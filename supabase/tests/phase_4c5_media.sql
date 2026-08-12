begin;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
select
  '00000000-0000-0000-0000-000000000000',
  fixture.id::uuid,
  'authenticated',
  'authenticated',
  fixture.email,
  '',
  now(),
  '{}',
  '{}',
  now(),
  now()
from (
  values
    ('4c510000-0000-0000-0000-000000000001', 'media-owner@example.invalid'),
    ('4c510000-0000-0000-0000-000000000002', 'media-admin@example.invalid'),
    ('4c510000-0000-0000-0000-000000000003', 'media-editor@example.invalid'),
    ('4c510000-0000-0000-0000-000000000004', 'media-viewer@example.invalid'),
    ('4c510000-0000-0000-0000-000000000005', 'media-outsider@example.invalid'),
    ('4c510000-0000-0000-0000-000000000006', 'media-owner-b@example.invalid')
) as fixture(id, email);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values
  (
    '4c520000-0000-0000-0000-000000000001',
    'organization', 'Media stable A', 'active', 'Europe/Amsterdam', 'nl',
    '4c510000-0000-0000-0000-000000000001',
    '4c520000-0000-0000-0000-000000000011'
  ),
  (
    '4c520000-0000-0000-0000-000000000002',
    'organization', 'Media stable B', 'active', 'UTC', 'en',
    '4c510000-0000-0000-0000-000000000006',
    '4c520000-0000-0000-0000-000000000012'
  );

insert into public.stable_members (
  id, stable_id, display_name, source
)
values
  ('4c530000-0000-0000-0000-000000000001', '4c520000-0000-0000-0000-000000000001', 'Media Owner', 'owner_creation'),
  ('4c530000-0000-0000-0000-000000000002', '4c520000-0000-0000-0000-000000000001', 'Media Admin', 'manual'),
  ('4c530000-0000-0000-0000-000000000003', '4c520000-0000-0000-0000-000000000001', 'Media Editor', 'manual'),
  ('4c530000-0000-0000-0000-000000000004', '4c520000-0000-0000-0000-000000000001', 'Media Viewer', 'manual'),
  ('4c530000-0000-0000-0000-000000000005', '4c520000-0000-0000-0000-000000000001', 'Media Outsider', 'manual'),
  ('4c530000-0000-0000-0000-000000000006', '4c520000-0000-0000-0000-000000000002', 'Media Owner B', 'owner_creation');

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values
  ('4c540000-0000-0000-0000-000000000001', '4c520000-0000-0000-0000-000000000001', '4c510000-0000-0000-0000-000000000001', '4c530000-0000-0000-0000-000000000001', 'owner', 'active', now()),
  ('4c540000-0000-0000-0000-000000000002', '4c520000-0000-0000-0000-000000000001', '4c510000-0000-0000-0000-000000000002', '4c530000-0000-0000-0000-000000000002', 'admin', 'active', now()),
  ('4c540000-0000-0000-0000-000000000003', '4c520000-0000-0000-0000-000000000001', '4c510000-0000-0000-0000-000000000003', '4c530000-0000-0000-0000-000000000003', 'member', 'active', now()),
  ('4c540000-0000-0000-0000-000000000004', '4c520000-0000-0000-0000-000000000001', '4c510000-0000-0000-0000-000000000004', '4c530000-0000-0000-0000-000000000004', 'viewer', 'active', now()),
  ('4c540000-0000-0000-0000-000000000005', '4c520000-0000-0000-0000-000000000001', '4c510000-0000-0000-0000-000000000005', '4c530000-0000-0000-0000-000000000005', 'viewer', 'active', now()),
  ('4c540000-0000-0000-0000-000000000006', '4c520000-0000-0000-0000-000000000002', '4c510000-0000-0000-0000-000000000006', '4c530000-0000-0000-0000-000000000006', 'owner', 'active', now());

set constraints all immediate;

insert into public.horses (
  id, stable_id, display_name, source_kind,
  created_by_user_id, created_request_id
)
values
  ('4c550000-0000-0000-0000-000000000001', '4c520000-0000-0000-0000-000000000001', 'Media Horse A', 'manual', '4c510000-0000-0000-0000-000000000001', '4c550000-0000-0000-0000-000000000011'),
  ('4c550000-0000-0000-0000-000000000002', '4c520000-0000-0000-0000-000000000001', 'Other Horse A', 'manual', '4c510000-0000-0000-0000-000000000001', '4c550000-0000-0000-0000-000000000012'),
  ('4c550000-0000-0000-0000-000000000003', '4c520000-0000-0000-0000-000000000002', 'Media Horse B', 'manual', '4c510000-0000-0000-0000-000000000006', '4c550000-0000-0000-0000-000000000013');

insert into public.horse_access_grants (
  stable_id, horse_id, membership_id, category,
  can_view, can_execute, can_edit, can_manage,
  granted_by_user_id, granted_request_id, grant_reason
)
values
  (
    '4c520000-0000-0000-0000-000000000001',
    '4c550000-0000-0000-0000-000000000001',
    '4c540000-0000-0000-0000-000000000003',
    'horse.media', true, false, true, false,
    '4c510000-0000-0000-0000-000000000001',
    '4c560000-0000-0000-0000-000000000001',
    'Media editor regression fixture'
  ),
  (
    '4c520000-0000-0000-0000-000000000001',
    '4c550000-0000-0000-0000-000000000001',
    '4c540000-0000-0000-0000-000000000004',
    'horse.media', true, false, false, false,
    '4c510000-0000-0000-0000-000000000001',
    '4c560000-0000-0000-0000-000000000002',
    'Media viewer regression fixture'
  );

-- C-009.1 moves media authority to the canonical C-003C permission model.
-- Keep the historical stable-scoped graph, but make editor/viewer authority
-- explicit on the canonical horse instead of deriving it from membership.
insert into public.horse_delegated_administrators (
  id, horse_id, profile_id, granted_by_profile_id, permission_codes,
  valid_from, creation_correlation_id
)
select
  '4c560000-0000-0000-0000-000000000011'::uuid,
  '4c550000-0000-0000-0000-000000000001'::uuid,
  editor.id, owner_profile.id, array['horse.view','horse.edit']::text[],
  statement_timestamp(), '4c560000-0000-0000-0000-000000000021'::uuid
from public.profiles editor
cross join public.profiles owner_profile
where editor.auth_user_id = '4c510000-0000-0000-0000-000000000003'
  and owner_profile.auth_user_id = '4c510000-0000-0000-0000-000000000001'
union all
select
  '4c560000-0000-0000-0000-000000000012'::uuid,
  '4c550000-0000-0000-0000-000000000001'::uuid,
  viewer.id, owner_profile.id, array['horse.view']::text[],
  statement_timestamp(), '4c560000-0000-0000-0000-000000000022'::uuid
from public.profiles viewer
cross join public.profiles owner_profile
where viewer.auth_user_id = '4c510000-0000-0000-0000-000000000004'
  and owner_profile.auth_user_id = '4c510000-0000-0000-0000-000000000001';

do $$
declare
  relation_name text;
begin
  if not exists (
    select 1 from storage.buckets
    where id = 'horse-media'
      and public is false
      and file_size_limit = 20971520
      and allowed_mime_types @> array[
        'image/jpeg', 'image/png', 'image/webp', 'application/pdf'
      ]::text[]
  ) then
    raise exception '4C.5 private bucket contract missing';
  end if;
  foreach relation_name in array array[
    'media_assets',
    'media_asset_variants',
    'media_links',
    'media_change_events'
  ] loop
    if not (
      select class.relrowsecurity
      from pg_class class
      where class.oid = ('public.' || relation_name)::regclass
    ) or has_table_privilege(
      'authenticated', 'public.' || relation_name, 'INSERT'
    ) or has_table_privilege(
      'authenticated', 'public.' || relation_name, 'UPDATE'
    ) or has_table_privilege(
      'authenticated', 'public.' || relation_name, 'DELETE'
    ) then
      raise exception '4C.5 RLS/direct-DML incorrect for %', relation_name;
    end if;
  end loop;
  if has_function_privilege(
    'authenticated',
    'public.finalize_media_asset(uuid,uuid,bigint,text,bigint,text,text,bigint,text,uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'public.authorize_media_asset_download(uuid,uuid,text)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'public.get_media_upload_session(uuid,uuid)',
    'EXECUTE'
  ) then
    raise exception '4C.5 service-only RPC exposed to authenticated';
  end if;
end;
$$;

create temp table phase_4c5_results (
  name text primary key,
  value jsonb not null
) on commit drop;
grant select, insert, update on phase_4c5_results
  to authenticated, service_role;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '4c510000-0000-0000-0000-000000000001',
  true
);

insert into phase_4c5_results
values (
  'owner_png',
  public.create_media_upload_session(
    '4c550000-0000-0000-0000-000000000001',
    null,
    '../unsafe/<portrait>.png',
    'image/png',
    '4c570000-0000-0000-0000-000000000001'
  )
);

do $$
declare
  first_result jsonb;
  retry_result jsonb;
  asset_id uuid;
  expected_prefix text :=
    '4c520000-0000-0000-0000-000000000001/'
    || '4c550000-0000-0000-0000-000000000001/';
begin
  select value into first_result
  from phase_4c5_results where name = 'owner_png';
  asset_id := (first_result->>'media_asset_id')::uuid;
  if jsonb_array_length(first_result->'variants') <> 2
    or not exists (
      select 1
      from jsonb_array_elements(first_result->'variants') variant
      where variant->>'variant' = 'original'
        and variant->>'object_path' =
          expected_prefix || asset_id::text || '/original'
    )
    or not exists (
      select 1
      from jsonb_array_elements(first_result->'variants') variant
      where variant->>'variant' = 'thumbnail'
        and variant->>'object_path' =
          expected_prefix || asset_id::text || '/thumbnail'
    )
  then
    raise exception '4C.5 server path or image variants incorrect';
  end if;
  if (
    select original_filename
    from public.media_assets
    where id = asset_id
  ) <> '_portrait_.png' then
    raise exception '4C.5 filename was not sanitized';
  end if;
  retry_result := public.create_media_upload_session(
    '4c550000-0000-0000-0000-000000000001',
    null,
    '../unsafe/<portrait>.png',
    'image/png',
    '4c570000-0000-0000-0000-000000000001'
  );
  if retry_result->>'media_asset_id' <> asset_id::text
    or (retry_result->>'idempotent')::boolean is not true
  then
    raise exception '4C.5 create exact retry failed';
  end if;
  begin
    perform public.create_media_upload_session(
      '4c550000-0000-0000-0000-000000000001',
      null,
      'other.pdf',
      'application/pdf',
      '4c570000-0000-0000-0000-000000000001'
    );
    raise exception '4C.5 reused request accepted different payload';
  exception when invalid_parameter_value then null;
  end;
end;
$$;

do $$
begin
  if (select count(*) from public.media_assets) <> 0 then
    raise exception '4C.5 pending asset became readable';
  end if;
  begin
    insert into storage.objects (bucket_id, name)
    values ('horse-media', 'client/chosen/path');
    raise exception '4C.5 direct client storage insert succeeded';
  exception
    when insufficient_privilege or sqlstate '42501' then null;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c510000-0000-0000-0000-000000000002',
  true
);
do $$
begin
  begin
    perform public.create_media_upload_session(
      '4c550000-0000-0000-0000-000000000001',
      null,
      'admin-without-explicit-grant.png',
      'image/png',
      '4c570000-0000-0000-0000-000000000002'
    );
    raise exception '4C.5 admin received implicit media edit';
  exception when insufficient_privilege then null;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c510000-0000-0000-0000-000000000003',
  true
);
insert into phase_4c5_results
values (
  'editor_pdf',
  public.create_media_upload_session(
    '4c550000-0000-0000-0000-000000000001',
    null,
    'vet-report.pdf',
    'application/pdf',
    '4c570000-0000-0000-0000-000000000003'
  )
);
do $$
begin
  if jsonb_array_length(
    (select value->'variants' from phase_4c5_results where name = 'editor_pdf')
  ) <> 1 then
    raise exception '4C.5 PDF unexpectedly received thumbnail';
  end if;
end;
$$;

reset role;
insert into storage.objects (bucket_id, name, metadata)
select
  variant.bucket_id,
  variant.object_path,
  jsonb_build_object('mimetype', variant.expected_mime_type)
from public.media_asset_variants variant
where variant.media_asset_id = (
  select (value->>'media_asset_id')::uuid
  from phase_4c5_results where name = 'owner_png'
);

set local role service_role;
do $$
declare
  finalized jsonb;
  asset_id uuid := (
    select (value->>'media_asset_id')::uuid
    from phase_4c5_results where name = 'owner_png'
  );
begin
  begin
    perform public.finalize_media_asset(
      '4c510000-0000-0000-0000-000000000001',
      asset_id,
      1,
      'image/jpeg',
      128,
      repeat('ab', 32),
      'image/png',
      64,
      repeat('cd', 32),
      '4c580000-0000-0000-0000-000000000001'
    );
    raise exception '4C.5 finalize accepted MIME mismatch';
  exception when invalid_parameter_value then null;
  end;
  if (select status from public.media_assets where id = asset_id) <> 'pending' then
    raise exception '4C.5 rejected finalize mutated asset';
  end if;
  finalized := public.finalize_media_asset(
    '4c510000-0000-0000-0000-000000000001',
    asset_id,
    1,
    'image/png',
    128,
    repeat('ab', 32),
    'image/png',
    64,
    repeat('cd', 32),
    '4c580000-0000-0000-0000-000000000002'
  );
  if finalized->>'status' <> 'ready'
    or (finalized->>'row_version')::bigint <> 2
  then
    raise exception '4C.5 valid finalize failed';
  end if;
  finalized := public.finalize_media_asset(
    '4c510000-0000-0000-0000-000000000001',
    asset_id,
    1,
    'image/png',
    128,
    repeat('ab', 32),
    'image/png',
    64,
    repeat('cd', 32),
    '4c580000-0000-0000-0000-000000000002'
  );
  if (finalized->>'idempotent')::boolean is not true then
    raise exception '4C.5 finalize exact retry failed';
  end if;
end;
$$;

reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '4c510000-0000-0000-0000-000000000001',
  true
);
do $$
declare asset_id uuid := (
  select (value->>'media_asset_id')::uuid
  from phase_4c5_results where name = 'owner_png'
);
begin
  if (select count(*) from public.media_assets where id = asset_id) <> 1
    or (
      select count(*) from public.media_asset_variants
      where media_asset_id = asset_id
    ) <> 2
    or (
      select count(*) from public.media_links
      where media_asset_id = asset_id
    ) <> 1
  then
    raise exception '4C.5 owner cannot read ready media graph';
  end if;
  begin
    perform public.finalize_media_asset(
      '4c510000-0000-0000-0000-000000000001',
      asset_id, 2, 'image/png', 1, repeat('aa', 32),
      'image/png', 1, repeat('bb', 32), gen_random_uuid()
    );
    raise exception '4C.5 authenticated called service finalize';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.get_media_upload_session(
      '4c510000-0000-0000-0000-000000000001',
      asset_id
    );
    raise exception '4C.5 authenticated called service upload coordinates';
  exception when insufficient_privilege then null;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c510000-0000-0000-0000-000000000004',
  true
);
do $$
declare asset_id uuid := (
  select (value->>'media_asset_id')::uuid
  from phase_4c5_results where name = 'owner_png'
);
begin
  if (select count(*) from public.media_assets where id = asset_id) <> 1 then
    raise exception '4C.5 explicit media viewer cannot read ready asset';
  end if;
  begin
    perform public.archive_media_asset(
      asset_id, 2, '4c590000-0000-0000-0000-000000000001'
    );
    raise exception '4C.5 media viewer archived asset';
  exception when insufficient_privilege then null;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c510000-0000-0000-0000-000000000002',
  true
);
do $$
declare asset_id uuid := (
  select (value->>'media_asset_id')::uuid
  from phase_4c5_results where name = 'owner_png'
);
begin
  if (select count(*) from public.media_assets where id = asset_id) <> 0 then
    raise exception '4C.5 admin without explicit grant read media';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c510000-0000-0000-0000-000000000001',
  true
);
insert into phase_4c5_results
select
  'archive',
  public.archive_media_asset(
    (select (value->>'media_asset_id')::uuid
     from phase_4c5_results where name = 'owner_png'),
    2,
    '4c590000-0000-0000-0000-000000000002'
  );

do $$
declare asset_id uuid := (
  select (value->>'media_asset_id')::uuid
  from phase_4c5_results where name = 'owner_png'
);
begin
  if (select count(*) from public.media_assets where id = asset_id) <> 0 then
    raise exception '4C.5 archived asset remained readable';
  end if;
end;
$$;

reset role;
do $$
declare asset_id uuid := (
  select (value->>'media_asset_id')::uuid
  from phase_4c5_results where name = 'owner_png'
);
begin
  if (select status from public.media_assets where id = asset_id) <> 'archived'
    or exists (
      select 1 from public.media_asset_variants
      where media_asset_id = asset_id and status <> 'archived'
    )
    or exists (
      select 1 from public.media_links
      where media_asset_id = asset_id and archived_at is null
    )
  then
    raise exception '4C.5 soft archive lifecycle incomplete';
  end if;
  if exists (
    select 1
    from private.media_mutation_receipts receipt
    where receipt.result ?| array[
      'object_path', 'signed_url', 'upload_token', 'filename', 'sha256'
    ]
  ) then
    raise exception '4C.5 receipt persisted sensitive transport metadata';
  end if;
  if exists (
    select 1
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'media_change_events'
      and column_row.column_name in (
        'object_path', 'signed_url', 'upload_token',
        'original_filename', 'sha256'
      )
  ) then
    raise exception '4C.5 audit schema contains sensitive transport metadata';
  end if;
  begin
    update public.horses
    set profile_media_asset_id = asset_id
    where id = '4c550000-0000-0000-0000-000000000002';
    raise exception '4C.5 cross-Horse profile media assignment succeeded';
  exception when foreign_key_violation then null;
  end;
end;
$$;

do $$
begin
  update public.horse_access_grants
  set
    status = 'revoked',
    revoked_by_user_id = '4c510000-0000-0000-0000-000000000001',
    revoked_request_id = '4c5e0000-0000-0000-0000-000000000001',
    revoked_at = timezone('utc', now())
  where horse_id = '4c550000-0000-0000-0000-000000000001'
    and membership_id = '4c540000-0000-0000-0000-000000000003'
    and category = 'horse.media';
  update public.horse_delegated_administrators
  set status = 'ended', valid_until = statement_timestamp(),
    ended_reason_code = 'C0091_PERMISSION_REVOKED', row_version = row_version + 1,
    updated_at = clock_timestamp()
  where id = '4c560000-0000-0000-0000-000000000011';
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '4c510000-0000-0000-0000-000000000003',
  true
);
do $$
begin
  begin
    perform public.create_media_upload_session(
      '4c550000-0000-0000-0000-000000000001',
      null,
      'vet-report.pdf',
      'application/pdf',
      '4c570000-0000-0000-0000-000000000003'
    );
    raise exception '4C.5 revoked grant reopened exact upload retry';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
insert into public.schedule_items (
  id, stable_id, horse_id, item_kind, data_category, title, instruction,
  priority, scheduled_start_at, scheduled_end_at, source_timezone,
  source_local_date, source_local_time, state, terminal_at,
  created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c5e1000-0000-0000-0000-000000000001',
  '4c520000-0000-0000-0000-000000000001',
  '4c550000-0000-0000-0000-000000000001',
  'task', 'horse.schedule', 'Execution-only proof',
  'A minimally authorized execution actor may see only this proof.',
  'normal', now() - interval '30 minutes', now(), 'Europe/Amsterdam',
  current_date, localtime(0), 'completed', now(),
  '4c510000-0000-0000-0000-000000000001',
  '4c5e1000-0000-0000-0000-000000000011',
  '4c510000-0000-0000-0000-000000000001',
  '4c5e1000-0000-0000-0000-000000000011'
);

insert into public.schedule_executions (
  id, stable_id, schedule_item_id, actor_user_id,
  actor_membership_id, actor_stable_member_id, execution_status,
  actual_started_at, actual_completed_at, recorded_local_at,
  recorded_timezone, source, request_id
)
values (
  '4c5e2000-0000-0000-0000-000000000001',
  '4c520000-0000-0000-0000-000000000001',
  '4c5e1000-0000-0000-0000-000000000001',
  '4c510000-0000-0000-0000-000000000005',
  '4c540000-0000-0000-0000-000000000005',
  '4c530000-0000-0000-0000-000000000005',
  'completed', now() - interval '20 minutes', now(),
  localtimestamp(0), 'Europe/Amsterdam', 'online',
  '4c5e2000-0000-0000-0000-000000000011'
);

insert into public.media_assets (
  id, stable_id, horse_id, status, original_filename,
  expected_mime_type, max_byte_size, mime_type, byte_size, sha256,
  uploaded_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id, ready_at
)
values (
  '4c5e3000-0000-0000-0000-000000000001',
  '4c520000-0000-0000-0000-000000000001',
  '4c550000-0000-0000-0000-000000000001',
  'ready', 'execution.png', 'image/png', 10485760,
  'image/png', 128, decode(repeat('ab', 32), 'hex'),
  '4c510000-0000-0000-0000-000000000005',
  '4c5e3000-0000-0000-0000-000000000011',
  '4c510000-0000-0000-0000-000000000005',
  '4c5e3000-0000-0000-0000-000000000011',
  now()
);

insert into public.media_asset_variants (
  stable_id, media_asset_id, variant, status, object_path,
  expected_mime_type, max_byte_size, mime_type, byte_size, sha256, ready_at
)
values
  (
    '4c520000-0000-0000-0000-000000000001',
    '4c5e3000-0000-0000-0000-000000000001',
    'original', 'ready',
    '4c520000-0000-0000-0000-000000000001/4c550000-0000-0000-0000-000000000001/4c5e3000-0000-0000-0000-000000000001/original',
    'image/png', 10485760, 'image/png', 128,
    decode(repeat('ab', 32), 'hex'), now()
  ),
  (
    '4c520000-0000-0000-0000-000000000001',
    '4c5e3000-0000-0000-0000-000000000001',
    'thumbnail', 'ready',
    '4c520000-0000-0000-0000-000000000001/4c550000-0000-0000-0000-000000000001/4c5e3000-0000-0000-0000-000000000001/thumbnail',
    'image/png', 1048576, 'image/png', 64,
    decode(repeat('cd', 32), 'hex'), now()
  );

insert into public.media_links (
  id, stable_id, media_asset_id, schedule_execution_id, link_kind,
  created_by_user_id, created_request_id
)
values (
  '4c5e4000-0000-0000-0000-000000000001',
  '4c520000-0000-0000-0000-000000000001',
  '4c5e3000-0000-0000-0000-000000000001',
  '4c5e2000-0000-0000-0000-000000000001',
  'schedule_execution',
  '4c510000-0000-0000-0000-000000000001',
  '4c5e4000-0000-0000-0000-000000000011'
);
insert into public.media_links (
  id, stable_id, media_asset_id, horse_id, link_kind,
  created_by_user_id, created_request_id
)
values (
  '4c5e4000-0000-0000-0000-000000000002',
  '4c520000-0000-0000-0000-000000000001',
  '4c5e3000-0000-0000-0000-000000000001',
  '4c550000-0000-0000-0000-000000000001',
  'horse',
  '4c510000-0000-0000-0000-000000000001',
  '4c5e4000-0000-0000-0000-000000000012'
);
insert into public.media_change_events (
  stable_id, horse_id, media_asset_id, media_link_id,
  actor_user_id, actor_membership_id, request_id,
  event_type, row_version
)
values (
  '4c520000-0000-0000-0000-000000000001',
  '4c550000-0000-0000-0000-000000000001',
  '4c5e3000-0000-0000-0000-000000000001',
  '4c5e4000-0000-0000-0000-000000000001',
  '4c510000-0000-0000-0000-000000000001',
  '4c540000-0000-0000-0000-000000000001',
  '4c5e5000-0000-0000-0000-000000000001',
  'media_asset_linked', 1
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '4c510000-0000-0000-0000-000000000005',
  true
);
do $$
begin
  if (
    select count(*) from public.media_assets
    where id = '4c5e3000-0000-0000-0000-000000000001'
  ) <> 0 or (
    select count(*) from public.media_links
    where media_asset_id = '4c5e3000-0000-0000-0000-000000000001'
  ) <> 0 or exists (
    select 1 from public.media_links
    where id = '4c5e4000-0000-0000-0000-000000000001'
  ) or (
    select count(*) from public.media_change_events
    where media_asset_id = '4c5e3000-0000-0000-0000-000000000001'
  ) <> 0
  then
    raise exception '4C.5 execution assignment implied canonical media access';
  end if;
end;
$$;

reset role;
do $$
declare revoked_status text;
begin
  foreach revoked_status in array array['suspended', 'removed', 'left'] loop
    update public.stable_memberships
    set
      status = revoked_status,
      ended_at = timezone('utc', now()),
      ended_reason = '4C.5 ' || revoked_status || ' regression'
    where id = '4c540000-0000-0000-0000-000000000005';
    if private.media_actor_can_view_asset(
      '4c510000-0000-0000-0000-000000000005',
      '4c5e3000-0000-0000-0000-000000000001'
    ) then
      raise exception '4C.5 % execution actor retained media access', revoked_status;
    end if;
  end loop;
end;
$$;

update public.horses
set status = 'archived', archived_at = timezone('utc', now())
where id = '4c550000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '4c510000-0000-0000-0000-000000000001',
  true
);
do $$
begin
  begin
    perform public.create_media_upload_session(
      '4c550000-0000-0000-0000-000000000001',
      null,
      '../unsafe/<portrait>.png',
      'image/png',
      '4c570000-0000-0000-0000-000000000001'
    );
    raise exception '4C.5 archived Horse reopened exact upload retry';
  exception when insufficient_privilege then null;
  end;
end;
$$;

rollback;
