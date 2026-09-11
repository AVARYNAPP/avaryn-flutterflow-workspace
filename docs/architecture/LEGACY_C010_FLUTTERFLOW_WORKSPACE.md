> Historische FlutterFlow/Route-B-werkwijze. De officiële V8-productbron staat nu in `apps/avaryn/src`; volg de README in de repositoryroot voor actuele ontwikkeling.

# AVARYN — C-010 ontwikkelworkspace

Dit is de bestaande AVARYN Alpha-workspace voor FlutterFlow-project
`a-v-a-r-y-n-alpha-ynvyuq`. Start bij
[CURRENT_STATE.md](docs/status/CURRENT_STATE.md), het goedgekeurde
[Account Model v2-contract](docs/architecture/ACCOUNT_MODEL_V2_TECHNICAL_CONTRACT.md)
en de [lokale C-010 herstelstatus](docs/status/C010_LOCAL_REPAIR_2026-09-07.md).
C-010 blijft open voor menselijke acceptatie; C-011 is niet gestart.

## Lokaal ontwikkelen

De beheerde Route B combineert de ongewijzigde FlutterFlow-export, de huidige
handgeschreven runtimebronnen en gecontroleerde generatorcorrecties in een
aparte buildmap. De lokale runner gebruikt uitsluitend synthetische Auth- en
stalgegevens en expliciete loopbackpoorten. Docker en de aanwezige, vastgelegde
Flutter/Dart-toolchain zijn vereist; de runner voert geen upgrade of publicatie uit.

```sh
./tool/avaryn_local.sh start --target avaryn-c010-local --port-base 56020
./tool/avaryn_local.sh verify --target avaryn-c010-local
./tool/avaryn_local.sh status --target avaryn-c010-local
./tool/avaryn_local.sh stop --target avaryn-c010-local
```

`prepare` maakt de expliciet benoemde eigen omgeving klaar. `start` bouwt de
migrationketen, maakt echte lokale Auth-fixtures en bouwt de actuele release.
`verify` legt de gecontroleerde uitkomsten vast. `stop` raakt alleen resources
waarvan de eigendomslabels met het opgegeven doel overeenkomen. Credentials,
loopbackconfiguratie, caches en afgeleide builds horen onder `.avaryn-local/`
en worden niet ingecheckt. Gebruik `--state-dir` voor een andere private locatie.

## Bron en gegenereerde uitvoer

- `dsl/edit.dart` bevat de bestaande editflow, runtime-loaders en gedeelde
  `avarynC010Routes`-routekaart. `dsl/avaryn_*_runtime.dart` bevat de productcode.
- `dsl/c010_context_contract.dart` bevat de gedeelde canonieke context-, datum-
  en asynchrone requestgrenzen; de bijbehorende regressies staan in `test/`.
- `supabase/migrations/` bevat uitsluitend voorwaartse migrations;
  `supabase/tests/` en de lokale runner leveren de beveiligingscontroles.
- `tool/route_b/` bevat de actuele bronassembler, bekende-exportmanifest,
  expliciete doelcontrole en de Font Awesome 11-adapter met tests.
- `generated_code/` is een **read-only ruwe export**. Bewerk deze niet handmatig.
- `lib/flutterflow_project.dart` en de deelbestanden geven getypeerde handles
  voor FlutterFlow-pagina's, widgets, schema's en state.
- `.flutterflow/` bevat de bestaande SDK en workspaceconfiguratie.

Gebruik geen create-script tegen dit reeds gebonden project. Remote
`flutterflow ai run`, databasewijzigingen, deployment, hosting en publicatie
vereisen afzonderlijk mandaat. De lokale herstelrun geeft daarvoor geen toestemming.
Een lokaal groen resultaat is geen bewijs dat dezelfde wijziging remote draait.

## Toolchaingrens

De vastgelegde lokale combinatie is Flutter `3.44.8`, Dart `3.12.2`, FlutterFlow AI
`0.0.40` build `287a31d5` en Font Awesome Flutter `11.0.0`, met behoud van de
bestaande lockfiles. Onbekende generatorinput wordt geweigerd en moet eerst
inhoudelijk worden beoordeeld. Accountverwijdering blijft veilig geblokkeerd
zolang de volledige dependencycleanup en hervatbare deletion-orchestrator ontbreken.
