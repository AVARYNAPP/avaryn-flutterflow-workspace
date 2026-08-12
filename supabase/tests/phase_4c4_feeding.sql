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
  now(),
  '{}',
  '{}',
  now(),
  now()
from (
  values
    ('4c410000-0000-0000-0000-000000000001', 'feeding-owner-a@example.invalid'),
    ('4c410000-0000-0000-0000-000000000002', 'feeding-admin-a@example.invalid'),
    ('4c410000-0000-0000-0000-000000000003', 'feeding-member-a@example.invalid'),
    ('4c410000-0000-0000-0000-000000000004', 'feeding-assignee-a@example.invalid'),
    ('4c410000-0000-0000-0000-000000000005', 'feeding-viewer-a@example.invalid'),
    ('4c410000-0000-0000-0000-000000000006', 'feeding-suspended-a@example.invalid'),
    ('4c410000-0000-0000-0000-000000000007', 'feeding-owner-b@example.invalid'),
    ('4c410000-0000-0000-0000-000000000008', 'feeding-admin-without-grant@example.invalid')
) as fixture(id, email);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values
  (
    '4c420000-0000-0000-0000-000000000001',
    'organization', 'Feeding stable A', 'active',
    'Europe/Amsterdam', 'nl',
    '4c410000-0000-0000-0000-000000000001',
    '4c420000-0000-0000-0000-000000000011'
  ),
  (
    '4c420000-0000-0000-0000-000000000002',
    'organization', 'Feeding control B', 'active',
    'Europe/Brussels', 'nl',
    '4c410000-0000-0000-0000-000000000007',
    '4c420000-0000-0000-0000-000000000012'
  );

insert into public.stable_members (
  id, stable_id, display_name, status, source
)
values
  ('4c430000-0000-0000-0000-000000000001', '4c420000-0000-0000-0000-000000000001', 'Owner A', 'active', 'owner_creation'),
  ('4c430000-0000-0000-0000-000000000002', '4c420000-0000-0000-0000-000000000001', 'Admin A', 'active', 'manual'),
  ('4c430000-0000-0000-0000-000000000003', '4c420000-0000-0000-0000-000000000001', 'Member A', 'active', 'manual'),
  ('4c430000-0000-0000-0000-000000000004', '4c420000-0000-0000-0000-000000000001', 'Assigned viewer A', 'active', 'manual'),
  ('4c430000-0000-0000-0000-000000000005', '4c420000-0000-0000-0000-000000000001', 'Viewer A', 'active', 'manual'),
  ('4c430000-0000-0000-0000-000000000006', '4c420000-0000-0000-0000-000000000001', 'Suspended A', 'active', 'manual'),
  ('4c430000-0000-0000-0000-000000000007', '4c420000-0000-0000-0000-000000000002', 'Owner B', 'active', 'owner_creation'),
  ('4c430000-0000-0000-0000-000000000008', '4c420000-0000-0000-0000-000000000001', 'Admin without grant', 'active', 'manual');

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status,
  joined_at, ended_at, ended_reason
)
values
  ('4c440000-0000-0000-0000-000000000001', '4c420000-0000-0000-0000-000000000001', '4c410000-0000-0000-0000-000000000001', '4c430000-0000-0000-0000-000000000001', 'owner', 'active', now(), null, null),
  ('4c440000-0000-0000-0000-000000000002', '4c420000-0000-0000-0000-000000000001', '4c410000-0000-0000-0000-000000000002', '4c430000-0000-0000-0000-000000000002', 'admin', 'active', now(), null, null),
  ('4c440000-0000-0000-0000-000000000003', '4c420000-0000-0000-0000-000000000001', '4c410000-0000-0000-0000-000000000003', '4c430000-0000-0000-0000-000000000003', 'member', 'active', now(), null, null),
  ('4c440000-0000-0000-0000-000000000004', '4c420000-0000-0000-0000-000000000001', '4c410000-0000-0000-0000-000000000004', '4c430000-0000-0000-0000-000000000004', 'viewer', 'active', now(), null, null),
  ('4c440000-0000-0000-0000-000000000005', '4c420000-0000-0000-0000-000000000001', '4c410000-0000-0000-0000-000000000005', '4c430000-0000-0000-0000-000000000005', 'viewer', 'active', now(), null, null),
  ('4c440000-0000-0000-0000-000000000006', '4c420000-0000-0000-0000-000000000001', '4c410000-0000-0000-0000-000000000006', '4c430000-0000-0000-0000-000000000006', 'member', 'suspended', now(), now(), 'fixture'),
  ('4c440000-0000-0000-0000-000000000007', '4c420000-0000-0000-0000-000000000002', '4c410000-0000-0000-0000-000000000007', '4c430000-0000-0000-0000-000000000007', 'owner', 'active', now(), null, null),
  ('4c440000-0000-0000-0000-000000000008', '4c420000-0000-0000-0000-000000000001', '4c410000-0000-0000-0000-000000000008', '4c430000-0000-0000-0000-000000000008', 'admin', 'active', now(), null, null);

set constraints all immediate;

insert into public.horses (
  id, stable_id, display_name, source_kind,
  created_by_user_id, created_request_id
)
values
  ('4c450000-0000-0000-0000-000000000001', '4c420000-0000-0000-0000-000000000001', 'Feeding Horse A', 'manual', '4c410000-0000-0000-0000-000000000001', '4c450000-0000-0000-0000-000000000011'),
  ('4c450000-0000-0000-0000-000000000002', '4c420000-0000-0000-0000-000000000001', 'Private Horse A', 'manual', '4c410000-0000-0000-0000-000000000001', '4c450000-0000-0000-0000-000000000012'),
  ('4c450000-0000-0000-0000-000000000003', '4c420000-0000-0000-0000-000000000002', 'Control Horse B', 'manual', '4c410000-0000-0000-0000-000000000007', '4c450000-0000-0000-0000-000000000013');

insert into public.horse_access_grants (
  stable_id, horse_id, membership_id, category,
  can_view, can_execute, can_edit, can_manage,
  granted_by_user_id, granted_request_id, grant_reason
)
values
  ('4c420000-0000-0000-0000-000000000001', '4c450000-0000-0000-0000-000000000001', '4c440000-0000-0000-0000-000000000002', 'horse.nutrition', true, true, true, true, '4c410000-0000-0000-0000-000000000001', '4c460000-0000-0000-0000-000000000001', 'Explicit nutrition manager'),
  ('4c420000-0000-0000-0000-000000000001', '4c450000-0000-0000-0000-000000000001', '4c440000-0000-0000-0000-000000000003', 'horse.nutrition', true, true, true, false, '4c410000-0000-0000-0000-000000000001', '4c460000-0000-0000-0000-000000000002', 'Explicit nutrition editor'),
  ('4c420000-0000-0000-0000-000000000001', '4c450000-0000-0000-0000-000000000001', '4c440000-0000-0000-0000-000000000005', 'horse.nutrition', true, false, false, false, '4c410000-0000-0000-0000-000000000001', '4c460000-0000-0000-0000-000000000003', 'Explicit nutrition viewer');

-- C-009.1 makes the canonical permission catalog authoritative. These grants
-- retain the fixture's capability distinctions without deriving horse access
-- from membership, role, assignment or the legacy nutrition grant table.
insert into public.horse_profile_permission_grants (
  horse_id,
  grantee_profile_id,
  permission_id,
  grantor_profile_id,
  reason_code,
  creation_correlation_id
)
select
  fixture.horse_id,
  grantee.id,
  permission.id,
  grantor.id,
  'MANUAL_GRANT',
  fixture.creation_correlation_id
from (
  values
    ('4c450000-0000-0000-0000-000000000001'::uuid, '4c410000-0000-0000-0000-000000000002'::uuid, 'horse.view'::text, '4c460000-0000-0000-0000-000000000011'::uuid),
    ('4c450000-0000-0000-0000-000000000001'::uuid, '4c410000-0000-0000-0000-000000000002'::uuid, 'horse.edit'::text, '4c460000-0000-0000-0000-000000000012'::uuid),
    ('4c450000-0000-0000-0000-000000000001'::uuid, '4c410000-0000-0000-0000-000000000003'::uuid, 'horse.view'::text, '4c460000-0000-0000-0000-000000000013'::uuid),
    ('4c450000-0000-0000-0000-000000000001'::uuid, '4c410000-0000-0000-0000-000000000003'::uuid, 'horse.edit'::text, '4c460000-0000-0000-0000-000000000014'::uuid),
    ('4c450000-0000-0000-0000-000000000001'::uuid, '4c410000-0000-0000-0000-000000000004'::uuid, 'horse.edit'::text, '4c460000-0000-0000-0000-000000000015'::uuid),
    ('4c450000-0000-0000-0000-000000000001'::uuid, '4c410000-0000-0000-0000-000000000004'::uuid, 'horse.view'::text, '4c460000-0000-0000-0000-000000000017'::uuid),
    ('4c450000-0000-0000-0000-000000000001'::uuid, '4c410000-0000-0000-0000-000000000005'::uuid, 'horse.view'::text, '4c460000-0000-0000-0000-000000000016'::uuid)
) as fixture(
  horse_id,
  grantee_auth_user_id,
  permission_code,
  creation_correlation_id
)
join public.profiles grantee
  on grantee.auth_user_id = fixture.grantee_auth_user_id
join public.profiles grantor
  on grantor.auth_user_id = '4c410000-0000-0000-0000-000000000001'::uuid
join public.permission_definitions permission
  on permission.code = fixture.permission_code;

insert into public.feeding_plans (
  id, stable_id, horse_id, plan_type, name, status,
  effective_from, effective_until, active_version_id,
  created_by_user_id, created_request_id,
  last_mutated_by_user_id, last_mutation_request_id
)
values (
  '4c470000-0000-0000-0000-000000000099',
  '4c420000-0000-0000-0000-000000000002',
  '4c450000-0000-0000-0000-000000000003',
  'standard', 'Control plan B', 'draft',
  '2026-07-28', null, null,
  '4c410000-0000-0000-0000-000000000007',
  '4c470000-0000-0000-0000-000000000199',
  '4c410000-0000-0000-0000-000000000007',
  '4c470000-0000-0000-0000-000000000199'
);

do $$
declare
  public_table text;
  public_tables text[] := array[
    'feeding_plans',
    'feeding_plan_versions',
    'feeding_plan_items',
    'feeding_occurrences',
    'feeding_execution_details',
    'feeding_change_events'
  ];
  required_rpc text;
  required_rpcs text[] := array[
    'create_feeding_plan',
    'create_feeding_plan_version',
    'upsert_feeding_plan_item',
    'approve_feeding_plan_version',
    'activate_feeding_plan_version',
    'retire_feeding_plan',
    'record_feeding_execution'
  ];
begin
  foreach public_table in array public_tables loop
    if not (
      select c.relrowsecurity
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public' and c.relname = public_table
    ) then
      raise exception '4C.4 RLS disabled on %', public_table;
    end if;
    if has_table_privilege('authenticated', 'public.' || public_table, 'INSERT')
      or has_table_privilege('authenticated', 'public.' || public_table, 'UPDATE')
      or has_table_privilege('authenticated', 'public.' || public_table, 'DELETE')
    then
      raise exception '4C.4 direct DML ACL too broad on %', public_table;
    end if;
  end loop;
  foreach required_rpc in array required_rpcs loop
    if not exists (
      select 1
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = required_rpc
        and p.prosecdef
    ) then
      raise exception '4C.4 SECURITY DEFINER RPC missing: %', required_rpc;
    end if;
  end loop;
  if has_sequence_privilege(
    'authenticated',
    'public.feeding_change_events_id_seq',
    'USAGE'
  ) or has_sequence_privilege(
    'authenticated',
    'public.feeding_change_events_id_seq',
    'SELECT'
  ) then
    raise exception '4C.4 event sequence ACL too broad';
  end if;
end;
$$;

do $$
begin
  begin
    insert into public.feeding_plans (
      stable_id, horse_id, plan_type, name, effective_from,
      created_by_user_id, created_request_id,
      last_mutated_by_user_id, last_mutation_request_id
    ) values (
      '4c420000-0000-0000-0000-000000000001',
      '4c450000-0000-0000-0000-000000000003',
      'standard', 'Cross stable', '2026-07-28',
      '4c410000-0000-0000-0000-000000000001', gen_random_uuid(),
      '4c410000-0000-0000-0000-000000000001', gen_random_uuid()
    );
    raise exception 'Cross-stable feeding plan bypassed FK';
  exception when foreign_key_violation then null;
  end;
end;
$$;

create temp table phase_4c4_ids (
  name text primary key,
  id uuid not null
) on commit drop;
grant select, insert, update on phase_4c4_ids to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '4c410000-0000-0000-0000-000000000001',
  true
);

insert into phase_4c4_ids
select 'standard_plan', (
  public.create_feeding_plan(
    '4c450000-0000-0000-0000-000000000001',
    'standard', '  Basisrantsoen  ', '2026-07-28', null,
    '4c4a0000-0000-0000-0000-000000000001'
  )->>'feeding_plan_id'
)::uuid;

do $$
declare replayed jsonb;
begin
  replayed := public.create_feeding_plan(
    '4c450000-0000-0000-0000-000000000001',
    'standard', 'Basisrantsoen', '2026-07-28', null,
    '4c4a0000-0000-0000-0000-000000000001'
  );
  if (replayed->>'feeding_plan_id')::uuid <>
      (select id from phase_4c4_ids where name = 'standard_plan')
    or (replayed->>'idempotent')::boolean is not true
  then
    raise exception 'create_feeding_plan exact retry failed';
  end if;
  begin
    perform public.create_feeding_plan(
      '4c450000-0000-0000-0000-000000000001',
      'standard', 'Changed payload', '2026-07-28', null,
      '4c4a0000-0000-0000-0000-000000000001'
    );
    raise exception 'Changed create payload reused request id';
  exception when invalid_parameter_value then
    if sqlerrm <> 'REQUEST_ID_REUSED' then raise; end if;
  end;
end;
$$;

insert into phase_4c4_ids
select 'standard_version', (
  public.create_feeding_plan_version(
    (select id from phase_4c4_ids where name = 'standard_plan'),
    'user', null, 'Eerste goedgekeurde versie',
    '4c4a0000-0000-0000-0000-000000000002'
  )->>'feeding_plan_version_id'
)::uuid;

do $$
begin
  begin
    perform public.create_feeding_plan_version(
      (select id from phase_4c4_ids where name = 'standard_plan'),
      'professional', 'dietician-claim', 'Niet client-verifieerbaar',
      '4c4a0000-0000-0000-0000-000000000003'
    );
    raise exception 'Professional source was opened by ordinary client RPC';
  exception when invalid_parameter_value then
    if sqlerrm <> 'INVALID_FEEDING_VERSION_SOURCE' then raise; end if;
  end;
end;
$$;

insert into phase_4c4_ids
select 'hay_item', (
  public.upsert_feeding_plan_item(
    (select id from phase_4c4_ids where name = 'standard_version'),
    null, null, '  AVARYN  ', '  Timothy hay  ', null,
    'user_entered', 2.5, 'kg', 'hay_net', 'morning', '08:00',
    null, null, 'morning-hay',
    '4c430000-0000-0000-0000-000000000004',
    'LOT-001', '2026-12-31', '  Weigh before offering.  ',
    '4c4a0000-0000-0000-0000-000000000004'
  )->>'feeding_plan_item_id'
)::uuid;

insert into phase_4c4_ids
select 'supplement_item', (
  public.upsert_feeding_plan_item(
    (select id from phase_4c4_ids where name = 'standard_version'),
    null, null, null, 'Mineral supplement', null,
    'commercial', 120, 'g', 'bucket', 'evening', '18:30',
    null, null, 'evening-mineral', null,
    null, null, null,
    '4c4a0000-0000-0000-0000-000000000005'
  )->>'feeding_plan_item_id'
)::uuid;

do $$
declare replayed jsonb;
begin
  replayed := public.upsert_feeding_plan_item(
    (select id from phase_4c4_ids where name = 'standard_version'),
    null, null, 'AVARYN', 'Timothy hay', null,
    'user_entered', 2.5, 'kg', 'hay_net', 'morning', '08:00',
    null, null, 'morning-hay',
    '4c430000-0000-0000-0000-000000000004',
    'LOT-001', '2026-12-31', 'Weigh before offering.',
    '4c4a0000-0000-0000-0000-000000000004'
  );
  if (replayed->>'feeding_plan_item_id')::uuid <>
      (select id from phase_4c4_ids where name = 'hay_item')
    or (replayed->>'idempotent')::boolean is not true
  then
    raise exception 'upsert_feeding_plan_item exact retry failed';
  end if;
  begin
    perform public.upsert_feeding_plan_item(
      (select id from phase_4c4_ids where name = 'standard_version'),
      null, null, null, 'Forbidden template', null,
      'verified_template', 1, 'kg', 'bucket', 'test', '12:00',
      null, null, null, null, null, null, null,
      '4c4a0000-0000-0000-0000-000000000006'
    );
    raise exception 'Verified template claim was accepted';
  exception when invalid_parameter_value then
    if sqlerrm <> 'INVALID_FEEDING_PLAN_ITEM' then raise; end if;
  end;
end;
$$;

select public.approve_feeding_plan_version(
  (select id from phase_4c4_ids where name = 'standard_version'),
  1,
  '4c4a0000-0000-0000-0000-000000000007'
);

do $$
declare replayed jsonb;
begin
  replayed := public.approve_feeding_plan_version(
    (select id from phase_4c4_ids where name = 'standard_version'),
    1,
    '4c4a0000-0000-0000-0000-000000000007'
  );
  if (replayed->>'idempotent')::boolean is not true then
    raise exception 'approve exact retry failed';
  end if;
  begin
    update public.feeding_plan_versions
    set change_reason = 'Forbidden rewrite'
    where id = (select id from phase_4c4_ids where name = 'standard_version');
    raise exception 'Approved version was mutable';
  exception when insufficient_privilege then null;
  end;
end;
$$;

select public.activate_feeding_plan_version(
  (select id from phase_4c4_ids where name = 'standard_version'),
  2, '2026-08-02',
  '4c4a0000-0000-0000-0000-000000000008'
);

do $$
declare
  replayed jsonb;
  expected_count integer;
begin
  replayed := public.activate_feeding_plan_version(
    (select id from phase_4c4_ids where name = 'standard_version'),
    2, '2026-08-02',
    '4c4a0000-0000-0000-0000-000000000008'
  );
  if (replayed->>'idempotent')::boolean is not true then
    raise exception 'activate exact retry failed';
  end if;
  select count(*) into expected_count
  from public.feeding_occurrences
  where feeding_plan_version_id =
    (select id from phase_4c4_ids where name = 'standard_version');
  if expected_count <> 12 then
    raise exception 'Expected 12 standard occurrences, got %', expected_count;
  end if;
  if exists (
    select 1
    from public.feeding_occurrences occurrence
    join public.schedule_items item on item.id = occurrence.schedule_item_id
    where occurrence.feeding_plan_version_id =
      (select id from phase_4c4_ids where name = 'standard_version')
      and (
        item.item_kind <> 'feeding'
        or item.data_category <> 'horse.nutrition'
        or item.source_timezone <> 'Europe/Amsterdam'
        or item.source_local_date <> occurrence.occurrence_local_date
      )
  ) then
    raise exception 'Feeding schedule materialization lost typed/local intent';
  end if;
  if (
    select count(*)
    from public.schedule_assignments assignment
    join public.feeding_occurrences occurrence
      on occurrence.schedule_item_id = assignment.schedule_item_id
    where occurrence.feeding_plan_item_id =
      (select id from phase_4c4_ids where name = 'hay_item')
      and assignment.stable_member_id =
        '4c430000-0000-0000-0000-000000000004'
  ) <> 6 then
    raise exception 'Default feeding assignee was not materialized';
  end if;
end;
$$;

insert into phase_4c4_ids
select 'execution_item', occurrence.schedule_item_id
from public.feeding_occurrences occurrence
where occurrence.feeding_plan_item_id =
  (select id from phase_4c4_ids where name = 'hay_item')
  and occurrence.occurrence_local_date = '2026-07-29';

select set_config(
  'request.jwt.claim.sub',
  '4c410000-0000-0000-0000-000000000004',
  true
);

do $$
begin
  if (
    select count(*) from public.feeding_plans
    where horse_id = '4c450000-0000-0000-0000-000000000001'
  ) <> 1
    or exists (
      select 1 from public.feeding_plans
      where horse_id = '4c450000-0000-0000-0000-000000000003'
    )
  then
    raise exception 'Explicit canonical editor feeding scope is incorrect';
  end if;
  if (
    select count(*)
    from public.get_schedule_item(
      (select id from phase_4c4_ids where name = 'execution_item')
    )
  ) <> 1 then
    raise exception 'Explicit canonical editor cannot read its schedule item';
  end if;
end;
$$;

insert into phase_4c4_ids
select 'execution', (
  public.record_feeding_execution(
    (select id from phase_4c4_ids where name = 'execution_item'),
    null,
    '4c4b0000-0000-0000-0000-000000000001',
    'partial',
    '2026-07-29 06:00:00+00',
    '2026-07-29 06:10:00+00',
    '2026-07-29 08:10:00',
    'Europe/Amsterdam',
    'online',
    null,
    'Horse left some hay.',
    2.0,
    'kg',
    0.5,
    'less',
    'Calm appetite.',
    'LOT-001'
  )->>'execution_id'
)::uuid;

do $$
declare replayed jsonb;
begin
  replayed := public.record_feeding_execution(
    (select id from phase_4c4_ids where name = 'execution_item'),
    null,
    '4c4b0000-0000-0000-0000-000000000001',
    'partial',
    '2026-07-29 06:00:00+00',
    '2026-07-29 06:10:00+00',
    '2026-07-29 08:10:00',
    'Europe/Amsterdam',
    'online',
    null,
    'Horse left some hay.',
    2.0,
    'kg',
    0.5,
    'less',
    'Calm appetite.',
    'LOT-001'
  );
  if (replayed->>'execution_id')::uuid <>
      (select id from phase_4c4_ids where name = 'execution')
    or (replayed->>'idempotent')::boolean is not true
  then
    raise exception 'Terminal feeding execution exact retry failed';
  end if;
  if (
    select count(*) from public.feeding_execution_details
    where execution_id = (select id from phase_4c4_ids where name = 'execution')
      and actual_quantity = 2.0
      and unit_code = 'kg'
      and remaining_quantity = 0.5
  ) <> 1 then
    raise exception 'Generic execution and feeding detail were not atomic';
  end if;
  begin
    perform public.record_feeding_execution(
      (select id from phase_4c4_ids where name = 'execution_item'),
      null, gen_random_uuid(), 'completed', null, now(),
      localtimestamp, 'Europe/Amsterdam', 'online', null, null,
      2000, 'g', 0, 'none', null, null
    );
    raise exception 'Silent unit conversion was accepted';
  exception when invalid_parameter_value then
    if sqlerrm <> 'FEEDING_UNIT_CONVERSION_REQUIRED' then raise; end if;
  end;
end;
$$;

insert into phase_4c4_ids
select 'correction', (
  public.record_feeding_execution(
    (select id from phase_4c4_ids where name = 'execution_item'),
    (select id from phase_4c4_ids where name = 'execution'),
    '4c4b0000-0000-0000-0000-000000000002',
    'completed',
    '2026-07-29 06:00:00+00',
    '2026-07-29 06:10:00+00',
    '2026-07-29 08:10:00',
    'Europe/Amsterdam',
    'online',
    null,
    'Corrected quantity.',
    2.5,
    'kg',
    0,
    'none',
    'Finished after recheck.',
    'LOT-001'
  )->>'execution_id'
)::uuid;

do $$
begin
  if (
    select count(*)
    from public.schedule_executions
    where schedule_item_id =
      (select id from phase_4c4_ids where name = 'execution_item')
  ) <> 2
    or (
      select corrects_execution_id
      from public.schedule_executions
      where id = (select id from phase_4c4_ids where name = 'correction')
    ) <> (select id from phase_4c4_ids where name = 'execution')
  then
    raise exception 'Feeding correction was not append-only';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c410000-0000-0000-0000-000000000001',
  true
);

insert into phase_4c4_ids
select 'temporary_plan', (
  public.create_feeding_plan(
    '4c450000-0000-0000-0000-000000000001',
    'temporary', 'Temporary hay override',
    '2026-07-29', '2026-07-30',
    '4c4c0000-0000-0000-0000-000000000001'
  )->>'feeding_plan_id'
)::uuid;

insert into phase_4c4_ids
select 'temporary_version', (
  public.create_feeding_plan_version(
    (select id from phase_4c4_ids where name = 'temporary_plan'),
    'user', null, 'Temporary adjustment',
    '4c4c0000-0000-0000-0000-000000000002'
  )->>'feeding_plan_version_id'
)::uuid;

select public.upsert_feeding_plan_item(
  (select id from phase_4c4_ids where name = 'temporary_version'),
  null, null, null, 'Temporary hay amount', null,
  'user_entered', 2.0, 'kg', 'hay_net', 'morning', '08:00',
  null, null, 'morning-hay',
  '4c430000-0000-0000-0000-000000000004',
  null, null, 'Temporary exact-key replacement',
  '4c4c0000-0000-0000-0000-000000000003'
);

select public.approve_feeding_plan_version(
  (select id from phase_4c4_ids where name = 'temporary_version'),
  1,
  '4c4c0000-0000-0000-0000-000000000004'
);

select public.activate_feeding_plan_version(
  (select id from phase_4c4_ids where name = 'temporary_version'),
  2, '2026-07-30',
  '4c4c0000-0000-0000-0000-000000000005'
);

do $$
begin
  if (
    select state
    from public.schedule_items
    where id = (select id from phase_4c4_ids where name = 'execution_item')
  ) <> 'completed' then
    raise exception 'Temporary override rewrote executed standard history';
  end if;
  if exists (
    select 1
    from public.feeding_occurrences occurrence
    join public.feeding_plan_versions version
      on version.id = occurrence.feeding_plan_version_id
    join public.feeding_plans plan on plan.id = version.feeding_plan_id
    where plan.id = (select id from phase_4c4_ids where name = 'temporary_plan')
      and occurrence.occurrence_local_date = '2026-07-29'
  ) then
    raise exception 'Temporary occurrence duplicated executed standard history';
  end if;
  if (
    select count(*)
    from public.feeding_occurrences occurrence
    join public.feeding_plan_versions version
      on version.id = occurrence.feeding_plan_version_id
    join public.feeding_plans plan on plan.id = version.feeding_plan_id
    where plan.id = (select id from phase_4c4_ids where name = 'temporary_plan')
      and occurrence.occurrence_local_date = '2026-07-30'
  ) <> 1 then
    raise exception 'Temporary exact-key occurrence not materialized';
  end if;
  if (
    select state_reason
    from public.schedule_items item
    join public.feeding_occurrences occurrence
      on occurrence.schedule_item_id = item.id
    where occurrence.feeding_plan_item_id =
      (select id from phase_4c4_ids where name = 'hay_item')
      and occurrence.occurrence_local_date = '2026-07-30'
  ) <> 'temporary_feeding_override' then
    raise exception 'Unexecuted standard occurrence was not overridden';
  end if;
  if exists (
    select 1
    from public.schedule_assignments assignment
    join public.feeding_occurrences occurrence
      on occurrence.schedule_item_id = assignment.schedule_item_id
    where occurrence.feeding_plan_item_id =
      (select id from phase_4c4_ids where name = 'hay_item')
      and occurrence.occurrence_local_date = '2026-07-30'
      and assignment.status in ('assigned', 'accepted')
  ) then
    raise exception 'Cancelled standard occurrence retained active assignment';
  end if;
end;
$$;

do $$
begin
  begin
    perform public.retire_feeding_plan(
      (select id from phase_4c4_ids where name = 'standard_plan'),
      2, 'Must not orphan active temporary override',
      '4c4c0000-0000-0000-0000-000000000006'
    );
    raise exception 'Standard plan retired beneath active temporary override';
  exception when object_not_in_prerequisite_state then
    if sqlerrm <> 'STANDARD_PLAN_HAS_ACTIVE_TEMPORARY' then raise; end if;
  end;
end;
$$;

insert into phase_4c4_ids
select 'bad_temp_plan', (
  public.create_feeding_plan(
    '4c450000-0000-0000-0000-000000000001',
    'temporary', 'Bad temporary',
    '2026-08-01', '2026-08-02',
    '4c4d0000-0000-0000-0000-000000000001'
  )->>'feeding_plan_id'
)::uuid;
insert into phase_4c4_ids
select 'bad_temp_version', (
  public.create_feeding_plan_version(
    (select id from phase_4c4_ids where name = 'bad_temp_plan'),
    'user', null, 'Invalid missing override',
    '4c4d0000-0000-0000-0000-000000000002'
  )->>'feeding_plan_version_id'
)::uuid;
select public.upsert_feeding_plan_item(
  (select id from phase_4c4_ids where name = 'bad_temp_version'),
  null, null, null, 'Unknown replacement', null,
  'user_entered', 1, 'kg', 'bucket', 'night', '21:00',
  null, null, 'not-in-standard', null, null, null, null,
  '4c4d0000-0000-0000-0000-000000000003'
);
select public.approve_feeding_plan_version(
  (select id from phase_4c4_ids where name = 'bad_temp_version'),
  1,
  '4c4d0000-0000-0000-0000-000000000004'
);

do $$
begin
  begin
    perform public.activate_feeding_plan_version(
      (select id from phase_4c4_ids where name = 'bad_temp_version'),
      2, '2026-08-02',
      '4c4d0000-0000-0000-0000-000000000005'
    );
    raise exception 'Ambiguous temporary override was activated';
  exception when object_not_in_prerequisite_state then
    if sqlerrm <> 'TEMPORARY_OVERRIDE_NOT_EXPLICIT' then raise; end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c410000-0000-0000-0000-000000000002',
  true
);
do $$
begin
  if (select count(*) from public.feeding_plans) < 3 then
    raise exception 'Explicit nutrition manager cannot read plans';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c410000-0000-0000-0000-000000000003',
  true
);
do $$
begin
  if (select count(*) from public.feeding_plans) < 3 then
    raise exception 'Explicit nutrition editor cannot read plans';
  end if;
  perform public.retire_feeding_plan(
    (select id from phase_4c4_ids where name = 'bad_temp_plan'),
    1, 'Canonical horse editor retirement',
    '4c4e0000-0000-0000-0000-000000000001'
  );
  if (
    select status from public.feeding_plans
    where id = (select id from phase_4c4_ids where name = 'bad_temp_plan')
  ) <> 'retired' then
    raise exception 'Explicit canonical editor could not retire a feeding plan';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c410000-0000-0000-0000-000000000008',
  true
);
do $$
begin
  if (select count(*) from public.feeding_plans) <> 0 then
    raise exception 'Admin without explicit nutrition grant read plan data';
  end if;
  begin
    perform public.create_feeding_plan(
      '4c450000-0000-0000-0000-000000000001',
      'standard', 'Implicit admin forbidden', '2026-10-01', null,
      '4c4e0000-0000-0000-0000-000000000002'
    );
    raise exception 'Admin received implicit nutrition edit capability';
  exception when insufficient_privilege then
    if sqlerrm <> 'NOT_AUTHORIZED' then raise; end if;
  end;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c410000-0000-0000-0000-000000000006',
  true
);
do $$
begin
  if (select count(*) from public.feeding_plans) <> 0
    or (select count(*) from public.feeding_change_events) <> 0
  then
    raise exception 'Suspended membership retained feeding visibility';
  end if;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '4c410000-0000-0000-0000-000000000001',
  true
);
do $$
declare
  unknown_message text;
  cross_message text;
begin
  begin
    perform public.create_feeding_plan(
      '4c450000-0000-0000-0000-000000000099',
      'standard', 'Unknown', '2026-09-01', null, gen_random_uuid()
    );
  exception when insufficient_privilege then unknown_message := sqlerrm;
  end;
  begin
    perform public.create_feeding_plan(
      '4c450000-0000-0000-0000-000000000003',
      'standard', 'Cross stable', '2026-09-01', null, gen_random_uuid()
    );
  exception when insufficient_privilege then cross_message := sqlerrm;
  end;
  if unknown_message <> 'NUTRITION_UNAVAILABLE'
    or cross_message <> unknown_message
  then
    raise exception 'Nutrition unknown/cross-stable oracle diverged: %, %',
      unknown_message, cross_message;
  end if;
  if (
    select count(*) from public.feeding_plans
    where stable_id = '4c420000-0000-0000-0000-000000000002'
  ) <> 0 then
    raise exception 'Cross-stable control became visible';
  end if;
end;
$$;

insert into phase_4c4_ids
select 'lifecycle_plan', (
  public.create_feeding_plan(
    '4c450000-0000-0000-0000-000000000002',
    'standard', 'Lifecycle replay plan',
    '2026-09-01', '2026-09-02',
    '4c4f0000-0000-0000-0000-000000000001'
  )->>'feeding_plan_id'
)::uuid;
insert into phase_4c4_ids
select 'lifecycle_version', (
  public.create_feeding_plan_version(
    (select id from phase_4c4_ids where name = 'lifecycle_plan'),
    'user', null, 'Sensitive ration diagnosis CR-4C4-NEVER-EVENT',
    '4c4f0000-0000-0000-0000-000000000002'
  )->>'feeding_plan_version_id'
)::uuid;
insert into phase_4c4_ids
select 'lifecycle_item', (
  public.upsert_feeding_plan_item(
    (select id from phase_4c4_ids where name = 'lifecycle_version'),
    null, null, null, 'Lifecycle feed', null,
    'user_entered', 1, 'kg', 'bucket', 'morning', '08:00',
    null, null, 'lifecycle-key',
    '4c430000-0000-0000-0000-000000000004',
    null, null, null,
    '4c4f0000-0000-0000-0000-000000000003'
  )->>'feeding_plan_item_id'
)::uuid;
insert into phase_4c4_ids
select 'lifecycle_evening_item', (
  public.upsert_feeding_plan_item(
    (select id from phase_4c4_ids where name = 'lifecycle_version'),
    null, null, null, 'Lifecycle evening feed', null,
    'user_entered', 0.5, 'kg', 'bucket', 'evening', '18:00',
    null, null, 'lifecycle-evening',
    '4c430000-0000-0000-0000-000000000004',
    null, null, null,
    '4c4f0000-0000-0000-0000-00000000000d'
  )->>'feeding_plan_item_id'
)::uuid;
select public.approve_feeding_plan_version(
  (select id from phase_4c4_ids where name = 'lifecycle_version'),
  1,
  '4c4f0000-0000-0000-0000-000000000004'
);
select public.activate_feeding_plan_version(
  (select id from phase_4c4_ids where name = 'lifecycle_version'),
  2, '2026-09-02',
  '4c4f0000-0000-0000-0000-000000000005'
);

insert into phase_4c4_ids
select 'lifecycle_execution_item', occurrence.schedule_item_id
from public.feeding_occurrences occurrence
where occurrence.feeding_plan_item_id =
  (select id from phase_4c4_ids where name = 'lifecycle_item')
  and occurrence.occurrence_local_date = '2026-09-01';
select public.record_feeding_execution(
  (select id from phase_4c4_ids where name = 'lifecycle_execution_item'),
  null,
  '4c4f0000-0000-0000-0000-000000000006',
  'completed',
  '2026-09-01 06:00:00+00',
  '2026-09-01 06:10:00+00',
  '2026-09-01 08:10:00',
  'Europe/Amsterdam',
  'online', null, null,
  1, 'kg', 0, 'none', null, null
);

insert into phase_4c4_ids
select 'lifecycle_version_2', (
  public.create_feeding_plan_version(
    (select id from phase_4c4_ids where name = 'lifecycle_plan'),
    'user', null, 'Lifecycle replacement version',
    '4c4f0000-0000-0000-0000-000000000007'
  )->>'feeding_plan_version_id'
)::uuid;
insert into phase_4c4_ids
select 'lifecycle_item_2', (
  public.upsert_feeding_plan_item(
    (select id from phase_4c4_ids where name = 'lifecycle_version_2'),
    null, null, null, 'Lifecycle feed revised', null,
    'user_entered', 1.2, 'kg', 'bucket', 'morning', '08:00',
    null, null, 'lifecycle-key',
    '4c430000-0000-0000-0000-000000000004',
    null, null, null,
    '4c4f0000-0000-0000-0000-000000000008'
  )->>'feeding_plan_item_id'
)::uuid;
insert into phase_4c4_ids
select 'lifecycle_evening_item_2', (
  public.upsert_feeding_plan_item(
    (select id from phase_4c4_ids where name = 'lifecycle_version_2'),
    null, null, null, 'Lifecycle evening feed revised', null,
    'user_entered', 0.6, 'kg', 'bucket', 'evening', '18:00',
    null, null, 'lifecycle-evening',
    '4c430000-0000-0000-0000-000000000004',
    null, null, null,
    '4c4f0000-0000-0000-0000-00000000000e'
  )->>'feeding_plan_item_id'
)::uuid;
select public.approve_feeding_plan_version(
  (select id from phase_4c4_ids where name = 'lifecycle_version_2'),
  1,
  '4c4f0000-0000-0000-0000-000000000009'
);
select public.activate_feeding_plan_version(
  (select id from phase_4c4_ids where name = 'lifecycle_version_2'),
  2, '2026-09-02',
  '4c4f0000-0000-0000-0000-00000000000a'
);

do $$
begin
  if (
    select count(*)
    from public.feeding_occurrences occurrence
    where occurrence.occurrence_local_date = '2026-09-01'
      and occurrence.override_key = 'lifecycle-key'
      and occurrence.feeding_plan_version_id in (
        select version.id
        from public.feeding_plan_versions version
        where version.feeding_plan_id =
          (select id from phase_4c4_ids where name = 'lifecycle_plan')
      )
  ) <> 1 then
    raise exception 'Replacement version duplicated executed slot history';
  end if;
  if (
    select count(*)
    from public.feeding_occurrences occurrence
    join public.schedule_items item
      on item.id = occurrence.schedule_item_id
    where occurrence.feeding_plan_version_id =
      (select id from phase_4c4_ids where name = 'lifecycle_version_2')
      and occurrence.occurrence_local_date = '2026-09-01'
      and item.state = 'planned'
      and occurrence.override_key = 'lifecycle-evening'
  ) <> 1 then
    raise exception 'Executed morning slot suppressed unexecuted evening slot';
  end if;
  if (
    select count(*)
    from public.feeding_occurrences occurrence
    join public.schedule_items item
      on item.id = occurrence.schedule_item_id
    where occurrence.feeding_plan_version_id =
      (select id from phase_4c4_ids where name = 'lifecycle_version_2')
      and occurrence.occurrence_local_date = '2026-09-02'
      and item.state = 'planned'
  ) <> 2 then
    raise exception 'Replacement version missed future unexecuted slots';
  end if;
end;
$$;

select public.retire_feeding_plan(
  (select id from phase_4c4_ids where name = 'lifecycle_plan'),
  3, 'Lifecycle replay proof',
  '4c4f0000-0000-0000-0000-00000000000b'
);

do $$
declare
  replayed jsonb;
begin
  replayed := public.create_feeding_plan_version(
    (select id from phase_4c4_ids where name = 'lifecycle_plan'),
    'user', null, 'Sensitive ration diagnosis CR-4C4-NEVER-EVENT',
    '4c4f0000-0000-0000-0000-000000000002'
  );
  if (replayed->>'idempotent')::boolean is not true then
    raise exception 'Version create did not replay after plan retirement';
  end if;
  replayed := public.upsert_feeding_plan_item(
    (select id from phase_4c4_ids where name = 'lifecycle_version'),
    null, null, null, 'Lifecycle feed', null,
    'user_entered', 1, 'kg', 'bucket', 'morning', '08:00',
    null, null, 'lifecycle-key',
    '4c430000-0000-0000-0000-000000000004',
    null, null, null,
    '4c4f0000-0000-0000-0000-000000000003'
  );
  if (replayed->>'idempotent')::boolean is not true then
    raise exception 'Item upsert did not replay after approval/retirement';
  end if;
  replayed := public.approve_feeding_plan_version(
    (select id from phase_4c4_ids where name = 'lifecycle_version'),
    1,
    '4c4f0000-0000-0000-0000-000000000004'
  );
  if (replayed->>'idempotent')::boolean is not true then
    raise exception 'Approval did not replay after plan retirement';
  end if;
  replayed := public.activate_feeding_plan_version(
    (select id from phase_4c4_ids where name = 'lifecycle_version'),
    2, '2026-09-02',
    '4c4f0000-0000-0000-0000-000000000005'
  );
  if (replayed->>'idempotent')::boolean is not true then
    raise exception 'Activation did not replay after plan retirement';
  end if;
  replayed := public.retire_feeding_plan(
    (select id from phase_4c4_ids where name = 'lifecycle_plan'),
    3, 'Lifecycle replay proof',
    '4c4f0000-0000-0000-0000-00000000000b'
  );
  if (replayed->>'idempotent')::boolean is not true then
    raise exception 'Retirement exact retry failed';
  end if;
  if exists (
    select 1
    from public.schedule_assignments assignment
    join public.feeding_occurrences occurrence
      on occurrence.schedule_item_id = assignment.schedule_item_id
    join public.schedule_items schedule_item
      on schedule_item.id = occurrence.schedule_item_id
    where occurrence.feeding_plan_version_id in (
      select version.id
      from public.feeding_plan_versions version
      where version.feeding_plan_id =
        (select id from phase_4c4_ids where name = 'lifecycle_plan')
    )
      and schedule_item.state = 'cancelled'
      and assignment.status in ('assigned', 'accepted')
  ) then
    raise exception 'Retired plan retained an active assignment';
  end if;
end;
$$;

select public.archive_horse(
  '4c450000-0000-0000-0000-000000000002',
  '4c4f0000-0000-0000-0000-00000000000c',
  '4C.4 Horse-status RLS proof'
);
do $$
begin
  if not exists (
    select 1
    from public.feeding_plans
    where id = (select id from phase_4c4_ids where name = 'lifecycle_plan')
  ) or not exists (
    select 1
    from public.feeding_change_events
    where horse_id = '4c450000-0000-0000-0000-000000000002'
  ) then
    raise exception 'Legacy Horse archival changed canonical nutrition visibility or history';
  end if;
end;
$$;

reset role;

do $$
begin
  if (
    select count(*)
    from public.feeding_plans
    where id = '4c470000-0000-0000-0000-000000000099'
      and status = 'draft'
      and row_version = 1
  ) <> 1 then
    raise exception 'Control stable was mutated by 4C.4 tests';
  end if;
  if exists (
    select 1
    from private.feeding_mutation_receipts receipt
    where receipt.result::text ilike any (
      array[
        '%Timothy%',
        '%Horse left%',
        '%Calm appetite%',
        '%Corrected quantity%',
        '%CR-4C4-NEVER-EVENT%'
      ]
    )
  ) then
    raise exception 'Feeding receipt leaked domain text';
  end if;
  if exists (
    select 1
    from public.feeding_change_events event
    where event.reason ilike any (
      array[
        '%Timothy%',
        '%Horse left%',
        '%Calm appetite%',
        '%CR-4C4-NEVER-EVENT%'
      ]
    )
  ) then
    raise exception 'Feeding audit event leaked domain text';
  end if;
  if (
    select count(*)
    from public.feeding_change_events
    where execution_id in (
      select id
      from public.schedule_executions
      where schedule_item_id = (
        select id from phase_4c4_ids where name = 'execution_item'
      )
    )
  ) <> 2 then
    raise exception 'Feeding execution events are incomplete';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '', true);
rollback;
