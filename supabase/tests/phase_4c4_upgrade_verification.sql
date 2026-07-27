begin;

do $$
declare
  relation_name text;
  row_count bigint;
begin
  if not exists (
    select 1
    from public.stables
    where id = '4c4f2000-0000-0000-0000-000000000001'
      and name = '4C.4 upgrade control'
      and timezone = 'Europe/Amsterdam'
  ) or not exists (
    select 1
    from public.horses
    where id = '4c4f6000-0000-0000-0000-000000000001'
      and display_name = '4C.4 Upgrade Horse'
      and row_version = 1
  ) then
    raise exception '4C.4 upgrade changed existing tenant/Horse data';
  end if;

  if not exists (
    select 1
    from public.schedule_series
    where id = '4c4f8000-0000-0000-0000-000000000001'
      and title = 'Upgrade check'
      and instruction = 'Preserve this instruction.'
      and row_version = 1
  ) or not exists (
    select 1
    from public.schedule_items
    where id = '4c4fa000-0000-0000-0000-000000000001'
      and state = 'in_progress'
      and source_timezone = 'Europe/Amsterdam'
      and source_local_date = '2026-07-28'
      and row_version = 1
  ) or not exists (
    select 1
    from public.schedule_assignments
    where id = '4c4fb000-0000-0000-0000-000000000001'
      and status = 'accepted'
      and row_version = 1
  ) or not exists (
    select 1
    from public.schedule_executions
    where id = '4c4fc000-0000-0000-0000-000000000001'
      and execution_status = 'partial'
      and note = 'Preserve this execution note.'
  ) or not exists (
      select 1
    from public.schedule_change_events
    where request_id = '4c4fd000-0000-0000-0000-000000000001'
      and event_type = 'schedule_execution_recorded'
  ) then
    raise exception '4C.4 upgrade changed existing 4C.3 planning history';
  end if;

  foreach relation_name in array array[
    'feeding_plans',
    'feeding_plan_versions',
    'feeding_plan_items',
    'feeding_occurrences',
    'feeding_execution_details',
    'feeding_change_events'
  ]
  loop
    if not (
      select c.relrowsecurity
      from pg_catalog.pg_class c
      where c.oid = ('public.' || relation_name)::regclass
    ) or has_table_privilege(
      'authenticated', 'public.' || relation_name, 'INSERT'
    ) or has_table_privilege(
      'authenticated', 'public.' || relation_name, 'UPDATE'
    ) or has_table_privilege(
      'authenticated', 'public.' || relation_name, 'DELETE'
    ) then
      raise exception '4C.4 RLS/direct-DML incorrect for %', relation_name;
    end if;
    execute format('select count(*) from public.%I', relation_name)
      into strict row_count;
    if row_count <> 0 then
      raise exception '4C.4 upgrade fabricated feeding data in %', relation_name;
    end if;
  end loop;

  if (select count(*) from private.feeding_mutation_receipts) <> 0
    or has_table_privilege(
      'authenticated',
      'private.feeding_mutation_receipts',
      'SELECT'
    )
  then
    raise exception '4C.4 upgrade fabricated/exposed feeding receipts';
  end if;

  if has_sequence_privilege(
    'anon', 'public.feeding_change_events_id_seq', 'USAGE'
  ) or has_sequence_privilege(
    'authenticated', 'public.feeding_change_events_id_seq', 'USAGE'
  ) or has_sequence_privilege(
    'authenticated', 'public.feeding_change_events_id_seq', 'SELECT'
  ) then
    raise exception '4C.4 upgrade exposed feeding event sequence';
  end if;

  if to_regprocedure(
    'public.create_feeding_plan(uuid,text,text,date,date,uuid)'
  ) is null or to_regprocedure(
    'public.create_feeding_plan_version(uuid,text,text,text,uuid)'
  ) is null or to_regprocedure(
    'public.upsert_feeding_plan_item(uuid,uuid,bigint,text,text,text,text,numeric,text,text,text,time,smallint[],integer,text,uuid,text,date,text,uuid)'
  ) is null or to_regprocedure(
    'public.approve_feeding_plan_version(uuid,bigint,uuid)'
  ) is null or to_regprocedure(
    'public.activate_feeding_plan_version(uuid,bigint,date,uuid)'
  ) is null or to_regprocedure(
    'public.retire_feeding_plan(uuid,bigint,text,uuid)'
  ) is null or to_regprocedure(
    'public.record_feeding_execution(uuid,uuid,uuid,text,timestamptz,timestamptz,timestamp,text,text,uuid,text,numeric,text,numeric,text,text,text)'
  ) is null then
    raise exception '4C.4 required RPC signature missing';
  end if;

  if not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.feeding_plans'::regclass
      and conname = 'feeding_plans_horse_fk' and contype = 'f'
  ) or not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.feeding_occurrences'::regclass
      and conname = 'feeding_occurrences_plan_item_fk' and contype = 'f'
  ) or not exists (
    select 1 from pg_catalog.pg_constraint
    where conrelid = 'public.feeding_execution_details'::regclass
      and conname = 'feeding_execution_details_execution_fk' and contype = 'f'
  ) then
    raise exception '4C.4 same-stable/typed foreign keys missing';
  end if;
end;
$$;

rollback;
