begin;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000000',
  '4c5f1000-0000-0000-0000-000000000001',
  'authenticated', 'authenticated',
  '4c5-upgrade-owner@example.invalid', '', now(), '{}', '{}', now(), now()
);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values (
  '4c5f2000-0000-0000-0000-000000000001',
  'organization', '4C.5 upgrade control', 'active',
  'Europe/Amsterdam', 'nl',
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5f3000-0000-0000-0000-000000000001'
);

insert into public.stable_members (
  id, stable_id, display_name, source
)
values (
  '4c5f4000-0000-0000-0000-000000000001',
  '4c5f2000-0000-0000-0000-000000000001',
  '4C.5 upgrade owner', 'owner_creation'
);

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values (
  '4c5f5000-0000-0000-0000-000000000001',
  '4c5f2000-0000-0000-0000-000000000001',
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5f4000-0000-0000-0000-000000000001',
  'owner', 'active', '2026-07-27 06:00:00+00'
);

set constraints all immediate;

insert into public.horses (
  id, stable_id, display_name, source_kind,
  created_by_user_id, created_request_id
)
values (
  '4c5f6000-0000-0000-0000-000000000001',
  '4c5f2000-0000-0000-0000-000000000001',
  '4C.5 Upgrade Horse', 'manual',
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5f7000-0000-0000-0000-000000000001'
);

insert into public.schedule_series (
  id, stable_id, horse_id, series_kind, data_category, title, instruction,
  timezone, frequency, interval_value, local_start_time,
  duration_minutes, starts_on, status, generation_horizon_days,
  created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c5f8000-0000-0000-0000-000000000001',
  '4c5f2000-0000-0000-0000-000000000001',
  '4c5f6000-0000-0000-0000-000000000001',
  'task', 'horse.schedule', '4C.5 upgrade schedule',
  'Preserve schedule instruction.', 'Europe/Amsterdam',
  'daily', 1, '08:00', 30, '2026-07-28', 'active', 30,
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5f8000-0000-0000-0000-000000000011',
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5f8000-0000-0000-0000-000000000011'
);

insert into public.schedule_items (
  id, stable_id, horse_id, series_id, occurrence_local_date,
  occurrence_sequence, item_kind, data_category, title, instruction,
  priority, scheduled_start_at, scheduled_end_at, source_timezone,
  source_local_date, source_local_time, state, terminal_at,
  created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c5f9000-0000-0000-0000-000000000001',
  '4c5f2000-0000-0000-0000-000000000001',
  '4c5f6000-0000-0000-0000-000000000001',
  '4c5f8000-0000-0000-0000-000000000001',
  '2026-07-28', 1, 'task', 'horse.schedule',
  '4C.5 upgrade schedule', 'Preserve schedule instruction.',
  'normal', '2026-07-28 06:00:00+00', '2026-07-28 06:30:00+00',
  'Europe/Amsterdam', '2026-07-28', '08:00', 'completed',
  '2026-07-28 06:20:00+00',
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5f9000-0000-0000-0000-000000000011',
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5f9000-0000-0000-0000-000000000011'
);

insert into public.schedule_executions (
  id, stable_id, schedule_item_id, actor_user_id,
  actor_membership_id, actor_stable_member_id, execution_status,
  actual_started_at, actual_completed_at, recorded_local_at,
  recorded_timezone, source, request_id, note
)
values (
  '4c5fa000-0000-0000-0000-000000000001',
  '4c5f2000-0000-0000-0000-000000000001',
  '4c5f9000-0000-0000-0000-000000000001',
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5f5000-0000-0000-0000-000000000001',
  '4c5f4000-0000-0000-0000-000000000001',
  'completed', '2026-07-28 06:00:00+00',
  '2026-07-28 06:20:00+00', '2026-07-28 08:20:00',
  'Europe/Amsterdam', 'online',
  '4c5fa000-0000-0000-0000-000000000011',
  'Preserve 4C.3 execution history.'
);

insert into public.feeding_plans (
  id, stable_id, horse_id, plan_type, name, status,
  effective_from, effective_until,
  created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c5fb000-0000-0000-0000-000000000001',
  '4c5f2000-0000-0000-0000-000000000001',
  '4c5f6000-0000-0000-0000-000000000001',
  'standard', 'Preserve 4C.4 feeding plan', 'draft',
  '2026-07-28', null,
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5fb000-0000-0000-0000-000000000011',
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5fb000-0000-0000-0000-000000000011'
);

insert into public.feeding_plan_versions (
  id, stable_id, feeding_plan_id, version_number, status,
  source_kind, change_reason,
  created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c5fc000-0000-0000-0000-000000000001',
  '4c5f2000-0000-0000-0000-000000000001',
  '4c5fb000-0000-0000-0000-000000000001',
  1, 'draft', 'user', 'Preserve this immutable reason.',
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5fc000-0000-0000-0000-000000000011',
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5fc000-0000-0000-0000-000000000011'
);

insert into public.feeding_plan_items (
  id, stable_id, feeding_plan_version_id, product_name,
  source_status, planned_quantity, unit_code, offering_method,
  round_code, local_time, override_key,
  created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c5fd000-0000-0000-0000-000000000001',
  '4c5f2000-0000-0000-0000-000000000001',
  '4c5fc000-0000-0000-0000-000000000001',
  'Preserved hay', 'user_entered', 3.5, 'kg', 'hay_net',
  'morning', '08:00', 'upgrade-hay',
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5fd000-0000-0000-0000-000000000011',
  '4c5f1000-0000-0000-0000-000000000001',
  '4c5fd000-0000-0000-0000-000000000011'
);

commit;
