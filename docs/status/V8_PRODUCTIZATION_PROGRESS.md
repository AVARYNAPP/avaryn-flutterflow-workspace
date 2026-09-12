# V8 productisering — voortgang, 12 september 2026

Dit is een werkstatus, geen eindacceptatie of publicatieverklaring.

Officiële client: `apps/avaryn/src`. Ontwikkelkandidaat `C010-V8-PRODUCTIZATION-20260912-03`, versie0.10.8/build3, entry `app-TFA5EGCM.js`. De gebruiker heeft nu rechtstreeks in de chat toestemming gegeven voor het lokale checkpoint en de publicatie van kandidaat03. Commit en deployment zijn nog niet als voltooid vastgelegd; definitieve publicatiehash en verificatie volgen.
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
| Nieuwe pilothosting | `appgprj_6aa45546e34481918b42c6609c243630` | Kandidaat02 gepubliceerd; directe chattoestemming voor kandidaat03-checkpoint en publicatie is gegeven, uitvoering nog niet als voltooid vastgelegd. Audience revision2 na expliciete toestemming openbaar/via link; Auth/RLS onveranderd. https://avaryn-c010-pilot.silasdesteur.chatgpt.site |
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

## Kandidaat03 — laatste gerichte delta

- Gmail-navigatie naar de callback werd vóór de shellrouter geweigerd. De Worker staat nu alleen GET-documentnavigatie naar bestaande shellpaden toe, zonder API-/bearergrenzen te verruimen of tokens naar ASSETS te sturen. **65 Workerchecks PASS**; **35 packaging/native-versiechecks PASS** (`candidate03-worker-navigation.json` en `candidate03-package-version-tests.log`). De onderliggende kandidaat02-suite **924 PASS/2 SKIP** is hergebruikt; geen nieuwe volledige suiteclaim.
- Nieuwe lokale browserreadbacks: paardenfoto geladen na herladen (`complete:true`,640×427); reflectie Rustig/Energiek met eigen focus en Privé houden bewaard; nieuw wegwerpaccount via de app verwijderd en opnieuw inloggen geweigerd. Geen persoonlijke accountverwijdering. Exact bewijs: `final-user-flows/horse-photo-after-reload.txt`, `horse-photo-render-after-reload.json`, `reflection-after-reload.txt`, `local-disposable-deletion-after.txt` en `local-disposable-login-refused.txt`. Dit is geen managed media-/lifecycleproef.
- Echte registratiemail om12 september00:43 in Gmail bezorgd; bevestigde accountstatus op Pilot teruggelezen. Herstelmail om01:03 bezorgd, onderwerp “Herstel je AVARYN-wachtwoord”; echte reset nog niet uitgevoerd. De bevestigde accountstatus en het openen van de callbackpagina zijn afzonderlijke stappen.
- De eerdere403 van de geautomatiseerde nativeconnectiviteitsprobe blijkt **Cloudflare1010-probeweigering**, geen bewezen defect van de native app. De expliciet toegestane audience revision2 wijzigt uitsluitend Sites-toegang, geen Auth/RLS. Werkelijke native verbinding blijft te testen; kandidaat03 heeft nog geen definitieve publicatiehash of online acceptatie.

## Open werk en persoonlijke afhankelijkheden

- De beide Pilot-Edgefuncties zijn gedeployed; de drie online bronbestanden zijn exact tegen de geteste checksums gelezen. Na afzonderlijk akkoord staan de legacy JWT-filters uit; verplichte interne Auth- en databaseautorisatie blijven behouden. Media:3 negatieve Authproeven; delete-account:5 weigeringen, inclusief echte Auth-lookup, PASS. Authenticated media en lifecycle nog niet bewezen.
- Nog nodig: daadwerkelijke online wachtwoordreset, authenticated managed media/accountlifecycle en gedeelde gebruikersflows; kandidaat03-publicatie en browseracceptatie. Kandidaat02-publicatie en mailbezorging/bevestiging zijn hierboven apart vastgelegd; ontwikkelpush blijft open.
- Browsercontrole is hervat. GitHubpush vraagt een geautoriseerd account met schrijfrecht op uitsluitend `AVARYNAPP/avaryn-flutterflow-workspace`; de accountnaam is gevraagd, geen token.
- De archiefoverdracht is aangesloten. Bestaande legacyguards blijven van kracht; nieuw aangemaakte canonieke accounts vragen geen kunstmatige legacy-remap. Een nieuw lokaal wegwerpaccount is via de app verwijderd, inclusief geweigerde herlogin; de managed end-to-end proef staat nog open.
- Androidcompile wordt afzonderlijk behandeld; native verbinding, toestelinstallatie, camera/toestemmingen en distributie zijn met deze webbewijzen niet aangetoond.
- Deze Mac heeft geen geschikte Xcode/macOS-combinatie voor Capacitor8. Geen bewezen iOS-simulatorbuild, archive of IPA; signing/developeraccounts blijven afzonderlijk te verifiëren.
- Apple/Google-providerlogin blijft verborgen zolang de vereiste configuratie ontbreekt. E-maillogin moet onafhankelijk daarvan werken.
- Geen publieke storevrijgave, main-merge of menselijke C-010-eindacceptatie.

Auth-templatevariabelen volgen de officiële [Supabase-documentatie](https://supabase.com/docs/guides/auth/auth-email-templates).

## Android kandidaat03 — laatste compilebewijs

**PASS:** versie0.10.8/build3, debug-APK en release-APK/AAB werkelijk opnieuw gebouwd, alle unsigned.188 officiële bronbestanden en33 ingesloten webbestanden per artifact exact gecontroleerd; officiële weboutput onveranderd. Bronbinding: huidig f19-checkpoint plus de zeven beoordeelde staged wijzigingen, nog geen nieuw commit. Bewijs: `.avaryn-local/productization-20260911/evidence/android-candidate03-compile.json`. Systeemimagelicentie, echte installatie/login, iOS en distributiesigning blijven open.
