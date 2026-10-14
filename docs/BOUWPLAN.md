# Bouwplan – Nederlandse Combat + Roleplay server (ESX Legacy)

## 1. Technische inventarisatie

| Onderdeel | Keuze | Opmerking |
|---|---|---|
| Server | FXServer (recommended artifact) | OneSync **verplicht** (server-side coördinaten, state bags, `GetVehiclePedIsIn` op de server) |
| Framework | ESX Legacy (`esx-framework/esx_core`) | `es_extended` + `esx_identity`, `esx_skin`, `skinchanger`, `esx_status`, `esx_basicneeds`, `esx_society`, `esx_addonaccount`, `esx_addoninventory`, `esx_datastore`, `esx_license`, `esx_menu_default/dialog/list`, `esx_progressbar` |
| Database | oxmysql (`overextended/oxmysql`) | `set mysql_connection_string` via secrets.cfg / startup-argument |
| UI-lib | ox_lib (`overextended/ox_lib`) | `lib.callback`, `lib.registerContext`, `lib.inputDialog`, `lib.alertDialog`, `lib.zones`, `lib.points`, `lib.notify` |
| Inventory | **ESX standaard-inventory** (items-tabel + loadout) | `ox_inventory` wordt in v1 niet ondersteund (zie "Beperkingen") |
| Basis | `citizenfx/cfx-server-data` (deze repo) | `mapmanager`, `spawnmanager`, `chat`, `sessionmanager`, `baseevents`, `hardcap`; de voorbeeld-resources (`[examples]`) worden **niet** gestart |

ESX, ox_lib en oxmysql worden **niet** in deze repo meegeleverd (upstream, regelmatig updates). `scripts/install-deps.sh` haalt ze op.

## 2. Architectuur (één geheel, geen losse scripts)

```
                        ┌────────────────────┐
                        │   server_config    │  centrale config, NL-teksten, kleuren, helpers
                        └─────────┬──────────┘
        ┌────────────┬────────────┼─────────────┬─────────────┐
 ┌──────┴──────┐ ┌───┴────┐ ┌─────┴──────┐ ┌────┴─────┐ ┌─────┴──────┐
 │ server_logs │ │ admin  │ │combat_stats│ │ rp_*     │ │ server_hud │
 │ (Discord+DB)│ │ _tools │ │ (DB/XP/top)│ │ (RP)     │ │ (NUI)      │
 └──────▲──────┘ └───▲────┘ └─────▲──────┘ └────┬─────┘ └─────▲──────┘
        │            │            │             │             │
        └────────────┴──────┬─────┴─────────────┘             │
                      ┌─────┴──────┐   events/state bags      │
                      │combat_core │──────────────────────────┘
                      │ zones·spawn│  (killfeed, score, zone-status)
                      │ loadouts·  │◄── rp_gangs: tijdelijke ganggevecht-zones
                      │ rewards    │◄── rp_jobs: jobregels (politie niet in PvP)
                      └────────────┘
```

**Samenvoegen van combat-resources.** De gevraagde `combat_zones`, `combat_spawn` en `combat_loadouts` delen één server-autoritatieve toestand (wie zit in welke zone, team, beschermtijd, respawn). Gescheiden resources zouden die toestand moeten synchroniseren via exports/events en geven race-condities (kill vs. leave vs. respawn). Daarom zitten ze samen in `combat_core` (aparte bestanden). `combat_stats` blijft apart (database, XP, leaderboard, dagcap) zodat HUD, gangs en admin het kunnen gebruiken. De killfeed zit in `server_hud` (NUI), `combat_core` stuurt het event.

## 3. Hoe combat en roleplay elkaar niet kapotmaken

| Risico | Maatregel |
|---|---|
| Combatwapens in RP-wereld | Combatwapens worden **alleen client-native** gegeven (niet in de ESX-loadout/DB). Bij verlaten, dood buiten, disconnect of crash zijn ze weg. RP-loadout wordt bij betreden veiliggesteld (niet gewijzigd) en bij verlaten hersteld. |
| Inventaris verliezen/farmen | Geen loot bij dood in zones; gebruik van items (eten/medkit) in zones geblokkeerd (config). |
| Honger/dorst resetten via dood | Snapshot van `esx_status` bij betreden, herstel bij verlaten. |
| Geld printen | Beloning: server-side, dagcap per speler, globaal uurbudget, cooldown per slachtoffer, minimale levenstijd van slachtoffer, geen beloning bij beschermd/zelfde team/zelfde persoon-paar-farming; boven drempel → Discord-log `suspicious`. |
| Respawn-misbruik | Respawn-timer server-side afgedwongen, max. respawns per minuut, beschermtijd vervalt bij schieten, server negeert kills op beschermde spelers. |
| Politie/ambulance in PvP | `Config.JobRules`: op-dienst-jobs mogen niet meedoen (moeten eerst uit dienst), wissel van job tijdens PvP = automatisch verlaten. |
| Niet-deelnemers in zone | Prompt bij binnenkomst; weigeren → onkwetsbaar + niet kunnen schieten + automatische uitzetting na x seconden. Server annuleert schade van deelnemers aan niet-deelnemers (`weaponDamageEvent`). |
| Client-manipulatie | Alle geld/wapen/kill/admin-acties lopen via server-callbacks met validatie (positie, afstand, job, rate-limits). Clientdata is alleen een *claim*. |

## 4. Bouwvolgorde en status

1. [x] Repo-inventarisatie, bouwplan
2. [x] `server_config`, `server_logs`, SQL
3. [x] `combat_stats`, `combat_core` (zones, PvP-regels, spawn, loadouts, beloningen)
4. [x] `server_hud` (HUD, killfeed, leaderboard)
5. [x] `rp_jobs`, `rp_garages`, `rp_shops`, `rp_interactions`
6. [x] `rp_gangs`
7. [x] `admin_tools`
8. [x] Tests (lupa), install-scripts, `server.cfg.example`, README, installatiehandleiding

## 4b. Testresultaat

`python3 tests/run_all.py`: syntax (59 bestanden), manifesten (11 resources), teksten (414 sleutels), SQL (2× import in MariaDB 10.11)
en 425 Lua-checks over 6 testbestanden – allemaal geslaagd. Zie README → Tests voor wat wel/niet gedekt is.

## 5. Beperkingen (eerlijk)

* Er kon in deze omgeving **geen FXServer/GTA** draaien: alle scripts zijn syntactisch gecontroleerd en de server-logica is getest met gemockte ESX/ox_lib/oxmysql (`tests/`). **In-game testen moet jij nog doen** – zie `docs/TESTEN.md` (checklist).
* ESX/ox_lib-broncode kon niet worden opgehaald (netwerk). Er zijn alleen API's gebruikt die in ESX Legacy / ox_lib / oxmysql gedocumenteerd of in de officiële ESX-resources gebruikt worden; `docs/TESTEN.md` bevat een verificatielijst voor jouw exacte versie.
* Zonecoördinaten, garages, shops en bezorgpunten zijn best-effort bekende GTA-locaties. Controleer ze in-game (`/coords` voor admins).
* `ox_inventory` en `esx_multicharacter` zijn niet getest (identifier-prefix `charN:` werkt wel).
* Lopende ganggevechten gaan verloren bij een server-/resource-herstart (de kosten ook); territoriumeigendom blijft bewaard.
* Honger/dorst worden na een gewone ziekenhuis-respawn door `esx_basicneeds` gereset (ESX-standaard); in PvP-zones is dat afgevangen.
