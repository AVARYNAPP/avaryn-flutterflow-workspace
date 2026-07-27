begin;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at
)
values (
  '00000000-0000-0000-0000-000000000000',
  '4c3d1000-0000-0000-0000-000000000001',
  'authenticated',
  'authenticated',
  '4c3-upgrade-owner@example.invalid',
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
  '4c3d2000-0000-0000-0000-000000000001',
  'organization',
  '4C.3 upgrade control',
  'active',
  'Europe/Amsterdam',
  'nl',
  '4c3d1000-0000-0000-0000-000000000001',
  '4c3d3000-0000-0000-0000-000000000001'
);

insert into public.stable_members (
  id, stable_id, display_name, source
)
values (
  '4c3d4000-0000-0000-0000-000000000001',
  '4c3d2000-0000-0000-0000-000000000001',
  '4C.3 upgrade owner',
  'owner_creation'
);

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values (
  '4c3d5000-0000-0000-0000-000000000001',
  '4c3d2000-0000-0000-0000-000000000001',
  '4c3d1000-0000-0000-0000-000000000001',
  '4c3d4000-0000-0000-0000-000000000001',
  'owner',
  'active',
  '2026-07-27 06:00:00+00'
);

set constraints all immediate;

insert into public.horses (
  id, stable_id, display_name, source_kind,
  created_by_user_id, created_request_id
)
values (
  '4c3d6000-0000-0000-0000-000000000001',
  '4c3d2000-0000-0000-0000-000000000001',
  '4C.3 Upgrade Horse',
  'manual',
  '4c3d1000-0000-0000-0000-000000000001',
  '4c3d7000-0000-0000-0000-000000000001'
);

insert into public.horse_profile_change_events (
  stable_id, horse_id, actor_user_id, actor_membership_id,
  request_id, event_type, changed_fields, old_values, new_values
)
values (
  '4c3d2000-0000-0000-0000-000000000001',
  '4c3d6000-0000-0000-0000-000000000001',
  '4c3d1000-0000-0000-0000-000000000001',
  '4c3d5000-0000-0000-0000-000000000001',
  '4c3d7000-0000-0000-0000-000000000002',
  'horse_created',
  array['display_name']::text[],
  '{}'::jsonb,
  '{"display_name":"4C.3 Upgrade Horse"}'::jsonb
);

insert into public.horse_identifiers (
  id, stable_id, horse_id, identifier_type, identifier_value,
  source_kind, verification_status,
  created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c3d8000-0000-0000-0000-000000000001',
  '4c3d2000-0000-0000-0000-000000000001',
  '4c3d6000-0000-0000-0000-000000000001',
  'passport',
  'UPGRADE-PASSPORT-001',
  'user',
  'unverified',
  '4c3d1000-0000-0000-0000-000000000001',
  '4c3d9000-0000-0000-0000-000000000001',
  '4c3d1000-0000-0000-0000-000000000001',
  '4c3d9000-0000-0000-0000-000000000001'
);

insert into private.horse_identifier_mutation_receipts (
  actor_user_id,
  request_id,
  horse_id,
  identifier_id,
  operation,
  payload_hash
)
values (
  '4c3d1000-0000-0000-0000-000000000001',
  '4c3d9000-0000-0000-0000-000000000001',
  '4c3d6000-0000-0000-0000-000000000001',
  '4c3d8000-0000-0000-0000-000000000001',
  'create',
  extensions.digest(convert_to('upgrade-identifier', 'UTF8'), 'sha256')
);

insert into public.horse_relationships (
  id, stable_id, horse_id, stable_member_id, relationship_type,
  valid_from, created_by_user_id, created_request_id
)
values (
  '4c3da000-0000-0000-0000-000000000001',
  '4c3d2000-0000-0000-0000-000000000001',
  '4c3d6000-0000-0000-0000-000000000001',
  '4c3d4000-0000-0000-0000-000000000001',
  'owner',
  '2026-07-27',
  '4c3d1000-0000-0000-0000-000000000001',
  '4c3db000-0000-0000-0000-000000000001'
);

insert into private.horse_relationship_mutation_receipts (
  actor_user_id,
  request_id,
  horse_id,
  relationship_id,
  stable_member_id,
  relationship_type,
  payload_hash
)
values (
  '4c3d1000-0000-0000-0000-000000000001',
  '4c3db000-0000-0000-0000-000000000001',
  '4c3d6000-0000-0000-0000-000000000001',
  '4c3da000-0000-0000-0000-000000000001',
  '4c3d4000-0000-0000-0000-000000000001',
  'owner',
  extensions.digest(convert_to('upgrade-relationship', 'UTF8'), 'sha256')
);

commit;
