begin;

select extensions.plan(1);

do $$
declare
  foundation_tables text[]:=array[
    'profiles','audit_events','organizations','organization_memberships',
    'organization_roles','organization_role_permissions',
    'organization_membership_roles','canonical_horses',
    'horse_delegated_administrators','horse_person_ownerships',
    'horse_organization_ownerships','horse_person_relationships',
    'organization_horse_links','horse_residencies',
    'horse_profile_permission_grants','horse_organization_role_permission_grants',
    'organization_invitations','horse_access_invitations',
    'horse_authority_transfers','organization_authority_transfers'
  ];
  role_name text;
begin
  if (
    select count(*) from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace on namespace.oid=relation.relnamespace
    where namespace.nspname='public' and relation.relkind='r'
      and relation.relname=any(foundation_tables) and relation.relrowsecurity
  )<>pg_catalog.cardinality(foundation_tables)
  then raise exception 'C004_FOUNDATION_RLS_INCOMPLETE';end if;

  foreach role_name in array array['anon','authenticated','service_role'] loop
    if exists(
      select 1 from pg_catalog.unnest(foundation_tables) table_name
      where pg_catalog.has_table_privilege(
        role_name,pg_catalog.format('public.%I',table_name),
        'insert,update,delete,truncate'
      )
    ) then raise exception 'C004_DIRECT_DML_EXPOSED_TO_%',role_name;end if;
  end loop;

  if not exists(
    select 1 from pg_catalog.pg_proc procedure
    where procedure.oid='public.create_organization(text,text,text,uuid,jsonb)'::pg_catalog.regprocedure
      and procedure.prosecdef and pg_catalog.pg_get_function_result(procedure.oid) like 'TABLE(%'
  ) or not exists(
    select 1 from pg_catalog.pg_proc procedure
    where procedure.oid='public.create_canonical_horse(text,date,text,text,uuid,jsonb)'::pg_catalog.regprocedure
      and procedure.prosecdef and pg_catalog.pg_get_function_result(procedure.oid) like 'TABLE(%'
  ) or not exists(
    select 1 from pg_catalog.pg_proc procedure
    where procedure.oid='public.respond_organization_authority_transfer(text,text,uuid)'::pg_catalog.regprocedure
      and procedure.prosecdef and pg_catalog.pg_get_function_result(procedure.oid) like 'TABLE(%'
  ) then raise exception 'C004_TYPED_RPC_CONTRACT_MISSING';end if;

  if exists(
    select 1 from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname in('public','private') and procedure.prosecdef
      and (procedure.proconfig is null
        or not procedure.proconfig @> array['search_path=""']::text[])
  ) then raise exception 'C004_SECURITY_DEFINER_SEARCH_PATH_INVALID';end if;

  if (
    select count(*) from pg_catalog.pg_trigger trigger
    where trigger.tgrelid='public.audit_events'::pg_catalog.regclass
      and not trigger.tgisinternal and trigger.tgenabled='O'
      and trigger.tgname in('audit_events_append_only','audit_events_append_only_truncate')
  )<>2 then raise exception 'C004_AUDIT_IMMUTABILITY_INCOMPLETE';end if;

  if not exists(select 1 from pg_catalog.pg_attribute attribute
      where attribute.attrelid='public.profiles'::pg_catalog.regclass
        and attribute.attname='access_version' and not attribute.attisdropped)
    or not exists(select 1 from pg_catalog.pg_attribute attribute
      where attribute.attrelid='public.organizations'::pg_catalog.regclass
        and attribute.attname='access_version' and not attribute.attisdropped)
    or not exists(select 1 from pg_catalog.pg_attribute attribute
      where attribute.attrelid='public.canonical_horses'::pg_catalog.regclass
        and attribute.attname in('access_version','authority_version')
        and not attribute.attisdropped group by attribute.attrelid having count(*)=2)
  then raise exception 'C004_VERSION_CONTRACT_INCOMPLETE';end if;
end $$;

select extensions.pass(
  'C-004 Account Foundation v2 is fully mapped to the approved C-003 implementation'
);
select * from extensions.finish();

rollback;
