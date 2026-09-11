begin;
select extensions.no_plan();
create temporary table archive_horse_actors(alias text primary key,auth_id uuid default gen_random_uuid(),profile_id uuid);
create temporary table archive_horse_values(key text primary key,id uuid,payload jsonb);
grant select,insert,update on archive_horse_actors,archive_horse_values to authenticated,service_role;
insert into archive_horse_actors(alias) values('owner'),('recipient'),('outsider'),('other_owner'),('other_recipient');
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000',auth_id,'authenticated','authenticated',
 alias||'-archived-horse@example.invalid','',now(),'{}','{}',now(),now() from archive_horse_actors;
update archive_horse_actors actor set profile_id=profile.id from public.profiles profile where profile.auth_user_id=actor.auth_id;
create function pg_temp.archived_horse_login(p_alias text) returns void language plpgsql as $$ begin
 perform set_config('request.jwt.claim.sub',(select auth_id::text from archive_horse_actors where alias=p_alias),true);
end $$;
create function pg_temp.archive_this_horse(p_id uuid) returns void language plpgsql as $$
declare h public.canonical_horses%rowtype;
begin
 select * into h from public.canonical_horses where id=p_id;
 perform public.update_canonical_horse_profile(h.id,h.row_version,h.display_name,h.official_name,h.birth_date,h.sex,
  h.breed,h.discipline,h.level,h.color,h.notes,h.chip_number,h.passport_number,h.passport_valid_until,'archived',gen_random_uuid());
end $$;
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
select pg_temp.archived_horse_login('owner');
insert into archive_horse_values(key,id) select 'main',horse_id from public.create_canonical_horse_profile(
 'Archive succession horse','Retained official name','2018-05-12','mare','KWPN','Dressuur','L','Brown','Preserve this instruction',null,null,null,gen_random_uuid());
select public.start_horse_person_ownership_by_email((select id from archive_horse_values where key='main'),
 'recipient-archived-horse@example.invalid',50,statement_timestamp(),gen_random_uuid());
select public.start_horse_person_relationship_by_email((select id from archive_horse_values where key='main'),
 'recipient-archived-horse@example.invalid','rider',statement_timestamp(),gen_random_uuid());
select extensions.ok(not exists(select 1 from public.list_c010_my_archived_horses()),'active horses are absent from archive list');
select pg_temp.archive_this_horse((select id from archive_horse_values where key='main'));
select extensions.ok(exists(select 1 from public.list_c010_my_archived_horses() where horse_id=(select id from archive_horse_values where key='main')),'current primary can find own archived horse');
select extensions.ok(public.has_canonical_horse_permission((select id from archive_horse_values where key='main'),'horse.view'),'existing primary archived-horse visibility remains unchanged');
select extensions.ok(exists(select 1 from public.list_c010_horses() where horse_id=(select id from archive_horse_values where key='main') and lifecycle_status='archived'),'regular horse list keeps its existing primary archive projection');
reset role;
create temporary table archive_horse_before(key text primary key,payload jsonb);
insert into archive_horse_before select 'horse',to_jsonb(h) from public.canonical_horses h where id=(select id from archive_horse_values where key='main');
insert into archive_horse_before select 'ownerships',jsonb_agg(to_jsonb(v) order by id) from public.horse_person_ownerships v where horse_id=(select id from archive_horse_values where key='main');
insert into archive_horse_before select 'relationships',jsonb_agg(to_jsonb(v) order by id) from public.horse_person_relationships v where horse_id=(select id from archive_horse_values where key='main');
insert into archive_horse_before select 'history',jsonb_agg(to_jsonb(v) order by id) from public.audit_events v where scope_id=(select id from archive_horse_values where key='main');
insert into archive_horse_before select 'permissions',jsonb_object_agg(code,private.c003c_profile_has_horse_permission((select profile_id from archive_horse_actors where alias='owner'),(select id from archive_horse_values where key='main'),code)) from unnest(array['horse.view','horse.edit','horse.manage','horse.assign','horse.share','horse.transfer','horse.planning.manage','horse.feeding.manage']) code;
select set_config('request.jwt.claim.sub','',true);
set local role service_role;
select extensions.ok(public.prepare_c010_account_deletion((select auth_id from archive_horse_actors where alias='owner'),gen_random_uuid())->>'code'='PRIMARY_HORSE_AUTHORITY_REQUIRED','archived scalar primary blocks deletion before transfer');
reset role;
set local role authenticated;
select pg_temp.archived_horse_login('outsider');
select extensions.ok(not exists(select 1 from public.list_c010_my_archived_horses()),'outsider cannot enumerate another archive');
select extensions.throws_ok(format('select public.initiate_horse_authority_transfer_by_email(%L,%L,%L)',(select id from archive_horse_values where key='main'),'recipient-archived-horse@example.invalid',gen_random_uuid()),'42501','PRIMARY_HORSE_AUTHORITY_REQUIRED','known email refused before unauthorized lookup');
select extensions.throws_ok(format('select public.initiate_horse_authority_transfer_by_email(%L,%L,%L)',(select id from archive_horse_values where key='main'),'unknown-archived-horse@example.invalid',gen_random_uuid()),'42501','PRIMARY_HORSE_AUTHORITY_REQUIRED','unknown email gets the same scope refusal');
select pg_temp.archived_horse_login('recipient');
select extensions.ok(not exists(select 1 from public.list_c010_my_archived_horses()),'legal ownership and rider relationship do not grant archive listing');
select pg_temp.archived_horse_login('owner');
select extensions.throws_ok(format('select public.initiate_horse_authority_transfer_by_email(%L,%L,%L)',(select id from archive_horse_values where key='main'),'owner-archived-horse@example.invalid',gen_random_uuid()),'22023','ACTIVE_DISTINCT_RECIPIENT_REQUIRED','self-transfer refused');
insert into archive_horse_values(key,id) values('create_request',gen_random_uuid());
insert into archive_horse_values(key,id,payload) select 'transfer',transfer_id,to_jsonb(t) from public.initiate_horse_authority_transfer_by_email(
 (select id from archive_horse_values where key='main'),'recipient-archived-horse@example.invalid',(select id from archive_horse_values where key='create_request')) t;
select extensions.ok((select length(payload->>'transfer_token')=64 and payload->>'applied'='true' from archive_horse_values where key='transfer'),'archived initiation returns the existing one-time token');
select extensions.ok((select pending_transfer->>'id'=(select id::text from archive_horse_values where key='transfer') and not(pending_transfer?'recipient_profile_id') and not(pending_transfer?'transfer_token') and not(pending_transfer?'auth_user_id') from public.list_c010_my_archived_horses() where horse_id=(select id from archive_horse_values where key='main')),'minimal archive metadata excludes private IDs and tokens');
select extensions.ok((select applied=false and transfer_token is null and transfer_id=(select id from archive_horse_values where key='transfer') from public.initiate_horse_authority_transfer_by_email((select id from archive_horse_values where key='main'),'recipient-archived-horse@example.invalid',(select id from archive_horse_values where key='create_request'))),'same request replays existing transfer without another token');
select extensions.throws_ok(format('select public.initiate_horse_authority_transfer_by_email(%L,%L,%L)',(select id from archive_horse_values where key='main'),'outsider-archived-horse@example.invalid',(select id from archive_horse_values where key='create_request')),'22023','REQUEST_ID_REUSED','same request cannot silently change recipient');
select extensions.throws_ok(format('select public.initiate_horse_authority_transfer_by_email(%L,%L,%L)',(select id from archive_horse_values where key='main'),'recipient-archived-horse@example.invalid',gen_random_uuid()),'55000','HORSE_TRANSFER_ALREADY_PENDING','second pending request refused');
select pg_temp.archived_horse_login('outsider');
select extensions.ok(not exists(select 1 from public.preview_horse_authority_transfer((select payload->>'transfer_token' from archive_horse_values where key='transfer'))),'wrong recipient cannot preview a known token');
select extensions.throws_ok(format('select public.respond_horse_authority_transfer(%L,%L,%L)',(select payload->>'transfer_token' from archive_horse_values where key='transfer'),'accept',gen_random_uuid()),'42501','TRANSFER_NOT_AVAILABLE','wrong recipient cannot accept');
select pg_temp.archived_horse_login('recipient');
select extensions.ok(exists(select 1 from public.preview_horse_authority_transfer((select payload->>'transfer_token' from archive_horse_values where key='transfer')) where horse_name='Archive succession horse'),'intended recipient previews without operational horse access');
select extensions.throws_ok(format('select public.respond_horse_authority_transfer(%L,null,%L)',(select payload->>'transfer_token' from archive_horse_values where key='transfer'),gen_random_uuid()),'22023','TRANSFER_ACTION_INVALID','missing action is not acceptance');
insert into archive_horse_values(key,id) values('accepted_request',gen_random_uuid());
insert into archive_horse_values(key,payload) select 'accepted',to_jsonb(r) from public.respond_horse_authority_transfer(
 (select payload->>'transfer_token' from archive_horse_values where key='transfer'),'accept',(select id from archive_horse_values where key='accepted_request')) r;
select extensions.ok((select payload->>'status'='accepted' and payload->>'applied'='true' from archive_horse_values where key='accepted'),'explicit acceptance transfers archived responsibility');
select extensions.ok(exists(select 1 from public.list_c010_my_archived_horses() where horse_id=(select id from archive_horse_values where key='main')) and public.has_canonical_horse_permission((select id from archive_horse_values where key='main'),'horse.view'),'recipient gets archive responsibility under existing canonical primary permissions');
select extensions.throws_ok(format('select public.respond_horse_authority_transfer(%L,%L,%L)',(select payload->>'transfer_token' from archive_horse_values where key='transfer'),'accept',(select id from archive_horse_values where key='accepted_request')),'42501','TRANSFER_NOT_AVAILABLE','terminal token cannot accept twice');
select pg_temp.archived_horse_login('owner');
select extensions.ok(not exists(select 1 from public.list_c010_my_archived_horses()),'former primary no longer sees archive metadata');
reset role;
select extensions.ok((select h.primary_authority_profile_id=(select profile_id from archive_horse_actors where alias='recipient') and h.status='archived' and to_jsonb(h)-array['primary_authority_profile_id','authority_version','access_version','row_version','updated_at']=(select payload-array['primary_authority_profile_id','authority_version','access_version','row_version','updated_at'] from archive_horse_before where key='horse') from public.canonical_horses h where id=(select id from archive_horse_values where key='main')),'only successor and versions change; every profile field and archive date survive');
select extensions.ok((select h.authority_version=(b.payload->>'authority_version')::bigint+1 and h.access_version=(b.payload->>'access_version')::bigint+1 and h.row_version=(b.payload->>'row_version')::bigint+1 from public.canonical_horses h cross join archive_horse_before b where h.id=(select id from archive_horse_values where key='main') and b.key='horse'),'authority, access and row versions each advance once');
select extensions.ok((select jsonb_agg(to_jsonb(v) order by id)=(select payload from archive_horse_before where key='ownerships') from public.horse_person_ownerships v where horse_id=(select id from archive_horse_values where key='main')),'legal ownership rows remain byte-identical');
select extensions.ok((select jsonb_agg(to_jsonb(v) order by id)=(select payload from archive_horse_before where key='relationships') from public.horse_person_relationships v where horse_id=(select id from archive_horse_values where key='main')),'person relationships remain byte-identical');
select extensions.ok(not exists(select 1 from jsonb_array_elements((select payload from archive_horse_before where key='history')) b where not exists(select 1 from public.audit_events e where to_jsonb(e)=b)),'existing immutable audit entries survive byte-identically');
select extensions.ok((select count(*)=1 from public.audit_events where correlation_id=(select id from archive_horse_values where key='accepted_request') and event_type='horse.authority_transfer_accepted'),'exactly one accepted audit event');
select extensions.ok(not exists(select 1 from public.horse_profile_permission_grants where horse_id=(select id from archive_horse_values where key='main')) and not exists(select 1 from public.horse_delegated_administrators where horse_id=(select id from archive_horse_values where key='main')),'succession creates no grants or delegated administrators');
select extensions.ok((select jsonb_object_agg(code,private.c003c_profile_has_horse_permission((select profile_id from archive_horse_actors where alias='recipient'),(select id from archive_horse_values where key='main'),code))=(select payload from archive_horse_before where key='permissions') from unnest(array['horse.view','horse.edit','horse.manage','horse.assign','horse.share','horse.transfer','horse.planning.manage','horse.feeding.manage']) code),'successor permissions exactly match former primary; permission helper is unchanged');
select set_config('request.jwt.claim.sub','',true);
set local role service_role;
select extensions.ok(public.prepare_c010_account_deletion((select auth_id from archive_horse_actors where alias='recipient'),gen_random_uuid())->>'code'='PRIMARY_HORSE_AUTHORITY_REQUIRED','accepted successor remains protected by the last-primary condition');
insert into archive_horse_values(key,id) values('deletion',gen_random_uuid());
update archive_horse_values set payload=public.prepare_c010_account_deletion((select auth_id from archive_horse_actors where alias='owner'),id) where key='deletion';
select extensions.ok((select payload->>'status'='auth_removal_pending' from archive_horse_values where key='deletion'),'former primary can enter existing deletion preparation');
reset role;
delete from auth.users where id=(select auth_id from archive_horse_actors where alias='owner');
set local role service_role;
select extensions.ok(public.finalize_c010_account_deletion((select id from archive_horse_values where key='deletion'))->>'status'='anonymized','existing unlink/finalize completes for former primary');
reset role;
select extensions.ok(exists(select 1 from public.canonical_horses where id=(select id from archive_horse_values where key='main') and status='archived') and exists(select 1 from public.horse_authority_transfers where id=(select id from archive_horse_values where key='transfer') and status='accepted'),'horse and accepted transfer history survive former-owner deletion');

set local role authenticated;
select pg_temp.archived_horse_login('other_owner');
insert into archive_horse_values(key,id) select 'other',horse_id from public.create_canonical_horse_profile('Other archive',null,null,'unknown',null,null,null,null,null,null,null,null,gen_random_uuid());
select pg_temp.archive_this_horse((select id from archive_horse_values where key='other'));
insert into archive_horse_values(key,id,payload) select 'revocable',transfer_id,to_jsonb(t) from public.initiate_horse_authority_transfer_by_email((select id from archive_horse_values where key='other'),'other_recipient-archived-horse@example.invalid',gen_random_uuid()) t;
select extensions.throws_ok(format('select public.revoke_horse_authority_transfer(%L,99,%L)',(select id from archive_horse_values where key='revocable'),gen_random_uuid()),'PT409','STALE_TRANSFER_VERSION','archive revoke CAS uses bounded HTTP409');
select extensions.throws_ok(format('select public.revoke_horse_authority_transfer(%L,null,%L)',(select id from archive_horse_values where key='revocable'),gen_random_uuid()),'PT409','STALE_TRANSFER_VERSION','missing archive version cannot bypass CAS');
select extensions.ok((select status='revoked' and applied from public.revoke_horse_authority_transfer((select id from archive_horse_values where key='revocable'),1,gen_random_uuid())),'sender can revoke an archive transfer');
select extensions.ok((select status='revoked' and not applied from public.revoke_horse_authority_transfer((select id from archive_horse_values where key='revocable'),1,gen_random_uuid())),'revoke retry does not create a second terminal transition');
insert into archive_horse_values(key,id,payload) select 'declinable',transfer_id,to_jsonb(t) from public.initiate_horse_authority_transfer_by_email((select id from archive_horse_values where key='other'),'other_recipient-archived-horse@example.invalid',gen_random_uuid()) t;
select pg_temp.archived_horse_login('other_recipient');
select extensions.ok((select status='declined' from public.respond_horse_authority_transfer((select payload->>'transfer_token' from archive_horse_values where key='declinable'),'decline',gen_random_uuid())),'recipient may decline archived responsibility');
reset role;
insert into archive_horse_values(key,id,payload) values('expired',gen_random_uuid(),jsonb_build_object('transfer_token',encode(extensions.gen_random_bytes(32),'hex')));
insert into public.horse_authority_transfers(id,horse_id,sender_profile_id,recipient_profile_id,authority_version_at_create,token_digest,expires_at,creation_correlation_id,created_at,updated_at)
select t.id,h.id,(select profile_id from archive_horse_actors where alias='other_owner'),(select profile_id from archive_horse_actors where alias='other_recipient'),h.authority_version,
 private.c003d_token_digest(t.payload->>'transfer_token'),now()-interval '1 day',gen_random_uuid(),now()-interval '8 days',now()-interval '8 days'
 from archive_horse_values t join public.canonical_horses h on h.id=(select id from archive_horse_values where key='other') where t.key='expired';
set local role authenticated;
select pg_temp.archived_horse_login('other_recipient');
select extensions.ok((select status='expired' from public.respond_horse_authority_transfer((select payload->>'transfer_token' from archive_horse_values where key='expired'),'accept',gen_random_uuid())),'expired archive token terminates without acceptance');
reset role;
insert into archive_horse_values(key,id,payload) values('stale',gen_random_uuid(),jsonb_build_object('transfer_token',encode(extensions.gen_random_bytes(32),'hex')));
insert into public.horse_authority_transfers(id,horse_id,sender_profile_id,recipient_profile_id,authority_version_at_create,token_digest,expires_at,creation_correlation_id,created_at,updated_at)
select t.id,h.id,(select profile_id from archive_horse_actors where alias='other_owner'),(select profile_id from archive_horse_actors where alias='other_recipient'),h.authority_version+1,
 private.c003d_token_digest(t.payload->>'transfer_token'),now()+interval '7 days',gen_random_uuid(),now(),now()
 from archive_horse_values t join public.canonical_horses h on h.id=(select id from archive_horse_values where key='other') where t.key='stale';
set local role authenticated;
select pg_temp.archived_horse_login('other_recipient');
select extensions.throws_ok(format('select public.respond_horse_authority_transfer(%L,%L,%L)',(select payload->>'transfer_token' from archive_horse_values where key='stale'),'accept',gen_random_uuid()),'PT409','STALE_HORSE_AUTHORITY_VERSION','stale archive authority snapshot is a bounded conflict');
reset role;
select extensions.ok((select primary_authority_profile_id=(select profile_id from archive_horse_actors where alias='other_owner') and status='archived' from public.canonical_horses where id=(select id from archive_horse_values where key='other')),'decline, expiry and stale snapshots never move primary or reopen horse');
set local role authenticated;
select pg_temp.archived_horse_login('other_owner');
insert into archive_horse_values(key,id) select 'active',horse_id from public.create_canonical_horse_profile('Active compatibility',null,null,'unknown',null,null,null,null,null,null,null,null,gen_random_uuid());
insert into archive_horse_values(key,id,payload) select 'active_transfer',transfer_id,to_jsonb(t) from public.initiate_horse_authority_transfer_by_email((select id from archive_horse_values where key='active'),'other_recipient-archived-horse@example.invalid',gen_random_uuid()) t;
select pg_temp.archived_horse_login('other_recipient');
select public.respond_horse_authority_transfer((select payload->>'transfer_token' from archive_horse_values where key='active_transfer'),'accept',gen_random_uuid());
select extensions.ok(public.has_canonical_horse_permission((select id from archive_horse_values where key='active'),'horse.edit'),'existing active transfer retains actual primary permission');
reset role;
select extensions.ok((select status='active' and primary_authority_profile_id=(select profile_id from archive_horse_actors where alias='other_recipient') from public.canonical_horses where id=(select id from archive_horse_values where key='active')),'active transfer remains active and accepted');
select extensions.ok(not has_function_privilege('anon','public.list_c010_my_archived_horses()','EXECUTE') and not has_function_privilege('service_role','public.list_c010_my_archived_horses()','EXECUTE') and has_function_privilege('authenticated','public.list_c010_my_archived_horses()','EXECUTE'),'archive list is authenticated-only');
select extensions.ok(not has_table_privilege('authenticated','public.horse_authority_transfers','SELECT') and not has_table_privilege('authenticated','public.canonical_horses','UPDATE'),'no direct table permission added');
set local role authenticated;
select set_config('request.jwt.claim.sub','',true);
select extensions.throws_ok('select public.list_c010_my_archived_horses()','42501',null,'missing actual actor cannot list archives');
reset role;
select * from extensions.finish();
rollback;
