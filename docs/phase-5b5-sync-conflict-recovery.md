# AVARYN Fase 5B.5 — Realtime, offline-sync en conflictherstel

## Scope

Deze subfase maakt het bestaande 4C.6-synccontract bruikbaar in de besloten
Alpha zonder de beveiligingsgrenzen te verruimen:

- private Realtime blijft uitsluitend een wake-upsignaal;
- de monotone serverfeed blijft de duurzame verversingsbron;
- offline dagsets en pending uitvoeringen blijven uitsluitend beschikbaar op
  native/desktop met OS-backed sleutelopslag;
- browseroffline blijft fail-closed uitgeschakeld;
- een eigen open, niet-kritiek Horse-profielconflict kan bewust worden
  afgesloten door de actuele serverversie te behouden.

Er is geen generieke merge, last-write-wins, offline Horse-bewerking,
permissionconflict of nieuwe backendmutatie toegevoegd.

## Conflictherstel

De runtime vraagt conflicten uitsluitend op via `list_sync_conflicts`. Die RPC
retourneert alleen open conflicten waarvan `actor_user_id` gelijk is aan de
ingelogde Auth-UUID. De database beperkt het type tot
`horse_basic_noncritical`, de patch tot 4 KiB en de velden tot:

- roepnaam en officiële naam;
- geboortedatum en geslacht;
- ras, discipline en niveau.

De Alpha-resolver biedt bewust maar één uitvoerbare keuze:
`resolved_server`. De bestaande serverrij blijft ongewijzigd en actief; de
lokale patch wordt niet stil toegepast. De gebruiker ziet de beperkte lokale
wijziging, vergelijkt die met de actuele UI en geeft een verplichte reden van
maximaal 500 tekens. Daarna kan de lokale wijziging zo nodig als een nieuwe,
gewone online bewerking worden ingevoerd.

De RPC-call gebruikt vóór verzending secure storage voor exact één
idempotent request-ID, de vaste resolutie en de exacte reden. Het
storage-adres bevat alleen een SHA-256-intentsleutel. Na succes wordt het
record verwijderd; bij een ambigue transportuitkomst blijft exact dezelfde
request behouden. Logout, account-/stalwissel en authorityreset wissen de
volledige accountgebonden operationele opslag.

Het conflictvenster is zelf onderdeel van die beveiligingsgrens. De runtime
volgt uitsluitend de exacte gevoelige dialogroute en verwijdert die vóór
gedecrypteerde state wordt gewist. Een bevestiging uit een oudere
beveiligingsgeneratie, Auth-gebruiker of stal wordt daarna fail-closed
genegeerd. Hierdoor kan een account- of authoritywissel geen oude lokale
patch in een nog geopend venster achterlaten.

Dezelfde scopebinding wordt vóór het lezen of schrijven van het duurzame
requestrecord en opnieuw direct vóór de RPC gecontroleerd. Verandert de
beveiligingsgeneratie, Auth-gebruiker of stal tijdens secure-storage-I/O, dan
wordt het eventueel tussentijds geschreven record verwijderd en wordt geen
RPC gestart.

## Reproduceerbaar lokaal bewijs

De volledige subfaserunner:

```sh
tool/test_phase_5b5_local.sh
```

Deze voert achtereenvolgens uit:

1. de bestaande 4C.6 SQL/RLS/privilege- en conflictmatrix;
2. 50 offline-sync/revoke-, import/revoke-, cutover- en cursorvolgorderaces;
3. alle FlutterFlow-workspacetests.

Aanvullend gelden:

```sh
flutterflow ai run dsl/edit.dart \
  --project-id "a-v-a-r-y-n-consumer-app-8yb89s" \
  --commit-message "Fail closed on stale conflict confirmation"

cd generated_code
../.flutterflow/sdk/flutter_3.35.7/bin/flutter analyze --no-pub
../.flutterflow/sdk/flutter_3.35.7/bin/flutter build web --release
```

De FlutterFlow-run gebruikt uitsluitend de beveiligde clipboard-handoff voor
`FF_API_KEY`. Er wordt niets gepubliceerd of gedeployed.

Behaald op 28 juli 2026:

- 4C.6 SQL/RLS/privilege- en conflictmatrix: groen;
- offline-sync/revoke, import/revoke, cutover/target en cursorvolgorde:
  elk 50/50;
- FlutterFlow-workspace: 108/108;
- FlutterFlow-projectcommit: `5h5N8qza8aOSIfSVuPPf`;
- gegenereerde analyse met Flutter 3.35.7: nul compilefouten; alleen bestaande
  gegenereerde lintmeldingen;
- lokale release-webbuild met Flutter 3.35.7: groen.

## Handmatige Alpha-acceptatie voor fase 5D

1. Sessie A veroorzaakt met een fictieve, niet-kritieke Horse-profielpatch
   een base-versionconflict.
2. Alleen dezelfde actor ziet het open conflict; een andere gebruiker en stal
   zien niets.
3. De actor ziet lokale en serverversie, de beperkte patch en de verplichte
   reden.
4. Annuleren wijzigt niets.
5. Serverversie behouden sluit het conflict exact eenmaal en houdt de
   serverrij ongewijzigd.
6. Een ambigue response wordt met dezelfde request-ID hervat.
7. Revoke tijdens de flow wist operationele state en blokkeert de mutatie.
8. Op web blijft offline uitgeschakeld; native pending-sync blijft
   versleuteld en herstartbestendig.

Multi-session-, native-offline-, responsive- en browseracceptatie worden in
fase 5D als afzonderlijke bewijsrecords uitgevoerd.
