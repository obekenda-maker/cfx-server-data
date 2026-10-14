# Testen en verificatie

## 1. Geautomatiseerd (zonder FiveM)

```bash
pip install lupa pymysql
# MariaDB moet draaien op socket /run/mysqld/mysqld.sock (user root). Bijv. op Ubuntu: apt install mariadb-server
python3 tests/run_all.py
```
Dit draait: Lua-syntaxis (5.4) + JS-syntaxis, manifest-controle, tekstsleutel-controle, SQL-import (2×) en alle Lua-tests.
De Lua-tests laden onze **echte serverbestanden** met een mock van FiveM-natives, ESX, ox_lib en oxmysql;
queries lopen via een **echte MariaDB** (de mock faalt ook op `nil`-gaten in queryparameters, die in oxmysql stil
kunnen misgaan). Wat dat bewijst: de logica (rechten, afstanden, caps, cooldowns, validatie, SQL).
Wat het **niet** bewijst: dat jouw ESX/ox_lib-versie de gebruikte API exact zo aanbiedt, en alle clientcode.

## 2. API-verificatie voor jouw versies (doe dit éénmalig)

Ik kon ESX/ox_lib-broncode niet ophalen. Er zijn alleen API's gebruikt die in de officiële ESX-resources/ox_lib-docs
voorkomen, maar controleer ze tegen jouw geïnstalleerde versies (zoek in de resource-map, bv. `grep -rn "<naam>" resources/[core]`).
Een afwijking = één regel aanpassen.

| Gebruikt | Waar | Controle |
|---|---|---|
| `ESX.GetPlayerFromId`, `ESX.GetPlayers`, `ESX.GetJobs`, `ESX.RegisterUsableItem` | server | bestaat in `es_extended/server` |
| `xPlayer.getMoney/addMoney/removeMoney(n, reason)`, `getAccount(n).money`, `add/removeAccountMoney(n, amt, reason)` | server | idem |
| `xPlayer.getLoadout()`, `updateWeaponAmmo(name, ammo)`, `hasWeapon`, `addWeapon(name, ammo)` | combat_core/rp_shops/rp_gangs | loadout-velden `name, ammo, components, tintIndex` |
| `xPlayer.getInventory()`, `getInventoryItem(n).count/.label`, `add/removeInventoryItem`, `canCarryItem` | rp_* | default ESX-inventaris (niet ox_inventory) |
| `xPlayer.setJob(name, grade)`, `xPlayer.job.name/.grade/.grade_name`, `ESX.GetJobs()[n].grades[tostring(g)]` | rp_jobs | |
| `xPlayer.get('dateofbirth'/'sex'/'height')` | rp_interactions `/id` | valt terug op `?` als anders |
| Server-event `esx:playerLoaded(playerId, xPlayer)`, `esx:setJob(src, job, lastJob)` | combat_stats/gangs/combat_core | |
| Client: `ESX.IsPlayerLoaded()`, `ESX.GetPlayerData()`, `ESX.Game.SpawnVehicle/DeleteVehicle/GetVehicleProperties/SetVehicleProperties` | clients | |
| Client-event `esx:onPlayerSpawn` (wij triggeren die na respawn) | combat_core/rp_jobs | |
| `esx_status:getStatus`, `esx_status:set`, `esx_status:add`, `esx_status:onTick` | combat_core/server_hud/rp_shops | `grep -rn "esx_status:" resources/[esx]/esx_status` |
| `esx_basicneeds:onEat/onDrink` | rp_shops | |
| `esx_society:registerSociety`, `esx_society:openBossMenu` | rp_jobs | |
| `esx_addonaccount:getSharedAccount` | rp_jobs | callback geeft account met `addMoney` |
| `esx_license:checkLicense`, `esx_license:addLicense` | rp_shops | |
| ox_lib: `lib.callback.register/await` (beide richtingen), `lib.registerContext/showContext`, `lib.inputDialog`, `lib.alertDialog`, `lib.showTextUI/hideTextUI`, `lib.progressBar`, `lib.zones.sphere`, `lib.points.new`, `lib.getClosestPlayer`, `lib.setClipboard`, event `ox_lib:notify` | clients | |
| oxmysql: `MySQL.query/single/scalar/insert/update` (+`.await`) | servers | via `@oxmysql/lib/MySQL.lua` |
| FiveM: `weaponDamageEvent` (velden `hitGlobalId`, `hitGlobalIds`), `GetPlayerPed`/`GetEntityCoords` server-side, `Player(src).state:set` | combat_core | OneSync aan |

Specifieke aandachtspunten:
* **`weaponDamageEvent`** wordt in `damage.lua` gebruikt om schade tussen deelnemers/niet-deelnemers te annuleren. Test dit in-game
  (zie checklist). Zou het event bij jouw artifact andere velden hebben, dan doet de pcall niets (geen errors) en blijft de
  client-kant (onkwetsbaar/geen vuren) de bescherming. Zet `strictDamageCheck = false` (standaard) tot je dit hebt getest.
* **ESX-groep `mod`**: sommige ESX-versies accepteren alleen `user/admin/superadmin` bij `setgroup`. Gebruik dan `admin` voor staff
  en pas `ServerCfg.Admin.groups` aan.
* **`ALTER TABLE owned_vehicles … ADD COLUMN IF NOT EXISTS`** is MariaDB-syntaxis.

## 3. In-game checklist (minimaal 2 spelers/clients)

Markeer elk punt; een mislukt punt = noteer de F8-console/serverconsole-fout.

**Start**
- [ ] Serverconsole: geen rode fouten bij `ensure`; `[combat_core] 3 zone(s) geladen`, `[rp_gangs] … gang(s) geladen`.
- [ ] `/coords` (admin) kopieert een `vec4`.

**HUD**
- [ ] HUD zichtbaar; health/armor/geld/job kloppen; honger/dorst verschijnen (esx_status); standaard GTA-geld/straatnaam verborgen.
- [ ] In voertuig: snelheid/brandstof/versnelling; met een vuurwapen: munitie.
- [ ] `F7` ingedrukt houden toont leaderboard; `/top kd` en `/top xp`.

**Combat (2 spelers)**
- [ ] Zone-blip en grensmarkering zichtbaar; binnenkomst toont banner + prompt.
- [ ] Weigeren → onkwetsbaar, kunt niet schieten, na 15 s naar buiten gezet. Speler B (deelnemer) kan A **niet** raken (test ook met geweren).
- [ ] Deelnemen → loadout, spawnprotectie (4 s, vervalt bij schieten), teleport naar spawn.
- [ ] Kill: killfeed in het Nederlands, geld/XP-melding, stats +1; respawn na 5 s op ander punt; protectie.
- [ ] Zelfde slachtoffer direct opnieuw: melding "zonder beloning". Daglimiet bereikt: geen geld meer.
- [ ] Teamzone: teams verdeeld, teamgenoten kunnen elkaar niet raken, ronde-einde met bonus.
- [ ] Verlaten (`/pvpverlaat`): wapens weg, **RP-wapens + munitie terug**, honger/dorst/health terug op oude waarde.
- [ ] Sterf in zone, disconnect, reconnect: RP-loadout correct (geen combatwapens, geen verkeerde munitie).
- [ ] Politie op dienst kan niet meedoen; wisselen van job tijdens PvP zet je eruit.
- [ ] Eten/medkit gebruiken in zone → geblokkeerd.

**Roleplay**
- [ ] Dienst in/uit bij het bureau; bossmenu (`boss`-grade).
- [ ] Politie: boeien/ontboeien/fouilleren/begeleiden/boete (`/politie`); geboeide speler kan niet lopen/schieten.
- [ ] Dood buiten zone: tekst met timers; hulp melden; ambulance reanimeert; ziekenhuis-respawn met kosten.
- [ ] Monteur `/repareer` (kit nodig), taxi `/taxi`, trucker/courier-opdracht (afleveren + betaling; te snel = geweigerd).
- [ ] Voertuig kopen (PDM) → staat in Garage Legion → uitparkeren → opslaan; tweede keer uitparkeren zonder opslaan niet mogelijk.
- [ ] Winkel kopen; item gebruiken; Ammu-Nation: licentie → wapen.
- [ ] `/me`, `/do`, `/id`, `/geefgeld`, `/geefitem`.

**Gangs**
- [ ] `/gang` oprichten (kosten), uitnodigen, rang wijzigen, kas storten/opnemen.
- [ ] Territorium claimen; uitdagen door andere gang (2+ online per gang): na voorbereiding verschijnt een zone, alleen leden kunnen er in; kills tellen; resultaat verandert eigenaar.
- [ ] Zwarte markt (lid, met gebied voor wapens), activiteit, hehler.

**Admin**
- [ ] `/admin` menu; `/kick`, `/warn`, `/ban 1h reden`; geband account kan niet verbinden (ook via ander Discord-id); `/unban`.
- [ ] Discord: berichten in de juiste kanalen (money/combat/gang/admin/suspicious).

## 4. Prestaties
Server-ticks: `combat_core` 1×/s over *deelnemers*; HUD-client 200 ms met diff (alleen versturen bij verandering);
`server_logs` batcht. Controleer `resmon` (F8): richtwaarden idle < 0,05 ms per resource, HUD < 0,10 ms.
