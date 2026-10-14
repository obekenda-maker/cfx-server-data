# Release-checklist – wat is klaar, wat is getest, wat moet jij doen

> ## ⛔ Status: NIET vrijgegeven voor spelers
> Alles is **gebouwd** en **automatisch getest**, maar er is **nog geen enkele test met echte spelers op een echte FiveM-server** gedaan
> (de bouwomgeving had geen GTA/FXServer). De clientcode (zones, HUD-in-het-spel, doodscherm, menu's, spawn/teleport) heeft nog **nooit gedraaid**,
> en de echte ESX/ox_lib/oxmysql-versies zijn nog niet gecontroleerd. De server mag pas open voor een **besloten test** na
> §A (installatie) en pas "vrijgegeven" na `docs/MULTIPLAYER_CHECKLIST.md` (GO/NO-GO).

Legenda: ✅ gedaan/aangetoond • 🟡 gedeeltelijk • ⬜ nog niet • 👤 jij moet dit doen

## 1. Overzicht per gebied

| Gebied | Gebouwd | Automatisch getest (bewijs) | Met echte spelers getest | Jij moet |
|---|---|---|---|---|
| Installatie & hosting (VPS/Pterodactyl/Windows) | ✅ handleiding + scripts | 🟡 scripts echt getest (import, back-up, herstel); hosterstappen **niet** | ⬜ | 👤 installeren, `docs/INSTALLATIE.md` |
| Configuratie (`server.cfg`, secrets, waarden) | ✅ | ✅ `check_config.py` (+ mutatietest) | ⬜ | 👤 geheimen invullen |
| SQL-imports | ✅ `sql/01–03`, `import-sql.sh` | ✅ 2× in MariaDB 10.11, 59 queries uit de code gevalideerd (PREPARE), import-script (26 checks) | ⬜ | 👤 importeren op jouw database |
| Roleplay: banen, geld, voertuigen, winkels, interacties | ✅ | ✅ servertests (jobs 69, garages/shops 81, jobcentrum 35) | ⬜ | 👤 multiplayer-sessie 2–3 |
| Jobsysteem (politie, ambulance, monteur, burger) | ✅ catalogus, Jobcentrum, `/baan`, `jobsync` | ✅ catalogus-lint + 35 Jobcentrum-checks | ⬜ | 👤 `docs/JOBS.md`; PaycheckInterval instellen |
| Combat: zones, PvP, respawn, loadouts, stats | ✅ | ✅ 198 servertests (combat + extra) | ⬜ **clientcode ongetest** | 👤 sessie 4 |
| Combat ↔ roleplay (economie, wapens, bescherming) | ✅ caps, snapshots, SafeZones | ✅ economie-grens, RP-loadout-herstel, SafeZones, zone-lint, economie-beleid | ⬜ | 👤 sessie 4–5 |
| Gangs, gangoorlog, zwarte markt | ✅ | ✅ 110 servertests incl. volledig gevecht | ⬜ | 👤 sessie 5 |
| Welkom, regels, onboarding | ✅ loadscreen, akkoord (server-afgedwongen), onboarding, `/help` | ✅ 38 servertests + 22 NUI-checks (Chromium) | ⬜ **samenspel met `esx_identity` ongetest** | 👤 regels goedkeuren; sessie 1 |
| HUD | ✅ | ✅ 25 NUI-checks (Chromium) | ⬜ | 👤 sessie 1/4/8 |
| Admin: rechten & beveiliging | ✅ | ✅ matrix 19 acties × 5 rollen; audit 4 net events + 53 callbacks | ⬜ | 👤 sessie 6; ESX-eigen admincommando's nalopen |
| Logging & geheimen | ✅ | ✅ geheimen-scan, webhook-batching/429 (8 checks) | ⬜ | 👤 webhooks aanmaken |
| Back-up & herstel | ✅ scripts + `docs/BACKUP_HERSTEL.md` | ✅ 26 checks tegen echte MariaDB | ⬜ | 👤 cron + off-site + herstel-oefening |
| Persistentie na herstart | ✅ | ✅ herstart-simulatie (28 checks) voor **onze** tabellen | ⬜ | 👤 sessie 7 (incl. ESX-eigen data) |
| Prestaties | 🟡 codeanalyse, caches, diff-updates | ⬜ geen echte meting | ⬜ | 👤 `resmon` (sessie 8) |
| Ontbrekende assets/scripts | ✅ lijst: `docs/ONTBREKENDE_ASSETS.md` | n.v.t. | n.v.t. | 👤 anticheat, voice, brandstof, MLO's, icoon |

**Totaal automatisch:** 585 Lua-servertests • 28 herstart-checks • 47 NUI-checks • 52 script-checks • adminmatrix • lint/manifest/kruisverwijzing/locale/geheimen/config/zone/economie/jobs/SQL-lints — laatste run: **alles geslaagd** (`docs/TESTRESULTATEN.md`).

## 2. Stappenplan: van nu naar een besloten test

### A. Installeren (👤 jij)
- [ ] Hosting kiezen en `docs/INSTALLATIE.md` volgen (A, B of C); versies vastleggen met `scripts/print-versions.sh`; ESX pinnen (`ESX_REF`).
- [ ] `secrets.cfg` ingevuld (licentie, database, 6 webhooks), rechten 600, niet in git.
- [ ] `scripts/import-sql.sh` zonder fouten gedraaid; serverconsole bij start zonder rode regels (`INSTALLATIE.md` §F).
- [ ] ESX: `PaycheckInterval = 30 min`, taal, startgeld; `esx_society` `EnableSocietyPayouts`.
- [ ] Eerste beheerder: `setgroup <id> superadmin`. Wie krijgt `mod`/`admin`? (beleid vastleggen; ESX-eigen commando's nalopen, zie `ADMIN_RECHTEN.md`.)
- [ ] **Coördinaten gecontroleerd met `/coords`**: PvP-zones, SafeZones, garages, winkels, depots, Jobcentrum, dienstpunten, territoria (met name `grove`/`davis`/`mirror`, in fase 3 verplaatst).
- [ ] Anticheat/voicechat/brandstof beslist (`ONTBREKENDE_ASSETS.md`).

### B. Inhoud goedkeuren (👤 jij)
- [ ] Serverregels (`rules_nl.lua` / `docs/SERVERREGELS.md`) gelezen en goedgekeurd; sancties kloppen met jouw beleid.
- [ ] Loadscreen- en welkomsttekst/branding (`loading.html`, `server_config/config.lua`, Discord-link) ingevuld.
- [ ] Salarissen, prijzen, beloningen akkoord (`docs/ECONOMIE.md`, `JobsCfg.Catalog`, `CombatCfg.Rewards`).
- [ ] Privacy: logs bevatten licenses/Discord-id's; toegang tot Discord-logkanalen beperkt en vermeld in je regels.

### C. Veiligheidsnet (👤 jij)
- [ ] Back-up-cron + **off-site kopie** actief; **herstel-oefening** op een testdatabase gedaan (`BACKUP_HERSTEL.md` §5).
- [ ] Je weet hoe je de server stopt en een back-up terugzet (stappen uitgeprint/bij de hand).

### D. Besloten test (👤 jij + testers)
- [ ] `docs/TESTERS_BRIEFING.md` aan testers gegeven; 5–6 testers + 1 beheerder (rollen in `MULTIPLAYER_CHECKLIST.md` §0).
- [ ] Sessies 1–8 uitgevoerd; ❌/⚠ genoteerd met bewijs (bugrapport-sjabloon).
- [ ] Bugs opgelost (stuur ze mij met het bugrapport: logregels + stappen), tests opnieuw doorlopen.

### E. GO/NO-GO vóór openstellen
**GO** alleen als: alle ⭐-tests ✅ • geen ❌ bij verlies van spullen/geld, misbruik of dataverlies (4.10–4.14, 6.5, 7.1) • geen herhaalde errors in serverconsole/F8 •
herstart-persistentie (7.1) en back-up+herstel (7.3) bewezen • `resmon` binnen richtwaarden (8.1) • back-up off-site actief.

## 3. Wat er in fase 3 is gewijzigd (voor jouw overzicht)

| Wijziging | Reden | Risico/let op |
|---|---|---|
| Nieuwe resource `server_welcome` + tabel `server_rules_accepted` (additief) | loadscreen, regels, onboarding, `/help` | akkoord-timeout kickt spelers die niet akkoord geven; bij kapotte database **fail open** (geen kick); noodcommando `/akkoord`; uit te zetten met `requireAcceptance = false` |
| `JobsCfg.Catalog` als enige jobbron; `sql/02_jobs_items.sql` gegenereerd (inhoud identiek aan eerder) | configureerbaar jobsysteem | Database wordt **nooit** automatisch aangepast; alleen via `jobsync` (superadmin/console) + herstart; start-waarschuwing bij afwijking |
| Jobcentrum + `/baan` + monteur als open job | burgers/instructies | cooldown en daglimiet tegen job-hoppen; politie/ambulance niet via Jobcentrum |
| `CombatCfg.SafeZones` + serverafdwinging; territoria `davis` en `mirror` verplaatst; `grove` ongewijzigd | bescherming RP-gebieden; `mirror` lag precies op een winkel | **nieuwe coördinaten moeten in-game gecontroleerd worden** |
| Throttle op 11 extra callbacks (jobs/gangs) | uniforme spam-bescherming (audit) | geen gedragswijziging bij normaal gebruik |
| `import-sql.sh` strenger (exit-codes) | het gaf eerst "klaar" bij een fout wachtwoord | scripts stoppen nu bij foute verbinding (exit 5) |
| `backups/` in `.gitignore`; `scripts/backup.sh`/`restore.sh` | back-up/herstel | herstel overschrijft data: alleen met gestopte server; veiligheidskopie wordt vooraf gemaakt |
| Fase 2: gedeelde server-helpers, client-hardening | stabiliteit | zie `docs/TESTRESULTATEN.md` |

## 4. Wat ik **niet** kan beloven
* Dat de server "volledig werkt": dat is pas aangetoond na de multiplayer-test.
* Dat de gekozen ESX/ox_lib/oxmysql-versies exact de gebruikte API's bieden (zie `docs/TESTEN.md` §2).
* Dat de vanilla-coördinaten overal begaanbaar zijn of niet door jouw MLO's/maps worden geraakt.
* Dat er geen cheating mogelijk is: er is geen anticheat; de server valideert acties, maar detecteert geen cheat-software.
