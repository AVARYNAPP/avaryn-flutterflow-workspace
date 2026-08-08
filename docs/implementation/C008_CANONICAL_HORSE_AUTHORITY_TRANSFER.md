# C-008 — Zelfstandig paard, relaties, Horse Authority en transfer

Startdatum: `2026-08-08`

Startbasis: C-007-eindcommit
`87d4ac667bc5b1acf2e3ee5addc3d0a7ad518307`.

Status: **C-008 — Approved within the current Alpha/Staging scope**.

Formele uitkomst: **HORSE AUTHORITY / TRANSFER ROUTE = PASS**.

## Gap-analyse vóór implementatie

De repository bevat geen afzonderlijk Master Productblauwdrukbestand. De
bindende C-008-opdracht, het goedgekeurde Account Model v2 Technical Contract,
`CURRENT_STATE.md` en de bestaande horse-/planning-/feedingfasebewijzen vormen
daarom samen de gecontroleerde bron.

| Onderdeel | Uitkomst | C-008-besluit |
| --- | --- | --- |
| Canonical horse zonder stal | Aanwezig in C-003C | Hergebruiken; geen tweede horseaggregate. |
| Exact één primary Horse Authority | Aanwezig als niet-null scalar invariant | Ongewijzigd leidend houden. |
| Delegated administrators | Aanwezig, tijdgeldige expliciete codes | Alleen veilige productprojectie en e-mailgebonden mutatieroute toevoegen. |
| Juridisch eigendom | Persoon/organisatie, historie en percentage aanwezig | Geen permissionsemantiek toevoegen; productroute aansluiten. |
| Semantische relaties en residency | Aanwezig en niet-autoriserend | Productroute aansluiten; stal blijft optioneel. |
| Authority transfer | C-003E is atomair, zeven dagen, tokengebonden, idempotent en auditable | Geen tweede state machine; veilige e-mailinitiatie en UI-route toevoegen. |
| Paardprofiel | Canonical bevat kernvelden; legacy bevat extra Alpha-profielvelden | Canonical profiel backward-safe uitbreiden met dezelfde veldnamen. |
| Legacy `public.horses` | Verplicht `stable_id`; Planning, Voeding en media verwijzen ernaar | Expliciete één-op-één canonical bridge met dezelfde UUID toevoegen en bestaande rijen fail-closed backfillen. |
| Planning en Voeding | Werkend en uitgebreid getest, maar legacy horse-FK | Niet herbouwen; bestaande UUID's via de bridge canonical maken en regressies behouden. |
| Actieve Alpha-UI | Paardenmodus gebruikt nog `create_horse` en actuele stalcontext | Vervangen door een online-first canonical horse-runtime; Planning en Voeding blijven ongewijzigd. |
| Security | C-003F-gate groen | Nieuwe projecties/wrappers RPC-only, actor server-side, RLS/ACL exact allowlisten en negatief testen. |

## Risico- en migratiegrens

- Bestaande legacy horse-UUID's worden ook hun canonical UUID. Daardoor blijven
  alle Planning-, Voeding-, media- en historieverwijzingen intact zonder
  destructieve sleutelconversie.
- Backfill accepteert alleen een legacy paard waarvan de actieve stalowner naar
  exact één actief duurzaam profile resolveert. Ontbrekende of ambigue
  authority stopt de migration; er wordt nooit een fictieve authority gekozen.
- Een nieuw zelfstandig canonical paard krijgt geen `stable_id` en is direct
  geldig. Latere C-009/C-010-koppelingen blijven relaties en verlenen geen
  impliciete toegang.
- Transfercodes en credentials worden niet persistent opgeslagen of gelogd.
  Clientzichtbaarheid blijft uitsluitend presentatie; alle beslissingen vallen
  opnieuw in de bestaande server-RPC's.
- Er wordt geen Stagingreset uitgevoerd. Een eventuele forward migration of
  FlutterFlow-publicatie volgt alleen via de bestaande targetguards en vereiste
  externe gates.

## Lokale implementatie

- Forward-only migration `202608080001_c008_canonical_horse_vertical.sql`
  breidt uitsluitend het bestaande C-003C canonical aggregate uit. Bestaande
  legacy paarden worden fail-closed met dezelfde UUID gebridged; toekomstige
  legacy aanmaakroutes krijgen dezelfde één-op-één bridge.
- Canonical create/update/list/workspace-RPC's leiden de actor server-side af,
  gebruiken bestaande C-003C-permissions en row-version-CAS en geven alleen
  vooraf bepaalde projecties terug.
- Verified-email-wrappers verbinden een concreet actief profiel aan juridisch
  eigendom, semantische relatie, begrensde delegatie of transfer. Geen wrapper
  accepteert een actor- of authorityparameter van de client.
- De Nederlandse online-only paardenworkspace ondersteunt zelfstandig
  aanmaken, volledig profielbeheer, eigendom, relaties, gedelegeerd beheer,
  transfer starten/ontvangen/weigeren/accepteren/intrekken en auditinzage.
  Normale, loading-, empty-, denied-, error-, offline- en stale/conflictstates
  zijn fail-closed. Transfertokens blijven uitsluitend tijdelijk in geheugen.
- Bestaande private profielfoto-ID's blijven behouden. Miniaturen worden alleen
  via de bestaande Edge Function als kortlevende signed `horse-media`-URL in
  geheugen geladen; een publieke storage-URL of persistente mediacache is niet
  toegevoegd.
- Planning en Voeding zijn niet herbouwd. Hun bestaande horse-UUID blijft door
  de één-op-één bridge de canonical identity; de bestaande pagina's en
  operationele runtime blijven ongewijzigd actief.

## Lokale verificatie tot de externe gate

- C-008 SQL-securitymatrix: **PASS**.
- Bestaande C-003C horse-/relationshipmatrix: **PASS**.
- Bestaande C-003E transferstatemachines: **PASS**.
- Canonical-horse CAS-concurrency: exact één winnaar en één stale writer:
  **PASS**.
- Horse- en organization-transferconcurrency: exact één acceptwinnaar en één
  terminale replayweigering: **PASS**.
- Nieuwe C-008 contracttests: **8/8 PASS**.
- Volledige bestaande plus C-008 Dart-/FlutterFlow-statische regressiesuite:
  **183/183 PASS**.
- C-008 custom-widgetanalyse tegen de gegenereerde Flutterdependencies:
  **PASS**, geen analyzerbevindingen.
- `git diff --check`: **PASS**.

De migration is transactioneel: iedere unresolved legacy authority of UUID-
collision breekt de volledige transactie af voordat constraints worden
vastgelegd. Herstel vóór de Stagingtoepassing bleef gebonden aan de bestaande
versleutelde C-006-back-upketen. De migrationpreflight bewees nul legacy horses,
nul unresolved authoritygevallen, nul ambigue ownerfallbacks en nul UUID-
collisions. Na de geslaagde forward migration blijft de primaire herstelroute
een corrigerende forward migration, niet het herschrijven van migrationhistorie.

## SDK-, Staging- en cutovergate

- De expliciet goedgekeurde FlutterFlow AI-upgrade van `2c299209` naar
  `b5c8a09d` is geslaagd; beide builds rapporteren versie `0.0.40` en
  `newer_available: false`. Onverwachte workspacebrede templatewijzigingen uit
  de upgrade zijn niet behouden. De relevante diff bestaat uit de buildpin,
  de bijbehorende gegenereerde Flutter/Dart-lockupdate en C-008-output.
- FlutterFlow-projectcommits `rhTZQThF7kbDX671Nagg` en
  `YNqu1rA4Wts0ZafmrG8q` zijn gevalideerd op project
  `a-v-a-r-y-n-alpha-ynvyuq`. De tweede revisie verwijdert uitsluitend een
  dubbele bronimport vóór codegeneratie.
- Forward migration `202608080001_c008_canonical_horse_vertical` met SHA-256
  `852190d66e16e10fba7efa1d363d5465410281acd5fafad43a7cf3d8923b8548`
  is als één transactie op exact Supabaseproject `ipdovjdtnfslrftvrdrl`
  (`AVARYN Staging`) toegepast en in dezelfde transactie aan
  `supabase_migrations.schema_migrations` gebonden: **PASS**.
- De volledige inhoudelijke C-008 RLS-/ACL-/actor-/CAS-/ownership-/relationship-
  /delegation-/transfer-/audit-/legacybridgematrix is op Staging in één
  teruggerolde transactie uitgevoerd: **PASS**. Alleen de niet-beschikbare
  PgTAP-wrapper is voor hosted Staging weggelaten; alle inhoudelijke checks
  bleven identiek. Er bleef geen C-008-testuser of fixture achter.
- De postcheck bewijst authenticated-only list/transfer-RPC's, anon-deny,
  private-helperdeny voor `service_role`, de verplichte legacybridgekolom en
  -trigger, nul active horses zonder primary authority en nul ongeldige pending
  transferwindows: **PASS**.
- De nieuwe C-008-build is naar `alpha.avaryn.eu` en
  `avaryn-alpha.flutterflow.app` gepubliceerd. Beide hosts leveren identieke
  index-, serviceworker- en JavaScriptbundlebestanden; bundle-SHA-256 is
  `0f24ffe958ba28a1908ef7070a649ce7a9f48ec44422ba624e3eff1c3c95fb40`.
- De cachevrije fallbackhost is met een bestaand bevestigd Alpha-account op
  mobiel en desktop beoordeeld. De zelfstandige empty-state, canonical create-
  dialoog en transferontvangstdialoog zijn zichtbaar en fail-closed; er is geen
  persistente paarddata aangemaakt: **PASS**. Een al geopende custom-domainclient
  hield tijdelijk de vorige serviceworkerclient vast; de publiek aangeboden
  artifacts op beide hosts waren aantoonbaar identiek. Dit is geen C-008-code-
  of securitybevinding.

Er zijn geen bekende open C-008 P0/P1/P2-code-, data- of securitybevindingen.
Productie, Git-push en merge zijn niet uitgevoerd. C-009 is niet gestart.
