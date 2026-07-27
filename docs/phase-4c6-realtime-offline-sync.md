# Fase 4C.6 — Realtime, offline sync en legacy-cutover

## Status en grens

Fase 4C.6 voegt een autorisatiebewuste synchronisatielaag toe bovenop de
gevalideerde 4C.5-baseline. De migratie is additief: bestaande Horse-, planning-,
voeding-, media- en fase-4B-tabellen worden niet herschreven of verwijderd.

Deze fase levert de database- en cryptografische contracten. De
FlutterFlow-koppeling, UI-states en lokale lifecycle worden pas in 4C.7
geactiveerd. Totdat 4C.7 de hieronder beschreven wisregels volledig uitvoert,
mag offline sync niet als productfeature worden aangezet.

## Duurzame feed en Realtime

`stable_change_events` is de duurzame bron van waarheid. De cursor wordt per
stal toegewezen onder dezelfde authority-rowlock. Daardoor volgt de
cursorvolgorde de commitbare invoegvolgorde en kan een laat gecommitte
transactie niet achter een al uitgegeven cursor verdwijnen. De tabel bevat
alleen:

- een monotone cursor;
- stal, getypeerd doel en categorie;
- wijzigingssoort, row version en tijdstip;
- een interne broncorrelatie.

Vrije tekst, notities, media-URL's, tokens en secrets ontbreken. Bestaande
Horse-, schedule- en feeding-events worden bij upgrade eenmalig in deze feed
opgenomen. Nieuwe domeinevents worden in dezelfde transactie doorgezet.

`pull_operation_changes`:

1. valideert opnieuw een actieve membership en actieve stal;
2. vergelijkt de door de client verwachte authority version;
3. voert per event opnieuw de Horse-capability of minimale assignmentcontrole
   uit;
4. geeft alleen refresh-hints terug, nooit de inhoud van het doelrecord;
5. schuift een cursor pas voorbij een volle pagina nadat alle zichtbare events
   in die pagina zijn teruggegeven.

Realtime is uitsluitend een wake-upsignaal. Private Broadcast gebruikt
ondoorzichtige UUID-topics per stal, Horse/categorie of membership. Het
staltopic dekt Horse-loze operationele wijzigingen voor owner/admin; Horse- en
membershiptopics houden least-privilege wakes gericht. De payload bevat alleen
`cursor` en `authority_version`. Een policy op `realtime.messages`
controleert het topic opnieuw tegen de actuele membership en capability.
Clients hebben geen Realtime-writepad.

Bij membership-, rol-, grant-, Horse- of stalstatuswijziging:

- stijgt de authority version;
- roteren alle topics van de stal;
- worden geregistreerde offline devices server-side ingetrokken;
- weigeren oude cursors, topics en dagsets met `SYNC_RESET_REQUIRED`.

Broadcast is daarmee geen autorisatielaag. De duurzame cursor en de
domein-RLS/RPC's blijven altijd beslissend. Dit volgt het officiële
[Supabase Broadcast-patroon](https://supabase.com/docs/guides/realtime/broadcast)
en de afzonderlijke
[Realtime Authorization via `realtime.messages`](https://supabase.com/docs/guides/realtime/authorization).

## Versleutelde offline dagset

Een device registreert online een eigen OpenPGP public key. Alleen de public key
en SHA-256-fingerprint komen op de server; de private key verlaat het device
nooit.

`get_encrypted_offline_dayset` levert uitsluitend:

- actieve, aan de huidige rosterpersoon toegewezen items;
- stalbrede items zonder Horse of items van een nog actief paard, altijd met
  een bevestiging door de actuele schedule-accesshelper;
- één expliciete lokale datum;
- noodzakelijke uitvoeringsinstructies en tijden;
- normale/hoge prioriteit, nooit een generieke kritieke mutatie;
- een authority version en korte vervaltijd.

De volledige dagset wordt server-side met OpenPGP en AES-256 voor het
device versleuteld. Het resultaat bevat alleen ciphertext. De 4C.7-client moet:

- alleen ciphertext persistent opslaan;
- plaintext uitsluitend kort in geheugen houden;
- de private key in OS-backed secure storage houden;
- bij 401/403, `SYNC_RESET_REQUIRED`, suspended/removed/left of stalarchivering
  onmiddellijk ciphertext, decrypted state, cursor en topics verwijderen;
- na reconnect altijd eerst topics/authority en daarna de cursorfeed ophalen.

`sync_schedule_execution` en `sync_feeding_execution` zijn de enige nieuwe
offline mutatiepaden. Ze accepteren alleen een actieve, aan dezelfde gebruiker
en stal gebonden device-registratie, de actuele authority version en het
bestaande append-only executioncontract. Een execution-trigger reserveert ook
oude directe online/offline execution-RPC's in dezelfde
`client_mutation_receipts`-namespace. Daardoor kan één actor/request-ID nooit
tussen device-, schedule-, feeding-, conflict- of importdoelen worden
hergebruikt. Tijdzone en lokale invoertijd blijven afzonderlijk bewaard.
Beheer-/migratie-inserts via een directe `postgres`-databasesessie, of zonder
clientsessie, mogen de reservering overslaan; dit is een expliciete
trusted-service-grens. Servercode mag daarbij nooit een ongecontroleerde
client-`request_id` doorgeven.

## Conflictcontract

`sync_conflicts` is begrensd tot vooraf toegestane
`horse_basic_noncritical`-patches van maximaal 4 KiB. Ook op databaseniveau zijn
alleen `display_name`, `official_name`, `birth_date`, `sex`, `breed`,
`discipline` en `level` toegestaan. Memberships, grants,
permissions, gezondheid, medicatie en compliance passen niet in de
allowlist. `resolve_sync_conflict` is idempotent en vereist de oorspronkelijke
actor of een actuele owner/admin. Deze fase maakt Horse-profielwijzigingen
offline nog niet actief; de tabel en resolver zorgen dat een latere beperkte
pilot nooit stil naar last-write-wins kan terugvallen.
`list_sync_conflicts` maakt uitsluitend de eigen open conflicten zichtbaar;
directe tabelreads blijven dicht.

## Legacy-import

Legacy-import is expliciet en stateful:

`draft → validated → importing → verified → cutover`

met `failed` en `rolled_back` als zichtbare uitkomsten.

- `create_legacy_import_job` ontvangt één door de gebruiker gekozen bronstal,
  doelstal, een volledige typed broninventaris, versie-/hashmanifest en
  getypeerde preview-items.
- De server canonicaliseert de inventaris en items, berekent ieder
  payload-SHA-256 opnieuw en weigert afwijkende item- of manifesthashes.
- Ongewijzigde seeds worden altijd `excluded_seed`.
- Gewijzigde seeds en onbekende herkomst vereisen `selected = true`.
- Horse-items behouden de lokale integer bytegetrouw als
  `legacy_local_horse_id`.
- Schedule-items worden pas na een bestaande Horse-mapping geïmporteerd.
- Rosterpersonen worden nooit op naam of e-mail gekoppeld. Een
  `stable_member`-bronitem moet expliciet naar een actieve rosterrow in dezelfde
  stal wijzen.
- Voerplannen worden met Horse-mapping en hun volledige getypeerde bronpayload
  in een private, immutable legacy-snapshot bewaard; ze worden niet stil als
  actief operationeel voerplan geïnterpreteerd.
- Historische schedule-/feedingexecutions worden in een private typed
  historytabel bewaard en vereisen zowel een schedule-itemmapping als een
  expliciete roster-/actormapping. Ze worden nooit aan de importerende
  owner/admin toegeschreven.
- Iedere batch is actor/request-idempotent.
- Iedere batch retourneert de getypeerde legacy→cloudmappings en
  `get_legacy_import_job` kan een onderbroken flow zonder bronpayload hervatten.
- `verify_legacy_import_job` vergelijkt aantallen, bron- en cloudhashes, de
  actuele cloudrows/snapshots en het veilige mappingmanifest.
- `cutover_legacy_import_job` vereist dezelfde bronfingerprint én expliciete
  bevestiging dat de lokale back-up behouden blijft.
- `rollback_legacy_import_job` zet alleen een rollbackmarker. Cloudhistorie en
  lokale brondata worden niet stil verwijderd.

Importitems en payloads hebben geen client-DML. De bronpayload staat in
`private`; publieke statusrijen bevatten alleen classificatie, mapping en veilige
conflictcodes.

## Threat model en bekende beperking

Een volledig offline device kan niet op afstand worden gewist. Topicrotatie,
device-intrekking en authority versions voorkomen nieuwe data of nieuwe
mutaties zodra het apparaat opnieuw contact maakt, maar reeds gedownloade
ciphertext blijft fysiek aanwezig totdat de client of het OS die verwijdert.

Daarom gelden voor de pilot:

- minimale dagset en korte serverexpiry;
- public-keyencryptie per device;
- OS-lock en private-keybeveiliging zijn verplicht;
- logout/accountwissel en iedere authorityfout wissen de cache;
- verloren of gecompromitteerde devices moeten als privacy-incident worden
  behandeld;
- er bestaat geen claim van onmiddellijke remote wipe.

## Verificatie

De fase wordt pas geaccepteerd na:

- minimaal twee volledige lokale resets;
- een expliciete 4C.5→4C.6 upgrade met backfill en data-behoud;
- alle oudere SQL-, concurrency-, Edge- en Flutter-regressies;
- 100 identieke offline retries zonder duplicaat;
- verschillende request-ID's zonder samenvoeging;
- request-ID-hergebruik voor een ander doel als harde fout, ook over oude
  execution-RPC's heen;
- permission-filtered cursorcatch-up plus omgekeerde transactiestart/
  commit-races zonder gemiste zichtbare events;
- membership-/grant-/Horse-intrekking met topicrotatie, device-revoke en
  cache-reset;
- ciphertext zonder plaintextlekkage;
- seeduitsluiting, expliciete modified-seedselectie, volledige broninventaris,
  serverberekende hashes, roster-/Horse-/planning-/feeding-/executionmapping,
  tamper-detectie en een geserialiseerde cutover-versus-targetmutatierace,
  cutover en rollbackmarker;
- een onafhankelijke read-only security- en contractaudit.
