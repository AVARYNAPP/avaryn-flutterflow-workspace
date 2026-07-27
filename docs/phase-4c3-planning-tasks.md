# Fase 4C.3 — Planning en taken

## Scope

Deze subfase bouwt de centrale, server-authoritative planning uit het bindende
4C.1-contract:

- eenmalige taken;
- recurrence-series en afzonderlijke occurrences;
- rostergebaseerde assignments;
- append-only executions en correcties;
- payloadarme change-/auditevents;
- Today- en deep-linkreadmodels;
- idempotency, optimistic concurrency en authorityraces.

Voeding, media, generieke sync/changefeed, legacy-import, FlutterFlow-koppeling
en productieconfiguratie blijven buiten deze subfase.

`critical` is bewust niet beschikbaar. Alleen `normal` en `high` bestaan in
de fysieke constraint en alle publieke RPC-validatie. Daarmee blijft
4C-DEC-14/P0-05/P0-06 fail-closed.

## Additieve migratie

`202607270003_phase_4c3_planning_tasks.sql` bouwt uitsluitend voort op de
groene 4C.2B-commit. Eerdere migraties en bestaande 4A/4B/4C-data worden niet
gewijzigd of herschreven.

De migratie maakt:

- `public.schedule_series`;
- `public.schedule_items`;
- `public.schedule_assignments`;
- `public.schedule_executions`;
- `public.schedule_change_events`;
- `private.schedule_mutation_receipts`;
- normalisatie-, row-version- en append-onlytriggers;
- private lock-, permission-, receipt-, recurrence- en eventhelpers;
- elf mutatie-RPC’s;
- drie read-RPC’s voor Today, deep links en executionhistorie.

## Datamodel

### `schedule_series`

Een serie bewaart de lokale planningsintentie:

- optionele same-stable `horse_id`;
- `task`, `feeding`, `training`, `care` of `other`;
- een vaste gegevenscategorie;
- begrensde titel en instructie;
- IANA-tijdzone en lokale starttijd;
- `daily`, `weekly` of `interval`;
- positieve intervalwaarde;
- gesorteerde unieke ISO-weekdagen voor weekly;
- optionele duur;
- start-/einddatum;
- `draft`, `active`, `paused` of `ended`;
- een materialisatiehorizon van 1–90 dagen;
- optimistic `row_version`;
- create- en laatste-mutatieactor/request/timestamps;
- optionele typed verwijzing naar een vervangen serie.

De huidige publieke 4C.3-flow accepteert uitsluitend niet-voedingsseries met
`horse.schedule`. De fysieke enumwaarden voor voeding en andere categorieën
zijn al tenantveilig aanwezig, maar worden pas door latere, afzonderlijke
contract-RPC’s geopend.

### `schedule_items`

Een item is één stabiele occurrence en bewaart:

- tenant en optionele same-stable Horse;
- optionele typed seriecorrelatie;
- lokale occurrencedatum en sequence;
- snapshot van type, categorie, titel en minimale instructie;
- `normal` of `high`;
- UTC start/einde plus bron-IANA-zone, lokale datum en lokale tijd;
- `planned`, `in_progress`, `completed`, `skipped` of `cancelled`;
- optionele begrensde state-reden;
- een expliciete occurrence-overrideflag;
- optimistic row-version en serverauditvelden.

De samengestelde serie-FK gebruikt een gegenereerde `horse_scope_key`. Daardoor
kan ook een stalbrede serie met `horse_id = null` nooit aan een Horse-occurrence
worden verwisseld.

`overdue` wordt alleen in het readmodel afgeleid. Het is geen bronstatus.

### `schedule_assignments`

Assignments verwijzen naar een typed `stable_member_id`, nooit naar naam,
e-mail of clientmetadata.

- rollen: `responsible`, `support`, `reviewer`;
- states: `assigned`, `accepted`, `returned`, `completed`, `cancelled`;
- maximaal één actieve responsible per occurrence;
- maximaal één actieve identieke item/person/role-combinatie;
- same-stable item- en roster-FK’s;
- row-version, actors, request-ID’s en lifecycle-timestamps.

Een rosterpersoon zonder account mag gepland worden. Uitvoering kan pas nadat
een actief membership aan exact die rosterpersoon is gekoppeld.

### `schedule_executions`

Executions zijn append-only:

- actor, membership en rosterpersoon worden uit de actieve sessie afgeleid;
- same-stable item-, membership- en roster-FK’s;
- `completed`, `partial`, `skipped`, `refused` of `problem`;
- actual en device-local tijden plus IANA-zone;
- `online` of `offline_sync`;
- bij offline sync is een willekeurige app-installatie-UUID verplicht;
- begrensde notitie;
- optionele typed verwijzing naar één rechtstreeks gecorrigeerde execution.

Een correctie schrijft een nieuw record. De oorspronkelijke execution wordt
nooit gewijzigd. Een volgende correctie kan de vorige correctie als nieuw
bronrecord gebruiken.

### Audit en receipts

Iedere geslaagde 4C.3-mutatie schrijft exact het passende typed
`schedule_change_event`. Events bevatten alleen IDs, eventtype, categorie,
row-version en eventueel een begrensde cancel/reopenreden. Executionnotities
en taakteksten worden niet gekopieerd.

Iedere clientmutatie gebruikt een actor/requestreceipt met:

- vaste operation name;
- stable en typed target;
- SHA-256-payloadhash;
- uitsluitend een veilig resultaat met ID/state/version/count.

De receipt bevat geen taaktekst, instructie of executionnotitie. Een exacte
retry retourneert hetzelfde resultaat met `idempotent: true`. Hergebruik voor
een andere operatie of payload faalt met `REQUEST_ID_REUSED`.

## Recurrence en scopes

`materialize_schedule_occurrences`:

1. lockt membership, grant, Horse en serie in de gedocumenteerde volgorde;
2. begrenst iedere batch door `generation_horizon_days`;
3. selecteert daily/weekly/interval-datums;
4. vormt `timestamptz` met de opgeslagen IANA-zone;
5. bewaart daarnaast de oorspronkelijke lokale datum/tijd;
6. gebruikt een deterministisch afgeleid request-ID per occurrence;
7. schrijft door de unieke `(series_id, occurrence_local_date,
   occurrence_sequence)`-sleutel maximaal één rij;
8. receipteert het veilige batchresultaat;
9. gebruikt de veilige `through_local_date` uit eerdere receipts als duurzame
   scanvoortgang, zodat ook een leeg horizonvenster bij een interval tot 365
   dagen de volgende batch vooruit laat gaan;
10. bindt die voortgang aan de exacte `series_row_version`, zodat een
    toegestane full-serieswijziging oude lege scanvensters ook binnen één
    database-transactie deterministisch ongeldig maakt.

DST-gaten of dubbelzinnige lokale tijden vernietigen de lokale intentie niet:
de bronzone, lokale datum en lokale tijd blijven apart bewaard.

`update_schedule_series_scope` ondersteunt:

- `occurrence`: alleen de aangewezen niet-terminale occurrence wordt een
  expliciete override;
- `future`: de oude serie eindigt vóór de effectieve datum, alleen toekomstige
  nog geplande/onuitgevoerde occurrences worden geannuleerd en een typed
  replacementserie wordt gemaakt;
- `full`: alleen toegestaan zolang de serie nog geen occurrencehistorie heeft.

Uitgevoerde, gedeeltelijk uitgevoerde en terminale historie wordt nooit
stilzwijgend herschreven.

## Autorisatie en minimale taaktoegang

Volledige plan-/itemtoegang volgt exact `horse.schedule`:

- owner en admin: view, plan, edit en execute binnen de actieve stal;
- member: alleen door een actieve, niet-verlopen expliciete Horse-grant;
- viewer: geen breed plan/edit/execute;
- stalbrede taken zonder Horse: alleen owner/admin beheren.

Objecttoewijzing is een afzonderlijke laag:

- een actieve linked `responsible` of `support` mag de taak uitvoeren;
- een `reviewer` mag niet uitvoeren;
- een assignment verleent geen Horse-, team-, identity- of ander
  dossierpermission;
- returned/cancelled/completed assignments verlenen geen nieuwe uitvoering;
- suspension/removal/leave maakt iedere nieuwe read/execution direct
  onmogelijk.

`get_schedule_item` en `list_today_schedule` hercontroleren bij iedere call:

- sessie;
- actief membership;
- actieve stal en Horse;
- volledige categoriepermission of een eigen assignment.

Een assigned-only actor ontvangt titel, minimale instructie, planning,
taskstate en eigen assignmentstatus. De serie-ID wordt verborgen en de
basistabelpolicy blijft deny. Een onbekend of cross-stable ID levert geen
objectoracle: alle vier objectgestuurde mutatieflows antwoorden in beide
gevallen uitsluitend met `SCHEDULE_UNAVAILABLE`.

`list_schedule_executions` toont:

- alle executionhistorie aan full-access actors;
- uitsluitend de eigen executions aan assigned-minimal actors.

Ook de directe execution-RLS hercontroleert die actuele toegang. Een
geschorst, verwijderd of verlaten membership kan daarom geen historische
eigen execution of notitie via de basistabel blijven lezen. De identity-
sequence van het change-eventlog heeft geen clientrechten.

## Executionstate

`record_schedule_execution`:

1. lockt actief membership `FOR SHARE`;
2. lockt de relevante schedule-grant(s) `FOR SHARE`;
3. lockt een actieve Horse `FOR SHARE`;
4. lockt de occurrence `FOR UPDATE`;
5. lockt actieve assignments deterministisch `FOR SHARE`;
6. accepteert een exacte bestaande receipt;
7. hervalideert brede executepermission of linked assignment;
8. schrijft execution, itemstate, typed event en receipt atomair.

Stateprojectie:

- `completed` → `completed`;
- `skipped`/`refused` → `skipped`;
- `partial`/`problem` → `in_progress`.

Een gewone client kan een terminal item niet heropenen. Alleen owner/admin kan
`reopen_schedule_item` met expected row-version en een auditreden uitvoeren.

## RPC-signatures

```text
create_schedule_series(
  uuid, uuid, text, text, text, text, text, text, integer, smallint[],
  time, integer, date, date, integer, text, uuid
) -> jsonb

update_schedule_series_scope(
  uuid, bigint, text, uuid, date, uuid, text, text, text, text,
  integer, smallint[], time, integer, date, integer, text
) -> jsonb

materialize_schedule_occurrences(uuid, date, uuid) -> jsonb

create_schedule_item(
  uuid, uuid, text, text, text, text, text, timestamptz, timestamptz,
  text, date, time, uuid
) -> jsonb

update_schedule_item(
  uuid, bigint, uuid, text, text, text, timestamptz, timestamptz,
  text, date, time
) -> jsonb

cancel_schedule_item(uuid, bigint, uuid, text) -> jsonb
assign_schedule_item(uuid, uuid, text, uuid) -> jsonb
return_schedule_assignment(uuid, bigint, uuid) -> jsonb

record_schedule_execution(
  uuid, uuid, text, timestamptz, timestamptz, timestamp,
  text, text, uuid, text
) -> jsonb

correct_schedule_execution(
  uuid, uuid, text, timestamptz, timestamptz, timestamp,
  text, text, uuid, text
) -> jsonb

reopen_schedule_item(uuid, bigint, uuid, text) -> jsonb
get_schedule_item(uuid) -> table
list_today_schedule(uuid, date) -> table
list_schedule_executions(uuid) -> table
```

Alle mutatie- en read-RPC’s zijn `SECURITY DEFINER`, gebruiken een lege
`search_path`, leiden actor/stable server-side af en zijn alleen aan
`authenticated` verleend.

## RLS, ACL en append-only

Alle vijf publieke tabellen hebben RLS. `anon` heeft geen tabel- of
RPC-toegang. `authenticated` heeft alleen `SELECT`; mutaties zijn RPC-only.

- series/items/change-events: uitsluitend full category access;
- assignments: full access of de eigen rosterassignment;
- executions: full access of de eigen actorrows;
- assigned-minimal itemvelden uitsluitend via de twee beveiligde read-RPC’s.

De private receipttabel en alle interne helpers zijn niet clientleesbaar.
Triggers blokkeren ook privileged `UPDATE`/`DELETE` van executions en
change-events met `APPEND_ONLY_RECORD`.

## Locking en concurrency

De normale volgorde is:

```text
stable/Horse/item zonder relevante lock vinden
→ actor-membership FOR SHARE
→ actieve horse.schedule-grants deterministisch FOR SHARE
→ Horse FOR SHARE
→ series/item FOR UPDATE
→ assignments deterministisch FOR SHARE/UPDATE
→ volledige hervalidatie
→ mutatie + event + receipt
```

Fase-4B authoritymutaties en Horse-archive locken eerst stal/memberships en
vervolgens Horse. Een 4C.3-transactie met een membership-sharelock mag daarom
eerst afronden; een later gestarte mutatie ziet de gecommitte intrekking of
archive. Er ontstaat geen Horse/item-lockinversie.

## Lokale verificatie

Gerichte artifacts:

- `supabase/tests/phase_4c3_planning_tasks.sql`;
- `supabase/tests/phase_4c3_planning_tasks_concurrency.rb`;
- `supabase/tests/phase_4c3_upgrade_fixture.sql`;
- `supabase/tests/phase_4c3_upgrade_verification.sql`.

De SQL-matrix dekt onder meer schema/ACL/RLS, same-stable FK’s, critical
fail-closed, owner/admin/member/viewer, assigned-only en unlinked roster,
Today/deep link, create/update/cancel/reopen, execution/correctie,
requestreplay/payloadmismatch, daily/weekly/interval, DST, occurrence/future/
full scopes, directe DML, anon, suspension, cross-stable-oracles en een
onaangeraakte controlestal.

De Ruby-harness gebruikt twee echte `psql`-verbindingen en een
database-zichtbare advisory-lockbarrière. Per volledige cyclus racet hij:

- execution tegen execution met verschillende request-ID’s;
- dezelfde executionrequest tegen zichzelf;
- execution tegen assignment-return in beide volgordes;
- execution tegen membership-suspend in beide volgordes;
- execution tegen Horse-archive in beide volgordes;
- taskupdate tegen Horse-archive in beide volgordes.

Deadlock, timeout, dubbele execution/event/receipt, uitvoering na authority- of
statusverlies, verloren update of wijziging van de controlestal is altijd een
testfout.

De formele upgradeproef start exact op 4C.2B, bewaart representatieve Horse,
identifier, relationship en beide 4C.2B-receipts, past uitsluitend 4C.3 toe en
bewijst dat geen scheduledata wordt gefabriceerd.
