# Fase 4C.2A — Horse Core en toegang

Status: lokaal geïmplementeerd en getest. Niet gedeployed. Er is geen
FlutterFlow-codegen of schermkoppeling uitgevoerd.

## Scope

Deze subfase implementeert uitsluitend de veilige cloudfundering voor:

- het actuele Horse-basisprofiel;
- append-only profielwijzigingsaudit;
- expliciete capabilities per Horse en actief stalmembership;
- create, update, archive, grant en revoke via beveiligde RPC's;
- getypeerde Horse-correlatie voor `horse_access_granted` en
  `horse_access_revoked`.

Identifiers, Horse-relaties, planning, taken, voeding, media, realtime, offline
sync, legacy-import en FlutterFlow-koppelingen horen niet bij 4C.2A.
`profile_media_asset_id` is daarom alleen een nullable gereserveerde UUID en
heeft pas in de mediafase een typed foreign key. Er wordt geen lokale Horse
automatisch geüpload.

## Additieve migratie

`202607270001_phase_4c2a_horse_core.sql`:

1. voegt een unieke `(stable_id, id)`-sleutel toe aan
   `stable_memberships`, zodat grant-FK's dezelfde tenant afdwingen;
2. maakt `horses`, `horse_access_grants` en
   `horse_profile_change_events`;
3. maakt en valideert
   `stable_security_events(stable_id, horse_id) ->
   horses(stable_id, id)`;
4. voegt private booleanhelpers, triggers en één minimale private
   Horse-eventwriter toe;
5. voegt vijf publieke RPC's, RLS-policies, ACL's, indexes en comments toe.

De fase-4A-, fase-4B- en 4C.2A0-migraties blijven byte-ongewijzigd. Er worden
geen bestaande rijen herschreven en geen bestaande functies of signatures
vervangen.

## `horses`

Het basisrecord bevat:

- server-UUID `id` en verplichte `stable_id`;
- `active` of `archived`;
- begrensde en getrimde display- en officiële naam;
- optionele geboortedatum;
- `mare`, `gelding`, `stallion` of `unknown`;
- begrensd ras, discipline en niveau;
- gereserveerde `profile_media_asset_id`;
- optionele exacte `legacy_local_horse_id`;
- `manual`, `legacy_import` of `external_verified`;
- monotone `row_version`;
- server-afgeleide maker, request-ID en timestamps;
- `archived_at` die exact met de status overeenkomt.

Uniek zijn:

- `(stable_id, id)`;
- `(created_by_user_id, created_request_id)`;
- `(stable_id, legacy_local_horse_id)` wanneer de legacy-ID niet null is.

Twee paarden met dezelfde naam zijn toegestaan. Hard delete is geen
clientfunctie.

## Profielaudit

`horse_profile_change_events` is append-only voor:

- `horse_created`;
- `horse_profile_updated`;
- `horse_archived`.

De server bepaalt de begrensde `changed_fields`, `old_values` en `new_values`.
Een archiefreden is verplicht, getrimd en maximaal 500 tekens. Actor,
actormembership, stal en paard worden getypeerd gecorreleerd. Per
`(actor_user_id, request_id)` kan maximaal één profielmutatie-event bestaan.
Clientrollen hebben alleen `SELECT` en uitsluitend wanneer zij
`horse.basic:view` op hetzelfde paard hebben.

## Grantmodel

Een grant verwijst via samengestelde foreign keys naar exact één Horse en één
membership in dezelfde stal. Alleen een op locktijd opnieuw gevalideerd actief
membership kan als nieuw doel worden gebruikt. Een later suspended, removed of
left membership maakt de grant direct inert, zonder historische rijen te
verwijderen.

Categorieën:

- `horse.basic`;
- `horse.identity`;
- `horse.team`;
- `horse.schedule`;
- `horse.nutrition`;
- `horse.health_summary`;
- `horse.health_detail`;
- `horse.media`;
- `horse.permissions`.

Capabilities zijn `view`, `execute`, `edit` en `manage`. Iedere grant vereist
`view`; `edit` en `execute` impliceren `view`, en `manage` vereist `view` plus
`edit`. Viewergrants zijn view-only. Membergrants kunnen view, execute en edit
bevatten, maar nooit manage. Alleen een owner kan een admin een expliciete
grant geven. Een ownermembership is geen geldig grantdoel, omdat de owner de
volledige Horse-authoriteit al uit de stalrol krijgt.

Gevoelige categorieën vereisen een begrensde `grant_reason`. De reden wordt
nooit naar vrije security-eventmetadata gekopieerd.

Een partial unique index staat maximaal één actieve grant toe per
`(horse_id, membership_id, category)`. Revoke wijzigt de rij naar `revoked` en
bewaart actor, request-ID en timestamp. Een latere regrant maakt een nieuwe ID;
een oude grant-ID wordt niet hergebruikt.

## Rollen- en toegangsmatrix

| Actie | Owner | Admin | Member | Viewer |
| --- | --- | --- | --- | --- |
| Horse Basic lezen | alle eigen stalpaarden | alle eigen stalpaarden | expliciete geldige viewgrant | expliciete geldige viewgrant |
| Horse Basic aanmaken | ja | ja | nee | nee |
| Horse Basic wijzigen | ja | ja | expliciete geldige editgrant | nee |
| Paard archiveren | ja | ja | nee | nee |
| Niet-gevoelige Basic/Schedule-grant beheren | ja | member/viewer, nooit zichzelf | nee | nee |
| Gevoelige grant beheren | ja | alleen met vooraf door owner gegeven managegrant voor die Horse/categorie; alleen member/viewer | nee | nee |
| Grant aan admin geven | ja | nee | nee | nee |
| Grant aan owner geven | niet nodig/toegestaan | nee | nee | nee |
| Grants rechtstreeks muteren | nee, RPC-only | nee, RPC-only | nee | nee |

De capabilityhelper legt daarnaast de 4C.1-defaults vast voor latere fasen:
owner volledig; admin automatisch Basic view/edit, Team view/edit/manage en
Schedule view/execute/edit/manage. Identity, Nutrition, Health en andere
gevoelige categorieën vereisen voor admin een expliciete grant.

Namen, e-mailadressen, functietitels, profielen, relaties, JWT-customclaims en
clientmetadata verlenen nul rechten.

## RPC-signatures

Publiek executeerbaar voor `authenticated`, nooit voor `anon` of `public`:

```text
create_horse(
  uuid, text, uuid, text, date, text, text, text, text
) -> jsonb

update_horse_profile(
  uuid, bigint, uuid, text, text, date, text, text, text, text
) -> horses

archive_horse(uuid, uuid, text) -> boolean

grant_horse_access(
  uuid, uuid, text, boolean, boolean, boolean, boolean,
  timestamptz, timestamptz, text, uuid
) -> jsonb

revoke_horse_access(uuid, uuid, text, uuid) -> boolean
```

Actor en rollen komen altijd uit `auth.uid()` plus actuele database-rows.
Update, archive, grant en revoke ontvangen geen vertrouwde `stable_id`; de
server leidt die af uit het doelpaard. Grant en revoke leiden ook de
security-event-`horse_id` uit de opnieuw gelockte Horse-row af.

Create is idempotent op `(created_by_user_id, created_request_id)`. Dezelfde
request-ID met een andere payload faalt. Profile update gebruikt
`expected_row_version`; een stale update faalt met `ROW_VERSION_CONFLICT`.
Een semantisch identieke dubbele grant is een eventvrije no-op. Een dubbele
revoke met dezelfde request-ID retourneert veilig hetzelfde resultaat; een
latere revoke zonder actieve grant retourneert voor een nog steeds bevoegde
grantmanager `false` en schrijft geen event. De grantmanagerautorisatie wordt
vóór request- en grantaanwezigheidscontrole uitgevoerd, zodat een onbevoegde
actor geen grantstatus kan afleiden.

## Security-events

De bestaande `private.write_security_event(...)` blijft ongewijzigd. De
minimale nieuwe `private.write_horse_security_event(...)`:

- accepteert alleen `horse_access_granted` en `horse_access_revoked`;
- vereist typed stal-, paard-, actor-, subject- en requestcorrelatie;
- leidt `actor_user_id` af uit `auth.uid()` en controleert zelfstandig dat het
  actormembership bij die gebruiker en stal hoort en het subjectmembership bij
  dezelfde stal;
- schrijft alleen server-gegenereerde, begrensde categorie/capabilitymetadata;
- is niet executeerbaar voor `authenticated`, `anon` of `public`.

Grant/revoke en het event zitten in dezelfde PostgreSQL-transactie. Een
rejection, no-op, constraintfout of writerfout laat geen gedeeltelijke grant
en geen gedeeltelijk event achter. Alle fase-4B-eventtypen blijven
`horse_id IS NULL` vereisen; onbekende eventtypen blijven verboden.

## RLS en privileges

Alle drie nieuwe tabellen hebben RLS. `anon` heeft geen tabeltoegang.
`authenticated` heeft uitsluitend `SELECT`:

- `horses`: `horse.basic:view`;
- `horse_access_grants`: alleen de contractueel bevoegde grantmanager voor
  dezelfde Horse en categorie;
- `horse_profile_change_events`: `horse.basic:view`.

Geen clientrol heeft direct `INSERT`, `UPDATE` of `DELETE`. De private
eventwriter, normalisatiehelpers en triggerfuncties hebben geen
client-EXECUTE. De twee RLS-booleanhelpers retourneren alleen een boolean en
het private schema is niet als API-schema geëxposeerd.

## Lockvolgorde en hervalidatie

Create:

```text
stable FOR SHARE vinden en actief hervalideren
→ actor-membership FOR SHARE vinden en rol/status hervalideren
→ idempotencycontrole
→ Horse-insert
→ profielaudit
```

De stable-first volgorde voorkomt een membership→stable-FK-lockinversie met
fase-4B-authoritymutaties, die dezelfde stal eerst `FOR UPDATE` locken.

Normale profielmutaties:

```text
Horse/stable non-locking vinden
→ actor-membership FOR SHARE
→ benodigde actorgrant FOR SHARE
→ Horse FOR UPDATE
→ alle authority en status opnieuw valideren
→ mutatie
→ profielaudit
```

Grant en revoke:

```text
Horse/stable non-locking vinden
→ private.lock_stable_membership_mutation(stable_id)
  (stable FOR UPDATE, alle memberships in UUID-volgorde FOR UPDATE)
→ Horse FOR UPDATE
→ alle actieve Horse-grants in UUID-volgorde FOR UPDATE
→ actor, doelmembership, rol, grantmanagercapability,
  stalstatus en Horsestatus opnieuw valideren
→ grant/revoke
→ exact één typed stable_security_event
```

Deze volgorde is een uitbreiding van, en geen alternatief voor, het
fase-4B-authorityprotocol. Membershipmutaties, Horse-archivering en
grantmutaties hebben daardoor één geldige seriële uitkomst zonder
target/actor- of Horse/grant-lockinversie.

## Lokale verificatie

Gerichte bestanden:

- `supabase/tests/phase_4c2a_horse_core.sql`;
- `supabase/tests/phase_4c2a_horse_concurrency.rb`;
- aangepaste 4C.2A0-compatibiliteitstest met een echte Horse-fixture.

De SQL-matrix bewijst schema, constraints, RLS, privileges, RPC-matrix,
idempotency, optimistic concurrency, same-stable foreign keys, directe DML,
cross-stal- en onbekend-ID-orakelweerstand, inactieve memberships, exacte
eventcorrelatie, rollback en een onaangeroerde controlestal.

De Ruby-harness gebruikt per deelnemer een eigen `psql`-verbinding, een
database-zichtbare PostgreSQL-advisory-lockbarrière, unieke request-ID's en een
harde timeout. Hij racet:

- Horse-create tegen actor-suspend en stalarchive;
- grant tegen target-suspend;
- admin-grant tegen verlies van actor-authority;
- grant en revoke tegen Horse-archive;
- profielupdate tegen archive;
- twee profielupdates met dezelfde baseversion;
- grant tegen grant;
- grant tegen revoke.

Iedere deelnemer wordt gekoppeld aan zijn eigen event en volledige
eindtoestand. `40P01`, timeout, hang, dubbel/ontbrekend event, verloren update,
ID-hergebruik, cross-stalwijziging en wijziging van de controlestal zijn nooit
toegestaan.
