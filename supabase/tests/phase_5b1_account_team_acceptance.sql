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

-- Deterministic, fictive Phase 5B.1 fixtures. The transaction always rolls
-- back and must only be invoked through the local-only test runner.
insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    'b5100000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'phase5b1-new@example.invalid',
    '',
    '2026-07-27T08:00:00Z',
    '{"provider":"email","providers":["email"]}',
    '{"given_name":"Nieuw"}',
    '2026-07-27T08:00:00Z',
    '2026-07-27T08:00:00Z'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b5100000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'phase5b1-owner-a@example.invalid',
    '',
    '2026-07-27T08:00:00Z',
    '{"provider":"email","providers":["email"]}',
    '{"given_name":"Owner","family_name":"Alpha"}',
    '2026-07-27T08:00:00Z',
    '2026-07-27T08:00:00Z'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b5100000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'phase5b1-member-a@example.invalid',
    '',
    '2026-07-27T08:00:00Z',
    '{"provider":"email","providers":["email"]}',
    '{"given_name":"Member","family_name":"Alpha"}',
    '2026-07-27T08:00:00Z',
    '2026-07-27T08:00:00Z'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b5100000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'phase5b1-removed-a@example.invalid',
    '',
    '2026-07-27T08:00:00Z',
    '{"provider":"email","providers":["email"]}',
    '{"given_name":"Removed","family_name":"Alpha"}',
    '2026-07-27T08:00:00Z',
    '2026-07-27T08:00:00Z'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b5200000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'phase5b1-owner-b@example.invalid',
    '',
    '2026-07-27T08:00:00Z',
    '{"provider":"email","providers":["email"]}',
    '{"given_name":"Owner","family_name":"Beta"}',
    '2026-07-27T08:00:00Z',
    '2026-07-27T08:00:00Z'
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    'b5300000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'phase5b1-outsider@example.invalid',
    '',
    '2026-07-27T08:00:00Z',
    '{"provider":"email","providers":["email"]}',
    '{"given_name":"Outsider"}',
    '2026-07-27T08:00:00Z',
    '2026-07-27T08:00:00Z'
  );

update public.profiles
set
  first_name = case
    when id = 'b5100000-0000-0000-0000-000000000001' then null
    else first_name
  end,
  onboarding_intent = case
    when id = 'b5100000-0000-0000-0000-000000000001' then null
    else 'createStable'
  end,
  onboarding_completed_at = case
    when id = 'b5100000-0000-0000-0000-000000000001' then null
    else '2026-07-27T08:15:00Z'::timestamptz
  end,
  avatar_object_path = case
    when id = 'b5100000-0000-0000-0000-000000000002'
      then 'b5100000-0000-0000-0000-000000000002/avatar.png'
    else null
  end
where id in (
  'b5100000-0000-0000-0000-000000000001',
  'b5100000-0000-0000-0000-000000000002',
  'b5100000-0000-0000-0000-000000000003',
  'b5100000-0000-0000-0000-000000000004',
  'b5200000-0000-0000-0000-000000000001',
  'b5300000-0000-0000-0000-000000000001'
);

insert into public.stables (
  id,
  kind,
  name,
  status,
  timezone,
  locale,
  created_by_user_id,
  creation_request_id
)
values
  (
    'b5400000-0000-0000-0000-000000000001',
    'organization',
    'Fictieve Alpha stal',
    'active',
    'Europe/Amsterdam',
    'nl',
    'b5100000-0000-0000-0000-000000000002',
    'b5500000-0000-0000-0000-000000000001'
  ),
  (
    'b5400000-0000-0000-0000-000000000002',
    'organization',
    'Fictieve Beta stal',
    'active',
    'Europe/Amsterdam',
    'nl',
    'b5200000-0000-0000-0000-000000000001',
    'b5500000-0000-0000-0000-000000000002'
  );

insert into public.stable_members (
  id,
  stable_id,
  display_name,
  function_title,
  source
)
values
  (
    'b5600000-0000-0000-0000-000000000001',
    'b5400000-0000-0000-0000-000000000001',
    'Owner Alpha',
    'Eigenaar',
    'owner_creation'
  ),
  (
    'b5600000-0000-0000-0000-000000000002',
    'b5400000-0000-0000-0000-000000000001',
    'Member Alpha',
    'Groom',
    'manual'
  ),
  (
    'b5600000-0000-0000-0000-000000000003',
    'b5400000-0000-0000-0000-000000000001',
    'Removed Alpha',
    null,
    'manual'
  ),
  (
    'b5600000-0000-0000-0000-000000000004',
    'b5400000-0000-0000-0000-000000000002',
    'Owner Beta',
    'Eigenaar',
    'owner_creation'
  );

insert into public.stable_memberships (
  id,
  stable_id,
  user_id,
  stable_member_id,
  role,
  status,
  joined_at,
  ended_at,
  ended_reason
)
values
  (
    'b5700000-0000-0000-0000-000000000001',
    'b5400000-0000-0000-0000-000000000001',
    'b5100000-0000-0000-0000-000000000002',
    'b5600000-0000-0000-0000-000000000001',
    'owner',
    'active',
    '2026-07-27T08:20:00Z',
    null,
    null
  ),
  (
    'b5700000-0000-0000-0000-000000000002',
    'b5400000-0000-0000-0000-000000000001',
    'b5100000-0000-0000-0000-000000000003',
    'b5600000-0000-0000-0000-000000000002',
    'member',
    'active',
    '2026-07-27T08:20:00Z',
    null,
    null
  ),
  (
    'b5700000-0000-0000-0000-000000000003',
    'b5400000-0000-0000-0000-000000000001',
    'b5100000-0000-0000-0000-000000000004',
    'b5600000-0000-0000-0000-000000000003',
    'member',
    'removed',
    '2026-07-27T08:20:00Z',
    '2026-07-27T09:00:00Z',
    'phase5b1_fixture'
  ),
  (
    'b5700000-0000-0000-0000-000000000004',
    'b5400000-0000-0000-0000-000000000002',
    'b5200000-0000-0000-0000-000000000001',
    'b5600000-0000-0000-0000-000000000004',
    'owner',
    'active',
    '2026-07-27T08:20:00Z',
    null,
    null
  );

insert into public.account_workspace_preferences (
  user_id,
  last_selected_stable_id,
  workspace_mode,
  phase_4b_status,
  intent_consumed_at
)
values
  (
    'b5100000-0000-0000-0000-000000000002',
    'b5400000-0000-0000-0000-000000000001',
    'stable',
    'active',
    '2026-07-27T08:20:00Z'
  ),
  (
    'b5100000-0000-0000-0000-000000000004',
    null,
    'stable',
    'access_lost',
    '2026-07-27T08:20:00Z'
  );

insert into public.stable_invitations (
  id,
  stable_id,
  invited_email,
  offered_role,
  token_hash,
  status,
  expires_at,
  invited_by_membership_id
)
values (
  'b5800000-0000-0000-0000-000000000001',
  'b5400000-0000-0000-0000-000000000001',
  'phase5b1-new@example.invalid',
  'viewer',
  decode(
    '5151515151515151515151515151515151515151515151515151515151515151',
    'hex'
  ),
  'pending',
  '2026-08-27T08:20:00Z',
  'b5700000-0000-0000-0000-000000000001'
);

set constraints all immediate;
set constraints all deferred;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  'b5100000-0000-0000-0000-000000000001',
  true
);

do $$
declare
  preview jsonb;
  acceptance jsonb;
begin
  if (
    select onboarding_completed_at is not null
    from public.profiles
    where id = auth.uid()
  ) then
    raise exception 'Incomplete account bypassed onboarding';
  end if;
  if (select count(*) from public.stables) <> 0 then
    raise exception 'Incomplete account inherited a stable';
  end if;

  preview := public.resume_stable_invitation(
    'b5800000-0000-0000-0000-000000000001'
  );
  if preview ->> 'status' <> 'pending'
    or preview ->> 'invitation_id'
      <> 'b5800000-0000-0000-0000-000000000001'
  then
    raise exception 'Confirmed invitee could not resume by non-secret ID';
  end if;

  acceptance := public.accept_stable_invitation_by_id(
    'b5800000-0000-0000-0000-000000000001',
    'Fictieve nieuwe gebruiker',
    'Ruiter',
    'b5900000-0000-0000-0000-000000000001'
  );
  if acceptance ->> 'stable_id'
    <> 'b5400000-0000-0000-0000-000000000001'
  then
    raise exception 'Resumed invitation acceptance selected wrong stable';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  'b5100000-0000-0000-0000-000000000002',
  true
);

do $$
begin
  if not (
    select onboarding_completed_at is not null
      and onboarding_intent = 'createStable'
    from public.profiles
    where id = auth.uid()
  ) then
    raise exception 'Completed owner profile lost onboarding state';
  end if;
  if (select count(*) from public.stables) <> 1 then
    raise exception 'Owner Alpha did not see exactly one stable';
  end if;
  if (
    select count(*)
    from public.list_stable_member_directory(
      'b5400000-0000-0000-0000-000000000001'
    )
  ) <> 4 then
    raise exception 'Owner Alpha directory is incomplete';
  end if;
  if exists (
    select 1
    from public.stables
    where id = 'b5400000-0000-0000-0000-000000000002'
  ) then
    raise exception 'Owner Alpha crossed the stable boundary';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  'b5100000-0000-0000-0000-000000000004',
  true
);

do $$
begin
  if (select count(*) from public.stables) <> 0 then
    raise exception 'Removed member retained stable visibility';
  end if;
  if (select count(*) from public.stable_members) <> 0 then
    raise exception 'Removed member retained team visibility';
  end if;
  if (
    select phase_4b_status
    from public.account_workspace_preferences
    where user_id = auth.uid()
  ) <> 'access_lost' then
    raise exception 'Removed member lost the access-lost state';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  'b5300000-0000-0000-0000-000000000001',
  true
);

do $$
begin
  if (select count(*) from public.stables) <> 0 then
    raise exception 'Outsider saw a stable';
  end if;
  if (select count(*) from public.stable_memberships) <> 0 then
    raise exception 'Outsider saw a membership';
  end if;
  if public.resume_stable_invitation(
    'b5800000-0000-0000-0000-000000000001'
  ) ->> 'status' <> 'unavailable' then
    raise exception 'Outsider resumed an invitation for another email';
  end if;
end;
$$;

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'anon', true);

do $$
begin
  begin
    perform count(*) from public.profiles;
    raise exception 'Anonymous profile read succeeded';
  exception
    when insufficient_privilege then
      null;
  end;
end;
$$;

rollback;
