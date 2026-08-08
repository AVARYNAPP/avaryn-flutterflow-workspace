begin;

select extensions.plan(1);

create temporary table c009_fixture (
  auth_authority uuid not null,
  auth_horse uuid not null,
  auth_worker uuid not null,
  auth_viewer uuid not null,
  auth_wrong uuid not null,
  auth_recipient uuid not null,
  authority_profile uuid,
  horse_profile uuid,
  worker_profile uuid,
  viewer_profile uuid,
  recipient_profile uuid,
  organization_id uuid,
  worker_role_id uuid,
  viewer_role_id uuid,
  worker_membership_id uuid,
  horse_id uuid,
  link_id uuid,
  link_row_version bigint,
  residency_id uuid,
  worker_token text,
  viewer_token text,
  transfer_token text
);
grant select,update on pg_temp.c009_fixture to authenticated,anon,service_role;

insert into pg_temp.c009_fixture(
  auth_authority,auth_horse,auth_worker,auth_viewer,auth_wrong,auth_recipient
) values (
  'c0090000-0000-4000-8000-000000000001',
  'c0090000-0000-4000-8000-000000000002',
  'c0090000-0000-4000-8000-000000000003',
  'c0090000-0000-4000-8000-000000000004',
  'c0090000-0000-4000-8000-000000000005',
  'c0090000-0000-4000-8000-000000000006'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
)
select '00000000-0000-0000-0000-000000000000'::uuid,auth_authority,
  'authenticated','authenticated','c009-authority@example.invalid','',now(),
  '{}'::jsonb,'{"organization_id":"spoof","role":"owner"}'::jsonb,now(),now()
from pg_temp.c009_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_horse,
  'authenticated','authenticated','c009-horse@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c009_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_worker,
  'authenticated','authenticated','c009-worker@example.invalid','',now(),
  '{}'::jsonb,'{"role":"platform_admin"}'::jsonb,now(),now() from pg_temp.c009_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_viewer,
  'authenticated','authenticated','c009-viewer@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c009_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_wrong,
  'authenticated','authenticated','c009-wrong@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c009_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_recipient,
  'authenticated','authenticated','c009-recipient@example.invalid','',now(),
  '{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c009_fixture;

update pg_temp.c009_fixture fixture set
  authority_profile=(select id from public.profiles where auth_user_id=fixture.auth_authority),
  horse_profile=(select id from public.profiles where auth_user_id=fixture.auth_horse),
  worker_profile=(select id from public.profiles where auth_user_id=fixture.auth_worker),
  viewer_profile=(select id from public.profiles where auth_user_id=fixture.auth_viewer),
  recipient_profile=(select id from public.profiles where auth_user_id=fixture.auth_recipient);

-- Only authenticated persons get the product RPC surface. Organizations do
-- not receive auth.users rows, shared credentials or direct DML access.
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','anon',true);
set local role anon;
do $$ begin
  begin perform public.list_stable_accounts();
    raise exception 'anon listed stable accounts';
  exception when insufficient_privilege then null; end;
  begin perform public.create_stable_account('Attack',null,gen_random_uuid());
    raise exception 'anon created stable account';
  exception when insufficient_privilege then null; end;
  begin perform public.get_horse_organization_links(gen_random_uuid());
    raise exception 'anon listed horse-side organization links';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claim.role','service_role',true);
set local role service_role;
do $$ begin
  begin perform private.c009_seed_role_templates(gen_random_uuid(),gen_random_uuid());
    raise exception 'service role executed private C-009 helper';
  exception when insufficient_privilege then null; end;
  begin update public.organizations set primary_admin_profile_id=gen_random_uuid();
    raise exception 'service role directly mutated Organization Authority';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

-- Reimer Dressage starts as an independent canonical organization with one
-- scalar authority, one creator membership and no horse or residency.
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',(select auth_authority::text from pg_temp.c009_fixture),true);
set local role authenticated;
with created as (
  select * from public.create_stable_account(
    'Reimer Dressage','C-009 deterministic vertical fixture',
    'c0091000-0000-4000-8000-000000000001'
  )
) update pg_temp.c009_fixture fixture set organization_id=created.organization_id
from created;

update pg_temp.c009_fixture fixture set
  worker_role_id=(select id from public.organization_roles
    where organization_id=fixture.organization_id and code='stable_worker'),
  viewer_role_id=(select id from public.organization_roles
    where organization_id=fixture.organization_id and code='stable_viewer');

do $$
declare fixture pg_temp.c009_fixture%rowtype; replay record; workspace jsonb;
begin
  select * into fixture from pg_temp.c009_fixture;
  select * into replay from public.create_stable_account(
    'Changed replay','ignored','c0091000-0000-4000-8000-000000000001'
  );
  workspace:=public.get_stable_account_workspace(fixture.organization_id);
  if replay.result_code<>'idempotent_replay' or replay.applied
    or replay.organization_id<>fixture.organization_id
    or (select count(*) from public.organizations where id=fixture.organization_id)<>1
    or (select primary_admin_profile_id from public.organizations where id=fixture.organization_id)<>fixture.authority_profile
    or (select count(*) from public.organization_memberships where organization_id=fixture.organization_id)<>1
    or (select count(*) from public.organization_roles where organization_id=fixture.organization_id
      and code in('head_admin','stable_admin','stable_manager','stable_worker','stable_viewer'))<>5
    or pg_catalog.jsonb_array_length(workspace->'horse_links')<>0
    or pg_catalog.jsonb_array_length(workspace->'residencies')<>0
    or workspace::text like '%@example.invalid%'
    or workspace::text like '%token%'
  then raise exception 'standalone stable account, templates, idempotency or PII-minimized projection failed'; end if;
end;
$$;

select * from public.update_organization(
  (select organization_id from pg_temp.c009_fixture),1,
  'Reimer Dressage','Veilig bijgewerkt','active',
  'c0091000-0000-4000-8000-000000000002'
);

-- Two distinct verified identities get one-time invitations for different
-- bounded role templates. No membership exists before valid acceptance.
with invitation as (
  select * from public.create_stable_invitation_by_role_code(
    (select organization_id from pg_temp.c009_fixture),'stable_worker',
    'c009-worker@example.invalid',statement_timestamp()+interval '7 days',
    'c0091100-0000-4000-8000-000000000001'
  )
) update pg_temp.c009_fixture fixture set worker_token=invitation.invitation_token
from invitation;
with invitation as (
  select * from public.create_stable_invitation_by_role_code(
    (select organization_id from pg_temp.c009_fixture),'stable_viewer',
    'c009-viewer@example.invalid',statement_timestamp()+interval '7 days',
    'c0091100-0000-4000-8000-000000000002'
  )
) update pg_temp.c009_fixture fixture set viewer_token=invitation.invitation_token
from invitation;

do $$ begin
  if exists(select 1 from public.organization_memberships where organization_id=(select organization_id from pg_temp.c009_fixture)
    and profile_id in((select worker_profile from pg_temp.c009_fixture),(select viewer_profile from pg_temp.c009_fixture)))
  then raise exception 'invitation activated membership before acceptance'; end if;
end $$;

select set_config('request.jwt.claim.sub',(select auth_wrong::text from pg_temp.c009_fixture),true);
do $$ begin
  begin perform public.respond_stable_invitation(
    (select worker_token from pg_temp.c009_fixture),'accept',gen_random_uuid()
  ); raise exception 'wrong invitation recipient accepted token';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub',(select auth_worker::text from pg_temp.c009_fixture),true);
with accepted as (
  select * from public.respond_stable_invitation(
    (select worker_token from pg_temp.c009_fixture),'accept',
    'c0091100-0000-4000-8000-000000000003'
  )
) update pg_temp.c009_fixture fixture set worker_membership_id=accepted.membership_id
from accepted;

select set_config('request.jwt.claim.sub',(select auth_viewer::text from pg_temp.c009_fixture),true);
select * from public.respond_stable_invitation(
  (select viewer_token from pg_temp.c009_fixture),'accept',
  'c0091100-0000-4000-8000-000000000004'
);

do $$ begin
  begin perform public.respond_stable_invitation(
    (select viewer_token from pg_temp.c009_fixture),'accept',gen_random_uuid()
  ); raise exception 'terminal invitation replay succeeded';
  exception when insufficient_privilege then null; end;
  if public.has_organization_permission((select organization_id from pg_temp.c009_fixture),'organization.planning.execute')
    or not public.has_organization_permission((select organization_id from pg_temp.c009_fixture),'organization.planning.view')
    or public.has_organization_permission((select organization_id from pg_temp.c009_fixture),'organization.memberships.manage')
  then raise exception 'viewer capability template escaped its exact scope'; end if;
end $$;

select set_config('request.jwt.claim.sub',(select auth_worker::text from pg_temp.c009_fixture),true);
do $$ begin
  if not public.has_organization_permission((select organization_id from pg_temp.c009_fixture),'organization.planning.execute')
    or public.has_organization_permission((select organization_id from pg_temp.c009_fixture),'organization.memberships.manage')
    or public.has_organization_permission((select organization_id from pg_temp.c009_fixture),'organization.roles.manage')
  then raise exception 'worker capability template is over- or under-privileged'; end if;
  begin perform public.set_organization_membership_status(
    (select worker_membership_id from pg_temp.c009_fixture),1,'suspended',null,gen_random_uuid()
  ); raise exception 'worker self-escalated membership management';
  exception when insufficient_privilege then null; end;
end $$;

-- A different personal Horse Authority creates a canonical horse and starts
-- the bilateral link. The organization cannot see horse data and the link is
-- not active until the separately authorized organization context responds.
select set_config('request.jwt.claim.sub',(select auth_horse::text from pg_temp.c009_fixture),true);
with created as (
  select * from public.create_canonical_horse_profile(
    'Reimer Testpaard',null,null,'unknown',null,'Dressuur',null,null,null,
    null,null,null,'c0091200-0000-4000-8000-000000000001'
  )
) update pg_temp.c009_fixture fixture set horse_id=created.horse_id from created;
with proposed as (
  select * from public.propose_organization_horse_link(
    (select horse_id from pg_temp.c009_fixture),
    (select organization_id from pg_temp.c009_fixture),
    'training_provider','horse','c0091200-0000-4000-8000-000000000002'
  )
) update pg_temp.c009_fixture fixture set
  link_id=proposed.link_id,link_row_version=proposed.row_version
from proposed;

select set_config('request.jwt.claim.sub',(select auth_worker::text from pg_temp.c009_fixture),true);
do $$ begin
  begin perform public.respond_organization_horse_link(
    (select link_id from pg_temp.c009_fixture),(select link_row_version from pg_temp.c009_fixture),
    'accept',gen_random_uuid()
  ); raise exception 'worker approved horse link without link capability';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub',(select auth_authority::text from pg_temp.c009_fixture),true);
do $$
declare workspace jsonb;
begin
  workspace:=public.get_stable_account_workspace((select organization_id from pg_temp.c009_fixture));
  if (select status from public.organization_horse_links where id=(select link_id from pg_temp.c009_fixture))<>'proposed'
    or (workspace->'horse_links'->0->>'horse_confirmed')::boolean is not true
    or (workspace->'horse_links'->0->>'organization_confirmed')::boolean is not false
    or workspace->'horse_links'->0->>'horse_name' is not null
    or public.has_canonical_horse_permission((select horse_id from pg_temp.c009_fixture),'horse.view')
  then raise exception 'one-sided link, metadata isolation or zero implicit access failed'; end if;
end;
$$;
select * from public.respond_organization_horse_link(
  (select link_id from pg_temp.c009_fixture),(select link_row_version from pg_temp.c009_fixture),
  'accept','c0091200-0000-4000-8000-000000000003'
);

do $$ begin
  if public.has_canonical_horse_permission((select horse_id from pg_temp.c009_fixture),'horse.view')
  then raise exception 'active organization-horse link implied horse access'; end if;
end $$;

select set_config('request.jwt.claim.sub',(select auth_horse::text from pg_temp.c009_fixture),true);
do $$
declare links jsonb;
begin
  links:=public.get_horse_organization_links((select horse_id from pg_temp.c009_fixture));
  if links->0->>'organization_name'<>'Reimer Dressage'
    or links->0->>'status'<>'active'
    or not exists(
      select 1 from pg_catalog.jsonb_array_elements(links->0->'roles') role
      where role->>'id'=(select worker_role_id::text from pg_temp.c009_fixture)
    )
  then raise exception 'horse-side link projection did not expose the exact active link and grant targets'; end if;
end;
$$;

-- Horse Authority explicitly grants only horse.view to the worker template.
-- The same organization viewer receives nothing and residency remains a
-- separate zero-access record.
select set_config('request.jwt.claim.sub',(select auth_horse::text from pg_temp.c009_fixture),true);
select * from public.grant_horse_organization_role_permission(
  (select horse_id from pg_temp.c009_fixture),(select worker_role_id from pg_temp.c009_fixture),
  'horse.view',(select link_id from pg_temp.c009_fixture),statement_timestamp(),
  statement_timestamp()+interval '30 days','LINK_BOUND',
  'c0091300-0000-4000-8000-000000000001'
);
with residency as (
  select * from public.switch_horse_residency(
    (select horse_id from pg_temp.c009_fixture),(select organization_id from pg_temp.c009_fixture),
    statement_timestamp(),'c0091300-0000-4000-8000-000000000002'
  )
) update pg_temp.c009_fixture fixture set residency_id=residency.residency_id from residency;

select set_config('request.jwt.claim.sub',(select auth_worker::text from pg_temp.c009_fixture),true);
do $$ begin
  if not public.has_canonical_horse_permission((select horse_id from pg_temp.c009_fixture),'horse.view')
    or public.has_canonical_horse_permission((select horse_id from pg_temp.c009_fixture),'horse.edit')
    or (select count(*) from public.list_canonical_horses())<>1
  then raise exception 'exact horse role grant did not stay within worker, horse and capability scope'; end if;
  begin perform public.switch_horse_residency(
    (select horse_id from pg_temp.c009_fixture),(select organization_id from pg_temp.c009_fixture),
    statement_timestamp(),gen_random_uuid()
  ); raise exception 'horse.view holder changed residency';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub',(select auth_viewer::text from pg_temp.c009_fixture),true);
do $$ begin
  if public.has_canonical_horse_permission((select horse_id from pg_temp.c009_fixture),'horse.view')
  then raise exception 'role grant leaked to a different role member'; end if;
end $$;

-- Membership suspension immediately removes organization and derived horse
-- access without changing other memberships, the canonical horse or history.
select set_config('request.jwt.claim.sub',(select auth_authority::text from pg_temp.c009_fixture),true);
select * from public.set_organization_membership_status(
  (select worker_membership_id from pg_temp.c009_fixture),1,'suspended',null,
  'c0091400-0000-4000-8000-000000000001'
);
select set_config('request.jwt.claim.sub',(select auth_worker::text from pg_temp.c009_fixture),true);
do $$ begin
  if public.has_organization_permission((select organization_id from pg_temp.c009_fixture),'organization.view')
    or public.has_canonical_horse_permission((select horse_id from pg_temp.c009_fixture),'horse.view')
  then raise exception 'membership revocation left usable organization or horse access'; end if;
end $$;

-- Residency can end independently and retains organization, horse and history.
select set_config('request.jwt.claim.sub',(select auth_horse::text from pg_temp.c009_fixture),true);
select public.end_horse_residency(
  (select residency_id from pg_temp.c009_fixture),1,
  'c0091400-0000-4000-8000-000000000002'
);
reset role;
do $$ begin
  if (select status from public.horse_residencies where id=(select residency_id from pg_temp.c009_fixture))<>'ended'
    or not exists(select 1 from public.canonical_horses where id=(select horse_id from pg_temp.c009_fixture))
    or not exists(select 1 from public.organizations where id=(select organization_id from pg_temp.c009_fixture))
  then raise exception 'residency history was not independent and durable'; end if;
end $$;
set local role authenticated;

-- The scalar Organization Authority transfer is still the C-003E seven-day,
-- one-time, concurrency-safe route. No admin capability can replace it.
select set_config('request.jwt.claim.sub',(select auth_authority::text from pg_temp.c009_fixture),true);
with initiated as (
  select * from public.initiate_organization_authority_transfer_by_email(
    (select organization_id from pg_temp.c009_fixture),'c009-recipient@example.invalid',
    'c0091500-0000-4000-8000-000000000001'
  )
) update pg_temp.c009_fixture fixture set transfer_token=initiated.transfer_token
from initiated;

select set_config('request.jwt.claim.sub',(select auth_recipient::text from pg_temp.c009_fixture),true);
select * from public.respond_stable_authority_transfer(
  (select transfer_token from pg_temp.c009_fixture),'accept',
  'c0091500-0000-4000-8000-000000000002'
);
do $$
declare actual_authority uuid; expected_authority uuid;
begin
  select primary_admin_profile_id into actual_authority from public.organizations
    where id=(select organization_id from pg_temp.c009_fixture);
  select recipient_profile into expected_authority from pg_temp.c009_fixture;
  if actual_authority is distinct from expected_authority
  then raise exception 'authority transfer scalar authority % is not intended recipient %',actual_authority,expected_authority; end if;
  if (select count(*) from public.organization_membership_roles assignment
      join public.organization_memberships membership on membership.id=assignment.membership_id
      join public.organization_roles role on role.id=assignment.role_id
      where membership.organization_id=(select organization_id from pg_temp.c009_fixture)
        and assignment.status='active' and role.code='head_admin')<>1
  then raise exception 'authority transfer did not leave exactly one active head role'; end if;
  begin perform public.respond_stable_authority_transfer(
    (select transfer_token from pg_temp.c009_fixture),'accept',gen_random_uuid()
  ); raise exception 'terminal organization transfer replay succeeded';
  exception when insufficient_privilege then null; end;
end $$;

select set_config('request.jwt.claim.sub',(select auth_authority::text from pg_temp.c009_fixture),true);
do $$ begin
  begin perform public.initiate_organization_authority_transfer_by_email(
    (select organization_id from pg_temp.c009_fixture),'c009-worker@example.invalid',gen_random_uuid()
  ); raise exception 'old Organization Authority retained transfer authority';
  exception when insufficient_privilege then null; end;
end $$;

reset role;
do $$ begin
  if (select count(*) from public.audit_events where scope_kind='organization'
      and scope_id=(select organization_id from pg_temp.c009_fixture)
      and event_type in('organization.created','invitation.organization_accepted',
        'organization.membership_status_changed','organization.head_transfer_accepted'))<4
  then raise exception 'PII-minimized organization security history is incomplete'; end if;
end $$;

select extensions.pass('C-009 Reimer Dressage stable account, membership, role, bilateral horse link, residency and authority transfer vertical is secure');
select * from extensions.finish();

rollback;
