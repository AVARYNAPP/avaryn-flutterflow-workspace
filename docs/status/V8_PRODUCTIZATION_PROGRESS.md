# AVARYN V8 — actuele productisering

## Actueel — kandidaat07, 12 september 2026

De opvolger C010-V8-PRODUCTIZATION-20260912-07 (0.10.8/build7) is lokaal gebouwd: webentry app-JXBJQ2KX.js, 33 clientbestanden/35 publicatiebestanden. Kandidaat06 is alleen lokaal getest en op de emulator geïnstalleerd;07 voegt uitschakeling van gevoelige Capacitor-debuglogging toe. Online staat tot de gecontroleerde publicatie nog05, checkpoint b812d4831f1366aaa3b5654b8dff39e56b9129d5. Officiële ontwikkelbranch: implementation/c010-stable-team-collaboration. Pilot: https://avaryn-c010-pilot.silasdesteur.chatgpt.site/ met uitsluitend backend rvymglpkttlfwhqpmupp. Definitieve online binding volgt in het opleverreceipt.

De gebruiker heeft persoonlijk wachtwoordherstel én gewone nieuwe telefoonlogin bevestigd. Zelfregistratie is vrij voor iedereen met de pilotlink; vijf vaste e-mailadressen zijn niet nodig. Geen ongevraagde uitnodigingsmail verstuurd.

| Onderdeel | Actuele bewijsstatus | Resterend |
| --- | --- | --- |
| Onafhankelijkheid Mac/tunnel | PASS: eigen devserver56860 uit; nieuwe registratie, ontvangen/bevestigde mail, profiel/paard/stal, tweede login en private media werkten via vaste Worker/Supabase. Ook na macOS-herstart opnieuw ingelogd. | Geen lokale infrastructuur nodig voor de webpilot. |
| Nieuwe synthetische manager en groom | PASS: onboarding, paard, stal, uitnodiging/acceptatie; groom voltooit gedeelde taak, manager leest resultaat terug. Taken zonder datum/met datum/met21:00 en instructies opgeslagen; onafhankelijke groomreadbacks. | Intrekking PASS: stalcontext verdwijnt, eigen gegevens behouden. Finale updatecontrole nog uitvoeren. |
| Planning/voeding/faciliteiten | PASS online05: training19:30–20:00, Basisvoeding plus tijdelijk schema13–14 september met instructies; volledige herlaadactie bewaart beide. Nieuwe voorzieningen en exclusieve rijbakaanvraag→goedkeuring; groom ziet gedeelde bezetting zonder beheerknoppen. | PASS: verblijfplaats/box met instructie, wasplaatsmoment20:10–20:25; tweede managersessie leest warming-upstap2/focus/privéterugblik. |
| Sessies en fouten | Gerichte herstelschermfix met144 functionele checks PASS;21 contrastchecks herhaald.78 Workerchecks PASS, uitsluitend veilige504-classificatie. Eerdere401 en twee504 niet gereproduceerd; oorzaak niet bewezen hersteld. | Natuurlijke tokenproef gecorrigeerd voor gedocumenteerde30s PostgREST-speling; loopt naast ander werk. |
| Backup/herstel | PASS: volledige49-migration Pilotdump daadwerkelijk in nieuwe geïsoleerde lokale database hersteld;125 tabelhashes/owners/RLS/ACL gelijk. Twee private PNG-objecten op checksum/omvang gecontroleerd, ook na reboot. | Geen uploadrestore naar tweede Storage-service of volledige hosted configuratie-export bewezen. |
| Android | PASS: ondertekende05 installatie/login/taakafronding/herstart;06 en07 update met dezelfde afzonderlijke testkey behouden sessie en gedeelde data.07 logproef bevat geen bridgecredentials. | Native media/callback afronden; fysieke telefoon/store-release niet getest. |
| iOS | macOS26.6.2 en Xcode26.6/17F113 bevestigd;07 assets/plugins gesynchroniseerd, simulatorcompilatie loopt. | iOS26.5 Simulatorruntime door gebruiker installeren; feitelijke installatie/flows daarna. |
| Bron, overdracht en publicatie | GitHub-pushrecht op juiste repository bevestigd.20 bedoelde bestanden geselecteerd voor review; alle uitgaande Gitobjecten en huidige bron gescand, geen ongeclassificeerde secretmatch.44 pakket/metadatachecks PASS. | Exacte staging, lokaal checkpoint, gewone ontwikkelpush en bestaande Sites-publicatie volgen. |

Bewijs staat afgeschermd onder .avaryn-local/productization-20260911/evidence: final-user-flows/resume-*, operational49-backupreceipts, backup-post-reboot-integrity.json, candidate07-independent-source-review.json, candidate07-full-outgoing-content-scan.json en de platformreceipts. Historische testtellingen worden niet opgeteld als één nieuwe integrale suite.

Alleen noodzakelijke correcties en synthetische mutaties in Pilot; persoonlijke account behouden. Geen main-merge/force-push, database-migration, oude Staging, Alpha/DNS-omzetting, productie, C-011 of nieuwe kosten. Dit is technische voortgang, geen menselijke eindacceptatie.

## Historische voortgang en bewijs

Dit is een werkstatus, geen eindacceptatie of publicatieverklaring.

Officiële client: `apps/avaryn/src`. Lokale kandidaat `C010-V8-PRODUCTIZATION-20260912-05`, versie0.10.8/build5, entry `app-22PYSOSG.js`, nog niet gepubliceerd. Kandidaat04 is vastgelegd in checkpoint `2abb2c45c229959afe20e60a2f4c4eae4a9cdd15` en gepubliceerd via Sites-commit `c446f7a261d857450bdbfd87fed98745192818dd`, deployment `appgdep_6aa540d52e748191b7ecf556b40ea39c` succeeded. Bewijs: `candidate04-checkpoint.json`, `candidate04-online-publication.json` en `candidate04-web-checkpoint-binding.json`.
Gecontroleerde ontwikkelbranch: `implementation/c010-stable-team-collaboration`;
historische HEAD `5fc70f09d5122da1def3d44cbcfc3a3098086f60`.
Vorig technisch broncheckpoint: `e1ba6965f459525061d45ae3984c2a0b877918c0`, lokaal vastgelegd.
De push naar precies deze ontwikkelbranch kreeg GitHub403: de bestaande lokale Git-koppeling
gebruikte een ander account zonder schrijfrecht. Geen accountwisseling of herhaalde push uitgevoerd.

De geaccepteerde warme V8 blijft de visuele basis. Webassets worden lokaal gebundeld voor Capacitor;
de native projecten verwijzen niet naar een tijdelijke ontwikkelwebsite.

## Omgevingen

| Omgeving | Identiteit | Actuele toestand |
| --- | --- | --- |
| Eigen development | `avaryn-c010-vitality-20260911-a`, API56801, DB56802, uitsluitend loopback | 49 migrations; synthetische rolproeven |
| Nieuwe permanente pilotbackend | `rvymglpkttlfwhqpmupp`, organisatie AVARYN | 49 migrations; volledige backup werkelijk apart hersteld; bestaande gegevens en rechten behouden |
| Nieuwe pilothosting | `appgprj_6aa45546e34481918b42c6609c243630` | Kandidaat04 gepubliceerd en werkelijk geladen; kandidaat05 lokaal gereed, nog niet gepubliceerd. Audience revision2 na expliciete toestemming openbaar/via link; Auth/RLS onveranderd. https://avaryn-c010-pilot.silasdesteur.chatgpt.site |
| Bestaande besloten preview | `avaryn-c010-preview.silasdesteur.chatgpt.site` | Behouden; dit is niet de nieuwe permanente pilot |
| Gewenste pilotalias | `alpha.avaryn.eu` | Nog niet omgezet; eerst hosting/Auth/opslag en herstel aantonen |

## Bewezen voortgang

- Geïntegreerde account-, stal-, team-, paarden-, media-, planning-, voeding-, faciliteiten- en Vitalitycontracten hebben gerichte lokale tests; bewijzen staan onder `.avaryn-local/productization-20260911/evidence`.
- Twee afzonderlijke browsersessies: stalmanager nodigt groom uit; groom accepteert; manager ziet acceptatie na herladen. Stalrol geeft geen automatische toegang tot een afzonderlijk paard.
- Manager maakt een taak zonder datum met instructie en groomtoewijzing. Groom ziet de instructie en rondt de taak af; serverreadback bevestigt de afronding.
- Eigenaar maakt paard Linde en stal Lindehof aan, legt verblijfplaats vast, configureert boxen/weide/paddock/rijbak/wasplaats en koppelt box met bewaarde instructie.
- Basisvoeding: twee producten in één dagdeel, Nederlandse decimale komma, eenheden en volledige instructies opgeslagen en opnieuw opgehaald.
- Tijdzone004: 105 nieuwe plus215 bestaande SQL-controles geslaagd. Pilotapply verandert uitsluitend de migrationhistory; alle124 overige tabelinhouden en effectieve rechten behouden.
- SMTP: aparte sleutel met Sending access voor uitsluitend `auth.avaryn.eu`; Supabase-pilot verstuurt via `no-reply@auth.avaryn.eu`. TLS en SMTP-authenticatie235 geslaagd. Deze eerdere probe bewees alleen de verbinding; latere bezorging/bevestiging staat hieronder.
- Pilot-Auth Site URL en precies twee HTTPS-callbacks ingesteld. Nederlandse registratie-/herstelsjablonen bieden een link naar de app en een eenmalige code. Voorafgaande configuratie bewaard.
- Permanente Worker:56 gerichte tests; packagingadapter:14 tests. Alleen de vaste pilotbackend, expliciete RPC/Edge/media-routes, gebruikersbearers en exacte web/native origins. Runtimekey blijft buiten de publieke client.
- Gecorrigeerd: authschermreset bij uitloggen; peraccount stalkeuze met hernieuwde toegangscontrole; canonieke stalnaam op taakkaarten; paardlocatie/betrokkenen uitsluitend uit paardkoppelingen; accountverwijderingsreceiptcorrelatie.
- Paardenarchief005:48 SQL-asserties en2 echte acceptatie/verwijderingsraces geslaagd;39 clientchecks. Dev en Pilot afzonderlijk toegepast na echte restores. Alleen hun ledger veranderde;135 respectievelijk124 overige tabelinhouden en bestaande effectieve rechten behouden. De eerste devpoging stopte vóór DDL op een te sterke ledgerlock; rollback volledig gecontroleerd en guard zonder extra grants gecorrigeerd. De lifecycleproef vergelijkt nu de bestaande serviceprivileges van de eigen omgeving; anon-/gebruikersgrenzen blijven ongewijzigd.
- Native merkassets:30 PNG's uit het bestaande AVARYN-mark.svg; iOSicon1024² zonder transparantie, Androidvarianten en startbeelden visueel gecontroleerd. Geen toestel-/simulatorclaim. Build en Capacitor-sync slagen.
- Dependencycontrole: gerichte `xcode > uuid`-correctie naar11.1.1; echte projectparse en scratchroundtrip geslaagd. Actuele npm-audit:0 bekende kwetsbaarheden.
- Pilot publieke Auth-instellingen alleen-lezen gecontroleerd: e-mail en zelfregistratie aan, bevestiging verplicht; Apple/Google/telefoon/anonieme registratie uit. Wachtwoordbeleid vraagt nog aparte controle; bezorging is later afzonderlijk bewezen.
- Productsuite kandidaat02:926 tests,924 geslaagd,0 fouten,2 expliciete liveproeven overgeslagen. Release-entry `app-A6YYXOA7.js`;33 publieke manifestbestanden, geen actieve demo-inputs. Zie [testresultaten](../../apps/avaryn/TEST_RESULTS.md).
- Lokale server herstart met een afgeschermde config die de acht werkelijke developmentcontainers controleert. Alle geserveerde bestandshashes en kandidaat/backendidentiteit gelijk aan de build; nieuwe archieflees-RPC weigert anoniem met401. Dit is HTTPbewijs, geen nieuwe browseracceptatie.
- Native fotoactie gebruikt de bestaande expliciete opslagflow.72 gerichte checks plus5 controllerchecks groen, onderdeel van de gezamenlijke suite. Cameratoegang, galerijkeuze en toestemming op een echt toestel zijn nog niet getest.
- Zelfstandige developmentmodus zonder FlutterFlow-binding:35 Pythonchecks en56 Nodechecks; bestaande devconfig daadwerkelijk tegen de eigen containers gevalideerd. Het voorbeeld van een volledig nieuwe backend is nog niet gestart.
- Overdrachtsproef vanaf broncheckpoint `e1ba6965f459`:400 exacte bronbestanden in een schone map op dezelfde Mac, verse `npm ci`, webbuild en beide Capacitor-syncs geslaagd. Alle34 bestanden inclusief het buildmanifest zijn bytegelijk. In die schone map opnieuw884 productsuitetests geslaagd,2 liveproeven overgeslagen;35 productrunnerchecks en5 huidige backendmanifestguards geslaagd. Geen FlutterFlow-state, oude node_modules of ontbrekende imports nodig.
- Historisch kandidaat01-webpakket:33 clientbestanden plus Worker en hostingmetadata; ZIP bevat daarnaast een herleidbaar releasereceipt. Artifact-SHA256 `325667557b975e3cc89a7bae7add3194b2b26cf7a0ded3dceb65f4f34ac58a4d`. Destijds nog niet gepubliceerd; geen secrets of Edgecode in dit publicatiepakket.

- Gevonden en hersteld: na middernacht werd alleen de kop vernieuwd. De nieuwe cliënt ververst de actuele serverprojecties eenmaal, bewaart open concepten en historische dagkeuzes en weigert late accountresponses.117 gerichte checks en onafhankelijke review PASS; onderdeel van bovenstaande suite. Geen databasewijziging.
- Native versievelden volgen nu release.json: Android en beide iOS-configuraties0.10.8/build2.21 gerichte checks PASS; identifiers/signing behouden. Webbuild en beide Capacitor-syncs opnieuw geslaagd, geen native compileclaim.
- Werkelijke lokale gebruikersproeven: tijdelijk schema teruggelezen, training met twee betrokkenen, warming-up hervat na herstart en privéreflectie opgeslagen; manager ziet groomafronding, morgen12:00-taak zichtbaar in onafhankelijke groomsessie; weidemoment, gedeelde rijbakreservering en exclusieve aanvraag→goedkeuring met aansluitend slot en behouden eerdere reservering. Groom ziet alleen toegestane bezetting. Mobiel320/390 light/dark en terugnavigatie gecontroleerd; geen horizontale overflow of consolewaarschuwingen/fouten in deze sessie. Bewijs geldt voor de geteste webbrowser, niet voor fysieke toestellen.

## Kandidaat03 — gepubliceerd bewijs

- Gmail-navigatie naar de callback werd vóór de shellrouter geweigerd. De Worker staat nu alleen GET-documentnavigatie naar bestaande shellpaden toe, zonder API-/bearergrenzen te verruimen of tokens naar ASSETS te sturen. **65 Workerchecks PASS**; **35 packaging/native-versiechecks PASS** (`candidate03-worker-navigation.json` en `candidate03-package-version-tests.log`). De onderliggende kandidaat02-suite **924 PASS/2 SKIP** is hergebruikt; geen nieuwe volledige suiteclaim.
- Nieuwe lokale browserreadbacks: paardenfoto geladen na herladen (`complete:true`,640×427); reflectie Rustig/Energiek met eigen focus en Privé houden bewaard; nieuw wegwerpaccount via de app verwijderd en opnieuw inloggen geweigerd. Geen persoonlijke accountverwijdering. Exact bewijs: `final-user-flows/horse-photo-after-reload.txt`, `horse-photo-render-after-reload.json`, `reflection-after-reload.txt`, `local-disposable-deletion-after.txt` en `local-disposable-login-refused.txt`. Dit is geen managed media-/lifecycleproef.
- Echte registratiemail om12 september00:43 in Gmail bezorgd; bevestigde accountstatus op Pilot teruggelezen. Herstelmail om01:03 bezorgd, onderwerp “Herstel je AVARYN-wachtwoord”; echte reset nog niet uitgevoerd. De bevestigde accountstatus en het openen van de callbackpagina zijn afzonderlijke stappen.
- De eerdere403 van de geautomatiseerde nativeconnectiviteitsprobe blijkt **Cloudflare1010-probeweigering**, geen bewezen defect van de native app. De expliciet toegestane audience revision2 wijzigt uitsluitend Sites-toegang, geen Auth/RLS. Werkelijke native verbinding blijft te testen; kandidaat03-publicatie is hierboven vastgelegd en alleen de afzonderlijk bewezen online flows gelden als PASS.

## Kandidaat04 — drie gerichte fixes, gepubliceerd

- `<base href="/">` voorkomt dat koude `/auth/*`-routes scripts en styles onder `/auth/` zoeken; de lokale Capacitor-bundel houdt zijn eigen origin. De finale webbuild gebruikt `/api` en entry `app-5FOLTYRW.js`:33 clientbestanden,35 pakketbestanden in het nieuwe `private/pilot-artifact-candidate04-auth-final`. **44 gerichte checks PASS/0 SKIP** (9 callback/assets,14 packaging,21 native-versies). Bewijs: `candidate04-auth-final-web-staging.json` en `candidate04-auth-final-package-version-tests.log`; beide eerdere04-pakketten blijven bewaard.
- Na bevestigde e-mail gevolgd door een accountread401 biedt de controller login/herstel in plaats van het verbruikte codeformulier. Daarnaast wordt na geslaagde authenticatie én accountload de authmodus naar login teruggezet, zodat na accountverwijdering geen oud OTP-formulier verschijnt. De finale gezamenlijke auth-/lifecyclecontroles geven **79 PASS/1 optionele live SKIP**, bewijs `auth-completed-mode-reset-fix.json`; dit vervangt de eerdere40-checkdeelrun. Actor-/sessiegrenzen blijven intact; de oorzaak van de eerste upstream401 is niet vastgesteld. Geen nieuwe volledige productsuite: kandidaat02 **924 PASS/2 SKIP** blijft afzonderlijk baselinebewijs.
- De eerdere lokale04-servercontrole bewees deze entry:33 bestandshashes,5 shellroutes en41 HTTP-aanvragen gecontroleerd. Metadata staat op `/runtime.json`; `/api/runtime` blijft404. Root opende beide koude callbackroutes zonder token in de echte browser: duidelijke ongeldige-link/loginweergave, rootassets en geen consolemeldingen. Bewijs `candidate04-auth-final-local-http.json` en `final-user-flows/candidate04-local-cold-callback.txt`. Dit lokale bewijs alleen bewijst geen persoonlijke reset via een geldige mailtoken; online04 is hierboven afzonderlijk vastgelegd.
- **Managed kandidaat03:** Vandaag, Paarden, Stal, Team, Taken, Planning en Voeding daadwerkelijk gebruikt; synthetische login/profielopslag en eigen PNG-foto na herladen PASS (privéblob640×427). Wegwerpaccount D via de app verwijderd, Auth-afwezigheid apart teruggelezen en herlogin geweigerd; media-account M en persoonlijk account behouden, M kon opnieuw inloggen. De specifieke geanonimiseerde profiel-/jobcorrelatie is niet onafhankelijk toegeschreven. Bewijs `final-user-flows/managed-final-online-smoke.json`, `managed-synthetic-photo-reload.json`, `managed-disposable-deleted-ui.txt` en `managed-disposable-login-refused.txt`. Het oude OTP-scherm na verwijdering was de concrete03-presentatiefout die04 herstelt; geen native-/JPEG-/WebP- of volledige lifecycleacceptatieclaim.

- **Werkelijk online04:** nieuwe synthetische registratie, mailbezorging, koude bevestigingslink met opgeschoond adres en verificatie200 openen uitsluitend het eigen lege profiel. De gebruikte bevestigingslink geeft403 zonder privétoegang; de onjuiste rechtenmelding wordt in05 gecorrigeerd. Ook de herstelmail is bezorgd: koude herstelroute → Verder → nieuw wachtwoord opslaan → Vandaag PASS. Na uitloggen wordt het oude wachtwoord met400 geweigerd en werkt het nieuwe. Bewijs onder `final-user-flows/`: `candidate04-confirmed-own-context.txt`, `candidate04-confirmation-replay-refused.txt`, `candidate04-recovery-completed.txt` en `candidate04-old-password-refused.txt`. Herstel-tokenreplay wordt op05 afzonderlijk getest; geen persoonlijke reset of natuurlijk verlopen-tokenclaim.
- **Incidentele401 blijft onverklaard:** op03 trad na verificatie een paardenlijst401 op; op04 gaf de profiel-RPC401 na refresh200 en Auth-user200, terwijl de drie andere initiële reads200 gaven. Verse login/herladen werkte.12 directe RPC-reads en3 synthetische client-/Worker-raceproeven reproduceerden de fout niet; de relevante SQL-bron en rechten kwamen overeen. Dit is geen bewijs van normale sessievervalwerking of een herstelde oorzaak. Zie `profile-read-401-analysis.md`, `session-rpc-race-review.json` en het begrensde privéreceipt `synthetic-profile-refresh-diagnostics-20260912.json`.

## Kandidaat05 — tokenfoutmelding, lokaal gereed

Alleen `/auth/v1/verify` met HTTP403 en de werkelijk vastgestelde providercode `otp_expired` krijgt: “Deze code of link is ongeldig, verlopen of al gebruikt. Vraag een nieuwe e-mail aan.” Database42501, zakelijke weigeringen, andereAuthendpoints en serverfouten behouden hun bestaande afhandeling. RED:2 verwachte fouten; daarna **103 PASS/1 optionele live SKIP** (`candidate05-auth-token-copy.json`). Ongeldige verificatie bewaart geen sessie en wordt niet automatisch herhaald. De dummyproviderproef bewijst de foutvorm, geen natuurlijk verlopen token of echte herstel-tokenreplay.

Webbuild `/api`: `app-22PYSOSG.js`, versie0.10.8/build5,33 clientbestanden en35 gehashte pakketbestanden in het nieuwe `private/pilot-artifact-candidate05`. **44 gerichte checks PASS/0 SKIP** (9 koude assets,14 packaging,21 native-versies);109 broninputs tijdens build ongewijzigd. Bewijs `candidate05-web-staging.json` en `candidate05-package-version-tests.log`. Geen nieuwe volledige suite, native05-compilatie, Gitcheckpoint of publicatieclaim. Kandidaat02 **924 PASS/2 SKIP** blijft historisch baselinebewijs; eerdere04-pakketten blijven behouden.

## Historische afhankelijkheden

De eerdere open-actielijst is vervangen door de actuele backlog bovenaan. Eerdere bewijssecties blijven hieronder behouden.

## Android kandidaat03 — historisch compilebewijs

**PASS:** versie0.10.8/build3, debug-APK en release-APK/AAB werkelijk opnieuw gebouwd, alle unsigned.188 officiële bronbestanden en33 ingesloten webbestanden per artifact exact gecontroleerd; officiële weboutput onveranderd. De eerder vanuit f19 plus zeven beoordeelde wijzigingen gebouwde kandidaat03-artifacts zijn inmiddels exact aan checkpoint `13a599996ca60abcb45dabec08f9aef5d3a08940` gebonden (`android-candidate03-checkpoint-binding.json`); dit is geen kandidaat04-compilebewijs. Bewijs: `.avaryn-local/productization-20260911/evidence/android-candidate03-compile.json`. Systeemimagelicentie, echte installatie/login, iOS en distributiesigning blijven open.

## Android kandidaat04 — finale authbron gecompileerd

**PASS:** de herziene04-bron met authmodusreset is afzonderlijk gecompileerd als unsigned debug-APK, release-APK en AAB, versie0.10.8/build4.188 bronbestanden gekoppeld aan de gecontroleerde snapshot; native entry `app-H5NJGZLZ.js`, HTTPS-pilot-API. Bewijs `android-candidate04-final-compile.json` en bijbehorend verslag; eerdere03-/04-artifacts behouden. Dit bewijst compilatie, geen installatie, native login/camera, signing of storedistributie. iOS en de persoonlijke systeemimagelicentiestap blijven open.
