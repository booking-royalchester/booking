import { requireUser, supabaseAdmin } from '../push/_shared.js'

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

    const { error } = await supabaseAdmin
      .from('allowed_member')
      .update({ force_password_reset: false })
      .ilike('email', user.email.toLowerCase())

    if (error) {
      throw error
    }

    res.status(200).json({ ok: true })
  } catch (error) {
    res.status(500).json({
      error: error instanceof Error ? error.message : 'Unable to clear forced password reset.',
    })
  }
}
