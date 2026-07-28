\set ON_ERROR_STOP on

\if :{?avaryn_local_test}
\else
  \echo 'Refusing to verify: avaryn_local_test is required.'
  select 1 / 0;
\endif
\if :{?profile}
\else
  \echo 'Refusing to verify: profile is required.'
  select 1 / 0;
\endif

\set QUIET 1
select
  :'avaryn_local_test' = '1'
  and :'profile' in ('basis', 'medium', 'extreme', 'custom')
  as phase_5c_guard
\gset
\set QUIET 0
\if :phase_5c_guard
\else
  \echo 'Refusing to verify: invalid local profile.'
  select 1 / 0;
\endif

select set_config('avaryn.horse_count', :'horse_count', false);
select set_config('avaryn.routine_count', :'routine_count', false);
select set_config('avaryn.item_count', :'item_count', false);
select set_config('avaryn.media_count', :'media_count', false);
select set_config('avaryn.conflict_count', :'conflict_count', false);

do $$
declare
  expected_horses integer := current_setting('avaryn.horse_count')::integer;
  expected_routines integer := current_setting('avaryn.routine_count')::integer;
  expected_items integer := current_setting('avaryn.item_count')::integer;
  expected_media integer := current_setting('avaryn.media_count')::integer;
  expected_conflicts integer :=
    current_setting('avaryn.conflict_count')::integer;
begin
  if (
    select count(*)
    from auth.users
    where email like 'test-%@example.invalid'
  ) <> 11 then
    raise exception 'Phase 5C user fixture count mismatch';
  end if;
  if (
    select count(*)
    from public.horses
    where stable_id = '5ca00000-0000-0000-0000-000000000001'
  ) <> expected_horses then
    raise exception 'Phase 5C horse count mismatch';
  end if;
  if (
    select count(*)
    from public.schedule_series
    where stable_id = '5ca00000-0000-0000-0000-000000000001'
  ) <> expected_routines then
    raise exception 'Phase 5C routine count mismatch';
  end if;
  if (
    select count(*)
    from public.schedule_items
    where stable_id = '5ca00000-0000-0000-0000-000000000001'
  ) <> expected_items then
    raise exception 'Phase 5C schedule item count mismatch';
  end if;
  if (
    select count(*)
    from public.media_assets
    where stable_id = '5ca00000-0000-0000-0000-000000000001'
  ) <> expected_media then
    raise exception 'Phase 5C media count mismatch';
  end if;
  if (
    select count(*)
    from public.sync_conflicts
    where stable_id = '5ca00000-0000-0000-0000-000000000001'
      and status = 'open'
  ) <> expected_conflicts then
    raise exception 'Phase 5C conflict count mismatch';
  end if;
  if (
    select count(*)
    from public.stable_members
    where stable_id = '5ca00000-0000-0000-0000-000000000001'
      and function_title = 'Ruiter'
  ) <> 2 then
    raise exception 'Phase 5C requires two explicit rider records';
  end if;
  if (
    select count(*)
    from public.stable_members
    where stable_id = '5ca00000-0000-0000-0000-000000000001'
      and function_title = 'Groom'
  ) <> 2 then
    raise exception 'Phase 5C requires two groom records';
  end if;
  if not exists (
    select 1
    from public.horse_relationships
    where stable_member_id = '5cb00000-0000-0000-0000-000000000008'
      and relationship_type = 'owner'
      and status = 'active'
  ) then
    raise exception 'Phase 5C limited semantic owner missing';
  end if;
  if not exists (
    select 1
    from public.horse_access_grants
    where membership_id = '5cc00000-0000-0000-0000-000000000009'
      and status = 'revoked'
  ) then
    raise exception 'Phase 5C revoked access scenario missing';
  end if;
  if not exists (
    select 1
    from public.stable_memberships
    where user_id = '5c000000-0000-0000-0000-000000000002'
      and status = 'active'
    group by user_id
    having count(distinct stable_id) = 2
  ) then
    raise exception 'Phase 5C stable-switch scenario missing';
  end if;
  if not exists (
    select 1 from public.schedule_executions
    where request_id = md5('phase5c:execution-request:online:1')::uuid
  ) then
    raise exception 'Phase 5C completed execution missing';
  end if;
  if not exists (
    select 1 from public.feeding_plans
    where stable_id = '5ca00000-0000-0000-0000-000000000001'
      and status = 'active'
  ) then
    raise exception 'Phase 5C feeding scenario missing';
  end if;
  if not exists (
    select 1 from public.client_sync_devices
    where actor_user_id = '5c000000-0000-0000-0000-000000000003'
      and status = 'active'
  ) then
    raise exception 'Phase 5C native offline-device scenario missing';
  end if;
end;
$$;

begin;
set local role authenticated;

select set_config(
  'request.jwt.claims',
  '{"sub":"5c000000-0000-0000-0000-000000000001","role":"authenticated"}',
  true
);
do $$
begin
  if (
    select count(*) from public.horses
  ) <> current_setting('avaryn.horse_count')::integer then
    raise exception 'Owner A did not see exactly its own stable horses';
  end if;
  if exists (
    select 1
    from public.horses
    where stable_id <> '5ca00000-0000-0000-0000-000000000001'
  ) then
    raise exception 'Owner A saw a cross-stable Horse';
  end if;
end;
$$;

select set_config(
  'request.jwt.claims',
  '{"sub":"5c000000-0000-0000-0000-000000000011","role":"authenticated"}',
  true
);
do $$
begin
  if (
    select count(*)
    from public.horses
    where stable_id = '5ca00000-0000-0000-0000-000000000002'
      and id = md5('phase5c:horse:b:1')::uuid
  ) <> 1
    or (select count(*) from public.horses) <> 1
  then
    raise exception 'Owner B isolation failed';
  end if;
end;
$$;

select set_config(
  'request.jwt.claims',
  '{"sub":"5c000000-0000-0000-0000-000000000008","role":"authenticated"}',
  true
);
do $$
begin
  if (
    select count(*)
    from public.horses
    where stable_id = '5ca00000-0000-0000-0000-000000000001'
      and id = md5('phase5c:horse:a:1')::uuid
  ) <> 1
    or (select count(*) from public.horses) <> 1
  then
    raise exception 'Limited owner scope failed';
  end if;
end;
$$;

select set_config(
  'request.jwt.claims',
  '{"sub":"5c000000-0000-0000-0000-000000000009","role":"authenticated"}',
  true
);
do $$
begin
  if (select count(*) from public.horses) <> 0 then
    raise exception 'Revoked user retained Horse access';
  end if;
end;
$$;

select set_config(
  'request.jwt.claims',
  '{"sub":"5c000000-0000-0000-0000-000000000010","role":"authenticated"}',
  true
);
do $$
begin
  if (select count(*) from public.horses) <> 0 then
    raise exception 'Outsider reached Horse data';
  end if;
end;
$$;

rollback;

\echo 'Verified local AVARYN Phase 5C profile:' :profile
