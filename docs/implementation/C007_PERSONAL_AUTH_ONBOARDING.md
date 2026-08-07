# C-007 — Persoonlijk account + Auth/onboarding

Datum lokale uitvoering: `2026-08-06`
Datum Staging-/securitygate: `2026-08-08`

Status: **C-007 — Approved within the current Alpha/Staging scope**.

Silas heeft de contractuele scherm- en cutoverreview op `2026-08-08`
expliciet goedgekeurd voor de huidige Alpha/Staging-scope.

## Verticale slice

C-007 sluit de bestaande Auth- en onboardinginterface aan op Account Foundation
v2. Een Auth-UUID is alleen de externe identiteit en lokale cache-namespace;
het duurzame `profiles.id` blijft een afzonderlijke server-gegenereerde UUID.

- Auth ondersteunt voor de eerste externe testerfase uitsluitend
  e-mail/wachtwoord, e-mailverificatie, neutrale wachtwoordreset en
  herstel-eventbinding. Google en Apple zijn bewust uitgesteld en zijn niet
  geconfigureerd of zichtbaar in de testerinterface.
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
`EO6gySfL4pU70Ext2Eaf`. De e-mail-only/privacyrevisie is
`uBZ2pyFPeB5nXYvFNzWC` en is op `2026-08-07` uitsluitend naar de bestaande
Alpha-hosts gepubliceerd. De first-party e-maillinkrevisie
`tIuGom3jTogDhabdK25X` is gevalideerd, naar het Alpha-project gepusht en op
`2026-08-08` naar beide bestaande Alpha-hosts gepubliceerd. Een cachevrije
controle gaf voor beide hosts exact bundlehash
`34fe4a9b193005e8487d926d90e7a24fa8c040ed460671f84bfa71bb78e94cb0`.

## Lokale gates

- Fresh migration build vanaf leeg, inclusief C-003A–E en C-007: **PASS**.
- C-007 positieve/negatieve RLS-, ACL-, actor-, CAS-, audit-, lifecycle- en
  avatarsecuritymatrix: **PASS**.
- Parallelle profielwrite: exact één winnaar en één `PROFILE_VERSION_STALE`:
  **PASS**.
- Direct geraakte C-003F-catalogus/securitygate en C-004-acceptatie: **PASS**.
- Volledige FlutterFlow/Dart-suite: **PASS** (`175` tests).
- FlutterFlow DSL-validatie en projectcommit: **PASS**.
- Finale `generated_code`-snapshot: **fresh**; de gerichte analyse van de
  gegenereerde C-007-runtime bevat geen compile- of analyzererror.
- `git diff --check` en secretscan op embedded credentials/keys: **PASS**.

## Externe Staging-/securitygate

De C-006-reset, v2-seed en securitysmoke zijn aantoonbaar geslaagd op
startcommit `b33d299065fb2d4f37dca7e42a5d52810c126a3e`. De release-chain naar de
lokale C-007-implementatiecommit
`62d96c183b62644a8350749f52c347ea26776f4c` is gecontroleerd.

- Exact target: Supabaseproject `ipdovjdtnfslrftvrdrl` (`AVARYN Staging`) en
  FlutterFlowproject `a-v-a-r-y-n-alpha-ynvyuq` (`AVARYN Alpha`).
- Forward migration `202608060001_c007_personal_auth_onboarding` is atomisch
  toegepast en aan `supabase_migrations.schema_migrations` gebonden: **PASS**.
- De volledige C-007 RLS-/ACL-/actor-/CAS-/audit-/lifecycle-/avatarmatrix is op
  Staging in één teruggerolde testtransactie uitgevoerd: **PASS**. PgTAP is op
  hosted Staging niet geïnstalleerd; alleen de PgTAP-wrapper is voor deze run
  weggelaten, alle inhoudelijke checks bleven identiek. Geen testuser bleef
  achter.
- Auth: signup en e-mailprovider aan; e-mailbevestiging aan; anonieme login,
  manual linking, Google en Apple uit; wachtwoord minimaal 8 tekens met
  hoofdletter, kleine letter en cijfer; OTP 8 tekens en 3600 seconden: **PASS**.
- Custom SMTP gebruikt op Staging de bestaande Resend-configuratie met
  afzender `AVARYN <no-reply@auth.avaryn.eu>`; credentials zijn niet bekeken of
  gewijzigd. Signup- en recoveryrequests zijn in Supabase Auth met status 200
  en de juiste Alpha-referer verwerkt. Confirm Signup en Reset Password zijn
  beperkt tot korte Nederlandstalige transactionele templates. Signup gebruikt
  `{{ .SiteURL }}/auth/callback?token_hash={{ .TokenHash }}&type=email` en
  recovery gebruikt
  `{{ .SiteURL }}/auth/reset-password?token_hash={{ .TokenHash }}&type=recovery`;
  directe `ConfirmationURL`-links zijn verwijderd: **PASS**.
- Site URL en redirects zijn exact de twee callback- en resetpaden op
  `alpha.avaryn.eu` plus dezelfde twee fallbackpaden: **PASS**.
- Storagebucket `avatars` is private, 5 MB, jpeg/png/webp en heeft exact vier
  auth-UUID-gebonden policies; `horse-media` blijft zonder clientpolicy:
  **PASS**.
- De nieuwe FlutterFlowrevisie is succesvol gepubliceerd naar
  `https://alpha.avaryn.eu` en `https://avaryn-alpha.flutterflow.app`. Beide
  hosts serveren dezelfde bundle. De fallbackhost bewijst de publieke
  `/privacy`-route, uitsluitend e-mailaanmelding, fail-closed callback en
  fail-closed reset zonder recovery-authority: **PASS**.

De ingebouwde Supabase-maildienst is alleen bruikbaar voor geautoriseerde
Supabase-organisatieleden, heeft een projectbrede limiet van twee berichten per
uur en is niet geschikt voor externe testers. Daarom gebruikt Staging custom
Resend-SMTP. Credentials zijn niet in Git, bewijs of chat opgenomen.

De directe Resend-test is door de opdrachtgever als ontvangen bevestigd bij
Gmail en als spam bij `vangilstbv.nl`. Een actuele Auth-mail naar
`silas@de-steur.com` kwam normaal in de inbox. Actuele Auth-mails naar
`verkoop@vangilstbv.nl` en `info@vangilstbv.nl` bleven onzichtbaar, maar Resend
registreert geen suppression, bounce of complaint. Exchange Online accepteerde
beide berichten expliciet met SMTP `250 2.6.0`. Microsoft Message Trace en de
beheerquarantaine bewezen vervolgens dat het tenantbeleid de eerdere Auth-mails als
high-confidence phishing (`SCL 8`) classificeerde en in
`QuarantinedEmailSecured` afleverde. Ook de trace met status `Resolved` voor
`info@vangilstbv.nl` eindigde feitelijk in die quarantainefolder. Dit is geen
SMTP- of DNS-fout aan AVARYN-zijde.

Publieke DNS-controle bewijst een geldige Resend-DKIM-record en bounce-MX/SPF op
`send.auth.avaryn.eu`. Op `2026-08-07` is de expliciete monitoringpolicy
`TXT _dmarc.auth.avaryn.eu = v=DMARC1; p=none;` toegevoegd en publiek
teruggelezen: **PASS**. Een nieuw Resend-insightsrapport markeert DMARC nu als
groen. Resend-tracking is niet geconfigureerd; plain text en kleine imageloze
bodies zijn groen. Een replyable alias mag pas worden gebruikt wanneer deze
werkelijk wordt bewaakt. De actieve Confirm Signup- en Reset Password-templates
zijn opnieuw opgeslagen als korte Nederlandstalige transactionele Alpha-
templates met links op `alpha.avaryn.eu`. De FlutterFlow-runtime verwerkt deze
links fail-closed op exact `type=email` of `type=recovery`, valideert een
begrensde `token_hash` en roept `verifyOTP` pas na een expliciete gebruikersklik
aan. Microsoft Safe Links en andere mailprefetchers kunnen de eenmalige token
daarmee niet meer door alleen linkinspectie verbruiken. De volledige
Microsoft-beheercontrole is uitgevoerd. Eén specifiek bericht is zonder brede
mailflow-bypass vrijgegeven, kwam aantoonbaar in Outlook aan en bevestigde het
Staging-account succesvol. De callback, server-side profielbootstrap en route
naar `/onboarding` zijn daarmee **PASS**. Nadat de token was verbruikt is
hetzelfde false positive als schoon bij Microsoft ingediend, met een tijdelijk
allow-verzoek voor uitsluitend de gedetecteerde berichtentiteiten; analyse en
activering daarvan zijn extern pending. De opdrachtgever heeft daarna bevestigd
dat de mails bij `vangilstbv.nl` binnenkomen. Algemene deliverability bij andere
Microsoft 365-tenants is nog niet als PASS bewezen en blijft een operationeel
monitoringpunt, niet een C-007-code- of Stagingblocker.

Na publicatie van de first-party runtime is op `2026-08-08` met een bestaande,
nog onbevestigde Staginggebruiker de volledige echte e-maillevenscyclus
doorlopen: bevestigingsmail ontvangen, expliciete first-party tokenverificatie,
bevestigde login, profielbootstrap, onboarding, resetrequest vanuit de app,
ontvangen resetmail, expliciete recoveryverificatie, nieuw wachtwoord en
herlogin. Supabase registreerde bevestiging en login; Resend registreerde zowel
de actuele bevestigingsmail als resetmail als `delivered`. De opdrachtgever
bevestigde afzonderlijk dat login en onboarding werken: **PASS**. Er zijn geen
accounts verwijderd en geen productieacties uitgevoerd.

De ingebouwde minimale Alpha-privacyverklaring is versie `Alpha 2026-08-07`.
Definitieve gebruiksvoorwaarden en Google-/Apple-configuratie zijn expliciet
uitgesteld tot na de eerste externe testerfase; dit heropent de afgebakende
C-007-code- en databasegate niet. De trusted deletion-orchestrator blijft een
eerder geaccepteerde productiebeperking; accountverwijdering blijft fail-closed
en productieanonimisering mag niet worden geactiveerd.

Er is geen bekende open C-007 P0/P1/P2-code- of securitybevinding. De positieve
e-maillevenscyclus op Staging is bewezen en Silas heeft de contractuele scherm-
en cutoverreview expliciet goedgekeurd. C-007 is daarmee volledig afgerond
binnen de huidige Alpha/Staging-scope.
