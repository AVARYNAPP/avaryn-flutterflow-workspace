begin;

-- C-003A upgrades the existing Phase 4A profile in place. The durable profile
-- UUID remains the primary key, while authentication becomes a nullable,
-- unique link that can be removed without deleting profile history.

create schema if not exists private;

create or replace function private.c003a_is_valid_iana_time_zone(
  p_time_zone text
)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1
    from pg_catalog.pg_timezone_names zone
    where zone.name = p_time_zone
  )
$$;

revoke all on function private.c003a_is_valid_iana_time_zone(text)
  from public, anon, authenticated, service_role;

drop trigger if exists phase_4a_auth_user_profile on auth.users;
drop trigger if exists phase_4a_profile_before_write on public.profiles;

alter table public.profiles
  add column if not exists auth_user_id uuid,
  add column if not exists time_zone text not null default 'UTC',
  add column if not exists status text not null default 'active',
  add column if not exists access_version bigint not null default 1,
  add column if not exists row_version bigint not null default 1,
  add column if not exists anonymized_at timestamptz;

alter table public.profiles
  alter column id set default extensions.gen_random_uuid();

update public.profiles profile
set auth_user_id = profile.id
where profile.auth_user_id is null
  and exists (
    select 1
    from auth.users auth_user
    where auth_user.id = profile.id
  );

-- The legacy id -> auth.users FK would delete the durable profile. No later
-- migration references profiles, so replacing only this FK is dependency-safe.
alter table public.profiles
  drop constraint if exists profiles_id_fkey;

alter table public.profiles
  add constraint profiles_auth_user_id_fkey
    foreign key (auth_user_id)
    references auth.users (id)
    on delete set null,
  add constraint profiles_auth_user_id_key unique (auth_user_id),
  add constraint profiles_status_check
    check (
      status in (
        'active',
        'deletion_pending',
        'auth_removal_pending',
        'anonymized'
      )
    ),
  add constraint profiles_access_version_check
    check (access_version >= 1),
  add constraint profiles_row_version_check
    check (row_version >= 1),
  add constraint profiles_time_zone_iana_check
    check (private.c003a_is_valid_iana_time_zone(time_zone)),
  add constraint profiles_lifecycle_identity_check
    check (
      (
        status in ('active', 'deletion_pending')
        and auth_user_id is not null
        and anonymized_at is null
      )
      or (
        status = 'auth_removal_pending'
        and anonymized_at is null
      )
      or (
        status = 'anonymized'
        and auth_user_id is null
        and anonymized_at is not null
      )
    );

create index profiles_status_idx on public.profiles (status);

create or replace function private.c003a_audit_json_keys_allowed(
  p_value jsonb,
  p_allowed_keys text[]
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select pg_catalog.jsonb_typeof(p_value) = 'object'
    and not exists (
      select 1
      from pg_catalog.jsonb_object_keys(p_value) key_name
      where not (key_name = any (p_allowed_keys))
    )
$$;

create table public.audit_events (
  id uuid primary key default extensions.gen_random_uuid(),
  schema_version smallint not null default 1,
  actor_kind text not null,
  actor_profile_id uuid,
  system_actor_code text,
  event_type text not null,
  resource_kind text not null,
  resource_id uuid not null,
  scope_kind text not null,
  scope_id uuid not null,
  old_state jsonb not null default '{}'::jsonb,
  new_state jsonb not null default '{}'::jsonb,
  reason_code text not null,
  occurred_at timestamptz not null default pg_catalog.clock_timestamp(),
  correlation_id uuid not null,
  channel text not null,
  row_version_before bigint,
  row_version_after bigint,
  access_version_before bigint,
  access_version_after bigint,
  metadata jsonb not null default '{}'::jsonb,
  constraint audit_events_schema_version_check
    check (schema_version = 1),
  constraint audit_events_actor_kind_check
    check (actor_kind in ('profile', 'system')),
  constraint audit_events_actor_shape_check
    check (
      (
        actor_kind = 'profile'
        and actor_profile_id is not null
        and system_actor_code is null
      )
      or (
        actor_kind = 'system'
        and actor_profile_id is null
        and system_actor_code in (
          'auth_provisioner',
          'account_deletion_orchestrator',
          'profile_maintenance'
        )
      )
    ),
  constraint audit_events_event_type_check
    check (
      event_type in (
        'profile.provisioned',
        'profile.display_fields_updated',
        'profile.deletion_requested',
        'profile.auth_removal_prepared',
        'profile.anonymization_finalized',
        'profile.lifecycle_denied'
      )
    ),
  constraint audit_events_profile_resource_check
    check (
      resource_kind = 'profile'
      and scope_kind = 'profile'
      and resource_id = scope_id
    ),
  constraint audit_events_state_shape_check
    check (
      private.c003a_audit_json_keys_allowed(old_state, array['status'])
      and private.c003a_audit_json_keys_allowed(new_state, array['status'])
    ),
  constraint audit_events_reason_code_check
    check (
      reason_code in (
        'AUTH_USER_CREATED',
        'PROFILE_FIELDS_CHANGED',
        'USER_DELETION_REQUEST',
        'C003A_AUTH_REMOVAL_PREPARED',
        'C003A_ANONYMIZATION_FINALIZED',
        'LIFECYCLE_REQUEST_DENIED'
      )
    ),
  constraint audit_events_channel_check
    check (channel in ('direct_api', 'rpc', 'system')),
  constraint audit_events_versions_check
    check (
      (row_version_before is null or row_version_before >= 1)
      and (row_version_after is null or row_version_after >= 1)
      and (access_version_before is null or access_version_before >= 1)
      and (access_version_after is null or access_version_after >= 1)
    ),
  constraint audit_events_metadata_shape_check
    check (
      private.c003a_audit_json_keys_allowed(
        metadata,
        array[
          'changed_fields',
          'dependency_checks_complete',
          'denial_code'
        ]
      )
    )
);

create index audit_events_resource_time_idx
  on public.audit_events (resource_kind, resource_id, occurred_at desc);
create index audit_events_actor_time_idx
  on public.audit_events (actor_profile_id, occurred_at desc)
  where actor_profile_id is not null;
create index audit_events_correlation_idx
  on public.audit_events (correlation_id);
create index audit_events_type_time_idx
  on public.audit_events (event_type, occurred_at desc);
create unique index audit_events_profile_lifecycle_idempotency_idx
  on public.audit_events (event_type, resource_id, correlation_id)
  where event_type in (
    'profile.deletion_requested',
    'profile.auth_removal_prepared',
    'profile.anonymization_finalized',
    'profile.lifecycle_denied'
  );

create or replace function private.c003a_prevent_audit_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'AUDIT_EVENTS_APPEND_ONLY';
end;
$$;

create trigger audit_events_append_only
before update or delete on public.audit_events
for each row execute function private.c003a_prevent_audit_mutation();

create trigger audit_events_append_only_truncate
before truncate on public.audit_events
for each statement execute function private.c003a_prevent_audit_mutation();

create or replace function private.c003a_write_profile_audit(
  p_event_type text,
  p_profile_id uuid,
  p_actor_profile_id uuid,
  p_system_actor_code text,
  p_correlation_id uuid,
  p_channel text,
  p_old_status text,
  p_new_status text,
  p_row_version_before bigint,
  p_row_version_after bigint,
  p_access_version_before bigint,
  p_access_version_after bigint,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_id uuid;
  actor_kind_value text;
  reason_code_value text;
  changed_field text;
begin
  if p_event_type not in (
    'profile.provisioned',
    'profile.display_fields_updated',
    'profile.deletion_requested',
    'profile.auth_removal_prepared',
    'profile.anonymization_finalized',
    'profile.lifecycle_denied'
  ) then
    raise exception using errcode = '22023', message = 'AUDIT_EVENT_NOT_ALLOWED';
  end if;

  if p_profile_id is null or p_correlation_id is null then
    raise exception using errcode = '22004', message = 'AUDIT_IDENTIFIER_REQUIRED';
  end if;

  if (p_actor_profile_id is null) = (p_system_actor_code is null) then
    raise exception using errcode = '22023', message = 'AUDIT_ACTOR_SHAPE_INVALID';
  end if;

  actor_kind_value := case
    when p_actor_profile_id is not null then 'profile'
    else 'system'
  end;

  if p_system_actor_code is not null
    and p_system_actor_code not in (
      'auth_provisioner',
      'account_deletion_orchestrator',
      'profile_maintenance'
    )
  then
    raise exception using errcode = '22023', message = 'AUDIT_SYSTEM_ACTOR_INVALID';
  end if;

  if p_old_status is not null
    and p_old_status not in (
      'active',
      'deletion_pending',
      'auth_removal_pending',
      'anonymized'
    )
  then
    raise exception using errcode = '22023', message = 'AUDIT_OLD_STATUS_INVALID';
  end if;

  if p_new_status is not null
    and p_new_status not in (
      'active',
      'deletion_pending',
      'auth_removal_pending',
      'anonymized'
    )
  then
    raise exception using errcode = '22023', message = 'AUDIT_NEW_STATUS_INVALID';
  end if;

  p_metadata := coalesce(p_metadata, '{}'::jsonb);

  case p_event_type
    when 'profile.provisioned' then
      reason_code_value := 'AUTH_USER_CREATED';
      if p_metadata <> '{}'::jsonb then
        raise exception using errcode = '22023', message = 'AUDIT_METADATA_INVALID';
      end if;
    when 'profile.display_fields_updated' then
      reason_code_value := 'PROFILE_FIELDS_CHANGED';
      if pg_catalog.jsonb_typeof(p_metadata -> 'changed_fields') <> 'array'
        or (
          select pg_catalog.count(*)
          from pg_catalog.jsonb_object_keys(p_metadata)
        ) <> 1
      then
        raise exception using errcode = '22023', message = 'AUDIT_METADATA_INVALID';
      end if;
      for changed_field in
        select pg_catalog.jsonb_array_elements_text(p_metadata -> 'changed_fields')
      loop
        if changed_field not in (
          'display_name',
          'avatar_object_path',
          'locale',
          'phone_e164',
          'time_zone'
        ) then
          raise exception using errcode = '22023', message = 'AUDIT_CHANGED_FIELD_INVALID';
        end if;
      end loop;
    when 'profile.deletion_requested' then
      reason_code_value := 'USER_DELETION_REQUEST';
      if p_metadata <> '{}'::jsonb then
        raise exception using errcode = '22023', message = 'AUDIT_METADATA_INVALID';
      end if;
    when 'profile.auth_removal_prepared' then
      reason_code_value := 'C003A_AUTH_REMOVAL_PREPARED';
      if p_metadata <> '{"dependency_checks_complete": false}'::jsonb then
        raise exception using errcode = '22023', message = 'AUDIT_METADATA_INVALID';
      end if;
    when 'profile.anonymization_finalized' then
      reason_code_value := 'C003A_ANONYMIZATION_FINALIZED';
      if p_metadata <> '{"dependency_checks_complete": false}'::jsonb then
        raise exception using errcode = '22023', message = 'AUDIT_METADATA_INVALID';
      end if;
    when 'profile.lifecycle_denied' then
      reason_code_value := 'LIFECYCLE_REQUEST_DENIED';
      if pg_catalog.jsonb_typeof(p_metadata -> 'denial_code') <> 'string'
        or (
          select pg_catalog.count(*)
          from pg_catalog.jsonb_object_keys(p_metadata)
        ) <> 1
        or (p_metadata ->> 'denial_code') not in (
          'STALE_ROW_VERSION',
          'PROFILE_NOT_ACTIVE'
        )
      then
        raise exception using errcode = '22023', message = 'AUDIT_METADATA_INVALID';
      end if;
  end case;

  insert into public.audit_events (
    actor_kind,
    actor_profile_id,
    system_actor_code,
    event_type,
    resource_kind,
    resource_id,
    scope_kind,
    scope_id,
    old_state,
    new_state,
    reason_code,
    correlation_id,
    channel,
    row_version_before,
    row_version_after,
    access_version_before,
    access_version_after,
    metadata
  )
  values (
    actor_kind_value,
    p_actor_profile_id,
    p_system_actor_code,
    p_event_type,
    'profile',
    p_profile_id,
    'profile',
    p_profile_id,
    case
      when p_old_status is null then '{}'::jsonb
      else pg_catalog.jsonb_build_object('status', p_old_status)
    end,
    case
      when p_new_status is null then '{}'::jsonb
      else pg_catalog.jsonb_build_object('status', p_new_status)
    end,
    reason_code_value,
    p_correlation_id,
    p_channel,
    p_row_version_before,
    p_row_version_after,
    p_access_version_before,
    p_access_version_after,
    p_metadata
  )
  returning id into event_id;

  return event_id;
end;
$$;

create or replace function private.current_profile_id()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  matched_ids uuid[];
begin
  if auth.uid() is null then
    return null;
  end if;

  select pg_catalog.array_agg(profile.id)
  into matched_ids
  from public.profiles profile
  where profile.auth_user_id = auth.uid()
    and profile.status = 'active';

  if coalesce(pg_catalog.cardinality(matched_ids), 0) <> 1 then
    return null;
  end if;

  return matched_ids[1];
end;
$$;

create or replace function private.require_current_profile_id()
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  profile_id uuid;
begin
  profile_id := private.current_profile_id();
  if profile_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_PROFILE_REQUIRED';
  end if;
  return profile_id;
end;
$$;

create or replace function public.phase_4a_profile_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  business_value_changed boolean;
begin
  new.display_name := coalesce(
    nullif(pg_catalog.btrim(new.display_name), ''),
    'AVARYN user'
  );
  new.first_name := nullif(pg_catalog.btrim(new.first_name), '');
  new.last_name := nullif(pg_catalog.btrim(new.last_name), '');
  new.phone_e164 := nullif(pg_catalog.btrim(new.phone_e164), '');
  new.avatar_object_path := nullif(
    pg_catalog.btrim(new.avatar_object_path),
    ''
  );
  new.locale := coalesce(
    nullif(pg_catalog.btrim(new.locale), ''),
    'und'
  );
  new.time_zone := coalesce(
    nullif(pg_catalog.btrim(new.time_zone), ''),
    'UTC'
  );

  if tg_op = 'INSERT' then
    new.id := coalesce(new.id, extensions.gen_random_uuid());
    new.status := coalesce(new.status, 'active');
    new.access_version := coalesce(new.access_version, 1);
    new.row_version := coalesce(new.row_version, 1);
    new.created_at := coalesce(
      new.created_at,
      pg_catalog.clock_timestamp()
    );
    new.updated_at := coalesce(new.updated_at, new.created_at);

    if new.status <> 'active'
      or new.auth_user_id is null
      or new.access_version <> 1
      or new.row_version <> 1
      or new.anonymized_at is not null
    then
      raise exception using errcode = '22023', message = 'PROFILE_INSERT_INVALID';
    end if;
    return new;
  end if;

  if new.id is distinct from old.id
    or new.created_at is distinct from old.created_at
    or new.updated_at is distinct from old.updated_at
    or new.row_version is distinct from old.row_version
  then
    raise exception using errcode = '22023', message = 'PROFILE_TECHNICAL_FIELD_IMMUTABLE';
  end if;

  if new.status = old.status then
    if new.access_version is distinct from old.access_version then
      raise exception using errcode = '22023', message = 'PROFILE_ACCESS_VERSION_INVALID';
    end if;
  else
    if not (
      (old.status = 'active' and new.status = 'deletion_pending')
      or (
        old.status = 'deletion_pending'
        and new.status = 'auth_removal_pending'
      )
      or (
        old.status = 'auth_removal_pending'
        and new.status = 'anonymized'
      )
    ) then
      raise exception using errcode = '22023', message = 'PROFILE_LIFECYCLE_INVALID';
    end if;
    if new.access_version <> old.access_version + 1 then
      raise exception using errcode = '22023', message = 'PROFILE_ACCESS_VERSION_INVALID';
    end if;
  end if;

  if new.auth_user_id is distinct from old.auth_user_id then
    if not (
      old.status = 'auth_removal_pending'
      and new.status = 'auth_removal_pending'
      and old.auth_user_id is not null
      and new.auth_user_id is null
    ) then
      raise exception using errcode = '22023', message = 'PROFILE_AUTH_LINK_INVALID';
    end if;
  end if;

  if new.anonymized_at is distinct from old.anonymized_at
    and not (
      old.status = 'auth_removal_pending'
      and new.status = 'anonymized'
      and old.anonymized_at is null
      and new.anonymized_at is not null
    )
  then
    raise exception using errcode = '22023', message = 'PROFILE_ANONYMIZED_AT_INVALID';
  end if;

  business_value_changed := row(
    new.auth_user_id,
    new.first_name,
    new.last_name,
    new.display_name,
    new.avatar_object_path,
    new.phone_e164,
    new.locale,
    new.theme_mode,
    new.onboarding_intent,
    new.onboarding_completed_at,
    new.accepted_terms_version,
    new.accepted_privacy_version,
    new.time_zone,
    new.status,
    new.access_version,
    new.anonymized_at
  ) is distinct from row(
    old.auth_user_id,
    old.first_name,
    old.last_name,
    old.display_name,
    old.avatar_object_path,
    old.phone_e164,
    old.locale,
    old.theme_mode,
    old.onboarding_intent,
    old.onboarding_completed_at,
    old.accepted_terms_version,
    old.accepted_privacy_version,
    old.time_zone,
    old.status,
    old.access_version,
    old.anonymized_at
  );

  if not business_value_changed then
    return null;
  end if;

  new.row_version := old.row_version + 1;
  new.updated_at := pg_catalog.clock_timestamp();
  return new;
end;
$$;

create trigger phase_4a_profile_before_write
before insert or update on public.profiles
for each row execute function public.phase_4a_profile_before_write();

create or replace function private.c003a_audit_profile_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.c003a_write_profile_audit(
    'profile.provisioned',
    new.id,
    null,
    'auth_provisioner',
    extensions.gen_random_uuid(),
    'system',
    null,
    new.status,
    null,
    new.row_version,
    null,
    new.access_version,
    '{}'::jsonb
  );
  return new;
end;
$$;

create trigger c003a_profile_provision_audit
after insert on public.profiles
for each row execute function private.c003a_audit_profile_insert();

create or replace function private.c003a_audit_safe_profile_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  changed_fields text[];
  actor_profile_id uuid;
  system_actor_code text;
  event_channel text;
begin
  if old.status <> new.status then
    return new;
  end if;

  changed_fields := pg_catalog.array_remove(array[
    case when old.display_name is distinct from new.display_name
      then 'display_name' end,
    case when old.avatar_object_path is distinct from new.avatar_object_path
      then 'avatar_object_path' end,
    case when old.locale is distinct from new.locale then 'locale' end,
    case when old.phone_e164 is distinct from new.phone_e164
      then 'phone_e164' end,
    case when old.time_zone is distinct from new.time_zone
      then 'time_zone' end
  ], null);

  if pg_catalog.cardinality(changed_fields) = 0 then
    return new;
  end if;

  actor_profile_id := private.current_profile_id();
  if actor_profile_id = new.id then
    system_actor_code := null;
    event_channel := 'direct_api';
  else
    actor_profile_id := null;
    system_actor_code := 'profile_maintenance';
    event_channel := 'system';
  end if;

  perform private.c003a_write_profile_audit(
    'profile.display_fields_updated',
    new.id,
    actor_profile_id,
    system_actor_code,
    extensions.gen_random_uuid(),
    event_channel,
    old.status,
    new.status,
    old.row_version,
    new.row_version,
    old.access_version,
    new.access_version,
    pg_catalog.jsonb_build_object('changed_fields', changed_fields)
  );
  return new;
end;
$$;

create trigger c003a_profile_safe_update_audit
after update on public.profiles
for each row execute function private.c003a_audit_safe_profile_update();

create or replace function public.phase_4a_create_profile_for_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (
    id,
    auth_user_id,
    display_name,
    locale,
    time_zone,
    theme_mode,
    status,
    access_version,
    row_version
  )
  values (
    extensions.gen_random_uuid(),
    new.id,
    'AVARYN user',
    'und',
    'UTC',
    'system',
    'active',
    1,
    1
  )
  on conflict (auth_user_id) do nothing;
  return new;
end;
$$;

create trigger phase_4a_auth_user_profile
after insert on auth.users
for each row execute function public.phase_4a_create_profile_for_auth_user();

create or replace function public.request_profile_deletion(
  p_expected_row_version bigint,
  p_correlation_id uuid
)
returns table (
  result_code text,
  profile_status text,
  row_version bigint,
  access_version bigint,
  correlation_id uuid,
  applied boolean,
  production_ready boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_ids uuid[];
  profile_before public.profiles%rowtype;
  profile_after public.profiles%rowtype;
  prior_event public.audit_events%rowtype;
begin
  if p_correlation_id is null then
    raise exception using errcode = '22004', message = 'CORRELATION_ID_REQUIRED';
  end if;

  select pg_catalog.array_agg(profile.id)
  into actor_ids
  from public.profiles profile
  where profile.auth_user_id = auth.uid();

  if coalesce(pg_catalog.cardinality(actor_ids), 0) <> 1 then
    raise exception using errcode = '42501', message = 'ACTIVE_PROFILE_REQUIRED';
  end if;

  select profile.*
  into profile_before
  from public.profiles profile
  where profile.id = actor_ids[1]
  for update;

  select event.*
  into prior_event
  from public.audit_events event
  where event.event_type = 'profile.deletion_requested'
    and event.resource_id = profile_before.id
    and event.correlation_id = p_correlation_id;

  if found then
    return query select
      'idempotent_replay'::text,
      prior_event.new_state ->> 'status',
      prior_event.row_version_after,
      prior_event.access_version_after,
      p_correlation_id,
      false,
      false;
    return;
  end if;

  if profile_before.status <> 'active' then
    raise exception using errcode = '42501', message = 'ACTIVE_PROFILE_REQUIRED';
  end if;

  if p_expected_row_version is null
    or p_expected_row_version <> profile_before.row_version
  then
    if not exists (
      select 1
      from public.audit_events event
      where event.event_type = 'profile.lifecycle_denied'
        and event.resource_id = profile_before.id
        and event.correlation_id = p_correlation_id
    ) then
      perform private.c003a_write_profile_audit(
        'profile.lifecycle_denied',
        profile_before.id,
        profile_before.id,
        null,
        p_correlation_id,
        'rpc',
        profile_before.status,
        profile_before.status,
        profile_before.row_version,
        profile_before.row_version,
        profile_before.access_version,
        profile_before.access_version,
        '{"denial_code": "STALE_ROW_VERSION"}'::jsonb
      );
    end if;
    return query select
      'stale_row_version'::text,
      profile_before.status,
      profile_before.row_version,
      profile_before.access_version,
      p_correlation_id,
      false,
      false;
    return;
  end if;

  update public.profiles profile
  set
    status = 'deletion_pending',
    access_version = profile.access_version + 1
  where profile.id = profile_before.id
  returning profile.* into profile_after;

  perform private.c003a_write_profile_audit(
    'profile.deletion_requested',
    profile_after.id,
    profile_after.id,
    null,
    p_correlation_id,
    'rpc',
    profile_before.status,
    profile_after.status,
    profile_before.row_version,
    profile_after.row_version,
    profile_before.access_version,
    profile_after.access_version,
    '{}'::jsonb
  );

  return query select
    'deletion_pending'::text,
    profile_after.status,
    profile_after.row_version,
    profile_after.access_version,
    p_correlation_id,
    true,
    false;
end;
$$;

-- Internal-only C-003A foundation. Later phases must atomically add blockers
-- and dependency cleanup before any trusted deletion orchestrator may expose it.
create or replace function private.prepare_profile_auth_removal(
  p_profile_id uuid,
  p_expected_row_version bigint,
  p_correlation_id uuid
)
returns table (
  result_code text,
  profile_status text,
  row_version bigint,
  access_version bigint,
  correlation_id uuid,
  applied boolean,
  production_ready boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  profile_before public.profiles%rowtype;
  profile_after public.profiles%rowtype;
  prior_event public.audit_events%rowtype;
begin
  if p_profile_id is null or p_correlation_id is null then
    raise exception using errcode = '22004', message = 'IDENTIFIERS_REQUIRED';
  end if;

  select profile.*
  into profile_before
  from public.profiles profile
  where profile.id = p_profile_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'PROFILE_NOT_FOUND';
  end if;

  select event.*
  into prior_event
  from public.audit_events event
  where event.event_type = 'profile.auth_removal_prepared'
    and event.resource_id = p_profile_id
    and event.correlation_id = p_correlation_id;

  if found then
    return query select
      'idempotent_replay'::text,
      prior_event.new_state ->> 'status',
      prior_event.row_version_after,
      prior_event.access_version_after,
      p_correlation_id,
      false,
      false;
    return;
  end if;

  if profile_before.status = 'auth_removal_pending' then
    return query select
      'already_prepared'::text,
      profile_before.status,
      profile_before.row_version,
      profile_before.access_version,
      p_correlation_id,
      false,
      false;
    return;
  end if;

  if profile_before.status <> 'deletion_pending' then
    raise exception using errcode = '55000', message = 'DELETION_PENDING_REQUIRED';
  end if;

  if p_expected_row_version is null
    or p_expected_row_version <> profile_before.row_version
  then
    raise exception using errcode = '40001', message = 'STALE_ROW_VERSION';
  end if;

  update public.profiles profile
  set
    first_name = null,
    last_name = null,
    display_name = 'Deleted AVARYN account',
    avatar_object_path = null,
    phone_e164 = null,
    locale = 'und',
    time_zone = 'UTC',
    theme_mode = 'system',
    onboarding_intent = null,
    onboarding_completed_at = null,
    accepted_terms_version = null,
    accepted_privacy_version = null,
    status = 'auth_removal_pending',
    access_version = profile.access_version + 1
  where profile.id = p_profile_id
  returning profile.* into profile_after;

  perform private.c003a_write_profile_audit(
    'profile.auth_removal_prepared',
    profile_after.id,
    null,
    'account_deletion_orchestrator',
    p_correlation_id,
    'system',
    profile_before.status,
    profile_after.status,
    profile_before.row_version,
    profile_after.row_version,
    profile_before.access_version,
    profile_after.access_version,
    '{"dependency_checks_complete": false}'::jsonb
  );

  return query select
    'auth_removal_pending'::text,
    profile_after.status,
    profile_after.row_version,
    profile_after.access_version,
    p_correlation_id,
    true,
    false;
end;
$$;

create or replace function private.finalize_profile_anonymization(
  p_profile_id uuid,
  p_expected_row_version bigint,
  p_correlation_id uuid
)
returns table (
  result_code text,
  profile_status text,
  row_version bigint,
  access_version bigint,
  correlation_id uuid,
  applied boolean,
  production_ready boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  profile_before public.profiles%rowtype;
  profile_after public.profiles%rowtype;
  prior_event public.audit_events%rowtype;
begin
  if p_profile_id is null or p_correlation_id is null then
    raise exception using errcode = '22004', message = 'IDENTIFIERS_REQUIRED';
  end if;

  select profile.*
  into profile_before
  from public.profiles profile
  where profile.id = p_profile_id
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'PROFILE_NOT_FOUND';
  end if;

  select event.*
  into prior_event
  from public.audit_events event
  where event.event_type = 'profile.anonymization_finalized'
    and event.resource_id = p_profile_id
    and event.correlation_id = p_correlation_id;

  if found then
    return query select
      'idempotent_replay'::text,
      prior_event.new_state ->> 'status',
      prior_event.row_version_after,
      prior_event.access_version_after,
      p_correlation_id,
      false,
      false;
    return;
  end if;

  if profile_before.status = 'anonymized' then
    return query select
      'already_anonymized'::text,
      profile_before.status,
      profile_before.row_version,
      profile_before.access_version,
      p_correlation_id,
      false,
      false;
    return;
  end if;

  if profile_before.status <> 'auth_removal_pending' then
    raise exception using errcode = '55000', message = 'AUTH_REMOVAL_PENDING_REQUIRED';
  end if;

  if profile_before.auth_user_id is not null then
    raise exception using errcode = '55000', message = 'AUTH_LINK_STILL_PRESENT';
  end if;

  if p_expected_row_version is null
    or p_expected_row_version <> profile_before.row_version
  then
    raise exception using errcode = '40001', message = 'STALE_ROW_VERSION';
  end if;

  update public.profiles profile
  set
    status = 'anonymized',
    anonymized_at = pg_catalog.clock_timestamp(),
    access_version = profile.access_version + 1
  where profile.id = p_profile_id
  returning profile.* into profile_after;

  perform private.c003a_write_profile_audit(
    'profile.anonymization_finalized',
    profile_after.id,
    null,
    'account_deletion_orchestrator',
    p_correlation_id,
    'system',
    profile_before.status,
    profile_after.status,
    profile_before.row_version,
    profile_after.row_version,
    profile_before.access_version,
    profile_after.access_version,
    '{"dependency_checks_complete": false}'::jsonb
  );

  return query select
    'anonymized'::text,
    profile_after.status,
    profile_after.row_version,
    profile_after.access_version,
    p_correlation_id,
    true,
    false;
end;
$$;

alter table public.profiles enable row level security;
alter table public.audit_events enable row level security;

revoke all on table public.profiles
  from public, anon, authenticated, service_role;
revoke all on table public.audit_events
  from public, anon, authenticated, service_role;

grant select (
  id,
  display_name,
  avatar_object_path,
  phone_e164,
  locale,
  time_zone,
  status,
  access_version,
  row_version,
  created_at,
  updated_at,
  anonymized_at
) on public.profiles to authenticated;

grant update (
  display_name,
  avatar_object_path,
  phone_e164,
  locale,
  time_zone
) on public.profiles to authenticated;

drop policy if exists "profiles_select_own" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own" on public.profiles;

create policy profiles_select_active_own
on public.profiles
for select
to authenticated
using (private.current_profile_id() = id);

create policy profiles_update_active_own_safe_fields
on public.profiles
for update
to authenticated
using (private.current_profile_id() = id)
with check (private.current_profile_id() = id);

revoke all on function public.phase_4a_profile_before_write()
  from public, anon, authenticated, service_role;
revoke all on function public.phase_4a_create_profile_for_auth_user()
  from public, anon, authenticated, service_role;
revoke all on function private.c003a_audit_json_keys_allowed(jsonb, text[])
  from public, anon, authenticated, service_role;
revoke all on function private.c003a_prevent_audit_mutation()
  from public, anon, authenticated, service_role;
revoke all on function private.c003a_write_profile_audit(
  text, uuid, uuid, text, uuid, text, text, text,
  bigint, bigint, bigint, bigint, jsonb
) from public, anon, authenticated, service_role;
revoke all on function private.c003a_audit_profile_insert()
  from public, anon, authenticated, service_role;
revoke all on function private.c003a_audit_safe_profile_update()
  from public, anon, authenticated, service_role;
revoke all on function private.current_profile_id()
  from public, anon, authenticated, service_role;
revoke all on function private.require_current_profile_id()
  from public, anon, authenticated, service_role;
revoke all on function private.prepare_profile_auth_removal(uuid, bigint, uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.finalize_profile_anonymization(uuid, bigint, uuid)
  from public, anon, authenticated, service_role;

grant usage on schema private to authenticated;
grant execute on function private.c003a_is_valid_iana_time_zone(text)
  to authenticated;
grant execute on function private.current_profile_id() to authenticated;

revoke all on function public.request_profile_deletion(bigint, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.request_profile_deletion(bigint, uuid)
  to authenticated;

comment on table public.profiles is
  'C-003A durable personal profiles. auth_user_id is the nullable one-to-one Auth link.';
comment on column public.profiles.id is
  'Durable server-generated profile UUID; never a client or Auth claim.';
comment on column public.profiles.access_version is
  'Server-managed monotone authorization cache invalidation version.';
comment on table public.audit_events is
  'C-003A append-only allowlisted identity and lifecycle audit foundation.';
comment on function private.prepare_profile_auth_removal(uuid, bigint, uuid) is
  'Internal C-003A preparation only. Not production-ready until later dependency checks and C-003F pass.';
comment on function private.finalize_profile_anonymization(uuid, bigint, uuid) is
  'Internal C-003A finalization only. Not production-ready until later dependency checks and C-003F pass.';

commit;
