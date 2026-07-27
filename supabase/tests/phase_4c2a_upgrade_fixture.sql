begin;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000000',
  '4ca00000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'upgrade-owner@example.invalid',
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
  '4cb00000-0000-0000-0000-000000000001',
  'organization',
  '4C.2A upgrade control',
  'active',
  'UTC',
  'nl',
  '4ca00000-0000-0000-0000-000000000001',
  '4cc00000-0000-0000-0000-000000000001'
);

insert into public.stable_members (
  id, stable_id, display_name, source
)
values (
  '4cd00000-0000-0000-0000-000000000001',
  '4cb00000-0000-0000-0000-000000000001',
  'Upgrade owner',
  'owner_creation'
);

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values (
  '4ce00000-0000-0000-0000-000000000001',
  '4cb00000-0000-0000-0000-000000000001',
  '4ca00000-0000-0000-0000-000000000001',
  '4cd00000-0000-0000-0000-000000000001',
  'owner',
  'active',
  '2026-07-26 12:00:00+00'
);

set constraints all immediate;

insert into public.stable_security_events (
  stable_id,
  actor_user_id,
  actor_membership_id,
  event_type,
  request_id,
  metadata,
  created_at
)
values (
  '4cb00000-0000-0000-0000-000000000001',
  '4ca00000-0000-0000-0000-000000000001',
  '4ce00000-0000-0000-0000-000000000001',
  'stable_updated',
  '4cf00000-0000-0000-0000-000000000001',
  '{"upgrade_fixture":true}'::jsonb,
  '2026-07-26 12:01:00+00'
);

commit;
