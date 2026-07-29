# AVARYN Alpha — concept tester-gate

Status: **concept, NO-GO voor echte testers**
Versie: 2026-07-29
Omgeving: uitsluitend de besloten AVARYN Alpha

Dit document bereidt de toelating van maximaal vijf persoonlijke testers voor.
Het autoriseert geen accountaanmaak, e-mail, uitnodiging, publicatie,
productiehandeling of verwerking van echte testerinformatie.

De teksten moeten vóór gebruik worden goedgekeurd door de uiteindelijke
verwerkingsverantwoordelijke en, waar nodig, juridisch/privacyadvies.

## Alpha-omgeving en actuele gate

| Onderdeel | Waarde |
| --- | --- |
| Primaire URL | `https://alpha.avaryn.eu` |
| Terugvaladres | `https://avaryn-alpha.flutterflow.app` |
| FlutterFlow-project | `a-v-a-r-y-n-alpha-ynvyuq` (`AVARYN Alpha`) |
| Supabaseproject | `ipdovjdtnfslrftvrdrl` (`AVARYN Staging`, Central EU/Frankfurt) |
| DNS | Porkbun, uitsluitend expliciet `A`-record voor host `alpha` |
| Zoekmachines | `noindex`; FlutterFlow-indexering uit |

Op 2026-07-29 zijn beide Alpha-hostnamen extern groen bevonden voor HTTPS,
dezelfde gepubliceerde build, uitsluitend het stagingendpoint, afwezigheid van
serversecrets en onverwachte analytics, responsive mobiel/desktopgedrag en de
fictieve accountlevenscyclus. De zero-footprint verwijderroute verwijderde het
fictieve Auth-account aantoonbaar en een nieuwe login werd geweigerd.

Dit verandert de tester-gate niet: er worden geen echte accounts gemaakt en
geen echte e-mails verstuurd totdat de juridische/privacykeuzes, het actieve
contactkanaal en de afzonderlijke tester-GO zijn vastgelegd.

## 1. Verwerkingsverantwoordelijke en open contactkeuze

Gebruik in deze conceptversie:

> **SDS Group B.V., handelend onder de handelsnaam AVARYN**
> KvK 91614112
> Nieuwe Rijksweg 2a, 4472 AB ’s-Heer Hendrikskinderen
> Privacy- en securitycontact:
> **[NOG IN TE VULLEN — NIET ACTIEF; GEEN E-MAILADRES GEPUBLICEERD]**

De definitieve verantwoordelijke is de natuurlijke of rechtspersoon die
feitelijk het doel en de essentiële middelen van de Alpha-verwerking bepaalt:
waarom AVARYN wordt getest, welke tester- en testgegevens worden verwerkt,
wie toegang krijgt en hoe lang gegevens worden bewaard. Een handelsnaam,
softwareleverancier of technisch account is niet automatisch de
verwerkingsverantwoordelijke.

Vóór definitief maken moet schriftelijk worden vastgesteld:

1. dat SDS Group B.V. feitelijk doeleinden, toegang, retentie en verwijdering
   voor deze Alpha bepaalt;
2. of iemand gezamenlijk deze beslissingen neemt;
3. welk privacy-, incident- en verwijdercontact bereikbaar en bemand is;
4. welke verwerkersovereenkomsten voor Supabase, FlutterFlow en eventueel
   e-mail gelden.

De AVG-definitie en praktische EDPB-uitleg koppelen de rol aan degene die het
“waarom en hoe” bepaalt:

- [AVG, artikelen 4 en 13](https://eur-lex.europa.eu/legal-content/EN/AUTO/?uri=CELEX%3A32016R0679)
- [EDPB: controller of processor](https://www.edpb.europa.eu/sme/learn-the-basics/data-controller-or-data-processor_en)

## 2. Korte concept-privacyverklaring

### Wie zijn wij?

**SDS Group B.V., handelend onder de handelsnaam AVARYN** organiseert een
kleine, besloten Alpha-test van AVARYN. Het privacy- en securitycontact is nog
niet actief en moet vóór echte testers worden ingevuld:
**[NOG IN TE VULLEN — NIET ACTIEF; GEEN E-MAILADRES GEPUBLICEERD]**.

### Welke gegevens verwerken wij?

Wij verwerken uitsluitend wat voor de Alpha noodzakelijk is:

- het persoonlijke e-mailadres van de tester;
- een intern tester-ID, Auth-UUID en minimale accountstatus;
- door de tester gekozen fictieve profiel- en testgegevens;
- technische login-, beveiligings-, fout- en toegangsgegevens;
- vrijwillige feedback, bugmeldingen en vooraf gecontroleerde screenshots;
- vastlegging van toestemming, intrekking en verwijdering.

IP-adres, browser- en beveiligingsmetadata kunnen technisch door Supabase,
FlutterFlow of hun infrastructuur worden verwerkt. AVARYN gebruikt in deze
Alpha geen marketinganalytics, advertentietracking of crashreporting-SDK.

### Waarom verwerken wij deze gegevens?

De gegevens worden gebruikt om:

- maximaal vijf testers persoonlijk en veilig toegang te geven;
- authenticatie, rollen, RLS en gegevensscheiding te beveiligen;
- fouten en bruikbaarheidsproblemen te onderzoeken;
- toegang in te trekken en incidenten af te handelen;
- testeraccounts en testgegevens gecontroleerd te verwijderen.

De definitieve juridische grondslag wordt vóór uitnodiging vastgesteld.
Voorgestelde keuze:

- uitvoering van de vrijwillige Alpha-testafspraak voor account en testgebruik;
- toestemming voor testercontact en vrijwillige feedback;
- gerechtvaardigd beveiligingsbelang voor minimale security- en auditlogging.

Deze keuze vereist juridische bevestiging; toestemming wordt niet gebruikt
waar zij niet vrij kan worden ingetrokken.

### Met wie delen wij gegevens?

Gegevens worden uitsluitend verwerkt door geautoriseerde AVARYN-beheerders en
de goedgekeurde technische verwerkers:

- Supabase voor Auth, database, Storage, Realtime en Edge Functions;
- FlutterFlow voor de besloten webapp en hosting;
- alleen na afzonderlijke goedkeuring: een gekozen e-mailprovider.

Het Alpha-Supabaseproject staat in Central EU (Frankfurt). Voor iedere
leverancier moeten de verwerkersovereenkomst, subverwerkers en eventuele
internationale doorgiften afzonderlijk worden beoordeeld.

### Hoe lang bewaren wij gegevens?

Het voorgestelde standaardbeleid is:

- testercontact, account en gewone testinhoud: tot einde deelname en daarna
  maximaal 30 dagen;
- vooraf gecontroleerde feedback zonder noodzaak tot identificatie: zo snel
  mogelijk pseudonimiseren en maximaal 90 dagen na einde Alpha bewaren;
- security- en auditgegevens: maximaal 90 dagen na intrekking of einde Alpha;
- incidentbewijs: maximaal 180 dagen na sluiting van het incident, uitsluitend
  wanneer aantoonbaar nodig;
- langere bewaring: alleen met een vastgelegde wettelijke noodzaak of
  rechtsvordering en een nieuw reviewmoment.

Backups en door leveranciers beheerde logs volgen hun goedgekeurde
verwerkers- en retentievoorwaarden. De definitieve termijnen moeten daarmee
worden afgestemd.

### Welke rechten heeft de tester?

De tester kan vragen om inzage, correctie, beperking, overdracht of
verwijdering en kan bezwaar maken of toestemming intrekken. Een verzoek gaat,
zodra dit kanaal formeel is ingericht, naar
**[NOG IN TE VULLEN — NIET ACTIEF; GEEN E-MAILADRES GEPUBLICEERD]**.
Intrekking beëindigt toekomstige deelname,
maar maakt eerdere rechtmatige verwerking niet onrechtmatig.

Bij een account met historische operationele gegevens kan directe technische
verwijdering worden geblokkeerd om referentiële integriteit, beveiligingsaudit
of een wettelijke bewaarplicht te respecteren. Dan volgt het
beheerdersreviewproces uit hoofdstuk 6 en ontvangt de tester een concrete
status en uitkomst.

Een tester kan ook een klacht indienen bij de bevoegde
gegevensbeschermingsautoriteit. AVARYN neemt geen uitsluitend geautomatiseerde
beslissingen over testers.

### Belangrijke Alpha-beperking

AVARYN is een onvoltooide, online-only testomgeving. Zij levert geen medisch,
veterinair of veiligheidskritiek advies en mag niet voor echte behandel-,
voer- of zorgbeslissingen worden gebruikt.

## 3. Concept testtoestemming, geheimhouding en feedback

De tester bevestigt vóór activering afzonderlijk:

- [ ] Ik ben ten minste 18 jaar, of er is een afzonderlijk juridisch
      goedgekeurd minderjarigenproces.
- [ ] Ik heb de Alpha-privacyverklaring en deze testafspraak ontvangen en
      begrepen.
- [ ] Ik neem vrijwillig deel en kan zonder opgave van reden stoppen.
- [ ] Ik gebruik uitsluitend mijn persoonlijke account en deel geen
      wachtwoord, activatielink of sessie.
- [ ] Ik voer uitsluitend toegestane fictieve gegevens en verstrekte
      testmedia in.
- [ ] Ik gebruik AVARYN niet voor echte medische, veterinaire, voer- of
      veiligheidskritieke beslissingen.
- [ ] Ik deel de Alpha-URL, schermen, functies, testresultaten en niet-openbare
      informatie niet publiek of met derden.
- [ ] Ik publiceer geen kwetsbaarheid; ik meld die onmiddellijk via het
      privé-incidentkanaal.
- [ ] Ik controleer screenshots en logs op namen, e-mailadressen, tokens,
      signed URLs, browserstorage en andere gevoelige inhoud.
- [ ] Ik begrijp dat de Alpha fouten kan bevatten en tijdelijk onbeschikbaar
      kan zijn.
- [ ] Ik geef vrijwillige feedback zonder vertrouwelijke informatie van
      anderen.
- [ ] Ik geef AVARYN een niet-exclusief, kosteloos recht om mijn
      productfeedback te gebruiken voor verbetering van AVARYN, standaard
      zonder naamsvermelding.
- [ ] Ik begrijp de bewaartermijnen en de procedure voor intrekking en
      verwijdering.
- [ ] Ik stem in met persoonlijk testercontact via het opgegeven e-mailadres.

Deze geheimhoudingsafspraak verhindert niet dat een tester vertrouwelijk
advies vraagt, een wettelijk recht uitoefent of een bevoegde toezichthouder
informeert.

Bewijs van acceptatie bevat alleen tester-ID, documentversie, UTC-tijd en
acceptatiestatus. Het wordt buiten Git en buiten gewone bugrapporten bewaard.

## 4. Regels voor toegestane en verboden invoer

### Wel toegestaan

- fictieve paardnamen en fictieve stalnamen;
- verzonnen taken, routines, voerplannen en teamrollen;
- synthetische of speciaal verstrekte testafbeeldingen en test-PDF's;
- korte technische feedback zonder echte namen of contactgegevens;
- willekeurige testwaarden die geen werkelijk dier, persoon of bedrijf
  beschrijven.

### Niet toegestaan

- namen, foto's, contactgegevens of locaties van echte personen;
- echte stal-, bedrijfs-, klant-, werknemer- of teamgegevens;
- gegevens van minderjarigen;
- echte paardendossiers, medische/veterinaire gegevens of behandelplannen;
- echte voer- of medicatie-instructies;
- biometrische, financiële, identificatie- of verzekeringsgegevens;
- herkenbare beelden van personen, kentekens, adressen of documenten;
- auteursrechtelijk materiaal zonder toestemming;
- wachtwoorden, API-sleutels, tokens, signed URLs of volledige netwerkheaders;
- gegevens uit productie- of andere bestaande systemen;
- beledigende, illegale of veiligheidskritieke inhoud.

Alle verstrekte media moeten synthetisch of gelicentieerd zijn en vóór gebruik
van EXIF-, locatie- en andere metadata zijn ontdaan.

## 5. Bewaar- en verwijderprocedure

### Normale uitstroom

1. Leg de intrekking vast onder het tester-ID, niet onder naam.
2. Blokkeer onmiddellijk nieuwe sessies en uitnodigingen.
3. Suspend de membership en trek Horse-grants en device-authority in.
4. Bevestig dat actieve clients hun lokale projectie hebben gewist.
5. Inventariseer profiel, testdata, media, feedback en auditcategorieën.
6. Verwijder gewone inhoud uiterlijk binnen 30 dagen na uitstroom.
7. Pseudonimiseer noodzakelijke feedback en securityrecords.
8. Verwijder het Auth-account wanneer geen historie of blokkade resteert.
9. Controleer van buiten het account dat login en dataread niet meer werken.
10. Bewaar alleen tester-ID, UTC-tijd, uitvoerder, categorie en uitkomst van
    de verwijdering.

Een volledig ongebruikt zero-footprint account mag via de bewezen
zelfbedieningsroute worden verwijderd. Iedere historische membership gaat
altijd naar beheerdersreview.

### Afsluiting van de volledige Alpha

Binnen 30 dagen na het officiële Alpha-einde:

- alle testeraccounts intrekken;
- gewone tester- en testinhoud verwijderen;
- feedback pseudonimiseren;
- security/auditrecords voorzien van een einddatum;
- open incidenten en juridische uitzonderingen afzonderlijk vastleggen;
- een verwijderrapport op aantallen, niet op namen, laten goedkeuren.

## 6. Beheerdersreview bij historische gegevens

`ACCOUNT_HISTORY_REQUIRES_ADMIN_REVIEW` is een veilige blokkade en nooit een
reden om databaseconstraints, RLS of audit-FK's te omzeilen.

Het reviewproces:

1. Identificeer uitsluitend op exacte Auth-UUID en intern tester-ID.
2. Freeze het account: membership suspend, grants revoke, authority rotate en
   sessies intrekken.
3. Maak per categorie een inventaris: memberships, stallen, Horses, planning,
   voeding, media, devices, feedback en audit/securityevents.
4. Classificeer iedere rij als:
   - direct verwijderbaar;
   - te anonimiseren/pseudonimiseren;
   - tijdelijk te bewaren met grondslag en einddatum;
   - technisch geblokkeerd door noodzakelijke referentiële integriteit.
5. Laat de privacyverantwoordelijke en technische beheerder samen het plan
   goedkeuren; de uitvoerder keurt niet alleen zijn eigen uitzondering goed.
6. Verwijder eerst toegankelijke private media en operationele inhoud volgens
   het goedgekeurde plan.
7. Vervang persoonsgegevens in noodzakelijke historie door een niet
   herleidbare of strikt afgescheiden pseudonieme referentie, voor zover
   juridisch en technisch toegestaan.
8. Verwijder daarna profiel en Auth-account met server-side
   beheerdersbevoegdheid.
9. Verifieer RLS-denial, login-denial, ontbrekende Storage-objecten en
   ingetrokken Realtime/device-authority.
10. Leg minimale beslis- en uitvoeringsgegevens vast, met een nieuwe
    vernietigingsdatum voor iedere uitzondering.
11. Informeer de tester over voltooiing, resterende categorieën, reden en
    einddatum zonder interne beveiligingsdetails prijs te geven.

## 7. Incident-, intrekkings- en toegangsprocedure

### Onmiddellijk stoppen bij

- zichtbaarheid van gegevens van een andere tester of stal;
- toegang na revoke of logout;
- verlies of delen van account, activatielink of apparaat;
- token, signed URL of geheim in een screenshot/log;
- echte persoonsgegevens of productiegegevens in Alpha;
- onverwachte externe communicatie of een onbekend endpoint.

### Eerste acties

1. Stop de testsessie en laat de tester niet verder “bewijzen verzamelen”.
2. Suspend de betrokken membership en trek grants, sessies en authority in.
3. Blokkeer zo nodig nieuwe Alpha-toelatingen.
4. Bewaar alleen minimaal, geredigeerd bewijs.
5. Registreer UTC-tijd, tester-ID, omgeving, route en gegevenscategorie.
6. Meld privé aan
   **[PRIVACY- EN SECURITYCONTACT NOG IN TE VULLEN — NIET ACTIEF]**.
7. Bepaal scope, betrokkenen en toegankelijkheid.
8. Laat de verwerkingsverantwoordelijke beoordelen of sprake is van een
   meldplichtig datalek en welke wettelijke termijnen gelden.
9. Herstel en voer een onafhankelijke heraudit uit.
10. Herstel toegang uitsluitend na expliciete goedkeuring en een nieuwe
    veilige sessie.

### Gewone intrekking

Een tester kan na activering intrekken via
**[PRIVACY- EN SECURITYCONTACT NOG IN TE VULLEN — NIET ACTIEF]**. De beheerder
bevestigt ontvangst, voert dezelfde onmiddellijke technische revoke uit en start de
verwijderprocedure. Een e-mailverzoek alleen is nooit voldoende bewijs om een
account op basis van e-mailadres te verwijderen; de beheerder verifieert de
Auth-UUID via het geauthenticeerde of vooraf vastgelegde proces.

## 8. Veilige toelating van maximaal vijf persoonlijke accounts

Deze procedure mag pas starten na een afzonderlijke schriftelijke GO.

1. Gebruik vaste pseudoniemen `T-001` tot en met `T-005`.
2. Verzamel per tester alleen:
   - persoonlijk e-mailadres;
   - gekozen pseudoniem/weergavenaam;
   - bevestiging 18+ of goedgekeurde uitzondering;
   - acceptatie van exacte documentversies en UTC-tijd;
   - optioneel voorkeurscontactkanaal voor incidenten.
3. Bewaar de koppeling tester-ID ↔ e-mailadres in een afgeschermd
   toegangsregister buiten Git, chat en testbewijs.
4. Controleer vóór ieder account opnieuw:
   - exact Supabaseproject `AVARYN Staging`;
   - exact FlutterFlow-project `AVARYN Alpha`;
   - geen productie- of legacyendpoint;
   - groene releasecommit en geen open P0/P1/P2.
5. Maak accounts één voor één met server-side Auth Admin in staging.
6. Gebruik geen gedeelde accounts en geen owner/adminrol als standaard.
   Start met de minimaal benodigde `member`- of `viewer`-authority.
7. Genereer geen door een beheerder gekozen blijvend wachtwoord. Gebruik een
   korte, eenmalige accountactivatie-/password-set-link met maximaal één uur
   geldigheid.
8. Toon of log de link niet en plaats hem nooit in Git, chat, tickets of
   spreadsheets.
9. Verstuur iedere activatie individueel via de goedgekeurde mailroute; nooit
   CC/BCC met andere testers.
10. Bind een eventuele staluitnodiging server-side aan exact het bevestigde
    persoonlijke account-e-mailadres.
11. Controleer na eerste login profiel, rol, cross-stable denial, logout en
    lokale purge voordat de tester scenario's uitvoert.
12. Houd een toegangslijst bij met alleen tester-ID, Auth-UUID, rol,
    activeringsstatus, laatste review en intrekkingsstatus.

## 9. E-mailplan voor maximaal vijf testers

### Vergelijking

| Route | Kosten | Belangrijkste grens | Beoordeling |
| --- | --- | --- | --- |
| Supabase standaardmail | geen nieuwe kosten | momenteel 2 Auth-mails per uur, best-effort, geen SLA, alleen naar vooraf geautoriseerde adressen van Supabase-projectteamleden en voor nieuwe Free-projecten geen aangepaste Auth-templates | **niet geschikt voor vijf externe testers**; testers projectteamtoegang geven is verboden |
| Bestaand organisatiepostvak, handmatige persoonlijke verzending | geen nieuwe kosten als dit postvak al bestaat | geen automatische Auth-mail; beheerder moet eenmalige links veilig en individueel verzenden | **aanbevolen kosteloze Alpha-route**, mits eigendom, beveiliging en privacy van het postvak zijn goedgekeurd |
| Custom SMTP | mogelijk bestaand/gratis, maar voorwaarden en kosten verschillen | credentials, afzenderdomein, SPF/DKIM/DMARC, DPA, deliverability en linktracking moeten worden beoordeeld | alleen gebruiken als al een geschikt account bestaat; anders eerst afzonderlijke dienst- en kostenbeslissing |

Supabase documenteert de standaarddienst als niet-productieve best-effortmail,
momenteel 2 berichten per uur en beperkt tot projectteamadressen:

- [Supabase: Send emails with custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)
- [Supabase production checklist en Auth-rate limits](https://supabase.com/docs/guides/deployment/going-into-prod)
- [Supabase: Free-tier wijziging e-mailtemplates vanaf 3 juni 2026](https://supabase.com/changelog/46599-changes-to-email-template-customisation-on-free-tier)

### Aanbevolen kosteloze route

Gebruik een reeds bestaand, door
**SDS Group B.V., handelend onder de handelsnaam AVARYN** beheerd postvak, mits:

- MFA en beperkte beheerderstoegang zijn ingeschakeld;
- het postvak niet gedeeld wordt met onbevoegden;
- er geen nieuwe dienst, licentie of betaling nodig is;
- het privacycontact en afzenderadres zijn goedgekeurd;
- verzonden links niet door tracking of linkrewriting worden gewijzigd;
- mails één voor één en zonder andere testeradressen worden verzonden.

Per tester zijn maximaal deze berichten voorzien:

1. **Voorafgaande uitnodiging** — doel, privacytekst, testafspraak, datagrens en
   verzoek om expliciete acceptatie; nog geen account of geheime link.
2. **Persoonlijke activering** — pas na acceptatie; één kortlevende
   activatielink, Alpha-URL en incidentcontact; geen wachtwoord.
3. **Alleen indien nodig** — intrekking, incidentinformatie of
   verwijderbevestiging.

Stuur maximaal twee activaties per gecontroleerd tijdvak en verifieer na elke
activering de juiste accountbinding voordat de volgende wordt verstuurd.

### Wanneer custom SMTP opnieuw beoordelen?

Custom SMTP is de voorkeursroute zodra:

- een bestaand geschikt organisatieaccount beschikbaar is;
- de afzender en het domein zijn geverifieerd;
- DPA, subverwerkers, regio en kosten zijn goedgekeurd;
- SPF, DKIM en DMARC zijn ingericht;
- linktracking is uitgeschakeld;
- testmails, bounce, expiry, resend en revoke groen zijn.

Zonder bestaand geschikt account of bij iedere nieuwe betaling/credit/
betaalmethode blijft de status `NO-GO` totdat de eigenaar apart toestemming
geeft.

## 10. Resterende beslissingen en exacte volgende toestemming

Vóór toelating is één schriftelijke beslissing nodig met:

1. definitieve statutaire naam, rechtsvorm, adres en registratienummer van de
   verwerkingsverantwoordelijke;
2. privacy-, incident- en verwijdercontact;
3. bevestigde juridische grondslagen;
4. goedgekeurde privacyverklaring en testafspraak, met versienummers;
5. gekozen definitieve retentietermijnen en backup-/leveranciersafhandeling;
6. Supabase-/FlutterFlow-DPA- en subverwerkersreview;
7. besluit over minderjarigen: volledig uitsluiten of afzonderlijk proces;
8. bevestiging dat een bestaand veilig organisatiepostvak beschikbaar is, of
   een aparte custom-SMTP/kostenbeslissing;
9. aangewezen accountbeheerder en tweede reviewer;
10. expliciete toestemming: “Maak maximaal vijf persoonlijke accounts aan in
    AVARYN Staging en verstuur de goedgekeurde individuele Alpha-mails.”

Pas daarna mag per tester veilig worden aangeleverd:

- persoonlijk e-mailadres;
- gekozen pseudoniem/weergavenaam;
- 18+-bevestiging of goedgekeurde uitzondering;
- acceptatie van privacy- en testafspraak;
- optioneel incidentcontactvoorkeur.

Geen namen, e-mailadressen of andere echte testerinformatie horen in Git,
Codex-chat, FlutterFlow-projectbestanden, bugrapporten of gedeelde
testbewijzen.
