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
  '2026-07-28T10:00:00Z',
  '{}',
  '{}',
  '2026-07-28T10:00:00Z',
  '2026-07-28T10:00:00Z'
from (
  values
    ('b5410000-0000-0000-0000-000000000001', 'phase5b4-owner@example.invalid'),
    ('b5410000-0000-0000-0000-000000000002', 'phase5b4-admin@example.invalid'),
    ('b5410000-0000-0000-0000-000000000003', 'phase5b4-member@example.invalid'),
    ('b5410000-0000-0000-0000-000000000004', 'phase5b4-viewer@example.invalid'),
    ('b5410000-0000-0000-0000-000000000005', 'phase5b4-outsider@example.invalid')
) as fixture(id, email);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values (
  'b5420000-0000-0000-0000-000000000001',
  'organization',
  'Phase 5B.4 fictive media stable',
  'active',
  'Europe/Amsterdam',
  'nl',
  'b5410000-0000-0000-0000-000000000001',
  'b5430000-0000-0000-0000-000000000001'
);

insert into public.stable_members (
  id, stable_id, display_name, function_title, source
)
values
  (
    'b5440000-0000-0000-0000-000000000001',
    'b5420000-0000-0000-0000-000000000001',
    'Fictive Media Owner',
    'Owner',
    'owner_creation'
  ),
  (
    'b5440000-0000-0000-0000-000000000002',
    'b5420000-0000-0000-0000-000000000001',
    'Fictive Media Admin',
    'Admin',
    'manual'
  ),
  (
    'b5440000-0000-0000-0000-000000000003',
    'b5420000-0000-0000-0000-000000000001',
    'Fictive Media Member',
    'Groom',
    'manual'
  ),
  (
    'b5440000-0000-0000-0000-000000000004',
    'b5420000-0000-0000-0000-000000000001',
    'Fictive Media Viewer',
    'Observer',
    'manual'
  );

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values
  (
    'b5450000-0000-0000-0000-000000000001',
    'b5420000-0000-0000-0000-000000000001',
    'b5410000-0000-0000-0000-000000000001',
    'b5440000-0000-0000-0000-000000000001',
    'owner',
    'active',
    '2026-07-28T10:00:00Z'
  ),
  (
    'b5450000-0000-0000-0000-000000000002',
    'b5420000-0000-0000-0000-000000000001',
    'b5410000-0000-0000-0000-000000000002',
    'b5440000-0000-0000-0000-000000000002',
    'admin',
    'active',
    '2026-07-28T10:00:00Z'
  ),
  (
    'b5450000-0000-0000-0000-000000000003',
    'b5420000-0000-0000-0000-000000000001',
    'b5410000-0000-0000-0000-000000000003',
    'b5440000-0000-0000-0000-000000000003',
    'member',
    'active',
    '2026-07-28T10:00:00Z'
  ),
  (
    'b5450000-0000-0000-0000-000000000004',
    'b5420000-0000-0000-0000-000000000001',
    'b5410000-0000-0000-0000-000000000004',
    'b5440000-0000-0000-0000-000000000004',
    'viewer',
    'active',
    '2026-07-28T10:00:00Z'
  );

insert into public.horses (
  id, stable_id, display_name, source_kind,
  created_by_user_id, created_request_id
)
values (
  'b5460000-0000-0000-0000-000000000001',
  'b5420000-0000-0000-0000-000000000001',
  'Fictive Media Horse',
  'manual',
  'b5410000-0000-0000-0000-000000000001',
  'b5470000-0000-0000-0000-000000000001'
);

insert into public.horse_access_grants (
  stable_id, horse_id, membership_id, category,
  can_view, can_execute, can_edit, can_manage,
  granted_by_user_id, granted_request_id
)
values
  (
    'b5420000-0000-0000-0000-000000000001',
    'b5460000-0000-0000-0000-000000000001',
    'b5450000-0000-0000-0000-000000000003',
    'horse.basic', true, false, false, false,
    'b5410000-0000-0000-0000-000000000001',
    'b5480000-0000-0000-0000-000000000001'
  ),
  (
    'b5420000-0000-0000-0000-000000000001',
    'b5460000-0000-0000-0000-000000000001',
    'b5450000-0000-0000-0000-000000000004',
    'horse.basic', true, false, false, false,
    'b5410000-0000-0000-0000-000000000001',
    'b5480000-0000-0000-0000-000000000002'
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
    raise exception 'Phase 5B.4 capability RPC privileges are incorrect';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  'b5410000-0000-0000-0000-000000000001',
  true
);

do $$
declare
  capabilities jsonb;
begin
  capabilities := public.get_horse_capabilities(
    'b5460000-0000-0000-0000-000000000001'
  );
  if (capabilities ->> 'can_view_media')::boolean is not true
    or (capabilities ->> 'can_edit_media')::boolean is not true
    or (capabilities ->> 'can_manage_media_access')::boolean is not true
  then
    raise exception 'Owner media capability summary is incomplete: %',
      capabilities;
  end if;
end;
$$;

do $$
begin
  perform public.grant_horse_access(
    'b5460000-0000-0000-0000-000000000001',
    'b5450000-0000-0000-0000-000000000003',
    'horse.media',
    true,
    false,
    true,
    false,
    null,
    null,
    'Fictive member needs private media upload for Alpha acceptance',
    'b5490000-0000-4000-8000-000000000001'
  );
  perform public.grant_horse_access(
    'b5460000-0000-0000-0000-000000000001',
    'b5450000-0000-0000-0000-000000000004',
    'horse.media',
    true,
    false,
    false,
    false,
    null,
    null,
    'Fictive viewer needs read-only media for Alpha acceptance',
    'b5490000-0000-4000-8000-000000000002'
  );
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  'b5410000-0000-0000-0000-000000000002',
  true
);
do $$
declare
  capabilities jsonb;
begin
  capabilities := public.get_horse_capabilities(
    'b5460000-0000-0000-0000-000000000001'
  );
  if (capabilities ->> 'can_view_media')::boolean is not false
    or (capabilities ->> 'can_edit_media')::boolean is not false
    or (capabilities ->> 'can_manage_media_access')::boolean is not false
  then
    raise exception 'Admin received implicit private media authority: %',
      capabilities;
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  'b5410000-0000-0000-0000-000000000003',
  true
);
do $$
declare
  capabilities jsonb;
begin
  capabilities := public.get_horse_capabilities(
    'b5460000-0000-0000-0000-000000000001'
  );
  if (capabilities ->> 'can_view_media')::boolean is not true
    or (capabilities ->> 'can_edit_media')::boolean is not true
    or (capabilities ->> 'can_manage_media_access')::boolean is not false
  then
    raise exception 'Member media edit capability is incorrect: %',
      capabilities;
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  'b5410000-0000-0000-0000-000000000004',
  true
);
do $$
declare
  capabilities jsonb;
begin
  capabilities := public.get_horse_capabilities(
    'b5460000-0000-0000-0000-000000000001'
  );
  if (capabilities ->> 'can_view_media')::boolean is not true
    or (capabilities ->> 'can_edit_media')::boolean is not false
  then
    raise exception 'Viewer media capability is incorrect: %', capabilities;
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  'b5410000-0000-0000-0000-000000000001',
  true
);
do $$
begin
  perform public.revoke_horse_access(
    'b5460000-0000-0000-0000-000000000001',
    'b5450000-0000-0000-0000-000000000003',
    'horse.media',
    'b5490000-0000-4000-8000-000000000003'
  );
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  'b5410000-0000-0000-0000-000000000003',
  true
);
do $$
declare
  capabilities jsonb;
begin
  capabilities := public.get_horse_capabilities(
    'b5460000-0000-0000-0000-000000000001'
  );
  if (capabilities ->> 'can_view_media')::boolean is not false
    or (capabilities ->> 'can_edit_media')::boolean is not false
  then
    raise exception 'Revoked member retained private media capability: %',
      capabilities;
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  'b5410000-0000-0000-0000-000000000005',
  true
);
do $$
begin
  begin
    perform public.get_horse_capabilities(
      'b5460000-0000-0000-0000-000000000001'
    );
    raise exception 'Outsider received a Horse media object oracle';
  exception when insufficient_privilege then
    if sqlerrm <> 'HORSE_UNAVAILABLE' then raise; end if;
  end;
end;
$$;

reset role;
rollback;
