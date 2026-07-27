begin;

create table public.stable_sync_authorities (
  stable_id uuid primary key references public.stables (id),
  authority_version bigint not null default 1 check (authority_version > 0),
  last_change_sequence bigint not null default 0
    check (last_change_sequence >= 0),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.client_sync_devices (
  id uuid primary key,
  stable_id uuid not null references public.stables (id),
  actor_user_id uuid not null references auth.users (id),
  encryption_public_key text not null
    check (length(encryption_public_key) between 200 and 20000),
  encryption_key_fingerprint bytea not null
    check (octet_length(encryption_key_fingerprint) = 32),
  registered_authority_version bigint not null check (
    registered_authority_version > 0
  ),
  status text not null default 'active'
    check (status in ('active', 'revoked')),
  registered_at timestamptz not null default timezone('utc', now()),
  last_seen_at timestamptz not null default timezone('utc', now()),
  revoked_at timestamptz,
  constraint client_sync_devices_stable_and_id_unique
    unique (stable_id, id),
  constraint client_sync_devices_owner_key_unique
    unique (actor_user_id, stable_id, encryption_key_fingerprint),
  constraint client_sync_devices_revocation_shape check (
    (status = 'active' and revoked_at is null)
    or (status = 'revoked' and revoked_at is not null)
  )
);

create index client_sync_devices_active_actor
  on public.client_sync_devices (actor_user_id, stable_id, id)
  where status = 'active';

create table private.realtime_channel_topics (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  horse_id uuid,
  membership_id uuid,
  data_category text,
  scope_kind text not null
    check (scope_kind in ('stable', 'horse_category', 'membership')),
  topic_token uuid not null default gen_random_uuid() unique,
  authority_version bigint not null check (authority_version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  rotated_at timestamptz not null default timezone('utc', now()),
  constraint realtime_channel_topics_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint realtime_channel_topics_membership_fk
    foreign key (stable_id, membership_id)
    references public.stable_memberships (stable_id, id),
  constraint realtime_channel_topics_shape check (
    (
      scope_kind = 'stable'
      and horse_id is null
      and membership_id is null
      and data_category is null
    )
    or (
      scope_kind = 'horse_category'
      and horse_id is not null
      and membership_id is null
      and data_category in (
        'horse.basic',
        'horse.schedule',
        'horse.nutrition'
      )
    )
    or (
      scope_kind = 'membership'
      and horse_id is null
      and membership_id is not null
      and data_category is null
    )
  )
);

create unique index realtime_channel_topics_scope_unique
  on private.realtime_channel_topics (
    stable_id,
    scope_kind,
    coalesce(horse_id::text, ''),
    coalesce(membership_id::text, ''),
    coalesce(data_category, '')
  );

create table public.stable_change_events (
  stable_id uuid not null references public.stables (id),
  sequence_id bigint not null check (sequence_id > 0),
  horse_id uuid,
  entity_type text not null
    check (
      entity_type in (
        'horse',
        'schedule_series',
        'schedule_item',
        'schedule_assignment',
        'schedule_execution',
        'feeding_plan',
        'feeding_plan_version',
        'feeding_plan_item',
        'legacy_import_job'
      )
    ),
  entity_id uuid not null,
  change_kind text not null
    check (length(change_kind) between 1 and 80),
  data_category text not null
    check (
      data_category in (
        'horse.basic',
        'horse.schedule',
        'horse.nutrition',
        'horse.health_summary',
        'stable.import'
      )
    ),
  row_version bigint check (row_version is null or row_version > 0),
  source_stream text not null
    check (
      source_stream in (
        'horse_profile',
        'schedule',
        'feeding',
        'legacy_import'
      )
    ),
  source_event_id bigint,
  changed_at timestamptz not null default timezone('utc', now()),
  constraint stable_change_events_primary_key
    primary key (stable_id, sequence_id),
  constraint stable_change_events_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint stable_change_events_source_unique
    unique nulls not distinct (source_stream, source_event_id)
);

create index stable_change_events_cursor
  on public.stable_change_events (stable_id, sequence_id);

create index stable_change_events_horse_cursor
  on public.stable_change_events (horse_id, data_category, sequence_id)
  where horse_id is not null;

create table private.client_mutation_receipts (
  actor_user_id uuid not null references auth.users (id),
  request_id uuid not null,
  stable_id uuid not null references public.stables (id),
  operation_name text not null
    check (length(operation_name) between 1 and 80),
  target_type text not null
    check (length(target_type) between 1 and 80),
  target_id uuid,
  payload_hash bytea not null check (octet_length(payload_hash) = 32),
  safe_result jsonb not null check (jsonb_typeof(safe_result) = 'object'),
  target_row_version bigint check (
    target_row_version is null or target_row_version > 0
  ),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (actor_user_id, request_id)
);

create table public.sync_conflicts (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null references auth.users (id),
  stable_id uuid not null references public.stables (id),
  entity_type text not null
    check (entity_type in ('horse_basic_noncritical')),
  entity_id uuid not null,
  base_row_version bigint not null check (base_row_version > 0),
  server_row_version bigint not null check (server_row_version > 0),
  client_patch jsonb not null check (
    jsonb_typeof(client_patch) = 'object'
    and pg_column_size(client_patch) <= 4096
    and client_patch - array[
      'display_name',
      'official_name',
      'birth_date',
      'sex',
      'breed',
      'discipline',
      'level'
    ]::text[] = '{}'::jsonb
  ),
  status text not null default 'open'
    check (
      status in (
        'open',
        'resolved_client',
        'resolved_server',
        'resolved_merged'
      )
    ),
  resolved_by_user_id uuid references auth.users (id),
  resolution_reason text check (
    resolution_reason is null
    or length(btrim(resolution_reason)) between 1 and 500
  ),
  created_at timestamptz not null default timezone('utc', now()),
  resolved_at timestamptz,
  constraint sync_conflicts_resolution_shape check (
    (
      status = 'open'
      and resolved_by_user_id is null
      and resolution_reason is null
      and resolved_at is null
    )
    or (
      status <> 'open'
      and resolved_by_user_id is not null
      and resolution_reason is not null
      and resolved_at is not null
    )
  )
);

create index sync_conflicts_actor_open
  on public.sync_conflicts (actor_user_id, stable_id, created_at, id)
  where status = 'open';

create table public.legacy_import_jobs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid not null references auth.users (id),
  stable_id uuid not null references public.stables (id),
  local_stable_fingerprint bytea not null
    check (octet_length(local_stable_fingerprint) = 32),
  app_version text not null check (length(btrim(app_version)) between 1 and 80),
  schema_version integer not null check (schema_version > 0),
  horse_seed_version integer not null check (horse_seed_version > 0),
  status text not null default 'draft'
    check (
      status in (
        'draft',
        'validated',
        'importing',
        'verified',
        'cutover',
        'failed',
        'rolled_back'
      )
    ),
  source_record_count integer not null check (source_record_count >= 0),
  source_inventory jsonb not null check (
    jsonb_typeof(source_inventory) = 'object'
    and pg_column_size(source_inventory) <= 4096
  ),
  selected_record_count integer not null default 0
    check (selected_record_count >= 0),
  imported_record_count integer not null default 0
    check (imported_record_count >= 0),
  source_manifest_hash bytea not null
    check (octet_length(source_manifest_hash) = 32),
  mapping_manifest_hash bytea
    check (
      mapping_manifest_hash is null
      or octet_length(mapping_manifest_hash) = 32
    ),
  request_id uuid not null,
  row_version bigint not null default 1 check (row_version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  verified_at timestamptz,
  cutover_at timestamptz,
  rolled_back_at timestamptz,
  constraint legacy_import_jobs_request_unique
    unique (actor_user_id, request_id),
  constraint legacy_import_jobs_stable_and_id_unique
    unique (stable_id, id)
);

create table public.legacy_import_items (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null,
  job_id uuid not null,
  entity_type text not null
    check (
      entity_type in (
        'horse',
        'stable_member',
        'schedule_item',
        'feeding_plan',
        'schedule_execution'
      )
    ),
  legacy_local_id text not null
    check (length(legacy_local_id) between 1 and 200),
  cloud_id uuid,
  status text not null default 'pending'
    check (
      status in (
        'pending',
        'excluded_seed',
        'selected',
        'imported',
        'conflict',
        'failed',
        'rolled_back'
      )
    ),
  conflict_code text check (
    conflict_code is null
    or conflict_code in (
      'SOURCE_CONFIRMATION_REQUIRED',
      'UNSUPPORTED_ENTITY',
      'MAPPING_MISSING',
      'SOURCE_HASH_MISMATCH',
      'IMPORT_REJECTED'
    )
  ),
  source_classification text not null
    check (
      source_classification in (
        'user',
        'modified_seed',
        'unmodified_seed',
        'unknown'
      )
    ),
  selected_explicitly boolean not null default false,
  source_hash bytea not null check (octet_length(source_hash) = 32),
  cloud_hash bytea check (
    cloud_hash is null or octet_length(cloud_hash) = 32
  ),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint legacy_import_items_job_fk
    foreign key (stable_id, job_id)
    references public.legacy_import_jobs (stable_id, id),
  constraint legacy_import_items_stable_and_id_unique
    unique (stable_id, id),
  constraint legacy_import_items_local_unique
    unique (job_id, entity_type, legacy_local_id)
);

create table private.legacy_import_payloads (
  item_id uuid primary key references public.legacy_import_items (id),
  payload jsonb not null check (
    jsonb_typeof(payload) = 'object'
    and pg_column_size(payload) <= 32768
  )
);

create table private.legacy_feeding_plan_snapshots (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  job_id uuid not null,
  import_item_id uuid not null unique,
  horse_id uuid not null,
  payload jsonb not null check (
    jsonb_typeof(payload) = 'object'
    and pg_column_size(payload) <= 32768
  ),
  source_hash bytea not null check (octet_length(source_hash) = 32),
  created_at timestamptz not null default timezone('utc', now()),
  constraint legacy_feeding_snapshots_job_fk
    foreign key (stable_id, job_id)
    references public.legacy_import_jobs (stable_id, id),
  constraint legacy_feeding_snapshots_item_fk
    foreign key (stable_id, import_item_id)
    references public.legacy_import_items (stable_id, id),
  constraint legacy_feeding_snapshots_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id)
);

create table private.legacy_schedule_execution_history (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  job_id uuid not null,
  import_item_id uuid not null unique,
  schedule_item_id uuid not null,
  actor_stable_member_id uuid not null,
  execution_status text not null check (
    execution_status in (
      'completed', 'partial', 'skipped', 'refused', 'problem'
    )
  ),
  actual_started_at timestamptz,
  actual_completed_at timestamptz not null,
  recorded_local_at timestamp not null,
  recorded_timezone text not null
    check (length(btrim(recorded_timezone)) between 1 and 100),
  note text check (
    note is null or length(btrim(note)) between 1 and 1000
  ),
  feeding_details jsonb check (
    feeding_details is null
    or (
      jsonb_typeof(feeding_details) = 'object'
      and pg_column_size(feeding_details) <= 4096
    )
  ),
  source_hash bytea not null check (octet_length(source_hash) = 32),
  created_at timestamptz not null default timezone('utc', now()),
  constraint legacy_execution_history_job_fk
    foreign key (stable_id, job_id)
    references public.legacy_import_jobs (stable_id, id),
  constraint legacy_execution_history_item_fk
    foreign key (stable_id, import_item_id)
    references public.legacy_import_items (stable_id, id),
  constraint legacy_execution_history_schedule_fk
    foreign key (stable_id, schedule_item_id)
    references public.schedule_items (stable_id, id),
  constraint legacy_execution_history_member_fk
    foreign key (stable_id, actor_stable_member_id)
    references public.stable_members (stable_id, id),
  constraint legacy_execution_history_time_window check (
    actual_started_at is null
    or actual_completed_at >= actual_started_at
  )
);

create or replace function private.sync_payload_hash(p_payload jsonb)
returns bytea
language sql
immutable
set search_path = ''
as $$
  select extensions.digest(
    pg_catalog.convert_to(p_payload::text, 'UTF8'),
    'sha256'
  )
$$;

create or replace function private.legacy_source_manifest_hash(
  p_source_inventory jsonb,
  p_items jsonb
)
returns bytea
language sql
immutable
set search_path = ''
as $$
  select private.sync_payload_hash(
    jsonb_build_object(
      'source_inventory',
      p_source_inventory,
      'items',
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'entity_type', source_item.value->>'entity_type',
              'legacy_local_id',
                source_item.value->>'legacy_local_id',
              'source_classification',
                source_item.value->>'source_classification',
              'selected',
                coalesce(
                  (source_item.value->>'selected')::boolean,
                  false
                ),
              'source_hash', source_item.value->>'source_hash',
              'payload', source_item.value->'payload'
            )
            order by
              source_item.value->>'entity_type',
              source_item.value->>'legacy_local_id'
          )
          from jsonb_array_elements(p_items) source_item(value)
        ),
        '[]'::jsonb
      )
    )
  )
$$;

create or replace function private.lock_client_request(
  p_actor_user_id uuid,
  p_request_id uuid
)
returns void
language sql
volatile
security definer
set search_path = ''
as $$
  select pg_catalog.pg_advisory_xact_lock(
    hashtextextended(
      p_actor_user_id::text || ':' || p_request_id::text,
      4606
    )
  )
$$;

create or replace function private.active_sync_membership(p_stable_id uuid)
returns public.stable_memberships
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  result public.stable_memberships%rowtype;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  select membership.* into result
  from public.stable_memberships membership
  join public.stables stable on stable.id = membership.stable_id
  where membership.stable_id = p_stable_id
    and membership.user_id = actor_id
    and membership.status = 'active'
    and stable.status = 'active';
  if result.id is null then
    raise exception using errcode = '42501', message = 'SYNC_UNAVAILABLE';
  end if;
  return result;
end;
$$;

create or replace function private.lock_sync_membership(p_stable_id uuid)
returns public.stable_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  result public.stable_memberships%rowtype;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  perform 1
  from public.stables stable
  where stable.id = p_stable_id
    and stable.status = 'active'
  for share;
  if not found then
    raise exception using errcode = '42501', message = 'SYNC_UNAVAILABLE';
  end if;
  select membership.* into result
  from public.stable_memberships membership
  where membership.stable_id = p_stable_id
    and membership.user_id = actor_id
    and membership.status = 'active'
  for share;
  if result.id is null then
    raise exception using errcode = '42501', message = 'SYNC_UNAVAILABLE';
  end if;
  return result;
end;
$$;

create or replace function private.ensure_sync_authority(p_stable_id uuid)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  result bigint;
begin
  insert into public.stable_sync_authorities (stable_id)
  values (p_stable_id)
  on conflict (stable_id) do nothing;
  select authority_version into result
  from public.stable_sync_authorities
  where stable_id = p_stable_id;
  return result;
end;
$$;

create or replace function private.assign_stable_change_sequence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.stable_sync_authorities (stable_id)
  values (new.stable_id)
  on conflict (stable_id) do nothing;
  update public.stable_sync_authorities authority
  set
    last_change_sequence = authority.last_change_sequence + 1,
    updated_at = timezone('utc', now())
  where authority.stable_id = new.stable_id
  returning authority.last_change_sequence into new.sequence_id;
  return new;
end;
$$;

create trigger stable_change_events_assign_sequence
before insert on public.stable_change_events
for each row execute function private.assign_stable_change_sequence();

create or replace function private.rotate_sync_authority()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_stable_id uuid;
  next_version bigint;
begin
  if tg_table_schema = 'public' and tg_table_name = 'stables' then
    target_stable_id := coalesce(new.id, old.id);
  else
    target_stable_id := coalesce(new.stable_id, old.stable_id);
  end if;
  insert into public.stable_sync_authorities (stable_id, authority_version)
  values (target_stable_id, 2)
  on conflict (stable_id) do update
  set
    authority_version =
      public.stable_sync_authorities.authority_version + 1,
    updated_at = timezone('utc', now())
  returning authority_version into next_version;

  update private.realtime_channel_topics
  set
    topic_token = gen_random_uuid(),
    authority_version = next_version,
    rotated_at = timezone('utc', now())
  where stable_id = target_stable_id;

  update public.client_sync_devices
  set
    status = 'revoked',
    revoked_at = timezone('utc', now()),
    last_seen_at = timezone('utc', now())
  where stable_id = target_stable_id
    and status = 'active';
  return null;
end;
$$;

create trigger stable_memberships_rotate_sync_authority
after insert or update of role, status, stable_member_id or delete
on public.stable_memberships
for each row execute function private.rotate_sync_authority();

create trigger horse_access_grants_rotate_sync_authority
after insert or update of status, valid_from, valid_until, can_view,
  can_execute, can_edit, can_manage or delete
on public.horse_access_grants
for each row execute function private.rotate_sync_authority();

create trigger stables_rotate_sync_authority
after update of status on public.stables
for each row
when (old.status is distinct from new.status)
execute function private.rotate_sync_authority();

create trigger horses_rotate_sync_authority
after update of status on public.horses
for each row
when (old.status is distinct from new.status)
execute function private.rotate_sync_authority();

insert into public.stable_sync_authorities (stable_id)
select id from public.stables
on conflict (stable_id) do nothing;

create or replace function private.event_is_visible(
  p_stable_id uuid,
  p_horse_id uuid,
  p_entity_type text,
  p_entity_id uuid,
  p_data_category text
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  membership public.stable_memberships%rowtype;
  target_schedule_item_id uuid;
begin
  select m.* into membership
  from public.stable_memberships m
  join public.stables s on s.id = m.stable_id
  where m.stable_id = p_stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
    and s.status = 'active';
  if membership.id is null then return false; end if;
  if p_data_category = 'stable.import' then
    return exists (
      select 1 from public.legacy_import_jobs j
      where j.id = p_entity_id
        and j.stable_id = p_stable_id
        and j.actor_user_id = auth.uid()
    );
  end if;
  if p_entity_type = 'horse' then
    return private.has_horse_capability(
      p_horse_id,
      p_data_category,
      'view'
    );
  end if;
  if p_entity_type = 'schedule_item' then
    target_schedule_item_id := p_entity_id;
  elsif p_entity_type = 'schedule_assignment' then
    select assignment.schedule_item_id into target_schedule_item_id
    from public.schedule_assignments assignment
    where assignment.id = p_entity_id;
  elsif p_entity_type = 'schedule_execution' then
    select execution.schedule_item_id into target_schedule_item_id
    from public.schedule_executions execution
    where execution.id = p_entity_id;
  elsif p_entity_type in (
    'feeding_plan',
    'feeding_plan_version',
    'feeding_plan_item'
  ) then
    return p_horse_id is not null
      and private.has_horse_capability(
        p_horse_id,
        'horse.nutrition',
        'view'
      );
  elsif p_entity_type = 'schedule_series' then
    return private.can_select_schedule_series_base(p_entity_id);
  end if;
  return target_schedule_item_id is not null
    and private.schedule_item_access_level(target_schedule_item_id) <> 'none';
end;
$$;

create or replace function private.can_join_realtime_topic(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.realtime_channel_topics topic
    join public.stables stable on stable.id = topic.stable_id
    join public.stable_memberships membership
      on membership.stable_id = topic.stable_id
     and membership.user_id = auth.uid()
     and membership.status = 'active'
    join public.stable_sync_authorities authority
      on authority.stable_id = topic.stable_id
     and authority.authority_version = topic.authority_version
    where topic.topic_token::text = p_topic
      and stable.status = 'active'
      and (
        (
          topic.scope_kind = 'stable'
          and membership.role in ('owner', 'admin')
        )
        or (
          topic.scope_kind = 'membership'
          and topic.membership_id = membership.id
        )
        or (
          topic.scope_kind = 'horse_category'
          and private.has_horse_capability(
            topic.horse_id,
            topic.data_category,
            'view'
          )
        )
      )
  )
$$;

create or replace function private.publish_stable_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_authority_version bigint;
  topic_row record;
  target_schedule_item_id uuid;
begin
  current_authority_version := private.ensure_sync_authority(new.stable_id);
  insert into private.realtime_channel_topics (
    stable_id, scope_kind, authority_version
  )
  values (
    new.stable_id,
    'stable',
    current_authority_version
  )
  on conflict (
    stable_id,
    scope_kind,
    (coalesce(horse_id::text, '')),
    (coalesce(membership_id::text, '')),
    (coalesce(data_category, ''))
  ) do nothing;
  perform realtime.send(
    jsonb_build_object(
      'cursor', new.sequence_id,
      'authority_version', current_authority_version
    ),
    'change_available',
    (
      select channel.topic_token::text
      from private.realtime_channel_topics channel
      where channel.stable_id = new.stable_id
        and channel.scope_kind = 'stable'
    ),
    true
  );

  if new.horse_id is not null
    and new.data_category in (
      'horse.basic',
      'horse.schedule',
      'horse.nutrition'
    )
  then
    insert into private.realtime_channel_topics (
      stable_id, horse_id, data_category, scope_kind, authority_version
    )
    values (
      new.stable_id,
      new.horse_id,
      new.data_category,
      'horse_category',
      current_authority_version
    )
    on conflict (
      stable_id,
      scope_kind,
      (coalesce(horse_id::text, '')),
      (coalesce(membership_id::text, '')),
      (coalesce(data_category, ''))
    ) do nothing;

    for topic_row in
      select channel.topic_token
      from private.realtime_channel_topics channel
      where channel.stable_id = new.stable_id
        and channel.horse_id = new.horse_id
        and channel.data_category = new.data_category
        and channel.scope_kind = 'horse_category'
        and channel.authority_version = current_authority_version
    loop
      perform realtime.send(
        jsonb_build_object(
          'cursor', new.sequence_id,
          'authority_version', current_authority_version
        ),
        'change_available',
        topic_row.topic_token::text,
        true
      );
    end loop;
  end if;

  if new.entity_type = 'schedule_item' then
    target_schedule_item_id := new.entity_id;
  elsif new.entity_type = 'schedule_assignment' then
    select schedule_item_id into target_schedule_item_id
    from public.schedule_assignments where id = new.entity_id;
  elsif new.entity_type = 'schedule_execution' then
    select schedule_item_id into target_schedule_item_id
    from public.schedule_executions where id = new.entity_id;
  end if;

  if target_schedule_item_id is not null then
    for topic_row in
      select distinct membership.id as membership_id
      from public.schedule_assignments assignment
      join public.stable_memberships membership
        on membership.stable_id = assignment.stable_id
       and membership.stable_member_id = assignment.stable_member_id
       and membership.status = 'active'
      where assignment.schedule_item_id = target_schedule_item_id
        and (
          assignment.status in ('assigned', 'accepted', 'completed')
          or (
            new.entity_type = 'schedule_assignment'
            and assignment.id = new.entity_id
          )
        )
    loop
      insert into private.realtime_channel_topics (
        stable_id, membership_id, scope_kind, authority_version
      )
      values (
        new.stable_id,
        topic_row.membership_id,
        'membership',
        current_authority_version
      )
      on conflict (
        stable_id,
        scope_kind,
        (coalesce(horse_id::text, '')),
        (coalesce(membership_id::text, '')),
        (coalesce(data_category, ''))
      ) do nothing;
      perform realtime.send(
        jsonb_build_object(
          'cursor', new.sequence_id,
          'authority_version', current_authority_version
        ),
        'change_available',
        (
          select channel.topic_token::text
          from private.realtime_channel_topics channel
          where channel.stable_id = new.stable_id
            and channel.membership_id = topic_row.membership_id
            and channel.scope_kind = 'membership'
        ),
        true
      );
    end loop;
  end if;
  return new;
end;
$$;

create or replace function private.capture_horse_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.stable_change_events (
    stable_id, horse_id, entity_type, entity_id, change_kind,
    data_category, row_version, source_stream, source_event_id, changed_at
  )
  select
    new.stable_id,
    new.horse_id,
    'horse',
    new.horse_id,
    new.event_type,
    'horse.basic',
    horse.row_version,
    'horse_profile',
    new.id,
    new.created_at
  from public.horses horse
  where horse.id = new.horse_id
  on conflict (source_stream, source_event_id) do nothing;
  return new;
end;
$$;

create trigger horse_profile_changes_feed
after insert on public.horse_profile_change_events
for each row execute function private.capture_horse_change();

create or replace function private.capture_schedule_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  entity_type text;
  entity_id uuid;
  target_horse_id uuid;
begin
  if new.schedule_execution_id is not null then
    entity_type := 'schedule_execution';
    entity_id := new.schedule_execution_id;
  elsif new.schedule_assignment_id is not null then
    entity_type := 'schedule_assignment';
    entity_id := new.schedule_assignment_id;
  elsif new.schedule_item_id is not null then
    entity_type := 'schedule_item';
    entity_id := new.schedule_item_id;
  else
    entity_type := 'schedule_series';
    entity_id := new.schedule_series_id;
  end if;
  if new.schedule_item_id is not null then
    select horse_id into target_horse_id
    from public.schedule_items where id = new.schedule_item_id;
  elsif new.schedule_series_id is not null then
    select horse_id into target_horse_id
    from public.schedule_series where id = new.schedule_series_id;
  end if;
  insert into public.stable_change_events (
    stable_id, horse_id, entity_type, entity_id, change_kind,
    data_category, row_version, source_stream, source_event_id, changed_at
  )
  values (
    new.stable_id,
    target_horse_id,
    entity_type,
    entity_id,
    new.event_type,
    new.data_category,
    new.row_version,
    'schedule',
    new.id,
    new.created_at
  )
  on conflict (source_stream, source_event_id) do nothing;
  return new;
end;
$$;

create trigger schedule_changes_feed
after insert on public.schedule_change_events
for each row execute function private.capture_schedule_change();

create or replace function private.capture_feeding_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  entity_type text;
  entity_id uuid;
begin
  if new.execution_id is not null then
    entity_type := 'schedule_execution';
    entity_id := new.execution_id;
  elsif new.feeding_plan_item_id is not null then
    entity_type := 'feeding_plan_item';
    entity_id := new.feeding_plan_item_id;
  elsif new.feeding_plan_version_id is not null then
    entity_type := 'feeding_plan_version';
    entity_id := new.feeding_plan_version_id;
  else
    entity_type := 'feeding_plan';
    entity_id := new.feeding_plan_id;
  end if;
  insert into public.stable_change_events (
    stable_id, horse_id, entity_type, entity_id, change_kind,
    data_category, row_version, source_stream, source_event_id, changed_at
  )
  values (
    new.stable_id,
    new.horse_id,
    entity_type,
    entity_id,
    new.event_type,
    'horse.nutrition',
    new.row_version,
    'feeding',
    new.id,
    new.created_at
  )
  on conflict (source_stream, source_event_id) do nothing;
  return new;
end;
$$;

create trigger feeding_changes_feed
after insert on public.feeding_change_events
for each row execute function private.capture_feeding_change();

insert into public.stable_change_events (
  stable_id, horse_id, entity_type, entity_id, change_kind,
  data_category, row_version, source_stream, source_event_id, changed_at
)
select
  event.stable_id, event.horse_id, 'horse', event.horse_id,
  event.event_type, 'horse.basic', horse.row_version,
  'horse_profile', event.id, event.created_at
from public.horse_profile_change_events event
join public.horses horse on horse.id = event.horse_id
on conflict (source_stream, source_event_id) do nothing;

insert into public.stable_change_events (
  stable_id, horse_id, entity_type, entity_id, change_kind,
  data_category, row_version, source_stream, source_event_id, changed_at
)
select
  event.stable_id,
  coalesce(item.horse_id, series.horse_id),
  case
    when event.schedule_execution_id is not null then 'schedule_execution'
    when event.schedule_assignment_id is not null then 'schedule_assignment'
    when event.schedule_item_id is not null then 'schedule_item'
    else 'schedule_series'
  end,
  coalesce(
    event.schedule_execution_id,
    event.schedule_assignment_id,
    event.schedule_item_id,
    event.schedule_series_id
  ),
  event.event_type,
  event.data_category,
  event.row_version,
  'schedule',
  event.id,
  event.created_at
from public.schedule_change_events event
left join public.schedule_items item on item.id = event.schedule_item_id
left join public.schedule_series series on series.id = event.schedule_series_id
on conflict (source_stream, source_event_id) do nothing;

insert into public.stable_change_events (
  stable_id, horse_id, entity_type, entity_id, change_kind,
  data_category, row_version, source_stream, source_event_id, changed_at
)
select
  event.stable_id,
  event.horse_id,
  case
    when event.execution_id is not null then 'schedule_execution'
    when event.feeding_plan_item_id is not null then 'feeding_plan_item'
    when event.feeding_plan_version_id is not null then 'feeding_plan_version'
    else 'feeding_plan'
  end,
  coalesce(
    event.execution_id,
    event.feeding_plan_item_id,
    event.feeding_plan_version_id,
    event.feeding_plan_id
  ),
  event.event_type,
  'horse.nutrition',
  event.row_version,
  'feeding',
  event.id,
  event.created_at
from public.feeding_change_events event
on conflict (source_stream, source_event_id) do nothing;

create trigger stable_change_events_publish
after insert on public.stable_change_events
for each row execute function private.publish_stable_change();

create or replace function public.get_realtime_topics(p_stable_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  membership public.stable_memberships%rowtype;
  current_authority_version bigint;
  result jsonb;
begin
  membership := private.lock_sync_membership(p_stable_id);
  current_authority_version := private.ensure_sync_authority(p_stable_id);

  if membership.role in ('owner', 'admin') then
    insert into private.realtime_channel_topics (
      stable_id, scope_kind, authority_version
    )
    values (p_stable_id, 'stable', current_authority_version)
    on conflict (
      stable_id,
      scope_kind,
      (coalesce(horse_id::text, '')),
      (coalesce(membership_id::text, '')),
      (coalesce(data_category, ''))
    ) do nothing;
  end if;

  insert into private.realtime_channel_topics (
    stable_id, membership_id, scope_kind, authority_version
  )
  values (
    p_stable_id,
    membership.id,
    'membership',
    current_authority_version
  )
  on conflict (
    stable_id,
    scope_kind,
    (coalesce(horse_id::text, '')),
    (coalesce(membership_id::text, '')),
    (coalesce(data_category, ''))
  ) do nothing;

  insert into private.realtime_channel_topics (
    stable_id, horse_id, data_category, scope_kind, authority_version
  )
  select
    horse.stable_id,
    horse.id,
    category.name,
    'horse_category',
    current_authority_version
  from public.horses horse
  cross join (
    values ('horse.basic'), ('horse.schedule'), ('horse.nutrition')
  ) category(name)
  where horse.stable_id = p_stable_id
    and horse.status = 'active'
    and private.has_horse_capability(horse.id, category.name, 'view')
  on conflict (
    stable_id,
    scope_kind,
    (coalesce(horse_id::text, '')),
    (coalesce(membership_id::text, '')),
    (coalesce(data_category, ''))
  ) do nothing;

  select jsonb_build_object(
    'authority_version', current_authority_version,
    'topics',
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'topic', topic.topic_token,
          'scope', topic.scope_kind,
          'data_category', topic.data_category
        )
        order by topic.scope_kind, topic.data_category, topic.topic_token
      ),
      '[]'::jsonb
    )
  ) into result
  from private.realtime_channel_topics topic
  where topic.stable_id = p_stable_id
    and topic.authority_version = current_authority_version
    and (
      (topic.scope_kind = 'stable' and membership.role in ('owner', 'admin'))
      or (
        topic.scope_kind = 'membership'
        and topic.membership_id = membership.id
      )
      or (
        topic.scope_kind = 'horse_category'
        and private.has_horse_capability(
          topic.horse_id,
          topic.data_category,
          'view'
        )
      )
    );
  return result;
end;
$$;

create or replace function public.pull_operation_changes(
  p_stable_id uuid,
  p_after_sequence bigint,
  p_limit integer,
  p_expected_authority_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  membership public.stable_memberships%rowtype;
  current_authority_version bigint;
  high_water bigint;
  result jsonb;
begin
  membership := private.lock_sync_membership(p_stable_id);
  current_authority_version := private.ensure_sync_authority(p_stable_id);
  if p_expected_authority_version is null
    or p_expected_authority_version <> current_authority_version
  then
    raise exception using errcode = '42501', message = 'SYNC_RESET_REQUIRED';
  end if;
  if p_after_sequence is null or p_after_sequence < 0
    or p_limit is null or p_limit not between 1 and 500
  then
    raise exception using errcode = '22023', message = 'INVALID_SYNC_CURSOR';
  end if;
  select coalesce(max(sequence_id), p_after_sequence) into high_water
  from public.stable_change_events
  where stable_id = p_stable_id;
  select jsonb_build_object(
    'authority_version', current_authority_version,
    'next_cursor',
      case
        when count(visible.sequence_id) = p_limit
          then max(visible.sequence_id)
        else high_water
      end,
    'changes',
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'sequence_id', visible.sequence_id,
          'entity_type', visible.entity_type,
          'entity_id', visible.entity_id,
          'change_kind', visible.change_kind,
          'data_category', visible.data_category,
          'row_version', visible.row_version,
          'changed_at', visible.changed_at
        )
        order by visible.sequence_id
      ),
      '[]'::jsonb
    )
  ) into result
  from (
    select event.*
    from public.stable_change_events event
    where event.stable_id = p_stable_id
      and event.sequence_id > p_after_sequence
      and private.event_is_visible(
        event.stable_id,
        event.horse_id,
        event.entity_type,
        event.entity_id,
        event.data_category
      )
    order by event.sequence_id
    limit p_limit
  ) visible;
  return result;
end;
$$;

create or replace function public.register_sync_device(
  p_stable_id uuid,
  p_device_instance_id uuid,
  p_encryption_public_key text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  membership public.stable_memberships%rowtype;
  current_authority_version bigint;
  normalized_key text := btrim(coalesce(p_encryption_public_key, ''));
  key_fingerprint bytea;
  request_payload_hash bytea;
  receipt private.client_mutation_receipts%rowtype;
  result jsonb;
begin
  if p_request_id is null or p_device_instance_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  membership := private.lock_sync_membership(p_stable_id);
  if length(normalized_key) not between 200 and 20000
    or position('BEGIN PGP PUBLIC KEY BLOCK' in normalized_key) = 0
    or position('END PGP PUBLIC KEY BLOCK' in normalized_key) = 0
  then
    raise exception using errcode = '22023', message = 'INVALID_DEVICE_KEY';
  end if;
  current_authority_version := private.ensure_sync_authority(p_stable_id);
  key_fingerprint := extensions.digest(
    pg_catalog.convert_to(normalized_key, 'UTF8'),
    'sha256'
  );
  request_payload_hash := private.sync_payload_hash(
    jsonb_build_object(
      'stable_id', p_stable_id,
      'device_instance_id', p_device_instance_id,
      'encryption_key_fingerprint', encode(key_fingerprint, 'hex')
    )
  );
  perform private.lock_client_request(actor_id, p_request_id);
  select * into receipt
  from private.client_mutation_receipts
  where actor_user_id = actor_id and request_id = p_request_id;
  if receipt.actor_user_id is not null then
    if receipt.operation_name = 'register_sync_device'
      and receipt.payload_hash = request_payload_hash
    then
      return receipt.safe_result || jsonb_build_object('idempotent', true);
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  insert into public.client_sync_devices (
    id, stable_id, actor_user_id, encryption_public_key,
    encryption_key_fingerprint, registered_authority_version
  )
  values (
    p_device_instance_id, p_stable_id, actor_id, normalized_key,
    key_fingerprint, current_authority_version
  )
  on conflict (id) do update
  set
    encryption_public_key = excluded.encryption_public_key,
    encryption_key_fingerprint = excluded.encryption_key_fingerprint,
    registered_authority_version = excluded.registered_authority_version,
    status = 'active',
    revoked_at = null,
    last_seen_at = timezone('utc', now())
  where public.client_sync_devices.actor_user_id = actor_id
    and public.client_sync_devices.stable_id = p_stable_id;
  if not found then
    raise exception using errcode = '42501', message = 'DEVICE_UNAVAILABLE';
  end if;
  result := jsonb_build_object(
    'device_instance_id', p_device_instance_id,
    'authority_version', current_authority_version,
    'key_fingerprint', encode(key_fingerprint, 'hex'),
    'idempotent', false
  );
  insert into private.client_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name,
    target_type, target_id, payload_hash, safe_result
  )
  values (
    actor_id, p_request_id, p_stable_id, 'register_sync_device',
    'client_sync_device', p_device_instance_id, request_payload_hash, result
  );
  return result;
end;
$$;

create or replace function private.require_sync_device(
  p_device_instance_id uuid,
  p_stable_id uuid,
  p_expected_authority_version bigint
)
returns public.client_sync_devices
language plpgsql
security definer
set search_path = ''
as $$
declare
  device public.client_sync_devices%rowtype;
  current_version bigint;
begin
  perform private.lock_sync_membership(p_stable_id);
  current_version := private.ensure_sync_authority(p_stable_id);
  select * into device
  from public.client_sync_devices
  where id = p_device_instance_id
    and stable_id = p_stable_id
    and actor_user_id = auth.uid()
    and status = 'active'
    and registered_authority_version = current_version;
  if device.id is null
    or p_expected_authority_version is null
    or p_expected_authority_version <> current_version
  then
    raise exception using errcode = '42501', message = 'SYNC_RESET_REQUIRED';
  end if;
  return device;
end;
$$;

create or replace function private.enforce_offline_execution_device()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_version bigint;
begin
  if new.source <> 'offline_sync' then return new; end if;
  current_version := private.ensure_sync_authority(new.stable_id);
  if not exists (
    select 1
    from public.client_sync_devices device
    where device.id = new.device_instance_id
      and device.stable_id = new.stable_id
      and device.actor_user_id = new.actor_user_id
      and device.status = 'active'
      and device.registered_authority_version = current_version
  ) then
    raise exception using errcode = '42501', message = 'SYNC_RESET_REQUIRED';
  end if;
  return new;
end;
$$;

create trigger schedule_executions_require_sync_device
before insert on public.schedule_executions
for each row execute function private.enforce_offline_execution_device();

create or replace function private.reserve_execution_request_namespace()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  receipt private.client_mutation_receipts%rowtype;
  reservation_hash bytea;
begin
  if actor_id is null
    or (
      session_user = 'postgres'
      and coalesce(current_setting('role', true), 'none')
        in ('none', 'postgres', 'service_role')
    )
  then
    return new;
  end if;
  if actor_id <> new.actor_user_id then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  perform private.lock_client_request(actor_id, new.request_id);
  select * into receipt
  from private.client_mutation_receipts
  where actor_user_id = actor_id and request_id = new.request_id;
  if receipt.actor_user_id is not null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  reservation_hash := private.sync_payload_hash(
    jsonb_build_object(
      'stable_id', new.stable_id,
      'schedule_item_id', new.schedule_item_id,
      'execution_status', new.execution_status,
      'source', new.source,
      'device_instance_id', new.device_instance_id
    )
  );
  insert into private.client_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name,
    target_type, target_id, payload_hash, safe_result
  )
  values (
    actor_id, new.request_id, new.stable_id,
    'execution_request_reserved', 'schedule_execution', new.id,
    reservation_hash, jsonb_build_object('reserved', true)
  );
  return new;
end;
$$;

create trigger schedule_executions_reserve_request_namespace
before insert on public.schedule_executions
for each row execute function private.reserve_execution_request_namespace();

create or replace function public.get_encrypted_offline_dayset(
  p_stable_id uuid,
  p_device_instance_id uuid,
  p_local_date date,
  p_timezone text,
  p_expected_authority_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  membership public.stable_memberships%rowtype;
  device public.client_sync_devices%rowtype;
  normalized_timezone text := btrim(coalesce(p_timezone, ''));
  plaintext jsonb;
  ciphertext text;
  expires_at timestamptz := timezone('utc', now()) + interval '36 hours';
begin
  membership := private.lock_sync_membership(p_stable_id);
  device := private.require_sync_device(
    p_device_instance_id,
    p_stable_id,
    p_expected_authority_version
  );
  if p_local_date is null
    or length(normalized_timezone) not between 1 and 100
    or not exists (
      select 1 from pg_catalog.pg_timezone_names zone
      where zone.name = normalized_timezone
    )
  then
    raise exception using errcode = '22023', message = 'INVALID_DAYSET';
  end if;
  select jsonb_build_object(
    'stable_id', p_stable_id,
    'local_date', p_local_date,
    'timezone', normalized_timezone,
    'authority_version', p_expected_authority_version,
    'expires_at', expires_at,
    'cache_policy', 'encrypted_assigned_dayset_only',
    'schedule_items',
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'schedule_item_id', item.id,
          'horse_id', item.horse_id,
          'item_kind', item.item_kind,
          'data_category', item.data_category,
          'title', item.title,
          'instruction', item.instruction,
          'priority', item.priority,
          'scheduled_start_at', item.scheduled_start_at,
          'scheduled_end_at', item.scheduled_end_at,
          'source_timezone', item.source_timezone,
          'source_local_date', item.source_local_date,
          'source_local_time', item.source_local_time,
          'state', item.state,
          'row_version', item.row_version,
          'assignment_role', assignment.assignment_role,
          'assignment_status', assignment.status
        )
        order by item.scheduled_start_at, item.id
      ),
      '[]'::jsonb
    )
  ) into plaintext
  from public.schedule_assignments assignment
  join public.schedule_items item
    on item.id = assignment.schedule_item_id
   and item.stable_id = assignment.stable_id
  left join public.horses horse
    on horse.id = item.horse_id
   and horse.stable_id = item.stable_id
  where assignment.stable_id = p_stable_id
    and assignment.stable_member_id = membership.stable_member_id
    and assignment.status in ('assigned', 'accepted')
    and (item.horse_id is null or horse.status = 'active')
    and private.schedule_item_access_level(item.id) <> 'none'
    and item.source_local_date = p_local_date
    and item.state in ('planned', 'in_progress')
    and item.priority in ('normal', 'high');
  begin
    ciphertext := encode(
      extensions.pgp_pub_encrypt(
        plaintext::text,
        extensions.dearmor(device.encryption_public_key),
        'cipher-algo=aes256,compress-algo=1'
      ),
      'base64'
    );
  exception when others then
    raise exception using errcode = '22023', message = 'INVALID_DEVICE_KEY';
  end;
  return jsonb_build_object(
    'format', 'openpgp-aes256',
    'ciphertext', ciphertext,
    'authority_version', p_expected_authority_version,
    'expires_at', expires_at,
    'cache_directive', 'store_ciphertext_only'
  );
end;
$$;

create or replace function public.sync_schedule_execution(
  p_stable_id uuid,
  p_device_instance_id uuid,
  p_expected_authority_version bigint,
  p_schedule_item_id uuid,
  p_request_id uuid,
  p_execution_status text,
  p_actual_started_at timestamptz,
  p_actual_completed_at timestamptz,
  p_recorded_local_at timestamp,
  p_recorded_timezone text,
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
  request_payload_hash bytea;
  receipt private.client_mutation_receipts%rowtype;
  result jsonb;
begin
  select stable_id into target_stable_id
  from public.schedule_items where id = p_schedule_item_id;
  if target_stable_id is null or target_stable_id <> p_stable_id then
    raise exception using errcode = '42501', message = 'SYNC_UNAVAILABLE';
  end if;
  perform private.require_sync_device(
    p_device_instance_id,
    p_stable_id,
    p_expected_authority_version
  );
  request_payload_hash := private.sync_payload_hash(
    jsonb_build_object(
      'stable_id', p_stable_id,
      'device_instance_id', p_device_instance_id,
      'expected_authority_version', p_expected_authority_version,
      'schedule_item_id', p_schedule_item_id,
      'execution_status', p_execution_status,
      'actual_started_at', p_actual_started_at,
      'actual_completed_at', p_actual_completed_at,
      'recorded_local_at', p_recorded_local_at,
      'recorded_timezone', btrim(p_recorded_timezone),
      'note', nullif(btrim(p_note), '')
    )
  );
  perform private.lock_client_request(actor_id, p_request_id);
  select * into receipt
  from private.client_mutation_receipts
  where actor_user_id = actor_id and request_id = p_request_id;
  if receipt.actor_user_id is not null then
    if receipt.operation_name = 'sync_schedule_execution'
      and receipt.payload_hash = request_payload_hash
    then
      return receipt.safe_result || jsonb_build_object('idempotent', true);
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  result := public.record_schedule_execution(
    p_schedule_item_id,
    p_request_id,
    p_execution_status,
    p_actual_started_at,
    p_actual_completed_at,
    p_recorded_local_at,
    p_recorded_timezone,
    'offline_sync',
    p_device_instance_id,
    p_note
  );
  update public.client_sync_devices
  set last_seen_at = timezone('utc', now())
  where id = p_device_instance_id
    and stable_id = p_stable_id
    and actor_user_id = auth.uid()
    and status = 'active';
  update private.client_mutation_receipts
  set
    operation_name = 'sync_schedule_execution',
    payload_hash = request_payload_hash,
    safe_result = result,
    target_row_version =
      (result->>'schedule_item_row_version')::bigint
  where actor_user_id = actor_id
    and request_id = p_request_id
    and operation_name = 'execution_request_reserved'
    and target_id = (result->>'execution_id')::uuid;
  if not found then
    raise exception using
      errcode = '55000',
      message = 'REQUEST_RECEIPT_MISSING';
  end if;
  return result;
end;
$$;

create or replace function public.sync_feeding_execution(
  p_stable_id uuid,
  p_device_instance_id uuid,
  p_expected_authority_version bigint,
  p_schedule_item_id uuid,
  p_request_id uuid,
  p_execution_status text,
  p_actual_started_at timestamptz,
  p_actual_completed_at timestamptz,
  p_recorded_local_at timestamp,
  p_recorded_timezone text,
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
  request_payload_hash bytea;
  receipt private.client_mutation_receipts%rowtype;
  result jsonb;
begin
  select item.stable_id into target_stable_id
  from public.schedule_items item
  join public.feeding_occurrences occurrence
    on occurrence.schedule_item_id = item.id
   and occurrence.stable_id = item.stable_id
  where item.id = p_schedule_item_id;
  if target_stable_id is null or target_stable_id <> p_stable_id then
    raise exception using errcode = '42501', message = 'SYNC_UNAVAILABLE';
  end if;
  perform private.require_sync_device(
    p_device_instance_id,
    p_stable_id,
    p_expected_authority_version
  );
  request_payload_hash := private.sync_payload_hash(
    jsonb_build_object(
      'stable_id', p_stable_id,
      'device_instance_id', p_device_instance_id,
      'expected_authority_version', p_expected_authority_version,
      'schedule_item_id', p_schedule_item_id,
      'execution_status', p_execution_status,
      'actual_started_at', p_actual_started_at,
      'actual_completed_at', p_actual_completed_at,
      'recorded_local_at', p_recorded_local_at,
      'recorded_timezone', btrim(p_recorded_timezone),
      'note', nullif(btrim(p_note), ''),
      'actual_quantity', p_actual_quantity,
      'unit_code', p_unit_code,
      'remaining_quantity', p_remaining_quantity,
      'deviation_code', p_deviation_code,
      'observation', nullif(btrim(p_observation), ''),
      'batch_lot', nullif(btrim(p_batch_lot), '')
    )
  );
  perform private.lock_client_request(actor_id, p_request_id);
  select * into receipt
  from private.client_mutation_receipts
  where actor_user_id = actor_id and request_id = p_request_id;
  if receipt.actor_user_id is not null then
    if receipt.operation_name = 'sync_feeding_execution'
      and receipt.payload_hash = request_payload_hash
    then
      return receipt.safe_result || jsonb_build_object('idempotent', true);
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  result := public.record_feeding_execution(
    p_schedule_item_id,
    null,
    p_request_id,
    p_execution_status,
    p_actual_started_at,
    p_actual_completed_at,
    p_recorded_local_at,
    p_recorded_timezone,
    'offline_sync',
    p_device_instance_id,
    p_note,
    p_actual_quantity,
    p_unit_code,
    p_remaining_quantity,
    p_deviation_code,
    p_observation,
    p_batch_lot
  );
  update public.client_sync_devices
  set last_seen_at = timezone('utc', now())
  where id = p_device_instance_id
    and stable_id = p_stable_id
    and actor_user_id = actor_id
    and status = 'active';
  update private.client_mutation_receipts
  set
    operation_name = 'sync_feeding_execution',
    payload_hash = request_payload_hash,
    safe_result = result,
    target_row_version =
      (result->>'schedule_item_row_version')::bigint
  where actor_user_id = actor_id
    and request_id = p_request_id
    and operation_name = 'execution_request_reserved'
    and target_id = (result->>'execution_id')::uuid;
  if not found then
    raise exception using
      errcode = '55000',
      message = 'REQUEST_RECEIPT_MISSING';
  end if;
  return result;
end;
$$;

create or replace function public.resolve_sync_conflict(
  p_conflict_id uuid,
  p_resolution text,
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
  conflict public.sync_conflicts%rowtype;
  membership public.stable_memberships%rowtype;
  payload_hash bytea;
  receipt private.client_mutation_receipts%rowtype;
  result jsonb;
begin
  if p_request_id is null
    or p_resolution not in (
      'resolved_client', 'resolved_server', 'resolved_merged'
    )
    or length(btrim(coalesce(p_reason, ''))) not between 1 and 500
  then
    raise exception using errcode = '22023', message = 'INVALID_RESOLUTION';
  end if;
  select * into conflict
  from public.sync_conflicts where id = p_conflict_id;
  if conflict.id is null then
    raise exception using errcode = '42501', message = 'CONFLICT_UNAVAILABLE';
  end if;
  membership := private.lock_sync_membership(conflict.stable_id);
  select * into conflict
  from public.sync_conflicts
  where id = p_conflict_id
    and stable_id = conflict.stable_id
  for update;
  if conflict.actor_user_id <> actor_id
    and membership.role not in ('owner', 'admin')
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  payload_hash := private.sync_payload_hash(
    jsonb_build_object(
      'conflict_id', p_conflict_id,
      'resolution', p_resolution,
      'reason', btrim(p_reason)
    )
  );
  perform private.lock_client_request(actor_id, p_request_id);
  select * into receipt from private.client_mutation_receipts
  where actor_user_id = actor_id and request_id = p_request_id;
  if receipt.actor_user_id is not null then
    if receipt.operation_name = 'resolve_sync_conflict'
      and receipt.payload_hash = payload_hash
    then
      return receipt.safe_result || jsonb_build_object('idempotent', true);
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  if conflict.status <> 'open' then
    raise exception using errcode = '55000', message = 'CONFLICT_RESOLVED';
  end if;
  update public.sync_conflicts
  set
    status = p_resolution,
    resolved_by_user_id = actor_id,
    resolution_reason = btrim(p_reason),
    resolved_at = timezone('utc', now())
  where id = conflict.id;
  result := jsonb_build_object(
    'conflict_id', conflict.id,
    'status', p_resolution,
    'idempotent', false
  );
  insert into private.client_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name,
    target_type, target_id, payload_hash, safe_result
  )
  values (
    actor_id, p_request_id, conflict.stable_id, 'resolve_sync_conflict',
    'sync_conflict', conflict.id, payload_hash, result
  );
  return result;
end;
$$;

create or replace function public.list_sync_conflicts(p_stable_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  perform private.active_sync_membership(p_stable_id);
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'conflict_id', conflict.id,
        'entity_type', conflict.entity_type,
        'entity_id', conflict.entity_id,
        'base_row_version', conflict.base_row_version,
        'server_row_version', conflict.server_row_version,
        'client_patch', conflict.client_patch,
        'status', conflict.status,
        'created_at', conflict.created_at
      )
      order by conflict.created_at, conflict.id
    ),
    '[]'::jsonb
  ) into result
  from public.sync_conflicts conflict
  where conflict.stable_id = p_stable_id
    and conflict.actor_user_id = auth.uid()
    and conflict.status = 'open';
  return result;
end;
$$;

create or replace function private.write_legacy_import_change(
  p_job public.legacy_import_jobs,
  p_change_kind text
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.stable_change_events (
    stable_id,
    horse_id,
    entity_type,
    entity_id,
    change_kind,
    data_category,
    row_version,
    source_stream,
    source_event_id
  )
  values (
    p_job.stable_id,
    null,
    'legacy_import_job',
    p_job.id,
    p_change_kind,
    'stable.import',
    p_job.row_version,
    'legacy_import',
    hashtextextended(p_job.id::text || ':' || p_job.row_version::text, 0)
  )
  on conflict (source_stream, source_event_id) do nothing
$$;

create or replace function private.legacy_job_access(
  p_job_id uuid,
  p_lock boolean default false
)
returns public.legacy_import_jobs
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  result public.legacy_import_jobs%rowtype;
  membership public.stable_memberships%rowtype;
begin
  select * into result
  from public.legacy_import_jobs
  where id = p_job_id;
  if result.id is null then
    raise exception using errcode = '42501', message = 'IMPORT_UNAVAILABLE';
  end if;
  if p_lock then
    membership := private.lock_sync_membership(result.stable_id);
  else
    membership := private.active_sync_membership(result.stable_id);
  end if;
  if result.actor_user_id <> actor_id
    or membership.role not in ('owner', 'admin')
  then
    raise exception using errcode = '42501', message = 'IMPORT_UNAVAILABLE';
  end if;
  if p_lock then
    select locked_job.* into result
    from public.legacy_import_jobs locked_job
    where locked_job.id = p_job_id
      and locked_job.stable_id = result.stable_id
      and locked_job.actor_user_id = actor_id
    for update;
    if result.id is null then
      raise exception using errcode = '42501', message = 'IMPORT_UNAVAILABLE';
    end if;
  end if;
  return result;
end;
$$;

create or replace function private.legacy_import_mapping_is_current(
  p_item_id uuid
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  item public.legacy_import_items%rowtype;
  source_payload jsonb;
begin
  select source_item.* into item
  from public.legacy_import_items source_item
  where source_item.id = p_item_id;
  select stored_payload.payload into source_payload
  from private.legacy_import_payloads stored_payload
  where stored_payload.item_id = p_item_id;
  if item.id is null
    or item.status <> 'imported'
    or item.cloud_id is null
    or item.source_hash <> private.sync_payload_hash(source_payload)
    or item.cloud_hash <> private.sync_payload_hash(source_payload)
  then
    return false;
  end if;
  if item.entity_type = 'stable_member' then
    return exists (
      select 1
      from public.stable_members member
      where member.id = item.cloud_id
        and member.stable_id = item.stable_id
        and member.status = 'active'
        and source_payload->>'target_stable_member_id' = member.id::text
    );
  elsif item.entity_type = 'horse' then
    return exists (
      select 1
      from public.horses horse
      where horse.id = item.cloud_id
        and horse.stable_id = item.stable_id
        and horse.source_kind = 'legacy_import'
        and horse.legacy_local_horse_id::text = item.legacy_local_id
        and horse.display_name = btrim(source_payload->>'display_name')
        and horse.official_name is not distinct from
          nullif(btrim(source_payload->>'official_name'), '')
        and horse.birth_date is not distinct from
          nullif(source_payload->>'birth_date', '')::date
        and horse.sex =
          coalesce(nullif(source_payload->>'sex', ''), 'unknown')
        and horse.breed is not distinct from
          nullif(btrim(source_payload->>'breed'), '')
        and horse.discipline is not distinct from
          nullif(btrim(source_payload->>'discipline'), '')
        and horse.level is not distinct from
          nullif(btrim(source_payload->>'level'), '')
    );
  elsif item.entity_type = 'schedule_item' then
    return exists (
      select 1
      from public.schedule_items schedule_item
      join public.legacy_import_items horse_item
        on horse_item.job_id = item.job_id
       and horse_item.entity_type = 'horse'
       and horse_item.legacy_local_id =
         source_payload->>'horse_legacy_local_id'
       and horse_item.cloud_id = schedule_item.horse_id
       and horse_item.status = 'imported'
      where schedule_item.id = item.cloud_id
        and schedule_item.stable_id = item.stable_id
        and schedule_item.item_kind = source_payload->>'item_kind'
        and schedule_item.data_category =
          source_payload->>'data_category'
        and schedule_item.title = btrim(source_payload->>'title')
        and schedule_item.instruction =
          btrim(source_payload->>'instruction')
        and schedule_item.priority = source_payload->>'priority'
        and schedule_item.scheduled_start_at =
          (source_payload->>'scheduled_start_at')::timestamptz
        and schedule_item.scheduled_end_at is not distinct from
          nullif(source_payload->>'scheduled_end_at', '')::timestamptz
        and schedule_item.source_timezone =
          source_payload->>'source_timezone'
        and schedule_item.source_local_date =
          (source_payload->>'source_local_date')::date
        and schedule_item.source_local_time =
          (source_payload->>'source_local_time')::time
    );
  elsif item.entity_type = 'feeding_plan' then
    return exists (
      select 1
      from private.legacy_feeding_plan_snapshots snapshot
      join public.legacy_import_items horse_item
        on horse_item.job_id = item.job_id
       and horse_item.entity_type = 'horse'
       and horse_item.legacy_local_id =
         source_payload->>'horse_legacy_local_id'
       and horse_item.cloud_id = snapshot.horse_id
       and horse_item.status = 'imported'
      where snapshot.id = item.cloud_id
        and snapshot.import_item_id = item.id
        and snapshot.stable_id = item.stable_id
        and snapshot.payload = source_payload
        and snapshot.source_hash = item.source_hash
    );
  elsif item.entity_type = 'schedule_execution' then
    return exists (
      select 1
      from private.legacy_schedule_execution_history history
      join public.legacy_import_items schedule_item
        on schedule_item.job_id = item.job_id
       and schedule_item.entity_type = 'schedule_item'
       and schedule_item.legacy_local_id =
         source_payload->>'schedule_item_legacy_local_id'
       and schedule_item.cloud_id = history.schedule_item_id
       and schedule_item.status = 'imported'
      join public.legacy_import_items member_item
        on member_item.job_id = item.job_id
       and member_item.entity_type = 'stable_member'
       and member_item.legacy_local_id =
         source_payload->>'actor_stable_member_legacy_local_id'
       and member_item.cloud_id = history.actor_stable_member_id
       and member_item.status = 'imported'
      where history.id = item.cloud_id
        and history.import_item_id = item.id
        and history.stable_id = item.stable_id
        and history.execution_status =
          source_payload->>'execution_status'
        and history.actual_started_at is not distinct from
          nullif(source_payload->>'actual_started_at', '')::timestamptz
        and history.actual_completed_at =
          (source_payload->>'actual_completed_at')::timestamptz
        and history.recorded_local_at =
          (source_payload->>'recorded_local_at')::timestamp
        and history.recorded_timezone =
          source_payload->>'recorded_timezone'
        and history.note is not distinct from
          nullif(btrim(source_payload->>'note'), '')
        and history.feeding_details is not distinct from
          source_payload->'feeding_details'
        and history.source_hash = item.source_hash
    );
  end if;
  return false;
end;
$$;

create or replace function public.create_legacy_import_job(
  p_stable_id uuid,
  p_local_stable_fingerprint bytea,
  p_app_version text,
  p_schema_version integer,
  p_horse_seed_version integer,
  p_source_inventory jsonb,
  p_source_manifest_hash bytea,
  p_items jsonb,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  membership public.stable_memberships%rowtype;
  payload_hash bytea;
  receipt private.client_mutation_receipts%rowtype;
  created_job public.legacy_import_jobs%rowtype;
  item jsonb;
  created_item_id uuid;
  source_count integer;
  computed_source_inventory jsonb;
  computed_source_manifest_hash bytea;
  computed_item_hash bytea;
  result jsonb;
begin
  membership := private.lock_sync_membership(p_stable_id);
  if membership.role not in ('owner', 'admin') then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  if p_request_id is null
    or p_local_stable_fingerprint is null
    or octet_length(p_local_stable_fingerprint) <> 32
    or p_source_manifest_hash is null
    or octet_length(p_source_manifest_hash) <> 32
    or length(btrim(coalesce(p_app_version, ''))) not between 1 and 80
    or p_schema_version is null or p_schema_version <= 0
    or p_horse_seed_version is null or p_horse_seed_version <= 0
    or jsonb_typeof(p_source_inventory) <> 'object'
    or p_source_inventory - array[
      'horses',
      'stable_members',
      'schedule_items',
      'feeding_plans',
      'schedule_executions'
    ]::text[] <> '{}'::jsonb
    or jsonb_typeof(p_items) <> 'array'
    or jsonb_array_length(p_items) > 5000
  then
    raise exception using errcode = '22023', message = 'INVALID_IMPORT_MANIFEST';
  end if;
  source_count := jsonb_array_length(p_items);
  select jsonb_build_object(
    'horses',
      count(*) filter (where value->>'entity_type' = 'horse'),
    'stable_members',
      count(*) filter (where value->>'entity_type' = 'stable_member'),
    'schedule_items',
      count(*) filter (where value->>'entity_type' = 'schedule_item'),
    'feeding_plans',
      count(*) filter (where value->>'entity_type' = 'feeding_plan'),
    'schedule_executions',
      count(*) filter (where value->>'entity_type' = 'schedule_execution')
  ) into computed_source_inventory
  from jsonb_array_elements(p_items);
  if computed_source_inventory <> p_source_inventory then
    raise exception using
      errcode = '22023',
      message = 'SOURCE_INVENTORY_MISMATCH';
  end if;
  computed_source_manifest_hash :=
    private.legacy_source_manifest_hash(p_source_inventory, p_items);
  if computed_source_manifest_hash <> p_source_manifest_hash then
    raise exception using
      errcode = '22023',
      message = 'SOURCE_MANIFEST_MISMATCH';
  end if;
  payload_hash := private.sync_payload_hash(
    jsonb_build_object(
      'stable_id', p_stable_id,
      'local_stable_fingerprint',
        encode(p_local_stable_fingerprint, 'hex'),
      'app_version', btrim(p_app_version),
      'schema_version', p_schema_version,
      'horse_seed_version', p_horse_seed_version,
      'source_inventory', p_source_inventory,
      'source_manifest_hash', encode(p_source_manifest_hash, 'hex'),
      'items', p_items
    )
  );
  perform private.lock_client_request(actor_id, p_request_id);
  select * into receipt
  from private.client_mutation_receipts
  where actor_user_id = actor_id and request_id = p_request_id;
  if receipt.actor_user_id is not null then
    if receipt.operation_name = 'create_legacy_import_job'
      and receipt.payload_hash = payload_hash
    then
      return receipt.safe_result || jsonb_build_object('idempotent', true);
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;

  insert into public.legacy_import_jobs (
    actor_user_id,
    stable_id,
    local_stable_fingerprint,
    app_version,
    schema_version,
    horse_seed_version,
    source_record_count,
    source_inventory,
    source_manifest_hash,
    request_id
  )
  values (
    actor_id,
    p_stable_id,
    p_local_stable_fingerprint,
    btrim(p_app_version),
    p_schema_version,
    p_horse_seed_version,
    source_count,
    p_source_inventory,
    p_source_manifest_hash,
    p_request_id
  )
  returning * into created_job;

  for item in select value from jsonb_array_elements(p_items)
  loop
    if jsonb_typeof(item) <> 'object'
      or item->>'entity_type' not in (
        'horse',
        'stable_member',
        'schedule_item',
        'feeding_plan',
        'schedule_execution'
      )
      or length(btrim(coalesce(item->>'legacy_local_id', '')))
        not between 1 and 200
      or item->>'source_classification' not in (
        'user', 'modified_seed', 'unmodified_seed', 'unknown'
      )
      or coalesce(item->>'source_hash', '') !~ '^[0-9a-f]{64}$'
      or jsonb_typeof(item->'payload') <> 'object'
      or pg_column_size(item->'payload') > 32768
    then
      raise exception using
        errcode = '22023',
        message = 'INVALID_IMPORT_ITEM';
    end if;
    computed_item_hash := private.sync_payload_hash(item->'payload');
    if computed_item_hash <> decode(item->>'source_hash', 'hex') then
      raise exception using
        errcode = '22023',
        message = 'SOURCE_HASH_MISMATCH';
    end if;
    insert into public.legacy_import_items (
      stable_id,
      job_id,
      entity_type,
      legacy_local_id,
      source_classification,
      selected_explicitly,
      source_hash
    )
    values (
      p_stable_id,
      created_job.id,
      item->>'entity_type',
      item->>'legacy_local_id',
      item->>'source_classification',
      coalesce((item->>'selected')::boolean, false),
      decode(item->>'source_hash', 'hex')
    )
    returning id into created_item_id;
    insert into private.legacy_import_payloads (item_id, payload)
    values (created_item_id, item->'payload');
  end loop;

  result := jsonb_build_object(
    'job_id', created_job.id,
    'status', created_job.status,
    'source_record_count', source_count,
    'idempotent', false
  );
  insert into private.client_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name,
    target_type, target_id, payload_hash, safe_result
  )
  values (
    actor_id, p_request_id, p_stable_id, 'create_legacy_import_job',
    'legacy_import_job', created_job.id, payload_hash, result
  );
  perform private.write_legacy_import_change(
    created_job,
    'legacy_import_created'
  );
  return result;
end;
$$;

create or replace function public.validate_legacy_import_job(
  p_job_id uuid,
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
  job public.legacy_import_jobs%rowtype;
  payload_hash bytea;
  receipt private.client_mutation_receipts%rowtype;
  result jsonb;
  selected_count integer;
  conflict_count integer;
  excluded_count integer;
begin
  if p_request_id is null or p_expected_row_version is null then
    raise exception using errcode = '22023', message = 'INVALID_VALIDATION';
  end if;
  job := private.legacy_job_access(p_job_id, true);
  payload_hash := private.sync_payload_hash(
    jsonb_build_object(
      'job_id', p_job_id,
      'expected_row_version', p_expected_row_version
    )
  );
  perform private.lock_client_request(actor_id, p_request_id);
  select * into receipt from private.client_mutation_receipts
  where actor_user_id = actor_id and request_id = p_request_id;
  if receipt.actor_user_id is not null then
    if receipt.operation_name = 'validate_legacy_import_job'
      and receipt.payload_hash = payload_hash
    then
      return receipt.safe_result || jsonb_build_object('idempotent', true);
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  if job.status <> 'draft' or job.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'IMPORT_VERSION_CONFLICT';
  end if;

  update public.legacy_import_items item
  set
    status = case
      when source_classification = 'unmodified_seed' then 'excluded_seed'
      when source_classification = 'user' then 'selected'
      when selected_explicitly then 'selected'
      else 'conflict'
    end,
    conflict_code = case
      when source_classification in ('modified_seed', 'unknown')
        and not selected_explicitly
        then 'SOURCE_CONFIRMATION_REQUIRED'
      else null
    end,
    updated_at = timezone('utc', now())
  where item.job_id = job.id;

  select
    count(*) filter (where status = 'selected'),
    count(*) filter (where status = 'conflict'),
    count(*) filter (where status = 'excluded_seed')
  into selected_count, conflict_count, excluded_count
  from public.legacy_import_items
  where job_id = job.id;

  update public.legacy_import_jobs
  set
    status = 'validated',
    selected_record_count = selected_count,
    row_version = row_version + 1,
    updated_at = timezone('utc', now())
  where id = job.id
  returning * into job;

  result := jsonb_build_object(
    'job_id', job.id,
    'status', job.status,
    'row_version', job.row_version,
    'selected_count', selected_count,
    'conflict_count', conflict_count,
    'excluded_seed_count', excluded_count,
    'ready_to_import', conflict_count = 0,
    'idempotent', false
  );
  insert into private.client_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name,
    target_type, target_id, payload_hash, safe_result, target_row_version
  )
  values (
    actor_id, p_request_id, job.stable_id, 'validate_legacy_import_job',
    'legacy_import_job', job.id, payload_hash, result, job.row_version
  );
  perform private.write_legacy_import_change(
    job,
    'legacy_import_validated'
  );
  return result;
end;
$$;

create or replace function public.execute_legacy_import_batch(
  p_job_id uuid,
  p_expected_row_version bigint,
  p_limit integer,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  job public.legacy_import_jobs%rowtype;
  membership public.stable_memberships%rowtype;
  item record;
  payload jsonb;
  created_horse public.horses%rowtype;
  horse_was_created boolean;
  created_schedule_item public.schedule_items%rowtype;
  mapped_horse_id uuid;
  mapped_schedule_item_id uuid;
  mapped_stable_member_id uuid;
  created_snapshot_id uuid;
  computed_cloud_hash bytea;
  imported_count integer := 0;
  batch_mappings jsonb := '[]'::jsonb;
  remaining_count integer;
  payload_hash bytea;
  receipt private.client_mutation_receipts%rowtype;
  result jsonb;
begin
  if p_request_id is null or p_expected_row_version is null
    or p_limit is null or p_limit not between 1 and 250
  then
    raise exception using errcode = '22023', message = 'INVALID_IMPORT_BATCH';
  end if;
  job := private.legacy_job_access(p_job_id, true);
  membership := private.active_sync_membership(job.stable_id);
  payload_hash := private.sync_payload_hash(
    jsonb_build_object(
      'job_id', p_job_id,
      'expected_row_version', p_expected_row_version,
      'limit', p_limit
    )
  );
  perform private.lock_client_request(actor_id, p_request_id);
  select * into receipt from private.client_mutation_receipts
  where actor_user_id = actor_id and request_id = p_request_id;
  if receipt.actor_user_id is not null then
    if receipt.operation_name = 'execute_legacy_import_batch'
      and receipt.payload_hash = payload_hash
    then
      return receipt.safe_result || jsonb_build_object('idempotent', true);
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  if job.status not in ('validated', 'importing')
    or job.row_version <> p_expected_row_version
    or exists (
      select 1 from public.legacy_import_items
      where job_id = job.id and status = 'conflict'
    )
  then
    raise exception using errcode = '55000', message = 'IMPORT_NOT_READY';
  end if;

  for item in
    select source_item.*, source_payload.payload
    from public.legacy_import_items source_item
    join private.legacy_import_payloads source_payload
      on source_payload.item_id = source_item.id
    where source_item.job_id = job.id
      and source_item.status = 'selected'
    order by
      case source_item.entity_type
        when 'stable_member' then 1
        when 'horse' then 2
        when 'schedule_item' then 3
        when 'feeding_plan' then 4
        else 5
      end,
      source_item.created_at,
      source_item.id
    limit p_limit
    for update of source_item
  loop
    payload := item.payload;
    created_horse := null;
    horse_was_created := false;
    mapped_horse_id := null;
    mapped_schedule_item_id := null;
    mapped_stable_member_id := null;
    created_snapshot_id := null;
    computed_cloud_hash := null;
    begin
      if item.entity_type = 'stable_member' then
        if payload - array['target_stable_member_id']::text[]
            <> '{}'::jsonb
          or coalesce(payload->>'target_stable_member_id', '')
            !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        then
          raise exception using
            errcode = '22023',
            message = 'MAPPING_MISSING';
        end if;
        select member.id into mapped_stable_member_id
        from public.stable_members member
        where member.id = (payload->>'target_stable_member_id')::uuid
          and member.stable_id = job.stable_id
          and member.status = 'active';
        if mapped_stable_member_id is null then
          raise exception using
            errcode = '22023',
            message = 'MAPPING_MISSING';
        end if;
        created_snapshot_id := mapped_stable_member_id;
      elsif item.entity_type = 'horse' then
        if item.legacy_local_id !~ '^[0-9]+$'
          or (item.legacy_local_id)::numeric > 9223372036854775807
          or length(btrim(coalesce(payload->>'display_name', '')))
            not between 1 and 120
          or payload - array[
            'display_name', 'official_name', 'birth_date', 'sex',
            'breed', 'discipline', 'level'
          ]::text[] <> '{}'::jsonb
        then
          raise exception using
            errcode = '22023',
            message = 'IMPORT_REJECTED';
        end if;
        select * into created_horse
        from public.horses horse
        where horse.stable_id = job.stable_id
          and horse.legacy_local_horse_id = item.legacy_local_id::bigint
        for update;
        if created_horse.id is not null then
          if created_horse.source_kind <> 'legacy_import'
            or created_horse.display_name <> btrim(payload->>'display_name')
            or created_horse.official_name is distinct from
              nullif(btrim(payload->>'official_name'), '')
            or created_horse.birth_date is distinct from
              nullif(payload->>'birth_date', '')::date
            or created_horse.sex <>
              coalesce(nullif(payload->>'sex', ''), 'unknown')
            or created_horse.breed is distinct from
              nullif(btrim(payload->>'breed'), '')
            or created_horse.discipline is distinct from
              nullif(btrim(payload->>'discipline'), '')
            or created_horse.level is distinct from
              nullif(btrim(payload->>'level'), '')
          then
            raise exception using
              errcode = '22023',
              message = 'SOURCE_HASH_MISMATCH';
          end if;
        else
          insert into public.horses (
            stable_id,
            display_name,
            official_name,
            birth_date,
            sex,
            breed,
            discipline,
            level,
            legacy_local_horse_id,
            source_kind,
            created_by_user_id,
            created_request_id
          )
          values (
            job.stable_id,
            btrim(payload->>'display_name'),
            nullif(btrim(payload->>'official_name'), ''),
            nullif(payload->>'birth_date', '')::date,
            coalesce(nullif(payload->>'sex', ''), 'unknown'),
            nullif(btrim(payload->>'breed'), ''),
            nullif(btrim(payload->>'discipline'), ''),
            nullif(btrim(payload->>'level'), ''),
            item.legacy_local_id::bigint,
            'legacy_import',
            actor_id,
            item.id
          )
          returning * into created_horse;
          horse_was_created := true;
        end if;
        if horse_was_created then
          insert into public.horse_profile_change_events (
            stable_id, horse_id, actor_user_id, actor_membership_id,
            request_id, event_type, changed_fields, old_values, new_values
          )
          values (
            job.stable_id, created_horse.id, actor_id, membership.id,
            item.id, 'horse_created',
            array[
              'status',
              'display_name',
              'official_name',
              'birth_date',
              'sex',
              'breed',
              'discipline',
              'level'
            ]::text[],
            '{}'::jsonb,
            private.horse_profile_json(created_horse)
          );
        end if;
        update public.legacy_import_items
        set
          cloud_id = created_horse.id,
          cloud_hash = private.sync_payload_hash(payload),
          status = 'imported',
          conflict_code = null,
          updated_at = timezone('utc', now())
        where id = item.id;
        batch_mappings := batch_mappings || jsonb_build_array(
          jsonb_build_object(
            'entity_type', item.entity_type,
            'legacy_local_id', item.legacy_local_id,
            'cloud_id', created_horse.id,
            'source_hash', encode(item.source_hash, 'hex'),
            'cloud_hash',
              encode(private.sync_payload_hash(payload), 'hex')
          )
        );
        imported_count := imported_count + 1;
      elsif item.entity_type = 'schedule_item' then
        select horse_item.cloud_id into mapped_horse_id
        from public.legacy_import_items horse_item
        where horse_item.job_id = job.id
          and horse_item.entity_type = 'horse'
          and horse_item.legacy_local_id =
            payload->>'horse_legacy_local_id'
          and horse_item.status = 'imported';
        if mapped_horse_id is null
          or length(btrim(coalesce(payload->>'title', '')))
            not between 1 and 160
          or length(btrim(coalesce(payload->>'instruction', '')))
            not between 1 and 2000
          or payload->>'item_kind' not in (
            'task', 'feeding', 'training', 'care', 'other'
          )
          or payload->>'data_category' not in (
            'horse.schedule', 'horse.nutrition'
          )
          or payload->>'priority' not in ('normal', 'high')
          or not exists (
            select 1
            from pg_catalog.pg_timezone_names zone
            where zone.name = payload->>'source_timezone'
          )
          or payload - array[
            'horse_legacy_local_id', 'item_kind', 'data_category',
            'title', 'instruction', 'priority', 'scheduled_start_at',
            'scheduled_end_at', 'source_timezone', 'source_local_date',
            'source_local_time'
          ]::text[] <> '{}'::jsonb
        then
          raise exception using
            errcode = '22023',
            message = 'MAPPING_MISSING';
        end if;
        insert into public.schedule_items (
          stable_id, horse_id, item_kind, data_category, title, instruction,
          priority, scheduled_start_at, scheduled_end_at, source_timezone,
          source_local_date, source_local_time, created_by_user_id,
          created_request_id, last_mutated_by_user_id,
          last_mutation_request_id
        )
        values (
          job.stable_id, mapped_horse_id, payload->>'item_kind',
          payload->>'data_category', btrim(payload->>'title'),
          btrim(payload->>'instruction'), payload->>'priority',
          (payload->>'scheduled_start_at')::timestamptz,
          nullif(payload->>'scheduled_end_at', '')::timestamptz,
          payload->>'source_timezone',
          (payload->>'source_local_date')::date,
          (payload->>'source_local_time')::time,
          actor_id, item.id, actor_id, item.id
        )
        on conflict (created_by_user_id, created_request_id) do update
        set created_request_id = excluded.created_request_id
        returning * into created_schedule_item;
        insert into public.schedule_change_events (
          stable_id, schedule_item_id, actor_user_id, actor_membership_id,
          request_id, event_type, data_category, row_version
        )
        values (
          job.stable_id, created_schedule_item.id, actor_id, membership.id,
          item.id, 'schedule_item_created',
          created_schedule_item.data_category,
          created_schedule_item.row_version
        );
        update public.legacy_import_items
        set
          cloud_id = created_schedule_item.id,
          cloud_hash = private.sync_payload_hash(payload),
          status = 'imported',
          conflict_code = null,
          updated_at = timezone('utc', now())
        where id = item.id;
        batch_mappings := batch_mappings || jsonb_build_array(
          jsonb_build_object(
            'entity_type', item.entity_type,
            'legacy_local_id', item.legacy_local_id,
            'cloud_id', created_schedule_item.id,
            'source_hash', encode(item.source_hash, 'hex'),
            'cloud_hash',
              encode(private.sync_payload_hash(payload), 'hex')
          )
        );
        imported_count := imported_count + 1;
      elsif item.entity_type = 'feeding_plan' then
        select horse_item.cloud_id into mapped_horse_id
        from public.legacy_import_items horse_item
        where horse_item.job_id = job.id
          and horse_item.entity_type = 'horse'
          and horse_item.legacy_local_id =
            payload->>'horse_legacy_local_id'
          and horse_item.status = 'imported';
        if mapped_horse_id is null
          or payload->>'plan_type' not in ('standard', 'temporary')
          or length(btrim(coalesce(payload->>'name', '')))
            not between 1 and 160
          or nullif(payload->>'effective_from', '') is null
          or jsonb_typeof(payload->'plan_data') <> 'object'
          or payload - array[
            'horse_legacy_local_id', 'plan_type', 'name',
            'effective_from', 'effective_until', 'plan_data'
          ]::text[] <> '{}'::jsonb
        then
          raise exception using
            errcode = '22023',
            message = 'MAPPING_MISSING';
        end if;
        if payload->>'plan_type' = 'temporary'
          and nullif(payload->>'effective_until', '') is null
        then
          raise exception using
            errcode = '22023',
            message = 'IMPORT_REJECTED';
        end if;
        insert into private.legacy_feeding_plan_snapshots (
          stable_id, job_id, import_item_id, horse_id, payload, source_hash
        )
        values (
          job.stable_id, job.id, item.id, mapped_horse_id,
          payload, item.source_hash
        )
        on conflict (import_item_id) do update
        set import_item_id = excluded.import_item_id
        returning id into created_snapshot_id;
      elsif item.entity_type = 'schedule_execution' then
        select schedule_item.cloud_id into mapped_schedule_item_id
        from public.legacy_import_items schedule_item
        where schedule_item.job_id = job.id
          and schedule_item.entity_type = 'schedule_item'
          and schedule_item.legacy_local_id =
            payload->>'schedule_item_legacy_local_id'
          and schedule_item.status = 'imported';
        select member_item.cloud_id into mapped_stable_member_id
        from public.legacy_import_items member_item
        where member_item.job_id = job.id
          and member_item.entity_type = 'stable_member'
          and member_item.legacy_local_id =
            payload->>'actor_stable_member_legacy_local_id'
          and member_item.status = 'imported';
        if mapped_schedule_item_id is null
          or mapped_stable_member_id is null
          or payload->>'execution_status' not in (
            'completed', 'partial', 'skipped', 'refused', 'problem'
          )
          or nullif(payload->>'actual_completed_at', '') is null
          or nullif(payload->>'recorded_local_at', '') is null
          or not exists (
            select 1 from pg_catalog.pg_timezone_names zone
            where zone.name = payload->>'recorded_timezone'
          )
          or length(coalesce(payload->>'note', '')) > 1000
          or (
            payload ? 'feeding_details'
            and jsonb_typeof(payload->'feeding_details') <> 'object'
          )
          or payload - array[
            'schedule_item_legacy_local_id',
            'actor_stable_member_legacy_local_id',
            'execution_status', 'actual_started_at',
            'actual_completed_at', 'recorded_local_at',
            'recorded_timezone', 'note', 'feeding_details'
          ]::text[] <> '{}'::jsonb
        then
          raise exception using
            errcode = '22023',
            message = 'MAPPING_MISSING';
        end if;
        insert into private.legacy_schedule_execution_history (
          stable_id, job_id, import_item_id, schedule_item_id,
          actor_stable_member_id, execution_status, actual_started_at,
          actual_completed_at, recorded_local_at, recorded_timezone,
          note, feeding_details, source_hash
        )
        values (
          job.stable_id, job.id, item.id, mapped_schedule_item_id,
          mapped_stable_member_id, payload->>'execution_status',
          nullif(payload->>'actual_started_at', '')::timestamptz,
          (payload->>'actual_completed_at')::timestamptz,
          (payload->>'recorded_local_at')::timestamp,
          payload->>'recorded_timezone',
          nullif(btrim(payload->>'note'), ''),
          payload->'feeding_details',
          item.source_hash
        )
        on conflict (import_item_id) do update
        set import_item_id = excluded.import_item_id
        returning id into created_snapshot_id;
      end if;
      if item.entity_type in (
        'stable_member', 'feeding_plan', 'schedule_execution'
      ) then
        computed_cloud_hash := private.sync_payload_hash(payload);
        update public.legacy_import_items
        set
          cloud_id = created_snapshot_id,
          cloud_hash = computed_cloud_hash,
          status = 'imported',
          conflict_code = null,
          updated_at = timezone('utc', now())
        where id = item.id;
        batch_mappings := batch_mappings || jsonb_build_array(
          jsonb_build_object(
            'entity_type', item.entity_type,
            'legacy_local_id', item.legacy_local_id,
            'cloud_id', created_snapshot_id,
            'source_hash', encode(item.source_hash, 'hex'),
            'cloud_hash', encode(computed_cloud_hash, 'hex')
          )
        );
        imported_count := imported_count + 1;
      else
        update public.legacy_import_items
        set cloud_hash = private.sync_payload_hash(payload)
        where id = item.id;
      end if;
    exception when others then
      update public.legacy_import_items
      set
        status = 'failed',
        conflict_code = case sqlerrm
          when 'MAPPING_MISSING' then 'MAPPING_MISSING'
          when 'UNSUPPORTED_ENTITY' then 'UNSUPPORTED_ENTITY'
          when 'SOURCE_HASH_MISMATCH' then 'SOURCE_HASH_MISMATCH'
          else 'IMPORT_REJECTED'
        end,
        updated_at = timezone('utc', now())
      where id = item.id;
    end;
  end loop;

  select count(*) into remaining_count
  from public.legacy_import_items
  where job_id = job.id and status = 'selected';

  update public.legacy_import_jobs
  set
    status = case when remaining_count = 0 then 'importing' else 'importing' end,
    imported_record_count = (
      select count(*) from public.legacy_import_items
      where job_id = job.id and status = 'imported'
    ),
    row_version = row_version + 1,
    updated_at = timezone('utc', now())
  where id = job.id
  returning * into job;

  result := jsonb_build_object(
    'job_id', job.id,
    'status', job.status,
    'row_version', job.row_version,
    'batch_imported_count', imported_count,
    'mappings', batch_mappings,
    'imported_record_count', job.imported_record_count,
    'remaining_count', remaining_count,
    'idempotent', false
  );
  insert into private.client_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name,
    target_type, target_id, payload_hash, safe_result, target_row_version
  )
  values (
    actor_id, p_request_id, job.stable_id, 'execute_legacy_import_batch',
    'legacy_import_job', job.id, payload_hash, result, job.row_version
  );
  perform private.write_legacy_import_change(
    job,
    'legacy_import_batch_executed'
  );
  return result;
end;
$$;

create or replace function public.verify_legacy_import_job(
  p_job_id uuid,
  p_expected_row_version bigint,
  p_expected_mapping_manifest_hash bytea,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  job public.legacy_import_jobs%rowtype;
  mapping_hash bytea;
  payload_hash bytea;
  receipt private.client_mutation_receipts%rowtype;
  result jsonb;
begin
  if p_request_id is null
    or p_expected_mapping_manifest_hash is null
    or octet_length(p_expected_mapping_manifest_hash) <> 32
  then
    raise exception using errcode = '22023', message = 'INVALID_VERIFICATION';
  end if;
  job := private.legacy_job_access(p_job_id, true);
  payload_hash := private.sync_payload_hash(
    jsonb_build_object(
      'job_id', p_job_id,
      'expected_row_version', p_expected_row_version,
      'mapping_manifest_hash',
        encode(p_expected_mapping_manifest_hash, 'hex')
    )
  );
  perform private.lock_client_request(actor_id, p_request_id);
  select * into receipt from private.client_mutation_receipts
  where actor_user_id = actor_id and request_id = p_request_id;
  if receipt.actor_user_id is not null then
    if receipt.operation_name = 'verify_legacy_import_job'
      and receipt.payload_hash = payload_hash
    then
      return receipt.safe_result || jsonb_build_object('idempotent', true);
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  perform 1
  from public.legacy_import_items source_item
  join public.stable_members member on member.id = source_item.cloud_id
  where source_item.job_id = job.id
    and source_item.entity_type = 'stable_member'
    and source_item.status = 'imported'
  order by member.id
  for share of member;
  perform 1
  from public.legacy_import_items source_item
  join public.horses horse on horse.id = source_item.cloud_id
  where source_item.job_id = job.id
    and source_item.entity_type = 'horse'
    and source_item.status = 'imported'
  order by horse.id
  for share of horse;
  perform 1
  from public.legacy_import_items source_item
  join public.schedule_items schedule_item
    on schedule_item.id = source_item.cloud_id
  where source_item.job_id = job.id
    and source_item.entity_type = 'schedule_item'
    and source_item.status = 'imported'
  order by schedule_item.id
  for share of schedule_item;
  perform 1
  from public.legacy_import_items source_item
  join private.legacy_feeding_plan_snapshots snapshot
    on snapshot.id = source_item.cloud_id
  where source_item.job_id = job.id
    and source_item.entity_type = 'feeding_plan'
    and source_item.status = 'imported'
  order by snapshot.id
  for share of snapshot;
  perform 1
  from public.legacy_import_items source_item
  join private.legacy_schedule_execution_history history
    on history.id = source_item.cloud_id
  where source_item.job_id = job.id
    and source_item.entity_type = 'schedule_execution'
    and source_item.status = 'imported'
  order by history.id
  for share of history;
  select private.sync_payload_hash(
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'entity_type', entity_type,
          'legacy_local_id', legacy_local_id,
          'cloud_id', cloud_id,
          'source_hash', encode(source_hash, 'hex'),
          'cloud_hash', encode(cloud_hash, 'hex')
        )
        order by entity_type, legacy_local_id
      ) filter (where status = 'imported'),
      '[]'::jsonb
    )
  ) into mapping_hash
  from public.legacy_import_items
  where job_id = job.id;
  if job.row_version <> p_expected_row_version
    or job.status <> 'importing'
    or exists (
      select 1 from public.legacy_import_items
      where job_id = job.id and status in (
        'selected', 'pending', 'conflict', 'failed'
      )
    )
    or exists (
      select 1
      from public.legacy_import_items source_item
      where source_item.job_id = job.id
        and source_item.status = 'imported'
        and not private.legacy_import_mapping_is_current(source_item.id)
    )
    or job.imported_record_count <> job.selected_record_count
    or mapping_hash <> p_expected_mapping_manifest_hash
  then
    raise exception using
      errcode = '55000',
      message = 'IMPORT_VERIFICATION_FAILED';
  end if;
  update public.legacy_import_jobs
  set
    status = 'verified',
    mapping_manifest_hash = mapping_hash,
    row_version = row_version + 1,
    updated_at = timezone('utc', now()),
    verified_at = timezone('utc', now())
  where id = job.id
  returning * into job;
  result := jsonb_build_object(
    'job_id', job.id,
    'status', job.status,
    'row_version', job.row_version,
    'mapping_manifest_hash', encode(mapping_hash, 'hex'),
    'idempotent', false
  );
  insert into private.client_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name,
    target_type, target_id, payload_hash, safe_result, target_row_version
  )
  values (
    actor_id, p_request_id, job.stable_id, 'verify_legacy_import_job',
    'legacy_import_job', job.id, payload_hash, result, job.row_version
  );
  perform private.write_legacy_import_change(
    job,
    'legacy_import_verified'
  );
  return result;
end;
$$;

create or replace function public.cutover_legacy_import_job(
  p_job_id uuid,
  p_expected_row_version bigint,
  p_local_stable_fingerprint bytea,
  p_local_backup_retained boolean,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  job public.legacy_import_jobs%rowtype;
  current_mapping_hash bytea;
  payload_hash bytea;
  receipt private.client_mutation_receipts%rowtype;
  result jsonb;
begin
  if p_request_id is null or p_local_backup_retained is not true then
    raise exception using errcode = '22023', message = 'BACKUP_REQUIRED';
  end if;
  job := private.legacy_job_access(p_job_id, true);
  payload_hash := private.sync_payload_hash(
    jsonb_build_object(
      'job_id', p_job_id,
      'expected_row_version', p_expected_row_version,
      'local_stable_fingerprint',
        encode(p_local_stable_fingerprint, 'hex'),
      'local_backup_retained', p_local_backup_retained
    )
  );
  perform private.lock_client_request(actor_id, p_request_id);
  select * into receipt from private.client_mutation_receipts
  where actor_user_id = actor_id and request_id = p_request_id;
  if receipt.actor_user_id is not null then
    if receipt.operation_name = 'cutover_legacy_import_job'
      and receipt.payload_hash = payload_hash
    then
      return receipt.safe_result || jsonb_build_object('idempotent', true);
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  perform 1
  from public.legacy_import_items source_item
  join public.stable_members member on member.id = source_item.cloud_id
  where source_item.job_id = job.id
    and source_item.entity_type = 'stable_member'
    and source_item.status = 'imported'
  order by member.id
  for share of member;
  perform 1
  from public.legacy_import_items source_item
  join public.horses horse on horse.id = source_item.cloud_id
  where source_item.job_id = job.id
    and source_item.entity_type = 'horse'
    and source_item.status = 'imported'
  order by horse.id
  for share of horse;
  perform 1
  from public.legacy_import_items source_item
  join public.schedule_items schedule_item
    on schedule_item.id = source_item.cloud_id
  where source_item.job_id = job.id
    and source_item.entity_type = 'schedule_item'
    and source_item.status = 'imported'
  order by schedule_item.id
  for share of schedule_item;
  perform 1
  from public.legacy_import_items source_item
  join private.legacy_feeding_plan_snapshots snapshot
    on snapshot.id = source_item.cloud_id
  where source_item.job_id = job.id
    and source_item.entity_type = 'feeding_plan'
    and source_item.status = 'imported'
  order by snapshot.id
  for share of snapshot;
  perform 1
  from public.legacy_import_items source_item
  join private.legacy_schedule_execution_history history
    on history.id = source_item.cloud_id
  where source_item.job_id = job.id
    and source_item.entity_type = 'schedule_execution'
    and source_item.status = 'imported'
  order by history.id
  for share of history;
  select private.sync_payload_hash(
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'entity_type', entity_type,
          'legacy_local_id', legacy_local_id,
          'cloud_id', cloud_id,
          'source_hash', encode(source_hash, 'hex'),
          'cloud_hash', encode(cloud_hash, 'hex')
        )
        order by entity_type, legacy_local_id
      ) filter (where status = 'imported'),
      '[]'::jsonb
    )
  ) into current_mapping_hash
  from public.legacy_import_items
  where job_id = job.id;
  if job.status <> 'verified'
    or job.row_version <> p_expected_row_version
    or job.local_stable_fingerprint <> p_local_stable_fingerprint
    or job.mapping_manifest_hash <> current_mapping_hash
    or job.imported_record_count <> job.selected_record_count
    or exists (
      select 1
      from public.legacy_import_items source_item
      where source_item.job_id = job.id
        and source_item.status = 'imported'
        and not private.legacy_import_mapping_is_current(source_item.id)
    )
  then
    raise exception using errcode = '55000', message = 'CUTOVER_NOT_READY';
  end if;
  update public.legacy_import_jobs
  set
    status = 'cutover',
    row_version = row_version + 1,
    updated_at = timezone('utc', now()),
    cutover_at = timezone('utc', now())
  where id = job.id
  returning * into job;
  result := jsonb_build_object(
    'job_id', job.id,
    'stable_id', job.stable_id,
    'status', job.status,
    'row_version', job.row_version,
    'local_backup_retained', true,
    'idempotent', false
  );
  insert into private.client_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name,
    target_type, target_id, payload_hash, safe_result, target_row_version
  )
  values (
    actor_id, p_request_id, job.stable_id, 'cutover_legacy_import_job',
    'legacy_import_job', job.id, payload_hash, result, job.row_version
  );
  perform private.write_legacy_import_change(
    job,
    'legacy_import_cutover'
  );
  return result;
end;
$$;

create or replace function public.rollback_legacy_import_job(
  p_job_id uuid,
  p_expected_row_version bigint,
  p_local_backup_retained boolean,
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
  job public.legacy_import_jobs%rowtype;
  payload_hash bytea;
  receipt private.client_mutation_receipts%rowtype;
  result jsonb;
begin
  if p_request_id is null
    or p_local_backup_retained is not true
    or length(btrim(coalesce(p_reason, ''))) not between 1 and 500
  then
    raise exception using errcode = '22023', message = 'INVALID_ROLLBACK';
  end if;
  job := private.legacy_job_access(p_job_id, true);
  payload_hash := private.sync_payload_hash(
    jsonb_build_object(
      'job_id', p_job_id,
      'expected_row_version', p_expected_row_version,
      'local_backup_retained', p_local_backup_retained,
      'reason', btrim(p_reason)
    )
  );
  perform private.lock_client_request(actor_id, p_request_id);
  select * into receipt from private.client_mutation_receipts
  where actor_user_id = actor_id and request_id = p_request_id;
  if receipt.actor_user_id is not null then
    if receipt.operation_name = 'rollback_legacy_import_job'
      and receipt.payload_hash = payload_hash
    then
      return receipt.safe_result || jsonb_build_object('idempotent', true);
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  if job.status not in (
    'validated', 'importing', 'verified', 'cutover', 'failed'
  ) or job.row_version <> p_expected_row_version
  then
    raise exception using errcode = '55000', message = 'ROLLBACK_NOT_AVAILABLE';
  end if;
  update public.legacy_import_items
  set
    status = case
      when status = 'imported' then 'rolled_back'
      else status
    end,
    updated_at = timezone('utc', now())
  where job_id = job.id;
  update public.legacy_import_jobs
  set
    status = 'rolled_back',
    row_version = row_version + 1,
    updated_at = timezone('utc', now()),
    rolled_back_at = timezone('utc', now())
  where id = job.id
  returning * into job;
  result := jsonb_build_object(
    'job_id', job.id,
    'status', job.status,
    'row_version', job.row_version,
    'local_backup_retained', true,
    'cloud_history_retained', true,
    'idempotent', false
  );
  insert into private.client_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name,
    target_type, target_id, payload_hash, safe_result, target_row_version
  )
  values (
    actor_id, p_request_id, job.stable_id, 'rollback_legacy_import_job',
    'legacy_import_job', job.id, payload_hash, result, job.row_version
  );
  perform private.write_legacy_import_change(
    job,
    'legacy_import_rolled_back'
  );
  return result;
end;
$$;

create or replace function public.get_legacy_import_job(p_job_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  job public.legacy_import_jobs%rowtype;
  result jsonb;
begin
  job := private.legacy_job_access(p_job_id, false);
  select jsonb_build_object(
    'job_id', job.id,
    'stable_id', job.stable_id,
    'status', job.status,
    'row_version', job.row_version,
    'app_version', job.app_version,
    'schema_version', job.schema_version,
    'horse_seed_version', job.horse_seed_version,
    'source_record_count', job.source_record_count,
    'source_inventory', job.source_inventory,
    'selected_record_count', job.selected_record_count,
    'imported_record_count', job.imported_record_count,
    'source_manifest_hash', encode(job.source_manifest_hash, 'hex'),
    'mapping_manifest_hash',
      case
        when job.mapping_manifest_hash is null then null
        else encode(job.mapping_manifest_hash, 'hex')
      end,
    'created_at', job.created_at,
    'updated_at', job.updated_at,
    'verified_at', job.verified_at,
    'cutover_at', job.cutover_at,
    'rolled_back_at', job.rolled_back_at,
    'item_counts',
    (
      select coalesce(
        jsonb_object_agg(status_count.status, status_count.count),
        '{}'::jsonb
      )
      from (
        select item.status, count(*) as count
        from public.legacy_import_items item
        where item.job_id = job.id
        group by item.status
      ) status_count
    ),
    'mappings',
    (
      select coalesce(
        jsonb_agg(
          jsonb_build_object(
            'entity_type', item.entity_type,
            'legacy_local_id', item.legacy_local_id,
            'cloud_id', item.cloud_id,
            'source_hash', encode(item.source_hash, 'hex'),
            'cloud_hash', encode(item.cloud_hash, 'hex')
          )
          order by item.entity_type, item.legacy_local_id
        ) filter (where item.cloud_id is not null),
        '[]'::jsonb
      )
      from public.legacy_import_items item
      where item.job_id = job.id
    )
  ) into result;
  return result;
end;
$$;

alter table public.stable_sync_authorities enable row level security;
alter table public.client_sync_devices enable row level security;
alter table public.stable_change_events enable row level security;
alter table public.sync_conflicts enable row level security;
alter table public.legacy_import_jobs enable row level security;
alter table public.legacy_import_items enable row level security;

revoke all on table public.stable_sync_authorities
  from public, anon, authenticated;
revoke all on table public.client_sync_devices
  from public, anon, authenticated;
revoke all on table public.stable_change_events
  from public, anon, authenticated;
revoke all on table public.sync_conflicts
  from public, anon, authenticated;
revoke all on table public.legacy_import_jobs
  from public, anon, authenticated;
revoke all on table public.legacy_import_items
  from public, anon, authenticated;
revoke all on table private.realtime_channel_topics
  from public, anon, authenticated;
revoke all on table private.client_mutation_receipts
  from public, anon, authenticated;
revoke all on table private.legacy_import_payloads
  from public, anon, authenticated;
revoke all on table private.legacy_feeding_plan_snapshots
  from public, anon, authenticated;
revoke all on table private.legacy_schedule_execution_history
  from public, anon, authenticated;

create policy realtime_messages_private_read
on realtime.messages for select to authenticated
using (
  private.can_join_realtime_topic(realtime.topic())
  and extension = 'broadcast'
  and private is true
);

revoke all on function private.sync_payload_hash(jsonb)
  from public, anon, authenticated;
revoke all on function private.legacy_source_manifest_hash(jsonb, jsonb)
  from public, anon, authenticated;
revoke all on function private.lock_client_request(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.active_sync_membership(uuid)
  from public, anon, authenticated;
revoke all on function private.lock_sync_membership(uuid)
  from public, anon, authenticated;
revoke all on function private.ensure_sync_authority(uuid)
  from public, anon, authenticated;
revoke all on function private.assign_stable_change_sequence()
  from public, anon, authenticated;
revoke all on function private.rotate_sync_authority()
  from public, anon, authenticated;
revoke all on function private.event_is_visible(
  uuid, uuid, text, uuid, text
) from public, anon, authenticated;
revoke all on function private.can_join_realtime_topic(text)
  from public, anon, authenticated;
revoke all on function private.publish_stable_change()
  from public, anon, authenticated;
revoke all on function private.capture_horse_change()
  from public, anon, authenticated;
revoke all on function private.capture_schedule_change()
  from public, anon, authenticated;
revoke all on function private.capture_feeding_change()
  from public, anon, authenticated;
revoke all on function private.require_sync_device(uuid, uuid, bigint)
  from public, anon, authenticated;
revoke all on function private.enforce_offline_execution_device()
  from public, anon, authenticated;
revoke all on function private.reserve_execution_request_namespace()
  from public, anon, authenticated;
revoke all on function private.write_legacy_import_change(
  public.legacy_import_jobs, text
) from public, anon, authenticated;
revoke all on function private.legacy_job_access(uuid, boolean)
  from public, anon, authenticated;
revoke all on function private.legacy_import_mapping_is_current(uuid)
  from public, anon, authenticated;

revoke execute on function public.get_realtime_topics(uuid)
  from public, anon;
revoke execute on function public.pull_operation_changes(
  uuid, bigint, integer, bigint
) from public, anon;
revoke execute on function public.register_sync_device(
  uuid, uuid, text, uuid
) from public, anon;
revoke execute on function public.get_encrypted_offline_dayset(
  uuid, uuid, date, text, bigint
) from public, anon;
revoke execute on function public.sync_schedule_execution(
  uuid, uuid, bigint, uuid, uuid, text, timestamptz, timestamptz,
  timestamp, text, text
) from public, anon;
revoke execute on function public.sync_feeding_execution(
  uuid, uuid, bigint, uuid, uuid, text, timestamptz, timestamptz,
  timestamp, text, text, numeric, text, numeric, text, text, text
) from public, anon;
revoke execute on function public.resolve_sync_conflict(
  uuid, text, text, uuid
) from public, anon;
revoke execute on function public.list_sync_conflicts(uuid)
  from public, anon;
revoke execute on function public.create_legacy_import_job(
  uuid, bytea, text, integer, integer, jsonb, bytea, jsonb, uuid
) from public, anon;
revoke execute on function public.validate_legacy_import_job(
  uuid, bigint, uuid
) from public, anon;
revoke execute on function public.execute_legacy_import_batch(
  uuid, bigint, integer, uuid
) from public, anon;
revoke execute on function public.verify_legacy_import_job(
  uuid, bigint, bytea, uuid
) from public, anon;
revoke execute on function public.cutover_legacy_import_job(
  uuid, bigint, bytea, boolean, uuid
) from public, anon;
revoke execute on function public.rollback_legacy_import_job(
  uuid, bigint, boolean, text, uuid
) from public, anon;
revoke execute on function public.get_legacy_import_job(uuid)
  from public, anon;

grant execute on function public.get_realtime_topics(uuid)
  to authenticated;
grant execute on function public.pull_operation_changes(
  uuid, bigint, integer, bigint
) to authenticated;
grant execute on function public.register_sync_device(
  uuid, uuid, text, uuid
) to authenticated;
grant execute on function public.get_encrypted_offline_dayset(
  uuid, uuid, date, text, bigint
) to authenticated;
grant execute on function public.sync_schedule_execution(
  uuid, uuid, bigint, uuid, uuid, text, timestamptz, timestamptz,
  timestamp, text, text
) to authenticated;
grant execute on function public.sync_feeding_execution(
  uuid, uuid, bigint, uuid, uuid, text, timestamptz, timestamptz,
  timestamp, text, text, numeric, text, numeric, text, text, text
) to authenticated;
grant execute on function public.resolve_sync_conflict(
  uuid, text, text, uuid
) to authenticated;
grant execute on function public.list_sync_conflicts(uuid)
  to authenticated;
grant execute on function public.create_legacy_import_job(
  uuid, bytea, text, integer, integer, jsonb, bytea, jsonb, uuid
) to authenticated;
grant execute on function public.validate_legacy_import_job(
  uuid, bigint, uuid
) to authenticated;
grant execute on function public.execute_legacy_import_batch(
  uuid, bigint, integer, uuid
) to authenticated;
grant execute on function public.verify_legacy_import_job(
  uuid, bigint, bytea, uuid
) to authenticated;
grant execute on function public.cutover_legacy_import_job(
  uuid, bigint, bytea, boolean, uuid
) to authenticated;
grant execute on function public.rollback_legacy_import_job(
  uuid, bigint, boolean, text, uuid
) to authenticated;
grant execute on function public.get_legacy_import_job(uuid)
  to authenticated;

comment on table public.stable_change_events is
  'Durable payload-free 4C.6 sync cursor; every returned row is reauthorized.';
comment on table public.client_sync_devices is
  'Per-user device public keys and authority binding for encrypted daysets.';
comment on table public.sync_conflicts is
  'Bounded non-critical conflicts only; authority and critical data excluded.';
comment on table public.legacy_import_jobs is
  'Explicit opt-in legacy preview, verification, cutover and rollback marker.';
comment on function public.get_encrypted_offline_dayset(
  uuid, uuid, date, text, bigint
) is
  'Returns only an OpenPGP-encrypted assigned dayset. The client must persist ciphertext only and clear it on any auth/sync rejection.';

commit;
