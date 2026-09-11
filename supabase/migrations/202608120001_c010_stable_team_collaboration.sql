begin;

-- C-010 is an additive collaboration layer over the approved Account Model
-- v2. Organizations, profiles, memberships, invitations, canonical horses,
-- horse authority, residencies, schedule_items and feeding plans remain the
-- only authoritative domain models.

alter table public.organizations
  add column location_name text,
  add column address_line text,
  add column locality text,
  add constraint organizations_location_name_check check (
    location_name is null
    or pg_catalog.length(pg_catalog.btrim(location_name)) between 1 and 240
  ),
  add constraint organizations_address_line_check check (
    address_line is null
    or pg_catalog.length(pg_catalog.btrim(address_line)) between 1 and 300
  ),
  add constraint organizations_locality_check check (
    locality is null
    or pg_catalog.length(pg_catalog.btrim(locality)) between 1 and 160
  );

insert into public.permission_definitions (
  code,scope_kind,action_class,description,is_grantable,is_active
) values
  ('horse.planning.manage','horse','assign',
    'Create and update canonical planning without profile-edit authority.',true,true),
  ('horse.feeding.manage','horse','edit',
    'Manage canonical feeding without profile-edit authority.',true,true)
on conflict (code) do update set
  description=excluded.description,is_grantable=true,is_active=true;

-- A narrow transaction-local elevation lets explicit horse.feeding.manage
-- call only the existing canonical Feeding writers. No client role can write
-- or read this marker table and no generic callback is exposed.
create table private.c010_capability_elevations (
  transaction_id bigint not null,
  actor_profile_id uuid not null references public.profiles(id) on delete restrict,
  horse_id uuid not null references public.canonical_horses(id) on delete restrict,
  capability text not null check(capability='feeding'),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(transaction_id,actor_profile_id,horse_id,capability)
);

alter table public.horse_delegated_administrators
  drop constraint horse_delegated_permissions_check,
  add constraint horse_delegated_permissions_check check (
    pg_catalog.cardinality(permission_codes) between 1 and 7
    and permission_codes <@ array[
      'horse.view','horse.edit','horse.manage','horse.assign','horse.share',
      'horse.planning.manage','horse.feeding.manage'
    ]::text[]
  );

create or replace function private.c003c_profile_has_horse_permission(
  p_profile_id uuid,p_horse_id uuid,p_permission_code text,
  p_at timestamptz default pg_catalog.statement_timestamp()
)
returns boolean language sql stable security definer set search_path='' as $$
  select p_permission_code in(
    'horse.view','horse.edit','horse.manage','horse.assign','horse.share',
    'horse.transfer','horse.planning.manage','horse.feeding.manage'
  ) and exists(
    select 1
    from public.profiles profile
    join public.canonical_horses horse on horse.id=p_horse_id
    where profile.id=p_profile_id and profile.status='active' and(
      horse.primary_authority_profile_id=profile.id
      or(p_permission_code='horse.edit' and exists(
        select 1 from private.c010_capability_elevations elevation
        where elevation.transaction_id=pg_catalog.txid_current()
          and elevation.actor_profile_id=profile.id
          and elevation.horse_id=horse.id
          and elevation.capability='feeding'
      ))
      or(p_permission_code<>'horse.transfer' and exists(
        select 1
        from public.horse_delegated_administrators delegation
        where delegation.horse_id=horse.id
          and delegation.profile_id=profile.id
          and delegation.status='active'
          and delegation.valid_from<=p_at
          and(delegation.valid_until is null or delegation.valid_until>p_at)
          and p_permission_code=any(delegation.permission_codes)
      ))
      or(p_permission_code<>'horse.transfer' and exists(
        select 1
        from public.horse_profile_permission_grants grant_row
        join public.permission_definitions permission
          on permission.id=grant_row.permission_id
        where grant_row.horse_id=horse.id
          and grant_row.grantee_profile_id=profile.id
          and grant_row.status='active' and grant_row.valid_from<=p_at
          and(grant_row.valid_until is null or grant_row.valid_until>p_at)
          and permission.scope_kind='horse' and permission.is_active
          and permission.code=p_permission_code
          and(grant_row.horse_person_relationship_id is null or exists(
            select 1
            from public.horse_person_relationships relationship
            where relationship.id=grant_row.horse_person_relationship_id
              and relationship.status='active'
              and relationship.valid_from<=p_at
              and(relationship.valid_until is null or relationship.valid_until>p_at)
          ))
      ))
      or(p_permission_code<>'horse.transfer' and exists(
        select 1
        from public.horse_organization_role_permission_grants grant_row
        join public.permission_definitions permission
          on permission.id=grant_row.permission_id
        join public.organization_roles role
          on role.id=grant_row.role_id
          and role.organization_id=grant_row.organization_id
        join public.organization_membership_roles assignment
          on assignment.role_id=role.id
          and assignment.organization_id=role.organization_id
        join public.organization_memberships membership
          on membership.id=assignment.membership_id
          and membership.organization_id=role.organization_id
        join public.organizations organization on organization.id=role.organization_id
        where grant_row.horse_id=horse.id and membership.profile_id=profile.id
          and grant_row.status='active' and grant_row.valid_from<=p_at
          and(grant_row.valid_until is null or grant_row.valid_until>p_at)
          and permission.scope_kind='horse' and permission.is_active
          and permission.code=p_permission_code
          and organization.status='active' and role.status='active'
          and membership.status='active' and membership.valid_from<=p_at
          and(membership.valid_until is null or membership.valid_until>p_at)
          and assignment.status='active' and assignment.valid_from<=p_at
          and(assignment.valid_until is null or assignment.valid_until>p_at)
          and(grant_row.organization_horse_link_id is null or exists(
            select 1 from public.organization_horse_links link
            where link.id=grant_row.organization_horse_link_id
              and link.status='active'
          ))
      ))
    )
  )
$$;

create table public.schedule_item_participants (
  id uuid primary key default extensions.gen_random_uuid(),
  schedule_item_id uuid not null references public.schedule_items(id) on delete restrict,
  horse_id uuid not null references public.canonical_horses(id) on delete restrict,
  profile_id uuid not null references public.profiles(id) on delete restrict,
  status text not null default 'active',
  valid_from timestamptz not null default pg_catalog.clock_timestamp(),
  valid_until timestamptz,
  created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  ended_by_profile_id uuid references public.profiles(id) on delete restrict,
  creation_request_id uuid not null,
  terminal_request_id uuid,
  row_version bigint not null default 1,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint schedule_item_participants_status_check
    check(status in('active','ended')),
  constraint schedule_item_participants_time_check
    check(valid_until is null or valid_until>valid_from),
  constraint schedule_item_participants_terminal_shape check(
    (status='active' and valid_until is null and ended_by_profile_id is null
      and terminal_request_id is null)
    or(status='ended' and valid_until is not null and ended_by_profile_id is not null
      and terminal_request_id is not null)
  ),
  constraint schedule_item_participants_version_check check(row_version>=1),
  constraint schedule_item_participants_creation_unique
    unique(created_by_profile_id,creation_request_id,profile_id)
);

create unique index schedule_item_participants_active_unique
  on public.schedule_item_participants(schedule_item_id,profile_id)
  where status='active';
create index schedule_item_participants_profile_active_idx
  on public.schedule_item_participants(profile_id,status,schedule_item_id);
create index schedule_item_participants_horse_active_idx
  on public.schedule_item_participants(horse_id,status,schedule_item_id);

create table private.c010_mutation_receipts (
  actor_user_id uuid not null references auth.users(id),
  request_id uuid not null,
  operation_name text not null check(operation_name in(
    'create_stable','update_stable','set_team_role','revoke_membership',
    'set_horse_residency','set_horse_collaborator','upsert_schedule_participants'
  )),
  payload_hash bytea not null check(pg_catalog.octet_length(payload_hash)=32),
  result jsonb not null check(pg_catalog.jsonb_typeof(result)='object'),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(actor_user_id,request_id)
);

create or replace function private.c010_receipt_result(
  p_actor_user_id uuid,p_request_id uuid,p_operation_name text,p_payload_hash bytea
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare receipt private.c010_mutation_receipts%rowtype;
begin
  select * into receipt from private.c010_mutation_receipts value
  where value.actor_user_id=p_actor_user_id and value.request_id=p_request_id;
  if not found then return null; end if;
  if receipt.operation_name<>p_operation_name
    or receipt.payload_hash<>p_payload_hash
  then raise exception using errcode='22023',message='C010_IDEMPOTENCY_CONFLICT'; end if;
  return receipt.result||pg_catalog.jsonb_build_object('idempotent',true);
end;
$$;

create or replace function private.c010_seed_role_templates(
  p_organization_id uuid,p_actor_profile_id uuid
)
returns void language plpgsql security definer set search_path='' as $$
declare template record; role_id uuid;
begin
  perform 1 from public.organizations organization
  join public.organization_types type on type.id=organization.organization_type_id
  where organization.id=p_organization_id and organization.status='active'
    and type.code='stable'
    and organization.primary_admin_profile_id=p_actor_profile_id
  for update;
  if not found then
    raise exception using errcode='42501',message='PRIMARY_ORGANIZATION_ADMIN_REQUIRED';
  end if;
  for template in
    select * from(values
      ('manager','Beheerder','Beheert stal en team zonder horse ownership.',array[
        'organization.view','organization.edit','organization.memberships.view',
        'organization.memberships.manage','organization.roles.view',
        'organization.roles.manage',
        'organization.invitations.manage','organization.horse_links.manage',
        'organization.residencies.manage','organization.planning.view',
        'organization.planning.execute','organization.feeding.view'
      ]::text[]),
      ('rider','Ruiter','Ruiterrol; horse access blijft expliciet.',array[
        'organization.view','organization.planning.view',
        'organization.planning.execute','organization.feeding.view'
      ]::text[]),
      ('trainer','Trainer','Trainerrol; geen impliciete profile-editrechten.',array[
        'organization.view','organization.planning.view'
      ]::text[]),
      ('groom','Groom / medewerker','Dagelijkse uitvoering met least privilege.',array[
        'organization.view','organization.planning.view',
        'organization.planning.execute','organization.feeding.view'
      ]::text[])
    ) value(code,name,description,permission_codes)
  loop
    select role.id into role_id from public.organization_roles role
    where role.organization_id=p_organization_id and role.code=template.code;
    if role_id is null then
      insert into public.organization_roles(
        organization_id,code,name,description,status,is_system,is_reserved,
        created_by_profile_id,creation_correlation_id
      ) values(
        p_organization_id,template.code,template.name,template.description,
        'active',true,false,p_actor_profile_id,extensions.gen_random_uuid()
      ) returning id into role_id;
    end if;
    insert into public.organization_role_permissions(
      organization_id,role_id,permission_id,granted_by_profile_id,correlation_id
    )
    select p_organization_id,role_id,permission.id,p_actor_profile_id,
      extensions.gen_random_uuid()
    from public.permission_definitions permission
    where permission.code=any(template.permission_codes)
    on conflict on constraint organization_role_permissions_pkey do nothing;
  end loop;
end;
$$;

do $$
declare organization record;
begin
  for organization in
    select value.id,value.primary_admin_profile_id
    from public.organizations value
    join public.organization_types type on type.id=value.organization_type_id
    where type.code='stable' and value.status='active'
  loop
    perform private.c010_seed_role_templates(
      organization.id,organization.primary_admin_profile_id
    );
  end loop;
end;
$$;

create or replace function public.create_c010_stable(
  p_name text,p_location_name text,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea;
  replay jsonb; created record; organization public.organizations%rowtype;
  result jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if actor_user is null or p_request_id is null
    or pg_catalog.length(pg_catalog.btrim(coalesce(p_name,''))) not between 1 and 160
    or(nullif(pg_catalog.btrim(p_location_name),'') is not null
      and pg_catalog.length(pg_catalog.btrim(p_location_name))>240)
  then raise exception using errcode='22023',message='C010_STABLE_INPUT_INVALID'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'name',pg_catalog.btrim(p_name),
    'location_name',nullif(pg_catalog.btrim(p_location_name),'')
  ));
  replay:=private.c010_receipt_result(
    actor_user,p_request_id,'create_stable',payload_hash
  );
  if replay is not null then return replay; end if;
  select * into created from public.create_stable_account(
    p_name,null,p_request_id
  );
  update public.organizations value set
    location_name=nullif(pg_catalog.btrim(p_location_name),''),
    row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where value.id=created.organization_id returning * into organization;
  perform private.c010_seed_role_templates(organization.id,actor_profile);
  perform private.c003b_write_audit(
    'organization.updated','organization',organization.id,organization.id,
    actor_profile,private.schedule_derived_request_id(p_request_id,'location'),
    'ORGANIZATION_UPDATED','active','active',1,organization.row_version,
    organization.access_version,organization.access_version,
    pg_catalog.jsonb_build_object('operation_code','c010_create_stable_location')
  );
  result:=pg_catalog.jsonb_build_object(
    'organization_id',organization.id,'membership_id',created.membership_id,
    'row_version',organization.row_version,'access_version',organization.access_version,
    'name',organization.name,'location_name',organization.location_name,
    'idempotent',false
  );
  insert into private.c010_mutation_receipts(
    actor_user_id,request_id,operation_name,payload_hash,result
  ) values(actor_user,p_request_id,'create_stable',payload_hash,result);
  return result;
end;
$$;

create or replace function public.update_c010_stable(
  p_organization_id uuid,p_expected_row_version bigint,p_name text,
  p_location_name text,p_address_line text,p_locality text,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea;
  replay jsonb; before_row public.organizations%rowtype;
  after_row public.organizations%rowtype; result jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if not private.c003b_profile_has_permission(
    actor_profile,p_organization_id,'organization.edit'
  ) then raise exception using errcode='42501',message='ORGANIZATION_PERMISSION_REQUIRED'; end if;
  if p_request_id is null or coalesce(p_expected_row_version,0)<1
    or pg_catalog.length(pg_catalog.btrim(coalesce(p_name,''))) not between 1 and 160
  then raise exception using errcode='22023',message='C010_STABLE_INPUT_INVALID'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'expected',p_expected_row_version,
    'name',pg_catalog.btrim(p_name),'location',nullif(pg_catalog.btrim(p_location_name),''),
    'address',nullif(pg_catalog.btrim(p_address_line),''),
    'locality',nullif(pg_catalog.btrim(p_locality),'')
  ));
  replay:=private.c010_receipt_result(
    actor_user,p_request_id,'update_stable',payload_hash
  );
  if replay is not null then return replay; end if;
  select * into before_row from public.organizations value
  where value.id=p_organization_id for update;
  if before_row.id is null then
    raise exception using errcode='P0002',message='STABLE_NOT_FOUND'; end if;
  if before_row.row_version<>p_expected_row_version then
    raise exception using errcode='40001',message='STALE_STABLE_VERSION'; end if;
  update public.organizations value set
    name=pg_catalog.btrim(p_name),
    location_name=nullif(pg_catalog.btrim(p_location_name),''),
    address_line=nullif(pg_catalog.btrim(p_address_line),''),
    locality=nullif(pg_catalog.btrim(p_locality),''),
    row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where value.id=p_organization_id returning * into after_row;
  perform private.c003b_write_audit(
    'organization.updated','organization',after_row.id,after_row.id,
    actor_profile,p_request_id,'ORGANIZATION_UPDATED',before_row.status,
    after_row.status,before_row.row_version,after_row.row_version,
    before_row.access_version,after_row.access_version,
    pg_catalog.jsonb_build_object('operation_code','c010_update_stable')
  );
  result:=pg_catalog.jsonb_build_object(
    'organization_id',after_row.id,'row_version',after_row.row_version,
    'name',after_row.name,'location_name',after_row.location_name,
    'address_line',after_row.address_line,'locality',after_row.locality,
    'idempotent',false
  );
  insert into private.c010_mutation_receipts(
    actor_user_id,request_id,operation_name,payload_hash,result
  ) values(actor_user,p_request_id,'update_stable',payload_hash,result);
  return result;
end;
$$;

create or replace function public.create_c010_stable_invitation(
  p_organization_id uuid,p_role_code text,p_target_email text,
  p_expires_at timestamptz,p_request_id uuid
)
returns table(
  invitation_id uuid,invitation_token text,expires_at timestamptz,
  status text,applied boolean
)
language plpgsql security definer set search_path='' as $$
declare actor_profile uuid; email_hmac bytea; pending public.organization_invitations%rowtype;
  created record;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if p_request_id is null then
    raise exception using errcode='22023',message='REQUEST_ID_REQUIRED'; end if;
  if not private.c003b_profile_has_permission(
    actor_profile,p_organization_id,'organization.invitations.manage'
  ) then raise exception using errcode='42501',message='ORGANIZATION_PERMISSION_REQUIRED'; end if;
  email_hmac:=private.c003d_email_hmac(p_target_email);
  select invitation.* into pending
  from public.organization_invitations invitation
  where invitation.organization_id=p_organization_id
    and invitation.target_email_hmac=email_hmac
    and invitation.status='pending'
    and invitation.expires_at>pg_catalog.statement_timestamp()
  order by invitation.created_at desc limit 1 for update;
  if found then
    return query select pending.id,null::text,pending.expires_at,
      pending.status,false;
    return;
  end if;
  select * into created from public.create_stable_invitation_by_role_code(
    p_organization_id,p_role_code,p_target_email,p_expires_at,p_request_id
  );
  return query select created.invitation_id,created.invitation_token,
    created.expires_at,'pending'::text,created.applied;
end;
$$;

create or replace function public.set_c010_team_role(
  p_organization_id uuid,p_membership_id uuid,p_expected_membership_row_version bigint,
  p_role_code text,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea;
  replay jsonb; membership public.organization_memberships%rowtype;
  organization public.organizations%rowtype; role_row public.organization_roles%rowtype;
  assignment record; granted record;
  changed_membership public.organization_memberships%rowtype; result jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if p_role_code not in('manager','rider','trainer','groom')
    or p_request_id is null or coalesce(p_expected_membership_row_version,0)<1
  then raise exception using errcode='22023',message='C010_TEAM_ROLE_INVALID'; end if;
  if not private.c003b_profile_has_permission(
    actor_profile,p_organization_id,'organization.memberships.manage'
  ) or not private.c003b_profile_has_permission(
    actor_profile,p_organization_id,'organization.roles.manage'
  ) then raise exception using errcode='42501',message='ORGANIZATION_PERMISSION_REQUIRED'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'membership_id',p_membership_id,
    'expected',p_expected_membership_row_version,'role_code',p_role_code
  ));
  replay:=private.c010_receipt_result(
    actor_user,p_request_id,'set_team_role',payload_hash
  );
  if replay is not null then return replay; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c010:team:'||p_organization_id::text,0)
  );
  select * into organization from public.organizations value
    where value.id=p_organization_id and value.status='active' for update;
  select * into membership from public.organization_memberships value
    where value.id=p_membership_id and value.organization_id=p_organization_id for update;
  if membership.id is null or organization.id is null then
    raise exception using errcode='42501',message='CROSS_STABLE_MEMBERSHIP_DENIED'; end if;
  if membership.status<>'active' then
    raise exception using errcode='22023',message='ACTIVE_MEMBERSHIP_REQUIRED'; end if;
  if membership.row_version<>p_expected_membership_row_version then
    raise exception using errcode='40001',message='STALE_MEMBERSHIP_VERSION'; end if;
  if membership.profile_id=organization.primary_admin_profile_id then
    raise exception using errcode='42501',message='PRIMARY_ADMIN_ROLE_IMMUTABLE'; end if;
  select * into role_row from public.organization_roles value
    where value.organization_id=p_organization_id and value.code=p_role_code
      and value.status='active' and not value.is_reserved;
  if role_row.id is null then
    raise exception using errcode='22023',message='C010_TEAM_ROLE_INVALID'; end if;
  for assignment in
    select value.id,value.row_version
    from public.organization_membership_roles value
    join public.organization_roles existing on existing.id=value.role_id
    where value.membership_id=membership.id and value.status='active'
      and not existing.is_reserved and existing.code<>p_role_code
    for update of value
  loop
    perform public.revoke_organization_membership_role(
      assignment.id,assignment.row_version,false,
      private.schedule_derived_request_id(p_request_id,'revoke:'||assignment.id::text)
    );
  end loop;
  if not exists(
    select 1 from public.organization_membership_roles value
    where value.membership_id=membership.id and value.role_id=role_row.id
      and value.status='active'
  ) then
    select * into granted from public.grant_organization_membership_role(
      membership.id,role_row.id,pg_catalog.statement_timestamp(),
      private.schedule_derived_request_id(p_request_id,'grant:'||role_row.id::text)
    );
  end if;
  update public.organization_memberships value set
    row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where value.id=membership.id returning * into changed_membership;
  result:=pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'membership_id',membership.id,
    'role_id',role_row.id,'role_code',role_row.code,
    'membership_row_version',changed_membership.row_version,'idempotent',false
  );
  insert into private.c010_mutation_receipts(
    actor_user_id,request_id,operation_name,payload_hash,result
  ) values(actor_user,p_request_id,'set_team_role',payload_hash,result);
  return result;
end;
$$;

create or replace function public.revoke_c010_membership(
  p_organization_id uuid,p_membership_id uuid,p_expected_row_version bigint,
  p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea;
  replay jsonb; membership public.organization_memberships%rowtype;
  organization public.organizations%rowtype; changed record; result jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if p_request_id is null or coalesce(p_expected_row_version,0)<1 then
    raise exception using errcode='22023',message='ROW_VERSION_REQUIRED'; end if;
  if not private.c003b_profile_has_permission(
    actor_profile,p_organization_id,'organization.memberships.manage'
  ) then raise exception using errcode='42501',message='ORGANIZATION_PERMISSION_REQUIRED'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'membership_id',p_membership_id,
    'expected',p_expected_row_version
  ));
  replay:=private.c010_receipt_result(
    actor_user,p_request_id,'revoke_membership',payload_hash
  );
  if replay is not null then return replay; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c010:team:'||p_organization_id::text,0)
  );
  select * into organization from public.organizations value
    where value.id=p_organization_id for update;
  select * into membership from public.organization_memberships value
    where value.id=p_membership_id and value.organization_id=p_organization_id for update;
  if membership.id is null or organization.id is null then
    raise exception using errcode='42501',message='CROSS_STABLE_MEMBERSHIP_DENIED'; end if;
  if membership.profile_id=organization.primary_admin_profile_id then
    raise exception using errcode='42501',message='PRIMARY_ADMIN_MEMBERSHIP_REQUIRED'; end if;
  select * into changed from public.set_organization_membership_status(
    membership.id,p_expected_row_version,'ended','membership_ended',p_request_id
  );
  result:=pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'membership_id',membership.id,
    'row_version',changed.row_version,'status',changed.status,'idempotent',false
  );
  insert into private.c010_mutation_receipts(
    actor_user_id,request_id,operation_name,payload_hash,result
  ) values(actor_user,p_request_id,'revoke_membership',payload_hash,result);
  return result;
end;
$$;

create or replace function public.set_c010_horse_residency(
  p_horse_id uuid,p_stable_organization_id uuid,p_expected_residency_row_version bigint,
  p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea;
  replay jsonb; current_row public.horse_residencies%rowtype;
  changed record; result jsonb;
begin
  actor_profile:=private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.manage');
  if p_request_id is null then
    raise exception using errcode='22023',message='REQUEST_ID_REQUIRED'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,'stable_organization_id',p_stable_organization_id,
    'expected',p_expected_residency_row_version
  ));
  replay:=private.c010_receipt_result(
    actor_user,p_request_id,'set_horse_residency',payload_hash
  );
  if replay is not null then return replay; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c010:residency:'||p_horse_id::text,0)
  );
  perform 1 from public.canonical_horses value where value.id=p_horse_id for update;
  select * into current_row from public.horse_residencies value
  where value.horse_id=p_horse_id and value.status='active' for update;
  if current_row.id is not null and coalesce(p_expected_residency_row_version,0)<>current_row.row_version then
    raise exception using errcode='40001',message='STALE_RESIDENCY_VERSION'; end if;
  if current_row.id is null and p_expected_residency_row_version is not null then
    raise exception using errcode='40001',message='STALE_RESIDENCY_VERSION'; end if;
  if p_stable_organization_id is null then
    if current_row.id is not null then
      select * into changed from public.end_horse_residency(
        current_row.id,current_row.row_version,p_request_id
      );
    end if;
    result:=pg_catalog.jsonb_build_object(
      'horse_id',p_horse_id,'residency_id',null,'organization_id',null,
      'status','unlinked','idempotent',false
    );
  else
    select * into changed from public.switch_horse_residency(
      p_horse_id,p_stable_organization_id,pg_catalog.statement_timestamp(),p_request_id
    );
    result:=pg_catalog.jsonb_build_object(
      'horse_id',p_horse_id,'residency_id',changed.residency_id,
      'organization_id',p_stable_organization_id,'row_version',changed.row_version,
      'status','active','idempotent',false
    );
  end if;
  insert into private.c010_mutation_receipts(
    actor_user_id,request_id,operation_name,payload_hash,result
  ) values(actor_user,p_request_id,'set_horse_residency',payload_hash,result);
  return result;
end;
$$;

create or replace function public.set_c010_horse_collaborator(
  p_horse_id uuid,p_profile_id uuid,p_relationship_type_code text,
  p_permission_codes text[],p_active boolean,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea;
  replay jsonb; normalized text[]; residency public.horse_residencies%rowtype;
  relationship public.horse_person_relationships%rowtype; grant_change record;
  permission_code text; result jsonb;
begin
  actor_profile:=private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.manage');
  if p_request_id is null or p_profile_id is null or p_active is null
    or p_relationship_type_code not in(
      'rider','trainer','groom','care_provider','professional_treatment'
    )
  then raise exception using errcode='22023',message='C010_COLLABORATOR_INPUT_INVALID'; end if;
  select pg_catalog.array_agg(distinct item order by item) into normalized
  from pg_catalog.unnest(coalesce(p_permission_codes,array[]::text[])) item;
  normalized:=coalesce(normalized,array[]::text[]);
  if p_active and(
    not('horse.view'=any(normalized))
    or not normalized<@array[
      'horse.view','horse.edit','horse.planning.manage','horse.feeding.manage'
    ]::text[]
  ) then raise exception using errcode='22023',message='C010_COLLABORATOR_PERMISSIONS_INVALID'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,'profile_id',p_profile_id,
    'relationship_type',p_relationship_type_code,'permissions',normalized,
    'active',p_active
  ));
  replay:=private.c010_receipt_result(
    actor_user,p_request_id,'set_horse_collaborator',payload_hash
  );
  if replay is not null then return replay; end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c010:collaborator:'||p_horse_id::text||':'||p_profile_id::text,0)
  );
  perform 1 from public.canonical_horses horse_row
    where horse_row.id=p_horse_id for update;
  if not exists(select 1 from public.profiles profile
    where profile.id=p_profile_id and profile.status='active')
  then raise exception using errcode='42501',message='ACTIVE_COLLABORATOR_REQUIRED'; end if;
  select * into residency from public.horse_residencies value
    where value.horse_id=p_horse_id and value.status='active';
  if p_active and p_profile_id<>actor_profile
    and not exists(
      select 1 from public.organization_memberships membership
      where membership.organization_id=residency.stable_organization_id
        and membership.profile_id=p_profile_id and membership.status='active'
        and membership.valid_from<=pg_catalog.statement_timestamp()
        and(membership.valid_until is null or membership.valid_until>pg_catalog.statement_timestamp())
    ) and not exists(
      select 1 from public.horse_person_relationships existing
      where existing.horse_id=p_horse_id and existing.profile_id=p_profile_id
        and existing.status='active'
    )
  then raise exception using errcode='42501',message='COLLABORATOR_CONTEXT_REQUIRED'; end if;
  select relationship_row.* into relationship
  from public.horse_person_relationships relationship_row
  where relationship_row.horse_id=p_horse_id
    and relationship_row.profile_id=p_profile_id
    and relationship_row.status='active'
  order by relationship_row.created_at desc limit 1 for update;
  if p_active and relationship.id is not null and not exists(
    select 1 from public.horse_relationship_types type
    where type.id=relationship.relationship_type_id
      and type.code=p_relationship_type_code
  ) then
    perform public.end_horse_person_relationship(
      relationship.id,relationship.row_version,
      private.schedule_derived_request_id(p_request_id,'replace-relationship')
    );
    relationship:=null;
  end if;
  if p_active and relationship.id is null then
    relationship.id:=public.start_horse_person_relationship(
      p_horse_id,p_profile_id,p_relationship_type_code,
      pg_catalog.statement_timestamp(),
      private.schedule_derived_request_id(p_request_id,'relationship')
    );
    select * into relationship from public.horse_person_relationships value
    where value.id=relationship.id;
  end if;
  if not p_active then
    for grant_change in
      select relationship_row.id,relationship_row.row_version
      from public.horse_person_relationships relationship_row
      where relationship_row.horse_id=p_horse_id
        and relationship_row.profile_id=p_profile_id
        and relationship_row.status='active'
      for update
    loop
      perform public.end_horse_person_relationship(
        grant_change.id,grant_change.row_version,
        private.schedule_derived_request_id(
          p_request_id,'end:'||grant_change.id::text
        )
      );
    end loop;
  else
    for grant_change in
      select grant_row.id,grant_row.row_version,permission.code
      from public.horse_profile_permission_grants grant_row
      join public.permission_definitions permission on permission.id=grant_row.permission_id
      where grant_row.horse_id=p_horse_id
        and grant_row.grantee_profile_id=p_profile_id
        and grant_row.status='active'
        and permission.code in(
          'horse.view','horse.edit','horse.planning.manage','horse.feeding.manage'
        ) and not(permission.code=any(normalized))
      for update of grant_row
    loop
      perform public.transition_horse_profile_permission_grant(
        grant_change.id,grant_change.row_version,'revoke','C010_ACCESS_CHANGED',
        private.schedule_derived_request_id(
          p_request_id,'revoke:'||grant_change.code
        )
      );
    end loop;
    foreach permission_code in array normalized loop
      if not exists(
        select 1 from public.horse_profile_permission_grants grant_row
        join public.permission_definitions permission on permission.id=grant_row.permission_id
        where grant_row.horse_id=p_horse_id
          and grant_row.grantee_profile_id=p_profile_id
          and grant_row.status='active' and permission.code=permission_code
      ) then
        perform public.grant_horse_profile_permission(
          p_horse_id,p_profile_id,permission_code,relationship.id,
          pg_catalog.statement_timestamp(),null,'RELATIONSHIP_BOUND',
          private.schedule_derived_request_id(p_request_id,'grant:'||permission_code)
        );
      end if;
    end loop;
  end if;
  result:=pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,'profile_id',p_profile_id,
    'relationship_type',p_relationship_type_code,'permission_codes',normalized,
    'active',p_active,'idempotent',false
  );
  insert into private.c010_mutation_receipts(
    actor_user_id,request_id,operation_name,payload_hash,result
  ) values(actor_user,p_request_id,'set_horse_collaborator',payload_hash,result);
  return result;
end;
$$;

create or replace function public.list_c010_horse_collaboration(
  p_horse_id uuid
)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid; can_manage boolean; result jsonb;
begin
  actor_profile:=private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.view');
  can_manage:=private.c003c_profile_has_horse_permission(
    actor_profile,p_horse_id,'horse.manage',pg_catalog.statement_timestamp()
  );
  select pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,
    'can_manage',can_manage,
    'current_residency',(
      select pg_catalog.jsonb_build_object(
        'id',residency.id,'organization_id',residency.stable_organization_id,
        'organization_name',organization.name,'location_name',organization.location_name,
        'row_version',residency.row_version,'valid_from',residency.valid_from
      )
      from public.horse_residencies residency
      join public.organizations organization on organization.id=residency.stable_organization_id
      where residency.horse_id=p_horse_id and residency.status='active'
      limit 1
    ),
    'stable_options',case when can_manage then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'organization_id',organization.id,'name',organization.name,
        'location_name',organization.location_name
      ) order by pg_catalog.lower(organization.name),organization.id)
      from public.organizations organization
      join public.organization_types type on type.id=organization.organization_type_id
      where type.code='stable' and organization.status='active'
        and private.c003b_profile_has_permission(
          actor_profile,organization.id,'organization.view',pg_catalog.statement_timestamp()
        )
    ),'[]'::jsonb) else '[]'::jsonb end,
    'collaborators',coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'relationship_id',relationship.id,'profile_id',relationship.profile_id,
        'profile_name',profile.display_name,'avatar_object_path',profile.avatar_object_path,
        'relationship_type',type.code,'relationship_label',type.label,
        'row_version',relationship.row_version,
        'permission_codes',coalesce((
          select pg_catalog.jsonb_agg(permission.code order by permission.code)
          from public.horse_profile_permission_grants grant_row
          join public.permission_definitions permission on permission.id=grant_row.permission_id
          where grant_row.horse_id=p_horse_id
            and grant_row.grantee_profile_id=relationship.profile_id
            and grant_row.status='active'
            and grant_row.valid_from<=pg_catalog.statement_timestamp()
            and(grant_row.valid_until is null or grant_row.valid_until>pg_catalog.statement_timestamp())
        ),'[]'::jsonb)
      ) order by pg_catalog.lower(profile.display_name),relationship.id)
      from public.horse_person_relationships relationship
      join public.horse_relationship_types type on type.id=relationship.relationship_type_id
      join public.profiles profile on profile.id=relationship.profile_id
      where relationship.horse_id=p_horse_id and relationship.status='active'
    ),'[]'::jsonb),
    'candidates',case when can_manage then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'profile_id',candidate.profile_id,'profile_name',candidate.profile_name,
        'avatar_object_path',candidate.avatar_object_path,
        'stable_role',candidate.stable_role
      ) order by pg_catalog.lower(candidate.profile_name),candidate.profile_id)
      from(
        select distinct membership.profile_id,profile.display_name profile_name,
          profile.avatar_object_path,
          coalesce(role.code,'teamlid') stable_role
        from public.horse_residencies residency
        join public.organization_memberships membership
          on membership.organization_id=residency.stable_organization_id
          and membership.status='active'
          and membership.valid_from<=pg_catalog.statement_timestamp()
          and(membership.valid_until is null or membership.valid_until>pg_catalog.statement_timestamp())
        join public.profiles profile on profile.id=membership.profile_id and profile.status='active'
        left join public.organization_membership_roles assignment
          on assignment.membership_id=membership.id and assignment.status='active'
          and assignment.valid_from<=pg_catalog.statement_timestamp()
          and(assignment.valid_until is null or assignment.valid_until>pg_catalog.statement_timestamp())
        left join public.organization_roles role on role.id=assignment.role_id and not role.is_reserved
        where residency.horse_id=p_horse_id and residency.status='active'
        union
        select relationship.profile_id,profile.display_name,
          profile.avatar_object_path,type.code
        from public.horse_person_relationships relationship
        join public.profiles profile on profile.id=relationship.profile_id and profile.status='active'
        join public.horse_relationship_types type on type.id=relationship.relationship_type_id
        where relationship.horse_id=p_horse_id and relationship.status='active'
      ) candidate
    ),'[]'::jsonb) else '[]'::jsonb end
  ) into result;
  return result;
end;
$$;

create or replace function public.list_c010_horses()
returns table(
  horse_id uuid,display_name text,official_name text,birth_date date,sex text,
  breed text,discipline text,level text,color text,notes text,chip_number text,
  passport_number text,passport_valid_until date,profile_media_asset_id uuid,
  lifecycle_status text,access_version bigint,authority_version bigint,
  row_version bigint,is_primary_authority boolean,can_edit boolean,
  can_manage boolean,can_manage_planning boolean,can_manage_feeding boolean,
  can_assign boolean,can_share boolean,can_transfer boolean,legacy_stable_id uuid
)
language sql stable security definer set search_path='' as $$
  select horse.id,horse.display_name,horse.official_name,horse.birth_date,
    horse.sex,horse.breed,horse.discipline,horse.level,horse.color,horse.notes,
    horse.chip_number,horse.passport_number,horse.passport_valid_until,
    horse.profile_media_asset_id,horse.status,horse.access_version,
    horse.authority_version,horse.row_version,
    horse.primary_authority_profile_id=private.current_profile_id(),
    private.c003c_profile_has_horse_permission(
      private.current_profile_id(),horse.id,'horse.edit',pg_catalog.statement_timestamp()
    ),private.c003c_profile_has_horse_permission(
      private.current_profile_id(),horse.id,'horse.manage',pg_catalog.statement_timestamp()
    ),private.c003c_profile_has_horse_permission(
      private.current_profile_id(),horse.id,'horse.planning.manage',pg_catalog.statement_timestamp()
    ),private.c003c_profile_has_horse_permission(
      private.current_profile_id(),horse.id,'horse.feeding.manage',pg_catalog.statement_timestamp()
    ),private.c003c_profile_has_horse_permission(
      private.current_profile_id(),horse.id,'horse.assign',pg_catalog.statement_timestamp()
    ),private.c003c_profile_has_horse_permission(
      private.current_profile_id(),horse.id,'horse.share',pg_catalog.statement_timestamp()
    ),private.c003c_profile_has_horse_permission(
      private.current_profile_id(),horse.id,'horse.transfer',pg_catalog.statement_timestamp()
    ),legacy_horse.stable_id
  from public.canonical_horses horse
  left join public.horses legacy_horse on legacy_horse.canonical_horse_id=horse.id
  where private.c003c_profile_has_horse_permission(
    private.current_profile_id(),horse.id,'horse.view',pg_catalog.statement_timestamp()
  )
  order by pg_catalog.lower(horse.display_name),horse.id
$$;

create or replace function private.c010_participant_allowed(
  p_profile_id uuid,p_horse_id uuid
)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.profiles profile
    where profile.id=p_profile_id and profile.status='active')
  and(
    exists(
      select 1
      from public.horse_residencies residency
      join public.organization_memberships membership
        on membership.organization_id=residency.stable_organization_id
      where residency.horse_id=p_horse_id and residency.status='active'
        and membership.profile_id=p_profile_id and membership.status='active'
        and membership.valid_from<=pg_catalog.statement_timestamp()
        and(membership.valid_until is null or membership.valid_until>pg_catalog.statement_timestamp())
    )
    or exists(
      select 1 from public.horse_person_relationships relationship
      where relationship.horse_id=p_horse_id and relationship.profile_id=p_profile_id
        and relationship.status='active'
        and relationship.valid_from<=pg_catalog.statement_timestamp()
        and(relationship.valid_until is null or relationship.valid_until>pg_catalog.statement_timestamp())
    )
    or private.c003c_profile_has_horse_permission(
      p_profile_id,p_horse_id,'horse.view',pg_catalog.statement_timestamp()
    )
  )
$$;

create or replace function private.c010_begin_feeding_elevation(
  p_horse_id uuid
)
returns uuid language plpgsql security definer set search_path='' as $$
declare actor_profile uuid;
begin
  actor_profile:=private.c003c_actor_profile_id();
  if not private.c003c_profile_has_horse_permission(
    actor_profile,p_horse_id,'horse.feeding.manage',pg_catalog.statement_timestamp()
  ) then raise exception using errcode='42501',message='HORSE_FEEDING_PERMISSION_REQUIRED'; end if;
  insert into private.c010_capability_elevations(
    transaction_id,actor_profile_id,horse_id,capability
  ) values(pg_catalog.txid_current(),actor_profile,p_horse_id,'feeding')
  on conflict do nothing;
  return actor_profile;
end;
$$;

alter table private.schedule_mutation_receipts
  drop constraint schedule_mutation_receipts_operation_name_check;
alter table private.schedule_mutation_receipts
  add constraint schedule_mutation_receipts_operation_name_check check(
    operation_name in(
      'create_schedule_series','update_schedule_series_scope',
      'materialize_schedule_occurrences','create_schedule_item',
      'update_schedule_item','cancel_schedule_item','assign_schedule_item',
      'return_schedule_assignment','record_schedule_execution',
      'correct_schedule_execution','reopen_schedule_item',
      'upsert_canonical_horse_schedule_item',
      'upsert_c010_horse_schedule_item'
    )
  );

create or replace function public.upsert_c010_horse_schedule_item(
  p_horse_id uuid,p_schedule_item_id uuid,p_expected_row_version bigint,
  p_item_kind text,p_title text,p_instruction text,p_priority text,
  p_scheduled_start_at timestamptz,p_scheduled_end_at timestamptz,
  p_source_timezone text,p_state text,p_state_reason text,
  p_participant_profile_ids uuid[],p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea;
  replay jsonb; normalized uuid[]; target public.schedule_items%rowtype;
  context_stable uuid; local_value timestamp; normalized_title text;
  normalized_instruction text; normalized_reason text; participant_profile uuid;
  participant public.schedule_item_participants%rowtype; result jsonb;
begin
  actor_profile:=private.c003c_actor_profile_id();
  if not(
    private.c003c_profile_has_horse_permission(
      actor_profile,p_horse_id,'horse.edit',pg_catalog.statement_timestamp()
    ) or private.c003c_profile_has_horse_permission(
      actor_profile,p_horse_id,'horse.planning.manage',pg_catalog.statement_timestamp()
    )
  ) then raise exception using errcode='42501',message='HORSE_PLANNING_PERMISSION_REQUIRED'; end if;
  normalized_title:=pg_catalog.btrim(coalesce(p_title,''));
  normalized_instruction:=pg_catalog.btrim(coalesce(p_instruction,''));
  normalized_reason:=nullif(pg_catalog.btrim(p_state_reason),'');
  select pg_catalog.array_agg(distinct value order by value) into normalized
  from pg_catalog.unnest(coalesce(p_participant_profile_ids,array[]::uuid[])) value;
  normalized:=coalesce(normalized,array[actor_profile]::uuid[]);
  if pg_catalog.cardinality(normalized)=0 then normalized:=array[actor_profile]; end if;
  if p_request_id is null
    or p_item_kind not in(
      'task','feeding','training','care','farrier','veterinary',
      'competition','transport','other'
    ) or p_priority not in('normal','high')
    or p_state not in('planned','in_progress','completed','skipped','cancelled')
    or pg_catalog.length(normalized_title) not between 1 and 160
    or pg_catalog.length(normalized_instruction) not between 0 and 2000
    or p_scheduled_start_at is null
    or(p_scheduled_end_at is not null and p_scheduled_end_at<p_scheduled_start_at)
    or p_source_timezone is null or not exists(
      select 1 from pg_catalog.pg_timezone_names value where value.name=p_source_timezone
    ) or(p_state='cancelled' and normalized_reason is null)
    or pg_catalog.cardinality(normalized)>50
  then raise exception using errcode='22023',message='INVALID_C010_SCHEDULE_ITEM'; end if;
  foreach participant_profile in array normalized loop
    if not private.c010_participant_allowed(participant_profile,p_horse_id) then
      raise exception using errcode='42501',message='SCHEDULE_PARTICIPANT_NOT_ALLOWED'; end if;
  end loop;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'horse_id',p_horse_id,'schedule_item_id',p_schedule_item_id,
    'expected',p_expected_row_version,'item_kind',p_item_kind,
    'title',normalized_title,'instruction',normalized_instruction,
    'priority',p_priority,'start',p_scheduled_start_at,'end',p_scheduled_end_at,
    'timezone',p_source_timezone,'state',p_state,'reason',normalized_reason,
    'participants',normalized
  ));
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c0091:schedule:'||p_horse_id::text,0)
  );
  replay:=private.schedule_receipt_result(
    actor_user,p_request_id,'upsert_c010_horse_schedule_item',payload_hash
  );
  if replay is not null then return replay; end if;
  context_stable:=private.c0091_legacy_stable_context(p_horse_id);
  local_value:=p_scheduled_start_at at time zone p_source_timezone;
  if p_schedule_item_id is null then
    if p_expected_row_version is not null then
      raise exception using errcode='22023',message='INVALID_ROW_VERSION'; end if;
    insert into public.schedule_items(
      stable_id,horse_id,item_kind,data_category,title,instruction,priority,
      scheduled_start_at,scheduled_end_at,source_timezone,source_local_date,
      source_local_time,state,state_reason,created_by_user_id,created_request_id,
      last_mutated_by_user_id,last_mutation_request_id,terminal_at
    ) values(
      context_stable,p_horse_id,p_item_kind,
      case when p_item_kind='feeding' then 'horse.nutrition' else 'horse.schedule' end,
      normalized_title,normalized_instruction,p_priority,p_scheduled_start_at,
      p_scheduled_end_at,p_source_timezone,local_value::date,local_value::time,
      p_state,normalized_reason,actor_user,p_request_id,actor_user,p_request_id,
      case when p_state in('completed','skipped','cancelled')
        then pg_catalog.clock_timestamp() end
    ) returning * into target;
  else
    if coalesce(p_expected_row_version,0)<1 then
      raise exception using errcode='22023',message='ROW_VERSION_REQUIRED'; end if;
    select * into target from public.schedule_items item
    where item.id=p_schedule_item_id and item.horse_id=p_horse_id for update;
    if target.id is null then
      raise exception using errcode='42501',message='HORSE_SCHEDULE_UNAVAILABLE'; end if;
    if target.row_version<>p_expected_row_version then
      raise exception using errcode='40001',message='STALE_SCHEDULE_VERSION'; end if;
    update public.schedule_items item set
      item_kind=p_item_kind,
      data_category=case when p_item_kind='feeding' then 'horse.nutrition' else 'horse.schedule' end,
      title=normalized_title,instruction=normalized_instruction,priority=p_priority,
      scheduled_start_at=p_scheduled_start_at,scheduled_end_at=p_scheduled_end_at,
      source_timezone=p_source_timezone,source_local_date=local_value::date,
      source_local_time=local_value::time,state=p_state,state_reason=normalized_reason,
      terminal_at=case when p_state in('completed','skipped','cancelled')
        then coalesce(item.terminal_at,pg_catalog.clock_timestamp()) else null end,
      last_mutated_by_user_id=actor_user,last_mutation_request_id=p_request_id
    where item.id=target.id returning * into target;
  end if;
  for participant in
    select * from public.schedule_item_participants value
    where value.schedule_item_id=target.id and value.status='active' for update
  loop
    if not(participant.profile_id=any(normalized)) then
      update public.schedule_item_participants value set
        status='ended',valid_until=greatest(
          pg_catalog.clock_timestamp(),value.valid_from+interval '1 microsecond'
        ),ended_by_profile_id=actor_profile,
        terminal_request_id=private.schedule_derived_request_id(
          p_request_id,'participant-end:'||participant.profile_id::text
        ),row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
      where value.id=participant.id;
    end if;
  end loop;
  foreach participant_profile in array normalized loop
    if not exists(
      select 1 from public.schedule_item_participants value
      where value.schedule_item_id=target.id
        and value.profile_id=participant_profile
        and value.status='active'
    ) then
      insert into public.schedule_item_participants(
        schedule_item_id,horse_id,profile_id,created_by_profile_id,creation_request_id
      ) values(
        target.id,p_horse_id,participant_profile,actor_profile,
        private.schedule_derived_request_id(
          p_request_id,'participant-add:'||participant_profile::text
        )
      );
    end if;
  end loop;
  result:=pg_catalog.jsonb_build_object(
    'schedule_item_id',target.id,'horse_id',target.horse_id,
    'row_version',target.row_version,'state',target.state,
    'participant_profile_ids',normalized,'idempotent',false
  );
  insert into private.schedule_mutation_receipts(
    actor_user_id,request_id,stable_id,horse_id,operation_name,target_type,
    target_id,payload_hash,result
  ) values(
    actor_user,p_request_id,target.stable_id,p_horse_id,
    'upsert_c010_horse_schedule_item','schedule_item',target.id,payload_hash,result
  );
  perform private.c0091_write_horse_domain_audit(
    p_horse_id,actor_profile,p_request_id,'c010_schedule_participants_updated',
    array['planning','participants']::text[]
  );
  return result;
end;
$$;

create or replace function public.create_c010_horse_feeding_plan(
  p_horse_id uuid,p_plan_type text,p_name text,p_effective_from date,
  p_effective_until date,p_change_reason text,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  perform private.c010_begin_feeding_elevation(p_horse_id);
  result:=public.create_canonical_horse_feeding_plan(
    p_horse_id,p_plan_type,p_name,p_effective_from,p_effective_until,
    p_change_reason,p_request_id
  );
  delete from private.c010_capability_elevations elevation
  where elevation.transaction_id=pg_catalog.txid_current()
    and elevation.actor_profile_id=private.current_profile_id()
    and elevation.horse_id=p_horse_id and elevation.capability='feeding';
  return result;
end;
$$;

create or replace function public.upsert_c010_horse_feeding_item(
  p_horse_id uuid,p_feeding_plan_version_id uuid,p_feeding_plan_item_id uuid,
  p_expected_row_version bigint,p_item_category text,p_product_brand text,
  p_product_name text,p_product_variant text,p_planned_quantity numeric,
  p_unit_code text,p_offering_method text,p_round_code text,p_local_time time,
  p_weekdays smallint[],p_interval_days integer,p_override_key text,
  p_instruction text,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  perform private.c010_begin_feeding_elevation(p_horse_id);
  result:=public.upsert_canonical_horse_feeding_item(
    p_horse_id,p_feeding_plan_version_id,p_feeding_plan_item_id,
    p_expected_row_version,p_item_category,p_product_brand,p_product_name,
    p_product_variant,p_planned_quantity,p_unit_code,p_offering_method,
    p_round_code,p_local_time,p_weekdays,p_interval_days,p_override_key,
    p_instruction,p_request_id
  );
  delete from private.c010_capability_elevations elevation
  where elevation.transaction_id=pg_catalog.txid_current()
    and elevation.actor_profile_id=private.current_profile_id()
    and elevation.horse_id=p_horse_id and elevation.capability='feeding';
  return result;
end;
$$;

create or replace function public.transition_c010_horse_feeding_version(
  p_horse_id uuid,p_feeding_plan_version_id uuid,p_expected_row_version bigint,
  p_action text,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  perform private.c010_begin_feeding_elevation(p_horse_id);
  result:=public.transition_canonical_horse_feeding_version(
    p_horse_id,p_feeding_plan_version_id,p_expected_row_version,p_action,p_request_id
  );
  delete from private.c010_capability_elevations elevation
  where elevation.transaction_id=pg_catalog.txid_current()
    and elevation.actor_profile_id=private.current_profile_id()
    and elevation.horse_id=p_horse_id and elevation.capability='feeding';
  return result;
end;
$$;

create or replace function public.retire_c010_horse_feeding_plan(
  p_horse_id uuid,p_feeding_plan_id uuid,p_expected_row_version bigint,
  p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  perform private.c010_begin_feeding_elevation(p_horse_id);
  result:=public.retire_canonical_horse_feeding_plan(
    p_horse_id,p_feeding_plan_id,p_expected_row_version,p_request_id
  );
  delete from private.c010_capability_elevations elevation
  where elevation.transaction_id=pg_catalog.txid_current()
    and elevation.actor_profile_id=private.current_profile_id()
    and elevation.horse_id=p_horse_id and elevation.capability='feeding';
  return result;
end;
$$;

create or replace function public.save_c010_horse_feeding_round(
  p_horse_id uuid,p_plan_type text,p_feeding_plan_id uuid,
  p_expected_plan_row_version bigint,p_round_code text,p_effective_from date,
  p_effective_until date,p_products jsonb,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  perform private.c010_begin_feeding_elevation(p_horse_id);
  result:=public.save_canonical_horse_feeding_round(
    p_horse_id,p_plan_type,p_feeding_plan_id,p_expected_plan_row_version,
    p_round_code,p_effective_from,p_effective_until,p_products,p_request_id
  );
  delete from private.c010_capability_elevations elevation
  where elevation.transaction_id=pg_catalog.txid_current()
    and elevation.actor_profile_id=private.current_profile_id()
    and elevation.horse_id=p_horse_id and elevation.capability='feeding';
  return result;
end;
$$;

create or replace function public.list_c010_horse_schedule(
  p_horse_id uuid,p_from timestamptz,p_through timestamptz,p_scope text default 'all'
)
returns table(
  schedule_item_id uuid,stable_id uuid,horse_id uuid,item_kind text,
  data_category text,title text,instruction text,priority text,
  scheduled_start_at timestamptz,scheduled_end_at timestamptz,
  source_timezone text,state text,state_reason text,row_version bigint,
  participant_profile_ids uuid[],participant_names text[],is_mine boolean
)
language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid;
begin
  actor_profile:=private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_profile,p_horse_id,'horse.view');
  if p_scope not in('all','mine') or p_from is null or p_through is null
    or p_through<p_from or p_through>p_from+interval '2 years'
  then raise exception using errcode='22023',message='INVALID_C010_SCHEDULE_PERIOD'; end if;
  return query
  select item.id,item.stable_id,item.horse_id,item.item_kind,item.data_category,
    item.title,item.instruction,item.priority,item.scheduled_start_at,
    item.scheduled_end_at,item.source_timezone,item.state,item.state_reason,
    item.row_version,
    coalesce((select pg_catalog.array_agg(participant.profile_id order by profile.display_name,participant.profile_id)
      from public.schedule_item_participants participant
      join public.profiles profile on profile.id=participant.profile_id
      where participant.schedule_item_id=item.id and participant.status='active'),array[]::uuid[]),
    coalesce((select pg_catalog.array_agg(profile.display_name order by profile.display_name,participant.profile_id)
      from public.schedule_item_participants participant
      join public.profiles profile on profile.id=participant.profile_id
      where participant.schedule_item_id=item.id and participant.status='active'),array[]::text[]),
    exists(select 1 from public.schedule_item_participants mine
      where mine.schedule_item_id=item.id and mine.profile_id=actor_profile
        and mine.status='active')
  from public.schedule_items item
  where item.horse_id=p_horse_id and item.scheduled_start_at<p_through
    and coalesce(item.scheduled_end_at,item.scheduled_start_at)>=p_from
    and(p_scope='all' or exists(
      select 1 from public.schedule_item_participants participant
      where participant.schedule_item_id=item.id
        and participant.profile_id=actor_profile and participant.status='active'
    ))
  order by item.scheduled_start_at,item.id;
end;
$$;

create or replace function public.list_c010_my_schedule(
  p_from timestamptz,p_through timestamptz
)
returns table(
  schedule_item_id uuid,horse_id uuid,horse_name text,item_kind text,title text,
  scheduled_start_at timestamptz,scheduled_end_at timestamptz,state text,
  row_version bigint,participant_names text[]
)
language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid;
begin
  actor_profile:=private.c003c_actor_profile_id();
  if p_from is null or p_through is null or p_through<p_from
    or p_through>p_from+interval '2 years'
  then raise exception using errcode='22023',message='INVALID_C010_SCHEDULE_PERIOD'; end if;
  return query
  select item.id,item.horse_id,horse.display_name,item.item_kind,item.title,
    item.scheduled_start_at,item.scheduled_end_at,item.state,item.row_version,
    coalesce((select pg_catalog.array_agg(profile.display_name order by profile.display_name,all_participant.profile_id)
      from public.schedule_item_participants all_participant
      join public.profiles profile on profile.id=all_participant.profile_id
      where all_participant.schedule_item_id=item.id and all_participant.status='active'),array[]::text[])
  from public.schedule_items item
  join public.canonical_horses horse on horse.id=item.horse_id
  join public.schedule_item_participants participant
    on participant.schedule_item_id=item.id and participant.profile_id=actor_profile
      and participant.status='active'
  where private.c003c_profile_has_horse_permission(
      actor_profile,item.horse_id,'horse.view',pg_catalog.statement_timestamp()
    ) and item.scheduled_start_at<p_through
    and coalesce(item.scheduled_end_at,item.scheduled_start_at)>=p_from
  order by item.scheduled_start_at,item.id;
end;
$$;

create or replace function public.list_c010_stables()
returns table(
  organization_id uuid,name text,location_name text,locality text,
  lifecycle_status text,role_codes text[],horse_count bigint,team_count bigint,
  next_activity_at timestamptz,can_edit boolean,can_manage_team boolean,
  can_view_planning boolean,can_view_feeding boolean,row_version bigint
)
language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid;
begin
  actor_profile:=private.c003b_actor_profile_id();
  return query
  select organization.id,organization.name,organization.location_name,
    organization.locality,organization.status,
    coalesce((select pg_catalog.array_agg(distinct role.code order by role.code)
      from public.organization_memberships membership
      join public.organization_membership_roles assignment
        on assignment.membership_id=membership.id and assignment.status='active'
      join public.organization_roles role on role.id=assignment.role_id
      where membership.organization_id=organization.id
        and membership.profile_id=actor_profile and membership.status='active'),array[]::text[]),
    (select pg_catalog.count(*) from public.horse_residencies residency
      where residency.stable_organization_id=organization.id and residency.status='active'
        and private.c003c_profile_has_horse_permission(
          actor_profile,residency.horse_id,'horse.view',pg_catalog.statement_timestamp()
        )),
    (select pg_catalog.count(*) from public.organization_memberships membership
      where membership.organization_id=organization.id and membership.status='active'),
    (select pg_catalog.min(item.scheduled_start_at)
      from public.horse_residencies residency
      join public.schedule_items item on item.horse_id=residency.horse_id
      where residency.stable_organization_id=organization.id
        and residency.status='active' and item.state in('planned','in_progress')
        and item.scheduled_start_at>=pg_catalog.statement_timestamp()
        and private.c003c_profile_has_horse_permission(
          actor_profile,item.horse_id,'horse.view',pg_catalog.statement_timestamp()
        )),
    private.c003b_profile_has_permission(actor_profile,organization.id,'organization.edit'),
    private.c003b_profile_has_permission(actor_profile,organization.id,'organization.memberships.manage'),
    private.c003b_profile_has_permission(actor_profile,organization.id,'organization.planning.view'),
    private.c003b_profile_has_permission(actor_profile,organization.id,'organization.feeding.view'),
    organization.row_version
  from public.organizations organization
  join public.organization_types type on type.id=organization.organization_type_id
  where type.code='stable' and private.c003b_profile_has_permission(
    actor_profile,organization.id,'organization.view',pg_catalog.statement_timestamp()
  )
  order by pg_catalog.lower(organization.name),organization.id;
end;
$$;

create or replace function public.get_c010_stable_workspace(
  p_organization_id uuid,p_from timestamptz,p_through timestamptz,p_on_date date,
  p_planning_scope text default 'all'
)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid; can_team boolean; can_planning boolean;
  can_feeding boolean; result jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if not private.c003b_profile_has_permission(
    actor_profile,p_organization_id,'organization.view',pg_catalog.statement_timestamp()
  ) then raise exception using errcode='42501',message='ORGANIZATION_PERMISSION_REQUIRED'; end if;
  if p_from is null or p_through is null or p_through<p_from
    or p_through>p_from+interval '1 year' or p_on_date is null
    or p_planning_scope not in('mine','all')
  then raise exception using errcode='22023',message='C010_WORKSPACE_PERIOD_INVALID'; end if;
  can_team:=private.c003b_profile_has_permission(
    actor_profile,p_organization_id,'organization.memberships.view',pg_catalog.statement_timestamp()
  );
  can_planning:=private.c003b_profile_has_permission(
    actor_profile,p_organization_id,'organization.planning.view',pg_catalog.statement_timestamp()
  );
  can_feeding:=private.c003b_profile_has_permission(
    actor_profile,p_organization_id,'organization.feeding.view',pg_catalog.statement_timestamp()
  );
  select pg_catalog.jsonb_build_object(
    'organization',pg_catalog.jsonb_build_object(
      'id',organization.id,'name',organization.name,
      'location_name',organization.location_name,'address_line',organization.address_line,
      'locality',organization.locality,'status',organization.status,
      'row_version',organization.row_version,'access_version',organization.access_version,
      'primary_authority_profile_id',organization.primary_admin_profile_id,
      'is_primary_authority',organization.primary_admin_profile_id=actor_profile
    ),
    'capabilities',(
      select coalesce(pg_catalog.jsonb_object_agg(
        permission.code,private.c003b_profile_has_permission(
          actor_profile,p_organization_id,permission.code,pg_catalog.statement_timestamp()
        )
      ),'{}'::jsonb)
      from public.permission_definitions permission
      where permission.scope_kind='organization' and permission.is_active
    ),
    'roles',case when can_team then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',role.id,'code',role.code,'name',role.name,
        'description',role.description,'status',role.status,
        'is_reserved',role.is_reserved,'row_version',role.row_version,
        'permissions',coalesce((
          select pg_catalog.jsonb_agg(permission.code order by permission.code)
          from public.organization_role_permissions role_permission
          join public.permission_definitions permission
            on permission.id=role_permission.permission_id
          where role_permission.role_id=role.id
        ),'[]'::jsonb)
      ) order by case role.code when 'manager' then 0 when 'rider' then 1
        when 'trainer' then 2 else 3 end)
      from public.organization_roles role
      where role.organization_id=p_organization_id and role.status='active'
        and role.code in('manager','rider','trainer','groom')
    ),'[]'::jsonb) else '[]'::jsonb end,
    'memberships',case when can_team then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',membership.id,'profile_id',membership.profile_id,
        'profile_name',profile.display_name,'avatar_object_path',profile.avatar_object_path,
        'status',membership.status,'row_version',membership.row_version,
        'role_code',coalesce((select role.code
          from public.organization_membership_roles assignment
          join public.organization_roles role on role.id=assignment.role_id
          where assignment.membership_id=membership.id and assignment.status='active'
            and not role.is_reserved
          order by assignment.created_at desc limit 1),'beheerder'),
        'role_name',coalesce((select role.name
          from public.organization_membership_roles assignment
          join public.organization_roles role on role.id=assignment.role_id
          where assignment.membership_id=membership.id and assignment.status='active'
            and not role.is_reserved
          order by assignment.created_at desc limit 1),'Beheerder')
      ) order by pg_catalog.lower(profile.display_name),membership.id)
      from public.organization_memberships membership
      join public.profiles profile on profile.id=membership.profile_id
      where membership.organization_id=p_organization_id
    ),'[]'::jsonb) else '[]'::jsonb end,
    'invitations',case when can_team then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',invitation.id,'role_code',role.code,'role_name',role.name,
        'status',invitation.status,'expires_at',invitation.expires_at,
        'row_version',invitation.row_version,'created_at',invitation.created_at
      ) order by invitation.created_at desc)
      from public.organization_invitations invitation
      join public.organization_roles role on role.id=invitation.initial_role_id
      where invitation.organization_id=p_organization_id
    ),'[]'::jsonb) else '[]'::jsonb end,
    'horses',coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'horse_id',horse.id,'horse_name',horse.display_name,
        'residency_id',residency.id,'residency_row_version',residency.row_version,
        'can_edit',private.c003c_profile_has_horse_permission(
          actor_profile,horse.id,'horse.edit',pg_catalog.statement_timestamp()
        ),'can_manage',private.c003c_profile_has_horse_permission(
          actor_profile,horse.id,'horse.manage',pg_catalog.statement_timestamp()
        ),'can_manage_planning',private.c003c_profile_has_horse_permission(
          actor_profile,horse.id,'horse.planning.manage',pg_catalog.statement_timestamp()
        ),'can_manage_feeding',private.c003c_profile_has_horse_permission(
          actor_profile,horse.id,'horse.feeding.manage',pg_catalog.statement_timestamp()
        )
      ) order by pg_catalog.lower(horse.display_name),horse.id)
      from public.horse_residencies residency
      join public.canonical_horses horse on horse.id=residency.horse_id
      where residency.stable_organization_id=p_organization_id
        and residency.status='active'
        and private.c003c_profile_has_horse_permission(
          actor_profile,horse.id,'horse.view',pg_catalog.statement_timestamp()
        )
    ),'[]'::jsonb),
    'planning',case when can_planning then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'schedule_item_id',item.id,'horse_id',horse.id,'horse_name',horse.display_name,
        'item_kind',item.item_kind,'title',item.title,'instruction',item.instruction,
        'scheduled_start_at',item.scheduled_start_at,
        'scheduled_end_at',item.scheduled_end_at,'state',item.state,
        'row_version',item.row_version,
        'is_mine',exists(select 1 from public.schedule_item_participants mine
          where mine.schedule_item_id=item.id and mine.profile_id=actor_profile
            and mine.status='active'),
        'participant_names',coalesce((select pg_catalog.jsonb_agg(
          profile.display_name order by profile.display_name,participant.profile_id
        ) from public.schedule_item_participants participant
          join public.profiles profile on profile.id=participant.profile_id
          where participant.schedule_item_id=item.id and participant.status='active'
        ),'[]'::jsonb)
      ) order by item.scheduled_start_at,item.id)
      from public.horse_residencies residency
      join public.canonical_horses horse on horse.id=residency.horse_id
      join public.schedule_items item on item.horse_id=horse.id
      where residency.stable_organization_id=p_organization_id
        and residency.status='active'
        and item.scheduled_start_at<p_through
        and coalesce(item.scheduled_end_at,item.scheduled_start_at)>=p_from
        and private.c003c_profile_has_horse_permission(
          actor_profile,horse.id,'horse.view',pg_catalog.statement_timestamp()
        )
        and(p_planning_scope='all' or exists(
          select 1 from public.schedule_item_participants mine
          where mine.schedule_item_id=item.id and mine.profile_id=actor_profile
            and mine.status='active'
        ))
    ),'[]'::jsonb) else '[]'::jsonb end,
    'feeding',case when can_feeding then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'horse_id',horse.id,'horse_name',horse.display_name,
        'active_plan_id',active_plan.id,'plan_type',active_plan.plan_type,
        'plan_name',active_plan.name,'effective_from',active_plan.effective_from,
        'effective_until',active_plan.effective_until,
        'rounds',coalesce((
          select pg_catalog.jsonb_agg(round_data.value order by round_data.sort_order)
          from(
            select case item.round_code when 'morning' then 0 when 'afternoon' then 1
                when 'evening' then 2 else 3 end sort_order,
              pg_catalog.jsonb_build_object(
                'round_code',item.round_code,
                'items',pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
                  'description',coalesce(item.product_brand,item.product_name,item.product_variant,'Voeding'),
                  'product_name',item.product_name,'product_variant',item.product_variant,
                  'quantity',item.planned_quantity,'unit_code',item.unit_code,
                  'instruction',item.instruction
                ) order by item.local_time,item.id)
              ) value
            from public.feeding_plan_items item
            where item.feeding_plan_version_id=active_plan.active_version_id
            group by item.round_code
          ) round_data
        ),'[]'::jsonb)
      ) order by pg_catalog.lower(horse.display_name),horse.id)
      from public.horse_residencies residency
      join public.canonical_horses horse on horse.id=residency.horse_id
      left join lateral(
        select plan.* from public.feeding_plans plan
        where plan.horse_id=horse.id and plan.status='active'
          and plan.effective_from<=p_on_date
          and(plan.effective_until is null or plan.effective_until>=p_on_date)
        order by case plan.plan_type when 'temporary' then 0 else 1 end,
          plan.effective_from desc,plan.id limit 1
      ) active_plan on true
      where residency.stable_organization_id=p_organization_id
        and residency.status='active'
        and private.c003c_profile_has_horse_permission(
          actor_profile,horse.id,'horse.view',pg_catalog.statement_timestamp()
        )
    ),'[]'::jsonb) else '[]'::jsonb end
  ) into result
  from public.organizations organization
  join public.organization_types type
    on type.id=organization.organization_type_id and type.code='stable'
  where organization.id=p_organization_id;
  if result is null then
    raise exception using errcode='P0002',message='STABLE_NOT_FOUND'; end if;
  return result;
end;
$$;

alter table public.schedule_item_participants enable row level security;
create policy schedule_item_participants_read
on public.schedule_item_participants for select to authenticated
using(
  profile_id=private.current_profile_id()
  or public.has_canonical_horse_permission(horse_id,'horse.view')
);

revoke all on table public.schedule_item_participants
  from public,anon,authenticated,service_role;
grant select on table public.schedule_item_participants to authenticated;
revoke all on table private.c010_mutation_receipts,private.c010_capability_elevations
  from public,anon,authenticated,service_role;

revoke all on function private.c010_receipt_result(uuid,uuid,text,bytea),
  private.c010_seed_role_templates(uuid,uuid),
  private.c010_participant_allowed(uuid,uuid),
  private.c010_begin_feeding_elevation(uuid)
  from public,anon,authenticated,service_role;

revoke all on function public.create_c010_stable(text,text,uuid),
  public.update_c010_stable(uuid,bigint,text,text,text,text,uuid),
  public.create_c010_stable_invitation(uuid,text,text,timestamptz,uuid),
  public.set_c010_team_role(uuid,uuid,bigint,text,uuid),
  public.revoke_c010_membership(uuid,uuid,bigint,uuid),
  public.set_c010_horse_residency(uuid,uuid,bigint,uuid),
  public.set_c010_horse_collaborator(uuid,uuid,text,text[],boolean,uuid),
  public.list_c010_horse_collaboration(uuid),
  public.list_c010_horses(),
  public.upsert_c010_horse_schedule_item(
    uuid,uuid,bigint,text,text,text,text,timestamptz,timestamptz,
    text,text,text,uuid[],uuid
  ),
  public.list_c010_horse_schedule(uuid,timestamptz,timestamptz,text),
  public.list_c010_my_schedule(timestamptz,timestamptz),
  public.list_c010_stables(),
  public.get_c010_stable_workspace(uuid,timestamptz,timestamptz,date,text),
  public.create_c010_horse_feeding_plan(uuid,text,text,date,date,text,uuid),
  public.upsert_c010_horse_feeding_item(
    uuid,uuid,uuid,bigint,text,text,text,text,numeric,text,text,text,time,
    smallint[],integer,text,text,uuid
  ),
  public.transition_c010_horse_feeding_version(uuid,uuid,bigint,text,uuid),
  public.retire_c010_horse_feeding_plan(uuid,uuid,bigint,uuid),
  public.save_c010_horse_feeding_round(uuid,text,uuid,bigint,text,date,date,jsonb,uuid)
  from public,anon,authenticated,service_role;

grant execute on function public.create_c010_stable(text,text,uuid),
  public.update_c010_stable(uuid,bigint,text,text,text,text,uuid),
  public.create_c010_stable_invitation(uuid,text,text,timestamptz,uuid),
  public.set_c010_team_role(uuid,uuid,bigint,text,uuid),
  public.revoke_c010_membership(uuid,uuid,bigint,uuid),
  public.set_c010_horse_residency(uuid,uuid,bigint,uuid),
  public.set_c010_horse_collaborator(uuid,uuid,text,text[],boolean,uuid),
  public.list_c010_horse_collaboration(uuid),
  public.list_c010_horses(),
  public.upsert_c010_horse_schedule_item(
    uuid,uuid,bigint,text,text,text,text,timestamptz,timestamptz,
    text,text,text,uuid[],uuid
  ),
  public.list_c010_horse_schedule(uuid,timestamptz,timestamptz,text),
  public.list_c010_my_schedule(timestamptz,timestamptz),
  public.list_c010_stables(),
  public.get_c010_stable_workspace(uuid,timestamptz,timestamptz,date,text),
  public.create_c010_horse_feeding_plan(uuid,text,text,date,date,text,uuid),
  public.upsert_c010_horse_feeding_item(
    uuid,uuid,uuid,bigint,text,text,text,text,numeric,text,text,text,time,
    smallint[],integer,text,text,uuid
  ),
  public.transition_c010_horse_feeding_version(uuid,uuid,bigint,text,uuid),
  public.retire_c010_horse_feeding_plan(uuid,uuid,bigint,uuid),
  public.save_c010_horse_feeding_round(uuid,text,uuid,bigint,text,date,date,jsonb,uuid)
  to authenticated;

do $$
begin
  if exists(
    select 1 from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where(namespace.nspname='private' and procedure.proname like 'c010_%')
      and(
        pg_catalog.has_function_privilege('anon',procedure.oid,'EXECUTE')
        or pg_catalog.has_function_privilege('authenticated',procedure.oid,'EXECUTE')
        or pg_catalog.has_function_privilege('service_role',procedure.oid,'EXECUTE')
      )
  ) then raise exception using errcode='55000',message='C010_PRIVATE_ACL_INVALID'; end if;
  if exists(
    select 1 from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='public' and procedure.proname like '%c010%'
      and(
        not procedure.prosecdef
        or not coalesce(procedure.proconfig@>array['search_path=""'],false)
        or pg_catalog.has_function_privilege('anon',procedure.oid,'EXECUTE')
        or pg_catalog.has_function_privilege('service_role',procedure.oid,'EXECUTE')
        or not pg_catalog.has_function_privilege('authenticated',procedure.oid,'EXECUTE')
      )
  ) then raise exception using errcode='55000',message='C010_PUBLIC_ACL_INVALID'; end if;
end;
$$;

comment on table public.schedule_item_participants is
  'C-010 historical profile participants on canonical schedule_items; no horse permission is implied.';
comment on function public.get_c010_stable_workspace(uuid,timestamptz,timestamptz,date,text) is
  'Permission-filtered C-010 stable projection over canonical horses, planning and feeding.';

commit;
