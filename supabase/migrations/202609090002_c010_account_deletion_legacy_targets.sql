begin;

-- Close the remaining legacy intake race without converting any legacy data.
-- New/changed Auth references must serialize with account preparation. Existing
-- actor history stays untouched; no legacy FK is dropped or reference rewritten.
create function private.c010_guard_legacy_auth_targets()
returns trigger language plpgsql security definer set search_path='' as $$
declare value jsonb:=pg_catalog.to_jsonb(new); previous jsonb; field text; target uuid;
  targets uuid[]:='{}'; profile_status text;
begin
  if tg_op='UPDATE' then previous:=pg_catalog.to_jsonb(old); end if;
  foreach field in array tg_argv loop
    target:=nullif(value->>field,'')::uuid;
    if target is not null and (tg_op='INSERT' or value->field is distinct from previous->field) then
      targets:=pg_catalog.array_append(targets,target);
    end if;
  end loop;
  -- Legacy pending invitations do not yet set invitee_user_id. Their plaintext
  -- email is still a real retention footprint, so lock the resolved user too.
  if tg_table_name='stable_invitations' and
    (tg_op='INSERT' or value->>'status' in('pending','accepted') or value->'invited_email' is distinct from previous->'invited_email') then
    select actor.id into target from auth.users actor
    where pg_catalog.lower(pg_catalog.btrim(actor.email))=value->>'invited_email';
    if target is not null then targets:=pg_catalog.array_append(targets,target); end if;
  end if;
  for target in select distinct actor_id from pg_catalog.unnest(targets) ids(actor_id) order by actor_id loop
    select p.status into profile_status from public.profiles p
    join auth.users actor on actor.id=p.auth_user_id
    where actor.id=target for update of p;
    if profile_status is distinct from 'active' then
      raise exception using errcode='42501',message='ACTIVE_LEGACY_TARGET_PROFILE_REQUIRED';
    end if;
  end loop;
  return new;
end; $$;
revoke all on function private.c010_guard_legacy_auth_targets() from public,anon,authenticated,service_role;
create trigger c010_legacy_auth_target_before_write before insert or update on private.client_mutation_receipts
for each row execute function private.c010_guard_legacy_auth_targets('actor_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on private.horse_identifier_mutation_receipts
for each row execute function private.c010_guard_legacy_auth_targets('actor_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on private.horse_relationship_mutation_receipts
for each row execute function private.c010_guard_legacy_auth_targets('actor_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on private.stable_invitation_rate_events
for each row execute function private.c010_guard_legacy_auth_targets('actor_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.account_workspace_preferences
for each row execute function private.c010_guard_legacy_auth_targets('user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.client_sync_devices
for each row execute function private.c010_guard_legacy_auth_targets('actor_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.horse_access_grants
for each row execute function private.c010_guard_legacy_auth_targets('granted_by_user_id','revoked_by_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.horse_identifiers
for each row execute function private.c010_guard_legacy_auth_targets('created_by_user_id','last_mutated_by_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.horse_profile_change_events
for each row execute function private.c010_guard_legacy_auth_targets('actor_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.horse_relationships
for each row execute function private.c010_guard_legacy_auth_targets('created_by_user_id','ended_by_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.horses
for each row execute function private.c010_guard_legacy_auth_targets('created_by_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.legacy_import_jobs
for each row execute function private.c010_guard_legacy_auth_targets('actor_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.stable_invitations
for each row execute function private.c010_guard_legacy_auth_targets('invitee_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.stable_memberships
for each row execute function private.c010_guard_legacy_auth_targets('user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.stable_security_events
for each row execute function private.c010_guard_legacy_auth_targets('actor_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.stables
for each row execute function private.c010_guard_legacy_auth_targets('created_by_user_id');
create trigger c010_legacy_auth_target_before_write before insert or update on public.sync_conflicts
for each row execute function private.c010_guard_legacy_auth_targets('actor_user_id','resolved_by_user_id');

-- The preparation contract is identical apart from the missing email footprint.
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
