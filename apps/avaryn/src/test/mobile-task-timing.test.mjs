import test from 'node:test';
import assert from 'node:assert/strict';
import {taskToday,shiftTaskDay,taskDayLabel,taskWhenLabel,taskOrder,taskFormValues} from '../task-timing.js';
import {renderTaskForm,updateTaskTiming} from '../task-form.js';

const DAY='2026-09-10';
const values={title:'Looppad vegen',location:'Weide 6',note:'Sluit het hek.',assigneeProfileId:'actor',horseId:''};
for(const [label,input,date,time] of [
 ['general clears stale day and time',{when:'none',date:DAY,time:'11:00',addTime:'on'},null,null],
 ['today without time',{when:'today',time:'11:00'},DAY,null],
 ['tomorrow without time',{when:'tomorrow',date:DAY},'2026-09-11',null],
 ['chosen day without time',{when:'custom',date:'2026-10-03',time:'11:00'},'2026-10-03',null],
 ['explicit timed day',{when:'custom',date:'2026-10-03',time:'15:30',addTime:'on'},'2026-10-03','15:30'],
 ['explicit midnight remains a real chosen time',{when:'today',time:'00:00',addTime:'on'},DAY,'00:00'],
]) test(label,()=>{const out=taskFormValues({...values,...input},DAY);assert.deepEqual(out,{...values,horseId:null,date,time});assert(!('when' in out));assert(!('addTime' in out));});

test('optional horse stays independent of date and free location',()=>{const out=taskFormValues({...values,when:'none',horseId:'orion'},DAY);assert.equal(out.horseId,'orion');assert.equal(out.date,null);assert.equal(out.location,'Weide 6');assert.equal(out.assigneeProfileId,'actor');});
test('day shifts are civil dates across month year leap day and both Amsterdam DST boundaries',()=>{for(const [a,b] of [['2026-12-31','2027-01-01'],['2028-02-28','2028-02-29'],['2026-03-28','2026-03-29'],['2026-03-29','2026-03-30'],['2026-10-24','2026-10-25'],['2026-10-25','2026-10-26']]){assert.equal(shiftTaskDay(a,1),b);assert.equal(shiftTaskDay(b,-1),a);}});
test('server day wins over selected day and labels do not manufacture midnight',()=>{assert.equal(taskToday({today:DAY,selectedDay:'2026-09-11'}),DAY);assert.equal(taskDayLabel(null,DAY),'Zonder datum');assert.equal(taskWhenLabel({date:DAY,time:null},DAY),'Vandaag');assert.equal(taskWhenLabel({date:'2026-09-11',time:''},DAY),'Morgen');assert.equal(taskWhenLabel({date:null,time:'00:00'},DAY),'Zonder datum');assert.equal(taskWhenLabel({date:DAY,time:'00:00'},DAY),'Vandaag · 00:00');assert.match(taskDayLabel('2027-01-01',DAY),/januari 2027/);});
test('chronological ordering keeps untimed day before chosen times and general tasks separate at end',()=>{const rows=[{id:4,date:null,time:null},{id:3,date:DAY,time:'13:00'},{id:2,date:DAY,time:'00:00'},{id:1,date:DAY,time:null}];assert.deepEqual(rows.sort(taskOrder).map(x=>x.id),[1,2,3,4]);});

const options={id:'backend-task-form',horseOptions:'<option value="">Geen paard</option>',assigneeName:'assigneeProfileId',assigneeOptions:'<option value="actor">Noor</option>',locations:['Weide 6','Weide 6','<unsafe>']};
for(const [route,selectedDay,expected] of [['today','2026-09-12','today'],['stable',DAY,'none'],['tasks',DAY,'today'],['tasks','2026-09-11','tomorrow'],['planning','2026-10-03','custom']]) test(`shared form default: ${route}/${selectedDay}`,()=>{const html=renderTaskForm({route,today:DAY,selectedDay},options);assert.match(html,new RegExp(`<option value="${expected}" selected>`));assert.match(html,/<select name="horseId">/);assert.match(html,/<select name="assigneeProfileId" required>/);assert.match(html,/<input name="time" type="time" disabled>/);assert.doesNotMatch(html,/value="00:00"/);assert.equal((html.match(/<option value="Weide 6"/g)||[]).length,1);assert.match(html,/&lt;unsafe&gt;/);});

// Actual production callback with minimal DOM fields; native browser validation/layout is a separate gate.
function form(when='custom',checked=true){const elements={when:{value:when},addTime:{checked,disabled:false},date:{value:'2026-10-03',disabled:false,required:true},time:{value:'14:20',disabled:false,required:true}};const nodes=Object.fromEntries(['date','general','clock','time'].map(k=>[`[data-task-${k}]`,{hidden:false}]));const f={elements,querySelector:s=>nodes[s]};return {f,elements,nodes,change:name=>updateTaskTiming({name,closest:()=>f})};}
test('switching to no date removes prior time and disables irrelevant required controls',()=>{const h=form('none');assert.equal(h.change('when'),true);assert.equal(h.elements.time.value,'');assert.equal(h.elements.time.required,false);assert.equal(h.elements.date.required,false);assert.equal(h.elements.addTime.checked,false);assert.equal(h.elements.addTime.disabled,true);assert.equal(h.nodes['[data-task-general]'].hidden,false);assert.equal(h.nodes['[data-task-clock]'].hidden,true);});
test('custom date and opt-in time become required only when relevant',()=>{const h=form('custom',false);h.change('when');assert.equal(h.elements.date.disabled,false);assert.equal(h.elements.date.required,true);assert.equal(h.elements.time.value,'');assert.equal(h.elements.time.required,false);h.elements.addTime.checked=true;h.change('addTime');assert.equal(h.elements.time.disabled,false);assert.equal(h.elements.time.required,true);assert.equal(h.nodes['[data-task-time]'].hidden,false);});
test('turning time off clears stale value and moving back to today does not re-enable it',()=>{const h=form('custom',false);h.change('addTime');assert.equal(h.elements.time.value,'');h.elements.when.value='today';h.change('when');assert.equal(h.elements.date.disabled,true);assert.equal(h.elements.date.required,false);assert.equal(h.elements.time.disabled,true);assert.equal(h.elements.addTime.disabled,false);});
test('unrelated form input does not mutate task controls',()=>{assert.equal(updateTaskTiming({name:'title',closest:()=>null}),false);const h=form();assert.equal(h.change('location'),false);assert.equal(h.elements.time.value,'14:20');});
