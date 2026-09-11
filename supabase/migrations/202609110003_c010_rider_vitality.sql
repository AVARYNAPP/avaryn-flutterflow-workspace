begin;

-- Personal, owner-only C010 Vitality days. No horse/team permissions, Auth UUID,
-- medical interpretation, shared performance data or text-bearing audit event.
-- A content-free tombstone keeps CAS monotonic after a user deletes a day.
create table private.c010_vitality_days (
  profile_id uuid not null references public.profiles(id) on delete restrict,
  on_date date not null check(isfinite(on_date)),
  document jsonb,
  row_version bigint not null check(row_version>0),
  updated_at timestamptz not null default clock_timestamp(),
  primary key(profile_id,on_date)
);
create table private.c010_vitality_receipts (
  profile_id uuid not null references public.profiles(id) on delete restrict,
  request_id uuid not null,
  on_date date not null,
  operation text not null check(operation in('save','delete')),
  payload_hash bytea not null check(octet_length(payload_hash)=32),
  result jsonb not null,
  created_at timestamptz not null default clock_timestamp(),
  primary key(profile_id,request_id)
);
alter table private.c010_vitality_days enable row level security;
alter table private.c010_vitality_receipts enable row level security;
revoke all on private.c010_vitality_days,private.c010_vitality_receipts
  from public,anon,authenticated,service_role;

create function private.c010v_actor(p_write boolean default false) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid;
begin
  if p_write then
    select p.id into actor from public.profiles p join auth.users a on a.id=p.auth_user_id
    where p.auth_user_id=auth.uid() and p.status='active' for update of p;
  else
    select p.id into actor from public.profiles p join auth.users a on a.id=p.auth_user_id
    where p.auth_user_id=auth.uid() and p.status='active';
  end if;
  if actor is null then raise exception using errcode='42501',message='ACTIVE_PROFILE_REQUIRED';end if;
  return actor;
end;$$;

create function private.c010v_steps_valid(p_steps jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
declare item jsonb; seen jsonb:='[]';
begin
  if p_steps is null or jsonb_typeof(p_steps)<>'array' then return false;end if;
  if jsonb_array_length(p_steps)>5 then return false;end if;
  for item in select value from jsonb_array_elements(p_steps) loop
    if jsonb_typeof(item)<>'number' or item::text !~ '^[0-4]$'
      or seen @> jsonb_build_array(item) then return false;end if;
    seen:=seen||jsonb_build_array(item);
  end loop;
  return true;
end;$$;

create function private.c010v_document(p_document jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare d jsonb; w jsonb; r jsonb; routines jsonb; item record; value jsonb; field text;
begin
  if p_document is null or jsonb_typeof(p_document)<>'object'
    or octet_length(p_document::text)>8192
    or p_document-array['warmup','reflection','focus','routines']<>'{}'::jsonb then
    raise exception using errcode='22023',message='C010_VITALITY_DOCUMENT_INVALID';
  end if;
  d:='{"warmup":null,"reflection":null,"focus":"","routines":{}}'::jsonb||p_document;
  if jsonb_typeof(d->'focus')<>'string' or length(d->>'focus')>500 then
    raise exception using errcode='22023',message='C010_VITALITY_DOCUMENT_INVALID';end if;
  w:=d->'warmup';r:=d->'reflection';routines:=d->'routines';
  if w<>'null'::jsonb then
    if jsonb_typeof(w)<>'object' or w-array['minutes','status','steps']<>'{}'::jsonb
      or not coalesce(w->'minutes' in('5'::jsonb,'10'::jsonb),false)
      or not coalesce(w->>'status' in('done','later','skipped'),false)
      or not private.c010v_steps_valid(w->'steps') then
      raise exception using errcode='22023',message='C010_VITALITY_DOCUMENT_INVALID';end if;
    if w->>'status'='done' and jsonb_array_length(w->'steps')<>5 then
      raise exception using errcode='22023',message='C010_VITALITY_DOCUMENT_INVALID';end if;
  end if;
  if r<>'null'::jsonb then
    if jsonb_typeof(r)<>'object' or r-array['person','horse','focus','sharingIntent']<>'{}'::jsonb then
      raise exception using errcode='22023',message='C010_VITALITY_DOCUMENT_INVALID';end if;
    r:='{"person":"","horse":"","focus":"","sharingIntent":"private"}'::jsonb||r;
    foreach field in array array['person','horse'] loop
      if jsonb_typeof(r->field)<>'string' or not coalesce(r->>field in('','Rustig','Energiek','Gespannen','Moe','Sterk'),false) then
        raise exception using errcode='22023',message='C010_VITALITY_DOCUMENT_INVALID';end if;
    end loop;
    if jsonb_typeof(r->'focus')<>'string' or length(r->>'focus')>500
      or not coalesce(r->>'sharingIntent' in('private','later'),false) then
      raise exception using errcode='22023',message='C010_VITALITY_DOCUMENT_INVALID';end if;
    d:=jsonb_set(d,'{reflection}',r);
  end if;
  if jsonb_typeof(routines)<>'object' or routines-array['basic','extended','dressage']<>'{}'::jsonb then
    raise exception using errcode='22023',message='C010_VITALITY_DOCUMENT_INVALID';end if;
  for item in select * from jsonb_each(routines) loop
    value:=item.value;
    if jsonb_typeof(value)<>'object' or value-array['currentStep','completed','status']<>'{}'::jsonb
      or not coalesce(jsonb_typeof(value->'currentStep')='number' and (value->'currentStep')::text ~ '^[0-4]$',false)
      or not private.c010v_steps_valid(value->'completed')
      or not coalesce(value->>'status' in('in_progress','later','done'),false) then
      raise exception using errcode='22023',message='C010_VITALITY_DOCUMENT_INVALID';end if;
    if value->>'status'='done' and jsonb_array_length(value->'completed')<>5 then
      raise exception using errcode='22023',message='C010_VITALITY_DOCUMENT_INVALID';end if;
  end loop;
  return d;
end;$$;
alter table private.c010_vitality_days add constraint c010_vitality_document_valid
  check(document is null or document=private.c010v_document(document));

create function public.get_c010_my_vitality_day(p_on_date date default null) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.c010v_actor(false);calendar jsonb;day date;r private.c010_vitality_days%rowtype;
begin
  calendar:=public.get_c010_calendar_context();day:=coalesce(p_on_date,(calendar->>'today_date')::date);
  if not isfinite(day) then raise exception using errcode='22023',message='C010_VITALITY_DATE_INVALID';end if;
  select * into r from private.c010_vitality_days where profile_id=actor and on_date=day;
  return jsonb_build_object('profile_id',actor,'on_date',day,'calendar',calendar,
    'document',coalesce(r.document,private.c010v_document('{}'::jsonb)),
    'row_version',coalesce(r.row_version,0),'exists',r.document is not null);
end;$$;

create function private.c010v_mutate(p_on_date date,p_expected_row_version bigint,
  p_document jsonb,p_request_id uuid,p_delete boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.c010v_actor(true);r private.c010_vitality_days%rowtype;
  receipt private.c010_vitality_receipts%rowtype;d jsonb;payload jsonb;hash bytea;result jsonb;
  operation text:=case when p_delete then 'delete' else 'save' end;
begin
  -- This actor/profile lock precedes receipt lookup and all writes. Deletion
  -- takes the same profile lock before changing status or erasing this data.
  if p_on_date is null or not isfinite(p_on_date) then
    raise exception using errcode='22023',message='C010_VITALITY_DATE_INVALID';end if;
  if p_request_id is null then raise exception using errcode='22023',message='C010_REQUEST_ID_REQUIRED';end if;
  if p_expected_row_version is null or p_expected_row_version<0 then
    raise exception using errcode='22023',message='C010_VITALITY_VERSION_REQUIRED';end if;
  d:=case when p_delete then null else private.c010v_document(p_document) end;
  payload:=jsonb_build_object('on_date',p_on_date,'expected',p_expected_row_version,'document',d,'operation',operation);
  hash:=private.schedule_payload_hash(payload);
  select * into receipt from private.c010_vitality_receipts where profile_id=actor and request_id=p_request_id;
  if found then
    if receipt.operation<>operation or receipt.payload_hash<>hash then
      raise exception using errcode='22023',message='C010_VITALITY_IDEMPOTENCY_CONFLICT';end if;
    return receipt.result||jsonb_build_object('applied',false,'idempotent',true);
  end if;
  select * into r from private.c010_vitality_days where profile_id=actor and on_date=p_on_date for update;
  if coalesce(r.row_version,0)<>p_expected_row_version then
    raise exception using errcode='PT409',message='C010_VITALITY_VERSION_STALE';end if;
  insert into private.c010_vitality_days(profile_id,on_date,document,row_version)
  values(actor,p_on_date,d,1)
  on conflict(profile_id,on_date) do update set document=excluded.document,
    row_version=private.c010_vitality_days.row_version+1,updated_at=clock_timestamp()
  returning * into r;
  if p_delete then
    -- No previous content hash or response survives an explicit day deletion.
    delete from private.c010_vitality_receipts where profile_id=actor and on_date=p_on_date;
  end if;
  result:=jsonb_build_object('on_date',p_on_date,'row_version',r.row_version,'exists',not p_delete,'applied',true,'idempotent',false);
  insert into private.c010_vitality_receipts(profile_id,request_id,on_date,operation,payload_hash,result)
  values(actor,p_request_id,p_on_date,operation,hash,result);
  return result;
end;$$;

create function public.save_c010_my_vitality_day(p_on_date date,p_expected_row_version bigint,p_document jsonb,p_request_id uuid)
returns jsonb language sql security definer set search_path='' as $$
  select private.c010v_mutate(p_on_date,p_expected_row_version,p_document,p_request_id,false)
$$;
create function public.delete_c010_my_vitality_day(p_on_date date,p_expected_row_version bigint,p_request_id uuid)
returns jsonb language sql security definer set search_path='' as $$
  select private.c010v_mutate(p_on_date,p_expected_row_version,null,p_request_id,true)
$$;

create function private.c010v_erase_on_deactivation() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if old.status='active' and new.status<>'active' then
    delete from private.c010_vitality_receipts where profile_id=new.id;
    delete from private.c010_vitality_days where profile_id=new.id;
  end if;
  return new;
end;$$;
create trigger c010v_personal_data_lifecycle after update of status on public.profiles
  for each row execute function private.c010v_erase_on_deactivation();

revoke all on function private.c010v_actor(boolean),private.c010v_steps_valid(jsonb),private.c010v_document(jsonb),
  private.c010v_mutate(date,bigint,jsonb,uuid,boolean),private.c010v_erase_on_deactivation()
  from public,anon,authenticated,service_role;
revoke all on function public.get_c010_my_vitality_day(date),public.save_c010_my_vitality_day(date,bigint,jsonb,uuid),
  public.delete_c010_my_vitality_day(date,bigint,uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_c010_my_vitality_day(date),public.save_c010_my_vitality_day(date,bigint,jsonb,uuid),
  public.delete_c010_my_vitality_day(date,bigint,uuid) to authenticated;

comment on table private.c010_vitality_days is 'Personal owner-only day content, erased on deletion preparation; no sharing or medical interpretation. Null document is only a monotonic CAS tombstone.';
comment on table private.c010_vitality_receipts is 'Private retry metadata only; no reflection/focus text, no Auth UUID; erased for day deletion and account deactivation.';
comment on function public.get_c010_my_vitality_day(date) is 'Actorless personal day; existing Europe/Amsterdam calendar. Missing day has row_version 0; a deleted day retains its version.';
commit;
