begin;

-- C-009.1 forward-only syntax correction for the canonical Feeding item
-- upsert. The signature, return contract, authority, validation, RLS/ACL,
-- idempotency, CAS, audit and data semantics remain unchanged.
create or replace function public.upsert_canonical_horse_feeding_item(
  p_horse_id uuid,p_feeding_plan_version_id uuid,p_feeding_plan_item_id uuid,
  p_expected_row_version bigint,p_item_category text,p_product_brand text,
  p_product_name text,p_product_variant text,p_planned_quantity numeric,
  p_unit_code text,p_offering_method text,p_round_code text,p_local_time time,
  p_weekdays smallint[],p_interval_days integer,p_override_key text,
  p_instruction text,p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_user uuid := auth.uid(); actor_profile uuid; payload_hash bytea;
  replay jsonb; plan public.feeding_plans%rowtype;
  version public.feeding_plan_versions%rowtype; item public.feeding_plan_items%rowtype;
  result jsonb; normalized_name text := pg_catalog.btrim(coalesce(p_product_name,''));
  normalized_round text := pg_catalog.btrim(coalesce(p_round_code,''));
  normalized_override text := pg_catalog.btrim(coalesce(p_override_key,''));
begin
  actor_profile := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.edit');
  if p_request_id is null or p_item_category not in ('feed','supplement','hay','water','medication')
    or length(normalized_name) not between 1 and 200
    or p_planned_quantity is null or p_planned_quantity<=0
    or p_unit_code not in ('g','kg','ml','l','scoop','portion','piece')
    or p_offering_method not in ('bucket','manger','hay_net','pasture','hand','other')
    or length(normalized_round) not between 1 and 80 or p_local_time is null
    or length(normalized_override) not between 1 and 160
    or (p_weekdays is not null and p_interval_days is not null)
  then raise exception using errcode='22023',message='INVALID_CANONICAL_FEEDING_ITEM'; end if;
  if p_feeding_plan_item_id is null and p_expected_row_version is not null then
    raise exception using errcode='22023',message='INVALID_ROW_VERSION'; end if;
  if p_feeding_plan_item_id is not null and coalesce(p_expected_row_version,0)<1 then
    raise exception using errcode='22023',message='ROW_VERSION_REQUIRED'; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c0091:feeding:'||p_horse_id::text,0)
  );
  select value.* into version from public.feeding_plan_versions value
    where value.id=p_feeding_plan_version_id for update;
  select value.* into plan from public.feeding_plans value
    where value.id=version.feeding_plan_id and value.horse_id=p_horse_id for update;
  if version.id is null or plan.id is null then
    raise exception using errcode='42501',message='HORSE_FEEDING_UNAVAILABLE'; end if;
  if version.status<>'draft' or plan.status='retired' then
    raise exception using errcode='55000',message='FEEDING_VERSION_IMMUTABLE'; end if;
  payload_hash := private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,'version_id',p_feeding_plan_version_id,
    'item_id',p_feeding_plan_item_id,'expected',p_expected_row_version,
    'category',p_item_category,'brand',p_product_brand,'name',normalized_name,
    'variant',p_product_variant,'quantity',p_planned_quantity,'unit',p_unit_code,
    'method',p_offering_method,'round',normalized_round,'time',p_local_time,
    'weekdays',p_weekdays,'interval',p_interval_days,'override',normalized_override,
    'instruction',p_instruction
  ));
  replay := private.feeding_receipt_result(
    actor_user,p_request_id,'upsert_canonical_horse_feeding_item',payload_hash
  );
  if replay is not null then return replay; end if;
  if p_feeding_plan_item_id is null then
    insert into public.feeding_plan_items(
      stable_id,feeding_plan_version_id,item_category,product_brand,product_name,
      product_variant,source_status,planned_quantity,unit_code,offering_method,
      round_code,local_time,weekdays,interval_days,override_key,instruction,
      created_by_user_id,created_request_id,last_mutated_by_user_id,last_mutation_request_id
    ) values (
      plan.stable_id,version.id,p_item_category,NULLIF(pg_catalog.btrim(p_product_brand),''),
      normalized_name,NULLIF(pg_catalog.btrim(p_product_variant),''),'user_entered',
      p_planned_quantity,p_unit_code,p_offering_method,normalized_round,p_local_time,
      p_weekdays,p_interval_days,normalized_override,
      NULLIF(pg_catalog.btrim(p_instruction),''),actor_user,p_request_id,
      actor_user,p_request_id
    ) returning * into item;
  else
    select value.* into item from public.feeding_plan_items value
    where value.id=p_feeding_plan_item_id
      and value.feeding_plan_version_id=version.id for update;
    if item.id is null then raise exception using errcode='42501',message='HORSE_FEEDING_UNAVAILABLE'; end if;
    if item.row_version<>p_expected_row_version then
      raise exception using errcode='40001',message='STALE_FEEDING_ITEM_VERSION'; end if;
    update public.feeding_plan_items value set
      item_category=p_item_category,product_brand=NULLIF(pg_catalog.btrim(p_product_brand),''),
      product_name=normalized_name,product_variant=NULLIF(pg_catalog.btrim(p_product_variant),''),
      source_status='user_entered',planned_quantity=p_planned_quantity,
      unit_code=p_unit_code,offering_method=p_offering_method,round_code=normalized_round,
      local_time=p_local_time,weekdays=p_weekdays,interval_days=p_interval_days,
      override_key=normalized_override,instruction=NULLIF(pg_catalog.btrim(p_instruction),''),
      last_mutated_by_user_id=actor_user,last_mutation_request_id=p_request_id
    where value.id=item.id returning * into item;
  end if;
  result := pg_catalog.jsonb_build_object(
    'feeding_plan_item_id',item.id,'feeding_plan_version_id',version.id,
    'row_version',item.row_version,'idempotent',false
  );
  insert into private.feeding_mutation_receipts(
    actor_user_id,request_id,stable_id,horse_id,operation_name,target_type,
    target_id,payload_hash,result
  ) values (
    actor_user,p_request_id,plan.stable_id,p_horse_id,
    'upsert_canonical_horse_feeding_item','feeding_plan_item',item.id,payload_hash,result
  );
  perform private.c0091_write_horse_domain_audit(
    p_horse_id,actor_profile,p_request_id,'canonical_feeding_item_upserted',
    array['feeding']::text[]
  );
  return result;
end;
$$;

do $$
begin
  if (
    select count(*)
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='public'
      and procedure.proname='upsert_canonical_horse_feeding_item'
      and pg_catalog.pg_get_function_identity_arguments(procedure.oid)=
        'p_horse_id uuid, p_feeding_plan_version_id uuid, p_feeding_plan_item_id uuid, p_expected_row_version bigint, p_item_category text, p_product_brand text, p_product_name text, p_product_variant text, p_planned_quantity numeric, p_unit_code text, p_offering_method text, p_round_code text, p_local_time time without time zone, p_weekdays smallint[], p_interval_days integer, p_override_key text, p_instruction text, p_request_id uuid'
      and pg_catalog.pg_get_function_result(procedure.oid)='jsonb'
      and procedure.prosecdef
      and procedure.proconfig=array['search_path=""']::text[]
      and position(
        'pg_catalog.nullif' in pg_catalog.lower(pg_catalog.pg_get_functiondef(procedure.oid))
      )=0
  )<>1 then
    raise exception using
      errcode='55000',
      message='C0091_CANONICAL_FEEDING_NULLIF_FIX_INVALID';
  end if;
end;
$$;

commit;
