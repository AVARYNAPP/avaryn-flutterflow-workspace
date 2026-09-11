begin;
select extensions.no_plan();
create temporary table archive_actors(alias text primary key,auth_id uuid default gen_random_uuid(),profile_id uuid);
create temporary table archive_ids(key text primary key,id uuid,payload jsonb);
grant select,insert,update on archive_actors,archive_ids to authenticated,service_role;
insert into archive_actors(alias) values('owner'),('recipient'),('outsider'),('other_owner'),('other_recipient');
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000',auth_id,'authenticated','authenticated',
 alias||'-archive-transfer@example.invalid','',now(),'{}','{}',now(),now() from archive_actors;
update archive_actors actor set profile_id=profile.id from public.profiles profile where profile.auth_user_id=actor.auth_id;
create function pg_temp.archive_login(p_alias text) returns void language plpgsql as $$ begin
 perform set_config('request.jwt.claim.sub',(select auth_id::text from archive_actors where alias=p_alias),true);
end $$;
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
select pg_temp.archive_login('owner');
insert into archive_ids(key,id) select 'main',(public.create_c010_stable('Archived transfer main','Local',gen_random_uuid())->>'organization_id')::uuid;
insert into archive_ids(key,id) select 'task',(public.upsert_c010_stable_task(
 (select id from archive_ids where key='main'),null,null,'Retained task','Historical instruction','water','2026-09-09',null,
 (select profile_id from archive_actors where alias='owner'),'Water trough',null,null,gen_random_uuid())->>'task_id')::uuid;
select extensions.ok(not exists(select 1 from public.list_c010_my_archived_organizations() where organization_id=(select id from archive_ids where key='main')),'active organizations do not enter archive list');
select public.retire_c010_stable((select id from archive_ids where key='main'),
 (select row_version from public.organizations where id=(select id from archive_ids where key='main')),'Archived transfer main',gen_random_uuid());
select extensions.ok(exists(select 1 from public.list_c010_my_archived_organizations() where organization_id=(select id from archive_ids where key='main')),'active current primary can reach own archived organization');
select extensions.ok(not public.has_organization_permission((select id from archive_ids where key='main'),'organization.view'),'archive route does not restore operational read permission');
reset role;
create temporary table archive_before(key text primary key,payload jsonb);
insert into archive_before select 'organization',to_jsonb(o) from public.organizations o where id=(select id from archive_ids where key='main');
insert into archive_before select 'memberships',jsonb_agg(to_jsonb(m) order by id) from public.organization_memberships m where organization_id=(select id from archive_ids where key='main');
insert into archive_before select 'assignments',jsonb_agg(to_jsonb(m) order by id) from public.organization_membership_roles m where organization_id=(select id from archive_ids where key='main');
insert into archive_before select 'task',to_jsonb(t) from public.stable_tasks t where id=(select id from archive_ids where key='task');
insert into archive_before select 'events',jsonb_agg(to_jsonb(e) order by id) from public.stable_task_events e where task_id=(select id from archive_ids where key='task');
select set_config('request.jwt.claim.sub','',true);
set local role service_role;
select extensions.ok(public.prepare_c010_account_deletion((select auth_id from archive_actors where alias='owner'),gen_random_uuid())->>'code'='PRIMARY_ORGANIZATION_ADMIN_REQUIRED','archive authority blocks deletion before transfer');
reset role;
set local role authenticated;
select pg_temp.archive_login('outsider');
select extensions.ok(not exists(select 1 from public.list_c010_my_archived_organizations() where organization_id=(select id from archive_ids where key='main')),'outsider cannot enumerate another archive');
select extensions.throws_ok(format('select public.initiate_organization_authority_transfer_by_email(%L,%L,%L)',(select id from archive_ids where key='main'),'recipient-archive-transfer@example.invalid',gen_random_uuid()),'42501','PRIMARY_ORGANIZATION_ADMIN_REQUIRED','unauthorized known recipient refused before email lookup');
select extensions.throws_ok(format('select public.initiate_organization_authority_transfer_by_email(%L,%L,%L)',(select id from archive_ids where key='main'),'unknown-archive-transfer@example.invalid',gen_random_uuid()),'42501','PRIMARY_ORGANIZATION_ADMIN_REQUIRED','unauthorized unknown recipient gets same scope refusal');
select pg_temp.archive_login('owner');
select extensions.throws_ok(format('select public.initiate_organization_authority_transfer_by_email(%L,%L,%L)',(select id from archive_ids where key='main'),'owner-archive-transfer@example.invalid',gen_random_uuid()),'22023','ACTIVE_DISTINCT_RECIPIENT_REQUIRED','self transfer refused');
insert into archive_ids(key,id,payload) select 'transfer',transfer_id,to_jsonb(t) from public.initiate_organization_authority_transfer_by_email(
 (select id from archive_ids where key='main'),'recipient-archive-transfer@example.invalid',gen_random_uuid()) t;
select extensions.ok((select length(payload->>'transfer_token')=64 and payload->>'applied'='true' from archive_ids where key='transfer'),'existing seven-day token transfer accepts archive initiation');
select extensions.ok((select pending_transfer->>'id'=(select id::text from archive_ids where key='transfer') and not(pending_transfer?'recipient_profile_id') and not(pending_transfer?'transfer_token') from public.list_c010_my_archived_organizations() where organization_id=(select id from archive_ids where key='main')),'archive metadata is minimal and excludes tokens and recipient IDs');
select extensions.throws_ok(format('select public.initiate_organization_authority_transfer_by_email(%L,%L,%L)',(select id from archive_ids where key='main'),'recipient-archive-transfer@example.invalid',gen_random_uuid()),'55000','ORGANIZATION_TRANSFER_ALREADY_PENDING','only one pending request per archive');
select pg_temp.archive_login('outsider');
select extensions.ok(not exists(select 1 from public.preview_organization_authority_transfer((select payload->>'transfer_token' from archive_ids where key='transfer'))),'known token exposes no preview to wrong recipient');
select extensions.throws_ok(format('select public.respond_stable_authority_transfer(%L,%L,%L)',(select payload->>'transfer_token' from archive_ids where key='transfer'),'accept',gen_random_uuid()),'42501','TRANSFER_NOT_AVAILABLE','wrong recipient cannot accept');
select pg_temp.archive_login('recipient');
select extensions.ok(exists(select 1 from public.preview_organization_authority_transfer((select payload->>'transfer_token' from archive_ids where key='transfer')) where organization_name='Archived transfer main'),'existing preview token route works without an active stable');
select extensions.throws_ok(format('select public.respond_stable_authority_transfer(%L,null,%L)',(select payload->>'transfer_token' from archive_ids where key='transfer'),gen_random_uuid()),'22023','TRANSFER_ACTION_INVALID','null action cannot silently count as consent');
insert into archive_ids(key,id) values('accepted_request',gen_random_uuid());
insert into archive_ids(key,payload) select 'accepted',to_jsonb(r) from public.respond_stable_authority_transfer(
 (select payload->>'transfer_token' from archive_ids where key='transfer'),'accept',(select id from archive_ids where key='accepted_request')) r;
select extensions.ok((select payload->>'status'='accepted' and payload->>'applied'='true' from archive_ids where key='accepted'),'existing stable wrapper accepts terminal archive succession');
select extensions.ok(exists(select 1 from public.list_c010_my_archived_organizations() where organization_id=(select id from archive_ids where key='main')) and not public.has_organization_permission((select id from archive_ids where key='main'),'organization.view'),'recipient receives archive responsibility only, no operational access');
select extensions.throws_ok(format('select public.respond_stable_authority_transfer(%L,%L,%L)',(select payload->>'transfer_token' from archive_ids where key='transfer'),'accept',gen_random_uuid()),'42501','TRANSFER_NOT_AVAILABLE','terminal one-time token cannot accept twice');
select pg_temp.archive_login('owner');
select extensions.ok(not exists(select 1 from public.list_c010_my_archived_organizations() where organization_id=(select id from archive_ids where key='main')),'former primary no longer receives archive metadata');
reset role;
select extensions.ok((select o.primary_admin_profile_id=(select profile_id from archive_actors where alias='recipient') and o.status='archived' and to_jsonb(o)-array['primary_admin_profile_id','access_version','row_version','updated_at']=(select payload-array['primary_admin_profile_id','access_version','row_version','updated_at'] from archive_before where key='organization') from public.organizations o where id=(select id from archive_ids where key='main')),'scalar successor changes without altering archive identity, fields or closure');
select extensions.ok((select jsonb_agg(to_jsonb(m) order by id)=(select payload from archive_before where key='memberships') from public.organization_memberships m where organization_id=(select id from archive_ids where key='main')),'all ended memberships are byte-identical');
select extensions.ok((select jsonb_agg(to_jsonb(m) order by id)=(select payload from archive_before where key='assignments') from public.organization_membership_roles m where organization_id=(select id from archive_ids where key='main')),'all ended head-role assignments are byte-identical');
select extensions.ok((select to_jsonb(t)=(select payload from archive_before where key='task') from public.stable_tasks t where id=(select id from archive_ids where key='task')) and (select jsonb_agg(to_jsonb(e) order by id)=(select payload from archive_before where key='events') from public.stable_task_events e where task_id=(select id from archive_ids where key='task')),'task status, note and immutable event history preserved');
select extensions.ok((select count(*)=1 from public.audit_events where correlation_id=(select id from archive_ids where key='accepted_request') and event_type='organization.head_transfer_accepted'),'one immutable accepted transfer audit');
select set_config('request.jwt.claim.sub','',true);
set local role service_role;
insert into archive_ids(key,id,payload) select 'deletion',gen_random_uuid(),null;
update archive_ids set payload=public.prepare_c010_account_deletion((select auth_id from archive_actors where alias='owner'),id) where key='deletion';
select extensions.ok((select payload->>'status'='auth_removal_pending' from archive_ids where key='deletion'),'former archive primary now reaches existing trusted deletion preparation');
reset role;
delete from auth.users where id=(select auth_id from archive_actors where alias='owner');
set local role service_role;
select extensions.ok(public.finalize_c010_account_deletion((select id from archive_ids where key='deletion'))->>'status'='anonymized','existing Auth-removal/finalize path completes without deleting archive history');
reset role;
select extensions.ok(exists(select 1 from public.stable_tasks where id=(select id from archive_ids where key='task')) and exists(select 1 from public.organization_authority_transfers where id=(select id from archive_ids where key='transfer') and status='accepted'),'archive and transfer history survives former primary anonymization');

-- Compatibility plus a real active->retired transition invalidating a token.
set local role authenticated;
select pg_temp.archive_login('other_owner');
insert into archive_ids(key,id) select 'stale',(public.create_c010_stable('Archive stale example','Local',gen_random_uuid())->>'organization_id')::uuid;
insert into archive_ids(key,id,payload) select 'stale_transfer',transfer_id,to_jsonb(t) from public.initiate_organization_authority_transfer_by_email(
 (select id from archive_ids where key='stale'),'other_recipient-archive-transfer@example.invalid',gen_random_uuid()) t;
select public.retire_c010_stable((select id from archive_ids where key='stale'),(select row_version from public.organizations where id=(select id from archive_ids where key='stale')),'Archive stale example',gen_random_uuid());
select pg_temp.archive_login('other_recipient');
select extensions.throws_ok(format('select public.respond_stable_authority_transfer(%L,%L,%L)',(select payload->>'transfer_token' from archive_ids where key='stale_transfer'),'accept',gen_random_uuid()),'PT409','STALE_ORGANIZATION_ACCESS_VERSION','retirement changes access version and stale archive acceptance returns409');
select pg_temp.archive_login('other_owner');
select extensions.throws_ok(format('select public.revoke_organization_authority_transfer(%L,99,%L)',(select id from archive_ids where key='stale_transfer'),gen_random_uuid()),'PT409','STALE_TRANSFER_VERSION','archive revoke CAS also returns409');
select public.revoke_organization_authority_transfer((select id from archive_ids where key='stale_transfer'),1,gen_random_uuid());
insert into archive_ids(key,id,payload) select 'decline_transfer',transfer_id,to_jsonb(t) from public.initiate_organization_authority_transfer_by_email(
 (select id from archive_ids where key='stale'),'other_recipient-archive-transfer@example.invalid',gen_random_uuid()) t;
select pg_temp.archive_login('other_recipient');
select extensions.ok((select status='declined' from public.respond_stable_authority_transfer((select payload->>'transfer_token' from archive_ids where key='decline_transfer'),'decline',gen_random_uuid())),'recipient may decline archived responsibility');
reset role;
insert into archive_ids(key,id,payload) values('expired_transfer',gen_random_uuid(),jsonb_build_object('transfer_token',encode(extensions.gen_random_bytes(32),'hex')));
insert into public.organization_authority_transfers(id,organization_id,sender_profile_id,recipient_profile_id,access_version_at_create,token_digest,expires_at,creation_correlation_id,created_at,updated_at)
select t.id,o.id,(select profile_id from archive_actors where alias='other_owner'),(select profile_id from archive_actors where alias='other_recipient'),
 o.access_version,private.c003d_token_digest(t.payload->>'transfer_token'),now()-interval '1 day',gen_random_uuid(),now()-interval '8 days',now()-interval '8 days'
 from archive_ids t join public.organizations o on o.id=(select id from archive_ids where key='stale') where t.key='expired_transfer';
set local role authenticated;
select pg_temp.archive_login('other_recipient');
select extensions.ok((select status='expired' from public.respond_stable_authority_transfer((select payload->>'transfer_token' from archive_ids where key='expired_transfer'),'accept',gen_random_uuid())),'expired archive token terminates without acceptance');
reset role;
select extensions.ok((select primary_admin_profile_id=(select profile_id from archive_actors where alias='other_owner') from public.organizations where id=(select id from archive_ids where key='stale')),'decline, revoke, expiry and stale input never move authority');
set local role authenticated;
select pg_temp.archive_login('other_owner');
insert into archive_ids(key,id) select 'active',(public.create_c010_stable('Active compatibility','Local',gen_random_uuid())->>'organization_id')::uuid;
insert into archive_ids(key,id,payload) select 'active_transfer',transfer_id,to_jsonb(t) from public.initiate_organization_authority_transfer_by_email(
 (select id from archive_ids where key='active'),'other_recipient-archive-transfer@example.invalid',gen_random_uuid()) t;
select pg_temp.archive_login('other_recipient');
select public.respond_stable_authority_transfer((select payload->>'transfer_token' from archive_ids where key='active_transfer'),'accept',gen_random_uuid());
select extensions.ok(public.has_organization_permission((select id from archive_ids where key='active'),'organization.edit'),'existing active transfer still creates usable recipient head-admin rights');
reset role;
select extensions.ok((select status='active' and primary_admin_profile_id=(select profile_id from archive_actors where alias='other_recipient') from public.organizations where id=(select id from archive_ids where key='active')),'active organization remains active with its accepted successor');
select extensions.ok(not has_function_privilege('anon','public.list_c010_my_archived_organizations()','EXECUTE') and not has_function_privilege('service_role','public.list_c010_my_archived_organizations()','EXECUTE') and has_function_privilege('authenticated','public.list_c010_my_archived_organizations()','EXECUTE'),'archive list remains authenticated-only');
select extensions.ok(not has_table_privilege('authenticated','public.organization_authority_transfers','SELECT') and not has_table_privilege('authenticated','public.organizations','UPDATE'),'no direct table grant or transfer-history access added');
select * from extensions.finish();
rollback;
