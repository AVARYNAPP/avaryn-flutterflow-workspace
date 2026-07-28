# AVARYN Fase 5D.2 — Voedingsacceptatie

## Scope

Deze subfase sluit de functioneel onvolledige Alpha-eisen A16, A34 en A35
aan op het bestaande fase-4C.4-contract. Er wordt geen tweede voedingsmodel
gemaakt. De FlutterFlow-runtime gebruikt uitsluitend de bestaande RLS-tabellen
en mutatie-RPC's voor:

- standaard- en tijdelijke voerplannen;
- een eerste draftversie en latere expliciete versies;
- voeritems met exacte unit, ronde, lokale tijd en duurzame `override_key`;
- een optionele verantwoordelijke uit het actieve stalroster;
- goedkeuring, activatie en retirement als afzonderlijke stappen;
- feitelijke uitvoering en append-only correctie.

Automatische eenheidsconversie, professioneel of medisch advies en wijziging
van goedgekeurde historie blijven buiten scope.

## Atomische start en duurzame retries

Migratie `202607280004_phase_5d2_feeding_atomic_flow.sql` voegt alleen
`create_feeding_plan_with_version` toe. De wrapper voert
`create_feeding_plan` en `create_feeding_plan_version` in één
databasetransactie uit. De twee onderliggende request-ID's moeten verschillend
zijn en blijven bij een ambigue transportuitkomst exact gelijk.

De client bewaart ieder nog niet definitief verwerkt requestrecord uitsluitend
in de account- en stalgebonden secure-storage-scope. De vastgelegde replaydata
bevat geen token, signed URL of mediabyte. Logout, accountwissel, stalwissel,
revoke en authorityrotatie sluiten gevoelige dialogs, verhogen de
stategeneratie en wissen de lokale scope voordat een bevestigde mutatie wordt
verzonden.

## Plan- en itemlifecycle

Een tester kan:

1. een standaardplan of begrensde tijdelijke override starten;
2. een draftitem toevoegen of conflictveilig wijzigen;
3. voor een standaarditem een blijvende slotsleutel vastleggen;
4. voor een tijdelijk item uitsluitend een slotsleutel uit het actieve
   standaardplan kiezen;
5. een verantwoordelijke selecteren zonder dat de client authority verleent;
6. een niet-lege draftversie expliciet goedkeuren;
7. een goedgekeurde versie maximaal dertig lokale dagen vooruit activeren;
8. voor latere wijzigingen een nieuwe versie starten;
9. een plan met reden stoppen zonder uitvoeringshistorie te verwijderen.

RLS en RPC-authority blijven beslissend. Een zichtbare knop, rosternaam,
semantische Horse-relatie of clientrol verleent geen recht.

## Uitvoering en correctie

De voerronde toont alleen taken uit `list_today_schedule`. Feitelijke
hoeveelheid, unit, restant en afwijking worden duurzaam met exact dezelfde
request-ID en payload herhaald. Een afgeronde voertaak krijgt de actuele
execution-ID via `list_schedule_executions`.

Een correctie:

- verwijst met `corrects_execution_id` naar de oorspronkelijke uitvoering;
- schrijft een nieuwe `schedule_execution` en
  `feeding_execution_detail`;
- wijzigt of verwijdert de oorspronkelijke registratie nooit;
- gebruikt dezelfde RLS-, assignment- en execute-authority als de eerste
  registratie.

## Reproduceerbaar lokaal bewijs

Alle onderstaande data is fictief en lokaal. De runner vereist de expliciete
resetvlag, de exacte Supabase-projectlabel en een lokale Dockercontext:

```sh
tool/test_phase_5d2_local.sh --confirm-local-reset
```

De runner bewijst:

- lege reset en migratie tot en met `202607280004`;
- deterministische Basis-provisioning en RLS-verificatie;
- atomische plan-/versiereplay;
- tijdelijke exact-slotvervanging over twee lokale dagen;
- assigned-only toegang voor een groom zonder brede Horse-grant;
- feitelijke uitvoering plus append-only correctie;
- idempotente correctiereplay;
- cross-stable en revoked read/write denial;
- twee volledige 4C.4-concurrencyruns;
- alle FlutterFlow-workspacetests.

De lokaal meegeleverde Supabase CLI kan na een volledig toegepaste reset
incidenteel een `502` op zijn laatste health-probe retourneren. De runner
vervolgt dan alleen wanneer hij afzonderlijk bewijst dat `auth.users` leeg is
en migratie `202607280004` exact eenmaal geregistreerd staat. Iedere andere
toestand stopt fail-closed.

## Handmatige Alpha-acceptatie

Gebruik een fictief Basis-profiel:

1. Start een standaardplan, voeg een dagelijks voerslot toe en selecteer een
   groom.
2. Keur de versie goed en activeer haar.
3. Controleer de gematerialiseerde voertaak op twee lokale dagen.
4. Start een tijdelijke override en kies exact het standaardslot.
5. Controleer dat andere voerslots niet worden vervangen.
6. Open als toegewezen groom en registreer hoeveelheid, unit, restant en
   afwijking.
7. Voeg een correctie toe en bevestig dat beide registraties zichtbaar blijven.
8. Open als gebruiker van stal B en als ingetrokken gebruiker; geen plan,
   item of uitvoering uit stal A mag bereikbaar zijn.
9. Trek tijdens een open dialog toegang in; de dialog moet sluiten en de
   bevestiging mag geen mutatie uitvoeren.

Er is geen staging-, publicatie- of productiehandeling uitgevoerd.
