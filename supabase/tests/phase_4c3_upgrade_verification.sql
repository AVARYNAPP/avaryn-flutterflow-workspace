begin;

do $$
declare
  relation_name text;
  row_count bigint;
begin
  if not exists (
    select 1
    from public.stables
    where id = '4c3d2000-0000-0000-0000-000000000001'
      and name = '4C.3 upgrade control'
      and status = 'active'
      and timezone = 'Europe/Amsterdam'
  ) or not exists (
    select 1
    from public.stable_memberships
    where id = '4c3d5000-0000-0000-0000-000000000001'
      and role = 'owner'
      and status = 'active'
      and joined_at = '2026-07-27 06:00:00+00'
  ) or not exists (
    select 1
    from public.horses
    where id = '4c3d6000-0000-0000-0000-000000000001'
      and stable_id = '4c3d2000-0000-0000-0000-000000000001'
      and display_name = '4C.3 Upgrade Horse'
      and status = 'active'
      and row_version = 1
  ) then
    raise exception '4C.3 upgrade changed existing stable/member/Horse data';
  end if;

  if not exists (
    select 1
    from public.horse_identifiers
    where id = '4c3d8000-0000-0000-0000-000000000001'
      and horse_id = '4c3d6000-0000-0000-0000-000000000001'
      and identifier_type = 'passport'
      and identifier_value = 'UPGRADE-PASSPORT-001'
      and row_version = 1
  ) or not exists (
    select 1
    from public.horse_relationships
    where id = '4c3da000-0000-0000-0000-000000000001'
      and horse_id = '4c3d6000-0000-0000-0000-000000000001'
      and relationship_type = 'owner'
      and status = 'active'
      and row_version = 1
  ) or (
    select count(*)
    from private.horse_identifier_mutation_receipts
    where request_id = '4c3d9000-0000-0000-0000-000000000001'
  ) <> 1 or (
    select count(*)
    from private.horse_relationship_mutation_receipts
    where request_id = '4c3db000-0000-0000-0000-000000000001'
  ) <> 1 then
    raise exception '4C.3 upgrade changed existing 4C.2B data/receipts';
  end if;

  foreach relation_name in array array[
    'schedule_series',
    'schedule_items',
    'schedule_assignments',
    'schedule_executions',
    'schedule_change_events'
  ]
  loop
    if not (
      select c.relrowsecurity
      from pg_catalog.pg_class c
      where c.oid = ('public.' || relation_name)::regclass
    ) or has_table_privilege(
      'authenticated',
      'public.' || relation_name,
      'INSERT'
    ) or has_table_privilege(
      'authenticated',
      'public.' || relation_name,
      'UPDATE'
    ) or has_table_privilege(
      'authenticated',
      'public.' || relation_name,
      'DELETE'
    ) then
      raise exception '4C.3 RLS/direct-DML incorrect for %', relation_name;
    end if;
    execute format(
      'select count(*) from public.%I',
      relation_name
    ) into strict row_count;
    if row_count <> 0 then
      raise exception '4C.3 upgrade fabricated schedule data';
    end if;
  end loop;

  if (select count(*) from private.schedule_mutation_receipts) <> 0
    or has_table_privilege(
      'authenticated',
      'private.schedule_mutation_receipts',
      'SELECT'
    )
  then
    raise exception '4C.3 upgrade fabricated/exposed mutation receipts';
  end if;

  if has_sequence_privilege(
    'anon',
    'public.schedule_change_events_id_seq',
    'USAGE'
  ) or has_sequence_privilege(
    'anon',
    'public.schedule_change_events_id_seq',
    'SELECT'
  ) or has_sequence_privilege(
    'anon',
    'public.schedule_change_events_id_seq',
    'UPDATE'
  ) or has_sequence_privilege(
    'authenticated',
    'public.schedule_change_events_id_seq',
    'USAGE'
  ) or has_sequence_privilege(
    'authenticated',
    'public.schedule_change_events_id_seq',
    'SELECT'
  ) or has_sequence_privilege(
    'authenticated',
    'public.schedule_change_events_id_seq',
    'UPDATE'
  ) then
    raise exception '4C.3 upgrade exposed the audit identity sequence';
  end if;

  if to_regprocedure(
    'public.upsert_horse_identifier(uuid,uuid,bigint,uuid,text,text,text,text,date,date)'
  ) is null or to_regprocedure(
    'public.add_horse_relationship(uuid,uuid,text,uuid,date,text)'
  ) is null or to_regprocedure(
    'public.create_schedule_item(uuid,uuid,text,text,text,text,text,timestamptz,timestamptz,text,date,time,uuid)'
  ) is null or to_regprocedure(
    'public.record_schedule_execution(uuid,uuid,text,timestamptz,timestamptz,timestamp,text,text,uuid,text)'
  ) is null or to_regprocedure(
    'public.list_today_schedule(uuid,date)'
  ) is null then
    raise exception '4C.3 upgrade changed/missed required RPC signatures';
  end if;

  if not exists (
    select 1
    from pg_catalog.pg_constraint constraint_row
    where constraint_row.conrelid = 'public.schedule_items'::regclass
      and constraint_row.conname = 'schedule_items_series_fk'
      and constraint_row.contype = 'f'
  ) or not exists (
    select 1
    from pg_catalog.pg_constraint constraint_row
    where constraint_row.conrelid = 'public.schedule_assignments'::regclass
      and constraint_row.conname = 'schedule_assignments_member_fk'
      and constraint_row.contype = 'f'
  ) then
    raise exception '4C.3 same-stable foreign keys are missing';
  end if;
end;
$$;

rollback;
