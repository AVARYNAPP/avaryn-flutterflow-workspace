begin;

-- Isolated local fixtures. No production-like names, addresses or content.
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
  fixture.metadata::jsonb,
  now(),
  now()
from (
  values
    ('41000000-0000-0000-0000-000000000001', 'owner-a@example.invalid', '{"role":"owner"}'),
    ('41000000-0000-0000-0000-000000000002', 'admin-a@example.invalid', '{"role":"owner"}'),
    ('41000000-0000-0000-0000-000000000003', 'member-a@example.invalid', '{"role":"owner"}'),
    ('41000000-0000-0000-0000-000000000004', 'viewer-a@example.invalid', '{"role":"owner"}'),
    ('42000000-0000-0000-0000-000000000001', 'owner-b@example.invalid', '{"role":"owner"}'),
    ('43000000-0000-0000-0000-000000000001', 'outsider@example.invalid', '{"role":"owner"}'),
    ('44000000-0000-0000-0000-000000000001', 'invitee@example.invalid', '{"role":"owner"}')
) as fixture(id, email, metadata);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values
  (
    '51000000-0000-0000-0000-000000000001',
    'organization', 'Lokale stal A', 'active', 'Europe/Amsterdam', 'nl',
    '41000000-0000-0000-0000-000000000001',
    '61000000-0000-0000-0000-000000000001'
  ),
  (
    '52000000-0000-0000-0000-000000000001',
    'organization', 'Lokale stal B', 'active', 'Europe/Amsterdam', 'nl',
    '42000000-0000-0000-0000-000000000001',
    '62000000-0000-0000-0000-000000000001'
  );

insert into public.stable_members (
  id, stable_id, display_name, function_title, source, legacy_local_member_id
)
values
  ('71000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'Owner A', 'Eigenaar', 'owner_creation', 'legacy-owner-a'),
  ('71000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000001', 'Admin A', 'Stalmanager', 'manual', 'legacy-admin-a'),
  ('71000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000001', 'Member A', 'Groom', 'manual', 'legacy-member-a'),
  ('71000000-0000-0000-0000-000000000004', '51000000-0000-0000-0000-000000000001', 'Viewer A', 'Dierenarts', 'manual', null),
  ('72000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', 'Owner B', 'Eigenaar', 'owner_creation', 'legacy-owner-b'),
  ('71000000-0000-0000-0000-000000000005', '51000000-0000-0000-0000-000000000001', 'Zonder account', 'Trainer', 'manual', 'legacy-no-account');

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status, joined_at
)
values
  ('81000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001', '71000000-0000-0000-0000-000000000001', 'owner', 'active', now()),
  ('81000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000002', '71000000-0000-0000-0000-000000000002', 'admin', 'active', now()),
  ('81000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000003', '71000000-0000-0000-0000-000000000003', 'member', 'active', now()),
  ('81000000-0000-0000-0000-000000000004', '51000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000004', '71000000-0000-0000-0000-000000000004', 'viewer', 'active', now()),
  ('82000000-0000-0000-0000-000000000001', '52000000-0000-0000-0000-000000000001', '42000000-0000-0000-0000-000000000001', '72000000-0000-0000-0000-000000000001', 'owner', 'active', now());

set constraints all immediate;
set constraints all deferred;

-- Owner A: complete authority view for A, no visibility into B.
set local role authenticated;
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);

do $$
declare
  count_value integer;
begin
  select count(*) into count_value from public.stables;
  if count_value <> 1 then
    raise exception 'Owner A stable visibility was %, expected 1', count_value;
  end if;
  select count(*) into count_value from public.stable_memberships;
  if count_value <> 4 then
    raise exception 'Owner A membership visibility was %, expected 4', count_value;
  end if;
  select count(*) into count_value
  from public.stable_memberships
  where stable_id = '52000000-0000-0000-0000-000000000001';
  if count_value <> 0 then
    raise exception 'Owner A could read stable B memberships';
  end if;
  select count(*) into count_value
  from public.list_stable_member_directory(
    '51000000-0000-0000-0000-000000000001'
  );
  if count_value <> 5 then
    raise exception 'Safe member directory omitted an operational person';
  end if;
end;
$$;

do $$
begin
  begin
    insert into public.stables (
      kind, name, timezone, locale, created_by_user_id, creation_request_id
    ) values (
      'organization', 'Aanval', 'UTC', 'nl', auth.uid(), gen_random_uuid()
    );
    raise exception 'Direct stable insert unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.stable_memberships set role = 'owner'
    where id = '81000000-0000-0000-0000-000000000003';
    raise exception 'Direct membership update unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.stable_security_events;
    raise exception 'Direct audit delete unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
end;
$$;

-- Forged role metadata does not elevate a normal member.
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000003', true);
do $$
declare
  count_value integer;
begin
  select count(*) into count_value from public.stable_memberships;
  if count_value <> 1 then
    raise exception 'Member must see only own membership, saw %', count_value;
  end if;
  select count(*) into count_value from public.stable_members;
  if count_value <> 0 then
    raise exception 'Member read authority roster base table';
  end if;
  select count(*) into count_value
  from public.list_stable_member_directory(
    '51000000-0000-0000-0000-000000000001'
  );
  if count_value <> 5 then
    raise exception 'Member safe directory did not expose names/titles';
  end if;
  begin
    perform public.change_stable_member_role(
      '81000000-0000-0000-0000-000000000004', 'member', gen_random_uuid()
    );
    raise exception 'Forged metadata elevated member';
  exception when insufficient_privilege then null;
  end;
end;
$$;

-- Viewer has the same authority read boundary and no writes.
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000004', true);
do $$
begin
  if (select count(*) from public.stable_memberships) <> 1 then
    raise exception 'Viewer saw another membership';
  end if;
  begin
    perform public.create_stable_invitation(
      '51000000-0000-0000-0000-000000000001',
      'blocked@example.invalid', 'member', repeat('1', 64), null, gen_random_uuid()
    );
    raise exception 'Viewer created invitation';
  exception when insufficient_privilege then null;
  end;
end;
$$;

-- Stable B is fully isolated from stable A.
select set_config('request.jwt.claim.sub', '42000000-0000-0000-0000-000000000001', true);
do $$
begin
  if exists (
    select 1 from public.stables
    where id = '51000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'Stable B owner could read stable A';
  end if;
  if (select count(*) from public.list_stable_member_directory(
    '51000000-0000-0000-0000-000000000001'
  )) <> 0 then
    raise exception 'Stable B owner could read stable A directory';
  end if;
end;
$$;

-- Unaffiliated and anonymous callers see nothing.
select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000001', true);
do $$
begin
  if (select count(*) from public.stables) <> 0 then
    raise exception 'Outsider saw a stable';
  end if;
  if (select count(*) from public.stable_memberships) <> 0 then
    raise exception 'Outsider saw a membership';
  end if;
end;
$$;

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'anon', true);
do $$
begin
  begin
    perform count(*) from public.stable_invitations;
    raise exception 'Anon read invitation records';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.preview_stable_invitation(repeat('0', 64));
    raise exception 'Anon directly executed preview RPC';
  exception when insufficient_privilege then null;
  end;
end;
$$;

-- Invitation create, target isolation, role bounds and email-bound acceptance.
reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000002', true);
do $$
begin
  begin
    perform public.create_stable_invitation(
      '51000000-0000-0000-0000-000000000001',
      'admin-offer@example.invalid', 'admin', repeat('2', 64), null, gen_random_uuid()
    );
    raise exception 'Admin offered admin role';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.create_stable_invitation(
      '51000000-0000-0000-0000-000000000001',
      'cross-member@example.invalid', 'member', repeat('3', 64),
      '72000000-0000-0000-0000-000000000001', gen_random_uuid()
    );
    raise exception 'Cross-stable target member accepted';
  exception when foreign_key_violation then null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000001', true);
select public.create_stable_invitation(
  '51000000-0000-0000-0000-000000000001',
  'invitee@example.invalid', 'member', repeat('a', 64), null,
  '91000000-0000-0000-0000-000000000001'
);

select set_config('request.jwt.claim.sub', '43000000-0000-0000-0000-000000000001', true);
do $$
begin
  begin
    perform public.accept_stable_invitation(
      repeat('a', 64), 'Verkeerd account', null, gen_random_uuid()
    );
    raise exception 'Wrong email accepted invitation';
  exception when insufficient_privilege then null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', '44000000-0000-0000-0000-000000000001', true);
select public.accept_stable_invitation(
  repeat('a', 64), 'Uitgenodigd lid', 'Ruiter',
  '91000000-0000-0000-0000-000000000002'
);
-- Serial duplicate is idempotent.
select public.accept_stable_invitation(
  repeat('a', 64), 'Uitgenodigd lid', 'Ruiter',
  '91000000-0000-0000-0000-000000000002'
);

reset role;
do $$
declare
  membership_count integer;
  raw_column_count integer;
begin
  select count(*) into membership_count
  from public.stable_memberships
  where stable_id = '51000000-0000-0000-0000-000000000001'
    and user_id = '44000000-0000-0000-0000-000000000001'
    and status = 'active';
  if membership_count <> 1 then
    raise exception 'Invitation acceptance did not create exactly one membership';
  end if;
  if exists (
    select 1 from public.stable_invitations
    where token_hash = convert_to(repeat('a', 64), 'UTF8')
  ) then
    raise exception 'Raw token was stored instead of a digest';
  end if;
  select count(*) into raw_column_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'stable_invitations'
    and column_name in ('token', 'raw_token', 'invitation_url');
  if raw_column_count <> 0 then
    raise exception 'Raw invitation token column exists';
  end if;
end;
$$;

-- Expired, declined, revoked and rotated tokens cannot be consumed.
insert into public.stable_invitations (
  id, stable_id, invited_email, offered_role, token_hash, status,
  expires_at, invited_by_membership_id, last_sent_at, created_at
)
values
  ('92000000-0000-0000-0000-000000000001', '51000000-0000-0000-0000-000000000001', 'outsider@example.invalid', 'viewer', decode(repeat('b',64),'hex'), 'pending', now() + interval '1 minute', '81000000-0000-0000-0000-000000000001', now() - interval '2 minutes', now() - interval '1 day'),
  ('92000000-0000-0000-0000-000000000002', '51000000-0000-0000-0000-000000000001', 'unused-declined@example.invalid', 'viewer', decode(repeat('c',64),'hex'), 'declined', now() + interval '1 day', '81000000-0000-0000-0000-000000000001', now(), now() - interval '1 day'),
  ('92000000-0000-0000-0000-000000000003', '51000000-0000-0000-0000-000000000001', 'unused-revoked@example.invalid', 'viewer', decode(repeat('d',64),'hex'), 'revoked', now() + interval '1 day', '81000000-0000-0000-0000-000000000001', now(), now() - interval '1 day'),
  ('92000000-0000-0000-0000-000000000004', '51000000-0000-0000-0000-000000000001', 'unused-expired@example.invalid', 'viewer', decode(repeat('e',64),'hex'), 'pending', now() - interval '1 second', '81000000-0000-0000-0000-000000000001', now() - interval '2 days', now() - interval '3 days');

set local role authenticated;
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select public.resend_stable_invitation(
  '92000000-0000-0000-0000-000000000001', repeat('f', 64), gen_random_uuid()
);

reset role;
do $$
begin
  if exists (
    select 1 from public.stable_invitations
    where id = '92000000-0000-0000-0000-000000000001'
      and token_hash = decode(repeat('b',64), 'hex')
  ) then
    raise exception 'Old token remained valid after resend';
  end if;
end;
$$;

-- Admin boundaries and safe ownership transfer.
set local role authenticated;
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000002', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select public.change_stable_member_role(
  '81000000-0000-0000-0000-000000000003', 'viewer', gen_random_uuid()
);
do $$
begin
  begin
    perform public.remove_stable_membership(
      '81000000-0000-0000-0000-000000000001', gen_random_uuid()
    );
    raise exception 'Admin removed owner';
  exception when insufficient_privilege then null;
  end;
  perform public.leave_stable(
    '51000000-0000-0000-0000-000000000001', gen_random_uuid()
  );
end;
$$;

-- Restore admin for ownership transfer fixture.
reset role;
update public.stable_memberships set
  status = 'active', joined_at = now(), ended_at = null,
  ended_reason = null
where id = '81000000-0000-0000-0000-000000000002';

set local role authenticated;
select set_config('request.jwt.claim.sub', '41000000-0000-0000-0000-000000000001', true);
select set_config('request.jwt.claim.role', 'authenticated', true);
select public.transfer_stable_ownership(
  '51000000-0000-0000-0000-000000000001',
  '81000000-0000-0000-0000-000000000002',
  '93000000-0000-0000-0000-000000000001'
);
set constraints all immediate;

reset role;
do $$
begin
  if (
    select count(*) from public.stable_memberships
    where stable_id = '51000000-0000-0000-0000-000000000001'
      and role = 'owner' and status = 'active'
  ) <> 1 then
    raise exception 'Ownership transfer broke exact owner invariant';
  end if;
  if exists (
    select stable_member_id
    from public.stable_memberships
    where stable_member_id is not null
    group by stable_member_id
    having count(*) > 1
  ) then
    raise exception 'A stable member is linked to multiple accounts';
  end if;
  if not exists (
    select 1 from public.stable_members
    where id = '71000000-0000-0000-0000-000000000005'
  ) then
    raise exception 'Operational stable member without account was lost';
  end if;
end;
$$;

-- An active stable cannot commit with zero owners.
do $$
begin
  begin
    set constraints all deferred;
    update public.stable_memberships set role = 'admin'
    where stable_id = '51000000-0000-0000-0000-000000000001'
      and role = 'owner' and status = 'active';
    set constraints all immediate;
    raise exception 'Zero-owner state passed deferred invariant';
  exception when check_violation then
    set constraints all deferred;
  end;
end;
$$;

rollback;
