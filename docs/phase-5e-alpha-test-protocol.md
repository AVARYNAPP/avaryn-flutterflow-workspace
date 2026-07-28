# AVARYN Fase 5E — besloten Alpha-testprotocol

## 1. Doel, status en grens

Dit protocol is de uitvoerbare testinstructie voor een kleine besloten
webalpha. Het bouwt voort op:

- Git-baseline `fd8e0de85f3bf5721cc3ccabaad262c544f11aa2`;
- FlutterFlow-projectcommit `273uNhvKI33OfF2VFdRi`;
- de lokale migratieketen tot en met `202607280005`;
- de formele profielen Test Basis, Medium, Extreme en Custom;
- de groene fase-5D.1-, 5D.2- en 5D.3-bewijzen.

Dit document autoriseert geen stagingdeployment, echte accounts, echte
uitnodigingen of verwerking van persoonsgegevens. Vóór die externe stappen is
de afzonderlijke deploymentgate in
`docs/phase-5e-deployment-gate.md` bindend.

De webalpha is online-only. Bij netwerkverlies wist de webclient de zichtbare
cloudprojectie en toont hij een veilige fout/empty-state. Duurzame offline
dagsets blijven uitsluitend voor een later afzonderlijk goedgekeurde
native/desktopacceptatie met OS-backed sleutelopslag.

## 2. Rollen, persona's en testdata

Persona's zijn alleen scenario-aanduidingen. Zij verlenen geen authority.

| Scenarioactor | Membershiprol | Extra authority | Verwacht bereik |
| --- | --- | --- | --- |
| Stalowner | `owner` | server-side ownerregels | eigen stal beheren |
| Gedelegeerde beheerder | `admin` | alleen expliciete Horse-grants | team beheren binnen rolgrens |
| Ruiter/groom/trainer | `member` | grant en/of assignment | alleen toegewezen context |
| Lezer | `viewer` | expliciete view-grant | lezen, nooit muteren |
| Semantische Horse-owner | willekeurige actieve membership | expliciete Horse-grant | relatie alleen verleent niets |
| Ingetrokken gebruiker | suspended/revoked | geen | geen stal- of Horse-data |
| Cross-stable actor | actieve membership in andere stal | geen cross-stable grant | nul data uit doelstal |

Gebruik uitsluitend de UUID's en `example.invalid`-accounts uit
`docs/phase-5c-test-profiles.md`. Test Basis is het functionele startprofiel;
Medium bewijst normale teamomvang; Extreme bewijst de bovengrens van de
beoogde Alpha; Custom is alleen voor gerichte regressies. De volumes zijn geen
commerciële productlimieten.

## 3. Entrycriteria per testsessie

Een sessie start alleen wanneer alle vakken groen zijn:

- [ ] De gebruikte omgeving is expliciet `local` of later goedgekeurd
      `staging`, nooit productie.
- [ ] Git `HEAD`, trackingref en de bedoelde releasecommit zijn vastgelegd.
- [ ] FlutterFlow-projectcommit en buildtijd zijn vastgelegd.
- [ ] De testdata is fictief of afzonderlijk door de tester goedgekeurd.
- [ ] Geen wachtwoord, token, signed URL, objectpad of private media-inhoud
      staat in het testrecord.
- [ ] De database- en hostnaam zijn vóór reset of migratie gecontroleerd.
- [ ] Browserconsole en netwerklog worden alleen met geredigeerde waarden
      bewaard.
- [ ] Een incidentcontact en stopbevoegde testleider zijn aangewezen.

Leg iedere sessie vast met
`docs/templates/phase-5-alpha-test-session.md`.

## 4. Kernscenario's

| ID | Scenario | Positief bewijs | Verplichte negatieve tegenproef |
| --- | --- | --- | --- |
| TP-01 | registratie, verificatie, login, herstel | callback bereikt Auth Gate | verlopen/hergebruikte link en fout wachtwoord weigeren |
| TP-02 | onboarding en persoonlijk profiel | eigen profiel en avatar blijven na refresh | andere Auth-UUID kan profiel/avatar niet lezen |
| TP-03 | stalkeuze en accountwissel | A → B → A behoudt alleen eigen selectie | nooit een frame data van vorig account/stal |
| TP-04 | team en uitnodiging | fictieve uitnodiging eenmaal accepteren | replay, revoke en verkeerde ontvanger weigeren |
| TP-05 | Horse lifecycle | create, update, conflict en archive | viewer/outsider/cross-stable mutatie weigeren |
| TP-06 | Horse-relatie versus grant | relatie en grant afzonderlijk beheren | relatie alleen opent geen data |
| TP-07 | Planning en Today | drie routines, twee lokale dagen, assignment | niet-toegewezen member ziet geen taak |
| TP-08 | uitvoering | één taak exact eenmaal uitvoeren | retry maakt geen duplicaat |
| TP-09 | voeding | version, item, override, approve, activate, execution, correction | fout unit, overlap en oude row-version weigeren |
| TP-10 | private media | JPG/PDF upload, finalize, download en archive | type/maat/hash, outsider en revoked download weigeren |
| TP-11 | conflict | eigen niet-kritiek conflict met serverversie sluiten | andere actor/stal ziet of sluit niets |
| TP-12 | Realtime | wijzig in sessie A verschijnt in B | payload bevat geen domeindata |
| TP-13 | revoke | open sessie verliest data zonder refresh | oud topic en directe deeplink blijven geweigerd |
| TP-14 | browseroffline | gateway weg geeft purge en veilige fout | geen plaintext of lokale prototypefallback |
| TP-15 | navigatie/responsive | actieve en legacy routes, back, refresh en deeplink | geen dood scherm, overflow of lokale split-brain |

TP-01, TP-02, TP-04, TP-05, TP-06, TP-09, TP-10 en TP-11 moeten na een
goedgekeurde stagingdeployment nog als hosted browserjourney worden
vastgelegd. Lokale SQL-, RLS-, RPC-, Edge-, concurrency- en broncontracten
blijven ook dan verplicht; UI-zichtbaarheid vervangt nooit server-authority.

## 5. Viewport-, keyboard- en toegankelijkheidsmatrix

Test minimaal:

| Klasse | Viewport | Invoer |
| --- | --- | --- |
| mobiel | 390 × 844 | touch en softwarekeyboard |
| tablet | 820 × 1180 | touch en hardwarekeyboard |
| desktop | 1440 × 900 | keyboard en pointer |

Per actieve Alpha-route:

- [ ] geen horizontale overflow of verborgen primaire actie;
- [ ] logische tabvolgorde en zichtbare focus;
- [ ] Enter activeert alleen de bedoelde primaire actie;
- [ ] knoppen, velden en statusmeldingen hebben begrijpelijke labels;
- [ ] fouttekst gebruikt niet alleen kleur;
- [ ] tekst blijft bruikbaar bij 200% browserzoom;
- [ ] dialogen sluiten met Escape wanneer dit geen mutatie omzeilt;
- [ ] loading, empty, error, offline, denied en conflict hebben een
      herstelactie of expliciete uitleg.

## 6. Regressieprotocol

Voer vóór iedere stagingkandidaat in deze volgorde uit:

```sh
flutterflow ai upgrade --check
tool/test_phase_5b1_local.sh
tool/test_phase_5b2_upgrade_local.sh
tool/test_phase_5b2_local.sh
tool/test_phase_5b4_upgrade_local.sh
tool/test_phase_5b4_local.sh
tool/test_phase_5b5_local.sh
tool/test_phase_5c_local.sh --confirm-local-reset
tool/test_phase_5d1_local.sh --confirm-local-reset
tool/test_phase_5d2_local.sh --confirm-local-reset
tool/test_phase_5d3_local.sh --confirm-local-reset
tool/test_phase_5e_local.sh
```

Gebruik daarna de projectcompatibele Flutter 3.35.7-toolchain:

```sh
cd generated_code
../.flutterflow/sdk/flutter_3.35.7/bin/flutter pub get
../.flutterflow/sdk/flutter_3.35.7/bin/flutter analyze \
  --no-fatal-infos --no-fatal-warnings
../.flutterflow/sdk/flutter_3.35.7/bin/flutter build web --release --no-pub
```

De gegenereerde lintbaseline is vastgelegd in
`docs/phase-4a-supabase-setup.md`. Iedere nieuwe compile-error of stijging
moet worden onderzocht; gegenereerde bestanden worden nooit handmatig
gerepareerd.

## 7. Acceptatie- en stopcriteria

Een stagingkandidaat is technisch accepteerbaar wanneer:

- [ ] alle automatische gates exitcode 0 hebben;
- [ ] alle vijftien scenario's positief én negatief zijn vastgelegd;
- [ ] alle drie viewports en keyboardmatrix groen zijn;
- [ ] cross-account, cross-stable, revoked en outsider steeds fail-closed zijn;
- [ ] retry, idempotentie, Realtime en concurrency groen zijn;
- [ ] geen token, secret, signed URL, machinepad of echte persoonsgegevens in
      bewijs of Git staat;
- [ ] geen open P0, P1 of P2 bestaat;
- [ ] de bekende beperkingen door de testleider zijn geaccepteerd;
- [ ] juridische/privacyvoorwaarden voor echte testers afzonderlijk zijn
      goedgekeurd.

Stop de sessie onmiddellijk bij tenantlekkage, authbypass, plaintext
persistentie, onomkeerbaar gegevensverlies, onbekende externe target, een
echte uitnodiging of een onverwachte productieverbinding. Gebruik dan het
incidentrunbook; ga niet door om extra bewijs te verzamelen.

## 8. Korte instructie voor testers

1. Gebruik uitsluitend het toegewezen Alpha-account en deel het niet.
2. Voer alleen fictieve Horse-, team-, planning-, voeding- en mediagegevens in.
3. Test geen medische of veiligheidskritieke instructies.
4. Maak vóór iedere bevinding een korte route- en tijdnotitie.
5. Kopieer geen tokens, netwerkheaders, signed URLs of volledige consolelogs.
6. Stop direct wanneer data van een andere stal of gebruiker zichtbaar is.
7. Meld een probleem met het bugtemplate; meld mogelijk datalek of
   toegangsverlies via het incidentpad.
8. Verwijder na de sessie gedownloade testmedia en log uit.
