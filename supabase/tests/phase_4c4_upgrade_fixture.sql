begin;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000000',
  '4c4f1000-0000-0000-0000-000000000001',
  'authenticated', 'authenticated',
  '4c4-upgrade-owner@example.invalid', '', now(), '{}', '{}', now(), now()
);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values (
  '4c4f2000-0000-0000-0000-000000000001',
  'organization', '4C.4 upgrade control', 'active',
  'Europe/Amsterdam', 'nl',
  '4c4f1000-0000-0000-0000-000000000001',
  '4c4f3000-0000-0000-0000-000000000001'
);

insert into public.stable_members (
  id, stable_id, display_name, source
)
values (
  '4c4f4000-0000-0000-0000-000000000001',
  '4c4f2000-0000-0000-0000-000000000001',
  '4C.4 upgrade owner', 'owner_creation'
);

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values (
  '4c4f5000-0000-0000-0000-000000000001',
  '4c4f2000-0000-0000-0000-000000000001',
  '4c4f1000-0000-0000-0000-000000000001',
  '4c4f4000-0000-0000-0000-000000000001',
  'owner', 'active', '2026-07-27 06:00:00+00'
);

set constraints all immediate;

insert into public.horses (
  id, stable_id, display_name, source_kind,
  created_by_user_id, created_request_id
)
values (
  '4c4f6000-0000-0000-0000-000000000001',
  '4c4f2000-0000-0000-0000-000000000001',
  '4C.4 Upgrade Horse', 'manual',
  '4c4f1000-0000-0000-0000-000000000001',
  '4c4f7000-0000-0000-0000-000000000001'
);

insert into public.schedule_series (
  id, stable_id, horse_id, series_kind, data_category, title, instruction,
  timezone, frequency, interval_value, weekdays, local_start_time,
  duration_minutes, starts_on, ends_on, status, generation_horizon_days,
  created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c4f8000-0000-0000-0000-000000000001',
  '4c4f2000-0000-0000-0000-000000000001',
  '4c4f6000-0000-0000-0000-000000000001',
  'task', 'horse.schedule', 'Upgrade check', 'Preserve this instruction.',
  'Europe/Amsterdam', 'daily', 1, null, '08:00',
  30, '2026-07-28', null, 'active', 30,
  '4c4f1000-0000-0000-0000-000000000001',
  '4c4f9000-0000-0000-0000-000000000001',
  '4c4f1000-0000-0000-0000-000000000001',
  '4c4f9000-0000-0000-0000-000000000001'
);

insert into public.schedule_items (
  id, stable_id, horse_id, series_id, occurrence_local_date,
  occurrence_sequence, item_kind, data_category, title, instruction,
  priority, scheduled_start_at, scheduled_end_at, source_timezone,
  source_local_date, source_local_time, state,
  created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c4fa000-0000-0000-0000-000000000001',
  '4c4f2000-0000-0000-0000-000000000001',
  '4c4f6000-0000-0000-0000-000000000001',
  '4c4f8000-0000-0000-0000-000000000001',
  '2026-07-28', 1,
  'task', 'horse.schedule', 'Upgrade check', 'Preserve this instruction.',
  'normal', '2026-07-28 06:00:00+00', '2026-07-28 06:30:00+00',
  'Europe/Amsterdam', '2026-07-28', '08:00', 'in_progress',
  '4c4f1000-0000-0000-0000-000000000001',
  '4c4fa000-0000-0000-0000-000000000011',
  '4c4f1000-0000-0000-0000-000000000001',
  '4c4fa000-0000-0000-0000-000000000011'
);

insert into public.schedule_assignments (
  id, stable_id, schedule_item_id, stable_member_id, assignment_role,
  status, accepted_at, created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c4fb000-0000-0000-0000-000000000001',
  '4c4f2000-0000-0000-0000-000000000001',
  '4c4fa000-0000-0000-0000-000000000001',
  '4c4f4000-0000-0000-0000-000000000001',
  'responsible', 'accepted', '2026-07-28 05:55:00+00',
  '4c4f1000-0000-0000-0000-000000000001',
  '4c4fb000-0000-0000-0000-000000000011',
  '4c4f1000-0000-0000-0000-000000000001',
  '4c4fb000-0000-0000-0000-000000000011'
);

insert into public.schedule_executions (
  id, stable_id, schedule_item_id, actor_user_id,
  actor_membership_id, actor_stable_member_id, execution_status,
  actual_started_at, actual_completed_at, recorded_local_at,
  recorded_timezone, source, request_id, note
)
values (
  '4c4fc000-0000-0000-0000-000000000001',
  '4c4f2000-0000-0000-0000-000000000001',
  '4c4fa000-0000-0000-0000-000000000001',
  '4c4f1000-0000-0000-0000-000000000001',
  '4c4f5000-0000-0000-0000-000000000001',
  '4c4f4000-0000-0000-0000-000000000001',
  'partial',
  '2026-07-28 06:00:00+00', '2026-07-28 06:20:00+00',
  '2026-07-28 08:20:00', 'Europe/Amsterdam', 'online',
  '4c4fc000-0000-0000-0000-000000000011',
  'Preserve this execution note.'
);

insert into public.schedule_change_events (
  stable_id, schedule_item_id, schedule_series_id,
  actor_user_id, actor_membership_id, request_id,
  event_type, data_category, row_version
)
values (
  '4c4f2000-0000-0000-0000-000000000001',
  '4c4fa000-0000-0000-0000-000000000001',
  '4c4f8000-0000-0000-0000-000000000001',
  '4c4f1000-0000-0000-0000-000000000001',
  '4c4f5000-0000-0000-0000-000000000001',
  '4c4fd000-0000-0000-0000-000000000001',
  'schedule_execution_recorded', 'horse.schedule', 1
);

commit;
