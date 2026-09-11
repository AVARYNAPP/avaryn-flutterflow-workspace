# AVARYN V8 productisering — uitvoeringsbacklog

Mandaat: 11 september 2026. Doel is behoud van de goedgekeurde V8 met één productbron,
duurzame pilotkern en web/iOS/Android-builds. Geen publieke storevrijgave of main-merge.

1. [x] Branch/origin/stash en laatste complete V8 identificeren; 425 ongecommitte bestanden + actieve bron gecontroleerd archiveren.
2. [x] Referentiebeelden van Vandaag light/dark, paarden, planning, stal en desktop vastleggen.
3. [x] Goedgekeurde JS-client met bronmanifest consolideren in `apps/avaryn/src`.
4. [ ] Gate A: webbuild en gekoppelde taakflow bewezen; Capacitor-assets gesynchroniseerd. Native compile wacht op SDKlicenties en geschikte Xcode.
5. [ ] Kernintegratie geïmplementeerd: Auth/profiel, paardaanmaak/foto, stal/team, duurzame Vitality en lifecycle. Resterende echte browser-/onlineproeven uitvoeren.
6. [ ] Development/RC/pilot bepalen en herstellen; permanente backend en hosting gereedmaken.
7. [ ] Gate B: lokale SQL-/HTTP-/raceproeven en gezamenlijke productsuite geslaagd; managed Edge- en onlineproeven staan nog open.
8. [ ] Gate C: finale kandidaat, visuele vergelijking, web/Android/iOS artifacts, exact checkpointreview.
9. [ ] Gate D: besloten permanente pilot, cross-client/opslag/update/herstel, testdistributie waar mogelijk.
10. [ ] Schone overdrachtsbuild en documentatie bewezen, checkpoint lokaal vastgelegd; push wacht op juiste GitHub-schrijftoegang. Persoonlijke acties gebundeld.

De productbron en parallel beoordeelde wijzigingen zijn bevroren voor het technische checkpoint.
De productsuite telt 886 tests:884 geslaagd,0 fouten,2 expliciete liveproeven overgeslagen.
Dit sluit de browser-, toestel- en menselijke acceptatie niet af. De actuele grenzen en bewijzen
staan in [de voortgang](../status/V8_PRODUCTIZATION_PROGRESS.md) en
[de technische testresultaten](../../apps/avaryn/TEST_RESULTS.md).

Zelfregistratie met e-mailbevestiging is bevestigd door de gebruiker; geen vaste testeremaillijst.
Webgedeelte Gate A: UI login/taak/create/complete/reload bewezen; de finale build bevat geen actieve demodata.
Huidige externe afhankelijkheden: Android SDK-licenties wachten op persoonlijke acceptatie; iOS vraagt
een geschikte macOS/Xcode-omgeving (huidige Mac14.6.1 heeft geen Xcode). Signing en
developerregistraties nog te controleren. Permanente hosting wordt geen laptop-tunnel.
