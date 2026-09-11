-- Read only; target identity must first match the dashboard connection metadata.
-- Save result privately. No passwords, Auth rows, emails or object paths returned.
begin read only;
set local statement_timeout = '15s';
select jsonb_build_object(
  'database',current_database(),
  'current_role',current_user,
  'session_role',session_user,
  'server_version',current_setting('server_version'),
  'server_version_num',current_setting('server_version_num'),
  'auth_users',(select count(*) from auth.users),
  'auth_identities',(select count(*) from auth.identities),
  'storage_objects',(select count(*) from storage.objects),
  'storage_buckets',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'public',public)), '[]') from storage.buckets),
  'application_relations',(
    select coalesce(jsonb_agg(n.nspname||'.'||c.relname order by n.nspname,c.relname),'[]')
    from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
    where n.nspname in('public','private') and c.relkind in('r','p','v','m','S')
      and not exists(select 1 from pg_catalog.pg_depend d where d.classid='pg_catalog.pg_class'::regclass
        and d.objid=c.oid and d.deptype='e')
  ),
  'migration_history_present',to_regclass('supabase_migrations.schema_migrations') is not null,
  'auth_uid_present',to_regprocedure('auth.uid()') is not null,
  'crypto_functions_present',to_regprocedure('extensions.gen_random_uuid()') is not null
    and to_regprocedure('extensions.gen_random_bytes(integer)') is not null
    and to_regprocedure('extensions.hmac(bytea,bytea,text)') is not null
    and to_regprocedure('extensions.digest(bytea,text)') is not null,
  'btree_gist_available',exists(select 1 from pg_catalog.pg_available_extensions where name='btree_gist'),
  'required_roles',(select jsonb_agg(rolname order by rolname) from pg_catalog.pg_roles
    where rolname in('postgres','anon','authenticated','service_role','authenticator')),
  'tls',(select jsonb_build_object('ssl',ssl,'version',version) from pg_catalog.pg_stat_ssl where pid=pg_backend_pid())
);
commit;
