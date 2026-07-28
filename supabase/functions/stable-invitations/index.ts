import { createClient } from 'npm:@supabase/supabase-js@2'

const responseHeaders = {
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Origin': '*',
  'Content-Type': 'application/json',
}

function response(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: responseHeaders,
  })
}

function base64Url(bytes: Uint8Array) {
  let binary = ''
  for (const byte of bytes) binary += String.fromCharCode(byte)
  return btoa(binary)
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '')
}

function randomToken() {
  const bytes = new Uint8Array(32)
  crypto.getRandomValues(bytes)
  return base64Url(bytes)
}

async function tokenDigest(token: string) {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(token),
  )
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

function safeRpcError(message: string) {
  if (message.includes('COOLDOWN')) return 'INVITATION_COOLDOWN'
  if (message.includes('RATE_LIMITED')) return 'INVITATION_RATE_LIMITED'
  if (message.includes('PERSONAL_INVITATIONS_DISABLED')) {
    return 'PERSONAL_INVITATIONS_DISABLED'
  }
  if (message.includes('ROLE_NOT_ALLOWED')) return 'ROLE_NOT_ALLOWED'
  if (message.includes('NOT_AUTHORIZED')) return 'NOT_AUTHORIZED'
  if (message.includes('INVITATION_UNAVAILABLE')) return 'INVITATION_UNAVAILABLE'
  if (message.includes('CONFIRMED_ACCOUNT_REQUIRED')) {
    return 'CONFIRMED_ACCOUNT_REQUIRED'
  }
  if (message.includes('DISPLAY_NAME_REQUIRED')) return 'DISPLAY_NAME_REQUIRED'
  if (message.includes('MEMBERSHIP_ALREADY_ACTIVE')) {
    return 'MEMBERSHIP_ALREADY_ACTIVE'
  }
  return 'SERVER_UNAVAILABLE'
}

function rpcErrorStatus(code: string) {
  if (code === 'SERVER_UNAVAILABLE') return 503
  if (code === 'NOT_AUTHORIZED') return 403
  if (
    code === 'CONFIRMED_ACCOUNT_REQUIRED' ||
    code === 'DISPLAY_NAME_REQUIRED'
  ) {
    return 412
  }
  return 409
}

function inviteLink(rawToken: string) {
  const configured =
    Deno.env.get('AVARYN_INVITATION_URL') ??
    'http://127.0.0.1:3000/uitnodiging'
  return `${configured}#token=${encodeURIComponent(rawToken)}`
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response(null, { headers: responseHeaders })
  if (request.method !== 'POST') {
    return response(405, { code: 'METHOD_NOT_ALLOWED' })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const publishableKey =
    Deno.env.get('SUPABASE_ANON_KEY') ??
    Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
    ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (!supabaseUrl || !publishableKey || !serviceRoleKey) {
    return response(503, { code: 'SERVER_CONFIGURATION_MISSING' })
  }

  let body: Record<string, unknown>
  try {
    body = await request.json()
  } catch {
    return response(400, { code: 'INVALID_REQUEST' })
  }
  const action = typeof body.action === 'string' ? body.action : ''
  const authorization = request.headers.get('Authorization') ?? ''

  const callerClient = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  })
  const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  })

  if (action === 'preview') {
    const rawToken = typeof body.token === 'string' ? body.token : ''
    if (rawToken.length < 40 || rawToken.length > 128) {
      return response(200, { status: 'unavailable' })
    }
    const tokenHash = await tokenDigest(rawToken)
    const { data, error } = await serviceClient.rpc(
      'preview_stable_invitation',
      { p_token_hash_hex: tokenHash },
    )
    if (error) return response(503, { code: 'SERVER_UNAVAILABLE' })
    return response(200, data as Record<string, unknown>)
  }

  const accessToken = authorization.startsWith('Bearer ')
    ? authorization.substring('Bearer '.length)
    : ''
  if (!accessToken) {
    return response(401, { code: 'AUTHENTICATION_REQUIRED' })
  }
  const {
    data: { user },
    error: userError,
  } = await callerClient.auth.getUser(accessToken)
  if (userError || !user) {
    return response(401, { code: 'INVALID_SESSION' })
  }

  if (action === 'resume') {
    const invitationId =
      typeof body.invitation_id === 'string' ? body.invitation_id : ''
    if (
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
        .test(invitationId)
    ) {
      return response(200, { status: 'unavailable' })
    }
    const { data, error } = await callerClient.rpc(
      'resume_stable_invitation',
      { p_invitation_id: invitationId },
    )
    if (error) return response(503, { code: 'SERVER_UNAVAILABLE' })
    return response(200, data as Record<string, unknown>)
  }

  if (action === 'create' || action === 'resend') {
    const rawToken = randomToken()
    const tokenHash = await tokenDigest(rawToken)
    const rpc =
      action === 'create'
        ? callerClient.rpc('create_stable_invitation', {
            p_stable_id: body.stable_id,
            p_invited_email: body.email,
            p_offered_role: body.role,
            p_token_hash_hex: tokenHash,
            p_target_stable_member_id: body.target_stable_member_id ?? null,
            p_request_id: body.request_id ?? null,
          })
        : callerClient.rpc('resend_stable_invitation', {
            p_invitation_id: body.invitation_id,
            p_token_hash_hex: tokenHash,
            p_request_id: body.request_id ?? null,
          })
    const { data, error } = await rpc
    if (error) {
      const code = safeRpcError(error.message)
      return response(rpcErrorStatus(code), { code })
    }
    return response(200, {
      ...(data as Record<string, unknown>),
      delivery: 'manual_share_only',
      invitation_url: inviteLink(rawToken),
    })
  }

  if (action === 'accept' || action === 'decline') {
    const rawToken = typeof body.token === 'string' ? body.token : ''
    const invitationId =
      typeof body.invitation_id === 'string' ? body.invitation_id : ''
    const hasToken = rawToken.length >= 40 && rawToken.length <= 128
    const hasInvitationId =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
        .test(invitationId)
    if (!hasToken && !hasInvitationId) {
      return response(409, { code: 'INVITATION_UNAVAILABLE' })
    }
    const tokenHash = hasToken ? await tokenDigest(rawToken) : ''
    const rpc =
      action === 'accept'
        ? hasToken
          ? callerClient.rpc('accept_stable_invitation', {
              p_token_hash_hex: tokenHash,
              p_display_name: body.display_name ?? null,
              p_function_title: body.function_title ?? null,
              p_request_id: body.request_id ?? null,
            })
          : callerClient.rpc('accept_stable_invitation_by_id', {
              p_invitation_id: invitationId,
              p_display_name: body.display_name ?? null,
              p_function_title: body.function_title ?? null,
              p_request_id: body.request_id ?? null,
            })
        : hasToken
          ? callerClient.rpc('decline_stable_invitation', {
              p_token_hash_hex: tokenHash,
              p_request_id: body.request_id ?? null,
            })
          : callerClient.rpc('decline_stable_invitation_by_id', {
              p_invitation_id: invitationId,
              p_request_id: body.request_id ?? null,
            })
    const { data, error } = await rpc
    if (error) {
      const code = safeRpcError(error.message)
      return response(rpcErrorStatus(code), { code })
    }
    return response(200, { result: data })
  }

  if (action === 'revoke') {
    const { data, error } = await callerClient.rpc(
      'revoke_stable_invitation',
      {
        p_invitation_id: body.invitation_id,
        p_request_id: body.request_id ?? null,
      },
    )
    if (error) {
      const code = safeRpcError(error.message)
      return response(rpcErrorStatus(code), { code })
    }
    return response(200, { revoked: data === true })
  }

  return response(400, { code: 'INVALID_REQUEST' })
})
