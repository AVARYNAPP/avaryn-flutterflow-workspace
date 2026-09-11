begin;
select extensions.no_plan();

-- All fixture writes are rolled back; caller-side domain writes use real RPCs.
create temporary table day_actors(alias text primary key,auth_id uuid default gen_random_uuid(),profile_id uuid);
create temporary table day_ids(key text primary key,id uuid,payload jsonb);
grant select,insert,update on day_actors,day_ids to authenticated;
insert into day_actors(alias) values('admin_a'),('admin_b'),('worker'),('viewer'),('outsider');
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000',auth_id,'authenticated','authenticated',
 alias||'-personal-day@example.invalid','',now(),'{}','{}',now(),now() from day_actors;
update day_actors actor set profile_id=profile.id from public.profiles profile where profile.auth_user_id=actor.auth_id;
-- This existing suite exercises Amsterdam; account defaults are not assumed.
update public.profiles p set time_zone='Europe/Amsterdam' where p.id in(select profile_id from day_actors);
create function pg_temp.day_login(p_alias text) returns void language plpgsql as $$
begin
 perform pg_catalog.set_config('request.jwt.claim.sub',(select auth_id::text from day_actors where alias=p_alias),true);
end;
$$;
create function pg_temp.day_item(p_key text,p_day date default '2026-09-09') returns jsonb language sql as $$
 select item from pg_catalog.jsonb_array_elements(public.get_c010_personal_day(p_day)->'items') item
 where item->>'source_id'=(select id::text from day_ids where key=p_key);
$$;
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
select pg_temp.day_login('admin_a');
insert into day_ids(key,id) select 'stable_a',(public.create_c010_stable('Day A','Local',gen_random_uuid())->>'organization_id')::uuid;
select pg_temp.day_login('admin_b');
insert into day_ids(key,id) select 'stable_b',(public.create_c010_stable('Day B','Local',gen_random_uuid())->>'organization_id')::uuid;
do $$ declare label text; invitation record; accepted record; begin
 foreach label in array array['a','b'] loop
  perform pg_temp.day_login('admin_'||label);
  select * into invitation from public.create_c010_stable_invitation(
   (select id from day_ids where key='stable_'||label),'groom','worker-personal-day@example.invalid',
   statement_timestamp()+interval '7 days',gen_random_uuid());
  perform pg_temp.day_login('worker');
  select * into accepted from public.respond_stable_invitation(invitation.invitation_token,'accept',gen_random_uuid());
  insert into day_ids(key,id) values('membership_'||label,accepted.membership_id);
 end loop;
end $$;
select pg_temp.day_login('admin_a');
insert into day_ids(key,id) select 'horse',horse_id from public.create_canonical_horse_profile(
 'Personal day shared horse',null,null,'unknown',null,null,null,null,null,null,null,null,gen_random_uuid());
insert into day_ids(key,id) select 'personal_horse',horse_id from public.create_canonical_horse_profile(
 'Personal day unlinked horse',null,null,'unknown',null,null,null,null,null,null,null,null,gen_random_uuid());
select public.set_c010_horse_residency((select id from day_ids where key='horse'),(select id from day_ids where key='stable_a'),null,gen_random_uuid());
select public.set_c010_horse_collaborator((select id from day_ids where key='horse'),profile_id,'trainer',
 case when alias='worker' then array['horse.view','horse.planning.manage'] else array['horse.view'] end,true,gen_random_uuid())
 from day_actors where alias='worker';
select public.grant_horse_profile_permission((select id from day_ids where key='horse'),profile_id,
 'horse.view',null,null,null,'MANUAL_GRANT',gen_random_uuid()) from day_actors where alias in('viewer','outsider');
insert into day_ids(key,id) select 'task_a',(public.upsert_c010_stable_task(
 (select id from day_ids where key='stable_a'),null,null,'Own A task','Water instruction','water','2026-09-09',null,
 (select profile_id from day_actors where alias='worker'),'Pasture',null,null,gen_random_uuid())->>'task_id')::uuid;
insert into day_ids(key,id) select 'task_horse',(public.upsert_c010_stable_task(
 (select id from day_ids where key='stable_a'),null,null,'Own linked task','Horse instruction','water','2026-09-09','09:30',
 (select profile_id from day_actors where alias='worker'),null,null,(select id from day_ids where key='horse'),gen_random_uuid())->>'task_id')::uuid;
insert into day_ids(key,id) select 'task_other',(public.upsert_c010_stable_task(
 (select id from day_ids where key='stable_a'),null,null,'Other assignee','Private other instruction','other','2026-09-09',null,
 (select profile_id from day_actors where alias='admin_a'),null,null,null,gen_random_uuid())->>'task_id')::uuid;
select pg_temp.day_login('admin_b');
insert into day_ids(key,id) select 'task_b',(public.upsert_c010_stable_task(
 (select id from day_ids where key='stable_b'),null,null,'Own B task','B instruction','water','2026-09-09','17:30',
 (select profile_id from day_actors where alias='worker'),null,null,null,gen_random_uuid())->>'task_id')::uuid;
insert into day_ids(key,id) select 'task_tomorrow',(public.upsert_c010_stable_task(
 (select id from day_ids where key='stable_b'),null,null,'Tomorrow task','Future instruction','other','2026-09-10',null,
 (select profile_id from day_actors where alias='worker'),null,null,null,gen_random_uuid())->>'task_id')::uuid;
select pg_temp.day_login('admin_a');
insert into day_ids(key,id) select 'activity',(public.upsert_c010_horse_schedule_item(
 (select id from day_ids where key='horse'),null,null,'training','Own training','Exact training instruction','high',
 '2026-09-09 08:00+00','2026-09-09 09:00+00','Europe/Amsterdam','planned',null,
 array(select profile_id from day_actors where alias in('worker','viewer')),gen_random_uuid())->>'schedule_item_id')::uuid;
insert into day_ids(key,id) select 'personal_activity',(public.upsert_c010_horse_schedule_item(
 (select id from day_ids where key='personal_horse'),null,null,'training','Personal training','No stable needed','normal',
 '2026-09-09 10:00+00','2026-09-09 11:00+00','Europe/Amsterdam','planned',null,
 array[(select profile_id from day_actors where alias='admin_a')],gen_random_uuid())->>'schedule_item_id')::uuid;

select extensions.ok(pg_temp.day_item('activity') is null,'horse authority without participation is not a personal assignment');
select extensions.ok(pg_temp.day_item('personal_activity')->>'organization_id' is null and pg_temp.day_item('personal_activity')->>'title'='Personal training','personal activity works without any stable link');
select pg_temp.day_login('outsider');
select extensions.ok(jsonb_array_length(public.get_c010_personal_day('2026-09-09')->'items')=0,'general horse view alone exposes no personal obligations');
select pg_temp.day_login('viewer');
select extensions.ok(pg_temp.day_item('activity')->>'can_complete'='false','explicit participant with view alone cannot complete');
select extensions.throws_ok(format('select public.complete_c010_personal_activity(%L,1,%L)',(select id from day_ids where key='activity'),gen_random_uuid()),'42501','HORSE_PLANNING_PERMISSION_REQUIRED','view-only completion refused');
select pg_temp.day_login('worker');
select extensions.ok(pg_temp.day_item('task_a') is not null and pg_temp.day_item('task_b') is not null,'own tasks from both stables appear together');
select extensions.ok(pg_temp.day_item('task_other') is null,'other assignee excluded');
select extensions.ok(pg_temp.day_item('task_tomorrow') is null and pg_temp.day_item('task_tomorrow','2026-09-10') is not null,'tomorrow accessible with explicit calendar day');
select extensions.ok(pg_temp.day_item('task_a')->>'instruction'='Water instruction' and pg_temp.day_item('task_a')->>'scheduled_start_at' is null and pg_temp.day_item('task_a')->>'due_time' is null,'date-only task keeps instruction and does not invent midnight');
select extensions.ok(pg_temp.day_item('activity')->>'instruction'='Exact training instruction' and pg_temp.day_item('activity')->>'can_complete'='true','participant planning-manager receives instruction and truthful capability');
select extensions.ok((select count(*)=count(distinct item->>'source_type'||':'||(item->>'source_id')) from jsonb_array_elements(public.get_c010_personal_day('2026-09-09')->'items') item),'personal union has one item per canonical source');
select extensions.ok(public.get_c010_personal_day()->>'on_date'=public.get_c010_calendar_context()->>'today_date','default day comes from existing server calendar');
select extensions.throws_ok($$select public.get_c010_personal_day('infinity')$$,'22023','C010_PERSONAL_DAY_INVALID','infinite day refused');

-- State projection and completion preserve the entire stored activity payload.
reset role;
insert into day_ids(key,id,payload) select 'before_activity',id,to_jsonb(item) from public.schedule_items item where id=(select id from day_ids where key='activity');
insert into day_ids(key,id,payload) select 'before_participants',null,jsonb_agg(to_jsonb(p) order by p.id) from public.schedule_item_participants p where schedule_item_id=(select id from day_ids where key='activity');
set local role authenticated;
select pg_temp.day_login('worker');
insert into day_ids(key,id,payload) values('complete_request',gen_random_uuid(),null);
select extensions.throws_ok(format('select public.complete_c010_personal_activity(%L,99,%L)',(select id from day_ids where key='activity'),gen_random_uuid()),'PT409','STALE_SCHEDULE_VERSION','stale activity version is a business HTTP409');
update day_ids set payload=public.complete_c010_personal_activity((select id from day_ids where key='activity'),1,id) where key='complete_request';
select extensions.ok((select payload->>'row_version'='2' and payload->>'state'='completed' and payload->>'idempotent'='false' from day_ids where key='complete_request'),'completion advances exactly one version');
select extensions.ok(public.complete_c010_personal_activity((select id from day_ids where key='activity'),1,(select id from day_ids where key='complete_request'))->>'idempotent'='true','same completion request replays idempotently');
select extensions.ok(pg_temp.day_item('activity')->>'status'='completed' and pg_temp.day_item('activity')->>'can_complete'='false','completed activity remains in personal day with terminal state');
select extensions.throws_ok(format('select public.complete_c010_personal_activity(%L,2,%L)',(select id from day_ids where key='activity'),gen_random_uuid()),'22023','C010_ACTIVITY_NOT_COMPLETABLE','terminal activity cannot be completed a second time');
select extensions.throws_ok(format('select public.complete_c010_personal_activity(%L,2,%L)',(select id from day_ids where key='activity'),(select id from day_ids where key='complete_request')),'22023','REQUEST_ID_REUSED','request identity is bound to exact CAS input');
select public.transition_c010_stable_task((select id from day_ids where key='stable_a'),(select id from day_ids where key='task_a'),1,'complete',gen_random_uuid());
select extensions.ok(pg_temp.day_item('task_a')->>'status'='completed' and pg_temp.day_item('task_a')->>'can_complete'='false','completed stable task remains with terminal state');
reset role;
select extensions.ok((select to_jsonb(item)-array['state','terminal_at','last_mutated_by_user_id','last_mutation_request_id','row_version','updated_at']=(select payload-array['state','terminal_at','last_mutated_by_user_id','last_mutation_request_id','row_version','updated_at'] from day_ids where key='before_activity') from public.schedule_items item where id=(select id from day_ids where key='activity')),'completion preserves instructions, start/end, timezone, priority, ownership and all other fields');
select extensions.ok((select jsonb_agg(to_jsonb(p) order by p.id)=(select payload from day_ids where key='before_participants') from public.schedule_item_participants p where schedule_item_id=(select id from day_ids where key='activity')),'completion preserves all participant records byte for byte');
select extensions.ok((select count(*)=1 from private.schedule_mutation_receipts where request_id=(select id from day_ids where key='complete_request')),'one existing-infrastructure receipt retained');
select extensions.ok((select count(*)=1 from public.audit_events where correlation_id=(select id from day_ids where key='complete_request')),'one immutable canonical audit event retained');

-- Half-open windows, including the spring/fall DST transition days.
create temporary table day_windows(day date,hours integer);
insert into day_windows values('2026-03-29',23),('2026-10-25',25);
grant select on day_windows to authenticated;
set local role authenticated;
select pg_temp.day_login('admin_a');
do $$ declare c record; k integer; t0 timestamptz; t1 timestamptz; starts timestamptz; ends timestamptz; r jsonb; begin
 for c in select * from day_windows loop
  t0:=c.day::timestamp at time zone 'Europe/Amsterdam'; t1:=(c.day+1)::timestamp at time zone 'Europe/Amsterdam';
  for k in 0..4 loop
   starts:=case k when 0 then t0-interval '1 hour' when 1 then t0 when 2 then t1 when 3 then t0-interval '1 hour' else t0-interval '2 hour' end;
   ends:=case k when 0 then t0 when 1 then t0 when 2 then t1 when 3 then t0+interval '1 hour' else null end;
   r:=public.upsert_c010_horse_schedule_item((select id from day_ids where key='horse'),null,null,'training','DST item','Boundary test','normal',starts,ends,'Europe/Amsterdam','planned',null,array[(select profile_id from day_actors where alias='worker')],gen_random_uuid());
   insert into day_ids(key,id) values(c.day::text||':'||k,(r->>'schedule_item_id')::uuid);
  end loop;
 end loop;
end $$;
select pg_temp.day_login('worker');
select extensions.ok(extract(epoch from ((public.get_c010_personal_day(day)->>'day_end_at')::timestamptz-(public.get_c010_personal_day(day)->>'day_start_at')::timestamptz))/3600=hours,'DST civil-day length '||day) from day_windows;
select extensions.ok(pg_temp.day_item(day::text||':0',day) is null and pg_temp.day_item(day::text||':2',day) is null and pg_temp.day_item(day::text||':4',day) is null,'half-open exact ending/next start/old point excluded '||day) from day_windows;
select extensions.ok(pg_temp.day_item(day::text||':1',day) is not null and pg_temp.day_item(day::text||':3',day) is not null,'zero-duration beginning and crossing interval included '||day) from day_windows;

-- Revoked membership is not a substitute for, or erasure of, independent Horse ACL.
select pg_temp.day_login('admin_a');
select public.transition_horse_profile_permission_grant(g.id,g.row_version,'revoke','TEST_REVOKED',gen_random_uuid())
 from public.horse_profile_permission_grants g join public.permission_definitions p on p.id=g.permission_id
 where g.horse_id=(select id from day_ids where key='horse')
 and g.grantee_profile_id=(select profile_id from day_actors where alias='worker')
 and g.status='active' and p.code='horse.planning.manage';
select pg_temp.day_login('worker');
select extensions.ok(pg_temp.day_item('activity') is not null,'revoking manage alone preserves explicitly granted read history');
select extensions.throws_ok(format('select public.complete_c010_personal_activity(%L,1,%L)',(select id from day_ids where key='activity'),(select id from day_ids where key='complete_request')),'42501','HORSE_PLANNING_PERMISSION_REQUIRED','revoked mutation permission checked before receipt replay');
select pg_temp.day_login('admin_a');
do $$ declare r record; begin
 select id,horse_id,row_version,item_kind,title,instruction,priority,scheduled_start_at,scheduled_end_at,source_timezone,state,state_reason into r
 from public.schedule_items where id=(select id from day_ids where key='activity');
 perform public.upsert_c010_horse_schedule_item(r.horse_id,r.id,r.row_version,r.item_kind,r.title,r.instruction,r.priority,
 r.scheduled_start_at,r.scheduled_end_at,r.source_timezone,r.state,r.state_reason,
 array[(select profile_id from day_actors where alias='viewer')],gen_random_uuid());
end $$;
select pg_temp.day_login('worker');
select extensions.ok(pg_temp.day_item('activity') is null,'ended personal participation removes item despite horse view');
select extensions.throws_ok(format('select public.complete_c010_personal_activity(%L,1,%L)',(select id from day_ids where key='activity'),(select id from day_ids where key='complete_request')),'42501','HORSE_SCHEDULE_UNAVAILABLE','ended participant cannot obtain a prior completion receipt');
select pg_temp.day_login('admin_a');
do $$ declare r record; begin
 select id,horse_id,row_version,item_kind,title,instruction,priority,scheduled_start_at,scheduled_end_at,source_timezone,state,state_reason into r
 from public.schedule_items where id=(select id from day_ids where key='activity');
 perform public.upsert_c010_horse_schedule_item(r.horse_id,r.id,r.row_version,r.item_kind,r.title,r.instruction,r.priority,
 r.scheduled_start_at,r.scheduled_end_at,r.source_timezone,r.state,r.state_reason,
 array(select profile_id from day_actors where alias in('worker','viewer')),gen_random_uuid());
end $$;
select public.revoke_c010_membership((select id from day_ids where key='stable_a'),(select id from day_ids where key='membership_a'),1,gen_random_uuid());
select pg_temp.day_login('worker');
select extensions.ok(pg_temp.day_item('task_a') is null and pg_temp.day_item('task_horse') is null and pg_temp.day_item('task_b') is not null,'revoked A membership removes A tasks/history while B remains');
select extensions.ok(pg_temp.day_item('activity') is not null and pg_temp.day_item('activity')->>'organization_id' is null,'independent horse activity remains but unreadable stable context is omitted');
select pg_temp.day_login('admin_a');
select public.set_c010_horse_collaborator((select id from day_ids where key='horse'),(select profile_id from day_actors where alias='worker'),'trainer',array[]::text[],false,gen_random_uuid());
select pg_temp.day_login('worker');
select extensions.ok(pg_temp.day_item('activity') is null,'revoked horse view removes personal activity and terminal history');
select extensions.throws_ok(format('select public.complete_c010_personal_activity(%L,1,%L)',(select id from day_ids where key='activity'),(select id from day_ids where key='complete_request')),'42501','HORSE_SCHEDULE_UNAVAILABLE','revoked actor cannot obtain old receipt');
reset role;
select extensions.ok((select count(*)=1 from pg_policy where polrelid='public.stable_tasks'::regclass and polcmd in('r','*')) and (select count(*)=1 from pg_policy where polrelid='public.stable_task_events'::regclass and polcmd in('r','*')),'existing task/event RLS paths unchanged');
select extensions.ok(not has_function_privilege('anon','public.get_c010_personal_day(date)','EXECUTE') and not has_function_privilege('service_role','public.get_c010_personal_day(date)','EXECUTE') and has_function_privilege('authenticated','public.get_c010_personal_day(date)','EXECUTE'),'day RPC granted only to authenticated');
select extensions.ok(not has_function_privilege('anon','public.complete_c010_personal_activity(uuid,bigint,uuid)','EXECUTE') and not has_function_privilege('service_role','public.complete_c010_personal_activity(uuid,bigint,uuid)','EXECUTE'),'completion not available through anonymous/service client grant');
update public.profiles set status='deletion_pending',access_version=access_version+1 where id=(select profile_id from day_actors where alias='outsider');
set local role authenticated;
select pg_temp.day_login('outsider');
select extensions.throws_ok($$select public.get_c010_personal_day('2026-09-09')$$,'42501',null,'inactive actor with unchanged Auth UUID cannot read personal day');
select extensions.throws_ok(format('select public.complete_c010_personal_activity(%L,1,%L)',(select id from day_ids where key='activity'),gen_random_uuid()),'42501',null,'inactive actor cannot complete');
select set_config('request.jwt.claim.sub','',true);
select extensions.throws_ok($$select public.get_c010_personal_day('2026-09-09')$$,'42501',null,'authenticated role without real current actor refused');
reset role;
select * from extensions.finish();
rollback;
