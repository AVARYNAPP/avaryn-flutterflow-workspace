\set ON_ERROR_STOP on

\if :{?avaryn_local_test}
\else
  \echo 'Refusing to provision: avaryn_local_test is required.'
  select 1 / 0;
\endif
\if :{?profile}
\else
  \echo 'Refusing to provision: profile is required.'
  select 1 / 0;
\endif
\if :{?horse_count}
\else
  \echo 'Refusing to provision: horse_count is required.'
  select 1 / 0;
\endif
\if :{?routine_count}
\else
  \echo 'Refusing to provision: routine_count is required.'
  select 1 / 0;
\endif
\if :{?item_count}
\else
  \echo 'Refusing to provision: item_count is required.'
  select 1 / 0;
\endif
\if :{?media_count}
\else
  \echo 'Refusing to provision: media_count is required.'
  select 1 / 0;
\endif
\if :{?conflict_count}
\else
  \echo 'Refusing to provision: conflict_count is required.'
  select 1 / 0;
\endif

\set QUIET 1
select
  :'avaryn_local_test' = '1'
  and :'profile' in ('basis', 'medium', 'extreme', 'custom')
  and :'horse_count'::integer between 1 and 50
  and :'routine_count'::integer between 3 and 100
  and :'item_count'::integer between 6 and 500
  and :'media_count'::integer between 1 and 50
  and :'conflict_count'::integer between 1 and 25
  as phase_5c_guard
\gset
\set QUIET 0
\if :phase_5c_guard
\else
  \echo 'Refusing to provision: invalid local profile parameters.'
  select 1 / 0;
\endif

begin;

select set_config('avaryn.test_profile', :'profile', true);
select set_config('avaryn.horse_count', :'horse_count', true);
select set_config('avaryn.routine_count', :'routine_count', true);
select set_config('avaryn.item_count', :'item_count', true);
select set_config('avaryn.media_count', :'media_count', true);
select set_config('avaryn.conflict_count', :'conflict_count', true);

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
select
  '00000000-0000-0000-0000-000000000000',
  fixture.id::uuid,
  'authenticated',
  'authenticated',
  fixture.email,
  '',
  '2026-07-28T06:00:00Z'::timestamptz,
  '{"provider":"email","providers":["email"],"phase_5c_fixture":true}'::jsonb,
  jsonb_build_object(
    'given_name', fixture.given_name,
    'family_name', 'Fictief'
  ),
  '2026-07-28T06:00:00Z'::timestamptz,
  '2026-07-28T06:00:00Z'::timestamptz
from (
  values
    ('5c000000-0000-0000-0000-000000000001', 'test-owner-a@example.invalid', 'Owner A'),
    ('5c000000-0000-0000-0000-000000000002', 'test-rider-1@example.invalid', 'Ruiter Een'),
    ('5c000000-0000-0000-0000-000000000003', 'test-rider-2@example.invalid', 'Ruiter Twee'),
    ('5c000000-0000-0000-0000-000000000004', 'test-rider-3@example.invalid', 'Ruiter Drie'),
    ('5c000000-0000-0000-0000-000000000005', 'test-groom-1@example.invalid', 'Groom Een'),
    ('5c000000-0000-0000-0000-000000000006', 'test-groom-2@example.invalid', 'Groom Twee'),
    ('5c000000-0000-0000-0000-000000000007', 'test-trainer@example.invalid', 'Trainer'),
    ('5c000000-0000-0000-0000-000000000008', 'test-limited-owner@example.invalid', 'Beperkte Eigenaar'),
    ('5c000000-0000-0000-0000-000000000009', 'test-revoked@example.invalid', 'Ingetrokken'),
    ('5c000000-0000-0000-0000-000000000010', 'test-outsider@example.invalid', 'Buitenstaander'),
    ('5c000000-0000-0000-0000-000000000011', 'test-owner-b@example.invalid', 'Owner B')
) as fixture(id, email, given_name);

update public.profiles
set
  first_name = split_part(
    raw_user_meta_data->>'given_name',
    ' ',
    1
  ),
  last_name = 'Fictief',
  display_name = raw_user_meta_data->>'given_name',
  onboarding_intent = 'joinStable',
  onboarding_completed_at = '2026-07-28T06:15:00Z'::timestamptz,
  locale = 'nl'
from auth.users
where profiles.id = auth.users.id
  and auth.users.raw_app_meta_data @> '{"phase_5c_fixture":true}'::jsonb;

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
    '5ca00000-0000-0000-0000-000000000001',
    'organization',
    'AVARYN Test ' || initcap(:'profile'),
    'active',
    'Europe/Amsterdam',
    'nl',
    '5c000000-0000-0000-0000-000000000001',
    '5ca90000-0000-0000-0000-000000000001'
  ),
  (
    '5ca00000-0000-0000-0000-000000000002',
    'organization',
    'AVARYN Test Isolatie B',
    'active',
    'Europe/Brussels',
    'nl',
    '5c000000-0000-0000-0000-000000000011',
    '5ca90000-0000-0000-0000-000000000002'
  );

insert into public.stable_members (
  id,
  stable_id,
  display_name,
  function_title,
  status,
  source
)
select
  fixture.id::uuid,
  fixture.stable_id::uuid,
  fixture.display_name,
  fixture.function_title,
  fixture.status,
  fixture.source
from (
  values
    ('5cb00000-0000-0000-0000-000000000001', '5ca00000-0000-0000-0000-000000000001', 'Owner A', 'Staleigenaar', 'active', 'owner_creation'),
    ('5cb00000-0000-0000-0000-000000000002', '5ca00000-0000-0000-0000-000000000001', 'Ruiter Een', 'Ruiter en beheerder', 'active', 'manual'),
    ('5cb00000-0000-0000-0000-000000000003', '5ca00000-0000-0000-0000-000000000001', 'Ruiter Twee', 'Ruiter', 'active', 'manual'),
    ('5cb00000-0000-0000-0000-000000000004', '5ca00000-0000-0000-0000-000000000001', 'Ruiter Drie', 'Ruiter', 'active', 'manual'),
    ('5cb00000-0000-0000-0000-000000000005', '5ca00000-0000-0000-0000-000000000001', 'Groom Een', 'Groom', 'active', 'manual'),
    ('5cb00000-0000-0000-0000-000000000006', '5ca00000-0000-0000-0000-000000000001', 'Groom Twee', 'Groom', 'active', 'manual'),
    ('5cb00000-0000-0000-0000-000000000007', '5ca00000-0000-0000-0000-000000000001', 'Trainer', 'Trainer', 'active', 'manual'),
    ('5cb00000-0000-0000-0000-000000000008', '5ca00000-0000-0000-0000-000000000001', 'Beperkte Eigenaar', 'Paardeigenaar', 'active', 'manual'),
    ('5cb00000-0000-0000-0000-000000000009', '5ca00000-0000-0000-0000-000000000001', 'Ingetrokken gebruiker', 'Voormalig teamlid', 'inactive', 'manual'),
    ('5cb00000-0000-0000-0000-000000000011', '5ca00000-0000-0000-0000-000000000002', 'Owner B', 'Staleigenaar', 'active', 'owner_creation'),
    ('5cb00000-0000-0000-0000-000000000012', '5ca00000-0000-0000-0000-000000000002', 'Ruiter Een', 'Gast in tweede stal', 'active', 'manual')
) as fixture(id, stable_id, display_name, function_title, status, source);

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
select
  fixture.id::uuid,
  fixture.stable_id::uuid,
  fixture.user_id::uuid,
  fixture.member_id::uuid,
  fixture.role,
  fixture.status,
  '2026-07-28T06:30:00Z'::timestamptz,
  case
    when fixture.status = 'active' then null
    else '2026-07-28T07:00:00Z'::timestamptz
  end,
  case
    when fixture.status = 'active' then null
    else 'phase_5c_revoked_fixture'
  end
from (
  values
    ('5cc00000-0000-0000-0000-000000000001', '5ca00000-0000-0000-0000-000000000001', '5c000000-0000-0000-0000-000000000001', '5cb00000-0000-0000-0000-000000000001', 'owner', 'active'),
    ('5cc00000-0000-0000-0000-000000000002', '5ca00000-0000-0000-0000-000000000001', '5c000000-0000-0000-0000-000000000002', '5cb00000-0000-0000-0000-000000000002', 'admin', 'active'),
    ('5cc00000-0000-0000-0000-000000000003', '5ca00000-0000-0000-0000-000000000001', '5c000000-0000-0000-0000-000000000003', '5cb00000-0000-0000-0000-000000000003', 'member', 'active'),
    ('5cc00000-0000-0000-0000-000000000004', '5ca00000-0000-0000-0000-000000000001', '5c000000-0000-0000-0000-000000000004', '5cb00000-0000-0000-0000-000000000004', 'member', 'active'),
    ('5cc00000-0000-0000-0000-000000000005', '5ca00000-0000-0000-0000-000000000001', '5c000000-0000-0000-0000-000000000005', '5cb00000-0000-0000-0000-000000000005', 'member', 'active'),
    ('5cc00000-0000-0000-0000-000000000006', '5ca00000-0000-0000-0000-000000000001', '5c000000-0000-0000-0000-000000000006', '5cb00000-0000-0000-0000-000000000006', 'member', 'active'),
    ('5cc00000-0000-0000-0000-000000000007', '5ca00000-0000-0000-0000-000000000001', '5c000000-0000-0000-0000-000000000007', '5cb00000-0000-0000-0000-000000000007', 'member', 'active'),
    ('5cc00000-0000-0000-0000-000000000008', '5ca00000-0000-0000-0000-000000000001', '5c000000-0000-0000-0000-000000000008', '5cb00000-0000-0000-0000-000000000008', 'viewer', 'active'),
    ('5cc00000-0000-0000-0000-000000000009', '5ca00000-0000-0000-0000-000000000001', '5c000000-0000-0000-0000-000000000009', '5cb00000-0000-0000-0000-000000000009', 'viewer', 'removed'),
    ('5cc00000-0000-0000-0000-000000000011', '5ca00000-0000-0000-0000-000000000002', '5c000000-0000-0000-0000-000000000011', '5cb00000-0000-0000-0000-000000000011', 'owner', 'active'),
    ('5cc00000-0000-0000-0000-000000000012', '5ca00000-0000-0000-0000-000000000002', '5c000000-0000-0000-0000-000000000002', '5cb00000-0000-0000-0000-000000000012', 'viewer', 'active')
) as fixture(id, stable_id, user_id, member_id, role, status);

set constraints all immediate;

insert into public.account_workspace_preferences (
  user_id,
  last_selected_stable_id,
  workspace_mode,
  phase_4b_status,
  intent_consumed_at
)
values
  ('5c000000-0000-0000-0000-000000000001', '5ca00000-0000-0000-0000-000000000001', 'stable', 'active', '2026-07-28T06:30:00Z'),
  ('5c000000-0000-0000-0000-000000000002', '5ca00000-0000-0000-0000-000000000001', 'stable', 'active', '2026-07-28T06:30:00Z'),
  ('5c000000-0000-0000-0000-000000000011', '5ca00000-0000-0000-0000-000000000002', 'stable', 'active', '2026-07-28T06:30:00Z');

insert into public.horses (
  id,
  stable_id,
  display_name,
  official_name,
  birth_date,
  sex,
  breed,
  discipline,
  level,
  source_kind,
  created_by_user_id,
  created_request_id,
  created_at,
  updated_at
)
select
  md5('phase5c:horse:a:' || horse_no)::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  'Testpaard ' || lpad(horse_no::text, 2, '0'),
  'AVARYN Fictief ' || lpad(horse_no::text, 2, '0'),
  date '2012-01-01' + (horse_no * 97),
  (array['mare', 'gelding', 'stallion'])[1 + ((horse_no - 1) % 3)],
  'KWPN testdata',
  case when horse_no % 2 = 0 then 'Dressuur' else 'Springen' end,
  case when horse_no % 3 = 0 then 'Z' else 'M' end,
  'manual',
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:horse-request:' || horse_no)::uuid,
  '2026-07-28T07:00:00Z'::timestamptz,
  '2026-07-28T07:00:00Z'::timestamptz
from generate_series(
  1,
  current_setting('avaryn.horse_count')::integer
) as horse_no;

insert into public.horses (
  id,
  stable_id,
  display_name,
  official_name,
  birth_date,
  sex,
  breed,
  discipline,
  level,
  source_kind,
  created_by_user_id,
  created_request_id,
  created_at,
  updated_at
)
values (
  md5('phase5c:horse:b:1')::uuid,
  '5ca00000-0000-0000-0000-000000000002',
  'Isolatiepaard B',
  'AVARYN Fictief B',
  '2016-05-01',
  'gelding',
  'BWP testdata',
  'Springen',
  'M',
  'manual',
  '5c000000-0000-0000-0000-000000000011',
  md5('phase5c:horse-b-request:1')::uuid,
  '2026-07-28T07:00:00Z',
  '2026-07-28T07:00:00Z'
);

insert into public.horse_relationships (
  id,
  stable_id,
  horse_id,
  stable_member_id,
  relationship_type,
  status,
  valid_from,
  label,
  created_by_user_id,
  created_request_id
)
select
  md5(
    'phase5c:relationship:' || horse_no || ':' || relation.relation_no
  )::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5('phase5c:horse:a:' || horse_no)::uuid,
  relation.member_id::uuid,
  relation.relationship_type,
  'active',
  '2026-07-28',
  relation.label,
  '5c000000-0000-0000-0000-000000000001',
  md5(
    'phase5c:relationship-request:' || horse_no || ':' || relation.relation_no
  )::uuid
from generate_series(
  1,
  current_setting('avaryn.horse_count')::integer
) as horse_no
cross join (
  values
    (1, '5cb00000-0000-0000-0000-000000000002', 'rider', 'Primaire testruiter'),
    (2, '5cb00000-0000-0000-0000-000000000005', 'groom', 'Groom voor testuitvoering'),
    (3, '5cb00000-0000-0000-0000-000000000007', 'trainer', 'Fictieve trainer')
) as relation(relation_no, member_id, relationship_type, label);

insert into public.horse_relationships (
  id,
  stable_id,
  horse_id,
  stable_member_id,
  relationship_type,
  status,
  valid_from,
  label,
  created_by_user_id,
  created_request_id
)
values (
  md5('phase5c:relationship:limited-owner')::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5('phase5c:horse:a:1')::uuid,
  '5cb00000-0000-0000-0000-000000000008',
  'owner',
  'active',
  '2026-07-28',
  'Beperkte semantische eigenaar; geen stalbeheerder',
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:relationship-request:limited-owner')::uuid
);

with grant_rows as (
  select
    horse_no,
    target.membership_id,
    target.category,
    target.can_view,
    target.can_execute,
    target.can_edit,
    target.can_manage,
    target.reason
  from generate_series(
    1,
    current_setting('avaryn.horse_count')::integer
  ) as horse_no
  cross join (
    values
      ('5cc00000-0000-0000-0000-000000000003', 'horse.basic', true, false, true, false, null),
      ('5cc00000-0000-0000-0000-000000000003', 'horse.schedule', true, true, true, false, null),
      ('5cc00000-0000-0000-0000-000000000003', 'horse.nutrition', true, true, true, false, 'Voedingstest voor ruiter'),
      ('5cc00000-0000-0000-0000-000000000007', 'horse.basic', true, false, false, false, null),
      ('5cc00000-0000-0000-0000-000000000007', 'horse.schedule', true, true, true, false, null)
  ) as target(
    membership_id,
    category,
    can_view,
    can_execute,
    can_edit,
    can_manage,
    reason
  )
  union all
  select
    horse_no,
    case
      when horse_no % 2 = 1
        then '5cc00000-0000-0000-0000-000000000005'
      else '5cc00000-0000-0000-0000-000000000006'
    end,
    category,
    true,
    category <> 'horse.basic',
    false,
    false,
    case
      when category = 'horse.nutrition' then 'Voedingstest voor groom'
      else null
    end
  from generate_series(
    1,
    current_setting('avaryn.horse_count')::integer
  ) as horse_no
  cross join (
    values ('horse.basic'), ('horse.schedule'), ('horse.nutrition')
  ) as category_row(category)
  union all
  select
    1,
    '5cc00000-0000-0000-0000-000000000008',
    category,
    true,
    false,
    false,
    false,
    case
      when category = 'horse.media' then 'Media-inzage voor beperkte eigenaar'
      else null
    end
  from (values ('horse.basic'), ('horse.media')) as limited(category)
)
insert into public.horse_access_grants (
  id,
  stable_id,
  horse_id,
  membership_id,
  category,
  can_view,
  can_execute,
  can_edit,
  can_manage,
  status,
  valid_from,
  granted_by_user_id,
  granted_request_id,
  grant_reason
)
select
  md5(
    'phase5c:grant:' || horse_no || ':' || membership_id || ':' || category
  )::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5('phase5c:horse:a:' || horse_no)::uuid,
  membership_id::uuid,
  category,
  can_view,
  can_execute,
  can_edit,
  can_manage,
  'active',
  '2026-07-28T07:15:00Z',
  '5c000000-0000-0000-0000-000000000001',
  md5(
    'phase5c:grant-request:' || horse_no || ':' || membership_id || ':' || category
  )::uuid,
  reason
from grant_rows;

insert into public.horse_access_grants (
  id,
  stable_id,
  horse_id,
  membership_id,
  category,
  can_view,
  can_execute,
  can_edit,
  can_manage,
  status,
  valid_from,
  granted_by_user_id,
  granted_request_id,
  grant_reason,
  revoked_by_user_id,
  revoked_request_id,
  revoked_at
)
values (
  md5('phase5c:grant:revoked')::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5('phase5c:horse:a:1')::uuid,
  '5cc00000-0000-0000-0000-000000000009',
  'horse.basic',
  true,
  false,
  false,
  false,
  'revoked',
  '2026-07-28T07:00:00Z',
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:grant-request:revoked')::uuid,
  'Ingetrokken toegangsscenario',
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:revoke-request:revoked')::uuid,
  '2026-07-28T07:30:00Z'
);

insert into public.schedule_series (
  id,
  stable_id,
  horse_id,
  series_kind,
  data_category,
  title,
  instruction,
  timezone,
  frequency,
  interval_value,
  weekdays,
  local_start_time,
  duration_minutes,
  starts_on,
  status,
  generation_horizon_days,
  created_by_user_id,
  created_request_id,
  last_mutated_by_user_id,
  last_mutation_request_id
)
select
  md5('phase5c:series:' || routine_no)::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5(
    'phase5c:horse:a:'
    || (1 + ((routine_no - 1) % current_setting('avaryn.horse_count')::integer))
  )::uuid,
  case
    when routine_no % 3 = 0 then 'care'
    when routine_no % 3 = 1 then 'training'
    else 'task'
  end,
  'horse.schedule',
  'Testroutine ' || lpad(routine_no::text, 2, '0'),
  'Fictieve terugkerende taak voor deterministische Alpha-acceptatie.',
  'Europe/Amsterdam',
  case when routine_no % 2 = 0 then 'weekly' else 'daily' end,
  1,
  case
    when routine_no % 2 = 0 then array[1, 3, 5]::smallint[]
    else null
  end,
  make_time(7 + (routine_no % 10), 0, 0),
  30,
  '2026-07-27',
  'active',
  30,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:series-create:' || routine_no)::uuid,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:series-mutate:' || routine_no)::uuid
from generate_series(
  1,
  current_setting('avaryn.routine_count')::integer
) as routine_no;

insert into public.schedule_items (
  id,
  stable_id,
  horse_id,
  series_id,
  occurrence_local_date,
  occurrence_sequence,
  item_kind,
  data_category,
  title,
  instruction,
  priority,
  scheduled_start_at,
  scheduled_end_at,
  source_timezone,
  source_local_date,
  source_local_time,
  state,
  terminal_at,
  created_by_user_id,
  created_request_id,
  last_mutated_by_user_id,
  last_mutation_request_id
)
select
  md5('phase5c:schedule-item:' || item_no)::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5(
    'phase5c:horse:a:'
    || (
      1
      + (
        (
          1
          + (
            (item_no - 1)
            % current_setting('avaryn.routine_count')::integer
          )
          - 1
        )
        % current_setting('avaryn.horse_count')::integer
      )
    )
  )::uuid,
  md5(
    'phase5c:series:'
    || (1 + ((item_no - 1) % current_setting('avaryn.routine_count')::integer))
  )::uuid,
  date '2026-07-28' + ((item_no - 1) % 2),
  1 + (
    (item_no - 1) / current_setting('avaryn.routine_count')::integer
  ),
  case
    when item_no % 3 = 0 then 'care'
    when item_no % 3 = 1 then 'training'
    else 'task'
  end,
  'horse.schedule',
  'Today testitem ' || lpad(item_no::text, 3, '0'),
  'Fictieve uitvoering voor twee logische testdagen.',
  case when item_no % 5 = 0 then 'high' else 'normal' end,
  (
    date '2026-07-28'
    + ((item_no - 1) % 2)
    + make_time(7 + (item_no % 10), 0, 0)
  ) at time zone 'Europe/Amsterdam',
  (
    date '2026-07-28'
    + ((item_no - 1) % 2)
    + make_time(7 + (item_no % 10), 30, 0)
  ) at time zone 'Europe/Amsterdam',
  'Europe/Amsterdam',
  date '2026-07-28' + ((item_no - 1) % 2),
  make_time(7 + (item_no % 10), 0, 0),
  case when item_no = 1 then 'completed' else 'planned' end,
  case
    when item_no = 1 then '2026-07-28T06:30:00Z'::timestamptz
    else null
  end,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:item-create:' || item_no)::uuid,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:item-mutate:' || item_no)::uuid
from generate_series(
  1,
  current_setting('avaryn.item_count')::integer
) as item_no;

insert into public.schedule_assignments (
  id,
  stable_id,
  schedule_item_id,
  stable_member_id,
  assignment_role,
  status,
  completed_at,
  created_by_user_id,
  created_request_id,
  last_mutated_by_user_id,
  last_mutation_request_id
)
select
  md5('phase5c:assignment:' || item_no)::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5('phase5c:schedule-item:' || item_no)::uuid,
  case
    when item_no % 2 = 0
      then '5cb00000-0000-0000-0000-000000000006'::uuid
    else '5cb00000-0000-0000-0000-000000000005'::uuid
  end,
  'responsible',
  case when item_no = 1 then 'completed' else 'assigned' end,
  case
    when item_no = 1 then '2026-07-28T06:30:00Z'::timestamptz
    else null
  end,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:assignment-create:' || item_no)::uuid,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:assignment-mutate:' || item_no)::uuid
from generate_series(
  1,
  current_setting('avaryn.item_count')::integer
) as item_no;

insert into public.schedule_executions (
  id,
  stable_id,
  schedule_item_id,
  actor_user_id,
  actor_membership_id,
  actor_stable_member_id,
  execution_status,
  actual_started_at,
  actual_completed_at,
  recorded_local_at,
  recorded_timezone,
  source,
  request_id,
  note
)
values (
  md5('phase5c:execution:online:1')::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5('phase5c:schedule-item:1')::uuid,
  '5c000000-0000-0000-0000-000000000005',
  '5cc00000-0000-0000-0000-000000000005',
  '5cb00000-0000-0000-0000-000000000005',
  'completed',
  '2026-07-28T06:00:00Z',
  '2026-07-28T06:30:00Z',
  '2026-07-28T08:30:00',
  'Europe/Amsterdam',
  'online',
  md5('phase5c:execution-request:online:1')::uuid,
  'Fictieve afgeronde Alpha-uitvoering'
);

insert into public.feeding_plans (
  id,
  stable_id,
  horse_id,
  plan_type,
  name,
  status,
  effective_from,
  row_version,
  created_by_user_id,
  created_request_id,
  last_mutated_by_user_id,
  last_mutation_request_id
)
select
  md5('phase5c:feeding-plan:' || horse_no)::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5('phase5c:horse:a:' || horse_no)::uuid,
  'standard',
  'Fictief basisvoer ' || horse_no,
  'draft',
  '2026-07-28',
  1,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:feeding-plan-create:' || horse_no)::uuid,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:feeding-plan-mutate:' || horse_no)::uuid
from generate_series(
  1,
  least(current_setting('avaryn.horse_count')::integer, 3)
) as horse_no;

insert into public.feeding_plan_versions (
  id,
  stable_id,
  feeding_plan_id,
  version_number,
  status,
  source_kind,
  change_reason,
  approved_by_user_id,
  approved_at,
  row_version,
  created_by_user_id,
  created_request_id,
  last_mutated_by_user_id,
  last_mutation_request_id
)
select
  md5('phase5c:feeding-version:' || horse_no)::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5('phase5c:feeding-plan:' || horse_no)::uuid,
  1,
  'draft',
  'user',
  'Deterministisch fictief testplan',
  null,
  null,
  1,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:feeding-version-create:' || horse_no)::uuid,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:feeding-version-mutate:' || horse_no)::uuid
from generate_series(
  1,
  least(current_setting('avaryn.horse_count')::integer, 3)
) as horse_no;

insert into public.feeding_plan_items (
  id,
  stable_id,
  feeding_plan_version_id,
  product_brand,
  product_name,
  source_status,
  planned_quantity,
  unit_code,
  offering_method,
  round_code,
  local_time,
  weekdays,
  override_key,
  default_stable_member_id,
  instruction,
  created_by_user_id,
  created_request_id,
  last_mutated_by_user_id,
  last_mutation_request_id
)
select
  md5('phase5c:feeding-item:' || horse_no)::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5('phase5c:feeding-version:' || horse_no)::uuid,
  'Fictief merk',
  'Testbrok',
  'user_entered',
  1.5,
  'kg',
  'bucket',
  'ochtend',
  '07:00',
  array[1, 2, 3, 4, 5, 6, 7]::smallint[],
  'phase5c-ochtend-' || horse_no,
  '5cb00000-0000-0000-0000-000000000005',
  'Geen medisch advies; uitsluitend fictieve testdata.',
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:feeding-item-create:' || horse_no)::uuid,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:feeding-item-mutate:' || horse_no)::uuid
from generate_series(
  1,
  least(current_setting('avaryn.horse_count')::integer, 3)
) as horse_no;

update public.feeding_plan_versions
set
  status = 'approved',
  approved_by_user_id = '5c000000-0000-0000-0000-000000000001',
  approved_at = '2026-07-28T07:30:00Z',
  last_mutated_by_user_id = '5c000000-0000-0000-0000-000000000001',
  last_mutation_request_id = md5(
    'phase5c:feeding-version-approve:' || feeding_plan_id
  )::uuid
where stable_id = '5ca00000-0000-0000-0000-000000000001';

update public.feeding_plans plan
set
  status = 'active',
  active_version_id = version.id,
  row_version = 2,
  updated_at = '2026-07-28T07:30:00Z'
from public.feeding_plan_versions version
where plan.stable_id = '5ca00000-0000-0000-0000-000000000001'
  and version.feeding_plan_id = plan.id;

insert into public.media_assets (
  id,
  stable_id,
  horse_id,
  status,
  original_filename,
  expected_mime_type,
  max_byte_size,
  uploaded_by_user_id,
  created_request_id,
  last_mutated_by_user_id,
  last_mutation_request_id
)
select
  md5('phase5c:media:' || media_no)::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5(
    'phase5c:horse:a:'
    || (1 + ((media_no - 1) % current_setting('avaryn.horse_count')::integer))
  )::uuid,
  'pending',
  'fictieve-media-' || lpad(media_no::text, 2, '0') || '.jpg',
  'image/jpeg',
  10485760,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:media-create:' || media_no)::uuid,
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:media-mutate:' || media_no)::uuid
from generate_series(
  1,
  current_setting('avaryn.media_count')::integer
) as media_no;

insert into public.media_asset_variants (
  id,
  stable_id,
  media_asset_id,
  variant,
  status,
  object_path,
  expected_mime_type,
  max_byte_size
)
select
  md5('phase5c:media-variant:' || media_no)::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5('phase5c:media:' || media_no)::uuid,
  'original',
  'pending',
  '5ca00000-0000-0000-0000-000000000001/'
    || md5('phase5c:media:' || media_no)::uuid
    || '/original.jpg',
  'image/jpeg',
  10485760
from generate_series(
  1,
  current_setting('avaryn.media_count')::integer
) as media_no;

insert into public.media_links (
  id,
  stable_id,
  media_asset_id,
  horse_id,
  link_kind,
  created_by_user_id,
  created_request_id
)
select
  md5('phase5c:media-link:' || media_no)::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  md5('phase5c:media:' || media_no)::uuid,
  md5(
    'phase5c:horse:a:'
    || (1 + ((media_no - 1) % current_setting('avaryn.horse_count')::integer))
  )::uuid,
  'horse',
  '5c000000-0000-0000-0000-000000000001',
  md5('phase5c:media-link-create:' || media_no)::uuid
from generate_series(
  1,
  current_setting('avaryn.media_count')::integer
) as media_no;

insert into public.stable_sync_authorities (
  stable_id,
  authority_version,
  last_change_sequence
)
values
  ('5ca00000-0000-0000-0000-000000000001', 1, 0),
  ('5ca00000-0000-0000-0000-000000000002', 1, 0)
on conflict (stable_id) do nothing;

insert into public.client_sync_devices (
  id,
  stable_id,
  actor_user_id,
  encryption_public_key,
  encryption_key_fingerprint,
  registered_authority_version,
  status,
  registered_at,
  last_seen_at
)
values (
  md5('phase5c:sync-device:rider-2')::uuid,
  '5ca00000-0000-0000-0000-000000000001',
  '5c000000-0000-0000-0000-000000000003',
  repeat('FICTIVE-LOCAL-TEST-PUBLIC-KEY-', 8),
  decode(md5('phase5c:sync-fingerprint') || md5('phase5c:sync-fingerprint'), 'hex'),
  (
    select authority_version
    from public.stable_sync_authorities
    where stable_id = '5ca00000-0000-0000-0000-000000000001'
  ),
  'active',
  '2026-07-28T07:45:00Z',
  '2026-07-28T07:45:00Z'
);

insert into public.sync_conflicts (
  id,
  actor_user_id,
  stable_id,
  entity_type,
  entity_id,
  base_row_version,
  server_row_version,
  client_patch,
  status,
  created_at
)
select
  md5('phase5c:conflict:' || conflict_no)::uuid,
  '5c000000-0000-0000-0000-000000000003',
  '5ca00000-0000-0000-0000-000000000001',
  'horse_basic_noncritical',
  md5(
    'phase5c:horse:a:'
    || (1 + ((conflict_no - 1) % current_setting('avaryn.horse_count')::integer))
  )::uuid,
  1,
  2,
  jsonb_build_object(
    'display_name',
    'Lokale fictieve naam ' || conflict_no
  ),
  'open',
  '2026-07-28T08:00:00Z'::timestamptz
from generate_series(
  1,
  current_setting('avaryn.conflict_count')::integer
) as conflict_no;

commit;

\echo 'Provisioned local AVARYN Phase 5C profile:' :profile
