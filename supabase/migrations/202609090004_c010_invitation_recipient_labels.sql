begin;

-- A bounded projection for existing organization invitations. Only an existing
-- invitation manager receives the linked canonical profile's current label.
-- Unlinked invitations remain null: their HMAC is not a display identity.
-- No Auth lookup, new grant, identifier field, snapshot, RLS or mutation change.
create or replace function public.get_c010_stable_workspace(
  p_organization_id uuid,p_from timestamptz,p_through timestamptz,p_on_date date,
  p_planning_scope text default 'all'
)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid; can_team boolean; can_planning boolean;
  can_feeding boolean; can_manage_invitations boolean; result jsonb;
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
  can_manage_invitations:=private.c003b_profile_has_permission(
    actor_profile,p_organization_id,'organization.invitations.manage',pg_catalog.statement_timestamp()
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
        'recipient_label',case when can_manage_invitations then (
          select case when recipient.status='active' then recipient.display_name
            else 'Niet-actief account' end
          from public.profiles recipient
          where recipient.id=coalesce(invitation.accepted_by_profile_id,invitation.target_profile_id)
        ) else null::text end,
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

commit;
