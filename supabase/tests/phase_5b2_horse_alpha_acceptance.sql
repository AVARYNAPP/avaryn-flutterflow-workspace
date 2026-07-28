\if :{?avaryn_local_test}
\else
  \echo 'Refusing to run: pass -v avaryn_local_test=1 against the local test database.'
  \quit
\endif
\set QUIET 1
select :'avaryn_local_test' = '1' as avaryn_local_guard \gset
\set QUIET 0
\if :avaryn_local_guard
\else
  \echo 'Refusing to run: avaryn_local_test must equal 1.'
  \quit
\endif

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
  '2026-07-28T08:00:00Z',
  '{}',
  '{}',
  '2026-07-28T08:00:00Z',
  '2026-07-28T08:00:00Z'
from (
  values
    ('b5210000-0000-0000-0000-000000000001', 'phase5b2-owner@example.invalid'),
    ('b5210000-0000-0000-0000-000000000002', 'phase5b2-admin@example.invalid'),
    ('b5210000-0000-0000-0000-000000000003', 'phase5b2-member@example.invalid'),
    ('b5210000-0000-0000-0000-000000000004', 'phase5b2-viewer@example.invalid'),
    ('b5210000-0000-0000-0000-000000000005', 'phase5b2-outsider@example.invalid')
) as fixture(id, email);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values (
  'b5220000-0000-0000-0000-000000000001',
  'organization',
  'Phase 5B.2 fictive stable',
  'active',
  'Europe/Amsterdam',
  'nl',
  'b5210000-0000-0000-0000-000000000001',
  'b5230000-0000-0000-0000-000000000001'
);

insert into public.stable_members (
  id, stable_id, display_name, function_title, source
)
values
  (
    'b5240000-0000-0000-0000-000000000001',
    'b5220000-0000-0000-0000-000000000001',
    'Fictive Owner',
    'Owner',
    'owner_creation'
  ),
  (
    'b5240000-0000-0000-0000-000000000002',
    'b5220000-0000-0000-0000-000000000001',
    'Fictive Admin',
    'Admin',
    'manual'
  ),
  (
    'b5240000-0000-0000-0000-000000000003',
    'b5220000-0000-0000-0000-000000000001',
    'Fictive Member',
    'Groom',
    'manual'
  ),
  (
    'b5240000-0000-0000-0000-000000000004',
    'b5220000-0000-0000-0000-000000000001',
    'Fictive Viewer',
    'Owner observer',
    'manual'
  );

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values
  (
    'b5250000-0000-0000-0000-000000000001',
    'b5220000-0000-0000-0000-000000000001',
    'b5210000-0000-0000-0000-000000000001',
    'b5240000-0000-0000-0000-000000000001',
    'owner',
    'active',
    '2026-07-28T08:00:00Z'
  ),
  (
    'b5250000-0000-0000-0000-000000000002',
    'b5220000-0000-0000-0000-000000000001',
    'b5210000-0000-0000-0000-000000000002',
    'b5240000-0000-0000-0000-000000000002',
    'admin',
    'active',
    '2026-07-28T08:00:00Z'
  ),
  (
    'b5250000-0000-0000-0000-000000000003',
    'b5220000-0000-0000-0000-000000000001',
    'b5210000-0000-0000-0000-000000000003',
    'b5240000-0000-0000-0000-000000000003',
    'member',
    'active',
    '2026-07-28T08:00:00Z'
  ),
  (
    'b5250000-0000-0000-0000-000000000004',
    'b5220000-0000-0000-0000-000000000001',
    'b5210000-0000-0000-0000-000000000004',
    'b5240000-0000-0000-0000-000000000004',
    'viewer',
    'active',
    '2026-07-28T08:00:00Z'
  );

insert into public.horses (
  id, stable_id, display_name, official_name, sex, source_kind,
  created_by_user_id, created_request_id
)
values (
  'b5260000-0000-0000-0000-000000000001',
  'b5220000-0000-0000-0000-000000000001',
  'Fictive Alpha Horse',
  'Fictive Alpha Horse Official',
  'gelding',
  'manual',
  'b5210000-0000-0000-0000-000000000001',
  'b5270000-0000-0000-0000-000000000001'
);

do $$
begin
  if has_function_privilege(
    'anon',
    'public.get_horse_capabilities(uuid)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'public.get_horse_capabilities(uuid)',
    'EXECUTE'
  ) then
    raise exception 'Phase 5B.2 capability RPC privileges are incorrect';
  end if;
end;
$$;

set local role authenticated;

select set_config(
  'request.jwt.claim.sub',
  'b5210000-0000-0000-0000-000000000001',
  true
);
do $$
declare
  capabilities jsonb;
begin
  capabilities := public.get_horse_capabilities(
    'b5260000-0000-0000-0000-000000000001'
  );
  if capabilities ->> 'role' <> 'owner'
    or (capabilities ->> 'membership_id')::uuid <>
      'b5250000-0000-0000-0000-000000000001'
    or (capabilities ->> 'can_edit_profile')::boolean is not true
    or (capabilities ->> 'can_archive')::boolean is not true
    or (capabilities ->> 'can_manage_basic_access')::boolean is not true
    or (capabilities ->> 'can_manage_schedule_access')::boolean is not true
    or (capabilities ->> 'can_manage_relationships')::boolean is not true
  then
    raise exception 'Owner Horse capability summary is incomplete: %',
      capabilities;
  end if;
end;
$$;

select public.grant_horse_access(
  'b5260000-0000-0000-0000-000000000001',
  'b5250000-0000-0000-0000-000000000003',
  'horse.basic',
  true,
  false,
  true,
  false,
  null,
  null,
  null,
  'b5280000-0000-0000-0000-000000000001'
);
select public.grant_horse_access(
  'b5260000-0000-0000-0000-000000000001',
  'b5250000-0000-0000-0000-000000000004',
  'horse.basic',
  true,
  false,
  false,
  false,
  null,
  null,
  null,
  'b5280000-0000-0000-0000-000000000002'
);

select set_config(
  'request.jwt.claim.sub',
  'b5210000-0000-0000-0000-000000000003',
  true
);
do $$
declare
  capabilities jsonb;
begin
  capabilities := public.get_horse_capabilities(
    'b5260000-0000-0000-0000-000000000001'
  );
  if capabilities ->> 'role' <> 'member'
    or (capabilities ->> 'can_edit_profile')::boolean is not true
    or (capabilities ->> 'can_archive')::boolean is not false
    or (capabilities ->> 'can_manage_basic_access')::boolean is not false
    or (capabilities ->> 'can_manage_relationships')::boolean is not false
  then
    raise exception 'Member Horse capability summary is incorrect: %',
      capabilities;
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  'b5210000-0000-0000-0000-000000000004',
  true
);
do $$
declare
  capabilities jsonb;
begin
  capabilities := public.get_horse_capabilities(
    'b5260000-0000-0000-0000-000000000001'
  );
  if capabilities ->> 'role' <> 'viewer'
    or (capabilities ->> 'can_edit_profile')::boolean is not false
    or (capabilities ->> 'can_archive')::boolean is not false
    or (capabilities ->> 'can_manage_basic_access')::boolean is not false
  then
    raise exception 'Viewer Horse capability summary is too broad: %',
      capabilities;
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  'b5210000-0000-0000-0000-000000000005',
  true
);
do $$
declare
  denied boolean := false;
begin
  begin
    perform public.get_horse_capabilities(
      'b5260000-0000-0000-0000-000000000001'
    );
  exception when insufficient_privilege then
    if sqlerrm <> 'HORSE_UNAVAILABLE' then raise; end if;
    denied := true;
  end;
  if not denied then
    raise exception 'Outsider received a Horse capability summary';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  'b5210000-0000-0000-0000-000000000001',
  true
);
select public.revoke_horse_access(
  'b5260000-0000-0000-0000-000000000001',
  'b5250000-0000-0000-0000-000000000003',
  'horse.basic',
  'b5290000-0000-0000-0000-000000000001'
);

select set_config(
  'request.jwt.claim.sub',
  'b5210000-0000-0000-0000-000000000003',
  true
);
do $$
declare
  denied boolean := false;
begin
  begin
    perform public.get_horse_capabilities(
      'b5260000-0000-0000-0000-000000000001'
    );
  exception when insufficient_privilege then
    if sqlerrm <> 'HORSE_UNAVAILABLE' then raise; end if;
    denied := true;
  end;
  if not denied then
    raise exception 'Revoked member retained Horse capability visibility';
  end if;
end;
$$;

reset role;
rollback;
