-- Phase 5D.2: keep the first feeding-plan version atomic with its plan.

create or replace function public.create_feeding_plan_with_version(
  p_horse_id uuid,
  p_plan_type text,
  p_name text,
  p_effective_from date,
  p_effective_until date,
  p_change_reason text,
  p_create_request_id uuid,
  p_version_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  plan_result jsonb;
  version_result jsonb;
begin
  if p_create_request_id is null
    or p_version_request_id is null
    or p_create_request_id = p_version_request_id
  then
    raise exception using
      errcode = '22023',
      message = 'DISTINCT_REQUEST_IDS_REQUIRED';
  end if;

  plan_result := public.create_feeding_plan(
    p_horse_id,
    p_plan_type,
    p_name,
    p_effective_from,
    p_effective_until,
    p_create_request_id
  );

  version_result := public.create_feeding_plan_version(
    (plan_result->>'feeding_plan_id')::uuid,
    'user',
    null,
    p_change_reason,
    p_version_request_id
  );

  return jsonb_build_object(
    'feeding_plan_id', plan_result->>'feeding_plan_id',
    'feeding_plan_row_version', plan_result->'row_version',
    'feeding_plan_version_id',
      version_result->>'feeding_plan_version_id',
    'feeding_plan_version_row_version', version_result->'row_version',
    'version_number', version_result->'version_number',
    'status', version_result->>'status',
    'idempotent',
      coalesce((plan_result->>'idempotent')::boolean, false)
      and coalesce((version_result->>'idempotent')::boolean, false)
  );
end;
$$;

revoke execute on function public.create_feeding_plan_with_version(
  uuid, text, text, date, date, text, uuid, uuid
) from public, anon;

grant execute on function public.create_feeding_plan_with_version(
  uuid, text, text, date, date, text, uuid, uuid
) to authenticated;

comment on function public.create_feeding_plan_with_version(
  uuid, text, text, date, date, text, uuid, uuid
) is
  'Atomically creates one feeding plan and its first durable draft version.';
