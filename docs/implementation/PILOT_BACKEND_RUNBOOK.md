# C010 Pilot — gecontroleerde backendbootstrap

Dit is het historische verslag van de uitgevoerde **47-migrationbootstrap**. De pilot staat inmiddels op49 na afzonderlijk geteste004 en005. Voer de bootstrap of het oude stagingcommando niet opnieuw uit op de huidige bron. Het oude manifest en de uitvoeringsreceipts blijven ongewijzigd.

De actuele49-bronsnapshot staat in `apps/avaryn/config/backend-release.json`; controleer die offline met `python3 tool/productization/backend/prepare_current_backend_release.py`. Dit is geen deploymentbewijs. De actuele toestand, aparte incrementprocedures en nog niet gepubliceerde Edgecode staan in [de voortgang](../status/V8_PRODUCTIZATION_PROGRESS.md).

## Doel en huidige grens

Uitsluitend **AVARYN C010 Pilot**, organisatie **AVARYN** (`ufvwcbrvwbqmejwraend`), project **`rvymglpkttlfwhqpmupp`**, API `https://rvymglpkttlfwhqpmupp.supabase.co`. Root heeft deze nieuwe, door de gebruiker aangemaakte resource in het AVARYN-dashboard gecontroleerd. Op 11 september 2026 zijn de projectgebonden TLS-verbinding, lege databasebasis, volledige backup, echte afzonderlijke restore en alle 47 migrations daadwerkelijk geverifieerd en toegepast. De managed Auth-, Edge- en SMTP-runtime is daarmee nog niet bewezen.

De bestaande globale CLI-login behoort niet tot deze AVARYN-scope: niet hergebruiken, niet verder onderzoeken. Staging, oude Alpha, andere projecten en de lokale preview vallen buiten deze bootstrap. De gecontroleerde projectdatabaseverbinding is nu beschikbaar; gebruik geen andere accountcredentials.

Runtimebackendidentiteit moet `rvymglpkttlfwhqpmupp` zijn; de FlutterFlow-bronbinding `a-v-a-r-y-n-alpha-ynvyuq` is geen backendtarget. Hetzelfde onderscheid geldt voor disposable dev: daar is de runtime-identiteit `avaryn-c010-vitality-20260911-a`.

## Vastgezette bron

`tool/productization/backend/pilot-release-manifest.json` bevat de47 afzonderlijke versies, bestandsnamen en SHA256-hashes tot en met `202609110003`, plus de drie bronbestanden voor de twee benodigde Edge Functions. Geen lokale users, wachtwoorden, Auth/Storage-inhoud, fixtures of testreceipts worden geëxporteerd. De migrations bevatten wel noodzakelijke rollen-/permissioncatalogi, bucketdefinities en een nieuw lokaal-in-die-database gegenereerd uitnodigings-HMACgeheim; dat zijn geen demogegevens en het geheim wordt niet uit dev gekopieerd.

Historisch gebruikte offline commando's voor de toenmalige47-bron (geen huidige uitvoeringsinstructie):

```sh
python3 -B tool/productization/backend/prepare_pilot_release.py
python3 -B tool/productization/backend/prepare_pilot_release.py --stage .avaryn-local/productization-20260911/private/pilot-release-candidate
python3 -B -m unittest discover -s tool/productization/backend -p 'test_*.py'
```

De stagingmap bevat exact47 migrations,3 Edgebronbestanden, een minimale config met seed uit en het manifest. Een bestaande map wordt geweigerd. Verandert één bronhash, dan stopt verificatie; herbeoordeling en bewust `--write-manifest` zijn vereist. De bestaande repositorylink/config wordt niet vervangen. PostgreSQL17 is de huidige bronconfigverwachting; controleer de echte managed versie voordat dump/executor gekozen wordt.

## Bestaand projectwachtwoord veilig invoeren

De gebruiker voert zelf in een privéterminal uit:

```sh
python3 tool/productization/backend/configure_pilot_connection.py
```

Dit leest het reeds gekozen databasewachtwoord met `getpass` en weigert piped invoer. Geen netwerk, passwordreset, CLI-login of PAT. De standaard is de door root gecontroleerde **sessionpooler** `aws-1-eu-west-1.pooler.supabase.com:5432`, database `postgres`, gebruiker `postgres.rvymglpkttlfwhqpmupp`. Alleen `--connection direct` kiest het eveneens gecontroleerde `db.rvymglpkttlfwhqpmupp.supabase.co:5432`, gebruiker `postgres`. Geen transactionpooler6543 voor dump/migration.

De ignored map `.avaryn-local/productization-20260911/private/pilot-backend/` krijgt0700, bestanden0600. `connection.json` bevat uitsluitend metadata en paden naar `pg_service.conf`/`pgpass`; het wachtwoord staat alleen escaped in PGpass. Vorige generaties blijven behouden. De invoerhelper test de verbinding niet. TLS blijft `verify-full`; bij TLSfalen nooit verzwakken naar alleen encryptie. [PostgreSQL SSL-parameters](https://www.postgresql.org/docs/17/libpq-connect.html).

Bij de echte verbinding op11september2026 bleken systeem-CA's onvoldoende: de pooler gebruikt **Supabase Root2021 CA**. Root heeft de exacte downloadlink in het geverifieerde pilotdashboard gezien. Het via HTTPS opgehaalde1367bytes-certificaat heeft SHA256 `700723581420dd1ac98fd7e9ac529f0ef210eadcaf87fc868a3ad7d114c2f3b7`. `attach_pilot_certificate.py --certificate <dashboard-download> --sha256 <gecontroleerde-hash>` maakt uitsluitend een nieuwe projectprivate pgservicegeneratie; oude config en PGpass blijven behouden. Er wordt geen systeemtrust gewijzigd. Vertrouw nooit een CA uitsluitend omdat de mislukte TLSverbinding die zelf aanbiedt. De officiële instructie gebruikt eveneens het dashboardcertificaat. [Supabase psql](https://supabase.com/docs/guides/database/psql).

`python3 -B tool/productization/backend/check_pilot_connection.py` verifieert de vaste target, private rechten, CA-hash en metadata met read-only transacties. De werkelijke clientverbinding gebruikt TLS1.3 met `TLS_AES_256_GCM_SHA384`. `pg_stat_ssl` meet bij deze sessionpooler de interne Supavisor→PostgreSQL-hop en meldt daar geen TLS; dit is geen bewijs dat de clientverbinding onversleuteld is. Het platform-SSLswitch is niet veranderd.

Een begrensde connector moet deze private bestanden in RAM laden, exactref/host/poort/database/user hercontroleren en de libpqvariabelen `PGSERVICEFILE`, `PGPASSFILE`, `PGSERVICE` aan het kindproces meegeven. Geen password/connection-URL in argv, stdout, shellhistorie of rapport. Bij Docker alleen deze private generatie read-only mounten en de twee paden naar het containerpad vertalen. Geen `--debug`-logs met secrets.

## Read-only preflight vóór iedere eerste apply

1. Controleer verbindingstype, TLS-hostcertificaat en de exacte dashboardresource. Sla actuele project-/organisatie-/regiometadata en serverversie privé op. `current_database()` alleen bewijst geen projectidentiteit.
2. Voer `pilot_preflight.sql` uit in de begrensde read-only transactie. Vereist: Authusers/identities0, Storageobjects0, geen onbekende apprelaties, geen onverwachte buckets, de benodigde rollen/cryptohelpers en beschikbare `btree_gist`. Bij ontbrekende prerequisites eerst rapporteren; geen ad-hoc uitbreiding van historische migrations.
3. Alleen indien de historytabel bestaat: `pilot_migration_history.sql`. Voor fresh bootstrap moet de history leeg zijn. Een volledige reeds passende47history leidt tot verificatie, niet opnieuw toepassen. Onbekende/partiële geschiedenis vergt expliciete vergelijking; geen `migration repair` of reset.
4. Leg Auth-/Storage-/REST-config vóór wijziging vast via geautoriseerde Management API/dashboard. `private` mag niet door PostgREST worden geëxposeerd. Tijdens bootstrap geen testerwrites; laat registratie pas beschikbaar worden nadat de gehele definitieve schema- en Authketen is geverifieerd. Een noodzakelijke tijdelijke registratieblokkade is een afzonderlijk gecoördineerde configuratieactie met herstelwaarde, geen onderdeel van de offline helper.

## Backup en herstelgate

Gebruik een bij de echte server passende `pg_dump --format=custom` via de exact gecontroleerde projectverbinding, naar exclusief aangemaakt0600bestand. Bewaar consistent vangstmoment, versie, grootte en SHA256. Valideer `pg_restore --list` en volledige decode; herstel vervolgens werkelijk naar een **aparte lege disposable bestemming** met passende Supabaserollen/schema's. Vergelijk oorspronkelijke history, catalogus en tabelinhouden. Een decode is geen herstelproef.

De standaard SupabaseCLI-dump sluit Auth, Storage en extension-schema's uit en bevat standaard geen data. Die mag daarom niet als complete projectbackup worden benoemd. [CLI dumpcontract](https://supabase.com/docs/reference/cli/supabase-db-dump). Ook een volledige databasedump bevat geen Storagebytes of Auth/SMTP/providerconfig. Archiveer deze configuratie apart privé; bevestig vóór de eerste bootstrap dat er werkelijk geen objectbytes bestaan. Na ingebruikname moeten uploads en testerdata afzonderlijk herstelbaar zijn.

De lokaal geslaagde46→47-herstelproef is ontwikkelbewijs, geen backup of remote-PASS voor deze pilot. Voor deze pilot is inmiddels een eigen volledige custombackup gemaakt:282688bytes,0600, SHA256 `073726282a559bd61b75807d7fcb16bd69bf0b4bd36e5404f5708b1bfff86d0e`. Listing en volledige decode slaagden. De echte restore naar één afzonderlijke database op de bestaande disposable devstack vergeleek alle34 niet-extension tabelinhouden en de tabelcatalogus/owners exact. De eerste restore met gewone postgres strandde op ownerherstel; alleen de aantoonbaar eigen scratch is opnieuw leeg aangemaakt en vervolgens atomair met bestaande lokale `supabase_admin` hersteld. Er zijn geen rolgrants toegevoegd en de bestaande devdatabase is behouden.

De herstelde baseline is daarna als **niet-superuser postgres** door alle47 migrations gegaan; historyhashes en autorisatiepostflight slaagden. Zie `.avaryn-local/productization-20260911/evidence/pilot-backend/`. Geen automatische restore over pilotdata, geen projectreset; bij fout intake stoppen, bewijs bewaren en forward recovery beoordelen.

## Migrationapply na vrijgegeven gates

De werkelijk gekozen route is de projectgebonden libpqverbinding met `apply_pilot_migrations.py`; de globale SupabaseCLI-login wordt niet gebruikt. `--mode local-rehearsal --backup-run <private-backup-run>` controleert eerst de echte restore. `--mode remote-fresh --backup-run <dezelfde-run> --rehearsal-receipt <PASS-receipt>` vereist die passende proef, exacte bron-/backuphashes en opnieuw de lege remote clusteridentiteit `7678069749886157684`.

Iedere migration en bijbehorende standaard `supabase_migrations.schema_migrations`-rij landen samen in één transactie. Alleen de oorspronkelijke buitenste BEGIN/COMMIT worden door de gecontroleerde transactielaag vervangen; de oorspronkelijke bytes blijven ongewijzigd als één item in `statements[]` en worden na afloop met SHA256 gecontroleerd. Geen custom lokale ledger, fixtures, reset of historyrepair. Na een fout stopt de uitvoerder; een gedeeltelijke of ambigue apply vereist eerst lezen van de werkelijke history. Deze **fresh** uitvoerder weigert een database die al appgegevens/history heeft; gebruik hem niet als generieke updater voor testers.

Met een nieuw, expliciet AVARYN-geautoriseerd Managementtoken kan `supabase --workdir <staging> link --project-ref rvymglpkttlfwhqpmupp` de bedoelde resource koppelen; de CLI kan daarvoor een kortlevende loginrol maken zonder databasewachtwoordreset. Dat is wél een remote rolmutatie en gebeurt pas na coördinatie. De bestaande globale CLIcredential is uitgesloten. Alternatief blijft de expliciete projectdatabaseverbinding; een uitvoerder daarvoor moet vóór gebruik worden gereviewd. [CLI migrations](https://supabase.com/docs/reference/cli/supabase-db-push), [officiële tijdelijke loginrol](https://supabase.com/docs/reference/api/v1-create-login-role).

Management API biedt `POST /v1/projects/{ref}/database/query/read-only` voor metadata. Het apply-endpoint `POST .../database/migrations` accepteert `query`/`name`, maar geen expliciete bronversie: niet blind inzetten als vervanger die47 historische versies moet behouden. [Read-only API](https://supabase.com/docs/reference/api/v1-read-only-query), [applycontract](https://supabase.com/docs/reference/api/v1-apply-a-migration). Managementtoegang is nog niet beschikbaar; een projectdatabasewachtwoord geeft die rechten niet.

Na apply: historyversies/namen, daadwerkelijk gebruikte47 inputhashes en schema-effecten vastleggen; `supabase_migrations` heeft niet automatisch onze SHA256-kolom. Geen lokale `avaryn_local_meta`-ledger kopiëren. Voer `pilot_postflight.sql` uit: app/Authgegevens nog leeg, private Vitality niet direct toegankelijk, service-only deletion intact en buckets privé. Daarna pas de beperkte echte hosted Auth/RLS/CAS-, media- en lifecycleproeven met apart aangewezen synthetische acceptatie-identiteiten. Lokale PASS-tellingen worden niet hernoemd naar remote PASS.

## Edge, Auth en SMTP afzonderlijk

Deploy uitsluitend `delete-account` en `media-assets` uit het manifest. De canonical teamflow gebruikt bestaande RPCs; de legacy `stable-invitations` Edge wordt niet automatisch extra gepubliceerd. De twee functies hebben `verify_jwt=false` omdat zij zelf de bearer via Auth `getUser` verifiëren. Dat wordt met echte ongeldige/ontbrekende sessies bewezen; geen autorisatie afhankelijk van CORS alleen.

Na AVARYN-managementtoegang zijn de concrete commands per functie `supabase --workdir <staging> functions deploy <functie> --project-ref rvymglpkttlfwhqpmupp --use-api --no-verify-jwt`. Geen `--prune`, geen deploy van alle functies. [Officieel deploycontract](https://supabase.com/docs/reference/cli/supabase-functions-deploy). Leg packageversies en werkelijk deployed bundle vast; media heeft ook gepinde JPEG/WebP-WASM-afhankelijkheden die in de hosted runtime getest moeten worden.

Beide functies vereisen de **nieuwe pilot** `SUPABASE_URL`, public/anon key en server-only service-rolecredential in managed runtime; nooit devkeys overnemen. Zet `AVARYN_ALLOWED_ORIGINS` exact op de door root geverifieerde HTTPS-/native clientorigins. Geen localhostfallback in de pilot. `SUPABASE_PUBLIC_URL` mag bij media wegblijven zodat de echte managed URL wordt gebruikt.

Auth: e-mailbevestiging, refreshrotatie, correcte eigen web-/mobiele callback-/herstel-URLs en echte SMTP-afzender afstemmen. Niet de huidige lokale config.toml met localhost-/oude appcallbacks breed pushen. Met alleen DBtoegang blijven **Edge-deploy, Auth/SMTP en serversecrets BLOCKED op expliciete AVARYN-managementtoegang**. Dat is een andere afhankelijkheid dan databaseconnectiviteit. Het bestaan van een gratis project bewijst geen werkende tester-e-mail of permanente operationele backup.

## Bewijsstand

Offline manifest/staging-/private-inputtests: PASS, zie `tool/productization/backend/preparation-checks.json`. De echte managed databasebootstrap is **PASS**: 47 oorspronkelijke migrationhashes gelijk; 462 functie-, policy- en rechtenprojecties exact gelijk aan de lokale herstelproef; Authusers, appgegevens en Storageobjects leeg. Van de 34 oorspronkelijke niet-extension tabellen blijven 33 rijhashes gelijk; uitsluitend `storage.buckets` krijgt de twee bedoelde private bucketdefinities. Geen automatische fixtureseed of import uit de Mac-preview.

Bewijs: [remote apply](../../.avaryn-local/productization-20260911/evidence/pilot-backend/remote-fresh-20260911T190119Z.json), [echte backup/restore](../../.avaryn-local/productization-20260911/evidence/pilot-backend/baseline-backup-restored-20260911T185247Z.json) en [bestaande gegevens behouden](../../.avaryn-local/productization-20260911/evidence/pilot-backend/baseline-data-preserved-after47.json). Manifest SHA256: `41829a55f5283d349bc285e41d2706a68d87f904f54aa17bb3323e6eb6fda11d`.

Managed Edge, SMTP en echte gebruikersproeven via Auth/HTTP: **NOT TESTED**; benodigde AVARYN-managementtoegang blijft een afzonderlijke afhankelijkheid. Nieuwe migrations na deze 47-baseline vereisen eigen lokaal bewijs, backup en review; deze fresh uitvoerder wordt daarvoor niet opnieuw gebruikt.

## Afzonderlijke vervolgdelta004

De hier beschreven47-bootstrap blijft historisch ongewijzigd. Op11september2026 is daarna uitsluitend tijdzone004 via een aparte incrementaluitvoerder toegevoegd, na verse volledige backup, echte afzonderlijke restore,320 SQLcontroles en root-review/go. Daarmee kwam de pilot op48 migrations; alle47 oude bronhashes en alle124 overige tabelinhouden zijn behouden. Zie [incrementalrunbook](PILOT_TIMEZONE_004_RUNBOOK.md) en [remote004-receipt](../../.avaryn-local/productization-20260911/evidence/pilot-backend/timezone004-apply-20260911T194637Z.json). Gebruik de fresh47-uitvoerder niet opnieuw. Deze delta verandert geen Auth/SMTP/Edge-config.

Actuele vervolgstand: daarna is uitsluitend archived-horse005 afzonderlijk gereviewd, hersteld/gerepeteerd en toegepast. **Development en Pilot staan op49**; alle48 eerdere hashes en overige tabelinhouden zijn behouden. Zie [005-runbook en receipts](ARCHIVED_HORSE_005_RUNBOOK.md). Deze databasegate vervangt geen managed-Edge- of gebruikersacceptatie.
