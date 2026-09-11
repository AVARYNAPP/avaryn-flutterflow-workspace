# Overdracht van primair beheer voor gearchiveerde paarden

Migratie: `202609110005_c010_archived_horse_authority_transfer.sql`.

Een gearchiveerd paard behoudt zijn verplichte primaire verantwoordelijkheid. Die verantwoordelijkheid kan nu via dezelfde expliciete aanbieding en acceptatie worden overgedragen. Het paard wordt niet heropend; profielvelden, archieftijd, juridische eigendom, relaties en bestaande audit blijven behouden. Accountverwijdering blijft weigeren zolang iemand nog primair verantwoordelijk is.

## Clientcontract

Nieuw, zonder actorparameter:

```text
list_c010_my_archived_horses()
  → rows: horse_id UUID, display_name TEXT, archived_at TIMESTAMPTZ,
          row_version BIGINT, access_version BIGINT, authority_version BIGINT,
          pending_transfer JSONB | null

pending_transfer:
  id, recipient_name, status, expires_at, row_version
```

Alleen het actieve eigen profiel krijgt de gearchiveerde paarden waarvoor het op dat moment primair verantwoordelijk is. De minimale pendingmetadata bevat geen token, e-mail, ontvangerprofiel-ID of Auth-ID. Alleen `authenticated` krijgt EXECUTE; geen directe tabeltoegang wordt toegevoegd.

De bestaande RPC-ABI blijft gelijk:

| Stap | Bestaande RPC en parameters | Resultaat |
|---|---|---|
| Aanbieden | `initiate_horse_authority_transfer_by_email(p_horse_id, p_recipient_email, p_correlation_id)` | `transfer_id, transfer_token, expires_at, row_version, applied` |
| Controleren | `preview_horse_authority_transfer(p_transfer_token)` | Bestaande beperkte preview voor de bedoelde ontvanger |
| Accepteren/weigeren | `respond_horse_authority_transfer(p_transfer_token, p_action, p_correlation_id)` | `transfer_id, row_version, status, authority_version, applied` |
| Intrekken | `revoke_horse_authority_transfer(p_transfer_id, p_expected_row_version, p_correlation_id)` | `row_version, status, applied` |

De onderliggende `initiate_horse_authority_transfer(p_horse_id, p_recipient_profile_id, p_correlation_id)` blijft eveneens bestaan. De e-mailwrapper controleert eigen primaire scope vóór ontvangerlookup. De client toont eenmalige tokens alleen in het bestaande bewaakte deelvenster. Aanbieden is nog geen geaccepteerde overdracht.

Een herhaalde creatie met dezelfde correlation-ID retourneert de bestaande aanvraag zonder opnieuw een token uit te geven. Voor archieven wordt dezelfde ID met een andere ontvanger of ander paard geweigerd (`REQUEST_ID_REUSED`). Een terminale token kan niet opnieuw accepteren. Herhaald intrekken retourneert de bestaande terminale status zonder tweede mutatie. Archief-CAS-conflicten gebruiken `PT409`; ontbrekende acceptatiekeuze wordt nooit als toestemming behandeld.

## Bevoegdheden en races

**Paardenarchief is niet gelijk aan stalarchief.** De bestaande `private.c003c_profile_has_horse_permission` kent een actieve primary ook voor een gearchiveerd paard zijn normale canonical primary-capabilities toe. Migratie 005 verandert die helper niet. De geaccepteerde opvolger krijgt dezelfde bestaande primaire positie; er worden geen aanvullende grants, delegaties, memberships of rollen aangemaakt. De tests vergelijken alle acht primary-capabilities vóór en na overdracht. Een claim dat de opvolger uitsluitend een administratieve archiefverwijzing zonder bestaande paardrechten krijgt, zou onjuist zijn.

Initiatie en acceptatie vergrendelen de betrokken profielrijen gesorteerd vóór de paard- en transferrijen. Na wachten wordt de actor herlezen. Voor archived acceptatie worden beide actieve profielen expliciet gecontroleerd, omdat de algemene live-targettrigger gearchiveerde rijen overslaat. De bestaande recipient-, pending-, expiry-, authority-version- en auditregels blijven van kracht.

Twee echte gelijktijdige transacties zijn in een nieuwe eigen lokale scratch-database getest: acceptatie eerst blokkeert daarna verwijdering van de opvolger; verwijderingsvoorbereiding eerst trekt de transfer in en voorkomt acceptatie. Het paard blijft in beide gevallen gearchiveerd en er ontstaan geen grants.

## Bewijs en status

- **48/48 SQL-asserties PASS**, inclusief negatieve scope/e-mailgevallen, ontbrekende actie, replay, intrekken, expiry/CAS, actieve-transfercompatibiliteit, behoud van velden/relaties/audit en verwijdering van de voormalige primary.
- **2/2 echte races PASS**; de tweede transactie wachtte aantoonbaar circa 0,82 seconde op de eerste. Beide scratch-doelen, inclusief de eerste harnasfoutpoging, zijn gecontroleerd verwijderd.
- Hoofddev: exact container/cluster/volume en uitsluitend loopback 56802 geverifieerd. Migratie + SQL-suite draaiden in één rollbacktransactie. De 48-ledger, vijf betrokken functiedefinities en eigen fixturecount waren vóór/na gelijk. Er is geen volledige database-bytevergelijking geclaimd en geen remote apply uitgevoerd.

Reproduceerbaar vanaf de repositoryroot:

```sh
python3 tool/productization/verify_archived_horse_transfer.py
python3 tool/productization/verify_archived_horse_races.py
```

De scripts weigeren andere container-, cluster-, volume- of portidentiteiten. Het tweede script maakt uitsluitend een nieuwe gemarkeerde scratch-database met een schema-only kopie, nieuwe HMAC en eigen `.invalid` fixtures; bestaande gebruikerdata en sleutels worden niet gekopieerd.

Bewijs: [rollback](../../.avaryn-local/productization-20260911/evidence/archived-horse-transfer-rollback.json), [races](../../.avaryn-local/productization-20260911/evidence/archived-horse-transfer-races.json), [bronfreeze](../../.avaryn-local/productization-20260911/evidence/archived-horse-transfer-freeze.json).

**Nog afzonderlijk:** root integreert de bestaande accountcontroller en plant eventuele dev/pilot-migratie met backup- en hashcontrole. Legacy-identiteitsmapping, Apple-intrekking en de andere deletionblockers zijn niet gewijzigd of als opgelost geteld.
