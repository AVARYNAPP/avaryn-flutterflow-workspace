-- C-003D — Explicit permissions and invitations
-- Adds explicit grants and tokenized invitations to the approved A/B/C
-- foundations. Relationships, links, residency, legacy stable_id and client
-- metadata remain non-authoritative.

-- Expand the shared catalog without allowing organization roles to consume
-- horse-scoped capabilities.
alter table public.permission_definitions drop constraint permission_definitions_code_check;
alter table public.permission_definitions add constraint permission_definitions_code_check check (
  (scope_kind='organization' and code ~ '^organization\.[a-z][a-z0-9_.]{1,62}$')
  or (scope_kind='horse' and code ~ '^horse\.[a-z][a-z0-9_.]{1,62}$')
);
alter table public.permission_definitions drop constraint permission_definitions_scope_check;
alter table public.permission_definitions add constraint permission_definitions_scope_check
  check (scope_kind in ('organization','horse'));
alter table public.permission_definitions drop constraint permission_definitions_action_check;
alter table public.permission_definitions add constraint permission_definitions_action_check
  check (action_class in ('view','edit','manage','assign','share','transfer'));

insert into public.permission_definitions(
  code,scope_kind,action_class,description,is_grantable
) values
  ('horse.view','horse','view','View the canonical horse.',true),
  ('horse.edit','horse','edit','Edit canonical horse domain data.',true),
  ('horse.manage','horse','manage','Manage horse lifecycle, relationships and grants.',true),
  ('horse.assign','horse','assign','Assign horse-scoped work when that module exists.',true),
  ('horse.share','horse','share','Share explicitly permitted horse data.',true),
  ('horse.transfer','horse','transfer','Transfer primary Horse Authority through C-003E only.',false);

drop policy permission_definitions_read on public.permission_definitions;
create policy permission_definitions_read on public.permission_definitions for select to authenticated
using (is_active and scope_kind in ('organization','horse'));

create table public.horse_profile_permission_grants (
  id uuid primary key default extensions.gen_random_uuid(),
  horse_id uuid not null references public.canonical_horses(id) on delete restrict,
  grantee_profile_id uuid not null references public.profiles(id) on delete restrict,
  permission_id uuid not null references public.permission_definitions(id) on delete restrict,
  grantor_profile_id uuid not null references public.profiles(id) on delete restrict,
  horse_person_relationship_id uuid references public.horse_person_relationships(id) on delete restrict,
  status text not null default 'active',
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  reason_code text not null,
  terminal_reason_code text,
  terminal_by_profile_id uuid references public.profiles(id) on delete restrict,
  terminal_at timestamptz,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint horse_profile_grants_status_check check (status in ('active','revoked','expired','ended')),
  constraint horse_profile_grants_time_check check (valid_until is null or valid_until > valid_from),
  constraint horse_profile_grants_reason_check check (reason_code in ('MANUAL_GRANT','RELATIONSHIP_BOUND','INVITATION_ACCEPTED')),
  constraint horse_profile_grants_terminal_shape check (
    (status='active' and terminal_reason_code is null and terminal_by_profile_id is null and terminal_at is null)
    or (status<>'active' and terminal_reason_code is not null and terminal_by_profile_id is not null and terminal_at is not null)
  ),
  constraint horse_profile_grants_row_version_check check (row_version>=1),
  constraint horse_profile_grants_creation_unique unique(
    grantor_profile_id,creation_correlation_id,horse_id,grantee_profile_id,permission_id
  ),
  constraint horse_profile_grants_no_overlap exclude using gist (
    horse_id with =,grantee_profile_id with =,permission_id with =,
    tstzrange(valid_from,coalesce(valid_until,'infinity'::timestamptz),'[)') with &&
  ) where(status='active')
);

create table public.horse_organization_role_permission_grants (
  id uuid primary key default extensions.gen_random_uuid(),
  horse_id uuid not null references public.canonical_horses(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  role_id uuid not null,
  permission_id uuid not null references public.permission_definitions(id) on delete restrict,
  grantor_profile_id uuid not null references public.profiles(id) on delete restrict,
  organization_horse_link_id uuid references public.organization_horse_links(id) on delete restrict,
  status text not null default 'active',
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  reason_code text not null,
  terminal_reason_code text,
  terminal_by_profile_id uuid references public.profiles(id) on delete restrict,
  terminal_at timestamptz,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint horse_role_grants_role_fk foreign key(organization_id,role_id)
    references public.organization_roles(organization_id,id) on delete restrict,
  constraint horse_role_grants_status_check check(status in ('active','revoked','expired','ended')),
  constraint horse_role_grants_time_check check(valid_until is null or valid_until>valid_from),
  constraint horse_role_grants_reason_check check(reason_code in ('MANUAL_GRANT','LINK_BOUND')),
  constraint horse_role_grants_terminal_shape check(
    (status='active' and terminal_reason_code is null and terminal_by_profile_id is null and terminal_at is null)
    or (status<>'active' and terminal_reason_code is not null and terminal_by_profile_id is not null and terminal_at is not null)
  ),
  constraint horse_role_grants_row_version_check check(row_version>=1),
  constraint horse_role_grants_creation_unique unique(
    grantor_profile_id,creation_correlation_id,horse_id,role_id,permission_id
  ),
  constraint horse_role_grants_no_overlap exclude using gist(
    horse_id with =,role_id with =,permission_id with =,
    tstzrange(valid_from,coalesce(valid_until,'infinity'::timestamptz),'[)') with &&
  ) where(status='active')
);

create table private.c003d_secrets (
  secret_name text primary key,
  secret_value bytea not null,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint c003d_secrets_name_check check(secret_name='invitation_hmac_v1'),
  constraint c003d_secrets_length_check check(pg_catalog.octet_length(secret_value)>=32)
);
insert into private.c003d_secrets(secret_name,secret_value)
values('invitation_hmac_v1',extensions.gen_random_bytes(32));

create table public.organization_invitations (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  initial_role_id uuid not null,
  inviter_profile_id uuid not null references public.profiles(id) on delete restrict,
  target_profile_id uuid references public.profiles(id) on delete restrict,
  target_email_hmac bytea not null,
  token_digest bytea,
  status text not null default 'pending',
  expires_at timestamptz not null,
  accepted_by_profile_id uuid references public.profiles(id) on delete restrict,
  terminal_reason_code text,
  terminal_at timestamptz,
  creation_correlation_id uuid not null,
  response_correlation_id uuid,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint organization_invitations_role_fk foreign key(organization_id,initial_role_id)
    references public.organization_roles(organization_id,id) on delete restrict,
  constraint organization_invitations_status_check check(status in ('pending','accepted','declined','revoked','expired')),
  constraint organization_invitations_expiry_check check(expires_at>created_at),
  constraint organization_invitations_pending_shape check(
    (status='pending' and token_digest is not null and terminal_reason_code is null and terminal_at is null and accepted_by_profile_id is null)
    or (status='accepted' and token_digest is null and terminal_reason_code='ACCEPTED' and terminal_at is not null and accepted_by_profile_id is not null)
    or (status in ('declined','revoked','expired') and token_digest is null and terminal_reason_code is not null and terminal_at is not null and accepted_by_profile_id is null)
  ),
  constraint organization_invitations_hmac_length_check check(pg_catalog.octet_length(target_email_hmac)=32),
  constraint organization_invitations_token_length_check check(token_digest is null or pg_catalog.octet_length(token_digest)=32),
  constraint organization_invitations_row_version_check check(row_version>=1),
  constraint organization_invitations_creation_unique unique(inviter_profile_id,creation_correlation_id)
);
create unique index organization_invitations_token_unique on public.organization_invitations(token_digest) where token_digest is not null;
create index organization_invitations_org_status_idx on public.organization_invitations(organization_id,status);
create index organization_invitations_target_status_idx on public.organization_invitations(target_email_hmac,status);

create table public.horse_access_invitations (
  id uuid primary key default extensions.gen_random_uuid(),
  horse_id uuid not null references public.canonical_horses(id) on delete restrict,
  inviter_profile_id uuid not null references public.profiles(id) on delete restrict,
  target_profile_id uuid references public.profiles(id) on delete restrict,
  target_email_hmac bytea not null,
  token_digest bytea,
  status text not null default 'pending',
  expires_at timestamptz not null,
  accepted_by_profile_id uuid references public.profiles(id) on delete restrict,
  terminal_reason_code text,
  terminal_at timestamptz,
  creation_correlation_id uuid not null,
  response_correlation_id uuid,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint horse_access_invitations_status_check check(status in ('pending','accepted','declined','revoked','expired')),
  constraint horse_access_invitations_expiry_check check(expires_at>created_at),
  constraint horse_access_invitations_pending_shape check(
    (status='pending' and token_digest is not null and terminal_reason_code is null and terminal_at is null and accepted_by_profile_id is null)
    or (status='accepted' and token_digest is null and terminal_reason_code='ACCEPTED' and terminal_at is not null and accepted_by_profile_id is not null)
    or (status in ('declined','revoked','expired') and token_digest is null and terminal_reason_code is not null and terminal_at is not null and accepted_by_profile_id is null)
  ),
  constraint horse_access_invitations_hmac_length_check check(pg_catalog.octet_length(target_email_hmac)=32),
  constraint horse_access_invitations_token_length_check check(token_digest is null or pg_catalog.octet_length(token_digest)=32),
  constraint horse_access_invitations_row_version_check check(row_version>=1),
  constraint horse_access_invitations_creation_unique unique(inviter_profile_id,creation_correlation_id)
);
create unique index horse_access_invitations_token_unique on public.horse_access_invitations(token_digest) where token_digest is not null;
create index horse_access_invitations_horse_status_idx on public.horse_access_invitations(horse_id,status);
create index horse_access_invitations_target_status_idx on public.horse_access_invitations(target_email_hmac,status);

create table public.horse_access_invitation_permissions (
  id uuid primary key default extensions.gen_random_uuid(),
  invitation_id uuid not null references public.horse_access_invitations(id) on delete restrict,
  permission_id uuid not null references public.permission_definitions(id) on delete restrict,
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  reason_code text not null default 'INVITATION_ACCEPTED',
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint horse_invitation_permissions_unique unique(invitation_id,permission_id),
  constraint horse_invitation_permissions_time_check check(valid_until is null or valid_until>valid_from),
  constraint horse_invitation_permissions_reason_check check(reason_code='INVITATION_ACCEPTED')
);

create table public.rider_performance_profile_share_grants (
  id uuid primary key default extensions.gen_random_uuid(),
  owner_profile_id uuid not null references public.profiles(id) on delete restrict,
  grantee_profile_id uuid not null references public.profiles(id) on delete restrict,
  category_code text not null,
  record_id uuid,
  status text not null default 'active',
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  terminal_reason_code text,
  terminal_at timestamptz,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint rider_profile_shares_distinct_check check(owner_profile_id<>grantee_profile_id),
  constraint rider_profile_shares_category_check check(category_code~'^[a-z][a-z0-9_]{1,62}$'),
  constraint rider_profile_shares_status_check check(status in ('active','revoked','expired','ended')),
  constraint rider_profile_shares_time_check check(valid_until is null or valid_until>valid_from),
  constraint rider_profile_shares_terminal_shape check((status='active' and terminal_reason_code is null and terminal_at is null) or (status<>'active' and terminal_reason_code is not null and terminal_at is not null)),
  constraint rider_profile_shares_row_version_check check(row_version>=1),
  constraint rider_profile_shares_creation_unique unique(owner_profile_id,creation_correlation_id)
);
create unique index rider_profile_shares_active_unique on public.rider_performance_profile_share_grants(
  owner_profile_id,grantee_profile_id,category_code,coalesce(record_id,'00000000-0000-0000-0000-000000000000'::uuid)
) where status='active';

create table public.rider_performance_org_role_share_grants (
  id uuid primary key default extensions.gen_random_uuid(),
  owner_profile_id uuid not null references public.profiles(id) on delete restrict,
  organization_id uuid not null references public.organizations(id) on delete restrict,
  role_id uuid not null,
  category_code text not null,
  record_id uuid,
  status text not null default 'active',
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  terminal_reason_code text,
  terminal_at timestamptz,
  creation_correlation_id uuid not null,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint rider_role_shares_role_fk foreign key(organization_id,role_id)
    references public.organization_roles(organization_id,id) on delete restrict,
  constraint rider_role_shares_category_check check(category_code~'^[a-z][a-z0-9_]{1,62}$'),
  constraint rider_role_shares_status_check check(status in ('active','revoked','expired','ended')),
  constraint rider_role_shares_time_check check(valid_until is null or valid_until>valid_from),
  constraint rider_role_shares_terminal_shape check((status='active' and terminal_reason_code is null and terminal_at is null) or (status<>'active' and terminal_reason_code is not null and terminal_at is not null)),
  constraint rider_role_shares_row_version_check check(row_version>=1),
  constraint rider_role_shares_creation_unique unique(owner_profile_id,creation_correlation_id)
);
create unique index rider_role_shares_active_unique on public.rider_performance_org_role_share_grants(
  owner_profile_id,role_id,category_code,coalesce(record_id,'00000000-0000-0000-0000-000000000000'::uuid)
) where status='active';

create index horse_profile_grants_grantee_idx on public.horse_profile_permission_grants(grantee_profile_id,status,horse_id);
create index horse_profile_grants_relationship_idx on public.horse_profile_permission_grants(horse_person_relationship_id,status);
create index horse_role_grants_role_idx on public.horse_organization_role_permission_grants(role_id,status,horse_id);
create index horse_role_grants_link_idx on public.horse_organization_role_permission_grants(organization_horse_link_id,status);
create index rider_profile_shares_grantee_idx on public.rider_performance_profile_share_grants(grantee_profile_id,status);
create index rider_role_shares_role_idx on public.rider_performance_org_role_share_grants(role_id,status);

-- Extend the immutable audit allowlists with PII-free permission, invitation
-- and Rider Performance share events.
alter table public.audit_events drop constraint audit_events_event_type_check;
alter table public.audit_events add constraint audit_events_event_type_check check(event_type in(
  'profile.provisioned','profile.display_fields_updated','profile.deletion_requested',
  'profile.auth_removal_prepared','profile.anonymization_finalized','profile.lifecycle_denied',
  'organization.created','organization.updated','organization.membership_created',
  'organization.membership_status_changed','organization.role_created','organization.role_status_changed',
  'organization.role_permission_granted','organization.role_permission_revoked',
  'organization.membership_role_granted','organization.membership_role_revoked','organization.access_changed',
  'horse.created','horse.updated','horse.access_changed','horse.delegation_granted','horse.delegation_ended',
  'horse.person_ownership_started','horse.person_ownership_ended','horse.organization_ownership_started',
  'horse.organization_ownership_ended','horse.person_relationship_started','horse.person_relationship_ended',
  'horse.organization_link_proposed','horse.organization_link_activated','horse.organization_link_rejected',
  'horse.organization_link_withdrawn','horse.organization_link_expired','horse.organization_link_ended',
  'horse.residency_started','horse.residency_switched','horse.residency_ended',
  'permission.horse_profile_granted','permission.horse_profile_revoked','permission.horse_profile_expired',
  'permission.horse_role_granted','permission.horse_role_revoked','permission.horse_role_expired',
  'permission.denied_escalation',
  'invitation.organization_created','invitation.organization_accepted','invitation.organization_declined',
  'invitation.organization_revoked','invitation.organization_expired',
  'invitation.horse_created','invitation.horse_accepted','invitation.horse_declined',
  'invitation.horse_revoked','invitation.horse_expired',
  'rider_performance.profile_share_granted','rider_performance.profile_share_revoked',
  'rider_performance.profile_share_expired','rider_performance.role_share_granted',
  'rider_performance.role_share_revoked','rider_performance.role_share_expired'
));

alter table public.audit_events drop constraint audit_events_profile_resource_check;
alter table public.audit_events add constraint audit_events_profile_resource_check check(
  (resource_kind='profile' and scope_kind='profile' and resource_id=scope_id)
  or (resource_kind in('rider_profile_share_grant','rider_role_share_grant') and scope_kind='profile')
  or (resource_kind in('organization','organization_membership','organization_role',
      'organization_role_permission','organization_membership_role','organization_invitation') and scope_kind='organization')
  or (resource_kind in('horse','horse_delegation','horse_person_ownership','horse_organization_ownership',
      'horse_person_relationship','organization_horse_link','horse_residency',
      'horse_profile_permission_grant','horse_role_permission_grant','horse_access_invitation') and scope_kind='horse')
);

alter table public.audit_events drop constraint audit_events_reason_code_check;
alter table public.audit_events add constraint audit_events_reason_code_check check(reason_code in(
  'AUTH_USER_CREATED','PROFILE_FIELDS_CHANGED','USER_DELETION_REQUEST','C003A_AUTH_REMOVAL_PREPARED',
  'C003A_ANONYMIZATION_FINALIZED','LIFECYCLE_REQUEST_DENIED','ORGANIZATION_CREATED','ORGANIZATION_UPDATED',
  'MEMBERSHIP_CREATED','MEMBERSHIP_STATUS_CHANGED','ROLE_CREATED','ROLE_STATUS_CHANGED',
  'ROLE_PERMISSION_GRANTED','ROLE_PERMISSION_REVOKED','MEMBERSHIP_ROLE_GRANTED','MEMBERSHIP_ROLE_REVOKED',
  'ACCESS_CHANGED','HORSE_CREATED','HORSE_UPDATED','DELEGATION_GRANTED','DELEGATION_ENDED',
  'PERSON_OWNERSHIP_STARTED','PERSON_OWNERSHIP_ENDED','ORGANIZATION_OWNERSHIP_STARTED',
  'ORGANIZATION_OWNERSHIP_ENDED','PERSON_RELATIONSHIP_STARTED','PERSON_RELATIONSHIP_ENDED',
  'ORGANIZATION_LINK_PROPOSED','ORGANIZATION_LINK_ACTIVATED','ORGANIZATION_LINK_REJECTED',
  'ORGANIZATION_LINK_WITHDRAWN','ORGANIZATION_LINK_EXPIRED','ORGANIZATION_LINK_ENDED',
  'RESIDENCY_STARTED','RESIDENCY_SWITCHED','RESIDENCY_ENDED',
  'HORSE_PERMISSION_GRANTED','HORSE_PERMISSION_REVOKED','HORSE_PERMISSION_EXPIRED',
  'PERMISSION_ESCALATION_DENIED','ORGANIZATION_INVITATION_CREATED','ORGANIZATION_INVITATION_ACCEPTED',
  'ORGANIZATION_INVITATION_DECLINED','ORGANIZATION_INVITATION_REVOKED','ORGANIZATION_INVITATION_EXPIRED',
  'HORSE_INVITATION_CREATED','HORSE_INVITATION_ACCEPTED','HORSE_INVITATION_DECLINED',
  'HORSE_INVITATION_REVOKED','HORSE_INVITATION_EXPIRED','RIDER_SHARE_GRANTED',
  'RIDER_SHARE_REVOKED','RIDER_SHARE_EXPIRED'
));

alter table public.audit_events drop constraint audit_events_metadata_shape_check;
alter table public.audit_events add constraint audit_events_metadata_shape_check check(
  private.c003a_audit_json_keys_allowed(metadata,array[
    'changed_fields','dependency_checks_complete','denial_code','operation_code','role_code',
    'permission_code','target_profile_id','permission_codes','organization_id','relationship_type',
    'link_type','initiating_context','relationship_id','link_id','invitation_kind',
    'target_role_id','category_code','record_id','action_code'
  ])
);

create or replace function private.c003d_actor_profile_id()
returns uuid language plpgsql stable security definer set search_path='' as $$
begin return private.c003c_actor_profile_id(); end;
$$;

create or replace function private.c003d_normalize_email(p_email text)
returns text language sql immutable set search_path='' as $$
  select pg_catalog.lower(pg_catalog.btrim(p_email))
$$;

create or replace function private.c003d_hmac(p_domain text,p_value text)
returns bytea language sql stable security definer set search_path='' as $$
  select extensions.hmac(
    pg_catalog.convert_to(p_domain||':'||p_value,'UTF8'),secret.secret_value,'sha256'
  ) from private.c003d_secrets secret where secret.secret_name='invitation_hmac_v1'
$$;

create or replace function private.c003d_token_digest(p_token text)
returns bytea language sql stable security definer set search_path='' as $$
  select private.c003d_hmac('token',p_token)
$$;

create or replace function private.c003d_email_hmac(p_email text)
returns bytea language plpgsql stable security definer set search_path='' as $$
declare normalized text;
begin
  normalized:=private.c003d_normalize_email(p_email);
  if normalized is null or normalized !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' or pg_catalog.length(normalized)>320
  then raise exception using errcode='22023',message='TARGET_EMAIL_INVALID'; end if;
  return private.c003d_hmac('email',normalized);
end;
$$;

create or replace function private.c003d_actor_verified_email_hmac(p_profile_id uuid)
returns bytea language plpgsql stable security definer set search_path='' as $$
declare email_value text;
begin
  select auth_user.email into email_value
  from public.profiles profile join auth.users auth_user on auth_user.id=profile.auth_user_id
  where profile.id=p_profile_id and profile.status='active'
    and auth_user.email is not null and auth_user.email_confirmed_at is not null;
  if email_value is null then raise exception using errcode='42501',message='VERIFIED_AUTH_EMAIL_REQUIRED'; end if;
  return private.c003d_email_hmac(email_value);
end;
$$;

create or replace function private.c003d_resolve_target_profile(p_email text)
returns uuid language sql stable security definer set search_path='' as $$
  select profile.id
  from auth.users auth_user join public.profiles profile on profile.auth_user_id=auth_user.id
  where profile.status='active' and auth_user.email_confirmed_at is not null
    and private.c003d_normalize_email(auth_user.email)=private.c003d_normalize_email(p_email)
  order by profile.id limit 1
$$;

create or replace function private.c003d_write_audit(
  p_event_type text,p_resource_kind text,p_resource_id uuid,p_scope_kind text,p_scope_id uuid,
  p_actor_profile_id uuid,p_correlation_id uuid,p_reason_code text,p_old_status text,p_new_status text,
  p_row_before bigint,p_row_after bigint,p_access_before bigint,p_access_after bigint,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid language plpgsql security definer set search_path='' as $$
declare event_id uuid;
begin
  if p_actor_profile_id is null or p_scope_id is null or p_correlation_id is null or p_metadata is null
    or p_scope_kind not in('profile','organization','horse')
    or p_resource_kind not in('horse_profile_permission_grant','horse_role_permission_grant',
      'organization_invitation','horse_access_invitation','rider_profile_share_grant','rider_role_share_grant')
    or exists(select 1 from pg_catalog.jsonb_object_keys(p_metadata) key_name where key_name not in(
      'operation_code','permission_code','target_profile_id','organization_id','relationship_id',
      'link_id','invitation_kind','target_role_id','category_code','record_id','action_code'))
  then raise exception using errcode='22023',message='C003D_AUDIT_INPUT_INVALID'; end if;
  insert into public.audit_events(
    actor_kind,actor_profile_id,event_type,resource_kind,resource_id,scope_kind,scope_id,
    old_state,new_state,reason_code,correlation_id,channel,row_version_before,row_version_after,
    access_version_before,access_version_after,metadata
  ) values(
    'profile',p_actor_profile_id,p_event_type,p_resource_kind,p_resource_id,p_scope_kind,p_scope_id,
    case when p_old_status is null then '{}'::jsonb else pg_catalog.jsonb_build_object('status',p_old_status) end,
    case when p_new_status is null then '{}'::jsonb else pg_catalog.jsonb_build_object('status',p_new_status) end,
    p_reason_code,p_correlation_id,'rpc',p_row_before,p_row_after,p_access_before,p_access_after,p_metadata
  ) returning id into event_id;
  return event_id;
end;
$$;

create or replace function private.c003d_role_profile_ids(
  p_role_id uuid,p_at timestamptz default pg_catalog.statement_timestamp()
)
returns uuid[] language sql stable security definer set search_path='' as $$
  select coalesce(pg_catalog.array_agg(distinct membership.profile_id),array[]::uuid[])
  from public.organization_roles role
  join public.organization_membership_roles assignment on assignment.role_id=role.id and assignment.organization_id=role.organization_id
  join public.organization_memberships membership on membership.id=assignment.membership_id and membership.organization_id=role.organization_id
  join public.profiles profile on profile.id=membership.profile_id
  join public.organizations organization on organization.id=role.organization_id
  where role.id=p_role_id and role.status='active' and organization.status='active' and profile.status='active'
    and membership.status='active' and membership.valid_from<=p_at and (membership.valid_until is null or membership.valid_until>p_at)
    and assignment.status='active' and assignment.valid_from<=p_at and (assignment.valid_until is null or assignment.valid_until>p_at)
$$;

create or replace function private.c003d_bump_profiles(p_profile_ids uuid[])
returns void language plpgsql security definer set search_path='' as $$
declare profile_id uuid;
begin
  foreach profile_id in array coalesce(p_profile_ids,array[]::uuid[]) loop
    update public.profiles profile set access_version=profile.access_version+1 where profile.id=profile_id and profile.status='active';
  end loop;
end;
$$;

create or replace function private.c003d_guard_horse_grant()
returns trigger language plpgsql security definer set search_path='' as $$
declare permission_row public.permission_definitions%rowtype;
begin
  select permission.* into permission_row from public.permission_definitions permission where permission.id=new.permission_id;
  if permission_row.scope_kind<>'horse' or not permission_row.is_active or not permission_row.is_grantable
    or permission_row.code='horse.transfer'
  then raise exception using errcode='23514',message='HORSE_GRANT_PERMISSION_INVALID'; end if;
  if tg_table_name='horse_profile_permission_grants' then
    if new.status='active' and new.horse_person_relationship_id is not null
      and not exists(select 1 from public.horse_person_relationships relationship
        where relationship.id=new.horse_person_relationship_id and relationship.horse_id=new.horse_id
          and relationship.profile_id=new.grantee_profile_id and relationship.status='active'
          and relationship.valid_from<=pg_catalog.statement_timestamp()
          and (relationship.valid_until is null or relationship.valid_until>pg_catalog.statement_timestamp()))
    then raise exception using errcode='23514',message='RELATIONSHIP_GRANT_SCOPE_MISMATCH';end if;
  elsif tg_table_name='horse_organization_role_permission_grants' then
    if new.status='active' and new.organization_horse_link_id is not null
      and not exists(select 1 from public.organization_horse_links link
        where link.id=new.organization_horse_link_id and link.horse_id=new.horse_id
          and link.organization_id=new.organization_id and link.status='active')
    then raise exception using errcode='23514',message='LINK_GRANT_SCOPE_MISMATCH';end if;
  end if;
  return new;
end;
$$;

create trigger c003d_horse_profile_grants_before_write
before insert or update on public.horse_profile_permission_grants
for each row execute function private.c003d_guard_horse_grant();
create trigger c003d_horse_role_grants_before_write
before insert or update on public.horse_organization_role_permission_grants
for each row execute function private.c003d_guard_horse_grant();

-- Organization roles remain organization-scoped. This database invariant also
-- protects owner/direct writes, not only the public C-003B RPC layer.
create or replace function private.c003d_guard_organization_role_permission()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if not exists(
    select 1 from public.permission_definitions permission
    where permission.id=new.permission_id and permission.scope_kind='organization'
      and permission.is_active
  ) then
    raise exception using errcode='23514',message='ORGANIZATION_PERMISSION_SCOPE_REQUIRED';
  end if;
  return new;
end;
$$;
create trigger c003d_organization_role_permissions_before_write
before insert or update on public.organization_role_permissions
for each row execute function private.c003d_guard_organization_role_permission();

create or replace function private.c003d_guard_invitation_permission()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if not exists(
    select 1 from public.permission_definitions permission
    where permission.id=new.permission_id and permission.scope_kind='horse'
      and permission.is_active and permission.is_grantable and permission.code<>'horse.transfer'
  ) then raise exception using errcode='23514',message='HORSE_INVITATION_PERMISSION_INVALID';end if;
  return new;
end;
$$;
create trigger c003d_horse_invitation_permissions_before_write
before insert or update on public.horse_access_invitation_permissions
for each row execute function private.c003d_guard_invitation_permission();

create or replace function private.c003d_guard_terminal_history()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='DELETE' then
    raise exception using errcode='55000',message='C003D_HISTORY_DELETE_FORBIDDEN';
  end if;
  if old.status not in('active','pending') then
    raise exception using errcode='55000',message='C003D_TERMINAL_STATE_IMMUTABLE';
  end if;
  return new;
end;
$$;
create trigger c003d_profile_grants_terminal_history
before update or delete on public.horse_profile_permission_grants
for each row execute function private.c003d_guard_terminal_history();
create trigger c003d_role_grants_terminal_history
before update or delete on public.horse_organization_role_permission_grants
for each row execute function private.c003d_guard_terminal_history();
create trigger c003d_organization_invitations_terminal_history
before update or delete on public.organization_invitations
for each row execute function private.c003d_guard_terminal_history();
create trigger c003d_horse_invitations_terminal_history
before update or delete on public.horse_access_invitations
for each row execute function private.c003d_guard_terminal_history();
create trigger c003d_rider_profile_shares_terminal_history
before update or delete on public.rider_performance_profile_share_grants
for each row execute function private.c003d_guard_terminal_history();
create trigger c003d_rider_role_shares_terminal_history
before update or delete on public.rider_performance_org_role_share_grants
for each row execute function private.c003d_guard_terminal_history();

-- C-003B created the reserved head role from the then organization-only
-- catalog. Filter explicitly now that C-003D adds horse capabilities.
create or replace function public.create_organization(
  p_organization_type_code text,p_name text,p_description text,
  p_correlation_id uuid,p_client_context jsonb default '{}'::jsonb
)
returns table(
  organization_id uuid,membership_id uuid,head_admin_role_id uuid,
  organization_access_version bigint,organization_row_version bigint,
  result_code text,applied boolean
)
language plpgsql security definer set search_path='' as $$
declare
  actor_id uuid;type_id uuid;org_id uuid;member_id uuid;role_id uuid;
  existing public.organizations%rowtype;
begin
  actor_id:=private.c003b_actor_profile_id();
  if p_correlation_id is null then raise exception using errcode='22023',message='CORRELATION_ID_REQUIRED';end if;
  if p_client_context is not null and pg_catalog.jsonb_typeof(p_client_context)<>'object'
  then raise exception using errcode='22023',message='CLIENT_CONTEXT_INVALID';end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(actor_id::text||p_correlation_id::text,0));
  select organization.* into existing from public.organizations organization
  where organization.created_by_profile_id=actor_id and organization.creation_correlation_id=p_correlation_id;
  if found then
    select membership.id into member_id from public.organization_memberships membership
      where membership.organization_id=existing.id and membership.profile_id=actor_id;
    select role.id into role_id from public.organization_roles role
      where role.organization_id=existing.id and role.code='head_admin';
    return query select existing.id,member_id,role_id,existing.access_version,
      existing.row_version,'idempotent_replay'::text,false;return;
  end if;
  select organization_type.id into type_id from public.organization_types organization_type
    where organization_type.code=p_organization_type_code and organization_type.is_active;
  if type_id is null then raise exception using errcode='22023',message='ORGANIZATION_TYPE_INVALID';end if;
  if pg_catalog.length(pg_catalog.btrim(coalesce(p_name,''))) not between 1 and 160
  then raise exception using errcode='22023',message='ORGANIZATION_NAME_INVALID';end if;
  org_id:=extensions.gen_random_uuid();member_id:=extensions.gen_random_uuid();role_id:=extensions.gen_random_uuid();
  insert into public.organizations(
    id,organization_type_id,name,description,primary_admin_profile_id,
    created_by_profile_id,creation_correlation_id
  ) values(org_id,type_id,pg_catalog.btrim(p_name),nullif(pg_catalog.btrim(p_description),''),actor_id,actor_id,p_correlation_id);
  insert into public.organization_memberships(
    id,organization_id,profile_id,created_by_profile_id,creation_correlation_id
  ) values(member_id,org_id,actor_id,actor_id,p_correlation_id);
  insert into public.organization_roles(
    id,organization_id,code,name,description,is_system,is_reserved,
    created_by_profile_id,creation_correlation_id
  ) values(role_id,org_id,'head_admin','Head administrator','Reserved primary administrator role.',true,true,actor_id,p_correlation_id);
  insert into public.organization_role_permissions(
    organization_id,role_id,permission_id,granted_by_profile_id,correlation_id
  ) select org_id,role_id,permission.id,actor_id,extensions.gen_random_uuid()
    from public.permission_definitions permission
    where permission.is_active and permission.scope_kind='organization';
  insert into public.organization_membership_roles(
    organization_id,membership_id,role_id,granted_by_profile_id,creation_correlation_id
  ) values(org_id,member_id,role_id,actor_id,p_correlation_id);
  update public.profiles profile set access_version=profile.access_version+1 where profile.id=actor_id;
  perform private.c003b_write_audit(
    'organization.created','organization',org_id,org_id,actor_id,p_correlation_id,
    'ORGANIZATION_CREATED',null,'active',null,1,null,1,
    pg_catalog.jsonb_build_object('operation_code','create_organization')
  );
  return query select org_id,member_id,role_id,1::bigint,1::bigint,'created'::text,true;
end;
$$;

create or replace function private.c003c_profile_has_horse_permission(
  p_profile_id uuid,p_horse_id uuid,p_permission_code text,
  p_at timestamptz default pg_catalog.statement_timestamp()
)
returns boolean language sql stable security definer set search_path='' as $$
  select p_permission_code in('horse.view','horse.edit','horse.manage','horse.assign','horse.share','horse.transfer')
    and exists(
      select 1 from public.profiles profile join public.canonical_horses horse on horse.id=p_horse_id
      where profile.id=p_profile_id and profile.status='active' and(
        horse.primary_authority_profile_id=profile.id
        or(p_permission_code<>'horse.transfer' and exists(
          select 1 from public.horse_delegated_administrators delegation
          where delegation.horse_id=horse.id and delegation.profile_id=profile.id
            and delegation.status='active' and delegation.valid_from<=p_at
            and(delegation.valid_until is null or delegation.valid_until>p_at)
            and p_permission_code=any(delegation.permission_codes)
        ))
        or(p_permission_code<>'horse.transfer' and exists(
          select 1 from public.horse_profile_permission_grants grant_row
          join public.permission_definitions permission on permission.id=grant_row.permission_id
          where grant_row.horse_id=horse.id and grant_row.grantee_profile_id=profile.id
            and grant_row.status='active' and grant_row.valid_from<=p_at
            and(grant_row.valid_until is null or grant_row.valid_until>p_at)
            and permission.scope_kind='horse' and permission.is_active and permission.code=p_permission_code
            and(grant_row.horse_person_relationship_id is null or exists(
              select 1 from public.horse_person_relationships relationship
              where relationship.id=grant_row.horse_person_relationship_id and relationship.status='active'
                and relationship.valid_from<=p_at and(relationship.valid_until is null or relationship.valid_until>p_at)
            ))
        ))
        or(p_permission_code<>'horse.transfer' and exists(
          select 1 from public.horse_organization_role_permission_grants grant_row
          join public.permission_definitions permission on permission.id=grant_row.permission_id
          join public.organization_roles role on role.id=grant_row.role_id and role.organization_id=grant_row.organization_id
          join public.organization_membership_roles assignment on assignment.role_id=role.id and assignment.organization_id=role.organization_id
          join public.organization_memberships membership on membership.id=assignment.membership_id and membership.organization_id=role.organization_id
          join public.organizations organization on organization.id=role.organization_id
          where grant_row.horse_id=horse.id and membership.profile_id=profile.id
            and grant_row.status='active' and grant_row.valid_from<=p_at and(grant_row.valid_until is null or grant_row.valid_until>p_at)
            and permission.scope_kind='horse' and permission.is_active and permission.code=p_permission_code
            and organization.status='active' and role.status='active' and membership.status='active'
            and membership.valid_from<=p_at and(membership.valid_until is null or membership.valid_until>p_at)
            and assignment.status='active' and assignment.valid_from<=p_at and(assignment.valid_until is null or assignment.valid_until>p_at)
            and(grant_row.organization_horse_link_id is null or exists(
              select 1 from public.organization_horse_links link
              where link.id=grant_row.organization_horse_link_id and link.status='active'
            ))
        ))
      )
    )
$$;

create or replace function private.c003d_profile_can_grant_horse_permission(
  p_profile_id uuid,p_horse_id uuid,p_permission_code text
)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.permission_definitions permission
      where permission.code=p_permission_code and permission.scope_kind='horse'
        and permission.is_active and permission.is_grantable and permission.code<>'horse.transfer')
    and private.c003c_profile_has_horse_permission(p_profile_id,p_horse_id,'horse.manage',pg_catalog.statement_timestamp())
    and private.c003c_profile_has_horse_permission(p_profile_id,p_horse_id,p_permission_code,pg_catalog.statement_timestamp())
$$;

create or replace function public.can_grant_canonical_horse_permission(p_horse_id uuid,p_permission_code text)
returns boolean language sql stable security definer set search_path='' as $$
  select private.c003d_profile_can_grant_horse_permission(private.current_profile_id(),p_horse_id,p_permission_code)
$$;

create or replace function public.grant_horse_profile_permission(
  p_horse_id uuid,p_grantee_profile_id uuid,p_permission_code text,
  p_relationship_id uuid,p_valid_from timestamptz,p_valid_until timestamptz,
  p_reason_code text,p_correlation_id uuid
)
returns table(grant_id uuid,row_version bigint,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;v_permission_id uuid;created public.horse_profile_permission_grants%rowtype;prior public.horse_profile_permission_grants%rowtype;
begin
  actor_id:=private.c003d_actor_profile_id();
  select permission.id into v_permission_id from public.permission_definitions permission where permission.code=p_permission_code;
  select grant_row.* into prior from public.horse_profile_permission_grants grant_row
  where grant_row.grantor_profile_id=actor_id and grant_row.creation_correlation_id=p_correlation_id
    and grant_row.horse_id=p_horse_id and grant_row.grantee_profile_id=p_grantee_profile_id
    and grant_row.permission_id=v_permission_id;
  if found then return query select prior.id,prior.row_version,false;return;end if;
  if not private.c003d_profile_can_grant_horse_permission(actor_id,p_horse_id,p_permission_code)
  then
    perform private.c003d_write_audit('permission.denied_escalation','horse_profile_permission_grant',p_horse_id,
      'horse',p_horse_id,actor_id,p_correlation_id,'PERMISSION_ESCALATION_DENIED',null,null,null,null,null,null,
      pg_catalog.jsonb_build_object('permission_code',coalesce(p_permission_code,'null'),'target_profile_id',p_grantee_profile_id::text,'operation_code','grant_profile'));
    return query select null::uuid,null::bigint,false;
    return;
  end if;
  if not exists(select 1 from public.profiles profile where profile.id=p_grantee_profile_id and profile.status='active')
  then raise exception using errcode='42501',message='ACTIVE_GRANTEE_PROFILE_REQUIRED'; end if;
  insert into public.horse_profile_permission_grants(
    horse_id,grantee_profile_id,permission_id,grantor_profile_id,horse_person_relationship_id,
    valid_from,valid_until,reason_code,creation_correlation_id
  ) values(p_horse_id,p_grantee_profile_id,v_permission_id,actor_id,p_relationship_id,
    coalesce(p_valid_from,pg_catalog.statement_timestamp()),p_valid_until,p_reason_code,p_correlation_id)
  returning * into created;
  perform private.c003c_bump_access(p_horse_id,array[p_grantee_profile_id],actor_id,p_correlation_id,'profile_permission_granted');
  perform private.c003d_write_audit('permission.horse_profile_granted','horse_profile_permission_grant',created.id,
    'horse',p_horse_id,actor_id,p_correlation_id,'HORSE_PERMISSION_GRANTED',null,created.status,null,created.row_version,null,null,
    pg_catalog.jsonb_build_object('permission_code',p_permission_code,'target_profile_id',p_grantee_profile_id::text,
      'relationship_id',p_relationship_id::text,'operation_code','grant_profile'));
  return query select created.id,created.row_version,true;
end;
$$;

create or replace function public.transition_horse_profile_permission_grant(
  p_grant_id uuid,p_expected_row_version bigint,p_action text,p_reason_code text,p_correlation_id uuid
)
returns table(row_version bigint,status text,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid; before_row public.horse_profile_permission_grants%rowtype; after_row public.horse_profile_permission_grants%rowtype; permission_code text; new_status text; event_name text; audit_reason text;
begin
  actor_id:=private.c003d_actor_profile_id();
  select grant_row.* into before_row from public.horse_profile_permission_grants grant_row
  where grant_row.id=p_grant_id for update;
  if not found then raise exception using errcode='P0002',message='HORSE_PROFILE_GRANT_NOT_FOUND'; end if;
  select permission.code into permission_code from public.permission_definitions permission where permission.id=before_row.permission_id;
  if not private.c003d_profile_can_grant_horse_permission(actor_id,before_row.horse_id,permission_code)
  then raise exception using errcode='42501',message='HORSE_PERMISSION_REVOKE_DENIED'; end if;
  if before_row.status<>'active' then return query select before_row.row_version,before_row.status,false; return; end if;
  if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_GRANT_VERSION'; end if;
  if p_action='expire' then
    if before_row.valid_until is null or before_row.valid_until>pg_catalog.statement_timestamp()
    then raise exception using errcode='22023',message='GRANT_NOT_DUE_FOR_EXPIRY'; end if;
    new_status:='expired';event_name:='permission.horse_profile_expired';audit_reason:='HORSE_PERMISSION_EXPIRED';
  elsif p_action in('revoke','end') then
    new_status:=case when p_action='revoke' then 'revoked' else 'ended' end;
    event_name:='permission.horse_profile_revoked';audit_reason:='HORSE_PERMISSION_REVOKED';
  else raise exception using errcode='22023',message='GRANT_ACTION_INVALID'; end if;
  update public.horse_profile_permission_grants grant_row set status=new_status,
    valid_until=case when grant_row.valid_until is null or grant_row.valid_until>pg_catalog.statement_timestamp() then greatest(pg_catalog.statement_timestamp(),grant_row.valid_from+interval '1 microsecond') else grant_row.valid_until end,
    terminal_reason_code=coalesce(nullif(pg_catalog.btrim(p_reason_code),''),pg_catalog.upper(p_action)),
    terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),row_version=grant_row.row_version+1,
    updated_at=pg_catalog.clock_timestamp() where grant_row.id=p_grant_id returning * into after_row;
  perform private.c003c_bump_access(before_row.horse_id,array[before_row.grantee_profile_id],actor_id,p_correlation_id,'profile_permission_'||p_action);
  perform private.c003d_write_audit(event_name,'horse_profile_permission_grant',p_grant_id,'horse',before_row.horse_id,
    actor_id,p_correlation_id,audit_reason,before_row.status,after_row.status,before_row.row_version,after_row.row_version,null,null,
    pg_catalog.jsonb_build_object('permission_code',permission_code,'target_profile_id',before_row.grantee_profile_id::text,'action_code',p_action));
  return query select after_row.row_version,after_row.status,true;
end;
$$;

create or replace function public.grant_horse_organization_role_permission(
  p_horse_id uuid,p_role_id uuid,p_permission_code text,p_link_id uuid,
  p_valid_from timestamptz,p_valid_until timestamptz,p_reason_code text,p_correlation_id uuid
)
returns table(grant_id uuid,row_version bigint,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;v_permission_id uuid;organization_id uuid;created public.horse_organization_role_permission_grants%rowtype;prior public.horse_organization_role_permission_grants%rowtype;profile_ids uuid[];
begin
  actor_id:=private.c003d_actor_profile_id();
  select permission.id into v_permission_id from public.permission_definitions permission where permission.code=p_permission_code;
  select grant_row.* into prior from public.horse_organization_role_permission_grants grant_row
  where grant_row.grantor_profile_id=actor_id and grant_row.creation_correlation_id=p_correlation_id
    and grant_row.horse_id=p_horse_id and grant_row.role_id=p_role_id and grant_row.permission_id=v_permission_id;
  if found then return query select prior.id,prior.row_version,false;return;end if;
  if not private.c003d_profile_can_grant_horse_permission(actor_id,p_horse_id,p_permission_code)
  then
    perform private.c003d_write_audit('permission.denied_escalation','horse_role_permission_grant',p_horse_id,
      'horse',p_horse_id,actor_id,p_correlation_id,'PERMISSION_ESCALATION_DENIED',null,null,null,null,null,null,
      pg_catalog.jsonb_build_object('permission_code',coalesce(p_permission_code,'null'),'target_role_id',p_role_id::text,'operation_code','grant_role'));
    return query select null::uuid,null::bigint,false;
    return;
  end if;
  select role.organization_id into organization_id from public.organization_roles role where role.id=p_role_id and role.status='active';
  if organization_id is null then raise exception using errcode='22023',message='ACTIVE_ORGANIZATION_ROLE_REQUIRED'; end if;
  insert into public.horse_organization_role_permission_grants(
    horse_id,organization_id,role_id,permission_id,grantor_profile_id,organization_horse_link_id,
    valid_from,valid_until,reason_code,creation_correlation_id
  ) values(p_horse_id,organization_id,p_role_id,v_permission_id,actor_id,p_link_id,
    coalesce(p_valid_from,pg_catalog.statement_timestamp()),p_valid_until,p_reason_code,p_correlation_id)
  returning * into created;
  profile_ids:=private.c003d_role_profile_ids(p_role_id);
  perform private.c003c_bump_access(p_horse_id,profile_ids,actor_id,p_correlation_id,'role_permission_granted');
  perform private.c003d_write_audit('permission.horse_role_granted','horse_role_permission_grant',created.id,'horse',p_horse_id,
    actor_id,p_correlation_id,'HORSE_PERMISSION_GRANTED',null,created.status,null,created.row_version,null,null,
    pg_catalog.jsonb_build_object('permission_code',p_permission_code,'organization_id',organization_id::text,
      'target_role_id',p_role_id::text,'link_id',p_link_id::text,'operation_code','grant_role'));
  return query select created.id,created.row_version,true;
end;
$$;

create or replace function public.transition_horse_organization_role_permission_grant(
  p_grant_id uuid,p_expected_row_version bigint,p_action text,p_reason_code text,p_correlation_id uuid
)
returns table(row_version bigint,status text,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid; before_row public.horse_organization_role_permission_grants%rowtype; after_row public.horse_organization_role_permission_grants%rowtype; permission_code text; new_status text; event_name text; audit_reason text; profile_ids uuid[];
begin
  actor_id:=private.c003d_actor_profile_id();
  select grant_row.* into before_row from public.horse_organization_role_permission_grants grant_row
  where grant_row.id=p_grant_id for update;
  if not found then raise exception using errcode='P0002',message='HORSE_ROLE_GRANT_NOT_FOUND'; end if;
  select permission.code into permission_code from public.permission_definitions permission where permission.id=before_row.permission_id;
  if not private.c003d_profile_can_grant_horse_permission(actor_id,before_row.horse_id,permission_code)
  then raise exception using errcode='42501',message='HORSE_PERMISSION_REVOKE_DENIED'; end if;
  if before_row.status<>'active' then return query select before_row.row_version,before_row.status,false; return; end if;
  if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_GRANT_VERSION'; end if;
  if p_action='expire' then
    if before_row.valid_until is null or before_row.valid_until>pg_catalog.statement_timestamp() then raise exception using errcode='22023',message='GRANT_NOT_DUE_FOR_EXPIRY'; end if;
    new_status:='expired';event_name:='permission.horse_role_expired';audit_reason:='HORSE_PERMISSION_EXPIRED';
  elsif p_action in('revoke','end') then new_status:=case when p_action='revoke' then 'revoked' else 'ended' end;event_name:='permission.horse_role_revoked';audit_reason:='HORSE_PERMISSION_REVOKED';
  else raise exception using errcode='22023',message='GRANT_ACTION_INVALID'; end if;
  profile_ids:=private.c003d_role_profile_ids(before_row.role_id);
  update public.horse_organization_role_permission_grants grant_row set status=new_status,
    valid_until=case when grant_row.valid_until is null or grant_row.valid_until>pg_catalog.statement_timestamp() then greatest(pg_catalog.statement_timestamp(),grant_row.valid_from+interval '1 microsecond') else grant_row.valid_until end,
    terminal_reason_code=coalesce(nullif(pg_catalog.btrim(p_reason_code),''),pg_catalog.upper(p_action)),terminal_by_profile_id=actor_id,
    terminal_at=pg_catalog.clock_timestamp(),row_version=grant_row.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where grant_row.id=p_grant_id returning * into after_row;
  perform private.c003c_bump_access(before_row.horse_id,profile_ids,actor_id,p_correlation_id,'role_permission_'||p_action);
  perform private.c003d_write_audit(event_name,'horse_role_permission_grant',p_grant_id,'horse',before_row.horse_id,
    actor_id,p_correlation_id,audit_reason,before_row.status,after_row.status,before_row.row_version,after_row.row_version,null,null,
    pg_catalog.jsonb_build_object('permission_code',permission_code,'organization_id',before_row.organization_id::text,'target_role_id',before_row.role_id::text,'action_code',p_action));
  return query select after_row.row_version,after_row.status,true;
end;
$$;

create or replace function private.c003d_revoke_bound_grants()
returns trigger language plpgsql security definer set search_path='' as $$
declare actor_id uuid; correlation_id uuid:=extensions.gen_random_uuid(); grant_row record; permission_code text; profile_ids uuid[]:=array[]::uuid[]; affected uuid[];
begin
  actor_id:=private.c003d_actor_profile_id();
  if tg_table_name='horse_person_relationships' and old.status='active' and new.status='ended' then
    for grant_row in
      update public.horse_profile_permission_grants grant_value set status='revoked',
        valid_until=case when grant_value.valid_until is null or grant_value.valid_until>pg_catalog.statement_timestamp() then greatest(pg_catalog.statement_timestamp(),grant_value.valid_from+interval '1 microsecond') else grant_value.valid_until end,
        terminal_reason_code='BOUND_RELATIONSHIP_ENDED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
        row_version=grant_value.row_version+1,updated_at=pg_catalog.clock_timestamp()
      where grant_value.horse_person_relationship_id=new.id and grant_value.status='active'
      returning grant_value.*
    loop
      select permission.code into permission_code from public.permission_definitions permission where permission.id=grant_row.permission_id;
      profile_ids:=pg_catalog.array_append(profile_ids,grant_row.grantee_profile_id);
      perform private.c003d_write_audit('permission.horse_profile_revoked','horse_profile_permission_grant',grant_row.id,
        'horse',grant_row.horse_id,actor_id,correlation_id,'HORSE_PERMISSION_REVOKED','active','revoked',
        grant_row.row_version-1,grant_row.row_version,null,null,pg_catalog.jsonb_build_object(
          'permission_code',permission_code,'target_profile_id',grant_row.grantee_profile_id::text,
          'relationship_id',new.id::text,'operation_code','bound_relationship_ended'));
    end loop;
    if pg_catalog.cardinality(profile_ids)>0 then
      perform private.c003c_bump_access(new.horse_id,profile_ids,actor_id,correlation_id,'bound_relationship_grants_revoked');
    end if;
  elsif tg_table_name='organization_horse_links' and old.status='active' and new.status='ended' then
    for grant_row in
      update public.horse_organization_role_permission_grants grant_value set status='revoked',
        valid_until=case when grant_value.valid_until is null or grant_value.valid_until>pg_catalog.statement_timestamp() then greatest(pg_catalog.statement_timestamp(),grant_value.valid_from+interval '1 microsecond') else grant_value.valid_until end,
        terminal_reason_code='BOUND_LINK_ENDED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
        row_version=grant_value.row_version+1,updated_at=pg_catalog.clock_timestamp()
      where grant_value.organization_horse_link_id=new.id and grant_value.status='active'
      returning grant_value.*
    loop
      select permission.code into permission_code from public.permission_definitions permission where permission.id=grant_row.permission_id;
      affected:=private.c003d_role_profile_ids(grant_row.role_id);
      profile_ids:=profile_ids||affected;
      perform private.c003d_write_audit('permission.horse_role_revoked','horse_role_permission_grant',grant_row.id,
        'horse',grant_row.horse_id,actor_id,correlation_id,'HORSE_PERMISSION_REVOKED','active','revoked',
        grant_row.row_version-1,grant_row.row_version,null,null,pg_catalog.jsonb_build_object(
          'permission_code',permission_code,'organization_id',grant_row.organization_id::text,
          'target_role_id',grant_row.role_id::text,'link_id',new.id::text,'operation_code','bound_link_ended'));
    end loop;
    if pg_catalog.cardinality(profile_ids)>0 then
      select pg_catalog.array_agg(distinct value) into profile_ids from unnest(profile_ids) value;
      perform private.c003c_bump_access(new.horse_id,profile_ids,actor_id,correlation_id,'bound_link_grants_revoked');
      perform private.c003b_bump_access(new.organization_id,array[]::uuid[],actor_id,correlation_id,'bound_link_grants_revoked');
    end if;
  end if;
  return new;
end;
$$;

create trigger c003d_relationship_bound_grants_after_update
after update of status on public.horse_person_relationships
for each row execute function private.c003d_revoke_bound_grants();
create trigger c003d_link_bound_grants_after_update
after update of status on public.organization_horse_links
for each row execute function private.c003d_revoke_bound_grants();

create or replace function private.c003d_profile_has_rider_share(
  p_actor_profile_id uuid,p_owner_profile_id uuid,p_category_code text,p_record_id uuid,
  p_at timestamptz default pg_catalog.statement_timestamp()
)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.profiles actor where actor.id=p_actor_profile_id and actor.status='active') and(
    p_actor_profile_id=p_owner_profile_id
    or exists(select 1 from public.rider_performance_profile_share_grants share
      where share.owner_profile_id=p_owner_profile_id and share.grantee_profile_id=p_actor_profile_id
        and share.category_code=p_category_code and(share.record_id is null or share.record_id=p_record_id)
        and share.status='active' and share.valid_from<=p_at and(share.valid_until is null or share.valid_until>p_at))
    or exists(select 1 from public.rider_performance_org_role_share_grants share
      join public.organization_roles role on role.id=share.role_id and role.organization_id=share.organization_id
      join public.organization_membership_roles assignment on assignment.role_id=role.id and assignment.organization_id=role.organization_id
      join public.organization_memberships membership on membership.id=assignment.membership_id and membership.organization_id=role.organization_id
      join public.organizations organization on organization.id=role.organization_id
      where share.owner_profile_id=p_owner_profile_id and membership.profile_id=p_actor_profile_id
        and share.category_code=p_category_code and(share.record_id is null or share.record_id=p_record_id)
        and share.status='active' and share.valid_from<=p_at and(share.valid_until is null or share.valid_until>p_at)
        and role.status='active' and organization.status='active' and membership.status='active'
        and membership.valid_from<=p_at and(membership.valid_until is null or membership.valid_until>p_at)
        and assignment.status='active' and assignment.valid_from<=p_at and(assignment.valid_until is null or assignment.valid_until>p_at))
  )
$$;

create or replace function public.has_rider_performance_share(
  p_owner_profile_id uuid,p_category_code text,p_record_id uuid default null
)
returns boolean language sql stable security definer set search_path='' as $$
  select private.c003d_profile_has_rider_share(private.current_profile_id(),p_owner_profile_id,p_category_code,p_record_id,pg_catalog.statement_timestamp())
$$;

create or replace function public.grant_rider_performance_profile_share(
  p_grantee_profile_id uuid,p_category_code text,p_record_id uuid,p_valid_from timestamptz,p_valid_until timestamptz,p_correlation_id uuid
)
returns table(grant_id uuid,row_version bigint,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid; created public.rider_performance_profile_share_grants%rowtype;prior public.rider_performance_profile_share_grants%rowtype;
begin
  actor_id:=private.c003d_actor_profile_id();
  select grant_row.* into prior from public.rider_performance_profile_share_grants grant_row
    where grant_row.owner_profile_id=actor_id and grant_row.creation_correlation_id=p_correlation_id;
  if found then return query select prior.id,prior.row_version,false;return;end if;
  if not exists(select 1 from public.profiles p where p.id=p_grantee_profile_id and p.status='active')
  then raise exception using errcode='42501',message='ACTIVE_GRANTEE_PROFILE_REQUIRED'; end if;
  insert into public.rider_performance_profile_share_grants(
    owner_profile_id,grantee_profile_id,category_code,record_id,valid_from,valid_until,creation_correlation_id
  ) values(actor_id,p_grantee_profile_id,p_category_code,p_record_id,coalesce(p_valid_from,pg_catalog.statement_timestamp()),p_valid_until,p_correlation_id)
  returning * into created;
  perform private.c003d_bump_profiles(array[actor_id,p_grantee_profile_id]);
  perform private.c003d_write_audit('rider_performance.profile_share_granted','rider_profile_share_grant',created.id,
    'profile',actor_id,actor_id,p_correlation_id,'RIDER_SHARE_GRANTED',null,created.status,null,created.row_version,null,null,
    pg_catalog.jsonb_build_object('target_profile_id',p_grantee_profile_id::text,'category_code',p_category_code,
      'record_id',p_record_id::text,'operation_code','grant_profile_share'));
  return query select created.id,created.row_version,true;
end;
$$;

create or replace function public.transition_rider_performance_profile_share(
  p_grant_id uuid,p_expected_row_version bigint,p_action text,p_correlation_id uuid
)
returns table(row_version bigint,status text,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid; before_row public.rider_performance_profile_share_grants%rowtype; after_row public.rider_performance_profile_share_grants%rowtype; new_status text; event_name text; reason_name text;
begin
  actor_id:=private.c003d_actor_profile_id(); select * into before_row from public.rider_performance_profile_share_grants g where g.id=p_grant_id for update;
  if not found then raise exception using errcode='P0002',message='RIDER_PROFILE_SHARE_NOT_FOUND'; end if;
  if before_row.owner_profile_id<>actor_id then raise exception using errcode='42501',message='RIDER_SHARE_OWNER_REQUIRED'; end if;
  if before_row.status<>'active' then return query select before_row.row_version,before_row.status,false;return;end if;
  if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_SHARE_VERSION'; end if;
  if p_action='expire' then
    if before_row.valid_until is null or before_row.valid_until>pg_catalog.statement_timestamp() then raise exception using errcode='22023',message='SHARE_NOT_DUE_FOR_EXPIRY'; end if;
    new_status:='expired';event_name:='rider_performance.profile_share_expired';reason_name:='RIDER_SHARE_EXPIRED';
  elsif p_action in('revoke','end') then new_status:=case when p_action='revoke' then 'revoked' else 'ended' end;event_name:='rider_performance.profile_share_revoked';reason_name:='RIDER_SHARE_REVOKED';
  else raise exception using errcode='22023',message='SHARE_ACTION_INVALID'; end if;
  update public.rider_performance_profile_share_grants g set status=new_status,
    valid_until=case when g.valid_until is null or g.valid_until>pg_catalog.statement_timestamp() then greatest(pg_catalog.statement_timestamp(),g.valid_from+interval '1 microsecond') else g.valid_until end,
    terminal_reason_code=pg_catalog.upper(p_action),terminal_at=pg_catalog.clock_timestamp(),row_version=g.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where g.id=p_grant_id returning * into after_row;
  perform private.c003d_bump_profiles(array[before_row.owner_profile_id,before_row.grantee_profile_id]);
  perform private.c003d_write_audit(event_name,'rider_profile_share_grant',p_grant_id,'profile',actor_id,actor_id,p_correlation_id,
    reason_name,before_row.status,after_row.status,before_row.row_version,after_row.row_version,null,null,
    pg_catalog.jsonb_build_object('target_profile_id',before_row.grantee_profile_id::text,'category_code',before_row.category_code,
      'record_id',before_row.record_id::text,'action_code',p_action));
  return query select after_row.row_version,after_row.status,true;
end;
$$;

create or replace function public.grant_rider_performance_role_share(
  p_role_id uuid,p_category_code text,p_record_id uuid,p_valid_from timestamptz,p_valid_until timestamptz,p_correlation_id uuid
)
returns table(grant_id uuid,row_version bigint,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid; organization_id uuid; created public.rider_performance_org_role_share_grants%rowtype;prior public.rider_performance_org_role_share_grants%rowtype;profile_ids uuid[];
begin
  actor_id:=private.c003d_actor_profile_id();
  select grant_row.* into prior from public.rider_performance_org_role_share_grants grant_row
    where grant_row.owner_profile_id=actor_id and grant_row.creation_correlation_id=p_correlation_id;
  if found then return query select prior.id,prior.row_version,false;return;end if;
  select role.organization_id into organization_id from public.organization_roles role where role.id=p_role_id and role.status='active';
  if organization_id is null then raise exception using errcode='22023',message='ACTIVE_ORGANIZATION_ROLE_REQUIRED'; end if;
  insert into public.rider_performance_org_role_share_grants(
    owner_profile_id,organization_id,role_id,category_code,record_id,valid_from,valid_until,creation_correlation_id
  ) values(actor_id,organization_id,p_role_id,p_category_code,p_record_id,coalesce(p_valid_from,pg_catalog.statement_timestamp()),p_valid_until,p_correlation_id)
  returning * into created;
  profile_ids:=array[actor_id]||private.c003d_role_profile_ids(p_role_id);perform private.c003d_bump_profiles(profile_ids);
  perform private.c003d_write_audit('rider_performance.role_share_granted','rider_role_share_grant',created.id,
    'profile',actor_id,actor_id,p_correlation_id,'RIDER_SHARE_GRANTED',null,created.status,null,created.row_version,null,null,
    pg_catalog.jsonb_build_object('organization_id',organization_id::text,'target_role_id',p_role_id::text,
      'category_code',p_category_code,'record_id',p_record_id::text,'operation_code','grant_role_share'));
  return query select created.id,created.row_version,true;
end;
$$;

create or replace function public.transition_rider_performance_role_share(
  p_grant_id uuid,p_expected_row_version bigint,p_action text,p_correlation_id uuid
)
returns table(row_version bigint,status text,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid; before_row public.rider_performance_org_role_share_grants%rowtype; after_row public.rider_performance_org_role_share_grants%rowtype; new_status text; event_name text; reason_name text; profile_ids uuid[];
begin
  actor_id:=private.c003d_actor_profile_id();select * into before_row from public.rider_performance_org_role_share_grants g where g.id=p_grant_id for update;
  if not found then raise exception using errcode='P0002',message='RIDER_ROLE_SHARE_NOT_FOUND';end if;
  if before_row.owner_profile_id<>actor_id then raise exception using errcode='42501',message='RIDER_SHARE_OWNER_REQUIRED';end if;
  if before_row.status<>'active' then return query select before_row.row_version,before_row.status,false;return;end if;
  if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_SHARE_VERSION';end if;
  if p_action='expire' then
    if before_row.valid_until is null or before_row.valid_until>pg_catalog.statement_timestamp() then raise exception using errcode='22023',message='SHARE_NOT_DUE_FOR_EXPIRY';end if;
    new_status:='expired';event_name:='rider_performance.role_share_expired';reason_name:='RIDER_SHARE_EXPIRED';
  elsif p_action in('revoke','end') then new_status:=case when p_action='revoke' then 'revoked' else 'ended' end;event_name:='rider_performance.role_share_revoked';reason_name:='RIDER_SHARE_REVOKED';
  else raise exception using errcode='22023',message='SHARE_ACTION_INVALID';end if;
  profile_ids:=array[actor_id]||private.c003d_role_profile_ids(before_row.role_id);
  update public.rider_performance_org_role_share_grants g set status=new_status,
    valid_until=case when g.valid_until is null or g.valid_until>pg_catalog.statement_timestamp() then greatest(pg_catalog.statement_timestamp(),g.valid_from+interval '1 microsecond') else g.valid_until end,
    terminal_reason_code=pg_catalog.upper(p_action),terminal_at=pg_catalog.clock_timestamp(),row_version=g.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where g.id=p_grant_id returning * into after_row;
  perform private.c003d_bump_profiles(profile_ids);
  perform private.c003d_write_audit(event_name,'rider_role_share_grant',p_grant_id,'profile',actor_id,actor_id,p_correlation_id,
    reason_name,before_row.status,after_row.status,before_row.row_version,after_row.row_version,null,null,
    pg_catalog.jsonb_build_object('organization_id',before_row.organization_id::text,'target_role_id',before_row.role_id::text,
      'category_code',before_row.category_code,'record_id',before_row.record_id::text,'action_code',p_action));
  return query select after_row.row_version,after_row.status,true;
end;
$$;

-- Invitation authorization is re-evaluated both when the invitation is
-- created and when it is accepted. A role can never amplify the inviter.
create or replace function private.c003d_can_assign_organization_role(
  p_profile_id uuid,p_organization_id uuid,p_role_id uuid
)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.organization_roles role
    join public.organizations organization on organization.id=role.organization_id
    where role.id=p_role_id and role.organization_id=p_organization_id
      and role.status='active' and not role.is_reserved and organization.status='active'
  )
  and private.c003b_profile_has_permission(
    p_profile_id,p_organization_id,'organization.memberships.manage',pg_catalog.statement_timestamp()
  )
  and not exists(
    select 1 from public.organization_role_permissions target_permission
    join public.permission_definitions permission on permission.id=target_permission.permission_id
    where target_permission.organization_id=p_organization_id
      and target_permission.role_id=p_role_id
      and permission.scope_kind='organization' and permission.is_active
      and not private.c003b_profile_has_permission(
        p_profile_id,p_organization_id,permission.code,pg_catalog.statement_timestamp()
      )
  )
$$;

create or replace function public.create_organization_invitation(
  p_organization_id uuid,p_initial_role_id uuid,p_target_email text,
  p_expires_at timestamptz,p_correlation_id uuid
)
returns table(invitation_id uuid,invitation_token text,expires_at timestamptz,applied boolean)
language plpgsql security definer set search_path='' as $$
declare
  actor_id uuid;raw_token text;created public.organization_invitations%rowtype;
  existing public.organization_invitations%rowtype;
begin
  actor_id:=private.c003d_actor_profile_id();
  if p_correlation_id is null then raise exception using errcode='22023',message='CORRELATION_ID_REQUIRED';end if;
  if p_expires_at<=pg_catalog.statement_timestamp() or p_expires_at>pg_catalog.statement_timestamp()+interval '30 days'
  then raise exception using errcode='22023',message='INVITATION_EXPIRY_INVALID';end if;
  if not private.c003d_can_assign_organization_role(actor_id,p_organization_id,p_initial_role_id)
  then raise exception using errcode='42501',message='ORGANIZATION_INVITATION_DENIED';end if;
  select invitation.* into existing from public.organization_invitations invitation
    where invitation.inviter_profile_id=actor_id and invitation.creation_correlation_id=p_correlation_id;
  if found then
    return query select existing.id,null::text,existing.expires_at,false;return;
  end if;
  raw_token:=pg_catalog.encode(extensions.gen_random_bytes(32),'hex');
  insert into public.organization_invitations(
    organization_id,initial_role_id,inviter_profile_id,target_profile_id,
    target_email_hmac,token_digest,expires_at,creation_correlation_id
  ) values(
    p_organization_id,p_initial_role_id,actor_id,private.c003d_resolve_target_profile(p_target_email),
    private.c003d_email_hmac(p_target_email),private.c003d_token_digest(raw_token),p_expires_at,p_correlation_id
  ) returning * into created;
  perform private.c003d_write_audit(
    'invitation.organization_created','organization_invitation',created.id,'organization',p_organization_id,
    actor_id,p_correlation_id,'ORGANIZATION_INVITATION_CREATED',null,created.status,null,created.row_version,null,null,
    pg_catalog.jsonb_build_object('invitation_kind','organization','target_role_id',p_initial_role_id::text,'operation_code','create_invitation')
  );
  return query select created.id,raw_token,created.expires_at,true;
end;
$$;

create or replace function public.preview_organization_invitation(p_invitation_token text)
returns table(organization_id uuid,organization_name text,role_id uuid,role_name text,expires_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare actor_id uuid;email_hmac bytea;
begin
  actor_id:=private.c003d_actor_profile_id();email_hmac:=private.c003d_actor_verified_email_hmac(actor_id);
  return query
    select invitation.organization_id,organization.name,role.id,role.name,invitation.expires_at
    from public.organization_invitations invitation
    join public.organizations organization on organization.id=invitation.organization_id
    join public.organization_roles role on role.id=invitation.initial_role_id
    where invitation.token_digest=private.c003d_token_digest(p_invitation_token)
      and invitation.target_email_hmac=email_hmac and invitation.status='pending'
      and invitation.expires_at>pg_catalog.statement_timestamp();
end;
$$;

create or replace function public.respond_organization_invitation(
  p_invitation_token text,p_action text,p_correlation_id uuid
)
returns table(invitation_id uuid,membership_id uuid,row_version bigint,status text,applied boolean)
language plpgsql security definer set search_path='' as $$
declare
  actor_id uuid;email_hmac bytea;before_row public.organization_invitations%rowtype;
  after_row public.organization_invitations%rowtype;member public.organization_memberships%rowtype;
  assignment public.organization_membership_roles%rowtype;new_status text;event_name text;reason_name text;
begin
  actor_id:=private.c003d_actor_profile_id();email_hmac:=private.c003d_actor_verified_email_hmac(actor_id);
  if p_action not in('accept','decline') then raise exception using errcode='22023',message='INVITATION_ACTION_INVALID';end if;
  select invitation.* into before_row from public.organization_invitations invitation
    where invitation.token_digest=private.c003d_token_digest(p_invitation_token) for update;
  if not found or before_row.status<>'pending' or before_row.target_email_hmac<>email_hmac
  then raise exception using errcode='42501',message='INVITATION_NOT_AVAILABLE';end if;
  if before_row.expires_at<=pg_catalog.statement_timestamp() then
    update public.organization_invitations invitation set status='expired',token_digest=null,
      terminal_reason_code='EXPIRED',terminal_at=pg_catalog.clock_timestamp(),response_correlation_id=p_correlation_id,
      row_version=invitation.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where invitation.id=before_row.id returning * into after_row;
    perform private.c003d_write_audit(
      'invitation.organization_expired','organization_invitation',before_row.id,'organization',before_row.organization_id,
      actor_id,p_correlation_id,'ORGANIZATION_INVITATION_EXPIRED',before_row.status,after_row.status,
      before_row.row_version,after_row.row_version,null,null,
      pg_catalog.jsonb_build_object('invitation_kind','organization','target_role_id',before_row.initial_role_id::text,'action_code','expire')
    );
    return query select before_row.id,null::uuid,after_row.row_version,after_row.status,true;return;
  end if;
  if p_action='decline' then
    update public.organization_invitations invitation set status='declined',token_digest=null,
      terminal_reason_code='DECLINED',terminal_at=pg_catalog.clock_timestamp(),response_correlation_id=p_correlation_id,
      row_version=invitation.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where invitation.id=before_row.id returning * into after_row;
    perform private.c003d_write_audit(
      'invitation.organization_declined','organization_invitation',before_row.id,'organization',before_row.organization_id,
      actor_id,p_correlation_id,'ORGANIZATION_INVITATION_DECLINED',before_row.status,after_row.status,
      before_row.row_version,after_row.row_version,null,null,
      pg_catalog.jsonb_build_object('invitation_kind','organization','target_role_id',before_row.initial_role_id::text,'action_code','decline')
    );
    return query select before_row.id,null::uuid,after_row.row_version,after_row.status,true;return;
  end if;
  if not private.c003d_can_assign_organization_role(
    before_row.inviter_profile_id,before_row.organization_id,before_row.initial_role_id
  ) then raise exception using errcode='42501',message='INVITER_AUTHORITY_NO_LONGER_VALID';end if;
  select membership.* into member from public.organization_memberships membership
    where membership.organization_id=before_row.organization_id and membership.profile_id=actor_id
      and membership.status in('active','suspended') for update;
  if found then
    if member.status='suspended' then
      update public.organization_memberships membership set status='active',row_version=membership.row_version+1,
        updated_at=pg_catalog.clock_timestamp() where membership.id=member.id returning * into member;
    end if;
  else
    insert into public.organization_memberships(
      organization_id,profile_id,created_by_profile_id,creation_correlation_id
    ) values(before_row.organization_id,actor_id,before_row.inviter_profile_id,p_correlation_id)
    returning * into member;
  end if;
  select role_assignment.* into assignment from public.organization_membership_roles role_assignment
    where role_assignment.membership_id=member.id and role_assignment.role_id=before_row.initial_role_id
      and role_assignment.status='active' for update;
  if not found then
    insert into public.organization_membership_roles(
      organization_id,membership_id,role_id,granted_by_profile_id,creation_correlation_id
    ) values(before_row.organization_id,member.id,before_row.initial_role_id,before_row.inviter_profile_id,p_correlation_id)
    returning * into assignment;
  end if;
  update public.organization_invitations invitation set status='accepted',token_digest=null,
    target_profile_id=actor_id,accepted_by_profile_id=actor_id,terminal_reason_code='ACCEPTED',
    terminal_at=pg_catalog.clock_timestamp(),response_correlation_id=p_correlation_id,
    row_version=invitation.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where invitation.id=before_row.id returning * into after_row;
  perform private.c003b_bump_access(before_row.organization_id,array[actor_id],actor_id,p_correlation_id,'organization_invitation_accepted');
  perform private.c003d_write_audit(
    'invitation.organization_accepted','organization_invitation',before_row.id,'organization',before_row.organization_id,
    actor_id,p_correlation_id,'ORGANIZATION_INVITATION_ACCEPTED',before_row.status,after_row.status,
    before_row.row_version,after_row.row_version,null,null,
    pg_catalog.jsonb_build_object('invitation_kind','organization','target_role_id',before_row.initial_role_id::text,'action_code','accept')
  );
  return query select before_row.id,member.id,after_row.row_version,after_row.status,true;
end;
$$;

create or replace function public.revoke_organization_invitation(
  p_invitation_id uuid,p_expected_row_version bigint,p_correlation_id uuid
)
returns table(row_version bigint,status text,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;before_row public.organization_invitations%rowtype;after_row public.organization_invitations%rowtype;new_status text;event_name text;reason_name text;
begin
  actor_id:=private.c003d_actor_profile_id();
  select invitation.* into before_row from public.organization_invitations invitation where invitation.id=p_invitation_id for update;
  if not found then raise exception using errcode='P0002',message='INVITATION_NOT_FOUND';end if;
  if before_row.inviter_profile_id<>actor_id then raise exception using errcode='42501',message='INVITER_REQUIRED';end if;
  if before_row.status<>'pending' then return query select before_row.row_version,before_row.status,false;return;end if;
  if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_INVITATION_VERSION';end if;
  if before_row.expires_at<=pg_catalog.statement_timestamp() then
    new_status:='expired';event_name:='invitation.organization_expired';reason_name:='ORGANIZATION_INVITATION_EXPIRED';
  else new_status:='revoked';event_name:='invitation.organization_revoked';reason_name:='ORGANIZATION_INVITATION_REVOKED';end if;
  update public.organization_invitations invitation set status=new_status,token_digest=null,
    terminal_reason_code=pg_catalog.upper(new_status),terminal_at=pg_catalog.clock_timestamp(),response_correlation_id=p_correlation_id,
    row_version=invitation.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where invitation.id=p_invitation_id returning * into after_row;
  perform private.c003d_write_audit(event_name,'organization_invitation',before_row.id,'organization',before_row.organization_id,
    actor_id,p_correlation_id,reason_name,before_row.status,after_row.status,before_row.row_version,after_row.row_version,null,null,
    pg_catalog.jsonb_build_object('invitation_kind','organization','target_role_id',before_row.initial_role_id::text,'action_code',new_status));
  return query select after_row.row_version,after_row.status,true;
end;
$$;

create or replace function public.create_horse_access_invitation(
  p_horse_id uuid,p_target_email text,p_permission_codes text[],
  p_valid_from timestamptz,p_valid_until timestamptz,p_expires_at timestamptz,p_correlation_id uuid
)
returns table(invitation_id uuid,invitation_token text,expires_at timestamptz,applied boolean)
language plpgsql security definer set search_path='' as $$
declare
  actor_id uuid;permission_code text;raw_token text;created public.horse_access_invitations%rowtype;
  existing public.horse_access_invitations%rowtype;effective_from timestamptz;
begin
  actor_id:=private.c003d_actor_profile_id();effective_from:=coalesce(p_valid_from,pg_catalog.statement_timestamp());
  if p_correlation_id is null then raise exception using errcode='22023',message='CORRELATION_ID_REQUIRED';end if;
  if coalesce(pg_catalog.array_length(p_permission_codes,1),0) not between 1 and 6
  then raise exception using errcode='22023',message='HORSE_INVITATION_PERMISSIONS_INVALID';end if;
  if p_expires_at<=pg_catalog.statement_timestamp() or p_expires_at>pg_catalog.statement_timestamp()+interval '30 days'
    or (p_valid_until is not null and p_valid_until<=effective_from)
  then raise exception using errcode='22023',message='INVITATION_EXPIRY_INVALID';end if;
  foreach permission_code in array p_permission_codes loop
    if not private.c003d_profile_can_grant_horse_permission(actor_id,p_horse_id,permission_code)
    then raise exception using errcode='42501',message='HORSE_INVITATION_PERMISSION_DENIED';end if;
  end loop;
  if (select pg_catalog.count(distinct value) from pg_catalog.unnest(p_permission_codes) value)
    <>pg_catalog.array_length(p_permission_codes,1)
  then raise exception using errcode='22023',message='HORSE_INVITATION_PERMISSIONS_DUPLICATE';end if;
  select invitation.* into existing from public.horse_access_invitations invitation
    where invitation.inviter_profile_id=actor_id and invitation.creation_correlation_id=p_correlation_id;
  if found then return query select existing.id,null::text,existing.expires_at,false;return;end if;
  raw_token:=pg_catalog.encode(extensions.gen_random_bytes(32),'hex');
  insert into public.horse_access_invitations(
    horse_id,inviter_profile_id,target_profile_id,target_email_hmac,token_digest,expires_at,creation_correlation_id
  ) values(
    p_horse_id,actor_id,private.c003d_resolve_target_profile(p_target_email),private.c003d_email_hmac(p_target_email),
    private.c003d_token_digest(raw_token),p_expires_at,p_correlation_id
  ) returning * into created;
  insert into public.horse_access_invitation_permissions(invitation_id,permission_id,valid_from,valid_until)
    select created.id,permission.id,effective_from,p_valid_until
    from public.permission_definitions permission where permission.code=any(p_permission_codes);
  perform private.c003d_write_audit(
    'invitation.horse_created','horse_access_invitation',created.id,'horse',p_horse_id,actor_id,p_correlation_id,
    'HORSE_INVITATION_CREATED',null,created.status,null,created.row_version,null,null,
    pg_catalog.jsonb_build_object('invitation_kind','horse','operation_code','create_invitation')
  );
  return query select created.id,raw_token,created.expires_at,true;
end;
$$;

create or replace function public.preview_horse_access_invitation(p_invitation_token text)
returns table(horse_id uuid,horse_name text,permission_codes text[],expires_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare actor_id uuid;email_hmac bytea;
begin
  actor_id:=private.c003d_actor_profile_id();email_hmac:=private.c003d_actor_verified_email_hmac(actor_id);
  return query
    select invitation.horse_id,horse.display_name,
      pg_catalog.array_agg(permission.code order by permission.code),invitation.expires_at
    from public.horse_access_invitations invitation
    join public.canonical_horses horse on horse.id=invitation.horse_id
    join public.horse_access_invitation_permissions child on child.invitation_id=invitation.id
    join public.permission_definitions permission on permission.id=child.permission_id
    where invitation.token_digest=private.c003d_token_digest(p_invitation_token)
      and invitation.target_email_hmac=email_hmac and invitation.status='pending'
      and invitation.expires_at>pg_catalog.statement_timestamp()
    group by invitation.horse_id,horse.display_name,invitation.expires_at;
end;
$$;

create or replace function public.respond_horse_access_invitation(
  p_invitation_token text,p_action text,p_correlation_id uuid
)
returns table(invitation_id uuid,row_version bigint,status text,grants_created integer,applied boolean)
language plpgsql security definer set search_path='' as $$
declare
  actor_id uuid;email_hmac bytea;before_row public.horse_access_invitations%rowtype;
  after_row public.horse_access_invitations%rowtype;child record;created_grant public.horse_profile_permission_grants%rowtype;
  created_count integer:=0;
begin
  actor_id:=private.c003d_actor_profile_id();email_hmac:=private.c003d_actor_verified_email_hmac(actor_id);
  if p_action not in('accept','decline') then raise exception using errcode='22023',message='INVITATION_ACTION_INVALID';end if;
  select invitation.* into before_row from public.horse_access_invitations invitation
    where invitation.token_digest=private.c003d_token_digest(p_invitation_token) for update;
  if not found or before_row.status<>'pending' or before_row.target_email_hmac<>email_hmac
  then raise exception using errcode='42501',message='INVITATION_NOT_AVAILABLE';end if;
  if before_row.expires_at<=pg_catalog.statement_timestamp() then
    update public.horse_access_invitations invitation set status='expired',token_digest=null,
      terminal_reason_code='EXPIRED',terminal_at=pg_catalog.clock_timestamp(),response_correlation_id=p_correlation_id,
      row_version=invitation.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where invitation.id=before_row.id returning * into after_row;
    perform private.c003d_write_audit(
      'invitation.horse_expired','horse_access_invitation',before_row.id,'horse',before_row.horse_id,actor_id,p_correlation_id,
      'HORSE_INVITATION_EXPIRED',before_row.status,after_row.status,before_row.row_version,after_row.row_version,null,null,
      pg_catalog.jsonb_build_object('invitation_kind','horse','action_code','expire')
    );
    return query select before_row.id,after_row.row_version,after_row.status,0,true;return;
  end if;
  if p_action='decline' then
    update public.horse_access_invitations invitation set status='declined',token_digest=null,
      terminal_reason_code='DECLINED',terminal_at=pg_catalog.clock_timestamp(),response_correlation_id=p_correlation_id,
      row_version=invitation.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where invitation.id=before_row.id returning * into after_row;
    perform private.c003d_write_audit(
      'invitation.horse_declined','horse_access_invitation',before_row.id,'horse',before_row.horse_id,actor_id,p_correlation_id,
      'HORSE_INVITATION_DECLINED',before_row.status,after_row.status,before_row.row_version,after_row.row_version,null,null,
      pg_catalog.jsonb_build_object('invitation_kind','horse','action_code','decline')
    );
    return query select before_row.id,after_row.row_version,after_row.status,0,true;return;
  end if;
  for child in
    select invitation_permission.*,permission.code
    from public.horse_access_invitation_permissions invitation_permission
    join public.permission_definitions permission on permission.id=invitation_permission.permission_id
    where invitation_permission.invitation_id=before_row.id
  loop
    if child.valid_until is not null and child.valid_until<=pg_catalog.statement_timestamp()
    then raise exception using errcode='42501',message='INVITATION_GRANT_WINDOW_EXPIRED';end if;
    if not private.c003d_profile_can_grant_horse_permission(
      before_row.inviter_profile_id,before_row.horse_id,child.code
    ) then raise exception using errcode='42501',message='INVITER_AUTHORITY_NO_LONGER_VALID';end if;
  end loop;
  for child in
    select invitation_permission.*,permission.code
    from public.horse_access_invitation_permissions invitation_permission
    join public.permission_definitions permission on permission.id=invitation_permission.permission_id
    where invitation_permission.invitation_id=before_row.id
  loop
    if not exists(
      select 1 from public.horse_profile_permission_grants grant_row
      where grant_row.horse_id=before_row.horse_id and grant_row.grantee_profile_id=actor_id
        and grant_row.permission_id=child.permission_id and grant_row.status='active'
        and grant_row.valid_from<=pg_catalog.statement_timestamp()
        and (grant_row.valid_until is null or grant_row.valid_until>pg_catalog.statement_timestamp())
    ) then
      insert into public.horse_profile_permission_grants(
        horse_id,grantee_profile_id,permission_id,grantor_profile_id,valid_from,valid_until,reason_code,creation_correlation_id
      ) values(
        before_row.horse_id,actor_id,child.permission_id,before_row.inviter_profile_id,
        greatest(child.valid_from,pg_catalog.statement_timestamp()),child.valid_until,'INVITATION_ACCEPTED',p_correlation_id
      ) returning * into created_grant;
      created_count:=created_count+1;
      perform private.c003d_write_audit(
        'permission.horse_profile_granted','horse_profile_permission_grant',created_grant.id,'horse',before_row.horse_id,
        before_row.inviter_profile_id,p_correlation_id,'HORSE_PERMISSION_GRANTED',null,created_grant.status,null,created_grant.row_version,null,null,
        pg_catalog.jsonb_build_object('permission_code',child.code,'target_profile_id',actor_id::text,'operation_code','invitation_accept')
      );
    end if;
  end loop;
  update public.horse_access_invitations invitation set status='accepted',token_digest=null,target_profile_id=actor_id,
    accepted_by_profile_id=actor_id,terminal_reason_code='ACCEPTED',terminal_at=pg_catalog.clock_timestamp(),
    response_correlation_id=p_correlation_id,row_version=invitation.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where invitation.id=before_row.id returning * into after_row;
  perform private.c003c_bump_access(before_row.horse_id,array[actor_id],actor_id,p_correlation_id,'horse_invitation_accepted');
  perform private.c003d_write_audit(
    'invitation.horse_accepted','horse_access_invitation',before_row.id,'horse',before_row.horse_id,actor_id,p_correlation_id,
    'HORSE_INVITATION_ACCEPTED',before_row.status,after_row.status,before_row.row_version,after_row.row_version,null,null,
    pg_catalog.jsonb_build_object('invitation_kind','horse','action_code','accept')
  );
  return query select before_row.id,after_row.row_version,after_row.status,created_count,true;
end;
$$;

create or replace function public.revoke_horse_access_invitation(
  p_invitation_id uuid,p_expected_row_version bigint,p_correlation_id uuid
)
returns table(row_version bigint,status text,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;before_row public.horse_access_invitations%rowtype;after_row public.horse_access_invitations%rowtype;new_status text;event_name text;reason_name text;
begin
  actor_id:=private.c003d_actor_profile_id();
  select invitation.* into before_row from public.horse_access_invitations invitation where invitation.id=p_invitation_id for update;
  if not found then raise exception using errcode='P0002',message='INVITATION_NOT_FOUND';end if;
  if before_row.inviter_profile_id<>actor_id then raise exception using errcode='42501',message='INVITER_REQUIRED';end if;
  if before_row.status<>'pending' then return query select before_row.row_version,before_row.status,false;return;end if;
  if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_INVITATION_VERSION';end if;
  if before_row.expires_at<=pg_catalog.statement_timestamp() then
    new_status:='expired';event_name:='invitation.horse_expired';reason_name:='HORSE_INVITATION_EXPIRED';
  else new_status:='revoked';event_name:='invitation.horse_revoked';reason_name:='HORSE_INVITATION_REVOKED';end if;
  update public.horse_access_invitations invitation set status=new_status,token_digest=null,
    terminal_reason_code=pg_catalog.upper(new_status),terminal_at=pg_catalog.clock_timestamp(),response_correlation_id=p_correlation_id,
    row_version=invitation.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where invitation.id=p_invitation_id returning * into after_row;
  perform private.c003d_write_audit(event_name,'horse_access_invitation',before_row.id,'horse',before_row.horse_id,
    actor_id,p_correlation_id,reason_name,before_row.status,after_row.status,before_row.row_version,after_row.row_version,null,null,
    pg_catalog.jsonb_build_object('invitation_kind','horse','action_code',new_status));
  return query select after_row.row_version,after_row.status,true;
end;
$$;

-- RLS/ACL: invitation secrets are RPC-only; readable grants disclose only
-- current self/role scope or an explicit managing authority.
alter table public.horse_profile_permission_grants enable row level security;
alter table public.horse_organization_role_permission_grants enable row level security;
alter table public.organization_invitations enable row level security;
alter table public.horse_access_invitations enable row level security;
alter table public.horse_access_invitation_permissions enable row level security;
alter table public.rider_performance_profile_share_grants enable row level security;
alter table public.rider_performance_org_role_share_grants enable row level security;

create policy horse_profile_permission_grants_read
on public.horse_profile_permission_grants for select to authenticated using(
  (grantee_profile_id=private.current_profile_id()
    and exists(select 1 from public.profiles profile where profile.id=private.current_profile_id() and profile.status='active'))
  or public.has_canonical_horse_permission(horse_id,'horse.manage')
);
create policy horse_role_permission_grants_read
on public.horse_organization_role_permission_grants for select to authenticated using(
  exists(
    select 1 from public.organization_membership_roles assignment
    join public.organization_memberships membership
      on membership.id=assignment.membership_id and membership.organization_id=assignment.organization_id
    join public.organization_roles role
      on role.id=assignment.role_id and role.organization_id=assignment.organization_id
    join public.organizations organization on organization.id=assignment.organization_id
    join public.profiles profile on profile.id=membership.profile_id
    where assignment.role_id=horse_organization_role_permission_grants.role_id
      and membership.profile_id=private.current_profile_id() and profile.status='active'
      and organization.status='active' and role.status='active'
      and membership.status='active' and membership.valid_from<=pg_catalog.statement_timestamp()
      and (membership.valid_until is null or membership.valid_until>pg_catalog.statement_timestamp())
      and assignment.status='active' and assignment.valid_from<=pg_catalog.statement_timestamp()
      and (assignment.valid_until is null or assignment.valid_until>pg_catalog.statement_timestamp())
  )
  or public.has_canonical_horse_permission(horse_id,'horse.manage')
);
create policy rider_profile_share_grants_read
on public.rider_performance_profile_share_grants for select to authenticated using(
  private.current_profile_id() in(owner_profile_id,grantee_profile_id)
  and exists(select 1 from public.profiles profile where profile.id=private.current_profile_id() and profile.status='active')
);
create policy rider_role_share_grants_read
on public.rider_performance_org_role_share_grants for select to authenticated using(
  owner_profile_id=private.current_profile_id()
  or exists(
    select 1 from public.organization_membership_roles assignment
    join public.organization_memberships membership
      on membership.id=assignment.membership_id and membership.organization_id=assignment.organization_id
    join public.organization_roles role
      on role.id=assignment.role_id and role.organization_id=assignment.organization_id
    join public.organizations organization on organization.id=assignment.organization_id
    join public.profiles profile on profile.id=membership.profile_id
    where assignment.role_id=rider_performance_org_role_share_grants.role_id
      and membership.profile_id=private.current_profile_id() and profile.status='active'
      and organization.status='active' and role.status='active'
      and membership.status='active' and membership.valid_from<=pg_catalog.statement_timestamp()
      and (membership.valid_until is null or membership.valid_until>pg_catalog.statement_timestamp())
      and assignment.status='active' and assignment.valid_from<=pg_catalog.statement_timestamp()
      and (assignment.valid_until is null or assignment.valid_until>pg_catalog.statement_timestamp())
  )
);
create policy c003d_horse_audit_read on public.audit_events for select to authenticated using(
  resource_kind in('horse_profile_permission_grant','horse_role_permission_grant','horse_access_invitation')
  and public.has_canonical_horse_permission(scope_id,'horse.view')
);
create policy c003d_organization_audit_read on public.audit_events for select to authenticated using(
  resource_kind='organization_invitation' and public.has_organization_permission(scope_id,'organization.view')
);
create policy c003d_rider_audit_read on public.audit_events for select to authenticated using(
  resource_kind in('rider_profile_share_grant','rider_role_share_grant')
  and actor_profile_id=private.current_profile_id()
);

revoke all on table public.horse_profile_permission_grants,
  public.horse_organization_role_permission_grants,public.organization_invitations,
  public.horse_access_invitations,public.horse_access_invitation_permissions,
  public.rider_performance_profile_share_grants,
  public.rider_performance_org_role_share_grants
from public,anon,authenticated,service_role;
grant select on public.horse_profile_permission_grants,
  public.horse_organization_role_permission_grants,
  public.rider_performance_profile_share_grants,
  public.rider_performance_org_role_share_grants to authenticated;
revoke all on table private.c003d_secrets from public,anon,authenticated,service_role;

revoke execute on function public.can_grant_canonical_horse_permission(uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.can_grant_canonical_horse_permission(uuid,text) to authenticated;
revoke execute on function public.grant_horse_profile_permission(uuid,uuid,text,uuid,timestamptz,timestamptz,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.grant_horse_profile_permission(uuid,uuid,text,uuid,timestamptz,timestamptz,text,uuid) to authenticated;
revoke execute on function public.transition_horse_profile_permission_grant(uuid,bigint,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.transition_horse_profile_permission_grant(uuid,bigint,text,text,uuid) to authenticated;
revoke execute on function public.grant_horse_organization_role_permission(uuid,uuid,text,uuid,timestamptz,timestamptz,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.grant_horse_organization_role_permission(uuid,uuid,text,uuid,timestamptz,timestamptz,text,uuid) to authenticated;
revoke execute on function public.transition_horse_organization_role_permission_grant(uuid,bigint,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.transition_horse_organization_role_permission_grant(uuid,bigint,text,text,uuid) to authenticated;
revoke execute on function public.has_rider_performance_share(uuid,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.has_rider_performance_share(uuid,text,uuid) to authenticated;
revoke execute on function public.grant_rider_performance_profile_share(uuid,text,uuid,timestamptz,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.grant_rider_performance_profile_share(uuid,text,uuid,timestamptz,timestamptz,uuid) to authenticated;
revoke execute on function public.transition_rider_performance_profile_share(uuid,bigint,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.transition_rider_performance_profile_share(uuid,bigint,text,uuid) to authenticated;
revoke execute on function public.grant_rider_performance_role_share(uuid,text,uuid,timestamptz,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.grant_rider_performance_role_share(uuid,text,uuid,timestamptz,timestamptz,uuid) to authenticated;
revoke execute on function public.transition_rider_performance_role_share(uuid,bigint,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.transition_rider_performance_role_share(uuid,bigint,text,uuid) to authenticated;
revoke execute on function public.create_organization_invitation(uuid,uuid,text,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_organization_invitation(uuid,uuid,text,timestamptz,uuid) to authenticated;
revoke execute on function public.preview_organization_invitation(text) from public,anon,authenticated,service_role;
grant execute on function public.preview_organization_invitation(text) to authenticated;
revoke execute on function public.respond_organization_invitation(text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.respond_organization_invitation(text,text,uuid) to authenticated;
revoke execute on function public.revoke_organization_invitation(uuid,bigint,uuid) from public,anon,authenticated,service_role;
grant execute on function public.revoke_organization_invitation(uuid,bigint,uuid) to authenticated;
revoke execute on function public.create_horse_access_invitation(uuid,text,text[],timestamptz,timestamptz,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.create_horse_access_invitation(uuid,text,text[],timestamptz,timestamptz,timestamptz,uuid) to authenticated;
revoke execute on function public.preview_horse_access_invitation(text) from public,anon,authenticated,service_role;
grant execute on function public.preview_horse_access_invitation(text) to authenticated;
revoke execute on function public.respond_horse_access_invitation(text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.respond_horse_access_invitation(text,text,uuid) to authenticated;
revoke execute on function public.revoke_horse_access_invitation(uuid,bigint,uuid) from public,anon,authenticated,service_role;
grant execute on function public.revoke_horse_access_invitation(uuid,bigint,uuid) to authenticated;

-- Restore the exact C-003A authenticated RLS-helper allowlist after revoking
-- every other private routine, including the C-003D HMAC oracle.
revoke execute on all functions in schema private from public,anon,authenticated,service_role;
grant execute on function private.c003a_is_valid_iana_time_zone(text),
  private.can_join_realtime_topic(text),
  private.can_manage_horse_grants(uuid,text),
  private.can_select_feeding_execution_detail(uuid),
  private.can_select_feeding_plan(uuid),
  private.can_select_feeding_version(uuid),
  private.can_select_schedule_assignment_base(uuid),
  private.can_select_schedule_item_base(uuid),
  private.can_select_schedule_series_base(uuid),
  private.can_view_media_asset(uuid),
  private.can_view_media_audit(uuid),
  private.can_view_media_link(uuid),
  private.current_membership_id(uuid),
  private.current_profile_id(),
  private.current_role(uuid),
  private.has_horse_capability(uuid,text,text),
  private.is_active_member(uuid),
  private.is_stable_manager(uuid),
  private.schedule_item_access_level(uuid)
to authenticated;

comment on table public.horse_profile_permission_grants is 'C-003D explicit, versioned profile grants; relationships may only bound and revoke a grant.';
comment on table public.horse_organization_role_permission_grants is 'C-003D explicit horse grants to active organization roles; links may only bound and revoke a grant.';
comment on table public.organization_invitations is 'HMAC-addressed organization invitations. Raw e-mail and raw invitation token are never persisted.';
comment on table public.horse_access_invitations is 'HMAC-addressed horse access invitations. Acceptance creates only the listed explicit grants.';
comment on table public.rider_performance_profile_share_grants is 'C-003D Rider Performance sharing security boundary; performance records are outside this phase.';
comment on function public.respond_horse_access_invitation(text,text,uuid) is 'Verified Auth e-mail and one-time token acceptance with atomic authority recheck and replay resistance.';
