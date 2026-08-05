# C-003C — Canonical horses and relationships

## Status en scope

- Status: **C-003C — Implemented locally – awaiting next gate**.
- Datum lokale implementatie: `2026-08-05`.
- Branch: `implementation/account-model-v2-c003c-canonical-horses`.
- Goedgekeurde C-003B-basis:
  `dfcc8db085785b7de4bf38ce5457019f4dc1b887`.
- C-003B is in `CURRENT_STATE.md` vastgelegd als
  **Approved within the agreed scope**.
- Niet gestart: C-003D permissions/invitations, C-003E transfers en C-003F.

De implementatie bestaat uitsluitend uit de C-003C-migration, de C-003C SQL-
en concurrencytests, dit document en de statusregistratie. Het technische
contract, C-003A/C-003B-bronbestanden, oudere migrations/tests, Supabase-config,
FlutterFlow en applicatiecode zijn niet gewijzigd.

## Legacy-isolatie en canonieke aggregate

`public.horses` is een bestaande legacy aggregate met verplichte `stable_id`
en een brede FK-/functie-keten. Om die expliciet te behouden zonder
`stable_id` tot v2-authority te maken, gebruikt C-003C de afzonderlijke fysieke
tabel `public.canonical_horses`. Alle nieuwe C-003C-tabellen verwijzen alleen
naar deze aggregate; geen legacy horse-, stable-, membership-, client- of
JWT-veld participeert in de nieuwe permissionevaluatie.

Een canonical horse heeft precies één `NOT NULL`
`primary_authority_profile_id`, `access_version`, `authority_version` en
`row_version`. De actor en eerste primary authority worden bij creatie
uitsluitend server-side uit `auth.uid()` en het actieve C-003A-profile afgeleid.
De primary authority en `authority_version` zijn in C-003C immutable: transfers
horen bij C-003E. Optimistic concurrency en een database-trigger bewaken iedere
horse-update; versions zijn niet clientschrijfbaar. Deferred constraint
triggers op horses en profiles vereisen bovendien dat de scalar primary
authority actief blijft en blokkeren een inconsistente lifecycletransactie.

## Tabellen en betekenis

| Tabel | Betekenis | Autorisatiebron |
| --- | --- | --- |
| `canonical_horses` | Canonieke horse aggregate en scalar primary authority. | Primary authority. |
| `horse_delegated_administrators` | Tijdgeldige expliciete horse-permissions zonder transfer. | Ja, alleen de opgeslagen permissioncodes. |
| `horse_person_ownerships` | Juridische person ownership en historie. | Nooit. |
| `horse_organization_ownerships` | Juridische organization ownership en historie. | Nooit. |
| `horse_relationship_types` | Gecureerde semantische relatietypen. | Nooit. |
| `horse_person_relationships` | Tijdgeldige horse-person relaties. | Nooit. |
| `organization_horse_link_types` | Gecureerde professionele linktypen. | Nooit. |
| `organization_horse_links` | Wederzijds bevestigde contextlink met lifecycle. | Nooit. |
| `horse_residencies` | Afzonderlijke stable-residencyhistorie. | Nooit. |

Gecureerde relationshiptypes zijn `rider`, `trainer`, `groom`,
`care_provider` en `professional_treatment`. Linktypes zijn
`training_provider`, `veterinary_provider`, `farrier_provider`,
`care_provider` en `other`.

GiST-exclusionconstraints voorkomen overlappende actieve delegaties,
ownerships en relaties. Een partial unique index staat maximaal één actieve
residency per horse toe. Een residency-switch lockt de horse, beëindigt een
bestaande actieve residency en maakt de nieuwe atomair aan; de doelorganisatie
moet actief en van het gecureerde type `stable` zijn.

## Authority, permissions en zero implicit access

`has_canonical_horse_permission(uuid,text)` kent uitsluitend twee routes:

1. het actieve primary-authority-profile;
2. een actieve, tijdgeldige delegated-administratorrij met de gevraagde
   expliciete permissioncode.

De C-003C-codes zijn `horse.view`, `horse.edit`, `horse.manage`,
`horse.assign` en `horse.share`. `horse.transfer` wordt alleen voor de primary
authority geëvalueerd en kan niet worden gedelegeerd. Ownership, een rider- of
professional-relatie, organization ownership/membership, organization-horse
links en residency geven geen horse-permission. Deze bronnen geven hoogstens
minimale zichtbaarheid op de eigen relatie- of organizationcontext-rij; RLS
blijft het canonical-horse-record afschermen.

Delegatiegrant en -beëindiging vereisen de actuele primary authority, row-
versioning en een actief targetprofile. Zij roteren atomair horse- en betrokken
profile-`access_version` en schrijven allowlisted audit. C-003C implementeert
geen algemene horse permission grants of invitations; die horen bij C-003D.

## Organization links en lifecycle

Een voorstel kiest `horse` of `organization` als initiating context. De server
valideert die context tegen respectievelijk `horse.manage` of de bestaande
`organization.edit`; opgegeven context- of JWT-identifiers verlenen niets.
Alleen de initiating context wordt bij voorstel bevestigd. De tegengestelde,
server-geautoriseerde context kan binnen exact zeven dagen accepteren of
weigeren. Alleen twee contextbevestigingen maken de link `active`.

De lifecycle is `proposed -> active|rejected|withdrawn|expired` en
`active -> ended`. Terminal replay muteert niets. Alle transitions zijn
RPC-only, row-versioned en auditable. Ook een actieve link verleent geen horse-
of organizationpermission.

## RLS, ACL, audit en RPC-grens

RLS staat aan op alle negen nieuwe tabellen. `authenticated` heeft uitsluitend
RLS-beperkte `SELECT` en een expliciete public-RPC-allowlist. `anon` en
`service_role` hebben geen tabel- of RPC-pad. Geen clientrol heeft `INSERT`,
`UPDATE`, `DELETE` of `TRUNCATE`; alle kritieke writes lopen door
`SECURITY DEFINER`-RPC's met owner `postgres` en `search_path = ''`.
`private.c003c_*` is voor geen clientrol uitvoerbaar.

De bestaande append-only C-003A-auditallowlists zijn alleen met PII-vrije
C-003C-event-, resource-, reason- en metadatawaarden uitgebreid. Horse-audit
is alleen zichtbaar via `horse.view`; `TRUNCATE` blijft door de bestaande
C-003A owner-trigger geblokkeerd.

Publieke mutaties bestaan voor create/update horse, grant/end delegation,
start/end person- en organizationownership, start/end person relationship,
switch/end residency en propose/respond organization-horse link. Er is bewust
geen authority-transfer-, general-grant- of invitation-RPC.

## Verificatie

De gerichte ronde op een verse geïsoleerde lokale database is groen:

- volledige migrationketen vanaf leeg, inclusief C-003C;
- C-003C pgTAP securitymatrix;
- echte gelijktijdige optimistic-concurrency-race: één winnaar en één
  `STALE_HORSE_VERSION`, zonder deadlock;
- C-003A- en C-003B-pgTAP-regressies;
- legacy stable RLS, horse core en horse identity/relationship SQL-regressies;
- spoofing, inactive profiles, cross-horse/-organization isolation,
  authoritymutation, relationship escalation, direct DML/TRUNCATE, stale
  versions, invalid/overlappende tijdvensters, terminal replay en exacte
  EXECUTE/RLS/ACL/routinecataloguschecks.

Er zijn geen bekende open P0/P1/P2-bevindingen binnen de afgebakende lokale
C-003C-scope. Er is niets gelinkt, gepusht, gemerged, gedeployed of remote
uitgevoerd; C-003D is niet gestart.
