-- AVARYN Phase 5D.1: atomic client-facing Planning workflows.
--
-- The underlying Phase 4C.3 mutations remain the single authorization and
-- idempotency authority. These wrappers only join dependent mutations into
-- one database transaction so a lost response or a failed second step cannot
-- leave an orphan series or an unassignable duplicate task.

create or replace function public.create_schedule_task_with_assignment(
  p_stable_id uuid,
  p_horse_id uuid,
  p_title text,
  p_instruction text,
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
begin
  if (p_stable_member_id is null) <> (p_assignment_request_id is null) then
    raise exception using
      errcode = '22023',
      message = 'INVALID_OPTIONAL_ASSIGNMENT';
  end if;

  item_result := public.create_schedule_item(
    p_stable_id,
    p_horse_id,
    'task',
    'horse.schedule',
    p_title,
    p_instruction,
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
    'assignment_id', assignment_result ->> 'assignment_id',
    'assignment_status', assignment_result ->> 'status',
    'assignment_idempotent', assignment_result -> 'idempotent'
  );
end;
$$;

create or replace function public.create_schedule_series_with_occurrences(
  p_stable_id uuid,
  p_horse_id uuid,
  p_title text,
  p_instruction text,
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
  schedule_series_id uuid;
begin
  series_result := public.create_schedule_series(
    p_stable_id,
    p_horse_id,
    'task',
    'horse.schedule',
    p_title,
    p_instruction,
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

  return series_result || jsonb_build_object(
    'materialized_from_local_date',
      materialize_result ->> 'from_local_date',
    'materialized_through_local_date',
      materialize_result ->> 'through_local_date',
    'materialized_created_count',
      materialize_result -> 'created_count',
    'materialization_idempotent',
      materialize_result -> 'idempotent'
  );
end;
$$;

revoke execute on function public.create_schedule_task_with_assignment(
  uuid, uuid, text, text, text, timestamptz, timestamptz, text, date, time,
  uuid, uuid, uuid
) from public, anon;

revoke execute on function public.create_schedule_series_with_occurrences(
  uuid, uuid, text, text, text, text, integer, smallint[], time, integer,
  date, date, integer, text, date, uuid, uuid
) from public, anon;

grant execute on function public.create_schedule_task_with_assignment(
  uuid, uuid, text, text, text, timestamptz, timestamptz, text, date, time,
  uuid, uuid, uuid
) to authenticated;

grant execute on function public.create_schedule_series_with_occurrences(
  uuid, uuid, text, text, text, text, integer, smallint[], time, integer,
  date, date, integer, text, date, uuid, uuid
) to authenticated;

comment on function public.create_schedule_task_with_assignment(
  uuid, uuid, text, text, text, timestamptz, timestamptz, text, date, time,
  uuid, uuid, uuid
) is
  'Atomically creates one task and its optional responsible assignment.';

comment on function public.create_schedule_series_with_occurrences(
  uuid, uuid, text, text, text, text, integer, smallint[], time, integer,
  date, date, integer, text, date, uuid, uuid
) is
  'Atomically creates a schedule series and materializes its initial horizon.';
