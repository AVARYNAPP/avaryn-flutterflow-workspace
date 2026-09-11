# Bestaande Resend-route voor de AVARYN-pilot

**Bijgewerkt op 11 september 2026. Status: bestaand verzenddomein bevestigd; pilot-SMTP en bezorging nog niet bevestigd.** De eerder voorbereide nieuwe route `auth.alpha.avaryn.eu` is **vervallen en onnodig**. Gebruik het al bestaande **`auth.avaryn.eu`**. Geen extra domein, DNS-records of Porkbun-mailbox aanmaken.

## Gezaghebbende accountwaarneming

Na expliciet gebruikersakkoord voor alleen-lezen domeinen/plan heeft de hoofdwerkstroom in Resend het volgende gezien:

| Onderdeel | Waargenomen waarde |
|---|---|
| Account | `silasdesteur` |
| Domeinen | Exact één: `auth.avaryn.eu` |
| Domeinstatus | **Verified**, UI: **ready to send emails** |
| Domain-ID | `1255fdb7-c4c1-461f-b583-50c7dfd8a69c` |
| DNS-provider / regio | Porkbun / `eu-west-1` (Ireland) |
| Aanmaak | UI toont circa één maand geleden; geen exacte datum afgeleid |
| Actueel abonnement | `/settings/usage`: **Transactional Free**, team **Free** |
| Gebruik | **0/3.000** deze maand, **0/100** vandaag, domeinen **1/3** |
| Kosteninstelling | **Pay-as-you-go uit**; geen upgrade uitgevoerd |
| Actieve SMTP/API-sleutels | Niet geïnspecteerd, niet bewezen beschikbaar; buiten het gegeven read-only domeinen/plan-mandaat |

Dit is directe account-UI-evidentie van de hoofdwerkstroom, geen conclusie uit openbare DNS. De eerdere [apex-DNS-controle](V8_MAIL_SERVICE_PREFLIGHT.md) vond geen MX of SPF op `avaryn.eu`; dat bewijst geen afwezigheid van SMTP-verzending vanaf het nu aangetroffen subdomein. De bestaande DNS-verificatie is voldoende uitgangspunt: geen nieuwe DNS-mutatie voorbereiden of uitvoeren.

## Gratis voorwaarden: bestaand accountplan bevestigd

De actuele openbare Resend-prijspagina vermeldt voor **Transactional Free $0 per maand, 3.000 berichten per maand, maximaal 100 per dag en 3 domeinen**. De afzonderlijke read-only accountwaarneming hierboven bevestigt dat dit account daadwerkelijk op Free staat en pay-as-you-go uit heeft. [Actuele prijzen](https://resend.com/pricing).

Free kent geen betaalde overage; bereikte quota begrenzen verder verzenden. Ontvangers, herhaalde bevestigingen/herstelberichten en eventuele ontvangen mail tellen mee binnen de teamquota. Geen betaald plan, pay-as-you-go of add-on activeren. Voor deze pilot is geen ontvangende Porkbun-mailbox nodig. [Planvoorwaarden](https://resend.com/docs/knowledge-base/what-is-resend-pricing), [quota](https://resend.com/docs/knowledge-base/account-quotas-and-limits).

## Concrete pilotconfiguratie, nog niet uitgevoerd

Doel blijft uitsluitend de nieuwe Supabase-pilot (`rvym…`, geïdentificeerd door de hoofdwerkstroom). De eerdere dashboardwaarneming was Custom SMTP uit. De volgende persoonlijke stap is een bruikbare SMTP-sleutel voor het **bestaande** domein veilig beschikbaar maken. Gebruik het bestaande Resend-account; geen nieuwe account- of DNS-aanmaak. Bestaande keys en hun scope zijn nog niet bekeken, dus aanwezigheid of herstelbaarheid van zo’n sleutel wordt niet verondersteld.

| Supabase Authentication → SMTP settings | Benodigde configuratie |
|---|---|
| Custom SMTP | Pas inschakelen bij beschikbare, geautoriseerde SMTP-credential |
| Host / port | `smtp.resend.com` / `465` (impliciete TLS) |
| Username | `resend` |
| Password | Bruikbare Resend-API-sleutel; bestaan/toegang nog niet gecontroleerd |
| Sender email/name | Voorgesteld: `no-reply@auth.avaryn.eu` / `AVARYN` |

De SMTP-credential is een Resend-API-sleutel, geen Supabase anon/service-role-key of Porkbun-login. Keyinspectie, hergebruik of aanmaak is een **afzonderlijke geheime configuratiestap**; deze is niet verricht of stilzwijgend geautoriseerd door alleen-lezen domeinen/plan. Indien later een aparte sleutel nodig blijkt: alleen verzendrecht en domeinbeperking voor `auth.avaryn.eu`, geen algemeen beheer. Nooit in chat, rapport, bron, build of screenshot opslaan. [SMTP](https://resend.com/docs/send-with-smtp), [sleutelrechten](https://resend.com/docs/api-reference/api-keys/create-api-key), [sleutelbeheer](https://resend.com/docs/dashboard/api-keys/introduction).

Resend staat na domeinverificatie een afzender op dat exacte domein toe zonder afzonderlijke mailboxaanmaak. Het bovenstaande afzenderadres is een voorstel, geen bewezen bestaande configuratie; een bewaakt antwoordadres is nog niet aangetoond. [Afzenderidentiteit](https://resend.com/docs/knowledge-base/how-do-I-create-an-email-address-or-sender-in-resend).

De bestaande Supabase Auth-mailstroom, e-mailbevestiging en exacte callback-allowlist blijven uitgangspunt. Geen nieuwe mail-Edge, frontendsecret of Supabase custom-domainproduct nodig. Controleer de werkelijke Auth-mailrate in het pilotdashboard: de Supabase-doc noemt initieel 30/uur; een Resend-quickstart noemt 25/uur. Controleer ook open-/linktracking voor Auth-links; de provider raadt uitschakelen aan. Deze instelling is hier niet bekeken of gewijzigd. [Supabase SMTP](https://supabase.com/docs/guides/auth/auth-smtp), [Resend-bezorgadvies](https://resend.com/docs/knowledge-base/how-do-i-maximize-deliverability-for-supabase-auth-emails).

**Open acceptatie:** geautoriseerde credentialconfiguratie, SMTP-inschakeling in uitsluitend de pilot, daarna echte zelfregistratie met ontvangst/bevestiging, resend en wachtwoordherstel. Verified of SMTP-save alleen bewijst geen bezorging. Geen e-mails verzonden in deze documenttaak; geen nieuwe tester-e-maillijst vereist.
