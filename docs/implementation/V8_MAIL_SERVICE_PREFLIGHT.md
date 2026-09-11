# V8 — bestaande maildienst, alleen-lezen controle

Oorspronkelijke DNS-controle: **11 september 2026, 18:07 UTC**. Aanvulling dezelfde dag: geautoriseerde Resend-accountcontrole door de hoofdwerkstroom. Geen DNS-wijzigingen, nieuwe accounts, aankopen, wachtwoordresets, SMTP-loginproeven of verzonden e-mails.

**Actuele conclusie:** de hoofdwerkstroom heeft na expliciet gebruikersakkoord het bestaande Resend-account `silasdesteur` alleen-lezen op domeinen gecontroleerd. Daar staat exact één domein: **`auth.avaryn.eu`**, status **Verified**, melding **ready to send emails**, DNS-provider **Porkbun**, regio **eu-west-1 (Ireland)**. Domain-ID: `1255fdb7-c4c1-461f-b583-50c7dfd8a69c`; de UI toont aanmaak circa één maand geleden. Dit bestaande geverifieerde verzenddomein is leidend. Het voorstel voor een nieuw `auth.alpha.avaryn.eu` is vervallen; er zijn geen nieuwe DNS-records of Porkbun-mailbox nodig voor deze route.

De hieronder bewaarde apex-DNS-resultaten bewezen geen afwezigheid van uitgaande SMTP. Een ontbrekend MX/SPF op `avaryn.eu` zegt niets afdoends over verzending via het bestaande subdomein `auth.avaryn.eu`. De eerdere onzekerheid over een bestaande verzendprovider is hiermee voor Resend/domeinverificatie opgelost; daadwerkelijke SMTP-authenticatie en bezorging zijn nog niet bewezen.

**Aanvullende planwaarneming:** de hoofdwerkstroom heeft met expliciet read-only akkoord `/settings/usage` bekeken: **Transactional Free**, maandgebruik **0/3.000**, daggebruik **0/100**, team **Free**, domeinen **1/3**, **pay-as-you-go uit**. Geen upgrade uitgevoerd. **Bewijsgrens:** actieve SMTP/API-sleutels zijn niet geïnspecteerd of bewezen beschikbaar; daarvoor was bij deze controle geen toestemming (alleen domeinen en plan). Er zijn geen keys, instellingen of DNS gewijzigd. Zie de bijgewerkte [pilotroute met bestaand Resend-domein](V8_PILOT_FREE_SMTP_ROUTE.md).

## Openbare DNS op het oorspronkelijke controlemoment

De vier op dat moment waargenomen autoritatieve servers zijn `curitiba.ns.porkbun.com`, `fortaleza.ns.porkbun.com`, `maceio.ns.porkbun.com` en `salvador.ns.porkbun.com`.

| Query | Waargenomen resultaat |
|---|---|
| `avaryn.eu MX` op alle vier servers | `NOERROR`, `AA`, 0 antwoorden: geen expliciete MX-records. |
| `avaryn.eu TXT` op alle vier servers | `NOERROR`, `AA`, 0 antwoorden: geen apex-TXT en daarmee geen apex-SPF. |
| SOA in bovenstaande antwoorden | `curitiba.ns.porkbun.com`, serial `2412915114`. |
| `_dmarc.avaryn.eu TXT` op Curitiba | `NOERROR`, `AA`; CNAME naar `pixie.porkbun.com`, TTL 600. |
| Dezelfde DMARC-query via de lokale resolver | De CNAME gevolgd door Porkbun-SOA; geen effectieve DMARC-TXT-policy in het antwoord. |

Herhaalbare read-only query, met dezelfde domeinscope:

```sh
dig @curitiba.ns.porkbun.com +norecurse +time=3 +tries=1 avaryn.eu MX
dig @curitiba.ns.porkbun.com +norecurse +time=3 +tries=1 avaryn.eu TXT
dig @curitiba.ns.porkbun.com +norecurse +time=3 +tries=1 _dmarc.avaryn.eu TXT
```

De MX/TXT-queries zijn ook tegen de drie andere genoemde servers uitgevoerd. DNS-bevraging vanuit de sandbox kon geen socket openen; dezelfde expliciet read-only bevraging is met netwerktoestemming geslaagd. Er is geen DKIM-selectorinventarisatie uitgevoerd en geen uitgaande SMTP-authenticatie getest. MX beschrijft inkomende mailrouting; ontbrekende MX alleen bewijst geen afwezigheid van alle uitgaande maildiensten.

## Wat Porkbun daadwerkelijk aanbiedt

| Onderdeel | Officieel ondersteund / minimum |
|---|---|
| Gratis forwarding | Ontvangt en stuurt door; levert geen eigen mailbox-SMTP-login waarmee Supabase als AVARYN kan verzenden. [Hosted email tegenover forwarding](https://kb.porkbun.com/article/67-hosted-email-vs-email-forwarding). |
| Hosted mailbox | Kan wel verzenden en ontvangen. Actuele aangeboden prijs: USD 36 per jaar per mailbox; 15 dagen proef bij een nieuw domein. Of AVARYN dit al bezit is **niet geverifieerd**. Er is niets besteld of geactiveerd. [Officiële productpagina](https://porkbun.com/products/porkbun_email). |
| SMTP | Host `smtp.porkbun.com`, poort `587`, STARTTLS; alternatief `465` met impliciete TLS. Gebruikersnaam: volledig bestaand mailboxadres. Wachtwoord: het aparte mailboxwachtwoord, niet het Porkbun-accountwachtwoord. [SMTP-configuratie](https://kb.porkbun.com/article/146-email-client-configuration-settings), [mailboxconfiguratie](https://kb.porkbun.com/article/24-how-to-set-up-email-hosting-services). |
| Supabase-koppeling | Indien de mailbox al bestaat: hetzelfde SMTP-endpoint, mailboxlogin, passende afzendernaam en bijbehorend afzenderadres uitsluitend in servermatige Auth-configuratie. Werkelijke mailboxstatus, toegestane afzender, SMTP-authenticatie en bezorging moeten nog worden vastgesteld; geen onbeperkte transactionele capaciteit claimen. |
| DNS voor Porkbun-mail | Porkbuns standaarddocumentatie noemt MX `fwd1.porkbun.com` prioriteit 10 en `fwd2.porkbun.com` prioriteit 20; SPF `v=spf1 include:_spf.porkbun.com ~all`. Dit zijn documentatiegegevens, **geen aangetroffen AVARYN-records en geen wijzigingsopdracht**. Een bestaande SPF moet bij eventuele uitvoering worden behouden/samengevoegd, niet verdubbeld. [Officiële DNS-instructie](https://kb.porkbun.com/article/47-how-to-use-porkbun-email-when-your-dns-is-hosted-elsewhere). |
| DKIM/DMARC | Porkbun biedt configuratie voor hosted mail; controleer eerst de werkelijke mailbox en de gegenereerde doelrecords. In deze taak is de configuratieknop niet gebruikt. [Officiële DKIM/DMARC-instructie](https://kb.porkbun.com/article/179-how-to-turn-on-dkim-dmarc). |

## Historische Porkbun-accountcontrole en huidige vervolgstap

De oorspronkelijke eigen Chrome-tab naar de officiële [Porkbun-accountpagina](https://porkbun.com/account) eindigde op `/account/login` met lege gebruikersnaam/wachtwoordvelden en een menselijke verificatiestap. Er zijn daarbij geen domeinlijsten, mailboxen, berichten of accountcredentials gelezen. Geen voorwaarden zijn geaccepteerd. De toenmalige handoff-tab was `386275948`.

**Een nieuwe Porkbun-aanmelding of mailboxcontrole is voor de gekozen SMTP-route niet meer nodig:** Resend toont het bestaande domein al als Verified met Porkbun als DNS-provider. Gebruik die bestaande route. Alleen de persoonlijke voorbereiding van een bruikbare, tot het bestaande domein beperkte SMTP-sleutel, de afzonderlijk geautoriseerde geheime configuratiestap in de nieuwe Supabase-pilot en werkelijke mailbezorging blijven open. Er is geen nieuw Resend-account nodig. Vraag geen nieuwe domein- of DNS-aanmaak op basis van deze historische apex-query's.
