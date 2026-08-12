begin;

-- C-009.1 forward-only canonical horse rescoping for the existing Planning
-- and Feeding aggregates. Stable context remains optional compatibility
-- metadata for horse-owned rows and remains mandatory for stable-only work.

-- Fail closed before changing constraints: every legacy horse reference must
-- already resolve to the one C-008 canonical identity.
do $$
begin
  if exists (
    select 1
    from public.schedule_series series
    left join public.canonical_horses horse on horse.id = series.horse_id
    where series.horse_id is not null and horse.id is null
  ) or exists (
    select 1
    from public.schedule_items item
    left join public.canonical_horses horse on horse.id = item.horse_id
    where item.horse_id is not null and horse.id is null
  ) or exists (
    select 1
    from public.feeding_plans plan
    left join public.canonical_horses horse on horse.id = plan.horse_id
    where horse.id is null
  ) then
    raise exception using
      errcode = '23503',
      message = 'C0091_CANONICAL_HORSE_BACKFILL_UNRESOLVED';
  end if;
end;
$$;

alter table public.schedule_series
  alter column stable_id drop not null;
alter table public.schedule_items
  alter column stable_id drop not null;
alter table public.feeding_plans
  alter column stable_id drop not null;
alter table public.feeding_plan_versions
  alter column stable_id drop not null;
alter table public.feeding_plan_items
  alter column stable_id drop not null;

alter table private.schedule_mutation_receipts
  alter column stable_id drop not null,
  add column horse_id uuid references public.canonical_horses(id) on delete restrict;
alter table private.feeding_mutation_receipts
  alter column stable_id drop not null,
  add column horse_id uuid references public.canonical_horses(id) on delete restrict;

-- Existing receipts are unambiguous: their target IDs already identify the
-- existing schedule/feeding aggregate. No row is guessed or rewritten.
update private.schedule_mutation_receipts receipt
set horse_id = item.horse_id
from public.schedule_items item
where receipt.target_type = 'schedule_item'
  and receipt.target_id = item.id
  and receipt.horse_id is null
  and item.horse_id is not null;

update private.schedule_mutation_receipts receipt
set horse_id = series.horse_id
from public.schedule_series series
where receipt.target_type = 'schedule_series'
  and receipt.target_id = series.id
  and receipt.horse_id is null
  and series.horse_id is not null;

update private.feeding_mutation_receipts receipt
set horse_id = resolved.horse_id
from (
  select plan.id as target_id, plan.horse_id
  from public.feeding_plans plan
  union all
  select version.id, plan.horse_id
  from public.feeding_plan_versions version
  join public.feeding_plans plan on plan.id = version.feeding_plan_id
  union all
  select item.id, plan.horse_id
  from public.feeding_plan_items item
  join public.feeding_plan_versions version on version.id = item.feeding_plan_version_id
  join public.feeding_plans plan on plan.id = version.feeding_plan_id
) resolved
where receipt.target_id = resolved.target_id
  and receipt.horse_id is null;

alter table public.schedule_series
  add constraint schedule_series_owner_scope_check
    check (stable_id is not null or horse_id is not null),
  add constraint schedule_series_canonical_horse_fk
    foreign key (horse_id) references public.canonical_horses(id) on delete restrict,
  add constraint schedule_series_supersedes_id_fk
    foreign key (supersedes_series_id) references public.schedule_series(id) on delete restrict;

alter table public.schedule_items
  add constraint schedule_items_owner_scope_check
    check (stable_id is not null or horse_id is not null),
  add constraint schedule_items_canonical_horse_fk
    foreign key (horse_id) references public.canonical_horses(id) on delete restrict,
  add constraint schedule_items_series_id_fk
    foreign key (series_id) references public.schedule_series(id) on delete restrict;

alter table public.feeding_plans
  add constraint feeding_plans_canonical_horse_fk
    foreign key (horse_id) references public.canonical_horses(id) on delete restrict;

alter table public.feeding_plan_versions
  add constraint feeding_plan_versions_plan_id_fk
    foreign key (feeding_plan_id) references public.feeding_plans(id) on delete restrict;

alter table public.feeding_plan_items
  add constraint feeding_plan_items_version_id_fk
    foreign key (feeding_plan_version_id)
    references public.feeding_plan_versions(id) on delete restrict,
  add constraint feeding_plan_items_stable_member_shape_check
    check (stable_id is not null or default_stable_member_id is null);

alter table private.schedule_mutation_receipts
  add constraint schedule_mutation_receipts_owner_scope_check
    check (stable_id is not null or horse_id is not null);
alter table private.feeding_mutation_receipts
  add constraint feeding_mutation_receipts_owner_scope_check
    check (stable_id is not null or horse_id is not null);

create index schedule_series_canonical_horse_period_idx
  on public.schedule_series (horse_id, starts_on, ends_on, status, id)
  where horse_id is not null;
create index schedule_items_canonical_horse_period_idx
  on public.schedule_items (horse_id, scheduled_start_at, state, id)
  where horse_id is not null;
create index feeding_plans_canonical_horse_period_idx
  on public.feeding_plans (
    horse_id, plan_type, status, effective_from, effective_until, id
  );
create index schedule_receipts_canonical_horse_idx
  on private.schedule_mutation_receipts (horse_id, created_at)
  where horse_id is not null;
create index feeding_receipts_canonical_horse_idx
  on private.feeding_mutation_receipts (horse_id, created_at)
  where horse_id is not null;

alter table private.schedule_mutation_receipts
  drop constraint schedule_mutation_receipts_operation_name_check;
alter table private.schedule_mutation_receipts
  add constraint schedule_mutation_receipts_operation_name_check
  check (operation_name in (
    'create_schedule_series','update_schedule_series_scope',
    'materialize_schedule_occurrences','create_schedule_item',
    'update_schedule_item','cancel_schedule_item','assign_schedule_item',
    'return_schedule_assignment','record_schedule_execution',
    'correct_schedule_execution','reopen_schedule_item',
    'upsert_canonical_horse_schedule_item'
  ));

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
    'retire_canonical_horse_feeding_plan'
  ));

create or replace function private.c0091_legacy_stable_context(p_horse_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select legacy.stable_id
  from public.horses legacy
  where legacy.canonical_horse_id = p_horse_id
    and legacy.id = p_horse_id
    and legacy.status = 'active'
  limit 1
$$;

create or replace function private.c0091_write_horse_domain_audit(
  p_horse_id uuid,
  p_actor_profile_id uuid,
  p_request_id uuid,
  p_operation_code text,
  p_changed_fields text[]
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  horse public.canonical_horses%rowtype;
begin
  select * into horse
  from public.canonical_horses value
  where value.id = p_horse_id;
  if horse.id is null or p_actor_profile_id is null or p_request_id is null then
    raise exception using errcode = '22023', message = 'C0091_AUDIT_INPUT_INVALID';
  end if;
  perform private.c003c_write_audit(
    'horse.updated','horse',horse.id,horse.id,p_actor_profile_id,p_request_id,
    'HORSE_UPDATED',null,null,horse.row_version,horse.row_version,
    horse.access_version,horse.access_version,
    pg_catalog.jsonb_build_object(
      'operation_code', p_operation_code,
      'changed_fields', pg_catalog.to_jsonb(coalesce(p_changed_fields,array[]::text[]))
    )
  );
end;
$$;

-- Canonical horses never inherit permission from stable membership. Legacy
-- stable-only items keep the existing stable-owned access model.
create or replace function private.schedule_membership_can_edit(
  p_membership public.stable_memberships,
  p_horse_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_horse_id is not null and exists (
      select 1 from public.canonical_horses horse where horse.id = p_horse_id
    ) then public.has_canonical_horse_permission(p_horse_id,'horse.edit')
    else p_membership.role in ('owner','admin') or (
      p_membership.role = 'member' and p_horse_id is not null and exists (
        select 1 from public.horse_access_grants grant_row
        where grant_row.horse_id = p_horse_id
          and grant_row.membership_id = p_membership.id
          and grant_row.category = 'horse.schedule'
          and grant_row.status = 'active' and grant_row.can_edit
          and grant_row.valid_from <= pg_catalog.statement_timestamp()
          and (grant_row.valid_until is null or grant_row.valid_until > pg_catalog.statement_timestamp())
      )
    )
  end
$$;

create or replace function private.schedule_membership_can_execute(
  p_membership public.stable_memberships,
  p_horse_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_horse_id is not null and exists (
      select 1 from public.canonical_horses horse where horse.id = p_horse_id
    ) then public.has_canonical_horse_permission(p_horse_id,'horse.edit')
    else p_membership.role in ('owner','admin') or (
      p_membership.role = 'member' and p_horse_id is not null and exists (
        select 1 from public.horse_access_grants grant_row
        where grant_row.horse_id = p_horse_id
          and grant_row.membership_id = p_membership.id
          and grant_row.category = 'horse.schedule'
          and grant_row.status = 'active' and grant_row.can_execute
          and grant_row.valid_from <= pg_catalog.statement_timestamp()
          and (grant_row.valid_until is null or grant_row.valid_until > pg_catalog.statement_timestamp())
      )
    )
  end
$$;

create or replace function private.schedule_item_access_level(p_schedule_item_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target public.schedule_items%rowtype;
  membership public.stable_memberships%rowtype;
begin
  if actor_id is null then return 'none'; end if;
  select * into target from public.schedule_items item where item.id=p_schedule_item_id;
  if target.id is null then return 'none'; end if;
  if target.horse_id is not null and exists (
    select 1 from public.canonical_horses horse
    where horse.id=target.horse_id and horse.status='active'
  ) then
    return case when public.has_canonical_horse_permission(target.horse_id,'horse.view')
      then 'full' else 'none' end;
  end if;
  if target.stable_id is null then return 'none'; end if;
  select * into membership from public.stable_memberships value
  where value.stable_id=target.stable_id and value.user_id=actor_id
    and value.status='active';
  if membership.id is null or not exists (
    select 1 from public.stables stable
    where stable.id=target.stable_id and stable.status='active'
  ) then return 'none'; end if;
  if membership.role in ('owner','admin') then return 'full'; end if;
  if membership.stable_member_id is not null and exists (
    select 1 from public.schedule_assignments assignment
    where assignment.schedule_item_id=target.id
      and assignment.stable_id=target.stable_id
      and assignment.stable_member_id=membership.stable_member_id
      and assignment.status in ('assigned','accepted','completed')
  ) then return 'assigned'; end if;
  return 'none';
end;
$$;

create or replace function private.can_select_schedule_series_base(p_schedule_series_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.schedule_series series
    where series.id=p_schedule_series_id and (
      (series.horse_id is not null and exists (
        select 1 from public.canonical_horses horse
        where horse.id=series.horse_id and horse.status='active'
      ) and public.has_canonical_horse_permission(series.horse_id,'horse.view'))
      or
      (series.horse_id is null and series.stable_id is not null and exists (
        select 1 from public.stables stable
        join public.stable_memberships membership on membership.stable_id=stable.id
        where stable.id=series.stable_id and stable.status='active'
          and membership.user_id=auth.uid() and membership.status='active'
          and membership.role in ('owner','admin')
      ))
    )
  )
$$;

create or replace function private.feeding_membership_can_edit(
  p_membership public.stable_memberships,
  p_horse_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case when exists (
    select 1 from public.canonical_horses horse where horse.id=p_horse_id
  ) then public.has_canonical_horse_permission(p_horse_id,'horse.edit')
  else p_membership.role='owner' or private.has_horse_capability(
    p_horse_id,'horse.nutrition','edit'
  ) end
$$;

create or replace function private.feeding_membership_can_manage(
  p_membership public.stable_memberships,
  p_horse_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case when exists (
    select 1 from public.canonical_horses horse where horse.id=p_horse_id
  ) then public.has_canonical_horse_permission(p_horse_id,'horse.edit')
  else p_membership.role='owner' or private.has_horse_capability(
    p_horse_id,'horse.nutrition','manage'
  ) end
$$;

create or replace function private.can_select_feeding_plan(p_feeding_plan_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.feeding_plans plan
    join public.canonical_horses horse on horse.id=plan.horse_id
    where plan.id=p_feeding_plan_id and horse.status='active'
      and public.has_canonical_horse_permission(plan.horse_id,'horse.view')
  )
$$;

create or replace function public.list_canonical_horse_schedule(
  p_horse_id uuid,
  p_from timestamptz,
  p_through timestamptz
)
returns table(
  schedule_item_id uuid, stable_id uuid, horse_id uuid, item_kind text,
  data_category text, title text, instruction text, priority text,
  scheduled_start_at timestamptz, scheduled_end_at timestamptz,
  source_timezone text, state text, state_reason text, row_version bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor_profile uuid;
begin
  actor_profile := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.view');
  if p_from is null or p_through is null or p_through < p_from
    or p_through > p_from + interval '2 years'
  then raise exception using errcode='22023',message='INVALID_SCHEDULE_PERIOD'; end if;
  return query
  select item.id,item.stable_id,item.horse_id,item.item_kind,item.data_category,
    item.title,item.instruction,item.priority,item.scheduled_start_at,
    item.scheduled_end_at,item.source_timezone,item.state,item.state_reason,
    item.row_version
  from public.schedule_items item
  where item.horse_id=p_horse_id
    and item.scheduled_start_at < p_through
    and coalesce(item.scheduled_end_at,item.scheduled_start_at) >= p_from
  order by item.scheduled_start_at,item.id;
end;
$$;

create or replace function public.list_my_canonical_horse_schedule(
  p_from timestamptz,
  p_through timestamptz
)
returns table(
  schedule_item_id uuid, stable_id uuid, horse_id uuid, horse_name text,
  item_kind text, title text, scheduled_start_at timestamptz,
  scheduled_end_at timestamptz, state text, row_version bigint
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  perform private.c003c_actor_profile_id();
  if p_from is null or p_through is null or p_through < p_from
    or p_through > p_from + interval '2 years'
  then raise exception using errcode='22023',message='INVALID_SCHEDULE_PERIOD'; end if;
  return query
  select item.id,item.stable_id,item.horse_id,horse.display_name,item.item_kind,
    item.title,item.scheduled_start_at,item.scheduled_end_at,item.state,item.row_version
  from public.schedule_items item
  join public.canonical_horses horse on horse.id=item.horse_id
  where public.has_canonical_horse_permission(item.horse_id,'horse.view')
    and item.scheduled_start_at < p_through
    and coalesce(item.scheduled_end_at,item.scheduled_start_at) >= p_from
  order by item.scheduled_start_at,item.id;
end;
$$;

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
  normalized_instruction text := pg_catalog.btrim(coalesce(p_instruction,''));
  normalized_reason text := nullif(pg_catalog.btrim(p_state_reason),'');
  local_value timestamp;
begin
  actor_profile := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.edit');
  if p_request_id is null or p_item_kind not in ('task','feeding','training','care','other')
    or p_priority not in ('normal','high')
    or p_state not in ('planned','in_progress','completed','skipped','cancelled')
    or length(normalized_title) not between 1 and 160
    or length(normalized_instruction) not between 1 and 2000
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

create or replace function public.get_canonical_horse_feeding(p_horse_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor_profile uuid; result jsonb; today date := current_date;
begin
  actor_profile := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.view');
  select pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,
    'active_plan_id',(
      select plan.id from public.feeding_plans plan
      where plan.horse_id=p_horse_id and plan.status='active'
        and plan.effective_from<=today
        and (plan.effective_until is null or plan.effective_until>=today)
      order by case plan.plan_type when 'temporary' then 0 else 1 end,
        plan.effective_from desc,plan.id limit 1
    ),
    'plans',coalesce(pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'feeding_plan_id',plan.id,'stable_id',plan.stable_id,
        'plan_type',plan.plan_type,'name',plan.name,'status',plan.status,
        'effective_from',plan.effective_from,'effective_until',plan.effective_until,
        'active_version_id',plan.active_version_id,'row_version',plan.row_version,
        'versions',coalesce((select pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'feeding_plan_version_id',version.id,'version_number',version.version_number,
            'status',version.status,'change_reason',version.change_reason,
            'row_version',version.row_version,
            'items',coalesce((select pg_catalog.jsonb_agg(
              pg_catalog.jsonb_build_object(
                'feeding_plan_item_id',item.id,'item_category',item.item_category,
                'product_brand',item.product_brand,'product_name',item.product_name,
                'product_variant',item.product_variant,
                'planned_quantity',item.planned_quantity,'unit_code',item.unit_code,
                'offering_method',item.offering_method,'round_code',item.round_code,
                'local_time',item.local_time,'weekdays',item.weekdays,
                'interval_days',item.interval_days,'override_key',item.override_key,
                'instruction',item.instruction,'row_version',item.row_version
              ) order by item.local_time,item.id
            ) from public.feeding_plan_items item
              where item.feeding_plan_version_id=version.id),'[]'::jsonb)
          ) order by version.version_number desc
        ) from public.feeding_plan_versions version
          where version.feeding_plan_id=plan.id),'[]'::jsonb)
      ) order by plan.plan_type,plan.effective_from desc,plan.id
    ) filter (where plan.id is not null),'[]'::jsonb)
  ) into result
  from public.feeding_plans plan where plan.horse_id=p_horse_id;
  return coalesce(result,pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,'active_plan_id',null,'plans','[]'::jsonb
  ));
end;
$$;

create or replace function public.create_canonical_horse_feeding_plan(
  p_horse_id uuid,p_plan_type text,p_name text,p_effective_from date,
  p_effective_until date,p_change_reason text,p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_user uuid := auth.uid(); actor_profile uuid; context_stable uuid;
  payload_hash bytea; replay jsonb; plan public.feeding_plans%rowtype;
  version public.feeding_plan_versions%rowtype; result jsonb;
  normalized_name text := pg_catalog.btrim(coalesce(p_name,''));
  normalized_reason text := pg_catalog.btrim(coalesce(p_change_reason,''));
begin
  actor_profile := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.edit');
  if p_request_id is null or p_plan_type not in ('standard','temporary')
    or length(normalized_name) not between 1 and 160
    or length(normalized_reason) not between 1 and 500 or p_effective_from is null
    or (p_effective_until is not null and p_effective_until<p_effective_from)
    or (p_plan_type='temporary' and p_effective_until is null)
  then raise exception using errcode='22023',message='INVALID_CANONICAL_FEEDING_PLAN'; end if;
  payload_hash := private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,'plan_type',p_plan_type,'name',normalized_name,
    'effective_from',p_effective_from,'effective_until',p_effective_until,
    'change_reason',normalized_reason
  ));
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c0091:feeding:'||p_horse_id::text,0)
  );
  replay := private.feeding_receipt_result(
    actor_user,p_request_id,'create_canonical_horse_feeding_plan',payload_hash
  );
  if replay is not null then return replay; end if;
  context_stable := private.c0091_legacy_stable_context(p_horse_id);
  insert into public.feeding_plans(
    stable_id,horse_id,plan_type,name,effective_from,effective_until,
    created_by_user_id,created_request_id,last_mutated_by_user_id,last_mutation_request_id
  ) values (
    context_stable,p_horse_id,p_plan_type,normalized_name,p_effective_from,
    p_effective_until,actor_user,p_request_id,actor_user,p_request_id
  ) returning * into plan;
  insert into public.feeding_plan_versions(
    stable_id,feeding_plan_id,version_number,source_kind,change_reason,
    created_by_user_id,created_request_id,last_mutated_by_user_id,last_mutation_request_id
  ) values (
    context_stable,plan.id,1,'user',normalized_reason,actor_user,p_request_id,
    actor_user,p_request_id
  ) returning * into version;
  result := pg_catalog.jsonb_build_object(
    'feeding_plan_id',plan.id,'feeding_plan_version_id',version.id,
    'plan_row_version',plan.row_version,'version_row_version',version.row_version,
    'status',plan.status,'idempotent',false
  );
  insert into private.feeding_mutation_receipts(
    actor_user_id,request_id,stable_id,horse_id,operation_name,target_type,
    target_id,payload_hash,result
  ) values (
    actor_user,p_request_id,context_stable,p_horse_id,
    'create_canonical_horse_feeding_plan','feeding_plan',plan.id,payload_hash,result
  );
  perform private.c0091_write_horse_domain_audit(
    p_horse_id,actor_profile,p_request_id,'canonical_feeding_plan_created',
    array['feeding']::text[]
  );
  return result;
end;
$$;

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
      plan.stable_id,version.id,p_item_category,nullif(pg_catalog.btrim(p_product_brand),''),
      normalized_name,nullif(pg_catalog.btrim(p_product_variant),''),'user_entered',
      p_planned_quantity,p_unit_code,p_offering_method,normalized_round,p_local_time,
      p_weekdays,p_interval_days,normalized_override,
      nullif(pg_catalog.btrim(p_instruction),''),actor_user,p_request_id,
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
      item_category=p_item_category,product_brand=nullif(pg_catalog.btrim(p_product_brand),''),
      product_name=normalized_name,product_variant=nullif(pg_catalog.btrim(p_product_variant),''),
      source_status='user_entered',planned_quantity=p_planned_quantity,
      unit_code=p_unit_code,offering_method=p_offering_method,round_code=normalized_round,
      local_time=p_local_time,weekdays=p_weekdays,interval_days=p_interval_days,
      override_key=normalized_override,instruction=nullif(pg_catalog.btrim(p_instruction),''),
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

create or replace function public.transition_canonical_horse_feeding_version(
  p_horse_id uuid,p_feeding_plan_version_id uuid,p_expected_row_version bigint,
  p_action text,p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_user uuid := auth.uid(); actor_profile uuid; payload_hash bytea;
  replay jsonb; plan public.feeding_plans%rowtype;
  version public.feeding_plan_versions%rowtype; prior uuid; result jsonb;
begin
  actor_profile := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.edit');
  if p_request_id is null or p_action not in ('approve','activate')
    or coalesce(p_expected_row_version,0)<1
  then raise exception using errcode='22023',message='INVALID_FEEDING_TRANSITION'; end if;
  payload_hash := private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,'version_id',p_feeding_plan_version_id,
    'expected',p_expected_row_version,'action',p_action
  ));
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c0091:feeding:'||p_horse_id::text,0)
  );
  replay := private.feeding_receipt_result(
    actor_user,p_request_id,'transition_canonical_horse_feeding_version',payload_hash
  );
  if replay is not null then return replay; end if;
  select value.* into version from public.feeding_plan_versions value
    where value.id=p_feeding_plan_version_id for update;
  select value.* into plan from public.feeding_plans value
    where value.id=version.feeding_plan_id and value.horse_id=p_horse_id for update;
  if version.id is null or plan.id is null then
    raise exception using errcode='42501',message='HORSE_FEEDING_UNAVAILABLE'; end if;
  if version.row_version<>p_expected_row_version then
    raise exception using errcode='40001',message='STALE_FEEDING_VERSION'; end if;
  if p_action='approve' then
    if version.status<>'draft' or not exists (
      select 1 from public.feeding_plan_items item
      where item.feeding_plan_version_id=version.id
    ) then raise exception using errcode='55000',message='FEEDING_VERSION_NOT_APPROVABLE'; end if;
    update public.feeding_plan_versions value set status='approved',
      approved_by_user_id=actor_user,approved_at=pg_catalog.clock_timestamp(),
      last_mutated_by_user_id=actor_user,last_mutation_request_id=p_request_id
    where value.id=version.id returning * into version;
  else
    if version.status<>'approved' then
      raise exception using errcode='55000',message='FEEDING_VERSION_NOT_ACTIVATABLE'; end if;
    if plan.plan_type='standard' and exists (
      select 1 from public.feeding_plans other
      where other.horse_id=p_horse_id and other.id<>plan.id
        and other.plan_type='standard' and other.status='active'
        and pg_catalog.daterange(other.effective_from,
          coalesce(other.effective_until+1,'infinity'::date),'[)')
          && pg_catalog.daterange(plan.effective_from,
          coalesce(plan.effective_until+1,'infinity'::date),'[)')
    ) then raise exception using errcode='23P01',message='STANDARD_FEEDING_PLAN_OVERLAP'; end if;
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
    ) then raise exception using errcode='23P01',message='TEMPORARY_FEEDING_PLAN_CONFLICT'; end if;
    prior := plan.active_version_id;
    if prior is not null and prior<>version.id then
      update public.feeding_plan_versions value set status='superseded',
        last_mutated_by_user_id=actor_user,last_mutation_request_id=p_request_id
      where value.id=prior and value.status='approved';
    end if;
    update public.feeding_plans value set status='active',active_version_id=version.id,
      last_mutated_by_user_id=actor_user,last_mutation_request_id=p_request_id
    where value.id=plan.id returning * into plan;
  end if;
  result := pg_catalog.jsonb_build_object(
    'feeding_plan_id',plan.id,'feeding_plan_version_id',version.id,
    'plan_row_version',plan.row_version,'version_row_version',version.row_version,
    'status',case when p_action='approve' then version.status else plan.status end,
    'idempotent',false
  );
  insert into private.feeding_mutation_receipts(
    actor_user_id,request_id,stable_id,horse_id,operation_name,target_type,
    target_id,payload_hash,result
  ) values (
    actor_user,p_request_id,plan.stable_id,p_horse_id,
    'transition_canonical_horse_feeding_version','feeding_plan_version',
    version.id,payload_hash,result
  );
  perform private.c0091_write_horse_domain_audit(
    p_horse_id,actor_profile,p_request_id,
    'canonical_feeding_version_'||p_action,array['feeding']::text[]
  );
  return result;
end;
$$;

create or replace function public.retire_canonical_horse_feeding_plan(
  p_horse_id uuid,p_feeding_plan_id uuid,p_expected_row_version bigint,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_user uuid := auth.uid(); actor_profile uuid; payload_hash bytea;
  replay jsonb; plan public.feeding_plans%rowtype; result jsonb;
begin
  actor_profile := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.edit');
  if p_request_id is null or coalesce(p_expected_row_version,0)<1 then
    raise exception using errcode='22023',message='ROW_VERSION_REQUIRED'; end if;
  payload_hash := private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,'plan_id',p_feeding_plan_id,'expected',p_expected_row_version
  ));
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c0091:feeding:'||p_horse_id::text,0)
  );
  replay := private.feeding_receipt_result(
    actor_user,p_request_id,'retire_canonical_horse_feeding_plan',payload_hash
  );
  if replay is not null then return replay; end if;
  select value.* into plan from public.feeding_plans value
  where value.id=p_feeding_plan_id and value.horse_id=p_horse_id for update;
  if plan.id is null then raise exception using errcode='42501',message='HORSE_FEEDING_UNAVAILABLE'; end if;
  if plan.row_version<>p_expected_row_version then
    raise exception using errcode='40001',message='STALE_FEEDING_PLAN'; end if;
  update public.feeding_plans value set status='retired',
    retired_at=pg_catalog.clock_timestamp(),last_mutated_by_user_id=actor_user,
    last_mutation_request_id=p_request_id
  where value.id=plan.id returning * into plan;
  result := pg_catalog.jsonb_build_object(
    'feeding_plan_id',plan.id,'row_version',plan.row_version,
    'status',plan.status,'idempotent',false
  );
  insert into private.feeding_mutation_receipts(
    actor_user_id,request_id,stable_id,horse_id,operation_name,target_type,
    target_id,payload_hash,result
  ) values (
    actor_user,p_request_id,plan.stable_id,p_horse_id,
    'retire_canonical_horse_feeding_plan','feeding_plan',plan.id,payload_hash,result
  );
  perform private.c0091_write_horse_domain_audit(
    p_horse_id,actor_profile,p_request_id,'canonical_feeding_plan_retired',
    array['feeding']::text[]
  );
  return result;
end;
$$;

revoke all on function private.c0091_legacy_stable_context(uuid)
  from public,anon,authenticated,service_role;
revoke all on function private.c0091_write_horse_domain_audit(uuid,uuid,uuid,text,text[])
  from public,anon,authenticated,service_role;

revoke all on function public.list_canonical_horse_schedule(uuid,timestamptz,timestamptz)
  from public,anon,authenticated,service_role;
revoke all on function public.list_my_canonical_horse_schedule(timestamptz,timestamptz)
  from public,anon,authenticated,service_role;
revoke all on function public.upsert_canonical_horse_schedule_item(
  uuid,uuid,bigint,text,text,text,text,timestamptz,timestamptz,text,text,text,uuid
) from public,anon,authenticated,service_role;
revoke all on function public.get_canonical_horse_feeding(uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.create_canonical_horse_feeding_plan(
  uuid,text,text,date,date,text,uuid
) from public,anon,authenticated,service_role;
revoke all on function public.upsert_canonical_horse_feeding_item(
  uuid,uuid,uuid,bigint,text,text,text,text,numeric,text,text,text,time,smallint[],integer,text,text,uuid
) from public,anon,authenticated,service_role;
revoke all on function public.transition_canonical_horse_feeding_version(
  uuid,uuid,bigint,text,uuid
) from public,anon,authenticated,service_role;
revoke all on function public.retire_canonical_horse_feeding_plan(
  uuid,uuid,bigint,uuid
) from public,anon,authenticated,service_role;

grant execute on function public.list_canonical_horse_schedule(uuid,timestamptz,timestamptz)
  to authenticated;
grant execute on function public.list_my_canonical_horse_schedule(timestamptz,timestamptz)
  to authenticated;
grant execute on function public.upsert_canonical_horse_schedule_item(
  uuid,uuid,bigint,text,text,text,text,timestamptz,timestamptz,text,text,text,uuid
) to authenticated;
grant execute on function public.get_canonical_horse_feeding(uuid)
  to authenticated;
grant execute on function public.create_canonical_horse_feeding_plan(
  uuid,text,text,date,date,text,uuid
) to authenticated;
grant execute on function public.upsert_canonical_horse_feeding_item(
  uuid,uuid,uuid,bigint,text,text,text,text,numeric,text,text,text,time,smallint[],integer,text,text,uuid
) to authenticated;
grant execute on function public.transition_canonical_horse_feeding_version(
  uuid,uuid,bigint,text,uuid
) to authenticated;
grant execute on function public.retire_canonical_horse_feeding_plan(
  uuid,uuid,bigint,uuid
) to authenticated;

comment on function public.upsert_canonical_horse_schedule_item(
  uuid,uuid,bigint,text,text,text,text,timestamptz,timestamptz,text,text,text,uuid
) is 'C-009.1 canonical horse Planning mutation; stable context is server-derived compatibility metadata only.';
comment on function public.get_canonical_horse_feeding(uuid) is
  'C-009.1 horse-scoped Feeding projection; temporary active plans override but never overwrite the base plan.';

commit;
