begin;

select extensions.plan(1);

create temporary table c010_round1_fixture(
  auth_manager_a uuid not null,
  auth_manager_b uuid not null,
  auth_owner uuid not null,
  auth_groom uuid not null,
  auth_outsider uuid not null,
  manager_a uuid,
  manager_b uuid,
  owner_profile uuid,
  groom_profile uuid,
  outsider_profile uuid,
  stable_a uuid,
  stable_b uuid,
  groom_membership uuid,
  horse_a uuid,
  horse_b uuid,
  place_3 uuid,
  task_id uuid,
  open_task_id uuid
);
grant select,update on pg_temp.c010_round1_fixture to authenticated,anon,service_role;

insert into pg_temp.c010_round1_fixture(
  auth_manager_a,auth_manager_b,auth_owner,auth_groom,auth_outsider
) values(
  'c0110000-0000-4000-8000-000000000001',
  'c0110000-0000-4000-8000-000000000002',
  'c0110000-0000-4000-8000-000000000003',
  'c0110000-0000-4000-8000-000000000004',
  'c0110000-0000-4000-8000-000000000005'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
)
select '00000000-0000-0000-0000-000000000000'::uuid,auth_manager_a,
  'authenticated','authenticated','round1-manager-a@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_manager_b,
  'authenticated','authenticated','round1-manager-b@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_owner,
  'authenticated','authenticated','round1-owner@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_groom,
  'authenticated','authenticated','round1-groom@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_outsider,
  'authenticated','authenticated','round1-outsider@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture;

update public.profiles profile set display_name=case profile.auth_user_id
  when 'c0110000-0000-4000-8000-000000000001' then 'Manager Alpha'
  when 'c0110000-0000-4000-8000-000000000002' then 'Manager Beta'
  when 'c0110000-0000-4000-8000-000000000003' then 'Horse Authority'
  when 'c0110000-0000-4000-8000-000000000004' then 'Groom Alpha'
  else 'Buitenstaander' end
where profile.auth_user_id::text like 'c0110000-%';

update pg_temp.c010_round1_fixture fixture set
  manager_a=(select id from public.profiles where auth_user_id=fixture.auth_manager_a),
  manager_b=(select id from public.profiles where auth_user_id=fixture.auth_manager_b),
  owner_profile=(select id from public.profiles where auth_user_id=fixture.auth_owner),
  groom_profile=(select id from public.profiles where auth_user_id=fixture.auth_groom),
  outsider_profile=(select id from public.profiles where auth_user_id=fixture.auth_outsider);

select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_round1_fixture),true);
with created as(
  select public.create_c010_stable('SDS Stables','Amsterdam','c0111000-0000-4000-8000-000000000001') result
) update pg_temp.c010_round1_fixture fixture
set stable_a=(created.result->>'organization_id')::uuid from created;

select set_config('request.jwt.claim.sub',(select auth_manager_b::text from pg_temp.c010_round1_fixture),true);
with created as(
  select public.create_c010_stable('Test Stable','Utrecht','c0111000-0000-4000-8000-000000000002') result
) update pg_temp.c010_round1_fixture fixture
set stable_b=(created.result->>'organization_id')::uuid from created;

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_round1_fixture),true);
do $$ declare invitation record; begin
  select * into invitation from public.create_c010_stable_invitation(
    (select stable_a from pg_temp.c010_round1_fixture),'groom','round1-groom@example.invalid',
    statement_timestamp()+interval '7 days','c0111100-0000-4000-8000-000000000001'
  );
  perform pg_catalog.set_config('c010.round1.groom_token',invitation.invitation_token,true);
end $$;

select set_config('request.jwt.claim.sub',(select auth_groom::text from pg_temp.c010_round1_fixture),true);
with accepted as(
  select * from public.respond_stable_invitation(
    current_setting('c010.round1.groom_token'),'accept','c0111100-0000-4000-8000-000000000002'
  )
) update pg_temp.c010_round1_fixture fixture set groom_membership=accepted.membership_id from accepted;

select set_config('request.jwt.claim.sub',(select auth_owner::text from pg_temp.c010_round1_fixture),true);
with horse as(
  select * from public.create_canonical_horse_profile(
    'Orion Round 1',null,null,'unknown',null,'Dressuur',null,null,null,null,null,null,
    'c0111200-0000-4000-8000-000000000001'
  )
) update pg_temp.c010_round1_fixture fixture set horse_a=horse.horse_id from horse;
with horse as(
  select * from public.create_canonical_horse_profile(
    'Nova Round 1',null,null,'unknown',null,'Dressuur',null,null,null,null,null,null,
    'c0111200-0000-4000-8000-000000000002'
  )
) update pg_temp.c010_round1_fixture fixture set horse_b=horse.horse_id from horse;
select public.set_c010_horse_residency(
  (select horse_a from pg_temp.c010_round1_fixture),(select stable_a from pg_temp.c010_round1_fixture),
  null,'c0111200-0000-4000-8000-000000000003'
);
select public.set_c010_horse_residency(
  (select horse_b from pg_temp.c010_round1_fixture),(select stable_b from pg_temp.c010_round1_fixture),
  null,'c0111200-0000-4000-8000-000000000004'
);
select public.set_c010_horse_collaborator(
  (select horse_a from pg_temp.c010_round1_fixture),(select manager_a from pg_temp.c010_round1_fixture),
  'trainer',array['horse.view'],true,'c0111200-0000-4000-8000-000000000005'
);
select public.set_c010_horse_collaborator(
  (select horse_a from pg_temp.c010_round1_fixture),(select groom_profile from pg_temp.c010_round1_fixture),
  'groom',array['horse.view'],true,'c0111200-0000-4000-8000-000000000006'
);

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_round1_fixture),true);
select public.update_c010_stable(
  (select stable_a from pg_temp.c010_round1_fixture),
  (select row_version from public.organizations where id=(select stable_a from pg_temp.c010_round1_fixture)),
  'SDS Stables','Amsterdam',
  'Stalstraat 10','Amsterdam','c0111300-0000-4000-8000-000000000001'
);
select public.update_c010_stable_facilities(
  (select stable_a from pg_temp.c010_round1_fixture),null,3,2,1,1,true,1,4,true,8,
  'c0111300-0000-4000-8000-000000000002'
);
update pg_temp.c010_round1_fixture fixture set place_3=(
  select id from public.stable_places where organization_id=fixture.stable_a and ordinal=3
);
select public.upsert_c010_stable_resource(
  (select stable_a from pg_temp.c010_round1_fixture),null,null,'concentrate_feed','Pavo','SportsFit',
  'c0111300-0000-4000-8000-000000000003'
);
select public.upsert_c010_stable_resource(
  (select stable_a from pg_temp.c010_round1_fixture),null,null,'bedding','AVARYN','Zaagsel',
  'c0111300-0000-4000-8000-000000000004'
);

with saved as(
  select public.upsert_c010_stable_task(
    (select stable_a from pg_temp.c010_round1_fixture),null,null,'Orion voeren','Controleer water','feeding',
    current_date,'18:00',(select groom_profile from pg_temp.c010_round1_fixture),'Weide 6',
    (select place_3 from pg_temp.c010_round1_fixture),(select horse_a from pg_temp.c010_round1_fixture),
    'c0111400-0000-4000-8000-000000000001'
  ) result
) update pg_temp.c010_round1_fixture fixture set task_id=(saved.result->>'task_id')::uuid from saved;

do $$ begin
  if (select stable_place_id from public.list_c010_stable_activities(
      (select stable_a from pg_temp.c010_round1_fixture),
      current_date::timestamptz,(current_date+1)::timestamptz,'all'
    ) where activity_id=(select task_id from pg_temp.c010_round1_fixture))
    is distinct from (select place_3 from pg_temp.c010_round1_fixture)
  then raise exception 'stable activity projection lost canonical place identity'; end if;
end $$;

-- Server-side negative boundaries: outsiders, cross-stable assignees/horses,
-- stale versions and occupied/historical stable places all fail closed.
do $$ begin
  begin perform public.upsert_c010_stable_task(
    (select stable_a from pg_temp.c010_round1_fixture),null,null,'Cross member',null,'other',current_date,null,
    (select manager_b from pg_temp.c010_round1_fixture),null,null,null,gen_random_uuid()
  ); raise exception 'cross-stable assignee was accepted';
  exception when sqlstate '22023' then null; end;
  begin perform public.upsert_c010_stable_task(
    (select stable_a from pg_temp.c010_round1_fixture),null,null,'Cross horse',null,'other',current_date,null,
    (select groom_profile from pg_temp.c010_round1_fixture),null,null,
    (select horse_b from pg_temp.c010_round1_fixture),gen_random_uuid()
  ); raise exception 'cross-stable horse was accepted';
  exception when insufficient_privilege then null; end;
  begin perform public.update_c010_stable_facilities(
    (select stable_a from pg_temp.c010_round1_fixture),1,2,2,1,1,true,1,4,true,8,gen_random_uuid()
  ); raise exception 'historically used stable place was archived';
  exception when foreign_key_violation then null; end;
end $$;

select set_config('request.jwt.claim.sub',(select auth_outsider::text from pg_temp.c010_round1_fixture),true);
do $$ begin
  begin perform public.get_c010_stable_round1_workspace(
    (select stable_a from pg_temp.c010_round1_fixture),current_date,'all'
  ); raise exception 'outsider read stable round1 workspace';
  exception when insufficient_privilege then null; end;
  begin perform public.retire_c010_stable(
    (select stable_a from pg_temp.c010_round1_fixture),
    (select row_version from public.organizations where id=(select stable_a from pg_temp.c010_round1_fixture)),
    'SDS Stables',gen_random_uuid()
  ); raise exception 'outsider retired stable';
  exception when insufficient_privilege then null; end;
end $$;

-- The assignee sees only its own task in the date-scoped personal projection,
-- can complete it once, and completion remains historical.
select set_config('request.jwt.claim.sub',(select auth_groom::text from pg_temp.c010_round1_fixture),true);
do $$ begin
  if (select count(*) from public.list_c010_personal_today(current_date))<>1
    or (select organization_name from public.list_c010_personal_today(current_date) limit 1)<>'SDS Stables'
  then raise exception 'personal Today projection did not return one labelled task'; end if;
end $$;
select public.transition_c010_stable_task(
  (select stable_a from pg_temp.c010_round1_fixture),(select task_id from pg_temp.c010_round1_fixture),
  1,'complete','c0111400-0000-4000-8000-000000000002'
);
do $$ begin
  if exists(select 1 from public.list_c010_personal_today(current_date))
    or not exists(select 1 from public.stable_task_events where task_id=(select task_id from pg_temp.c010_round1_fixture)
      and event_type='completed')
  then raise exception 'completion did not leave Today and preserve history'; end if;
end $$;

-- A second open task proves revocation and stable retirement behavior.
select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_round1_fixture),true);
with saved as(
  select public.upsert_c010_stable_task(
    (select stable_a from pg_temp.c010_round1_fixture),null,null,'Hooiruif vullen',null,'hay',
    current_date,'09:00',(select groom_profile from pg_temp.c010_round1_fixture),'Weide 6',null,null,
    'c0111400-0000-4000-8000-000000000003'
  ) result
) update pg_temp.c010_round1_fixture fixture set open_task_id=(saved.result->>'task_id')::uuid from saved;

do $$ declare primary_membership record; begin
  select membership.* into primary_membership from public.organization_memberships membership
  where membership.organization_id=(select stable_a from pg_temp.c010_round1_fixture)
    and membership.profile_id=(select manager_a from pg_temp.c010_round1_fixture) and membership.status='active';
  begin perform public.revoke_c010_membership(
    (select stable_a from pg_temp.c010_round1_fixture),primary_membership.id,primary_membership.row_version,gen_random_uuid()
  ); raise exception 'last primary administrator was removable outside retirement';
  exception when insufficient_privilege then null; end;
end $$;
select public.revoke_c010_membership(
  (select stable_a from pg_temp.c010_round1_fixture),(select groom_membership from pg_temp.c010_round1_fixture),
  1,'c0111500-0000-4000-8000-000000000001'
);

select set_config('request.jwt.claim.sub',(select auth_groom::text from pg_temp.c010_round1_fixture),true);
do $$ begin
  if exists(select 1 from public.list_c010_personal_today(current_date)) then
    raise exception 'revoked member retained personal Today access'; end if;
  begin perform public.get_c010_stable_round1_workspace(
    (select stable_a from pg_temp.c010_round1_fixture),current_date,'mine'
  ); raise exception 'revoked member retained stable access';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_round1_fixture),true);
do $$ begin
  begin perform public.retire_c010_stable(
    (select stable_a from pg_temp.c010_round1_fixture),
    (select row_version from public.organizations where id=(select stable_a from pg_temp.c010_round1_fixture)),
    'Verkeerde naam',gen_random_uuid()
  ); raise exception 'retirement accepted a wrong confirmation name';
  exception when sqlstate '22023' then null; end;
end $$;
select public.retire_c010_stable(
  (select stable_a from pg_temp.c010_round1_fixture),
  (select row_version from public.organizations where id=(select stable_a from pg_temp.c010_round1_fixture)),
  'SDS Stables',
  'c0111500-0000-4000-8000-000000000002'
);

reset role;
do $$ declare original_owner uuid; begin
  select primary_authority_profile_id into original_owner from public.canonical_horses
  where id=(select horse_a from pg_temp.c010_round1_fixture);
  if (select status from public.organizations where id=(select stable_a from pg_temp.c010_round1_fixture))<>'archived'
    or exists(select 1 from public.organization_memberships where organization_id=(select stable_a from pg_temp.c010_round1_fixture)
      and status in('active','suspended'))
    or exists(select 1 from public.horse_residencies where stable_organization_id=(select stable_a from pg_temp.c010_round1_fixture)
      and status in('active','planned'))
    or original_owner is distinct from(select owner_profile from pg_temp.c010_round1_fixture)
    or (select status from public.stable_tasks where id=(select open_task_id from pg_temp.c010_round1_fixture))<>'cancelled'
    or not exists(select 1 from public.stable_task_events where task_id=(select open_task_id from pg_temp.c010_round1_fixture)
      and event_type='cancelled' and metadata->>'reason'='stable_retired')
    or not exists(select 1 from public.audit_events where scope_id=(select stable_a from pg_temp.c010_round1_fixture)
      and event_type='organization.updated' and metadata->>'operation_code'='c010_retire_stable')
  then raise exception 'safe stable retirement corrupted lifecycle, ownership or history'; end if;
  if exists(select 1 from information_schema.columns where table_schema='public'
      and table_name='stable_resource_items' and column_name in('quantity','price','supplier_id'))
  then raise exception 'C-010 accidentally introduced inventory or commerce'; end if;
end $$;

select extensions.pass(
  'C-010 Round 1 stable context, facilities, resources, tasks, Today, isolation, revocation and retirement are secure'
);
select * from extensions.finish();

rollback;
