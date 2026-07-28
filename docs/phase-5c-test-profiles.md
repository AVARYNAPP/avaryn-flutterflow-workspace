# AVARYN Fase 5C — lokale fictieve testprofielen

## Doel en grenzen

Deze profielen zijn uitsluitend deterministische testdata voor de lokale
Supabase-stack met project-ID `avaryn-flutterflow-workspace`. Alle accounts
gebruiken `example.invalid`, alle namen zijn herkenbaar fictief en er worden
geen e-mails of uitnodigingen verstuurd.

De aantallen zijn technische testvolumes, geen commerciële productlimieten:

| Profiel | Paarden | Routines | Today-items | Mediasessies | Open conflicten |
| --- | ---: | ---: | ---: | ---: | ---: |
| Test Basis | 3 | 3 | 6 | 1 | 1 |
| Test Medium | 8 | 8 | 24 | 4 | 2 |
| Test Extreme | 15 | 15 | 90 | 15 | 5 |
| Test Custom | 5 | 5 | 12 | 2 | 2 |

Custom kan met `AVARYN_CUSTOM_HORSES`, `AVARYN_CUSTOM_ROUTINES`,
`AVARYN_CUSTOM_ITEMS`, `AVARYN_CUSTOM_MEDIA` en
`AVARYN_CUSTOM_CONFLICTS` worden aangepast. De ruime scriptgrenzen
(1–50 paarden en overeenkomstig begrensde records) zijn uitsluitend
veiligheidsgrenzen voor lokale testbelasting.

## Scenario-inhoud

Ieder profiel bevat:

- drie fictieve ruiters, twee grooms, één trainer en twee gescheiden
  stalowners;
- één semantische paardeigenaar met alleen leesrechten op één paard;
- één ingetrokken gebruiker en één outsider zonder zichtbare Horse-data;
- een gebruiker met toegang tot twee stallen voor stabielwissels;
- Horse-relaties die losstaan van technische grants;
- per paard verdeelde `horse.basic`, planning-, voeding- en mediagrants;
- terugkerende dagelijkse en wekelijkse routines;
- items op twee logische lokale datums, assignments en één afgeronde
  uitvoering;
- actieve fictieve voerplannen, zonder medisch advies;
- private-media-uploadsessies in `pending` status. Er worden bewust geen
  niet-bestaande Storage-objecten als downloadklaar gemarkeerd;
- een native sync-devicecontract en open, niet-kritieke profielconflicten.

De versleutelde pending queue zelf is devicegebonden en wordt daarom niet als
plaintext databasescenario geseed. Die wordt in 5D via de runtime aangemaakt.

## Provisioning

Provisioning wist alle huidige lokale testdata en bouwt de database opnieuw
op vanaf de migraties:

```sh
tool/provision_phase_5c_profile_local.sh basis --confirm-local-reset
tool/provision_phase_5c_profile_local.sh medium --confirm-local-reset
tool/provision_phase_5c_profile_local.sh extreme --confirm-local-reset
tool/provision_phase_5c_profile_local.sh custom --confirm-local-reset
```

Een Custom-voorbeeld:

```sh
AVARYN_CUSTOM_HORSES=10 \
AVARYN_CUSTOM_ROUTINES=12 \
AVARYN_CUSTOM_ITEMS=48 \
AVARYN_CUSTOM_MEDIA=6 \
AVARYN_CUSTOM_CONFLICTS=3 \
tool/provision_phase_5c_profile_local.sh custom --confirm-local-reset
```

Alle vier profielen plus de workspace-tests:

```sh
tool/test_phase_5c_local.sh --confirm-local-reset
```

Alleen resetten, zonder profiel:

```sh
tool/reset_phase_5c_local.sh --confirm-local-reset
```

## Veiligheidsmodel

- De scripts vereisen zowel de exacte repository-project-ID als de exacte
  lokale Docker-container en het exacte Supabase-projectlabel.
- De actieve Docker-context moet via een lokale Unix-socket lopen; een TCP- of
  andere externe Docker-context wordt geweigerd.
- Een `DOCKER_HOST`-override is alleen toegestaan wanneer deze eveneens naar
  een lokale Unix-socket wijst; TCP/SSH-overrides worden vóór Dockeracties
  geweigerd.
- `--confirm-local-reset` is verplicht.
- `supabase db reset --local` is het enige resetpad.
- `[db.seed]` blijft uitgeschakeld; niets wordt impliciet geprovisioned.
- Er is geen `db push`, projectlink, remote URL, deployment of productiepad.
- De verificatie bewijst exacte volumes, stal B-isolatie, één-paardtoegang,
  ingetrokken toegang en outsider-deny via echte RLS.
- Herprovisioning begint altijd met een schone lokale database en levert
  daardoor dezelfde UUID’s, datums en scenarioverdeling.

De lokale accounts hebben geen bruikbare wachtwoorden. Interactieve
authenticatie- en uitnodigingsflows worden in fase 5D met de bestaande lokale
Auth/Mailpit-runners uitgevoerd.
