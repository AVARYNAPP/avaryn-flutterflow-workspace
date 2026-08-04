# AVARYN — Current State

Laatst bijgewerkt: 2026-08-04

## Huidige status

- **C-001:** afgerond. De read-only architectuuraudit adviseert het bestaande
  FlutterFlow-project te behouden en de stalgebonden backend grotendeels schoon
  te vervangen voor Account Model v2.
- **C-002:** technisch contract opgesteld.
- **C-002A:** formele reviewcorrecties op het technische contract uitgevoerd.
- **C-002A-besluit:** een organization-horse link wordt pas actief nadat de
  horse- en organizationcontext ieder afzonderlijk, expliciet en server-side
  geautoriseerd hebben bevestigd. De link zelf verleent geen toegang.
- **Contractstatus:** **Proposed – awaiting Silas approval**.
- Er is nog geen Account Model v2-functionaliteit geïmplementeerd.
- Er zijn geen migrations geschreven of uitgevoerd en geen database-, Auth-,
  RLS-, storage-, Edge-, FlutterFlow- of applicatiewijzigingen uitgevoerd als
  onderdeel van C-002 of C-002A.

Het voorgestelde contract staat in
[Account Model v2 Technical Contract](../architecture/ACCOUNT_MODEL_V2_TECHNICAL_CONTRACT.md).

## Repository- en FlutterFlow-basis

| Onderdeel | Waarde |
| --- | --- |
| Immutable snapshotbranch | `snapshot/latest-alpha-2026-08-04` |
| Snapshotcommit | `1634ef281084a76ae862fcb595dff8b08048ff48` |
| Actieve architectuurbranch | `architecture/account-model-v2-contract` |
| C-002A-basiscommit | `dc93b1c574eab185a95f9aa5113e65415d784d2a` |
| C-002A-documentatiecommit | Lokale Git HEAD van deze afgeronde correctieronde (`docs: refine account model v2 contract`) |
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
  Er is niet geüpgraded.
- De live Alpha en rollback-URL zijn in C-001 read-only geobserveerd; C-002 en
  C-002A hebben geen live omgeving benaderd of gewijzigd.

## Eerstvolgende stappen en afzonderlijke gates

De eerstvolgende stap is dat Silas het gecorrigeerde C-002A-contract goedkeurt
of opnieuw gerichte contractcorrecties vraagt. Daarna is C-003 opgesplitst in:

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

**Niet uitgevoerd in C-002A:** geen implementatie, stagingreset, migration,
remote Supabasehandeling, push, merge, deployment of FlutterFlow-/live-
wijziging. Deze handelingen blijven verboden zonder een afzonderlijke opdracht
die de exacte scope autoriseert.
