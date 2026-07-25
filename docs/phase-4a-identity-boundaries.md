# AVARYN Phase 4A identity boundaries

Phase 4A keeps identity, profile data, future stable access, and the existing
local operational identity as four separate concepts.

## Authenticated AVARYN account

- Source of truth: Supabase Auth.
- Primary identifier: the immutable Supabase auth user UUID.
- Owns one or more linked sign-in identities such as email, Google, or Apple.
- Email addresses, relay addresses, provider display names, and personal names
  are never identifiers.

## Personal profile

- Source of truth: one `public.profiles` row whose primary key equals the auth
  user UUID.
- Contains only personal display data and preferences: name, avatar path,
  optional phone number, locale, theme, onboarding intent, and onboarding
  completion.
- Contains no stable role, permissions, ownership claim, or invitation state.
- OAuth metadata may prefill missing values but is not authorization data.

## Future stable membership

- Phase 4B will connect an auth account to a stable through a separate
  membership record.
- Stable roles and permissions belong to that future relationship, not to the
  profile and not to editable auth metadata.
- Phase 4A does not create, infer, or fabricate any stable membership.

## Existing local stable member and operational user

- Source of truth: the existing Phase 1–3 local prototype state, including
  `currentLocalUserId` and stored responsible-person and performer IDs.
- These IDs remain legacy operational identifiers and are not converted to auth
  UUIDs.
- Historical feeding responsibility, performer history, horse data, planning,
  and feeding records remain unchanged.
- Phase 4A only adds an auth-UUID namespace around the existing local working
  set. It does not reinterpret or rewrite the records inside that set.

## Transitional local-data rule

- Local account scopes are keyed by auth UUID, never by email or display name.
- Legacy unscoped data is preserved as a rollback-safe backup.
- It is attached or copied to an account only after an explicit, one-time
  ownership choice.
- “Niet nu” retains the legacy backup and gives the signed-in account an empty
  safe scope.
- Logging out saves and clears the in-memory account-sensitive working set; it
  does not delete either scoped data or the legacy backup.
- Signing in again with the same auth UUID restores the same local scope.
- A different auth UUID cannot see another account's local scope.

