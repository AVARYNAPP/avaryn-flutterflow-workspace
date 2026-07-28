begin;

-- Recreate the exact pre-5B.4 projection so the upgrade proves that the new
-- migration, rather than prior local state, introduces the ready replay.
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

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000000',
  'b54a0000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'phase5b4-upgrade-owner@example.invalid',
  '',
  '2026-07-28T11:00:00Z',
  '{}',
  '{}',
  '2026-07-28T11:00:00Z',
  '2026-07-28T11:00:00Z'
);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values (
  'b54b0000-0000-0000-0000-000000000001',
  'organization',
  'Phase 5B.4 upgrade preservation',
  'active',
  'Europe/Amsterdam',
  'nl',
  'b54a0000-0000-0000-0000-000000000001',
  'b54c0000-0000-0000-0000-000000000001'
);

insert into public.stable_members (
  id, stable_id, display_name, source
)
values (
  'b54d0000-0000-0000-0000-000000000001',
  'b54b0000-0000-0000-0000-000000000001',
  'Phase 5B.4 upgrade owner',
  'owner_creation'
);

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values (
  'b54e0000-0000-0000-0000-000000000001',
  'b54b0000-0000-0000-0000-000000000001',
  'b54a0000-0000-0000-0000-000000000001',
  'b54d0000-0000-0000-0000-000000000001',
  'owner',
  'active',
  '2026-07-28T11:00:00Z'
);

insert into public.horses (
  id, stable_id, display_name, source_kind,
  created_by_user_id, created_request_id
)
values (
  'b54f0000-0000-0000-0000-000000000001',
  'b54b0000-0000-0000-0000-000000000001',
  'Phase 5B.4 preserved media Horse',
  'manual',
  'b54a0000-0000-0000-0000-000000000001',
  'b5500000-0000-0000-0000-000000000001'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b54a0000-0000-0000-0000-000000000001',
  true
);
do $$
begin
  perform public.create_media_upload_session(
    'b54f0000-0000-0000-0000-000000000001',
    null,
    'preserved-before-5b4.jpg',
    'image/jpeg',
    'b5510000-0000-4000-8000-000000000001'
  );
end;
$$;
reset role;

commit;
