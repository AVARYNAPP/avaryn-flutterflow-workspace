# Operationele Pilotbackup — 12 september 2026

Alleen `rvymglpkttlfwhqpmupp`, actuele49 migrations. De historische lege-pre47-uitvoerder blijft ongewijzigd en is geen operationele backupopdracht.

## Vastgelegde opname

De gebruiker gaf expliciet toestemming voor een volledige huidige databasebackup en een echte restore in één nieuwe geïsoleerde lokale database. Na een korte gecoördineerde pauze van onze eigen invoer is tussen **15:43:05–15:43:52 UTC** een volledige customarchive gemaakt. Alle125 tabelrijhashen,49 migrationhashes, owners, RLS en effectieve tabel-/kolomrechten waren gelijk vóór/na en in de werkelijke lokale restore. Geen remote restore of schema-/datawijziging; bestaande developmentdatabase behouden. De vergelijking bewijst inhoudsbehoud, geen technisch afgedwongen globale writepauze.

- Private run: `.avaryn-local/productization-20260911/private/pilot-backend/operational49-20260912T154258Z/`.
- Archive `pilot49-full.dump`:2.569.737bytes, mode0600, SHA256 `d45d50bbb35bd4e405c4b170ed239dd6515b9172fcf39c98dcc9adec85d1e43d`.
- Werkelijke aparte restore: `avaryn_pilot49_backup_20260912t154258z` op de bestaande eigen lokale devcluster; geen app-API wijst hiernaar.
- Bewijs: `evidence/pilot-backend/operational49-20260912T154258Z.json` onder dezelfde productization-run.

De snapshot bevatte precies2 private PNGobjecten. Die zijn via de gewone synthetische eigenaar M en bestaande `canonical_download`-autorisatie gelezen: **2.755.929bytes, beide SHA256’s en byteaantallen exact gelijk aan de canonieke variantmetadata**. Alle snapshotobjecten zijn hiermee afgedekt. Bestanden en hun exacte bucket-/padmapping staan0600 in `media-bytes/`; signed URLs en tokens zijn niet bewaard. Geen upload of Storage-restore is uitgevoerd. Bewijs: `operational49-20260912T154258Z-storage.json` in dezelfde evidence-map. Latere uploads/invoer vallen buiten deze opname.

## Uitvoeren en herstellen

`python3 tool/productization/backend/backup_operational_pilot.py --root-reviewed --writes-paused` vereist vooraf gecontroleerde doelidentiteit, bron49 en een gecoördineerd eigen writevenster. De helper bewaart een nieuwe exclusieve0600archive, valideert listing/decode, weigert inhoudsdrift en herstelt alleen een nieuwe unieke lokale database. Er is geen DROP/reset, migrationapply of retryoptie. Een mislukte poging blijft behouden.8 offline guards PASS.

`backup_operational_media.py --backup-run <geverifieerde-private-run> --root-reviewed` werkt alleen wanneer alle snapshotobjecten via de vaste synthetische M-fixture en actuele normale eigenaarautorisatie bereikbaar zijn. Andere, gearchiveerde of onbekende objecten blokkeren volledige dekking; geen servicecredential of persoonlijke sessie als omweg.13 actuele guards PASS. De echte download gebruikte de voorafgaande bron met dezelfde M-selectie; daarna is uitsluitend een persoonlijke mailboxprefix vervangen door een generieke plusaliascontrole. De eerste lokale queryaliasfout is afzonderlijk privé bewaard; geen productcorrectie was nodig.

Gebruik bij werkelijk herstel de private `restore-target.json`, archivehash, rijhashen en `media-bytes/manifest.json`. Herstel nooit automatisch over nieuwe testerdata. Een live herstel vereist een afzonderlijk beoordeelde bestemming/cutover, intakepauze en behoud van latere writes. Mediabytes moeten dan via een bevoegde Storage-restore terug naar exact hun vastgelegde bucket/pad; deze uploadstap is niet geoefend of uitgevoerd.

## Exacte configuratiegrens

De archive bevat databasegegevens, geen hosted Auth-/SMTP-/provider-/Edge-/hostingconfiguratie of platformsecrets. Bestaande runtime- en SMTPcredentialbestanden staan al privé; deze run heeft geen actuele volledige managementconfigexport gemaakt. Bron49, de twee Edgebronnen en Workerbron zijn herkomstbewijs, geen herstelde managed configuratie. Behoud daarom de bestaande geverifieerde dashboard-/deployinstellingen en private credentialbronnen afzonderlijk. Geen complete platform-disaster-recoveryclaim. Alle backupdata blijven genegeerd door Git en zijn niet naar Git/Sites geüpload.
