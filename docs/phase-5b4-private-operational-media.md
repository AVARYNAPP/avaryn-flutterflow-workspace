# AVARYN Fase 5B.4 — Private operationele media

## Scope

Deze subfase ontsluit uitsluitend de in 4C.5 beveiligde mediaketen in de
testklare Alpha-runtime:

- privé-afbeeldingen en PDF's aan een Horse koppelen;
- uitvoeringsbewijs aan exact één bestaande schedule execution koppelen;
- servergekozen objectpaden via een signed upload-token gebruiken;
- server-side bytes, MIME, omvang, hash en thumbnail laten verifiëren;
- een kort geldige downloadlink per aanvraag verkrijgen;
- media soft-archiveren met optimistische concurrency;
- mediarechten expliciet geven en direct intrekken.

Er is geen publieke bucket, directe client-DML, nieuwe externe dienst of
deployment toegevoegd.

## Authority en gegevensscheiding

| Handeling | Server-authority |
| --- | --- |
| Horse-media lezen | media-RLS plus expliciete `horse.media:view` of owner |
| Horse-media uploaden | Edge `create` plus `horse.media:edit` of owner |
| execution-media uploaden | actor van exact die execution of media-edit |
| finalize | Edge-servicepad na server-side objectvalidatie |
| downloaden | Edge `download`, nieuwe autorisatie en URL van 60 seconden |
| archiveren | `archive_media_asset`, media-edit en `row_version` |
| grant/revoke | bestaande Horse-grant-RPC's met verplichte mediareden |

`get_horse_capabilities(uuid)` geeft alleen display guidance voor een reeds
zichtbare actieve Horse. RLS, RPC's, Storage en de Edge Function blijven de
authority. Een admin krijgt geen impliciete private-mediarechten; een owner
kan mediarechten expliciet aan admin, member of viewer geven.

## Clientveiligheid

- De Alpha-client accepteert alleen JPG/JPEG, PNG en PDF. De bestaande
  servervalidator ondersteunt WebP al, maar de projectgebonden Dart
  3.9-toolchain heeft geen compatibele begrensde WebP-encoder; WebP wordt
  daarom in deze client fail-closed niet aangeboden.
- Afbeeldingen zijn maximaal 10 MiB; PDF's maximaal 20 MiB.
- Web en native lezen het gekozen bestand als begrensde stream; de opgegeven
  bestandsgrootte wordt vóór het lezen gecontroleerd en het lezen stopt zodra
  de limiet alsnog zou worden overschreden.
- De thumbnaildecoder accepteert één frame, begrenst het gedecodeerde
  pixeloppervlak op 32 MiB en encodeert maximaal 1 MiB.
- De client gebruikt uitsluitend de vaste private `horse-media`-bucket en de
  door de server teruggegeven objectpaden en uploadtokens; de server valideert
  daarna de werkelijk opgeslagen bytes.
- Signed URLs, uploadtokens, objectpaden en mediabytes bestaan alleen tijdelijk
  in geheugen en komen niet in secure storage, auditpayloads of Git.
- Een download wordt alleen geopend via HTTPS op de exacte Supabase
  Storage-host en het signed-objectpad van de vaste private
  `horse-media`-bucket.
- Voor een ambigue upload bewaart secure storage vóór de eerste call uitsluitend
  het SHA-256-intent, create-request-ID en finalize-request-ID. Een herstart
  hergebruikt daardoor exact dezelfde idempotente serverrequests. Als alleen de
  finalize-respons verloren ging, hervat de server de reeds voltooide upload
  zonder nieuwe credentials of duplicaat. De client kan dit bij een oudere
  Edge-versie tevens via de bestaande media-RLS fail-closed vaststellen.
- Lokale offline media is fail-closed; een verloren sessie of authority triggert
  de bestaande account-/stalscope-purge.

## Reproduceerbaar lokaal bewijs

Lege migratie:

```sh
.flutterflow/sdk/bin/supabase db reset
```

Upgrade met databehoud:

```sh
tool/test_phase_5b4_upgrade_local.sh
```

Volledige subfaserunner:

```sh
tool/test_phase_5b4_local.sh
```

Behaald op 28 juli 2026:

- lege reset met alle migraties tot en met `202607280002`: groen;
- upgrade met behoud van pending asset, twee varianten en Horse-link: groen;
- 4C.5 SQL/RLS/Storage-matrix: groen;
- 5B.4 owner/admin/member/viewer/outsider/revoke-matrix: groen;
- finalize/Horse-archive concurrency: 50/50;
- lokale Edge/Storage-integratie, inclusief spoofing-, polyglot-,
  decompressiebom- en signed-URL-denials: groen;
- FlutterFlow-workspace: 103/103;
- FlutterFlow-projectcommit: `yIE3ywADlieIFyQqOBl1`;
- gegenereerde analyse met Flutter 3.35.7: nul compilefouten; alleen bestaande
  gegenereerde lintmeldingen;
- lokale release-webbuild met Flutter 3.35.7: groen.

Er is niets gepubliceerd of gedeployed.

## Handmatige Alpha-acceptatie voor fase 5D

1. Owner uploadt een fictieve JPG en PDF bij een Horse.
2. Owner koppelt fictief beeldbewijs aan een afgeronde eigen execution.
3. Member met media-edit kan uploaden; viewer met media-view kan alleen openen.
4. Admin zonder media-grant ziet of beheert geen private Horse-media.
5. Revoke sluit metadata én nieuwe downloadlinks direct af in een tweede sessie.
6. Een outsider en cross-stable actor krijgen geen object-, pad- of Horse-orakel.
7. Ongeldige, te grote, polyglot en decompressiebom-fixtures worden geweigerd.
8. Een gelijktijdige finalize/archive-race eindigt in één consistente toestand.
9. Een gearchiveerd item verdwijnt uit actieve lijsten en krijgt geen nieuwe URL.

Deze multi-session-, responsive- en browserstappen blijven onderdeel van de
formele fase-5D-acceptatie.
