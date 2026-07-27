# AVARYN fase 5 — besluitrecord

**Besluit-ID:** `AVARYN-P5-2026-07-27`
**Status:** bindend voor lokale bouwregie tot de deploymentgate
**Vaste basis:** `3fca50764dde5575ed8be8097ba090159b8d4ba4`
**FlutterFlow-basis:** `0FZW5Yak1yDvRiVOdoui`

## Vastgestelde besluiten

De fase-5-opdracht van 27 juli 2026 stelt repositorymatig de volgende
besluiten vast:

1. Fase 5 maakt de bestaande dagelijkse Horse/team-kern testklaar voor een
   kleine besloten webalpha.
2. De bindende Alpha-scope is account, stal/team, Horse, Today,
   planning/routines, execution, voeding, operationele media, invitations,
   private Realtime, de reeds beveiligde offlinepilot en lifecyclecleanup.
3. Notificaties/reminders vallen alleen binnen scope voor zover zij al
   contractueel zijn geïmplementeerd. De fase-4-contracten bevatten geen
   notification/reminderbackend; fase 5 verzint die niet alsnog.
4. Persona's `ruiter`, `groom`, `trainer` en `eigenaar` zijn geen
   autorisatierollen.
5. Horse-relaties zijn uitsluitend semantisch en verlenen nul capabilities.
   Authority komt alleen uit actieve membership/rol, expliciete grants,
   assignments en de server-side datacategoriecontrole.
6. Alle testaccounts en gegevens vóór de deploymentgate zijn fictief en
   uitsluitend lokaal.
7. Lokale Supabase-reset is toegestaan; externe of productiegegevens zijn
   verboden.
8. FlutterFlow-projectcommits en lokale webbuilds zijn toegestaan;
   publicatie, hosting, stagingprojecten, domeinen en echte accounts niet.
9. Iedere groene subfase krijgt tests, onafhankelijke read-only audit, één
   conventionele commit en een non-force push naar `origin/main`.
10. De uitvoering stopt bij de externe deploymentgate voor een expliciet
    toestemmingsverzoek.

## Geërfde fase-4-basis

De geïmplementeerde en groen geteste fase-4-securitycontracten zijn de
technische basis en worden in fase 5 niet heropend of verzwakt. Dit
besluitrecord claimt geen afzonderlijke juridische goedkeuring van oude
conceptdocumenten. Nog ontbrekende privacy-, retentie- of juridische
goedkeuring blijft een deploymentvoorwaarde.

## Open productbesluit: browseroffline

De actuele opdracht vraagt een besloten webalpha en offlineacceptatie. Het
fase-4-contract verbiedt duurzame browseroffline-opslag zonder goedgekeurde
OS-backed sleutelopslag.

Daarom blijft exact één keuze open:

- webalpha online-only houden en offline afzonderlijk op ondersteund
  native/desktop bewijzen; of
- eerst een nieuw beveiligingscontract voor WebCrypto/sleutelopslag
  goedkeuren en auditen.

Tot dit besluit is genomen, wordt browseroffline niet gebouwd en kan de
offline-eis voor een webtester niet als groen worden afgetekend. Alle andere
onafhankelijke fase-5-werkzaamheden mogen doorgaan.
