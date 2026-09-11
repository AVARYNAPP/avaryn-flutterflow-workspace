import test from 'node:test';
import assert from 'node:assert/strict';
import {registerHooks} from 'node:module';
import {readFileSync} from 'node:fs';
import {normalizeFeeding} from '../backend-client.js?day-refresh-projection';
import {renderHorseFeeding} from '../feeding.js';
import {createContext} from '../components.js';
const target=new URL('../backend-client.js',import.meta.url).href;
const hooks=registerHooks({load(url,context,next){if(url===target)return {format:'module',shortCircuit:true,source:'export const createBackendClient=()=>globalThis.__dayRefreshClient;'};return next(url,context);}});
const {createBackendController}=await import('../backend-controller.js');hooks.deregister();
const DAY='2026-09-11',NEXT='2026-09-12',MIDNIGHT=new Date('2026-09-11T22:01:00Z');
const A='10000000-0000-4000-8000-000000000001',B='10000000-0000-4000-8000-000000000002',HORSE='20000000-0000-4000-8000-000000000001';
const deferred=()=>{let resolve,reject;const promise=new Promise((r,j)=>{resolve=r;reject=j;});return{promise,resolve,reject};};
const tick=()=>new Promise(r=>setImmediate(r));
const plan=(type,from,until,products)=>({feeding_plan_id:type,plan_type:type,status:'active',row_version:1,effective_from:from,effective_until:until,active_version_id:type,versions:[{feeding_plan_version_id:type,items:products.map(product=>({round_code:'morning',local_time:'07:00:00',product_brand:product,planned_quantity:1,unit_code:'kg',instruction:'Volledige instructie behouden.'}))}]});
const feeding={plans:[plan('standard',DAY,null,['Onderhoudsbrok','Hooi']),plan('temporary',NEXT,'2026-09-14',['Hooi tijdelijk'])]};
const empty=()=>({theme:'light',route:'horse-feeding',horseId:HORSE,selectedDay:DAY,today:DAY,horses:[],tasks:[],activities:[],feeding:{},team:[]});
function fresh({actor=A,day=DAY,selectedDay=day,zone='Europe/Amsterdam',org=null}={}){
 return{...empty(),selectedDay,today:day,horseFilter:'personal',period:'today',horses:[{id:HORSE,name:'Linde',stable:'',image:'',personalAccess:true}],feeding:{[HORSE]:normalizeFeeding(feeding,day)},backend:{connected:true,userId:actor,actor:{id:actor,name:'Synthetic owner',initials:'SO',personalHorseIds:[HORSE],accessibleHorseIds:[HORSE],assignedHorseIds:[]},organizationId:org,organizations:[],horseCapabilities:{[HORSE]:{view:true,edit:true,feeding:true}},todayDate:day,todayItems:[],profile:{profile_status:'active',time_zone:zone,onboarding_completed_at:'2026-09-01'},calendar:{time_zone:zone,today_date:day}}};
}
function fixture(t,initial={}){
 let state=empty(),serverDay=DAY,loads=0,renders=0,purges=0;const calls=[],commits=[],memory=new Map(),modal={open:false,dataset:{viewId:'test'},contains:f=>f===modal.form},dom={inline:null};
 const keys=['document','localStorage','location','history','__dayRefreshClient'],old=Object.fromEntries(keys.map(k=>[k,Object.getOwnPropertyDescriptor(globalThis,k)]));
 const set=(k,v)=>Object.defineProperty(globalThis,k,{configurable:true,writable:true,value:v});
 const client={restore:async()=>true,logout:async()=>{},invalidateData(){},load:async args=>{loads++;calls.push(args);return client.read(args);},read:async args=>fresh({...initial,day:serverDay,selectedDay:args.day||serverDay})};
 set('__dayRefreshClient',client);set('document',{getElementById:()=>null,querySelector:s=>s==='#modal'?modal:s==='#app form'?dom.inline:null});set('location',new URL('https://alpha.avaryn.eu/'));set('history',{replaceState(){}});set('localStorage',{getItem:k=>memory.get(k)||null,setItem:(k,v)=>memory.set(k,v)});
 t.after(()=>{for(const k of keys){if(old[k])Object.defineProperty(globalThis,k,old[k]);else delete globalThis[k];}});
 let duringRender=()=>{};
 const controller=createBackendController({getState:()=>state,setState:s=>{state=s;commits.push(s);},render:()=>{renders++;duringRender();},save(){},navigate:r=>{state.route=r;},showModal(){},closeModal(){modal.open=false;},toast(){},purgeMedia:()=>purges++});
 return{controller,client,calls,commits,memory,modal,dom,get state(){return state;},get loads(){return loads;},get renders(){return renders;},get purges(){return purges;},set:s=>state=s,day:d=>serverDay=d,onRender:fn=>duringRender=fn};
}
test('account midnight reload changes active morning feed from basis to the complete temporary replacement',async t=>{
 const h=fixture(t);await h.controller.init();assert.equal(h.state.feeding[HORSE].planType,'standard');h.day(NEXT);const wait=deferred();h.client.read=()=>wait.promise;
 assert.equal(h.controller.refreshToday(MIDNIGHT),true);assert.match(h.controller.getScreen(),/access-loading/);assert.equal(h.state.today,DAY,'No optimistic day stamping');
 wait.resolve(fresh({day:NEXT}));await tick();assert.equal(h.state.today,NEXT);assert.equal(h.state.selectedDay,NEXT);assert.equal(h.state.backend.todayDate,NEXT);assert.equal(h.state.feeding[HORSE].planType,'temporary');assert.deepEqual(h.state.feeding[HORSE].meals[0].items.map(i=>i.product),['Hooi tijdelijk']);
 const html=renderHorseFeeding(h.state,createContext(h.state)),active=html.slice(html.indexOf('feeding-plan-status'),html.indexOf('<section class="section">'));assert.match(active,/Tijdelijk schema actief/);assert.match(active,/Hooi tijdelijk/);assert.match(active,/Volledige instructie behouden/);assert.doesNotMatch(active,/Onderhoudsbrok/);assert.equal(h.loads,2);
});
test('day after inclusive temporary end returns to unchanged basis',async t=>{
 const h=fixture(t);h.day('2026-09-14');await h.controller.init();assert.equal(h.state.feeding[HORSE].planType,'temporary');h.day('2026-09-15');h.controller.refreshToday(new Date('2026-09-14T22:01:00Z'));await tick();assert.equal(h.state.feeding[HORSE].planType,'standard');assert.deepEqual(h.state.feeding[HORSE].meals[0].items.map(i=>i.product),['Onderhoudsbrok','Hooi']);
});
test('same account day stays network-idle across repeated timer, focus and render calls',async t=>{const h=fixture(t);await h.controller.init();for(let i=0;i<5;i++)assert.equal(h.controller.refreshToday(new Date('2026-09-11T21:59:00Z')),false);assert.equal(h.loads,1);});
test('verified Los Angeles day takes precedence over browser Amsterdam midnight',async t=>{const h=fixture(t,{zone:'America/Los_Angeles'});await h.controller.init();assert.equal(h.controller.refreshToday(MIDNIGHT),false);assert.equal(h.loads,1);h.day(NEXT);assert.equal(h.controller.refreshToday(new Date('2026-09-12T07:01:00Z')),true);await tick();assert.equal(h.state.today,NEXT);});
test('chosen historical agenda/task date survives while feeding follows current server day',async t=>{
 const h=fixture(t);await h.controller.init();h.state.route='tasks';h.state.selectedDay='2026-09-08';h.day(NEXT);h.controller.refreshToday(MIDNIGHT);await tick();assert.equal(h.calls.at(-1).day,'2026-09-08');assert.equal(h.state.selectedDay,'2026-09-08');assert.equal(h.state.today,NEXT);assert.equal(h.state.feeding[HORSE].planType,'temporary');
});
test('open modal draft is untouched, then refresh resumes after close',async t=>{
 const h=fixture(t);await h.controller.init();h.modal.open=true;h.modal.form={note:'Exact concept',time:'10:30'};h.day(NEXT);const before=h.state;assert.equal(h.controller.refreshToday(MIDNIGHT),false);assert.equal(h.state,before);assert.deepEqual(h.modal.form,{note:'Exact concept',time:'10:30'});assert.equal(h.loads,1);h.modal.open=false;assert.equal(h.controller.refreshToday(MIDNIGHT),true);await tick();assert.equal(h.state.today,NEXT);
});
test('inline role-profile draft is preserved, but its old DOM cannot block navigation to current feeding',async t=>{
 const h=fixture(t);await h.controller.init();h.state.route='function-profile';const form=h.dom.inline={value:'Unsaved function preference'};h.day(NEXT);assert.equal(h.controller.refreshToday(MIDNIGHT),false);assert.equal(h.dom.inline.value,'Unsaved function preference');assert.equal(h.loads,1);
 // navigate changes state.route before render removes the previous route's form.
 h.state.route='horse-feeding';assert.equal(h.dom.inline,form);assert.equal(h.controller.refreshToday(MIDNIGHT),true);await tick();assert.equal(h.state.today,NEXT);assert.equal(h.state.route,'horse-feeding');assert.equal(h.state.feeding[HORSE].planType,'temporary');assert.equal(h.loads,2);assert.equal(h.dom.inline,form);
});
test('a running write remains authoritative and prevents a competing midnight read',async t=>{
 const h=fixture(t);await h.controller.init();const wait=deferred(),f={id:'core-test',dataset:{},querySelectorAll:()=>[]};h.modal.open=true;h.modal.form=f;const saving=h.controller.perform(f,()=>wait.promise,'Saved');h.modal.open=false;h.day(NEXT);assert.equal(h.controller.refreshToday(MIDNIGHT),false);assert.equal(h.loads,1);wait.resolve();await saving;assert.equal(h.state.today,NEXT);assert.equal(h.loads,2);
});
test('duplicate focus and render during delayed read share one refresh, with no recursive read on commit',async t=>{
 const h=fixture(t);await h.controller.init();const wait=deferred();h.client.read=()=>wait.promise;h.onRender(()=>h.controller.refreshToday(MIDNIGHT));assert.equal(h.controller.refreshToday(MIDNIGHT),true);assert.equal(h.controller.refreshToday(MIDNIGHT),false);assert.equal(h.loads,2);wait.resolve(fresh({day:NEXT}));await tick();assert.equal(h.loads,2);assert.equal(h.controller.refreshToday(MIDNIGHT),false);
});
for(const failure of [false,true])test('late day refresh '+(failure?'failure':'success')+' cannot overwrite new actor',async t=>{
 const h=fixture(t);await h.controller.init();const wait=deferred();h.client.read=()=>wait.promise;h.controller.refreshToday(MIDNIGHT);h.controller.handleAction('login-open');h.client.read=async()=>fresh({actor:B,day:NEXT});await h.controller.init();const before=h.renders;
 failure?wait.reject(Object.assign(Error('Old denied'),{status:403})):wait.resolve(fresh({day:NEXT}));await tick();assert.equal(h.state.backend.actor.id,B);assert.equal(h.renders,before);assert.equal(h.controller.getScreen(),null);
});
test('failed current day read purges previous feeding and exposes failure, never a current-day success',async t=>{
 const h=fixture(t);await h.controller.init();h.client.read=async()=>{throw Error('Nieuwe dag niet geladen');};h.controller.refreshToday(MIDNIGHT);await tick();assert.equal(h.state.backend,undefined);assert.deepEqual(h.state.feeding,{});assert.match(h.controller.getScreen(),/Nieuwe dag niet geladen/);assert.equal(h.controller.refreshToday(MIDNIGHT),false);
});
test('lifecycle suspension and logged-out state cannot refresh operational data',async t=>{const h=fixture(t);assert.equal(h.controller.refreshToday(MIDNIGHT),false);await h.controller.init();h.controller.suspendAccount();assert.equal(h.controller.refreshToday(MIDNIGHT),false);assert.equal(h.loads,1);assert.deepEqual(h.state.feeding,{});});
test('same-account navigation during read retains latest route and selected horse',async t=>{const h=fixture(t);await h.controller.init();const wait=deferred();h.client.read=()=>wait.promise;h.controller.refreshToday(MIDNIGHT);h.state.route='horse-overview';wait.resolve(fresh({day:NEXT}));await tick();assert.equal(h.state.route,'horse-overview');assert.equal(h.state.horseId,HORSE);});
test('app checks current day before feeding render and resumes deferred checks on modal close',()=>{
 const src=readFileSync(new URL('../app.js',import.meta.url),'utf8');const render=src.slice(src.indexOf('function render(){'),src.indexOf('function showModal('));assert(render.indexOf('if(backendController?.refreshToday())return;')<render.indexOf('const view=viewState()'));
 assert.match(src,/modal\.addEventListener\('close',refreshTodayClock\)/);assert.match(src,/state\.selectedDay=state\.today;if\(!backendController\.refreshToday\(\)\)backendController\.reload\(\)/);
});
