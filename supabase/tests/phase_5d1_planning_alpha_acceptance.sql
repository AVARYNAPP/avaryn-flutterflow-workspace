\set ON_ERROR_STOP on

\if :{?avaryn_local_test}
\else
\echo 'Refusing Phase 5D.1 acceptance without avaryn_local_test.'
select 1 / 0;
\endif

\if :avaryn_local_test
\else
\echo 'Refusing Phase 5D.1 acceptance outside the local test database.'
select 1 / 0;
\endif

begin;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '5c000000-0000-0000-0000-000000000001',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

create temporary table phase_5d1_ids (
  name text primary key,
  id uuid not null
) on commit drop;

insert into phase_5d1_ids (name, id)
select
  'daily_one',
  (
    public.create_schedule_series_with_occurrences(
      '5ca00000-0000-0000-0000-000000000001',
      md5('phase5c:horse:a:1')::uuid,
      'Alpha routine ochtend',
      'Fictieve acceptatieroutine.',
      'Europe/Amsterdam',
      'daily',
      1,
      null,
      '08:00',
      30,
      '2026-08-03',
      null,
      30,
      'active',
      '2026-08-15',
      '5d110000-0000-0000-0000-000000000001',
      '5d120000-0000-0000-0000-000000000001'
    )->>'series_id'
  )::uuid
union all
select
  'daily_two',
  (
    public.create_schedule_series_with_occurrences(
      '5ca00000-0000-0000-0000-000000000001',
      md5('phase5c:horse:a:1')::uuid,
      'Alpha routine middag',
      'Fictieve acceptatieroutine.',
      'Europe/Amsterdam',
      'daily',
      1,
      null,
      '13:00',
      20,
      '2026-08-03',
      null,
      30,
      'active',
      '2026-08-15',
      '5d110000-0000-0000-0000-000000000002',
      '5d120000-0000-0000-0000-000000000002'
    )->>'series_id'
  )::uuid
union all
select
  'weekly_one',
  (
    public.create_schedule_series_with_occurrences(
      '5ca00000-0000-0000-0000-000000000001',
      md5('phase5c:horse:a:1')::uuid,
      'Alpha routine week',
      'Fictieve wekelijkse acceptatieroutine.',
      'Europe/Amsterdam',
      'weekly',
      1,
      array[1]::smallint[],
      '16:00',
      45,
      '2026-08-03',
      null,
      30,
      'active',
      '2026-08-15',
      '5d110000-0000-0000-0000-000000000003',
      '5d120000-0000-0000-0000-000000000003'
    )->>'series_id'
  )::uuid;

insert into phase_5d1_ids (name, id)
select
  'assigned_item',
  (
    public.create_schedule_task_with_assignment(
      '5ca00000-0000-0000-0000-000000000001',
      md5('phase5c:horse:a:1')::uuid,
      'Alpha toegewezen taak',
      'Fictieve taak voor toewijzing en uitvoering.',
      'normal',
      '2026-08-03 09:00:00+00',
      '2026-08-03 09:30:00+00',
      'Europe/Amsterdam',
      '2026-08-03',
      '11:00',
      '5d130000-0000-0000-0000-000000000001',
      '5cb00000-0000-0000-0000-000000000004',
      '5d140000-0000-0000-0000-000000000001'
    )->>'schedule_item_id'
  )::uuid;

do $$
declare
  replay jsonb;
begin
  if (
    select count(*)
    from public.schedule_series
    where id in (select id from phase_5d1_ids where name <> 'assigned_item')
  ) <> 3 then
    raise exception 'Tester did not create exactly three routines';
  end if;
  if (
    select count(*)
    from public.schedule_items
    where series_id = (
      select id from phase_5d1_ids where name = 'daily_one'
    )
      and source_local_date between '2026-08-03' and '2026-08-15'
  ) <> 13 then
    raise exception 'Daily routine did not materialize exactly 13 days';
  end if;
  if (
    select max(source_local_date)
    from public.schedule_items
    where series_id = (
      select id from phase_5d1_ids where name = 'daily_one'
    )
  ) <> '2026-08-15'::date then
    raise exception 'Daily routine materialization horizon is off by one';
  end if;
  if (
    select count(*)
    from public.list_today_schedule(
      '5ca00000-0000-0000-0000-000000000001',
      '2026-08-03'
    )
    where schedule_item_id in (
      select item.id
      from public.schedule_items item
      where item.series_id in (
        select id from phase_5d1_ids where name <> 'assigned_item'
      )
    )
  ) < 3 then
    raise exception 'Owner Today view is missing created routines';
  end if;

  replay := public.create_schedule_series_with_occurrences(
    '5ca00000-0000-0000-0000-000000000001',
    md5('phase5c:horse:a:1')::uuid,
    'Alpha routine ochtend',
    'Fictieve acceptatieroutine.',
    'Europe/Amsterdam',
    'daily',
    1,
    null,
    '08:00',
    30,
    '2026-08-03',
    null,
    30,
    'active',
    '2026-08-15',
    '5d110000-0000-0000-0000-000000000001',
    '5d120000-0000-0000-0000-000000000001'
  );
  if (replay ->> 'series_id')::uuid <> (
    select id from phase_5d1_ids where name = 'daily_one'
  ) or (replay ->> 'idempotent')::boolean is not true
    or (replay ->> 'materialization_idempotent')::boolean is not true
  then
    raise exception 'Atomic routine same-request replay was not idempotent';
  end if;

  replay := public.create_schedule_task_with_assignment(
    '5ca00000-0000-0000-0000-000000000001',
    md5('phase5c:horse:a:1')::uuid,
    'Alpha toegewezen taak',
    'Fictieve taak voor toewijzing en uitvoering.',
    'normal',
    '2026-08-03 09:00:00+00',
    '2026-08-03 09:30:00+00',
    'Europe/Amsterdam',
    '2026-08-03',
    '11:00',
    '5d130000-0000-0000-0000-000000000001',
    '5cb00000-0000-0000-0000-000000000004',
    '5d140000-0000-0000-0000-000000000001'
  );
  if (replay ->> 'schedule_item_id')::uuid <> (
    select id from phase_5d1_ids where name = 'assigned_item'
  ) or (replay ->> 'idempotent')::boolean is not true
    or (replay ->> 'assignment_idempotent')::boolean is not true
  then
    raise exception 'Atomic task same-request replay was not idempotent';
  end if;
end;
$$;

-- Canonical execution authority is explicit and independent from the stable
-- assignment. The rider receives edit (execution) without view, proving that
-- assignment alone does not open schedule metadata.
reset role;
insert into public.horse_profile_permission_grants (
  horse_id,
  grantee_profile_id,
  permission_id,
  grantor_profile_id,
  reason_code,
  creation_correlation_id
)
select
  item.horse_id,
  grantee.id,
  permission.id,
  grantor.id,
  'MANUAL_GRANT',
  '5d140000-0000-0000-0000-000000000011'::uuid
from public.schedule_items item
join public.profiles grantee
  on grantee.auth_user_id = '5c000000-0000-0000-0000-000000000004'::uuid
join public.profiles grantor
  on grantor.auth_user_id = '5c000000-0000-0000-0000-000000000001'::uuid
join public.permission_definitions permission
  on permission.code = 'horse.edit'
where item.id = (select id from phase_5d1_ids where name = 'assigned_item');
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config(
  'request.jwt.claim.sub',
  '5c000000-0000-0000-0000-000000000004',
  true
);

do $$
begin
  if (
    select count(*)
    from public.list_today_schedule(
      '5ca00000-0000-0000-0000-000000000001',
      '2026-08-03'
    )
  ) <> 0 then
    raise exception 'Assignment or execute-only grant leaked schedule metadata';
  end if;
  if (
    select count(*)
    from public.list_today_schedule(
      '5ca00000-0000-0000-0000-000000000001',
      '2026-08-03'
    )
    where schedule_item_id = (
      select id from phase_5d1_ids where name = 'assigned_item'
    )
      and assignment_role = 'responsible'
      and access_scope = 'assigned'
  ) <> 0 then
    raise exception 'Assignment opened an implicit schedule read';
  end if;
  if (
    select count(*)
    from public.get_schedule_item(
      (
        select item.id
        from public.schedule_items item
        where item.series_id = (
          select id from phase_5d1_ids where name = 'daily_one'
        )
        order by item.source_local_date
        limit 1
      )
    )
  ) <> 0 then
    raise exception 'Assigned rider directly accessed an unassigned task';
  end if;
end;
$$;

insert into phase_5d1_ids (name, id)
select
  'execution',
  (
    public.record_schedule_execution(
      (select id from phase_5d1_ids where name = 'assigned_item'),
      '5d150000-0000-0000-0000-000000000001',
      'completed',
      '2026-08-03 09:02:00+00',
      '2026-08-03 09:22:00+00',
      '2026-08-03 11:22:00',
      'Europe/Amsterdam',
      'online',
      null,
      'Fictieve Alpha-uitvoering.'
    )->>'execution_id'
  )::uuid;

do $$
begin
  if (
    select count(*)
    from phase_5d1_ids
    where name = 'execution' and id is not null
  ) <> 1 then
    raise exception 'Explicit execute-only rider execution was not registered';
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
  if (
    select count(*)
    from public.list_today_schedule(
      '5ca00000-0000-0000-0000-000000000001',
      '2026-08-03'
    )
  ) <> 0 then
    raise exception 'Cross-stable Today isolation failed';
  end if;
  if (
    select count(*)
    from public.get_schedule_item(
      (select id from phase_5d1_ids where name = 'assigned_item')
    )
  ) <> 0 then
    raise exception 'Cross-stable direct task access succeeded';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '5c000000-0000-0000-0000-000000000009',
  true
);

do $$
declare
  mutation_denied boolean := false;
begin
  if (
    select count(*)
    from public.list_today_schedule(
      '5ca00000-0000-0000-0000-000000000001',
      '2026-08-03'
    )
  ) <> 0 then
    raise exception 'Revoked user retained Today access';
  end if;
  if (
    select count(*)
    from public.get_schedule_item(
      (select id from phase_5d1_ids where name = 'assigned_item')
    )
  ) <> 0 then
    raise exception 'Revoked user retained direct task access';
  end if;
  begin
    perform public.create_schedule_task_with_assignment(
      '5ca00000-0000-0000-0000-000000000001',
      md5('phase5c:horse:a:1')::uuid,
      'Verboden ingetrokken taak',
      'Deze fictieve mutatie moet worden geweigerd.',
      'normal',
      '2026-08-03 10:00:00+00',
      '2026-08-03 10:30:00+00',
      'Europe/Amsterdam',
      '2026-08-03',
      '12:00',
      '5d160000-0000-0000-0000-000000000001',
      null,
      null
    );
  exception when insufficient_privilege then
    if SQLERRM not in (
      'SCHEDULE_UNAVAILABLE',
      'NOT_AUTHORIZED',
      'STABLE_MEMBER_UNAVAILABLE'
    ) then
      raise;
    end if;
    mutation_denied := true;
  end;
  if not mutation_denied then
    raise exception 'Revoked user retained direct task mutation access';
  end if;
end;
$$;

rollback;

\echo 'PASS: Phase 5D.1 planning Alpha acceptance is green.'
