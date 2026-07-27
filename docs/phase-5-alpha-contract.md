# AVARYN Fase 5 — contract voor een testklare besloten webalpha

## 1. Status en basis

Dit document is het bindende repositorycontract voor fase 5 en hoort bij
besluitrecord `AVARYN-P5-2026-07-27`. Het bouwt voort op de groene
fase-4-backend- en securityregressiebasis, met bekende FlutterFlow-waarschuwingen
en nog incomplete Alpha-UI:

- Git-basis: `3fca50764dde5575ed8be8097ba090159b8d4ba4`;
- FlutterFlow-projectcommit: `0FZW5Yak1yDvRiVOdoui`;
- project: `a-v-a-r-y-n-consumer-app-8yb89s`;
- branch: `main`;
- databasebasis: migraties `202607250001` tot en met `202607270006`.

De fase-1-PRD, App Blueprint en oorspronkelijke FlutterFlow-webpilotplanning
zijn niet als afzonderlijke bestanden in deze repository of lokale
Git-geschiedenis aanwezig. Hun fase-5-relevante productgrenzen zijn bindend
opnieuw vastgesteld in de nieuwere fase-5-opdracht en de goedgekeurde
fase-4-contracten. De actuele fase-5-opdracht heeft voor deze Alpha voorrang;
ontbrekende oude conceptbestanden mogen niet worden gebruikt om productgedrag
toe te voegen, weg te laten of opnieuw te interpreteren.

## 2. Alpha-doel

De besloten Alpha bewijst dat een klein team veilig kan samenwerken rond
paarden, dagelijkse planning, uitvoering, voeding en operationele media. De
beoogde schaal is 3–15 paarden en een klein vast team.

Binnen scope:

- accountregistratie, verificatie, login, herstel en logout;
- stallen, uitnodigingen, memberships en authoritywissels;
- Horse-profiel, relaties en expliciete toegangsgrants;
- Today, taken, routines, toewijzing en uitvoering;
- voeding en feitelijke voederregistratie;
- private operationele media;
- private Realtime-wake-ups en duurzame cursorcatch-up;
- begrensde versleutelde offline dagsets op ondersteunde platforms;
- pending-sync, idempotentie, conflict- en revoke-afhandeling;
- begrijpelijke states, responsieve werking en testdocumentatie.

Buiten scope:

- stal-ERP, box-/paddock-/massaplanning en bulkmanagement;
- Stable Display, klantportalen, chat, marketplace en webshop;
- AI-coaching, medische advisering of autonome voer-/behandelbeslissingen;
- betaalfuncties, publieke lancering en app-storepublicatie;
- nieuwe analytics-, tracking- of feedback-SDK's;
- productie- of stagingdeployment zonder aparte toestemming.

Legacy-import, conflictbeheer voor gevoelige medische/compliancegegevens en
kritieke taken waarvan escalatie-/overridebeleid niet is vastgesteld, zijn
geen Alpha-gebruikersflow. De al aanwezige backendfundering blijft wel
regressiedekking houden.

## 3. Autorisatiebegrippen

Productpersona's en autorisatierollen zijn verschillende concepten en mogen
niet worden samengevoegd.

| Begrip | Betekenis in de Alpha | Autorisatiebron |
| --- | --- | --- |
| ruiter | semantische werkcontext rond één of meer paarden | actieve membership plus expliciete grant en/of assignment |
| groom | dagelijkse uitvoerder | actieve membership plus expliciete grant en/of assignment |
| trainer | semantische trainingscontext | actieve membership plus expliciete grant en/of assignment |
| eigenaar | semantische eigenaarcontext van een Horse | actieve membership plus expliciete grant; niet automatisch stable-owner |
| `owner` | hoogste stabiele authorityrol | `stable_memberships.role` |
| `admin` | gedelegeerde stalbeheerder | `stable_memberships.role` |
| `member` | regulier teamlid | `stable_memberships.role` |
| `viewer` | read-only teamlid | `stable_memberships.role` |

Een persona, naam, e-mailadres, zichtbare knop of clientclaim verleent nooit
toegang. Een Horse-relatie is uitsluitend semantisch en verleent nul
capabilities. Alleen de actuele server-side membership/rol, expliciete grant,
assignment, datacategorie en RLS/RPC-controle zijn bindend.

## 4. Permanente beveiligings- en integriteitsregels

1. `stable_id` blijft de tenantgrens; Horse-toegang kan die grens nooit
   verruimen.
2. Auth-UUID, actor, authority, stable, rol en permission worden server-side
   bepaald of opnieuw gevalideerd.
3. Securitykritieke writes blijven RPC-only en least-privileged.
4. Directe client-DML blijft geweigerd waar het fase-4-contract dat vereist.
5. Kritieke operationele data gebruikt geen last-write-wins.
6. Online en offline retries behouden exact dezelfde request-ID en payload.
7. Realtime-payloads zijn alleen private wake-upsignalen zonder domeindata.
8. Offline plaintext bestaat alleen in geheugen; duurzame dagsets en pending
   executions blijven versleuteld en auth-/stalgebonden.
9. Logout, accountwissel, stalwissel, revoke en authoritywijziging wissen
   ontsleutelde toestand vóór asynchrone cleanup.
10. Horse- en Riderrechten blijven afzonderlijke domeinen.
11. Testdata is fictief, deterministisch en uitsluitend lokaal provisionable.
12. Seeds, resets en testtools bevatten geen externe projectreferentie en
    benaderen geen externe omgeving.
13. Er worden geen secrets, signed URLs, tokens of persoonsgegevens gelogd,
    gedocumenteerd of gecommit.
14. Een FlutterFlow-projectcommit is toegestaan; publiceren of deployen niet.

## 5. Web- en offlinegrens

Fase 4C.7 schakelt duurzame offline opslag in de browser bewust uit omdat de
webapp geen contractueel goedgekeurde OS-backed sleutelopslag heeft. De
versleutelde offlinepilot is daarom alleen actief op ondersteunde native- en
desktopplatforms. Web blijft online functioneren en faalt offline gesloten.

De fase-5-opdracht vraagt tegelijk om een besloten webalpha én om aantoonbaar
offline werken. Dit is een open productbeslissing en wordt niet door
implementatie ingevuld. Browseroffline wordt niet stilzwijgend toegevoegd.
Tot de keuze uit het besluitrecord is gemaakt, kan browseroffline niet groen
worden afgetekend. Native/desktop-offline en alle onafhankelijke webflows
kunnen wel veilig verder worden bewezen.

## 6. Definition of done per subfase

Een fase-5-subfase is pas groen wanneer:

1. scope en traceerbaarheid actueel zijn;
2. implementatie en documentatie overeenkomen;
3. relevante lege-reset- en upgradepaden zijn bewezen indien de database
   wijzigt;
4. positieve én negatieve RLS/RPC-tests groen zijn;
5. relevante FlutterFlow-, Flutter-, web- en gedragstests groen zijn;
6. concurrency/idempotentie wordt herhaald waar races mogelijk zijn;
7. een onafhankelijke read-only audit geen open P0/P1/P2 bevat;
8. `git diff --check` en `git diff --cached --check` groen zijn;
9. lockfiles, generated code, secrets en machinepaden gecontroleerd zijn;
10. de afzonderlijke commit non-force op `origin/main` staat en de werkboom
    schoon is.

## 7. Technische uitvoeringsvolgorde

| Subfase | Doel | Verwachte repository-uitkomst |
| --- | --- | --- |
| 5A | contract, inventaris en traceerbaarheid | dit contract en de traceerbaarheidsmatrix |
| 5B.1 | account, onboarding, profiel, stal, team en navigatie | complete en niet-doodlopende bestaande flows |
| 5B.2 | Horse-profiel en cloudbron | create/update/archive zonder lokale split-brain |
| 5B.3 | Horse-authority | semantische relaties, expliciete grants en revoke-UI |
| 5B.4 | private operationele media | upload/finalize/download/archive binnen Horse/executioncontext |
| 5B.5 | planning en uitvoering | series, assignment, Today, execution en correctie |
| 5B.6 | voeding | versionering, items, overrides, activation en feitelijke uitvoering |
| 5B.7 | Realtime, pending-sync en conflicten | multi-client lifecycle- en statebetrouwbaarheid |
| 5B.8 | responsive en a11y | mobiel/tablet/desktop, keyboard, semantics en tekstschaal |
| 5C | fictieve profielen en deterministische provisioning | lokale seeds, reset en scenariofixtures |
| 5D | formele Alpha-acceptatie en kwaliteitsgates | reproduceerbare geautomatiseerde en handmatige bewijzen |
| 5E | testprotocol en operationele gereedheid | tester-, incident-, rollback-, privacy- en deploymentdocumentatie |

Iedere 5B-slice levert vóór zijn implementatie de minimaal benodigde
deterministische lokale fixture en negatieve tegenproef; 5C consolideert die
fixtures daarna tot de vier formele testprofielen. Iedere logisch afgebakende
subfase krijgt een afzonderlijke audit, commit en push. Er volgt geen externe
staginghandeling vóór de deploymentgate.

## 8. Deploymentgate

Na 5A–5E wordt alleen gerapporteerd:

- welk technisch bewijs groen is;
- welke bekende beperkingen overblijven;
- de aanbevolen staging-/hostingroute en kosten;
- benodigde secrets en handmatige acties;
- rollback en gegevensverwijdering;
- ontbrekende juridische/privacygoedkeuring;
- exact welke externe handelingen na toestemming volgen.

Zonder expliciete toestemming worden geen stagingprojecten, publicaties,
domeinen, echte accounts, uitnodigingen of betaalde diensten aangemaakt.
