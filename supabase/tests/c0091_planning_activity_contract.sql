begin;

select extensions.plan(1);

create temporary table pg_temp.c0091_activity_fixture (
  authority_user uuid not null,
  outsider_user uuid not null,
  authority_profile uuid,
  outsider_profile uuid,
  horse_id uuid,
  outsider_horse_id uuid
) on commit drop;

create temporary table pg_temp.c0091_activity_items (
  item_kind text primary key,
  visible_label text not null,
  schedule_item_id uuid not null,
  request_id uuid not null,
  scheduled_start_at timestamptz not null,
  scheduled_end_at timestamptz not null
) on commit drop;

grant select,update on pg_temp.c0091_activity_fixture to authenticated;
grant select,insert,update on pg_temp.c0091_activity_items to authenticated;

insert into pg_temp.c0091_activity_fixture(authority_user,outsider_user) values (
  'c0930000-0000-4000-8000-000000000001',
  'c0930000-0000-4000-8000-000000000002'
);

insert into auth.users(
  instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
)
select '00000000-0000-0000-0000-000000000000'::uuid,authority_user,
  'authenticated','authenticated','c0091-contract-authority@example.invalid','',now(),
  '{"provider":"email","providers":["email"]}'::jsonb,'{}'::jsonb,now(),now()
from pg_temp.c0091_activity_fixture
union all
select '00000000-0000-0000-0000-000000000000'::uuid,outsider_user,
  'authenticated','authenticated','c0091-contract-outsider@example.invalid','',now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"stable_id":"spoof","role":"owner","horse_id":"spoof"}'::jsonb,
  now(),now()
from pg_temp.c0091_activity_fixture;

update pg_temp.c0091_activity_fixture fixture set
  authority_profile=(select id from public.profiles where auth_user_id=fixture.authority_user),
  outsider_profile=(select id from public.profiles where auth_user_id=fixture.outsider_user);

select set_config('request.jwt.claim.role','authenticated',true);
select set_config(
  'request.jwt.claim.sub',
  (select authority_user::text from pg_temp.c0091_activity_fixture),true
);
set local role authenticated;

with created as (
  select * from public.create_canonical_horse_profile(
    'C-009.1 Activity Contract',null,null,'unknown',null,null,null,null,null,
    null,null,null,'c0931000-0000-4000-8000-000000000001'
  )
) update pg_temp.c0091_activity_fixture fixture set horse_id=created.horse_id from created;

do $$
declare
  spec record;
  result jsonb;
  request_id uuid;
  starts_at timestamptz;
  ends_at timestamptz;
  note text;
begin
  for spec in
    select * from (values
      (1,'training','Training'),
      (2,'task','Taak'),
      (3,'care','Verzorging'),
      (4,'farrier','Hoefsmid'),
      (5,'veterinary','Dierenarts'),
      (6,'competition','Wedstrijd'),
      (7,'transport','Transport'),
      (8,'other','Overig'),
      (9,'feeding','Voeding')
    ) value(sequence,item_kind,visible_label)
  loop
    request_id := gen_random_uuid();
    starts_at := date_trunc('day',now()) + (spec.sequence + 7) * interval '1 hour';
    ends_at := starts_at + interval '1 hour';
    note := case
      when spec.item_kind in ('farrier','veterinary','competition','transport') then null
      when spec.item_kind='training' then 'Bestaande instructie blijft intact'
      else 'Bestaande notitie voor '||spec.visible_label
    end;
    result := public.upsert_canonical_horse_schedule_item(
      (select horse_id from pg_temp.c0091_activity_fixture),null,null,
      spec.item_kind,spec.visible_label,note,'normal',starts_at,ends_at,
      'Europe/Amsterdam','planned',null,request_id
    );
    insert into pg_temp.c0091_activity_items(
      item_kind,visible_label,schedule_item_id,request_id,
      scheduled_start_at,scheduled_end_at
    ) values (
      spec.item_kind,spec.visible_label,(result->>'schedule_item_id')::uuid,
      request_id,starts_at,ends_at
    );
  end loop;
end;
$$;

do $$
declare
  item pg_temp.c0091_activity_items%rowtype;
  replay jsonb;
begin
  select * into item from pg_temp.c0091_activity_items where item_kind='farrier';
  replay := public.upsert_canonical_horse_schedule_item(
    (select horse_id from pg_temp.c0091_activity_fixture),null,null,
    item.item_kind,item.visible_label,null,'normal',
    item.scheduled_start_at,item.scheduled_end_at,
    'Europe/Amsterdam','planned',null,item.request_id
  );
  if (replay->>'schedule_item_id')::uuid<>item.schedule_item_id
    or (replay->>'idempotent')::boolean is not true
  then raise exception 'optional-note idempotent replay diverged'; end if;

  if (select count(*) from public.schedule_items
      where horse_id=(select horse_id from pg_temp.c0091_activity_fixture))<>9
    or (select count(*) from public.schedule_items
      where horse_id=(select horse_id from pg_temp.c0091_activity_fixture)
        and item_kind in (
          'task','feeding','training','care','farrier','veterinary',
          'competition','transport','other'
        ))<>9
    or exists (
      select 1 from public.schedule_items schedule
      join pg_temp.c0091_activity_items expected
        on expected.schedule_item_id=schedule.id
      where schedule.title<>expected.visible_label
    )
    or exists (
      select 1 from public.schedule_items
      where horse_id=(select horse_id from pg_temp.c0091_activity_fixture)
        and item_kind in ('farrier','veterinary','competition','transport')
        and instruction<>''
    )
    or (select instruction from public.schedule_items
      where id=(select schedule_item_id from pg_temp.c0091_activity_items
        where item_kind='training'))<>'Bestaande instructie blijft intact'
  then raise exception 'activity type, title or optional-note persistence failed'; end if;

  if (select count(*) from public.list_canonical_horse_schedule(
      (select horse_id from pg_temp.c0091_activity_fixture),
      now()-interval '1 day',now()+interval '2 days'
    ))<>9
    or (select count(*) from public.list_my_canonical_horse_schedule(
      now()-interval '1 day',now()+interval '2 days'
    ))<>9
    or exists (
      select schedule_item_id from public.list_canonical_horse_schedule(
        (select horse_id from pg_temp.c0091_activity_fixture),
        now()-interval '1 day',now()+interval '2 days'
      )
      except
      select schedule_item_id from public.list_my_canonical_horse_schedule(
        now()-interval '1 day',now()+interval '2 days'
      )
    )
  then raise exception 'horse and general Planning projections diverged'; end if;
end;
$$;

do $$
begin
  begin
    perform public.upsert_canonical_horse_schedule_item(
      (select horse_id from pg_temp.c0091_activity_fixture),null,null,
      'unknown_kind','Onbekend',null,'normal',now()+interval '1 day',
      now()+interval '1 day 1 hour','Europe/Amsterdam','planned',null,
      gen_random_uuid()
    );
    raise exception 'unknown activity kind accepted';
  exception when sqlstate '22023' then
    if sqlerrm<>'INVALID_CANONICAL_SCHEDULE_ITEM' then raise; end if;
  end;
end;
$$;

do $$
declare
  competition pg_temp.c0091_activity_items%rowtype;
  transport pg_temp.c0091_activity_items%rowtype;
begin
  select * into competition from pg_temp.c0091_activity_items
    where item_kind='competition';
  perform public.upsert_canonical_horse_schedule_item(
    (select horse_id from pg_temp.c0091_activity_fixture),
    competition.schedule_item_id,1,'competition','Wedstrijd',null,'high',
    competition.scheduled_start_at,competition.scheduled_end_at,
    'Europe/Amsterdam','planned',null,gen_random_uuid()
  );
  begin
    perform public.upsert_canonical_horse_schedule_item(
      (select horse_id from pg_temp.c0091_activity_fixture),
      competition.schedule_item_id,1,'competition','Wedstrijd',null,'normal',
      competition.scheduled_start_at,competition.scheduled_end_at,
      'Europe/Amsterdam','planned',null,gen_random_uuid()
    );
    raise exception 'stale activity writer accepted';
  exception when serialization_failure then
    if sqlerrm<>'STALE_SCHEDULE_VERSION' then raise; end if;
  end;

  select * into transport from pg_temp.c0091_activity_items
    where item_kind='transport';
  perform public.upsert_canonical_horse_schedule_item(
    (select horse_id from pg_temp.c0091_activity_fixture),
    transport.schedule_item_id,1,'transport','Transport',null,'normal',
    transport.scheduled_start_at,transport.scheduled_end_at,
    'Europe/Amsterdam','cancelled','Geannuleerd vanuit Planning.',gen_random_uuid()
  );
  if (select state from public.schedule_items where id=transport.schedule_item_id)<>'cancelled'
    or (select terminal_at from public.schedule_items where id=transport.schedule_item_id) is null
  then raise exception 'cancellation semantics failed'; end if;
end;
$$;

reset role;

select set_config(
  'request.jwt.claim.sub',
  (select outsider_user::text from pg_temp.c0091_activity_fixture),true
);
set local role authenticated;

with created as (
  select * from public.create_canonical_horse_profile(
    'C-009.1 Isolated Horse',null,null,'unknown',null,null,null,null,null,
    null,null,null,'c0931000-0000-4000-8000-000000000002'
  )
) update pg_temp.c0091_activity_fixture fixture set outsider_horse_id=created.horse_id from created;

do $$
begin
  begin
    perform public.list_canonical_horse_schedule(
      (select horse_id from pg_temp.c0091_activity_fixture),
      now()-interval '1 day',now()+interval '2 days'
    );
    raise exception 'cross-horse schedule list succeeded';
  exception when insufficient_privilege then null; end;
  begin
    perform public.upsert_canonical_horse_schedule_item(
      (select horse_id from pg_temp.c0091_activity_fixture),null,null,
      'veterinary','Dierenarts',null,'normal',now()+interval '1 day',
      now()+interval '1 day 1 hour','Europe/Amsterdam','planned',null,
      gen_random_uuid()
    );
    raise exception 'cross-horse activity write succeeded';
  exception when insufficient_privilege then null; end;
  if exists (
    select 1 from public.schedule_items
    where horse_id=(select horse_id from pg_temp.c0091_activity_fixture)
  ) or exists (
    select 1 from public.list_my_canonical_horse_schedule(
      now()-interval '1 day',now()+interval '2 days'
    )
  ) then raise exception 'RLS or actor isolation leaked Planning records'; end if;
end;
$$;

reset role;

do $$
begin
  if (select is_nullable from information_schema.columns
      where table_schema='public' and table_name='schedule_items'
        and column_name='instruction')<>'NO'
    or not pg_catalog.has_function_privilege(
      'authenticated',
      'public.upsert_canonical_horse_schedule_item(uuid,uuid,bigint,text,text,text,text,timestamp with time zone,timestamp with time zone,text,text,text,uuid)',
      'EXECUTE'
    )
    or pg_catalog.has_function_privilege(
      'anon',
      'public.upsert_canonical_horse_schedule_item(uuid,uuid,bigint,text,text,text,text,timestamp with time zone,timestamp with time zone,text,text,text,uuid)',
      'EXECUTE'
    )
  then raise exception 'optional-note shape or canonical RPC ACL changed'; end if;
end;
$$;

select extensions.ok(
  true,
  'C-009.1 Planning activity contract, compatibility and isolation passed'
);
select * from extensions.finish();

rollback;
