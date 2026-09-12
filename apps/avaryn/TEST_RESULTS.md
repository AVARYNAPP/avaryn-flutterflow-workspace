# Actuele teststatus — kandidaat07, 12 september 2026

C010-V8-PRODUCTIZATION-20260912-07 (0.10.8/build7) is lokaal gebouwd: app-JXBJQ2KX.js,33 clientbestanden/35 publicatiebestanden, Worker SHA256 c55824eaa12ae1381ca5bdcced93f55c90d825e22b3737df1d968a1eac07aa2b. Online staat bij dit technische checkpoint nog05 (b812d4831f1366aaa3b5654b8dff39e56b9129d5). Publicatie en exact geladen bron worden afzonderlijk vastgelegd; dit document claimt geen nog niet uitgevoerde deployment.

- Gerichte correctie: na geslaagde Auth en een tijdelijke laadfout een duidelijke Opnieuw laden-route; geen rechtenfallback.144 functionele controles PASS;21 hiervan na contrastcorrectie opnieuw PASS.320px donkere eindweergave visueel gecontroleerd, leesbaar en zonder overflow; ongewijzigde320/390 light/dark-geometrie hergebruikt.
- 78 Workercontroles PASS, waaronder13 voor begrensde504-diagnostiek. Alleen canonieke RPC-route/status en toegestane foutcode; geen payloads.44 package/cold-route/native-versiecontroles PASS.
- Capacitor loggingBehavior none voorkomt gevoelige bridge-debugoutput;3 configchecks plus42 ongewijzigde callback/storagechecks PASS. Native07-update en runtimecontrole afzonderlijk in Androidreceipt. Geen nieuwe volledige productsuitetelling; eerder924/2SKIP blijft historisch baselinebewijs.
- Nieuwe managed gebruikersketen op05: nieuw bevestigd synthetisch manageraccount, profiel/paard/stal, twee-accountuitnodiging en acceptatie, gedeelde taakafronding en beide datedvarianten; planning, Basisvoeding/tijdelijk schema/instructies, verblijfplaats/box, faciliteitenmoment en exclusieve rijbakaanvraag→goedkeuring PASS. Tweede managersessie leest warming-upstap2, focus en privéreflectie terug. Staltoegang ingetrokken; groom verliest de context en behoudt eigen gegevens.
- Mac-onafhankelijkheid PASS met eigen devserver uit: nieuwe registratie, daadwerkelijk ontvangen en bevestigde mail, gegevens en media; na OS-herstart opnieuw ingelogd. Volledige49-migration DBbackup echt apart hersteld:125 tabelhashes/owners/RLS/ACL gelijk.2 private mediaobjecten op bytes/checksums geverifieerd. Geen tweede Storage-uploadrestore of volledige hostedconfigexportclaim.
- Eerdere401 en twee tijdelijke504 niet gereproduceerd; exacte oorzaak niet bewezen hersteld. Eerste natuurlijke tokenproef verwachtte401 al8s na expiry, terwijl PostgREST30s speling documenteert; die proef is geen refresh-PASS. Eén gecorrigeerde natuurlijke proef loopt naast ander werk, zonder globale TTLwijziging.
- Android: ondertekende05-installatie/login/taakafronding/herstart PASS;06 en07 dezelfde-keyupdates behouden sessie en serverdata. iOS: macOS26.6.2/Xcode26.6 aanwezig;07 native sync PASS, compilatie en simulatorgebruik bij dit checkpoint nog in uitvoering.

Persoonlijk wachtwoordherstel en gewone nieuwe telefoonlogin zijn door gebruiker bevestigd; geen persoonlijke verwijderproef. Bewijs: .avaryn-local/productization-20260911/evidence/final-user-flows/resume-*, candidate07-independent-source-review.json, platform- en backupreceipts. Actuele resterende backlog staat in docs/status/V8_PRODUCTIZATION_PROGRESS.md. Onderstaande secties en resterende gates zijn historische momentopnames, geen actuele blokkadelijst.

# Technisch checkpoint — 12 september 2026

Lokale kandidaat: `C010-V8-PRODUCTIZATION-20260912-05`, versie0.10.8/build5, entry `app-22PYSOSG.js`; nog niet gepubliceerd.
Kandidaat04 is vastgelegd in checkpoint `2abb2c45c229959afe20e60a2f4c4eae4a9cdd15` en gepubliceerd via Sites-commit `c446f7a261d857450bdbfd87fed98745192818dd`, deployment `appgdep_6aa540d52e748191b7ecf556b40ea39c` succeeded. Bewijs: `candidate04-checkpoint.json`, `candidate04-online-publication.json` en `candidate04-web-checkpoint-binding.json`. De tabel bewaart kandidaat02- en historisch bewijs; voor kandidaat05 is geen nieuwe volledige suite uitgevoerd.

| Onderdeel | Resultaat | Grens van het bewijs |
| --- | --- | --- |
| Gezamenlijke JavaScript-/Edgeproductsuite, kandidaat02 | 926 tests:924 PASS,0 FAIL,2 SKIP; hergebruikt als historische baseline voor kandidaat05 | Twee optionele liveproeven zijn niet uitgevoerd; geen nieuwe volledige run |
| Webbuild, kandidaat02 | PASS; entry `app-A6YYXOA7.js`,33 publieke manifestbestanden | Release gebruikt `/api`, drie lege providers en geen demo-inputs |
| Werkelijke lokale HTTPcontrole | PASS; alle bestanden gelijk aan de build, no-store en juiste kandidaat/backend | Geen browser-/visuele acceptatie; archief-RPC anoniem401 |
| Capacitor-sync Android/iOS | PASS voor beide platformprojecten | Assets/plugins kopiëren is geen native compilatie |
| Native fotoactie | 72 gerichte checks plus5 controllerchecks PASS; onderdeel van de gezamenlijke suite | Geen toestelcamera, galerij of OSpermissiedialoog getest |
| Zelfstandige lokale ontwikkelmodus | 35 Pythonchecks PASS;56 Nodechecks PASS | Nieuwe volledige stack nog niet gestart; bestaande devconfig wel gecontroleerd |
| Schone overdrachtsbuild | PASS vanaf `e1ba6965f459`;400 bronbestanden, verse npm-installatie, identieke webhashes | Schone map op dezelfde Mac; geen tweede fysieke machine |
| Schone overdrachtstests | Opnieuw884 PASS/2 SKIP;35 Pythonchecks en5 huidige backendguards PASS | Geen historische migration-executors opnieuw uitgevoerd |
| Tijdzone004 | 105 nieuwe en215 bestaande SQL-asserties PASS | Dev en Pilot afzonderlijk na echte backuprestore toegepast |
| Archief005 | 48 SQL-asserties en2 echte races PASS;39 clientchecks PASS | Dev/Pilot49 migrations; overige tabelinhouden en rechten behouden |
| SMTP, eerdere technische probe | TLS/SMTPauthenticatie235 PASS;0 e-mails verzonden door de probe | Latere echte bezorging en bevestiging staan in de kandidaat03-delta hieronder |
| Dependencies | Npm-audit0 bekende kwetsbaarheden; gerichte uuid11.1.1-override | Geen garantie tegen onbekende kwetsbaarheden |
| Visuele bron | 17/17 oorspronkelijke CSS/font/beeldbestanden bytegelijk | 320/390 light/dark en dagelijkse routebeelden uitgevoerd; vergelijking met exact dezelfde referentiedata nog niet compleet |

Kandidaat02 voegde dagwisselherstel en consistente native versies toe.117 gerichte dagwisselchecks en21 native-versiechecks zijn onderdeel van de926 controles. De twee Edgefuncties zijn naar alleen de Pilot gedeployed; exacte onlinebronchecks en8 negatieve toegangsproeven PASS. Andere managed mutaties dan de hieronder afzonderlijk bewezen flows blijven aparte gates. Lokale werkelijke UI-proeven voor planning, voeding, taken, faciliteiten en Vitality zijn vastgelegd in het voortgangsverslag.

## Kandidaat03 — gepubliceerd bewijs

- Worker: **65 PASS**. Externe GET-documentnavigatie vanuit Gmail mag uitsluitend bestaande shellroutes openen; API-origin-/bearercontroles blijven strikt en querytokens/headers gaan niet naar ASSETS. Packaging/native-versies: **35 PASS**. Bewijs: `candidate03-worker-navigation.json`, `candidate03-worker-navigation.log` en `candidate03-package-version-tests.log`. Deze gerichte checks vervangen hun eerdere deelruns; tel ze niet op als nieuwe volledige productsuite.
- Werkelijke **lokale** browserproeven na herladen: paardenfoto zichtbaar en geladen (`complete:true`,640×427); privéreflectie met Rustig/Energiek en bewaarde focus; expliciete verwijdering van een nieuw wegwerpaccount, gevolgd door geweigerde login. Geen persoonlijk account verwijderd en geen managed lifecycleclaim. Bewijs onder `final-user-flows/`: `horse-photo-after-reload.txt`, `horse-photo-render-after-reload.json`, `reflection-after-reload.txt`, `local-disposable-deletion-after.txt`, `local-disposable-login-refused.txt`.
- Managed Gmail: registratiemail bezorgd op12 september00:43, accountbevestiging in Pilot teruggelezen. Herstelmail om01:03 bezorgd met onderwerp “Herstel je AVARYN-wachtwoord”; daadwerkelijk wachtwoordresetten nog niet getest. Een bevestigde serveraccountstatus bewijst niet dat de daaropvolgende callbackpagina al werkte; die originfout is de kandidaat03-fix.
- Sites-audience revision2 is na expliciete gebruikerstoestemming openbaar/via link ingesteld; Supabase Auth/RLS is niet veranderd. De eerdere geautomatiseerde403-proef is nader vastgesteld als **Cloudflare1010-probeweigering** en bewijst geen native appfalen. Native toegang moet nog met de echte app worden getest. Kandidaat03 is na directe chattoestemming vastgelegd en gepubliceerd; bovenstaande identifiers binden het online bewijs aan die versie.

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

Resterende gates: GitHubpush met het juiste AVARYN-account, nog niet bewezen managed media-/lifecyclegevallen, kandidaat05-publicatie en tokenfout-/herstelacceptatie, persoonlijke wachtwoordreset en herstel-tokenreplay, HTTPS/aliascontrole, native installatiebewijs, iOS simulator/archive, signing en testdistributie. Zie [voortgang](../../docs/status/V8_PRODUCTIZATION_PROGRESS.md) en [releaseprocedure](RELEASES.md).

Het eerdere kandidaat01-broncheckpoint is `e1ba6965f459525061d45ae3984c2a0b877918c0`; de onderstaande oude artifacthashes horen uitsluitend bij die kandidaat. De schone webbuild heeft buildmanifest-SHA256 `c50b27f7569b3605f968f4afd7d1f9e883cd2adcc694087bb59518dee8d64784` en het afgeleide publicatiepakket Worker-SHA256 `5297b1372adcae3e12d37598a6a781ea73155f1084035457db9c16afc0774796`. `clean-handoff-build.json`, `clean-handoff-python.json` en `packaged-web-artifact.json` leggen dit lokaal vast. Dit was het destijds nog niet gehoste pakket. De ontwikkelpush werd geweigerd wegens ontbrekend schrijfrecht van het actieve GitHub-account; dat is geen mislukte build of Sites-publicatie.

Nieuwe bewijsbestanden: `candidate02-productsuite.log`, `day-refresh-receipt.json`, `native-version-sync.json`, `edge-deployment/deployment-outcome.json`, `managed-media-auth-probes.json`, `managed-delete-request-boundary-probes.json` en `final-user-flows/`. Voorafgaande ongewijzigde SQL-, dependency- en schone installatiebewijzen zijn hergebruikt.

## Android kandidaat03 — historisch compilebewijs

**PASS:** versie0.10.8/build3, debug-APK en release-APK/AAB werkelijk opnieuw gebouwd, alle unsigned.188 officiële bronbestanden en33 ingesloten webbestanden per artifact exact gecontroleerd; officiële weboutput onveranderd. De eerder vanuit f19 plus zeven beoordeelde wijzigingen gebouwde kandidaat03-artifacts zijn inmiddels exact aan checkpoint `13a599996ca60abcb45dabec08f9aef5d3a08940` gebonden (`android-candidate03-checkpoint-binding.json`); dit is geen kandidaat04-compilebewijs. Bewijs: `.avaryn-local/productization-20260911/evidence/android-candidate03-compile.json`. Systeemimagelicentie, echte installatie/login, iOS en distributiesigning blijven open.

## Android kandidaat04 — finale authbron gecompileerd

**PASS:** de herziene04-bron met authmodusreset is afzonderlijk gecompileerd als unsigned debug-APK, release-APK en AAB, versie0.10.8/build4.188 bronbestanden gekoppeld aan de gecontroleerde snapshot; native entry `app-H5NJGZLZ.js`, HTTPS-pilot-API. Bewijs `android-candidate04-final-compile.json` en bijbehorend verslag; eerdere03-/04-artifacts behouden. Dit bewijst compilatie, geen installatie, native login/camera, signing of storedistributie. iOS en de persoonlijke systeemimagelicentiestap blijven open.
