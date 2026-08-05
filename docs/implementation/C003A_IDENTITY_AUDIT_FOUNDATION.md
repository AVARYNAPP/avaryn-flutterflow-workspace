# C-003A — Identity and Audit Foundation

## Status en begrenzing

- Status: **C-003A — Approved within the agreed scope**.
- Datum securitygoedkeuring: `2026-08-05`.
- Branch: `implementation/account-model-v2-c003a-identity-audit`.
- Basis- en rollbackcommit:
  `5eb07f54ffa7464f8f7e325f8b112411936298e8`.
- Normatieve inhoudscommit:
  `4288944ae77cee9e1f0bf42f9369956b342e0097`.
- Goedgekeurde implementatiecommit:
  `7ecddccb6cf7dabea2a6597d8245b707f6110ff4`.
- Goedgekeurde hardeningcommit:
  `09e3d1ef1f2efe30a94afd1ea23df4c7da6f724c`.
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
- `audit_events` heeft geen clientpolicy en geen `anon`-, `authenticated`- of
  `service_role`-DML-grants.
- Interne audit- en anonymiseringsfuncties hebben geen `PUBLIC`, `anon`,
  `authenticated` of `service_role` `EXECUTE`.

### Private-schema-inventaris en allowlist

De inventaris is na een fresh build rechtstreeks uit `pg_proc`,
`pg_namespace`, `pg_roles`, `proacl`/`aclexplode`,
`has_function_privilege()` en `has_schema_privilege()` opgebouwd. Hij bevat
**96 functies, 0 procedures, 70 SECURITY DEFINER- en 26 invokerfuncties**. Voor
iedere rij gelden: owner `postgres`, functie (geen procedure) en
`search_path=""`. De kolom `D/I` hieronder betekent SECURITY DEFINER/invoker.

De volledige clientallowlist bestaat uit de volgende 19 routines. Iedere rij
heeft expliciete ACL `{postgres=X/postgres,authenticated=X/postgres}` en
effectief EXECUTE `PUBLIC=false`, `anon=false`, `authenticated=true`,
`service_role=false`:

```text
I c003a_is_valid_iana_time_zone(p_time_zone text)
D can_join_realtime_topic(p_topic text)
D can_manage_horse_grants(p_horse_id uuid, p_category text)
D can_select_feeding_execution_detail(p_execution_id uuid)
D can_select_feeding_plan(p_feeding_plan_id uuid)
D can_select_feeding_version(p_feeding_plan_version_id uuid)
D can_select_schedule_assignment_base(p_schedule_assignment_id uuid)
D can_select_schedule_item_base(p_schedule_item_id uuid)
D can_select_schedule_series_base(p_schedule_series_id uuid)
D can_view_media_asset(p_media_asset_id uuid)
D can_view_media_audit(p_media_asset_id uuid)
D can_view_media_link(p_media_link_id uuid)
D current_membership_id(p_stable_id uuid)
D current_profile_id()
D current_role(p_stable_id uuid)
D has_horse_capability(p_horse_id uuid, p_category text, p_capability text)
D is_active_member(p_stable_id uuid)
D is_stable_manager(p_stable_id uuid)
D schedule_item_access_level(p_schedule_item_id uuid)
```

De overige 77 routines zijn intern. Iedere rij heeft expliciete ACL
`{postgres=X/postgres}` en effectief EXECUTE `PUBLIC=false`, `anon=false`,
`authenticated=false`, `service_role=false`:

```text
D active_sync_membership(p_stable_id uuid)
D assert_exactly_one_active_owner_for_membership()
D assert_exactly_one_active_owner_for_stable()
D assign_stable_change_sequence()
I c003a_audit_json_keys_allowed(p_value jsonb, p_allowed_keys text[])
D c003a_audit_profile_insert()
D c003a_audit_safe_profile_update()
I c003a_prevent_audit_mutation()
D c003a_write_profile_audit(p_event_type text, p_profile_id uuid, p_actor_profile_id uuid, p_system_actor_code text, p_correlation_id uuid, p_channel text, p_old_status text, p_new_status text, p_row_version_before bigint, p_row_version_after bigint, p_access_version_before bigint, p_access_version_after bigint, p_metadata jsonb)
D capture_feeding_change()
D capture_horse_change()
D capture_schedule_change()
D enforce_offline_execution_device()
D ensure_sync_authority(p_stable_id uuid)
D event_is_visible(p_stable_id uuid, p_horse_id uuid, p_entity_type text, p_entity_id uuid, p_data_category text)
I feeding_item_matches_date(p_item feeding_plan_items, p_effective_from date, p_local_date date)
D feeding_membership_can_edit(p_membership stable_memberships, p_horse_id uuid)
D feeding_membership_can_manage(p_membership stable_memberships, p_horse_id uuid)
D feeding_receipt_result(p_actor_user_id uuid, p_request_id uuid, p_operation_name text, p_payload_hash bytea)
D finalize_profile_anonymization(p_profile_id uuid, p_expected_row_version bigint, p_correlation_id uuid)
I guard_feeding_plan_item_draft()
D guard_media_link_scope()
I horse_profile_json(p_horse horses)
D legacy_import_mapping_is_current(p_item_id uuid)
D legacy_job_access(p_job_id uuid, p_lock boolean)
I legacy_source_manifest_hash(p_source_inventory jsonb, p_items jsonb)
D lock_client_request(p_actor_user_id uuid, p_request_id uuid)
D lock_feeding_context(p_stable_id uuid, p_horse_id uuid)
D lock_media_actor_context(p_actor_user_id uuid, p_stable_id uuid, p_horse_id uuid)
D lock_media_context(p_stable_id uuid, p_horse_id uuid)
D lock_media_request(p_actor_user_id uuid, p_request_id uuid)
D lock_schedule_context(p_stable_id uuid, p_horse_id uuid)
D lock_stable_membership_mutation(p_stable_id uuid)
D lock_sync_membership(p_stable_id uuid)
D media_actor_can_continue_asset_upload(p_actor_user_id uuid, p_media_asset_id uuid)
D media_actor_can_upload_to_target(p_actor_user_id uuid, p_horse_id uuid, p_schedule_execution_id uuid)
D media_actor_can_view_asset(p_actor_user_id uuid, p_media_asset_id uuid)
D media_actor_can_view_link(p_actor_user_id uuid, p_media_link_id uuid)
D media_actor_has_capability(p_actor_user_id uuid, p_horse_id uuid, p_capability text)
D media_actor_membership(p_actor_user_id uuid, p_stable_id uuid)
D media_actor_schedule_access_level(p_actor_user_id uuid, p_schedule_item_id uuid)
D media_receipt_result(p_actor_user_id uuid, p_request_id uuid, p_operation_name text, p_payload_hash bytea)
D media_upload_session_result(p_media_asset_id uuid, p_idempotent boolean)
D prepare_profile_auth_removal(p_profile_id uuid, p_expected_row_version bigint, p_correlation_id uuid)
I prevent_media_append_only_mutation()
I prevent_schedule_append_only_mutation()
D publish_stable_change()
D require_current_profile_id()
D require_sync_device(p_device_instance_id uuid, p_stable_id uuid, p_expected_authority_version bigint)
D reserve_execution_request_namespace()
D rotate_sync_authority()
I schedule_derived_request_id(p_request_id uuid, p_suffix text)
D schedule_membership_can_edit(p_membership stable_memberships, p_horse_id uuid)
D schedule_membership_can_execute(p_membership stable_memberships, p_horse_id uuid)
I schedule_payload_hash(p_payload jsonb)
D schedule_receipt_result(p_actor_user_id uuid, p_request_id uuid, p_operation_name text, p_payload_hash bytea)
I schedule_series_matches_date(p_series schedule_series, p_local_date date)
I sync_payload_hash(p_payload jsonb)
I touch_feeding_plan()
I touch_feeding_plan_item()
I touch_feeding_plan_version()
I touch_horse()
I touch_horse_access_grant()
I touch_horse_identifier()
I touch_horse_relationship()
I touch_media_asset()
I touch_membership()
I touch_schedule_assignment()
I touch_schedule_item()
I touch_schedule_series()
I touch_updated_at()
D write_feeding_change_event(p_stable_id uuid, p_horse_id uuid, p_feeding_plan_id uuid, p_feeding_plan_version_id uuid, p_feeding_plan_item_id uuid, p_schedule_item_id uuid, p_execution_id uuid, p_actor_membership_id uuid, p_request_id uuid, p_event_type text, p_row_version bigint, p_reason text)
D write_horse_security_event(p_stable_id uuid, p_horse_id uuid, p_event_type text, p_actor_membership_id uuid, p_subject_membership_id uuid, p_request_id uuid, p_metadata jsonb)
D write_legacy_import_change(p_job legacy_import_jobs, p_change_kind text)
D write_media_change_event(p_stable_id uuid, p_horse_id uuid, p_media_asset_id uuid, p_media_link_id uuid, p_actor_user_id uuid, p_actor_membership_id uuid, p_request_id uuid, p_event_type text, p_row_version bigint)
D write_schedule_change_event(p_stable_id uuid, p_schedule_series_id uuid, p_schedule_item_id uuid, p_schedule_assignment_id uuid, p_schedule_execution_id uuid, p_actor_membership_id uuid, p_request_id uuid, p_event_type text, p_data_category text, p_row_version bigint, p_reason text)
D write_security_event(p_stable_id uuid, p_event_type text, p_actor_membership_id uuid, p_subject_membership_id uuid, p_subject_stable_member_id uuid, p_invitation_id uuid, p_request_id uuid, p_metadata jsonb)
```

De afhankelijkheidscontrole vond 28 RLS-policies, 41 niet-interne triggers en
70 publieke functies/RPC's als bewuste aanroepers van private helpers. De
19 clientbereikbare helpers zijn uitsluitend RLS-/capabilityprojecties of de
timezonevalidator; hun definities muteren geen data buiten de bestaande
RPC-/RLS-grenzen. Alle 18 bereikbare SECURITY DEFINER-helpers hebben een lege
vaste search path. `authenticated`-`USAGE` op schema `private` blijft daarom
nodig voor policies en deze allowlist. `anon` en `service_role` hebben geen
schema-`USAGE`; `PUBLIC`, `anon` en `service_role` hebben geen effectieve
EXECUTE op private routines. Er is geen aantoonbaar onveilig legacyrecht
gevonden en daarom is geen brede legacy-revoke uitgevoerd. Alleen de C-003A-
routines zijn ook expliciet van `service_role` ingetrokken.

De securitytest vergelijkt de effectieve catalogusrechten met deze exacte
allowlist. Hij faalt bij een onverwachte private routine, clienttoegang tot een
interne C-003A-writer/lifecyclefunctie, een onverwacht bereikbare SECURITY
DEFINER of een bereikbare SECURITY DEFINER zonder `search_path=""`.

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
token, token digest, signed URL of volledige payload over. Row-level
before-triggers weigeren iedere directe `UPDATE` en `DELETE`; een afzonderlijke
`BEFORE TRUNCATE ... FOR EACH STATEMENT`-trigger weigert ook `TRUNCATE`. Alle
drie leveren `AUDIT_EVENTS_APPEND_ONLY`, ook bij rechtstreeks
database-ownergebruik.

## Deletion- en anonimiseringbasis

`public.request_profile_deletion(expected_row_version, correlation_id)`:

- leidt de actor server-side af en accepteert geen target profile-ID;
- vereist optimistic concurrency en een correlation-ID;
- zet `active` naar `deletion_pending`;
- verhoogt access- en row-version;
- auditeert atomair;
- levert bij retry dezelfde vastgelegde versions terug zonder tweede mutatie;
- auditeert een stale versionpoging idempotent met een technische code;
- bewaart alleen de exacte bestaande correlation-replay na de eerste aanvraag
  en weigert iedere nieuwe aanvraag vanuit `deletion_pending`,
  `auth_removal_pending` of `anonymized` met `ACTIVE_PROFILE_REQUIRED`;
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

De bestaande actieve workspace-stack is niet gereset. Alle databasehandelingen
zijn uitgevoerd in de disposable lokale stack
`/private/tmp/avaryn-c003a-hardening.u7IsRq`, project-ID
`avaryn-c003a-hardening-u7isrq`, met eigen poorten en zonder `.env`, link,
remote credentials of seed. Alleen de databasecontainer was nodig.

### Fresh build, C-003A en catalogus

1. `.flutterflow/sdk/bin/supabase db reset --local --no-seed --workdir
   /private/tmp/avaryn-c003a-hardening.u7IsRq`: **PASS**; alle migrations
   `202607250001` t/m de geharde `202608040001` bouwden vanaf een lege database.
2. `.flutterflow/sdk/bin/supabase test db
   supabase/tests/c003a_identity_audit_foundation.sql --local --workdir
   /private/tmp/avaryn-c003a-hardening.u7IsRq`: **PASS**;
   `Files=1, Tests=1, Result: PASS`.
3. `.flutterflow/sdk/bin/supabase db lint --local --level warning --workdir
   /private/tmp/avaryn-c003a-hardening.u7IsRq`: **PASS voor C-003A**. Alleen
   drie reeds bestaande warnings bleven staan: ongebruikte variabele
   `membership` in `public.pull_operation_changes` en
   `public.register_sync_device`, en `assignment_result` in
   `public.create_schedule_series_with_occurrences_v2`.
4. Read-only catalogusqueries op `pg_proc`, `pg_namespace`, `pg_class`,
   `pg_trigger`, `pg_policies`, `proacl`/`aclexplode` en de effectieve
   privilegefuncties: **PASS**. `profiles` en `audit_events` hebben RLS en owner
   `postgres`; private-schema-USAGE is `anon=false`, `authenticated=true`,
   `service_role=false`; effectieve private EXECUTE-aantallen zijn `0/19/0`;
   alle 96 routines hebben owner `postgres` en `search_path=""`; bereikbare
   onveilige SECURITY DEFINER-routines: `0`; beide append-onlytriggers zijn
   enabled en hebben de verwachte row-/statementdefinitie.

De uitgebreide C-003A-test gebruikt daadwerkelijk `SET LOCAL ROLE anon`,
`authenticated` en `service_role`. Voor iedere rol worden audit-`INSERT`,
`UPDATE`, `DELETE` en `TRUNCATE` geweigerd en blijven bestaande auditregels
staan. Directe aanroepen van de interne auditwriter en lifecyclefuncties worden
eveneens geweigerd. Database-owner-`UPDATE`, `DELETE` en `TRUNCATE` leveren
allemaal `AUDIT_EVENTS_APPEND_ONLY`, terwijl normale interne auditwriting blijft
werken.

Voor `deletion_pending`, `auth_removal_pending` en `anonymized` gebruikt de
test telkens het oorspronkelijke Auth-subject als `authenticated`, plus
gespoofde profile-/rolmetadata. Per status is bewezen dat
`private.current_profile_id()` null geeft, profile-RLS niets leest, een veilige
clientupdate nul rijen wijzigt en een nieuwe deletion-RPC-aanroep
`ACTIVE_PROFILE_REQUIRED` krijgt. `auth_removal_pending` is vóór Auth-unlink
getest; `anonymized` na unlink/finalisatie met de oude stale claim. Bestaande
idempotency-, version-, audit-, PII- en duurzame-actorcontroles blijven groen.

### Bestaande regressiesuite

De bestaande suite bevat zowel functionele eindstaattests als upgrade-fixtures.
Daarom zijn de upgradeparen met `supabase db reset --version <predecessor>` en
vervolgens `psql` fixture -> migration -> verification op hun historische
grens uitgevoerd. Alle acht paren zijn **PASS**:

- 4C.2A, 4C.2B, 4C.3, 4C.4, 4C.5 en 4C.6;
- 5B.2 en 5B.4.

Daarna is met `supabase db reset --local --no-seed --version 202607300001`
een schone laatste pre-C-003A-database gebouwd. Met `docker exec ... psql -X
-v ON_ERROR_STOP=1 -v avaryn_local_test=1 -f /dev/stdin` zijn alle bestaande
functionele SQL-tests uitgevoerd: 4A, beide 4B-tests, 4C.2A0, 4C.2A, 4C.2B,
4C.3, 4C.4, 4C.5, 4C.6, Phase 5 Alpha product recovery, 5B.1, 5B.2 en 5B.4.
Alle 14 zijn **PASS**.

De lokale fictieve Phase 5C-`basis`fixture (`3/3/6/1/1`) en verificatie zijn
**PASS**. Aansluitend zijn 5D.1, 5D.2, de browserfixture met een disposable
local-only credential en 5D.3 Realtime SQL uitgevoerd: alle **PASS**. Er is
geen `.env` gelezen en geen credential gelogd.

De zeven pure PostgreSQL-Ruby-concurrencytests zijn tegen dezelfde geïsoleerde
database uitgevoerd met `ruby supabase/tests/<test>.rb
supabase_db_avaryn-c003a-hardening-u7isrq`: alle **PASS**. Dit omvat 4B
membership (8/8 races), 4C.2A (20/20), 4C.2B (9/9), 4C.3 (10/10), 4C.4 (6/6),
4C.5 media (50/50) en 4C.6 realtime/offline sync (vier racegroepen elk
50/50). De Ruby Auth/Mailpit/Edge-Functionbestanden zijn integratietests, geen
databasetests, en zijn niet gestart.

Een verkennende directory-aanroep van `supabase test db supabase/tests` is niet
als gate gebruikt: die directory mengt pgTAP, gewone transactionele SQL,
persistente fixtures en fasegebonden upgradeverificaties, waardoor de pgTAP-
runner terecht `No plan found` meldt voor niet-pgTAP-bestanden. Een directe
`psql`-aanroep van de C-003A-pgTAP-test mist om dezelfde harnessreden de door
`supabase test db` geïnitialiseerde `extensions.plan`; de officiële enkel-
bestandrunner hierboven is groen. Oudere functionele tests die nog het bewust
vervangen Phase 4A-profilecontract gebruiken, zijn op de laatste pre-C-003A-
baseline getest; de nieuwe C-003A-test is op de volledige fresh build getest.

Alle migrations vóór `202608040001` bleven byte-for-byte ongewijzigd. Ook het
technische contract, `AGENTS.md`, FlutterFlow- en applicatiecode bleven
ongewijzigd.

## Securitygate en rollback

Formele status: **C-003A — Approved within the agreed scope**. De securitygate
is op `2026-08-05` handmatig beoordeeld en goedgekeurd. Alle C-003A
P0/P1/P2-securitybevindingen zijn binnen de afgesproken scope gesloten. RLS,
ACL's, server-side actorafleiding, audit-immutability inclusief `TRUNCATE`, de
private-routineallowlist, lifecycleversioning en de fail-closed
profilestatussen zijn onderdeel van die goedkeuring.

C-003A is gereed en vormt na deze statuscommit de goedgekeurde basis voor een
afzonderlijk op te dragen C-003B. De volgende beperkingen blijven expliciet
van kracht:

- productiebrede dependencycleanup is nog niet afgerond;
- de trusted deletion-orchestrator is nog niet geïmplementeerd;
- productieanonimisering mag daarom nog niet worden geactiveerd;
- de overkoepelende C-003F-securityaudit blijft verplicht.

Deze beperkingen vallen buiten de afgebakende C-003A-goedkeuring en maken haar
niet opnieuw pending.

Rollback is terugkeren naar de onveranderde basiscommit
`5eb07f54ffa7464f8f7e325f8b112411936298e8`. Snapshot, remote database,
staging, Supabase-linking, FlutterFlow, applicatiecode en live Alpha zijn niet
gewijzigd. Er is niets gepusht, gemerged of gedeployed.
