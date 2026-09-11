// A request is authorized by Auth once, then its durable database receipt owns
// retries. Database preparation is atomic; Storage and Auth are external steps.
export const responseHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-api-version',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
  'Cache-Control': 'no-store',
}
export function response(status: number, code: string, headers: Record<string, string> = responseHeaders,
  extra: Record<string, unknown> = {}) {
  return new Response(JSON.stringify({ code, ...extra }), { status, headers })
}
export function deletionCorsHeaders(request: Request, allowedOrigins?: string[]) {
  const origin = request.headers.get('Origin')
  if (allowedOrigins === undefined) return { ...responseHeaders, 'Access-Control-Allow-Origin': '*' }
  if (origin && !allowedOrigins.includes(origin)) return null
  return { ...responseHeaders, Vary: 'Origin', ...(origin ? { 'Access-Control-Allow-Origin': origin } : {}) }
}
type User = {
  id: string
  identities?: { provider: string }[] | null
  app_metadata?: { provider?: unknown; providers?: unknown } | null
}
export type DeletionJob = {
  code: string
  status: string
  correlation_id: string
  profile_id: string
  auth_user_id: string
  avatar_paths: string[]
}
export type DeletionPorts = {
  authenticate(token: string): Promise<User | null>
  trustedResume(token: string): boolean
  prepare(authUserId: string, requestId: string): Promise<DeletionJob>
  job(requestId: string): Promise<DeletionJob | null>
  removeAvatars(job: DeletionJob): Promise<void>
  deleteAuth(authUserId: string): Promise<void>
  finalize(requestId: string): Promise<DeletionJob>
}
export class DeletionFailure extends Error {
  code: string
  constructor(code: string) { super(code); this.code = code }
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const blockers = new Set([
  'PRIMARY_ORGANIZATION_ADMIN_REQUIRED', 'PRIMARY_HORSE_AUTHORITY_REQUIRED',
  'LEGACY_RETENTION_REQUIRED', 'STORAGE_OWNERSHIP_UNSUPPORTED',
  'ACCOUNT_DELETION_STATE_UNSUPPORTED', 'DELETION_REQUEST_CONFLICT',
  'PRIMARY_ORGANIZATION_AUTHORITY_REQUIRES_TRANSFER',
  'PRIMARY_HORSE_AUTHORITY_REQUIRES_TRANSFER',
  'ACTIVE_STABLE_OWNER_REQUIRES_TRANSFER', 'ACTIVE_MEMBERSHIPS_REQUIRE_RESOLUTION',
  'ACCOUNT_HISTORY_REQUIRES_ADMIN_REVIEW', 'ACCOUNT_LEGACY_HISTORY_REQUIRES_REVIEW',
  'APPLE_REVOCATION_NOT_CONFIGURED', 'CANONICAL_PROFILE_REQUIRED',
  'AVATAR_CLEANUP_REQUIRES_ADMIN_REVIEW', 'STORAGE_OWNERSHIP_REQUIRES_REVIEW',
  'ACCOUNT_DELETION_LIFECYCLE_NOT_READY', 'REQUEST_ID_REUSED',
])
function validJob(job: DeletionJob) {
  return uuid.test(job.correlation_id) && uuid.test(job.profile_id) && uuid.test(job.auth_user_id) &&
    // SQL rejects identity overlap before preparation. A historical or invalid
    // receipt must not bypass that boundary through resume or lost-response recovery.
    job.profile_id.toLowerCase() !== job.auth_user_id.toLowerCase() &&
    ['auth_removal_pending', 'anonymized'].includes(job.status) && Array.isArray(job.avatar_paths) &&
    job.avatar_paths.every(path => typeof path === 'string' && path.startsWith(job.auth_user_id + '/') &&
      path.length > job.auth_user_id.length + 1 && !path.split('/').some(part => part === '.' || part === '..'))
}
export async function handleAccountDeletion(request: Request, ports: DeletionPorts | null,
  allowedOrigins?: string[]) {
  const headers = deletionCorsHeaders(request, allowedOrigins)
  if (!headers) return response(403, 'ORIGIN_NOT_ALLOWED')
  const reply = (status: number, code: string, extra: Record<string, unknown> = {}) => response(status, code, headers, extra)
  if (request.method === 'OPTIONS') return new Response(null, { headers })
  if (request.method !== 'POST') return reply(405, 'METHOD_NOT_ALLOWED')
  const authorization = request.headers.get('Authorization') ?? ''
  const token = authorization.startsWith('Bearer ') ? authorization.slice(7).trim() : ''
  if (!token) return reply(401, 'AUTHENTICATION_REQUIRED')
  if (!ports) return reply(503, 'SERVER_CONFIGURATION_MISSING')
  let body: Record<string, unknown>
  try {
    const text = await request.text()
    if (text.length > 4096) return reply(400, 'DELETION_REQUEST_INVALID')
    const value = JSON.parse(text || '{}')
    if (!value || typeof value !== 'object' || Array.isArray(value)) return reply(400, 'DELETION_REQUEST_INVALID')
    body = value
  } catch { return reply(400, 'DELETION_REQUEST_INVALID') }
  // Earlier clients used {} to inspect blockers. Never reinterpret that old
  // read-only action as consent to destructive work.
  if (body.action !== 'delete' && body.action !== 'resume') return reply(400, 'DELETION_CONFIRMATION_REQUIRED')
  if (typeof body.request_id !== 'string' || !uuid.test(body.request_id) ||
      Object.keys(body).some(key => key !== 'action' && key !== 'request_id')) return reply(400, 'DELETION_REQUEST_INVALID')
  const requestId = body.request_id
  let job: DeletionJob | null = null
  let verifiedActor = ''
  let preparationAttempted = false
  try {
    if (body.action === 'resume') {
      if (!ports.trustedResume(token)) return reply(403, 'TRUSTED_DELETION_SERVICE_REQUIRED')
      job = await ports.job(requestId)
      if (!job) return reply(404, 'DELETION_REQUEST_NOT_FOUND')
    } else {
      const user = await ports.authenticate(token)
      if (!user || !uuid.test(user.id)) return reply(401, 'INVALID_SESSION')
      // These fields come from Auth's verified user response, never request/JWT
      // or editable user_metadata. Older responses may omit the identities list.
      if (user.app_metadata?.provider === 'apple' ||
          (Array.isArray(user.app_metadata?.providers) && user.app_metadata.providers.includes('apple')) ||
          (Array.isArray(user.identities) && user.identities.some(identity => identity?.provider === 'apple'))) {
        return reply(409, 'APPLE_REVOCATION_NOT_CONFIGURED')
      }
      verifiedActor = user.id
      preparationAttempted = true
      job = await ports.prepare(user.id, requestId)
    }
    if (job.status === 'blocked' && blockers.has(job.code)) return reply(409, job.code)
    if (!validJob(job) || (verifiedActor && job.auth_user_id !== verifiedActor) ||
        (body.action === 'resume' && job.correlation_id !== requestId)) throw new DeletionFailure('DELETION_JOB_INVALID')
    if (job.status === 'anonymized') return reply(200, 'ACCOUNT_DELETED', { request_id: job.correlation_id })
    await ports.removeAvatars(job)
    await ports.deleteAuth(job.auth_user_id)
    const terminal = await ports.finalize(job.correlation_id)
    if (!validJob(terminal) || terminal.status !== 'anonymized' || terminal.profile_id !== job.profile_id ||
        terminal.auth_user_id !== job.auth_user_id || terminal.correlation_id !== job.correlation_id) {
      throw new DeletionFailure('DELETION_FINALIZATION_UNCONFIRMED')
    }
    return reply(200, 'ACCOUNT_DELETED', { request_id: job.correlation_id })
  } catch (error) {
    if (error instanceof DeletionFailure && blockers.has(error.code) && !job) return reply(409, error.code)
    // Preparation may have committed even when its HTTP response was lost.
    // Lookup is read-only; an unrelated receipt never authorizes a retry.
    if (!job && preparationAttempted) {
      try {
        const recovered = await ports.job(requestId)
        if (recovered && validJob(recovered) && recovered.auth_user_id === verifiedActor &&
            recovered.correlation_id === requestId) job = recovered
      } catch { /* No authoritative status: report uncertainty below. */ }
    }
    if (job && validJob(job) && (!verifiedActor || job.auth_user_id === verifiedActor) &&
        (body.action !== 'resume' || job.correlation_id === requestId)) {
      if (job.status === 'anonymized') return reply(200, 'ACCOUNT_DELETED', { request_id: job.correlation_id })
      return reply(202, 'ACCOUNT_DELETION_PENDING', { request_id: job.correlation_id })
    }
    return reply(503, preparationAttempted ? 'DELETION_STATUS_UNAVAILABLE' : 'DELETION_CHECK_UNAVAILABLE')
  }
}
