\set ON_ERROR_STOP on

\if :{?avaryn_local_test}
\else
  \echo 'Refusing Phase 5D.3 SQL: avaryn_local_test is required.'
  select 1 / 0;
\endif

\set QUIET 1
select :'avaryn_local_test' = '1' as phase_5d3_guard
\gset
\set QUIET 0
\if :phase_5d3_guard
\else
  \echo 'Refusing Phase 5D.3 SQL: local test guard is invalid.'
  select 1 / 0;
\endif

begin;

do $$
declare
  policy_qual text;
begin
  if has_function_privilege(
    'anon',
    'private.can_join_realtime_topic(text)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'private.can_join_realtime_topic(text)',
    'EXECUTE'
  ) then
    raise exception 'Realtime topic function ACL is not authenticated-only';
  end if;

  select qual into policy_qual
  from pg_policies
  where schemaname = 'realtime'
    and tablename = 'messages'
    and policyname = 'realtime_messages_private_read'
    and cmd = 'SELECT';

  if policy_qual is null
    or policy_qual not like '%can_join_realtime_topic%'
    or policy_qual like '%extension%'
    or policy_qual like '%private IS TRUE%'
  then
    raise exception 'Realtime join policy is not handshake-compatible';
  end if;
end;
$$;

create temporary table phase_5d3_results (
  name text primary key,
  value jsonb not null
) on commit drop;
grant select, insert on phase_5d3_results to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '5c000000-0000-0000-0000-000000000006',
  true
);

insert into phase_5d3_results(name, value)
values (
  'groom_topics',
  public.get_realtime_topics(
    '5ca00000-0000-0000-0000-000000000001'
  )
);

do $$
declare
  topics jsonb;
  topic jsonb;
begin
  select value into topics
  from phase_5d3_results
  where name = 'groom_topics';

  if jsonb_array_length(topics->'topics') = 0 then
    raise exception 'Assigned groom did not receive a private Realtime topic';
  end if;

  for topic in
    select value from jsonb_array_elements(topics->'topics')
  loop
    if not private.can_join_realtime_topic(topic->>'topic') then
      raise exception 'Assigned groom could not join an issued topic';
    end if;
  end loop;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '5c000000-0000-0000-0000-000000000011',
  true
);

do $$
declare
  topic jsonb;
begin
  for topic in
    select topic_row.value
    from phase_5d3_results result
    cross join lateral jsonb_array_elements(result.value->'topics') topic_row
    where result.name = 'groom_topics'
  loop
    if private.can_join_realtime_topic(topic->>'topic') then
      raise exception 'Cross-stable owner joined stable A Realtime topic';
    end if;
  end loop;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '5c000000-0000-0000-0000-000000000009',
  true
);

do $$
declare
  topic jsonb;
begin
  for topic in
    select topic_row.value
    from phase_5d3_results result
    cross join lateral jsonb_array_elements(result.value->'topics') topic_row
    where result.name = 'groom_topics'
  loop
    if private.can_join_realtime_topic(topic->>'topic') then
      raise exception 'Revoked fixture user joined stable A Realtime topic';
    end if;
  end loop;
end;
$$;

select set_config(
  'request.jwt.claim.sub',
  '5c000000-0000-0000-0000-000000000001',
  true
);

select public.suspend_stable_membership(
  '5cc00000-0000-0000-0000-000000000006',
  '5d300000-0000-0000-0000-000000000001'
);

reset role;

do $$
begin
  if not exists (
    select 1
    from realtime.messages message
    join phase_5d3_results result
      on result.name = 'groom_topics'
    where message.event = 'change_available'
      and message.private is true
      and message.topic in (
        select topic_row.value->>'topic'
        from jsonb_array_elements(result.value->'topics') topic_row
      )
      and message.payload ? 'authority_version'
      and message.payload = jsonb_build_object(
        'authority_version',
        message.payload->'authority_version',
        'id',
        message.payload->'id'
      )
      and not (message.payload ? 'stable_id')
      and not (message.payload ? 'membership_id')
      and not (message.payload ? 'user_id')
  ) then
    raise exception 'Authority rotation did not wake prior private topics';
  end if;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config(
  'request.jwt.claim.sub',
  '5c000000-0000-0000-0000-000000000006',
  true
);

do $$
declare
  topic jsonb;
begin
  for topic in
    select topic_row.value
    from phase_5d3_results result
    cross join lateral jsonb_array_elements(result.value->'topics') topic_row
    where result.name = 'groom_topics'
  loop
    if private.can_join_realtime_topic(topic->>'topic') then
      raise exception 'Rotated topic remained valid after membership suspend';
    end if;
  end loop;

  begin
    perform public.get_realtime_topics(
      '5ca00000-0000-0000-0000-000000000001'
    );
    raise exception 'Suspended groom received replacement Realtime topics';
  exception
    when sqlstate '42501' then
      if sqlerrm <> 'SYNC_UNAVAILABLE' then
        raise;
      end if;
  end;
end;
$$;

reset role;
set local role anon;

do $$
begin
  begin
    perform private.can_join_realtime_topic(gen_random_uuid()::text);
    raise exception 'Anonymous client executed private topic authorization';
  exception
    when insufficient_privilege then
      null;
  end;
end;
$$;

reset role;
rollback;

\echo 'PASS: Phase 5D.3 Realtime ACL, isolation, and rotation are green.'
