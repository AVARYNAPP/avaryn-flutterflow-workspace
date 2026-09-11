# Kandidaat, publicatie en herstel

1. Controleer branch, origin en de exacte gewijzigde bestanden. Geen brede staging of wijzigingen aan bestaande stashes. Een ontwikkelcheckpoint is geen menselijke acceptatie.
2. Geef de kandidaat een unieke identiteit in `config/release.json`. Behoud één bron voor web en native. Controleer backendmanifest en benodigde compatibele forward migrations.
3. Voer de relevante tests uit. Voor release: volledige gekozen productsuite, getroffen SQL/HTTP/Edge-/racecontroles, twee gebruikerssessies en visuele vergelijking met de goedgekeurde V8.
4. Bouw vanuit schone dependencies met `npm ci` en `npm run build`. Controleer `version.json`, `build-manifest.json`, fixture-isolatie, secrets en licenties. Leg commit, Node-/npm-versie en artifacthashes vast.
5. Maak een beoordeeld checkpoint op de geverifieerde AVARYN-ontwikkelbranch. Bouw vanuit die commit opnieuw in een schone werkmap. Vergelijk de publieke bestandshashes. Een schone map op dezelfde Mac is geen tweede fysieke machine.

## Web

`scripts/package-pilot-site.mjs --project-id <geverifieerd-pilotproject> --output <nieuwe-stagingmap>` maakt de Worker en exact dezelfde clientassets voor Sites. De publicatiecheckout is afgeleid: pas daar geen functionaliteit aan. Scan de exacte inhoud; commit/push alleen naar de eigen Sites-repository. Gebruik de hostingtool voor bewaren/deployen en controleer de werkelijk gepubliceerde broncommit.

Controleer HTTPS, `/version.json`, `/runtime.json`, nieuwe scriptnaam, login/callback, gedeelde gegevens, media en accountlifecycle. Zelfregistratie met bevestigde e-mail vervangt een vaste testeradressenlijst. Verifieer de gekozen besloten toegang; een gedeelde URL alleen is geen autorisatiemechanisme.

Zet `alpha.avaryn.eu` pas om wanneer de afzonderlijke pilot werkt en herstel is voorbereid. Bewaar het vorige exacte DNSrecord. Wijzig uitsluitend de goedgekeurde alias en noodzakelijke doelverificatie; geen apex/www/MX. Controleer opnieuw nadat eigen ontwikkelservers en tunnels zijn uitgezet.

## Native

Controleer eerst de bestaande store-identiteit/signing; het gevonden ontwikkel-ID is geen bewijs van store-eigendom. Bouw met `AVARYN_PUBLIC_API_BASE=https://<geverifieerde-pilotorigin>/api npm run build`, daarna `npm run native:sync`. De native app bevat eigen webassets en geen externe `server.url`.

Android: JDK21 en de vastgelegde SDK/Gradle-configuratie; accepteer SDKlicenties persoonlijk. Bouw vanuit `android/` eerst `./gradlew assembleDebug`, daarna een release-AAB met de bestaande geverifieerde signingconfiguratie. Verzin of vervang geen releasekey. Test installatie, herstart, back, toetsenbord, foto-/toestemmingsgedrag en APIverkeer op een beschikbaar toestel/emulator.

iOS: gebruik een ondersteunde macOS/Xcodeversie, genereer eerst een simulatorbuild en daarna een archive met geverifieerd AVARYN-team/provisioning. Een simulatorartifact of ongetekend archive is geen TestFlight-installatie. Enrollment, MFA en juridische verklaringen zijn persoonlijke stappen.

Upload uitsluitend naar geautoriseerde testkanalen wanneer signing en accounts beschikbaar zijn. Native updates gaan via die kanalen; geen eigen mechanisme om uitvoerbare code buiten storecontrole te vervangen. Publieke storevrijgave en AVARYN-main-merge vereisen de uiteindelijke gebruikersvrijgave.

## Herstel en compatibiliteit

Behoud het vorige ondersteunde clientartifact. Test het tegen relevante nieuwe databasecontracten vóór promotie. Herstel een frontend alleen naar een versie die nog bij de backend past en geen gerepareerde beveiligingsfout terugbrengt.

Voor een migration: controleer cluster/project, volledige bestandsnaam/checksum, bestaande ledger en gecontroleerde backup. Herstel de backup werkelijk op een afzonderlijke bestemming, oefen daar de nieuwe migration en pas alleen die migration toe. Geen reset of brede batch op een bestaande pilot. Bij onzekere write eerst toestand vaststellen; niet blind opnieuw uitvoeren.

Stop bij onverwachte gegevens-/rechtenverandering. Een database terugzetten over nieuwe testerdata is geen automatische rollback. Bewaar de fouttoestand en kies een beoordeelde forward repair of expliciet goedgekeurd herstel. SMTP/Auth/Storage/hosting vragen hun eigen configuratie- en objectherstel.
