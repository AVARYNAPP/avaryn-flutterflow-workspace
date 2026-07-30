-- AVARYN Phase 5 Alpha: audited profile-photo selection.
--
-- The Horse core already reserved profile_media_asset_id and Phase 4C.5
-- already attached its same-horse foreign key. This migration only exposes
-- an idempotent, RLS-equivalent mutation contract for that existing field.

alter table public.horse_profile_change_events
  drop constraint horse_profile_change_events_changed_fields;

alter table public.horse_profile_change_events
  add constraint horse_profile_change_events_changed_fields
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
      'level',
      'profile_media_asset_id'
    ]::text[]
  );

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
    'level', p_horse.level,
    'profile_media_asset_id', p_horse.profile_media_asset_id
  )
$$;

create or replace function public.set_horse_profile_media(
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
  actor_id uuid := auth.uid();
  actor_membership public.stable_memberships%rowtype;
  before_row public.horses%rowtype;
  result public.horses%rowtype;
  target_asset public.media_assets%rowtype;
  replay_event public.horse_profile_change_events%rowtype;
begin
  if actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_horse_id is null
    or p_expected_row_version is null
    or p_expected_row_version < 1
    or p_request_id is null
  then
    raise exception using
      errcode = '22023',
      message = 'PROFILE_MEDIA_INPUT_INVALID';
  end if;

  select * into replay_event
  from public.horse_profile_change_events event
  where event.actor_user_id = actor_id
    and event.request_id = p_request_id;
  if replay_event.id is not null then
    if replay_event.horse_id <> p_horse_id
      or replay_event.changed_fields <> array['profile_media_asset_id']::text[]
      or replay_event.new_values ->> 'profile_media_asset_id'
        is distinct from p_media_asset_id::text
    then
      raise exception using
        errcode = '22023',
        message = 'REQUEST_ID_REUSED';
    end if;
    select * into result
    from public.horses horse
    where horse.id = replay_event.horse_id;
    return jsonb_build_object(
      'horse_id', result.id,
      'row_version', result.row_version,
      'profile_media_asset_id', result.profile_media_asset_id,
      'idempotent', true
    );
  end if;

  select * into before_row
  from public.horses horse
  where horse.id = p_horse_id
    and horse.status = 'active'
  for update;
  if before_row.id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  actor_membership := private.lock_media_context(
    before_row.stable_id,
    before_row.id
  );
  if not private.media_actor_has_capability(actor_id, before_row.id, 'edit') then
    raise exception using
      errcode = '42501',
      message = 'MEDIA_EDIT_REQUIRED';
  end if;
  if before_row.row_version <> p_expected_row_version then
    raise exception using
      errcode = '40001',
      message = 'ROW_VERSION_CONFLICT';
  end if;

  if p_media_asset_id is not null then
    select * into target_asset
    from public.media_assets asset
    where asset.id = p_media_asset_id
      and asset.stable_id = before_row.stable_id
      and asset.horse_id = before_row.id
      and asset.status = 'ready';
    if target_asset.id is null
      or target_asset.mime_type not in (
        'image/jpeg',
        'image/png',
        'image/webp'
      )
    then
      raise exception using
        errcode = '42501',
        message = 'PROFILE_MEDIA_UNAVAILABLE';
    end if;
  end if;

  if before_row.profile_media_asset_id is not distinct from p_media_asset_id then
    return jsonb_build_object(
      'horse_id', before_row.id,
      'row_version', before_row.row_version,
      'profile_media_asset_id', before_row.profile_media_asset_id,
      'idempotent', true
    );
  end if;

  update public.horses horse
  set profile_media_asset_id = p_media_asset_id
  where horse.id = before_row.id
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
    array['profile_media_asset_id']::text[],
    private.horse_profile_json(before_row),
    private.horse_profile_json(result)
  );

  return jsonb_build_object(
    'horse_id', result.id,
    'row_version', result.row_version,
    'profile_media_asset_id', result.profile_media_asset_id,
    'idempotent', false
  );
end;
$$;

revoke all on function public.set_horse_profile_media(
  uuid, uuid, bigint, uuid
) from public, anon;

grant execute on function public.set_horse_profile_media(
  uuid, uuid, bigint, uuid
) to authenticated;

comment on function public.set_horse_profile_media(uuid, uuid, bigint, uuid) is
  'Selects or removes one ready same-horse image as audited profile media.';
