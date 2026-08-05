-- C-003C — Canonical horses and relationships
-- `public.horses` is the immutable legacy stable-scoped aggregate. C-003C is
-- deliberately isolated in `canonical_horses`; no legacy stable_id is an
-- authority source for this model.

create table public.canonical_horses (
  id uuid primary key default extensions.gen_random_uuid(),
  primary_authority_profile_id uuid not null
    references public.profiles(id) on delete restrict,
  display_name text not null,
  birth_date date,
  sex text not null default 'unknown',
  breed text,
  status text not null default 'active',
  access_version bigint not null default 1,
  authority_version bigint not null default 1,
  row_version bigint not null default 1,
  created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  creation_correlation_id uuid not null,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  archived_at timestamptz,
  constraint canonical_horses_name_check
    check (pg_catalog.length(pg_catalog.btrim(display_name)) between 1 and 160),
  constraint canonical_horses_sex_check
    check (sex in ('mare','gelding','stallion','unknown')),
  constraint canonical_horses_breed_check
    check (breed is null or pg_catalog.length(pg_catalog.btrim(breed)) between 1 and 160),
  constraint canonical_horses_status_check check (status in ('active','archived')),
  constraint canonical_horses_archive_shape_check
    check ((status = 'archived') = (archived_at is not null)),
  constraint canonical_horses_versions_check
    check (access_version >= 1 and authority_version >= 1 and row_version >= 1),
  constraint canonical_horses_creation_idempotency_unique
    unique (created_by_profile_id, creation_correlation_id)
);

create table public.horse_delegated_administrators (
  id uuid primary key default extensions.gen_random_uuid(),
  horse_id uuid not null references public.canonical_horses(id) on delete restrict,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  granted_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  permission_codes text[] not null,
  status text not null default 'active',
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  ended_reason_code text,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint horse_delegated_permissions_check check (
    pg_catalog.cardinality(permission_codes) between 1 and 5
    and permission_codes <@ array['horse.view','horse.edit','horse.manage','horse.assign','horse.share']::text[]
  ),
  constraint horse_delegated_status_check check (status in ('active','ended')),
  constraint horse_delegated_time_check check (valid_until is null or valid_until > valid_from),
  constraint horse_delegated_end_shape_check check (
    (status = 'ended' and valid_until is not null and ended_reason_code is not null)
    or (status = 'active' and ended_reason_code is null)
  ),
  constraint horse_delegated_row_version_check check (row_version >= 1),
  constraint horse_delegated_creation_unique unique (granted_by_profile_id, creation_correlation_id),
  constraint horse_delegated_no_overlap exclude using gist (
    horse_id with =, profile_id with =,
    tstzrange(valid_from, coalesce(valid_until, 'infinity'::timestamptz), '[)') with &&
  ) where (status = 'active')
);

create table public.horse_person_ownerships (
  id uuid primary key default extensions.gen_random_uuid(),
  horse_id uuid not null references public.canonical_horses(id) on delete restrict,
  owner_profile_id uuid not null references public.profiles(id) on delete restrict,
  ownership_percentage numeric(5,2),
  status text not null default 'active',
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  disclaimer_code text not null default 'LEGAL_RELATIONSHIP_ONLY',
  created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint horse_person_ownership_percentage_check
    check (ownership_percentage is null or ownership_percentage between 0 and 100),
  constraint horse_person_ownership_status_check check (status in ('active','ended')),
  constraint horse_person_ownership_time_check check (valid_until is null or valid_until > valid_from),
  constraint horse_person_ownership_end_shape_check
    check ((status = 'ended') = (valid_until is not null)),
  constraint horse_person_ownership_disclaimer_check
    check (disclaimer_code = 'LEGAL_RELATIONSHIP_ONLY'),
  constraint horse_person_ownership_row_version_check check (row_version >= 1),
  constraint horse_person_ownership_creation_unique unique (created_by_profile_id, creation_correlation_id),
  constraint horse_person_ownership_no_overlap exclude using gist (
    horse_id with =, owner_profile_id with =,
    tstzrange(valid_from, coalesce(valid_until, 'infinity'::timestamptz), '[)') with &&
  ) where (status = 'active')
);

create table public.horse_organization_ownerships (
  id uuid primary key default extensions.gen_random_uuid(),
  horse_id uuid not null references public.canonical_horses(id) on delete restrict,
  owner_organization_id uuid not null references public.organizations(id) on delete restrict,
  ownership_percentage numeric(5,2),
  status text not null default 'active',
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  disclaimer_code text not null default 'LEGAL_RELATIONSHIP_ONLY',
  created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint horse_org_ownership_percentage_check
    check (ownership_percentage is null or ownership_percentage between 0 and 100),
  constraint horse_org_ownership_status_check check (status in ('active','ended')),
  constraint horse_org_ownership_time_check check (valid_until is null or valid_until > valid_from),
  constraint horse_org_ownership_end_shape_check check ((status = 'ended') = (valid_until is not null)),
  constraint horse_org_ownership_disclaimer_check check (disclaimer_code = 'LEGAL_RELATIONSHIP_ONLY'),
  constraint horse_org_ownership_row_version_check check (row_version >= 1),
  constraint horse_org_ownership_creation_unique unique (created_by_profile_id, creation_correlation_id),
  constraint horse_org_ownership_no_overlap exclude using gist (
    horse_id with =, owner_organization_id with =,
    tstzrange(valid_from, coalesce(valid_until, 'infinity'::timestamptz), '[)') with &&
  ) where (status = 'active')
);

create table public.horse_relationship_types (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique,
  label text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint horse_relationship_types_code_check check (code ~ '^[a-z][a-z0-9_]{1,62}$'),
  constraint horse_relationship_types_label_check check (pg_catalog.length(pg_catalog.btrim(label)) between 1 and 120)
);

insert into public.horse_relationship_types (code, label) values
  ('rider','Rider'), ('trainer','Trainer'), ('groom','Groom'),
  ('care_provider','Care provider'), ('professional_treatment','Professional treatment');

create table public.horse_person_relationships (
  id uuid primary key default extensions.gen_random_uuid(),
  horse_id uuid not null references public.canonical_horses(id) on delete restrict,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  relationship_type_id uuid not null references public.horse_relationship_types(id) on delete restrict,
  status text not null default 'active',
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint horse_person_relationship_status_check check (status in ('active','ended')),
  constraint horse_person_relationship_time_check check (valid_until is null or valid_until > valid_from),
  constraint horse_person_relationship_end_shape_check check ((status = 'ended') = (valid_until is not null)),
  constraint horse_person_relationship_row_version_check check (row_version >= 1),
  constraint horse_person_relationship_creation_unique unique (created_by_profile_id, creation_correlation_id),
  constraint horse_person_relationship_no_overlap exclude using gist (
    horse_id with =, profile_id with =, relationship_type_id with =,
    tstzrange(valid_from, coalesce(valid_until, 'infinity'::timestamptz), '[)') with &&
  ) where (status = 'active')
);

create table public.organization_horse_link_types (
  id uuid primary key default extensions.gen_random_uuid(),
  code text not null unique,
  label text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint organization_horse_link_types_code_check check (code ~ '^[a-z][a-z0-9_]{1,62}$'),
  constraint organization_horse_link_types_label_check check (pg_catalog.length(pg_catalog.btrim(label)) between 1 and 120)
);

insert into public.organization_horse_link_types (code, label) values
  ('training_provider','Training provider'), ('veterinary_provider','Veterinary provider'),
  ('farrier_provider','Farrier provider'), ('care_provider','Care provider'), ('other','Other');

create table public.organization_horse_links (
  id uuid primary key default extensions.gen_random_uuid(),
  horse_id uuid not null references public.canonical_horses(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  link_type_id uuid not null references public.organization_horse_link_types(id) on delete restrict,
  status text not null default 'proposed',
  initiating_context text not null,
  initiated_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  horse_confirmed_by_profile_id uuid references public.profiles(id) on delete restrict,
  horse_confirmed_at timestamptz,
  organization_confirmed_by_profile_id uuid references public.profiles(id) on delete restrict,
  organization_confirmed_at timestamptz,
  proposed_at timestamptz not null default pg_catalog.clock_timestamp(),
  expires_at timestamptz not null,
  ended_at timestamptz,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint organization_horse_links_status_check
    check (status in ('proposed','active','rejected','withdrawn','expired','ended')),
  constraint organization_horse_links_context_check check (initiating_context in ('horse','organization')),
  constraint organization_horse_links_expiry_check check (expires_at = proposed_at + interval '7 days'),
  constraint organization_horse_links_horse_confirmation_shape check (
    (horse_confirmed_at is null and horse_confirmed_by_profile_id is null)
    or (horse_confirmed_at is not null and horse_confirmed_by_profile_id is not null)
  ),
  constraint organization_horse_links_org_confirmation_shape check (
    (organization_confirmed_at is null and organization_confirmed_by_profile_id is null)
    or (organization_confirmed_at is not null and organization_confirmed_by_profile_id is not null)
  ),
  constraint organization_horse_links_active_shape check (
    (status = 'active' and horse_confirmed_at is not null and organization_confirmed_at is not null and ended_at is null)
    or (status = 'proposed' and ended_at is null)
    or (status in ('rejected','withdrawn','expired','ended') and ended_at is not null)
  ),
  constraint organization_horse_links_initial_confirmation_check check (
    status <> 'proposed'
    or (initiating_context = 'horse' and horse_confirmed_at is not null and organization_confirmed_at is null)
    or (initiating_context = 'organization' and organization_confirmed_at is not null and horse_confirmed_at is null)
  ),
  constraint organization_horse_links_row_version_check check (row_version >= 1),
  constraint organization_horse_links_creation_unique unique (initiated_by_profile_id, creation_correlation_id)
);

create unique index organization_horse_links_one_open_idx
  on public.organization_horse_links(horse_id, organization_id, link_type_id)
  where status in ('proposed','active');

create table public.horse_residencies (
  id uuid primary key default extensions.gen_random_uuid(),
  horse_id uuid not null references public.canonical_horses(id) on delete restrict,
  stable_organization_id uuid not null references public.organizations(id) on delete restrict,
  status text not null default 'active',
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint horse_residencies_status_check check (status in ('planned','active','ended','cancelled')),
  constraint horse_residencies_time_check check (valid_until is null or valid_until > valid_from),
  constraint horse_residencies_end_shape_check
    check ((status in ('ended','cancelled')) = (valid_until is not null)),
  constraint horse_residencies_row_version_check check (row_version >= 1),
  constraint horse_residencies_creation_unique unique (created_by_profile_id, creation_correlation_id)
);

create unique index horse_residencies_one_active_idx on public.horse_residencies(horse_id) where status = 'active';
create index horse_delegated_profile_idx on public.horse_delegated_administrators(profile_id, horse_id);
create index horse_person_ownership_owner_idx on public.horse_person_ownerships(owner_profile_id, horse_id);
create index horse_org_ownership_org_idx on public.horse_organization_ownerships(owner_organization_id, horse_id);
create index horse_person_relationship_profile_idx on public.horse_person_relationships(profile_id, horse_id);
create index organization_horse_links_org_idx on public.organization_horse_links(organization_id, status);
create index horse_residencies_stable_idx on public.horse_residencies(stable_organization_id, status);

-- Extend the append-only C-003A audit allowlists for PII-free horse events.
alter table public.audit_events drop constraint audit_events_event_type_check;
alter table public.audit_events add constraint audit_events_event_type_check check (event_type in (
  'profile.provisioned','profile.display_fields_updated','profile.deletion_requested',
  'profile.auth_removal_prepared','profile.anonymization_finalized','profile.lifecycle_denied',
  'organization.created','organization.updated','organization.membership_created',
  'organization.membership_status_changed','organization.role_created','organization.role_status_changed',
  'organization.role_permission_granted','organization.role_permission_revoked',
  'organization.membership_role_granted','organization.membership_role_revoked','organization.access_changed',
  'horse.created','horse.updated','horse.access_changed','horse.delegation_granted','horse.delegation_ended',
  'horse.person_ownership_started','horse.person_ownership_ended',
  'horse.organization_ownership_started','horse.organization_ownership_ended',
  'horse.person_relationship_started','horse.person_relationship_ended',
  'horse.organization_link_proposed','horse.organization_link_activated','horse.organization_link_rejected',
  'horse.organization_link_withdrawn','horse.organization_link_expired','horse.organization_link_ended',
  'horse.residency_started','horse.residency_switched','horse.residency_ended'
));

alter table public.audit_events drop constraint audit_events_profile_resource_check;
alter table public.audit_events add constraint audit_events_profile_resource_check check (
  (resource_kind = 'profile' and scope_kind = 'profile' and resource_id = scope_id)
  or (resource_kind in ('organization','organization_membership','organization_role',
      'organization_role_permission','organization_membership_role') and scope_kind = 'organization')
  or (resource_kind in ('horse','horse_delegation','horse_person_ownership',
      'horse_organization_ownership','horse_person_relationship','organization_horse_link',
      'horse_residency') and scope_kind = 'horse')
);

alter table public.audit_events drop constraint audit_events_reason_code_check;
alter table public.audit_events add constraint audit_events_reason_code_check check (reason_code in (
  'AUTH_USER_CREATED','PROFILE_FIELDS_CHANGED','USER_DELETION_REQUEST','C003A_AUTH_REMOVAL_PREPARED',
  'C003A_ANONYMIZATION_FINALIZED','LIFECYCLE_REQUEST_DENIED','ORGANIZATION_CREATED','ORGANIZATION_UPDATED',
  'MEMBERSHIP_CREATED','MEMBERSHIP_STATUS_CHANGED','ROLE_CREATED','ROLE_STATUS_CHANGED',
  'ROLE_PERMISSION_GRANTED','ROLE_PERMISSION_REVOKED','MEMBERSHIP_ROLE_GRANTED','MEMBERSHIP_ROLE_REVOKED',
  'ACCESS_CHANGED','HORSE_CREATED','HORSE_UPDATED','DELEGATION_GRANTED','DELEGATION_ENDED',
  'PERSON_OWNERSHIP_STARTED','PERSON_OWNERSHIP_ENDED','ORGANIZATION_OWNERSHIP_STARTED',
  'ORGANIZATION_OWNERSHIP_ENDED','PERSON_RELATIONSHIP_STARTED','PERSON_RELATIONSHIP_ENDED',
  'ORGANIZATION_LINK_PROPOSED','ORGANIZATION_LINK_ACTIVATED','ORGANIZATION_LINK_REJECTED',
  'ORGANIZATION_LINK_WITHDRAWN','ORGANIZATION_LINK_EXPIRED','ORGANIZATION_LINK_ENDED',
  'RESIDENCY_STARTED','RESIDENCY_SWITCHED','RESIDENCY_ENDED'
));

alter table public.audit_events drop constraint audit_events_metadata_shape_check;
alter table public.audit_events add constraint audit_events_metadata_shape_check check (
  private.c003a_audit_json_keys_allowed(metadata, array[
    'changed_fields','dependency_checks_complete','denial_code','operation_code','role_code',
    'permission_code','target_profile_id','permission_codes','organization_id',
    'relationship_type','link_type','initiating_context'
  ])
);

create or replace function private.c003c_touch_catalog_row()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.id is distinct from old.id or new.code is distinct from old.code or new.created_at is distinct from old.created_at
  then raise exception using errcode = '22023', message = 'CATALOG_IDENTITY_IMMUTABLE'; end if;
  new.updated_at := pg_catalog.clock_timestamp();
  return new;
end;
$$;

create trigger c003c_horse_relationship_types_before_update before update on public.horse_relationship_types
for each row execute function private.c003c_touch_catalog_row();
create trigger c003c_organization_horse_link_types_before_update before update on public.organization_horse_link_types
for each row execute function private.c003c_touch_catalog_row();

create or replace function private.c003c_guard_horse_authority()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.id is distinct from old.id
    or new.primary_authority_profile_id is distinct from old.primary_authority_profile_id
    or new.authority_version is distinct from old.authority_version
    or new.created_by_profile_id is distinct from old.created_by_profile_id
    or new.creation_correlation_id is distinct from old.creation_correlation_id
    or new.created_at is distinct from old.created_at
  then raise exception using errcode = '42501', message = 'HORSE_AUTHORITY_FIELDS_IMMUTABLE_IN_C003C'; end if;
  if new.access_version not in (old.access_version, old.access_version + 1)
    or new.row_version <> old.row_version + 1
  then raise exception using errcode = '22023', message = 'HORSE_VERSION_TRANSITION_INVALID'; end if;
  return new;
end;
$$;

create trigger c003c_canonical_horses_before_update before update on public.canonical_horses
for each row execute function private.c003c_guard_horse_authority();

create or replace function private.c003c_assert_primary_authority(p_horse_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare horse public.canonical_horses%rowtype;
begin
  select h.* into horse from public.canonical_horses h where h.id=p_horse_id;
  if not found then return; end if;
  if not exists(select 1 from public.profiles p where p.id=horse.primary_authority_profile_id and p.status='active')
  then raise exception using errcode='23514',message='ACTIVE_PRIMARY_HORSE_AUTHORITY_REQUIRED'; end if;
end;
$$;

create or replace function private.c003c_primary_authority_constraint()
returns trigger language plpgsql security definer set search_path = '' as $$
declare horse_id uuid;
begin
  if tg_table_name='canonical_horses' then
    horse_id:=coalesce(new.id,old.id);
    perform private.c003c_assert_primary_authority(horse_id);
  else
    for horse_id in select h.id from public.canonical_horses h
      where h.primary_authority_profile_id=coalesce(new.id,old.id)
    loop perform private.c003c_assert_primary_authority(horse_id); end loop;
  end if;
  return coalesce(new,old);
end;
$$;

create constraint trigger c003c_primary_authority_horses
after insert or update or delete on public.canonical_horses deferrable initially deferred
for each row execute function private.c003c_primary_authority_constraint();
create constraint trigger c003c_primary_authority_profiles
after update or delete on public.profiles deferrable initially deferred
for each row execute function private.c003c_primary_authority_constraint();

create or replace function private.c003c_actor_profile_id()
returns uuid language plpgsql stable security definer set search_path = '' as $$
declare actor_id uuid;
begin
  actor_id := private.require_current_profile_id();
  if not exists (select 1 from public.profiles p where p.id = actor_id and p.status = 'active')
  then raise exception using errcode = '42501', message = 'ACTIVE_PROFILE_REQUIRED'; end if;
  return actor_id;
end;
$$;

create or replace function private.c003c_profile_has_horse_permission(
  p_profile_id uuid, p_horse_id uuid, p_permission_code text,
  p_at timestamptz default pg_catalog.statement_timestamp()
)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_permission_code in ('horse.view','horse.edit','horse.manage','horse.assign','horse.share','horse.transfer')
    and exists (
      select 1 from public.profiles profile
      join public.canonical_horses horse on horse.id = p_horse_id
      where profile.id = p_profile_id and profile.status = 'active'
        and (
          horse.primary_authority_profile_id = profile.id
          or (p_permission_code <> 'horse.transfer' and exists (
            select 1 from public.horse_delegated_administrators delegation
            where delegation.horse_id = horse.id and delegation.profile_id = profile.id
              and delegation.status = 'active' and delegation.valid_from <= p_at
              and (delegation.valid_until is null or delegation.valid_until > p_at)
              and p_permission_code = any(delegation.permission_codes)
          ))
        )
    )
$$;

create or replace function public.has_canonical_horse_permission(p_horse_id uuid, p_permission_code text)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.c003c_profile_has_horse_permission(
    private.current_profile_id(), p_horse_id, p_permission_code, pg_catalog.statement_timestamp()
  )
$$;

create or replace function private.c003c_write_audit(
  p_event_type text, p_resource_kind text, p_resource_id uuid, p_horse_id uuid,
  p_actor_profile_id uuid, p_correlation_id uuid, p_reason_code text,
  p_old_status text, p_new_status text, p_row_before bigint, p_row_after bigint,
  p_access_before bigint, p_access_after bigint, p_metadata jsonb default '{}'::jsonb
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare event_id uuid;
begin
  if p_event_type not like 'horse.%' or p_resource_kind not in (
    'horse','horse_delegation','horse_person_ownership','horse_organization_ownership',
    'horse_person_relationship','organization_horse_link','horse_residency'
  ) or p_actor_profile_id is null or p_horse_id is null or p_metadata is null
  or exists (select 1 from pg_catalog.jsonb_object_keys(p_metadata) key_name where key_name not in (
    'operation_code','target_profile_id','permission_codes','organization_id',
    'relationship_type','link_type','initiating_context','changed_fields'
  )) then raise exception using errcode = '22023', message = 'C003C_AUDIT_INPUT_INVALID'; end if;
  insert into public.audit_events (
    actor_kind, actor_profile_id, event_type, resource_kind, resource_id,
    scope_kind, scope_id, old_state, new_state, reason_code, correlation_id,
    channel, row_version_before, row_version_after, access_version_before,
    access_version_after, metadata
  ) values (
    'profile', p_actor_profile_id, p_event_type, p_resource_kind, p_resource_id,
    'horse', p_horse_id,
    case when p_old_status is null then '{}'::jsonb else pg_catalog.jsonb_build_object('status',p_old_status) end,
    case when p_new_status is null then '{}'::jsonb else pg_catalog.jsonb_build_object('status',p_new_status) end,
    p_reason_code, p_correlation_id, 'rpc', p_row_before, p_row_after,
    p_access_before, p_access_after, p_metadata
  ) returning id into event_id;
  return event_id;
end;
$$;

create or replace function private.c003c_bump_access(
  p_horse_id uuid, p_profile_ids uuid[], p_actor_profile_id uuid,
  p_correlation_id uuid, p_operation_code text
)
returns void language plpgsql security definer set search_path = '' as $$
declare before_access bigint; after_access bigint; after_row bigint; profile_id uuid;
begin
  update public.canonical_horses horse set access_version = horse.access_version + 1,
    row_version = horse.row_version + 1, updated_at = pg_catalog.clock_timestamp()
  where horse.id = p_horse_id
  returning access_version - 1, access_version, row_version into before_access, after_access, after_row;
  if not found then raise exception using errcode = 'P0002', message = 'CANONICAL_HORSE_NOT_FOUND'; end if;
  foreach profile_id in array coalesce(p_profile_ids,array[]::uuid[]) loop
    update public.profiles profile set access_version = profile.access_version + 1
      where profile.id = profile_id and profile.status = 'active';
  end loop;
  perform private.c003c_write_audit(
    'horse.access_changed','horse',p_horse_id,p_horse_id,p_actor_profile_id,p_correlation_id,
    'ACCESS_CHANGED',null,null,after_row-1,after_row,before_access,after_access,
    pg_catalog.jsonb_build_object('operation_code',p_operation_code)
  );
end;
$$;

create or replace function private.c003c_require_permission(
  p_actor_id uuid, p_horse_id uuid, p_permission_code text
)
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.c003c_profile_has_horse_permission(p_actor_id,p_horse_id,p_permission_code,pg_catalog.statement_timestamp())
  then raise exception using errcode = '42501', message = 'HORSE_PERMISSION_REQUIRED'; end if;
end;
$$;

create or replace function public.create_canonical_horse(
  p_display_name text, p_birth_date date, p_sex text, p_breed text,
  p_correlation_id uuid, p_client_context jsonb default '{}'::jsonb
)
returns table(horse_id uuid, access_version bigint, authority_version bigint, row_version bigint, result_code text, applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; existing public.canonical_horses%rowtype; created public.canonical_horses%rowtype;
begin
  actor_id := private.c003c_actor_profile_id();
  if p_correlation_id is null or p_client_context is null then
    raise exception using errcode = '22023', message = 'CREATE_HORSE_INPUT_INVALID'; end if;
  select * into existing from public.canonical_horses h
    where h.created_by_profile_id = actor_id and h.creation_correlation_id = p_correlation_id;
  if found then return query select existing.id,existing.access_version,existing.authority_version,existing.row_version,'idempotent_replay'::text,false; return; end if;
  insert into public.canonical_horses(
    primary_authority_profile_id,display_name,birth_date,sex,breed,
    created_by_profile_id,creation_correlation_id
  ) values (actor_id,pg_catalog.btrim(p_display_name),p_birth_date,coalesce(p_sex,'unknown'),
    nullif(pg_catalog.btrim(p_breed),''),actor_id,p_correlation_id) returning * into created;
  update public.profiles p set access_version = p.access_version + 1 where p.id = actor_id;
  perform private.c003c_write_audit('horse.created','horse',created.id,created.id,actor_id,p_correlation_id,
    'HORSE_CREATED',null,created.status,null,created.row_version,null,created.access_version,
    pg_catalog.jsonb_build_object('operation_code','create_canonical_horse'));
  return query select created.id,created.access_version,created.authority_version,created.row_version,'created'::text,true;
end;
$$;

create or replace function public.update_canonical_horse(
  p_horse_id uuid, p_expected_row_version bigint, p_display_name text,
  p_birth_date date, p_sex text, p_breed text, p_status text, p_correlation_id uuid
)
returns table(row_version bigint, status text, applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; before_row public.canonical_horses%rowtype; after_row public.canonical_horses%rowtype;
begin
  actor_id := private.c003c_actor_profile_id(); perform private.c003c_require_permission(actor_id,p_horse_id,'horse.edit');
  select * into before_row from public.canonical_horses h where h.id=p_horse_id for update;
  if before_row.row_version <> p_expected_row_version then raise exception using errcode='40001',message='STALE_HORSE_VERSION'; end if;
  if p_status not in ('active','archived') then raise exception using errcode='22023',message='HORSE_STATUS_INVALID'; end if;
  update public.canonical_horses h set display_name=pg_catalog.btrim(p_display_name),birth_date=p_birth_date,
    sex=coalesce(p_sex,'unknown'),breed=nullif(pg_catalog.btrim(p_breed),''),status=p_status,
    archived_at=case when p_status='archived' then coalesce(h.archived_at,pg_catalog.clock_timestamp()) else null end,
    row_version=h.row_version+1,updated_at=pg_catalog.clock_timestamp() where h.id=p_horse_id returning * into after_row;
  perform private.c003c_write_audit('horse.updated','horse',p_horse_id,p_horse_id,actor_id,p_correlation_id,
    'HORSE_UPDATED',before_row.status,after_row.status,before_row.row_version,after_row.row_version,
    before_row.access_version,after_row.access_version,pg_catalog.jsonb_build_object('changed_fields',array['display_fields','status']));
  return query select after_row.row_version,after_row.status,true;
end;
$$;

create or replace function public.grant_horse_delegated_administrator(
  p_horse_id uuid, p_profile_id uuid, p_permission_codes text[],
  p_valid_from timestamptz, p_valid_until timestamptz, p_correlation_id uuid
)
returns table(delegation_id uuid, row_version bigint, applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; horse public.canonical_horses%rowtype; created public.horse_delegated_administrators%rowtype; normalized text[];
begin
  actor_id := private.c003c_actor_profile_id();
  select * into horse from public.canonical_horses h where h.id=p_horse_id for update;
  if horse.primary_authority_profile_id <> actor_id then raise exception using errcode='42501',message='PRIMARY_HORSE_AUTHORITY_REQUIRED'; end if;
  if not exists(select 1 from public.profiles p where p.id=p_profile_id and p.status='active') then raise exception using errcode='42501',message='ACTIVE_TARGET_PROFILE_REQUIRED'; end if;
  select array_agg(distinct code order by code) into normalized from unnest(coalesce(p_permission_codes,array[]::text[])) code;
  if pg_catalog.cardinality(normalized) < 1 or not normalized <@ array['horse.view','horse.edit','horse.manage','horse.assign','horse.share']::text[]
  then raise exception using errcode='22023',message='DELEGATED_PERMISSION_SCOPE_INVALID'; end if;
  insert into public.horse_delegated_administrators(horse_id,profile_id,granted_by_profile_id,permission_codes,
    valid_from,valid_until,creation_correlation_id) values(p_horse_id,p_profile_id,actor_id,normalized,
    coalesce(p_valid_from,pg_catalog.statement_timestamp()),p_valid_until,p_correlation_id) returning * into created;
  perform private.c003c_bump_access(p_horse_id,array[p_profile_id],actor_id,p_correlation_id,'grant_delegation');
  perform private.c003c_write_audit('horse.delegation_granted','horse_delegation',created.id,p_horse_id,actor_id,p_correlation_id,
    'DELEGATION_GRANTED',null,created.status,null,created.row_version,null,null,
    pg_catalog.jsonb_build_object('target_profile_id',p_profile_id::text,'permission_codes',normalized));
  return query select created.id,created.row_version,true;
end;
$$;

create or replace function public.end_horse_delegated_administrator(
  p_delegation_id uuid, p_expected_row_version bigint, p_reason_code text, p_correlation_id uuid
)
returns table(row_version bigint, status text, applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; before_row public.horse_delegated_administrators%rowtype; after_row public.horse_delegated_administrators%rowtype; horse public.canonical_horses%rowtype;
begin
  actor_id:=private.c003c_actor_profile_id(); select * into before_row from public.horse_delegated_administrators d where d.id=p_delegation_id for update;
  if not found then raise exception using errcode='P0002',message='DELEGATION_NOT_FOUND'; end if;
  select * into horse from public.canonical_horses h where h.id=before_row.horse_id for update;
  if horse.primary_authority_profile_id<>actor_id then raise exception using errcode='42501',message='PRIMARY_HORSE_AUTHORITY_REQUIRED'; end if;
  if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_DELEGATION_VERSION'; end if;
  if before_row.status='ended' then return query select before_row.row_version,before_row.status,false; return; end if;
  update public.horse_delegated_administrators d set status='ended',valid_until=greatest(pg_catalog.statement_timestamp(),d.valid_from+interval '1 microsecond'),
    ended_reason_code=coalesce(nullif(pg_catalog.btrim(p_reason_code),''),'AUTHORITY_REVOKED'),row_version=d.row_version+1,
    updated_at=pg_catalog.clock_timestamp() where d.id=p_delegation_id returning * into after_row;
  perform private.c003c_bump_access(after_row.horse_id,array[after_row.profile_id],actor_id,p_correlation_id,'end_delegation');
  perform private.c003c_write_audit('horse.delegation_ended','horse_delegation',after_row.id,after_row.horse_id,actor_id,p_correlation_id,
    'DELEGATION_ENDED',before_row.status,after_row.status,before_row.row_version,after_row.row_version,null,null,
    pg_catalog.jsonb_build_object('target_profile_id',after_row.profile_id::text));
  return query select after_row.row_version,after_row.status,true;
end;
$$;

-- Ownership and semantic relationship records never participate in the
-- permission helper. Their RPCs require pre-existing horse.manage authority.
create or replace function public.start_horse_person_ownership(
  p_horse_id uuid,p_owner_profile_id uuid,p_percentage numeric,p_valid_from timestamptz,p_correlation_id uuid
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; created_id uuid;
begin actor_id:=private.c003c_actor_profile_id(); perform private.c003c_require_permission(actor_id,p_horse_id,'horse.manage');
  if not exists(select 1 from public.profiles p where p.id=p_owner_profile_id and p.status='active')
  then raise exception using errcode='42501',message='ACTIVE_OWNER_PROFILE_REQUIRED'; end if;
  insert into public.horse_person_ownerships(horse_id,owner_profile_id,ownership_percentage,valid_from,created_by_profile_id,creation_correlation_id)
  values(p_horse_id,p_owner_profile_id,p_percentage,coalesce(p_valid_from,pg_catalog.statement_timestamp()),actor_id,p_correlation_id) returning id into created_id;
  perform private.c003c_write_audit('horse.person_ownership_started','horse_person_ownership',created_id,p_horse_id,actor_id,p_correlation_id,
    'PERSON_OWNERSHIP_STARTED',null,'active',null,1,null,null,pg_catalog.jsonb_build_object('target_profile_id',p_owner_profile_id::text)); return created_id; end;
$$;

create or replace function public.end_horse_person_ownership(p_ownership_id uuid,p_expected_row_version bigint,p_correlation_id uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; before_row public.horse_person_ownerships%rowtype; after_version bigint;
begin actor_id:=private.c003c_actor_profile_id(); select * into before_row from public.horse_person_ownerships o where o.id=p_ownership_id for update;
  perform private.c003c_require_permission(actor_id,before_row.horse_id,'horse.manage'); if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_OWNERSHIP_VERSION'; end if;
  update public.horse_person_ownerships o set status='ended',valid_until=greatest(pg_catalog.statement_timestamp(),o.valid_from+interval '1 microsecond'),row_version=o.row_version+1,updated_at=pg_catalog.clock_timestamp() where o.id=p_ownership_id returning row_version into after_version;
  perform private.c003c_write_audit('horse.person_ownership_ended','horse_person_ownership',p_ownership_id,before_row.horse_id,actor_id,p_correlation_id,'PERSON_OWNERSHIP_ENDED','active','ended',before_row.row_version,after_version,null,null,'{}'); return after_version; end;
$$;

create or replace function public.start_horse_organization_ownership(
  p_horse_id uuid,p_organization_id uuid,p_percentage numeric,p_valid_from timestamptz,p_correlation_id uuid
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; created_id uuid;
begin actor_id:=private.c003c_actor_profile_id(); perform private.c003c_require_permission(actor_id,p_horse_id,'horse.manage');
  if not exists(select 1 from public.organizations o where o.id=p_organization_id and o.status='active')
  then raise exception using errcode='22023',message='ACTIVE_OWNER_ORGANIZATION_REQUIRED'; end if;
  insert into public.horse_organization_ownerships(horse_id,owner_organization_id,ownership_percentage,valid_from,created_by_profile_id,creation_correlation_id)
  values(p_horse_id,p_organization_id,p_percentage,coalesce(p_valid_from,pg_catalog.statement_timestamp()),actor_id,p_correlation_id) returning id into created_id;
  perform private.c003c_write_audit('horse.organization_ownership_started','horse_organization_ownership',created_id,p_horse_id,actor_id,p_correlation_id,'ORGANIZATION_OWNERSHIP_STARTED',null,'active',null,1,null,null,pg_catalog.jsonb_build_object('organization_id',p_organization_id::text)); return created_id; end;
$$;

create or replace function public.end_horse_organization_ownership(p_ownership_id uuid,p_expected_row_version bigint,p_correlation_id uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; before_row public.horse_organization_ownerships%rowtype; after_version bigint;
begin actor_id:=private.c003c_actor_profile_id(); select * into before_row from public.horse_organization_ownerships o where o.id=p_ownership_id for update;
  perform private.c003c_require_permission(actor_id,before_row.horse_id,'horse.manage'); if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_OWNERSHIP_VERSION'; end if;
  update public.horse_organization_ownerships o set status='ended',valid_until=greatest(pg_catalog.statement_timestamp(),o.valid_from+interval '1 microsecond'),row_version=o.row_version+1,updated_at=pg_catalog.clock_timestamp() where o.id=p_ownership_id returning row_version into after_version;
  perform private.c003c_write_audit('horse.organization_ownership_ended','horse_organization_ownership',p_ownership_id,before_row.horse_id,actor_id,p_correlation_id,'ORGANIZATION_OWNERSHIP_ENDED','active','ended',before_row.row_version,after_version,null,null,'{}'); return after_version; end;
$$;

create or replace function public.start_horse_person_relationship(
  p_horse_id uuid,p_profile_id uuid,p_relationship_type_code text,p_valid_from timestamptz,p_correlation_id uuid
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; type_id uuid; created_id uuid;
begin actor_id:=private.c003c_actor_profile_id(); perform private.c003c_require_permission(actor_id,p_horse_id,'horse.manage');
  if not exists(select 1 from public.profiles p where p.id=p_profile_id and p.status='active')
  then raise exception using errcode='42501',message='ACTIVE_RELATIONSHIP_PROFILE_REQUIRED'; end if;
  select id into type_id from public.horse_relationship_types where code=p_relationship_type_code and is_active;
  if type_id is null then raise exception using errcode='22023',message='RELATIONSHIP_TYPE_INVALID'; end if;
  insert into public.horse_person_relationships(horse_id,profile_id,relationship_type_id,valid_from,created_by_profile_id,creation_correlation_id)
  values(p_horse_id,p_profile_id,type_id,coalesce(p_valid_from,pg_catalog.statement_timestamp()),actor_id,p_correlation_id) returning id into created_id;
  perform private.c003c_write_audit('horse.person_relationship_started','horse_person_relationship',created_id,p_horse_id,actor_id,p_correlation_id,'PERSON_RELATIONSHIP_STARTED',null,'active',null,1,null,null,pg_catalog.jsonb_build_object('target_profile_id',p_profile_id::text,'relationship_type',p_relationship_type_code)); return created_id; end;
$$;

create or replace function public.end_horse_person_relationship(p_relationship_id uuid,p_expected_row_version bigint,p_correlation_id uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; before_row public.horse_person_relationships%rowtype; after_version bigint;
begin actor_id:=private.c003c_actor_profile_id(); select * into before_row from public.horse_person_relationships r where r.id=p_relationship_id for update;
  perform private.c003c_require_permission(actor_id,before_row.horse_id,'horse.manage'); if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_RELATIONSHIP_VERSION'; end if;
  update public.horse_person_relationships r set status='ended',valid_until=greatest(pg_catalog.statement_timestamp(),r.valid_from+interval '1 microsecond'),row_version=r.row_version+1,updated_at=pg_catalog.clock_timestamp() where r.id=p_relationship_id returning row_version into after_version;
  perform private.c003c_write_audit('horse.person_relationship_ended','horse_person_relationship',p_relationship_id,before_row.horse_id,actor_id,p_correlation_id,'PERSON_RELATIONSHIP_ENDED','active','ended',before_row.row_version,after_version,null,null,'{}'); return after_version; end;
$$;

create or replace function public.switch_horse_residency(
  p_horse_id uuid,p_stable_organization_id uuid,p_valid_from timestamptz,p_correlation_id uuid
)
returns table(residency_id uuid,row_version bigint,applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; at_time timestamptz; old_row public.horse_residencies%rowtype; created public.horse_residencies%rowtype;
begin actor_id:=private.c003c_actor_profile_id(); perform private.c003c_require_permission(actor_id,p_horse_id,'horse.manage');
  perform 1 from public.canonical_horses h where h.id=p_horse_id for update;
  if not exists(select 1 from public.organizations o join public.organization_types t on t.id=o.organization_type_id where o.id=p_stable_organization_id and o.status='active' and t.code='stable' and t.is_active)
  then raise exception using errcode='22023',message='ACTIVE_STABLE_ORGANIZATION_REQUIRED'; end if;
  at_time:=coalesce(p_valid_from,pg_catalog.statement_timestamp()); select * into old_row from public.horse_residencies r where r.horse_id=p_horse_id and r.status='active' for update;
  if found and old_row.stable_organization_id=p_stable_organization_id then return query select old_row.id,old_row.row_version,false; return; end if;
  if found then update public.horse_residencies r set status='ended',valid_until=greatest(at_time,r.valid_from+interval '1 microsecond'),row_version=r.row_version+1,updated_at=pg_catalog.clock_timestamp() where r.id=old_row.id; end if;
  insert into public.horse_residencies(horse_id,stable_organization_id,status,valid_from,created_by_profile_id,creation_correlation_id)
    values(p_horse_id,p_stable_organization_id,'active',at_time,actor_id,p_correlation_id) returning * into created;
  perform private.c003c_write_audit(case when old_row.id is null then 'horse.residency_started' else 'horse.residency_switched' end,
    'horse_residency',created.id,p_horse_id,actor_id,p_correlation_id,case when old_row.id is null then 'RESIDENCY_STARTED' else 'RESIDENCY_SWITCHED' end,
    null,created.status,null,created.row_version,null,null,pg_catalog.jsonb_build_object('organization_id',p_stable_organization_id::text));
  return query select created.id,created.row_version,true; end;
$$;

create or replace function public.end_horse_residency(p_residency_id uuid,p_expected_row_version bigint,p_correlation_id uuid)
returns bigint language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; before_row public.horse_residencies%rowtype; after_version bigint;
begin actor_id:=private.c003c_actor_profile_id(); select * into before_row from public.horse_residencies r where r.id=p_residency_id for update;
  perform private.c003c_require_permission(actor_id,before_row.horse_id,'horse.manage'); if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_RESIDENCY_VERSION'; end if;
  update public.horse_residencies r set status='ended',valid_until=greatest(pg_catalog.statement_timestamp(),r.valid_from+interval '1 microsecond'),row_version=r.row_version+1,updated_at=pg_catalog.clock_timestamp() where r.id=p_residency_id returning row_version into after_version;
  perform private.c003c_write_audit('horse.residency_ended','horse_residency',p_residency_id,before_row.horse_id,actor_id,p_correlation_id,'RESIDENCY_ENDED','active','ended',before_row.row_version,after_version,null,null,'{}'); return after_version; end;
$$;

create or replace function private.c003c_context_authorized(p_actor_id uuid,p_context text,p_horse_id uuid,p_organization_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select case p_context when 'horse' then private.c003c_profile_has_horse_permission(p_actor_id,p_horse_id,'horse.manage',pg_catalog.statement_timestamp())
    when 'organization' then private.c003b_profile_has_permission(p_actor_id,p_organization_id,'organization.edit',pg_catalog.statement_timestamp()) else false end
$$;

create or replace function public.propose_organization_horse_link(
  p_horse_id uuid,p_organization_id uuid,p_link_type_code text,p_initiating_context text,p_correlation_id uuid
)
returns table(link_id uuid,status text,expires_at timestamptz,row_version bigint,applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; type_id uuid; proposed_at timestamptz; created public.organization_horse_links%rowtype;
begin actor_id:=private.c003c_actor_profile_id();
  if not exists(select 1 from public.organizations o where o.id=p_organization_id and o.status='active')
  then raise exception using errcode='22023',message='ACTIVE_ORGANIZATION_REQUIRED'; end if;
  if not private.c003c_context_authorized(actor_id,p_initiating_context,p_horse_id,p_organization_id)
  then raise exception using errcode='42501',message='LINK_INITIATING_CONTEXT_NOT_AUTHORIZED'; end if;
  select id into type_id from public.organization_horse_link_types where code=p_link_type_code and is_active;
  if type_id is null then raise exception using errcode='22023',message='LINK_TYPE_INVALID'; end if;
  proposed_at:=pg_catalog.clock_timestamp();
  insert into public.organization_horse_links(horse_id,organization_id,link_type_id,initiating_context,initiated_by_profile_id,
    horse_confirmed_by_profile_id,horse_confirmed_at,organization_confirmed_by_profile_id,organization_confirmed_at,
    proposed_at,expires_at,creation_correlation_id)
  values(p_horse_id,p_organization_id,type_id,p_initiating_context,actor_id,
    case when p_initiating_context='horse' then actor_id end,case when p_initiating_context='horse' then proposed_at end,
    case when p_initiating_context='organization' then actor_id end,case when p_initiating_context='organization' then proposed_at end,
    proposed_at,proposed_at+interval '7 days',p_correlation_id) returning * into created;
  perform private.c003c_write_audit('horse.organization_link_proposed','organization_horse_link',created.id,p_horse_id,actor_id,p_correlation_id,'ORGANIZATION_LINK_PROPOSED',null,created.status,null,created.row_version,null,null,
    pg_catalog.jsonb_build_object('organization_id',p_organization_id::text,'link_type',p_link_type_code,'initiating_context',p_initiating_context));
  return query select created.id,created.status,created.expires_at,created.row_version,true; end;
$$;

create or replace function public.respond_organization_horse_link(
  p_link_id uuid,p_expected_row_version bigint,p_action text,p_correlation_id uuid
)
returns table(row_version bigint,status text,applied boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid; before_row public.organization_horse_links%rowtype; after_row public.organization_horse_links%rowtype; responding_context text; event_name text; reason_name text;
begin actor_id:=private.c003c_actor_profile_id(); select * into before_row from public.organization_horse_links l where l.id=p_link_id for update;
  if not found then raise exception using errcode='P0002',message='ORGANIZATION_HORSE_LINK_NOT_FOUND'; end if;
  if not (
    private.c003c_context_authorized(actor_id,'horse',before_row.horse_id,before_row.organization_id)
    or private.c003c_context_authorized(actor_id,'organization',before_row.horse_id,before_row.organization_id)
  ) then raise exception using errcode='42501',message='LINK_CONTEXT_NOT_AUTHORIZED'; end if;
  if before_row.status in ('rejected','withdrawn','expired','ended') then return query select before_row.row_version,before_row.status,false; return; end if;
  if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_LINK_VERSION'; end if;
  if before_row.status='proposed' and pg_catalog.statement_timestamp()>=before_row.expires_at then
    update public.organization_horse_links l set status='expired',ended_at=pg_catalog.clock_timestamp(),row_version=l.row_version+1,updated_at=pg_catalog.clock_timestamp() where l.id=p_link_id returning * into after_row;
    perform private.c003c_write_audit('horse.organization_link_expired','organization_horse_link',p_link_id,before_row.horse_id,actor_id,p_correlation_id,'ORGANIZATION_LINK_EXPIRED',before_row.status,after_row.status,before_row.row_version,after_row.row_version,null,null,'{}');
    return query select after_row.row_version,after_row.status,true; return;
  end if;
  if p_action='withdraw' then
    if before_row.status<>'proposed' or not private.c003c_context_authorized(actor_id,before_row.initiating_context,before_row.horse_id,before_row.organization_id)
    then raise exception using errcode='42501',message='LINK_WITHDRAW_NOT_AUTHORIZED'; end if;
    event_name:='horse.organization_link_withdrawn'; reason_name:='ORGANIZATION_LINK_WITHDRAWN';
    update public.organization_horse_links l set status='withdrawn',ended_at=pg_catalog.clock_timestamp(),row_version=l.row_version+1,updated_at=pg_catalog.clock_timestamp() where l.id=p_link_id returning * into after_row;
  elsif p_action in ('accept','reject') then
    if before_row.status<>'proposed' then raise exception using errcode='22023',message='LINK_RESPONSE_STATE_INVALID'; end if;
    responding_context:=case before_row.initiating_context when 'horse' then 'organization' else 'horse' end;
    if not private.c003c_context_authorized(actor_id,responding_context,before_row.horse_id,before_row.organization_id)
    then raise exception using errcode='42501',message='LINK_RESPONDING_CONTEXT_NOT_AUTHORIZED'; end if;
    if p_action='accept' then
      update public.organization_horse_links l set status='active',
        horse_confirmed_by_profile_id=coalesce(l.horse_confirmed_by_profile_id,actor_id),horse_confirmed_at=coalesce(l.horse_confirmed_at,pg_catalog.clock_timestamp()),
        organization_confirmed_by_profile_id=coalesce(l.organization_confirmed_by_profile_id,actor_id),organization_confirmed_at=coalesce(l.organization_confirmed_at,pg_catalog.clock_timestamp()),
        row_version=l.row_version+1,updated_at=pg_catalog.clock_timestamp() where l.id=p_link_id returning * into after_row;
      event_name:='horse.organization_link_activated'; reason_name:='ORGANIZATION_LINK_ACTIVATED';
    else
      update public.organization_horse_links l set status='rejected',ended_at=pg_catalog.clock_timestamp(),row_version=l.row_version+1,updated_at=pg_catalog.clock_timestamp() where l.id=p_link_id returning * into after_row;
      event_name:='horse.organization_link_rejected'; reason_name:='ORGANIZATION_LINK_REJECTED';
    end if;
  elsif p_action='end' then
    if before_row.status<>'active' or not (
      private.c003c_context_authorized(actor_id,'horse',before_row.horse_id,before_row.organization_id)
      or private.c003c_context_authorized(actor_id,'organization',before_row.horse_id,before_row.organization_id))
    then raise exception using errcode='42501',message='LINK_END_NOT_AUTHORIZED'; end if;
    update public.organization_horse_links l set status='ended',ended_at=pg_catalog.clock_timestamp(),row_version=l.row_version+1,updated_at=pg_catalog.clock_timestamp() where l.id=p_link_id returning * into after_row;
    event_name:='horse.organization_link_ended'; reason_name:='ORGANIZATION_LINK_ENDED';
  else raise exception using errcode='22023',message='LINK_ACTION_INVALID'; end if;
  perform private.c003c_write_audit(event_name,'organization_horse_link',p_link_id,before_row.horse_id,actor_id,p_correlation_id,reason_name,before_row.status,after_row.status,before_row.row_version,after_row.row_version,null,null,'{}');
  return query select after_row.row_version,after_row.status,true; end;
$$;

-- RLS/ACL: reads are explicit and every critical write is RPC-only.
alter table public.canonical_horses enable row level security;
alter table public.horse_delegated_administrators enable row level security;
alter table public.horse_person_ownerships enable row level security;
alter table public.horse_organization_ownerships enable row level security;
alter table public.horse_relationship_types enable row level security;
alter table public.horse_person_relationships enable row level security;
alter table public.organization_horse_link_types enable row level security;
alter table public.organization_horse_links enable row level security;
alter table public.horse_residencies enable row level security;

create policy canonical_horses_read on public.canonical_horses for select to authenticated using (public.has_canonical_horse_permission(id,'horse.view'));
create policy horse_delegated_administrators_read on public.horse_delegated_administrators for select to authenticated using ((profile_id=private.current_profile_id() and exists(select 1 from public.profiles p where p.id=private.current_profile_id() and p.status='active')) or public.has_canonical_horse_permission(horse_id,'horse.assign'));
create policy horse_person_ownerships_read on public.horse_person_ownerships for select to authenticated using ((owner_profile_id=private.current_profile_id() and exists(select 1 from public.profiles p where p.id=private.current_profile_id() and p.status='active')) or public.has_canonical_horse_permission(horse_id,'horse.view'));
create policy horse_organization_ownerships_read on public.horse_organization_ownerships for select to authenticated using (public.has_canonical_horse_permission(horse_id,'horse.view') or public.has_organization_permission(owner_organization_id,'organization.view'));
create policy horse_relationship_types_read on public.horse_relationship_types for select to authenticated using (is_active);
create policy horse_person_relationships_read on public.horse_person_relationships for select to authenticated using ((profile_id=private.current_profile_id() and exists(select 1 from public.profiles p where p.id=private.current_profile_id() and p.status='active')) or public.has_canonical_horse_permission(horse_id,'horse.view'));
create policy organization_horse_link_types_read on public.organization_horse_link_types for select to authenticated using (is_active);
create policy organization_horse_links_read on public.organization_horse_links for select to authenticated using (public.has_canonical_horse_permission(horse_id,'horse.view') or public.has_organization_permission(organization_id,'organization.view'));
create policy horse_residencies_read on public.horse_residencies for select to authenticated using (public.has_canonical_horse_permission(horse_id,'horse.view') or public.has_organization_permission(stable_organization_id,'organization.view'));
create policy c003c_horse_audit_read on public.audit_events for select to authenticated using (scope_kind='horse' and public.has_canonical_horse_permission(scope_id,'horse.view'));

revoke all on table public.canonical_horses,public.horse_delegated_administrators,
  public.horse_person_ownerships,public.horse_organization_ownerships,
  public.horse_relationship_types,public.horse_person_relationships,
  public.organization_horse_link_types,public.organization_horse_links,
  public.horse_residencies from public,anon,authenticated,service_role;
grant select on public.canonical_horses,public.horse_delegated_administrators,
  public.horse_person_ownerships,public.horse_organization_ownerships,
  public.horse_relationship_types,public.horse_person_relationships,
  public.organization_horse_link_types,public.organization_horse_links,
  public.horse_residencies to authenticated;

revoke execute on function public.has_canonical_horse_permission(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.has_canonical_horse_permission(uuid,text) to authenticated;
revoke execute on function public.create_canonical_horse(text,date,text,text,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.create_canonical_horse(text,date,text,text,uuid,jsonb) to authenticated;
revoke execute on function public.update_canonical_horse(uuid,bigint,text,date,text,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.update_canonical_horse(uuid,bigint,text,date,text,text,text,uuid) to authenticated;
revoke execute on function public.grant_horse_delegated_administrator(uuid,uuid,text[],timestamptz,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.grant_horse_delegated_administrator(uuid,uuid,text[],timestamptz,timestamptz,uuid) to authenticated;
revoke execute on function public.end_horse_delegated_administrator(uuid,bigint,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.end_horse_delegated_administrator(uuid,bigint,text,uuid) to authenticated;
revoke execute on function public.start_horse_person_ownership(uuid,uuid,numeric,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.start_horse_person_ownership(uuid,uuid,numeric,timestamptz,uuid) to authenticated;
revoke execute on function public.end_horse_person_ownership(uuid,bigint,uuid) from public,anon,authenticated,service_role;
grant execute on function public.end_horse_person_ownership(uuid,bigint,uuid) to authenticated;
revoke execute on function public.start_horse_organization_ownership(uuid,uuid,numeric,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.start_horse_organization_ownership(uuid,uuid,numeric,timestamptz,uuid) to authenticated;
revoke execute on function public.end_horse_organization_ownership(uuid,bigint,uuid) from public,anon,authenticated,service_role;
grant execute on function public.end_horse_organization_ownership(uuid,bigint,uuid) to authenticated;
revoke execute on function public.start_horse_person_relationship(uuid,uuid,text,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.start_horse_person_relationship(uuid,uuid,text,timestamptz,uuid) to authenticated;
revoke execute on function public.end_horse_person_relationship(uuid,bigint,uuid) from public,anon,authenticated,service_role;
grant execute on function public.end_horse_person_relationship(uuid,bigint,uuid) to authenticated;
revoke execute on function public.switch_horse_residency(uuid,uuid,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.switch_horse_residency(uuid,uuid,timestamptz,uuid) to authenticated;
revoke execute on function public.end_horse_residency(uuid,bigint,uuid) from public,anon,authenticated,service_role;
grant execute on function public.end_horse_residency(uuid,bigint,uuid) to authenticated;
revoke execute on function public.propose_organization_horse_link(uuid,uuid,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.propose_organization_horse_link(uuid,uuid,text,text,uuid) to authenticated;
revoke execute on function public.respond_organization_horse_link(uuid,bigint,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.respond_organization_horse_link(uuid,bigint,text,uuid) to authenticated;

revoke execute on function private.c003c_touch_catalog_row() from public,anon,authenticated,service_role;
revoke execute on function private.c003c_guard_horse_authority() from public,anon,authenticated,service_role;
revoke execute on function private.c003c_assert_primary_authority(uuid) from public,anon,authenticated,service_role;
revoke execute on function private.c003c_primary_authority_constraint() from public,anon,authenticated,service_role;
revoke execute on function private.c003c_actor_profile_id() from public,anon,authenticated,service_role;
revoke execute on function private.c003c_profile_has_horse_permission(uuid,uuid,text,timestamptz) from public,anon,authenticated,service_role;
revoke execute on function private.c003c_write_audit(text,text,uuid,uuid,uuid,uuid,text,text,text,bigint,bigint,bigint,bigint,jsonb) from public,anon,authenticated,service_role;
revoke execute on function private.c003c_bump_access(uuid,uuid[],uuid,uuid,text) from public,anon,authenticated,service_role;
revoke execute on function private.c003c_require_permission(uuid,uuid,text) from public,anon,authenticated,service_role;
revoke execute on function private.c003c_context_authorized(uuid,text,uuid,uuid) from public,anon,authenticated,service_role;

comment on table public.canonical_horses is 'C-003C canonical horse aggregate, isolated from legacy stable-scoped public.horses.';
comment on column public.canonical_horses.primary_authority_profile_id is 'Exactly one scalar primary authority; changes require a later transfer workflow.';
comment on table public.horse_person_relationships is 'Semantic relationship only; never an authorization source.';
comment on table public.horse_residencies is 'Stable residency history only; never an authorization source.';
comment on table public.organization_horse_links is 'Mutually confirmed context link; never an authorization source.';
comment on function public.has_canonical_horse_permission(uuid,text) is 'PII-free explicit authority/delegation evaluator; ignores ownership, relationships, links, residency, legacy stable_id and JWT metadata.';
