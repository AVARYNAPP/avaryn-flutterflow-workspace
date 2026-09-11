import test from 'node:test';
import assert from 'node:assert/strict';
const actor='10000000-0000-4000-8000-000000000001';
const profile='20000000-0000-4000-8000-000000000001';
const rid='30000000-0000-4000-8000-000000000001';
const env={SUPABASE_URL:'http://synthetic.invalid',SUPABASE_ANON_KEY:'synthetic-public',SUPABASE_SERVICE_ROLE_KEY:'synthetic-server',AVARYN_ALLOWED_ORIGINS:'https://preview.example'};
let entry;
globalThis.Deno={env:{get:key=>env[key]},serve:handler=>{entry=handler;}};
await import('../../supabase/functions/delete-account/index.ts');
const originalFetch=globalThis.fetch;
const job=(status='auth_removal_pending')=>({code:status==='anonymized'?'ACCOUNT_DELETED':'ACCOUNT_DELETION_PENDING',status,correlation_id:rid,profile_id:profile,auth_user_id:actor,avatar_paths:[actor+'/avatar.png']});
const post=(action='delete',token='synthetic-caller')=>new Request('http://localhost/delete-account',{method:'POST',headers:{Authorization:'Bearer '+token,Origin:'https://preview.example'},body:JSON.stringify({action,request_id:rid})});
function install(overrides={}) {
  const calls=[];
  globalThis.fetch=async(url,init)=>{
    const path=new URL(url).pathname;const body=init.body?JSON.parse(init.body):null;
    calls.push({path,body,headers:init.headers});
    assert.equal(init.redirect,'error');assert(init.signal instanceof AbortSignal);
    if(overrides[path])return overrides[path]({path,body,init});
    if(path==='/auth/v1/user'){assert.equal(init.headers.Authorization,'Bearer synthetic-caller');return Response.json({id:actor,identities:[]});}
    assert.equal(init.headers.Authorization,'Bearer synthetic-server');assert.equal(init.headers.apikey,'synthetic-server');
    if(path==='/rest/v1/rpc/prepare_c010_account_deletion')return Response.json(job());
    if(path==='/rest/v1/rpc/get_c010_account_deletion_job')return Response.json(job());
    if(path==='/rest/v1/rpc/finalize_c010_account_deletion')return Response.json(job('anonymized'));
    if(path==='/storage/v1/object/avatars')return Response.json([]);
    if(path==='/auth/v1/admin/users/'+actor)return Response.json({});
    throw new Error('Unexpected synthetic request');
  };
  return calls;
}
test.after(()=>{globalThis.fetch=originalFetch;delete globalThis.Deno;});
test('actual native adapter uses verified actor, exact avatar paths, hard Auth delete and final DB RPC',async()=>{
  const calls=install();const result=await entry(post());assert.equal(result.status,200);
  assert.deepEqual(calls.map(c=>c.path),['/auth/v1/user','/rest/v1/rpc/prepare_c010_account_deletion','/storage/v1/object/avatars','/auth/v1/admin/users/'+actor,'/rest/v1/rpc/finalize_c010_account_deletion']);
  assert.deepEqual(calls[1].body,{p_auth_user_id:actor,p_request_id:rid});
  assert.deepEqual(calls[2].body,{prefixes:[actor+'/avatar.png']});
  assert.deepEqual(calls[3].body,{should_soft_delete:false});
  assert.equal(result.headers.get('Access-Control-Allow-Origin'),'https://preview.example');
});
test('native adapter handles singleton-array RPC projection and Auth-already-absent retry',async()=>{
  const calls=install({'/rest/v1/rpc/get_c010_account_deletion_job':()=>Response.json([job()]),
    ['/auth/v1/admin/users/'+actor]:()=>Response.json({code:'user_not_found'},{status:404})});
  const result=await entry(post('resume','synthetic-server'));assert.equal(result.status,200);
  assert(!calls.some(c=>c.path==='/auth/v1/user'));assert.equal(calls.at(-1).path,'/rest/v1/rpc/finalize_c010_account_deletion');
});
test('native Storage error stops before Auth and reports durable pending',async()=>{
  const calls=install({'/storage/v1/object/avatars':()=>Response.json({message:'synthetic outage'},{status:503})});
  const result=await entry(post());assert.equal(result.status,202);assert.equal((await result.json()).code,'ACCOUNT_DELETION_PENDING');
  assert(!calls.some(c=>c.path.includes('/admin/users/')));
});
test('native Auth error leaves DB finalization uncalled',async()=>{
  const calls=install({['/auth/v1/admin/users/'+actor]:()=>Response.json({message:'synthetic outage'},{status:500})});
  assert.equal((await entry(post())).status,202);assert(!calls.some(c=>c.path.includes('/finalize_')));
});
test('native RPC blocker maps to safe concrete409 without destructive calls',async()=>{
  const calls=install({'/rest/v1/rpc/prepare_c010_account_deletion':()=>Response.json({code:'42501',message:'PRIMARY_HORSE_AUTHORITY_REQUIRED'},{status:403})});
  const result=await entry(post());assert.equal(result.status,409);assert.equal((await result.json()).code,'PRIMARY_HORSE_AUTHORITY_REQUIRED');assert.equal(calls.length,2);
});
test('native legacy preflight refusal leaves avatar, Auth and finalization untouched on retry',async()=>{
  const calls=install({'/rest/v1/rpc/prepare_c010_account_deletion':()=>Response.json({status:'blocked',code:'LEGACY_RETENTION_REQUIRED'})});
  for(let i=0;i<2;i++){
    const result=await entry(post());assert.equal(result.status,409);assert.equal((await result.json()).code,'LEGACY_RETENTION_REQUIRED');
  }
  assert.deepEqual(calls.map(c=>c.path),['/auth/v1/user','/rest/v1/rpc/prepare_c010_account_deletion','/auth/v1/user','/rest/v1/rpc/prepare_c010_account_deletion']);
});
test('native verified Apple metadata blocks without a prepare or Storage request',async()=>{
  const calls=install({'/auth/v1/user':()=>Response.json({id:actor,app_metadata:{provider:'email',providers:['email','apple']}})});
  const result=await entry(post());assert.equal(result.status,409);assert.equal((await result.json()).code,'APPLE_REVOCATION_NOT_CONFIGURED');
  assert.deepEqual(calls.map(c=>c.path),['/auth/v1/user']);
});
test('native trusted resume rejects a legacy receipt rather than deleting Auth',async()=>{
  const calls=install({'/rest/v1/rpc/get_c010_account_deletion_job':()=>Response.json({...job(),profile_id:actor})});
  const result=await entry(post('resume','synthetic-server'));assert.equal(result.status,503);
  assert.deepEqual(calls.map(c=>c.path),['/rest/v1/rpc/get_c010_account_deletion_job']);
});
test('native adapter rejects foreign CORS before all API requests',async()=>{
  const calls=install();const request=post();request.headers.set('Origin','https://foreign.example');assert.equal((await entry(request)).status,403);assert.deepEqual(calls,[]);
});
