\set ON_ERROR_STOP on

\if :{?avaryn_local_test}
\else
\echo 'Refusing Phase 5D.2 acceptance without avaryn_local_test.'
select 1 / 0;
\endif

\if :avaryn_local_test
\else
\echo 'Refusing Phase 5D.2 acceptance outside the local test database.'
select 1 / 0;
\endif

begin;

-- Normalize the dated local fixture inside this rolled-back acceptance
-- transaction so the two-day lifecycle remains deterministic.
update public.feeding_plans
set effective_from = current_date
where id = md5('phase5c:feeding-plan:1')::uuid;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '5c000000-0000-0000-0000-000000000001',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

create temporary table phase_5d2_ids (
  name text primary key,
  id uuid not null
) on commit drop;

do $$
declare
  version_result jsonb;
  approval_result jsonb;
  activation_result jsonb;
  standard_version_id uuid;
begin
  version_result := public.create_feeding_plan_version(
    md5('phase5c:feeding-plan:1')::uuid,
    'user',
    null,
    'Fictieve standaardversie met twee slots',
    '5d200000-0000-0000-0000-000000000001'
  );
  standard_version_id :=
    (version_result->>'feeding_plan_version_id')::uuid;
  insert into phase_5d2_ids (name, id)
  values ('standard_version', standard_version_id);

  perform public.upsert_feeding_plan_item(
    standard_version_id,
    null,
    null,
    'Fictief merk',
    'Standaard ochtendbrok',
    null,
    'user_entered',
    1.5,
    'kg',
    'bucket',
    'ochtend',
    '07:00',
    array[1, 2, 3, 4, 5, 6, 7]::smallint[],
    null,
    'phase5c-ochtend-1',
    '5cb00000-0000-0000-0000-000000000005',
    null,
    null,
    'Fictieve standaard ochtend.',
    '5d200000-0000-0000-0000-000000000002'
  );
  perform public.upsert_feeding_plan_item(
    standard_version_id,
    null,
    null,
    'Fictief merk',
    'Standaard avondbrok',
    null,
    'user_entered',
    1.75,
    'kg',
    'bucket',
    'avond',
    '19:00',
    array[1, 2, 3, 4, 5, 6, 7]::smallint[],
    null,
    'phase5c-avond-1',
    '5cb00000-0000-0000-0000-000000000005',
    null,
    null,
    'Fictieve standaard avond.',
    '5d200000-0000-0000-0000-000000000003'
  );

  approval_result := public.approve_feeding_plan_version(
    standard_version_id,
    (
      select version.row_version
      from public.feeding_plan_versions version
      where version.id = standard_version_id
    ),
    '5d200000-0000-0000-0000-000000000004'
  );
  activation_result := public.activate_feeding_plan_version(
    standard_version_id,
    (approval_result->>'row_version')::bigint,
    current_date + 1,
    '5d200000-0000-0000-0000-000000000005'
  );
  if activation_result->>'status' <> 'active' then
    raise exception 'Two-slot standard feeding setup was not activated';
  end if;
end;
$$;

do $$
declare
  first_result jsonb;
  replay_result jsonb;
begin
  first_result := public.create_feeding_plan_with_version(
    md5('phase5c:horse:a:1')::uuid,
    'temporary',
    'Fictieve 5D.2 tijdelijke override',
    current_date,
    current_date + 1,
    'Fictieve Alpha-acceptatie',
    '5d210000-0000-0000-0000-000000000001',
    '5d210000-0000-0000-0000-000000000002'
  );
  replay_result := public.create_feeding_plan_with_version(
    md5('phase5c:horse:a:1')::uuid,
    'temporary',
    'Fictieve 5D.2 tijdelijke override',
    current_date,
    current_date + 1,
    'Fictieve Alpha-acceptatie',
    '5d210000-0000-0000-0000-000000000001',
    '5d210000-0000-0000-0000-000000000002'
  );

  if (first_result->>'feeding_plan_id') is null
    or (first_result->>'feeding_plan_version_id') is null
    or (replay_result->>'feeding_plan_id')
      <> (first_result->>'feeding_plan_id')
    or (replay_result->>'feeding_plan_version_id')
      <> (first_result->>'feeding_plan_version_id')
    or (replay_result->>'idempotent')::boolean is not true
  then
    raise exception 'Atomic feeding plan replay was not idempotent';
  end if;

  insert into phase_5d2_ids (name, id)
  values
    (
      'plan',
      (first_result->>'feeding_plan_id')::uuid
    ),
    (
      'version',
      (first_result->>'feeding_plan_version_id')::uuid
    );
end;
$$;

insert into phase_5d2_ids (name, id)
select
  'item',
  (
    public.upsert_feeding_plan_item(
      (select id from phase_5d2_ids where name = 'version'),
      null,
      null,
      'Fictief merk',
      'Tijdelijke testbrok',
      null,
      'user_entered',
      1.25,
      'kg',
      'bucket',
      'ochtend',
      '07:00',
      null,
      null,
      'phase5c-ochtend-1',
      '5cb00000-0000-0000-0000-000000000006',
      null,
      null,
      'Uitsluitend fictieve Alpha-testdata.',
      '5d220000-0000-0000-0000-000000000001'
    )->>'feeding_plan_item_id'
  )::uuid;

do $$
declare
  approval jsonb;
  activation jsonb;
  replay jsonb;
begin
  approval := public.approve_feeding_plan_version(
    (select id from phase_5d2_ids where name = 'version'),
    (
      select version.row_version
      from public.feeding_plan_versions version
      where version.id = (
        select id from phase_5d2_ids where name = 'version'
      )
    ),
    '5d230000-0000-0000-0000-000000000001'
  );
  if approval->>'status' <> 'approved' then
    raise exception 'Feeding version was not approved';
  end if;

  activation := public.activate_feeding_plan_version(
    (select id from phase_5d2_ids where name = 'version'),
    (approval->>'row_version')::bigint,
    current_date + 1,
    '5d240000-0000-0000-0000-000000000001'
  );
  replay := public.activate_feeding_plan_version(
    (select id from phase_5d2_ids where name = 'version'),
    (approval->>'row_version')::bigint,
    current_date + 1,
    '5d240000-0000-0000-0000-000000000001'
  );
  if activation->>'status' <> 'active'
    or (replay->>'idempotent')::boolean is not true
  then
    raise exception 'Feeding activation replay was not idempotent';
  end if;
end;
$$;

insert into phase_5d2_ids (name, id)
select 'schedule_item', occurrence.schedule_item_id
from public.feeding_occurrences occurrence
where occurrence.feeding_plan_version_id = (
  select id from phase_5d2_ids where name = 'version'
)
  and occurrence.occurrence_local_date = current_date
limit 1;

do $$
begin
  if (
    select count(*)
    from public.feeding_occurrences occurrence
    where occurrence.feeding_plan_version_id = (
      select id from phase_5d2_ids where name = 'version'
    )
      and occurrence.occurrence_local_date
        between current_date and current_date + 1
  ) <> 2 then
    raise exception 'Temporary feeding plan did not materialize both days';
  end if;
  if exists (
    select 1
    from public.feeding_occurrences occurrence
    join public.feeding_plan_items item
      on item.id = occurrence.feeding_plan_item_id
    where occurrence.feeding_plan_version_id = (
      select id from phase_5d2_ids where name = 'version'
    )
      and item.override_key <> 'phase5c-ochtend-1'
  ) then
    raise exception 'Temporary plan replaced a non-matching override slot';
  end if;
  if (
    select count(*)
    from public.feeding_occurrences occurrence
    join public.schedule_items schedule_item
      on schedule_item.id = occurrence.schedule_item_id
    where occurrence.feeding_plan_version_id = (
      select id from phase_5d2_ids where name = 'standard_version'
    )
      and occurrence.override_key = 'phase5c-ochtend-1'
      and occurrence.occurrence_local_date
        between current_date and current_date + 1
      and schedule_item.state = 'cancelled'
      and schedule_item.state_reason = 'temporary_feeding_override'
  ) <> 2 then
    raise exception 'Matching standard slots were not replaced exactly';
  end if;
  if (
    select count(*)
    from public.feeding_occurrences occurrence
    join public.schedule_items schedule_item
      on schedule_item.id = occurrence.schedule_item_id
    where occurrence.feeding_plan_version_id = (
      select id from phase_5d2_ids where name = 'standard_version'
    )
      and occurrence.override_key = 'phase5c-avond-1'
      and occurrence.occurrence_local_date
        between current_date and current_date + 1
      and schedule_item.state = 'planned'
  ) <> 2 then
    raise exception 'Non-matching standard slots were not preserved';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '5c000000-0000-0000-0000-000000000006',
  true
);

do $$
declare
  first_execution jsonb;
  correction jsonb;
  replay jsonb;
  correction_completed_at timestamptz := clock_timestamp();
  correction_local_at timestamp := localtimestamp;
begin
  if (
    select count(*)
    from public.list_today_schedule(
      '5ca00000-0000-0000-0000-000000000001',
      current_date
    )
    where item_kind = 'feeding'
      and access_scope = 'assigned'
  ) <> 1 then
    raise exception
      'Assigned groom saw more or fewer than one total feeding task';
  end if;
  if (
    select count(*)
    from public.list_today_schedule(
      '5ca00000-0000-0000-0000-000000000001',
      current_date
    )
    where schedule_item_id = (
      select id from phase_5d2_ids where name = 'schedule_item'
    )
      and access_scope = 'assigned'
  ) <> 1 then
    raise exception 'Assigned groom did not receive the exact feeding task';
  end if;

  first_execution := public.record_feeding_execution(
    (select id from phase_5d2_ids where name = 'schedule_item'),
    null,
    '5d250000-0000-0000-0000-000000000001',
    'completed',
    null,
    clock_timestamp(),
    localtimestamp,
    'Europe/Amsterdam',
    'online',
    null,
    null,
    1.10,
    'kg',
    0.15,
    'less',
    'Fictieve eerste registratie.',
    null
  );
  insert into phase_5d2_ids (name, id)
  values ('execution', (first_execution->>'execution_id')::uuid);

  correction := public.record_feeding_execution(
    (select id from phase_5d2_ids where name = 'schedule_item'),
    (select id from phase_5d2_ids where name = 'execution'),
    '5d250000-0000-0000-0000-000000000002',
    'completed',
    null,
    correction_completed_at,
    correction_local_at,
    'Europe/Amsterdam',
    'online',
    null,
    'Append-only correctie',
    1.25,
    'kg',
    0,
    'none',
    'Fictieve correctie.',
    null
  );
  replay := public.record_feeding_execution(
    (select id from phase_5d2_ids where name = 'schedule_item'),
    (select id from phase_5d2_ids where name = 'execution'),
    '5d250000-0000-0000-0000-000000000002',
    'completed',
    null,
    correction_completed_at,
    correction_local_at,
    'Europe/Amsterdam',
    'online',
    null,
    'Append-only correctie',
    1.25,
    'kg',
    0,
    'none',
    'Fictieve correctie.',
    null
  );

  if (correction->>'execution_id') is null
    or (replay->>'execution_id') <> (correction->>'execution_id')
    or (replay->>'idempotent')::boolean is not true
  then
    raise exception 'Feeding correction replay was not idempotent';
  end if;
end;
$$;

do $$
begin
  if (
    select count(*)
    from public.schedule_executions execution
    where execution.schedule_item_id = (
      select id from phase_5d2_ids where name = 'schedule_item'
    )
  ) <> 2 then
    raise exception 'Feeding correction did not remain append-only';
  end if;
  if (
    select count(*)
    from public.schedule_executions execution
    where execution.schedule_item_id = (
      select id from phase_5d2_ids where name = 'schedule_item'
    )
      and execution.corrects_execution_id = (
        select id from phase_5d2_ids where name = 'execution'
      )
  ) <> 1 then
    raise exception 'Correction does not point to the original execution';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '5c000000-0000-0000-0000-000000000011',
  true
);

do $$
begin
  if exists (
    select 1
    from public.feeding_plans
    where id = (select id from phase_5d2_ids where name = 'plan')
  ) then
    raise exception 'Cross-stable owner read feeding plan from stable A';
  end if;
  begin
    perform public.create_feeding_plan_with_version(
      md5('phase5c:horse:a:1')::uuid,
      'standard',
      'Cross-stable denied',
      current_date,
      null,
      'Must fail',
      '5d260000-0000-0000-0000-000000000001',
      '5d260000-0000-0000-0000-000000000002'
    );
    raise exception 'Cross-stable owner created a feeding plan in stable A';
  exception
    when insufficient_privilege then
      if sqlerrm not in ('NUTRITION_UNAVAILABLE', 'NOT_AUTHORIZED') then
        raise;
      end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '5c000000-0000-0000-0000-000000000009',
  true
);

do $$
begin
  if exists (
    select 1
    from public.feeding_plans
    where id = (select id from phase_5d2_ids where name = 'plan')
  ) then
    raise exception 'Revoked user retained feeding-plan visibility';
  end if;
  begin
    perform public.record_feeding_execution(
      (select id from phase_5d2_ids where name = 'schedule_item'),
      null,
      '5d270000-0000-0000-0000-000000000001',
      'completed',
      null,
      clock_timestamp(),
      localtimestamp,
      'Europe/Amsterdam',
      'online',
      null,
      null,
      1.25,
      'kg',
      0,
      'none',
      null,
      null
    );
    raise exception 'Revoked user mutated a feeding execution';
  exception
    when insufficient_privilege then
      if sqlerrm not in (
        'MEMBERSHIP_UNAVAILABLE',
        'NUTRITION_UNAVAILABLE',
        'NOT_AUTHORIZED'
      ) then
        raise;
      end if;
  end;
end;
$$;

rollback;

\echo 'PASS: Phase 5D.2 feeding Alpha acceptance'
