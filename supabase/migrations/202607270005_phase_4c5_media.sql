begin;

alter table public.schedule_executions
  add constraint schedule_executions_stable_and_id_unique
  unique (stable_id, id);

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'horse-media',
  'horse-media',
  false,
  20971520,
  array[
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf'
  ]
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create table public.media_assets (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  horse_id uuid not null,
  status text not null default 'pending'
    check (
      status in ('pending', 'ready', 'quarantined', 'archived', 'purged')
    ),
  bucket_id text not null default 'horse-media'
    check (bucket_id = 'horse-media'),
  original_filename text not null
    check (length(btrim(original_filename)) between 1 and 240),
  expected_mime_type text not null
    check (
      expected_mime_type in (
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/pdf'
      )
    ),
  max_byte_size bigint not null
    check (max_byte_size in (10485760, 20971520)),
  mime_type text,
  byte_size bigint check (byte_size is null or byte_size > 0),
  sha256 bytea check (sha256 is null or octet_length(sha256) = 32),
  row_version bigint not null default 1 check (row_version > 0),
  uploaded_by_user_id uuid not null references auth.users (id),
  created_request_id uuid not null,
  last_mutated_by_user_id uuid not null references auth.users (id),
  last_mutation_request_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  ready_at timestamptz,
  quarantined_at timestamptz,
  archived_at timestamptz,
  purged_at timestamptz,
  constraint media_assets_stable_and_id_unique unique (stable_id, id),
  constraint media_assets_scope_unique unique (stable_id, horse_id, id),
  constraint media_assets_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint media_assets_created_request_unique
    unique (uploaded_by_user_id, created_request_id),
  constraint media_assets_expected_size_shape
    check (
      (
        expected_mime_type = 'application/pdf'
        and max_byte_size = 20971520
      )
      or (
        expected_mime_type in ('image/jpeg', 'image/png', 'image/webp')
        and max_byte_size = 10485760
      )
    ),
  constraint media_assets_final_metadata_shape
    check (
      (
        status = 'pending'
        and mime_type is null
        and byte_size is null
        and sha256 is null
        and ready_at is null
        and quarantined_at is null
        and archived_at is null
        and purged_at is null
      )
      or (
        status = 'ready'
        and mime_type is not null
        and byte_size is not null
        and sha256 is not null
        and ready_at is not null
        and quarantined_at is null
        and archived_at is null
        and purged_at is null
      )
      or (
        status = 'quarantined'
        and quarantined_at is not null
        and archived_at is null
        and purged_at is null
      )
      or (
        status = 'archived'
        and archived_at is not null
        and purged_at is null
      )
      or (
        status = 'purged'
        and purged_at is not null
      )
    )
);

alter table public.horses
  add constraint horses_profile_media_asset_fk
  foreign key (stable_id, id, profile_media_asset_id)
  references public.media_assets (stable_id, horse_id, id);

create index media_assets_horse_status_created
  on public.media_assets (horse_id, status, created_at desc, id);

create table public.media_asset_variants (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  media_asset_id uuid not null,
  variant text not null check (variant in ('original', 'thumbnail')),
  status text not null default 'pending'
    check (status in ('pending', 'ready', 'quarantined', 'archived', 'purged')),
  bucket_id text not null default 'horse-media'
    check (bucket_id = 'horse-media'),
  object_path text not null
    check (length(object_path) between 1 and 500),
  expected_mime_type text not null,
  max_byte_size bigint not null check (max_byte_size > 0),
  mime_type text,
  byte_size bigint check (byte_size is null or byte_size > 0),
  sha256 bytea check (sha256 is null or octet_length(sha256) = 32),
  created_at timestamptz not null default timezone('utc', now()),
  ready_at timestamptz,
  constraint media_asset_variants_stable_and_id_unique
    unique (stable_id, id),
  constraint media_asset_variants_asset_fk
    foreign key (stable_id, media_asset_id)
    references public.media_assets (stable_id, id),
  constraint media_asset_variants_asset_variant_unique
    unique (media_asset_id, variant),
  constraint media_asset_variants_path_unique
    unique (bucket_id, object_path),
  constraint media_asset_variants_expected_shape
    check (
      (
        variant = 'thumbnail'
        and expected_mime_type in ('image/jpeg', 'image/png', 'image/webp')
        and max_byte_size = 1048576
      )
      or (
        variant = 'original'
        and (
          (
            expected_mime_type = 'application/pdf'
            and max_byte_size = 20971520
          )
          or (
            expected_mime_type in ('image/jpeg', 'image/png', 'image/webp')
            and max_byte_size = 10485760
          )
        )
      )
    ),
  constraint media_asset_variants_metadata_shape
    check (
      (
        status = 'pending'
        and mime_type is null
        and byte_size is null
        and sha256 is null
        and ready_at is null
      )
      or (
        status = 'ready'
        and mime_type is not null
        and byte_size is not null
        and sha256 is not null
        and ready_at is not null
      )
      or status in ('quarantined', 'archived', 'purged')
    )
);

create index media_asset_variants_asset_status
  on public.media_asset_variants (media_asset_id, status, variant);

create table public.media_links (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  media_asset_id uuid not null,
  horse_id uuid,
  schedule_execution_id uuid,
  link_kind text not null check (link_kind in ('horse', 'schedule_execution')),
  created_by_user_id uuid not null references auth.users (id),
  created_request_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  constraint media_links_stable_and_id_unique unique (stable_id, id),
  constraint media_links_asset_fk
    foreign key (stable_id, media_asset_id)
    references public.media_assets (stable_id, id),
  constraint media_links_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint media_links_execution_fk
    foreign key (stable_id, schedule_execution_id)
    references public.schedule_executions (stable_id, id),
  constraint media_links_exact_target
    check (
      (
        link_kind = 'horse'
        and horse_id is not null
        and schedule_execution_id is null
      )
      or (
        link_kind = 'schedule_execution'
        and horse_id is null
        and schedule_execution_id is not null
      )
    ),
  constraint media_links_target_unique
    unique nulls not distinct (
      media_asset_id,
      link_kind,
      horse_id,
      schedule_execution_id
    ),
  constraint media_links_created_request_unique
    unique (created_by_user_id, created_request_id)
);

create index media_links_horse_active
  on public.media_links (horse_id, media_asset_id, id)
  where archived_at is null and horse_id is not null;

create index media_links_execution_active
  on public.media_links (schedule_execution_id, media_asset_id, id)
  where archived_at is null and schedule_execution_id is not null;

create table public.media_change_events (
  id bigint generated always as identity primary key,
  stable_id uuid not null references public.stables (id),
  horse_id uuid not null,
  media_asset_id uuid not null,
  media_link_id uuid,
  actor_user_id uuid not null references auth.users (id),
  actor_membership_id uuid not null,
  request_id uuid not null,
  event_type text not null
    check (
      event_type in (
        'media_upload_session_created',
        'media_asset_finalized',
        'media_asset_linked',
        'media_asset_archived'
      )
    ),
  row_version bigint not null check (row_version > 0),
  created_at timestamptz not null default timezone('utc', now()),
  constraint media_change_events_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint media_change_events_asset_fk
    foreign key (stable_id, media_asset_id)
    references public.media_assets (stable_id, id),
  constraint media_change_events_link_fk
    foreign key (stable_id, media_link_id)
    references public.media_links (stable_id, id),
  constraint media_change_events_membership_fk
    foreign key (stable_id, actor_membership_id)
    references public.stable_memberships (stable_id, id),
  constraint media_change_events_actor_request_unique
    unique (actor_user_id, request_id)
);

create index media_change_events_stable_created
  on public.media_change_events (stable_id, created_at, id);

create table private.media_mutation_receipts (
  actor_user_id uuid not null references auth.users (id),
  request_id uuid not null,
  stable_id uuid not null references public.stables (id),
  operation_name text not null
    check (
      operation_name in (
        'create_media_upload_session',
        'finalize_media_asset',
        'link_media_asset',
        'archive_media_asset'
      )
    ),
  target_type text not null check (target_type in ('media_asset', 'media_link')),
  target_id uuid,
  payload_hash bytea not null check (octet_length(payload_hash) = 32),
  result jsonb not null check (jsonb_typeof(result) = 'object'),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (actor_user_id, request_id)
);

create or replace function private.touch_media_asset()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.original_filename := btrim(new.original_filename);
  new.updated_at := timezone('utc', pg_catalog.now());
  if tg_op = 'UPDATE' then
    new.row_version := old.row_version + 1;
  end if;
  return new;
end;
$$;

create trigger media_assets_touch_before_write
before insert or update on public.media_assets
for each row execute function private.touch_media_asset();

create or replace function private.prevent_media_append_only_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using errcode = '55000', message = 'MEDIA_HISTORY_APPEND_ONLY';
end;
$$;

create trigger media_change_events_append_only
before update or delete on public.media_change_events
for each row execute function private.prevent_media_append_only_mutation();

create or replace function private.guard_media_link_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  asset_horse_id uuid;
  execution_horse_id uuid;
begin
  select asset.horse_id into asset_horse_id
  from public.media_assets asset
  where asset.id = new.media_asset_id
    and asset.stable_id = new.stable_id;
  if asset_horse_id is null then
    raise exception using errcode = '23503', message = 'MEDIA_ASSET_SCOPE_INVALID';
  end if;
  if new.link_kind = 'horse' then
    if new.horse_id <> asset_horse_id then
      raise exception using errcode = '23514', message = 'MEDIA_HORSE_SCOPE_MISMATCH';
    end if;
  else
    select schedule_item.horse_id into execution_horse_id
    from public.schedule_executions execution
    join public.schedule_items schedule_item
      on schedule_item.id = execution.schedule_item_id
     and schedule_item.stable_id = execution.stable_id
    where execution.id = new.schedule_execution_id
      and execution.stable_id = new.stable_id;
    if execution_horse_id is null or execution_horse_id <> asset_horse_id then
      raise exception using
        errcode = '23514',
        message = 'MEDIA_EXECUTION_SCOPE_MISMATCH';
    end if;
  end if;
  return new;
end;
$$;

create trigger media_links_scope_before_write
before insert or update on public.media_links
for each row execute function private.guard_media_link_scope();

create or replace function private.media_receipt_result(
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
  existing_receipt private.media_mutation_receipts%rowtype;
begin
  select * into existing_receipt
  from private.media_mutation_receipts receipt
  where receipt.actor_user_id = p_actor_user_id
    and receipt.request_id = p_request_id;
  if existing_receipt.request_id is null then return null; end if;
  if existing_receipt.operation_name <> p_operation_name
    or existing_receipt.payload_hash <> p_payload_hash
  then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  return existing_receipt.result || jsonb_build_object('idempotent', true);
end;
$$;

create or replace function private.lock_media_request(
  p_actor_user_id uuid,
  p_request_id uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  select pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_actor_user_id::text || ':' || p_request_id::text,
      405
    )
  )
$$;

create or replace function private.lock_media_context(
  p_stable_id uuid,
  p_horse_id uuid
)
returns public.stable_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_membership public.stable_memberships%rowtype;
begin
  select * into actor_membership
  from public.stable_memberships membership
  where membership.stable_id = p_stable_id
    and membership.user_id = auth.uid()
    and membership.status = 'active'
  for share;
  perform 1
  from public.horse_access_grants grant_row
  where grant_row.horse_id = p_horse_id
    and grant_row.membership_id = actor_membership.id
    and grant_row.status = 'active'
  order by grant_row.id
  for share;
  perform 1
  from public.horses horse
  where horse.id = p_horse_id
    and horse.stable_id = p_stable_id
    and horse.status = 'active'
  for share;
  if actor_membership.id is null
    or not exists (
      select 1 from public.stables stable
      where stable.id = p_stable_id and stable.status = 'active'
    )
    or not exists (
      select 1 from public.horses horse
      where horse.id = p_horse_id
        and horse.stable_id = p_stable_id
        and horse.status = 'active'
    )
  then
    raise exception using errcode = '42501', message = 'MEDIA_UNAVAILABLE';
  end if;
  return actor_membership;
end;
$$;

create or replace function private.write_media_change_event(
  p_stable_id uuid,
  p_horse_id uuid,
  p_media_asset_id uuid,
  p_media_link_id uuid,
  p_actor_user_id uuid,
  p_actor_membership_id uuid,
  p_request_id uuid,
  p_event_type text,
  p_row_version bigint
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.media_change_events (
    stable_id,
    horse_id,
    media_asset_id,
    media_link_id,
    actor_user_id,
    actor_membership_id,
    request_id,
    event_type,
    row_version
  )
  values (
    p_stable_id,
    p_horse_id,
    p_media_asset_id,
    p_media_link_id,
    p_actor_user_id,
    p_actor_membership_id,
    p_request_id,
    p_event_type,
    p_row_version
  )
$$;

create or replace function private.media_actor_membership(
  p_actor_user_id uuid,
  p_stable_id uuid
)
returns public.stable_memberships
language sql
stable
security definer
set search_path = ''
as $$
  select membership
  from public.stable_memberships membership
  join public.stables stable on stable.id = membership.stable_id
  where membership.user_id = p_actor_user_id
    and membership.stable_id = p_stable_id
    and membership.status = 'active'
    and stable.status = 'active'
  limit 1
$$;

create or replace function private.media_actor_has_capability(
  p_actor_user_id uuid,
  p_horse_id uuid,
  p_capability text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with target as (
    select horse.stable_id
    from public.horses horse
    join public.stables stable on stable.id = horse.stable_id
    where horse.id = p_horse_id
      and horse.status = 'active'
      and stable.status = 'active'
  ),
  actor as (
    select membership.id, membership.role
    from target
    join public.stable_memberships membership
      on membership.stable_id = target.stable_id
    where membership.user_id = p_actor_user_id
      and membership.status = 'active'
  )
  select exists (
    select 1
    from actor
    where actor.role = 'owner'
      or exists (
        select 1
        from public.horse_access_grants grant_row
        where grant_row.horse_id = p_horse_id
          and grant_row.membership_id = actor.id
          and grant_row.category = 'horse.media'
          and grant_row.status = 'active'
          and grant_row.valid_from <= timezone('utc', pg_catalog.now())
          and (
            grant_row.valid_until is null
            or grant_row.valid_until > timezone('utc', pg_catalog.now())
          )
          and case p_capability
            when 'view' then grant_row.can_view
            when 'edit' then grant_row.can_edit
            when 'manage' then grant_row.can_manage
            else false
          end
      )
  )
$$;

create or replace function private.media_actor_schedule_access_level(
  p_actor_user_id uuid,
  p_schedule_item_id uuid
)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target_item public.schedule_items%rowtype;
  actor_membership public.stable_memberships%rowtype;
begin
  select * into target_item
  from public.schedule_items item
  where item.id = p_schedule_item_id;
  if target_item.id is null then return 'none'; end if;

  actor_membership := private.media_actor_membership(
    p_actor_user_id,
    target_item.stable_id
  );
  if actor_membership.id is null then return 'none'; end if;
  if target_item.horse_id is not null
    and not exists (
      select 1
      from public.horses horse
      where horse.id = target_item.horse_id
        and horse.stable_id = target_item.stable_id
        and horse.status = 'active'
    )
  then
    return 'none';
  end if;

  if actor_membership.role in ('owner', 'admin')
    or (
      target_item.horse_id is not null
      and exists (
        select 1
        from public.horse_access_grants grant_row
        where grant_row.horse_id = target_item.horse_id
          and grant_row.membership_id = actor_membership.id
          and grant_row.category = target_item.data_category
          and grant_row.status = 'active'
          and grant_row.can_view
          and grant_row.valid_from <= timezone('utc', pg_catalog.now())
          and (
            grant_row.valid_until is null
            or grant_row.valid_until > timezone('utc', pg_catalog.now())
          )
      )
    )
  then
    return 'full';
  end if;

  if actor_membership.stable_member_id is not null
    and exists (
      select 1
      from public.schedule_assignments assignment
      where assignment.schedule_item_id = target_item.id
        and assignment.stable_id = target_item.stable_id
        and assignment.stable_member_id = actor_membership.stable_member_id
        and assignment.status in ('assigned', 'accepted', 'completed')
    )
  then
    return 'assigned';
  end if;
  return 'none';
end;
$$;

create or replace function private.media_actor_can_upload_to_target(
  p_actor_user_id uuid,
  p_horse_id uuid,
  p_schedule_execution_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.horses horse
    join public.stables stable on stable.id = horse.stable_id
    join public.stable_memberships membership
      on membership.stable_id = horse.stable_id
     and membership.user_id = p_actor_user_id
     and membership.status = 'active'
    where horse.id = p_horse_id
      and horse.status = 'active'
      and stable.status = 'active'
      and (
        (
          p_schedule_execution_id is null
          and private.media_actor_has_capability(
            p_actor_user_id,
            horse.id,
            'edit'
          )
        )
        or (
          p_schedule_execution_id is not null
          and exists (
            select 1
            from public.schedule_executions execution
            join public.schedule_items item
              on item.id = execution.schedule_item_id
             and item.stable_id = execution.stable_id
            where execution.id = p_schedule_execution_id
              and execution.stable_id = horse.stable_id
              and item.horse_id = horse.id
              and (
                execution.actor_user_id = p_actor_user_id
                or private.media_actor_has_capability(
                  p_actor_user_id,
                  horse.id,
                  'edit'
                )
              )
          )
        )
      )
  )
$$;

create or replace function private.media_actor_can_continue_asset_upload(
  p_actor_user_id uuid,
  p_media_asset_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.media_assets asset
    join public.media_links link
      on link.media_asset_id = asset.id
     and link.stable_id = asset.stable_id
     and link.archived_at is null
    where asset.id = p_media_asset_id
      and asset.uploaded_by_user_id = p_actor_user_id
      and private.media_actor_can_upload_to_target(
        p_actor_user_id,
        asset.horse_id,
        link.schedule_execution_id
      )
  )
$$;

create or replace function private.media_actor_can_view_link(
  p_actor_user_id uuid,
  p_media_link_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.media_links link
    join public.media_assets asset
      on asset.id = link.media_asset_id
     and asset.stable_id = link.stable_id
    join public.horses horse
      on horse.id = asset.horse_id
     and horse.stable_id = asset.stable_id
    join public.stables stable on stable.id = asset.stable_id
    where link.id = p_media_link_id
      and link.archived_at is null
      and asset.status = 'ready'
      and horse.status = 'active'
      and stable.status = 'active'
      and (
        private.media_actor_membership(
          p_actor_user_id,
          asset.stable_id
        )
      ).id is not null
      and (
        (
          link.link_kind = 'horse'
          and private.media_actor_has_capability(
            p_actor_user_id,
            asset.horse_id,
            'view'
          )
        )
        or (
          link.link_kind = 'schedule_execution'
          and exists (
            select 1
            from public.schedule_executions execution
            where execution.id = link.schedule_execution_id
              and execution.stable_id = link.stable_id
              and (
                execution.actor_user_id = p_actor_user_id
                or private.media_actor_schedule_access_level(
                  p_actor_user_id,
                  execution.schedule_item_id
                ) in ('full', 'assigned')
              )
          )
        )
      )
  )
$$;

create or replace function private.media_actor_can_view_asset(
  p_actor_user_id uuid,
  p_media_asset_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.media_links link
    where link.media_asset_id = p_media_asset_id
      and private.media_actor_can_view_link(p_actor_user_id, link.id)
  )
$$;

create or replace function private.can_view_media_asset(
  p_media_asset_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and private.media_actor_can_view_asset(auth.uid(), p_media_asset_id)
$$;

create or replace function private.can_view_media_link(
  p_media_link_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and private.media_actor_can_view_link(auth.uid(), p_media_link_id)
$$;

create or replace function private.can_view_media_audit(
  p_media_asset_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.media_assets asset
    join public.horses horse
      on horse.id = asset.horse_id
     and horse.stable_id = asset.stable_id
    join public.stables stable on stable.id = asset.stable_id
    where asset.id = p_media_asset_id
      and asset.status = 'ready'
      and horse.status = 'active'
      and stable.status = 'active'
      and private.media_actor_has_capability(
        auth.uid(),
        asset.horse_id,
        'view'
      )
  )
$$;

create or replace function private.lock_media_actor_context(
  p_actor_user_id uuid,
  p_stable_id uuid,
  p_horse_id uuid
)
returns public.stable_memberships
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_membership public.stable_memberships%rowtype;
  target_horse public.horses%rowtype;
begin
  if p_actor_user_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  select * into actor_membership
  from public.stable_memberships membership
  where membership.stable_id = p_stable_id
    and membership.user_id = p_actor_user_id
    and membership.status = 'active'
  for share;
  if actor_membership.id is null then
    raise exception using errcode = '42501', message = 'MEDIA_UNAVAILABLE';
  end if;
  perform 1
  from public.horse_access_grants grant_row
  where grant_row.horse_id = p_horse_id
    and grant_row.membership_id = actor_membership.id
    and grant_row.status = 'active'
  order by grant_row.id
  for share;
  select * into target_horse
  from public.horses horse
  where horse.id = p_horse_id
    and horse.stable_id = p_stable_id
  for share;
  if not exists (
    select 1
    from public.stables stable
    where stable.id = p_stable_id and stable.status = 'active'
  ) or target_horse.id is null or target_horse.status <> 'active'
  then
    raise exception using errcode = '42501', message = 'MEDIA_UNAVAILABLE';
  end if;
  return actor_membership;
end;
$$;

create or replace function private.lock_media_context(
  p_stable_id uuid,
  p_horse_id uuid
)
returns public.stable_memberships
language sql
security definer
set search_path = ''
as $$
  select private.lock_media_actor_context(auth.uid(), p_stable_id, p_horse_id)
$$;

create or replace function private.media_upload_session_result(
  p_media_asset_id uuid,
  p_idempotent boolean
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'media_asset_id', asset.id,
    'row_version', asset.row_version,
    'status', case
      when asset.status = 'pending'
        and bool_and(variant.status = 'pending')
      then 'pending'
      else 'closed'
    end,
    'bucket_id', asset.bucket_id,
    'idempotent', p_idempotent,
    'variants', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'variant', variant.variant,
          'object_path', variant.object_path,
          'expected_mime_type', variant.expected_mime_type,
          'max_byte_size', variant.max_byte_size
        )
        order by variant.variant
      ) filter (where asset.status = 'pending' and variant.status = 'pending'),
      '[]'::jsonb
    )
  )
  from public.media_assets asset
  join public.media_asset_variants variant
    on variant.media_asset_id = asset.id
   and variant.stable_id = asset.stable_id
  where asset.id = p_media_asset_id
  group by asset.id
$$;

create or replace function public.create_media_upload_session(
  p_horse_id uuid,
  p_schedule_execution_id uuid,
  p_original_filename text,
  p_mime_type text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_horse public.horses%rowtype;
  actor_membership public.stable_memberships%rowtype;
  replay_asset public.media_assets%rowtype;
  existing_receipt jsonb;
  asset_id uuid := gen_random_uuid();
  link_id uuid := gen_random_uuid();
  safe_filename text;
  payload_hash bytea;
  max_size bigint;
  result jsonb;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_request_id is null
    or p_horse_id is null
    or p_mime_type not in (
      'image/jpeg', 'image/png', 'image/webp', 'application/pdf'
    )
  then
    raise exception using errcode = '22023', message = 'MEDIA_INPUT_INVALID';
  end if;
  safe_filename := btrim(
    regexp_replace(
      regexp_replace(coalesce(p_original_filename, ''), '^.*[\\/]', ''),
      '[^[:alnum:] ._()\\-]',
      '_',
      'g'
    )
  );
  if length(safe_filename) not between 1 and 240 then
    raise exception using errcode = '22023', message = 'MEDIA_FILENAME_INVALID';
  end if;
  payload_hash := extensions.digest(
    jsonb_build_object(
      'horse_id', p_horse_id,
      'schedule_execution_id', p_schedule_execution_id,
      'original_filename', safe_filename,
      'mime_type', p_mime_type
    )::text,
    'sha256'
  );
  perform private.lock_media_request(actor_id, p_request_id);
  existing_receipt := private.media_receipt_result(
    actor_id,
    p_request_id,
    'create_media_upload_session',
    payload_hash
  );
  if existing_receipt is not null then
    select * into replay_asset
    from public.media_assets asset
    where asset.id = (existing_receipt->>'media_asset_id')::uuid;
    if replay_asset.id is null then
      raise exception using errcode = '42501', message = 'MEDIA_UNAVAILABLE';
    end if;
    actor_membership := private.lock_media_context(
      replay_asset.stable_id,
      replay_asset.horse_id
    );
    if not private.media_actor_can_upload_to_target(
      actor_id,
      replay_asset.horse_id,
      p_schedule_execution_id
    ) then
      raise exception using errcode = '42501', message = 'MEDIA_EDIT_REQUIRED';
    end if;
    return private.media_upload_session_result(
      replay_asset.id,
      true
    );
  end if;

  select * into target_horse
  from public.horses horse
  where horse.id = p_horse_id;
  if target_horse.id is null then
    raise exception using errcode = '42501', message = 'MEDIA_UNAVAILABLE';
  end if;
  actor_membership := private.lock_media_context(
    target_horse.stable_id,
    target_horse.id
  );
  if not private.media_actor_can_upload_to_target(
    actor_id,
    target_horse.id,
    p_schedule_execution_id
  ) then
    raise exception using
      errcode = '42501',
      message = case
        when p_schedule_execution_id is null then 'MEDIA_EDIT_REQUIRED'
        else 'MEDIA_EXECUTION_UPLOAD_FORBIDDEN'
      end;
  end if;

  max_size := case
    when p_mime_type = 'application/pdf' then 20971520
    else 10485760
  end;
  insert into public.media_assets (
    id,
    stable_id,
    horse_id,
    original_filename,
    expected_mime_type,
    max_byte_size,
    uploaded_by_user_id,
    created_request_id,
    last_mutated_by_user_id,
    last_mutation_request_id
  )
  values (
    asset_id,
    target_horse.stable_id,
    target_horse.id,
    safe_filename,
    p_mime_type,
    max_size,
    actor_id,
    p_request_id,
    actor_id,
    p_request_id
  );

  insert into public.media_asset_variants (
    stable_id,
    media_asset_id,
    variant,
    object_path,
    expected_mime_type,
    max_byte_size
  )
  values (
    target_horse.stable_id,
    asset_id,
    'original',
    target_horse.stable_id::text || '/' || target_horse.id::text || '/'
      || asset_id::text || '/original',
    p_mime_type,
    max_size
  );
  if p_mime_type <> 'application/pdf' then
    insert into public.media_asset_variants (
      stable_id,
      media_asset_id,
      variant,
      object_path,
      expected_mime_type,
      max_byte_size
    )
    values (
      target_horse.stable_id,
      asset_id,
      'thumbnail',
      target_horse.stable_id::text || '/' || target_horse.id::text || '/'
        || asset_id::text || '/thumbnail',
      p_mime_type,
      1048576
    );
  end if;

  insert into public.media_links (
    id,
    stable_id,
    media_asset_id,
    horse_id,
    schedule_execution_id,
    link_kind,
    created_by_user_id,
    created_request_id
  )
  values (
    link_id,
    target_horse.stable_id,
    asset_id,
    case when p_schedule_execution_id is null then target_horse.id end,
    p_schedule_execution_id,
    case
      when p_schedule_execution_id is null then 'horse'
      else 'schedule_execution'
    end,
    actor_id,
    p_request_id
  );
  perform private.write_media_change_event(
    target_horse.stable_id,
    target_horse.id,
    asset_id,
    link_id,
    actor_id,
    actor_membership.id,
    p_request_id,
    'media_upload_session_created',
    1
  );
  insert into private.media_mutation_receipts (
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
    target_horse.stable_id,
    'create_media_upload_session',
    'media_asset',
    asset_id,
    payload_hash,
    jsonb_build_object('media_asset_id', asset_id)
  );
  result := private.media_upload_session_result(asset_id, false);
  return result;
end;
$$;

create or replace function public.finalize_media_asset(
  p_actor_user_id uuid,
  p_media_asset_id uuid,
  p_expected_row_version bigint,
  p_original_mime_type text,
  p_original_byte_size bigint,
  p_original_sha256_hex text,
  p_thumbnail_mime_type text,
  p_thumbnail_byte_size bigint,
  p_thumbnail_sha256_hex text,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  asset_snapshot public.media_assets%rowtype;
  target_asset public.media_assets%rowtype;
  actor_membership public.stable_memberships%rowtype;
  original_variant public.media_asset_variants%rowtype;
  thumbnail_variant public.media_asset_variants%rowtype;
  existing_receipt jsonb;
  payload_hash bytea;
begin
  if p_actor_user_id is null
    or p_media_asset_id is null
    or p_expected_row_version is null
    or p_request_id is null
    or p_original_byte_size is null
    or p_original_byte_size <= 0
    or p_original_sha256_hex !~ '^[0-9A-Fa-f]{64}$'
  then
    raise exception using errcode = '22023', message = 'MEDIA_FINALIZE_INPUT_INVALID';
  end if;
  payload_hash := extensions.digest(
    jsonb_build_object(
      'media_asset_id', p_media_asset_id,
      'expected_row_version', p_expected_row_version,
      'original_mime_type', p_original_mime_type,
      'original_byte_size', p_original_byte_size,
      'original_sha256_hex', lower(p_original_sha256_hex),
      'thumbnail_mime_type', p_thumbnail_mime_type,
      'thumbnail_byte_size', p_thumbnail_byte_size,
      'thumbnail_sha256_hex', lower(p_thumbnail_sha256_hex)
    )::text,
    'sha256'
  );
  perform private.lock_media_request(p_actor_user_id, p_request_id);
  existing_receipt := private.media_receipt_result(
    p_actor_user_id,
    p_request_id,
    'finalize_media_asset',
    payload_hash
  );
  if existing_receipt is not null then
    select * into target_asset
    from public.media_assets asset
    where asset.id = p_media_asset_id;
    return jsonb_build_object(
      'media_asset_id', target_asset.id,
      'status', target_asset.status,
      'row_version', target_asset.row_version,
      'idempotent', true
    );
  end if;

  select * into asset_snapshot
  from public.media_assets asset
  where asset.id = p_media_asset_id;
  if asset_snapshot.id is null then
    raise exception using errcode = '42501', message = 'MEDIA_UNAVAILABLE';
  end if;
  actor_membership := private.lock_media_actor_context(
    p_actor_user_id,
    asset_snapshot.stable_id,
    asset_snapshot.horse_id
  );
  select * into target_asset
  from public.media_assets asset
  where asset.id = p_media_asset_id
    and asset.stable_id = asset_snapshot.stable_id
  for update;
  if target_asset.status <> 'pending' then
    raise exception using errcode = '55000', message = 'MEDIA_NOT_PENDING';
  end if;
  if target_asset.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'MEDIA_VERSION_CONFLICT';
  end if;
  if not private.media_actor_can_continue_asset_upload(
    p_actor_user_id,
    target_asset.id
  ) then
    raise exception using errcode = '42501', message = 'MEDIA_FINALIZE_FORBIDDEN';
  end if;

  select * into original_variant
  from public.media_asset_variants variant
  where variant.media_asset_id = target_asset.id
    and variant.variant = 'original'
  for update;
  if original_variant.id is null
    or p_original_mime_type <> target_asset.expected_mime_type
    or p_original_mime_type <> original_variant.expected_mime_type
    or p_original_byte_size > target_asset.max_byte_size
    or p_original_byte_size > original_variant.max_byte_size
  then
    raise exception using errcode = '22023', message = 'MEDIA_ORIGINAL_INVALID';
  end if;
  perform 1
  from storage.objects object
  where object.bucket_id = original_variant.bucket_id
    and object.name = original_variant.object_path
  for share;
  if not found then
    raise exception using errcode = '55000', message = 'MEDIA_ORIGINAL_MISSING';
  end if;

  select * into thumbnail_variant
  from public.media_asset_variants variant
  where variant.media_asset_id = target_asset.id
    and variant.variant = 'thumbnail'
  for update;
  if target_asset.expected_mime_type = 'application/pdf' then
    if thumbnail_variant.id is not null
      or p_thumbnail_mime_type is not null
      or p_thumbnail_byte_size is not null
      or p_thumbnail_sha256_hex is not null
    then
      raise exception using errcode = '22023', message = 'MEDIA_THUMBNAIL_UNEXPECTED';
    end if;
  else
    if thumbnail_variant.id is null
      or p_thumbnail_mime_type <> thumbnail_variant.expected_mime_type
      or p_thumbnail_mime_type not in (
        'image/jpeg', 'image/png', 'image/webp'
      )
      or p_thumbnail_byte_size is null
      or p_thumbnail_byte_size <= 0
      or p_thumbnail_byte_size > thumbnail_variant.max_byte_size
      or p_thumbnail_sha256_hex !~ '^[0-9A-Fa-f]{64}$'
    then
      raise exception using errcode = '22023', message = 'MEDIA_THUMBNAIL_INVALID';
    end if;
    perform 1
    from storage.objects object
    where object.bucket_id = thumbnail_variant.bucket_id
      and object.name = thumbnail_variant.object_path
    for share;
    if not found then
      raise exception using errcode = '55000', message = 'MEDIA_THUMBNAIL_MISSING';
    end if;
  end if;

  update public.media_asset_variants variant
  set
    status = 'ready',
    mime_type = p_original_mime_type,
    byte_size = p_original_byte_size,
    sha256 = decode(p_original_sha256_hex, 'hex'),
    ready_at = timezone('utc', pg_catalog.now())
  where variant.id = original_variant.id;
  if thumbnail_variant.id is not null then
    update public.media_asset_variants variant
    set
      status = 'ready',
      mime_type = p_thumbnail_mime_type,
      byte_size = p_thumbnail_byte_size,
      sha256 = decode(p_thumbnail_sha256_hex, 'hex'),
      ready_at = timezone('utc', pg_catalog.now())
    where variant.id = thumbnail_variant.id;
  end if;
  update public.media_assets asset
  set
    status = 'ready',
    mime_type = p_original_mime_type,
    byte_size = p_original_byte_size,
    sha256 = decode(p_original_sha256_hex, 'hex'),
    ready_at = timezone('utc', pg_catalog.now()),
    last_mutated_by_user_id = p_actor_user_id,
    last_mutation_request_id = p_request_id
  where asset.id = target_asset.id
  returning * into target_asset;

  perform private.write_media_change_event(
    target_asset.stable_id,
    target_asset.horse_id,
    target_asset.id,
    null,
    p_actor_user_id,
    actor_membership.id,
    p_request_id,
    'media_asset_finalized',
    target_asset.row_version
  );
  insert into private.media_mutation_receipts (
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
    p_actor_user_id,
    p_request_id,
    target_asset.stable_id,
    'finalize_media_asset',
    'media_asset',
    target_asset.id,
    payload_hash,
    jsonb_build_object(
      'media_asset_id', target_asset.id,
      'status', target_asset.status,
      'row_version', target_asset.row_version
    )
  );
  return jsonb_build_object(
    'media_asset_id', target_asset.id,
    'status', target_asset.status,
    'row_version', target_asset.row_version,
    'idempotent', false
  );
end;
$$;

create or replace function public.get_media_upload_session(
  p_actor_user_id uuid,
  p_media_asset_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'media_asset_id', asset.id,
    'row_version', asset.row_version,
    'status', asset.status,
    'bucket_id', asset.bucket_id,
    'expected_mime_type', asset.expected_mime_type,
    'variants', jsonb_agg(
      jsonb_build_object(
        'variant', variant.variant,
        'object_path', variant.object_path,
        'expected_mime_type', variant.expected_mime_type,
        'max_byte_size', variant.max_byte_size
      )
      order by variant.variant
    )
  )
  from public.media_assets asset
  join public.horses horse
    on horse.id = asset.horse_id
   and horse.stable_id = asset.stable_id
  join public.stables stable on stable.id = asset.stable_id
  join public.media_asset_variants variant
    on variant.media_asset_id = asset.id
   and variant.stable_id = asset.stable_id
  where asset.id = p_media_asset_id
    and asset.status in ('pending', 'ready')
    and horse.status = 'active'
    and stable.status = 'active'
    and (
      private.media_actor_membership(
        p_actor_user_id,
        asset.stable_id
      )
    ).id is not null
    and private.media_actor_can_continue_asset_upload(
      p_actor_user_id,
      asset.id
    )
  group by asset.id
$$;

create or replace function public.link_media_asset(
  p_media_asset_id uuid,
  p_horse_id uuid,
  p_schedule_execution_id uuid,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  asset_snapshot public.media_assets%rowtype;
  target_asset public.media_assets%rowtype;
  target_execution public.schedule_executions%rowtype;
  target_item public.schedule_items%rowtype;
  actor_membership public.stable_memberships%rowtype;
  created_link public.media_links%rowtype;
  existing_receipt jsonb;
  payload_hash bytea;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_request_id is null
    or p_media_asset_id is null
    or ((p_horse_id is null) = (p_schedule_execution_id is null))
  then
    raise exception using errcode = '22023', message = 'MEDIA_LINK_INPUT_INVALID';
  end if;
  payload_hash := extensions.digest(
    jsonb_build_object(
      'media_asset_id', p_media_asset_id,
      'horse_id', p_horse_id,
      'schedule_execution_id', p_schedule_execution_id
    )::text,
    'sha256'
  );
  perform private.lock_media_request(actor_id, p_request_id);
  existing_receipt := private.media_receipt_result(
    actor_id,
    p_request_id,
    'link_media_asset',
    payload_hash
  );
  if existing_receipt is not null then
    return existing_receipt;
  end if;
  select * into asset_snapshot
  from public.media_assets asset
  where asset.id = p_media_asset_id;
  if asset_snapshot.id is null then
    raise exception using errcode = '42501', message = 'MEDIA_UNAVAILABLE';
  end if;
  actor_membership := private.lock_media_context(
    asset_snapshot.stable_id,
    asset_snapshot.horse_id
  );
  if not private.media_actor_has_capability(
    actor_id, asset_snapshot.horse_id, 'edit'
  ) then
    raise exception using errcode = '42501', message = 'MEDIA_EDIT_REQUIRED';
  end if;
  select * into target_asset
  from public.media_assets asset
  where asset.id = p_media_asset_id
    and asset.stable_id = asset_snapshot.stable_id
  for update;
  if target_asset.status <> 'ready' then
    raise exception using errcode = '55000', message = 'MEDIA_NOT_READY';
  end if;
  if p_horse_id is not null and p_horse_id <> target_asset.horse_id then
    raise exception using errcode = '23514', message = 'MEDIA_HORSE_SCOPE_MISMATCH';
  end if;
  if p_schedule_execution_id is not null then
    select * into target_execution
    from public.schedule_executions execution
    where execution.id = p_schedule_execution_id
      and execution.stable_id = target_asset.stable_id;
    select * into target_item
    from public.schedule_items item
    where item.id = target_execution.schedule_item_id
      and item.stable_id = target_asset.stable_id;
    if target_execution.id is null or target_item.horse_id <> target_asset.horse_id then
      raise exception using
        errcode = '23514',
        message = 'MEDIA_EXECUTION_SCOPE_MISMATCH';
    end if;
  end if;
  insert into public.media_links (
    stable_id,
    media_asset_id,
    horse_id,
    schedule_execution_id,
    link_kind,
    created_by_user_id,
    created_request_id
  )
  values (
    target_asset.stable_id,
    target_asset.id,
    p_horse_id,
    p_schedule_execution_id,
    case when p_horse_id is not null then 'horse' else 'schedule_execution' end,
    actor_id,
    p_request_id
  )
  returning * into created_link;
  perform private.write_media_change_event(
    target_asset.stable_id,
    target_asset.horse_id,
    target_asset.id,
    created_link.id,
    actor_id,
    actor_membership.id,
    p_request_id,
    'media_asset_linked',
    target_asset.row_version
  );
  insert into private.media_mutation_receipts (
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
    target_asset.stable_id,
    'link_media_asset',
    'media_link',
    created_link.id,
    payload_hash,
    jsonb_build_object(
      'media_link_id', created_link.id,
      'media_asset_id', target_asset.id,
      'idempotent', false
    )
  );
  return jsonb_build_object(
    'media_link_id', created_link.id,
    'media_asset_id', target_asset.id,
    'idempotent', false
  );
end;
$$;

create or replace function public.archive_media_asset(
  p_media_asset_id uuid,
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
  asset_snapshot public.media_assets%rowtype;
  target_asset public.media_assets%rowtype;
  actor_membership public.stable_memberships%rowtype;
  existing_receipt jsonb;
  payload_hash bytea;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_media_asset_id is null
    or p_expected_row_version is null
    or p_request_id is null
  then
    raise exception using errcode = '22023', message = 'MEDIA_ARCHIVE_INPUT_INVALID';
  end if;
  payload_hash := extensions.digest(
    jsonb_build_object(
      'media_asset_id', p_media_asset_id,
      'expected_row_version', p_expected_row_version
    )::text,
    'sha256'
  );
  perform private.lock_media_request(actor_id, p_request_id);
  existing_receipt := private.media_receipt_result(
    actor_id,
    p_request_id,
    'archive_media_asset',
    payload_hash
  );
  if existing_receipt is not null then return existing_receipt; end if;
  select * into asset_snapshot
  from public.media_assets asset
  where asset.id = p_media_asset_id;
  if asset_snapshot.id is null then
    raise exception using errcode = '42501', message = 'MEDIA_UNAVAILABLE';
  end if;
  actor_membership := private.lock_media_context(
    asset_snapshot.stable_id,
    asset_snapshot.horse_id
  );
  if not private.media_actor_has_capability(
    actor_id, asset_snapshot.horse_id, 'edit'
  ) then
    raise exception using errcode = '42501', message = 'MEDIA_EDIT_REQUIRED';
  end if;
  select * into target_asset
  from public.media_assets asset
  where asset.id = p_media_asset_id
    and asset.stable_id = asset_snapshot.stable_id
  for update;
  if target_asset.status not in ('pending', 'ready', 'quarantined') then
    raise exception using errcode = '55000', message = 'MEDIA_NOT_ARCHIVABLE';
  end if;
  if target_asset.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'MEDIA_VERSION_CONFLICT';
  end if;
  update public.media_asset_variants variant
  set status = 'archived'
  where variant.media_asset_id = target_asset.id
    and variant.status in ('pending', 'ready', 'quarantined');
  update public.media_links link
  set archived_at = coalesce(link.archived_at, timezone('utc', pg_catalog.now()))
  where link.media_asset_id = target_asset.id
    and link.archived_at is null;
  update public.media_assets asset
  set
    status = 'archived',
    archived_at = timezone('utc', pg_catalog.now()),
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where asset.id = target_asset.id
  returning * into target_asset;
  perform private.write_media_change_event(
    target_asset.stable_id,
    target_asset.horse_id,
    target_asset.id,
    null,
    actor_id,
    actor_membership.id,
    p_request_id,
    'media_asset_archived',
    target_asset.row_version
  );
  insert into private.media_mutation_receipts (
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
    target_asset.stable_id,
    'archive_media_asset',
    'media_asset',
    target_asset.id,
    payload_hash,
    jsonb_build_object(
      'media_asset_id', target_asset.id,
      'status', target_asset.status,
      'row_version', target_asset.row_version,
      'idempotent', false
    )
  );
  return jsonb_build_object(
    'media_asset_id', target_asset.id,
    'status', target_asset.status,
    'row_version', target_asset.row_version,
    'idempotent', false
  );
end;
$$;

create or replace function public.authorize_media_asset_download(
  p_actor_user_id uuid,
  p_media_asset_id uuid,
  p_variant text
)
returns table (
  bucket_id text,
  object_path text,
  mime_type text
)
language sql
stable
security definer
set search_path = ''
as $$
  select variant.bucket_id, variant.object_path, variant.mime_type
  from public.media_assets asset
  join public.media_asset_variants variant
    on variant.media_asset_id = asset.id
   and variant.stable_id = asset.stable_id
  where asset.id = p_media_asset_id
    and asset.status = 'ready'
    and variant.status = 'ready'
    and variant.variant = p_variant
    and private.media_actor_can_view_asset(p_actor_user_id, asset.id)
$$;

alter table public.media_assets enable row level security;
alter table public.media_asset_variants enable row level security;
alter table public.media_links enable row level security;
alter table public.media_change_events enable row level security;

revoke all on table public.media_assets
  from public, anon, authenticated;
revoke all on table public.media_asset_variants
  from public, anon, authenticated;
revoke all on table public.media_links
  from public, anon, authenticated;
revoke all on table public.media_change_events
  from public, anon, authenticated;
revoke all on table private.media_mutation_receipts
  from public, anon, authenticated;
revoke all on sequence public.media_change_events_id_seq
  from public, anon, authenticated;

grant select on table public.media_assets to authenticated;
grant select on table public.media_asset_variants to authenticated;
grant select on table public.media_links to authenticated;
grant select on table public.media_change_events to authenticated;

create policy media_assets_select_authorized
on public.media_assets for select to authenticated
using (private.can_view_media_asset(id));

create policy media_variants_select_authorized
on public.media_asset_variants for select to authenticated
using (private.can_view_media_asset(media_asset_id));

create policy media_links_select_authorized
on public.media_links for select to authenticated
using (private.can_view_media_link(id));

create policy media_events_select_authorized
on public.media_change_events for select to authenticated
using (private.can_view_media_audit(media_asset_id));

revoke all on function private.touch_media_asset()
  from public, anon, authenticated;
revoke all on function private.prevent_media_append_only_mutation()
  from public, anon, authenticated;
revoke all on function private.guard_media_link_scope()
  from public, anon, authenticated;
revoke all on function private.media_receipt_result(uuid, uuid, text, bytea)
  from public, anon, authenticated;
revoke all on function private.lock_media_request(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.lock_media_context(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.write_media_change_event(
  uuid, uuid, uuid, uuid, uuid, uuid, uuid, text, bigint
) from public, anon, authenticated;
revoke all on function private.media_actor_membership(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.media_actor_has_capability(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function private.media_actor_schedule_access_level(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.media_actor_can_upload_to_target(
  uuid, uuid, uuid
) from public, anon, authenticated;
revoke all on function private.media_actor_can_continue_asset_upload(
  uuid, uuid
) from public, anon, authenticated;
revoke all on function private.media_actor_can_view_link(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.media_actor_can_view_asset(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_media_asset(uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_media_link(uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_media_audit(uuid)
  from public, anon, authenticated;
revoke all on function private.lock_media_actor_context(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.media_upload_session_result(uuid, boolean)
  from public, anon, authenticated;

grant execute on function private.can_view_media_asset(uuid)
  to authenticated;
grant execute on function private.can_view_media_link(uuid)
  to authenticated;
grant execute on function private.can_view_media_audit(uuid)
  to authenticated;

revoke execute on function public.create_media_upload_session(
  uuid, uuid, text, text, uuid
) from public, anon;
revoke execute on function public.finalize_media_asset(
  uuid, uuid, bigint, text, bigint, text, text, bigint, text, uuid
) from public, anon, authenticated;
revoke execute on function public.get_media_upload_session(
  uuid, uuid
) from public, anon, authenticated;
revoke execute on function public.link_media_asset(
  uuid, uuid, uuid, uuid
) from public, anon;
revoke execute on function public.archive_media_asset(
  uuid, bigint, uuid
) from public, anon;
revoke execute on function public.authorize_media_asset_download(
  uuid, uuid, text
) from public, anon, authenticated;

grant execute on function public.create_media_upload_session(
  uuid, uuid, text, text, uuid
) to authenticated;
grant execute on function public.link_media_asset(
  uuid, uuid, uuid, uuid
) to authenticated;
grant execute on function public.archive_media_asset(
  uuid, bigint, uuid
) to authenticated;
grant execute on function public.finalize_media_asset(
  uuid, uuid, bigint, text, bigint, text, text, bigint, text, uuid
) to service_role;
grant execute on function public.get_media_upload_session(
  uuid, uuid
) to service_role;
grant execute on function public.authorize_media_asset_download(
  uuid, uuid, text
) to service_role;

comment on table public.media_assets is
  'Private Horse media lifecycle metadata; object paths live in variants and direct client DML is forbidden.';
comment on table public.media_asset_variants is
  'Server-chosen private object paths and independently verified metadata for original and thumbnail bytes.';
comment on table public.media_links is
  'Typed same-Horse media links to either a Horse or a schedule execution.';
comment on table public.media_change_events is
  'Append-only payload-minimal audit trail; signed URLs, tokens, object paths, filenames and hashes are intentionally absent.';
comment on function public.create_media_upload_session(
  uuid, uuid, text, text, uuid
) is
  'Creates a pending asset with server-chosen original/thumbnail paths; Edge converts those paths to transient signed upload URLs.';
comment on function public.finalize_media_asset(
  uuid, uuid, bigint, text, bigint, text, text, bigint, text, uuid
) is
  'Service-role-only atomic finalize after Edge has downloaded, magic-checked, sized and SHA-256 hashed every uploaded variant.';
comment on function public.get_media_upload_session(uuid, uuid) is
  'Service-role-only object coordinates for Edge byte verification; never granted to clients and never persisted in events or receipts.';
comment on function public.authorize_media_asset_download(
  uuid, uuid, text
) is
  'Service-role-only authorization returning an object coordinate; Edge emits a 60-second signed URL only after this check.';
comment on function public.archive_media_asset(uuid, bigint, uuid) is
  'Soft-archives metadata and links without deleting private object bytes; purge remains a later retention-policy operation.';

commit;
