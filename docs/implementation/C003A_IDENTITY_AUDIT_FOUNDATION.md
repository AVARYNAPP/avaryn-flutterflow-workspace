# C-003A — Identity and Audit Foundation

## Status en begrenzing

- Status: **Implemented locally – awaiting Silas security approval**.
- Branch: `implementation/account-model-v2-c003a-identity-audit`.
- Basis- en rollbackcommit:
  `5eb07f54ffa7464f8f7e325f8b112411936298e8`.
- Normatieve inhoudscommit:
  `4288944ae77cee9e1f0bf42f9369956b342e0097`.
- Scope: uitsluitend personal profiles, Auth-koppeling/provisioning,
  server-side actorafleiding, profile-RLS/grants, profile versions,
  append-only audit en de lokale deletion-/anonimiseringsbasis.
- Uitgesteld: organizations, horses, memberships, rollen, permissions,
  invitations, transfers, Today, Rider Performance, FlutterFlow, staging en
  remote uitvoering.

## Toegevoegde bestanden

- Migration:
  `supabase/migrations/202608040001_c003a_identity_audit_foundation.sql`.
- Securitytest:
  `supabase/tests/c003a_identity_audit_foundation.sql`.

Het bestaande `public.profiles` kon zonder schaduwmodel worden geconformeerd.
Statische analyse van de volledige migrationketen vond geen latere database-FK
of functie die van `public.profiles` afhankelijk is. De legacy PK blijft de
duurzame profile-UUID; alleen de oude `id -> auth.users ON DELETE CASCADE`-FK is
zonder `CASCADE` vervangen door de contractuele nullable Auth-koppeling.

## Databasecontract

### Profiles

`public.profiles` heeft na C-003A:

- `id uuid` als server-generated duurzame PK;
- unieke nullable `auth_user_id uuid` naar `auth.users(id)` met
  `ON DELETE SET NULL`;
- `display_name`, `avatar_object_path`, `locale`, `phone_e164` en
  `time_zone` als displayvelden;
- lifecycle `active -> deletion_pending -> auth_removal_pending -> anonymized`;
- `access_version bigint not null default 1` en
  `row_version bigint not null default 1`;
- database-timestamps en `anonymized_at`;
- constraints voor Auth/lifecycleconsistentie, IANA-timezone, versionminimums
  en de vier duurzame statussen;
- indexes op `status` en de unieke Auth-koppeling.

De before-write-trigger normaliseert veilige waarden, weigert lifecycle- en
Auth-linksprongen, voorkomt versionverlagingen, beheert `row_version` en
`updated_at` server-side en laat uitsluitend de goedgekeurde lifecycle-richting
toe. Een normale displaymutatie verhoogt alleen `row_version`; iedere C-003A-
lifecyclemutatie verhoogt `access_version` en `row_version` in dezelfde
transactie.

### Auth-provisioning en actor

De bestaande Auth-trigger is veilig vervangen. Een nieuwe `auth.users`-rij
maakt idempotent precies één profile met een onafhankelijke server-generated
UUID, status `active`, versions `1`, timezone `UTC`, locale `und` en een
neutrale displaynaam. E-mail, namen, OAuth-/JWT-metadata en een eventueel
gespoofde profile-ID worden niet gelezen.

`private.current_profile_id()` gebruikt uitsluitend `auth.uid()`, eist exact
één actief profile en retourneert anders `null`. De helper is side-effectvrij,
`STABLE`, `SECURITY DEFINER`, heeft `search_path=''` en is de enige helper die
RLS nodig heeft. `private.require_current_profile_id()` bestaat als interne
fail-closed variant, zonder client-EXECUTE.

### RLS en grants

- RLS staat aan op `public.profiles` en `public.audit_events`.
- `anon` heeft geen toegang.
- `authenticated` kan uitsluitend het eigen actieve profile lezen.
- Directe client-`INSERT` en `DELETE` zijn niet verleend.
- `UPDATE` is zowel door RLS als kolomgrants beperkt tot `display_name`,
  `avatar_object_path`, `locale`, `phone_e164` en `time_zone`.
- Auth-, lifecycle-, version- en technische timestampkolommen zijn niet direct
  clientschrijfbaar.
- `audit_events` heeft geen clientpolicy en geen client- of service-role-DML-
  grants.
- Interne audit- en anonymiseringsfuncties hebben geen `PUBLIC`, `anon`,
  `authenticated` of service-role `EXECUTE`.

### Audit

`public.audit_events` bevat UUID, schema version, exact één technische
actorvorm, eventtype, profile resource/scope, allowlisted status-snapshots,
reason code, databasetijd, correlation-ID, channel en row/access versions voor
en na de mutatie.

Allowlisted events zijn:

- `profile.provisioned`;
- `profile.display_fields_updated`;
- `profile.deletion_requested`;
- `profile.auth_removal_prepared`;
- `profile.anonymization_finalized`;
- `profile.lifecycle_denied`.

Metadata accepteert per event uitsluitend de benodigde codevelden:
`changed_fields`, `dependency_checks_complete=false` of `denial_code`. Audit
neemt geen e-mail, naam-/displaywaarde, telefoonwaarde, vrije tekst, secret,
token, token digest, signed URL of volledige payload over. Een before-trigger
weigert iedere directe `UPDATE` en `DELETE`, ook via de database-eigenaar.

## Deletion- en anonimiseringbasis

`public.request_profile_deletion(expected_row_version, correlation_id)`:

- leidt de actor server-side af en accepteert geen target profile-ID;
- vereist optimistic concurrency en een correlation-ID;
- zet `active` naar `deletion_pending`;
- verhoogt access- en row-version;
- auditeert atomair;
- levert bij retry dezelfde vastgelegde versions terug zonder tweede mutatie;
- auditeert stale/niet-actieve lifecyclepogingen idempotent met codes;
- retourneert uitsluitend een getypeerd technisch resultaat.

De niet-publieke functies `private.prepare_profile_auth_removal(...)` en
`private.finalize_profile_anonymization(...)` leveren alleen de lokale basis
voor een latere trusted orchestrator. Preparation pseudonimiseert de bekende
identificerende profilevelden, roteert versions en bereikt
`auth_removal_pending`. De Auth-FK mag pas daarna worden ontkoppeld. Finalisatie
vereist aantoonbaar `auth_user_id is null`, bewaart de duurzame profile-UUID en
bereikt idempotent `anonymized`.

Deze functies retourneren altijd `production_ready=false`; auditmetadata legt
`dependency_checks_complete=false` vast. Cleanup/blockers voor horse authority,
organization admin, memberships, rollen, grants, shares, relaties,
invitations en transfers zijn expliciet uitgesteld tot latere fasen. Volledige
productieanonimisering is niet veilig vóór die uitbreidingen en de C-003F-gate.

## Lokale verificatie

De bestaande actieve workspace-stack is niet gereset. Voor C-003A is een aparte
tijdelijke stack gebruikt met project-ID `avaryn-c003a-isolated-6alvm5` en
afwijkende poorten.

Uitgevoerde controles:

1. `supabase db reset --local --no-seed` in de geïsoleerde stack: **PASS**;
   alle migrations van `202607250001` tot en met `202608040001` bouwden vanaf
   een lege database.
2. `supabase test db supabase/tests/c003a_identity_audit_foundation.sql --local`:
   **PASS**, `Files=1, Tests=1, Result: PASS`.
3. `supabase db lint --local --level warning`: **PASS voor C-003A**; uitsluitend
   vier reeds bestaande waarschuwingen in legacy planning/syncfuncties, geen
   C-003A-waarschuwing.
4. PostgreSQL-catalogusinspectie: **PASS** voor RLS, policies, kolomgrants,
   triggeractivatie, `ON DELETE SET NULL`, SECURITY DEFINER en lege
   `search_path`.
5. `git diff --check`: **PASS**.

De test bevat positieve en negatieve gevallen voor provisioning, één-op-één-
Auth, missing/duplicate/spoofed actors, anonymous/cross-profiletoegang,
allowlisted displayupdates, directe DML, IANA-timezones, versions, stale
concurrency, retries, auditimmutabiliteit, PII-uitsluiting, Auth-unlinkvolgorde,
pseudonimisering, herstel na de externe Auth-stap en duurzame actorhistorie.

## Securitygate en rollback

Lokale C-003A-securitygate: **geslaagd; awaiting Silas security approval**.
Er zijn geen open C-003A P0/P1/P2-bevindingen. De enige echte open technische
punten zijn de bewust uitgestelde dependencychecks/orchestrator en de latere
C-003F-brede securityaudit.

Rollback is terugkeren naar de onveranderde basiscommit
`5eb07f54ffa7464f8f7e325f8b112411936298e8`. Snapshot, remote database,
staging, Supabase-linking, FlutterFlow, applicatiecode en live Alpha zijn niet
gewijzigd. Er is niets gepusht, gemerged of gedeployed.
