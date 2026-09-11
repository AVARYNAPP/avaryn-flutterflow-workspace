import test from 'node:test';
import assert from 'node:assert/strict';
import {createBackendClient,civilInstant,amsterdamInstant,localParts,normalizeLoad} from '../../../apps/avaryn/src/backend-client.js';
const uid=n=>`10000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const ACTOR=uid(1),HORSE=uid(2),ITEM=uid(3),ORG=uid(4),TASK=uid(5),PLAN=uid(6),DAY='2026-09-11';
const AMS='Europe/Amsterdam',LA='America/Los_Angeles',AKL='Pacific/Auckland';
const instant='2026-09-11T00:30:45.123Z',end='2026-09-11T01:30:56.789Z';
function raw(zone=AMS){return {
 profile:[{profile_id:ACTOR,profile_status:'active',display_name:'Synthetic actor',time_zone:zone}],
 day:{on_date:DAY,time_zone:zone,calendar:{today_date:DAY,time_zone:zone},items:[{source_type:'horse_activity',schedule_item_id:ITEM,horse_id:HORSE,item_kind:'training',scheduled_start_at:instant,scheduled_end_at:end,source_timezone:AMS,status:'planned',can_complete:true},{source_type:'stable_task',source_id:TASK,title:'Civil task',due_date:DAY,due_time:'06:15:00',status:'open'}]},
 horses:[{horse_id:HORSE,display_name:'Own horse',lifecycle_status:'active',can_edit:true,can_manage_planning:true}],stables:[{organization_id:ORG,name:'Own stable',lifecycle_status:'active'}],
 workspace:{organization:{id:ORG,name:'Own stable'},horses:[{horse_id:HORSE}],memberships:[],capabilities:{}},round1:{can_manage_tasks:true,activities:[]},details:{[HORSE]:{}},
 schedules:{[HORSE]:[{schedule_item_id:ITEM,horse_id:HORSE,item_kind:'training',title:'Existing',instruction:'Unchanged note',scheduled_start_at:instant,scheduled_end_at:end,source_timezone:AMS,state:'planned',row_version:7,participant_profile_ids:[ACTOR]}]},
 feeding:{[HORSE]:{plans:[{feeding_plan_id:PLAN,plan_type:'standard',status:'active',row_version:1,effective_from:DAY,effective_until:DAY,active_version_id:uid(7),versions:[{feeding_plan_version_id:uid(7),items:[{feeding_plan_item_id:uid(8),row_version:1,round_code:'morning',local_time:'07:00:00',product_brand:'Civil feed',product_variant:'roughage',planned_quantity:1,unit_code:'kg',instruction:'Civil instruction'}]}]}]}}
};}
function fixture({data=raw(),override}={}){
 const calls=[],memory=new Map();
 const client=createBackendClient({storage:{getItem:k=>memory.get(k),setItem:(k,v)=>memory.set(k,v),removeItem:k=>memory.delete(k)},fetchImpl:async(path,options)=>{
  const body=options.body?JSON.parse(options.body):null;calls.push({path,body});
  if(override){const value=await override(path,body);if(value!==undefined)return value;}
  if(path.includes('grant_type=password'))return Response.json({access_token:'synthetic-access',refresh_token:'synthetic-refresh',expires_at:Date.now()/1000+3600,user:{id:ACTOR}});
  const routes={get_current_account_profile:data.profile,get_c010_personal_day:data.day,list_c010_horses:data.horses,list_c010_stables:data.stables,get_c010_stable_workspace:data.workspace,get_c010_stable_round1_workspace:data.round1,list_c010_horse_schedule:data.schedules[HORSE],get_canonical_horse_workspace:data.details[HORSE],get_canonical_horse_feeding:data.feeding[HORSE]};
  const name=path.split('/').at(-1);return Response.json(routes[name]??(name==='upsert_c010_horse_schedule_item'?{schedule_item_id:ITEM,row_version:8}:name==='upsert_c010_stable_task'?{task_id:TASK,row_version:2}:{feeding_plan_id:PLAN,plan_row_version:2}));
 }});
 return {client,data,calls,ready:async()=>{await client.login('synthetic@example.invalid','synthetic');return client.load();}};
}
for(const [zone,day,expected] of [[AMS,'2026-01-15','2026-01-15T11:15:00.000Z'],[AMS,'2026-07-15','2026-07-15T10:15:00.000Z'],[LA,'2026-01-15','2026-01-15T20:15:00.000Z'],[LA,'2026-07-15','2026-07-15T19:15:00.000Z'],[AKL,'2026-01-15','2026-01-14T23:15:00.000Z'],[AKL,'2026-07-15','2026-07-15T00:15:00.000Z']])test(`civil ${zone} ${day} uses seasonal offset`,()=>assert.equal(civilInstant(day,'12:15',zone),expected));
for(const [zone,day,time] of [[AMS,'2026-03-29','02:30'],[AMS,'2026-10-25','02:30'],[LA,'2026-03-08','02:30'],[LA,'2026-11-01','01:30'],[AKL,'2026-09-27','02:30'],[AKL,'2026-04-05','02:30']])test(`DST gap/fold ${zone} ${day} is rejected instead of guessed`,()=>assert.throws(()=>civilInstant(day,time,zone),e=>e.code==='INPUT_INVALID'&&/klokwisseling/.test(e.message)));
for(const [zone,day,next,hours] of [[AMS,'2026-03-29','2026-03-30',23],[AMS,'2026-10-25','2026-10-26',25],[LA,'2026-03-08','2026-03-09',23],[LA,'2026-11-01','2026-11-02',25],[AKL,'2026-09-27','2026-09-28',23],[AKL,'2026-04-05','2026-04-06',25]])test(`two local midnights ${zone} ${day} span ${hours}h`,()=>assert.equal((Date.parse(civilInstant(next,'00:00',zone))-Date.parse(civilInstant(day,'00:00',zone)))/3600000,hours));
test('Amsterdam compatibility export stays pinned and explicit seconds are retained',()=>{assert.equal(amsterdamInstant(DAY,'10:00'),civilInstant(DAY,'10:00',AMS));assert.equal(civilInstant(DAY,'12:15:42',LA),'2026-09-11T19:15:42.000Z');});
for(const [zone,date,time] of [[AMS,DAY,'02:30'],[LA,'2026-09-10','17:30'],[AKL,DAY,'12:30']])test(`${zone} normalizes both activity sources but leaves civil task/feeding date and time intact`,()=>{
 const data=raw(zone),copy=structuredClone(data),s=normalizeLoad(data,{day:'2026-09-12',organizationId:ORG});
 for(const a of [s.activities[0],s.backend.todayActivities[0]]){assert.equal(a.date,date);assert.equal(a.time,time);assert.equal(a.sourceTimezone,AMS);assert.equal(a.displayTimezone,zone);}
 assert.equal(s.tasks[0].date,DAY);assert.equal(s.tasks[0].time,'06:15');assert.equal(s.feeding[HORSE].planId,PLAN);assert.equal(s.feeding[HORSE].effectiveFrom,DAY);assert.equal(s.feeding[HORSE].meals[0].time,'07:00');assert.equal(s.backend.calendar.time_zone,zone);assert.equal(s.selectedDay,'2026-09-12');assert.deepEqual(data,copy);
});
test('Auckland instant can belong to following calendar day, Los Angeles to previous day',()=>{assert.equal(localParts('2026-09-11T23:30:00Z',AKL).date,'2026-09-12');assert.equal(localParts('2026-09-11T00:30:00Z',LA).date,'2026-09-10');});
for(const [zone,from,through] of [[AMS,'2026-08-09T22:00:00.000Z','2026-11-13T23:00:00.000Z'],[LA,'2026-08-10T07:00:00.000Z','2026-11-14T08:00:00.000Z'],[AKL,'2026-08-09T12:00:00.000Z','2026-11-13T11:00:00.000Z']])test(`authenticated load uses ${zone} interval and unchanged civil query dates`,async()=>{
 const h=fixture({data:raw(zone)});await h.ready();
 for(const c of h.calls.filter(c=>/get_c010_stable_workspace$|list_c010_horse_schedule$/.test(c.path))){assert.equal(c.body.p_from,from);assert.equal(c.body.p_through,through);}
 assert.equal(h.calls.find(c=>c.path.endsWith('get_c010_stable_round1_workspace')).body.p_on_date,DAY);assert.deepEqual(h.calls.find(c=>c.path.endsWith('get_c010_personal_day')).body,{p_on_date:null});
});
for(const zone of [LA,AKL])test(`unchanged ${zone} editor retains original instants, seconds and source zone`,async()=>{
 const h=fixture({data:raw(zone)}),s=await h.ready(),a=s.activities[0];await h.client.saveActivity({...a,note:'Only note changed'},uid(30));const p=h.calls.at(-1).body;assert.equal(p.p_scheduled_start_at,instant);assert.equal(p.p_scheduled_end_at,end);assert.equal(p.p_source_timezone,AMS);assert.equal(p.p_expected_row_version,7);assert.deepEqual(p.p_participant_profile_ids,[ACTOR]);
});
test('existing repeated-clock instant remains valid when displayed fields are unchanged',async()=>{
 const data=raw(LA);data.schedules[HORSE][0].scheduled_start_at='2026-11-01T09:30:12.123Z';data.schedules[HORSE][0].scheduled_end_at='2026-11-01T10:30:34.456Z';const h=fixture({data}),s=await h.ready();await h.client.saveActivity(s.activities[0],uid(30));assert.equal(h.calls.at(-1).body.p_scheduled_start_at,'2026-11-01T09:30:12.123Z');
});
test('changing LA displayed time converts in LA and marks changed source timezone; untouched end keeps precision',async()=>{
 const h=fixture({data:raw(LA)}),s=await h.ready();await h.client.saveActivity({...s.activities[0],time:'18:00'},uid(30));const p=h.calls.at(-1).body;assert.equal(p.p_scheduled_start_at,'2026-09-11T01:00:00.000Z');assert.equal(p.p_scheduled_end_at,end);assert.equal(p.p_source_timezone,LA);
});
for(const [zone,expected] of [[LA,'2026-09-11T19:00:00.000Z'],[AKL,'2026-09-11T00:00:00.000Z']])test(`new ${zone} activity sends current zone and exact chosen date`,async()=>{const h=fixture({data:raw(zone)});await h.ready();await h.client.saveActivity({horseId:HORSE,title:'New',date:DAY,time:'12:00',end:'13:00'},uid(30));const p=h.calls.at(-1).body;assert.equal(p.p_source_timezone,zone);assert.equal(p.p_scheduled_start_at,expected);assert.equal(p.p_schedule_item_id,null);});
test('changing an existing activity to an ambiguous LA wall time sends no mutation',async()=>{const h=fixture({data:raw(LA)}),s=await h.ready();await assert.rejects(h.client.saveActivity({...s.activities[0],date:'2026-11-01',time:'01:30',end:''},uid(30)));assert.equal(h.calls.filter(c=>c.path.endsWith('upsert_c010_horse_schedule_item')).length,0);});
for(const [kind,value] of [['invalid','Europe/Not_real'],['empty',''],['null',null],['mismatch',LA]])test(`explicit ${kind} zone cannot fall back to Amsterdam or browser zone`,async()=>{
 const data=raw();data.profile[0].time_zone=value;const h=fixture({data});await assert.rejects(h.ready(),e=>['INVALID_ACCOUNT_TIME_ZONE','CALENDAR_TIME_ZONE_MISMATCH'].includes(e.code));assert.equal(h.calls.some(c=>c.path.endsWith('list_c010_horse_schedule')),false);await assert.rejects(h.client.saveActivity({horseId:HORSE,date:DAY,time:'12:00'},uid(30)));
});
test('legacy absent fields use explicit historical fallback; profile-only timezone is consumed',()=>{const data=raw();delete data.profile[0].time_zone;delete data.day.time_zone;delete data.day.calendar.time_zone;assert.equal(normalizeLoad(data,{day:DAY}).backend.calendar.time_zone,AMS);data.profile[0].time_zone=LA;assert.equal(normalizeLoad(data,{day:DAY}).activities[0].date,'2026-09-10');});
test('equivalent IANA alias does not cause false profile/calendar race',()=>{const data=raw(LA);data.profile[0].time_zone='US/Pacific';assert.equal(normalizeLoad(data,{day:DAY}).backend.calendar.time_zone,LA);});
test('inactive verified profile is refused before scheduling reads',async()=>{const data=raw();data.profile[0].profile_status='anonymized';const h=fixture({data});await assert.rejects(h.ready());assert.equal(h.calls.some(c=>c.path.endsWith('list_c010_horse_schedule')),false);});
test('LA saveTask and saveFeedingRound keep civil dates/times, never UTC-shift them',async()=>{
 const h=fixture({data:raw(LA)});await h.ready();await h.client.saveTask({title:'Civil task',date:DAY,time:'06:15',assigneeProfileId:ACTOR,horseId:HORSE},uid(30));let p=h.calls.at(-1).body;assert.equal(p.p_due_date,DAY);assert.equal(p.p_due_time,'06:15:00');
 await h.client.saveFeedingRound({horseId:HORSE,day:DAY,mealName:'morning',items:[{id:uid(8),quantity:1,unit:'kg',product:'Civil feed',note:'Keep instruction'}]},uid(31));p=h.calls.at(-1).body;assert.equal(p.p_effective_from,DAY);assert.equal(p.p_effective_until,DAY);
});
