\set ON_ERROR_STOP on

\if :{?avaryn_local_test}
\else
  \echo 'Refusing browser fixture: avaryn_local_test is required.'
  select 1 / 0;
\endif

\getenv test_password AVARYN_BROWSER_TEST_PASSWORD

\if :{?test_password}
\else
  \echo 'Refusing browser fixture: secure password environment is missing.'
  select 1 / 0;
\endif

\set QUIET 1
select
  :'avaryn_local_test' = '1'
  and length(:'test_password') >= 20
  as phase_5d3_browser_guard
\gset
\set QUIET 0
\if :phase_5d3_browser_guard
\else
  \echo 'Refusing browser fixture: local guard or password length is invalid.'
  select 1 / 0;
\endif

begin;

update auth.users
set
  encrypted_password = crypt(:'test_password', gen_salt('bf')),
  confirmation_token = '',
  recovery_token = '',
  email_change_token_new = '',
  email_change = '',
  email_change_token_current = '',
  reauthentication_token = '',
  phone_change_token = '',
  updated_at = now()
where id in (
  '5c000000-0000-0000-0000-000000000001',
  '5c000000-0000-0000-0000-000000000006',
  '5c000000-0000-0000-0000-000000000009',
  '5c000000-0000-0000-0000-000000000011'
)
  and raw_app_meta_data @> '{"phase_5c_fixture":true}'::jsonb;

do $$
begin
  if (
    select count(*)
    from auth.users
    where id in (
      '5c000000-0000-0000-0000-000000000001',
      '5c000000-0000-0000-0000-000000000006',
      '5c000000-0000-0000-0000-000000000009',
      '5c000000-0000-0000-0000-000000000011'
    )
      and encrypted_password <> ''
      and raw_app_meta_data @> '{"phase_5c_fixture":true}'::jsonb
  ) <> 4 then
    raise exception 'Browser fixture did not update exactly four local users';
  end if;
end;
$$;

commit;

\unset test_password
\echo 'PASS: local browser users prepared without emitting credentials.'
