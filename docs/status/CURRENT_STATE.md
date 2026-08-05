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
  daarom nog niet worden geactiveerd. De overkoepelende C-003F-securityaudit
  blijft verplicht. Deze beperkingen maken de afgebakende C-003A-goedkeuring
  niet opnieuw pending.
- C-003A is gereed en vormt na deze statuscommit de goedgekeurde basis voor een
  afzonderlijk op te dragen C-003B.
- Er is niets remote uitgevoerd, geen stagingreset gedaan en geen FlutterFlow-
  of applicatiecode gewijzigd voor C-003A.
- Er is niets gepusht, gemerged of gedeployed als onderdeel van deze lokale
  C-003A-hardening.

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
  De C-003A-check kon niet starten omdat `dart` niet op `PATH` stond. Er is niet
  geüpgraded en FlutterFlow is niet uitgevoerd.
- De live Alpha en rollback-URL zijn in C-001 read-only geobserveerd; C-002,
  C-002A en C-002B hebben geen live omgeving benaderd of gewijzigd.

## Eerstvolgende stappen en afzonderlijke gates

C-003A is binnen de afgesproken scope goedgekeurd. C-003B is niet gestart en
vereist nog steeds een afzonderlijke exacte opdracht.
C-003 blijft opgesplitst in:

1. C-003A — Identity and audit foundation;
2. C-003B — Organizations and memberships;
3. C-003C — Canonical horses and relationships;
4. C-003D — Explicit permissions and invitations;
5. C-003E — Atomic transfers;
6. C-003F — Security hardening gate.

Iedere C-003-fase vereist vooraf een afzonderlijke expliciete goedkeuring, een
eigen branch, begrensde scope, eigen tests, securitygate, handmatig
goedkeuringsmoment en rollbackpunt. Een fase start of omvat nooit impliciet de
volgende fase. Zie sectie L van het technische contract voor de exacte scopes.

**Niet uitgevoerd in C-003A:** geen C-003B of latere fase, stagingreset,
Supabase-linking, remote migration, databasepush, FlutterFlow-/applicatiewijziging,
push, merge, deployment of livewijziging. Deze handelingen blijven verboden
zonder een afzonderlijke exacte opdracht en de vereiste voorafgaande gate.
