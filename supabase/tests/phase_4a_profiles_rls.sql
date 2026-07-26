begin;

-- Run only against an isolated local Supabase test database.
-- The transaction rolls every fixture back.
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
    '10000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'phase4a-a@example.invalid',
    '',
    now(),
    '{}',
    '{"given_name":"Gebruiker A"}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '20000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'phase4a-b@example.invalid',
    '',
    now(),
    '{}',
    '{"given_name":"Gebruiker B"}',
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '30000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'phase4a-c@example.invalid',
    '',
    now(),
    '{}',
    '{"given_name":"Gebruiker C"}',
    now(),
    now()
  );

-- Keep a valid auth UUID without a profile. This makes the cross-UUID insert
-- exercise the RLS check instead of the auth.users foreign key.
delete from public.profiles
where id = '30000000-0000-0000-0000-000000000003';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '10000000-0000-0000-0000-000000000001',
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $$
declare
  visible_count integer;
  changed_count integer;
begin
  select count(*) into visible_count from public.profiles;
  if visible_count <> 1 then
    raise exception 'RLS failure: own profile count was %, expected 1', visible_count;
  end if;

  select count(*) into visible_count
  from public.profiles
  where id = '20000000-0000-0000-0000-000000000002';
  if visible_count <> 0 then
    raise exception 'RLS failure: user A could read user B profile';
  end if;

  update public.profiles
  set first_name = 'Eigen'
  where id = '10000000-0000-0000-0000-000000000001';
  get diagnostics changed_count = row_count;
  if changed_count <> 1 then
    raise exception 'RLS failure: own profile update was blocked';
  end if;

  update public.profiles
  set first_name = 'Niet toegestaan'
  where id = '20000000-0000-0000-0000-000000000002';
  get diagnostics changed_count = row_count;
  if changed_count <> 0 then
    raise exception 'RLS failure: cross-user update succeeded';
  end if;

  begin
    insert into public.profiles (id, display_name)
    values (
      '30000000-0000-0000-0000-000000000003',
      'Niet toegestaan'
    );
    raise exception 'RLS failure: arbitrary cross-UUID profile insert succeeded';
  exception
    when insufficient_privilege then
      null;
  end;
end;
$$;

reset role;

do $$
begin
  begin
    insert into public.profiles (id, display_name)
    values (
      '10000000-0000-0000-0000-000000000001',
      'Dubbel profiel'
    );
    raise exception 'Uniqueness failure: duplicate profile insert succeeded';
  exception
    when unique_violation then
      null;
  end;
end;
$$;

set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'anon', true);

do $$
begin
  begin
    perform count(*) from public.profiles;
    raise exception 'RLS failure: anonymous profile read succeeded';
  exception
    when insufficient_privilege then
      null;
  end;

  begin
    update public.profiles
    set first_name = 'Anoniem'
    where id = '10000000-0000-0000-0000-000000000001';
    raise exception 'RLS failure: anonymous profile update succeeded';
  exception
    when insufficient_privilege then
      null;
  end;
end;
$$;

rollback;
