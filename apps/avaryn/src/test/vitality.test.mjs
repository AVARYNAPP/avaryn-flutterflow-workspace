import test,{before,after} from 'node:test';
import assert from 'node:assert/strict';
import {createVitalityController,canUseVitality,readVitality,vitalityTraining,renderVitalityCard,WARMUP_STEPS,VITALITY_FEELINGS} from '../vitality.js';
import {INITIAL_STATE} from '../data.js';
import {createContext} from '../components.js';
import {EXERCISES,ROUTINES,EXERCISE_SAFETY} from '../exercise-data.js';

const copy=x=>structuredClone(x);
const demo=(persona='owner')=>({...copy(INITIAL_STATE),persona,today:'2026-09-10'});
const live=(id='actor-a')=>({...demo(),backend:{connected:true,actor:{id,name:id,roleKind:'rider',accessibleHorseIds:['orion','nova'],personalHorseIds:[],assignedHorseIds:[]},calendar:{today_date:'2026-09-10'},capabilities:{}},functionProfiles:{[id]:['rider']}});
const memory=()=>({rows:new Map(),writes:0,getItem(k){return this.rows.get(k)??null;},setItem(k,v){this.rows.set(k,v);this.writes++;}});
const initialStorage=Object.getOwnPropertyDescriptor(globalThis,'localStorage');
before(()=>Object.defineProperty(globalThis,'localStorage',{configurable:true,value:memory()}));
after(()=>{if(initialStorage)Object.defineProperty(globalThis,'localStorage',initialStorage);else delete globalThis.localStorage;});
function harness(t,state=demo(),storage=memory()){
 let current=state,seq=0,form=null,html='',kicker='',viewButtons=[],titles=[],messages=[],closed=0,rendered=0,navigation=[],fetches=0;
 const originals={document:globalThis.document,FormData:globalThis.FormData,fetch:globalThis.fetch,storage:Object.getOwnPropertyDescriptor(globalThis,'localStorage')};
 const modal={open:false,scrollTop:0,dataset:{viewId:''},querySelector:selector=>selector==='[data-vitality-form]'?form:null,querySelectorAll:()=>viewButtons};
 globalThis.document={getElementById:id=>id==='modal'?modal:form?.id===id?form:null};
 globalThis.FormData=class{constructor(f){this.values=f.values}get(k){const v=this.values[k];return Array.isArray(v)?v[0]??null:v??null}getAll(k){const v=this.values[k];return Array.isArray(v)?v:v==null?[]:[v]}};
 globalThis.fetch=()=>{fetches++;throw new Error('No network allowed');};
 Object.defineProperty(globalThis,'localStorage',{configurable:true,value:storage});
 t.after(()=>{globalThis.document=originals.document;globalThis.FormData=originals.FormData;globalThis.fetch=originals.fetch;if(originals.storage)Object.defineProperty(globalThis,'localStorage',originals.storage);else delete globalThis.localStorage;});
 const controller=createVitalityController({getState:()=>current,storage,showModal(title,body,footer,caption){
  titles.push(title);html=body+footer;kicker=caption;modal.open=true;modal.scrollTop=0;modal.dataset.viewId=String(++seq);if(form)form.isConnected=false;for(const b of viewButtons)b.isConnected=false;
  viewButtons=[...html.matchAll(/<button\b([^>]*)>/g)].map(m=>({isConnected:true,dataset:Object.fromEntries([...m[1].matchAll(/data-([a-z-]+)="([^"]*)"/g)].map(a=>[a[1].replace(/-([a-z])/g,(_,c)=>c.toUpperCase()),a[2]]))}));
  const id=body.match(/<form id="([^"]+)"/);form=id?{id:id[1],isConnected:true,values:{},error:{textContent:'',hidden:true},getAttribute(k){return this[k]},querySelector(){return this.error}}:null;
  if(form?.id==='vitality-warmup-form')form.values={minutes:body.match(/value="(5|10)" checked/)?.[1]||'5',step:[...body.matchAll(/name="step" value="(\d)" checked/g)].map(x=>x[1])};
 },closeModal(){closed++;modal.open=false;if(form)form.isConnected=false;for(const b of viewButtons)b.isConnected=false;},toast:m=>messages.push(m),navigate:r=>navigation.push(r),render:()=>rendered++});
 const open=(action,dataset={})=>controller.handleAction(action,{dataset});
 const button=(action,attrs={})=>viewButtons.find(b=>b.dataset.action===action&&Object.entries(attrs).every(([k,v])=>b.dataset[k]===v));
 const click=(action,attrs={})=>{const b=button(action,attrs);assert.ok(b,`Missing ${action}`);return controller.handleAction(action,b);};
 const submit=values=>{Object.assign(form.values,values);let prevented=false;const before=form;assert.equal(controller.handleSubmit(form,{preventDefault(){prevented=true}}),true);assert.equal(prevented,true);return before;};
 return {controller,storage,open,submit,click,button,dismiss(){modal.open=false;if(form)form.isConnected=false;for(const b of viewButtons)b.isConnected=false;},get kicker(){return kicker},set:s=>{current=s},get state(){return current},get form(){return form},get html(){return html},get title(){return titles.at(-1)},get messages(){return messages},get closed(){return closed},get rendered(){return rendered},get navigation(){return navigation},get fetches(){return fetches},modal};
}

test('function preferences gate personal prototype without changing horse permissions',()=>{
 const s=demo('groom'),before=JSON.stringify(s);assert.equal(canUseVitality(s),false);assert.equal(JSON.stringify(s),before);
 s.functionProfiles={groom:['groom','rider']};assert.equal(canUseVitality(s),true);
 const manager=demo('manager');manager.functionProfiles={manager:['manager']};assert.equal(canUseVitality(manager),false);
});
test('missing connected actor and missing demo persona fail closed',()=>{
 for(const s of [{}, {...demo(),backend:{connected:false}}, {...live(),backend:{connected:true,actor:null}}, {...live(),backend:{connected:true,actor:{id:''}}}]){assert.equal(canUseVitality(s),false);assert.equal(readVitality(s).available,false);assert.equal(renderVitalityCard(s),'');}
});
test('ineligible direct action neither reads storage nor opens sheet',t=>{
 let reads=0;const h=harness(t,demo('groom'),{getItem(){reads++;throw Error('no')},setItem(){throw Error('no')}});assert.equal(h.open('vitality-reflection'),true);assert.equal(reads,0);assert.equal(h.modal.open,false);assert.equal(h.messages.length,1);
});
test('connected records never import the previous local prototype namespace',t=>{
 const h=harness(t,live('actor-a'));h.open('vitality-focus');h.submit({focus:'Not locally stored'});
 assert.equal(h.storage.writes,0);assert.equal(readVitality(live('actor-a'),{storage:h.storage}).available,false);
 h.set(demo('owner'));h.open('vitality-focus');h.submit({focus:'Demo eigenaar'});
 assert.equal(readVitality(demo('owner'),{storage:h.storage}).focus,'Demo eigenaar');
 assert.equal(readVitality(live('actor-a'),{storage:h.storage}).focus,'');assert.equal(h.storage.rows.size,1);
});
test('demo local readback survives a new controller and preserves reflection words',t=>{
 const h=harness(t,demo());h.open('vitality-reflection');h.submit({person:'Rustig',horse:'Energiek',focus:'Rustig beginnen'});
 assert.deepEqual(readVitality(demo(),{storage:h.storage}).reflection,{person:'Rustig',horse:'Energiek',focus:'Rustig beginnen',sharingIntent:'private'});h.open('vitality-reflection');assert.match(h.html,/Rustig beginnen/);assert.match(h.html,/<option selected>Rustig/);
});
test('stale reflection after actor A to B to A cannot save',t=>{
 const h=harness(t,live('a'));h.open('vitality-reflection');const old=h.form;h.set(live('b'));h.controller.syncContext();h.set(live('a'));h.controller.syncContext();old.values={focus:'Old A'};
 h.controller.handleSubmit(old,{preventDefault(){}});assert.equal(h.storage.writes,0);assert.equal(h.closed,1);
});
test('day change invalidates open form and never saves under new day',t=>{
 const h=harness(t,live());h.open('vitality-focus');const old=h.form;h.state.backend.calendar.today_date='2026-09-11';h.controller.syncContext();old.values={focus:'Yesterday'};h.controller.handleSubmit(old,{preventDefault(){}});assert.equal(h.storage.writes,0);assert.equal(h.closed,1);
});
test('same actor becoming groom-only clears open private presentation',t=>{
 const h=harness(t,live());h.open('vitality-reflection');h.state.functionProfiles['actor-a']=['groom'];h.controller.syncContext();assert.equal(h.closed,1);assert.equal(readVitality(h.state,{storage:h.storage}).available,false);
});
test('context changes never close a newer unrelated modal',t=>{
 const h=harness(t,live());h.open('vitality-focus');h.modal.dataset.viewId='unrelated';h.set(live('b'));h.controller.syncContext();assert.equal(h.closed,0);assert.equal(h.modal.open,true);
});
test('storage quota failure keeps exact form draft open without success',t=>{
 const h=harness(t);h.open('vitality-reflection');h.storage.setItem=()=>{throw new Error('quota');};const form=h.submit({person:'Moe',horse:'Rustig',focus:'Keep draft'});assert.equal(form.values.focus,'Keep draft');assert.equal(form.isConnected,true);assert.equal(h.modal.open,true);assert.equal(form.error.hidden,false);assert.match(form.error.textContent,/invoer blijft staan/);assert.equal(h.messages.length,0);
});
test('unavailable or malformed local storage does not overwrite existing content',t=>{
 const h=harness(t);h.storage.getItem=()=>'{bad json';h.open('vitality-focus');const f=h.submit({focus:'Still here'});assert.equal(h.storage.writes,0);assert.equal(f.values.focus,'Still here');assert.match(f.error.textContent,/niets opgeslagen/);
});
test('user reflection and horse labels are escaped in production HTML',t=>{
 const h=harness(t);h.open('vitality-focus');h.submit({focus:'<img src=x onerror=alert(1)>'});h.open('vitality-focus');assert.ok(!h.html.includes('<img src=x'));assert.match(h.html,/&lt;img src=x/);
 h.state.activities=[{id:'x',type:'Training',date:'2026-09-10',horseId:'orion',status:'planned',time:'12:00'}];h.state.horses[0].name='<script>bad</script>';const html=renderVitalityCard(h.state,createContext(h.state));assert.ok(!html.includes('<script>'));assert.match(html,/&lt;script&gt;/);
});
test('card only uses an accessible real training on Today, not selected agenda day',()=>{
 const s=live();s.selectedDay='2026-09-12';s.activities=[{id:'farrier',horseId:'orion',type:'Hoefsmid',date:'2026-09-10',status:'planned',time:'08:00'},{id:'future',horseId:'orion',type:'Training',date:'2026-09-12',status:'planned',time:'09:00'},{id:'training',horseId:'nova',type:'Training',date:'2026-09-10',status:'planned',time:'12:00'}];
 assert.equal(vitalityTraining(s).activity.id,'training');assert.match(renderVitalityCard(s,createContext(s)),/training met Nova/);
});
test('completed cancelled foreign horse and nontraining never become warming-up context',()=>{
 for(const patch of [{status:'completed'},{status:'done'},{status:'cancelled'},{horseId:'other'},{itemKind:'farrier',type:'Training'},{date:'2026-09-09'}]){const s=live();s.activities=[{id:'x',horseId:'orion',type:'Training',date:'2026-09-10',status:'planned',...patch}];assert.equal(vitalityTraining(s),null);assert.match(renderVitalityCard(s,createContext(s)),/Focuspunt toevoegen/);}
});
test('routine selector exposes five choices with accurate 5/10 minute guidance',t=>{
 const h=harness(t);h.open('vitality-warmup');assert.equal((h.html.match(/class="vitality-routine"/g)||[]).length,5);
 for(const routine of ROUTINES)assert.ok(h.button('vitality-start',{routine:routine.id}));
 assert.deepEqual(ROUTINES.filter(r=>r.seconds).map(r=>r.seconds.reduce((a,b)=>a+b,0)),[300,600,300]);assert.equal(EXERCISES.reduce((sum,e)=>sum+e.seconds,0),330);assert.match(h.html,/er loopt geen timer/);assert.equal(h.storage.writes,0);
});
test('Next and Later preserve exact extended routine step without claiming completion',t=>{
 const h=harness(t);h.open('vitality-warmup');h.click('vitality-start',{routine:'extended'});h.submit({});h.submit({});assert.match(h.html,/Stap 3\/5/);h.click('vitality-pause');
 const r=readVitality(h.state,{storage:h.storage}).routines.extended;assert.deepEqual(r,{currentStep:2,completed:[0,1],status:'later'});assert.equal(h.modal.open,false);h.open('vitality-warmup');assert.match(h.html,/Hervatten bij stap 3/);h.click('vitality-start',{routine:'extended'});assert.match(h.html,/Stap 3\/5/);assert.equal(h.title,'10 minuten uitgebreid');
});
test('all five steps are required and completion stays in owned modal',t=>{
 const h=harness(t);h.open('vitality-start',{routine:'basic'});for(let n=1;n<=5;n++){assert.match(h.html,new RegExp(`Stap ${n}/5`));h.submit({});}
 const r=readVitality(h.state,{storage:h.storage});assert.equal(r.routines.basic.status,'done');assert.deepEqual(r.routines.basic.completed,[0,1,2,3,4]);assert.equal(r.warmup.status,'done');assert.equal(h.title,'Even voorbereid');assert.equal(h.closed,0);assert.equal(h.modal.open,true);assert.ok(h.button('vitality-reflection'));assert.ok(h.button('vitality-share'));
});
test('skip and complete are day-scoped and never mutate an activity',t=>{
 const h=harness(t);const before=JSON.stringify(h.state.activities);h.open('vitality-skip');assert.equal(readVitality(h.state,{storage:h.storage}).warmup.status,'skipped');h.state.today='2026-09-11';h.controller.syncContext();assert.equal(readVitality(h.state,{storage:h.storage}).warmup,null);assert.equal(JSON.stringify(h.state.activities),before);
});
test('reflection exposes exactly five words and rejects unrecognized values',t=>{
 const h=harness(t);h.open('vitality-reflection');for(const word of VITALITY_FEELINGS)assert.ok(h.html.includes(word));h.submit({person:'Diagnose',horse:'Rustig'});assert.equal(h.storage.writes,0);assert.match(h.form.error.textContent,/uit de lijst/);
});
test('all eight menu sections reach an honest prototype sheet; goals are forthcoming',t=>{
 const h=harness(t);for(const section of ['warmup','cooldown','mobility','focus','goals','feeling','journal','exercises']){assert.equal(h.controller.handleAction('vitality-open',{dataset:{section}}),true);assert.ok(h.modal.open);assert.match(h.kicker,/Prototype/);if(section==='goals')assert.match(h.html,/Binnenkort/);}
});
test('share proposal copies no private text and uses one existing navigation action',t=>{
 const h=harness(t);h.open('vitality-reflection');h.submit({person:'Moe',focus:'Not for sharing'});h.open('vitality-share');assert.ok(!h.html.includes('Not for sharing'));assert.match(h.html,/niets verstuurd/);assert.match(h.html,/Stalrechten blijven apart/);const closed=h.closed;h.open('vitality-moments');assert.deepEqual(h.navigation,['moments']);assert.equal(h.closed,closed);assert.equal(h.fetches,0);
});
test('unknown actions/forms are left to the existing controller',t=>{
 const h=harness(t);assert.equal(h.open('new-task'),false);assert.equal(h.controller.handleSubmit({id:'task-form'},{}),false);assert.equal(h.storage.writes,0);assert.equal(h.fetches,0);
});

test('library renders five full safe exercise cards with text video followups only',t=>{
 const h=harness(t);h.open('vitality-exercises');assert.equal((h.html.match(/class="vitality-exercise-card"/g)||[]).length,5);
 for(const e of EXERCISES){assert.ok(h.html.includes(e.title));assert.ok(h.html.includes(e.description));assert.ok(h.button('vitality-video',{exercise:e.id}));}
 assert.equal(h.html.split(EXERCISE_SAFETY).length-1,1);assert.ok(!/<video|<iframe|<audio|<img/i.test(h.html));assert.equal(h.fetches,0);assert.equal(h.storage.writes,0);
});
test('step library video library return preserves exact step and routine',t=>{
 const h=harness(t);h.open('vitality-start',{routine:'extended'});h.submit({});h.submit({});const before=JSON.stringify(readVitality(h.state,{storage:h.storage}).routines);
 h.click('vitality-exercises');h.click('vitality-video',{exercise:'breathing'});assert.equal(h.title,'Video volgt later');assert.match(h.html,/Terug naar oefeningen/);h.click('vitality-return');assert.equal(h.title,'Oefeningen');assert.match(h.html,/Terug naar stap 3/);h.click('vitality-return');assert.equal(h.title,'10 minuten uitgebreid');assert.match(h.html,/Stap 3\/5/);assert.equal(JSON.stringify(readVitality(h.state,{storage:h.storage}).routines),before);assert.equal(h.fetches,0);
});
test('step video direct return and Previous keep completed progress',t=>{
 const h=harness(t);h.open('vitality-start',{routine:'basic'});h.submit({});assert.match(h.html,/1 min 30 sec/);assert.match(h.html,/Losse oefening: 2 min/);
 h.click('vitality-video');assert.match(h.html,/Terug naar stap 2/);h.click('vitality-return');assert.match(h.html,/Stap 2\/5/);h.click('vitality-previous');assert.match(h.html,/Stap 1\/5/);assert.deepEqual(readVitality(h.state,{storage:h.storage}).routines.basic.completed,[0]);
});
test('closing routine and opening Today library does not inherit stale return context',t=>{
 const h=harness(t);h.open('vitality-start',{routine:'basic'});h.submit({});h.dismiss();h.open('vitality-exercises');assert.ok(!h.html.includes('Terug naar stap'));h.click('vitality-video',{exercise:'hips'});h.click('vitality-return');assert.ok(!h.html.includes('Terug naar stap'));h.open('vitality-start',{routine:'basic'});assert.match(h.html,/Stap 2\/5/);
});
test('new controller resumes routine from persistent demo day record',t=>{
 const store=memory(),h=harness(t,demo('owner'),store);h.open('vitality-start',{routine:'dressage'});h.submit({});h.dismiss();
 const fresh=harness(t,demo('owner'),store);fresh.open('vitality-warmup');fresh.click('vitality-start',{routine:'dressage'});assert.match(fresh.html,/Stap 2\/5/);assert.match(fresh.html,/algemene basisroutine/);
});
test('dressage progress and completion never create or complete basic routine',t=>{
 const h=harness(t);h.open('vitality-start',{routine:'dressage'});h.submit({});assert.equal(readVitality(h.state,{storage:h.storage}).routines.basic,undefined);
 for(let n=0;n<4;n++)h.submit({});const r=readVitality(h.state,{storage:h.storage});assert.equal(r.routines.dressage.status,'done');assert.equal(r.routines.basic,undefined);h.open('vitality-start',{routine:'basic'});assert.match(h.html,/Stap 1\/5/);
});
test('restart resets only chosen routine and preserves other routine and reflection',t=>{
 const h=harness(t);h.open('vitality-reflection');h.submit({focus:'Mijn focus'});h.open('vitality-start',{routine:'extended'});h.submit({});h.open('vitality-start',{routine:'basic'});for(let n=0;n<5;n++)h.submit({});h.click('vitality-restart');
 const r=readVitality(h.state,{storage:h.storage});assert.deepEqual(r.routines.basic,{currentStep:0,completed:[],status:'in_progress'});assert.equal(r.routines.extended.currentStep,1);assert.equal(r.reflection.focus,'Mijn focus');assert.match(h.html,/Stap 1\/5/);
});
test('legacy reflection focus and reordered warmup import are preserved without read writes',t=>{
 const store=memory(),old={version:1,days:{'2026-09-10':{focus:'Bewaar focus',reflection:{person:'Moe',horse:'Rustig',focus:'Oude terugblik'},warmup:{minutes:5,status:'later',steps:[0,1,3]}}}};store.rows.set('avaryn-v8-rider-vitality-v1:demo:owner',JSON.stringify(old));
 const h=harness(t,demo(),store);h.open('vitality-start',{routine:'basic'});assert.match(h.html,/Stap 3\/5/);assert.equal(store.writes,0);assert.deepEqual(JSON.parse([...store.rows.values()][0]),old);h.submit({});
 const r=readVitality(h.state,{storage:store});assert.equal(r.focus,'Bewaar focus');assert.equal(r.reflection.focus,'Oude terugblik');assert.equal(r.reflection.sharingIntent,'private');assert.deepEqual(r.routines.basic.completed,[0,1,4,2]);
});
test('legacy fully completed routine remains done and is not silently restarted',t=>{
 const store=memory();store.rows.set('avaryn-v8-rider-vitality-v1:demo:owner',JSON.stringify({version:1,days:{'2026-09-10':{warmup:{minutes:10,status:'done',steps:[0,1,2,3,4]}}}}));
 const h=harness(t,demo(),store);h.open('vitality-start',{routine:'extended'});assert.equal(h.title,'Even voorbereid');assert.equal(store.writes,0);
});
test('stale step submit and detached video button after account switch cannot act',t=>{
 const h=harness(t,live('a'));h.open('vitality-start',{routine:'basic'});const old=h.form,button=h.button('vitality-video');h.set(live('b'));h.controller.syncContext();h.open('vitality-focus');
 h.controller.handleSubmit(old,{preventDefault(){}});h.controller.handleAction('vitality-video',button);assert.equal(h.title,'Jouw focuspunt');assert.equal(h.storage.writes,0);assert.equal(h.closed,1);
});
test('same account new day invalidates old routine button without reading another day',t=>{
 const h=harness(t,live());h.open('vitality-warmup');const old=h.button('vitality-start',{routine:'basic'});h.state.backend.calendar.today_date='2026-09-11';h.controller.syncContext();h.open('vitality-reflection');h.controller.handleAction('vitality-start',old);assert.equal(h.title,'Trainingsterugblik');assert.equal(h.storage.writes,0);
});
test('storage failure during step keeps same step and previous progress for exact retry',t=>{
 const h=harness(t);h.open('vitality-start',{routine:'basic'});h.submit({});const originalSet=h.storage.setItem;h.storage.setItem=()=>{throw Error('quota')};const f=h.submit({});assert.equal(h.form,f);assert.equal(f.isConnected,true);assert.match(h.html,/Stap 2\/5/);assert.equal(readVitality(h.state,{storage:h.storage}).routines.basic.currentStep,1);assert.match(f.error.textContent,/invoer blijft staan/);
 h.storage.setItem=originalSet;h.submit({});assert.match(h.html,/Stap 3\/5/);assert.equal(readVitality(h.state,{storage:h.storage}).routines.basic.currentStep,2);
});
test('incomplete corrupt final-step progress cannot claim completion',t=>{
 const store=memory();store.rows.set('avaryn-v8-rider-vitality-v1:demo:owner',JSON.stringify({version:1,days:{'2026-09-10':{routines:{basic:{currentStep:4,completed:[0],status:'in_progress'}}}}}));
 const h=harness(t,demo(),store);h.open('vitality-start',{routine:'basic'});const f=h.submit({});assert.match(f.error.textContent,/eerdere stappen/);assert.equal(store.writes,0);assert.equal(readVitality(h.state,{storage:store}).routines.basic.status,'in_progress');
});
test('reflect privately by default; later sharing remains only local intent after confirmation',t=>{
 const h=harness(t);h.open('vitality-reflection');assert.match(h.html,/value="private" selected/);h.submit({focus:'Mijn privé tekst',sharingIntent:'later'});assert.equal(h.title,'Terugblik bewaard');assert.match(h.html,/niets gedeeld/);assert.equal(readVitality(h.state,{storage:h.storage}).reflection.sharingIntent,'later');h.click('vitality-share');assert.ok(!h.html.includes('Mijn privé tekst'));assert.match(h.html,/geen upload of publicatie/);assert.equal(h.fetches,0);
});
test('Today training starts basic directly and rest day offers focus and exercises only',()=>{
 const s=demo();s.activities=[{id:'t',horseId:'orion',date:s.today,type:'Training',time:'12:00',status:'planned'}];let html=renderVitalityCard(s,createContext(s));assert.match(html,/Warming-up voor je rit/);assert.match(html,/data-action="vitality-start" data-routine="basic"/);assert.match(html,/>Start 5 min/);s.activities=[];html=renderVitalityCard(s,createContext(s));assert.match(html,/Kies een focuspunt voor je volgende rit/);assert.match(html,/Oefeningen bekijken/);assert.ok(!html.includes('vitality-start'));
});
test('jumping and stablework are honest forthcoming views with no progress or media',t=>{
 const h=harness(t);for(const routine of ['jumping','stablework']){h.open('vitality-start',{routine});assert.match(h.html,/Binnenkort/);assert.equal(h.form,null);assert.ok(h.button('vitality-warmup'));}assert.equal(h.storage.writes,0);assert.equal(h.fetches,0);
});

test('video return restores library reading position while preserving exact routine step',t=>{
 const h=harness(t);h.open('vitality-start',{routine:'extended'});h.submit({});h.submit({});h.click('vitality-exercises');h.modal.scrollTop=1460;const writes=h.storage.writes;
 h.click('vitality-video',{exercise:'breathing'});assert.equal(h.modal.scrollTop,0);h.click('vitality-return');assert.equal(h.title,'Oefeningen');assert.equal(h.modal.scrollTop,1460);assert.match(h.html,/Terug naar stap 3/);assert.equal(h.storage.writes,writes);
 h.click('vitality-return');assert.match(h.html,/Stap 3\/5/);assert.equal(h.modal.scrollTop,0);h.dismiss();h.open('vitality-exercises');assert.equal(h.modal.scrollTop,0);
 h.modal.scrollTop=920;h.click('vitality-video',{exercise:'balance'});const stale=h.button('vitality-return');h.set(demo('manager'));h.controller.syncContext();h.open('vitality-exercises');h.controller.handleAction('vitality-return',stale);assert.equal(h.modal.scrollTop,0);assert.equal(h.title,'Oefeningen');assert.equal(h.storage.writes,writes);
});
