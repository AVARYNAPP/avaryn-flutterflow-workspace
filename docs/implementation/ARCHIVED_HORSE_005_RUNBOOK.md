# Archived-horse 005: gecontroleerde promotie

Stand 11 september 2026: **005 toegepast, development en managed Pilot staan op49 migraties.** Beide toepassingen volgden afzonderlijke rootreview en de normale toolreview. De eerdere48bronhashes bleven gelijk. Geen Auth-, SMTP-, Edge-, hosting- of Storageconfiguratie hoorde bij deze handeling.

Alleen `supabase/migrations/202609110005_c010_archived_horse_authority_transfer.sql`, SHA256 `755aa06c7d613aa887ed8f9c69ce9afe68560c45e00bb19d7955ef85677f98bc`, wordt toegevoegd. De eerdere48migraties, waaronder004, worden niet herhaald of aangepast. De migratie voegt een actorloos eigenarchiefoverzicht toe en behoudt de bestaande tweefasige overdracht, archiefstatus, historie en autorisatie. Er komen geen tabelrechten of operationele grants bij.

| Doel | Echte identiteit | Gecontroleerde voorbereiding |
|---|---|---|
| Development | `avaryn-c010-vitality-20260911-a`; API56801, PostgreSQL56802, uitsluitend loopback; cluster `7684330901039525928` | `horse005-dev-prepare-20260911T202103Z` |
| AVARYN C010 Pilot | `rvymglpkttlfwhqpmupp`, organisatie `ufvwcbrvwbqmejwraend`; projectgebonden sessionpooler, TLSverify-full; cluster `7678069749886157684` | `horse005-pilot-prepare-20260911T202109Z` |

De prepared directories staan onder `.avaryn-local/productization-20260911/private/pilot-backend/` (0700). Iedere backup is0600 en daadwerkelijk teruggezet in een eigen nieuwe lokale database. Er zijn geen fixtures uit development naar Pilot gekopieerd.

| Bewijs | Development | Pilot |
|---|---|---|
| Volledige backup | 2.703.452 bytes | 2.542.014 bytes |
| BackupSHA256 | `0fd8c7a6cb2942874c85d056cd401ef7cbc99b3c9d8a384bb261ba51637c9358` | `901fdb1c93ce770e06824b49d730614d61bb213baedbd460fba221ff87e1a602` |
| Herstelde bestaande tabellen |136|125|
| Na rehearsal ongewijzigde tabellen, exclusief ledger |135|124|
| SQL |48 nieuwe pgTAPchecks plus2 bestaande compoundtests PASS|Dezelfde PASS|

De echte restorekopieën heten `avaryn_dev005_restore_20260911t201211z` en `avaryn_pilot005_restore_20260911t201247z`. Hier is005 één keer geoefend; testfixtures zijn teruggedraaid. De originele dumps en eerdere receipts blijven behouden. Ook de positieve ledgerprologue en de weigering bij een afwijkende hash zijn als exact `postgres` in een rollbacktransactie getest. De aparte tweesessieraces van generator_research zijn vastgelegd in `evidence/archived-horse-transfer-races.json`; ze zijn geen managed-HTTPproef.

De eerste devapply stopte vóór migratieDDL: de bestaande lokale ledger staat postgres SELECT/INSERT toe, niet de sterkere tablelock. Alle136tabellen, schema/ACL en48ledger bleven gelijk. De gecorrigeerde devguard gebruikt een transactionele advisorylock voor deze gecoördineerde executor, dezelfde ledgervergelijking en unieke versionkey. Andere schrijvers moeten stilblijven. De Pilotguard behoudt zijn toegestane tablelock.

De eerste Pilot-lifecyclecompound verwachtte ten onrechte universeel service_role SELECT op historische actorkolommen. De minimale testcorrectie bewaart nu de **werkelijk bestaande** serviceprivileges vóór en na beide lifecyclefasen. De anon/auth-weigeringen, echte verboden SELECTs en RLS-controles bleven identiek. Er zijn geen servicegrants toegevoegd. De Edges gebruiken voor deze appdata bestaande SECURITY DEFINER-RPC's. Met dezelfde backups en restorekopieën zijn de gecorrigeerde controles geslaagd.

## Uitgevoerde commando's en herhaalgedrag

```sh
python3 tool/productization/backend/archived_horse_increment.py --target dev --mode apply --prepared .avaryn-local/productization-20260911/private/pilot-backend/horse005-dev-prepare-20260911T202103Z --root-reviewed --writes-paused
python3 tool/productization/backend/archived_horse_increment.py --target pilot --mode apply --prepared .avaryn-local/productization-20260911/private/pilot-backend/horse005-pilot-prepare-20260911T202109Z --root-reviewed --writes-paused
```

Deze commando's zijn achtereenvolgens uitgevoerd; herhaal toepassing niet. Elke afwijking in doel, bron,48ledger, huidige rijen, effectieve ACL, backups of prepared bewijs stopt vóór toepassing. Bij reeds identieke49 volgt uitsluitend verificatie. De enige persistente tabelwijziging was de eigen ledgerregel; postchecks vergeleken alle bestaande rijen en het gerepeteerde catalogusresultaat. Geen automatische retry of restore.

De [devreceipt](../../.avaryn-local/productization-20260911/evidence/pilot-backend/horse005-dev-apply-20260911T202329Z.json) bewijst135 ongewijzigde overige tabellen. De [Pilotreceipt](../../.avaryn-local/productization-20260911/evidence/pilot-backend/horse005-pilot-apply-20260911T202403Z.json) bewijst124. Beide catalogi, bestaande functie-ACL, tabel-ACL en RLS matchen hun herstelproef. Alle bestaande account-, paard-, stal- en overige gegevens zijn behouden; geen fixtures toegevoegd tijdens apply.

ExecutorSHA256: `31f6e01fe7806a41579d5cd3eb521419ce2c17074970669b324124eba3bccc0e`. PlanSHA256: `98ed7431d0f20a03e4511a8be451d7406d780d7398f9694b271671019f848a54`. De9offline-executorguards zijn PASS. Receipts en privacystopdiagnose staan onder `.avaryn-local/productization-20260911/evidence/pilot-backend/`.

Herstel: elke private prepare-run bevat `RECOVERY.md`, de volledige backupreferentie en de vier oude functiedefinities. Een defect na commit vergt een beoordeelde forward-only correctie. Herstel nooit blind over nieuwe gebruikersdata en verwijder geen ledgerhistorie. Een databasearchive omvat geen externe Auth-/SMTP-/Edgeconfiguratie of Storagebytes.

De persoonlijke/beheerafhankelijkheid voor managed Edge-deployment staat los van deze databasegate: deployment en echte HTTPacceptatie vereisen expliciete AVARYN-managementtoegang. De projectdatabaseverbinding geeft die niet; de eerder uitgesloten globale CLIcredential mag niet worden gebruikt. Root coördineert de twee benodigde functies en Auth/SMTP. Deze uitvoering leverde geen managed-Edge- of menselijke UI-acceptatieclaim.
