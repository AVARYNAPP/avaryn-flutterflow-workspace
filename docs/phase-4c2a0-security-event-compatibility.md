# Fase 4C.2A0 — compatibiliteit security-events

## Doel en begrenzing

Fase 4C.2A0 is de strikt noodzakelijke additieve voorbereiding van het
bestaande fase-4B-security-eventcontract. De uitbreiding maakt uitsluitend de
latere, getypeerde correlatie van Horse-grant- en revoke-events mogelijk.
Fase 4B blijft inhoudelijk en semantisch onveranderd.

Deze tussenfase implementeert geen Horse-tabellen, Horse-grants, Horse-RPC's,
profielmutaties of eventwriters. Er is niets naar productie gedeployed.

## Additieve uitbreiding

`public.stable_security_events` krijgt één nullable kolom zonder default:

```sql
horse_id uuid
```

De gesloten allowlist van `event_type` wordt uitsluitend uitgebreid met:

- `horse_access_granted`;
- `horse_access_revoked`.

De afzonderlijke correlatieconstraint verplicht bij deze twee typen een
niet-null `horse_id`. Alle bestaande fase-4B-eventtypen verplichten
`horse_id IS NULL`. Bestaande rijen worden niet herschreven of gebackfilled.
Metadata is niet de primaire Horse-correlatie en wordt daarvoor niet gebruikt.

## Verplichte gate voor fase 4C.2A

Totdat de onderstaande gate volledig in één additieve 4C.2A-migratie aanwezig
is, mogen er geen Horse-security-eventwriters bestaan:

1. `public.horses` bestaat;
2. `public.horses` garandeert uniek `(stable_id, id)`;
3. `stable_security_events(stable_id, horse_id)` heeft een samengestelde
   foreign key naar `horses(stable_id, id)`;
4. grant- en revoke-RPC's leiden `horse_id` uitsluitend server-side af uit het
   vergrendelde targetpaard;
5. mutatie en security-event worden in dezelfde transactie geschreven;
6. de RPC's volgen het fase-4B stable-scoped authoritylockprotocol.

De tijdelijke afwezigheid van de foreign key is dus geen toestemming om een
eventwriter te bouwen. Zij voorkomt uitsluitend een ongeldige voorlopige
foreign key naar de in deze fase nog niet bestaande `public.horses`-tabel.

## Beveiligingsbehoud

RLS, grants, append-onlybescherming en directe-DML-beperkingen worden niet
gewijzigd. Bestaande functies, signatures, eventwriters en lockprotocollen
blijven onaangeroerd. De migratie verruimt geen rechten en introduceert geen
metadataescape, polymorf resourcesysteem, trigger of lock.
