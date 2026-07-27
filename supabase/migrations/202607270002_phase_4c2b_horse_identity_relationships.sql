begin;

create table public.horse_identifiers (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null,
  horse_id uuid not null,
  identifier_type text not null
    check (
      identifier_type in (
        'chip',
        'passport',
        'registration',
        'studbook',
        'other'
      )
    ),
  identifier_value text not null
    check (length(btrim(identifier_value)) between 1 and 200),
  issuer text
    check (issuer is null or length(btrim(issuer)) between 1 and 200),
  country_code text
    check (
      country_code is null
      or country_code ~ '^[A-Z]{2}$'
    ),
  source_kind text not null default 'user'
    check (source_kind in ('user', 'professional', 'official', 'import')),
  verification_status text not null default 'unverified'
    check (
      verification_status in (
        'unverified',
        'verified',
        'rejected',
        'expired'
      )
    ),
  valid_from date,
  valid_until date,
  row_version bigint not null default 1 check (row_version > 0),
  created_by_user_id uuid not null references auth.users (id),
  created_request_id uuid not null,
  last_mutated_by_user_id uuid not null references auth.users (id),
  last_mutation_request_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint horse_identifiers_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint horse_identifiers_stable_and_id_unique
    unique (stable_id, id),
  constraint horse_identifiers_created_request_unique
    unique (created_by_user_id, created_request_id),
  constraint horse_identifiers_validity_window
    check (valid_until is null or valid_from is null or valid_until >= valid_from)
);

create index horse_identifiers_horse_type
  on public.horse_identifiers (horse_id, identifier_type, id);

create table private.horse_identifier_mutation_receipts (
  actor_user_id uuid not null references auth.users (id),
  request_id uuid not null,
  horse_id uuid not null references public.horses (id),
  identifier_id uuid not null references public.horse_identifiers (id),
  operation text not null check (operation in ('create', 'update')),
  payload_hash bytea not null check (octet_length(payload_hash) = 32),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (actor_user_id, request_id)
);

create table public.horse_relationships (
  id uuid primary key default gen_random_uuid(),
  stable_id uuid not null,
  horse_id uuid not null,
  stable_member_id uuid not null,
  relationship_type text not null
    check (
      relationship_type in (
        'owner',
        'rider',
        'groom',
        'trainer',
        'veterinarian',
        'professional',
        'other'
      )
    ),
  status text not null default 'active'
    check (status in ('active', 'ended')),
  valid_from date not null default current_date,
  valid_until date,
  label text
    check (label is null or length(btrim(label)) between 1 and 160),
  row_version bigint not null default 1 check (row_version > 0),
  created_by_user_id uuid not null references auth.users (id),
  created_request_id uuid not null,
  ended_by_user_id uuid references auth.users (id),
  ended_request_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  ended_at timestamptz,
  constraint horse_relationships_horse_fk
    foreign key (stable_id, horse_id)
    references public.horses (stable_id, id),
  constraint horse_relationships_stable_member_fk
    foreign key (stable_id, stable_member_id)
    references public.stable_members (stable_id, id),
  constraint horse_relationships_stable_and_id_unique
    unique (stable_id, id),
  constraint horse_relationships_created_request_unique
    unique (created_by_user_id, created_request_id),
  constraint horse_relationships_ended_request_unique
    unique (ended_by_user_id, ended_request_id),
  constraint horse_relationships_validity_window
    check (valid_until is null or valid_until >= valid_from),
  constraint horse_relationships_lifecycle
    check (
      (
        status = 'active'
        and ended_by_user_id is null
        and ended_request_id is null
        and ended_at is null
        and valid_until is null
      )
      or (
        status = 'ended'
        and ended_by_user_id is not null
        and ended_request_id is not null
        and ended_at is not null
        and valid_until is not null
      )
    )
);

create unique index horse_relationships_one_active_kind
  on public.horse_relationships (
    horse_id,
    stable_member_id,
    relationship_type
  )
  where status = 'active';

create index horse_relationships_horse_active
  on public.horse_relationships (horse_id, stable_member_id, relationship_type)
  where status = 'active';

create table private.horse_relationship_mutation_receipts (
  actor_user_id uuid not null references auth.users (id),
  request_id uuid not null,
  horse_id uuid not null references public.horses (id),
  relationship_id uuid not null references public.horse_relationships (id),
  stable_member_id uuid not null references public.stable_members (id),
  relationship_type text not null
    check (
      relationship_type in (
        'owner',
        'rider',
        'groom',
        'trainer',
        'veterinarian',
        'professional',
        'other'
      )
    ),
  payload_hash bytea not null check (octet_length(payload_hash) = 32),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (actor_user_id, request_id)
);

create or replace function private.touch_horse_identifier()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.identifier_value := btrim(new.identifier_value);
  new.issuer := nullif(btrim(new.issuer), '');
  new.country_code := nullif(upper(btrim(new.country_code)), '');
  new.updated_at := timezone('utc', pg_catalog.now());
  if tg_op = 'UPDATE' then
    new.row_version := old.row_version + 1;
  end if;
  return new;
end;
$$;

create trigger horse_identifiers_touch_before_write
before insert or update on public.horse_identifiers
for each row execute function private.touch_horse_identifier();

create or replace function private.touch_horse_relationship()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.label := nullif(btrim(new.label), '');
  new.updated_at := timezone('utc', pg_catalog.now());
  if tg_op = 'UPDATE' then
    new.row_version := old.row_version + 1;
  end if;
  return new;
end;
$$;

create trigger horse_relationships_touch_before_write
before insert or update on public.horse_relationships
for each row execute function private.touch_horse_relationship();

create or replace function public.upsert_horse_identifier(
  p_horse_id uuid,
  p_identifier_id uuid,
  p_expected_row_version bigint,
  p_request_id uuid,
  p_identifier_type text,
  p_identifier_value text,
  p_issuer text default null,
  p_country_code text default null,
  p_valid_from date default null,
  p_valid_until date default null
)
returns public.horse_identifiers
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  actor_membership public.stable_memberships%rowtype;
  target_horse public.horses%rowtype;
  target_identifier public.horse_identifiers%rowtype;
  request_receipt private.horse_identifier_mutation_receipts%rowtype;
  result public.horse_identifiers%rowtype;
  normalized_value text := btrim(coalesce(p_identifier_value, ''));
  normalized_issuer text := nullif(btrim(p_issuer), '');
  normalized_country text := nullif(upper(btrim(p_country_code)), '');
  actor_can_edit boolean := false;
  mutation_operation text := case
    when p_identifier_id is null then 'create'
    else 'update'
  end;
  mutation_payload_hash bytea;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if (p_identifier_id is null) <> (p_expected_row_version is null) then
    raise exception using errcode = '22023', message = 'INVALID_UPSERT_MODE';
  end if;
  if p_expected_row_version is not null and p_expected_row_version < 1 then
    raise exception using errcode = '22023', message = 'INVALID_ROW_VERSION';
  end if;
  if p_identifier_type is null
    or p_identifier_type not in (
      'chip',
      'passport',
      'registration',
      'studbook',
      'other'
    )
    or length(normalized_value) not between 1 and 200
    or (
      normalized_issuer is not null
      and length(normalized_issuer) > 200
    )
    or (
      normalized_country is not null
      and normalized_country !~ '^[A-Z]{2}$'
    )
    or (
      p_valid_until is not null
      and p_valid_from is not null
      and p_valid_until < p_valid_from
    )
  then
    raise exception using errcode = '22023', message = 'INVALID_HORSE_IDENTIFIER';
  end if;

  select h.stable_id into target_stable_id
  from public.horses h
  where h.id = p_horse_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  select * into actor_membership
  from public.stable_memberships m
  where m.stable_id = target_stable_id
    and m.user_id = actor_id
    and m.status = 'active'
  for share;
  if actor_membership.id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  perform 1
  from public.horse_access_grants g
  where g.horse_id = p_horse_id
    and g.membership_id = actor_membership.id
    and g.category = 'horse.identity'
    and g.status = 'active'
  order by g.id
  for share;

  select * into target_horse
  from public.horses h
  where h.id = p_horse_id
    and h.stable_id = target_stable_id
  for update;

  actor_can_edit := actor_membership.role = 'owner'
    or exists (
      select 1
      from public.horse_access_grants g
      where g.horse_id = p_horse_id
        and g.membership_id = actor_membership.id
        and g.category = 'horse.identity'
        and g.status = 'active'
        and g.can_edit
        and g.valid_from <= timezone('utc', now())
        and (
          g.valid_until is null
          or g.valid_until > timezone('utc', now())
        )
    );
  if target_horse.id is null
    or target_horse.status <> 'active'
    or not exists (
      select 1
      from public.stables s
      where s.id = target_stable_id
        and s.status = 'active'
    )
  then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;
  if not actor_can_edit then
    raise exception using errcode = '42501', message = 'NOT_AUTHORIZED';
  end if;

  mutation_payload_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'identifier_id', p_identifier_id,
        'identifier_type', p_identifier_type,
        'identifier_value', normalized_value,
        'issuer', normalized_issuer,
        'country_code', normalized_country,
        'valid_from', p_valid_from,
        'valid_until', p_valid_until
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  select * into request_receipt
  from private.horse_identifier_mutation_receipts r
  where r.actor_user_id = actor_id
    and r.request_id = p_request_id;
  if request_receipt.request_id is not null then
    if request_receipt.horse_id = p_horse_id
      and request_receipt.operation = mutation_operation
      and request_receipt.payload_hash = mutation_payload_hash
      and (
        p_identifier_id is null
        or request_receipt.identifier_id = p_identifier_id
      )
    then
      select * into result
      from public.horse_identifiers i
      where i.id = request_receipt.identifier_id
        and i.horse_id = p_horse_id;
      if result.id is not null then
        return result;
      end if;
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;

  if p_identifier_id is null then
    insert into public.horse_identifiers (
      stable_id,
      horse_id,
      identifier_type,
      identifier_value,
      issuer,
      country_code,
      source_kind,
      verification_status,
      valid_from,
      valid_until,
      created_by_user_id,
      created_request_id,
      last_mutated_by_user_id,
      last_mutation_request_id
    )
    values (
      target_stable_id,
      p_horse_id,
      p_identifier_type,
      normalized_value,
      normalized_issuer,
      normalized_country,
      'user',
      'unverified',
      p_valid_from,
      p_valid_until,
      actor_id,
      p_request_id,
      actor_id,
      p_request_id
    )
    returning * into result;
    insert into private.horse_identifier_mutation_receipts (
      actor_user_id,
      request_id,
      horse_id,
      identifier_id,
      operation,
      payload_hash
    )
    values (
      actor_id,
      p_request_id,
      p_horse_id,
      result.id,
      mutation_operation,
      mutation_payload_hash
    );
    return result;
  end if;

  select * into target_identifier
  from public.horse_identifiers i
  where i.id = p_identifier_id
    and i.horse_id = p_horse_id
    and i.stable_id = target_stable_id
  for update;
  if target_identifier.id is null then
    raise exception using errcode = '42501', message = 'IDENTIFIER_UNAVAILABLE';
  end if;
  if target_identifier.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'ROW_VERSION_CONFLICT';
  end if;

  update public.horse_identifiers i
  set
    identifier_type = p_identifier_type,
    identifier_value = normalized_value,
    issuer = normalized_issuer,
    country_code = normalized_country,
    valid_from = p_valid_from,
    valid_until = p_valid_until,
    last_mutated_by_user_id = actor_id,
    last_mutation_request_id = p_request_id
  where i.id = target_identifier.id
  returning * into result;

  insert into private.horse_identifier_mutation_receipts (
    actor_user_id,
    request_id,
    horse_id,
    identifier_id,
    operation,
    payload_hash
  )
  values (
    actor_id,
    p_request_id,
    p_horse_id,
    result.id,
    mutation_operation,
    mutation_payload_hash
  );

  return result;
end;
$$;

create or replace function public.add_horse_relationship(
  p_horse_id uuid,
  p_stable_member_id uuid,
  p_relationship_type text,
  p_request_id uuid,
  p_valid_from date default current_date,
  p_label text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  actor_membership public.stable_memberships%rowtype;
  target_horse public.horses%rowtype;
  target_member public.stable_members%rowtype;
  request_receipt private.horse_relationship_mutation_receipts%rowtype;
  existing_relationship public.horse_relationships%rowtype;
  result public.horse_relationships%rowtype;
  normalized_label text := nullif(btrim(p_label), '');
  mutation_payload_hash bytea;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_relationship_type is null
    or p_relationship_type not in (
      'owner',
      'rider',
      'groom',
      'trainer',
      'veterinarian',
      'professional',
      'other'
    )
    or p_valid_from is null
    or (
      normalized_label is not null
      and length(normalized_label) > 160
    )
  then
    raise exception using errcode = '22023', message = 'INVALID_HORSE_RELATIONSHIP';
  end if;

  select h.stable_id into target_stable_id
  from public.horses h
  where h.id = p_horse_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;

  select * into actor_membership
  from public.stable_memberships m
  where m.stable_id = target_stable_id
    and m.user_id = actor_id
    and m.status = 'active'
    and m.role in ('owner', 'admin')
  for share;
  if actor_membership.id is null then
    raise exception using
      errcode = '42501',
      message = 'RELATIONSHIP_UNAVAILABLE';
  end if;

  select * into target_horse
  from public.horses h
  where h.id = p_horse_id
    and h.stable_id = target_stable_id
  for update;

  select * into target_member
  from public.stable_members sm
  where sm.id = p_stable_member_id
    and sm.stable_id = target_stable_id
  for share;

  if target_horse.id is null
    or target_horse.status <> 'active'
    or not exists (
      select 1
      from public.stables s
      where s.id = target_stable_id
        and s.status = 'active'
    )
  then
    raise exception using errcode = '42501', message = 'HORSE_UNAVAILABLE';
  end if;
  if target_member.id is null or target_member.status <> 'active' then
    raise exception using
      errcode = '42501',
      message = 'STABLE_MEMBER_UNAVAILABLE';
  end if;

  mutation_payload_hash := extensions.digest(
    convert_to(
      jsonb_build_object(
        'horse_id', p_horse_id,
        'stable_member_id', p_stable_member_id,
        'relationship_type', p_relationship_type,
        'valid_from', p_valid_from,
        'label', normalized_label
      )::text,
      'UTF8'
    ),
    'sha256'
  );

  select * into request_receipt
  from private.horse_relationship_mutation_receipts r
  where r.actor_user_id = actor_id
    and r.request_id = p_request_id;
  if request_receipt.request_id is not null then
    if request_receipt.horse_id = p_horse_id
      and request_receipt.stable_member_id = p_stable_member_id
      and request_receipt.relationship_type = p_relationship_type
      and request_receipt.payload_hash = mutation_payload_hash
    then
      select * into result
      from public.horse_relationships r
      where r.id = request_receipt.relationship_id;
      if result.id is null then
        raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
      end if;
      return jsonb_build_object(
        'relationship_id', result.id,
        'row_version', result.row_version,
        'idempotent', true
      );
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;

  select * into existing_relationship
  from public.horse_relationships r
  where r.horse_id = p_horse_id
    and r.stable_member_id = p_stable_member_id
    and r.relationship_type = p_relationship_type
    and r.status = 'active'
  for update;
  if existing_relationship.id is not null then
    if existing_relationship.valid_from = p_valid_from
      and existing_relationship.label is not distinct from normalized_label
    then
      insert into private.horse_relationship_mutation_receipts (
        actor_user_id,
        request_id,
        horse_id,
        relationship_id,
        stable_member_id,
        relationship_type,
        payload_hash
      )
      values (
        actor_id,
        p_request_id,
        p_horse_id,
        existing_relationship.id,
        p_stable_member_id,
        p_relationship_type,
        mutation_payload_hash
      );
      return jsonb_build_object(
        'relationship_id', existing_relationship.id,
        'row_version', existing_relationship.row_version,
        'idempotent', true
      );
    end if;
    raise exception using
      errcode = '23505',
      message = 'RELATIONSHIP_ALREADY_ACTIVE';
  end if;

  insert into public.horse_relationships (
    stable_id,
    horse_id,
    stable_member_id,
    relationship_type,
    valid_from,
    label,
    created_by_user_id,
    created_request_id
  )
  values (
    target_stable_id,
    p_horse_id,
    p_stable_member_id,
    p_relationship_type,
    p_valid_from,
    normalized_label,
    actor_id,
    p_request_id
  )
  returning * into result;

  insert into private.horse_relationship_mutation_receipts (
    actor_user_id,
    request_id,
    horse_id,
    relationship_id,
    stable_member_id,
    relationship_type,
    payload_hash
  )
  values (
    actor_id,
    p_request_id,
    p_horse_id,
    result.id,
    p_stable_member_id,
    p_relationship_type,
    mutation_payload_hash
  );

  return jsonb_build_object(
    'relationship_id', result.id,
    'row_version', result.row_version,
    'idempotent', false
  );
end;
$$;

create or replace function public.end_horse_relationship(
  p_relationship_id uuid,
  p_expected_row_version bigint,
  p_request_id uuid,
  p_valid_until date default current_date
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  target_stable_id uuid;
  actor_membership public.stable_memberships%rowtype;
  target_horse public.horses%rowtype;
  target_relationship public.horse_relationships%rowtype;
  request_relationship public.horse_relationships%rowtype;
begin
  if actor_id is null then
    raise exception using errcode = '42501', message = 'AUTHENTICATION_REQUIRED';
  end if;
  if p_request_id is null then
    raise exception using errcode = '22023', message = 'REQUEST_ID_REQUIRED';
  end if;
  if p_expected_row_version is null
    or p_expected_row_version < 1
    or p_valid_until is null
  then
    raise exception using errcode = '22023', message = 'INVALID_RELATIONSHIP_END';
  end if;

  select r.stable_id into target_stable_id
  from public.horse_relationships r
  where r.id = p_relationship_id;
  if target_stable_id is null then
    raise exception using errcode = '42501', message = 'RELATIONSHIP_UNAVAILABLE';
  end if;

  select * into actor_membership
  from public.stable_memberships m
  where m.stable_id = target_stable_id
    and m.user_id = actor_id
    and m.status = 'active'
    and m.role in ('owner', 'admin')
  for share;
  if actor_membership.id is null then
    raise exception using
      errcode = '42501',
      message = 'RELATIONSHIP_UNAVAILABLE';
  end if;

  select * into target_horse
  from public.horses h
  where h.stable_id = target_stable_id
    and h.id = (
      select r.horse_id
      from public.horse_relationships r
      where r.id = p_relationship_id
    )
  for update;

  select * into target_relationship
  from public.horse_relationships r
  where r.id = p_relationship_id
    and r.stable_id = target_stable_id
  for update;
  if target_horse.id is null
    or target_horse.status <> 'active'
    or target_relationship.id is null
    or not exists (
      select 1
      from public.stables s
      where s.id = target_stable_id
        and s.status = 'active'
    )
  then
    raise exception using errcode = '42501', message = 'RELATIONSHIP_UNAVAILABLE';
  end if;

  select * into request_relationship
  from public.horse_relationships r
  where r.ended_by_user_id = actor_id
    and r.ended_request_id = p_request_id;
  if request_relationship.id is not null then
    if request_relationship.id = p_relationship_id
      and request_relationship.valid_until = p_valid_until
    then
      return true;
    end if;
    raise exception using errcode = '22023', message = 'REQUEST_ID_REUSED';
  end if;
  if target_relationship.status = 'ended' then
    return false;
  end if;
  if target_relationship.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'ROW_VERSION_CONFLICT';
  end if;
  if p_valid_until < target_relationship.valid_from then
    raise exception using errcode = '22023', message = 'INVALID_RELATIONSHIP_END';
  end if;

  update public.horse_relationships r
  set
    status = 'ended',
    valid_until = p_valid_until,
    ended_by_user_id = actor_id,
    ended_request_id = p_request_id,
    ended_at = timezone('utc', now())
  where r.id = target_relationship.id;

  return true;
end;
$$;

alter table public.horse_identifiers enable row level security;
alter table public.horse_relationships enable row level security;

revoke all on table public.horse_identifiers
  from public, anon, authenticated;
revoke all on table public.horse_relationships
  from public, anon, authenticated;
revoke all on table private.horse_identifier_mutation_receipts
  from public, anon, authenticated;
revoke all on table private.horse_relationship_mutation_receipts
  from public, anon, authenticated;

grant select on table public.horse_identifiers to authenticated;
grant select on table public.horse_relationships to authenticated;

create policy horse_identifiers_select_authorized
on public.horse_identifiers for select to authenticated
using (private.has_horse_capability(horse_id, 'horse.identity', 'view'));

create policy horse_relationships_select_authorized
on public.horse_relationships for select to authenticated
using (private.has_horse_capability(horse_id, 'horse.team', 'view'));

revoke all on function private.touch_horse_identifier()
  from public, anon, authenticated;
revoke all on function private.touch_horse_relationship()
  from public, anon, authenticated;

revoke execute on function public.upsert_horse_identifier(
  uuid, uuid, bigint, uuid, text, text, text, text, date, date
) from public, anon;
revoke execute on function public.add_horse_relationship(
  uuid, uuid, text, uuid, date, text
) from public, anon;
revoke execute on function public.end_horse_relationship(
  uuid, bigint, uuid, date
) from public, anon;

grant execute on function public.upsert_horse_identifier(
  uuid, uuid, bigint, uuid, text, text, text, text, date, date
) to authenticated;
grant execute on function public.add_horse_relationship(
  uuid, uuid, text, uuid, date, text
) to authenticated;
grant execute on function public.end_horse_relationship(
  uuid, bigint, uuid, date
) to authenticated;

comment on table public.horse_identifiers is
  'Phase 4C.2B protected Horse identity values. Client writes are RPC-only.';
comment on column public.horse_identifiers.identifier_value is
  'Sensitive identity value; never included in standard Horse lists or errors.';
comment on table public.horse_relationships is
  'Semantic Horse-to-roster relationships. Rows grant no authorization.';
comment on table private.horse_identifier_mutation_receipts is
  'Private payload-hash receipts for durable identifier RPC idempotency.';
comment on table private.horse_relationship_mutation_receipts is
  'Private payload-hash receipts for durable relationship-add idempotency.';
comment on function public.upsert_horse_identifier(
  uuid, uuid, bigint, uuid, text, text, text, text, date, date
) is
  'Creates or optimistically updates an unverified user-supplied Horse identifier.';
comment on function public.add_horse_relationship(
  uuid, uuid, text, uuid, date, text
) is
  'Adds a same-stable semantic relationship; only owner/admin may manage it.';
comment on function public.end_horse_relationship(
  uuid, bigint, uuid, date
) is
  'Optimistically ends a Horse relationship without deleting its history.';

commit;
