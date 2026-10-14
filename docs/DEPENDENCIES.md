# Dependencies en versies

> **Eerlijk vooraf:** ESX, ox_lib en oxmysql konden in de bouwomgeving niet worden gedownload. De kolom "getest" geeft aan
> wat *echt* is uitgevoerd. De "minimaal"-versies zijn de versies waarvan ik weet dat de gebruikte functies bestaan; **leg na
> installatie je werkelijke versies vast met `./scripts/print-versions.sh`** en pin ESX (`ESX_REF=<tag>`).

## Runtime

| Component | Rol | Minimaal / aanbevolen | Getest in bouwomgeving |
|---|---|---|---|
| FXServer (artifact) | game-server | recente *recommended* build, `lua54`, **OneSync aan** (`set onesync on`) | ❌ niet beschikbaar |
| MariaDB | database | ≥ 10.3 (aanbevolen 10.6+; `ADD COLUMN/INDEX IF NOT EXISTS`) | ✅ **10.11.14** (schema + alle queries) |
| MySQL | alternatief | 8.x; twee `ALTER`-regels onderaan `sql/01_core.sql` geven een meldbare "bestaat al"-fout | ❌ |
| oxmysql | `MySQL.*` + `@oxmysql/lib/MySQL.lua` | 2.x of nieuwer | ❌ (gemockt; echte SQL wel via MariaDB) |
| ox_lib | callbacks (beide richtingen), context-menu's, input/alert-dialogen, TextUI, progressbar, `lib.zones`, `lib.points`, `lib.getClosestPlayer`, notify | 3.x of nieuwer | ❌ (gemockt) |
| es_extended (ESX Legacy) | framework: spelers, geld, jobs, loadout, inventaris, items | Legacy ≥ 1.9 (default inventaris) | ❌ (gemockt) |

## ESX-resources (zie `server.cfg.example`, in deze volgorde)

`esx_menu_default`, `esx_menu_dialog`, `esx_menu_list`, `skinchanger`, `esx_skin`, `esx_identity`, `esx_addonaccount`,
`esx_addoninventory`, `esx_datastore`, `esx_society`, `esx_status`, `esx_basicneeds`, `esx_license`.
Gebruik de versies die bij jouw gekozen `es_extended`-tag horen (zelfde release/tag van `esx_core`).

Waarvoor eigen resources ze gebruiken: `esx_status` (honger/dorst: events `getStatus/set/add/onTick`), `esx_basicneeds`
(eet/drink-animaties), `esx_society`+`esx_addonaccount` (bedrijfskas, bossmenu), `esx_license` (wapenlicentie),
`esx_identity` (personage-aanmaak; `/id` leest naam/geboortedatum).

**Niet installeren** (conflicteert met eigen resources): `esx_ambulancejob`, `esx_policejob`, `esx_mechanicjob`,
`esx_vehicleshop`, `esx_advancedgarage`, `esx_shops`, `esx_weaponshop`, `ox_inventory` (niet ondersteund), losse HUD-resources.

## Cfx-basisresources (in deze repo)
`mapmanager`, `chat`, `chat-theme-gtao`, `spawnmanager`, `sessionmanager`, `rconlog` (zie `server.cfg.example`).
Niet gestart: `[gameplay]/[examples]`, `runcode` (dev-tool, remote code-uitvoering), `hardcap` (verouderd; `sv_maxclients` volstaat).

## Eigen resources en hun onderlinge afhankelijkheden

| Resource | Harde dependencies (`fxmanifest`) | Zacht (via `pcall`, resource mag ontbreken) |
|---|---|---|
| `server_config` | – | – |
| `server_logs` | oxmysql, server_config | – |
| `combat_stats` | oxmysql, ox_lib, es_extended, server_config | – |
| `combat_core` | oxmysql, ox_lib, es_extended, server_config, server_logs, combat_stats | rp_gangs (toegangsbeperkte zones) |
| `rp_jobs` | oxmysql, ox_lib, es_extended, esx_society, server_config, server_logs | combat_core |
| `rp_garages` | oxmysql, ox_lib, es_extended, server_config, server_logs | – |
| `rp_shops` | ox_lib, es_extended, esx_status, esx_basicneeds, esx_license, server_config, server_logs | combat_core |
| `rp_interactions` | ox_lib, es_extended, server_config, server_logs | combat_core |
| `rp_gangs` | oxmysql, ox_lib, es_extended, server_config, server_logs, combat_core, rp_jobs | – |
| `admin_tools` | oxmysql, ox_lib, es_extended, server_config, server_logs | rp_gangs, combat_stats, combat_core |
| `server_hud` | ox_lib, es_extended, server_config | esx_status (honger/dorst), combat_* (via events) |
| `server_welcome` | oxmysql, ox_lib, es_extended, server_config, server_logs | – (loadscreen + NUI; `esx_identity`-scherm wordt afgewacht) |

`python3 tests/check_manifests.py` controleert bestanden, `@resource/…`-verwijzingen, dependencies **en** dat elke dependency
vóór zijn gebruiker in `server.cfg.example` staat.

## Ontwikkel-/testgereedschap (alleen om de tests te draaien, niet op de gameserver)

Python 3.10+ met `lupa` (Lua 5.4) en `pymysql`; MariaDB; `luacheck` (`apt install lua-check`); Node 22 + Playwright + Chromium
(alleen voor `tests/test_nui.py`; wordt overgeslagen als het ontbreekt).
