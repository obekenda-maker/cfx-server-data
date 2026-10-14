# Testresultaten

*Gegenereerd door `python3 tests/make_report.py` op 14-10-2026 12:05 – dit zijn de werkelijke uitkomsten van die run.*

Omgeving: Lua 5.4 (lupa), luacheck 1.1.2, MariaDB 10.11.14, Chromium (Playwright), Node 22. **Geen FXServer/GTA.**

## Uitgevoerde controles

| Controle | Resultaat | Details |
|---|---|---|
| Lua/JS-syntaxis | ✅ geslaagd | 67 bestanden gecontroleerd, 0 fout(en) |
| Statische analyse (luacheck) | ✅ geslaagd | luacheck: 0 waarschuwingen |
| Manifesten + startvolgorde | ✅ geslaagd | 12 resources gecontroleerd, 0 fout(en) |
| Kruisverwijzingen (exports/events/callbacks) | ✅ geslaagd | 65 bestanden, 0 fout(en) |
| Tekstsleutels (NL) | ✅ geslaagd | 501 sleutels gedefinieerd, 426 in gebruik, 0 ontbreken, 75 ongebruikt |
| Geheimen-scan | ✅ geslaagd | 263 bestanden gecontroleerd op geheimen, 0 fout(en) |
| Net events/callbacks: spam-bescherming | ✅ geslaagd | 4 net events en 53 server-callbacks geaudit, 0 fout(en) |
| Configbestanden (server.cfg, secrets, waarden) | ✅ geslaagd | config-lint: 34 ensure-regels, 0 fout(en) |
| Jobcatalogus (config ↔ SQL ↔ teksten) | ✅ geslaagd | jobcatalogus: 6 jobs, 16 grades, 0 fout(en) |
| Zone-lint (RP-bescherming) | ✅ geslaagd | 23 RP-punten, 19 SafeZones, 3 PvP-zones, 3 territoria: 0 fout(en) |
| Economie-beleid | ✅ geslaagd | economie: 0 beleidsfout(en); rapport docs/ECONOMIE.md |
| SQL-import (2×, MariaDB) | ✅ geslaagd | police grades na 2 imports: 5 (verwacht 5), jobs: 9, fouten: 0 |
| Scripts: shellcheck + backup/restore + import-sql | ✅ geslaagd | shellcheck schoon; test_backup: 26/26, test_import_script: 26/26 |
| SQL-statements uit de code (PREPARE) | ✅ geslaagd | 59 SQL-statements gevalideerd tegen MariaDB, 0 fout(en) |
| Lua-servertests | ✅ geslaagd | 585 checks (test_admin: 46/46, test_combat: 111/111, test_combat_extra: 87/87, test_gangs: 110/110, test_garages_shops: 81/81, test_jobcenter: 35/35, test_jobs: 69/69, test_logs: 8/8, test_welcome: 38/38) |
| Herstart-persistentie | ✅ geslaagd | 28 checks (restart phase_a: 6/6, restart phase_b: 22/22) |
| Admin-rechtenmatrix (19 acties × 5 rollen) | ✅ geslaagd | rechtenmatrix: 19 acties × 5 rollen, 0 fout(en); docs/ADMIN_RECHTEN.md geschreven |
| NUI HUD in Chromium | ✅ geslaagd | 25 checks |
| NUI welkom in Chromium | ✅ geslaagd | 22 checks |
| Welkomstdocumenten = bron | ✅ geslaagd | welkomstdocumenten komen overeen met de bron |

**Eindoordeel van deze run: ALLES GESLAAGD**


## Wat is echt UITGEVOERD (getest)

| Onderdeel | Hoe getest |
|---|---|
| **Serverlogica combat** (join-regels, zones, kills, beloningen/caps, anti-farm, respawn-limiet, beschermtijd, loadout-validatie, killfeed-dubbelingen, streaks, tijdelijke zones, schaderegels) | Echte serverbestanden in Lua 5.4 + mock van FiveM/ESX/ox_lib; queries tegen **echte MariaDB** |
| **Economie-grens** | 12 spelers die elkaar herhaald doden: totale uitkering ≤ uurbudget en dagcap |
| **Stats, K/D, XP, leaderboard** | Opslag in MariaDB, flush bij disconnect/stop, sortering (kills/kd/xp), SQL-injectie op sortering |
| **Dood/disconnect/jobwissel** | Inventaris, geld, bank, RP-loadout identiek vóór/na PvP-cyclus; geen verweesde toestand |
| **Roleplay-servers** | Dienst, politie, dood/revive/ziekenhuis, bezorging (anti-teleport/dagmax), taxi (alleen overdracht), monteur, garages (atomisch uitparkeren, geen model-swap), depot, winkels, wapenlicentie, geld/items geven, /me |
| **Gangs** | Aanmaken, rechten/grades, kas, territoria, **volledig ganggevecht** via combat_core, zwarte markt, activiteiten, hehler |
| **Admin** | Rechtenniveaus (ook voor menu-callbacks), bans in DB + login-controle (ook via ander identifier), verlopen/unban, warnings + auto-ban, console |
| **Persistentie na restart** | Twee opeenvolgende Lua-runtimes op dezelfde database: stats, dagcap, gang/kas/grades/territorium, voertuigen (garage + depot), bans, warnings, dagelijkse limieten |
| **SQL** | `sql/01–03` 2× achter elkaar in MariaDB (idempotent); alle queries via parameter-binding |
| **NUI** | Echte `index.html/style.css/app.js` in Chromium: berichten met ontbrekende/extreme waarden, killfeed-limiet, XSS via spelersnamen, geen console-fouten |
| **Jobsysteem** | Catalogus ↔ SQL ↔ database-diff, expliciet `jobsync` (alleen superadmin/console, raakt andere jobs niet), Jobcentrum (alleen publieke jobs, cooldown, daglimiet, geen ontsnapping uit politie/ambulance) |
| **Regels/welkom** | Akkoord per license, server-afgedwongen timeout-kick, decline, regelversie, `/akkoord`-noodoplossing, fail-open bij kapotte database; NUI in Chromium (knoppen, Escape, onboarding, waypoint, XSS) |
| **Bescherming RP-gebieden** | SafeZones (join geweigerd, deelnemer eruit bij betreden, tijdelijke/statische zone op RP-punt geweigerd) + zone-lint (geen overlap PvP/gangoorlog met RP-punten) |
| **Economie-beleid** | `check_economy.py`: combat-dagcap ≤ beste burgerbaan, zwarte markt ≥1,5× legaal, salarissen/uur, geldputten; rapport `docs/ECONOMIE.md` |
| **Adminrechten** | 19 acties × 5 rollen echt uitgevoerd en vergeleken met de config (`docs/ADMIN_RECHTEN.md`); audit van alle net events en 53 server-callbacks op spam-bescherming |
| **Back-up/herstel** | `backup.sh`/`restore.sh`: dump, checksum, rechten, versleuteld config-archief, retentie, lock, byte-gelijk herstel, weigeren van beschadigde back-ups, wachtwoord niet zichtbaar; `import-sql.sh` (idempotent, exit-codes); shellcheck |
| **SQL-statements** | alle 50 statements uit de Lua-code gevalideerd tegen het echte schema (PREPARE) |
| **Kwaliteit** | luacheck (geen waarschuwingen), manifesten, kruisverwijzingen, tekstsleutels, geheimen-scan |

## Alleen via CODE gecontroleerd (NIET uitgevoerd)

| Onderdeel | Waarom niet getest |
|---|---|
| Alle **clientcode** (zones/blips/markers, bystander-gedrag, death-camera, respawn, spawn-teleport, loadouts geven, menu's, progressbars, taxi-meter, politie-animaties) | vereist een draaiende GTA-client |
| **Echte ESX/ox_lib/oxmysql-versies** (API-vormen) | bronnen niet op te halen; zie API-lijst in `docs/TESTEN.md` |
| **`weaponDamageEvent`** in een echte server | server-side schadebescherming; gedrag in-game te bevestigen |
| **ESX-eigen persistentie** (users: geld, job, positie, inventaris, loadout; personages/esx_identity) | beheerd door ESX, niet door onze code |
| **Multiplayer-/integratietests met echte spelers** | `docs/MULTIPLAYER_CHECKLIST.md` – **nog niet uitgevoerd**; zonder deze tests is de server niet vrijgegeven |
| Hostingstappen (VPS/Pterodactyl/Windows) op een echte omgeving | scripts getest, de hoster-specifieke stappen niet |
| Back-up-cron op jouw server en herstel op andere DB-versie | niet getest |
| Prestaties onder belasting (`resmon`) | geen echte server; alleen codeanalyse (lussen, queries, diff-updates) |
| Netwerkgedrag, latency, meerdere gelijktijdige clients | niet te simuleren |
