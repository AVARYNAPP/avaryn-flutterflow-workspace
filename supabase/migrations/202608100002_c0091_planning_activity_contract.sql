begin;

-- C-009.1 forward-only canonical Planning contract extension. Existing rows,
-- item kinds, authority, RLS, audit, CAS and idempotency remain unchanged.

alter table public.schedule_items
  drop constraint schedule_items_item_kind_check,
  add constraint schedule_items_item_kind_check check (
    item_kind in (
      'task', 'feeding', 'training', 'care', 'farrier', 'veterinary',
      'competition', 'transport', 'other'
    )
  ),
  drop constraint schedule_items_instruction_check,
  add constraint schedule_items_instruction_check check (
    pg_catalog.length(pg_catalog.btrim(instruction)) between 0 and 2000
  );

create or replace function public.upsert_canonical_horse_schedule_item(
  p_horse_id uuid,
  p_schedule_item_id uuid,
  p_expected_row_version bigint,
  p_item_kind text,
  p_title text,
  p_instruction text,
  p_priority text,
  p_scheduled_start_at timestamptz,
  p_scheduled_end_at timestamptz,
  p_source_timezone text,
  p_state text,
  p_state_reason text,
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
  target public.schedule_items%rowtype;
  result jsonb;
  normalized_title text := pg_catalog.btrim(coalesce(p_title,''));
  -- Empty is the backward-compatible canonical representation for an omitted
  -- user note. The column remains NOT NULL for existing readers.
  normalized_instruction text := pg_catalog.btrim(coalesce(p_instruction,''));
  normalized_reason text := nullif(pg_catalog.btrim(p_state_reason),'');
  local_value timestamp;
begin
  actor_profile := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.edit');
  if p_request_id is null
    or p_item_kind not in (
      'task','feeding','training','care','farrier','veterinary',
      'competition','transport','other'
    )
    or p_priority not in ('normal','high')
    or p_state not in ('planned','in_progress','completed','skipped','cancelled')
    or length(normalized_title) not between 1 and 160
    or length(normalized_instruction) > 2000
    or p_scheduled_start_at is null
    or (p_scheduled_end_at is not null and p_scheduled_end_at<p_scheduled_start_at)
    or p_source_timezone is null or not exists (
      select 1 from pg_catalog.pg_timezone_names value where value.name=p_source_timezone
    ) or (p_state='cancelled' and normalized_reason is null)
  then raise exception using errcode='22023',message='INVALID_CANONICAL_SCHEDULE_ITEM'; end if;
  if p_schedule_item_id is null and p_expected_row_version is not null then
    raise exception using errcode='22023',message='INVALID_ROW_VERSION';
  end if;
  if p_schedule_item_id is not null and coalesce(p_expected_row_version,0)<1 then
    raise exception using errcode='22023',message='ROW_VERSION_REQUIRED';
  end if;
  payload_hash := private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,'schedule_item_id',p_schedule_item_id,
    'expected_row_version',p_expected_row_version,'item_kind',p_item_kind,
    'title',normalized_title,'instruction',normalized_instruction,
    'priority',p_priority,'scheduled_start_at',p_scheduled_start_at,
    'scheduled_end_at',p_scheduled_end_at,'source_timezone',p_source_timezone,
    'state',p_state,'state_reason',normalized_reason
  ));
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c0091:schedule:'||p_horse_id::text,0)
  );
  replay := private.schedule_receipt_result(
    actor_user,p_request_id,'upsert_canonical_horse_schedule_item',payload_hash
  );
  if replay is not null then return replay; end if;
  context_stable := private.c0091_legacy_stable_context(p_horse_id);
  local_value := p_scheduled_start_at at time zone p_source_timezone;
  if p_schedule_item_id is null then
    insert into public.schedule_items(
      stable_id,horse_id,item_kind,data_category,title,instruction,priority,
      scheduled_start_at,scheduled_end_at,source_timezone,source_local_date,
      source_local_time,state,state_reason,created_by_user_id,created_request_id,
      last_mutated_by_user_id,last_mutation_request_id,terminal_at
    ) values (
      context_stable,p_horse_id,p_item_kind,
      case when p_item_kind='feeding' then 'horse.nutrition' else 'horse.schedule' end,
      normalized_title,normalized_instruction,p_priority,p_scheduled_start_at,
      p_scheduled_end_at,p_source_timezone,local_value::date,local_value::time,
      p_state,normalized_reason,actor_user,p_request_id,actor_user,p_request_id,
      case when p_state in ('completed','skipped','cancelled') then pg_catalog.clock_timestamp() else null end
    ) returning * into target;
  else
    select * into target from public.schedule_items item
    where item.id=p_schedule_item_id and item.horse_id=p_horse_id for update;
    if target.id is null then raise exception using errcode='42501',message='HORSE_SCHEDULE_UNAVAILABLE'; end if;
    if target.row_version<>p_expected_row_version then
      raise exception using errcode='40001',message='STALE_SCHEDULE_VERSION'; end if;
    update public.schedule_items item set
      item_kind=p_item_kind,
      data_category=case when p_item_kind='feeding' then 'horse.nutrition' else 'horse.schedule' end,
      title=normalized_title,instruction=normalized_instruction,priority=p_priority,
      scheduled_start_at=p_scheduled_start_at,scheduled_end_at=p_scheduled_end_at,
      source_timezone=p_source_timezone,source_local_date=local_value::date,
      source_local_time=local_value::time,state=p_state,state_reason=normalized_reason,
      terminal_at=case when p_state in ('completed','skipped','cancelled')
        then coalesce(item.terminal_at,pg_catalog.clock_timestamp()) else null end,
      last_mutated_by_user_id=actor_user,last_mutation_request_id=p_request_id
    where item.id=target.id returning * into target;
  end if;
  result := pg_catalog.jsonb_build_object(
    'schedule_item_id',target.id,'horse_id',target.horse_id,
    'row_version',target.row_version,'state',target.state,'idempotent',false
  );
  insert into private.schedule_mutation_receipts(
    actor_user_id,request_id,stable_id,horse_id,operation_name,target_type,
    target_id,payload_hash,result
  ) values (
    actor_user,p_request_id,target.stable_id,p_horse_id,
    'upsert_canonical_horse_schedule_item','schedule_item',target.id,payload_hash,result
  );
  perform private.c0091_write_horse_domain_audit(
    p_horse_id,actor_profile,p_request_id,'canonical_schedule_item_upserted',
    array['planning']::text[]
  );
  return result;
end;
$$;

comment on function public.upsert_canonical_horse_schedule_item(
  uuid,uuid,bigint,text,text,text,text,timestamptz,timestamptz,text,text,text,uuid
) is
  'C-009.1 authenticated canonical-horse Planning upsert. Supports task, feeding, training, care, farrier, veterinary, competition, transport and other; an omitted user note is stored as an empty instruction string for backward-compatible readers.';

commit;
