begin;
select extensions.plan(1);

-- Disposable identities; the entire suite is rolled back. The two writes for
-- actor A represent independent profile editors, followed by stale retries.
create temporary table ux_profile_fixture (actor_a uuid, actor_b uuid);
insert into ux_profile_fixture values (
  'c010aa00-0000-4000-8000-000000000001',
  'c010aa00-0000-4000-8000-000000000002'
);
grant select on pg_temp.ux_profile_fixture to authenticated;
insert into auth.users (
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
)
select '00000000-0000-0000-0000-000000000000'::uuid,id,
  'authenticated','authenticated',email,'',now(),
  '{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()
from (values
  ('c010aa00-0000-4000-8000-000000000001'::uuid,'ux-profile-a@example.invalid'),
  ('c010aa00-0000-4000-8000-000000000002'::uuid,'ux-profile-b@example.invalid')
) fixture(id,email);

set local role authenticated;
select set_config('request.jwt.claim.role','authenticated',true);
select set_config('request.jwt.claim.sub',
  (select actor_a::text from pg_temp.ux_profile_fixture),true);
do $$
declare initial record; first_write record; other_writer record; latest record;
  retried record; attempt integer; recipient_before record; recipient_after record;
  owned_horse record; granted record;
begin
  select * into strict initial from public.get_current_account_profile();
  select * into strict first_write from public.update_current_account_profile(
    initial.row_version,'Alice','Profile',null,'nl','Europe/Amsterdam','light',
    'individualHorse',true,null,'c010aa10-0000-4000-8000-000000000001'
  );
  if first_write.row_version<>initial.row_version+1
      or first_write.access_version<>initial.access_version then
    raise exception 'ordinary profile save changed version/security semantics'; end if;
  -- A second editor saves after the first editor captured first_write.version.
  select * into strict other_writer from public.update_current_account_profile(
    first_write.row_version,'Alice','Other editor','+31622222222','nl',
    'Europe/Amsterdam','light','individualHorse',false,null,
    'c010aa10-0000-4000-8000-000000000002'
  );
  for attempt in 1..3 loop
    begin
      perform * from public.update_current_account_profile(
        first_write.row_version,'Stale','Must not overwrite',null,'nl','UTC',
        'dark','individualHorse',false,null,
        'c010aa10-0000-4000-8000-000000000003'
      );
      raise exception 'stale profile write succeeded';
    exception when sqlstate 'PT409' then
      if sqlerrm<>'PROFILE_VERSION_STALE' then raise;end if;
    end;
  end loop;
  select * into strict latest from public.get_current_account_profile();
  if latest.row_version<>other_writer.row_version
      or latest.theme_mode<>'light' or latest.last_name<>'Other editor'
      or latest.phone_e164<>'+31622222222'
      or latest.access_version<>initial.access_version then
    raise exception 'stale retry changed saved data or authority'; end if;
  -- Explicit retry after reading the latest version, preserving the other edit.
  select * into strict retried from public.update_current_account_profile(
    latest.row_version,'Alice',latest.last_name,latest.phone_e164,'nl',
    'Europe/Amsterdam','dark','individualHorse',false,null,
    'c010aa10-0000-4000-8000-000000000004'
  );
  if retried.row_version<>latest.row_version+1 or retried.theme_mode<>'dark'
      or retried.phone_e164<>latest.phone_e164
      or retried.access_version<>initial.access_version then
    raise exception 'explicit latest-version retry failed'; end if;
  -- The API does not accept an actor/profile id; B is always scoped to B.
  perform set_config('request.jwt.claim.sub',
    (select actor_b::text from pg_temp.ux_profile_fixture),true);
  select * into strict latest from public.get_current_account_profile();
  if latest.profile_id=initial.profile_id or latest.row_version<>1 then
    raise exception 'profile projection crossed identity boundary'; end if;
  begin
    perform * from public.update_current_account_profile(
      1,'Bob',null,null,'nl','Europe/Amsterdam','light','individualHorse',false,
      'c010aa00-0000-4000-8000-000000000001/avatar-11111111-1111-4111-8111-111111111111.png',
      'c010aa10-0000-4000-8000-000000000005'
    );
    raise exception 'cross-account avatar was accepted';
  exception when insufficient_privilege then
    if sqlerrm<>'AVATAR_PATH_NOT_OWNED' then raise;end if;
  end;
  -- An open profile also becomes stale after a real authority operation.
  -- Capture B's form, then let A grant B horse.view through the public API.
  recipient_before := latest;
  perform set_config('request.jwt.claim.sub',
    (select actor_a::text from pg_temp.ux_profile_fixture),true);
  select * into strict owned_horse from public.create_canonical_horse_profile(
    'UX profile permission fixture',null,null,'unknown',null,null,null,null,
    null,null,null,null,'c010aa10-0000-4000-8000-000000000006'
  );
  select * into strict granted from public.grant_horse_profile_permission(
    owned_horse.horse_id,recipient_before.profile_id,'horse.view',null,now(),
    null,'MANUAL_GRANT','c010aa10-0000-4000-8000-000000000007'
  );
  if not granted.applied then raise exception 'fixture authority grant failed';end if;
  perform set_config('request.jwt.claim.sub',
    (select actor_b::text from pg_temp.ux_profile_fixture),true);
  select * into strict recipient_after from public.get_current_account_profile();
  if recipient_after.row_version<=recipient_before.row_version
      or recipient_after.access_version<=recipient_before.access_version then
    raise exception 'permission change did not advance profile/access version';end if;
  begin
    perform * from public.update_current_account_profile(
      recipient_before.row_version,'Bob',null,null,'nl','Europe/Amsterdam',
      'dark','individualHorse',false,null,
      'c010aa10-0000-4000-8000-000000000008'
    );
    raise exception 'profile save ignored concurrent authority change';
  exception when sqlstate 'PT409' then
    if sqlerrm<>'PROFILE_VERSION_STALE' then raise;end if;
  end;
  select * into strict latest from public.get_current_account_profile();
  if latest.row_version<>recipient_after.row_version
      or latest.access_version<>recipient_after.access_version then
    raise exception 'conflicting profile save altered new authority';end if;
  select * into strict retried from public.update_current_account_profile(
    latest.row_version,'Bob',null,null,'nl','Europe/Amsterdam','dark',
    'individualHorse',false,null,'c010aa10-0000-4000-8000-000000000009'
  );
  if retried.row_version<>latest.row_version+1
      or retried.access_version<>recipient_after.access_version then
    raise exception 'explicit profile retry changed authority';end if;
end;
$$;
reset role;

do $$
declare profile_a uuid; update_fn regprocedure :=
 'public.update_current_account_profile(bigint,text,text,text,text,text,text,text,boolean,text,uuid)'::regprocedure;
begin
  select id into strict profile_a from public.profiles
    where auth_user_id='c010aa00-0000-4000-8000-000000000001';
  if (select count(*) from public.audit_events where resource_id=profile_a
      and event_type='profile.account_fields_updated')<>3 then
    raise exception 'failed CAS appended an account change audit'; end if;
  if exists(select 1 from public.audit_events
      where correlation_id='c010aa10-0000-4000-8000-000000000003') then
    raise exception 'failed CAS recorded successful audit'; end if;
  if has_function_privilege('anon',update_fn,'execute')
      or has_function_privilege('service_role',update_fn,'execute')
      or not has_function_privilege('authenticated',update_fn,'execute') then
    raise exception 'profile function ACL widened or removed'; end if;
  if not exists(select 1 from pg_proc where oid=update_fn and prosecdef
      and proconfig @> array['search_path=""']::text[]) then
    raise exception 'profile function security boundary changed'; end if;
end;
$$;
select extensions.pass('UX profile CAS: PT409, no writes/audits on conflict, explicit retry, concurrent permission change, actor/ACL/avatar boundaries');
select * from extensions.finish();
rollback;
