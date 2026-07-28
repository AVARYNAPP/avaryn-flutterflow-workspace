# AVARYN Fase 5B.1 — Account-, stal-, team- en navigatiebasis

## Scope

Fase 5B.1 maakt de bestaande besloten-Alpha-instroom en authoritygrenzen
testklaar zonder nieuwe commerciële functionaliteit toe te voegen. De
afgeronde scope omvat:

- accountgate voor bevestiging, onboarding, uitnodiging en geselecteerde stal;
- wachtwoordherstel uitsluitend na het Supabase
  `AuthChangeEvent.passwordRecovery`;
- profiel- en avatarbeheer met private opslag, magic-bytecontrole en unieke
  versiepaden;
- server-side geselecteerde-stalvoorkeur met actieve-membershipcontrole;
- stalkeuze, stalbeheer, teamoverzicht, rollen en zelf verlaten;
- invitation hand-off vóór en na authenticatie zonder duurzame raw-tokenopslag;
- hervatten, accepteren en weigeren via een niet-geheime invitation-ID;
- fail-closed authority-invalidatie bij expliciete toegangsweigering;
- verwijdering van legacy-links, prototypecopy en doodlopende Alpha-navigatie;
- consistente mobiele, tablet- en desktopzichtbaarheid op de bestaande
  FlutterFlow-breakpoints.

Paardbeheer, planning/routines, voeding, media, Realtime/offline-sync en
conflictresolutie blijven hun eigen volgende fase-5B-subfasen.

## Security- en lifecyclecontract

### Account en herstel

- Een resetpagina is alleen bruikbaar nadat de actieve Supabase-authstream het
  echte `passwordRecovery`-event heeft geleverd.
- URL-fragmenten of queryparameters verlenen nooit zelfstandig
  recovery-authority.
- Logout wist de transiënte invitation-token en de niet-geheime
  invitation-ID uit AppState.

### Avatar

- JPEG, PNG en WebP worden door MIME-type én bestandsmagic gecontroleerd.
- Uploads gebruiken een nieuw
  `<auth-uuid>/avatar-<uuid>.<ext>`-object per versie.
- Een mislukte profielupdate verwijdert het nieuwe object compenserend.
- Het oude object wordt pas na een geslaagde profielupdate verwijderd.

### Stal- en teamauthority

- De servervoorkeur `account_workspace_preferences.last_selected_stable_id`
  wordt alleen geaccepteerd bij een actuele actieve membership.
- Offline membershipauthority is maximaal 24 uur oud en accepteert geen
  toekomstige timestamps.
- Een expliciete `401`, `403` of Postgres `42501` wist de actieve selectie,
  accountgebonden membershipcache en dezelfde authorityvelden in zowel
  `localAccountScopes` als `phase4BAccountOperationalBackups`.
- Een volgende accountwissel of transportfout kan ingetrokken authority
  daardoor niet uit een oudere lokale snapshot herstellen.

### Uitnodigingen

- De raw invitation-token blijft uitsluitend in niet-gepersisteerde AppState.
- Na veilige preview gebruikt de client alleen de niet-geheime invitation-ID;
  de server bindt die opnieuw aan de bevestigde e-mail van de actieve sessie.
- Onbekende RPC- en infrastructuurfouten geven HTTP 503 en behouden de
  hand-off voor een idempotente retry.
- `CONFIRMED_ACCOUNT_REQUIRED` en `DISPLAY_NAME_REQUIRED` geven HTTP 412,
  behouden token/ID en tonen een corrigeerbare melding.
- Definitief ongeldige, verlopen, ingetrokken of accountvreemde uitnodigingen
  worden fail-closed afgehandeld.
- Accept/decline gebruikt een deterministische request-ID; create-stable houdt
  dezelfde request-ID vast bij een ambigue response en wist hem pas na
  bevestigde activatie.

## Database en Edge

Migratie:

`supabase/migrations/202607270007_phase_5b1_invitation_resume.sql`

Toegevoegd of aangescherpt:

- veilige preview met invitation-ID voor een geldige pending token;
- `resume_stable_invitation(uuid)`;
- `accept_stable_invitation_by_id(...)`;
- `decline_stable_invitation_by_id(...)`;
- authenticated-only grants en expliciete `PUBLIC`-revokes;
- minimale terminale `accepted`/`declined`-responses voor ambigue retries;
- Edge-classificatie van definitieve, corrigeerbare en tijdelijke fouten.

Alle lokale fixtures gebruiken uitsluitend fictieve `.example.invalid`-data,
vaste UUID-scopes en een expliciete local-only guard. De SQL-acceptatiefixture
eindigt altijd met `ROLLBACK`.

## Reproduceerbare verificatie

Centrale local-only gate:

```sh
tool/test_phase_5b1_local.sh
```

Groene resultaten op 28 juli 2026:

- lege lokale Supabase-reset en migraties: groen;
- fase-4A-profiel/RLS, fase-4B-stal/security en fase-5B.1-acceptatie-SQL:
  groen;
- concurrency: 8/8 basisraces, 50/50 scenario 3 en 50/50 scenario 6;
- Auth, Storage en Recovery: 16/16;
- invitation- en Edge-integratie: 27/27;
- FlutterFlow AI-tests: 89/89;
- `git diff --check`, Ruby- en shellsyntaxis: groen;
- secrets-, token- en machinepadscan: schoon.

FlutterFlow-projectcommit:

`IWY1YaAsjF7TcE2tzLLn`

Deze corrigerende projectcommit volgt op de eerste 5B.1-export
`Nqj9k3dkEmmt4LOzddPP` en sluit de drie post-export gevonden
lifecyclebevindingen: recovery-authority over widgetinstances,
accountgate-denial en verwijdering van raw invitation-tokens uit de
browsergeschiedenis.

Project:

`a-v-a-r-y-n-consumer-app-8yb89s`

Na de projectcommit waren typed SDK en `generated_code/` vers. De
projectgebonden Flutter 3.35.7-toolchain gaf:

- volledige generated analyse: 0 errors;
- 1.688 warnings en 3.353 infos uit gegenereerde FlutterFlow-importen en
  stijllints;
- lokale release-webbuild: groen (`build/web`).

Flutter 3.44.8 is niet de projectbuildgate: de door FlutterFlow geëxporteerde
basispakketten `font_awesome_flutter 10.7.0` en `page_transition 2.1.0`
compileren niet tegen die nieuwere SDK. De reeds aanwezige, eerder groene
projecttoolchain 3.35.7 resolveert de compatibele transitive versies en bouwt
zonder compilefouten. `generated_code/` is niet handmatig aangepast.

## Audit en releasegrens

De finale bron- en lifecycle-audit rapporteerde geen P0, P1 of P2. De eerste
post-projectcommit-audit vond drie P1-lifecycleproblemen. Die zijn hersteld,
opnieuw als FlutterFlow-projectcommit geëxporteerd, gebouwd en getest. De
gerichte heraudit van de verse export `IWY1YaAsjF7TcE2tzLLn` rapporteerde
daarna geen P0, P1 of P2.

Deze fase heeft uitsluitend een FlutterFlow-projectcommit en lokale
test/buildhandelingen uitgevoerd. Er is geen webapp gepubliceerd, geen
staging- of productieomgeving aangemaakt en geen externe Supabase-migratie of
Edge-deployment uitgevoerd.
