import test from 'node:test';
import assert from 'node:assert/strict';
import {createBackendClient} from '../../../apps/avaryn/src/backend-client.js';
import {consumeEmailCallback,renderAuth} from '../../../apps/avaryn/src/auth-ui.js';

const A='10000000-0000-4000-8000-000000000001',B='10000000-0000-4000-8000-000000000002';
const KEY='avaryn-v8-real-auth-v1',EMAIL='synthetic-auth@example.invalid',PASSWORD='Synthetic-only-123456!';
const TOKEN='synthetic-confirmation-token-hash';
const tick=()=>new Promise(resolve=>setImmediate(resolve));
const defer=()=>{let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};};
const authSession=(actor=A,confirmed=true)=>({access_token:'synthetic-access-'+actor,refresh_token:'synthetic-refresh-'+actor,expires_at:Date.now()/1000+3600,user:{id:actor,email_confirmed_at:confirmed?'2026-09-11T12:00:00Z':null}});
function fixture(override){
 const memory=new Map(),calls=[];
 const storage={getItem:async k=>memory.get(k),setItem:async(k,v)=>memory.set(k,v),removeItem:async k=>memory.delete(k)};
 const fetchImpl=async(url,options)=>{
  const body=options.body?JSON.parse(options.body):null;calls.push({url,options,body});
  if(override){const value=await override(url,body,options);if(value!==undefined)return value;}
  if(url.includes('grant_type=password'))return Response.json(authSession(body.email==='B'?B:A));
  if(url.endsWith('/verify'))return Response.json(authSession());
  if(url.endsWith('/logout?scope=local'))return new Response(null,{status:204});
  return Response.json({});
 };
 return {memory,calls,client:createBackendClient({storage,fetchImpl,timeoutMs:200})};
}
function callback(path){
 const calls=[];const location={href:'https://avaryn.example.invalid'+path};
 const history={replaceState:(state,title,url)=>{calls.push({state,title,url});location.href=new URL(url,location.href).href;}};
 return {calls,location,history};
}
for(const [path,type] of [['/auth/callback','email'],['/auth/reset-password','recovery']])test('callback '+type+' moves secret to RAM and erases query/fragment before returning',()=>{
 const h=callback(`${path}?token_hash=${TOKEN}&type=${type}#old-secret`);const value=consumeEmailCallback(h.location,h.history);
 assert.equal(value.type,type);assert.equal(value.tokenHash===TOKEN,true);assert.deepEqual(h.calls,[{state:null,title:'',url:'/#/vandaag'}]);
 assert.equal(h.location.href.includes(TOKEN),false);assert.equal(consumeEmailCallback(h.location,h.history),null);
});
for(const query of ['type=email','token_hash=short&type=email',`token_hash=${TOKEN}&type=invite`,`token_hash=${encodeURIComponent('white space token'.repeat(2))}&type=email`,`token_hash=${'x'.repeat(2049)}&type=email`])test('invalid callback is erased without returning credentials: '+query.slice(-12),()=>{
 const h=callback('/auth/callback?'+query);assert.deepEqual(consumeEmailCallback(h.location,h.history),{invalid:true});assert.equal(h.location.href,'https://avaryn.example.invalid/#/vandaag');
});
test('implicit-flow access tokens are removed and never accepted as confirmed session',()=>{
 const h=callback('/auth/callback#access_token=synthetic&refresh_token=synthetic');assert.deepEqual(consumeEmailCallback(h.location,h.history),{invalid:true});assert.equal(h.location.href,'https://avaryn.example.invalid/#/vandaag');
});
test('ordinary routes are not treated as callback or rewritten',()=>{
 const h=callback('/other?token_hash='+TOKEN+'&type=email');assert.equal(consumeEmailCallback(h.location,h.history),null);assert.deepEqual(h.calls,[]);
});
test('callback consumes no logging channel and auth rendering never embeds tokenHash',()=>{
 const messages=[],originals={};for(const key of ['log','warn','error','info']){originals[key]=console[key];console[key]=(...v)=>messages.push(v);}
 try{const h=callback('/auth/callback?token_hash='+TOKEN+'&type=email');consumeEmailCallback(h.location,h.history);assert.deepEqual(messages,[]);
  const html=renderAuth({mode:'verify',tokenHash:TOKEN,email:EMAIL});assert.equal(html.includes(TOKEN),false);assert.equal(html.includes('name="token"'),false);
 }finally{for(const key of Object.keys(originals))console[key]=originals[key];}
});
test('signup requires configured password length before making a request',async()=>{
 const f=fixture();await assert.rejects(f.client.signUp(EMAIL,'short'),e=>e.code==='INPUT_INVALID');assert.equal(f.calls.length,0);
});
test('signup does not persist a returned session or claim email confirmation',async()=>{
 const f=fixture(url=>url.endsWith('/signup')?Response.json(authSession()):undefined);
 assert.equal(await f.client.signUp(EMAIL,PASSWORD),true);assert.equal(f.memory.size,0);await assert.rejects(f.client.load(),e=>e.code==='AUTH_REQUIRED');
 const c=f.calls[0];assert.equal(c.url,'/api/auth/v1/signup');assert.deepEqual(c.body,{email:EMAIL,password:PASSWORD});assert.equal(c.options.headers.Authorization,undefined);
});
test('recovery and resend use public Auth requests even when another account is logged in',async()=>{
 const f=fixture();await f.client.login('B',PASSWORD);await f.client.recover(EMAIL);await f.client.resend(EMAIL);
 for(const c of f.calls.slice(-2))assert.equal(c.options.headers.Authorization,undefined);
 assert.deepEqual(f.calls.at(-2).body,{email:EMAIL});assert.deepEqual(f.calls.at(-1).body,{type:'signup',email:EMAIL});
 assert.equal(JSON.parse(f.memory.get(KEY)).user_id,B);
});
for(const input of [{email:EMAIL,token:'123456',type:'email'},{tokenHash:TOKEN,type:'email'},{tokenHash:TOKEN,type:'recovery'}])test('email verification persists only a confirmed Auth session: '+(input.token?'otp':input.type),async()=>{
 const f=fixture();assert.equal(await f.client.verifyEmail(input),true);assert.equal(JSON.parse(f.memory.get(KEY)).user_id,A);
 const expected=input.token?{email:EMAIL,token:'123456',type:'email'}:{token_hash:TOKEN,type:input.type};assert.deepEqual(f.calls.at(-1).body,expected);assert.equal(f.calls.at(-1).options.headers.Authorization,undefined);
});
for(const code of ['otp_expired','invalid_token'])test('invalid or replayed email token never creates a session: '+code,async()=>{
 const f=fixture(()=>Response.json({code,message:code},{status:403}));await assert.rejects(f.client.verifyEmail({tokenHash:TOKEN}),e=>e.status===403);
 assert.equal(f.memory.size,0);await assert.rejects(f.client.load(),e=>e.code==='AUTH_REQUIRED');
});
// Exact managed Auth /verify response observed with a dummy token on 2026-09-12.
// This checks response handling, not elapsed token lifetime or a live replay.
const PROVIDER_OTP_ERROR={code:'otp_expired',message:'Email link is invalid or has expired'};
const OTP_MESSAGE='Deze code of link is ongeldig, verlopen of al gebruikt. Vraag een nieuwe e-mail aan.';
for(const type of ['email','recovery'])test('verified provider token copy for '+type+' preserves failed-verification session boundary',async()=>{
 const f=fixture(url=>url.endsWith('/verify')?Response.json(PROVIDER_OTP_ERROR,{status:403}):undefined);
 await f.client.login('B',PASSWORD);
 await assert.rejects(f.client.verifyEmail({tokenHash:TOKEN,type}),e=>{
  assert.equal(e.status,403);assert.equal(e.message,OTP_MESSAGE);assert.equal(e.code,'otp_expired');
  assert.equal(e.accessLost,false);assert.equal(e.uncertain,false);
  const html=renderAuth({mode:type==='recovery'?'recovery':'verify',message:e.message,tokenHash:TOKEN});
  assert.ok(html.includes(OTP_MESSAGE));assert.equal(html.includes(TOKEN),false);assert.equal(html.includes(PROVIDER_OTP_ERROR.message),false);return true;
 });
 assert.equal(f.memory.size,0);await assert.rejects(f.client.load(),e=>e.code==='AUTH_REQUIRED');
 assert.equal(f.calls.filter(c=>c.url.endsWith('/verify')).length,1,'No automatic token replay');
});
for(const scenario of [
 {name:'RPC provider-shaped error remains an access failure',path:'/get_current_account_profile',operation:c=>c.load(),body:PROVIDER_OTP_ERROR,status:403,accessLost:true},
 {name:'other Auth endpoint is not normalized',path:'/recover',operation:c=>c.recover(EMAIL),body:PROVIDER_OTP_ERROR,status:403,accessLost:true},
 {name:'SQL42501 remains an access failure',path:'/verify',operation:c=>c.verifyEmail({tokenHash:TOKEN}),body:{code:'42501',message:'PERMISSION_DENIED'},status:403,accessLost:true},
 {name:'unknown provider code never matches by English message',path:'/verify',operation:c=>c.verifyEmail({tokenHash:TOKEN}),body:{code:'unproven_token_code',message:PROVIDER_OTP_ERROR.message},status:403,accessLost:true},
 {name:'server failure retains uncertain retry handling',path:'/verify',operation:c=>c.verifyEmail({tokenHash:TOKEN}),body:PROVIDER_OTP_ERROR,status:503,accessLost:false,uncertain:true},
])test('token copy scope: '+scenario.name,async()=>{
 const f=fixture(url=>url.endsWith(scenario.path)?Response.json(scenario.body,{status:scenario.status}):undefined);
 await f.client.login('B',PASSWORD);
 await assert.rejects(scenario.operation(f.client),e=>{
  assert.equal(e.status,scenario.status);assert.equal(e.accessLost,scenario.accessLost);assert.equal(e.uncertain,Boolean(scenario.uncertain));assert.notEqual(e.message,OTP_MESSAGE);
  if(scenario.accessLost)assert.equal(e.message,'Je hebt geen toegang tot deze handeling. Laad de actuele gegevens.');return true;
 });
});
for(const value of [authSession(A,false),{user:{id:A,email_confirmed_at:'2026-09-11T12:00:00Z'}}])test('incomplete verify response does not falsely confirm an account: '+Boolean(value.access_token),async()=>{
 const f=fixture(()=>Response.json(value));await assert.rejects(f.client.verifyEmail({tokenHash:TOKEN}));assert.equal(f.memory.size,0);
});
test('late verify response cannot overwrite a later B login',async()=>{
 const gate=defer(),f=fixture(url=>url.endsWith('/verify')?gate.promise:undefined);
 const old=assert.rejects(f.client.verifyEmail({tokenHash:TOKEN}),e=>e.code==='STALE_CONTEXT');await tick();await f.client.login('B',PASSWORD);
 gate.resolve(Response.json(authSession(A)));await old;assert.equal(JSON.parse(f.memory.get(KEY)).user_id,B);
});
test('password update requires a session and strong input; no false successful anonymous update',async()=>{
 const f=fixture();await assert.rejects(f.client.updatePassword(PASSWORD),e=>e.code==='AUTH_REQUIRED');await f.client.login(EMAIL,PASSWORD);
 await assert.rejects(f.client.updatePassword('short'),e=>e.code==='INPUT_INVALID');await f.client.updatePassword(PASSWORD);
 assert.equal(f.calls.at(-1).options.method,'PUT');assert.equal(f.calls.at(-1).url,'/api/auth/v1/user');assert.deepEqual(f.calls.at(-1).body,{password:PASSWORD});
});
test('password update finishing after logout cannot report current-account success',async()=>{
 const gate=defer(),f=fixture((url,_body,options)=>url.endsWith('/user')&&options.method==='PUT'?gate.promise:undefined);await f.client.login(EMAIL,PASSWORD);
 const pending=assert.rejects(f.client.updatePassword(PASSWORD),e=>e.code==='STALE_CONTEXT');await tick();await f.client.logout();gate.resolve(Response.json({id:A}));await pending;assert.equal(f.memory.size,0);
});
test('signup transport failure is uncertain and never retried automatically',async()=>{
 const f=fixture(()=>{throw Error('synthetic offline');});await assert.rejects(f.client.signUp(EMAIL,PASSWORD),e=>e.code==='NETWORK'&&e.uncertain);assert.equal(f.calls.length,1);assert.equal(f.memory.size,0);
});

// Explicitly opt-in: one newly created local synthetic actor, never existing fixtures.
test('LIVE isolated signup, confirmation, token refusal/replay and profile read', {skip:process.env.AVARYN_AUTH_LIVE!=='1'}, async()=>{
 const {readFile,writeFile,chmod,stat}=await import('node:fs/promises');
 const {randomUUID,randomBytes,createHash}=await import('node:crypto');
 const {resolve}=await import('node:path');
 const root=resolve(import.meta.dirname,'../../..'),base=resolve(root,'.avaryn-local/productization-20260911');
 const configBytes=await readFile(resolve(base,'private/dev-vitality-server.json'));
 assert.equal(createHash('sha256').update(configBytes).digest('hex'),'3147d7f72179b3acb09e8a404f10843b0461de24f5c441829f753e612978b830');
 const config=JSON.parse(configBytes);const upstream=new URL(config.upstream);
 assert.equal(config.projectId,'avaryn-c010-vitality-20260911-a');
 assert.equal(upstream.origin,'http://127.0.0.1:56801');assert.equal(upstream.pathname,'/');assert.equal(upstream.search,'');assert.equal(upstream.username,'');assert.equal(upstream.password,'');
 assert.equal(config.allowAuthRegistration,true);assert.equal(typeof config.anonKey,'string');assert(config.anonKey.length>20);
 const runId=randomUUID(),email=`product-auth-${runId}@example.invalid`,password=randomBytes(28).toString('base64url');
 const privatePath=resolve(base,`private/auth-fixture-${runId}.json`),evidencePath=resolve(base,'evidence/auth-live-http.json');
 const fixture={runId,target:config.projectId,apiOrigin:upstream.origin,email,password,created:false,confirmed:false};
 const checks=[],requests=[],sessions=[];let failed=false,step='setup';
 const keep=async()=>{await writeFile(privatePath,JSON.stringify(fixture,null,2)+'\n',{mode:0o600});await chmod(privatePath,0o600);};
 await keep();assert.equal((await stat(privatePath)).mode&0o777,0o600);
 const fetchImpl=async(path,options)=>{
  assert.equal(path.startsWith('/api/'),true);const target=new URL(path.slice(4),upstream);
  assert.equal(target.origin,upstream.origin);
  const response=await fetch(target,{...options,redirect:'error',headers:{...options.headers,apikey:config.anonKey,Origin:upstream.origin}});
  requests.push({method:options.method||'GET',path:target.pathname,status:response.status});
  if(target.pathname==='/auth/v1/signup'&&response.ok){const value=await response.clone().json();const user=value.user||value;fixture.created=Boolean(user.id);fixture.userId=user.id;await keep();}
  return response;
 };
 const makeClient=()=>{const values=new Map();const storage={getItem:async key=>values.get(key),setItem:async(key,value)=>values.set(key,value),removeItem:async key=>values.delete(key)};const client=createBackendClient({baseUrl:'/api',fetchImpl,storage,timeoutMs:10000});sessions.push({client,values});return {client,values};};
 const checked=(name,condition)=>{step=name;assert.equal(Boolean(condition),true,name);checks.push({name,status:'PASS'});};
 const expectDenied=async(client,operation,name)=>{step=name;let error;try{await operation();}catch(e){error=e;}checked(name,Boolean(error)&&[400,401,403,422].includes(error.status));};
 const primary=makeClient();
 try{
  step='signup';checked('Signup accepted with confirmation required',await primary.client.signUp(email,password));
  checked('Signup response creates no authenticated local session',primary.values.size===0);
  await expectDenied(primary.client,()=>primary.client.login(email,password),'Unconfirmed password login denied');
  checked('Unconfirmed denial retains no local session',primary.values.size===0);
  step='own confirmation mail';let message;
  for(let attempt=0;attempt<24;attempt++){
   const search=new URL('http://127.0.0.1:56804/api/v1/search');search.searchParams.set('query','to:'+email);search.searchParams.set('limit','10');
   const found=await fetch(search,{redirect:'error',signal:AbortSignal.timeout(5000)});if(!found.ok)throw Error('Synthetic mailbox unavailable');
   const data=await found.json();message=(data.messages||[]).find(m=>(m.To||[]).some(to=>to.Address===email));
   if(message)break;await new Promise(r=>setTimeout(r,250));
  }
  checked('Confirmation mail reached only the exact synthetic recipient',Boolean(message));
  const mailResponse=await fetch('http://127.0.0.1:56804/api/v1/message/'+encodeURIComponent(message.ID),{redirect:'error',signal:AbortSignal.timeout(5000)});
  checked('Own confirmation message readable',mailResponse.ok);const mail=await mailResponse.json();
  const text=String(mail.Text||'')+'\n'+String(mail.HTML||'').replaceAll('&amp;','&');
  const links=[...text.matchAll(/https?:\/\/[^\s"<>]+/g)].map(match=>{try{return new URL(match[0]);}catch{return null;}}).filter(Boolean);
  const link=links.find(url=>url.searchParams.has('token_hash')||url.searchParams.has('token'));
  checked('Own mail contains a verification capability',Boolean(link));
  const tokenHash=link.searchParams.get('token_hash')||link.searchParams.get('token');
  const type=link.searchParams.get('type')==='signup'?'email':link.searchParams.get('type');
  checked('Confirmation capability has supported type',type==='email');fixture.mailMessageId=message.ID;await keep();
  const wrong=makeClient();await expectDenied(wrong.client,()=>wrong.client.verifyEmail({tokenHash:randomBytes(32).toString('hex'),type}),'Incorrect email token denied');
  checked('Incorrect token creates no authenticated local session',wrong.values.size===0);
  step='valid confirmation';checked('Actual email confirmation accepted',await primary.client.verifyEmail({tokenHash,type}));fixture.confirmed=true;await keep();
  checked('Confirmed session belongs to only the created actor',JSON.parse(primary.values.get(KEY)).user_id===fixture.userId);
  step='profile read';const view=await primary.client.load({organizationId:null});
  checked('Confirmed actor can read its canonical active profile',Boolean(view.backend.actor.id)&&view.backend.connected===true);
  checked('Fresh actor has no inherited horse or stable data',view.horses.length===0&&view.backend.organizations.length===0);fixture.profileId=view.backend.actor.id;await keep();
  const replay=makeClient();await expectDenied(replay.client,()=>replay.client.verifyEmail({tokenHash,type}),'Consumed confirmation token replay denied');
  checked('Replayed token creates no authenticated local session',replay.values.size===0);
  checked('Valid account remains usable after a separate replay refusal',(await primary.client.load({organizationId:null})).backend.actor.id===fixture.profileId);
 }catch(error){failed=true;fixture.failedStep=step;throw new Error('Isolated Auth gate failed at: '+step,{cause:undefined});}
 finally{
  for(const entry of sessions){if(entry.values.size){try{await entry.client.logout();}catch{failed=true;checks.push({name:'Synthetic session logout',status:'FAIL'});}}}
  fixture.runStatus=failed?'FAIL':'PASS';await keep();
  const sourceFiles=['apps/avaryn/src/backend-client.js','apps/avaryn/src/auth-ui.js','tool/productization/tests/auth.test.mjs'];const hashes={};for(const file of sourceFiles)hashes[file]=createHash('sha256').update(await readFile(resolve(root,file))).digest('hex');
  const receipt={status:failed?'FAIL':'PASS',checkedAt:new Date().toISOString(),target:config.projectId,apiOrigin:upstream.origin,mailOrigin:'http://127.0.0.1:56804',configSha256:createHash('sha256').update(configBytes).digest('hex'),sourceSha256:hashes,checks,checkCount:checks.length,requests,privateFixture:privatePath,syntheticAccountRetained:true,allLocalSessionsCleared:sessions.every(s=>s.values.size===0),limits:['Local synthetic HTTP only; no browser or external SMTP.','Recover/resend/updatePassword are unit-tested here; no claim those flows were exercised by this signup run.','No existing fixtures, grants, domain records, Auth configuration or schema changed.']};
  await writeFile(evidencePath,JSON.stringify(receipt,null,2)+'\n');
 }
});
