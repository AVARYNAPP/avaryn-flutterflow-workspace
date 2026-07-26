# AVARYN Phase 4A development setup

This checklist is intentionally configuration-only. Never add real secrets to
this repository.

## Supabase development project

1. Connect a non-production Supabase project in FlutterFlow.
2. Apply `supabase/migrations/202607250001_phase_4a_identity.sql`.
3. Verify the private `avatars` bucket and all ownership policies.
4. Run `supabase/tests/phase_4a_profiles_rls.sql` only against an isolated local
   or disposable test database.
5. Refresh the Supabase schema in FlutterFlow.

Client configuration:

- Supabase project URL: configured in FlutterFlow, never duplicated here.
- Publishable/anon key: configured in FlutterFlow.
- Service-role/secret key: server environment only; never in Flutter.

## Redirect allowlist

The local Supabase instance uses this exact allowlist:

- `http://127.0.0.1:3000/auth/callback`
- `http://127.0.0.1:3000/auth/reset-password`
- `http://localhost:3000/auth/callback`
- `http://localhost:3000/auth/reset-password`
- `http://127.0.0.1:3001/auth/callback`
- `http://127.0.0.1:3001/auth/reset-password`
- `avarynconsumerapp://avarynconsumerapp.com/auth/callback`
- `avarynconsumerapp://avarynconsumerapp.com/auth/reset-password`

The web runtime builds its callback from the exact origin serving the app. For
every hosted development origin, add exactly these two entries manually in
Supabase Authentication > URL Configuration:

- `https://ACTUAL-DEVELOPMENT-ORIGIN/auth/callback`
- `https://ACTUAL-DEVELOPMENT-ORIGIN/auth/reset-password`

`ACTUAL-DEVELOPMENT-ORIGIN` is intentionally not a value to paste. Replace it
with the real HTTPS host after that host is approved. The repository does not
currently contain that host, so the hosted-development allowlist cannot be
finalized truthfully from source alone.

Do not use a wildcard production redirect. Add each preview origin explicitly.
Do not change the production allowlist during Phase 4A.

## Google

- Configure Google only in the Supabase development project.
- Create the appropriate web, Android, and iOS client types.
- Android application ID: `com.mycompany.avarynconsumerapp`.
- Register every development signing SHA fingerprint that is actually used.
- iOS bundle ID: `com.mycompany.avarynconsumerapp`.
- Keep the Google client secret in Supabase, not in FlutterFlow custom code.

## Apple

- Enable the Sign in with Apple capability for
  `com.mycompany.avarynconsumerapp`.
- Configure the Apple Service ID/client ID, Team ID, key ID, and signing key in
  Supabase.
- Keep the Apple private key out of Flutter and this repository.
- Configure the relay-email sender domain before release.
- Implement and runtime-test Apple authorization revocation before enabling
  account deletion for Apple-linked accounts.

## Email

- Set the confirmation redirect to the exact callback URL above.
- Set password recovery to the exact reset-password URL above.
- Verify confirmation and recovery templates in the development project.
- Test expiry, replay, resend throttling, and cold-start handling.

## Legal URLs

Before release, configure real HTTPS URLs for:

- `AVARYN_PRIVACY_POLICY_URL`
- `AVARYN_TERMS_URL`

Until both URLs exist, the app must not show invented or dead legal links. Their
absence remains a release blocker.

## Account deletion

`supabase/functions/delete-account/index.ts` is deliberately not deployed by
this phase.

Before enabling the client action:

1. Configure and test authenticated Edge Function invocation.
2. Verify `SUPABASE_SERVICE_ROLE_KEY` exists only in the server environment.
3. Complete the Apple revocation path.
4. Restrict allowed web origins.
5. Test repeated requests and partial storage failures.
6. Confirm account-scoped local-data deletion separately in the app.

## Local development commands

After installing the Supabase CLI:

```text
supabase start
supabase db reset
supabase test db
supabase functions serve delete-account
```

Do not run deployment commands as part of Phase 4A review.

## Release verification

- Real privacy and terms URLs configured.
- Exact redirect allowlist reviewed.
- Email confirmation and recovery delivered and tested.
- Google tested on every released target.
- Apple tested on a signed Apple-capable build.
- RLS own-user and cross-user tests pass.
- Avatar ownership tests pass.
- Account deletion and Apple revocation pass end to end.
- Release build contains no local auth bypass.

## Static-analysis baseline

The Phase 4A local verification on Flutter 3.35.7 established the following
baseline for the complete FlutterFlow-generated code snapshot:

- Errors: `0`
- Warnings: `1578`
- Info/lints: `2975`

The targeted Phase 4A analysis of `dsl/edit.dart` and `test/app_test.dart`
reported:

- Errors: `0`
- Warnings: `0`

Future reviews should compare their results with this baseline and report new
errors or increases separately. The generated snapshot remains read-only and is
not committed from this workspace.
