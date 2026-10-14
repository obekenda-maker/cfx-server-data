# Resterende punten en handmatige instellingen

Dit is de eerlijke lijst van wat **niet** is geverifieerd of door jou moet worden ingesteld.
Bekende *code*-fouten waren er na de laatste testronde niet; de risico's zitten in wat zonder GTA/ESX niet te testen is.

## 0. Release-blokkade

**Het multiplayer-testplan (`docs/MULTIPLAYER_CHECKLIST.md`) is nog niet uitgevoerd.** Tot dan is de server niet vrijgegeven; zie `docs/RELEASE_CHECKLIST.md`.

## A. Moet je in-game verifiëren (nog nooit gedraaid)
1. **Alle clientcode**: zones/blips/markers, binnenkomst-prompt, bystander (onkwetsbaar + niet schieten + naar buiten zetten), spawn/teleport
   met grondhoogte, loadouts, death-camera/respawn, protectie-effect, menu's, progressbars, politie-animaties/boeien/begeleiden, taxi-meter.
   → checklist in `docs/TESTEN.md` (§3).
2. **ESX/ox_lib/oxmysql-API's** tegen jouw versies → tabel in `docs/TESTEN.md` (§2). Een afwijking is meestal één regel.
3. **`weaponDamageEvent`** (server-side schadebescherming tussen deelnemers/niet-deelnemers). Werkt het niet, dan blijft de
   client-bescherming (onkwetsbaar/geen vuren) staan en loopt er geen script-error; test met 2 clients.
4. **Esx_status events** (`esx_status:onTick/getStatus/set/add`) en `esx_basicneeds:onEat/onDrink`: HUD toont honger/dorst alleen als die kloppen.
5. **Prestaties** met `resmon` bij een gevulde server (richtwaarden in `docs/TESTEN.md` §4).

## B. Moet je instellen/aanpassen
1. **Coördinaten** van zones, garages, depot, winkels, bezorgpunten, dienstpunten, territoria, zwarte markt: best-effort bekende GTA-locaties → controleer met `/coords`.
2. **Licentiesleutel, database, Discord-webhooks** in `secrets.cfg`.
3. **Eerste beheerder**: `setgroup <id> superadmin` in de serverconsole. Accepteert jouw ESX-versie de groep `mod` niet, pas dan `ServerCfg.Admin.groups` aan.
4. **ESX-config**: taal, startgeld, `PaycheckInterval`; in `esx_society` `Config.EnableSocietyPayouts` voor salarissen uit de bedrijfskas.
5. **Salarissen/prijzen/beloningen** zijn startwaarden (`sql/02_jobs_items.sql`, `*/config.lua`). Balanceer na een testperiode:
   `CombatCfg.Rewards` (dagcap, uurbudget), bezorg-`pay`/`dailyMax`, voertuig-/winkelprijzen.
6. **Brandstof**: de HUD leest `GetVehicleFuelLevel`; er is geen brandstofsysteem meegeleverd.

## B2. Nieuw in fase 3 (ook handmatig te controleren)
1. **Territoria `grove`/`davis`/`mirror`** zijn in fase 3 verplaatst of nieuw gekozen zodat ze niet op winkels/RP-punten liggen; de zone-lint bewijst de afstanden tussen de **config**-coördinaten, niet dat de plek in-game begaanbaar is → controleer met `/coords`.
2. **SafeZones** (`CombatCfg.SafeZones`) zijn straalcirkels rond bekende RP-punten; controleer in-game dat ze de gebouwen/straten dekken (bij MLO's aanpassen).
3. **`esx_identity` + akkoord-pagina:** de akkoordpagina wacht tot er geen andere NUI focus heeft. Controleer met een nieuw account of het personagescherm en de regels elkaar niet in de weg zitten.
4. **`minPolice = 0`** voor illegale activiteiten (zodat testen met weinig spelers kan); zet het hoger zodra er politie speelt.
5. **Jobs-sync:** het commando `jobsync` schrijft alleen de catalogus-jobs; na een wijziging altijd de server herstarten.
6. **Anticheat, voicechat, brandstof, sleutels** ontbreken (zie `docs/ONTBREKENDE_ASSETS.md`).

## C. Bekende beperkingen (bewust of niet gebouwd)
* **Ganggevechten overleven geen herstart** (zone + betaalde kosten gaan verloren); territoriumeigendom blijft wel bewaard.
* **Statistieken** worden elke 30 s (en bij disconnect/resource-stop) weggeschreven: bij een harde crash gaan ≤ 30 s aan stats verloren.
* **Combat-economie**: vrienden kunnen binnen de caps elkaars kills "boosten" (dagcap + uurbudget + paar-cooldown beperken dit; geen volledige bescherming). Monitor het `suspicious`/`money`-Discordkanaal.
* **ESX-eigen data** (users: geld/job/positie/loadout/inventaris, personages) wordt door ESX bewaard; hier alleen onze eigen tabellen getest.
* **Hospital-respawn** laat `esx_basicneeds` honger/dorst resetten (ESX-standaard); in PvP-zones is dit afgevangen met een snapshot.
* **Twee meldingssystemen**: onze resources gebruiken `ox_lib`-meldingen; ESX/esx_basicneeds kunnen eigen `ESX.ShowNotification` tonen.
* **Niet ondersteund**: `ox_inventory`, `esx_multicharacter` (identifier-prefix werkt wel, niet getest), voertuigsleutels/-sloten, telefoon, huizen.
* **GTA-minimap** met health-ring blijft zichtbaar (standaard radar); alleen losse HUD-onderdelen (geld, gebiedsnaam, wapen-icoon, voertuignaam) zijn verborgen.
* **Weapon-audit** na verlaten verwijdert alleen het *geselecteerde* combatwapen (server-API `GetSelectedPedWeapon`); de volledige opruiming doet de client + de RP-loadout-herstelactie.
* **Pterodactyl**: `scripts/*.sh` hebben een shell nodig; draai ze lokaal en upload (zie `docs/INSTALLATIE.md`).
