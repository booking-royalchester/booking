import webpush from 'web-push'
import { DateTime } from 'luxon'
import { supabaseAdmin } from './_shared.js'

const vapidSubject = process.env.VAPID_SUBJECT
const vapidPublicKey = process.env.VAPID_PUBLIC_KEY
const vapidPrivateKey = process.env.VAPID_PRIVATE_KEY

if (!vapidSubject || !vapidPublicKey || !vapidPrivateKey) {
  throw new Error('Missing VAPID configuration.')
}

webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey)

const sendToMember = async (memberId, payload) => {
  const { data: subs, error } = await supabaseAdmin
    .from('push_subscriptions')
    .select('id, endpoint, p256dh, auth')
    .eq('member_id', memberId)

  if (error || !subs || subs.length === 0) {
    return false
  }

  let delivered = false
  await Promise.all(
    subs.map(async (sub) => {
      try {
        await webpush.sendNotification(
          {
            endpoint: sub.endpoint,
            keys: {
              p256dh: sub.p256dh,
              auth: sub.auth,
            },
          },
          JSON.stringify(payload),
        )
        delivered = true
      } catch (err) {
        const status = err?.statusCode
        if (status === 404 || status === 410) {
          await supabaseAdmin.from('push_subscriptions').delete().eq('id', sub.id)
        }
      }
    }),
  )

  return delivered
}

const formatOccurrenceLabel = (date, time) => {
  const dateTime = DateTime.fromISO(`${date}T${time}`, { zone: 'Europe/London' })
  return `${dateTime.toFormat('ccc d LLL')} at ${dateTime.toFormat('HH:mm')}`
}

const getTemplateSeasonForDate = (date) => {
  const dateTime = DateTime.fromISO(date, { zone: 'Europe/London' }).set({ hour: 12 })
  return dateTime.isInDST ? 'summer time' : 'winter time'
}

const getOppositeTemplateSeason = (season) =>
  season === 'summer time' ? 'winter time' : 'summer time'

const getConfiguredTemplateSeasonForDate = (date, nextSwitchDate) => {
  const fallbackSeason = getTemplateSeasonForDate(date)
  if (!nextSwitchDate) {
    return fallbackSeason
  }

  const today = DateTime.now().setZone('Europe/London').toISODate()
  const activeTodaySeason = getTemplateSeasonForDate(today)
  if (today < nextSwitchDate) {
    return date < nextSwitchDate ? activeTodaySeason : getOppositeTemplateSeason(activeTodaySeason)
  }
  return date < nextSwitchDate ? getOppositeTemplateSeason(activeTodaySeason) : activeTodaySeason
}

const buildKey = (templateId, occurrenceDate) => `${templateId}:${occurrenceDate}`
const buildGroupKey = (groupId, occurrenceDate) => `${groupId}:${occurrenceDate}`

export default async function handler(req, res) {
  const secret = process.env.CRON_SECRET
  if (secret) {
    const header = req.headers['x-cron-secret']
    const querySecret =
      typeof req.query?.secret === 'string'
        ? req.query.secret
        : Array.isArray(req.query?.secret)
          ? req.query.secret[0]
          : null
    if (header !== secret && querySecret !== secret) {
      res.status(401).json({ error: 'Unauthorized.' })
      return
    }
  }

  if (req.method !== 'POST' && req.method !== 'GET' && req.method !== 'HEAD') {
    res.status(405).json({ error: 'Method not allowed.' })
    return
  }

  const today = DateTime.now().setZone('Europe/London').startOf('day')
  const notificationDate = today.plus({ days: 3 }).toISODate()
  const autoCancelDates = [
    today.toISODate(),
    today.plus({ days: 1 }).toISODate(),
    today.plus({ days: 2 }).toISODate(),
  ]
  const relevantDates = [notificationDate, ...autoCancelDates]

  const { data: seasonSettings, error: seasonSettingsError } = await supabaseAdmin
    .from('template_season_settings')
    .select('next_switch_date')
    .eq('id', 1)
    .maybeSingle()

  if (seasonSettingsError) {
    res.status(500).json({ error: seasonSettingsError.message })
    return
  }

  const nextSwitchDate = seasonSettings?.next_switch_date ?? null

  const { data: templates, error: templatesError } = await supabaseAdmin
    .from('booking_templates')
    .select(
      'id, template_group_id, boat_id, member_id, season, weekday, start_time, end_time, boat_label, member_label, boats(name,type), members(name)',
    )
    .not('member_id', 'is', null)

  if (templatesError) {
    res.status(500).json({ error: templatesError.message })
    return
  }

  const [{ data: exceptions, error: exceptionsError }, { data: confirmations, error: confirmationsError }] =
    await Promise.all([
      supabaseAdmin
        .from('template_exceptions')
        .select('template_id, exception_date')
        .in('exception_date', relevantDates),
      supabaseAdmin
        .from('template_confirmations')
        .select('id, template_id, occurrence_date, member_id, status, booking_id, notified_at')
        .in('occurrence_date', relevantDates),
    ])

  if (exceptionsError) {
    res.status(500).json({ error: exceptionsError.message })
    return
  }

  if (confirmationsError) {
    res.status(500).json({ error: confirmationsError.message })
    return
  }

  const exceptionSet = new Set((exceptions ?? []).map((row) => buildKey(row.template_id, row.exception_date)))
  const confirmationMap = new Map(
    (confirmations ?? []).map((row) => [buildKey(row.template_id, row.occurrence_date), row]),
  )
  const templateGroups = new Map()

  for (const template of templates ?? []) {
    const groupId = template.template_group_id ?? template.id
    const existing = templateGroups.get(groupId)
    if (!existing) {
      templateGroups.set(groupId, {
        id: groupId,
        member_id: template.member_id,
        season: template.season ?? 'winter time',
        weekday: template.weekday,
        start_time: template.start_time,
        end_time: template.end_time,
        boat_label: template.boat_label,
        template_ids: [template.id],
        boats: template.boats ? [template.boats] : [],
        representative_template_id: template.id,
      })
      continue
    }

    existing.template_ids.push(template.id)
    if (template.boats) {
      existing.boats.push(template.boats)
    }
  }

  let pendingCreated = 0
  let remindersSent = 0
  let autoRemoved = 0
  let removalNoticesSent = 0

  for (const templateGroup of templateGroups.values()) {
    if (!templateGroup.member_id) {
      continue
    }

    const datesToCheck = [notificationDate, ...autoCancelDates]

    for (const occurrenceDate of datesToCheck) {
      const weekday = DateTime.fromISO(occurrenceDate, { zone: 'Europe/London' }).weekday % 7
      if (weekday !== templateGroup.weekday) {
        continue
      }
      if (
        (templateGroup.season ?? 'winter time') !==
        getConfiguredTemplateSeasonForDate(occurrenceDate, nextSwitchDate)
      ) {
        continue
      }

      const groupKey = buildGroupKey(templateGroup.id, occurrenceDate)
      const groupTemplateIds = templateGroup.template_ids
      const groupExceptions = groupTemplateIds.filter((templateId) =>
        exceptionSet.has(buildKey(templateId, occurrenceDate)),
      )
      if (groupExceptions.length === groupTemplateIds.length) {
        continue
      }

      const boatName =
        templateGroup.boat_label ||
        templateGroup.boats
          .map((boat) => {
            if (!boat) {
              return null
            }
            const parts = boat.name.trim().split(/\s+/).filter(Boolean)
            const shortName =
              parts.length <= 1 ? boat.name : `${parts[0]?.charAt(0) ?? ''}. ${parts.slice(1).join(' ')}`
            return boat.type ? `${boat.type} ${shortName}` : shortName
          })
          .filter(Boolean)
          .join(', ') ||
        'Boat'
      const existingGroupConfirmations = groupTemplateIds
        .map((templateId) => confirmationMap.get(buildKey(templateId, occurrenceDate)) ?? null)
        .filter(Boolean)
      const existingConfirmation =
        existingGroupConfirmations.find(
          (row) => row.template_id === templateGroup.representative_template_id,
        ) ??
        existingGroupConfirmations[0] ??
        null
      const existingStatus = existingGroupConfirmations.find((row) => row.status !== 'pending')?.status ?? 'pending'

      if (occurrenceDate === notificationDate) {
        if (existingStatus === 'confirmed' || existingStatus === 'cancelled') {
          continue
        }

        let confirmation = existingConfirmation
        if (!confirmation) {
          const { data: insertedConfirmation, error: insertError } = await supabaseAdmin
            .from('template_confirmations')
            .upsert(
              {
                template_id: templateGroup.representative_template_id,
                member_id: templateGroup.member_id,
                occurrence_date: occurrenceDate,
                status: 'pending',
              },
              { onConflict: 'template_id,occurrence_date' },
            )
            .select('id, template_id, occurrence_date, member_id, status, booking_id, notified_at')
            .single()

          if (insertError) {
            res.status(500).json({ error: insertError.message })
            return
          }

          confirmation = insertedConfirmation
          confirmationMap.set(
            buildKey(templateGroup.representative_template_id, occurrenceDate),
            insertedConfirmation,
          )
          pendingCreated += 1
        }

        if (!confirmation.notified_at) {
          const delivered = await sendToMember(templateGroup.member_id, {
            title: 'Template booking needs confirmation',
            body: `${boatName} on ${formatOccurrenceLabel(occurrenceDate, templateGroup.start_time)} needs to be confirmed.`,
            url: '/',
          })

          if (delivered) {
            remindersSent += 1
          }

          const notifiedAt = new Date().toISOString()
          const { error: updateError } = await supabaseAdmin
            .from('template_confirmations')
            .update({ notified_at: notifiedAt })
            .eq('id', confirmation.id)

          if (updateError) {
            res.status(500).json({ error: updateError.message })
            return
          }

          confirmationMap.set(buildKey(confirmation.template_id, occurrenceDate), {
            ...confirmation,
            notified_at: notifiedAt,
          })
        }

        continue
      }

      if (existingStatus === 'confirmed') {
        continue
      }

      const respondedAt = new Date().toISOString()
      const { error: exceptionError } = await supabaseAdmin
        .from('template_exceptions')
        .upsert(
          groupTemplateIds.map((templateId) => ({
            template_id: templateId,
            exception_date: occurrenceDate,
          })),
          { onConflict: 'template_id,exception_date' },
        )

      if (exceptionError) {
        res.status(500).json({ error: exceptionError.message })
        return
      }

      groupTemplateIds.forEach((templateId) => exceptionSet.add(buildKey(templateId, occurrenceDate)))
      autoRemoved += 1

      if (existingGroupConfirmations.length > 0) {
        const { error: cancelError } = await supabaseAdmin
          .from('template_confirmations')
          .update({
            status: 'cancelled',
            responded_at: respondedAt,
          })
          .in(
            'id',
            existingGroupConfirmations.map((row) => row.id),
          )

        if (cancelError) {
          res.status(500).json({ error: cancelError.message })
          return
        }

        existingGroupConfirmations.forEach((row) => {
          confirmationMap.set(buildKey(row.template_id, occurrenceDate), {
            ...row,
            status: 'cancelled',
            responded_at: respondedAt,
          })
        })
      } else {
        const { data: cancelledConfirmation, error: cancelError } = await supabaseAdmin
          .from('template_confirmations')
          .upsert(
            {
              template_id: templateGroup.representative_template_id,
              member_id: templateGroup.member_id,
              occurrence_date: occurrenceDate,
              status: 'cancelled',
              responded_at: respondedAt,
            },
            { onConflict: 'template_id,occurrence_date' },
          )
          .select('id, template_id, occurrence_date, member_id, status, booking_id, notified_at')
          .single()

        if (cancelError) {
          res.status(500).json({ error: cancelError.message })
          return
        }

        confirmationMap.set(
          buildKey(templateGroup.representative_template_id, occurrenceDate),
          cancelledConfirmation,
        )
      }

      if (existingStatus !== 'cancelled') {
        const delivered = await sendToMember(templateGroup.member_id, {
          title: 'Template booking removed',
          body: `${boatName} on ${formatOccurrenceLabel(occurrenceDate, templateGroup.start_time)} was removed because it was not confirmed in time.`,
          url: '/',
        })

        if (delivered) {
          removalNoticesSent += 1
        }
      }
    }
  }

  if (req.method === 'HEAD') {
    res.status(200).end()
    return
  }

  res.status(200).json({
    ok: true,
    notificationDate,
    autoCancelDates,
    pendingCreated,
    remindersSent,
    autoRemoved,
    removalNoticesSent,
  })
}
