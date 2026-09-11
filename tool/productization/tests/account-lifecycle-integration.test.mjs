import test from 'node:test';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';

// Only the I/O client is replaced; load, suspension and clear ordering execute
// from the current production controller and its real imported form modules.
const clientUrl=new URL('../../../apps/avaryn/src/backend-client.js',import.meta.url).href;
const hooks=registerHooks({load(url,context,next){
 if(url===clientUrl)return {format:'module',shortCircuit:true,source:'export const createBackendClient=()=>globalThis.__lifecycleClient;'};
 return next(url,context);
}});
const {createBackendController}=await import('../../../apps/avaryn/src/backend-controller.js');
hooks.deregister();
const A='10000000-0000-4000-8000-000000000001',B='10000000-0000-4000-8000-000000000002',DAY='2026-09-11';
const defer=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
const live=(id=A)=>({theme:'dark',today:DAY,selectedDay:DAY,route:'horses',horses:[{id:'own-horse',name:'Private horse'}],tasks:[{id:'own-task'}],activities:[{id:'own-activity'}],feeding:{private:'instruction'},team:[{id:'member'}],facilities:{private:'place'},backend:{connected:true,actor:{id,name:'Synthetic actor'},userId:id,organizationId:'own-stable',todayDate:DAY,todayItems:[],profile:{private:'profile'}}});
function fixture(t,overrides={}){
 let state=live(),renders=0,closed=0,purged=0,callbacks=0,invalidations=0,removals=0;
 const prior={client:globalThis.__lifecycleClient,document:globalThis.document,localStorage:Object.getOwnPropertyDescriptor(globalThis,'localStorage')};
 globalThis.document={getElementById:()=>null};
 Object.defineProperty(globalThis,'localStorage',{configurable:true,writable:true,value:{getItem:()=>null,setItem:()=>{}}});
 globalThis.__lifecycleClient={invalidateData(){invalidations++;},clearLocalSession:async()=>{removals++;if(overrides.clear)return overrides.clear();},load:overrides.load||(async()=>live()),logout:async()=>{},...overrides.client};
 t.after(()=>{globalThis.__lifecycleClient=prior.client;globalThis.document=prior.document;if(prior.localStorage)Object.defineProperty(globalThis,'localStorage',prior.localStorage);else delete globalThis.localStorage;});
 const controller=createBackendController({getState:()=>state,setState:value=>{state=value;},render:()=>{renders++;},save(){},navigate(){},showModal(){},closeModal:()=>{closed++;},toast(){},purgeMedia:()=>{purged++;},clearAuthCallback:()=>{callbacks++;}});
 return {controller,get state(){return state;},setState:value=>{state=value;},counts:()=>({renders,closed,purged,callbacks,invalidations,removals})};
}
test('pending suspension removes all operational/private presentation, keeps only same actor for deletion retry',t=>{
 const h=fixture(t);h.controller.suspendAccount();
 assert.deepEqual(h.state.backend,{connected:true,actor:{id:A,name:'Synthetic actor'},userId:A});
 for(const field of ['horses','tasks','activities','team'])assert.deepEqual(h.state[field],[]);
 assert.deepEqual(h.state.feeding,{});assert.equal(h.state.facilities,undefined);
 assert.deepEqual(h.counts(),{renders:1,closed:0,purged:1,callbacks:1,invalidations:1,removals:0});
});
for(const fail of [false,true])test(`late background ${fail?'failure':'success'} cannot resurrect or sign out a suspended actor`,async t=>{
 const gate=defer(),h=fixture(t,{load:()=>gate.promise});const old=h.controller.reload();h.controller.suspendAccount();const suspended=structuredClone(h.state),counts=h.counts();
 if(fail)gate.reject(Error('Synthetic unavailable'));else gate.resolve(live());await old;
 assert.deepEqual(h.state,suspended);assert.deepEqual(h.counts(),counts);
});
test('deleted-session success and login UI wait until durable removal resolves',async t=>{
 const gate=defer(),h=fixture(t,{clear:()=>gate.promise});h.controller.suspendAccount();
 const clearing=h.controller.clearDeletedSession({isCurrent:()=>true,message:'Account verwijderd.'});
 assert.equal(h.state.backend.actor.id,A);assert.equal(h.counts().closed,0);assert.equal(h.controller.getScreen(),null);
 gate.resolve();await clearing;assert.equal(h.state.backend,undefined);assert.equal(h.counts().closed,1);assert.match(h.controller.getScreen(),/Account verwijderd/);
});
test('durable removal failure leaves the same suspended actor and permits only a later local clear retry',async t=>{
 let calls=0;const h=fixture(t,{clear:async()=>{if(calls++===0)throw Error('Synthetic storage unavailable');}});h.controller.suspendAccount();
 await assert.rejects(h.controller.clearDeletedSession({isCurrent:()=>true,message:'Account verwijderd.'}));
 assert.equal(h.state.backend.actor.id,A);assert.equal(h.counts().closed,0);assert.equal(h.controller.getScreen(),null);
 await h.controller.clearDeletedSession({isCurrent:()=>true,message:'Account verwijderd.'});assert.equal(h.state.backend,undefined);assert.equal(h.counts().removals,2);
});
test('late durable removal completion cannot purge the next actor presentation',async t=>{
 const gate=defer(),h=fixture(t,{clear:()=>gate.promise});let current=true;
 const clearing=h.controller.clearDeletedSession({isCurrent:()=>current,message:'Account verwijderd.'});
 current=false;h.setState(live(B));const before=structuredClone(h.state);gate.resolve();await clearing;
 assert.deepEqual(h.state,before);assert.equal(h.counts().closed,0);assert.equal(h.counts().purged,0);
});
