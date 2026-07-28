# AVARYN Fase 5E — staging- en deploymentgate

## 1. Gate-status

**Externe status: NIET GEAUTORISEERD.**

Deze gate bereidt een afzonderlijke besloten stagingwebalpha voor. Zij geeft
geen toestemming voor staging, productie, publicatie, domeinwijziging, echte
accounts, uitnodigingen of betaalde diensten.

Lokale technische baseline:

- Git-basis vóór fase 5E: `fd8e0de85f3bf5721cc3ccabaad262c544f11aa2`; de fase-5E-documentcommit wordt door de Git-gate vastgelegd;
- FlutterFlow: `273uNhvKI33OfF2VFdRi`;
- database: migraties tot en met `202607280005`;
- lokale webbuild: Flutter 3.35.7 release groen;
- workspace: 139/139 tests groen;
- fase 5D.3: reset, 4C.6 SQL, 50-voudige concurrency, Realtime-isolatie en
  live revoke groen.

## 2. Aanbevolen stagingroute

Aanbevolen is:

1. één nieuw, uitsluitend staging Supabase-project in een vooraf goedgekeurde
   regio en organisatie;
2. één FlutterFlow Development Environment `Staging` met uitsluitend de URL en
   publishable key van dat project;
3. publicatie op een afzonderlijk `flutterflow.app`-subdomein;
4. geen custom domein, PWA-offline, analytics, tracking, app-storebuild of
   productieverbinding voor de eerste besloten smoke;
5. eerst uitsluitend fictieve smokeaccounts; echte testers pas na de
   juridische/privacy- en accountverwijderingsgate.

FlutterFlow documenteert webpublicatie en gratis subdomeinen op
`https://docs.flutterflow.io/deployment/web-publishing/`. Afzonderlijke
FlutterFlow-omgevingen en Supabase-projecten worden beschreven op
`https://docs.flutterflow.io/testing/dev-environments/`.

## 3. Verwachte kosten en keuze

Prijzen moeten op de toestemmingsdatum opnieuw worden gecontroleerd.

| Onderdeel | Minimale smoke-optie | Aanbevolen voor echte Alpha |
| --- | --- | --- |
| FlutterFlow-hosting | gratis `flutterflow.app`-subdomein; maximaal twee custom subdomeinen op Free | huidig plan behouden; custom domein is niet nodig |
| FlutterFlow Development Environment | afhankelijk van huidig accountplan | Growth of hoger wanneer een extra environment nodig is |
| Supabase staging | Free: $0, maximaal twee actieve projecten; kan na lage activiteit pauzeren | Pro vanaf $25/maand voor niet-pauzerende service en dagelijkse backups |
| custom domein | niet nodig | pas later; FlutterFlow Basic staat vanaf $39/maand vermeld |
| PITR | niet nodig voor eerste smoke | alleen na risico-/kostenbesluit; betaald add-on plus geschikte compute |
| e-mailprovider | lokale Mailpit vóór staging; platformlimiet voor smoke | afzonderlijk goedgekeurde transactionele provider vóór echte uitnodigingen |

Officiële prijsbronnen:

- `https://supabase.com/pricing`;
- `https://flutterflow.io/pricing`;
- `https://supabase.com/docs/guides/platform/backups`.

## 4. Benodigde secrets en handmatige acties

Na expliciete toestemming zijn minimaal nodig:

- gekozen Supabase-organisatie, projectnaam en regio;
- nieuwe staging project-URL en uitsluitend de publishable clientkey;
- server-only secrets voor Edge Functions, nooit in FlutterFlow-code of Git;
- toegang tot FlutterFlow Web Deployment en zo nodig Development
  Environments;
- een goedgekeurd staging-subdomein;
- exacte Auth callback- en reset-URL's;
- keuze voor platformmail of een goedgekeurde transactionele e-mailprovider;
- aangewezen testleider, incidentcontact en privacycontact.

`FF_API_KEY` blijft uitsluitend via secure clipboard hand-off bruikbaar en
wordt nooit getoond, gelogd, opgeslagen of gecommit.

## 5. Externe uitvoeringsvolgorde na toestemming

1. Hercontroleer Git/remote, FlutterFlow-commit en alle lokale gates.
2. Maak het afzonderlijke Supabase-stagingproject aan.
3. Leg project-ID en regio vast zonder secrets te documenteren.
4. Pas migraties in volgorde toe op uitsluitend dit stagingproject.
5. Deploy de bestaande Edge Functions `stable-invitations`, `media-assets` en
   pas na afzonderlijke deletiongoedkeuring `delete-account`.
6. Controleer RLS, functie-ACL's, private bucket en cross-tenant denial.
7. Configureer exacte HTTPS callback- en reset-URL's zonder wildcard.
8. Maak de FlutterFlow-environment `Staging` en vul URL/publishable key via
   beveiligde configuratie in.
9. Publiceer naar het goedgekeurde FlutterFlow-stagingsubdomein.
10. Maak uitsluitend goedgekeurde fictieve smokeaccounts aan.
11. Voer auth-, Horse-, planning-, voeding-, media-, Realtime-, revoke-,
    responsive- en browserback/deeplink-smokes uit.
12. Voer één echte testnotificatie alleen uit wanneer daarvoor later een
    contractueel bestaande en expliciet goedgekeurde notificatieroute bestaat.
    De huidige repository bevat die niet; verzin er geen.
13. Audit logs, secrets, CORS, redirect allowlist en omgevingisolatie.
14. Vraag afzonderlijke toestemming voordat echte testers worden toegevoegd.

## 6. Rollbackplan

Voor de eerste publicatie:

- maak een logische stagingdatabasebackup;
- leg migratieversie, FlutterFlow-projectcommit en Git-commit vast;
- bewaar het vorige groene FlutterFlow-deploymentrecord;
- bewijs account- en datareset op staging met fictieve data.

Bij appregressie:

1. blokkeer nieuwe testers;
2. unpublish de stagingwebapp of publiceer de laatst groene
   FlutterFlow-versie;
3. wijzig de database niet terug wanneer dat security verlaagt;
4. voer na herstel de volledige smoke opnieuw uit.

Bij migratie- of dataprobleem:

1. stop stagingwrites;
2. geef de voorkeur aan een forward-fix;
3. herstel anders het hele stagingproject uit de expliciete pre-deploybackup;
4. voer alle migraties, RLS- en databehoudcontroles opnieuw uit;
5. heropen pas na onafhankelijke audit.

Supabase Free heeft geen beheerde dagelijkse backupgarantie. Voor een echte
Alpha is daarom Pro of een aantoonbaar uitgevoerde externe logische
backupdiscipline vereist.

## 7. Go/no-go-checklist

Technisch vóór staging:

- [ ] fase 5E-commit staat schoon op live `origin/main`;
- [ ] alle lokale runners en Flutter 3.35.7-webbuild zijn groen;
- [ ] geen open P0/P1/P2;
- [ ] stagingtarget, regio en accountplan zijn expliciet gekozen;
- [ ] kosten en eventuele upgrade zijn goedgekeurd;
- [ ] rollbackeigenaar en incidentcontact zijn aangewezen.

Vóór echte testers:

- [ ] privacyverklaring en voorwaarden zijn juridisch goedgekeurd en via HTTPS
      bereikbaar;
- [ ] DPA/subprocessors, regio, retentie en dataverwijdering zijn goedgekeurd;
- [ ] hosted auth-, invitation-, Horse-, media- en conflictjourneys zijn groen;
- [ ] accountverwijdering is uitvoerbaar en getest;
- [ ] e-mailafzender, templates, expiry, throttling en redirects zijn getest;
- [ ] uitsluitend expliciet goedgekeurde testers en minimale contactgegevens
      worden gebruikt;
- [ ] browseralpha is expliciet als online-only geaccepteerd.

Bij een leeg vak is de status `NO-GO`. Een technisch groene lokale build is
geen toestemming om te publiceren.
