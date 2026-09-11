# V8 — account- en kerncontracten

Broncontrole: **11 september 2026**. Dit document beschrijft bestaande SQL, Edge-functies en aanroepen uit de Dart-runtime. Het is geen bewijs van actuele uitrol, SMTP-bezorging of uitgevoerde nieuwe gebruikersflows. Er zijn voor deze inventarisatie geen backendwrites uitgevoerd.

Uitgangspunt is **zelfregistratie met e-mailbevestiging**. Een vooraf opgegeven lijst testeradressen is geen productvoorwaarde. Auth, profiel, functievoorkeuren, stalrechten en paardrechten blijven afzonderlijke begrippen.

## 1. Auth en profiel

Onderstaande Auth-aanroepen zijn de bestaande Supabase SDK-contracten. RPC's gaan als JSON-object met de exacte `p_*` namen naar `POST /rest/v1/rpc/<functie>`, met de huidige gebruikerssessie. Een SQL `returns table` levert een array op; de profiel- en paardaanmaakaanroepen verwachten precies één rij. `returns jsonb` levert rechtstreeks een object op.

| Functie | Parameters | Resultaat / minimale verwerking |
|---|---|---|
| `auth.signUp` | `email`, `password`, `emailRedirectTo: <app-origin>/auth/callback` | Auth-resultaat; toon bevestigingsscherm, behandel dit niet als reeds aangemelde gebruiker. Bestaande clientcontrole: geldig e-mailadres; wachtwoord ≥8 tekens met hoofdletter, kleine letter en cijfer. De ingestelde Auth-policy blijft leidend. |
| `auth.verifyOTP` | `tokenHash`, `type: email` | Alleen een sessie met `user.emailConfirmedAt` vervolgt naar profiel laden. Bestaande callback accepteert uitsluitend `type=email` en een tokenhash van 16–2048 tekens zonder witruimte/controltekens; verificatie start door de bevestigingsknop. |
| `auth.resend` | `type: signup`, `email`, `emailRedirectTo: <app-origin>/auth/callback` | Bevestigingsmail opnieuw aanvragen; bestaande UI heeft 60 seconden wachttijd. |
| `auth.signInWithPassword` | `email`, `password` | Niet-null sessie vereist. Daarna profiel laden; geen lokale rol- of stalkeuze als bewijs van bevoegdheid. |
| `auth.resetPasswordForEmail` | `email`, `redirectTo: <app-origin>/auth/reset-password` | Neutrale melding ongeacht wel/niet bestaand account. Vervolgens `verifyOTP(tokenHash, type: recovery)`; pas met de bijbehorende actuele herstelsessie `auth.updateUser(UserAttributes(password: ...))`. |
| `get_current_account_profile()` | Geen | Eén actuele, actieve profielrij. Geen insert. Ontbrekend actief profiel: `42501 / ACTIVE_PROFILE_REQUIRED`. |
| `update_current_account_profile(...)` | Zie exacte lijst hieronder | Dezelfde profielrij; `result_code` is `updated` of `no_change`. `PT409 / PROFILE_VERSION_STALE` vraagt actuele gegevens en vergelijking met de bewaarde invoer. |

De Auth-inserttrigger `phase_4a_auth_user_profile` roept `phase_4a_create_profile_for_auth_user()` aan. Deze maakt servermatig een **apart, duurzaam profiel-UUID**, gekoppeld via `auth_user_id`, met status `active`, versies 1, locale `und`, tijdzone `UTC` en thema `system`. Dit gebeurt bij Auth-aanmaak, niet pas bij e-mailbevestiging. De client maakt geen profielrij aan en verleent geen rechten via Auth-metadata.

Exacte profielupdate, zonder weggelaten velden:

```text
p_expected_row_version bigint
p_first_name text                 p_last_name text
p_phone_e164 text                 p_locale text
p_time_zone text                  p_theme_mode text
p_onboarding_intent text          p_complete_onboarding boolean
p_avatar_object_path text         p_correlation_id uuid
```

Dit is een volledige veldenset, geen gedeeltelijke PATCH: behoud bijvoorbeeld bij een thema- of avatarwijziging de overige actuele waarden. Lege strings worden genormaliseerd naar null; lege locale/tijdzone/thema naar `und`/`UTC`/`system`. Voltooide onboarding vereist voornaam en intentie: `createStable`, `joinStable` of `individualHorse`. Dit zijn keuzes, geen organisatie- of paardaanmaak. De voltooiingstijd wordt eenmaal gezet. Telefoon is E.164; locale `und` of `xx[-YY]`; tijdzone een geldige IANA-zone; thema `system|light|dark`.

Beide profiel-RPC's retourneren: `result_code, profile_id, first_name, last_name, display_name, avatar_object_path, phone_e164, locale, time_zone, theme_mode, onboarding_intent, onboarding_completed_at, profile_status, access_version, row_version, created_at, updated_at`. `p_correlation_id` is auditcorrelatie; de profielupdate biedt hiermee geen algemene herhaalgarantie na een onzekere write.

**Minimumflow:** signup → bevestigingsmail → expliciete OTP-verificatie → actuele sessie → profiel ophalen → onboarding opslaan met gelezen versie → persoonlijke Vandaag. Een gebruiker zonder stal hoeft geen fictieve stal te kiezen. Later opnieuw inloggen en herladen gebruikt dezelfde profiel-RPC. Iedere late response moet nog bij dezelfde actor én aanvraaggeneratie horen; logout/accountwissel wist de vorige presentatie en concepten.

**Omgeving:** correcte Auth Site URL, exact toegestane callbacks, e-mailbevestiging en werkende bezorging zijn aparte uitrolvoorwaarden. De bestaande first-party templates zijn `{{ .SiteURL }}/auth/callback?token_hash={{ .TokenHash }}&type=email` en de overeenkomstige `/auth/reset-password?...&type=recovery`. Log nooit tokenhashes, wachtwoorden of sessietokens.

Bronnen: [Auth/profielruntime](../../dsl/avaryn_account_runtime.dart), [profielbootstrap](../../supabase/migrations/202608040001_c003a_identity_audit_foundation.sql), [profiel-read/onboarding](../../supabase/migrations/202608060001_c007_personal_auth_onboarding.sql), [actuele profielupdate/PT409](../../supabase/migrations/202609080002_c010_ux_profile_cas_http.sql), [bestaande e-mailflow](C007_PERSONAL_AUTH_ONBOARDING.md).

## 2. Mijn functieprofiel

| Functie | Parameters | Resultaat en voorwaarden |
|---|---|---|
| `get_my_c010_function_profile()` | Geen | JSON `{profile_id, functions, row_version}`. Nog niet opgeslagen: `functions: []`, `row_version: null`. |
| `save_my_c010_function_profile(...)` | `p_functions text[]`, `p_expected_row_version bigint`, `p_request_id uuid` | JSON `{profile_id, row_version, idempotent}`; vervolgens opnieuw lezen voor de genormaliseerde selectie. Eerste save verwacht null; anders de gelezen versie. |

Toegestaan zijn 1–9 unieke waarden uit `owner, rider, manager, trainer, groom, farrier, vet, physio, nutrition`. De server sorteert en dedupliceert. Latere functies `breeder, partner, organizer, sponsor` horen niet in deze save. `PT409 / C010_FUNCTION_VERSION_STALE` is een versieconflict. Zelfde request-ID met dezelfde payload geeft de bestaande uitkomst; gewijzigde payload met hetzelfde ID geeft `C010_P2_IDEMPOTENCY_CONFLICT`.

Dit zijn persoonlijke voorkeuren, **geen rechten**. De RPC leidt het profiel af uit de actuele actor; een functiekeuze verleent geen stalbeheer, paardtoegang of boekingsrecht. Bij het verlaten van actieve profielstatus wist de bestaande lifecycletrigger deze voorkeuren.

Bron: [Connected-functievoorkeuren](../../supabase/migrations/202609110001_c010_connected_facilities.sql), functies `get_my_c010_function_profile`, `save_my_c010_function_profile`, `private.c010p2_receipt/finish` en `private.c010p2_clear_preferences`.

## 3. Stal en paard

| Functie | Exacte parameters | Resultaat / veiligheidsgrens |
|---|---|---|
| `create_c010_stable` | `p_name text`, `p_location_name text`, `p_request_id uuid` | JSON `{organization_id, membership_id, row_version, access_version, name, location_name, idempotent}`. Naam 1–160 tekens; locatie optioneel ≤240. Actuele actor wordt via `create_stable_account`/`create_organization` servermatig initiële bevoegdheidhouder. Actor/request-lock en payloadreceipt voorkomen dubbele aanmaak bij gelijke retry. |
| `update_c010_stable` | `p_organization_id uuid`, `p_expected_row_version bigint`, `p_name text`, `p_location_name text`, `p_address_line text`, `p_locality text`, `p_request_id uuid` | JSON `{organization_id, row_version, name, location_name, address_line, locality, idempotent}`. Vereist actuele `organization.edit`, ook vóór ontvangstbewijshergebruik. Volledige vier tekstvelden; gelezen versie ≥1. |
| `list_c010_stables()` | Geen | Array met `organization_id, name, location_name, locality, lifecycle_status, role_codes, horse_count, team_count, next_activity_at, can_edit, can_manage_team, can_view_planning, can_view_feeding, row_version`. Alleen servermatig toegankelijke stallen. Aantallen zijn projecties, geen eigen autorisatiebron. |
| `get_c010_stable_workspace` | `p_organization_id uuid`, `p_from timestamptz`, `p_through timestamptz`, `p_on_date date`, `p_planning_scope text = 'all'` | JSON met `organization`, `capabilities` en toegestane deelprojecties. `p_on_date` mag niet null zijn; periode oplopend, maximaal één jaar; scope `mine|all`. Gebruik de gekozen serverdag. |
| `create_canonical_horse_profile` | Zie veldenset hieronder | Eén rij `{horse_id, access_version, authority_version, row_version, result_code, applied}`. Nieuw: `created/true`; herhaling: `idempotent_replay/false`. Geen stalparameter. |
| `list_c010_horses()` | Geen | Array met paardprofielvelden, `profile_media_asset_id`, `lifecycle_status`, versies en `can_edit/can_manage/can_manage_planning/can_manage_feeding/can_assign/can_share/can_transfer`. Alleen `horse.view`-toegankelijke paarden. |
| `get_canonical_horse_workspace` | `p_horse_id uuid` | JSON met onder meer relaties, eigendom, delegaties en verblijfplaatsen; vereist `horse.view`. Het primaire paardprofiel komt uit de paardenlijst. |

Exacte paardaanmaak:

```text
p_display_name text               p_official_name text
p_birth_date date                 p_sex text
p_breed text                      p_discipline text
p_level text                      p_color text
p_notes text                      p_chip_number text
p_passport_number text            p_passport_valid_until date
p_correlation_id uuid
```

Minimum: naam 1–160 tekens, één behouden correlation-UUID, `p_sex: 'unknown'` en overige optionele velden null. Geslacht is `mare|gelding|stallion|unknown`; notities maximaal 2000 tekens. De server maakt de actuele actor primaire paardbevoegdheidhouder. Aanmaak vereist geen stal en creëert niet automatisch een stalverblijf of rechten voor stalgenoten. De herhaalcontrole is actor + correlation-ID; deze vergelijkt bij paardaanmaak niet opnieuw de gehele payload. Behoud daarom exact dezelfde conceptinhoud tijdens een onzekere retry.

**Minimumflows:** stal aanmaken → resultaat bewaren → `list_c010_stables` en workspace lezen; stal bewerken → huidige volledige waarden + versie → save → readback. Paard aanmaken → resultaat-ID → `list_c010_horses` → paard tonen; optionele verblijfplaats/relaties blijven afzonderlijke bestaande workflows. Rolnamen, voorkeuren en stalverblijf vervangen nooit de servercapabilities.

**Bestaande conflictgrens:** de gecontroleerde `update_c010_stable` gebruikt nog `40001 / STALE_STABLE_VERSION`; dit is niet dezelfde expliciete HTTP-409-afspraak als profielupdate. Ook de bestaande paardprofielupdate en fotoselectie gebruiken `40001 / STALE_HORSE_VERSION`. Een clienttimeout bewijst geen mislukte write en annuleert de serverquery niet. Bewaar de invoer, lees terug en handel deze grens gericht af vóór een conflictflow als bewezen voltooid wordt gerapporteerd. Dit document wijzigt de SQL niet.

Bronnen: [stalcreate met lock](../../supabase/migrations/202608120003_c010_create_stable_idempotency_lock.sql), [canonieke stalbasis](../../supabase/migrations/202608080002_c009_stable_account_vertical.sql), [stalupdate/lijsten](../../supabase/migrations/202608120001_c010_stable_team_collaboration.sql), [actuele workspace](../../supabase/migrations/202609090004_c010_invitation_recipient_labels.sql), [paardaanmaak/read](../../supabase/migrations/202608080001_c008_canonical_horse_vertical.sql), [paardconstraints](../../supabase/migrations/202608050002_c003c_canonical_horses_relationships.sql). Bestaande callers: [stalruntime](../../dsl/avaryn_stable_account_runtime.dart), [paardruntime](../../dsl/avaryn_horse_account_runtime.dart).

## 4. Foto's en overige paardmedia

### Paardmedia: canonieke Edge-flow

`POST /functions/v1/media-assets` gebruikt JSON en de actuele `Authorization: Bearer <gebruikerssessie>`. De Edge valideert die sessie met Auth. Gebruik de **canonical** acties; geen legacy stalmedia-aanmaak voor een nieuw canoniek paard.

| Stap | Body / functie | Resultaat |
|---|---|---|
| 1. Sessie maken | `{action:'canonical_create', horse_id, original_filename, mime_type, request_id}` | `{media_asset_id, row_version, status, idempotent, uploads:[{variant, object_path, expected_mime_type, max_byte_size, signed_upload_url, upload_token}]}`. Reeds ready bij retry: `uploads: []`. |
| 2. Bytes uploaden | Voor iedere servervariant: `storage.from('horse-media').uploadBinaryToSignedUrl(object_path, upload_token, bytes, FileOptions(contentType: ..., upsert: true))` | Werkelijke objectupload naar het verstrekte pad. Het bestaan van een uploadsessie is nog geen geslaagde foto. |
| 3. Finaliseren | `{action:'canonical_finalize', media_asset_id, expected_row_version, request_id}` | `{media_asset_id, status, row_version, idempotent}`. Edge haalt werkelijk opgeslagen bytes op, controleert omvang, MIME, decodering en SHA256; server maakt pas daarna `ready`. |
| 4. Als profielfoto kiezen | RPC `set_canonical_horse_profile_media(p_horse_id uuid, p_media_asset_id uuid, p_expected_row_version bigint, p_request_id uuid)` | `{horse_id, profile_media_asset_id, row_version, idempotent}`. Verwachte versie is die van het **paard**, niet de upload. Alleen ready afbeelding van hetzelfde paard; null maakt de selectie leeg. |
| 5. Afbeelding lezen | `{action:'canonical_download', media_asset_id, variant:'original'|'thumbnail'}` | `{signed_download_url, expires_in:60, mime_type}`. Actuele `horse.view`-toegang vóór ondertekening; anders `MEDIA_UNAVAILABLE`. Vernieuw na verlopen URL. |
| Herstel na onzeker antwoord | RPC `get_c010_my_media_upload_status(p_create_request_id uuid)` | Eigen, zichtbare ready asset: `{id,status}`; anders null. Null bewijst niet dat er geen pending upload bestaat. |
| Archiveren | RPC `archive_canonical_media_asset(p_media_asset_id uuid, p_expected_row_version bigint, p_request_id uuid)` | `{media_asset_id,status,row_version,idempotent}`; actuele `horse.edit`. Eerst een actieve profielfotoselectie vervangen/leegmaken (`MEDIA_PROFILE_SELECTION_ACTIVE`). Versieconflict: `40001 / MEDIA_VERSION_CONFLICT`. Auditgeschiedenis blijft behouden. |

Afbeeldingen: JPEG/PNG/WebP, origineel maximaal 10 MiB, verplichte echte thumbnail maximaal 1 MiB met hetzelfde MIME-type. PDF: maximaal 20 MiB, uitsluitend origineel en niet bruikbaar als paardprofielfoto. De client maakt de thumbnail; de Edge valideert beide varianten. JPEG/WebP-decodering gebruikt de bestaande gepinde decoderimports; de runtime haalt hun WASM-modules momenteel van jsDelivr, dus ook die bereikbaarheid is een bestaande Edge-afhankelijkheid.

De bucket blijft privé. `get_canonical_media_upload_session`, `finalize_canonical_media_asset` en `authorize_canonical_media_asset_download` zijn **service-role-only** RPC's achter de Edge. Neem deze niet op als browser-RPC; laat de client geen actor-ID, objectpad of inhoudshash als autoritatief bewijs aanleveren. De servicekey blijft uitsluitend servermatig.

`SUPABASE_PUBLIC_URL` bepaalt het exacte bereikbare origin van de ondertekende URL; de Edge accepteert hiervoor HTTPS of expliciet lokale `http://127.0.0.1`. Rewrite alleen het gecontroleerde interne origin en de vaste `horse-media`-signpaden. `AVARYN_ALLOWED_ORIGINS` moet voor de besloten preview expliciet staan: exact toegestane origins; zonder deze configuratie heeft de bestaande Edge een wildcardfallback. CORS verleent geen inhoudsrechten.

**Transportgrens:** de bestaande lokale/preview-Kong vereist daarnaast de publieke `apikey` voor Storage. Een kale `<img src>` levert die header niet. Gebruik het reeds bestaande publieke clientkey-contract op het exacte doel/bucket, bijvoorbeeld een gecontroleerde fetch → Blob-URL. Geen servicekey of versoepeling van Storage-signaturen; trek Blob-URL's bij vervanging/logout in. Een eerder verstrekte signed URL kan tot expiratie bruikbaar blijven: niet claimen dat deze onmiddellijk wordt ingetrokken door een UI-purge.

Bronnen: [media Edge](../../supabase/functions/media-assets/index.ts), [canonieke media-RPC's/ACL](../../supabase/migrations/202608080003_c0091_canonical_media_hardening.sql), [eigen uploadstatus](../../supabase/migrations/202609090003_c010_historical_actor_privacy.sql), [bestaande volledige paardupload](../../dsl/avaryn_horse_account_runtime.dart).

### Avatar: aparte bestaande Storage-flow

De privébucket `avatars` accepteert JPEG/PNG/WebP tot 5 MiB. Upload met de gebruikerssessie via `storage.from('avatars').uploadBinary(path, bytes, FileOptions(contentType: ..., upsert: true))`, pad `<auth-user-UUID>/avatar-<UUIDv4>.<jpg|jpeg|png|webp>`. Dit gebruikt het Auth-ID, niet het canonieke profiel-ID. RLS beperkt alle vier objectoperaties tot die eigen map; de latere restrictieve policy vereist ook een actief profiel.

Volgorde: bytes controleren → nieuw object uploaden → actor/generatie opnieuw controleren → volledige profielupdate met `p_avatar_object_path` en huidige versie → bevestigde profieluitkomst → oude avatar opruimen → `createSignedUrl(path, 3600)` → tonen. Verwijderen: eerst profielreferentie leeg opslaan, daarna oud object opruimen. Bij een definitieve CAS-/autorisatie-/validatiefout mag de nieuwe upload worden opgeruimd; bij timeout/netwerkfout eerst profiel teruglezen, zodat een mogelijk opgeslagen referentie niet naar een verwijderd object gaat wijzen. De avatarflow heeft geen canonieke media-finalize/decodering; de bestaande client doet bestandsinhoudcontrole en Storage controleert bucketlimieten en MIME.

Bronnen: [avatarbucket en eigen-map-RLS](../../supabase/migrations/202607250001_phase_4a_identity.sql), [actieve-profielrestrictie](../../supabase/migrations/202609090001_c010_account_deletion.sql), [avatarcallers en compensatie](../../dsl/avaryn_account_runtime.dart).

## 5. Kleinste integratiegrens voor de nieuwe V8-client

De gecontroleerde voorganger is `.avaryn-local/avaryn-c010-v8-rider-vitality-date-priority/`. Zijn `connected-worker.mjs` laat voor Auth alleen token/password-refresh, user-read en logout door. De bestaande 25 RPC's bevatten profiel-read en functievoorkeuren, maar **geen** profielupdate, stalcreate/update, paardcreate of media. De nieuwe client mag de aanwezigheid van SQL dus niet gelijkstellen aan een beschikbare proxyroute.

Voeg bij de nieuwe implementatie alleen de gekozen Auth-acties, publieke RPC-namen en begrensde Edge/Storage-paden toe; geen algemene RPC-, bucket- of service-route. Ondertekende media-URL's bevatten momenteel `/storage/v1/...` op het ingestelde publieke origin en niet automatisch het V8 `/api`-prefix: leg de mapping expliciet vast. Bewaar bodylimieten, timeouts, sessiecontrole en accountwisselguards. Bevestig vóór oplevering minimaal registratie/mail/callback/herlogin, profiel-CAS/readback, functievoorkeuren zonder extra rechten, persoonlijke paardaanmaak, stalcreate/update en upload → zichtbaar beeld → reload; deze inventarisatie zelf claimt die nieuwe integratietests niet.
