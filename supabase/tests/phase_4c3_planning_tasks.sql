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
    ('4c310000-0000-0000-0000-000000000001', 'schedule-owner-a@example.invalid'),
    ('4c310000-0000-0000-0000-000000000002', 'schedule-admin-a@example.invalid'),
    ('4c310000-0000-0000-0000-000000000003', 'schedule-member-a@example.invalid'),
    ('4c310000-0000-0000-0000-000000000004', 'schedule-assignee-a@example.invalid'),
    ('4c310000-0000-0000-0000-000000000005', 'schedule-viewer-a@example.invalid'),
    ('4c310000-0000-0000-0000-000000000006', 'schedule-suspended-a@example.invalid'),
    ('4c310000-0000-0000-0000-000000000007', 'schedule-owner-b@example.invalid')
) as fixture(id, email);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values
  (
    '4c320000-0000-0000-0000-000000000001',
    'organization',
    'Schedule stable A',
    'active',
    'Europe/Amsterdam',
    'nl',
    '4c310000-0000-0000-0000-000000000001',
    '4c320000-0000-0000-0000-000000000011'
  ),
  (
    '4c320000-0000-0000-0000-000000000002',
    'organization',
    'Schedule control stable B',
    'active',
    'Europe/Brussels',
    'nl',
    '4c310000-0000-0000-0000-000000000007',
    '4c320000-0000-0000-0000-000000000012'
  );

insert into public.stable_members (
  id, stable_id, display_name, status, source
)
values
  ('4c330000-0000-0000-0000-000000000001', '4c320000-0000-0000-0000-000000000001', 'Owner A', 'active', 'owner_creation'),
  ('4c330000-0000-0000-0000-000000000002', '4c320000-0000-0000-0000-000000000001', 'Admin A', 'active', 'manual'),
  ('4c330000-0000-0000-0000-000000000003', '4c320000-0000-0000-0000-000000000001', 'Member A', 'active', 'manual'),
  ('4c330000-0000-0000-0000-000000000004', '4c320000-0000-0000-0000-000000000001', 'Assigned viewer A', 'active', 'manual'),
  ('4c330000-0000-0000-0000-000000000005', '4c320000-0000-0000-0000-000000000001', 'Unassigned viewer A', 'active', 'manual'),
  ('4c330000-0000-0000-0000-000000000006', '4c320000-0000-0000-0000-000000000001', 'Unlinked roster A', 'active', 'manual'),
  ('4c330000-0000-0000-0000-000000000007', '4c320000-0000-0000-0000-000000000001', 'Suspended A', 'active', 'manual'),
  ('4c330000-0000-0000-0000-000000000008', '4c320000-0000-0000-0000-000000000002', 'Owner B', 'active', 'owner_creation');

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status,
  joined_at, ended_at, ended_reason
)
values
  ('4c340000-0000-0000-0000-000000000001', '4c320000-0000-0000-0000-000000000001', '4c310000-0000-0000-0000-000000000001', '4c330000-0000-0000-0000-000000000001', 'owner', 'active', now(), null, null),
  ('4c340000-0000-0000-0000-000000000002', '4c320000-0000-0000-0000-000000000001', '4c310000-0000-0000-0000-000000000002', '4c330000-0000-0000-0000-000000000002', 'admin', 'active', now(), null, null),
  ('4c340000-0000-0000-0000-000000000003', '4c320000-0000-0000-0000-000000000001', '4c310000-0000-0000-0000-000000000003', '4c330000-0000-0000-0000-000000000003', 'member', 'active', now(), null, null),
  ('4c340000-0000-0000-0000-000000000004', '4c320000-0000-0000-0000-000000000001', '4c310000-0000-0000-0000-000000000004', '4c330000-0000-0000-0000-000000000004', 'viewer', 'active', now(), null, null),
  ('4c340000-0000-0000-0000-000000000005', '4c320000-0000-0000-0000-000000000001', '4c310000-0000-0000-0000-000000000005', '4c330000-0000-0000-0000-000000000005', 'viewer', 'active', now(), null, null),
  ('4c340000-0000-0000-0000-000000000006', '4c320000-0000-0000-0000-000000000001', '4c310000-0000-0000-0000-000000000006', '4c330000-0000-0000-0000-000000000007', 'member', 'suspended', now(), now(), 'fixture'),
  ('4c340000-0000-0000-0000-000000000007', '4c320000-0000-0000-0000-000000000002', '4c310000-0000-0000-0000-000000000007', '4c330000-0000-0000-0000-000000000008', 'owner', 'active', now(), null, null);

set constraints all immediate;

insert into public.horses (
  id, stable_id, display_name, source_kind,
  created_by_user_id, created_request_id
)
values
  ('4c350000-0000-0000-0000-000000000001', '4c320000-0000-0000-0000-000000000001', 'Schedule Horse A', 'manual', '4c310000-0000-0000-0000-000000000001', '4c350000-0000-0000-0000-000000000011'),
  ('4c350000-0000-0000-0000-000000000002', '4c320000-0000-0000-0000-000000000001', 'Private Horse A', 'manual', '4c310000-0000-0000-0000-000000000001', '4c350000-0000-0000-0000-000000000012'),
  ('4c350000-0000-0000-0000-000000000003', '4c320000-0000-0000-0000-000000000002', 'Control Horse B', 'manual', '4c310000-0000-0000-0000-000000000007', '4c350000-0000-0000-0000-000000000013');

insert into public.horse_access_grants (
  stable_id, horse_id, membership_id, category,
  can_view, can_execute, can_edit,
  granted_by_user_id, granted_request_id
)
values (
  '4c320000-0000-0000-0000-000000000001',
  '4c350000-0000-0000-0000-000000000001',
  '4c340000-0000-0000-0000-000000000003',
  'horse.schedule',
  true,
  true,
  true,
  '4c310000-0000-0000-0000-000000000001',
  '4c360000-0000-0000-0000-000000000001'
);

-- Since C-009.1, canonical horse access is never inherited from stable
-- membership or the legacy horse_access_grants bridge. Preserve the intent of
-- this Planning regression fixture with explicit canonical permissions: the
-- member and assignee receive explicit view + edit capabilities, while the
-- unassigned viewer below
-- intentionally receives no grant.
insert into public.horse_profile_permission_grants (
  horse_id,
  grantee_profile_id,
  permission_id,
  grantor_profile_id,
  reason_code,
  creation_correlation_id
)
select
  fixture.horse_id,
  grantee.id,
  permission.id,
  grantor.id,
  'MANUAL_GRANT',
  fixture.creation_correlation_id
from (
  values
    (
      '4c350000-0000-0000-0000-000000000001'::uuid,
      '4c310000-0000-0000-0000-000000000003'::uuid,
      'horse.edit'::text,
      '4c360000-0000-0000-0000-000000000011'::uuid
    ),
    (
      '4c350000-0000-0000-0000-000000000001'::uuid,
      '4c310000-0000-0000-0000-000000000003'::uuid,
      'horse.view'::text,
      '4c360000-0000-0000-0000-000000000013'::uuid
    ),
    (
      '4c350000-0000-0000-0000-000000000001'::uuid,
      '4c310000-0000-0000-0000-000000000004'::uuid,
      'horse.edit'::text,
      '4c360000-0000-0000-0000-000000000012'::uuid
    ),
    (
      '4c350000-0000-0000-0000-000000000001'::uuid,
      '4c310000-0000-0000-0000-000000000004'::uuid,
      'horse.view'::text,
      '4c360000-0000-0000-0000-000000000014'::uuid
    )
) as fixture(
  horse_id,
  grantee_profile_id,
  permission_code,
  creation_correlation_id
)
join public.permission_definitions permission
  on permission.code = fixture.permission_code
join public.profiles grantee
  on grantee.auth_user_id = fixture.grantee_profile_id
join public.profiles grantor
  on grantor.auth_user_id = '4c310000-0000-0000-0000-000000000001'::uuid;

insert into public.schedule_series (
  id, stable_id, horse_id, series_kind, data_category, title, instruction,
  timezone, frequency, interval_value, weekdays, local_start_time,
  duration_minutes, starts_on, ends_on, status, generation_horizon_days,
  created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c3e0000-0000-0000-0000-000000000001',
  '4c320000-0000-0000-0000-000000000002',
  '4c350000-0000-0000-0000-000000000003',
  'task', 'horse.schedule', 'Control series B', 'Oracle control only.',
  'Europe/Brussels', 'daily', 1, null, '08:00', null,
  '2026-07-28', null, 'active', 30,
  '4c310000-0000-0000-0000-000000000007',
  '4c3e0000-0000-0000-0000-000000000011',
  '4c310000-0000-0000-0000-000000000007',
  '4c3e0000-0000-0000-0000-000000000011'
);

insert into public.schedule_items (
  id, stable_id, horse_id, item_kind, data_category, title, instruction,
  priority, scheduled_start_at, source_timezone, source_local_date,
  source_local_time, state, created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values
  (
    '4c3e0000-0000-0000-0000-000000000002',
    '4c320000-0000-0000-0000-000000000002',
    '4c350000-0000-0000-0000-000000000003',
    'task', 'horse.schedule', 'Control item B', 'Oracle control only.',
    'normal', '2026-07-28 06:00:00+00', 'Europe/Brussels',
    '2026-07-28', '08:00', 'in_progress',
    '4c310000-0000-0000-0000-000000000007',
    '4c3e0000-0000-0000-0000-000000000012',
    '4c310000-0000-0000-0000-000000000007',
    '4c3e0000-0000-0000-0000-000000000012'
  ),
  (
    '4c3e0000-0000-0000-0000-000000000005',
    '4c320000-0000-0000-0000-000000000001',
    '4c350000-0000-0000-0000-000000000001',
    'task', 'horse.schedule', 'Suspended proof item',
    'Must remain hidden after authority loss.',
    'normal', '2026-07-28 07:00:00+00', 'Europe/Amsterdam',
    '2026-07-28', '09:00', 'in_progress',
    '4c310000-0000-0000-0000-000000000001',
    '4c3e0000-0000-0000-0000-000000000015',
    '4c310000-0000-0000-0000-000000000001',
    '4c3e0000-0000-0000-0000-000000000015'
  );

insert into public.schedule_assignments (
  id, stable_id, schedule_item_id, stable_member_id, assignment_role,
  status, created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c3e0000-0000-0000-0000-000000000003',
  '4c320000-0000-0000-0000-000000000002',
  '4c3e0000-0000-0000-0000-000000000002',
  '4c330000-0000-0000-0000-000000000008',
  'responsible', 'assigned',
  '4c310000-0000-0000-0000-000000000007',
  '4c3e0000-0000-0000-0000-000000000013',
  '4c310000-0000-0000-0000-000000000007',
  '4c3e0000-0000-0000-0000-000000000013'
);

insert into public.schedule_executions (
  id, stable_id, schedule_item_id, actor_user_id, actor_membership_id,
  actor_stable_member_id, execution_status, actual_completed_at,
  recorded_local_at, recorded_timezone, source, request_id, note
)
values
  (
    '4c3e0000-0000-0000-0000-000000000004',
    '4c320000-0000-0000-0000-000000000002',
    '4c3e0000-0000-0000-0000-000000000002',
    '4c310000-0000-0000-0000-000000000007',
    '4c340000-0000-0000-0000-000000000007',
    '4c330000-0000-0000-0000-000000000008',
    'partial', '2026-07-28 06:05:00+00',
    '2026-07-28 08:05:00', 'Europe/Brussels', 'online',
    '4c3e0000-0000-0000-0000-000000000014',
    'Control execution B'
  ),
  (
    '4c3e0000-0000-0000-0000-000000000006',
    '4c320000-0000-0000-0000-000000000001',
    '4c3e0000-0000-0000-0000-000000000005',
    '4c310000-0000-0000-0000-000000000006',
    '4c340000-0000-0000-0000-000000000006',
    '4c330000-0000-0000-0000-000000000007',
    'partial', '2026-07-28 07:05:00+00',
    '2026-07-28 09:05:00', 'Europe/Amsterdam', 'online',
    '4c3e0000-0000-0000-0000-000000000016',
    'SENSITIVE-PROOF-NOTE'
  );

do $$
declare
  relation_name text;
begin
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
    )
    then
      raise exception '4C.3 RLS/direct-DML incorrect for %', relation_name;
    end if;
  end loop;
  if has_table_privilege(
    'authenticated',
    'private.schedule_mutation_receipts',
    'SELECT'
  ) or has_table_privilege(
    'authenticated',
    'private.schedule_mutation_receipts',
    'INSERT'
  )
  then
    raise exception '4C.3 private receipt ACL is too broad';
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
  )
  then
    raise exception '4C.3 audit identity sequence ACL is too broad';
  end if;
end;
$$;

do $$
begin
  begin
    insert into public.schedule_items (
      stable_id, horse_id, item_kind, data_category, title, instruction,
      priority, scheduled_start_at, source_timezone, source_local_date,
      source_local_time, state, created_by_user_id, created_request_id,
      last_mutated_by_user_id, last_mutation_request_id
    )
    values (
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000003',
      'task', 'horse.schedule', 'Cross stable', 'Must fail', 'normal',
      '2026-07-28 08:00:00+00', 'UTC', '2026-07-28', '08:00', 'planned',
      '4c310000-0000-0000-0000-000000000001', gen_random_uuid(),
      '4c310000-0000-0000-0000-000000000001', gen_random_uuid()
    );
    raise exception 'Cross-stable schedule item passed the Horse FK';
  exception when foreign_key_violation then null;
  end;
  begin
    insert into public.schedule_items (
      stable_id, horse_id, item_kind, data_category, title, instruction,
      priority, scheduled_start_at, source_timezone, source_local_date,
      source_local_time, state, created_by_user_id, created_request_id,
      last_mutated_by_user_id, last_mutation_request_id
    )
    values (
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000001',
      'task', 'horse.schedule', 'Critical disabled', 'Must fail', 'critical',
      '2026-07-28 08:00:00+00', 'UTC', '2026-07-28', '08:00', 'planned',
      '4c310000-0000-0000-0000-000000000001', gen_random_uuid(),
      '4c310000-0000-0000-0000-000000000001', gen_random_uuid()
    );
    raise exception 'Critical task bypassed the feature gate';
  exception when check_violation then null;
  end;
end;
$$;

create temp table phase_4c3_ids (
  name text primary key,
  id uuid not null
) on commit drop;
grant select, insert, update on phase_4c3_ids to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000001',
  true
);

insert into phase_4c3_ids
select
  'one_off',
  (
    public.create_schedule_item(
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000001',
      'task',
      'horse.schedule',
      '  Morning check  ',
      '  Check water and movement.  ',
      'high',
      '2026-07-28 06:00:00+00',
      '2026-07-28 06:30:00+00',
      'Europe/Amsterdam',
      '2026-07-28',
      '08:00',
      '4c370000-0000-0000-0000-000000000001'
    )->>'schedule_item_id'
  )::uuid;

do $$
declare
  replayed jsonb;
begin
  replayed := public.create_schedule_item(
    '4c320000-0000-0000-0000-000000000001',
    '4c350000-0000-0000-0000-000000000001',
    'task',
    'horse.schedule',
    'Morning check',
    'Check water and movement.',
    'high',
    '2026-07-28 06:00:00+00',
    '2026-07-28 06:30:00+00',
    'Europe/Amsterdam',
    '2026-07-28',
    '08:00',
    '4c370000-0000-0000-0000-000000000001'
  );
  if (replayed->>'schedule_item_id')::uuid
      <> (select id from phase_4c3_ids where name = 'one_off')
    or (replayed->>'idempotent')::boolean is not true
    or (
      select count(*)
      from public.schedule_items
      where created_request_id
        = '4c370000-0000-0000-0000-000000000001'
    ) <> 1
  then
    raise exception 'Schedule create idempotency failed';
  end if;
  begin
    perform public.create_schedule_item(
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000001',
      'task',
      'horse.schedule',
      'Changed payload',
      'Check water and movement.',
      'high',
      '2026-07-28 06:00:00+00',
      '2026-07-28 06:30:00+00',
      'Europe/Amsterdam',
      '2026-07-28',
      '08:00',
      '4c370000-0000-0000-0000-000000000001'
    );
    raise exception 'Schedule request ID was reused with another payload';
  exception when invalid_parameter_value then
    if sqlerrm <> 'REQUEST_ID_REUSED' then raise; end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000003',
  true
);
insert into phase_4c3_ids
select
  'member_item',
  (
    public.create_schedule_item(
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000001',
      'care',
      'horse.schedule',
      'Member planned check',
      'Walk the horse for ten minutes.',
      'normal',
      '2026-07-28 07:00:00+00',
      '2026-07-28 07:15:00+00',
      'Europe/Amsterdam',
      '2026-07-28',
      '09:00',
      '4c370000-0000-0000-0000-000000000002'
    )->>'schedule_item_id'
  )::uuid;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000005',
  true
);
do $$
begin
  begin
    perform public.create_schedule_item(
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000001',
      'task',
      'horse.schedule',
      'Viewer cannot plan',
      'Must fail.',
      'normal',
      '2026-07-28 08:00:00+00',
      null,
      'Europe/Amsterdam',
      '2026-07-28',
      '10:00',
      gen_random_uuid()
    );
    raise exception 'Viewer planned a schedule item';
  exception when insufficient_privilege then
    if sqlerrm <> 'NOT_AUTHORIZED' then raise; end if;
  end;
  begin
    perform public.create_schedule_item(
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000003',
      'task',
      'horse.schedule',
      'Cross stable',
      'Must fail.',
      'normal',
      '2026-07-28 08:00:00+00',
      null,
      'Europe/Amsterdam',
      '2026-07-28',
      '10:00',
      gen_random_uuid()
    );
    raise exception 'Cross-stable Horse was an oracle';
  exception when insufficient_privilege then
    if sqlerrm <> 'SCHEDULE_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.create_schedule_item(
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000099',
      'task',
      'horse.schedule',
      'Unknown Horse',
      'Must fail.',
      'normal',
      '2026-07-28 08:00:00+00',
      null,
      'Europe/Amsterdam',
      '2026-07-28',
      '10:00',
      gen_random_uuid()
    );
    raise exception 'Unknown Horse was an oracle';
  exception when insufficient_privilege then
    if sqlerrm <> 'SCHEDULE_UNAVAILABLE' then raise; end if;
  end;
end;
$$;

do $$
begin
  begin
    perform public.return_schedule_assignment(
      '4c3f0000-0000-0000-0000-000000000001',
      1,
      gen_random_uuid()
    );
    raise exception 'Unknown assignment exposed an object oracle';
  exception when insufficient_privilege then
    if sqlerrm <> 'SCHEDULE_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.return_schedule_assignment(
      '4c3e0000-0000-0000-0000-000000000003',
      1,
      gen_random_uuid()
    );
    raise exception 'Cross-stable assignment exposed an object oracle';
  exception when insufficient_privilege then
    if sqlerrm <> 'SCHEDULE_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.correct_schedule_execution(
      '4c3f0000-0000-0000-0000-000000000002',
      gen_random_uuid(),
      'completed',
      null,
      '2026-07-28 06:10:00+00',
      '2026-07-28 08:10:00',
      'Europe/Amsterdam',
      'online',
      null,
      null
    );
    raise exception 'Unknown execution exposed an object oracle';
  exception when insufficient_privilege then
    if sqlerrm <> 'SCHEDULE_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.correct_schedule_execution(
      '4c3e0000-0000-0000-0000-000000000004',
      gen_random_uuid(),
      'completed',
      null,
      '2026-07-28 06:10:00+00',
      '2026-07-28 08:10:00',
      'Europe/Brussels',
      'online',
      null,
      null
    );
    raise exception 'Cross-stable execution exposed an object oracle';
  exception when insufficient_privilege then
    if sqlerrm <> 'SCHEDULE_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.materialize_schedule_occurrences(
      '4c3f0000-0000-0000-0000-000000000003',
      '2026-07-30',
      gen_random_uuid()
    );
    raise exception 'Unknown series materialization exposed an object oracle';
  exception when insufficient_privilege then
    if sqlerrm <> 'SCHEDULE_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.materialize_schedule_occurrences(
      '4c3e0000-0000-0000-0000-000000000001',
      '2026-07-30',
      gen_random_uuid()
    );
    raise exception 'Cross-stable series materialization exposed an oracle';
  exception when insufficient_privilege then
    if sqlerrm <> 'SCHEDULE_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.update_schedule_series_scope(
      '4c3f0000-0000-0000-0000-000000000004',
      1,
      'full',
      null,
      null,
      gen_random_uuid(),
      'Unknown series',
      'Must remain unavailable.',
      'Europe/Amsterdam',
      'daily',
      1,
      null,
      '08:00',
      null,
      '2026-07-28',
      30,
      'active'
    );
    raise exception 'Unknown series update exposed an object oracle';
  exception when insufficient_privilege then
    if sqlerrm <> 'SCHEDULE_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.update_schedule_series_scope(
      '4c3e0000-0000-0000-0000-000000000001',
      1,
      'full',
      null,
      null,
      gen_random_uuid(),
      'Cross-stable series',
      'Must remain unavailable.',
      'Europe/Brussels',
      'daily',
      1,
      null,
      '08:00',
      null,
      '2026-07-28',
      30,
      'active'
    );
    raise exception 'Cross-stable series update exposed an object oracle';
  exception when insufficient_privilege then
    if sqlerrm <> 'SCHEDULE_UNAVAILABLE' then raise; end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000001',
  true
);
insert into phase_4c3_ids
select
  'dst_series',
  (
    public.create_schedule_series(
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000001',
      'training',
      'horse.schedule',
      'DST training',
      'Keep local intent at 02:30.',
      'Europe/Amsterdam',
      'daily',
      1,
      null,
      '02:30',
      30,
      '2026-03-28',
      '2026-03-30',
      60,
      'active',
      '4c380000-0000-0000-0000-000000000001'
    )->>'series_id'
  )::uuid;

do $$
declare
  first_run jsonb;
  replayed jsonb;
  no_op jsonb;
begin
  first_run := public.materialize_schedule_occurrences(
    (select id from phase_4c3_ids where name = 'dst_series'),
    '2026-03-30',
    '4c380000-0000-0000-0000-000000000002'
  );
  replayed := public.materialize_schedule_occurrences(
    (select id from phase_4c3_ids where name = 'dst_series'),
    '2026-03-30',
    '4c380000-0000-0000-0000-000000000002'
  );
  no_op := public.materialize_schedule_occurrences(
    (select id from phase_4c3_ids where name = 'dst_series'),
    '2026-03-30',
    '4c380000-0000-0000-0000-000000000003'
  );
  if (first_run->>'created_count')::integer <> 3
    or (replayed->>'created_count')::integer <> 3
    or (replayed->>'idempotent')::boolean is not true
    or (no_op->>'created_count')::integer <> 0
    or (
      select count(*)
      from public.schedule_items
      where series_id = (
        select id from phase_4c3_ids where name = 'dst_series'
      )
    ) <> 3
    or exists (
      select 1
      from public.schedule_items
      where series_id = (
        select id from phase_4c3_ids where name = 'dst_series'
      )
        and (
          source_timezone <> 'Europe/Amsterdam'
          or source_local_time <> '02:30'
          or source_local_date <> occurrence_local_date
        )
    )
  then
    raise exception 'Daily/DST materialization or idempotency failed';
  end if;
  if (
    select count(distinct scheduled_start_at)
    from public.schedule_items
    where series_id = (
      select id from phase_4c3_ids where name = 'dst_series'
    )
  ) <> 3 then
    raise exception 'DST materialization produced duplicate instants';
  end if;
end;
$$;

insert into phase_4c3_ids
select
  'weekly_series',
  (
    public.create_schedule_series(
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000001',
      'task',
      'horse.schedule',
      'Weekly checks',
      'Monday and Friday.',
      'Europe/Brussels',
      'weekly',
      1,
      array[1, 5]::smallint[],
      '08:00',
      null,
      '2026-10-19',
      '2026-10-30',
      30,
      'active',
      '4c380000-0000-0000-0000-000000000004'
    )->>'series_id'
  )::uuid;

select public.materialize_schedule_occurrences(
  (select id from phase_4c3_ids where name = 'weekly_series'),
  '2026-10-30',
  '4c380000-0000-0000-0000-000000000005'
);

do $$
begin
  if (
    select array_agg(occurrence_local_date order by occurrence_local_date)
    from public.schedule_items
    where series_id = (
      select id from phase_4c3_ids where name = 'weekly_series'
    )
  ) <> array[
    '2026-10-19'::date,
    '2026-10-23'::date,
    '2026-10-26'::date,
    '2026-10-30'::date
  ] then
    raise exception 'Weekly recurrence materialization failed';
  end if;
end;
$$;

insert into phase_4c3_ids
select
  'sparse_interval_series',
  (
    public.create_schedule_series(
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000001',
      'care',
      'horse.schedule',
      'Annual sparse check',
      'Prove progress across empty materialization horizons.',
      'Europe/Amsterdam',
      'interval',
      365,
      null,
      '12:00',
      null,
      '2026-01-01',
      '2027-01-01',
      90,
      'active',
      '4c380000-0000-0000-0000-000000000006'
    )->>'series_id'
  )::uuid;

select public.materialize_schedule_occurrences(
  (select id from phase_4c3_ids where name = 'sparse_interval_series'),
  '2027-01-01',
  '4c380000-0000-0000-0000-000000000007'
);
select public.materialize_schedule_occurrences(
  (select id from phase_4c3_ids where name = 'sparse_interval_series'),
  '2027-01-01',
  '4c380000-0000-0000-0000-000000000008'
);
select public.materialize_schedule_occurrences(
  (select id from phase_4c3_ids where name = 'sparse_interval_series'),
  '2027-01-01',
  '4c380000-0000-0000-0000-000000000009'
);
select public.materialize_schedule_occurrences(
  (select id from phase_4c3_ids where name = 'sparse_interval_series'),
  '2027-01-01',
  '4c380000-0000-0000-0000-000000000010'
);
select public.materialize_schedule_occurrences(
  (select id from phase_4c3_ids where name = 'sparse_interval_series'),
  '2027-01-01',
  '4c380000-0000-0000-0000-000000000011'
);

do $$
begin
  if (
    select array_agg(occurrence_local_date order by occurrence_local_date)
    from public.schedule_items
    where series_id = (
      select id
      from phase_4c3_ids
      where name = 'sparse_interval_series'
    )
  ) <> array['2026-01-01'::date, '2027-01-01'::date]
  then
    raise exception 'Sparse interval materialization did not advance';
  end if;
end;
$$;

insert into phase_4c3_ids
select
  'cursor_reset_series',
  (
    public.create_schedule_series(
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000001',
      'task',
      'horse.schedule',
      'Cursor reset proof',
      'Begin on Tuesday while the first version selects Monday.',
      'Europe/Amsterdam',
      'weekly',
      1,
      array[1]::smallint[],
      '13:00',
      null,
      '2026-01-06',
      null,
      1,
      'active',
      '4c380000-0000-0000-0000-000000000012'
    )->>'series_id'
  )::uuid;

select public.materialize_schedule_occurrences(
  (select id from phase_4c3_ids where name = 'cursor_reset_series'),
  '2026-01-06',
  '4c380000-0000-0000-0000-000000000013'
);

select public.update_schedule_series_scope(
  (select id from phase_4c3_ids where name = 'cursor_reset_series'),
  1,
  'full',
  null,
  null,
  '4c380000-0000-0000-0000-000000000014',
  'Cursor reset proof updated',
  'Old empty-window progress must not survive this version.',
  'Europe/Amsterdam',
  'daily',
  1,
  null,
  '13:00',
  null,
  null,
  1,
  'active'
);

select public.materialize_schedule_occurrences(
  (select id from phase_4c3_ids where name = 'cursor_reset_series'),
  '2026-01-06',
  '4c380000-0000-0000-0000-000000000015'
);

do $$
begin
  if (
    select array_agg(occurrence_local_date order by occurrence_local_date)
    from public.schedule_items
    where series_id = (
      select id from phase_4c3_ids where name = 'cursor_reset_series'
    )
  ) <> array['2026-01-06'::date]
  then
    raise exception 'Full series update retained stale scan progress';
  end if;
end;
$$;

insert into phase_4c3_ids
select
  'assigned_viewer_assignment',
  (
    public.assign_schedule_item(
      (select id from phase_4c3_ids where name = 'one_off'),
      '4c330000-0000-0000-0000-000000000004',
      'responsible',
      '4c390000-0000-0000-0000-000000000001'
    )->>'assignment_id'
  )::uuid;

insert into phase_4c3_ids
select
  'unlinked_support_assignment',
  (
    public.assign_schedule_item(
      (select id from phase_4c3_ids where name = 'one_off'),
      '4c330000-0000-0000-0000-000000000006',
      'support',
      '4c390000-0000-0000-0000-000000000002'
    )->>'assignment_id'
  )::uuid;

do $$
begin
  begin
    perform public.assign_schedule_item(
      (select id from phase_4c3_ids where name = 'one_off'),
      '4c330000-0000-0000-0000-000000000006',
      'responsible',
      gen_random_uuid()
    );
    raise exception 'Second active responsible assignment succeeded';
  exception when unique_violation then
    if sqlerrm <> 'ASSIGNMENT_ALREADY_ACTIVE' then raise; end if;
  end;
  begin
    perform public.assign_schedule_item(
      (select id from phase_4c3_ids where name = 'one_off'),
      '4c330000-0000-0000-0000-000000000008',
      'support',
      gen_random_uuid()
    );
    raise exception 'Cross-stable roster assignment succeeded';
  exception when insufficient_privilege then
    if sqlerrm <> 'STABLE_MEMBER_UNAVAILABLE' then raise; end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000004',
  true
);
do $$
begin
  if (
    select count(*)
    from public.schedule_items
    where id = (select id from phase_4c3_ids where name = 'one_off')
  ) <> 1 then
    raise exception 'Explicit canonical editor lacked full base-row access';
  end if;
  if (
    select count(*)
    from public.get_schedule_item(
      (select id from phase_4c3_ids where name = 'one_off')
    )
    where access_scope = 'full'
      and series_id is null
      and assignment_role = 'responsible'
  ) <> 1 then
    raise exception 'Explicit canonical editor deep-link read failed';
  end if;
  if (
    select count(*)
    from public.list_today_schedule(
      '4c320000-0000-0000-0000-000000000001',
      '2026-07-28'
    )
    where schedule_item_id = (
      select id from phase_4c3_ids where name = 'one_off'
    )
      and access_scope = 'full'
  ) <> 1 then
    raise exception 'Explicit canonical editor Today read failed';
  end if;
  if (
    select count(*) from public.canonical_horses
    where id = '4c350000-0000-0000-0000-000000000001'
  ) <> 1 then
    raise exception 'Explicit canonical editor lacked Horse dossier access';
  end if;
end;
$$;

insert into phase_4c3_ids
select
  'partial_execution',
  (
    public.record_schedule_execution(
      (select id from phase_4c3_ids where name = 'one_off'),
      '4c3a0000-0000-0000-0000-000000000001',
      'partial',
      '2026-07-28 06:02:00+00',
      '2026-07-28 06:12:00+00',
      '2026-07-28 08:12:00',
      'Europe/Amsterdam',
      'online',
      null,
      'Water checked; movement partly completed.'
    )->>'execution_id'
  )::uuid;

do $$
declare
  replayed jsonb;
begin
  replayed := public.record_schedule_execution(
    (select id from phase_4c3_ids where name = 'one_off'),
    '4c3a0000-0000-0000-0000-000000000001',
    'partial',
    '2026-07-28 06:02:00+00',
    '2026-07-28 06:12:00+00',
    '2026-07-28 08:12:00',
    'Europe/Amsterdam',
    'online',
    null,
    'Water checked; movement partly completed.'
  );
  if (replayed->>'execution_id')::uuid <> (
      select id from phase_4c3_ids where name = 'partial_execution'
    )
    or (replayed->>'idempotent')::boolean is not true
    or (
      select count(*)
      from public.schedule_executions
      where request_id = '4c3a0000-0000-0000-0000-000000000001'
    ) <> 1
  then
    raise exception 'Execution idempotency/event correlation failed';
  end if;
  begin
    perform public.record_schedule_execution(
      (select id from phase_4c3_ids where name = 'one_off'),
      '4c3a0000-0000-0000-0000-000000000001',
      'problem',
      '2026-07-28 06:02:00+00',
      '2026-07-28 06:12:00+00',
      '2026-07-28 08:12:00',
      'Europe/Amsterdam',
      'online',
      null,
      'Changed payload'
    );
    raise exception 'Execution request ID was reused with another payload';
  exception when invalid_parameter_value then
    if sqlerrm <> 'REQUEST_ID_REUSED' then raise; end if;
  end;
end;
$$;

reset role;
insert into public.client_sync_devices (
  id,
  stable_id,
  actor_user_id,
  encryption_public_key,
  encryption_key_fingerprint,
  registered_authority_version
)
select
  '4c3a0000-0000-0000-0000-000000000099',
  '4c320000-0000-0000-0000-000000000001',
  '4c310000-0000-0000-0000-000000000004',
  '-----BEGIN PGP PUBLIC KEY BLOCK-----'
    || repeat('x', 200)
    || '-----END PGP PUBLIC KEY BLOCK-----',
  extensions.digest(
    convert_to('phase-4c3-regression-device', 'UTF8'),
    'sha256'
  ),
  (
    select authority_version
    from public.stable_sync_authorities
    where stable_id = '4c320000-0000-0000-0000-000000000001'
  );
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000004',
  true
);

insert into phase_4c3_ids
select
  'completed_execution',
  (
    public.record_schedule_execution(
      (select id from phase_4c3_ids where name = 'one_off'),
      '4c3a0000-0000-0000-0000-000000000002',
      'completed',
      '2026-07-28 06:13:00+00',
      '2026-07-28 06:25:00+00',
      '2026-07-28 08:25:00',
      'Europe/Amsterdam',
      'offline_sync',
      '4c3a0000-0000-0000-0000-000000000099',
      null
    )->>'execution_id'
  )::uuid;

do $$
declare
  terminal_replay jsonb;
begin
  terminal_replay := public.record_schedule_execution(
    (select id from phase_4c3_ids where name = 'one_off'),
    '4c3a0000-0000-0000-0000-000000000002',
    'completed',
    '2026-07-28 06:13:00+00',
    '2026-07-28 06:25:00+00',
    '2026-07-28 08:25:00',
    'Europe/Amsterdam',
    'offline_sync',
    '4c3a0000-0000-0000-0000-000000000099',
    null
  );
  if not exists (
    select 1
    from public.get_schedule_item(
      (select id from phase_4c3_ids where name = 'one_off')
    )
    where state = 'completed'
  ) or (
    select count(*)
    from public.list_schedule_executions(
      (select id from phase_4c3_ids where name = 'one_off')
    )
  ) <> 2
    or (terminal_replay->>'idempotent')::boolean is not true
    or (terminal_replay->>'execution_id')::uuid <> (
      select id from phase_4c3_ids where name = 'completed_execution'
    )
  then
    raise exception 'Terminal execution state/history failed';
  end if;
  begin
    perform public.record_schedule_execution(
      (select id from phase_4c3_ids where name = 'one_off'),
      gen_random_uuid(),
      'completed',
      null,
      '2026-07-28 06:30:00+00',
      '2026-07-28 08:30:00',
      'Europe/Amsterdam',
      'online',
      null,
      null
    );
    raise exception 'Terminal schedule item accepted another execution';
  exception when insufficient_privilege then
    if sqlerrm <> 'NOT_AUTHORIZED' then raise; end if;
  when object_not_in_prerequisite_state then
    if sqlerrm <> 'SCHEDULE_ITEM_TERMINAL' then raise; end if;
  end;
end;
$$;

insert into phase_4c3_ids
select
  'execution_correction',
  (
    public.correct_schedule_execution(
      (select id from phase_4c3_ids where name = 'completed_execution'),
      '4c3a0000-0000-0000-0000-000000000003',
      'problem',
      '2026-07-28 06:13:00+00',
      '2026-07-28 06:25:00+00',
      '2026-07-28 08:25:00',
      'Europe/Amsterdam',
      'online',
      null,
      'Correction: follow-up is required.'
    )->>'execution_id'
  )::uuid;

do $$
begin
  if not exists (
    select 1
    from public.schedule_executions
    where id = (select id from phase_4c3_ids where name = 'completed_execution')
      and execution_status = 'completed'
      and corrects_execution_id is null
  ) or not exists (
    select 1
    from public.schedule_executions
    where id = (select id from phase_4c3_ids where name = 'execution_correction')
      and execution_status = 'problem'
      and corrects_execution_id = (
        select id from phase_4c3_ids where name = 'completed_execution'
      )
  ) then
    raise exception 'Append-only correction did not preserve original';
  end if;
  begin
    perform public.correct_schedule_execution(
      (select id from phase_4c3_ids where name = 'completed_execution'),
      gen_random_uuid(),
      'completed',
      null,
      '2026-07-28 06:30:00+00',
      '2026-07-28 08:30:00',
      'Europe/Amsterdam',
      'online',
      null,
      null
    );
    raise exception 'Second direct correction succeeded';
  exception when object_not_in_prerequisite_state then
    if sqlerrm <> 'EXECUTION_ALREADY_CORRECTED' then raise; end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000001',
  true
);
insert into phase_4c3_ids
select
  'return_item',
  (
    public.create_schedule_item(
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000002',
      'task',
      'horse.schedule',
      'Returnable task',
      'Assigned actor may return this task.',
      'normal',
      '2026-07-29 07:00:00+00',
      null,
      'Europe/Amsterdam',
      '2026-07-29',
      '09:00',
      '4c3b0000-0000-0000-0000-000000000001'
    )->>'schedule_item_id'
  )::uuid;
insert into phase_4c3_ids
select
  'return_assignment',
  (
    public.assign_schedule_item(
      (select id from phase_4c3_ids where name = 'return_item'),
      '4c330000-0000-0000-0000-000000000004',
      'responsible',
      '4c3b0000-0000-0000-0000-000000000002'
    )->>'assignment_id'
  )::uuid;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000004',
  true
);
select public.return_schedule_assignment(
  (select id from phase_4c3_ids where name = 'return_assignment'),
  1,
  '4c3b0000-0000-0000-0000-000000000003'
);
do $$
begin
  begin
    perform public.record_schedule_execution(
      (select id from phase_4c3_ids where name = 'return_item'),
      gen_random_uuid(),
      'completed',
      null,
      '2026-07-29 07:10:00+00',
      '2026-07-29 09:10:00',
      'Europe/Amsterdam',
      'online',
      null,
      null
    );
    raise exception 'Returned assignee still executed task';
  exception when insufficient_privilege then
    if sqlerrm <> 'NOT_AUTHORIZED' then raise; end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000003',
  true
);
select public.cancel_schedule_item(
  (select id from phase_4c3_ids where name = 'member_item'),
  1,
  '4c3b0000-0000-0000-0000-000000000004',
  'Operationeel geannuleerd'
);

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000005',
  true
);
do $$
begin
  begin
    perform public.reopen_schedule_item(
      (select id from phase_4c3_ids where name = 'member_item'),
      2,
      gen_random_uuid(),
      'Viewer must not reopen'
    );
    raise exception 'Viewer reopened a terminal task';
  exception when insufficient_privilege then
    if sqlerrm <> 'NOT_AUTHORIZED' then raise; end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000002',
  true
);
select public.reopen_schedule_item(
  (select id from phase_4c3_ids where name = 'member_item'),
  2,
  '4c3b0000-0000-0000-0000-000000000005',
  'Beheerder heropent na controle'
);

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000003',
  true
);
do $$
begin
  begin
    perform public.update_schedule_item(
      (select id from phase_4c3_ids where name = 'member_item'),
      1,
      gen_random_uuid(),
      'Stale update',
      'Must fail.',
      'normal',
      '2026-07-28 07:00:00+00',
      '2026-07-28 07:15:00+00',
      'Europe/Amsterdam',
      '2026-07-28',
      '09:00'
    );
    raise exception 'Stale schedule update succeeded';
  exception when serialization_failure then
    if sqlerrm <> 'ROW_VERSION_CONFLICT' then raise; end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000001',
  true
);
select public.update_schedule_series_scope(
  (select id from phase_4c3_ids where name = 'dst_series'),
  1,
  'occurrence',
  (
    select id
    from public.schedule_items
    where series_id = (
      select id from phase_4c3_ids where name = 'dst_series'
    )
      and occurrence_local_date = '2026-03-28'
  ),
  '2026-03-28',
  '4c3c0000-0000-0000-0000-000000000001',
  'Single occurrence override',
  'Only this occurrence changes.',
  'Europe/Amsterdam',
  'daily',
  1,
  null,
  '03:00',
  45,
  '2026-03-30',
  60,
  'active'
);

insert into phase_4c3_ids
select
  'replacement_series',
  (
    public.update_schedule_series_scope(
      (select id from phase_4c3_ids where name = 'dst_series'),
      1,
      'future',
      null,
      '2026-03-30',
      '4c3c0000-0000-0000-0000-000000000002',
      'Future training',
      'Future occurrences use a new immutable definition.',
      'Europe/Amsterdam',
      'interval',
      2,
      null,
      '04:00',
      30,
      '2026-04-05',
      60,
      'active'
    )->>'replacement_series_id'
  )::uuid;

do $$
begin
  if not exists (
    select 1
    from public.schedule_items
    where series_id = (
      select id from phase_4c3_ids where name = 'dst_series'
    )
      and occurrence_local_date = '2026-03-28'
      and title = 'Single occurrence override'
      and series_override
      and row_version = 2
  ) or not exists (
    select 1
    from public.schedule_items
    where series_id = (
      select id from phase_4c3_ids where name = 'dst_series'
    )
      and occurrence_local_date = '2026-03-30'
      and state = 'cancelled'
      and state_reason = 'series_replaced'
  ) or not exists (
    select 1
    from public.schedule_series
    where id = (select id from phase_4c3_ids where name = 'dst_series')
      and status = 'ended'
      and ends_on = '2026-03-29'
  ) or not exists (
    select 1
    from public.schedule_series
    where id = (
      select id from phase_4c3_ids where name = 'replacement_series'
    )
      and supersedes_series_id = (
        select id from phase_4c3_ids where name = 'dst_series'
      )
      and starts_on = '2026-03-30'
      and frequency = 'interval'
  ) then
    raise exception 'Occurrence/future series scope behavior failed';
  end if;
end;
$$;

insert into phase_4c3_ids
select
  'draft_series',
  (
    public.create_schedule_series(
      '4c320000-0000-0000-0000-000000000001',
      null,
      'task',
      'horse.schedule',
      'Draft stable task',
      'No Horse and no occurrences yet.',
      'Europe/Amsterdam',
      'daily',
      1,
      null,
      '10:00',
      null,
      '2026-08-01',
      null,
      30,
      'draft',
      '4c3c0000-0000-0000-0000-000000000003'
    )->>'series_id'
  )::uuid;

select public.update_schedule_series_scope(
  (select id from phase_4c3_ids where name = 'draft_series'),
  1,
  'full',
  null,
  null,
  '4c3c0000-0000-0000-0000-000000000004',
  'Updated draft stable task',
  'Full scope is allowed before history exists.',
  'Europe/Brussels',
  'weekly',
  1,
  array[2]::smallint[],
  '11:00',
  15,
  '2026-08-31',
  45,
  'active'
);

do $$
begin
  if not exists (
    select 1
    from public.schedule_series
    where id = (select id from phase_4c3_ids where name = 'draft_series')
      and row_version = 2
      and title = 'Updated draft stable task'
      and weekdays = array[2]::smallint[]
      and status = 'active'
  ) then
    raise exception 'Full series update without history failed';
  end if;
  begin
    perform public.update_schedule_series_scope(
      (select id from phase_4c3_ids where name = 'weekly_series'),
      1,
      'full',
      null,
      null,
      gen_random_uuid(),
      'Illegal full rewrite',
      'History must remain immutable.',
      'Europe/Brussels',
      'daily',
      1,
      null,
      '08:00',
      null,
      '2026-10-30',
      30,
      'active'
    );
    raise exception 'Series history was rewritten in full scope';
  exception when object_not_in_prerequisite_state then
    if sqlerrm <> 'SERIES_HAS_HISTORY' then raise; end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000005',
  true
);
do $$
begin
  if (
    select count(*)
    from public.get_schedule_item(
      (select id from phase_4c3_ids where name = 'one_off')
    )
  ) <> 0 or (
    select count(*)
    from public.list_today_schedule(
      '4c320000-0000-0000-0000-000000000001',
      '2026-07-28'
    )
  ) <> 0 then
    raise exception 'Unassigned viewer received schedule data';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000007',
  true
);
do $$
begin
  if (
    select count(*)
    from public.list_today_schedule(
      '4c320000-0000-0000-0000-000000000001',
      '2026-07-28'
    )
  ) <> 0 or (
    select count(*)
    from public.get_schedule_item(
      (select id from phase_4c3_ids where name = 'one_off')
    )
  ) <> 0 then
    raise exception 'Control-stable owner crossed the tenant boundary';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000006',
  true
);
do $$
begin
  if (
    select count(*)
    from public.list_today_schedule(
      '4c320000-0000-0000-0000-000000000001',
      '2026-07-28'
    )
  ) <> 0 then
    raise exception 'Suspended membership retained schedule reads';
  end if;
  if (
    select count(*)
    from public.schedule_executions
    where id = '4c3e0000-0000-0000-0000-000000000006'
      and note = 'SENSITIVE-PROOF-NOTE'
  ) <> 0 then
    raise exception 'Suspended actor retained direct execution RLS access';
  end if;
  begin
    perform public.record_schedule_execution(
      (select id from phase_4c3_ids where name = 'member_item'),
      gen_random_uuid(),
      'completed',
      null,
      '2026-07-28 08:00:00+00',
      '2026-07-28 10:00:00',
      'Europe/Amsterdam',
      'online',
      null,
      null
    );
    raise exception 'Suspended membership executed a schedule item';
  exception when insufficient_privilege then
    if sqlerrm <> 'SCHEDULE_UNAVAILABLE' then raise; end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c310000-0000-0000-0000-000000000001',
  true
);
do $$
begin
  if (
    select count(*)
    from public.get_schedule_item(
      (select id from phase_4c3_ids where name = 'one_off')
    )
    where access_scope = 'full'
  ) <> 1 then
    raise exception 'Owner full deep-link read failed';
  end if;
  begin
    insert into public.schedule_items (
      stable_id, horse_id, item_kind, data_category, title, instruction,
      priority, scheduled_start_at, source_timezone, source_local_date,
      source_local_time, state, created_by_user_id, created_request_id,
      last_mutated_by_user_id, last_mutation_request_id
    )
    values (
      '4c320000-0000-0000-0000-000000000001',
      '4c350000-0000-0000-0000-000000000001',
      'task', 'horse.schedule', 'Direct DML', 'Must fail', 'normal',
      '2026-07-30 08:00:00+00', 'UTC', '2026-07-30', '08:00', 'planned',
      '4c310000-0000-0000-0000-000000000001', gen_random_uuid(),
      '4c310000-0000-0000-0000-000000000001', gen_random_uuid()
    );
    raise exception 'Authenticated direct schedule DML succeeded';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;

do $$
declare
  function_name text;
begin
  foreach function_name in array array[
    'create_schedule_series',
    'update_schedule_series_scope',
    'materialize_schedule_occurrences',
    'create_schedule_item',
    'update_schedule_item',
    'cancel_schedule_item',
    'assign_schedule_item',
    'return_schedule_assignment',
    'record_schedule_execution',
    'correct_schedule_execution',
    'reopen_schedule_item',
    'get_schedule_item',
    'list_today_schedule',
    'list_schedule_executions'
  ]
  loop
    if not exists (
      select 1
      from pg_catalog.pg_proc procedure
      join pg_catalog.pg_namespace namespace
        on namespace.oid = procedure.pronamespace
      where namespace.nspname = 'public'
        and procedure.proname = function_name
        and procedure.prosecdef
        and procedure.proconfig @> array['search_path=""']::text[]
    ) then
      raise exception 'SECURITY DEFINER/search_path missing for %', function_name;
    end if;
  end loop;

  begin
    update public.schedule_executions
    set note = 'Illegal rewrite'
    where id = (select id from phase_4c3_ids where name = 'partial_execution');
    raise exception 'Append-only execution was updated';
  exception when object_not_in_prerequisite_state then
    if sqlerrm <> 'APPEND_ONLY_RECORD' then raise; end if;
  end;
  begin
    delete from public.schedule_change_events
    where schedule_execution_id = (
      select id from phase_4c3_ids where name = 'partial_execution'
    );
    raise exception 'Append-only schedule event was deleted';
  exception when object_not_in_prerequisite_state then
    if sqlerrm <> 'APPEND_ONLY_RECORD' then raise; end if;
  end;

  if exists (
    select 1
    from private.schedule_mutation_receipts
    where result::text ilike '%Water checked%'
       or result::text ilike '%Correction:%'
  ) then
    raise exception 'Private schedule receipt copied raw note text';
  end if;
  if (
    select count(*)
    from public.schedule_change_events
    where request_id = '4c3a0000-0000-0000-0000-000000000001'
      and event_type = 'schedule_execution_recorded'
      and schedule_execution_id = (
        select id from phase_4c3_ids where name = 'partial_execution'
      )
  ) <> 1 then
    raise exception 'Execution event correlation failed';
  end if;
  if (
    select count(*)
    from public.schedule_series
    where stable_id = '4c320000-0000-0000-0000-000000000002'
  ) <> 1 or (
    select count(*)
    from public.schedule_items
    where stable_id = '4c320000-0000-0000-0000-000000000002'
  ) <> 1 or (
    select count(*)
    from public.schedule_assignments
    where stable_id = '4c320000-0000-0000-0000-000000000002'
  ) <> 1 or (
    select count(*)
    from public.schedule_executions
    where stable_id = '4c320000-0000-0000-0000-000000000002'
  ) <> 1 or not exists (
    select 1
    from public.horses
    where id = '4c350000-0000-0000-0000-000000000003'
      and status = 'active'
      and row_version = 1
  ) then
    raise exception 'Control stable was modified';
  end if;
end;
$$;

set local role anon;
select set_config('request.jwt.claim.role', 'anon', true);
select set_config('request.jwt.claim.sub', '', true);
do $$
declare
  relation_name text;
begin
  foreach relation_name in array array[
    'schedule_series',
    'schedule_items',
    'schedule_assignments',
    'schedule_executions',
    'schedule_change_events'
  ]
  loop
    begin
      execute format('select 1 from public.%I limit 1', relation_name);
      raise exception 'Anonymous read %', relation_name;
    exception when insufficient_privilege then null;
    end;
  end loop;
  begin
    perform public.get_schedule_item(
      '4c3f0000-0000-0000-0000-000000000001'
    );
    raise exception 'Anonymous deep-link execution succeeded';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
rollback;
