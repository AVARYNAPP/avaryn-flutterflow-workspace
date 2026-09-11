begin;

-- C010 account calendar: verified active profile timezone, no caller actor/zone.
-- Date-only tasks and facility reservations remain civil values. Existing
-- absolute training instants, stored dates, CAS, receipts and ACLs are unchanged.
create function private.c010_actor_time_zone() returns text
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.c003b_actor_profile_id(); zone_name text;
begin
 select p.time_zone into zone_name from public.profiles p where p.id=actor and p.status='active';
 if zone_name is null or not private.c003a_is_valid_iana_time_zone(zone_name) then
  raise exception using errcode='22023',message='ACCOUNT_TIME_ZONE_INVALID';
 end if;
 return zone_name;
end;$$;
revoke all on function private.c010_actor_time_zone() from public,anon,authenticated,service_role;


create or replace function public.get_c010_calendar_context()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare account_zone text:=private.c010_actor_time_zone(); now_at timestamptz:=pg_catalog.statement_timestamp(); today date;
begin
  perform private.c003b_actor_profile_id();
  today:=(now_at at time zone account_zone)::date;
  return pg_catalog.jsonb_build_object(
    'today_date',today,'time_zone',account_zone,'server_now',now_at,
    'next_day_at',(today+1)::timestamp at time zone account_zone
  );
end;
$$;

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
declare account_zone text:=private.c010_actor_time_zone(); actor_profile uuid;
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
      then (task.due_date+task.due_time) at time zone account_zone end,
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
    and (task.due_date is null or (
      task.due_date::timestamp at time zone account_zone<p_through
      and (task.due_date+1)::timestamp at time zone account_zone>p_from
      and (task.due_time is null or (
        (task.due_date+task.due_time) at time zone account_zone>=p_from
        and (task.due_date+task.due_time) at time zone account_zone<p_through
      ))
    ))
    and(p_scope='all' or task.assignee_profile_id=actor_profile)
    and(task.horse_id is null or private.c003c_profile_has_horse_permission(actor_profile,task.horse_id,'horse.view'))
  union all
  select 'horse_activity'::text,item.id,item.title,item.instruction,item.item_kind,
    item.scheduled_start_at,(item.scheduled_start_at at time zone account_zone)::date,
    (item.scheduled_start_at at time zone account_zone)::time,item.state,
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

create or replace function public.get_c010_personal_day(p_on_date date default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare account_zone text:=private.c010_actor_time_zone(); actor_profile uuid; on_date date; calendar jsonb;
  day_start timestamptz; day_end timestamptz; items jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  calendar:=public.get_c010_calendar_context();
  on_date:=coalesce(p_on_date,(calendar->>'today_date')::date);
  if not pg_catalog.isfinite(on_date) then
    raise exception using errcode='22023',message='C010_PERSONAL_DAY_INVALID';
  end if;
  day_start:=on_date::timestamp at time zone account_zone;
  day_end:=(on_date+1)::timestamp at time zone account_zone;

  select coalesce(pg_catalog.jsonb_agg(source.item order by source.sort_at nulls last,
    source.source_type,source.source_id),'[]'::jsonb) into items
  from (
    select 'stable_task'::text source_type,task.id source_id,
      case when task.due_time is not null
        then (task.due_date+task.due_time) at time zone account_zone end sort_at,
      pg_catalog.jsonb_build_object(
        'source_type','stable_task','source_id',task.id,'task_id',task.id,
        'schedule_item_id',null,'organization_id',organization.id,
        'organization_name',organization.name,'horse_id',task.horse_id,
        'horse_name',horse.display_name,'title',task.title,'instruction',task.note,
        'item_kind',task.category,'location_name',coalesce(place.label,task.location_text),
        'due_date',task.due_date,'due_time',task.due_time,
        'scheduled_start_at',null,'scheduled_end_at',null,
        'status',task.status,'row_version',task.row_version,
        'can_complete',task.status='open' and private.c003b_profile_has_permission(
          actor_profile,task.organization_id,'organization.planning.execute')
      ) item
    from public.stable_tasks task
    join public.organizations organization on organization.id=task.organization_id
      and organization.status='active'
    left join public.canonical_horses horse on horse.id=task.horse_id
    left join public.stable_places place on place.id=task.stable_place_id
    where task.assignee_profile_id=actor_profile
      and (task.due_date=on_date or (task.due_date is null and task.status='open'))
      and exists(select 1 from public.organization_memberships membership
        where membership.organization_id=task.organization_id
          and membership.profile_id=actor_profile and membership.status='active'
          and membership.valid_from<=pg_catalog.statement_timestamp()
          and (membership.valid_until is null or membership.valid_until>pg_catalog.statement_timestamp()))
      and private.c003b_profile_has_permission(
        actor_profile,task.organization_id,'organization.planning.view')
      and (task.horse_id is null or private.c003c_profile_has_horse_permission(
        actor_profile,task.horse_id,'horse.view',pg_catalog.statement_timestamp()))
    union all
    select 'horse_activity'::text,item.id,item.scheduled_start_at,
      pg_catalog.jsonb_build_object(
        'source_type','horse_activity','source_id',item.id,'task_id',null,
        'schedule_item_id',item.id,'organization_id',context.id,
        'organization_name',context.name,'horse_id',horse.id,
        'horse_name',horse.display_name,'title',item.title,'instruction',item.instruction,
        'item_kind',item.item_kind,'location_name',null,
        'due_date',(item.scheduled_start_at at time zone account_zone)::date,
        'due_time',(item.scheduled_start_at at time zone account_zone)::time,
        'scheduled_start_at',item.scheduled_start_at,'scheduled_end_at',item.scheduled_end_at,
        'source_timezone',item.source_timezone,'priority',item.priority,
        'status',item.state,'row_version',item.row_version,
        'can_complete',item.state in ('planned','in_progress') and (
          private.c003c_profile_has_horse_permission(actor_profile,horse.id,'horse.edit',pg_catalog.statement_timestamp())
          or private.c003c_profile_has_horse_permission(actor_profile,horse.id,'horse.planning.manage',pg_catalog.statement_timestamp()))
      )
    from public.schedule_items item
    join public.canonical_horses horse on horse.id=item.horse_id
    -- A readable residency is optional context, never an assignment or access
    -- grant. A lateral limit prevents multiple contexts duplicating one item.
    left join lateral (
      select organization.id,organization.name
      from public.horse_residencies residency
      join public.organizations organization on organization.id=residency.stable_organization_id
        and organization.status='active'
      where residency.horse_id=item.horse_id and residency.status='active'
        and residency.valid_from<=pg_catalog.statement_timestamp()
        and (residency.valid_until is null or residency.valid_until>pg_catalog.statement_timestamp())
        and private.c003b_profile_has_permission(actor_profile,organization.id,'organization.view')
      order by organization.id limit 1
    ) context on true
    where exists(select 1 from public.schedule_item_participants participant
      where participant.schedule_item_id=item.id and participant.profile_id=actor_profile
        and participant.status='active' and participant.valid_from<=pg_catalog.statement_timestamp()
        and (participant.valid_until is null or participant.valid_until>pg_catalog.statement_timestamp()))
      and private.c003c_profile_has_horse_permission(
        actor_profile,item.horse_id,'horse.view',pg_catalog.statement_timestamp())
      and item.scheduled_start_at<day_end
      and (item.scheduled_start_at>=day_start or item.scheduled_end_at>day_start)
  ) source;
  return pg_catalog.jsonb_build_object(
    'calendar',calendar,'on_date',on_date,'time_zone',account_zone,
    'day_start_at',day_start,'day_end_at',day_end,'items',items
  );
end;
$$;

create or replace function public.list_c010_personal_today(p_on_date date default null)
returns table(
  task_id uuid,organization_id uuid,organization_name text,title text,note text,
  category text,due_date date,due_time time,location_name text,horse_id uuid,
  horse_name text,row_version bigint,can_complete boolean
)
language plpgsql stable security definer set search_path='' as $$
declare account_zone text:=private.c010_actor_time_zone(); actor_profile uuid; on_date date;
begin
  actor_profile:=private.c003b_actor_profile_id();
  on_date:=coalesce(p_on_date,(pg_catalog.statement_timestamp() at time zone account_zone)::date);
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
declare account_zone text:=private.c010_actor_time_zone(); actor_profile uuid; can_edit boolean; can_team boolean; result jsonb; on_date date; calendar jsonb;
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
        p_organization_id,on_date::timestamp at time zone account_zone,
        (on_date+1)::timestamp at time zone account_zone,p_scope
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

create or replace function public.configure_c010_facilities(p_organization_id uuid,p_expected_row_version bigint,p_counts jsonb,p_walker_capacity integer,p_has_tack_room boolean,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare account_zone text:=private.c010_actor_time_zone(); actor uuid:=private.c010p2_context(p_organization_id,true);current_version bigint;payload jsonb;replay jsonb;r jsonb;resource_kind text;n integer;i integer;label text;booking record;
begin
 if not private.c010p2_manage(actor,p_organization_id) then raise exception using errcode='42501',message='C010_FACILITY_MANAGE_REQUIRED';end if;
 if p_counts is null or jsonb_typeof(p_counts)<>'object' or (select count(*) from jsonb_object_keys(p_counts))<>7
 or p_walker_capacity not between 1 and 20 or p_walker_capacity is null or p_has_tack_room is null then
  raise exception using errcode='22023',message='C010_FACILITY_COUNTS_INVALID';end if;
 foreach resource_kind in array array['stall','pasture','paddock','arena','walker','wash','locker'] loop
  if coalesce(p_counts->>resource_kind,'')!~'^[0-9]{1,2}$' or (p_counts->>resource_kind)::integer>50 then raise exception using errcode='22023',message='C010_FACILITY_COUNTS_INVALID';end if;
 end loop;
 if not p_has_tack_room and (p_counts->>'locker')::integer>0 then raise exception using errcode='22023',message='C010_TACK_ROOM_REQUIRED';end if;
 payload:=jsonb_build_object('org',p_organization_id,'expected',p_expected_row_version,'counts',p_counts,'walker_capacity',p_walker_capacity,'tack_room',p_has_tack_room);
 replay:=private.c010p2_receipt(actor,p_request_id,'configure',payload);if replay is not null then return replay;end if;
 select row_version into current_version from public.stable_facilities where organization_id=p_organization_id for update;
 if current_version is distinct from p_expected_row_version then raise exception using errcode='PT409',message='C010_FACILITY_VERSION_STALE';end if;
 if exists(select 1 from public.c010_facility_units u join public.c010_facility_bookings b on b.resource_id=u.id
 where u.organization_id=p_organization_id and u.ordinal>(p_counts->>u.kind)::integer)
 or exists(select 1 from public.c010_horse_places hp join public.stable_places sp on sp.id=hp.stable_place_id
 where hp.organization_id=p_organization_id and hp.status='active' and private.c010p2_placement_live(hp.horse_id,hp.organization_id) and sp.ordinal>(p_counts->>'stall')::integer) then
  raise exception using errcode='PT409',message='C010_FACILITY_HAS_HISTORY';end if;
 r:=public.update_c010_stable_facilities(p_organization_id,p_expected_row_version,(p_counts->>'stall')::integer,
 (p_counts->>'pasture')::integer,(p_counts->>'paddock')::integer,(p_counts->>'wash')::integer,(p_counts->>'walker')::integer>0,
 (p_counts->>'walker')::integer,case when (p_counts->>'walker')::integer>0 then p_walker_capacity else 0 end,p_has_tack_room,(p_counts->>'locker')::integer,p_request_id);
 update public.stable_facilities set arena_count=(p_counts->>'arena')::integer where organization_id=p_organization_id;
 foreach resource_kind in array array['pasture','paddock','arena','walker','wash','locker'] loop
  n:=(p_counts->>resource_kind)::integer;
  label:=case resource_kind when 'pasture' then 'Weide' when 'paddock' then 'Paddock' when 'arena' then 'Rijbak' when 'walker' then 'Stapmolen' when 'wash' then 'Wasplaats' else 'Kast' end;
  if n>0 then for i in 1..n loop
   insert into public.c010_facility_units(organization_id,kind,ordinal,name,unit_type,capacity,created_by_profile_id)
   values(p_organization_id,resource_kind,i,label||' '||i,case when resource_kind='arena' then 'Binnenbak' else '' end,
    case resource_kind when 'arena' then 4 when 'pasture' then 6 when 'paddock' then 2 when 'walker' then p_walker_capacity else 1 end,actor)
   on conflict(organization_id,kind,ordinal) do update set status=case when public.c010_facility_units.status='archived' then 'available' else public.c010_facility_units.status end,
    capacity=case when excluded.kind='walker' then excluded.capacity else public.c010_facility_units.capacity end,
    row_version=public.c010_facility_units.row_version+1,updated_at=clock_timestamp();
  end loop;end if;
  update public.c010_facility_units set status='archived',row_version=row_version+1,updated_at=clock_timestamp()
  where organization_id=p_organization_id and c010_facility_units.kind=resource_kind and ordinal>n and status<>'archived';
 end loop;
 for booking in select b.* from public.c010_facility_bookings b join public.c010_facility_units u on u.id=b.resource_id
 where u.organization_id=p_organization_id and u.kind='walker' and u.status<>'archived' and b.status in('approved','requested')
 and b.booking_date>=(statement_timestamp() at time zone account_zone)::date loop
  if booking.participants>p_walker_capacity then raise exception using errcode='PT409',message='C010_FACILITY_CAPACITY_CONFLICT';end if;
  if booking.status='approved' then perform private.c010p2_capacity(booking.resource_id,booking.booking_date,booking.start_time,booking.end_time,booking.participants,booking.exclusive,booking.id);end if;
 end loop;
 return private.c010p2_finish(actor,p_organization_id,p_request_id,'configure',payload,jsonb_build_object('organization_id',p_organization_id,'row_version',(r->>'row_version')::bigint));
end;$$;

create or replace function public.update_c010_facility_unit(p_organization_id uuid,p_resource_id uuid,p_expected_row_version bigint,p_name text,p_type text,p_status text,p_capacity integer,p_note text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare account_zone text:=private.c010_actor_time_zone(); actor uuid:=private.c010p2_context(p_organization_id,true);u public.c010_facility_units%rowtype;sp public.stable_places%rowtype;payload jsonb;replay jsonb;b record;new_version bigint;
begin
 if not private.c010p2_manage(actor,p_organization_id) then raise exception using errcode='42501',message='C010_FACILITY_MANAGE_REQUIRED';end if;
 if length(btrim(coalesce(p_name,''))) not between 1 and 80 or p_capacity is null or p_capacity not between 1 and 50
 or p_status is null or p_status not in('available','occupied','maintenance','reserved','rest') or length(coalesce(p_note,''))>2000 or length(coalesce(p_type,''))>80 then
  raise exception using errcode='22023',message='C010_FACILITY_INPUT_INVALID';end if;
 select * into u from public.c010_facility_units where id=p_resource_id and organization_id=p_organization_id and status<>'archived' for update;
 if u.id is null then select * into sp from public.stable_places where id=p_resource_id and organization_id=p_organization_id and status='active' for update;end if;
 if u.id is null and sp.id is null then raise exception using errcode='42501',message='C010_FACILITY_UNAVAILABLE';end if;
 payload:=jsonb_build_object('org',p_organization_id,'id',p_resource_id,'expected',p_expected_row_version,'name',p_name,'type',p_type,'status',p_status,'capacity',p_capacity,'note',p_note);
 replay:=private.c010p2_receipt(actor,p_request_id,'resource',payload);if replay is not null then return replay;end if;
 if coalesce(u.row_version,sp.row_version) is distinct from p_expected_row_version then raise exception using errcode='PT409',message='C010_FACILITY_VERSION_STALE';end if;
 if p_status<>'available' and ((u.id is not null and exists(select 1 from public.c010_facility_bookings where resource_id=u.id and status in('approved','requested') and booking_date>=(statement_timestamp() at time zone account_zone)::date)) or (sp.id is not null and exists(select 1 from public.c010_horse_places where stable_place_id=sp.id and status='active'))) then
  raise exception using errcode='PT409',message='C010_FACILITY_HAS_PLANNING';end if;
 if sp.id is not null then
  if p_capacity<>1 then raise exception using errcode='22023',message='C010_BOX_CAPACITY_ONE';end if;
  update public.stable_places set label=btrim(p_name),place_type=coalesce(p_type,''),operating_status=p_status,note=coalesce(p_note,''),row_version=row_version+1,updated_at=clock_timestamp() where id=sp.id returning row_version into new_version;
 else
  update public.c010_facility_units set name=btrim(p_name),unit_type=coalesce(p_type,''),status=p_status,capacity=p_capacity,note=coalesce(p_note,''),row_version=row_version+1,updated_at=clock_timestamp()
   where id=u.id returning row_version into new_version;
  for b in select * from public.c010_facility_bookings where resource_id=u.id and status in('approved','requested')
   and booking_date>=(statement_timestamp() at time zone account_zone)::date loop
   if b.participants>p_capacity then raise exception using errcode='PT409',message='C010_FACILITY_CAPACITY_CONFLICT';end if;
   if b.status='approved' then perform private.c010p2_capacity(u.id,b.booking_date,b.start_time,b.end_time,b.participants,b.exclusive,b.id);end if;
  end loop;
 end if;
 return private.c010p2_finish(actor,p_organization_id,p_request_id,'resource',payload,jsonb_build_object('resource_id',p_resource_id,'row_version',new_version));
end;$$;

create or replace function public.save_c010_facility_booking(p_organization_id uuid,p_booking_id uuid,p_expected_row_version bigint,p_resource_id uuid,p_date date,p_start time,p_end time,p_horse_ids uuid[],p_participants integer,p_activity text,p_note text,p_exclusive boolean,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare account_zone text:=private.c010_actor_time_zone(); actor uuid:=private.c010p2_context(p_organization_id,true);manager boolean:=private.c010p2_manage(actor,p_organization_id);u public.c010_facility_units%rowtype;
 old public.c010_facility_bookings%rowtype;after_row public.c010_facility_bookings%rowtype;payload jsonb;replay jsonb;horses uuid[];h uuid;next_status text;today date:=(statement_timestamp() at time zone account_zone)::date;
begin
 if not private.c010p2_book(actor,p_organization_id) then raise exception using errcode='42501',message='C010_FACILITY_BOOK_REQUIRED';end if;
 select * into u from public.c010_facility_units where id=p_resource_id and organization_id=p_organization_id and status='available' for update;
 if u.id is null or u.kind='locker' then raise exception using errcode='42501',message='C010_FACILITY_UNAVAILABLE';end if;
 if u.kind<>'arena' and not manager then raise exception using errcode='42501',message='C010_FACILITY_MANAGE_REQUIRED';end if;
 select coalesce(array_agg(distinct value order by value),'{}'::uuid[]) into horses from unnest(coalesce(p_horse_ids,'{}'::uuid[])) value;
 if p_date is null or not isfinite(p_date) or p_date<today or p_date>today+366 or p_start is null or p_end is null or p_start>=p_end or p_start='24:00'::time or p_end='24:00'::time
 or not private.c010p2_civil_time(p_date,p_start) or not private.c010p2_civil_time(p_date,p_end)
 or p_participants is null or p_participants not between 1 and u.capacity or p_exclusive is null
 or (u.kind='arena' and cardinality(horses)>1) or (u.kind<>'arena' and (cardinality(horses)=0 or p_participants<>cardinality(horses) or p_exclusive))
 or cardinality(horses)<>cardinality(coalesce(p_horse_ids,'{}'::uuid[])) or array_position(horses,null) is not null
 or length(coalesce(p_activity,''))>180 or length(coalesce(p_note,''))>2000 or (p_exclusive and length(btrim(coalesce(p_note,'')))=0) then
  raise exception using errcode='22023',message='C010_BOOKING_INPUT_INVALID';end if;
 -- Lock actual horses before checking current residency and explicit permissions.
 foreach h in array horses loop
  perform 1 from public.canonical_horses where id=h for update;
  if not private.c010p2_horse(actor,p_organization_id,h,u.kind='arena' and not manager) then raise exception using errcode='42501',message='C010_HORSE_CONTEXT_REQUIRED';end if;
 end loop;
 if p_booking_id is not null then
  select * into old from public.c010_facility_bookings where id=p_booking_id and organization_id=p_organization_id for update;
  if old.id is null or (not manager and old.requester_profile_id<>actor) then raise exception using errcode='42501',message='C010_BOOKING_UNAVAILABLE';end if;
 end if;
 payload:=jsonb_build_object('org',p_organization_id,'id',p_booking_id,'expected',p_expected_row_version,'resource',p_resource_id,'date',p_date,'start',p_start,'end',p_end,'horses',horses,'participants',p_participants,'activity',p_activity,'note',p_note,'exclusive',p_exclusive);
 replay:=private.c010p2_receipt(actor,p_request_id,'booking',payload);if replay is not null then return replay;end if;
 if old.row_version is distinct from p_expected_row_version then raise exception using errcode='PT409',message='C010_BOOKING_VERSION_STALE';end if;
 if old.id is not null and old.status not in('approved','requested') then raise exception using errcode='PT409',message='C010_BOOKING_TERMINAL';end if;
 -- Every exclusive edit requires a fresh decision; manager action is explicit.
 next_status:=case when p_exclusive then 'requested' else 'approved' end;
 if next_status='approved' then perform private.c010p2_capacity(u.id,p_date,p_start,p_end,p_participants,false,p_booking_id);end if;
 if next_status='approved' and exists(select 1 from public.c010_facility_bookings b join public.c010_facility_booking_horses bh on bh.booking_id=b.id
 where b.id is distinct from p_booking_id and b.organization_id=p_organization_id and b.booking_date=p_date and b.status='approved'
 and b.start_time<p_end and b.end_time>p_start and bh.horse_id=any(horses)) then raise exception using errcode='PT409',message='C010_HORSE_LOCATION_CONFLICT';end if;
 if old.id is null then
  insert into public.c010_facility_bookings(organization_id,resource_id,requester_profile_id,booking_date,start_time,end_time,participants,exclusive,activity,note,status)
  values(p_organization_id,u.id,actor,p_date,p_start,p_end,p_participants,p_exclusive,coalesce(p_activity,''),coalesce(p_note,''),next_status) returning * into after_row;
 else
  update public.c010_facility_bookings set resource_id=u.id,booking_date=p_date,start_time=p_start,end_time=p_end,participants=p_participants,exclusive=p_exclusive,
  activity=coalesce(p_activity,''),note=coalesce(p_note,''),status=next_status,decision_note='',decided_by_profile_id=null,row_version=row_version+1,updated_at=clock_timestamp()
  where id=old.id returning * into after_row;
  delete from public.c010_facility_booking_horses where booking_id=old.id;
 end if;
 insert into public.c010_facility_booking_horses(booking_id,horse_id) select after_row.id,value from unnest(horses) value;
 return private.c010p2_finish(actor,p_organization_id,p_request_id,'booking',payload,jsonb_build_object('booking_id',after_row.id,'row_version',after_row.row_version,'status',after_row.status));
end;$$;

create or replace function public.get_c010_facility_workspace(p_organization_id uuid,p_on_date date default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare account_zone text:=private.c010_actor_time_zone(); actor uuid:=private.c010p2_context(p_organization_id,false);manager boolean:=private.c010p2_manage(actor,p_organization_id);book boolean:=private.c010p2_book(actor,p_organization_id);
 today date:=(statement_timestamp() at time zone account_zone)::date;selected date:=coalesce(p_on_date,today);f public.stable_facilities%rowtype;resources jsonb;places jsonb;versions jsonb;bookings jsonb;arenas jsonb;
begin
 if not isfinite(selected) or selected<today-366 or selected>today+366 then raise exception using errcode='22023',message='C010_FACILITY_DAY_INVALID';end if;
 select * into f from public.stable_facilities where organization_id=p_organization_id;
 select coalesce(jsonb_agg(value order by kind,ordinal),'[]') into resources from(
  select 'stall'::text kind,sp.ordinal,jsonb_build_object('id',sp.id,'kind','stall','number',sp.ordinal,'name',sp.label,'type',sp.place_type,'status',sp.operating_status,'capacity',1,'note',sp.note,'rowVersion',sp.row_version,'occupied',exists(select 1 from public.c010_horse_places hp where hp.stable_place_id=sp.id and hp.status='active' and private.c010p2_placement_live(hp.horse_id,hp.organization_id))) value
  from public.stable_places sp where sp.organization_id=p_organization_id and sp.status='active'
  union all select u.kind,u.ordinal,jsonb_build_object('id',u.id,'kind',u.kind,'number',u.ordinal,'name',u.name,'type',u.unit_type,'status',u.status,'capacity',u.capacity,'note',u.note,'rowVersion',u.row_version)
  from public.c010_facility_units u where u.organization_id=p_organization_id and u.status<>'archived'
 ) source;
 select coalesce(jsonb_agg(jsonb_build_object('resourceId',hp.stable_place_id,
 'horseId',case when private.c003c_profile_has_horse_permission(actor,hp.horse_id,'horse.view') then hp.horse_id end,
 'note',case when private.c003c_profile_has_horse_permission(actor,hp.horse_id,'horse.view') then hp.note else '' end,
 'rowVersion',case when private.c003c_profile_has_horse_permission(actor,hp.horse_id,'horse.view') then hp.row_version end,
 'redacted',not private.c003c_profile_has_horse_permission(actor,hp.horse_id,'horse.view')))
 filter(where hp.status='active' and private.c010p2_placement_live(hp.horse_id,hp.organization_id)),'[]'),
 coalesce(jsonb_object_agg(hp.horse_id,hp.row_version) filter(where private.c003c_profile_has_horse_permission(actor,hp.horse_id,'horse.view')),'{}')
 into places,versions from public.c010_horse_places hp where hp.organization_id=p_organization_id;
 with projected as(
 select b.*,u.kind,hs.ids,hs.visible_ids,
 (b.requester_profile_id=actor or manager) as private_details,
 (b.requester_profile_id=actor or manager or (hs.total>0 and hs.total=hs.visible_count)) as visible_activity,
 case when p.status='active' then p.display_name else 'Niet-actief account' end requester_name
 from public.c010_facility_bookings b join public.c010_facility_units u on u.id=b.resource_id
 join public.profiles p on p.id=b.requester_profile_id
 cross join lateral(select coalesce(array_agg(bh.horse_id order by bh.horse_id),'{}'::uuid[]) ids,
  coalesce(array_agg(bh.horse_id order by bh.horse_id) filter(where private.c003c_profile_has_horse_permission(actor,bh.horse_id,'horse.view')),'{}'::uuid[]) visible_ids,
  count(*) total,count(*) filter(where private.c003c_profile_has_horse_permission(actor,bh.horse_id,'horse.view')) visible_count
  from public.c010_facility_booking_horses bh where bh.booking_id=b.id) hs
 where b.organization_id=p_organization_id and (b.status='approved' or b.requester_profile_id=actor or manager)
 and (b.booking_date in(selected,today) or (b.status='requested' and b.booking_date between today and today+366))
 ), vals as(select kind,jsonb_build_object('id',id,'resourceId',resource_id,'date',booking_date,'start',to_char(start_time,'HH24:MI'),'end',to_char(end_time,'HH24:MI'),
 'horseIds',visible_ids,'horseId',case when cardinality(visible_ids)=1 then visible_ids[1] end,'participants',participants,'exclusive',exclusive,
 'activity',case when visible_activity then activity else '' end,'note',case when private_details then note else '' end,'status',status,'decisionNote',case when private_details then decision_note else '' end,
 'requesterId',case when private_details then requester_profile_id end,'requesterName',case when private_details then requester_name else '' end,'rowVersion',row_version,
 'canEdit',status in('approved','requested') and (manager or (kind='arena' and requester_profile_id=actor and book)),
 'canCancel',status in('approved','requested') and (manager or (kind='arena' and requester_profile_id=actor and book)),
 'canDecide',status='requested' and manager,'redacted',not private_details) value from projected)
 select coalesce(jsonb_agg(value) filter(where kind<>'arena'),'[]'),coalesce(jsonb_agg(value) filter(where kind='arena'),'[]') into bookings,arenas from vals;
 return jsonb_build_object('organization_id',p_organization_id,'profile_id',actor,'on_date',selected,
 'calendar',jsonb_build_object('today_date',today,'time_zone',account_zone,'selected_date',selected,'covered_dates',array[ today,selected ],'pending_from',today,'pending_through',today+366),
 'configuration',jsonb_build_object('row_version',f.row_version,'counts',jsonb_build_object('stall',coalesce(f.box_count,0),'pasture',coalesce(f.pasture_count,0),'paddock',coalesce(f.paddock_count,0),'arena',coalesce(f.arena_count,0),'walker',coalesce(f.walker_count,0),'wash',coalesce(f.wash_bay_count,0),'locker',coalesce(f.tack_locker_count,0)),
 'walker_capacity',greatest(coalesce(f.walker_places_per_unit,0),1),'tack_room',coalesce(f.has_tack_room,false)),
 'resources',resources,'placements',places,'placementVersions',versions,'bookings',bookings,'arenaBookings',arenas,'capabilities',jsonb_build_object('manage',manager,'book',book));
end;$$;

comment on function public.get_c010_my_vitality_day(date) is 'Actorless day in the verified account timezone. Missing day has row_version 0; a deleted day retains its version.';
notify pgrst,'reload schema';
commit;
