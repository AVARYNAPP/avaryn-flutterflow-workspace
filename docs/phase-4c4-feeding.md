# Fase 4C.4 — Voedingsplannen en feitelijke uitvoering

## Scope

Deze subfase bouwt het bindende 4C.1-voedingscontract:

- versieerbare standaard- en tijdelijke voedingsplannen;
- expliciete goedkeuring en activatie;
- exacte tijdelijke vervanging via `override_key`;
- materialisatie naar de bestaande centrale planning;
- feitelijke hoeveelheid, restant, afwijking en observatie bij uitvoering;
- append-only uitvoering en correctie;
- RLS, same-stable foreign keys, idempotency en concurrencycontrole.

Productcatalogus, professionele verificatieworkflows, automatische
eenheidsconversie, media, generieke sync/changefeed, FlutterFlow-koppeling en
productiedeployment vallen buiten 4C.4.

## Additieve migratie

`202607270004_phase_4c4_feeding.sql` bouwt uitsluitend voort op de groene
4C.3-commit. Eerdere migraties worden niet gewijzigd.

De migratie maakt:

- `public.feeding_plans`;
- `public.feeding_plan_versions`;
- `public.feeding_plan_items`;
- `public.feeding_occurrences`;
- `public.feeding_execution_details`;
- `public.feeding_change_events`;
- `private.feeding_mutation_receipts`;
- lock-, capability-, receipt-, recurrence- en eventhelpers;
- zeven publieke mutatie-RPC’s.

## Autorisatie

`horse.nutrition` is een expliciet gevoelige gegevenscategorie:

- een actieve owner heeft de contractuele beheerbevoegdheid;
- admin, member en viewer krijgen geen impliciete voedingstoegang;
- zij hebben een actieve, niet-verlopen Horse-grant nodig;
- `view` leest planinhoud;
- `edit` maakt plannen, versies en draft-items;
- `manage` keurt goed, activeert en retireert;
- `execute` registreert uitvoering;
- een actief toegewezen responsible/support mag alleen de minimale taak lezen
  en uitvoeren, zonder toegang tot de voedingstabellen.

Een geschorst membership, inactieve stal of gearchiveerd Horse verliest
onmiddellijk toegang. Onbekende en cross-stable objecten delen
`NUTRITION_UNAVAILABLE`.

## Plannen, versies en bronnen

Een plan is `standard` of `temporary`. Tijdelijke plannen hebben altijd een
einddatum. De lifecycle is `draft → active → retired`.

Planinhoud staat in versies:

- `draft`: items zijn muteerbaar;
- `approved`: inhoud en approval-snapshot zijn immutable;
- `superseded`: historische goedgekeurde versie.

Een nieuwe versie krijgt een oplopend nummer. Een versie moet minimaal één
item bevatten voordat beheer haar kan goedkeuren. Plan- en itemwijzigingen
gebruiken optimistic `row_version`.

De fysieke bronwaarden `professional` en `verified_template` en de
itembronlabels zijn voorbereid. De gewone client-RPC accepteert alleen
`source_kind = user` en itembronnen `user_entered`,
`professional_unverified` of `commercial`. Een client kan dus niet zelf een
professionele of geverifieerde claim aanbrengen.

## Items en eenheden

Een item bewaart een snapshotspecifieke productnaam, optioneel merk/variant,
positieve geplande hoeveelheid, vaste unit, aanbiedingsmethode, ronde,
lokale tijd, recurrence, optionele verantwoordelijke rosterpersoon, batch,
houdbaarheidsdatum en instructie. Iedere clientregel heeft daarnaast een
verplichte, versie-overstijgende `override_key`. Die sleutel is de duurzame
logische slotidentiteit voor zowel gewone versie-vervanging als tijdelijke
overrides.

Ondersteunde units zijn:

- `g`, `kg`, `ml`, `l`;
- `scoop`, `portion`, `piece`.

Er vindt geen stille conversie plaats. De uitvoeringsunit moet exact gelijk
zijn aan de occurrence-unit; anders volgt
`FEEDING_UNIT_CONVERSION_REQUIRED`.

Recurrence is dagelijks wanneer weekdagen en interval ontbreken, anders
óf een unieke ISO-weekdagenset óf een interval van 1–365 dagen.

## Goedkeuring en activatie

Activatie serializeert per Horse met één advisory transaction lock en lockt
daarna de planrijen en doelversie deterministisch. Draft-itemmutatie,
approval, activatie en retirement delen die lockorde; approval en activatie
kunnen daardoor niet in een plan/version-lockinversie belanden.

Voor standaardplannen geldt:

- actieve datumvensters mogen niet overlappen;
- een overlappend actief tijdelijk plan blokkeert standaardactivatie.

Voor tijdelijke plannen geldt:

- een actief standaardplan moet het volledige tijdelijke venster dekken;
- ieder tijdelijk item gebruikt een `override_key` die ook in de standaardversie
  bestaat;
- die key moet exact in de actieve standaardversie bestaan;
- twee actieve tijdelijke plannen mogen dezelfde key niet in een
  overlappend datumvenster vervangen.

De activatie materialiseert maximaal negentig lokale dagen per call:

- `schedule_items` met `item_kind = feeding`;
- `data_category = horse.nutrition`;
- bron-IANA-zone, lokale datum en tijd;
- een typed `feeding_occurrence`;
- optioneel een responsible assignment.

Receipts bewaren duurzame batchvoortgang. Een vervolgaanroep kan daardoor
zonder duplicaten voorbij het eerste venster materialiseren.

Bij versie-vervanging worden alleen toekomstige geplande en onuitgevoerde
occurrences geannuleerd. Actieve assignments op geannuleerde occurrences
worden eveneens geannuleerd. De nieuwe versie materialiseert niet opnieuw
vóór de lokale staldatum en slaat uitsluitend dezelfde exacte
`override_key` over wanneer de vorige versie voor dat slot al terminale of
uitgevoerde historie heeft. Andere ronde-/voerslots op dezelfde datum
blijven dus materialiseren. Tijdelijke overrides annuleren uitsluitend de
exact-key standaardoccurrences. Reeds uitgevoerde of terminale historie
blijft intact; voor zo’n logisch slot wordt geen dubbele occurrence gemaakt.

Een actief standaardplan kan niet worden geretired zolang voor hetzelfde
Horse een actief tijdelijk plan bestaat. Zo kan een tijdelijke override nooit
zonder de standaarddekking achterblijven.

## Feitelijke uitvoering

`record_feeding_execution` schrijft atomair:

1. een generieke append-only `schedule_execution`;
2. een typed `feeding_execution_detail`;
3. de afgeleide schedule-itemstate;
4. een generiek schedule-event;
5. een payloadarm feeding-event;
6. een private idempotencyreceipt.

Het detail bevat:

- `actual_quantity`;
- dezelfde `unit_code` als de occurrence;
- optioneel `remaining_quantity`;
- afwijking `none`, `less`, `more`, `refused`, `spilled`,
  `substituted` of `other`;
- optionele observatie en batch.

Correctie is een nieuwe uitvoering met `corrects_execution_id`. De
oorspronkelijke execution en het oorspronkelijke detail worden nooit
gewijzigd.

## Idempotency en audit

Iedere publieke mutatie vereist een request-UUID. Receipts zijn uniek op
actor/request en bevatten operation name, typed target, SHA-256-payloadhash
en uitsluitend een veilig resultaat.

- exacte retry retourneert hetzelfde resultaat met `idempotent: true`;
- ander payload- of operationgebruik faalt met `REQUEST_ID_REUSED`;
- terminale retries worden vóór mutable-statecontrole herkend.

Feeding-events zijn append-only en bevatten alleen tenant/object/request,
eventtype, row-version en uitsluitend bij retirement een begrensde reden.
Versie-`change_reason`, productnamen, instructies, executionnotities en
observaties worden niet gekopieerd.
Identity-sequences en private receipts zijn niet clientleesbaar.

## Publieke RPC’s

- `create_feeding_plan`
- `create_feeding_plan_version`
- `upsert_feeding_plan_item`
- `approve_feeding_plan_version`
- `activate_feeding_plan_version`
- `retire_feeding_plan`
- `record_feeding_execution`

Alleen deze SECURITY DEFINER-RPC’s muteren voeding. `authenticated` heeft
alleen RLS-begrensde SELECT op de publieke basistabellen; `anon` heeft geen
toegang.

## Bewijs

De 4C.4-bewijslaag bestaat uit:

- `supabase/tests/phase_4c4_feeding.sql`;
- `supabase/tests/phase_4c4_feeding_concurrency.rb`;
- `supabase/tests/phase_4c4_upgrade_fixture.sql`;
- `supabase/tests/phase_4c4_upgrade_verification.sql`.

De SQL-regressie bewijst onder meer ACL/RLS, same-stable constraints,
bronclaims, normalisatie, idempotency, immutable approvals, materialisatie,
lokale tijdsintentie, minimale assignmenttoegang, uitvoering/correctie,
eenheidsfail-closed, tijdelijke overrides, assignment-annulering,
autoriteitsverlies, oracle-gelijkheid en payloadarme audit/receipts.

De upgradeproef zet representatieve 4C.3 planning, assignment, execution en
eventhistorie vóór de migratie en bewijst daarna bit-for-bit betekenisbehoud
plus lege, beveiligde 4C.4-tabellen.

De concurrencyrunner forceert races voor:

- approval tegenover activatie, in beide aankomstvolgordes;
- twee concurrerende standaardactivaties op hetzelfde Horse;
- tijdelijke overrideactivatie tegenover feitelijke standaarduitvoering;
- beide aankomstvolgordes.

Geldige uitkomsten zijn seriële contractuitkomsten: approval commit vóór
activatie of een veilige pre-approval-rejection; één overlappend
standaardplan wint; en bij de tijdelijke race blijft óf de uitvoering als
historie behouden zonder dubbele tijdelijke occurrence, óf de override
annuleert de nog onuitgevoerde standaardoccurrence. Iedere race controleert
ook een aparte controlestal. Deadlocks, dubbele actieve scopes, cross-tenant
mutaties en verloren executions zijn nooit geldig.
