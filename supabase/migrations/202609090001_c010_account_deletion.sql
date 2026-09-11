begin;

-- C010: trusted, resumable deletion for canonical accounts. Historical actor
-- UUIDs remain unchanged. Legacy footprints and unresolved authority fail closed.
create table private.account_actor_references (
  auth_user_id uuid primary key,
  profile_id uuid not null unique references public.profiles(id) on delete restrict
);
revoke all on private.account_actor_references from public,anon,authenticated,service_role;
insert into private.account_actor_references(auth_user_id,profile_id)
select profile.auth_user_id,profile.id from public.profiles profile
join auth.users actor on actor.id=profile.auth_user_id;

create function private.c010_register_actor_reference()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if new.auth_user_id is not null then
    if not exists(select 1 from auth.users actor where actor.id=new.auth_user_id) then
      raise exception using errcode='23503',message='AUTH_ACTOR_REFERENCE_REQUIRED';
    end if;
    insert into private.account_actor_references(auth_user_id,profile_id)
    values(new.auth_user_id,new.id);
  end if;
  return new;
end; $$;
create trigger c010_register_actor_reference after insert on public.profiles
for each row execute function private.c010_register_actor_reference();

-- Explicit catalog allowlist: fail on drift; never discover-and-drop arbitrary FKs.
do $$
declare item record; actual text; unresolved boolean;
begin
  for item in select * from (values
    ('private','c010_mutation_receipts','c010_mutation_receipts_actor_user_id_fkey','actor_user_id','FOREIGN KEY (actor_user_id) REFERENCES auth.users(id)'),
    ('private','c010_round1_receipts','c010_round1_receipts_actor_user_id_fkey','actor_user_id','FOREIGN KEY (actor_user_id) REFERENCES auth.users(id) ON DELETE RESTRICT'),
    ('private','feeding_mutation_receipts','feeding_mutation_receipts_actor_user_id_fkey','actor_user_id','FOREIGN KEY (actor_user_id) REFERENCES auth.users(id)'),
    ('private','media_mutation_receipts','media_mutation_receipts_actor_user_id_fkey','actor_user_id','FOREIGN KEY (actor_user_id) REFERENCES auth.users(id)'),
    ('private','schedule_mutation_receipts','schedule_mutation_receipts_actor_user_id_fkey','actor_user_id','FOREIGN KEY (actor_user_id) REFERENCES auth.users(id)'),
    ('public','feeding_change_events','feeding_change_events_actor_user_id_fkey','actor_user_id','FOREIGN KEY (actor_user_id) REFERENCES auth.users(id)'),
    ('public','feeding_plan_items','feeding_plan_items_created_by_user_id_fkey','created_by_user_id','FOREIGN KEY (created_by_user_id) REFERENCES auth.users(id)'),
    ('public','feeding_plan_items','feeding_plan_items_last_mutated_by_user_id_fkey','last_mutated_by_user_id','FOREIGN KEY (last_mutated_by_user_id) REFERENCES auth.users(id)'),
    ('public','feeding_plan_versions','feeding_plan_versions_approved_by_user_id_fkey','approved_by_user_id','FOREIGN KEY (approved_by_user_id) REFERENCES auth.users(id)'),
    ('public','feeding_plan_versions','feeding_plan_versions_created_by_user_id_fkey','created_by_user_id','FOREIGN KEY (created_by_user_id) REFERENCES auth.users(id)'),
    ('public','feeding_plan_versions','feeding_plan_versions_last_mutated_by_user_id_fkey','last_mutated_by_user_id','FOREIGN KEY (last_mutated_by_user_id) REFERENCES auth.users(id)'),
    ('public','feeding_plans','feeding_plans_created_by_user_id_fkey','created_by_user_id','FOREIGN KEY (created_by_user_id) REFERENCES auth.users(id)'),
    ('public','feeding_plans','feeding_plans_last_mutated_by_user_id_fkey','last_mutated_by_user_id','FOREIGN KEY (last_mutated_by_user_id) REFERENCES auth.users(id)'),
    ('public','media_assets','media_assets_last_mutated_by_user_id_fkey','last_mutated_by_user_id','FOREIGN KEY (last_mutated_by_user_id) REFERENCES auth.users(id)'),
    ('public','media_assets','media_assets_uploaded_by_user_id_fkey','uploaded_by_user_id','FOREIGN KEY (uploaded_by_user_id) REFERENCES auth.users(id)'),
    ('public','media_change_events','media_change_events_actor_user_id_fkey','actor_user_id','FOREIGN KEY (actor_user_id) REFERENCES auth.users(id)'),
    ('public','media_links','media_links_created_by_user_id_fkey','created_by_user_id','FOREIGN KEY (created_by_user_id) REFERENCES auth.users(id)'),
    ('public','schedule_assignments','schedule_assignments_created_by_user_id_fkey','created_by_user_id','FOREIGN KEY (created_by_user_id) REFERENCES auth.users(id)'),
    ('public','schedule_assignments','schedule_assignments_last_mutated_by_user_id_fkey','last_mutated_by_user_id','FOREIGN KEY (last_mutated_by_user_id) REFERENCES auth.users(id)'),
    ('public','schedule_change_events','schedule_change_events_actor_user_id_fkey','actor_user_id','FOREIGN KEY (actor_user_id) REFERENCES auth.users(id)'),
    ('public','schedule_executions','schedule_executions_actor_user_id_fkey','actor_user_id','FOREIGN KEY (actor_user_id) REFERENCES auth.users(id)'),
    ('public','schedule_items','schedule_items_created_by_user_id_fkey','created_by_user_id','FOREIGN KEY (created_by_user_id) REFERENCES auth.users(id)'),
    ('public','schedule_items','schedule_items_last_mutated_by_user_id_fkey','last_mutated_by_user_id','FOREIGN KEY (last_mutated_by_user_id) REFERENCES auth.users(id)'),
    ('public','schedule_series','schedule_series_created_by_user_id_fkey','created_by_user_id','FOREIGN KEY (created_by_user_id) REFERENCES auth.users(id)'),
    ('public','schedule_series','schedule_series_last_mutated_by_user_id_fkey','last_mutated_by_user_id','FOREIGN KEY (last_mutated_by_user_id) REFERENCES auth.users(id)')
  ) as selected(schema_name,table_name,constraint_name,column_name,definition) loop
    select pg_catalog.pg_get_constraintdef(k.oid) into actual
    from pg_catalog.pg_constraint k
    where k.conrelid=pg_catalog.to_regclass(pg_catalog.format('%I.%I',item.schema_name,item.table_name))
      and k.conname=item.constraint_name and k.contype='f';
    if actual is distinct from item.definition then
      raise exception using errcode='55000',message='ACCOUNT_ACTOR_FK_CATALOG_DRIFT';
    end if;
    execute pg_catalog.format('select exists(select 1 from %I.%I value where value.%I is not null and not exists(select 1 from private.account_actor_references actor where actor.auth_user_id=value.%I))',
      item.schema_name,item.table_name,item.column_name,item.column_name) into unresolved;
    if unresolved then raise exception using errcode='23503',message='ACCOUNT_ACTOR_MAPPING_UNRESOLVED'; end if;
    execute pg_catalog.format('alter table %I.%I drop constraint %I',item.schema_name,item.table_name,item.constraint_name);
    execute pg_catalog.format('alter table %I.%I add constraint %I foreign key (%I) references private.account_actor_references(auth_user_id) on delete restrict',
      item.schema_name,item.table_name,item.constraint_name,item.column_name);
  end loop;
end; $$;

create table private.account_deletion_jobs (
  profile_id uuid primary key references public.profiles(id) on delete restrict,
  auth_user_id uuid not null unique references private.account_actor_references(auth_user_id) on delete restrict,
  correlation_id uuid not null unique,
  avatar_paths text[] not null,
  status text not null check(status in('auth_removal_pending','anonymized'))
);
revoke all on private.account_deletion_jobs from public,anon,authenticated,service_role;

-- Serialize a user's writes with preparation. Checking only changed actor fields
-- would permit a stale JWT to update another field on its historical row.
create function private.c010_guard_deletion_actor_write()
returns trigger language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); profile_id uuid;
begin
  if actor is not null then
    select profile.id into profile_id from public.profiles profile
    join auth.users auth_actor on auth_actor.id=profile.auth_user_id
    where profile.auth_user_id=actor and profile.status='active' for update of profile;
    if profile_id is null then raise exception using errcode='42501',message='ACTIVE_PROFILE_REQUIRED'; end if;
  end if;
  if tg_op='DELETE' then return old; end if;
  return new;
end; $$;
create trigger c010_active_actor_before_write before insert or update or delete on private.c010_mutation_receipts
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on private.c010_round1_receipts
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on private.client_mutation_receipts
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on private.feeding_mutation_receipts
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on private.horse_identifier_mutation_receipts
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on private.horse_relationship_mutation_receipts
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on private.media_mutation_receipts
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on private.schedule_mutation_receipts
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on private.stable_invitation_rate_events
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.account_workspace_preferences
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.client_sync_devices
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.feeding_change_events
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.feeding_plan_items
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.feeding_plan_versions
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.feeding_plans
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.horse_access_grants
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.horse_identifiers
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.horse_profile_change_events
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.horse_relationships
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.horses
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.legacy_import_jobs
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.media_assets
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.media_change_events
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.media_links
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.schedule_assignments
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.schedule_change_events
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.schedule_executions
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.schedule_items
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.schedule_series
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.stable_invitations
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.stable_memberships
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.stable_security_events
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.stables
for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010_active_actor_before_write before insert or update or delete on public.sync_conflicts
for each row execute function private.c010_guard_deletion_actor_write();

-- Target-row locking closes grant/invitation/authority races. Historical actor
-- references do not need to stay active; only new live target dependencies do.
create function private.c010_guard_live_profile_targets()
returns trigger language plpgsql security definer set search_path='' as $$
declare value jsonb:=pg_catalog.to_jsonb(new); field text; target uuid; ids uuid[]:='{}';
begin
  if coalesce(value->>'status','active') not in('active','suspended','pending') then return new; end if;
  foreach field in array tg_argv loop
    if field='@membership' then
      select m.profile_id into target from public.organization_memberships m where m.id=(value->>'membership_id')::uuid;
    else target:=nullif(value->>field,'')::uuid;
    end if;
    if target is not null then ids:=pg_catalog.array_append(ids,target); end if;
  end loop;
  for target in select distinct value_id from pg_catalog.unnest(ids) as values_to_lock(value_id) order by value_id loop
    perform 1 from public.profiles p where p.id=target and p.status='active' for update;
    if not found then raise exception using errcode='42501',message='ACTIVE_TARGET_PROFILE_REQUIRED'; end if;
  end loop;
  return new;
end; $$;
create trigger c010_live_profile_target_before_write before insert or update on public.organizations
for each row execute function private.c010_guard_live_profile_targets('primary_admin_profile_id');
create trigger c010_live_profile_target_before_write before insert or update on public.canonical_horses
for each row execute function private.c010_guard_live_profile_targets('primary_authority_profile_id');
create trigger c010_live_profile_target_before_write before insert or update on public.organization_memberships
for each row execute function private.c010_guard_live_profile_targets('profile_id');
create trigger c010_live_profile_target_before_write before insert or update on public.organization_membership_roles
for each row execute function private.c010_guard_live_profile_targets('@membership');
create trigger c010_live_profile_target_before_write before insert or update on public.horse_delegated_administrators
for each row execute function private.c010_guard_live_profile_targets('profile_id');
create trigger c010_live_profile_target_before_write before insert or update on public.horse_person_relationships
for each row execute function private.c010_guard_live_profile_targets('profile_id');
create trigger c010_live_profile_target_before_write before insert or update on public.horse_profile_permission_grants
for each row execute function private.c010_guard_live_profile_targets('grantee_profile_id');
create trigger c010_live_profile_target_before_write before insert or update on public.rider_performance_profile_share_grants
for each row execute function private.c010_guard_live_profile_targets('owner_profile_id','grantee_profile_id');
create trigger c010_live_profile_target_before_write before insert or update on public.rider_performance_org_role_share_grants
for each row execute function private.c010_guard_live_profile_targets('owner_profile_id');
create trigger c010_live_profile_target_before_write before insert or update on public.organization_invitations
for each row execute function private.c010_guard_live_profile_targets('inviter_profile_id','target_profile_id');
create trigger c010_live_profile_target_before_write before insert or update on public.horse_access_invitations
for each row execute function private.c010_guard_live_profile_targets('inviter_profile_id','target_profile_id');
create trigger c010_live_profile_target_before_write before insert or update on public.horse_authority_transfers
for each row execute function private.c010_guard_live_profile_targets('sender_profile_id','recipient_profile_id');
create trigger c010_live_profile_target_before_write before insert or update on public.organization_authority_transfers
for each row execute function private.c010_guard_live_profile_targets('sender_profile_id','recipient_profile_id');

create trigger c010_avatar_actor_before_insert before insert on storage.objects
for each row when (new.bucket_id='avatars') execute function private.c010_guard_deletion_actor_write();
create trigger c010_avatar_actor_before_update before update on storage.objects
for each row when (old.bucket_id='avatars' or new.bucket_id='avatars') execute function private.c010_guard_deletion_actor_write();
create trigger c010_avatar_actor_before_delete before delete on storage.objects
for each row when (old.bucket_id='avatars') execute function private.c010_guard_deletion_actor_write();

-- Restrictive policies only narrow the old prefix policies. No new table grants.
create policy c010_avatars_active_profile on storage.objects as restrictive for all to authenticated
using(bucket_id<>'avatars' or private.current_profile_id() is not null)
with check(bucket_id<>'avatars' or private.current_profile_id() is not null);
create policy c010_preferences_active_profile on public.account_workspace_preferences as restrictive for all to authenticated
using(private.current_profile_id() is not null) with check(private.current_profile_id() is not null);

-- No new actor impersonation: an empty bound-grant cascade is a no-op.
create or replace function private.c003d_revoke_bound_grants()
returns trigger language plpgsql security definer set search_path='' as $$
declare actor_id uuid; correlation_id uuid:=extensions.gen_random_uuid(); grant_row record; permission_code text; profile_ids uuid[]:=array[]::uuid[]; affected uuid[];
begin
  if tg_table_name='horse_person_relationships' and not exists(
    select 1 from public.horse_profile_permission_grants g
    where g.horse_person_relationship_id=new.id and g.status='active'
  ) then return new; end if;
  actor_id:=private.c003d_actor_profile_id();
  if tg_table_name='horse_person_relationships' and old.status='active' and new.status='ended' then
    for grant_row in
      update public.horse_profile_permission_grants grant_value set status='revoked',
        valid_until=case when grant_value.valid_until is null or grant_value.valid_until>pg_catalog.statement_timestamp() then greatest(pg_catalog.statement_timestamp(),grant_value.valid_from+interval '1 microsecond') else grant_value.valid_until end,
        terminal_reason_code='BOUND_RELATIONSHIP_ENDED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
        row_version=grant_value.row_version+1,updated_at=pg_catalog.clock_timestamp()
      where grant_value.horse_person_relationship_id=new.id and grant_value.status='active'
      returning grant_value.*
    loop
      select permission.code into permission_code from public.permission_definitions permission where permission.id=grant_row.permission_id;
      profile_ids:=pg_catalog.array_append(profile_ids,grant_row.grantee_profile_id);
      perform private.c003d_write_audit('permission.horse_profile_revoked','horse_profile_permission_grant',grant_row.id,
        'horse',grant_row.horse_id,actor_id,correlation_id,'HORSE_PERMISSION_REVOKED','active','revoked',
        grant_row.row_version-1,grant_row.row_version,null,null,pg_catalog.jsonb_build_object(
          'permission_code',permission_code,'target_profile_id',grant_row.grantee_profile_id::text,
          'relationship_id',new.id::text,'operation_code','bound_relationship_ended'));
    end loop;
    if pg_catalog.cardinality(profile_ids)>0 then
      perform private.c003c_bump_access(new.horse_id,profile_ids,actor_id,correlation_id,'bound_relationship_grants_revoked');
    end if;
  elsif tg_table_name='organization_horse_links' and old.status='active' and new.status='ended' then
    for grant_row in
      update public.horse_organization_role_permission_grants grant_value set status='revoked',
        valid_until=case when grant_value.valid_until is null or grant_value.valid_until>pg_catalog.statement_timestamp() then greatest(pg_catalog.statement_timestamp(),grant_value.valid_from+interval '1 microsecond') else grant_value.valid_until end,
        terminal_reason_code='BOUND_LINK_ENDED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
        row_version=grant_value.row_version+1,updated_at=pg_catalog.clock_timestamp()
      where grant_value.organization_horse_link_id=new.id and grant_value.status='active'
      returning grant_value.*
    loop
      select permission.code into permission_code from public.permission_definitions permission where permission.id=grant_row.permission_id;
      affected:=private.c003d_role_profile_ids(grant_row.role_id);
      profile_ids:=profile_ids||affected;
      perform private.c003d_write_audit('permission.horse_role_revoked','horse_role_permission_grant',grant_row.id,
        'horse',grant_row.horse_id,actor_id,correlation_id,'HORSE_PERMISSION_REVOKED','active','revoked',
        grant_row.row_version-1,grant_row.row_version,null,null,pg_catalog.jsonb_build_object(
          'permission_code',permission_code,'organization_id',grant_row.organization_id::text,
          'target_role_id',grant_row.role_id::text,'link_id',new.id::text,'operation_code','bound_link_ended'));
    end loop;
    if pg_catalog.cardinality(profile_ids)>0 then
      select pg_catalog.array_agg(distinct value) into profile_ids from unnest(profile_ids) value;
      perform private.c003c_bump_access(new.horse_id,profile_ids,actor_id,correlation_id,'bound_link_grants_revoked');
      perform private.c003b_bump_access(new.organization_id,array[]::uuid[],actor_id,correlation_id,'bound_link_grants_revoked');
    end if;
  end if;
  return new;
end;
$$;

-- Completed dependency metadata is accepted only for a durable prepared job.
create or replace function private.c003a_write_profile_audit(
  p_event_type text,
  p_profile_id uuid,
  p_actor_profile_id uuid,
  p_system_actor_code text,
  p_correlation_id uuid,
  p_channel text,
  p_old_status text,
  p_new_status text,
  p_row_version_before bigint,
  p_row_version_after bigint,
  p_access_version_before bigint,
  p_access_version_after bigint,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_id uuid;
  actor_kind_value text;
  reason_code_value text;
  changed_field text;
begin
  if p_event_type not in (
    'profile.provisioned',
    'profile.display_fields_updated',
    'profile.deletion_requested',
    'profile.auth_removal_prepared',
    'profile.anonymization_finalized',
    'profile.lifecycle_denied'
  ) then
    raise exception using errcode = '22023', message = 'AUDIT_EVENT_NOT_ALLOWED';
  end if;

  if p_profile_id is null or p_correlation_id is null then
    raise exception using errcode = '22004', message = 'AUDIT_IDENTIFIER_REQUIRED';
  end if;

  if (p_actor_profile_id is null) = (p_system_actor_code is null) then
    raise exception using errcode = '22023', message = 'AUDIT_ACTOR_SHAPE_INVALID';
  end if;

  actor_kind_value := case
    when p_actor_profile_id is not null then 'profile'
    else 'system'
  end;

  if p_system_actor_code is not null
    and p_system_actor_code not in (
      'auth_provisioner',
      'account_deletion_orchestrator',
      'profile_maintenance'
    )
  then
    raise exception using errcode = '22023', message = 'AUDIT_SYSTEM_ACTOR_INVALID';
  end if;

  if p_old_status is not null
    and p_old_status not in (
      'active',
      'deletion_pending',
      'auth_removal_pending',
      'anonymized'
    )
  then
    raise exception using errcode = '22023', message = 'AUDIT_OLD_STATUS_INVALID';
  end if;

  if p_new_status is not null
    and p_new_status not in (
      'active',
      'deletion_pending',
      'auth_removal_pending',
      'anonymized'
    )
  then
    raise exception using errcode = '22023', message = 'AUDIT_NEW_STATUS_INVALID';
  end if;

  p_metadata := coalesce(p_metadata, '{}'::jsonb);

  case p_event_type
    when 'profile.provisioned' then
      reason_code_value := 'AUTH_USER_CREATED';
      if p_metadata <> '{}'::jsonb then
        raise exception using errcode = '22023', message = 'AUDIT_METADATA_INVALID';
      end if;
    when 'profile.display_fields_updated' then
      reason_code_value := 'PROFILE_FIELDS_CHANGED';
      if pg_catalog.jsonb_typeof(p_metadata -> 'changed_fields') <> 'array'
        or (
          select pg_catalog.count(*)
          from pg_catalog.jsonb_object_keys(p_metadata)
        ) <> 1
      then
        raise exception using errcode = '22023', message = 'AUDIT_METADATA_INVALID';
      end if;
      for changed_field in
        select pg_catalog.jsonb_array_elements_text(p_metadata -> 'changed_fields')
      loop
        if changed_field not in (
          'display_name',
          'avatar_object_path',
          'locale',
          'phone_e164',
          'time_zone'
        ) then
          raise exception using errcode = '22023', message = 'AUDIT_CHANGED_FIELD_INVALID';
        end if;
      end loop;
    when 'profile.deletion_requested' then
      reason_code_value := 'USER_DELETION_REQUEST';
      if p_metadata <> '{}'::jsonb then
        raise exception using errcode = '22023', message = 'AUDIT_METADATA_INVALID';
      end if;
    when 'profile.auth_removal_prepared' then
      reason_code_value := 'C003A_AUTH_REMOVAL_PREPARED';
      if p_metadata not in ('{"dependency_checks_complete": false}'::jsonb,'{"dependency_checks_complete": true}'::jsonb)
        or (p_metadata='{"dependency_checks_complete": true}'::jsonb and not exists(
          select 1 from private.account_deletion_jobs job
          where job.profile_id=p_profile_id and job.correlation_id=p_correlation_id
        )) then
        raise exception using errcode = '22023', message = 'AUDIT_METADATA_INVALID';
      end if;
    when 'profile.anonymization_finalized' then
      reason_code_value := 'C003A_ANONYMIZATION_FINALIZED';
      if p_metadata not in ('{"dependency_checks_complete": false}'::jsonb,'{"dependency_checks_complete": true}'::jsonb)
        or (p_metadata='{"dependency_checks_complete": true}'::jsonb and not exists(
          select 1 from private.account_deletion_jobs job
          where job.profile_id=p_profile_id and job.correlation_id=p_correlation_id
        )) then
        raise exception using errcode = '22023', message = 'AUDIT_METADATA_INVALID';
      end if;
    when 'profile.lifecycle_denied' then
      reason_code_value := 'LIFECYCLE_REQUEST_DENIED';
      if pg_catalog.jsonb_typeof(p_metadata -> 'denial_code') <> 'string'
        or (
          select pg_catalog.count(*)
          from pg_catalog.jsonb_object_keys(p_metadata)
        ) <> 1
        or (p_metadata ->> 'denial_code') not in (
          'STALE_ROW_VERSION',
          'PROFILE_NOT_ACTIVE'
        )
      then
        raise exception using errcode = '22023', message = 'AUDIT_METADATA_INVALID';
      end if;
  end case;

  insert into public.audit_events (
    actor_kind,
    actor_profile_id,
    system_actor_code,
    event_type,
    resource_kind,
    resource_id,
    scope_kind,
    scope_id,
    old_state,
    new_state,
    reason_code,
    correlation_id,
    channel,
    row_version_before,
    row_version_after,
    access_version_before,
    access_version_after,
    metadata
  )
  values (
    actor_kind_value,
    p_actor_profile_id,
    p_system_actor_code,
    p_event_type,
    'profile',
    p_profile_id,
    'profile',
    p_profile_id,
    case
      when p_old_status is null then '{}'::jsonb
      else pg_catalog.jsonb_build_object('status', p_old_status)
    end,
    case
      when p_new_status is null then '{}'::jsonb
      else pg_catalog.jsonb_build_object('status', p_new_status)
    end,
    reason_code_value,
    p_correlation_id,
    p_channel,
    p_row_version_before,
    p_row_version_after,
    p_access_version_before,
    p_access_version_after,
    p_metadata
  )
  returning id into event_id;

  return event_id;
end;
$$;

create function private.c010_deletion_job_result(p_profile_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select pg_catalog.jsonb_build_object(
    'code',case when j.status='anonymized' then 'ACCOUNT_DELETED' else 'ACCOUNT_DELETION_PENDING' end,
    'status',j.status,'correlation_id',j.correlation_id,'profile_id',j.profile_id,
    'auth_user_id',j.auth_user_id,'avatar_paths',j.avatar_paths
  ) from private.account_deletion_jobs j where j.profile_id=p_profile_id
$$;

create function public.get_c010_account_deletion_job(p_request_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce((select private.c010_deletion_job_result(j.profile_id)
    from private.account_deletion_jobs j where j.correlation_id=p_request_id),
    '{"code":"DELETION_REQUEST_NOT_FOUND","status":"not_found"}'::jsonb)
$$;

create function public.get_my_c010_account_deletion_status()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare job private.account_deletion_jobs%rowtype;
begin
  if auth.uid() is null then raise exception using errcode='42501',message='AUTHENTICATION_REQUIRED'; end if;
  select * into job from private.account_deletion_jobs j where j.auth_user_id=auth.uid();
  if not found then return '{"code":"DELETION_REQUEST_NOT_FOUND","status":"not_found","correlation_id":null}'::jsonb; end if;
  return pg_catalog.jsonb_build_object('code',case when job.status='anonymized' then 'ACCOUNT_DELETED' else 'ACCOUNT_DELETION_PENDING' end,
    'status',job.status,'correlation_id',job.correlation_id);
end; $$;

-- The incomplete foundation request can no longer leave an account pending
-- before authority, Storage and legacy preflight. Its return signature survives.
create or replace function public.request_profile_deletion(p_expected_row_version bigint,p_correlation_id uuid)
returns table(result_code text,profile_status text,row_version bigint,access_version bigint,
  correlation_id uuid,applied boolean,production_ready boolean)
language plpgsql security definer set search_path='' as $$
declare profile public.profiles%rowtype;
begin
  select p.* into profile from public.profiles p where p.id=private.require_current_profile_id();
  return query select 'trusted_deletion_service_required'::text,profile.status,
    profile.row_version,profile.access_version,p_correlation_id,false,false;
end; $$;

create function public.prepare_c010_account_deletion(p_auth_user_id uuid,p_request_id uuid)
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

create function public.finalize_c010_account_deletion(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare job private.account_deletion_jobs%rowtype; before_profile public.profiles%rowtype; after_profile public.profiles%rowtype;
begin
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('c010:delete:request:'||p_request_id::text,0));
  select * into job from private.account_deletion_jobs j where j.correlation_id=p_request_id;
  if not found then return '{"code":"DELETION_REQUEST_NOT_FOUND","status":"not_found"}'::jsonb; end if;
  select * into before_profile from public.profiles p where p.id=job.profile_id for update;
  if job.status='anonymized' then return private.c010_deletion_job_result(job.profile_id); end if;
  if before_profile.status<>'auth_removal_pending' then raise exception using errcode='55000',message='ACCOUNT_DELETION_STATE_UNSUPPORTED'; end if;
  if before_profile.auth_user_id is not null or exists(select 1 from auth.users actor where actor.id=job.auth_user_id)
    or exists(select 1 from storage.objects object where object.owner=job.auth_user_id or object.owner_id=job.auth_user_id::text
      or (object.bucket_id='avatars' and pg_catalog.split_part(object.name,'/',1)=job.auth_user_id::text)) then
    return private.c010_deletion_job_result(job.profile_id);
  end if;
  update public.profiles p set status='anonymized',anonymized_at=pg_catalog.clock_timestamp(),access_version=p.access_version+1
  where p.id=job.profile_id returning p.* into after_profile;
  perform private.c003a_write_profile_audit('profile.anonymization_finalized',after_profile.id,null,'account_deletion_orchestrator',
    p_request_id,'system',before_profile.status,after_profile.status,before_profile.row_version,after_profile.row_version,
    before_profile.access_version,after_profile.access_version,'{"dependency_checks_complete":true}'::jsonb);
  update private.account_deletion_jobs j set status='anonymized' where j.profile_id=job.profile_id;
  return private.c010_deletion_job_result(job.profile_id);
end; $$;

revoke all on function private.c010_register_actor_reference(),private.c010_guard_deletion_actor_write(),
  private.c010_guard_live_profile_targets(),private.c010_deletion_job_result(uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.prepare_c010_account_deletion(uuid,uuid),public.get_c010_account_deletion_job(uuid),
  public.finalize_c010_account_deletion(uuid),public.get_my_c010_account_deletion_status()
  from public,anon,authenticated,service_role;
grant execute on function public.prepare_c010_account_deletion(uuid,uuid),public.get_c010_account_deletion_job(uuid),
  public.finalize_c010_account_deletion(uuid) to service_role;
grant execute on function public.get_my_c010_account_deletion_status() to authenticated;

comment on table private.account_actor_references is
  'Technical compatibility only: existing historical UUIDs map to durable profiles; no credentials or retention policy.';
comment on function public.prepare_c010_account_deletion(uuid,uuid) is
  'Trusted verified-actor preparation, canonical history preserved; authority, legacy or unsupported Storage refuses without changes.';
notify pgrst,'reload schema';
commit;
