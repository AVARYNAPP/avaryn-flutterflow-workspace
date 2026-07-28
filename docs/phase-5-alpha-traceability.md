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
| A03 | veilig uitloggen | Profile/account-runtime | Auth sign-out plus UUID-scoped secure purge | fase-4C.7 purge-/contracttests plus 5D.3 browserlogout | logout vanuit operationeel scherm; geen vorige data zichtbaar | gereed en bewezen |
| A04 | accountwissel zonder datalek | Auth Gate/account-runtime | auth UUID, accountscopes, secure purge | fase-4B contexttests, 4C.7 audit en 5D.3 groom → Owner B-browserwissel | A → logout → B; geen A-data of selectie zichtbaar | gereed en bewezen |
| A05 | stal/werkomgeving kiezen | Stable Handoff, Picker, selector | `stable_memberships`, `set_selected_stable` | fase-4B SQL-, context- en managementtests | wissel stal A → B → A, inclusief lege scope | aanwezig, onvoldoende getest |
| A06 | stal en klein team beheren | Create Stable, Details, Members, Roles | `stables`, memberships en authority-RPC's | fase-4B RLS/security/concurrency | owner/admin/member/viewer-matrix doorlopen | aanwezig, onvoldoende getest |
| A07 | teamlid uitnodigen/accepteren | Invite, Pending, Invitation | invitation Edge Function en invitation-RPC's | 23 lokale integratieasserties plus concurrency | create, preview, accept, decline, resend en revoke via eenmalige lokale manual-share-link | aanwezig, onvoldoende getest |
| A08 | Horse aanmaken en lezen | Horses Overview/operational runtime | `horses`, `create_horse`, RLS | 4C.2A SQL/concurrency, 5B.2 lokale acceptatie en runtimecompile | maak Horse, ververs en zie hem uitsluitend in juiste stal | aanwezig, onvoldoende getest: formeel browser-E2E ontbreekt |
| A09 | Horse-kerngegevens beheren | Horses Overview/operational runtime | `update_horse_profile`, `archive_horse`, `get_horse_capabilities` | 4C.2A SQL/concurrency, 5B.2 upgrade- en broncontracttests | wijzig kernveld met row-version, bewijs conflict en archiveer met reden | aanwezig, onvoldoende getest: browser-E2E en responsive bewijs ontbreken |
| A10 | Horse-relaties en beperkte toegang | Horses Overview/operational runtime | `horse_relationships`, `horse_access_grants`, grant/revoke- en relationship-RPC's | 4C.2A/2B SQL en 5B.2 herhaalde concurrency/denialtests | geef beperkte basis- of planningtoegang, revoke, beheer losse teamrelatie en test cross-stable denial | aanwezig, onvoldoende getest: multi-user browser-E2E ontbreekt |
| A11 | taak aanmaken | Planning/operational runtime | `schedule_items`, `create_schedule_item` | 4C.3 plus 5D.1 atomische SQL/replay/concurrency | maak een taak met Horse, tijd en categorie | aanwezig, onvoldoende getest: browser-E2E blijft nodig |
| A12 | terugkerende routines | Planning en Today | `schedule_series`, materialisatie-RPC's | 5D.1 drie routines, exacte 13-daagse horizon en races | maak drie series; materialiseer en controleer twee dagen | aanwezig, onvoldoende getest: browser-E2E blijft nodig |
| A13 | taak toewijzen | Planning/Team | `schedule_assignments`, `assign_schedule_item` | 5D.1 atomiciteit, assigned-only cardinaliteit en denial | wijs groom toe; andere gebruiker ziet opdracht niet | aanwezig, onvoldoende getest: multi-user browser-E2E blijft nodig |
| A14 | Today op logische dagen | Today/operational runtime | `list_today_schedule` | 5D.1 datumkeuze, twee lokale dagen en fixturebewijs | vandaag plus tweede lokale staldag/DST-rand | aanwezig, onvoldoende getest: viewport- en DST-browserbewijs blijft nodig |
| A15 | uitvoering registreren | Today/Feeding Execution | record- en sync-execution-RPC's | SQL, 5D.1 idempotentie en concurrency | voltooi toegewezen taak exact eenmaal | aanwezig, onvoldoende getest: formeel browser-E2E blijft nodig |
| A16 | voerplanversionering en activatie | Feeding Overview | feeding plans, versions en lifecycle-RPC's | 4C.4 plus 5D.2 atomische planstart, lifecycle en races | draft, versie, approve, activate en retire met denied-tegenproef | aanwezig, onvoldoende getest: browser-E2E blijft nodig |
| A17 | private operationele media | Horses Overview en afgeronde Today/Planning-executioncontext | private bucket, media-assets/links, media-RPC's en media Edge Function | 4C.5 SQL/Ruby plus 5B.4 capability-, bron-, upgrade- en concurrencytests | upload, finalize, download en archive; revoke en denial voor andere Horse/stal | aanwezig, onvoldoende getest: multi-user browser-E2E en viewportbewijs ontbreken |
| A18 | private Realtime-update | operational runtime | private topics plus `pull_operation_changes` | 4C.6 SQL/concurrency, 5D.3 Realtime-policytests en twee gelijktijdige browsersessies | wijzig in sessie A, veilige refresh in sessie B | gereed en bewezen |
| A19 | offline dagset en pending-sync | operational runtime op ondersteund native/desktop | device/dayset/sync-RPC's | 4C.6 SQL/concurrency en 4C.7 contracttests | prepare, verbreek netwerk, execute, restart, reconnect | aanwezig, onvoldoende getest: native E2E ontbreekt |
| A20 | browseroffline | web-runtime | bewust uitgeschakeld; geen goedgekeurde browserkeystore | webbuild, fail-closed bronasserties en 5D.3 lokale gateway-uitval met purge | netwerk weg: geen plaintext/fallback en duidelijke state | productbeslissing: fail-closed browsergedrag bewezen; beveiligde webopslag vereist nieuw contract |
| A21 | retries en idempotentie | operational runtime | mutation receipts en request-ID-contract | SQL 100-retrytests en pure ledgertests | simuleer ambigue response en retry exact dezelfde payload | aanwezig, onvoldoende getest: transport-E2E ontbreekt |
| A22 | conflicten | operationele conflictindicator en serverversie-resolver | `sync_conflicts`, list/resolve-RPC's | 4C.6 RLS/idempotentietests plus 5B.5 resolvercontract | forceer base-versionconflict; alleen actor ziet hem en kan met reden de serverversie behouden | aanwezig, onvoldoende getest: multi-session browser/native-E2E ontbreekt |
| A23 | revoke/authority-reset | alle drie runtimes | authorityversion, topicrotatie, device revoke en payloadarme wake op oude topics | SQL-races, 5D.3 handshake-/wake-tests en live revoke met purge zonder refresh | revoke tijdens sessie/offline; oude data direct weg bij detectie | gereed en bewezen |
| A24 | loading/empty/error/offline/denied/conflict | account-, stable- en operational runtime | RLS/RPC-foutcodes | bronasserties en compiletests | forceer iedere state en controleer herstelactie | aanwezig, onvoldoende getest |
| A25 | navigatie zonder doodlopers | alle Alpha-routes | auth- en membershipgate | route-/bronasserties plus 5D.3 Today/Paarden/Planning en drie legacy-Horse-deeplinks met back/refresh | doorloop mobiel/tablet/desktop en browser back/refresh/deeplink | aanwezig, onvoldoende getest: overige Alpha-routes blijven handmatig te doorlopen |
| A26 | Paard/Ruiter/Team gescheiden | Horse-, Profile- en Teamroutes | gescheiden profiles, semantische relationships, grants en memberships | schema- en RLS-tests plus expliciete 5B.2 UI-copy | persona-labels en Horse-relaties verlenen geen authority | aanwezig, onvoldoende getest: multi-user E2E controleren |
| A27 | notificaties/reminders | geen actuele operationele Alpha-runtime | geen fase-4 notificationbackend; besluitrecord beperkt scope tot reeds contractueel geïmplementeerd | besluitrecord `AVARYN-P5-2026-07-27` | n.v.t.; voeg geen nieuwe notificationfeature toe | buiten fase 5 op grond van de actuele bindende scope |
| A28 | responsive en basis-a11y | alle Alpha-routes | n.v.t. | webbuild en 5D.3-browserbewijs op 390×844, 820×1180 en 1440×900 met keyboard-login en semantische labels | 390×844, tablet en desktop; keyboard, focus, labels, contrast | aanwezig, onvoldoende getest: resterende Alpha-routes en contrastmatrix ontbreken |
| A29 | één cloudbron zonder lokale split-brain | operationele pagina's plus oude Horse/Activity/Feeding/Nutrition-routes | cloud-RLS/RPC blijft de autoritatieve bron | 5B.1 cloudnavigatie, 5B.2 harde legacy-redirects en 5D.3 browserdeeplinks/back/refresh zonder prototypegegevens | start schoon, navigeer en deeplink alle actieve/legacy routes en bewijs dat geen prototypegegevens verschijnen of clouddata overschrijven | gereed en bewezen |
| A30 | geldige FlutterFlow-stateconfiguratie | AppState en formroutes | n.v.t. | laatste run is groen maar meldt vier bestaande nullable-statewaarschuwingen | cold start, refresh en deeplink zonder null-crash | aanwezig, onvoldoende getest: warnings oplossen of aantoonbaar als veilige nullable state documenteren |
| A31 | lokale uitnodigingsoverdracht | Invite/Invitation | lokale Edge Function; raw token nooit duurzaam opslaan | Ruby-integratiesuite | fictieve invite via eenmalige lokale manual-share-link, zonder echte e-mail | aanwezig, onvoldoende getest: hosted mail/deeplink blijft deploymentvoorwaarde |
| A32 | onboarding voltooien | Onboarding/account-runtime | eigen `profiles`-record en server-side Auth-UUID | fase-4A RLS en runtimecompile | doorloop verplichte profielstappen en cold refresh | aanwezig, onvoldoende getest: formeel E2E ontbreekt |
| A33 | persoonlijk profiel en avatar beheren | Personal Profile/account-runtime | eigen `profiles`, private `avatars` en padcontrole | fase-4A RLS, Storage-integratie en runtimecompile | wijzig profiel, upload/verwijder fictieve avatar, test cross-user denial | aanwezig, onvoldoende getest: formeel UI-E2E ontbreekt |
| A34 | voeritems, units en tijdelijke overrides | Feeding Overview | plan items, inclusive effective dates, round-specific overlap en unit fail-closed | 4C.4 plus 5D.2 exact-slot UI/SQL en twee racepasses | voeg items toe, test geldige unit, geweigerde unit en overlappende tijdelijke override | aanwezig, onvoldoende getest: responsive browser-E2E blijft nodig |
| A35 | voederuitvoering en correctie | Feeding Execution | immutable executions, actual/remainder/deviation en correction-RPC | 5D.2 assigned-only uitvoering, durable replay en append-only correctie | registreer actual, remainder en deviation; corrigeer zonder historie te overschrijven | aanwezig, onvoldoende getest: formeel browser-E2E blijft nodig |

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
3. terugkerende series, assignments en datumgedreven Today-flow ontsluiten;
4. Feeding version/item/activation/momentflow afmaken;
5. private media upload/download/archive aan een Horse of execution koppelen;
6. conflictresolver en stateherstel zichtbaar maken;
7. auth-, invitation-, Horse-, multi-session Realtime- en lifecycle-E2E toevoegen.

P2 voor formele testgereedheid:

1. deterministische Test Basis/Medium/Extreme/Custom-fixtures — afgerond in
   fase 5C;
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

## 6. Fase-5B.1-checkpoint

Op 28 juli 2026 is de account-, onboarding-, stal-, team- en
navigatiebasis afgerond en via FlutterFlow-projectcommit
`IWY1YaAsjF7TcE2tzLLn` geëxporteerd. Het reproduceerbare bewijs staat in
`docs/phase-5b1-account-team-navigation.md`.

Daarmee zijn voor A01–A07, A23–A26 en A30–A33 de broncontracten, lokale
Auth/RLS/Edge-integratie, fail-closed lifecycle, FlutterFlow-compilatie en
navigatiestructuur aangescherpt en automatisch bewezen. De requirements
blijven voor de formele fase-5D-status `aanwezig, onvoldoende getest` zolang
de bijbehorende browser-, viewport- en handmatige Alpha-E2E-records nog niet
zijn uitgevoerd; de technische 5B.1-subfase zelf is groen.

De invitation-integratiesuite bevat nu 27 controles en de workspace bevat 89
groene Darttests. De gegenereerde webapp bouwt lokaal met de projectgebonden
Flutter 3.35.7-toolchain. Er is niets gepubliceerd of gedeployed.

## 7. Fase-5B.2-checkpoint

Op 28 juli 2026 is de cloud-backed Horse Alpha-flow lokaal afgerond. De
operationele runtime ontsluit nu creatie, kerngegevens met optimistische
concurrency, archivering met reden, beperkte basis-/planningtoegang en
afzonderlijke niet-autoriserende paard-teamrelaties.

De capability-RPC is uitsluitend read-only en retourneert alleen de effectieve
rechten van de ingelogde actor voor een Horse die die actor al mag zien. RLS en
de bestaande mutatie-RPC's blijven de enige authority. De lokale lege reset,
upgrade-met-databehoud, denialmatrix en concurrencyruns staan beschreven in
`docs/phase-5b2-horse-management-access.md`.

A08–A10 en het technische deel van A26 zijn daarmee niet langer functioneel
onvolledig. Zij blijven voor de formele fase-5D-status `aanwezig, onvoldoende
getest` totdat de gegenereerde export-, responsive en multi-user browser-E2E
zijn bewezen. Er is niets gepubliceerd of gedeployed.

## 8. Fase-5B.4-checkpoint

De private-mediaketen uit 4C.5 is in de operationele Alpha-runtime aangesloten
op zowel de Horse- als de exacte schedule-executioncontext. Upload en finalize
gebruiken duurzame idempotente request-ID's, terwijl signed materiaal,
objectpaden en mediabytes uitsluitend tijdelijk in geheugen bestaan.

De aanvullende capabilityvelden zijn alleen UI-guidance. De bestaande
media-RLS, Storage-policy's, mutatie-RPC's en Edge Function blijven de
authority. De reproduceerbare reset-, upgrade-, denial-, Storage- en
concurrencygate staat in
`docs/phase-5b4-private-operational-media.md`.

A17 is daarmee niet langer functioneel onvolledig. De formele status blijft
`aanwezig, onvoldoende getest` totdat de multi-user browser-, viewport- en
handmatige Alpha-E2E in fase 5D zijn bewezen. Er is niets gepubliceerd of
gedeployed.

## 9. Fase-5B.5-checkpoint

Het bestaande 4C.6-contract voor private Realtime, versleutelde native
offline-dagsets, pending-sync en authorityrotatie blijft ongewijzigd. De
operationele runtime maakt de eigen open, niet-kritieke
Horse-profielconflicten nu zichtbaar en kan die expliciet afsluiten met behoud
van de actuele serverversie en een verplichte reden.

De UI biedt geen client-wins of automatische merge: de serverrij blijft de
autoritatieve toestand. De resolutie gebruikt een duurzaam idempotent
requestrecord en de bestaande actor-/owner-/admin-RPC-authority; de lijst blijft
beperkt tot de eigen Auth-UUID.

A22 is daarmee niet langer functioneel onvolledig. A18–A23 blijven voor de
formele fase-5D-status `aanwezig, onvoldoende getest` totdat multi-session,
native-offline, revoke-, responsive en browserbewijs als afzonderlijke
acceptatierecords zijn uitgevoerd. Er is niets gepubliceerd of gedeployed.

## 10. Fase-5C-checkpoint

De vier formele, uitsluitend lokale testprofielen zijn reproduceerbaar
geconsolideerd in `supabase/fixtures/phase_5c_test_profile.sql`. Basis,
Medium en Extreme gebruiken respectievelijk 3, 8 en 15 paarden; Custom heeft
begrensde, expliciete testparameters. Deze aantallen zijn testvolumes en geen
commerciële productlimieten.

Ieder profiel bevat fictieve ruiters, grooms, trainer, gescheiden stallen,
een semantische eigenaar met één-paardtoegang, ingetrokken toegang, outsider,
terugkerende routines, twee Today-datums, uitvoering, voeding, pending media,
een native sync-devicecontract en open profielconflicten. Horse-relaties en
technische grants blijven afzonderlijk.

De centrale lokale runner heeft alle vier profielen vanaf een lege reset
geprovisioned en met echte RLS gecontroleerd. Een aanvullende Custom-run met
4 paarden, 7 routines, 19 items, 3 mediasessies en 2 conflicten bewijst dat
de parametrisering niet afhankelijk is van gelijke volumes. De workspace
staat op 112/112 groene tests. De resetguard vereist expliciete bevestiging,
de exacte project-ID, een lokale Unix-Dockercontext en het exacte
Supabase-projectlabel. Er is geen automatische seed, externe databaseactie,
FlutterFlow-projectwijziging, publicatie of deployment uitgevoerd.

## 11. Fase-5D.1-checkpoint

Planning en Today bieden nu lokale-dagnavigatie, dagelijkse en wekelijkse
routines, eenmalige taken en optionele verantwoordelijke toewijzing. Plan plus
assignment en serie plus materialisatie gebruiken atomische wrappers en
duurzame exact-payloadreplay.

Het lokale Basis-profiel bewijst drie routines, twee logische dagen, een
exacte inclusieve horizon van dertien dagen, assigned-only cardinaliteit,
revoked denial en herhaalde 4C.3-races. De generated-code-analyse en
Flutter-webreleasebuild zijn groen met de projectcompatibele Flutter 3.35.7
SDK. Details staan in `docs/phase-5d1-planning-acceptance.md`.

A11–A15 zijn niet langer functioneel onvolledig. Het resterende formele bewijs
is browser-, viewport-, DST- en multi-user-E2E. Er is niets gepubliceerd of
gedeployed.

## 12. Fase-5D.2-checkpoint

De voedingsruntime ontsluit nu dezelfde bestaande 4C.4-bron voor atomische
planstart, versionering, items, duurzame `override_key`, tijdelijke
exact-slotvervanging, verantwoordelijke assignment, goedkeuring, activatie en
retirement. Feitelijke uitvoering gebruikt duurzame exact-payloadreplay; een
correctie is een nieuwe uitvoering die naar de immutable oorspronkelijke
registratie verwijst.

De lokale gate bewijst een verse migratieketen, Basis-fixture, atomische
plan-/versiereplay, twee lokale override-dagen, assigned-only uitvoering,
append-only correctie, idempotente correctiereplay, cross-stable en revoked
denial en twee volledige 4C.4-racepasses. Details staan in
`docs/phase-5d2-feeding-acceptance.md`.

A16, A34 en A35 zijn niet langer functioneel onvolledig. Responsive en
multi-user browser-E2E blijven formele 5D-gates. Er is niets gepubliceerd of
gedeployed.

## 13. Fase-5D.3-checkpoint

FlutterFlow-projectcommit `273uNhvKI33OfF2VFdRi` bevat de clientzijde van de
private Realtime- en lifecycleherstelgrens. De lokale servermigratie verleent
de handshakefunctie alleen aan `authenticated`, houdt de topiccontrole
fail-closed en verstuurt vóór authorityrotatie een payloadarme wake naar de
oude privé-topics. Naast de authorityversie bevat die uitsluitend de door
Realtime verplichte willekeurige technische bericht-ID.

Twee gelijktijdige, door origin geïsoleerde browsersessies bewezen een
assigned-only update zonder refresh, gevolgd door suspension en onmiddellijke
purge van eerder zichtbare data zonder refresh. Logout en accountwissel naar
een tweede owner lekten geen stal- of taakdata. De drie oude Horse-deeplinks,
browser-back en refresh bleven bij de cloudruntime. Een gecontroleerde lokale
gateway-uitval purgeerde zichtbare data en viel terug op een veilige
fout/empty-state zonder plaintext browsercache.

De lege lokale reset, volledige 4C.6 SQL- en concurrencyregressie,
5D.3-handshake-/cross-stable-/revoked-/old-topic-waketests en alle 134
workspace-Darttests zijn groen. Details en reproduceerbare commando's staan in
`docs/phase-5d3-browser-multisession-acceptance.md`. A03, A04, A18, A23 en A29
zijn daarmee `gereed en bewezen`; A20 blijft bewust een productbeslissing voor
beveiligde browserofflineopslag. Er is niets gepubliceerd of gedeployed.
