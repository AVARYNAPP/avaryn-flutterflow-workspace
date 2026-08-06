# C-007 — Persoonlijk account + Auth/onboarding

Datum lokale uitvoering: `2026-08-06`

Status: **Implemented locally and committed to the FlutterFlow project — staging gate blocked**.

## Verticale slice

C-007 sluit de bestaande Auth- en onboardinginterface aan op Account Foundation
v2. Een Auth-UUID is alleen de externe identiteit en lokale cache-namespace;
het duurzame `profiles.id` blijft een afzonderlijke server-gegenereerde UUID.

- Auth ondersteunt e-mail/wachtwoord, e-mailverificatie, neutrale
  wachtwoordreset, herstel-eventbinding en de bestaande Apple-/Google-ingangen.
- Profielbootstrap gebruikt uitsluitend de typed
  `get_current_account_profile()`-projectie. De client maakt geen profile aan,
  leest geen beperkte profilekolommen rechtstreeks en ontleent geen authority
  aan Auth- of JWT-metadata.
- Profiel- en onboardingmutaties gebruiken uitsluitend
  `update_current_account_profile(...)`, met server-side actorafleiding,
  `row_version`-CAS, invoervalidatie en fail-closed profilestatus.
- Voornaam, achternaam, telefoon, locale, IANA-tijdzone, thema,
  onboardingintentie en eenmalige completiontimestamp worden server-side
  verwerkt. De onboardingintentie verleent geen organization-, horse-, role-
  of permissionauthority.
- Avatarpaden zijn aan de Auth-UUID gebonden. Een upload wordt bij een
  mislukte profielwrite gecompenseerd; verwijderen wist eerst de autoritatieve
  databasereferentie en laat bij Storage-falen hoogstens een niet-autoriserend
  orphanobject achter.
- De persoonlijke profielprojectie is niet persistent in FlutterFlow App
  State. `profile_id`, `status`, `access_version` en `row_version` blijven wel
  beschikbaar voor de actuele in-memory sessie.
- Accountwijzigingen schrijven alleen veldnamen en versies naar de append-only
  audit; namen, telefoon, e-mail en Auth-metadata worden niet gelogd.

FlutterFlow-projectcommits: implementatie `TnNAmpLnN4O6OCfgTdSa`, gevolgd door
de gerichte foutafhandelingsfix `cpxFJHeuc2uVQxGBt80f`, op project
`a-v-a-r-y-n-alpha-ynvyuq`. De finale cleanuprevisie is
`EO6gySfL4pU70Ext2Eaf`. Dit is geen publicatie of deployment.

## Lokale gates

- Fresh migration build vanaf leeg, inclusief C-003A–E en C-007: **PASS**.
- C-007 positieve/negatieve RLS-, ACL-, actor-, CAS-, audit-, lifecycle- en
  avatarsecuritymatrix: **PASS**.
- Parallelle profielwrite: exact één winnaar en één `PROFILE_VERSION_STALE`:
  **PASS**.
- Direct geraakte C-003F-catalogus/securitygate en C-004-acceptatie: **PASS**.
- Volledige FlutterFlow/Dart-suite: **PASS** (`172` tests).
- FlutterFlow DSL-validatie en projectcommit: **PASS**.
- Finale `generated_code`-snapshot: **fresh**; gerichte analyse van de vier
  C-007-runtime/schema/UI-bestanden bevat geen compile- of analyzererror.
- `git diff --check` en secretscan op embedded credentials/keys: **PASS**.

## Externe staging-/releasegate

C-007 kan niet veilig naar staging worden gemigreerd of daar end-to-end worden
bewezen zolang de voorafgaande C-006 stagingreset en Account Foundation v2-seed
niet aantoonbaar zijn afgerond. In deze sessie ontbreken daarnaast de
contractuele stagingconfiguratie, databasecredentials, twee afzonderlijke
approvals, encryptiepassphrase en Auth-/Storage-/platformbewijs. Daarom zijn
geen stagingdatabaseverbinding, migration, seed, Auth-/Storagewijziging of
remote smoke uitgevoerd.

Vóór stagingvrijgave zijn bovendien redacted bewijzen nodig voor Apple/Google,
redirect-URL's en de juridische URL-configuratie. De trusted
deletion-orchestrator blijft een eerder geaccepteerde productiebeperking;
accountverwijdering blijft fail-closed en productieanonimisering mag niet worden
geactiveerd.

De lokale code heeft geen bekende open C-007 P0/P1/P2-securitybevinding. C-007
blijft formeel pending totdat de externe staging-/securitygate is uitgevoerd en
goedgekeurd.
