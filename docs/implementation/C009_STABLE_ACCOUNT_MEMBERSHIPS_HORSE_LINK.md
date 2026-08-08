# C-009 — Stalaccount, memberships, rollen en paard-stalkoppeling

Startdatum: `2026-08-08`

Startbasis: C-008-eindcommit
`318a0f6a1f5429d2cc1f09da879129c0aa1d5e33`.

Status: **C-009 — Approved within the current Alpha/Staging scope**.

Formele uitkomst: **STABLE ACCOUNT / MEMBERSHIP / HORSE LINK ROUTE = PASS**.

## Afbakening en hergebruik

C-009 bouwt geen tweede organization-, membership-, permission-, invitation-,
horse-link-, residency- of transfermodel. De goedgekeurde C-003B/C/D/E-
aggregates en state machines blijven leidend. Alleen personen authenticeren;
een stalaccount is een zelfstandige canonical organization zonder login of
gedeelde credentials.

- Exact één scalar Organization Authority blijft verplicht.
- Membership, rol, link en residency blijven afzonderlijke concepten.
- Een membership, role template, actieve paard-stalkoppeling of residency
  verleent nooit impliciete paardtoegang.
- Paardtoegang vereist een afzonderlijke, scoped horse grant van Horse
  Authority en blijft server-side gecontroleerd.
- Organization Authority wordt uitsluitend via de bestaande zeven dagen
  geldige, tokengebonden en concurrency-safe C-003E-route overgedragen.
- Planning, Voeding, C-007 Auth en C-008 Horse Authority zijn niet herbouwd.

## Implementatie

- Forward-only migration `202608080002_c009_stable_account_vertical.sql`
  introduceert zeven aanvullende organizationcapabilities en begrensde
  `stable_admin`, `stable_manager`, `stable_worker` en `stable_viewer`-
  templates. Alleen de bestaande reserved head-adminrol wordt met alle nieuwe
  capabilities uitgebreid; custom rollen worden niet verbreed of overschreven.
- Authenticated-only RPC's maken en projecteren stalaccounts, maken
  uitnodigingen via een niet-reserved role template, tonen bilaterale
  paard-stalkoppelingen en initiëren authority-transfer op verified e-mail.
  Actor en authority worden steeds server-side afgeleid.
- C-009-responsewrappers hergebruiken de bestaande invitation- en
  authority-transferstatemachines. Zij corrigeren uitsluitend de nieuw
  geaccepteerde membership-/rolactivatie naar dezelfde statementtimestamp,
  zodat een atomaire vervolgstap niet tijdelijk fail-closed op een latere
  `clock_timestamp()`-default. Status, token, locks, CAS, audit en terminale
  historie blijven van C-003D/E.
- De stalworkspace filtert memberships, rollen, audit en capabilities op het
  expliciete organizationrecht. Paardnamen blijven verborgen zonder
  `horse.view`; horse grant-targets zijn alleen zichtbaar voor een expliciete
  horse manager.
- De Nederlandse online-first runtime ondersteunt stal aanmaken en bewerken,
  one-time invitations, membershipstatus, role capabilities, bilaterale
  paard-stalkoppeling, afzonderlijke residency, expliciete horse grants en
  Organization Authority-transfer. Tokens blijven alleen tijdelijk in geheugen.
- De C-008-paardenruntime kreeg uitsluitend de wederkerige horse-zijde van de
  link- en grantflow. Canonical horse, Horse Authority, relaties, Planning,
  Voeding en private media bleven inhoudelijk ongewijzigd.

## Security- en concurrencybewijs

- Fresh migration build vanaf nul: **PASS**.
- C-003A/B/C/D/E/F-, C-004-, C-007- en C-008-securityregressies: **PASS**.
- C-009 Reimer Dressage-scenario voor zelfstandige organization, creator-
  authority, role templates, verified invitation, bilaterale link, expliciete
  horse grant, onafhankelijke residency en authority-transfer: **PASS**.
- Organization invitation-, horse transfer- en organization transfer-races:
  **PASS**; exact één winnaar en terminale replaydeny.
- RLS/ACL/EXECUTE, private-helperdeny, actor-spoofdeny, cross-resource-isolatie,
  stale-versiondeny, idempotency, revocation, append-only audit en
  membership-/link-/residency-implies-no-access: **PASS**.
- Volledige FlutterFlow/Dart-regressiesuite: **192/192 PASS**.
- Custom-widgetanalyse tegen de gegenereerde Flutterdependencies: **PASS**.
- `git diff --check` en secretscan: **PASS**.

Er zijn geen bekende open C-009 P0/P1/P2-code-, data- of
securitybevindingen.

## Staging en Alpha

- Migration `202608080002_c009_stable_account_vertical` met SHA-256
  `3b2ad6c378b09e36ffcf10d499fa1bcb7efe3d4702cedb9f6fbbe6fcb75d396b`
  is transactioneel op exact Supabaseproject `ipdovjdtnfslrftvrdrl`
  (`AVARYN Staging`) toegepast en aan de migrationhistorie gebonden.
- De volledige hosted C-009-security- en Reimer Dressage-matrix is in één
  teruggerolde transactie uitgevoerd: **PASS**. De postcheck bewijst nul
  C-009-testusers, nul benoemde fixture-organizations, authenticated-only RPC's,
  nul public/service-role execute-grants en exact de zeven capabilities.
- FlutterFlow-projectcommit `HssI1OiCUzJNn9p7t2ya` is gevalideerd op project
  `a-v-a-r-y-n-alpha-ynvyuq` en naar uitsluitend de bestaande Alpha-hosts
  gepubliceerd.
- De cachevrije custom-domainroute `/stallen` toont de nieuwe C-009-runtime;
  create-, empty- en bestaande paardenregressieroutes zijn technisch groen.
  Een al geopende fallbackclient hield tijdelijk de vorige serviceworkerbuild
  vast; de FlutterFlow-publicatie zelf eindigde voor beide Alpha-domeinen met
  `Published Successfully`.
- Silas heeft de C-009 scherm- en cutoverreview op `2026-08-08` expliciet
  goedgekeurd voor de huidige Alpha/Staging-scope.

Er is geen persistente testfixture achtergebleven. Productie, Git-push en merge
zijn niet uitgevoerd. C-010 is niet gestart.
