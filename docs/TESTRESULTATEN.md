# Testresultaten

*Gegenereerd door `python3 tests/make_report.py` op 14-10-2026 11:14 – dit zijn de werkelijke uitkomsten van die run.*

Omgeving: Lua 5.4 (lupa), luacheck 1.1.2, MariaDB 10.11.14, Chromium (Playwright), Node 22. **Geen FXServer/GTA.**

## Uitgevoerde controles

| Controle | Resultaat | Details |
|---|---|---|
| Lua/JS-syntaxis | ✅ geslaagd | 59 bestanden gecontroleerd, 0 fout(en) |
| Statische analyse (luacheck) | ✅ geslaagd | luacheck: 0 waarschuwingen |
| Manifesten + startvolgorde | ✅ geslaagd | 11 resources gecontroleerd, 0 fout(en) |
| Kruisverwijzingen (exports/events/callbacks) | ✅ geslaagd | 58 bestanden, 0 fout(en) |
| Tekstsleutels (NL) | ✅ geslaagd | 414 sleutels gedefinieerd, 379 in gebruik, 0 ontbreken, 35 ongebruikt |
| Geheimen-scan | ✅ geslaagd | 220 bestanden gecontroleerd op geheimen, 0 fout(en) |
| SQL-import (2×, MariaDB) | ✅ geslaagd | police grades na 2 imports: 5 (verwacht 5), jobs: 9, fouten: 0 |
| Lua-servertests | ✅ geslaagd | 504 checks (test_admin: 46/46, test_combat: 111/111, test_combat_extra: 79/79, test_gangs: 110/110, test_garages_shops: 81/81, test_jobs: 69/69, test_logs: 8/8) |
| Herstart-persistentie | ✅ geslaagd | 28 checks (restart phase_a: 6/6, restart phase_b: 22/22) |
| NUI in Chromium | ✅ geslaagd | 25 checks |

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
| **Kwaliteit** | luacheck (geen waarschuwingen), manifesten, kruisverwijzingen, tekstsleutels, geheimen-scan |

## Alleen via CODE gecontroleerd (NIET uitgevoerd)

| Onderdeel | Waarom niet getest |
|---|---|
| Alle **clientcode** (zones/blips/markers, bystander-gedrag, death-camera, respawn, spawn-teleport, loadouts geven, menu's, progressbars, taxi-meter, politie-animaties) | vereist een draaiende GTA-client |
| **Echte ESX/ox_lib/oxmysql-versies** (API-vormen) | bronnen niet op te halen; zie API-lijst in `docs/TESTEN.md` |
| **`weaponDamageEvent`** in een echte server | server-side schadebescherming; gedrag in-game te bevestigen |
| **ESX-eigen persistentie** (users: geld, job, positie, inventaris, loadout; personages/esx_identity) | beheerd door ESX, niet door onze code |
| Prestaties onder belasting (`resmon`) | geen echte server; alleen codeanalyse (lussen, queries, diff-updates) |
| Netwerkgedrag, latency, meerdere gelijktijdige clients | niet te simuleren |
