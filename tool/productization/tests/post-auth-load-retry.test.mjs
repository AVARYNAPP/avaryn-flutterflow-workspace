import test from 'node:test';
import assert from 'node:assert/strict';
import {createBackendController} from '../../../apps/avaryn/src/backend-controller.js';
import {createP2Client} from '../../../apps/avaryn/src/p2-client.js';
import {renderLoadRecovery} from '../../../apps/avaryn/src/auth-ui.js';

const A='10000000-0000-4000-8000-000000000001',B='10000000-0000-4000-8000-000000000002';
const DAY='2026-09-12',PAST='2026-09-10';
const tick=()=>new Promise(r=>setImmediate(r));
const deferred=()=>{let resolve;const promise=new Promise(r=>{resolve=r;});return {promise,resolve};};

function fixture(t,{restore=false,timeoutMs=3000}={}){
 const calls=[],routes=[],memory=new Map(),local=new Map(),gates=[];
 const settings={p2Status:504,coreStatus:200,authStatus:200,userStatus:200,delayP2:false,network:false,preferences:null};
 const access=id=>'synthetic-access-'+id;
 const session=id=>({access_token:access(id),refresh_token:'synthetic-refresh-'+id,expires_in:3600,user:{id,email_confirmed_at:'2026-09-01T00:00:00Z'}});
 if(restore)memory.set('avaryn-v8-real-auth-v1',JSON.stringify({...session(A),user_id:A,expires_at:Math.floor(Date.now()/1000)+3600}));
 let state={theme:'light',route:'today',today:DAY,selectedDay:DAY,horses:[],tasks:[],activities:[],feeding:{},team:[]},restoredRoutes=0;
 const names=['document','localStorage','location','history','FormData'];
 const prior=Object.fromEntries(names.map(k=>[k,Object.getOwnPropertyDescriptor(globalThis,k)])),NativeFormData=globalThis.FormData;
 const set=(key,value)=>Object.defineProperty(globalThis,key,{configurable:true,writable:true,value});
 set('document',{getElementById:()=>null,querySelector:()=>null});
 set('localStorage',{getItem:k=>local.get(k)??null,setItem:(k,v)=>local.set(k,v)});
 set('location',new URL('https://avaryn.example.invalid/'));set('history',{replaceState(){}});
 set('FormData',class{constructor(form){const data=new NativeFormData();for(const [k,v]of Object.entries(form.values||{}))data.append(k,v);return data;}});
 t.after(()=>{for(const key of names){if(prior[key])Object.defineProperty(globalThis,key,prior[key]);else delete globalThis[key];}});
 const storage={getItem:k=>memory.get(k)??null,setItem:(k,v)=>memory.set(k,v),removeItem:k=>memory.delete(k)};
 const fetchImpl=async(path,options)=>{
  const body=options.body?JSON.parse(options.body):null,actor=options.headers.Authorization==='Bearer '+access(B)?B:A;
  calls.push({path,method:options.method,actor});
  if(path.includes('/token?grant_type=password'))return settings.authStatus===200?Response.json(session(body.email.startsWith('b@')?B:A)):Response.json({code:'UPSTREAM_TIMEOUT'},{status:settings.authStatus});
  if(path.endsWith('/auth/v1/user'))return settings.userStatus===200?Response.json({id:actor}):Response.json({code:'UPSTREAM_TIMEOUT'},{status:settings.userStatus});
  if(path.endsWith('/logout?scope=local'))return new Response(null,{status:204});
  const name=path.split('/').at(-1);
  if(name==='get_my_c010_function_profile'){
   const status=settings.p2Status,prefs=settings.preferences,network=settings.network;
   if(settings.delayP2){const gate=deferred();gates.push(gate);await gate.promise;}
   if(network)throw new TypeError('Synthetic network failure');
   return status===200?Response.json(prefs||{profile_id:actor,functions:['rider'],row_version:1}):Response.json({code:'UPSTREAM_TIMEOUT'},{status});
  }
  if(name==='get_current_account_profile')return settings.coreStatus===200?Response.json([{profile_id:actor,profile_status:'active',display_name:'Synthetic '+(actor===A?'A':'B'),time_zone:'Europe/Amsterdam',row_version:1,onboarding_completed_at:'2026-09-01T00:00:00Z'}]):Response.json({code:'DENIED'},{status:settings.coreStatus});
  if(name==='get_c010_personal_day')return Response.json({on_date:DAY,calendar:{today_date:DAY,time_zone:'Europe/Amsterdam'},items:[]});
  if(['list_c010_horses','list_c010_stables'].includes(name))return Response.json([]);
  assert.fail('Unexpected synthetic request '+path);
 };
 let controller;
 const p2=createP2Client({request:(...args)=>controller.apiRequest(...args)});
 controller=createBackendController({getState:()=>state,setState:v=>{state=v;},render(){},save(){},navigate:r=>{routes.push(r);state.route=r;},showModal(){},closeModal(){},toast(){},restoreRoute(){restoredRoutes++;},augmentLoad:s=>p2.load(s),clientOptions:{storage,fetchImpl,timeoutMs}});
 const action=name=>controller.handleAction(name,{dataset:{}});
 return {controller,calls,routes,memory,settings,gates,action,get state(){return state;},get restoredRoutes(){return restoredRoutes;},screen:()=>controller.getScreen(),async login(actor='a'){controller.handleSubmit({id:'auth-login-form',values:{email:actor+'@example.invalid',password:'Synthetic-password-only'}},{preventDefault(){}});await tick();await tick();},async retry(){action('load-retry');await tick();await tick();}};
}

test('actual client login then P2 function-profile504 offers full-load retry instead of a login form',async t=>{
 const h=fixture(t);await h.login();
 assert.equal(h.calls.filter(c=>c.path.includes('/rest/')).length,5);
 assert.equal(h.memory.size,1,'The successfully persisted session is retained');
 assert.equal(h.state.backend,undefined);assert.deepEqual(h.state.horses,[]);
 assert.match(h.screen(),/data-action="load-retry"/);
 assert.match(h.screen(),/Opnieuw laden/);assert.doesNotMatch(h.screen(),/auth-login-form|name="password"|auth-verify-form/);
});

test('retry rereads all core and P2 data with the retained session, without another authentication request',async t=>{
 const h=fixture(t);await h.login();const stored=[...h.memory.values()][0];
 h.settings.p2Status=200;await h.retry();
 assert.equal(h.screen(),null);assert.equal(h.state.backend.actor.id,A);
 assert.deepEqual(h.state.functionProfiles,{[A]:['rider']});assert.equal(h.state.functionProfileRowVersion,1);
 assert.equal(h.calls.filter(c=>c.path.includes('/token?')).length,1);
 assert.equal(h.calls.filter(c=>c.path.includes('/rest/')).length,10);assert.equal([...h.memory.values()][0],stored);
 assert.deepEqual(h.routes,['today']);
});

test('two retry clicks start exactly one full read while loading',async t=>{
 const h=fixture(t);await h.login();h.settings.p2Status=200;h.settings.delayP2=true;
 await h.retry();const count=h.calls.length;h.action('load-retry');await tick();
 assert.equal(h.gates.length,1);assert.equal(h.calls.length,count);assert.match(h.screen(),/Je dag wordt klaargezet/);
 h.gates[0].resolve();await tick();assert.equal(h.screen(),null);
});

test('another transient retry failure stays empty and waits for an explicit retry',async t=>{
 const h=fixture(t);await h.login();await h.retry();const count=h.calls.length;await tick();
 assert.equal(h.calls.length,count);assert.equal(h.state.backend,undefined);assert.equal(h.memory.size,1);
 assert.match(h.screen(),/load-retry/);assert.deepEqual(h.routes,[]);
});

test('logout from recovery clears the session and makes an old retry button inert',async t=>{
 const h=fixture(t);await h.login();h.action('logout');await tick();const count=h.calls.length;await h.retry();
 assert.equal(h.calls.length,count);assert.equal(h.memory.size,0);assert.equal(h.state.backend,undefined);
 assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/load-retry/);
});

test('logout during delayed retry prevents old data or success navigation returning',async t=>{
 const h=fixture(t);await h.login();h.settings.p2Status=200;h.settings.delayP2=true;await h.retry();
 h.action('logout');h.gates[0].resolve();await tick();await tick();
 assert.equal(h.state.backend,undefined);assert.equal(h.memory.size,0);assert.deepEqual(h.routes,[]);
 assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/load-retry/);
});

for(const status of [200,504])test('late actorA retry '+status+' cannot replace a newer actorB session or view',async t=>{
 const h=fixture(t);await h.login();h.settings.p2Status=status;h.settings.delayP2=true;await h.retry();
 h.action('logout');await tick();h.settings.delayP2=false;h.settings.p2Status=200;await h.login('b');
 assert.equal(h.state.backend.actor.id,B);h.gates[0].resolve();await tick();await tick();
 assert.equal(h.state.backend.actor.id,B);assert.deepEqual(h.state.functionProfiles,{[B]:['rider']});
 assert.equal(h.screen(),null);assert.deepEqual(h.routes,['today']);
 assert.equal(JSON.parse([...h.memory.values()][0]).user_id,B);
});

test('restored session with P2 failure retries data only and restores the requested route after success',async t=>{
 const h=fixture(t,{restore:true});await h.controller.init();assert.match(h.screen(),/load-retry/);
 assert.equal(h.restoredRoutes,0);h.settings.p2Status=200;await h.retry();
 assert.equal(h.restoredRoutes,1);assert.equal(h.state.backend.actor.id,A);
 assert.equal(h.calls.filter(c=>c.path.includes('/token?')).length,0);
 assert.equal(h.calls.filter(c=>c.path.endsWith('/auth/v1/user')).length,1);
});

test('restore failure before authenticated user verification cannot claim an authenticated recovery',async t=>{
 const h=fixture(t,{restore:true});h.settings.userStatus=503;await h.controller.init();
 assert.equal(h.memory.size,0);assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/load-retry/);
 assert.equal(h.calls.filter(c=>c.path.includes('/rest/')).length,0);
});

test('password-login503 itself stays a login error, with no retained-session claim or data retry',async t=>{
 const h=fixture(t);h.settings.authStatus=503;await h.login();
 assert.equal(h.memory.size,0);assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/load-retry/);
 assert.equal(h.calls.filter(c=>c.path.includes('/rest/')).length,0);
});

test('full reload recovery preserves a selected historical date, route and period without showing stale data',async t=>{
 const h=fixture(t);h.settings.p2Status=200;await h.login();
 h.state.route='planning';h.state.period='week';h.state.horseFilter='assigned';h.state.selectedDay=PAST;
 h.state.tasks=[{id:'old-private-task',title:'Must be purged'}];h.settings.p2Status=504;
 await h.controller.reload();assert.equal(h.state.backend,undefined);assert.deepEqual(h.state.tasks,[]);
 assert.doesNotMatch(h.screen(),/Must be purged/);
 h.settings.p2Status=200;await h.retry();
 assert.equal(h.state.route,'planning');assert.equal(h.state.period,'week');assert.equal(h.state.horseFilter,'assigned');
 assert.equal(h.state.selectedDay,PAST);assert.equal(h.state.today,DAY);assert.deepEqual(h.state.tasks,[]);
});

test('transient core read failure after successful Auth uses the same complete-read recovery',async t=>{
 const h=fixture(t);h.settings.coreStatus=504;h.settings.p2Status=200;await h.login();
 assert.match(h.screen(),/load-retry/);assert.equal(h.state.backend,undefined);
 h.settings.coreStatus=200;await h.retry();assert.equal(h.state.backend.actor.id,A);assert.equal(h.screen(),null);
});

for(const status of [401,403])test('P2 '+status+' is a hard access failure, never a temporary-load retry',async t=>{
 const h=fixture(t);h.settings.p2Status=status;await h.login();
 assert.equal(h.state.backend,undefined);assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/load-retry/);
 const count=h.calls.length;await h.retry();assert.equal(h.calls.length,count);
});

for(const [label,preferences]of [['wrong actor',{profile_id:B,functions:['rider'],row_version:1}],['malformed choices',{profile_id:A,functions:['superadmin'],row_version:1}]])test(label+' never falls back to default preferences or recovery',async t=>{
 const h=fixture(t);h.settings.p2Status=200;h.settings.preferences=preferences;await h.login();
 assert.equal(h.state.backend,undefined);assert.equal(h.state.functionProfiles,undefined);
 assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/load-retry/);
});

test('known network error during authenticated read offers manual recovery',async t=>{
 const h=fixture(t);h.settings.network=true;await h.login();assert.match(h.screen(),/load-retry/);
 h.settings.network=false;h.settings.p2Status=200;await h.retry();assert.equal(h.screen(),null);
});

test('actual client read timeout offers retry and a late response cannot publish partial data',async t=>{
 const h=fixture(t,{timeoutMs:30});h.settings.p2Status=200;h.settings.delayP2=true;await h.login();
 await new Promise(r=>setTimeout(r,45));assert.match(h.screen(),/load-retry/);assert.equal(h.state.backend,undefined);
 h.gates[0].resolve();await tick();assert.equal(h.state.backend,undefined);assert.deepEqual(h.routes,[]);
});

test('fresh login action invalidates the old retry descriptor',async t=>{
 const h=fixture(t);await h.login();h.action('login-open');const count=h.calls.length;await h.retry();
 assert.equal(h.calls.length,count);assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/load-retry/);
});

test('recovery message is escaped and the screen contains only retry/logout actions',()=>{
 const html=renderLoadRecovery('<img src=x onerror=alert(1)>');
 assert(!html.includes('<img'));assert.match(html,/&lt;img/);assert.doesNotMatch(html,/<form|<input/);
 assert.match(html,/<p class="form-error" role="alert" style="color:var\(--text\)">&lt;img/);
 assert.deepEqual([...html.matchAll(/data-action="([^"]+)"/g)].map(m=>m[1]),['load-retry','logout']);
});
