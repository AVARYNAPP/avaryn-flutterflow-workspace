# Fase 4B.2 — stallen, medewerkers en lidmaatschappen

Status: lokaal geïmplementeerd en getest. Niet gedeployed. Paarden, planning,
voeding en historie blijven lokaal tot fase 4C.

## Identiteitsgrenzen

De volgende identifiers zijn bewust niet uitwisselbaar:

1. `auth.users.id`: immutable accountidentiteit;
2. `profiles.id`: persoonlijk profiel van hetzelfde account;
3. `stables.id`: cloudworkspace;
4. `stable_members.id`: operationele persoon binnen één stal;
5. `stable_memberships.id`: autoritatieve account-stalrelatie;
6. toekomstige relaties tussen medewerkers en paarden.

Een auth-UUID wordt nooit als medewerker-ID gebruikt. Een operationele
medewerker kan zonder AVARYN-account bestaan. Namen, functietitels,
profielvelden, e-mailadressen en user metadata verlenen nooit rechten.

## Datamodel

- `stables`: `organization` of `personal`, soft archive, idempotente creatie
  via `(created_by_user_id, creation_request_id)`.
- `stable_members`: operationeel roster met naam, functietitel, status en
  optioneel exact behouden legacy-ID. Geen beveiligingsrol.
- `stable_memberships`: permanente unieke `(stable_id, user_id)`-relatie. Een
  actief membership vereist een `stable_member`. Een medewerker is maximaal
  aan één membership gekoppeld.
- `stable_invitations`: zeven dagen geldig, alleen SHA-256-tokenhash, nooit raw
  token. Maximaal één pending uitnodiging per stal/e-mailadres en per gekozen
  medewerker.
- `account_workspace_preferences`: eigen stalkeuze en verwerkte
  onboarding-handoff.
- `stable_security_events`: append-only audit zonder raw token of volledig
  e-mailadres.
- `private.stable_invitation_rate_events`: niet-publieke counters met alleen
  recipienthash.

Een partial unique index voorkomt meer dan één actieve owner. Deferred
constraint-triggers controleren bij transactie-einde dat elke actieve stal
exact één actieve owner heeft. De triggerfuncties zijn `SECURITY DEFINER`,
hebben `search_path = ''` en tellen buiten RLS. Eigendomsoverdracht lockt stal,
huidige owner en doelmembership, degradeert de huidige owner en promoveert het
doel binnen één transactie.

Alle mutaties die dezelfde stal en memberships kunnen raken gebruiken
`private.lock_stable_membership_mutation`: eerst exact één stalrij, daarna alle
membershiprijen van die stal in oplopende UUID-volgorde. Dit serialiseert alleen
mutaties binnen dezelfde stal; er is geen globale tabel-, database- of
advisory lock.
Invitation decline doet eerst uitsluitend een niet-vergrendelende discovery-read
van de kandidaat-stal, gebruikt daarna dezelfde helper en lockt en valideert pas
dan de invitation opnieuw. Accept en decline volgen daardoor beide
stable → memberships → invitation vóór hun terminale mutatie en eventwrite.
Voorheen lockte `remove_stable_membership` eerst het doel en daarna de actor,
terwijl `transfer_stable_ownership` eerst stal en actor en daarna het doel
lockte. Bij transfer/remove kon daardoor target → owner tegenover owner →
target ontstaan. De deadlock trad op vóór updates, deferred ownertriggers en
security-eventinserties.

## Rollenmatrix

| Actie | owner | admin | member | viewer |
| --- | --- | --- | --- | --- |
| Stal en veilige ledenlijst lezen | ja | ja | ja | ja |
| Authority muteren | ja | beperkt | nee | nee |
| Member/viewer uitnodigen en beheren | ja | ja | nee | nee |
| Admin uitnodigen en beheren | ja | nee | nee | nee |
| Owner uitnodigen | nee | nee | nee | nee |
| Eigendom overdragen | ja | nee | nee | nee |
| Stal archiveren | ja | nee | nee | nee |
| Later operationeel schrijven | ja | ja | ja | nee |

Een admin kan een admin of owner niet wijzigen, verwijderen, schorsen of
uitnodigen. Een owner kan niet vertrekken of worden verwijderd voordat
eigendom veilig is overgedragen.

## RLS

Alle zes publieke tabellen hebben RLS en beginnen default-deny. `anon` heeft
geen tabel- of RPC-rechten op invitations.

| Resource | Normaal actief lid | owner/admin | Andere stal / outsider |
| --- | --- | --- | --- |
| `stables` | eigen actieve stallen | eigen actieve stallen | geen rijen |
| `stable_members` basistabel | geen directe rijen | eigen roster | geen rijen |
| veilige directory-RPC | alleen naam en functietitel | naam en functietitel | leeg |
| `stable_memberships` | eigen rij | alle rijen eigen stal | geen rijen |
| `stable_invitations` | geen rijen | eigen stal | geen rijen |
| `account_workspace_preferences` | alleen eigen rij | alleen eigen rij | geen rij |
| `stable_security_events` | geen rijen | eigen stal | geen rijen |

Niet-recursieve helpers staan in schema `private`. Alleen vier kleine
read-helpers zijn executeerbaar voor `authenticated`; het schema is niet via de
API geëxposeerd. Tabellen verlenen alleen `SELECT`; alle writes verlopen via
gecontroleerde functies.

## Serverfuncties

Beschikbaar voor `authenticated`, met server-side `auth.uid()`, lege
`search_path`, volledig gekwalificeerde relaties, relevante row locks en audit
in dezelfde transactie:

- `create_stable`
- `update_stable`
- `archive_stable`
- `create_stable_invitation`
- `resend_stable_invitation`
- `accept_stable_invitation`
- `decline_stable_invitation`
- `revoke_stable_invitation`
- `change_stable_member_role`
- `remove_stable_membership`
- `suspend_stable_membership`
- `leave_stable`
- `transfer_stable_ownership`
- `link_account_to_stable_member`
- `set_selected_stable`
- `list_stable_member_directory`

`preview_stable_invitation` is alleen voor `service_role` en wordt uitsluitend
door de serverroute gebruikt. Brede execute-rechten voor `public` en `anon`
zijn ingetrokken.

De lokale `AvarynStableRuntime` sluit deze bestaande functies aan via één
testbare `Phase4BManagementController` en één Supabase-gateway. De controller
blokkeert offline en dubbele inzendingen, past de owner/admin-matrix toe,
ververst na succes de serverstatus en wist bij 401/403 de actieve
autoriteitscontext. Postgres blijft altijd de definitieve autoriteit.

## Uitnodigingslifecycle en tokenbeveiliging

De lokale `stable-invitations` Edge Function ondersteunt `create`, `preview`,
`accept`, `decline`, `revoke` en `resend`.

1. De function maakt 32 cryptografisch willekeurige bytes.
2. Zij berekent direct SHA-256.
3. Alleen de hash gaat naar Postgres.
4. De raw waarde bestaat alleen tijdelijk in functiongeheugen en één
   succesvolle creator-response.
5. De deelbare route gebruikt een URL-fragment (`#token=...`), niet pad of
   query, zodat de raw waarde niet in normale HTTP-accesslogs komt.
6. Alleen een pending preview retourneert stalnaam, kind en aangeboden rol.
   Verlopen, gebruikte, ingetrokken en geweigerde tokens retourneren uitsluitend
   een neutrale status.
7. Accept/decline leiden de gebruiker af uit een geldige bearer session en
   vergelijken server-side met het bevestigde account-e-mailadres.
8. Accept is transactioneel en idempotent; een target-rosterrecord wordt
   gekoppeld of na expliciete naaminput veilig aangemaakt.
9. Resend roteert de hash; het oude token is direct ongeldig.

Limieten: cooldown 60 seconden, maximaal vijf resends per recipient/stal per
24 uur en maximaal twintig invitation-acties per actor per 24 uur.

Er is geen e-mailprovider geconfigureerd. Lokaal wordt geen echte mail
verstuurd; alleen een eenmalig kopieerbare link is beschikbaar. De UI wist de
transiente link na kopiëren en bewaart raw tokens niet in SharedPreferences,
app-state, analytics of documentatie.

## Onboarding-handoff

- `createStable`: expliciet formulier voor naam en tijdzone; na bevestiging
  worden stal, owner-roster en owner-membership atomair gemaakt. Lokale mapping
  is daarna een aparte bevestiging.
- `joinStable`: zonder token alleen uitleg. Met token alleen minimale preview.
  Niet-ingelogd gaat eerst door bestaande auth. Acceptatie is nooit
  automatisch.
- `individualHorse`: expliciete private workspace, standaardnaam `Mijn
  paarden`, aanpasbaar vóór bevestiging. Geen paard en geen uitnodiging wordt
  automatisch gemaakt.

`intent_consumed_at` wordt pas gezet na succesvolle stable creation of
invitation acceptance.

## Lokale mapping en contextwissel

Fase 4B verhoogt `LocalAccountScopeData.schemaVersion` naar 2 en voegt toe:

- `selectedCloudStableId`;
- `LocalStableCloudLinkData`;
- per cloudstal een bestaand lokaal `selectedHorseId`;
- `StableMembershipCacheData`;
- `lastMembershipValidatedAt`;
- rollbackveilige accountmasters voor operationele lokale data.

`currentLocalStableId` blijft altijd een lokale ID. Bestaande SharedPreferences
keys en lokale IDs blijven behouden. `legacyLocalDataBackup` blijft bestaan.
Persisted app-state wordt via de FlutterFlow-instelling voor secure persisted
values versleuteld zodra de DSL later afzonderlijk wordt toegepast.

De centrale switchroutine:

1. maakt vóór iedere account-, logout- of stalwissel met
   `phase4BPlanSerializedOperationalMasterSave` en
   `phase4BMergeOperationalMasterMaps` één gedeeld uitvoerbaar savecontract
   onderscheid tussen een gekoppelde lokale stalscope en een unlinked context;
2. voegt een gekoppelde scope terug in uitsluitend die lokale stalscope van de
   volledige accountmaster; ook een bewust geleegde gekoppelde scope wordt als
   geldige lege scope opgeslagen;
3. schrijft vanuit een unlinked context met lege `currentLocalStableId` niets
   terug en behoudt een bestaande accountmaster byte-voor-byte; een lege
   working set kan de gekoppelde scopes dan niet vervangen;
4. neemt vanuit een gekoppelde scope alle actuele operationele counters,
   paardindex, schema- en seedversies en toekomstige niet-scoped mastervelden
   mee;
5. wist de vorige gevoelige werkset vóór netwerk-I/O;
6. valideert het gekozen actieve membership online;
7. zet de cloudkeuze;
8. zoekt uitsluitend een expliciet bevestigde mapping van hetzelfde account;
9. laadt alleen paarden, activiteiten, voeding en historie met die lokale
   stal-ID;
10. toont bij ontbrekende mapping een lege context;
11. wist bij 401/403 onmiddellijk de werkset en toont access
    removed/suspended;
12. wist de werkset en cloudselectie bij logout, nadat een eventueel gekoppelde
    actuele scope veilig is opgeslagen.

Een opslagfout stopt de wissel vóór validatie en loading van het doel. Bij een
ontbrekende mapping worden naast alle operationele records ook
`currentLocalStableId`, geselecteerd paard, drafts, geselecteerde activiteit,
voerdatum en voerronde gewist. De per-stal paardkeuze wordt vóór wisselen en
accountlogout vanuit een gekoppelde scope teruggeschreven naar de expliciete
mapping. Logout en accountwissel gebruiken exact hetzelfde saveplan als de
stalwissel. Vanuit een unlinked context vindt geen lege vervangingswrite plaats.
Bestaande lokale IDs, `legacyLocalDataBackup` en gegevens van andere gekoppelde
lokale stallen blijven daardoor behouden, zonder dat zij opnieuw in de actieve
lege working set verschijnen.

Offline authority is maximaal een kortdurende read-only cache. Offline
stalwissels en alle authority-mutaties zijn uitgeschakeld.

## Routes en navigatie

Publiek:

- `/uitnodiging`
- `/uitnodiging/ongeldig`

Authenticated subflow:

- `/onboarding/workspace`
- `/stallen/nieuw`
- `/persoonlijke-workspace`
- `/stallen`
- `/stal`
- `/stal/leden`
- `/stal/leden/detail`
- `/stal/uitnodigen`
- `/stal/uitnodigingen`
- `/stal/rollen`
- `/stal/toegang`
- `/stal/lokale-koppeling`

De bestaande vijf mobiele tabs blijven ongewijzigd. Stalbeheer is een subflow.
De nieuwe schermen gebruiken dezelfde AVARYN-navigatie en een contextselector,
met compacte layout onder 700 px en een begrensde desktopcanvas. De lokale
uitvoerbare layoutcontroller is gericht gecontroleerd voor 390 px en 1024 px.

De lokale runtime biedt daadwerkelijk:

- selectie van een operationele medewerker en het eventueel gekoppelde
  membership;
- toegestane rolwijziging, suspend, remove en self-leave;
- afzonderlijk bevestigde ownership-transfer;
- koppeling van een bestaand accountmembership aan een ongekoppelde
  medewerker;
- owner/admin-afhankelijke invitationrolkeuze;
- resend met eenmalige nieuwe link en revoke;
- update van stalnaam/tijdzone en door owner bevestigde archivering.

Personal workspaces tonen geen invitationacties. Offline blijven veilige
autoriteitsgegevens read-only en worden geen mutaties gequeued.

Een medewerkerklik maakt een expliciete `stableMemberId`-routeparameter. De
nieuwe detailruntime initialiseert haar bedoelde selectie met die parameter en
valideert hem na iedere load of refresh opnieuw tegen de actuele
`selectedCloudStableId` en serverroster. Een ontbrekende, verouderde of
cross-stal-ID toont een veilige not-foundstatus; de detailruntime valt dan niet
terug op de eerste medewerker. Na een geldige initialisatie kan de gebruiker
via de dropdown bewust een andere medewerker kiezen.

## Lokaal testen

Gebruik de repository-pinned Flutter 3.35.7 en Supabase CLI 2.75.0.

```sh
.flutterflow/sdk/bin/supabase start
.flutterflow/sdk/bin/supabase db reset --local
docker exec -i supabase_db_avaryn-flutterflow-workspace \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /dev/stdin \
  < supabase/tests/phase_4b_stables_rls.sql
docker exec -i supabase_db_avaryn-flutterflow-workspace \
  psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /dev/stdin \
  < supabase/tests/phase_4b_security_matrix.sql
ruby supabase/tests/phase_4b_membership_concurrency.rb
ruby supabase/tests/phase_4b_membership_concurrency.rb \
  --scenario 3 --start-order leave-first
ruby supabase/tests/phase_4b_membership_concurrency.rb \
  --scenario 3 --start-order transfer-first
ruby supabase/tests/phase_4b_membership_concurrency.rb \
  --scenario 3 --iterations 25 --quiet
ruby supabase/tests/phase_4b_membership_concurrency.rb \
  --scenario 6 --start-order accept-first
ruby supabase/tests/phase_4b_membership_concurrency.rb \
  --scenario 6 --start-order decline-first
ruby supabase/tests/phase_4b_membership_concurrency.rb \
  --scenario 6 --iterations 25 --quiet
dart test test/app_test.dart
dart test test/phase_4b_context_test.dart
dart test test/phase_4b_management_test.dart
```

De invitation-integratietest leest lokale statuswaarden uit een tijdelijk,
niet-gecommit bestand en print geen tokens of lokale sleutels.

De pure-Dart behavior-tests voeren iedere beheerhandler uit met een fake
gateway en bewijzen RPC-naam, parameters, rolblokkades, offlinegedrag,
double-submitbescherming, refresh, veilige fouten, transient links en
responsive route-state. De contexttests voeren hetzelfde volledige
`phase4BPlanSerializedOperationalMasterSave`-contract met
`phase4BMergeOperationalMasterMaps` uit dat door de account- en stalruntime
voor logout, accountwissel en stalwissel wordt aangeroepen. De
regressies vergelijken de volledige resulterende masters van de drie routes en
testen alle horse-, activity-, feeding-, temporary-schedule-,
assignment-exception- en execution-counters, de paardindex, schema- en
seedversies, save → volledige runtimeherinitialisatie → reload en twee
opeenvolgende collisionvrije ID-allocaties. Zij testen daarnaast linked →
unlinked → logout/accountwissel, herhaalde accountwissels, bewust lege
gekoppelde scopes, behoud van een tweede stal en account, opslagfalen en
afwezigheid van oude working-setdata. De routetests voeren dezelfde
`Phase4BMemberSelectionCoordinator` uit die routeparameters maakt en in de
detailruntime actuele serverresultaten valideert, inclusief tweede, derde,
onbekende en cross-stal-ID's en herhaalde refresh.

Dit is uitvoerbaar gedeeld runtimecontract- en controllerniveau. Het is geen
claim over reeds gegenereerde fase-4B-widgettests.

De aanvullende SQL-matrix voert voor anon, outsider, viewer, member, admin en
owner directe insert/update/delete-aanvallen uit op alle zes publieke tabellen.
Removed, suspended en left worden afzonderlijk gecontroleerd op alle
stalresources en relevante RPC's. De Ruby-harness opent werkelijk afzonderlijke
Postgresverbindingen voor transfer/transfer, transfer/remove,
transfer/owner-leave, remove/member-leave en remove/remove. Een zesde scenario
laat invitation accept en decline tegen elkaar racen met zowel accept-first als
decline-first. Na iedere race wordt iedere verbinding geclassificeerd als
gecommitte mutatie, gecontroleerde SQLSTATE-fout of veilige idempotente
uitkomst. Iedere deelnemer heeft een unieke request-ID. Voor een gecommitte
mutatie moet precies één event met diezelfde request-ID, het exacte eventtype,
stal-ID, actor-ID en doelmembership bestaan. Geweigerde of teruggedraaide
deelnemers moeten exact nul events hebben.

“Exact één winnaar” geldt uitsluitend voor wederzijds uitsluitende races:
transfer/transfer, transfer/remove, remove/leave, remove/remove en
invitation accept/decline. Transfer/owner-leave is serieel combineerbaar en
gebruikt daarom `committed` en `rejected`, niet automatisch `winner` en
`loser`. Na een gecommitte ownership transfer is de voormalige owner admin.
Een daaropvolgende leave van die voormalige owner is een geldige
domeinmutatie. De twee en uitsluitend twee toegestane volledige seriële
uitkomsten zijn:

1. leave wordt eerst beoordeeld, wordt met
   `42501 OWNER_MUST_TRANSFER_FIRST` veilig geweigerd en schrijft nul events;
   transfer commit daarna met exact één `ownership_transferred`-event. De
   voormalige owner blijft actieve admin en de nieuwe owner blijft actief;
2. transfer commit eerst met exact één `ownership_transferred`-event, waarna
   de voormalige owner als admin mag vertrekken en exact één
   `membership_left`-event schrijft. De voormalige owner eindigt als
   `admin/left` met `ended_at`; de nieuwe owner blijft de enige actieve owner.

De harness accepteert geen losse eventset als bewijs. Iedere toegestane
uitkomst is een volledige signatuur van resultaat en SQLSTATE per deelnemer,
ieders unieke request-ID, eventtype en eventaantal per request-ID, definitieve
owner, rol/status/lifecycle van de voormalige owner en overige fixtureleden,
invitationstatus en -membership wanneer relevant, unieke en cross-stalveilige
medewerkerkoppelingen en een volledig onaangeroerde controlestal. Een verkeerde
combinatie van deelnemer, event en eindtoestand kan daardoor niet slagen omdat
alleen het totale eventset toevallig klopt.

De harness maakt iedere request-ID vóór de gezamenlijke startbarrière, wacht
begrensd op beide afzonderlijke `psql`-processen en rapporteert voor beide
deelnemers request-ID, classificatie, SQLSTATE, exact antwoord, verwacht event,
werkelijke events en eventaantal voordat een scenario kan falen. `40P01`,
timeouts, onleesbare antwoorden en onbekende fouten zijn nooit toegestane
uitkomsten. In de gerichte fase-4B.9-verificatie slaagden accept-first en
decline-first afzonderlijk 1/1. Daarna slaagden 50/50 verse accept/decline-races
met 100/100 afzonderlijk gevalideerde deelnemers. De vijf bestaande
membershipraces slaagden opnieuw 5/5 met 10/10 deelnemers. Iedere iteratie
controleerde unieke request-ID's, exacte eventcorrelatie, owner- en
lifecycle-invarianten en een onaangeroerde tweede stal.

In de gerichte fase-4B.10-verificatie slaagde scenario 3 afzonderlijk in beide
startvolgorden. De leave-first-uitvoering matchte de geweigerde leave plus
gecommitte transfer; de transfer-first-uitvoering matchte twee correct
gecorreleerde commits. Daarna slaagden 50/50 verse scenario-3-races met
100/100 afzonderlijk gevalideerde deelnemers tegen de volledige
uitkomstsignaturen. Alle zes standaardscenario's slaagden vervolgens in 8/8
racevarianten en 16/16 deelnemers, omdat scenario 3 en 6 elk in beide
startvolgorden draaien. Twintig volledige suites slaagden met 160/160 verse
races en 320/320 deelnemers. De bestaande fase-4B RLS- en securitymatrix
slaagden en rolden volledig terug; de invitation-integratie slaagde met 23
asserties. Geen toegestane uitkomst bevatte `40P01`, timeout, hang, dubbel of
ontbrekend event, verloren update, invariantbreuk of wijziging van de
controlestal.

De Edge-integratietest zet daarnaast een echte lokale invitation-expiry in het
verleden en voert daarna preview en accept uit. Zij bewijst dat geen membership
ontstaat en dat de verlopen token niet opnieuw bruikbaar wordt.

## Accountverwijdering

Accountverwijdering blijft uitgeschakeld. De lokale Edge-voorbereiding weigert
expliciet en vóór enige mutatie bij:

- Apple-identiteit zonder geteste revocation;
- actieve ownership;
- andere actieve memberships;
- ontbrekende veilige volledige delete-implementatie.

Er worden in fase 4B geen avatars, profielen of auth-records verwijderd.

## Uitgesteld tot fase 4C of online configuratie

- cloudtabellen en migratie van paarden, planning, voeding en historie;
- automatische synchronisatie of conflictresolutie;
- omzetting van personal workspace naar organization;
- echte invitation-e-mailbezorging;
- hosted invitationroute en mobile universal/app links;
- productie-Edge secrets en providerconfiguratie;
- veilige volledige accountdelete en Apple revocation;
- uitvoering van deze lokale FlutterFlow DSL tegen de remote FlutterFlow
  projectbackend.

Voor online e-mailbezorging moeten later afzonderlijk een provider, afzender,
template, rate-monitoring en een hosted `AVARYN_INVITATION_URL` worden
geconfigureerd. Hosted web- en mobiele routes moeten het token uitsluitend uit
het fragment in tijdelijk geheugen consumeren. Geen van deze instellingen is
in fase 4B lokaal of op productie gewijzigd.

## Analyzerbaseline

Fase 4A blijft de volledige generated-codebaseline:

- 0 fouten;
- 1.578 waarschuwingen;
- 2.975 info/lints;
- gerichte fase-4A-analyse: 0 fouten en 0 waarschuwingen.

Fase 4B mag geen nieuwe gerichte fout of waarschuwing introduceren. De
gegenereerde runtimecode blijft onaangeroerd; daardoor wordt de volledige
baseline alleen opnieuw gemeten tegen dezelfde snapshot en niet als nieuwe
remote codegeneratie gepresenteerd.

De fase-4B DSL/runtime is dus lokaal geïmplementeerd en op controller-, SQL- en
Edge-integratieniveau getest. De bestaande `generated_code/` blijft de
fase-4A-snapshot. De uiteindelijke gegenereerde fase-4B-app, widgetcompilatie en
visuele 390/1024-QA worden pas waarheidsgetrouw mogelijk na een afzonderlijk
goedgekeurde FlutterFlow-toepassing en codegen.
