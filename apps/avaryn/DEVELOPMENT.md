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

## Assets en bewijs

Native beeldbestanden zijn afgeleid van `src/assets/mark.svg`. `config/native-brand-assets.json` bevat afmetingen en hashes. Alleen bij een bewuste merkassetwijziging is de optionele renderer nodig: `scripts/render-native-brand.mjs` met sharp0.35.4. Normale web/native builds gebruiken de opgenomen assets en hebben geen afhankelijkheid van die renderer of een persoonlijke packagecache.

De distributie bevat de fontlicenties in `src/assets/fonts/` en de vijf runtime-dependencylicenties in `src/assets/licenses/runtime-notices.txt`. Werk die notices mee bij een dependencywijziging. De `xcode > uuid`-override naar11.1.1 betreft alleen buildtooling; deze behoudt de gebruikte `v4()`-API en is met een Xcode-projectroundtrip gecontroleerd.

Beperkte bewijsbestanden horen bij het checkpoint; lokale credentials, screenshots met persoonlijke gegevens, browserprofielen, ruwe Auth-responses en backups horen niet in Git. Gebruik de gecontroleerde bron-/artifactmanifesten bij [releases](RELEASES.md).
