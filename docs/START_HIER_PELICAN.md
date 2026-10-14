# Start hier – installeren op een gehost paneel (Pelican / Pterodactyl / txAdmin)

Voor hosts zonder eigen shell. De zip bevat de **complete serverdata**: eigen resources, ESX 1.13.5 met alle benodigde
`esx_*`-resources, `cron`, `oxmysql` 2.14.1, `ox_lib` 3.39.0, `server.cfg`, een lege `secrets.cfg` en `sql/ALL_IN_ONE.sql`.
Niet inbegrepen: voertuigen, kaarten (MLO), kleding en de politie-/ANWB-scripts (nog niet gebouwd).

## 1. Zip uploaden en uitpakken
1. Stop de server. Maak in het bestandsbeheer een back-up van je huidige `resources`-map (hernoem naar `resources_oud`).
2. Upload de zip naar de hoofdmap van de server (`/home/container`) en pak hem uit. Er moet daarna staan:
   `server.cfg`, `secrets.cfg`, `resources/` en `sql/` **direct in de hoofdmap** (niet in een extra map).
3. Controleer in het bestandsbeheer dat deze bestanden bestaan (anders is het uitpakken mislukt):
   `resources/[server]/server_config/fxmanifest.lua` · `resources/[core]/es_extended/fxmanifest.lua` ·
   `resources/[core]/oxmysql/fxmanifest.lua` · `resources/[core]/ox_lib/fxmanifest.lua`.
   Zie je overal "does not have a resource manifest" in de console, dan ontbreken bestanden of staan ze een niveau te diep.

## 2. Database
1. Maak in het paneel (tab **Databases**) een database. Noteer host, poort, naam, gebruiker, wachtwoord.
2. Open phpMyAdmin (of de importknop van je host), kies die **lege** database en importeer `sql/ALL_IN_ONE.sql`.
   Het bestand maakt zelf geen database aan en is bedoeld voor één import in een lege database.
3. Vul in `secrets.cfg` de regel `set mysql_connection_string "mysql://GEBRUIKER:WACHTWOORD@HOST:POORT/NAAM?charset=utf8mb4"`
   (speciale tekens in het wachtwoord URL-encoden, bv. `@` → `%40`). Discord-webhooks zijn optioneel.

## 3. Licentiesleutel
De sleutel staat in de **startopdracht van het paneel** (veld *Startup*/*License Key*). Laat `sv_licenseKey` in `secrets.cfg`
uitgecommentarieerd. Deel de startopdracht of console-uitvoer nooit: staat de sleutel ergens openbaar, maak dan een nieuwe op
https://portal.cfx.re en vervang hem in het paneel.

## 4. txAdmin of rechtstreeks
* Eenvoudigst voor de eerste test: zet in het paneel de variabele voor txAdmin uit (`TXADMIN_ENABLE=0`); de server start dan met `+exec server.cfg`.
* Met txAdmin: kies bij de eerste setup *bestaande serverdata*, map `/home/container`, config `server.cfg`. Zet een sterk txAdmin-wachtwoord.

## 5. Beheerrechten
In `server.cfg` staat een `add_principal identifier.license:CHANGEME group.admin`-regel. Vervang `CHANGEME` door jouw eigen
license-identifier (zie je in de console zodra je verbindt) en start opnieuw. Zonder dit heb je geen admin.

## 6. Starten en controleren
Console zonder rode fouten, en: `Started resource ...` voor alle regels uit `server.cfg`. Verbind, accepteer de regels,
maak een personage, en loop daarna `docs/MULTIPLAYER_CHECKLIST.md` door (minimaal 3–4 echte spelers). **Pas daarna** openen.

Veelvoorkomende fouten: "Couldn't find resource X" = map ontbreekt/verkeerde plek · `oxmysql` fout bij start = connection string ·
"Table ... doesn't exist" = `ALL_IN_ONE.sql` niet (volledig) geïmporteerd.
