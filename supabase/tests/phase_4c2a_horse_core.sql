begin;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
select
  '00000000-0000-0000-0000-000000000000',
  fixture.id::uuid,
  'authenticated',
  'authenticated',
  fixture.email,
  '',
  now(),
  '{}',
  '{"role":"owner","stable_id":"forged"}',
  now(),
  now()
from (
  values
    ('4a100000-0000-0000-0000-000000000001', 'horse-owner-a@example.invalid'),
    ('4a100000-0000-0000-0000-000000000002', 'horse-admin-a@example.invalid'),
    ('4a100000-0000-0000-0000-000000000003', 'horse-member-a@example.invalid'),
    ('4a100000-0000-0000-0000-000000000004', 'horse-viewer-a@example.invalid'),
    ('4a100000-0000-0000-0000-000000000005', 'horse-suspended-a@example.invalid'),
    ('4a100000-0000-0000-0000-000000000006', 'horse-removed-a@example.invalid'),
    ('4a100000-0000-0000-0000-000000000007', 'horse-left-a@example.invalid'),
    ('4a100000-0000-0000-0000-000000000008', 'horse-outsider@example.invalid'),
    ('4a200000-0000-0000-0000-000000000001', 'horse-owner-b@example.invalid'),
    ('4a200000-0000-0000-0000-000000000002', 'horse-member-b@example.invalid')
) as fixture(id, email);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values
  (
    '4b100000-0000-0000-0000-000000000001',
    'organization',
    'Horse Core stable A',
    'active',
    'Europe/Brussels',
    'nl',
    '4a100000-0000-0000-0000-000000000001',
    '4c100000-0000-0000-0000-000000000001'
  ),
  (
    '4b200000-0000-0000-0000-000000000001',
    'organization',
    'Horse Core control stable B',
    'active',
    'Europe/Amsterdam',
    'nl',
    '4a200000-0000-0000-0000-000000000001',
    '4c200000-0000-0000-0000-000000000001'
  );

insert into public.stable_members (
  id, stable_id, display_name, function_title, source
)
values
  ('4d100000-0000-0000-0000-000000000001', '4b100000-0000-0000-0000-000000000001', 'Horse owner A', 'Owner', 'owner_creation'),
  ('4d100000-0000-0000-0000-000000000002', '4b100000-0000-0000-0000-000000000001', 'Horse admin A', 'Admin', 'manual'),
  ('4d100000-0000-0000-0000-000000000003', '4b100000-0000-0000-0000-000000000001', 'Horse member A', 'Member', 'manual'),
  ('4d100000-0000-0000-0000-000000000004', '4b100000-0000-0000-0000-000000000001', 'Horse viewer A', 'Viewer', 'manual'),
  ('4d100000-0000-0000-0000-000000000005', '4b100000-0000-0000-0000-000000000001', 'Horse suspended A', null, 'manual'),
  ('4d100000-0000-0000-0000-000000000006', '4b100000-0000-0000-0000-000000000001', 'Horse removed A', null, 'manual'),
  ('4d100000-0000-0000-0000-000000000007', '4b100000-0000-0000-0000-000000000001', 'Horse left A', null, 'manual'),
  ('4d200000-0000-0000-0000-000000000001', '4b200000-0000-0000-0000-000000000001', 'Horse owner B', 'Owner', 'owner_creation'),
  ('4d200000-0000-0000-0000-000000000002', '4b200000-0000-0000-0000-000000000001', 'Horse member B', 'Member', 'manual');

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status,
  joined_at, ended_at, ended_reason
)
values
  ('4e100000-0000-0000-0000-000000000001', '4b100000-0000-0000-0000-000000000001', '4a100000-0000-0000-0000-000000000001', '4d100000-0000-0000-0000-000000000001', 'owner', 'active', now(), null, null),
  ('4e100000-0000-0000-0000-000000000002', '4b100000-0000-0000-0000-000000000001', '4a100000-0000-0000-0000-000000000002', '4d100000-0000-0000-0000-000000000002', 'admin', 'active', now(), null, null),
  ('4e100000-0000-0000-0000-000000000003', '4b100000-0000-0000-0000-000000000001', '4a100000-0000-0000-0000-000000000003', '4d100000-0000-0000-0000-000000000003', 'member', 'active', now(), null, null),
  ('4e100000-0000-0000-0000-000000000004', '4b100000-0000-0000-0000-000000000001', '4a100000-0000-0000-0000-000000000004', '4d100000-0000-0000-0000-000000000004', 'viewer', 'active', now(), null, null),
  ('4e100000-0000-0000-0000-000000000005', '4b100000-0000-0000-0000-000000000001', '4a100000-0000-0000-0000-000000000005', '4d100000-0000-0000-0000-000000000005', 'member', 'suspended', now(), now(), 'fixture'),
  ('4e100000-0000-0000-0000-000000000006', '4b100000-0000-0000-0000-000000000001', '4a100000-0000-0000-0000-000000000006', '4d100000-0000-0000-0000-000000000006', 'member', 'removed', now(), now(), 'fixture'),
  ('4e100000-0000-0000-0000-000000000007', '4b100000-0000-0000-0000-000000000001', '4a100000-0000-0000-0000-000000000007', '4d100000-0000-0000-0000-000000000007', 'viewer', 'left', now(), now(), 'fixture'),
  ('4e200000-0000-0000-0000-000000000001', '4b200000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000001', '4d200000-0000-0000-0000-000000000001', 'owner', 'active', now(), null, null),
  ('4e200000-0000-0000-0000-000000000002', '4b200000-0000-0000-0000-000000000001', '4a200000-0000-0000-0000-000000000002', '4d200000-0000-0000-0000-000000000002', 'member', 'active', now(), null, null);

set constraints all immediate;
set constraints all deferred;

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'stable_security_events'
      and c.conname = 'stable_security_events_horse_fk'
      and c.contype = 'f'
      and c.convalidated
  ) then
    raise exception 'Validated stable security-event Horse FK is missing';
  end if;
  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'horses'
      and c.conname = 'horses_stable_and_id_unique'
      and c.contype = 'u'
  ) then
    raise exception 'Horse same-stable unique key is missing';
  end if;
  if not (
    select relrowsecurity
    from pg_class
    where oid = 'public.horses'::regclass
  ) or not (
    select relrowsecurity
    from pg_class
    where oid = 'public.horse_access_grants'::regclass
  ) or not (
    select relrowsecurity
    from pg_class
    where oid = 'public.horse_profile_change_events'::regclass
  ) then
    raise exception 'Horse Core RLS is incomplete';
  end if;
  if has_table_privilege('authenticated', 'public.horses', 'INSERT')
    or has_table_privilege('authenticated', 'public.horses', 'UPDATE')
    or has_table_privilege('authenticated', 'public.horses', 'DELETE')
    or has_table_privilege('authenticated', 'public.horse_access_grants', 'INSERT')
    or has_table_privilege('authenticated', 'public.horse_access_grants', 'UPDATE')
    or has_table_privilege('authenticated', 'public.horse_access_grants', 'DELETE')
    or has_table_privilege('authenticated', 'public.horse_profile_change_events', 'INSERT')
    or has_table_privilege('authenticated', 'public.horse_profile_change_events', 'UPDATE')
    or has_table_privilege('authenticated', 'public.horse_profile_change_events', 'DELETE')
  then
    raise exception 'Authenticated received direct Horse Core DML';
  end if;
  if has_function_privilege(
    'authenticated',
    'private.write_horse_security_event(uuid,uuid,text,uuid,uuid,uuid,jsonb)',
    'EXECUTE'
  ) then
    raise exception 'Authenticated can execute the private Horse event writer';
  end if;
end;
$$;

-- The private writer independently enforces stable, actor and subject
-- correlation, even if a future private caller passes inconsistent rows.
select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000001', true);
do $$
declare
  failure_count integer := 0;
begin
  begin
    perform private.write_horse_security_event(
      '4b100000-0000-0000-0000-000000000001',
      '40100000-0000-0000-0000-000000000001',
      'horse_access_granted',
      '4e200000-0000-0000-0000-000000000001',
      '4e100000-0000-0000-0000-000000000003',
      '40210000-0000-0000-0000-000000000001',
      '{"category":"horse.basic"}'
    );
  exception when invalid_parameter_value then
    if sqlerrm <> 'HORSE_SECURITY_EVENT_CORRELATION_REQUIRED' then raise; end if;
    failure_count := failure_count + 1;
  end;

  perform set_config(
    'request.jwt.claim.sub',
    '4a100000-0000-0000-0000-000000000003',
    true
  );
  begin
    perform private.write_horse_security_event(
      '4b100000-0000-0000-0000-000000000001',
      '40100000-0000-0000-0000-000000000001',
      'horse_access_granted',
      '4e100000-0000-0000-0000-000000000001',
      '4e100000-0000-0000-0000-000000000003',
      '40210000-0000-0000-0000-000000000002',
      '{"category":"horse.basic"}'
    );
  exception when invalid_parameter_value then
    if sqlerrm <> 'HORSE_SECURITY_EVENT_CORRELATION_REQUIRED' then raise; end if;
    failure_count := failure_count + 1;
  end;

  perform set_config(
    'request.jwt.claim.sub',
    '4a100000-0000-0000-0000-000000000001',
    true
  );
  begin
    perform private.write_horse_security_event(
      '4b100000-0000-0000-0000-000000000001',
      '40100000-0000-0000-0000-000000000001',
      'horse_access_granted',
      '4e100000-0000-0000-0000-000000000001',
      '4e200000-0000-0000-0000-000000000002',
      '40210000-0000-0000-0000-000000000003',
      '{"category":"horse.basic"}'
    );
  exception when invalid_parameter_value then
    if sqlerrm <> 'HORSE_SECURITY_EVENT_CORRELATION_REQUIRED' then raise; end if;
    failure_count := failure_count + 1;
  end;

  if failure_count <> 3 or exists (
    select 1
    from public.stable_security_events
    where request_id in (
      '40210000-0000-0000-0000-000000000001',
      '40210000-0000-0000-0000-000000000002',
      '40210000-0000-0000-0000-000000000003'
    )
  ) then
    raise exception 'Horse security-event correlation was not fail-closed';
  end if;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);

select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000001', true);
select public.create_horse(
  '4b100000-0000-0000-0000-000000000001',
  '  Orion  ',
  '4f100000-0000-0000-0000-000000000001',
  'Orion Official',
  '2015-04-12',
  'gelding',
  'KWPN',
  'Dressage',
  'ZZ-Licht'
);
select public.create_horse(
  '4b100000-0000-0000-0000-000000000001',
  'Orion',
  '4f100000-0000-0000-0000-000000000001',
  'Orion Official',
  '2015-04-12',
  'gelding',
  'KWPN',
  'Dressage',
  'ZZ-Licht'
);
select public.create_horse(
  '4b100000-0000-0000-0000-000000000001',
  'Orion',
  '4f100000-0000-0000-0000-000000000002'
);

do $$
begin
  if (
    select count(*)
    from public.horses
    where stable_id = '4b100000-0000-0000-0000-000000000001'
      and display_name = 'Orion'
  ) <> 2 then
    raise exception 'Same-name Horses or idempotent create are incorrect';
  end if;
  if (
    select count(*)
    from public.horse_profile_change_events
    where request_id = '4f100000-0000-0000-0000-000000000001'
      and event_type = 'horse_created'
  ) <> 1 then
    raise exception 'Idempotent Horse create wrote an incorrect audit count';
  end if;
  begin
    perform public.create_horse(
      '4b100000-0000-0000-0000-000000000001',
      'Request reuse attack',
      '4f100000-0000-0000-0000-000000000001'
    );
    raise exception 'Horse create request ID was reused for another payload';
  exception when sqlstate '22023' then
    if sqlerrm <> 'REQUEST_ID_REUSED' then raise; end if;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000002', true);
select public.create_horse(
  '4b100000-0000-0000-0000-000000000001',
  'Admin Horse',
  '4f100000-0000-0000-0000-000000000003'
);

do $$
declare
  denied_actor text;
begin
  foreach denied_actor in array array[
    '4a100000-0000-0000-0000-000000000003',
    '4a100000-0000-0000-0000-000000000004',
    '4a100000-0000-0000-0000-000000000005',
    '4a100000-0000-0000-0000-000000000006',
    '4a100000-0000-0000-0000-000000000007',
    '4a100000-0000-0000-0000-000000000008'
  ] loop
    perform set_config('request.jwt.claim.sub', denied_actor, true);
    begin
      perform public.create_horse(
        '4b100000-0000-0000-0000-000000000001',
        'Blocked Horse',
        gen_random_uuid()
      );
      raise exception 'Denied actor created a Horse: %', denied_actor;
    exception when insufficient_privilege then null;
    end;
  end loop;
end;
$$;

reset role;

insert into public.horses (
  id, stable_id, display_name, source_kind,
  created_by_user_id, created_request_id
)
values
  ('40100000-0000-0000-0000-000000000001', '4b100000-0000-0000-0000-000000000001', 'Aster', 'manual', '4a100000-0000-0000-0000-000000000001', '40200000-0000-0000-0000-000000000001'),
  ('40100000-0000-0000-0000-000000000002', '4b100000-0000-0000-0000-000000000001', 'Boreal', 'manual', '4a100000-0000-0000-0000-000000000001', '40200000-0000-0000-0000-000000000002'),
  ('40100000-0000-0000-0000-000000000003', '4b100000-0000-0000-0000-000000000001', 'Celeste', 'manual', '4a100000-0000-0000-0000-000000000001', '40200000-0000-0000-0000-000000000003'),
  ('40200000-0000-0000-0000-000000000001', '4b200000-0000-0000-0000-000000000001', 'Control Horse B', 'manual', '4a200000-0000-0000-0000-000000000001', '40200000-0000-0000-0000-000000000004');

do $$
begin
  begin
    insert into public.horse_access_grants (
      stable_id, horse_id, membership_id, category,
      can_view, granted_by_user_id, granted_request_id
    )
    values (
      '4b100000-0000-0000-0000-000000000001',
      '40100000-0000-0000-0000-000000000001',
      '4e200000-0000-0000-0000-000000000002',
      'horse.basic',
      true,
      '4a100000-0000-0000-0000-000000000001',
      gen_random_uuid()
    );
    raise exception 'Cross-stable membership grant passed the composite FK';
  exception when foreign_key_violation then null;
  end;
  begin
    insert into public.stable_security_events (
      stable_id, horse_id, event_type
    )
    values (
      '4b100000-0000-0000-0000-000000000001',
      '40200000-0000-0000-0000-000000000001',
      'horse_access_granted'
    );
    raise exception 'Cross-stable security-event Horse passed the FK';
  exception when foreign_key_violation then null;
  end;
  begin
    insert into public.stable_security_events (
      stable_id, horse_id, event_type
    )
    values (
      '4b100000-0000-0000-0000-000000000001',
      '40100000-0000-0000-0000-000000000001',
      'stable_updated'
    );
    raise exception 'Phase-4B event accepted horse_id';
  exception when check_violation then null;
  end;
  begin
    insert into public.stable_security_events (
      stable_id, event_type
    )
    values (
      '4b100000-0000-0000-0000-000000000001',
      'horse_access_granted'
    );
    raise exception 'Horse access event accepted null horse_id';
  exception when check_violation then null;
  end;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000001', true);

select public.grant_horse_access(
  '40100000-0000-0000-0000-000000000001',
  '4e100000-0000-0000-0000-000000000003',
  'horse.basic',
  true, false, true, false,
  null, null, null,
  '40300000-0000-0000-0000-000000000001'
);
select public.grant_horse_access(
  '40100000-0000-0000-0000-000000000001',
  '4e100000-0000-0000-0000-000000000004',
  'horse.basic',
  true, false, false, false,
  null, null, null,
  '40300000-0000-0000-0000-000000000002'
);
select public.grant_horse_access(
  '40100000-0000-0000-0000-000000000002',
  '4e100000-0000-0000-0000-000000000002',
  'horse.nutrition',
  true, false, true, true,
  null, null, 'Owner delegated nutrition grant management',
  '40300000-0000-0000-0000-000000000003'
);

do $$
begin
  if (
    select count(*)
    from public.stable_security_events
    where request_id in (
      '40300000-0000-0000-0000-000000000001',
      '40300000-0000-0000-0000-000000000002',
      '40300000-0000-0000-0000-000000000003'
    )
      and event_type = 'horse_access_granted'
      and horse_id is not null
  ) <> 3 then
    raise exception 'Horse grants lack exact typed event correlation';
  end if;
  if exists (
    select 1
    from public.stable_security_events
    where request_id = '40300000-0000-0000-0000-000000000003'
      and (
        metadata ? 'grant_reason'
        or metadata ? 'email'
        or metadata ? 'name'
      )
  ) then
    raise exception 'Sensitive free text leaked into security-event metadata';
  end if;
end;
$$;

-- Exact duplicate grant is an event-free no-op, even when valid_from was
-- server-derived from a null input.
select public.grant_horse_access(
  '40100000-0000-0000-0000-000000000001',
  '4e100000-0000-0000-0000-000000000003',
  'horse.basic',
  true, false, true, false,
  null, null, null,
  '40300000-0000-0000-0000-000000000004'
);
do $$
begin
  if (
    select count(*)
    from public.horse_access_grants
    where horse_id = '40100000-0000-0000-0000-000000000001'
      and membership_id = '4e100000-0000-0000-0000-000000000003'
      and category = 'horse.basic'
      and status = 'active'
  ) <> 1 then
    raise exception 'Duplicate Horse grant created another active row';
  end if;
  if exists (
    select 1
    from public.stable_security_events
    where request_id = '40300000-0000-0000-0000-000000000004'
  ) then
    raise exception 'Duplicate Horse grant wrote an event';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000002', true);
select public.grant_horse_access(
  '40100000-0000-0000-0000-000000000001',
  '4e100000-0000-0000-0000-000000000004',
  'horse.schedule',
  true, false, false, false,
  null, null, null,
  '40300000-0000-0000-0000-000000000005'
);
select public.grant_horse_access(
  '40100000-0000-0000-0000-000000000002',
  '4e100000-0000-0000-0000-000000000003',
  'horse.nutrition',
  true, false, true, false,
  null, null, 'Delegated nutrition access',
  '40300000-0000-0000-0000-000000000006'
);

do $$
begin
  begin
    perform public.grant_horse_access(
      '40100000-0000-0000-0000-000000000001',
      '4e100000-0000-0000-0000-000000000002',
      'horse.basic',
      true, false, true, false,
      null, null, null,
      gen_random_uuid()
    );
    raise exception 'Admin self-granted Horse access';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.grant_horse_access(
      '40100000-0000-0000-0000-000000000001',
      '4e100000-0000-0000-0000-000000000003',
      'horse.nutrition',
      true, false, true, false,
      null, null, 'Unauthorized sensitive grant',
      gen_random_uuid()
    );
    raise exception 'Admin granted sensitive access without manage authority';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.grant_horse_access(
      '40100000-0000-0000-0000-000000000001',
      '4e100000-0000-0000-0000-000000000004',
      'horse.basic',
      true, false, true, false,
      null, null, null,
      gen_random_uuid()
    );
    raise exception 'Viewer received edit capability';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.grant_horse_access(
      '40100000-0000-0000-0000-000000000001',
      '4e100000-0000-0000-0000-000000000005',
      'horse.basic',
      true, false, false, false,
      null, null, null,
      gen_random_uuid()
    );
    raise exception 'Suspended target membership received a grant';
  exception when insufficient_privilege then
    if sqlerrm <> 'TARGET_MEMBERSHIP_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.grant_horse_access(
      '40100000-0000-0000-0000-000000000001',
      '4e100000-0000-0000-0000-000000000006',
      'horse.basic',
      true, false, false, false,
      null, null, null,
      gen_random_uuid()
    );
    raise exception 'Removed target membership received a grant';
  exception when insufficient_privilege then
    if sqlerrm <> 'TARGET_MEMBERSHIP_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.grant_horse_access(
      '40100000-0000-0000-0000-000000000001',
      '4e100000-0000-0000-0000-000000000007',
      'horse.basic',
      true, false, false, false,
      null, null, null,
      gen_random_uuid()
    );
    raise exception 'Left target membership received a grant';
  exception when insufficient_privilege then
    if sqlerrm <> 'TARGET_MEMBERSHIP_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.grant_horse_access(
      '40100000-0000-0000-0000-000000000001',
      '4e200000-0000-0000-0000-000000000002',
      'horse.basic',
      true, false, false, false,
      null, null, null,
      gen_random_uuid()
    );
    raise exception 'Cross-stable target membership received a grant';
  exception when insufficient_privilege then
    if sqlerrm <> 'TARGET_MEMBERSHIP_UNAVAILABLE' then raise; end if;
  end;
end;
$$;

-- An elapsed time window is normalized to expired while holding the same
-- Horse/grant locks, so it cannot block a fresh grant or remain authoritative.
reset role;
insert into public.horse_access_grants (
  stable_id,
  horse_id,
  membership_id,
  category,
  can_view,
  valid_from,
  valid_until,
  granted_by_user_id,
  granted_request_id
)
values (
  '4b100000-0000-0000-0000-000000000001',
  '40100000-0000-0000-0000-000000000002',
  '4e100000-0000-0000-0000-000000000002',
  'horse.basic',
  true,
  now() - interval '2 days',
  now() - interval '1 day',
  '4a100000-0000-0000-0000-000000000001',
  '40300000-0000-0000-0000-000000000007'
);

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000001', true);
select public.grant_horse_access(
  '40100000-0000-0000-0000-000000000002',
  '4e100000-0000-0000-0000-000000000002',
  'horse.basic',
  true, false, false, false,
  null, null, null,
  '40300000-0000-0000-0000-000000000008'
);
do $$
begin
  if (
    select count(*)
    from public.horse_access_grants
    where horse_id = '40100000-0000-0000-0000-000000000002'
      and membership_id = '4e100000-0000-0000-0000-000000000002'
      and category = 'horse.basic'
      and status = 'expired'
  ) <> 1 or (
    select count(*)
    from public.horse_access_grants
    where horse_id = '40100000-0000-0000-0000-000000000002'
      and membership_id = '4e100000-0000-0000-0000-000000000002'
      and category = 'horse.basic'
      and status = 'active'
  ) <> 1 then
    raise exception 'Expired Horse grant blocked or replaced the fresh grant';
  end if;
end;
$$;

-- Member with explicit edit can update exactly the authorized Horse.
select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000003', true);
do $$
begin
  if (select count(*) from public.horses) <> 1
    or (select count(*) from public.horse_access_grants) <> 0
  then
    raise exception 'Member Horse/grant RLS mismatch before update';
  end if;
end;
$$;
select public.update_horse_profile(
  '40100000-0000-0000-0000-000000000001',
  1,
  '40400000-0000-0000-0000-000000000001',
  'Aster Updated',
  null,
  null,
  'unknown',
  null,
  'Eventing',
  null
);
do $$
begin
  begin
    perform public.update_horse_profile(
      '40100000-0000-0000-0000-000000000002',
      1,
      gen_random_uuid(),
      'Unauthorized',
      null, null, 'unknown', null, null, null
    );
    raise exception 'Member updated an ungranted Horse';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.update_horse_profile(
      '40100000-0000-0000-0000-000000000001',
      1,
      gen_random_uuid(),
      'Lost update',
      null, null, 'unknown', null, null, null
    );
    raise exception 'Stale Horse row version was accepted';
  exception when serialization_failure then
    if sqlerrm <> 'ROW_VERSION_CONFLICT' then raise; end if;
  end;
end;
$$;

-- Viewer can read its granted Horse but can never update it.
select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000004', true);
do $$
begin
  if (select count(*) from public.horses) <> 1 then
    raise exception 'Viewer Horse RLS does not match its explicit grant';
  end if;
  if (select count(*) from public.horse_access_grants) <> 0 then
    raise exception 'Viewer read Horse grants';
  end if;
  begin
    perform public.update_horse_profile(
      '40100000-0000-0000-0000-000000000001',
      2,
      gen_random_uuid(),
      'Viewer attack',
      null, null, 'unknown', null, null, null
    );
    raise exception 'Viewer updated a Horse';
  exception when insufficient_privilege then null;
  end;
end;
$$;

-- Inactive and unaffiliated accounts lose all Horse data immediately.
do $$
declare
  denied_actor text;
begin
  foreach denied_actor in array array[
    '4a100000-0000-0000-0000-000000000005',
    '4a100000-0000-0000-0000-000000000006',
    '4a100000-0000-0000-0000-000000000007',
    '4a100000-0000-0000-0000-000000000008'
  ] loop
    perform set_config('request.jwt.claim.sub', denied_actor, true);
    if (select count(*) from public.horses) <> 0
      or (select count(*) from public.horse_access_grants) <> 0
      or (select count(*) from public.horse_profile_change_events) <> 0
    then
      raise exception 'Inactive/outsider retained Horse access: %', denied_actor;
    end if;
  end loop;
end;
$$;

-- Other-stable IDs and unknown IDs have the same safe public error.
select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000003', true);
do $$
declare
  observed text[] := '{}'::text[];
begin
  begin
    perform public.update_horse_profile(
      '40200000-0000-0000-0000-000000000001',
      1,
      gen_random_uuid(),
      'Oracle attack',
      null, null, 'unknown', null, null, null
    );
  exception when insufficient_privilege then
    observed := array_append(observed, sqlerrm);
  end;
  begin
    perform public.update_horse_profile(
      '40999999-0000-0000-0000-000000000999',
      1,
      gen_random_uuid(),
      'Oracle attack',
      null, null, 'unknown', null, null, null
    );
  exception when insufficient_privilege then
    observed := array_append(observed, sqlerrm);
  end;
  if observed <> array['HORSE_UNAVAILABLE', 'HORSE_UNAVAILABLE']::text[] then
    raise exception 'Horse ID oracle leaked different outcomes: %', observed;
  end if;
end;
$$;

-- An active same-stable member cannot distinguish an existing grant from an
-- absent one through revoke's return value or error behavior.
select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000003', true);
do $$
declare
  observed text[] := '{}'::text[];
begin
  begin
    perform public.revoke_horse_access(
      '40100000-0000-0000-0000-000000000001',
      '4e100000-0000-0000-0000-000000000003',
      'horse.basic',
      '40510000-0000-0000-0000-000000000001'
    );
  exception when insufficient_privilege then
    observed := array_append(observed, sqlerrm);
  end;
  begin
    perform public.revoke_horse_access(
      '40100000-0000-0000-0000-000000000001',
      '4e100000-0000-0000-0000-000000000003',
      'horse.health_detail',
      '40510000-0000-0000-0000-000000000002'
    );
  exception when insufficient_privilege then
    observed := array_append(observed, sqlerrm);
  end;
  if observed <> array['NOT_AUTHORIZED', 'NOT_AUTHORIZED']::text[] then
    raise exception 'Unauthorized revoke leaked grant state: %', observed;
  end if;
end;
$$;

reset role;
do $$
begin
  if exists (
    select 1
    from public.stable_security_events
    where request_id in (
      '40510000-0000-0000-0000-000000000001',
      '40510000-0000-0000-0000-000000000002'
    )
  ) or not exists (
    select 1
    from public.horse_access_grants
    where horse_id = '40100000-0000-0000-0000-000000000001'
      and membership_id = '4e100000-0000-0000-0000-000000000003'
      and category = 'horse.basic'
      and status = 'active'
  ) then
    raise exception 'Unauthorized revoke mutated grant or event state';
  end if;
end;
$$;

-- Owner revocation is atomic and duplicate-safe.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000001', true);
select public.revoke_horse_access(
  '40100000-0000-0000-0000-000000000001',
  '4e100000-0000-0000-0000-000000000003',
  'horse.basic',
  '40500000-0000-0000-0000-000000000001'
);
select public.revoke_horse_access(
  '40100000-0000-0000-0000-000000000001',
  '4e100000-0000-0000-0000-000000000003',
  'horse.basic',
  '40500000-0000-0000-0000-000000000001'
);
select public.revoke_horse_access(
  '40100000-0000-0000-0000-000000000001',
  '4e100000-0000-0000-0000-000000000003',
  'horse.basic',
  '40500000-0000-0000-0000-000000000002'
);
do $$
begin
  if (
    select count(*)
    from public.stable_security_events
    where request_id = '40500000-0000-0000-0000-000000000001'
      and event_type = 'horse_access_revoked'
      and horse_id = '40100000-0000-0000-0000-000000000001'
      and subject_membership_id = '4e100000-0000-0000-0000-000000000003'
  ) <> 1 then
    raise exception 'Duplicate revoke event correlation is incorrect';
  end if;
  if exists (
    select 1
    from public.stable_security_events
    where request_id = '40500000-0000-0000-0000-000000000002'
  ) then
    raise exception 'No-op revoke wrote an event';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000003', true);
do $$
begin
  if exists (
    select 1 from public.horses
    where id = '40100000-0000-0000-0000-000000000001'
  ) then
    raise exception 'Revoked member retained Horse access';
  end if;
end;
$$;

-- Archive is owner/admin-only, soft, audited, and event-free on duplicate.
select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000002', true);
select public.archive_horse(
  '40100000-0000-0000-0000-000000000003',
  '40600000-0000-0000-0000-000000000001',
  'Retired from active roster'
);
select public.archive_horse(
  '40100000-0000-0000-0000-000000000003',
  '40600000-0000-0000-0000-000000000002',
  'Duplicate archive'
);

reset role;
do $$
begin
  if not exists (
    select 1
    from public.horses
    where id = '40100000-0000-0000-0000-000000000003'
      and status = 'archived'
      and archived_at is not null
      and row_version = 2
  ) then
    raise exception 'Horse archive lifecycle is incorrect';
  end if;
  if (
    select count(*)
    from public.horse_profile_change_events
    where horse_id = '40100000-0000-0000-0000-000000000003'
      and event_type = 'horse_archived'
  ) <> 1 then
    raise exception 'Duplicate archive wrote an incorrect audit count';
  end if;
end;
$$;

-- Force the private writer to fail and prove grant/revoke + event rollback.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000001', true);
select public.grant_horse_access(
  '40100000-0000-0000-0000-000000000002',
  '4e100000-0000-0000-0000-000000000004',
  'horse.schedule',
  true, false, false, false,
  null, null, null,
  '40700000-0000-0000-0000-000000000002'
);

reset role;
create function pg_temp.reject_horse_security_event()
returns trigger
language plpgsql
as $$
begin
  if new.request_id in (
    '40700000-0000-0000-0000-000000000001'::uuid,
    '40700000-0000-0000-0000-000000000003'::uuid
  ) then
    raise exception using errcode = 'P0001', message = 'FORCED_EVENT_FAILURE';
  end if;
  return new;
end;
$$;

create trigger reject_horse_security_event
before insert on public.stable_security_events
for each row execute function pg_temp.reject_horse_security_event();

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000001', true);
do $$
begin
  begin
    perform public.grant_horse_access(
      '40100000-0000-0000-0000-000000000002',
      '4e100000-0000-0000-0000-000000000004',
      'horse.basic',
      true, false, false, false,
      null, null, null,
      '40700000-0000-0000-0000-000000000001'
    );
    raise exception 'Forced event failure did not abort the grant';
  exception when raise_exception then
    if sqlerrm <> 'FORCED_EVENT_FAILURE' then raise; end if;
  end;
end;
$$;

do $$
begin
  begin
    perform public.revoke_horse_access(
      '40100000-0000-0000-0000-000000000002',
      '4e100000-0000-0000-0000-000000000004',
      'horse.schedule',
      '40700000-0000-0000-0000-000000000003'
    );
    raise exception 'Forced event failure did not abort the revoke';
  exception when raise_exception then
    if sqlerrm <> 'FORCED_EVENT_FAILURE' then raise; end if;
  end;
end;
$$;

reset role;
drop trigger reject_horse_security_event on public.stable_security_events;
do $$
begin
  if exists (
    select 1
    from public.horse_access_grants
    where horse_id = '40100000-0000-0000-0000-000000000002'
      and membership_id = '4e100000-0000-0000-0000-000000000004'
      and category = 'horse.basic'
  ) or exists (
    select 1
    from public.stable_security_events
    where request_id = '40700000-0000-0000-0000-000000000001'
  ) or not exists (
    select 1
    from public.horse_access_grants
    where horse_id = '40100000-0000-0000-0000-000000000002'
      and membership_id = '4e100000-0000-0000-0000-000000000004'
      and category = 'horse.schedule'
      and status = 'active'
  ) or exists (
    select 1
    from public.stable_security_events
    where request_id = '40700000-0000-0000-0000-000000000003'
  ) then
    raise exception 'Failed event writer left a grant, revoke or event behind';
  end if;
end;
$$;

-- Full direct-DML denial for authenticated and anonymous clients.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '4a100000-0000-0000-0000-000000000001', true);
do $$
declare
  relation_name text;
  operation_name text;
begin
  foreach relation_name in array array[
    'horses',
    'horse_access_grants',
    'horse_profile_change_events'
  ] loop
    foreach operation_name in array array['insert', 'update', 'delete'] loop
      begin
        if operation_name = 'insert' then
          execute format('insert into public.%I default values', relation_name);
        elsif operation_name = 'update' then
          execute format('update public.%I set %I = %I',
            relation_name,
            case relation_name
              when 'horses' then 'display_name'
              when 'horse_access_grants' then 'status'
              else 'reason'
            end,
            case relation_name
              when 'horses' then 'display_name'
              when 'horse_access_grants' then 'status'
              else 'reason'
            end
          );
        else
          execute format('delete from public.%I', relation_name);
        end if;
        raise exception 'Authenticated direct % on % succeeded',
          operation_name, relation_name;
      exception when insufficient_privilege then null;
      end;
    end loop;
  end loop;
end;
$$;

reset role;
set local role anon;
select set_config('request.jwt.claim.role', 'anon', true);
select set_config('request.jwt.claim.sub', '', true);
do $$
declare
  relation_name text;
begin
  foreach relation_name in array array[
    'horses',
    'horse_access_grants',
    'horse_profile_change_events'
  ] loop
    begin
      execute format('select count(*) from public.%I', relation_name);
      raise exception 'Anonymous read %', relation_name;
    exception when insufficient_privilege then null;
    end;
    begin
      execute format('insert into public.%I default values', relation_name);
      raise exception 'Anonymous inserted into %', relation_name;
    exception when insufficient_privilege then null;
    end;
  end loop;
  begin
    perform public.create_horse(
      '4b100000-0000-0000-0000-000000000001',
      'Anonymous Horse',
      gen_random_uuid()
    );
    raise exception 'Anonymous executed create_horse';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
do $$
begin
  if (
    select count(*)
    from public.horses
    where stable_id = '4b200000-0000-0000-0000-000000000001'
  ) <> 1
    or exists (
      select 1
      from public.horse_access_grants
      where stable_id = '4b200000-0000-0000-0000-000000000001'
    )
    or exists (
      select 1
      from public.stable_security_events
      where stable_id = '4b200000-0000-0000-0000-000000000001'
    )
  then
    raise exception 'Control stable B changed during Horse Core tests';
  end if;
end;
$$;

rollback;
