begin;

select extensions.plan(1);

create temporary table c010_fixture (
  auth_manager_a uuid not null,
  auth_manager_b uuid not null,
  auth_horse_owner uuid not null,
  auth_trainer uuid not null,
  auth_rider uuid not null,
  auth_groom uuid not null,
  auth_outsider uuid not null,
  manager_a_profile uuid,
  manager_b_profile uuid,
  horse_owner_profile uuid,
  trainer_profile uuid,
  rider_profile uuid,
  groom_profile uuid,
  stable_a uuid,
  stable_b uuid,
  trainer_a_membership uuid,
  trainer_b_membership uuid,
  rider_membership uuid,
  groom_membership uuid,
  horse_a1 uuid,
  horse_b1 uuid,
  rider_token text,
  trainer_a_token text,
  trainer_b_token text,
  groom_token text,
  schedule_item_id uuid
);
grant select,update on pg_temp.c010_fixture to authenticated,anon,service_role;

insert into pg_temp.c010_fixture(
  auth_manager_a,auth_manager_b,auth_horse_owner,auth_trainer,
  auth_rider,auth_groom,auth_outsider
) values(
  'c0100000-0000-4000-8000-000000000001',
  'c0100000-0000-4000-8000-000000000002',
  'c0100000-0000-4000-8000-000000000003',
  'c0100000-0000-4000-8000-000000000004',
  'c0100000-0000-4000-8000-000000000005',
  'c0100000-0000-4000-8000-000000000006',
  'c0100000-0000-4000-8000-000000000007'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
)
select '00000000-0000-0000-0000-000000000000'::uuid,auth_manager_a,
  'authenticated','authenticated','c010-manager-a@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c010_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_manager_b,
  'authenticated','authenticated','c010-manager-b@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c010_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_horse_owner,
  'authenticated','authenticated','c010-horse-owner@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c010_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_trainer,
  'authenticated','authenticated','c010-trainer@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c010_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_rider,
  'authenticated','authenticated','c010-rider@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c010_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_groom,
  'authenticated','authenticated','c010-groom@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c010_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_outsider,
  'authenticated','authenticated','c010-outsider@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c010_fixture;

update public.profiles profile set display_name=case profile.auth_user_id
  when 'c0100000-0000-4000-8000-000000000001' then 'Manager A'
  when 'c0100000-0000-4000-8000-000000000002' then 'Manager B'
  when 'c0100000-0000-4000-8000-000000000003' then 'Horse Authority'
  when 'c0100000-0000-4000-8000-000000000004' then 'Gedeelde Trainer'
  when 'c0100000-0000-4000-8000-000000000005' then 'Ruiter A'
  when 'c0100000-0000-4000-8000-000000000006' then 'Groom A'
  else 'Buitenstaander' end
where profile.auth_user_id::text like 'c0100000-%';

update pg_temp.c010_fixture fixture set
  manager_a_profile=(select id from public.profiles where auth_user_id=fixture.auth_manager_a),
  manager_b_profile=(select id from public.profiles where auth_user_id=fixture.auth_manager_b),
  horse_owner_profile=(select id from public.profiles where auth_user_id=fixture.auth_horse_owner),
  trainer_profile=(select id from public.profiles where auth_user_id=fixture.auth_trainer),
  rider_profile=(select id from public.profiles where auth_user_id=fixture.auth_rider),
  groom_profile=(select id from public.profiles where auth_user_id=fixture.auth_groom);

-- Client ACLs fail closed before any fixture is created.
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','anon',true);
set local role anon;
do $$ begin
  begin perform public.list_c010_stables();
    raise exception 'anon listed C-010 stables';
  exception when insufficient_privilege then null; end;
  begin perform public.create_c010_stable('Attack','Remote',gen_random_uuid());
    raise exception 'anon created C-010 stable';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.role','service_role',true);
set local role service_role;
do $$ begin
  begin perform public.list_c010_horses();
    raise exception 'service-role client listed C-010 horses';
  exception when insufficient_privilege then null; end;
  begin perform private.c010_seed_role_templates(gen_random_uuid(),gen_random_uuid());
    raise exception 'service-role client executed private C-010 helper';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Two independent stables are created atomically; the same profile can hold
-- a different role in each stable without global role metadata.
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_fixture),true);
with created as(
  select public.create_c010_stable(
    'Stal A','Amsterdam','c0101000-0000-4000-8000-000000000001'
  ) result
) update pg_temp.c010_fixture fixture
set stable_a=(created.result->>'organization_id')::uuid from created;

select set_config('request.jwt.claim.sub',(select auth_manager_b::text from pg_temp.c010_fixture),true);
with created as(
  select public.create_c010_stable(
    'Stal B','Utrecht','c0101000-0000-4000-8000-000000000002'
  ) result
) update pg_temp.c010_fixture fixture
set stable_b=(created.result->>'organization_id')::uuid from created;

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_fixture),true);
with invitation as(
  select * from public.create_c010_stable_invitation(
    (select stable_a from pg_temp.c010_fixture),'trainer',
    'c010-trainer@example.invalid',statement_timestamp()+interval '7 days',
    'c0101100-0000-4000-8000-000000000001'
  )
) update pg_temp.c010_fixture fixture set trainer_a_token=invitation.invitation_token
from invitation;
with invitation as(
  select * from public.create_c010_stable_invitation(
    (select stable_a from pg_temp.c010_fixture),'rider',
    'c010-rider@example.invalid',statement_timestamp()+interval '7 days',
    'c0101100-0000-4000-8000-000000000002'
  )
) update pg_temp.c010_fixture fixture set rider_token=invitation.invitation_token
from invitation;
with invitation as(
  select * from public.create_c010_stable_invitation(
    (select stable_a from pg_temp.c010_fixture),'groom',
    'c010-groom@example.invalid',statement_timestamp()+interval '7 days',
    'c0101100-0000-4000-8000-000000000003'
  )
) update pg_temp.c010_fixture fixture set groom_token=invitation.invitation_token
from invitation;

do $$ declare duplicate record; begin
  select * into duplicate from public.create_c010_stable_invitation(
    (select stable_a from pg_temp.c010_fixture),'trainer',
    ' C010-TRAINER@example.invalid ',statement_timestamp()+interval '7 days',
    'c0101100-0000-4000-8000-000000000004'
  );
  if duplicate.applied or duplicate.invitation_token is not null
    or duplicate.invitation_id is null
  then raise exception 'duplicate pending invitation was not controlled'; end if;
end $$;

select set_config('request.jwt.claim.sub',(select auth_outsider::text from pg_temp.c010_fixture),true);
do $$ begin
  begin perform public.respond_stable_invitation(
    (select trainer_a_token from pg_temp.c010_fixture),'accept',gen_random_uuid()
  ); raise exception 'wrong actor claimed C-010 invitation';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub',(select auth_trainer::text from pg_temp.c010_fixture),true);
with accepted as(
  select * from public.respond_stable_invitation(
    (select trainer_a_token from pg_temp.c010_fixture),'accept',
    'c0101100-0000-4000-8000-000000000005'
  )
) update pg_temp.c010_fixture fixture set trainer_a_membership=accepted.membership_id
from accepted;
do $$ begin
  begin perform public.respond_stable_invitation(
    (select trainer_a_token from pg_temp.c010_fixture),'accept',gen_random_uuid()
  ); raise exception 'accepted invitation was reusable';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub',(select auth_rider::text from pg_temp.c010_fixture),true);
with accepted as(
  select * from public.respond_stable_invitation(
    (select rider_token from pg_temp.c010_fixture),'accept',
    'c0101100-0000-4000-8000-000000000006'
  )
) update pg_temp.c010_fixture fixture set rider_membership=accepted.membership_id
from accepted;

select set_config('request.jwt.claim.sub',(select auth_groom::text from pg_temp.c010_fixture),true);
with accepted as(
  select * from public.respond_stable_invitation(
    (select groom_token from pg_temp.c010_fixture),'accept',
    'c0101100-0000-4000-8000-000000000007'
  )
) update pg_temp.c010_fixture fixture set groom_membership=accepted.membership_id
from accepted;
do $$ begin
  begin perform public.set_c010_team_role(
    (select stable_a from pg_temp.c010_fixture),
    (select groom_membership from pg_temp.c010_fixture),1,'manager',gen_random_uuid()
  ); raise exception 'groom escalated itself to manager';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub',(select auth_manager_b::text from pg_temp.c010_fixture),true);
with invitation as(
  select * from public.create_c010_stable_invitation(
    (select stable_b from pg_temp.c010_fixture),'rider',
    'c010-trainer@example.invalid',statement_timestamp()+interval '7 days',
    'c0101100-0000-4000-8000-000000000008'
  )
) update pg_temp.c010_fixture fixture set trainer_b_token=invitation.invitation_token
from invitation;
do $$ begin
  begin perform public.set_c010_team_role(
    (select stable_a from pg_temp.c010_fixture),
    (select rider_membership from pg_temp.c010_fixture),1,'manager',gen_random_uuid()
  ); raise exception 'cross-stable role mutation succeeded';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub',(select auth_trainer::text from pg_temp.c010_fixture),true);
with accepted as(
  select * from public.respond_stable_invitation(
    (select trainer_b_token from pg_temp.c010_fixture),'accept',
    'c0101100-0000-4000-8000-000000000009'
  )
) update pg_temp.c010_fixture fixture set trainer_b_membership=accepted.membership_id
from accepted;

-- Horse Authority stays personal. Residency and stable membership alone grant
-- neither horse ownership nor horse visibility.
select set_config('request.jwt.claim.sub',(select auth_horse_owner::text from pg_temp.c010_fixture),true);
with horse as(
  select * from public.create_canonical_horse_profile(
    'Orion C010',null,null,'unknown',null,'Dressuur',null,null,null,null,null,null,
    'c0101200-0000-4000-8000-000000000001'
  )
) update pg_temp.c010_fixture fixture set horse_a1=horse.horse_id from horse;
with horse as(
  select * from public.create_canonical_horse_profile(
    'Nova C010',null,null,'unknown',null,'Dressuur',null,null,null,null,null,null,
    'c0101200-0000-4000-8000-000000000002'
  )
) update pg_temp.c010_fixture fixture set horse_b1=horse.horse_id from horse;
select public.set_c010_horse_residency(
  (select horse_a1 from pg_temp.c010_fixture),(select stable_a from pg_temp.c010_fixture),
  null,'c0101200-0000-4000-8000-000000000003'
);
select public.set_c010_horse_residency(
  (select horse_b1 from pg_temp.c010_fixture),(select stable_b from pg_temp.c010_fixture),
  null,'c0101200-0000-4000-8000-000000000004'
);
select public.set_c010_horse_collaborator(
  (select horse_a1 from pg_temp.c010_fixture),(select rider_profile from pg_temp.c010_fixture),
  'rider',array['horse.view','horse.planning.manage'],true,
  'c0101200-0000-4000-8000-000000000005'
);
select public.set_c010_horse_collaborator(
  (select horse_a1 from pg_temp.c010_fixture),(select trainer_profile from pg_temp.c010_fixture),
  'trainer',array['horse.view'],true,
  'c0101200-0000-4000-8000-000000000006'
);

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_fixture),true);
do $$ begin
  if public.has_canonical_horse_permission(
    (select horse_a1 from pg_temp.c010_fixture),'horse.view'
  )
  then raise exception 'stable manager became horse owner or viewer implicitly'; end if;
end $$;

select set_config('request.jwt.claim.sub',(select auth_trainer::text from pg_temp.c010_fixture),true);
do $$ begin
  if not public.has_canonical_horse_permission((select horse_a1 from pg_temp.c010_fixture),'horse.view')
    or public.has_canonical_horse_permission((select horse_a1 from pg_temp.c010_fixture),'horse.edit')
    or public.has_canonical_horse_permission((select horse_a1 from pg_temp.c010_fixture),'horse.feeding.manage')
  then raise exception 'trainer explicit horse permission boundary failed'; end if;
  begin perform public.create_c010_horse_feeding_plan(
    (select horse_a1 from pg_temp.c010_fixture),'standard','Attack',current_date,null,
    'attack',gen_random_uuid()
  ); raise exception 'trainer changed feeding without explicit permission';
  exception when insufficient_privilege then null; end;
end $$;

-- Participants are canonical profile references, default to the actor when
-- empty, and drive the server-side Mine scope.
select set_config('request.jwt.claim.sub',(select auth_rider::text from pg_temp.c010_fixture),true);
with saved as(
  select public.upsert_c010_horse_schedule_item(
    (select horse_a1 from pg_temp.c010_fixture),null,null,'training','Training',
    'Losrijden','normal',statement_timestamp()+interval '1 day',
    statement_timestamp()+interval '1 day 1 hour','Europe/Amsterdam','planned',
    null,array[(select rider_profile from pg_temp.c010_fixture)],
    'c0101300-0000-4000-8000-000000000001'
  ) result
) update pg_temp.c010_fixture fixture
set schedule_item_id=(saved.result->>'schedule_item_id')::uuid from saved;
do $$ begin
  if (select count(*) from public.list_c010_horse_schedule(
      (select horse_a1 from pg_temp.c010_fixture),statement_timestamp(),
      statement_timestamp()+interval '2 days','mine'))<>1
    or (select count(*) from public.schedule_item_participants
      where schedule_item_id=(select schedule_item_id from pg_temp.c010_fixture)
        and status='active')<>1
  then raise exception 'server-side My tasks or participant contract failed'; end if;
end $$;

select set_config('request.jwt.claim.sub',(select auth_outsider::text from pg_temp.c010_fixture),true);
do $$ begin
  begin perform public.list_c010_horse_schedule(
    (select horse_a1 from pg_temp.c010_fixture),statement_timestamp(),
    statement_timestamp()+interval '2 days','all'
  ); raise exception 'outsider read cross-horse schedule metadata';
  exception when insufficient_privilege then null; end;
  begin perform public.get_c010_stable_workspace(
    (select stable_a from pg_temp.c010_fixture),statement_timestamp(),
    statement_timestamp()+interval '2 days',current_date,'all'
  ); raise exception 'outsider read private stable workspace';
  exception when insufficient_privilege then null; end;
end $$;

-- Revoking a membership closes organization access while explicit Horse ACL
-- remains deliberate and all historical participant rows remain referential.
select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_fixture),true);
select public.revoke_c010_membership(
  (select stable_a from pg_temp.c010_fixture),(select rider_membership from pg_temp.c010_fixture),
  1,'c0101400-0000-4000-8000-000000000001'
);
select set_config('request.jwt.claim.sub',(select auth_rider::text from pg_temp.c010_fixture),true);
do $$ begin
  if public.has_organization_permission((select stable_a from pg_temp.c010_fixture),'organization.view')
    or not public.has_canonical_horse_permission((select horse_a1 from pg_temp.c010_fixture),'horse.view')
    or not exists(select 1 from public.schedule_item_participants
      where schedule_item_id=(select schedule_item_id from pg_temp.c010_fixture))
  then raise exception 'membership revoke corrupted access or participant history'; end if;
end $$;

reset role;
do $$
declare trainer_stables text[]; actual_owner uuid;
begin
  select pg_catalog.array_agg(organization_id::text order by organization_id)
  into trainer_stables from public.organization_memberships
  where profile_id=(select trainer_profile from pg_temp.c010_fixture) and status='active';
  if pg_catalog.cardinality(trainer_stables)<>2 then
    raise exception 'shared trainer did not retain two independent stable memberships';
  end if;
  select primary_authority_profile_id into actual_owner
  from public.canonical_horses where id=(select horse_a1 from pg_temp.c010_fixture);
  if actual_owner is distinct from(select horse_owner_profile from pg_temp.c010_fixture)
  then raise exception 'residency or stable manager changed Horse Authority'; end if;
  if (select count(*) from public.organizations
      where id in((select stable_a from pg_temp.c010_fixture),(select stable_b from pg_temp.c010_fixture)))<>2
    or (select count(*) from public.organization_roles
      where organization_id=(select stable_a from pg_temp.c010_fixture)
        and code in('manager','rider','trainer','groom'))<>4
  then raise exception 'canonical stable or role templates are incomplete'; end if;
end $$;

select extensions.pass(
  'C-010 stable, multi-stable team, invitation, horse ACL, participants, scope and revoke contract is secure'
);
select * from extensions.finish();

rollback;
