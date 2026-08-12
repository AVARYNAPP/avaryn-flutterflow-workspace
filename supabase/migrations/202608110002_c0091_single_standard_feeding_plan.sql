begin;

-- Preserve the already reviewed atomic implementation as the non-granted
-- executor. The public wrapper below resolves one durable standard-plan
-- identity before delegating to the unchanged transaction.
alter function public.save_canonical_horse_feeding_round(
  uuid,text,uuid,bigint,text,date,date,jsonb,uuid
) rename to save_canonical_horse_feeding_round_v1;

alter function public.save_canonical_horse_feeding_round_v1(
  uuid,text,uuid,bigint,text,date,date,jsonb,uuid
) set schema private;

revoke all on function private.save_canonical_horse_feeding_round_v1(
  uuid,text,uuid,bigint,text,date,date,jsonb,uuid
) from public,anon,authenticated,service_role;

create or replace function public.save_canonical_horse_feeding_round(
  p_horse_id uuid,
  p_plan_type text,
  p_feeding_plan_id uuid,
  p_expected_plan_row_version bigint,
  p_round_code text,
  p_effective_from date,
  p_effective_until date,
  p_products jsonb,
  p_request_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_user uuid := auth.uid();
  actor_profile uuid;
  logical_payload_hash bytea;
  replay jsonb;
  resolved_plan_id uuid := p_feeding_plan_id;
  resolved_plan_row_version bigint := p_expected_plan_row_version;
  result jsonb;
begin
  actor_profile := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(
    actor_profile,p_horse_id,'horse.edit'
  );

  -- Keep the receipt bound to the caller's logical request. Without this
  -- outer hash, replaying a first save with a null plan id would be compared
  -- with the plan id resolved after that first save and be rejected.
  logical_payload_hash := private.schedule_payload_hash(
    pg_catalog.jsonb_build_object(
      'horse_id',p_horse_id,
      'plan_type',p_plan_type,
      'feeding_plan_id',p_feeding_plan_id,
      'expected_plan_row_version',p_expected_plan_row_version,
      'round_code',p_round_code,
      'effective_from',p_effective_from,
      'effective_until',p_effective_until,
      'products',p_products
    )
  );

  -- Serialize identity resolution with the executor. A concurrent first save
  -- observes and reuses the plan committed by its predecessor instead of
  -- creating a second functional Basisvoeding.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c0091:feeding:'||p_horse_id::text,0)
  );
  replay := private.feeding_receipt_result(
    actor_user,p_request_id,'save_canonical_horse_feeding_round',
    logical_payload_hash
  );
  if replay is not null then return replay; end if;

  if p_plan_type='standard' and p_feeding_plan_id is null then
    select plan.id,plan.row_version
      into resolved_plan_id,resolved_plan_row_version
    from public.feeding_plans plan
    where plan.horse_id=p_horse_id
      and plan.plan_type='standard'
      and plan.status<>'retired'
    order by
      case plan.status when 'active' then 0 else 1 end,
      case when exists (
        select 1
        from public.feeding_plan_versions version
        join public.feeding_plan_items item
          on item.feeding_plan_version_id=version.id
        where version.feeding_plan_id=plan.id
      ) then 0 else 1 end,
      plan.effective_from desc,
      plan.id
    limit 1
    for update of plan;
  end if;

  result := private.save_canonical_horse_feeding_round_v1(
    p_horse_id,
    p_plan_type,
    resolved_plan_id,
    resolved_plan_row_version,
    p_round_code,
    p_effective_from,
    p_effective_until,
    p_products,
    p_request_id
  );

  -- The unchanged executor stored its normalized physical request hash. Once
  -- it succeeds, replace only that receipt hash with the logical caller hash
  -- so exact null-id retries remain idempotent. Audit and result stay intact.
  update private.feeding_mutation_receipts receipt
  set payload_hash=logical_payload_hash
  where receipt.actor_user_id=actor_user
    and receipt.request_id=p_request_id
    and receipt.operation_name='save_canonical_horse_feeding_round';
  if not found then
    raise exception 'C0091_FEEDING_RECEIPT_MISSING';
  end if;
  return result;
end;
$$;

revoke all on function public.save_canonical_horse_feeding_round(
  uuid,text,uuid,bigint,text,date,date,jsonb,uuid
) from public,anon,authenticated,service_role;
grant execute on function public.save_canonical_horse_feeding_round(
  uuid,text,uuid,bigint,text,date,date,jsonb,uuid
) to authenticated;

comment on function public.save_canonical_horse_feeding_round(
  uuid,text,uuid,bigint,text,date,date,jsonb,uuid
) is
  'C-009.1 canonical atomic round save; reuses the single functional standard plan under the horse lock.';

do $$
begin
  if pg_catalog.has_function_privilege(
      'anon',
      'public.save_canonical_horse_feeding_round(uuid,text,uuid,bigint,text,date,date,jsonb,uuid)',
      'EXECUTE'
    )
    or not pg_catalog.has_function_privilege(
      'authenticated',
      'public.save_canonical_horse_feeding_round(uuid,text,uuid,bigint,text,date,date,jsonb,uuid)',
      'EXECUTE'
    )
    or pg_catalog.has_function_privilege(
      'service_role',
      'public.save_canonical_horse_feeding_round(uuid,text,uuid,bigint,text,date,date,jsonb,uuid)',
      'EXECUTE'
    )
    or pg_catalog.has_function_privilege(
      'authenticated',
      'private.save_canonical_horse_feeding_round_v1(uuid,text,uuid,bigint,text,date,date,jsonb,uuid)',
      'EXECUTE'
    )
  then
    raise exception 'C0091_SINGLE_STANDARD_FEEDING_ACL_INVALID';
  end if;
end;
$$;

commit;
