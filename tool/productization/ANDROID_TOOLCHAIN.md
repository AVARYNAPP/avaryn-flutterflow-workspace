# Projectgebonden Android-tooling

Status 2026-09-11: **JDK en Google commandlinetools gereed; Android SDK-componenten wachten op persoonlijke licentieacceptatie.** Geen globale installatie, shellprofielwijziging, app-ID, signingkey, emulatorstart of appcompile uitgevoerd.

De enige installatiemap is `.avaryn-local/productization-20260911/toolchains` onder deze repository. De bijbehorende `env.sh` stelt Java, Android-gebruikersdata, AVD-map en Gradle-cache alleen voor de aanroepende shell in. `$HOME` blijft ongewijzigd.

## Vastgelegde archieven

- Eclipse Temurin **21.0.12.1+1**, macOS aarch64, officiële Adoptium-release. Java en javac melden 21.0.12.1; beide exit 0.
- Google Android Command Line Tools **22.0**, ARM-build **15859902**. SDK-manager `--version`: exit 0. Het archief is bewust vastgezet op de officiële downloadpagina, niet de bewegende `latest`-repositoryverwijzing.
- Beide downloads zijn vóór uitpakken tegen de gepubliceerde **SHA-256** gecontroleerd. Exacte URLs en hashes staan in `android-toolchain-lock.json`; resultaten in de lokale `toolchains/manifest.json`.
- SDK-manager meldt dat de CLI deprecated is en verwijst naar `android sdk`. Het geïnstalleerde compatibele SDK-managerpad werkt; deze waarschuwing is geen installatiefout.

Herhaalbare installatie van alleen de twee bovenstaande archieven, vanaf de repositoryroot:

```sh
python3 tool/productization/install_android_toolchain.py
```

Het script accepteert geen SDK-licenties. Downloads worden hergebruikt uitsluitend als de checksum klopt. Een bestaande installatiemap zonder de bijbehorende eigen checksum-marker wordt geweigerd.

## Persoonlijke gebruikershandeling

Google SDK-manager is één keer gestart met gesloten standaardinvoer. De melding was `Accept? (y/N): Skipping following packages as the license is not accepted`. Ondanks exit 0 zijn alle vier componenten overgeslagen. `android-sdk/licenses/` is niet aangemaakt. Bewijs: `toolchains/license-boundary.json` en het bijbehorende log.

De gebruiker moet zelf de voorwaarden lezen en beslissen. Open een eigen terminal en voer uit:

```sh
cd /Users/sds/Documents/Codex/AVARYN/avaryn-flutterflow-workspace
source .avaryn-local/productization-20260911/toolchains/env.sh
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
  --sdk_root="$ANDROID_HOME" --channel=0 \
  "platform-tools" "emulator" "platforms;android-36" "build-tools;36.0.0"
```

Lees de getoonde voorwaarden en beantwoord de vraag uitsluitend zelf. Er is geen `yes`-pipe, vooraf geschreven license-hash of automatische akkoordoptie opgenomen. Een lokale kopie ter inzage staat in `toolchains/metadata/android-sdk-license.txt`.

Verwachte stabiele pakketversies uit de opgehaalde Google-repository: platform-tools 37.0.1, emulator 37.1.11 voor ARM, Android36 platformrevisie2, build-tools36.0.0. Deze zijn **nog niet geïnstalleerd**. `pending-sdk-packages.json` bewaart de concrete archief-URLs, Google-repositorychecksums en bronhash. Na persoonlijke installatie moeten de werkelijk verkregen versies worden vergeleken en vastgelegd; veranderde repositoryversies zijn niet automatisch goedgekeurd als dezelfde pin.

Na die stap kan de agent afzonderlijk `adb version`, `emulator -version` en de SDK-pakketlijst controleren. Er is nog geen Android-systeemimage of AVD, en nog geen werkende emulatorrun bewezen.

## Primaire bronnen

- [Google commandlinetools en SHA-256](https://developer.android.com/studio)
- [Google SDK repositorymetadata](https://dl.google.com/android/repository/repository2-3.xml)
- [SDK-manager](https://developer.android.com/tools/sdkmanager)
- [Adoptium archiefinstallatie en checksumcontrole](https://adoptium.net/installation/archives)
- [Adoptium JDK21 metadata](https://api.adoptium.net/v3/assets/latest/21/hotspot?architecture=aarch64&image_type=jdk&os=mac&vendor=eclipse)
