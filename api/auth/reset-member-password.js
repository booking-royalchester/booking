import { readJson, requireUser, supabaseAdmin } from '../push/_shared.js'

const getRoleForEmail = async (email) => {
  const { data, error } = await supabaseAdmin
    .from('allowed_member')
    .select('role, is_admin')
    .ilike('email', email)
    .maybeSingle()

  if (error) {
    throw error
  }

  if (!data) {
    return null
  }

  return data.role || (data.is_admin ? 'admin' : 'coordinator')
}

const findAuthUserByEmail = async (email) => {
  let page = 1

  for (;;) {
    const { data, error } = await supabaseAdmin.auth.admin.listUsers({
      page,
      perPage: 1000,
    })

    if (error) {
      throw error
    }

    const users = data?.users ?? []
    const matched = users.find((user) => (user.email || '').toLowerCase() === email)
    if (matched) {
      return matched
    }

    if (users.length < 1000) {
      return null
    }

    page += 1
  }
}

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST')
    res.status(405).json({ error: 'Method not allowed.' })
    return
  }

  try {
    const user = await requireUser(req, res)
    if (!user?.email) {
      return
    }

    const requesterEmail = user.email.toLowerCase()
    const requesterRole = await getRoleForEmail(requesterEmail)

    if (requesterRole !== 'admin' && requesterRole !== 'captain') {
      res.status(403).json({ error: 'You do not have permission to reset passwords.' })
      return
    }

    const body = await readJson(req)
    const targetEmail = typeof body.email === 'string' ? body.email.trim().toLowerCase() : ''

    if (!targetEmail) {
      res.status(400).json({ error: 'Missing email.' })
      return
    }

    const { data: allowedMember, error: allowedError } = await supabaseAdmin
      .from('allowed_member')
      .select('email')
      .ilike('email', targetEmail)
      .maybeSingle()

    if (allowedError) {
      throw allowedError
    }

    if (!allowedMember) {
      res.status(404).json({ error: 'Allowed member not found.' })
      return
    }

    const authUser = await findAuthUserByEmail(targetEmail)
    if (!authUser?.id) {
      res.status(404).json({ error: 'Auth user not found for this email.' })
      return
    }

    const { error: updateUserError } = await supabaseAdmin.auth.admin.updateUserById(authUser.id, {
      password: targetEmail,
    })

    if (updateUserError) {
      throw updateUserError
    }

    const { error: flagError } = await supabaseAdmin
      .from('allowed_member')
      .update({ force_password_reset: true })
      .ilike('email', targetEmail)

    if (flagError) {
      throw flagError
    }

    res.status(200).json({ ok: true })
  } catch (error) {
    res.status(500).json({ error: error instanceof Error ? error.message : 'Unable to reset password.' })
  }
}
