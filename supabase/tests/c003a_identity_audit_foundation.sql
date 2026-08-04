begin;

select extensions.plan(1);

-- C-003A tests run only against an isolated, disposable local database. Every
-- fixture is rolled back so the test remains repeatable.

create temporary table c003a_fixture (
  auth_a uuid not null,
  auth_b uuid not null,
  auth_c uuid not null,
  profile_a uuid,
  profile_b uuid,
  profile_c uuid,
  delete_request_a uuid not null,
  prepare_a uuid not null,
  finalize_a uuid not null,
  alternate_request_a uuid not null,
  audit_count_before_unlink bigint
);

grant select, update on pg_temp.c003a_fixture to authenticated, anon;

insert into pg_temp.c003a_fixture (
  auth_a,
  auth_b,
  auth_c,
  delete_request_a,
  prepare_a,
  finalize_a,
  alternate_request_a
)
values (
  'c003a000-0000-4000-8000-000000000001',
  'c003a000-0000-4000-8000-000000000002',
  'c003a000-0000-4000-8000-000000000003',
  'c003a100-0000-4000-8000-000000000001',
  'c003a200-0000-4000-8000-000000000001',
  'c003a300-0000-4000-8000-000000000001',
  'c003a400-0000-4000-8000-000000000001'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  fixture.auth_a,
  'authenticated',
  'authenticated',
  'sensitive-alice@example.invalid',
  '',
  pg_catalog.now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  pg_catalog.jsonb_build_object(
    'full_name',
    'Sensitive Alice',
    'profile_id',
    fixture.auth_b,
    'role',
    'platform_admin'
  ),
  pg_catalog.now(),
  pg_catalog.now()
from pg_temp.c003a_fixture fixture
union all
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  fixture.auth_b,
  'authenticated',
  'authenticated',
  'sensitive-bob@example.invalid',
  '',
  pg_catalog.now(),
  '{}'::jsonb,
  '{"full_name":"Sensitive Bob"}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
from pg_temp.c003a_fixture fixture
union all
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  fixture.auth_c,
  'authenticated',
  'authenticated',
  'sensitive-carol@example.invalid',
  '',
  pg_catalog.now(),
  '{}'::jsonb,
  '{}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
from pg_temp.c003a_fixture fixture;

update pg_temp.c003a_fixture fixture
set
  profile_a = (
    select profile.id
    from public.profiles profile
    where profile.auth_user_id = fixture.auth_a
  ),
  profile_b = (
    select profile.id
    from public.profiles profile
    where profile.auth_user_id = fixture.auth_b
  ),
  profile_c = (
    select profile.id
    from public.profiles profile
    where profile.auth_user_id = fixture.auth_c
  );

do $$
declare
  fixture pg_temp.c003a_fixture%rowtype;
  provision_event public.audit_events%rowtype;
begin
  select * into fixture from pg_temp.c003a_fixture;

  if fixture.profile_a is null
    or fixture.profile_b is null
    or fixture.profile_c is null
  then
    raise exception 'Provisioning did not create all profiles';
  end if;

  if fixture.profile_a = fixture.auth_a
    or fixture.profile_b = fixture.auth_b
    or fixture.profile_c = fixture.auth_c
  then
    raise exception 'A profile UUID reused a client/Auth UUID';
  end if;

  if (
    select pg_catalog.count(*)
    from public.profiles profile
    where profile.auth_user_id in (fixture.auth_a, fixture.auth_b, fixture.auth_c)
  ) <> 3 then
    raise exception 'Provisioning did not create exactly one profile per Auth user';
  end if;

  if exists (
    select 1
    from public.profiles profile
    where profile.auth_user_id in (fixture.auth_a, fixture.auth_b)
      and (
        profile.display_name <> 'AVARYN user'
        or profile.time_zone <> 'UTC'
        or profile.locale <> 'und'
        or profile.status <> 'active'
        or profile.access_version <> 1
        or profile.row_version <> 1
      )
  ) then
    raise exception 'Provisioning did not use neutral safe defaults';
  end if;

  select event.* into strict provision_event
  from public.audit_events event
  where event.event_type = 'profile.provisioned'
    and event.resource_id = fixture.profile_a;

  if provision_event.actor_kind <> 'system'
    or provision_event.system_actor_code <> 'auth_provisioner'
    or provision_event.actor_profile_id is not null
    or provision_event.row_version_after <> 1
    or provision_event.access_version_after <> 1
  then
    raise exception 'Provisioning audit actor or versions are incorrect';
  end if;

  if provision_event::text ilike '%sensitive-alice%'
    or provision_event::text ilike '%example.invalid%'
    or provision_event::text ilike '%platform_admin%'
  then
    raise exception 'Provisioning audit contains Auth metadata or PII';
  end if;

  begin
    insert into public.profiles (auth_user_id, display_name)
    values (fixture.auth_a, 'Duplicate');
    raise exception 'Second profile for one Auth user succeeded';
  exception
    when unique_violation then
      null;
  end;

  begin
    insert into public.profiles (
      auth_user_id,
      display_name,
      status,
      access_version,
      row_version
    )
    values (
      'c003a999-0000-4000-8000-000000000999',
      'No Auth',
      'active',
      1,
      1
    );
    raise exception 'Active profile without a valid Auth user succeeded';
  exception
    when foreign_key_violation then
      null;
  end;
end;
$$;

-- Missing and anonymous actors fail closed. Anonymous cannot even execute the
-- helper, while a trusted diagnostic call with no JWT obtains null.
select pg_catalog.set_config('request.jwt.claim.sub', '', true);
select pg_catalog.set_config('request.jwt.claim.role', 'anon', true);

do $$
begin
  if private.current_profile_id() is not null then
    raise exception 'Missing actor did not fail closed';
  end if;
end;
$$;

set local role anon;

do $$
begin
  begin
    perform private.current_profile_id();
    raise exception 'Anonymous actor executed current_profile_id';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    perform profile.id from public.profiles profile;
    raise exception 'Anonymous actor read profiles';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    perform public.request_profile_deletion(
      1,
      'c003afff-0000-4000-8000-000000000001'
    );
    raise exception 'Anonymous actor executed deletion RPC';
  exception
    when insufficient_privilege then
      null;
  end;
end;
$$;

reset role;

-- Auth user A receives a hostile metadata payload that claims profile B and a
-- privileged role. Only the JWT sub/Auth UID may influence actor derivation.
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  (select fixture.auth_a::text from pg_temp.c003a_fixture fixture),
  true
);
select pg_catalog.set_config('request.jwt.claim.role', 'authenticated', true);
select pg_catalog.set_config(
  'request.jwt.claims',
  (
    select pg_catalog.jsonb_build_object(
      'sub',
      fixture.auth_a,
      'role',
      'authenticated',
      'user_metadata',
      pg_catalog.jsonb_build_object(
        'profile_id',
        fixture.profile_b,
        'role',
        'platform_admin'
      )
    )::text
    from pg_temp.c003a_fixture fixture
  ),
  true
);

set local role authenticated;

do $$
declare
  fixture pg_temp.c003a_fixture%rowtype;
  visible_count bigint;
  changed_count bigint;
begin
  select * into fixture from pg_temp.c003a_fixture;

  if private.current_profile_id() <> fixture.profile_a then
    raise exception 'Actor derivation did not use the Auth UID exclusively';
  end if;

  select pg_catalog.count(*) into visible_count
  from public.profiles profile;
  if visible_count <> 1 then
    raise exception 'Own-profile RLS exposed % rows instead of 1', visible_count;
  end if;

  select pg_catalog.count(*) into visible_count
  from public.profiles profile
  where profile.id = fixture.profile_b;
  if visible_count <> 0 then
    raise exception 'Spoofed metadata exposed profile B';
  end if;

  update public.profiles profile
  set display_name = 'Alice Safe', time_zone = 'Europe/Brussels'
  where profile.id = fixture.profile_a;
  get diagnostics changed_count = row_count;
  if changed_count <> 1 then
    raise exception 'Safe own-profile update was rejected';
  end if;

  update public.profiles profile
  set display_name = 'Cross-profile attack'
  where profile.id = fixture.profile_b;
  get diagnostics changed_count = row_count;
  if changed_count <> 0 then
    raise exception 'Cross-profile update succeeded';
  end if;

  begin
    update public.profiles profile
    set time_zone = 'Mars/Olympus_Mons'
    where profile.id = fixture.profile_a;
    raise exception 'Invalid IANA time zone succeeded';
  exception
    when check_violation then
      null;
  end;

  begin
    insert into public.profiles (auth_user_id, display_name)
    values (fixture.auth_a, 'Client insert');
    raise exception 'Authenticated direct profile INSERT succeeded';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    delete from public.profiles profile where profile.id = fixture.profile_a;
    raise exception 'Authenticated direct profile DELETE succeeded';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    update public.profiles profile
    set status = 'deletion_pending'
    where profile.id = fixture.profile_a;
    raise exception 'Authenticated direct status update succeeded';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    update public.profiles profile
    set auth_user_id = fixture.auth_b
    where profile.id = fixture.profile_a;
    raise exception 'Authenticated direct Auth-link update succeeded';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    update public.profiles profile
    set access_version = 99
    where profile.id = fixture.profile_a;
    raise exception 'Authenticated direct access_version update succeeded';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    update public.profiles profile
    set row_version = 99
    where profile.id = fixture.profile_a;
    raise exception 'Authenticated direct row_version update succeeded';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    insert into public.audit_events (
      actor_kind,
      actor_profile_id,
      event_type,
      resource_kind,
      resource_id,
      scope_kind,
      scope_id,
      reason_code,
      correlation_id,
      channel
    )
    values (
      'profile',
      fixture.profile_a,
      'profile.deletion_requested',
      'profile',
      fixture.profile_a,
      'profile',
      fixture.profile_a,
      'USER_DELETION_REQUEST',
      extensions.gen_random_uuid(),
      'rpc'
    );
    raise exception 'Authenticated direct audit INSERT succeeded';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    update public.audit_events event
    set metadata = '{}'::jsonb
    where event.resource_id = fixture.profile_a;
    raise exception 'Authenticated direct audit UPDATE succeeded';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    delete from public.audit_events event
    where event.resource_id = fixture.profile_a;
    raise exception 'Authenticated direct audit DELETE succeeded';
  exception
    when insufficient_privilege then
      null;
  end;

  if pg_catalog.has_function_privilege(
    'authenticated',
    'private.c003a_write_profile_audit(text,uuid,uuid,text,uuid,text,text,text,bigint,bigint,bigint,bigint,jsonb)',
    'EXECUTE'
  ) then
    raise exception 'Authenticated can execute the audit writer';
  end if;

  if pg_catalog.has_function_privilege(
    'authenticated',
    'private.prepare_profile_auth_removal(uuid,bigint,uuid)',
    'EXECUTE'
  ) or pg_catalog.has_function_privilege(
    'authenticated',
    'private.finalize_profile_anonymization(uuid,bigint,uuid)',
    'EXECUTE'
  ) then
    raise exception 'Authenticated can execute an internal lifecycle function';
  end if;

  if pg_catalog.has_function_privilege(
    'service_role',
    'private.c003a_write_profile_audit(text,uuid,uuid,text,uuid,text,text,text,bigint,bigint,bigint,bigint,jsonb)',
    'EXECUTE'
  ) or pg_catalog.has_function_privilege(
    'service_role',
    'private.prepare_profile_auth_removal(uuid,bigint,uuid)',
    'EXECUTE'
  ) then
    raise exception 'Service role can execute an internal C-003A writer';
  end if;

  if not pg_catalog.has_function_privilege(
    'authenticated',
    'public.request_profile_deletion(bigint,uuid)',
    'EXECUTE'
  ) then
    raise exception 'Authenticated cannot execute the deletion request RPC';
  end if;
end;
$$;

reset role;

do $$
declare
  fixture pg_temp.c003a_fixture%rowtype;
  profile_record public.profiles%rowtype;
  display_event public.audit_events%rowtype;
begin
  select * into fixture from pg_temp.c003a_fixture;

  begin
    delete from auth.users auth_user where auth_user.id = fixture.auth_b;
    raise exception 'Auth user disappeared while its profile was active';
  exception
    when invalid_parameter_value then
      if sqlerrm <> 'PROFILE_AUTH_LINK_INVALID' then
        raise;
      end if;
  end;

  if not exists (
    select 1 from auth.users auth_user where auth_user.id = fixture.auth_b
  ) then
    raise exception 'Failed Auth delete did not preserve Auth user B';
  end if;

  select * into profile_record
  from public.profiles profile
  where profile.id = fixture.profile_a;

  if profile_record.row_version <> 2 or profile_record.access_version <> 1 then
    raise exception 'Display update versions were %, %, expected 2, 1',
      profile_record.row_version,
      profile_record.access_version;
  end if;

  select event.* into strict display_event
  from public.audit_events event
  where event.event_type = 'profile.display_fields_updated'
    and event.resource_id = fixture.profile_a;

  if display_event.actor_profile_id <> fixture.profile_a
    or display_event.actor_kind <> 'profile'
    or display_event.channel <> 'direct_api'
    or display_event.row_version_before <> 1
    or display_event.row_version_after <> 2
    or display_event.access_version_before <> 1
    or display_event.access_version_after <> 1
    or display_event.metadata -> 'changed_fields'
      <> '["display_name", "time_zone"]'::jsonb
  then
    raise exception 'Safe display update audit is incorrect';
  end if;

  if display_event::text ilike '%alice safe%'
    or display_event::text ilike '%europe/brussels%'
  then
    raise exception 'Display audit captured a profile field value';
  end if;
end;
$$;

-- Exercise stale optimistic concurrency and then a valid, idempotent deletion
-- request. The RPC has no target-profile argument to spoof.
set local role authenticated;

do $$
declare
  fixture pg_temp.c003a_fixture%rowtype;
  result record;
  visible_count bigint;
begin
  select * into fixture from pg_temp.c003a_fixture;

  select * into result
  from public.request_profile_deletion(1, fixture.delete_request_a);

  if result.result_code <> 'stale_row_version'
    or result.applied
    or result.row_version <> 2
    or result.access_version <> 1
  then
    raise exception 'Stale deletion request was not rejected safely';
  end if;

  select * into result
  from public.request_profile_deletion(2, fixture.delete_request_a);
  if result.result_code <> 'deletion_pending'
    or not result.applied
    or result.profile_status <> 'deletion_pending'
    or result.row_version <> 3
    or result.access_version <> 2
    or result.production_ready
  then
    raise exception 'Valid deletion request result is incorrect';
  end if;

  select * into result
  from public.request_profile_deletion(999, fixture.delete_request_a);
  if result.result_code <> 'idempotent_replay'
    or result.applied
    or result.row_version <> 3
    or result.access_version <> 2
  then
    raise exception 'Deletion request replay was not idempotent';
  end if;

  select * into result
  from public.request_profile_deletion(3, fixture.alternate_request_a);
  if result.result_code <> 'already_pending' or result.applied then
    raise exception 'Second correlation caused another deletion mutation';
  end if;

  if private.current_profile_id() is not null then
    raise exception 'deletion_pending remained an active actor';
  end if;

  select pg_catalog.count(*) into visible_count
  from public.profiles profile;
  if visible_count <> 0 then
    raise exception 'deletion_pending profile remained RLS-readable';
  end if;
end;
$$;

reset role;

do $$
declare
  fixture pg_temp.c003a_fixture%rowtype;
  profile_record public.profiles%rowtype;
  result record;
  audit_before bigint;
  audit_after bigint;
begin
  select * into fixture from pg_temp.c003a_fixture;
  select * into profile_record
  from public.profiles profile
  where profile.id = fixture.profile_a;

  if profile_record.status <> 'deletion_pending'
    or profile_record.row_version <> 3
    or profile_record.access_version <> 2
  then
    raise exception 'Deletion request did not rotate status and versions';
  end if;

  if not exists (
    select 1
    from public.audit_events event
    where event.event_type = 'profile.deletion_requested'
      and event.resource_id = fixture.profile_a
      and event.actor_profile_id = fixture.profile_a
      and event.correlation_id = fixture.delete_request_a
      and event.row_version_before = 2
      and event.row_version_after = 3
      and event.access_version_before = 1
      and event.access_version_after = 2
  ) then
    raise exception 'Deletion request audit is missing actor, correlation or versions';
  end if;

  if (
    select pg_catalog.count(*)
    from public.audit_events event
    where event.event_type = 'profile.deletion_requested'
      and event.resource_id = fixture.profile_a
  ) <> 1 then
    raise exception 'Stale or replayed deletion request created an extra audit event';
  end if;

  if not exists (
    select 1
    from public.audit_events event
    where event.event_type = 'profile.lifecycle_denied'
      and event.resource_id = fixture.profile_a
      and event.correlation_id = fixture.delete_request_a
      and event.actor_profile_id = fixture.profile_a
      and event.metadata = '{"denial_code": "STALE_ROW_VERSION"}'::jsonb
      and event.row_version_before = 2
      and event.row_version_after = 2
      and event.access_version_before = 1
      and event.access_version_after = 1
  ) or not exists (
    select 1
    from public.audit_events event
    where event.event_type = 'profile.lifecycle_denied'
      and event.resource_id = fixture.profile_a
      and event.correlation_id = fixture.alternate_request_a
      and event.actor_profile_id = fixture.profile_a
      and event.metadata = '{"denial_code": "PROFILE_NOT_ACTIVE"}'::jsonb
  ) then
    raise exception 'Security-relevant lifecycle denial audit is incomplete';
  end if;

  begin
    update public.profiles profile
    set auth_user_id = null
    where profile.id = fixture.profile_a;
    raise exception 'Auth unlink before auth_removal_pending succeeded';
  exception
    when invalid_parameter_value then
      if sqlerrm <> 'PROFILE_AUTH_LINK_INVALID' then
        raise;
      end if;
  end;

  begin
    perform private.finalize_profile_anonymization(
      fixture.profile_a,
      profile_record.row_version,
      fixture.finalize_a
    );
    raise exception 'Finalization before preparation succeeded';
  exception
    when object_not_in_prerequisite_state then
      if sqlerrm <> 'AUTH_REMOVAL_PENDING_REQUIRED' then
        raise;
      end if;
  end;

  select * into result
  from private.prepare_profile_auth_removal(
    fixture.profile_a,
    profile_record.row_version,
    fixture.prepare_a
  );

  if result.result_code <> 'auth_removal_pending'
    or not result.applied
    or result.profile_status <> 'auth_removal_pending'
    or result.row_version <> 4
    or result.access_version <> 3
    or result.production_ready
  then
    raise exception 'Auth-removal preparation result is incorrect';
  end if;

  select * into result
  from private.prepare_profile_auth_removal(
    fixture.profile_a,
    999,
    fixture.prepare_a
  );
  if result.result_code <> 'idempotent_replay'
    or result.applied
    or result.row_version <> 4
    or result.access_version <> 3
  then
    raise exception 'Preparation replay was not idempotent';
  end if;

  select * into profile_record
  from public.profiles profile
  where profile.id = fixture.profile_a;
  if profile_record.first_name is not null
    or profile_record.last_name is not null
    or profile_record.display_name <> 'Deleted AVARYN account'
    or profile_record.avatar_object_path is not null
    or profile_record.phone_e164 is not null
    or profile_record.locale <> 'und'
    or profile_record.time_zone <> 'UTC'
    or profile_record.status <> 'auth_removal_pending'
  then
    raise exception 'Preparation did not pseudonymize the allowlisted fields';
  end if;

  if not exists (
    select 1
    from public.audit_events event
    where event.event_type = 'profile.auth_removal_prepared'
      and event.resource_id = fixture.profile_a
      and event.system_actor_code = 'account_deletion_orchestrator'
      and event.metadata = '{"dependency_checks_complete": false}'::jsonb
      and event.correlation_id = fixture.prepare_a
      and event.row_version_before = 3
      and event.row_version_after = 4
      and event.access_version_before = 2
      and event.access_version_after = 3
  ) then
    raise exception 'Preparation audit is incomplete';
  end if;

  begin
    perform private.finalize_profile_anonymization(
      fixture.profile_a,
      profile_record.row_version,
      fixture.finalize_a
    );
    raise exception 'Finalization with an Auth link succeeded';
  exception
    when object_not_in_prerequisite_state then
      if sqlerrm <> 'AUTH_LINK_STILL_PRESENT' then
        raise;
      end if;
  end;

  select pg_catalog.count(*) into audit_before
  from public.audit_events event
  where event.resource_id = fixture.profile_a;

  update pg_temp.c003a_fixture
  set audit_count_before_unlink = audit_before;

  -- This simulates the later trusted external Auth deletion step. The FK may
  -- detach only because preparation already reached auth_removal_pending.
  delete from auth.users auth_user where auth_user.id = fixture.auth_a;

  select pg_catalog.count(*) into audit_after
  from public.audit_events event
  where event.resource_id = fixture.profile_a;
  if audit_after <> audit_before then
    raise exception 'Auth unlink rewrote or duplicated audit history';
  end if;

  select * into profile_record
  from public.profiles profile
  where profile.id = fixture.profile_a;
  if profile_record.auth_user_id is not null
    or profile_record.status <> 'auth_removal_pending'
    or profile_record.row_version <> 5
    or profile_record.access_version <> 3
  then
    raise exception 'Controlled Auth unlink produced an invalid profile state';
  end if;

  select * into result
  from private.finalize_profile_anonymization(
    fixture.profile_a,
    profile_record.row_version,
    fixture.finalize_a
  );
  if result.result_code <> 'anonymized'
    or not result.applied
    or result.profile_status <> 'anonymized'
    or result.row_version <> 6
    or result.access_version <> 4
    or result.production_ready
  then
    raise exception 'Anonymization finalization result is incorrect';
  end if;

  select * into result
  from private.finalize_profile_anonymization(
    fixture.profile_a,
    999,
    fixture.finalize_a
  );
  if result.result_code <> 'idempotent_replay'
    or result.applied
    or result.row_version <> 6
    or result.access_version <> 4
  then
    raise exception 'Finalization replay was not idempotent';
  end if;

  select * into profile_record
  from public.profiles profile
  where profile.id = fixture.profile_a;
  if profile_record.id <> fixture.profile_a
    or profile_record.status <> 'anonymized'
    or profile_record.auth_user_id is not null
    or profile_record.anonymized_at is null
  then
    raise exception 'Durable profile identity was not preserved';
  end if;

  if not exists (
    select 1
    from public.audit_events event
    where event.event_type = 'profile.anonymization_finalized'
      and event.resource_id = fixture.profile_a
      and event.metadata = '{"dependency_checks_complete": false}'::jsonb
      and event.correlation_id = fixture.finalize_a
      and event.row_version_before = 5
      and event.row_version_after = 6
      and event.access_version_before = 3
      and event.access_version_after = 4
  ) then
    raise exception 'Finalization audit is incomplete';
  end if;

  if not exists (
    select 1
    from public.audit_events event
    where event.event_type = 'profile.deletion_requested'
      and event.actor_profile_id = fixture.profile_a
  ) then
    raise exception 'Anonymized actor history lost the durable profile UUID';
  end if;

  if exists (
    select 1
    from public.audit_events event
    where event.resource_id = fixture.profile_a
      and (
        event::text ilike '%sensitive-alice%'
        or event::text ilike '%alice safe%'
        or event::text ilike '%example.invalid%'
        or event::text ilike '%bearer%'
        or event::text ilike '%token%'
        or event::text ilike '%secret%'
      )
  ) then
    raise exception 'Audit payload contains PII or credential material';
  end if;
end;
$$;

-- Direct trusted database DML cannot alter append-only events, and version or
-- lifecycle guards prevent monotonicity/reversal violations on profiles.
do $$
declare
  fixture pg_temp.c003a_fixture%rowtype;
begin
  select * into fixture from pg_temp.c003a_fixture;

  begin
    update public.audit_events event
    set reason_code = reason_code
    where event.resource_id = fixture.profile_a;
    raise exception 'Trusted direct audit UPDATE succeeded';
  exception
    when object_not_in_prerequisite_state then
      if sqlerrm <> 'AUDIT_EVENTS_APPEND_ONLY' then
        raise;
      end if;
  end;

  begin
    delete from public.audit_events event
    where event.resource_id = fixture.profile_a;
    raise exception 'Trusted direct audit DELETE succeeded';
  exception
    when object_not_in_prerequisite_state then
      if sqlerrm <> 'AUDIT_EVENTS_APPEND_ONLY' then
        raise;
      end if;
  end;

  begin
    update public.profiles profile
    set access_version = profile.access_version - 1
    where profile.id = fixture.profile_a;
    raise exception 'access_version decreased';
  exception
    when invalid_parameter_value then
      if sqlerrm <> 'PROFILE_ACCESS_VERSION_INVALID' then
        raise;
      end if;
  end;

  begin
    update public.profiles profile
    set row_version = profile.row_version - 1
    where profile.id = fixture.profile_a;
    raise exception 'row_version decreased';
  exception
    when invalid_parameter_value then
      if sqlerrm <> 'PROFILE_TECHNICAL_FIELD_IMMUTABLE' then
        raise;
      end if;
  end;

  begin
    update public.profiles profile
    set status = 'active', access_version = profile.access_version + 1
    where profile.id = fixture.profile_a;
    raise exception 'Terminal lifecycle reversal succeeded';
  exception
    when invalid_parameter_value then
      if sqlerrm <> 'PROFILE_LIFECYCLE_INVALID' then
        raise;
      end if;
  end;
end;
$$;

-- The database contract itself proves that a duplicate active actor cannot be
-- formed: auth_user_id is unique and current_profile_id additionally demands
-- exactly one active match.
do $$
declare
  fixture pg_temp.c003a_fixture%rowtype;
  function_definition text;
begin
  select * into fixture from pg_temp.c003a_fixture;

  if not exists (
    select 1
    from pg_catalog.pg_constraint constraint_record
    where constraint_record.conrelid = 'public.profiles'::regclass
      and constraint_record.conname = 'profiles_auth_user_id_key'
      and constraint_record.contype = 'u'
  ) then
    raise exception 'One-to-one Auth/profile unique constraint is missing';
  end if;

  select pg_catalog.pg_get_functiondef(
    'private.current_profile_id()'::regprocedure
  ) into function_definition;
  if function_definition not ilike '%cardinality(matched_ids)%<> 1%'
    or function_definition ilike '%raw_user_meta_data%'
    or function_definition ilike '%request.jwt.claims%profile_id%'
  then
    raise exception 'current_profile_id is not explicitly fail-closed';
  end if;

  if exists (
    select 1
    from pg_catalog.pg_proc procedure_record
    join pg_catalog.pg_namespace namespace_record
      on namespace_record.oid = procedure_record.pronamespace
    where namespace_record.nspname = 'public'
      and procedure_record.proname = 'request_profile_deletion'
      and pg_catalog.pg_get_function_identity_arguments(procedure_record.oid)
        <> 'p_expected_row_version bigint, p_correlation_id uuid'
  ) then
    raise exception 'Deletion request RPC exposes an unexpected target argument';
  end if;

  if exists (
    select 1
    from public.audit_events event
    where event.resource_id = fixture.profile_a
      and event.metadata ? 'dependency_checks_complete'
      and event.metadata ->> 'dependency_checks_complete' <> 'false'
  ) then
    raise exception 'C-003A incorrectly claims dependency cleanup is complete';
  end if;
end;
$$;

select extensions.pass(
  'C-003A identity, RLS, versions, audit and anonymization foundation'
);
select * from extensions.finish();

rollback;
