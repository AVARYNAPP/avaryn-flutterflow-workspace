# C-003B — Organizations and memberships

## Status en begrenzing

- Status: **C-003B — Implemented locally – awaiting Silas security approval**.
- Datum lokale implementatie: `2026-08-05`.
- Branch: `implementation/account-model-v2-c003b-organizations-memberships`.
- Goedgekeurde C-003A-basiscommit:
  `cabf649ce34099b5aee7537652cbb667113f93fc`.
- Scope: organization types, organizations, scalar primary admin,
  memberships, organizationrollen en -permissions, role assignments,
  beveiligde creatie, minimale lifecyclemutaties, RLS, ACL, versions en audit.
- Niet gestart: C-003C canonical horses/relationships, C-003D invitations,
  C-003E transfers en C-003F brede securitygate.

De implementatie staat uitsluitend in:

- `supabase/migrations/202608050001_c003b_organizations_memberships.sql`;
- `supabase/tests/c003b_organizations_memberships.sql`;
- dit document;
- `docs/status/CURRENT_STATE.md`.

De C-003A-migration en -test, alle oudere migrations en tests, het technische
contract, `AGENTS.md`, Supabase-configuratie, FlutterFlow en applicatiecode
bleven ongewijzigd.

## Preflight en legacy-inventaris

De startcontrole vond exact branch
`implementation/account-model-v2-c003a-identity-audit`, HEAD
`cabf649ce34099b5aee7537652cbb667113f93fc`, een schone werkboom en exact één
tracked `ACCOUNT_MODEL_V2_TECHNICAL_CONTRACT.md`. De C-003B-doeltabellen,
migration, test en implementatiedocumentatie bestonden nog niet.

De catalogusinventaris vond de legacy tabellen `stables`, `stable_members` en
`stable_memberships`, met RLS, policies, triggers en een brede FK-/functieketen
naar horses, planning, feeding, media, realtime/offline sync en invitations.
Die objecten zijn niet gewijzigd, vervangen, verwijderd of als v2-authority
hergebruikt. De nieuwe organizationlaag heeft geen `stable_id`-kolom en geen
autorisatiepad via legacy memberships, clientstate of JWT-metadata.

De bestaande C-003A-objecten `profiles`, `audit_events`, de Auth-afleiding en
de private routinegrens zijn hergebruikt. De nieuwe migration breidt alleen de
auditallowlists en de servermatige profile-`access_version`-rotatie begrensd
uit; het C-003A-bronbestand zelf is niet gewijzigd.

## Schema en referentiedata

| Tabel | Functie |
| --- | --- |
| `organization_types` | Immutable gecureerde organisatietypen. |
| `organizations` | Organisatieaggregate, scalar primary admin, status, access- en row-version. |
| `organization_memberships` | Profile-organizatiemembership met lifecycle en tijdvenster. |
| `permission_definitions` | Organization-scoped permissiontaxonomie. |
| `organization_roles` | Organisatiespecifieke expliciete rollen. |
| `organization_role_permissions` | Expliciete role-permissionkoppelingen. |
| `organization_membership_roles` | Tijdgeldige role assignments per membership. |

Exact geseed en door clients niet muteerbaar zijn:

- `stable`;
- `trainer_practice`;
- `farrier_business`;
- `veterinary_practice`;
- `other_professional`.

Alle identiteiten zijn duurzame server-generated UUID's. Tijden zijn
`timestamptz`. FK's gebruiken `RESTRICT` waar identity/authority niet stil mag
verdwijnen. Statuschecks, row-/access-versionminimums, status-tijdvormen,
same-organization composite FK's en indexes ondersteunen het contract.
`btree_gist`-exclusionconstraints voorkomen overlappende actieve membership-
en assignmentvensters. Uniques voorkomen dubbele organization role codes en
correlationreplays.

## Primary-admininvariant

`organizations.primary_admin_profile_id` is `NOT NULL`, een scalar FK naar
`profiles(id)` met delete-restrict en heeft geen client-schrijfgrant of
transfer-RPC.

Vijf `DEFERRABLE INITIALLY DEFERRED` constraint triggers bewaken changes aan
organizations, memberships, roles, assignments en profiles. Bij transaction
commit moet de actuele primaire beheerder:

- een actief profile zijn;
- een actieve, actuele en onbegrensde membership in dezelfde organization
  hebben;
- een actieve, actuele en onbegrensde assignment hebben;
- daarmee de actieve gereserveerde systemrol `head_admin` in dezelfde
  organization bezitten.

De membershipstatus-RPC weigert suspend/end van de actuele primaire
beheerder. De role- en assignment-RPC's weigeren iedere clientmutatie van de
gereserveerde head-adminrol. Owner-level negatieve tests forceren de deferred
trigger naar `IMMEDIATE` en bewijzen dat een inconsistente transactie niet kan
committen.

## Atomaire organisatiecreatie

`public.create_organization(text,text,text,uuid,jsonb)`:

1. leidt de actor uitsluitend af via de C-003A-keten `auth.uid()` -> exact één
   actief profile;
2. negeert actor-, primary-admin-, organization- en legacy-ID's in het
   allowlisted object `p_client_context`;
3. serialiseert dezelfde actor/correlation met een transactioneel advisory
   lock;
4. valideert een actief gecureerd organization type;
5. maakt organization, actor-membership, gereserveerde `head_admin`, alle
   C-003B-permissions, assignment en audit in één transactie;
6. roteert de profile-`access_version` van de actor;
7. retourneert bij dezelfde correlation de bestaande aggregate als
   `idempotent_replay`.

Een fout rolt de volledige statement/transactie terug. Parallelle sessies met
dezelfde correlation leverden exact één organization en `created` plus
`idempotent_replay` op.

## Permissionmatrix

| Permission | Klasse | Betekenis |
| --- | --- | --- |
| `organization.view` | view | Organization lezen. |
| `organization.edit` | edit | Metadata/status wijzigen. |
| `organization.memberships.view` | view | Memberships lezen. |
| `organization.memberships.manage` | manage | Memberships aanmaken en lifecycle wijzigen. |
| `organization.roles.view` | view | Rollen en role permissions lezen. |
| `organization.roles.manage` | assign | Rollen, permissions en assignments beheren. |
| `organization.audit.view` | view | Organization-audit lezen. |

De primaire beheerder krijgt via de gereserveerde `head_admin` alle zeven
permissions. Andere admins/members krijgen alleen permissions via expliciete,
actieve en tijdgeldige roles. Membership alleen geeft geen onbeperkte toegang.
Een actor kan uitsluitend een als grantable gemarkeerde permission toekennen
die de actor zelf effectief bezit. Horsepermissions bestaan niet in C-003B.

## Lifecycle en RPC's

Memberships ondersteunen:

- create/activate: `active` met `valid_from`;
- `active -> suspended -> active`;
- `active|suspended -> ended`, met `valid_until` en allowlisted reason code.

Assignments ondersteunen:

- grant als `active` met `valid_from`;
- `active -> revoked|ended`, met `valid_until`, actor en reason code.

Rollen ondersteunen `active -> archived` en kunnen alleen als niet-reserved
weer naar `active`. Iedere status-/permission-/assignmentmutatie lockt het
actuele doelrecord waar nodig, controleert `row_version` of steunt voor nieuwe
records op unieke/exclusionserialisatie, roteert access versions bij veranderd
effectief access en schrijft audit.

Publieke client-RPC's/signatures:

```text
has_organization_permission(uuid, text)
create_organization(text, text, text, uuid, jsonb)
update_organization(uuid, bigint, text, text, text, uuid)
create_organization_membership(uuid, uuid, timestamptz, uuid)
set_organization_membership_status(uuid, bigint, text, text, uuid)
create_organization_role(uuid, text, text, text, text[], uuid)
set_organization_role_status(uuid, bigint, text, uuid)
set_organization_role_permission(uuid, bigint, text, boolean, uuid)
grant_organization_membership_role(uuid, uuid, timestamptz, uuid)
revoke_organization_membership_role(uuid, bigint, boolean, uuid)
```

Er is bewust geen invitation-, acceptatie-, e-mail-, token-, horse- of
primary-admintransfer-RPC.

## RLS, ACL en routinebeveiliging

RLS staat aan op alle zeven nieuwe tabellen. Leestoegang vereist gelijktijdig
een actief profile, actieve organization, actuele actieve membership, actuele
actieve assignment, actieve role en de vereiste actieve permission. Een
membership kan zijn eigen membership/assignment minimaal zien; beheerlezingen
vereisen de expliciete viewpermission. Organization-audit vereist
`organization.audit.view`.

| Rol | Tabellen | RPC's | Interne `private.c003b_*` |
| --- | --- | --- | --- |
| `anon` | geen grants | geen EXECUTE | geen USAGE/EXECUTEpad |
| `authenticated` | alleen RLS-beperkte `SELECT` | expliciete allowlist hierboven | geen EXECUTE |
| `service_role` | geen grants | geen EXECUTE | geen EXECUTE |
| `postgres` | owner/trusted mutation | intern | intern |

Er zijn geen client-`INSERT`, `UPDATE`, `DELETE` of `TRUNCATE`-grants en geen
writepolicies. `FORCE RLS` is bewust niet gebruikt omdat de trusted
`SECURITY DEFINER`-writers als owner door de read-only clientpolicies heen
moeten kunnen muteren; clientrollen hebben geen owner/bypasspad.

De catalogusgate vond 7/7 tabellen met owner `postgres` en RLS, vijf enabled
deferred primary-admintriggers, zeven C-003B-private routines en tien publieke
helpers/RPC's. Alle routines hebben owner `postgres` en vaste
`search_path=""`; alle muterende/private routines gebruiken gekwalificeerde
objectnamen. Geen `private.c003b_*` is effectief uitvoerbaar door `PUBLIC`,
`anon`, `authenticated` of `service_role`. De bestaande C-003A-private
clientallowlist is niet uitgebreid.

## Access versions en concurrency

- `organizations.access_version BIGINT NOT NULL DEFAULT 1` stijgt bij iedere
  mutatie die effective access kan veranderen.
- De `access_version` van ieder profile wiens effective access verandert,
  stijgt in dezelfde transactie.
- De C-003B-migration breidt de C-003A-profiletrigger alleen uit voor een
  servermatige access-only `+1`; clientkolom-ACL's blijven de kolom blokkeren.
- `row_version` is monotone optimistic concurrency op organization,
  membership, role en assignment; role-permissionmutaties vereisen de
  verwachte role-row-version.
- Versions zijn niet rechtstreeks clientschrijfbaar en kunnen niet dalen.

Drie aparte parallelle C-003B-races bewezen: dezelfde create-correlation geeft
één aggregate; twee gelijktijdige actieve memberships voor organization/profile
geven één winnaar; twee gelijktijdige gelijke role codes geven één winnaar.
Advisory locking, unique constraints en GiST-exclusionconstraints vormen de
databasegrens, niet clientcoördinatie.

## Audit

De C-003A-`audit_events`-allowlists zijn uitgebreid met:

- `organization.created`, `organization.updated`;
- `organization.membership_created` en
  `organization.membership_status_changed`;
- `organization.role_created` en `organization.role_status_changed`;
- `organization.role_permission_granted|revoked`;
- `organization.membership_role_granted|revoked`;
- `organization.access_changed`.

Events leggen actor profile, resource, organization scope, correlation,
reason, relevante row-/access-versions en uitsluitend allowlisted metadata
vast: `operation_code`, `role_code`, `permission_code` en technische
`target_profile_id`. Namen, e-mails, tokens, vrije tekst en signed URLs worden
niet geschreven. De bestaande C-003A append-only row- en statementtrigger
blijft `UPDATE`, `DELETE` en `TRUNCATE` weigeren.

## Lokale verificatie

Alle databasehandelingen gebruikten uitsluitend de disposable lokale stack
`/private/tmp/avaryn-c003b-preflight.1E0wGZ`, project-ID
`avaryn-c003b-preflight-1e0wgz`, met afwijkende lokale poorten. Er is geen
`.env` gelezen, geen Supabase-project gelinkt en niets remote uitgevoerd.

Uitgevoerde gates en resultaten:

1. `supabase db reset --no-seed --workdir ...`: **PASS**; alle migrations van
   `202607250001` t/m `202608050001` bouwden vanaf een lege database.
2. `supabase test db .../c003b_organizations_memberships.sql`: **PASS**;
   `Files=1, Tests=1, Result: PASS`.
3. Ongewijzigde `c003a_identity_audit_foundation.sql`: **PASS**;
   `Files=1, Tests=1, Result: PASS`.
4. Drie C-003B parallelle multi-sessionraces: **PASS** voor idempotente create,
   dubbele actieve membership en dubbele role code.
5. Veertien bestaande functionele SQL-tests op de fase-correcte laatste
   pre-C-003A-baseline: **PASS**.
6. Acht upgradeparen 4C.2A, 4C.2B, 4C.3, 4C.4, 4C.5, 4C.6, 5B.2 en 5B.4:
   **8/8 PASS**.
7. Zeven bestaande PostgreSQL-Ruby-concurrencysuites: **PASS** met 8/8,
   20/20, 9/9, 10/10, 6/6, 50/50 en vier racegroepen van 50/50.
8. Phase 5C `basis`-fixture/verificatie (`3/3/6/1/1`) en 5D.1, 5D.2,
   browserfixture en 5D.3 Realtime: **PASS**. Het lokale browserwachtwoord was
   vluchtig, niet gelogd en niet opgeslagen.
9. `supabase db lint --local --level warning`: **PASS voor C-003B**; geen
   C-003B-warning/error. Alleen de drie reeds bestaande warnings bleven:
   `membership` in `pull_operation_changes` en `register_sync_device`, en
   `assignment_result` in `create_schedule_series_with_occurrences_v2`.
10. Read-only catalogusgate voor RLS, policies, owners, ACL's, triggers,
    routineconfiguraties en effectieve privileges: **PASS**.
11. `git diff --check`, volledige basisdiff en toegestane-bestandencontrole:
    **PASS**; exact de vier toegestane bestanden.

De oudste functionele profiletest is bewust niet op de post-C-003A-schemafase
geïnterpreteerd: die verwacht de vóór C-003A bestaande directe schrijfrechten.
Net als bij de goedgekeurde C-003A-gate draaide de legacy functionele suite op
`202607300001`; C-003A en C-003B draaiden vervolgens op de volledige fresh
build.

## Bekende beperkingen en uitgestelde onderdelen

- C-003B bevat geen canonical horses/relationships (C-003C).
- Invitations, e-mail-/tokenflows en acceptatie horen bij C-003D.
- Primary-admin- en andere transfers horen bij C-003E.
- De productiebrede dependencycleanup en trusted deletion-orchestrator zijn
  nog niet gereed; productieanonimisering blijft uitgeschakeld.
- De brede C-003F-securityaudit en handmatige C-003B-securitygoedkeuring
  blijven verplicht.
- Legacy stabledata is niet gemigreerd en geeft geen v2-authority.

Er resteren na de lokale gate geen bekende P0/P1/P2-securitybevindingen binnen
de afgebakende C-003B-scope. Dit is nog geen formele securitygoedkeuring.
