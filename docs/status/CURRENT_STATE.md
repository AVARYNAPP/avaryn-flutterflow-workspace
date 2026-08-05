# AVARYN — Current State

Laatst bijgewerkt: 2026-08-05

## Huidige status

- **C-001:** afgerond. De read-only architectuuraudit adviseert het bestaande
  FlutterFlow-project te behouden en de stalgebonden backend grotendeels schoon
  te vervangen voor Account Model v2.
- **C-002:** technisch contract opgesteld.
- **C-002A:** formele reviewcorrecties op het technische contract uitgevoerd,
  inhoudelijk beoordeeld en definitief goedgekeurd door Silas de Steur op
  2026-08-04.
- **C-002A-besluit:** een organization-horse link wordt pas actief nadat de
  horse- en organizationcontext ieder afzonderlijk, expliciet en server-side
  geautoriseerd hebben bevestigd. De link zelf verleent geen toegang.
- **C-002B:** uitsluitend de lokale approval-statuscommit; geen wijziging van
  de goedgekeurde normatieve technische inhoud.
- **Contractstatus:** **Approved**.
- **Goedgekeurde inhoudscommit:**
  `4288944ae77cee9e1f0bf42f9369956b342e0097`.
- **C-003A:** lokaal geïmplementeerd en formeel goedgekeurd op de afzonderlijke
  taskbranch.
- **C-003A-status:** **Approved within the agreed scope**.
- **Datum securitygoedkeuring:** `2026-08-05`.
- **Goedgekeurde C-003A-implementatiecommit:**
  `7ecddccb6cf7dabea2a6597d8245b707f6110ff4`.
- **Goedgekeurde C-003A-hardeningcommit:**
  `09e3d1ef1f2efe30a94afd1ea23df4c7da6f724c`.
- Geïmplementeerd zijn uitsluitend duurzame personal profiles, de unieke
  nullable koppeling met `auth.uid()`, veilige Auth-provisioning, profile-
  lifecycle en versions, server-side actorafleiding, fail-closed profile-RLS,
  kolomgrants, append-only allowlisted audit en de lokale herstelbare
  deletion-/anonimiseringsbasis.
- De volledige migrationketen bouwt groen vanaf een lege geïsoleerde lokale
  database en de positieve/negatieve C-003A-securitytest is groen.
- De C-003A-security-hardening na handmatige review is lokaal uitgevoerd:
  `audit_events` is nu ook tegen owner-`TRUNCATE` beschermd, de volledige
  private-routine-inventaris (96 functies) heeft een catalogusgestuurde exacte
  allowlist en daadwerkelijke `anon`-/`authenticated`-/`service_role`-tests,
  en alle drie niet-actieve profilestatussen zijn expliciet fail-closed getest.
- De fresh build, bestaande fase-correcte SQL- en upgrade-regressies, zeven
  databaseconcurrencytests, C-003A-pgTAP-test, lint en catalogus-securitygate
  zijn groen. Alle C-003A P0/P1/P2-securitybevindingen zijn binnen de
  afgesproken scope gesloten.
- RLS, ACL's, server-side actorafleiding, audit-immutability inclusief
  `TRUNCATE`, de private-routineallowlist, lifecycleversioning en fail-closed
  profilestatussen zijn handmatig beoordeeld en goedgekeurd.
- Productiebrede dependencycleanup is nog niet afgerond en de trusted
  deletion-orchestrator is nog niet geïmplementeerd. Productieanonimisering mag
  daarom nog niet worden geactiveerd. De overkoepelende C-003F-securityaudit is
  op 2026-08-05 geslaagd. Deze productie-activatiebeperkingen maken de
  afgebakende C-003-goedkeuring niet opnieuw pending.
- C-003A is gereed en vormt na deze statuscommit de goedgekeurde basis voor een
  afzonderlijk uitgevoerde C-003B.
- **C-003B-status:** **C-003B — Approved within the agreed scope**.
- **Goedgekeurde C-003B-implementatiebasis:**
  `dfcc8db085785b7de4bf38ce5457019f4dc1b887`.
- C-003B implementeert lokaal de geïsoleerde organizationlaag met exact vijf
  organization types, organizations, verplichte scalar primary admin,
  memberships, organizationrollen en -permissions, role assignments,
  atomaire idempotente creatie, deferred primary-admininvariant, RLS/ACL,
  access-/row-versioning en PII-arme organization-audit.
- De C-003B-fresh build, C-003A- en C-003B-securitytests, fase-correcte
  functionele/upgrade-/concurrencyregressies, lint en catalogusgate zijn groen.
  Er zijn geen bekende open P0/P1/P2-bevindingen binnen de lokale afgebakende
  C-003B-scope; de implementatie is binnen die scope goedgekeurd.
- Legacy `stable_id` en stable memberships verlenen geen C-003B-authority en
  de bestaande stable-/horse-/applicatieobjecten bleven ongewijzigd.
- **C-003C-status:** **C-003C — Approved within the agreed scope**.
- **Goedgekeurde C-003C-implementatiecommit:**
  `1321da6366018d9d8a0a203a2fefde188ce7be69`.
- C-003C implementeert naast de ongewijzigde legacy `public.horses`-aggregate
  de geïsoleerde `canonical_horses`, exact één scalar primary authority,
  expliciete gedelegeerde horse-administratie, juridische ownerships,
  semantische horse-person relationships, residencyhistorie en wederzijds
  bevestigde organization-horse links. Alleen primary authority en expliciete,
  actuele delegated permissions verlenen C-003C-horse-access.
- Ownership, relationships, organization links, residency, legacy `stable_id`,
  clientstate en JWT-metadata verlenen geen impliciete horse-toegang.
- De C-003C-fresh build, securitytest, concurrency-race, gerichte C-003A/C-003B-
  regressies en legacy stable-/horse-regressies zijn groen. Er zijn geen bekende
  open P0/P1/P2-bevindingen binnen de lokale afgebakende C-003C-scope.
- C-003C is op basis van de uitgevoerde implementatie- en securitychecks
  goedgekeurd binnen de afgesproken scope en vormt de basis voor C-003D.
- **C-003D-status:** **C-003D — Approved within the agreed scope**.
- **Goedgekeurde C-003D-implementatiecommit:**
  `e940e956144cfa666be12f6d5c6d7ea383b44d20`.
- C-003D voegt expliciete tijdgeldige horse grants voor profiles en actieve
  organizationrollen toe, plus fail-closed organization- en horse-invitations
  met server-side actorafleiding, verified-Auth-e-mailbinding, HMAC-opslag,
  actuele authority-hercontrole, one-time tokens, lifecycleversioning en
  PII-arme audit. Relationships en organization-horse links kunnen grants
  uitsluitend begrenzen en bij beëindiging revoken; zij verlenen zelf niets.
- De afzonderlijke Rider Performance profile-/role-sharelaag is als expliciete
  securitygrens aanwezig; de feitelijke datamodule valt buiten C-003D.
- De C-003D-fresh build, securitytest, invitation-concurrencyrace, direct
  geraakte C-003A/B/C-regressies en catalogus-/RLS-/ACL-/EXECUTE-controles zijn
  groen. Er zijn geen bekende open P0/P1/P2-bevindingen binnen de afgebakende
  lokale C-003D-scope.
- **C-003E-status:** **C-003E — Approved within the agreed scope**.
- C-003E implementeert RPC-only, zeven dagen geldige horse-authority- en
  organization-headtransfers met server-side actorafleiding, HMAC-tokens,
  resource- en transferlocks, stale-versiondeny, idempotency, terminale
  immutable historie, versionrotatie en append-only audit. Organization-
  acceptatie wisselt membership, reserved head-adminrol en scalar primary admin
  atomair onder de deferred invariant.
- De C-003E-pgTAP-matrix en simultane acceptatieraces zijn groen: per transfer
  bestaat exact één winnaar, één terminale replaydeny en één scalar/version-
  overgang. Er zijn geen bekende C-003E P0/P1/P2-bevindingen.
- **C-003F-status:** **C-003F — PASS; Approved within the agreed scope**.
- De brede C-003F-eindgate over A–E is groen voor fresh build, volledige
  positieve/negatieve securitymatrices, concurrency, idempotency, expiry,
  spoofing, cross-tenantdeny, revocation/access-versioncache, service-role-
  misbruik, RLS/ACL/EXECUTE, `SECURITY DEFINER`, audit, gesloten directe
  realtimepaden, typed RPC-projecties en queryplannen.
- **C-003-status:** **C-003 — Fully completed; Approved within the agreed
  scope**. Er zijn geen bekende open C-003 P0/P1/P2-problemen.
- Er is niets remote uitgevoerd, geen stagingreset gedaan en geen FlutterFlow-
  of applicatiecode gewijzigd voor C-003A tot en met C-003F.
- Er is niets gepusht, gemerged of gedeployed als onderdeel van deze lokale
  C-003-uitvoering. C-004 is niet gestart.

Het goedgekeurde contract staat in
[Account Model v2 Technical Contract](../architecture/ACCOUNT_MODEL_V2_TECHNICAL_CONTRACT.md).

## Repository- en FlutterFlow-basis

| Onderdeel | Waarde |
| --- | --- |
| Immutable snapshotbranch | `snapshot/latest-alpha-2026-08-04` |
| Snapshotcommit | `1634ef281084a76ae862fcb595dff8b08048ff48` |
| Actieve architectuurbranch | `architecture/account-model-v2-contract` |
| C-002A-basiscommit | `dc93b1c574eab185a95f9aa5113e65415d784d2a` |
| Goedgekeurde inhoudscommit | `4288944ae77cee9e1f0bf42f9369956b342e0097` |
| C-003A-branch | `implementation/account-model-v2-c003a-identity-audit` |
| C-003A-basiscommit | `5eb07f54ffa7464f8f7e325f8b112411936298e8` |
| Goedgekeurde C-003A-implementatiecommit | `7ecddccb6cf7dabea2a6597d8245b707f6110ff4` |
| Goedgekeurde C-003A-hardeningcommit | `09e3d1ef1f2efe30a94afd1ea23df4c7da6f724c` |
| C-003A-approvalstatuscommit / C-003B-basis | `cabf649ce34099b5aee7537652cbb667113f93fc` |
| C-003B-branch | `implementation/account-model-v2-c003b-organizations-memberships` |
| Goedgekeurde C-003B-implementatiebasis | `dfcc8db085785b7de4bf38ce5457019f4dc1b887` |
| C-003B-status | `Approved within the agreed scope` |
| C-003C-branch | `implementation/account-model-v2-c003c-canonical-horses` |
| Goedgekeurde C-003C-implementatiecommit | `1321da6366018d9d8a0a203a2fefde188ce7be69` |
| C-003C-status | `Approved within the agreed scope` |
| C-003D-branch | `implementation/account-model-v2-c003d-permissions-invitations` |
| Goedgekeurde C-003D-implementatiecommit | `e940e956144cfa666be12f6d5c6d7ea383b44d20` |
| C-003D-status | `Approved within the agreed scope` |
| C-003E/F-branch | `implementation/account-model-v2-c003e-f-transfers-security` |
| C-003E-status | `Approved within the agreed scope` |
| C-003F-status | `PASS; Approved within the agreed scope` |
| C-003-status | `Fully completed; Approved within the agreed scope` |
| FlutterFlow-project | `a-v-a-r-y-n-alpha-ynvyuq` |
| FlutterFlow-revisie | `LOTvjLR6TzQjoalLhZWh` |
| Live Alpha | <https://alpha.avaryn.eu/> |
| Rollback-/fallback-URL | <https://avaryn-alpha.flutterflow.app/> |

De snapshotbranch is het bewijs- en rollbackpunt en mag niet worden gewijzigd.

## Bindende richting

- Alleen persoonlijke accounts authenticeren.
- Persoonlijke profiles, canonical horse accounts en organization accounts
  zijn zelfstandige duurzame entiteiten.
- `stable_id` is in v2 geen universele owner-, tenant-, workspace- of
  permissionbron.
- Relaties, eigendom, authority, memberships, rollen en permissions blijven
  afzonderlijke concepten.
- Professionele organization-horse links en fysieke horse residency zijn
  afzonderlijke concepten. Residency en een wederzijds bevestigde link geven
  geen impliciete toegang; daarvoor blijft een afzonderlijke permission grant
  vereist.
- Today is persoonsgebonden en onafhankelijk van het actieve workspacefilter.
- Bestaande fictieve testdata vereist geen compatibilitylaag.
- De browser blijft voorlopig online-first zonder persistente gevoelige
  volledige-offlinecache.

## Bekende documentatie- en toolchainpunten

- De complete Master Productblauwdruk is niet als zelfstandig bestand in de
  repository aangetroffen. Zij is in C-002 niet uit aannames gereconstrueerd;
  het technische contract is zelfstandig genoeg gemaakt voor de v2-kern.
- De lokale `generated_code`-snapshot verwijst in manifest/index naar
  gegenereerde FlutterFlow-bestanden die lokaal ontbreken. Dit is een bekende,
  afzonderlijke exportwaarschuwing en valt buiten C-002/C-002A.
- `flutterflow ai upgrade --check` meldde in C-002 op 2026-08-04 een nieuwere
  SDK-build (`2c299209` naar `b5c8a09d`, beide rapporteren versie `0.0.40`). De
  C-002A-check kon door een lokaal Dart-kernel-/netwerkprobleem niet afronden.
  De C-003A- en C-003C-check konden niet starten omdat `dart` niet op `PATH`
  stond. Er is niet geüpgraded en FlutterFlow is niet uitgevoerd.
- De live Alpha en rollback-URL zijn in C-001 read-only geobserveerd; C-002,
  C-002A en C-002B hebben geen live omgeving benaderd of gewijzigd.

## Afgeronde C-003-gates

C-003A tot en met C-003E zijn binnen de afgesproken scope goedgekeurd en de
C-003F-eindgate is volledig geslaagd. C-003 is daarmee volledig afgerond en
goedgekeurd binnen de afgesproken lokale scope:

1. C-003A — Identity and audit foundation;
2. C-003B — Organizations and memberships;
3. C-003C — Canonical horses and relationships;
4. C-003D — Explicit permissions and invitations;
5. C-003E — Atomic transfers;
6. C-003F — Security hardening gate.

De afzonderlijke implementatie- en testbewijzen staan in `docs/implementation`.
C-004 is niet gestart. Stagingreset, Supabase-linking, remote migration,
databasepush, FlutterFlow-/applicatiewijziging, push, merge, deployment en
livewijziging zijn niet uitgevoerd en blijven buiten deze opdracht.
