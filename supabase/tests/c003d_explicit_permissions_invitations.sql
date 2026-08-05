begin;

select extensions.plan(1);

create temporary table c003d_fixture(
  auth_owner uuid not null,auth_target uuid not null,auth_other uuid not null,auth_unverified uuid not null,
  profile_owner uuid,profile_target uuid,profile_other uuid,profile_unverified uuid,
  horse_id uuid,organization_id uuid,role_id uuid,membership_id uuid,
  relationship_id uuid,link_id uuid,direct_grant_id uuid,bound_grant_id uuid,role_grant_id uuid,
  organization_invitation_id uuid,organization_token text,
  horse_invitation_id uuid,horse_token text,rider_grant_id uuid
);
grant select,update on pg_temp.c003d_fixture to authenticated,anon,service_role;

insert into pg_temp.c003d_fixture(auth_owner,auth_target,auth_other,auth_unverified) values(
  'c003d000-0000-4000-8000-000000000001','c003d000-0000-4000-8000-000000000002',
  'c003d000-0000-4000-8000-000000000003','c003d000-0000-4000-8000-000000000004'
);
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000'::uuid,auth_owner,'authenticated','authenticated',
  'c003d-owner@example.invalid','',now(),'{}'::jsonb,'{"role":"platform_admin","stable_id":"spoof"}'::jsonb,now(),now()
from pg_temp.c003d_fixture
union all select '00000000-0000-0000-0000-000000000000'::uuid,auth_target,'authenticated','authenticated',
  'C003D-TARGET@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c003d_fixture
union all select '00000000-0000-0000-0000-000000000000'::uuid,auth_other,'authenticated','authenticated',
  'c003d-other@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c003d_fixture
union all select '00000000-0000-0000-0000-000000000000'::uuid,auth_unverified,'authenticated','authenticated',
  'c003d-unverified@example.invalid','',null,'{}'::jsonb,'{}'::jsonb,now(),now() from pg_temp.c003d_fixture;

update pg_temp.c003d_fixture fixture set
  profile_owner=(select id from public.profiles where auth_user_id=fixture.auth_owner),
  profile_target=(select id from public.profiles where auth_user_id=fixture.auth_target),
  profile_other=(select id from public.profiles where auth_user_id=fixture.auth_other),
  profile_unverified=(select id from public.profiles where auth_user_id=fixture.auth_unverified);

do $$
begin
  if (select count(*) from public.permission_definitions where scope_kind='organization')<>7
    or (select count(*) from public.permission_definitions where scope_kind='horse')<>6
    or (select is_grantable from public.permission_definitions where code='horse.transfer')
    or exists(select 1 from public.permission_definitions where code like 'horse.%' and scope_kind<>'horse')
  then raise exception 'C-003D permission catalog invalid';end if;
  if to_regclass('public.horse_profile_permission_grants') is null
    or to_regclass('public.horse_organization_role_permission_grants') is null
    or to_regclass('public.organization_invitations') is null
    or to_regclass('public.horse_access_invitations') is null
    or to_regclass('public.rider_performance_profile_share_grants') is null
  then raise exception 'C-003D data model incomplete';end if;
end $$;

-- Client roles have no direct write, truncate, invitation-table read or RPC
-- authority outside the authenticated allowlist.
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','anon',true);
set local role anon;
do $$ begin
  begin perform public.create_organization_invitation(gen_random_uuid(),gen_random_uuid(),'x@example.invalid',now()+interval '1 day',gen_random_uuid());
    raise exception 'anon created invitation';exception when insufficient_privilege then null;end;
  begin perform count(*) from public.organization_invitations;raise exception 'anon read invitations';
    exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.role','service_role',true);
set local role service_role;
do $$ begin
  begin truncate public.horse_profile_permission_grants;raise exception 'service role truncated grants';
    exception when insufficient_privilege then null;end;
  begin perform public.create_horse_access_invitation(gen_random_uuid(),'x@example.invalid',array['horse.view'],null,null,now()+interval '1 day',gen_random_uuid());
    raise exception 'service role created invitation';exception when insufficient_privilege then null;end;
end $$;
reset role;

-- Primary authority creates the bounded resources. Head admin receives only
-- organization-scoped permissions after the catalog extension.
select set_config('request.jwt.claim.sub',(select auth_owner::text from pg_temp.c003d_fixture),true);
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
with created as(select * from public.create_canonical_horse('C003D Horse',null,'unknown',null,
  'c003d100-0000-4000-8000-000000000001','{}'))
update pg_temp.c003d_fixture fixture set horse_id=created.horse_id from created;
with created as(select * from public.create_organization('stable','C003D Stable',null,
  'c003d100-0000-4000-8000-000000000002','{}'))
update pg_temp.c003d_fixture fixture set organization_id=created.organization_id from created;
with created as(select * from public.create_organization_role(
  (select organization_id from pg_temp.c003d_fixture),'rider_team','Rider team',null,
  array['organization.view'],'c003d100-0000-4000-8000-000000000003'))
update pg_temp.c003d_fixture fixture set role_id=created.role_id from created;
do $$ begin
  if (select count(*) from public.organization_role_permissions role_permission
      join public.organization_roles role on role.id=role_permission.role_id
      join public.permission_definitions permission on permission.id=role_permission.permission_id
      where role.organization_id=(select organization_id from pg_temp.c003d_fixture)
        and role.code='head_admin' and permission.scope_kind='organization')<>7
    or exists(select 1 from public.organization_role_permissions role_permission
      join public.organization_roles role on role.id=role_permission.role_id
      join public.permission_definitions permission on permission.id=role_permission.permission_id
      where role.organization_id=(select organization_id from pg_temp.c003d_fixture)
        and role.code='head_admin' and permission.scope_kind<>'organization')
  then raise exception 'C-003B organization role scope regressed';end if;
  begin insert into public.organization_role_permissions(
    organization_id,role_id,permission_id,granted_by_profile_id,correlation_id
  ) select (select organization_id from pg_temp.c003d_fixture),(select role_id from pg_temp.c003d_fixture),
      id,(select profile_owner from pg_temp.c003d_fixture),gen_random_uuid()
    from public.permission_definitions where code='horse.view';
    raise exception 'horse permission entered organization role';exception when insufficient_privilege then null;end;
end $$;

-- Direct explicit grant, RLS and denied escalation audit.
with granted as(select * from public.grant_horse_profile_permission(
  (select horse_id from pg_temp.c003d_fixture),(select profile_target from pg_temp.c003d_fixture),
  'horse.view',null,null,null,'MANUAL_GRANT','c003d110-0000-4000-8000-000000000001'))
update pg_temp.c003d_fixture fixture set direct_grant_id=granted.grant_id from granted;
do $$ declare replay record;
begin
  select * into replay from public.grant_horse_profile_permission(
    (select horse_id from pg_temp.c003d_fixture),(select profile_target from pg_temp.c003d_fixture),
    'horse.view',null,null,null,'MANUAL_GRANT','c003d110-0000-4000-8000-000000000001');
  if replay.applied or replay.grant_id<>(select direct_grant_id from pg_temp.c003d_fixture)
  then raise exception 'direct grant idempotent replay failed';end if;
end $$;
select set_config('request.jwt.claim.sub',(select auth_target::text from pg_temp.c003d_fixture),true);
do $$ declare result record;
begin
  if not public.has_canonical_horse_permission((select horse_id from pg_temp.c003d_fixture),'horse.view')
    or (select count(*) from public.horse_profile_permission_grants)<>1
  then raise exception 'direct grant or self RLS failed';end if;
  select * into result from public.grant_horse_profile_permission(
    (select horse_id from pg_temp.c003d_fixture),(select profile_other from pg_temp.c003d_fixture),
    'horse.view',null,null,null,'MANUAL_GRANT','c003d110-0000-4000-8000-000000000002');
  if result.applied then raise exception 'non-manager escalated horse permission';end if;
  begin update public.horse_profile_permission_grants set status='revoked';
    raise exception 'direct grant DML succeeded';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub',(select auth_owner::text from pg_temp.c003d_fixture),true);
reset role;
do $$ begin
  if not exists(select 1 from public.audit_events where event_type='permission.denied_escalation'
    and correlation_id='c003d110-0000-4000-8000-000000000002')
  then raise exception 'denied escalation audit was rolled back';end if;
end $$;
set local role authenticated;

-- Organization invitation is normalized/HMAC-bound and creates exactly the
-- invited membership and non-reserved role. Wrong and unverified actors fail.
with invitation as(select * from public.create_organization_invitation(
  (select organization_id from pg_temp.c003d_fixture),(select role_id from pg_temp.c003d_fixture),
  ' c003d-target@example.invalid ',now()+interval '2 days','c003d120-0000-4000-8000-000000000001'))
update pg_temp.c003d_fixture fixture set organization_invitation_id=invitation.invitation_id,
  organization_token=invitation.invitation_token from invitation;
select set_config('request.jwt.claim.sub',(select auth_other::text from pg_temp.c003d_fixture),true);
do $$ begin
  if (select count(*) from public.preview_organization_invitation((select organization_token from pg_temp.c003d_fixture)))<>0
  then raise exception 'wrong e-mail previewed invitation';end if;
end $$;
select set_config('request.jwt.claim.sub',(select auth_unverified::text from pg_temp.c003d_fixture),true);
do $$ begin
  begin perform public.preview_organization_invitation((select organization_token from pg_temp.c003d_fixture));
    raise exception 'unverified e-mail previewed invitation';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub',(select auth_target::text from pg_temp.c003d_fixture),true);
do $$ begin
  if (select count(*) from public.preview_organization_invitation((select organization_token from pg_temp.c003d_fixture)))<>1
  then raise exception 'verified normalized e-mail could not preview';end if;
end $$;
with response as(select * from public.respond_organization_invitation(
  (select organization_token from pg_temp.c003d_fixture),'accept','c003d120-0000-4000-8000-000000000002'))
update pg_temp.c003d_fixture fixture set membership_id=response.membership_id from response;
do $$ begin
  if not public.has_organization_permission((select organization_id from pg_temp.c003d_fixture),'organization.view')
  then raise exception 'organization invitation acceptance failed';end if;
  begin perform status from public.organization_invitations where id=(select organization_invitation_id from pg_temp.c003d_fixture);
    raise exception 'accepted invitation table became readable';exception when insufficient_privilege then null;end;
  begin perform public.respond_organization_invitation((select organization_token from pg_temp.c003d_fixture),'accept',gen_random_uuid());
    raise exception 'consumed organization token replayed';exception when insufficient_privilege then null;end;
end $$;

-- Organization-role horse grants require explicit authority and do not flow
-- from membership alone.
select set_config('request.jwt.claim.sub',(select auth_owner::text from pg_temp.c003d_fixture),true);
with granted as(select * from public.grant_horse_organization_role_permission(
  (select horse_id from pg_temp.c003d_fixture),(select role_id from pg_temp.c003d_fixture),
  'horse.edit',null,null,null,'MANUAL_GRANT','c003d130-0000-4000-8000-000000000001'))
update pg_temp.c003d_fixture fixture set role_grant_id=granted.grant_id from granted;
select set_config('request.jwt.claim.sub',(select auth_target::text from pg_temp.c003d_fixture),true);
do $$ begin
  if not public.has_canonical_horse_permission((select horse_id from pg_temp.c003d_fixture),'horse.edit')
  then raise exception 'active organization role grant failed';end if;
end $$;

-- Relationship-bound direct grants and link-bound role grants are revoked
-- automatically; the semantic relationship/link never grants access itself.
select set_config('request.jwt.claim.sub',(select auth_owner::text from pg_temp.c003d_fixture),true);
with relationship as(select public.start_horse_person_relationship(
  (select horse_id from pg_temp.c003d_fixture),(select profile_other from pg_temp.c003d_fixture),
  'trainer',statement_timestamp(),'c003d140-0000-4000-8000-000000000001') id)
update pg_temp.c003d_fixture fixture set relationship_id=relationship.id from relationship;
select set_config('request.jwt.claim.sub',(select auth_other::text from pg_temp.c003d_fixture),true);
do $$ begin
  if public.has_canonical_horse_permission((select horse_id from pg_temp.c003d_fixture),'horse.view')
  then raise exception 'relationship implicitly granted access';end if;
end $$;
select set_config('request.jwt.claim.sub',(select auth_owner::text from pg_temp.c003d_fixture),true);
with granted as(select * from public.grant_horse_profile_permission(
  (select horse_id from pg_temp.c003d_fixture),(select profile_other from pg_temp.c003d_fixture),
  'horse.view',(select relationship_id from pg_temp.c003d_fixture),null,null,'RELATIONSHIP_BOUND',
  'c003d140-0000-4000-8000-000000000002'))
update pg_temp.c003d_fixture fixture set bound_grant_id=granted.grant_id from granted;
select public.end_horse_person_relationship((select relationship_id from pg_temp.c003d_fixture),1,
  'c003d140-0000-4000-8000-000000000003');
do $$ begin
  if (select status from public.horse_profile_permission_grants where id=(select bound_grant_id from pg_temp.c003d_fixture))<>'revoked'
  then raise exception 'relationship-bound grant was not revoked';end if;
end $$;
with proposed as(select * from public.propose_organization_horse_link(
  (select horse_id from pg_temp.c003d_fixture),(select organization_id from pg_temp.c003d_fixture),
  'training_provider','horse','c003d141-0000-4000-8000-000000000001'))
update pg_temp.c003d_fixture fixture set link_id=proposed.link_id from proposed;
select * from public.respond_organization_horse_link((select link_id from pg_temp.c003d_fixture),1,'accept',
  'c003d141-0000-4000-8000-000000000002');
with granted as(select * from public.grant_horse_organization_role_permission(
  (select horse_id from pg_temp.c003d_fixture),(select role_id from pg_temp.c003d_fixture),
  'horse.view',(select link_id from pg_temp.c003d_fixture),null,null,'LINK_BOUND',
  'c003d141-0000-4000-8000-000000000003'))
update pg_temp.c003d_fixture fixture set role_grant_id=granted.grant_id from granted;
select * from public.respond_organization_horse_link((select link_id from pg_temp.c003d_fixture),2,'end',
  'c003d141-0000-4000-8000-000000000004');
do $$ begin
  if (select status from public.horse_organization_role_permission_grants where id=(select role_grant_id from pg_temp.c003d_fixture))<>'revoked'
  then raise exception 'link-bound role grant was not revoked';end if;
end $$;

-- Horse invitation creates only its listed explicit grant and is token/e-mail
-- bound. Rider Performance shares are a separate, explicit security layer.
with invitation as(select * from public.create_horse_access_invitation(
  (select horse_id from pg_temp.c003d_fixture),'c003d-other@example.invalid',array['horse.assign'],
  null,null,now()+interval '2 days','c003d150-0000-4000-8000-000000000001'))
update pg_temp.c003d_fixture fixture set horse_invitation_id=invitation.invitation_id,
  horse_token=invitation.invitation_token from invitation;
select set_config('request.jwt.claim.sub',(select auth_target::text from pg_temp.c003d_fixture),true);
do $$ begin
  begin perform public.respond_horse_access_invitation((select horse_token from pg_temp.c003d_fixture),'accept',gen_random_uuid());
    raise exception 'wrong e-mail accepted horse invitation';exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claim.sub',(select auth_other::text from pg_temp.c003d_fixture),true);
select * from public.respond_horse_access_invitation((select horse_token from pg_temp.c003d_fixture),'accept',
  'c003d150-0000-4000-8000-000000000002');
do $$ begin
  if not public.has_canonical_horse_permission((select horse_id from pg_temp.c003d_fixture),'horse.assign')
    or public.has_canonical_horse_permission((select horse_id from pg_temp.c003d_fixture),'horse.edit')
  then raise exception 'horse invitation over/under-granted';end if;
end $$;
select set_config('request.jwt.claim.sub',(select auth_owner::text from pg_temp.c003d_fixture),true);
with granted as(select * from public.grant_rider_performance_profile_share(
  (select profile_target from pg_temp.c003d_fixture),'training_summary',null,null,null,
  'c003d160-0000-4000-8000-000000000001'))
update pg_temp.c003d_fixture fixture set rider_grant_id=granted.grant_id from granted;
select set_config('request.jwt.claim.sub',(select auth_target::text from pg_temp.c003d_fixture),true);
do $$ begin
  if not public.has_rider_performance_share((select profile_owner from pg_temp.c003d_fixture),'training_summary',null)
  then raise exception 'Rider Performance profile share failed';end if;
end $$;
select set_config('request.jwt.claim.sub',(select auth_owner::text from pg_temp.c003d_fixture),true);
select * from public.transition_rider_performance_profile_share((select rider_grant_id from pg_temp.c003d_fixture),1,'revoke',
  'c003d160-0000-4000-8000-000000000002');

-- Explicit expiry, optimistic versioning and inviter revocation are all
-- fail-closed; an expired active row never evaluates as access.
do $$ declare expired_grant record;transitioned record;created_invitation record;revoked_invitation record;
begin
  select * into expired_grant from public.grant_horse_profile_permission(
    (select horse_id from pg_temp.c003d_fixture),(select profile_target from pg_temp.c003d_fixture),
    'horse.share',null,statement_timestamp()-interval '2 days',statement_timestamp()-interval '1 day',
    'MANUAL_GRANT','c003d170-0000-4000-8000-000000000001');
  select * into transitioned from public.transition_horse_profile_permission_grant(
    expired_grant.grant_id,1,'expire','WINDOW_EXPIRED','c003d170-0000-4000-8000-000000000002');
  if transitioned.status<>'expired' then raise exception 'expired grant transition failed';end if;
  begin perform public.transition_horse_profile_permission_grant(
    (select direct_grant_id from pg_temp.c003d_fixture),0,'revoke','MANUAL_REVOKE',gen_random_uuid());
    raise exception 'stale grant version succeeded';exception when serialization_failure then null;end;
  select * into transitioned from public.transition_horse_profile_permission_grant(
    (select direct_grant_id from pg_temp.c003d_fixture),1,'revoke','MANUAL_REVOKE',
    'c003d170-0000-4000-8000-000000000003');
  if transitioned.status<>'revoked' then raise exception 'direct revoke failed';end if;
  select * into created_invitation from public.create_organization_invitation(
    (select organization_id from pg_temp.c003d_fixture),(select role_id from pg_temp.c003d_fixture),
    'c003d-other@example.invalid',now()+interval '1 day','c003d170-0000-4000-8000-000000000004');
  select * into revoked_invitation from public.revoke_organization_invitation(
    created_invitation.invitation_id,1,'c003d170-0000-4000-8000-000000000005');
  if revoked_invitation.status<>'revoked' then raise exception 'organization invitation revoke failed';end if;
end $$;
select set_config('request.jwt.claim.sub',(select auth_target::text from pg_temp.c003d_fixture),true);
do $$ begin
  if public.has_canonical_horse_permission((select horse_id from pg_temp.c003d_fixture),'horse.share')
    or public.has_canonical_horse_permission((select horse_id from pg_temp.c003d_fixture),'horse.view')
  then raise exception 'expired/revoked horse access remained effective';end if;
end $$;

-- Secret material stays server-only and private routines have no client ACL.
reset role;
do $$
declare routine record;
begin
  if exists(select 1 from public.organization_invitations invitation
      where pg_catalog.encode(invitation.target_email_hmac,'hex') ilike '%example.invalid%')
    or exists(select 1 from public.audit_events event
      where event.event_type like 'invitation.%' and event.metadata::text ilike '%example.invalid%')
    or exists(select 1 from public.audit_events event
      where event.event_type like 'invitation.%' and event.metadata::text ilike '%c003d150%')
  then raise exception 'invitation PII/token leaked';end if;
  if has_table_privilege('authenticated','private.c003d_secrets','select')
    or has_table_privilege('service_role','private.c003d_secrets','select')
  then raise exception 'C-003D secret table exposed';end if;
  for routine in
    select procedure.oid from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='private' and procedure.proname like 'c003d_%'
  loop
    if has_function_privilege('authenticated',routine.oid,'execute')
      or has_function_privilege('anon',routine.oid,'execute')
      or has_function_privilege('service_role',routine.oid,'execute')
    then raise exception 'private C-003D routine executable by client';end if;
  end loop;
  if exists(
    select 1 from pg_catalog.pg_proc procedure
    join pg_catalog.pg_namespace namespace on namespace.oid=procedure.pronamespace
    where namespace.nspname='public' and procedure.proname in(
      'grant_horse_profile_permission','respond_organization_invitation','respond_horse_access_invitation'
    ) and (not procedure.prosecdef or not coalesce(procedure.proconfig@>array['search_path=""'],false))
  ) then raise exception 'security-definer routine hardening invalid';end if;
end $$;

select extensions.pass('C-003D explicit permissions and invitations security regression suite passed');
select * from extensions.finish();
rollback;
