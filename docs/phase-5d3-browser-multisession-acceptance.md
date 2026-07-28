# AVARYN Fase 5D.3 — Browser- en multi-sessieacceptatie

## Scope en veiligheidsgrens

Deze subfase gebruikt uitsluitend de lokale Supabase-stack, het fictieve
fase-5C Basis-profiel en een tijdelijke kopie van de gegenereerde Flutter-app.
De repositoryversie van `generated_code/` blijft ongewijzigd. Er is geen
deployment, staging- of productiehandeling uitgevoerd.

Browserwachtwoorden worden willekeurig gegenereerd, uitsluitend via een
bestand met modus `600` en een tijdelijke `docker exec`-omgevingsvariabele aan
de lokale fixture doorgegeven. De waarde wordt niet getoond, gelogd of
gecommit.

## Bevinding D3-RT-001 en reparatie

De eerste echte owner/groom-proef leverde geen live update. De lokale Realtime-
container wees ieder uitgegeven ondoorzichtig UUID-topic af. Twee afzonderlijke
oorzaken zijn bewezen:

1. `authenticated` miste `EXECUTE` op
   `private.can_join_realtime_topic(text)`, hoewel de RLS-policy deze functie
   moet evalueren;
2. de policy eiste daarnaast `extension = 'broadcast'` en `private is true`.
   Supabase Realtime voert de channel-join als RLS-probe uit; die probe biedt
   deze berichtkolommen niet als een opgeslagen rij aan. De topicfunctie gaf
   voor dezelfde fictieve JWT en UUID aantoonbaar `true`, terwijl alleen deze
   extra clausules de join nog afwezen.

Migratie `202607280005_phase_5d3_realtime_policy_handshake.sql` verleent
`EXECUTE` uitsluitend aan `authenticated` en laat de SELECT-policy beslissen
op de ondoorzichtige topic-UUID. De functie zelf blijft fail-closed controleren:
actieve stal, actieve membership, actuele authority-versie en scopegebonden
rol, eigen membership of actuele Horse-capability.

Een tweede tegenproef trok Groom Twee in terwijl diens Today-pagina openstond.
De server roteerde correct, maar de client reageerde nog niet op een private
channel-error en hield daardoor ontsleutelde regels in het geheugen. Een
authorityrotatie verstuurt daarom vóór het vervangen van UUID-topics een
payloadarme `change_available`-wake naar ieder oud privé-topic. De payload
bevat applicatiezijdig alleen de nieuwe authorityversie; `realtime.send` voegt
uitsluitend zijn willekeurige technische bericht-ID toe. Er staat geen stal-,
membership-, user- of domeinobject-ID in.
`AvarynOperationalRuntime` behandelt daarom zowel `channelError` als
`timedOut` als een wake-up voor een nieuwe authoritycontrole. Een geweigerde
topicjoin of `SYNC_UNAVAILABLE` loopt vervolgens door dezelfde bestaande
purgegrens: dialogs sluiten, geheugenstate en secure scope worden gewist en de
stalkeuze vervalt.

## Uitgevoerd lokaal browserbewijs

Datum: 28 juli 2026. Tijdzone: `Europe/Amsterdam`.

| Scenario | Platform/viewport | Resultaat |
| --- | --- | --- |
| Owner-login met toetsenbord-Enter | web, 1440×900 | groen; gate naar Today |
| Today responsive en semantische labels | web, 390×844 | groen; geen consolefouten |
| Today responsive en horizontale begrenzing | web, 820×1180 | groen; body- en Flutter-view-breedte exact 820 |
| Today/Paarden/Planning navigatie | web, 1440×900 en 820×1180 | groen; clouddata uit Basis-profiel |
| Twee geïsoleerde Auth-sessies | `127.0.0.1` owner en `localhost` groom | groen; afzonderlijke webstorage |
| Assigned-only groom-scope | web, 820×1180 | groen; alleen toegewezen taken |
| Private Realtime na policyfix | twee gelijktijdige sessies | groen; nieuwe taak verscheen zonder refresh in groom-sessie |
| Live revoke tijdens open groom-sessie | twee gelijktijdige sessies | groen; toegangsmelding, geen actieve stal en eerdere taak zonder refresh uit geheugen |
| Logout en accountwissel groom → Owner B | geïsoleerde tweede browserorigin | groen; Stal B zichtbaar, naam en taken van Stal A afwezig |
| Legacy Horse-deeplinks | `/paarden/formulier`, `/paarden/bewerken`, `/paarden/detail` | groen; harde replace naar `/paarden`, ook na back en refresh uitsluitend cloudruntime |
| Realtime-foutvenster na fix | lokale containerlog | groen; geen `Unauthorized`, `RlsPolicyError` of functierechtenfout |
| Browseroffline-contract | web, owner-sessie | groen; na stoppen van uitsluitend lokale API-gateway werden namen gepurged en verscheen veilige fout/empty-state zonder plaintext fallback |

De taak `5D3 Realtime definitief groen` werd in de owner-sessie gepland voor de
fictieve Groom Twee. Zonder refresh verscheen exact die taak binnen het
debouncevenster in de reeds actieve groom-sessie. Een daaropvolgende
suspension roteerde de authority en verwijderde de eerder zichtbare taak
binnen 2,2 seconden uit diezelfde open sessie, eveneens zonder refresh.

De browserproef gebruikte twee origins voor gescheiden webstorage. Na logout
van de ingetrokken Groom Twee kon Owner B in dezelfde tweede origin uitsluitend
Stal B zien. De drie oude Horse-routes, browser-back en refresh kwamen steeds
uit op de cloud-backed `/paarden`-runtime. Voor de offline-tegenproef is alleen
de exact gecontroleerde lokale Kong-container kort gestopt; de app purgeerde
zichtbare Horse-data en toonde een veilige herstelbare fout. De container is
daarna opnieuw gestart en eindigde `running` en `healthy`.

Alle tijdelijke wachtwoord- en webserverartefacten zijn na de proef verwijderd.
Er is geen deployment of productiehandeling uitgevoerd.

## Reproduceerbare automatische gate

```sh
tool/test_phase_5d3_local.sh --confirm-local-reset
```

De runner controleert het exacte lokale Dockerproject, reset uitsluitend de
lokale testdatabase en voert uit:

- de volledige 4C.6 SQL-suite;
- vijftig 4C.6 concurrency-iteraties;
- 5D.3 ACL-, cross-stable-, revoked- en authorityrotatietests;
- alle FlutterFlow-workspacetests.

Een lokale browserfixture kan met een willekeurig tijdelijk wachtwoord worden
voorbereid:

```sh
tool/prepare_phase_5d3_browser_local.sh \
  --confirm-local-reset \
  --password-file /pad/naar/lokaal-bestand-met-modus-600
```

Het wachtwoord mag nooit als argument, chattekst of repositorybestand worden
doorgegeven.
