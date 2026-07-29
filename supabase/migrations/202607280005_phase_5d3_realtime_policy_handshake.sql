-- Phase 5D.3: make the private Realtime authorization policy compatible with
-- Supabase's channel-join probe while preserving topic-level least privilege.

create or replace function private.rotate_sync_authority()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_stable_id uuid;
  next_version bigint;
  topic_row record;
  wake_id uuid;
begin
  if tg_table_schema = 'public' and tg_table_name = 'stables' then
    target_stable_id := coalesce(new.id, old.id);
  else
    target_stable_id := coalesce(new.stable_id, old.stable_id);
  end if;
  insert into public.stable_sync_authorities (stable_id, authority_version)
  values (target_stable_id, 2)
  on conflict (stable_id) do update
  set
    authority_version =
      public.stable_sync_authorities.authority_version + 1,
    updated_at = timezone('utc', now())
  returning authority_version into next_version;

  for topic_row in
    select topic_token
    from private.realtime_channel_topics
    where stable_id = target_stable_id
  loop
    wake_id := gen_random_uuid();
    perform realtime.send(
      jsonb_build_object(
        'authority_version', next_version,
        'id', wake_id
      ),
      'change_available',
      topic_row.topic_token::text,
      true
    );
    if not exists (
      select 1
      from realtime.messages message
      where message.topic = topic_row.topic_token::text
        and message.event = 'change_available'
        and message.private is true
        and message.payload->>'id' = wake_id::text
        and message.payload->>'authority_version' = next_version::text
    ) then
      raise exception using
        errcode = 'P0001',
        message = 'REALTIME_WAKE_FAILED';
    end if;
  end loop;

  update private.realtime_channel_topics
  set
    topic_token = gen_random_uuid(),
    authority_version = next_version,
    rotated_at = timezone('utc', now())
  where stable_id = target_stable_id;

  update public.client_sync_devices
  set
    status = 'revoked',
    revoked_at = timezone('utc', now()),
    last_seen_at = timezone('utc', now())
  where stable_id = target_stable_id
    and status = 'active';
  return null;
end;
$$;

revoke all on function private.rotate_sync_authority()
  from public, anon, authenticated;

revoke execute on function private.can_join_realtime_topic(text)
  from public, anon;
grant execute on function private.can_join_realtime_topic(text)
  to authenticated;

alter policy realtime_messages_private_read
on realtime.messages
using (
  private.can_join_realtime_topic(realtime.topic())
);

-- Hosted Supabase owns realtime.messages as supabase_realtime_admin. The
-- project postgres role may alter its policies but cannot always attach policy
-- comments. Keep this non-security metadata best-effort so a fresh hosted
-- deployment does not roll back the authorization fix.
do $$
begin
  comment on policy realtime_messages_private_read on realtime.messages is
    'Private channel joins are authorized by opaque topic, active membership, '
    'current authority version, and current Horse capability. Realtime join '
    'probes do not expose message extension/private columns as stored rows.';
exception
  when insufficient_privilege then
    raise notice
      'Skipping realtime policy comment: hosted owner retains metadata control';
end;
$$;
