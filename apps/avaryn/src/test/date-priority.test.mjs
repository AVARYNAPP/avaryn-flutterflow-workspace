import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
import {dashboardClock,browserDay,activityDay,browserActivity} from '../browser-clock.js';
import {renderToday} from '../daily-ui.js';
import {vitalityTraining} from '../vitality.js';
import {INITIAL_STATE} from '../data.js';
import {createContext} from '../components.js';

for(const [h,m,want] of [[0,0,'Goedenavond'],[4,59,'Goedenavond'],[5,0,'Goedemorgen'],[11,59,'Goedemorgen'],[12,0,'Goedemiddag'],[17,59,'Goedemiddag'],[18,0,'Goedenavond'],[23,59,'Goedenavond']]){
  test(`local greeting ${h}:${m}`,()=>assert.equal(dashboardClock(new Date(2026,8,11,h,m)).greeting,want));
}
test('Dutch current date and local midnight, independent of fixture date',()=>{
  assert.equal(dashboardClock(new Date(2026,8,11,23,59)).dateLabel,'Vrijdag 11 september');
  assert.equal(dashboardClock(new Date(2026,8,12,0,0)).dateLabel,'Zaterdag 12 september');
  assert.equal(browserDay(new Date(2027,0,1,0,0)),'2027-01-01');
});
for(const [tz,day,greeting,label] of [
  ['Europe/Amsterdam','2026-09-12','Goedenavond','Zaterdag 12 september'],
  ['America/Los_Angeles','2026-09-11','Goedemiddag','Vrijdag 11 september'],
  ['Asia/Tokyo','2026-09-12','Goedemorgen','Zaterdag 12 september']
])test(`browser-local timezone ${tz}`,()=>{
  const module=new URL('../browser-clock.js',import.meta.url).href;
  const code=`import {dashboardClock,activityDay} from ${JSON.stringify(module)}; const at='2026-09-11T23:30:00Z';console.log(JSON.stringify({clock:dashboardClock(new Date(at)),day:activityDay({scheduledStartAt:at,date:'2026-09-12'})}));`;
  const result=spawnSync(process.execPath,['--input-type=module','-e',code],{env:{...process.env,TZ:tz},encoding:'utf8'});
  assert.equal(result.status,0,result.stderr);const actual=JSON.parse(result.stdout);
  assert.deepEqual(actual,{clock:{day,dateLabel:label,greeting},day});
});
const now=new Date(2026,8,11,14,30),day=browserDay(now);
function state(training=true){const s=structuredClone(INITIAL_STATE);s.today='2026-09-10';s.selectedDay='2026-09-14';s.activities=training?[{id:'clock-test',horseId:s.horses[0].id,type:'Training',status:'planned',date:day,time:'16:00',end:'16:45',title:'Test training'}]:[];return s;}
test('training appears once directly after next appointment and before tasks',()=>{
  const s=state(),html=renderToday(s,createContext(s),now);
  const indexes=['class="next-card"','class="vitality-card"','Dit staat nog open','Paarden vandaag','Voeding vandaag'].map(x=>html.indexOf(x));
  assert.ok(indexes.every((n,i)=>n>=0&&(!i||n>indexes[i-1])));
  assert.equal((html.match(/aria-label="Ruiter & fitheid"/g)||[]).length,1);
  assert.ok(html.includes('Warming-up voor je rit'));assert.ok(html.includes('Vrijdag 11 september'));assert.ok(html.includes('Goedemiddag'));
});
test('rest day focus is below tasks, horses and feeding',()=>{
  const s=state(false),html=renderToday(s,createContext(s),now);
  assert.ok(html.indexOf('class="vitality-card"')>html.indexOf('Open de voerinstructies'));
  assert.ok(html.includes('Kies een focuspunt voor je volgende rit.'));assert.ok(!html.includes('Warming-up voor je rit'));
  assert.equal((html.match(/aria-label="Ruiter & fitheid"/g)||[]).length,1);
});
test('stale server date and selected calendar date cannot change header or priority',()=>{
  const s=state();s.backend={connected:true,actor:{id:'a',name:'Test gebruiker',initials:'TG',roleKind:'rider',accessibleHorseIds:s.horses.map(h=>h.id),personalHorseIds:[],assignedHorseIds:[]},calendar:{today_date:'2026-09-10'},todayActivities:s.activities,todayTasks:[]};
  s.functionProfiles={a:['rider']};const before=JSON.stringify(s);renderToday(s,createContext(s),now);assert.equal(JSON.stringify(s),before);
  assert.ok(renderToday(s,createContext(s),now).includes('Vrijdag 11 september'));
});
for(const status of ['completed','cancelled'])test(`${status} training does not promote card`,()=>{
  const s=state();s.activities[0].status=status;
  assert.equal(vitalityTraining(s,day),null);assert.ok(!renderToday(s,createContext(s),now).includes('Warming-up voor je rit'));
});
test('training on another day does not promote card',()=>{const s=state();s.activities[0].date='2026-09-12';assert.equal(vitalityTraining(s,day),null);});
test('no fixed greeting, fixture date or Amsterdam timezone in dashboard header',()=>{
  const source=readFileSync(new URL('../daily-ui.js',import.meta.url),'utf8');
  assert.ok(!source.includes('Goedemorgen'));assert.ok(!source.slice(source.indexOf('export function renderToday'),source.indexOf('export function renderStable')).includes('2026-09-10'));assert.ok(!source.includes('Europe/Amsterdam'));
});

const accountClockState=zone=>({backend:{connected:true,profile:{profile_status:'active',time_zone:zone},calendar:{time_zone:zone,today_date:'2026-09-10'}}});
for(const [zone,day,greeting,label] of [
  ['Europe/Amsterdam','2026-09-12','Goedenavond','Zaterdag 12 september'],
  ['America/Los_Angeles','2026-09-11','Goedemiddag','Vrijdag 11 september'],
  ['Pacific/Auckland','2026-09-12','Goedemorgen','Zaterdag 12 september']
])test(`verified account header ${zone} overrides browser clock without mutating server calendar`,()=>{
  const s=accountClockState(zone),copy=structuredClone(s);
  assert.deepEqual(dashboardClock(new Date('2026-09-11T23:30:00Z'),s),{day,dateLabel:label,greeting});assert.deepEqual(s,copy);
});
for(const [at,greeting] of [['11:59','Goedenavond'],['12:00','Goedemorgen'],['18:59','Goedemorgen'],['19:00','Goedemiddag'],['00:59','Goedemiddag'],['01:00','Goedenavond']])test(`LA account greeting boundary UTC ${at}`,()=>{
  assert.equal(dashboardClock(new Date(`2026-09-11T${at}:00Z`),accountClockState('America/Los_Angeles')).greeting,greeting);
});
test('account midnight changes header independently of stale server/selected day',()=>{
  const s=accountClockState('America/Los_Angeles');s.selectedDay='2026-10-01';
  assert.equal(dashboardClock(new Date('2026-09-12T06:59:00Z'),s).dateLabel,'Vrijdag 11 september');
  assert.equal(dashboardClock(new Date('2026-09-12T07:00:00Z'),s).dateLabel,'Zaterdag 12 september');
  assert.equal(s.backend.calendar.today_date,'2026-09-10');assert.equal(s.selectedDay,'2026-10-01');
});
for(const mode of ['demo','missing-profile','inactive'])test(`${mode} retains browser clock despite stray calendar metadata`,()=>{
  const s=accountClockState('Pacific/Auckland');if(mode==='demo')s.backend.connected=false;else if(mode==='missing-profile')delete s.backend.profile;else s.backend.profile.profile_status='anonymized';
  const at=new Date('2026-09-11T23:30:00Z');assert.deepEqual(dashboardClock(at,s),dashboardClock(at));
});
test('account activity day and displayed times keep midnight training on the same day as header',()=>{
  const a={scheduledStartAt:'2026-09-12T00:30:00Z',scheduledEndAt:'2026-09-12T01:30:00Z',displayTimezone:'America/Los_Angeles',date:'2026-09-11'};
  assert.equal(activityDay(a),'2026-09-11');assert.equal(browserActivity(a).time,'17:30');assert.equal(browserActivity(a).end,'18:30');
  const b={...a,displayTimezone:'Pacific/Auckland'};assert.equal(activityDay(b),'2026-09-12');assert.equal(browserActivity(b).time,'12:30');
});
test('Today next card, warmup priority and horse time agree with verified LA header',()=>{
  const s=state(false);s.today='2026-09-11';s.backend={...accountClockState('America/Los_Angeles').backend,actor:{id:'a',name:'Test gebruiker',initials:'TG',roleKind:'rider',accessibleHorseIds:s.horses.map(h=>h.id),personalHorseIds:[],assignedHorseIds:[]},todayActivities:[],todayTasks:[]};
  s.backend.calendar.today_date=s.today;s.functionProfiles={a:['rider']};
  s.activities=[{id:'zone-training',horseId:s.horses[0].id,type:'Training',status:'planned',isMine:true,date:'2026-09-11',time:'17:30',end:'18:30',title:'Test training',scheduledStartAt:'2026-09-12T00:30:00Z',scheduledEndAt:'2026-09-12T01:30:00Z',displayTimezone:'America/Los_Angeles'}];
  const html=renderToday(s,createContext(s),new Date('2026-09-11T23:30:00Z'));
  assert.match(html,/Vrijdag 11 september/);assert.match(html,/Goedemiddag/);assert.match(html,/17:30 – 18:30/);assert.match(html,/17:30 · Training/);
  assert.ok(html.indexOf('class="next-card"')<html.indexOf('class="vitality-card"'));assert.ok(html.indexOf('class="vitality-card"')<html.indexOf('Dit staat nog open'));assert.match(html,/Warming-up voor je rit/);
});
function clockRefreshFixture({state,now,oldDay,hidden=false}){
  const source=readFileSync(new URL('../app.js',import.meta.url),'utf8');
  const match=source.match(/function refreshTodayClock\(\)\{[\s\S]*?\n\}/);assert.ok(match);
  const date={textContent:''},greeting={textContent:''};let renders=0;
  const header={dataset:{todayDay:oldDay},querySelector:q=>q==='[data-today-date]'?date:greeting};
  const document={hidden,querySelector:()=>header};
  class FixedDate extends Date{constructor(){super(now);}}
  const refresh=new Function('state','document','dashboardClock','render','Date',`${match[0]};return refreshTodayClock;`)(state,document,dashboardClock,()=>renders++,FixedDate);
  return {refresh,date,greeting,get renders(){return renders;}};
}
test('actual focus/timer refresh uses same account clock as initial rendering',()=>{
  const s=accountClockState('America/Los_Angeles'),h=clockRefreshFixture({state:s,now:'2026-09-11T23:30:00Z',oldDay:'2026-09-11'});h.refresh();
  assert.equal(h.renders,0);assert.equal(h.date.textContent,'Vrijdag 11 september');assert.equal(h.greeting.textContent,'Goedemiddag');assert.equal(s.backend.calendar.today_date,'2026-09-10');
});
test('actual refresh rerenders once after account midnight, but stays idle while hidden',()=>{
  const s=accountClockState('America/Los_Angeles'),h=clockRefreshFixture({state:s,now:'2026-09-12T07:00:00Z',oldDay:'2026-09-11'});h.refresh();assert.equal(h.renders,1);
  const hidden=clockRefreshFixture({state:s,now:'2026-09-12T07:00:00Z',oldDay:'2026-09-11',hidden:true});hidden.refresh();assert.equal(hidden.renders,0);
});
