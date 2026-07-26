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
  '{"role":"owner"}',
  now(),
  now()
from (
  values
    ('a1000000-0000-0000-0000-000000000001', 'matrix-owner@example.invalid'),
    ('a1000000-0000-0000-0000-000000000002', 'matrix-admin@example.invalid'),
    ('a1000000-0000-0000-0000-000000000003', 'matrix-member@example.invalid'),
    ('a1000000-0000-0000-0000-000000000004', 'matrix-viewer@example.invalid'),
    ('a1000000-0000-0000-0000-000000000005', 'matrix-removed@example.invalid'),
    ('a1000000-0000-0000-0000-000000000006', 'matrix-suspended@example.invalid'),
    ('a1000000-0000-0000-0000-000000000007', 'matrix-left@example.invalid'),
    ('a1000000-0000-0000-0000-000000000008', 'matrix-outsider@example.invalid'),
    ('a2000000-0000-0000-0000-000000000001', 'matrix-owner-b@example.invalid')
) as fixture(id, email);

insert into public.stables (
  id, kind, name, status, timezone, locale,
  created_by_user_id, creation_request_id
)
values
  (
    'b1000000-0000-0000-0000-000000000001',
    'organization', 'Matrix stal A', 'active', 'Europe/Amsterdam', 'nl',
    'a1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001'
  ),
  (
    'b2000000-0000-0000-0000-000000000001',
    'organization', 'Matrix stal B', 'active', 'Europe/Amsterdam', 'nl',
    'a2000000-0000-0000-0000-000000000001',
    'c2000000-0000-0000-0000-000000000001'
  );

insert into public.stable_members (
  id, stable_id, display_name, function_title, source
)
values
  ('d1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'Matrix owner', 'Owner', 'owner_creation'),
  ('d1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001', 'Matrix admin', 'Admin', 'manual'),
  ('d1000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000001', 'Matrix member', 'Member', 'manual'),
  ('d1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', 'Matrix viewer', 'Viewer', 'manual'),
  ('d1000000-0000-0000-0000-000000000005', 'b1000000-0000-0000-0000-000000000001', 'Matrix removed', null, 'manual'),
  ('d1000000-0000-0000-0000-000000000006', 'b1000000-0000-0000-0000-000000000001', 'Matrix suspended', null, 'manual'),
  ('d1000000-0000-0000-0000-000000000007', 'b1000000-0000-0000-0000-000000000001', 'Matrix left', null, 'manual'),
  ('d1000000-0000-0000-0000-000000000009', 'b1000000-0000-0000-0000-000000000001', 'Unlinked employee', 'Trainer', 'manual'),
  ('d2000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001', 'Matrix owner B', 'Owner', 'owner_creation');

insert into public.stable_memberships (
  id, stable_id, user_id, stable_member_id, role, status,
  joined_at, ended_at, ended_reason
)
values
  ('e1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'owner', 'active', now(), null, null),
  ('e1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000002', 'admin', 'active', now(), null, null),
  ('e1000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000003', 'member', 'active', now(), null, null),
  ('e1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000004', 'viewer', 'active', now(), null, null),
  ('e1000000-0000-0000-0000-000000000005', 'b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000005', 'd1000000-0000-0000-0000-000000000005', 'member', 'removed', now(), now(), 'fixture'),
  ('e1000000-0000-0000-0000-000000000006', 'b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000006', 'd1000000-0000-0000-0000-000000000006', 'member', 'suspended', now(), now(), 'fixture'),
  ('e1000000-0000-0000-0000-000000000007', 'b1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000007', 'd1000000-0000-0000-0000-000000000007', 'viewer', 'left', now(), now(), 'fixture'),
  ('e2000000-0000-0000-0000-000000000001', 'b2000000-0000-0000-0000-000000000001', 'a2000000-0000-0000-0000-000000000001', 'd2000000-0000-0000-0000-000000000001', 'owner', 'active', now(), null, null);

insert into public.stable_invitations (
  id, stable_id, invited_email, offered_role, token_hash, status,
  expires_at, invited_by_membership_id
)
values (
  'f1000000-0000-0000-0000-000000000001',
  'b1000000-0000-0000-0000-000000000001',
  'matrix-invite@example.invalid',
  'member',
  decode(repeat('1', 64), 'hex'),
  'pending',
  now() + interval '7 days',
  'e1000000-0000-0000-0000-000000000001'
);

insert into public.account_workspace_preferences (
  user_id, last_selected_stable_id, workspace_mode, phase_4b_status
)
select
  id,
  case when id = 'a1000000-0000-0000-0000-000000000008'::uuid
    then null
    else 'b1000000-0000-0000-0000-000000000001'::uuid
  end,
  'stable',
  'active'
from auth.users
where id::text like 'a1000000-%';

insert into public.stable_security_events (
  stable_id, actor_user_id, actor_membership_id, event_type
)
values (
  'b1000000-0000-0000-0000-000000000001',
  'a1000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000001',
  'stable_updated'
);

set constraints all immediate;
set constraints all deferred;

-- Full direct-DML denial for every authenticated actor class.
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);
do $$
declare
  actor_id text;
  relation_name text;
  operation_name text;
begin
  foreach actor_id in array array[
    'a1000000-0000-0000-0000-000000000001',
    'a1000000-0000-0000-0000-000000000002',
    'a1000000-0000-0000-0000-000000000003',
    'a1000000-0000-0000-0000-000000000004',
    'a1000000-0000-0000-0000-000000000008'
  ] loop
    perform set_config('request.jwt.claim.sub', actor_id, true);
    foreach relation_name in array array[
      'stables',
      'stable_members',
      'stable_memberships',
      'stable_invitations',
      'account_workspace_preferences',
      'stable_security_events'
    ] loop
      foreach operation_name in array array['insert', 'update', 'delete'] loop
        begin
          if operation_name = 'insert' then
            execute format('insert into public.%I default values', relation_name);
          elsif operation_name = 'update' then
            execute format(
              'update public.%I set %I = %I',
              relation_name,
              case relation_name
                when 'stables' then 'name'
                when 'stable_members' then 'display_name'
                when 'stable_memberships' then 'role'
                when 'stable_invitations' then 'status'
                when 'account_workspace_preferences' then 'workspace_mode'
                else 'event_type'
              end,
              case relation_name
                when 'stables' then 'name'
                when 'stable_members' then 'display_name'
                when 'stable_memberships' then 'role'
                when 'stable_invitations' then 'status'
                when 'account_workspace_preferences' then 'workspace_mode'
                else 'event_type'
              end
            );
          else
            execute format('delete from public.%I', relation_name);
          end if;
          raise exception 'Direct % on % succeeded for %',
            operation_name, relation_name, actor_id;
        exception when insufficient_privilege then
          null;
        end;
      end loop;
    end loop;
  end loop;
end;
$$;

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
select set_config('request.jwt.claim.role', 'anon', true);
do $$
declare
  relation_name text;
  operation_name text;
  column_name text;
begin
  foreach relation_name in array array[
    'stables',
    'stable_members',
    'stable_memberships',
    'stable_invitations',
    'account_workspace_preferences',
    'stable_security_events'
  ] loop
    column_name := case relation_name
      when 'stables' then 'name'
      when 'stable_members' then 'display_name'
      when 'stable_memberships' then 'role'
      when 'stable_invitations' then 'status'
      when 'account_workspace_preferences' then 'workspace_mode'
      else 'event_type'
    end;
    foreach operation_name in array array['insert', 'update', 'delete'] loop
      begin
        if operation_name = 'insert' then
          execute format('insert into public.%I default values', relation_name);
        elsif operation_name = 'update' then
          execute format(
            'update public.%I set %I = %I',
            relation_name, column_name, column_name
          );
        else
          execute format('delete from public.%I', relation_name);
        end if;
        raise exception 'Anonymous direct % on % succeeded',
          operation_name, relation_name;
      exception when insufficient_privilege then
        null;
      end;
    end loop;
  end loop;
end;
$$;

reset role;
set local role authenticated;
select set_config('request.jwt.claim.role', 'authenticated', true);

-- Removed, suspended and left each retain only their own preference and own
-- membership-status row; all stable authority and mutations are denied.
do $$
declare
  actor_id text;
  expected_status text;
begin
  for actor_id, expected_status in
    select * from (values
      ('a1000000-0000-0000-0000-000000000005', 'removed'),
      ('a1000000-0000-0000-0000-000000000006', 'suspended'),
      ('a1000000-0000-0000-0000-000000000007', 'left')
    ) as fixture(actor_id, expected_status)
  loop
    perform set_config('request.jwt.claim.sub', actor_id, true);
    perform set_config('request.jwt.claim.role', 'owner', true);
    if (select count(*) from public.stables) <> 0 then
      raise exception '% retained stable visibility', expected_status;
    end if;
    if (select count(*) from public.stable_members) <> 0 then
      raise exception '% retained roster visibility', expected_status;
    end if;
    if (select count(*) from public.stable_memberships) <> 1
      or (select status from public.stable_memberships limit 1) <> expected_status
    then
      raise exception '% membership status visibility mismatch', expected_status;
    end if;
    if (select count(*) from public.stable_invitations) <> 0 then
      raise exception '% retained invitation visibility', expected_status;
    end if;
    if (select count(*) from public.stable_security_events) <> 0 then
      raise exception '% retained audit visibility', expected_status;
    end if;
    if (select count(*) from public.account_workspace_preferences) <> 1 then
      raise exception '% lost own preference boundary', expected_status;
    end if;
    if (select count(*) from public.list_stable_member_directory(
      'b1000000-0000-0000-0000-000000000001'
    )) <> 0 then
      raise exception '% retained directory visibility', expected_status;
    end if;
    begin
      perform public.set_selected_stable(
        'b1000000-0000-0000-0000-000000000001',
        'stable'
      );
      raise exception '% selected stable without active membership', expected_status;
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.update_stable(
        'b1000000-0000-0000-0000-000000000001',
        'Aanval', 'UTC', 'nl', gen_random_uuid()
      );
      raise exception '% updated stable', expected_status;
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.create_stable_invitation(
        'b1000000-0000-0000-0000-000000000001',
        'blocked@example.invalid', 'member', repeat('2', 64),
        null, gen_random_uuid()
      );
      raise exception '% created invitation', expected_status;
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.archive_stable(
        'b1000000-0000-0000-0000-000000000001', gen_random_uuid()
      );
      raise exception '% archived stable', expected_status;
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.change_stable_member_role(
        'e1000000-0000-0000-0000-000000000004', 'member', gen_random_uuid()
      );
      raise exception '% changed another role', expected_status;
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.remove_stable_membership(
        'e1000000-0000-0000-0000-000000000004', gen_random_uuid()
      );
      raise exception '% removed another membership', expected_status;
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.suspend_stable_membership(
        'e1000000-0000-0000-0000-000000000004', gen_random_uuid()
      );
      raise exception '% suspended another membership', expected_status;
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.transfer_stable_ownership(
        'b1000000-0000-0000-0000-000000000001',
        'e1000000-0000-0000-0000-000000000002',
        gen_random_uuid()
      );
      raise exception '% transferred ownership', expected_status;
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.link_account_to_stable_member(
        'e1000000-0000-0000-0000-000000000003',
        'd1000000-0000-0000-0000-000000000009',
        gen_random_uuid()
      );
      raise exception '% linked account to member', expected_status;
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.resend_stable_invitation(
        'f1000000-0000-0000-0000-000000000001',
        repeat('3', 64),
        gen_random_uuid()
      );
      raise exception '% resent invitation', expected_status;
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.revoke_stable_invitation(
        'f1000000-0000-0000-0000-000000000001',
        gen_random_uuid()
      );
      raise exception '% revoked invitation', expected_status;
    exception when insufficient_privilege then null;
    end;
    if public.leave_stable(
      'b1000000-0000-0000-0000-000000000001', gen_random_uuid()
    ) then
      raise exception '% left stable a second time', expected_status;
    end if;
  end loop;
end;
$$;

-- Allowed SELECT matrix.
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
do $$
begin
  if (select count(*) from public.stables) <> 1
    or (select count(*) from public.stable_members) <> 8
    or (select count(*) from public.stable_memberships) <> 7
    or (select count(*) from public.stable_invitations) <> 1
    or (select count(*) from public.stable_security_events) <> 1
  then
    raise exception 'Owner SELECT matrix mismatch';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000002', true);
do $$
begin
  if (select count(*) from public.stables) <> 1
    or (select count(*) from public.stable_members) <> 8
    or (select count(*) from public.stable_memberships) <> 7
    or (select count(*) from public.stable_invitations) <> 1
    or (select count(*) from public.stable_security_events) <> 1
  then
    raise exception 'Admin SELECT matrix mismatch';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000003', true);
do $$
begin
  if (select count(*) from public.stables) <> 1
    or (select count(*) from public.stable_members) <> 0
    or (select count(*) from public.stable_memberships) <> 1
    or (select count(*) from public.stable_invitations) <> 0
    or (select count(*) from public.stable_security_events) <> 0
    or (select count(*) from public.list_stable_member_directory(
      'b1000000-0000-0000-0000-000000000001'
    )) <> 8
  then
    raise exception 'Member SELECT matrix mismatch';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000004', true);
do $$
begin
  if (select count(*) from public.stables) <> 1
    or (select count(*) from public.stable_members) <> 0
    or (select count(*) from public.stable_memberships) <> 1
    or (select count(*) from public.stable_invitations) <> 0
    or (select count(*) from public.stable_security_events) <> 0
  then
    raise exception 'Viewer SELECT matrix mismatch';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000008', true);
do $$
begin
  if (select count(*) from public.stables) <> 0
    or (select count(*) from public.stable_members) <> 0
    or (select count(*) from public.stable_memberships) <> 0
    or (select count(*) from public.stable_invitations) <> 0
    or (select count(*) from public.stable_security_events) <> 0
    or (select count(*) from public.account_workspace_preferences) <> 1
  then
    raise exception 'Outsider SELECT matrix mismatch';
  end if;
end;
$$;

-- Real management RPC flows with allowed and denied actors.
select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000002', true);
select public.update_stable(
  'b1000000-0000-0000-0000-000000000001',
  'Matrix stal bijgewerkt', 'Europe/Brussels', 'nl', gen_random_uuid()
);
select public.change_stable_member_role(
  'e1000000-0000-0000-0000-000000000003', 'viewer', gen_random_uuid()
);
do $$
begin
  begin
    perform public.change_stable_member_role(
      'e1000000-0000-0000-0000-000000000001', 'viewer', gen_random_uuid()
    );
    raise exception 'Admin changed owner';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.suspend_stable_membership(
      'e1000000-0000-0000-0000-000000000002', gen_random_uuid()
    );
    raise exception 'Admin suspended admin';
  exception when insufficient_privilege then null;
  end;
end;
$$;

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
select public.link_account_to_stable_member(
  'e1000000-0000-0000-0000-000000000003',
  'd1000000-0000-0000-0000-000000000009',
  gen_random_uuid()
);
select public.suspend_stable_membership(
  'e1000000-0000-0000-0000-000000000003', gen_random_uuid()
);
select public.remove_stable_membership(
  'e1000000-0000-0000-0000-000000000004', gen_random_uuid()
);
select public.transfer_stable_ownership(
  'b1000000-0000-0000-0000-000000000001',
  'e1000000-0000-0000-0000-000000000002',
  gen_random_uuid()
);

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000001', true);
select public.leave_stable(
  'b1000000-0000-0000-0000-000000000001', gen_random_uuid()
);

select set_config('request.jwt.claim.sub', 'a1000000-0000-0000-0000-000000000002', true);
select public.archive_stable(
  'b1000000-0000-0000-0000-000000000001', gen_random_uuid()
);
set constraints all immediate;

reset role;
do $$
begin
  if (
    select count(*) from public.stable_memberships
    where stable_id = 'b1000000-0000-0000-0000-000000000001'
      and role = 'owner' and status = 'active'
  ) <> 1 then
    raise exception 'Management flows broke exact owner invariant';
  end if;
  if (
    select count(*) from public.stable_security_events
    where stable_id = 'b1000000-0000-0000-0000-000000000001'
      and event_type in (
        'stable_updated', 'role_changed', 'stable_member_linked',
        'membership_suspended', 'membership_removed', 'ownership_transferred',
        'membership_left', 'stable_archived'
      )
  ) < 8 then
    raise exception 'Management flow audit events are incomplete';
  end if;
  if exists (
    select stable_member_id
    from public.stable_memberships
    where stable_member_id is not null
    group by stable_member_id
    having count(*) > 1
  ) then
    raise exception 'Management flows duplicated a member-account link';
  end if;
  if not exists (
    select 1 from public.stable_memberships
    where id = 'e1000000-0000-0000-0000-000000000003'
      and stable_member_id = 'd1000000-0000-0000-0000-000000000009'
      and status = 'suspended'
  ) then
    raise exception 'Link or suspend flow did not persist';
  end if;
end;
$$;

rollback;
