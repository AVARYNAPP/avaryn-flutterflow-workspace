\set ON_ERROR_STOP on

begin;

do $$
declare
  personal_profile uuid;
  authority_profile uuid;
  collaborator_profile uuid;
  outsider_profile uuid;
  no_residency_horse uuid;
  linked_horse uuid;
begin
  select id into personal_profile from public.profiles
    where auth_user_id='c0050000-0000-4000-8000-000000000001';
  select id into authority_profile from public.profiles
    where auth_user_id='c0050000-0000-4000-8000-000000000002';
  select id into collaborator_profile from public.profiles
    where auth_user_id='c0050000-0000-4000-8000-000000000003';
  select id into outsider_profile from public.profiles
    where auth_user_id='c0050000-0000-4000-8000-000000000004';
  select id into no_residency_horse from public.canonical_horses
    where creation_correlation_id='c0051000-0000-4000-8000-000000000002';
  select id into linked_horse from public.canonical_horses
    where creation_correlation_id='c0051000-0000-4000-8000-000000000003';

  if personal_profile is null or authority_profile is null
    or collaborator_profile is null or outsider_profile is null
  then raise exception 'C005_SMOKE_PROFILES_MISSING';end if;
  if exists(select 1 from public.organization_memberships where profile_id=personal_profile)
    or exists(select 1 from public.canonical_horses where primary_authority_profile_id=personal_profile)
  then raise exception 'C005_PERSONAL_ONLY_SCOPE_INVALID';end if;
  if (select count(*) from public.organizations
      where creation_correlation_id in(
        'c0051000-0000-4000-8000-000000000001',
        'c0051000-0000-4000-8000-000000000008'))<>2
    or no_residency_horse is null or linked_horse is null
  then raise exception 'C005_CORE_FIXTURE_INCOMPLETE';end if;
  if exists(select 1 from public.horse_residencies
      where horse_id=no_residency_horse and status='active')
    or (select count(*) from public.horse_residencies
      where horse_id=linked_horse and status='active')<>1
  then raise exception 'C005_RESIDENCY_FIXTURE_INVALID';end if;
  if (select count(*) from public.horse_person_ownerships
      where horse_id=no_residency_horse and status='active')<>2
  then raise exception 'C005_OWNERSHIP_FIXTURE_INVALID';end if;
  if not exists(
    select 1 from public.horse_profile_permission_grants grant_row
    join public.permission_definitions permission on permission.id=grant_row.permission_id
    where grant_row.horse_id=no_residency_horse
      and grant_row.grantee_profile_id=collaborator_profile
      and grant_row.status='active' and permission.code='horse.view'
  ) then raise exception 'C005_EXPLICIT_GRANT_MISSING';end if;
  if not exists(select 1 from public.organization_horse_links
      where horse_id=linked_horse and status='active')
  then raise exception 'C005_ACTIVE_LINK_MISSING';end if;
  if exists(
    select 1 from public.horse_profile_permission_grants
    where horse_id=linked_horse and grantee_profile_id=collaborator_profile
      and status='active'
  ) then raise exception 'C005_LINK_GRANTED_IMPLICIT_ACCESS';end if;
  if exists(
    select 1 from public.horse_profile_permission_grants
    where grantee_profile_id=outsider_profile and status='active'
  ) then raise exception 'C005_OUTSIDER_HAS_GRANT';end if;
  if exists(select 1 from auth.users
      where id::text like 'c005%' and email not like '%@example.invalid')
  then raise exception 'C005_NON_FICTITIOUS_EMAIL';end if;
  if (select count(*) from public.audit_events
      where correlation_id::text like 'c0051%')<10
  then raise exception 'C005_AUDIT_EVIDENCE_INCOMPLETE';end if;
end $$;

select pg_catalog.set_config('request.jwt.claim.role','authenticated',true);
select pg_catalog.set_config('request.jwt.claim.sub','c0050000-0000-4000-8000-000000000004',true);
set local role authenticated;
do $$
begin
  if exists(select 1 from public.canonical_horses)
  then raise exception 'C005_OUTSIDER_RLS_LEAK';end if;
  begin
    update public.organizations set name='forbidden';
    raise exception 'C005_DIRECT_DML_ALLOWED';
  exception when insufficient_privilege then null;end;
end $$;

reset role;
rollback;
