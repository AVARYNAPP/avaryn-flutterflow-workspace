begin;

do $$
declare
  relation_name text;
  row_count bigint;
begin
  if not exists (
    select 1 from public.stables
    where id = '4c5f2000-0000-0000-0000-000000000001'
      and name = '4C.5 upgrade control'
      and timezone = 'Europe/Amsterdam'
      and status = 'active'
  ) or not exists (
    select 1 from public.horses
    where id = '4c5f6000-0000-0000-0000-000000000001'
      and display_name = '4C.5 Upgrade Horse'
      and status = 'active'
      and row_version = 1
  ) then
    raise exception '4C.5 upgrade changed tenant/Horse baseline';
  end if;

  if not exists (
    select 1 from public.schedule_executions
    where id = '4c5fa000-0000-0000-0000-000000000001'
      and execution_status = 'completed'
      and note = 'Preserve 4C.3 execution history.'
  ) or not exists (
    select 1 from public.feeding_plans
    where id = '4c5fb000-0000-0000-0000-000000000001'
      and name = 'Preserve 4C.4 feeding plan'
      and status = 'draft'
      and row_version = 1
  ) or not exists (
    select 1 from public.feeding_plan_versions
    where id = '4c5fc000-0000-0000-0000-000000000001'
      and status = 'draft'
      and change_reason = 'Preserve this immutable reason.'
      and row_version = 1
  ) or not exists (
    select 1 from public.feeding_plan_items
    where id = '4c5fd000-0000-0000-0000-000000000001'
      and product_name = 'Preserved hay'
      and planned_quantity = 3.5
      and override_key = 'upgrade-hay'
      and row_version = 1
  ) then
    raise exception '4C.5 upgrade changed existing 4C.3/4C.4 history';
  end if;

  foreach relation_name in array array[
    'media_assets',
    'media_asset_variants',
    'media_links',
    'media_change_events'
  ] loop
    if not (
      select class.relrowsecurity
      from pg_class class
      where class.oid = ('public.' || relation_name)::regclass
    ) or has_table_privilege(
      'authenticated', 'public.' || relation_name, 'INSERT'
    ) or has_table_privilege(
      'authenticated', 'public.' || relation_name, 'UPDATE'
    ) or has_table_privilege(
      'authenticated', 'public.' || relation_name, 'DELETE'
    ) then
      raise exception '4C.5 upgrade RLS/direct-DML incorrect for %', relation_name;
    end if;
    execute format('select count(*) from public.%I', relation_name)
      into strict row_count;
    if row_count <> 0 then
      raise exception '4C.5 upgrade fabricated media rows in %', relation_name;
    end if;
  end loop;

  if not exists (
    select 1 from storage.buckets
    where id = 'horse-media' and public is false
  ) or (select count(*) from private.media_mutation_receipts) <> 0 then
    raise exception '4C.5 upgrade bucket/receipt state incorrect';
  end if;

  if to_regprocedure(
    'public.create_media_upload_session(uuid,uuid,text,text,uuid)'
  ) is null or to_regprocedure(
    'public.finalize_media_asset(uuid,uuid,bigint,text,bigint,text,text,bigint,text,uuid)'
  ) is null or to_regprocedure(
    'public.link_media_asset(uuid,uuid,uuid,uuid)'
  ) is null or to_regprocedure(
    'public.archive_media_asset(uuid,bigint,uuid)'
  ) is null or to_regprocedure(
    'public.authorize_media_asset_download(uuid,uuid,text)'
  ) is null or to_regprocedure(
    'public.get_media_upload_session(uuid,uuid)'
  ) is null then
    raise exception '4C.5 required RPC signature missing';
  end if;

  if has_function_privilege(
    'authenticated',
    'public.finalize_media_asset(uuid,uuid,bigint,text,bigint,text,text,bigint,text,uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'public.authorize_media_asset_download(uuid,uuid,text)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'public.get_media_upload_session(uuid,uuid)',
    'EXECUTE'
  ) or not has_function_privilege(
    'service_role',
    'public.finalize_media_asset(uuid,uuid,bigint,text,bigint,text,text,bigint,text,uuid)',
    'EXECUTE'
  ) or not has_function_privilege(
    'service_role',
    'public.get_media_upload_session(uuid,uuid)',
    'EXECUTE'
  ) then
    raise exception '4C.5 service boundary ACL incorrect';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.media_assets'::regclass
      and conname = 'media_assets_horse_fk'
      and contype = 'f'
  ) or not exists (
    select 1 from pg_constraint
    where conrelid = 'public.media_links'::regclass
      and conname = 'media_links_execution_fk'
      and contype = 'f'
  ) or not exists (
    select 1 from pg_constraint
    where conrelid = 'public.horses'::regclass
      and conname = 'horses_profile_media_asset_fk'
      and contype = 'f'
  ) then
    raise exception '4C.5 typed same-scope foreign keys missing';
  end if;
end;
$$;

rollback;
