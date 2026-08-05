begin;

select extensions.plan(1);

do $$
declare
  expected_tables text[]:=array[
    'profiles','audit_events','organization_types','permission_definitions',
    'organizations','organization_memberships','organization_roles',
    'organization_role_permissions','organization_membership_roles',
    'canonical_horses','horse_delegated_administrators','horse_person_ownerships',
    'horse_organization_ownerships','horse_relationship_types',
    'horse_person_relationships','organization_horse_link_types',
    'organization_horse_links','horse_residencies','horse_profile_permission_grants',
    'horse_organization_role_permission_grants','organization_invitations',
    'horse_access_invitations','horse_access_invitation_permissions',
    'rider_performance_profile_share_grants',
    'rider_performance_org_role_share_grants','horse_authority_transfers',
    'organization_authority_transfers'
  ];
  role_name text;
  procedure_row record;
begin
  if (
    select count(*) from pg_catalog.pg_class relation
    join pg_catalog.pg_namespace namespace on namespace.oid=relation.relnamespace
    where namespace.nspname='public' and relation.relkind='r'
      and relation.relname=any(expected_tables) and relation.relrowsecurity
      and pg_catalog.pg_get_userbyid(relation.relowner)='postgres'
  )<>pg_catalog.cardinality(expected_tables)
  then raise exception 'C003F_RLS_OR_OWNER_MATRIX_INVALID';end if;

  foreach role_name in array array['anon','authenticated','service_role'] loop
    if exists(
      select 1 from pg_catalog.unnest(expected_tables) table_name
      where pg_catalog.has_table_privilege(
        role_name,pg_catalog.format('public.%I',table_name),'insert,update,delete,truncate'
      )
    ) then raise exception 'C003F_DIRECT_DML_EXPOSED_TO_%',role_name;end if;
  end loop;

  if exists(
    select 1 from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname in('public','private') and procedure.prosecdef
      and (procedure.proconfig is null
        or not procedure.proconfig @> array['search_path=""']::text[])
  ) then raise exception 'C003F_SECURITY_DEFINER_SEARCH_PATH_INVALID';end if;

  if (
    select count(*) from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='public' and procedure.proname like '%authority_transfer'
      and procedure.prosecdef
      and pg_catalog.pg_get_function_result(procedure.oid) like 'TABLE(%'
      and pg_catalog.has_function_privilege('authenticated',procedure.oid,'execute')
      and not pg_catalog.has_function_privilege('anon',procedure.oid,'execute')
      and not pg_catalog.has_function_privilege('service_role',procedure.oid,'execute')
  )<>8 then raise exception 'C003F_TYPED_TRANSFER_RPC_ACL_INVALID';end if;

  if pg_catalog.has_table_privilege('anon','public.horse_authority_transfers','select')
    or pg_catalog.has_table_privilege('authenticated','public.horse_authority_transfers','select')
    or pg_catalog.has_table_privilege('service_role','public.horse_authority_transfers','select')
    or pg_catalog.has_table_privilege('anon','public.organization_authority_transfers','select')
    or pg_catalog.has_table_privilege('authenticated','public.organization_authority_transfers','select')
    or pg_catalog.has_table_privilege('service_role','public.organization_authority_transfers','select')
  then raise exception 'C003F_TRANSFER_TABLE_SELECT_EXPOSED';end if;

  if (
    select count(*) from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='private'
      and pg_catalog.has_function_privilege('authenticated',procedure.oid,'execute')
  )<>19 or exists(
    select 1 from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='private'
      and (pg_catalog.has_function_privilege('anon',procedure.oid,'execute')
        or pg_catalog.has_function_privilege('service_role',procedure.oid,'execute'))
  ) then raise exception 'C003F_PRIVATE_EXECUTE_ALLOWLIST_INVALID';end if;

  for procedure_row in
    select procedure.oid,procedure.proname from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='private' and procedure.proname like 'c003%'
      and procedure.proname<>'c003a_is_valid_iana_time_zone'
  loop
    if pg_catalog.has_function_privilege('anon',procedure_row.oid,'execute')
      or pg_catalog.has_function_privilege('authenticated',procedure_row.oid,'execute')
      or pg_catalog.has_function_privilege('service_role',procedure_row.oid,'execute')
    then raise exception 'C003F_PRIVATE_ROUTINE_EXPOSED_%',procedure_row.proname;end if;
  end loop;

  if (
    select count(*) from pg_catalog.pg_trigger trigger
    where trigger.tgrelid='public.audit_events'::pg_catalog.regclass
      and not trigger.tgisinternal and trigger.tgenabled='O'
      and trigger.tgname in('audit_events_append_only','audit_events_append_only_truncate')
  )<>2 then raise exception 'C003F_AUDIT_IMMUTABILITY_TRIGGER_INVALID';end if;

  if exists(
    select 1 from pg_catalog.pg_publication_tables publication
    where publication.schemaname='public' and publication.tablename=any(expected_tables)
  ) then raise exception 'C003F_SENSITIVE_DIRECT_REALTIME_PUBLICATION';end if;
end $$;

select extensions.pass(
  'C-003F catalog gate: RLS, ACL, SECURITY DEFINER, typed RPC, audit and realtime closure passed'
);
select * from extensions.finish();

rollback;
