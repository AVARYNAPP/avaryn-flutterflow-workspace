# AVARYN V8

De officiële productclient staat in [`apps/avaryn/src`](apps/avaryn/src). De goedgekeurde V8-interface wordt als één JavaScript-client gebouwd voor web en met gebundelde assets voor iOS/Android via Capacitor. Supabase levert de bestaande canonieke account-, paarden- en stalcontracten.

Begin bij de [clienthandleiding](apps/avaryn/README.md):

- [Installatie en bouwen](apps/avaryn/README.md)
- [Architectuur en platformkeuze](docs/implementation/ADR_V8_CLIENT_PLATFORM.md)
- [Ontwikkelen](apps/avaryn/DEVELOPMENT.md)
- [Omgevingen](apps/avaryn/ENVIRONMENTS.md)
- [Releases, signing en herstel](apps/avaryn/RELEASES.md)
- [Testerhandleiding](apps/avaryn/TESTER_GUIDE.md)
- [Actuele voortgang en open afhankelijkheden](docs/status/V8_PRODUCTIZATION_PROGRESS.md)

```sh
cd apps/avaryn
npm ci
npm run build
npm run dev
```

De developmentserver gebruikt alleen loopback. Zonder expliciete lokale backendconfiguratie start de interface, maar zijn account- en gegevensbewerkingen niet verbonden. De releasebuild bevat geen synthetische accounts of voorbeeldgegevens.

`supabase/migrations/` bevat voorwaartse databasecontracten; `supabase/tests/` en `test/edge/` verifiëren de getroffen beveiliging en lifecycle. De clienttests staan onder `apps/avaryn/src/test/` en `tool/productization/tests/`. Sites en native webassets zijn afgeleide buildbestanden, geen tweede productbron.

De bestaande FlutterFlow-workspace (`a-v-a-r-y-n-alpha-ynvyuq`), `dsl/`, typed SDK en `generated_code/` blijven behouden als historische referentie. De [eerdere werkwijze](docs/architecture/LEGACY_C010_FLUTTERFLOW_WORKSPACE.md) is gearchiveerd; exports mogen de officiële V8-bron niet overschrijven. Productisering vereist geen push naar de bestaande FlutterFlow Alpha.

Ontwikkeling en beoordeelde checkpoints blijven op de geverifieerde ontwikkelbranch. Een technisch checkpoint is geen menselijke C-010-acceptatie, AVARYN-main-merge of publieke storevrijgave. Er is geen C-011 gestart.
