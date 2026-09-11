begin;

select extensions.plan(1);

create temporary table c010_round1_fixture(
  auth_manager_a uuid not null,
  auth_manager_b uuid not null,
  auth_owner uuid not null,
  auth_groom uuid not null,
  auth_outsider uuid not null,
  manager_a uuid,
  manager_b uuid,
  owner_profile uuid,
  groom_profile uuid,
  outsider_profile uuid,
  stable_a uuid,
  stable_b uuid,
  groom_membership uuid,
  horse_a uuid,
  horse_b uuid,
  place_3 uuid,
  task_id uuid,
  open_task_id uuid
);
grant select,update on pg_temp.c010_round1_fixture to authenticated,anon,service_role;

insert into pg_temp.c010_round1_fixture(
  auth_manager_a,auth_manager_b,auth_owner,auth_groom,auth_outsider
) values(
  'c0110000-0000-4000-8000-000000000001',
  'c0110000-0000-4000-8000-000000000002',
  'c0110000-0000-4000-8000-000000000003',
  'c0110000-0000-4000-8000-000000000004',
  'c0110000-0000-4000-8000-000000000005'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
)
select '00000000-0000-0000-0000-000000000000'::uuid,auth_manager_a,
  'authenticated','authenticated','round1-manager-a@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_manager_b,
  'authenticated','authenticated','round1-manager-b@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_owner,
  'authenticated','authenticated','round1-owner@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_groom,
  'authenticated','authenticated','round1-groom@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture union all
select '00000000-0000-0000-0000-000000000000'::uuid,auth_outsider,
  'authenticated','authenticated','round1-outsider@example.invalid','',now(),'{}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c010_round1_fixture;

update public.profiles profile set display_name=case profile.auth_user_id
  when 'c0110000-0000-4000-8000-000000000001' then 'Manager Alpha'
  when 'c0110000-0000-4000-8000-000000000002' then 'Manager Beta'
  when 'c0110000-0000-4000-8000-000000000003' then 'Horse Authority'
  when 'c0110000-0000-4000-8000-000000000004' then 'Groom Alpha'
  else 'Buitenstaander' end
where profile.auth_user_id::text like 'c0110000-%';

update pg_temp.c010_round1_fixture fixture set
  manager_a=(select id from public.profiles where auth_user_id=fixture.auth_manager_a),
  manager_b=(select id from public.profiles where auth_user_id=fixture.auth_manager_b),
  owner_profile=(select id from public.profiles where auth_user_id=fixture.auth_owner),
  groom_profile=(select id from public.profiles where auth_user_id=fixture.auth_groom),
  outsider_profile=(select id from public.profiles where auth_user_id=fixture.auth_outsider);

select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_round1_fixture),true);
with created as(
  select public.create_c010_stable('SDS Stables','Amsterdam','c0111000-0000-4000-8000-000000000001') result
) update pg_temp.c010_round1_fixture fixture
set stable_a=(created.result->>'organization_id')::uuid from created;

select set_config('request.jwt.claim.sub',(select auth_manager_b::text from pg_temp.c010_round1_fixture),true);
with created as(
  select public.create_c010_stable('Test Stable','Utrecht','c0111000-0000-4000-8000-000000000002') result
) update pg_temp.c010_round1_fixture fixture
set stable_b=(created.result->>'organization_id')::uuid from created;

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_round1_fixture),true);
do $$ declare invitation record; begin
  select * into invitation from public.create_c010_stable_invitation(
    (select stable_a from pg_temp.c010_round1_fixture),'groom','round1-groom@example.invalid',
    statement_timestamp()+interval '7 days','c0111100-0000-4000-8000-000000000001'
  );
  perform pg_catalog.set_config('c010.round1.groom_token',invitation.invitation_token,true);
end $$;

select set_config('request.jwt.claim.sub',(select auth_groom::text from pg_temp.c010_round1_fixture),true);
with accepted as(
  select * from public.respond_stable_invitation(
    current_setting('c010.round1.groom_token'),'accept','c0111100-0000-4000-8000-000000000002'
  )
) update pg_temp.c010_round1_fixture fixture set groom_membership=accepted.membership_id from accepted;

select set_config('request.jwt.claim.sub',(select auth_owner::text from pg_temp.c010_round1_fixture),true);
with horse as(
  select * from public.create_canonical_horse_profile(
    'Orion Round 1',null,null,'unknown',null,'Dressuur',null,null,null,null,null,null,
    'c0111200-0000-4000-8000-000000000001'
  )
) update pg_temp.c010_round1_fixture fixture set horse_a=horse.horse_id from horse;
with horse as(
  select * from public.create_canonical_horse_profile(
    'Nova Round 1',null,null,'unknown',null,'Dressuur',null,null,null,null,null,null,
    'c0111200-0000-4000-8000-000000000002'
  )
) update pg_temp.c010_round1_fixture fixture set horse_b=horse.horse_id from horse;
select public.set_c010_horse_residency(
  (select horse_a from pg_temp.c010_round1_fixture),(select stable_a from pg_temp.c010_round1_fixture),
  null,'c0111200-0000-4000-8000-000000000003'
);
select public.set_c010_horse_residency(
  (select horse_b from pg_temp.c010_round1_fixture),(select stable_b from pg_temp.c010_round1_fixture),
  null,'c0111200-0000-4000-8000-000000000004'
);
select public.set_c010_horse_collaborator(
  (select horse_a from pg_temp.c010_round1_fixture),(select manager_a from pg_temp.c010_round1_fixture),
  'trainer',array['horse.view'],true,'c0111200-0000-4000-8000-000000000005'
);
select public.set_c010_horse_collaborator(
  (select horse_a from pg_temp.c010_round1_fixture),(select groom_profile from pg_temp.c010_round1_fixture),
  'groom',array['horse.view'],true,'c0111200-0000-4000-8000-000000000006'
);

select set_config('request.jwt.claim.sub',(select auth_manager_a::text from pg_temp.c010_round1_fixture),true);
select public.update_c010_stable(
  (select stable_a from pg_temp.c010_round1_fixture),
  (select row_version from public.organizations where id=(select stable_a from pg_temp.c010_round1_fixture)),
  'SDS Stables','Amsterdam',
  'Stalstraat 10','Amsterdam','c0111300-0000-4000-8000-000000000001'
);
select public.update_c010_stable_facilities(
  (select stable_a from pg_temp.c010_round1_fixture),null,3,2,1,1,true,1,4,true,8,
  'c0111300-0000-4000-8000-000000000002'
);
update pg_temp.c010_round1_fixture fixture set place_3=(
  select id from public.stable_places where organization_id=fixture.stable_a and ordinal=3
);
select public.upsert_c010_stable_resource(
  (select stable_a from pg_temp.c010_round1_fixture),null,null,'concentrate_feed','Pavo','SportsFit',
  'c0111300-0000-4000-8000-000000000003'
);
select public.upsert_c010_stable_resource(
  (select stable_a from pg_temp.c010_round1_fixture),null,null,'bedding','AVARYN','Zaagsel',
  'c0111300-0000-4000-8000-000000000004'
);

with saved as(
  select public.upsert_c010_stable_task(
    (select stable_a from pg_temp.c010_round1_fixture),null,null,'Orion voeren','Controleer water','feeding',
    current_date,'18:00',(select groom_profile from pg_temp.c010_round1_fixture),'Weide 6',
    (select place_3 from pg_temp.c010_round1_fixture),(select horse_a from pg_temp.c010_round1_fixture),
    'c0111400-0000-4000-8000-000000000001'
  ) result
) update pg_temp.c010_round1_fixture fixture set task_id=(saved.result->>'task_id')::uuid from saved;

do $$ begin
  if (select stable_place_id from public.list_c010_stable_activities(
      (select stable_a from pg_temp.c010_round1_fixture),
      current_date::timestamptz,(current_date+1)::timestamptz,'all'
    ) where activity_id=(select task_id from pg_temp.c010_round1_fixture))
    is distinct from (select place_3 from pg_temp.c010_round1_fixture)
  then raise exception 'stable activity projection lost canonical place identity'; end if;
end $$;


-- Extend the legacy regression fixture with a non-assignee rider. Setup uses
-- admin only to provision test identities; every authorization check below is
-- SET LOCAL ROLE authenticated with a distinct actor claim.
reset role;
create temporary table repair_staff(auth_id uuid,profile_id uuid,membership_id uuid);
insert into repair_staff(auth_id) values('c0190000-0000-4000-8000-000000000001');
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000'::uuid,auth_id,'authenticated','authenticated',
  'repair-rider@example.invalid','',now(),'{}','{}',now(),now() from repair_staff;
update repair_staff set profile_id=(select id from public.profiles where auth_user_id=repair_staff.auth_id);
create temporary table repair_tasks(id uuid primary key,horse_linked boolean,terminal boolean,completion_request_id uuid);
grant select,update,insert on repair_staff,repair_tasks to authenticated;
set local role authenticated;
insert into repair_tasks values((select task_id from c010_round1_fixture),true,false,null);
do $$ declare invitation record; begin
  select * into invitation from public.create_c010_stable_invitation(
    (select stable_a from c010_round1_fixture),'rider','repair-rider@example.invalid',
    statement_timestamp()+interval '7 days',gen_random_uuid());
  perform set_config('request.jwt.claim.sub',(select auth_id::text from repair_staff),true);
  update repair_staff set membership_id=(select membership_id from public.respond_stable_invitation(
    invitation.invitation_token,'accept',gen_random_uuid()));
  perform set_config('request.jwt.claim.sub',(select auth_manager_a::text from c010_round1_fixture),true);
end $$;

do $$ declare linked boolean; history boolean; saved jsonb; completion_request uuid; begin
  foreach linked in array array[false,true] loop
    foreach history in array array[false,true] loop
      if linked and not history then continue; end if;
      saved:=public.upsert_c010_stable_task((select stable_a from c010_round1_fixture),null,null,
        'Repair visibility '||linked||' '||history,'Sensitive task note','other',current_date,null,
        (select groom_profile from c010_round1_fixture),null,null,
        case when linked then (select horse_a from c010_round1_fixture) end,gen_random_uuid());
      completion_request:=gen_random_uuid();
      insert into repair_tasks values((saved->>'task_id')::uuid,linked,history,completion_request);
      if history then
        perform set_config('request.jwt.claim.sub',(select auth_groom::text from c010_round1_fixture),true);
        perform public.transition_c010_stable_task((select stable_a from c010_round1_fixture),
          (saved->>'task_id')::uuid,1,'complete',completion_request);
        perform set_config('request.jwt.claim.sub',(select auth_manager_a::text from c010_round1_fixture),true);
      end if;
    end loop;
  end loop;
end $$;

create function pg_temp.assert_task_visibility(
  p_label text,p_auth uuid,p_member boolean,p_horse boolean,p_assignee boolean
) returns void language plpgsql as $$
declare rows_count bigint; expected_rows bigint; expected_events bigint; linked boolean; history boolean;
begin
  if current_user<>'authenticated' then raise exception 'Authorization test bypassed client role'; end if;
  perform set_config('request.jwt.claim.sub',p_auth::text,true);
  foreach linked in array array[false,true] loop
    foreach history in array array[false,true] loop
      expected_rows:=case when p_member and (not linked or p_horse) then 1 else 0 end;
      expected_events:=expected_rows*(case when history then 2 else 1 end);
      select count(*) into rows_count from public.stable_tasks t join repair_tasks f on f.id=t.id
        where f.horse_linked=linked and f.terminal=history;
      if rows_count<>expected_rows then raise exception '% direct tasks linked=% historical=% got %, expected %',p_label,linked,history,rows_count,expected_rows; end if;
      select count(*) into rows_count from public.stable_task_events e join repair_tasks f on f.id=e.task_id
        where f.horse_linked=linked and f.terminal=history;
      if rows_count<>expected_events then raise exception '% direct events linked=% historical=% got %, expected %',p_label,linked,history,rows_count,expected_events; end if;
      if p_member then
        select count(*) into rows_count from public.list_c010_stable_activities(
          (select stable_a from c010_round1_fixture),
          current_date::timestamp at time zone 'Europe/Amsterdam',
          (current_date+1)::timestamp at time zone 'Europe/Amsterdam','all') a
          join repair_tasks f on f.id=a.activity_id where f.horse_linked=linked and f.terminal=history;
        if rows_count<>expected_rows then raise exception '% activity RPC mismatch',p_label; end if;
      end if;
      select count(*) into rows_count from public.list_c010_personal_today(current_date) a
        join repair_tasks f on f.id=a.task_id where f.horse_linked=linked and f.terminal=history;
      if rows_count<>(case when p_assignee and not history then expected_rows else 0 end)
      then raise exception '% personal Today mismatch',p_label; end if;
    end loop;
  end loop;
  if not p_member then
    begin
      perform public.get_c010_stable_round1_workspace((select stable_a from c010_round1_fixture),current_date,'all');
      raise exception '% denied workspace became readable',p_label;
    exception when insufficient_privilege then null; end;
  end if;
end $$;
select pg_temp.assert_task_visibility('groom assignee with horse',auth_groom,true,true,true) from c010_round1_fixture;
select pg_temp.assert_task_visibility('manager with horse',auth_manager_a,true,true,false) from c010_round1_fixture;
select pg_temp.assert_task_visibility('ordinary rider without horse',auth_id,true,false,false) from repair_staff;
select pg_temp.assert_task_visibility('outsider without horse',auth_outsider,false,false,false) from c010_round1_fixture;
select pg_temp.assert_task_visibility('cross stable manager without horse',auth_manager_b,false,false,false) from c010_round1_fixture;
select pg_temp.assert_task_visibility('horse authority without membership',auth_owner,false,true,false) from c010_round1_fixture;

-- A horse grant alone cannot provide stable-task access to an outsider or
-- another stable. It does make the legitimate ordinary member's task visible.
select set_config('request.jwt.claim.sub',(select auth_owner::text from c010_round1_fixture),true);
select public.grant_horse_profile_permission((select horse_a from c010_round1_fixture),profile_id,
  'horse.view',null,null,null,'MANUAL_GRANT',gen_random_uuid()) from repair_staff;
select public.grant_horse_profile_permission(horse_a,outsider_profile,'horse.view',null,null,null,'MANUAL_GRANT',gen_random_uuid()) from c010_round1_fixture;
select public.grant_horse_profile_permission(horse_a,manager_b,'horse.view',null,null,null,'MANUAL_GRANT',gen_random_uuid()) from c010_round1_fixture;
select pg_temp.assert_task_visibility('ordinary rider with horse',auth_id,true,true,false) from repair_staff;
select pg_temp.assert_task_visibility('outsider with explicit horse',auth_outsider,false,true,false) from c010_round1_fixture;
select pg_temp.assert_task_visibility('cross stable manager with explicit horse',auth_manager_b,false,true,false) from c010_round1_fixture;

-- Revoke just the horse grant. Both open and history disappear in every read
-- path; unlinked tasks remain legitimately readable. Knowing an id is no grant.
select set_config('request.jwt.claim.sub',(select auth_owner::text from c010_round1_fixture),true);
select public.set_c010_horse_collaborator(horse_a,groom_profile,'groom',array[]::text[],false,gen_random_uuid()) from c010_round1_fixture;
select public.set_c010_horse_collaborator(horse_a,manager_a,'trainer',array[]::text[],false,gen_random_uuid()) from c010_round1_fixture;
select pg_temp.assert_task_visibility('groom after horse revocation',auth_groom,true,false,true) from c010_round1_fixture;
select pg_temp.assert_task_visibility('manager after horse revocation',auth_manager_a,true,false,false) from c010_round1_fixture;
select set_config('request.jwt.claim.sub',(select auth_groom::text from c010_round1_fixture),true);
do $$ begin
  begin
    perform public.transition_c010_stable_task((select stable_a from c010_round1_fixture),
      (select task_id from c010_round1_fixture),1,'complete',gen_random_uuid());
    raise exception 'revoked horse grant allowed completion';
  exception when insufficient_privilege then null; end;
  begin
    perform public.transition_c010_stable_task((select stable_a from c010_round1_fixture),
      (select id from repair_tasks where horse_linked and terminal),1,'complete',
      (select completion_request_id from repair_tasks where horse_linked and terminal));
    raise exception 'revoked horse grant leaked idempotency receipt';
  exception when insufficient_privilege then null; end;
end $$;

-- An admin cannot strip the horse link from a now-unreadable task to regain it.
select set_config('request.jwt.claim.sub',(select auth_manager_a::text from c010_round1_fixture),true);
do $$ begin
  begin
    perform public.upsert_c010_stable_task((select stable_a from c010_round1_fixture),
      (select task_id from c010_round1_fixture),1,'Unauthorized relink',null,'other',current_date,null,
      (select groom_profile from c010_round1_fixture),null,null,null,gen_random_uuid());
    raise exception 'revoked horse grant allowed blind task relink';
  exception when insufficient_privilege then null; end;
end $$;

-- Independent horse rights may remain after membership ends; task rights do not.
select set_config('request.jwt.claim.sub',(select auth_manager_a::text from c010_round1_fixture),true);
select public.revoke_c010_membership((select stable_a from c010_round1_fixture),membership_id,1,gen_random_uuid()) from repair_staff;
select pg_temp.assert_task_visibility('rider after membership revocation retaining horse',auth_id,false,true,false) from repair_staff;
select set_config('request.jwt.claim.sub',(select auth_manager_a::text from c010_round1_fixture),true);
select public.revoke_c010_membership(stable_a,groom_membership,1,gen_random_uuid()) from c010_round1_fixture;
select pg_temp.assert_task_visibility('assignee after membership revocation',auth_groom,false,false,true) from c010_round1_fixture;

-- Business CAS conflicts must not use PostgreSQL serialization_failure (40001):
-- PostgREST retries that SQLSTATE. Assert exact non-retryable HTTP conflict while
-- authenticated, and preserve versions/events through repeated stale attempts.
select set_config('request.jwt.claim.sub',(select auth_manager_a::text from c010_round1_fixture),true);
do $$
declare saved jsonb; task_uuid uuid; stale_request uuid:=gen_random_uuid();
  completion_request uuid:=gen_random_uuid(); attempt integer; row_data public.stable_tasks%rowtype;
begin
  if current_user<>'authenticated' then raise exception 'CAS test bypassed client role'; end if;
  saved:=public.upsert_c010_stable_task((select stable_a from c010_round1_fixture),null,null,
    'CAS HTTP regression','v1','other',current_date,null,(select manager_a from c010_round1_fixture),
    null,null,null,gen_random_uuid());
  task_uuid:=(saved->>'task_id')::uuid;
  saved:=public.upsert_c010_stable_task((select stable_a from c010_round1_fixture),task_uuid,1,
    'CAS HTTP regression','v2','other',current_date,null,(select manager_a from c010_round1_fixture),
    null,null,null,gen_random_uuid());
  if (saved->>'row_version')::bigint<>2 then raise exception 'CAS setup did not advance to v2'; end if;
  for attempt in 1..2 loop
    begin
      perform public.transition_c010_stable_task((select stable_a from c010_round1_fixture),
        task_uuid,1,'complete',stale_request);
      raise exception 'stale completion unexpectedly succeeded';
    exception when sqlstate 'PT409' then
      if sqlerrm<>'STALE_TASK_VERSION' then raise; end if;
    end;
    begin
      perform public.upsert_c010_stable_task((select stable_a from c010_round1_fixture),task_uuid,1,
        'CAS HTTP regression','stale overwrite','other',current_date,null,(select manager_a from c010_round1_fixture),
        null,null,null,stale_request);
      raise exception 'stale edit unexpectedly succeeded';
    exception when sqlstate 'PT409' then
      if sqlerrm<>'STALE_TASK_VERSION' then raise; end if;
    end;
  end loop;
  select * into row_data from public.stable_tasks where id=task_uuid;
  if row_data.status<>'open' or row_data.row_version<>2 or row_data.note<>'v2'
    or (select count(*) from public.stable_task_events where task_id=task_uuid)<>2
  then raise exception 'stale attempts changed task or event history'; end if;
  saved:=public.transition_c010_stable_task((select stable_a from c010_round1_fixture),task_uuid,2,'complete',completion_request);
  if saved->>'status'<>'completed' or (saved->>'row_version')::bigint<>3 then
    raise exception 'current version completion failed'; end if;
  saved:=public.transition_c010_stable_task((select stable_a from c010_round1_fixture),task_uuid,2,'complete',completion_request);
  if saved->>'status'<>'completed' or (saved->>'row_version')::bigint<>3 or not (saved->>'idempotent')::boolean
    or (select count(*) from public.stable_task_events where task_id=task_uuid and event_type='completed')<>1
  then raise exception 'completion receipt replay produced duplicate outcome'; end if;
end $$;

reset role;
do $$ begin
  if (select count(*) from pg_policy where polrelid='public.stable_tasks'::regclass and polcmd in('r','*'))<>1
    or (select count(*) from pg_policy where polrelid='public.stable_task_events'::regclass and polcmd in('r','*'))<>1
  then raise exception 'alternative permissive read policy exists'; end if;
  if (select count(*) from public.stable_tasks t join repair_tasks f on f.id=t.id)<>4
    or (select count(*) from public.stable_task_events e join repair_tasks f on f.id=e.task_id)<>6
  then raise exception 'visibility changes destroyed task history'; end if;
end $$;
select extensions.pass('13 role/revocation cases: open/history, direct tasks/events, scoped RPC/Today, no read bypass, no history loss');
select * from extensions.finish();
rollback;
