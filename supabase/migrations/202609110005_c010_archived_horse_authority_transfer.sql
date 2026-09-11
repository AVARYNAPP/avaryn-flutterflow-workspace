begin;

-- C010 archived-horse primary succession using the existing two-phase transfer.
-- Keep horse status, canonical identity, relations, ownership and history intact.
-- No unarchive, replacement authority, permission grant, legacy rewrite or
-- account-deletion preflight exception. Existing active transfer ABI is retained.

create or replace function public.list_c010_my_archived_horses()
returns table(horse_id uuid,display_name text,archived_at timestamptz,row_version bigint,
  access_version bigint,authority_version bigint,pending_transfer jsonb)
language plpgsql stable security definer set search_path='' as $$
declare actor_id uuid;
begin
  actor_id:=private.c003c_actor_profile_id();
  return query select horse.id,horse.display_name,horse.archived_at,horse.row_version,
    horse.access_version,horse.authority_version,(
      select pg_catalog.jsonb_build_object('id',transfer.id,
        'recipient_name',case when recipient.status='active' then recipient.display_name else 'Niet-actief account' end,
        'status',transfer.status,'expires_at',transfer.expires_at,'row_version',transfer.row_version)
      from public.horse_authority_transfers transfer
      join public.profiles recipient on recipient.id=transfer.recipient_profile_id
      where transfer.horse_id=horse.id and transfer.sender_profile_id=actor_id and transfer.status='pending'
      limit 1
    )
  from public.canonical_horses horse
  where horse.status='archived' and horse.primary_authority_profile_id=actor_id
  order by pg_catalog.lower(horse.display_name),horse.id;
end;
$$;
revoke all on function public.list_c010_my_archived_horses() from public,anon,authenticated,service_role;
grant execute on function public.list_c010_my_archived_horses() to authenticated;
comment on function public.list_c010_my_archived_horses() is
  'Only the active caller''s own archived primary horses and minimal pending-transfer metadata. No additional horse permission or private Auth identity is exposed.';

create or replace function public.initiate_horse_authority_transfer(
  p_horse_id uuid,p_recipient_profile_id uuid,p_correlation_id uuid
)
returns table(transfer_id uuid,transfer_token text,expires_at timestamptz,row_version bigint,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;horse public.canonical_horses%rowtype;prior public.horse_authority_transfers%rowtype;
  pending public.horse_authority_transfers%rowtype;created public.horse_authority_transfers%rowtype;raw_token text;created_time timestamptz;
begin
  actor_id:=private.c003e_actor_profile_id();
  if p_correlation_id is null then raise exception using errcode='22023',message='CORRELATION_ID_REQUIRED';end if;
  -- Keep identity locks before resource locks, also when archival races us.
  -- Archived scalar changes bypass the active-target trigger, so explicitly
  -- serialize both profiles with deletion before gaining a new dependency.
  if exists(select 1 from public.canonical_horses value where value.id=p_horse_id
    and value.status in('active','archived') and value.primary_authority_profile_id=actor_id) then
    perform 1 from public.profiles profile where profile.id in(actor_id,p_recipient_profile_id)
      order by profile.id for update;
    actor_id:=private.c003e_actor_profile_id();
  end if;
  select value.* into horse from public.canonical_horses value where value.id=p_horse_id for update;
  if not found or horse.status not in('active','archived') then raise exception using errcode='P0002',message='ACTIVE_HORSE_NOT_FOUND';end if;
  if horse.primary_authority_profile_id<>actor_id then raise exception using errcode='42501',message='PRIMARY_HORSE_AUTHORITY_REQUIRED';end if;
  select value.* into prior from public.horse_authority_transfers value
    where value.sender_profile_id=actor_id and value.creation_correlation_id=p_correlation_id;
  if found then
    if horse.status='archived' and (prior.horse_id is distinct from p_horse_id
      or prior.recipient_profile_id is distinct from p_recipient_profile_id) then
      raise exception using errcode='22023',message='REQUEST_ID_REUSED';
    end if;
    return query select prior.id,null::text,prior.expires_at,prior.row_version,false;return;
  end if;
  if p_recipient_profile_id=actor_id or not exists(
    select 1 from public.profiles profile where profile.id=p_recipient_profile_id and profile.status='active'
  ) then raise exception using errcode='22023',message='ACTIVE_DISTINCT_RECIPIENT_REQUIRED';end if;
  select value.* into pending from public.horse_authority_transfers value
    where value.horse_id=p_horse_id and value.status='pending' for update;
  if found then
    if pending.expires_at>pg_catalog.statement_timestamp() then
      raise exception using errcode='55000',message='HORSE_TRANSFER_ALREADY_PENDING';
    end if;
    update public.horse_authority_transfers value set status='expired',token_digest=null,
      terminal_reason_code='EXPIRED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
      response_correlation_id=p_correlation_id,row_version=value.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where value.id=pending.id returning * into pending;
    perform private.c003e_write_audit('horse.authority_transfer_expired','horse_authority_transfer',pending.id,
      'horse',p_horse_id,actor_id,p_correlation_id,'HORSE_TRANSFER_EXPIRED','pending','expired',
      pending.row_version-1,pending.row_version,horse.access_version,horse.access_version,
      pg_catalog.jsonb_build_object('target_profile_id',pending.recipient_profile_id::text,'action_code','expire'));
  end if;
  raw_token:=pg_catalog.encode(extensions.gen_random_bytes(32),'hex');created_time:=pg_catalog.clock_timestamp();
  insert into public.horse_authority_transfers(
    horse_id,sender_profile_id,recipient_profile_id,authority_version_at_create,token_digest,
    expires_at,creation_correlation_id,created_at,updated_at
  ) values(p_horse_id,actor_id,p_recipient_profile_id,horse.authority_version,
    private.c003d_token_digest(raw_token),created_time+interval '7 days',p_correlation_id,created_time,created_time)
  returning * into created;
  perform private.c003e_write_audit('horse.authority_transfer_initiated','horse_authority_transfer',created.id,
    'horse',p_horse_id,actor_id,p_correlation_id,'HORSE_TRANSFER_INITIATED',null,'pending',null,created.row_version,
    horse.access_version,horse.access_version,pg_catalog.jsonb_build_object(
      'target_profile_id',p_recipient_profile_id::text,'operation_code','initiate_transfer',
      'authority_version_before',horse.authority_version,'authority_version_after',horse.authority_version));
  return query select created.id,raw_token,created.expires_at,created.row_version,true;
end;
$$;

create or replace function public.initiate_horse_authority_transfer_by_email(
  p_horse_id uuid,p_recipient_email text,p_correlation_id uuid
)
returns table(transfer_id uuid,transfer_token text,expires_at timestamptz,row_version bigint,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;
begin
  actor_id:=private.c003e_actor_profile_id();
  -- Refuse before recipient lookup, without turning email into a directory.
  if not exists(select 1 from public.canonical_horses horse
    where horse.id=p_horse_id and horse.primary_authority_profile_id=actor_id
      and horse.status in('active','archived')) then
    raise exception using errcode='42501',message='PRIMARY_HORSE_AUTHORITY_REQUIRED';
  end if;
  return query select * from public.initiate_horse_authority_transfer(
    p_horse_id,private.c008_target_profile_by_email(p_recipient_email),p_correlation_id
  );
end;
$$;

create or replace function public.respond_horse_authority_transfer(
  p_transfer_token text,p_action text,p_correlation_id uuid
)
returns table(transfer_id uuid,row_version bigint,status text,authority_version bigint,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;resource_id uuid;before_row public.horse_authority_transfers%rowtype;
  after_row public.horse_authority_transfers%rowtype;horse_before public.canonical_horses%rowtype;horse_after public.canonical_horses%rowtype;
begin
  actor_id:=private.c003e_actor_profile_id();
  if p_action is null or p_action not in('accept','decline') then raise exception using errcode='22023',message='TRANSFER_ACTION_INVALID';end if;
  select transfer.horse_id into resource_id from public.horse_authority_transfers transfer
    where transfer.token_digest=private.c003d_token_digest(p_transfer_token);
  if resource_id is null then raise exception using errcode='42501',message='TRANSFER_NOT_AVAILABLE';end if;
  if not exists(select 1 from public.horse_authority_transfers transfer
    where transfer.token_digest=private.c003d_token_digest(p_transfer_token)
      and transfer.recipient_profile_id=actor_id and transfer.status='pending') then
    raise exception using errcode='42501',message='TRANSFER_NOT_AVAILABLE';
  end if;
  perform 1 from public.profiles profile where profile.id in (
    select transfer.sender_profile_id from public.horse_authority_transfers transfer
      where transfer.token_digest=private.c003d_token_digest(p_transfer_token)
    union select transfer.recipient_profile_id from public.horse_authority_transfers transfer
      where transfer.token_digest=private.c003d_token_digest(p_transfer_token)
  ) order by profile.id for update;
  actor_id:=private.c003e_actor_profile_id();
  select value.* into horse_before from public.canonical_horses value where value.id=resource_id for update;
  select transfer.* into before_row from public.horse_authority_transfers transfer
    where transfer.token_digest=private.c003d_token_digest(p_transfer_token) for update;
  if not found or before_row.status<>'pending' or before_row.recipient_profile_id<>actor_id
  then raise exception using errcode='42501',message='TRANSFER_NOT_AVAILABLE';end if;
  if horse_before.status='archived' and exists(select 1 from public.profiles profile
    where profile.id in(before_row.sender_profile_id,before_row.recipient_profile_id) and profile.status<>'active') then
    raise exception using errcode='42501',message='ACTIVE_TARGET_PROFILE_REQUIRED';
  end if;
  if before_row.expires_at<=pg_catalog.statement_timestamp() then
    update public.horse_authority_transfers transfer set status='expired',token_digest=null,
      terminal_reason_code='EXPIRED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
      response_correlation_id=p_correlation_id,row_version=transfer.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where transfer.id=before_row.id returning * into after_row;
    perform private.c003e_write_audit('horse.authority_transfer_expired','horse_authority_transfer',before_row.id,
      'horse',before_row.horse_id,actor_id,p_correlation_id,'HORSE_TRANSFER_EXPIRED','pending','expired',
      before_row.row_version,after_row.row_version,horse_before.access_version,horse_before.access_version,
      pg_catalog.jsonb_build_object('target_profile_id',actor_id::text,'action_code','expire'));
    return query select before_row.id,after_row.row_version,after_row.status,horse_before.authority_version,true;return;
  end if;
  if p_action='decline' then
    update public.horse_authority_transfers transfer set status='declined',token_digest=null,
      terminal_reason_code='DECLINED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
      response_correlation_id=p_correlation_id,row_version=transfer.row_version+1,updated_at=pg_catalog.clock_timestamp()
    where transfer.id=before_row.id returning * into after_row;
    perform private.c003e_write_audit('horse.authority_transfer_declined','horse_authority_transfer',before_row.id,
      'horse',before_row.horse_id,actor_id,p_correlation_id,'HORSE_TRANSFER_DECLINED','pending','declined',
      before_row.row_version,after_row.row_version,horse_before.access_version,horse_before.access_version,
      pg_catalog.jsonb_build_object('target_profile_id',actor_id::text,'action_code','decline'));
    return query select before_row.id,after_row.row_version,after_row.status,horse_before.authority_version,true;return;
  end if;
  if horse_before.primary_authority_profile_id<>before_row.sender_profile_id
    or horse_before.authority_version<>before_row.authority_version_at_create
    or not exists(select 1 from public.profiles profile where profile.id=actor_id and profile.status='active')
  then
    if horse_before.status='archived' then raise exception using errcode='PT409',message='STALE_HORSE_AUTHORITY_VERSION'; end if;
    raise exception using errcode='40001',message='STALE_HORSE_AUTHORITY_VERSION';
  end if;
  update public.canonical_horses horse set primary_authority_profile_id=actor_id,
    authority_version=horse.authority_version+1,access_version=horse.access_version+1,
    row_version=horse.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where horse.id=before_row.horse_id returning * into horse_after;
  update public.profiles profile set access_version=profile.access_version+1
    where profile.id in(before_row.sender_profile_id,before_row.recipient_profile_id);
  update public.horse_authority_transfers transfer set status='accepted',token_digest=null,
    terminal_reason_code='ACCEPTED',terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
    response_correlation_id=p_correlation_id,row_version=transfer.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where transfer.id=before_row.id returning * into after_row;
  perform private.c003e_write_audit('horse.authority_transfer_accepted','horse_authority_transfer',before_row.id,
    'horse',before_row.horse_id,actor_id,p_correlation_id,'HORSE_TRANSFER_ACCEPTED','pending','accepted',
    before_row.row_version,after_row.row_version,horse_before.access_version,horse_after.access_version,
    pg_catalog.jsonb_build_object('target_profile_id',actor_id::text,'action_code','accept',
      'authority_version_before',horse_before.authority_version,'authority_version_after',horse_after.authority_version));
  return query select before_row.id,after_row.row_version,after_row.status,horse_after.authority_version,true;
end;
$$;

create or replace function public.revoke_horse_authority_transfer(
  p_transfer_id uuid,p_expected_row_version bigint,p_correlation_id uuid
)
returns table(row_version bigint,status text,applied boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid;resource_id uuid;before_row public.horse_authority_transfers%rowtype;
  after_row public.horse_authority_transfers%rowtype;horse public.canonical_horses%rowtype;new_status text;event_name text;reason_name text;
begin
  actor_id:=private.c003e_actor_profile_id();
  select transfer.horse_id into resource_id from public.horse_authority_transfers transfer where transfer.id=p_transfer_id;
  if resource_id is null then raise exception using errcode='P0002',message='TRANSFER_NOT_FOUND';end if;
  select value.* into horse from public.canonical_horses value where value.id=resource_id for update;
  select transfer.* into before_row from public.horse_authority_transfers transfer where transfer.id=p_transfer_id for update;
  if before_row.sender_profile_id<>actor_id then raise exception using errcode='42501',message='TRANSFER_SENDER_REQUIRED';end if;
  if before_row.status<>'pending' then return query select before_row.row_version,before_row.status,false;return;end if;
  if before_row.row_version is distinct from p_expected_row_version then
    if horse.status='archived' then raise exception using errcode='PT409',message='STALE_TRANSFER_VERSION'; end if;
    raise exception using errcode='40001',message='STALE_TRANSFER_VERSION';
  end if;
  if before_row.expires_at<=pg_catalog.statement_timestamp() then
    new_status:='expired';event_name:='horse.authority_transfer_expired';reason_name:='HORSE_TRANSFER_EXPIRED';
  else new_status:='revoked';event_name:='horse.authority_transfer_revoked';reason_name:='HORSE_TRANSFER_REVOKED';end if;
  update public.horse_authority_transfers transfer set status=new_status,token_digest=null,
    terminal_reason_code=pg_catalog.upper(new_status),terminal_by_profile_id=actor_id,terminal_at=pg_catalog.clock_timestamp(),
    response_correlation_id=p_correlation_id,row_version=transfer.row_version+1,updated_at=pg_catalog.clock_timestamp()
  where transfer.id=p_transfer_id returning * into after_row;
  perform private.c003e_write_audit(event_name,'horse_authority_transfer',before_row.id,'horse',before_row.horse_id,
    actor_id,p_correlation_id,reason_name,'pending',new_status,before_row.row_version,after_row.row_version,
    horse.access_version,horse.access_version,pg_catalog.jsonb_build_object(
      'target_profile_id',before_row.recipient_profile_id::text,'action_code',new_status));
  return query select after_row.row_version,after_row.status,true;
end;
$$;

comment on function public.respond_horse_authority_transfer(text,text,uuid) is
  'Locks live identities before horse and transfer; exact recipient, expiry and authority CAS; archived horse remains archived without operation grants.';

commit;
