// Local-only dispatcher. Each exact canonical function owns its authorization.
// The functions source directory is mounted read-only by the target runner.
const functions = new Set(['delete-account', 'stable-invitations', 'media-assets'])
Deno.serve(async (request: Request) => {
  const path = new URL(request.url).pathname
  const name = path.slice(1)
  if (path !== `/${name}` || !functions.has(name)) {
    return new Response(JSON.stringify({ code: 'LOCAL_FUNCTION_NOT_ALLOWED' }), {
      status: 404, headers: { 'Content-Type': 'application/json' },
    })
  }
  try {
    const worker = await EdgeRuntime.userWorkers.create({
      servicePath: `/home/deno/functions/source/${name}`,
      memoryLimitMb: 150, workerTimeoutMs: 60_000, noModuleCache: false,
      envVars: Object.entries(Deno.env.toObject()),
    })
    return await worker.fetch(request)
  } catch {
    return new Response(JSON.stringify({ code: 'LOCAL_FUNCTION_BOOT_FAILED' }), {
      status: 503, headers: { 'Content-Type': 'application/json' },
    })
  }
})
