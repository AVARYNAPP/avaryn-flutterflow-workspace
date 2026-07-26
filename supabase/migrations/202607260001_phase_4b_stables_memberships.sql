begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table public.stables (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('organization', 'personal')),
  name text not null check (length(btrim(name)) between 1 and 120),
  status text not null default 'active'
    check (status in ('active', 'archived')),
  timezone text not null check (length(btrim(timezone)) between 1 and 100),
  locale text not null default 'nl'
    check (length(btrim(locale)) between 2 and 16),
  created_by_user_id uuid not null references auth.users (id),
  creation_request_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  constraint stables_creation_request_unique
    unique (created_by_user_id, creation_request_id),
  constraint stables_archive_timestamp
    check (
      (status = 'active' and archived_at is null)
      or (status = 'archived' and archived_at is not null)
    )
);

create table public.stable_members (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  display_name text not null
    check (length(btrim(display_name)) between 1 and 120),
  function_title text
    check (
      function_title is null
      or length(btrim(function_title)) between 1 and 120
    ),
  status text not null default 'active'
    check (status in ('active', 'inactive', 'archived')),
  legacy_local_member_id text,
  source text not null
    check (source in ('owner_creation', 'invitation', 'manual', 'legacy_link')),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  archived_at timestamptz,
  constraint stable_members_stable_and_id_unique unique (stable_id, id),
  constraint stable_members_legacy_not_blank
    check (
      legacy_local_member_id is null
      or length(btrim(legacy_local_member_id)) > 0
    ),
  constraint stable_members_archive_timestamp
    check (
      (status <> 'archived' and archived_at is null)
      or (status = 'archived' and archived_at is not null)
    )
);

create unique index stable_members_legacy_per_stable_unique
  on public.stable_members (stable_id, legacy_local_member_id)
  where legacy_local_member_id is not null;

create table public.stable_memberships (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  user_id uuid not null references auth.users (id),
  stable_member_id uuid,
  role text not null check (role in ('owner', 'admin', 'member', 'viewer')),
  status text not null default 'active'
    check (status in ('active', 'suspended', 'removed', 'left')),
  joined_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  row_version bigint not null default 1 check (row_version > 0),
  source_invitation_id uuid,
  ended_at timestamptz,
  ended_reason text,
  constraint stable_memberships_stable_user_unique unique (stable_id, user_id),
  constraint stable_memberships_stable_member_fk
    foreign key (stable_id, stable_member_id)
    references public.stable_members (stable_id, id),
  constraint stable_memberships_active_requires_member
    check (status <> 'active' or stable_member_id is not null),
  constraint stable_memberships_lifecycle
    check (
      (status = 'active' and joined_at is not null and ended_at is null)
      or (status <> 'active' and ended_at is not null)
    )
);

create unique index stable_memberships_one_account_per_member
  on public.stable_memberships (stable_member_id)
  where stable_member_id is not null;

create unique index stable_memberships_one_active_owner
  on public.stable_memberships (stable_id)
  where role = 'owner' and status = 'active';

create index stable_memberships_active_user
  on public.stable_memberships (user_id, stable_id)
  where status = 'active';

create table public.stable_invitations (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null references public.stables (id),
  invited_email text not null,
  offered_role text not null check (offered_role in ('admin', 'member', 'viewer')),
  token_hash bytea not null unique check (octet_length(token_hash) = 32),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'revoked', 'expired')),
  expires_at timestamptz not null,
  invited_by_membership_id uuid not null
    references public.stable_memberships (id),
  invitee_user_id uuid references auth.users (id),
  target_stable_member_id uuid,
  accepted_membership_id uuid
    references public.stable_memberships (id),
  last_sent_at timestamptz not null default timezone('utc', now()),
  resend_count integer not null default 0 check (resend_count >= 0),
  accepted_at timestamptz,
  declined_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint stable_invitations_email_normalized
    check (
      invited_email = lower(btrim(invited_email))
      and length(invited_email) between 3 and 320
      and position('@' in invited_email) > 1
    ),
  constraint stable_invitations_target_member_fk
    foreign key (stable_id, target_stable_member_id)
    references public.stable_members (stable_id, id),
  constraint stable_invitations_expiry_after_create
    check (expires_at > created_at),
  constraint stable_invitations_acceptance_fields
    check (
      (status = 'accepted'
        and accepted_membership_id is not null
        and accepted_at is not null)
      or
      (status <> 'accepted'
        and accepted_membership_id is null
        and accepted_at is null)
    )
);

alter table public.stable_memberships
  add constraint stable_memberships_source_invitation_fk
  foreign key (source_invitation_id)
  references public.stable_invitations (id);

create unique index stable_invitations_one_pending_email
  on public.stable_invitations (stable_id, invited_email)
  where status = 'pending';

create unique index stable_invitations_one_pending_target
  on public.stable_invitations (stable_id, target_stable_member_id)
  where status = 'pending' and target_stable_member_id is not null;

create index stable_invitations_stable_status
  on public.stable_invitations (stable_id, status, created_at desc);

create table public.account_workspace_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  last_selected_stable_id uuid references public.stables (id),
  workspace_mode text not null default 'stable'
    check (workspace_mode in ('stable', 'personal')),
  phase_4b_status text not null default 'pending'
    check (phase_4b_status in ('pending', 'active', 'access_lost')),
  intent_consumed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create table public.stable_security_events (
  id bigint generated always as identity primary key,
  stable_id uuid not null references public.stables (id),
  actor_user_id uuid references auth.users (id),
  actor_membership_id uuid references public.stable_memberships (id),
  event_type text not null check (
    event_type in (
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
    )
  ),
  subject_membership_id uuid references public.stable_memberships (id),
  subject_stable_member_id uuid references public.stable_members (id),
  invitation_id uuid references public.stable_invitations (id),
  request_id uuid,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  constraint stable_security_events_metadata_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint stable_security_events_no_contact_data
    check (
      not (metadata ? 'email')
      and not (metadata ? 'invited_email')
      and not (metadata ? 'token')
      and not (metadata ? 'token_hash')
    )
);

create index stable_security_events_stable_created
  on public.stable_security_events (stable_id, created_at desc);

create table private.stable_invitation_rate_events (
  id bigint generated always as identity primary key,
  stable_id uuid not null references public.stables (id),
  actor_user_id uuid not null references auth.users (id),
  invitation_id uuid references public.stable_invitations (id),
  recipient_hash bytea not null check (octet_length(recipient_hash) = 32),
  action text not null check (action in ('create', 'resend')),
  created_at timestamptz not null default timezone('utc', now())
);

revoke all on table private.stable_invitation_rate_events
  from public, anon, authenticated;

create or replace function private.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := timezone('utc', pg_catalog.now());
  return new;
end;
$$;

create or replace function private.touch_membership()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := timezone('utc', pg_catalog.now());
  if tg_op = 'UPDATE' then
    new.row_version := old.row_version + 1;
  end if;
  return new;
end;
$$;

create trigger stables_touch_updated_at
before update on public.stables
for each row execute function private.touch_updated_at();

create trigger stable_members_touch_updated_at
before update on public.stable_members
for each row execute function private.touch_updated_at();

create trigger stable_memberships_touch_updated_at
before update on public.stable_memberships
for each row execute function private.touch_membership();

create trigger stable_invitations_touch_updated_at
before update on public.stable_invitations
for each row execute function private.touch_updated_at();

create trigger account_workspace_preferences_touch_updated_at
before update on public.account_workspace_preferences
for each row execute function private.touch_updated_at();

create or replace function private.current_membership_id(p_stable_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select m.id
  from public.stable_memberships m
  where m.stable_id = p_stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
  limit 1
$$;

create or replace function private.current_role(p_stable_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select m.role
  from public.stable_memberships m
  where m.stable_id = p_stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
  limit 1
$$;

create or replace function private.is_active_member(p_stable_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.stable_memberships m
    where m.stable_id = p_stable_id
      and m.user_id = auth.uid()
      and m.status = 'active'
  )
$$;

create or replace function private.is_stable_manager(p_stable_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.stable_memberships m
    where m.stable_id = p_stable_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and m.role in ('owner', 'admin')
  )
$$;

create or replace function private.write_security_event(
  p_stable_id uuid,
  p_event_type text,
  p_actor_membership_id uuid default null,
  p_subject_membership_id uuid default null,
  p_subject_stable_member_id uuid default null,
  p_invitation_id uuid default null,
  p_request_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.stable_security_events (
    stable_id,
    actor_user_id,
    actor_membership_id,
    event_type,
    subject_membership_id,
    subject_stable_member_id,
    invitation_id,
    request_id,
    metadata
  )
  values (
    p_stable_id,
    auth.uid(),
    p_actor_membership_id,
    p_event_type,
    p_subject_membership_id,
    p_subject_stable_member_id,
    p_invitation_id,
    p_request_id,
    coalesce(p_metadata, '{}'::jsonb)
  );
end;
$$;

create or replace function private.lock_stable_membership_mutation(
  p_stable_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Every mutation that can touch a stable and its memberships starts with
  -- this stable-scoped lock. Different stables remain fully concurrent.
  perform 1
  from public.stables s
  where s.id = p_stable_id
  for update;
  if not found then return; end if;

  -- Lock the complete stable membership set in one deterministic UUID order.
  -- The stable row already serializes same-stable entrants; this explicit
  -- order also prevents target/actor inversions inside the transaction.
  perform 1
  from public.stable_memberships m
  where m.stable_id = p_stable_id
  order by m.id
  for update;
end;
$$;

create or replace function private.assert_exactly_one_active_owner_for_membership()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_stable_id uuid;
  target_status text;
  owner_count integer;
begin
  target_stable_id := case
    when tg_op = 'DELETE' then old.stable_id
    else new.stable_id
  end;
  select s.status into target_status
  from public.stables s
  where s.id = target_stable_id;

  if target_status = 'active' then
    select count(*) into owner_count
    from public.stable_memberships m
    where m.stable_id = target_stable_id
      and m.role = 'owner'
      and m.status = 'active';
    if owner_count <> 1 then
      raise exception using
        errcode = '23514',
        message = 'ACTIVE_STABLE_REQUIRES_EXACTLY_ONE_OWNER';
    end if;
  end if;
  return null;
end;
$$;

create or replace function private.assert_exactly_one_active_owner_for_stable()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_count integer;
begin
  if new.status = 'active' then
    select count(*) into owner_count
    from public.stable_memberships m
    where m.stable_id = new.id
      and m.role = 'owner'
      and m.status = 'active';
    if owner_count <> 1 then
      raise exception using
        errcode = '23514',
        message = 'ACTIVE_STABLE_REQUIRES_EXACTLY_ONE_OWNER';
    end if;
  end if;
  return null;
end;
$$;

create constraint trigger stable_memberships_exactly_one_owner
after insert or update or delete on public.stable_memberships
deferrable initially deferred
for each row execute function private.assert_exactly_one_active_owner_for_membership();

create constraint trigger stables_exactly_one_owner
after insert or update of status on public.stables
deferrable initially deferred
for each row execute function private.assert_exactly_one_active_owner_for_stable();

create or replace function public.create_stable(
  p_name text,
  p_timezone text,
  p_kind text,
  p_locale text,
  p_creation_request_id uuid,
  p_owner_display_name text,
  p_owner_function_title text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  stable_row public.stables%rowtype;
  member_id uuid;
  membership_id uuid;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_creation_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_kind not in ('organization', 'personal') then
    raise exception using errcode = '22023', message = 'INVALID_STABLE_KIND';
  end if;

  select * into stable_row
  from public.stables s
  where s.created_by_user_id = actor_id
    and s.creation_request_id = p_creation_request_id
  for update;

  if stable_row.id is not null then
    select m.id, m.stable_member_id
    into membership_id, member_id
    from public.stable_memberships m
    where m.stable_id = stable_row.id and m.user_id = actor_id;
    return jsonb_build_object(
      'stable_id', stable_row.id,
      'stable_member_id', member_id,
      'membership_id', membership_id,
      'idempotent', true
    );
  end if;

  insert into public.stables (
    kind, name, timezone, locale, created_by_user_id, creation_request_id
  )
  values (
    p_kind,
    btrim(p_name),
    btrim(p_timezone),
    coalesce(nullif(btrim(p_locale), ''), 'nl'),
    actor_id,
    p_creation_request_id
  )
  returning * into stable_row;

  insert into public.stable_members (
    stable_id, display_name, function_title, source
  )
  values (
    stable_row.id,
    btrim(p_owner_display_name),
    nullif(btrim(p_owner_function_title), ''),
    'owner_creation'
  )
  returning id into member_id;

  insert into public.stable_memberships (
    stable_id, user_id, stable_member_id, role, status, joined_at
  )
  values (
    stable_row.id, actor_id, member_id, 'owner', 'active',
    timezone('utc', now())
  )
  returning id into membership_id;

  perform private.write_security_event(
    stable_row.id, 'stable_created', membership_id, membership_id,
    member_id, null, p_creation_request_id,
    jsonb_build_object('kind', p_kind)
  );
  insert into public.account_workspace_preferences (
    user_id, last_selected_stable_id, workspace_mode,
    phase_4b_status, intent_consumed_at
  )
  values (
    actor_id, stable_row.id,
    case when p_kind = 'personal' then 'personal' else 'stable' end,
    'active', timezone('utc', now())
  )
  on conflict (user_id) do update set
    last_selected_stable_id = excluded.last_selected_stable_id,
    workspace_mode = excluded.workspace_mode,
    phase_4b_status = excluded.phase_4b_status,
    intent_consumed_at = excluded.intent_consumed_at;

  return jsonb_build_object(
    'stable_id', stable_row.id,
    'stable_member_id', member_id,
    'membership_id', membership_id,
    'idempotent', false
  );
end;
$$;

create or replace function public.update_stable(
  p_stable_id uuid,
  p_name text,
  p_timezone text,
  p_locale text,
  p_request_id uuid
)
returns public.stables
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_membership public.stable_memberships%rowtype;
  result public.stables%rowtype;
begin
  perform private.lock_stable_membership_mutation(p_stable_id);
  select * into actor_membership
  from public.stable_memberships m
  where m.stable_id = p_stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
    and m.role in ('owner', 'admin')
  for update;
  if actor_membership.id is null then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  update public.stables s set
    name = btrim(p_name),
    timezone = btrim(p_timezone),
    locale = coalesce(nullif(btrim(p_locale), ''), s.locale)
  where s.id = p_stable_id and s.status = 'active'
  returning * into result;
  if result.id is null then
    raise exception using errcode = '22023', message = 'STABLE_NOT_ACTIVE';
  end if;
  perform private.write_security_event(
    p_stable_id, 'stable_updated', actor_membership.id,
    null, null, null, p_request_id
  );
  return result;
end;
$$;

create or replace function public.archive_stable(
  p_stable_id uuid,
  p_request_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_membership public.stable_memberships%rowtype;
  changed integer;
begin
  perform private.lock_stable_membership_mutation(p_stable_id);
  select * into actor_membership
  from public.stable_memberships m
  where m.stable_id = p_stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
    and m.role = 'owner'
  for update;
  if actor_membership.id is null then
    raise exception using errcode = '42501', message = 'OWNER_REQUIRED';
  end if;
  update public.stables
  set status = 'archived', archived_at = timezone('utc', now())
  where id = p_stable_id and status = 'active';
  get diagnostics changed = row_count;
  if changed = 0 then return false; end if;
  perform private.write_security_event(
    p_stable_id, 'stable_archived', actor_membership.id,
    null, null, null, p_request_id
  );
  return true;
end;
$$;

create or replace function public.list_stable_member_directory(p_stable_id uuid)
returns table (
  stable_member_id uuid,
  display_name text,
  function_title text
)
language sql
stable
security definer
set search_path = ''
as $$
  select sm.id, sm.display_name, sm.function_title
  from public.stable_members sm
  where sm.stable_id = p_stable_id
    and sm.status = 'active'
    and private.is_active_member(p_stable_id)
  order by lower(sm.display_name), sm.id
$$;

create or replace function public.create_stable_invitation(
  p_stable_id uuid,
  p_invited_email text,
  p_offered_role text,
  p_token_hash_hex text,
  p_target_stable_member_id uuid default null,
  p_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_membership public.stable_memberships%rowtype;
  stable_row public.stables%rowtype;
  normalized_email text := lower(btrim(p_invited_email));
  token_digest bytea;
  recipient_digest bytea;
  invitation_id uuid;
  action_count integer;
  recipient_count integer;
begin
  perform private.lock_stable_membership_mutation(p_stable_id);
  select * into actor_membership
  from public.stable_memberships m
  where m.stable_id = p_stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
    and m.role in ('owner', 'admin')
  for update;
  if actor_membership.id is null then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  select * into stable_row from public.stables s
  where s.id = p_stable_id for update;
  if stable_row.status <> 'active' then
    raise exception using errcode = '22023', message = 'STABLE_NOT_ACTIVE';
  end if;
  if stable_row.kind = 'personal' then
    raise exception using errcode = '42501', message = 'PERSONAL_INVITATIONS_DISABLED';
  end if;
  if p_offered_role = 'owner'
    or p_offered_role not in ('admin', 'member', 'viewer')
    or (actor_membership.role = 'admin' and p_offered_role = 'admin')
  then
    raise exception using errcode = '42501', message = 'ROLE_NOT_ALLOWED';
  end if;
  if length(normalized_email) not between 3 and 320
    or position('@' in normalized_email) <= 1
  then
    raise exception using errcode = '22023', message = 'INVALID_INVITATION';
  end if;
  if p_token_hash_hex !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'INVALID_TOKEN_DIGEST';
  end if;
  token_digest := decode(p_token_hash_hex, 'hex');
  recipient_digest := extensions.digest(
    p_stable_id::text || ':' || normalized_email,
    'sha256'
  );

  select count(*) into action_count
  from private.stable_invitation_rate_events r
  where r.actor_user_id = auth.uid()
    and r.created_at >= timezone('utc', now()) - interval '1 day';
  if action_count >= 20 then
    raise exception using errcode = '54000', message = 'INVITATION_RATE_LIMITED';
  end if;
  select count(*) into recipient_count
  from private.stable_invitation_rate_events r
  where r.stable_id = p_stable_id
    and r.recipient_hash = recipient_digest
    and r.created_at >= timezone('utc', now()) - interval '1 day';
  if recipient_count >= 5 then
    raise exception using errcode = '54000', message = 'RECIPIENT_RATE_LIMITED';
  end if;
  if p_target_stable_member_id is not null and not exists (
    select 1 from public.stable_members sm
    where sm.id = p_target_stable_member_id
      and sm.stable_id = p_stable_id
      and sm.status = 'active'
  ) then
    raise exception using errcode = '23503', message = 'INVALID_TARGET_MEMBER';
  end if;

  insert into public.stable_invitations (
    stable_id, invited_email, offered_role, token_hash, expires_at,
    invited_by_membership_id, target_stable_member_id
  )
  values (
    p_stable_id, normalized_email, p_offered_role, token_digest,
    timezone('utc', now()) + interval '7 days',
    actor_membership.id, p_target_stable_member_id
  )
  returning id into invitation_id;

  insert into private.stable_invitation_rate_events (
    stable_id, actor_user_id, invitation_id, recipient_hash, action
  )
  values (
    p_stable_id, auth.uid(), invitation_id, recipient_digest, 'create'
  );
  perform private.write_security_event(
    p_stable_id, 'invitation_created', actor_membership.id,
    null, p_target_stable_member_id, invitation_id, p_request_id,
    jsonb_build_object('offered_role', p_offered_role)
  );
  return jsonb_build_object(
    'invitation_id', invitation_id,
    'expires_at', timezone('utc', now()) + interval '7 days'
  );
exception
  when unique_violation then
    raise exception using errcode = '23505', message = 'INVITATION_ALREADY_PENDING';
end;
$$;

create or replace function public.resend_stable_invitation(
  p_invitation_id uuid,
  p_token_hash_hex text,
  p_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  invitation_row public.stable_invitations%rowtype;
  actor_membership public.stable_memberships%rowtype;
  recipient_digest bytea;
  action_count integer;
  recipient_count integer;
begin
  select * into invitation_row
  from public.stable_invitations i
  where i.id = p_invitation_id;
  if invitation_row.id is null then
    raise exception using errcode = '22023', message = 'INVITATION_UNAVAILABLE';
  end if;
  perform private.lock_stable_membership_mutation(invitation_row.stable_id);
  select * into invitation_row
  from public.stable_invitations i
  where i.id = p_invitation_id
  for update;
  select * into actor_membership
  from public.stable_memberships m
  where m.stable_id = invitation_row.stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
    and m.role in ('owner', 'admin')
  for update;
  if actor_membership.id is null
    or (actor_membership.role = 'admin' and invitation_row.offered_role = 'admin')
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  if invitation_row.status <> 'pending' then
    raise exception using errcode = '22023', message = 'INVITATION_UNAVAILABLE';
  end if;
  if invitation_row.last_sent_at > timezone('utc', now()) - interval '60 seconds' then
    raise exception using errcode = '55000', message = 'INVITATION_COOLDOWN';
  end if;
  if p_token_hash_hex !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'INVALID_TOKEN_DIGEST';
  end if;
  recipient_digest := extensions.digest(
    invitation_row.stable_id::text || ':' || invitation_row.invited_email,
    'sha256'
  );
  select count(*) into action_count
  from private.stable_invitation_rate_events r
  where r.actor_user_id = auth.uid()
    and r.created_at >= timezone('utc', now()) - interval '1 day';
  select count(*) into recipient_count
  from private.stable_invitation_rate_events r
  where r.stable_id = invitation_row.stable_id
    and r.recipient_hash = recipient_digest
    and r.action = 'resend'
    and r.created_at >= timezone('utc', now()) - interval '1 day';
  if action_count >= 20 then
    raise exception using errcode = '54000', message = 'INVITATION_RATE_LIMITED';
  end if;
  if recipient_count >= 5 then
    raise exception using errcode = '54000', message = 'RECIPIENT_RATE_LIMITED';
  end if;

  update public.stable_invitations set
    token_hash = decode(p_token_hash_hex, 'hex'),
    expires_at = timezone('utc', now()) + interval '7 days',
    last_sent_at = timezone('utc', now()),
    resend_count = resend_count + 1
  where id = invitation_row.id;
  insert into private.stable_invitation_rate_events (
    stable_id, actor_user_id, invitation_id, recipient_hash, action
  )
  values (
    invitation_row.stable_id, auth.uid(), invitation_row.id,
    recipient_digest, 'resend'
  );
  perform private.write_security_event(
    invitation_row.stable_id, 'invitation_resent', actor_membership.id,
    null, invitation_row.target_stable_member_id, invitation_row.id,
    p_request_id
  );
  return jsonb_build_object(
    'invitation_id', invitation_row.id,
    'expires_at', timezone('utc', now()) + interval '7 days'
  );
end;
$$;

create or replace function public.preview_stable_invitation(
  p_token_hash_hex text
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  invitation_row public.stable_invitations%rowtype;
  stable_row public.stables%rowtype;
  effective_status text;
begin
  if p_token_hash_hex !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('status', 'unavailable');
  end if;
  select * into invitation_row
  from public.stable_invitations i
  where i.token_hash = decode(p_token_hash_hex, 'hex');
  if invitation_row.id is null then
    return jsonb_build_object('status', 'unavailable');
  end if;
  select * into stable_row from public.stables s
  where s.id = invitation_row.stable_id;
  effective_status := case
    when invitation_row.status = 'pending'
      and invitation_row.expires_at <= timezone('utc', now()) then 'expired'
    when stable_row.status <> 'active' then 'unavailable'
    else invitation_row.status
  end;
  if effective_status <> 'pending' then
    return jsonb_build_object('status', effective_status);
  end if;
  return jsonb_build_object(
    'status', effective_status,
    'stable_name', stable_row.name,
    'stable_kind', stable_row.kind,
    'offered_role', invitation_row.offered_role
  );
end;
$$;

create or replace function public.accept_stable_invitation(
  p_token_hash_hex text,
  p_display_name text default null,
  p_function_title text default null,
  p_request_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  actor_email text;
  invitation_row public.stable_invitations%rowtype;
  member_id uuid;
  membership_row public.stable_memberships%rowtype;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_token_hash_hex !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '22023', message = 'INVITATION_UNAVAILABLE';
  end if;
  select lower(u.email) into actor_email
  from auth.users u
  where u.id = actor_id and u.email_confirmed_at is not null;
  if actor_email is null then
    raise exception using errcode = '42501', message = 'CONFIRMED_ACCOUNT_REQUIRED';
  end if;

  select * into invitation_row
  from public.stable_invitations i
  where i.token_hash = decode(p_token_hash_hex, 'hex');
  if invitation_row.id is null then
    raise exception using errcode = '22023', message = 'INVITATION_UNAVAILABLE';
  end if;
  perform private.lock_stable_membership_mutation(invitation_row.stable_id);
  select * into invitation_row
  from public.stable_invitations i
  where i.token_hash = decode(p_token_hash_hex, 'hex')
  for update;
  if invitation_row.id is null then
    raise exception using errcode = '22023', message = 'INVITATION_UNAVAILABLE';
  end if;
  if invitation_row.status = 'accepted'
    and invitation_row.invitee_user_id = actor_id
  then
    return jsonb_build_object(
      'stable_id', invitation_row.stable_id,
      'membership_id', invitation_row.accepted_membership_id,
      'idempotent', true
    );
  end if;
  if invitation_row.status <> 'pending'
    or invitation_row.expires_at <= timezone('utc', now())
    or invitation_row.invited_email <> actor_email
    or (
      invitation_row.invitee_user_id is not null
      and invitation_row.invitee_user_id <> actor_id
    )
  then
    if invitation_row.status = 'pending'
      and invitation_row.expires_at <= timezone('utc', now())
    then
      update public.stable_invitations
      set status = 'expired' where id = invitation_row.id;
    end if;
    raise exception using errcode = '42501', message = 'INVITATION_UNAVAILABLE';
  end if;

  if invitation_row.target_stable_member_id is not null then
    select sm.id into member_id
    from public.stable_members sm
    where sm.id = invitation_row.target_stable_member_id
      and sm.stable_id = invitation_row.stable_id
      and sm.status = 'active'
    for update;
    if member_id is null then
      raise exception using errcode = '22023', message = 'INVITATION_UNAVAILABLE';
    end if;
  else
    if length(btrim(coalesce(p_display_name, ''))) not between 1 and 120 then
      raise exception using errcode = '22023', message = 'DISPLAY_NAME_REQUIRED';
    end if;
    insert into public.stable_members (
      stable_id, display_name, function_title, source
    )
    values (
      invitation_row.stable_id, btrim(p_display_name),
      nullif(btrim(p_function_title), ''), 'invitation'
    )
    returning id into member_id;
  end if;

  select * into membership_row
  from public.stable_memberships m
  where m.stable_id = invitation_row.stable_id
    and m.user_id = actor_id
  for update;
  if membership_row.id is null then
    insert into public.stable_memberships (
      stable_id, user_id, stable_member_id, role, status, joined_at,
      source_invitation_id
    )
    values (
      invitation_row.stable_id, actor_id, member_id,
      invitation_row.offered_role, 'active', timezone('utc', now()),
      invitation_row.id
    )
    returning * into membership_row;
  elsif membership_row.status = 'active' then
    raise exception using errcode = '23505', message = 'MEMBERSHIP_ALREADY_ACTIVE';
  else
    update public.stable_memberships set
      stable_member_id = member_id,
      role = invitation_row.offered_role,
      status = 'active',
      joined_at = timezone('utc', now()),
      ended_at = null,
      ended_reason = null,
      source_invitation_id = invitation_row.id
    where id = membership_row.id
    returning * into membership_row;
  end if;

  update public.stable_invitations set
    status = 'accepted',
    invitee_user_id = actor_id,
    accepted_membership_id = membership_row.id,
    accepted_at = timezone('utc', now())
  where id = invitation_row.id;
  perform private.write_security_event(
    invitation_row.stable_id, 'invitation_accepted', membership_row.id,
    membership_row.id, member_id, invitation_row.id, p_request_id
  );
  insert into public.account_workspace_preferences (
    user_id, last_selected_stable_id, workspace_mode,
    phase_4b_status, intent_consumed_at
  )
  values (
    actor_id, invitation_row.stable_id, 'stable',
    'active', timezone('utc', now())
  )
  on conflict (user_id) do update set
    last_selected_stable_id = excluded.last_selected_stable_id,
    workspace_mode = excluded.workspace_mode,
    phase_4b_status = excluded.phase_4b_status,
    intent_consumed_at = excluded.intent_consumed_at;
  return jsonb_build_object(
    'stable_id', invitation_row.stable_id,
    'membership_id', membership_row.id,
    'stable_member_id', member_id,
    'idempotent', false
  );
end;
$$;

create or replace function public.decline_stable_invitation(
  p_token_hash_hex text,
  p_request_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  actor_email text;
  candidate_invitation_id uuid;
  candidate_stable_id uuid;
  invitation_row public.stable_invitations%rowtype;
begin
  select lower(u.email) into actor_email
  from auth.users u
  where u.id = actor_id and u.email_confirmed_at is not null;
  if actor_email is null or p_token_hash_hex !~ '^[0-9a-f]{64}$' then
    raise exception using errcode = '42501', message = 'INVITATION_UNAVAILABLE';
  end if;
  select i.id, i.stable_id
  into candidate_invitation_id, candidate_stable_id
  from public.stable_invitations i
  where i.token_hash = decode(p_token_hash_hex, 'hex');
  if candidate_invitation_id is null then
    raise exception using errcode = '42501', message = 'INVITATION_UNAVAILABLE';
  end if;

  perform private.lock_stable_membership_mutation(candidate_stable_id);
  select * into invitation_row
  from public.stable_invitations i
  where i.id = candidate_invitation_id
  for update;
  if invitation_row.id is null
    or invitation_row.token_hash <> decode(p_token_hash_hex, 'hex')
    or invitation_row.stable_id <> candidate_stable_id
    or invitation_row.status <> 'pending'
    or invitation_row.expires_at <= timezone('utc', now())
    or invitation_row.invited_email <> actor_email
  then
    raise exception using errcode = '42501', message = 'INVITATION_UNAVAILABLE';
  end if;
  update public.stable_invitations set
    status = 'declined', invitee_user_id = actor_id,
    declined_at = timezone('utc', now())
  where id = invitation_row.id;
  perform private.write_security_event(
    candidate_stable_id, 'invitation_declined', null,
    null, invitation_row.target_stable_member_id,
    invitation_row.id, p_request_id
  );
  return true;
end;
$$;

create or replace function public.revoke_stable_invitation(
  p_invitation_id uuid,
  p_request_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  invitation_row public.stable_invitations%rowtype;
  actor_membership public.stable_memberships%rowtype;
begin
  select * into invitation_row
  from public.stable_invitations i where i.id = p_invitation_id;
  if invitation_row.id is null then return false; end if;
  perform private.lock_stable_membership_mutation(invitation_row.stable_id);
  select * into invitation_row
  from public.stable_invitations i where i.id = p_invitation_id for update;
  select * into actor_membership
  from public.stable_memberships m
  where m.stable_id = invitation_row.stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
    and m.role in ('owner', 'admin')
  for update;
  if actor_membership.id is null
    or (actor_membership.role = 'admin' and invitation_row.offered_role = 'admin')
  then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;
  if invitation_row.status = 'revoked' then return true; end if;
  if invitation_row.status <> 'pending' then
    raise exception using errcode = '22023', message = 'INVITATION_UNAVAILABLE';
  end if;
  update public.stable_invitations set
    status = 'revoked', revoked_at = timezone('utc', now())
  where id = invitation_row.id;
  perform private.write_security_event(
    invitation_row.stable_id, 'invitation_revoked', actor_membership.id,
    null, invitation_row.target_stable_member_id,
    invitation_row.id, p_request_id
  );
  return true;
end;
$$;

create or replace function public.change_stable_member_role(
  p_membership_id uuid,
  p_new_role text,
  p_request_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.stable_memberships%rowtype;
  actor public.stable_memberships%rowtype;
  target_stable_id uuid;
begin
  select m.stable_id into target_stable_id
  from public.stable_memberships m where m.id = p_membership_id;
  if target_stable_id is null then
    raise exception using errcode = '22023', message = 'MEMBERSHIP_NOT_ACTIVE';
  end if;
  perform private.lock_stable_membership_mutation(target_stable_id);
  select * into target from public.stable_memberships m
  where m.id = p_membership_id for update;
  if target.id is null or target.status <> 'active' then
    raise exception using errcode = '22023', message = 'MEMBERSHIP_NOT_ACTIVE';
  end if;
  select * into actor from public.stable_memberships m
  where m.stable_id = target.stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
    and m.role in ('owner', 'admin')
  for update;
  if actor.id is null
    or p_new_role not in ('admin', 'member', 'viewer')
    or target.role = 'owner'
    or (actor.role = 'admin'
      and (target.role = 'admin' or p_new_role = 'admin'))
  then
    raise exception using errcode = '42501', message = 'ROLE_CHANGE_NOT_ALLOWED';
  end if;
  if target.role = p_new_role then return true; end if;
  update public.stable_memberships set role = p_new_role
  where id = target.id;
  perform private.write_security_event(
    target.stable_id, 'role_changed', actor.id, target.id,
    target.stable_member_id, null, p_request_id,
    jsonb_build_object('from_role', target.role, 'to_role', p_new_role)
  );
  return true;
end;
$$;

create or replace function public.remove_stable_membership(
  p_membership_id uuid,
  p_request_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.stable_memberships%rowtype;
  actor public.stable_memberships%rowtype;
  target_stable_id uuid;
begin
  select m.stable_id into target_stable_id
  from public.stable_memberships m where m.id = p_membership_id;
  if target_stable_id is null then return false; end if;
  perform private.lock_stable_membership_mutation(target_stable_id);
  select * into target from public.stable_memberships m
  where m.id = p_membership_id for update;
  if target.id is null then return false; end if;
  select * into actor from public.stable_memberships m
  where m.stable_id = target.stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
    and m.role in ('owner', 'admin')
  for update;
  if actor.id is null or target.role = 'owner'
    or (actor.role = 'admin' and target.role = 'admin')
  then
    raise exception using errcode = '42501', message = 'REMOVE_NOT_ALLOWED';
  end if;
  if target.status = 'removed' then return true; end if;
  if target.status <> 'active' and target.status <> 'suspended' then
    raise exception using errcode = '22023', message = 'MEMBERSHIP_NOT_REMOVABLE';
  end if;
  update public.stable_memberships set
    status = 'removed', ended_at = timezone('utc', now()),
    ended_reason = 'removed'
  where id = target.id;
  perform private.write_security_event(
    target.stable_id, 'membership_removed', actor.id, target.id,
    target.stable_member_id, null, p_request_id
  );
  return true;
end;
$$;

create or replace function public.suspend_stable_membership(
  p_membership_id uuid,
  p_request_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.stable_memberships%rowtype;
  actor public.stable_memberships%rowtype;
  target_stable_id uuid;
begin
  select m.stable_id into target_stable_id
  from public.stable_memberships m where m.id = p_membership_id;
  if target_stable_id is null then
    raise exception using errcode = '22023', message = 'MEMBERSHIP_NOT_ACTIVE';
  end if;
  perform private.lock_stable_membership_mutation(target_stable_id);
  select * into target from public.stable_memberships m
  where m.id = p_membership_id for update;
  if target.id is null or target.status <> 'active' then
    raise exception using errcode = '22023', message = 'MEMBERSHIP_NOT_ACTIVE';
  end if;
  select * into actor from public.stable_memberships m
  where m.stable_id = target.stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
    and m.role in ('owner', 'admin')
  for update;
  if actor.id is null or target.role = 'owner'
    or (actor.role = 'admin' and target.role = 'admin')
  then
    raise exception using errcode = '42501', message = 'SUSPEND_NOT_ALLOWED';
  end if;
  update public.stable_memberships set
    status = 'suspended', ended_at = timezone('utc', now()),
    ended_reason = 'suspended'
  where id = target.id;
  perform private.write_security_event(
    target.stable_id, 'membership_suspended', actor.id, target.id,
    target.stable_member_id, null, p_request_id
  );
  return true;
end;
$$;

create or replace function public.leave_stable(
  p_stable_id uuid,
  p_request_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor public.stable_memberships%rowtype;
begin
  perform private.lock_stable_membership_mutation(p_stable_id);
  select * into actor from public.stable_memberships m
  where m.stable_id = p_stable_id
    and m.user_id = auth.uid()
  for update;
  if actor.id is null or actor.status <> 'active' then return false; end if;
  if actor.role = 'owner' then
    raise exception using errcode = '42501', message = 'OWNER_MUST_TRANSFER_FIRST';
  end if;
  update public.stable_memberships set
    status = 'left', ended_at = timezone('utc', now()),
    ended_reason = 'left'
  where id = actor.id;
  perform private.write_security_event(
    p_stable_id, 'membership_left', actor.id, actor.id,
    actor.stable_member_id, null, p_request_id
  );
  return true;
end;
$$;

create or replace function public.transfer_stable_ownership(
  p_stable_id uuid,
  p_target_membership_id uuid,
  p_request_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor public.stable_memberships%rowtype;
  target public.stable_memberships%rowtype;
begin
  perform private.lock_stable_membership_mutation(p_stable_id);
  select * into actor from public.stable_memberships m
  where m.stable_id = p_stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
    and m.role = 'owner'
  for update;
  select * into target from public.stable_memberships m
  where m.id = p_target_membership_id
    and m.stable_id = p_stable_id
    and m.status = 'active'
  for update;
  if actor.id is null then
    raise exception using errcode = '42501', message = 'OWNER_REQUIRED';
  end if;
  if target.id is null or target.id = actor.id then
    raise exception using errcode = '22023', message = 'INVALID_TRANSFER_TARGET';
  end if;
  update public.stable_memberships set role = 'admin' where id = actor.id;
  update public.stable_memberships set role = 'owner' where id = target.id;
  perform private.write_security_event(
    p_stable_id, 'ownership_transferred', actor.id, target.id,
    target.stable_member_id, null, p_request_id,
    jsonb_build_object('previous_owner_membership_id', actor.id)
  );
  return true;
end;
$$;

create or replace function public.link_account_to_stable_member(
  p_membership_id uuid,
  p_stable_member_id uuid,
  p_request_id uuid default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.stable_memberships%rowtype;
  actor public.stable_memberships%rowtype;
  member public.stable_members%rowtype;
  target_stable_id uuid;
begin
  select m.stable_id into target_stable_id
  from public.stable_memberships m where m.id = p_membership_id;
  if target_stable_id is null then
    raise exception using errcode = '22023', message = 'MEMBERSHIP_NOT_ACTIVE';
  end if;
  perform private.lock_stable_membership_mutation(target_stable_id);
  select * into target from public.stable_memberships m
  where m.id = p_membership_id for update;
  if target.id is null or target.status <> 'active' then
    raise exception using errcode = '22023', message = 'MEMBERSHIP_NOT_ACTIVE';
  end if;
  select * into actor from public.stable_memberships m
  where m.stable_id = target.stable_id
    and m.user_id = auth.uid()
    and m.status = 'active'
    and m.role in ('owner', 'admin')
  for update;
  if actor.id is null or (
    actor.role = 'admin' and target.role in ('owner', 'admin')
  ) then
    raise exception using errcode = '42501', message = 'LINK_NOT_ALLOWED';
  end if;
  select * into member from public.stable_members sm
  where sm.id = p_stable_member_id
    and sm.stable_id = target.stable_id
    and sm.status = 'active'
  for update;
  if member.id is null then
    raise exception using errcode = '23503', message = 'INVALID_TARGET_MEMBER';
  end if;
  update public.stable_memberships
  set stable_member_id = null
  where stable_member_id = member.id
    and id <> target.id
    and status <> 'active';
  if exists (
    select 1 from public.stable_memberships m
    where m.stable_member_id = member.id and m.id <> target.id
  ) then
    raise exception using errcode = '23505', message = 'MEMBER_ALREADY_LINKED';
  end if;
  update public.stable_memberships set stable_member_id = member.id
  where id = target.id;
  perform private.write_security_event(
    target.stable_id, 'stable_member_linked', actor.id, target.id,
    member.id, null, p_request_id
  );
  return true;
end;
$$;

create or replace function public.set_selected_stable(
  p_stable_id uuid,
  p_workspace_mode text default 'stable'
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  stable_kind text;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  select s.kind into stable_kind
  from public.stables s
  join public.stable_memberships m on m.stable_id = s.id
  where s.id = p_stable_id
    and s.status = 'active'
    and m.user_id = actor_id
    and m.status = 'active'
  for update of m;
  if stable_kind is null then
    raise exception using errcode = '42501', message = 'ACTIVE_MEMBERSHIP_REQUIRED';
  end if;
  if p_workspace_mode not in ('stable', 'personal')
    or (p_workspace_mode = 'personal' and stable_kind <> 'personal')
  then
    raise exception using errcode = '22023', message = 'INVALID_WORKSPACE_MODE';
  end if;
  insert into public.account_workspace_preferences (
    user_id, last_selected_stable_id, workspace_mode, phase_4b_status
  )
  values (actor_id, p_stable_id, p_workspace_mode, 'active')
  on conflict (user_id) do update set
    last_selected_stable_id = excluded.last_selected_stable_id,
    workspace_mode = excluded.workspace_mode,
    phase_4b_status = excluded.phase_4b_status;
  return true;
end;
$$;

alter table public.stables enable row level security;
alter table public.stable_members enable row level security;
alter table public.stable_memberships enable row level security;
alter table public.stable_invitations enable row level security;
alter table public.account_workspace_preferences enable row level security;
alter table public.stable_security_events enable row level security;

revoke all on table public.stables from public, anon, authenticated;
revoke all on table public.stable_members from public, anon, authenticated;
revoke all on table public.stable_memberships from public, anon, authenticated;
revoke all on table public.stable_invitations from public, anon, authenticated;
revoke all on table public.account_workspace_preferences
  from public, anon, authenticated;
revoke all on table public.stable_security_events
  from public, anon, authenticated;

grant select on table public.stables to authenticated;
grant select on table public.stable_members to authenticated;
grant select on table public.stable_memberships to authenticated;
grant select on table public.stable_invitations to authenticated;
grant select on table public.account_workspace_preferences to authenticated;
grant select on table public.stable_security_events to authenticated;

create policy stables_select_active_members
on public.stables for select to authenticated
using (private.is_active_member(id));

create policy stable_members_select_managers
on public.stable_members for select to authenticated
using (private.is_stable_manager(stable_id));

create policy stable_memberships_select_own_or_managers
on public.stable_memberships for select to authenticated
using (
  user_id = auth.uid()
  or private.is_stable_manager(stable_id)
);

create policy stable_invitations_select_managers
on public.stable_invitations for select to authenticated
using (private.is_stable_manager(stable_id));

create policy account_workspace_preferences_select_own
on public.account_workspace_preferences for select to authenticated
using (user_id = auth.uid());

create policy stable_security_events_select_managers
on public.stable_security_events for select to authenticated
using (private.is_stable_manager(stable_id));

revoke all on all functions in schema private from public, anon, authenticated;
grant execute on function private.current_membership_id(uuid) to authenticated;
grant execute on function private.current_role(uuid) to authenticated;
grant execute on function private.is_active_member(uuid) to authenticated;
grant execute on function private.is_stable_manager(uuid) to authenticated;

revoke execute on function public.create_stable(
  text, text, text, text, uuid, text, text
) from public, anon;
revoke execute on function public.update_stable(
  uuid, text, text, text, uuid
) from public, anon;
revoke execute on function public.archive_stable(uuid, uuid) from public, anon;
revoke execute on function public.list_stable_member_directory(uuid)
  from public, anon;
revoke execute on function public.create_stable_invitation(
  uuid, text, text, text, uuid, uuid
) from public, anon;
revoke execute on function public.resend_stable_invitation(uuid, text, uuid)
  from public, anon;
revoke execute on function public.preview_stable_invitation(text)
  from public, anon, authenticated;
revoke execute on function public.accept_stable_invitation(
  text, text, text, uuid
) from public, anon;
revoke execute on function public.decline_stable_invitation(text, uuid)
  from public, anon;
revoke execute on function public.revoke_stable_invitation(uuid, uuid)
  from public, anon;
revoke execute on function public.change_stable_member_role(uuid, text, uuid)
  from public, anon;
revoke execute on function public.remove_stable_membership(uuid, uuid)
  from public, anon;
revoke execute on function public.suspend_stable_membership(uuid, uuid)
  from public, anon;
revoke execute on function public.leave_stable(uuid, uuid) from public, anon;
revoke execute on function public.transfer_stable_ownership(uuid, uuid, uuid)
  from public, anon;
revoke execute on function public.link_account_to_stable_member(uuid, uuid, uuid)
  from public, anon;
revoke execute on function public.set_selected_stable(uuid, text)
  from public, anon;

grant execute on function public.create_stable(
  text, text, text, text, uuid, text, text
) to authenticated;
grant execute on function public.update_stable(
  uuid, text, text, text, uuid
) to authenticated;
grant execute on function public.archive_stable(uuid, uuid) to authenticated;
grant execute on function public.list_stable_member_directory(uuid)
  to authenticated;
grant execute on function public.create_stable_invitation(
  uuid, text, text, text, uuid, uuid
) to authenticated;
grant execute on function public.resend_stable_invitation(uuid, text, uuid)
  to authenticated;
grant execute on function public.preview_stable_invitation(text)
  to service_role;
grant execute on function public.accept_stable_invitation(
  text, text, text, uuid
) to authenticated;
grant execute on function public.decline_stable_invitation(text, uuid)
  to authenticated;
grant execute on function public.revoke_stable_invitation(uuid, uuid)
  to authenticated;
grant execute on function public.change_stable_member_role(uuid, text, uuid)
  to authenticated;
grant execute on function public.remove_stable_membership(uuid, uuid)
  to authenticated;
grant execute on function public.suspend_stable_membership(uuid, uuid)
  to authenticated;
grant execute on function public.leave_stable(uuid, uuid) to authenticated;
grant execute on function public.transfer_stable_ownership(uuid, uuid, uuid)
  to authenticated;
grant execute on function public.link_account_to_stable_member(uuid, uuid, uuid)
  to authenticated;
grant execute on function public.set_selected_stable(uuid, text)
  to authenticated;

commit;
