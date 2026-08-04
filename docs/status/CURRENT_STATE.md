# AVARYN — Current State

Laatst bijgewerkt: 2026-08-04

## Huidige status

- **C-001:** afgerond. De read-only architectuuraudit adviseert het bestaande
  FlutterFlow-project te behouden en de stalgebonden backend grotendeels schoon
  te vervangen voor Account Model v2.
- **C-002:** technisch contract opgesteld.
- **C-002-status:** **Proposed – awaiting Silas approval**.
- Er is nog geen Account Model v2-functionaliteit geïmplementeerd.
- Er zijn geen migrations, database-, Auth-, RLS-, storage-, Edge-,
  FlutterFlow- of applicatiewijzigingen uitgevoerd als onderdeel van C-002.

Het voorgestelde contract staat in
[Account Model v2 Technical Contract](../architecture/ACCOUNT_MODEL_V2_TECHNICAL_CONTRACT.md).

## Repository- en FlutterFlow-basis

| Onderdeel | Waarde |
| --- | --- |
| Immutable snapshotbranch | `snapshot/latest-alpha-2026-08-04` |
| Snapshotcommit | `1634ef281084a76ae862fcb595dff8b08048ff48` |
| Actieve architectuurbranch | `architecture/account-model-v2-contract` |
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
  afzonderlijke exportwaarschuwing en valt buiten C-002.
- `flutterflow ai upgrade --check` meldde op 2026-08-04 een nieuwere SDK-build
  (`2c299209` naar `b5c8a09d`, beide rapporteren versie `0.0.40`). Er is in
  C-002 niet geüpgraded.
- De live Alpha en rollback-URL zijn in C-001 read-only geobserveerd; C-002
  heeft geen live omgeving benaderd of gewijzigd.

## Eerstvolgende stap

De eerstvolgende stap is uitsluitend na expliciete goedkeuring door Silas:

1. keur C-002 goed of vraag gerichte contractcorrecties;
2. start daarna C-003 op een afzonderlijke branch;
3. implementeer in C-003 alleen de lokale Account Model v2 security nucleus en
   bijbehorende database/securitytests zoals gespecificeerd in sectie L van
   het contract.

**Expliciet verboden vóór die goedkeuring:** geen stagingreset, geen migration,
geen remote Supabasehandeling en geen FlutterFlow- of deploymentwijziging.
