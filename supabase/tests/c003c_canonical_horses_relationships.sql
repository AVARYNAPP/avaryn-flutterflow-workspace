begin;

select extensions.plan(1);

create temporary table c003c_fixture (
  auth_a uuid not null, auth_b uuid not null, auth_c uuid not null, auth_d uuid not null,
  profile_a uuid, profile_b uuid, profile_c uuid, profile_d uuid,
  horse_a uuid, horse_b uuid,
  stable_org uuid, stable_org_2 uuid, other_org uuid,
  delegation uuid, person_ownership uuid, org_ownership uuid,
  relationship uuid, inactive_relationship uuid, residency uuid, link uuid
);
grant select,update on pg_temp.c003c_fixture to authenticated,anon,service_role;

insert into pg_temp.c003c_fixture(auth_a,auth_b,auth_c,auth_d) values
  ('c003c000-0000-4000-8000-000000000001',
   'c003c000-0000-4000-8000-000000000002',
   'c003c000-0000-4000-8000-000000000003',
   'c003c000-0000-4000-8000-000000000004');

insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000'::uuid,auth_a,'authenticated','authenticated',
  'c003c-a@example.invalid','',now(),'{}'::jsonb,'{"stable_id":"spoof","horse_id":"spoof","role":"platform_admin"}'::jsonb,now(),now()
from pg_temp.c003c_fixture
union all select '00000000-0000-0000-0000-000000000000'::uuid,auth_b,'authenticated','authenticated',
  'c003c-b@example.invalid','',now(),'{}'::jsonb,'{"primary_authority_profile_id":"spoof"}'::jsonb,now(),now()
from pg_temp.c003c_fixture
union all select '00000000-0000-0000-0000-000000000000'::uuid,auth_c,'authenticated','authenticated',
  'c003c-c@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c003c_fixture
union all select '00000000-0000-0000-0000-000000000000'::uuid,auth_d,'authenticated','authenticated',
  'c003c-d@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c003c_fixture;

update pg_temp.c003c_fixture f set
  profile_a=(select id from public.profiles where auth_user_id=f.auth_a),
  profile_b=(select id from public.profiles where auth_user_id=f.auth_b),
  profile_c=(select id from public.profiles where auth_user_id=f.auth_c),
  profile_d=(select id from public.profiles where auth_user_id=f.auth_d);

do $$
begin
  if (select array_agg(code order by code) from public.horse_relationship_types)
    <> array['care_provider','groom','professional_treatment','rider','trainer']
    or (select array_agg(code order by code) from public.organization_horse_link_types)
    <> array['care_provider','farrier_provider','other','training_provider','veterinary_provider']
  then raise exception 'C-003C catalog seeds are not exact'; end if;
  if to_regclass('public.horses') is null or to_regclass('public.canonical_horses') is null
    or exists(select 1 from information_schema.columns where table_schema='public'
      and table_name='canonical_horses' and column_name='stable_id')
  then raise exception 'Canonical/legacy horse isolation is invalid'; end if;
end $$;

-- Anonymous and service role have neither direct table access nor RPC access.
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','anon',true);
set local role anon;
do $$ begin
  begin perform count(*) from public.horse_relationship_types; raise exception 'anon read catalog';
  exception when insufficient_privilege then null; end;
  begin perform public.create_canonical_horse('attack',null,'unknown',null,gen_random_uuid(),'{}'); raise exception 'anon created horse';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.role','service_role',true);
set local role service_role;
do $$ begin
  begin truncate public.canonical_horses; raise exception 'service role truncated horses';
  exception when insufficient_privilege then null; end;
  begin perform public.create_canonical_horse('attack',null,'unknown',null,gen_random_uuid(),'{}'); raise exception 'service role created horse';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- A creates two horses. Spoofed client/JWT authority is ignored and replay is idempotent.
select set_config('request.jwt.claim.sub',(select auth_a::text from pg_temp.c003c_fixture),true);
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claims',jsonb_build_object('sub',(select auth_a from pg_temp.c003c_fixture),
  'role','authenticated','stable_id',gen_random_uuid(),'primary_authority_profile_id',(select profile_b from pg_temp.c003c_fixture))::text,true);
set local role authenticated;
with created as (
  select * from public.create_canonical_horse('Canonical A','2016-05-01','mare','KWPN',
    'c003c100-0000-4000-8000-000000000001',jsonb_build_object('actor_profile_id',(select profile_b from pg_temp.c003c_fixture),'stable_id',gen_random_uuid()))
) update pg_temp.c003c_fixture f set horse_a=created.horse_id from created;
with created as (
  select * from public.create_canonical_horse('Canonical B',null,'unknown',null,
    'c003c100-0000-4000-8000-000000000002','{}')
) update pg_temp.c003c_fixture f set horse_b=created.horse_id from created;

do $$ declare f pg_temp.c003c_fixture%rowtype; replay record;
begin select * into f from pg_temp.c003c_fixture;
  select * into replay from public.create_canonical_horse('Changed replay',null,'stallion',null,
    'c003c100-0000-4000-8000-000000000001','{"primary_authority_profile_id":"spoof"}');
  if replay.applied or replay.result_code<>'idempotent_replay'
    or (select primary_authority_profile_id from public.canonical_horses where id=f.horse_a)<>f.profile_a
    or (select authority_version from public.canonical_horses where id=f.horse_a)<>1
    or (select count(*) from public.canonical_horses where created_by_profile_id=f.profile_a)<>2
  then raise exception 'Server-derived horse authority or create idempotency failed'; end if;
  begin update public.canonical_horses set primary_authority_profile_id=f.profile_b where id=f.horse_a;
    raise exception 'direct authority mutation succeeded'; exception when insufficient_privilege then null; end;
  begin update public.canonical_horses set display_name='direct' where id=f.horse_a;
    raise exception 'direct horse DML succeeded'; exception when insufficient_privilege then null; end;
  begin truncate public.horse_delegated_administrators;
    raise exception 'authenticated truncated delegations'; exception when insufficient_privilege then null; end;
end $$;

-- An inactive profile cannot create or acquire horse authority.
with x as (select public.start_horse_person_relationship((select horse_a from pg_temp.c003c_fixture),
  (select profile_d from pg_temp.c003c_fixture),'groom',statement_timestamp(),'c003c104-0000-4000-8000-000000000001') id)
update pg_temp.c003c_fixture f set inactive_relationship=x.id from x;
select set_config('request.jwt.claim.sub',(select auth_d::text from pg_temp.c003c_fixture),true);
select * from public.request_profile_deletion(1,'c003c105-0000-4000-8000-000000000001');
do $$ begin
  begin perform public.create_canonical_horse('inactive',null,'unknown',null,gen_random_uuid(),'{}');
    raise exception 'inactive profile created horse'; exception when insufficient_privilege then null; end;
  if public.has_canonical_horse_permission((select horse_a from pg_temp.c003c_fixture),'horse.view')
  then raise exception 'inactive profile had horse access'; end if;
  if exists(select 1 from public.horse_person_relationships where id=(select inactive_relationship from pg_temp.c003c_fixture))
  then raise exception 'inactive profile retained own relationship visibility'; end if;
end $$;

-- B creates a stable organization; C creates an unrelated tenant.
select set_config('request.jwt.claim.sub',(select auth_b::text from pg_temp.c003c_fixture),true);
with created as (select * from public.create_organization('stable','C003C Stable',null,
  'c003c110-0000-4000-8000-000000000001','{}'))
update pg_temp.c003c_fixture f set stable_org=created.organization_id from created;
with created as (select * from public.create_organization('stable','C003C Stable 2',null,
  'c003c110-0000-4000-8000-000000000003','{}'))
update pg_temp.c003c_fixture f set stable_org_2=created.organization_id from created;
select set_config('request.jwt.claim.sub',(select auth_c::text from pg_temp.c003c_fixture),true);
with created as (select * from public.create_organization('veterinary_practice','C003C Other',null,
  'c003c110-0000-4000-8000-000000000002','{}'))
update pg_temp.c003c_fixture f set other_org=created.organization_id from created;

-- A records legal ownership, a semantic relationship, organization ownership,
-- and residency. None of those records is an access path.
select set_config('request.jwt.claim.sub',(select auth_a::text from pg_temp.c003c_fixture),true);
with x as (select public.start_horse_person_ownership((select horse_a from pg_temp.c003c_fixture),
  (select profile_c from pg_temp.c003c_fixture),50,statement_timestamp(),'c003c120-0000-4000-8000-000000000001') id)
update pg_temp.c003c_fixture f set person_ownership=x.id from x;
with x as (select public.start_horse_organization_ownership((select horse_a from pg_temp.c003c_fixture),
  (select stable_org from pg_temp.c003c_fixture),50,statement_timestamp(),'c003c120-0000-4000-8000-000000000002') id)
update pg_temp.c003c_fixture f set org_ownership=x.id from x;
with x as (select public.start_horse_person_relationship((select horse_a from pg_temp.c003c_fixture),
  (select profile_c from pg_temp.c003c_fixture),'rider',statement_timestamp(),'c003c120-0000-4000-8000-000000000003') id)
update pg_temp.c003c_fixture f set relationship=x.id from x;
with x as (select * from public.switch_horse_residency((select horse_a from pg_temp.c003c_fixture),
  (select stable_org from pg_temp.c003c_fixture),statement_timestamp(),'c003c120-0000-4000-8000-000000000004'))
update pg_temp.c003c_fixture f set residency=x.residency_id from x;

select set_config('request.jwt.claim.sub',(select auth_c::text from pg_temp.c003c_fixture),true);
do $$ declare f pg_temp.c003c_fixture%rowtype;
begin select * into f from pg_temp.c003c_fixture;
  if public.has_canonical_horse_permission(f.horse_a,'horse.view')
    or exists(select 1 from public.canonical_horses where id=f.horse_a)
    or (select count(*) from public.horse_person_ownerships where id=f.person_ownership)<>1
    or (select count(*) from public.horse_person_relationships where id=f.relationship)<>1
  then raise exception 'Ownership/relationship implicitly granted horse access or minimum own-row visibility failed'; end if;
  begin perform public.update_canonical_horse(f.horse_a,1,'attack',null,'unknown',null,'active',gen_random_uuid());
    raise exception 'relationship participant mutated horse'; exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub',(select auth_b::text from pg_temp.c003c_fixture),true);
do $$ declare f pg_temp.c003c_fixture%rowtype;
begin select * into f from pg_temp.c003c_fixture;
  if public.has_canonical_horse_permission(f.horse_a,'horse.view')
    or exists(select 1 from public.canonical_horses where id=f.horse_a)
    or not exists(select 1 from public.horse_organization_ownerships where id=f.org_ownership)
    or not exists(select 1 from public.horse_residencies where id=f.residency)
  then raise exception 'Organization ownership/residency implicitly granted horse access or org-side row visibility failed'; end if;
end $$;

-- Residency validates stable type, switches atomically and can be ended;
-- none of those transitions changes horse authority.
select set_config('request.jwt.claim.sub',(select auth_a::text from pg_temp.c003c_fixture),true);
do $$ begin
  begin perform public.switch_horse_residency((select horse_a from pg_temp.c003c_fixture),
    (select other_org from pg_temp.c003c_fixture),statement_timestamp(),gen_random_uuid());
    raise exception 'non-stable residency succeeded'; exception when invalid_parameter_value then null; end;
end $$;
with switched as (select * from public.switch_horse_residency((select horse_a from pg_temp.c003c_fixture),
  (select stable_org_2 from pg_temp.c003c_fixture),statement_timestamp(),'c003c125-0000-4000-8000-000000000001'))
update pg_temp.c003c_fixture f set residency=switched.residency_id from switched;
do $$ begin
  if (select count(*) from public.horse_residencies where horse_id=(select horse_a from pg_temp.c003c_fixture) and status='active')<>1
    or (select stable_organization_id from public.horse_residencies where id=(select residency from pg_temp.c003c_fixture))<>(select stable_org_2 from pg_temp.c003c_fixture)
  then raise exception 'Atomic residency switch failed'; end if;
end $$;

-- Mutual link confirmation: horse context proposes, organization context accepts.
select set_config('request.jwt.claim.sub',(select auth_a::text from pg_temp.c003c_fixture),true);
with x as (select * from public.propose_organization_horse_link((select horse_a from pg_temp.c003c_fixture),
  (select stable_org from pg_temp.c003c_fixture),'training_provider','horse','c003c130-0000-4000-8000-000000000001'))
update pg_temp.c003c_fixture f set link=x.link_id from x;
do $$ begin
  if (select expires_at-proposed_at from public.organization_horse_links where id=(select link from pg_temp.c003c_fixture))<>interval '7 days'
  then raise exception 'Link expiry is not exactly seven days'; end if;
  begin perform public.propose_organization_horse_link((select horse_b from pg_temp.c003c_fixture),(select stable_org from pg_temp.c003c_fixture),
    'other','organization',gen_random_uuid()); raise exception 'horse actor spoofed organization context';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub',(select auth_c::text from pg_temp.c003c_fixture),true);
do $$ begin
  begin perform public.respond_organization_horse_link((select link from pg_temp.c003c_fixture),1,'accept',gen_random_uuid());
    raise exception 'unrelated cross-tenant actor responded to link'; exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub',(select auth_b::text from pg_temp.c003c_fixture),true);
select * from public.respond_organization_horse_link((select link from pg_temp.c003c_fixture),1,'accept','c003c130-0000-4000-8000-000000000002');
do $$ declare f pg_temp.c003c_fixture%rowtype;
begin select * into f from pg_temp.c003c_fixture;
  if (select status from public.organization_horse_links where id=f.link)<>'active'
    or public.has_canonical_horse_permission(f.horse_a,'horse.view')
    or exists(select 1 from public.canonical_horses where id=f.horse_a)
  then raise exception 'Mutual link activation failed or link implicitly granted horse access'; end if;
  begin perform public.respond_organization_horse_link(f.link,1,'end',gen_random_uuid());
    raise exception 'stale link version succeeded'; exception when serialization_failure then null; end;
end $$;

select * from public.respond_organization_horse_link((select link from pg_temp.c003c_fixture),2,'end','c003c130-0000-4000-8000-000000000003');
do $$ declare replay record;
begin
  select * into replay from public.respond_organization_horse_link((select link from pg_temp.c003c_fixture),2,'end',gen_random_uuid());
  if replay.applied or replay.status<>'ended' then raise exception 'terminal link replay mutated state'; end if;
end $$;

select set_config('request.jwt.claim.sub',(select auth_a::text from pg_temp.c003c_fixture),true);
with x as (select * from public.propose_organization_horse_link((select horse_a from pg_temp.c003c_fixture),
  (select stable_org from pg_temp.c003c_fixture),'other','horse','c003c131-0000-4000-8000-000000000001'))
update pg_temp.c003c_fixture f set link=x.link_id from x;
select * from public.respond_organization_horse_link((select link from pg_temp.c003c_fixture),1,'withdraw','c003c131-0000-4000-8000-000000000002');

with x as (select * from public.propose_organization_horse_link((select horse_a from pg_temp.c003c_fixture),
  (select stable_org from pg_temp.c003c_fixture),'farrier_provider','horse','c003c132-0000-4000-8000-000000000001'))
update pg_temp.c003c_fixture f set link=x.link_id from x;
select set_config('request.jwt.claim.sub',(select auth_b::text from pg_temp.c003c_fixture),true);
select * from public.respond_organization_horse_link((select link from pg_temp.c003c_fixture),1,'reject','c003c132-0000-4000-8000-000000000002');

-- The opposite direction is represented separately: organization initiates,
-- then an authorized horse context confirms.
with x as (select * from public.propose_organization_horse_link((select horse_a from pg_temp.c003c_fixture),
  (select stable_org from pg_temp.c003c_fixture),'care_provider','organization','c003c133-0000-4000-8000-000000000001'))
update pg_temp.c003c_fixture f set link=x.link_id from x;
select set_config('request.jwt.claim.sub',(select auth_a::text from pg_temp.c003c_fixture),true);
select * from public.respond_organization_horse_link((select link from pg_temp.c003c_fixture),1,'accept','c003c133-0000-4000-8000-000000000002');
select * from public.respond_organization_horse_link((select link from pg_temp.c003c_fixture),2,'end','c003c133-0000-4000-8000-000000000003');

with x as (select * from public.propose_organization_horse_link((select horse_a from pg_temp.c003c_fixture),
  (select stable_org from pg_temp.c003c_fixture),'veterinary_provider','horse','c003c134-0000-4000-8000-000000000001'))
update pg_temp.c003c_fixture f set link=x.link_id from x;
reset role;
update public.organization_horse_links set proposed_at=pg_catalog.statement_timestamp()-interval '8 days',
  expires_at=pg_catalog.statement_timestamp()-interval '1 day'
where id=(select link from pg_temp.c003c_fixture);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select auth_b::text from pg_temp.c003c_fixture),true);
select * from public.respond_organization_horse_link((select link from pg_temp.c003c_fixture),1,'accept','c003c134-0000-4000-8000-000000000002');
do $$ begin
  if (select status from public.organization_horse_links where id=(select link from pg_temp.c003c_fixture))<>'expired'
  then raise exception 'expired link transition failed'; end if;
end $$;

-- Only primary authority may delegate. Delegated scopes exclude transfer;
-- overlap, stale versions and cross-horse authority are rejected.
select set_config('request.jwt.claim.sub',(select auth_b::text from pg_temp.c003c_fixture),true);
do $$ begin
  begin perform public.grant_horse_delegated_administrator((select horse_a from pg_temp.c003c_fixture),(select profile_b from pg_temp.c003c_fixture),
    array['horse.view'],statement_timestamp(),null,gen_random_uuid()); raise exception 'non-primary delegated';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claim.sub',(select auth_a::text from pg_temp.c003c_fixture),true);
do $$ begin
  begin perform public.grant_horse_delegated_administrator((select horse_a from pg_temp.c003c_fixture),(select profile_b from pg_temp.c003c_fixture),
    array['horse.view','horse.transfer'],statement_timestamp(),null,gen_random_uuid()); raise exception 'transfer permission delegated';
  exception when invalid_parameter_value then null; end;
end $$;
with x as (select * from public.grant_horse_delegated_administrator((select horse_a from pg_temp.c003c_fixture),
  (select profile_b from pg_temp.c003c_fixture),array['horse.view','horse.edit'],statement_timestamp(),null,'c003c140-0000-4000-8000-000000000001'))
update pg_temp.c003c_fixture f set delegation=x.delegation_id from x;
do $$ begin
  begin perform public.grant_horse_delegated_administrator((select horse_a from pg_temp.c003c_fixture),(select profile_b from pg_temp.c003c_fixture),
    array['horse.view'],statement_timestamp(),null,gen_random_uuid()); raise exception 'overlapping delegation succeeded';
  exception when exclusion_violation then null; end;
end $$;
select set_config('request.jwt.claim.sub',(select auth_b::text from pg_temp.c003c_fixture),true);
do $$ declare f pg_temp.c003c_fixture%rowtype; v bigint; result record;
begin select * into f from pg_temp.c003c_fixture;
  if not public.has_canonical_horse_permission(f.horse_a,'horse.view')
    or public.has_canonical_horse_permission(f.horse_a,'horse.transfer')
    or public.has_canonical_horse_permission(f.horse_b,'horse.view')
  then raise exception 'Delegated or cross-horse permission evaluation failed'; end if;
  select row_version into v from public.canonical_horses where id=f.horse_a;
  select * into result from public.update_canonical_horse(f.horse_a,v,'Delegated edit','2016-05-01','mare','KWPN','active',gen_random_uuid());
  begin perform public.update_canonical_horse(f.horse_a,v,'stale',null,'unknown',null,'active',gen_random_uuid());
    raise exception 'stale horse version succeeded'; exception when serialization_failure then null; end;
end $$;
select set_config('request.jwt.claim.sub',(select auth_a::text from pg_temp.c003c_fixture),true);
do $$ begin
  begin perform public.end_horse_delegated_administrator((select delegation from pg_temp.c003c_fixture),99,'TEST',gen_random_uuid());
    raise exception 'stale delegation version succeeded'; exception when serialization_failure then null; end;
end $$;
select * from public.end_horse_delegated_administrator((select delegation from pg_temp.c003c_fixture),1,'TEST','c003c140-0000-4000-8000-000000000002');
select set_config('request.jwt.claim.sub',(select auth_b::text from pg_temp.c003c_fixture),true);
do $$ begin if public.has_canonical_horse_permission((select horse_a from pg_temp.c003c_fixture),'horse.view')
  then raise exception 'ended delegation retained access'; end if; end $$;

-- Owner-level constraints independently reject invalid/overlapping windows,
-- non-stable residency and direct primary-authority mutation.
reset role;
do $$ declare f pg_temp.c003c_fixture%rowtype;
begin select * into f from pg_temp.c003c_fixture;
  begin
    insert into public.canonical_horses(primary_authority_profile_id,display_name,created_by_profile_id,creation_correlation_id)
      values(f.profile_d,'Inactive primary',f.profile_a,gen_random_uuid());
    set constraints c003c_primary_authority_horses immediate;
    raise exception 'inactive primary authority succeeded';
  exception when check_violation then null; end;
  set constraints c003c_primary_authority_horses deferred;
  begin update public.canonical_horses set primary_authority_profile_id=f.profile_b,row_version=row_version+1 where id=f.horse_a;
    raise exception 'owner bypassed immutable primary authority'; exception when insufficient_privilege then null; end;
  begin insert into public.horse_person_ownerships(horse_id,owner_profile_id,status,valid_from,valid_until,created_by_profile_id,creation_correlation_id)
    values(f.horse_a,f.profile_b,'active',statement_timestamp(),statement_timestamp()-interval '1 day',f.profile_a,gen_random_uuid());
    raise exception 'invalid ownership window succeeded'; exception when check_violation then null; end;
  begin insert into public.horse_residencies(horse_id,stable_organization_id,status,created_by_profile_id,creation_correlation_id)
    values(f.horse_a,f.stable_org,'active',f.profile_a,gen_random_uuid()); raise exception 'second active residency succeeded';
    exception when unique_violation then null; end;
end $$;

set local role authenticated;
select set_config('request.jwt.claim.sub',(select auth_a::text from pg_temp.c003c_fixture),true);
select public.end_horse_person_ownership((select person_ownership from pg_temp.c003c_fixture),1,'c003c150-0000-4000-8000-000000000001');
select public.end_horse_organization_ownership((select org_ownership from pg_temp.c003c_fixture),1,'c003c150-0000-4000-8000-000000000002');
select public.end_horse_person_relationship((select relationship from pg_temp.c003c_fixture),1,'c003c150-0000-4000-8000-000000000003');
select public.end_horse_residency((select residency from pg_temp.c003c_fixture),1,'c003c150-0000-4000-8000-000000000004');
reset role;

-- Catalog/RLS/ACL/routine hardening and audit privacy/immutability.
do $$ declare routine record; definition text;
begin
  if exists(select 1 from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname in ('canonical_horses','horse_delegated_administrators','horse_person_ownerships',
      'horse_organization_ownerships','horse_relationship_types','horse_person_relationships','organization_horse_link_types',
      'organization_horse_links','horse_residencies') and (not c.relrowsecurity or pg_catalog.has_table_privilege('authenticated',c.oid,'INSERT,UPDATE,DELETE,TRUNCATE')))
  then raise exception 'C-003C RLS or table ACL hardening failed'; end if;
  for routine in select p.oid from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='private' and p.proname like 'c003c_%') or (n.nspname='public' and p.proname in (
      'has_canonical_horse_permission','create_canonical_horse','update_canonical_horse','grant_horse_delegated_administrator',
      'end_horse_delegated_administrator','start_horse_person_ownership','end_horse_person_ownership',
      'start_horse_organization_ownership','end_horse_organization_ownership','start_horse_person_relationship',
      'end_horse_person_relationship','switch_horse_residency','end_horse_residency','propose_organization_horse_link',
      'respond_organization_horse_link')) loop
    select pg_get_functiondef(routine.oid) into definition;
    if (select proowner from pg_proc where oid=routine.oid)<>'postgres'::regrole or definition not ilike '%SET search_path TO %''''%'
    then raise exception 'Routine owner/search_path hardening failed: %',routine.oid::regprocedure; end if;
  end loop;
  if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname like 'c003c_%'
    and (has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('service_role',p.oid,'EXECUTE')))
  then raise exception 'Private C-003C routine is client executable'; end if;
  if exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in (
      'has_canonical_horse_permission','create_canonical_horse','update_canonical_horse','grant_horse_delegated_administrator',
      'end_horse_delegated_administrator','start_horse_person_ownership','end_horse_person_ownership',
      'start_horse_organization_ownership','end_horse_organization_ownership','start_horse_person_relationship',
      'end_horse_person_relationship','switch_horse_residency','end_horse_residency','propose_organization_horse_link',
      'respond_organization_horse_link') and (not has_function_privilege('authenticated',p.oid,'EXECUTE')
        or has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('service_role',p.oid,'EXECUTE')))
  then raise exception 'Public C-003C RPC execute allowlist failed'; end if;
  if exists(select 1 from public.audit_events where scope_kind='horse' and (metadata::text ~* 'example.invalid|KWPN|Delegated edit' or actor_profile_id is null))
  then raise exception 'Horse audit contains PII or lacks actor'; end if;
  begin
    truncate public.audit_events;
    raise exception 'audit truncate succeeded';
  exception when others then
    if sqlerrm <> 'AUDIT_EVENTS_APPEND_ONLY' then raise; end if;
  end;
end $$;

select extensions.pass('C-003C canonical horses and relationships security matrix passed');
select * from extensions.finish();
rollback;
