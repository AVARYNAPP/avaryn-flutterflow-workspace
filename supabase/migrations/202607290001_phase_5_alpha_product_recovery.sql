-- AVARYN Phase 5: bounded Alpha product recovery.
--
-- This migration deliberately reuses the Phase 4C.3/4C.4 mutation contracts.
-- It adds one feeding classification, an RLS-aware calendar/history read
-- model, and atomic client wrappers. Existing records and audit history are
-- never deleted or rewritten.

alter table public.feeding_plan_items
  add column if not exists item_category text
  not null default 'feed';

alter table private.feeding_mutation_receipts
  drop constraint if exists feeding_mutation_receipts_operation_name_check;

alter table private.feeding_mutation_receipts
  add constraint feeding_mutation_receipts_operation_name_check
  check (
    operation_name in (
      'create_feeding_plan',
      'create_feeding_plan_version',
      'upsert_feeding_plan_item',
      'upsert_feeding_plan_item_v2',
      'approve_feeding_plan_version',
      'activate_feeding_plan_version',
      'retire_feeding_plan',
      'record_feeding_execution'
    )
  );

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint
    where conname = 'feeding_plan_items_item_category_check'
      and conrelid = 'public.feeding_plan_items'::regclass
  ) then
    alter table public.feeding_plan_items
      add constraint feeding_plan_items_item_category_check
      check (
        item_category in (
          'feed', 'supplement', 'hay', 'water', 'medication'
        )
      );
  end if;
end;
$$;

create or replace function public.upsert_feeding_plan_item_v2(
  p_feeding_plan_version_id uuid,
  p_feeding_plan_item_id uuid,
  p_expected_row_version bigint,
  p_item_category text,
  p_product_brand text,
  p_product_name text,
  p_product_variant text,
  p_source_status text,
  p_planned_quantity numeric,
  p_unit_code text,
  p_offering_method text,
  p_round_code text,
  p_local_time time,
  p_weekdays smallint[],
  p_interval_days integer,
  p_override_key text,
  p_default_stable_member_id uuid,
  p_batch_lot text,
  p_expires_on date,
  p_instruction text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  actor_membership public.stable_memberships%rowtype;
  target_stable_id uuid;
  target_horse_id uuid;
  target_feeding_plan_id uuid;
  base_result jsonb;
  target_item_id uuid;
  final_row_version bigint;
  normalized_category text := btrim(coalesce(p_item_category, ''));
  normalized_weekdays smallint[];
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
  base_request_id uuid;
begin
  if actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if normalized_category not in (
    'feed', 'supplement', 'hay', 'water', 'medication'
  ) then
    raise exception using
      errcode = '22023',
      message = 'INVALID_FEEDING_ITEM_CATEGORY';
  end if;

  if p_weekdays is not null then
    select array_agg(day_value order by day_value)::smallint[]
      into normalized_weekdays
    from (
      select distinct unnest(p_weekdays) as day_value
    ) normalized_days;
  end if;

  select version.stable_id, plan.horse_id, plan.id
    into target_stable_id, target_horse_id, target_feeding_plan_id
  from public.feeding_plan_versions version
  join public.feeding_plans plan on plan.id = version.feeding_plan_id
  where version.id = p_feeding_plan_version_id;
  if target_stable_id is null then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;

  actor_membership := private.lock_feeding_context(
    target_stable_id,
    target_horse_id
  );
  if not private.feeding_membership_can_edit(
    actor_membership,
    target_horse_id
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'feeding_plan_version_id', p_feeding_plan_version_id,
      'feeding_plan_item_id', p_feeding_plan_item_id,
      'expected_row_version', p_expected_row_version,
      'item_category', normalized_category,
      'product_brand', nullif(btrim(p_product_brand), ''),
      'product_name', btrim(coalesce(p_product_name, '')),
      'product_variant', nullif(btrim(p_product_variant), ''),
      'source_status', p_source_status,
      'planned_quantity', p_planned_quantity,
      'unit_code', p_unit_code,
      'offering_method', p_offering_method,
      'round_code', btrim(coalesce(p_round_code, '')),
      'local_time', p_local_time,
      'weekdays', normalized_weekdays,
      'interval_days', p_interval_days,
      'override_key', nullif(btrim(p_override_key), ''),
      'default_stable_member_id', p_default_stable_member_id,
      'batch_lot', nullif(btrim(p_batch_lot), ''),
      'expires_on', p_expires_on,
      'instruction', nullif(btrim(p_instruction), '')
    )
  );
  receipt_result := private.feeding_receipt_result(
    actor_id,
    p_request_id,
    'upsert_feeding_plan_item_v2',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  base_request_id := private.schedule_derived_request_id(
    p_request_id,
    'feeding-plan-item-v2-base'
  );
  base_result := public.upsert_feeding_plan_item(
    p_feeding_plan_version_id,
    p_feeding_plan_item_id,
    p_expected_row_version,
    p_product_brand,
    p_product_name,
    p_product_variant,
    p_source_status,
    p_planned_quantity,
    p_unit_code,
    p_offering_method,
    p_round_code,
    p_local_time,
    p_weekdays,
    p_interval_days,
    p_override_key,
    p_default_stable_member_id,
    p_batch_lot,
    p_expires_on,
    p_instruction,
    base_request_id
  );

  target_item_id := (base_result ->> 'feeding_plan_item_id')::uuid;
  update public.feeding_plan_items item
  set
    item_category = normalized_category,
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where item.id = target_item_id
    and item.item_category is distinct from normalized_category;

  select item.row_version
    into strict final_row_version
  from public.feeding_plan_items item
  where item.id = target_item_id;

  perform private.write_feeding_change_event(
    target_stable_id,
    target_horse_id,
    target_feeding_plan_id,
    p_feeding_plan_version_id,
    target_item_id,
    null,
    null,
    actor_membership.id,
    p_request_id,
    'feeding_plan_item_upserted',
    final_row_version,
    'item_category=' || normalized_category
  );

  safe_result := base_result || jsonb_build_object(
    'item_category', normalized_category,
    'row_version', final_row_version,
    'idempotent', false
  );
  insert into private.feeding_mutation_receipts (
    actor_user_id,
    request_id,
    stable_id,
    operation_name,
    target_type,
    target_id,
    payload_hash,
    result
  )
  values (
    actor_id,
    p_request_id,
    target_stable_id,
    'upsert_feeding_plan_item_v2',
    'feeding_plan_item',
    target_item_id,
    payload_hash,
    safe_result
  );

  return safe_result;
end;
$$;

create or replace function public.create_schedule_task_with_assignment_v2(
  p_stable_id uuid,
  p_horse_id uuid,
  p_item_kind text,
  p_title text,
  p_instruction text,
  p_location text,
  p_priority text,
  p_scheduled_start_at timestamptz,
  p_scheduled_end_at timestamptz,
  p_source_timezone text,
  p_source_local_date date,
  p_source_local_time time,
  p_create_request_id uuid,
  p_stable_member_id uuid,
  p_assignment_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  item_result jsonb;
  assignment_result jsonb;
  schedule_item_id uuid;
  normalized_location text := nullif(btrim(p_location), '');
  normalized_instruction text := nullif(btrim(p_instruction), '');
  stored_instruction text;
begin
  if p_item_kind not in ('task', 'training', 'care', 'other')
    or (normalized_location is not null and length(normalized_location) > 200)
  then
    raise exception using errcode = '22023', message = 'INVALID_SCHEDULE_INPUT';
  end if;
  if (p_stable_member_id is null) <> (p_assignment_request_id is null) then
    raise exception using
      errcode = '22023',
      message = 'INVALID_OPTIONAL_ASSIGNMENT';
  end if;

  stored_instruction := concat_ws(
    E'\n',
    case
      when normalized_location is null then null
      else 'Locatie: ' || normalized_location
    end,
    normalized_instruction
  );
  if stored_instruction = '' then stored_instruction := 'Geen instructie.'; end if;

  item_result := public.create_schedule_item(
    p_stable_id,
    p_horse_id,
    p_item_kind,
    'horse.schedule',
    p_title,
    stored_instruction,
    p_priority,
    p_scheduled_start_at,
    p_scheduled_end_at,
    p_source_timezone,
    p_source_local_date,
    p_source_local_time,
    p_create_request_id
  );
  schedule_item_id := (item_result ->> 'schedule_item_id')::uuid;

  if p_stable_member_id is not null then
    assignment_result := public.assign_schedule_item(
      schedule_item_id,
      p_stable_member_id,
      'responsible',
      p_assignment_request_id
    );
  end if;

  return item_result || jsonb_build_object(
    'item_kind', p_item_kind,
    'location', normalized_location,
    'assignment_id', assignment_result ->> 'assignment_id',
    'assignment_status', assignment_result ->> 'status',
    'assignment_idempotent', assignment_result -> 'idempotent'
  );
end;
$$;

create or replace function public.create_schedule_series_with_occurrences_v2(
  p_stable_id uuid,
  p_horse_id uuid,
  p_series_kind text,
  p_title text,
  p_instruction text,
  p_location text,
  p_timezone text,
  p_frequency text,
  p_interval_value integer,
  p_weekdays smallint[],
  p_local_start_time time,
  p_duration_minutes integer,
  p_starts_on date,
  p_ends_on date,
  p_generation_horizon_days integer,
  p_status text,
  p_through_local_date date,
  p_stable_member_id uuid,
  p_create_request_id uuid,
  p_materialize_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  series_result jsonb;
  materialize_result jsonb;
  assignment_result jsonb;
  schedule_series_id uuid;
  target_item record;
  assignment_count integer := 0;
  normalized_location text := nullif(btrim(p_location), '');
  normalized_instruction text := nullif(btrim(p_instruction), '');
  stored_instruction text;
begin
  if p_series_kind not in ('task', 'training', 'care', 'other')
    or (normalized_location is not null and length(normalized_location) > 200)
  then
    raise exception using errcode = '22023', message = 'INVALID_SCHEDULE_INPUT';
  end if;

  stored_instruction := concat_ws(
    E'\n',
    case
      when normalized_location is null then null
      else 'Locatie: ' || normalized_location
    end,
    normalized_instruction
  );
  if stored_instruction = '' then stored_instruction := 'Geen instructie.'; end if;

  series_result := public.create_schedule_series(
    p_stable_id,
    p_horse_id,
    p_series_kind,
    'horse.schedule',
    p_title,
    stored_instruction,
    p_timezone,
    p_frequency,
    p_interval_value,
    p_weekdays,
    p_local_start_time,
    p_duration_minutes,
    p_starts_on,
    p_ends_on,
    p_generation_horizon_days,
    p_status,
    p_create_request_id
  );
  schedule_series_id := (series_result ->> 'series_id')::uuid;

  materialize_result := public.materialize_schedule_occurrences(
    schedule_series_id,
    p_through_local_date,
    p_materialize_request_id
  );

  if p_stable_member_id is not null then
    for target_item in
      select item.id
      from public.schedule_items item
      where item.series_id = schedule_series_id
        and item.source_local_date between p_starts_on and p_through_local_date
        and item.state = 'planned'
      order by item.source_local_date, item.id
    loop
      assignment_result := public.assign_schedule_item(
        target_item.id,
        p_stable_member_id,
        'responsible',
        private.schedule_derived_request_id(
          p_create_request_id,
          'series-assignment:' || target_item.id::text
        )
      );
      assignment_count := assignment_count + 1;
    end loop;
  end if;

  return series_result || jsonb_build_object(
    'series_kind', p_series_kind,
    'location', normalized_location,
    'materialized_from_local_date',
      materialize_result ->> 'from_local_date',
    'materialized_through_local_date',
      materialize_result ->> 'through_local_date',
    'materialized_created_count',
      materialize_result -> 'created_count',
    'materialization_idempotent',
      materialize_result -> 'idempotent',
    'assigned_occurrence_count', assignment_count
  );
end;
$$;

create or replace function public.update_schedule_series_scope_materialized(
  p_series_id uuid,
  p_expected_row_version bigint,
  p_scope text,
  p_occurrence_item_id uuid,
  p_effective_local_date date,
  p_request_id uuid,
  p_title text,
  p_instruction text,
  p_timezone text,
  p_frequency text,
  p_interval_value integer,
  p_weekdays smallint[],
  p_local_start_time time,
  p_duration_minutes integer,
  p_ends_on date,
  p_generation_horizon_days integer,
  p_status text,
  p_through_local_date date,
  p_materialize_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  update_result jsonb;
  materialize_result jsonb;
  target_series_id uuid;
begin
  update_result := public.update_schedule_series_scope(
    p_series_id,
    p_expected_row_version,
    p_scope,
    p_occurrence_item_id,
    p_effective_local_date,
    p_request_id,
    p_title,
    p_instruction,
    p_timezone,
    p_frequency,
    p_interval_value,
    p_weekdays,
    p_local_start_time,
    p_duration_minutes,
    p_ends_on,
    p_generation_horizon_days,
    p_status
  );

  target_series_id := case
    when p_scope = 'future'
      then (update_result ->> 'replacement_series_id')::uuid
    else null
  end;
  if target_series_id is not null then
    materialize_result := public.materialize_schedule_occurrences(
      target_series_id,
      p_through_local_date,
      p_materialize_request_id
    );
  end if;

  return update_result || jsonb_build_object(
    'materialized_created_count',
      materialize_result -> 'created_count',
    'materialization_idempotent',
      materialize_result -> 'idempotent'
  );
end;
$$;

create or replace function public.list_schedule_calendar(
  p_stable_id uuid,
  p_from_local_date date,
  p_through_local_date date
)
returns table (
  schedule_item_id uuid,
  stable_id uuid,
  horse_id uuid,
  horse_name text,
  series_id uuid,
  item_kind text,
  data_category text,
  title text,
  instruction text,
  priority text,
  scheduled_start_at timestamptz,
  scheduled_end_at timestamptz,
  source_timezone text,
  source_local_date date,
  source_local_time time,
  occurrence_local_date date,
  state text,
  row_version bigint,
  assignment_role text,
  assignment_status text,
  responsible_stable_member_id uuid,
  responsible_name text,
  access_scope text,
  is_overdue boolean,
  series_row_version bigint,
  series_frequency text,
  series_interval_value integer,
  series_weekdays smallint[],
  series_local_start_time time,
  series_duration_minutes integer,
  series_ends_on date,
  series_status text,
  feeding_plan_item_id uuid,
  feeding_item_category text,
  planned_quantity numeric,
  planned_unit_code text,
  product_name text,
  offering_method text,
  round_code text,
  actual_quantity numeric,
  actual_unit_code text,
  remaining_quantity numeric,
  deviation_code text,
  observation text,
  execution_note text,
  execution_actor_user_id uuid,
  actual_completed_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with actor_membership as (
    select membership.stable_member_id
    from public.stable_memberships membership
    join public.stables stable on stable.id = membership.stable_id
    where membership.stable_id = p_stable_id
      and membership.user_id = auth.uid()
      and membership.status = 'active'
      and stable.status = 'active'
  ),
  accessible_items as (
    select
      item.*,
      private.schedule_item_access_level(item.id) as access_level
    from public.schedule_items item
    where item.stable_id = p_stable_id
      and item.source_local_date between p_from_local_date and p_through_local_date
      and p_through_local_date >= p_from_local_date
      and p_through_local_date <= p_from_local_date + 366
  )
  select
    item.id,
    item.stable_id,
    item.horse_id,
    horse.display_name,
    case when item.access_level = 'full' then item.series_id else null end,
    item.item_kind,
    item.data_category,
    item.title,
    item.instruction,
    item.priority,
    item.scheduled_start_at,
    item.scheduled_end_at,
    item.source_timezone,
    item.source_local_date,
    item.source_local_time,
    item.occurrence_local_date,
    item.state,
    item.row_version,
    own_assignment.assignment_role,
    own_assignment.status,
    responsible_assignment.stable_member_id,
    responsible_member.display_name,
    item.access_level,
    item.state in ('planned', 'in_progress')
      and item.scheduled_start_at < pg_catalog.now(),
    case when item.access_level = 'full' then series.row_version else null end,
    case when item.access_level = 'full' then series.frequency else null end,
    case when item.access_level = 'full' then series.interval_value else null end,
    case when item.access_level = 'full' then series.weekdays else null end,
    case when item.access_level = 'full' then series.local_start_time else null end,
    case when item.access_level = 'full' then series.duration_minutes else null end,
    case when item.access_level = 'full' then series.ends_on else null end,
    case when item.access_level = 'full' then series.status else null end,
    occurrence.feeding_plan_item_id,
    plan_item.item_category,
    occurrence.planned_quantity,
    occurrence.unit_code,
    plan_item.product_name,
    occurrence.offering_method,
    plan_item.round_code,
    execution_detail.actual_quantity,
    execution_detail.unit_code,
    execution_detail.remaining_quantity,
    execution_detail.deviation_code,
    execution_detail.observation,
    latest_execution.note,
    latest_execution.actor_user_id,
    latest_execution.actual_completed_at
  from accessible_items item
  cross join actor_membership
  left join public.horses horse on horse.id = item.horse_id
  left join public.schedule_series series on series.id = item.series_id
  left join lateral (
    select assignment.assignment_role, assignment.status
    from public.schedule_assignments assignment
    where assignment.schedule_item_id = item.id
      and assignment.stable_member_id = actor_membership.stable_member_id
      and assignment.status in ('assigned', 'accepted', 'completed')
    order by assignment.created_at desc, assignment.id
    limit 1
  ) own_assignment on true
  left join lateral (
    select assignment.stable_member_id
    from public.schedule_assignments assignment
    where assignment.schedule_item_id = item.id
      and assignment.assignment_role = 'responsible'
      and assignment.status in ('assigned', 'accepted', 'completed')
    order by assignment.created_at desc, assignment.id
    limit 1
  ) responsible_assignment on true
  left join public.stable_members responsible_member
    on responsible_member.id = responsible_assignment.stable_member_id
  left join public.feeding_occurrences occurrence
    on occurrence.schedule_item_id = item.id
  left join public.feeding_plan_items plan_item
    on plan_item.id = occurrence.feeding_plan_item_id
  left join lateral (
    select execution.*
    from public.schedule_executions execution
    where execution.schedule_item_id = item.id
    order by execution.created_at desc, execution.id desc
    limit 1
  ) latest_execution on true
  left join public.feeding_execution_details execution_detail
    on execution_detail.execution_id = latest_execution.id
  where item.access_level in ('full', 'assigned')
  order by item.scheduled_start_at, item.id
$$;

revoke execute on function public.upsert_feeding_plan_item_v2(
  uuid, uuid, bigint, text, text, text, text, text, numeric, text, text, text,
  time, smallint[], integer, text, uuid, text, date, text, uuid
) from public, anon;
revoke execute on function public.create_schedule_task_with_assignment_v2(
  uuid, uuid, text, text, text, text, text, timestamptz, timestamptz, text,
  date, time, uuid, uuid, uuid
) from public, anon;
revoke execute on function public.create_schedule_series_with_occurrences_v2(
  uuid, uuid, text, text, text, text, text, text, integer, smallint[], time,
  integer, date, date, integer, text, date, uuid, uuid, uuid
) from public, anon;
revoke execute on function public.update_schedule_series_scope_materialized(
  uuid, bigint, text, uuid, date, uuid, text, text, text, text, integer,
  smallint[], time, integer, date, integer, text, date, uuid
) from public, anon;
revoke execute on function public.list_schedule_calendar(uuid, date, date)
  from public, anon;

grant execute on function public.upsert_feeding_plan_item_v2(
  uuid, uuid, bigint, text, text, text, text, text, numeric, text, text, text,
  time, smallint[], integer, text, uuid, text, date, text, uuid
) to authenticated;
grant execute on function public.create_schedule_task_with_assignment_v2(
  uuid, uuid, text, text, text, text, text, timestamptz, timestamptz, text,
  date, time, uuid, uuid, uuid
) to authenticated;
grant execute on function public.create_schedule_series_with_occurrences_v2(
  uuid, uuid, text, text, text, text, text, text, integer, smallint[], time,
  integer, date, date, integer, text, date, uuid, uuid, uuid
) to authenticated;
grant execute on function public.update_schedule_series_scope_materialized(
  uuid, bigint, text, uuid, date, uuid, text, text, text, text, integer,
  smallint[], time, integer, date, integer, text, date, uuid
) to authenticated;
grant execute on function public.list_schedule_calendar(uuid, date, date)
  to authenticated;

comment on function public.list_schedule_calendar(uuid, date, date) is
  'RLS-aware day/week/month planning projection with feeding plan and latest execution details.';
