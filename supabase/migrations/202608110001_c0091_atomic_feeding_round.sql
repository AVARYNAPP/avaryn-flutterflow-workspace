begin;

-- C-009.1 direct Feeding entry. Existing values are retained; `bale` is the
-- canonical storage value for the Dutch UI label `baal`.
alter table public.feeding_plan_items
  drop constraint feeding_plan_items_unit_code_check,
  add constraint feeding_plan_items_unit_code_check
    check (unit_code in ('g','kg','ml','l','scoop','portion','piece','bale'));

alter table public.feeding_occurrences
  drop constraint feeding_occurrences_unit_code_check,
  add constraint feeding_occurrences_unit_code_check
    check (unit_code in ('g','kg','ml','l','scoop','portion','piece','bale'));

alter table public.feeding_execution_details
  drop constraint feeding_execution_details_unit_code_check,
  add constraint feeding_execution_details_unit_code_check
    check (unit_code in ('g','kg','ml','l','scoop','portion','piece','bale'));

alter table private.feeding_mutation_receipts
  drop constraint feeding_mutation_receipts_operation_name_check;
alter table private.feeding_mutation_receipts
  add constraint feeding_mutation_receipts_operation_name_check
  check (operation_name in (
    'create_feeding_plan','create_feeding_plan_version',
    'upsert_feeding_plan_item','upsert_feeding_plan_item_v2',
    'approve_feeding_plan_version','activate_feeding_plan_version',
    'retire_feeding_plan','record_feeding_execution',
    'create_canonical_horse_feeding_plan',
    'upsert_canonical_horse_feeding_item',
    'transition_canonical_horse_feeding_version',
    'retire_canonical_horse_feeding_plan',
    'save_canonical_horse_feeding_round'
  ));

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
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_user uuid := auth.uid();
  actor_profile uuid;
  context_stable uuid;
  payload_hash bytea;
  replay jsonb;
  plan public.feeding_plans%rowtype;
  version public.feeding_plan_versions%rowtype;
  prior_version_id uuid;
  normalized_products jsonb := '[]'::jsonb;
  product jsonb;
  normalized_product jsonb;
  product_index integer := 0;
  product_type text;
  product_description text;
  product_note text;
  quantity_text text;
  quantity_value numeric;
  unit_value text;
  item_id_text text;
  item_id_value uuid;
  expected_item_version bigint;
  target_item public.feeding_plan_items%rowtype;
  product_category text;
  product_time time;
  result_items jsonb;
  result jsonb;
begin
  actor_profile := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.edit');

  if actor_user is null or p_request_id is null
    or p_plan_type not in ('standard','temporary')
    or p_round_code not in ('morning','afternoon','evening')
    or p_effective_from is null
    or (p_plan_type='standard' and p_effective_until is not null
      and p_effective_until<p_effective_from)
    or (p_plan_type='temporary' and (
      p_effective_until is null or p_effective_until<p_effective_from
    ))
    or (p_feeding_plan_id is null and p_expected_plan_row_version is not null)
    or (p_feeding_plan_id is not null and coalesce(p_expected_plan_row_version,0)<1)
    or pg_catalog.jsonb_typeof(p_products)<>'array'
    or pg_catalog.jsonb_array_length(p_products) not between 1 and 24
  then
    raise exception using errcode='22023',message='INVALID_CANONICAL_FEEDING_ROUND';
  end if;

  -- Normalize and validate every product before the first durable write. A
  -- malformed second product therefore cannot leave the plan or product one.
  for product in select value from pg_catalog.jsonb_array_elements(p_products)
  loop
    product_index := product_index + 1;
    if pg_catalog.jsonb_typeof(product)<>'object' then
      raise exception using errcode='22023',message='INVALID_CANONICAL_FEEDING_PRODUCT';
    end if;
    product_type := pg_catalog.btrim(coalesce(product->>'product_type',''));
    product_description := nullif(pg_catalog.btrim(product->>'description'),'');
    product_note := nullif(pg_catalog.btrim(product->>'note'),'');
    quantity_text := pg_catalog.btrim(coalesce(product->>'quantity',''));
    unit_value := pg_catalog.btrim(coalesce(product->>'unit_code',''));
    item_id_text := nullif(pg_catalog.btrim(product->>'item_id'),'');

    if product_type not in (
      'pellet','muesli','mash','roughage','supplement','medication','oil','other'
    ) or (product_description is not null and length(product_description)>160)
      or (product_note is not null and length(product_note)>1000)
      or quantity_text !~ '^[0-9]+([.][0-9]{1,4})?$'
      or unit_value not in ('g','kg','ml','l','scoop','portion','piece','bale')
      or (item_id_text is not null and item_id_text !~
        '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$')
      or (product ? 'expected_row_version' and (
        pg_catalog.jsonb_typeof(product->'expected_row_version')<>'number'
        or (product->>'expected_row_version')::numeric<1
        or (product->>'expected_row_version')::numeric<>pg_catalog.trunc((product->>'expected_row_version')::numeric)
      ))
    then
      raise exception using errcode='22023',message='INVALID_CANONICAL_FEEDING_PRODUCT';
    end if;
    quantity_value := quantity_text::numeric;
    if quantity_value<=0 then
      raise exception using errcode='22023',message='INVALID_CANONICAL_FEEDING_PRODUCT';
    end if;
    item_id_value := case when item_id_text is null then null else item_id_text::uuid end;
    expected_item_version := case when product ? 'expected_row_version'
      then (product->>'expected_row_version')::bigint else null end;
    if (item_id_value is null and expected_item_version is not null)
      or (item_id_value is not null and expected_item_version is null)
    then
      raise exception using errcode='22023',message='INVALID_FEEDING_ITEM_VERSION';
    end if;
    if item_id_value is not null and exists (
      select 1
      from pg_catalog.jsonb_array_elements(normalized_products) prior
      where prior->>'item_id'=item_id_value::text
    ) then
      raise exception using errcode='22023',message='DUPLICATE_FEEDING_ITEM_ID';
    end if;

    normalized_product := pg_catalog.jsonb_build_object(
      'item_id',item_id_value,
      'expected_row_version',expected_item_version,
      'product_type',product_type,
      'description',product_description,
      'quantity',quantity_value,
      'unit_code',unit_value,
      'note',product_note,
      'ordinal',product_index
    );
    normalized_products := normalized_products || pg_catalog.jsonb_build_array(normalized_product);
  end loop;

  payload_hash := private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,'plan_type',p_plan_type,
    'feeding_plan_id',p_feeding_plan_id,
    'expected_plan_row_version',p_expected_plan_row_version,
    'round_code',p_round_code,'effective_from',p_effective_from,
    'effective_until',p_effective_until,'products',normalized_products
  ));
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c0091:feeding:'||p_horse_id::text,0)
  );
  replay := private.feeding_receipt_result(
    actor_user,p_request_id,'save_canonical_horse_feeding_round',payload_hash
  );
  if replay is not null then return replay; end if;

  context_stable := private.c0091_legacy_stable_context(p_horse_id);
  if p_feeding_plan_id is null then
    insert into public.feeding_plans(
      stable_id,horse_id,plan_type,name,effective_from,effective_until,
      created_by_user_id,created_request_id,last_mutated_by_user_id,last_mutation_request_id
    ) values (
      context_stable,p_horse_id,p_plan_type,
      case p_plan_type when 'standard' then 'Basisvoeding' else 'Tijdelijk schema' end,
      p_effective_from,p_effective_until,actor_user,p_request_id,actor_user,p_request_id
    ) returning * into plan;
    insert into public.feeding_plan_versions(
      stable_id,feeding_plan_id,version_number,source_kind,change_reason,
      created_by_user_id,created_request_id,last_mutated_by_user_id,last_mutation_request_id
    ) values (
      context_stable,plan.id,1,'user','Directe invoer van '||p_round_code,
      actor_user,extensions.gen_random_uuid(),actor_user,p_request_id
    ) returning * into version;
  else
    select value.* into plan
    from public.feeding_plans value
    where value.id=p_feeding_plan_id and value.horse_id=p_horse_id
    for update;
    if plan.id is null or plan.plan_type<>p_plan_type then
      raise exception using errcode='42501',message='HORSE_FEEDING_UNAVAILABLE';
    end if;
    if plan.status='retired' then
      raise exception using errcode='55000',message='FEEDING_PLAN_RETIRED';
    end if;
    if plan.row_version<>p_expected_plan_row_version then
      raise exception using errcode='40001',message='STALE_FEEDING_PLAN_VERSION';
    end if;

    select value.* into version
    from public.feeding_plan_versions value
    where value.feeding_plan_id=plan.id and value.status='draft'
    order by value.version_number desc,value.id
    limit 1 for update;
    if version.id is null then
      insert into public.feeding_plan_versions(
        stable_id,feeding_plan_id,version_number,source_kind,change_reason,
        created_by_user_id,created_request_id,last_mutated_by_user_id,last_mutation_request_id
      ) values (
        plan.stable_id,plan.id,
        (select coalesce(max(value.version_number),0)+1
          from public.feeding_plan_versions value where value.feeding_plan_id=plan.id),
        'user','Directe wijziging van '||p_round_code,
        actor_user,extensions.gen_random_uuid(),actor_user,p_request_id
      ) returning * into version;

      if plan.active_version_id is not null then
        insert into public.feeding_plan_items(
          stable_id,feeding_plan_version_id,item_category,product_brand,product_name,
          product_variant,source_status,planned_quantity,unit_code,offering_method,
          round_code,local_time,weekdays,interval_days,override_key,
          default_stable_member_id,batch_lot,expires_on,instruction,
          created_by_user_id,created_request_id,last_mutated_by_user_id,last_mutation_request_id
        )
        select item.stable_id,version.id,item.item_category,item.product_brand,
          item.product_name,item.product_variant,item.source_status,
          item.planned_quantity,item.unit_code,item.offering_method,item.round_code,
          item.local_time,item.weekdays,item.interval_days,
          item.override_key||'-'||pg_catalog.substr(extensions.gen_random_uuid()::text,1,8),
          item.default_stable_member_id,item.batch_lot,item.expires_on,item.instruction,
          actor_user,extensions.gen_random_uuid(),actor_user,p_request_id
        from public.feeding_plan_items item
        where item.feeding_plan_version_id=plan.active_version_id
          and item.round_code<>p_round_code;
      end if;
    end if;

    update public.feeding_plans value set
      effective_from=p_effective_from,effective_until=p_effective_until,
      last_mutated_by_user_id=actor_user,last_mutation_request_id=p_request_id
    where value.id=plan.id returning * into plan;
  end if;

  -- Remove omitted draft rows before inserting replacements. Newly inserted
  -- rows cannot be mistaken for omissions later in the same call.
  delete from public.feeding_plan_items existing
  where existing.feeding_plan_version_id=version.id
    and existing.round_code=p_round_code
    and not exists (
      select 1 from pg_catalog.jsonb_array_elements(normalized_products) supplied
      where nullif(supplied->>'item_id','')::uuid=existing.id
    );

  -- Existing identifiers are retained when the client is editing the current
  -- draft. IDs from the approved source version are safely replaced in the new
  -- immutable version, while IDs from another plan or horse are denied.
  for normalized_product in
    select value from pg_catalog.jsonb_array_elements(normalized_products)
    order by (value->>'ordinal')::integer
  loop
    item_id_value := nullif(normalized_product->>'item_id','')::uuid;
    expected_item_version := nullif(normalized_product->>'expected_row_version','')::bigint;
    product_type := normalized_product->>'product_type';
    product_description := nullif(normalized_product->>'description','');
    product_note := nullif(normalized_product->>'note','');
    quantity_value := (normalized_product->>'quantity')::numeric;
    unit_value := normalized_product->>'unit_code';
    product_category := case product_type
      when 'roughage' then 'hay'
      when 'supplement' then 'supplement'
      when 'medication' then 'medication'
      else 'feed'
    end;
    product_time := case p_round_code
      when 'morning' then '08:00'::time
      when 'afternoon' then '13:00'::time
      else '18:00'::time
    end;

    target_item := null;
    if item_id_value is not null then
      if exists (
        select 1
        from public.feeding_plan_items foreign_item
        join public.feeding_plan_versions foreign_version
          on foreign_version.id=foreign_item.feeding_plan_version_id
        join public.feeding_plans foreign_plan
          on foreign_plan.id=foreign_version.feeding_plan_id
        where foreign_item.id=item_id_value and foreign_plan.horse_id<>p_horse_id
      ) then
        raise exception using errcode='42501',message='HORSE_FEEDING_UNAVAILABLE';
      end if;
      select value.* into target_item
      from public.feeding_plan_items value
      where value.id=item_id_value
        and value.feeding_plan_version_id=version.id
        and value.round_code=p_round_code
      for update;
    end if;

    if target_item.id is not null then
      if target_item.row_version<>expected_item_version then
        raise exception using errcode='40001',message='STALE_FEEDING_ITEM_VERSION';
      end if;
      update public.feeding_plan_items value set
        item_category=product_category,product_brand=product_description,
        product_name=product_type,product_variant=product_type,
        source_status='user_entered',planned_quantity=quantity_value,
        unit_code=unit_value,
        offering_method=case when product_type='roughage' then 'hay_net' else 'bucket' end,
        round_code=p_round_code,local_time=product_time,weekdays=null,
        interval_days=null,instruction=product_note,
        last_mutated_by_user_id=actor_user,last_mutation_request_id=p_request_id
      where value.id=target_item.id;
    else
      insert into public.feeding_plan_items(
        stable_id,feeding_plan_version_id,item_category,product_brand,product_name,
        product_variant,source_status,planned_quantity,unit_code,offering_method,
        round_code,local_time,weekdays,interval_days,override_key,instruction,
        created_by_user_id,created_request_id,last_mutated_by_user_id,last_mutation_request_id
      ) values (
        plan.stable_id,version.id,product_category,product_description,
        product_type,product_type,'user_entered',quantity_value,unit_value,
        case when product_type='roughage' then 'hay_net' else 'bucket' end,
        p_round_code,product_time,null,null,
        p_round_code||'-'||extensions.gen_random_uuid()::text,product_note,
        actor_user,extensions.gen_random_uuid(),actor_user,p_request_id
      );
    end if;
  end loop;

  -- Approve and activate inside the same transaction. Failure of overlap,
  -- lifecycle or any item constraint rolls the entire call back.
  update public.feeding_plan_versions value set
    status='approved',approved_by_user_id=actor_user,
    approved_at=pg_catalog.clock_timestamp(),
    last_mutated_by_user_id=actor_user,last_mutation_request_id=p_request_id
  where value.id=version.id returning * into version;

  if plan.plan_type='standard' and exists (
    select 1 from public.feeding_plans other
    where other.horse_id=p_horse_id and other.id<>plan.id
      and other.plan_type='standard' and other.status='active'
      and pg_catalog.daterange(other.effective_from,
        coalesce(other.effective_until+1,'infinity'::date),'[)')
        && pg_catalog.daterange(plan.effective_from,
        coalesce(plan.effective_until+1,'infinity'::date),'[)')
  ) then
    raise exception using errcode='23P01',message='STANDARD_FEEDING_PLAN_OVERLAP';
  end if;
  if plan.plan_type='temporary' and (
    not exists (
      select 1 from public.feeding_plans base
      where base.horse_id=p_horse_id and base.plan_type='standard'
        and base.status='active' and base.effective_from<=plan.effective_from
        and (base.effective_until is null or base.effective_until>=plan.effective_until)
    ) or exists (
      select 1 from public.feeding_plans other
      where other.horse_id=p_horse_id and other.id<>plan.id
        and other.plan_type='temporary' and other.status='active'
        and pg_catalog.daterange(other.effective_from,other.effective_until+1,'[)')
          && pg_catalog.daterange(plan.effective_from,plan.effective_until+1,'[)')
    )
  ) then
    raise exception using errcode='23P01',message='TEMPORARY_FEEDING_PLAN_CONFLICT';
  end if;

  prior_version_id := plan.active_version_id;
  if prior_version_id is not null and prior_version_id<>version.id then
    update public.feeding_plan_versions value set
      status='superseded',last_mutated_by_user_id=actor_user,
      last_mutation_request_id=p_request_id
    where value.id=prior_version_id and value.status='approved';
  end if;
  update public.feeding_plans value set
    status='active',active_version_id=version.id,
    last_mutated_by_user_id=actor_user,last_mutation_request_id=p_request_id
  where value.id=plan.id returning * into plan;

  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'feeding_plan_item_id',item.id,'row_version',item.row_version,
    'product_type',item.product_variant,'description',item.product_brand,
    'quantity',item.planned_quantity,'unit_code',item.unit_code,
    'note',item.instruction
  ) order by item.local_time,item.id),'[]'::jsonb)
  into result_items
  from public.feeding_plan_items item
  where item.feeding_plan_version_id=version.id and item.round_code=p_round_code;

  result := pg_catalog.jsonb_build_object(
    'feeding_plan_id',plan.id,'feeding_plan_version_id',version.id,
    'plan_row_version',plan.row_version,'version_row_version',version.row_version,
    'plan_type',plan.plan_type,'round_code',p_round_code,
    'effective_from',plan.effective_from,'effective_until',plan.effective_until,
    'status',plan.status,'items',result_items,'idempotent',false
  );
  insert into private.feeding_mutation_receipts(
    actor_user_id,request_id,stable_id,horse_id,operation_name,target_type,
    target_id,payload_hash,result
  ) values (
    actor_user,p_request_id,plan.stable_id,p_horse_id,
    'save_canonical_horse_feeding_round','feeding_plan',plan.id,payload_hash,result
  );
  perform private.c0091_write_horse_domain_audit(
    p_horse_id,actor_profile,p_request_id,'canonical_feeding_round_saved',
    array['feeding']::text[]
  );
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
) is 'C-009.1 atomic canonical-horse Feeding round save. Validates all products before writes, preserves immutable approved versions and activates the complete result in one transaction.';

do $$
begin
  if (
    select count(*)
    from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='public'
      and procedure.proname='save_canonical_horse_feeding_round'
      and procedure.prosecdef
      and procedure.proconfig=array['search_path=""']::text[]
      and pg_catalog.has_function_privilege(
        'authenticated',procedure.oid,'EXECUTE'
      )
      and not pg_catalog.has_function_privilege('anon',procedure.oid,'EXECUTE')
      and not pg_catalog.has_function_privilege('service_role',procedure.oid,'EXECUTE')
  )<>1 then
    raise exception using errcode='55000',message='C0091_ATOMIC_FEEDING_RPC_INVALID';
  end if;
end;
$$;

commit;
