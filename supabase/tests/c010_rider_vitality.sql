begin;
set local statement_timeout='25s';
select extensions.no_plan();
create temporary table vitality_actors(alias text primary key,auth_id uuid default gen_random_uuid(),profile_id uuid);
create temporary table vitality_values(key text primary key,value jsonb);
grant select,insert,update on vitality_actors,vitality_values to authenticated,service_role;
insert into vitality_actors(alias) values('owner'),('other');
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000',auth_id,'authenticated','authenticated',
  alias||'-vitality@example.invalid','',now(),'{}','{}',now(),now() from vitality_actors;
update vitality_actors a set profile_id=p.id from public.profiles p where p.auth_user_id=a.auth_id;
-- This existing suite exercises Amsterdam; account defaults are not assumed.
update public.profiles p set time_zone='Europe/Amsterdam' where p.id in(select profile_id from vitality_actors);
create function pg_temp.v_login(who text) returns void language sql as $$
  select set_config('request.jwt.claim.sub',(select auth_id::text from vitality_actors where alias=who),true)::void
$$;
create function pg_temp.v_doc() returns jsonb language sql immutable as $$
  select '{"warmup":{"minutes":5,"status":"done","steps":[0,1,2,3,4]},
    "reflection":{"person":"Rustig","horse":"Energiek","focus":"Eigen fictieve reflectie","sharingIntent":"later"},
    "focus":"Persoonlijk fictief focuspunt",
    "routines":{"basic":{"currentStep":4,"completed":[0,1,2,3,4],"status":"done"},
      "extended":{"currentStep":1,"completed":[0],"status":"later"},
      "dressage":{"currentStep":0,"completed":[],"status":"in_progress"}}}'::jsonb
$$;
insert into vitality_values values('save_request',to_jsonb(gen_random_uuid())),('delete_request',to_jsonb(gen_random_uuid()));
create function pg_temp.v_request(keyname text) returns uuid language sql as $$
  select (value#>>'{}')::uuid from vitality_values where key=keyname
$$;
select extensions.ok(not has_table_privilege('authenticated','private.c010_vitality_days','SELECT'),'no direct read of personal day table');
select extensions.ok(not has_table_privilege('authenticated','private.c010_vitality_days','INSERT,UPDATE,DELETE'),'no direct personal content writes');
select extensions.ok(not has_table_privilege('service_role','private.c010_vitality_days','SELECT'),'no new general service content grant');
select extensions.ok(not has_table_privilege('authenticated','private.c010_vitality_receipts','SELECT'),'private receipts cannot be read');
select extensions.ok((select bool_and(relrowsecurity) from pg_class where oid in('private.c010_vitality_days'::regclass,'private.c010_vitality_receipts'::regclass)),'RLS enabled on both private tables');
select extensions.ok(not has_function_privilege('anon','public.get_c010_my_vitality_day(date)','EXECUTE'),'anonymous read denied');
select extensions.ok(not has_function_privilege('anon','public.save_c010_my_vitality_day(date,bigint,jsonb,uuid)','EXECUTE'),'anonymous save denied');
select extensions.ok(not has_function_privilege('anon','public.delete_c010_my_vitality_day(date,bigint,uuid)','EXECUTE'),'anonymous delete denied');
select extensions.ok(not has_function_privilege('authenticated','private.c010v_mutate(date,bigint,jsonb,uuid,boolean)','EXECUTE'),'internal mutation cannot bypass actorless API');
select extensions.ok(not exists(select 1 from pg_constraint where conrelid in('private.c010_vitality_days'::regclass,'private.c010_vitality_receipts'::regclass) and confrelid='auth.users'::regclass),'no new Auth UUID foreign keys');
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
select pg_temp.v_login('owner');
select extensions.is(public.get_c010_my_vitality_day('2026-09-11')->>'row_version','0','unsaved day has expected version zero');
select extensions.is(public.get_c010_my_vitality_day('2026-09-11')->>'exists','false','unsaved day reports absence');
select extensions.is(public.get_c010_my_vitality_day('2026-09-11')->'document','{"warmup":null,"reflection":null,"focus":"","routines":{}}'::jsonb,'empty document matches existing UI shape');
select extensions.is(public.get_c010_my_vitality_day()->>'on_date',public.get_c010_calendar_context()->>'today_date','default date uses existing server day');
set local timezone='Pacific/Honolulu';
select extensions.is(public.get_c010_my_vitality_day()->'calendar'->>'time_zone','Europe/Amsterdam','session timezone cannot change calendar contract');
select extensions.is(public.get_c010_my_vitality_day('2026-10-25')->>'on_date','2026-10-25','DST autumn remains an explicit civil date');
select extensions.is(public.get_c010_my_vitality_day('2027-03-28')->>'on_date','2027-03-28','DST spring remains an explicit civil date');
select extensions.throws_ok($$select public.get_c010_my_vitality_day('infinity')$$,'22023','C010_VITALITY_DATE_INVALID','infinite day refused');
select extensions.throws_ok($$select public.save_c010_my_vitality_day(null,0,'{}',gen_random_uuid())$$,'22023','C010_VITALITY_DATE_INVALID','writes require explicit captured day');
select extensions.throws_ok($$select public.save_c010_my_vitality_day('2026-09-11',null,'{}',gen_random_uuid())$$,'22023','C010_VITALITY_VERSION_REQUIRED','save requires explicit CAS version');
select extensions.throws_ok($$select public.save_c010_my_vitality_day('2026-09-11',0,'{}',null)$$,'22023','C010_REQUEST_ID_REQUIRED','request id required');
select extensions.is(public.save_c010_my_vitality_day('2026-09-11',0,pg_temp.v_doc(),pg_temp.v_request('save_request'))->>'row_version','1','first whole-day save succeeds');
select extensions.is(public.get_c010_my_vitality_day('2026-09-11')->'document',pg_temp.v_doc(),'all routine/reflection/focus values round trip exactly');
select extensions.is(public.save_c010_my_vitality_day('2026-09-11',0,pg_temp.v_doc(),pg_temp.v_request('save_request'))->>'idempotent','true','same request returns receipt');
select extensions.is(public.get_c010_my_vitality_day('2026-09-11')->>'row_version','1','replay does not advance version');
select extensions.throws_ok($$select public.save_c010_my_vitality_day('2026-09-11',0,'{}',pg_temp.v_request('save_request'))$$,'22023','C010_VITALITY_IDEMPOTENCY_CONFLICT','same request with another payload rejected');
select extensions.throws_ok($$select public.save_c010_my_vitality_day('2026-09-11',0,'{}',gen_random_uuid())$$,'PT409','C010_VITALITY_VERSION_STALE','stale save is an HTTP409 business conflict');
select extensions.throws_ok($$select public.delete_c010_my_vitality_day('2026-09-11',0,gen_random_uuid())$$,'PT409','C010_VITALITY_VERSION_STALE','stale delete cannot erase current content');
select extensions.throws_ok('select * from private.c010_vitality_days','42501',null,'authenticated direct SELECT cannot read another owner');

-- Each invalid document is tested through the real public write boundary.
select extensions.throws_ok(format('select public.save_c010_my_vitality_day(%L,1,%L::jsonb,gen_random_uuid())','2026-09-11',value),
  '22023','C010_VITALITY_DOCUMENT_INVALID',label)
from (values
 ('null','null document refused'),('[]','array document refused'),
 ('{"actor_id":"other"}','caller-supplied identity refused'),
 ('{"focus":null}','null focus refused'),('{"focus":5}','non-text focus refused'),
 ('{"reflection":{"person":"Diagnose"}}','unknown feeling refused'),
 ('{"reflection":{"sharingIntent":"public"}}','public sharing claim refused'),
 ('{"reflection":{"score":100}}','unrecognized medical score refused'),
 ('{"warmup":{"minutes":15,"status":"later","steps":[]}}','unsupported duration refused'),
 ('{"warmup":{"minutes":5,"status":"done","steps":[0]}}','incomplete warmup cannot claim done'),
 ('{"warmup":{"minutes":5,"status":"later","steps":[0,0]}}','duplicate steps refused'),
 ('{"warmup":{"minutes":5,"status":"later","steps":["0"]}}','string step refused'),
 ('{"routines":{"jumping":{"currentStep":0,"completed":[],"status":"later"}}}','unreleased routine refused'),
 ('{"routines":{"basic":{"currentStep":5,"completed":[],"status":"later"}}}','out of range step refused'),
 ('{"routines":{"basic":{"currentStep":0,"completed":[],"status":"done"}}}','incomplete routine cannot claim done'),
 ('{"routines":{"basic":{"currentStep":0,"completed":[],"status":"later","note":"x"}}}','unknown nested field refused')
) invalid(value,label);
select extensions.throws_ok(format('select public.save_c010_my_vitality_day(%L,1,%L::jsonb,gen_random_uuid())','2026-09-11',jsonb_build_object('focus',repeat('x',501))),
 '22023','C010_VITALITY_DOCUMENT_INVALID','focus is bounded to 500 characters');
select extensions.is(public.get_c010_my_vitality_day('2026-09-11')->'document',pg_temp.v_doc(),'failed writes preserve prior content');

-- Existing performance sharing rights do not silently widen this private scope.
select public.grant_rider_performance_profile_share(profile_id,'vitality',null,now(),null,gen_random_uuid()) from vitality_actors where alias='other';
select pg_temp.v_login('other');
select extensions.ok(public.has_rider_performance_share((select profile_id from vitality_actors where alias='owner'),'vitality',null),'fixture has explicit existing performance sharing grant');
select extensions.is(public.get_c010_my_vitality_day('2026-09-11')->>'exists','false','explicit sharing still cannot expose private Vitality day');
select extensions.is(public.save_c010_my_vitality_day('2026-09-11',0,'{"focus":"Other personal content"}',pg_temp.v_request('save_request'))->>'row_version','1','request id is isolated per owner');
select extensions.is(public.get_c010_my_vitality_day('2026-09-11')->'document'->>'focus','Other personal content','other actor reads only own document');
select pg_temp.v_login('owner');
select extensions.is(public.get_c010_my_vitality_day('2026-09-11')->'document',pg_temp.v_doc(),'second actor writes cannot alter first actor');
select extensions.is(public.delete_c010_my_vitality_day('2026-09-11',1,pg_temp.v_request('delete_request'))->>'row_version','2','explicit deletion advances monotonic version');
select extensions.is(public.get_c010_my_vitality_day('2026-09-11')->>'exists','false','deleted content is absent');
select extensions.is(public.get_c010_my_vitality_day('2026-09-11')->>'row_version','2','deleted day retains only CAS tombstone');
select extensions.is(public.delete_c010_my_vitality_day('2026-09-11',1,pg_temp.v_request('delete_request'))->>'idempotent','true','deletion replay is safe');
select extensions.throws_ok($$select public.save_c010_my_vitality_day('2026-09-11',0,pg_temp.v_doc(),pg_temp.v_request('save_request'))$$,'PT409','C010_VITALITY_VERSION_STALE','old save receipt cannot resurrect explicitly deleted content');
select extensions.is(public.save_c010_my_vitality_day('2026-09-11',2,pg_temp.v_doc(),gen_random_uuid())->>'row_version','3','explicit re-create requires latest tombstone version');
select public.save_c010_my_vitality_day('2026-09-12',0,'{"focus":"Second day"}',gen_random_uuid());
reset role;
select extensions.is((select count(*)::integer from private.c010_vitality_receipts where profile_id=(select profile_id from vitality_actors where alias='owner') and operation='save' and result::text like '%Eigen fictieve reflectie%'),0,'receipts never retain reflection text');
select extensions.is((select count(*)::integer from public.audit_events where to_jsonb(audit_events)::text like '%Eigen fictieve reflectie%'),0,'reflection is absent from general audit');
select extensions.is((select count(*)::integer from private.c010_vitality_receipts where profile_id=(select profile_id from vitality_actors where alias='owner') and request_id=pg_temp.v_request('save_request')),0,'day deletion removed earlier payload fingerprint');

-- The actual trusted deletion preparation must atomically erase all owner days.
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','service_role',true);
set local role service_role;
insert into vitality_values select 'deletion',public.prepare_c010_account_deletion(auth_id,gen_random_uuid()) from vitality_actors where alias='owner';
reset role;
select extensions.is((select value->>'status' from vitality_values where key='deletion'),'auth_removal_pending','canonical lifecycle preparation succeeds');
select extensions.is((select count(*)::integer from private.c010_vitality_days where profile_id=(select profile_id from vitality_actors where alias='owner')),0,'lifecycle erases every personal day and tombstone');
select extensions.is((select count(*)::integer from private.c010_vitality_receipts where profile_id=(select profile_id from vitality_actors where alias='owner')),0,'lifecycle erases private retry metadata');
select extensions.is((select count(*)::integer from private.c010_vitality_days where profile_id=(select profile_id from vitality_actors where alias='other')),1,'lifecycle preserves other actor data');
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
select pg_temp.v_login('owner');
select extensions.throws_ok($$select public.get_c010_my_vitality_day('2026-09-11')$$,'42501','ACTIVE_PROFILE_REQUIRED','pending actor cannot read through old JWT');
select extensions.throws_ok($$select public.save_c010_my_vitality_day('2026-09-11',0,'{}',pg_temp.v_request('save_request'))$$,'42501','ACTIVE_PROFILE_REQUIRED','pending actor cannot replay a write');
select extensions.throws_ok($$select public.delete_c010_my_vitality_day('2026-09-11',0,gen_random_uuid())$$,'42501','ACTIVE_PROFILE_REQUIRED','pending actor cannot mutate deletion state');
select pg_temp.v_login('other');
select extensions.is(public.get_c010_my_vitality_day('2026-09-11')->'document'->>'focus','Other personal content','remaining actor still reads own content');
reset role;
select * from extensions.finish();
rollback;
