# Referentie: bevindingen uit de lokale "reallife"-map

Bron: verslag van een sessie op de pc van de eigenaar, over de map `reallife`
(uitgepakt). Er is niets gekopieerd; dit zijn alleen waarnemingen. Archieven (rars,
50+ GB) zijn niet uitgepakt en `server.cfg` is niet gedeeld.

## Wat is vastgesteld (door de pc-sessie, niet door mij gecontroleerd)

- `es_extended` versie **1.13.5**. Aanvullend: `esx_status`, `esx_basicneeds`,
  `illenium-appearance`, `dpclothing`.
- Die server gebruikt `ox_inventory`, `ox_target`, `ox_doorlock`, `ox_fuel`, `pma-voice`.
  Mijn server_config/rp_* gaan uit van de **standaard ESX-inventaris** (ox_inventory
  wordt niet ondersteund). Beide naast elkaar gebruiken vraagt een bewuste keuze.
- De jobscripts (politie, ziekenhuis, monteur, garages) zitten **niet** in de map.
- `zerorealliferp.sql` bevat alleen tabelstructuur, geen data.
- Beveiligingsscan op `.lua`: geen obfuscatie, geen `loadstring`/`os.execute`. Niet
  beoordeeld: minified `.js`-bundels en `dist`-mappen.

## Functies die die server heeft en deze build (nog) niet

Afgeleid uit tabelnamen, dus een wensenlijst en geen specificatie:

| Gebied | Voorbeelden uit tabelnamen |
|---|---|
| Woningen/appartementen | woningen, appartementen, liften, interieur_opslag, woning_toegang |
| Voertuigen | kentekens, keys_shared (sleutels), voertuig_km, tankstations, impound_tegoed, garage_belasting |
| Overheid | facturen, jail/taakstraf, politie_bolo, flitspalen, gemeentehuis |
| Economie/extra | bank_transactions, dealership, 2dehands, skills, speeltijd |
| Staff | staff_audit, staff_roles, reports (ticketsysteem), unban_requests, anticheat-tabellen |
| Webshop | tebex_* (niet nodig voor een besloten test) |
| Overig | drugs, racing, pechhulp, vuilnisman, gopostal |

## Coördinaten uit `ox_inventory/data/shops.lua`

Niet overgenomen. Van 32 "24/7"-locaties hebben 13 een y-waarde boven 5000
(buiten de standaardkaart), dus een custom kaart. Gebruik ze alleen als dezelfde
kaart op de nieuwe server staat. De rest is niet in-game geverifieerd.

## Nog te doen om hier iets mee te kunnen

1. Keuze: standaard ESX-inventaris houden, of overstappen op `ox_inventory`
   (grote aanpassing in rp_shops, rp_jobs, rp_garages, combat-loadouts).
2. API-verificatie tegen ESX 1.13.5 (`GetPlayerFromId`, xPlayer-methoden,
   `esx:playerLoaded`, `esx_status`-events). Zie `RESTERENDE_PUNTEN.md`.
3. Jobscripts alleen inzien via een bestandslijst van de rars (niet uitpakken).

## API-vergelijking met es_extended 1.13.5 (alleen namen en signaturen)

Bron: functielijst uit `server/classes/player.lua` en de trigger-regels van de events,
aangeleverd door de pc-sessie. Vergeleken met alle ESX-aanroepen in `resources/`.

- **Server-methoden:** alle 19 gebruikte methoden bestaan (`getName`, `addMoney`,
  `removeMoney`, `getMoney`, `getJob`, `getGroup`, `getAccount`, `addAccountMoney`,
  `removeAccountMoney`, `canCarryItem`, `getInventoryItem`, `addInventoryItem`,
  `removeInventoryItem`, `hasWeapon`, `addWeapon`, `updateWeaponAmmo`, `getLoadout`,
  `getInventory`, `setJob`). `setJob(newJob, grade, onDuty)` heeft een extra
  optionele derde parameter.
- **Events:** `esx:playerLoaded` (server: `playerId, xPlayer, isNew`), `esx:setJob`
  (server: `source, job, lastJob`) en `esx:onPlayerDeath` komen overeen met het gebruik.
- **esx_status / esx_basicneeds:** client-events `esx_status:add/set/getStatus/onTick`
  en `esx_basicneeds:onEat/onDrink` bestaan.
- **Niet bevestigd:** `esx:onPlayerSpawn` (wordt door mijn code afgevuurd en door
  esx_basicneeds beluisterd; niet in de lijst van es_extended zelf) en het gedrag
  van de methoden. Dat blijft een test in-game.
- **Extra in 1.13.5:** tweede job (`getJob2`/`setJob2`, `esx:setJob2`), `getSSN`, meta-functies.
  Niet gebruikt; de combat- en jobcode kijkt alleen naar de eerste job.
- **Versies elders:** ox_lib 3.39.0 en oxmysql 2.14.1; nog niet vergeleken met mijn aanroepen.
- esx_basicneeds roept `setPedProp`/`clearPedProp` aan uit `rlrp_smallresources`, dat in
  de map ontbreekt. Zonder die resource kan het fout geven bij eten of drinken.
