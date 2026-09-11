# AVARYN V8 client

`src/` is de officiële productclient. De geaccepteerde V8 wordt behouden; `dist/` en native webassets zijn afgeleide buildbestanden. FlutterFlow-export en oude previewkopieën zijn geen tweede productbron. De ontwikkelbranch en actuele gates staan in `../../docs/status/V8_PRODUCTIZATION_PROGRESS.md`.

Aanvullend: [ontwikkeling](DEVELOPMENT.md), [omgevingen](ENVIRONMENTS.md), [releases en herstel](RELEASES.md), [testerhandleiding](TESTER_GUIDE.md).

## Bouwen en testen

Gebruik Node22 of nieuwer en de vastgelegde `package-lock.json`.

```sh
npm ci
npm run build
```

De standaardbuild bevat geen demoaccounts of voorbeelddata. `npm run build:demo` is een afzonderlijk lokaal visueel voorbeeld en mag niet naar de pilot. De builder schrijft een kandidaat-ID, gehashte scriptnaam en `build-manifest.json` met alle publieke bestandshashes. Runtimecredentials staan nooit in bron of build.

Voer vanuit de repositoryroot de relevante productsuite uit:

```sh
node --test apps/avaryn/src/test/*.test.mjs tool/productization/tests/*.test.mjs test/edge/delete_account_test.mjs test/edge/delete_account_adapter_test.mjs
```

Live tests zijn expliciet opt-in en vereisen de geïdentificeerde eigen loopbackstack. Credentials en testreceipts blijven onder `.avaryn-local/`. Oude tests voor de laptop-tunnelgateway horen bij de behouden historische preview; de productserver wordt getest in `tool/productization/tests/pilot-worker.test.mjs`.

## Permanente webpilot

`server/worker.js` gebruikt uitsluitend pilotbackend `rvymglpkttlfwhqpmupp`. De host levert `ASSETS`, de exacte HTTPS-origin als `APP_ORIGIN` en de publishable API-key als afgeschermde `SUPABASE_PUBLISHABLE_KEY`. De server weigert service-rolekeys, willekeurige upstreams en routes buiten `config/rpc-routes.json` en de expliciete Auth/media/lifecyclecontracten.

Na de releasebuild maakt `scripts/package-pilot-site.mjs` met expliciete `--project-id` en een nieuwe `--output` stagingmap een gecontroleerde Sites-artifact. Dit verandert geen bron of native dist. De aparte Sites-checkout bevat alleen het afgeleide resultaat, versieherkomst en eigen hostingmetadata. Publiceren gebeurt pas na broncommit/review, backendgates en een geteste artifact.

Authsjablonen staan in `config/auth-emails/`. Bewaar vooraf de huidige providerconfiguratie, pas uitsluitend de nieuwe pilot aan en controleer werkelijke e-mailbezorging. Een SMTP-authenticatieproef bewijst geen inboxbevestiging.

## iOS en Android

Capacitor bundelt dezelfde clientassets. Er staat geen externe `server.url` in de native configuratie. Voor native builds moet `AVARYN_PUBLIC_API_BASE` bij bouwen de geverifieerde HTTPS-pilotorigin met `/api` bevatten; anders weigert de app native login. Voer daarna `npm run native:sync` uit. Gewone webbuilds gebruiken `/api` relatief aan hun eigen origin.

Native sessies gebruiken apparaatgebonden veilige opslag. Het bestaande ontwikkel-ID `com.mycompany.avarynalpha` is nog geen geverifieerde store-/signingregistratie. De native callbacks worden strikt afgehandeld, maar OS-installatie, signing, camera/toestelgedrag en testdistributie vragen afzonderlijk bewijs.

Android SDK-licenties worden persoonlijk geaccepteerd. iOS vraagt een bij Capacitor8 passende macOS/Xcode-combinatie. Geen licenties, enrollment, signingkeys of storepublicatie automatisch afhandelen. De actuele externe afhankelijkheden staan in het voortgangsverslag.
