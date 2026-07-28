# AVARYN Fase 5B.2 — Horse-management en beperkte toegang

## Scope

Deze subfase maakt uitsluitend de bestaande Alpha-Horse-kern testbaar:

- Horse aanmaken in de gekozen cloudstal;
- toegankelijke Horses vanuit RLS laden;
- kerngegevens wijzigen met `row_version`;
- een Horse gecontroleerd archiveren met reden;
- beperkte toegang voor `horse.basic` en `horse.schedule` geven en intrekken;
- semantische eigenaar-, ruiter-, groom- en trainerrelaties beheren;
- Paard-, Ruiter- en Team-authority gescheiden houden.

De oude lokale prototypeformulieren zijn buiten de actieve Alpha-navigatie
geplaatst én hard omgeleid naar de cloudworkspace. Hun on-loadacties en bodies
zijn vervangen, zodat ook een cold start, browser-back of deeplink geen lokaal
Horse-profiel meer kan creëren of wijzigen. Er is geen nieuwe productfunctie,
externe dienst of deployment toegevoegd.

## Authoritymodel

RLS en de bestaande mutatie-RPC's blijven leidend:

| Handeling | Server-authority |
| --- | --- |
| lezen | `horses_select_authorized` en `horse.basic:view` |
| aanmaken | actieve owner/admin van de gekozen stal |
| kerngegevens wijzigen | owner/admin of expliciete `horse.basic:edit` |
| archiveren | actieve owner/admin |
| toegang beheren | `grant_horse_access` / `revoke_horse_access` |
| teamrelatie beheren | owner/admin via relationship-RPC's |

`get_horse_capabilities(uuid)` is een read-only UI-samenvatting. De functie:

- vereist een ingelogde, actieve membership;
- retourneert alleen actor-rechten voor een actieve Horse die al zichtbaar is;
- gebruikt dezelfde private capabilityfuncties als RLS;
- schrijft niets en verleent geen authority;
- is niet uitvoerbaar door `anon` of `public`.

Een semantische teamrelatie geeft nadrukkelijk geen Horse-toegang. Grants en
relaties hebben afzonderlijke tabellen, RPC's, UI-secties en tests.

## Clientveiligheid

- Horse-mutaties bewaren vóór de netwerkcall uitsluitend een SHA-256
  intentdigest en UUID onder de account-/stalscope in veilige opslag. Voor de
  twee datumgebonden relatiemutaties bevat hetzelfde record ook de
  oorspronkelijke, niet-persoonlijke mutatiedatum. Een ambigue transportretry
  hergebruikt daardoor ook na widgetdispose, refresh, app-herstart of een
  datumgrens exact dezelfde request-ID en RPC-payload; alleen een definitieve
  uitkomst wist het record.
- Profielwijzigingen en relatie-einde sturen de gelezen `row_version`.
- Definitieve SQLSTATE-fouten beëindigen het request; conflicten vereisen
  vernieuwen.
- Een verloren membership, Horse-visibility of authority veroorzaakt de
  bestaande fail-closed purge.
- De UI toont alleen managementacties die de capabilitysamenvatting toestaat;
  verborgen knoppen zijn nooit de beveiligingsgrens.
- Er wordt geen Horse- of teamdata in plaintext lokaal opgeslagen.

## Reproduceerbaar lokaal bewijs

Lege migratie:

```sh
.flutterflow/sdk/bin/supabase db reset
```

Resultaat: alle migraties vanaf leeg toegepast, inclusief
`202607280001_phase_5b2_horse_alpha.sql`.

Upgrade met databehoud:

```sh
tool/test_phase_5b2_upgrade_local.sh
```

Resultaat: de laatste migratie is lokaal vanaf de groene 5B.1-structuur
toegepast; de fictieve bestaande stal, membership en Horse bleven exact
behouden en de owner-capabilitysamenvatting was correct.

Volledige subfaserunner:

```sh
tool/test_phase_5b2_local.sh
```

Behaald op 28 juli 2026:

- 4C.2A Horse Core SQL/RLS/idempotentie: groen;
- 4C.2B identiteit/relaties SQL/RLS/idempotentie: groen;
- 5B.2 owner/member/viewer/outsider/revoke-matrix: groen;
- Horse Core concurrency: 20/20;
- relatie/identiteit-concurrency: 9/9;
- herhaalde profiel-update-race: 25/25, 50/50 deelnemers;
- herhaalde relatie/identiteit-races: 90/90, 180/180 deelnemers;
- FlutterFlow AI workspace: 97/97.

## FlutterFlow-projectgate

De beveiligde projectrun is op 28 juli 2026 uitsluitend via de clipboard
credential-hand-off uitgevoerd en heeft FlutterFlow-projectcommit
`jjylhniKeKpUtLxWFRsq` gemaakt. Er is geen deployment uitgevoerd.

De daarna vernieuwde gegenereerde snapshot bewijst:

- alle drie legacy Horse-routes voeren bij initialisatie direct
  `goNamed(HorsesOverviewPageWidget.routeName)` uit;
- de veilige vervangende routebody en duurzame UUID-plus-replaydatumlogica zijn
  aanwezig;
- `flutter analyze` met de projectgebonden Flutter 3.35.7 meldt nul
  compilefouten; bestaande gegenereerde lintwaarschuwingen zijn niet
  bronhandmatig aangepast;
- `flutter build web --release` met Flutter 3.35.7 is lokaal geslaagd;
- de onafhankelijke read-only beveiligingsheraudit gaf GO zonder P0-, P1- of
  P2-bevindingen.

## Handmatige Alpha-acceptatie voor fase 5D

1. Owner maakt een fictieve Horse met meerdere kernvelden aan.
2. Owner wijzigt één kernveld; een gelijktijdige oude update krijgt conflict.
3. Owner geeft een member alleen basisbewerkrecht en een viewer alleen leesrecht.
4. Member kan de Horse wijzigen maar geen grants of relaties beheren.
5. Viewer kan lezen maar niet wijzigen of uitvoeren.
6. Owner trekt de grant in; de tweede sessie verliest Horse-visibility.
7. Owner koppelt een ruiterrelatie zonder access grant; die relatie opent geen
   gegevens.
8. Cross-stable en outsider-deeplinks tonen geen Horse of capabilitydetails.
9. Owner archiveert de Horse met reden; historie blijft bestaan en de actieve
   lijst verbergt de Horse.

Deze browser-, responsive- en multi-sessionstappen blijven onderdeel van de
formele fase-5D-acceptatie en zijn geen voorwendsel om server-authority te
verlagen.
