import { createClient } from 'npm:@supabase/supabase-js@2'

const responseHeaders = {
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
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

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: responseHeaders })
  }
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

  const serviceClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  })
  // Use the server-only client for the retention check. Caller RLS may
  // intentionally hide suspended or removed historical memberships, but
  // account deletion must discover them before any avatar is removed.
  const { data: memberships, error: membershipError } = await serviceClient
    .from('stable_memberships')
    .select('id,role,status')
    .eq('user_id', user.id)
  if (membershipError) {
    return response(503, { code: 'MEMBERSHIP_CHECK_UNAVAILABLE' })
  }
  if (
    (memberships ?? []).some(
      (membership) =>
        membership.status === 'active' && membership.role === 'owner',
    )
  ) {
    return response(409, { code: 'ACTIVE_STABLE_OWNER_REQUIRES_TRANSFER' })
  }
  if (
    (memberships ?? []).some(
      (membership) => membership.status === 'active',
    )
  ) {
    return response(409, { code: 'ACTIVE_MEMBERSHIPS_REQUIRE_RESOLUTION' })
  }
  if ((memberships ?? []).length > 0) {
    // Historical memberships and their audit references have an explicit
    // retention contract. Do not silently destroy or detach them here.
    return response(409, { code: 'ACCOUNT_HISTORY_REQUIRES_ADMIN_REVIEW' })
  }

  const { data: avatarObjects, error: avatarListError } =
    await serviceClient.storage.from('avatars').list(user.id, { limit: 1000 })
  if (avatarListError) {
    return response(503, { code: 'AVATAR_CLEANUP_UNAVAILABLE' })
  }
  if ((avatarObjects ?? []).length >= 1000) {
    return response(409, { code: 'AVATAR_CLEANUP_REQUIRES_ADMIN_REVIEW' })
  }

  const avatarPaths = (avatarObjects ?? [])
    .filter((object) => object.id)
    .map((object) => `${user.id}/${object.name}`)
  if (avatarPaths.length > 0) {
    const { error: avatarDeleteError } = await serviceClient.storage
      .from('avatars')
      .remove(avatarPaths)
    if (avatarDeleteError) {
      return response(503, { code: 'AVATAR_CLEANUP_UNAVAILABLE' })
    }
  }

  const { error: deleteError } = await serviceClient.auth.admin.deleteUser(
    user.id,
    false,
  )
  if (deleteError) {
    // A remaining database reference is never bypassed. The account stays
    // fail-closed for controlled administrative review.
    return response(409, { code: 'ACCOUNT_HISTORY_REQUIRES_ADMIN_REVIEW' })
  }

  return response(200, { code: 'ACCOUNT_DELETED' })
})
