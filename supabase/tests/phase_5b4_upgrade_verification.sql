begin;

do $$
declare
  capabilities jsonb;
  asset_id uuid;
  upload_session jsonb;
begin
  select asset.id into asset_id
  from public.media_assets asset
  where asset.horse_id = 'b54f0000-0000-0000-0000-000000000001'
    and asset.original_filename = 'preserved-before-5b4.jpg'
    and asset.expected_mime_type = 'image/jpeg'
    and asset.status = 'pending'
    and asset.created_request_id =
      'b5510000-0000-4000-8000-000000000001';
  if asset_id is null then
    raise exception 'Phase 5B.4 upgrade changed the existing media asset';
  end if;
  if (
    select count(*)
    from public.media_asset_variants variant
    where variant.media_asset_id = asset_id
      and variant.status = 'pending'
      and variant.variant in ('original', 'thumbnail')
  ) <> 2 or (
    select count(*)
    from public.media_links link
    where link.media_asset_id = asset_id
      and link.horse_id = 'b54f0000-0000-0000-0000-000000000001'
      and link.link_kind = 'horse'
      and link.archived_at is null
  ) <> 1 then
    raise exception 'Phase 5B.4 upgrade changed media variants or link';
  end if;

  upload_session := private.media_upload_session_result(asset_id, true);
  if upload_session ->> 'status' <> 'pending'
    or jsonb_array_length(upload_session -> 'variants') <> 2
  then
    raise exception 'Phase 5B.4 pending upload projection is incorrect: %',
      upload_session;
  end if;

  update public.media_asset_variants
  set
    status = 'ready',
    mime_type = expected_mime_type,
    byte_size = 1,
    sha256 = decode(repeat('00', 32), 'hex'),
    ready_at = timezone('utc', pg_catalog.now())
  where media_asset_id = asset_id;

  update public.media_assets
  set
    status = 'ready',
    mime_type = expected_mime_type,
    byte_size = 1,
    sha256 = decode(repeat('00', 32), 'hex'),
    ready_at = timezone('utc', pg_catalog.now())
  where id = asset_id;

  upload_session := private.media_upload_session_result(asset_id, true);
  if upload_session ->> 'status' <> 'ready'
    or upload_session ->> 'idempotent' <> 'true'
    or jsonb_array_length(upload_session -> 'variants') <> 0
  then
    raise exception 'Phase 5B.4 ready upload replay is incorrect: %',
      upload_session;
  end if;

  perform set_config(
    'request.jwt.claim.sub',
    'b54a0000-0000-0000-0000-000000000001',
    true
  );
  capabilities := public.get_horse_capabilities(
    'b54f0000-0000-0000-0000-000000000001'
  );
  if (capabilities ->> 'can_view_media')::boolean is not true
    or (capabilities ->> 'can_edit_media')::boolean is not true
    or (capabilities ->> 'can_manage_media_access')::boolean is not true
  then
    raise exception 'Phase 5B.4 owner media capabilities are incorrect: %',
      capabilities;
  end if;
end;
$$;

rollback;
