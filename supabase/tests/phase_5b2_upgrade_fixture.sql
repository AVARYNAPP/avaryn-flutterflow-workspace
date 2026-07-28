begin;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000000',
  'b52a0000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  'phase5b2-upgrade-owner@example.invalid',
  '',
  '2026-07-28T09:00:00Z',
  '{}',
  '{}',
  '2026-07-28T09:00:00Z',
  '2026-07-28T09:00:00Z'
);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values (
  'b52b0000-0000-0000-0000-000000000001',
  'organization',
  'Phase 5B.2 upgrade preservation',
  'active',
  'UTC',
  'nl',
  'b52a0000-0000-0000-0000-000000000001',
  'b52c0000-0000-0000-0000-000000000001'
);

insert into public.stable_members (
  id, stable_id, display_name, source
)
values (
  'b52d0000-0000-0000-0000-000000000001',
  'b52b0000-0000-0000-0000-000000000001',
  'Upgrade owner',
  'owner_creation'
);

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values (
  'b52e0000-0000-0000-0000-000000000001',
  'b52b0000-0000-0000-0000-000000000001',
  'b52a0000-0000-0000-0000-000000000001',
  'b52d0000-0000-0000-0000-000000000001',
  'owner',
  'active',
  '2026-07-28T09:00:00Z'
);

insert into public.horses (
  id, stable_id, display_name, sex, source_kind,
  created_by_user_id, created_request_id
)
values (
  'b52f0000-0000-0000-0000-000000000001',
  'b52b0000-0000-0000-0000-000000000001',
  'Upgrade preserved Horse',
  'mare',
  'manual',
  'b52a0000-0000-0000-0000-000000000001',
  'b5300000-0000-0000-0000-000000000001'
);

commit;
