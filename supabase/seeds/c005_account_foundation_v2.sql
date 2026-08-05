\set ON_ERROR_STOP on

\if :{?c005_environment}
\else
  \echo 'C005 seed refused: c005_environment is required.'
  \quit 2
\endif

begin;

select pg_catalog.set_config('avaryn.c005_environment',:'c005_environment',true);

do $$
begin
  if pg_catalog.current_setting('avaryn.c005_environment',true)
      not in('staging','local-drill')
  then raise exception using errcode='42501',message='C005_SEED_ENVIRONMENT_FORBIDDEN';end if;
  if exists(
    select 1 from auth.users where id in(
      'c0050000-0000-4000-8000-000000000001',
      'c0050000-0000-4000-8000-000000000002',
      'c0050000-0000-4000-8000-000000000003',
      'c0050000-0000-4000-8000-000000000004'
    )
  ) then raise exception using errcode='55000',message='C005_SEED_REQUIRES_CLEAN_TARGET';end if;
end $$;

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  banned_until,raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
  ('00000000-0000-0000-0000-000000000000','c0050000-0000-4000-8000-000000000001',
   'authenticated','authenticated','c005-personal-only@example.invalid','',now(),'infinity',
   '{"provider":"email","providers":["email"]}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','c0050000-0000-4000-8000-000000000002',
   'authenticated','authenticated','c005-authority@example.invalid','',now(),'infinity',
   '{"provider":"email","providers":["email"]}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','c0050000-0000-4000-8000-000000000003',
   'authenticated','authenticated','c005-collaborator@example.invalid','',now(),'infinity',
   '{"provider":"email","providers":["email"]}','{}',now(),now()),
  ('00000000-0000-0000-0000-000000000000','c0050000-0000-4000-8000-000000000004',
   'authenticated','authenticated','c005-outsider@example.invalid','',now(),'infinity',
   '{"provider":"email","providers":["email"]}','{}',now(),now());

create temporary table c005_seed_fixture as
select
  (select id from public.profiles where auth_user_id='c0050000-0000-4000-8000-000000000001') personal_profile,
  (select id from public.profiles where auth_user_id='c0050000-0000-4000-8000-000000000002') authority_profile,
  (select id from public.profiles where auth_user_id='c0050000-0000-4000-8000-000000000003') collaborator_profile,
  (select id from public.profiles where auth_user_id='c0050000-0000-4000-8000-000000000004') outsider_profile,
  null::uuid stable_id,null::uuid trainer_id,null::uuid horse_without_residency_id,
  null::uuid linked_horse_id,null::uuid link_id;
grant select,update on pg_temp.c005_seed_fixture to authenticated;

set local role authenticated;
select pg_catalog.set_config('request.jwt.claim.role','authenticated',true);
select pg_catalog.set_config('request.jwt.claim.sub','c0050000-0000-4000-8000-000000000002',true);

with created as(
  select * from public.create_organization(
    'stable','C005 Fictional Stable','Fictitious staging-only fixture.',
    'c0051000-0000-4000-8000-000000000001','{}'
  )
) update pg_temp.c005_seed_fixture fixture set stable_id=created.organization_id from created;

with created as(
  select * from public.create_canonical_horse(
    'C005 No Residency',date '2018-04-12','unknown','Fictitious',
    'c0051000-0000-4000-8000-000000000002','{}'
  )
) update pg_temp.c005_seed_fixture fixture
  set horse_without_residency_id=created.horse_id from created;

with created as(
  select * from public.create_canonical_horse(
    'C005 Linked Horse',date '2016-09-03','mare','Fictitious',
    'c0051000-0000-4000-8000-000000000003','{}'
  )
) update pg_temp.c005_seed_fixture fixture set linked_horse_id=created.horse_id from created;

select * from public.grant_horse_profile_permission(
  (select horse_without_residency_id from pg_temp.c005_seed_fixture),
  (select collaborator_profile from pg_temp.c005_seed_fixture),
  'horse.view',null,null,null,'MANUAL_GRANT',
  'c0051000-0000-4000-8000-000000000004'
);

select public.start_horse_person_ownership(
  (select horse_without_residency_id from pg_temp.c005_seed_fixture),
  (select authority_profile from pg_temp.c005_seed_fixture),60,null,
  'c0051000-0000-4000-8000-000000000005'
);
select public.start_horse_person_ownership(
  (select horse_without_residency_id from pg_temp.c005_seed_fixture),
  (select collaborator_profile from pg_temp.c005_seed_fixture),40,null,
  'c0051000-0000-4000-8000-000000000006'
);

select * from public.switch_horse_residency(
  (select linked_horse_id from pg_temp.c005_seed_fixture),
  (select stable_id from pg_temp.c005_seed_fixture),null,
  'c0051000-0000-4000-8000-000000000007'
);

select pg_catalog.set_config('request.jwt.claim.sub','c0050000-0000-4000-8000-000000000003',true);
with created as(
  select * from public.create_organization(
    'trainer_practice','C005 Fictional Trainer','Fictitious staging-only fixture.',
    'c0051000-0000-4000-8000-000000000008','{}'
  )
) update pg_temp.c005_seed_fixture fixture set trainer_id=created.organization_id from created;

select pg_catalog.set_config('request.jwt.claim.sub','c0050000-0000-4000-8000-000000000002',true);
with proposed as(
  select * from public.propose_organization_horse_link(
    (select linked_horse_id from pg_temp.c005_seed_fixture),
    (select trainer_id from pg_temp.c005_seed_fixture),'training_provider','horse',
    'c0051000-0000-4000-8000-000000000009'
  )
) update pg_temp.c005_seed_fixture fixture set link_id=proposed.link_id from proposed;

select pg_catalog.set_config('request.jwt.claim.sub','c0050000-0000-4000-8000-000000000003',true);
select * from public.respond_organization_horse_link(
  (select link_id from pg_temp.c005_seed_fixture),1,'accept',
  'c0051000-0000-4000-8000-000000000010'
);

reset role;
commit;
