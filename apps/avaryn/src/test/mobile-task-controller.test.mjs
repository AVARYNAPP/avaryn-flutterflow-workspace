import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {taskToday,taskFormValues} from '../task-timing.js';
import {INITIAL_STATE} from '../data.js';
import {createContext} from '../components.js';
import {renderPlanning} from '../planning.js';
import {createFeedingEditor} from '../backend-feeding-form.js';
import {createAccountCore} from '../account-core.js';
import {createTeamCore} from '../team-core.js';
import {createHorseResidency} from '../horse-residency.js';
import {createActivityEditor} from '../activity-form.js';
import {createAuthorityTransfer} from '../authority-transfer.js';
import {createHorseProfile} from '../horse-profile.js';


// Execute the exact current controller bindings. HTTP and async perform are covered separately.
const source=fs.readFileSync(new URL('../backend-controller.js',import.meta.url),'utf8');
function part(start,end){assert.equal(source.split(start).length,2);const index=source.indexOf(start),last=source.indexOf(end,index);assert(last>index);return source.slice(index,last);}
const submitSource=part(' function handleSubmit(','\n function reload(');
const factorySource=part(' const feedingEditor=',' function getScreen(');
const factories={createFeedingEditor,createAccountCore,createTeamCore,createHorseResidency,createActivityEditor,createAuthorityTransfer};
function submit(values){const state={today:'2026-09-10',selectedDay:'2026-09-11',backend:{connected:true}};const calls=[];let prevented=false;
 const FormData=class{constructor(form){return Object.entries(form.values);}};
 const make=new Function('getState','connected','perform','client','FormData','taskToday','taskFormValues',...Object.keys(factories),`const unexpected=()=>{throw new Error('Unexpected non-task form effect');};const showModal=unexpected,closeModal=unexpected,formError=unexpected,toast=unexpected;${factorySource}\n${submitSource};return handleSubmit;`);
 const client={saveTask:(value,id)=>calls.push({value,id})};
 const handler=make(()=>state,()=>true,(form,op,message,route)=>{calls.push({form,message,route});op('same-request');},client,FormData,taskToday,taskFormValues,...Object.values(factories));
 const form={id:'backend-task-form',getAttribute(name){return name==='id'?this.id:null;},dataset:{resultDay:'2026-10-12'},values};
 assert.equal(handler(form,{preventDefault(){prevented=true;}}),true);assert.equal(prevented,true);
 return {state,form,calls};
}
test('connected task submit clears obsolete resultDay for general task and preserves fields',()=>{const h=submit({when:'none',date:'2026-10-12',time:'11:30',addTime:'on',horseId:'',title:'Vegen',location:'Vrije plek',note:'Hele instructie',assigneeProfileId:'owner'});assert.equal(h.form.dataset.resultDay,undefined);assert.equal(h.calls[0].route,'tasks');assert.deepEqual(h.calls[1],{id:'same-request',value:{title:'Vegen',location:'Vrije plek',note:'Hele instructie',assigneeProfileId:'owner',date:null,time:null,horseId:null}});});
test('connected tomorrow submit uses server today, then opens returned future day',()=>{const h=submit({when:'tomorrow',date:'2026-10-12',time:'11:30',horseId:''});assert.equal(h.form.dataset.resultDay,'2026-09-11');assert.equal(h.calls[1].value.date,'2026-09-11');assert.equal(h.calls[1].value.time,null);});
test('connected explicit time binding retains optional horse and declared clock',()=>{const h=submit({when:'custom',date:'2026-10-12',time:'15:30',addTime:'on',horseId:'horse'});assert.equal(h.form.dataset.resultDay,'2026-10-12');assert.equal(h.calls[1].value.time,'15:30');assert.equal(h.calls[1].value.horseId,'horse');});
test('actual saveLocal writes only theme/day under actor and stable, never task content',()=>{let state={theme:'dark',selectedDay:'2026-09-11',tasks:[{secret:'private task'}],backend:{connected:true,actor:{id:'actor-a'},organizationId:'stable-a'}};const memory=new Map();const code=part(' const scopeKey=',' function clearCore(');const save=new Function('getState','connected','localStorage',`${code};return saveLocal;`)(()=>state,()=>state.backend?.connected===true,{setItem:(k,v)=>memory.set(k,v)});save();assert.deepEqual(JSON.parse(memory.get('avaryn-v8-connected-preferences:actor-a:stable-a')),{theme:'dark',taskDay:'2026-09-11'});state={...state,selectedDay:'2026-09-12',backend:{connected:true,actor:{id:'actor-b'},organizationId:null}};save();assert.equal(memory.size,4);assert.deepEqual(JSON.parse(memory.get('avaryn-v8-connected-active-context:actor-a')),{organizationId:'stable-a'});assert.deepEqual(JSON.parse(memory.get('avaryn-v8-connected-active-context:actor-b')),{organizationId:null});assert.equal(JSON.parse(memory.get('avaryn-v8-connected-preferences:actor-b:personal')).taskDay,'2026-09-12');state.backend.connected=false;save();assert.equal(memory.size,4);assert([...memory.values()].every(v=>!v.includes('private task')));});

test('actual Tasks-to-Planning navigation preserves tomorrow and activates Week, while today/month stay unchanged',()=>{
 const app=fs.readFileSync(new URL('../app.js',import.meta.url),'utf8');
 const routes=app.slice(app.indexOf('const routeNames='),app.indexOf('const dateText='));
 const navigation=app.slice(app.indexOf('function navigate('),app.indexOf('function toast('));
 assert(routes.startsWith('const routeNames='));assert(navigation.startsWith('function navigate('));
 for(const [day,period,expected] of [['2026-09-11','today','week'],['2026-09-10','today','today'],['2026-09-11','month','month']]){
  const state={...structuredClone(INITIAL_STATE),today:'2026-09-10',route:'tasks',selectedDay:day,period};
  const calls=[];let html='';
  const horseProfile=createHorseProfile({getState:()=>state,getBackend:()=>({}),showModal:()=>assert.fail('Navigation must not open a photo form'),perform:()=>assert.fail('Navigation must not mutate a horse'),esc:createContext(state).esc});
  const navigate=new Function('state','visibleHorseIds','unavailable','modal','history','backendController','render','window','save','taskToday','horseProfile',`${routes}\n${navigation}\nreturn navigate;`)(state,()=>['orion','nova'],()=>assert.fail('Unexpected access refusal'),{open:false},{state:null,pushState:(_,__,path)=>calls.push(path)}, {reload:()=>assert.fail('Navigation must not reload the selected day')},()=>{html=renderPlanning(state,createContext(state));},{scrollTo:()=>{}},()=>calls.push('saved'),taskToday,horseProfile);
  navigate('planning');
  assert.equal(state.selectedDay,day);assert.equal(state.period,expected);assert.equal(state.route,'planning');assert.deepEqual(calls,['#/planning','saved']);
  assert.match(html,new RegExp(`data-period="${expected}" aria-pressed="true"`));
 }
});
