begin;

-- Personal day is a projection of the canonical sources, never a second task
-- registry. The existing C010 civil-calendar contract remains Amsterdam.
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
    where task.assignee_profile_id=actor_profile and task.due_date=on_date
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

revoke all on function public.get_c010_personal_day(date) from public,anon,authenticated,service_role;
grant execute on function public.get_c010_personal_day(date) to authenticated;
comment on function public.get_c010_personal_day(date) is
  'Actorless C010 personal calendar day: assigned stable tasks and explicitly participated horse activities, including terminal state. Current source permissions apply to each branch; no active-stable dependency or copied records.';

-- Reuse the Planning receipt/audit infrastructure. This action changes only
-- completion state: clients do not resend or reconstruct the stored activity.
alter table private.schedule_mutation_receipts
  drop constraint schedule_mutation_receipts_operation_name_check;
alter table private.schedule_mutation_receipts
  add constraint schedule_mutation_receipts_operation_name_check check (
    operation_name in (
      'create_schedule_series','update_schedule_series_scope',
      'materialize_schedule_occurrences','create_schedule_item',
      'update_schedule_item','cancel_schedule_item','assign_schedule_item',
      'return_schedule_assignment','record_schedule_execution',
      'correct_schedule_execution','reopen_schedule_item',
      'upsert_canonical_horse_schedule_item','upsert_c010_horse_schedule_item',
      'complete_c010_personal_activity'
    )
  );

create or replace function public.complete_c010_personal_activity(
  p_schedule_item_id uuid,p_expected_row_version bigint,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; target_horse_id uuid;
  target public.schedule_items%rowtype; payload_hash bytea; replay jsonb; result jsonb;
begin
  actor_profile:=private.c003c_actor_profile_id();
  if p_schedule_item_id is null or p_request_id is null
    or coalesce(p_expected_row_version,0)<1 then
    raise exception using errcode='22023',message='C010_ACTIVITY_COMPLETION_INPUT_INVALID';
  end if;
  select item.horse_id into target_horse_id from public.schedule_items item
    where item.id=p_schedule_item_id;
  if target_horse_id is null then
    raise exception using errcode='42501',message='HORSE_SCHEDULE_UNAVAILABLE';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('c0091:schedule:'||target_horse_id::text,0)
  );
  select * into target from public.schedule_items item
    where item.id=p_schedule_item_id and item.horse_id=target_horse_id for update;
  -- Recheck live visibility, explicit participation and mutation capability
  -- before looking up a prior receipt; a stale JWT/grant cannot read a replay.
  actor_profile:=private.c003c_actor_profile_id();
  if target.id is null or not private.c003c_profile_has_horse_permission(
      actor_profile,target.horse_id,'horse.view',pg_catalog.statement_timestamp())
    or not exists(select 1 from public.schedule_item_participants participant
      where participant.schedule_item_id=target.id and participant.profile_id=actor_profile
        and participant.status='active' and participant.valid_from<=pg_catalog.statement_timestamp()
        and (participant.valid_until is null or participant.valid_until>pg_catalog.statement_timestamp()))
  then raise exception using errcode='42501',message='HORSE_SCHEDULE_UNAVAILABLE'; end if;
  if not (
    private.c003c_profile_has_horse_permission(actor_profile,target.horse_id,'horse.edit',pg_catalog.statement_timestamp())
    or private.c003c_profile_has_horse_permission(actor_profile,target.horse_id,'horse.planning.manage',pg_catalog.statement_timestamp())
  ) then raise exception using errcode='42501',message='HORSE_PLANNING_PERMISSION_REQUIRED'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'schedule_item_id',p_schedule_item_id,'expected_row_version',p_expected_row_version
  ));
  replay:=private.schedule_receipt_result(
    actor_user,p_request_id,'complete_c010_personal_activity',payload_hash
  );
  if replay is not null then return replay; end if;
  if target.row_version<>p_expected_row_version then
    raise exception using errcode='PT409',message='STALE_SCHEDULE_VERSION';
  end if;
  if target.state not in ('planned','in_progress') then
    raise exception using errcode='22023',message='C010_ACTIVITY_NOT_COMPLETABLE';
  end if;
  update public.schedule_items item set
    state='completed',terminal_at=pg_catalog.clock_timestamp(),
    last_mutated_by_user_id=actor_user,last_mutation_request_id=p_request_id
  where item.id=target.id returning * into target;
  result:=pg_catalog.jsonb_build_object(
    'schedule_item_id',target.id,'horse_id',target.horse_id,
    'row_version',target.row_version,'state',target.state,'idempotent',false
  );
  insert into private.schedule_mutation_receipts(
    actor_user_id,request_id,stable_id,horse_id,operation_name,target_type,
    target_id,payload_hash,result
  ) values (
    actor_user,p_request_id,target.stable_id,target.horse_id,
    'complete_c010_personal_activity','schedule_item',target.id,payload_hash,result
  );
  perform private.c0091_write_horse_domain_audit(
    target.horse_id,actor_profile,p_request_id,'canonical_schedule_item_upserted',
    array['planning']::text[]
  );
  return result;
end;
$$;
revoke all on function public.complete_c010_personal_activity(uuid,bigint,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.complete_c010_personal_activity(uuid,bigint,uuid) to authenticated;
comment on function public.complete_c010_personal_activity(uuid,bigint,uuid) is
  'Complete one own explicitly participated canonical activity under the existing horse edit/planning-manage permission, CAS, horse lock, receipt and domain-audit contract. Stored scheduling, participants and instructions remain unchanged.';

commit;
