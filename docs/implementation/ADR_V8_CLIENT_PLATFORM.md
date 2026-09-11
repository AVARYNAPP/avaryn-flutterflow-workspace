# Besluit: één V8-webclient met Capacitor 8

De daadwerkelijk goedgekeurde interface bestaat uit 29 JavaScriptmodules, 10 stylesheets
en gedeelde assets, niet uit de oudere Flutter-export. De date-priority-kandidaat bevat
alle eerdere Connected-, Mobile Tasks-, Rider- en Exercise-uitbreidingen. Het gecontroleerde
manifest en de beeldreferenties vormen het contract.

De officiële bron is `apps/avaryn/src`; Supabase-contracten blijven onder `supabase`.
Sites-checkouts en web/native buildmappen zijn afgeleide publicatiebronnen. FlutterFlow
blijft een historische ontwerp-/exportreferentie en mag deze bron niet overschrijven.

Capacitor 8 verpakt dezelfde gebouwde webassets in iOS/Android. Geen native `server.url`
naar een tijdelijke preview. Kleine platformadapters behandelen veilige sessieopslag,
links, foto's en lifecycle. Er komt geen tweede interface, nieuw stateframework of
algemene TypeScript-migratie. Webbuilds blijven zelfstandige statische assets.

Beperking: Capacitor is geen automatische native gebruikersacceptatie. Gate A moet
compile én de gekoppelde taakflow bewijzen. Op deze Mac ontbreekt Android-tooling;
die wordt projectgebonden ingericht. iOS-builds vereisen Xcode26/macOS15.6 of nieuwer;
macOS14.6.1 kan dat niet uitvoeren. Platformprojecten worden wel voorbereid. Bestaande
Flutter-ID `com.mycompany.avarynalpha` is alleen een gevonden aanwijzing; registratie
en signing moeten eerst worden gecontroleerd.

Bronnen: https://capacitorjs.com/docs/getting-started/environment-setup en
https://developer.apple.com/xcode/system-requirements .
