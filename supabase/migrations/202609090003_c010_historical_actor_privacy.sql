begin;

-- Keep historical values immutable while making credential identifiers private.
-- Existing non-Auth column rights are preserved, not broadened. RLS and service
-- rights are unchanged; unknown inherited sensitive grants fail this migration.
do $$
declare table_row record; column_row record; role_name text; allowed_columns text[];
  rights jsonb; service_before jsonb; service_after jsonb; columns_sql text; sensitive_sql text;
begin
  for table_row in select * from (values
    ('feeding_change_events',array['actor_user_id']::text[]),
    ('feeding_plan_items',array['created_by_user_id','last_mutated_by_user_id']::text[]),
    ('feeding_plan_versions',array['approved_by_user_id','created_by_user_id','last_mutated_by_user_id']::text[]),
    ('feeding_plans',array['created_by_user_id','last_mutated_by_user_id']::text[]),
    ('media_assets',array['last_mutated_by_user_id','uploaded_by_user_id']::text[]),
    ('media_change_events',array['actor_user_id']::text[]),
    ('media_links',array['created_by_user_id']::text[]),
    ('schedule_assignments',array['created_by_user_id','last_mutated_by_user_id']::text[]),
    ('schedule_change_events',array['actor_user_id']::text[]),
    ('schedule_executions',array['actor_user_id']::text[]),
    ('schedule_items',array['created_by_user_id','last_mutated_by_user_id']::text[]),
    ('schedule_series',array['created_by_user_id','last_mutated_by_user_id']::text[])
  ) selected(table_name,sensitive_columns) loop
    if (select count(*) from pg_catalog.pg_attribute a where a.attrelid=pg_catalog.to_regclass('public.'||table_row.table_name)
      and a.attnum>0 and not a.attisdropped and a.attname=any(table_row.sensitive_columns))<>pg_catalog.cardinality(table_row.sensitive_columns) then
      raise exception using errcode='55000',message='HISTORICAL_ACTOR_COLUMN_DRIFT';
    end if;
    rights:='{}'::jsonb;
    foreach role_name in array array['PUBLIC','anon','authenticated'] loop
      select coalesce(pg_catalog.array_agg(a.attname::text order by a.attnum),'{}'::text[]) into allowed_columns
      from pg_catalog.pg_attribute a join pg_catalog.pg_class c on c.oid=a.attrelid
      where c.oid=pg_catalog.to_regclass('public.'||table_row.table_name)
        and a.attnum>0 and not a.attisdropped and not(a.attname=any(table_row.sensitive_columns))
        and case when role_name='PUBLIC' then
          exists(select 1 from pg_catalog.aclexplode(coalesce(c.relacl,pg_catalog.acldefault('r',c.relowner))) acl
            where acl.grantee=0 and acl.privilege_type='SELECT')
          or exists(select 1 from pg_catalog.aclexplode(a.attacl) acl where acl.grantee=0 and acl.privilege_type='SELECT')
        else pg_catalog.has_column_privilege(role_name,c.oid,a.attnum,'SELECT') end;
      rights:=rights||pg_catalog.jsonb_build_object(role_name,allowed_columns);
    end loop;
    select pg_catalog.jsonb_object_agg(a.attname,pg_catalog.has_column_privilege('service_role',a.attrelid,a.attnum,'SELECT'))
      into service_before from pg_catalog.pg_attribute a where a.attrelid=pg_catalog.to_regclass('public.'||table_row.table_name)
      and a.attnum>0 and not a.attisdropped;
    select pg_catalog.string_agg(pg_catalog.quote_ident(name),',') into sensitive_sql
      from pg_catalog.unnest(table_row.sensitive_columns) names(name);
    foreach role_name in array array['PUBLIC','anon','authenticated'] loop
      execute pg_catalog.format('revoke select on public.%I from %s',table_row.table_name,
        case when role_name='PUBLIC' then 'PUBLIC' else pg_catalog.quote_ident(role_name) end);
      execute pg_catalog.format('revoke select (%s) on public.%I from %s',sensitive_sql,table_row.table_name,
        case when role_name='PUBLIC' then 'PUBLIC' else pg_catalog.quote_ident(role_name) end);
      select pg_catalog.string_agg(pg_catalog.quote_ident(name),',') into columns_sql
        from pg_catalog.jsonb_array_elements_text(rights->role_name) names(name);
      if columns_sql is not null then
        execute pg_catalog.format('grant select (%s) on public.%I to %s',columns_sql,table_row.table_name,
          case when role_name='PUBLIC' then 'PUBLIC' else pg_catalog.quote_ident(role_name) end);
      end if;
    end loop;
    for column_row in select a.attnum,a.attname,a.attrelid from pg_catalog.pg_attribute a
      where a.attrelid=pg_catalog.to_regclass('public.'||table_row.table_name) and a.attname=any(table_row.sensitive_columns)
    loop
      if pg_catalog.has_column_privilege('authenticated',column_row.attrelid,column_row.attnum,'SELECT')
        or pg_catalog.has_column_privilege('anon',column_row.attrelid,column_row.attnum,'SELECT') then
        raise exception using errcode='42501',message='HISTORICAL_ACTOR_INHERITED_GRANT_UNSUPPORTED';
      end if;
    end loop;
    select pg_catalog.jsonb_object_agg(a.attname,pg_catalog.has_column_privilege('service_role',a.attrelid,a.attnum,'SELECT'))
      into service_after from pg_catalog.pg_attribute a where a.attrelid=pg_catalog.to_regclass('public.'||table_row.table_name)
      and a.attnum>0 and not a.attisdropped;
    if service_before is distinct from service_after then
      raise exception using errcode='42501',message='HISTORICAL_ACTOR_SERVICE_PRIVILEGE_DRIFT';
    end if;
  end loop;
end; $$;

-- Old execution projections retain their column shape and active-user behavior;
-- a pending/deleted historical actor's credential UUID is no longer returned.
CREATE OR REPLACE FUNCTION public.list_schedule_executions(p_schedule_item_id uuid)
 RETURNS TABLE(execution_id uuid, schedule_item_id uuid, actor_user_id uuid, actor_stable_member_id uuid, execution_status text, actual_started_at timestamp with time zone, actual_completed_at timestamp with time zone, recorded_local_at timestamp without time zone, recorded_timezone text, source text, note text, corrects_execution_id uuid, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with access as (
    select private.schedule_item_access_level(p_schedule_item_id) as level
  )
  select
    execution.id,
    execution.schedule_item_id,
    case when exists(select 1 from public.profiles actor_profile
      where actor_profile.auth_user_id=execution.actor_user_id and actor_profile.status='active')
      then execution.actor_user_id else null::uuid end,
    execution.actor_stable_member_id,
    execution.execution_status,
    execution.actual_started_at,
    execution.actual_completed_at,
    execution.recorded_local_at,
    execution.recorded_timezone,
    execution.source,
    execution.note,
    execution.corrects_execution_id,
    execution.created_at
  from public.schedule_executions execution
  cross join access
  where execution.schedule_item_id = p_schedule_item_id
    and (
      access.level = 'full'
      or (
        access.level = 'assigned'
        and execution.actor_user_id = auth.uid()
      )
    )
  order by execution.created_at, execution.id
$function$
;

CREATE OR REPLACE FUNCTION public.list_schedule_calendar(p_stable_id uuid, p_from_local_date date, p_through_local_date date)
 RETURNS TABLE(schedule_item_id uuid, stable_id uuid, horse_id uuid, horse_name text, series_id uuid, item_kind text, data_category text, title text, instruction text, priority text, scheduled_start_at timestamp with time zone, scheduled_end_at timestamp with time zone, source_timezone text, source_local_date date, source_local_time time without time zone, occurrence_local_date date, state text, row_version bigint, assignment_role text, assignment_status text, responsible_stable_member_id uuid, responsible_name text, access_scope text, is_overdue boolean, series_row_version bigint, series_frequency text, series_interval_value integer, series_weekdays smallint[], series_local_start_time time without time zone, series_duration_minutes integer, series_ends_on date, series_status text, feeding_plan_item_id uuid, feeding_item_category text, planned_quantity numeric, planned_unit_code text, product_name text, offering_method text, round_code text, actual_quantity numeric, actual_unit_code text, remaining_quantity numeric, deviation_code text, observation text, execution_note text, execution_actor_user_id uuid, actual_completed_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  with actor_membership as (
    select membership.stable_member_id
    from public.stable_memberships membership
    join public.stables stable on stable.id = membership.stable_id
    where membership.stable_id = p_stable_id
      and membership.user_id = auth.uid()
      and membership.status = 'active'
      and stable.status = 'active'
  ),
  accessible_items as (
    select
      item.*,
      private.schedule_item_access_level(item.id) as access_level
    from public.schedule_items item
    where item.stable_id = p_stable_id
      and item.source_local_date between p_from_local_date and p_through_local_date
      and p_through_local_date >= p_from_local_date
      and p_through_local_date <= p_from_local_date + 366
  )
  select
    item.id,
    item.stable_id,
    item.horse_id,
    horse.display_name,
    case when item.access_level = 'full' then item.series_id else null end,
    item.item_kind,
    item.data_category,
    item.title,
    item.instruction,
    item.priority,
    item.scheduled_start_at,
    item.scheduled_end_at,
    item.source_timezone,
    item.source_local_date,
    item.source_local_time,
    item.occurrence_local_date,
    item.state,
    item.row_version,
    own_assignment.assignment_role,
    own_assignment.status,
    responsible_assignment.stable_member_id,
    responsible_member.display_name,
    item.access_level,
    item.state in ('planned', 'in_progress')
      and item.scheduled_start_at < pg_catalog.now(),
    case when item.access_level = 'full' then series.row_version else null end,
    case when item.access_level = 'full' then series.frequency else null end,
    case when item.access_level = 'full' then series.interval_value else null end,
    case when item.access_level = 'full' then series.weekdays else null end,
    case when item.access_level = 'full' then series.local_start_time else null end,
    case when item.access_level = 'full' then series.duration_minutes else null end,
    case when item.access_level = 'full' then series.ends_on else null end,
    case when item.access_level = 'full' then series.status else null end,
    occurrence.feeding_plan_item_id,
    plan_item.item_category,
    occurrence.planned_quantity,
    occurrence.unit_code,
    plan_item.product_name,
    occurrence.offering_method,
    plan_item.round_code,
    execution_detail.actual_quantity,
    execution_detail.unit_code,
    execution_detail.remaining_quantity,
    execution_detail.deviation_code,
    execution_detail.observation,
    latest_execution.note,
    case when exists(select 1 from public.profiles actor_profile
      where actor_profile.auth_user_id=latest_execution.actor_user_id and actor_profile.status='active')
      then latest_execution.actor_user_id else null::uuid end,
    latest_execution.actual_completed_at
  from accessible_items item
  cross join actor_membership
  left join public.horses horse on horse.id = item.horse_id
  left join public.schedule_series series on series.id = item.series_id
  left join lateral (
    select assignment.assignment_role, assignment.status
    from public.schedule_assignments assignment
    where assignment.schedule_item_id = item.id
      and assignment.stable_member_id = actor_membership.stable_member_id
      and assignment.status in ('assigned', 'accepted', 'completed')
    order by assignment.created_at desc, assignment.id
    limit 1
  ) own_assignment on true
  left join lateral (
    select assignment.stable_member_id
    from public.schedule_assignments assignment
    where assignment.schedule_item_id = item.id
      and assignment.assignment_role = 'responsible'
      and assignment.status in ('assigned', 'accepted', 'completed')
    order by assignment.created_at desc, assignment.id
    limit 1
  ) responsible_assignment on true
  left join public.stable_members responsible_member
    on responsible_member.id = responsible_assignment.stable_member_id
  left join public.feeding_occurrences occurrence
    on occurrence.schedule_item_id = item.id
  left join public.feeding_plan_items plan_item
    on plan_item.id = occurrence.feeding_plan_item_id
  left join lateral (
    select execution.*
    from public.schedule_executions execution
    where execution.schedule_item_id = item.id
    order by execution.created_at desc, execution.id desc
    limit 1
  ) latest_execution on true
  left join public.feeding_execution_details execution_detail
    on execution_detail.execution_id = latest_execution.id
  where item.access_level in ('full', 'assigned')
  order by item.scheduled_start_at, item.id
$function$
;

-- Safe replacement for filtering the now-private uploaded_by_user_id column.
create function public.get_c010_my_media_upload_status(p_create_request_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  perform private.require_current_profile_id();
  return (select pg_catalog.jsonb_build_object('id',asset.id,'status',asset.status)
    from public.media_assets asset
    where asset.uploaded_by_user_id=auth.uid() and asset.created_request_id=p_create_request_id
      and asset.status='ready' and private.can_view_media_asset(asset.id));
end; $$;
revoke all on function public.get_c010_my_media_upload_status(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_c010_my_media_upload_status(uuid) to authenticated;

-- Also fail closed for pre-C003A identities whose durable ID is the Auth ID.
create or replace function public.prepare_c010_account_deletion(p_auth_user_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  before_profile public.profiles%rowtype; pending_profile public.profiles%rowtype; after_profile public.profiles%rowtype;
  job private.account_deletion_jobs%rowtype; item record; footprint boolean; avatar_paths text[];
  email_hmac bytea; now_at timestamptz:=pg_catalog.clock_timestamp(); horse_ids uuid[]; org_ids uuid[];
  affected_profiles uuid[]; value_id uuid;
begin
  if p_auth_user_id is null or p_request_id is null then
    raise exception using errcode='22023',message='DELETION_CONFIRMATION_REQUIRED';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('c010:delete:request:'||p_request_id::text,0));
  select p.* into before_profile from public.profiles p
  join private.account_actor_references actor on actor.profile_id=p.id
  where actor.auth_user_id=p_auth_user_id for update of p;
  if not found then return '{"code":"AUTHENTICATION_REQUIRED","status":"blocked"}'::jsonb; end if;
  select * into job from private.account_deletion_jobs j where j.correlation_id=p_request_id;
  if found and job.profile_id<>before_profile.id then
    return '{"code":"DELETION_REQUEST_CONFLICT","status":"blocked"}'::jsonb;
  end if;
  if exists(select 1 from private.account_deletion_jobs j where j.profile_id=before_profile.id) then
    return private.c010_deletion_job_result(before_profile.id);
  end if;
  if before_profile.status<>'active' then
    return '{"code":"ACCOUNT_DELETION_STATE_UNSUPPORTED","status":"blocked"}'::jsonb;
  end if;
  if before_profile.auth_user_id is distinct from p_auth_user_id
    or not exists(select 1 from auth.users actor where actor.id=p_auth_user_id) then
    return '{"code":"AUTHENTICATION_REQUIRED","status":"blocked"}'::jsonb;
  end if;
  -- All scalar authorities block, including archived entities.
  if exists(select 1 from public.organizations o where o.primary_admin_profile_id=before_profile.id) then
    return '{"code":"PRIMARY_ORGANIZATION_ADMIN_REQUIRED","status":"blocked"}'::jsonb;
  end if;
  if exists(select 1 from public.canonical_horses h where h.primary_authority_profile_id=before_profile.id) then
    return '{"code":"PRIMARY_HORSE_AUTHORITY_REQUIRED","status":"blocked"}'::jsonb;
  end if;
  -- C003A preserved pre-existing profile IDs. If the durable ID equals the
  -- Auth ID, hiding actor columns cannot hide that same durable profile UUID.
  -- Keep this legacy account active; do not silently rewrite its identity.
  if before_profile.id=p_auth_user_id then
    return '{"code":"LEGACY_RETENTION_REQUIRED","status":"blocked"}'::jsonb;
  end if;
  -- Every remaining historical app FK is a refusal, never a cleanup DELETE.
  -- The two consciously classified real Auth FKs are unlink and preferences.
  for item in
    select n.nspname schema_name,c.relname table_name,a.attname column_name
    from pg_catalog.pg_constraint k
    join pg_catalog.pg_class c on c.oid=k.conrelid
    join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    join pg_catalog.pg_attribute a on a.attrelid=c.oid and a.attnum=any(k.conkey)
    where k.contype='f' and k.confrelid='auth.users'::regclass
      and n.nspname in('public','private')
      and not(n.nspname='public' and c.relname in('profiles','account_workspace_preferences'))
  loop
    execute pg_catalog.format('select exists(select 1 from %I.%I value where value.%I=$1)',
      item.schema_name,item.table_name,item.column_name) into footprint using p_auth_user_id;
    if footprint then return '{"code":"LEGACY_RETENTION_REQUIRED","status":"blocked"}'::jsonb; end if;
  end loop;
  if exists(select 1 from public.stable_invitations invitation
    join auth.users actor on actor.id=p_auth_user_id
    where invitation.invited_email=pg_catalog.lower(pg_catalog.btrim(actor.email))) then
    return '{"code":"LEGACY_RETENTION_REQUIRED","status":"blocked"}'::jsonb;
  end if;
  if exists(select 1 from storage.objects object
    where (object.owner=p_auth_user_id or object.owner_id=p_auth_user_id::text)
      and not(object.bucket_id='avatars' and pg_catalog.split_part(object.name,'/',1)=p_auth_user_id::text))
    or exists(select 1 from storage.objects object
      where object.bucket_id='avatars' and pg_catalog.split_part(object.name,'/',1)=p_auth_user_id::text
        and ((object.owner is not null and object.owner<>p_auth_user_id)
          or (object.owner_id is not null and object.owner_id<>p_auth_user_id::text))) then
    return '{"code":"STORAGE_OWNERSHIP_UNSUPPORTED","status":"blocked"}'::jsonb;
  end if;
  select coalesce(pg_catalog.array_agg(object.name order by object.name),'{}'::text[])
  into avatar_paths from storage.objects object
  where object.bucket_id='avatars' and pg_catalog.split_part(object.name,'/',1)=p_auth_user_id::text;
  select private.c003d_email_hmac(actor.email) into email_hmac from auth.users actor
  where actor.id=p_auth_user_id and actor.email is not null;

  select coalesce(pg_catalog.array_agg(distinct id),'{}'::uuid[]) into horse_ids from (
    select horse_id id from public.horse_delegated_administrators where profile_id=before_profile.id and status='active'
    union select horse_id from public.horse_person_relationships where profile_id=before_profile.id and status='active'
    union select horse_id from public.horse_profile_permission_grants where (grantee_profile_id=before_profile.id or grantor_profile_id=before_profile.id) and status='active'
    union select horse_id from public.horse_organization_role_permission_grants where grantor_profile_id=before_profile.id and status='active'
    union select horse_id from public.horse_access_invitations where status='pending' and (inviter_profile_id=before_profile.id or target_profile_id=before_profile.id or target_email_hmac=email_hmac)
    union select horse_id from public.horse_authority_transfers where status='pending' and (sender_profile_id=before_profile.id or recipient_profile_id=before_profile.id)
  ) related;
  select coalesce(pg_catalog.array_agg(distinct id),'{}'::uuid[]) into org_ids from (
    select organization_id id from public.organization_memberships where profile_id=before_profile.id and status in('active','suspended')
    union select organization_id from public.organization_invitations where status='pending' and (inviter_profile_id=before_profile.id or target_profile_id=before_profile.id or target_email_hmac=email_hmac)
    union select organization_id from public.organization_authority_transfers where status='pending' and (sender_profile_id=before_profile.id or recipient_profile_id=before_profile.id)
    union select organization_id from public.horse_organization_role_permission_grants where grantor_profile_id=before_profile.id and status='active'
    union select organization_id from public.rider_performance_org_role_share_grants where owner_profile_id=before_profile.id and status='active'
  ) related;
  select coalesce(pg_catalog.array_agg(distinct id),'{}'::uuid[]) into affected_profiles from (
    select before_profile.id id
    union select grantee_profile_id from public.horse_profile_permission_grants where grantor_profile_id=before_profile.id and status='active'
    union select grantee_profile_id from public.rider_performance_profile_share_grants where owner_profile_id=before_profile.id and status='active'
    union select owner_profile_id from public.rider_performance_profile_share_grants where grantee_profile_id=before_profile.id and status='active'
    union select profile_id from public.organization_memberships where organization_id=any(org_ids) and status in('active','suspended')
  ) related;

  -- Any failure below rolls back the job and every dependency change together.
  insert into private.account_deletion_jobs(profile_id,auth_user_id,correlation_id,avatar_paths,status)
  values(before_profile.id,p_auth_user_id,p_request_id,avatar_paths,'auth_removal_pending');
  update public.horse_profile_permission_grants g set status='revoked',
    terminal_reason_code='PROFILE_DELETION',terminal_by_profile_id=before_profile.id,terminal_at=now_at,
    valid_until=greatest(now_at,g.valid_from+interval '1 microsecond'),row_version=g.row_version+1,updated_at=now_at
  where g.status='active' and (g.grantee_profile_id=before_profile.id or g.grantor_profile_id=before_profile.id);
  update public.horse_organization_role_permission_grants g set status='revoked',
    terminal_reason_code='PROFILE_DELETION',terminal_by_profile_id=before_profile.id,terminal_at=now_at,
    valid_until=greatest(now_at,g.valid_from+interval '1 microsecond'),row_version=g.row_version+1,updated_at=now_at
  where g.status='active' and g.grantor_profile_id=before_profile.id;
  update public.rider_performance_profile_share_grants g set status='revoked',
    terminal_reason_code='PROFILE_DELETION',terminal_at=now_at,
    valid_until=greatest(now_at,g.valid_from+interval '1 microsecond'),row_version=g.row_version+1,updated_at=now_at
  where g.status='active' and (g.owner_profile_id=before_profile.id or g.grantee_profile_id=before_profile.id);
  update public.rider_performance_org_role_share_grants g set status='revoked',
    terminal_reason_code='PROFILE_DELETION',terminal_at=now_at,
    valid_until=greatest(now_at,g.valid_from+interval '1 microsecond'),row_version=g.row_version+1,updated_at=now_at
  where g.status='active' and g.owner_profile_id=before_profile.id;
  update public.horse_delegated_administrators d set status='ended',ended_reason_code='profile_deleted',
    valid_until=greatest(now_at,d.valid_from+interval '1 microsecond'),row_version=d.row_version+1,updated_at=now_at
  where d.profile_id=before_profile.id and d.status='active';
  update public.horse_person_relationships r set status='ended',
    valid_until=greatest(now_at,r.valid_from+interval '1 microsecond'),row_version=r.row_version+1,updated_at=now_at
  where r.profile_id=before_profile.id and r.status='active';
  update public.organization_membership_roles r set status='ended',ended_reason_code='membership_ended',revoked_by_profile_id=before_profile.id,
    valid_until=greatest(now_at,r.valid_from+interval '1 microsecond'),row_version=r.row_version+1,updated_at=now_at
  from public.organization_memberships m where m.id=r.membership_id and m.profile_id=before_profile.id and r.status='active';
  update public.organization_memberships m set status='ended',ended_reason_code='profile_departed',
    valid_until=greatest(now_at,m.valid_from+interval '1 microsecond'),row_version=m.row_version+1,updated_at=now_at
  where m.profile_id=before_profile.id and m.status in('active','suspended');
  update public.organization_invitations i set status='revoked',token_digest=null,terminal_reason_code='PROFILE_DELETION',
    terminal_at=now_at,response_correlation_id=p_request_id,row_version=i.row_version+1,updated_at=now_at
  where i.status='pending' and (i.inviter_profile_id=before_profile.id or i.target_profile_id=before_profile.id or i.target_email_hmac=email_hmac);
  update public.horse_access_invitations i set status='revoked',token_digest=null,terminal_reason_code='PROFILE_DELETION',
    terminal_at=now_at,response_correlation_id=p_request_id,row_version=i.row_version+1,updated_at=now_at
  where i.status='pending' and (i.inviter_profile_id=before_profile.id or i.target_profile_id=before_profile.id or i.target_email_hmac=email_hmac);
  update public.horse_authority_transfers t set status='revoked',token_digest=null,terminal_reason_code='REVOKED',
    terminal_by_profile_id=before_profile.id,terminal_at=now_at,response_correlation_id=p_request_id,row_version=t.row_version+1,updated_at=now_at
  where t.status='pending' and (t.sender_profile_id=before_profile.id or t.recipient_profile_id=before_profile.id);
  update public.organization_authority_transfers t set status='revoked',token_digest=null,terminal_reason_code='REVOKED',
    terminal_by_profile_id=before_profile.id,terminal_at=now_at,response_correlation_id=p_request_id,row_version=t.row_version+1,updated_at=now_at
  where t.status='pending' and (t.sender_profile_id=before_profile.id or t.recipient_profile_id=before_profile.id);
  foreach value_id in array horse_ids loop
    perform private.c003c_bump_access(value_id,'{}'::uuid[],before_profile.id,p_request_id,'profile_deletion');
  end loop;
  foreach value_id in array org_ids loop
    perform private.c003b_bump_access(value_id,'{}'::uuid[],before_profile.id,p_request_id,'profile_deletion');
  end loop;
  update public.profiles p set access_version=p.access_version+1 where p.id=any(affected_profiles) and p.status='active';
  select p.* into before_profile from public.profiles p where p.id=before_profile.id;
  update public.profiles p set status='deletion_pending',access_version=p.access_version+1
  where p.id=before_profile.id returning p.* into pending_profile;
  perform private.c003a_write_profile_audit('profile.deletion_requested',pending_profile.id,pending_profile.id,null,
    p_request_id,'rpc',before_profile.status,pending_profile.status,before_profile.row_version,pending_profile.row_version,
    before_profile.access_version,pending_profile.access_version,'{}'::jsonb);
  update public.profiles p set first_name=null,last_name=null,display_name='Deleted AVARYN account',avatar_object_path=null,
    phone_e164=null,locale='und',time_zone='UTC',theme_mode='system',onboarding_intent=null,onboarding_completed_at=null,
    accepted_terms_version=null,accepted_privacy_version=null,status='auth_removal_pending',access_version=p.access_version+1
  where p.id=before_profile.id returning p.* into after_profile;
  perform private.c003a_write_profile_audit('profile.auth_removal_prepared',after_profile.id,null,'account_deletion_orchestrator',
    p_request_id,'system',pending_profile.status,after_profile.status,pending_profile.row_version,after_profile.row_version,
    pending_profile.access_version,after_profile.access_version,'{"dependency_checks_complete":true}'::jsonb);
  return private.c010_deletion_job_result(before_profile.id);
end; $$;

notify pgrst,'reload schema';
commit;
