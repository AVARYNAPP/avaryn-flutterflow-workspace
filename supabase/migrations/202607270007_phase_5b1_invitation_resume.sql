-- Phase 5B.1: resume an invitation after an auth redirect without persisting
-- its raw bearer token. The durable client hand-off is the non-secret
-- invitation UUID; every server operation rebinds it to the confirmed email
-- of auth.uid().

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

  select * into stable_row
  from public.stables s
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
    'status', 'pending',
    'invitation_id', invitation_row.id,
    'stable_name', stable_row.name,
    'stable_kind', stable_row.kind,
    'offered_role', invitation_row.offered_role
  );
end;
$$;

create or replace function public.resume_stable_invitation(
  p_invitation_id uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  actor_email text;
  invitation_row public.stable_invitations%rowtype;
  stable_row public.stables%rowtype;
  effective_status text;
begin
  select lower(u.email) into actor_email
  from auth.users u
  where u.id = actor_id
    and u.email_confirmed_at is not null;

  if actor_email is null then
    return jsonb_build_object('status', 'unavailable');
  end if;

  select * into invitation_row
  from public.stable_invitations i
  where i.id = p_invitation_id
    and i.invited_email = actor_email;

  if invitation_row.id is null then
    return jsonb_build_object('status', 'unavailable');
  end if;

  select * into stable_row
  from public.stables s
  where s.id = invitation_row.stable_id;

  effective_status := case
    when invitation_row.status = 'pending'
      and invitation_row.expires_at <= timezone('utc', now()) then 'expired'
    when stable_row.status <> 'active' then 'unavailable'
    else invitation_row.status
  end;

  if effective_status = 'accepted'
    and invitation_row.invitee_user_id = actor_id
  then
    return jsonb_build_object(
      'status', 'accepted',
      'stable_id', invitation_row.stable_id
    );
  end if;

  if effective_status = 'declined'
    and invitation_row.invitee_user_id = actor_id
  then
    return jsonb_build_object('status', 'declined');
  end if;

  if effective_status <> 'pending' then
    return jsonb_build_object('status', effective_status);
  end if;

  return jsonb_build_object(
    'status', 'pending',
    'invitation_id', invitation_row.id,
    'stable_name', stable_row.name,
    'stable_kind', stable_row.kind,
    'offered_role', invitation_row.offered_role
  );
end;
$$;

create or replace function public.accept_stable_invitation_by_id(
  p_invitation_id uuid,
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
  token_hash_hex text;
begin
  select lower(u.email) into actor_email
  from auth.users u
  where u.id = actor_id
    and u.email_confirmed_at is not null;

  if actor_email is null then
    raise exception using
      errcode = '42501',
      message = 'INVITATION_UNAVAILABLE';
  end if;

  select encode(i.token_hash, 'hex') into token_hash_hex
  from public.stable_invitations i
  where i.id = p_invitation_id
    and i.invited_email = actor_email;

  if token_hash_hex is null then
    raise exception using
      errcode = '42501',
      message = 'INVITATION_UNAVAILABLE';
  end if;

  return public.accept_stable_invitation(
    token_hash_hex,
    p_display_name,
    p_function_title,
    p_request_id
  );
end;
$$;

create or replace function public.decline_stable_invitation_by_id(
  p_invitation_id uuid,
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
  token_hash_hex text;
begin
  select lower(u.email) into actor_email
  from auth.users u
  where u.id = actor_id
    and u.email_confirmed_at is not null;

  if actor_email is null then
    raise exception using
      errcode = '42501',
      message = 'INVITATION_UNAVAILABLE';
  end if;

  select encode(i.token_hash, 'hex') into token_hash_hex
  from public.stable_invitations i
  where i.id = p_invitation_id
    and i.invited_email = actor_email;

  if token_hash_hex is null then
    raise exception using
      errcode = '42501',
      message = 'INVITATION_UNAVAILABLE';
  end if;

  return public.decline_stable_invitation(token_hash_hex, p_request_id);
end;
$$;

revoke all on function public.resume_stable_invitation(uuid) from public;
revoke all on function public.accept_stable_invitation_by_id(
  uuid, text, text, uuid
) from public;
revoke all on function public.decline_stable_invitation_by_id(
  uuid, uuid
) from public;

grant execute on function public.resume_stable_invitation(uuid)
  to authenticated;
grant execute on function public.accept_stable_invitation_by_id(
  uuid, text, text, uuid
) to authenticated;
grant execute on function public.decline_stable_invitation_by_id(
  uuid, uuid
) to authenticated;

comment on function public.resume_stable_invitation(uuid) is
  'Returns a minimal pending invitation preview only when auth.uid has the confirmed invited email.';
comment on function public.accept_stable_invitation_by_id(
  uuid, text, text, uuid
) is
  'Resumes acceptance after auth redirects using a non-secret invitation UUID rebound to the confirmed invited email.';
comment on function public.decline_stable_invitation_by_id(uuid, uuid) is
  'Resumes decline after auth redirects using a non-secret invitation UUID rebound to the confirmed invited email.';
