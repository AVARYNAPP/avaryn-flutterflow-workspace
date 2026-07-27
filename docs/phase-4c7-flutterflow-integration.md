# Fase 4C.7 — FlutterFlow-integratie

## Scope

Fase 4C.7 koppelt de reeds beveiligde fase-4C-datalaag aan de bestaande
FlutterFlow-schermen. Deze fase voegt geen databaseobjecten of nieuw
autorisatiebeleid toe en voert geen productie-deployment uit.

De volgende operationele pagina's gebruiken één gedeelde custom widget,
`AvarynOperationalRuntime`, met een expliciete modus:

| Pagina | Modus |
| --- | --- |
| `TodayDashboardPage` | `today` |
| `HorsesOverviewPage` | `horses` |
| `PlanningPage` | `planning` |
| `FeedingOverviewPage` | `feeding` |
| `FeedingRoundExecutionPage` | `feedingExecution` |

Iedere pagina behoudt de fase-4B-stalselector, desktopnavigatie en mobiele
navigatie. De runtime leest de geselecteerde cloudstal uitsluitend uit de
bestaande, accountgebonden fase-4B-context.

## Autorisatie- en datagrens

De client behandelt Supabase RLS en de fase-4C-RPC's als enige bron van
autorisatie. Er is geen service-role-sleutel, lokale bypass of directe
client-DML toegevoegd.

De runtime gebruikt:

- `list_today_schedule` voor de actuele operationele projectie;
- `create_horse`, `create_schedule_item` en `create_feeding_plan` voor
  servergevalideerde mutaties;
- `record_schedule_execution` en `record_feeding_execution` voor directe
  online uitvoering;
- `get_realtime_topics` en private Broadcast-kanalen uitsluitend als
  wake-upsignaal;
- `pull_operation_changes` als duurzame, permission-filtered cursorfeed;
- `list_sync_conflicts` voor uitsluitend de eigen open conflicten;
- `register_sync_device`, `get_encrypted_offline_dayset`,
  `sync_schedule_execution` en `sync_feeding_execution` voor de begrensde
  offlinepilot.

Bij `AuthException`, PostgREST `42501`, `SYNC_RESET_REQUIRED`, ontbrekende
membership, een inactieve stal of een gewijzigde authority version sluit de
client fail-closed. Hij verwijdert dan kanalen, authority/cursor, ciphertext,
pending mutaties, devicekeys, ontsleutelde toestand en de actieve cloudstal.
De authority version wordt vóór overschrijven met de lokaal gebonden versie
vergeleken, zodat een oude cursor nooit onder een nieuwe authority wordt
doorgezet.

De account-runtime wist bij logout, een ontbrekende sessie en accountwisseling
alle `avaryn.4c7.<auth-uuid>.*`-sleutels van het vorige account. De operationele
runtime bewaart daarnaast de gebonden auth-UUID, zodat een auth-event niet
abusievelijk de `signed-out`-namespace opruimt.

## Realtime

Realtime-payloads bevatten geen domeindata. Een private Broadcast op
`change_available` plant alleen een begrensde refresh. Na een wake-up haalt de
client eerst de duurzame cursorfeed op en ververst daarna de operationele
projectie via de bestaande RLS/RPC-laag.

Een reconnect herstelt eerst authority en topics en verwerkt pas daarna
durable changes. Oude topics of cursors worden bij een authoritywijziging niet
hergebruikt.

## Offlinepilot en platformgrens

Op ondersteunde native/desktopplatforms:

- genereert ieder device een eigen OpenPGP-sleutelpaar;
- blijven private key en passphrase uitsluitend in
  `FlutterSecureStorage`;
- ontvangt en bewaart de app alleen de versleutelde dagset-envelope;
- bestaat ontsleutelde dagdata uitsluitend in geheugen;
- wordt de pending executionqueue eveneens met de device-public key
  versleuteld;
- behoudt een queued item bij herstart exact dezelfde UUID request-ID;
- verwijdert een geslaagde queued mutatie direct uit de versleutelde queue,
  zodat een latere fout reeds bevestigde items niet blokkeert;
- hergebruikt een online mutatie na een ambigue transportuitkomst in dezelfde
  auth-/stal-scope met exact dezelfde payload en request-ID;
- gebruikt ditzelfde idempotencycontract voor device-registratie;
- herstelt de eerder gevalideerde stal-timezone uit secure storage voordat een
  offline dagset wordt ontsleuteld;
- accepteert een dagset alleen wanneer outer envelope, ontsleutelde payload en
  actuele context exact dezelfde authority version en expiry dragen.

Een feeding-uitvoerder vult de werkelijk gegeven hoeveelheid, de eenheid, een
optionele resthoeveelheid en de afwijkingscode expliciet in. De client probeert
die gegevens niet uit een door RLS mogelijk verborgen `feeding_occurrence` te
reconstrueren en verzint geen `0/portion`-fallback.

De webvariant schakelt offline opslag en offline queueing bewust uit. De
4C.6-pilot vereist OS-backed sleutelopslag; browseropslag voldoet niet aan die
grens. Online RLS/RPC-werking blijft op web beschikbaar. Deze beperking is
fail-closed en zichtbaar in de UI.

Een volledig offline apparaat kan niet op afstand worden gewist. De korte
dagsetexpiry, device-intrekking en verplichte purge bij reconnect beperken het
rest-risico zoals vastgelegd in fase 4C.6.

## UI-states

De gedeelde runtime levert per modus:

- loading en handmatige refresh;
- lege toestand zonder lokale fallbackdata;
- permission-denied/fail-closed toestand;
- offline toestand met alleen een geldige ontsleutelde native dagset;
- conflictindicator voor de eigen open syncconflicten;
- online create- en executionflows via de bestaande server-RPC's.

De client toont geen data van een eerder account of een eerder geselecteerde
stal terwijl nieuwe authority wordt vastgesteld. Bij netwerkverlies wordt de
volledige online projectie eerst uit geheugen verwijderd; alleen een geldige,
ontsleutelde toegewezen dagset wordt daarna teruggezet. De binnen de
ciphertext opgenomen stal, timezone, authority version en expiry moeten exact
overeenkomen met de envelope en actuele context.

Bij logout, accountwissel, stalwissel of authority-reset wordt ontsleutelde
toestand vóór iedere await uit geheugen verwijderd. Secure-storage- en
kanaalverwijdering worden gecontroleerd; een mislukte verwijdering blijft in
een procesbrede retryqueue en blokkeert herladen zolang de accountnamespace
niet aantoonbaar schoon is.

Alle dagselectie, invoertijd en tijdzonelabels gebruiken de geconfigureerde
IANA-timezone van de actieve stal, niet de devicezone.

## Verificatie

Op 27 juli 2026 zijn lokaal uitgevoerd:

- `flutterflow ai test`: 71/71 tests groen, inclusief pure gedragstests voor
  queue-deduplicatie, partial flush, accountnamespace-isolatie, inner-expiry en
  ambigue request-ID-retry;
- FlutterFlow DSL-validatie en projectpush: groen;
- gerichte analyse van de gegenereerde operational runtime: geen fouten;
- Flutter 3.35.7 webbuild: groen;
- visuele auth-boundaryregressie op 390 × 844 en 1024 × 768: groen;
- volledige lokale Supabase-reset: groen;
- expliciete 4C.5 → 4C.6 upgradefixture, migratie en
  upgradeverificatie: groen;
- volledige 4C.6 SQL/RLS/offline-syncsuite: groen;
- 50/50 offline-sync/suspend-races, 50/50 import/suspend-races,
  50/50 cutover/target-races en 50/50 cursor-commitvolgorderaces: groen.

De onafhankelijke audits vonden geen P0, RLS-/tenantbypass,
service-rolegebruik, Realtime-autorisatie of plaintextpersistentie. De
gevonden lifecycle-, offline-, feeding-, idempotentie-, timezone-, expiry-,
purge- en brownfieldbevindingen zijn vóór de finale heraudit hersteld en van
gerichte regressies voorzien.

De gegenereerde FlutterFlow-importheader veroorzaakt enkele bestaande
niet-fatale unused-importmeldingen; de gerichte analyse bevat geen compile- of
typefouten.

## Releasegrens

Deze fase mag pas naar Git worden gepusht na een onafhankelijke read-only
security- en contractaudit en een schone Git-gate. Een geslaagde
FlutterFlow-projectpush is geen productie-deployment. Productieconfiguratie,
productiedata, Edge-deployment en app-store/webdeployment blijven expliciet
buiten scope.
