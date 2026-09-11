# Technisch checkpoint — 11 september 2026

Kandidaat: `C010-V8-PRODUCTIZATION-20260911-01`, versie0.10.8/build1, status development.
Dit is technisch bronbewijs. De permanente pilot, native installatie en menselijke acceptatie zijn nog niet afgerond.

| Onderdeel | Resultaat | Grens van het bewijs |
| --- | --- | --- |
| Gezamenlijke JavaScript-/Edgeproductsuite | 886 tests:884 PASS,0 FAIL,2 SKIP | Twee optionele liveproeven zijn niet uitgevoerd |
| Webbuild | PASS; entry `app-N467XD6F.js`,33 publieke manifestbestanden | Release gebruikt `/api`, drie lege providers en geen demo-inputs |
| Werkelijke lokale HTTPcontrole | PASS; alle bestanden gelijk aan de build, no-store en juiste kandidaat/backend | Geen browser-/visuele acceptatie; archief-RPC anoniem401 |
| Capacitor-sync Android/iOS | PASS voor beide platformprojecten | Assets/plugins kopiëren is geen native compilatie |
| Native fotoactie | 72 gerichte checks plus5 controllerchecks PASS; onderdeel van de gezamenlijke suite | Geen toestelcamera, galerij of OSpermissiedialoog getest |
| Zelfstandige lokale ontwikkelmodus | 35 Pythonchecks PASS;56 Nodechecks PASS | Nieuwe volledige stack nog niet gestart; bestaande devconfig wel gecontroleerd |
| Tijdzone004 | 105 nieuwe en215 bestaande SQL-asserties PASS | Dev en Pilot afzonderlijk na echte backuprestore toegepast |
| Archief005 | 48 SQL-asserties en2 echte races PASS;39 clientchecks PASS | Dev/Pilot49 migrations; overige tabelinhouden en rechten behouden |
| SMTP | TLS/SMTPauthenticatie235 PASS;0 e-mails verzonden door de probe | Bezorging, inboxbevestiging en herstelmail nog te bewijzen |
| Dependencies | Npm-audit0 bekende kwetsbaarheden; gerichte uuid11.1.1-override | Geen garantie tegen onbekende kwetsbaarheden |
| Visuele bron | 17/17 oorspronkelijke CSS/font/beeldbestanden bytegelijk | Finale screenshots/viewportvergelijking wachten op browsertoegang |

Voer de productsuite vanuit de repositoryroot uit:

```sh
node --test apps/avaryn/src/test/*.test.mjs tool/productization/tests/*.test.mjs test/edge/delete_account_test.mjs test/edge/delete_account_adapter_test.mjs
```

De twee overgeslagen liveproeven betreffen registratie/bevestiging/tokenherhaling/profiel en de uitwisseling van Vitality-voortgang tussen twee sessies. Synthetische controller-/transporttests bewijzen die online uitvoering niet. Eerder uitgevoerde twee-sessieproeven van teamuitnodiging en gedeelde taken blijven apart geldig.

De huidige backendbron wordt offline gecontroleerd met:

```sh
python3 tool/productization/backend/prepare_current_backend_release.py
```

Dit bevestigt49 migrationhashes en drie Edgebronbestanden; het voert niets uit en bewijst geen Edge-deployment. De47-bootstrap en004/005-promotiehelpers zijn historische, exact gepinde uitvoeringsinstrumenten. De005-plancontrole weigert terecht de later gewijzigde lokale runner; herschrijf geen historisch plan om heruitvoering mogelijk te maken. Ze horen niet bij de normale fresh-producttestopdracht.

Ruwe lokale receipts staan buiten Git in `.avaryn-local/productization-20260911/evidence`: `final-integration-tests.log`, `final-local-http.json`, `native-photo-receipt.json`, `product-runner-receipt.json`, `dependency-audit-fixed.json`, `visual-source-preservation.json` en de specifieke migrationrestore/applyreceipts onder `pilot-backend/`. Deze map bevat ook private operationele informatie en wordt niet als geheel gedeeld.

Resterende gates: managed media/account-Edge-deployment, finale ingelogde/visuele browserproeven, daadwerkelijke registratie-/herstelmailbezorging, permanente pilot en HTTPS/aliascontrole, schone checkpointbuild, Android APK/AAB, iOS simulator/archive, signing en testdistributie. Zie [voortgang](../../docs/status/V8_PRODUCTIZATION_PROGRESS.md) en [releaseprocedure](RELEASES.md).
