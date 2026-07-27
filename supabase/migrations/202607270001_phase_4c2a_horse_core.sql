begin;

alter table public.stable_memberships
  add constraint stable_memberships_stable_and_id_unique
  unique (stable_id, id);

create table public.horses (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  status text not null default 'active'
    check (status in ('active', 'archived')),
  display_name text not null
    check (length(btrim(display_name)) between 1 and 120),
  official_name text
    check (
      official_name is null
      or length(btrim(official_name)) between 1 and 200
    ),
  birth_date date,
  sex text not null default 'unknown'
    check (sex in ('mare', 'gelding', 'stallion', 'unknown')),
  breed text
    check (breed is null or length(btrim(breed)) between 1 and 120),
  discipline text
    check (
      discipline is null
      or length(btrim(discipline)) between 1 and 120
    ),
  level text
    check (level is null or length(btrim(level)) between 1 and 120),
  profile_media_asset_id uuid,
  legacy_local_horse_id bigint,
  source_kind text not null default 'manual'
    check (source_kind in ('manual', 'legacy_import', 'external_verified')),
  row_version bigint not null default 1 check (row_version > 0),
  created_by_user_id uuid not null references auth.users (id),
  created_request_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  constraint horses_stable_and_id_unique unique (stable_id, id),
  constraint horses_creation_request_unique
    unique (created_by_user_id, created_request_id),
  constraint horses_archive_timestamp
    check (
      (status = 'active' and archived_at is null)
      or (status = 'archived' and archived_at is not null)
    )
);

create unique index horses_legacy_per_stable_unique
  on public.horses (stable_id, legacy_local_horse_id)
  where legacy_local_horse_id is not null;

create index horses_stable_status_name
  on public.horses (stable_id, status, lower(display_name), id);

create table public.horse_access_grants (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null,
  horse_id uuid not null,
  membership_id uuid not null,
  category text not null
    check (
      category in (
        'horse.basic',
        'horse.identity',
        'horse.team',
        'horse.schedule',
        'horse.nutrition',
        'horse.health_summary',
        'horse.health_detail',
        'horse.media',
        'horse.permissions'
      )
    ),
  can_view boolean not null default false,
  can_execute boolean not null default false,
  can_edit boolean not null default false,
  can_manage boolean not null default false,
  status text not null default 'active'
    check (status in ('active', 'revoked', 'expired')),
  valid_from timestamptz not null default timezone('utc', now()),
  valid_until timestamptz,
  granted_by_user_id uuid not null references auth.users (id),
  granted_request_id uuid not null,
  grant_reason text
    check (
      grant_reason is null
      or length(btrim(grant_reason)) between 1 and 500
    ),
  revoked_by_user_id uuid references auth.users (id),
  revoked_request_id uuid,
  revoked_at timestamptz,
  row_version bigint not null default 1 check (row_version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint horse_access_grants_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint horse_access_grants_membership_fk
    foreign key (stable_id, membership_id)
    references public.stable_memberships (stable_id, id),
  constraint horse_access_grants_capability_shape
    check (
      can_view
      and (not can_execute or can_view)
      and (not can_edit or can_view)
      and (not can_manage or (can_view and can_edit))
    ),
  constraint horse_access_grants_validity_window
    check (valid_until is null or valid_until > valid_from),
  constraint horse_access_grants_sensitive_reason
    check (
      category in ('horse.basic', 'horse.schedule')
      or (
        grant_reason is not null
        and length(btrim(grant_reason)) between 1 and 500
      )
    ),
  constraint horse_access_grants_revocation_lifecycle
    check (
      (
        status = 'active'
        and revoked_by_user_id is null
        and revoked_request_id is null
        and revoked_at is null
      )
      or (
        status = 'revoked'
        and revoked_by_user_id is not null
        and revoked_request_id is not null
        and revoked_at is not null
      )
      or (
        status = 'expired'
        and revoked_by_user_id is null
        and revoked_request_id is null
        and revoked_at is null
      )
    ),
  constraint horse_access_grants_grant_request_unique
    unique (granted_by_user_id, granted_request_id),
  constraint horse_access_grants_revoke_request_unique
    unique (revoked_by_user_id, revoked_request_id)
);

create unique index horse_access_grants_one_active
  on public.horse_access_grants (horse_id, membership_id, category)
  where status = 'active';

create index horse_access_grants_membership_active
  on public.horse_access_grants (
    membership_id,
    horse_id,
    category,
    valid_from,
    valid_until
  )
  where status = 'active';

create index horse_access_grants_horse_active
  on public.horse_access_grants (horse_id, category, membership_id, id)
  where status = 'active';

create table public.horse_profile_change_events (
  id bigint generated always as identity primary key,
  stable_id uuid not null,
  horse_id uuid not null,
  actor_user_id uuid not null references auth.users (id),
  actor_membership_id uuid not null,
  request_id uuid not null,
  event_type text not null
    check (
      event_type in (
        'horse_created',
        'horse_profile_updated',
        'horse_archived'
      )
    ),
  changed_fields text[] not null,
  old_values jsonb not null default '{}'::jsonb,
  new_values jsonb not null default '{}'::jsonb,
  reason text
    check (
      reason is null
      or length(btrim(reason)) between 1 and 500
    ),
  created_at timestamptz not null default timezone('utc', now()),
  constraint horse_profile_change_events_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint horse_profile_change_events_actor_membership_fk
    foreign key (stable_id, actor_membership_id)
    references public.stable_memberships (stable_id, id),
  constraint horse_profile_change_events_request_unique
    unique (actor_user_id, request_id),
  constraint horse_profile_change_events_changed_fields
    check (
      cardinality(changed_fields) > 0
      and changed_fields <@ array[
        'status',
        'display_name',
        'official_name',
        'birth_date',
        'sex',
        'breed',
        'discipline',
        'level'
      ]::text[]
    ),
  constraint horse_profile_change_events_json_objects
    check (
      jsonb_typeof(old_values) = 'object'
      and jsonb_typeof(new_values) = 'object'
    ),
  constraint horse_profile_change_events_archive_reason
    check (
      event_type <> 'horse_archived'
      or (
        reason is not null
        and length(btrim(reason)) between 1 and 500
      )
    )
);

create index horse_profile_change_events_horse_created
  on public.horse_profile_change_events (horse_id, created_at desc, id desc);

alter table public.stable_security_events
  add constraint stable_security_events_horse_fk
  foreign key (stable_id, horse_id)
  references public.horses (stable_id, id)
  not valid;

alter table public.stable_security_events
  validate constraint stable_security_events_horse_fk;

create or replace function private.touch_horse()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.display_name := btrim(new.display_name);
  new.official_name := nullif(btrim(new.official_name), '');
  new.breed := nullif(btrim(new.breed), '');
  new.discipline := nullif(btrim(new.discipline), '');
  new.level := nullif(btrim(new.level), '');
  new.updated_at := timezone('utc', pg_catalog.now());
  if tg_op = 'UPDATE' then
    new.row_version := old.row_version + 1;
  end if;
  return new;
end;
$$;

create trigger horses_touch_before_write
before insert or update on public.horses
for each row execute function private.touch_horse();

create or replace function private.touch_horse_access_grant()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.grant_reason := nullif(btrim(new.grant_reason), '');
  new.updated_at := timezone('utc', pg_catalog.now());
  if tg_op = 'UPDATE' then
    new.row_version := old.row_version + 1;
  end if;
  return new;
end;
$$;

create trigger horse_access_grants_touch_before_write
before insert or update on public.horse_access_grants
for each row execute function private.touch_horse_access_grant();

create or replace function private.has_horse_capability(
  p_horse_id uuid,
  p_category text,
  p_capability text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with actor_membership as (
    select m.id, m.role
    from public.horses h
    join public.stable_memberships m
      on m.stable_id = h.stable_id
    join public.stables s
      on s.id = h.stable_id
    where h.id = p_horse_id
      and s.status = 'active'
      and m.user_id = auth.uid()
      and m.status = 'active'
    limit 1
  )
  select exists (
    select 1
    from actor_membership actor
    where actor.role = 'owner'
      or (
        actor.role = 'admin'
        and (
          (
            p_category = 'horse.basic'
            and p_capability in ('view', 'edit')
          )
          or (
            p_category = 'horse.team'
            and p_capability in ('view', 'edit', 'manage')
          )
          or (
            p_category = 'horse.schedule'
            and p_capability in ('view', 'execute', 'edit', 'manage')
          )
        )
      )
      or exists (
        select 1
        from public.horse_access_grants g
        where g.horse_id = p_horse_id
          and g.membership_id = actor.id
          and g.status = 'active'
          and g.category = p_category
          and g.valid_from <= timezone('utc', pg_catalog.now())
          and (
            g.valid_until is null
            or g.valid_until > timezone('utc', pg_catalog.now())
          )
          and case p_capability
            when 'view' then g.can_view
            when 'execute' then g.can_execute
            when 'edit' then g.can_edit
            when 'manage' then g.can_manage
            else false
          end
      )
  )
$$;

create or replace function private.can_manage_horse_grants(
  p_horse_id uuid,
  p_category text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with actor_membership as (
    select m.id, m.role
    from public.horses h
    join public.stable_memberships m
      on m.stable_id = h.stable_id
    join public.stables s
      on s.id = h.stable_id
    where h.id = p_horse_id
      and s.status = 'active'
      and m.user_id = auth.uid()
      and m.status = 'active'
    limit 1
  )
  select exists (
    select 1
    from actor_membership actor
    where actor.role = 'owner'
      or (
        actor.role = 'admin'
        and (
          p_category in ('horse.basic', 'horse.schedule')
          or exists (
            select 1
            from public.horse_access_grants g
            where g.horse_id = p_horse_id
              and g.membership_id = actor.id
              and g.category = p_category
              and g.status = 'active'
              and g.can_manage
              and g.valid_from <= timezone('utc', pg_catalog.now())
              and (
                g.valid_until is null
                or g.valid_until > timezone('utc', pg_catalog.now())
              )
          )
        )
      )
  )
$$;

create or replace function private.write_horse_security_event(
  p_stable_id uuid,
  p_horse_id uuid,
  p_event_type text,
  p_actor_membership_id uuid,
  p_subject_membership_id uuid,
  p_request_id uuid,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_event_type not in (
    'horse_access_granted',
    'horse_access_revoked'
  ) then
    raise exception using
      errcode = '22023',
      message = 'INVALID_HORSE_SECURITY_EVENT';
  end if;
  if p_stable_id is null
    or p_horse_id is null
    or p_actor_membership_id is null
    or p_subject_membership_id is null
    or p_request_id is null
  then
    raise exception using
      errcode = '22023',
      message = 'HORSE_SECURITY_EVENT_CORRELATION_REQUIRED';
  end if;
  if jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) <> 'object' then
    raise exception using
      errcode = '22023',
      message = 'INVALID_HORSE_SECURITY_METADATA';
  end if;
  if not exists (
    select 1
    from public.stable_memberships m
    where m.id = p_actor_membership_id
      and m.stable_id = p_stable_id
      and m.user_id = auth.uid()
  ) or not exists (
    select 1
    from public.stable_memberships m
    where m.id = p_subject_membership_id
      and m.stable_id = p_stable_id
  ) then
    raise exception using
      errcode = '22023',
      message = 'HORSE_SECURITY_EVENT_CORRELATION_REQUIRED';
  end if;

  insert into public.stable_security_events (
    stable_id,
    horse_id,
    actor_user_id,
    actor_membership_id,
    event_type,
    subject_membership_id,
    request_id,
    metadata
  )
  values (
    p_stable_id,
    p_horse_id,
    auth.uid(),
    p_actor_membership_id,
    p_event_type,
    p_subject_membership_id,
    p_request_id,
    coalesce(p_metadata, '{}'::jsonb)
  );
end;
$$;

create or replace function private.horse_profile_json(
  p_horse public.horses
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'status', p_horse.status,
    'display_name', p_horse.display_name,
    'official_name', p_horse.official_name,
    'birth_date', p_horse.birth_date,
    'sex', p_horse.sex,
    'breed', p_horse.breed,
    'discipline', p_horse.discipline,
    'level', p_horse.level
  )
$$;

create or replace function public.create_horse(
  p_stable_id uuid,
  p_display_name text,
  p_request_id uuid,
  p_official_name text default null,
  p_birth_date date default null,
  p_sex text default 'unknown',
  p_breed text default null,
  p_discipline text default null,
  p_level text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  actor_membership public.stable_memberships%rowtype;
  existing_horse public.horses%rowtype;
  result public.horses%rowtype;
  normalized_display_name text := btrim(coalesce(p_display_name, ''));
  normalized_official_name text := nullif(btrim(p_official_name), '');
  normalized_breed text := nullif(btrim(p_breed), '');
  normalized_discipline text := nullif(btrim(p_discipline), '');
  normalized_level text := nullif(btrim(p_level), '');
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if length(normalized_display_name) not between 1 and 120
    or (
      normalized_official_name is not null
      and length(normalized_official_name) > 200
    )
    or (
      normalized_breed is not null
      and length(normalized_breed) > 120
    )
    or (
      normalized_discipline is not null
      and length(normalized_discipline) > 120
    )
    or (
      normalized_level is not null
      and length(normalized_level) > 120
    )
    or p_sex is null
    or p_sex not in ('mare', 'gelding', 'stallion', 'unknown')
  then
    raise exception using errcode = '22023', message = 'INVALID_HORSE_PROFILE';
  end if;
  if p_birth_date is not null and p_birth_date > current_date then
    raise exception using errcode = '22023', message = 'INVALID_BIRTH_DATE';
  end if;

  perform 1
  from public.stables s
  where s.id = p_stable_id
    and s.status = 'active'
  for share;
  if not found then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  select m.* into actor_membership
  from public.stable_memberships m
  where m.stable_id = p_stable_id
    and m.user_id = actor_id
    and m.status = 'active'
    and m.role in ('owner', 'admin')
  for share;

  if actor_membership.id is null then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  select * into existing_horse
  from public.horses h
  where h.created_by_user_id = actor_id
    and h.created_request_id = p_request_id;

  if existing_horse.id is not null then
    if existing_horse.stable_id = p_stable_id
      and existing_horse.display_name = normalized_display_name
      and existing_horse.official_name is not distinct from normalized_official_name
      and existing_horse.birth_date is not distinct from p_birth_date
      and existing_horse.sex = p_sex
      and existing_horse.breed is not distinct from normalized_breed
      and existing_horse.discipline is not distinct from normalized_discipline
      and existing_horse.level is not distinct from normalized_level
    then
      return jsonb_build_object(
        'horse_id', existing_horse.id,
        'row_version', existing_horse.row_version,
        'idempotent', true
      );
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;

  insert into public.horses (
    stable_id,
    display_name,
    official_name,
    birth_date,
    sex,
    breed,
    discipline,
    level,
    source_kind,
    created_by_user_id,
    created_request_id
  )
  values (
    p_stable_id,
    normalized_display_name,
    normalized_official_name,
    p_birth_date,
    p_sex,
    normalized_breed,
    normalized_discipline,
    normalized_level,
    'manual',
    actor_id,
    p_request_id
  )
  on conflict (created_by_user_id, created_request_id) do nothing
  returning * into result;

  if result.id is null then
    select * into existing_horse
    from public.horses h
    where h.created_by_user_id = actor_id
      and h.created_request_id = p_request_id;
    if existing_horse.stable_id = p_stable_id
      and existing_horse.display_name = normalized_display_name
      and existing_horse.official_name is not distinct from normalized_official_name
      and existing_horse.birth_date is not distinct from p_birth_date
      and existing_horse.sex = p_sex
      and existing_horse.breed is not distinct from normalized_breed
      and existing_horse.discipline is not distinct from normalized_discipline
      and existing_horse.level is not distinct from normalized_level
    then
      return jsonb_build_object(
        'horse_id', existing_horse.id,
        'row_version', existing_horse.row_version,
        'idempotent', true
      );
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;

  insert into public.horse_profile_change_events (
    stable_id,
    horse_id,
    actor_user_id,
    actor_membership_id,
    request_id,
    event_type,
    changed_fields,
    old_values,
    new_values
  )
  values (
    result.stable_id,
    result.id,
    actor_id,
    actor_membership.id,
    p_request_id,
    'horse_created',
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
    private.horse_profile_json(result)
  );

  return jsonb_build_object(
    'horse_id', result.id,
    'row_version', result.row_version,
    'idempotent', false
  );
end;
$$;

create or replace function public.update_horse_profile(
  p_horse_id uuid,
  p_expected_row_version bigint,
  p_request_id uuid,
  p_display_name text,
  p_official_name text,
  p_birth_date date,
  p_sex text,
  p_breed text,
  p_discipline text,
  p_level text
)
returns public.horses
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  actor_membership public.stable_memberships%rowtype;
  actor_grant public.horse_access_grants%rowtype;
  before_row public.horses%rowtype;
  result public.horses%rowtype;
  changed text[] := '{}'::text[];
  normalized_display_name text := btrim(coalesce(p_display_name, ''));
  normalized_official_name text := nullif(btrim(p_official_name), '');
  normalized_breed text := nullif(btrim(p_breed), '');
  normalized_discipline text := nullif(btrim(p_discipline), '');
  normalized_level text := nullif(btrim(p_level), '');
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_expected_row_version is null or p_expected_row_version < 1 then
    raise exception using errcode = '22023', message = 'ROW_VERSION_REQUIRED';
  end if;
  if length(normalized_display_name) not between 1 and 120
    or (
      normalized_official_name is not null
      and length(normalized_official_name) > 200
    )
    or (
      normalized_breed is not null
      and length(normalized_breed) > 120
    )
    or (
      normalized_discipline is not null
      and length(normalized_discipline) > 120
    )
    or (
      normalized_level is not null
      and length(normalized_level) > 120
    )
    or p_sex is null
    or p_sex not in ('mare', 'gelding', 'stallion', 'unknown')
  then
    raise exception using errcode = '22023', message = 'INVALID_HORSE_PROFILE';
  end if;
  if p_birth_date is not null and p_birth_date > current_date then
    raise exception using errcode = '22023', message = 'INVALID_BIRTH_DATE';
  end if;

  select h.stable_id into target_stable_id
  from public.horses h
  where h.id = p_horse_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  select m.* into actor_membership
  from public.stable_memberships m
  join public.stables s on s.id = m.stable_id
  where m.stable_id = target_stable_id
    and m.user_id = actor_id
    and m.status = 'active'
    and s.status = 'active'
  for share of m;
  if actor_membership.id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  if actor_membership.role not in ('owner', 'admin') then
    select * into actor_grant
    from public.horse_access_grants g
    where g.horse_id = p_horse_id
      and g.membership_id = actor_membership.id
      and g.category = 'horse.basic'
      and g.status = 'active'
      and g.can_edit
      and g.valid_from <= timezone('utc', now())
      and (
        g.valid_until is null
        or g.valid_until > timezone('utc', now())
      )
    for share;
    if actor_grant.id is null then
      raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
    end if;
  end if;

  select * into before_row
  from public.horses h
  where h.id = p_horse_id
    and h.stable_id = target_stable_id
  for update;

  if before_row.id is null
    or before_row.status <> 'active'
    or not exists (
      select 1
      from public.stable_memberships m
      join public.stables s on s.id = m.stable_id
      where m.id = actor_membership.id
        and m.stable_id = target_stable_id
        and m.user_id = actor_id
        and m.status = 'active'
        and s.status = 'active'
    )
    or (
      actor_membership.role not in ('owner', 'admin')
      and not exists (
        select 1
        from public.horse_access_grants g
        where g.id = actor_grant.id
          and g.stable_id = target_stable_id
          and g.horse_id = p_horse_id
          and g.membership_id = actor_membership.id
          and g.category = 'horse.basic'
          and g.status = 'active'
          and g.can_edit
          and g.valid_from <= timezone('utc', now())
          and (
            g.valid_until is null
            or g.valid_until > timezone('utc', now())
          )
      )
    )
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  if before_row.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'ROW_VERSION_CONFLICT';
  end if;
  if exists (
    select 1
    from public.horse_profile_change_events e
    where e.actor_user_id = actor_id
      and e.request_id = p_request_id
  ) then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;

  if before_row.display_name is distinct from normalized_display_name then
    changed := array_append(changed, 'display_name');
  end if;
  if before_row.official_name is distinct from normalized_official_name then
    changed := array_append(changed, 'official_name');
  end if;
  if before_row.birth_date is distinct from p_birth_date then
    changed := array_append(changed, 'birth_date');
  end if;
  if before_row.sex is distinct from p_sex then
    changed := array_append(changed, 'sex');
  end if;
  if before_row.breed is distinct from normalized_breed then
    changed := array_append(changed, 'breed');
  end if;
  if before_row.discipline is distinct from normalized_discipline then
    changed := array_append(changed, 'discipline');
  end if;
  if before_row.level is distinct from normalized_level then
    changed := array_append(changed, 'level');
  end if;

  if cardinality(changed) = 0 then
    return before_row;
  end if;

  update public.horses h
  set
    display_name = normalized_display_name,
    official_name = normalized_official_name,
    birth_date = p_birth_date,
    sex = p_sex,
    breed = normalized_breed,
    discipline = normalized_discipline,
    level = normalized_level
  where h.id = p_horse_id
  returning * into result;

  insert into public.horse_profile_change_events (
    stable_id,
    horse_id,
    actor_user_id,
    actor_membership_id,
    request_id,
    event_type,
    changed_fields,
    old_values,
    new_values
  )
  values (
    result.stable_id,
    result.id,
    actor_id,
    actor_membership.id,
    p_request_id,
    'horse_profile_updated',
    changed,
    private.horse_profile_json(before_row),
    private.horse_profile_json(result)
  );

  return result;
end;
$$;

create or replace function public.archive_horse(
  p_horse_id uuid,
  p_request_id uuid,
  p_reason text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  actor_membership public.stable_memberships%rowtype;
  before_row public.horses%rowtype;
  result public.horses%rowtype;
  normalized_reason text := nullif(btrim(p_reason), '');
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if normalized_reason is null or length(normalized_reason) > 500 then
    raise exception using errcode = '22023', message = 'ARCHIVE_REASON_REQUIRED';
  end if;

  select h.stable_id into target_stable_id
  from public.horses h
  where h.id = p_horse_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  select m.* into actor_membership
  from public.stable_memberships m
  join public.stables s on s.id = m.stable_id
  where m.stable_id = target_stable_id
    and m.user_id = actor_id
    and m.status = 'active'
    and m.role in ('owner', 'admin')
    and s.status = 'active'
  for share of m;
  if actor_membership.id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  select * into before_row
  from public.horses h
  where h.id = p_horse_id
    and h.stable_id = target_stable_id
  for update;
  if before_row.id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;
  if before_row.status = 'archived' then
    return false;
  end if;
  if not exists (
    select 1
    from public.stable_memberships m
    join public.stables s on s.id = m.stable_id
    where m.id = actor_membership.id
      and m.stable_id = target_stable_id
      and m.user_id = actor_id
      and m.status = 'active'
      and m.role in ('owner', 'admin')
      and s.status = 'active'
  ) then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  if exists (
    select 1
    from public.horse_profile_change_events e
    where e.actor_user_id = actor_id
      and e.request_id = p_request_id
  ) then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;

  update public.horses h
  set
    status = 'archived',
    archived_at = timezone('utc', now())
  where h.id = p_horse_id
  returning * into result;

  insert into public.horse_profile_change_events (
    stable_id,
    horse_id,
    actor_user_id,
    actor_membership_id,
    request_id,
    event_type,
    changed_fields,
    old_values,
    new_values,
    reason
  )
  values (
    result.stable_id,
    result.id,
    actor_id,
    actor_membership.id,
    p_request_id,
    'horse_archived',
    array['status']::text[],
    private.horse_profile_json(before_row),
    private.horse_profile_json(result),
    normalized_reason
  );

  return true;
end;
$$;

create or replace function public.grant_horse_access(
  p_horse_id uuid,
  p_membership_id uuid,
  p_category text,
  p_can_view boolean,
  p_can_execute boolean,
  p_can_edit boolean,
  p_can_manage boolean,
  p_valid_from timestamptz,
  p_valid_until timestamptz,
  p_grant_reason text,
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
  target_membership public.stable_memberships%rowtype;
  target_horse public.horses%rowtype;
  existing_grant public.horse_access_grants%rowtype;
  request_grant public.horse_access_grants%rowtype;
  result public.horse_access_grants%rowtype;
  effective_valid_from timestamptz :=
    coalesce(p_valid_from, timezone('utc', now()));
  normalized_reason text := nullif(btrim(p_grant_reason), '');
  actor_can_manage boolean := false;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_category is null
    or p_category not in (
    'horse.basic',
    'horse.identity',
    'horse.team',
    'horse.schedule',
    'horse.nutrition',
    'horse.health_summary',
    'horse.health_detail',
    'horse.media',
    'horse.permissions'
  )
    or not coalesce(p_can_view, false)
    or (coalesce(p_can_execute, false) and not coalesce(p_can_view, false))
    or (coalesce(p_can_edit, false) and not coalesce(p_can_view, false))
    or (
      coalesce(p_can_manage, false)
      and (
        not coalesce(p_can_view, false)
        or not coalesce(p_can_edit, false)
      )
    )
    or (
      p_valid_until is not null
      and p_valid_until <= effective_valid_from
    )
    or (
      p_category not in ('horse.basic', 'horse.schedule')
      and normalized_reason is null
    )
    or (normalized_reason is not null and length(normalized_reason) > 500)
  then
    raise exception using errcode = '22023', message = 'INVALID_HORSE_GRANT';
  end if;

  select h.stable_id into target_stable_id
  from public.horses h
  where h.id = p_horse_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  perform private.lock_stable_membership_mutation(target_stable_id);

  select * into target_horse
  from public.horses h
  where h.id = p_horse_id
    and h.stable_id = target_stable_id
  for update;

  perform 1
  from public.horse_access_grants g
  where g.horse_id = p_horse_id
    and g.status = 'active'
  order by g.id
  for update;

  update public.horse_access_grants g
  set status = 'expired'
  where g.horse_id = p_horse_id
    and g.status = 'active'
    and g.valid_until is not null
    and g.valid_until <= timezone('utc', now());

  select * into actor_membership
  from public.stable_memberships m
  where m.stable_id = target_stable_id
    and m.user_id = actor_id
    and m.status = 'active';
  if actor_membership.id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  select * into target_membership
  from public.stable_memberships m
  where m.id = p_membership_id
    and m.stable_id = target_stable_id
    and m.status = 'active';
  if target_membership.id is null then
    raise exception using
      errcode = '42501',
      message = 'TARGET_MEMBERSHIP_UNAVAILABLE';
  end if;
  if target_horse.id is null
    or target_horse.status <> 'active'
    or not exists (
      select 1
      from public.stables s
      where s.id = target_stable_id
        and s.status = 'active'
    )
  then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  actor_can_manage := actor_membership.role = 'owner'
    or (
      actor_membership.role = 'admin'
      and actor_membership.id <> target_membership.id
      and target_membership.role in ('member', 'viewer')
      and (
        p_category in ('horse.basic', 'horse.schedule')
        or exists (
          select 1
          from public.horse_access_grants g
          where g.horse_id = p_horse_id
            and g.membership_id = actor_membership.id
            and g.category = p_category
            and g.status = 'active'
            and g.can_manage
            and g.valid_from <= timezone('utc', now())
            and (
              g.valid_until is null
              or g.valid_until > timezone('utc', now())
            )
        )
      )
    );
  if not actor_can_manage then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  if target_membership.role = 'owner'
    or (
      target_membership.role = 'viewer'
      and (
        coalesce(p_can_execute, false)
        or coalesce(p_can_edit, false)
        or coalesce(p_can_manage, false)
      )
    )
    or (
      target_membership.role = 'member'
      and coalesce(p_can_manage, false)
    )
    or (
      target_membership.role = 'admin'
      and actor_membership.role <> 'owner'
    )
  then
    raise exception using errcode = '42501', message = 'GRANT_NOT_ALLOWED';
  end if;

  select * into request_grant
  from public.horse_access_grants g
  where g.granted_by_user_id = actor_id
    and g.granted_request_id = p_request_id;
  if request_grant.id is not null then
    if request_grant.horse_id = p_horse_id
      and request_grant.membership_id = p_membership_id
      and request_grant.category = p_category
      and request_grant.can_view = coalesce(p_can_view, false)
      and request_grant.can_execute = coalesce(p_can_execute, false)
      and request_grant.can_edit = coalesce(p_can_edit, false)
      and request_grant.can_manage = coalesce(p_can_manage, false)
      and (
        p_valid_from is null
        or request_grant.valid_from = p_valid_from
      )
      and request_grant.valid_until is not distinct from p_valid_until
      and request_grant.grant_reason is not distinct from normalized_reason
    then
      return jsonb_build_object(
        'grant_id', request_grant.id,
        'row_version', request_grant.row_version,
        'idempotent', true
      );
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;

  select * into existing_grant
  from public.horse_access_grants g
  where g.horse_id = p_horse_id
    and g.membership_id = p_membership_id
    and g.category = p_category
    and g.status = 'active';
  if existing_grant.id is not null then
    if existing_grant.can_view = coalesce(p_can_view, false)
      and existing_grant.can_execute = coalesce(p_can_execute, false)
      and existing_grant.can_edit = coalesce(p_can_edit, false)
      and existing_grant.can_manage = coalesce(p_can_manage, false)
      and (
        p_valid_from is null
        or existing_grant.valid_from = p_valid_from
      )
      and existing_grant.valid_until is not distinct from p_valid_until
      and existing_grant.grant_reason is not distinct from normalized_reason
    then
      return jsonb_build_object(
        'grant_id', existing_grant.id,
        'row_version', existing_grant.row_version,
        'idempotent', true
      );
    end if;
    raise exception using
      errcode = '23505',
      message = 'HORSE_ACCESS_ALREADY_ACTIVE';
  end if;

  insert into public.horse_access_grants (
    stable_id,
    horse_id,
    membership_id,
    category,
    can_view,
    can_execute,
    can_edit,
    can_manage,
    valid_from,
    valid_until,
    granted_by_user_id,
    granted_request_id,
    grant_reason
  )
  values (
    target_stable_id,
    p_horse_id,
    p_membership_id,
    p_category,
    coalesce(p_can_view, false),
    coalesce(p_can_execute, false),
    coalesce(p_can_edit, false),
    coalesce(p_can_manage, false),
    effective_valid_from,
    p_valid_until,
    actor_id,
    p_request_id,
    normalized_reason
  )
  returning * into result;

  perform private.write_horse_security_event(
    target_stable_id,
    p_horse_id,
    'horse_access_granted',
    actor_membership.id,
    target_membership.id,
    p_request_id,
    jsonb_build_object(
      'category', p_category,
      'can_view', result.can_view,
      'can_execute', result.can_execute,
      'can_edit', result.can_edit,
      'can_manage', result.can_manage
    )
  );

  return jsonb_build_object(
    'grant_id', result.id,
    'row_version', result.row_version,
    'idempotent', false
  );
end;
$$;

create or replace function public.revoke_horse_access(
  p_horse_id uuid,
  p_membership_id uuid,
  p_category text,
  p_request_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  actor_membership public.stable_memberships%rowtype;
  target_membership public.stable_memberships%rowtype;
  target_horse public.horses%rowtype;
  target_grant public.horse_access_grants%rowtype;
  request_grant public.horse_access_grants%rowtype;
  actor_can_manage boolean := false;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_category is null
    or p_category not in (
    'horse.basic',
    'horse.identity',
    'horse.team',
    'horse.schedule',
    'horse.nutrition',
    'horse.health_summary',
    'horse.health_detail',
    'horse.media',
    'horse.permissions'
  ) then
    raise exception using errcode = '22023', message = 'INVALID_HORSE_CATEGORY';
  end if;

  select h.stable_id into target_stable_id
  from public.horses h
  where h.id = p_horse_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  perform private.lock_stable_membership_mutation(target_stable_id);

  select * into target_horse
  from public.horses h
  where h.id = p_horse_id
    and h.stable_id = target_stable_id
  for update;

  perform 1
  from public.horse_access_grants g
  where g.horse_id = p_horse_id
    and g.status = 'active'
  order by g.id
  for update;

  update public.horse_access_grants g
  set status = 'expired'
  where g.horse_id = p_horse_id
    and g.status = 'active'
    and g.valid_until is not null
    and g.valid_until <= timezone('utc', now());

  select * into actor_membership
  from public.stable_memberships m
  where m.stable_id = target_stable_id
    and m.user_id = actor_id
    and m.status = 'active';
  if actor_membership.id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  select * into target_membership
  from public.stable_memberships m
  where m.id = p_membership_id
    and m.stable_id = target_stable_id;
  if target_membership.id is null then
    raise exception using
      errcode = '42501',
      message = 'TARGET_MEMBERSHIP_UNAVAILABLE';
  end if;
  if target_horse.id is null
    or target_horse.status <> 'active'
    or not exists (
      select 1
      from public.stables s
      where s.id = target_stable_id
        and s.status = 'active'
    )
  then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  actor_can_manage := actor_membership.role = 'owner'
    or (
      actor_membership.role = 'admin'
      and actor_membership.id <> target_membership.id
      and target_membership.role in ('member', 'viewer')
      and (
        p_category in ('horse.basic', 'horse.schedule')
        or exists (
          select 1
          from public.horse_access_grants g
          where g.horse_id = p_horse_id
            and g.membership_id = actor_membership.id
            and g.category = p_category
            and g.status = 'active'
            and g.can_manage
            and g.valid_from <= timezone('utc', now())
            and (
              g.valid_until is null
              or g.valid_until > timezone('utc', now())
            )
        )
      )
    );
  if not actor_can_manage then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  select * into request_grant
  from public.horse_access_grants g
  where g.revoked_by_user_id = actor_id
    and g.revoked_request_id = p_request_id;
  if request_grant.id is not null then
    if request_grant.horse_id = p_horse_id
      and request_grant.membership_id = p_membership_id
      and request_grant.category = p_category
    then
      return true;
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;

  select * into target_grant
  from public.horse_access_grants g
  where g.horse_id = p_horse_id
    and g.membership_id = p_membership_id
    and g.category = p_category
    and g.status = 'active';
  if target_grant.id is null then
    return false;
  end if;

  update public.horse_access_grants g
  set
    status = 'revoked',
    revoked_by_user_id = actor_id,
    revoked_request_id = p_request_id,
    revoked_at = timezone('utc', now())
  where g.id = target_grant.id;

  perform private.write_horse_security_event(
    target_stable_id,
    p_horse_id,
    'horse_access_revoked',
    actor_membership.id,
    target_membership.id,
    p_request_id,
    jsonb_build_object('category', p_category)
  );

  return true;
end;
$$;

alter table public.horses enable row level security;
alter table public.horse_access_grants enable row level security;
alter table public.horse_profile_change_events enable row level security;

revoke all on table public.horses from public, anon, authenticated;
revoke all on table public.horse_access_grants
  from public, anon, authenticated;
revoke all on table public.horse_profile_change_events
  from public, anon, authenticated;

grant select on table public.horses to authenticated;
grant select on table public.horse_access_grants to authenticated;
grant select on table public.horse_profile_change_events to authenticated;

create policy horses_select_authorized
on public.horses for select to authenticated
using (private.has_horse_capability(id, 'horse.basic', 'view'));

create policy horse_access_grants_select_authorized_managers
on public.horse_access_grants for select to authenticated
using (private.can_manage_horse_grants(horse_id, category));

create policy horse_profile_change_events_select_authorized
on public.horse_profile_change_events for select to authenticated
using (private.has_horse_capability(horse_id, 'horse.basic', 'view'));

revoke all on function private.touch_horse()
  from public, anon, authenticated;
revoke all on function private.touch_horse_access_grant()
  from public, anon, authenticated;
revoke all on function private.has_horse_capability(uuid, text, text)
  from public, anon, authenticated;
revoke all on function private.can_manage_horse_grants(uuid, text)
  from public, anon, authenticated;
revoke all on function private.write_horse_security_event(
  uuid, uuid, text, uuid, uuid, uuid, jsonb
) from public, anon, authenticated;
revoke all on function private.horse_profile_json(public.horses)
  from public, anon, authenticated;

grant execute on function private.has_horse_capability(uuid, text, text)
  to authenticated;
grant execute on function private.can_manage_horse_grants(uuid, text)
  to authenticated;

revoke execute on function public.create_horse(
  uuid, text, uuid, text, date, text, text, text, text
) from public, anon;
revoke execute on function public.update_horse_profile(
  uuid, bigint, uuid, text, text, date, text, text, text, text
) from public, anon;
revoke execute on function public.archive_horse(uuid, uuid, text)
  from public, anon;
revoke execute on function public.grant_horse_access(
  uuid, uuid, text, boolean, boolean, boolean, boolean,
  timestamptz, timestamptz, text, uuid
) from public, anon;
revoke execute on function public.revoke_horse_access(
  uuid, uuid, text, uuid
) from public, anon;

grant execute on function public.create_horse(
  uuid, text, uuid, text, date, text, text, text, text
) to authenticated;
grant execute on function public.update_horse_profile(
  uuid, bigint, uuid, text, text, date, text, text, text, text
) to authenticated;
grant execute on function public.archive_horse(uuid, uuid, text)
  to authenticated;
grant execute on function public.grant_horse_access(
  uuid, uuid, text, boolean, boolean, boolean, boolean,
  timestamptz, timestamptz, text, uuid
) to authenticated;
grant execute on function public.revoke_horse_access(
  uuid, uuid, text, uuid
) to authenticated;

comment on table public.horses is
  'Phase 4C.2A authoritative Horse core. Client writes are RPC-only.';
comment on column public.horses.profile_media_asset_id is
  'Reserved typed media reference; no media FK exists before phase 4C.5.';
comment on column public.horses.legacy_local_horse_id is
  'Optional exact legacy migration reference. It is not an authorization identity.';
comment on table public.horse_access_grants is
  'Explicit per-Horse, per-membership capability grants. Revocation preserves rows.';
comment on column public.horse_access_grants.grant_reason is
  'Bounded reason for sensitive categories; never copied into security-event metadata.';
comment on table public.horse_profile_change_events is
  'Append-only server-authored audit for Horse Basic profile mutations.';
comment on constraint stable_security_events_horse_fk
  on public.stable_security_events is
  'Typed same-stable Horse correlation required by phase 4C.2A.';
comment on function private.has_horse_capability(uuid, text, text) is
  'Boolean RLS helper. Authority comes only from active same-stable membership and unexpired grants.';
comment on function private.can_manage_horse_grants(uuid, text) is
  'Boolean RLS helper for the contract-bounded owner/admin grant-management matrix.';
comment on function private.write_horse_security_event(
  uuid, uuid, text, uuid, uuid, uuid, jsonb
) is
  'Private least-privileged writer for only Horse grant/revoke events.';
comment on function public.create_horse(
  uuid, text, uuid, text, date, text, text, text, text
) is
  'Creates a manual Horse for an active owner/admin; actor and authority are server-derived.';
comment on function public.update_horse_profile(
  uuid, bigint, uuid, text, text, date, text, text, text, text
) is
  'Optimistic, audited Horse Basic profile update with lock-time authority revalidation.';
comment on function public.archive_horse(uuid, uuid, text) is
  'Soft-archives a Horse for an active owner/admin and writes bounded profile audit.';
comment on function public.grant_horse_access(
  uuid, uuid, text, boolean, boolean, boolean, boolean,
  timestamptz, timestamptz, text, uuid
) is
  'Stable-serialized same-tenant Horse grant with atomic typed security event.';
comment on function public.revoke_horse_access(
  uuid, uuid, text, uuid
) is
  'Stable-serialized Horse grant revocation with atomic typed security event.';

commit;
