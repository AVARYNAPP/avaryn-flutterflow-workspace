begin;

select extensions.plan(1);

-- C-003B runs only against an isolated disposable database. All fixtures and
-- mutations are transaction-local and rolled back at the end.
create temporary table c003b_fixture (
  auth_a uuid not null,
  auth_b uuid not null,
  auth_c uuid not null,
  profile_a uuid,
  profile_b uuid,
  profile_c uuid,
  organization_a uuid,
  organization_b uuid,
  membership_a uuid,
  membership_b uuid,
  viewer_role uuid,
  grantor_role uuid,
  viewer_assignment uuid,
  grantor_assignment uuid,
  create_a uuid not null,
  create_b uuid not null
);

grant select, update on pg_temp.c003b_fixture to authenticated, anon, service_role;

insert into pg_temp.c003b_fixture (
  auth_a, auth_b, auth_c, create_a, create_b
) values (
  'c003b000-0000-4000-8000-000000000001',
  'c003b000-0000-4000-8000-000000000002',
  'c003b000-0000-4000-8000-000000000003',
  'c003b100-0000-4000-8000-000000000001',
  'c003b100-0000-4000-8000-000000000002'
);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  '00000000-0000-0000-0000-000000000000'::uuid, fixture.auth_a,
  'authenticated', 'authenticated', 'c003b-a@example.invalid', '', now(),
  '{}'::jsonb, '{"stable_id":"spoof","role":"platform_admin"}'::jsonb, now(), now()
from pg_temp.c003b_fixture fixture
union all
select
  '00000000-0000-0000-0000-000000000000'::uuid, fixture.auth_b,
  'authenticated', 'authenticated', 'c003b-b@example.invalid', '', now(),
  '{}'::jsonb, '{"organization_id":"spoof","primary_admin":true}'::jsonb, now(), now()
from pg_temp.c003b_fixture fixture
union all
select
  '00000000-0000-0000-0000-000000000000'::uuid, fixture.auth_c,
  'authenticated', 'authenticated', 'c003b-c@example.invalid', '', now(),
  '{}'::jsonb, '{}'::jsonb, now(), now()
from pg_temp.c003b_fixture fixture;

update pg_temp.c003b_fixture fixture set
  profile_a = (select id from public.profiles where auth_user_id = fixture.auth_a),
  profile_b = (select id from public.profiles where auth_user_id = fixture.auth_b),
  profile_c = (select id from public.profiles where auth_user_id = fixture.auth_c);

do $$
declare fixture pg_temp.c003b_fixture%rowtype;
begin
  select * into fixture from pg_temp.c003b_fixture;
  if fixture.profile_a is null or fixture.profile_b is null or fixture.profile_c is null
  then raise exception 'C-003A did not provision C-003B fixture profiles'; end if;
  if (select pg_catalog.array_agg(code order by code) from public.organization_types)
    <> array['farrier_business','other_professional','stable','trainer_practice','veterinary_practice']
  then raise exception 'Organization type seed set is not exact'; end if;
  if not array[
      'organization.view','organization.edit',
      'organization.memberships.view','organization.memberships.manage',
      'organization.roles.view','organization.roles.manage',
      'organization.audit.view'
    ]::text[] <@ (select array_agg(code) from public.permission_definitions
      where scope_kind = 'organization')
    or exists (select 1 from public.permission_definitions
      where scope_kind = 'organization' and code not like 'organization.%')
  then raise exception 'Organization permission taxonomy is invalid'; end if;
end;
$$;

-- Anonymous has neither catalog/table access nor an RPC execution path.
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'anon', true);
set local role anon;
do $$ begin
  begin perform count(*) from public.organization_types;
    raise exception 'anon read organization_types';
  exception when insufficient_privilege then null; end;
  begin perform public.create_organization('stable','anon',null,gen_random_uuid(),'{}');
    raise exception 'anon executed create_organization';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Service role receives no bypass RPC and no direct authorization-table DML.
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'service_role', true);
set local role service_role;
do $$ begin
  begin perform public.create_organization('stable','service',null,gen_random_uuid(),'{}');
    raise exception 'service_role executed create_organization';
  exception when insufficient_privilege then null; end;
  begin truncate public.organization_memberships;
    raise exception 'service_role truncated memberships';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Actor A creates organization A. Client context contains deliberately spoofed
-- actor/primary identifiers and is ignored by the server-authoritative RPC.
select set_config('request.jwt.claim.sub', (select auth_a::text from pg_temp.c003b_fixture), true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select auth_a::text from pg_temp.c003b_fixture),
    'role', 'authenticated', 'stable_id', gen_random_uuid(),
    'organization_id', gen_random_uuid(), 'primary_admin_profile_id',
    (select profile_b from pg_temp.c003b_fixture)
  )::text, true
);
set local role authenticated;

with created as (
  select * from public.create_organization(
    'stable', 'C-003B Organization A', 'No PII in audit',
    (select create_a from pg_temp.c003b_fixture),
    jsonb_build_object(
      'actor_profile_id', (select profile_b from pg_temp.c003b_fixture),
      'primary_admin_profile_id', (select profile_b from pg_temp.c003b_fixture),
      'stable_id', gen_random_uuid()
    )
  )
)
update pg_temp.c003b_fixture fixture set
  organization_a = created.organization_id,
  membership_a = created.membership_id
from created;

do $$
declare fixture pg_temp.c003b_fixture%rowtype; replay record;
begin
  select * into fixture from pg_temp.c003b_fixture;
  select * into replay from public.create_organization(
    'veterinary_practice', 'Changed replay payload', null,
    fixture.create_a, '{"actor_profile_id":"spoof"}'
  );
  if replay.result_code <> 'idempotent_replay' or replay.applied
    or replay.organization_id <> fixture.organization_a
    or (select count(*) from public.organizations where created_by_profile_id = fixture.profile_a) <> 1
  then raise exception 'Create organization replay is not idempotent'; end if;
  if (select primary_admin_profile_id from public.organizations where id = fixture.organization_a) <> fixture.profile_a
  then raise exception 'Primary administrator was accepted from spoofed input'; end if;
  if not public.has_organization_permission(fixture.organization_a, 'organization.audit.view')
    or exists (
      select 1
      from public.permission_definitions permission_definition
      where permission_definition.scope_kind = 'organization'
        and not exists (
          select 1
          from public.organization_role_permissions role_permission
          join public.organization_roles role on role.id = role_permission.role_id
          where role.organization_id = fixture.organization_a
            and role.code = 'head_admin'
            and role_permission.permission_id = permission_definition.id
        )
    )
  then raise exception 'Head administrator was not assembled atomically with all permissions'; end if;
  if (select access_version from public.profiles where id = fixture.profile_a) <> 2
  then raise exception 'Organization creation did not rotate creator profile access_version'; end if;
  begin
    perform public.create_organization(
      'inactive_or_unknown', 'Must roll back', null, gen_random_uuid(), '{}'
    );
    raise exception 'Unknown organization type was accepted';
  exception when invalid_parameter_value then null; end;
  if (select count(*) from public.organizations where created_by_profile_id = fixture.profile_a) <> 1
  then raise exception 'Failed organization creation left partial records'; end if;
end;
$$;

set constraints all immediate;
set constraints all deferred;

-- Direct authenticated writes and TRUNCATE are unavailable; critical writes
-- are RPC-only even for the current head administrator.
do $$ begin
  begin update public.organizations set name = 'direct attack';
    raise exception 'authenticated directly updated organizations';
  exception when insufficient_privilege then null; end;
  begin update public.organizations
      set primary_admin_profile_id = (select profile_b from pg_temp.c003b_fixture)
      where id = (select organization_a from pg_temp.c003b_fixture);
    raise exception 'authenticated directly changed primary_admin_profile_id';
  exception when insufficient_privilege then null; end;
  begin update public.organizations set access_version = 1;
    raise exception 'authenticated directly wrote organization access_version';
  exception when insufficient_privilege then null; end;
  begin update public.profiles set access_version = 1;
    raise exception 'authenticated directly wrote profile access_version';
  exception when insufficient_privilege then null; end;
  begin insert into public.organization_roles (
      organization_id, code, name, created_by_profile_id, creation_correlation_id
    ) values (
      (select organization_a from pg_temp.c003b_fixture), 'attack', 'Attack',
      (select profile_a from pg_temp.c003b_fixture), gen_random_uuid()
    );
    raise exception 'authenticated directly inserted role';
  exception when insufficient_privilege then null; end;
  begin delete from public.organization_memberships;
    raise exception 'authenticated directly deleted membership';
  exception when insufficient_privilege then null; end;
  begin truncate public.organization_roles;
    raise exception 'authenticated truncated roles';
  exception when insufficient_privilege then null; end;
  begin truncate public.audit_events;
    raise exception 'authenticated truncated audit';
  exception when insufficient_privilege then null; end;
end $$;

-- A adds B, creates two explicit roles and grants both. Grantor deliberately
-- lacks organization.edit so B cannot delegate beyond effective authority.
with created as (
  select * from public.create_organization_membership(
    (select organization_a from pg_temp.c003b_fixture),
    (select profile_b from pg_temp.c003b_fixture), statement_timestamp(),
    'c003b200-0000-4000-8000-000000000001'
  )
)
update pg_temp.c003b_fixture fixture set membership_b = created.membership_id from created;

with created as (
  select * from public.create_organization_role(
    (select organization_a from pg_temp.c003b_fixture), 'viewer', 'Viewer', null,
    array['organization.view'], 'c003b200-0000-4000-8000-000000000002'
  )
)
update pg_temp.c003b_fixture fixture set viewer_role = created.role_id from created;

with created as (
  select * from public.create_organization_role(
    (select organization_a from pg_temp.c003b_fixture), 'grantor', 'Grantor', null,
    array['organization.view','organization.roles.view','organization.roles.manage'],
    'c003b200-0000-4000-8000-000000000003'
  )
)
update pg_temp.c003b_fixture fixture set grantor_role = created.role_id from created;

with granted as (
  select * from public.grant_organization_membership_role(
    (select membership_b from pg_temp.c003b_fixture),
    (select viewer_role from pg_temp.c003b_fixture), statement_timestamp(),
    'c003b200-0000-4000-8000-000000000004'
  )
)
update pg_temp.c003b_fixture fixture set viewer_assignment = granted.assignment_id from granted;

with granted as (
  select * from public.grant_organization_membership_role(
    (select membership_b from pg_temp.c003b_fixture),
    (select grantor_role from pg_temp.c003b_fixture), statement_timestamp(),
    'c003b200-0000-4000-8000-000000000005'
  )
)
update pg_temp.c003b_fixture fixture set grantor_assignment = granted.assignment_id from granted;

do $$
declare fixture pg_temp.c003b_fixture%rowtype; result record; profile_before bigint; org_before bigint;
begin
  select * into fixture from pg_temp.c003b_fixture;
  select access_version into profile_before from public.profiles where id = fixture.profile_b;
  select access_version into org_before from public.organizations where id = fixture.organization_a;
  select * into result from public.set_organization_role_permission(
    fixture.viewer_role, 1, 'organization.roles.view', true,
    'c003b200-0000-4000-8000-000000000006'
  );
  if not result.applied or result.role_row_version <> 2
    or (select access_version from public.profiles where id = fixture.profile_b) <> profile_before + 1
    or (select access_version from public.organizations where id = fixture.organization_a) <> org_before + 1
  then raise exception 'Role permission grant/version rotation failed'; end if;
  begin
    perform public.set_organization_role_permission(
      fixture.viewer_role, 1, 'organization.roles.view', false, gen_random_uuid()
    );
    raise exception 'Stale role permission row_version succeeded';
  exception when serialization_failure then null; end;
  select * into result from public.set_organization_role_permission(
    fixture.viewer_role, 2, 'organization.roles.view', false,
    'c003b200-0000-4000-8000-000000000007'
  );
  if not result.applied or result.role_row_version <> 3
  then raise exception 'Role permission revoke/version rotation failed'; end if;
end;
$$;

-- C independently creates organization B, establishing a second tenant.
select set_config('request.jwt.claim.sub', (select auth_c::text from pg_temp.c003b_fixture), true);
with created as (
  select * from public.create_organization(
    'veterinary_practice', 'C-003B Organization B', null,
    (select create_b from pg_temp.c003b_fixture), '{}'
  )
)
update pg_temp.c003b_fixture fixture set organization_b = created.organization_id from created;

-- B can see A through actual time-valid assignments, but cannot see tenant B.
select set_config('request.jwt.claim.sub', (select auth_b::text from pg_temp.c003b_fixture), true);
do $$
declare fixture pg_temp.c003b_fixture%rowtype;
begin
  select * into fixture from pg_temp.c003b_fixture;
  if not public.has_organization_permission(fixture.organization_a, 'organization.view')
    or public.has_organization_permission(fixture.organization_b, 'organization.view')
    or (select count(*) from public.organizations) <> 1
    or exists (select 1 from public.organizations where id = fixture.organization_b)
  then raise exception 'RLS or cross-tenant organization isolation failed'; end if;
  if exists (select 1 from public.organization_memberships where organization_id = fixture.organization_b)
    or exists (select 1 from public.organization_roles where organization_id = fixture.organization_b)
    or exists (select 1 from public.organization_role_permissions where organization_id = fixture.organization_b)
    or exists (select 1 from public.organization_membership_roles where organization_id = fixture.organization_b)
  then raise exception 'Cross-tenant child-row isolation failed'; end if;
  begin
    perform public.create_organization_membership(
      fixture.organization_b, fixture.profile_b, statement_timestamp(), gen_random_uuid()
    );
    raise exception 'Cross-tenant mutation succeeded';
  exception when insufficient_privilege then null; end;
  begin
    perform public.create_organization_role(
      fixture.organization_a, 'escalation', 'Escalation', null,
      array['organization.edit'], gen_random_uuid()
    );
    raise exception 'Actor delegated a permission they do not possess';
  exception when insufficient_privilege then null; end;
end;
$$;

-- A exercises optimistic concurrency, suspend/resume/end semantics, access
-- rotations, and mandatory primary-admin protections.
select set_config('request.jwt.claim.sub', (select auth_a::text from pg_temp.c003b_fixture), true);
do $$
declare fixture pg_temp.c003b_fixture%rowtype; membership_before public.organization_memberships%rowtype; profile_version bigint; org_version bigint; result record;
begin
  select * into fixture from pg_temp.c003b_fixture;
  select * into membership_before from public.organization_memberships where id = fixture.membership_b;
  select access_version into profile_version from public.profiles where id = fixture.profile_b;
  select access_version into org_version from public.organizations where id = fixture.organization_a;
  begin
    perform public.set_organization_membership_status(
      fixture.membership_b, 999, 'suspended', null, gen_random_uuid()
    );
    raise exception 'Stale membership row_version succeeded';
  exception when serialization_failure then null; end;
  select * into result from public.set_organization_membership_status(
    fixture.membership_b, membership_before.row_version, 'suspended', null,
    'c003b300-0000-4000-8000-000000000001'
  );
  if result.status <> 'suspended' or result.row_version <> membership_before.row_version + 1
    or (select access_version from public.profiles where id = fixture.profile_b) <> profile_version + 1
    or (select access_version from public.organizations where id = fixture.organization_a) <> org_version + 1
  then raise exception 'Membership suspension versions are incorrect'; end if;
  begin
    perform public.set_organization_membership_status(
      fixture.membership_a,
      (select row_version from public.organization_memberships where id = fixture.membership_a),
      'suspended', null, gen_random_uuid()
    );
    raise exception 'Primary membership was suspended';
  exception when check_violation then null; end;
  select * into result from public.set_organization_membership_status(
    fixture.membership_b, result.row_version, 'active', null,
    'c003b300-0000-4000-8000-000000000002'
  );
  if result.status <> 'active' then raise exception 'Membership resume failed'; end if;
end;
$$;

-- Suspended actors lose authority immediately; resumed actors regain only the
-- persisted, active and time-valid permissions.
select set_config('request.jwt.claim.sub', (select auth_a::text from pg_temp.c003b_fixture), true);
select public.set_organization_membership_status(
  (select membership_b from pg_temp.c003b_fixture),
  (select row_version from public.organization_memberships where id = (select membership_b from pg_temp.c003b_fixture)),
  'suspended', null, 'c003b300-0000-4000-8000-000000000003'
);
select set_config('request.jwt.claim.sub', (select auth_b::text from pg_temp.c003b_fixture), true);
do $$ begin
  if public.has_organization_permission((select organization_a from pg_temp.c003b_fixture), 'organization.view')
    or exists (select 1 from public.organizations)
  then raise exception 'Suspended membership retained organization access'; end if;
end $$;
select set_config('request.jwt.claim.sub', (select auth_a::text from pg_temp.c003b_fixture), true);
select public.set_organization_membership_status(
  (select membership_b from pg_temp.c003b_fixture),
  (select row_version from public.organization_memberships where id = (select membership_b from pg_temp.c003b_fixture)),
  'active', null, 'c003b300-0000-4000-8000-000000000004'
);

-- Reserved head-admin material cannot be client-mutated. Ordinary assignment
-- revocation/end and role lifecycle are versioned and auditable.
do $$
declare fixture pg_temp.c003b_fixture%rowtype; head_role uuid; head_assignment uuid; role_version bigint; result record;
begin
  select * into fixture from pg_temp.c003b_fixture;
  select id, row_version into head_role, role_version from public.organization_roles
    where organization_id = fixture.organization_a and code = 'head_admin';
  select id into head_assignment from public.organization_membership_roles where role_id = head_role;
  begin perform public.set_organization_role_permission(
      head_role, role_version, 'organization.view', false, gen_random_uuid()
    );
    raise exception 'Reserved head role permission was removed';
  exception when insufficient_privilege then null; end;
  begin perform public.set_organization_role_status(head_role, role_version, 'archived', gen_random_uuid());
    raise exception 'Reserved head role was archived';
  exception when insufficient_privilege then null; end;
  begin perform public.revoke_organization_membership_role(head_assignment, 1, false, gen_random_uuid());
    raise exception 'Reserved head assignment was revoked';
  exception when insufficient_privilege then null; end;
  select * into result from public.revoke_organization_membership_role(
    fixture.viewer_assignment, 1, false, 'c003b400-0000-4000-8000-000000000001'
  );
  if result.status <> 'revoked' or result.row_version <> 2 then
    raise exception 'Ordinary role revocation failed'; end if;
  select * into result from public.set_organization_role_status(
    fixture.viewer_role,
    (select row_version from public.organization_roles where id = fixture.viewer_role),
    'archived', 'c003b400-0000-4000-8000-000000000002'
  );
  if result.status <> 'archived' or result.row_version <> 4 then
    raise exception 'Ordinary role archive failed'; end if;
end;
$$;

-- Owner-level attempts prove database constraints independently of RPC/ACL:
-- deferred primary-admin invariant, non-overlapping windows and FK scope.
reset role;
do $$
declare fixture pg_temp.c003b_fixture%rowtype; head_role uuid;
begin
  select * into fixture from pg_temp.c003b_fixture;
  begin
    insert into public.organizations (
      organization_type_id, name, primary_admin_profile_id,
      created_by_profile_id, creation_correlation_id
    ) values (
      (select id from public.organization_types where code = 'stable'),
      'Missing primary', null, fixture.profile_a, gen_random_uuid()
    );
    raise exception 'Organization without primary admin succeeded';
  exception when not_null_violation then null; end;
  begin
    insert into public.organizations (
      organization_type_id, name, primary_admin_profile_id,
      created_by_profile_id, creation_correlation_id
    ) values (
      (select id from public.organization_types where code = 'stable'),
      'Unknown primary', gen_random_uuid(), fixture.profile_a, gen_random_uuid()
    );
    raise exception 'Organization with unknown primary profile succeeded';
  exception when foreign_key_violation then null; end;
  begin
    update public.organization_memberships set status = 'suspended', row_version = row_version + 1
      where id = fixture.membership_a;
    set constraints c003b_primary_admin_memberships immediate;
    raise exception 'Deferred primary-admin invariant accepted suspension';
  exception when check_violation then null; end;
  begin
    insert into public.organization_memberships (
      organization_id, profile_id, status, valid_from, created_by_profile_id,
      creation_correlation_id
    ) select organization_id, profile_id, 'active', valid_from,
      fixture.profile_a, gen_random_uuid()
      from public.organization_memberships where id = fixture.membership_b;
    raise exception 'Overlapping membership window succeeded';
  exception when exclusion_violation then null; end;
  select id into head_role from public.organization_roles
    where organization_id = fixture.organization_a and code = 'head_admin';
  begin
    insert into public.organization_membership_roles (
      organization_id, membership_id, role_id, valid_from,
      granted_by_profile_id, creation_correlation_id
    ) values (
      fixture.organization_a, fixture.membership_b, fixture.grantor_role,
      statement_timestamp(), fixture.profile_a, gen_random_uuid()
    );
    raise exception 'Overlapping membership-role window succeeded';
  exception when exclusion_violation then null; end;
  begin
    insert into public.organization_membership_roles (
      organization_id, membership_id, role_id, granted_by_profile_id,
      creation_correlation_id
    ) values (
      fixture.organization_b, fixture.membership_b, head_role,
      fixture.profile_a, gen_random_uuid()
    );
    raise exception 'Cross-organization assignment FK succeeded';
  exception when foreign_key_violation then null; end;
end;
$$;

-- Security-definer routines are postgres-owned, search_path-safe and minimally
-- executable. No C-003B private routine expands the C-003A private allowlist.
do $$
declare routine record; function_definition text;
begin
  for routine in
    select procedure_record.oid
    from pg_catalog.pg_proc procedure_record
    join pg_catalog.pg_namespace namespace_record on namespace_record.oid = procedure_record.pronamespace
    where (namespace_record.nspname = 'private' and procedure_record.proname like 'c003b_%')
       or (namespace_record.nspname = 'public' and procedure_record.proname in (
         'has_organization_permission','create_organization','update_organization',
         'create_organization_membership','set_organization_membership_status',
         'create_organization_role','set_organization_role_status',
         'set_organization_role_permission','grant_organization_membership_role',
         'revoke_organization_membership_role'
       ))
  loop
    select pg_catalog.pg_get_functiondef(routine.oid) into function_definition;
    if (select proowner from pg_catalog.pg_proc where oid = routine.oid) <> 'postgres'::regrole
      or function_definition not ilike '%SET search_path TO %''''%'
    then raise exception 'C-003B routine owner/search_path hardening failed for %', routine.oid::regprocedure; end if;
  end loop;
  if exists (
    select 1 from pg_catalog.pg_proc procedure_record
    join pg_catalog.pg_namespace namespace_record on namespace_record.oid = procedure_record.pronamespace
    where namespace_record.nspname = 'private' and procedure_record.proname like 'c003b_%'
      and (
        pg_catalog.has_function_privilege('authenticated', procedure_record.oid, 'EXECUTE')
        or pg_catalog.has_function_privilege('anon', procedure_record.oid, 'EXECUTE')
        or pg_catalog.has_function_privilege('service_role', procedure_record.oid, 'EXECUTE')
      )
  ) then raise exception 'C-003B expanded private client routine execution'; end if;
  if pg_catalog.has_function_privilege('service_role', 'public.create_organization(text,text,text,uuid,jsonb)', 'EXECUTE')
    or not pg_catalog.has_function_privilege('authenticated', 'public.create_organization(text,text,text,uuid,jsonb)', 'EXECUTE')
  then raise exception 'Public RPC EXECUTE allowlist is incorrect'; end if;
  if exists (
    select 1 from pg_catalog.pg_proc procedure_record
    join pg_catalog.pg_namespace namespace_record on namespace_record.oid = procedure_record.pronamespace
    where namespace_record.nspname = 'public' and procedure_record.proname = 'create_organization'
      and pg_catalog.pg_get_function_identity_arguments(procedure_record.oid)
        ilike any(array['%actor%','%primary_admin%','%profile_id%'])
  ) then raise exception 'Create organization exposes actor/primary identity arguments'; end if;
end;
$$;

-- Catalog immutability, RLS enablement, no DML grants and no legacy stable
-- authority are proven from the catalog and function definitions.
do $$
declare fixture pg_temp.c003b_fixture%rowtype; helper_definition text;
begin
  select * into fixture from pg_temp.c003b_fixture;
  begin update public.organization_types set code = 'changed' where code = 'stable';
    raise exception 'Organization type code changed';
  exception when invalid_parameter_value then null; end;
  begin update public.permission_definitions set code = 'organization.changed' where code = 'organization.view';
    raise exception 'Permission code changed';
  exception when invalid_parameter_value then null; end;
  if exists (
    select 1 from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace_record on namespace_record.oid = relation.relnamespace
    where namespace_record.nspname = 'public'
      and relation.relname in (
        'organization_types','permission_definitions','organizations',
        'organization_memberships','organization_roles',
        'organization_role_permissions','organization_membership_roles'
      ) and not relation.relrowsecurity
  ) then raise exception 'RLS is not enabled on every C-003B authorization table'; end if;
  if exists (
    select 1 from information_schema.role_table_grants grant_record
    where grant_record.grantee in ('anon','authenticated','service_role')
      and grant_record.table_schema = 'public'
      and grant_record.table_name like 'organization%'
      and grant_record.privilege_type in ('INSERT','UPDATE','DELETE','TRUNCATE')
  ) then raise exception 'Client role has direct C-003B DML/TRUNCATE privilege'; end if;
  select pg_catalog.pg_get_functiondef('private.c003b_profile_has_permission(uuid,uuid,text,timestamptz)'::regprocedure)
    into helper_definition;
  if helper_definition ilike '%stable_id%'
    or helper_definition ilike '%raw_user_meta_data%'
    or helper_definition ilike '%request.jwt.claims%organization%'
    or exists (
      select 1 from information_schema.columns
      where table_schema = 'public' and table_name like 'organization%'
        and column_name = 'stable_id'
    )
  then raise exception 'Legacy stable/JWT metadata grants C-003B authority'; end if;
end;
$$;

-- Audit is organization-scoped, PII-free, allowlisted and append-only. Access
-- changes rotate both organization and affected profile versions.
do $$
declare fixture pg_temp.c003b_fixture%rowtype;
begin
  select * into fixture from pg_temp.c003b_fixture;
  if not exists (
    select 1 from public.audit_events event
    where event.event_type = 'organization.created'
      and event.resource_id = fixture.organization_a
      and event.scope_kind = 'organization' and event.scope_id = fixture.organization_a
      and event.actor_profile_id = fixture.profile_a
      and event.correlation_id = fixture.create_a
      and event.reason_code = 'ORGANIZATION_CREATED'
  ) or not exists (
    select 1 from public.audit_events event
    where event.event_type = 'organization.membership_role_revoked'
      and event.scope_id = fixture.organization_a
      and event.metadata ->> 'role_code' = 'viewer'
  ) then raise exception 'Required C-003B audit event is missing'; end if;
  if exists (
    select 1 from public.audit_events event
    where event.scope_id in (fixture.organization_a, fixture.organization_b)
      and (
        event::text ilike '%example.invalid%'
        or event::text ilike '%C-003B Organization%'
        or event.metadata ? 'email' or event.metadata ? 'name'
      )
  ) then raise exception 'C-003B audit contains PII or organization names'; end if;
  begin update public.audit_events set metadata = '{}' where scope_id = fixture.organization_a;
    raise exception 'Audit UPDATE succeeded';
  exception when sqlstate '55000' then
    if sqlerrm not like 'AUDIT_EVENTS_APPEND_ONLY%' then raise; end if;
  end;
  begin delete from public.audit_events where scope_id = fixture.organization_a;
    raise exception 'Audit DELETE succeeded';
  exception when sqlstate '55000' then
    if sqlerrm not like 'AUDIT_EVENTS_APPEND_ONLY%' then raise; end if;
  end;
  begin truncate public.audit_events;
    raise exception 'Audit TRUNCATE succeeded';
  exception when sqlstate '55000' then
    if sqlerrm not like 'AUDIT_EVENTS_APPEND_ONLY%' then raise; end if;
  end;
end;
$$;

-- Lifecycle completion: end B's membership after testing assignment end. Ended
-- windows cannot authorize and cannot be resumed.
set local role authenticated;
select set_config('request.jwt.claim.sub', (select auth_a::text from pg_temp.c003b_fixture), true);
select public.revoke_organization_membership_role(
  (select grantor_assignment from pg_temp.c003b_fixture), 1, true,
  'c003b500-0000-4000-8000-000000000001'
);
select public.set_organization_membership_status(
  (select membership_b from pg_temp.c003b_fixture),
  (select row_version from public.organization_memberships where id = (select membership_b from pg_temp.c003b_fixture)),
  'ended', 'profile_departed', 'c003b500-0000-4000-8000-000000000002'
);
select set_config('request.jwt.claim.sub', (select auth_b::text from pg_temp.c003b_fixture), true);
do $$ begin
  if public.has_organization_permission((select organization_a from pg_temp.c003b_fixture), 'organization.view')
  then raise exception 'Ended membership retained access'; end if;
  begin
    perform public.set_organization_membership_status(
      (select membership_b from pg_temp.c003b_fixture),
      (select row_version from public.organization_memberships where id = (select membership_b from pg_temp.c003b_fixture)),
      'active', null, gen_random_uuid()
    );
    raise exception 'Ended membership resumed';
  exception when insufficient_privilege then null; end;
end $$;

select * from public.request_profile_deletion(
  (select row_version from public.profiles where id = (select profile_b from pg_temp.c003b_fixture)),
  'c003b500-0000-4000-8000-000000000003'
);
do $$ begin
  if private.current_profile_id() is not null
    or public.has_organization_permission(
      (select organization_a from pg_temp.c003b_fixture), 'organization.view'
    )
  then raise exception 'Non-active profile remained authorized in C-003B'; end if;
end $$;
reset role;

select extensions.pass(
  'C-003B organizations, memberships, roles, RLS, versions, audit and invariants'
);
select * from extensions.finish();

rollback;
