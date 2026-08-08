begin;

-- C-008 keeps the C-003C canonical aggregate authoritative and adds only the
-- profile/product projection and the backward-safe bridge required by the
-- still stable-scoped Planning, Feeding and media modules.

alter table public.canonical_horses
  add column official_name text,
  add column discipline text,
  add column level text,
  add column color text,
  add column notes text,
  add column chip_number text,
  add column passport_number text,
  add column passport_valid_until date,
  add column profile_media_asset_id uuid references public.media_assets(id) on delete restrict,
  add constraint canonical_horses_official_name_check
    check (official_name is null or pg_catalog.length(pg_catalog.btrim(official_name)) between 1 and 200),
  add constraint canonical_horses_discipline_check
    check (discipline is null or pg_catalog.length(pg_catalog.btrim(discipline)) between 1 and 120),
  add constraint canonical_horses_level_check
    check (level is null or pg_catalog.length(pg_catalog.btrim(level)) between 1 and 120),
  add constraint canonical_horses_color_check
    check (color is null or pg_catalog.length(pg_catalog.btrim(color)) between 1 and 120),
  add constraint canonical_horses_notes_check
    check (notes is null or pg_catalog.length(pg_catalog.btrim(notes)) between 1 and 2000),
  add constraint canonical_horses_chip_number_check
    check (chip_number is null or pg_catalog.length(pg_catalog.btrim(chip_number)) between 1 and 200),
  add constraint canonical_horses_passport_number_check
    check (passport_number is null or pg_catalog.length(pg_catalog.btrim(passport_number)) between 1 and 200);

alter table public.horses add column canonical_horse_id uuid;

-- A legacy horse is migrated only when its maker still has an active profile,
-- or, for older imported data, when the stable has one unambiguous active
-- owner with an active profile. Missing authority aborts the complete migration.
do $$
begin
  if exists (
    select 1
    from public.horses legacy_horse
    left join public.profiles creator_profile
      on creator_profile.auth_user_id = legacy_horse.created_by_user_id
     and creator_profile.status = 'active'
    left join public.stable_memberships owner_membership
      on owner_membership.stable_id = legacy_horse.stable_id
     and owner_membership.role = 'owner'
     and owner_membership.status = 'active'
    left join public.profiles owner_profile
      on owner_profile.auth_user_id = owner_membership.user_id
     and owner_profile.status = 'active'
    where legacy_horse.canonical_horse_id is null
      and creator_profile.id is null
      and owner_profile.id is null
  ) then
    raise exception using
      errcode = '23514',
      message = 'C008_LEGACY_HORSE_AUTHORITY_UNRESOLVED';
  end if;

  if exists (
    select 1
    from public.horses legacy_horse
    join public.canonical_horses canonical_horse on canonical_horse.id = legacy_horse.id
    where legacy_horse.canonical_horse_id is null
  ) then
    raise exception using
      errcode = '23505',
      message = 'C008_CANONICAL_HORSE_ID_COLLISION';
  end if;
end;
$$;

insert into public.canonical_horses (
  id,
  primary_authority_profile_id,
  display_name,
  official_name,
  birth_date,
  sex,
  breed,
  discipline,
  level,
  profile_media_asset_id,
  status,
  access_version,
  authority_version,
  row_version,
  created_by_profile_id,
  creation_correlation_id,
  created_at,
  updated_at,
  archived_at
)
select
  legacy_horse.id,
  coalesce(creator_profile.id, owner_profile.id),
  legacy_horse.display_name,
  legacy_horse.official_name,
  legacy_horse.birth_date,
  legacy_horse.sex,
  legacy_horse.breed,
  legacy_horse.discipline,
  legacy_horse.level,
  legacy_horse.profile_media_asset_id,
  legacy_horse.status,
  1,
  1,
  1,
  coalesce(creator_profile.id, owner_profile.id),
  legacy_horse.created_request_id,
  legacy_horse.created_at,
  legacy_horse.updated_at,
  legacy_horse.archived_at
from public.horses legacy_horse
left join public.profiles creator_profile
  on creator_profile.auth_user_id = legacy_horse.created_by_user_id
 and creator_profile.status = 'active'
left join public.stable_memberships owner_membership
  on owner_membership.stable_id = legacy_horse.stable_id
 and owner_membership.role = 'owner'
 and owner_membership.status = 'active'
left join public.profiles owner_profile
  on owner_profile.auth_user_id = owner_membership.user_id
 and owner_profile.status = 'active'
where legacy_horse.canonical_horse_id is null;

insert into public.audit_events (
  actor_kind,
  actor_profile_id,
  system_actor_code,
  event_type,
  resource_kind,
  resource_id,
  scope_kind,
  scope_id,
  old_state,
  new_state,
  reason_code,
  correlation_id,
  channel,
  row_version_before,
  row_version_after,
  access_version_before,
  access_version_after,
  metadata
)
select
  'system',
  null,
  'profile_maintenance',
  'horse.created',
  'horse',
  legacy_horse.id,
  'horse',
  legacy_horse.id,
  '{}'::jsonb,
  pg_catalog.jsonb_build_object('status', legacy_horse.status),
  'HORSE_CREATED',
  legacy_horse.created_request_id,
  'migration',
  null,
  1,
  null,
  1,
  pg_catalog.jsonb_build_object('operation_code', 'c008_legacy_bridge')
from public.horses legacy_horse
where legacy_horse.canonical_horse_id is null;

update public.horses legacy_horse
set canonical_horse_id = legacy_horse.id
where legacy_horse.canonical_horse_id is null;

alter table public.horses
  alter column canonical_horse_id set not null,
  add constraint horses_canonical_horse_id_unique unique (canonical_horse_id),
  add constraint horses_canonical_horse_id_fkey
    foreign key (canonical_horse_id)
    references public.canonical_horses(id)
    on delete restrict,
  add constraint horses_canonical_identity_check check (canonical_horse_id = id);

create index canonical_horses_active_name_idx
  on public.canonical_horses (status, pg_catalog.lower(display_name), id);

-- Every future legacy horse created by the retained Planning/Feeding adapter
-- receives the same UUID in the canonical aggregate. The authenticated maker,
-- never the stable, is the initial primary Horse Authority.
create or replace function private.c008_bridge_legacy_horse_before_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  maker_profile_id uuid;
begin
  if new.id is null then
    new.id := extensions.gen_random_uuid();
  end if;
  if new.canonical_horse_id is not null and new.canonical_horse_id <> new.id then
    raise exception using errcode = '22023', message = 'C008_CANONICAL_ID_MISMATCH';
  end if;
  select profile.id into maker_profile_id
  from public.profiles profile
  where profile.auth_user_id = new.created_by_user_id
    and profile.status = 'active';
  if maker_profile_id is null then
    raise exception using errcode = '42501', message = 'ACTIVE_HORSE_MAKER_PROFILE_REQUIRED';
  end if;
  if exists (select 1 from public.canonical_horses horse where horse.id = new.id) then
    raise exception using errcode = '23505', message = 'C008_CANONICAL_HORSE_ALREADY_EXISTS';
  end if;

  insert into public.canonical_horses (
    id, primary_authority_profile_id, display_name, official_name, birth_date,
    sex, breed, discipline, level, profile_media_asset_id, status,
    created_by_profile_id, creation_correlation_id, created_at, updated_at,
    archived_at
  ) values (
    new.id, maker_profile_id, new.display_name, new.official_name,
    new.birth_date, new.sex, new.breed, new.discipline, new.level,
    new.profile_media_asset_id, new.status, maker_profile_id,
    new.created_request_id, new.created_at, new.updated_at, new.archived_at
  );
  update public.profiles profile
    set access_version = profile.access_version + 1
    where profile.id = maker_profile_id;
  perform private.c003c_write_audit(
    'horse.created', 'horse', new.id, new.id, maker_profile_id,
    new.created_request_id, 'HORSE_CREATED', null, new.status, null, 1, null, 1,
    pg_catalog.jsonb_build_object('operation_code', 'create_legacy_bridge')
  );
  new.canonical_horse_id := new.id;
  return new;
end;
$$;

create trigger c008_horses_canonical_bridge_before_insert
before insert on public.horses
for each row execute function private.c008_bridge_legacy_horse_before_insert();

-- C-003E remains the only authority-transfer route. Its guard is expanded so
-- a transfer transaction cannot smuggle any new profile field mutation.
create or replace function private.c003c_guard_horse_authority()
returns trigger language plpgsql set search_path = '' as $$
declare authority_changed boolean;
begin
  authority_changed := new.primary_authority_profile_id is distinct from old.primary_authority_profile_id;
  if new.id is distinct from old.id
    or new.created_by_profile_id is distinct from old.created_by_profile_id
    or new.creation_correlation_id is distinct from old.creation_correlation_id
    or new.created_at is distinct from old.created_at
  then raise exception using errcode = '42501', message = 'HORSE_AUTHORITY_IDENTITY_IMMUTABLE'; end if;
  if authority_changed then
    if new.authority_version <> old.authority_version + 1
      or new.access_version <> old.access_version + 1
      or new.row_version <> old.row_version + 1
      or row(
        new.display_name,new.official_name,new.birth_date,new.sex,new.breed,
        new.discipline,new.level,new.color,new.notes,new.chip_number,
        new.passport_number,new.passport_valid_until,new.profile_media_asset_id,
        new.status,new.archived_at
      ) is distinct from row(
        old.display_name,old.official_name,old.birth_date,old.sex,old.breed,
        old.discipline,old.level,old.color,old.notes,old.chip_number,
        old.passport_number,old.passport_valid_until,old.profile_media_asset_id,
        old.status,old.archived_at
      )
      or not exists (
        select 1 from public.horse_authority_transfers transfer
        where transfer.horse_id = old.id
          and transfer.sender_profile_id = old.primary_authority_profile_id
          and transfer.recipient_profile_id = new.primary_authority_profile_id
          and transfer.status = 'pending'
          and transfer.authority_version_at_create = old.authority_version
      )
    then raise exception using errcode = '42501', message = 'HORSE_AUTHORITY_TRANSFER_REQUIRED'; end if;
  elsif new.authority_version is distinct from old.authority_version
    or new.access_version not in (old.access_version, old.access_version + 1)
    or new.row_version <> old.row_version + 1
  then raise exception using errcode = '22023', message = 'HORSE_VERSION_TRANSITION_INVALID'; end if;
  return new;
end;
$$;

create or replace function private.c008_normalize_optional(p_value text)
returns text language sql immutable set search_path = '' as $$
  select nullif(pg_catalog.btrim(p_value), '')
$$;

create or replace function public.create_canonical_horse_profile(
  p_display_name text,
  p_official_name text,
  p_birth_date date,
  p_sex text,
  p_breed text,
  p_discipline text,
  p_level text,
  p_color text,
  p_notes text,
  p_chip_number text,
  p_passport_number text,
  p_passport_valid_until date,
  p_correlation_id uuid
)
returns table (
  horse_id uuid,
  access_version bigint,
  authority_version bigint,
  row_version bigint,
  result_code text,
  applied boolean
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  existing public.canonical_horses%rowtype;
  created public.canonical_horses%rowtype;
begin
  actor_id := private.c003c_actor_profile_id();
  if p_correlation_id is null then
    raise exception using errcode = '22023', message = 'CORRELATION_ID_REQUIRED';
  end if;
  select horse.* into existing
  from public.canonical_horses horse
  where horse.created_by_profile_id = actor_id
    and horse.creation_correlation_id = p_correlation_id;
  if found then
    return query select existing.id, existing.access_version,
      existing.authority_version, existing.row_version,
      'idempotent_replay'::text, false;
    return;
  end if;
  insert into public.canonical_horses (
    primary_authority_profile_id, display_name, official_name, birth_date, sex,
    breed, discipline, level, color, notes, chip_number, passport_number,
    passport_valid_until, created_by_profile_id, creation_correlation_id
  ) values (
    actor_id, pg_catalog.btrim(p_display_name), private.c008_normalize_optional(p_official_name),
    p_birth_date, coalesce(p_sex, 'unknown'), private.c008_normalize_optional(p_breed),
    private.c008_normalize_optional(p_discipline), private.c008_normalize_optional(p_level),
    private.c008_normalize_optional(p_color), private.c008_normalize_optional(p_notes),
    private.c008_normalize_optional(p_chip_number), private.c008_normalize_optional(p_passport_number),
    p_passport_valid_until, actor_id, p_correlation_id
  ) returning * into created;
  update public.profiles profile set access_version = profile.access_version + 1
    where profile.id = actor_id;
  perform private.c003c_write_audit(
    'horse.created','horse',created.id,created.id,actor_id,p_correlation_id,
    'HORSE_CREATED',null,created.status,null,created.row_version,null,
    created.access_version,
    pg_catalog.jsonb_build_object('operation_code','create_canonical_horse_profile')
  );
  return query select created.id, created.access_version,
    created.authority_version, created.row_version, 'created'::text, true;
end;
$$;

create or replace function public.update_canonical_horse_profile(
  p_horse_id uuid,
  p_expected_row_version bigint,
  p_display_name text,
  p_official_name text,
  p_birth_date date,
  p_sex text,
  p_breed text,
  p_discipline text,
  p_level text,
  p_color text,
  p_notes text,
  p_chip_number text,
  p_passport_number text,
  p_passport_valid_until date,
  p_status text,
  p_correlation_id uuid
)
returns table (row_version bigint, status text, applied boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  before_row public.canonical_horses%rowtype;
  after_row public.canonical_horses%rowtype;
begin
  actor_id := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_id,p_horse_id,'horse.edit');
  select horse.* into before_row from public.canonical_horses horse
    where horse.id = p_horse_id for update;
  if not found then raise exception using errcode = 'P0002', message = 'CANONICAL_HORSE_NOT_FOUND'; end if;
  if before_row.row_version <> p_expected_row_version then
    raise exception using errcode = '40001', message = 'STALE_HORSE_VERSION';
  end if;
  if p_status not in ('active','archived') then
    raise exception using errcode = '22023', message = 'HORSE_STATUS_INVALID';
  end if;
  update public.canonical_horses horse set
    display_name = pg_catalog.btrim(p_display_name),
    official_name = private.c008_normalize_optional(p_official_name),
    birth_date = p_birth_date,
    sex = coalesce(p_sex,'unknown'),
    breed = private.c008_normalize_optional(p_breed),
    discipline = private.c008_normalize_optional(p_discipline),
    level = private.c008_normalize_optional(p_level),
    color = private.c008_normalize_optional(p_color),
    notes = private.c008_normalize_optional(p_notes),
    chip_number = private.c008_normalize_optional(p_chip_number),
    passport_number = private.c008_normalize_optional(p_passport_number),
    passport_valid_until = p_passport_valid_until,
    status = p_status,
    archived_at = case when p_status = 'archived'
      then coalesce(horse.archived_at,pg_catalog.clock_timestamp()) else null end,
    row_version = horse.row_version + 1,
    updated_at = pg_catalog.clock_timestamp()
  where horse.id = p_horse_id
  returning * into after_row;
  perform private.c003c_write_audit(
    'horse.updated','horse',p_horse_id,p_horse_id,actor_id,p_correlation_id,
    'HORSE_UPDATED',before_row.status,after_row.status,before_row.row_version,
    after_row.row_version,before_row.access_version,after_row.access_version,
    pg_catalog.jsonb_build_object(
      'changed_fields',array['profile_fields','status'],
      'operation_code','update_canonical_horse_profile'
    )
  );
  return query select after_row.row_version, after_row.status, true;
end;
$$;

create or replace function private.c008_sync_canonical_profile_to_legacy()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.horses legacy_horse set
    display_name = new.display_name,
    official_name = new.official_name,
    birth_date = new.birth_date,
    sex = new.sex,
    breed = new.breed,
    discipline = new.discipline,
    level = new.level,
    profile_media_asset_id = new.profile_media_asset_id,
    status = new.status,
    archived_at = new.archived_at
  where legacy_horse.canonical_horse_id = new.id;
  return new;
end;
$$;

create trigger c008_canonical_profile_after_update
after update of display_name,official_name,birth_date,sex,breed,discipline,level,
  profile_media_asset_id,status,archived_at
on public.canonical_horses
for each row
when (row(
  old.display_name,old.official_name,old.birth_date,old.sex,old.breed,
  old.discipline,old.level,old.profile_media_asset_id,old.status,old.archived_at
) is distinct from row(
  new.display_name,new.official_name,new.birth_date,new.sex,new.breed,
  new.discipline,new.level,new.profile_media_asset_id,new.status,new.archived_at
))
execute function private.c008_sync_canonical_profile_to_legacy();

create or replace function public.list_canonical_horses()
returns table (
  horse_id uuid,
  display_name text,
  official_name text,
  birth_date date,
  sex text,
  breed text,
  discipline text,
  level text,
  color text,
  notes text,
  chip_number text,
  passport_number text,
  passport_valid_until date,
  profile_media_asset_id uuid,
  lifecycle_status text,
  access_version bigint,
  authority_version bigint,
  row_version bigint,
  is_primary_authority boolean,
  can_edit boolean,
  can_manage boolean,
  can_assign boolean,
  can_share boolean,
  can_transfer boolean,
  legacy_stable_id uuid
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    horse.id,
    horse.display_name,
    horse.official_name,
    horse.birth_date,
    horse.sex,
    horse.breed,
    horse.discipline,
    horse.level,
    horse.color,
    horse.notes,
    horse.chip_number,
    horse.passport_number,
    horse.passport_valid_until,
    horse.profile_media_asset_id,
    horse.status,
    horse.access_version,
    horse.authority_version,
    horse.row_version,
    horse.primary_authority_profile_id = private.current_profile_id(),
    private.c003c_profile_has_horse_permission(private.current_profile_id(),horse.id,'horse.edit',pg_catalog.statement_timestamp()),
    private.c003c_profile_has_horse_permission(private.current_profile_id(),horse.id,'horse.manage',pg_catalog.statement_timestamp()),
    private.c003c_profile_has_horse_permission(private.current_profile_id(),horse.id,'horse.assign',pg_catalog.statement_timestamp()),
    private.c003c_profile_has_horse_permission(private.current_profile_id(),horse.id,'horse.share',pg_catalog.statement_timestamp()),
    private.c003c_profile_has_horse_permission(private.current_profile_id(),horse.id,'horse.transfer',pg_catalog.statement_timestamp()),
    legacy_horse.stable_id
  from public.canonical_horses horse
  left join public.horses legacy_horse on legacy_horse.canonical_horse_id = horse.id
  where private.c003c_profile_has_horse_permission(
    private.current_profile_id(),horse.id,'horse.view',pg_catalog.statement_timestamp()
  )
  order by pg_catalog.lower(horse.display_name),horse.id
$$;

create or replace function public.get_canonical_horse_workspace(p_horse_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor_id uuid;
  result jsonb;
begin
  actor_id := private.c003c_actor_profile_id();
  perform private.c003c_require_permission(actor_id,p_horse_id,'horse.view');
  select pg_catalog.jsonb_build_object(
    'delegations',coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',delegation.id,'profile_id',delegation.profile_id,
        'profile_name',profile.display_name,'permission_codes',delegation.permission_codes,
        'status',delegation.status,'valid_from',delegation.valid_from,
        'valid_until',delegation.valid_until,'row_version',delegation.row_version
      ) order by delegation.created_at desc)
      from public.horse_delegated_administrators delegation
      join public.profiles profile on profile.id = delegation.profile_id
      where delegation.horse_id = p_horse_id
    ),'[]'::jsonb),
    'person_ownerships',coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',ownership.id,'profile_id',ownership.owner_profile_id,
        'profile_name',profile.display_name,'percentage',ownership.ownership_percentage,
        'status',ownership.status,'valid_from',ownership.valid_from,
        'valid_until',ownership.valid_until,'row_version',ownership.row_version
      ) order by ownership.created_at desc)
      from public.horse_person_ownerships ownership
      join public.profiles profile on profile.id = ownership.owner_profile_id
      where ownership.horse_id = p_horse_id
    ),'[]'::jsonb),
    'organization_ownerships',coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',ownership.id,'organization_id',ownership.owner_organization_id,
        'organization_name',organization.name,'percentage',ownership.ownership_percentage,
        'status',ownership.status,'valid_from',ownership.valid_from,
        'valid_until',ownership.valid_until,'row_version',ownership.row_version
      ) order by ownership.created_at desc)
      from public.horse_organization_ownerships ownership
      join public.organizations organization on organization.id = ownership.owner_organization_id
      where ownership.horse_id = p_horse_id
    ),'[]'::jsonb),
    'relationships',coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',relationship.id,'profile_id',relationship.profile_id,
        'profile_name',profile.display_name,'relationship_type',type.code,
        'status',relationship.status,'valid_from',relationship.valid_from,
        'valid_until',relationship.valid_until,'row_version',relationship.row_version
      ) order by relationship.created_at desc)
      from public.horse_person_relationships relationship
      join public.horse_relationship_types type on type.id = relationship.relationship_type_id
      join public.profiles profile on profile.id = relationship.profile_id
      where relationship.horse_id = p_horse_id
    ),'[]'::jsonb),
    'residencies',coalesce((
      select pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object(
        'id',residency.id,'organization_id',residency.stable_organization_id,
        'organization_name',organization.name,'status',residency.status,
        'valid_from',residency.valid_from,'valid_until',residency.valid_until,
        'row_version',residency.row_version
      ) order by residency.created_at desc)
      from public.horse_residencies residency
      join public.organizations organization on organization.id = residency.stable_organization_id
      where residency.horse_id = p_horse_id
    ),'[]'::jsonb),
    'pending_transfer',(
      select pg_catalog.jsonb_build_object(
        'id',transfer.id,'recipient_profile_id',transfer.recipient_profile_id,
        'recipient_name',profile.display_name,'status',transfer.status,
        'created_at',transfer.created_at,'expires_at',transfer.expires_at,
        'row_version',transfer.row_version
      )
      from public.horse_authority_transfers transfer
      join public.profiles profile on profile.id = transfer.recipient_profile_id
      where transfer.horse_id = p_horse_id
        and transfer.sender_profile_id = actor_id
        and transfer.status = 'pending'
      limit 1
    ),
    'audit',coalesce((
      select pg_catalog.jsonb_agg(entry.value order by entry.occurred_at desc)
      from (
        select event.occurred_at,
          pg_catalog.jsonb_build_object(
            'event_type',event.event_type,'reason_code',event.reason_code,
            'occurred_at',event.occurred_at,'row_version_before',event.row_version_before,
            'row_version_after',event.row_version_after,
            'access_version_before',event.access_version_before,
            'access_version_after',event.access_version_after
          ) value
        from public.audit_events event
        where event.scope_kind = 'horse' and event.scope_id = p_horse_id
        order by event.occurred_at desc
        limit 50
      ) entry
    ),'[]'::jsonb)
  ) into result;
  return result;
end;
$$;

create or replace function private.c008_target_profile_by_email(p_email text)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare target_id uuid;
begin
  target_id := private.c003d_resolve_target_profile(p_email);
  if target_id is null then
    raise exception using errcode = '22023', message = 'ACTIVE_VERIFIED_TARGET_REQUIRED';
  end if;
  return target_id;
end;
$$;

create or replace function public.grant_horse_delegated_administrator_by_email(
  p_horse_id uuid,p_target_email text,p_permission_codes text[],
  p_valid_from timestamptz,p_valid_until timestamptz,p_correlation_id uuid
)
returns table(delegation_id uuid,row_version bigint,applied boolean)
language sql security definer set search_path = '' as $$
  select * from public.grant_horse_delegated_administrator(
    p_horse_id,private.c008_target_profile_by_email(p_target_email),
    p_permission_codes,p_valid_from,p_valid_until,p_correlation_id
  )
$$;

create or replace function public.start_horse_person_ownership_by_email(
  p_horse_id uuid,p_owner_email text,p_percentage numeric,
  p_valid_from timestamptz,p_correlation_id uuid
)
returns uuid language sql security definer set search_path = '' as $$
  select public.start_horse_person_ownership(
    p_horse_id,private.c008_target_profile_by_email(p_owner_email),
    p_percentage,p_valid_from,p_correlation_id
  )
$$;

create or replace function public.start_horse_person_relationship_by_email(
  p_horse_id uuid,p_profile_email text,p_relationship_type_code text,
  p_valid_from timestamptz,p_correlation_id uuid
)
returns uuid language sql security definer set search_path = '' as $$
  select public.start_horse_person_relationship(
    p_horse_id,private.c008_target_profile_by_email(p_profile_email),
    p_relationship_type_code,p_valid_from,p_correlation_id
  )
$$;

create or replace function public.initiate_horse_authority_transfer_by_email(
  p_horse_id uuid,p_recipient_email text,p_correlation_id uuid
)
returns table(
  transfer_id uuid,transfer_token text,expires_at timestamptz,
  row_version bigint,applied boolean
)
language sql security definer set search_path = '' as $$
  select * from public.initiate_horse_authority_transfer(
    p_horse_id,private.c008_target_profile_by_email(p_recipient_email),p_correlation_id
  )
$$;

revoke execute on function public.create_canonical_horse_profile(
  text,text,date,text,text,text,text,text,text,text,text,date,uuid
) from public,anon,authenticated,service_role;
grant execute on function public.create_canonical_horse_profile(
  text,text,date,text,text,text,text,text,text,text,text,date,uuid
) to authenticated;

revoke execute on function public.update_canonical_horse_profile(
  uuid,bigint,text,text,date,text,text,text,text,text,text,text,text,date,text,uuid
) from public,anon,authenticated,service_role;
grant execute on function public.update_canonical_horse_profile(
  uuid,bigint,text,text,date,text,text,text,text,text,text,text,text,date,text,uuid
) to authenticated;

revoke execute on function public.list_canonical_horses()
  from public,anon,authenticated,service_role;
grant execute on function public.list_canonical_horses() to authenticated;

revoke execute on function public.get_canonical_horse_workspace(uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.get_canonical_horse_workspace(uuid) to authenticated;

revoke execute on function public.grant_horse_delegated_administrator_by_email(
  uuid,text,text[],timestamptz,timestamptz,uuid
) from public,anon,authenticated,service_role;
grant execute on function public.grant_horse_delegated_administrator_by_email(
  uuid,text,text[],timestamptz,timestamptz,uuid
) to authenticated;

revoke execute on function public.start_horse_person_ownership_by_email(
  uuid,text,numeric,timestamptz,uuid
) from public,anon,authenticated,service_role;
grant execute on function public.start_horse_person_ownership_by_email(
  uuid,text,numeric,timestamptz,uuid
) to authenticated;

revoke execute on function public.start_horse_person_relationship_by_email(
  uuid,text,text,timestamptz,uuid
) from public,anon,authenticated,service_role;
grant execute on function public.start_horse_person_relationship_by_email(
  uuid,text,text,timestamptz,uuid
) to authenticated;

revoke execute on function public.initiate_horse_authority_transfer_by_email(
  uuid,text,uuid
) from public,anon,authenticated,service_role;
grant execute on function public.initiate_horse_authority_transfer_by_email(
  uuid,text,uuid
) to authenticated;

revoke execute on function private.c008_bridge_legacy_horse_before_insert(),
  private.c008_normalize_optional(text),
  private.c008_sync_canonical_profile_to_legacy(),
  private.c008_target_profile_by_email(text)
from public,anon,authenticated,service_role;

comment on column public.horses.canonical_horse_id is
  'C-008 compatibility bridge. Legacy Planning/Feeding horse UUID equals the independent canonical horse UUID.';
comment on function public.list_canonical_horses() is
  'C-008 RLS-equivalent horse projection with server-derived current-actor capabilities.';
comment on function public.get_canonical_horse_workspace(uuid) is
  'C-008 authorized relationship, ownership, residency, pending-transfer and PII-minimized audit projection.';

commit;
