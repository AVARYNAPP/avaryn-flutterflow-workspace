import test from 'node:test';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
const target=new URL('../../../apps/avaryn/src/backend-client.js',import.meta.url).href;
const hooks=registerHooks({load(url,context,next){if(url===target)return {format:'module',shortCircuit:true,source:'export const createBackendClient=()=>globalThis.__stableContextClient;'};return next(url,context);}});
const {createBackendController}=await import('../../../apps/avaryn/src/backend-controller.js');hooks.deregister();
const A='10000000-0000-4000-8000-000000000001',B='10000000-0000-4000-8000-000000000002';
const ONE='20000000-0000-4000-8000-000000000001',TWO='20000000-0000-4000-8000-000000000002',OTHER='20000000-0000-4000-8000-000000000003',DAY='2026-09-11';
const contextKey=id=>`avaryn-v8-connected-active-context:${id}`;
const scopeKey=(id,org)=>`avaryn-v8-connected-preferences:${id}:${org||'personal'}`;
const deferred=()=>{let resolve,reject;const promise=new Promise((r,j)=>{resolve=r;reject=j;});return {promise,resolve,reject};};
const tick=()=>new Promise(r=>setImmediate(r));
const empty=()=>({theme:'light',route:'tasks',selectedDay:DAY,today:DAY,horses:[],tasks:[],activities:[],feeding:{},team:[]});
function fresh({actor=A,org=ONE,organizations=[ONE,TWO],day=DAY}={}){return {...empty(),stableName:org===ONE?'Stal A':org===TWO?'Lindehof':'Jouw paarden',horses:[{id:'horse-'+actor,name:'Actueel paard'}],tasks:[{id:'task-'+actor,title:'Actuele taak',organizationId:org}],backend:{connected:true,actor:{id:actor,name:'Synthetic'},userId:actor,organizationId:org,organizations:organizations.map(id=>({id,name:id===ONE?'Stal A':'Lindehof'})),todayDate:DAY,todayItems:[],profile:{profile_status:'active',onboarding_completed_at:'2026-09-01'},calendar:{time_zone:'Europe/Amsterdam'}},selectedDay:day};}
function fixture(t,{memory=new Map(),actor=A,organizations=[ONE,TWO],onLoad,onRead,onWrite,augmentLoad}={}){
 let state=empty();const calls=[],commits=[],messages=[],routes=[],writes=[],reads=[];
 const names=['document','localStorage','location','history','__stableContextClient'];
 const prior=Object.fromEntries(names.map(k=>[k,Object.getOwnPropertyDescriptor(globalThis,k)]));
 const set=(key,value)=>Object.defineProperty(globalThis,key,{configurable:true,writable:true,value});
 const client={restore:async()=>true,logout:async()=>{},invalidateData(){},load:async args=>{calls.push({...args});return onLoad?onLoad(args):fresh({actor,organizations,org:args.organizationId===undefined?organizations[0]||null:args.organizationId,day:args.day||DAY});}};
 set('document',{getElementById:()=>null});set('location',new URL('https://alpha.avaryn.eu/'));set('history',{replaceState(){}});
 set('localStorage',{getItem(key){reads.push(key);onRead?.(key);return memory.get(key)??null;},setItem(key,value){onWrite?.(key,value);memory.set(key,value);writes.push({key,value});}});set('__stableContextClient',client);
 t.after(()=>{for(const key of names){if(prior[key])Object.defineProperty(globalThis,key,prior[key]);else delete globalThis[key];}});
 const deps={getState:()=>state,setState:value=>{state=value;commits.push(structuredClone(value));},render(){},save(){},navigate:value=>routes.push(value),showModal(){},closeModal(){},toast:value=>messages.push(value),augmentLoad};
 let controller=createBackendController(deps);
 return {client,memory,calls,commits,messages,routes,writes,reads,get state(){return state;},get controller(){return controller;},cold(){state=empty();controller=createBackendController(deps);},setState(value){state=value;}};
}

test('selected Lindehof survives a cold task route; default stable is never committed first',async t=>{
 const h=fixture(t);await h.controller.init();h.controller.handleAction('select-stable',{dataset:{id:TWO}});await tick();assert.equal(h.state.backend.organizationId,TWO);
 assert.deepEqual(JSON.parse(h.memory.get(contextKey(A))),{organizationId:TWO});h.cold();const before=h.commits.length;await h.controller.init();
 assert.deepEqual(h.calls.slice(-2),[{organizationId:undefined,day:undefined},{organizationId:TWO,day:undefined}]);assert.equal(h.state.backend.organizationId,TWO);
 assert.deepEqual(h.commits.slice(before).map(s=>s.backend?.organizationId),[TWO]);
});
test('an explicit personal selection survives a cold load with accessible stables',async t=>{
 const h=fixture(t);await h.controller.init();h.controller.handleAction('select-stable',{dataset:{id:'personal'}});await tick();h.cold();await h.controller.init();assert.equal(h.state.backend.organizationId,null);assert.deepEqual(JSON.parse(h.memory.get(contextKey(A))),{organizationId:null});
});
test('no saved choice retains the existing first authorized stable default',async t=>{const h=fixture(t);await h.controller.init();assert.equal(h.calls.length,1);assert.equal(h.state.backend.organizationId,ONE);assert.equal(h.messages.length,0);});
test('context preferences never cross accounts and only verified actor determines the key',async t=>{
 const memory=new Map([[contextKey(A),JSON.stringify({organizationId:TWO,privateName:'Never display'})],[contextKey(B),JSON.stringify({organizationId:null})]]),h=fixture(t,{memory,actor:B});
 await h.controller.init();assert.equal(h.state.backend.actor.id,B);assert.equal(h.state.backend.organizationId,null);assert(!h.reads.includes(contextKey(A)));assert(!JSON.stringify(h.state).includes('Never display'));assert.equal(JSON.parse(memory.get(contextKey(A))).organizationId,TWO);
});
for(const stored of [JSON.stringify({organizationId:OTHER}),'{broken',JSON.stringify({unexpected:TWO})])test('unavailable or malformed saved context falls back to personal with notice: '+stored,async t=>{
 const h=fixture(t,{memory:new Map([[contextKey(A),stored]])});await h.controller.init();assert.equal(h.state.backend.organizationId,null);assert(!h.calls.some(c=>c.organizationId===OTHER));assert(h.messages.some(m=>m.includes('persoonlijke paarden')));assert.deepEqual(JSON.parse(h.memory.get(contextKey(A))),{organizationId:null});assert.deepEqual(h.commits.map(s=>s.backend?.organizationId),[null]);
});
test('restored context uses only that account and organization task date preference',async t=>{
 const memory=new Map([[contextKey(A),JSON.stringify({organizationId:TWO})],[scopeKey(A,ONE),JSON.stringify({taskDay:'2026-09-20'})],[scopeKey(A,TWO),JSON.stringify({taskDay:'2026-09-12'})],[scopeKey(B,TWO),JSON.stringify({taskDay:'2026-10-12'})]]),h=fixture(t,{memory});await h.controller.init();
 assert.equal(h.state.selectedDay,'2026-09-12');assert.equal(h.state.today,DAY);assert.deepEqual(h.calls.at(-1),{organizationId:TWO,day:'2026-09-12'});
});
test('loss of selected stable on current reload falls back only on exact organization-unavailable code',async t=>{
 const h=fixture(t);await h.controller.init();h.client.load=async args=>{h.calls.push(args);if(args.organizationId===ONE)throw Object.assign(Error('Unavailable'),{code:'ORGANIZATION_UNAVAILABLE',accessLost:true});return fresh({org:null,organizations:[TWO]});};
 await h.controller.reload();assert.equal(h.state.backend.organizationId,null);assert(h.messages.some(m=>m.includes('persoonlijke paarden')));assert.equal(h.controller.getScreen(),null);
});
test('ordinary ACL failure still purges and never attempts a personal-context bypass',async t=>{
 const h=fixture(t);await h.controller.init();const before=h.calls.length;h.client.load=async args=>{h.calls.push(args);throw Object.assign(Error('Access lost'),{code:'HORSE_ACCESS_DENIED',status:403});};await h.controller.reload();
 assert.equal(h.state.backend,undefined);assert.deepEqual(h.state.tasks,[]);assert.equal(h.calls.length,before+1);assert.match(h.controller.getScreen(),/auth-login-form/);assert.equal(JSON.parse(h.memory.get(contextKey(A))).organizationId,ONE);
});
test('saved choice revoked between fresh list and readback is revalidated as personal',async t=>{
 const memory=new Map([[contextKey(A),JSON.stringify({organizationId:TWO})]]),h=fixture(t,{memory,onLoad:args=>{if(args.organizationId===TWO)throw Object.assign(Error('Unavailable'),{code:'ORGANIZATION_UNAVAILABLE'});return fresh({org:args.organizationId===null?null:ONE});}});
 await h.controller.init();assert.deepEqual(h.calls.map(c=>c.organizationId),[undefined,TWO,null]);assert.equal(h.state.backend.organizationId,null);assert(h.messages.some(m=>m.includes('persoonlijke paarden')));
});
test('logout during restored-context readback discards data and preference writes',async t=>{
 const gate=deferred(),memory=new Map([[contextKey(A),JSON.stringify({organizationId:TWO})]]),h=fixture(t,{memory,onLoad:args=>args.organizationId===TWO?gate.promise:fresh()});
 const loading=h.controller.init();await tick();h.controller.handleAction('logout');gate.resolve(fresh({org:TWO}));await loading;assert.equal(h.state.backend,undefined);assert.equal(h.writes.length,0);assert.deepEqual(h.routes,[]);assert.equal(h.messages.length,0);
});
test('late first actor response cannot read old preference or overwrite a newer login',async t=>{
 const gate=deferred(),memory=new Map([[contextKey(A),JSON.stringify({organizationId:TWO})],[contextKey(B),JSON.stringify({organizationId:null})]]),h=fixture(t,{memory,onLoad:()=>gate.promise});
 const old=h.controller.init();h.controller.handleAction('login-open');h.client.load=async args=>fresh({actor:B,org:args.organizationId===null?null:ONE});await h.controller.init();gate.resolve(fresh());await old;
 assert.equal(h.state.backend.actor.id,B);assert.equal(h.state.backend.organizationId,null);assert(!h.reads.includes(contextKey(A)));assert(!h.writes.some(w=>w.key===contextKey(A)));
});
test('P2 readback must finish before selected context is remembered; stale enrichment cannot save it',async t=>{
 const gate=deferred(),h=fixture(t,{augmentLoad:()=>gate.promise});const loading=h.controller.init();await tick();assert.equal(h.writes.length,0);h.controller.handleAction('logout');gate.resolve(fresh());await loading;assert.equal(h.writes.length,0);assert.equal(h.state.backend,undefined);
});
test('storage write failure keeps authorized state visible and reports missing persistence',async t=>{
 const h=fixture(t,{onWrite:()=>{throw Error('Storage unavailable');}});await h.controller.init();assert.equal(h.state.backend.organizationId,ONE);assert.equal(h.controller.getScreen(),null);assert(h.messages.some(m=>m.includes('niet op dit apparaat')));
});
test('unreadable saved choice uses personal context instead of silently selecting first stable',async t=>{
 const h=fixture(t,{onRead:key=>{if(key===contextKey(A))throw Error('Storage unavailable');}});await h.controller.init();assert.equal(h.state.backend.organizationId,null);assert(h.messages.some(m=>m.includes('persoonlijke paarden')));
});
test('suspended lifecycle state cannot overwrite context or persist cached domain data',async t=>{
 const h=fixture(t);await h.controller.init();const before=h.writes.length;h.controller.suspendAccount();h.controller.saveLocal();assert.equal(h.writes.length,before);assert.equal(JSON.parse(h.memory.get(contextKey(A))).organizationId,ONE);assert([...h.memory.values()].every(v=>!v.includes('Actuele taak')&&!v.includes('Actueel paard')));
});
