begin;

select extensions.plan(1);

create temporary table c007_fixture (
  auth_a uuid not null,
  auth_b uuid not null,
  profile_a uuid,
  profile_b uuid
);
grant select, update on pg_temp.c007_fixture to authenticated, anon, service_role;

insert into pg_temp.c007_fixture (auth_a, auth_b)
values (
  'c0070000-0000-4000-8000-000000000001',
  'c0070000-0000-4000-8000-000000000002'
);

insert into auth.users (
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
)
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  fixture.auth_a,
  'authenticated',
  'authenticated',
  'c007-a@example.invalid',
  '',
  pg_catalog.now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"profile_id":"spoofed","role":"platform_admin","full_name":"Sensitive A"}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
from pg_temp.c007_fixture fixture
union all
select
  '00000000-0000-0000-0000-000000000000'::uuid,
  fixture.auth_b,
  'authenticated',
  'authenticated',
  'c007-b@example.invalid',
  '',
  pg_catalog.now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
from pg_temp.c007_fixture fixture;

update pg_temp.c007_fixture fixture
set
  profile_a = (select id from public.profiles where auth_user_id = fixture.auth_a),
  profile_b = (select id from public.profiles where auth_user_id = fixture.auth_b);

set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.role', 'authenticated', true);
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  (select auth_a::text from pg_temp.c007_fixture),
  true
);

do $$
declare
  fixture pg_temp.c007_fixture%rowtype;
  projected record;
  updated record;
  avatar_updated record;
begin
  select * into strict fixture from pg_temp.c007_fixture;
  if fixture.profile_a is null or fixture.profile_b is null
    or fixture.profile_a = fixture.auth_a or fixture.profile_b = fixture.auth_b
  then
    raise exception 'C007 durable profile provisioning is invalid';
  end if;

  select * into strict projected from public.get_current_account_profile();
  if projected.profile_id <> fixture.profile_a
    or projected.profile_id = fixture.auth_a
    or projected.display_name <> 'AVARYN user'
    or projected.profile_status <> 'active'
    or projected.row_version <> 1
    or projected.access_version <> 1
  then
    raise exception 'C007 typed own-profile projection is invalid';
  end if;

  begin
    perform profile.first_name from public.profiles profile;
    raise exception 'Restricted profile columns were directly selectable';
  exception when insufficient_privilege then null;end;

  begin
    update public.profiles profile set first_name = 'Forbidden'
    where profile.id = fixture.profile_a;
    raise exception 'Restricted profile columns were directly mutable';
  exception when insufficient_privilege then null;end;

  select * into strict updated
  from public.update_current_account_profile(
    1,
    'Ada',
    'Lovelace',
    '+31612345678',
    'nl',
    'Europe/Amsterdam',
    'dark',
    'individualHorse',
    true,
    null,
    'c0071000-0000-4000-8000-000000000001'
  );

  if updated.result_code <> 'updated'
    or updated.profile_id <> fixture.profile_a
    or updated.display_name <> 'Ada Lovelace'
    or updated.onboarding_completed_at is null
    or updated.time_zone <> 'Europe/Amsterdam'
    or updated.row_version <> 2
    or updated.access_version <> 1
  then
    raise exception 'C007 onboarding mutation result is invalid';
  end if;

  begin
    perform * from public.update_current_account_profile(
      1,'Stale','Writer',null,'nl','UTC','system','individualHorse',false,null,
      'c0071000-0000-4000-8000-000000000002'
    );
    raise exception 'Stale profile mutation succeeded';
  exception when sqlstate 'PT409' then
    if sqlerrm <> 'PROFILE_VERSION_STALE' then raise;end if;
  end;

  begin
    perform * from public.update_current_account_profile(
      2,'Ada','Lovelace',null,'nl','UTC','system','individualHorse',false,
      fixture.auth_b::text || '/avatar-11111111-1111-4111-8111-111111111111.png',
      'c0071000-0000-4000-8000-000000000003'
    );
    raise exception 'Cross-account avatar path succeeded';
  exception when insufficient_privilege then
    if sqlerrm <> 'AVATAR_PATH_NOT_OWNED' then raise;end if;
  end;

  select * into strict avatar_updated
  from public.update_current_account_profile(
    2,'Ada','Lovelace',null,'nl','Europe/Amsterdam','system','individualHorse',false,
    fixture.auth_a::text || '/avatar-11111111-1111-4111-8111-111111111111.webp',
    'c0071000-0000-4000-8000-000000000004'
  );
  if avatar_updated.row_version <> 3
    or avatar_updated.avatar_object_path not like fixture.auth_a::text || '/avatar-%'
  then raise exception 'Owned avatar path did not update safely';end if;

  perform pg_catalog.set_config('request.jwt.claim.sub', fixture.auth_b::text, true);
  select * into strict projected from public.get_current_account_profile();
  if projected.profile_id <> fixture.profile_b
    or projected.display_name <> 'AVARYN user'
    or projected.onboarding_completed_at is not null
  then raise exception 'C007 actor B crossed profile scope';end if;

  begin
    perform * from public.update_current_account_profile(
      1,'Bob',null,null,'nl','Not/A_Time_Zone','system','joinStable',true,null,
      'c0071000-0000-4000-8000-000000000005'
    );
    raise exception 'Invalid IANA time zone succeeded';
  exception when invalid_parameter_value then
    if sqlerrm <> 'TIME_ZONE_INVALID' then raise;end if;
  end;

end;
$$;

reset role;

do $$
declare
  fixture pg_temp.c007_fixture%rowtype;
  audit_record public.audit_events%rowtype;
begin
  select * into strict fixture from pg_temp.c007_fixture;
  select event.* into strict audit_record
  from public.audit_events event
  where event.event_type = 'profile.account_fields_updated'
    and event.resource_id = fixture.profile_a
    and event.correlation_id = 'c0071000-0000-4000-8000-000000000001';

  if audit_record.actor_profile_id <> fixture.profile_a
    or audit_record.channel <> 'rpc'
    or audit_record.row_version_before <> 1
    or audit_record.row_version_after <> 2
    or not (audit_record.metadata -> 'changed_fields' ? 'onboarding_completed_at')
    or pg_catalog.concat(
      audit_record.old_state::text,
      audit_record.new_state::text,
      audit_record.metadata::text
    ) ilike any (array[
      '%ada%',
      '%lovelace%',
      '%31612345678%',
      '%example.invalid%',
      '%platform_admin%'
    ])
  then
    raise exception 'C007 onboarding audit is invalid or contains PII/Auth metadata';
  end if;
end;
$$;

update public.profiles profile
set status = 'deletion_pending', access_version = profile.access_version + 1
where profile.id = (select profile_a from pg_temp.c007_fixture);

set local role authenticated;
select pg_catalog.set_config(
  'request.jwt.claim.sub',
  (select auth_a::text from pg_temp.c007_fixture),
  true
);
do $$
begin
  begin
    perform * from public.get_current_account_profile();
    raise exception 'Inactive profile retained account access';
  exception when insufficient_privilege then
    if sqlerrm <> 'ACTIVE_PROFILE_REQUIRED' then raise;end if;
  end;
end;
$$;

reset role;

do $$
begin
  if not pg_catalog.has_function_privilege(
    'authenticated', 'public.get_current_account_profile()', 'EXECUTE'
  ) or pg_catalog.has_function_privilege(
    'anon', 'public.get_current_account_profile()', 'EXECUTE'
  ) or pg_catalog.has_function_privilege(
    'service_role', 'public.get_current_account_profile()', 'EXECUTE'
  ) then raise exception 'C007 profile read RPC ACL is invalid';end if;

  if not pg_catalog.has_function_privilege(
    'authenticated',
    'public.update_current_account_profile(bigint,text,text,text,text,text,text,text,boolean,text,uuid)',
    'EXECUTE'
  ) or pg_catalog.has_function_privilege(
    'anon',
    'public.update_current_account_profile(bigint,text,text,text,text,text,text,text,boolean,text,uuid)',
    'EXECUTE'
  ) or pg_catalog.has_function_privilege(
    'service_role',
    'public.update_current_account_profile(bigint,text,text,text,text,text,text,text,boolean,text,uuid)',
    'EXECUTE'
  ) then raise exception 'C007 profile mutation RPC ACL is invalid';end if;

  if exists(
    select 1 from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in ('get_current_account_profile','update_current_account_profile')
      and (
        not procedure.prosecdef
        or procedure.proconfig is null
        or not procedure.proconfig @> array['search_path=""']::text[]
        or pg_catalog.pg_get_function_result(procedure.oid) not like 'TABLE(%'
      )
  ) then raise exception 'C007 typed RPC or SECURITY DEFINER hardening is invalid';end if;
end;
$$;

select extensions.pass(
  'C-007 personal account/Auth/onboarding actor, RLS, ACL, CAS, audit and avatar boundaries passed'
);
select * from extensions.finish();

rollback;
