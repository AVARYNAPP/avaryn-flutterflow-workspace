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
    ('4b210000-0000-0000-0000-000000000001', 'identity-owner-a@example.invalid'),
    ('4b210000-0000-0000-0000-000000000002', 'identity-admin-a@example.invalid'),
    ('4b210000-0000-0000-0000-000000000003', 'identity-member-a@example.invalid'),
    ('4b210000-0000-0000-0000-000000000004', 'identity-viewer-a@example.invalid'),
    ('4b220000-0000-0000-0000-000000000001', 'identity-owner-b@example.invalid')
) as fixture(id, email);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values
  (
    '4b230000-0000-0000-0000-000000000001',
    'organization',
    'Identity stable A',
    'active',
    'UTC',
    'nl',
    '4b210000-0000-0000-0000-000000000001',
    '4b240000-0000-0000-0000-000000000001'
  ),
  (
    '4b230000-0000-0000-0000-000000000002',
    'organization',
    'Identity control stable B',
    'active',
    'UTC',
    'nl',
    '4b220000-0000-0000-0000-000000000001',
    '4b240000-0000-0000-0000-000000000002'
  );

insert into public.stable_members (
  id, stable_id, display_name, status, source
)
values
  ('4b250000-0000-0000-0000-000000000001', '4b230000-0000-0000-0000-000000000001', 'Owner A', 'active', 'owner_creation'),
  ('4b250000-0000-0000-0000-000000000002', '4b230000-0000-0000-0000-000000000001', 'Admin A', 'active', 'manual'),
  ('4b250000-0000-0000-0000-000000000003', '4b230000-0000-0000-0000-000000000001', 'Member A', 'active', 'manual'),
  ('4b250000-0000-0000-0000-000000000004', '4b230000-0000-0000-0000-000000000001', 'Viewer A', 'active', 'manual'),
  ('4b250000-0000-0000-0000-000000000005', '4b230000-0000-0000-0000-000000000001', 'Inactive roster A', 'inactive', 'manual'),
  ('4b250000-0000-0000-0000-000000000006', '4b230000-0000-0000-0000-000000000002', 'Owner B', 'active', 'owner_creation');

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values
  ('4b260000-0000-0000-0000-000000000001', '4b230000-0000-0000-0000-000000000001', '4b210000-0000-0000-0000-000000000001', '4b250000-0000-0000-0000-000000000001', 'owner', 'active', now()),
  ('4b260000-0000-0000-0000-000000000002', '4b230000-0000-0000-0000-000000000001', '4b210000-0000-0000-0000-000000000002', '4b250000-0000-0000-0000-000000000002', 'admin', 'active', now()),
  ('4b260000-0000-0000-0000-000000000003', '4b230000-0000-0000-0000-000000000001', '4b210000-0000-0000-0000-000000000003', '4b250000-0000-0000-0000-000000000003', 'member', 'active', now()),
  ('4b260000-0000-0000-0000-000000000004', '4b230000-0000-0000-0000-000000000001', '4b210000-0000-0000-0000-000000000004', '4b250000-0000-0000-0000-000000000004', 'viewer', 'active', now()),
  ('4b260000-0000-0000-0000-000000000005', '4b230000-0000-0000-0000-000000000002', '4b220000-0000-0000-0000-000000000001', '4b250000-0000-0000-0000-000000000006', 'owner', 'active', now());

set constraints all immediate;

insert into public.horses (
  id, stable_id, display_name, source_kind,
  created_by_user_id, created_request_id
)
values
  ('4b270000-0000-0000-0000-000000000001', '4b230000-0000-0000-0000-000000000001', 'Identity Horse A', 'manual', '4b210000-0000-0000-0000-000000000001', '4b280000-0000-0000-0000-000000000001'),
  ('4b270000-0000-0000-0000-000000000002', '4b230000-0000-0000-0000-000000000001', 'Second Horse A', 'manual', '4b210000-0000-0000-0000-000000000001', '4b280000-0000-0000-0000-000000000002'),
  ('4b270000-0000-0000-0000-000000000003', '4b230000-0000-0000-0000-000000000002', 'Control Horse B', 'manual', '4b220000-0000-0000-0000-000000000001', '4b280000-0000-0000-0000-000000000003');

insert into public.horse_access_grants (
  stable_id, horse_id, membership_id, category,
  can_view, can_edit, granted_by_user_id, granted_request_id, grant_reason
)
values
  ('4b230000-0000-0000-0000-000000000001', '4b270000-0000-0000-0000-000000000001', '4b260000-0000-0000-0000-000000000003', 'horse.identity', true, true, '4b210000-0000-0000-0000-000000000001', '4b290000-0000-0000-0000-000000000001', 'Identity editing for fixture'),
  ('4b230000-0000-0000-0000-000000000001', '4b270000-0000-0000-0000-000000000001', '4b260000-0000-0000-0000-000000000004', 'horse.identity', true, false, '4b210000-0000-0000-0000-000000000001', '4b290000-0000-0000-0000-000000000002', 'Identity viewing for fixture');

do $$
begin
  if not (select relrowsecurity from pg_class where oid = 'public.horse_identifiers'::regclass)
    or not (select relrowsecurity from pg_class where oid = 'public.horse_relationships'::regclass)
    or has_table_privilege('authenticated', 'public.horse_identifiers', 'INSERT')
    or has_table_privilege('authenticated', 'public.horse_identifiers', 'UPDATE')
    or has_table_privilege('authenticated', 'public.horse_identifiers', 'DELETE')
    or has_table_privilege('authenticated', 'public.horse_relationships', 'INSERT')
    or has_table_privilege('authenticated', 'public.horse_relationships', 'UPDATE')
    or has_table_privilege('authenticated', 'public.horse_relationships', 'DELETE')
  then
    raise exception '4C.2B RLS or direct-DML privileges are incorrect';
  end if;
end;
$$;

do $$
begin
  begin
    insert into public.horse_identifiers (
      stable_id, horse_id, identifier_type, identifier_value,
      created_by_user_id, created_request_id,
      last_mutated_by_user_id, last_mutation_request_id
    )
    values (
      '4b230000-0000-0000-0000-000000000001',
      '4b270000-0000-0000-0000-000000000003',
      'chip',
      'cross-stable',
      '4b210000-0000-0000-0000-000000000001',
      gen_random_uuid(),
      '4b210000-0000-0000-0000-000000000001',
      gen_random_uuid()
    );
    raise exception 'Cross-stable identifier passed the Horse FK';
  exception when foreign_key_violation then null;
  end;
  begin
    insert into public.horse_relationships (
      stable_id, horse_id, stable_member_id, relationship_type,
      created_by_user_id, created_request_id
    )
    values (
      '4b230000-0000-0000-0000-000000000001',
      '4b270000-0000-0000-0000-000000000001',
      '4b250000-0000-0000-0000-000000000006',
      'trainer',
      '4b210000-0000-0000-0000-000000000001',
      gen_random_uuid()
    );
    raise exception 'Cross-stable relationship passed the roster FK';
  exception when foreign_key_violation then null;
  end;
end;
$$;

create temp table phase_4c2b_ids (
  name text primary key,
  id uuid not null
) on commit drop;
grant select, insert on phase_4c2b_ids to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '4b210000-0000-0000-0000-000000000001', true);

insert into phase_4c2b_ids
select
  'identifier',
  (
    public.upsert_horse_identifier(
      '4b270000-0000-0000-0000-000000000001',
      null,
      null,
      '4b2a0000-0000-0000-0000-000000000001',
      'chip',
      '  528210004567890  ',
      '  AVARYN Registry  ',
      'be',
      '2024-01-01',
      null
    )
  ).id;

do $$
declare
  duplicate_id uuid;
begin
  duplicate_id := (
    public.upsert_horse_identifier(
      '4b270000-0000-0000-0000-000000000001',
      null,
      null,
      '4b2a0000-0000-0000-0000-000000000001',
      'chip',
      '528210004567890',
      'AVARYN Registry',
      'BE',
      '2024-01-01',
      null
    )
  ).id;
  if duplicate_id <> (select id from phase_4c2b_ids where name = 'identifier')
    or not exists (
      select 1
      from public.horse_identifiers
      where id = duplicate_id
        and identifier_value = '528210004567890'
        and issuer = 'AVARYN Registry'
        and country_code = 'BE'
        and source_kind = 'user'
        and verification_status = 'unverified'
        and row_version = 1
    )
  then
    raise exception 'Identifier create normalization/idempotency failed';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '4b210000-0000-0000-0000-000000000003', true);
select public.upsert_horse_identifier(
  '4b270000-0000-0000-0000-000000000001',
  (select id from phase_4c2b_ids where name = 'identifier'),
  1,
  '4b2a0000-0000-0000-0000-000000000002',
  'chip',
  '528210004567891',
  'AVARYN Registry',
  'BE',
  '2024-01-01',
  null
);

select set_config('request.jwt.claim.sub', '4b210000-0000-0000-0000-000000000001', true);
do $$
declare
  replayed public.horse_identifiers%rowtype;
begin
  replayed := public.upsert_horse_identifier(
    '4b270000-0000-0000-0000-000000000001',
    null,
    null,
    '4b2a0000-0000-0000-0000-000000000001',
    'chip',
    '528210004567890',
    'AVARYN Registry',
    'BE',
    '2024-01-01',
    null
  );
  if replayed.id <> (select id from phase_4c2b_ids where name = 'identifier')
    or replayed.row_version <> 2
    or (
      select count(*)
      from public.horse_identifiers
      where horse_id = '4b270000-0000-0000-0000-000000000001'
    ) <> 1
  then
    raise exception 'Durable create request replay was reapplied or lost';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '4b210000-0000-0000-0000-000000000003', true);
do $$
begin
  begin
    perform public.upsert_horse_identifier(
      '4b270000-0000-0000-0000-000000000001',
      (select id from phase_4c2b_ids where name = 'identifier'),
      1,
      gen_random_uuid(),
      'chip',
      'stale-write',
      null,
      null,
      null,
      null
    );
    raise exception 'Stale identifier row version was accepted';
  exception when serialization_failure then
    if sqlerrm <> 'ROW_VERSION_CONFLICT' then raise; end if;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '4b210000-0000-0000-0000-000000000004', true);
do $$
begin
  if (select count(*) from public.horse_identifiers) <> 1 then
    raise exception 'Viewer did not receive its explicit identity view';
  end if;
  begin
    perform public.upsert_horse_identifier(
      '4b270000-0000-0000-0000-000000000001',
      (select id from phase_4c2b_ids where name = 'identifier'),
      2,
      gen_random_uuid(),
      'chip',
      'viewer-write',
      null,
      null,
      null,
      null
    );
    raise exception 'Viewer changed a Horse identifier';
  exception when insufficient_privilege then
    if sqlerrm <> 'NOT_AUTHORIZED' then raise; end if;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '4b210000-0000-0000-0000-000000000002', true);
do $$
begin
  if (select count(*) from public.horse_identifiers) <> 0 then
    raise exception 'Admin received automatic Horse identity access';
  end if;
  begin
    perform public.upsert_horse_identifier(
      '4b270000-0000-0000-0000-000000000001',
      null,
      null,
      gen_random_uuid(),
      'passport',
      'admin-without-grant',
      null,
      null,
      null,
      null
    );
    raise exception 'Admin edited identity without an explicit grant';
  exception when insufficient_privilege then
    if sqlerrm <> 'NOT_AUTHORIZED' then raise; end if;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '4b210000-0000-0000-0000-000000000003', true);
do $$
begin
  if (select count(*) from public.horse_relationships) <> 0 then
    raise exception 'Identity grant or roster relationship granted team access';
  end if;
  if (select count(*) from public.horses) <> 0 then
    raise exception 'Roster relationship granted implicit Horse Basic access';
  end if;
  begin
    perform public.add_horse_relationship(
      '4b270000-0000-0000-0000-000000000001',
      '4b250000-0000-0000-0000-000000000003',
      'rider',
      gen_random_uuid()
    );
    raise exception 'Member managed a Horse relationship';
  exception when insufficient_privilege then
    if sqlerrm <> 'RELATIONSHIP_UNAVAILABLE' then raise; end if;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '4b210000-0000-0000-0000-000000000001', true);
insert into phase_4c2b_ids
select
  'relationship',
  (
    public.add_horse_relationship(
      '4b270000-0000-0000-0000-000000000001',
      '4b250000-0000-0000-0000-000000000003',
      'rider',
      '4b2b0000-0000-0000-0000-000000000001',
      '2025-01-01',
      'Primary rider'
    )->>'relationship_id'
  )::uuid;

do $$
declare
  duplicate_id uuid;
begin
  duplicate_id := (
    public.add_horse_relationship(
      '4b270000-0000-0000-0000-000000000001',
      '4b250000-0000-0000-0000-000000000003',
      'rider',
      '4b2b0000-0000-0000-0000-000000000001',
      '2025-01-01',
      'Primary rider'
    )->>'relationship_id'
  )::uuid;
  if duplicate_id <> (select id from phase_4c2b_ids where name = 'relationship')
    or (
      select count(*)
      from public.horse_relationships
      where horse_id = '4b270000-0000-0000-0000-000000000001'
        and stable_member_id = '4b250000-0000-0000-0000-000000000003'
        and relationship_type = 'rider'
        and status = 'active'
    ) <> 1
  then
    raise exception 'Relationship create/idempotency failed';
  end if;
  begin
    perform public.add_horse_relationship(
      '4b270000-0000-0000-0000-000000000001',
      '4b250000-0000-0000-0000-000000000005',
      'trainer',
      gen_random_uuid()
    );
    raise exception 'Inactive rosterperson received a relationship';
  exception when insufficient_privilege then
    if sqlerrm <> 'STABLE_MEMBER_UNAVAILABLE' then raise; end if;
  end;
  begin
    perform public.add_horse_relationship(
      '4b270000-0000-0000-0000-000000000001',
      '4b250000-0000-0000-0000-000000000006',
      'trainer',
      gen_random_uuid()
    );
    raise exception 'Cross-stable rosterperson received a relationship';
  exception when insufficient_privilege then
    if sqlerrm <> 'STABLE_MEMBER_UNAVAILABLE' then raise; end if;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '4b210000-0000-0000-0000-000000000002', true);
do $$
declare
  aliased jsonb;
begin
  aliased := public.add_horse_relationship(
    '4b270000-0000-0000-0000-000000000001',
    '4b250000-0000-0000-0000-000000000003',
    'rider',
    '4b2b0000-0000-0000-0000-000000000003',
    '2025-01-01',
    'Primary rider'
  );
  if (aliased->>'relationship_id')::uuid
      <> (select id from phase_4c2b_ids where name = 'relationship')
    or (aliased->>'idempotent')::boolean is not true
  then
    raise exception 'Equivalent active relationship request was not receipted';
  end if;
end;
$$;

select public.end_horse_relationship(
  (select id from phase_4c2b_ids where name = 'relationship'),
  1,
  '4b2b0000-0000-0000-0000-000000000002',
  '2026-01-01'
);
select public.end_horse_relationship(
  (select id from phase_4c2b_ids where name = 'relationship'),
  1,
  '4b2b0000-0000-0000-0000-000000000002',
  '2026-01-01'
);

do $$
declare
  replayed jsonb;
begin
  replayed := public.add_horse_relationship(
    '4b270000-0000-0000-0000-000000000001',
    '4b250000-0000-0000-0000-000000000003',
    'rider',
    '4b2b0000-0000-0000-0000-000000000003',
    '2025-01-01',
    'Primary rider'
  );
  if (replayed->>'relationship_id')::uuid
      <> (select id from phase_4c2b_ids where name = 'relationship')
    or (replayed->>'idempotent')::boolean is not true
    or (replayed->>'row_version')::bigint <> 2
    or exists (
      select 1
      from public.horse_relationships
      where horse_id = '4b270000-0000-0000-0000-000000000001'
        and stable_member_id = '4b250000-0000-0000-0000-000000000003'
        and relationship_type = 'rider'
        and status = 'active'
    )
  then
    raise exception 'Receipted relationship replay recreated ended access';
  end if;
  begin
    perform public.add_horse_relationship(
      '4b270000-0000-0000-0000-000000000001',
      '4b250000-0000-0000-0000-000000000003',
      'rider',
      '4b2b0000-0000-0000-0000-000000000003',
      '2025-01-01',
      'Different payload'
    );
    raise exception 'Relationship request ID was reused with another payload';
  exception when invalid_parameter_value then
    if sqlerrm <> 'REQUEST_ID_REUSED' then raise; end if;
  end;
end;
$$;

reset role;
do $$
begin
  if not exists (
    select 1
    from public.horse_relationships
    where id = (select id from phase_4c2b_ids where name = 'relationship')
      and status = 'ended'
      and valid_until = '2026-01-01'
      and row_version = 2
  ) then
    raise exception 'Relationship end lifecycle is incorrect';
  end if;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '4b220000-0000-0000-0000-000000000001', true);
do $$
declare
  observed text[] := '{}'::text[];
begin
  begin
    perform public.end_horse_relationship(
      (select id from phase_4c2b_ids where name = 'relationship'),
      2,
      gen_random_uuid(),
      current_date
    );
  exception when insufficient_privilege then
    observed := array_append(observed, sqlerrm);
  end;
  begin
    perform public.end_horse_relationship(
      '4b2b9999-0000-0000-0000-000000000999',
      1,
      gen_random_uuid(),
      current_date
    );
  exception when insufficient_privilege then
    observed := array_append(observed, sqlerrm);
  end;
  if observed <> array[
    'RELATIONSHIP_UNAVAILABLE',
    'RELATIONSHIP_UNAVAILABLE'
  ]::text[] then
    raise exception 'Relationship oracle leaked cross-stable state: %', observed;
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '4b210000-0000-0000-0000-000000000001', true);
do $$
declare
  observed text[] := '{}'::text[];
begin
  begin
    perform public.upsert_horse_identifier(
      '4b270000-0000-0000-0000-000000000003',
      null, null, gen_random_uuid(), 'chip', 'oracle', null, null, null, null
    );
  exception when insufficient_privilege then
    observed := array_append(observed, sqlerrm);
  end;
  begin
    perform public.upsert_horse_identifier(
      '4b279999-0000-0000-0000-000000000999',
      null, null, gen_random_uuid(), 'chip', 'oracle', null, null, null, null
    );
  exception when insufficient_privilege then
    observed := array_append(observed, sqlerrm);
  end;
  if observed <> array['HORSE_UNAVAILABLE', 'HORSE_UNAVAILABLE']::text[] then
    raise exception 'Identifier Horse oracle leaked: %', observed;
  end if;
end;
$$;

do $$
declare
  relation_name text;
begin
  foreach relation_name in array array[
    'horse_identifiers',
    'horse_relationships'
  ] loop
    begin
      execute format('insert into public.%I default values', relation_name);
      raise exception 'Authenticated inserted directly into %', relation_name;
    exception when insufficient_privilege then null;
    end;
    begin
      execute format('update public.%I set updated_at = updated_at', relation_name);
      raise exception 'Authenticated updated directly in %', relation_name;
    exception when insufficient_privilege then null;
    end;
    begin
      execute format('delete from public.%I', relation_name);
      raise exception 'Authenticated deleted directly from %', relation_name;
    exception when insufficient_privilege then null;
    end;
  end loop;
end;
$$;

reset role;
set local role anon;
select set_config('request.jwt.claim.role', 'anon', true);
select set_config('request.jwt.claim.sub', '', true);
do $$
declare
  relation_name text;
begin
  foreach relation_name in array array[
    'horse_identifiers',
    'horse_relationships'
  ] loop
    begin
      execute format('select count(*) from public.%I', relation_name);
      raise exception 'Anonymous read %', relation_name;
    exception when insufficient_privilege then null;
    end;
  end loop;
  begin
    perform public.add_horse_relationship(
      '4b270000-0000-0000-0000-000000000001',
      '4b250000-0000-0000-0000-000000000003',
      'rider',
      gen_random_uuid()
    );
    raise exception 'Anonymous executed relationship RPC';
  exception when insufficient_privilege then null;
  end;
end;
$$;

reset role;
do $$
begin
  if (
    select count(*) from public.horse_identifiers
    where stable_id = '4b230000-0000-0000-0000-000000000002'
  ) <> 0
    or (
      select count(*) from public.horse_relationships
      where stable_id = '4b230000-0000-0000-0000-000000000002'
    ) <> 0
    or (
      select count(*) from public.horses
      where stable_id = '4b230000-0000-0000-0000-000000000002'
    ) <> 1
  then
    raise exception '4C.2B changed the control stable';
  end if;
end;
$$;

rollback;
