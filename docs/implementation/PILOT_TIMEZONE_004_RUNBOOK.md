# AVARYN Pilot — uitsluitend tijdzone004 (47 → 48)

Dit document bewaart de uitgevoerde004-promotie. Inmiddels staan development en Pilot na de afzonderlijke [005-promotie](ARCHIVED_HORSE_005_RUNBOOK.md) op49; voer deze004-executor daarvoor niet opnieuw uit.

Doel: `rvymglpkttlfwhqpmupp`, organisatie AVARYN `ufvwcbrvwbqmejwraend`, werkelijk PostgreSQL-cluster `7678069749886157684`, database/rol `postgres` (geen superuser). Alleen de bestaande projectprivate sessionpoolerverbinding met TLS `verify-full` en gepinde Supabase-CA. Geen globale CLI-login, nieuwe credentials of ander project.

De enige nieuwe migration is `202609110004_c010_account_calendar_timezone.sql`, SHA256 `a9e47de0b01bb8fd407e354b1ea1a148d89455a53e79c70561aa13f6365b08bd`. De oorspronkelijke 47 migraties en het historische manifest blijven ongewijzigd, manifestdigest `41829a55f5283d349bc285e41d2706a68d87f904f54aa17bb3323e6eb6fda11d`. De oude fresh47-uitvoerder wordt niet opnieuw aangeroepen.

`tool/productization/backend/pilot-timezone004-plan.json` legt alle 47 historische versie-/naam-/bronhashes, de ene delta en de zes testbronhashes vast. `pilot_timezone_increment.py` weigert iedere afwijking. Geen andere migrations, data, rollen/grants, Auth/SMTP/Edge-config of Storagebytes worden gewijzigd. De SQL vervangt negen bestaande functies en voegt één private helper toe; bestaande signatures/ACL/RLS blijven behouden.

## Uitvoering in aparte fasen

1. Optioneel uitsluitend lezen:

   ```sh
   python3 -B tool/productization/backend/pilot_timezone_increment.py --mode preflight
   ```

2. Na bronreview: verse remote backup lezen, echt lokaal herstellen en repeteren:

   ```sh
   python3 -B tool/productization/backend/pilot_timezone_increment.py --mode prepare
   ```

   Deze fase schrijft niets op de pilot. De uitvoerder controleert echte clusteridentiteit, client-TLS en exact47 geschiedenis, maakt een volledige custom `pg_dump` (0600), valideert listing/decode en controleert opnieuw alle tabelrijhashes. Daarna wordt één **nieuwe** database `avaryn_pilot004_restore_<UTC>` op het expliciet eigen loopbackcluster56802 aangemaakt. De echte restore moet alle oorspronkelijke tabellen, rijhashes, history, functie-/policycatalogus en tabelrechten matchen. Uitsluitend die kopie krijgt004+standaardhistory atomair, gevolgd door105 nieuwe plus215 bestaande rollbackcontroles. De bestaande ontwikkelgebruikersdatabase blijft ongemoeid.

   De vergelijking van rechten gebruikt gesorteerde `aclexplode(coalesce(acl,acldefault(...)))`-tuples, inclusief grantor, ontvanger, privilege en grantoptie. Dit ondervangt uitsluitend de equivalente representaties die `pg_dump` kan herstellen: expliciete eigenaarsrechten versus NULL/default en een andere arrayvolgorde. Geen werkelijk privilege wordt genegeerd.

   De eerste prepare stopte vóór enige migrationapply op deze representatieafwijking; de 125 tabelinhouden en47 historyregels waren gelijk. De bestaande backup en nog ongemigreerde herstelkopie kunnen expliciet worden hergebruikt:

   ```sh
   python3 -B tool/productization/backend/pilot_timezone_increment.py --mode prepare \
     --resume-restore .avaryn-local/productization-20260911/private/pilot-backend/timezone004-prepare-20260911T193748Z
   ```

   Resume vereist een vooraf vastgelegde private backup-/snapshotpin, dezelfde daadwerkelijke lokale identiteit en exact dezelfde actuele remote data, history én oorspronkelijke ruwe ACL-representatie. Daarna moet de herstelde kopie de volledige semantische rechtenvergelijking doorstaan. Er wordt geen database opnieuw aangemaakt of gereset, geen backup gedupliceerd en geen remote migration uitgevoerd. De nieuwe preparedirectory bewaart een gecontroleerde verwijzing naar de oorspronkelijke backup.

3. Pas na afzonderlijk root-go, passende prepare-PASS en afgesproken schrijfpauze:

   ```sh
   python3 -B tool/productization/backend/pilot_timezone_increment.py --mode apply \
     --prepared .avaryn-local/productization-20260911/private/pilot-backend/timezone004-prepare-<UTC> \
     --root-reviewed --writes-paused
   ```

   Deze flags leggen de coördinatie vast; zij vervangen geen daadwerkelijke toestemming of normale toolreview. De bron, script-/planhash, complete backup, testreceipt en actuele pilotinhoud moeten opnieuw exact passen. Alleen004 en zijn standaard `supabase_migrations.schema_migrations`-rij worden samen gecommit. Een korte history-lock sluit een gelijktijdige migrationapply uit. Functionele gegevens worden niet gelockt of herschreven; gedurende backup/apply moeten externe gebruikers-/beheerwrites stil zijn. Elke tussentijdse inhoudsverandering maakt de voorbereide snapshot ongeldig.

   Postcommit moeten de oorspronkelijke47 historyhashes gelijk blijven, regel48 exact004 bevatten, alle bestaande tabelinhouden behalve de ene historytabel gelijk blijven en de volledige functie-/policycatalogus exact overeenkomen met de herstelde lokale proef. Een exact reeds toegepaste48 leidt met dezelfde prepared catalogus uitsluitend tot verificatie, geen tweede apply.

## Fout en herstel

Afwijkende, gedeeltelijke of onbekende geschiedenis: stoppen. Fout of onzekere verbindingsuitkomst: geen automatische retry, historyrepair of restore. Eerst werkelijke history/bron lezen. Een fout tijdens de transactie rolt004 plus history samen terug; bij een ambigue uitkomst wordt dit niet aangenomen zonder controle. Een postcommit-verificatiefout betekent dat de schemawijziging mogelijk al bestaat: bewijs bewaren en gericht onderzoeken.

Backups, restorelogs, volledige private snapshots en receipts staan onder `.avaryn-local/productization-20260911/private/pilot-backend/timezone004-*` (0700/0600); veilige samenvattingen onder `evidence/pilot-backend/timezone004-*`. De volledige backup kan opnieuw naar een afzonderlijke gecontroleerde bestemming worden hersteld. Nooit automatisch over latere testerdata heen. Functionele forward recovery heeft de voorkeur boven verwijderen van historyregels.

Een databasedump bevat geen Storagebytes of hosted Auth/SMTP/provider/Edge-instellingen. Deze migration raakt die niet. Ze bewijst evenmin menselijke acceptatie of managed Auth/Edge-HTTPgedrag.

## Permanente lokale suite

`tool/productization/backend/verify_timezone_local.py` registreert de nieuwe `c010_account_calendar_timezone`-suite plus de vijf geraakte regressies. De runner ondersteunt uitsluitend de expliciet eigen vitalitydevstack, vereist dat004 al is toegepast en voert tests met rollback uit. Dezelfde lijst wordt in de prepare-herstelproef gebruikt. De oude algemene repair20-runner blijft onveranderd.

Offline guardtests:

```sh
python3 -B -m unittest discover -s tool/productization/backend -p 'test_pilot_timezone_increment.py'
```

De voorbereiding is werkelijk geslaagd op 11 september 2026: 125 oorspronkelijke tabelinhouden en 47 historyregels gelijk, volledige effectieve ACL/policycatalogus gelijk, 320 controles uit zes suites PASS. De bestaande backup en herstelkopie zijn hergebruikt. Backup SHA256: `57811e675e4b26e49849bce138ed4ea4b0eb4d8f80eb4cb86c0dca6d5a51e250` (2.535.356 bytes, 0600).

Het exacte voorbereide pad is `.avaryn-local/productization-20260911/private/pilot-backend/timezone004-prepare-20260911T194402Z`. Executor SHA256: `efcb5c32e487a86e8dde094e3729de08ccb78b30b8d86cfb020e31bc519949fd`. [Prepare-receipt](../../.avaryn-local/productization-20260911/evidence/pilot-backend/timezone004-prepare-20260911T194402Z.json), [15 offline guardtests](../../.avaryn-local/productization-20260911/evidence/pilot-backend/timezone004-tooling-review-v2.json), [eerste veilige stop](../../.avaryn-local/productization-20260911/evidence/pilot-backend/timezone004-initial-prepare-stop.json).

Na afzonderlijk root-go is uitsluitend004 daadwerkelijk toegepast. De pilot staat op48: alle47 eerdere migrationhashes zijn gelijk, alle124 overige tabelinhouden behouden en de volledige functie-/policycatalogus matcht de lokale herstelproef. Tabel-ACL/RLS zijn ongewijzigd. [Remote004-receipt](../../.avaryn-local/productization-20260911/evidence/pilot-backend/timezone004-apply-20260911T194637Z.json). Er zijn daarna geen verdere DBwrites uitgevoerd. Dit is geen bewijs van menselijke acceptatie of managed Auth/Edge-HTTPgedrag.
