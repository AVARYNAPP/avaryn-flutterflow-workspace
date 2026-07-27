begin;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000000',
  '4c6f1000-0000-0000-0000-000000000001',
  'authenticated', 'authenticated',
  '4c6-upgrade-owner@example.invalid', '', now(), '{}', '{}', now(), now()
);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values (
  '4c6f2000-0000-0000-0000-000000000001',
  'organization', '4C.6 upgrade control', 'active',
  'Europe/Amsterdam', 'nl',
  '4c6f1000-0000-0000-0000-000000000001',
  '4c6f3000-0000-0000-0000-000000000001'
);

insert into public.stable_members (
  id, stable_id, display_name, source
)
values (
  '4c6f4000-0000-0000-0000-000000000001',
  '4c6f2000-0000-0000-0000-000000000001',
  '4C.6 upgrade owner', 'owner_creation'
);

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values (
  '4c6f5000-0000-0000-0000-000000000001',
  '4c6f2000-0000-0000-0000-000000000001',
  '4c6f1000-0000-0000-0000-000000000001',
  '4c6f4000-0000-0000-0000-000000000001',
  'owner', 'active', '2026-07-27 06:00:00+00'
);

insert into public.horses (
  id, stable_id, display_name, source_kind,
  created_by_user_id, created_request_id
)
values (
  '4c6f6000-0000-0000-0000-000000000001',
  '4c6f2000-0000-0000-0000-000000000001',
  '4C.6 Upgrade Horse', 'manual',
  '4c6f1000-0000-0000-0000-000000000001',
  '4c6f7000-0000-0000-0000-000000000001'
);

insert into public.horse_profile_change_events (
  stable_id, horse_id, actor_user_id, actor_membership_id,
  request_id, event_type, changed_fields, old_values, new_values
)
values (
  '4c6f2000-0000-0000-0000-000000000001',
  '4c6f6000-0000-0000-0000-000000000001',
  '4c6f1000-0000-0000-0000-000000000001',
  '4c6f5000-0000-0000-0000-000000000001',
  '4c6f8000-0000-0000-0000-000000000001',
  'horse_created',
  array['status', 'display_name']::text[],
  '{}'::jsonb,
  '{"status":"active","display_name":"4C.6 Upgrade Horse"}'::jsonb
);

commit;
