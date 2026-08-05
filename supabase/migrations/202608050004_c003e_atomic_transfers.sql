-- C-003E — Atomic transfers
-- Implements the two scalar-primary transfer state machines. Pending transfer
-- rows are requests only and never participate in permission evaluation.

create table public.horse_authority_transfers(
  id uuid primary key default extensions.gen_random_uuid(),
  horse_id uuid not null references public.canonical_horses(id) on delete restrict,
  sender_profile_id uuid not null references public.profiles(id) on delete restrict,
  recipient_profile_id uuid not null references public.profiles(id) on delete restrict,
  authority_version_at_create bigint not null,
  token_digest bytea,
  status text not null default 'pending',
  expires_at timestamptz not null,
  terminal_reason_code text,
  terminal_by_profile_id uuid references public.profiles(id) on delete restrict,
  terminal_at timestamptz,
  creation_correlation_id uuid not null,
  response_correlation_id uuid,
  row_version bigint not null default 1,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  constraint horse_authority_transfers_distinct_check check(sender_profile_id<>recipient_profile_id),
  constraint horse_authority_transfers_authority_version_check check(authority_version_at_create>=1),
  constraint horse_authority_transfers_status_check check(status in('pending','accepted','declined','revoked','expired')),
  constraint horse_authority_transfers_expiry_check check(expires_at=created_at+interval '7 days'),
  constraint horse_authority_transfers_token_length_check check(token_digest is null or pg_catalog.octet_length(token_digest)=32),
  constraint horse_authority_transfers_shape_check check(
    (status='pending' and token_digest is not null and terminal_reason_code is null and terminal_by_profile_id is null and terminal_at is null)
    or (status<>'pending' and token_digest is null and terminal_reason_code=pg_catalog.upper(status)
      and terminal_by_profile_id is not null and terminal_at is not null)
  ),
  constraint horse_authority_transfers_row_version_check check(row_version>=1),
  constraint horse_authority_transfers_creation_unique unique(sender_profile_id,creation_correlation_id)
);
create unique index horse_authority_transfers_pending_unique
  on public.horse_authority_transfers(horse_id) where status='pending';
create unique index horse_authority_transfers_token_unique
  on public.horse_authority_transfers(token_digest) where token_digest is not null;
create index horse_authority_transfers_recipient_status_idx
  on public.horse_authority_transfers(recipient_profile_id,status);

create table public.organization_authority_transfers(
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  sender_profile_id uuid not null references public.profiles(id) on delete restrict,
  recipient_profile_id uuid not null references public.profiles(id) on delete restrict,
  access_version_at_create bigint not null,
  token_digest bytea,
  status text not null default 'pending',
  expires_at timestamptz not null,
  terminal_reason_code text,
  terminal_by_profile_id uuid references public.profiles(id) on delete restrict,
  terminal_at timestamptz,
  creation_correlation_id uuid not null,
  response_correlation_id uuid,
  row_version bigint not null default 1,
  created_at timestamptz not null,
  updated_at timestamptz not null,
  constraint organization_authority_transfers_distinct_check check(sender_profile_id<>recipient_profile_id),
  constraint organization_authority_transfers_access_version_check check(access_version_at_create>=1),
  constraint organization_authority_transfers_status_check check(status in('pending','accepted','declined','revoked','expired')),
  constraint organization_authority_transfers_expiry_check check(expires_at=created_at+interval '7 days'),
  constraint organization_authority_transfers_token_length_check check(token_digest is null or pg_catalog.octet_length(token_digest)=32),
  constraint organization_authority_transfers_shape_check check(
    (status='pending' and token_digest is not null and terminal_reason_code is null and terminal_by_profile_id is null and terminal_at is null)
    or (status<>'pending' and token_digest is null and terminal_reason_code=pg_catalog.upper(status)
      and terminal_by_profile_id is not null and terminal_at is not null)
  ),
  constraint organization_authority_transfers_row_version_check check(row_version>=1),
  constraint organization_authority_transfers_creation_unique unique(sender_profile_id,creation_correlation_id)
);
create unique index organization_authority_transfers_pending_unique
  on public.organization_authority_transfers(organization_id) where status='pending';
create unique index organization_authority_transfers_token_unique
  on public.organization_authority_transfers(token_digest) where token_digest is not null;
create index organization_authority_transfers_recipient_status_idx
  on public.organization_authority_transfers(recipient_profile_id,status);

-- Extend the immutable, PII-free audit catalog for both transfer lifecycles.
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
  'rider_performance.role_share_revoked','rider_performance.role_share_expired',
  'horse.authority_transfer_initiated','horse.authority_transfer_accepted',
  'horse.authority_transfer_declined','horse.authority_transfer_revoked','horse.authority_transfer_expired',
  'organization.head_transfer_initiated','organization.head_transfer_accepted',
  'organization.head_transfer_declined','organization.head_transfer_revoked','organization.head_transfer_expired'
));

alter table public.audit_events drop constraint audit_events_profile_resource_check;
alter table public.audit_events add constraint audit_events_profile_resource_check check(
  (resource_kind='profile' and scope_kind='profile' and resource_id=scope_id)
  or (resource_kind in('rider_profile_share_grant','rider_role_share_grant') and scope_kind='profile')
  or (resource_kind in('organization','organization_membership','organization_role',
      'organization_role_permission','organization_membership_role','organization_invitation',
      'organization_authority_transfer') and scope_kind='organization')
  or (resource_kind in('horse','horse_delegation','horse_person_ownership','horse_organization_ownership',
      'horse_person_relationship','organization_horse_link','horse_residency',
      'horse_profile_permission_grant','horse_role_permission_grant','horse_access_invitation',
      'horse_authority_transfer') and scope_kind='horse')
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
  'RIDER_SHARE_REVOKED','RIDER_SHARE_EXPIRED','HORSE_TRANSFER_INITIATED','HORSE_TRANSFER_ACCEPTED',
  'HORSE_TRANSFER_DECLINED','HORSE_TRANSFER_REVOKED','HORSE_TRANSFER_EXPIRED',
  'ORGANIZATION_TRANSFER_INITIATED','ORGANIZATION_TRANSFER_ACCEPTED',
  'ORGANIZATION_TRANSFER_DECLINED','ORGANIZATION_TRANSFER_REVOKED','ORGANIZATION_TRANSFER_EXPIRED'
));

alter table public.audit_events drop constraint audit_events_metadata_shape_check;
alter table public.audit_events add constraint audit_events_metadata_shape_check check(
  private.c003a_audit_json_keys_allowed(metadata,array[
    'changed_fields','dependency_checks_complete','denial_code','operation_code','role_code',
    'permission_code','target_profile_id','permission_codes','organization_id','relationship_type',
    'link_type','initiating_context','relationship_id','link_id','invitation_kind',
    'target_role_id','category_code','record_id','action_code',
    'authority_version_before','authority_version_after'
  ])
);

create or replace function private.c003e_actor_profile_id()
returns uuid language plpgsql stable security definer set search_path='' as $$
begin return private.c003d_actor_profile_id();end;
$$;

create or replace function private.c003e_write_audit(
  p_event_type text,p_resource_kind text,p_resource_id uuid,p_scope_kind text,p_scope_id uuid,
  p_actor_profile_id uuid,p_correlation_id uuid,p_reason_code text,p_old_status text,p_new_status text,
  p_row_before bigint,p_row_after bigint,p_access_before bigint,p_access_after bigint,p_metadata jsonb
)
returns uuid language plpgsql security definer set search_path='' as $$
declare event_id uuid;
begin
  if p_actor_profile_id is null or p_correlation_id is null or p_scope_id is null
    or p_resource_kind not in('horse_authority_transfer','organization_authority_transfer')
    or p_scope_kind not in('horse','organization') or p_metadata is null
    or exists(select 1 from pg_catalog.jsonb_object_keys(p_metadata) key_name
      where key_name not in('operation_code','target_profile_id','action_code','authority_version_before','authority_version_after'))
  then raise exception using errcode='22023',message='C003E_AUDIT_INPUT_INVALID';end if;
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

create or replace function private.c003e_guard_transfer_history()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='DELETE' then raise exception using errcode='55000',message='C003E_HISTORY_DELETE_FORBIDDEN';end if;
  if old.status<>'pending' then raise exception using errcode='55000',message='C003E_TERMINAL_STATE_IMMUTABLE';end if;
  if new.id is distinct from old.id or new.created_at is distinct from old.created_at
    or new.creation_correlation_id is distinct from old.creation_correlation_id
    or new.sender_profile_id is distinct from old.sender_profile_id
    or new.recipient_profile_id is distinct from old.recipient_profile_id
    or new.expires_at is distinct from old.expires_at
  then raise exception using errcode='55000',message='C003E_TRANSFER_IDENTITY_IMMUTABLE';end if;
  if new.status not in('accepted','declined','revoked','expired')
    or new.row_version<>old.row_version+1
  then raise exception using errcode='55000',message='C003E_TRANSFER_TRANSITION_INVALID';end if;
  if tg_table_name='horse_authority_transfers' then
    if new.horse_id is distinct from old.horse_id
      or new.authority_version_at_create is distinct from old.authority_version_at_create
    then raise exception using errcode='55000',message='C003E_TRANSFER_IDENTITY_IMMUTABLE';end if;
  elsif tg_table_name='organization_authority_transfers' then
    if new.organization_id is distinct from old.organization_id
      or new.access_version_at_create is distinct from old.access_version_at_create
    then raise exception using errcode='55000',message='C003E_TRANSFER_IDENTITY_IMMUTABLE';end if;
  else
    raise exception using errcode='55000',message='C003E_TRANSFER_TABLE_INVALID';
  end if;
  return new;
end;
$$;
create trigger c003e_horse_transfers_terminal_history
before update or delete on public.horse_authority_transfers
for each row execute function private.c003e_guard_transfer_history();
create trigger c003e_organization_transfers_terminal_history
before update or delete on public.organization_authority_transfers
for each row execute function private.c003e_guard_transfer_history();

-- Replace the C-003C phase guard with the same invariants plus the single
-- narrowly-defined C-003E transfer transition.
create or replace function private.c003c_guard_horse_authority()
returns trigger language plpgsql set search_path='' as $$
declare authority_changed boolean;
begin
  authority_changed:=new.primary_authority_profile_id is distinct from old.primary_authority_profile_id;
  if new.id is distinct from old.id or new.created_by_profile_id is distinct from old.created_by_profile_id
    or new.creation_correlation_id is distinct from old.creation_correlation_id
    or new.created_at is distinct from old.created_at
  then raise exception using errcode='42501',message='HORSE_AUTHORITY_IDENTITY_IMMUTABLE';end if;
  if authority_changed then
    if new.authority_version<>old.authority_version+1 or new.access_version<>old.access_version+1
      or new.row_version<>old.row_version+1
      or row(new.display_name,new.birth_date,new.sex,new.breed,new.status,new.archived_at)
        is distinct from row(old.display_name,old.birth_date,old.sex,old.breed,old.status,old.archived_at)
      or not exists(
        select 1 from public.horse_authority_transfers transfer
        where transfer.horse_id=old.id and transfer.sender_profile_id=old.primary_authority_profile_id
          and transfer.recipient_profile_id=new.primary_authority_profile_id and transfer.status='pending'
          and transfer.authority_version_at_create=old.authority_version
      )
    then raise exception using errcode='42501',message='HORSE_AUTHORITY_TRANSFER_REQUIRED';end if;
  elsif new.authority_version is distinct from old.authority_version
    or new.access_version not in(old.access_version,old.access_version+1)
    or new.row_version<>old.row_version+1
  then raise exception using errcode='22023',message='HORSE_VERSION_TRANSITION_INVALID';end if;
  return new;
end;
$$;

create or replace function private.c003e_guard_organization_primary_transfer()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.primary_admin_profile_id is distinct from old.primary_admin_profile_id then
    if new.access_version<>old.access_version+1 or new.row_version<>old.row_version+1
      or row(new.organization_type_id,new.name,new.description,new.status,new.archived_at)
        is distinct from row(old.organization_type_id,old.name,old.description,old.status,old.archived_at)
      or not exists(
        select 1 from public.organization_authority_transfers transfer
        where transfer.organization_id=old.id and transfer.sender_profile_id=old.primary_admin_profile_id
          and transfer.recipient_profile_id=new.primary_admin_profile_id and transfer.status='pending'
          and transfer.access_version_at_create=old.access_version
      )
    then raise exception using errcode='42501',message='ORGANIZATION_PRIMARY_TRANSFER_REQUIRED';end if;
  end if;
  return new;
end;
$$;
create trigger c003e_organizations_primary_transfer_before_update
before update of primary_admin_profile_id on public.organizations
for each row execute function private.c003e_guard_organization_primary_transfer();

create or replace function public.initiate_horse_authority_transfer(
  p_horse_id uuid,p_recipient_profile_id uuid,p_correlation_id uuid
)
returns table(transfer_id uuid,transfer_token text,expires_at timestamptz,row_version bigint,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;horse public.canonical_horses%rowtype;prior public.horse_authority_transfers%rowtype;
  pending public.horse_authority_transfers%rowtype;created public.horse_authority_transfers%rowtype;raw_token text;created_time timestamptz;
begin
  actor_id:=private.c003e_actor_profile_id();
  if p_correlation_id is null then raise exception using errcode='22023',message='CORRELATION_ID_REQUIRED';end if;
  select value.* into horse from public.canonical_horses value where value.id=p_horse_id for update;
  if not found or horse.status<>'active' then raise exception using errcode='P0002',message='ACTIVE_HORSE_NOT_FOUND';end if;
  if horse.primary_authority_profile_id<>actor_id then raise exception using errcode='42501',message='PRIMARY_HORSE_AUTHORITY_REQUIRED';end if;
  select value.* into prior from public.horse_authority_transfers value
    where value.sender_profile_id=actor_id and value.creation_correlation_id=p_correlation_id;
  if found then return query select prior.id,null::text,prior.expires_at,prior.row_version,false;return;end if;
  if p_recipient_profile_id=actor_id or not exists(
    select 1 from public.profiles profile where profile.id=p_recipient_profile_id and profile.status='active'
  ) then raise exception using errcode='22023',message='ACTIVE_DISTINCT_RECIPIENT_REQUIRED';end if;
  select value.* into pending from public.horse_authority_transfers value
    where value.horse_id=p_horse_id and value.status='pending' for update;
  if found then
    if pending.expires_at>pg_catalog.statement_timestamp() then
      raise exception using errcode='55000',message='HORSE_TRANSFER_ALREADY_PENDING';
    end if;
    update public.horse_authority_transfers value set status='expired',token_digest=null,
      terminal_reason_code='EXPIRED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
      response_correlation_id=p_correlation_id,row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where value.id=pending.id returning * into pending;
    perform private.c003e_write_audit('horse.authority_transfer_expired','horse_authority_transfer',pending.id,
      'horse',p_horse_id,actor_id,p_correlation_id,'HORSE_TRANSFER_EXPIRED','pending','expired',
      pending.row_version-1,pending.row_version,horse.access_version,horse.access_version,
      pg_catalog.jsonb_build_object('target_profile_id',pending.recipient_profile_id::text,'action_code','expire'));
  end if;
  raw_token:=pg_catalog.encode(extensions.gen_random_bytes(32),'hex');created_time:=pg_catalog.clock_timestamp();
  insert into public.horse_authority_transfers(
    horse_id,sender_profile_id,recipient_profile_id,authority_version_at_create,token_digest,
    expires_at,creation_correlation_id,created_at,updated_at
  ) values(p_horse_id,actor_id,p_recipient_profile_id,horse.authority_version,
    private.c003d_token_digest(raw_token),created_time+interval '7 days',p_correlation_id,created_time,created_time)
  returning * into created;
  perform private.c003e_write_audit('horse.authority_transfer_initiated','horse_authority_transfer',created.id,
    'horse',p_horse_id,actor_id,p_correlation_id,'HORSE_TRANSFER_INITIATED',null,'pending',null,created.row_version,
    horse.access_version,horse.access_version,pg_catalog.jsonb_build_object(
      'target_profile_id',p_recipient_profile_id::text,'operation_code','initiate_transfer',
      'authority_version_before',horse.authority_version,'authority_version_after',horse.authority_version));
  return query select created.id,raw_token,created.expires_at,created.row_version,true;
end;
$$;

create or replace function public.preview_horse_authority_transfer(p_transfer_token text)
returns table(transfer_id uuid,horse_id uuid,horse_name text,sender_profile_id uuid,expires_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare actor_id uuid;
begin
  actor_id:=private.c003e_actor_profile_id();
  return query select transfer.id,transfer.horse_id,horse.display_name,transfer.sender_profile_id,transfer.expires_at
    from public.horse_authority_transfers transfer join public.canonical_horses horse on horse.id=transfer.horse_id
    where transfer.token_digest=private.c003d_token_digest(p_transfer_token)
      and transfer.recipient_profile_id=actor_id and transfer.status='pending'
      and transfer.expires_at>pg_catalog.statement_timestamp();
end;
$$;

create or replace function public.respond_horse_authority_transfer(
  p_transfer_token text,p_action text,p_correlation_id uuid
)
returns table(transfer_id uuid,row_version bigint,status text,authority_version bigint,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;resource_id uuid;before_row public.horse_authority_transfers%rowtype;
  after_row public.horse_authority_transfers%rowtype;horse_before public.canonical_horses%rowtype;horse_after public.canonical_horses%rowtype;
begin
  actor_id:=private.c003e_actor_profile_id();
  if p_action not in('accept','decline') then raise exception using errcode='22023',message='TRANSFER_ACTION_INVALID';end if;
  select transfer.horse_id into resource_id from public.horse_authority_transfers transfer
    where transfer.token_digest=private.c003d_token_digest(p_transfer_token);
  if resource_id is null then raise exception using errcode='42501',message='TRANSFER_NOT_AVAILABLE';end if;
  select value.* into horse_before from public.canonical_horses value where value.id=resource_id for update;
  select transfer.* into before_row from public.horse_authority_transfers transfer
    where transfer.token_digest=private.c003d_token_digest(p_transfer_token) for update;
  if not found or before_row.status<>'pending' or before_row.recipient_profile_id<>actor_id
  then raise exception using errcode='42501',message='TRANSFER_NOT_AVAILABLE';end if;
  if before_row.expires_at<=pg_catalog.statement_timestamp() then
    update public.horse_authority_transfers transfer set status='expired',token_digest=null,
      terminal_reason_code='EXPIRED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
      response_correlation_id=p_correlation_id,row_version=transfer.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where transfer.id=before_row.id returning * into after_row;
    perform private.c003e_write_audit('horse.authority_transfer_expired','horse_authority_transfer',before_row.id,
      'horse',before_row.horse_id,actor_id,p_correlation_id,'HORSE_TRANSFER_EXPIRED','pending','expired',
      before_row.row_version,after_row.row_version,horse_before.access_version,horse_before.access_version,
      pg_catalog.jsonb_build_object('target_profile_id',actor_id::text,'action_code','expire'));
    return query select before_row.id,after_row.row_version,after_row.status,horse_before.authority_version,true;return;
  end if;
  if p_action='decline' then
    update public.horse_authority_transfers transfer set status='declined',token_digest=null,
      terminal_reason_code='DECLINED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
      response_correlation_id=p_correlation_id,row_version=transfer.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where transfer.id=before_row.id returning * into after_row;
    perform private.c003e_write_audit('horse.authority_transfer_declined','horse_authority_transfer',before_row.id,
      'horse',before_row.horse_id,actor_id,p_correlation_id,'HORSE_TRANSFER_DECLINED','pending','declined',
      before_row.row_version,after_row.row_version,horse_before.access_version,horse_before.access_version,
      pg_catalog.jsonb_build_object('target_profile_id',actor_id::text,'action_code','decline'));
    return query select before_row.id,after_row.row_version,after_row.status,horse_before.authority_version,true;return;
  end if;
  if horse_before.primary_authority_profile_id<>before_row.sender_profile_id
    or horse_before.authority_version<>before_row.authority_version_at_create
    or not exists(select 1 from public.profiles profile where profile.id=actor_id and profile.status='active')
  then raise exception using errcode='40001',message='STALE_HORSE_AUTHORITY_VERSION';end if;
  update public.canonical_horses horse set primary_authority_profile_id=actor_id,
    authority_version=horse.authority_version+1,access_version=horse.access_version+1,
    row_version=horse.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where horse.id=before_row.horse_id returning * into horse_after;
  update public.profiles profile set access_version=profile.access_version+1
    where profile.id in(before_row.sender_profile_id,before_row.recipient_profile_id);
  update public.horse_authority_transfers transfer set status='accepted',token_digest=null,
    terminal_reason_code='ACCEPTED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
    response_correlation_id=p_correlation_id,row_version=transfer.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where transfer.id=before_row.id returning * into after_row;
  perform private.c003e_write_audit('horse.authority_transfer_accepted','horse_authority_transfer',before_row.id,
    'horse',before_row.horse_id,actor_id,p_correlation_id,'HORSE_TRANSFER_ACCEPTED','pending','accepted',
    before_row.row_version,after_row.row_version,horse_before.access_version,horse_after.access_version,
    pg_catalog.jsonb_build_object('target_profile_id',actor_id::text,'action_code','accept',
      'authority_version_before',horse_before.authority_version,'authority_version_after',horse_after.authority_version));
  return query select before_row.id,after_row.row_version,after_row.status,horse_after.authority_version,true;
end;
$$;

create or replace function public.revoke_horse_authority_transfer(
  p_transfer_id uuid,p_expected_row_version bigint,p_correlation_id uuid
)
returns table(row_version bigint,status text,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;resource_id uuid;before_row public.horse_authority_transfers%rowtype;
  after_row public.horse_authority_transfers%rowtype;horse public.canonical_horses%rowtype;new_status text;event_name text;reason_name text;
begin
  actor_id:=private.c003e_actor_profile_id();
  select transfer.horse_id into resource_id from public.horse_authority_transfers transfer where transfer.id=p_transfer_id;
  if resource_id is null then raise exception using errcode='P0002',message='TRANSFER_NOT_FOUND';end if;
  select value.* into horse from public.canonical_horses value where value.id=resource_id for update;
  select transfer.* into before_row from public.horse_authority_transfers transfer where transfer.id=p_transfer_id for update;
  if before_row.sender_profile_id<>actor_id then raise exception using errcode='42501',message='TRANSFER_SENDER_REQUIRED';end if;
  if before_row.status<>'pending' then return query select before_row.row_version,before_row.status,false;return;end if;
  if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_TRANSFER_VERSION';end if;
  if before_row.expires_at<=pg_catalog.statement_timestamp() then
    new_status:='expired';event_name:='horse.authority_transfer_expired';reason_name:='HORSE_TRANSFER_EXPIRED';
  else new_status:='revoked';event_name:='horse.authority_transfer_revoked';reason_name:='HORSE_TRANSFER_REVOKED';end if;
  update public.horse_authority_transfers transfer set status=new_status,token_digest=null,
    terminal_reason_code=pg_catalog.upper(new_status),terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
    response_correlation_id=p_correlation_id,row_version=transfer.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where transfer.id=p_transfer_id returning * into after_row;
  perform private.c003e_write_audit(event_name,'horse_authority_transfer',before_row.id,'horse',before_row.horse_id,
    actor_id,p_correlation_id,reason_name,'pending',new_status,before_row.row_version,after_row.row_version,
    horse.access_version,horse.access_version,pg_catalog.jsonb_build_object(
      'target_profile_id',before_row.recipient_profile_id::text,'action_code',new_status));
  return query select after_row.row_version,after_row.status,true;
end;
$$;

create or replace function public.initiate_organization_authority_transfer(
  p_organization_id uuid,p_recipient_profile_id uuid,p_correlation_id uuid
)
returns table(transfer_id uuid,transfer_token text,expires_at timestamptz,row_version bigint,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;organization public.organizations%rowtype;prior public.organization_authority_transfers%rowtype;
  pending public.organization_authority_transfers%rowtype;created public.organization_authority_transfers%rowtype;raw_token text;created_time timestamptz;
begin
  actor_id:=private.c003e_actor_profile_id();
  if p_correlation_id is null then raise exception using errcode='22023',message='CORRELATION_ID_REQUIRED';end if;
  select value.* into organization from public.organizations value where value.id=p_organization_id for update;
  if not found or organization.status<>'active' then raise exception using errcode='P0002',message='ACTIVE_ORGANIZATION_NOT_FOUND';end if;
  if organization.primary_admin_profile_id<>actor_id then raise exception using errcode='42501',message='PRIMARY_ORGANIZATION_ADMIN_REQUIRED';end if;
  select value.* into prior from public.organization_authority_transfers value
    where value.sender_profile_id=actor_id and value.creation_correlation_id=p_correlation_id;
  if found then return query select prior.id,null::text,prior.expires_at,prior.row_version,false;return;end if;
  if p_recipient_profile_id=actor_id or not exists(
    select 1 from public.profiles profile where profile.id=p_recipient_profile_id and profile.status='active'
  ) then raise exception using errcode='22023',message='ACTIVE_DISTINCT_RECIPIENT_REQUIRED';end if;
  select value.* into pending from public.organization_authority_transfers value
    where value.organization_id=p_organization_id and value.status='pending' for update;
  if found then
    if pending.expires_at>pg_catalog.statement_timestamp() then
      raise exception using errcode='55000',message='ORGANIZATION_TRANSFER_ALREADY_PENDING';
    end if;
    update public.organization_authority_transfers value set status='expired',token_digest=null,
      terminal_reason_code='EXPIRED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
      response_correlation_id=p_correlation_id,row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where value.id=pending.id returning * into pending;
    perform private.c003e_write_audit('organization.head_transfer_expired','organization_authority_transfer',pending.id,
      'organization',p_organization_id,actor_id,p_correlation_id,'ORGANIZATION_TRANSFER_EXPIRED','pending','expired',
      pending.row_version-1,pending.row_version,organization.access_version,organization.access_version,
      pg_catalog.jsonb_build_object('target_profile_id',pending.recipient_profile_id::text,'action_code','expire'));
  end if;
  raw_token:=pg_catalog.encode(extensions.gen_random_bytes(32),'hex');created_time:=pg_catalog.clock_timestamp();
  insert into public.organization_authority_transfers(
    organization_id,sender_profile_id,recipient_profile_id,access_version_at_create,token_digest,
    expires_at,creation_correlation_id,created_at,updated_at
  ) values(p_organization_id,actor_id,p_recipient_profile_id,organization.access_version,
    private.c003d_token_digest(raw_token),created_time+interval '7 days',p_correlation_id,created_time,created_time)
  returning * into created;
  perform private.c003e_write_audit('organization.head_transfer_initiated','organization_authority_transfer',created.id,
    'organization',p_organization_id,actor_id,p_correlation_id,'ORGANIZATION_TRANSFER_INITIATED',null,'pending',null,created.row_version,
    organization.access_version,organization.access_version,pg_catalog.jsonb_build_object(
      'target_profile_id',p_recipient_profile_id::text,'operation_code','initiate_transfer'));
  return query select created.id,raw_token,created.expires_at,created.row_version,true;
end;
$$;

create or replace function public.preview_organization_authority_transfer(p_transfer_token text)
returns table(transfer_id uuid,organization_id uuid,organization_name text,sender_profile_id uuid,expires_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare actor_id uuid;
begin
  actor_id:=private.c003e_actor_profile_id();
  return query select transfer.id,transfer.organization_id,organization.name,transfer.sender_profile_id,transfer.expires_at
    from public.organization_authority_transfers transfer join public.organizations organization on organization.id=transfer.organization_id
    where transfer.token_digest=private.c003d_token_digest(p_transfer_token)
      and transfer.recipient_profile_id=actor_id and transfer.status='pending'
      and transfer.expires_at>pg_catalog.statement_timestamp();
end;
$$;

create or replace function public.respond_organization_authority_transfer(
  p_transfer_token text,p_action text,p_correlation_id uuid
)
returns table(transfer_id uuid,row_version bigint,status text,organization_access_version bigint,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;resource_id uuid;before_row public.organization_authority_transfers%rowtype;
  after_row public.organization_authority_transfers%rowtype;organization_before public.organizations%rowtype;organization_after public.organizations%rowtype;
  head_role_id uuid;old_membership public.organization_memberships%rowtype;new_membership public.organization_memberships%rowtype;
  old_assignment public.organization_membership_roles%rowtype;new_assignment public.organization_membership_roles%rowtype;
begin
  actor_id:=private.c003e_actor_profile_id();
  if p_action not in('accept','decline') then raise exception using errcode='22023',message='TRANSFER_ACTION_INVALID';end if;
  select transfer.organization_id into resource_id from public.organization_authority_transfers transfer
    where transfer.token_digest=private.c003d_token_digest(p_transfer_token);
  if resource_id is null then raise exception using errcode='42501',message='TRANSFER_NOT_AVAILABLE';end if;
  select value.* into organization_before from public.organizations value where value.id=resource_id for update;
  select transfer.* into before_row from public.organization_authority_transfers transfer
    where transfer.token_digest=private.c003d_token_digest(p_transfer_token) for update;
  if not found or before_row.status<>'pending' or before_row.recipient_profile_id<>actor_id
  then raise exception using errcode='42501',message='TRANSFER_NOT_AVAILABLE';end if;
  if before_row.expires_at<=pg_catalog.statement_timestamp() then
    update public.organization_authority_transfers transfer set status='expired',token_digest=null,
      terminal_reason_code='EXPIRED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
      response_correlation_id=p_correlation_id,row_version=transfer.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where transfer.id=before_row.id returning * into after_row;
    perform private.c003e_write_audit('organization.head_transfer_expired','organization_authority_transfer',before_row.id,
      'organization',before_row.organization_id,actor_id,p_correlation_id,'ORGANIZATION_TRANSFER_EXPIRED','pending','expired',
      before_row.row_version,after_row.row_version,organization_before.access_version,organization_before.access_version,
      pg_catalog.jsonb_build_object('target_profile_id',actor_id::text,'action_code','expire'));
    return query select before_row.id,after_row.row_version,after_row.status,organization_before.access_version,true;return;
  end if;
  if p_action='decline' then
    update public.organization_authority_transfers transfer set status='declined',token_digest=null,
      terminal_reason_code='DECLINED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
      response_correlation_id=p_correlation_id,row_version=transfer.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where transfer.id=before_row.id returning * into after_row;
    perform private.c003e_write_audit('organization.head_transfer_declined','organization_authority_transfer',before_row.id,
      'organization',before_row.organization_id,actor_id,p_correlation_id,'ORGANIZATION_TRANSFER_DECLINED','pending','declined',
      before_row.row_version,after_row.row_version,organization_before.access_version,organization_before.access_version,
      pg_catalog.jsonb_build_object('target_profile_id',actor_id::text,'action_code','decline'));
    return query select before_row.id,after_row.row_version,after_row.status,organization_before.access_version,true;return;
  end if;
  if organization_before.primary_admin_profile_id<>before_row.sender_profile_id
    or organization_before.access_version<>before_row.access_version_at_create
    or not exists(select 1 from public.profiles profile where profile.id=actor_id and profile.status='active')
  then raise exception using errcode='40001',message='STALE_ORGANIZATION_ACCESS_VERSION';end if;
  select role.id into head_role_id from public.organization_roles role
    where role.organization_id=before_row.organization_id and role.code='head_admin'
      and role.status='active' and role.is_system and role.is_reserved for update;
  if head_role_id is null then raise exception using errcode='23514',message='HEAD_ADMIN_ROLE_REQUIRED';end if;
  select membership.* into old_membership from public.organization_memberships membership
    where membership.organization_id=before_row.organization_id and membership.profile_id=before_row.sender_profile_id
      and membership.status='active' for update;
  if not found then raise exception using errcode='23514',message='CURRENT_PRIMARY_MEMBERSHIP_REQUIRED';end if;
  select assignment.* into old_assignment from public.organization_membership_roles assignment
    where assignment.membership_id=old_membership.id and assignment.role_id=head_role_id and assignment.status='active' for update;
  if not found then raise exception using errcode='23514',message='CURRENT_PRIMARY_ROLE_REQUIRED';end if;
  select membership.* into new_membership from public.organization_memberships membership
    where membership.organization_id=before_row.organization_id and membership.profile_id=actor_id
      and membership.status in('active','suspended') for update;
  if found then
    if new_membership.status='suspended' then
      update public.organization_memberships membership set status='active',row_version=membership.row_version+1,
        updated_at=pg_catalog.clock_timestamp() where membership.id=new_membership.id returning * into new_membership;
    end if;
  else
    insert into public.organization_memberships(
      organization_id,profile_id,created_by_profile_id,creation_correlation_id
    ) values(before_row.organization_id,actor_id,before_row.sender_profile_id,p_correlation_id)
    returning * into new_membership;
  end if;
  select assignment.* into new_assignment from public.organization_membership_roles assignment
    where assignment.membership_id=new_membership.id and assignment.role_id=head_role_id and assignment.status='active' for update;
  if not found then
    insert into public.organization_membership_roles(
      organization_id,membership_id,role_id,granted_by_profile_id,creation_correlation_id
    ) values(before_row.organization_id,new_membership.id,head_role_id,before_row.sender_profile_id,p_correlation_id)
    returning * into new_assignment;
  end if;
  update public.organization_membership_roles assignment set status='revoked',
    valid_until=greatest(pg_catalog.statement_timestamp(),assignment.valid_from+interval '1 microsecond'),
    ended_reason_code='role_revoked',revoked_by_profile_id=actor_id,row_version=assignment.row_version+1,
    updated_at=pg_catalog.clock_timestamp() where assignment.id=old_assignment.id;
  update public.organizations organization set primary_admin_profile_id=actor_id,
    access_version=organization.access_version+1,row_version=organization.row_version+1,
    updated_at=pg_catalog.clock_timestamp() where organization.id=before_row.organization_id
    returning * into organization_after;
  update public.profiles profile set access_version=profile.access_version+1
    where profile.id in(before_row.sender_profile_id,before_row.recipient_profile_id);
  update public.organization_authority_transfers transfer set status='accepted',token_digest=null,
    terminal_reason_code='ACCEPTED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
    response_correlation_id=p_correlation_id,row_version=transfer.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where transfer.id=before_row.id returning * into after_row;
  perform private.c003e_write_audit('organization.head_transfer_accepted','organization_authority_transfer',before_row.id,
    'organization',before_row.organization_id,actor_id,p_correlation_id,'ORGANIZATION_TRANSFER_ACCEPTED','pending','accepted',
    before_row.row_version,after_row.row_version,organization_before.access_version,organization_after.access_version,
    pg_catalog.jsonb_build_object('target_profile_id',actor_id::text,'action_code','accept'));
  return query select before_row.id,after_row.row_version,after_row.status,organization_after.access_version,true;
end;
$$;

create or replace function public.revoke_organization_authority_transfer(
  p_transfer_id uuid,p_expected_row_version bigint,p_correlation_id uuid
)
returns table(row_version bigint,status text,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;resource_id uuid;before_row public.organization_authority_transfers%rowtype;
  after_row public.organization_authority_transfers%rowtype;organization public.organizations%rowtype;new_status text;event_name text;reason_name text;
begin
  actor_id:=private.c003e_actor_profile_id();
  select transfer.organization_id into resource_id from public.organization_authority_transfers transfer where transfer.id=p_transfer_id;
  if resource_id is null then raise exception using errcode='P0002',message='TRANSFER_NOT_FOUND';end if;
  select value.* into organization from public.organizations value where value.id=resource_id for update;
  select transfer.* into before_row from public.organization_authority_transfers transfer where transfer.id=p_transfer_id for update;
  if before_row.sender_profile_id<>actor_id then raise exception using errcode='42501',message='TRANSFER_SENDER_REQUIRED';end if;
  if before_row.status<>'pending' then return query select before_row.row_version,before_row.status,false;return;end if;
  if before_row.row_version<>p_expected_row_version then raise exception using errcode='40001',message='STALE_TRANSFER_VERSION';end if;
  if before_row.expires_at<=pg_catalog.statement_timestamp() then
    new_status:='expired';event_name:='organization.head_transfer_expired';reason_name:='ORGANIZATION_TRANSFER_EXPIRED';
  else new_status:='revoked';event_name:='organization.head_transfer_revoked';reason_name:='ORGANIZATION_TRANSFER_REVOKED';end if;
  update public.organization_authority_transfers transfer set status=new_status,token_digest=null,
    terminal_reason_code=pg_catalog.upper(new_status),terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
    response_correlation_id=p_correlation_id,row_version=transfer.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where transfer.id=p_transfer_id returning * into after_row;
  perform private.c003e_write_audit(event_name,'organization_authority_transfer',before_row.id,'organization',before_row.organization_id,
    actor_id,p_correlation_id,reason_name,'pending',new_status,before_row.row_version,after_row.row_version,
    organization.access_version,organization.access_version,pg_catalog.jsonb_build_object(
      'target_profile_id',before_row.recipient_profile_id::text,'action_code',new_status));
  return query select after_row.row_version,after_row.status,true;
end;
$$;

-- Transfer tables are RPC-only. Even sender/recipient clients never receive
-- token digests or mutable history rows through PostgREST.
alter table public.horse_authority_transfers enable row level security;
alter table public.organization_authority_transfers enable row level security;
revoke all on table public.horse_authority_transfers,public.organization_authority_transfers
  from public,anon,authenticated,service_role;

revoke execute on function public.initiate_horse_authority_transfer(uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.initiate_horse_authority_transfer(uuid,uuid,uuid) to authenticated;
revoke execute on function public.preview_horse_authority_transfer(text) from public,anon,authenticated,service_role;
grant execute on function public.preview_horse_authority_transfer(text) to authenticated;
revoke execute on function public.respond_horse_authority_transfer(text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.respond_horse_authority_transfer(text,text,uuid) to authenticated;
revoke execute on function public.revoke_horse_authority_transfer(uuid,bigint,uuid) from public,anon,authenticated,service_role;
grant execute on function public.revoke_horse_authority_transfer(uuid,bigint,uuid) to authenticated;
revoke execute on function public.initiate_organization_authority_transfer(uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.initiate_organization_authority_transfer(uuid,uuid,uuid) to authenticated;
revoke execute on function public.preview_organization_authority_transfer(text) from public,anon,authenticated,service_role;
grant execute on function public.preview_organization_authority_transfer(text) to authenticated;
revoke execute on function public.respond_organization_authority_transfer(text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.respond_organization_authority_transfer(text,text,uuid) to authenticated;
revoke execute on function public.revoke_organization_authority_transfer(uuid,bigint,uuid) from public,anon,authenticated,service_role;
grant execute on function public.revoke_organization_authority_transfer(uuid,bigint,uuid) to authenticated;

revoke execute on all functions in schema private from public,anon,authenticated,service_role;
grant execute on function private.c003a_is_valid_iana_time_zone(text),
  private.can_join_realtime_topic(text),private.can_manage_horse_grants(uuid,text),
  private.can_select_feeding_execution_detail(uuid),private.can_select_feeding_plan(uuid),
  private.can_select_feeding_version(uuid),private.can_select_schedule_assignment_base(uuid),
  private.can_select_schedule_item_base(uuid),private.can_select_schedule_series_base(uuid),
  private.can_view_media_asset(uuid),private.can_view_media_audit(uuid),private.can_view_media_link(uuid),
  private.current_membership_id(uuid),private.current_profile_id(),private.current_role(uuid),
  private.has_horse_capability(uuid,text,text),private.is_active_member(uuid),
  private.is_stable_manager(uuid),private.schedule_item_access_level(uuid)
to authenticated;

comment on table public.horse_authority_transfers is 'C-003E immutable seven-day requests for atomic scalar primary Horse Authority transfer.';
comment on table public.organization_authority_transfers is 'C-003E immutable seven-day requests for atomic organization primary-admin, membership and head-role transfer.';
comment on function public.respond_horse_authority_transfer(text,text,uuid) is 'Locks horse then transfer; validates recipient, expiry and authority_version before one atomic scalar authority update.';
comment on function public.respond_organization_authority_transfer(text,text,uuid) is 'Locks organization then transfer; validates access_version and atomically establishes recipient membership/head role before scalar primary-admin update.';
