begin;

-- C-009.1 makes the existing private media aggregate canonical-horse scoped.
-- Existing C-008 legacy horse ids are identical to their canonical horse ids,
-- so no asset row or object path needs to be rewritten.

do $$
begin
  if exists (
    select 1
    from public.media_assets asset
    left join public.canonical_horses horse on horse.id = asset.horse_id
    where horse.id is null
  ) then
    raise exception using
      errcode = '23503',
      message = 'C0091_MEDIA_CANONICAL_HORSE_UNRESOLVED';
  end if;
  if exists (
    select 1
    from public.media_assets asset
    left join public.horses legacy_horse
      on legacy_horse.id = asset.horse_id
     and legacy_horse.stable_id = asset.stable_id
    where asset.stable_id is not null
      and legacy_horse.id is null
  ) then
    raise exception using
      errcode = '23503',
      message = 'C0091_MEDIA_LEGACY_CONTEXT_INVALID';
  end if;
end;
$$;

alter table public.media_assets
  drop constraint media_assets_horse_fk,
  alter column stable_id drop not null,
  add constraint media_assets_canonical_horse_fk
    foreign key (horse_id) references public.canonical_horses(id) on delete restrict;

alter table public.media_asset_variants
  drop constraint media_asset_variants_asset_fk,
  alter column stable_id drop not null,
  add constraint media_asset_variants_asset_id_fk
    foreign key (media_asset_id) references public.media_assets(id) on delete restrict;

alter table public.media_links
  drop constraint media_links_asset_fk,
  drop constraint media_links_horse_fk,
  alter column stable_id drop not null,
  add constraint media_links_asset_id_fk
    foreign key (media_asset_id) references public.media_assets(id) on delete restrict,
  add constraint media_links_canonical_horse_fk
    foreign key (horse_id) references public.canonical_horses(id) on delete restrict;

alter table public.media_change_events
  drop constraint media_change_events_horse_fk,
  drop constraint media_change_events_asset_fk,
  drop constraint media_change_events_link_fk,
  drop constraint media_change_events_membership_fk,
  alter column stable_id drop not null,
  alter column actor_membership_id drop not null,
  add constraint media_change_events_canonical_horse_fk
    foreign key (horse_id) references public.canonical_horses(id) on delete restrict,
  add constraint media_change_events_asset_id_fk
    foreign key (media_asset_id) references public.media_assets(id) on delete restrict,
  add constraint media_change_events_link_id_fk
    foreign key (media_link_id) references public.media_links(id) on delete restrict,
  add constraint media_change_events_membership_id_fk
    foreign key (actor_membership_id) references public.stable_memberships(id) on delete restrict;

alter table private.media_mutation_receipts
  drop constraint media_mutation_receipts_operation_name_check,
  alter column stable_id drop not null,
  add constraint media_mutation_receipts_operation_name_check
    check (operation_name in (
      'create_media_upload_session',
      'finalize_media_asset',
      'link_media_asset',
      'archive_media_asset',
      'create_canonical_media_upload_session',
      'finalize_canonical_media_asset',
      'archive_canonical_media_asset',
      'set_canonical_horse_profile_media'
    ));

create or replace function private.c0091_guard_media_asset_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE' and (
    new.horse_id is distinct from old.horse_id
    or new.stable_id is distinct from old.stable_id
  ) then
    raise exception using errcode = '42501', message = 'MEDIA_SCOPE_IMMUTABLE';
  end if;
  if not exists (
    select 1 from public.canonical_horses horse where horse.id = new.horse_id
  ) then
    raise exception using errcode = '23503', message = 'MEDIA_CANONICAL_HORSE_INVALID';
  end if;
  if new.stable_id is not null and not exists (
    select 1
    from public.horses legacy_horse
    where legacy_horse.id = new.horse_id
      and legacy_horse.stable_id = new.stable_id
  ) then
    raise exception using errcode = '23503', message = 'MEDIA_LEGACY_CONTEXT_INVALID';
  end if;
  return new;
end;
$$;

create trigger c0091_media_assets_scope_before_write
before insert or update of horse_id, stable_id on public.media_assets
for each row execute function private.c0091_guard_media_asset_scope();

create or replace function private.c0091_guard_media_variant_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  asset_stable_id uuid;
begin
  if tg_op = 'UPDATE' and new.media_asset_id is distinct from old.media_asset_id then
    raise exception using errcode = '42501', message = 'MEDIA_VARIANT_SCOPE_IMMUTABLE';
  end if;
  select asset.stable_id into asset_stable_id
  from public.media_assets asset
  where asset.id = new.media_asset_id;
  if not found or new.stable_id is distinct from asset_stable_id then
    raise exception using errcode = '23503', message = 'MEDIA_VARIANT_SCOPE_INVALID';
  end if;
  return new;
end;
$$;

create trigger c0091_media_variants_scope_before_write
before insert or update of media_asset_id, stable_id on public.media_asset_variants
for each row execute function private.c0091_guard_media_variant_scope();

create or replace function private.guard_media_link_scope()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  asset_horse_id uuid;
  asset_stable_id uuid;
  execution_horse_id uuid;
begin
  select asset.horse_id, asset.stable_id
    into asset_horse_id, asset_stable_id
  from public.media_assets asset
  where asset.id = new.media_asset_id;
  if asset_horse_id is null or new.stable_id is distinct from asset_stable_id then
    raise exception using errcode = '23503', message = 'MEDIA_ASSET_SCOPE_INVALID';
  end if;
  if new.link_kind = 'horse' then
    if new.horse_id is distinct from asset_horse_id
      or new.schedule_execution_id is not null
    then
      raise exception using errcode = '23514', message = 'MEDIA_HORSE_SCOPE_MISMATCH';
    end if;
  else
    if new.stable_id is null then
      raise exception using errcode = '23514', message = 'MEDIA_EXECUTION_STABLE_REQUIRED';
    end if;
    select schedule_item.horse_id into execution_horse_id
    from public.schedule_executions execution
    join public.schedule_items schedule_item
      on schedule_item.id = execution.schedule_item_id
     and schedule_item.stable_id = execution.stable_id
    where execution.id = new.schedule_execution_id
      and execution.stable_id = new.stable_id;
    if execution_horse_id is null or execution_horse_id <> asset_horse_id then
      raise exception using errcode = '23514', message = 'MEDIA_EXECUTION_SCOPE_MISMATCH';
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.c0091_profile_id_for_user(p_actor_user_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select profile.id
  from public.profiles profile
  where profile.auth_user_id = p_actor_user_id
    and profile.status = 'active'
  limit 1
$$;

create or replace function private.c0091_actor_has_media_permission(
  p_actor_user_id uuid,
  p_horse_id uuid,
  p_permission_code text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_actor_user_id is not null
    and p_permission_code in ('horse.view', 'horse.edit')
    and exists (
      select 1
      from public.canonical_horses horse
      where horse.id = p_horse_id
        and horse.status = 'active'
        and private.c003c_profile_has_horse_permission(
          private.c0091_profile_id_for_user(p_actor_user_id),
          horse.id,
          p_permission_code,
          pg_catalog.statement_timestamp()
        )
    )
$$;

create or replace function private.c0091_require_media_permission(
  p_actor_user_id uuid,
  p_horse_id uuid,
  p_permission_code text
)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.c0091_actor_has_media_permission(
    p_actor_user_id, p_horse_id, p_permission_code
  ) then
    raise exception using errcode = '42501', message = 'MEDIA_PERMISSION_REQUIRED';
  end if;
end;
$$;

-- Legacy media helpers remain callable by the old Planning/Feeding RPCs, but
-- stable membership is never sufficient after this replacement.
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
  select case p_capability
    when 'view' then private.c0091_actor_has_media_permission(
      p_actor_user_id, p_horse_id, 'horse.view'
    )
    when 'edit' then private.c0091_actor_has_media_permission(
      p_actor_user_id, p_horse_id, 'horse.edit'
    )
    when 'manage' then private.c0091_actor_has_media_permission(
      p_actor_user_id, p_horse_id, 'horse.edit'
    )
    else false
  end
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
  select private.c0091_actor_has_media_permission(
    p_actor_user_id, p_horse_id, 'horse.view'
  ) and exists (
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
        (p_schedule_execution_id is null and private.c0091_actor_has_media_permission(
          p_actor_user_id, p_horse_id, 'horse.edit'
        ))
        or (p_schedule_execution_id is not null and exists (
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
              or private.c0091_actor_has_media_permission(
                p_actor_user_id, p_horse_id, 'horse.edit'
              )
            )
        ))
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
     and link.archived_at is null
    where asset.id = p_media_asset_id
      and asset.uploaded_by_user_id = p_actor_user_id
      and private.c0091_actor_has_media_permission(
        p_actor_user_id, asset.horse_id,
        case when link.link_kind = 'horse' then 'horse.edit' else 'horse.view' end
      )
      and (
        link.link_kind = 'horse'
        or private.media_actor_can_upload_to_target(
          p_actor_user_id, asset.horse_id, link.schedule_execution_id
        )
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
    join public.media_assets asset on asset.id = link.media_asset_id
    where link.id = p_media_link_id
      and link.archived_at is null
      and asset.status = 'ready'
      and private.c0091_actor_has_media_permission(
        p_actor_user_id, asset.horse_id, 'horse.view'
      )
      and (
        link.link_kind = 'horse'
        or exists (
          select 1
          from public.schedule_executions execution
          where execution.id = link.schedule_execution_id
            and execution.stable_id = link.stable_id
            and (
              execution.actor_user_id = p_actor_user_id
              or private.media_actor_schedule_access_level(
                p_actor_user_id, execution.schedule_item_id
              ) in ('full', 'assigned')
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

create or replace function private.can_view_media_audit(p_media_asset_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null and exists (
    select 1
    from public.media_assets asset
    where asset.id = p_media_asset_id
      and private.c0091_actor_has_media_permission(
        auth.uid(), asset.horse_id, 'horse.view'
      )
  )
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
  select pg_catalog.jsonb_build_object(
    'media_asset_id', asset.id,
    'row_version', asset.row_version,
    'status', case
      when asset.status = 'pending' and pg_catalog.bool_and(variant.status = 'pending')
        then 'pending'
      when asset.status = 'ready' and pg_catalog.bool_and(variant.status = 'ready')
        then 'ready'
      else 'closed'
    end,
    'bucket_id', asset.bucket_id,
    'idempotent', p_idempotent,
    'variants', coalesce(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'variant', variant.variant,
          'object_path', variant.object_path,
          'expected_mime_type', variant.expected_mime_type,
          'max_byte_size', variant.max_byte_size
        ) order by variant.variant
      ) filter (where asset.status = 'pending' and variant.status = 'pending'),
      '[]'::jsonb
    )
  )
  from public.media_assets asset
  join public.media_asset_variants variant on variant.media_asset_id = asset.id
  where asset.id = p_media_asset_id
  group by asset.id
$$;

create or replace function public.create_canonical_media_upload_session(
  p_horse_id uuid,
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
  actor_user_id uuid := auth.uid();
  actor_membership_id uuid;
  compatibility_stable_id uuid;
  replay_asset public.media_assets%rowtype;
  existing_receipt jsonb;
  asset_id uuid := extensions.gen_random_uuid();
  link_id uuid := extensions.gen_random_uuid();
  safe_filename text;
  payload_hash bytea;
  max_size bigint;
begin
  if actor_user_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_request_id is null or p_horse_id is null or p_mime_type not in (
    'image/jpeg', 'image/png', 'image/webp', 'application/pdf'
  ) then
    raise exception using errcode = '22023', message = 'MEDIA_INPUT_INVALID';
  end if;
  safe_filename := pg_catalog.btrim(pg_catalog.regexp_replace(
    pg_catalog.regexp_replace(coalesce(p_original_filename, ''), '^.*[\\/]', ''),
    '[^[:alnum:] ._()\\-]', '_', 'g'
  ));
  if pg_catalog.length(safe_filename) not between 1 and 240 then
    raise exception using errcode = '22023', message = 'MEDIA_FILENAME_INVALID';
  end if;
  perform private.c0091_require_media_permission(
    actor_user_id, p_horse_id, 'horse.edit'
  );
  payload_hash := extensions.digest(pg_catalog.jsonb_build_object(
    'horse_id', p_horse_id,
    'original_filename', safe_filename,
    'mime_type', p_mime_type
  )::text, 'sha256');
  perform private.lock_media_request(actor_user_id, p_request_id);
  existing_receipt := private.media_receipt_result(
    actor_user_id, p_request_id, 'create_canonical_media_upload_session', payload_hash
  );
  if existing_receipt is not null then
    select * into replay_asset
    from public.media_assets asset
    where asset.id = (existing_receipt->>'media_asset_id')::uuid;
    if replay_asset.id is null or replay_asset.horse_id <> p_horse_id then
      raise exception using errcode = '42501', message = 'MEDIA_UNAVAILABLE';
    end if;
    perform private.c0091_require_media_permission(
      actor_user_id, replay_asset.horse_id, 'horse.edit'
    );
    return private.media_upload_session_result(replay_asset.id, true);
  end if;

  perform 1
  from public.canonical_horses horse
  where horse.id = p_horse_id and horse.status = 'active'
  for share;
  if not found then
    raise exception using errcode = '42501', message = 'MEDIA_UNAVAILABLE';
  end if;
  perform private.c0091_require_media_permission(
    actor_user_id, p_horse_id, 'horse.edit'
  );
  select legacy_horse.stable_id into compatibility_stable_id
  from public.horses legacy_horse
  where legacy_horse.id = p_horse_id;
  if compatibility_stable_id is not null then
    select membership.id into actor_membership_id
    from public.stable_memberships membership
    where membership.stable_id = compatibility_stable_id
      and membership.user_id = actor_user_id
      and membership.status = 'active'
    limit 1;
  end if;
  max_size := case when p_mime_type = 'application/pdf' then 20971520 else 10485760 end;

  insert into public.media_assets (
    id, stable_id, horse_id, original_filename, expected_mime_type,
    max_byte_size, uploaded_by_user_id, created_request_id,
    last_mutated_by_user_id, last_mutation_request_id
  ) values (
    asset_id, compatibility_stable_id, p_horse_id, safe_filename, p_mime_type,
    max_size, actor_user_id, p_request_id, actor_user_id, p_request_id
  );
  insert into public.media_asset_variants (
    stable_id, media_asset_id, variant, object_path, expected_mime_type, max_byte_size
  ) values (
    compatibility_stable_id, asset_id, 'original',
    coalesce(compatibility_stable_id::text, 'canonical') || '/' ||
      p_horse_id::text || '/' || asset_id::text || '/original',
    p_mime_type, max_size
  );
  if p_mime_type <> 'application/pdf' then
    insert into public.media_asset_variants (
      stable_id, media_asset_id, variant, object_path, expected_mime_type, max_byte_size
    ) values (
      compatibility_stable_id, asset_id, 'thumbnail',
      coalesce(compatibility_stable_id::text, 'canonical') || '/' ||
        p_horse_id::text || '/' || asset_id::text || '/thumbnail',
      p_mime_type, 1048576
    );
  end if;
  insert into public.media_links (
    id, stable_id, media_asset_id, horse_id, schedule_execution_id,
    link_kind, created_by_user_id, created_request_id
  ) values (
    link_id, compatibility_stable_id, asset_id, p_horse_id, null,
    'horse', actor_user_id, p_request_id
  );
  perform private.write_media_change_event(
    compatibility_stable_id, p_horse_id, asset_id, link_id, actor_user_id,
    actor_membership_id, p_request_id, 'media_upload_session_created', 1
  );
  insert into private.media_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name, target_type,
    target_id, payload_hash, result
  ) values (
    actor_user_id, p_request_id, compatibility_stable_id,
    'create_canonical_media_upload_session', 'media_asset', asset_id,
    payload_hash, pg_catalog.jsonb_build_object('media_asset_id', asset_id)
  );
  return private.media_upload_session_result(asset_id, false);
end;
$$;

create or replace function public.get_canonical_media_upload_session(
  p_actor_user_id uuid,
  p_media_asset_id uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.jsonb_build_object(
    'media_asset_id', asset.id,
    'row_version', asset.row_version,
    'status', asset.status,
    'bucket_id', asset.bucket_id,
    'expected_mime_type', asset.expected_mime_type,
    'variants', pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'variant', variant.variant,
      'object_path', variant.object_path,
      'expected_mime_type', variant.expected_mime_type,
      'max_byte_size', variant.max_byte_size
    ) order by variant.variant)
  )
  from public.media_assets asset
  join public.media_asset_variants variant on variant.media_asset_id = asset.id
  where asset.id = p_media_asset_id
    and asset.status in ('pending', 'ready')
    and asset.uploaded_by_user_id = p_actor_user_id
    and private.c0091_actor_has_media_permission(
      p_actor_user_id, asset.horse_id, 'horse.edit'
    )
  group by asset.id
$$;

create or replace function public.finalize_canonical_media_asset(
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
  target_asset public.media_assets%rowtype;
  original_variant public.media_asset_variants%rowtype;
  thumbnail_variant public.media_asset_variants%rowtype;
  actor_membership_id uuid;
  existing_receipt jsonb;
  payload_hash bytea;
begin
  if p_actor_user_id is null or p_media_asset_id is null
    or p_expected_row_version is null or p_request_id is null
    or p_original_byte_size is null or p_original_byte_size <= 0
    or p_original_sha256_hex !~ '^[0-9A-Fa-f]{64}$'
  then
    raise exception using errcode = '22023', message = 'MEDIA_FINALIZE_INPUT_INVALID';
  end if;
  payload_hash := extensions.digest(pg_catalog.jsonb_build_object(
    'media_asset_id', p_media_asset_id,
    'expected_row_version', p_expected_row_version,
    'original_mime_type', p_original_mime_type,
    'original_byte_size', p_original_byte_size,
    'original_sha256_hex', pg_catalog.lower(p_original_sha256_hex),
    'thumbnail_mime_type', p_thumbnail_mime_type,
    'thumbnail_byte_size', p_thumbnail_byte_size,
    'thumbnail_sha256_hex', pg_catalog.lower(p_thumbnail_sha256_hex)
  )::text, 'sha256');
  perform private.lock_media_request(p_actor_user_id, p_request_id);
  existing_receipt := private.media_receipt_result(
    p_actor_user_id, p_request_id, 'finalize_canonical_media_asset', payload_hash
  );
  if existing_receipt is not null then
    select * into target_asset from public.media_assets asset
    where asset.id = p_media_asset_id;
    return pg_catalog.jsonb_build_object(
      'media_asset_id', target_asset.id, 'status', target_asset.status,
      'row_version', target_asset.row_version, 'idempotent', true
    );
  end if;
  select * into target_asset
  from public.media_assets asset
  where asset.id = p_media_asset_id
    and asset.uploaded_by_user_id = p_actor_user_id
  for update;
  if target_asset.id is null then
    raise exception using errcode = '42501', message = 'MEDIA_UNAVAILABLE';
  end if;
  perform private.c0091_require_media_permission(
    p_actor_user_id, target_asset.horse_id, 'horse.edit'
  );
  if target_asset.status <> 'pending' then
    raise exception using errcode = '55000', message = 'MEDIA_NOT_PENDING';
  end if;
  if target_asset.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'MEDIA_VERSION_CONFLICT';
  end if;
  select * into original_variant
  from public.media_asset_variants variant
  where variant.media_asset_id = target_asset.id and variant.variant = 'original'
  for update;
  if original_variant.id is null
    or p_original_mime_type <> target_asset.expected_mime_type
    or p_original_mime_type <> original_variant.expected_mime_type
    or p_original_byte_size > target_asset.max_byte_size
    or p_original_byte_size > original_variant.max_byte_size
  then
    raise exception using errcode = '22023', message = 'MEDIA_ORIGINAL_INVALID';
  end if;
  perform 1 from storage.objects object
  where object.bucket_id = original_variant.bucket_id
    and object.name = original_variant.object_path
  for share;
  if not found then
    raise exception using errcode = '55000', message = 'MEDIA_ORIGINAL_MISSING';
  end if;
  select * into thumbnail_variant
  from public.media_asset_variants variant
  where variant.media_asset_id = target_asset.id and variant.variant = 'thumbnail'
  for update;
  if target_asset.expected_mime_type = 'application/pdf' then
    if thumbnail_variant.id is not null or p_thumbnail_mime_type is not null
      or p_thumbnail_byte_size is not null or p_thumbnail_sha256_hex is not null
    then
      raise exception using errcode = '22023', message = 'MEDIA_THUMBNAIL_UNEXPECTED';
    end if;
  else
    if thumbnail_variant.id is null
      or p_thumbnail_mime_type <> thumbnail_variant.expected_mime_type
      or p_thumbnail_mime_type not in ('image/jpeg', 'image/png', 'image/webp')
      or p_thumbnail_byte_size is null or p_thumbnail_byte_size <= 0
      or p_thumbnail_byte_size > thumbnail_variant.max_byte_size
      or p_thumbnail_sha256_hex !~ '^[0-9A-Fa-f]{64}$'
    then
      raise exception using errcode = '22023', message = 'MEDIA_THUMBNAIL_INVALID';
    end if;
    perform 1 from storage.objects object
    where object.bucket_id = thumbnail_variant.bucket_id
      and object.name = thumbnail_variant.object_path
    for share;
    if not found then
      raise exception using errcode = '55000', message = 'MEDIA_THUMBNAIL_MISSING';
    end if;
  end if;
  update public.media_asset_variants variant set
    status = 'ready', mime_type = p_original_mime_type,
    byte_size = p_original_byte_size,
    sha256 = pg_catalog.decode(p_original_sha256_hex, 'hex'),
    ready_at = pg_catalog.clock_timestamp()
  where variant.id = original_variant.id;
  if thumbnail_variant.id is not null then
    update public.media_asset_variants variant set
      status = 'ready', mime_type = p_thumbnail_mime_type,
      byte_size = p_thumbnail_byte_size,
      sha256 = pg_catalog.decode(p_thumbnail_sha256_hex, 'hex'),
      ready_at = pg_catalog.clock_timestamp()
    where variant.id = thumbnail_variant.id;
  end if;
  update public.media_assets asset set
    status = 'ready', mime_type = p_original_mime_type,
    byte_size = p_original_byte_size,
    sha256 = pg_catalog.decode(p_original_sha256_hex, 'hex'),
    ready_at = pg_catalog.clock_timestamp(),
    last_mutated_by_user_id = p_actor_user_id,
    last_mutation_request_id = p_request_id
  where asset.id = target_asset.id returning * into target_asset;
  if target_asset.stable_id is not null then
    select membership.id into actor_membership_id
    from public.stable_memberships membership
    where membership.stable_id = target_asset.stable_id
      and membership.user_id = p_actor_user_id
      and membership.status = 'active'
    limit 1;
  end if;
  perform private.write_media_change_event(
    target_asset.stable_id, target_asset.horse_id, target_asset.id, null,
    p_actor_user_id, actor_membership_id, p_request_id,
    'media_asset_finalized', target_asset.row_version
  );
  insert into private.media_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name, target_type,
    target_id, payload_hash, result
  ) values (
    p_actor_user_id, p_request_id, target_asset.stable_id,
    'finalize_canonical_media_asset', 'media_asset', target_asset.id,
    payload_hash, pg_catalog.jsonb_build_object(
      'media_asset_id', target_asset.id, 'status', target_asset.status,
      'row_version', target_asset.row_version
    )
  );
  return pg_catalog.jsonb_build_object(
    'media_asset_id', target_asset.id, 'status', target_asset.status,
    'row_version', target_asset.row_version, 'idempotent', false
  );
end;
$$;

create or replace function public.authorize_canonical_media_asset_download(
  p_actor_user_id uuid,
  p_media_asset_id uuid,
  p_variant text
)
returns table (bucket_id text, object_path text, mime_type text)
language sql
stable
security definer
set search_path = ''
as $$
  select variant.bucket_id, variant.object_path, variant.mime_type
  from public.media_assets asset
  join public.media_asset_variants variant on variant.media_asset_id = asset.id
  where asset.id = p_media_asset_id
    and asset.status = 'ready'
    and variant.status = 'ready'
    and variant.variant = p_variant
    and private.c0091_actor_has_media_permission(
      p_actor_user_id, asset.horse_id, 'horse.view'
    )
$$;

create or replace function public.archive_canonical_media_asset(
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
  actor_user_id uuid := auth.uid();
  actor_membership_id uuid;
  target_asset public.media_assets%rowtype;
  existing_receipt jsonb;
  payload_hash bytea;
begin
  if actor_user_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_media_asset_id is null or p_expected_row_version is null or p_request_id is null then
    raise exception using errcode = '22023', message = 'MEDIA_ARCHIVE_INPUT_INVALID';
  end if;
  payload_hash := extensions.digest(pg_catalog.jsonb_build_object(
    'media_asset_id', p_media_asset_id,
    'expected_row_version', p_expected_row_version
  )::text, 'sha256');
  perform private.lock_media_request(actor_user_id, p_request_id);
  existing_receipt := private.media_receipt_result(
    actor_user_id, p_request_id, 'archive_canonical_media_asset', payload_hash
  );
  if existing_receipt is not null then return existing_receipt; end if;
  select * into target_asset
  from public.media_assets asset
  where asset.id = p_media_asset_id
  for update;
  if target_asset.id is null then
    raise exception using errcode = '42501', message = 'MEDIA_UNAVAILABLE';
  end if;
  perform private.c0091_require_media_permission(
    actor_user_id, target_asset.horse_id, 'horse.edit'
  );
  if exists (
    select 1 from public.canonical_horses horse
    where horse.id = target_asset.horse_id
      and horse.profile_media_asset_id = target_asset.id
  ) then
    raise exception using errcode = '55000', message = 'MEDIA_PROFILE_SELECTION_ACTIVE';
  end if;
  if target_asset.status not in ('pending', 'ready', 'quarantined') then
    raise exception using errcode = '55000', message = 'MEDIA_NOT_ARCHIVABLE';
  end if;
  if target_asset.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'MEDIA_VERSION_CONFLICT';
  end if;
  update public.media_asset_variants variant set status = 'archived'
  where variant.media_asset_id = target_asset.id
    and variant.status in ('pending', 'ready', 'quarantined');
  update public.media_links link
  set archived_at = coalesce(link.archived_at, pg_catalog.clock_timestamp())
  where link.media_asset_id = target_asset.id and link.archived_at is null;
  update public.media_assets asset set
    status = 'archived', archived_at = pg_catalog.clock_timestamp(),
    last_mutated_by_user_id = actor_user_id,
    last_mutation_request_id = p_request_id
  where asset.id = target_asset.id returning * into target_asset;
  if target_asset.stable_id is not null then
    select membership.id into actor_membership_id
    from public.stable_memberships membership
    where membership.stable_id = target_asset.stable_id
      and membership.user_id = actor_user_id
      and membership.status = 'active'
    limit 1;
  end if;
  perform private.write_media_change_event(
    target_asset.stable_id, target_asset.horse_id, target_asset.id, null,
    actor_user_id, actor_membership_id, p_request_id,
    'media_asset_archived', target_asset.row_version
  );
  insert into private.media_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name, target_type,
    target_id, payload_hash, result
  ) values (
    actor_user_id, p_request_id, target_asset.stable_id,
    'archive_canonical_media_asset', 'media_asset', target_asset.id,
    payload_hash, pg_catalog.jsonb_build_object(
      'media_asset_id', target_asset.id, 'status', target_asset.status,
      'row_version', target_asset.row_version
    )
  );
  return pg_catalog.jsonb_build_object(
    'media_asset_id', target_asset.id, 'status', target_asset.status,
    'row_version', target_asset.row_version, 'idempotent', false
  );
end;
$$;

create or replace function public.set_canonical_horse_profile_media(
  p_horse_id uuid,
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
  actor_user_id uuid := auth.uid();
  actor_profile_id uuid;
  before_horse public.canonical_horses%rowtype;
  after_horse public.canonical_horses%rowtype;
  target_asset public.media_assets%rowtype;
  existing_receipt jsonb;
  payload_hash bytea;
  result jsonb;
begin
  if actor_user_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_horse_id is null or p_expected_row_version is null
    or p_expected_row_version < 1 or p_request_id is null
  then
    raise exception using errcode = '22023', message = 'PROFILE_MEDIA_INPUT_INVALID';
  end if;
  actor_profile_id := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile_id, p_horse_id, 'horse.edit');
  payload_hash := extensions.digest(pg_catalog.jsonb_build_object(
    'horse_id', p_horse_id,
    'media_asset_id', p_media_asset_id,
    'expected_row_version', p_expected_row_version
  )::text, 'sha256');
  perform private.lock_media_request(actor_user_id, p_request_id);
  existing_receipt := private.media_receipt_result(
    actor_user_id, p_request_id, 'set_canonical_horse_profile_media', payload_hash
  );
  if existing_receipt is not null then return existing_receipt; end if;
  select * into before_horse
  from public.canonical_horses horse
  where horse.id = p_horse_id and horse.status = 'active'
  for update;
  if before_horse.id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;
  perform private.c003c_require_permission(actor_profile_id, p_horse_id, 'horse.edit');
  if before_horse.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'STALE_HORSE_VERSION';
  end if;
  if p_media_asset_id is not null then
    select * into target_asset
    from public.media_assets asset
    where asset.id = p_media_asset_id
      and asset.horse_id = p_horse_id
      and asset.status = 'ready'
      and asset.mime_type in ('image/jpeg', 'image/png', 'image/webp')
      and exists (
        select 1
        from public.media_links link
        where link.media_asset_id = asset.id
          and link.horse_id = p_horse_id
          and link.link_kind = 'horse'
          and link.archived_at is null
      );
    if target_asset.id is null then
      raise exception using errcode = '42501', message = 'PROFILE_MEDIA_UNAVAILABLE';
    end if;
  end if;
  if before_horse.profile_media_asset_id is not distinct from p_media_asset_id then
    after_horse := before_horse;
  else
    update public.canonical_horses horse set
      profile_media_asset_id = p_media_asset_id,
      row_version = horse.row_version + 1,
      updated_at = pg_catalog.clock_timestamp()
    where horse.id = p_horse_id
    returning * into after_horse;
    perform private.c003c_write_audit(
      'horse.updated', 'horse', p_horse_id, p_horse_id, actor_profile_id,
      p_request_id, 'HORSE_UPDATED', before_horse.status, after_horse.status,
      before_horse.row_version, after_horse.row_version,
      before_horse.access_version, after_horse.access_version,
      pg_catalog.jsonb_build_object(
        'changed_fields', array['profile_media_asset_id']::text[],
        'operation_code', 'set_canonical_horse_profile_media'
      )
    );
  end if;
  result := pg_catalog.jsonb_build_object(
    'horse_id', after_horse.id,
    'profile_media_asset_id', after_horse.profile_media_asset_id,
    'row_version', after_horse.row_version,
    'idempotent', before_horse.profile_media_asset_id is not distinct from p_media_asset_id
  );
  insert into private.media_mutation_receipts (
    actor_user_id, request_id, stable_id, operation_name, target_type,
    target_id, payload_hash, result
  ) values (
    actor_user_id, p_request_id, target_asset.stable_id,
    'set_canonical_horse_profile_media', 'media_asset', p_media_asset_id,
    payload_hash, result
  );
  return result;
end;
$$;

-- Append-only includes TRUNCATE. No client role has write privileges.
create trigger c0091_media_change_events_no_truncate
before truncate on public.media_change_events
for each statement execute function private.prevent_media_append_only_mutation();

revoke all on function private.c0091_guard_media_asset_scope()
  from public, anon, authenticated, service_role;
revoke all on function private.c0091_guard_media_variant_scope()
  from public, anon, authenticated, service_role;
revoke all on function private.c0091_profile_id_for_user(uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.c0091_actor_has_media_permission(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function private.c0091_require_media_permission(uuid, uuid, text)
  from public, anon, authenticated, service_role;

revoke all on function public.create_canonical_media_upload_session(uuid, text, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.get_canonical_media_upload_session(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.finalize_canonical_media_asset(
  uuid, uuid, bigint, text, bigint, text, text, bigint, text, uuid
) from public, anon, authenticated, service_role;
revoke all on function public.authorize_canonical_media_asset_download(uuid, uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.archive_canonical_media_asset(uuid, bigint, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.set_canonical_horse_profile_media(uuid, uuid, bigint, uuid)
  from public, anon, authenticated, service_role;

grant execute on function public.create_canonical_media_upload_session(uuid, text, text, uuid)
  to authenticated;
grant execute on function public.archive_canonical_media_asset(uuid, bigint, uuid)
  to authenticated;
grant execute on function public.set_canonical_horse_profile_media(uuid, uuid, bigint, uuid)
  to authenticated;
grant execute on function public.get_canonical_media_upload_session(uuid, uuid)
  to service_role;
grant execute on function public.finalize_canonical_media_asset(
  uuid, uuid, bigint, text, bigint, text, text, bigint, text, uuid
) to service_role;
grant execute on function public.authorize_canonical_media_asset_download(uuid, uuid, text)
  to service_role;

comment on function public.create_canonical_media_upload_session(uuid, text, text, uuid) is
  'Creates one idempotent private media upload for a canonical horse after horse.edit authorization; stable_id is compatibility-only.';
comment on function public.finalize_canonical_media_asset(
  uuid, uuid, bigint, text, bigint, text, text, bigint, text, uuid
) is
  'Service-only finalize after Edge byte validation, owner binding, horse.edit reauthorization and CAS.';
comment on function public.authorize_canonical_media_asset_download(uuid, uuid, text) is
  'Service-only private object coordinate after active-profile horse.view authorization.';
comment on function public.archive_canonical_media_asset(uuid, bigint, uuid) is
  'Soft-archives one unselected canonical horse asset with horse.edit, CAS and append-only audit.';
comment on function public.set_canonical_horse_profile_media(uuid, uuid, bigint, uuid) is
  'Selects or removes a ready same-canonical-horse image with horse.edit, CAS, idempotency and C-003C audit.';

commit;
