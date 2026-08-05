# C-003D — Explicit permissions and invitations

## Status en scope

- Status: **C-003D — Implemented locally – awaiting next gate**.
- Datum lokale implementatie: `2026-08-05`.
- Branch: `implementation/account-model-v2-c003d-permissions-invitations`.
- Goedgekeurde C-003C-basis:
  `1321da6366018d9d8a0a203a2fefde188ce7be69`.
- Niet gestart: C-003E transfers en C-003F.

C-003D breidt uitsluitend de goedgekeurde identity-, audit-, organization- en
canonical-horsefundamenten uit met expliciete grants, invitationflows en de
Rider Performance sharing-securitylaag. Relationships, organization-horse
links, residency, ownership, legacy `stable_id`, clientstate en JWT-metadata
blijven niet-autoritair. FlutterFlow, applicatiecode en remote omgevingen zijn
niet gewijzigd.

## Permissions en grants

Het gedeelde catalogusmodel bevat nu de horse-scoped codes `horse.view`,
`horse.edit`, `horse.manage`, `horse.assign`, `horse.share` en de niet-
grantable `horse.transfer`. De zeven bestaande organizationcodes blijven
organization-scoped; een database-trigger en de aangepaste C-003B-
organizationaanmaak blokkeren horse-codes in organizationrollen.

Expliciete horse-toegang bestaat uit:

- tijdgeldige profile-grants;
- tijdgeldige grants aan een actieve organizationrol, alleen voor actuele
  actieve memberships en role assignments;
- C-003C primary authority en bestaande expliciete delegaties.

De grantor moet server-side `horse.manage` én de te verlenen grantable
permission bezitten. Afgewezen escalatie retourneert `applied=false` en blijft
PII-arm geaudit. Profile grants kunnen optioneel aan een actuele horse-person
relationship zijn gebonden; role grants aan een actieve organization-horse
link. Het einde daarvan revokeert uitsluitend de gebonden grants. De relatie
of link zelf verleent nooit toegang. Grant/revoke/expire/end roteert relevante
horse-, organization- en profile-`access_version` en gebruikt optimistic
`row_version`-controle.

De afzonderlijke Rider Performance sharing-tabellen ondersteunen expliciete,
tijdgeldige profile- en organizationrole-shares per category en optioneel
record. Alleen de eigenaar kan verlenen of beëindigen. De daadwerkelijke Rider
Performance-recordmodule valt buiten C-003D.

## Invitations

Organization-invitations verwijzen naar precies één actieve, niet-reserved
initiële rol. Horse-invitations bevatten een genormaliseerde set expliciete,
grantable horse-permissions met eigen grantvenster. Beide flows gebruiken een
cryptografisch random token dat alleen eenmaal aan de creator wordt
teruggegeven. Alleen een server-side HMAC van genormaliseerde e-mail en een
domeingescheiden token-HMAC worden opgeslagen; raw e-mail en raw token worden
nooit opgeslagen of geaudit. Het HMAC-secret staat in `private` zonder
client-ACL.

Preview en response vereisen een actief profile en de bevestigde e-mail uit
`auth.users`; een clientclaim kan dit niet vervangen. Acceptatie lockt de
invitation, vergelijkt de HMAC, valideert expiry en beoordeelt de actuele
inviter-authority opnieuw. Organization-acceptatie maakt alleen het bedoelde
membership en role assignment; horse-acceptatie alleen de opgesomde grants.
Tokens worden bij accept/decline/revoke/expire gewist, waardoor terminal replay
fail-closed is. Verloren tokens zijn bij idempotente create-replay bewust niet
terug te halen.

## RLS, ACL, audit en mutatiegrens

RLS staat aan op alle zeven nieuwe publieke tabellen. `authenticated` heeft
alleen RLS-beperkte `SELECT` op de vier grant/share-tabellen. Invitation- en
invitation-permissiontabellen zijn uitsluitend via preview/respond-RPC's
bereikbaar. `anon`, `service_role` en `authenticated` hebben geen directe
`INSERT`, `UPDATE`, `DELETE` of `TRUNCATE` en geen onverwachte public-RPC-
rechten. Mutaties lopen door `SECURITY DEFINER` met `search_path = ''` en
server-side actorafleiding.

Alle private C-003D-routines, inclusief HMAC-routines en triggers, zijn voor
clientrollen niet uitvoerbaar. De eerder goedgekeurde exacte C-003A-
authenticated RLS-helperallowlist blijft intact. Autorisatierelevante
mutaties schrijven allowlisted append-only audit zonder e-mail, token, HMAC of
clientaangeleverde actorvelden.

## Verificatie en beperkingen

De gerichte lokale ronde is groen:

- volledige migrationketen vanaf een lege geïsoleerde database;
- C-003D pgTAP-securitymatrix voor grant/deny, cross-scope, invitation-
  lifecycle, spoofing, expiry/revoke, DML, RLS/ACL/EXECUTE, audit en versions;
- gelijktijdige one-time-tokenacceptatie: één winnaar, één consumed-token-
  fout en exact één grant;
- direct geraakte C-003A private-ACL/audit-, C-003B organization/catalogus- en
  C-003C horse-authorityregressies;
- gerichte cataloguscontrole en `git diff --check`.

Er zijn geen bekende P0/P1/P2-securityproblemen binnen C-003D. Expiry wordt
bij iedere autorisatiecheck onmiddellijk fail-closed toegepast; een latere
achtergrond-sweeper voor cosmetische statusmaterialisatie is niet onderdeel
van deze fase. C-003E-transfers, de feitelijke Rider Performance-datamodule,
productie-uitvoering en de overkoepelende C-003F-securitygate blijven apart.
