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
  '{}',
  now(),
  now()
from (
  values
    ('4c610000-0000-0000-0000-000000000001', 'sync-owner-a@example.invalid'),
    ('4c610000-0000-0000-0000-000000000002', 'sync-assignee-a@example.invalid'),
    ('4c610000-0000-0000-0000-000000000003', 'sync-outsider-a@example.invalid'),
    ('4c610000-0000-0000-0000-000000000004', 'sync-owner-b@example.invalid')
) fixture(id, email);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values
  (
    '4c620000-0000-0000-0000-000000000001',
    'organization', 'Sync stable A', 'active', 'Europe/Amsterdam', 'nl',
    '4c610000-0000-0000-0000-000000000001',
    '4c620000-0000-0000-0000-000000000011'
  ),
  (
    '4c620000-0000-0000-0000-000000000002',
    'organization', 'Sync stable B', 'active', 'Europe/Brussels', 'nl',
    '4c610000-0000-0000-0000-000000000004',
    '4c620000-0000-0000-0000-000000000012'
  );

insert into public.stable_members (
  id, stable_id, display_name, source
)
values
  ('4c630000-0000-0000-0000-000000000001', '4c620000-0000-0000-0000-000000000001', 'Sync Owner A', 'owner_creation'),
  ('4c630000-0000-0000-0000-000000000002', '4c620000-0000-0000-0000-000000000001', 'Sync Assignee A', 'manual'),
  ('4c630000-0000-0000-0000-000000000003', '4c620000-0000-0000-0000-000000000002', 'Sync Owner B', 'owner_creation');

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values
  ('4c640000-0000-0000-0000-000000000001', '4c620000-0000-0000-0000-000000000001', '4c610000-0000-0000-0000-000000000001', '4c630000-0000-0000-0000-000000000001', 'owner', 'active', now()),
  ('4c640000-0000-0000-0000-000000000002', '4c620000-0000-0000-0000-000000000001', '4c610000-0000-0000-0000-000000000002', '4c630000-0000-0000-0000-000000000002', 'viewer', 'active', now()),
  ('4c640000-0000-0000-0000-000000000003', '4c620000-0000-0000-0000-000000000002', '4c610000-0000-0000-0000-000000000004', '4c630000-0000-0000-0000-000000000003', 'owner', 'active', now());

insert into public.horses (
  id, stable_id, display_name, source_kind,
  created_by_user_id, created_request_id
)
values
  ('4c650000-0000-0000-0000-000000000001', '4c620000-0000-0000-0000-000000000001', 'Assigned Horse A', 'manual', '4c610000-0000-0000-0000-000000000001', '4c650000-0000-0000-0000-000000000011'),
  ('4c650000-0000-0000-0000-000000000002', '4c620000-0000-0000-0000-000000000001', 'Private Horse A', 'manual', '4c610000-0000-0000-0000-000000000001', '4c650000-0000-0000-0000-000000000012'),
  ('4c650000-0000-0000-0000-000000000003', '4c620000-0000-0000-0000-000000000002', 'Control Horse B', 'manual', '4c610000-0000-0000-0000-000000000004', '4c650000-0000-0000-0000-000000000013');

insert into public.schedule_items (
  id, stable_id, horse_id, item_kind, data_category, title, instruction,
  priority, scheduled_start_at, source_timezone, source_local_date,
  source_local_time, state, created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values
  (
    '4c660000-0000-0000-0000-000000000001',
    '4c620000-0000-0000-0000-000000000001',
    '4c650000-0000-0000-0000-000000000001',
    'task', 'horse.schedule', 'Assigned offline task',
    'Only this necessary instruction may enter the encrypted dayset.',
    'normal', '2026-07-28 07:00:00+00', 'Europe/Amsterdam',
    '2026-07-28', '09:00', 'planned',
    '4c610000-0000-0000-0000-000000000001',
    '4c660000-0000-0000-0000-000000000011',
    '4c610000-0000-0000-0000-000000000001',
    '4c660000-0000-0000-0000-000000000011'
  ),
  (
    '4c660000-0000-0000-0000-000000000002',
    '4c620000-0000-0000-0000-000000000001',
    '4c650000-0000-0000-0000-000000000002',
    'task', 'horse.schedule', 'Private task',
    'This instruction must never enter the assignee dayset.',
    'normal', '2026-07-28 08:00:00+00', 'Europe/Amsterdam',
    '2026-07-28', '10:00', 'planned',
    '4c610000-0000-0000-0000-000000000001',
    '4c660000-0000-0000-0000-000000000012',
    '4c610000-0000-0000-0000-000000000001',
    '4c660000-0000-0000-0000-000000000012'
  ),
  (
    '4c660000-0000-0000-0000-000000000003',
    '4c620000-0000-0000-0000-000000000001',
    null,
    'task', 'horse.schedule', 'Assigned stable-wide task',
    'Stable-wide work must remain available without a Horse mapping.',
    'normal', '2026-07-28 09:00:00+00', 'Europe/Amsterdam',
    '2026-07-28', '11:00', 'planned',
    '4c610000-0000-0000-0000-000000000001',
    '4c660000-0000-0000-0000-000000000013',
    '4c610000-0000-0000-0000-000000000001',
    '4c660000-0000-0000-0000-000000000013'
  );

insert into public.schedule_assignments (
  id, stable_id, schedule_item_id, stable_member_id, assignment_role,
  status, created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values
  (
    '4c670000-0000-0000-0000-000000000001',
    '4c620000-0000-0000-0000-000000000001',
    '4c660000-0000-0000-0000-000000000001',
    '4c630000-0000-0000-0000-000000000002',
    'responsible', 'assigned',
    '4c610000-0000-0000-0000-000000000001',
    '4c670000-0000-0000-0000-000000000011',
    '4c610000-0000-0000-0000-000000000001',
    '4c670000-0000-0000-0000-000000000011'
  ),
  (
    '4c670000-0000-0000-0000-000000000002',
    '4c620000-0000-0000-0000-000000000001',
    '4c660000-0000-0000-0000-000000000003',
    '4c630000-0000-0000-0000-000000000002',
    'support', 'assigned',
    '4c610000-0000-0000-0000-000000000001',
    '4c670000-0000-0000-0000-000000000012',
    '4c610000-0000-0000-0000-000000000001',
    '4c670000-0000-0000-0000-000000000012'
  );

insert into public.schedule_change_events (
  stable_id, schedule_item_id, schedule_assignment_id,
  actor_user_id, actor_membership_id, request_id,
  event_type, data_category, row_version
)
values
  (
    '4c620000-0000-0000-0000-000000000001',
    '4c660000-0000-0000-0000-000000000001',
    '4c670000-0000-0000-0000-000000000001',
    '4c610000-0000-0000-0000-000000000001',
    '4c640000-0000-0000-0000-000000000001',
    '4c680000-0000-0000-0000-000000000001',
    'schedule_assignment_created', 'horse.schedule', 1
  ),
  (
    '4c620000-0000-0000-0000-000000000001',
    '4c660000-0000-0000-0000-000000000002',
    null,
    '4c610000-0000-0000-0000-000000000001',
    '4c640000-0000-0000-0000-000000000001',
    '4c680000-0000-0000-0000-000000000002',
    'schedule_item_created', 'horse.schedule', 1
  );

do $$
declare
  relation_name text;
begin
  foreach relation_name in array array[
    'stable_sync_authorities',
    'client_sync_devices',
    'stable_change_events',
    'sync_conflicts',
    'legacy_import_jobs',
    'legacy_import_items'
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
      raise exception '4C.6 RLS/direct DML incorrect for %', relation_name;
    end if;
  end loop;
  if has_table_privilege(
    'authenticated', 'public.stable_change_events', 'SELECT'
  ) or has_table_privilege(
    'authenticated', 'private.realtime_channel_topics', 'SELECT'
  ) or has_table_privilege(
    'authenticated', 'private.client_mutation_receipts', 'SELECT'
  ) or has_table_privilege(
    'authenticated', 'private.legacy_feeding_plan_snapshots', 'SELECT'
  ) or has_table_privilege(
    'authenticated',
    'private.legacy_schedule_execution_history',
    'SELECT'
  ) then
    raise exception '4C.6 internal sync metadata exposed directly';
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname = 'realtime'
      and tablename = 'messages'
      and policyname = 'realtime_messages_private_read'
      and cmd = 'SELECT'
  ) then
    raise exception '4C.6 private Realtime policy missing';
  end if;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000002',
  true
);
do $$
begin
  begin
    insert into realtime.messages (
      topic, extension, payload, event, private
    )
    values (
      gen_random_uuid()::text,
      'broadcast',
      '{"forged":true}'::jsonb,
      'change_available',
      true
    );
    raise exception 'authenticated client wrote directly to Realtime';
  exception when sqlstate '42501' then
    null;
  end;
end;
$$;
reset role;

create temp table phase_4c6_results (
  name text primary key,
  value jsonb not null
) on commit drop;
grant select, insert, update on phase_4c6_results to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000002',
  true
);

insert into phase_4c6_results
values (
  'assignee_topics',
  public.get_realtime_topics(
    '4c620000-0000-0000-0000-000000000001'
  )
);

do $$
declare
  topics jsonb;
  authority_version bigint;
  changes jsonb;
begin
  select value into topics from phase_4c6_results
  where name = 'assignee_topics';
  authority_version := (topics->>'authority_version')::bigint;
  if jsonb_array_length(topics->'topics') <> 1
    or topics->'topics'->0->>'scope' <> 'membership'
  then
    raise exception 'assigned-only user received broad realtime topics';
  end if;
  changes := public.pull_operation_changes(
    '4c620000-0000-0000-0000-000000000001',
    0,
    500,
    authority_version
  );
  if jsonb_array_length(changes->'changes') <> 1
    or changes->'changes'->0->>'entity_id'
      <> '4c670000-0000-0000-0000-000000000001'
    or (changes->>'next_cursor')::bigint
      <= (changes->'changes'->0->>'sequence_id')::bigint
  then
    raise exception 'permission-filtered cursor catch-up incorrect';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000003',
  true
);
do $$
begin
  begin
    perform public.get_realtime_topics(
      '4c620000-0000-0000-0000-000000000001'
    );
    raise exception 'account without membership received realtime topics';
  exception when sqlstate '42501' then
    if sqlerrm <> 'SYNC_UNAVAILABLE' then raise; end if;
  end;
end;
$$;
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000002',
  true
);

insert into phase_4c6_results
values (
  'device',
  public.register_sync_device(
    '4c620000-0000-0000-0000-000000000001',
    '4c690000-0000-0000-0000-000000000001',
    $key$-----BEGIN PGP PUBLIC KEY BLOCK-----

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
=5hAt
-----END PGP PUBLIC KEY BLOCK-----$key$,
    '4c690000-0000-0000-0000-000000000011'
  )
);

do $$
begin
  begin
    perform public.register_sync_device(
      '4c620000-0000-0000-0000-000000000001',
      '4c690000-0000-0000-0000-000000000002',
      $key$-----BEGIN PGP PUBLIC KEY BLOCK-----
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
-----END PGP PUBLIC KEY BLOCK-----$key$,
      '4c690000-0000-0000-0000-000000000011'
    );
    raise exception 'request ID reuse for another device was accepted';
  exception when sqlstate '22023' then
    if sqlerrm <> 'REQUEST_ID_REUSED' then raise; end if;
  end;
end;
$$;

do $$
declare
  authority_version bigint;
begin
  select (value->>'authority_version')::bigint into authority_version
  from phase_4c6_results where name = 'device';
  begin
    perform public.sync_schedule_execution(
      '4c620000-0000-0000-0000-000000000001',
      '4c690000-0000-0000-0000-000000000001',
      authority_version,
      '4c660000-0000-0000-0000-000000000001',
      '4c690000-0000-0000-0000-000000000011',
      'problem',
      '2026-07-28 06:58:00+00',
      '2026-07-28 07:03:00+00',
      '2026-07-28 09:03:00',
      'Europe/Amsterdam',
      null
    );
    raise exception 'cross-operation request ID reuse was accepted';
  exception when sqlstate '22023' then
    if sqlerrm <> 'REQUEST_ID_REUSED' then raise; end if;
  end;
end;
$$;

do $$
declare
  device_result jsonb;
  dayset jsonb;
  authority_version bigint;
  execution jsonb;
  retry jsonb;
  counter integer;
begin
  select value into device_result from phase_4c6_results
  where name = 'device';
  authority_version := (device_result->>'authority_version')::bigint;
  if private.schedule_item_access_level(
    '4c660000-0000-0000-0000-000000000001'
  ) <> 'assigned'
    or private.schedule_item_access_level(
      '4c660000-0000-0000-0000-000000000003'
    ) <> 'assigned'
    or private.schedule_item_access_level(
      '4c660000-0000-0000-0000-000000000002'
    ) <> 'none'
  then
    raise exception
      'assigned Horse or stable-wide dayset access classification failed';
  end if;
  dayset := public.get_encrypted_offline_dayset(
    '4c620000-0000-0000-0000-000000000001',
    '4c690000-0000-0000-0000-000000000001',
    '2026-07-28',
    'Europe/Amsterdam',
    authority_version
  );
  if dayset->>'format' <> 'openpgp-aes256'
    or dayset->>'cache_directive' <> 'store_ciphertext_only'
    or length(dayset->>'ciphertext') < 200
    or dayset::text like '%Assigned offline task%'
    or dayset::text like '%Private task%'
  then
    raise exception 'encrypted assigned dayset contract failed';
  end if;
  execution := public.sync_schedule_execution(
    '4c620000-0000-0000-0000-000000000001',
    '4c690000-0000-0000-0000-000000000001',
    authority_version,
    '4c660000-0000-0000-0000-000000000001',
    '4c690000-0000-0000-0000-000000000021',
    'problem',
    '2026-07-28 06:58:00+00',
    '2026-07-28 07:03:00+00',
    '2026-07-28 09:03:00',
    'Europe/Amsterdam',
    null
  );
  for counter in 1..99 loop
    retry := public.sync_schedule_execution(
      '4c620000-0000-0000-0000-000000000001',
      '4c690000-0000-0000-0000-000000000001',
      authority_version,
      '4c660000-0000-0000-0000-000000000001',
      '4c690000-0000-0000-0000-000000000021',
      'problem',
      '2026-07-28 06:58:00+00',
      '2026-07-28 07:03:00+00',
      '2026-07-28 09:03:00',
      'Europe/Amsterdam',
      null
    );
    if retry->>'execution_id' <> execution->>'execution_id'
      or (retry->>'idempotent')::boolean is not true
    then
      raise exception '100-retry exactly-once proof failed';
    end if;
  end loop;
  retry := public.sync_schedule_execution(
    '4c620000-0000-0000-0000-000000000001',
    '4c690000-0000-0000-0000-000000000001',
    authority_version,
    '4c660000-0000-0000-0000-000000000001',
    '4c690000-0000-0000-0000-000000000022',
    'completed',
    '2026-07-28 07:04:00+00',
    '2026-07-28 07:08:00+00',
    '2026-07-28 09:08:00',
    'Europe/Amsterdam',
    null
  );
  if retry->>'execution_id' = execution->>'execution_id'
    or (retry->>'idempotent')::boolean is true
    or (
      select count(*) from public.schedule_executions
      where actor_user_id = '4c610000-0000-0000-0000-000000000002'
        and request_id in (
          '4c690000-0000-0000-0000-000000000021',
          '4c690000-0000-0000-0000-000000000022'
        )
    ) <> 2
  then
    raise exception 'different request IDs were incorrectly merged';
  end if;
  if (
    select count(*) from public.schedule_executions
    where actor_user_id = '4c610000-0000-0000-0000-000000000002'
      and request_id = '4c690000-0000-0000-0000-000000000021'
  ) <> 1 or (
    select recorded_timezone from public.schedule_executions
    where actor_user_id = '4c610000-0000-0000-0000-000000000002'
      and request_id = '4c690000-0000-0000-0000-000000000021'
  ) <> 'Europe/Amsterdam' then
    raise exception 'offline execution duplicated or timezone lost';
  end if;
end;
$$;

reset role;

savepoint phase_4c6_archived_horse;
update public.horses
set
  status = 'archived',
  archived_at = timezone('utc', now())
where id = '4c650000-0000-0000-0000-000000000001';

do $$
begin
  if (
    select count(*)
    from public.schedule_assignments assignment
    join public.schedule_items item
      on item.id = assignment.schedule_item_id
     and item.stable_id = assignment.stable_id
    join public.horses horse
      on horse.id = item.horse_id
     and horse.stable_id = item.stable_id
     and horse.status = 'active'
    where assignment.stable_id =
      '4c620000-0000-0000-0000-000000000001'
      and assignment.stable_member_id =
        '4c630000-0000-0000-0000-000000000002'
      and assignment.status in ('assigned', 'accepted')
      and item.horse_id is not null
  ) <> 0 or (
    select status
    from public.client_sync_devices
    where id = '4c690000-0000-0000-0000-000000000001'
  ) <> 'revoked' then
    raise exception
      'archived Horse remained eligible for offline cache';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000002',
  true
);
do $$
declare
  old_authority_version bigint;
begin
  select (value->>'authority_version')::bigint
    into old_authority_version
  from phase_4c6_results where name = 'device';
  begin
    perform public.get_encrypted_offline_dayset(
      '4c620000-0000-0000-0000-000000000001',
      '4c690000-0000-0000-0000-000000000001',
      '2026-07-28',
      'Europe/Amsterdam',
      old_authority_version
    );
    raise exception 'archived Horse did not invalidate offline cache';
  exception when sqlstate '42501' then
    if sqlerrm <> 'SYNC_RESET_REQUIRED' then raise; end if;
  end;
end;
$$;
reset role;
rollback to savepoint phase_4c6_archived_horse;

do $$
declare
  message_payload jsonb;
begin
  select payload into message_payload
  from realtime.messages
  where extension = 'broadcast'
  order by inserted_at desc
  limit 1;
  if message_payload is null
    or message_payload ? 'entity_id'
    or message_payload ? 'horse_id'
    or message_payload ? 'stable_id'
    or message_payload ? 'note'
    or message_payload ? 'token'
    or message_payload ? 'signed_url'
    or not (message_payload ? 'cursor')
  then
    raise exception 'Realtime payload is not identifier-free';
  end if;
end;
$$;

update public.horse_access_grants
set status = status
where false;

insert into public.horse_access_grants (
  stable_id, horse_id, membership_id, category,
  can_view, can_execute, can_edit, can_manage,
  granted_by_user_id, granted_request_id
)
values (
  '4c620000-0000-0000-0000-000000000001',
  '4c650000-0000-0000-0000-000000000001',
  '4c640000-0000-0000-0000-000000000002',
  'horse.schedule', true, true, false, false,
  '4c610000-0000-0000-0000-000000000001',
  '4c690000-0000-0000-0000-000000000031'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000002',
  true
);

do $$
declare
  stale_version bigint;
begin
  select (value->>'authority_version')::bigint into stale_version
  from phase_4c6_results where name = 'device';
  begin
    perform public.pull_operation_changes(
      '4c620000-0000-0000-0000-000000000001',
      0, 10, stale_version
    );
    raise exception 'stale authority cursor unexpectedly accepted';
  exception when sqlstate '42501' then
    if sqlerrm <> 'SYNC_RESET_REQUIRED' then raise; end if;
  end;
  begin
    perform public.get_encrypted_offline_dayset(
      '4c620000-0000-0000-0000-000000000001',
      '4c690000-0000-0000-0000-000000000001',
      '2026-07-28', 'Europe/Amsterdam', stale_version
    );
    raise exception 'revoked cache device unexpectedly accepted';
  exception when sqlstate '42501' then
    if sqlerrm <> 'SYNC_RESET_REQUIRED' then raise; end if;
  end;
end;
$$;

reset role;

do $$
declare
  old_topic text;
begin
  select value->'topics'->0->>'topic' into old_topic
  from phase_4c6_results where name = 'assignee_topics';
  perform set_config('request.jwt.claim.sub', '4c610000-0000-0000-0000-000000000002', true);
  if private.can_join_realtime_topic(old_topic) then
    raise exception 'rotated realtime topic remained authorized';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000004',
  true
);
do $$
begin
  begin
    perform public.pull_operation_changes(
      '4c620000-0000-0000-0000-000000000001',
      0,
      10,
      1
    );
    raise exception 'cross-stable owner received sync rows';
  exception when sqlstate '42501' then
    if sqlerrm <> 'SYNC_UNAVAILABLE' then raise; end if;
  end;
end;
$$;
reset role;

update public.stable_memberships
set
  status = 'suspended',
  ended_at = timezone('utc', now()),
  ended_reason = '4C.6 revoke regression'
where id = '4c640000-0000-0000-0000-000000000002';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000002',
  true
);
do $$
begin
  begin
    perform public.get_realtime_topics(
      '4c620000-0000-0000-0000-000000000001'
    );
    raise exception 'suspended member received realtime topics';
  exception when sqlstate '42501' then
    if sqlerrm <> 'SYNC_UNAVAILABLE' then raise; end if;
  end;
end;
$$;
reset role;

do $$
begin
  begin
    insert into public.sync_conflicts (
      id, actor_user_id, stable_id, entity_type, entity_id,
      base_row_version, server_row_version, client_patch
    )
    values (
      '4c6b0000-0000-0000-0000-000000000099',
      '4c610000-0000-0000-0000-000000000001',
      '4c620000-0000-0000-0000-000000000001',
      'horse_basic_noncritical',
      '4c650000-0000-0000-0000-000000000002',
      1,
      2,
      '{"role":"owner"}'::jsonb
    );
    raise exception 'non-allowlisted conflict field was accepted';
  exception when check_violation then
    null;
  end;
end;
$$;

insert into public.sync_conflicts (
  id, actor_user_id, stable_id, entity_type, entity_id,
  base_row_version, server_row_version, client_patch
)
values (
  '4c6b0000-0000-0000-0000-000000000001',
  '4c610000-0000-0000-0000-000000000001',
  '4c620000-0000-0000-0000-000000000001',
  'horse_basic_noncritical',
  '4c650000-0000-0000-0000-000000000002',
  1,
  2,
  '{"display_name":"Client-visible conflict"}'::jsonb
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000001',
  true
);

do $$
declare
  resolved jsonb;
  replayed jsonb;
begin
  if not exists (
    select 1
    from jsonb_array_elements(
      public.get_realtime_topics(
        '4c620000-0000-0000-0000-000000000001'
      )->'topics'
    ) topic
    where topic->>'scope' = 'stable'
  ) then
    raise exception 'owner stable-level Realtime wake-up topic missing';
  end if;
  if jsonb_array_length(
    public.list_sync_conflicts(
      '4c620000-0000-0000-0000-000000000001'
    )
  ) <> 1 then
    raise exception 'base-version conflict was not visible to its actor';
  end if;
  resolved := public.resolve_sync_conflict(
    '4c6b0000-0000-0000-0000-000000000001',
    'resolved_server',
    'Server version retained after explicit review.',
    '4c6b0000-0000-0000-0000-000000000011'
  );
  replayed := public.resolve_sync_conflict(
    '4c6b0000-0000-0000-0000-000000000001',
    'resolved_server',
    'Server version retained after explicit review.',
    '4c6b0000-0000-0000-0000-000000000011'
  );
  if resolved->>'status' <> 'resolved_server'
    or (replayed->>'idempotent')::boolean is not true
  then
    raise exception 'visible conflict resolution/retry failed';
  end if;
end;
$$;

reset role;

create temp table phase_4c6_legacy_source (
  source_inventory jsonb not null,
  items jsonb not null,
  manifest_hash bytea not null,
  bad_items jsonb,
  bad_manifest_hash bytea
) on commit drop;
grant select on phase_4c6_legacy_source to authenticated;

with source_payloads(
  entity_type,
  legacy_local_id,
  source_classification,
  selected,
  payload
) as (
  values
    (
      'horse',
      '1',
      'unmodified_seed',
      false,
      jsonb_build_object('display_name', 'Prototype seed')
    ),
    (
      'horse',
      '42',
      'user',
      false,
      jsonb_build_object(
        'display_name', 'Legacy User Horse',
        'sex', 'gelding'
      )
    ),
    (
      'horse',
      '43',
      'modified_seed',
      true,
      jsonb_build_object(
        'display_name', 'Explicit Modified Seed',
        'sex', 'unknown'
      )
    ),
    (
      'stable_member',
      'worker-9',
      'user',
      false,
      jsonb_build_object(
        'target_stable_member_id',
        '4c630000-0000-0000-0000-000000000001'
      )
    ),
    (
      'schedule_item',
      'activity-7',
      'user',
      false,
      jsonb_build_object(
        'horse_legacy_local_id', '42',
        'item_kind', 'task',
        'data_category', 'horse.schedule',
        'title', 'Legacy task',
        'instruction', 'Imported after explicit mapping.',
        'priority', 'normal',
        'scheduled_start_at', '2026-07-29T07:00:00Z',
        'scheduled_end_at', '',
        'source_timezone', 'Europe/Amsterdam',
        'source_local_date', '2026-07-29',
        'source_local_time', '09:00:00'
      )
    ),
    (
      'feeding_plan',
      'feeding-plan-3',
      'user',
      false,
      jsonb_build_object(
        'horse_legacy_local_id', '42',
        'plan_type', 'standard',
        'name', 'Legacy feeding plan',
        'effective_from', '2026-07-01',
        'effective_until', '',
        'plan_data', jsonb_build_object(
          'rounds',
          jsonb_build_array(
            jsonb_build_object(
              'round_code', 'morning',
              'product_name', 'Hay',
              'quantity', 2.5,
              'unit_code', 'kg'
            )
          )
        )
      )
    ),
    (
      'schedule_execution',
      'execution-8',
      'user',
      false,
      jsonb_build_object(
        'schedule_item_legacy_local_id', 'activity-7',
        'actor_stable_member_legacy_local_id', 'worker-9',
        'execution_status', 'completed',
        'actual_started_at', '2026-07-29T07:01:00Z',
        'actual_completed_at', '2026-07-29T07:10:00Z',
        'recorded_local_at', '2026-07-29T09:10:00',
        'recorded_timezone', 'Europe/Amsterdam',
        'note', 'Historical local completion.'
      )
    )
),
source_items as (
  select jsonb_agg(
    jsonb_build_object(
      'entity_type', entity_type,
      'legacy_local_id', legacy_local_id,
      'source_classification', source_classification,
      'selected', selected,
      'source_hash',
        encode(private.sync_payload_hash(payload), 'hex'),
      'payload', payload
    )
    order by entity_type, legacy_local_id
  ) as items
  from source_payloads
),
source_manifest as (
  select
    jsonb_build_object(
      'horses', 3,
      'stable_members', 1,
      'schedule_items', 1,
      'feeding_plans', 1,
      'schedule_executions', 1
    ) as source_inventory,
    items
  from source_items
)
insert into phase_4c6_legacy_source
select
  source_inventory,
  items,
  private.legacy_source_manifest_hash(source_inventory, items)
from source_manifest;

update phase_4c6_legacy_source
set bad_items = jsonb_set(
  items,
  '{0,source_hash}',
  to_jsonb(repeat('ff', 32))
);
update phase_4c6_legacy_source
set bad_manifest_hash = private.legacy_source_manifest_hash(
  source_inventory,
  bad_items
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000001',
  true
);

do $$
begin
  begin
    perform public.create_legacy_import_job(
      '4c620000-0000-0000-0000-000000000001',
      decode(repeat('11', 32), 'hex'),
      '4.0.0',
      2,
      1,
      (select source_inventory from phase_4c6_legacy_source),
      decode(repeat('00', 32), 'hex'),
      (select items from phase_4c6_legacy_source),
      '4c6a0000-0000-0000-0000-000000000009'
    );
    raise exception 'forged source manifest was accepted';
  exception when sqlstate '22023' then
    if sqlerrm <> 'SOURCE_MANIFEST_MISMATCH' then raise; end if;
  end;
  begin
    perform public.create_legacy_import_job(
      '4c620000-0000-0000-0000-000000000001',
      decode(repeat('11', 32), 'hex'),
      '4.0.0',
      2,
      1,
      (select source_inventory from phase_4c6_legacy_source),
      (select bad_manifest_hash from phase_4c6_legacy_source),
      (select bad_items from phase_4c6_legacy_source),
      '4c6a0000-0000-0000-0000-000000000010'
    );
    raise exception 'forged source item hash was accepted';
  exception when sqlstate '22023' then
    if sqlerrm <> 'SOURCE_HASH_MISMATCH' then raise; end if;
  end;
end;
$$;

insert into phase_4c6_results
values (
  'legacy_job',
  public.create_legacy_import_job(
    '4c620000-0000-0000-0000-000000000001',
    decode(repeat('11', 32), 'hex'),
    '4.0.0',
    2,
    1,
    (select source_inventory from phase_4c6_legacy_source),
    (select manifest_hash from phase_4c6_legacy_source),
    (select items from phase_4c6_legacy_source),
    '4c6a0000-0000-0000-0000-000000000001'
  )
);

do $$
declare
  target_job_id uuid;
  validated jsonb;
  batch_one jsonb;
  retry jsonb;
  batch_two jsonb;
begin
  select (value->>'job_id')::uuid into target_job_id
  from phase_4c6_results where name = 'legacy_job';
  validated := public.validate_legacy_import_job(
    target_job_id, 1, '4c6a0000-0000-0000-0000-000000000002'
  );
  if (validated->>'selected_count')::integer <> 6
    or (validated->>'excluded_seed_count')::integer <> 1
    or (validated->>'conflict_count')::integer <> 0
  then
    raise exception 'legacy preview classification incorrect';
  end if;
  batch_one := public.execute_legacy_import_batch(
    target_job_id,
    (validated->>'row_version')::bigint,
    3,
    '4c6a0000-0000-0000-0000-000000000003'
  );
  retry := public.execute_legacy_import_batch(
    target_job_id,
    (validated->>'row_version')::bigint,
    3,
    '4c6a0000-0000-0000-0000-000000000003'
  );
  if batch_one->>'job_id' <> retry->>'job_id'
    or (retry->>'idempotent')::boolean is not true
    or jsonb_array_length(batch_one->'mappings') <> 3
    or retry->'mappings' <> batch_one->'mappings'
  then
    raise exception
      'legacy batch retry mismatch: batch=%, retry=%',
      batch_one,
      retry;
  end if;
  if (
    select count(*) from public.horses
    where stable_id = '4c620000-0000-0000-0000-000000000001'
      and legacy_local_horse_id in (42, 43)
  ) <> 2 then
    raise exception 'legacy horse batch did not map both selected horses';
  end if;
  batch_two := public.execute_legacy_import_batch(
    target_job_id,
    (batch_one->>'row_version')::bigint,
    3,
    '4c6a0000-0000-0000-0000-000000000004'
  );
  if (batch_two->>'remaining_count')::integer <> 0
    or jsonb_array_length(batch_two->'mappings') <> 3
    or jsonb_array_length(
      public.get_legacy_import_job(target_job_id)->'mappings'
    ) <> 6
    or (
      select count(*) from public.schedule_items
      where stable_id = '4c620000-0000-0000-0000-000000000001'
        and title = 'Legacy task'
    ) <> 1
    or (
      select count(*) from jsonb_array_elements(
        public.get_legacy_import_job(target_job_id)->'mappings'
      ) mapping
      where mapping->>'entity_type' = 'feeding_plan'
    ) <> 1
    or (
      select count(*) from jsonb_array_elements(
        public.get_legacy_import_job(target_job_id)->'mappings'
      ) mapping
      where mapping->>'entity_type' = 'schedule_execution'
    ) <> 1
  then
    raise exception 'legacy dependency import failed';
  end if;
end;
$$;

reset role;

do $$
declare
  target_job_id uuid;
  job_version bigint;
  mapping_hash bytea;
begin
  select (value->>'job_id')::uuid into target_job_id
  from phase_4c6_results where name = 'legacy_job';
  select row_version into job_version
  from public.legacy_import_jobs where id = target_job_id;
  select private.sync_payload_hash(
    jsonb_agg(
      jsonb_build_object(
        'entity_type', entity_type,
        'legacy_local_id', legacy_local_id,
        'cloud_id', cloud_id,
        'source_hash', encode(source_hash, 'hex'),
        'cloud_hash', encode(cloud_hash, 'hex')
      )
      order by entity_type, legacy_local_id
    ) filter (where status = 'imported')
  ) into mapping_hash
  from public.legacy_import_items
  where legacy_import_items.job_id = target_job_id;
  insert into phase_4c6_results values (
    'legacy_verify_input',
    jsonb_build_object(
      'job_id', target_job_id,
      'row_version', job_version,
      'mapping_hash', encode(mapping_hash, 'hex')
    )
  );
end;
$$;

savepoint phase_4c6_mapping_tamper;
update private.legacy_feeding_plan_snapshots
set payload = jsonb_set(payload, '{name}', '"Tampered plan"'::jsonb)
where job_id = (
  select (value->>'job_id')::uuid
  from phase_4c6_results where name = 'legacy_job'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000001',
  true
);
do $$
declare
  input jsonb;
begin
  select value into input from phase_4c6_results
  where name = 'legacy_verify_input';
  begin
    perform public.verify_legacy_import_job(
      (input->>'job_id')::uuid,
      (input->>'row_version')::bigint,
      decode(input->>'mapping_hash', 'hex'),
      '4c6a0000-0000-0000-0000-000000000008'
    );
    raise exception 'tampered cloud import mapping was certified';
  exception when sqlstate '55000' then
    if sqlerrm <> 'IMPORT_VERIFICATION_FAILED' then raise; end if;
  end;
end;
$$;
reset role;
rollback to savepoint phase_4c6_mapping_tamper;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000001',
  true
);

do $$
declare
  input jsonb;
  verified jsonb;
begin
  select value into input from phase_4c6_results
  where name = 'legacy_verify_input';
  verified := public.verify_legacy_import_job(
    (input->>'job_id')::uuid,
    (input->>'row_version')::bigint,
    decode(input->>'mapping_hash', 'hex'),
    '4c6a0000-0000-0000-0000-000000000005'
  );
  insert into phase_4c6_results values ('legacy_verified', verified);
end;
$$;

reset role;
savepoint phase_4c6_post_verify_tamper;
update public.horses
set display_name = 'Tampered after verify'
where legacy_local_horse_id = 42
  and stable_id = '4c620000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000001',
  true
);
do $$
declare
  input jsonb;
  verified jsonb;
begin
  select value into input from phase_4c6_results
  where name = 'legacy_verify_input';
  select value into verified from phase_4c6_results
  where name = 'legacy_verified';
  begin
    perform public.cutover_legacy_import_job(
      (input->>'job_id')::uuid,
      (verified->>'row_version')::bigint,
      decode(repeat('11', 32), 'hex'),
      true,
      '4c6a0000-0000-0000-0000-000000000099'
    );
    raise exception 'post-verify mapping tamper reached cutover';
  exception when sqlstate '55000' then
    if sqlerrm <> 'CUTOVER_NOT_READY' then raise; end if;
  end;
end;
$$;
reset role;
rollback to savepoint phase_4c6_post_verify_tamper;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '4c610000-0000-0000-0000-000000000001',
  true
);
do $$
declare
  input jsonb;
  verified jsonb;
  cutover jsonb;
  rolled_back jsonb;
begin
  select value into input from phase_4c6_results
  where name = 'legacy_verify_input';
  select value into verified from phase_4c6_results
  where name = 'legacy_verified';
  begin
    perform public.cutover_legacy_import_job(
      (input->>'job_id')::uuid,
      (verified->>'row_version')::bigint,
      decode(repeat('11', 32), 'hex'),
      false,
      '4c6a0000-0000-0000-0000-000000000006'
    );
    raise exception 'cutover without retained backup accepted';
  exception when sqlstate '22023' then
    if sqlerrm <> 'BACKUP_REQUIRED' then raise; end if;
  end;
  cutover := public.cutover_legacy_import_job(
    (input->>'job_id')::uuid,
    (verified->>'row_version')::bigint,
    decode(repeat('11', 32), 'hex'),
    true,
    '4c6a0000-0000-0000-0000-000000000007'
  );
  rolled_back := public.rollback_legacy_import_job(
    (input->>'job_id')::uuid,
    (cutover->>'row_version')::bigint,
    true,
    'User explicitly returned to retained local backup.',
    '4c6a0000-0000-0000-0000-000000000008'
  );
  if rolled_back->>'status' <> 'rolled_back'
    or (rolled_back->>'cloud_history_retained')::boolean is not true
  then
    raise exception 'legacy rollback marker incorrect';
  end if;
end;
$$;

reset role;

do $$
declare
  target_job_id uuid;
begin
  select (value->>'job_id')::uuid into target_job_id
  from phase_4c6_results where name = 'legacy_job';
  if (
    select count(*) from public.horses
    where stable_id = '4c620000-0000-0000-0000-000000000001'
      and legacy_local_horse_id in (42, 43)
  ) <> 2 or not exists (
    select 1 from public.legacy_import_jobs
    where id = target_job_id
      and status = 'rolled_back'
      and rolled_back_at is not null
      and mapping_manifest_hash is not null
  ) or exists (
    select 1 from public.legacy_import_items
    where legacy_import_items.job_id = target_job_id
      and source_classification = 'unmodified_seed'
      and cloud_id is not null
  ) then
    raise exception 'legacy audit/history or seed exclusion failed';
  end if;
end;
$$;

rollback;
