# AVARYN Fase 5A — Alpha-traceerbaarheid

## 1. Legenda

| Status | Betekenis |
| --- | --- |
| gereed en bewezen | implementatie en relevante automatische regressies bestaan |
| aanwezig, onvoldoende getest | flow bestaat maar mist formeel Alpha-E2E-, responsive- of statebewijs |
| aanwezig, functioneel onvolledig | backend of UI bestaat, maar de tester kan de volledige Alpha-flow nog niet uitvoeren |
| productbeslissing | verschillende geldige productuitkomsten vereisen expliciete keuze |
| buiten fase 5 | uitgesloten door het fase-5-contract |

`AvarynAccountRuntime`, `AvarynStableRuntime` en
`AvarynOperationalRuntime` zijn de drie bestaande FlutterFlow-runtimegrenzen.
De server-side bron van waarheid bestaat uit de migraties en tests onder
`supabase/`.

## 2. Requirementsmatrix

| ID | Alpha-eis | Schermen/runtime | Backend en authority | Bestaand bewijs | Handmatige acceptatie | Status en ontbrekende afronding |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | account aanmaken en bevestigen | Auth Create, Verify, Callback; account-runtime | Supabase Auth, `profiles` | fase-4A auth-, RLS- en compiletests | registreer fictief lokaal account, open Mailpit-link, bereik gate | aanwezig, onvoldoende getest: formeel browser-E2E ontbreekt |
| A02 | login en wachtwoordherstel | Auth Login, Forgot, Reset | Supabase Auth | account-runtime compiletest en lokale authsuite | login, fout wachtwoord, resetlink, nieuw wachtwoord | aanwezig, onvoldoende getest |
| A03 | veilig uitloggen | Profile/account-runtime | Auth sign-out plus UUID-scoped secure purge | fase-4C.7 purge-/contracttests | logout vanuit operationeel scherm; geen vorige data zichtbaar | aanwezig, onvoldoende getest: Alpha-E2E ontbreekt |
| A04 | accountwissel zonder datalek | Auth Gate/account-runtime | auth UUID, accountscopes, secure purge | fase-4B contexttests en 4C.7 audit | A → logout → B; geen A-data of selectie zichtbaar | aanwezig, onvoldoende getest: browser/native acceptatie ontbreekt |
| A05 | stal/werkomgeving kiezen | Stable Handoff, Picker, selector | `stable_memberships`, `set_selected_stable` | fase-4B SQL-, context- en managementtests | wissel stal A → B → A, inclusief lege scope | aanwezig, onvoldoende getest |
| A06 | stal en klein team beheren | Create Stable, Details, Members, Roles | `stables`, memberships en authority-RPC's | fase-4B RLS/security/concurrency | owner/admin/member/viewer-matrix doorlopen | aanwezig, onvoldoende getest |
| A07 | teamlid uitnodigen/accepteren | Invite, Pending, Invitation | invitation Edge Function en invitation-RPC's | 23 lokale integratieasserties plus concurrency | create, preview, accept, decline, resend en revoke via eenmalige lokale manual-share-link | aanwezig, onvoldoende getest |
| A08 | Horse aanmaken en lezen | Horses Overview/operational runtime | `horses`, `create_horse`, RLS | 4C.2A SQL/concurrency en runtimecompile | maak Horse, ververs en zie hem uitsluitend in juiste stal | aanwezig, onvoldoende getest: formeel E2E ontbreekt |
| A09 | Horse-kerngegevens beheren | Horse Detail/Edit versus operational runtime | `update_horse_profile`, `archive_horse` | backendtests bestaan | wijzig naam/kernveld met row-version; bewijs conflict | aanwezig, functioneel onvolledig: actuele Alpha-runtime ontsluit update/archive niet |
| A10 | Horse-relaties en beperkte toegang | Stable Access/Member Details en Horse-context | `horse_relationships`, `horse_access_grants`, grant/revoke-RPC's | 4C.2A/2B SQL en concurrency | geef beperkte Horse-toegang, revoke, test cross-stable denial | aanwezig, functioneel onvolledig: geen complete Horse-grantflow in Alpha-UI |
| A11 | taak aanmaken | Planning/operational runtime | `schedule_items`, `create_schedule_item` | 4C.3 SQL/concurrency en runtimecompile | maak een taak met Horse, tijd en categorie | aanwezig, functioneel onvolledig: alleen minimale taakcreate |
| A12 | terugkerende routines | Planning en Today | `schedule_series`, materialisatie-RPC's | backend recurrence- en racetests | maak drie series; materialiseer en controleer twee dagen | aanwezig, functioneel onvolledig: geen serie-UI |
| A13 | taak toewijzen | Planning/Team | `schedule_assignments`, `assign_schedule_item` | backend RLS/concurrency | wijs groom toe; andere gebruiker ziet opdracht niet | aanwezig, functioneel onvolledig: geen assignment-UI |
| A14 | Today op logische dagen | Today/operational runtime | `list_today_schedule` | SQL-tests en runtimecompile | vandaag plus tweede lokale staldag/DST-rand | aanwezig, onvoldoende getest; datumkeuze/fixturebewijs ontbreekt |
| A15 | uitvoering registreren | Today/Feeding Execution | record- en sync-execution-RPC's | SQL, idempotentie en concurrency | voltooi toegewezen taak exact eenmaal | aanwezig, onvoldoende getest: formeel E2E ontbreekt |
| A16 | voerplanversionering en activatie | Feeding Overview | feeding plans, versions en lifecycle-RPC's | 4C.4 SQL/concurrency | draft, versie, approve, activate en retire met denied-tegenproef | aanwezig, functioneel onvolledig: UI maakt alleen een conceptplan |
| A17 | private operationele media | Horse/executioncontext nog niet ontsloten | private bucket, media-assets/links en media-RPC's | 4C.5 SQL, Ruby Storage/Edge en concurrency | upload, finalize, authorize, archive; denial voor andere Horse/stal | aanwezig, functioneel onvolledig: geen operationele mediaflow in Alpha-UI |
| A18 | private Realtime-update | operational runtime | private topics plus `pull_operation_changes` | 4C.6 SQL/concurrency en generated build | wijzig in sessie A, veilige refresh in sessie B | aanwezig, onvoldoende getest: multi-session Alpha-E2E ontbreekt |
| A19 | offline dagset en pending-sync | operational runtime op ondersteund native/desktop | device/dayset/sync-RPC's | 4C.6 SQL/concurrency en 4C.7 contracttests | prepare, verbreek netwerk, execute, restart, reconnect | aanwezig, onvoldoende getest: native E2E ontbreekt |
| A20 | browseroffline | web-runtime | bewust uitgeschakeld; geen goedgekeurde browserkeystore | webbuild en fail-closed bronasserties | netwerk weg: geen plaintext/fallback en duidelijke state | productbeslissing: beveiligde webopslag vereist nieuw contract |
| A21 | retries en idempotentie | operational runtime | mutation receipts en request-ID-contract | SQL 100-retrytests en pure ledgertests | simuleer ambigue response en retry exact dezelfde payload | aanwezig, onvoldoende getest: transport-E2E ontbreekt |
| A22 | conflicten | operationele conflictindicator | `sync_conflicts`, list/resolve-RPC's | 4C.6 RLS/idempotentietests | forceer base-versionconflict; alleen actor ziet hem | aanwezig, functioneel onvolledig: indicator bestaat, resolver-UI niet |
| A23 | revoke/authority-reset | alle drie runtimes | authorityversion, topicrotatie, device revoke | SQL races, purgecontract en audit | revoke tijdens sessie/offline; oude data direct weg bij detectie | aanwezig, onvoldoende getest: multi-client acceptatie ontbreekt |
| A24 | loading/empty/error/offline/denied/conflict | account-, stable- en operational runtime | RLS/RPC-foutcodes | bronasserties en compiletests | forceer iedere state en controleer herstelactie | aanwezig, onvoldoende getest |
| A25 | navigatie zonder doodlopers | alle Alpha-routes | auth- en membershipgate | route-/bronasserties | doorloop mobiel/tablet/desktop en browser back/refresh/deeplink | aanwezig, onvoldoende getest |
| A26 | Paard/Ruiter/Team gescheiden | Horse-, Profile- en Teamroutes | gescheiden profiles, semantische relationships, grants en memberships | schema- en RLS-tests | persona-labels en Horse-relaties verlenen geen authority | aanwezig, onvoldoende getest: UI-copy en E2E controleren |
| A27 | notificaties/reminders | geen actuele operationele Alpha-runtime | geen fase-4 notificationbackend; besluitrecord beperkt scope tot reeds contractueel geïmplementeerd | besluitrecord `AVARYN-P5-2026-07-27` | n.v.t.; voeg geen nieuwe notificationfeature toe | buiten fase 5 op grond van de actuele bindende scope |
| A28 | responsive en basis-a11y | alle Alpha-routes | n.v.t. | webbuild en eerdere auth-boundaryscreenshots | 390×844, tablet en desktop; keyboard, focus, labels, contrast | aanwezig, onvoldoende getest |
| A29 | één cloudbron zonder lokale split-brain | operationele pagina's plus oude Horse/Activity/Feeding/Nutrition-routes | cloud-RLS/RPC moet de autoritatieve bron blijven | generated snapshot toont nog lokale sample-seeding en lokale formwrites | start schoon, navigeer alle routes, bewijs dat geen prototypegegevens verschijnen of clouddata overschrijven | aanwezig, functioneel onvolledig: lokale seeding en oude lokale schrijfroutes moeten worden verwijderd, geïsoleerd of veilig omgeleid |
| A30 | geldige FlutterFlow-stateconfiguratie | AppState en formroutes | n.v.t. | laatste run is groen maar meldt vijf nullable-statewaarschuwingen | cold start, refresh en deeplink zonder null-crash | aanwezig, onvoldoende getest: warnings oplossen of aantoonbaar als veilige nullable state documenteren |
| A31 | lokale uitnodigingsoverdracht | Invite/Invitation | lokale Edge Function; raw token nooit duurzaam opslaan | Ruby-integratiesuite | fictieve invite via eenmalige lokale manual-share-link, zonder echte e-mail | aanwezig, onvoldoende getest: hosted mail/deeplink blijft deploymentvoorwaarde |
| A32 | onboarding voltooien | Onboarding/account-runtime | eigen `profiles`-record en server-side Auth-UUID | fase-4A RLS en runtimecompile | doorloop verplichte profielstappen en cold refresh | aanwezig, onvoldoende getest: formeel E2E ontbreekt |
| A33 | persoonlijk profiel en avatar beheren | Personal Profile/account-runtime | eigen `profiles`, private `avatars` en padcontrole | fase-4A RLS, Storage-integratie en runtimecompile | wijzig profiel, upload/verwijder fictieve avatar, test cross-user denial | aanwezig, onvoldoende getest: formeel UI-E2E ontbreekt |
| A34 | voeritems, units en tijdelijke overrides | Feeding Overview | plan items, inclusive effective dates, round-specific overlap en unit fail-closed | 4C.4 SQL/concurrency | voeg items toe, test geldige unit, geweigerde unit en overlappende tijdelijke override | aanwezig, functioneel onvolledig: geen item/override-UI |
| A35 | voederuitvoering en correctie | Feeding Execution | immutable executions, actual/remainder/deviation en correction-RPC | 4C.4 SQL/concurrency plus 4C.7 dialogcontract | registreer actual, remainder en deviation; corrigeer zonder historie te overschrijven | aanwezig, functioneel onvolledig: uitvoering bestaat, correctie-UI ontbreekt |

## 3. Backend- en testdekking per domein

| Domein | Belangrijkste tabellen | Belangrijkste RPC's | Primaire suites |
| --- | --- | --- | --- |
| identiteit | `profiles`, `account_workspace_preferences` | profieltrigger en Auth API | `phase_4a_local_auth.rb`, `phase_4a_profiles_rls.sql` |
| stal/team | `stables`, `stable_memberships`, `stable_members`, `stable_invitations` | create/update/archive stable, invitation-, role-, suspend-, remove-, leave- en transfer-RPC's | fase-4B SQL, Ruby integratie en concurrency |
| Horse | `horses`, grants, identifiers, relationships | create/update/archive, grant/revoke, identifier- en relationship-RPC's | fase-4C.2A/2B SQL, upgrade en concurrency |
| planning | series, items, assignments, executions | series/item/assignment/execution-RPC's | fase-4C.3 SQL, upgrade en concurrency |
| voeding | plans, versions, items, occurrences, execution details | create/version/item/approve/activate/record-RPC's | fase-4C.4 SQL, upgrade en concurrency |
| media | assets, variants, links, events | uploadsession, finalize, authorize, link en archive | fase-4C.5 SQL, Ruby integratie en concurrency |
| sync | authorities, devices, changes, conflicts, importjobs | topics, pull, dayset, sync, conflict en legacy-RPC's | fase-4C.6 SQL, upgrade en concurrency |
| FlutterFlow | drie custom runtimes en Alpha-pagina's | bovenstaande RLS/RPC-laag | `flutterflow ai test`, contracttests, generated analyze/build |

## 4. Geprioriteerde afronding

P1 voor een bruikbare Alpha:

1. lokale sample-seeding en lokale/cloud-split-brain verwijderen of isoleren;
2. vijf FlutterFlow nullable-statewaarschuwingen afhandelen;
3. Horse update/archive en expliciete Horse-grants end-to-end ontsluiten;
4. terugkerende series, assignments en datumgedreven Today-flow ontsluiten;
5. Feeding version/item/activation/momentflow afmaken;
6. private media upload/download/archive aan een Horse of execution koppelen;
7. conflictresolver en stateherstel zichtbaar maken;
8. auth-, invitation-, multi-session Realtime- en lifecycle-E2E toevoegen.

P2 voor formele testgereedheid:

1. deterministische Test Basis/Medium/Extreme/Custom-fixtures;
2. responsive- en keyboard/a11y-matrix;
3. reproduceerbare reset-, acceptatie- en regressiecommando's;
4. incident-, rollback-, testaccount- en privacyprocedures;
5. documentatie van de browserofflinebeslissing vóór deployment.

De bestaande automatische laag bestaat bij aanvang uit 22 SQL-bestanden,
10 Ruby-runners en 71 workspace-Darttests. Er zijn nog geen Test Pilot-tests,
`integration_test`-suite, centrale lokale runner, CI-workflow of bewaarde
Alpha-resultaatartifacts. Fase 5C–5E vullen dit repositorymatig aan zonder een
externe feedback-, analytics- of trackingdienst.

## 5. Acceptatiebewijs

Iedere requirement krijgt in fase 5D een bewijsrecord met:

- fixtureprofiel en vaste UUID-scope;
- exact commando of handmatige stappen;
- verwacht resultaat en negatieve tegenproef;
- platform en viewport;
- datum/tijdzone;
- relevante logs zonder secrets of persoonsgegevens;
- resultaat, datum en commit;
- bevinding-ID wanneer niet groen.

Geen item krijgt de status `gereed en bewezen` uitsluitend op basis van een
zichtbare knop of een succesvol positief pad.
