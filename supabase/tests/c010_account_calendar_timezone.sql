begin;
set local statement_timeout='30s';
select extensions.no_plan();
create temporary table tz_actors(alias text primary key,zone text,auth_id uuid default gen_random_uuid(),profile_id uuid,org uuid,horse uuid);
create temporary table tz_ids(key text primary key,id uuid,payload jsonb);
create temporary table tz_windows(alias text,day date,start_at timestamptz,end_at timestamptz,hours integer);
grant select,insert,update on tz_actors,tz_ids,tz_windows to authenticated;
insert into tz_actors(alias,zone) values('ams','Europe/Amsterdam'),('la','America/Los_Angeles'),('akl','Pacific/Auckland'),('outsider','UTC');
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000',auth_id,'authenticated','authenticated',alias||'-account-zone@example.invalid','',now(),'{}','{}',now(),now() from tz_actors;
update tz_actors a set profile_id=p.id from public.profiles p where p.auth_user_id=a.auth_id;
update public.profiles p set time_zone=a.zone from tz_actors a where p.id=a.profile_id;
insert into tz_windows values
 ('ams','2026-03-29','2026-03-28 23:00Z','2026-03-29 22:00Z',23),
 ('ams','2026-10-25','2026-10-24 22:00Z','2026-10-25 23:00Z',25),
 ('la','2026-03-08','2026-03-08 08:00Z','2026-03-09 07:00Z',23),
 ('la','2026-11-01','2026-11-01 07:00Z','2026-11-02 08:00Z',25),
 ('akl','2026-09-27','2026-09-26 12:00Z','2026-09-27 11:00Z',23),
 ('akl','2026-04-05','2026-04-04 11:00Z','2026-04-05 12:00Z',25);
create function pg_temp.login(who text) returns void language sql as $$select set_config('request.jwt.claim.sub',(select auth_id::text from tz_actors where alias=who),true)::void$$;
create function pg_temp.actor() returns uuid language sql as $$select profile_id from tz_actors where auth_id=auth.uid()$$;
create function pg_temp.org() returns uuid language sql as $$select org from tz_actors where auth_id=auth.uid()$$;
create function pg_temp.horse() returns uuid language sql as $$select horse from tz_actors where auth_id=auth.uid()$$;
create function pg_temp.item(k text,d date) returns jsonb language sql as $$select v from jsonb_array_elements(public.get_c010_personal_day(d)->'items')v where v->>'source_id'=(select id::text from tz_ids where key=k)$$;
create function pg_temp.task(label text,d date,t time default null) returns jsonb language sql as $$select public.upsert_c010_stable_task(pg_temp.org(),null,null,label,'Fictief','other',d,t,pg_temp.actor(),'Stalgang',null,null,gen_random_uuid())$$;
select extensions.ok(not has_function_privilege('authenticated','private.c010_actor_time_zone()','EXECUTE'),'private actor zone is not a public override API');
select extensions.ok(not has_function_privilege('anon','public.get_c010_calendar_context()','EXECUTE'),'anonymous calendar remains denied');
select extensions.ok(not has_table_privilege('authenticated','public.stable_tasks','UPDATE'),'direct task mutation remains denied');
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
do $$declare a record;r jsonb;today date;w record;k integer;starts timestamptz;ends timestamptz;begin
 for a in select * from tz_actors where alias<>'outsider' loop
  perform pg_temp.login(a.alias);
  r:=public.create_c010_stable('Calendar '||a.alias,'Fictief',gen_random_uuid());
  update tz_actors set org=(r->>'organization_id')::uuid where alias=a.alias;
  update tz_actors set horse=(select horse_id from public.create_canonical_horse_profile('Calendar horse '||a.alias,null,null,'unknown',null,null,null,null,null,null,null,null,gen_random_uuid())) where alias=a.alias;
  perform public.set_c010_horse_residency(pg_temp.horse(),pg_temp.org(),null,gen_random_uuid());
  perform public.configure_c010_facilities(pg_temp.org(),(public.get_c010_facility_workspace(pg_temp.org())->'configuration'->>'row_version')::bigint,
   '{"stall":0,"pasture":0,"paddock":0,"arena":1,"walker":0,"wash":0,"locker":0}',1,false,gen_random_uuid());
  today:=(statement_timestamp() at time zone a.zone)::date;
  insert into tz_ids select a.alias||':arena',(v->>'id')::uuid,null from jsonb_array_elements(public.get_c010_facility_workspace(pg_temp.org())->'resources')v where v->>'kind'='arena';
  insert into tz_ids values(a.alias||':booking_request',gen_random_uuid(),null);
  r:=public.save_c010_facility_booking(pg_temp.org(),null,null,(select id from tz_ids where key=a.alias||':arena'),today,'12:00','13:00','{}',1,'Oefenen','Fictief',false,(select id from tz_ids where key=a.alias||':booking_request'));
  insert into tz_ids values(a.alias||':booking',(r->>'booking_id')::uuid,r);
  r:=pg_temp.task('General '||a.alias,null);insert into tz_ids values(a.alias||':general',(r->>'task_id')::uuid,r);
  r:=pg_temp.task('Today '||a.alias,today);insert into tz_ids values(a.alias||':today',(r->>'task_id')::uuid,r);
  for w in select * from tz_windows where alias=a.alias loop
   for k in 0..3 loop
    starts:=case k when 0 then w.start_at-interval '1 hour' when 1 then w.start_at when 2 then w.end_at else w.start_at-interval '1 hour' end;
    ends:=case k when 0 then w.start_at when 1 then w.start_at when 2 then w.end_at else w.start_at+interval '1 hour' end;
    r:=public.upsert_c010_horse_schedule_item(pg_temp.horse(),null,null,'training','Boundary','Fictief','normal',starts,ends,a.zone,'planned',null,array[a.profile_id],gen_random_uuid());
    insert into tz_ids values(a.alias||':'||w.day||':'||k,(r->>'schedule_item_id')::uuid,r);
   end loop;
   r:=pg_temp.task('Civil noon '||a.alias,w.day,'12:00');insert into tz_ids values(a.alias||':'||w.day||':noon',(r->>'task_id')::uuid,r);
  end loop;
 end loop;
end$$;
-- Actual production callbacks, using independently pinned UTC transition edges.
create function pg_temp.zone_checks(who text) returns setof text language plpgsql as $$
declare a record;c jsonb;p jsonb;f jsonb;today date;w record;k integer;r jsonb;starts timestamptz;ends timestamptz;before jsonb;
begin
 perform pg_temp.login(who);select * into a from tz_actors where alias=who;
 c:=public.get_c010_calendar_context();today:=(c->>'server_now')::timestamptz at time zone a.zone;
 return next extensions.is(c->>'time_zone',a.zone,'verified profile zone '||who);
 return next extensions.is(c->>'today_date',today::text,'actual server instant yields account day '||who);
 return next extensions.ok((c->>'next_day_at')::timestamptz=(today+1)::timestamp at time zone a.zone,'next local midnight '||who);
 perform set_config('TimeZone','Pacific/Honolulu',true);
 return next extensions.is(public.get_c010_calendar_context()->>'time_zone',a.zone,'session TimeZone cannot override actor '||who);
 return next extensions.is(public.get_c010_personal_day()->>'on_date',today::text,'personal default account day '||who);
 return next extensions.is(public.get_c010_my_vitality_day()->'calendar'->>'time_zone',a.zone,'Vitality inherits account zone '||who);
 return next extensions.is(public.get_c010_stable_round1_workspace(a.org)->>'time_zone',a.zone,'stable calendar follows actor '||who);
 f:=public.get_c010_facility_workspace(a.org);
 return next extensions.ok(f->'calendar'->>'today_date'=today::text and f->'calendar'->>'time_zone'=a.zone and f->>'on_date'=today::text,'facility default and window use actor day '||who);
 return next extensions.ok(public.get_c010_facility_workspace(a.org,today+366)->'calendar'->'covered_dates'=jsonb_build_array(today,today+366),'facility explicit date and Today retained '||who);
 return next extensions.ok(exists(select 1 from jsonb_array_elements(f->'arenaBookings')v where v->>'id'=(select id::text from tz_ids where key=who||':booking') and v->>'date'=today::text and v->>'start'='12:00' and v->>'end'='13:00'),'facility stored civil slot unshifted '||who);
 return next extensions.is(public.save_c010_facility_booking(a.org,null,null,(select id from tz_ids where key=who||':arena'),today,'12:00','13:00','{}',1,'Oefenen','Fictief',false,(select id from tz_ids where key=who||':booking_request'))->>'idempotent','true','facility replay remains idempotent '||who);
 return next extensions.throws_ok(format('select public.save_c010_facility_booking(%L,null,null,%L,%L,''12:00'',''13:00'',''{}'',1,''Oefenen'','''',false,gen_random_uuid())',a.org,(select id from tz_ids where key=who||':arena'),today-1),'22023','C010_BOOKING_INPUT_INVALID','facility rejects prior account day '||who);
 return next extensions.throws_ok(format('select public.save_c010_facility_booking(%L,null,null,%L,%L,''12:00'',''13:00'',''{}'',1,''Oefenen'','''',false,gen_random_uuid())',a.org,(select id from tz_ids where key=who||':arena'),today+367),'22023','C010_BOOKING_INPUT_INVALID','facility rejects outside account booking window '||who);
 return next extensions.throws_ok(format('select public.save_c010_facility_booking(%L,%L,99,%L,%L,''12:00'',''13:00'',''{}'',1,''Oefenen'','''',false,gen_random_uuid())',a.org,(select id from tz_ids where key=who||':booking'),(select id from tz_ids where key=who||':arena'),today),'PT409','C010_BOOKING_VERSION_STALE','facility stale edit still HTTP409 '||who);
 return next extensions.throws_ok(format('select public.get_c010_facility_workspace(%L,%L)',a.org,today+367),'22023','C010_FACILITY_DAY_INVALID','facility window upper bound '||who);
 return next extensions.ok(pg_temp.item(who||':general',today+90)->>'due_date' is null and pg_temp.item(who||':general',today+90) is not null,'own general remains undated across days '||who);
 return next extensions.ok(exists(select 1 from public.list_c010_personal_today()x where x.task_id=(select id from tz_ids where key=who||':today')),'legacy personal today default follows actor '||who);
 return next extensions.ok(pg_temp.item(who||':today',today)->>'scheduled_start_at' is null,'date-only task has no fabricated midnight '||who);
 for w in select * from tz_windows where alias=who order by day loop
  p:=public.get_c010_personal_day(w.day);
  return next extensions.ok((p->>'day_start_at')::timestamptz=w.start_at and (p->>'day_end_at')::timestamptz=w.end_at,'pinned UTC boundaries '||who||' '||w.day);
  return next extensions.is((extract(epoch from ((p->>'day_end_at')::timestamptz-(p->>'day_start_at')::timestamptz))/3600)::integer,w.hours,'23/25-hour day '||who||' '||w.day);
  return next extensions.ok(pg_temp.item(who||':'||w.day||':0',w.day) is null and pg_temp.item(who||':'||w.day||':2',w.day) is null,'half-open ending and next-day point excluded '||who||' '||w.day);
  return next extensions.ok(pg_temp.item(who||':'||w.day||':1',w.day) is not null and pg_temp.item(who||':'||w.day||':3',w.day) is not null,'midnight point and crossing activity included '||who||' '||w.day);
  return next extensions.ok(exists(select 1 from jsonb_array_elements(public.get_c010_stable_round1_workspace(a.org,w.day)->'activities')v where v->>'activity_id'=(select id::text from tz_ids where key=who||':'||w.day||':1')),'round1 uses same local window '||who||' '||w.day);
  select payload into r from tz_ids where key=who||':'||w.day||':noon';
  return next extensions.ok(exists(select 1 from public.list_c010_stable_activities(a.org,w.start_at,w.end_at)x where x.activity_id=(r->>'task_id')::uuid and x.scheduled_at=(w.day+'12:00'::time) at time zone a.zone),'task civil time projects in actor zone '||who||' '||w.day);
 end loop;
 return next extensions.ok((select count(*)=count(distinct v->>'source_id') from jsonb_array_elements(public.get_c010_personal_day(today)->'items')v),'no duplicate obligations '||who);
end$$;
select pg_temp.zone_checks('ams');
select pg_temp.zone_checks('la');
select pg_temp.zone_checks('akl');
select pg_temp.login('outsider');
select extensions.throws_ok(format('select public.get_c010_stable_round1_workspace(%L)',(select org from tz_actors where alias='ams')),'42501','ORGANIZATION_PERMISSION_REQUIRED','timezone never grants foreign stable access');
select extensions.throws_ok(format('select public.get_c010_facility_workspace(%L)',(select org from tz_actors where alias='la')),'42501','C010_FACILITY_ACCESS_REQUIRED','timezone never grants facility access');
select extensions.is(jsonb_array_length(public.get_c010_personal_day()->'items'),0,'outsider has no other actors personal data');
select pg_temp.login('la');
select extensions.throws_ok(format('select public.complete_c010_personal_activity(%L,1,%L)',(select id from tz_ids where key='ams:2026-03-29:1'),gen_random_uuid()),'42501','HORSE_SCHEDULE_UNAVAILABLE','other-zone actor cannot complete foreign activity');
select extensions.throws_ok($$select pg_temp.task('Invalid loose time',null,'12:00')$$,'22023','C010_TASK_INPUT_INVALID','time without date remains invalid');
-- Changing account display zone does not rewrite stored training instants or civil dates.
reset role;
create temporary table tz_before as select id,to_jsonb(x) value from public.schedule_items x where horse_id=(select horse from tz_actors where alias='la');
update public.profiles set time_zone='Pacific/Auckland' where id=(select profile_id from tz_actors where alias='la');
set local role authenticated;
select extensions.is(public.get_c010_calendar_context()->>'time_zone','Pacific/Auckland','profile zone change takes effect on next read');
reset role;
select extensions.ok((select bool_and(to_jsonb(x)=b.value) from public.schedule_items x join tz_before b using(id)),'profile timezone update leaves all stored activity values unchanged');
select set_config('request.jwt.claim.sub','',true);
update public.profiles set status='deletion_pending',access_version=access_version+1 where id=(select profile_id from tz_actors where alias='la');
set local role authenticated;
select pg_temp.login('la');
select extensions.throws_ok('select public.get_c010_calendar_context()','42501','ACTIVE_PROFILE_REQUIRED','pending profile cannot obtain active calendar through old JWT');
select extensions.throws_ok('select public.get_c010_personal_day()','42501','ACTIVE_PROFILE_REQUIRED','pending profile cannot read personal day');
reset role;
select * from extensions.finish();
rollback;
