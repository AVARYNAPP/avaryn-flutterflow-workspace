# AVARYN Fase 5D.1 — Planning-acceptatie

## Scope

Deze slice sluit uitsluitend de minimale Planning-acceptatie:

- een tester kiest een logische lokale staldag;
- een tester maakt een losse taak voor die dag;
- een tester wijst optioneel één verantwoordelijk stabellid toe;
- een tester maakt een dagelijkse of wekelijkse routine;
- de client materialiseert de eerste dertien dagen via de bestaande
  server-RPC;
- Today en Planning tonen dezelfde server-side dagselectie;
- uitvoering, RLS, assignment-minimal-access en cross-stable denial blijven
  server-side afgedwongen.

Er is geen lokale planningbron, clientclaim-authority of nieuwe
productfunctionaliteit toegevoegd. `stable_id`, Horse-capabilities,
memberships, assignments en de bestaande planning-RPC's blijven leidend.

Taak plus optionele toewijzing en routine plus eerste materialisatie lopen
ieder via één atomische databasewrapper. De client bewaart de exacte
request-ID's en replaypayload versleuteld tot een definitief resultaat. Een
crash, ambigue response of fout in de tweede stap kan daardoor geen orphan
routine, dubbel geplande taak of taak zonder herstelbare toewijzing nalaten.
De dertiendaagse horizon is inclusief de startdag.

## Reproduceerbare lokale gate

```sh
tool/test_phase_5d1_local.sh --confirm-local-reset
```

De runner weigert zonder de expliciete resetflag, provisiont uitsluitend het
fictieve profiel Test Basis en controleert opnieuw het exacte lokale
Supabase-containerlabel voordat SQL wordt uitgevoerd.

De SQL-acceptatie voert binnen één teruggerolde transactie uit:

1. Owner A maakt drie routines met vaste request-ID's.
2. De routines worden voor dertien inclusieve staldagen van 3 t/m
   15 augustus 2026 gematerialiseerd.
3. Owner A maakt een losse taak en wijst Ruiter Drie verantwoordelijk toe.
4. Ruiter Drie ziet uitsluitend de minimale toegewezen taakcontext en
   registreert één fictieve uitvoering.
5. Owner B krijgt noch via Today noch via directe itemopvraag toegang.
6. De ingetrokken gebruiker ziet geen Today-data en kan het item niet direct
   lezen of muteren.
7. Exacte same-request-replays van beide atomische workflows leveren dezelfde
   objecten op en de routinehorizon bevat exact dertien lokale staldagen.

Daarna lopen de bestaande planning-concurrencytests tweemaal en de volledige
FlutterFlow AI-workspacesuite.

## Handmatige UI-acceptatie

Gebruik uitsluitend een fictief lokaal of later expliciet goedgekeurd
stagingaccount:

1. Open Planning en kies met de dagknoppen twee verschillende logische dagen.
2. Maak op een dag drie dagelijkse of wekelijkse routines.
3. Maak een losse taak, kies een Horse en wijs een verantwoordelijk
   stabellid toe.
4. Open Today op beide dagen en controleer de verwachte items.
5. Open als toegewezen teamlid en registreer één uitvoering.
6. Open als gebruiker van de tweede stal en bevestig dat geen item uit stal A
   zichtbaar of rechtstreeks bereikbaar is.
7. Trek de toegang in en bevestig dat refresh/reconnect de lokale toestand
   fail-closed wist.

De handmatige browser- en viewportrecords worden in de geconsolideerde
fase-5D-gate vastgelegd; dit document claimt nog geen deployment- of
stagingbewijs.

De projectgebonden buildgate gebruikt de met dit FlutterFlow-projectsjabloon
meegeleverde Flutter 3.35.7 SDK. `font_awesome_flutter` blijft daarom op
`10.7.0`: versie 11 breekt de gegenereerde `FFButtonWidget`-API. Alleen
`page_transition` wordt naar `2.2.2` bijgewerkt om de Cupertino-import
toekomstvast te maken. Er is geen dependency in de gegenereerde snapshot
handmatig aangepast.
