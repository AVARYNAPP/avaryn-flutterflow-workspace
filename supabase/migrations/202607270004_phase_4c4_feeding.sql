begin;

create table public.feeding_plans (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  horse_id uuid not null,
  plan_type text not null check (plan_type in ('standard', 'temporary')),
  name text not null check (length(btrim(name)) between 1 and 160),
  status text not null default 'draft'
    check (status in ('draft', 'active', 'retired')),
  effective_from date not null,
  effective_until date,
  active_version_id uuid,
  row_version bigint not null default 1 check (row_version > 0),
  created_by_user_id uuid not null references auth.users (id),
  created_request_id uuid not null,
  last_mutated_by_user_id uuid not null references auth.users (id),
  last_mutation_request_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  retired_at timestamptz,
  constraint feeding_plans_stable_and_id_unique unique (stable_id, id),
  constraint feeding_plans_scope_unique unique (stable_id, id, horse_id),
  constraint feeding_plans_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint feeding_plans_created_request_unique
    unique (created_by_user_id, created_request_id),
  constraint feeding_plans_window
    check (
      effective_until is null or effective_until >= effective_from
    ),
  constraint feeding_plans_temporary_window
    check (plan_type <> 'temporary' or effective_until is not null),
  constraint feeding_plans_lifecycle
    check (
      (
        status = 'draft'
        and active_version_id is null
        and retired_at is null
      )
      or (
        status = 'active'
        and active_version_id is not null
        and retired_at is null
      )
      or (
        status = 'retired'
        and retired_at is not null
      )
    )
);

create index feeding_plans_horse_status
  on public.feeding_plans (
    horse_id,
    status,
    plan_type,
    effective_from,
    effective_until,
    id
  );

create table public.feeding_plan_versions (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  feeding_plan_id uuid not null,
  version_number integer not null check (version_number > 0),
  status text not null default 'draft'
    check (status in ('draft', 'approved', 'superseded')),
  source_kind text not null
    check (source_kind in ('user', 'professional', 'verified_template')),
  source_reference text
    check (
      source_reference is null
      or length(btrim(source_reference)) between 1 and 300
    ),
  change_reason text not null
    check (length(btrim(change_reason)) between 1 and 500),
  approved_by_user_id uuid references auth.users (id),
  approved_at timestamptz,
  row_version bigint not null default 1 check (row_version > 0),
  created_by_user_id uuid not null references auth.users (id),
  created_request_id uuid not null,
  last_mutated_by_user_id uuid not null references auth.users (id),
  last_mutation_request_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint feeding_plan_versions_stable_and_id_unique
    unique (stable_id, id),
  constraint feeding_plan_versions_scope_unique
    unique (stable_id, feeding_plan_id, id),
  constraint feeding_plan_versions_number_unique
    unique (feeding_plan_id, version_number),
  constraint feeding_plan_versions_plan_fk
    foreign key (stable_id, feeding_plan_id)
    references public.feeding_plans (stable_id, id),
  constraint feeding_plan_versions_created_request_unique
    unique (created_by_user_id, created_request_id),
  constraint feeding_plan_versions_approval_shape
    check (
      (
        status = 'draft'
        and approved_by_user_id is null
        and approved_at is null
      )
      or (
        status in ('approved', 'superseded')
        and approved_by_user_id is not null
        and approved_at is not null
      )
    ),
  constraint feeding_plan_versions_source_shape
    check (
      source_kind = 'user'
      or source_reference is not null
    )
);

alter table public.feeding_plans
  add constraint feeding_plans_active_version_fk
  foreign key (stable_id, id, active_version_id)
  references public.feeding_plan_versions (
    stable_id,
    feeding_plan_id,
    id
  );

create index feeding_plan_versions_plan_status
  on public.feeding_plan_versions (
    feeding_plan_id,
    status,
    version_number desc,
    id
  );

create table public.feeding_plan_items (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  feeding_plan_version_id uuid not null,
  product_brand text
    check (
      product_brand is null
      or length(btrim(product_brand)) between 1 and 160
    ),
  product_name text not null
    check (length(btrim(product_name)) between 1 and 200),
  product_variant text
    check (
      product_variant is null
      or length(btrim(product_variant)) between 1 and 160
    ),
  source_status text not null
    check (
      source_status in (
        'user_entered',
        'professional_unverified',
        'verified_template',
        'commercial'
      )
    ),
  planned_quantity numeric(14, 4) not null check (planned_quantity > 0),
  unit_code text not null
    check (unit_code in ('g', 'kg', 'ml', 'l', 'scoop', 'portion', 'piece')),
  offering_method text not null
    check (
      offering_method in (
        'bucket',
        'manger',
        'hay_net',
        'pasture',
        'hand',
        'other'
      )
    ),
  round_code text not null
    check (length(btrim(round_code)) between 1 and 80),
  local_time time not null,
  weekdays smallint[],
  interval_days integer check (interval_days between 1 and 365),
  override_key text not null
    check (length(btrim(override_key)) between 1 and 160),
  default_stable_member_id uuid,
  batch_lot text
    check (
      batch_lot is null
      or length(btrim(batch_lot)) between 1 and 160
    ),
  expires_on date,
  instruction text
    check (
      instruction is null
      or length(btrim(instruction)) between 1 and 1000
    ),
  row_version bigint not null default 1 check (row_version > 0),
  created_by_user_id uuid not null references auth.users (id),
  created_request_id uuid not null,
  last_mutated_by_user_id uuid not null references auth.users (id),
  last_mutation_request_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint feeding_plan_items_stable_and_id_unique
    unique (stable_id, id),
  constraint feeding_plan_items_scope_unique
    unique (stable_id, feeding_plan_version_id, id),
  constraint feeding_plan_items_version_fk
    foreign key (stable_id, feeding_plan_version_id)
    references public.feeding_plan_versions (stable_id, id),
  constraint feeding_plan_items_member_fk
    foreign key (stable_id, default_stable_member_id)
    references public.stable_members (stable_id, id),
  constraint feeding_plan_items_created_request_unique
    unique (created_by_user_id, created_request_id),
  constraint feeding_plan_items_recurrence_shape
    check (
      not (weekdays is not null and interval_days is not null)
      and (
        weekdays is null
        or (
          cardinality(weekdays) between 1 and 7
          and weekdays <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
        )
      )
    )
);

create unique index feeding_plan_items_override_key_unique
  on public.feeding_plan_items (feeding_plan_version_id, override_key);

create index feeding_plan_items_version_round
  on public.feeding_plan_items (
    feeding_plan_version_id,
    round_code,
    local_time,
    id
  );

create table public.feeding_occurrences (
  schedule_item_id uuid primary key,
  stable_id uuid not null references public.stables (id),
  feeding_plan_version_id uuid not null,
  feeding_plan_item_id uuid not null,
  occurrence_local_date date not null,
  planned_quantity numeric(14, 4) not null check (planned_quantity > 0),
  unit_code text not null
    check (unit_code in ('g', 'kg', 'ml', 'l', 'scoop', 'portion', 'piece')),
  offering_method text not null
    check (
      offering_method in (
        'bucket',
        'manger',
        'hay_net',
        'pasture',
        'hand',
        'other'
      )
    ),
  override_key text,
  source_plan_type text not null
    check (source_plan_type in ('standard', 'temporary')),
  source_status text not null
    check (
      source_status in (
        'user_entered',
        'professional_unverified',
        'verified_template',
        'commercial'
      )
    ),
  created_at timestamptz not null default timezone('utc', now()),
  constraint feeding_occurrences_stable_and_item_unique
    unique (stable_id, schedule_item_id),
  constraint feeding_occurrences_version_item_date_unique
    unique (
      feeding_plan_version_id,
      feeding_plan_item_id,
      occurrence_local_date
    ),
  constraint feeding_occurrences_schedule_item_fk
    foreign key (stable_id, schedule_item_id)
    references public.schedule_items (stable_id, id),
  constraint feeding_occurrences_version_fk
    foreign key (stable_id, feeding_plan_version_id)
    references public.feeding_plan_versions (stable_id, id),
  constraint feeding_occurrences_plan_item_fk
    foreign key (
      stable_id,
      feeding_plan_version_id,
      feeding_plan_item_id
    )
    references public.feeding_plan_items (
      stable_id,
      feeding_plan_version_id,
      id
    )
);

create index feeding_occurrences_version_date
  on public.feeding_occurrences (
    feeding_plan_version_id,
    occurrence_local_date,
    schedule_item_id
  );

create table public.feeding_execution_details (
  execution_id uuid primary key,
  stable_id uuid not null references public.stables (id),
  schedule_item_id uuid not null,
  actual_quantity numeric(14, 4) not null check (actual_quantity >= 0),
  unit_code text not null
    check (unit_code in ('g', 'kg', 'ml', 'l', 'scoop', 'portion', 'piece')),
  remaining_quantity numeric(14, 4)
    check (remaining_quantity is null or remaining_quantity >= 0),
  deviation_code text not null
    check (
      deviation_code in (
        'none',
        'less',
        'more',
        'refused',
        'spilled',
        'substituted',
        'other'
      )
    ),
  observation text
    check (
      observation is null
      or length(btrim(observation)) between 1 and 1000
    ),
  batch_lot text
    check (
      batch_lot is null
      or length(btrim(batch_lot)) between 1 and 160
    ),
  created_at timestamptz not null default timezone('utc', now()),
  constraint feeding_execution_details_execution_fk
    foreign key (stable_id, schedule_item_id, execution_id)
    references public.schedule_executions (
      stable_id,
      schedule_item_id,
      id
    ),
  constraint feeding_execution_details_occurrence_fk
    foreign key (stable_id, schedule_item_id)
    references public.feeding_occurrences (stable_id, schedule_item_id)
);

create table public.feeding_change_events (
  id bigint generated always as identity primary key,
  stable_id uuid not null references public.stables (id),
  horse_id uuid not null,
  feeding_plan_id uuid,
  feeding_plan_version_id uuid,
  feeding_plan_item_id uuid,
  schedule_item_id uuid,
  execution_id uuid,
  actor_user_id uuid not null references auth.users (id),
  actor_membership_id uuid not null,
  request_id uuid not null,
  event_type text not null
    check (
      event_type in (
        'feeding_plan_created',
        'feeding_plan_version_created',
        'feeding_plan_item_upserted',
        'feeding_plan_version_approved',
        'feeding_plan_version_activated',
        'feeding_plan_retired',
        'feeding_execution_recorded',
        'feeding_execution_corrected'
      )
    ),
  row_version bigint check (row_version is null or row_version > 0),
  reason text
    check (reason is null or length(btrim(reason)) between 1 and 500),
  created_at timestamptz not null default timezone('utc', now()),
  constraint feeding_change_events_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint feeding_change_events_actor_membership_fk
    foreign key (stable_id, actor_membership_id)
    references public.stable_memberships (stable_id, id),
  constraint feeding_change_events_plan_fk
    foreign key (stable_id, feeding_plan_id)
    references public.feeding_plans (stable_id, id),
  constraint feeding_change_events_version_fk
    foreign key (stable_id, feeding_plan_version_id)
    references public.feeding_plan_versions (stable_id, id),
  constraint feeding_change_events_item_fk
    foreign key (stable_id, feeding_plan_item_id)
    references public.feeding_plan_items (stable_id, id),
  constraint feeding_change_events_schedule_item_fk
    foreign key (stable_id, schedule_item_id)
    references public.schedule_items (stable_id, id),
  constraint feeding_change_events_execution_fk
    foreign key (stable_id, schedule_item_id, execution_id)
    references public.schedule_executions (
      stable_id,
      schedule_item_id,
      id
    ),
  constraint feeding_change_events_target
    check (
      feeding_plan_id is not null
      or feeding_plan_version_id is not null
      or feeding_plan_item_id is not null
      or schedule_item_id is not null
      or execution_id is not null
    )
);

create index feeding_change_events_stable_created
  on public.feeding_change_events (stable_id, created_at, id);

create index feeding_change_events_horse_created
  on public.feeding_change_events (horse_id, created_at, id);

create table private.feeding_mutation_receipts (
  actor_user_id uuid not null references auth.users (id),
  request_id uuid not null,
  stable_id uuid not null references public.stables (id),
  operation_name text not null
    check (
      operation_name in (
        'create_feeding_plan',
        'create_feeding_plan_version',
        'upsert_feeding_plan_item',
        'approve_feeding_plan_version',
        'activate_feeding_plan_version',
        'retire_feeding_plan',
        'record_feeding_execution'
      )
    ),
  target_type text not null
    check (
      target_type in (
        'feeding_plan',
        'feeding_plan_version',
        'feeding_plan_item',
        'schedule_execution'
      )
    ),
  target_id uuid,
  payload_hash bytea not null check (octet_length(payload_hash) = 32),
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (actor_user_id, request_id)
);

create or replace function private.touch_feeding_plan()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.name := btrim(new.name);
  new.updated_at := timezone('utc', pg_catalog.now());
  if tg_op = 'UPDATE' then
    new.row_version := old.row_version + 1;
  end if;
  return new;
end;
$$;

create trigger feeding_plans_touch_before_write
before insert or update on public.feeding_plans
for each row execute function private.touch_feeding_plan();

create or replace function private.touch_feeding_plan_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.source_reference := nullif(btrim(new.source_reference), '');
  new.change_reason := btrim(new.change_reason);
  if tg_op = 'UPDATE' and old.status <> 'draft' then
    if not (
      old.status = 'approved'
      and new.status = 'superseded'
      and new.stable_id = old.stable_id
      and new.feeding_plan_id = old.feeding_plan_id
      and new.version_number = old.version_number
      and new.source_kind = old.source_kind
      and new.source_reference is not distinct from old.source_reference
      and new.change_reason = old.change_reason
      and new.approved_by_user_id = old.approved_by_user_id
      and new.approved_at = old.approved_at
      and new.created_by_user_id = old.created_by_user_id
      and new.created_request_id = old.created_request_id
    )
    then
      raise exception using
        errcode = '55000',
        message = 'FEEDING_VERSION_IMMUTABLE';
    end if;
  end if;
  new.updated_at := timezone('utc', pg_catalog.now());
  if tg_op = 'UPDATE' then
    new.row_version := old.row_version + 1;
  end if;
  return new;
end;
$$;

create trigger feeding_plan_versions_touch_before_write
before insert or update on public.feeding_plan_versions
for each row execute function private.touch_feeding_plan_version();

create or replace function private.guard_feeding_plan_item_draft()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_version_id uuid := case
    when tg_op = 'DELETE' then old.feeding_plan_version_id
    else new.feeding_plan_version_id
  end;
begin
  if not exists (
    select 1
    from public.feeding_plan_versions version
    where version.id = target_version_id
      and version.status = 'draft'
  )
  then
    raise exception using
      errcode = '55000',
      message = 'FEEDING_VERSION_IMMUTABLE';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

create trigger feeding_plan_items_draft_guard
before insert or update or delete on public.feeding_plan_items
for each row execute function private.guard_feeding_plan_item_draft();

create or replace function private.touch_feeding_plan_item()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.product_brand := nullif(btrim(new.product_brand), '');
  new.product_name := btrim(new.product_name);
  new.product_variant := nullif(btrim(new.product_variant), '');
  new.round_code := btrim(new.round_code);
  new.override_key := nullif(btrim(new.override_key), '');
  new.batch_lot := nullif(btrim(new.batch_lot), '');
  new.instruction := nullif(btrim(new.instruction), '');
  if new.weekdays is not null then
    select array_agg(day_value order by day_value)::smallint[]
      into new.weekdays
    from (
      select distinct unnest(new.weekdays) as day_value
    ) normalized_days;
  end if;
  new.updated_at := timezone('utc', pg_catalog.now());
  if tg_op = 'UPDATE' then
    new.row_version := old.row_version + 1;
  end if;
  return new;
end;
$$;

create trigger feeding_plan_items_touch_before_write
before insert or update on public.feeding_plan_items
for each row execute function private.touch_feeding_plan_item();

create trigger feeding_occurrences_append_only
before update or delete on public.feeding_occurrences
for each row execute function private.prevent_schedule_append_only_mutation();

create trigger feeding_execution_details_append_only
before update or delete on public.feeding_execution_details
for each row execute function private.prevent_schedule_append_only_mutation();

create trigger feeding_change_events_append_only
before update or delete on public.feeding_change_events
for each row execute function private.prevent_schedule_append_only_mutation();

create or replace function private.feeding_receipt_result(
  p_actor_user_id uuid,
  p_request_id uuid,
  p_operation_name text,
  p_payload_hash bytea
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_receipt private.feeding_mutation_receipts%rowtype;
begin
  select * into existing_receipt
  from private.feeding_mutation_receipts receipt
  where receipt.actor_user_id = p_actor_user_id
    and receipt.request_id = p_request_id;

  if existing_receipt.request_id is null then return null; end if;
  if existing_receipt.operation_name <> p_operation_name
    or existing_receipt.payload_hash <> p_payload_hash
  then
    raise exception using
      errcode = '22023',
      message = 'REQUEST_ID_REUSED';
  end if;
  return existing_receipt.result || jsonb_build_object('idempotent', true);
end;
$$;

create or replace function private.lock_feeding_context(
  p_stable_id uuid,
  p_horse_id uuid
)
returns public.stable_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  actor_membership public.stable_memberships%rowtype;
  target_horse public.horses%rowtype;
begin
  if actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'AUTHENTICATION_REQUIRED';
  end if;

  select * into actor_membership
  from public.stable_memberships membership
  where membership.stable_id = p_stable_id
    and membership.user_id = actor_id
    and membership.status = 'active'
  for share;
  if actor_membership.id is null then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;

  perform 1
  from public.horse_access_grants grant_row
  where grant_row.horse_id = p_horse_id
    and grant_row.category = 'horse.nutrition'
    and grant_row.status = 'active'
  order by grant_row.id
  for share;

  select * into target_horse
  from public.horses horse
  where horse.id = p_horse_id
    and horse.stable_id = p_stable_id
  for share;

  if target_horse.id is null
    or target_horse.status <> 'active'
    or not exists (
      select 1
      from public.stables stable
      where stable.id = p_stable_id
        and stable.status = 'active'
    )
  then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;
  return actor_membership;
end;
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
  select
    p_membership.role = 'owner'
    or private.has_horse_capability(
      p_horse_id,
      'horse.nutrition',
      'edit'
    )
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
  select
    p_membership.role = 'owner'
    or private.has_horse_capability(
      p_horse_id,
      'horse.nutrition',
      'manage'
    )
$$;

create or replace function private.write_feeding_change_event(
  p_stable_id uuid,
  p_horse_id uuid,
  p_feeding_plan_id uuid,
  p_feeding_plan_version_id uuid,
  p_feeding_plan_item_id uuid,
  p_schedule_item_id uuid,
  p_execution_id uuid,
  p_actor_membership_id uuid,
  p_request_id uuid,
  p_event_type text,
  p_row_version bigint,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_event_type not in (
    'feeding_plan_created',
    'feeding_plan_version_created',
    'feeding_plan_item_upserted',
    'feeding_plan_version_approved',
    'feeding_plan_version_activated',
    'feeding_plan_retired',
    'feeding_execution_recorded',
    'feeding_execution_corrected'
  ) or p_stable_id is null
    or p_horse_id is null
    or p_actor_membership_id is null
    or p_request_id is null
    or (
      p_feeding_plan_id is null
      and p_feeding_plan_version_id is null
      and p_feeding_plan_item_id is null
      and p_schedule_item_id is null
      and p_execution_id is null
    )
    or not exists (
      select 1
      from public.stable_memberships membership
      where membership.id = p_actor_membership_id
        and membership.stable_id = p_stable_id
        and membership.user_id = auth.uid()
        and membership.status = 'active'
    )
  then
    raise exception using
      errcode = '22023',
      message = 'FEEDING_EVENT_CORRELATION_REQUIRED';
  end if;

  insert into public.feeding_change_events (
    stable_id,
    horse_id,
    feeding_plan_id,
    feeding_plan_version_id,
    feeding_plan_item_id,
    schedule_item_id,
    execution_id,
    actor_user_id,
    actor_membership_id,
    request_id,
    event_type,
    row_version,
    reason
  )
  values (
    p_stable_id,
    p_horse_id,
    p_feeding_plan_id,
    p_feeding_plan_version_id,
    p_feeding_plan_item_id,
    p_schedule_item_id,
    p_execution_id,
    auth.uid(),
    p_actor_membership_id,
    p_request_id,
    p_event_type,
    p_row_version,
    nullif(btrim(p_reason), '')
  );
end;
$$;

create or replace function private.feeding_item_matches_date(
  p_item public.feeding_plan_items,
  p_effective_from date,
  p_local_date date
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when p_item.weekdays is not null
      then extract(isodow from p_local_date)::smallint
        = any(p_item.weekdays)
    when p_item.interval_days is not null
      then mod(p_local_date - p_effective_from, p_item.interval_days) = 0
    else true
  end
$$;

create or replace function public.create_feeding_plan(
  p_horse_id uuid,
  p_plan_type text,
  p_name text,
  p_effective_from date,
  p_effective_until date,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  actor_membership public.stable_memberships%rowtype;
  normalized_name text := btrim(coalesce(p_name, ''));
  payload_hash bytea;
  receipt_result jsonb;
  created_plan public.feeding_plans%rowtype;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_plan_type not in ('standard', 'temporary')
    or length(normalized_name) not between 1 and 160
    or p_effective_from is null
    or (
      p_effective_until is not null
      and p_effective_until < p_effective_from
    )
    or (p_plan_type = 'temporary' and p_effective_until is null)
  then
    raise exception using
      errcode = '22023',
      message = 'INVALID_FEEDING_PLAN';
  end if;

  select horse.stable_id into target_stable_id
  from public.horses horse
  where horse.id = p_horse_id;
  if target_stable_id is null then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;

  actor_membership := private.lock_feeding_context(
    target_stable_id,
    p_horse_id
  );
  if not private.feeding_membership_can_edit(
    actor_membership,
    p_horse_id
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'horse_id', p_horse_id,
      'plan_type', p_plan_type,
      'name', normalized_name,
      'effective_from', p_effective_from,
      'effective_until', p_effective_until
    )
  );
  receipt_result := private.feeding_receipt_result(
    actor_id,
    p_request_id,
    'create_feeding_plan',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  insert into public.feeding_plans (
    stable_id,
    horse_id,
    plan_type,
    name,
    effective_from,
    effective_until,
    created_by_user_id,
    created_request_id,
    last_mutated_by_user_id,
    last_mutation_request_id
  )
  values (
    target_stable_id,
    p_horse_id,
    p_plan_type,
    normalized_name,
    p_effective_from,
    p_effective_until,
    actor_id,
    p_request_id,
    actor_id,
    p_request_id
  )
  returning * into created_plan;

  perform private.write_feeding_change_event(
    created_plan.stable_id,
    created_plan.horse_id,
    created_plan.id,
    null,
    null,
    null,
    null,
    actor_membership.id,
    p_request_id,
    'feeding_plan_created',
    created_plan.row_version
  );

  safe_result := jsonb_build_object(
    'feeding_plan_id', created_plan.id,
    'row_version', created_plan.row_version,
    'status', created_plan.status,
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
    created_plan.stable_id,
    'create_feeding_plan',
    'feeding_plan',
    created_plan.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.create_feeding_plan_version(
  p_feeding_plan_id uuid,
  p_source_kind text,
  p_source_reference text,
  p_change_reason text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  target_horse_id uuid;
  actor_membership public.stable_memberships%rowtype;
  target_plan public.feeding_plans%rowtype;
  created_version public.feeding_plan_versions%rowtype;
  normalized_reference text := nullif(btrim(p_source_reference), '');
  normalized_reason text := btrim(coalesce(p_change_reason, ''));
  next_version integer;
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_source_kind <> 'user'
    or normalized_reference is not null
    or length(normalized_reason) not between 1 and 500
  then
    raise exception using
      errcode = '22023',
      message = 'INVALID_FEEDING_VERSION_SOURCE';
  end if;

  select plan.stable_id, plan.horse_id
    into target_stable_id, target_horse_id
  from public.feeding_plans plan
  where plan.id = p_feeding_plan_id;
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

  select * into target_plan
  from public.feeding_plans plan
  where plan.id = p_feeding_plan_id
    and plan.stable_id = target_stable_id
  for update;
  if target_plan.id is null then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'feeding_plan_id', p_feeding_plan_id,
      'source_kind', p_source_kind,
      'source_reference', normalized_reference,
      'change_reason', normalized_reason
    )
  );
  receipt_result := private.feeding_receipt_result(
    actor_id,
    p_request_id,
    'create_feeding_plan_version',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;
  if target_plan.status = 'retired' then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;

  select coalesce(max(version.version_number), 0) + 1
    into next_version
  from public.feeding_plan_versions version
  where version.feeding_plan_id = target_plan.id;

  insert into public.feeding_plan_versions (
    stable_id,
    feeding_plan_id,
    version_number,
    source_kind,
    source_reference,
    change_reason,
    created_by_user_id,
    created_request_id,
    last_mutated_by_user_id,
    last_mutation_request_id
  )
  values (
    target_plan.stable_id,
    target_plan.id,
    next_version,
    p_source_kind,
    normalized_reference,
    normalized_reason,
    actor_id,
    p_request_id,
    actor_id,
    p_request_id
  )
  returning * into created_version;

  perform private.write_feeding_change_event(
    target_plan.stable_id,
    target_plan.horse_id,
    target_plan.id,
    created_version.id,
    null,
    null,
    null,
    actor_membership.id,
    p_request_id,
    'feeding_plan_version_created',
    created_version.row_version,
    null
  );

  safe_result := jsonb_build_object(
    'feeding_plan_version_id', created_version.id,
    'feeding_plan_id', target_plan.id,
    'version_number', created_version.version_number,
    'row_version', created_version.row_version,
    'status', created_version.status,
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
    target_plan.stable_id,
    'create_feeding_plan_version',
    'feeding_plan_version',
    created_version.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.upsert_feeding_plan_item(
  p_feeding_plan_version_id uuid,
  p_feeding_plan_item_id uuid,
  p_expected_row_version bigint,
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
  target_stable_id uuid;
  target_horse_id uuid;
  actor_membership public.stable_memberships%rowtype;
  target_plan public.feeding_plans%rowtype;
  target_version public.feeding_plan_versions%rowtype;
  target_item public.feeding_plan_items%rowtype;
  normalized_brand text := nullif(btrim(p_product_brand), '');
  normalized_name text := btrim(coalesce(p_product_name, ''));
  normalized_variant text := nullif(btrim(p_product_variant), '');
  normalized_round text := btrim(coalesce(p_round_code, ''));
  normalized_override text := nullif(btrim(p_override_key), '');
  normalized_batch text := nullif(btrim(p_batch_lot), '');
  normalized_instruction text := nullif(btrim(p_instruction), '');
  normalized_weekdays smallint[];
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_weekdays is not null then
    select array_agg(day_value order by day_value)::smallint[]
      into normalized_weekdays
    from (
      select distinct unnest(p_weekdays) as day_value
    ) normalized_days;
  end if;
  if length(normalized_name) not between 1 and 200
    or (
      normalized_brand is not null
      and length(normalized_brand) > 160
    )
    or (
      normalized_variant is not null
      and length(normalized_variant) > 160
    )
    or p_source_status not in (
      'user_entered',
      'professional_unverified',
      'commercial'
    )
    or p_planned_quantity is null
    or p_planned_quantity <= 0
    or p_unit_code not in ('g', 'kg', 'ml', 'l', 'scoop', 'portion', 'piece')
    or p_offering_method not in (
      'bucket', 'manger', 'hay_net', 'pasture', 'hand', 'other'
    )
    or length(normalized_round) not between 1 and 80
    or p_local_time is null
    or (normalized_weekdays is not null and p_interval_days is not null)
    or (
      normalized_weekdays is not null
      and (
        cardinality(normalized_weekdays) not between 1 and 7
        or not (
          normalized_weekdays
          <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
        )
      )
    )
    or (
      p_interval_days is not null
      and p_interval_days not between 1 and 365
    )
    or (
      normalized_override is not null
      and length(normalized_override) > 160
    )
    or (normalized_batch is not null and length(normalized_batch) > 160)
    or (
      normalized_instruction is not null
      and length(normalized_instruction) > 1000
    )
  then
    raise exception using
      errcode = '22023',
      message = 'INVALID_FEEDING_PLAN_ITEM';
  end if;

  select version.stable_id, plan.horse_id
    into target_stable_id, target_horse_id
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

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(target_horse_id::text, 404)
  );
  perform 1
  from public.feeding_plans plan
  where plan.horse_id = target_horse_id
  order by plan.id
  for update;

  select * into target_version
  from public.feeding_plan_versions version
  where version.id = p_feeding_plan_version_id
    and version.stable_id = target_stable_id
  for update;
  select * into target_plan
  from public.feeding_plans plan
  where plan.id = target_version.feeding_plan_id
    and plan.stable_id = target_stable_id;
  if target_version.id is null or target_plan.id is null then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'feeding_plan_version_id', p_feeding_plan_version_id,
      'feeding_plan_item_id', p_feeding_plan_item_id,
      'expected_row_version', p_expected_row_version,
      'product_brand', normalized_brand,
      'product_name', normalized_name,
      'product_variant', normalized_variant,
      'source_status', p_source_status,
      'planned_quantity', p_planned_quantity,
      'unit_code', p_unit_code,
      'offering_method', p_offering_method,
      'round_code', normalized_round,
      'local_time', p_local_time,
      'weekdays', normalized_weekdays,
      'interval_days', p_interval_days,
      'override_key', normalized_override,
      'default_stable_member_id', p_default_stable_member_id,
      'batch_lot', normalized_batch,
      'expires_on', p_expires_on,
      'instruction', normalized_instruction
    )
  );
  receipt_result := private.feeding_receipt_result(
    actor_id,
    p_request_id,
    'upsert_feeding_plan_item',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;
  if target_version.status <> 'draft' or target_plan.status = 'retired' then
    raise exception using
      errcode = '55000',
      message = 'FEEDING_VERSION_IMMUTABLE';
  end if;
  if normalized_override is null then
    raise exception using
      errcode = '22023',
      message = 'FEEDING_OVERRIDE_KEY_REQUIRED';
  end if;
  if p_default_stable_member_id is not null and not exists (
    select 1
    from public.stable_members stable_member
    where stable_member.id = p_default_stable_member_id
      and stable_member.stable_id = target_stable_id
      and stable_member.status = 'active'
  )
  then
    raise exception using
      errcode = '42501',
      message = 'STABLE_MEMBER_UNAVAILABLE';
  end if;

  if p_feeding_plan_item_id is null then
    if p_expected_row_version is not null then
      raise exception using errcode = '22023', message = 'INVALID_ROW_VERSION';
    end if;
    insert into public.feeding_plan_items (
      stable_id,
      feeding_plan_version_id,
      product_brand,
      product_name,
      product_variant,
      source_status,
      planned_quantity,
      unit_code,
      offering_method,
      round_code,
      local_time,
      weekdays,
      interval_days,
      override_key,
      default_stable_member_id,
      batch_lot,
      expires_on,
      instruction,
      created_by_user_id,
      created_request_id,
      last_mutated_by_user_id,
      last_mutation_request_id
    )
    values (
      target_stable_id,
      target_version.id,
      normalized_brand,
      normalized_name,
      normalized_variant,
      p_source_status,
      p_planned_quantity,
      p_unit_code,
      p_offering_method,
      normalized_round,
      p_local_time,
      normalized_weekdays,
      p_interval_days,
      normalized_override,
      p_default_stable_member_id,
      normalized_batch,
      p_expires_on,
      normalized_instruction,
      actor_id,
      p_request_id,
      actor_id,
      p_request_id
    )
    returning * into target_item;
  else
    select * into target_item
    from public.feeding_plan_items item
    where item.id = p_feeding_plan_item_id
      and item.stable_id = target_stable_id
      and item.feeding_plan_version_id = target_version.id
    for update;
    if target_item.id is null then
      raise exception using
        errcode = '42501',
        message = 'NUTRITION_UNAVAILABLE';
    end if;
    if p_expected_row_version is null
      or target_item.row_version <> p_expected_row_version
    then
      raise exception using
        errcode = '40001',
        message = 'ROW_VERSION_CONFLICT';
    end if;
    update public.feeding_plan_items item
    set
      product_brand = normalized_brand,
      product_name = normalized_name,
      product_variant = normalized_variant,
      source_status = p_source_status,
      planned_quantity = p_planned_quantity,
      unit_code = p_unit_code,
      offering_method = p_offering_method,
      round_code = normalized_round,
      local_time = p_local_time,
      weekdays = normalized_weekdays,
      interval_days = p_interval_days,
      override_key = normalized_override,
      default_stable_member_id = p_default_stable_member_id,
      batch_lot = normalized_batch,
      expires_on = p_expires_on,
      instruction = normalized_instruction,
      last_mutated_by_user_id = actor_id,
      last_mutation_request_id = p_request_id
    where item.id = target_item.id
    returning * into target_item;
  end if;

  perform private.write_feeding_change_event(
    target_stable_id,
    target_horse_id,
    target_plan.id,
    target_version.id,
    target_item.id,
    null,
    null,
    actor_membership.id,
    p_request_id,
    'feeding_plan_item_upserted',
    target_item.row_version
  );
  safe_result := jsonb_build_object(
    'feeding_plan_item_id', target_item.id,
    'feeding_plan_version_id', target_version.id,
    'row_version', target_item.row_version,
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
    'upsert_feeding_plan_item',
    'feeding_plan_item',
    target_item.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.approve_feeding_plan_version(
  p_feeding_plan_version_id uuid,
  p_expected_row_version bigint,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  target_horse_id uuid;
  actor_membership public.stable_memberships%rowtype;
  target_plan public.feeding_plans%rowtype;
  target_version public.feeding_plan_versions%rowtype;
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_expected_row_version is null or p_expected_row_version < 1 then
    raise exception using errcode = '22023', message = 'ROW_VERSION_REQUIRED';
  end if;
  select version.stable_id, plan.horse_id
    into target_stable_id, target_horse_id
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
  if not private.feeding_membership_can_manage(
    actor_membership,
    target_horse_id
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(target_horse_id::text, 404)
  );
  perform 1
  from public.feeding_plans plan
  where plan.horse_id = target_horse_id
  order by plan.id
  for update;

  select * into target_version
  from public.feeding_plan_versions version
  where version.id = p_feeding_plan_version_id
    and version.stable_id = target_stable_id
  for update;
  select * into target_plan
  from public.feeding_plans plan
  where plan.id = target_version.feeding_plan_id
    and plan.stable_id = target_stable_id
  for share;
  if target_version.id is null or target_plan.id is null then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'feeding_plan_version_id', p_feeding_plan_version_id,
      'expected_row_version', p_expected_row_version
    )
  );
  receipt_result := private.feeding_receipt_result(
    actor_id,
    p_request_id,
    'approve_feeding_plan_version',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  if target_plan.status = 'retired'
    or target_version.status <> 'draft'
    or target_version.row_version <> p_expected_row_version
    or not exists (
      select 1
      from public.feeding_plan_items item
      where item.feeding_plan_version_id = target_version.id
    )
    or (
      target_plan.plan_type = 'temporary'
      and exists (
        select 1
        from public.feeding_plan_items item
        where item.feeding_plan_version_id = target_version.id
          and item.override_key is null
      )
    )
  then
    raise exception using
      errcode = '55000',
      message = 'FEEDING_VERSION_NOT_APPROVABLE';
  end if;

  update public.feeding_plan_versions version
  set
    status = 'approved',
    approved_by_user_id = actor_id,
    approved_at = timezone('utc', now()),
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where version.id = target_version.id
  returning * into target_version;

  perform private.write_feeding_change_event(
    target_stable_id,
    target_horse_id,
    target_plan.id,
    target_version.id,
    null,
    null,
    null,
    actor_membership.id,
    p_request_id,
    'feeding_plan_version_approved',
    target_version.row_version
  );
  safe_result := jsonb_build_object(
    'feeding_plan_version_id', target_version.id,
    'feeding_plan_id', target_plan.id,
    'row_version', target_version.row_version,
    'status', target_version.status,
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
    'approve_feeding_plan_version',
    'feeding_plan_version',
    target_version.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.activate_feeding_plan_version(
  p_feeding_plan_version_id uuid,
  p_expected_row_version bigint,
  p_through_local_date date,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  target_horse_id uuid;
  actor_membership public.stable_memberships%rowtype;
  target_plan public.feeding_plans%rowtype;
  target_version public.feeding_plan_versions%rowtype;
  prior_version_id uuid;
  standard_plan public.feeding_plans%rowtype;
  plan_item public.feeding_plan_items%rowtype;
  created_schedule_item public.schedule_items%rowtype;
  candidate_date date;
  batch_from date;
  batch_through date;
  stable_timezone text;
  occurrence_start timestamptz;
  occurrence_request_id uuid;
  assignment_request_id uuid;
  created_count integer := 0;
  cancelled_count integer := 0;
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
  instruction_snapshot text;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_expected_row_version is null
    or p_expected_row_version < 1
    or p_through_local_date is null
  then
    raise exception using
      errcode = '22023',
      message = 'INVALID_FEEDING_ACTIVATION';
  end if;

  select version.stable_id, plan.horse_id
    into target_stable_id, target_horse_id
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
  if not private.feeding_membership_can_manage(
    actor_membership,
    target_horse_id
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(target_horse_id::text, 404)
  );
  perform 1
  from public.feeding_plans plan
  where plan.horse_id = target_horse_id
  order by plan.id
  for update;

  select * into target_version
  from public.feeding_plan_versions version
  where version.id = p_feeding_plan_version_id
    and version.stable_id = target_stable_id
  for update;
  select * into target_plan
  from public.feeding_plans plan
  where plan.id = target_version.feeding_plan_id
    and plan.stable_id = target_stable_id
  for update;
  select stable.timezone into stable_timezone
  from public.stables stable
  where stable.id = target_stable_id;

  if target_version.id is null or target_plan.id is null then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'feeding_plan_version_id', p_feeding_plan_version_id,
      'expected_row_version', p_expected_row_version,
      'through_local_date', p_through_local_date
    )
  );
  receipt_result := private.feeding_receipt_result(
    actor_id,
    p_request_id,
    'activate_feeding_plan_version',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  if target_plan.status = 'retired'
    or target_version.status <> 'approved'
    or target_version.row_version <> p_expected_row_version
    or p_through_local_date < target_plan.effective_from
  then
    raise exception using
      errcode = '55000',
      message = 'FEEDING_VERSION_NOT_ACTIVATABLE';
  end if;

  if target_plan.plan_type = 'standard' then
    if exists (
      select 1
      from public.feeding_plans plan
      where plan.horse_id = target_plan.horse_id
        and plan.id <> target_plan.id
        and plan.plan_type = 'standard'
        and plan.status = 'active'
        and daterange(
          plan.effective_from,
          coalesce(plan.effective_until + 1, 'infinity'::date),
          '[)'
        ) && daterange(
          target_plan.effective_from,
          coalesce(target_plan.effective_until + 1, 'infinity'::date),
          '[)'
        )
    )
    then
      raise exception using
        errcode = '23P01',
        message = 'STANDARD_FEEDING_PLAN_OVERLAP';
    end if;
    if exists (
      select 1
      from public.feeding_plans plan
      where plan.horse_id = target_plan.horse_id
        and plan.plan_type = 'temporary'
        and plan.status = 'active'
        and daterange(
          plan.effective_from,
          plan.effective_until + 1,
          '[)'
        ) && daterange(
          target_plan.effective_from,
          coalesce(target_plan.effective_until + 1, 'infinity'::date),
          '[)'
        )
    )
    then
      raise exception using
        errcode = '55000',
        message = 'TEMPORARY_FEEDING_PLAN_ACTIVE';
    end if;
  else
    select * into standard_plan
    from public.feeding_plans plan
    where plan.horse_id = target_plan.horse_id
      and plan.plan_type = 'standard'
      and plan.status = 'active'
      and plan.effective_from <= target_plan.effective_from
      and (
        plan.effective_until is null
        or plan.effective_until >= target_plan.effective_until
      )
    order by plan.id
    limit 1;
    if standard_plan.id is null
      or exists (
        select 1
        from public.feeding_plan_items temporary_item
        where temporary_item.feeding_plan_version_id = target_version.id
          and (
            temporary_item.override_key is null
            or not exists (
              select 1
              from public.feeding_plan_items standard_item
              where standard_item.feeding_plan_version_id
                = standard_plan.active_version_id
                and standard_item.override_key
                  = temporary_item.override_key
            )
          )
      )
    then
      raise exception using
        errcode = '55000',
        message = 'TEMPORARY_OVERRIDE_NOT_EXPLICIT';
    end if;
    if exists (
      select 1
      from public.feeding_plans other_plan
      join public.feeding_plan_items other_item
        on other_item.feeding_plan_version_id = other_plan.active_version_id
      join public.feeding_plan_items target_item
        on target_item.feeding_plan_version_id = target_version.id
       and target_item.override_key = other_item.override_key
      where other_plan.horse_id = target_plan.horse_id
        and other_plan.id <> target_plan.id
        and other_plan.plan_type = 'temporary'
        and other_plan.status = 'active'
        and daterange(
          other_plan.effective_from,
          other_plan.effective_until + 1,
          '[)'
        ) && daterange(
          target_plan.effective_from,
          target_plan.effective_until + 1,
          '[)'
        )
    )
    then
      raise exception using
        errcode = '23P01',
        message = 'TEMPORARY_FEEDING_OVERRIDE_OVERLAP';
    end if;
  end if;

  prior_version_id := target_plan.active_version_id;
  if prior_version_id is distinct from target_version.id then
    if prior_version_id is not null then
      update public.feeding_plan_versions version
      set
        status = 'superseded',
        last_mutated_by_user_id = actor_id,
        last_mutation_request_id = p_request_id
      where version.id = prior_version_id
        and version.status = 'approved';
    end if;
    update public.feeding_plans plan
    set
      status = 'active',
      active_version_id = target_version.id,
      last_mutated_by_user_id = actor_id,
      last_mutation_request_id = p_request_id
    where plan.id = target_plan.id
    returning * into target_plan;

    with cancelled_items as (
      update public.schedule_items schedule_item
      set
        state = 'cancelled',
        state_reason = 'feeding_version_replaced',
        terminal_at = timezone('utc', now()),
        last_mutated_by_user_id = actor_id,
        last_mutation_request_id = p_request_id
      where schedule_item.id in (
        select occurrence.schedule_item_id
        from public.feeding_occurrences occurrence
        where occurrence.feeding_plan_version_id = prior_version_id
      )
        and schedule_item.source_local_date
          >= timezone(stable_timezone, pg_catalog.now())::date
        and schedule_item.state = 'planned'
        and not exists (
          select 1
          from public.schedule_executions execution
          where execution.schedule_item_id = schedule_item.id
        )
      returning schedule_item.id
    )
    select count(*) into cancelled_count from cancelled_items;
  end if;

  if target_plan.plan_type = 'temporary' then
    with cancelled_standard as (
      update public.schedule_items schedule_item
      set
        state = 'cancelled',
        state_reason = 'temporary_feeding_override',
        terminal_at = timezone('utc', now()),
        last_mutated_by_user_id = actor_id,
        last_mutation_request_id = p_request_id
      where schedule_item.id in (
        select occurrence.schedule_item_id
        from public.feeding_occurrences occurrence
        join public.feeding_plan_items target_item
          on target_item.feeding_plan_version_id = target_version.id
         and target_item.override_key = occurrence.override_key
        where occurrence.feeding_plan_version_id
          = standard_plan.active_version_id
          and occurrence.occurrence_local_date
            between target_plan.effective_from and target_plan.effective_until
      )
        and schedule_item.state = 'planned'
        and not exists (
          select 1
          from public.schedule_executions execution
          where execution.schedule_item_id = schedule_item.id
        )
      returning schedule_item.id
    )
    select cancelled_count + count(*)
      into cancelled_count
    from cancelled_standard;
  end if;

  update public.schedule_assignments assignment
  set
    status = 'cancelled',
    cancelled_at = timezone('utc', pg_catalog.now()),
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where assignment.schedule_item_id in (
    select schedule_item.id
    from public.schedule_items schedule_item
    where schedule_item.last_mutation_request_id = p_request_id
      and schedule_item.state = 'cancelled'
      and schedule_item.state_reason in (
        'feeding_version_replaced',
        'temporary_feeding_override'
      )
  )
    and assignment.status in ('assigned', 'accepted');

  select greatest(
    target_plan.effective_from,
    coalesce(
      (
        select max(
          (receipt.result ->> 'materialized_through_local_date')::date
        ) + 1
        from private.feeding_mutation_receipts receipt
        where receipt.operation_name = 'activate_feeding_plan_version'
          and receipt.target_type = 'feeding_plan_version'
          and receipt.target_id = target_version.id
      ),
      target_plan.effective_from
    )
  )
  into batch_from;
  if prior_version_id is not null then
    batch_from := greatest(
      batch_from,
      timezone(stable_timezone, pg_catalog.now())::date
    );
  end if;
  batch_through := least(
    p_through_local_date,
    batch_from + 89,
    coalesce(target_plan.effective_until, p_through_local_date)
  );

  if batch_from <= batch_through then
    for plan_item in
      select item.*
      from public.feeding_plan_items item
      where item.feeding_plan_version_id = target_version.id
      order by item.local_time, item.id
    loop
      for candidate_date in
        select generated_date::date
        from generate_series(
          batch_from,
          batch_through,
          interval '1 day'
        ) generated_date
      loop
        if private.feeding_item_matches_date(
          plan_item,
          target_plan.effective_from,
          candidate_date
        ) then
          if prior_version_id is not null and exists (
            select 1
            from public.feeding_occurrences prior_occurrence
            join public.schedule_items prior_schedule_item
              on prior_schedule_item.id = prior_occurrence.schedule_item_id
            where prior_occurrence.feeding_plan_version_id = prior_version_id
              and prior_occurrence.occurrence_local_date = candidate_date
              and prior_occurrence.override_key = plan_item.override_key
              and (
                prior_schedule_item.state in ('completed', 'skipped')
                or (
                  prior_schedule_item.state = 'cancelled'
                  and prior_schedule_item.state_reason
                    <> 'feeding_version_replaced'
                )
                or exists (
                  select 1
                  from public.schedule_executions prior_execution
                  where prior_execution.schedule_item_id
                    = prior_schedule_item.id
                )
              )
          )
          then
            continue;
          end if;
          if target_plan.plan_type = 'temporary' and exists (
            select 1
            from public.feeding_occurrences standard_occurrence
            join public.schedule_items standard_item
              on standard_item.id = standard_occurrence.schedule_item_id
            where standard_occurrence.feeding_plan_version_id
              = standard_plan.active_version_id
              and standard_occurrence.override_key = plan_item.override_key
              and standard_occurrence.occurrence_local_date = candidate_date
              and (
                standard_item.state in ('completed', 'skipped')
                or exists (
                  select 1
                  from public.schedule_executions execution
                  where execution.schedule_item_id = standard_item.id
                )
              )
          )
          then
            continue;
          end if;

          occurrence_start := pg_catalog.make_timestamptz(
            extract(year from candidate_date)::integer,
            extract(month from candidate_date)::integer,
            extract(day from candidate_date)::integer,
            extract(hour from plan_item.local_time)::integer,
            extract(minute from plan_item.local_time)::integer,
            extract(second from plan_item.local_time),
            stable_timezone
          );
          instruction_snapshot := left(
            concat_ws(
              ' · ',
              nullif(plan_item.product_brand, ''),
              plan_item.product_name,
              trim(to_char(plan_item.planned_quantity, 'FM9999999990.####'))
                || ' ' || plan_item.unit_code,
              plan_item.offering_method,
              plan_item.instruction
            ),
            2000
          );
          occurrence_request_id := private.schedule_derived_request_id(
            p_request_id,
            plan_item.id::text || ':' || candidate_date::text
          );
          created_schedule_item := null;
          insert into public.schedule_items (
            stable_id,
            horse_id,
            item_kind,
            data_category,
            title,
            instruction,
            priority,
            scheduled_start_at,
            source_timezone,
            source_local_date,
            source_local_time,
            state,
            created_by_user_id,
            created_request_id,
            last_mutated_by_user_id,
            last_mutation_request_id
          )
          values (
            target_plan.stable_id,
            target_plan.horse_id,
            'feeding',
            'horse.nutrition',
            left('Voeding · ' || plan_item.round_code, 160),
            instruction_snapshot,
            'normal',
            occurrence_start,
            stable_timezone,
            candidate_date,
            plan_item.local_time,
            'planned',
            actor_id,
            occurrence_request_id,
            actor_id,
            occurrence_request_id
          )
          on conflict (created_by_user_id, created_request_id)
          do nothing
          returning * into created_schedule_item;

          if created_schedule_item.id is not null then
            insert into public.feeding_occurrences (
              schedule_item_id,
              stable_id,
              feeding_plan_version_id,
              feeding_plan_item_id,
              occurrence_local_date,
              planned_quantity,
              unit_code,
              offering_method,
              override_key,
              source_plan_type,
              source_status
            )
            values (
              created_schedule_item.id,
              target_plan.stable_id,
              target_version.id,
              plan_item.id,
              candidate_date,
              plan_item.planned_quantity,
              plan_item.unit_code,
              plan_item.offering_method,
              plan_item.override_key,
              target_plan.plan_type,
              plan_item.source_status
            );
            if plan_item.default_stable_member_id is not null then
              assignment_request_id := private.schedule_derived_request_id(
                occurrence_request_id,
                'responsible-assignment'
              );
              insert into public.schedule_assignments (
                stable_id,
                schedule_item_id,
                stable_member_id,
                assignment_role,
                status,
                created_by_user_id,
                created_request_id,
                last_mutated_by_user_id,
                last_mutation_request_id
              )
              values (
                target_plan.stable_id,
                created_schedule_item.id,
                plan_item.default_stable_member_id,
                'responsible',
                'assigned',
                actor_id,
                assignment_request_id,
                actor_id,
                assignment_request_id
              );
            end if;
            perform private.write_schedule_change_event(
              target_plan.stable_id,
              null,
              created_schedule_item.id,
              null,
              null,
              actor_membership.id,
              occurrence_request_id,
              'schedule_occurrence_materialized',
              'horse.nutrition',
              created_schedule_item.row_version
            );
            created_count := created_count + 1;
          end if;
        end if;
      end loop;
    end loop;
  end if;

  perform private.write_feeding_change_event(
    target_plan.stable_id,
    target_plan.horse_id,
    target_plan.id,
    target_version.id,
    null,
    null,
    null,
    actor_membership.id,
    p_request_id,
    'feeding_plan_version_activated',
    target_plan.row_version
  );
  safe_result := jsonb_build_object(
    'feeding_plan_id', target_plan.id,
    'feeding_plan_version_id', target_version.id,
    'plan_row_version', target_plan.row_version,
    'version_row_version', target_version.row_version,
    'materialized_from_local_date', batch_from,
    'materialized_through_local_date', batch_through,
    'created_count', created_count,
    'cancelled_count', cancelled_count,
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
    target_plan.stable_id,
    'activate_feeding_plan_version',
    'feeding_plan_version',
    target_version.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.retire_feeding_plan(
  p_feeding_plan_id uuid,
  p_expected_row_version bigint,
  p_reason text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  target_horse_id uuid;
  actor_membership public.stable_memberships%rowtype;
  target_plan public.feeding_plans%rowtype;
  normalized_reason text := btrim(coalesce(p_reason, ''));
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
  cancelled_count integer := 0;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_expected_row_version is null
    or p_expected_row_version < 1
    or length(normalized_reason) not between 1 and 500
  then
    raise exception using
      errcode = '22023',
      message = 'INVALID_FEEDING_RETIREMENT';
  end if;
  select plan.stable_id, plan.horse_id
    into target_stable_id, target_horse_id
  from public.feeding_plans plan
  where plan.id = p_feeding_plan_id;
  if target_stable_id is null then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;
  actor_membership := private.lock_feeding_context(
    target_stable_id,
    target_horse_id
  );
  if not private.feeding_membership_can_manage(
    actor_membership,
    target_horse_id
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(target_horse_id::text, 404)
  );
  perform 1
  from public.feeding_plans plan
  where plan.horse_id = target_horse_id
  order by plan.id
  for update;
  select * into target_plan
  from public.feeding_plans plan
  where plan.id = p_feeding_plan_id
    and plan.stable_id = target_stable_id
  for update;
  if target_plan.id is null then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'feeding_plan_id', p_feeding_plan_id,
      'expected_row_version', p_expected_row_version,
      'reason', normalized_reason
    )
  );
  receipt_result := private.feeding_receipt_result(
    actor_id,
    p_request_id,
    'retire_feeding_plan',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  if target_plan.status = 'retired'
    or target_plan.row_version <> p_expected_row_version
  then
    raise exception using
      errcode = '40001',
      message = 'ROW_VERSION_CONFLICT';
  end if;
  if target_plan.plan_type = 'standard'
    and target_plan.status = 'active'
    and exists (
      select 1
      from public.feeding_plans temporary_plan
      where temporary_plan.horse_id = target_plan.horse_id
        and temporary_plan.plan_type = 'temporary'
        and temporary_plan.status = 'active'
    )
  then
    raise exception using
      errcode = '55000',
      message = 'STANDARD_PLAN_HAS_ACTIVE_TEMPORARY';
  end if;
  if target_plan.plan_type = 'temporary'
    and target_plan.status = 'active'
    and exists (
      select 1
      from public.feeding_occurrences occurrence
      join public.schedule_items schedule_item
        on schedule_item.id = occurrence.schedule_item_id
      where occurrence.feeding_plan_version_id
        = target_plan.active_version_id
        and schedule_item.state in ('planned', 'in_progress')
    )
  then
    raise exception using
      errcode = '55000',
      message = 'TEMPORARY_PLAN_HAS_PENDING_OCCURRENCES';
  end if;

  with cancelled_items as (
    update public.schedule_items schedule_item
    set
      state = 'cancelled',
      state_reason = 'feeding_plan_retired',
      terminal_at = timezone('utc', now()),
      last_mutated_by_user_id = actor_id,
      last_mutation_request_id = p_request_id
    where schedule_item.id in (
      select occurrence.schedule_item_id
      from public.feeding_occurrences occurrence
      where occurrence.feeding_plan_version_id
        = target_plan.active_version_id
    )
      and schedule_item.state = 'planned'
      and not exists (
        select 1
        from public.schedule_executions execution
        where execution.schedule_item_id = schedule_item.id
      )
    returning schedule_item.id
  )
  select count(*) into cancelled_count from cancelled_items;

  update public.schedule_assignments assignment
  set
    status = 'cancelled',
    cancelled_at = timezone('utc', pg_catalog.now()),
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where assignment.schedule_item_id in (
    select schedule_item.id
    from public.schedule_items schedule_item
    where schedule_item.last_mutation_request_id = p_request_id
      and schedule_item.state = 'cancelled'
      and schedule_item.state_reason = 'feeding_plan_retired'
  )
    and assignment.status in ('assigned', 'accepted');

  update public.feeding_plans plan
  set
    status = 'retired',
    retired_at = timezone('utc', now()),
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where plan.id = target_plan.id
  returning * into target_plan;

  perform private.write_feeding_change_event(
    target_plan.stable_id,
    target_plan.horse_id,
    target_plan.id,
    target_plan.active_version_id,
    null,
    null,
    null,
    actor_membership.id,
    p_request_id,
    'feeding_plan_retired',
    target_plan.row_version,
    normalized_reason
  );
  safe_result := jsonb_build_object(
    'feeding_plan_id', target_plan.id,
    'row_version', target_plan.row_version,
    'status', target_plan.status,
    'cancelled_count', cancelled_count,
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
    target_plan.stable_id,
    'retire_feeding_plan',
    'feeding_plan',
    target_plan.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.record_feeding_execution(
  p_schedule_item_id uuid,
  p_corrects_execution_id uuid,
  p_request_id uuid,
  p_execution_status text,
  p_actual_started_at timestamptz,
  p_actual_completed_at timestamptz,
  p_recorded_local_at timestamp,
  p_recorded_timezone text,
  p_source text,
  p_device_instance_id uuid,
  p_note text,
  p_actual_quantity numeric,
  p_unit_code text,
  p_remaining_quantity numeric,
  p_deviation_code text,
  p_observation text,
  p_batch_lot text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  target_horse_id uuid;
  actor_membership public.stable_memberships%rowtype;
  target_item public.schedule_items%rowtype;
  target_occurrence public.feeding_occurrences%rowtype;
  original_execution public.schedule_executions%rowtype;
  created_execution public.schedule_executions%rowtype;
  actor_is_assigned boolean := false;
  actor_can_execute boolean := false;
  normalized_timezone text := btrim(coalesce(p_recorded_timezone, ''));
  normalized_note text := nullif(btrim(p_note), '');
  normalized_observation text := nullif(btrim(p_observation), '');
  normalized_batch text := nullif(btrim(p_batch_lot), '');
  new_state text;
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_execution_status not in (
    'completed', 'partial', 'skipped', 'refused', 'problem'
  )
    or p_actual_completed_at is null
    or (
      p_actual_started_at is not null
      and p_actual_completed_at < p_actual_started_at
    )
    or p_recorded_local_at is null
    or length(normalized_timezone) not between 1 and 100
    or not exists (
      select 1
      from pg_catalog.pg_timezone_names zone
      where zone.name = normalized_timezone
    )
    or p_source not in ('online', 'offline_sync')
    or (p_source = 'offline_sync' and p_device_instance_id is null)
    or (normalized_note is not null and length(normalized_note) > 1000)
    or p_actual_quantity is null
    or p_actual_quantity < 0
    or p_unit_code not in ('g', 'kg', 'ml', 'l', 'scoop', 'portion', 'piece')
    or p_remaining_quantity is not null
      and p_remaining_quantity < 0
    or p_deviation_code not in (
      'none', 'less', 'more', 'refused',
      'spilled', 'substituted', 'other'
    )
    or (
      normalized_observation is not null
      and length(normalized_observation) > 1000
    )
    or (normalized_batch is not null and length(normalized_batch) > 160)
  then
    raise exception using
      errcode = '22023',
      message = 'INVALID_FEEDING_EXECUTION';
  end if;

  select schedule_item.stable_id, schedule_item.horse_id
    into target_stable_id, target_horse_id
  from public.schedule_items schedule_item
  join public.feeding_occurrences occurrence
    on occurrence.schedule_item_id = schedule_item.id
  where schedule_item.id = p_schedule_item_id;
  if target_stable_id is null then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;
  actor_membership := private.lock_feeding_context(
    target_stable_id,
    target_horse_id
  );

  select * into target_item
  from public.schedule_items schedule_item
  where schedule_item.id = p_schedule_item_id
    and schedule_item.stable_id = target_stable_id
    and schedule_item.item_kind = 'feeding'
    and schedule_item.data_category = 'horse.nutrition'
  for update;
  select * into target_occurrence
  from public.feeding_occurrences occurrence
  where occurrence.schedule_item_id = target_item.id
    and occurrence.stable_id = target_stable_id;
  if target_item.id is null or target_occurrence.schedule_item_id is null then
    raise exception using
      errcode = '42501',
      message = 'NUTRITION_UNAVAILABLE';
  end if;
  if p_unit_code <> target_occurrence.unit_code then
    raise exception using
      errcode = '22023',
      message = 'FEEDING_UNIT_CONVERSION_REQUIRED';
  end if;

  perform 1
  from public.schedule_assignments assignment
  where assignment.schedule_item_id = target_item.id
    and assignment.status in ('assigned', 'accepted')
  order by assignment.id
  for share;

  if p_corrects_execution_id is not null then
    select * into original_execution
    from public.schedule_executions execution
    where execution.id = p_corrects_execution_id
      and execution.schedule_item_id = target_item.id
      and execution.stable_id = target_stable_id
    for share;
    if original_execution.id is null then
      raise exception using
        errcode = '42501',
        message = 'NUTRITION_UNAVAILABLE';
    end if;
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'schedule_item_id', p_schedule_item_id,
      'corrects_execution_id', p_corrects_execution_id,
      'execution_status', p_execution_status,
      'actual_started_at', p_actual_started_at,
      'actual_completed_at', p_actual_completed_at,
      'recorded_local_at', p_recorded_local_at,
      'recorded_timezone', normalized_timezone,
      'source', p_source,
      'device_instance_id', p_device_instance_id,
      'note', normalized_note,
      'actual_quantity', p_actual_quantity,
      'unit_code', p_unit_code,
      'remaining_quantity', p_remaining_quantity,
      'deviation_code', p_deviation_code,
      'observation', normalized_observation,
      'batch_lot', normalized_batch
    )
  );
  receipt_result := private.feeding_receipt_result(
    actor_id,
    p_request_id,
    'record_feeding_execution',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  actor_is_assigned := actor_membership.stable_member_id is not null
    and exists (
      select 1
      from public.schedule_assignments assignment
      where assignment.schedule_item_id = target_item.id
        and assignment.stable_id = target_item.stable_id
        and assignment.stable_member_id
          = actor_membership.stable_member_id
        and assignment.assignment_role in ('responsible', 'support')
        and assignment.status in ('assigned', 'accepted')
    );
  actor_can_execute := private.has_horse_capability(
    target_horse_id,
    'horse.nutrition',
    'execute'
  );
  if not (
    actor_can_execute
    or actor_is_assigned
    or (
      p_corrects_execution_id is not null
      and original_execution.actor_user_id = actor_id
    )
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  if p_corrects_execution_id is null
    and target_item.state in ('completed', 'skipped', 'cancelled')
  then
    raise exception using
      errcode = '55000',
      message = 'SCHEDULE_ITEM_TERMINAL';
  end if;
  if p_corrects_execution_id is not null and exists (
    select 1
    from public.schedule_executions execution
    where execution.corrects_execution_id = original_execution.id
  )
  then
    raise exception using
      errcode = '55000',
      message = 'EXECUTION_ALREADY_CORRECTED';
  end if;

  insert into public.schedule_executions (
    stable_id,
    schedule_item_id,
    actor_user_id,
    actor_membership_id,
    actor_stable_member_id,
    execution_status,
    actual_started_at,
    actual_completed_at,
    recorded_local_at,
    recorded_timezone,
    source,
    device_instance_id,
    request_id,
    note,
    corrects_execution_id
  )
  values (
    target_stable_id,
    target_item.id,
    actor_id,
    actor_membership.id,
    actor_membership.stable_member_id,
    p_execution_status,
    p_actual_started_at,
    p_actual_completed_at,
    p_recorded_local_at,
    normalized_timezone,
    p_source,
    p_device_instance_id,
    p_request_id,
    normalized_note,
    p_corrects_execution_id
  )
  returning * into created_execution;

  insert into public.feeding_execution_details (
    execution_id,
    stable_id,
    schedule_item_id,
    actual_quantity,
    unit_code,
    remaining_quantity,
    deviation_code,
    observation,
    batch_lot
  )
  values (
    created_execution.id,
    target_stable_id,
    target_item.id,
    p_actual_quantity,
    p_unit_code,
    p_remaining_quantity,
    p_deviation_code,
    normalized_observation,
    normalized_batch
  );

  new_state := case
    when p_execution_status = 'completed' then 'completed'
    when p_execution_status in ('skipped', 'refused') then 'skipped'
    else 'in_progress'
  end;
  update public.schedule_items schedule_item
  set
    state = new_state,
    state_reason = case
      when p_execution_status = 'completed' then null
      else 'execution_' || p_execution_status
    end,
    terminal_at = case
      when new_state in ('completed', 'skipped')
        then timezone('utc', now())
      else null
    end,
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where schedule_item.id = target_item.id
  returning * into target_item;

  if actor_is_assigned and new_state in ('completed', 'skipped') then
    update public.schedule_assignments assignment
    set
      status = 'completed',
      completed_at = timezone('utc', now()),
      last_mutated_by_user_id = actor_id,
      last_mutation_request_id = p_request_id
    where assignment.schedule_item_id = target_item.id
      and assignment.stable_member_id
        = actor_membership.stable_member_id
      and assignment.assignment_role in ('responsible', 'support')
      and assignment.status in ('assigned', 'accepted');
  end if;

  perform private.write_schedule_change_event(
    target_item.stable_id,
    null,
    target_item.id,
    null,
    created_execution.id,
    actor_membership.id,
    p_request_id,
    case
      when p_corrects_execution_id is null
        then 'schedule_execution_recorded'
      else 'schedule_execution_corrected'
    end,
    'horse.nutrition',
    target_item.row_version
  );
  perform private.write_feeding_change_event(
    target_item.stable_id,
    target_horse_id,
    null,
    target_occurrence.feeding_plan_version_id,
    target_occurrence.feeding_plan_item_id,
    target_item.id,
    created_execution.id,
    actor_membership.id,
    p_request_id,
    case
      when p_corrects_execution_id is null
        then 'feeding_execution_recorded'
      else 'feeding_execution_corrected'
    end,
    target_item.row_version
  );
  safe_result := jsonb_build_object(
    'execution_id', created_execution.id,
    'corrects_execution_id', p_corrects_execution_id,
    'schedule_item_id', target_item.id,
    'schedule_item_row_version', target_item.row_version,
    'state', target_item.state,
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
    target_item.stable_id,
    'record_feeding_execution',
    'schedule_execution',
    created_execution.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function private.can_select_feeding_plan(
  p_feeding_plan_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.feeding_plans plan
    join public.stables stable on stable.id = plan.stable_id
    join public.horses horse
      on horse.id = plan.horse_id
     and horse.stable_id = plan.stable_id
    join public.stable_memberships membership
      on membership.stable_id = plan.stable_id
     and membership.user_id = auth.uid()
     and membership.status = 'active'
    where plan.id = p_feeding_plan_id
      and stable.status = 'active'
      and horse.status = 'active'
      and (
        membership.role = 'owner'
        or private.has_horse_capability(
          plan.horse_id,
          'horse.nutrition',
          'view'
        )
      )
  )
$$;

create or replace function private.can_select_feeding_version(
  p_feeding_plan_version_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.feeding_plan_versions version
    where version.id = p_feeding_plan_version_id
      and private.can_select_feeding_plan(version.feeding_plan_id)
  )
$$;

create or replace function private.can_select_feeding_execution_detail(
  p_execution_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.schedule_executions execution
    where execution.id = p_execution_id
      and (
        private.schedule_item_access_level(
          execution.schedule_item_id
        ) = 'full'
        or (
          execution.actor_user_id = auth.uid()
          and private.schedule_item_access_level(
            execution.schedule_item_id
          ) = 'assigned'
        )
      )
  )
$$;

alter table public.feeding_plans enable row level security;
alter table public.feeding_plan_versions enable row level security;
alter table public.feeding_plan_items enable row level security;
alter table public.feeding_occurrences enable row level security;
alter table public.feeding_execution_details enable row level security;
alter table public.feeding_change_events enable row level security;

revoke all on table public.feeding_plans
  from public, anon, authenticated;
revoke all on table public.feeding_plan_versions
  from public, anon, authenticated;
revoke all on table public.feeding_plan_items
  from public, anon, authenticated;
revoke all on table public.feeding_occurrences
  from public, anon, authenticated;
revoke all on table public.feeding_execution_details
  from public, anon, authenticated;
revoke all on table public.feeding_change_events
  from public, anon, authenticated;
revoke all on sequence public.feeding_change_events_id_seq
  from public, anon, authenticated;
revoke all on table private.feeding_mutation_receipts
  from public, anon, authenticated;

grant select on table public.feeding_plans to authenticated;
grant select on table public.feeding_plan_versions to authenticated;
grant select on table public.feeding_plan_items to authenticated;
grant select on table public.feeding_occurrences to authenticated;
grant select on table public.feeding_execution_details to authenticated;
grant select on table public.feeding_change_events to authenticated;

create policy feeding_plans_select_full
on public.feeding_plans for select to authenticated
using (private.can_select_feeding_plan(id));

create policy feeding_plan_versions_select_full
on public.feeding_plan_versions for select to authenticated
using (private.can_select_feeding_version(id));

create policy feeding_plan_items_select_full
on public.feeding_plan_items for select to authenticated
using (private.can_select_feeding_version(feeding_plan_version_id));

create policy feeding_occurrences_select_full
on public.feeding_occurrences for select to authenticated
using (private.can_select_feeding_version(feeding_plan_version_id));

create policy feeding_execution_details_select_authorized
on public.feeding_execution_details for select to authenticated
using (private.can_select_feeding_execution_detail(execution_id));

create policy feeding_change_events_select_full
on public.feeding_change_events for select to authenticated
using (
  (
    feeding_plan_id is not null
    and private.can_select_feeding_plan(feeding_plan_id)
  )
  or (
    feeding_plan_id is null
    and feeding_plan_version_id is not null
    and private.can_select_feeding_version(feeding_plan_version_id)
  )
);

revoke all on function private.touch_feeding_plan()
  from public, anon, authenticated;
revoke all on function private.touch_feeding_plan_version()
  from public, anon, authenticated;
revoke all on function private.guard_feeding_plan_item_draft()
  from public, anon, authenticated;
revoke all on function private.touch_feeding_plan_item()
  from public, anon, authenticated;
revoke all on function private.feeding_receipt_result(
  uuid, uuid, text, bytea
) from public, anon, authenticated;
revoke all on function private.lock_feeding_context(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.feeding_membership_can_edit(
  public.stable_memberships, uuid
) from public, anon, authenticated;
revoke all on function private.feeding_membership_can_manage(
  public.stable_memberships, uuid
) from public, anon, authenticated;
revoke all on function private.write_feeding_change_event(
  uuid, uuid, uuid, uuid, uuid, uuid, uuid, uuid, uuid, text, bigint, text
) from public, anon, authenticated;
revoke all on function private.feeding_item_matches_date(
  public.feeding_plan_items, date, date
) from public, anon, authenticated;
revoke all on function private.can_select_feeding_plan(uuid)
  from public, anon, authenticated;
revoke all on function private.can_select_feeding_version(uuid)
  from public, anon, authenticated;
revoke all on function private.can_select_feeding_execution_detail(uuid)
  from public, anon, authenticated;

grant execute on function private.can_select_feeding_plan(uuid)
  to authenticated;
grant execute on function private.can_select_feeding_version(uuid)
  to authenticated;
grant execute on function private.can_select_feeding_execution_detail(uuid)
  to authenticated;

revoke execute on function public.create_feeding_plan(
  uuid, text, text, date, date, uuid
) from public, anon;
revoke execute on function public.create_feeding_plan_version(
  uuid, text, text, text, uuid
) from public, anon;
revoke execute on function public.upsert_feeding_plan_item(
  uuid, uuid, bigint, text, text, text, text, numeric, text, text,
  text, time, smallint[], integer, text, uuid, text, date, text, uuid
) from public, anon;
revoke execute on function public.approve_feeding_plan_version(
  uuid, bigint, uuid
) from public, anon;
revoke execute on function public.activate_feeding_plan_version(
  uuid, bigint, date, uuid
) from public, anon;
revoke execute on function public.retire_feeding_plan(
  uuid, bigint, text, uuid
) from public, anon;
revoke execute on function public.record_feeding_execution(
  uuid, uuid, uuid, text, timestamptz, timestamptz, timestamp,
  text, text, uuid, text, numeric, text, numeric, text, text, text
) from public, anon;

grant execute on function public.create_feeding_plan(
  uuid, text, text, date, date, uuid
) to authenticated;
grant execute on function public.create_feeding_plan_version(
  uuid, text, text, text, uuid
) to authenticated;
grant execute on function public.upsert_feeding_plan_item(
  uuid, uuid, bigint, text, text, text, text, numeric, text, text,
  text, time, smallint[], integer, text, uuid, text, date, text, uuid
) to authenticated;
grant execute on function public.approve_feeding_plan_version(
  uuid, bigint, uuid
) to authenticated;
grant execute on function public.activate_feeding_plan_version(
  uuid, bigint, date, uuid
) to authenticated;
grant execute on function public.retire_feeding_plan(
  uuid, bigint, text, uuid
) to authenticated;
grant execute on function public.record_feeding_execution(
  uuid, uuid, uuid, text, timestamptz, timestamptz, timestamp,
  text, text, uuid, text, numeric, text, numeric, text, text, text
) to authenticated;

comment on table public.feeding_plans is
  'Phase 4C.4 logical standard or explicit temporary Horse feeding plans.';
comment on table public.feeding_plan_versions is
  'Immutable approved feeding content versions; activated rows are never edited in place.';
comment on table public.feeding_plan_items is
  'Draft-only feeding instructions with fixed units, source status and explicit override keys.';
comment on table public.feeding_occurrences is
  'Append-only specialization proving which feeding version generated each schedule item.';
comment on table public.feeding_execution_details is
  'Append-only quantities and deviations written atomically with generic schedule execution.';
comment on table public.feeding_change_events is
  'Payload-minimal append-only feeding plan and execution audit trail.';
comment on table private.feeding_mutation_receipts is
  'Private hash-only durable idempotency receipts for 4C.4 feeding mutations.';

commit;
