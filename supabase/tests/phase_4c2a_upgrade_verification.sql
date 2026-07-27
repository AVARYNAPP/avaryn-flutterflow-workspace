begin;

do $$
begin
  if not exists (
    select 1
    from public.stables
    where id = '4cb00000-0000-0000-0000-000000000001'
      and name = '4C.2A upgrade control'
      and status = 'active'
      and timezone = 'UTC'
      and locale = 'nl'
      and created_by_user_id = '4ca00000-0000-0000-0000-000000000001'
      and creation_request_id = '4cc00000-0000-0000-0000-000000000001'
  ) then
    raise exception 'Upgrade changed or removed the existing stable';
  end if;
  if not exists (
    select 1
    from public.stable_members
    where id = '4cd00000-0000-0000-0000-000000000001'
      and stable_id = '4cb00000-0000-0000-0000-000000000001'
      and display_name = 'Upgrade owner'
      and source = 'owner_creation'
  ) then
    raise exception 'Upgrade changed or removed the existing roster row';
  end if;
  if not exists (
    select 1
    from public.stable_memberships
    where id = '4ce00000-0000-0000-0000-000000000001'
      and stable_id = '4cb00000-0000-0000-0000-000000000001'
      and user_id = '4ca00000-0000-0000-0000-000000000001'
      and stable_member_id = '4cd00000-0000-0000-0000-000000000001'
      and role = 'owner'
      and status = 'active'
      and joined_at = '2026-07-26 12:00:00+00'
  ) then
    raise exception 'Upgrade changed or removed the existing membership';
  end if;
  if not exists (
    select 1
    from public.stable_security_events
    where stable_id = '4cb00000-0000-0000-0000-000000000001'
      and actor_user_id = '4ca00000-0000-0000-0000-000000000001'
      and actor_membership_id = '4ce00000-0000-0000-0000-000000000001'
      and event_type = 'stable_updated'
      and request_id = '4cf00000-0000-0000-0000-000000000001'
      and metadata = '{"upgrade_fixture":true}'::jsonb
      and horse_id is null
      and created_at = '2026-07-26 12:01:00+00'
  ) then
    raise exception 'Upgrade changed or removed the existing 4C.2A0 event';
  end if;
  if (
    select count(*)
    from public.stable_security_events
    where stable_id = '4cb00000-0000-0000-0000-000000000001'
  ) <> 1 then
    raise exception 'Upgrade added or removed stable security events';
  end if;
  if not exists (
    select 1
    from pg_constraint c
    where c.conrelid = 'public.stable_security_events'::regclass
      and c.conname = 'stable_security_events_horse_fk'
      and c.contype = 'f'
      and c.convalidated
  ) then
    raise exception 'Upgrade did not validate the typed Horse FK';
  end if;
  if to_regprocedure(
    'private.write_security_event(uuid,text,uuid,uuid,uuid,uuid,uuid,jsonb)'
  ) is null then
    raise exception 'Existing phase-4B event writer signature changed';
  end if;
  if (
    select count(*)
    from public.horses
  ) <> 0 or (
    select count(*)
    from public.horse_access_grants
  ) <> 0 or (
    select count(*)
    from public.horse_profile_change_events
  ) <> 0 then
    raise exception 'Upgrade fabricated Horse Core data';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4ca00000-0000-0000-0000-000000000001',
  true
);
select private.write_security_event(
  '4cb00000-0000-0000-0000-000000000001',
  'stable_updated',
  '4ce00000-0000-0000-0000-000000000001',
  null,
  null,
  null,
  '4cf00000-0000-0000-0000-000000000002',
  '{}'::jsonb
);

do $$
begin
  if (
    select count(*)
    from public.stable_security_events
    where request_id = '4cf00000-0000-0000-0000-000000000002'
      and event_type = 'stable_updated'
      and horse_id is null
  ) <> 1 then
    raise exception 'Existing phase-4B event writer semantics changed';
  end if;
end;
$$;

rollback;
