begin;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000000',
  '4c2b1000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  '4c2b-upgrade-owner@example.invalid',
  '',
  now(),
  '{}',
  '{}',
  now(),
  now()
);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values (
  '4c2b2000-0000-0000-0000-000000000001',
  'organization',
  '4C.2B upgrade control',
  'active',
  'UTC',
  'nl',
  '4c2b1000-0000-0000-0000-000000000001',
  '4c2b3000-0000-0000-0000-000000000001'
);

insert into public.stable_members (
  id, stable_id, display_name, source
)
values (
  '4c2b4000-0000-0000-0000-000000000001',
  '4c2b2000-0000-0000-0000-000000000001',
  'Upgrade owner',
  'owner_creation'
);

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values (
  '4c2b5000-0000-0000-0000-000000000001',
  '4c2b2000-0000-0000-0000-000000000001',
  '4c2b1000-0000-0000-0000-000000000001',
  '4c2b4000-0000-0000-0000-000000000001',
  'owner',
  'active',
  '2026-07-27 05:00:00+00'
);

set constraints all immediate;

set local session_replication_role = replica;
insert into public.horses (
  id, stable_id, status, display_name, source_kind,
  created_by_user_id, created_request_id,
  created_at, updated_at
)
values (
  '4c2b6000-0000-0000-0000-000000000001',
  '4c2b2000-0000-0000-0000-000000000001',
  'active',
  'Upgrade Horse',
  'manual',
  '4c2b1000-0000-0000-0000-000000000001',
  '4c2b7000-0000-0000-0000-000000000001',
  '2026-07-27 05:01:00+00',
  '2026-07-27 05:01:00+00'
);
set local session_replication_role = origin;

insert into public.horse_profile_change_events (
  stable_id, horse_id, actor_user_id, actor_membership_id,
  request_id, event_type, changed_fields, old_values, new_values, created_at
)
values (
  '4c2b2000-0000-0000-0000-000000000001',
  '4c2b6000-0000-0000-0000-000000000001',
  '4c2b1000-0000-0000-0000-000000000001',
  '4c2b5000-0000-0000-0000-000000000001',
  '4c2b7000-0000-0000-0000-000000000002',
  'horse_created',
  array['display_name']::text[],
  '{}'::jsonb,
  '{"display_name":"Upgrade Horse"}'::jsonb,
  '2026-07-27 05:01:00+00'
);

commit;
