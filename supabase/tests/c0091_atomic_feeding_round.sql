begin;

create temporary table c0091_atomic_feeding_fixture(
  authority_user uuid not null,
  outsider_user uuid not null,
  horse_id uuid,
  other_horse_id uuid,
  base_plan_id uuid,
  base_version_id uuid,
  base_plan_row_version bigint,
  temporary_plan_id uuid,
  other_plan_id uuid
);
grant select,update on pg_temp.c0091_atomic_feeding_fixture
  to authenticated,anon,service_role;

insert into pg_temp.c0091_atomic_feeding_fixture(authority_user,outsider_user)
values(
  'c0911000-0000-4000-8000-000000000001',
  'c0911000-0000-4000-8000-000000000002'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
)
select '00000000-0000-0000-0000-000000000000'::uuid,authority_user,
  'authenticated','authenticated','c0091-atomic-authority@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c0091_atomic_feeding_fixture
union all
select '00000000-0000-0000-0000-000000000000'::uuid,outsider_user,
  'authenticated','authenticated','c0091-atomic-outsider@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c0091_atomic_feeding_fixture;

-- The route is authenticated-only.
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','anon',true);
set local role anon;
do $$
begin
  begin
    perform public.save_canonical_horse_feeding_round(
      extensions.gen_random_uuid(),'standard',null,null,'morning',current_date,
      null,'[]'::jsonb,extensions.gen_random_uuid()
    );
    raise exception 'anon executed atomic Feeding route';
  exception when insufficient_privilege then null; end;
end;
$$;
reset role;

select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',
  (select authority_user::text from pg_temp.c0091_atomic_feeding_fixture),true);
set local role authenticated;
with created as (
  select * from public.create_canonical_horse_profile(
    'C-009.1 Atomic Feeding Horse',null,null,'unknown',null,null,null,null,null,
    null,null,null,'c0911100-0000-4000-8000-000000000001'
  )
) update pg_temp.c0091_atomic_feeding_fixture fixture
set horse_id=created.horse_id from created;

-- Product two is invalid. Validation occurs before DML, so neither product one
-- nor an empty plan may survive the caught subtransaction.
do $$
declare before_plans integer; before_items integer;
begin
  select count(*) into before_plans from public.feeding_plans;
  select count(*) into before_items from public.feeding_plan_items;
  begin
    perform public.save_canonical_horse_feeding_round(
      (select horse_id from pg_temp.c0091_atomic_feeding_fixture),
      'standard',null,null,'morning',current_date,null,
      '[{"product_type":"pellet","description":"Basisbrok","quantity":1.5,"unit_code":"kg"},
        {"product_type":"mash","description":"Ongeldig","quantity":0,"unit_code":"kg"}]'::jsonb,
      'c0911200-0000-4000-8000-000000000001'
    );
    raise exception 'invalid second product succeeded';
  exception when invalid_parameter_value then null; end;
  if (select count(*) from public.feeding_plans)<>before_plans
    or (select count(*) from public.feeding_plan_items)<>before_items
  then raise exception 'invalid product left partial Feeding data'; end if;
end;
$$;

-- One atomic request stores two products, including canonical `bale`.
with saved as (
  select public.save_canonical_horse_feeding_round(
    (select horse_id from pg_temp.c0091_atomic_feeding_fixture),
    'standard',null,null,'morning',current_date,null,
    '[{"product_type":"roughage","description":"Weidehooi","quantity":1,"unit_code":"bale","note":"Langzaam voeren"},
      {"product_type":"pellet","description":"Basisbrok","quantity":1.5,"unit_code":"kg"}]'::jsonb,
    'c0911200-0000-4000-8000-000000000002'
  ) value
) update pg_temp.c0091_atomic_feeding_fixture fixture set
  base_plan_id=(saved.value->>'feeding_plan_id')::uuid,
  base_version_id=(saved.value->>'feeding_plan_version_id')::uuid,
  base_plan_row_version=(saved.value->>'plan_row_version')::bigint
from saved;

do $$
declare replay jsonb;
begin
  if (select count(*) from public.feeding_plan_items item
      where item.feeding_plan_version_id=(select base_version_id from pg_temp.c0091_atomic_feeding_fixture))<>2
    or not exists (
      select 1 from public.feeding_plan_items item
      where item.feeding_plan_version_id=(select base_version_id from pg_temp.c0091_atomic_feeding_fixture)
        and item.unit_code='bale' and item.product_variant='roughage'
    )
  then raise exception 'atomic multi-product or bale save failed'; end if;
  replay := public.save_canonical_horse_feeding_round(
    (select horse_id from pg_temp.c0091_atomic_feeding_fixture),
    'standard',null,null,'morning',current_date,null,
    '[{"product_type":"roughage","description":"Weidehooi","quantity":1,"unit_code":"bale","note":"Langzaam voeren"},
      {"product_type":"pellet","description":"Basisbrok","quantity":1.5,"unit_code":"kg"}]'::jsonb,
    'c0911200-0000-4000-8000-000000000002'
  );
  if (replay->>'idempotent')::boolean is not true
    or (select count(*) from public.feeding_plan_items item
      where item.feeding_plan_version_id=(select base_version_id from pg_temp.c0091_atomic_feeding_fixture))<>2
  then raise exception 'atomic Feeding replay duplicated data'; end if;
end;
$$;

-- Adding another round creates and activates one immutable successor version,
-- preserving the first round without duplicates.
with saved as (
  select public.save_canonical_horse_feeding_round(
    (select horse_id from pg_temp.c0091_atomic_feeding_fixture),'standard',
    (select base_plan_id from pg_temp.c0091_atomic_feeding_fixture),
    (select base_plan_row_version from pg_temp.c0091_atomic_feeding_fixture),
    'afternoon',current_date,null,
    '[{"product_type":"mash","description":"Herstelmash","quantity":500,"unit_code":"g"}]'::jsonb,
    'c0911200-0000-4000-8000-000000000003'
  ) value
) update pg_temp.c0091_atomic_feeding_fixture fixture set
  base_version_id=(saved.value->>'feeding_plan_version_id')::uuid,
  base_plan_row_version=(saved.value->>'plan_row_version')::bigint
from saved;

do $$
begin
  if (select count(*) from public.feeding_plan_items item
      where item.feeding_plan_version_id=(select base_version_id from pg_temp.c0091_atomic_feeding_fixture))<>3
    or (select count(distinct item.round_code) from public.feeding_plan_items item
      where item.feeding_plan_version_id=(select base_version_id from pg_temp.c0091_atomic_feeding_fixture))<>2
  then raise exception 'round edit lost data or created duplicates'; end if;
end;
$$;

-- A later first-entry style request may omit the plan ID. The singleton
-- wrapper resolves and updates the same durable Basisvoeding under the horse
-- lock instead of creating a second functional standard plan.
with saved as (
  select public.save_canonical_horse_feeding_round(
    (select horse_id from pg_temp.c0091_atomic_feeding_fixture),
    'standard',null,null,'evening',current_date,null,
    '[{"product_type":"roughage","description":"Avondhooi","quantity":1,"unit_code":"bale"}]'::jsonb,
    'c0911200-0000-4000-8000-000000000006'
  ) value
) update pg_temp.c0091_atomic_feeding_fixture fixture set
  base_version_id=(saved.value->>'feeding_plan_version_id')::uuid,
  base_plan_row_version=(saved.value->>'plan_row_version')::bigint
from saved
where (saved.value->>'feeding_plan_id')::uuid=fixture.base_plan_id;

do $$
begin
  if (select count(*) from public.feeding_plans plan
      where plan.horse_id=(select horse_id from pg_temp.c0091_atomic_feeding_fixture)
        and plan.plan_type='standard' and plan.status<>'retired')<>1
    or not exists (
      select 1 from public.feeding_plan_items item
      where item.feeding_plan_version_id=(select base_version_id from pg_temp.c0091_atomic_feeding_fixture)
        and item.round_code='evening' and item.unit_code='bale'
    )
  then raise exception 'standard plan identity was not reused'; end if;
end;
$$;

-- Invalid unit, quantity and temporary dates all roll back completely.
do $$
declare before_plans integer; before_items integer;
begin
  select count(*) into before_plans from public.feeding_plans;
  select count(*) into before_items from public.feeding_plan_items;
  begin
    perform public.save_canonical_horse_feeding_round(
      (select horse_id from pg_temp.c0091_atomic_feeding_fixture),
      'temporary',null,null,'evening',current_date,current_date-1,
      '[{"product_type":"oil","quantity":1,"unit_code":"gallon"}]'::jsonb,
      'c0911200-0000-4000-8000-000000000004'
    );
    raise exception 'invalid temporary request succeeded';
  exception when invalid_parameter_value then null; end;
  if (select count(*) from public.feeding_plans)<>before_plans
    or (select count(*) from public.feeding_plan_items)<>before_items
  then raise exception 'invalid temporary request left durable data'; end if;
end;
$$;

-- A valid temporary plan is active only in its inclusive period; the base
-- remains active and is selected again outside that period.
with saved as (
  select public.save_canonical_horse_feeding_round(
    (select horse_id from pg_temp.c0091_atomic_feeding_fixture),
    'temporary',null,null,'evening',current_date,current_date+2,
    '[{"product_type":"supplement","description":"Elektrolyten","quantity":30,"unit_code":"g"}]'::jsonb,
    'c0911200-0000-4000-8000-000000000005'
  ) value
) update pg_temp.c0091_atomic_feeding_fixture fixture
set temporary_plan_id=(saved.value->>'feeding_plan_id')::uuid from saved;

do $$
begin
  if (public.get_canonical_horse_feeding(
    (select horse_id from pg_temp.c0091_atomic_feeding_fixture)
  )->>'active_plan_id')::uuid is distinct from
    (select temporary_plan_id from pg_temp.c0091_atomic_feeding_fixture)
  then raise exception 'temporary plan did not override base in its window'; end if;
  if not exists (
    select 1 from public.feeding_plans plan
    where plan.id=(select base_plan_id from pg_temp.c0091_atomic_feeding_fixture)
      and plan.status='active'
  ) then raise exception 'temporary save changed the base plan'; end if;
end;
$$;

reset role;

-- Create another horse and plan as the other authority.
select set_config('request.jwt.claim.sub',
  (select outsider_user::text from pg_temp.c0091_atomic_feeding_fixture),true);
set local role authenticated;
with created as (
  select * from public.create_canonical_horse_profile(
    'C-009.1 Other Feeding Horse',null,null,'unknown',null,null,null,null,null,
    null,null,null,'c0911300-0000-4000-8000-000000000001'
  )
) update pg_temp.c0091_atomic_feeding_fixture fixture
set other_horse_id=created.horse_id from created;
with saved as (
  select public.save_canonical_horse_feeding_round(
    (select other_horse_id from pg_temp.c0091_atomic_feeding_fixture),
    'standard',null,null,'morning',current_date,null,
    '[{"product_type":"muesli","quantity":1,"unit_code":"scoop"}]'::jsonb,
    'c0911300-0000-4000-8000-000000000002'
  ) value
) update pg_temp.c0091_atomic_feeding_fixture fixture
set other_plan_id=(saved.value->>'feeding_plan_id')::uuid from saved;
reset role;

-- The first authority cannot write the other horse or combine its own horse
-- with the other horse's plan ID. Neither denial mutates either plan.
select set_config('request.jwt.claim.sub',
  (select authority_user::text from pg_temp.c0091_atomic_feeding_fixture),true);
set local role authenticated;
do $$
declare before_items integer;
begin
  select count(*) into before_items from public.feeding_plan_items;
  begin
    perform public.save_canonical_horse_feeding_round(
      (select other_horse_id from pg_temp.c0091_atomic_feeding_fixture),
      'standard',(select other_plan_id from pg_temp.c0091_atomic_feeding_fixture),
      2,'morning',current_date,null,
      '[{"product_type":"pellet","quantity":1,"unit_code":"kg"}]'::jsonb,
      'c0911400-0000-4000-8000-000000000001'
    );
    raise exception 'unauthorized horse write succeeded';
  exception when insufficient_privilege then null; end;
  begin
    perform public.save_canonical_horse_feeding_round(
      (select horse_id from pg_temp.c0091_atomic_feeding_fixture),
      'standard',(select other_plan_id from pg_temp.c0091_atomic_feeding_fixture),
      2,'morning',current_date,null,
      '[{"product_type":"pellet","quantity":1,"unit_code":"kg"}]'::jsonb,
      'c0911400-0000-4000-8000-000000000002'
    );
    raise exception 'cross-horse plan ID succeeded';
  exception when insufficient_privilege then null; end;
  if (select count(*) from public.feeding_plan_items)<>before_items then
    raise exception 'denied write changed Feeding data';
  end if;
end;
$$;

-- Existing loose RPCs and canonical units remain compatible.
do $$
declare created jsonb; item jsonb;
begin
  created := public.create_canonical_horse_feeding_plan(
    (select horse_id from pg_temp.c0091_atomic_feeding_fixture),
    'temporary','Losse RPC-compatibiliteit',current_date+10,current_date+11,
    'Compatibiliteit','c0911500-0000-4000-8000-000000000001'
  );
  item := public.upsert_canonical_horse_feeding_item(
    (select horse_id from pg_temp.c0091_atomic_feeding_fixture),
    (created->>'feeding_plan_version_id')::uuid,null,null,'feed',null,
    'Compatibiliteitsproduct',null,1,'piece','bucket','morning','08:00',
    null,null,'compat-piece',null,'c0911500-0000-4000-8000-000000000002'
  );
  if item->>'feeding_plan_item_id' is null then
    raise exception 'existing loose Feeding RPC stopped working';
  end if;
end;
$$;

reset role;
rollback;

\echo 'PASS: C-009.1 atomic Feeding round contract'
