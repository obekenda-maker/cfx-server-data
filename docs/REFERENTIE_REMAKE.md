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
