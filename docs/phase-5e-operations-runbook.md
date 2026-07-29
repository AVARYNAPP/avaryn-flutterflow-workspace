# AVARYN Fase 5E — operationeel Alpha-runbook

## 1. Status en eigenaarschap

Dit runbook geldt voor lokale tests en, pas na expliciete toestemming, voor
een afzonderlijke stagingomgeving. Het bevat geen productieprocedure.

Voor een echte testsessie moeten vooraf namen of rollen worden ingevuld voor:

- testleider;
- technisch incidentleider;
- privacycontact;
- persoon die staging mag pauzeren;
- persoon die testaccounts mag verwijderen.

Geen van deze rollen mag een service-role- of andere serversecret in een
client, chat, ticket, screenshot of repository plaatsen.

## 2. Lokale provisioning en reset

De canonieke profielen staan in `docs/phase-5c-test-profiles.md`.

```sh
tool/provision_phase_5c_profile_local.sh basis --confirm-local-reset
tool/provision_phase_5c_profile_local.sh medium --confirm-local-reset
tool/provision_phase_5c_profile_local.sh extreme --confirm-local-reset
tool/provision_phase_5c_profile_local.sh custom --confirm-local-reset
```

Alleen leeg resetten:

```sh
tool/reset_phase_5c_local.sh --confirm-local-reset
```

De scripts moeten het exacte project-ID, een lokale Unix-Dockercontext en het
exacte containerlabel bewijzen. Stop bij iedere afwijking. Gebruik deze
commando's nooit tegen staging of productie; externe provisioning krijgt na
toestemming een afzonderlijk, expliciet target en een dry-runreview.

## 3. Staging Edge Function-configuratie

De besloten webalpha vereist in het afzonderlijke stagingproject:

```text
AVARYN_INVITATION_URL=https://avaryn-alpha.flutterflow.app/uitnodiging
```

Deze waarde is geen credential, maar wordt als server-side
Edge Function-omgevingswaarde beheerd. Zij mag nooit naar localhost, het
legacyproject of een productiehost verwijzen. De uitnodigingsfunctie voegt het
ruwe token uitsluitend als URL-fragment toe. De client promoveert dit eerst via
een anonieme serverpreview naar een niet-geheime invitation-ID en wist daarna
het fragment uit de adresbalk; alleen die ID mag de login-handoff overleven.

Alle Flutter web Edge Functions moeten in hun CORS-allowlist minimaal
`authorization, x-client-info, apikey, content-type` toelaten. Anders slaagt de
preflight wel, maar blokkeert de browser de daadwerkelijke geauthenticeerde
`POST`.

## 4. Bekende beperkingen

| ID | Beperking | Gevolg en beleid |
| --- | --- | --- |
| KL-01 | Browseroffline heeft geen goedgekeurde OS-backed sleutelopslag | webalpha blijft online-only en purget fail-closed |
| KL-02 | Native/desktop-offline is bron-, SQL- en concurrencygetest maar niet als formele native E2E | geen offlineclaim voor webtesters |
| KL-03 | FlutterFlow meldt vier nullable activity-draftwaarschuwingen | waarden zijn bewust leegbaar; cold-start/deeplink blijft staging-smokecriterium |
| KL-04 | Gegenereerde Fluttercode bevat bestaande lintwaarschuwingen | nul compile-errors vereist; generated code blijft read-only |
| KL-05 | `delete-account` verwijdert uitsluitend een zero-footprint account zonder Apple-identiteit, membership of historie | actieve rollen en historische referenties blijven fail-closed met `ACCOUNT_HISTORY_REQUIRES_ADMIN_REVIEW`; bredere verwijdering vereist een juridisch retentie- en beheerdersproces |
| KL-06 | Apple accountrevocation is niet geconfigureerd | Apple-login en accountverwijdering niet inschakelen |
| KL-07 | Juridische voorwaarden en privacytekst zijn niet repositorymatig goedgekeurd | geen echte testers vóór juridische goedkeuring |
| KL-08 | Notificatie/reminderbackend bestaat niet binnen het contract | niet beloven of testen als Alpha-feature |
| KL-09 | Gratis Supabase-projecten kunnen na lage activiteit pauzeren | alleen korte smoke; voor voorspelbare Alpha is betaald staging aanbevolen |

Geen bekende beperking mag worden gebruikt om RLS, autorisatie, purge,
idempotentie of tenantisolatie af te zwakken.

## 5. Incidentclassificatie

| Niveau | Voorbeeld | Eerste actie |
| --- | --- | --- |
| P0 | productie geraakt, secret openbaar, destructieve externe actie | alles stoppen, toegang intrekken, eigenaar informeren |
| P1 | cross-account/cross-stable datalek, authbypass, plaintextpersistentie | staging pauzeren, sessies intrekken, bewijs veiligstellen |
| P2 | verlies van testdata, revoke te laat, idempotentieduplicaat, geblokkeerde kernflow | nieuwe testers blokkeren, reproduceerbare fixture bewaren |
| P3 | tekst-, layout- of niet-blokkerende gebruiksbevinding | normaal bugproces |

Een mogelijk security- of privacyincident is nooit alleen een P3.

## 6. Incidentprocedure

1. Stop de test en noteer UTC-tijd, omgeving, releasecommit en actorlabel.
2. Deel geen ruwe tokens, headers, signed URLs, private media of echte data.
3. Pauzeer alleen de expliciet getroffen stagingomgeving; raak productie niet
   aan.
4. Trek zo nodig de getroffen membership/grant in via de bestaande
   server-authority. Bevestig topicrotatie, device revoke en clientpurge.
5. Bewaar minimale geredigeerde request-ID's, foutcode en stappen.
6. Classificeer P0–P3 en wijs één eigenaar toe.
7. Reproduceer uitsluitend lokaal met een fase-5C-profiel.
8. Herstel via een nieuwe migratie of FlutterFlow-projectcommit; wijzig geen
   gegenereerde output en herschrijf geen Git-geschiedenis.
9. Herhaal de volledige relevante runner plus cross-tenant en revoked
   tegenproeven.
10. Sluit het incident pas nadat rollback/herstel, gegevensscope en
    vervolgactie onafhankelijk zijn gecontroleerd.

Gebruik `docs/templates/phase-5-alpha-incident-record.md`.

## 7. Herstelvolgorde

Bij een appregressie:

1. blokkeer nieuwe tests;
2. publiceer niets nieuws;
3. selecteer de laatst aantoonbaar groene FlutterFlow-projectcommit;
4. laat databasewijzigingen staan wanneer terugdraaien security kan verlagen;
5. herstel de app alleen na een lokale build en smoke;
6. documenteer welk gedrag tijdelijk niet beschikbaar is.

Bij een database- of migratieprobleem:

1. stop writes naar de getroffen stagingomgeving;
2. maak geen ad-hoc destructieve correctie;
3. bepaal of een forward-fix veilig is;
4. gebruik anders de expliciet vóór deployment gemaakte logische backup of
   het goedgekeurde platformherstelpunt;
5. voer migraties opnieuw uit op een disposable kopie;
6. bewijs RLS, privileges, aantallen en databehoud vóór heropening.

Securitymigraties worden niet teruggedraaid naar een bekend onveilig beleid om
beschikbaarheid te herstellen.

## 8. Testaccount- en gegevensverwijdering

De Edge Function ondersteunt een harde zelfbedieningsverwijdering uitsluitend
voor een zero-footprint account zonder Apple-identiteit, actieve of historische
membership en zonder meer dan 999 avatarobjecten. Zij verwijdert eerst
avatarobjecten via de server-only Storage-client en daarna de Auth-UUID. Actieve
owners/members en iedere historische membership blijven fail-closed. Apple-
revocation is niet geconfigureerd.

Voor een goedgekeurd stagingtestaccount:

1. bevestig de exacte Auth-UUID; gebruik nooit e-mail of naam als identity;
2. draag actieve stalownership over of archiveer de fictieve stal volgens het
   bestaande ownercontract;
3. suspend/remove alle memberships en trek Horse-grants in;
4. bevestig authorityrotatie, device revoke en datapurging;
5. archiveer of verwijder private testmedia volgens de goedgekeurde
   retentie-instructie;
6. verwijder het Auth-account uitsluitend met server-side
   beheerdersbevoegdheid in de exacte stagingomgeving en pas nadat het
   goedgekeurde retentie-/pseudonimiseringsbesluit alle niet-null audit-FK's
   afdekt;
7. controleer dat geen actieve membership, grant, device of Storage-object
   bereikbaar blijft;
8. leg alleen Auth-UUID, tijd, uitvoerder en resultaat vast; geen secret of
   verwijderde inhoud.

Audit- en securityevents kunnen wettelijke of beveiligingsretentie hebben en
worden niet automatisch gewist. De exacte bewaartermijn en omgang met
backups vereisen vóór echte testers juridische/privacygoedkeuring.

De lokale integratiesuite bewijst daarnaast dat een volledig ongebruikt
fictief account na `ACCOUNT_DELETED` niet meer via de Auth Admin API bestaat.
Lokale fixtureaccounts met historie worden verder alleen verwijderd door de
expliciete lokale resettools. Productieaccounts vallen buiten dit runbook.

## 9. Feedback en bugmeldingen

Gebruik uitsluitend:

- `docs/templates/phase-5-alpha-bug-report.md`;
- `docs/templates/phase-5-alpha-incident-record.md`;
- `docs/templates/phase-5-alpha-test-session.md`.

Gebruik een willekeurige tester-ID in plaats van naam of e-mail. Voeg geen
analytics-, crashreporting-, tracking- of externe feedback-SDK toe. Screenshots
worden vooraf gecontroleerd op persoonsgegevens, tokens, browserstorage,
signed URLs en private media.

## 10. Juridische en privacyvoorwaarden vóór echte testers

De volgende onderdelen zijn deploymentvoorwaarden en geen door Codex
ingevulde juridische garanties:

- goedgekeurde privacyverklaring met verwerkingsdoelen, categorieën,
  ontvangers, bewaartermijnen en rechten;
- goedgekeurde gebruiksvoorwaarden voor de besloten Alpha;
- verwerkersovereenkomst en subprocessorreview voor Supabase, FlutterFlow en
  eventuele e-mailprovider;
- gekozen Supabase-regio en internationale-doorgiftebeoordeling;
- grondslag en toestemmings-/uitnodigingsproces voor testercontactgegevens;
- proces voor inzage, correctie, verwijdering en bezwaar;
- retentiebeleid voor profielen, operationele data, private media, auditlogs,
  backups en bugbewijs;
- incidentmeldings- en contactprocedure;
- verbod of afzonderlijk beleid voor minderjarigen;
- expliciete melding dat AVARYN geen medisch advies of autonome behandel- of
  voerbeslissingen levert;
- werkende HTTPS-URL's voor privacy en voorwaarden;
- juridisch beoordeelde accountverwijdering, inclusief Apple wanneer die
  provider wordt ingeschakeld.

Zonder schriftelijke eigenaar-/juridische goedkeuring worden
geen echte testers uitgenodigd.
