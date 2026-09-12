# AVARYN ontwikkelen

Lees eerst [README](README.md) en [het platformbesluit](../../docs/implementation/ADR_V8_CLIENT_PLATFORM.md). `src/` is de productbron; wijzig geen gekopieerde bestanden in `dist/`, native `public/` of de Sites-checkout. FlutterFlow en zijn exports zijn historische referenties en mogen deze client niet overschrijven.

| Wijziging | Bestaande module | Verificatie |
| --- | --- | --- |
| Presentatie en routes | `app.js`, schermmodules, gedeelde CSS | Gerichte rendertest en dezelfde viewport/data als de V8-referentie |
| Account, context, sessie | `backend-controller.js`, `backend-client.js`, `platform.js` | Accountwissel, uitloggen, late responses, verlopen toegang |
| Paard, team en overdracht | `horse-profile.js`, `horse-residency.js`, `team-core.js`, `authority-transfer.js` | Eigen en onbevoegde actor, actuele versies, opslaan en readback |
| Dagelijkse kern | Taken-, planning-, feeding- en facilitymodules | Instructies, tijdzone, conflicten en tweede gebruikerssessie |
| Nieuwe serveroperatie | `supabase/migrations`, `config/rpc-routes.json`, transport | SQL/HTTP-autorisatie en compatibiliteit, vóór clientpublicatie |

Een opgeslagen melding volgt pas na serverbevestiging. Gebruik de bestaande generatie-/contextcontrole rond ieder asynchroon resultaat. Een mislukte serverwrite mag niet veranderen in een lokale succesmelding. Browseropslag is alleen voor sessie-/concept-/voorkeurgedrag; gedeelde gegevens blijven servergegevens.

Werk in een ontwikkelbranch. Houd een wijziging klein: contract → implementatie → gerichte tests → handmatige getroffen flow. Draai de volledige productsuite één keer voor een samenhangende kandidaat. Oude Flutter-tests bewijzen deze JavaScript-client niet.

## Eigen lokale backend zonder FlutterFlow-binding

De productmodus heeft geen `.flutterflow/workspace.json`, Flutter/Dart, ruwe export of oude preview nodig. Gebruik Node 22+, Python 3.9+ en een actieve Docker-installatie met de vastgelegde **arm64** images uit [images.json](../../tool/route_b/images.json). Een andere architectuur is niet getest. De bestaande Docker-owner/projectlabels blijven behouden als backend-herkomst; zij vereisen geen FlutterFlow-accountbinding. Gebruik geen pilotgegevens voor disposable tests.

Haal ontbrekende images met hun exacte digests op, vanuit de repositoryroot:

```sh
python3 - <<'PY'
import json
import subprocess
with open('tool/route_b/images.json') as source:
    images = json.load(source)
for service, image in images.items():
    if service != 'architecture':
        subprocess.run(['docker', 'pull', image], check=True)
PY
```

Kies een unieke targetnaam en controleer vooraf dat de gekozen poorten vrij zijn. Hieronder zijn dat API 58001, database 58002, mailbox 58004 en web 58060. Gebruik de voorbeeldnaam niet om een bestaande omgeving over te nemen. Deze voorbeeldomgeving is niet als geheel opgestart als onderdeel van het documentatiebewijs.

Vanuit de repositoryroot:

```sh
python3 tool/avaryn_local.py prepare --target avaryn-c010-dev-eigennaam --port-base 58000 --web-port 58060 --product-client --backend-only
python3 tool/avaryn_local.py start --target avaryn-c010-dev-eigennaam --product-client --backend-only --no-fixtures
python3 tool/avaryn_local.py verify --target avaryn-c010-dev-eigennaam --product-client --backend-only --smoke-only --no-fixtures
node apps/avaryn/scripts/local-backend-config.mjs --environment .avaryn-local/avaryn-c010-dev-eigennaam/environment.json
```

`--product-client` valideert de actuele publieke package-, Capacitor- en releasemetadata. `prepare` maakt eigen gestopte containers met gecontroleerde loopbackbindings. `start` initialiseert uitsluitend deze backend en past de actuele forward-migrations met hun hashledger toe. Het voorbeeld maakt geen synthetische accounts. Voor de bestaande zes synthetische Auth-fixtures laat je `--no-fixtures` bij zowel `start` als `verify` weg; deze fixtures komen nooit in de productiebuild.

De beperkte rookproef controleert acht eigen loopbackservices, Auth-health, alle actuele migratiehashes, kernschema/ACL, anonieme weigering en CORS. Zonder fixtures rapporteert zij gebruikerssessies en frontend expliciet als **NOT TESTED**. Zij vervangt geen volledige SQL-regressie of browsercontrole. Productverificatie vereist daarom `--smoke-only`; de oude Flutter-suites zijn geen bewijs voor deze client.

De helper schrijft `product-bff.json` naast `environment.json`, met modus 0600 in de private targetmap. Het bestand bevat de geverifieerde lokale targetidentiteit, loopback-upstream en anonkey; geen servicekey, databasewachtwoord of JWT-signingkey. De helper controleert lopende container-ID's, eigendomslabels, image-pins, netwerken en werkelijke poorten. De devserver herhaalt die controle vóór het luisteren, plus de exacte frontend-origin, kandidaat en releasebuild.

Na containervervanging of wijziging van package/Capacitor/release genereer je de config opnieuw met hetzelfde helpercommando. Dat wijzigt geen backend. Kopieer private configuratie niet naar `dist/`, Sites, Git of een andere machine. Voor een afwijkende private opslaglocatie geef je bij alle runnercommando's dezelfde `--state-dir` op en pas je de configpaden aan.

## Productclient bouwen en starten

Bouw en start de officiële client in een aparte terminal, vanuit `apps/avaryn`:

```sh
npm ci
npm run build
AVARYN_DEV_PORT=58060 AVARYN_DEV_CONFIG="$PWD/../../.avaryn-local/avaryn-c010-dev-eigennaam/product-bff.json" npm run dev
```

Gebruik voor deze lokale webbuild geen externe `AVARYN_PUBLIC_API_BASE`: de BFF verwacht een release met `/api` en zonder demodata. Open `http://127.0.0.1:58060`. Zelfregistratie vereist e-mailbevestiging; de lokale mailbox is `http://127.0.0.1:58004` en verzendt niet naar echte inboxen. Zonder `AVARYN_DEV_CONFIG` start de interface, maar geeft de API een duidelijke niet-ingesteldmelding.

Status en alleen de backend stoppen, vanuit de repositoryroot:

```sh
python3 tool/avaryn_local.py status --target avaryn-c010-dev-eigennaam --product-client --backend-only
python3 tool/avaryn_local.py stop --target avaryn-c010-dev-eigennaam --product-client --backend-only
```

Stop de apart gestarte devserver zelf met Ctrl-C. De backendstop raakt dat proces niet en controleert alleen API/DB/mail-poorten. Volumes, accounts en bewijs blijven behouden. `--reuse-build` hoort niet bij de productmodus; gebruik de gewone productbuilder.

De toolintegratie is gericht getest met 35 Pythonchecks en 56 Nodechecks. De reproduceerbare opdrachten, vanuit de repositoryroot:

```sh
python3 -B -m unittest tool.route_b.test_product_client tool.route_b.test_local_lifecycle
node --test tool/productization/tests/local-backend-config.test.mjs tool/productization/tests/media-transport.test.mjs
```

Deze tests gebruiken synthetische bestanden en Docker/API-antwoorden; zij starten geen backend of browser.

## Actuele opvolger — kandidaat 09, 12 september 2026

`C010-V8-PRODUCTIZATION-20260912-09` (0.10.8/build 9) bevat de geteste 08-sessie-/naamcorrectie plus één bestaande mobiele CSS-regel die nu ook inlogvelden op16px zet. In de echte iOS-app veroorzaakte de oude13px-invoer focuszoom die na login bleef staan. Nieuwe normale iOS-login toont Vandaag volledig; eigen pinchzoom blijft mogelijk. Desktopvelden blijven13px, mobiele velden zijn16px op320/390; nul gemeten browserconsolemeldingen in deze lokale formulierproef.

Webentry `app-QTOOQUNT.js`; native entry `app-G44TDNMN.js` gebruikt de vaste HTTPS-Pilot-API. Backend `rvymglpkttlfwhqpmupp` en49 migrations/Edge/Auth/RLS zijn ongewijzigd. De onafhankelijke delta-herbouw leverde alle34 clientbestanden bytegelijk op, met ongewijzigde dependencies uit de schone08-build. Pakket/versie/koude-assets:44 PASS. De08-sessiecorrectie blijft exact bytegelijk en hergebruikt61 actuele regressies,141 omliggende controles en onafhankelijke review.

Android09: ondertekende update met dezelfde testkey behoudt sessie, paarden en opgeslagen foto;33 native bestanden exact. iOS09: standaard ad-hoc simulatorbuild, strikte codesigncontrole, installatie met bewaarde Keychain en33 bestanden exact; gewone login, uitloggen, light/dark en focus zonder uitsnijding daadwerkelijk gecontroleerd. De08-koude iOS-herstart las dezelfde stal en Android-testfoto terug. Native artifacts zijn simulator-/emulatortestbuilds, geen fysieke toestel- of storeacceptatie. Echte mail→automatische native terugkeer, fysieke camera en release-signing blijven afzonderlijke grenzen.

De losse Android08-login-time-out bleef afzonderlijk bewaard: Sites registreerde alleen een geslaagde preflight, geen voltooide Auth-POST; één normale herlogin werkte. Dit is geen bewezen JWT-fout of herstelde upstreamoorzaak. Voor de specifieke waargenomen tijdelijkeJWT-weigering is08/09 begrensde read-retry getest; een echte online weigering gevolgd door aantoonbaar geslaagde automatische retry is nog niet geobserveerd. De natuurlijke tokenproef (3643seconden zonder requests, oud token geweigerd, reguliere refresh en vier reads geslaagd) blijft onafhankelijk bewijs.

Kandidaat08 is lokaal vastgelegd als `21f80ff165cda0f3cd471701a0b67b95061677c6`, maar niet gepubliceerd. Automatische goedkeuringscontrole blokkeerde de ontwikkelpush omdat het eerdere directe akkoord alleen b083 en zes voorgangers omvatte; de concrete vraag staat apart open. De09-bron wordt selectief gecheckpoint en naar uitsluitend de bestaande pilot gepubliceerd. Tot het aparte publicatiereceipt slaagt, blijft de hieronder bewezen online07 de geldende online toestand. Geen main-merge, productie, Alpha, oud Staging, C-011, kosten of menselijke eindacceptatie.

Bewijs: `candidate09-version-assets-tests.log`, `candidate09-packaging-tests.log`, `candidate09-independent-build.json`, `candidate09-login-local-summary.json`, `android-candidate09-native-final.json`, `ios-candidate09-input-zoom-diagnosis.json` en de bijbehorende native/screenshotreceipts. De [testwandeling](TESTER_GUIDE.md) gebruikt vrije registratie via de gedeelde pilotlink. De geverifieerde backup is een momentopname; doorlopende backup en volledige hosted/Storage-herstelbaarheid zijn niet daarmee bewezen.

## Voorafgaand lokaal checkpoint 08 — bewijs op dat moment

`C010-V8-PRODUCTIZATION-20260912-08` (0.10.8/build 8) volgt checkpoint `b0839e2d287f13c0a2393feed5c1268f256b1b37` op. De webentry is `app-2NFGTUZO.js`; de native entry met vaste HTTPS-pilot-API is `app-ANBX25TF.js`. De hieronder vastgelegde 07-publicatie blijft de laatst geverifieerde online versie totdat het afzonderlijke 08-publicatiereceipt is afgerond. Backend `rvymglpkttlfwhqpmupp`, 49 migrations, Edgebron en toegangsgrenzen zijn ongewijzigd.

- **PASS — gerichte sessiecorrectie:** één herhaling na 1,2 seconde, uitsluitend voor een lees-RPC met HTTP401, code `PGRST303` en de exacte melding `JWT issued at future` of `JWT not yet valid`. Bearer, requestbody en totale deadline blijven gelijk; accountwissel/afbreken stopt de herhaling. Writes, Auth, Edge, verlopen tokens en andere weigeringen worden niet herhaald. 61 actuele sessie-/laadregressies PASS, inclusief eerst falende body-mutatietest; 141 omliggende controles PASS. Onafhankelijke review PASS. Bewijs: `candidate08-session-regressions.log`, `candidate08-affected-regressions.log`, `candidate08-jwt-retry-independent-review.json`.
- **Bevinding begrensd:** op 07 werd de tijdelijke JWT-weigering echt waargenomen bij één read terwijl drie gelijktijdige reads met dezelfde bearer slaagden. De huidige providerimplementatie en exacte upstreamoorzaak zijn niet vastgesteld. De 08-herhaling is gecontroleerde afhandeling van die specifieke weigering; een werkelijk optredende storing met daaropvolgende geslaagde automatische herhaling is online nog niet bewezen.
- **PASS — natuurlijke sessieveroudering:** aparte synthetische sessie bleef 3643 seconden zonder aanvragen. Na de vervaltijd plus 45 seconden werd het oude token geweigerd; reguliere refresh, Auth-user en vier kern-RPC's slaagden. Alleen de eigen testsessie is uitgelogd. Geen globale TTL-wijziging. Dit is direct Supabase-transportbewijs, geen bewijs van een uur slaapstand in elke browser/native app. `natural-m-session-leeway-final.json`.
- **PASS — Android 08:** offline ondertekende testbuild en update 07→08 met dezelfde sleutel, zonder dataverlies. Lange paardnaam breekt nu binnen de lijstkaart en detailkop; de badge blijft zichtbaar. De bestaande testfoto en sessie zijn behouden. De op 07 via de normale Android-bestandkiezer opgeslagen JPEG is ook na koude appstart en via een onafhankelijke nieuwe weblogin teruggelezen. Camerakeuze naar formulier is eerder bewezen; volledige camera→opslaan-keten en fysieke telefoon blijven NOT TESTED.
- **PASS — iOS-build/installatie:** standaard Xcode ad-hoc simulatorbuild 08, strikte codesigncontrole en 33/33 native bestanden geslaagd. De geïnstalleerde app gebruikt dezelfde 188 productbronbestanden als Android en behoudt appdata. Ingelogde simulatorflows worden afzonderlijk afgerond; compilatie en een gestart proces zijn daarvoor geen bewijs. Geen IPA, fysieke iPhone of TestFlight-publicatie.
- **OPEN — finale publicatie:** exacte bronselectie, staged secretscan, checkpointbinding en 08-onlinecontrole volgen. De twee regels voor lange paardnamen behouden de V8-stijl. Overige werkboom en stash blijven behouden; geen backendwijziging, main-merge, Alpha, oud Staging, productie, C-011 of nieuwe kosten.

## Overdracht en versieherkomst

De hervatting op 12 september 2026 begint bij checkpoint `b812d4831f1366aaa3b5654b8dff39e56b9129d5`: kandidaat `C010-V8-PRODUCTIZATION-20260912-05`, versie `0.10.8`, build `5`. De webentry van die kandidaat is `app-22PYSOSG.js`. Latere voortgang staat in [het voortgangsverslag](../../docs/status/V8_PRODUCTIZATION_PROGRESS.md); een gewijzigd document is op zichzelf geen nieuwe release.

De actuele gepubliceerde productbron is `b0839e2d287f13c0a2393feed5c1268f256b1b37`: kandidaat `C010-V8-PRODUCTIZATION-20260912-07`, versie `0.10.8`/build 7. De gecontroleerde ontwikkelpush staat op `implementation/c010-stable-team-collaboration`; main is ongewijzigd. De afzonderlijke Sites-commit `7dad42ffa616e8a71b89ddc173fccdee64d7ca71` is op de bestaande pilot gepubliceerd via deployment `appgdep_6aa58b8d85c48191b2529923f8a4c5e9` (geslaagd op 12 september om 17:28:33 UTC). Online script `app-JXBJQ2KX.js`, kandidaat 07 en backend `rvymglpkttlfwhqpmupp` zijn bevestigd. De schone 07-overdrachtsbuild vanaf dit checkpoint leverde met verse dependencies alle 34 clientbestanden inclusief manifest en 35 pakketbestanden bytegelijk op. De finale ingelogde 07-webcontrole is PASS: nieuwe synthetische login, sessie/herladen, kerngegevens en tweede Vitality-login, ingetrokken teamcontext, terug/scroll/uitloggen en ongeldige callbacks met opgeschoond adres. Vandaag 320/390 light/dark en plusmenu 390 zijn via actuele DOM/screenshots gecontroleerd, zonder overflow of gemeten consolefouten/waarschuwingen. Verse 07-readbacks hergebruiken 05-mutaties, ongewijzigde backend 49-contracten en eerder bewezen geldige mailbezorging; geen nieuwe persoonlijke reset of verwijderproef. Bewijs: `candidate07-publication-receipt.json` en `final-user-flows/candidate07-browser-regression.json`.

De officiële bron omvat `src/`, `server/`, `scripts/`, `config/`, de lockfile en de bestaande `android/`- en `ios/`-projecten. Gebruik een schone kopie van het bedoelde checkpoint voor een overdrachtsbuild. Neem geen persoonlijke `.avaryn-local/`, `node_modules/`, web/native outputs of signingmateriaal mee. `npm ci` herstelt de gepinde dependencies. De eerdere schone overdrachtsproef blijft historisch bewijs; deze handleiding claimt geen nieuwe volledige schone build.

Een gewone webbuild gebruikt `/api`. De bestaande permanente pilot is `https://avaryn-c010-pilot.silasdesteur.chatgpt.site/`, met backend `rvymglpkttlfwhqpmupp`. De lokale ontwikkelstack en mailbox uit het voorbeeld hierboven zijn daarvan gescheiden. `alpha.avaryn.eu` is nog geen vervangend publicatiedoel. Verander bij een clientbuild geen Auth-/databaseconfiguratie en kopieer geen testerdata naar development.

Voor een beoordeelde webbuild maakt dit commando vanuit `apps/avaryn` een **nieuw** lokaal publicatiepakket; kies een nog niet bestaande outputmap:

```sh
node scripts/package-pilot-site.mjs --project-id appgprj_6aa45546e34481918b42c6609c243630 --output ../../.avaryn-local/pilot-package-eigen-revisie
```

Dit publiceert niets. Broncommit, review, secretscan, afzonderlijke Sites-publicatie en controle van de werkelijk geladen versie volgen [RELEASES.md](RELEASES.md). Bewaar zowel het vorige beoordeelde artifact als zijn manifest. Een frontend-terugval vereist een nog ondersteund backendcontract; herstel geen database over nieuwere testerdata en breng geen bekende beveiligingsfout terug. Versie en buildnummer komen uit `config/release.json`; `npm run native:versions` synchroniseert Android/iOS. Een reeds verspreide native build krijgt bij een update een nieuw buildnummer.

## Native webassets voorbereiden

Werk in een aparte schone kopie, zodat de gewone weboutput met `/api` behouden blijft. Onderstaande opdrachten zijn vanuit `apps/avaryn` in die kopie. De HTTPS-origin is publieke configuratie; geen API-key, bearer, wachtwoord of signingsecret hoort in deze opdracht.

```sh
npm ci
AVARYN_PUBLIC_API_BASE=https://avaryn-c010-pilot.silasdesteur.chatgpt.site/api npm run build
npm run native:versions
```

Controleer daarna `dist/version.json` en `dist/build-manifest.json`: bedoelde kandidaat/build, exact bovenstaande HTTPS-API, `demo:false` en alle bestandshashes. Web en native hebben door hun API-origin verschillende gehashte scriptnamen. De native app bundelt deze assets; voeg geen `server.url` toe. Voer alleen de synchronisatie uit van het platform waaraan je werkt: `./node_modules/.bin/cap sync android` of `./node_modules/.bin/cap sync ios`.

## Android: bouwen en testsigning

De bestaande lokale tooling gebruikt JDK21, SDK36, build-tools36.0.0, Gradle8.14.3 en emulator37.1.11. De downloadpins staan in [android-toolchain-lock.json](../../tool/productization/android-toolchain-lock.json). Op 12 september 2026 heeft de gebruiker bovendien het Google APIs36 ARM64-systeemimage revision7 geïnstalleerd en de betreffende licentie persoonlijk geaccepteerd. Een aanwezig systeemimage bewijst geen gemaakte AVD, installatie of appflow; die resultaten blijven afzonderlijk in het voortgangsverslag.

De projectgebonden `toolchains/env.sh` zet Java/SDK-, Gradle- en Android-userpaden voor één terminal; het wijzigt geen shellprofiel. Op een nieuwe machine worden de gepinde tools opnieuw ingericht met eigen paden en persoonlijk geaccepteerde licenties. Kopieer dit Mac-specifieke environmentbestand niet blind. Activeer op deze Mac vanuit de repositoryroot:

```sh
source .avaryn-local/productization-20260911/toolchains/env.sh
```

In de voorbereide native kopie: synchroniseer Android, ga naar `android/` en gebruik de beoordeelde lokale signing-initfile. `AVARYN_ANDROID_TEST_SIGNING` verwijst naar het bestaande private JSON-bestand met modus0600; geef geen sleutelwachtwoord op de commandoregel. Initfile en signingmateriaal worden via de beveiligde buildoverdracht beschikbaar gesteld, niet in het webpakket.

```sh
./node_modules/.bin/cap sync android
cd android
: "${AVARYN_ANDROID_TEST_SIGNING:?Gebruik het bestaande private testsigningbestand}"
./gradlew --offline --no-daemon --console=plain --init-script ../android-test-signing.init.gradle -Pandroid.builder.sdkDownload=false :app:assembleDebug :app:assembleRelease :app:bundleRelease
```

Dit is de gecontroleerde commandovorm van de huidige Android-werkstroom; offline bouwen vraagt reeds gevulde caches. De initfile ondertekent uitsluitend debug met de afzonderlijke test-PKCS12; release-APK/AAB blijven unsigned tot echte release-signing is geverifieerd. Verifieer na elke build de APK-signature, package-ID, versie/build, API-origin en ingesloten manifestbestanden. De kandidaat05-tussenbuild compileerde, maar werd afgewezen vanwege drie oude dubbele cachebestanden; alleen `:app:clean` en een nieuwe artifactcontrole mogen daarvan een nieuw bruikbaar bewijs maken. Het eerste compilelog is dus geen goedgekeurd kandidaat05-installatieartifact.

Installeer uitsluitend het geverifieerde testartifact op de gekozen geautoriseerde emulator/toestel. Bewaar dezelfde testkey voor updates die testdata moeten behouden; een andere key is geen uitweg voor een updatefout. Wis geen testerdata en uninstall geen bestaande app om een signingconflict te verbergen. Een debug/testkey vervangt geen bestaande releasekey, storeaccount of distributietoestemming. Actuele ondertekening, installatie en echte native flows worden afzonderlijk gerapporteerd; de iOS-grens houdt deze Android-werkstroom niet tegen.

**Actueel Android-bewijs, kandidaat 07:** na de gecontroleerde schone 05-build zijn 05→06→07 werkelijk met dezelfde testkey en `adb install -r` op de eigen API 36 ARM64-emulator bijgewerkt. De app-ID en eerste installatiedatum zijn behouden. De synthetische sessie, Vandaag, bestaande paardenfoto en afgeronde Android 05-testtaak zijn zonder opnieuw inloggen teruggelezen, ook na de macOS-herstart. Kandidaat 07 is offline gebouwd als `0.10.8`/build 7; alle 33 webbestanden zijn per APK/AAB tegen het native manifest geverifieerd. Het debug-APK is ondertekend voor lokale tests; release-APK/AAB blijven unsigned. Dit is emulatorbewijs, geen fysieke toestel- of storeacceptatie.

De echte camera- en bestandkiezer hebben elk een synthetische JPEG teruggeleverd aan het fotoformulier; die eerste keuzes zijn geannuleerd en de bestaande paardenfoto bleef behouden. Een aanvullende normale gebruikersketen heeft op 07 uitsluitend nieuw synthetisch paard `Android07MediaProef` aangemaakt en daar een JPEG via de Android-bestandkiezer opgeslagen. De foto en beide paarden zijn na koude appstart teruggelezen; bestaande Nova, foto en persoonlijke gegevens zijn niet gewijzigd. Deze bestandsupload is bewezen in `android-candidate07-native-upload.json`; de volledige camera→opslaan-keten is niet uitgevoerd. Light/dark, scroll, taakreadback en Android-terugnavigatie zijn gecontroleerd. Warme email- en koude herstelcallbacks bereiken de bedoelde flow en weigeren ongeldige tokens. Echte mail met automatische terugkeer naar Android en fysieke toestelacceptatie blijven open. De lange naam zonder spaties toont in 07 overloop bij de paarddetailkop en lijstbadge; dit is een afzonderlijk concreet visueel punt.

Kandidaat 07 zet `loggingBehavior` op `none` voor Android en iOS, ook in debugbuilds: de standaard bridge-debuglogs kunnen SecureStorage-payloads bevatten. De echte 07-procescontrole na sessieherstel, camera/bestandkeuze en uitsluitend lokaal uitloggen bevatte nul bridge-payload/consolelogs, JSON-credentialvelden, JWT's of fatale exceptions. Er bleef alleen de vaste brug-opstartmelding vóór configuratie over. De logging-, callback- en sessieregressies tellen 45 geslaagde tests. Gedetailleerde lokale bewijzen: `android-candidate07-compile.json`, `android-candidate07-log-warm-media-logout.json` en `android-native07/` in de afgeschermde evidence-map; geen signingmateriaal, raw logs of sessiewaarden opnemen in Git. De aanvullende koude uploadreadback bevat eveneens nul gevoelige/fatale logcategorieën (`android-candidate07-log-upload-cold-readback.json`). Een nieuwe native 07-login liet wel een losse RPC401 na Auth200 zien; één normale herlogin werkte. Root heeft dit onafhankelijk als tijdelijke JWT-geldigheidsfout geïdentificeerd; kandidaat 08 is hiervoor in voorbereiding, zonder huidige 07-herstelclaim.

## iOS: uitvoerbare stappen en huidige grens

De gebruiker heeft deze MacBook Air M2 bijgewerkt. De hercontrole op 12 september 2026 bevestigt macOS `26.6.2`/build `25G83` en Xcode `26.6`/build `17F113`; de eerste-startcontrole geeft exit0 en de iOS26.5-simulator-SDK is aanwezig. Xcode hoeft niet opnieuw te worden geïnstalleerd. Bij de eerdere kandidaat05-controle waren nul bruikbare codesigningidentiteiten en nul lokale provisioningprofielen aanwezig; dat bewijst geen afwezigheid van een Apple-account elders. Het project gebruikt Swift Package Manager, iOS `15.0` als minimum, `com.mycompany.avarynalpha` en automatic signing zonder ingesteld development team. Versie/build volgen `config/release.json`. Dit ontwikkel-ID is geen bewijs van store-eigendom.

**PASS — simulatorbuild 08:** macOS, Xcode en runtime zijn aanwezig. Een standaard ad-hoc simulatorbuild geeft de app de door Xcode gegenereerde application-identifier voor Keychain. De aanvankelijke compile-only build met `CODE_SIGNING_ALLOWED=NO` had geen simulatorentitlements en gaf OSStatus -34018; gebruik die niet voor sessieacceptatie. Er is geen persoonlijk Apple-account, certificaatwijziging of handmatige entitlementverruiming nodig voor deze simulatorbuild.

Vanuit een aparte native bronkopie, na de hierboven beschreven HTTPS-build en `cap sync ios`:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project ios/App/App.xcodeproj -scheme App -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath ios/DerivedData -clonedSourcePackagesDirPath ios/SourcePackages \
  -packageCachePath "$PWD/ios/PackageCache" -skipPackageUpdates -jobs 2 \
  CONFIGURATION_BUILD_DIR=/private/tmp/avaryn-c010-ios08-products \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
codesign --verify --deep --strict /private/tmp/avaryn-c010-ios08-products/App.app
xcrun simctl list devices available
: "${AVARYN_IOS_DEVICE_UDID:?Kies de beschikbare geautoriseerde testsimulator}"
xcrun simctl bootstatus "$AVARYN_IOS_DEVICE_UDID" -b
xcrun simctl install "$AVARYN_IOS_DEVICE_UDID" /private/tmp/avaryn-c010-ios08-products/App.app
xcrun simctl launch "$AVARYN_IOS_DEVICE_UDID" com.mycompany.avarynalpha
```

Gebruik per kandidaat een eigen productmap buiten Documents/FileProvider: op deze Mac werd FinderInfo op afgeleide bundles opnieuw toegevoegd, waardoor normale codesigning weigerde. Verplaats alleen buildoutput; schakel signature- of packagevalidatie niet uit. De vastgelopen eerste SwiftPM-download is hersteld met officiële gepinde Capacitor 8.5.2-archieven, gecontroleerd tegen de ongewijzigde checksums uit Package.swift. Dependencies, plugins en appidentiteit zijn behouden.

08-build, signature, installatie en 33 assethashes zijn bewezen; ingelogde UI, sessieopslag en callbacks vragen afzonderlijke runtimeproeven. Bewaar een simulatorbundle alleen als afgeleid testartifact, zonder gebruikersdata of signingmateriaal. Een zip van App.app is geen IPA of fysieke iPhone-installatiepakket. De afgeronde macOS/Xcode/runtime-installatiestappen hoeven niet opnieuw gevraagd te worden.

Controleer kandidaat/backend, e-maillogin, eigen Vandaag, taak afronden/herladen, herstart, toetsenbord, terugnavigatie en foto-/toestemmingsgedrag. De aanwezige custom URL-scheme en camera-/fotobibliotheekteksten zijn configuratiebewijs; daadwerkelijke callbacks, veilige sessieopslag en camera blijven OS-/toestelproeven. De huidige pilotmail opent een HTTPS-webroute; automatische terugkeer vanuit die pilotlink naar de native app is niet bewezen. Gebruik de bestaande e-mailcodeflow waar nodig; wijzig geen callbackallowlist of platformidentiteit als testomweg.

Voor een devicearchive moeten eerst het bestaande AVARYN-team, de bundle-ID-registratie, een bruikbaar certificaat en provisioning worden geverifieerd. Selecteer die bestaande gegevens in Xcode; maak niet terloops een nieuwe appidentiteit of releasekey. Met reeds lokaal beschikbare, geautoriseerde signinggegevens kan vervolgens vanuit dezelfde kopie worden gebouwd:

```sh
: "${AVARYN_APPLE_TEAM_ID:?Verifieer eerst het bestaande AVARYN-signingteam}"
xcodebuild -project ios/App/App.xcodeproj -scheme App -configuration Release -destination 'generic/platform=iOS' -archivePath ios/App/output/AVARYN.xcarchive DEVELOPMENT_TEAM="$AVARYN_APPLE_TEAM_ID" archive
```

Er wordt geen automatische provisioningupdate of upload gestart. Een archive is geen geïnstalleerde testapp of TestFlight-release. Apple-accounttoegang, enrollment, MFA en juridische stappen blijven persoonlijk; export/distributie pas met geverifieerde toegang. Bewaar private keys/profielen en hun herstelgegevens in het eigen beveiligde signingregister, buiten Git, screenshots en logs. Neem geen persoonlijke keychain over in een gewone bronoverdracht.

## Assets en bewijs

Native beeldbestanden zijn afgeleid van `src/assets/mark.svg`. `config/native-brand-assets.json` bevat afmetingen en hashes. Alleen bij een bewuste merkassetwijziging is de optionele renderer nodig: `scripts/render-native-brand.mjs` met sharp0.35.4. Normale web/native builds gebruiken de opgenomen assets en hebben geen afhankelijkheid van die renderer of een persoonlijke packagecache.

De distributie bevat de fontlicenties in `src/assets/fonts/` en de vijf runtime-dependencylicenties in `src/assets/licenses/runtime-notices.txt`. Werk die notices mee bij een dependencywijziging. De `xcode > uuid`-override naar11.1.1 betreft alleen buildtooling; deze behoudt de gebruikte `v4()`-API en is met een Xcode-projectroundtrip gecontroleerd.

Beperkte bewijsbestanden horen bij het checkpoint; lokale credentials, screenshots met persoonlijke gegevens, browserprofielen, ruwe Auth-responses en backups horen niet in Git. Gebruik de gecontroleerde bron-/artifactmanifesten bij [releases](RELEASES.md).
