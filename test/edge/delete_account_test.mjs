import test from 'node:test';
import assert from 'node:assert/strict';
import { DeletionFailure, handleAccountDeletion } from '../../supabase/functions/delete-account/handler.ts';
const actor='10000000-0000-4000-8000-000000000001';
const other='10000000-0000-4000-8000-000000000002';
const profile='20000000-0000-4000-8000-000000000001';
const requestId='30000000-0000-4000-8000-000000000001';
const post=(body={action:'delete',request_id:requestId}, token='synthetic-user', origin) => new Request('http://localhost/delete-account', {
  method:'POST',headers:{...(token?{Authorization:'Bearer '+token}:{}),...(origin?{Origin:origin}:{})},body:JSON.stringify(body)});
function fixture(overrides={}) {
  const calls=[];
  const db={authPresent:true,avatarPresent:true,profileStatus:'active',job:null,terminalAudit:0,history:['canonical-task-receipt','retained-horse-data']};
  const project=()=>({...db.job,status:db.profileStatus,code:db.profileStatus==='anonymized'?'ACCOUNT_DELETED':'ACCOUNT_DELETION_PENDING'});
  const ports={
    authenticate:async token=>{calls.push('authenticate');return db.authPresent&&token==='synthetic-user'?{id:actor,identities:[]}:null;},
    trustedResume:token=>token==='synthetic-service',
    prepare:async (id,rid)=>{calls.push('prepare');assert.equal(id,actor);if(!db.job){db.job={correlation_id:rid,profile_id:profile,auth_user_id:id,avatar_paths:[id+'/avatar-one.png']};db.profileStatus='auth_removal_pending';}return project();},
    job:async rid=>{calls.push('job');return db.job?.correlation_id===rid?project():null;},
    removeAvatars:async job=>{calls.push('storage');assert.deepEqual(job.avatar_paths,[actor+'/avatar-one.png']);db.avatarPresent=false;},
    deleteAuth:async id=>{calls.push('deleteAuth');assert.equal(id,actor);db.authPresent=false;},
    finalize:async rid=>{calls.push('finalize');assert.equal(rid,requestId);assert(!db.authPresent&&!db.avatarPresent);if(db.profileStatus!=='anonymized'){db.profileStatus='anonymized';db.terminalAudit++;}return project();},
    ...overrides,
  };
  return {ports,calls,db,project};
}
const result=async(f,body,token)=>{const r=await handleAccountDeletion(post(body,token),f.ports);return {status:r.status,...await r.json()};};
const resume={action:'resume',request_id:requestId};
test('ordinary canonical deletion preserves history and orders DB, Storage, Auth and finalization',async()=>{
  const f=fixture();const before=structuredClone(f.db.history);
  assert.deepEqual(await result(f),{status:200,code:'ACCOUNT_DELETED',request_id:requestId});
  assert.deepEqual(f.calls,['authenticate','prepare','storage','deleteAuth','finalize']);
  assert.deepEqual(f.db.history,before);assert.equal(f.db.profileStatus,'anonymized');assert.equal(f.db.terminalAudit,1);
});
for(const code of ['PRIMARY_ORGANIZATION_ADMIN_REQUIRED','PRIMARY_HORSE_AUTHORITY_REQUIRED','LEGACY_RETENTION_REQUIRED','STORAGE_OWNERSHIP_UNSUPPORTED','ACCOUNT_DELETION_STATE_UNSUPPORTED','DELETION_REQUEST_CONFLICT']) {
  test(code+' refuses before avatar/Auth writes on every retry',async()=>{
    const f=fixture({prepare:async()=>{throw new DeletionFailure(code);}});const before=structuredClone(f.db);
    for(let i=0;i<2;i++)assert.deepEqual(await result(f),{status:409,code});
    assert.deepEqual(f.db,before);assert(!f.calls.includes('storage'));
  });
}
test('structured blocker remains side-effect-free',async()=>{
  const f=fixture({prepare:async()=>({status:'blocked',code:'LEGACY_RETENTION_REQUIRED'})});
  assert.deepEqual(await result(f),{status:409,code:'LEGACY_RETENTION_REQUIRED'});assert.equal(f.db.profileStatus,'active');
});
test('Apple-linked account keeps the existing revocation prerequisite',async()=>{
  const f=fixture({authenticate:async()=>({id:actor,identities:[{provider:'apple'}]})});
  assert.equal((await result(f)).code,'APPLE_REVOCATION_NOT_CONFIGURED');assert.deepEqual(f.calls,[]);assert(f.db.avatarPresent&&f.db.authPresent);
});
for (const providerData of [
  {app_metadata:{provider:'apple'}},
  {identities:null,app_metadata:{provider:'email',providers:['email','apple']}},
  {identities:[],app_metadata:{providers:['apple']}},
]) {
  test('verified Apple provider metadata refuses before preparation: '+JSON.stringify(providerData),async()=>{
    const f=fixture({authenticate:async()=>({id:actor,...providerData})});const before=structuredClone(f.db);
    for(let i=0;i<2;i++)assert.deepEqual(await result(f),{status:409,code:'APPLE_REVOCATION_NOT_CONFIGURED'});
    assert.deepEqual(f.calls,[]);assert.deepEqual(f.db,before);
  });
}
test('editable provider metadata does not replace the verified Auth provider contract',async()=>{
  const f=fixture({authenticate:async()=>({id:actor,identities:[{provider:'email'}],
    app_metadata:{provider:'email',providers:['email']},user_metadata:{provider:'apple',providers:['apple']}})});
  assert.equal((await result(f)).code,'ACCOUNT_DELETED');assert.equal(f.db.terminalAudit,1);
});
for(const status of ['auth_removal_pending','anonymized']) {
  for(const action of ['delete','resume']) {
    test(`legacy identity overlap in ${action}/${status} receipt cannot authorize side effects or success`,async()=>{
      const invalid={code:status==='anonymized'?'ACCOUNT_DELETED':'ACCOUNT_DELETION_PENDING',status,
        correlation_id:requestId,profile_id:actor,auth_user_id:actor,avatar_paths:[actor+'/avatar.png']};
      const f=fixture({prepare:async()=>invalid,job:async()=>invalid});const before=structuredClone(f.db);
      const response=await result(f,{action,request_id:requestId},action==='resume'?'synthetic-service':'synthetic-user');
      assert.equal(response.status,503);assert.equal(response.code,action==='resume'?'DELETION_CHECK_UNAVAILABLE':'DELETION_STATUS_UNAVAILABLE');
      assert.deepEqual(f.db,before);assert(!f.calls.some(call=>['storage','deleteAuth','finalize'].includes(call)));
    });
  }
  test('lost prepare response cannot recover a legacy '+status+' receipt as success',async()=>{
    const f=fixture({prepare:async()=>{throw new Error('lost response');},job:async()=>({
      correlation_id:requestId,profile_id:actor,auth_user_id:actor,avatar_paths:[],status,code:'ACCOUNT_DELETION_PENDING'})});
    const before=structuredClone(f.db);assert.deepEqual(await result(f),{status:503,code:'DELETION_STATUS_UNAVAILABLE'});
    assert.deepEqual(f.db,before);assert(!f.calls.some(call=>['storage','deleteAuth','finalize'].includes(call)));
  });
}
for(const [name,body] of [['old empty blocker check',{}],['wrong action',{action:'check'}],['no explicit action',{request_id:requestId}]]) {
  test(name+' never becomes deletion consent',async()=>{const f=fixture();assert.equal((await result(f,body)).code,'DELETION_CONFIRMATION_REQUIRED');assert.deepEqual(f.calls,[]);});
}
for(const body of [{action:'delete',request_id:'bad'},{action:'delete',request_id:requestId,user_id:other},{action:'delete',request_id:requestId,profile_id:profile},['delete'],null]) {
  test('malformed or supplied actor input rejected: '+JSON.stringify(body),async()=>{const f=fixture();assert.equal((await result(f,body)).status,400);assert.deepEqual(f.calls,[]);});
}
test('missing and invalid sessions cannot prepare',async()=>{
  const f=fixture();assert.equal((await result(f,undefined,'')).status,401);assert.equal((await result(f,undefined,'invalid')).status,401);assert.deepEqual(f.calls,['authenticate']);
});
test('user token and forged service claim cannot resume a privileged job',async()=>{
  const f=fixture();for(const token of ['synthetic-user','forged-service-role-claim'])assert.equal((await result(f,resume,token)).status,403);assert.deepEqual(f.calls,[]);
});
test('service resume cannot invent a job',async()=>{const f=fixture();assert.equal((await result(f,resume,'synthetic-service')).status,404);assert.deepEqual(f.calls,['job']);});
test('Storage failure retains Auth and a resumable prepared job',async()=>{
  const f=fixture();const original=f.ports.removeAvatars;f.ports.removeAvatars=async()=>{f.calls.push('storageFailure');throw new Error('synthetic');};
  assert.equal((await result(f)).code,'ACCOUNT_DELETION_PENDING');assert(f.db.authPresent&&f.db.avatarPresent);assert.equal(f.db.profileStatus,'auth_removal_pending');assert(!f.calls.includes('deleteAuth'));
  f.ports.removeAvatars=original;assert.equal((await result(f,resume,'synthetic-service')).code,'ACCOUNT_DELETED');assert.equal(f.db.terminalAudit,1);
});
test('Auth failure does not roll back preparation and repeats the same safe avatar cleanup',async()=>{
  const f=fixture();const original=f.ports.deleteAuth;f.ports.deleteAuth=async()=>{throw new Error('synthetic');};
  assert.equal((await result(f)).status,202);assert(f.db.authPresent&&!f.db.avatarPresent);assert.equal(f.db.terminalAudit,0);
  f.ports.deleteAuth=original;assert.equal((await result(f)).status,200);assert.equal(f.db.terminalAudit,1);
});
test('lost Auth response resumes after the real identity is already gone',async()=>{
  const f=fixture();const original=f.ports.deleteAuth;f.ports.deleteAuth=async id=>{await original(id);throw new Error('lost response');};
  assert.equal((await result(f)).status,202);assert(!f.db.authPresent);assert.equal((await result(f)).status,401);
  f.ports.deleteAuth=original;assert.equal((await result(f,resume,'synthetic-service')).status,200);assert.equal(f.db.terminalAudit,1);
});
test('finalization failure never claims deletion and service retry finalizes once',async()=>{
  const f=fixture();const original=f.ports.finalize;f.ports.finalize=async()=>{throw new Error('synthetic');};
  assert.equal((await result(f)).status,202);assert(!f.db.authPresent&&!f.db.avatarPresent);assert.equal(f.db.terminalAudit,0);
  f.ports.finalize=original;assert.equal((await result(f,resume,'synthetic-service')).status,200);assert.equal((await result(f,resume,'synthetic-service')).status,200);assert.equal(f.db.terminalAudit,1);
});
test('committed preparation with lost HTTP response is recovered without guessing',async()=>{
  const f=fixture();const original=f.ports.prepare;f.ports.prepare=async(...args)=>{await original(...args);throw new Error('lost response');};
  assert.equal((await result(f)).status,202);assert.deepEqual(f.calls,['authenticate','prepare','job']);assert(f.db.avatarPresent&&f.db.authPresent);
  assert.equal((await result(f,resume,'synthetic-service')).status,200);
});
test('unknown preparation result is uncertainty, not false success or false unchanged claim',async()=>{
  const f=fixture({prepare:async()=>{throw new Error('timeout');},job:async()=>{throw new Error('readback timeout');}});
  assert.deepEqual(await result(f),{status:503,code:'DELETION_STATUS_UNAVAILABLE'});assert.equal(f.db.profileStatus,'active');
});
test('a receipt belonging to another actor cannot authorize cleanup or a pending success',async()=>{
  const f=fixture();f.ports.prepare=async()=>({correlation_id:requestId,profile_id:profile,auth_user_id:other,avatar_paths:[],status:'auth_removal_pending',code:'ACCOUNT_DELETION_PENDING'});
  assert.equal((await result(f)).status,503);assert(!f.calls.includes('storage'));assert(f.db.authPresent);
});
for(const status of ['auth_removal_pending','anonymized']){
  const wrongId='30000000-0000-4000-8000-000000000099';
  const wrongJob={correlation_id:wrongId,profile_id:profile,auth_user_id:actor,avatar_paths:[],status,code:status==='anonymized'?'ACCOUNT_DELETED':'ACCOUNT_DELETION_PENDING'};
  test('resume cannot acknowledge a different request receipt in '+status,async()=>{
    const f=fixture({job:async()=>wrongJob}),before=structuredClone(f.db);
    assert.deepEqual(await result(f,resume,'synthetic-service'),{status:503,code:'DELETION_CHECK_UNAVAILABLE'});
    assert.deepEqual(f.db,before);assert(!f.calls.some(call=>['storage','deleteAuth','finalize'].includes(call)));
  });
  test('lost preparation cannot recover a different request receipt in '+status,async()=>{
    const f=fixture({prepare:async()=>{throw Error('Lost response');},job:async()=>wrongJob}),before=structuredClone(f.db);
    assert.deepEqual(await result(f),{status:503,code:'DELETION_STATUS_UNAVAILABLE'});
    assert.deepEqual(f.db,before);assert(!f.calls.some(call=>['storage','deleteAuth','finalize'].includes(call)));
  });
}
test('verified prepare may return the existing same-actor job under its original correlation ID',async()=>{
  const originalId='30000000-0000-4000-8000-000000000098';
  const existing={correlation_id:originalId,profile_id:profile,auth_user_id:actor,avatar_paths:[actor+'/avatar-one.png'],status:'auth_removal_pending',code:'ACCOUNT_DELETION_PENDING'};
  const f=fixture({prepare:async()=>existing,finalize:async rid=>{assert.equal(rid,originalId);return {...existing,status:'anonymized',code:'ACCOUNT_DELETED'};}});
  assert.deepEqual(await result(f),{status:200,code:'ACCOUNT_DELETED',request_id:originalId});
  assert.deepEqual(f.calls,['authenticate','storage','deleteAuth']);
});
for(const path of [other+'/avatar.png',actor+'/../horse-media/item',actor+'/./item']) {
  test('untrusted avatar path cannot reach Storage: '+path,async()=>{
    const f=fixture();const original=f.ports.prepare;f.ports.prepare=async(...args)=>({...await original(...args),avatar_paths:[path]});
    assert.equal((await result(f)).status,503);assert(!f.calls.includes('storage'));
  });
}
test('unfinished or mismatched finalization response cannot claim terminal success',async()=>{
  const f=fixture();f.ports.finalize=async()=>f.project();assert.equal((await result(f)).status,202);assert.equal(f.db.terminalAudit,0);
});
test('two overlapping handlers share the same durable operation and terminal receipt',async()=>{
  const f=fixture();const both=await Promise.all([result(f),result(f)]);assert(both.every(r=>r.status===200));assert.equal(f.db.terminalAudit,1);assert.deepEqual(f.db.history,['canonical-task-receipt','retained-horse-data']);
});
test('configured CORS rejects foreign origin before any work and returns an exact allowed origin',async()=>{
  const f=fixture();const origins=['https://preview.example'];
  const blocked=await handleAccountDeletion(post(undefined,'synthetic-user','https://other.example'),f.ports,origins);
  assert.equal(blocked.status,403);assert.equal(blocked.headers.get('Access-Control-Allow-Origin'),null);assert.deepEqual(f.calls,[]);
  const accepted=await handleAccountDeletion(new Request('http://localhost',{method:'OPTIONS',headers:{Origin:origins[0]}}),f.ports,origins);
  assert.equal(accepted.headers.get('Access-Control-Allow-Origin'),origins[0]);assert.equal(accepted.headers.get('Vary'),'Origin');assert(accepted.headers.get('Access-Control-Allow-Headers').includes('x-supabase-api-version'));
});
test('server requests without Origin need no browser CORS permission',async()=>{
  const f=fixture();const r=await handleAccountDeletion(new Request('http://localhost'),f.ports,[]);assert.equal(r.status,405);assert.equal(r.headers.get('Access-Control-Allow-Origin'),null);assert.deepEqual(f.calls,[]);
});
