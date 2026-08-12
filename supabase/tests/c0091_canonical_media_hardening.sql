begin;

select extensions.plan(1);

create temporary table c0091_fixture (
  authority_user uuid not null,
  outsider_user uuid not null,
  authority_profile uuid,
  outsider_profile uuid,
  horse_id uuid,
  other_horse_id uuid,
  asset_id uuid,
  other_asset_id uuid,
  create_request uuid not null,
  select_request uuid not null
);
grant select, update on pg_temp.c0091_fixture to authenticated, service_role, anon;

insert into pg_temp.c0091_fixture(
  authority_user, outsider_user, create_request, select_request
) values (
  'c0910000-0000-4000-8000-000000000001',
  'c0910000-0000-4000-8000-000000000002',
  'c0911000-0000-4000-8000-000000000001',
  'c0911000-0000-4000-8000-000000000002'
);

insert into auth.users(
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select '00000000-0000-0000-0000-000000000000'::uuid, authority_user,
  'authenticated', 'authenticated', 'c0091-authority@example.invalid', '', now(),
  '{}'::jsonb, '{}'::jsonb, now(), now()
from pg_temp.c0091_fixture
union all
select '00000000-0000-0000-0000-000000000000'::uuid, outsider_user,
  'authenticated', 'authenticated', 'c0091-outsider@example.invalid', '', now(),
  '{}'::jsonb, '{"stable_id":"spoof","role":"owner"}'::jsonb, now(), now()
from pg_temp.c0091_fixture;

update pg_temp.c0091_fixture fixture set
  authority_profile = (
    select id from public.profiles where auth_user_id = fixture.authority_user
  ),
  outsider_profile = (
    select id from public.profiles where auth_user_id = fixture.outsider_user
  );

-- Anonymous and service roles never receive the authenticated mutation API.
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'anon', true);
set local role anon;
do $$
begin
  begin
    perform public.create_canonical_media_upload_session(
      gen_random_uuid(), 'attack.jpg', 'image/jpeg', gen_random_uuid()
    );
    raise exception 'anon created canonical media';
  exception when insufficient_privilege then null; end;
  begin
    perform public.set_canonical_horse_profile_media(
      gen_random_uuid(), null, 1, gen_random_uuid()
    );
    raise exception 'anon selected canonical media';
  exception when insufficient_privilege then null; end;
end;
$$;
reset role;

select set_config('request.jwt.claim.role', 'service_role', true);
set local role service_role;
do $$
begin
  begin
    perform private.c0091_actor_has_media_permission(
      gen_random_uuid(), gen_random_uuid(), 'horse.view'
    );
    raise exception 'service role executed private C-009.1 helper';
  exception when insufficient_privilege then null; end;
  begin
    perform public.create_canonical_media_upload_session(
      gen_random_uuid(), 'attack.jpg', 'image/jpeg', gen_random_uuid()
    );
    raise exception 'service role created canonical media';
  exception when insufficient_privilege then null; end;
end;
$$;
reset role;

-- Each identity creates one standalone canonical horse. No stable, membership,
-- link or residency is needed and none of those can grant access.
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  (select authority_user::text from pg_temp.c0091_fixture),
  true
);
set local role authenticated;
with created as (
  select * from public.create_canonical_horse_profile(
    'C-009.1 Nova', null, null, 'unknown', null, null, null, null, null,
    null, null, null, 'c0912000-0000-4000-8000-000000000001'
  )
) update pg_temp.c0091_fixture fixture set horse_id = created.horse_id
from created;

with created as (
  select public.create_canonical_media_upload_session(
    (select horse_id from pg_temp.c0091_fixture),
    '../Nova portrait.jpg', 'image/jpeg',
    (select create_request from pg_temp.c0091_fixture)
  ) as result
) update pg_temp.c0091_fixture fixture
set asset_id = (created.result->>'media_asset_id')::uuid
from created;

do $$
declare
  first_result jsonb;
  replay_result jsonb;
begin
  first_result := public.create_canonical_media_upload_session(
    (select horse_id from pg_temp.c0091_fixture),
    '../Nova portrait.jpg', 'image/jpeg',
    (select create_request from pg_temp.c0091_fixture)
  );
  replay_result := public.create_canonical_media_upload_session(
    (select horse_id from pg_temp.c0091_fixture),
    '../Nova portrait.jpg', 'image/jpeg',
    (select create_request from pg_temp.c0091_fixture)
  );
  if first_result->>'media_asset_id' <> replay_result->>'media_asset_id'
    or (replay_result->>'idempotent')::boolean is not true
  then raise exception 'canonical upload idempotency failed'; end if;
  begin
    perform public.create_canonical_media_upload_session(
      (select horse_id from pg_temp.c0091_fixture),
      'changed.png', 'image/png',
      (select create_request from pg_temp.c0091_fixture)
    );
    raise exception 'request id payload reuse succeeded';
  exception when invalid_parameter_value then null; end;
end;
$$;
reset role;

do $$
begin
  if (select count(*) from public.media_assets
      where horse_id = (select horse_id from pg_temp.c0091_fixture)) <> 1
  then raise exception 'canonical upload created duplicate assets'; end if;
  if (select stable_id from public.media_assets
      where id = (select asset_id from pg_temp.c0091_fixture)) is not null
  then raise exception 'canonical upload fabricated legacy stable context'; end if;
  if exists (
    select 1 from public.media_asset_variants
    where media_asset_id = (select asset_id from pg_temp.c0091_fixture)
      and object_path not like 'canonical/%'
  ) then raise exception 'canonical upload object path was not canonical'; end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  (select outsider_user::text from pg_temp.c0091_fixture),
  true
);
set local role authenticated;
with created as (
  select * from public.create_canonical_horse_profile(
    'C-009.1 Other', null, null, 'unknown', null, null, null, null, null,
    null, null, null, 'c0912000-0000-4000-8000-000000000002'
  )
) update pg_temp.c0091_fixture fixture set other_horse_id = created.horse_id
from created;

with created as (
  select public.create_canonical_media_upload_session(
    (select other_horse_id from pg_temp.c0091_fixture),
    'other.png', 'image/png', 'c0912000-0000-4000-8000-000000000003'
  ) as result
) update pg_temp.c0091_fixture fixture
set other_asset_id = (created.result->>'media_asset_id')::uuid
from created;

do $$
begin
  begin
    perform public.create_canonical_media_upload_session(
      (select horse_id from pg_temp.c0091_fixture),
      'cross-horse.jpg', 'image/jpeg', gen_random_uuid()
    );
    raise exception 'outsider created media for another horse';
  exception when insufficient_privilege then null; end;
  if exists (
    select 1 from public.media_assets
    where id = (select asset_id from pg_temp.c0091_fixture)
  ) then
    raise exception 'RLS leaked another horse media asset';
  end if;
  begin
    perform public.authorize_canonical_media_asset_download(
      (select outsider_user from pg_temp.c0091_fixture),
      (select asset_id from pg_temp.c0091_fixture), 'original'
    );
    raise exception 'authenticated executed service-only download resolver';
  exception when insufficient_privilege then null; end;
end;
$$;
reset role;

-- Simulate Edge's already byte-verified ready transition without persisting
-- an object in this rolled-back SQL matrix. The Edge content verifier remains
-- covered by the existing Phase 4C.5 integration suite.
update public.media_asset_variants set
  status = 'ready', mime_type = expected_mime_type, byte_size = 128,
  sha256 = decode(repeat('00', 32), 'hex'), ready_at = statement_timestamp()
where media_asset_id in (
  (select asset_id from pg_temp.c0091_fixture),
  (select other_asset_id from pg_temp.c0091_fixture)
);
update public.media_assets set
  status = 'ready', mime_type = expected_mime_type, byte_size = 128,
  sha256 = decode(repeat('00', 32), 'hex'), ready_at = statement_timestamp()
where id in (
  (select asset_id from pg_temp.c0091_fixture),
  (select other_asset_id from pg_temp.c0091_fixture)
);

select set_config(
  'request.jwt.claim.sub',
  (select authority_user::text from pg_temp.c0091_fixture),
  true
);
set local role authenticated;
do $$
declare
  horse_version bigint;
  selected jsonb;
  replay jsonb;
begin
  select row_version into horse_version
  from public.canonical_horses
  where id = (select horse_id from pg_temp.c0091_fixture);
  selected := public.set_canonical_horse_profile_media(
    (select horse_id from pg_temp.c0091_fixture),
    (select asset_id from pg_temp.c0091_fixture), horse_version,
    (select select_request from pg_temp.c0091_fixture)
  );
  replay := public.set_canonical_horse_profile_media(
    (select horse_id from pg_temp.c0091_fixture),
    (select asset_id from pg_temp.c0091_fixture), horse_version,
    (select select_request from pg_temp.c0091_fixture)
  );
  if selected->>'horse_id' <> (select horse_id::text from pg_temp.c0091_fixture)
    or replay->>'horse_id' <> selected->>'horse_id'
    or (select profile_media_asset_id from public.canonical_horses
      where id = (select horse_id from pg_temp.c0091_fixture))
      <> (select asset_id from pg_temp.c0091_fixture)
  then
    raise exception 'same-horse selection or idempotency failed';
  end if;
  begin
    perform public.set_canonical_horse_profile_media(
      (select horse_id from pg_temp.c0091_fixture),
      (select other_asset_id from pg_temp.c0091_fixture),
      (selected->>'row_version')::bigint, gen_random_uuid()
    );
    raise exception 'cross-horse profile media selection succeeded';
  exception when insufficient_privilege then null; end;
  begin
    perform public.set_canonical_horse_profile_media(
      (select horse_id from pg_temp.c0091_fixture), null,
      horse_version, gen_random_uuid()
    );
    raise exception 'stale profile media writer succeeded';
  exception when serialization_failure then null; end;
  begin
    perform public.archive_canonical_media_asset(
      (select asset_id from pg_temp.c0091_fixture),
      (select row_version from public.media_assets
        where id = (select asset_id from pg_temp.c0091_fixture)),
      gen_random_uuid()
    );
    raise exception 'selected profile media was archived';
  exception when object_not_in_prerequisite_state then null; end;
end;
$$;
reset role;

do $$
begin
  if (select count(*) from public.audit_events
      where event_type = 'horse.updated'
        and resource_id = (select horse_id from pg_temp.c0091_fixture)
        and metadata->>'operation_code' = 'set_canonical_horse_profile_media') <> 1
  then raise exception 'same-horse profile media audit failed'; end if;
end;
$$;

-- Service-only coordinate resolution uses the verified user identity and
-- never accepts a client-supplied authority claim.
set local role service_role;
do $$
begin
  if (select count(*) from public.authorize_canonical_media_asset_download(
      (select authority_user from pg_temp.c0091_fixture),
      (select asset_id from pg_temp.c0091_fixture), 'thumbnail')) <> 1
    or (select count(*) from public.authorize_canonical_media_asset_download(
      (select outsider_user from pg_temp.c0091_fixture),
      (select asset_id from pg_temp.c0091_fixture), 'thumbnail')) <> 0
  then
    raise exception 'private download authorization or cross-user isolation failed';
  end if;
end;
$$;
reset role;

-- Catalog and compatibility invariants.
do $$
declare
  relation_name text;
begin
  foreach relation_name in array array[
    'media_assets', 'media_asset_variants', 'media_links', 'media_change_events'
  ] loop
    if not (select class.relrowsecurity from pg_catalog.pg_class class
      where class.oid = ('public.' || relation_name)::regclass)
      or pg_catalog.has_table_privilege(
        'authenticated', 'public.' || relation_name, 'INSERT,UPDATE,DELETE'
      )
    then
      raise exception 'C-009.1 RLS/direct DML incorrect for %', relation_name;
    end if;
  end loop;
  if (select is_nullable from information_schema.columns
      where table_schema = 'public' and table_name = 'media_assets'
        and column_name = 'stable_id') <> 'YES'
    or (select is_nullable from information_schema.columns
      where table_schema = 'public' and table_name = 'media_assets'
        and column_name = 'horse_id') <> 'NO'
    or not exists (
      select 1 from pg_catalog.pg_constraint constraint_row
      where constraint_row.conname = 'media_assets_canonical_horse_fk'
    )
    or pg_catalog.has_function_privilege(
      'authenticated',
      'public.get_canonical_media_upload_session(uuid,uuid)', 'EXECUTE'
    )
    or pg_catalog.has_function_privilege(
      'authenticated',
      'public.finalize_canonical_media_asset(uuid,uuid,bigint,text,bigint,text,text,bigint,text,uuid)',
      'EXECUTE'
    )
    or pg_catalog.has_function_privilege(
      'authenticated',
      'public.authorize_canonical_media_asset_download(uuid,uuid,text)', 'EXECUTE'
    )
    or pg_catalog.has_function_privilege(
      'service_role',
      'public.set_canonical_horse_profile_media(uuid,uuid,bigint,uuid)', 'EXECUTE'
    )
    or not pg_catalog.has_function_privilege(
      'authenticated',
      'public.create_canonical_media_upload_session(uuid,text,text,uuid)', 'EXECUTE'
    )
  then
    raise exception 'C-009.1 canonical scope, ACL or service boundary invalid';
  end if;
  if exists (
    select 1
    from public.media_assets asset
    left join public.canonical_horses horse on horse.id = asset.horse_id
    where horse.id is null
  ) then
    raise exception 'media asset lost its canonical horse reference';
  end if;
end;
$$;

select extensions.pass(
  'C-009.1 canonical media is private, canonical-scoped, idempotent, CAS-safe and legacy-compatible'
);
select * from extensions.finish();

rollback;
