import test from 'node:test';
import assert from 'node:assert/strict';
import {createContext} from '../../../apps/avaryn/src/components.js';
import {renderTasks} from '../../../apps/avaryn/src/tasks.js';
import {INITIAL_STATE} from '../../../apps/avaryn/src/data.js';
import {harness,raw,uid,org,DAY} from '../../../apps/avaryn/src/test/feeding-fixture.mjs';
const row=(n,name,extra={})=>({source_type:'stable_task',source_id:uid(n),task_id:uid(n),title:'Taak '+n,organization_id:uid(n+100),organization_name:name,due_date:DAY,status:'open',row_version:1,can_complete:true,...extra});
const render=s=>renderTasks(s,createContext(s));

test('canonical tasks from multiple stables keep their own organization in card metadata and accessible label',async()=>{
 const data=raw();data.day.items=[row(501,'Lindehof'),row(502,'Eigen andere stal')];data.round1.activities=[{activity_kind:'stable_task',activity_id:uid(503),title:'Huidige staltaak',due_date:DAY,status:'open',row_version:1}];
 const h=harness({data}),s=await h.ready();s.today=DAY;s.route='tasks';s.stableName='Verouderde cachenaam';
 const html=render(s);assert.match(html,/plus het werk dat je mag zien bij Teststal\./);assert.doesNotMatch(html,/Verouderde cachenaam/);
 for(const [id,name] of [[uid(501),'Lindehof'],[uid(502),'Eigen andere stal'],[uid(503),'Teststal']]){
  const task=s.tasks.find(t=>t.id===id),card=createContext(s).taskCard(task,{showInstruction:true});assert.equal(task.organizationName,name);assert.match(card,new RegExp('class="task-meta"[^]*?'+name));assert.match(card,new RegExp('aria-label="[^\"]*'+name));assert(html.includes(`data-id="${id}"`));
 }
});
test('missing canonical organization name never borrows a current, cached or horse stable name',async()=>{
 const data=raw();data.day.items=[row(504,'')];data.round1.activities=[];const h=harness({data}),s=await h.ready();s.today=DAY;s.route='tasks';s.stableName='Private cached stable';s.horses[0].stable='Private horse stable';s.tasks[0].horseId=s.horses[0].id;
 const card=createContext(s).taskCard(s.tasks[0]);assert.equal(s.tasks[0].organizationName,'');assert.doesNotMatch(card,/Private cached stable|Private horse stable|Teststal/);
});
test('personal task view keeps authorized multi-stable rows without an active-stable claim',async()=>{
 const data=raw();data.day.items=[row(505,'Lindehof'),row(506,'Stal A')];const h=harness({data});await h.ready();const s=await h.client.load({organizationId:null});s.today=DAY;s.route='tasks';s.stableName='Old selected stable';
 const html=render(s);assert.match(html,/<p>Je eigen taken uit alle stallen\.<\/p>/);assert.doesNotMatch(html,/plus het werk|Old selected stable/);assert(html.includes(`data-id="${uid(505)}"`));assert(html.includes(`data-id="${uid(506)}"`));
});
test('organization names are escaped in intro, card text and accessible label',async()=>{
 const data=raw(),name='<img src=x onerror="private()">';data.day.items=[row(507,name)];data.stables[0].name=name;data.workspace.organization.name=name;data.round1.activities=[];const s=await harness({data}).ready();s.today=DAY;s.route='tasks';const html=render(s);
 assert.doesNotMatch(html,/<img src=x|onerror="private/);assert.match(html,/&lt;img src=x onerror=&quot;private\(\)&quot;&gt;/);
});
test('demo and horse-specific task intro retain existing scope and copy',()=>{
 const s={...structuredClone(INITIAL_STATE),today:DAY,selectedDay:DAY,route:'tasks'};assert.match(render(s),/Gepland voor een dag of klaar om op te pakken/);
 s.backend={connected:true,organizationId:org,organizations:[{id:org,name:'Current stable'}],actor:{id:uid(1)},capabilities:{}};s.route='horse-tasks';assert.match(render(s),/Gepland voor een dag of klaar om op te pakken/);assert.doesNotMatch(render(s),/plus het werk/);
});
