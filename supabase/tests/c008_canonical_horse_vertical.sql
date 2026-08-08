begin;

select extensions.plan(1);

create temporary table c008_fixture (
  auth_authority uuid not null,
  auth_delegate uuid not null,
  auth_related uuid not null,
  auth_empty uuid not null,
  authority_profile uuid,
  delegate_profile uuid,
  related_profile uuid,
  empty_profile uuid,
  horse_id uuid,
  legacy_horse_id uuid,
  stable_id uuid,
  transfer_id uuid,
  transfer_token text
);
grant select,update on pg_temp.c008_fixture to authenticated,anon,service_role;

insert into pg_temp.c008_fixture(
  auth_authority,auth_delegate,auth_related,auth_empty
) values (
  'c0080000-0000-4000-8000-000000000001',
  'c0080000-0000-4000-8000-000000000002',
  'c0080000-0000-4000-8000-000000000003',
  'c0080000-0000-4000-8000-000000000004'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
)
select '00000000-0000-0000-0000-000000000000'::uuid,auth_authority,
  'authenticated','authenticated','c008-authority@example.invalid','',now(),
  '{}'::jsonb,'{"stable_id":"spoof","primary_authority_profile_id":"spoof"}'::jsonb,now(),now()
from pg_temp.c008_fixture
union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_delegate,
  'authenticated','authenticated','c008-delegate@example.invalid','',now(),
  '{}'::jsonb,'{"role":"platform_admin"}'::jsonb,now(),now()
from pg_temp.c008_fixture
union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_related,
  'authenticated','authenticated','c008-related@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c008_fixture
union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_empty,
  'authenticated','authenticated','c008-empty@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c008_fixture;

update pg_temp.c008_fixture fixture set
  authority_profile=(select id from public.profiles where auth_user_id=fixture.auth_authority),
  delegate_profile=(select id from public.profiles where auth_user_id=fixture.auth_delegate),
  related_profile=(select id from public.profiles where auth_user_id=fixture.auth_related),
  empty_profile=(select id from public.profiles where auth_user_id=fixture.auth_empty);

-- New RPCs are authenticated-only and private helpers stay private.
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','anon',true);
set local role anon;
do $$
begin
  begin perform public.list_canonical_horses();
    raise exception 'anon listed canonical horses';
  exception when insufficient_privilege then null; end;
  begin perform public.create_canonical_horse_profile(
    'Attack',null,null,'unknown',null,null,null,null,null,null,null,null,gen_random_uuid()
  ); raise exception 'anon created canonical horse';
  exception when insufficient_privilege then null; end;
end;
$$;
reset role;

select set_config('request.jwt.claim.role','service_role',true);
set local role service_role;
do $$
begin
  begin perform private.c008_target_profile_by_email('c008-related@example.invalid');
    raise exception 'service role executed private target resolver';
  exception when insufficient_privilege then null; end;
  begin update public.canonical_horses set authority_version=999;
    raise exception 'service role directly mutated canonical authority';
  exception when insufficient_privilege then null; end;
end;
$$;
reset role;

-- A personal account creates a complete horse without stable or organization.
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',(select auth_authority::text from pg_temp.c008_fixture),true);
set local role authenticated;
with created as (
  select * from public.create_canonical_horse_profile(
    'Nova','Nova van AVARYN','2018-05-12','mare','KWPN','Dressuur','Z2',
    'Bruin','Alleen testnotitie','528210000000001','NL-PASS-008','2030-05-12',
    'c0081000-0000-4000-8000-000000000001'
  )
) update pg_temp.c008_fixture fixture set horse_id=created.horse_id from created;

do $$
declare fixture pg_temp.c008_fixture%rowtype; horse public.canonical_horses%rowtype;
begin
  select * into fixture from pg_temp.c008_fixture;
  select * into horse from public.canonical_horses where id=fixture.horse_id;
  if horse.primary_authority_profile_id<>fixture.authority_profile
    or horse.authority_version<>1
    or horse.row_version<>1
    or horse.official_name<>'Nova van AVARYN'
    or exists(select 1 from information_schema.columns where table_schema='public'
      and table_name='canonical_horses' and column_name='stable_id')
    or exists(select 1 from public.horses where canonical_horse_id=fixture.horse_id)
    or (select count(*) from public.list_canonical_horses())<>1
  then raise exception 'standalone canonical creation or exact-one authority failed'; end if;
end;
$$;

-- Profile CAS is authoritative; stale writers fail closed.
select * from public.update_canonical_horse_profile(
  (select horse_id from pg_temp.c008_fixture),1,
  'Nova II','Nova van AVARYN','2018-05-12','mare','KWPN','Dressuur','ZZ-Licht',
  'Donkerbruin','Bijgewerkt','528210000000001','NL-PASS-008','2030-05-12',
  'active','c0081000-0000-4000-8000-000000000002'
);
do $$
begin
  begin perform public.update_canonical_horse_profile(
    (select horse_id from pg_temp.c008_fixture),1,
    'Stale',null,null,'unknown',null,null,null,null,null,null,null,null,
    'active',gen_random_uuid()
  ); raise exception 'stale canonical profile update succeeded';
  exception when serialization_failure then null; end;
end;
$$;

-- Legal ownership and semantic relationships are separately recorded by
-- verified e-mail but never grant horse visibility or mutation rights.
select public.start_horse_person_ownership_by_email(
  (select horse_id from pg_temp.c008_fixture),'c008-related@example.invalid',50,
  statement_timestamp(),'c0081100-0000-4000-8000-000000000001'
);
select public.start_horse_person_relationship_by_email(
  (select horse_id from pg_temp.c008_fixture),'c008-related@example.invalid','rider',
  statement_timestamp(),'c0081100-0000-4000-8000-000000000002'
);

select set_config('request.jwt.claim.sub',(select auth_related::text from pg_temp.c008_fixture),true);
do $$
begin
  if (select count(*) from public.list_canonical_horses())<>0
    or public.has_canonical_horse_permission((select horse_id from pg_temp.c008_fixture),'horse.view')
    or (select count(*) from public.horse_person_ownerships
      where horse_id=(select horse_id from pg_temp.c008_fixture))<>1
    or (select count(*) from public.horse_person_relationships
      where horse_id=(select horse_id from pg_temp.c008_fixture))<>1
  then raise exception 'ownership or relationship implied horse access'; end if;
  begin perform public.get_canonical_horse_workspace((select horse_id from pg_temp.c008_fixture));
    raise exception 'relationship participant read horse workspace';
  exception when insufficient_privilege then null; end;
end;
$$;

-- Explicit, bounded delegation grants only its listed permissions and never
-- the non-delegable transfer permission.
select set_config('request.jwt.claim.sub',(select auth_authority::text from pg_temp.c008_fixture),true);
select * from public.grant_horse_delegated_administrator_by_email(
  (select horse_id from pg_temp.c008_fixture),'c008-delegate@example.invalid',
  array['horse.view','horse.edit','horse.manage'],statement_timestamp(),
  statement_timestamp()+interval '2 days','c0081200-0000-4000-8000-000000000001'
);

select set_config('request.jwt.claim.sub',(select auth_delegate::text from pg_temp.c008_fixture),true);
do $$
begin
  if not public.has_canonical_horse_permission((select horse_id from pg_temp.c008_fixture),'horse.edit')
    or not public.has_canonical_horse_permission((select horse_id from pg_temp.c008_fixture),'horse.manage')
    or public.has_canonical_horse_permission((select horse_id from pg_temp.c008_fixture),'horse.transfer')
  then raise exception 'delegated permission scope was not exact'; end if;
  begin perform public.initiate_horse_authority_transfer_by_email(
    (select horse_id from pg_temp.c008_fixture),'c008-related@example.invalid',gen_random_uuid()
  ); raise exception 'delegated administrator initiated authority transfer';
  exception when insufficient_privilege then null; end;
end;
$$;

select * from public.update_canonical_horse_profile(
  (select horse_id from pg_temp.c008_fixture),3,
  'Nova III','Nova van AVARYN','2018-05-12','mare','KWPN','Dressuur','ZZ-Licht',
  'Donkerbruin','Delegated edit','528210000000001','NL-PASS-008','2030-05-12',
  'active','c0081200-0000-4000-8000-000000000002'
);

-- Primary authority starts one seven-day transfer to a concrete verified
-- recipient; accept is atomic and terminal replay is denied.
select set_config('request.jwt.claim.sub',(select auth_authority::text from pg_temp.c008_fixture),true);
with initiated as (
  select * from public.initiate_horse_authority_transfer_by_email(
    (select horse_id from pg_temp.c008_fixture),'c008-related@example.invalid',
    'c0081300-0000-4000-8000-000000000001'
  )
) update pg_temp.c008_fixture fixture set
  transfer_id=initiated.transfer_id,transfer_token=initiated.transfer_token
from initiated;

do $$
declare workspace jsonb;
begin
  workspace:=public.get_canonical_horse_workspace((select horse_id from pg_temp.c008_fixture));
  if pg_catalog.length((select transfer_token from pg_temp.c008_fixture))<>64
    or (workspace->'pending_transfer'->>'id')::uuid<>(select transfer_id from pg_temp.c008_fixture)
    or (workspace->'pending_transfer'->>'expires_at')::timestamptz
      -(workspace->'pending_transfer'->>'created_at')::timestamptz<>interval '7 days'
  then raise exception 'pending transfer projection or seven-day invariant failed'; end if;
end;
$$;

select set_config('request.jwt.claim.sub',(select auth_related::text from pg_temp.c008_fixture),true);
do $$
begin
  if (select count(*) from public.preview_horse_authority_transfer(
    (select transfer_token from pg_temp.c008_fixture)))<>1
  then raise exception 'recipient could not preview transfer'; end if;
end;
$$;
select * from public.respond_horse_authority_transfer(
  (select transfer_token from pg_temp.c008_fixture),'accept',
  'c0081300-0000-4000-8000-000000000002'
);

do $$
declare workspace jsonb;
begin
  workspace:=public.get_canonical_horse_workspace((select horse_id from pg_temp.c008_fixture));
  if (select count(*) from public.list_canonical_horses()
      where horse_id=(select horse_id from pg_temp.c008_fixture)
        and is_primary_authority and authority_version=2)<>1
    or workspace->'pending_transfer'<>'null'::jsonb
  then raise exception 'atomic authority transfer result invalid'; end if;
  begin perform public.respond_horse_authority_transfer(
    (select transfer_token from pg_temp.c008_fixture),'accept',gen_random_uuid()
  ); raise exception 'terminal transfer replay succeeded';
  exception when insufficient_privilege then null; end;
  if (select count(*) from pg_catalog.jsonb_array_elements(workspace->'audit') event
    where event->>'event_type'='horse.authority_transfer_accepted')<>1
  then raise exception 'transfer audit missing'; end if;
end;
$$;

select set_config('request.jwt.claim.sub',(select auth_authority::text from pg_temp.c008_fixture),true);
do $$
begin
  if public.has_canonical_horse_permission((select horse_id from pg_temp.c008_fixture),'horse.transfer')
  then raise exception 'old primary retained authority after transfer'; end if;
end;
$$;

-- The retained stable-scoped create route now creates the canonical aggregate
-- with the same UUID. Canonical edits remain visible to Planning/Feeding.
with stable_created as (
  select public.create_stable(
    'C008 Legacy Stable','Europe/Amsterdam','personal','nl',
    'c0081400-0000-4000-8000-000000000001','C008 Authority',null
  ) value
) update pg_temp.c008_fixture fixture set stable_id=(value->>'stable_id')::uuid
from stable_created;

with legacy_created as (
  select public.create_horse(
    (select stable_id from pg_temp.c008_fixture),'Legacy Bridge',
    'c0081400-0000-4000-8000-000000000002','Legacy Official',null,
    'gelding','KWPN','Springen','M'
  ) value
) update pg_temp.c008_fixture fixture set legacy_horse_id=(value->>'horse_id')::uuid
from legacy_created;

do $$
declare fixture pg_temp.c008_fixture%rowtype;
begin
  select * into fixture from pg_temp.c008_fixture;
  if (select canonical_horse_id from public.horses where id=fixture.legacy_horse_id)<>fixture.legacy_horse_id
    or (select primary_authority_profile_id from public.canonical_horses where id=fixture.legacy_horse_id)<>fixture.authority_profile
    or (select count(*) from public.canonical_horses where id=fixture.legacy_horse_id)<>1
  then raise exception 'legacy-to-canonical same-UUID bridge failed'; end if;
end;
$$;

select * from public.update_canonical_horse_profile(
  (select legacy_horse_id from pg_temp.c008_fixture),1,
  'Bridge Updated','Legacy Official',null,'gelding','KWPN','Springen','M',
  null,null,null,null,null,'active','c0081400-0000-4000-8000-000000000003'
);
do $$
begin
  if (select display_name from public.horses
      where id=(select legacy_horse_id from pg_temp.c008_fixture))<>'Bridge Updated'
  then raise exception 'canonical profile did not sync to retained Planning/Feeding row'; end if;
end;
$$;

-- A user with no explicit authority sees a safe empty state.
select set_config('request.jwt.claim.sub',(select auth_empty::text from pg_temp.c008_fixture),true);
do $$
begin
  if (select count(*) from public.list_canonical_horses())<>0
  then raise exception 'empty user received cross-user horse data'; end if;
end;
$$;

reset role;
select extensions.pass('C-008 canonical horse vertical, zero-implicit-access bridge and transfer route are secure');
select * from extensions.finish();

rollback;
