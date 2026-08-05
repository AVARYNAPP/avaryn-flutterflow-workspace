# C-004 — Account Foundation v2

## Status en bronmapping

- Status: **C-004 — Implemented locally – awaiting next gate**.
- Datum: `2026-08-05`.
- Branch: `implementation/account-foundation-v2-c004-c005`.
- Goedgekeurde basis: C-003 eindcommit
  `4fee78c8b24099cf4eac254fd083f062827f1ee3`.

De bindende C-004-opdracht noemt Account Foundation v2. Het oudere technische
contract gebruikt hetzelfde nummer nog voor Work items/Today. De latere,
expliciete opdracht vervangt die nummering voor deze run. Er is daarom geen
Today- of Rider Performance-module gebouwd en C-006 is niet gestart.

## Reeds volledig afgedekt door C-003

De goedgekeurde C-003A–F-implementatie levert de volledige Account Foundation:

- duurzame personal profiles met server-derived actors en fail-closed status;
- organizations, memberships, rollen en expliciete permissions;
- canonical horses met scalar primary authority, ownership, relaties,
  residency en wederzijds bevestigde organizationlinks zonder impliciete
  toegang;
- expliciete grants, invitations en atomische authoritytransfers;
- RLS, minimale ACL/EXECUTE-rechten en RPC-only kritieke mutaties;
- `SECURITY DEFINER` met lege `search_path`, typed RPC-resultaten,
  idempotency, locks, optimistic row versions en access-versionrotatie;
- append-only allowlisted audit inclusief bescherming tegen `TRUNCATE`;
- concurrency-, spoofing-, cross-tenant-, service-role- en fresh-buildbewijs.

Dit is door C-003F integraal goedgekeurd zonder open P0/P1/P2. Een nieuw
parallel account-, authority- of permissionmodel zou het contract juist
schenden. C-004 voegt daarom bewust geen migration of business-RPC toe.

## Werkelijke C-004-delta

De delta bestaat uit een zelfstandige, uitvoerbare acceptatiegate:
`supabase/tests/c004_account_foundation_acceptance.sql`. Deze bindt de latere
C-004-naam controleerbaar aan de bestaande tabellen, RLS/DML-grens, typed RPC's,
veilige `SECURITY DEFINER`-configuratie, audit-immutability en versionkolommen.
De gate bewijst dat C-004 geen ontbrekende databaseverplichting verbergt zonder
de reeds goedgekeurde C-003-tests te dupliceren.

## Lokale verificatie

- fresh migration build op een lege geïsoleerde lokale Supabase-stack: **PASS**;
- zelfstandige C-004 Account Foundation-acceptatiegate: **PASS**;
- direct relevante C-003F-catalogusregressie: **PASS**.

De gezamenlijke C-004/C-005-uitkomst staat ook in
`docs/status/CURRENT_STATE.md`.
