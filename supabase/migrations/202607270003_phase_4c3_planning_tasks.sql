begin;

create table public.schedule_series (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  horse_id uuid,
  horse_scope_key text generated always as (
    coalesce(horse_id::text, 'stable')
  ) stored,
  supersedes_series_id uuid,
  series_kind text not null
    check (series_kind in ('task', 'feeding', 'training', 'care', 'other')),
  data_category text not null
    check (
      data_category in (
        'horse.schedule',
        'horse.nutrition',
        'horse.health_summary'
      )
    ),
  title text not null
    check (length(btrim(title)) between 1 and 160),
  instruction text not null
    check (length(btrim(instruction)) between 1 and 2000),
  timezone text not null
    check (length(btrim(timezone)) between 1 and 100),
  frequency text not null
    check (frequency in ('daily', 'weekly', 'interval')),
  interval_value integer not null default 1
    check (interval_value between 1 and 365),
  weekdays smallint[],
  local_start_time time not null,
  duration_minutes integer
    check (duration_minutes is null or duration_minutes between 0 and 1440),
  starts_on date not null,
  ends_on date,
  status text not null default 'draft'
    check (status in ('draft', 'active', 'paused', 'ended')),
  generation_horizon_days integer not null default 60
    check (generation_horizon_days between 1 and 90),
  row_version bigint not null default 1 check (row_version > 0),
  created_by_user_id uuid not null references auth.users (id),
  created_request_id uuid not null,
  last_mutated_by_user_id uuid not null references auth.users (id),
  last_mutation_request_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  ended_at timestamptz,
  constraint schedule_series_stable_and_id_unique
    unique (stable_id, id),
  constraint schedule_series_scope_unique
    unique (stable_id, id, horse_scope_key),
  constraint schedule_series_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint schedule_series_supersedes_fk
    foreign key (stable_id, supersedes_series_id)
    references public.schedule_series (stable_id, id),
  constraint schedule_series_created_request_unique
    unique (created_by_user_id, created_request_id),
  constraint schedule_series_window
    check (ends_on is null or ends_on >= starts_on),
  constraint schedule_series_weekdays
    check (
      (
        frequency = 'weekly'
        and weekdays is not null
        and cardinality(weekdays) between 1 and 7
        and weekdays <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
      )
      or (
        frequency <> 'weekly'
        and weekdays is null
      )
    ),
  constraint schedule_series_lifecycle
    check (
      (status <> 'ended' and ended_at is null)
      or (status = 'ended' and ended_at is not null)
    )
);

create index schedule_series_stable_status
  on public.schedule_series (stable_id, status, starts_on, id);

create index schedule_series_horse_status
  on public.schedule_series (horse_id, status, starts_on, id)
  where horse_id is not null;

create table public.schedule_items (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  horse_id uuid,
  horse_scope_key text generated always as (
    coalesce(horse_id::text, 'stable')
  ) stored,
  series_id uuid,
  occurrence_local_date date,
  occurrence_sequence integer
    check (occurrence_sequence is null or occurrence_sequence > 0),
  item_kind text not null
    check (item_kind in ('task', 'feeding', 'training', 'care', 'other')),
  data_category text not null
    check (
      data_category in (
        'horse.schedule',
        'horse.nutrition',
        'horse.health_summary'
      )
    ),
  title text not null
    check (length(btrim(title)) between 1 and 160),
  instruction text not null
    check (length(btrim(instruction)) between 1 and 2000),
  priority text not null default 'normal'
    check (priority in ('normal', 'high')),
  scheduled_start_at timestamptz not null,
  scheduled_end_at timestamptz,
  source_timezone text not null
    check (length(btrim(source_timezone)) between 1 and 100),
  source_local_date date not null,
  source_local_time time not null,
  state text not null default 'planned'
    check (
      state in (
        'planned',
        'in_progress',
        'completed',
        'skipped',
        'cancelled'
      )
    ),
  state_reason text
    check (
      state_reason is null
      or length(btrim(state_reason)) between 1 and 500
    ),
  series_override boolean not null default false,
  row_version bigint not null default 1 check (row_version > 0),
  created_by_user_id uuid not null references auth.users (id),
  created_request_id uuid not null,
  last_mutated_by_user_id uuid not null references auth.users (id),
  last_mutation_request_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  terminal_at timestamptz,
  constraint schedule_items_stable_and_id_unique
    unique (stable_id, id),
  constraint schedule_items_scope_unique
    unique (stable_id, id, horse_scope_key),
  constraint schedule_items_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint schedule_items_series_fk
    foreign key (stable_id, series_id, horse_scope_key)
    references public.schedule_series (stable_id, id, horse_scope_key),
  constraint schedule_items_created_request_unique
    unique (created_by_user_id, created_request_id),
  constraint schedule_items_schedule_window
    check (
      scheduled_end_at is null
      or scheduled_end_at >= scheduled_start_at
    ),
  constraint schedule_items_series_occurrence_shape
    check (
      (
        series_id is null
        and occurrence_local_date is null
        and occurrence_sequence is null
      )
      or (
        series_id is not null
        and occurrence_local_date is not null
        and occurrence_sequence is not null
      )
    ),
  constraint schedule_items_terminal_shape
    check (
      (
        state in ('completed', 'skipped', 'cancelled')
        and terminal_at is not null
      )
      or (
        state in ('planned', 'in_progress')
        and terminal_at is null
      )
    ),
  constraint schedule_items_reason_shape
    check (
      state <> 'cancelled'
      or state_reason is not null
    )
);

create unique index schedule_items_series_occurrence_unique
  on public.schedule_items (
    series_id,
    occurrence_local_date,
    occurrence_sequence
  )
  where series_id is not null;

create index schedule_items_stable_day
  on public.schedule_items (
    stable_id,
    source_local_date,
    scheduled_start_at,
    id
  );

create index schedule_items_horse_day
  on public.schedule_items (
    horse_id,
    source_local_date,
    scheduled_start_at,
    id
  )
  where horse_id is not null;

create table public.schedule_assignments (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  schedule_item_id uuid not null,
  stable_member_id uuid not null,
  assignment_role text not null
    check (assignment_role in ('responsible', 'support', 'reviewer')),
  status text not null default 'assigned'
    check (
      status in (
        'assigned',
        'accepted',
        'returned',
        'completed',
        'cancelled'
      )
    ),
  row_version bigint not null default 1 check (row_version > 0),
  created_by_user_id uuid not null references auth.users (id),
  created_request_id uuid not null,
  last_mutated_by_user_id uuid not null references auth.users (id),
  last_mutation_request_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  accepted_at timestamptz,
  returned_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  constraint schedule_assignments_stable_and_id_unique
    unique (stable_id, id),
  constraint schedule_assignments_item_fk
    foreign key (stable_id, schedule_item_id)
    references public.schedule_items (stable_id, id),
  constraint schedule_assignments_member_fk
    foreign key (stable_id, stable_member_id)
    references public.stable_members (stable_id, id),
  constraint schedule_assignments_created_request_unique
    unique (created_by_user_id, created_request_id),
  constraint schedule_assignments_lifecycle
    check (
      (
        status = 'assigned'
        and accepted_at is null
        and returned_at is null
        and completed_at is null
        and cancelled_at is null
      )
      or (
        status = 'accepted'
        and accepted_at is not null
        and returned_at is null
        and completed_at is null
        and cancelled_at is null
      )
      or (
        status = 'returned'
        and returned_at is not null
        and completed_at is null
        and cancelled_at is null
      )
      or (
        status = 'completed'
        and completed_at is not null
        and returned_at is null
        and cancelled_at is null
      )
      or (
        status = 'cancelled'
        and cancelled_at is not null
        and returned_at is null
        and completed_at is null
      )
    )
);

create unique index schedule_assignments_one_active_responsible
  on public.schedule_assignments (schedule_item_id)
  where assignment_role = 'responsible'
    and status in ('assigned', 'accepted');

create unique index schedule_assignments_one_active_role
  on public.schedule_assignments (
    schedule_item_id,
    stable_member_id,
    assignment_role
  )
  where status in ('assigned', 'accepted');

create index schedule_assignments_member_active
  on public.schedule_assignments (
    stable_member_id,
    status,
    schedule_item_id,
    id
  );

create table public.schedule_executions (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  schedule_item_id uuid not null,
  actor_user_id uuid not null references auth.users (id),
  actor_membership_id uuid not null,
  actor_stable_member_id uuid not null,
  execution_status text not null
    check (
      execution_status in (
        'completed',
        'partial',
        'skipped',
        'refused',
        'problem'
      )
    ),
  actual_started_at timestamptz,
  actual_completed_at timestamptz not null,
  recorded_local_at timestamp not null,
  recorded_timezone text not null
    check (length(btrim(recorded_timezone)) between 1 and 100),
  source text not null
    check (source in ('online', 'offline_sync')),
  device_instance_id uuid,
  request_id uuid not null,
  note text
    check (note is null or length(btrim(note)) between 1 and 1000),
  corrects_execution_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  constraint schedule_executions_stable_item_id_unique
    unique (stable_id, schedule_item_id, id),
  constraint schedule_executions_item_fk
    foreign key (stable_id, schedule_item_id)
    references public.schedule_items (stable_id, id),
  constraint schedule_executions_actor_membership_fk
    foreign key (stable_id, actor_membership_id)
    references public.stable_memberships (stable_id, id),
  constraint schedule_executions_actor_member_fk
    foreign key (stable_id, actor_stable_member_id)
    references public.stable_members (stable_id, id),
  constraint schedule_executions_correction_fk
    foreign key (
      stable_id,
      schedule_item_id,
      corrects_execution_id
    )
    references public.schedule_executions (
      stable_id,
      schedule_item_id,
      id
    ),
  constraint schedule_executions_actor_request_unique
    unique (actor_user_id, request_id),
  constraint schedule_executions_time_window
    check (
      actual_started_at is null
      or actual_completed_at >= actual_started_at
    ),
  constraint schedule_executions_source_shape
    check (
      (source = 'online')
      or (source = 'offline_sync' and device_instance_id is not null)
    )
);

create unique index schedule_executions_one_direct_correction
  on public.schedule_executions (corrects_execution_id)
  where corrects_execution_id is not null;

create index schedule_executions_item_created
  on public.schedule_executions (schedule_item_id, created_at, id);

create table public.schedule_change_events (
  id bigint generated always as identity primary key,
  stable_id uuid not null references public.stables (id),
  schedule_series_id uuid,
  schedule_item_id uuid,
  schedule_assignment_id uuid,
  schedule_execution_id uuid,
  actor_user_id uuid not null references auth.users (id),
  actor_membership_id uuid not null,
  request_id uuid not null,
  event_type text not null
    check (
      event_type in (
        'schedule_series_created',
        'schedule_series_updated',
        'schedule_series_split',
        'schedule_occurrence_materialized',
        'schedule_item_created',
        'schedule_item_updated',
        'schedule_item_cancelled',
        'schedule_item_reopened',
        'schedule_assignment_created',
        'schedule_assignment_returned',
        'schedule_execution_recorded',
        'schedule_execution_corrected'
      )
    ),
  data_category text not null
    check (
      data_category in (
        'horse.schedule',
        'horse.nutrition',
        'horse.health_summary'
      )
    ),
  row_version bigint check (row_version is null or row_version > 0),
  reason text
    check (reason is null or length(btrim(reason)) between 1 and 500),
  created_at timestamptz not null default timezone('utc', now()),
  constraint schedule_change_events_actor_membership_fk
    foreign key (stable_id, actor_membership_id)
    references public.stable_memberships (stable_id, id),
  constraint schedule_change_events_series_fk
    foreign key (stable_id, schedule_series_id)
    references public.schedule_series (stable_id, id),
  constraint schedule_change_events_item_fk
    foreign key (stable_id, schedule_item_id)
    references public.schedule_items (stable_id, id),
  constraint schedule_change_events_assignment_fk
    foreign key (stable_id, schedule_assignment_id)
    references public.schedule_assignments (stable_id, id),
  constraint schedule_change_events_execution_fk
    foreign key (
      stable_id,
      schedule_item_id,
      schedule_execution_id
    )
    references public.schedule_executions (
      stable_id,
      schedule_item_id,
      id
    ),
  constraint schedule_change_events_target
    check (
      schedule_series_id is not null
      or schedule_item_id is not null
      or schedule_assignment_id is not null
      or schedule_execution_id is not null
    )
);

create index schedule_change_events_stable_created
  on public.schedule_change_events (stable_id, created_at, id);

create index schedule_change_events_item_created
  on public.schedule_change_events (schedule_item_id, created_at, id)
  where schedule_item_id is not null;

create table private.schedule_mutation_receipts (
  actor_user_id uuid not null references auth.users (id),
  request_id uuid not null,
  stable_id uuid not null references public.stables (id),
  operation_name text not null
    check (
      operation_name in (
        'create_schedule_series',
        'update_schedule_series_scope',
        'materialize_schedule_occurrences',
        'create_schedule_item',
        'update_schedule_item',
        'cancel_schedule_item',
        'assign_schedule_item',
        'return_schedule_assignment',
        'record_schedule_execution',
        'correct_schedule_execution',
        'reopen_schedule_item'
      )
    ),
  target_type text not null
    check (
      target_type in (
        'schedule_series',
        'schedule_item',
        'schedule_assignment',
        'schedule_execution'
      )
    ),
  target_id uuid,
  payload_hash bytea not null check (octet_length(payload_hash) = 32),
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (actor_user_id, request_id)
);

create or replace function private.touch_schedule_series()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.title := btrim(new.title);
  new.instruction := btrim(new.instruction);
  new.timezone := btrim(new.timezone);
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

create trigger schedule_series_touch_before_write
before insert or update on public.schedule_series
for each row execute function private.touch_schedule_series();

create or replace function private.touch_schedule_item()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.title := btrim(new.title);
  new.instruction := btrim(new.instruction);
  new.source_timezone := btrim(new.source_timezone);
  new.state_reason := nullif(btrim(new.state_reason), '');
  new.updated_at := timezone('utc', pg_catalog.now());
  if tg_op = 'UPDATE' then
    new.row_version := old.row_version + 1;
  end if;
  return new;
end;
$$;

create trigger schedule_items_touch_before_write
before insert or update on public.schedule_items
for each row execute function private.touch_schedule_item();

create or replace function private.touch_schedule_assignment()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := timezone('utc', pg_catalog.now());
  if tg_op = 'UPDATE' then
    new.row_version := old.row_version + 1;
  end if;
  return new;
end;
$$;

create trigger schedule_assignments_touch_before_write
before insert or update on public.schedule_assignments
for each row execute function private.touch_schedule_assignment();

create or replace function private.prevent_schedule_append_only_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'APPEND_ONLY_RECORD';
end;
$$;

create trigger schedule_executions_append_only
before update or delete on public.schedule_executions
for each row execute function private.prevent_schedule_append_only_mutation();

create trigger schedule_change_events_append_only
before update or delete on public.schedule_change_events
for each row execute function private.prevent_schedule_append_only_mutation();

create or replace function private.schedule_payload_hash(p_payload jsonb)
returns bytea
language sql
immutable
set search_path = ''
as $$
  select extensions.digest(
    convert_to(coalesce(p_payload, '{}'::jsonb)::text, 'UTF8'),
    'sha256'
  )
$$;

create or replace function private.schedule_derived_request_id(
  p_request_id uuid,
  p_suffix text
)
returns uuid
language sql
immutable
set search_path = ''
as $$
  with digest_text as (
    select encode(
      extensions.digest(
        convert_to(p_request_id::text || ':' || p_suffix, 'UTF8'),
        'sha256'
      ),
      'hex'
    ) as value
  )
  select (
    substr(value, 1, 8) || '-' ||
    substr(value, 9, 4) || '-' ||
    substr(value, 13, 4) || '-' ||
    substr(value, 17, 4) || '-' ||
    substr(value, 21, 12)
  )::uuid
  from digest_text
$$;

create or replace function private.schedule_receipt_result(
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
  existing_receipt private.schedule_mutation_receipts%rowtype;
begin
  select * into existing_receipt
  from private.schedule_mutation_receipts r
  where r.actor_user_id = p_actor_user_id
    and r.request_id = p_request_id;

  if existing_receipt.request_id is null then
    return null;
  end if;
  if existing_receipt.operation_name <> p_operation_name
    or existing_receipt.payload_hash <> p_payload_hash
  then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  return existing_receipt.result || jsonb_build_object('idempotent', true);
end;
$$;

create or replace function private.lock_schedule_context(
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
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;

  select * into actor_membership
  from public.stable_memberships m
  where m.stable_id = p_stable_id
    and m.user_id = actor_id
    and m.status = 'active'
  for share;

  if actor_membership.id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  if p_horse_id is not null then
    perform 1
    from public.horse_access_grants g
    where g.horse_id = p_horse_id
      and g.membership_id = actor_membership.id
      and g.category = 'horse.schedule'
      and g.status = 'active'
    order by g.id
    for share;

    select * into target_horse
    from public.horses h
    where h.id = p_horse_id
      and h.stable_id = p_stable_id
    for share;
  end if;

  if not exists (
    select 1
    from public.stables s
    where s.id = p_stable_id
      and s.status = 'active'
  ) or (
    p_horse_id is not null
    and (
      target_horse.id is null
      or target_horse.status <> 'active'
    )
  )
  then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  return actor_membership;
end;
$$;

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
  select
    p_membership.role in ('owner', 'admin')
    or (
      p_membership.role = 'member'
      and p_horse_id is not null
      and exists (
        select 1
        from public.horse_access_grants g
        where g.horse_id = p_horse_id
          and g.membership_id = p_membership.id
          and g.category = 'horse.schedule'
          and g.status = 'active'
          and g.can_edit
          and g.valid_from <= timezone('utc', pg_catalog.now())
          and (
            g.valid_until is null
            or g.valid_until > timezone('utc', pg_catalog.now())
          )
      )
    )
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
  select
    p_membership.role in ('owner', 'admin')
    or (
      p_membership.role = 'member'
      and p_horse_id is not null
      and exists (
        select 1
        from public.horse_access_grants g
        where g.horse_id = p_horse_id
          and g.membership_id = p_membership.id
          and g.category = 'horse.schedule'
          and g.status = 'active'
          and g.can_execute
          and g.valid_from <= timezone('utc', pg_catalog.now())
          and (
            g.valid_until is null
            or g.valid_until > timezone('utc', pg_catalog.now())
          )
      )
    )
$$;

create or replace function private.schedule_item_access_level(
  p_schedule_item_id uuid
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_item public.schedule_items%rowtype;
  actor_membership public.stable_memberships%rowtype;
begin
  if actor_id is null then return 'none'; end if;

  select * into target_item
  from public.schedule_items i
  where i.id = p_schedule_item_id;
  if target_item.id is null then return 'none'; end if;

  select * into actor_membership
  from public.stable_memberships m
  where m.stable_id = target_item.stable_id
    and m.user_id = actor_id
    and m.status = 'active';
  if actor_membership.id is null then return 'none'; end if;

  if not exists (
    select 1
    from public.stables s
    where s.id = target_item.stable_id
      and s.status = 'active'
  ) or (
    target_item.horse_id is not null
    and not exists (
      select 1
      from public.horses h
      where h.id = target_item.horse_id
        and h.stable_id = target_item.stable_id
        and h.status = 'active'
    )
  )
  then
    return 'none';
  end if;

  if actor_membership.role in ('owner', 'admin')
    or (
      target_item.horse_id is not null
      and private.has_horse_capability(
        target_item.horse_id,
        target_item.data_category,
        'view'
      )
    )
  then
    return 'full';
  end if;

  if actor_membership.stable_member_id is not null
    and exists (
      select 1
      from public.schedule_assignments a
      where a.schedule_item_id = target_item.id
        and a.stable_id = target_item.stable_id
        and a.stable_member_id = actor_membership.stable_member_id
        and a.status in ('assigned', 'accepted', 'completed')
    )
  then
    return 'assigned';
  end if;

  return 'none';
end;
$$;

create or replace function private.write_schedule_change_event(
  p_stable_id uuid,
  p_schedule_series_id uuid,
  p_schedule_item_id uuid,
  p_schedule_assignment_id uuid,
  p_schedule_execution_id uuid,
  p_actor_membership_id uuid,
  p_request_id uuid,
  p_event_type text,
  p_data_category text,
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
    'schedule_series_created',
    'schedule_series_updated',
    'schedule_series_split',
    'schedule_occurrence_materialized',
    'schedule_item_created',
    'schedule_item_updated',
    'schedule_item_cancelled',
    'schedule_item_reopened',
    'schedule_assignment_created',
    'schedule_assignment_returned',
    'schedule_execution_recorded',
    'schedule_execution_corrected'
  ) or p_data_category not in (
    'horse.schedule',
    'horse.nutrition',
    'horse.health_summary'
  ) or p_stable_id is null
    or p_actor_membership_id is null
    or p_request_id is null
    or (
      p_schedule_series_id is null
      and p_schedule_item_id is null
      and p_schedule_assignment_id is null
      and p_schedule_execution_id is null
    )
  then
    raise exception using
      errcode = '22023',
      message = 'SCHEDULE_EVENT_CORRELATION_REQUIRED';
  end if;

  if not exists (
    select 1
    from public.stable_memberships m
    where m.id = p_actor_membership_id
      and m.stable_id = p_stable_id
      and m.user_id = auth.uid()
  )
  then
    raise exception using
      errcode = '22023',
      message = 'SCHEDULE_EVENT_CORRELATION_REQUIRED';
  end if;

  insert into public.schedule_change_events (
    stable_id,
    schedule_series_id,
    schedule_item_id,
    schedule_assignment_id,
    schedule_execution_id,
    actor_user_id,
    actor_membership_id,
    request_id,
    event_type,
    data_category,
    row_version,
    reason
  )
  values (
    p_stable_id,
    p_schedule_series_id,
    p_schedule_item_id,
    p_schedule_assignment_id,
    p_schedule_execution_id,
    auth.uid(),
    p_actor_membership_id,
    p_request_id,
    p_event_type,
    p_data_category,
    p_row_version,
    nullif(btrim(p_reason), '')
  );
end;
$$;

create or replace function public.create_schedule_series(
  p_stable_id uuid,
  p_horse_id uuid,
  p_series_kind text,
  p_data_category text,
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
  normalized_title text := btrim(coalesce(p_title, ''));
  normalized_instruction text := btrim(coalesce(p_instruction, ''));
  normalized_timezone text := btrim(coalesce(p_timezone, ''));
  normalized_weekdays smallint[];
  payload_hash bytea;
  receipt_result jsonb;
  created_series public.schedule_series%rowtype;
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

  if p_series_kind not in ('task', 'training', 'care', 'other')
    or p_data_category <> 'horse.schedule'
    or length(normalized_title) not between 1 and 160
    or length(normalized_instruction) not between 1 and 2000
    or length(normalized_timezone) not between 1 and 100
    or not exists (
      select 1
      from pg_catalog.pg_timezone_names zone
      where zone.name = normalized_timezone
    )
    or p_frequency not in ('daily', 'weekly', 'interval')
    or p_interval_value not between 1 and 365
    or (
      p_frequency = 'weekly'
      and (
        normalized_weekdays is null
        or cardinality(normalized_weekdays) not between 1 and 7
        or not (
          normalized_weekdays
          <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
        )
      )
    )
    or (p_frequency <> 'weekly' and normalized_weekdays is not null)
    or p_local_start_time is null
    or (
      p_duration_minutes is not null
      and p_duration_minutes not between 0 and 1440
    )
    or p_starts_on is null
    or (p_ends_on is not null and p_ends_on < p_starts_on)
    or p_generation_horizon_days not between 1 and 90
    or p_status not in ('draft', 'active')
  then
    raise exception using errcode = '22023', message = 'INVALID_SCHEDULE_SERIES';
  end if;

  actor_membership := private.lock_schedule_context(
    p_stable_id,
    p_horse_id
  );
  if not private.schedule_membership_can_edit(
    actor_membership,
    p_horse_id
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'stable_id', p_stable_id,
      'horse_id', p_horse_id,
      'series_kind', p_series_kind,
      'data_category', p_data_category,
      'title', normalized_title,
      'instruction', normalized_instruction,
      'timezone', normalized_timezone,
      'frequency', p_frequency,
      'interval_value', p_interval_value,
      'weekdays', normalized_weekdays,
      'local_start_time', p_local_start_time,
      'duration_minutes', p_duration_minutes,
      'starts_on', p_starts_on,
      'ends_on', p_ends_on,
      'generation_horizon_days', p_generation_horizon_days,
      'status', p_status
    )
  );
  receipt_result := private.schedule_receipt_result(
    actor_id,
    p_request_id,
    'create_schedule_series',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  insert into public.schedule_series (
    stable_id,
    horse_id,
    series_kind,
    data_category,
    title,
    instruction,
    timezone,
    frequency,
    interval_value,
    weekdays,
    local_start_time,
    duration_minutes,
    starts_on,
    ends_on,
    status,
    generation_horizon_days,
    created_by_user_id,
    created_request_id,
    last_mutated_by_user_id,
    last_mutation_request_id
  )
  values (
    p_stable_id,
    p_horse_id,
    p_series_kind,
    p_data_category,
    normalized_title,
    normalized_instruction,
    normalized_timezone,
    p_frequency,
    p_interval_value,
    normalized_weekdays,
    p_local_start_time,
    p_duration_minutes,
    p_starts_on,
    p_ends_on,
    p_status,
    p_generation_horizon_days,
    actor_id,
    p_request_id,
    actor_id,
    p_request_id
  )
  returning * into created_series;

  perform private.write_schedule_change_event(
    created_series.stable_id,
    created_series.id,
    null,
    null,
    null,
    actor_membership.id,
    p_request_id,
    'schedule_series_created',
    created_series.data_category,
    created_series.row_version
  );

  safe_result := jsonb_build_object(
    'series_id', created_series.id,
    'row_version', created_series.row_version,
    'status', created_series.status,
    'idempotent', false
  );
  insert into private.schedule_mutation_receipts (
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
    created_series.stable_id,
    'create_schedule_series',
    'schedule_series',
    created_series.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.create_schedule_item(
  p_stable_id uuid,
  p_horse_id uuid,
  p_item_kind text,
  p_data_category text,
  p_title text,
  p_instruction text,
  p_priority text,
  p_scheduled_start_at timestamptz,
  p_scheduled_end_at timestamptz,
  p_source_timezone text,
  p_source_local_date date,
  p_source_local_time time,
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
  normalized_title text := btrim(coalesce(p_title, ''));
  normalized_instruction text := btrim(coalesce(p_instruction, ''));
  normalized_timezone text := btrim(coalesce(p_source_timezone, ''));
  payload_hash bytea;
  receipt_result jsonb;
  created_item public.schedule_items%rowtype;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_item_kind not in ('task', 'training', 'care', 'other')
    or p_data_category <> 'horse.schedule'
    or length(normalized_title) not between 1 and 160
    or length(normalized_instruction) not between 1 and 2000
    or p_priority not in ('normal', 'high')
    or p_scheduled_start_at is null
    or (
      p_scheduled_end_at is not null
      and p_scheduled_end_at < p_scheduled_start_at
    )
    or length(normalized_timezone) not between 1 and 100
    or not exists (
      select 1
      from pg_catalog.pg_timezone_names zone
      where zone.name = normalized_timezone
    )
    or p_source_local_date is null
    or p_source_local_time is null
    or (
      p_scheduled_start_at at time zone normalized_timezone
    )::date <> p_source_local_date
    or (
      p_scheduled_start_at at time zone normalized_timezone
    )::time <> p_source_local_time
  then
    raise exception using errcode = '22023', message = 'INVALID_SCHEDULE_ITEM';
  end if;

  actor_membership := private.lock_schedule_context(
    p_stable_id,
    p_horse_id
  );
  if not private.schedule_membership_can_edit(
    actor_membership,
    p_horse_id
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'stable_id', p_stable_id,
      'horse_id', p_horse_id,
      'item_kind', p_item_kind,
      'data_category', p_data_category,
      'title', normalized_title,
      'instruction', normalized_instruction,
      'priority', p_priority,
      'scheduled_start_at', p_scheduled_start_at,
      'scheduled_end_at', p_scheduled_end_at,
      'source_timezone', normalized_timezone,
      'source_local_date', p_source_local_date,
      'source_local_time', p_source_local_time
    )
  );
  receipt_result := private.schedule_receipt_result(
    actor_id,
    p_request_id,
    'create_schedule_item',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  insert into public.schedule_items (
    stable_id,
    horse_id,
    item_kind,
    data_category,
    title,
    instruction,
    priority,
    scheduled_start_at,
    scheduled_end_at,
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
    p_stable_id,
    p_horse_id,
    p_item_kind,
    p_data_category,
    normalized_title,
    normalized_instruction,
    p_priority,
    p_scheduled_start_at,
    p_scheduled_end_at,
    normalized_timezone,
    p_source_local_date,
    p_source_local_time,
    'planned',
    actor_id,
    p_request_id,
    actor_id,
    p_request_id
  )
  returning * into created_item;

  perform private.write_schedule_change_event(
    created_item.stable_id,
    null,
    created_item.id,
    null,
    null,
    actor_membership.id,
    p_request_id,
    'schedule_item_created',
    created_item.data_category,
    created_item.row_version
  );

  safe_result := jsonb_build_object(
    'schedule_item_id', created_item.id,
    'row_version', created_item.row_version,
    'state', created_item.state,
    'idempotent', false
  );
  insert into private.schedule_mutation_receipts (
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
    created_item.stable_id,
    'create_schedule_item',
    'schedule_item',
    created_item.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.update_schedule_item(
  p_schedule_item_id uuid,
  p_expected_row_version bigint,
  p_request_id uuid,
  p_title text,
  p_instruction text,
  p_priority text,
  p_scheduled_start_at timestamptz,
  p_scheduled_end_at timestamptz,
  p_source_timezone text,
  p_source_local_date date,
  p_source_local_time time
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
  normalized_title text := btrim(coalesce(p_title, ''));
  normalized_instruction text := btrim(coalesce(p_instruction, ''));
  normalized_timezone text := btrim(coalesce(p_source_timezone, ''));
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_expected_row_version is null or p_expected_row_version < 1
    or length(normalized_title) not between 1 and 160
    or length(normalized_instruction) not between 1 and 2000
    or p_priority not in ('normal', 'high')
    or p_scheduled_start_at is null
    or (
      p_scheduled_end_at is not null
      and p_scheduled_end_at < p_scheduled_start_at
    )
    or length(normalized_timezone) not between 1 and 100
    or not exists (
      select 1
      from pg_catalog.pg_timezone_names zone
      where zone.name = normalized_timezone
    )
    or p_source_local_date is null
    or p_source_local_time is null
    or (
      p_scheduled_start_at at time zone normalized_timezone
    )::date <> p_source_local_date
    or (
      p_scheduled_start_at at time zone normalized_timezone
    )::time <> p_source_local_time
  then
    raise exception using errcode = '22023', message = 'INVALID_SCHEDULE_ITEM';
  end if;

  select i.stable_id, i.horse_id
    into target_stable_id, target_horse_id
  from public.schedule_items i
  where i.id = p_schedule_item_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  actor_membership := private.lock_schedule_context(
    target_stable_id,
    target_horse_id
  );
  if not private.schedule_membership_can_edit(
    actor_membership,
    target_horse_id
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  select * into target_item
  from public.schedule_items i
  where i.id = p_schedule_item_id
    and i.stable_id = target_stable_id
  for update;
  if target_item.id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'schedule_item_id', p_schedule_item_id,
      'expected_row_version', p_expected_row_version,
      'title', normalized_title,
      'instruction', normalized_instruction,
      'priority', p_priority,
      'scheduled_start_at', p_scheduled_start_at,
      'scheduled_end_at', p_scheduled_end_at,
      'source_timezone', normalized_timezone,
      'source_local_date', p_source_local_date,
      'source_local_time', p_source_local_time
    )
  );
  receipt_result := private.schedule_receipt_result(
    actor_id,
    p_request_id,
    'update_schedule_item',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  if target_item.state in ('completed', 'skipped', 'cancelled') then
    raise exception using errcode = '55000', message = 'SCHEDULE_ITEM_TERMINAL';
  end if;
  if target_item.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'ROW_VERSION_CONFLICT';
  end if;

  update public.schedule_items i
  set
    title = normalized_title,
    instruction = normalized_instruction,
    priority = p_priority,
    scheduled_start_at = p_scheduled_start_at,
    scheduled_end_at = p_scheduled_end_at,
    source_timezone = normalized_timezone,
    source_local_date = p_source_local_date,
    source_local_time = p_source_local_time,
    series_override = i.series_id is not null,
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where i.id = target_item.id
  returning * into target_item;

  perform private.write_schedule_change_event(
    target_item.stable_id,
    target_item.series_id,
    target_item.id,
    null,
    null,
    actor_membership.id,
    p_request_id,
    'schedule_item_updated',
    target_item.data_category,
    target_item.row_version
  );

  safe_result := jsonb_build_object(
    'schedule_item_id', target_item.id,
    'row_version', target_item.row_version,
    'state', target_item.state,
    'idempotent', false
  );
  insert into private.schedule_mutation_receipts (
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
    'update_schedule_item',
    'schedule_item',
    target_item.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.cancel_schedule_item(
  p_schedule_item_id uuid,
  p_expected_row_version bigint,
  p_request_id uuid,
  p_reason text
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
  normalized_reason text := btrim(coalesce(p_reason, ''));
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_expected_row_version is null or p_expected_row_version < 1
    or length(normalized_reason) not between 1 and 500
  then
    raise exception using errcode = '22023', message = 'INVALID_CANCELLATION';
  end if;

  select i.stable_id, i.horse_id
    into target_stable_id, target_horse_id
  from public.schedule_items i
  where i.id = p_schedule_item_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  actor_membership := private.lock_schedule_context(
    target_stable_id,
    target_horse_id
  );
  if not private.schedule_membership_can_edit(
    actor_membership,
    target_horse_id
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  select * into target_item
  from public.schedule_items i
  where i.id = p_schedule_item_id
    and i.stable_id = target_stable_id
  for update;
  if target_item.id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'schedule_item_id', p_schedule_item_id,
      'expected_row_version', p_expected_row_version,
      'reason', normalized_reason
    )
  );
  receipt_result := private.schedule_receipt_result(
    actor_id,
    p_request_id,
    'cancel_schedule_item',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  if target_item.state in ('completed', 'skipped', 'cancelled') then
    raise exception using errcode = '55000', message = 'SCHEDULE_ITEM_TERMINAL';
  end if;
  if target_item.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'ROW_VERSION_CONFLICT';
  end if;

  update public.schedule_items i
  set
    state = 'cancelled',
    state_reason = normalized_reason,
    terminal_at = timezone('utc', now()),
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where i.id = target_item.id
  returning * into target_item;

  update public.schedule_assignments a
  set
    status = 'cancelled',
    cancelled_at = timezone('utc', now()),
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where a.schedule_item_id = target_item.id
    and a.status in ('assigned', 'accepted');

  perform private.write_schedule_change_event(
    target_item.stable_id,
    target_item.series_id,
    target_item.id,
    null,
    null,
    actor_membership.id,
    p_request_id,
    'schedule_item_cancelled',
    target_item.data_category,
    target_item.row_version,
    normalized_reason
  );

  safe_result := jsonb_build_object(
    'schedule_item_id', target_item.id,
    'row_version', target_item.row_version,
    'state', target_item.state,
    'idempotent', false
  );
  insert into private.schedule_mutation_receipts (
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
    'cancel_schedule_item',
    'schedule_item',
    target_item.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.reopen_schedule_item(
  p_schedule_item_id uuid,
  p_expected_row_version bigint,
  p_request_id uuid,
  p_reason text
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
  normalized_reason text := btrim(coalesce(p_reason, ''));
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_expected_row_version is null or p_expected_row_version < 1
    or length(normalized_reason) not between 1 and 500
  then
    raise exception using errcode = '22023', message = 'INVALID_REOPEN';
  end if;

  select i.stable_id, i.horse_id
    into target_stable_id, target_horse_id
  from public.schedule_items i
  where i.id = p_schedule_item_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  actor_membership := private.lock_schedule_context(
    target_stable_id,
    target_horse_id
  );
  if actor_membership.role not in ('owner', 'admin') then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  select * into target_item
  from public.schedule_items i
  where i.id = p_schedule_item_id
    and i.stable_id = target_stable_id
  for update;
  if target_item.id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'schedule_item_id', p_schedule_item_id,
      'expected_row_version', p_expected_row_version,
      'reason', normalized_reason
    )
  );
  receipt_result := private.schedule_receipt_result(
    actor_id,
    p_request_id,
    'reopen_schedule_item',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  if target_item.state not in ('completed', 'skipped', 'cancelled') then
    raise exception using errcode = '55000', message = 'SCHEDULE_ITEM_NOT_TERMINAL';
  end if;
  if target_item.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'ROW_VERSION_CONFLICT';
  end if;

  update public.schedule_items i
  set
    state = 'planned',
    state_reason = normalized_reason,
    terminal_at = null,
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where i.id = target_item.id
  returning * into target_item;

  perform private.write_schedule_change_event(
    target_item.stable_id,
    target_item.series_id,
    target_item.id,
    null,
    null,
    actor_membership.id,
    p_request_id,
    'schedule_item_reopened',
    target_item.data_category,
    target_item.row_version,
    normalized_reason
  );

  safe_result := jsonb_build_object(
    'schedule_item_id', target_item.id,
    'row_version', target_item.row_version,
    'state', target_item.state,
    'idempotent', false
  );
  insert into private.schedule_mutation_receipts (
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
    'reopen_schedule_item',
    'schedule_item',
    target_item.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.assign_schedule_item(
  p_schedule_item_id uuid,
  p_stable_member_id uuid,
  p_assignment_role text,
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
  target_item public.schedule_items%rowtype;
  target_member public.stable_members%rowtype;
  created_assignment public.schedule_assignments%rowtype;
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_assignment_role not in ('responsible', 'support', 'reviewer') then
    raise exception using errcode = '22023', message = 'INVALID_ASSIGNMENT';
  end if;

  select i.stable_id, i.horse_id
    into target_stable_id, target_horse_id
  from public.schedule_items i
  where i.id = p_schedule_item_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  actor_membership := private.lock_schedule_context(
    target_stable_id,
    target_horse_id
  );
  if not private.schedule_membership_can_edit(
    actor_membership,
    target_horse_id
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  select * into target_item
  from public.schedule_items i
  where i.id = p_schedule_item_id
    and i.stable_id = target_stable_id
  for update;
  if target_item.id is null
    or target_item.state in ('completed', 'skipped', 'cancelled')
  then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  select * into target_member
  from public.stable_members sm
  where sm.id = p_stable_member_id
    and sm.stable_id = target_stable_id
  for share;
  if target_member.id is null or target_member.status <> 'active' then
    raise exception using errcode = '42501', message = 'STABLE_MEMBER_UNAVAILABLE';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'schedule_item_id', p_schedule_item_id,
      'stable_member_id', p_stable_member_id,
      'assignment_role', p_assignment_role
    )
  );
  receipt_result := private.schedule_receipt_result(
    actor_id,
    p_request_id,
    'assign_schedule_item',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  begin
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
      target_item.stable_id,
      target_item.id,
      target_member.id,
      p_assignment_role,
      'assigned',
      actor_id,
      p_request_id,
      actor_id,
      p_request_id
    )
    returning * into created_assignment;
  exception when unique_violation then
    raise exception using
      errcode = '23505',
      message = 'ASSIGNMENT_ALREADY_ACTIVE';
  end;

  perform private.write_schedule_change_event(
    target_item.stable_id,
    target_item.series_id,
    target_item.id,
    created_assignment.id,
    null,
    actor_membership.id,
    p_request_id,
    'schedule_assignment_created',
    target_item.data_category,
    created_assignment.row_version
  );

  safe_result := jsonb_build_object(
    'assignment_id', created_assignment.id,
    'row_version', created_assignment.row_version,
    'status', created_assignment.status,
    'idempotent', false
  );
  insert into private.schedule_mutation_receipts (
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
    'assign_schedule_item',
    'schedule_assignment',
    created_assignment.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.return_schedule_assignment(
  p_schedule_assignment_id uuid,
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
  target_item_id uuid;
  target_horse_id uuid;
  actor_membership public.stable_memberships%rowtype;
  target_item public.schedule_items%rowtype;
  target_assignment public.schedule_assignments%rowtype;
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_expected_row_version is null or p_expected_row_version < 1 then
    raise exception using errcode = '22023', message = 'INVALID_ROW_VERSION';
  end if;

  select a.stable_id, a.schedule_item_id, i.horse_id
    into target_stable_id, target_item_id, target_horse_id
  from public.schedule_assignments a
  join public.schedule_items i on i.id = a.schedule_item_id
  where a.id = p_schedule_assignment_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  actor_membership := private.lock_schedule_context(
    target_stable_id,
    target_horse_id
  );

  select * into target_item
  from public.schedule_items i
  where i.id = target_item_id
    and i.stable_id = target_stable_id
  for update;
  select * into target_assignment
  from public.schedule_assignments a
  where a.id = p_schedule_assignment_id
    and a.stable_id = target_stable_id
    and a.schedule_item_id = target_item.id
  for update;

  if target_item.id is null or target_assignment.id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;
  if not (
    actor_membership.stable_member_id = target_assignment.stable_member_id
    or private.schedule_membership_can_edit(
      actor_membership,
      target_horse_id
    )
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'schedule_assignment_id', p_schedule_assignment_id,
      'expected_row_version', p_expected_row_version
    )
  );
  receipt_result := private.schedule_receipt_result(
    actor_id,
    p_request_id,
    'return_schedule_assignment',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  if target_assignment.status not in ('assigned', 'accepted') then
    raise exception using errcode = '55000', message = 'ASSIGNMENT_NOT_ACTIVE';
  end if;
  if target_assignment.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'ROW_VERSION_CONFLICT';
  end if;

  update public.schedule_assignments a
  set
    status = 'returned',
    returned_at = timezone('utc', now()),
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where a.id = target_assignment.id
  returning * into target_assignment;

  perform private.write_schedule_change_event(
    target_item.stable_id,
    target_item.series_id,
    target_item.id,
    target_assignment.id,
    null,
    actor_membership.id,
    p_request_id,
    'schedule_assignment_returned',
    target_item.data_category,
    target_assignment.row_version
  );

  safe_result := jsonb_build_object(
    'assignment_id', target_assignment.id,
    'row_version', target_assignment.row_version,
    'status', target_assignment.status,
    'idempotent', false
  );
  insert into private.schedule_mutation_receipts (
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
    'return_schedule_assignment',
    'schedule_assignment',
    target_assignment.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.record_schedule_execution(
  p_schedule_item_id uuid,
  p_request_id uuid,
  p_execution_status text,
  p_actual_started_at timestamptz,
  p_actual_completed_at timestamptz,
  p_recorded_local_at timestamp,
  p_recorded_timezone text,
  p_source text,
  p_device_instance_id uuid,
  p_note text
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
  created_execution public.schedule_executions%rowtype;
  normalized_timezone text := btrim(coalesce(p_recorded_timezone, ''));
  normalized_note text := nullif(btrim(p_note), '');
  actor_is_assigned boolean := false;
  new_state text;
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_execution_status not in (
    'completed',
    'partial',
    'skipped',
    'refused',
    'problem'
  ) or p_actual_completed_at is null
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
  then
    raise exception using errcode = '22023', message = 'INVALID_EXECUTION';
  end if;

  select i.stable_id, i.horse_id
    into target_stable_id, target_horse_id
  from public.schedule_items i
  where i.id = p_schedule_item_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  actor_membership := private.lock_schedule_context(
    target_stable_id,
    target_horse_id
  );

  select * into target_item
  from public.schedule_items i
  where i.id = p_schedule_item_id
    and i.stable_id = target_stable_id
  for update;
  if target_item.id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  perform 1
  from public.schedule_assignments a
  where a.schedule_item_id = target_item.id
    and a.status in ('assigned', 'accepted')
  order by a.id
  for share;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'schedule_item_id', p_schedule_item_id,
      'execution_status', p_execution_status,
      'actual_started_at', p_actual_started_at,
      'actual_completed_at', p_actual_completed_at,
      'recorded_local_at', p_recorded_local_at,
      'recorded_timezone', normalized_timezone,
      'source', p_source,
      'device_instance_id', p_device_instance_id,
      'note', normalized_note
    )
  );
  receipt_result := private.schedule_receipt_result(
    actor_id,
    p_request_id,
    'record_schedule_execution',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  actor_is_assigned := actor_membership.stable_member_id is not null
    and exists (
      select 1
      from public.schedule_assignments a
      where a.schedule_item_id = target_item.id
        and a.stable_id = target_item.stable_id
        and a.stable_member_id = actor_membership.stable_member_id
        and a.assignment_role in ('responsible', 'support')
        and a.status in ('assigned', 'accepted')
    );
  if not (
    private.schedule_membership_can_execute(
      actor_membership,
      target_horse_id
    )
    or actor_is_assigned
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  if target_item.state in ('completed', 'skipped', 'cancelled') then
    raise exception using errcode = '55000', message = 'SCHEDULE_ITEM_TERMINAL';
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
    note
  )
  values (
    target_item.stable_id,
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
    normalized_note
  )
  returning * into created_execution;

  new_state := case
    when p_execution_status = 'completed' then 'completed'
    when p_execution_status in ('skipped', 'refused') then 'skipped'
    else 'in_progress'
  end;

  update public.schedule_items i
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
  where i.id = target_item.id
  returning * into target_item;

  if actor_is_assigned
    and new_state in ('completed', 'skipped')
  then
    update public.schedule_assignments a
    set
      status = 'completed',
      completed_at = timezone('utc', now()),
      last_mutated_by_user_id = actor_id,
      last_mutation_request_id = p_request_id
    where a.schedule_item_id = target_item.id
      and a.stable_member_id = actor_membership.stable_member_id
      and a.assignment_role in ('responsible', 'support')
      and a.status in ('assigned', 'accepted');
  end if;

  perform private.write_schedule_change_event(
    target_item.stable_id,
    target_item.series_id,
    target_item.id,
    null,
    created_execution.id,
    actor_membership.id,
    p_request_id,
    'schedule_execution_recorded',
    target_item.data_category,
    target_item.row_version
  );

  safe_result := jsonb_build_object(
    'execution_id', created_execution.id,
    'schedule_item_id', target_item.id,
    'schedule_item_row_version', target_item.row_version,
    'state', target_item.state,
    'idempotent', false
  );
  insert into private.schedule_mutation_receipts (
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
    'record_schedule_execution',
    'schedule_execution',
    created_execution.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.correct_schedule_execution(
  p_corrects_execution_id uuid,
  p_request_id uuid,
  p_execution_status text,
  p_actual_started_at timestamptz,
  p_actual_completed_at timestamptz,
  p_recorded_local_at timestamp,
  p_recorded_timezone text,
  p_source text,
  p_device_instance_id uuid,
  p_note text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  target_item_id uuid;
  target_horse_id uuid;
  actor_membership public.stable_memberships%rowtype;
  target_item public.schedule_items%rowtype;
  original_execution public.schedule_executions%rowtype;
  created_execution public.schedule_executions%rowtype;
  normalized_timezone text := btrim(coalesce(p_recorded_timezone, ''));
  normalized_note text := nullif(btrim(p_note), '');
  new_state text;
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_execution_status not in (
    'completed',
    'partial',
    'skipped',
    'refused',
    'problem'
  ) or p_actual_completed_at is null
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
  then
    raise exception using errcode = '22023', message = 'INVALID_EXECUTION';
  end if;

  select e.stable_id, e.schedule_item_id, i.horse_id
    into target_stable_id, target_item_id, target_horse_id
  from public.schedule_executions e
  join public.schedule_items i on i.id = e.schedule_item_id
  where e.id = p_corrects_execution_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  actor_membership := private.lock_schedule_context(
    target_stable_id,
    target_horse_id
  );

  select * into target_item
  from public.schedule_items i
  where i.id = target_item_id
    and i.stable_id = target_stable_id
  for update;
  select * into original_execution
  from public.schedule_executions e
  where e.id = p_corrects_execution_id
    and e.stable_id = target_stable_id
    and e.schedule_item_id = target_item.id
  for share;

  if target_item.id is null or original_execution.id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;
  if not (
    original_execution.actor_user_id = actor_id
    or actor_membership.role in ('owner', 'admin')
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'corrects_execution_id', p_corrects_execution_id,
      'execution_status', p_execution_status,
      'actual_started_at', p_actual_started_at,
      'actual_completed_at', p_actual_completed_at,
      'recorded_local_at', p_recorded_local_at,
      'recorded_timezone', normalized_timezone,
      'source', p_source,
      'device_instance_id', p_device_instance_id,
      'note', normalized_note
    )
  );
  receipt_result := private.schedule_receipt_result(
    actor_id,
    p_request_id,
    'correct_schedule_execution',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  if exists (
    select 1
    from public.schedule_executions e
    where e.corrects_execution_id = original_execution.id
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
    target_item.stable_id,
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
    original_execution.id
  )
  returning * into created_execution;

  new_state := case
    when p_execution_status = 'completed' then 'completed'
    when p_execution_status in ('skipped', 'refused') then 'skipped'
    else 'in_progress'
  end;
  update public.schedule_items i
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
  where i.id = target_item.id
  returning * into target_item;

  perform private.write_schedule_change_event(
    target_item.stable_id,
    target_item.series_id,
    target_item.id,
    null,
    created_execution.id,
    actor_membership.id,
    p_request_id,
    'schedule_execution_corrected',
    target_item.data_category,
    target_item.row_version
  );

  safe_result := jsonb_build_object(
    'execution_id', created_execution.id,
    'corrects_execution_id', original_execution.id,
    'schedule_item_id', target_item.id,
    'schedule_item_row_version', target_item.row_version,
    'state', target_item.state,
    'idempotent', false
  );
  insert into private.schedule_mutation_receipts (
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
    'correct_schedule_execution',
    'schedule_execution',
    created_execution.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function private.schedule_series_matches_date(
  p_series public.schedule_series,
  p_local_date date
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when p_local_date < p_series.starts_on
      or (
        p_series.ends_on is not null
        and p_local_date > p_series.ends_on
      )
      then false
    when p_series.frequency in ('daily', 'interval')
      then mod(
        p_local_date - p_series.starts_on,
        p_series.interval_value
      ) = 0
    when p_series.frequency = 'weekly'
      then
        mod(
          ((p_local_date - p_series.starts_on) / 7),
          p_series.interval_value
        ) = 0
        and extract(isodow from p_local_date)::smallint
          = any(p_series.weekdays)
    else false
  end
$$;

create or replace function public.materialize_schedule_occurrences(
  p_series_id uuid,
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
  target_series public.schedule_series%rowtype;
  created_item public.schedule_items%rowtype;
  next_local_date date;
  upper_local_date date;
  candidate_date date;
  occurrence_start timestamptz;
  occurrence_end timestamptz;
  occurrence_request_id uuid;
  created_count integer := 0;
  payload_hash bytea;
  receipt_result jsonb;
  safe_result jsonb;
begin
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_through_local_date is null then
    raise exception using errcode = '22023', message = 'INVALID_MATERIALIZATION';
  end if;

  select s.stable_id, s.horse_id
    into target_stable_id, target_horse_id
  from public.schedule_series s
  where s.id = p_series_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  actor_membership := private.lock_schedule_context(
    target_stable_id,
    target_horse_id
  );
  if not private.schedule_membership_can_edit(
    actor_membership,
    target_horse_id
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  select * into target_series
  from public.schedule_series s
  where s.id = p_series_id
    and s.stable_id = target_stable_id
  for update;
  if target_series.id is null or target_series.status <> 'active' then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'series_id', p_series_id,
      'through_local_date', p_through_local_date
    )
  );
  receipt_result := private.schedule_receipt_result(
    actor_id,
    p_request_id,
    'materialize_schedule_occurrences',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  select greatest(
    coalesce(
      (
        select max(i.occurrence_local_date) + 1
        from public.schedule_items i
        where i.series_id = target_series.id
      ),
      target_series.starts_on
    ),
    coalesce(
      (
        select max(
          (r.result ->> 'through_local_date')::date
        ) + 1
        from private.schedule_mutation_receipts r
        where r.operation_name = 'materialize_schedule_occurrences'
          and r.target_type = 'schedule_series'
          and r.target_id = target_series.id
          and r.stable_id = target_series.stable_id
          and (r.result ->> 'series_row_version')::bigint
            = target_series.row_version
      ),
      target_series.starts_on
    )
  )
  into next_local_date;

  next_local_date := greatest(next_local_date, target_series.starts_on);
  upper_local_date := least(
    p_through_local_date,
    next_local_date + target_series.generation_horizon_days - 1,
    coalesce(target_series.ends_on, p_through_local_date)
  );
  for candidate_date in
    select generated_date::date
    from generate_series(
      next_local_date,
      upper_local_date,
      interval '1 day'
    ) generated_date
  loop
    if private.schedule_series_matches_date(
      target_series,
      candidate_date
    )
    then
      occurrence_start := pg_catalog.make_timestamptz(
        extract(year from candidate_date)::integer,
        extract(month from candidate_date)::integer,
        extract(day from candidate_date)::integer,
        extract(hour from target_series.local_start_time)::integer,
        extract(minute from target_series.local_start_time)::integer,
        extract(second from target_series.local_start_time),
        target_series.timezone
      );
      occurrence_end := case
        when target_series.duration_minutes is null then null
        else occurrence_start
          + make_interval(mins => target_series.duration_minutes)
      end;
      occurrence_request_id := private.schedule_derived_request_id(
        p_request_id,
        candidate_date::text || ':1'
      );
      created_item := null;

      insert into public.schedule_items (
        stable_id,
        horse_id,
        series_id,
        occurrence_local_date,
        occurrence_sequence,
        item_kind,
        data_category,
        title,
        instruction,
        priority,
        scheduled_start_at,
        scheduled_end_at,
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
        target_series.stable_id,
        target_series.horse_id,
        target_series.id,
        candidate_date,
        1,
        target_series.series_kind,
        target_series.data_category,
        target_series.title,
        target_series.instruction,
        'normal',
        occurrence_start,
        occurrence_end,
        target_series.timezone,
        candidate_date,
        target_series.local_start_time,
        'planned',
        actor_id,
        occurrence_request_id,
        actor_id,
        occurrence_request_id
      )
      on conflict (
        series_id,
        occurrence_local_date,
        occurrence_sequence
      ) where series_id is not null
      do nothing
      returning * into created_item;

      if created_item.id is not null then
        created_count := created_count + 1;
        perform private.write_schedule_change_event(
          created_item.stable_id,
          target_series.id,
          created_item.id,
          null,
          null,
          actor_membership.id,
          occurrence_request_id,
          'schedule_occurrence_materialized',
          created_item.data_category,
          created_item.row_version
        );
      end if;
    end if;
  end loop;

  safe_result := jsonb_build_object(
    'series_id', target_series.id,
    'series_row_version', target_series.row_version,
    'from_local_date', next_local_date,
    'through_local_date', upper_local_date,
    'created_count', created_count,
    'idempotent', false
  );
  insert into private.schedule_mutation_receipts (
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
    target_series.stable_id,
    'materialize_schedule_occurrences',
    'schedule_series',
    target_series.id,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function public.update_schedule_series_scope(
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
  p_status text
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
  target_series public.schedule_series%rowtype;
  replacement_series public.schedule_series%rowtype;
  target_item public.schedule_items%rowtype;
  normalized_title text := btrim(coalesce(p_title, ''));
  normalized_instruction text := btrim(coalesce(p_instruction, ''));
  normalized_timezone text := btrim(coalesce(p_timezone, ''));
  normalized_weekdays smallint[];
  occurrence_start timestamptz;
  occurrence_end timestamptz;
  replacement_request_id uuid;
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
  if p_expected_row_version is null or p_expected_row_version < 1
    or p_scope not in ('occurrence', 'future', 'full')
    or length(normalized_title) not between 1 and 160
    or length(normalized_instruction) not between 1 and 2000
    or length(normalized_timezone) not between 1 and 100
    or not exists (
      select 1
      from pg_catalog.pg_timezone_names zone
      where zone.name = normalized_timezone
    )
    or p_frequency not in ('daily', 'weekly', 'interval')
    or p_interval_value not between 1 and 365
    or (
      p_frequency = 'weekly'
      and (
        normalized_weekdays is null
        or cardinality(normalized_weekdays) not between 1 and 7
        or not (
          normalized_weekdays
          <@ array[1, 2, 3, 4, 5, 6, 7]::smallint[]
        )
      )
    )
    or (p_frequency <> 'weekly' and normalized_weekdays is not null)
    or p_local_start_time is null
    or (
      p_duration_minutes is not null
      and p_duration_minutes not between 0 and 1440
    )
    or p_generation_horizon_days not between 1 and 90
    or p_status not in ('draft', 'active', 'paused', 'ended')
  then
    raise exception using errcode = '22023', message = 'INVALID_SERIES_UPDATE';
  end if;

  select s.stable_id, s.horse_id
    into target_stable_id, target_horse_id
  from public.schedule_series s
  where s.id = p_series_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  actor_membership := private.lock_schedule_context(
    target_stable_id,
    target_horse_id
  );
  if not private.schedule_membership_can_edit(
    actor_membership,
    target_horse_id
  )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  select * into target_series
  from public.schedule_series s
  where s.id = p_series_id
    and s.stable_id = target_stable_id
  for update;
  if target_series.id is null then
    raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
  end if;

  payload_hash := private.schedule_payload_hash(
    jsonb_build_object(
      'series_id', p_series_id,
      'expected_row_version', p_expected_row_version,
      'scope', p_scope,
      'occurrence_item_id', p_occurrence_item_id,
      'effective_local_date', p_effective_local_date,
      'title', normalized_title,
      'instruction', normalized_instruction,
      'timezone', normalized_timezone,
      'frequency', p_frequency,
      'interval_value', p_interval_value,
      'weekdays', normalized_weekdays,
      'local_start_time', p_local_start_time,
      'duration_minutes', p_duration_minutes,
      'ends_on', p_ends_on,
      'generation_horizon_days', p_generation_horizon_days,
      'status', p_status
    )
  );
  receipt_result := private.schedule_receipt_result(
    actor_id,
    p_request_id,
    'update_schedule_series_scope',
    payload_hash
  );
  if receipt_result is not null then return receipt_result; end if;

  if p_scope = 'occurrence' then
    if p_occurrence_item_id is null or p_effective_local_date is null then
      raise exception using errcode = '22023', message = 'INVALID_SERIES_UPDATE';
    end if;

    select * into target_item
    from public.schedule_items i
    where i.id = p_occurrence_item_id
      and i.stable_id = target_series.stable_id
      and i.series_id = target_series.id
      and i.occurrence_local_date = p_effective_local_date
    for update;
    if target_item.id is null then
      raise exception using errcode = '42501', message = 'SCHEDULE_UNAVAILABLE';
    end if;
    if target_item.row_version <> p_expected_row_version then
      raise exception using errcode = '40001', message = 'ROW_VERSION_CONFLICT';
    end if;
    if target_item.state in ('completed', 'skipped', 'cancelled') then
      raise exception using errcode = '55000', message = 'SCHEDULE_ITEM_TERMINAL';
    end if;

    occurrence_start := pg_catalog.make_timestamptz(
      extract(year from p_effective_local_date)::integer,
      extract(month from p_effective_local_date)::integer,
      extract(day from p_effective_local_date)::integer,
      extract(hour from p_local_start_time)::integer,
      extract(minute from p_local_start_time)::integer,
      extract(second from p_local_start_time),
      normalized_timezone
    );
    occurrence_end := case
      when p_duration_minutes is null then null
      else occurrence_start + make_interval(mins => p_duration_minutes)
    end;
    update public.schedule_items i
    set
      title = normalized_title,
      instruction = normalized_instruction,
      scheduled_start_at = occurrence_start,
      scheduled_end_at = occurrence_end,
      source_timezone = normalized_timezone,
      source_local_date = p_effective_local_date,
      source_local_time = p_local_start_time,
      series_override = true,
      last_mutated_by_user_id = actor_id,
      last_mutation_request_id = p_request_id
    where i.id = target_item.id
    returning * into target_item;

    perform private.write_schedule_change_event(
      target_item.stable_id,
      target_series.id,
      target_item.id,
      null,
      null,
      actor_membership.id,
      p_request_id,
      'schedule_item_updated',
      target_item.data_category,
      target_item.row_version
    );
    safe_result := jsonb_build_object(
      'scope', 'occurrence',
      'series_id', target_series.id,
      'schedule_item_id', target_item.id,
      'row_version', target_item.row_version,
      'idempotent', false
    );
  elsif p_scope = 'full' then
    if p_occurrence_item_id is not null
      or exists (
        select 1
        from public.schedule_items i
        where i.series_id = target_series.id
      )
      or (p_ends_on is not null and p_ends_on < target_series.starts_on)
    then
      raise exception using errcode = '55000', message = 'SERIES_HAS_HISTORY';
    end if;
    if target_series.row_version <> p_expected_row_version then
      raise exception using errcode = '40001', message = 'ROW_VERSION_CONFLICT';
    end if;

    update public.schedule_series s
    set
      title = normalized_title,
      instruction = normalized_instruction,
      timezone = normalized_timezone,
      frequency = p_frequency,
      interval_value = p_interval_value,
      weekdays = normalized_weekdays,
      local_start_time = p_local_start_time,
      duration_minutes = p_duration_minutes,
      ends_on = p_ends_on,
      generation_horizon_days = p_generation_horizon_days,
      status = p_status,
      ended_at = case
        when p_status = 'ended' then timezone('utc', now())
        else null
      end,
      last_mutated_by_user_id = actor_id,
      last_mutation_request_id = p_request_id
    where s.id = target_series.id
    returning * into target_series;

    perform private.write_schedule_change_event(
      target_series.stable_id,
      target_series.id,
      null,
      null,
      null,
      actor_membership.id,
      p_request_id,
      'schedule_series_updated',
      target_series.data_category,
      target_series.row_version
    );
    safe_result := jsonb_build_object(
      'scope', 'full',
      'series_id', target_series.id,
      'row_version', target_series.row_version,
      'status', target_series.status,
      'idempotent', false
    );
  else
    if p_occurrence_item_id is not null
      or p_effective_local_date is null
      or p_effective_local_date <= target_series.starts_on
      or (
        target_series.ends_on is not null
        and p_effective_local_date > target_series.ends_on
      )
      or (p_ends_on is not null and p_ends_on < p_effective_local_date)
    then
      raise exception using errcode = '22023', message = 'INVALID_SERIES_UPDATE';
    end if;
    if target_series.row_version <> p_expected_row_version then
      raise exception using errcode = '40001', message = 'ROW_VERSION_CONFLICT';
    end if;

    update public.schedule_items i
    set
      state = 'cancelled',
      state_reason = 'series_replaced',
      terminal_at = timezone('utc', now()),
      last_mutated_by_user_id = actor_id,
      last_mutation_request_id = p_request_id
    where i.series_id = target_series.id
      and i.occurrence_local_date >= p_effective_local_date
      and i.state = 'planned'
      and not exists (
        select 1
        from public.schedule_executions e
        where e.schedule_item_id = i.id
      );

    update public.schedule_assignments a
    set
      status = 'cancelled',
      cancelled_at = timezone('utc', now()),
      last_mutated_by_user_id = actor_id,
      last_mutation_request_id = p_request_id
    where a.schedule_item_id in (
      select i.id
      from public.schedule_items i
      where i.series_id = target_series.id
        and i.occurrence_local_date >= p_effective_local_date
        and i.state = 'cancelled'
        and i.last_mutation_request_id = p_request_id
    )
      and a.status in ('assigned', 'accepted');

    update public.schedule_series s
    set
      ends_on = p_effective_local_date - 1,
      status = 'ended',
      ended_at = timezone('utc', now()),
      last_mutated_by_user_id = actor_id,
      last_mutation_request_id = p_request_id
    where s.id = target_series.id
    returning * into target_series;

    replacement_request_id := private.schedule_derived_request_id(
      p_request_id,
      'replacement-series'
    );
    insert into public.schedule_series (
      stable_id,
      horse_id,
      supersedes_series_id,
      series_kind,
      data_category,
      title,
      instruction,
      timezone,
      frequency,
      interval_value,
      weekdays,
      local_start_time,
      duration_minutes,
      starts_on,
      ends_on,
      status,
      generation_horizon_days,
      created_by_user_id,
      created_request_id,
      last_mutated_by_user_id,
      last_mutation_request_id,
      ended_at
    )
    values (
      target_series.stable_id,
      target_series.horse_id,
      target_series.id,
      target_series.series_kind,
      target_series.data_category,
      normalized_title,
      normalized_instruction,
      normalized_timezone,
      p_frequency,
      p_interval_value,
      normalized_weekdays,
      p_local_start_time,
      p_duration_minutes,
      p_effective_local_date,
      p_ends_on,
      p_status,
      p_generation_horizon_days,
      actor_id,
      replacement_request_id,
      actor_id,
      p_request_id,
      case
        when p_status = 'ended' then timezone('utc', now())
        else null
      end
    )
    returning * into replacement_series;

    perform private.write_schedule_change_event(
      replacement_series.stable_id,
      replacement_series.id,
      null,
      null,
      null,
      actor_membership.id,
      p_request_id,
      'schedule_series_split',
      replacement_series.data_category,
      replacement_series.row_version
    );
    safe_result := jsonb_build_object(
      'scope', 'future',
      'series_id', target_series.id,
      'series_row_version', target_series.row_version,
      'replacement_series_id', replacement_series.id,
      'replacement_row_version', replacement_series.row_version,
      'idempotent', false
    );
  end if;

  insert into private.schedule_mutation_receipts (
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
    target_series.stable_id,
    'update_schedule_series_scope',
    case
      when p_scope = 'occurrence' then 'schedule_item'
      else 'schedule_series'
    end,
    case
      when p_scope = 'occurrence' then target_item.id
      when p_scope = 'future' then replacement_series.id
      else target_series.id
    end,
    payload_hash,
    safe_result
  );
  return safe_result;
end;
$$;

create or replace function private.can_select_schedule_series_base(
  p_schedule_series_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.schedule_series series
    join public.stables stable on stable.id = series.stable_id
    join public.stable_memberships membership
      on membership.stable_id = series.stable_id
     and membership.user_id = auth.uid()
     and membership.status = 'active'
    where series.id = p_schedule_series_id
      and stable.status = 'active'
      and (
        membership.role in ('owner', 'admin')
        or (
          series.horse_id is not null
          and private.has_horse_capability(
            series.horse_id,
            series.data_category,
            'view'
          )
        )
      )
  )
$$;

create or replace function private.can_select_schedule_item_base(
  p_schedule_item_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.schedule_item_access_level(p_schedule_item_id) = 'full'
$$;

create or replace function private.can_select_schedule_assignment_base(
  p_schedule_assignment_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.schedule_assignments assignment
    join public.schedule_items item
      on item.id = assignment.schedule_item_id
    join public.stable_memberships membership
      on membership.stable_id = assignment.stable_id
     and membership.user_id = auth.uid()
     and membership.status = 'active'
    where assignment.id = p_schedule_assignment_id
      and (
        private.schedule_item_access_level(item.id) = 'full'
        or membership.stable_member_id = assignment.stable_member_id
      )
  )
$$;

create or replace function public.get_schedule_item(
  p_schedule_item_id uuid
)
returns table (
  schedule_item_id uuid,
  stable_id uuid,
  horse_id uuid,
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
  state text,
  row_version bigint,
  assignment_role text,
  assignment_status text,
  access_scope text,
  is_overdue boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with access as (
    select private.schedule_item_access_level(p_schedule_item_id) as level
  ),
  actor_membership as (
    select membership.stable_member_id
    from public.schedule_items item
    join public.stable_memberships membership
      on membership.stable_id = item.stable_id
     and membership.user_id = auth.uid()
     and membership.status = 'active'
    where item.id = p_schedule_item_id
  )
  select
    item.id,
    item.stable_id,
    item.horse_id,
    case when access.level = 'full' then item.series_id else null end,
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
    item.state,
    item.row_version,
    own_assignment.assignment_role,
    own_assignment.status,
    access.level,
    item.state in ('planned', 'in_progress')
      and item.scheduled_start_at < pg_catalog.now()
  from public.schedule_items item
  cross join access
  left join actor_membership on true
  left join lateral (
    select assignment.assignment_role, assignment.status
    from public.schedule_assignments assignment
    where assignment.schedule_item_id = item.id
      and assignment.stable_member_id
        = actor_membership.stable_member_id
      and assignment.status in ('assigned', 'accepted', 'completed')
    order by assignment.created_at desc, assignment.id
    limit 1
  ) own_assignment on true
  where item.id = p_schedule_item_id
    and access.level in ('full', 'assigned')
$$;

create or replace function public.list_today_schedule(
  p_stable_id uuid,
  p_local_date date
)
returns table (
  schedule_item_id uuid,
  stable_id uuid,
  horse_id uuid,
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
  state text,
  row_version bigint,
  assignment_role text,
  assignment_status text,
  access_scope text,
  is_overdue boolean
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
      and item.source_local_date = p_local_date
  )
  select
    item.id,
    item.stable_id,
    item.horse_id,
    case
      when item.access_level = 'full' then item.series_id
      else null
    end,
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
    item.state,
    item.row_version,
    own_assignment.assignment_role,
    own_assignment.status,
    item.access_level,
    item.state in ('planned', 'in_progress')
      and item.scheduled_start_at < pg_catalog.now()
  from accessible_items item
  cross join actor_membership
  left join lateral (
    select assignment.assignment_role, assignment.status
    from public.schedule_assignments assignment
    where assignment.schedule_item_id = item.id
      and assignment.stable_member_id
        = actor_membership.stable_member_id
      and assignment.status in ('assigned', 'accepted', 'completed')
    order by assignment.created_at desc, assignment.id
    limit 1
  ) own_assignment on true
  where item.access_level in ('full', 'assigned')
  order by item.scheduled_start_at, item.id
$$;

create or replace function public.list_schedule_executions(
  p_schedule_item_id uuid
)
returns table (
  execution_id uuid,
  schedule_item_id uuid,
  actor_user_id uuid,
  actor_stable_member_id uuid,
  execution_status text,
  actual_started_at timestamptz,
  actual_completed_at timestamptz,
  recorded_local_at timestamp,
  recorded_timezone text,
  source text,
  note text,
  corrects_execution_id uuid,
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with access as (
    select private.schedule_item_access_level(p_schedule_item_id) as level
  )
  select
    execution.id,
    execution.schedule_item_id,
    execution.actor_user_id,
    execution.actor_stable_member_id,
    execution.execution_status,
    execution.actual_started_at,
    execution.actual_completed_at,
    execution.recorded_local_at,
    execution.recorded_timezone,
    execution.source,
    execution.note,
    execution.corrects_execution_id,
    execution.created_at
  from public.schedule_executions execution
  cross join access
  where execution.schedule_item_id = p_schedule_item_id
    and (
      access.level = 'full'
      or (
        access.level = 'assigned'
        and execution.actor_user_id = auth.uid()
      )
    )
  order by execution.created_at, execution.id
$$;

alter table public.schedule_series enable row level security;
alter table public.schedule_items enable row level security;
alter table public.schedule_assignments enable row level security;
alter table public.schedule_executions enable row level security;
alter table public.schedule_change_events enable row level security;

revoke all on table public.schedule_series
  from public, anon, authenticated;
revoke all on table public.schedule_items
  from public, anon, authenticated;
revoke all on table public.schedule_assignments
  from public, anon, authenticated;
revoke all on table public.schedule_executions
  from public, anon, authenticated;
revoke all on table public.schedule_change_events
  from public, anon, authenticated;
revoke all on sequence public.schedule_change_events_id_seq
  from public, anon, authenticated;
revoke all on table private.schedule_mutation_receipts
  from public, anon, authenticated;

grant select on table public.schedule_series to authenticated;
grant select on table public.schedule_items to authenticated;
grant select on table public.schedule_assignments to authenticated;
grant select on table public.schedule_executions to authenticated;
grant select on table public.schedule_change_events to authenticated;

create policy schedule_series_select_full
on public.schedule_series for select to authenticated
using (private.can_select_schedule_series_base(id));

create policy schedule_items_select_full
on public.schedule_items for select to authenticated
using (private.can_select_schedule_item_base(id));

create policy schedule_assignments_select_full_or_own
on public.schedule_assignments for select to authenticated
using (private.can_select_schedule_assignment_base(id));

create policy schedule_executions_select_full_or_own
on public.schedule_executions for select to authenticated
using (
  private.can_select_schedule_item_base(schedule_item_id)
  or (
    actor_user_id = auth.uid()
    and private.schedule_item_access_level(schedule_item_id) = 'assigned'
  )
);

create policy schedule_change_events_select_full
on public.schedule_change_events for select to authenticated
using (
  (
    schedule_item_id is not null
    and private.can_select_schedule_item_base(schedule_item_id)
  )
  or (
    schedule_item_id is null
    and schedule_series_id is not null
    and private.can_select_schedule_series_base(schedule_series_id)
  )
);

revoke all on function private.touch_schedule_series()
  from public, anon, authenticated;
revoke all on function private.touch_schedule_item()
  from public, anon, authenticated;
revoke all on function private.touch_schedule_assignment()
  from public, anon, authenticated;
revoke all on function private.prevent_schedule_append_only_mutation()
  from public, anon, authenticated;
revoke all on function private.schedule_payload_hash(jsonb)
  from public, anon, authenticated;
revoke all on function private.schedule_derived_request_id(uuid, text)
  from public, anon, authenticated;
revoke all on function private.schedule_receipt_result(
  uuid, uuid, text, bytea
) from public, anon, authenticated;
revoke all on function private.lock_schedule_context(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.schedule_membership_can_edit(
  public.stable_memberships, uuid
) from public, anon, authenticated;
revoke all on function private.schedule_membership_can_execute(
  public.stable_memberships, uuid
) from public, anon, authenticated;
revoke all on function private.schedule_item_access_level(uuid)
  from public, anon, authenticated;
revoke all on function private.write_schedule_change_event(
  uuid, uuid, uuid, uuid, uuid, uuid, uuid, text, text, bigint, text
) from public, anon, authenticated;
revoke all on function private.schedule_series_matches_date(
  public.schedule_series, date
) from public, anon, authenticated;
revoke all on function private.can_select_schedule_series_base(uuid)
  from public, anon, authenticated;
revoke all on function private.can_select_schedule_item_base(uuid)
  from public, anon, authenticated;
revoke all on function private.can_select_schedule_assignment_base(uuid)
  from public, anon, authenticated;

grant execute on function private.can_select_schedule_series_base(uuid)
  to authenticated;
grant execute on function private.can_select_schedule_item_base(uuid)
  to authenticated;
grant execute on function private.can_select_schedule_assignment_base(uuid)
  to authenticated;
grant execute on function private.schedule_item_access_level(uuid)
  to authenticated;

revoke execute on function public.create_schedule_series(
  uuid, uuid, text, text, text, text, text, text, integer, smallint[],
  time, integer, date, date, integer, text, uuid
) from public, anon;
revoke execute on function public.update_schedule_series_scope(
  uuid, bigint, text, uuid, date, uuid, text, text, text, text,
  integer, smallint[], time, integer, date, integer, text
) from public, anon;
revoke execute on function public.materialize_schedule_occurrences(
  uuid, date, uuid
) from public, anon;
revoke execute on function public.create_schedule_item(
  uuid, uuid, text, text, text, text, text, timestamptz, timestamptz,
  text, date, time, uuid
) from public, anon;
revoke execute on function public.update_schedule_item(
  uuid, bigint, uuid, text, text, text, timestamptz, timestamptz,
  text, date, time
) from public, anon;
revoke execute on function public.cancel_schedule_item(
  uuid, bigint, uuid, text
) from public, anon;
revoke execute on function public.assign_schedule_item(
  uuid, uuid, text, uuid
) from public, anon;
revoke execute on function public.return_schedule_assignment(
  uuid, bigint, uuid
) from public, anon;
revoke execute on function public.record_schedule_execution(
  uuid, uuid, text, timestamptz, timestamptz, timestamp, text, text,
  uuid, text
) from public, anon;
revoke execute on function public.correct_schedule_execution(
  uuid, uuid, text, timestamptz, timestamptz, timestamp, text, text,
  uuid, text
) from public, anon;
revoke execute on function public.reopen_schedule_item(
  uuid, bigint, uuid, text
) from public, anon;
revoke execute on function public.get_schedule_item(uuid)
  from public, anon;
revoke execute on function public.list_today_schedule(uuid, date)
  from public, anon;
revoke execute on function public.list_schedule_executions(uuid)
  from public, anon;

grant execute on function public.create_schedule_series(
  uuid, uuid, text, text, text, text, text, text, integer, smallint[],
  time, integer, date, date, integer, text, uuid
) to authenticated;
grant execute on function public.update_schedule_series_scope(
  uuid, bigint, text, uuid, date, uuid, text, text, text, text,
  integer, smallint[], time, integer, date, integer, text
) to authenticated;
grant execute on function public.materialize_schedule_occurrences(
  uuid, date, uuid
) to authenticated;
grant execute on function public.create_schedule_item(
  uuid, uuid, text, text, text, text, text, timestamptz, timestamptz,
  text, date, time, uuid
) to authenticated;
grant execute on function public.update_schedule_item(
  uuid, bigint, uuid, text, text, text, timestamptz, timestamptz,
  text, date, time
) to authenticated;
grant execute on function public.cancel_schedule_item(
  uuid, bigint, uuid, text
) to authenticated;
grant execute on function public.assign_schedule_item(
  uuid, uuid, text, uuid
) to authenticated;
grant execute on function public.return_schedule_assignment(
  uuid, bigint, uuid
) to authenticated;
grant execute on function public.record_schedule_execution(
  uuid, uuid, text, timestamptz, timestamptz, timestamp, text, text,
  uuid, text
) to authenticated;
grant execute on function public.correct_schedule_execution(
  uuid, uuid, text, timestamptz, timestamptz, timestamp, text, text,
  uuid, text
) to authenticated;
grant execute on function public.reopen_schedule_item(
  uuid, bigint, uuid, text
) to authenticated;
grant execute on function public.get_schedule_item(uuid)
  to authenticated;
grant execute on function public.list_today_schedule(uuid, date)
  to authenticated;
grant execute on function public.list_schedule_executions(uuid)
  to authenticated;

comment on table public.schedule_series is
  'Phase 4C.3 recurrence definitions. Historical occurrences are separate rows.';
comment on table public.schedule_items is
  'Stable schedule occurrences shared by Plan, Today and Horse detail.';
comment on column public.schedule_items.priority is
  'Only normal/high are enabled; critical remains blocked by P0-05/P0-06.';
comment on table public.schedule_assignments is
  'Roster-based task assignments; an assignment grants only minimal task access.';
comment on table public.schedule_executions is
  'Append-only actual task executions and explicit correction records.';
comment on table public.schedule_change_events is
  'Payload-minimal append-only planning and execution audit trail.';
comment on table private.schedule_mutation_receipts is
  'Private hash-only receipts for durable schedule mutation idempotency.';
comment on function public.get_schedule_item(uuid) is
  'Deep-link read that rechecks full or assigned-minimal access on every call.';
comment on function public.list_today_schedule(uuid, date) is
  'Today read model with full or assigned-minimal field scope.';

commit;
