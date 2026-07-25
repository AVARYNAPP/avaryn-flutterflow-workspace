import { createClient } from 'npm:@supabase/supabase-js@2'

const jsonHeaders = {
  'Content-Type': 'application/json',
}

function response(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders })
}

Deno.serve(async (request: Request) => {
  if (request.method !== 'POST') {
    return response(405, { code: 'METHOD_NOT_ALLOWED' })
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
  const publishableKey =
    Deno.env.get('SUPABASE_ANON_KEY') ??
    Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ??
    ''
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  const authorization = request.headers.get('Authorization') ?? ''
  const accessToken = authorization.startsWith('Bearer ')
    ? authorization.substring('Bearer '.length)
    : ''

  if (!supabaseUrl || !publishableKey || !serviceRoleKey) {
    return response(503, { code: 'SERVER_CONFIGURATION_MISSING' })
  }
  if (!accessToken) {
    return response(401, { code: 'AUTHENTICATION_REQUIRED' })
  }

  const callerClient = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  })
  const {
    data: { user },
    error: userError,
  } = await callerClient.auth.getUser(accessToken)

  if (userError || !user) {
    return response(401, { code: 'INVALID_SESSION' })
  }

  const hasAppleIdentity =
    user.identities?.some((identity) => identity.provider === 'apple') ?? false
  if (hasAppleIdentity) {
    // Apple revocation needs the provider authorization material and configured
    // Apple credentials. Phase 4A fails closed until that server-side flow is
    // explicitly configured and tested.
    return response(409, { code: 'APPLE_REVOCATION_NOT_CONFIGURED' })
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  })

  const { data: avatarObjects, error: listError } = await admin.storage
    .from('avatars')
    .list(user.id)
  if (listError) {
    return response(500, { code: 'AVATAR_LIST_FAILED' })
  }
  const avatarPaths = (avatarObjects ?? []).map(
    (item) => `${user.id}/${item.name}`,
  )
  if (avatarPaths.length > 0) {
    const { error: removeError } = await admin.storage
      .from('avatars')
      .remove(avatarPaths)
    if (removeError) {
      return response(500, { code: 'AVATAR_DELETE_FAILED' })
    }
  }

  const { error: profileError } = await admin
    .from('profiles')
    .delete()
    .eq('id', user.id)
  if (profileError) {
    return response(500, { code: 'PROFILE_DELETE_FAILED' })
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(
    user.id,
    false,
  )
  if (deleteError && !deleteError.message.toLowerCase().includes('not found')) {
    return response(500, { code: 'AUTH_ACCOUNT_DELETE_FAILED' })
  }

  return response(200, { deleted: true })
})
