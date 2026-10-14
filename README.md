# Nederland Combat RP – FiveM ESX Legacy server

Een complete Nederlandstalige FiveM-server die **roleplay** en **vrijwillige PvP combat zones** combineert.
Gebouwd op [`cfx-server-data`](docs/CFX_SERVER_DATA_ORIGINAL.md) + ESX Legacy + oxmysql + ox_lib.

> **Status in het kort:** alle scripts, SQL, configuratie en documentatie staan erin. De server-logica is getest
> (zie [Tests](#tests)) met gemockte FiveM/ESX/ox_lib-API's en een **echte MariaDB**. Er is **geen in-game test**
> gedaan (er draaide hier geen GTA/FXServer): doorloop daarom eerst [`docs/TESTEN.md`](docs/TESTEN.md).

## Wat zit erin

| Resource | Map | Doel |
|---|---|---|
| `server_config` | `[server]` | **Centrale** instellingen: branding, kleuren, HUD, admin-niveaus, **alle Nederlandse teksten**, helpers |
| `server_logs` | `[admin]` | Discord-webhooks (wachtrij, batching, 429-afhandeling) + database-audit |
| `admin_tools` | `[admin]` | `/kick /ban /unban /warn /warnings /checkplayer /admin /coords …`, ban-controle bij verbinden |
| `combat_core` | `[combat]` | PvP-zones (FFA + teams), opt-in, loadouts, spawn/respawn, beloningen met caps, anti-misbruik |
| `combat_stats` | `[combat]` | Kills/deaths/K-D/XP/level, dagcap, leaderboard |
| `rp_jobs` | `[roleplay]` | Politie, ambulance (dood/revive), monteur, taxi, vrachtwagenchauffeur, bezorger, dienst, bossmenu |
| `rp_garages` | `[roleplay]` | Voertuigen kopen, bezitten, opslaan, uitparkeren, depot (gebruikt ESX `owned_vehicles`) |
| `rp_shops` | `[roleplay]` | Winkels, eten/drinken/EHBO, Ammu-Nation met wapenlicentie |
| `rp_interactions` | `[roleplay]` | `/me /do /id /geefgeld /geefitem`, handen omhoog |
| `rp_gangs` | `[roleplay]` | Gangs, grades, kas, territoria, ganggevechten, zwarte markt, illegale activiteiten |
| `server_hud` | `[ui]` | NUI-HUD: status, geld, job, voertuig, munitie, combat, killfeed, leaderboard |

Externe afhankelijkheden (worden **niet** meegeleverd, `scripts/install-deps.sh` haalt ze op): `oxmysql`, `ox_lib`,
`es_extended` + `esx_menu_*`, `esx_skin`, `skinchanger`, `esx_identity`, `esx_addonaccount`, `esx_addoninventory`,
`esx_datastore`, `esx_society`, `esx_status`, `esx_basicneeds`, `esx_license`.

Het ontwerp, de afwegingen en de beperkingen staan in [`docs/BOUWPLAN.md`](docs/BOUWPLAN.md).

## Snel starten

```bash
git clone <deze-repo> server-data && cd server-data
./scripts/install-deps.sh                       # oxmysql, ox_lib, ESX (ESX_REF=<tag> om te pinnen)
cp server.cfg.example server.cfg
cp secrets.cfg.example secrets.cfg              # vul licentiesleutel, database en webhooks in
DB_USER=esx_nl DB_PASS=… DB_NAME=esx_nl ./scripts/import-sql.sh
bash /pad/naar/fxserver/run.sh +exec server.cfg
```

Volledige stappen voor **VPS** en **Pterodactyl**: [`docs/INSTALLATIE.md`](docs/INSTALLATIE.md).
Eerste admin maken: typ in de serverconsole `setgroup <speler-id> superadmin`.

## Hoe combat en roleplay samenwerken

* **Vrijwillig:** bij het betreden van een zone krijg je een prompt. Weiger je, dan ben je onkwetsbaar, kun je niet schieten en word je na `bystanderEjectSeconds` naar buiten gezet. Server annuleert bovendien alle schade tussen deelnemers en niet-deelnemers (`weaponDamageEvent`).
* **RP-bezit blijft veilig:** combatwapens zijn *alleen client-native* en komen nooit in de ESX-loadout/database. Bij verlaten (ook bij crash/disconnect) verdwijnen ze; de RP-loadout (incl. munitie) wordt door de server hersteld. Honger/dorst en health/armor worden bij betreden vastgelegd en bij verlaten teruggezet (geen "heal via PvP").
* **Geen geld printen:** beloning server-side, **dagcap per speler**, **uurbudget voor de hele server**, cooldown per killer→slachtoffer-paar, minimale levensduur slachtoffer, geen beloning bij teamkill/beschermd slachtoffer, entreegeld als geldput, gangoorlogen betalen niets uit.
* **Jobs:** politie/ambulance op dienst mogen niet meedoen (moeten eerst uit dienst – `offpolice`, …); jobwissel tijdens PvP = direct eruit.
* **Gangs:** een ganggevecht is een *tijdelijke combat zone* met toegang alleen voor de twee gangs (opt-in). Buiten die zone verandert er niets aan de PvP-regels.
* **Buiten zones** (`CombatCfg.Outside.mode`): `rp` = normaal GTA, doden worden als mogelijke RDM gelogd; `disabled` = geen speler-op-speler schade.

## Configuratie – waar pas ik wat aan?

| Wat | Bestand |
|---|---|
| Servernaam, branding, kleuren, HUD (positie/schaal/onderdelen) | `resources/[server]/server_config/config.lua` |
| **Alle Nederlandse teksten** | `resources/[server]/server_config/locale_nl.lua` |
| Admin-niveaus per ESX-groep, ban-/warn-regels | `server_config/config.lua` → `ServerCfg.Admin` |
| Discord-webhooks, databasewachtwoord, licentie | `secrets.cfg` (convars via `set`) |
| Combat: zones, coördinaten, straal, teams, loadouts, wapens, respawn, beschermtijd, beloningen, jobregels, PvP buiten zones | `resources/[combat]/combat_core/config.lua` |
| XP/level-formule, leaderboard | `resources/[combat]/combat_stats/config.lua` |
| Jobs & **salarissen** | `sql/02_jobs_items.sql` (ESX `job_grades`) |
| Dienstpunten, politie-/ambulance-/taxi-/bezorgregels, routes, beloningen | `resources/[roleplay]/rp_jobs/config.lua` |
| Garages, depot, voertuigcatalogus + prijzen | `resources/[roleplay]/rp_garages/config.lua` |
| Winkels, prijzen, wapenlicentie, bruikbare items | `resources/[roleplay]/rp_shops/config.lua` |
| Gangs, grades, territoria, oorlog, zwarte markt, activiteiten | `resources/[roleplay]/rp_gangs/config.lua` |
| Geef-limieten, /me-afstand | `resources/[roleplay]/rp_interactions/config.lua` |

Meer detail: [`docs/CONFIGURATIE.md`](docs/CONFIGURATIE.md).

## Tests

```bash
pip install lupa pymysql          # Lua 5.4 in Python + MariaDB-client
# start een lokale MariaDB (socket /run/mysqld/mysqld.sock, user root)
python3 tests/run_all.py          # syntax, manifesten, teksten, SQL en alle Lua-tests
```

| Controle | Wat |
|---|---|
| `tests/syntax_check.py` | Alle Lua-bestanden (Lua 5.4) + JS (`node --check`) |
| `tests/check_manifests.py` | Alle `fxmanifest.lua`: bestanden, `@resource/…`-verwijzingen, dependencies, startvolgorde in `server.cfg.example` |
| `tests/check_locale.py` | Elke gebruikte tekstsleutel bestaat in `locale_nl.lua` |
| `tests/test_sql.py` | `sql/01–03` importeren (2×, idempotent) in echte MariaDB |
| `tests/test_combat.lua` | Zones, join-regels, kills, beloningscaps, anti-farm, respawn-limiet, RP-loadout-herstel, tijdelijke zones |
| `tests/test_jobs.lua` | Dienst, politie, dood/revive/ziekenhuis, bezorging (anti-teleport), taxi, monteur |
| `tests/test_garages_shops.lua` | Voertuigen (atomisch uitparkeren, geen model-swap), winkels, wapenlicentie, geven, /me |
| `tests/test_gangs.lua` | Gang-regels, kas, territoria, **volledig ganggevecht via combat_core**, zwarte markt, hehler |
| `tests/test_admin.lua` | Rechten, bans (DB + login-controle), warnings, auto-ban |
| `tests/test_logs.lua` | Webhook-batching, 429, DB-audit |

**Niet** door deze tests gedekt: alle clientcode (NUI, zones, death-camera, spawn, menu's), echte ESX/ox_lib-versies en
netwerkgedrag. Dat is wat `docs/TESTEN.md` dekt.

## Licentie en bronnen

Eigen resources: vrij te gebruiken en aan te passen voor deze server. `cfx-server-data` (Cfx.re), ESX, oxmysql en ox_lib
vallen onder hun eigen licenties; ze worden niet meegeleverd.
