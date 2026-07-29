# AVARYN Alpha — directe hersteltest

## Grens

Gebruik uitsluitend fictieve gegevens op `https://alpha.avaryn.eu` of, als
terugval, `https://avaryn-alpha.flutterflow.app`. Controleer vóór iedere
sessie dat netwerkverkeer uitsluitend naar Supabase Staging-project
`ipdovjdtnfslrftvrdrl` gaat. De tester-gate blijft `NO-GO`: maak geen echte
testeraccounts aan en verstuur geen e-mail.

## Route 1 — compleet voerschema

1. Log in met een bestaand fictief Alpha-account, kies de fictieve stal en
   open een fictief paard.
2. Open **Voerschema** en maak een standaard dagschema met minimaal twee vrije
   tijdstippen. Gebruik samen de typen voer, supplement, hooi, water en
   medicatie; vul product, hoeveelheid, eenheid, instructie en een
   verantwoordelijke in.
3. Keur de conceptversie goed en activeer haar. Controleer in **Today** en
   **Start mijn dag** dat de beurten chronologisch verschijnen.
4. Open een beurt en controleer alle instructies. Registreer werkelijke
   hoeveelheid, resterende hoeveelheid, afwijking of weigering, observatie en
   opmerking. Teken af en controleer gebruiker en tijdstip.
5. Open de historie van hetzelfde paard en vergelijk gepland met werkelijk.
6. Maak een tijdelijk schema dat exact één standaardslot vervangt. Activeer
   het en controleer dat het standaardschema en de overige slots intact
   blijven.
7. Wijzig een conceptitem conflictveilig en bevestig na verversen dat de
   laatste serverversie zichtbaar is.

Verwacht: alleen bevoegde of toegewezen teamleden zien de relevante
paardcontext; een fictieve actor uit stal B ziet niets uit stal A.

## Route 2 — agenda en planning

1. Open **Planning**, kies de dagweergave en maak een eenmalig item met paard,
   teamlid, datum, tijd, locatie, categorie, instructie en prioriteit.
2. Controleer hetzelfde bronrecord in de dagweergave, **Today** en
   **Start mijn dag**. Filter achtereenvolgens op paard, gebruiker, team en
   categorie.
3. Open de week- en maandweergave. Controleer kleur, titel, tijd, paard en
   verantwoordelijke; open vanuit iedere weergave dezelfde detailkaart.
4. Wijzig het item, vink het af en controleer status en historie. Maak een
   tweede item en markeer dit als **Gemist**.
5. Maak een dagelijkse of wekelijkse reeks. Wijzig eerst alleen één occurrence
   en daarna **Deze en volgende**. Controleer dat eerdere occurrences en hun
   historie ongewijzigd blijven.
6. Herhaal de zichtbaarheidstest als toegewezen fictief teamlid en de
   denialtest als fictieve actor uit stal B.

Verwacht: één serverrecord per afspraak, chronologische weergave en
conflictveilige updates zonder duplicaten.

## Sessies en schermen

Controleer beide routes op 390×844 en 1280×720. Test login, logout, refresh en
sessieherstel; beveiligde routes mogen zonder geldige sessie geen staldata
tonen. Trek tijdens een open mutatiedialoog de fictieve toegang in: de dialoog
moet sluiten en de stale bevestiging mag niets schrijven.

## Bewust uitgesteld

- voedingsvoorraad, QR-stickers, bestellen en uitgebreide voedingsanalyse;
- bulkplanning en beheer van boxen, weides, paddocks of faciliteiten;
- echte accounts, echte persoonsgegevens, uitnodigingsmail en productie.
