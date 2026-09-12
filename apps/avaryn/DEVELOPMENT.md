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

## Overdracht en versieherkomst

De hervatting op 12 september 2026 begint bij checkpoint `b812d4831f1366aaa3b5654b8dff39e56b9129d5`: kandidaat `C010-V8-PRODUCTIZATION-20260912-05`, versie `0.10.8`, build `5`. De webentry van die kandidaat is `app-22PYSOSG.js`. Latere voortgang staat in [het voortgangsverslag](../../docs/status/V8_PRODUCTIZATION_PROGRESS.md); een gewijzigd document is op zichzelf geen nieuwe release.

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

**Actueel Android-bewijs, kandidaat07:** na de gecontroleerde schone05-build zijn05→06→07 werkelijk met dezelfde testkey en `adb install -r` op de eigen API36 ARM64-emulator bijgewerkt. De app-ID en eerste installatiedatum zijn behouden. De synthetische sessie, Vandaag, bestaande paardenfoto en afgeronde Android05-testtaak zijn zonder opnieuw inloggen teruggelezen, ook na de macOS-herstart. Kandidaat07 is offline gebouwd als `0.10.8`/build7; alle33 webbestanden zijn per APK/AAB tegen het native manifest geverifieerd. Het debug-APK is ondertekend voor lokale tests; release-APK/AAB blijven unsigned. Dit is emulatorbewijs, geen fysieke toestel- of storeacceptatie.

De echte camera- en bestandkiezer hebben elk een synthetische JPEG teruggeleverd aan het fotoformulier. Beide keuzes zijn vervolgens geannuleerd; de bestaande paardenfoto bleef behouden. Native upload is hiermee niet bewezen. Light/dark, scroll, taakreadback en Android-terugnavigatie zijn gecontroleerd. Een warme synthetische emailcallback bereikt de bevestigingsflow en een ongeldig token wordt afgewezen. Een koude synthetische herstelcallback bereikt de herstelbevestiging en het ongeldige token wordt ook daar afgewezen. Ontvangst van een echte mail en automatische terugkeer vanuit de huidige HTTPS-pilotlink naar Android blijven een afzonderlijke acceptatieproef; de eerdere webmailproef bewijst die native route niet.

Kandidaat07 zet `loggingBehavior` op `none` voor Android en iOS, ook in debugbuilds: de standaard bridge-debuglogs kunnen SecureStorage-payloads bevatten. De echte07-procescontrole na sessieherstel, camera/bestandkeuze en uitsluitend lokaal uitloggen bevatte nul bridge-payload/consolelogs, JSON-credentialvelden, JWT's of fatale exceptions. Er bleef alleen de vaste brug-opstartmelding vóór configuratie over. De logging-, callback- en sessieregressies tellen45 geslaagde tests. Gedetailleerde lokale bewijzen: `android-candidate07-compile.json`, `android-candidate07-log-warm-media-logout.json` en `android-native07/` in de afgeschermde evidence-map; geen signingmateriaal, raw logs of sessiewaarden opnemen in Git.

## iOS: uitvoerbare stappen en huidige grens

De gebruiker heeft deze MacBook Air M2 bijgewerkt. De hercontrole op 12 september 2026 toont macOS `26.6.2`/build `25G83`; `/Library/Developer/CommandLineTools` is nog geselecteerd en `/Applications/Xcode.app` ontbreekt. De macOS-compatibiliteitsgrens is daarmee opgelost; volledige Xcode blijft nodig. Bij de eerdere kandidaat05-controle waren nul bruikbare codesigningidentiteiten en nul lokale provisioningprofielen aanwezig; dat bewijst geen afwezigheid van een Apple-account elders. Het project gebruikt Swift Package Manager, iOS `15.0` als minimum, `com.mycompany.avarynalpha` en automatic signing zonder ingesteld development team. Versie/build volgen `config/release.json`. Dit ontwikkel-ID is geen bewijs van store-eigendom.

**PASS — lokale voorbereiding:** project/Info.plist gevalideerd; de vier gepinde plugins zijn aanwezig; `cap sync ios` heeft de 33 native kandidaat05-bestanden gekopieerd en hun hashes komen overeen. De genegeerde iOS-weboutput is naar05 vernieuwd met behoud van de oude02-output in een private backup. Geen beheerde iOS-bron of officiële weboutput is veranderd. **BLOCKED — compilatie:** de simulator-buildopdracht stopt vóór compilatie omdat volledige Xcode ontbreekt. Geen simulator-app, archive, IPA, installatie of native gebruikersflow is hiermee bewezen.

Capacitor8 vereist minimaal Xcode26.0. De actuele stabiele Xcode26.6 ondersteunt deze macOS26.6.2-machine en bevat de iOS26.5-SDK. Zie de officiële [Capacitor-vereisten](https://capacitorjs.com/docs/getting-started/environment-setup) en [Apple-compatibiliteitstabel](https://developer.apple.com/xcode/system-requirements), opnieuw gecontroleerd op 12 september 2026.

**Benodigde gebruikersactie:** installeer de gratis stabiele [Xcode26.6 uit de Mac App Store](https://apps.apple.com/us/app/xcode/id497799835), open Xcode eenmaal en laat de iOS26.5-simulatorcomponent installeren. Rond eventuele Apple-accountbevestiging en de licentie persoonlijk af. Een betaald Apple Developer-abonnement is voor deze simulatorproef niet nodig; signing is niet nodig voor de eerste simulatorbuild.

Na die stap, vanuit de voorbereide native kopie van `apps/avaryn`:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-version
xcrun simctl list devices available
./node_modules/.bin/cap sync ios
xcodebuild -project ios/App/App.xcodeproj -scheme App -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/DerivedData CODE_SIGNING_ALLOWED=NO build
```

`DEVELOPER_DIR` geldt voor deze terminal en verandert de globale Xcode-selectie niet. Deze buildopdracht is hier daadwerkelijk gestart en gestopt op ontbrekende Xcode; uitvoering op de geschikte Mac is nog **NOT TESTED**. Swift Package Manager moet daar de exact gepinde Capacitor8.5.2-package ophalen. Er is geen CocoaPods- of dependency-upgrade nodig.

Kies vervolgens de UDID van een beschikbare iPhone-simulator uit de lijst, start deze in Xcode en vul alleen die UDID in als `AVARYN_IOS_DEVICE_UDID`:

```sh
: "${AVARYN_IOS_DEVICE_UDID:?Kies eerst een beschikbare iPhone-simulator}"
xcrun simctl bootstatus "$AVARYN_IOS_DEVICE_UDID" -b
xcrun simctl install "$AVARYN_IOS_DEVICE_UDID" ios/DerivedData/Build/Products/Debug-iphonesimulator/App.app
xcrun simctl launch "$AVARYN_IOS_DEVICE_UDID" com.mycompany.avarynalpha
```

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
