begin;

select extensions.plan(1);

create temporary table c0091_pf_fixture (
  authority_user uuid not null,
  outsider_user uuid not null,
  authority_profile uuid,
  outsider_profile uuid,
  horse_id uuid,
  other_horse_id uuid,
  schedule_item_id uuid,
  base_plan_id uuid,
  base_version_id uuid,
  temporary_plan_id uuid,
  temporary_version_id uuid,
  overlap_plan_id uuid,
  overlap_version_id uuid
);
grant select,update on pg_temp.c0091_pf_fixture to authenticated,anon,service_role;

insert into pg_temp.c0091_pf_fixture(authority_user,outsider_user) values (
  'c0920000-0000-4000-8000-000000000001',
  'c0920000-0000-4000-8000-000000000002'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
)
select '00000000-0000-0000-0000-000000000000'::uuid,authority_user,
  'authenticated','authenticated','c0091-pf-authority@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c0091_pf_fixture
union all
select '00000000-0000-0000-0000-000000000000'::uuid,outsider_user,
  'authenticated','authenticated','c0091-pf-outsider@example.invalid','',now(),
  '{}'::jsonb,'{"stable_id":"spoof","role":"owner","horse_id":"spoof"}'::jsonb,
  now(),now()
from pg_temp.c0091_pf_fixture;

update pg_temp.c0091_pf_fixture fixture set
  authority_profile=(select id from public.profiles where auth_user_id=fixture.authority_user),
  outsider_profile=(select id from public.profiles where auth_user_id=fixture.outsider_user);

-- The canonical API is authenticated-only; service_role is not client
-- authority and private helpers remain private.
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','anon',true);
set local role anon;
do $$
begin
  begin
    perform public.list_canonical_horse_schedule(
      gen_random_uuid(),now(),now()+interval '1 day'
    );
    raise exception 'anon listed canonical schedule';
  exception when insufficient_privilege then null; end;
  begin
    perform public.get_canonical_horse_feeding(gen_random_uuid());
    raise exception 'anon listed canonical feeding';
  exception when insufficient_privilege then null; end;
end;
$$;
reset role;

select set_config('request.jwt.claim.role','service_role',true);
set local role service_role;
do $$
begin
  begin
    perform private.c0091_legacy_stable_context(gen_random_uuid());
    raise exception 'service role executed private C-009.1 helper';
  exception when insufficient_privilege then null; end;
  begin
    perform public.get_canonical_horse_feeding(gen_random_uuid());
    raise exception 'service role used canonical feeding client API';
  exception when insufficient_privilege then null; end;
end;
$$;
reset role;

select set_config('request.jwt.claim.role','authenticated',true);
select set_config(
  'request.jwt.claim.sub',
  (select authority_user::text from pg_temp.c0091_pf_fixture),true
);
set local role authenticated;
with created as (
  select * from public.create_canonical_horse_profile(
    'C-009.1 Planning Horse',null,null,'unknown',null,null,null,null,null,
    null,null,null,'c0921000-0000-4000-8000-000000000001'
  )
) update pg_temp.c0091_pf_fixture fixture set horse_id=created.horse_id from created;

with result as (
  select public.upsert_canonical_horse_schedule_item(
    (select horse_id from pg_temp.c0091_pf_fixture),null,null,'training',
    'Dressuurtraining','Rustige opbouw','normal',
    date_trunc('day',now())+interval '10 hours',
    date_trunc('day',now())+interval '11 hours','Europe/Amsterdam','planned',null,
    'c0922000-0000-4000-8000-000000000001'
  ) value
) update pg_temp.c0091_pf_fixture fixture
set schedule_item_id=(result.value->>'schedule_item_id')::uuid from result;

do $$
declare first_result jsonb; replay_result jsonb;
begin
  first_result := public.upsert_canonical_horse_schedule_item(
    (select horse_id from pg_temp.c0091_pf_fixture),null,null,'training',
    'Dressuurtraining','Rustige opbouw','normal',
    date_trunc('day',now())+interval '10 hours',
    date_trunc('day',now())+interval '11 hours','Europe/Amsterdam','planned',null,
    'c0922000-0000-4000-8000-000000000001'
  );
  replay_result := public.upsert_canonical_horse_schedule_item(
    (select horse_id from pg_temp.c0091_pf_fixture),null,null,'training',
    'Dressuurtraining','Rustige opbouw','normal',
    date_trunc('day',now())+interval '10 hours',
    date_trunc('day',now())+interval '11 hours','Europe/Amsterdam','planned',null,
    'c0922000-0000-4000-8000-000000000001'
  );
  if first_result->>'schedule_item_id'<>replay_result->>'schedule_item_id'
    or (replay_result->>'idempotent')::boolean is not true
  then raise exception 'canonical schedule idempotency failed'; end if;
  if (select count(*) from public.list_canonical_horse_schedule(
    (select horse_id from pg_temp.c0091_pf_fixture),
    now()-interval '1 day',now()+interval '2 days'
  ))<>1 then raise exception 'horse schedule projection failed'; end if;
end;
$$;

select public.upsert_canonical_horse_schedule_item(
  (select horse_id from pg_temp.c0091_pf_fixture),
  (select schedule_item_id from pg_temp.c0091_pf_fixture),1,'training',
  'Dressuurtraining','Afgerond zonder bijzonderheden','normal',
  date_trunc('day',now())+interval '10 hours',
  date_trunc('day',now())+interval '11 hours','Europe/Amsterdam','completed',null,
  'c0922000-0000-4000-8000-000000000002'
);

-- Create and activate a durable base plan without fabricating stable context.
with result as (
  select public.create_canonical_horse_feeding_plan(
    (select horse_id from pg_temp.c0091_pf_fixture),'standard','Basisvoeding',
    current_date,null,'Eerste basisplan',
    'c0923000-0000-4000-8000-000000000001'
  ) value
) update pg_temp.c0091_pf_fixture fixture set
  base_plan_id=(result.value->>'feeding_plan_id')::uuid,
  base_version_id=(result.value->>'feeding_plan_version_id')::uuid
from result;

do $$
declare first_result jsonb; replay_result jsonb;
begin
  first_result := public.upsert_canonical_horse_feeding_item(
    (select horse_id from pg_temp.c0091_pf_fixture),
    (select base_version_id from pg_temp.c0091_pf_fixture),null,null,
    'feed',null,'Basisbrok',null,1.5,'kg','bucket','ochtend','07:30',
    null,null,'base-morning-feed','Rustig voeren',
    'c0923100-0000-4000-8000-000000000001'
  );
  replay_result := public.upsert_canonical_horse_feeding_item(
    (select horse_id from pg_temp.c0091_pf_fixture),
    (select base_version_id from pg_temp.c0091_pf_fixture),null,null,
    'feed',null,'Basisbrok',null,1.5,'kg','bucket','ochtend','07:30',
    null,null,'base-morning-feed','Rustig voeren',
    'c0923100-0000-4000-8000-000000000001'
  );
  if first_result->>'feeding_plan_item_id'<>replay_result->>'feeding_plan_item_id'
    or (replay_result->>'idempotent')::boolean is not true
  then raise exception 'canonical Feeding item idempotency failed'; end if;
end;
$$;
select public.upsert_canonical_horse_feeding_item(
  (select horse_id from pg_temp.c0091_pf_fixture),
  (select base_version_id from pg_temp.c0091_pf_fixture),null,null,
  'water','','Water','','10','l','bucket','middag','12:30',
  null,null,'base-afternoon-water','',
  'c0923100-0000-4000-8000-000000000002'
);
do $$
begin
  begin
    perform public.upsert_canonical_horse_feeding_item(
      (select horse_id from pg_temp.c0091_pf_fixture),
      (select base_version_id from pg_temp.c0091_pf_fixture),null,null,
      'unknown',null,'Ongeldig',null,1,'kg','bucket','middag','12:45',
      null,null,'invalid-category',null,gen_random_uuid()
    );
    raise exception 'unknown canonical Feeding category succeeded';
  exception when invalid_parameter_value then null; end;
end;
$$;
select public.transition_canonical_horse_feeding_version(
  (select horse_id from pg_temp.c0091_pf_fixture),
  (select base_version_id from pg_temp.c0091_pf_fixture),1,'approve',
  'c0923200-0000-4000-8000-000000000001'
);
select public.transition_canonical_horse_feeding_version(
  (select horse_id from pg_temp.c0091_pf_fixture),
  (select base_version_id from pg_temp.c0091_pf_fixture),2,'activate',
  'c0923200-0000-4000-8000-000000000002'
);

-- A temporary plan overrides only during its window. The base plan stays
-- active and intact, and an overlapping temporary plan is rejected.
with result as (
  select public.create_canonical_horse_feeding_plan(
    (select horse_id from pg_temp.c0091_pf_fixture),'temporary','Wedstrijdschema',
    current_date,current_date+2,'Tijdelijke wedstrijdaanpassing',
    'c0923300-0000-4000-8000-000000000001'
  ) value
) update pg_temp.c0091_pf_fixture fixture set
  temporary_plan_id=(result.value->>'feeding_plan_id')::uuid,
  temporary_version_id=(result.value->>'feeding_plan_version_id')::uuid
from result;
select public.upsert_canonical_horse_feeding_item(
  (select horse_id from pg_temp.c0091_pf_fixture),
  (select temporary_version_id from pg_temp.c0091_pf_fixture),null,null,
  'supplement',null,'Elektrolyten',null,40,'g','bucket','ochtend','07:30',
  null,null,'base-morning-feed','Alleen tijdens wedstrijdschema',
  'c0923400-0000-4000-8000-000000000001'
);
select public.transition_canonical_horse_feeding_version(
  (select horse_id from pg_temp.c0091_pf_fixture),
  (select temporary_version_id from pg_temp.c0091_pf_fixture),1,'approve',
  'c0923500-0000-4000-8000-000000000001'
);
select public.transition_canonical_horse_feeding_version(
  (select horse_id from pg_temp.c0091_pf_fixture),
  (select temporary_version_id from pg_temp.c0091_pf_fixture),2,'activate',
  'c0923500-0000-4000-8000-000000000002'
);

with result as (
  select public.create_canonical_horse_feeding_plan(
    (select horse_id from pg_temp.c0091_pf_fixture),'temporary','Conflict',
    current_date+1,current_date+3,'Overlaptest',
    'c0923600-0000-4000-8000-000000000001'
  ) value
) update pg_temp.c0091_pf_fixture fixture set
  overlap_plan_id=(result.value->>'feeding_plan_id')::uuid,
  overlap_version_id=(result.value->>'feeding_plan_version_id')::uuid
from result;
select public.upsert_canonical_horse_feeding_item(
  (select horse_id from pg_temp.c0091_pf_fixture),
  (select overlap_version_id from pg_temp.c0091_pf_fixture),null,null,
  'hay',null,'Hooi',null,5,'kg','hay_net','avond','18:00',null,null,
  'base-evening-hay',null,'c0923700-0000-4000-8000-000000000001'
);
select public.transition_canonical_horse_feeding_version(
  (select horse_id from pg_temp.c0091_pf_fixture),
  (select overlap_version_id from pg_temp.c0091_pf_fixture),1,'approve',
  'c0923800-0000-4000-8000-000000000001'
);
do $$
begin
  begin
    perform public.transition_canonical_horse_feeding_version(
      (select horse_id from pg_temp.c0091_pf_fixture),
      (select overlap_version_id from pg_temp.c0091_pf_fixture),2,'activate',
      'c0923800-0000-4000-8000-000000000002'
    );
    raise exception 'overlapping temporary plan activated';
  exception when exclusion_violation then null; end;
end;
$$;

do $$
declare feeding jsonb;
begin
  feeding := public.get_canonical_horse_feeding(
    (select horse_id from pg_temp.c0091_pf_fixture)
  );
  if feeding->>'active_plan_id'<>(select temporary_plan_id::text from pg_temp.c0091_pf_fixture)
    or (select status from public.feeding_plans
      where id=(select base_plan_id from pg_temp.c0091_pf_fixture))<>'active'
    or (select stable_id from public.feeding_plans
      where id=(select base_plan_id from pg_temp.c0091_pf_fixture)) is not null
    or (select stable_id from public.schedule_items
      where id=(select schedule_item_id from pg_temp.c0091_pf_fixture)) is not null
  then raise exception 'base/temporary precedence or standalone scope failed'; end if;
end;
$$;
reset role;

-- An unrelated profile cannot discover or mutate either domain. Forged JWT
-- metadata does not influence Horse Authority.
select set_config(
  'request.jwt.claim.sub',
  (select outsider_user::text from pg_temp.c0091_pf_fixture),true
);
set local role authenticated;
with created as (
  select * from public.create_canonical_horse_profile(
    'C-009.1 Other Horse',null,null,'unknown',null,null,null,null,null,
    null,null,null,'c0921000-0000-4000-8000-000000000002'
  )
) update pg_temp.c0091_pf_fixture fixture set other_horse_id=created.horse_id from created;
do $$
begin
  begin
    perform public.list_canonical_horse_schedule(
      (select horse_id from pg_temp.c0091_pf_fixture),
      now()-interval '1 day',now()+interval '2 days'
    );
    raise exception 'outsider listed another horse schedule';
  exception when insufficient_privilege then null; end;
  begin
    perform public.get_canonical_horse_feeding(
      (select horse_id from pg_temp.c0091_pf_fixture)
    );
    raise exception 'outsider listed another horse feeding';
  exception when insufficient_privilege then null; end;
  begin
    perform public.upsert_canonical_horse_schedule_item(
      (select horse_id from pg_temp.c0091_pf_fixture),null,null,'task','Forged',
      'Forged','normal',now(),null,'Europe/Amsterdam','planned',null,gen_random_uuid()
    );
    raise exception 'outsider forged horse schedule write';
  exception when insufficient_privilege then null; end;
  if exists (
    select 1 from public.schedule_items
    where id=(select schedule_item_id from pg_temp.c0091_pf_fixture)
  ) or exists (
    select 1 from public.feeding_plans
    where id=(select base_plan_id from pg_temp.c0091_pf_fixture)
  ) then raise exception 'RLS leaked another horse domain data'; end if;
end;
$$;
reset role;

do $$
begin
  if (select count(*) from public.schedule_items
      where horse_id=(select horse_id from pg_temp.c0091_pf_fixture))<>1
    or (select count(*) from public.feeding_plans
      where horse_id=(select horse_id from pg_temp.c0091_pf_fixture))<>3
    or (select count(*) from public.audit_events
      where scope_kind='horse'
        and scope_id=(select horse_id from pg_temp.c0091_pf_fixture)
        and metadata->>'operation_code' like 'canonical_%')<8
    or exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name in (
        'schedule_series','schedule_items','feeding_plans',
        'feeding_plan_versions','feeding_plan_items'
      ) and column_name='stable_id' and is_nullable<>'YES'
    )
    or exists (
      select 1
      from pg_catalog.pg_proc procedure
      join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
      where namespace.nspname='public'
        and procedure.proname='upsert_canonical_horse_feeding_item'
        and (
          position(
            'pg_catalog.nullif' in pg_catalog.lower(pg_catalog.pg_get_functiondef(procedure.oid))
          )>0
          or pg_catalog.pg_get_function_result(procedure.oid)<>'jsonb'
          or not procedure.prosecdef
          or procedure.proconfig<>array['search_path=""']::text[]
          or not pg_catalog.has_function_privilege('authenticated',procedure.oid,'EXECUTE')
          or pg_catalog.has_function_privilege('anon',procedure.oid,'EXECUTE')
          or pg_catalog.has_function_privilege('service_role',procedure.oid,'EXECUTE')
        )
    )
  then raise exception 'canonical rescoping schema, audit or retention invariant failed'; end if;
end;
$$;

select extensions.ok(true,'C-009.1 canonical Planning/Feeding rescoping security matrix passed');
select * from extensions.finish();

rollback;
