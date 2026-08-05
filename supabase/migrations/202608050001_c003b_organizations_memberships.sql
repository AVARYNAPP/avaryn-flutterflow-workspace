-- C-003B — Organizations and memberships
-- Server-authoritative organization scope built next to, and deliberately
-- independent from, the legacy stable/stable_members access model.

create extension if not exists btree_gist with schema extensions;

create table public.organization_types (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique,
  label text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint organization_types_code_check
    check (code ~ '^[a-z][a-z0-9_]{1,62}$'),
  constraint organization_types_label_check
    check (pg_catalog.length(pg_catalog.btrim(label)) between 1 and 120)
);

insert into public.organization_types (code, label)
values
  ('stable', 'Stable'),
  ('trainer_practice', 'Trainer practice'),
  ('farrier_business', 'Farrier business'),
  ('veterinary_practice', 'Veterinary practice'),
  ('other_professional', 'Other professional');

create table public.permission_definitions (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique,
  scope_kind text not null default 'organization',
  action_class text not null,
  description text not null,
  is_grantable boolean not null default true,
  is_active boolean not null default true,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint permission_definitions_code_check
    check (code ~ '^organization\.[a-z][a-z0-9_.]{1,62}$'),
  constraint permission_definitions_scope_check
    check (scope_kind = 'organization'),
  constraint permission_definitions_action_check
    check (action_class in ('view', 'edit', 'manage', 'assign')),
  constraint permission_definitions_description_check
    check (pg_catalog.length(pg_catalog.btrim(description)) between 1 and 240)
);

insert into public.permission_definitions (
  code, action_class, description
)
values
  ('organization.view', 'view', 'View the organization.'),
  ('organization.edit', 'edit', 'Edit organization metadata and lifecycle.'),
  ('organization.memberships.view', 'view', 'View organization memberships.'),
  ('organization.memberships.manage', 'manage', 'Create and change memberships.'),
  ('organization.roles.view', 'view', 'View organization roles and permissions.'),
  ('organization.roles.manage', 'assign', 'Create roles and assign grantable permissions.'),
  ('organization.audit.view', 'view', 'View organization-scoped audit events.');

create table public.organizations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_type_id uuid not null
    references public.organization_types(id) on delete restrict,
  name text not null,
  description text,
  status text not null default 'active',
  primary_admin_profile_id uuid not null
    references public.profiles(id) on delete restrict,
  created_by_profile_id uuid not null
    references public.profiles(id) on delete restrict,
  creation_correlation_id uuid not null,
  access_version bigint not null default 1,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  archived_at timestamptz,
  constraint organizations_name_check
    check (pg_catalog.length(pg_catalog.btrim(name)) between 1 and 160),
  constraint organizations_description_check
    check (description is null or pg_catalog.length(description) <= 2000),
  constraint organizations_status_check
    check (status in ('active', 'archived')),
  constraint organizations_archive_shape_check
    check ((status = 'archived') = (archived_at is not null)),
  constraint organizations_access_version_check check (access_version >= 1),
  constraint organizations_row_version_check check (row_version >= 1),
  constraint organizations_creation_idempotency_unique
    unique (created_by_profile_id, creation_correlation_id)
);

create table public.organization_memberships (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  profile_id uuid not null
    references public.profiles(id) on delete restrict,
  status text not null default 'active',
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  ended_reason_code text,
  created_by_profile_id uuid not null
    references public.profiles(id) on delete restrict,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint organization_memberships_status_check
    check (status in ('active', 'suspended', 'ended')),
  constraint organization_memberships_time_check
    check (valid_until is null or valid_until > valid_from),
  constraint organization_memberships_end_shape_check
    check (
      (status = 'ended' and valid_until is not null and ended_reason_code is not null)
      or (status <> 'ended' and ended_reason_code is null)
    ),
  constraint organization_memberships_reason_check
    check (ended_reason_code is null or ended_reason_code in (
      'membership_ended', 'profile_departed', 'organization_closed'
    )),
  constraint organization_memberships_row_version_check check (row_version >= 1),
  constraint organization_memberships_org_id_unique unique (organization_id, id),
  constraint organization_memberships_creation_idempotency_unique
    unique (created_by_profile_id, creation_correlation_id),
  constraint organization_memberships_no_overlap
    exclude using gist (
      organization_id with =,
      profile_id with =,
      tstzrange(valid_from, valid_until, '[)') with &&
    ) where (status in ('active', 'suspended'))
);

create table public.organization_roles (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null
    references public.organizations(id) on delete restrict,
  code text not null,
  name text not null,
  description text,
  status text not null default 'active',
  is_system boolean not null default false,
  is_reserved boolean not null default false,
  created_by_profile_id uuid not null
    references public.profiles(id) on delete restrict,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  archived_at timestamptz,
  constraint organization_roles_code_check
    check (code ~ '^[a-z][a-z0-9_]{1,62}$'),
  constraint organization_roles_name_check
    check (pg_catalog.length(pg_catalog.btrim(name)) between 1 and 120),
  constraint organization_roles_description_check
    check (description is null or pg_catalog.length(description) <= 1000),
  constraint organization_roles_status_check check (status in ('active', 'archived')),
  constraint organization_roles_archive_shape_check
    check ((status = 'archived') = (archived_at is not null)),
  constraint organization_roles_reserved_shape_check
    check (not is_reserved or is_system),
  constraint organization_roles_row_version_check check (row_version >= 1),
  constraint organization_roles_org_code_unique unique (organization_id, code),
  constraint organization_roles_org_id_unique unique (organization_id, id),
  constraint organization_roles_creation_idempotency_unique
    unique (created_by_profile_id, creation_correlation_id)
);

create table public.organization_role_permissions (
  organization_id uuid not null,
  role_id uuid not null,
  permission_id uuid not null
    references public.permission_definitions(id) on delete restrict,
  granted_by_profile_id uuid not null
    references public.profiles(id) on delete restrict,
  correlation_id uuid not null,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key (role_id, permission_id),
  constraint organization_role_permissions_role_fk
    foreign key (organization_id, role_id)
    references public.organization_roles(organization_id, id) on delete restrict,
  constraint organization_role_permissions_idempotency_unique
    unique (granted_by_profile_id, correlation_id)
);

create table public.organization_membership_roles (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null,
  membership_id uuid not null,
  role_id uuid not null,
  status text not null default 'active',
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  ended_reason_code text,
  granted_by_profile_id uuid not null
    references public.profiles(id) on delete restrict,
  revoked_by_profile_id uuid
    references public.profiles(id) on delete restrict,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint organization_membership_roles_membership_fk
    foreign key (organization_id, membership_id)
    references public.organization_memberships(organization_id, id) on delete restrict,
  constraint organization_membership_roles_role_fk
    foreign key (organization_id, role_id)
    references public.organization_roles(organization_id, id) on delete restrict,
  constraint organization_membership_roles_status_check
    check (status in ('active', 'revoked', 'ended')),
  constraint organization_membership_roles_time_check
    check (valid_until is null or valid_until > valid_from),
  constraint organization_membership_roles_end_shape_check
    check (
      (status in ('revoked', 'ended') and valid_until is not null
        and ended_reason_code is not null and revoked_by_profile_id is not null)
      or (status = 'active' and ended_reason_code is null
        and revoked_by_profile_id is null)
    ),
  constraint organization_membership_roles_reason_check
    check (ended_reason_code is null or ended_reason_code in (
      'role_revoked', 'role_ended', 'membership_ended', 'role_archived'
    )),
  constraint organization_membership_roles_row_version_check check (row_version >= 1),
  constraint organization_membership_roles_creation_idempotency_unique
    unique (granted_by_profile_id, creation_correlation_id),
  constraint organization_membership_roles_no_overlap
    exclude using gist (
      membership_id with =,
      role_id with =,
      tstzrange(valid_from, valid_until, '[)') with &&
    ) where (status = 'active')
);

create index organization_memberships_profile_idx
  on public.organization_memberships (profile_id, organization_id);
create index organization_memberships_org_status_idx
  on public.organization_memberships (organization_id, status);
create index organization_roles_org_status_idx
  on public.organization_roles (organization_id, status);
create index organization_membership_roles_membership_idx
  on public.organization_membership_roles (membership_id, status);
create index organization_membership_roles_role_idx
  on public.organization_membership_roles (role_id, status);
create index organization_role_permissions_permission_idx
  on public.organization_role_permissions (permission_id, role_id);

-- Extend the C-003A append-only audit allowlists without weakening its profile
-- shapes. C-003B events remain organization-scoped and PII-free.
alter table public.audit_events drop constraint audit_events_event_type_check;
alter table public.audit_events add constraint audit_events_event_type_check check (
  event_type in (
    'profile.provisioned', 'profile.display_fields_updated',
    'profile.deletion_requested', 'profile.auth_removal_prepared',
    'profile.anonymization_finalized', 'profile.lifecycle_denied',
    'organization.created', 'organization.updated',
    'organization.membership_created', 'organization.membership_status_changed',
    'organization.role_created', 'organization.role_status_changed',
    'organization.role_permission_granted', 'organization.role_permission_revoked',
    'organization.membership_role_granted', 'organization.membership_role_revoked',
    'organization.access_changed'
  )
);

alter table public.audit_events drop constraint audit_events_profile_resource_check;
alter table public.audit_events add constraint audit_events_profile_resource_check check (
  (resource_kind = 'profile' and scope_kind = 'profile' and resource_id = scope_id)
  or (
    resource_kind in (
      'organization', 'organization_membership', 'organization_role',
      'organization_role_permission', 'organization_membership_role'
    )
    and scope_kind = 'organization'
  )
);

alter table public.audit_events drop constraint audit_events_reason_code_check;
alter table public.audit_events add constraint audit_events_reason_code_check check (
  reason_code in (
    'AUTH_USER_CREATED', 'PROFILE_FIELDS_CHANGED', 'USER_DELETION_REQUEST',
    'C003A_AUTH_REMOVAL_PREPARED', 'C003A_ANONYMIZATION_FINALIZED',
    'LIFECYCLE_REQUEST_DENIED', 'ORGANIZATION_CREATED', 'ORGANIZATION_UPDATED',
    'MEMBERSHIP_CREATED', 'MEMBERSHIP_STATUS_CHANGED', 'ROLE_CREATED',
    'ROLE_STATUS_CHANGED', 'ROLE_PERMISSION_GRANTED', 'ROLE_PERMISSION_REVOKED',
    'MEMBERSHIP_ROLE_GRANTED', 'MEMBERSHIP_ROLE_REVOKED', 'ACCESS_CHANGED'
  )
);

alter table public.audit_events drop constraint audit_events_metadata_shape_check;
alter table public.audit_events add constraint audit_events_metadata_shape_check check (
  private.c003a_audit_json_keys_allowed(
    metadata,
    array[
      'changed_fields', 'dependency_checks_complete', 'denial_code',
      'operation_code', 'role_code', 'permission_code', 'target_profile_id'
    ]
  )
);

-- Permit a server-side, access-only +1 rotation. Client column ACLs still deny
-- access_version writes; C-003A lifecycle transitions retain their exact rules.
create or replace function public.phase_4a_profile_before_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  business_value_changed boolean;
  access_only_rotation boolean := false;
begin
  new.display_name := coalesce(nullif(pg_catalog.btrim(new.display_name), ''), 'AVARYN user');
  new.first_name := nullif(pg_catalog.btrim(new.first_name), '');
  new.last_name := nullif(pg_catalog.btrim(new.last_name), '');
  new.phone_e164 := nullif(pg_catalog.btrim(new.phone_e164), '');
  new.avatar_object_path := nullif(pg_catalog.btrim(new.avatar_object_path), '');
  new.locale := coalesce(nullif(pg_catalog.btrim(new.locale), ''), 'und');
  new.time_zone := coalesce(nullif(pg_catalog.btrim(new.time_zone), ''), 'UTC');

  if tg_op = 'INSERT' then
    new.id := coalesce(new.id, extensions.gen_random_uuid());
    new.status := coalesce(new.status, 'active');
    new.access_version := coalesce(new.access_version, 1);
    new.row_version := coalesce(new.row_version, 1);
    new.created_at := coalesce(new.created_at, pg_catalog.clock_timestamp());
    new.updated_at := coalesce(new.updated_at, new.created_at);
    if new.status <> 'active' or new.auth_user_id is null
      or new.access_version <> 1 or new.row_version <> 1
      or new.anonymized_at is not null
    then
      raise exception using errcode = '22023', message = 'PROFILE_INSERT_INVALID';
    end if;
    return new;
  end if;

  if new.id is distinct from old.id or new.created_at is distinct from old.created_at
    or new.updated_at is distinct from old.updated_at
    or new.row_version is distinct from old.row_version
  then
    raise exception using errcode = '22023', message = 'PROFILE_TECHNICAL_FIELD_IMMUTABLE';
  end if;

  if new.status = old.status then
    if new.access_version is distinct from old.access_version then
      access_only_rotation := new.access_version = old.access_version + 1
        and row(
          new.auth_user_id, new.first_name, new.last_name, new.display_name,
          new.avatar_object_path, new.phone_e164, new.locale, new.theme_mode,
          new.onboarding_intent, new.onboarding_completed_at,
          new.accepted_terms_version, new.accepted_privacy_version,
          new.time_zone, new.anonymized_at
        ) is not distinct from row(
          old.auth_user_id, old.first_name, old.last_name, old.display_name,
          old.avatar_object_path, old.phone_e164, old.locale, old.theme_mode,
          old.onboarding_intent, old.onboarding_completed_at,
          old.accepted_terms_version, old.accepted_privacy_version,
          old.time_zone, old.anonymized_at
        );
      if not access_only_rotation then
        raise exception using errcode = '22023', message = 'PROFILE_ACCESS_VERSION_INVALID';
      end if;
    end if;
  else
    if not (
      (old.status = 'active' and new.status = 'deletion_pending')
      or (old.status = 'deletion_pending' and new.status = 'auth_removal_pending')
      or (old.status = 'auth_removal_pending' and new.status = 'anonymized')
    ) then
      raise exception using errcode = '22023', message = 'PROFILE_LIFECYCLE_INVALID';
    end if;
    if new.access_version <> old.access_version + 1 then
      raise exception using errcode = '22023', message = 'PROFILE_ACCESS_VERSION_INVALID';
    end if;
  end if;

  if new.auth_user_id is distinct from old.auth_user_id and not (
    old.status = 'auth_removal_pending' and new.status = 'auth_removal_pending'
    and old.auth_user_id is not null and new.auth_user_id is null
  ) then
    raise exception using errcode = '22023', message = 'PROFILE_AUTH_LINK_INVALID';
  end if;

  if new.anonymized_at is distinct from old.anonymized_at and not (
    old.status = 'auth_removal_pending' and new.status = 'anonymized'
    and old.anonymized_at is null and new.anonymized_at is not null
  ) then
    raise exception using errcode = '22023', message = 'PROFILE_ANONYMIZED_AT_INVALID';
  end if;

  business_value_changed := row(
    new.auth_user_id, new.first_name, new.last_name, new.display_name,
    new.avatar_object_path, new.phone_e164, new.locale, new.theme_mode,
    new.onboarding_intent, new.onboarding_completed_at,
    new.accepted_terms_version, new.accepted_privacy_version,
    new.time_zone, new.status, new.access_version, new.anonymized_at
  ) is distinct from row(
    old.auth_user_id, old.first_name, old.last_name, old.display_name,
    old.avatar_object_path, old.phone_e164, old.locale, old.theme_mode,
    old.onboarding_intent, old.onboarding_completed_at,
    old.accepted_terms_version, old.accepted_privacy_version,
    old.time_zone, old.status, old.access_version, old.anonymized_at
  );
  if not business_value_changed then return null; end if;
  new.row_version := old.row_version + 1;
  new.updated_at := pg_catalog.clock_timestamp();
  return new;
end;
$$;

create or replace function private.c003b_touch_catalog_row()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.id is distinct from old.id or new.code is distinct from old.code
    or new.created_at is distinct from old.created_at
  then
    raise exception using errcode = '22023', message = 'CATALOG_IDENTITY_IMMUTABLE';
  end if;
  new.updated_at := pg_catalog.clock_timestamp();
  return new;
end;
$$;

create trigger c003b_organization_types_before_update
before update on public.organization_types for each row
execute function private.c003b_touch_catalog_row();
create trigger c003b_permission_definitions_before_update
before update on public.permission_definitions for each row
execute function private.c003b_touch_catalog_row();

create or replace function private.c003b_assert_primary_admin(p_organization_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare target public.organizations%rowtype;
begin
  select organization.* into target
  from public.organizations organization where organization.id = p_organization_id;
  if not found then return; end if;
  if not exists (
    select 1
    from public.profiles profile
    join public.organization_memberships membership
      on membership.profile_id = profile.id
      and membership.organization_id = target.id
    join public.organization_membership_roles assignment
      on assignment.membership_id = membership.id
      and assignment.organization_id = target.id
    join public.organization_roles role
      on role.id = assignment.role_id and role.organization_id = target.id
    where profile.id = target.primary_admin_profile_id
      and profile.status = 'active'
      and membership.status = 'active'
      and membership.valid_from <= pg_catalog.clock_timestamp()
      and membership.valid_until is null
      and assignment.status = 'active'
      and assignment.valid_from <= pg_catalog.clock_timestamp()
      and assignment.valid_until is null
      and role.code = 'head_admin' and role.status = 'active'
      and role.is_system and role.is_reserved
  ) then
    raise exception using errcode = '23514', message = 'PRIMARY_ADMIN_INVARIANT_VIOLATION';
  end if;
end;
$$;

create or replace function private.c003b_primary_admin_constraint()
returns trigger language plpgsql security definer set search_path = '' as $$
declare org_id uuid;
begin
  if tg_table_name = 'organizations' then org_id := coalesce(new.id, old.id);
  elsif tg_table_name = 'organization_roles' then org_id := coalesce(new.organization_id, old.organization_id);
  elsif tg_table_name = 'organization_memberships' then org_id := coalesce(new.organization_id, old.organization_id);
  elsif tg_table_name = 'organization_membership_roles' then org_id := coalesce(new.organization_id, old.organization_id);
  else
    for org_id in
      select organization.id from public.organizations organization
      where organization.primary_admin_profile_id = coalesce(new.id, old.id)
    loop perform private.c003b_assert_primary_admin(org_id); end loop;
    return coalesce(new, old);
  end if;
  perform private.c003b_assert_primary_admin(org_id);
  return coalesce(new, old);
end;
$$;

create constraint trigger c003b_primary_admin_organizations
after insert or update or delete on public.organizations deferrable initially deferred
for each row execute function private.c003b_primary_admin_constraint();
create constraint trigger c003b_primary_admin_memberships
after insert or update or delete on public.organization_memberships deferrable initially deferred
for each row execute function private.c003b_primary_admin_constraint();
create constraint trigger c003b_primary_admin_roles
after insert or update or delete on public.organization_roles deferrable initially deferred
for each row execute function private.c003b_primary_admin_constraint();
create constraint trigger c003b_primary_admin_assignments
after insert or update or delete on public.organization_membership_roles deferrable initially deferred
for each row execute function private.c003b_primary_admin_constraint();
create constraint trigger c003b_primary_admin_profiles
after update or delete on public.profiles deferrable initially deferred
for each row execute function private.c003b_primary_admin_constraint();

create or replace function private.c003b_write_audit(
  p_event_type text, p_resource_kind text, p_resource_id uuid,
  p_organization_id uuid, p_actor_profile_id uuid, p_correlation_id uuid,
  p_reason_code text, p_old_status text, p_new_status text,
  p_row_before bigint, p_row_after bigint,
  p_access_before bigint, p_access_after bigint,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare event_id uuid;
begin
  if p_event_type not like 'organization.%'
    or p_resource_kind not in (
      'organization', 'organization_membership', 'organization_role',
      'organization_role_permission', 'organization_membership_role'
    )
    or p_actor_profile_id is null or p_organization_id is null
    or p_metadata is null
    or exists (
      select 1 from pg_catalog.jsonb_object_keys(p_metadata) key_name
      where key_name not in (
        'operation_code', 'role_code', 'permission_code', 'target_profile_id'
      )
    )
  then raise exception using errcode = '22023', message = 'C003B_AUDIT_INPUT_INVALID';
  end if;
  insert into public.audit_events (
    actor_kind, actor_profile_id, event_type, resource_kind, resource_id,
    scope_kind, scope_id, old_state, new_state, reason_code, correlation_id,
    channel, row_version_before, row_version_after,
    access_version_before, access_version_after, metadata
  ) values (
    'profile', p_actor_profile_id, p_event_type, p_resource_kind, p_resource_id,
    'organization', p_organization_id,
    case when p_old_status is null then '{}'::jsonb else pg_catalog.jsonb_build_object('status', p_old_status) end,
    case when p_new_status is null then '{}'::jsonb else pg_catalog.jsonb_build_object('status', p_new_status) end,
    p_reason_code, p_correlation_id, 'rpc', p_row_before, p_row_after,
    p_access_before, p_access_after, p_metadata
  ) returning id into event_id;
  return event_id;
end;
$$;

create or replace function private.c003b_actor_profile_id()
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare actor_id uuid;
begin
  actor_id := private.require_current_profile_id();
  if not exists (select 1 from public.profiles profile where profile.id = actor_id and profile.status = 'active')
  then raise exception using errcode = '42501', message = 'ACTIVE_PROFILE_REQUIRED';
  end if;
  return actor_id;
end;
$$;

create or replace function private.c003b_profile_has_permission(
  p_profile_id uuid, p_organization_id uuid, p_permission_code text,
  p_at timestamptz default pg_catalog.statement_timestamp()
)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.profiles profile
    join public.organizations organization on organization.id = p_organization_id
    join public.organization_memberships membership
      on membership.organization_id = organization.id and membership.profile_id = profile.id
    join public.organization_membership_roles assignment
      on assignment.organization_id = organization.id and assignment.membership_id = membership.id
    join public.organization_roles role
      on role.organization_id = organization.id and role.id = assignment.role_id
    join public.organization_role_permissions role_permission
      on role_permission.organization_id = organization.id and role_permission.role_id = role.id
    join public.permission_definitions permission
      on permission.id = role_permission.permission_id
    where profile.id = p_profile_id and profile.status = 'active'
      and organization.status = 'active'
      and membership.status = 'active' and membership.valid_from <= p_at
      and (membership.valid_until is null or membership.valid_until > p_at)
      and assignment.status = 'active' and assignment.valid_from <= p_at
      and (assignment.valid_until is null or assignment.valid_until > p_at)
      and role.status = 'active' and permission.is_active
      and permission.scope_kind = 'organization' and permission.code = p_permission_code
  )
$$;

create or replace function public.has_organization_permission(
  p_organization_id uuid, p_permission_code text
)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.c003b_profile_has_permission(
    private.current_profile_id(), p_organization_id, p_permission_code,
    pg_catalog.statement_timestamp()
  )
$$;

create or replace function private.c003b_bump_access(
  p_organization_id uuid, p_profile_ids uuid[], p_actor_profile_id uuid,
  p_correlation_id uuid, p_operation_code text
)
returns void language plpgsql security definer set search_path = '' as $$
declare before_access bigint; after_access bigint; after_row bigint; profile_id uuid;
begin
  update public.organizations organization set
    access_version = organization.access_version + 1,
    row_version = organization.row_version + 1,
    updated_at = pg_catalog.clock_timestamp()
  where organization.id = p_organization_id
  returning access_version - 1, access_version, row_version
  into before_access, after_access, after_row;
  if not found then raise exception using errcode = 'P0002', message = 'ORGANIZATION_NOT_FOUND'; end if;
  foreach profile_id in array coalesce(p_profile_ids, array[]::uuid[]) loop
    update public.profiles profile set access_version = profile.access_version + 1
    where profile.id = profile_id and profile.status = 'active';
  end loop;
  perform private.c003b_write_audit(
    'organization.access_changed', 'organization', p_organization_id,
    p_organization_id, p_actor_profile_id, p_correlation_id, 'ACCESS_CHANGED',
    null, null, after_row - 1, after_row, before_access, after_access,
    pg_catalog.jsonb_build_object('operation_code', p_operation_code)
  );
end;
$$;

create or replace function public.create_organization(
  p_organization_type_code text, p_name text, p_description text,
  p_correlation_id uuid, p_client_context jsonb default '{}'::jsonb
)
returns table (
  organization_id uuid, membership_id uuid, head_admin_role_id uuid,
  organization_access_version bigint, organization_row_version bigint,
  result_code text, applied boolean
)
language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid; type_id uuid; org_id uuid; member_id uuid; role_id uuid;
  existing public.organizations%rowtype;
begin
  actor_id := private.c003b_actor_profile_id();
  if p_correlation_id is null then raise exception using errcode = '22023', message = 'CORRELATION_ID_REQUIRED'; end if;
  if p_client_context is not null
    and pg_catalog.jsonb_typeof(p_client_context) <> 'object'
  then raise exception using errcode = '22023', message = 'CLIENT_CONTEXT_INVALID'; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor_id::text || p_correlation_id::text, 0));
  select organization.* into existing from public.organizations organization
  where organization.created_by_profile_id = actor_id
    and organization.creation_correlation_id = p_correlation_id;
  if found then
    select membership.id into member_id from public.organization_memberships membership
      where membership.organization_id = existing.id and membership.profile_id = actor_id;
    select role.id into role_id from public.organization_roles role
      where role.organization_id = existing.id and role.code = 'head_admin';
    return query select existing.id, member_id, role_id, existing.access_version,
      existing.row_version, 'idempotent_replay'::text, false;
    return;
  end if;
  select organization_type.id into type_id from public.organization_types organization_type
  where organization_type.code = p_organization_type_code and organization_type.is_active;
  if type_id is null then raise exception using errcode = '22023', message = 'ORGANIZATION_TYPE_INVALID'; end if;
  if pg_catalog.length(pg_catalog.btrim(coalesce(p_name, ''))) not between 1 and 160
  then raise exception using errcode = '22023', message = 'ORGANIZATION_NAME_INVALID'; end if;
  org_id := extensions.gen_random_uuid(); member_id := extensions.gen_random_uuid(); role_id := extensions.gen_random_uuid();
  insert into public.organizations (
    id, organization_type_id, name, description, primary_admin_profile_id,
    created_by_profile_id, creation_correlation_id
  ) values (
    org_id, type_id, pg_catalog.btrim(p_name), nullif(pg_catalog.btrim(p_description), ''),
    actor_id, actor_id, p_correlation_id
  );
  insert into public.organization_memberships (
    id, organization_id, profile_id, created_by_profile_id, creation_correlation_id
  ) values (member_id, org_id, actor_id, actor_id, p_correlation_id);
  insert into public.organization_roles (
    id, organization_id, code, name, description, is_system, is_reserved,
    created_by_profile_id, creation_correlation_id
  ) values (
    role_id, org_id, 'head_admin', 'Head administrator',
    'Reserved primary administrator role.', true, true, actor_id, p_correlation_id
  );
  insert into public.organization_role_permissions (
    organization_id, role_id, permission_id, granted_by_profile_id,
    correlation_id
  ) select org_id, role_id, permission.id, actor_id, extensions.gen_random_uuid()
    from public.permission_definitions permission where permission.is_active;
  insert into public.organization_membership_roles (
    organization_id, membership_id, role_id, granted_by_profile_id,
    creation_correlation_id
  ) values (org_id, member_id, role_id, actor_id, p_correlation_id);
  update public.profiles profile set access_version = profile.access_version + 1 where profile.id = actor_id;
  perform private.c003b_write_audit(
    'organization.created', 'organization', org_id, org_id, actor_id,
    p_correlation_id, 'ORGANIZATION_CREATED', null, 'active', null, 1,
    null, 1, pg_catalog.jsonb_build_object('operation_code', 'create_organization')
  );
  return query select org_id, member_id, role_id, 1::bigint, 1::bigint,
    'created'::text, true;
end;
$$;

create or replace function public.update_organization(
  p_organization_id uuid, p_expected_row_version bigint, p_name text,
  p_description text, p_status text, p_correlation_id uuid
)
returns table (row_version bigint, access_version bigint, status text, applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; before_row public.organizations%rowtype; after_row public.organizations%rowtype; ids uuid[];
begin
  actor_id := private.c003b_actor_profile_id();
  if not private.c003b_profile_has_permission(actor_id, p_organization_id, 'organization.edit')
  then raise exception using errcode = '42501', message = 'ORGANIZATION_PERMISSION_REQUIRED'; end if;
  select * into before_row from public.organizations organization where organization.id = p_organization_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'ORGANIZATION_NOT_FOUND'; end if;
  if before_row.row_version <> p_expected_row_version then raise exception using errcode = '40001', message = 'STALE_ROW_VERSION'; end if;
  if p_status not in ('active', 'archived') then raise exception using errcode = '22023', message = 'ORGANIZATION_STATUS_INVALID'; end if;
  update public.organizations organization set
    name = pg_catalog.btrim(p_name), description = nullif(pg_catalog.btrim(p_description), ''),
    status = p_status, archived_at = case when p_status = 'archived' then coalesce(organization.archived_at, pg_catalog.clock_timestamp()) else null end,
    row_version = organization.row_version + 1, updated_at = pg_catalog.clock_timestamp()
  where organization.id = p_organization_id returning * into after_row;
  if before_row.status is distinct from after_row.status then
    select pg_catalog.array_agg(distinct membership.profile_id) into ids
      from public.organization_memberships membership where membership.organization_id = p_organization_id and membership.status <> 'ended';
    perform private.c003b_bump_access(p_organization_id, ids, actor_id, p_correlation_id, 'organization_status_changed');
    select * into after_row from public.organizations organization where organization.id = p_organization_id;
  end if;
  perform private.c003b_write_audit(
    'organization.updated', 'organization', p_organization_id, p_organization_id,
    actor_id, p_correlation_id, 'ORGANIZATION_UPDATED', before_row.status,
    after_row.status, before_row.row_version, after_row.row_version,
    before_row.access_version, after_row.access_version,
    pg_catalog.jsonb_build_object('operation_code', 'update_organization')
  );
  return query select after_row.row_version, after_row.access_version, after_row.status, true;
end;
$$;

create or replace function public.create_organization_membership(
  p_organization_id uuid, p_profile_id uuid, p_valid_from timestamptz,
  p_correlation_id uuid
)
returns table (membership_id uuid, row_version bigint, result_code text, applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; target_id uuid; prior public.organization_memberships%rowtype;
begin
  actor_id := private.c003b_actor_profile_id();
  if not private.c003b_profile_has_permission(actor_id, p_organization_id, 'organization.memberships.manage')
  then raise exception using errcode = '42501', message = 'ORGANIZATION_PERMISSION_REQUIRED'; end if;
  select membership.* into prior from public.organization_memberships membership
    where membership.created_by_profile_id = actor_id and membership.creation_correlation_id = p_correlation_id;
  if found then return query select prior.id, prior.row_version, 'idempotent_replay'::text, false; return; end if;
  if not exists (select 1 from public.profiles profile where profile.id = p_profile_id and profile.status = 'active')
  then raise exception using errcode = '22023', message = 'TARGET_PROFILE_NOT_ACTIVE'; end if;
  target_id := extensions.gen_random_uuid();
  insert into public.organization_memberships (
    id, organization_id, profile_id, valid_from, created_by_profile_id, creation_correlation_id
  ) values (target_id, p_organization_id, p_profile_id, coalesce(p_valid_from, pg_catalog.clock_timestamp()), actor_id, p_correlation_id);
  perform private.c003b_bump_access(p_organization_id, array[p_profile_id], actor_id, p_correlation_id, 'membership_created');
  perform private.c003b_write_audit(
    'organization.membership_created', 'organization_membership', target_id,
    p_organization_id, actor_id, p_correlation_id, 'MEMBERSHIP_CREATED', null,
    'active', null, 1, null, null,
    pg_catalog.jsonb_build_object('operation_code', 'create_membership', 'target_profile_id', p_profile_id::text)
  );
  return query select target_id, 1::bigint, 'created'::text, true;
end;
$$;

create or replace function public.set_organization_membership_status(
  p_membership_id uuid, p_expected_row_version bigint, p_status text,
  p_reason_code text, p_correlation_id uuid
)
returns table (row_version bigint, status text, applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; before_row public.organization_memberships%rowtype; after_row public.organization_memberships%rowtype; primary_id uuid;
begin
  actor_id := private.c003b_actor_profile_id();
  select membership.* into before_row from public.organization_memberships membership where membership.id = p_membership_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'MEMBERSHIP_NOT_FOUND'; end if;
  if not private.c003b_profile_has_permission(actor_id, before_row.organization_id, 'organization.memberships.manage')
  then raise exception using errcode = '42501', message = 'ORGANIZATION_PERMISSION_REQUIRED'; end if;
  if before_row.row_version <> p_expected_row_version then raise exception using errcode = '40001', message = 'STALE_ROW_VERSION'; end if;
  if p_status not in ('active', 'suspended', 'ended') then raise exception using errcode = '22023', message = 'MEMBERSHIP_STATUS_INVALID'; end if;
  if not ((before_row.status = 'active' and p_status in ('suspended','ended')) or (before_row.status = 'suspended' and p_status in ('active','ended')))
  then raise exception using errcode = '22023', message = 'MEMBERSHIP_LIFECYCLE_INVALID'; end if;
  select organization.primary_admin_profile_id into primary_id from public.organizations organization where organization.id = before_row.organization_id;
  if before_row.profile_id = primary_id and p_status <> 'active'
  then raise exception using errcode = '23514', message = 'PRIMARY_ADMIN_MEMBERSHIP_REQUIRED'; end if;
  update public.organization_memberships membership set
    status = p_status,
    valid_until = case when p_status = 'ended' then pg_catalog.clock_timestamp() else null end,
    ended_reason_code = case when p_status = 'ended' then coalesce(p_reason_code, 'membership_ended') else null end,
    row_version = membership.row_version + 1, updated_at = pg_catalog.clock_timestamp()
  where membership.id = p_membership_id returning * into after_row;
  perform private.c003b_bump_access(before_row.organization_id, array[before_row.profile_id], actor_id, p_correlation_id, 'membership_status_changed');
  perform private.c003b_write_audit(
    'organization.membership_status_changed', 'organization_membership', before_row.id,
    before_row.organization_id, actor_id, p_correlation_id, 'MEMBERSHIP_STATUS_CHANGED',
    before_row.status, after_row.status, before_row.row_version, after_row.row_version,
    null, null, pg_catalog.jsonb_build_object('operation_code', 'set_membership_status', 'target_profile_id', before_row.profile_id::text)
  );
  return query select after_row.row_version, after_row.status, true;
end;
$$;

create or replace function public.create_organization_role(
  p_organization_id uuid, p_code text, p_name text, p_description text,
  p_permission_codes text[], p_correlation_id uuid
)
returns table (role_id uuid, row_version bigint, result_code text, applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; new_id uuid; prior public.organization_roles%rowtype; permission_code text;
begin
  actor_id := private.c003b_actor_profile_id();
  if not private.c003b_profile_has_permission(actor_id, p_organization_id, 'organization.roles.manage')
  then raise exception using errcode = '42501', message = 'ORGANIZATION_PERMISSION_REQUIRED'; end if;
  select role.* into prior from public.organization_roles role where role.created_by_profile_id = actor_id and role.creation_correlation_id = p_correlation_id;
  if found then return query select prior.id, prior.row_version, 'idempotent_replay'::text, false; return; end if;
  if p_code = 'head_admin' then raise exception using errcode = '42501', message = 'RESERVED_ROLE_DENIED'; end if;
  foreach permission_code in array coalesce(p_permission_codes, array[]::text[]) loop
    if not exists (select 1 from public.permission_definitions permission where permission.code = permission_code and permission.is_active and permission.is_grantable)
      or not private.c003b_profile_has_permission(actor_id, p_organization_id, permission_code)
    then raise exception using errcode = '42501', message = 'PERMISSION_GRANT_EXCEEDS_ACTOR'; end if;
  end loop;
  new_id := extensions.gen_random_uuid();
  insert into public.organization_roles (
    id, organization_id, code, name, description, created_by_profile_id, creation_correlation_id
  ) values (new_id, p_organization_id, p_code, p_name, p_description, actor_id, p_correlation_id);
  insert into public.organization_role_permissions (
    organization_id, role_id, permission_id, granted_by_profile_id, correlation_id
  ) select p_organization_id, new_id, permission.id, actor_id, extensions.gen_random_uuid()
    from public.permission_definitions permission where permission.code = any(coalesce(p_permission_codes, array[]::text[]));
  perform private.c003b_write_audit(
    'organization.role_created', 'organization_role', new_id, p_organization_id,
    actor_id, p_correlation_id, 'ROLE_CREATED', null, 'active', null, 1,
    null, null, pg_catalog.jsonb_build_object('operation_code', 'create_role', 'role_code', p_code)
  );
  return query select new_id, 1::bigint, 'created'::text, true;
end;
$$;

create or replace function public.set_organization_role_status(
  p_role_id uuid, p_expected_row_version bigint, p_status text, p_correlation_id uuid
)
returns table (row_version bigint, status text, applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; before_row public.organization_roles%rowtype; after_row public.organization_roles%rowtype; ids uuid[];
begin
  actor_id := private.c003b_actor_profile_id();
  select role.* into before_row from public.organization_roles role where role.id = p_role_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'ROLE_NOT_FOUND'; end if;
  if not private.c003b_profile_has_permission(actor_id, before_row.organization_id, 'organization.roles.manage')
  then raise exception using errcode = '42501', message = 'ORGANIZATION_PERMISSION_REQUIRED'; end if;
  if before_row.is_reserved then raise exception using errcode = '42501', message = 'RESERVED_ROLE_DENIED'; end if;
  if before_row.row_version <> p_expected_row_version then raise exception using errcode = '40001', message = 'STALE_ROW_VERSION'; end if;
  if p_status not in ('active','archived') or p_status = before_row.status
  then raise exception using errcode = '22023', message = 'ROLE_STATUS_INVALID'; end if;
  select pg_catalog.array_agg(distinct membership.profile_id) into ids
  from public.organization_membership_roles assignment
  join public.organization_memberships membership on membership.id = assignment.membership_id
  where assignment.role_id = p_role_id and assignment.status = 'active';
  update public.organization_roles role set status = p_status,
    archived_at = case when p_status = 'archived' then pg_catalog.clock_timestamp() else null end,
    row_version = role.row_version + 1, updated_at = pg_catalog.clock_timestamp()
  where role.id = p_role_id returning * into after_row;
  perform private.c003b_bump_access(before_row.organization_id, ids, actor_id, p_correlation_id, 'role_status_changed');
  perform private.c003b_write_audit(
    'organization.role_status_changed', 'organization_role', p_role_id,
    before_row.organization_id, actor_id, p_correlation_id, 'ROLE_STATUS_CHANGED',
    before_row.status, after_row.status, before_row.row_version, after_row.row_version,
    null, null, pg_catalog.jsonb_build_object('operation_code', 'set_role_status', 'role_code', before_row.code)
  );
  return query select after_row.row_version, after_row.status, true;
end;
$$;

create or replace function public.set_organization_role_permission(
  p_role_id uuid, p_expected_role_row_version bigint,
  p_permission_code text, p_grant boolean, p_correlation_id uuid
)
returns table (
  permission_code text, granted boolean, role_row_version bigint,
  applied boolean
)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; role_row public.organization_roles%rowtype; target_permission_id uuid; ids uuid[]; changed integer;
begin
  actor_id := private.c003b_actor_profile_id();
  select role.* into role_row from public.organization_roles role where role.id = p_role_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'ROLE_NOT_FOUND'; end if;
  if not private.c003b_profile_has_permission(actor_id, role_row.organization_id, 'organization.roles.manage')
  then raise exception using errcode = '42501', message = 'ORGANIZATION_PERMISSION_REQUIRED'; end if;
  if role_row.is_reserved then raise exception using errcode = '42501', message = 'RESERVED_ROLE_DENIED'; end if;
  if role_row.row_version <> p_expected_role_row_version
  then raise exception using errcode = '40001', message = 'STALE_ROW_VERSION'; end if;
  select permission.id into target_permission_id from public.permission_definitions permission
    where permission.code = p_permission_code and permission.is_active and permission.is_grantable;
  if target_permission_id is null or not private.c003b_profile_has_permission(actor_id, role_row.organization_id, p_permission_code)
  then raise exception using errcode = '42501', message = 'PERMISSION_GRANT_EXCEEDS_ACTOR'; end if;
  if p_grant then
    insert into public.organization_role_permissions (organization_id, role_id, permission_id, granted_by_profile_id, correlation_id)
    values (role_row.organization_id, role_row.id, target_permission_id, actor_id, p_correlation_id)
    on conflict (role_id, permission_id) do nothing;
  else
    delete from public.organization_role_permissions role_permission
      where role_permission.role_id = role_row.id
        and role_permission.permission_id = target_permission_id;
  end if;
  get diagnostics changed = row_count;
  if changed > 0 then
    update public.organization_roles role set
      row_version = role.row_version + 1,
      updated_at = pg_catalog.clock_timestamp()
    where role.id = role_row.id
    returning * into role_row;
    select pg_catalog.array_agg(distinct membership.profile_id) into ids
    from public.organization_membership_roles assignment
    join public.organization_memberships membership on membership.id = assignment.membership_id
    where assignment.role_id = p_role_id and assignment.status = 'active';
    perform private.c003b_bump_access(role_row.organization_id, ids, actor_id, p_correlation_id, 'role_permission_changed');
    perform private.c003b_write_audit(
      case when p_grant then 'organization.role_permission_granted' else 'organization.role_permission_revoked' end,
      'organization_role_permission', role_row.id, role_row.organization_id, actor_id,
      p_correlation_id, case when p_grant then 'ROLE_PERMISSION_GRANTED' else 'ROLE_PERMISSION_REVOKED' end,
      null, null, null, null, null, null,
      pg_catalog.jsonb_build_object('operation_code', 'set_role_permission', 'role_code', role_row.code, 'permission_code', p_permission_code)
    );
  end if;
  return query select p_permission_code, p_grant, role_row.row_version, changed > 0;
end;
$$;

create or replace function public.grant_organization_membership_role(
  p_membership_id uuid, p_role_id uuid, p_valid_from timestamptz, p_correlation_id uuid
)
returns table (assignment_id uuid, row_version bigint, result_code text, applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; membership public.organization_memberships%rowtype; role_row public.organization_roles%rowtype; prior public.organization_membership_roles%rowtype; new_id uuid;
begin
  actor_id := private.c003b_actor_profile_id();
  select * into membership from public.organization_memberships value where value.id = p_membership_id;
  select * into role_row from public.organization_roles role where role.id = p_role_id;
  if membership.id is null or role_row.id is null or membership.organization_id <> role_row.organization_id
  then raise exception using errcode = '22023', message = 'ROLE_MEMBERSHIP_SCOPE_MISMATCH'; end if;
  if not private.c003b_profile_has_permission(actor_id, membership.organization_id, 'organization.roles.manage')
  then raise exception using errcode = '42501', message = 'ORGANIZATION_PERMISSION_REQUIRED'; end if;
  if role_row.is_reserved then raise exception using errcode = '42501', message = 'RESERVED_ROLE_DENIED'; end if;
  if membership.status <> 'active' or role_row.status <> 'active'
  then raise exception using errcode = '22023', message = 'ACTIVE_MEMBERSHIP_AND_ROLE_REQUIRED'; end if;
  if exists (
    select 1 from public.organization_role_permissions rp
    join public.permission_definitions permission on permission.id = rp.permission_id
    where rp.role_id = role_row.id and (
      not permission.is_grantable
      or not private.c003b_profile_has_permission(actor_id, membership.organization_id, permission.code)
    )
  ) then raise exception using errcode = '42501', message = 'PERMISSION_GRANT_EXCEEDS_ACTOR'; end if;
  select assignment.* into prior from public.organization_membership_roles assignment
    where assignment.granted_by_profile_id = actor_id and assignment.creation_correlation_id = p_correlation_id;
  if found then return query select prior.id, prior.row_version, 'idempotent_replay'::text, false; return; end if;
  new_id := extensions.gen_random_uuid();
  insert into public.organization_membership_roles (
    id, organization_id, membership_id, role_id, valid_from,
    granted_by_profile_id, creation_correlation_id
  ) values (new_id, membership.organization_id, membership.id, role_row.id,
    coalesce(p_valid_from, pg_catalog.clock_timestamp()), actor_id, p_correlation_id);
  perform private.c003b_bump_access(membership.organization_id, array[membership.profile_id], actor_id, p_correlation_id, 'membership_role_granted');
  perform private.c003b_write_audit(
    'organization.membership_role_granted', 'organization_membership_role', new_id,
    membership.organization_id, actor_id, p_correlation_id, 'MEMBERSHIP_ROLE_GRANTED',
    null, 'active', null, 1, null, null,
    pg_catalog.jsonb_build_object('operation_code', 'grant_membership_role', 'role_code', role_row.code, 'target_profile_id', membership.profile_id::text)
  );
  return query select new_id, 1::bigint, 'granted'::text, true;
end;
$$;

create or replace function public.revoke_organization_membership_role(
  p_assignment_id uuid, p_expected_row_version bigint, p_end boolean,
  p_correlation_id uuid
)
returns table (row_version bigint, status text, applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; before_row public.organization_membership_roles%rowtype; after_row public.organization_membership_roles%rowtype; membership public.organization_memberships%rowtype; role_row public.organization_roles%rowtype;
begin
  actor_id := private.c003b_actor_profile_id();
  select assignment.* into before_row from public.organization_membership_roles assignment where assignment.id = p_assignment_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'ASSIGNMENT_NOT_FOUND'; end if;
  select * into membership from public.organization_memberships value where value.id = before_row.membership_id;
  select * into role_row from public.organization_roles role where role.id = before_row.role_id;
  if not private.c003b_profile_has_permission(actor_id, before_row.organization_id, 'organization.roles.manage')
  then raise exception using errcode = '42501', message = 'ORGANIZATION_PERMISSION_REQUIRED'; end if;
  if role_row.is_reserved then raise exception using errcode = '42501', message = 'RESERVED_ROLE_DENIED'; end if;
  if before_row.row_version <> p_expected_row_version then raise exception using errcode = '40001', message = 'STALE_ROW_VERSION'; end if;
  if before_row.status <> 'active' then raise exception using errcode = '22023', message = 'ASSIGNMENT_NOT_ACTIVE'; end if;
  update public.organization_membership_roles assignment set
    status = case when p_end then 'ended' else 'revoked' end,
    valid_until = pg_catalog.clock_timestamp(),
    ended_reason_code = case when p_end then 'role_ended' else 'role_revoked' end,
    revoked_by_profile_id = actor_id, row_version = assignment.row_version + 1,
    updated_at = pg_catalog.clock_timestamp()
  where assignment.id = p_assignment_id returning * into after_row;
  perform private.c003b_bump_access(before_row.organization_id, array[membership.profile_id], actor_id, p_correlation_id, 'membership_role_revoked');
  perform private.c003b_write_audit(
    'organization.membership_role_revoked', 'organization_membership_role', before_row.id,
    before_row.organization_id, actor_id, p_correlation_id, 'MEMBERSHIP_ROLE_REVOKED',
    before_row.status, after_row.status, before_row.row_version, after_row.row_version,
    null, null, pg_catalog.jsonb_build_object('operation_code', 'revoke_membership_role', 'role_code', role_row.code, 'target_profile_id', membership.profile_id::text)
  );
  return query select after_row.row_version, after_row.status, true;
end;
$$;

-- RLS is mandatory on every new authorization table. Critical writes have no
-- client policy and no table DML grant; all changes pass through RPCs.
alter table public.organization_types enable row level security;
alter table public.permission_definitions enable row level security;
alter table public.organizations enable row level security;
alter table public.organization_memberships enable row level security;
alter table public.organization_roles enable row level security;
alter table public.organization_role_permissions enable row level security;
alter table public.organization_membership_roles enable row level security;

create policy organization_types_read on public.organization_types for select to authenticated
using (is_active);
create policy permission_definitions_read on public.permission_definitions for select to authenticated
using (is_active and scope_kind = 'organization');
create policy organizations_read on public.organizations for select to authenticated
using (public.has_organization_permission(id, 'organization.view'));
create policy organization_memberships_read on public.organization_memberships for select to authenticated
using (
  profile_id = private.current_profile_id()
  or public.has_organization_permission(organization_id, 'organization.memberships.view')
);
create policy organization_roles_read on public.organization_roles for select to authenticated
using (public.has_organization_permission(organization_id, 'organization.roles.view'));
create policy organization_role_permissions_read on public.organization_role_permissions for select to authenticated
using (public.has_organization_permission(organization_id, 'organization.roles.view'));
create policy organization_membership_roles_read on public.organization_membership_roles for select to authenticated
using (
  exists (
    select 1 from public.organization_memberships membership
    where membership.id = membership_id and membership.profile_id = private.current_profile_id()
  )
  or public.has_organization_permission(organization_id, 'organization.memberships.view')
);
create policy c003b_organization_audit_read on public.audit_events for select to authenticated
using (
  scope_kind = 'organization'
  and public.has_organization_permission(scope_id, 'organization.audit.view')
);

revoke all on table public.organization_types from public, anon, authenticated, service_role;
revoke all on table public.permission_definitions from public, anon, authenticated, service_role;
revoke all on table public.organizations from public, anon, authenticated, service_role;
revoke all on table public.organization_memberships from public, anon, authenticated, service_role;
revoke all on table public.organization_roles from public, anon, authenticated, service_role;
revoke all on table public.organization_role_permissions from public, anon, authenticated, service_role;
revoke all on table public.organization_membership_roles from public, anon, authenticated, service_role;
grant select on public.organization_types, public.permission_definitions,
  public.organizations, public.organization_memberships, public.organization_roles,
  public.organization_role_permissions, public.organization_membership_roles
to authenticated;

revoke execute on function public.has_organization_permission(uuid, text) from public, anon, authenticated, service_role;
grant execute on function public.has_organization_permission(uuid, text) to authenticated;
revoke execute on function public.create_organization(text, text, text, uuid, jsonb) from public, anon, authenticated, service_role;
grant execute on function public.create_organization(text, text, text, uuid, jsonb) to authenticated;
revoke execute on function public.update_organization(uuid, bigint, text, text, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.update_organization(uuid, bigint, text, text, text, uuid) to authenticated;
revoke execute on function public.create_organization_membership(uuid, uuid, timestamptz, uuid) from public, anon, authenticated, service_role;
grant execute on function public.create_organization_membership(uuid, uuid, timestamptz, uuid) to authenticated;
revoke execute on function public.set_organization_membership_status(uuid, bigint, text, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.set_organization_membership_status(uuid, bigint, text, text, uuid) to authenticated;
revoke execute on function public.create_organization_role(uuid, text, text, text, text[], uuid) from public, anon, authenticated, service_role;
grant execute on function public.create_organization_role(uuid, text, text, text, text[], uuid) to authenticated;
revoke execute on function public.set_organization_role_status(uuid, bigint, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.set_organization_role_status(uuid, bigint, text, uuid) to authenticated;
revoke execute on function public.set_organization_role_permission(uuid, bigint, text, boolean, uuid) from public, anon, authenticated, service_role;
grant execute on function public.set_organization_role_permission(uuid, bigint, text, boolean, uuid) to authenticated;
revoke execute on function public.grant_organization_membership_role(uuid, uuid, timestamptz, uuid) from public, anon, authenticated, service_role;
grant execute on function public.grant_organization_membership_role(uuid, uuid, timestamptz, uuid) to authenticated;
revoke execute on function public.revoke_organization_membership_role(uuid, bigint, boolean, uuid) from public, anon, authenticated, service_role;
grant execute on function public.revoke_organization_membership_role(uuid, bigint, boolean, uuid) to authenticated;

revoke execute on function private.c003b_touch_catalog_row() from public, anon, authenticated, service_role;
revoke execute on function private.c003b_assert_primary_admin(uuid) from public, anon, authenticated, service_role;
revoke execute on function private.c003b_primary_admin_constraint() from public, anon, authenticated, service_role;
revoke execute on function private.c003b_write_audit(text,text,uuid,uuid,uuid,uuid,text,text,text,bigint,bigint,bigint,bigint,jsonb) from public, anon, authenticated, service_role;
revoke execute on function private.c003b_actor_profile_id() from public, anon, authenticated, service_role;
revoke execute on function private.c003b_profile_has_permission(uuid,uuid,text,timestamptz) from public, anon, authenticated, service_role;
revoke execute on function private.c003b_bump_access(uuid,uuid[],uuid,uuid,text) from public, anon, authenticated, service_role;

comment on table public.organizations is 'C-003B server-authoritative organization aggregate; legacy stable_id grants no access.';
comment on column public.organizations.primary_admin_profile_id is 'Mandatory scalar primary administrator, backed by a deferred membership/head-admin invariant.';
comment on function public.create_organization(text,text,text,uuid,jsonb) is 'Atomic idempotent C-003B create; actor and primary administrator are always derived from auth.uid().';
comment on function public.has_organization_permission(uuid,text) is 'PII-free boolean RLS helper; evaluates current profile, organization, membership, role and permission sources.';
