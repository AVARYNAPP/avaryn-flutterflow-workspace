begin;

select extensions.plan(1);

create temporary table c010_round1_fixture(
  auth_manager_a uuid not null,
  auth_manager_b uuid not null,
  auth_owner uuid not null,
  auth_groom uuid not null,
  auth_outsider uuid not null,
  manager_a uuid,
  manager_b uuid,
  owner_profile uuid,
  groom_profile uuid,
  outsider_profile uuid,
  stable_a uuid,
  stable_b uuid,
  groom_membership uuid,
  horse_a uuid,
  horse_b uuid,
  place_3 uuid,
  task_id uuid,
  open_task_id uuid
);
grant select,update on pg_temp.c010_round1_fixture to authenticated,anon,service_role;

insert into pg_temp.c010_round1_fixture(
  auth_manager_a,auth_manager_b,auth_owner,auth_groom,auth_outsider
) values(
  'c0110000-0000-4000-8000-000000000001',
  'c0110000-0000-4000-8000-000000000002',
  'c0110000-0000-4000-8000-000000000003',
  'c0110000-0000-4000-8000-000000000004',
  'c0110000-0000-4000-8000-000000000005'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
)
select '00000000-0000-0000-0000-000000000000'::uuid,auth_manager_a,
  'authenticated','authenticated','round1-manager-a@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_manager_b,
  'authenticated','authenticated','round1-manager-b@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_owner,
  'authenticated','authenticated','round1-owner@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_groom,
  'authenticated','authenticated','round1-groom@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_outsider,
  'authenticated','authenticated','round1-outsider@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture;

-- Explicit Amsterdam account fixture; SQL session timezone is independently varied.
update public.profiles profile set time_zone='Europe/Amsterdam',display_name=case profile.auth_user_id
  when 'c0110000-0000-4000-8000-000000000001' then 'Manager Alpha'
  when 'c0110000-0000-4000-8000-000000000002' then 'Manager Beta'
  when 'c0110000-0000-4000-8000-000000000003' then 'Horse Authority'
  when 'c0110000-0000-4000-8000-000000000004' then 'Groom Alpha'
  else 'Buitenstaander' end
where profile.auth_user_id::text like 'c0110000-%';

update pg_temp.c010_round1_fixture fixture set
  manager_a=(select id from public.profiles where auth_user_id=fixture.auth_manager_a),
  manager_b=(select id from public.profiles where auth_user_id=fixture.auth_manager_b),
  owner_profile=(select id from public.profiles where auth_user_id=fixture.auth_owner),
  groom_profile=(select id from public.profiles where auth_user_id=fixture.auth_groom),
  outsider_profile=(select id from public.profiles where auth_user_id=fixture.auth_outsider);

select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_round1_fixture),true);
with created as(
  select public.create_c010_stable('SDS Stables','Amsterdam','c0111000-0000-4000-8000-000000000001') result
) update pg_temp.c010_round1_fixture fixture
set stable_a=(created.result->>'organization_id')::uuid from created;

select set_config('request.jwt.claim.sub',(select auth_manager_b::text from pg_temp.c010_round1_fixture),true);
with created as(
  select public.create_c010_stable('Test Stable','Utrecht','c0111000-0000-4000-8000-000000000002') result
) update pg_temp.c010_round1_fixture fixture
set stable_b=(created.result->>'organization_id')::uuid from created;

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_round1_fixture),true);
do $$ declare invitation record; begin
  select * into invitation from public.create_c010_stable_invitation(
    (select stable_a from pg_temp.c010_round1_fixture),'groom','round1-groom@example.invalid',
    statement_timestamp()+interval '7 days','c0111100-0000-4000-8000-000000000001'
  );
  perform pg_catalog.set_config('c010.round1.groom_token',invitation.invitation_token,true);
end $$;

select set_config('request.jwt.claim.sub',(select auth_groom::text from pg_temp.c010_round1_fixture),true);
with accepted as(
  select * from public.respond_stable_invitation(
    current_setting('c010.round1.groom_token'),'accept','c0111100-0000-4000-8000-000000000002'
  )
) update pg_temp.c010_round1_fixture fixture set groom_membership=accepted.membership_id from accepted;

select set_config('request.jwt.claim.sub',(select auth_owner::text from pg_temp.c010_round1_fixture),true);
with horse as(
  select * from public.create_canonical_horse_profile(
    'Orion Round 1',null,null,'unknown',null,'Dressuur',null,null,null,null,null,null,
    'c0111200-0000-4000-8000-000000000001'
  )
) update pg_temp.c010_round1_fixture fixture set horse_a=horse.horse_id from horse;
with horse as(
  select * from public.create_canonical_horse_profile(
    'Nova Round 1',null,null,'unknown',null,'Dressuur',null,null,null,null,null,null,
    'c0111200-0000-4000-8000-000000000002'
  )
) update pg_temp.c010_round1_fixture fixture set horse_b=horse.horse_id from horse;
select public.set_c010_horse_residency(
  (select horse_a from pg_temp.c010_round1_fixture),(select stable_a from pg_temp.c010_round1_fixture),
  null,'c0111200-0000-4000-8000-000000000003'
);
select public.set_c010_horse_residency(
  (select horse_b from pg_temp.c010_round1_fixture),(select stable_b from pg_temp.c010_round1_fixture),
  null,'c0111200-0000-4000-8000-000000000004'
);
select public.set_c010_horse_collaborator(
  (select horse_a from pg_temp.c010_round1_fixture),(select manager_a from pg_temp.c010_round1_fixture),
  'trainer',array['horse.view'],true,'c0111200-0000-4000-8000-000000000005'
);
select public.set_c010_horse_collaborator(
  (select horse_a from pg_temp.c010_round1_fixture),(select groom_profile from pg_temp.c010_round1_fixture),
  'groom',array['horse.view'],true,'c0111200-0000-4000-8000-000000000006'
);

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_round1_fixture),true);
select public.update_c010_stable(
  (select stable_a from pg_temp.c010_round1_fixture),
  (select row_version from public.organizations where id=(select stable_a from pg_temp.c010_round1_fixture)),
  'SDS Stables','Amsterdam',
  'Stalstraat 10','Amsterdam','c0111300-0000-4000-8000-000000000001'
);
select public.update_c010_stable_facilities(
  (select stable_a from pg_temp.c010_round1_fixture),null,3,2,1,1,true,1,4,true,8,
  'c0111300-0000-4000-8000-000000000002'
);
update pg_temp.c010_round1_fixture fixture set place_3=(
  select id from public.stable_places where organization_id=fixture.stable_a and ordinal=3
);
select public.upsert_c010_stable_resource(
  (select stable_a from pg_temp.c010_round1_fixture),null,null,'concentrate_feed','Pavo','SportsFit',
  'c0111300-0000-4000-8000-000000000003'
);
select public.upsert_c010_stable_resource(
  (select stable_a from pg_temp.c010_round1_fixture),null,null,'bedding','AVARYN','Zaagsel',
  'c0111300-0000-4000-8000-000000000004'
);

with saved as(
  select public.upsert_c010_stable_task(
    (select stable_a from pg_temp.c010_round1_fixture),null,null,'Orion voeren','Controleer water','feeding',
    current_date,'18:00',(select groom_profile from pg_temp.c010_round1_fixture),'Weide 6',
    (select place_3 from pg_temp.c010_round1_fixture),(select horse_a from pg_temp.c010_round1_fixture),
    'c0111400-0000-4000-8000-000000000001'
  ) result
) update pg_temp.c010_round1_fixture fixture set task_id=(saved.result->>'task_id')::uuid from saved;

do $$ begin
  if (select stable_place_id from public.list_c010_stable_activities(
      (select stable_a from pg_temp.c010_round1_fixture),
      current_date::timestamptz,(current_date+1)::timestamptz,'all'
    ) where activity_id=(select task_id from pg_temp.c010_round1_fixture))
    is distinct from (select place_3 from pg_temp.c010_round1_fixture)
  then raise exception 'stable activity projection lost canonical place identity'; end if;
end $$;


reset role;
create temporary table repair_calendar_cases(on_date date primary key,hours integer);
insert into repair_calendar_cases values('2026-01-01',24),('2026-03-29',23),
  ('2026-10-25',25),('2026-12-31',24),('2028-02-29',24);
create temporary table repair_calendar_tasks(case_date date,id uuid,offset_days integer,has_time boolean);
create temporary table repair_calendar_items(case_date date,id uuid,expected_included boolean);
grant select,insert on repair_calendar_cases,repair_calendar_tasks,repair_calendar_items to authenticated;
set local role authenticated;

do $$ declare c record; offset_day integer; task_time time; saved jsonb; begin
  for c in select * from repair_calendar_cases loop
    for offset_day in -1..1 loop
      foreach task_time in array array[null::time,'00:00'::time,'23:59:59'::time] loop
        saved:=public.upsert_c010_stable_task((select stable_a from c010_round1_fixture),null,null,
          'Calendar boundary',null,'other',c.on_date+offset_day,task_time,
          (select manager_a from c010_round1_fixture),null,null,null,gen_random_uuid());
        insert into repair_calendar_tasks values(c.on_date,(saved->>'task_id')::uuid,offset_day,task_time is not null);
      end loop;
    end loop;
  end loop;
end $$;

-- Timed horse activities have half-open overlap semantics. An activity ending
-- exactly at day-start is excluded; a zero-duration item at day-start is in.
select set_config('request.jwt.claim.sub',(select auth_owner::text from c010_round1_fixture),true);
do $$ declare c record; item record; start_at timestamptz; end_at timestamptz; saved jsonb;
begin
  for c in select * from repair_calendar_cases loop
    start_at:=c.on_date::timestamp at time zone 'Europe/Amsterdam';
    end_at:=(c.on_date+1)::timestamp at time zone 'Europe/Amsterdam';
    for item in select * from(values
      (start_at-interval '1 hour',start_at,false),
      (start_at,start_at,true),(end_at,end_at,false),
      (end_at-interval '1 second',null::timestamptz,true)
    ) x(starts,ends,included) loop
      saved:=public.upsert_c010_horse_schedule_item((select horse_a from c010_round1_fixture),null,null,
        'training','Calendar instant',null,'normal',item.starts,item.ends,
        'Europe/Amsterdam','planned',null,array[]::uuid[],gen_random_uuid());
      insert into repair_calendar_items values(c.on_date,(saved->>'schedule_item_id')::uuid,item.included);
    end loop;
  end loop;
end $$;

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from c010_round1_fixture),true);
do $$ declare c record; zone text; start_at timestamptz; end_at timestamptz; n bigint; calendar jsonb;
begin
  foreach zone in array array['UTC','Pacific/Honolulu','Asia/Tokyo'] loop
    perform set_config('TimeZone',zone,true);
    for c in select * from repair_calendar_cases loop
      start_at:=c.on_date::timestamp at time zone 'Europe/Amsterdam';
      end_at:=(c.on_date+1)::timestamp at time zone 'Europe/Amsterdam';
      if extract(epoch from(end_at-start_at))/3600<>c.hours
      then raise exception 'Calendar day length broken: %, zone %',c.on_date,zone; end if;
      select count(*) into n from public.list_c010_stable_activities(
        (select stable_a from c010_round1_fixture),start_at,end_at,'all') a
        join repair_calendar_tasks t on t.id=a.activity_id where t.case_date=c.on_date;
      if n<>3 then raise exception 'Day %, session %: expected 3 current-day tasks, got %',c.on_date,zone,n; end if;
      if exists(select 1 from public.list_c010_stable_activities(
        (select stable_a from c010_round1_fixture),start_at,end_at,'all') a
        join repair_calendar_tasks t on t.id=a.activity_id where t.case_date=c.on_date and(
          t.offset_days<>0 or a.due_date<>c.on_date or (not t.has_time and a.scheduled_at is not null)))
      then raise exception 'Date-only task acquired artificial time or leaked day'; end if;
      select count(*) into n from public.list_c010_stable_activities(
        (select stable_a from c010_round1_fixture),start_at,end_at,'all') a
        join repair_calendar_items i on i.id=a.activity_id where i.case_date=c.on_date;
      if n<>2 then raise exception 'Half-open instant day expected 2, got %',n; end if;
      if exists(select 1 from public.list_c010_stable_activities(
        (select stable_a from c010_round1_fixture),start_at,end_at,'all') a
        join repair_calendar_items i on i.id=a.activity_id where i.case_date=c.on_date
          and (not i.expected_included or a.due_date<>c.on_date))
      then raise exception 'Instant end boundary or projection timezone drift'; end if;
    end loop;
    calendar:=public.get_c010_calendar_context();
    if calendar->>'time_zone'<>'Europe/Amsterdam'
      or (calendar->>'today_date')::date<>((calendar->>'server_now')::timestamptz at time zone 'Europe/Amsterdam')::date
      or (calendar->>'next_day_at')::timestamptz<=(calendar->>'server_now')::timestamptz
      or (calendar->>'next_day_at')::timestamptz<>(((calendar->>'today_date')::date+1)::timestamp at time zone 'Europe/Amsterdam')
    then raise exception 'Server calendar context depends on session/browser timezone'; end if;
  end loop;
  begin
    perform public.list_c010_stable_activities((select stable_a from c010_round1_fixture),start_at,start_at,'all');
    raise exception 'Empty instant range accepted';
  exception when invalid_parameter_value then null; end;
end $$;

-- Optional wall-clock times use PostgreSQL's explicit named-zone resolution:
-- a missing spring 02:30 normalizes forward; repeated fall 02:30 uses standard
-- time. The stored date/time are unchanged; real horse instants never re-resolve.
do $$ declare c record; saved jsonb; projected record; context jsonb; start_at timestamptz; end_at timestamptz;
begin
  for c in select * from(values
    ('2026-03-29'::date,'2026-03-29 01:30:00+00'::timestamptz),
    ('2026-10-25'::date,'2026-10-25 01:30:00+00'::timestamptz)
  ) v(on_date,resolved_at) loop
    saved:=public.upsert_c010_stable_task((select stable_a from c010_round1_fixture),null,null,
      'DST wall clock',null,'other',c.on_date,'02:30',
      (select manager_a from c010_round1_fixture),null,null,null,gen_random_uuid());
    start_at:=c.on_date::timestamp at time zone 'Europe/Amsterdam';
    end_at:=(c.on_date+1)::timestamp at time zone 'Europe/Amsterdam';
    select * into strict projected from public.list_c010_stable_activities(
      (select stable_a from c010_round1_fixture),start_at,end_at,'all')
      where activity_id=(saved->>'task_id')::uuid;
    if projected.due_date<>c.on_date or projected.due_time<>'02:30'::time
      or projected.scheduled_at<>c.resolved_at
    then raise exception 'DST wall-clock normalization contract changed'; end if;
    context:=public.get_c010_stable_round1_workspace((select stable_a from c010_round1_fixture),c.on_date,'all');
    if (context->>'on_date')::date<>c.on_date or context->>'time_zone'<>'Europe/Amsterdam'
      or context->>'today_date' is null or context->>'next_day_at' is null
    then raise exception 'Workspace lost explicit calendar selection/server context'; end if;
  end loop;
  -- A sub-day instant window still includes date-only tasks, but only timed
  -- tasks actually inside that instant interval.
  start_at:='2026-01-01 12:00:00 Europe/Amsterdam'::timestamptz;
  end_at:='2026-01-01 13:00:00 Europe/Amsterdam'::timestamptz;
  if (select count(*) from public.list_c010_stable_activities(
    (select stable_a from c010_round1_fixture),start_at,end_at,'all') a
    join repair_calendar_tasks t on t.id=a.activity_id where t.case_date='2026-01-01')<>1
  then raise exception 'Date-only sub-day overlap contract changed'; end if;
  begin
    perform public.list_c010_stable_activities((select stable_a from c010_round1_fixture),start_at,end_at,null);
    raise exception 'NULL activity scope accepted';
  exception when invalid_parameter_value then null; end;
end $$;

-- The same assignee's Today spans two canonical memberships without any
-- active stable parameter. Other actors' tasks and other dates stay excluded.
select set_config('TimeZone','UTC',true);
select set_config('request.jwt.claim.sub',(select auth_manager_b::text from c010_round1_fixture),true);
do $$ declare invitation record; today date; begin
  select * into invitation from public.create_c010_stable_invitation(
    (select stable_b from c010_round1_fixture),'groom','round1-groom@example.invalid',
    statement_timestamp()+interval '7 days',gen_random_uuid());
  perform set_config('request.jwt.claim.sub',(select auth_groom::text from c010_round1_fixture),true);
  perform public.respond_stable_invitation(invitation.invitation_token,'accept',gen_random_uuid());
  perform set_config('request.jwt.claim.sub',(select auth_manager_b::text from c010_round1_fixture),true);
  today:=(public.get_c010_calendar_context()->>'today_date')::date;
  perform public.upsert_c010_stable_task((select stable_b from c010_round1_fixture),null,null,
    'Shared personal Today',null,'other',today,null,(select groom_profile from c010_round1_fixture),null,null,null,gen_random_uuid());
  perform set_config('request.jwt.claim.sub',(select auth_manager_a::text from c010_round1_fixture),true);
  perform public.upsert_c010_stable_task((select stable_a from c010_round1_fixture),null,null,
    'Shared personal Today',null,'other',today,null,(select groom_profile from c010_round1_fixture),null,null,null,gen_random_uuid());
  perform set_config('request.jwt.claim.sub',(select auth_groom::text from c010_round1_fixture),true);
  if (select count(distinct organization_id) from public.list_c010_personal_today(null)
    where title='Shared personal Today')<>2
  then raise exception 'Personal Today lost a canonical membership'; end if;
  if exists(select 1 from public.list_c010_personal_today(today+1) where title='Shared personal Today')
  then raise exception 'Today leaked next calendar day'; end if;
end $$;
reset role;
do $$ begin
  if not has_function_privilege('authenticated','public.get_c010_calendar_context()','EXECUTE')
    or has_function_privilege('anon','public.get_c010_calendar_context()','EXECUTE')
    or has_function_privilege('service_role','public.get_c010_calendar_context()','EXECUTE')
  then raise exception 'Calendar context RPC execute allowlist changed'; end if;
end $$;
select extensions.pass('Calendar days/month/year/leap/DST, 3 session zones, date-only tasks, half-open instants and multi-stable server Today');
select * from extensions.finish();
rollback;
