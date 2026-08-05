# C-005 — Back-up-, reset- en seedrunbook

## Status en harde grens

- Status: **C-005 — Implemented locally – awaiting next gate**.
- Dit runbook maakt een latere stagingreset technisch gereed.
- Het autoriseert of voert in C-005 geen stagingreset, remote migration, seed,
  deployment, FlutterFlow-koppeling of productieactie uit.
- C-006 is niet gestart.

De expliciete C-005-opdracht vervangt voor deze run de oudere contractlabel
“C-005 Rider Performance”. Dit runbook implementeert uitsluitend backup,
restorebewijs, resetvoorbereiding, migrationvolgorde, fictieve v2-seed en
security-smokes.

## Omgevingsallowlist

De hulpmiddelen accepteren exact één target:

| Veld | Vereiste waarde |
| --- | --- |
| environment | `staging` |
| Supabase project ref | `ipdovjdtnfslrftvrdrl` |
| databasehost | `db.ipdovjdtnfslrftvrdrl.supabase.co` |
| poort / database / user | `5432` / `postgres` / `postgres` |
| TLS | `PGSSLMODE=verify-full` |

Productie, een onbekende project-ref, pooler/alias, afwijkende database of
ontbrekend TLS-bewijs wordt vóór ieder commando geweigerd. Een databasewachtwoord
komt uitsluitend kortstondig in `PGPASSWORD`; nooit in argumenten, bestanden,
shellhistory, logs, chat of Git. De full dump wordt tijdens streaming versleuteld
met AES-256 en PBKDF2; een passphrase van minimaal 32 tekens komt uitsluitend uit
`AVARYN_C005_BACKUP_PASSPHRASE`. Gebruik een beveiligde operatorhost en wis beide
omgevingswaarden na afloop.

Voor iedere echte actie moet `AVARYN_C005_RELEASE_COMMIT` exact gelijk zijn aan
de schone uitgecheckte HEAD. De goedgekeurde C-003-eindcommit moet een ancestor
zijn. Backups en bewijs staan buiten de repository in een directory met mode
`0700`.

## Voorwaarden vóór enige reset

Alle onderstaande voorwaarden zijn cumulatief. Ontbreekt er één, dan stopt de
procedure:

1. afzonderlijke schriftelijke approval voor `staging-backup` en later een
   tweede approval voor `staging-reset`, beide volgens
   `docs/templates/c005-staging-approval.txt`;
2. schema-only én full custom-format databasebackup;
3. redacted Auth-configuratiebewijs zonder tokens, keys, hashes of e-mails;
4. afzonderlijk Storage-backup-/exportbewijs inclusief objectcount en locatie,
   zonder signed URLs of credentials;
5. bewijs van een vers, provider-managed stagingherstelpunt voor de managed
   Auth/Storage/Vault/Realtime-laag;
6. geldige SHA-256-manifesten;
7. geslaagde restore van de portable full application dump in een disposable
   lokale database;
8. vastgepinde releasecommit en pre-reset migrationversie;
9. write freeze en benoemde operator/incidentleider;
10. afzonderlijke expliciete resettoestemming.

Een logisch databasebestand is geen backup van Storage-objectbytes. De reset
mag dus niet starten met alleen `storage.objects`-metadata; platform-/object-
backupbewijs is verplicht. De portable logische dumps sluiten de Supabase-
managed schema's `vault` en `realtime` expliciet uit: vaultsecrets komen niet in
het operatorbestand en managed realtimefuncties zijn niet portable. Een vers
provider-managed herstelpunt is daarom aanvullend verplicht. Auth-provider-,
redirect- en mailconfiguratie wordt redacted vastgelegd, niet uit secrets
gereconstrueerd.

## Veilige commando-opbouw

Exporteer alleen op de beveiligde operatorhost:

```sh
export AVARYN_C005_ENVIRONMENT=staging
export AVARYN_C005_PROJECT_REF=ipdovjdtnfslrftvrdrl
export AVARYN_C005_DB_HOST=db.ipdovjdtnfslrftvrdrl.supabase.co
export AVARYN_C005_DB_PORT=5432
export AVARYN_C005_DB_NAME=postgres
export AVARYN_C005_DB_USER=postgres
export AVARYN_C005_RELEASE_COMMIT='<approved-full-git-sha>'
export PGSSLMODE=verify-full
export PGPASSWORD='<read-from-approved-secret-store>'
export AVARYN_C005_BACKUP_PASSPHRASE='<different-secret-from-approved-store>'
```

Targetguards kunnen zonder netwerk of credentials worden bekeken:

```sh
tool/c005_backup_staging.sh --dry-run \
  --evidence-dir /absolute/private/path/c005-backup
tool/c005_reset_staging.sh --dry-run
```

### 1. Backup

Na afzonderlijke backupapproval:

```sh
tool/c005_backup_staging.sh --execute \
  --evidence-dir /absolute/private/path/c005-backup \
  --approval-file /absolute/private/path/backup-approval.txt \
  --auth-config-evidence /absolute/private/path/auth-config-redacted.txt \
  --storage-backup-evidence /absolute/private/path/storage-backup-redacted.txt \
  --platform-backup-evidence /absolute/private/path/platform-backup-redacted.txt \
  --confirm BACKUP-STAGING-ipdovjdtnfslrftvrdrl
```

Het script maakt `schema-only.dump`, de versleutelde portable full application
dump `full.dump.enc`, `SHA256SUMS`, `manifest.txt` en `BACKUP_COMPLETE`. Het kopieert
Auth-/Storage-/platformbewijs niet, maar bindt hun hashes aan het manifest.

### 2. Restore-oefening

Start de bestaande lokale Supabase-stack. De restoretool bewijst de exacte
lokale Dockercontext en containerlabel, maakt een willekeurige database met
prefix `avaryn_c005_restore_`, herstelt de full dump, controleert de vier
kernobjecten en verwijdert de disposable database altijd:

```sh
tool/c005_verify_restore_local.sh \
  --backup-dir /absolute/private/path/c005-backup \
  --confirm-local-restore
```

Alleen een nieuw `restore-verification.txt` met `result=PASS` ontsluit de
resettool. Een schema-only parse of succesvolle dump is geen restorebewijs.

### 3. Afzonderlijk geautoriseerde stagingreset

Pas na de tweede approval en write freeze:

```sh
tool/c005_reset_staging.sh --execute \
  --backup-dir /absolute/private/path/c005-backup \
  --approval-file /absolute/private/path/reset-approval.txt \
  --confirm RESET-STAGING-ipdovjdtnfslrftvrdrl
```

De tool vergelijkt eerst de live migrationversie met de approval, bindt project,
omgeving, releasecommit, migrationversie en restorehash aan hetzelfde
backupmanifest, en gebruikt daarna uitsluitend de expliciete passwordloze
direct-host-URL met `PGPASSWORD` uit de omgeving. Er wordt nooit `supabase link`
of `--linked` gebruikt.

De reset past migrations in lexicografische timestampvolgorde toe, zonder
automatische seed. Daarna wordt exact
`supabase/seeds/c005_account_foundation_v2.sql` uitgevoerd. Deze seed:

- accepteert alleen `staging` of de geïsoleerde `local-drill`;
- vereist een schoon target en gebruikt vaste correlation IDs;
- maakt uitsluitend geblokkeerde `example.invalid`-Auth-fixtures;
- levert personal-only, authority, collaborator en outsider scopes;
- levert twee organizationtypen, twee horses, een horse zonder residency,
  meervoudige ownership, expliciete grant, residency en een wederzijds
  bevestigde organizationlink zonder impliciete grant.

De post-reset smoke bewijst aantallen, personal-onlyisolatie, exact één actieve
residency, expliciete grant, geen linktoegang, outsider-RLS, geweigerde directe
DML en auditbewijs. Tot slot moet de live migrationversie exact de laatste
lokale migration zijn.

## Stop- en rollbackvoorwaarden

Stop onmiddellijk en houd staging gesloten bij targetafwijking, ontbrekende
approval, gewijzigde HEAD, dirty tree, checksumverschil, mislukte restore,
veranderde pre-reset migration, migration-/seed-/smokefout, RLS/ACL-afwijking,
onverwachte data of enig mogelijk secretlek.

Het resetscript voert bewust geen automatische restore uit. Automatische
rollback kan een gedeeltelijke situatie verbergen of een nieuwere
securitymigratie terugdraaien. Na een fout:

1. behoud write freeze en bewijs;
2. classificeer het incident;
3. kies een gerichte forward fix of afzonderlijk goedgekeurd platformherstel;
4. herstel eerst op een disposable kopie;
5. herhaal migration-, RLS/ACL-, seed- en security-smokes;
6. heropen staging pas na onafhankelijke controle.

Productie is geen geldig target voor deze tooling of dit runbook.

## Lokale runbookverificatie

- script syntax, migrationvolgorde, targetallowlist en secretscan: **PASS**;
- productie, onbekende project-ref en afwijkende databasehost: **geblokkeerd**;
- fictieve v2-seed en post-seed security-smoke op fresh local: **PASS**;
- tweede seedrun en productie-seedomgeving: **fail-closed geblokkeerd**;
- encrypted full-dump restore in een disposable lokale database: **PASS**;
- verkeerde restorepassphrase en achterblijvende restore-database: **geblokkeerd**.

Er is voor deze verificatie niets op staging of een andere remote omgeving
uitgevoerd.
