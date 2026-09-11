begin;

-- A stale submitted profile version is a business conflict, not a database
-- serialization failure. PT409 returns HTTP 409 without REST transaction retry.
-- Only this SQLSTATE changes: actor derivation, validation, row locking,
-- return shape, audit writes, version semantics and existing ACL remain intact.

create or replace function public.update_current_account_profile(
  p_expected_row_version bigint,
  p_first_name text,
  p_last_name text,
  p_phone_e164 text,
  p_locale text,
  p_time_zone text,
  p_theme_mode text,
  p_onboarding_intent text,
  p_complete_onboarding boolean,
  p_avatar_object_path text,
  p_correlation_id uuid
)
returns table (
  result_code text,
  profile_id uuid,
  first_name text,
  last_name text,
  display_name text,
  avatar_object_path text,
  phone_e164 text,
  locale text,
  time_zone text,
  theme_mode text,
  onboarding_intent text,
  onboarding_completed_at timestamptz,
  profile_status text,
  access_version bigint,
  row_version bigint,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
  profile_before public.profiles%rowtype;
  profile_after public.profiles%rowtype;
  normalized_first_name text;
  normalized_last_name text;
  normalized_phone text;
  normalized_locale text;
  normalized_time_zone text;
  normalized_theme_mode text;
  normalized_intent text;
  normalized_avatar_path text;
  changed_fields text[];
begin
  if p_correlation_id is null then
    raise exception using errcode = '22004', message = 'CORRELATION_ID_REQUIRED';
  end if;
  if p_expected_row_version is null or p_expected_row_version < 1 then
    raise exception using errcode = '22023', message = 'EXPECTED_ROW_VERSION_INVALID';
  end if;

  actor_profile_id := private.require_current_profile_id();
  select profile.*
  into strict profile_before
  from public.profiles profile
  where profile.id = actor_profile_id
    and profile.status = 'active'
  for update;

  if profile_before.row_version <> p_expected_row_version then
    raise exception using errcode = 'PT409', message = 'PROFILE_VERSION_STALE';
  end if;

  normalized_first_name := nullif(pg_catalog.btrim(p_first_name), '');
  normalized_last_name := nullif(pg_catalog.btrim(p_last_name), '');
  normalized_phone := nullif(pg_catalog.btrim(p_phone_e164), '');
  normalized_locale := coalesce(nullif(pg_catalog.btrim(p_locale), ''), 'und');
  normalized_time_zone := coalesce(nullif(pg_catalog.btrim(p_time_zone), ''), 'UTC');
  normalized_theme_mode := coalesce(nullif(pg_catalog.btrim(p_theme_mode), ''), 'system');
  normalized_intent := nullif(pg_catalog.btrim(p_onboarding_intent), '');
  normalized_avatar_path := nullif(pg_catalog.btrim(p_avatar_object_path), '');

  if p_complete_onboarding is null then
    raise exception using errcode = '22004', message = 'ONBOARDING_COMPLETION_REQUIRED';
  end if;
  if p_complete_onboarding
    and (normalized_first_name is null or normalized_intent is null)
  then
    raise exception using errcode = '22023', message = 'ONBOARDING_FIELDS_REQUIRED';
  end if;
  if normalized_phone is not null
    and normalized_phone !~ '^\+[1-9][0-9]{7,14}$'
  then
    raise exception using errcode = '22023', message = 'PHONE_E164_INVALID';
  end if;
  if normalized_locale <> 'und'
    and normalized_locale !~ '^[a-z]{2}(-[A-Z]{2})?$'
  then
    raise exception using errcode = '22023', message = 'LOCALE_INVALID';
  end if;
  if not private.c003a_is_valid_iana_time_zone(normalized_time_zone) then
    raise exception using errcode = '22023', message = 'TIME_ZONE_INVALID';
  end if;
  if normalized_theme_mode not in ('system', 'light', 'dark') then
    raise exception using errcode = '22023', message = 'THEME_MODE_INVALID';
  end if;
  if normalized_intent is not null
    and normalized_intent not in ('createStable', 'joinStable', 'individualHorse')
  then
    raise exception using errcode = '22023', message = 'ONBOARDING_INTENT_INVALID';
  end if;
  if normalized_avatar_path is not null
    and normalized_avatar_path !~ (
      '^' || profile_before.auth_user_id::text
      || '/avatar-[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-4[0-9A-Fa-f]{3}'
      || '-[89AaBb][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}[.](jpg|jpeg|png|webp)$'
    )
  then
    raise exception using errcode = '42501', message = 'AVATAR_PATH_NOT_OWNED';
  end if;

  update public.profiles profile
  set
    first_name = normalized_first_name,
    last_name = normalized_last_name,
    display_name = coalesce(
      nullif(
        pg_catalog.btrim(
          pg_catalog.concat_ws(' ', normalized_first_name, normalized_last_name)
        ),
        ''
      ),
      'AVARYN user'
    ),
    avatar_object_path = normalized_avatar_path,
    phone_e164 = normalized_phone,
    locale = normalized_locale,
    time_zone = normalized_time_zone,
    theme_mode = normalized_theme_mode,
    onboarding_intent = normalized_intent,
    onboarding_completed_at = case
      when p_complete_onboarding
        then coalesce(profile.onboarding_completed_at, pg_catalog.clock_timestamp())
      else profile.onboarding_completed_at
    end
  where profile.id = actor_profile_id
  returning profile.* into profile_after;

  if profile_after.id is null then
    profile_after := profile_before;
  end if;

  changed_fields := pg_catalog.array_remove(array[
    case when profile_before.first_name is distinct from profile_after.first_name
      then 'first_name' end,
    case when profile_before.last_name is distinct from profile_after.last_name
      then 'last_name' end,
    case when profile_before.display_name is distinct from profile_after.display_name
      then 'display_name' end,
    case when profile_before.avatar_object_path is distinct from profile_after.avatar_object_path
      then 'avatar_object_path' end,
    case when profile_before.phone_e164 is distinct from profile_after.phone_e164
      then 'phone_e164' end,
    case when profile_before.locale is distinct from profile_after.locale
      then 'locale' end,
    case when profile_before.time_zone is distinct from profile_after.time_zone
      then 'time_zone' end,
    case when profile_before.theme_mode is distinct from profile_after.theme_mode
      then 'theme_mode' end,
    case when profile_before.onboarding_intent is distinct from profile_after.onboarding_intent
      then 'onboarding_intent' end,
    case when profile_before.onboarding_completed_at is distinct from profile_after.onboarding_completed_at
      then 'onboarding_completed_at' end
  ], null);

  if pg_catalog.cardinality(changed_fields) > 0 then
    insert into public.audit_events (
      actor_kind,
      actor_profile_id,
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
    ) values (
      'profile',
      actor_profile_id,
      'profile.account_fields_updated',
      'profile',
      actor_profile_id,
      'profile',
      actor_profile_id,
      pg_catalog.jsonb_build_object('status', profile_before.status),
      pg_catalog.jsonb_build_object('status', profile_after.status),
      'ACCOUNT_FIELDS_CHANGED',
      p_correlation_id,
      'rpc',
      profile_before.row_version,
      profile_after.row_version,
      profile_before.access_version,
      profile_after.access_version,
      pg_catalog.jsonb_build_object('changed_fields', changed_fields)
    );
  end if;

  return query
  select
    case when pg_catalog.cardinality(changed_fields) > 0
      then 'updated'::text else 'no_change'::text end,
    profile_after.id,
    profile_after.first_name,
    profile_after.last_name,
    profile_after.display_name,
    profile_after.avatar_object_path,
    profile_after.phone_e164,
    profile_after.locale,
    profile_after.time_zone,
    profile_after.theme_mode,
    profile_after.onboarding_intent,
    profile_after.onboarding_completed_at,
    profile_after.status,
    profile_after.access_version,
    profile_after.row_version,
    profile_after.created_at,
    profile_after.updated_at;
end;
$$;

commit;
