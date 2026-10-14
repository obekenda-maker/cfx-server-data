# Configuratie – overzicht

Alle waarden staan in Lua-tabellen met commentaar. Teksten staan **nooit** in de scripts, maar in
`resources/[server]/server_config/locale_nl.lua` (sleutel → tekst). Pas de tekst aan, laat de sleutel staan.
Na een wijziging: `restart <resource>` (voor `server_config`/locale: herstart de resources die het gebruiken, of de hele server).

## Geheimen
Nooit in Lua of in git. `secrets.cfg` (alleen op de server, staat in `.gitignore`):
`sv_licenseKey`, `mysql_connection_string`, `dc_webhook_*`. Gebruik `set`, **niet** `setr` (`setr` repliceert naar clients).

## server_config/config.lua
| Sleutel | Betekenis |
|---|---|
| `ServerCfg.Server` | naam/korte naam/Discord-link (branding) |
| `ServerCfg.Colors` | hex-kleuren; gebruikt door HUD en Discord-embeds |
| `ServerCfg.Hud` | positie (`bottom-right` standaard, minimap staat linksonder), schaal, onderdelen aan/uit, snelheidseenheid, leaderboard-toets, killfeed-lengte |
| `ServerCfg.NotifyCfg` | positie/duur ox_lib-meldingen |
| `ServerCfg.Admin` | `groups` (ESX-groep → niveau), `levels` (actie → minimaal niveau), warn-/ban-regels |
| `ServerCfg.Webhooks` | *naam* van de convar per logkanaal |
| `ServerCfg.Logs` | batching, kleuren, welke kanalen óók in de DB komen, bewaartermijn |

## combat_core/config.lua
| Sectie | Doel |
|---|---|
| `Rules` | respawntimer, beschermtijd (+ vervalt bij schieten), combat-tag, zonemarge, bystander-gedrag, voertuigen/items blokkeren, killvalidatie (`maxKillDistance`, `strictDamageCheck`), snapshots (needs/loadout) |
| `Outside` | PvP buiten zones: `rp` of `disabled` |
| `DefaultTeams` | teamnamen/kleuren |
| `Loadouts` | wapens/munitie/armor/health per loadout (client-native, nooit in de DB) |
| `Zones` | id, label, `coords`, `radius`, `mode` (`ffa`/`team`), `maxPlayers`, `minLevel`, `entryFee`, `rewardMultiplier`, `loadouts`, optioneel eigen `spawns`/`exit` |
| `Rewards` | geld/XP per kill, streakbonus, `dailyMoneyCap`, `globalHourlyBudget`, `pairCooldownSeconds`, `minAliveSeconds`, teambonus, logging |
| `JobRules` | per ESX-job: `canJoin`, `rewardMultiplier` |
| `WeaponLabels` | Nederlandse wapennamen voor de killfeed |

**Zonecoördinaten** zijn best-effort. Loop de zone in-game na (`/coords` → `vec4`), let op hoogte, water en gebouwen.
Zonder eigen `spawns` worden punten op een ring (65% van de straal) gegenereerd; de client bepaalt de grondhoogte.

## rp_jobs, rp_garages, rp_shops, rp_interactions, rp_gangs
Elk heeft één `config.lua`. Belangrijk:
* Salarissen: **`sql/02_jobs_items.sql`** (kolom `salary`), daarna SQL opnieuw importeren en ESX herstarten.
* Bezorgroutes/-beloning/-daglimiet: `JobsCfg.Delivery`.
* Voertuigprijzen en catalogus: `GarageCfg.Shop.categories`.
* Winkelprijzen: `ShopCfg.Catalogs`; wapens/licentie: `ShopCfg.WeaponShop`.
* Gangkosten/grades/rechten, territoria, oorlogsregels, zwarte markt, hehler: `rp_gangs/config.lua`.

## Nieuwe combat zone toevoegen
1. Kopieer een blok in `CombatCfg.Zones`, geef een uniek `id`, nieuwe `coords` en `radius`.
2. `restart combat_core`. Clients laden de zones opnieuw bij (her)start van de resource of bij verbinden.
3. Controleer in-game: blip, grensmarkering, prompt bij binnenkomst, spawnpunten (`/pvp`).

## Nieuwe job
1. Voeg regels toe aan `sql/02_jobs_items.sql` (job + grades + eventueel `off<job>` voor af-dienst) en importeer opnieuw.
2. Wil je dienstpunten: `JobsCfg.Duty`. Wil je PvP-regels voor de job: `CombatCfg.JobRules`.
