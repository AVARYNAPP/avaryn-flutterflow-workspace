begin;

select extensions.plan(1);

create temporary table c003e_fixture(
  auth_horse_sender uuid not null,auth_org_sender uuid not null,auth_recipient uuid not null,
  auth_other uuid not null,auth_outsider uuid not null,auth_inactive uuid not null,
  horse_sender uuid,org_sender uuid,recipient uuid,other_profile uuid,outsider uuid,inactive_profile uuid,
  horse_id uuid,organization_id uuid,horse_access_before bigint,horse_transfer_id uuid,horse_token text,
  organization_transfer_id uuid,organization_token text
);
grant select,update on pg_temp.c003e_fixture to authenticated,anon,service_role;

insert into pg_temp.c003e_fixture(
  auth_horse_sender,auth_org_sender,auth_recipient,auth_other,auth_outsider,auth_inactive
) values(
  'c003e000-0000-4000-8000-000000000001','c003e000-0000-4000-8000-000000000002',
  'c003e000-0000-4000-8000-000000000003','c003e000-0000-4000-8000-000000000004',
  'c003e000-0000-4000-8000-000000000005','c003e000-0000-4000-8000-000000000006'
);
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000'::uuid,auth_horse_sender,'authenticated','authenticated',
  'c003e-horse-sender@example.invalid','',now(),'{}'::jsonb,'{"role":"platform_admin","primary_authority_profile_id":"spoof"}'::jsonb,now(),now()
from pg_temp.c003e_fixture
union all select '00000000-0000-0000-0000-000000000000'::uuid,auth_org_sender,'authenticated','authenticated',
  'c003e-org-sender@example.invalid','',now(),'{}'::jsonb,'{"primary_admin_profile_id":"spoof"}'::jsonb,now(),now() from pg_temp.c003e_fixture
union all select '00000000-0000-0000-0000-000000000000'::uuid,auth_recipient,'authenticated','authenticated',
  'c003e-recipient@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c003e_fixture
union all select '00000000-0000-0000-0000-000000000000'::uuid,auth_other,'authenticated','authenticated',
  'c003e-other@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c003e_fixture
union all select '00000000-0000-0000-0000-000000000000'::uuid,auth_outsider,'authenticated','authenticated',
  'c003e-outsider@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c003e_fixture
union all select '00000000-0000-0000-0000-000000000000'::uuid,auth_inactive,'authenticated','authenticated',
  'c003e-inactive@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c003e_fixture;

update pg_temp.c003e_fixture fixture set
  horse_sender=(select id from public.profiles where auth_user_id=fixture.auth_horse_sender),
  org_sender=(select id from public.profiles where auth_user_id=fixture.auth_org_sender),
  recipient=(select id from public.profiles where auth_user_id=fixture.auth_recipient),
  other_profile=(select id from public.profiles where auth_user_id=fixture.auth_other),
  outsider=(select id from public.profiles where auth_user_id=fixture.auth_outsider),
  inactive_profile=(select id from public.profiles where auth_user_id=fixture.auth_inactive);

-- Inactive profiles cannot become transfer recipients.
select set_config('request.jwt.claim.sub',(select auth_inactive::text from pg_temp.c003e_fixture),true);
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
select * from public.request_profile_deletion(1,'c003e090-0000-4000-8000-000000000001');

-- Client roles have no table or unexpected RPC path.
reset role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','anon',true);
set local role anon;
do $$ begin
  begin perform count(*) from public.horse_authority_transfers;raise exception 'anon read transfers';
    exception when insufficient_privilege then null;end;
  begin perform public.initiate_horse_authority_transfer(gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
    raise exception 'anon initiated transfer';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.role','service_role',true);
set local role service_role;
do $$ begin
  begin truncate public.organization_authority_transfers;raise exception 'service role truncated transfers';
    exception when insufficient_privilege then null;end;
  begin perform public.initiate_organization_authority_transfer(gen_random_uuid(),gen_random_uuid(),gen_random_uuid());
    raise exception 'service role initiated transfer';exception when insufficient_privilege then null;end;
end $$;
reset role;

-- Create independent scalar-primary resources.
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',(select auth_horse_sender::text from pg_temp.c003e_fixture),true);
set local role authenticated;
with created as(select * from public.create_canonical_horse(
  'C003E Horse',null,'unknown',null,'c003e100-0000-4000-8000-000000000001','{}'
)) update pg_temp.c003e_fixture fixture set horse_id=created.horse_id from created;
do $$ begin
  begin perform public.initiate_horse_authority_transfer(
    (select horse_id from pg_temp.c003e_fixture),(select inactive_profile from pg_temp.c003e_fixture),gen_random_uuid());
    raise exception 'inactive recipient accepted for transfer';exception when invalid_parameter_value then null;end;
end $$;
select set_config('request.jwt.claim.sub',(select auth_org_sender::text from pg_temp.c003e_fixture),true);
with created as(select * from public.create_organization(
  'stable','C003E Organization',null,'c003e100-0000-4000-8000-000000000002','{}'
)) update pg_temp.c003e_fixture fixture set organization_id=created.organization_id from created;

-- Outsider and metadata spoofing never substitute for scalar authority.
select set_config('request.jwt.claim.sub',(select auth_outsider::text from pg_temp.c003e_fixture),true);
select set_config('request.jwt.claims',jsonb_build_object(
  'sub',(select auth_outsider from pg_temp.c003e_fixture),'role','authenticated',
  'primary_authority_profile_id',(select horse_sender from pg_temp.c003e_fixture),
  'primary_admin_profile_id',(select org_sender from pg_temp.c003e_fixture))::text,true);
do $$ begin
  begin perform public.initiate_horse_authority_transfer(
    (select horse_id from pg_temp.c003e_fixture),(select recipient from pg_temp.c003e_fixture),gen_random_uuid());
    raise exception 'outsider initiated horse transfer';exception when insufficient_privilege then null;end;
  begin perform public.initiate_organization_authority_transfer(
    (select organization_id from pg_temp.c003e_fixture),(select recipient from pg_temp.c003e_fixture),gen_random_uuid());
    raise exception 'outsider initiated organization transfer';exception when insufficient_privilege then null;end;
end $$;

-- A delegated manager still cannot transfer scalar Horse Authority.
select set_config('request.jwt.claim.sub',(select auth_horse_sender::text from pg_temp.c003e_fixture),true);
select * from public.grant_horse_profile_permission(
  (select horse_id from pg_temp.c003e_fixture),(select outsider from pg_temp.c003e_fixture),
  'horse.manage',null,null,null,'MANUAL_GRANT','c003e110-0000-4000-8000-000000000001');
select set_config('request.jwt.claim.sub',(select auth_outsider::text from pg_temp.c003e_fixture),true);
do $$ begin
  begin perform public.initiate_horse_authority_transfer(
    (select horse_id from pg_temp.c003e_fixture),(select recipient from pg_temp.c003e_fixture),gen_random_uuid());
    raise exception 'delegated manager initiated transfer';exception when insufficient_privilege then null;end;
end $$;

-- Horse transfer initiation is seven-day, high-entropy and idempotent.
select set_config('request.jwt.claim.sub',(select auth_horse_sender::text from pg_temp.c003e_fixture),true);
with initiated as(select * from public.initiate_horse_authority_transfer(
  (select horse_id from pg_temp.c003e_fixture),(select recipient from pg_temp.c003e_fixture),
  'c003e120-0000-4000-8000-000000000001'
)) update pg_temp.c003e_fixture fixture set
  horse_access_before=(select access_version from public.canonical_horses where id=fixture.horse_id),
  horse_transfer_id=initiated.transfer_id,horse_token=initiated.transfer_token from initiated;
do $$ declare replay record;
begin
  select * into replay from public.initiate_horse_authority_transfer(
    (select horse_id from pg_temp.c003e_fixture),(select recipient from pg_temp.c003e_fixture),
    'c003e120-0000-4000-8000-000000000001');
  if replay.applied or replay.transfer_token is not null
  then raise exception 'horse transfer idempotency failed';end if;
end $$;

-- Primary deletion remains blocked before accepted transfer.
do $$ begin
  begin
    perform public.request_profile_deletion(2,'c003e120-0000-4000-8000-000000000002');
    set constraints c003c_primary_authority_profiles immediate;
    raise exception 'primary authority entered deletion before transfer';
  exception when check_violation then null;end;
end $$;

select set_config('request.jwt.claim.sub',(select auth_outsider::text from pg_temp.c003e_fixture),true);
do $$ begin
  if (select count(*) from public.preview_horse_authority_transfer((select horse_token from pg_temp.c003e_fixture)))<>0
  then raise exception 'wrong actor previewed horse transfer';end if;
  begin perform public.respond_horse_authority_transfer((select horse_token from pg_temp.c003e_fixture),'accept',gen_random_uuid());
    raise exception 'wrong actor accepted horse transfer';exception when insufficient_privilege then null;end;
end $$;

-- Recipient acceptance atomically changes exactly one scalar authority and all
-- required versions; token replay is terminal.
select set_config('request.jwt.claim.sub',(select auth_recipient::text from pg_temp.c003e_fixture),true);
do $$ begin
  if (select count(*) from public.preview_horse_authority_transfer((select horse_token from pg_temp.c003e_fixture)))<>1
  then raise exception 'recipient could not preview horse transfer';end if;
end $$;
select * from public.respond_horse_authority_transfer(
  (select horse_token from pg_temp.c003e_fixture),'accept','c003e120-0000-4000-8000-000000000003');
do $$ begin
  if not public.has_canonical_horse_permission((select horse_id from pg_temp.c003e_fixture),'horse.transfer')
  then raise exception 'new primary lacks transfer authority';end if;
  begin perform public.respond_horse_authority_transfer((select horse_token from pg_temp.c003e_fixture),'accept',gen_random_uuid());
    raise exception 'terminal horse transfer token replayed';exception when insufficient_privilege then null;end;
  begin update public.canonical_horses set primary_authority_profile_id=null where id=(select horse_id from pg_temp.c003e_fixture);
    raise exception 'client nulled primary authority';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub',(select auth_horse_sender::text from pg_temp.c003e_fixture),true);
do $$ begin
  if public.has_canonical_horse_permission((select horse_id from pg_temp.c003e_fixture),'horse.transfer')
  then raise exception 'old horse primary retained transfer authority';end if;
end $$;
reset role;
do $$ begin
  if (select primary_authority_profile_id from public.canonical_horses where id=(select horse_id from pg_temp.c003e_fixture))
      <>(select recipient from pg_temp.c003e_fixture)
    or (select authority_version from public.canonical_horses where id=(select horse_id from pg_temp.c003e_fixture))<>2
    or (select access_version from public.canonical_horses where id=(select horse_id from pg_temp.c003e_fixture))
      <>(select horse_access_before+1 from pg_temp.c003e_fixture)
    or (select status from public.horse_authority_transfers where id=(select horse_transfer_id from pg_temp.c003e_fixture))<>'accepted'
    or (select token_digest from public.horse_authority_transfers where id=(select horse_transfer_id from pg_temp.c003e_fixture)) is not null
  then raise exception 'horse transfer atomic state invalid: %',(
    select pg_catalog.jsonb_build_object(
      'primary',horse.primary_authority_profile_id,'expected_primary',fixture.recipient,
      'authority_version',horse.authority_version,'access_version',horse.access_version,
      'status',transfer.status,'token_cleared',transfer.token_digest is null
    )
    from pg_temp.c003e_fixture fixture
    join public.canonical_horses horse on horse.id=fixture.horse_id
    join public.horse_authority_transfers transfer on transfer.id=fixture.horse_transfer_id
  );end if;
  begin update public.horse_authority_transfers set status='revoked'
    where id=(select horse_transfer_id from pg_temp.c003e_fixture);
    raise exception 'terminal horse transfer mutated';exception when object_not_in_prerequisite_state then null;end;
end $$;
set local role authenticated;

-- Revoke, decline, expiry and stale authority-version leave scalar authority unchanged.
select set_config('request.jwt.claim.sub',(select auth_recipient::text from pg_temp.c003e_fixture),true);
do $$ declare created record;revoked record;
begin
  select * into created from public.initiate_horse_authority_transfer(
    (select horse_id from pg_temp.c003e_fixture),(select other_profile from pg_temp.c003e_fixture),
    'c003e130-0000-4000-8000-000000000001');
  select * into revoked from public.revoke_horse_authority_transfer(created.transfer_id,1,
    'c003e130-0000-4000-8000-000000000002');
  if revoked.status<>'revoked' then raise exception 'horse transfer revoke failed';end if;
end $$;
with initiated as(select * from public.initiate_horse_authority_transfer(
  (select horse_id from pg_temp.c003e_fixture),(select other_profile from pg_temp.c003e_fixture),
  'c003e130-0000-4000-8000-000000000003'
)) update pg_temp.c003e_fixture fixture set horse_transfer_id=initiated.transfer_id,horse_token=initiated.transfer_token from initiated;
select set_config('request.jwt.claim.sub',(select auth_other::text from pg_temp.c003e_fixture),true);
select * from public.respond_horse_authority_transfer((select horse_token from pg_temp.c003e_fixture),'decline',
  'c003e130-0000-4000-8000-000000000004');
reset role;
do $$ declare raw_token text:='aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';created_time timestamptz:=statement_timestamp()-interval '8 days';
begin
  insert into public.horse_authority_transfers(
    horse_id,sender_profile_id,recipient_profile_id,authority_version_at_create,token_digest,
    expires_at,creation_correlation_id,created_at,updated_at
  ) values((select horse_id from pg_temp.c003e_fixture),(select recipient from pg_temp.c003e_fixture),
    (select other_profile from pg_temp.c003e_fixture),2,private.c003d_token_digest(raw_token),
    created_time+interval '7 days','c003e130-0000-4000-8000-000000000005',created_time,created_time);
  update pg_temp.c003e_fixture set horse_token=raw_token;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select auth_other::text from pg_temp.c003e_fixture),true);
select * from public.respond_horse_authority_transfer((select horse_token from pg_temp.c003e_fixture),'accept',
  'c003e130-0000-4000-8000-000000000006');
reset role;
do $$ declare raw_token text:='bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';now_value timestamptz:=clock_timestamp();
begin
  insert into public.horse_authority_transfers(
    horse_id,sender_profile_id,recipient_profile_id,authority_version_at_create,token_digest,
    expires_at,creation_correlation_id,created_at,updated_at
  ) values((select horse_id from pg_temp.c003e_fixture),(select recipient from pg_temp.c003e_fixture),
    (select other_profile from pg_temp.c003e_fixture),1,private.c003d_token_digest(raw_token),
    now_value+interval '7 days','c003e130-0000-4000-8000-000000000007',now_value,now_value);
  update pg_temp.c003e_fixture set horse_token=raw_token;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub',(select auth_other::text from pg_temp.c003e_fixture),true);
do $$ begin
  begin perform public.respond_horse_authority_transfer((select horse_token from pg_temp.c003e_fixture),'accept',gen_random_uuid());
    raise exception 'stale horse transfer accepted';exception when serialization_failure then null;end;
end $$;

-- Organization initiation, deletion blocker and atomic head/membership/role transfer.
select set_config('request.jwt.claim.sub',(select auth_org_sender::text from pg_temp.c003e_fixture),true);
with initiated as(select * from public.initiate_organization_authority_transfer(
  (select organization_id from pg_temp.c003e_fixture),(select recipient from pg_temp.c003e_fixture),
  'c003e140-0000-4000-8000-000000000001'
)) update pg_temp.c003e_fixture fixture set organization_transfer_id=initiated.transfer_id,
  organization_token=initiated.transfer_token from initiated;
do $$ declare replay record;
begin
  select * into replay from public.initiate_organization_authority_transfer(
    (select organization_id from pg_temp.c003e_fixture),(select recipient from pg_temp.c003e_fixture),
    'c003e140-0000-4000-8000-000000000001');
  if replay.applied or replay.transfer_token is not null then raise exception 'organization transfer idempotency failed';end if;
  begin
    perform public.request_profile_deletion(2,'c003e140-0000-4000-8000-000000000002');
    set constraints c003b_primary_admin_profiles immediate;
    raise exception 'primary admin entered deletion before transfer';
  exception when check_violation then null;end;
end $$;
select set_config('request.jwt.claim.sub',(select auth_recipient::text from pg_temp.c003e_fixture),true);
select * from public.respond_organization_authority_transfer(
  (select organization_token from pg_temp.c003e_fixture),'accept','c003e140-0000-4000-8000-000000000003');
do $$ begin
  if not public.has_organization_permission((select organization_id from pg_temp.c003e_fixture),'organization.roles.manage')
  then raise exception 'new organization primary lacks head permissions';end if;
end $$;
reset role;
do $$
begin
  if (select primary_admin_profile_id from public.organizations where id=(select organization_id from pg_temp.c003e_fixture))
      <>(select recipient from pg_temp.c003e_fixture)
    or (select access_version from public.organizations where id=(select organization_id from pg_temp.c003e_fixture))<>2
    or not exists(
      select 1 from public.organization_memberships membership
      join public.organization_membership_roles assignment on assignment.membership_id=membership.id
      join public.organization_roles role on role.id=assignment.role_id
      where membership.organization_id=(select organization_id from pg_temp.c003e_fixture)
        and membership.profile_id=(select recipient from pg_temp.c003e_fixture)
        and membership.status='active' and assignment.status='active' and role.code='head_admin'
    ) or exists(
      select 1 from public.organization_memberships membership
      join public.organization_membership_roles assignment on assignment.membership_id=membership.id
      join public.organization_roles role on role.id=assignment.role_id
      where membership.organization_id=(select organization_id from pg_temp.c003e_fixture)
        and membership.profile_id=(select org_sender from pg_temp.c003e_fixture)
        and assignment.status='active' and role.code='head_admin'
    )
  then raise exception 'organization transfer atomic membership/role state invalid';end if;
end $$;
set local role authenticated;

-- Any intervening organization access mutation invalidates a pending transfer.
select set_config('request.jwt.claim.sub',(select auth_recipient::text from pg_temp.c003e_fixture),true);
with initiated as(select * from public.initiate_organization_authority_transfer(
  (select organization_id from pg_temp.c003e_fixture),(select other_profile from pg_temp.c003e_fixture),
  'c003e150-0000-4000-8000-000000000001'
)) update pg_temp.c003e_fixture fixture set organization_transfer_id=initiated.transfer_id,
  organization_token=initiated.transfer_token from initiated;
select * from public.create_organization_membership(
  (select organization_id from pg_temp.c003e_fixture),(select outsider from pg_temp.c003e_fixture),null,
  'c003e150-0000-4000-8000-000000000002');
select set_config('request.jwt.claim.sub',(select auth_other::text from pg_temp.c003e_fixture),true);
do $$ begin
  begin perform public.respond_organization_authority_transfer(
    (select organization_token from pg_temp.c003e_fixture),'accept','c003e150-0000-4000-8000-000000000003');
    raise exception 'stale organization transfer accepted';exception when serialization_failure then null;end;
end $$;
select set_config('request.jwt.claim.sub',(select auth_recipient::text from pg_temp.c003e_fixture),true);
select * from public.revoke_organization_authority_transfer(
  (select organization_transfer_id from pg_temp.c003e_fixture),1,'c003e150-0000-4000-8000-000000000004');

-- Final catalog, secret, audit and exact-one checks.
reset role;
do $$ declare procedure_row record;
begin
  if (select count(*) from public.canonical_horses where id=(select horse_id from pg_temp.c003e_fixture)
      and primary_authority_profile_id is not null)<>1
    or (select count(*) from public.organizations where id=(select organization_id from pg_temp.c003e_fixture)
      and primary_admin_profile_id is not null)<>1
  then raise exception 'scalar exact-one invariant failed';end if;
  if exists(select 1 from public.audit_events event
      where event.event_type like '%transfer%' and event.metadata::text ilike '%aaaaaaaa%')
    or exists(select 1 from public.audit_events event
      where event.event_type like '%transfer%' and event.metadata::text ilike '%example.invalid%')
  then raise exception 'transfer token or e-mail leaked to audit';end if;
  if not exists(select 1 from public.audit_events where event_type='horse.authority_transfer_accepted')
    or not exists(select 1 from public.audit_events where event_type='organization.head_transfer_accepted')
    or not exists(select 1 from public.audit_events where event_type='horse.authority_transfer_expired')
  then raise exception 'required transfer audit events missing';end if;
  if has_table_privilege('authenticated','public.horse_authority_transfers','select')
    or has_table_privilege('service_role','public.organization_authority_transfers','select')
  then raise exception 'transfer table exposed';end if;
  for procedure_row in
    select procedure.oid from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='private' and procedure.proname like 'c003e_%'
  loop
    if has_function_privilege('anon',procedure_row.oid,'execute')
      or has_function_privilege('authenticated',procedure_row.oid,'execute')
      or has_function_privilege('service_role',procedure_row.oid,'execute')
    then raise exception 'private C-003E routine executable by client';end if;
  end loop;
end $$;

select extensions.pass('C-003E atomic transfer state machines passed');
select * from extensions.finish();
rollback;
