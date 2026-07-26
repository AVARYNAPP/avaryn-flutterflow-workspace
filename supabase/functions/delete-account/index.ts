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
  const authorization = request.headers.get('Authorization') ?? ''
  const accessToken = authorization.startsWith('Bearer ')
    ? authorization.substring('Bearer '.length)
    : ''

  if (!supabaseUrl || !publishableKey) {
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

  const { data: memberships, error: membershipError } = await callerClient
    .from('stable_memberships')
    .select('id,role,status')
    .eq('user_id', user.id)
    .eq('status', 'active')
  if (membershipError) {
    return response(503, { code: 'MEMBERSHIP_CHECK_UNAVAILABLE' })
  }
  if ((memberships ?? []).some((membership) => membership.role === 'owner')) {
    return response(409, { code: 'ACTIVE_STABLE_OWNER_REQUIRES_TRANSFER' })
  }
  if ((memberships ?? []).length > 0) {
    return response(409, { code: 'ACTIVE_MEMBERSHIPS_REQUIRE_RESOLUTION' })
  }

  // Phase 4B keeps deletion fully disabled. No profile, avatar or auth record
  // is touched until the complete server-side deletion and revocation path has
  // been configured and independently verified.
  return response(503, { code: 'SAFE_ACCOUNT_DELETION_NOT_AVAILABLE' })
})
