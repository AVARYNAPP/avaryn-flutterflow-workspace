begin;

alter table public.profiles
  add constraint profiles_avatar_object_path_owner_check
  check (
    avatar_object_path is null
    or (
      auth_user_id is not null
      and avatar_object_path ~ (
        '^' || auth_user_id::text
        || '/avatar-[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-4[0-9A-Fa-f]{3}'
        || '-[89AaBb][0-9A-Fa-f]{3}-[0-9A-Fa-f]{12}[.](jpg|jpeg|png|webp)$'
      )
    )
  );

alter table public.audit_events
  drop constraint audit_events_event_type_check,
  add constraint audit_events_event_type_check
    check (
      event_type in (
        'profile.provisioned','profile.display_fields_updated','profile.account_fields_updated',
        'profile.deletion_requested','profile.auth_removal_prepared','profile.anonymization_finalized',
        'profile.lifecycle_denied','organization.created','organization.updated',
        'organization.membership_created','organization.membership_status_changed',
        'organization.role_created','organization.role_status_changed',
        'organization.role_permission_granted','organization.role_permission_revoked',
        'organization.membership_role_granted','organization.membership_role_revoked',
        'organization.access_changed','horse.created','horse.updated','horse.access_changed',
        'horse.delegation_granted','horse.delegation_ended','horse.person_ownership_started',
        'horse.person_ownership_ended','horse.organization_ownership_started',
        'horse.organization_ownership_ended','horse.person_relationship_started',
        'horse.person_relationship_ended','horse.organization_link_proposed',
        'horse.organization_link_activated','horse.organization_link_rejected',
        'horse.organization_link_withdrawn','horse.organization_link_expired',
        'horse.organization_link_ended','horse.residency_started','horse.residency_switched',
        'horse.residency_ended','permission.horse_profile_granted',
        'permission.horse_profile_revoked','permission.horse_profile_expired',
        'permission.horse_role_granted','permission.horse_role_revoked',
        'permission.horse_role_expired','permission.denied_escalation',
        'invitation.organization_created','invitation.organization_accepted',
        'invitation.organization_declined','invitation.organization_revoked',
        'invitation.organization_expired','invitation.horse_created','invitation.horse_accepted',
        'invitation.horse_declined','invitation.horse_revoked','invitation.horse_expired',
        'rider_performance.profile_share_granted','rider_performance.profile_share_revoked',
        'rider_performance.profile_share_expired','rider_performance.role_share_granted',
        'rider_performance.role_share_revoked','rider_performance.role_share_expired',
        'horse.authority_transfer_initiated','horse.authority_transfer_accepted',
        'horse.authority_transfer_declined','horse.authority_transfer_revoked',
        'horse.authority_transfer_expired','organization.head_transfer_initiated',
        'organization.head_transfer_accepted','organization.head_transfer_declined',
        'organization.head_transfer_revoked','organization.head_transfer_expired'
      )
    ),
  drop constraint audit_events_reason_code_check,
  add constraint audit_events_reason_code_check
    check (
      reason_code in (
        'AUTH_USER_CREATED','PROFILE_FIELDS_CHANGED','ACCOUNT_FIELDS_CHANGED',
        'USER_DELETION_REQUEST','C003A_AUTH_REMOVAL_PREPARED',
        'C003A_ANONYMIZATION_FINALIZED','LIFECYCLE_REQUEST_DENIED','ORGANIZATION_CREATED',
        'ORGANIZATION_UPDATED','MEMBERSHIP_CREATED','MEMBERSHIP_STATUS_CHANGED','ROLE_CREATED',
        'ROLE_STATUS_CHANGED','ROLE_PERMISSION_GRANTED','ROLE_PERMISSION_REVOKED',
        'MEMBERSHIP_ROLE_GRANTED','MEMBERSHIP_ROLE_REVOKED','ACCESS_CHANGED','HORSE_CREATED',
        'HORSE_UPDATED','DELEGATION_GRANTED','DELEGATION_ENDED','PERSON_OWNERSHIP_STARTED',
        'PERSON_OWNERSHIP_ENDED','ORGANIZATION_OWNERSHIP_STARTED',
        'ORGANIZATION_OWNERSHIP_ENDED','PERSON_RELATIONSHIP_STARTED',
        'PERSON_RELATIONSHIP_ENDED','ORGANIZATION_LINK_PROPOSED','ORGANIZATION_LINK_ACTIVATED',
        'ORGANIZATION_LINK_REJECTED','ORGANIZATION_LINK_WITHDRAWN',
        'ORGANIZATION_LINK_EXPIRED','ORGANIZATION_LINK_ENDED','RESIDENCY_STARTED',
        'RESIDENCY_SWITCHED','RESIDENCY_ENDED','HORSE_PERMISSION_GRANTED',
        'HORSE_PERMISSION_REVOKED','HORSE_PERMISSION_EXPIRED','PERMISSION_ESCALATION_DENIED',
        'ORGANIZATION_INVITATION_CREATED','ORGANIZATION_INVITATION_ACCEPTED',
        'ORGANIZATION_INVITATION_DECLINED','ORGANIZATION_INVITATION_REVOKED',
        'ORGANIZATION_INVITATION_EXPIRED','HORSE_INVITATION_CREATED',
        'HORSE_INVITATION_ACCEPTED','HORSE_INVITATION_DECLINED','HORSE_INVITATION_REVOKED',
        'HORSE_INVITATION_EXPIRED','RIDER_SHARE_GRANTED','RIDER_SHARE_REVOKED',
        'RIDER_SHARE_EXPIRED','HORSE_TRANSFER_INITIATED','HORSE_TRANSFER_ACCEPTED',
        'HORSE_TRANSFER_DECLINED','HORSE_TRANSFER_REVOKED','HORSE_TRANSFER_EXPIRED',
        'ORGANIZATION_TRANSFER_INITIATED','ORGANIZATION_TRANSFER_ACCEPTED',
        'ORGANIZATION_TRANSFER_DECLINED','ORGANIZATION_TRANSFER_REVOKED',
        'ORGANIZATION_TRANSFER_EXPIRED'
      )
    );

create or replace function public.get_current_account_profile()
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
stable
security definer
set search_path = ''
as $$
declare
  actor_profile_id uuid;
begin
  actor_profile_id := private.require_current_profile_id();

  return query
  select
    'current'::text,
    profile.id,
    profile.first_name,
    profile.last_name,
    profile.display_name,
    profile.avatar_object_path,
    profile.phone_e164,
    profile.locale,
    profile.time_zone,
    profile.theme_mode,
    profile.onboarding_intent,
    profile.onboarding_completed_at,
    profile.status,
    profile.access_version,
    profile.row_version,
    profile.created_at,
    profile.updated_at
  from public.profiles profile
  where profile.id = actor_profile_id
    and profile.status = 'active';

  if not found then
    raise exception using errcode = '42501', message = 'ACTIVE_PROFILE_REQUIRED';
  end if;
end;
$$;

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
    raise exception using errcode = '40001', message = 'PROFILE_VERSION_STALE';
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

revoke all on function public.get_current_account_profile()
  from public, anon, authenticated, service_role;
grant execute on function public.get_current_account_profile()
  to authenticated;

revoke all on function public.update_current_account_profile(
  bigint, text, text, text, text, text, text, text, boolean, text, uuid
) from public, anon, authenticated, service_role;
grant execute on function public.update_current_account_profile(
  bigint, text, text, text, text, text, text, text, boolean, text, uuid
) to authenticated;

comment on function public.get_current_account_profile() is
  'C-007 typed current-profile projection. Actor and durable profile ID are derived server-side.';
comment on function public.update_current_account_profile(
  bigint, text, text, text, text, text, text, text, boolean, text, uuid
) is
  'C-007 CAS profile/onboarding mutation. No caller-supplied actor or profile authority.';

commit;
