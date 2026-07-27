begin;

do $$
begin
  if not exists (
    select 1
    from public.stables
    where id = '4c2b2000-0000-0000-0000-000000000001'
      and name = '4C.2B upgrade control'
      and status = 'active'
  ) or not exists (
    select 1
    from public.stable_memberships
    where id = '4c2b5000-0000-0000-0000-000000000001'
      and role = 'owner'
      and status = 'active'
      and joined_at = '2026-07-27 05:00:00+00'
  ) or not exists (
    select 1
    from public.horses
    where id = '4c2b6000-0000-0000-0000-000000000001'
      and stable_id = '4c2b2000-0000-0000-0000-000000000001'
      and display_name = 'Upgrade Horse'
      and status = 'active'
      and row_version = 1
      and created_at = '2026-07-27 05:01:00+00'
      and updated_at = '2026-07-27 05:01:00+00'
  ) then
    raise exception '4C.2B upgrade changed existing stable, membership or Horse data';
  end if;

  if (
    select count(*)
    from public.horse_profile_change_events
    where horse_id = '4c2b6000-0000-0000-0000-000000000001'
      and request_id = '4c2b7000-0000-0000-0000-000000000002'
      and event_type = 'horse_created'
      and changed_fields = array['display_name']::text[]
      and new_values = '{"display_name":"Upgrade Horse"}'::jsonb
      and created_at = '2026-07-27 05:01:00+00'
  ) <> 1 then
    raise exception '4C.2B upgrade changed existing Horse profile history';
  end if;

  if (select count(*) from public.horse_identifiers) <> 0
    or (select count(*) from public.horse_relationships) <> 0
    or (
      select count(*)
      from private.horse_identifier_mutation_receipts
    ) <> 0
    or (
      select count(*)
      from private.horse_relationship_mutation_receipts
    ) <> 0
  then
    raise exception '4C.2B upgrade fabricated identity or relationship data';
  end if;

  if not exists (
    select 1
    from pg_constraint c
    where c.conrelid = 'public.horse_identifiers'::regclass
      and c.conname = 'horse_identifiers_horse_fk'
      and c.contype = 'f'
  ) or not exists (
    select 1
    from pg_constraint c
    where c.conrelid = 'public.horse_relationships'::regclass
      and c.conname = 'horse_relationships_stable_member_fk'
      and c.contype = 'f'
  ) then
    raise exception '4C.2B same-stable foreign keys are missing';
  end if;

  if to_regprocedure(
    'public.create_horse(uuid,text,uuid,text,date,text,text,text,text)'
  ) is null or to_regprocedure(
    'public.grant_horse_access(uuid,uuid,text,boolean,boolean,boolean,boolean,timestamptz,timestamptz,text,uuid)'
  ) is null then
    raise exception '4C.2B upgrade changed existing Horse Core RPC signatures';
  end if;
end;
$$;

rollback;
