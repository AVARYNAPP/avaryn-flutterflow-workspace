# Fase 4C.5 — private Horse-media

## Status en grens

Fase 4C.5 levert de backendbasis voor documenten en beelden bij een Horse of
een concrete taakuitvoering. De wijziging is additief op de gevalideerde
4C.4-baseline. Er is niets naar productie uitgerold en er is geen
FlutterFlow-code gegenereerd.

De vaste grens is:

- bucket `horse-media` is privé;
- een client kiest nooit een objectpad;
- een client krijgt geen service-role-key;
- een asset is tijdens upload `pending` en daardoor niet leesbaar;
- alleen de Edge Function downloadt de bytes om MIME, omvang en SHA-256 te
  controleren;
- pas daarna maakt één databasetransactie alle varianten en het asset `ready`;
- downloadlinks worden pas na een nieuwe autorisatiecheck gemaakt en verlopen
  na 60 seconden;
- archiveren is een soft delete. Een latere, expliciete bewaartermijn bepaalt
  wanneer een serverproces bytes definitief mag purgen.

## Opslag en limieten

`202607270005_phase_4c5_media.sql` maakt de private bucket met:

| Type | Origineel | Thumbnail |
| --- | ---: | ---: |
| JPEG / PNG / WebP | maximaal 10 MiB | verplicht, maximaal 1 MiB |
| PDF | maximaal 20 MiB | niet van toepassing |

GIF en andere uitvoerbare of ambigu te interpreteren formaten zijn bewust niet
toegestaan. De thumbnail is een eigen variant met eigen servergekozen pad,
MIME, omvang en hash. De client mag de beeldderivaat maken, maar de server
verifieert ook die bytes en de derivaat kan nooit ruimere toegang geven dan het
origineel.

Het pad heeft altijd de vorm:

```text
<stable_id>/<horse_id>/<media_asset_id>/<variant>
```

De oorspronkelijke bestandsnaam wordt alleen als geschoonde presentatienaam
opgeslagen en heeft geen invloed op bucket of pad.

## Datamodel

- `media_assets`: tenant, Horse, lifecycle, verwachte en geverifieerde metadata,
  uploader, request-id en row version;
- `media_asset_variants`: `original` en optioneel `thumbnail`, ieder met een
  uniek serverpad en eigen SHA-256;
- `media_links`: exact één getypeerd doel, `horse` of
  `schedule_execution`;
- `media_change_events`: append-only en payload-minimaal;
- `private.media_mutation_receipts`: idempotency zonder URL, token, objectpad,
  bestandsnaam of hash.

Alle publieke mediatabellen hebben RLS. Authenticated clients hebben alleen
`SELECT` via de effectieve linkautorisatie en nooit directe
`INSERT`/`UPDATE`/`DELETE`. `finalize_media_asset` en
`authorize_media_asset_download` zijn uitsluitend uitvoerbaar door
`service_role`.

## Autorisatie

Een Horse-link erft exact `horse.media`:

- owner heeft deze capability automatisch;
- admin, member en viewer hebben een expliciete actieve grant nodig;
- Horse, stable en membership moeten actief blijven.

Een execution-link mag daarnaast worden gelezen door de uitvoerder of door een
gebruiker met `full`/`assigned` toegang tot het gekoppelde schedule item. Een
execution-linked upload mag worden gestart door die uitvoerder of door iemand
met `horse.media.edit`. Een los bestaand asset aan een nieuw doel koppelen of
een asset archiveren vereist altijd `horse.media.edit`.

Daardoor kan een taaktoewijzing minimale toegang geven tot bewijs bij precies
die uitvoering, zonder algemene inzage in de overige Horse-media. Ook de
`media_links`-RLS is target-specifiek: toegang via execution A onthult geen
Horse-link of execution B. Auditrijen zijn alleen zichtbaar met volledige
`horse.media.view`, niet met minimale execution-toegang.

Iedere route — ook de directe `actor_user_id` van een execution — vereist
opnieuw een actieve membership. `suspended`, `removed` en `left` leveren
onmiddellijk nul tabeltoegang en nul nieuwe signed URLs op.

## Lifecycle

1. `create_media_upload_session` bepaalt tenant, Horse, asset-id, links,
   varianten en paden. De Edge Function vertaalt die paden naar tijdelijke
   signed-upload gegevens.
2. De client uploadt alle vereiste varianten.
3. De Edge Function downloadt ieder object via service role, controleert magic
   bytes, volledige containerstructuur, allowlist, limiet en SHA-256 en roept
   daarna
   `finalize_media_asset` aan.
4. De finalize-transactie controleert opnieuw actieve autorisatie, row version,
   objectaanwezigheid en metadata en zet varianten plus asset atomair op
   `ready`.
5. `download` roept eerst `authorize_media_asset_download` aan en maakt pas
   daarna een signed URL van 60 seconden.
6. `archive_media_asset` archiveert asset, varianten en links, maar verwijdert
   geen objectbytes.

Alle mutaties zijn request-idempotent. Audit en receipts bevatten nooit signed
URLs, uploadtokens of opslagpaden. De Edge Function logt deze gegevens evenmin.
Een exacte retry herautoriseert altijd de actuele membership, grant, Stable en
Horse. Alleen een asset waarvan asset én alle varianten nog `pending` zijn kan
nieuwe uploadcredentials krijgen. Ready, archived of ingetrokken sessies zijn
gesloten. Edge haalt finalize-coördinaten uitsluitend op via de
service-role-only `get_media_upload_session`; clients kunnen die RPC niet
uitvoeren.

De structuurcontrole gaat verder dan een bestandsheader:

- PNG vereist geldige chunkgrenzen, CRC’s, IHDR, IDAT-decompressie,
  scanlinelengtes/filterwaarden en een exact afsluitende IEND;
- JPEG vereist een geldige marker-/segmentketen, begrensde frame-afmetingen,
  scanstructuur, exact afsluitende EOI en succesvolle decode door de gepinde
  MozJPEG-WASM-decoder;
- WebP vereist een exact passende RIFF-container, geldige chunkgrenzen en één
  ondersteund still-image frame dat de gepinde libwebp-WASM-decoder accepteert;
- PDF vereist een geldige header, laatste `startxref`, een bereikbare klassieke
  xref-tabel met Catalog-root en een exact afsluitende EOF.

Afgeknotte, fake-header-, synthetische en polyglotfixtures worden als `pending`
afgewezen. Beeldafmetingen zijn bovendien begrensd op maximaal 32 MiB
gedecomprimeerde rasterdata, zodat een klein gecomprimeerd bestand geen
decompressiebom kan worden.

De decoderimplementaties zijn exact gepind op `@jsquash/jpeg@1.6.0` en
`@jsquash/webp@1.5.0`. Hun publieke WASM-binaries worden bij de eerste relevante
decode lazy via de overeenkomstig gepinde jsDelivr-paden geladen; mediabytes
verlaten AVARYN daarbij nooit. Initialisatie en decode vallen binnen dezelfde
fail-closed foutgrens: bij een fout blijft finalize geweigerd en het asset
`pending`. Een latere productiedeployment moet deze bootstrap in de
deploymentcheck meenemen; deze fase voert zelf geen deployment uit.

## Concurrentie

Finalize en Horse-archivering nemen locks in dezelfde volgorde:

1. actieve membership;
2. relevante grants;
3. Horse;
4. media asset en varianten.

Als finalize eerst serializeert, kan de Horse daarna archiveren en maakt de
actieve-Horse-check het asset onmiddellijk onzichtbaar. Als archivering eerst
serializeert, faalt finalize gesloten. Er bestaat dus geen serialisatie waarin
een asset na Horse-archivering zichtbaar blijft.

## Verificatie

De fase wordt geaccepteerd na:

- een schone lokale reset met alle migraties;
- een exacte 4C.4→4C.5 upgrade met behoud van bestaande data;
- SQL-regressies voor scope, RLS, ACL, idempotency, lifecycle en metadata;
- echte lokale Storage/Edge-integratie voor upload, bytevalidatie, finalize en
  60-seconden-download;
- execution-minimal regressies voor target-specifieke links, verborgen audit,
  grant-revoke en membershipstatussen `suspended`/`removed`/`left`;
- geldige JPEG/PNG/WebP/PDF-fixtures én afgeknotte/fake/polyglotfixtures;
- een meermaals herhaalde finalize-versus-Horse-archive race;
- regressies van de eerdere fase-4-basis;
- een onafhankelijke read-only security- en contractaudit.
