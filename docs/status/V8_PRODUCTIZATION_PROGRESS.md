# V8 productisering — voortgang, 12 september 2026

Dit is een werkstatus, geen eindacceptatie of publicatieverklaring.

Officiële client: `apps/avaryn/src`. Lokale kandidaat `C010-V8-PRODUCTIZATION-20260912-04`, versie0.10.8/build4, entry `app-5FOLTYRW.js`, nog niet gepubliceerd. Online staat kandidaat03: officieel checkpoint `13a599996ca60abcb45dabec08f9aef5d3a08940`, Sites-commit `b8352c6b25a009d00df5c5012b5f8a5cf270c2aa`, deployment `appgdep_6aa509a6a8548191951789693157bae2` succeeded. `candidate03-checkpoint.json` en `candidate03-online-publication.json` bewaren de exacte binding.
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
| Nieuwe pilothosting | `appgprj_6aa45546e34481918b42c6609c243630` | Kandidaat03 gepubliceerd en werkelijk geladen; kandidaat04 lokaal gereed, nog niet gepubliceerd. Audience revision2 na expliciete toestemming openbaar/via link; Auth/RLS onveranderd. https://avaryn-c010-pilot.silasdesteur.chatgpt.site |
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

## Kandidaat04 — drie gerichte fixes, nog niet gepubliceerd

- `<base href="/">` voorkomt dat koude `/auth/*`-routes scripts en styles onder `/auth/` zoeken; de lokale Capacitor-bundel houdt zijn eigen origin. De finale webbuild gebruikt `/api` en entry `app-5FOLTYRW.js`:33 clientbestanden,35 pakketbestanden in het nieuwe `private/pilot-artifact-candidate04-auth-final`. **44 gerichte checks PASS/0 SKIP** (9 callback/assets,14 packaging,21 native-versies). Bewijs: `candidate04-auth-final-web-staging.json` en `candidate04-auth-final-package-version-tests.log`; beide eerdere04-pakketten blijven bewaard.
- Na bevestigde e-mail gevolgd door een accountread401 biedt de controller login/herstel in plaats van het verbruikte codeformulier. Daarnaast wordt na geslaagde authenticatie én accountload de authmodus naar login teruggezet, zodat na accountverwijdering geen oud OTP-formulier verschijnt. De finale gezamenlijke auth-/lifecyclecontroles geven **79 PASS/1 optionele live SKIP**, bewijs `auth-completed-mode-reset-fix.json`; dit vervangt de eerdere40-checkdeelrun. Actor-/sessiegrenzen blijven intact; de oorzaak van de eerste upstream401 is niet vastgesteld. Geen nieuwe volledige productsuite: kandidaat02 **924 PASS/2 SKIP** blijft afzonderlijk baselinebewijs.
- Lokale server56860 serveert exact deze04-entry:33 bestandshashes,5 shellroutes en41 HTTP-aanvragen gecontroleerd. Metadata staat op `/runtime.json`; `/api/runtime` blijft404. Root opende beide koude callbackroutes zonder token in de echte browser: duidelijke ongeldige-link/loginweergave, rootassets en geen consolemeldingen. Bewijs `candidate04-auth-final-local-http.json` en `final-user-flows/candidate04-local-cold-callback.txt`. Dit bewijst nog geen persoonlijke reset via een geldige mailtoken of online04-publicatie.
- **Managed kandidaat03:** Vandaag, Paarden, Stal, Team, Taken, Planning en Voeding daadwerkelijk gebruikt; synthetische login/profielopslag en eigen PNG-foto na herladen PASS (privéblob640×427). Wegwerpaccount D via de app verwijderd, Auth-afwezigheid apart teruggelezen en herlogin geweigerd; media-account M en persoonlijk account behouden, M kon opnieuw inloggen. De specifieke geanonimiseerde profiel-/jobcorrelatie is niet onafhankelijk toegeschreven. Bewijs `final-user-flows/managed-final-online-smoke.json`, `managed-synthetic-photo-reload.json`, `managed-disposable-deleted-ui.txt` en `managed-disposable-login-refused.txt`. Het oude OTP-scherm na verwijdering was de concrete03-presentatiefout die04 herstelt; geen native-/JPEG-/WebP- of volledige lifecycleacceptatieclaim.

## Open werk en persoonlijke afhankelijkheden

- De beide Pilot-Edgefuncties zijn gedeployed; de drie online bronbestanden zijn exact tegen de geteste checksums gelezen. Na afzonderlijk akkoord staan de legacy JWT-filters uit; verplichte interne Auth- en databaseautorisatie blijven behouden. Media:3 negatieve Authproeven; delete-account:5 weigeringen, inclusief echte Auth-lookup, PASS. PNG-media is inmiddels apart authenticated bewezen; andere media- en lifecyclegevallen blijven open; de afzonderlijke managed D-verwijdering is hierboven begrensd bewezen.
- Nog nodig: daadwerkelijke online wachtwoordreset, nog niet bewezen managed media/lifecycle en gedeelde gebruikersflows; kandidaat04-publicatie en callback-/authacceptatie. Kandidaat03-publicatie en de genoemde managed flows zijn apart vastgelegd; ontwikkelpush blijft open.
- Browsercontrole is hervat. GitHubpush vraagt een geautoriseerd account met schrijfrecht op uitsluitend `AVARYNAPP/avaryn-flutterflow-workspace`; de accountnaam is gevraagd, geen token.
- De archiefoverdracht is aangesloten. Bestaande legacyguards blijven van kracht; nieuw aangemaakte canonieke accounts vragen geen kunstmatige legacy-remap. Een nieuw lokaal én een afzonderlijk managed wegwerpaccount zijn via de app verwijderd, inclusief geweigerde herlogin; alleen de hierboven genoemde begrensde readbacks zijn bewezen.
- Androidcompile wordt afzonderlijk behandeld; native verbinding, toestelinstallatie, camera/toestemmingen en distributie zijn met deze webbewijzen niet aangetoond.
- Deze Mac heeft geen geschikte Xcode/macOS-combinatie voor Capacitor8. Geen bewezen iOS-simulatorbuild, archive of IPA; signing/developeraccounts blijven afzonderlijk te verifiëren.
- Apple/Google-providerlogin blijft verborgen zolang de vereiste configuratie ontbreekt. E-maillogin moet onafhankelijk daarvan werken.
- Geen publieke storevrijgave, main-merge of menselijke C-010-eindacceptatie.

Auth-templatevariabelen volgen de officiële [Supabase-documentatie](https://supabase.com/docs/guides/auth/auth-email-templates).

## Android kandidaat03 — historisch compilebewijs

**PASS:** versie0.10.8/build3, debug-APK en release-APK/AAB werkelijk opnieuw gebouwd, alle unsigned.188 officiële bronbestanden en33 ingesloten webbestanden per artifact exact gecontroleerd; officiële weboutput onveranderd. De eerder vanuit f19 plus zeven beoordeelde wijzigingen gebouwde kandidaat03-artifacts zijn inmiddels exact aan checkpoint `13a599996ca60abcb45dabec08f9aef5d3a08940` gebonden (`android-candidate03-checkpoint-binding.json`); dit is geen kandidaat04-compilebewijs. Bewijs: `.avaryn-local/productization-20260911/evidence/android-candidate03-compile.json`. Systeemimagelicentie, echte installatie/login, iOS en distributiesigning blijven open.

## Android kandidaat04 — finale authbron gecompileerd

**PASS:** de herziene04-bron met authmodusreset is afzonderlijk gecompileerd als unsigned debug-APK, release-APK en AAB, versie0.10.8/build4.188 bronbestanden gekoppeld aan de gecontroleerde snapshot; native entry `app-H5NJGZLZ.js`, HTTPS-pilot-API. Bewijs `android-candidate04-final-compile.json` en bijbehorend verslag; eerdere03-/04-artifacts behouden. Dit bewijst compilatie, geen installatie, native login/camera, signing of storedistributie. iOS en de persoonlijke systeemimagelicentiestap blijven open.
