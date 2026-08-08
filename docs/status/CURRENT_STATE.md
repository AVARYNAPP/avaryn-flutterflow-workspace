# AVARYN — Current State

Laatst bijgewerkt: 2026-08-08

## Huidige status

- **C-001:** afgerond. De read-only architectuuraudit adviseert het bestaande
  FlutterFlow-project te behouden en de stalgebonden backend grotendeels schoon
  te vervangen voor Account Model v2.
- **C-002:** technisch contract opgesteld.
- **C-002A:** formele reviewcorrecties op het technische contract uitgevoerd,
  inhoudelijk beoordeeld en definitief goedgekeurd door Silas de Steur op
  2026-08-04.
- **C-002A-besluit:** een organization-horse link wordt pas actief nadat de
  horse- en organizationcontext ieder afzonderlijk, expliciet en server-side
  geautoriseerd hebben bevestigd. De link zelf verleent geen toegang.
- **C-002B:** uitsluitend de lokale approval-statuscommit; geen wijziging van
  de goedgekeurde normatieve technische inhoud.
- **Contractstatus:** **Approved**.
- **Goedgekeurde inhoudscommit:**
  `4288944ae77cee9e1f0bf42f9369956b342e0097`.
- **C-003A:** lokaal geïmplementeerd en formeel goedgekeurd op de afzonderlijke
  taskbranch.
- **C-003A-status:** **Approved within the agreed scope**.
- **Datum securitygoedkeuring:** `2026-08-05`.
- **Goedgekeurde C-003A-implementatiecommit:**
  `7ecddccb6cf7dabea2a6597d8245b707f6110ff4`.
- **Goedgekeurde C-003A-hardeningcommit:**
  `09e3d1ef1f2efe30a94afd1ea23df4c7da6f724c`.
- Geïmplementeerd zijn uitsluitend duurzame personal profiles, de unieke
  nullable koppeling met `auth.uid()`, veilige Auth-provisioning, profile-
  lifecycle en versions, server-side actorafleiding, fail-closed profile-RLS,
  kolomgrants, append-only allowlisted audit en de lokale herstelbare
  deletion-/anonimiseringsbasis.
- De volledige migrationketen bouwt groen vanaf een lege geïsoleerde lokale
  database en de positieve/negatieve C-003A-securitytest is groen.
- De C-003A-security-hardening na handmatige review is lokaal uitgevoerd:
  `audit_events` is nu ook tegen owner-`TRUNCATE` beschermd, de volledige
  private-routine-inventaris (96 functies) heeft een catalogusgestuurde exacte
  allowlist en daadwerkelijke `anon`-/`authenticated`-/`service_role`-tests,
  en alle drie niet-actieve profilestatussen zijn expliciet fail-closed getest.
- De fresh build, bestaande fase-correcte SQL- en upgrade-regressies, zeven
  databaseconcurrencytests, C-003A-pgTAP-test, lint en catalogus-securitygate
  zijn groen. Alle C-003A P0/P1/P2-securitybevindingen zijn binnen de
  afgesproken scope gesloten.
- RLS, ACL's, server-side actorafleiding, audit-immutability inclusief
  `TRUNCATE`, de private-routineallowlist, lifecycleversioning en fail-closed
  profilestatussen zijn handmatig beoordeeld en goedgekeurd.
- Productiebrede dependencycleanup is nog niet afgerond en de trusted
  deletion-orchestrator is nog niet geïmplementeerd. Productieanonimisering mag
  daarom nog niet worden geactiveerd. De overkoepelende C-003F-securityaudit is
  op 2026-08-05 geslaagd. Deze productie-activatiebeperkingen maken de
  afgebakende C-003-goedkeuring niet opnieuw pending.
- C-003A is gereed en vormt na deze statuscommit de goedgekeurde basis voor een
  afzonderlijk uitgevoerde C-003B.
- **C-003B-status:** **C-003B — Approved within the agreed scope**.
- **Goedgekeurde C-003B-implementatiebasis:**
  `dfcc8db085785b7de4bf38ce5457019f4dc1b887`.
- C-003B implementeert lokaal de geïsoleerde organizationlaag met exact vijf
  organization types, organizations, verplichte scalar primary admin,
  memberships, organizationrollen en -permissions, role assignments,
  atomaire idempotente creatie, deferred primary-admininvariant, RLS/ACL,
  access-/row-versioning en PII-arme organization-audit.
- De C-003B-fresh build, C-003A- en C-003B-securitytests, fase-correcte
  functionele/upgrade-/concurrencyregressies, lint en catalogusgate zijn groen.
  Er zijn geen bekende open P0/P1/P2-bevindingen binnen de lokale afgebakende
  C-003B-scope; de implementatie is binnen die scope goedgekeurd.
- Legacy `stable_id` en stable memberships verlenen geen C-003B-authority en
  de bestaande stable-/horse-/applicatieobjecten bleven ongewijzigd.
- **C-003C-status:** **C-003C — Approved within the agreed scope**.
- **Goedgekeurde C-003C-implementatiecommit:**
  `1321da6366018d9d8a0a203a2fefde188ce7be69`.
- C-003C implementeert naast de ongewijzigde legacy `public.horses`-aggregate
  de geïsoleerde `canonical_horses`, exact één scalar primary authority,
  expliciete gedelegeerde horse-administratie, juridische ownerships,
  semantische horse-person relationships, residencyhistorie en wederzijds
  bevestigde organization-horse links. Alleen primary authority en expliciete,
  actuele delegated permissions verlenen C-003C-horse-access.
- Ownership, relationships, organization links, residency, legacy `stable_id`,
  clientstate en JWT-metadata verlenen geen impliciete horse-toegang.
- De C-003C-fresh build, securitytest, concurrency-race, gerichte C-003A/C-003B-
  regressies en legacy stable-/horse-regressies zijn groen. Er zijn geen bekende
  open P0/P1/P2-bevindingen binnen de lokale afgebakende C-003C-scope.
- C-003C is op basis van de uitgevoerde implementatie- en securitychecks
  goedgekeurd binnen de afgesproken scope en vormt de basis voor C-003D.
- **C-003D-status:** **C-003D — Approved within the agreed scope**.
- **Goedgekeurde C-003D-implementatiecommit:**
  `e940e956144cfa666be12f6d5c6d7ea383b44d20`.
- C-003D voegt expliciete tijdgeldige horse grants voor profiles en actieve
  organizationrollen toe, plus fail-closed organization- en horse-invitations
  met server-side actorafleiding, verified-Auth-e-mailbinding, HMAC-opslag,
  actuele authority-hercontrole, one-time tokens, lifecycleversioning en
  PII-arme audit. Relationships en organization-horse links kunnen grants
  uitsluitend begrenzen en bij beëindiging revoken; zij verlenen zelf niets.
- De afzonderlijke Rider Performance profile-/role-sharelaag is als expliciete
  securitygrens aanwezig; de feitelijke datamodule valt buiten C-003D.
- De C-003D-fresh build, securitytest, invitation-concurrencyrace, direct
  geraakte C-003A/B/C-regressies en catalogus-/RLS-/ACL-/EXECUTE-controles zijn
  groen. Er zijn geen bekende open P0/P1/P2-bevindingen binnen de afgebakende
  lokale C-003D-scope.
- **C-003E-status:** **C-003E — Approved within the agreed scope**.
- C-003E implementeert RPC-only, zeven dagen geldige horse-authority- en
  organization-headtransfers met server-side actorafleiding, HMAC-tokens,
  resource- en transferlocks, stale-versiondeny, idempotency, terminale
  immutable historie, versionrotatie en append-only audit. Organization-
  acceptatie wisselt membership, reserved head-adminrol en scalar primary admin
  atomair onder de deferred invariant.
- De C-003E-pgTAP-matrix en simultane acceptatieraces zijn groen: per transfer
  bestaat exact één winnaar, één terminale replaydeny en één scalar/version-
  overgang. Er zijn geen bekende C-003E P0/P1/P2-bevindingen.
- **C-003F-status:** **C-003F — PASS; Approved within the agreed scope**.
- De brede C-003F-eindgate over A–E is groen voor fresh build, volledige
  positieve/negatieve securitymatrices, concurrency, idempotency, expiry,
  spoofing, cross-tenantdeny, revocation/access-versioncache, service-role-
  misbruik, RLS/ACL/EXECUTE, `SECURITY DEFINER`, audit, gesloten directe
  realtimepaden, typed RPC-projecties en queryplannen.
- **C-003-status:** **C-003 — Fully completed; Approved within the agreed
  scope**. Er zijn geen bekende open C-003 P0/P1/P2-problemen.
- **Goedgekeurde C-003-eindcommit:**
  `4fee78c8b24099cf4eac254fd083f062827f1ee3`.
- **C-004-status:** **C-004 — Implemented locally – awaiting next gate**.
  Account Foundation v2 is inhoudelijk volledig afgedekt door de goedgekeurde
  C-003A–F-basis. C-004 voegt daarom geen parallel datamodel of migration toe,
  maar een zelfstandige acceptatiegate voor de bestaande identity-, tenant-,
  authority-, permission-, RLS/ACL-, audit- en versioninggrenzen.
- **C-005-status:** **C-005 — Implemented locally – awaiting next gate**.
  Het fail-closed stagingrunbook, targetguards, approvaltemplate, encrypted
  backup- en restoretooling, geordende resetprocedure, uitsluitend fictieve
  v2-seed en post-reset security-smoke zijn lokaal gereed.
- De C-004/C-005-verificatie is groen voor fresh migration build,
  C-004-acceptatie, direct relevante C-003F-regressie, v2-seed/smoke,
  productie- en targetdeny, seed-replaydeny, script-/secretcontroles en een
  daadwerkelijk lokaal herstel van de versleutelde full dump. Er zijn geen
  bekende open C-004/C-005 P0/P1/P2-problemen.
- **C-006-status:** **PASS — explicitly authorized staging reset, v2 seed and
  security smoke completed** op C-007-startcommit
  `b33d299065fb2d4f37dca7e42a5d52810c126a3e`. Back-up, checksums, restoretest,
  approvals en Auth-/Storage-/platformbewijs zijn extern en hashgebonden
  gecontroleerd; C-006 is geen C-007-blokkade meer.
- **C-007-status:** **C-007 — Approved within the current Alpha/Staging
  scope**. Silas heeft de contractuele scherm- en cutoverreview op `2026-08-08`
  expliciet goedgekeurd.
- C-007 sluit het persoonlijke Auth-/profiel-/onboardingpad aan op Account
  Foundation v2 met typed profielprojectie, server-side actorafleiding,
  row-version-CAS, fail-closed profielstatus, IANA-tijdzone, auth-UUID-gebonden
  avatarpaden, niet-persistente profielcache en PII-vrije append-only audit.
- De fresh migration build, C-007 RLS/ACL/actor/CAS/audit/lifecyclematrix,
  parallelle stale-writerrace, direct geraakte C-003F/C-004-gates en alle 172
  FlutterFlow/Dart-tests zijn lokaal groen. Er zijn geen bekende open C-007
  P0/P1/P2-code- of securitybevindingen. Na de scopewijziging zijn alle 173
  FlutterFlow/Dart-tests groen. Na de first-party e-maillinkhardening zijn alle
  `175` tests groen.
- De gevalideerde FlutterFlow-projectcommits zijn implementatie
  `TnNAmpLnN4O6OCfgTdSa` en gerichte foutafhandelingsfix
  `cpxFJHeuc2uVQxGBt80f`; de finale cleanuprevisie is
  `EO6gySfL4pU70Ext2Eaf`. De e-mail-only/privacyrevisie
  `uBZ2pyFPeB5nXYvFNzWC` is uitsluitend naar de bestaande Alpha-hosts
  gepubliceerd. De gevalideerde first-party e-maillinkrevisie
  `tIuGom3jTogDhabdK25X` is op `2026-08-08` naar beide bestaande Alpha-hosts
  gepubliceerd; beide hosts leverden cachevrij exact dezelfde nieuwe bundle.
- Stagingmigration `202608060001` en de teruggerolde inhoudelijke C-007
  RLS-/ACL-/actor-/CAS-/audit-/lifecycle-/avatarmatrix zijn **PASS**. Auth staat
  fail-closed op e-mailbevestiging, wachtwoordbeleid 8 + hoofdletter/kleine
  letter/cijfer, exacte redirects en uitgeschakelde anonymous/manual
  linking/Google/Apple. Storageconfiguratie en hosted callback-/resetsmokes zijn
  **PASS**; er bleef geen testuser achter.
- De publieke Alpha bevat versie `Alpha 2026-08-07` van de minimale
  privacyverklaring. Google, Apple en definitieve gebruiksvoorwaarden zijn
  expliciet uitgesteld tot na de eerste externe testerfase.
- De positieve signup-confirm-login-reset-onboarding-smoke is op `2026-08-08`
  volledig uitgevoerd. De bestaande Resend-SMTP-configuratie en de juiste
  Alpha-redirects zijn actief; Confirm Signup en Reset Password zijn
  geverifieerd als korte Nederlandstalige transactionele templates met
  `TokenHash`-links op `alpha.avaryn.eu` en zonder directe `ConfirmationURL`.
  De runtime verifieert exact getypeerde signup- en recoverylinks pas na een
  expliciete gebruikersklik, zodat mailprefetch geen eenmalige token verbruikt.
  Supabase registreert de eerdere signup- en recoveryrequests met status 200.
  DKIM en
  bounce-SPF zijn publiek aantoonbaar en de monitoringpolicy
  `TXT _dmarc.auth.avaryn.eu = v=DMARC1; p=none;` is toegevoegd en publiek
  geverifieerd; een nieuw Resend-rapport markeert DMARC als groen.
  Resend-tracking staat uit. Een Auth-mail naar `silas@de-steur.com` kwam in de
  inbox. Auth-mails naar `verkoop@vangilstbv.nl` en `info@vangilstbv.nl` zijn
  door Exchange Online met SMTP `250 2.6.0` geaccepteerd en staan niet op de
  Resend-suppressionlijst. Microsoft Message Trace bewees dat het tenantbeleid
  ze als high-confidence phishing (`SCL 8`) in `QuarantinedEmailSecured`
  plaatste. Eén specifiek testbericht is zonder brede mailflow-bypass
  vrijgegeven, kwam in Outlook aan en heeft het Staging-account succesvol
  bevestigd; callback, server-side profielbootstrap en `/onboarding` zijn
  **PASS**. Na verbruik van de token is het false positive als schoon bij
  Microsoft ingediend met een tijdelijk allow-verzoek voor uitsluitend de
  gedetecteerde berichtentiteiten; externe analyse is pending. De opdrachtgever
  bevestigt inmiddels ontvangst bij `vangilstbv.nl`; andere Microsoft 365-
  tenants zijn nog niet aantoonbaar groen en blijven een operationeel
  monitoringpunt. De first-party revisie is gepubliceerd. Een bestaande,
  aanvankelijk onbevestigde Staginggebruiker doorliep daarna bevestigingsmail,
  expliciete tokenverificatie, login, onboarding, resetmail, expliciete
  recoveryverificatie, nieuw wachtwoord en herlogin: **PASS**. Resend
  registreerde beide actuele transactionele mails als `delivered`; Supabase
  registreerde bevestiging en login. Silas heeft daarna de contractuele scherm-
  en cutoverreview expliciet goedgekeurd: **PASS**.
- **C-008-status:** **C-008 — Approved within the current Alpha/Staging
  scope**. Formele uitkomst: **HORSE AUTHORITY / TRANSFER ROUTE = PASS**.
- C-008 maakt het bestaande C-003C canonical horse het zelfstandige duurzame
  paardenaccount. Een paard heeft geen login of verplichte stal/organisatie,
  heeft exact één server-side primary Horse Authority en houdt juridisch
  eigendom, relaties, residency, gedelegeerd beheer en expliciete permissions
  afzonderlijk. Relaties, ownership en stalcontext verlenen geen impliciete
  toegang.
- Migration `202608080001_c008_canonical_horse_vertical` is transactioneel op
  exact AVARYN Staging toegepast en aan de migrationhistorie gebonden. De
  inhoudelijke hosted RLS-/ACL-/actor-/CAS-/ownership-/relationship-/delegation-
  /transfer-/audit-/legacybridgematrix is volledig teruggerold en groen; er
  bleef geen testuser of fixture achter. De postcheck bewijst authenticated-
  only RPC's, private-helperdeny, de legacybridge en nul active horses zonder
  primary authority.
- De FlutterFlow AI-SDK is na expliciete goedkeuring van build `2c299209` naar
  `b5c8a09d` geüpgraded. De volledige lokale suite is **183/183 PASS**;
  relevante SQL/security-, transfer-, concurrency-, Planning-, Feeding- en
  C-007-regressies en de C-008 custom-widgetanalyse zijn groen.
- FlutterFlowrevisies `rhTZQThF7kbDX671Nagg` en
  `YNqu1rA4Wts0ZafmrG8q` zijn gevalideerd en naar beide bestaande Alpha-hosts
  gepubliceerd. Beide hosts leveren identieke index-, serviceworker- en
  bundlebestanden. De cachevrije ingelogde schermreview op mobiel en desktop is
  groen voor de zelfstandige empty-state, createflow en transferontvangstflow;
  er is geen persistente testdata aangemaakt.
- Er zijn geen bekende open C-008 P0/P1/P2-code-, data- of
  securitybevindingen. Productie is niet gewijzigd.
- **C-009-status:** **C-009 — Approved within the current Alpha/Staging
  scope**. Formele uitkomst: **STABLE ACCOUNT / MEMBERSHIP / HORSE LINK ROUTE =
  PASS**. Silas heeft de scherm- en cutoverreview op `2026-08-08` expliciet
  goedgekeurd.
- C-009 maakt het stalaccount een zelfstandige canonical organization zonder
  login of gedeelde credentials. Exact één scalar Organization Authority,
  expliciete memberships, begrensde role templates, verified one-time
  invitations, bilaterale paard-stalkoppelingen, afzonderlijke residency en
  expliciete scoped horse grants blijven server-side en lifecycle-/CAS-
  beschermd.
- Membership, rol, actieve link en residency verlenen geen impliciete
  paardtoegang. Organization Authority-transfer hergebruikt uitsluitend de
  bewezen zeven dagen geldige C-003E-route; C-008 Horse Authority, Planning,
  Voeding en private media zijn niet herbouwd.
- Migration `202608080002_c009_stable_account_vertical` is transactioneel op
  exact AVARYN Staging toegepast en geregistreerd. Fresh build, de hosted
  teruggerolde Reimer Dressage-securitymatrix, invitation-/horse-/organization-
  transferconcurrency, direct geraakte C-003A–F/C-004/C-007/C-008-regressies,
  custom-widgetanalyse en alle **192/192** FlutterFlow/Dart-tests zijn groen.
  Er bleef geen C-009-testuser of fixture achter.
- FlutterFlowrevisie `HssI1OiCUzJNn9p7t2ya` is gevalideerd en uitsluitend naar
  de bestaande Alpha-hosts gepubliceerd. De cachevrije custom-domainroute toont
  de C-009-stalruntime; de menselijke scherm-/cutovergate is **PASS**.
- Er zijn geen bekende open C-009 P0/P1/P2-code-, data- of
  securitybevindingen. Productie, Git-push en merge zijn niet uitgevoerd en
  C-010 is niet gestart.
- De trusted deletion-orchestrator blijft ontbreken; accountverwijdering en
  productieanonimisering blijven fail-closed.

Het goedgekeurde contract staat in
[Account Model v2 Technical Contract](../architecture/ACCOUNT_MODEL_V2_TECHNICAL_CONTRACT.md).

## Repository- en FlutterFlow-basis

| Onderdeel | Waarde |
| --- | --- |
| Immutable snapshotbranch | `snapshot/latest-alpha-2026-08-04` |
| Snapshotcommit | `1634ef281084a76ae862fcb595dff8b08048ff48` |
| Actieve architectuurbranch | `architecture/account-model-v2-contract` |
| C-002A-basiscommit | `dc93b1c574eab185a95f9aa5113e65415d784d2a` |
| Goedgekeurde inhoudscommit | `4288944ae77cee9e1f0bf42f9369956b342e0097` |
| C-003A-branch | `implementation/account-model-v2-c003a-identity-audit` |
| C-003A-basiscommit | `5eb07f54ffa7464f8f7e325f8b112411936298e8` |
| Goedgekeurde C-003A-implementatiecommit | `7ecddccb6cf7dabea2a6597d8245b707f6110ff4` |
| Goedgekeurde C-003A-hardeningcommit | `09e3d1ef1f2efe30a94afd1ea23df4c7da6f724c` |
| C-003A-approvalstatuscommit / C-003B-basis | `cabf649ce34099b5aee7537652cbb667113f93fc` |
| C-003B-branch | `implementation/account-model-v2-c003b-organizations-memberships` |
| Goedgekeurde C-003B-implementatiebasis | `dfcc8db085785b7de4bf38ce5457019f4dc1b887` |
| C-003B-status | `Approved within the agreed scope` |
| C-003C-branch | `implementation/account-model-v2-c003c-canonical-horses` |
| Goedgekeurde C-003C-implementatiecommit | `1321da6366018d9d8a0a203a2fefde188ce7be69` |
| C-003C-status | `Approved within the agreed scope` |
| C-003D-branch | `implementation/account-model-v2-c003d-permissions-invitations` |
| Goedgekeurde C-003D-implementatiecommit | `e940e956144cfa666be12f6d5c6d7ea383b44d20` |
| C-003D-status | `Approved within the agreed scope` |
| C-003E/F-branch | `implementation/account-model-v2-c003e-f-transfers-security` |
| C-003E-status | `Approved within the agreed scope` |
| C-003F-status | `PASS; Approved within the agreed scope` |
| C-003-status | `Fully completed; Approved within the agreed scope` |
| Goedgekeurde C-003-eindcommit | `4fee78c8b24099cf4eac254fd083f062827f1ee3` |
| C-004/C-005-branch | `implementation/account-foundation-v2-c004-c005` |
| C-004-status | `Implemented locally – awaiting next gate` |
| C-005-status | `Implemented locally – awaiting next gate` |
| C-006-status | `PASS — staging reset, v2 seed and security smoke completed` |
| C-007-branch | `implementation/account-foundation-v2-c007-personal-auth-onboarding` |
| C-007-status | `Approved within the current Alpha/Staging scope` |
| C-008-branch | `implementation/account-foundation-v2-c008-horse-authority-transfer` |
| C-008-status | `Approved within the current Alpha/Staging scope; HORSE AUTHORITY / TRANSFER ROUTE = PASS` |
| C-009-branch | `implementation/account-foundation-v2-c009-stable-memberships-horse-link` |
| C-009-status | `Approved within the current Alpha/Staging scope; STABLE ACCOUNT / MEMBERSHIP / HORSE LINK ROUTE = PASS` |
| FlutterFlow-project | `a-v-a-r-y-n-alpha-ynvyuq` |
| FlutterFlow-revisie | `HssI1OiCUzJNn9p7t2ya` (published to both Alpha hosts) |
| Live Alpha | <https://alpha.avaryn.eu/> |
| Rollback-/fallback-URL | <https://avaryn-alpha.flutterflow.app/> |

De snapshotbranch is het bewijs- en rollbackpunt en mag niet worden gewijzigd.

## Bindende richting

- Alleen persoonlijke accounts authenticeren.
- Persoonlijke profiles, canonical horse accounts en organization accounts
  zijn zelfstandige duurzame entiteiten.
- `stable_id` is in v2 geen universele owner-, tenant-, workspace- of
  permissionbron.
- Relaties, eigendom, authority, memberships, rollen en permissions blijven
  afzonderlijke concepten.
- Professionele organization-horse links en fysieke horse residency zijn
  afzonderlijke concepten. Residency en een wederzijds bevestigde link geven
  geen impliciete toegang; daarvoor blijft een afzonderlijke permission grant
  vereist.
- Today is persoonsgebonden en onafhankelijk van het actieve workspacefilter.
- Bestaande fictieve testdata vereist geen compatibilitylaag.
- De browser blijft voorlopig online-first zonder persistente gevoelige
  volledige-offlinecache.

## Bekende documentatie- en toolchainpunten

- De complete Master Productblauwdruk is niet als zelfstandig bestand in de
  repository aangetroffen. Zij is in C-002 niet uit aannames gereconstrueerd;
  het technische contract is zelfstandig genoeg gemaakt voor de v2-kern.
- De lokale `generated_code`-snapshot verwijst in manifest/index naar
  gegenereerde FlutterFlow-bestanden die lokaal ontbreken. Dit is een bekende,
  afzonderlijke exportwaarschuwing en valt buiten C-002/C-002A.
- `flutterflow ai upgrade --check` meldde in C-002 op 2026-08-04 een nieuwere
  SDK-build (`2c299209` naar `b5c8a09d`, beide rapporteren versie `0.0.40`). De
  C-002A-check kon door een lokaal Dart-kernel-/netwerkprobleem niet afronden en
  de C-003A-/C-003C-checks misten `dart` op `PATH`. De upgrade is later binnen
  C-008 expliciet goedgekeurd en succesvol uitgevoerd; de finale check meldt
  `newer_available: false`.
- De live Alpha en rollback-URL zijn in C-001 read-only geobserveerd; C-002,
  C-002A en C-002B hebben geen live omgeving benaderd of gewijzigd.

## Afgeronde C-003-gates

C-003A tot en met C-003E zijn binnen de afgesproken scope goedgekeurd en de
C-003F-eindgate is volledig geslaagd. C-003 is daarmee volledig afgerond en
goedgekeurd binnen de afgesproken lokale scope:

1. C-003A — Identity and audit foundation;
2. C-003B — Organizations and memberships;
3. C-003C — Canonical horses and relationships;
4. C-003D — Explicit permissions and invitations;
5. C-003E — Atomic transfers;
6. C-003F — Security hardening gate.

De afzonderlijke implementatie- en testbewijzen staan in `docs/implementation`.
C-004 en C-005 zijn lokaal geïmplementeerd. De afzonderlijk geautoriseerde
C-006 Staging-run is geslaagd. C-007 heeft daarna uitsluitend het allowlisted
Staging-/Alpha-target gemigreerd, geconfigureerd, beveiligingstechnisch getest
en met de e-mail-only/privacy- en first-party e-maillinkrevisies gepubliceerd.
De echte e-maillevenscyclus en expliciete scherm-/cutoverapproval zijn groen;
C-007 is binnen de huidige Alpha/Staging-scope volledig afgerond. Productie,
Git-push en merge zijn niet uitgevoerd. C-008 heeft vervolgens uitsluitend de
canonical horse-/authority-/transfervertical op het allowlisted Staging-/Alpha-
target gemigreerd, securitytechnisch getest en gepubliceerd. De lokale en
hosted gates, concurrencybewijzen en cachevrije schermreview zijn groen;
C-008 is binnen de huidige Alpha/Staging-scope volledig afgerond. C-009 heeft
daarna uitsluitend de canonical stalaccount-/membership-/rollen-/bilaterale
horse-linkvertical op het allowlisted Staging-/Alpha-target gemigreerd,
securitytechnisch getest en gepubliceerd. De lokale en hosted gates,
concurrencybewijzen en expliciete scherm-/cutoverreview zijn groen; C-009 is
binnen de huidige Alpha/Staging-scope volledig afgerond. C-010 is niet gestart.
