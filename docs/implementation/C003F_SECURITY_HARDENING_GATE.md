# C-003F — Security hardening gate

## Uitkomst

- Status: **C-003F — PASS; Approved within the agreed scope**.
- Datum: `2026-08-05`.
- Scope: onafhankelijke lokale eindgate over C-003A tot en met C-003E.
- Open C-003 P0/P1/P2-bevindingen: **geen**.

## Bewijs

De fase-onafhankelijke fresh build paste alle migrations vanaf een lege,
geïsoleerde lokale database toe. De bestaande positieve/negatieve A–E-pgTAP-
suites zijn afzonderlijk groen voor identity/actors, organizations/memberships,
canonical horses/authority, permissions/invitations en transfers. De bestaande
C- en D-races en de nieuwe E-races zijn groen; idempotency, expiry, stale
versions, terminal replay, revoke, access-versionrotatie, cross-tenantdeny,
JWT-spoofing en service-role/Edge-misbruik zijn daardoor zonder dubbele tests
afgedekt.

De catalogusgate bevestigt voor alle 27 C-003-tabellen RLS en `postgres`-
ownership, geen client-`INSERT`/`UPDATE`/`DELETE`/`TRUNCATE`, RPC-only
transfertabellen, exact de bestaande private authenticated-helperallowlist en
geen private C-003-mutator-EXECUTE. Alle `SECURITY DEFINER`-routines in
`public`/`private` hebben `search_path = ''`. De acht transfer-RPC's hebben
getypeerde `TABLE(...)`-resultaten, uitsluitend authenticated EXECUTE en zijn
daarmee read-only technisch geschikt voor latere FlutterFlow-consumptie;
FlutterFlow zelf is niet uitgevoerd of gewijzigd.

Audit blijft append-only inclusief een actieve statement-trigger tegen
`TRUNCATE`. Geen C-003-tabel staat rechtstreeks in een realtime-publication;
gevoelige domeinpayloads hebben dus geen direct realtimepad. Revoke/end en
transfers roteren de actuele profile-, horse- en organization-
`access_version`; een oude clientprojectie verleent nooit toegang omdat iedere
refetch opnieuw onder actuele RLS/RPC-authority valt.

De read-only queryplancontrole gebruikte de bedoelde indexes:

- `horse_authority_transfers_token_unique` en
  `horse_authority_transfers_pending_unique`;
- `organization_authority_transfers_token_unique` en
  `organization_authority_transfers_pending_unique`;
- `organization_memberships_profile_idx`;
- `horse_profile_grants_no_overlap`.

De C-003F-exitcriteria zijn volledig PASS. Er zijn geen gerichte hardeningfixes
na de brede gate nodig gebleken.

## Resterende afbakening

Productiebrede deletion-dependencycleanup en de trusted deletion-orchestrator
zijn nog niet geïmplementeerd; productieanonimisering blijft daarom uit. Dit is
een reeds vastgelegde productie-activatiebeperking en geen open P0/P1/P2 binnen
de lokaal goedgekeurde C-003-scope. Er is geen front-endimplementatie,
stagingreset, remote migration, deployment of C-004 uitgevoerd.
