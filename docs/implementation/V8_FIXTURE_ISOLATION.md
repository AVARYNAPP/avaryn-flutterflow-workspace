# V8 — isolatie van demo-fixtures

11 september 2026. Afgebakende bronwijziging in `apps/avaryn`; geen backend-, Sites- of Git-acties.

**PASS:** de releasecompiler importeert `empty-state.js`, `empty-personas.js` en `empty-facilities.js`. Hij weigert een release waarin `data.js`, `demo-personas.js` of `demo-facilities.js` achterblijft. De standaardrelease heeft een neutrale actor zonder paarden/rechten en lege faciliteiten met een actuele kalenderdag. Verbonden views blijven de serveractor en servercapabilities gebruiken. Demo selecteert de drie oorspronkelijke fixtureproviders.

Gewijzigd: `src/horse-access.js`, `src/facility-data.js`, nieuwe `src/demo-personas.js`, `src/demo-facilities.js`, `src/empty-personas.js`, `src/empty-facilities.js`, `scripts/build.mjs` en `src/test/fixture-isolation.test.mjs`. Geen dependencies toegevoegd. De exports voor bestaande callers blijven behouden. Demo-persona’s, faciliteitenfixtures en soortmetadata komen exact overeen met de vóór de verplaatsing berekende waarde-hashes; de tests bewaken die gelijkheid.

## Bewijs

Uit `apps/avaryn`:

```sh
node --test src/test/fixture-isolation.test.mjs src/test/p2-ui-render.test.mjs src/test/mobile-task-render.test.mjs src/test/active-stable-view.test.mjs
npm run build:demo
npm run build
```

Resultaat: **36/36 tests PASS** (9 nieuwe isolatiegevallen, 27 bestaande rol/scope/rendergevallen). Beide builds exit 0, kandidaat `C010-V8-PRODUCTIZATION-20260911-01`, elk 30 manifestbestanden. `dist` eindigt in releasemodus; alle 30 bestandshashes en lengtes zijn teruggelezen en gelijk aan het release-buildmanifest. Dit is het buildmoment van deze subtaak; latere wijzigingen van de hoofdwerkstroom vereisen een nieuw manifest.

| Bewijs op dit buildmoment | SHA256 |
|---|---|
| `scripts/build.mjs` | `7699ad74bdf0d01d76c8689c9f3bbbee06abf2aa56cb66887da68d6d8bece612` |
| Nieuwe isolatietest | `5e7968b98391cebc8d69f9be726760f99bcd0428fcf7e4c1675e6273817c802f` |
| Demo `app-FRKCFRVI.js` | `d802fa5d99c89e1345bf9d23fb3cab55eec82c5a7c5ce307103cf31280cd36c9` |
| Demo-buildmanifest | `42a341baa4c5c9b5b2e78ecc45a43be621b22c51b338b9596a98cdc0fbc39264` |
| Release `app-KFO7QLIY.js` | `73181220b8165e1643c62fa7624a0ac81917009dfa3ce7664ed5bb8eb48d5cd1` |
| Release-buildmanifest | `ef590051d67b7cbbc60df858bef126bd8ebfc1742d27a1461a10f055f3be534d` |

`build-manifest.json.fixtureIsolation` bewaart modus, geselecteerde providers en werkelijk aangetroffen demo-inputs. De release heeft `demoInputs: []`. De nieuwe tests controleren daarnaast geweigerde restimports, alternatieve relatieve importpaden, neutrale startup, stale ongeauthenticeerde gegevens, actuele serverrechten, behoud van verbonden faciliteiten en aangrenzende capaciteitsslots.

## Afzonderlijk gemelde restpunten buiten deze wijzigingsscope

Dit bewijs is **geen claim dat iedere illustratieve of historische string uit de hele app verdwenen is**. De op dit moment gebouwde JS bevat nog:

- `components.js`: assignee-initialen vallen terug op `Noor Meijer`.
- `menu-ui.js`: voorbeeldposts met Emma/Noor/Orion.
- `task-timing.js`, `planning.js`, `daily-ui.js`, `backend-controller.js`, `vitality.js` en `app.js`: enkele vaste `2026-09-10`-fallbacks.
- `app.js`: testaccount-/previewcopy en een voorbeeldnaam in een invoerplaceholder.
- Bestaande generieke paardafbeeldingen en afbeeldingsfallbacks, waaronder `assets/orion.png`; deze zijn geen operationele databasefixtures.

Deze restpunten zijn aan de hoofdwerkstroom gemeld en hier niet gewijzigd. De zeven concrete fixture-reserverings-ID’s en de volledige persona-namen Emma de Vries, Sophie Bakker en Daan Visser komen niet meer voor in de release-JS. Alleen een nieuwe exacte bundelcontrole na de overige productwijzigingen kan een bredere vrijgaveclaim ondersteunen.
