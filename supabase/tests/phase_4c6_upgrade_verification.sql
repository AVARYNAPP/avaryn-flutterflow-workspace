begin;

do $$
declare
  relation_name text;
begin
  if not exists (
    select 1 from public.stables
    where id = '4c6f2000-0000-0000-0000-000000000001'
      and name = '4C.6 upgrade control'
      and timezone = 'Europe/Amsterdam'
      and status = 'active'
  ) or not exists (
    select 1 from public.horses
    where id = '4c6f6000-0000-0000-0000-000000000001'
      and display_name = '4C.6 Upgrade Horse'
      and status = 'active'
      and row_version = 1
  ) or not exists (
    select 1 from public.horse_profile_change_events
    where horse_id = '4c6f6000-0000-0000-0000-000000000001'
      and request_id = '4c6f8000-0000-0000-0000-000000000001'
  ) then
    raise exception '4C.6 upgrade changed the 4C.5 baseline';
  end if;

  if not exists (
    select 1 from public.stable_sync_authorities
    where stable_id = '4c6f2000-0000-0000-0000-000000000001'
      and authority_version > 0
  ) or not exists (
    select 1 from public.stable_change_events
    where stable_id = '4c6f2000-0000-0000-0000-000000000001'
      and horse_id = '4c6f6000-0000-0000-0000-000000000001'
      and entity_type = 'horse'
      and entity_id = '4c6f6000-0000-0000-0000-000000000001'
      and change_kind = 'horse_created'
      and data_category = 'horse.basic'
  ) or not exists (
    select 1
    from public.stable_sync_authorities authority
    where authority.stable_id =
      '4c6f2000-0000-0000-0000-000000000001'
      and authority.last_change_sequence = (
        select max(event.sequence_id)
        from public.stable_change_events event
        where event.stable_id = authority.stable_id
      )
  ) then
    raise exception '4C.6 upgrade did not backfill the safe cursor';
  end if;

  foreach relation_name in array array[
    'client_sync_devices',
    'sync_conflicts',
    'legacy_import_jobs',
    'legacy_import_items'
  ] loop
    if exists (
      select 1
      from pg_catalog.pg_class class
      join pg_catalog.pg_namespace namespace
        on namespace.oid = class.relnamespace
      where namespace.nspname = 'public'
        and class.relname = relation_name
        and not class.relrowsecurity
    ) or has_table_privilege(
      'authenticated', 'public.' || relation_name, 'INSERT'
    ) or has_table_privilege(
      'authenticated', 'public.' || relation_name, 'UPDATE'
    ) or has_table_privilege(
      'authenticated', 'public.' || relation_name, 'DELETE'
    ) then
      raise exception '4C.6 upgrade ACL/RLS incorrect for %', relation_name;
    end if;
  end loop;

  if (select count(*) from public.client_sync_devices) <> 0
    or (select count(*) from public.sync_conflicts) <> 0
    or (select count(*) from public.legacy_import_jobs) <> 0
    or (select count(*) from public.legacy_import_items) <> 0
    or (select count(*) from private.client_mutation_receipts) <> 0
    or (select count(*) from private.legacy_feeding_plan_snapshots) <> 0
    or (
      select count(*) from private.legacy_schedule_execution_history
    ) <> 0
  then
    raise exception '4C.6 upgrade fabricated client/import rows';
  end if;

  if to_regprocedure(
    'public.pull_operation_changes(uuid,bigint,integer,bigint)'
  ) is null or to_regprocedure(
    'public.get_encrypted_offline_dayset(uuid,uuid,date,text,bigint)'
  ) is null or to_regprocedure(
    'public.resolve_sync_conflict(uuid,text,text,uuid)'
  ) is null or to_regprocedure(
    'public.sync_feeding_execution(uuid,uuid,bigint,uuid,uuid,text,timestamptz,timestamptz,timestamp,text,text,numeric,text,numeric,text,text,text)'
  ) is null or to_regprocedure(
    'public.create_legacy_import_job(uuid,bytea,text,integer,integer,jsonb,bytea,jsonb,uuid)'
  ) is null or to_regprocedure(
    'public.cutover_legacy_import_job(uuid,bigint,bytea,boolean,uuid)'
  ) is null then
    raise exception '4C.6 required RPC signature missing';
  end if;
end;
$$;

rollback;
