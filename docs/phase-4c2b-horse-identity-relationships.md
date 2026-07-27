# Fase 4C.2B — Horse-identiteit en relaties

## Scope

Deze subfase voltooit het resterende, expliciet beschreven deel van Horse
Core uit het 4C.1-contract:

- beschermde Horse-identifiers;
- semantische relaties tussen een Horse en een rosterpersoon;
- drie beveiligde mutatie-RPC’s;
- same-stable foreign keys, RLS, ACL’s, regressies en concurrencytests.

Planning, voeding, media, offline sync, legacy-import, FlutterFlow-koppelingen
en productieconfiguratie blijven buiten deze subfase.

## Additieve migratie

`202607270002_phase_4c2b_horse_identity_relationships.sql` bouwt uitsluitend
voort op de groene 4C.2A-commit. Geen eerdere migratie wordt gewijzigd en
bestaande Horse-, grant-, profiel- of security-eventdata wordt herschreven.

De migratie maakt:

- `public.horse_identifiers`;
- `public.horse_relationships`;
- private, hash-only mutationreceipts voor identifiers en relationship-add;
- twee private normalisatie-/row-versiontriggers;
- `public.upsert_horse_identifier(...)`;
- `public.add_horse_relationship(...)`;
- `public.end_horse_relationship(...)`.

## Horse-identifiers

`horse_identifiers` bevat:

- typed `identifier_type`: `chip`, `passport`, `registration`, `studbook`,
  `other`;
- een getrimde, begrensde `identifier_value`;
- optionele issuer en ISO-alpha-2-landcode;
- bron en verificatiestatus;
- optionele geldigheidsperiode;
- optimistic `row_version`;
- server-afgeleide create- en laatste-mutatieactor/requestcorrelatie;
- timestamps.

De publieke RPC accepteert alleen user-supplied, `unverified` waarden.
`professional`, `official` en andere verificatiestatussen kunnen niet door een
gewone client worden geclaimd. Een latere professioneel gevalideerde flow
krijgt daarvoor een afzonderlijk contract.

Identifiers verschijnen nooit in de Horse-basislijst. Select vereist
`horse.identity:view`; create/update vereist `horse.identity:edit`. Daardoor:

- owner heeft toegang volgens de 4C-matrix;
- admin heeft geen automatische Identity-toegang en heeft een expliciete
  grant nodig;
- member/viewer volgen exact hun actieve, niet-verlopen grant;
- een inactief membership verliest direct alle toegang.

Create gebruikt een null identifier-ID en null expected version. Update vereist
beide waarden en faalt bij een stale versie met `ROW_VERSION_CONFLICT`.
Iedere identifierrequest krijgt een private receipt met actor, typed target,
operation en SHA-256-payloadhash. De ruwe identifier wordt daarin niet
gekopieerd. Daardoor blijft ook na latere wijzigingen dezelfde request-ID een
veilige no-op; hergebruik met een andere payload faalt.

## Horse-relaties

`horse_relationships` koppelt een Horse aan een `stable_member_id`, nooit aan
een naam of clientclaim. Typed relaties zijn:

- `owner`;
- `rider`;
- `groom`;
- `trainer`;
- `veterinarian`;
- `professional`;
- `other`.

De relatie-`owner` is uitsluitend een semantische relatie tot het paard en
heeft geen verband met de fase-4B-stalownerrol. Een relatie verleent nul
capabilities. Toegang blijft uitsluitend uit actief membership, rolmatrix en
Horse-grants komen.

Add valideert een actieve rosterpersoon via de samengestelde
`(stable_id, stable_member_id)`-FK. Maximaal één actieve identieke
Horse/person/type-relatie bestaat. End verwijdert nooit een rij, maar zet de
lifecycle op `ended`, bewaart einddatum, actor en request-ID en verhoogt de
row-version.

Ook een request die als no-op aan een al bestaande identieke actieve relatie
wordt gekoppeld, krijgt een private actor/request/payloadreceipt. Een replay
blijft daardoor naar dezelfde historische relatie verwijzen nadat die relatie
is beëindigd en kan nooit alsnog een nieuwe actieve relatie creëren.

Owner en admin mogen teamrelaties beheren. Member en viewer kunnen ook met een
viewgrant geen relatie muteren.

## RLS, ACL en tenantgrenzen

Beide tabellen hebben RLS en default-deny ACL’s:

- `anon`: geen table- of RPC-toegang;
- `authenticated`: uitsluitend `SELECT` door de passende
  `private.has_horse_capability`-policy;
- geen directe client-`INSERT`, `UPDATE` of `DELETE`;
- writes uitsluitend via de drie `SECURITY DEFINER`-RPC’s met lege
  `search_path`;
- private triggerfuncties zijn niet client-executeerbaar.

Identifiers refereren met `(stable_id, horse_id)` naar de Horse. Relaties
refereren daarnaast met `(stable_id, stable_member_id)` naar het roster. Een
cross-stable Horse- of roster-ID kan daardoor ook voor privileged code geen
geldige koppeling vormen.

## Locking en hervalidatie

Identifier-mutatie:

```text
Horse/stal non-locking vinden
→ actormembership FOR SHARE
→ relevante actieve identity-grant(s) FOR SHARE
→ Horse FOR UPDATE
→ stalstatus, Horsestatus, membership en capability hervalideren
→ identifier FOR UPDATE bij update
→ mutatie
```

Relatiemutatie:

```text
Horse/relatie en stal non-locking vinden
→ owner/admin-membership FOR SHARE
→ Horse FOR UPDATE
→ target rosterpersoon FOR SHARE bij add
→ stal-, Horse-, actor- en targetstatus hervalideren
→ relationship FOR UPDATE
→ add of soft-end
```

Fase-4B authoritymutaties en Horse grant/archivefuncties locken eerst de stal
en daarna alle memberships. Een 4C.2B-mutatie die al een membership-sharelock
heeft, kan zijn resterende Horse-/grantwerk afronden; de authoritymutatie wacht
vóór zij Horse-locks kan nemen. Dit geeft één seriële uitkomst zonder
membership-, Horse- of grantlockinversie.

## RPC-signatures

```text
upsert_horse_identifier(
  uuid, uuid, bigint, uuid, text, text, text, text, date, date
) -> horse_identifiers

add_horse_relationship(
  uuid, uuid, text, uuid, date, text
) -> jsonb

end_horse_relationship(
  uuid, bigint, uuid, date
) -> boolean
```

Actor en stable worden nooit uit clientmetadata vertrouwd. Stable wordt uit de
opnieuw gelockte Horse/relationshipcontext afgeleid.

## Lokale verificatie

Gerichte tests:

- `supabase/tests/phase_4c2b_horse_identity_relationships.sql`;
- `supabase/tests/phase_4c2b_horse_identity_relationships_concurrency.rb`;
- `supabase/tests/phase_4c2b_upgrade_fixture.sql`;
- `supabase/tests/phase_4c2b_upgrade_verification.sql`.

De SQL-matrix bewijst schema, same-stable FK’s, rol/grantmatrix, identifier
normalisatie, source/verification fail-closed gedrag, optimistic concurrency,
relatie-idempotency en soft-end, relatie-isolatie van autorisatie, onbekende en
cross-stable objecten, directe DML, anon-denial en een onaangeraakte
controlestal.

De Ruby-harness gebruikt per deelnemer een echte `psql`-verbinding en een
database-zichtbare advisory-lockbarrière. Hij racet:

- identifierupdate tegen grantrevoke;
- twee identifierupdates vanaf dezelfde baseversion;
- relationship-add tegen actor-suspend;
- relationship-add en relationship-end tegen Horse-archive.

Deadlock (`40P01`), timeout, verloren update, dubbele actieve relatie of een
mutatie na authority-/statusverlies is altijd een testfout.

De formele upgradeproef start exact op 4C.2A, plaatst representatieve bestaande
Horse- en profielhistorie, past alleen 4C.2B toe en bewijst dat bestaande data
en Horse Core RPC-signatures ongewijzigd blijven en geen identifiers of
relaties worden gefabriceerd.
