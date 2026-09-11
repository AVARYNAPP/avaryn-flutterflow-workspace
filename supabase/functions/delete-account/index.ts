import { DeletionFailure, deletionCorsHeaders, handleAccountDeletion, response } from './handler.ts'
import type { DeletionJob } from './handler.ts'

// Native HTTP keeps the trusted deletion chain independent of an unpinned SDK.
Deno.serve(async (request: Request) => {
  const configuredOrigins = Deno.env.get('AVARYN_ALLOWED_ORIGINS')
  const allowedOrigins = configuredOrigins === undefined ? undefined : configuredOrigins.split(',').map(value => value.trim()).filter(Boolean)
  const headers = deletionCorsHeaders(request, allowedOrigins)
  if (!headers) return response(403, 'ORIGIN_NOT_ALLOWED')
  if (request.method !== 'POST') return handleAccountDeletion(request, null, allowedOrigins)
  const url = (Deno.env.get('SUPABASE_URL') ?? '').replace(/\/$/, '')
  const anon = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY') ?? ''
  const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (!url || !anon || !service) return response(503, 'SERVER_CONFIGURATION_MISSING', headers)
  const privileged = { apikey: service, Authorization: `Bearer ${service}`, 'Content-Type': 'application/json' }
  async function boundedFetch(path: string, init: RequestInit) {
    return fetch(`${url}${path}`, { ...init, signal: AbortSignal.timeout(15000), redirect: 'error' })
  }
  async function rpc(name: string, body: Record<string, unknown>) {
    const result = await boundedFetch(`/rest/v1/rpc/${name}`, {
      method: 'POST', body: JSON.stringify(body), headers: privileged,
    })
    let data: unknown
    try { data = await result.json() } catch { throw new DeletionFailure('DELETION_RPC_UNAVAILABLE') }
    if (!result.ok) {
      const message = data && typeof data === 'object' && 'message' in data ? data.message : ''
      throw new DeletionFailure(typeof message === 'string' && /^[A-Z][A-Z0-9_]{1,90}$/.test(message) ? message : 'DELETION_RPC_UNAVAILABLE')
    }
    if (Array.isArray(data)) {
      if (data.length !== 1) throw new DeletionFailure('DELETION_JOB_INVALID')
      data = data[0]
    }
    if (!data || typeof data !== 'object') throw new DeletionFailure('DELETION_JOB_INVALID')
    return data as DeletionJob
  }
  return handleAccountDeletion(request, {
    authenticate: async token => {
      const result = await boundedFetch('/auth/v1/user', {
        headers: { apikey: anon, Authorization: `Bearer ${token}` },
      })
      if (result.status === 401 || result.status === 403) return null
      if (!result.ok) throw new DeletionFailure('AUTH_CHECK_UNAVAILABLE')
      const user = await result.json()
      return typeof user.id === 'string' ? user : null
    },
    // A role claim or user-supplied Auth UUID never authorizes recovery. Only
    // the configured server credential can resume an already authorized job.
    trustedResume: token => token === service,
    prepare: (authUserId, requestId) => rpc('prepare_c010_account_deletion', {
      p_auth_user_id: authUserId, p_request_id: requestId,
    }),
    job: async requestId => {
      const job = await rpc('get_c010_account_deletion_job', { p_request_id: requestId })
      return job.code === 'DELETION_REQUEST_NOT_FOUND' || job.status === 'not_found' ? null : job
    },
    removeAvatars: async job => {
      // These exact actor-prefixed paths were captured by the atomic database
      // preflight. No bucket listing, guessed filename or horse-media removal.
      for (let start = 0; start < job.avatar_paths.length; start += 1000) {
        const result = await boundedFetch('/storage/v1/object/avatars', {
          method: 'DELETE', headers: privileged,
          body: JSON.stringify({ prefixes: job.avatar_paths.slice(start, start + 1000) }),
        })
        if (!result.ok) throw new DeletionFailure('AVATAR_CLEANUP_PENDING')
      }
    },
    deleteAuth: async authUserId => {
      const result = await boundedFetch(`/auth/v1/admin/users/${encodeURIComponent(authUserId)}`, {
        method: 'DELETE', headers: privileged, body: JSON.stringify({ should_soft_delete: false }),
      })
      // A previous attempt may have succeeded before its response was lost.
      // The final database transaction still verifies that Auth is absent.
      if (!result.ok && result.status !== 404) throw new DeletionFailure('AUTH_REMOVAL_PENDING')
    },
    finalize: requestId => rpc('finalize_c010_account_deletion', { p_request_id: requestId }),
  }, allowedOrigins)
})
