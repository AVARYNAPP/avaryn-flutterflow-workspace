-- Read only, AFTER all47 migrations. No test accounts/fixtures are created here.
begin read only;
set local statement_timeout = '15s';
select jsonb_build_object(
  'auth_users',(select count(*) from auth.users),
  'profiles',(select count(*) from public.profiles),
  'organizations',(select count(*) from public.organizations),
  'canonical_horses',(select count(*) from public.canonical_horses),
  'storage_objects',(select count(*) from storage.objects),
  'vitality_days',(select count(*) from private.c010_vitality_days),
  'vitality_receipts',(select count(*) from private.c010_vitality_receipts),
  'private_vitality_direct_client_read',has_table_privilege('authenticated','private.c010_vitality_days','SELECT'),
  'private_vitality_direct_client_write',has_table_privilege('authenticated','private.c010_vitality_days','INSERT,UPDATE,DELETE'),
  'vitality_anon_execute',has_function_privilege('anon','public.get_c010_my_vitality_day(date)','EXECUTE'),
  'vitality_authenticated_execute',has_function_privilege('authenticated','public.get_c010_my_vitality_day(date)','EXECUTE'),
  'deletion_prepare_client_execute',has_function_privilege('authenticated','public.prepare_c010_account_deletion(uuid,uuid)','EXECUTE'),
  'deletion_prepare_service_execute',has_function_privilege('service_role','public.prepare_c010_account_deletion(uuid,uuid)','EXECUTE'),
  'migration_count',(select count(*) from supabase_migrations.schema_migrations),
  'storage_buckets',(select jsonb_agg(jsonb_build_object('id',id,'public',public,'file_size_limit',file_size_limit,'allowed_mime_types',allowed_mime_types)) from storage.buckets)
);
-- Catalog evidence supports comparison with tested source; not a substitute for
-- actual hosted Auth/RLS/CAS/Storage tests under separately scoped identities.
select n.nspname as schema,p.proname,pg_get_function_identity_arguments(p.oid) as arguments,
       pg_get_userbyid(p.proowner) as owner,p.prosecdef,p.proconfig,p.proacl,
       md5(pg_get_functiondef(p.oid)) as definition_md5
from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
where n.nspname in('public','private') and p.prokind='f'
  and (p.proname like '%c010%' or p.proname in('get_current_account_profile','create_canonical_horse_profile'))
order by 1,2,3;
commit;
