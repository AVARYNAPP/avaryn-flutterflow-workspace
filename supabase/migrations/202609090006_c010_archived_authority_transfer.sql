begin;

-- C010 terminal-archive authority succession. Keep existing transfer identities,
-- seven-day tokens, source CAS, immutable audit and active-org semantics.
-- No archive restoration, role/membership creation, identity rewriting, history
-- cleanup, or deletion-preflight relaxation is introduced.

create or replace function public.list_c010_my_archived_organizations()
returns table(organization_id uuid,name text,archived_at timestamptz,row_version bigint,
  access_version bigint,pending_transfer jsonb)
language plpgsql stable security definer set search_path='' as $$
declare actor_id uuid;
begin
  actor_id:=private.c003b_actor_profile_id();
  return query
  select organization.id,organization.name,organization.archived_at,organization.row_version,
    organization.access_version,(
      select pg_catalog.jsonb_build_object(
        'id',transfer.id,'recipient_name',case when recipient.status='active'
          then recipient.display_name else 'Niet-actief account' end,
        'status',transfer.status,'expires_at',transfer.expires_at,'row_version',transfer.row_version)
      from public.organization_authority_transfers transfer
      join public.profiles recipient on recipient.id=transfer.recipient_profile_id
      where transfer.organization_id=organization.id and transfer.sender_profile_id=actor_id
        and transfer.status='pending'
      limit 1
    )
  from public.organizations organization
  where organization.status='archived' and organization.primary_admin_profile_id=actor_id
  order by pg_catalog.lower(organization.name),organization.id;
end;
$$;
revoke all on function public.list_c010_my_archived_organizations() from public,anon,authenticated,service_role;
grant execute on function public.list_c010_my_archived_organizations() to authenticated;
comment on function public.list_c010_my_archived_organizations() is
  'Only the active caller''s own archived primary organizations and minimal pending-transfer metadata. No operational workspace/team access is granted.';

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
  -- Archived organizations do not run the active-primary target trigger.
  -- Lock the two live identities before the archive so deletion cannot acquire
  -- a new primary dependency after its preflight, or invert its lock order.
  if exists(select 1 from public.organizations value where value.id=p_organization_id
    and value.status in('active','archived') and value.primary_admin_profile_id=actor_id) then
    perform 1 from public.profiles profile
      where profile.id in(actor_id,p_recipient_profile_id) order by profile.id for update;
    actor_id:=private.c003e_actor_profile_id();
  end if;
  select value.* into organization from public.organizations value where value.id=p_organization_id for update;
  if not found or organization.status not in('active','archived') then raise exception using errcode='P0002',message='ACTIVE_ORGANIZATION_NOT_FOUND';end if;
  if organization.primary_admin_profile_id<>actor_id then raise exception using errcode='42501',message='PRIMARY_ORGANIZATION_ADMIN_REQUIRED';end if;
  select value.* into prior from public.organization_authority_transfers value
    where value.sender_profile_id=actor_id and value.creation_correlation_id=p_correlation_id;
  if found then
    if organization.status='archived' and (prior.organization_id is distinct from p_organization_id
      or prior.recipient_profile_id is distinct from p_recipient_profile_id) then
      raise exception using errcode='22023',message='REQUEST_ID_REUSED';
    end if;
    return query select prior.id,null::text,prior.expires_at,prior.row_version,false;return;
  end if;
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

create or replace function public.initiate_organization_authority_transfer_by_email(
  p_organization_id uuid,p_recipient_email text,p_correlation_id uuid
)
returns table(transfer_id uuid,transfer_token text,expires_at timestamptz,row_version bigint,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;
begin
  actor_id:=private.c003e_actor_profile_id();
  -- Resolve a supplied recipient only after checking this exact primary scope.
  -- No public profile search or new recipient-discovery contract is introduced.
  if not exists(select 1 from public.organizations organization
    where organization.id=p_organization_id and organization.primary_admin_profile_id=actor_id
      and organization.status in('active','archived')) then
    raise exception using errcode='42501',message='PRIMARY_ORGANIZATION_ADMIN_REQUIRED';
  end if;
  return query select * from public.initiate_organization_authority_transfer(
    p_organization_id,private.c008_target_profile_by_email(p_recipient_email),p_correlation_id
  );
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
  if p_action is null or p_action not in('accept','decline') then raise exception using errcode='22023',message='TRANSFER_ACTION_INVALID';end if;
  select transfer.organization_id into resource_id from public.organization_authority_transfers transfer
    where transfer.token_digest=private.c003d_token_digest(p_transfer_token);
  if resource_id is null then raise exception using errcode='42501',message='TRANSFER_NOT_AVAILABLE';end if;
  -- Lock identities even if retirement commits while we wait for the org.
  if not exists(select 1 from public.organization_authority_transfers transfer
    where transfer.token_digest=private.c003d_token_digest(p_transfer_token)
      and transfer.recipient_profile_id=actor_id and transfer.status='pending') then
    raise exception using errcode='42501',message='TRANSFER_NOT_AVAILABLE';
  end if;
  if resource_id is not null then
    perform 1 from public.profiles profile where profile.id in (
      select transfer.sender_profile_id from public.organization_authority_transfers transfer
        where transfer.token_digest=private.c003d_token_digest(p_transfer_token)
      union select transfer.recipient_profile_id from public.organization_authority_transfers transfer
        where transfer.token_digest=private.c003d_token_digest(p_transfer_token)
    ) order by profile.id for update;
    actor_id:=private.c003e_actor_profile_id();
  end if;
  select value.* into organization_before from public.organizations value where value.id=resource_id for update;
  select transfer.* into before_row from public.organization_authority_transfers transfer
    where transfer.token_digest=private.c003d_token_digest(p_transfer_token) for update;
  if not found or before_row.status<>'pending' or before_row.recipient_profile_id<>actor_id
  then raise exception using errcode='42501',message='TRANSFER_NOT_AVAILABLE';end if;
  if organization_before.status='archived' and exists(
    select 1 from public.profiles profile
      where profile.id in(before_row.sender_profile_id,before_row.recipient_profile_id) and profile.status<>'active'
  ) then raise exception using errcode='42501',message='ACTIVE_TARGET_PROFILE_REQUIRED'; end if;
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
  then
    if organization_before.status='archived' then
      raise exception using errcode='PT409',message='STALE_ORGANIZATION_ACCESS_VERSION';
    end if;
    raise exception using errcode='40001',message='STALE_ORGANIZATION_ACCESS_VERSION';
  end if;
  -- Active organizations retain the existing membership/head-role transition.
  -- Archive succession changes no closed membership, role or operational state.
  if organization_before.status='active' then
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
  end if;
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

create or replace function public.respond_stable_authority_transfer(
  p_transfer_token text,p_action text,p_correlation_id uuid
)
returns table (
  transfer_id uuid,row_version bigint,status text,
  organization_access_version bigint,applied boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  responded record;
  target_organization_id uuid;
  target_membership_id uuid;
  target_head_role_id uuid;
begin
  actor_id:=private.c003b_actor_profile_id();
  select * into responded from public.respond_organization_authority_transfer(
    p_transfer_token,p_action,p_correlation_id
  );
  if responded.applied and responded.status='accepted' and exists(
    select 1 from public.organization_authority_transfers transfer
    join public.organizations organization on organization.id=transfer.organization_id
    where transfer.id=responded.transfer_id and organization.status='active'
  ) then
    select transfer.organization_id into target_organization_id
    from public.organization_authority_transfers transfer
    where transfer.id=responded.transfer_id;
    select membership.id into target_membership_id
    from public.organization_memberships membership
    where membership.organization_id=target_organization_id
      and membership.profile_id=actor_id
      and membership.status='active';
    select role.id into target_head_role_id
    from public.organization_roles role
    where role.organization_id=target_organization_id
      and role.code='head_admin' and role.status='active'
      and role.is_system and role.is_reserved;
    update public.organization_memberships membership
    set valid_from=case
      when membership.valid_from>pg_catalog.statement_timestamp()
        then pg_catalog.statement_timestamp()
      else membership.valid_from
    end
    where membership.id=target_membership_id
      and membership.organization_id=target_organization_id;
    update public.organization_membership_roles assignment
    set valid_from=case
      when assignment.valid_from>pg_catalog.statement_timestamp()
        then pg_catalog.statement_timestamp()
      else assignment.valid_from
    end
    where assignment.membership_id=target_membership_id
      and assignment.role_id=target_head_role_id
      and assignment.organization_id=target_organization_id
      and assignment.status='active';
  end if;
  return query select
    responded.transfer_id,responded.row_version,responded.status,
    responded.organization_access_version,responded.applied;
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
  if before_row.row_version<>p_expected_row_version then
    if organization.status='archived' then raise exception using errcode='PT409',message='STALE_TRANSFER_VERSION'; end if;
    raise exception using errcode='40001',message='STALE_TRANSFER_VERSION';
  end if;
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

comment on function public.respond_organization_authority_transfer(text,text,uuid) is
  'Existing accepted primary-admin transfer. Active organizations retain membership/head-role migration; archived organizations retain terminal closure and move only the required primary reference, versions, transfer status and immutable audit.';

commit;
