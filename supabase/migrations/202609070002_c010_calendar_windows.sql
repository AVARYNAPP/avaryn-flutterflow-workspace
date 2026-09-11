begin;

-- C010 calendar contract: Europe/Amsterdam civil dates, half-open instant ranges.
-- Existing feeding effective dates remain inclusive and untouched.

create or replace function public.get_c010_calendar_context()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare now_at timestamptz:=pg_catalog.statement_timestamp(); today date;
begin
  perform private.c003b_actor_profile_id();
  today:=(now_at at time zone 'Europe/Amsterdam')::date;
  return pg_catalog.jsonb_build_object(
    'today_date',today,'time_zone','Europe/Amsterdam','server_now',now_at,
    'next_day_at',(today+1)::timestamp at time zone 'Europe/Amsterdam'
  );
end;
$$;
revoke all on function public.get_c010_calendar_context() from public,anon,authenticated,service_role;
grant execute on function public.get_c010_calendar_context() to authenticated;

create or replace function public.list_c010_stable_activities(
  p_organization_id uuid,p_from timestamptz,p_through timestamptz,p_scope text default 'all'
)
returns table(
  activity_kind text,activity_id uuid,title text,note text,category text,
  scheduled_at timestamptz,due_date date,due_time time,status text,row_version bigint,
  horse_id uuid,horse_name text,location_name text,assignee_profile_id uuid,
  assignee_name text,is_mine boolean,can_complete boolean,stable_place_id uuid
)
language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if p_scope is null or p_scope not in('mine','all') or p_from is null or p_through is null or p_through<=p_from
    or p_through>p_from+interval '1 year'
  then raise exception using errcode='22023',message='C010_ACTIVITY_PERIOD_INVALID'; end if;
  if not private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.planning.view') then
    raise exception using errcode='42501',message='ORGANIZATION_PERMISSION_REQUIRED'; end if;
  return query
  select 'stable_task'::text,task.id,task.title,task.note,task.category,
    case when task.due_time is not null
      then (task.due_date+task.due_time) at time zone 'Europe/Amsterdam' end,
    task.due_date,task.due_time,task.status,task.row_version,task.horse_id,horse.display_name,
    coalesce(place.label,task.location_text),task.assignee_profile_id,assignee.display_name,
    task.assignee_profile_id=actor_profile,
    task.assignee_profile_id=actor_profile and task.status='open'
      and private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.planning.execute'),
    task.stable_place_id
  from public.stable_tasks task
  join public.profiles assignee on assignee.id=task.assignee_profile_id
  left join public.canonical_horses horse on horse.id=task.horse_id
  left join public.stable_places place on place.id=task.stable_place_id
  where task.organization_id=p_organization_id
    -- A date-only task occupies its calendar day, not a fabricated midnight.
    -- Day bounds are converted separately, including 23/25-hour DST days.
    and task.due_date::timestamp at time zone 'Europe/Amsterdam'<p_through
    and (task.due_date+1)::timestamp at time zone 'Europe/Amsterdam'>p_from
    and (task.due_time is null or (
      (task.due_date+task.due_time) at time zone 'Europe/Amsterdam'>=p_from
      and (task.due_date+task.due_time) at time zone 'Europe/Amsterdam'<p_through
    ))
    and(p_scope='all' or task.assignee_profile_id=actor_profile)
    and(task.horse_id is null or private.c003c_profile_has_horse_permission(actor_profile,task.horse_id,'horse.view'))
  union all
  select 'horse_activity'::text,item.id,item.title,item.instruction,item.item_kind,
    item.scheduled_start_at,(item.scheduled_start_at at time zone 'Europe/Amsterdam')::date,
    (item.scheduled_start_at at time zone 'Europe/Amsterdam')::time,item.state,
    item.row_version,horse.id,horse.display_name,null::text,null::uuid,
    coalesce((select pg_catalog.string_agg(profile.display_name,', ' order by profile.display_name)
      from public.schedule_item_participants participant join public.profiles profile on profile.id=participant.profile_id
      where participant.schedule_item_id=item.id and participant.status='active'),'')::text,
    exists(select 1 from public.schedule_item_participants participant where participant.schedule_item_id=item.id
      and participant.profile_id=actor_profile and participant.status='active'),false,null::uuid
  from public.horse_residencies residency
  join public.canonical_horses horse on horse.id=residency.horse_id
  join public.schedule_items item on item.horse_id=horse.id
  where residency.stable_organization_id=p_organization_id and residency.status='active'
    and item.scheduled_start_at<p_through
    and (item.scheduled_start_at>=p_from or item.scheduled_end_at>p_from)
    and private.c003c_profile_has_horse_permission(actor_profile,horse.id,'horse.view')
    and(p_scope='all' or exists(select 1 from public.schedule_item_participants participant
      where participant.schedule_item_id=item.id and participant.profile_id=actor_profile and participant.status='active'))
  order by 7,8 nulls last,2;
end;
$$;

create or replace function public.list_c010_personal_today(p_on_date date default null)
returns table(
  task_id uuid,organization_id uuid,organization_name text,title text,note text,
  category text,due_date date,due_time time,location_name text,horse_id uuid,
  horse_name text,row_version bigint,can_complete boolean
)
language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid; on_date date;
begin
  actor_profile:=private.c003b_actor_profile_id();
  on_date:=coalesce(p_on_date,(pg_catalog.statement_timestamp() at time zone 'Europe/Amsterdam')::date);
  return query
  select task.id,organization.id,organization.name,task.title,task.note,task.category,
    task.due_date,task.due_time,coalesce(place.label,task.location_text),task.horse_id,
    horse.display_name,task.row_version,
    private.c003b_profile_has_permission(actor_profile,organization.id,'organization.planning.execute')
  from public.stable_tasks task
  join public.organizations organization on organization.id=task.organization_id and organization.status='active'
  join public.organization_memberships membership on membership.organization_id=task.organization_id
    and membership.profile_id=actor_profile and membership.status='active'
    and membership.valid_from<=pg_catalog.statement_timestamp()
    and(membership.valid_until is null or membership.valid_until>pg_catalog.statement_timestamp())
  left join public.stable_places place on place.id=task.stable_place_id
  left join public.canonical_horses horse on horse.id=task.horse_id
  where task.assignee_profile_id=actor_profile and task.due_date=on_date and task.status='open'
    and private.c003b_profile_has_permission(actor_profile,organization.id,'organization.planning.view')
    and(task.horse_id is null or private.c003c_profile_has_horse_permission(actor_profile,task.horse_id,'horse.view'))
  order by pg_catalog.lower(organization.name),task.due_time nulls last,task.id;
end;
$$;

create or replace function public.get_c010_stable_round1_workspace(
  p_organization_id uuid,p_on_date date default null,p_scope text default 'all'
)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid; can_edit boolean; can_team boolean; result jsonb; on_date date; calendar jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  calendar:=public.get_c010_calendar_context();
  on_date:=coalesce(p_on_date,(calendar->>'today_date')::date);
  if not private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.view') then
    raise exception using errcode='42501',message='ORGANIZATION_PERMISSION_REQUIRED'; end if;
  can_edit:=private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.edit');
  can_team:=private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.memberships.view');
  select pg_catalog.jsonb_build_object(
    'facilities',coalesce((select pg_catalog.to_jsonb(facility)-'created_by_profile_id'
      from public.stable_facilities facility where facility.organization_id=p_organization_id),'{}'::jsonb),
    'places',coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',place.id,'ordinal',place.ordinal,'label',place.label,'status',place.status,'row_version',place.row_version
    ) order by place.ordinal) from public.stable_places place
      where place.organization_id=p_organization_id and place.status='active'),'[]'::jsonb),
    'resources',coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',resource.id,'category',resource.category,'brand',resource.brand,
      'product_name',resource.product_name,'row_version',resource.row_version
    ) order by resource.category,pg_catalog.lower(resource.brand),pg_catalog.lower(resource.product_name))
      from public.stable_resource_items resource where resource.organization_id=p_organization_id
        and resource.status='active'),'[]'::jsonb),
    'activities',coalesce((select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(activity) order by activity.due_date,activity.due_time nulls last,activity.activity_id)
      from public.list_c010_stable_activities(
        p_organization_id,on_date::timestamp at time zone 'Europe/Amsterdam',
        (on_date+1)::timestamp at time zone 'Europe/Amsterdam',p_scope
      ) activity),'[]'::jsonb),
    'task_candidates',case when can_team then coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'profile_id',membership.profile_id,'display_name',profile.display_name
    ) order by pg_catalog.lower(profile.display_name),membership.profile_id)
      from public.organization_memberships membership join public.profiles profile on profile.id=membership.profile_id
      where membership.organization_id=p_organization_id and membership.status='active'
        and membership.valid_from<=pg_catalog.statement_timestamp()
        and(membership.valid_until is null or membership.valid_until>pg_catalog.statement_timestamp())
        and profile.status='active'),'[]'::jsonb) else '[]'::jsonb end,
    'can_edit_facilities',can_edit,
    'can_manage_tasks',can_team and private.c003b_profile_has_permission(
      actor_profile,p_organization_id,'organization.planning.execute'),
    'can_retire',can_edit and exists(select 1 from public.organizations organization
      where organization.id=p_organization_id and organization.primary_admin_profile_id=actor_profile)
  ) into result;
  return result||calendar||pg_catalog.jsonb_build_object('on_date',on_date);
end;
$$;

commit;
