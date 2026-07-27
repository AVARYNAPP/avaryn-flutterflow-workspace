begin;

do $$
declare
  stable_a uuid := gen_random_uuid();
  stable_b uuid := gen_random_uuid();
  owner_a uuid := gen_random_uuid();
  owner_b uuid := gen_random_uuid();
  roster_a uuid := gen_random_uuid();
  roster_b uuid := gen_random_uuid();
  membership_a uuid := gen_random_uuid();
  membership_b uuid := gen_random_uuid();
  horse_a uuid := gen_random_uuid();
  rejected_request uuid := gen_random_uuid();
  existing_types constant text[] := array[
    'stable_created',
    'stable_updated',
    'invitation_created',
    'invitation_resent',
    'invitation_revoked',
    'invitation_accepted',
    'invitation_declined',
    'role_changed',
    'membership_removed',
    'membership_suspended',
    'membership_left',
    'stable_member_linked',
    'ownership_transferred',
    'stable_archived'
  ];
  event_name text;
  before_b_count bigint;
  after_b_count bigint;
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
    created_at, updated_at
  )
  values
    (
      '00000000-0000-0000-0000-000000000000', owner_a,
      'authenticated', 'authenticated', 'phase4c2a0-a@example.invalid', '',
      now(), '{}', '{}', now(), now()
    ),
    (
      '00000000-0000-0000-0000-000000000000', owner_b,
      'authenticated', 'authenticated', 'phase4c2a0-b@example.invalid', '',
      now(), '{}', '{}', now(), now()
    );

  insert into public.stables (
    id, kind, name, status, timezone, locale,
    created_by_user_id, creation_request_id
  )
  values
    (
      stable_a, 'organization', '4C.2A0 test stable A', 'active', 'UTC', 'en',
      owner_a, gen_random_uuid()
    ),
    (
      stable_b, 'organization', '4C.2A0 control stable B', 'active', 'UTC', 'en',
      owner_b, gen_random_uuid()
    );

  insert into public.stable_members (
    id, stable_id, display_name, source
  )
  values
    (roster_a, stable_a, '4C.2A0 owner A', 'owner_creation'),
    (roster_b, stable_b, '4C.2A0 owner B', 'owner_creation');

  insert into public.stable_memberships (
    id, stable_id, user_id, stable_member_id, role, status, joined_at
  )
  values
    (membership_a, stable_a, owner_a, roster_a, 'owner', 'active', now()),
    (membership_b, stable_b, owner_b, roster_b, 'owner', 'active', now());

  set constraints all immediate;
  set constraints all deferred;

  -- Phase 4C.2A adds the typed same-stable FK that 4C.2A0 deliberately
  -- deferred. Keep exercising the 4C.2A0 event contract with a real Horse.
  insert into public.horses (
    id,
    stable_id,
    display_name,
    source_kind,
    created_by_user_id,
    created_request_id
  )
  values (
    horse_a,
    stable_a,
    '4C.2A0 compatibility Horse',
    'manual',
    owner_a,
    gen_random_uuid()
  );

  select count(*) into before_b_count
  from public.stable_security_events
  where stable_id = stable_b;

  foreach event_name in array existing_types loop
    insert into public.stable_security_events (
      stable_id, actor_user_id, actor_membership_id, event_type
    )
    values (stable_a, owner_a, membership_a, event_name);
  end loop;

  if (
    select count(*)
    from public.stable_security_events
    where stable_id = stable_a
      and event_type = any(existing_types)
      and horse_id is null
  ) <> cardinality(existing_types) then
    raise exception 'Existing phase-4B event types were not preserved';
  end if;

  begin
    insert into public.stable_security_events (
      stable_id, actor_user_id, actor_membership_id, event_type
    )
    values (stable_a, owner_a, membership_a, 'unknown_event');
    raise exception 'Unknown event type was accepted';
  exception when check_violation then
    null;
  end;

  foreach event_name in array array[
    'horse_access_granted',
    'horse_access_revoked'
  ] loop
    begin
      insert into public.stable_security_events (
        stable_id, actor_user_id, actor_membership_id, event_type
      )
      values (stable_a, owner_a, membership_a, event_name);
      raise exception 'Horse event without horse_id was accepted: %', event_name;
    exception when check_violation then
      null;
    end;

    insert into public.stable_security_events (
      stable_id, actor_user_id, actor_membership_id, event_type, horse_id
    )
    values (stable_a, owner_a, membership_a, event_name, horse_a);
  end loop;

  begin
    insert into public.stable_security_events (
      stable_id, actor_user_id, actor_membership_id,
      event_type, horse_id
    )
    values (stable_a, owner_a, membership_a, 'stable_updated', horse_a);
    raise exception 'Phase-4B event with horse_id was accepted';
  exception when check_violation then
    null;
  end;

  begin
    perform private.write_security_event(
      stable_a,
      'unknown_event',
      membership_a,
      null,
      null,
      null,
      rejected_request,
      '{}'::jsonb
    );
    raise exception 'Rejected writer call committed an event';
  exception when check_violation then
      null;
  end;

  if exists (
    select 1
    from public.stable_security_events
    where request_id = rejected_request
  ) then
    raise exception 'Rejected writer call left an event';
  end if;

  perform set_config('request.jwt.claim.sub', owner_a::text, true);
  perform private.write_security_event(
    stable_a,
    'stable_updated',
    membership_a,
    null,
    null,
    null,
    gen_random_uuid(),
    '{}'::jsonb
  );

  if not exists (
    select 1
    from public.stable_security_events e
    where e.stable_id = stable_a
      and e.actor_user_id = owner_a
      and e.actor_membership_id = membership_a
      and e.event_type = 'stable_updated'
      and e.horse_id is null
  ) then
    raise exception 'Existing phase-4B event writer changed behavior';
  end if;

  select count(*) into after_b_count
  from public.stable_security_events
  where stable_id = stable_b;

  if after_b_count <> before_b_count then
    raise exception 'Control stable was modified';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  (
    select actor_user_id::text
    from public.stable_security_events
    where event_type = 'stable_created'
    order by id desc
    limit 1
  ),
  true
);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $$
declare
  operation_name text;
begin
  foreach operation_name in array array['insert', 'update', 'delete'] loop
    begin
      if operation_name = 'insert' then
        insert into public.stable_security_events (
          stable_id, event_type
        )
        values (gen_random_uuid(), 'stable_updated');
      elsif operation_name = 'update' then
        update public.stable_security_events
        set metadata = metadata;
      else
        delete from public.stable_security_events;
      end if;
      raise exception 'Direct authenticated % unexpectedly succeeded',
        operation_name;
    exception when insufficient_privilege then
      null;
    end;
  end loop;
end;
$$;

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'anon', true);

do $$
begin
  begin
    insert into public.stable_security_events (
      stable_id, event_type
    )
    values (gen_random_uuid(), 'stable_updated');
    raise exception 'Direct anon insert unexpectedly succeeded';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

rollback;
