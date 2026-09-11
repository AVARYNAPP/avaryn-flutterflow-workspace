# C010 — kalender in de accounttijdzone

Kandidaat `202609110004_c010_account_calendar_timezone.sql`, SHA256 `a9e47de0b01bb8fd407e354b1ea1a148d89455a53e79c70561aa13f6365b08bd`. Alleen deze nieuwe forward migration wijzigt de bestaande kalenderfuncties; de eerdere47migrations blijven bytegelijk. Deze delta bracht development en Pilot op48 na afzonderlijke bronreview, verse backup, echte herstelproef en expliciet root-go. Na de afzonderlijke [005-promotie](ARCHIVED_HORSE_005_RUNBOOK.md) staan beide op49; dit tijdzonecontract is daarbij ongewijzigd.

## Contract

`private.c010_actor_time_zone()` leest `profiles.time_zone` van het bestaande geverifieerde actieve profiel. Er is geen actor- of tijdzoneparameter en geen nieuwe publieke RPC. Een ontbrekende of ongeldige opgeslagen zone geeft `ACCOUNT_TIME_ZONE_INVALID`; SQL-sessietijdzone en clientclaims zijn geen fallback. Een account met opgeslagen `UTC` blijft correct UTC gebruiken.

Bestaande signatures, privileges, RLS, CAS en idempotency blijven behouden. De kalender-returnshape blijft gelijk:

- `get_c010_calendar_context`: `today_date`, `time_zone`, `server_now`, `next_day_at`.
- `get_c010_personal_day`: hetzelfde `calendar`, `on_date`, `time_zone`, `day_start_at`, `day_end_at`, `items`.
- `get_c010_stable_round1_workspace`: bestaande top-level kalenderkeys en geselecteerde `on_date`.
- `get_c010_facility_workspace`: `calendar.time_zone/today_date`, `selected_date`, `covered_dates`, `pending_from`, `pending_through`; bestaande bereikgrens ±366 dagen.
- `get_c010_my_vitality_day`: erft dezelfde kalender via de bestaande call. Eerder opgeslagen dagdocumenten worden niet verplaatst.

De begin- en eindgrens van een dag worden afzonderlijk uit lokale middernacht berekend. Daardoor omvat een DST-dag zo nodig 23 of 25 uur. Een activiteit op de volgende middernacht valt buiten de huidige dag; een activiteit die de huidige beginrand overspant valt erbinnen. Bestaande trainingsinstants en `source_timezone` blijven opgeslagen zoals ze zijn; `due_date`/`due_time` van de activiteitenprojectie worden in de accountzone weergegeven.

Algemene taken blijven zonder verzonnen datum of tijd beschikbaar. Dagtaken blijven civiele datums; een optionele tijd wordt voor bereikvergelijking in de accountzone geïnterpreteerd. Rechten en deelnemersselectie blijven de bestaande grens.

## Faciliteiten: begrensde compatibiliteit

Alleen de actorafhankelijke huidige dag, standaarddag, laadvensters, boekdatumgrens en controles op toekomstige planning volgen de accountzone. Een gedeelde reservering houdt letterlijk dezelfde datum en begin-/eindtijd; capaciteit en overlapping blijven daarop gebaseerd. Het bestaande model heeft geen organisatiezone of absolute reserveringsinstants. De bestaande civiele DST-validatie blijft daarom vooralsnog Amsterdam gebruiken: deze migration pretendeert geen wereldwijd tijdzonemodel voor gedeelde faciliteiten. Daarvoor is een afzonderlijk expliciet organisatiezonecontract nodig; per bezoeker verschillend interpreteren zou geen veilige correctie zijn.

## Frontend

Lees eerst profiel plus persoonlijke serverkalender en vereis coherente zones. Gebruik `calendar.time_zone` voor activiteitweergave en omzetting van gekozen datum/tijd naar instants. Gebruik de serverdag voor Vandaag, huidige voeding en Vitality, ook wanneer een andere planningsdag geselecteerd is. Bereken daggrenzen afzonderlijk; tel geen vaste 24 uur op bij lokale middernacht. Na een profielzonewijziging: caches/readranges opnieuw laden, oude formulierwaarden niet stilzwijgend als nieuwe lokale tijden opslaan.

Aan `save_c010_facility_booking` blijven datum en tijden civiele waarden; geen browserzoneverschuiving. Geef bij gedeelde faciliteiten geen ongefundeerde absolute tijdzoneclaim.

## Bewijs en herstel

Gerichte SQL-tests staan in `supabase/tests/c010_account_calendar_timezone.sql`; zij gebruiken eigen synthetische profielen en bestaande publieke create/read/write-RPCs, volledig binnen rollback. Alle 105 controles slagen. De vijf geraakte bestaande suites slagen eveneens: kalender 1 samengestelde test, persoonlijke dag 44, Vitality 69, flexibele taken 42, faciliteiten 59. Alleen drie bestaande Amsterdam-testfixtures krijgen nu expliciet die accountzone; geen impliciete productdefault. Alle tests draaiden in de afzonderlijke database `avaryn_pilot_restore_20260911t185247z` op eigen cluster `7684330901039525928` (loopback 56802), met 125 oorspronkelijke tabelinhouden behouden.

Na bronreview en een afgesproken UI-schrijfpauze is uitsluitend 004 ook op de eigen gebruikersdatabase `postgres` toegepast. De verse volledige backup van 2.696.955 bytes (0600, SHA256 `3d8f031a9ad99f05e247fe963dbcedd5b594282c4af96d9b758be34533fd034a`) is eerst werkelijk in `avaryn_dev_timezone_restore_20260911t192327z` hersteld: alle 136 tabelinhouden en de oorspronkelijke 47 ledgerregels matchen. Na de atomaire apply blijven alle 135 overige tabelinhouden gelijk; alleen de lokale migrationledger krijgt regel 48. De 10 functiebody's matchen de bron exact; de 9 bestaande signatures, owners en ACL's blijven gelijk. De daaropvolgende managed pilotapply is afzonderlijk gecontroleerd: alle 47 oude historyhashes en alle 124 overige tabelinhouden zijn behouden; de volledige functie-/policycatalogus matcht de lokale herstelproef.

Private volledige backups en logs staan in `.avaryn-local/productization-20260911/private/timezone/`; veilige receipts in `evidence/timezone/`. De volledige oorspronkelijke rijhashes, bestaande functiesignatures/owners/ACL, tabelrechten/RLS/policies en 47 bronhashes worden gecontroleerd. Bij fout stopt uitvoering en wordt de proef teruggedraaid. Geen automatische restore over gebruikersdata.

Bewijs: [105 rollbackcontroles](../../.avaryn-local/productization-20260911/evidence/timezone/rollback-20260911T191721Z.json), [devbackup, echte restore en apply](../../.avaryn-local/productization-20260911/evidence/timezone/dev-apply-20260911T192327Z.json), [actuele functiepostcheck](../../.avaryn-local/productization-20260911/evidence/timezone/dev-function-postcheck.json). Dit is SQL-/bron-/lokale applybewijs, geen menselijke UI-acceptatie of managed runtimebewijs.

Managed bewijs: [uitsluitend004 toegepast](../../.avaryn-local/productization-20260911/evidence/pilot-backend/timezone004-apply-20260911T194637Z.json). Geen extra migrations of Auth-/SMTP-/Edge-config door deze uitvoerder gewijzigd.
