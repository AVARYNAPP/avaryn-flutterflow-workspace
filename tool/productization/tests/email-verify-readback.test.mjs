import test from 'node:test';
import assert from 'node:assert/strict';
import {createBackendController} from '../../../apps/avaryn/src/backend-controller.js';

const ACTOR='10000000-0000-4000-8000-000000000001';
const EMAIL='verified-readback@example.invalid',DAY='2026-09-12';
const ACCESS='eyJhbGciOiJFUzI1NiJ9.eyJzdWIiOiJzeW50aGV0aWMifQ.synthetic-signature';
const tick=()=>new Promise(resolve=>setImmediate(resolve));
const deferred=()=>{let resolve;const promise=new Promise(r=>{resolve=r;});return {promise,resolve};};
const SESSION={access_token:ACCESS,refresh_token:'synthetic-refresh',expires_in:3600,user:{id:ACTOR,email_confirmed_at:'2026-09-12T08:00:00Z'}};
const READS={
 get_current_account_profile:[{profile_id:ACTOR,profile_status:'active',display_name:'Synthetic actor',time_zone:'Europe/Amsterdam',row_version:1,onboarding_completed_at:'2026-09-12T08:00:00Z'}],
 get_c010_personal_day:{on_date:DAY,calendar:{today_date:DAY,time_zone:'Europe/Amsterdam'},items:[]},
 list_c010_horses:[],list_c010_stables:[],
};

function fixture(t,{delayedStorage=false,delayedReads=false,readStatus=200,verifyStatus=200}={}){
 const calls=[],routes=[],memory=new Map(),local=new Map(),storageGate=deferred();
 let currentReadStatus=readStatus;
 const gates=Object.fromEntries(Object.keys(READS).map(name=>[name,deferred()]));
 let state={theme:'light',route:'today',today:DAY,selectedDay:DAY,horses:[],tasks:[],activities:[],feeding:{},team:[]};
 const names=['document','localStorage','location','history','FormData'];
 const prior=Object.fromEntries(names.map(k=>[k,Object.getOwnPropertyDescriptor(globalThis,k)]));
 const NativeFormData=globalThis.FormData;
 const set=(key,value)=>Object.defineProperty(globalThis,key,{configurable:true,writable:true,value});
 set('document',{getElementById:()=>null,querySelector:()=>null});
 set('localStorage',{getItem:k=>local.get(k)??null,setItem:(k,v)=>local.set(k,v)});
 set('location',new URL('https://avaryn.example.invalid/'));set('history',{replaceState(){}});
 set('FormData',class{constructor(form){const data=new NativeFormData();for(const [k,v] of Object.entries(form.values||{}))data.append(k,v);return data;}});
 t.after(()=>{for(const key of names){if(prior[key])Object.defineProperty(globalThis,key,prior[key]);else delete globalThis[key];}});
 const storage={getItem:k=>memory.get(k)??null,removeItem:k=>memory.delete(k),async setItem(k,v){if(delayedStorage)await storageGate.promise;memory.set(k,v);}};
 const fetchImpl=async(path,options)=>{
  const body=options.body?JSON.parse(options.body):null;calls.push({path,body,authorization:options.headers.Authorization});
  if(path.endsWith('/signup'))return Response.json({user:{id:ACTOR}});
  if(path.endsWith('/verify'))return verifyStatus===200?Response.json(SESSION):Response.json({code:'invalid_token'},{status:verifyStatus});
  if(path.endsWith('/logout?scope=local'))return new Response(null,{status:204});
  const name=path.split('/').at(-1);assert(Object.hasOwn(READS,name),'Unexpected request: '+path);
  if(delayedReads)await gates[name].promise;
  return name==='list_c010_horses'&&currentReadStatus!==200?Response.json({code:'synthetic_read_refusal'},{status:currentReadStatus}):Response.json(READS[name]);
 };
 const controller=createBackendController({getState:()=>state,setState:v=>{state=v;},render(){},save(){},navigate:r=>routes.push(r),showModal(){},closeModal(){},toast(){},clientOptions:{storage,fetchImpl,timeoutMs:3000}});
 const submit=(id,values)=>{let prevented=false;assert.equal(controller.handleSubmit({id,values},{preventDefault(){prevented=true;}}),true);assert(prevented);};
 return {controller,calls,routes,memory,storageGate,gates,get state(){return state;},screen:()=>controller.getScreen(),setReadStatus(status){currentReadStatus=status;},async verify(){controller.handleAction('auth-signup');submit('auth-signup-form',{email:EMAIL,password:'Synthetic-password-only'});await tick();assert.match(controller.getScreen(),/auth-verify-form/);submit('auth-verify-form',{email:EMAIL,token:'123456'});await tick();},releaseReads(){for(const gate of Object.values(gates))gate.resolve();}};
}

test('confirmed OTP then one 401 and three late reads shows login, never the consumed OTP',async t=>{
 const h=fixture(t,{delayedStorage:true,delayedReads:true,readStatus:401});await h.verify();
 assert.equal(h.calls.filter(c=>c.path.includes('/rest/')).length,0,'No data request before durable session persistence');
 h.storageGate.resolve();await tick();
 const reads=h.calls.filter(c=>c.path.includes('/rest/'));assert.equal(reads.length,4);assert(reads.every(c=>c.authorization==='Bearer '+ACCESS));
 h.gates.list_c010_horses.resolve();await tick();
 assert.match(h.screen(),/auth-login-form/);assert.match(h.screen(),/Je e-mailadres is bevestigd/);assert.match(h.screen(),/auth-recover/);
 assert.doesNotMatch(h.screen(),/auth-verify-form|name="token"|auth-resend/);assert.match(h.screen(),/verified-readback@example\.invalid/);
 h.releaseReads();await tick();assert.equal(h.state.backend,undefined);assert.deepEqual(h.routes,[]);
 assert.equal(h.calls.filter(c=>c.path.endsWith('/verify')).length,1);assert.equal(h.calls.filter(c=>c.path.includes('/token?')).length,0,'No hidden login or refresh retry');
 assert.equal(h.memory.size,1,'Recovery UI does not mutate the existing session contract');
 assert.match(h.screen(),/auth-login-form/);
});

test('normal confirmed OTP loads its personal workspace once and opens Today',async t=>{
 const h=fixture(t);await h.verify();await tick();
 assert.equal(h.screen(),null);assert.equal(h.state.backend.actor.id,ACTOR);assert.deepEqual(h.routes,['today']);
 assert.equal(h.calls.filter(c=>c.path.includes('/rest/')).length,4);
 assert.deepEqual(h.calls.find(c=>c.path.endsWith('/verify')).body,{email:EMAIL,token:'123456',type:'signup'});
 assert(h.calls.filter(c=>c.path.includes('/rest/')).every(c=>c.authorization==='Bearer '+ACCESS));
});

test('completed verification then confirmed deletion clears the session and returns the login form',async t=>{
 const h=fixture(t);await h.verify();await tick();assert.equal(h.state.backend.actor.id,ACTOR);
 h.controller.suspendAccount();
 await h.controller.clearDeletedSession({isCurrent:()=>true,message:'Je account is verwijderd.'});
 assert.equal(h.state.backend,undefined);assert.equal(h.memory.size,0);
 assert.match(h.screen(),/Je account is verwijderd/);assert.match(h.screen(),/auth-login-form/);
 assert.doesNotMatch(h.screen(),/auth-verify-form|name="token"|auth-resend/);
 assert.equal(h.calls.filter(c=>c.path.endsWith('/verify')).length,1);assert.deepEqual(h.routes,['today']);
});

test('completed verification then lost session on reload returns login without offering the consumed OTP',async t=>{
 const h=fixture(t);await h.verify();await tick();assert.equal(h.state.backend.actor.id,ACTOR);
 h.setReadStatus(401);await h.controller.reload();
 assert.equal(h.state.backend,undefined);assert.match(h.screen(),/auth-login-form/);
 assert.match(h.screen(),/Meld je opnieuw aan/);assert.doesNotMatch(h.screen(),/auth-verify-form|name="token"|auth-resend/);
 assert.equal(h.calls.filter(c=>c.path.endsWith('/verify')).length,1);
 assert.equal(h.calls.filter(c=>c.path.includes('/token?')).length,0);assert.deepEqual(h.routes,['today']);
});

test('401 from verification itself stays a verification error and never claims email confirmation',async t=>{
 const h=fixture(t,{verifyStatus:401});await h.verify();
 assert.match(h.screen(),/auth-verify-form/);assert.doesNotMatch(h.screen(),/Je e-mailadres is bevestigd/);
 assert.equal(h.calls.filter(c=>c.path.includes('/rest/')).length,0);assert.equal(h.memory.size,0);
});

for(const status of [403,503])test('post-verification '+status+' discards the consumed OTP and preserves the correct access boundary',async t=>{
 const h=fixture(t,{readStatus:status});await h.verify();await tick();
 assert.match(h.screen(),status===503?/data-action="load-retry"/:/auth-login-form/);
 assert.doesNotMatch(h.screen(),/auth-verify-form|name="token"|Je e-mailadres is bevestigd/);
 assert.equal(h.state.backend,undefined);assert.deepEqual(h.routes,[]);
 assert.equal(h.memory.size,1);assert.equal(h.calls.filter(c=>c.path.endsWith('/verify')).length,1);
});

test('logout during post-verification reads cannot regain the old recovery message or workspace',async t=>{
 const h=fixture(t,{delayedReads:true,readStatus:401});await h.verify();
 assert.equal(h.calls.filter(c=>c.path.includes('/rest/')).length,4);
 h.controller.handleAction('logout');h.releaseReads();await tick();await tick();
 assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/Je e-mailadres is bevestigd|auth-verify-form/);
 assert.equal(h.state.backend,undefined);assert.equal(h.memory.size,0);assert.deepEqual(h.routes,[]);
});
