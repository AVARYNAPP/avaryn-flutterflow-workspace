import test from 'node:test';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
const target=new URL('../../../apps/avaryn/src/backend-client.js',import.meta.url).href;
const hooks=registerHooks({load(url,context,next){if(url===target)return {format:'module',shortCircuit:true,source:'export const createBackendClient=()=>globalThis.__emailControllerClient;'};return next(url,context);}});
const {createBackendController}=await import('../../../apps/avaryn/src/backend-controller.js');hooks.deregister();
const A='10000000-0000-4000-8000-000000000001',TOKEN='a'.repeat(64),NEXT='b'.repeat(64),DAY='2026-09-11';
const defer=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};};
const tick=()=>new Promise(r=>setImmediate(r));
const active=()=>({theme:'light',route:'today',selectedDay:DAY,today:DAY,horses:[{id:'private-horse'}],tasks:[],activities:[],feeding:{},team:[],backend:{connected:true,actor:{id:A,name:'Synthetic'},userId:A,organizationId:null,todayDate:DAY,todayItems:[],profile:{profile_status:'active',onboarding_completed_at:'2026-09-01'},calendar:{time_zone:'Europe/Amsterdam'}}});
function fixture(t,{clear,verify,location='https://alpha.avaryn.eu/'}={}){
 let state=active(),renders=0;const calls=[],routes=[],historyCalls=[];
 const names=['document','localStorage','location','history','FormData','__emailControllerClient'];
 const prior=Object.fromEntries(names.map(k=>[k,Object.getOwnPropertyDescriptor(globalThis,k)])),NativeFormData=globalThis.FormData;
 const set=(key,value)=>Object.defineProperty(globalThis,key,{configurable:true,writable:true,value});
 set('document',{getElementById:()=>null});set('localStorage',{getItem:()=>null,setItem(){}});set('location',new URL(location));set('history',{replaceState(...args){historyCalls.push(args);}});
 set('FormData',class{constructor(form){const data=new NativeFormData();for(const [k,v] of Object.entries(form.values||{}))data.append(k,v);return data;}});
 set('__emailControllerClient',{clearLocalSession:async()=>{calls.push({kind:'clear'});if(clear)return clear();},verifyEmail:async args=>{calls.push({kind:'verify',type:args.type,originalToken:args.tokenHash===TOKEN,nextToken:args.tokenHash===NEXT});if(verify)return verify(args);},restore:async()=>{calls.push({kind:'restore'});return false;},load:async()=>{calls.push({kind:'load'});return active();},logout:async()=>{calls.push({kind:'logout'});},updatePassword:async()=>{calls.push({kind:'password'});}});
 t.after(()=>{for(const key of names){if(prior[key])Object.defineProperty(globalThis,key,prior[key]);else delete globalThis[key];}});
 const controller=createBackendController({getState:()=>state,setState:v=>{state=v;},render:()=>{renders++;},save(){},navigate:r=>routes.push(r),showModal(){},closeModal(){},toast(){}});
 return {controller,calls,routes,historyCalls,get state(){return state;},get renders(){return renders;},screen:()=>controller.getScreen(),submit(id,values={}){let prevented=false;controller.handleSubmit({id,values},{preventDefault(){prevented=true;}});assert.equal(prevented,true);}};
}
test('invalid native callback is inert: no clear, verification or data load',async t=>{
 const h=fixture(t);await h.controller.handleNativeEmailCallback({type:'email',tokenHash:'short'});await h.controller.handleNativeEmailCallback({type:'oauth',tokenHash:TOKEN});assert.equal(h.calls.length,0);assert.equal(h.state.backend.actor.id,A);
});
test('native email waits for durable old-session clear and never embeds token in verification HTML',async t=>{
 const gate=defer(),h=fixture(t,{clear:()=>gate.promise});const receiving=h.controller.handleNativeEmailCallback({type:'email',tokenHash:TOKEN});
 assert.equal(h.state.backend,undefined);assert.deepEqual(h.calls,[{kind:'clear'}]);assert.doesNotMatch(h.screen(),/auth-verify-form/);
 gate.resolve();await receiving;assert.match(h.screen(),/auth-verify-form/);assert.equal(h.screen().includes(TOKEN),false);assert.equal(h.calls.some(c=>c.kind==='verify'),false);
});
test('durable callback clear failure cannot offer token verification or load old account data',async t=>{
 const h=fixture(t,{clear:()=>{throw Error('Synthetic secure storage unavailable');}});await h.controller.handleNativeEmailCallback({type:'email',tokenHash:TOKEN});assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/auth-verify-form/);assert.equal(h.state.backend,undefined);assert.deepEqual(h.calls,[{kind:'clear'}]);
});
test('older callback clear cannot overwrite newer recovery purpose or token',async t=>{
 const gate=defer();let attempts=0;const h=fixture(t,{clear:()=>attempts++===0?gate.promise:undefined});
 const old=h.controller.handleNativeEmailCallback({type:'email',tokenHash:TOKEN});await h.controller.handleNativeEmailCallback({type:'recovery',tokenHash:NEXT});gate.resolve();await old;
 assert.match(h.screen(),/auth-recovery-form/);h.submit('auth-recovery-form');await tick();assert.deepEqual(h.calls.filter(c=>c.kind==='verify'),[{kind:'verify',type:'recovery',originalToken:false,nextToken:true}]);assert.match(h.screen(),/auth-reset-form/);assert.equal(h.calls.some(c=>c.kind==='load'),false);
});
test('explicit verification awaits server acknowledgement before private readback',async t=>{
 const gate=defer(),h=fixture(t,{verify:()=>gate.promise});await h.controller.handleNativeEmailCallback({type:'email',tokenHash:TOKEN});h.submit('auth-verify-form');await tick();
 assert.equal(h.calls.filter(c=>c.kind==='verify').length,1);assert.equal(h.calls.some(c=>c.kind==='load'),false);assert.equal(h.state.backend,undefined);
 gate.resolve();await tick();assert.equal(h.calls.filter(c=>c.kind==='load').length,1);assert.deepEqual(h.routes,['today']);assert.equal(h.state.backend.actor.id,A);
});
test('invalid or replayed email verification never loads private state or claims confirmed',async t=>{
 const h=fixture(t,{verify:()=>{throw Object.assign(Error('Deze code is niet geldig.'),{status:403});}});await h.controller.handleNativeEmailCallback({type:'email',tokenHash:TOKEN});h.submit('auth-verify-form');await tick();assert.equal(h.state.backend,undefined);assert.equal(h.calls.some(c=>c.kind==='load'),false);assert.equal(h.routes.length,0);assert.match(h.screen(),/Deze code is niet geldig/);assert.equal(h.screen().includes(TOKEN),false);
});
test('logout while verification is pending blocks late private readback and navigation',async t=>{
 const gate=defer(),h=fixture(t,{verify:()=>gate.promise});await h.controller.handleNativeEmailCallback({type:'email',tokenHash:TOKEN});h.submit('auth-verify-form');await tick();h.controller.handleAction('logout');gate.resolve();await tick();assert.equal(h.calls.some(c=>c.kind==='load'),false);assert.equal(h.state.backend,undefined);assert.equal(h.routes.length,0);assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/auth-verify-form/);
});
test('opening a fresh login clears a previously received native callback purpose',async t=>{const h=fixture(t);await h.controller.handleNativeEmailCallback({type:'recovery',tokenHash:TOKEN});h.controller.handleAction('login-open');assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/auth-recovery-form/);assert.equal(h.calls.filter(c=>c.kind==='verify').length,0);});
test('fresh login while native clear is pending is enabled and cannot regain old callback',async t=>{const gate=defer(),h=fixture(t,{clear:()=>gate.promise});const old=h.controller.handleNativeEmailCallback({type:'email',tokenHash:TOKEN});h.controller.handleAction('login-open');assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/type="submit" disabled/);gate.resolve();await old;assert.match(h.screen(),/auth-login-form/);assert.doesNotMatch(h.screen(),/auth-verify-form/);assert.equal(h.calls.some(c=>c.kind==='verify'),false);});
test('browser email callback startup scrubs address and waits for explicit verification',async t=>{
 const h=fixture(t,{location:`https://alpha.avaryn.eu/auth/callback?token_hash=${TOKEN}&type=email`});await h.controller.init();assert.deepEqual(h.historyCalls,[[null,'','/#/vandaag']]);assert.match(h.screen(),/auth-verify-form/);assert.equal(h.screen().includes(TOKEN),false);assert.equal(h.calls.length,0);h.submit('auth-verify-form');await tick();assert.equal(h.calls.filter(c=>c.kind==='verify').length,1);assert.deepEqual(h.routes,['today']);
});
