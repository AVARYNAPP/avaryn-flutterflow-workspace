begin;

-- C-009 is an additive product slice over the approved C-003B/C/D/E model.
-- Persons remain the only authenticated principals; organizations never get
-- auth identities or credentials. Existing scalar authority and lifecycle
-- tables remain authoritative.

insert into public.permission_definitions (
  code, scope_kind, action_class, description, is_grantable, is_active
) values
  ('organization.invitations.manage','organization','manage','Create and revoke organization invitations.',true,true),
  ('organization.horse_links.manage','organization','manage','Propose and respond to bilateral horse links for the organization context.',true,true),
  ('organization.residencies.manage','organization','manage','Manage the organization side of horse residency administration.',true,true),
  ('organization.planning.view','organization','view','View explicitly shared stable planning.',true,true),
  ('organization.planning.execute','organization','manage','Execute explicitly assigned stable work.',true,true),
  ('organization.feeding.view','organization','view','View explicitly shared feeding information.',true,true),
  ('organization.feeding.edit','organization','edit','Edit explicitly shared feeding information.',true,true)
on conflict (code) do nothing;

-- Existing reserved head roles receive newly introduced organization-scoped
-- capabilities. Non-reserved roles are deliberately not broadened.
insert into public.organization_role_permissions (
  organization_id, role_id, permission_id, granted_by_profile_id,
  correlation_id
)
select role.organization_id, role.id, permission.id,
  organization.primary_admin_profile_id, extensions.gen_random_uuid()
from public.organization_roles role
join public.organizations organization on organization.id = role.organization_id
cross join public.permission_definitions permission
where role.code = 'head_admin'
  and role.is_system
  and role.is_reserved
  and permission.code in (
    'organization.invitations.manage',
    'organization.horse_links.manage',
    'organization.residencies.manage',
    'organization.planning.view',
    'organization.planning.execute',
    'organization.feeding.view',
    'organization.feeding.edit'
  )
on conflict (role_id, permission_id) do nothing;

create or replace function private.c003c_context_authorized(
  p_actor_id uuid,p_context text,p_horse_id uuid,p_organization_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case p_context
    when 'horse' then private.c003c_profile_has_horse_permission(
      p_actor_id,p_horse_id,'horse.manage',pg_catalog.statement_timestamp()
    )
    when 'organization' then
      private.c003b_profile_has_permission(
        p_actor_id,p_organization_id,'organization.horse_links.manage',
        pg_catalog.statement_timestamp()
      )
      or private.c003b_profile_has_permission(
        p_actor_id,p_organization_id,'organization.edit',
        pg_catalog.statement_timestamp()
      )
    else false
  end
$$;

create or replace function private.c009_seed_role_templates(
  p_organization_id uuid,p_actor_profile_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  template record;
  role_id uuid;
  permission_code text;
begin
  perform 1
  from public.organizations organization
  where organization.id = p_organization_id
    and organization.status = 'active'
    and organization.primary_admin_profile_id = p_actor_profile_id
  for update;
  if not found then
    raise exception using errcode = '42501', message = 'PRIMARY_ORGANIZATION_ADMIN_REQUIRED';
  end if;

  for template in
    select * from (values
      ('stable_admin','Beheerder','Beheert organisatie, leden, rollen en operationele koppelingen.',array[
        'organization.view','organization.edit','organization.memberships.view',
        'organization.memberships.manage','organization.roles.view',
        'organization.roles.manage','organization.audit.view',
        'organization.invitations.manage','organization.horse_links.manage',
        'organization.residencies.manage','organization.planning.view',
        'organization.planning.execute','organization.feeding.view',
        'organization.feeding.edit'
      ]::text[]),
      ('stable_manager','Stalmanager','Beheert operationele stalwerkzaamheden zonder authority- of rollenbeheer.',array[
        'organization.view','organization.memberships.view',
        'organization.horse_links.manage','organization.residencies.manage',
        'organization.planning.view','organization.planning.execute',
        'organization.feeding.view','organization.feeding.edit'
      ]::text[]),
      ('stable_worker','Medewerker','Voert uitsluitend expliciet gedeelde of toegewezen werkzaamheden uit.',array[
        'organization.view','organization.planning.view',
        'organization.planning.execute','organization.feeding.view'
      ]::text[]),
      ('stable_viewer','Beperkte kijkrol','Leest uitsluitend expliciet gedeelde stalcontext.',array[
        'organization.view','organization.planning.view',
        'organization.feeding.view'
      ]::text[])
    ) value(code,name,description,permission_codes)
  loop
    select role.id into role_id
    from public.organization_roles role
    where role.organization_id = p_organization_id
      and role.code = template.code;
    if role_id is null then
      insert into public.organization_roles (
        organization_id,code,name,description,status,is_system,is_reserved,
        created_by_profile_id,creation_correlation_id
      ) values (
        p_organization_id,template.code,template.name,template.description,
        'active',true,false,p_actor_profile_id,extensions.gen_random_uuid()
      ) returning id into role_id;
      foreach permission_code in array template.permission_codes loop
        insert into public.organization_role_permissions (
          organization_id,role_id,permission_id,granted_by_profile_id,
          correlation_id
        )
        select p_organization_id,role_id,permission.id,p_actor_profile_id,
          extensions.gen_random_uuid()
        from public.permission_definitions permission
        where permission.code = permission_code
          and permission.scope_kind = 'organization'
          and permission.is_active
          and permission.is_grantable;
      end loop;
    end if;
  end loop;
end;
$$;

-- Existing stable organizations gain missing template rows, but no custom role
-- or existing role-permission assignment is overwritten.
do $$
declare organization record;
begin
  for organization in
    select value.id,value.primary_admin_profile_id
    from public.organizations value
    join public.organization_types type
      on type.id = value.organization_type_id
    where type.code = 'stable' and value.status = 'active'
  loop
    perform private.c009_seed_role_templates(
      organization.id,organization.primary_admin_profile_id
    );
  end loop;
end;
$$;

create or replace function public.create_stable_account(
  p_name text,p_description text,p_correlation_id uuid
)
returns table (
  organization_id uuid,membership_id uuid,head_admin_role_id uuid,
  organization_access_version bigint,organization_row_version bigint,
  result_code text,applied boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  created record;
begin
  actor_id := private.c003b_actor_profile_id();
  select * into created
  from public.create_organization(
    'stable',p_name,p_description,p_correlation_id,'{}'::jsonb
  );
  -- C-003B uses clock_timestamp() defaults while authorization deliberately
  -- evaluates one stable statement timestamp. A freshly created stable must
  -- therefore activate its initial authority membership and reserved role no
  -- later than this RPC statement, including when a transaction-aware client
  -- calls another C-009 routine in the same statement batch.
  if created.applied then
    update public.organization_memberships membership
    set valid_from=case
      when membership.valid_from>pg_catalog.statement_timestamp()
        then pg_catalog.statement_timestamp()
      else membership.valid_from
    end
    where membership.id=created.membership_id
      and membership.organization_id=created.organization_id;
    update public.organization_membership_roles assignment
    set valid_from=case
      when assignment.valid_from>pg_catalog.statement_timestamp()
        then pg_catalog.statement_timestamp()
      else assignment.valid_from
    end
    where assignment.membership_id=created.membership_id
      and assignment.role_id=created.head_admin_role_id
      and assignment.organization_id=created.organization_id;
  end if;
  perform private.c009_seed_role_templates(created.organization_id,actor_id);
  return query select
    created.organization_id,created.membership_id,created.head_admin_role_id,
    created.organization_access_version,created.organization_row_version,
    created.result_code,created.applied;
end;
$$;

create or replace function public.list_stable_accounts()
returns table (
  organization_id uuid,name text,description text,lifecycle_status text,
  primary_authority_profile_id uuid,access_version bigint,row_version bigint,
  is_primary_authority boolean,can_edit boolean,can_view_members boolean,
  can_manage_members boolean,can_manage_roles boolean,can_manage_links boolean,
  can_manage_residencies boolean,can_view_planning boolean,
  can_execute_planning boolean,can_view_feeding boolean,can_edit_feeding boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    organization.id,organization.name,organization.description,
    organization.status,organization.primary_admin_profile_id,
    organization.access_version,organization.row_version,
    organization.primary_admin_profile_id = private.current_profile_id(),
    private.c003b_profile_has_permission(private.current_profile_id(),organization.id,'organization.edit',pg_catalog.statement_timestamp()),
    private.c003b_profile_has_permission(private.current_profile_id(),organization.id,'organization.memberships.view',pg_catalog.statement_timestamp()),
    private.c003b_profile_has_permission(private.current_profile_id(),organization.id,'organization.memberships.manage',pg_catalog.statement_timestamp()),
    private.c003b_profile_has_permission(private.current_profile_id(),organization.id,'organization.roles.manage',pg_catalog.statement_timestamp()),
    private.c003b_profile_has_permission(private.current_profile_id(),organization.id,'organization.horse_links.manage',pg_catalog.statement_timestamp()),
    private.c003b_profile_has_permission(private.current_profile_id(),organization.id,'organization.residencies.manage',pg_catalog.statement_timestamp()),
    private.c003b_profile_has_permission(private.current_profile_id(),organization.id,'organization.planning.view',pg_catalog.statement_timestamp()),
    private.c003b_profile_has_permission(private.current_profile_id(),organization.id,'organization.planning.execute',pg_catalog.statement_timestamp()),
    private.c003b_profile_has_permission(private.current_profile_id(),organization.id,'organization.feeding.view',pg_catalog.statement_timestamp()),
    private.c003b_profile_has_permission(private.current_profile_id(),organization.id,'organization.feeding.edit',pg_catalog.statement_timestamp())
  from public.organizations organization
  join public.organization_types type
    on type.id = organization.organization_type_id
  where type.code = 'stable'
    and private.c003b_profile_has_permission(
      private.current_profile_id(),organization.id,'organization.view',
      pg_catalog.statement_timestamp()
    )
  order by pg_catalog.lower(organization.name),organization.id
$$;

create or replace function public.get_stable_account_workspace(
  p_organization_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  can_members boolean;
  can_roles boolean;
  can_audit boolean;
  result jsonb;
begin
  actor_id := private.c003b_actor_profile_id();
  if not private.c003b_profile_has_permission(
    actor_id,p_organization_id,'organization.view'
  ) then
    raise exception using errcode = '42501', message = 'ORGANIZATION_PERMISSION_REQUIRED';
  end if;
  can_members := private.c003b_profile_has_permission(
    actor_id,p_organization_id,'organization.memberships.view'
  );
  can_roles := private.c003b_profile_has_permission(
    actor_id,p_organization_id,'organization.roles.view'
  );
  can_audit := private.c003b_profile_has_permission(
    actor_id,p_organization_id,'organization.audit.view'
  );

  select pg_catalog.jsonb_build_object(
    'organization',pg_catalog.jsonb_build_object(
      'id',organization.id,'name',organization.name,
      'description',organization.description,'status',organization.status,
      'primary_authority_profile_id',organization.primary_admin_profile_id,
      'primary_authority_name',authority.display_name,
      'access_version',organization.access_version,
      'row_version',organization.row_version,
      'created_at',organization.created_at,
      'is_primary_authority',organization.primary_admin_profile_id = actor_id
    ),
    'capabilities',(
      select coalesce(pg_catalog.jsonb_object_agg(
        permission.code,
        private.c003b_profile_has_permission(
          actor_id,p_organization_id,permission.code,
          pg_catalog.statement_timestamp()
        )
      ),'{}'::jsonb)
      from public.permission_definitions permission
      where permission.scope_kind = 'organization' and permission.is_active
    ),
    'memberships',case when can_members then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',membership.id,'profile_id',membership.profile_id,
        'profile_name',profile.display_name,'status',membership.status,
        'valid_from',membership.valid_from,'valid_until',membership.valid_until,
        'row_version',membership.row_version,
        'roles',coalesce((
          select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
            'assignment_id',assignment.id,'assignment_status',assignment.status,
            'assignment_row_version',assignment.row_version,
            'role_id',role.id,'role_code',role.code,'role_name',role.name
          ) order by role.name)
          from public.organization_membership_roles assignment
          join public.organization_roles role on role.id = assignment.role_id
          where assignment.membership_id = membership.id
        ),'[]'::jsonb)
      ) order by pg_catalog.lower(profile.display_name),membership.id)
      from public.organization_memberships membership
      join public.profiles profile on profile.id = membership.profile_id
      where membership.organization_id = p_organization_id
    ),'[]'::jsonb) else '[]'::jsonb end,
    'roles',case when can_roles then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',role.id,'code',role.code,'name',role.name,
        'description',role.description,'status',role.status,
        'is_reserved',role.is_reserved,'row_version',role.row_version,
        'permissions',coalesce((
          select pg_catalog.jsonb_agg(permission.code order by permission.code)
          from public.organization_role_permissions role_permission
          join public.permission_definitions permission
            on permission.id = role_permission.permission_id
          where role_permission.role_id = role.id
        ),'[]'::jsonb)
      ) order by role.is_reserved desc,role.name)
      from public.organization_roles role
      where role.organization_id = p_organization_id
    ),'[]'::jsonb) else '[]'::jsonb end,
    'invitations',case when can_members then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',invitation.id,'role_id',invitation.initial_role_id,
        'role_name',role.name,'status',invitation.status,
        'expires_at',invitation.expires_at,'row_version',invitation.row_version,
        'created_at',invitation.created_at
      ) order by invitation.created_at desc)
      from public.organization_invitations invitation
      join public.organization_roles role on role.id = invitation.initial_role_id
      where invitation.organization_id = p_organization_id
    ),'[]'::jsonb) else '[]'::jsonb end,
    'horse_links',coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',link.id,'horse_id',link.horse_id,
        'horse_name',case when private.c003c_profile_has_horse_permission(
          actor_id,link.horse_id,'horse.view',pg_catalog.statement_timestamp()
        ) then horse.display_name else null end,
        'can_manage_horse',private.c003c_profile_has_horse_permission(
          actor_id,link.horse_id,'horse.manage',pg_catalog.statement_timestamp()
        ),
        'link_type',type.code,'status',link.status,
        'initiating_context',link.initiating_context,
        'horse_confirmed',link.horse_confirmed_at is not null,
        'organization_confirmed',link.organization_confirmed_at is not null,
        'expires_at',link.expires_at,'row_version',link.row_version
      ) order by link.created_at desc)
      from public.organization_horse_links link
      join public.organization_horse_link_types type on type.id = link.link_type_id
      join public.canonical_horses horse on horse.id = link.horse_id
      where link.organization_id = p_organization_id
    ),'[]'::jsonb),
    'residencies',coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',residency.id,'horse_id',residency.horse_id,
        'horse_name',case when private.c003c_profile_has_horse_permission(
          actor_id,residency.horse_id,'horse.view',pg_catalog.statement_timestamp()
        ) then horse.display_name else null end,
        'status',residency.status,'valid_from',residency.valid_from,
        'valid_until',residency.valid_until,
        'row_version',residency.row_version
      ) order by residency.created_at desc)
      from public.horse_residencies residency
      join public.canonical_horses horse on horse.id = residency.horse_id
      where residency.stable_organization_id = p_organization_id
    ),'[]'::jsonb),
    'pending_authority_transfer',(
      select pg_catalog.jsonb_build_object(
        'id',transfer.id,'recipient_profile_id',transfer.recipient_profile_id,
        'recipient_name',recipient.display_name,'status',transfer.status,
        'expires_at',transfer.expires_at,'row_version',transfer.row_version
      )
      from public.organization_authority_transfers transfer
      join public.profiles recipient on recipient.id = transfer.recipient_profile_id
      where transfer.organization_id = p_organization_id
        and transfer.sender_profile_id = actor_id
        and transfer.status = 'pending'
      limit 1
    ),
    'audit',case when can_audit then coalesce((
      select pg_catalog.jsonb_agg(entry.value order by entry.occurred_at desc)
      from (
        select event.occurred_at,pg_catalog.jsonb_build_object(
          'event_type',event.event_type,'reason_code',event.reason_code,
          'occurred_at',event.occurred_at,
          'row_version_before',event.row_version_before,
          'row_version_after',event.row_version_after,
          'access_version_before',event.access_version_before,
          'access_version_after',event.access_version_after
        ) value
        from public.audit_events event
        where event.scope_kind = 'organization'
          and event.scope_id = p_organization_id
        order by event.occurred_at desc
        limit 75
      ) entry
    ),'[]'::jsonb) else '[]'::jsonb end
  ) into result
  from public.organizations organization
  join public.organization_types type
    on type.id = organization.organization_type_id and type.code = 'stable'
  join public.profiles authority
    on authority.id = organization.primary_admin_profile_id
  where organization.id = p_organization_id;
  if result is null then
    raise exception using errcode = 'P0002', message = 'STABLE_ACCOUNT_NOT_FOUND';
  end if;
  return result;
end;
$$;

create or replace function public.get_horse_organization_links(
  p_horse_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  can_manage boolean;
  result jsonb;
begin
  actor_id := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_id,p_horse_id,'horse.view');
  can_manage := private.c003c_profile_has_horse_permission(
    actor_id,p_horse_id,'horse.manage',pg_catalog.statement_timestamp()
  );
  select coalesce(pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
    'id',link.id,'horse_id',link.horse_id,
    'organization_id',link.organization_id,
    'organization_name',organization.name,'link_type',type.code,
    'status',link.status,'initiating_context',link.initiating_context,
    'horse_confirmed',link.horse_confirmed_at is not null,
    'organization_confirmed',link.organization_confirmed_at is not null,
    'expires_at',link.expires_at,'row_version',link.row_version,
    'roles',case when can_manage and link.status = 'active' then coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',role.id,'code',role.code,'name',role.name
      ) order by role.name)
      from public.organization_roles role
      where role.organization_id = link.organization_id
        and role.status = 'active' and not role.is_reserved
    ),'[]'::jsonb) else '[]'::jsonb end
  ) order by link.created_at desc),'[]'::jsonb) into result
  from public.organization_horse_links link
  join public.organizations organization on organization.id = link.organization_id
  join public.organization_horse_link_types type on type.id = link.link_type_id
  where link.horse_id = p_horse_id;
  return result;
end;
$$;

create or replace function public.create_stable_invitation_by_role_code(
  p_organization_id uuid,p_role_code text,p_target_email text,
  p_expires_at timestamptz,p_correlation_id uuid
)
returns table (
  invitation_id uuid,invitation_token text,expires_at timestamptz,
  applied boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare role_id uuid;
begin
  select role.id into role_id
  from public.organization_roles role
  where role.organization_id = p_organization_id
    and role.code = p_role_code
    and role.status = 'active'
    and not role.is_reserved;
  if role_id is null then
    raise exception using errcode = '22023', message = 'INVITATION_ROLE_INVALID';
  end if;
  return query select * from public.create_organization_invitation(
    p_organization_id,role_id,p_target_email,p_expires_at,p_correlation_id
  );
end;
$$;

create or replace function public.respond_stable_invitation(
  p_invitation_token text,p_action text,p_correlation_id uuid
)
returns table (
  invitation_id uuid,membership_id uuid,row_version bigint,status text,
  applied boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  responded record;
  target_role_id uuid;
  target_organization_id uuid;
begin
  perform private.c003b_actor_profile_id();
  select * into responded from public.respond_organization_invitation(
    p_invitation_token,p_action,p_correlation_id
  );
  if responded.applied and responded.status = 'accepted'
    and responded.membership_id is not null
  then
    select invitation.organization_id,invitation.initial_role_id
    into target_organization_id,target_role_id
    from public.organization_invitations invitation
    where invitation.id = responded.invitation_id;
    update public.organization_memberships membership
    set valid_from=case
      when membership.valid_from>pg_catalog.statement_timestamp()
        then pg_catalog.statement_timestamp()
      else membership.valid_from
    end
    where membership.id=responded.membership_id
      and membership.organization_id=target_organization_id;
    update public.organization_membership_roles assignment
    set valid_from=case
      when assignment.valid_from>pg_catalog.statement_timestamp()
        then pg_catalog.statement_timestamp()
      else assignment.valid_from
    end
    where assignment.membership_id=responded.membership_id
      and assignment.role_id=target_role_id
      and assignment.organization_id=target_organization_id
      and assignment.status='active';
  end if;
  return query select
    responded.invitation_id,responded.membership_id,responded.row_version,
    responded.status,responded.applied;
end;
$$;

create or replace function public.initiate_organization_authority_transfer_by_email(
  p_organization_id uuid,p_recipient_email text,p_correlation_id uuid
)
returns table (
  transfer_id uuid,transfer_token text,expires_at timestamptz,
  row_version bigint,applied boolean
)
language sql
security definer
set search_path = ''
as $$
  select * from public.initiate_organization_authority_transfer(
    p_organization_id,
    private.c008_target_profile_by_email(p_recipient_email),
    p_correlation_id
  )
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
  if responded.applied and responded.status='accepted' then
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

revoke execute on function public.create_stable_account(text,text,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.create_stable_account(text,text,uuid)
  to authenticated;
revoke execute on function public.list_stable_accounts()
  from public,anon,authenticated,service_role;
grant execute on function public.list_stable_accounts() to authenticated;
revoke execute on function public.get_stable_account_workspace(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.get_stable_account_workspace(uuid)
  to authenticated;
revoke execute on function public.get_horse_organization_links(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.get_horse_organization_links(uuid)
  to authenticated;
revoke execute on function public.create_stable_invitation_by_role_code(
  uuid,text,text,timestamptz,uuid
) from public,anon,authenticated,service_role;
grant execute on function public.create_stable_invitation_by_role_code(
  uuid,text,text,timestamptz,uuid
) to authenticated;
revoke execute on function public.respond_stable_invitation(text,text,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.respond_stable_invitation(text,text,uuid)
  to authenticated;
revoke execute on function public.initiate_organization_authority_transfer_by_email(
  uuid,text,uuid
) from public,anon,authenticated,service_role;
grant execute on function public.initiate_organization_authority_transfer_by_email(
  uuid,text,uuid
) to authenticated;
revoke execute on function public.respond_stable_authority_transfer(text,text,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.respond_stable_authority_transfer(text,text,uuid)
  to authenticated;

revoke execute on function private.c009_seed_role_templates(uuid,uuid)
  from public,anon,authenticated,service_role;
revoke execute on function private.c003c_context_authorized(uuid,text,uuid,uuid)
  from public,anon,authenticated,service_role;

comment on function public.create_stable_account(text,text,uuid) is
  'C-009 canonical stable organization creation with one scalar Organization Authority and bounded role templates.';
comment on function public.get_stable_account_workspace(uuid) is
  'C-009 capability-filtered stable account projection; horse links and residency never imply horse access.';
comment on function public.get_horse_organization_links(uuid) is
  'C-009 horse-side bilateral link projection; role targets are visible only to explicit horse managers.';
comment on function public.create_stable_invitation_by_role_code(uuid,text,text,timestamptz,uuid) is
  'C-009 one-time verified-identity invitation wrapper for a non-reserved organization role template.';
comment on function public.respond_stable_invitation(text,text,uuid) is
  'C-009 invitation response with immediate statement-consistent activation of only the accepted membership and intended role.';
comment on function public.respond_stable_authority_transfer(text,text,uuid) is
  'C-009 Organization Authority response preserving the C-003E transfer machine with immediate activation of only the accepted head membership and role.';

commit;
