-- Run only when preflight confirms this table exists. Statements are code, not data.
begin read only;
set local statement_timeout = '15s';
select version,name,statements from supabase_migrations.schema_migrations order by version;
commit;
