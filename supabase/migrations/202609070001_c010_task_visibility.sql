begin;

-- Align direct SELECT with C-010's existing organization/horse RPC boundary.
-- The existing PII-free organization helper checks active profile, organization,
-- membership, role and planning permission. An assignee receives no bypass.
drop policy stable_tasks_read on public.stable_tasks;
create policy stable_tasks_read on public.stable_tasks
for select to authenticated using (
  public.has_organization_permission(organization_id,'organization.planning.view')
  and (horse_id is null or public.has_canonical_horse_permission(horse_id,'horse.view'))
);

-- This lookup observes stable_tasks RLS as the calling role; tasks never read
-- events, so no policy cycle or privileged generic helper is introduced.
drop policy stable_task_events_read on public.stable_task_events;
create policy stable_task_events_read on public.stable_task_events
for select to authenticated using (
  exists (
    select 1 from public.stable_tasks task
    where task.id=stable_task_events.task_id
      and task.organization_id=stable_task_events.organization_id
  )
);

create or replace function public.transition_c010_stable_task(
  p_organization_id uuid,p_task_id uuid,p_expected_row_version bigint,p_action text,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea; replay jsonb;
  before_row public.stable_tasks%rowtype; after_row public.stable_tasks%rowtype; result jsonb; event_name text;
begin
  actor_profile:=private.c003b_actor_profile_id();
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'task_id',p_task_id,'expected',p_expected_row_version,'action',p_action
  ));
  select * into before_row from public.stable_tasks value
    where value.id=p_task_id and value.organization_id=p_organization_id for update;
  if before_row.id is null then raise exception using errcode='42501',message='CROSS_STABLE_TASK_DENIED'; end if;
  -- Recheck current read authority before a receipt or task state is revealed.
  -- Membership/role or residency never substitutes for explicit horse access.
  if not private.c003b_profile_has_permission(
    actor_profile,p_organization_id,'organization.planning.view'
  ) or (before_row.horse_id is not null and not
    private.c003c_profile_has_horse_permission(actor_profile,before_row.horse_id,'horse.view'))
  then raise exception using errcode='42501',message='TASK_VISIBILITY_PERMISSION_REQUIRED'; end if;
  replay:=private.c010_round1_receipt_result(actor_user,p_request_id,'transition_task',payload_hash);
  if replay is not null then return replay; end if;
  if before_row.status<>'open' or before_row.row_version<>p_expected_row_version then
    raise exception using errcode='40001',message='STALE_TASK_VERSION'; end if;
  if p_action='complete' then
    if before_row.assignee_profile_id<>actor_profile
      or not private.c010_round1_active_member(actor_profile,p_organization_id)
      or not private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.planning.execute')
    then raise exception using errcode='42501',message='TASK_COMPLETION_PERMISSION_REQUIRED'; end if;
    event_name:='completed';
  elsif p_action='cancel' then
    if not(private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.planning.execute')
      and private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.memberships.view'))
    then raise exception using errcode='42501',message='STABLE_TASK_MANAGE_PERMISSION_REQUIRED'; end if;
    event_name:='cancelled';
  else raise exception using errcode='22023',message='TASK_ACTION_INVALID'; end if;
  update public.stable_tasks value set status=event_name,
    completed_by_profile_id=case when event_name='completed' then actor_profile end,
    completed_at=case when event_name='completed' then pg_catalog.clock_timestamp() end,
    cancelled_by_profile_id=case when event_name='cancelled' then actor_profile end,
    cancelled_at=case when event_name='cancelled' then pg_catalog.clock_timestamp() end,
    terminal_request_id=p_request_id,row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where value.id=p_task_id returning * into after_row;
  perform private.c010_round1_log_task(after_row.id,p_organization_id,actor_profile,event_name,p_request_id,
    before_row.row_version,after_row.row_version,before_row.status,after_row.status,'{}');
  result:=pg_catalog.jsonb_build_object('task_id',after_row.id,'row_version',after_row.row_version,
    'status',after_row.status,'idempotent',false);
  insert into private.c010_round1_receipts(actor_user_id,request_id,operation_name,payload_hash,result)
  values(actor_user,p_request_id,'transition_task',payload_hash,result);
  return result;
end;
$$;

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
    or p_category not in('feeding','hay','water','pasture','stable_preparation','other') or p_due_date is null
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
      raise exception using errcode='40001',message='STALE_TASK_VERSION'; end if;
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

commit;
