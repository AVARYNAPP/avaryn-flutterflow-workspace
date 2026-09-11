begin;
set local statement_timeout='15s';
select extensions.plan(1);

-- Self-contained synthetic fixtures; no email lookup API or existing account.
create temporary table label_actor(code text primary key,auth_id uuid,profile_id uuid);
create temporary table label_fixture(org uuid,viewer_membership uuid,viewer_role uuid);
create temporary table label_invitation(code text primary key,id uuid,token text);
grant select,insert,update on pg_temp.label_actor,pg_temp.label_fixture,pg_temp.label_invitation to authenticated,service_role;
insert into label_actor(code,auth_id) values
 ('owner','c0101abe-0000-4000-8000-000000000001'),
 ('viewer','c0101abe-0000-4000-8000-000000000002'),
 ('alpha','c0101abe-0000-4000-8000-000000000003'),
 ('beta','c0101abe-0000-4000-8000-000000000004'),
 ('outside','c0101abe-0000-4000-8000-000000000005');
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
 raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000'::uuid,auth_id,'authenticated','authenticated',
 'c010-label-'||code||'@example.invalid','',now(),'{}','{}',now(),now() from label_actor;
update label_actor a set profile_id=p.id from public.profiles p where p.auth_user_id=a.auth_id;
update public.profiles p set display_name='Label '||a.code from label_actor a where p.id=a.profile_id;
insert into label_fixture default values;

create function pg_temp.label_workspace() returns jsonb language sql as $$
 select public.get_c010_stable_workspace((select org from pg_temp.label_fixture),
 now()-interval '1 day',now()+interval '1 day',current_date,'all');
$$;
grant execute on function pg_temp.label_workspace() to authenticated;

select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',(select auth_id::text from label_actor where code='owner'),true);
set local role authenticated;
do $$ declare created jsonb; membership record; role_row record; begin
 created:=public.create_c010_stable('Recipient label rollback fixture',null,gen_random_uuid());
 update label_fixture set org=(created->>'organization_id')::uuid;
 select * into membership from public.create_organization_membership((select org from label_fixture),
  (select profile_id from label_actor where code='viewer'),now(),gen_random_uuid());
 select * into role_row from public.create_organization_role((select org from label_fixture),'label_reader',
  'Read-only team','Synthetic existing permission boundary',array['organization.view','organization.memberships.view'],gen_random_uuid());
 perform public.grant_organization_membership_role(membership.membership_id,role_row.role_id,now(),gen_random_uuid());
 update label_fixture set viewer_membership=membership.membership_id,viewer_role=role_row.role_id;
end; $$;
insert into label_invitation select 'alpha',invitation_id,invitation_token from public.create_c010_stable_invitation(
 (select org from label_fixture),'groom','c010-label-alpha@example.invalid',now()+interval '7 days',gen_random_uuid());
insert into label_invitation select 'beta',invitation_id,invitation_token from public.create_c010_stable_invitation(
 (select org from label_fixture),'groom','c010-label-beta@example.invalid',now()+interval '7 days',gen_random_uuid());
insert into label_invitation select 'unlinked',invitation_id,invitation_token from public.create_c010_stable_invitation(
 (select org from label_fixture),'groom','c010-label-not-yet-registered@example.invalid',now()+interval '7 days',gen_random_uuid());

do $$ declare workspace jsonb; invitation jsonb; keys text[]; begin
 workspace:=pg_temp.label_workspace();
 if workspace#>>'{capabilities,organization.invitations.manage}'<>'true' then raise exception 'manager fixture lacks existing invitation permission'; end if;
 if (select item->>'recipient_label' from jsonb_array_elements(workspace->'invitations') item
    where item->>'id'=(select id::text from label_invitation where code='alpha')) is distinct from 'Label alpha'
 or (select item->>'recipient_label' from jsonb_array_elements(workspace->'invitations') item
    where item->>'id'=(select id::text from label_invitation where code='beta')) is distinct from 'Label beta' then
   raise exception 'two equal-role invitations lack distinct linked recipient labels'; end if;
 if (select item->>'recipient_label' from jsonb_array_elements(workspace->'invitations') item
    where item->>'id'=(select id::text from label_invitation where code='unlinked')) is not null then
   raise exception 'unlinked recipient identity was invented'; end if;
 for invitation in select * from jsonb_array_elements(workspace->'invitations') loop
  select array_agg(key order by key) into keys from jsonb_object_keys(invitation) key;
  if keys<>array['created_at','expires_at','id','recipient_label','role_code','role_name','row_version','status'] then
   raise exception 'invitation projection changed unrelated fields or exposed identifiers'; end if;
 end loop;
end; $$;

-- Existing team read permission alone must not reveal the new labels.
select set_config('request.jwt.claim.sub',(select auth_id::text from label_actor where code='viewer'),true);
do $$ declare workspace jsonb; begin
 workspace:=pg_temp.label_workspace();
 if jsonb_array_length(workspace->'invitations')<>3 then raise exception 'existing viewer invitation visibility changed'; end if;
 if workspace#>>'{capabilities,organization.invitations.manage}'<>'false' then raise exception 'viewer fixture accidentally manages invitations'; end if;
 if exists(select 1 from jsonb_array_elements(workspace->'invitations') item where item->>'recipient_label' is not null) then
  raise exception 'team reader without invitation management learned recipient labels'; end if;
end; $$;

-- A cross-organization administrator has no lookup into this organization.
select set_config('request.jwt.claim.sub',(select auth_id::text from label_actor where code='outside'),true);
do $$ begin
 perform public.create_c010_stable('Other recipient label organization',null,gen_random_uuid());
 begin perform pg_temp.label_workspace();raise exception 'cross-organization manager read invitation labels';
 exception when insufficient_privilege then null;end;
end; $$;

-- Accepted history resolves only its existing accepted/target profile link.
select set_config('request.jwt.claim.sub',(select auth_id::text from label_actor where code='alpha'),true);
do $$ begin
 perform public.respond_stable_invitation((select token from label_invitation where code='alpha'),'accept',gen_random_uuid());
end; $$;
select set_config('request.jwt.claim.sub',(select auth_id::text from label_actor where code='owner'),true);
do $$ declare invitation jsonb;begin
 select item into invitation from jsonb_array_elements(pg_temp.label_workspace()->'invitations') item
  where item->>'id'=(select id::text from label_invitation where code='alpha');
 if invitation->>'status'<>'accepted' or invitation->>'recipient_label' is distinct from 'Label alpha' then
  raise exception 'accepted invitation lost linked recipient label'; end if;
end; $$;

-- A real canonical deletion preparation revokes beta's pending invitation and
-- clears profile presentation. The projection must not recover its old name.
reset role;
select set_config('request.jwt.claim.sub','',true);
select set_config('request.jwt.claim.role','service_role',true);
set local role service_role;
do $$ declare result jsonb;begin
 result:=public.prepare_c010_account_deletion((select auth_id from label_actor where code='beta'),gen_random_uuid());
 if result->>'status'<>'auth_removal_pending' then raise exception 'inactive recipient fixture preparation failed';end if;
end; $$;
reset role;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',(select auth_id::text from label_actor where code='owner'),true);
set local role authenticated;
do $$ declare invitation jsonb;begin
 select item into invitation from jsonb_array_elements(pg_temp.label_workspace()->'invitations') item
  where item->>'id'=(select id::text from label_invitation where code='beta');
 if invitation->>'status'<>'revoked' or invitation->>'recipient_label' is distinct from 'Niet-actief account' then
  raise exception 'inactive recipient label leaked or became misleading';end if;
 perform public.revoke_c010_membership((select org from label_fixture),(select viewer_membership from label_fixture),
  (select row_version from public.organization_memberships where id=(select viewer_membership from label_fixture)),gen_random_uuid());
end; $$;
select set_config('request.jwt.claim.sub',(select auth_id::text from label_actor where code='viewer'),true);
do $$ begin
 begin perform pg_temp.label_workspace();raise exception 'revoked membership retained invitation lookup';
 exception when insufficient_privilege then null;end;
end; $$;
reset role;

-- Public RPC permissions are unchanged; neither anonymous nor service clients
-- gain a new profile lookup. The owning DB role is used only for fixture setup.
do $$ begin
 if has_function_privilege('anon','public.get_c010_stable_workspace(uuid,timestamptz,timestamptz,date,text)','EXECUTE')
  or has_function_privilege('service_role','public.get_c010_stable_workspace(uuid,timestamptz,timestamptz,date,text)','EXECUTE')
  or not has_function_privilege('authenticated','public.get_c010_stable_workspace(uuid,timestamptz,timestamptz,date,text)','EXECUTE') then
  raise exception 'workspace function grants changed';end if;
end; $$;
select extensions.pass('C010 invitation recipient labels: managed linked names, reader privacy, accepted/inactive/unlinked, cross-org and revoke');
select * from extensions.finish();
rollback;
