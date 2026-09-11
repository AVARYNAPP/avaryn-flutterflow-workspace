begin;

-- C010 P2: physical non-box units and shared bookings. Existing stable_places
-- stay authoritative for boxes; stable_resource_items remain feed products.
-- No Auth UUID, new permission definition, role assignment or direct write ACL.
alter table public.stable_facilities add column arena_count integer not null default 0
  check(arena_count between 0 and 10000);
alter table public.stable_places add column place_type text not null default '' check(length(place_type)<=80),
 add column operating_status text not null default 'available' check(operating_status in('available','occupied','maintenance','reserved','rest')),
 add column note text not null default '' check(length(note)<=2000);
create table public.c010_facility_units(
 id uuid primary key default extensions.gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 kind text not null check(kind in('pasture','paddock','arena','walker','wash','locker')),
 ordinal integer not null check(ordinal between 1 and 10000),
 name text not null check(length(btrim(name)) between 1 and 80),
 unit_type text not null default '' check(length(unit_type)<=80),
 status text not null default 'available' check(status in('available','occupied','maintenance','reserved','rest','archived')),
 capacity integer not null check(capacity between 1 and 50),
 note text not null default '' check(length(note)<=2000),
 row_version bigint not null default 1 check(row_version>0),
 created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
 created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp(),
 unique(organization_id,kind,ordinal),unique(organization_id,id)
);
create table public.c010_horse_places(
 horse_id uuid primary key references public.canonical_horses(id) on delete restrict,
 organization_id uuid not null references public.organizations(id) on delete restrict,
 stable_place_id uuid not null,
 status text not null check(status in('active','ended')),
 note text not null default '' check(length(note)<=2000),
 row_version bigint not null default 1 check(row_version>0),
 assigned_by_profile_id uuid not null references public.profiles(id) on delete restrict,
 updated_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,stable_place_id) references public.stable_places(organization_id,id) on delete restrict
);
create unique index c010_horse_places_one_active_box on public.c010_horse_places(stable_place_id) where status='active';
create table public.c010_facility_bookings(
 id uuid primary key default extensions.gen_random_uuid(),
 organization_id uuid not null references public.organizations(id) on delete restrict,
 resource_id uuid not null,
 requester_profile_id uuid not null references public.profiles(id) on delete restrict,
 booking_date date not null check(isfinite(booking_date)),start_time time not null,end_time time not null,
 participants integer not null check(participants between 1 and 50),exclusive boolean not null default false,
 activity text not null default '' check(length(activity)<=180),note text not null default '' check(length(note)<=2000),
 status text not null check(status in('requested','approved','rejected','cancelled')),
 decision_note text not null default '' check(length(decision_note)<=2000),
 decided_by_profile_id uuid references public.profiles(id) on delete restrict,
 row_version bigint not null default 1 check(row_version>0),
 created_at timestamptz not null default clock_timestamp(),updated_at timestamptz not null default clock_timestamp(),
 foreign key(organization_id,resource_id) references public.c010_facility_units(organization_id,id) on delete restrict,
 check(start_time<end_time),check(exclusive or status<>'requested')
);
create index c010_facility_bookings_day on public.c010_facility_bookings(organization_id,booking_date,resource_id,status);
create table public.c010_facility_booking_horses(
 booking_id uuid not null references public.c010_facility_bookings(id) on delete restrict,
 horse_id uuid not null references public.canonical_horses(id) on delete restrict,
 primary key(booking_id,horse_id)
);
create table private.c010_function_preferences(
 profile_id uuid primary key references public.profiles(id) on delete restrict,
 functions text[] not null check(cardinality(functions) between 1 and 9 and functions <@ array['owner','rider','manager','trainer','groom','farrier','vet','physio','nutrition']::text[]),
 row_version bigint not null default 1 check(row_version>0),updated_at timestamptz not null default clock_timestamp()
);
create table private.c010_facility_receipts(
 actor_profile_id uuid not null references public.profiles(id) on delete restrict,
 request_id uuid not null,operation text not null,payload_hash bytea not null check(octet_length(payload_hash)=32),
 result jsonb not null,created_at timestamptz not null default clock_timestamp(),primary key(actor_profile_id,request_id)
);

create function private.c010p2_actor(p_write boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid;
begin
 if p_write then
  select p.id into actor from public.profiles p join auth.users a on a.id=p.auth_user_id
  where p.auth_user_id=auth.uid() and p.status='active' for update of p;
  if actor is null then raise exception using errcode='42501',message='ACTIVE_PROFILE_REQUIRED';end if;
 else actor:=private.c003b_actor_profile_id();end if;
 return actor;
end;$$;
create function private.c010p2_context(p_org uuid,p_write boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.c010p2_actor(p_write);
begin
 if p_write then
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('c010:p2:org:'||p_org::text,0));
  perform 1 from public.organizations o where o.id=p_org and o.status='active' for update;
 end if;
 if not private.c010_round1_active_member(actor,p_org) or not private.c003b_profile_has_permission(actor,p_org,'organization.view') then
  raise exception using errcode='42501',message='C010_FACILITY_ACCESS_REQUIRED';end if;
 return actor;
end;$$;
create function private.c010p2_manage(p_actor uuid,p_org uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select private.c010_round1_active_member(p_actor,p_org) and private.c003b_profile_has_permission(p_actor,p_org,'organization.edit')
$$;
create function private.c010p2_placement_live(p_horse uuid,p_org uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.horse_residencies r join public.canonical_horses h on h.id=r.horse_id and h.status='active'
 where r.horse_id=p_horse and r.stable_organization_id=p_org and r.status='active'
 and r.valid_from<=statement_timestamp() and (r.valid_until is null or r.valid_until>statement_timestamp()))
$$;
create function private.c010p2_horse(p_actor uuid,p_org uuid,p_horse uuid,p_plan boolean) returns boolean
language sql stable security definer set search_path='' as $$
 select private.c003c_profile_has_horse_permission(p_actor,p_horse,'horse.view')
 and exists(select 1 from public.horse_residencies r join public.canonical_horses h on h.id=r.horse_id and h.status='active'
 where r.horse_id=p_horse and r.stable_organization_id=p_org and r.status='active'
 and r.valid_from<=statement_timestamp() and (r.valid_until is null or r.valid_until>statement_timestamp()))
 and (not p_plan or private.c003c_profile_has_horse_permission(p_actor,p_horse,'horse.edit')
 or private.c003c_profile_has_horse_permission(p_actor,p_horse,'horse.planning.manage'))
$$;
create function private.c010p2_book(p_actor uuid,p_org uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select private.c010p2_manage(p_actor,p_org) or (
 private.c010_round1_active_member(p_actor,p_org) and private.c003b_profile_has_permission(p_actor,p_org,'organization.planning.view')
 and exists(select 1 from public.horse_residencies r where r.stable_organization_id=p_org
 and private.c010p2_horse(p_actor,p_org,r.horse_id,true)))
$$;
create function private.c010p2_receipt(p_actor uuid,p_request uuid,p_operation text,p_payload jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare r private.c010_facility_receipts%rowtype;
begin
 if p_request is null then raise exception using errcode='22023',message='C010_REQUEST_ID_REQUIRED';end if;
 select * into r from private.c010_facility_receipts where actor_profile_id=p_actor and request_id=p_request;
 if not found then return null;end if;
 if r.operation<>p_operation or r.payload_hash<>private.schedule_payload_hash(p_payload) then
  raise exception using errcode='22023',message='C010_P2_IDEMPOTENCY_CONFLICT';end if;
 return r.result||jsonb_build_object('idempotent',true);
end;$$;
create function private.c010p2_finish(p_actor uuid,p_org uuid,p_request uuid,p_operation text,p_payload jsonb,p_result jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 insert into private.c010_facility_receipts(actor_profile_id,request_id,operation,payload_hash,result)
 values(p_actor,p_request,p_operation,private.schedule_payload_hash(p_payload),p_result);
 if p_org is not null then
  perform private.c003b_write_audit('organization.updated','organization',p_org,p_org,p_actor,p_request,
   'ORGANIZATION_UPDATED','active','active',null,null,null,null,jsonb_build_object('operation_code','c010_p2_'||p_operation));
 end if;
 return p_result||jsonb_build_object('idempotent',false);
end;$$;
create function private.c010p2_immutable() returns trigger language plpgsql set search_path='' as $$
begin raise exception using errcode='42501',message='C010_P2_HISTORY_IMMUTABLE';end;$$;
create trigger c010p2_receipt_immutable before update or delete on private.c010_facility_receipts for each row execute function private.c010p2_immutable();
create trigger c010p2_receipt_no_truncate before truncate on private.c010_facility_receipts for each statement execute function private.c010p2_immutable();

-- No preference survives the owner's account preparation. This does not touch
-- authorities, historical booking receipts or another user's preferences.
create function private.c010p2_clear_preferences() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if old.status='active' and new.status<>'active' then delete from private.c010_function_preferences where profile_id=new.id;end if;
 return new;
end;$$;
create trigger c010p2_preferences_lifecycle after update of status on public.profiles for each row execute function private.c010p2_clear_preferences();
create function public.get_my_c010_function_profile() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.c010p2_actor(false);r private.c010_function_preferences%rowtype;
begin
 select * into r from private.c010_function_preferences where profile_id=actor;
 return jsonb_build_object('profile_id',actor,'functions',coalesce(r.functions,'{}'::text[]),'row_version',r.row_version);
end;$$;
create function public.save_my_c010_function_profile(p_functions text[],p_expected_row_version bigint,p_request_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.c010p2_actor(true);r private.c010_function_preferences%rowtype;payload jsonb;replay jsonb;selected text[];
begin
 select array_agg(distinct v order by v) into selected from unnest(p_functions) v;
 if coalesce(cardinality(selected),0) not between 1 and 9 or not selected<@array['owner','rider','manager','trainer','groom','farrier','vet','physio','nutrition']::text[] then
  raise exception using errcode='22023',message='C010_FUNCTION_CHOICES_INVALID';end if;
 payload:=jsonb_build_object('functions',selected,'expected',p_expected_row_version);
 replay:=private.c010p2_receipt(actor,p_request_id,'functions',payload);if replay is not null then return replay;end if;
 select * into r from private.c010_function_preferences where profile_id=actor for update;
 if r.row_version is distinct from p_expected_row_version then raise exception using errcode='PT409',message='C010_FUNCTION_VERSION_STALE';end if;
 insert into private.c010_function_preferences(profile_id,functions) values(actor,selected)
 on conflict(profile_id) do update set functions=excluded.functions,row_version=private.c010_function_preferences.row_version+1,updated_at=clock_timestamp()
 returning * into r;
 return private.c010p2_finish(actor,null,p_request_id,'functions',payload,jsonb_build_object('profile_id',actor,'row_version',r.row_version));
end;$$;

create function private.c010p2_capacity(p_resource uuid,p_date date,p_start time,p_end time,p_n integer,p_exclusive boolean,p_except uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare cap integer;maximum integer;
begin
 select capacity into cap from public.c010_facility_units where id=p_resource;
 with events as(
  select p_start t,case when p_exclusive then cap else p_n end delta
  union all select p_end,-(case when p_exclusive then cap else p_n end)
  union all select greatest(b.start_time,p_start),case when b.exclusive then cap else b.participants end
   from public.c010_facility_bookings b where b.resource_id=p_resource and b.booking_date=p_date and b.status='approved'
   and b.id is distinct from p_except and b.start_time<p_end and b.end_time>p_start
  union all select least(b.end_time,p_end),-(case when b.exclusive then cap else b.participants end)
   from public.c010_facility_bookings b where b.resource_id=p_resource and b.booking_date=p_date and b.status='approved'
   and b.id is distinct from p_except and b.start_time<p_end and b.end_time>p_start
 ), grouped as(select t,sum(delta) delta from events group by t),running as(select sum(delta) over(order by t) total from grouped)
 select max(total) into maximum from running;
 if maximum>cap then raise exception using errcode='PT409',message='C010_FACILITY_CAPACITY_CONFLICT';end if;
end;$$;

create function public.configure_c010_facilities(p_organization_id uuid,p_expected_row_version bigint,p_counts jsonb,p_walker_capacity integer,p_has_tack_room boolean,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.c010p2_context(p_organization_id,true);current_version bigint;payload jsonb;replay jsonb;r jsonb;resource_kind text;n integer;i integer;label text;booking record;
begin
 if not private.c010p2_manage(actor,p_organization_id) then raise exception using errcode='42501',message='C010_FACILITY_MANAGE_REQUIRED';end if;
 if p_counts is null or jsonb_typeof(p_counts)<>'object' or (select count(*) from jsonb_object_keys(p_counts))<>7
 or p_walker_capacity not between 1 and 20 or p_walker_capacity is null or p_has_tack_room is null then
  raise exception using errcode='22023',message='C010_FACILITY_COUNTS_INVALID';end if;
 foreach resource_kind in array array['stall','pasture','paddock','arena','walker','wash','locker'] loop
  if coalesce(p_counts->>resource_kind,'')!~'^[0-9]{1,2}$' or (p_counts->>resource_kind)::integer>50 then raise exception using errcode='22023',message='C010_FACILITY_COUNTS_INVALID';end if;
 end loop;
 if not p_has_tack_room and (p_counts->>'locker')::integer>0 then raise exception using errcode='22023',message='C010_TACK_ROOM_REQUIRED';end if;
 payload:=jsonb_build_object('org',p_organization_id,'expected',p_expected_row_version,'counts',p_counts,'walker_capacity',p_walker_capacity,'tack_room',p_has_tack_room);
 replay:=private.c010p2_receipt(actor,p_request_id,'configure',payload);if replay is not null then return replay;end if;
 select row_version into current_version from public.stable_facilities where organization_id=p_organization_id for update;
 if current_version is distinct from p_expected_row_version then raise exception using errcode='PT409',message='C010_FACILITY_VERSION_STALE';end if;
 if exists(select 1 from public.c010_facility_units u join public.c010_facility_bookings b on b.resource_id=u.id
 where u.organization_id=p_organization_id and u.ordinal>(p_counts->>u.kind)::integer)
 or exists(select 1 from public.c010_horse_places hp join public.stable_places sp on sp.id=hp.stable_place_id
 where hp.organization_id=p_organization_id and hp.status='active' and private.c010p2_placement_live(hp.horse_id,hp.organization_id) and sp.ordinal>(p_counts->>'stall')::integer) then
  raise exception using errcode='PT409',message='C010_FACILITY_HAS_HISTORY';end if;
 r:=public.update_c010_stable_facilities(p_organization_id,p_expected_row_version,(p_counts->>'stall')::integer,
 (p_counts->>'pasture')::integer,(p_counts->>'paddock')::integer,(p_counts->>'wash')::integer,(p_counts->>'walker')::integer>0,
 (p_counts->>'walker')::integer,case when (p_counts->>'walker')::integer>0 then p_walker_capacity else 0 end,p_has_tack_room,(p_counts->>'locker')::integer,p_request_id);
 update public.stable_facilities set arena_count=(p_counts->>'arena')::integer where organization_id=p_organization_id;
 foreach resource_kind in array array['pasture','paddock','arena','walker','wash','locker'] loop
  n:=(p_counts->>resource_kind)::integer;
  label:=case resource_kind when 'pasture' then 'Weide' when 'paddock' then 'Paddock' when 'arena' then 'Rijbak' when 'walker' then 'Stapmolen' when 'wash' then 'Wasplaats' else 'Kast' end;
  if n>0 then for i in 1..n loop
   insert into public.c010_facility_units(organization_id,kind,ordinal,name,unit_type,capacity,created_by_profile_id)
   values(p_organization_id,resource_kind,i,label||' '||i,case when resource_kind='arena' then 'Binnenbak' else '' end,
    case resource_kind when 'arena' then 4 when 'pasture' then 6 when 'paddock' then 2 when 'walker' then p_walker_capacity else 1 end,actor)
   on conflict(organization_id,kind,ordinal) do update set status=case when public.c010_facility_units.status='archived' then 'available' else public.c010_facility_units.status end,
    capacity=case when excluded.kind='walker' then excluded.capacity else public.c010_facility_units.capacity end,
    row_version=public.c010_facility_units.row_version+1,updated_at=clock_timestamp();
  end loop;end if;
  update public.c010_facility_units set status='archived',row_version=row_version+1,updated_at=clock_timestamp()
  where organization_id=p_organization_id and c010_facility_units.kind=resource_kind and ordinal>n and status<>'archived';
 end loop;
 for booking in select b.* from public.c010_facility_bookings b join public.c010_facility_units u on u.id=b.resource_id
 where u.organization_id=p_organization_id and u.kind='walker' and u.status<>'archived' and b.status in('approved','requested')
 and b.booking_date>=(statement_timestamp() at time zone 'Europe/Amsterdam')::date loop
  if booking.participants>p_walker_capacity then raise exception using errcode='PT409',message='C010_FACILITY_CAPACITY_CONFLICT';end if;
  if booking.status='approved' then perform private.c010p2_capacity(booking.resource_id,booking.booking_date,booking.start_time,booking.end_time,booking.participants,booking.exclusive,booking.id);end if;
 end loop;
 return private.c010p2_finish(actor,p_organization_id,p_request_id,'configure',payload,jsonb_build_object('organization_id',p_organization_id,'row_version',(r->>'row_version')::bigint));
end;$$;

create function public.update_c010_facility_unit(p_organization_id uuid,p_resource_id uuid,p_expected_row_version bigint,p_name text,p_type text,p_status text,p_capacity integer,p_note text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.c010p2_context(p_organization_id,true);u public.c010_facility_units%rowtype;sp public.stable_places%rowtype;payload jsonb;replay jsonb;b record;new_version bigint;
begin
 if not private.c010p2_manage(actor,p_organization_id) then raise exception using errcode='42501',message='C010_FACILITY_MANAGE_REQUIRED';end if;
 if length(btrim(coalesce(p_name,''))) not between 1 and 80 or p_capacity is null or p_capacity not between 1 and 50
 or p_status is null or p_status not in('available','occupied','maintenance','reserved','rest') or length(coalesce(p_note,''))>2000 or length(coalesce(p_type,''))>80 then
  raise exception using errcode='22023',message='C010_FACILITY_INPUT_INVALID';end if;
 select * into u from public.c010_facility_units where id=p_resource_id and organization_id=p_organization_id and status<>'archived' for update;
 if u.id is null then select * into sp from public.stable_places where id=p_resource_id and organization_id=p_organization_id and status='active' for update;end if;
 if u.id is null and sp.id is null then raise exception using errcode='42501',message='C010_FACILITY_UNAVAILABLE';end if;
 payload:=jsonb_build_object('org',p_organization_id,'id',p_resource_id,'expected',p_expected_row_version,'name',p_name,'type',p_type,'status',p_status,'capacity',p_capacity,'note',p_note);
 replay:=private.c010p2_receipt(actor,p_request_id,'resource',payload);if replay is not null then return replay;end if;
 if coalesce(u.row_version,sp.row_version) is distinct from p_expected_row_version then raise exception using errcode='PT409',message='C010_FACILITY_VERSION_STALE';end if;
 if p_status<>'available' and ((u.id is not null and exists(select 1 from public.c010_facility_bookings where resource_id=u.id and status in('approved','requested') and booking_date>=(statement_timestamp() at time zone 'Europe/Amsterdam')::date)) or (sp.id is not null and exists(select 1 from public.c010_horse_places where stable_place_id=sp.id and status='active'))) then
  raise exception using errcode='PT409',message='C010_FACILITY_HAS_PLANNING';end if;
 if sp.id is not null then
  if p_capacity<>1 then raise exception using errcode='22023',message='C010_BOX_CAPACITY_ONE';end if;
  update public.stable_places set label=btrim(p_name),place_type=coalesce(p_type,''),operating_status=p_status,note=coalesce(p_note,''),row_version=row_version+1,updated_at=clock_timestamp() where id=sp.id returning row_version into new_version;
 else
  update public.c010_facility_units set name=btrim(p_name),unit_type=coalesce(p_type,''),status=p_status,capacity=p_capacity,note=coalesce(p_note,''),row_version=row_version+1,updated_at=clock_timestamp()
   where id=u.id returning row_version into new_version;
  for b in select * from public.c010_facility_bookings where resource_id=u.id and status in('approved','requested')
   and booking_date>=(statement_timestamp() at time zone 'Europe/Amsterdam')::date loop
   if b.participants>p_capacity then raise exception using errcode='PT409',message='C010_FACILITY_CAPACITY_CONFLICT';end if;
   if b.status='approved' then perform private.c010p2_capacity(u.id,b.booking_date,b.start_time,b.end_time,b.participants,b.exclusive,b.id);end if;
  end loop;
 end if;
 return private.c010p2_finish(actor,p_organization_id,p_request_id,'resource',payload,jsonb_build_object('resource_id',p_resource_id,'row_version',new_version));
end;$$;

create function public.set_c010_horse_place(p_organization_id uuid,p_horse_id uuid,p_stable_place_id uuid,p_expected_row_version bigint,p_note text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.c010p2_context(p_organization_id,true);old public.c010_horse_places%rowtype;after_row public.c010_horse_places%rowtype;payload jsonb;replay jsonb;
begin
 if not private.c003b_profile_has_permission(actor,p_organization_id,'organization.residencies.manage') then raise exception using errcode='42501',message='C010_PLACE_MANAGE_REQUIRED';end if;
 perform 1 from public.canonical_horses where id=p_horse_id for update;
 if p_stable_place_id is not null and not private.c010p2_horse(actor,p_organization_id,p_horse_id,false) then raise exception using errcode='42501',message='C010_HORSE_CONTEXT_REQUIRED';end if;
 if length(coalesce(p_note,''))>2000 then raise exception using errcode='22023',message='C010_PLACE_NOTE_INVALID';end if;
 if p_stable_place_id is not null and not exists(select 1 from public.stable_places where id=p_stable_place_id and organization_id=p_organization_id and status='active' and operating_status='available') then
  raise exception using errcode='42501',message='C010_FACILITY_UNAVAILABLE';end if;
 payload:=jsonb_build_object('org',p_organization_id,'horse',p_horse_id,'place',p_stable_place_id,'expected',p_expected_row_version,'note',p_note);
 replay:=private.c010p2_receipt(actor,p_request_id,'placement',payload);if replay is not null then return replay;end if;
 select * into old from public.c010_horse_places where horse_id=p_horse_id for update;
 if p_stable_place_id is null and (old.horse_id is null or old.organization_id<>p_organization_id) then raise exception using errcode='42501',message='C010_HORSE_CONTEXT_REQUIRED';end if;
 if old.row_version is distinct from p_expected_row_version then raise exception using errcode='PT409',message='C010_PLACE_VERSION_STALE';end if;
 if old.horse_id is null and p_stable_place_id is null then raise exception using errcode='22023',message='C010_PLACE_ASSIGNMENT_REQUIRED';end if;
 update public.c010_horse_places hp set status='ended',row_version=row_version+1,updated_at=clock_timestamp()
 where hp.organization_id=p_organization_id and hp.stable_place_id=p_stable_place_id and hp.status='active' and not private.c010p2_placement_live(hp.horse_id,hp.organization_id);
 if p_stable_place_id is not null and exists(select 1 from public.c010_horse_places where stable_place_id=p_stable_place_id and status='active' and horse_id<>p_horse_id) then
  raise exception using errcode='PT409',message='C010_PLACE_OCCUPIED';end if;
 insert into public.c010_horse_places(horse_id,organization_id,stable_place_id,status,note,assigned_by_profile_id)
 values(p_horse_id,p_organization_id,coalesce(p_stable_place_id,old.stable_place_id),case when p_stable_place_id is null then 'ended' else 'active' end,coalesce(p_note,''),actor)
 on conflict(horse_id) do update set organization_id=excluded.organization_id,stable_place_id=excluded.stable_place_id,status=excluded.status,note=excluded.note,
 row_version=public.c010_horse_places.row_version+1,assigned_by_profile_id=actor,updated_at=clock_timestamp() returning * into after_row;
 return private.c010p2_finish(actor,p_organization_id,p_request_id,'placement',payload,jsonb_build_object('horse_id',p_horse_id,'resource_id',p_stable_place_id,'row_version',after_row.row_version,'status',after_row.status,'previous_resource_id',old.stable_place_id));
end;$$;
create function private.c010p2_end_derived_place() returns trigger language plpgsql security definer set search_path='' as $$
declare target_horse uuid;
begin
 if tg_table_name='canonical_horses' then target_horse:=new.id;else target_horse:=old.horse_id;end if;
 update public.c010_horse_places hp set status='ended',row_version=row_version+1,updated_at=clock_timestamp()
 where hp.horse_id=target_horse and hp.status='active' and not private.c010p2_placement_live(hp.horse_id,hp.organization_id);
 return new;
end;$$;
create trigger c010p2_residency_place after update on public.horse_residencies for each row execute function private.c010p2_end_derived_place();
create trigger c010p2_retired_horse_place after update of status on public.canonical_horses for each row execute function private.c010p2_end_derived_place();
create function private.c010p2_box_archive_guard() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='archived' and old.status='active' and exists(select 1 from public.c010_horse_places hp where hp.stable_place_id=new.id and hp.status='active' and private.c010p2_placement_live(hp.horse_id,hp.organization_id)) then
  raise exception using errcode='PT409',message='C010_PLACE_OCCUPIED';end if;return new;
end;$$;
create trigger c010p2_box_archive_guard before update of status on public.stable_places for each row execute function private.c010p2_box_archive_guard();

create function private.c010p2_civil_time(p_date date,p_time time) returns boolean
language plpgsql stable set search_path='' as $$
declare wall timestamp;instant timestamptz;
begin
 if p_date is null or not isfinite(p_date) or p_time is null or p_time='24:00'::time or extract(second from p_time)<>0 then return false;end if;
 wall:=p_date+p_time;instant:=wall at time zone 'Europe/Amsterdam';
 return (instant at time zone 'Europe/Amsterdam')=wall
 and ((instant-interval '1 hour') at time zone 'Europe/Amsterdam')<>wall
 and ((instant+interval '1 hour') at time zone 'Europe/Amsterdam')<>wall;
end;$$;
create function public.save_c010_facility_booking(p_organization_id uuid,p_booking_id uuid,p_expected_row_version bigint,p_resource_id uuid,p_date date,p_start time,p_end time,p_horse_ids uuid[],p_participants integer,p_activity text,p_note text,p_exclusive boolean,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.c010p2_context(p_organization_id,true);manager boolean:=private.c010p2_manage(actor,p_organization_id);u public.c010_facility_units%rowtype;
 old public.c010_facility_bookings%rowtype;after_row public.c010_facility_bookings%rowtype;payload jsonb;replay jsonb;horses uuid[];h uuid;next_status text;today date:=(statement_timestamp() at time zone 'Europe/Amsterdam')::date;
begin
 if not private.c010p2_book(actor,p_organization_id) then raise exception using errcode='42501',message='C010_FACILITY_BOOK_REQUIRED';end if;
 select * into u from public.c010_facility_units where id=p_resource_id and organization_id=p_organization_id and status='available' for update;
 if u.id is null or u.kind='locker' then raise exception using errcode='42501',message='C010_FACILITY_UNAVAILABLE';end if;
 if u.kind<>'arena' and not manager then raise exception using errcode='42501',message='C010_FACILITY_MANAGE_REQUIRED';end if;
 select coalesce(array_agg(distinct value order by value),'{}'::uuid[]) into horses from unnest(coalesce(p_horse_ids,'{}'::uuid[])) value;
 if p_date is null or not isfinite(p_date) or p_date<today or p_date>today+366 or p_start is null or p_end is null or p_start>=p_end or p_start='24:00'::time or p_end='24:00'::time
 or not private.c010p2_civil_time(p_date,p_start) or not private.c010p2_civil_time(p_date,p_end)
 or p_participants is null or p_participants not between 1 and u.capacity or p_exclusive is null
 or (u.kind='arena' and cardinality(horses)>1) or (u.kind<>'arena' and (cardinality(horses)=0 or p_participants<>cardinality(horses) or p_exclusive))
 or cardinality(horses)<>cardinality(coalesce(p_horse_ids,'{}'::uuid[])) or array_position(horses,null) is not null
 or length(coalesce(p_activity,''))>180 or length(coalesce(p_note,''))>2000 or (p_exclusive and length(btrim(coalesce(p_note,'')))=0) then
  raise exception using errcode='22023',message='C010_BOOKING_INPUT_INVALID';end if;
 -- Lock actual horses before checking current residency and explicit permissions.
 foreach h in array horses loop
  perform 1 from public.canonical_horses where id=h for update;
  if not private.c010p2_horse(actor,p_organization_id,h,u.kind='arena' and not manager) then raise exception using errcode='42501',message='C010_HORSE_CONTEXT_REQUIRED';end if;
 end loop;
 if p_booking_id is not null then
  select * into old from public.c010_facility_bookings where id=p_booking_id and organization_id=p_organization_id for update;
  if old.id is null or (not manager and old.requester_profile_id<>actor) then raise exception using errcode='42501',message='C010_BOOKING_UNAVAILABLE';end if;
 end if;
 payload:=jsonb_build_object('org',p_organization_id,'id',p_booking_id,'expected',p_expected_row_version,'resource',p_resource_id,'date',p_date,'start',p_start,'end',p_end,'horses',horses,'participants',p_participants,'activity',p_activity,'note',p_note,'exclusive',p_exclusive);
 replay:=private.c010p2_receipt(actor,p_request_id,'booking',payload);if replay is not null then return replay;end if;
 if old.row_version is distinct from p_expected_row_version then raise exception using errcode='PT409',message='C010_BOOKING_VERSION_STALE';end if;
 if old.id is not null and old.status not in('approved','requested') then raise exception using errcode='PT409',message='C010_BOOKING_TERMINAL';end if;
 -- Every exclusive edit requires a fresh decision; manager action is explicit.
 next_status:=case when p_exclusive then 'requested' else 'approved' end;
 if next_status='approved' then perform private.c010p2_capacity(u.id,p_date,p_start,p_end,p_participants,false,p_booking_id);end if;
 if next_status='approved' and exists(select 1 from public.c010_facility_bookings b join public.c010_facility_booking_horses bh on bh.booking_id=b.id
 where b.id is distinct from p_booking_id and b.organization_id=p_organization_id and b.booking_date=p_date and b.status='approved'
 and b.start_time<p_end and b.end_time>p_start and bh.horse_id=any(horses)) then raise exception using errcode='PT409',message='C010_HORSE_LOCATION_CONFLICT';end if;
 if old.id is null then
  insert into public.c010_facility_bookings(organization_id,resource_id,requester_profile_id,booking_date,start_time,end_time,participants,exclusive,activity,note,status)
  values(p_organization_id,u.id,actor,p_date,p_start,p_end,p_participants,p_exclusive,coalesce(p_activity,''),coalesce(p_note,''),next_status) returning * into after_row;
 else
  update public.c010_facility_bookings set resource_id=u.id,booking_date=p_date,start_time=p_start,end_time=p_end,participants=p_participants,exclusive=p_exclusive,
  activity=coalesce(p_activity,''),note=coalesce(p_note,''),status=next_status,decision_note='',decided_by_profile_id=null,row_version=row_version+1,updated_at=clock_timestamp()
  where id=old.id returning * into after_row;
  delete from public.c010_facility_booking_horses where booking_id=old.id;
 end if;
 insert into public.c010_facility_booking_horses(booking_id,horse_id) select after_row.id,value from unnest(horses) value;
 return private.c010p2_finish(actor,p_organization_id,p_request_id,'booking',payload,jsonb_build_object('booking_id',after_row.id,'row_version',after_row.row_version,'status',after_row.status));
end;$$;

create function public.transition_c010_facility_booking(p_organization_id uuid,p_booking_id uuid,p_expected_row_version bigint,p_action text,p_note text,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.c010p2_context(p_organization_id,true);manager boolean:=private.c010p2_manage(actor,p_organization_id);b public.c010_facility_bookings%rowtype;u public.c010_facility_units%rowtype;
 payload jsonb;replay jsonb;new_status text;new_version bigint;h uuid;
begin
 select * into b from public.c010_facility_bookings where id=p_booking_id and organization_id=p_organization_id for update;
 if b.id is null or (not manager and (b.requester_profile_id<>actor or not private.c010p2_book(actor,p_organization_id))) then raise exception using errcode='42501',message='C010_BOOKING_UNAVAILABLE';end if;
 if p_action is null or p_action not in('approve','reject','cancel') or length(coalesce(p_note,''))>2000 then raise exception using errcode='22023',message='C010_BOOKING_ACTION_INVALID';end if;
 if p_action in('approve','reject') and not manager then raise exception using errcode='42501',message='C010_FACILITY_MANAGE_REQUIRED';end if;
 -- Active profile, org membership and current management/requester rights precede replay.
 payload:=jsonb_build_object('org',p_organization_id,'id',p_booking_id,'expected',p_expected_row_version,'action',p_action,'note',p_note);
 replay:=private.c010p2_receipt(actor,p_request_id,'transition',payload);if replay is not null then return replay;end if;
 if b.row_version is distinct from p_expected_row_version then raise exception using errcode='PT409',message='C010_BOOKING_VERSION_STALE';end if;
 if (p_action in('approve','reject') and b.status<>'requested') or (p_action='cancel' and b.status not in('approved','requested')) then raise exception using errcode='PT409',message='C010_BOOKING_TERMINAL';end if;
 if p_action='approve' then
  select * into u from public.c010_facility_units where id=b.resource_id and status='available' for update;
  if u.id is null then raise exception using errcode='PT409',message='C010_FACILITY_UNAVAILABLE';end if;
  for h in select horse_id from public.c010_facility_booking_horses where booking_id=b.id order by horse_id loop
   perform 1 from public.canonical_horses where id=h for update;
   if not private.c010p2_horse(actor,p_organization_id,h,false) then raise exception using errcode='42501',message='C010_HORSE_CONTEXT_REQUIRED';end if;
  end loop;
  perform private.c010p2_capacity(b.resource_id,b.booking_date,b.start_time,b.end_time,b.participants,true,b.id);
  if exists(select 1 from public.c010_facility_bookings other join public.c010_facility_booking_horses oh on oh.booking_id=other.id
   join public.c010_facility_booking_horses mine on mine.booking_id=b.id and mine.horse_id=oh.horse_id
   where other.id<>b.id and other.organization_id=p_organization_id and other.booking_date=b.booking_date and other.status='approved'
    and other.start_time<b.end_time and other.end_time>b.start_time) then raise exception using errcode='PT409',message='C010_HORSE_LOCATION_CONFLICT';end if;
 end if;
 new_status:=case p_action when 'approve' then 'approved' when 'reject' then 'rejected' else 'cancelled' end;
 update public.c010_facility_bookings set status=new_status,decision_note=coalesce(p_note,''),decided_by_profile_id=actor,row_version=row_version+1,updated_at=clock_timestamp()
 where id=b.id returning row_version into new_version;
 return private.c010p2_finish(actor,p_organization_id,p_request_id,'transition',payload,jsonb_build_object('booking_id',b.id,'row_version',new_version,'status',new_status));
end;$$;

create function public.get_c010_facility_workspace(p_organization_id uuid,p_on_date date default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.c010p2_context(p_organization_id,false);manager boolean:=private.c010p2_manage(actor,p_organization_id);book boolean:=private.c010p2_book(actor,p_organization_id);
 today date:=(statement_timestamp() at time zone 'Europe/Amsterdam')::date;selected date:=coalesce(p_on_date,today);f public.stable_facilities%rowtype;resources jsonb;places jsonb;versions jsonb;bookings jsonb;arenas jsonb;
begin
 if not isfinite(selected) or selected<today-366 or selected>today+366 then raise exception using errcode='22023',message='C010_FACILITY_DAY_INVALID';end if;
 select * into f from public.stable_facilities where organization_id=p_organization_id;
 select coalesce(jsonb_agg(value order by kind,ordinal),'[]') into resources from(
  select 'stall'::text kind,sp.ordinal,jsonb_build_object('id',sp.id,'kind','stall','number',sp.ordinal,'name',sp.label,'type',sp.place_type,'status',sp.operating_status,'capacity',1,'note',sp.note,'rowVersion',sp.row_version,'occupied',exists(select 1 from public.c010_horse_places hp where hp.stable_place_id=sp.id and hp.status='active' and private.c010p2_placement_live(hp.horse_id,hp.organization_id))) value
  from public.stable_places sp where sp.organization_id=p_organization_id and sp.status='active'
  union all select u.kind,u.ordinal,jsonb_build_object('id',u.id,'kind',u.kind,'number',u.ordinal,'name',u.name,'type',u.unit_type,'status',u.status,'capacity',u.capacity,'note',u.note,'rowVersion',u.row_version)
  from public.c010_facility_units u where u.organization_id=p_organization_id and u.status<>'archived'
 ) source;
 select coalesce(jsonb_agg(jsonb_build_object('resourceId',hp.stable_place_id,
 'horseId',case when private.c003c_profile_has_horse_permission(actor,hp.horse_id,'horse.view') then hp.horse_id end,
 'note',case when private.c003c_profile_has_horse_permission(actor,hp.horse_id,'horse.view') then hp.note else '' end,
 'rowVersion',case when private.c003c_profile_has_horse_permission(actor,hp.horse_id,'horse.view') then hp.row_version end,
 'redacted',not private.c003c_profile_has_horse_permission(actor,hp.horse_id,'horse.view')))
 filter(where hp.status='active' and private.c010p2_placement_live(hp.horse_id,hp.organization_id)),'[]'),
 coalesce(jsonb_object_agg(hp.horse_id,hp.row_version) filter(where private.c003c_profile_has_horse_permission(actor,hp.horse_id,'horse.view')),'{}')
 into places,versions from public.c010_horse_places hp where hp.organization_id=p_organization_id;
 with projected as(
 select b.*,u.kind,hs.ids,hs.visible_ids,
 (b.requester_profile_id=actor or manager) as private_details,
 (b.requester_profile_id=actor or manager or (hs.total>0 and hs.total=hs.visible_count)) as visible_activity,
 case when p.status='active' then p.display_name else 'Niet-actief account' end requester_name
 from public.c010_facility_bookings b join public.c010_facility_units u on u.id=b.resource_id
 join public.profiles p on p.id=b.requester_profile_id
 cross join lateral(select coalesce(array_agg(bh.horse_id order by bh.horse_id),'{}'::uuid[]) ids,
  coalesce(array_agg(bh.horse_id order by bh.horse_id) filter(where private.c003c_profile_has_horse_permission(actor,bh.horse_id,'horse.view')),'{}'::uuid[]) visible_ids,
  count(*) total,count(*) filter(where private.c003c_profile_has_horse_permission(actor,bh.horse_id,'horse.view')) visible_count
  from public.c010_facility_booking_horses bh where bh.booking_id=b.id) hs
 where b.organization_id=p_organization_id and (b.status='approved' or b.requester_profile_id=actor or manager)
 and (b.booking_date in(selected,today) or (b.status='requested' and b.booking_date between today and today+366))
 ), vals as(select kind,jsonb_build_object('id',id,'resourceId',resource_id,'date',booking_date,'start',to_char(start_time,'HH24:MI'),'end',to_char(end_time,'HH24:MI'),
 'horseIds',visible_ids,'horseId',case when cardinality(visible_ids)=1 then visible_ids[1] end,'participants',participants,'exclusive',exclusive,
 'activity',case when visible_activity then activity else '' end,'note',case when private_details then note else '' end,'status',status,'decisionNote',case when private_details then decision_note else '' end,
 'requesterId',case when private_details then requester_profile_id end,'requesterName',case when private_details then requester_name else '' end,'rowVersion',row_version,
 'canEdit',status in('approved','requested') and (manager or (kind='arena' and requester_profile_id=actor and book)),
 'canCancel',status in('approved','requested') and (manager or (kind='arena' and requester_profile_id=actor and book)),
 'canDecide',status='requested' and manager,'redacted',not private_details) value from projected)
 select coalesce(jsonb_agg(value) filter(where kind<>'arena'),'[]'),coalesce(jsonb_agg(value) filter(where kind='arena'),'[]') into bookings,arenas from vals;
 return jsonb_build_object('organization_id',p_organization_id,'profile_id',actor,'on_date',selected,
 'calendar',jsonb_build_object('today_date',today,'time_zone','Europe/Amsterdam','selected_date',selected,'covered_dates',array[ today,selected ],'pending_from',today,'pending_through',today+366),
 'configuration',jsonb_build_object('row_version',f.row_version,'counts',jsonb_build_object('stall',coalesce(f.box_count,0),'pasture',coalesce(f.pasture_count,0),'paddock',coalesce(f.paddock_count,0),'arena',coalesce(f.arena_count,0),'walker',coalesce(f.walker_count,0),'wash',coalesce(f.wash_bay_count,0),'locker',coalesce(f.tack_locker_count,0)),
 'walker_capacity',greatest(coalesce(f.walker_places_per_unit,0),1),'tack_room',coalesce(f.has_tack_room,false)),
 'resources',resources,'placements',places,'placementVersions',versions,'bookings',bookings,'arenaBookings',arenas,'capabilities',jsonb_build_object('manage',manager,'book',book));
end;$$;

alter table public.c010_facility_units enable row level security;
alter table public.c010_horse_places enable row level security;
alter table public.c010_facility_bookings enable row level security;
alter table public.c010_facility_booking_horses enable row level security;
alter table private.c010_function_preferences enable row level security;
alter table private.c010_facility_receipts enable row level security;
create policy c010_facility_units_read on public.c010_facility_units for select to authenticated
 using(public.has_organization_permission(organization_id,'organization.view'));
-- Booking details are available only through the explicit redacting projection.
revoke all on public.c010_facility_units,public.c010_horse_places,public.c010_facility_bookings,public.c010_facility_booking_horses,
 private.c010_function_preferences,private.c010_facility_receipts from public,anon,authenticated,service_role;
grant select on public.c010_facility_units to authenticated;
-- Every writer also acquires the existing active-profile lock, including trusted
-- SQL paths. Old JWTs cannot create entries after account preparation.
create trigger c010p2_actor_write before insert or update or delete on public.c010_facility_units for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010p2_actor_write before insert or update or delete on public.c010_horse_places for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010p2_actor_write before insert or update or delete on public.c010_facility_bookings for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010p2_actor_write before insert or update or delete on public.c010_facility_booking_horses for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010p2_actor_write before insert or update on private.c010_function_preferences for each row execute function private.c010_guard_deletion_actor_write();
create trigger c010p2_actor_write before insert on private.c010_facility_receipts for each row execute function private.c010_guard_deletion_actor_write();

revoke all on function private.c010p2_actor(boolean),private.c010p2_context(uuid,boolean),private.c010p2_manage(uuid,uuid),private.c010p2_horse(uuid,uuid,uuid,boolean),private.c010p2_book(uuid,uuid),
 private.c010p2_receipt(uuid,uuid,text,jsonb),private.c010p2_finish(uuid,uuid,uuid,text,jsonb,jsonb),private.c010p2_immutable(),private.c010p2_clear_preferences(),
 private.c010p2_capacity(uuid,date,time,time,integer,boolean,uuid),private.c010p2_box_archive_guard(),private.c010p2_placement_live(uuid,uuid),private.c010p2_end_derived_place(),private.c010p2_civil_time(date,time) from public,anon,authenticated,service_role;
revoke all on function public.get_my_c010_function_profile(),public.save_my_c010_function_profile(text[],bigint,uuid),public.get_c010_facility_workspace(uuid,date),
 public.configure_c010_facilities(uuid,bigint,jsonb,integer,boolean,uuid),public.update_c010_facility_unit(uuid,uuid,bigint,text,text,text,integer,text,uuid),
 public.set_c010_horse_place(uuid,uuid,uuid,bigint,text,uuid),public.save_c010_facility_booking(uuid,uuid,bigint,uuid,date,time,time,uuid[],integer,text,text,boolean,uuid),
 public.transition_c010_facility_booking(uuid,uuid,bigint,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_my_c010_function_profile(),public.save_my_c010_function_profile(text[],bigint,uuid),public.get_c010_facility_workspace(uuid,date),
 public.configure_c010_facilities(uuid,bigint,jsonb,integer,boolean,uuid),public.update_c010_facility_unit(uuid,uuid,bigint,text,text,text,integer,text,uuid),
 public.set_c010_horse_place(uuid,uuid,uuid,bigint,text,uuid),public.save_c010_facility_booking(uuid,uuid,bigint,uuid,date,time,time,uuid[],integer,text,text,boolean,uuid),
 public.transition_c010_facility_booking(uuid,uuid,bigint,text,text,uuid) to authenticated;

notify pgrst,'reload schema';
commit;
