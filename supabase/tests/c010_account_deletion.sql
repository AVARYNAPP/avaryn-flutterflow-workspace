begin;
set local statement_timeout='20s';
select extensions.plan(1);

-- Only synthetic transaction-local identities; every row is rolled back.
create temporary table deletion_fixture(owner_user uuid,member_user uuid,other_user uuid,email_user uuid,
  owner_profile uuid,member_profile uuid,other_profile uuid,horse_id uuid,org_id uuid,
  schedule_id uuid,version_id uuid,request_id uuid,history_before jsonb,legacy_schedule_id uuid,legacy_stable_id uuid);
grant select,update on pg_temp.deletion_fixture to authenticated,service_role;
insert into deletion_fixture(owner_user,member_user,other_user,email_user,request_id) values(
  'c010dd00-0000-4000-8000-000000000001','c010dd00-0000-4000-8000-000000000002',
  'c010dd00-0000-4000-8000-000000000003','c010dd00-0000-4000-8000-000000000005','c010dd10-0000-4000-8000-000000000001');
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000'::uuid,id,'authenticated','authenticated',
  'deletion-'||id::text||'@example.invalid','',now(),'{}','{}',now(),now()
from (select owner_user id from deletion_fixture union all select member_user from deletion_fixture
  union all select other_user from deletion_fixture union all select email_user from deletion_fixture) actors;
update deletion_fixture f set
  owner_profile=(select id from public.profiles where auth_user_id=f.owner_user),
  member_profile=(select id from public.profiles where auth_user_id=f.member_user),
  other_profile=(select id from public.profiles where auth_user_id=f.other_user);

do $$ begin
  if (select count(*) from pg_constraint k where k.contype='f'
      and k.confrelid='private.account_actor_references'::regclass)<>26 then
    raise exception 'expected 25 immutable history FKs plus one private job FK'; end if;
  if (select count(*) from pg_trigger where not tgisinternal
      and tgfoid='private.c010_guard_legacy_auth_targets()'::regprocedure)<>17 then
    raise exception 'remaining legacy Auth target guard surface is incomplete'; end if;
  if not exists(select 1 from pg_constraint where conrelid='public.profiles'::regclass
      and confrelid='auth.users'::regclass and confdeltype='n') then raise exception 'real profile Auth unlink lost'; end if;
  if has_function_privilege('authenticated','public.prepare_c010_account_deletion(uuid,uuid)','EXECUTE')
    or has_function_privilege('anon','public.get_c010_account_deletion_job(uuid)','EXECUTE')
    or has_function_privilege('authenticated','public.finalize_c010_account_deletion(uuid)','EXECUTE')
    or has_table_privilege('authenticated','private.account_deletion_jobs','SELECT')
    or has_table_privilege('service_role','private.account_actor_references','INSERT')
    or has_function_privilege('service_role','private.c010_deletion_job_result(uuid)','EXECUTE') then
    raise exception 'deletion privilege boundary widened'; end if;
end; $$;

-- Credential UUIDs are private for every historical row, not just a UI projection.
-- Invoke as a different, still-authorized horse owner at BOTH lifecycle stages.
-- Preserve the actual service privileges of this environment. Managed and local
-- defaults can differ; deletion must neither add nor remove those privileges.
create temporary table deletion_service_column_baseline as
select c.relname table_name,a.attname column_name,
  has_column_privilege('service_role',c.oid,a.attnum,'SELECT') service_select
from pg_constraint k join pg_class c on c.oid=k.conrelid
join pg_namespace n on n.oid=c.relnamespace
join pg_attribute a on a.attrelid=c.oid and a.attnum=any(k.conkey)
where k.contype='f' and n.nspname='public'
  and k.confrelid='private.account_actor_references'::regclass;
grant select on deletion_service_column_baseline to authenticated;
create function pg_temp.assert_history_privacy() returns void language plpgsql as $$
declare item record; payload text; begin
  for item in select c.relname table_name,a.attname column_name
    from pg_constraint k join pg_class c on c.oid=k.conrelid
    join pg_namespace n on n.oid=c.relnamespace
    join pg_attribute a on a.attrelid=c.oid and a.attnum=any(k.conkey)
    where k.contype='f' and n.nspname='public'
      and k.confrelid=(select c2.oid from pg_class c2 join pg_namespace n2 on n2.oid=c2.relnamespace
        where n2.nspname='private' and c2.relname='account_actor_references')
  loop
    if has_column_privilege('authenticated','public.'||item.table_name,item.column_name,'SELECT')
      or has_column_privilege('anon','public.'||item.table_name,item.column_name,'SELECT')
      or has_column_privilege('service_role','public.'||item.table_name,item.column_name,'SELECT')
        is distinct from (select service_select from pg_temp.deletion_service_column_baseline baseline
          where baseline.table_name=item.table_name and baseline.column_name=item.column_name) then
      raise exception 'historical Auth column boundary failed: %.%',item.table_name,item.column_name; end if;
    begin
      execute format('select %I from public.%I limit 1',item.column_name,item.table_name);
      raise exception 'direct historical Auth projection accepted: %.%',item.table_name,item.column_name;
    exception when insufficient_privilege then null; end;
    -- Non-sensitive direct reads retain the original RLS decision.
    execute format('select id from public.%I limit 1',item.table_name);
  end loop;
  if (select count(*) from pg_constraint k join pg_class c on c.oid=k.conrelid
      join pg_namespace n on n.oid=c.relnamespace where k.contype='f' and n.nspname='public'
      and k.confrelid=(select c2.oid from pg_class c2 join pg_namespace n2 on n2.oid=c2.relnamespace
        where n2.nspname='private' and c2.relname='account_actor_references'))<>20 then
    raise exception 'historical column probe did not cover all 20 public Auth references'; end if;
  begin perform id,status from public.media_assets where uploaded_by_user_id=(select member_user from deletion_fixture);
    raise exception 'hidden Auth filter accepted'; exception when insufficient_privilege then null; end;
  payload:=public.get_canonical_horse_feeding((select horse_id from deletion_fixture))::text;
  if strpos(payload,(select member_user::text from deletion_fixture))>0 then raise exception 'canonical feeding leaked Auth UUID'; end if;
  select coalesce(jsonb_agg(to_jsonb(s)),'[]')::text into payload
    from public.list_canonical_horse_schedule((select horse_id from deletion_fixture),now()-interval '1 day',now()+interval '3 days') s;
  if payload='[]' then raise exception 'authorized schedule history disappeared'; end if;
  if strpos(payload,(select member_user::text from deletion_fixture))>0 then raise exception 'canonical planning leaked Auth UUID'; end if;
  payload:=public.get_canonical_horse_workspace((select horse_id from deletion_fixture))::text;
  if strpos(payload,(select member_user::text from deletion_fixture))>0 then raise exception 'canonical workspace leaked Auth UUID'; end if;
end; $$;
grant execute on function pg_temp.assert_history_privacy() to authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',(select owner_user::text from deletion_fixture),true);
set local role authenticated;
with value as(select * from public.create_canonical_horse_profile('Deletion history horse',null,null,'unknown',
  null,null,null,null,null,null,null,null,'c010dd20-0000-4000-8000-000000000001'))
update deletion_fixture f set horse_id=value.horse_id from value;
reset role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','service_role',true);
set local role service_role;
do $$ declare result jsonb; begin
  result:=public.prepare_c010_account_deletion((select owner_user from deletion_fixture),gen_random_uuid());
  if result->>'code'<>'PRIMARY_HORSE_AUTHORITY_REQUIRED' or result->>'status'<>'blocked' then
    raise exception 'horse-only primary authority was not blocked'; end if;
end; $$;
reset role;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',(select owner_user::text from deletion_fixture),true);
set local role authenticated;
select * from public.grant_horse_profile_permission((select horse_id from deletion_fixture),
  (select member_profile from deletion_fixture),'horse.view',null,now(),null,'MANUAL_GRANT','c010dd20-0000-4000-8000-000000000002');
select * from public.grant_horse_profile_permission((select horse_id from deletion_fixture),
  (select member_profile from deletion_fixture),'horse.edit',null,now(),null,'MANUAL_GRANT','c010dd20-0000-4000-8000-000000000003');
select public.start_horse_person_relationship((select horse_id from deletion_fixture),
  (select member_profile from deletion_fixture),'groom',now(),'c010dd20-0000-4000-8000-000000000004');
with value as(select * from public.create_organization('stable','Deletion owner organization',null,
  'c010dd20-0000-4000-8000-000000000005','{}')) update deletion_fixture f set org_id=value.organization_id from value;
select set_config('request.jwt.claim.sub',(select member_user::text from deletion_fixture),true);
do $$ declare response record; before_value record; begin
  select * into before_value from public.get_current_account_profile();
  select * into response from public.request_profile_deletion(before_value.row_version,gen_random_uuid());
  if response.result_code<>'trusted_deletion_service_required' or response.applied or response.production_ready
    or response.profile_status<>'active' or response.row_version<>before_value.row_version then
    raise exception 'old public foundation request mutated before preflight'; end if;
  begin perform public.prepare_c010_account_deletion((select owner_user from deletion_fixture),gen_random_uuid());
    raise exception 'authenticated spoofed a deletion actor'; exception when insufficient_privilege then null; end;
end; $$;
with value as(select public.upsert_canonical_horse_schedule_item((select horse_id from deletion_fixture),null,null,
  'training','Preserved deletion history','Synthetic, no clinical conclusion','normal',now()+interval '1 day',
  now()+interval '25 hours','Europe/Amsterdam','planned',null,'c010dd30-0000-4000-8000-000000000001') result)
update deletion_fixture f set schedule_id=(value.result->>'schedule_item_id')::uuid from value;
with value as(select public.create_canonical_horse_feeding_plan((select horse_id from deletion_fixture),'standard',
  'Preserved synthetic feeding',current_date,null,'Synthetic only','c010dd30-0000-4000-8000-000000000002') result)
update deletion_fixture f set version_id=(value.result->>'feeding_plan_version_id')::uuid from value;
select public.upsert_canonical_horse_feeding_item((select horse_id from deletion_fixture),(select version_id from deletion_fixture),
  null,null,'hay',null,'Synthetic hay',null,0.1,'kg','bucket','ochtend','07:30',null,null,
  'deletion-synthetic','Synthetic record, no feeding advice','c010dd30-0000-4000-8000-000000000003');
select public.create_canonical_media_upload_session((select horse_id from deletion_fixture),'synthetic.png','image/png',
  'c010dd30-0000-4000-8000-000000000004');
-- Transaction-local analogue of the byte-verified Edge transition.
reset role;
update public.media_asset_variants set status='ready',mime_type=expected_mime_type,byte_size=128,
  sha256=decode(repeat('00',32),'hex'),ready_at=statement_timestamp()
where media_asset_id in(select id from public.media_assets where created_request_id='c010dd30-0000-4000-8000-000000000004');
update public.media_assets set status='ready',mime_type=expected_mime_type,byte_size=128,
  sha256=decode(repeat('00',32),'hex'),ready_at=statement_timestamp()
where created_request_id='c010dd30-0000-4000-8000-000000000004';
set local role authenticated;
do $$ declare recovered jsonb; begin
  recovered:=public.get_c010_my_media_upload_status('c010dd30-0000-4000-8000-000000000004');
  if recovered->>'status'<>'ready' or (select count(*) from jsonb_object_keys(recovered))<>2 then
    raise exception 'own ready upload recovery unavailable or exposes extra fields'; end if;
  if public.get_c010_my_media_upload_status(gen_random_uuid()) is not null then raise exception 'unknown upload request leaked'; end if;
  perform set_config('request.jwt.claim.sub',(select owner_user::text from deletion_fixture),true);
  if public.get_c010_my_media_upload_status('c010dd30-0000-4000-8000-000000000004') is not null then
    raise exception 'other authorized horse owner recovered someone else upload'; end if;
  perform set_config('request.jwt.claim.sub',(select member_user::text from deletion_fixture),true);
end; $$;
-- A former primary reaches deletion after an actually accepted transfer.
-- This also creates both C010 receipt families using authenticated APIs.
do $$ declare created jsonb; role_value record; transfer_value record; org uuid; begin
  created:=public.create_c010_stable('Transferred deletion fixture','Synthetic',gen_random_uuid());
  org:=(created->>'organization_id')::uuid;
  perform public.update_c010_stable_facilities(org,
    (select row_version from public.stable_facilities where organization_id=org),
    1,0,0,0,false,0,0,false,0,gen_random_uuid());
  select * into role_value from public.create_organization_role(org,'delete_viewer','Deletion viewer',null,
    array['organization.view'],gen_random_uuid());
  perform public.grant_organization_membership_role((created->>'membership_id')::uuid,role_value.role_id,now(),gen_random_uuid());
  select * into transfer_value from public.initiate_organization_authority_transfer(org,
    (select owner_profile from deletion_fixture),gen_random_uuid());
  perform set_config('request.jwt.claim.sub',(select owner_user::text from deletion_fixture),true);
  perform public.respond_organization_authority_transfer(transfer_value.transfer_token,'accept',gen_random_uuid());
  perform set_config('request.jwt.claim.sub',(select member_user::text from deletion_fixture),true);
end; $$;
-- An unsupported legacy footprint remains entirely intact and blocks early.
select set_config('request.jwt.claim.sub',(select other_user::text from deletion_fixture),true);
do $$ declare legacy jsonb; begin
  legacy:=public.create_stable('Legacy refusal fixture','UTC','organization','nl',gen_random_uuid(),'Synthetic legacy actor',null);
  update deletion_fixture set legacy_stable_id=(legacy->>'stable_id')::uuid,
    legacy_schedule_id=(public.create_schedule_item((legacy->>'stable_id')::uuid,null,'task','horse.schedule',
      'Historical actor projection','Synthetic execution history','normal','2026-09-08 07:00+00','2026-09-08 08:00+00',
      'UTC','2026-09-08','07:00',gen_random_uuid())->>'schedule_item_id')::uuid;
  perform public.record_schedule_execution((select legacy_schedule_id from deletion_fixture),gen_random_uuid(),
    'partial','2026-09-08 07:05+00','2026-09-08 07:15+00','2026-09-08 07:15','UTC','online',null,'Synthetic partial execution');
  perform public.create_stable_invitation((legacy->>'stable_id')::uuid,
    'deletion-'||(select email_user::text from deletion_fixture)||'@example.invalid','viewer',repeat('a',64),null,gen_random_uuid());
end; $$;
reset role;
select set_config('request.jwt.claim.sub','',true);

create function pg_temp.history_hash() returns jsonb language plpgsql as $$
declare item record; value text; hashes jsonb:='{}'; actor uuid:=(select member_user from pg_temp.deletion_fixture);
begin
  for item in select n.nspname schema_name,c.relname table_name,
      string_agg(format('value.%I=$1',a.attname),' or ') predicate
    from pg_constraint k join pg_class c on c.oid=k.conrelid join pg_namespace n on n.oid=c.relnamespace
    join pg_attribute a on a.attrelid=c.oid and a.attnum=any(k.conkey)
    where k.contype='f' and k.confrelid='private.account_actor_references'::regclass
      and c.relname<>'account_deletion_jobs' group by n.nspname,c.relname
  loop
    execute format('select md5(coalesce(jsonb_agg(to_jsonb(value) order by to_jsonb(value)::text)::text,''[]'')) from %I.%I value where %s',
      item.schema_name,item.table_name,item.predicate) into value using actor;
    hashes:=hashes||jsonb_build_object(item.schema_name||'.'||item.table_name,value);
  end loop;
  return hashes;
end; $$;
update deletion_fixture set history_before=pg_temp.history_hash();
select set_config('request.jwt.claim.role','service_role',true);
set local role service_role;
do $$ declare result jsonb; begin
  result:=public.prepare_c010_account_deletion((select email_user from deletion_fixture),gen_random_uuid());
  if result->>'status'<>'blocked' or result->>'code'<>'LEGACY_RETENTION_REQUIRED' then
    raise exception 'email-only legacy invitation footprint not blocked: %',result->>'code'; end if;
  result:=public.prepare_c010_account_deletion((select other_user from deletion_fixture),gen_random_uuid());
  if result->>'status'<>'blocked' or result->>'code'<>'LEGACY_RETENTION_REQUIRED' then
    raise exception 'legacy footprint not blocked before mutation'; end if;
  result:=public.prepare_c010_account_deletion((select owner_user from deletion_fixture),gen_random_uuid());
  if result->>'status'<>'blocked' or result->>'code'<>'PRIMARY_ORGANIZATION_ADMIN_REQUIRED' then
    raise exception 'primary organization authority not blocked before mutation'; end if;
  result:=public.prepare_c010_account_deletion((select member_user from deletion_fixture),(select request_id from deletion_fixture));
  if result->>'status'<>'auth_removal_pending' or result->>'code'<>'ACCOUNT_DELETION_PENDING'
    or jsonb_array_length(result->'avatar_paths')<>0 then raise exception 'trusted preparation failed: %',result->>'code'; end if;
  if public.prepare_c010_account_deletion((select member_user from deletion_fixture),gen_random_uuid()) is distinct from result then
    raise exception 'second request did not reuse exact profile job'; end if;
  if public.get_c010_account_deletion_job((select request_id from deletion_fixture)) is distinct from result then
    raise exception 'trusted job resume mismatch'; end if;
  if public.finalize_c010_account_deletion((select request_id from deletion_fixture)) is distinct from result then
    raise exception 'premature finalization claimed deletion while Auth exists'; end if;
  if public.prepare_c010_account_deletion((select other_user from deletion_fixture),(select request_id from deletion_fixture))->>'code'<>'DELETION_REQUEST_CONFLICT' then
    raise exception 'request correlation can target second profile'; end if;
end; $$;
reset role;
do $$ begin
  if (select status from public.profiles where id=(select owner_profile from deletion_fixture))<>'active' then
    raise exception 'blocked owner changed'; end if;
  if exists(select 1 from public.horse_profile_permission_grants where grantee_profile_id=(select member_profile from deletion_fixture) and status='active')
    or exists(select 1 from public.horse_person_relationships where profile_id=(select member_profile from deletion_fixture) and status='active') then
    raise exception 'active dependency survived preparation'; end if;
  if exists(select 1 from public.organization_memberships m where m.profile_id=(select member_profile from deletion_fixture) and m.status in('active','suspended'))
    or exists(select 1 from public.organization_membership_roles r join public.organization_memberships m on m.id=r.membership_id
      where m.profile_id=(select member_profile from deletion_fixture) and r.status='active') then
    raise exception 'organization membership/role survived preparation'; end if;
  if not exists(select 1 from private.c010_mutation_receipts where actor_user_id=(select member_user from deletion_fixture))
    or not exists(select 1 from private.c010_round1_receipts where actor_user_id=(select member_user from deletion_fixture)) then
    raise exception 'C010 history test did not create actual receipts'; end if;
  if (select history_before from deletion_fixture) is distinct from pg_temp.history_hash() then raise exception 'preparation rewrote domain history'; end if;
  if not exists(select 1 from public.profiles where id=(select member_profile from deletion_fixture)
    and status='auth_removal_pending' and first_name is null and last_name is null and avatar_object_path is null
    and phone_e164 is null and display_name='Deleted AVARYN account') then raise exception 'identifying profile fields survived preparation'; end if;
end; $$;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',(select owner_user::text from deletion_fixture),true);
set local role authenticated;
select pg_temp.assert_history_privacy();
select set_config('request.jwt.claim.sub',(select member_user::text from deletion_fixture),true);
do $$ declare status jsonb; begin
  begin perform public.get_c010_my_media_upload_status('c010dd30-0000-4000-8000-000000000004');
    raise exception 'pending actor recovered media'; exception when insufficient_privilege then null; end;
  status:=public.get_my_c010_account_deletion_status();
  if status->>'status'<>'auth_removal_pending' or (select count(*) from jsonb_object_keys(status))<>3 then
    raise exception 'minimal own status missing or leaks private job fields'; end if;
  if exists(select 1 from public.schedule_items where id=(select schedule_id from deletion_fixture)) then
    raise exception 'pending JWT reads canonical schedule'; end if;
  begin perform public.get_canonical_horse_feeding((select horse_id from deletion_fixture));
    raise exception 'pending JWT reads canonical feeding'; exception when insufficient_privilege then null; end;
  begin perform public.create_stable('Forbidden pending legacy','UTC','personal','nl',gen_random_uuid(),'Must not exist',null);
    raise exception 'pending JWT creates legacy stable'; exception when insufficient_privilege then null; end;
  begin perform public.create_canonical_media_upload_session((select horse_id from deletion_fixture),'synthetic.png','image/png',
    'c010dd30-0000-4000-8000-000000000004');
    raise exception 'pending JWT replays media receipt'; exception when insufficient_privilege then null; end;
end; $$;
select set_config('request.jwt.claim.sub',(select other_user::text from deletion_fixture),true);
do $$ begin
  if public.get_my_c010_account_deletion_status()->>'status'<>'not_found' then raise exception 'other actor reads deletion job'; end if;
end; $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','service_role',true);
-- Trusted Auth deletion is simulated only for this transaction-local fixture.
delete from auth.users where id=(select member_user from deletion_fixture);
set local role service_role;
do $$ declare result jsonb; begin
  result:=public.finalize_c010_account_deletion((select request_id from deletion_fixture));
  if result->>'status'<>'anonymized' or result->>'code'<>'ACCOUNT_DELETED' then raise exception 'finalization failed'; end if;
  if public.finalize_c010_account_deletion((select request_id from deletion_fixture)) is distinct from result then
    raise exception 'finalization replay changed job'; end if;
end; $$;
reset role;
do $$ begin
  if (select history_before from deletion_fixture) is distinct from pg_temp.history_hash() then raise exception 'Auth deletion or finalization rewrote history'; end if;
  if (select count(*) from public.audit_events where resource_id=(select member_profile from deletion_fixture)
      and event_type='profile.anonymization_finalized')<>1 then raise exception 'terminal audit missing or duplicated'; end if;
  if not exists(select 1 from public.profiles where id=(select member_profile from deletion_fixture)
      and status='anonymized' and auth_user_id is null and anonymized_at is not null) then raise exception 'terminal profile invalid'; end if;
end; $$;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',(select owner_user::text from deletion_fixture),true);
set local role authenticated;
select pg_temp.assert_history_privacy();
select set_config('request.jwt.claim.sub',(select member_user::text from deletion_fixture),true);
do $$ begin
  if public.get_my_c010_account_deletion_status()->>'code'<>'ACCOUNT_DELETED' then raise exception 'lost-response status not recoverable'; end if;
  begin perform public.create_stable('Forbidden deleted legacy','UTC','personal','nl',gen_random_uuid(),'Must not exist',null);
    raise exception 'deleted JWT creates legacy stable'; exception when insufficient_privilege then null; end;
  if exists(select 1 from public.schedule_items) then raise exception 'deleted JWT reads schedule'; end if;
end; $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values(
  '00000000-0000-0000-0000-000000000000','c010dd00-0000-4000-8000-000000000004',
  'authenticated','authenticated','archived-deletion@example.invalid','',now(),'{}','{}',now(),now());
select set_config('request.jwt.claim.sub','c010dd00-0000-4000-8000-000000000004',true);
set local role authenticated;
do $$ declare created jsonb; retired jsonb; begin
  created:=public.create_c010_stable('Archived deletion fixture',null,gen_random_uuid());
  retired:=public.retire_c010_stable((created->>'organization_id')::uuid,(created->>'row_version')::bigint,
    'Archived deletion fixture',gen_random_uuid());
  if retired->>'status'<>'archived' then raise exception 'archived boundary fixture failed'; end if;
end; $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
do $$ declare before_value jsonb; result jsonb; begin
  select to_jsonb(p) into before_value from public.profiles p where auth_user_id='c010dd00-0000-4000-8000-000000000004';
  result:=public.prepare_c010_account_deletion('c010dd00-0000-4000-8000-000000000004',gen_random_uuid());
  if result->>'code'<>'PRIMARY_ORGANIZATION_ADMIN_REQUIRED' or result->>'status'<>'blocked'
    or before_value is distinct from (select to_jsonb(p) from public.profiles p where auth_user_id='c010dd00-0000-4000-8000-000000000004') then
    raise exception 'archived primary bypassed blocker or suffered partial deletion'; end if;
end; $$;

-- A legacy footprint is intentionally blocked from real deletion. This
-- controlled pending fixture tests the two legacy projection branches without
-- rewriting a history row or claiming a supported legacy account deletion.
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',(select other_user::text from deletion_fixture),true);
set local role authenticated;
do $$ begin
  if (select count(*) from public.list_schedule_executions((select legacy_schedule_id from deletion_fixture))
    where actor_user_id=(select other_user from deletion_fixture))<>1 then raise exception 'active execution actor compatibility lost'; end if;
  if (select count(*) from public.list_schedule_calendar((select legacy_stable_id from deletion_fixture),'2026-09-08','2026-09-08')
    where execution_actor_user_id=(select other_user from deletion_fixture))<>1 then raise exception 'active calendar actor compatibility lost'; end if;
end; $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
update public.profiles set status='deletion_pending',access_version=access_version+1 where id=(select other_profile from deletion_fixture);
update public.profiles set status='auth_removal_pending',access_version=access_version+1 where id=(select other_profile from deletion_fixture);
select set_config('request.jwt.claim.sub',(select other_user::text from deletion_fixture),true);
set local role authenticated;
do $$ begin
  if (select count(*) from public.list_schedule_executions((select legacy_schedule_id from deletion_fixture))
    where actor_user_id is null)<>1 then raise exception 'pending execution actor was not redacted'; end if;
  if (select count(*) from public.list_schedule_calendar((select legacy_stable_id from deletion_fixture),'2026-09-08','2026-09-08')
    where execution_actor_user_id is null)<>1 then raise exception 'pending calendar actor was not redacted'; end if;
end; $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
-- Recreate an original pre-C003A identity shape at INSERT only. The test trigger
-- affects exactly this synthetic UUID, is removed immediately, and all rolls back.
-- No existing profile ID, historical record, or managed Auth trigger is changed.
create function pg_temp.legacy_profile_fixture_id() returns trigger language plpgsql as $$
begin new.id:=new.auth_user_id; return new; end; $$;
create trigger a_c010_legacy_identity_fixture before insert on public.profiles
for each row when(new.auth_user_id='c010dd00-0000-4000-8000-000000000006'::uuid)
execute function pg_temp.legacy_profile_fixture_id();
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values(
  '00000000-0000-0000-0000-000000000000','c010dd00-0000-4000-8000-000000000006',
  'authenticated','authenticated','legacy-identity-deletion@example.invalid','',now(),'{}','{}',now(),now());
drop trigger a_c010_legacy_identity_fixture on public.profiles;
do $$ declare before_value jsonb; result jsonb; begin
  select to_jsonb(p) into before_value from public.profiles p where id='c010dd00-0000-4000-8000-000000000006';
  if before_value is null then raise exception 'legacy identity fixture not established'; end if;
  result:=public.prepare_c010_account_deletion('c010dd00-0000-4000-8000-000000000006',gen_random_uuid());
  if result->>'code'<>'LEGACY_RETENTION_REQUIRED' or result->>'status'<>'blocked'
    or before_value is distinct from(select to_jsonb(p) from public.profiles p where id='c010dd00-0000-4000-8000-000000000006')
    or exists(select 1 from private.account_deletion_jobs where auth_user_id='c010dd00-0000-4000-8000-000000000006') then
    raise exception 'legacy profile identity was anonymized or partially changed'; end if;
end; $$;
select extensions.pass('C010 trusted deletion: ACL, blockers, immutable canonical history, old JWT, replay and recovery');
select * from extensions.finish();
rollback;
