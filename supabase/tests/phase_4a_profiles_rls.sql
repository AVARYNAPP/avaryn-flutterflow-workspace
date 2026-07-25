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
  );

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
end;
$$;

rollback;
