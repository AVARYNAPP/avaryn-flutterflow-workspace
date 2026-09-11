begin;

-- C-010 Human Acceptance Round 1. Generic stable tasks cannot safely reuse
-- schedule_items: that table is legacy-stable scoped and its C-010
-- participants are horse-required. This additive model remains organization
-- scoped and never creates a synthetic stable or grants horse authority.

create table public.stable_facilities (
  organization_id uuid primary key
    references public.organizations(id) on delete restrict,
  box_count integer not null default 0 check(box_count between 0 and 10000),
  pasture_count integer not null default 0 check(pasture_count between 0 and 10000),
  paddock_count integer not null default 0 check(paddock_count between 0 and 10000),
  wash_bay_count integer not null default 0 check(wash_bay_count between 0 and 10000),
  has_walker boolean not null default false,
  walker_count integer not null default 0 check(walker_count between 0 and 1000),
  walker_places_per_unit integer not null default 0
    check(walker_places_per_unit between 0 and 1000),
  has_tack_room boolean not null default false,
  tack_locker_count integer not null default 0
    check(tack_locker_count between 0 and 10000),
  row_version bigint not null default 1 check(row_version>=1),
  created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint stable_facilities_walker_shape check(
    has_walker or(walker_count=0 and walker_places_per_unit=0)
  ),
  constraint stable_facilities_tack_shape check(
    has_tack_room or tack_locker_count=0
  )
);

create table public.stable_places (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  ordinal integer not null check(ordinal between 1 and 10000),
  label text not null check(pg_catalog.length(pg_catalog.btrim(label)) between 1 and 80),
  status text not null default 'active' check(status in('active','archived')),
  row_version bigint not null default 1 check(row_version>=1),
  created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  archived_by_profile_id uuid references public.profiles(id) on delete restrict,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  archived_at timestamptz,
  constraint stable_places_archive_shape check(
    (status='active' and archived_at is null and archived_by_profile_id is null)
    or(status='archived' and archived_at is not null and archived_by_profile_id is not null)
  ),
  unique(organization_id,ordinal),
  unique(organization_id,id)
);

create table public.stable_resource_items (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  category text not null check(category in(
    'concentrate_feed','roughage','supplement','straw','bedding'
  )),
  brand text not null check(pg_catalog.length(pg_catalog.btrim(brand)) between 1 and 160),
  product_name text not null
    check(pg_catalog.length(pg_catalog.btrim(product_name)) between 1 and 240),
  status text not null default 'active' check(status in('active','archived')),
  row_version bigint not null default 1 check(row_version>=1),
  created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  archived_by_profile_id uuid references public.profiles(id) on delete restrict,
  creation_request_id uuid not null,
  terminal_request_id uuid,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  archived_at timestamptz,
  constraint stable_resource_items_archive_shape check(
    (status='active' and archived_at is null and archived_by_profile_id is null and terminal_request_id is null)
    or(status='archived' and archived_at is not null and archived_by_profile_id is not null and terminal_request_id is not null)
  ),
  unique(created_by_profile_id,creation_request_id)
);

create unique index stable_resource_items_active_identity_idx
  on public.stable_resource_items(
    organization_id,category,pg_catalog.lower(brand),pg_catalog.lower(product_name)
  ) where status='active';

create table public.stable_tasks (
  id uuid primary key default extensions.gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete restrict,
  title text not null check(pg_catalog.length(pg_catalog.btrim(title)) between 1 and 180),
  note text check(note is null or pg_catalog.length(note)<=2000),
  category text not null check(category in(
    'feeding','hay','water','pasture','stable_preparation','other'
  )),
  due_date date not null,
  due_time time,
  assignee_profile_id uuid not null references public.profiles(id) on delete restrict,
  location_text text check(
    location_text is null or pg_catalog.length(pg_catalog.btrim(location_text)) between 1 and 160
  ),
  stable_place_id uuid,
  horse_id uuid references public.canonical_horses(id) on delete restrict,
  status text not null default 'open' check(status in('open','completed','cancelled')),
  row_version bigint not null default 1 check(row_version>=1),
  created_by_profile_id uuid not null references public.profiles(id) on delete restrict,
  creation_request_id uuid not null,
  completed_by_profile_id uuid references public.profiles(id) on delete restrict,
  completed_at timestamptz,
  cancelled_by_profile_id uuid references public.profiles(id) on delete restrict,
  cancelled_at timestamptz,
  terminal_request_id uuid,
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  updated_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint stable_tasks_place_fk foreign key(organization_id,stable_place_id)
    references public.stable_places(organization_id,id) on delete restrict,
  constraint stable_tasks_terminal_shape check(
    (status='open' and completed_by_profile_id is null and completed_at is null
      and cancelled_by_profile_id is null and cancelled_at is null and terminal_request_id is null)
    or(status='completed' and completed_by_profile_id is not null and completed_at is not null
      and cancelled_by_profile_id is null and cancelled_at is null and terminal_request_id is not null)
    or(status='cancelled' and cancelled_by_profile_id is not null and cancelled_at is not null
      and completed_by_profile_id is null and completed_at is null and terminal_request_id is not null)
  ),
  unique(created_by_profile_id,creation_request_id),
  unique(organization_id,id)
);

create index stable_tasks_assignee_day_idx
  on public.stable_tasks(assignee_profile_id,due_date,status,organization_id);
create index stable_tasks_organization_day_idx
  on public.stable_tasks(organization_id,due_date,status);
create index stable_tasks_horse_idx on public.stable_tasks(horse_id) where horse_id is not null;

create table public.stable_task_events (
  id uuid primary key default extensions.gen_random_uuid(),
  task_id uuid not null references public.stable_tasks(id) on delete restrict,
  organization_id uuid not null,
  actor_profile_id uuid not null references public.profiles(id) on delete restrict,
  event_type text not null check(event_type in('created','updated','completed','cancelled')),
  correlation_id uuid not null,
  row_version_before bigint,
  row_version_after bigint not null,
  old_status text,
  new_status text not null,
  metadata jsonb not null default '{}'::jsonb check(pg_catalog.jsonb_typeof(metadata)='object'),
  occurred_at timestamptz not null default pg_catalog.clock_timestamp(),
  constraint stable_task_events_task_fk foreign key(organization_id,task_id)
    references public.stable_tasks(organization_id,id) on delete restrict,
  unique(actor_profile_id,correlation_id)
);

create table private.c010_round1_receipts (
  actor_user_id uuid not null references auth.users(id) on delete restrict,
  request_id uuid not null,
  operation_name text not null check(operation_name in(
    'update_facilities','upsert_resource','archive_resource','upsert_task',
    'transition_task','retire_stable'
  )),
  payload_hash bytea not null check(pg_catalog.octet_length(payload_hash)=32),
  result jsonb not null check(pg_catalog.jsonb_typeof(result)='object'),
  created_at timestamptz not null default pg_catalog.clock_timestamp(),
  primary key(actor_user_id,request_id)
);

create or replace function private.c010_round1_receipt_result(
  p_actor_user_id uuid,p_request_id uuid,p_operation_name text,p_payload_hash bytea
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare receipt private.c010_round1_receipts%rowtype;
begin
  select * into receipt from private.c010_round1_receipts value
  where value.actor_user_id=p_actor_user_id and value.request_id=p_request_id;
  if not found then return null; end if;
  if receipt.operation_name<>p_operation_name or receipt.payload_hash<>p_payload_hash then
    raise exception using errcode='22023',message='C010_ROUND1_IDEMPOTENCY_CONFLICT';
  end if;
  return receipt.result||pg_catalog.jsonb_build_object('idempotent',true);
end;
$$;

create or replace function private.c010_round1_active_member(
  p_profile_id uuid,p_organization_id uuid,p_at timestamptz default pg_catalog.statement_timestamp()
)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1 from public.organization_memberships membership
    join public.profiles profile on profile.id=membership.profile_id and profile.status='active'
    join public.organizations organization on organization.id=membership.organization_id and organization.status='active'
    where membership.profile_id=p_profile_id and membership.organization_id=p_organization_id
      and membership.status='active' and membership.valid_from<=p_at
      and(membership.valid_until is null or membership.valid_until>p_at)
  )
$$;

create or replace function private.c010_round1_log_task(
  p_task_id uuid,p_organization_id uuid,p_actor_profile_id uuid,p_event_type text,
  p_correlation_id uuid,p_row_before bigint,p_row_after bigint,
  p_old_status text,p_new_status text,p_metadata jsonb default '{}'::jsonb
)
returns uuid language plpgsql security definer set search_path='' as $$
declare event_id uuid;
begin
  if p_event_type not in('created','updated','completed','cancelled')
    or p_task_id is null or p_organization_id is null or p_actor_profile_id is null
    or p_correlation_id is null or coalesce(p_row_after,0)<1
    or p_metadata is null
  then raise exception using errcode='22023',message='C010_TASK_AUDIT_INPUT_INVALID'; end if;
  insert into public.stable_task_events(
    task_id,organization_id,actor_profile_id,event_type,correlation_id,
    row_version_before,row_version_after,old_status,new_status,metadata
  ) values(
    p_task_id,p_organization_id,p_actor_profile_id,p_event_type,p_correlation_id,
    p_row_before,p_row_after,p_old_status,p_new_status,p_metadata
  ) returning id into event_id;
  return event_id;
end;
$$;

create or replace function private.c010_round1_block_history_change()
returns trigger language plpgsql security definer set search_path='' as $$
begin raise exception using errcode='42501',message='STABLE_TASK_HISTORY_IMMUTABLE'; end;
$$;
create trigger stable_task_events_no_change
before update or delete on public.stable_task_events for each row
execute function private.c010_round1_block_history_change();
create trigger stable_task_events_no_truncate
before truncate on public.stable_task_events for each statement
execute function private.c010_round1_block_history_change();

-- Archived organizations are terminal. Their primary authority identity stays
-- recorded, but active memberships and assignments may be ended safely.
create or replace function private.c003b_assert_primary_admin(p_organization_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare target public.organizations%rowtype;
begin
  select organization.* into target from public.organizations organization
  where organization.id=p_organization_id;
  if not found or target.status='archived' then return; end if;
  if not exists(
    select 1 from public.profiles profile
    join public.organization_memberships membership
      on membership.profile_id=profile.id and membership.organization_id=target.id
    join public.organization_membership_roles assignment
      on assignment.membership_id=membership.id and assignment.organization_id=target.id
    join public.organization_roles role
      on role.id=assignment.role_id and role.organization_id=target.id
    where profile.id=target.primary_admin_profile_id and profile.status='active'
      and membership.status='active' and membership.valid_from<=pg_catalog.clock_timestamp()
      and membership.valid_until is null and assignment.status='active'
      and assignment.valid_from<=pg_catalog.clock_timestamp() and assignment.valid_until is null
      and role.code='head_admin' and role.status='active' and role.is_system and role.is_reserved
  ) then raise exception using errcode='23514',message='PRIMARY_ADMIN_INVARIANT_VIOLATION'; end if;
end;
$$;

create or replace function public.update_c010_stable_facilities(
  p_organization_id uuid,p_expected_row_version bigint,p_box_count integer,
  p_pasture_count integer,p_paddock_count integer,p_wash_bay_count integer,
  p_has_walker boolean,p_walker_count integer,p_walker_places_per_unit integer,
  p_has_tack_room boolean,p_tack_locker_count integer,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; before_row public.stable_facilities%rowtype;
  after_row public.stable_facilities%rowtype; payload_hash bytea; replay jsonb; result jsonb; value integer;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if not private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.edit') then
    raise exception using errcode='42501',message='ORGANIZATION_PERMISSION_REQUIRED'; end if;
  if p_request_id is null or least(p_box_count,p_pasture_count,p_paddock_count,p_wash_bay_count,
      p_walker_count,p_walker_places_per_unit,p_tack_locker_count)<0
    or(not p_has_walker and(p_walker_count<>0 or p_walker_places_per_unit<>0))
    or(not p_has_tack_room and p_tack_locker_count<>0)
  then raise exception using errcode='22023',message='C010_FACILITIES_INPUT_INVALID'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'expected',p_expected_row_version,'box_count',p_box_count,
    'pasture_count',p_pasture_count,'paddock_count',p_paddock_count,'wash_bay_count',p_wash_bay_count,
    'has_walker',p_has_walker,'walker_count',p_walker_count,'walker_places',p_walker_places_per_unit,
    'has_tack_room',p_has_tack_room,'tack_lockers',p_tack_locker_count
  ));
  replay:=private.c010_round1_receipt_result(actor_user,p_request_id,'update_facilities',payload_hash);
  if replay is not null then return replay; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('c010:facilities:'||p_organization_id::text,0));
  perform 1 from public.organizations organization where organization.id=p_organization_id and organization.status='active' for update;
  if not found then raise exception using errcode='P0002',message='ACTIVE_STABLE_NOT_FOUND'; end if;
  select * into before_row from public.stable_facilities facility
    where facility.organization_id=p_organization_id for update;
  if before_row.organization_id is null and p_expected_row_version is not null then
    raise exception using errcode='40001',message='STALE_FACILITIES_VERSION'; end if;
  if before_row.organization_id is not null and before_row.row_version<>p_expected_row_version then
    raise exception using errcode='40001',message='STALE_FACILITIES_VERSION'; end if;
  insert into public.stable_facilities(
    organization_id,box_count,pasture_count,paddock_count,wash_bay_count,
    has_walker,walker_count,walker_places_per_unit,has_tack_room,tack_locker_count,created_by_profile_id
  ) values(
    p_organization_id,p_box_count,p_pasture_count,p_paddock_count,p_wash_bay_count,
    p_has_walker,p_walker_count,p_walker_places_per_unit,p_has_tack_room,p_tack_locker_count,actor_profile
  ) on conflict(organization_id) do update set
    box_count=excluded.box_count,pasture_count=excluded.pasture_count,
    paddock_count=excluded.paddock_count,wash_bay_count=excluded.wash_bay_count,
    has_walker=excluded.has_walker,walker_count=excluded.walker_count,
    walker_places_per_unit=excluded.walker_places_per_unit,
    has_tack_room=excluded.has_tack_room,tack_locker_count=excluded.tack_locker_count,
    row_version=public.stable_facilities.row_version+1,updated_at=pg_catalog.clock_timestamp()
  returning * into after_row;
  if p_box_count>0 then
    for value in 1..p_box_count loop
      insert into public.stable_places(organization_id,ordinal,label,created_by_profile_id)
      values(p_organization_id,value,'Stal '||value,actor_profile)
      on conflict(organization_id,ordinal) do update set
        status='active',archived_at=null,archived_by_profile_id=null,
        row_version=public.stable_places.row_version+1,updated_at=pg_catalog.clock_timestamp();
    end loop;
  end if;
  if exists(
    select 1 from public.stable_places place
    join public.stable_tasks task on task.stable_place_id=place.id
    where place.organization_id=p_organization_id and place.status='active' and place.ordinal>p_box_count
  ) then raise exception using errcode='23503',message='STABLE_PLACE_HAS_HISTORY'; end if;
  update public.stable_places place set status='archived',archived_at=pg_catalog.clock_timestamp(),
    archived_by_profile_id=actor_profile,row_version=place.row_version+1,
    updated_at=pg_catalog.clock_timestamp()
  where place.organization_id=p_organization_id and place.status='active' and place.ordinal>p_box_count;
  perform private.c003b_write_audit(
    'organization.updated','organization',p_organization_id,p_organization_id,actor_profile,p_request_id,
    'ORGANIZATION_UPDATED','active','active',null,null,null,null,
    pg_catalog.jsonb_build_object('operation_code','c010_update_facilities')
  );
  result:=pg_catalog.jsonb_build_object('organization_id',p_organization_id,'row_version',after_row.row_version,
    'box_count',after_row.box_count,'idempotent',false);
  insert into private.c010_round1_receipts(actor_user_id,request_id,operation_name,payload_hash,result)
  values(actor_user,p_request_id,'update_facilities',payload_hash,result);
  return result;
end;
$$;

create or replace function public.upsert_c010_stable_resource(
  p_organization_id uuid,p_resource_id uuid,p_expected_row_version bigint,
  p_category text,p_brand text,p_product_name text,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea; replay jsonb;
  before_row public.stable_resource_items%rowtype; after_row public.stable_resource_items%rowtype; result jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if not private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.edit') then
    raise exception using errcode='42501',message='ORGANIZATION_PERMISSION_REQUIRED'; end if;
  if p_request_id is null or p_category not in('concentrate_feed','roughage','supplement','straw','bedding')
    or pg_catalog.length(pg_catalog.btrim(coalesce(p_brand,''))) not between 1 and 160
    or pg_catalog.length(pg_catalog.btrim(coalesce(p_product_name,''))) not between 1 and 240
  then raise exception using errcode='22023',message='C010_RESOURCE_INPUT_INVALID'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'resource_id',p_resource_id,'expected',p_expected_row_version,
    'category',p_category,'brand',pg_catalog.btrim(p_brand),'product',pg_catalog.btrim(p_product_name)
  ));
  replay:=private.c010_round1_receipt_result(actor_user,p_request_id,'upsert_resource',payload_hash);
  if replay is not null then return replay; end if;
  if p_resource_id is null then
    insert into public.stable_resource_items(
      organization_id,category,brand,product_name,created_by_profile_id,creation_request_id
    ) values(p_organization_id,p_category,pg_catalog.btrim(p_brand),pg_catalog.btrim(p_product_name),actor_profile,p_request_id)
    returning * into after_row;
  else
    select * into before_row from public.stable_resource_items value
      where value.id=p_resource_id and value.organization_id=p_organization_id for update;
    if before_row.id is null then raise exception using errcode='42501',message='CROSS_STABLE_RESOURCE_DENIED'; end if;
    if before_row.status<>'active' or before_row.row_version<>p_expected_row_version then
      raise exception using errcode='40001',message='STALE_RESOURCE_VERSION'; end if;
    update public.stable_resource_items value set category=p_category,brand=pg_catalog.btrim(p_brand),
      product_name=pg_catalog.btrim(p_product_name),row_version=value.row_version+1,
      updated_at=pg_catalog.clock_timestamp() where value.id=p_resource_id returning * into after_row;
  end if;
  result:=pg_catalog.jsonb_build_object('resource_id',after_row.id,'row_version',after_row.row_version,'idempotent',false);
  insert into private.c010_round1_receipts(actor_user_id,request_id,operation_name,payload_hash,result)
  values(actor_user,p_request_id,'upsert_resource',payload_hash,result);
  return result;
end;
$$;

create or replace function public.archive_c010_stable_resource(
  p_organization_id uuid,p_resource_id uuid,p_expected_row_version bigint,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea; replay jsonb;
  before_row public.stable_resource_items%rowtype; after_row public.stable_resource_items%rowtype; result jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if not private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.edit') then
    raise exception using errcode='42501',message='ORGANIZATION_PERMISSION_REQUIRED'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'resource_id',p_resource_id,'expected',p_expected_row_version
  ));
  replay:=private.c010_round1_receipt_result(actor_user,p_request_id,'archive_resource',payload_hash);
  if replay is not null then return replay; end if;
  select * into before_row from public.stable_resource_items value
    where value.id=p_resource_id and value.organization_id=p_organization_id for update;
  if before_row.id is null then raise exception using errcode='42501',message='CROSS_STABLE_RESOURCE_DENIED'; end if;
  if before_row.status='archived' then
    result:=pg_catalog.jsonb_build_object('resource_id',before_row.id,'row_version',before_row.row_version,'idempotent',true);
    return result;
  end if;
  if before_row.row_version<>p_expected_row_version then
    raise exception using errcode='40001',message='STALE_RESOURCE_VERSION'; end if;
  update public.stable_resource_items value set status='archived',archived_by_profile_id=actor_profile,
    archived_at=pg_catalog.clock_timestamp(),terminal_request_id=p_request_id,
    row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where value.id=p_resource_id returning * into after_row;
  result:=pg_catalog.jsonb_build_object('resource_id',after_row.id,'row_version',after_row.row_version,'status','archived','idempotent',false);
  insert into private.c010_round1_receipts(actor_user_id,request_id,operation_name,payload_hash,result)
  values(actor_user,p_request_id,'archive_resource',payload_hash,result);
  return result;
end;
$$;

create or replace function public.upsert_c010_stable_task(
  p_organization_id uuid,p_task_id uuid,p_expected_row_version bigint,p_title text,p_note text,
  p_category text,p_due_date date,p_due_time time,p_assignee_profile_id uuid,p_location_text text,
  p_stable_place_id uuid,p_horse_id uuid,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea; replay jsonb;
  before_row public.stable_tasks%rowtype; after_row public.stable_tasks%rowtype; result jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if not(private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.planning.execute')
    and private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.memberships.view'))
  then raise exception using errcode='42501',message='STABLE_TASK_MANAGE_PERMISSION_REQUIRED'; end if;
  if p_request_id is null or pg_catalog.length(pg_catalog.btrim(coalesce(p_title,''))) not between 1 and 180
    or p_category not in('feeding','hay','water','pasture','stable_preparation','other') or p_due_date is null
    or not private.c010_round1_active_member(p_assignee_profile_id,p_organization_id)
  then raise exception using errcode='22023',message='C010_TASK_INPUT_INVALID'; end if;
  if p_stable_place_id is not null and not exists(
    select 1 from public.stable_places place where place.id=p_stable_place_id
      and place.organization_id=p_organization_id and place.status='active'
  ) then raise exception using errcode='42501',message='CROSS_STABLE_PLACE_DENIED'; end if;
  if p_horse_id is not null and not(
    exists(select 1 from public.horse_residencies residency where residency.horse_id=p_horse_id
      and residency.stable_organization_id=p_organization_id and residency.status='active')
    and private.c003c_profile_has_horse_permission(actor_profile,p_horse_id,'horse.view')
    and private.c003c_profile_has_horse_permission(p_assignee_profile_id,p_horse_id,'horse.view')
  ) then raise exception using errcode='42501',message='CROSS_STABLE_HORSE_DENIED'; end if;
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'task_id',p_task_id,'expected',p_expected_row_version,
    'title',pg_catalog.btrim(p_title),'note',nullif(pg_catalog.btrim(p_note),''),'category',p_category,
    'due_date',p_due_date,'due_time',p_due_time,'assignee',p_assignee_profile_id,
    'location',nullif(pg_catalog.btrim(p_location_text),''),'place',p_stable_place_id,'horse',p_horse_id
  ));
  replay:=private.c010_round1_receipt_result(actor_user,p_request_id,'upsert_task',payload_hash);
  if replay is not null then return replay; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('c010:tasks:'||p_organization_id::text,0));
  if p_task_id is null then
    insert into public.stable_tasks(
      organization_id,title,note,category,due_date,due_time,assignee_profile_id,
      location_text,stable_place_id,horse_id,created_by_profile_id,creation_request_id
    ) values(
      p_organization_id,pg_catalog.btrim(p_title),nullif(pg_catalog.btrim(p_note),''),p_category,
      p_due_date,p_due_time,p_assignee_profile_id,nullif(pg_catalog.btrim(p_location_text),''),
      p_stable_place_id,p_horse_id,actor_profile,p_request_id
    ) returning * into after_row;
    perform private.c010_round1_log_task(after_row.id,p_organization_id,actor_profile,'created',p_request_id,
      null,after_row.row_version,null,after_row.status,pg_catalog.jsonb_build_object('category',after_row.category));
  else
    select * into before_row from public.stable_tasks value
      where value.id=p_task_id and value.organization_id=p_organization_id for update;
    if before_row.id is null then raise exception using errcode='42501',message='CROSS_STABLE_TASK_DENIED'; end if;
    if before_row.status<>'open' or before_row.row_version<>p_expected_row_version then
      raise exception using errcode='40001',message='STALE_TASK_VERSION'; end if;
    update public.stable_tasks value set title=pg_catalog.btrim(p_title),note=nullif(pg_catalog.btrim(p_note),''),
      category=p_category,due_date=p_due_date,due_time=p_due_time,assignee_profile_id=p_assignee_profile_id,
      location_text=nullif(pg_catalog.btrim(p_location_text),''),stable_place_id=p_stable_place_id,
      horse_id=p_horse_id,row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where value.id=p_task_id returning * into after_row;
    perform private.c010_round1_log_task(after_row.id,p_organization_id,actor_profile,'updated',p_request_id,
      before_row.row_version,after_row.row_version,before_row.status,after_row.status,
      pg_catalog.jsonb_build_object('category',after_row.category));
  end if;
  result:=pg_catalog.jsonb_build_object('task_id',after_row.id,'row_version',after_row.row_version,
    'status',after_row.status,'idempotent',false);
  insert into private.c010_round1_receipts(actor_user_id,request_id,operation_name,payload_hash,result)
  values(actor_user,p_request_id,'upsert_task',payload_hash,result);
  return result;
end;
$$;

create or replace function public.transition_c010_stable_task(
  p_organization_id uuid,p_task_id uuid,p_expected_row_version bigint,p_action text,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; payload_hash bytea; replay jsonb;
  before_row public.stable_tasks%rowtype; after_row public.stable_tasks%rowtype; result jsonb; event_name text;
begin
  actor_profile:=private.c003b_actor_profile_id();
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'task_id',p_task_id,'expected',p_expected_row_version,'action',p_action
  ));
  replay:=private.c010_round1_receipt_result(actor_user,p_request_id,'transition_task',payload_hash);
  if replay is not null then return replay; end if;
  select * into before_row from public.stable_tasks value
    where value.id=p_task_id and value.organization_id=p_organization_id for update;
  if before_row.id is null then raise exception using errcode='42501',message='CROSS_STABLE_TASK_DENIED'; end if;
  if before_row.status<>'open' or before_row.row_version<>p_expected_row_version then
    raise exception using errcode='40001',message='STALE_TASK_VERSION'; end if;
  if p_action='complete' then
    if before_row.assignee_profile_id<>actor_profile
      or not private.c010_round1_active_member(actor_profile,p_organization_id)
      or not private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.planning.execute')
    then raise exception using errcode='42501',message='TASK_COMPLETION_PERMISSION_REQUIRED'; end if;
    event_name:='completed';
  elsif p_action='cancel' then
    if not(private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.planning.execute')
      and private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.memberships.view'))
    then raise exception using errcode='42501',message='STABLE_TASK_MANAGE_PERMISSION_REQUIRED'; end if;
    event_name:='cancelled';
  else raise exception using errcode='22023',message='TASK_ACTION_INVALID'; end if;
  update public.stable_tasks value set status=event_name,
    completed_by_profile_id=case when event_name='completed' then actor_profile end,
    completed_at=case when event_name='completed' then pg_catalog.clock_timestamp() end,
    cancelled_by_profile_id=case when event_name='cancelled' then actor_profile end,
    cancelled_at=case when event_name='cancelled' then pg_catalog.clock_timestamp() end,
    terminal_request_id=p_request_id,row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where value.id=p_task_id returning * into after_row;
  perform private.c010_round1_log_task(after_row.id,p_organization_id,actor_profile,event_name,p_request_id,
    before_row.row_version,after_row.row_version,before_row.status,after_row.status,'{}');
  result:=pg_catalog.jsonb_build_object('task_id',after_row.id,'row_version',after_row.row_version,
    'status',after_row.status,'idempotent',false);
  insert into private.c010_round1_receipts(actor_user_id,request_id,operation_name,payload_hash,result)
  values(actor_user,p_request_id,'transition_task',payload_hash,result);
  return result;
end;
$$;

create or replace function public.list_c010_stable_activities(
  p_organization_id uuid,p_from timestamptz,p_through timestamptz,p_scope text default 'all'
)
returns table(
  activity_kind text,activity_id uuid,title text,note text,category text,
  scheduled_at timestamptz,due_date date,due_time time,status text,row_version bigint,
  horse_id uuid,horse_name text,location_name text,assignee_profile_id uuid,
  assignee_name text,is_mine boolean,can_complete boolean,stable_place_id uuid
)
language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if p_scope not in('mine','all') or p_from is null or p_through is null or p_through<p_from
    or p_through>p_from+interval '1 year'
  then raise exception using errcode='22023',message='C010_ACTIVITY_PERIOD_INVALID'; end if;
  if not private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.planning.view') then
    raise exception using errcode='42501',message='ORGANIZATION_PERMISSION_REQUIRED'; end if;
  return query
  select 'stable_task'::text,task.id,task.title,task.note,task.category,
    (task.due_date::timestamp+coalesce(task.due_time,'00:00'::time)) at time zone 'Europe/Amsterdam',
    task.due_date,task.due_time,task.status,task.row_version,task.horse_id,horse.display_name,
    coalesce(place.label,task.location_text),task.assignee_profile_id,assignee.display_name,
    task.assignee_profile_id=actor_profile,
    task.assignee_profile_id=actor_profile and task.status='open'
      and private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.planning.execute'),
    task.stable_place_id
  from public.stable_tasks task
  join public.profiles assignee on assignee.id=task.assignee_profile_id
  left join public.canonical_horses horse on horse.id=task.horse_id
  left join public.stable_places place on place.id=task.stable_place_id
  where task.organization_id=p_organization_id
    and task.due_date between (p_from at time zone 'Europe/Amsterdam')::date
      and (p_through at time zone 'Europe/Amsterdam')::date
    and(p_scope='all' or task.assignee_profile_id=actor_profile)
    and(task.horse_id is null or private.c003c_profile_has_horse_permission(actor_profile,task.horse_id,'horse.view'))
  union all
  select 'horse_activity'::text,item.id,item.title,item.instruction,item.item_kind,
    item.scheduled_start_at,item.scheduled_start_at::date,item.scheduled_start_at::time,item.state,
    item.row_version,horse.id,horse.display_name,null::text,null::uuid,
    coalesce((select pg_catalog.string_agg(profile.display_name,', ' order by profile.display_name)
      from public.schedule_item_participants participant join public.profiles profile on profile.id=participant.profile_id
      where participant.schedule_item_id=item.id and participant.status='active'),'')::text,
    exists(select 1 from public.schedule_item_participants participant where participant.schedule_item_id=item.id
      and participant.profile_id=actor_profile and participant.status='active'),false,null::uuid
  from public.horse_residencies residency
  join public.canonical_horses horse on horse.id=residency.horse_id
  join public.schedule_items item on item.horse_id=horse.id
  where residency.stable_organization_id=p_organization_id and residency.status='active'
    and item.scheduled_start_at<p_through and coalesce(item.scheduled_end_at,item.scheduled_start_at)>=p_from
    and private.c003c_profile_has_horse_permission(actor_profile,horse.id,'horse.view')
    and(p_scope='all' or exists(select 1 from public.schedule_item_participants participant
      where participant.schedule_item_id=item.id and participant.profile_id=actor_profile and participant.status='active'))
  order by 6,2;
end;
$$;

create or replace function public.list_c010_personal_today(p_on_date date)
returns table(
  task_id uuid,organization_id uuid,organization_name text,title text,note text,
  category text,due_date date,due_time time,location_name text,horse_id uuid,
  horse_name text,row_version bigint,can_complete boolean
)
language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if p_on_date is null then raise exception using errcode='22023',message='TASK_DATE_REQUIRED'; end if;
  return query
  select task.id,organization.id,organization.name,task.title,task.note,task.category,
    task.due_date,task.due_time,coalesce(place.label,task.location_text),task.horse_id,
    horse.display_name,task.row_version,
    private.c003b_profile_has_permission(actor_profile,organization.id,'organization.planning.execute')
  from public.stable_tasks task
  join public.organizations organization on organization.id=task.organization_id and organization.status='active'
  join public.organization_memberships membership on membership.organization_id=task.organization_id
    and membership.profile_id=actor_profile and membership.status='active'
    and membership.valid_from<=pg_catalog.statement_timestamp()
    and(membership.valid_until is null or membership.valid_until>pg_catalog.statement_timestamp())
  left join public.stable_places place on place.id=task.stable_place_id
  left join public.canonical_horses horse on horse.id=task.horse_id
  where task.assignee_profile_id=actor_profile and task.due_date=p_on_date and task.status='open'
    and private.c003b_profile_has_permission(actor_profile,organization.id,'organization.planning.view')
    and(task.horse_id is null or private.c003c_profile_has_horse_permission(actor_profile,task.horse_id,'horse.view'))
  order by pg_catalog.lower(organization.name),task.due_time nulls last,task.id;
end;
$$;

create or replace function public.get_c010_stable_round1_workspace(
  p_organization_id uuid,p_on_date date,p_scope text default 'all'
)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor_profile uuid; can_edit boolean; can_team boolean; result jsonb;
begin
  actor_profile:=private.c003b_actor_profile_id();
  if not private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.view') then
    raise exception using errcode='42501',message='ORGANIZATION_PERMISSION_REQUIRED'; end if;
  can_edit:=private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.edit');
  can_team:=private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.memberships.view');
  select pg_catalog.jsonb_build_object(
    'facilities',coalesce((select pg_catalog.to_jsonb(facility)-'created_by_profile_id'
      from public.stable_facilities facility where facility.organization_id=p_organization_id),'{}'::jsonb),
    'places',coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',place.id,'ordinal',place.ordinal,'label',place.label,'status',place.status,'row_version',place.row_version
    ) order by place.ordinal) from public.stable_places place
      where place.organization_id=p_organization_id and place.status='active'),'[]'::jsonb),
    'resources',coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'id',resource.id,'category',resource.category,'brand',resource.brand,
      'product_name',resource.product_name,'row_version',resource.row_version
    ) order by resource.category,pg_catalog.lower(resource.brand),pg_catalog.lower(resource.product_name))
      from public.stable_resource_items resource where resource.organization_id=p_organization_id
        and resource.status='active'),'[]'::jsonb),
    'activities',coalesce((select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(activity) order by activity.scheduled_at,activity.activity_id)
      from public.list_c010_stable_activities(
        p_organization_id,p_on_date::timestamp at time zone 'Europe/Amsterdam',
        (p_on_date+1)::timestamp at time zone 'Europe/Amsterdam',p_scope
      ) activity),'[]'::jsonb),
    'task_candidates',case when can_team then coalesce((select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
      'profile_id',membership.profile_id,'display_name',profile.display_name
    ) order by pg_catalog.lower(profile.display_name),membership.profile_id)
      from public.organization_memberships membership join public.profiles profile on profile.id=membership.profile_id
      where membership.organization_id=p_organization_id and membership.status='active'
        and membership.valid_from<=pg_catalog.statement_timestamp()
        and(membership.valid_until is null or membership.valid_until>pg_catalog.statement_timestamp())
        and profile.status='active'),'[]'::jsonb) else '[]'::jsonb end,
    'can_edit_facilities',can_edit,
    'can_manage_tasks',can_team and private.c003b_profile_has_permission(
      actor_profile,p_organization_id,'organization.planning.execute'),
    'can_retire',can_edit and exists(select 1 from public.organizations organization
      where organization.id=p_organization_id and organization.primary_admin_profile_id=actor_profile)
  ) into result;
  return result;
end;
$$;

create or replace function public.list_c010_horses_for_stable(p_organization_id uuid)
returns table(
  horse_id uuid,display_name text,official_name text,birth_date date,sex text,
  breed text,discipline text,level text,color text,notes text,chip_number text,
  passport_number text,passport_valid_until date,profile_media_asset_id uuid,
  lifecycle_status text,access_version bigint,authority_version bigint,row_version bigint,
  is_primary_authority boolean,can_edit boolean,can_manage boolean,
  can_manage_planning boolean,can_manage_feeding boolean,can_assign boolean,
  can_share boolean,can_transfer boolean,legacy_stable_id uuid
)
language sql stable security definer set search_path='' as $$
  select horse.horse_id,horse.display_name,horse.official_name,horse.birth_date,horse.sex,
    horse.breed,horse.discipline,horse.level,horse.color,horse.notes,horse.chip_number,
    horse.passport_number,horse.passport_valid_until,horse.profile_media_asset_id,
    horse.lifecycle_status,horse.access_version,horse.authority_version,horse.row_version,
    horse.is_primary_authority,horse.can_edit,horse.can_manage,horse.can_manage_planning,
    horse.can_manage_feeding,horse.can_assign,horse.can_share,horse.can_transfer,horse.legacy_stable_id
  from public.list_c010_horses() horse
  join public.horse_residencies residency on residency.horse_id=horse.horse_id
  where residency.stable_organization_id=p_organization_id and residency.status='active'
    and private.c003b_profile_has_permission(
      private.current_profile_id(),p_organization_id,'organization.view',pg_catalog.statement_timestamp()
    )
  order by pg_catalog.lower(horse.display_name),horse.horse_id
$$;

create or replace function public.retire_c010_stable(
  p_organization_id uuid,p_expected_row_version bigint,p_confirmed_name text,p_request_id uuid
)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor_user uuid:=auth.uid(); actor_profile uuid; organization public.organizations%rowtype;
  after_row public.organizations%rowtype; payload_hash bytea; replay jsonb; result jsonb; now_at timestamptz;
begin
  actor_profile:=private.c003b_actor_profile_id(); now_at:=pg_catalog.clock_timestamp();
  payload_hash:=private.schedule_payload_hash(pg_catalog.jsonb_build_object(
    'organization_id',p_organization_id,'expected',p_expected_row_version,
    'confirmed_name',pg_catalog.btrim(p_confirmed_name)
  ));
  replay:=private.c010_round1_receipt_result(actor_user,p_request_id,'retire_stable',payload_hash);
  if replay is not null then return replay; end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('c010:retire:'||p_organization_id::text,0));
  select * into organization from public.organizations value where value.id=p_organization_id for update;
  if organization.id is null then raise exception using errcode='P0002',message='STABLE_NOT_FOUND'; end if;
  if organization.primary_admin_profile_id<>actor_profile
    or not private.c003b_profile_has_permission(actor_profile,p_organization_id,'organization.edit')
  then raise exception using errcode='42501',message='PRIMARY_ORGANIZATION_ADMIN_REQUIRED'; end if;
  if organization.status<>'active' or organization.row_version<>p_expected_row_version then
    raise exception using errcode='40001',message='STALE_STABLE_VERSION'; end if;
  if pg_catalog.btrim(p_confirmed_name)<>organization.name then
    raise exception using errcode='22023',message='STABLE_NAME_CONFIRMATION_REQUIRED'; end if;
  update public.organizations value set status='archived',archived_at=now_at,
    access_version=value.access_version+1,row_version=value.row_version+1,updated_at=now_at
  where value.id=p_organization_id returning * into after_row;
  update public.organization_membership_roles assignment set status='ended',valid_until=greatest(now_at,assignment.valid_from+interval '1 microsecond'),
    ended_reason_code='membership_ended',revoked_by_profile_id=actor_profile,
    row_version=assignment.row_version+1,updated_at=now_at
  where assignment.organization_id=p_organization_id and assignment.status='active';
  update public.organization_memberships membership set status='ended',
    valid_until=greatest(now_at,membership.valid_from+interval '1 microsecond'),ended_reason_code='organization_closed',
    row_version=membership.row_version+1,updated_at=now_at
  where membership.organization_id=p_organization_id and membership.status in('active','suspended');
  update public.horse_residencies residency set status='ended',
    valid_until=greatest(now_at,residency.valid_from+interval '1 microsecond'),
    row_version=residency.row_version+1,updated_at=now_at
  where residency.stable_organization_id=p_organization_id and residency.status in('active','planned');
  update public.organization_horse_links link set status='ended',ended_at=now_at,
    row_version=link.row_version+1,updated_at=now_at
  where link.organization_id=p_organization_id and link.status in('active','proposed');
  insert into public.stable_task_events(
    task_id,organization_id,actor_profile_id,event_type,correlation_id,
    row_version_before,row_version_after,old_status,new_status,metadata
  ) select task.id,task.organization_id,actor_profile,'cancelled',
    private.schedule_derived_request_id(p_request_id,task.id::text),
    task.row_version,task.row_version+1,task.status,'cancelled',
    pg_catalog.jsonb_build_object('reason','stable_retired')
  from public.stable_tasks task
  where task.organization_id=p_organization_id and task.status='open';
  update public.stable_tasks task set status='cancelled',cancelled_by_profile_id=actor_profile,
    cancelled_at=now_at,terminal_request_id=private.schedule_derived_request_id(p_request_id,task.id::text),
    row_version=task.row_version+1,updated_at=now_at
  where task.organization_id=p_organization_id and task.status='open';
  update public.stable_places place set status='archived',archived_by_profile_id=actor_profile,
    archived_at=now_at,row_version=place.row_version+1,updated_at=now_at
  where place.organization_id=p_organization_id and place.status='active';
  update public.stable_resource_items resource set status='archived',archived_by_profile_id=actor_profile,
    archived_at=now_at,terminal_request_id=private.schedule_derived_request_id(p_request_id,resource.id::text),
    row_version=resource.row_version+1,updated_at=now_at
  where resource.organization_id=p_organization_id and resource.status='active';
  perform private.c003b_write_audit(
    'organization.updated','organization',p_organization_id,p_organization_id,actor_profile,p_request_id,
    'ORGANIZATION_UPDATED','active','archived',organization.row_version,after_row.row_version,
    organization.access_version,after_row.access_version,
    pg_catalog.jsonb_build_object('operation_code','c010_retire_stable')
  );
  result:=pg_catalog.jsonb_build_object('organization_id',p_organization_id,'status','archived',
    'row_version',after_row.row_version,'access_version',after_row.access_version,'idempotent',false);
  insert into private.c010_round1_receipts(actor_user_id,request_id,operation_name,payload_hash,result)
  values(actor_user,p_request_id,'retire_stable',payload_hash,result);
  return result;
end;
$$;

alter table public.stable_facilities enable row level security;
alter table public.stable_places enable row level security;
alter table public.stable_resource_items enable row level security;
alter table public.stable_tasks enable row level security;
alter table public.stable_task_events enable row level security;

create policy stable_facilities_read on public.stable_facilities for select to authenticated
using(public.has_organization_permission(organization_id,'organization.view'));
create policy stable_places_read on public.stable_places for select to authenticated
using(public.has_organization_permission(organization_id,'organization.view'));
create policy stable_resource_items_read on public.stable_resource_items for select to authenticated
using(public.has_organization_permission(organization_id,'organization.view'));
create policy stable_tasks_read on public.stable_tasks for select to authenticated using(
  (assignee_profile_id=private.current_profile_id() and exists(
    select 1 from public.organization_memberships membership
    where membership.organization_id=stable_tasks.organization_id
      and membership.profile_id=private.current_profile_id()
      and membership.status='active' and membership.valid_from<=pg_catalog.statement_timestamp()
      and(membership.valid_until is null or membership.valid_until>pg_catalog.statement_timestamp())
  ))
  or public.has_organization_permission(organization_id,'organization.planning.view')
);
create policy stable_task_events_read on public.stable_task_events for select to authenticated using(
  exists(select 1 from public.stable_tasks task where task.id=task_id and(
    (task.assignee_profile_id=private.current_profile_id() and exists(
      select 1 from public.organization_memberships membership
      where membership.organization_id=task.organization_id
        and membership.profile_id=private.current_profile_id()
        and membership.status='active' and membership.valid_from<=pg_catalog.statement_timestamp()
        and(membership.valid_until is null or membership.valid_until>pg_catalog.statement_timestamp())
    ))
    or public.has_organization_permission(task.organization_id,'organization.planning.view')
  ))
);

revoke all on table public.stable_facilities,public.stable_places,
  public.stable_resource_items,public.stable_tasks,public.stable_task_events
  from public,anon,authenticated,service_role;
grant select on table public.stable_facilities,public.stable_places,
  public.stable_resource_items,public.stable_tasks,public.stable_task_events to authenticated;
revoke all on table private.c010_round1_receipts from public,anon,authenticated,service_role;

revoke all on function private.c010_round1_receipt_result(uuid,uuid,text,bytea),
  private.c010_round1_active_member(uuid,uuid,timestamptz),
  private.c010_round1_log_task(uuid,uuid,uuid,text,uuid,bigint,bigint,text,text,jsonb),
  private.c010_round1_block_history_change()
  from public,anon,authenticated,service_role;

revoke all on function public.update_c010_stable_facilities(uuid,bigint,integer,integer,integer,integer,boolean,integer,integer,boolean,integer,uuid),
  public.upsert_c010_stable_resource(uuid,uuid,bigint,text,text,text,uuid),
  public.archive_c010_stable_resource(uuid,uuid,bigint,uuid),
  public.upsert_c010_stable_task(uuid,uuid,bigint,text,text,text,date,time,uuid,text,uuid,uuid,uuid),
  public.transition_c010_stable_task(uuid,uuid,bigint,text,uuid),
  public.list_c010_stable_activities(uuid,timestamptz,timestamptz,text),
  public.list_c010_personal_today(date),
  public.get_c010_stable_round1_workspace(uuid,date,text),
  public.list_c010_horses_for_stable(uuid),
  public.retire_c010_stable(uuid,bigint,text,uuid)
  from public,anon,authenticated,service_role;

grant execute on function public.update_c010_stable_facilities(uuid,bigint,integer,integer,integer,integer,boolean,integer,integer,boolean,integer,uuid),
  public.upsert_c010_stable_resource(uuid,uuid,bigint,text,text,text,uuid),
  public.archive_c010_stable_resource(uuid,uuid,bigint,uuid),
  public.upsert_c010_stable_task(uuid,uuid,bigint,text,text,text,date,time,uuid,text,uuid,uuid,uuid),
  public.transition_c010_stable_task(uuid,uuid,bigint,text,uuid),
  public.list_c010_stable_activities(uuid,timestamptz,timestamptz,text),
  public.list_c010_personal_today(date),
  public.get_c010_stable_round1_workspace(uuid,date,text),
  public.list_c010_horses_for_stable(uuid),
  public.retire_c010_stable(uuid,bigint,text,uuid)
  to authenticated;

commit;
