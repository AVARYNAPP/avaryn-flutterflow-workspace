begin;

-- C010 task timing: an undated todo has neither a calendar date nor a time.
-- Preserve all current authorization, CAS, receipts, event history and APIs.
-- Existing task dates/times are untouched; no fabricated date or midnight.
alter table public.stable_tasks alter column due_date drop not null;
alter table public.stable_tasks add constraint stable_tasks_time_requires_date
  check(due_date is not null or due_time is null);

create or replace function public.upsert_c010_stable_task(
  p_organization_id uuid,p_task_id uuid,p_expected_row_version bigint,p_title text,p_note text,
  p_category text,p_due_date date,p_due_time time,p_assignee_profile_id uuid,p_location_text text,
  p_stable_place_id uuid,p_horse_id uuid,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea; replay jsonb;
  before_row public.stable_tasks%rowtype; after_row public.stable_tasks%rowtype; result jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if not(private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.planning.view')
    and private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.planning.execute')
    and private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.memberships.view'))
  then raise exception using errcode='42501',message='STABLE_TASK_MANAGE_PERMISSION_REQUIRED'; end if;
  if p_request_id is null or pg_catalog.length(pg_catalog.btrim(coalesce(p_title,''))) not between 1 and 180
    or p_category not in('feeding','hay','water','pasture','stable_preparation','other') or (p_due_date is null and p_due_time is not null)
    or not private.c010_round1_active_member(p_assignee_profile_id,p_organization_id)
  then raise exception using errcode='22023',message='C010_TASK_INPUT_INVALID'; end if;
  if p_stable_place_id is not null and not exists(
    select 1 from public.stable_places place where place.id=p_stable_place_id
      and place.organization_id=p_organization_id and place.status='active'
  ) then raise exception using errcode='42501',message='CROSS_STABLE_PLACE_DENIED'; end if;
  if p_horse_id is not null and not(
    exists(select 1 from public.horse_residencies residency where residency.horse_id=p_horse_id
      and residency.stable_organization_id=p_organization_id and residency.status='active')
    and private.c003c_profile_has_horse_permission(actor_profile,p_horse_id,'horse.view')
    and private.c003c_profile_has_horse_permission(p_assignee_profile_id,p_horse_id,'horse.view')
  ) then raise exception using errcode='42501',message='CROSS_STABLE_HORSE_DENIED'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'task_id',p_task_id,'expected',p_expected_row_version,
    'title',pg_catalog.btrim(p_title),'note',nullif(pg_catalog.btrim(p_note),''),'category',p_category,
    'due_date',p_due_date,'due_time',p_due_time,'assignee',p_assignee_profile_id,
    'location',nullif(pg_catalog.btrim(p_location_text),''),'place',p_stable_place_id,'horse',p_horse_id
  ));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('c010:tasks:'||p_organization_id::text,0));
  -- The old horse link is part of authorization even if the requested new link
  -- is NULL. A known id cannot turn an unreadable task into a readable one.
  if p_task_id is not null then
    select * into before_row from public.stable_tasks value
      where value.id=p_task_id and value.organization_id=p_organization_id for update;
    if before_row.id is null then raise exception using errcode='42501',message='CROSS_STABLE_TASK_DENIED'; end if;
    if before_row.horse_id is not null and not private.c003c_profile_has_horse_permission(
      actor_profile,before_row.horse_id,'horse.view')
    then raise exception using errcode='42501',message='TASK_VISIBILITY_PERMISSION_REQUIRED'; end if;
  end if;
  replay:=private.c010_round1_receipt_result(actor_user,p_request_id,'upsert_task',payload_hash);
  if replay is not null then
    -- Creation receipts also refer to current rows; rights may have changed
    -- since the original request or a later edit may have linked a horse.
    if not exists(select 1 from public.stable_tasks value
      where value.id=(replay->>'task_id')::uuid and value.organization_id=p_organization_id
        and (value.horse_id is null or private.c003c_profile_has_horse_permission(
          actor_profile,value.horse_id,'horse.view')))
    then raise exception using errcode='42501',message='TASK_VISIBILITY_PERMISSION_REQUIRED'; end if;
    return replay;
  end if;
  if p_task_id is null then
    insert into public.stable_tasks(
      organization_id,title,note,category,due_date,due_time,assignee_profile_id,
      location_text,stable_place_id,horse_id,created_by_profile_id,creation_request_id
    ) values(
      p_organization_id,pg_catalog.btrim(p_title),nullif(pg_catalog.btrim(p_note),''),p_category,
      p_due_date,p_due_time,p_assignee_profile_id,nullif(pg_catalog.btrim(p_location_text),''),
      p_stable_place_id,p_horse_id,actor_profile,p_request_id
    ) returning * into after_row;
    perform private.c010_round1_log_task(after_row.id,p_organization_id,actor_profile,'created',p_request_id,
      null,after_row.row_version,null,after_row.status,pg_catalog.jsonb_build_object('category',after_row.category));
  else
    if before_row.status<>'open' or before_row.row_version<>p_expected_row_version then
      raise exception using errcode='PT409',message='STALE_TASK_VERSION'; end if;
    update public.stable_tasks value set title=pg_catalog.btrim(p_title),note=nullif(pg_catalog.btrim(p_note),''),
      category=p_category,due_date=p_due_date,due_time=p_due_time,assignee_profile_id=p_assignee_profile_id,
      location_text=nullif(pg_catalog.btrim(p_location_text),''),stable_place_id=p_stable_place_id,
      horse_id=p_horse_id,row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where value.id=p_task_id returning * into after_row;
    perform private.c010_round1_log_task(after_row.id,p_organization_id,actor_profile,'updated',p_request_id,
      before_row.row_version,after_row.row_version,before_row.status,after_row.status,
      pg_catalog.jsonb_build_object('category',after_row.category));
  end if;
  result:=pg_catalog.jsonb_build_object('task_id',after_row.id,'row_version',after_row.row_version,
    'status',after_row.status,'idempotent',false);
  insert into private.c010_round1_receipts(actor_user_id,request_id,operation_name,payload_hash,result)
  values(actor_user,p_request_id,'upsert_task',payload_hash,result);
  return result;
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
    and (task.due_date is null or (
      task.due_date::timestamp at time zone 'Europe/Amsterdam'<p_through
      and (task.due_date+1)::timestamp at time zone 'Europe/Amsterdam'>p_from
      and (task.due_time is null or (
        (task.due_date+task.due_time) at time zone 'Europe/Amsterdam'>=p_from
        and (task.due_date+task.due_time) at time zone 'Europe/Amsterdam'<p_through
      ))
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

create or replace function public.get_c010_personal_day(p_on_date date default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid; on_date date; calendar jsonb;
  day_start timestamptz; day_end timestamptz; items jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  calendar:=public.get_c010_calendar_context();
  on_date:=coalesce(p_on_date,(calendar->>'today_date')::date);
  if not pg_catalog.isfinite(on_date) then
    raise exception using errcode='22023',message='C010_PERSONAL_DAY_INVALID';
  end if;
  day_start:=on_date::timestamp at time zone 'Europe/Amsterdam';
  day_end:=(on_date+1)::timestamp at time zone 'Europe/Amsterdam';

  select coalesce(pg_catalog.jsonb_agg(source.item order by source.sort_at nulls last,
    source.source_type,source.source_id),'[]'::jsonb) into items
  from (
    select 'stable_task'::text source_type,task.id source_id,
      case when task.due_time is not null
        then (task.due_date+task.due_time) at time zone 'Europe/Amsterdam' end sort_at,
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
        'due_date',(item.scheduled_start_at at time zone 'Europe/Amsterdam')::date,
        'due_time',(item.scheduled_start_at at time zone 'Europe/Amsterdam')::time,
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
    'calendar',calendar,'on_date',on_date,'time_zone','Europe/Amsterdam',
    'day_start_at',day_start,'day_end_at',day_end,'items',items
  );
end;
$$;

notify pgrst,'reload schema';
commit;
