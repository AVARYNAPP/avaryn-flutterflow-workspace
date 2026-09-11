# AVARYN-omgevingen

| Omgeving | Identiteit | Gebruik |
| --- | --- | --- |
| Development | `avaryn-c010-vitality-20260911-a`; API56801, database56802, Mailpit56804 | Eigen loopbackstack met synthetische accounts. Geen externe e-mailbezorging. |
| Lokale productclient | `http://127.0.0.1:56860/` | Actuele ontwikkelbuild tegen bovenstaande stack. |
| Permanente pilotbackend | `rvymglpkttlfwhqpmupp`, organisatie AVARYN | Behouden testerdata; uitsluitend geteste forward migrations. |
| Nieuwe pilothosting | `appgprj_6aa45546e34481918b42c6609c243630` | Voorbereid op `https://avaryn-c010-pilot.silasdesteur.chatgpt.site`; publicatiestatus staat in het voortgangsverslag. |
| Gewenste alias | `https://alpha.avaryn.eu/` | Pas omschakelen na de publicatiegate. |
| Oude besloten preview | `https://avaryn-c010-preview.silasdesteur.chatgpt.site/` | Historische referentie; geen vervanging voor permanente hosting. |

Staging `ipdovjdtnfslrftvrdrl`, de bestaande FlutterFlow Alpha en productie zijn geen pilotbackend. Er worden geen testgegevens tussen deze omgevingen geïmporteerd.

De permanente Worker gebruikt een vaste pilotbackend en exacte toegestane routes. De host bewaart `SUPABASE_PUBLISHABLE_KEY` en `APP_ORIGIN`; geen waarden in de clientbron of het artifact. Gebruikersbewerkingen blijven aan hun eigen bearer en databaseautorisatie gebonden. De Worker heeft geen service-rolekey nodig.

SMTP gebruikt een afzonderlijke Sending-accesssleutel voor `auth.avaryn.eu`, met afzender `no-reply@auth.avaryn.eu`. Geen algemene mailrouting of MX-wijziging. Een databasebackup bevat niet automatisch Storageobjecten, SMTPsecrets, providerconfiguratie en hostingvariabelen: herstel die onderdelen afzonderlijk vanuit het door AVARYN beheerde geheime herstelregister.

De actuele migrationreceipts, herstelbewijzen, persoonlijke afhankelijkheden en publicatiestatus staan in [V8_PRODUCTIZATION_PROGRESS](../../docs/status/V8_PRODUCTIZATION_PROGRESS.md). Dit document alleen is geen bewijs dat een URL al werkt.
