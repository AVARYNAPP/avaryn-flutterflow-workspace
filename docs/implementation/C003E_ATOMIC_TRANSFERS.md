# C-003E — Atomic transfers

## Status en scope

- Status: **C-003E — Approved within the agreed scope**.
- Datum: `2026-08-05`.
- Branch: `implementation/account-model-v2-c003e-f-transfers-security`.
- Goedgekeurde C-003D-basis:
  `e940e956144cfa666be12f6d5c6d7ea383b44d20`.

C-003E implementeert uitsluitend de zeven dagen geldige overdracht van scalar
primary Horse Authority en scalar organization primary admin. Today,
FlutterFlow, staging en de Rider Performance-datamodule vallen buiten scope.

## Transfercontract

Beide transfermodellen ondersteunen `pending`, `accepted`, `declined`,
`revoked` en `expired`. Initiatie gebruikt een eenmalig cryptografisch token;
alleen de server-side HMAC-digest wordt opgeslagen. Een resource kan maximaal
één pending transfer hebben. Create-correlation is idempotent, terminale
tokens worden gewist en terminale transferhistorie kan niet worden gewijzigd
of verwijderd.

Acceptatie lockt eerst de horse/organization en daarna de transfer. Actor,
sender, recipient, actieve profilestatus, expiry en de bij creatie vastgelegde
`authority_version` of `access_version` worden opnieuw server-side
gevalideerd. Stale state faalt gesloten. Horseacceptatie wisselt de scalar
authority en verhoogt horse authority/access/row versions plus de betrokken
profile access versions in één transactie.

Organizationacceptatie maakt of activeert eerst de recipient-membership en
reserved head-adminrol, revokeert daarna de oude head-adminassignment en
wisselt de scalar primary admin met versionrotatie binnen dezelfde transactie.
De bestaande deferred primary-admininvariant wordt bij commit afgedwongen.
Daardoor is geen tijdelijk zichtbaar toegangsgat, dubbele primary authority of
half uitgevoerde transfer mogelijk.

Alle mutaties lopen via authenticated RPC's met server-side actorafleiding,
PII-arme append-only audit en `search_path = ''`. Transfer-tabellen zijn
RPC-only; `anon`, `authenticated` en `service_role` hebben geen directe
table-ACL. Private C-003E-routines zijn voor clientrollen niet uitvoerbaar.

## Verificatie

- volledige migrationketen vanaf een lege geïsoleerde lokale database: PASS;
- positieve/negatieve pgTAP-matrix voor authority, spoofing, DML/ACL, expiry,
  stale versions, revoke/decline, terminal replay, audit en deletion blockers:
  PASS;
- simultane horse- en organizationacceptatie: per transfer exact één winnaar,
  één terminal-replayfout en precies één scalar/versionovergang: PASS;
- atomische organization membership/head-rolewissel en deferred invariant:
  PASS.

Er zijn geen bekende C-003E P0/P1/P2-problemen binnen de afgesproken scope.
