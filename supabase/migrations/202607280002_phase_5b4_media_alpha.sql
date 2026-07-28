begin;

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
      when asset.status = 'ready'
        and bool_and(variant.status = 'ready')
      then 'ready'
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
      ) filter (
        where asset.status = 'pending'
          and variant.status = 'pending'
      ),
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

comment on function private.media_upload_session_result(uuid, boolean) is
  'Projects an upload session as pending, ready, or closed so exact retries can acknowledge a completed finalize without issuing fresh credentials.';

create or replace function public.get_horse_capabilities(
  p_horse_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_horse public.horses%rowtype;
  actor_membership public.stable_memberships%rowtype;
begin
  if actor_id is null then
    raise exception using
      errcode = '42501',
      message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_horse_id is null then
    raise exception using
      errcode = '22023',
      message = 'HORSE_ID_REQUIRED';
  end if;

  select h.* into target_horse
  from public.horses h
  join public.stables s on s.id = h.stable_id
  where h.id = p_horse_id
    and h.status = 'active'
    and s.status = 'active';
  if target_horse.id is null then
    raise exception using
      errcode = '42501',
      message = 'HORSE_UNAVAILABLE';
  end if;

  select m.* into actor_membership
  from public.stable_memberships m
  where m.stable_id = target_horse.stable_id
    and m.user_id = actor_id
    and m.status = 'active';
  if actor_membership.id is null
    or not private.has_horse_capability(
      target_horse.id,
      'horse.basic',
      'view'
    )
  then
    raise exception using
      errcode = '42501',
      message = 'HORSE_UNAVAILABLE';
  end if;

  return jsonb_build_object(
    'horse_id', target_horse.id,
    'stable_id', target_horse.stable_id,
    'membership_id', actor_membership.id,
    'role', actor_membership.role,
    'can_edit_profile', private.has_horse_capability(
      target_horse.id,
      'horse.basic',
      'edit'
    ),
    'can_archive', actor_membership.role in ('owner', 'admin'),
    'can_manage_basic_access', private.can_manage_horse_grants(
      target_horse.id,
      'horse.basic'
    ),
    'can_manage_schedule_access', private.can_manage_horse_grants(
      target_horse.id,
      'horse.schedule'
    ),
    'can_view_media', private.media_actor_has_capability(
      actor_id,
      target_horse.id,
      'view'
    ),
    'can_edit_media', private.media_actor_has_capability(
      actor_id,
      target_horse.id,
      'edit'
    ),
    'can_manage_media_access', private.can_manage_horse_grants(
      target_horse.id,
      'horse.media'
    ),
    'can_manage_relationships',
      actor_membership.role in ('owner', 'admin')
  );
end;
$$;

revoke execute on function public.get_horse_capabilities(uuid)
  from public, anon;
grant execute on function public.get_horse_capabilities(uuid)
  to authenticated;

comment on function public.get_horse_capabilities(uuid) is
  'Returns only the authenticated actor capabilities for one already-visible active Horse, including private-media display guidance; it never grants authority.';

commit;
