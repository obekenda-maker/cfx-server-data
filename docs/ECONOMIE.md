# Economie-overzicht (gegenereerd)

*Gegenereerd door `python3 tests/check_economy.py` uit de echte configbestanden en `sql/02_jobs_items.sql`.*

**Aanname:** ESX betaalt salaris elke **30 minuten**. Zet dat in `es_extended` (`Config.PaycheckInterval = 30 * 60000`);
de ESX-standaard is korter, waardoor salarissen veel te hoog uitvallen. Controleer dit eerst, anders kloppen de bedragen hieronder niet.

## Geldbronnen (faucets)

| Bron | Maximaal per speler per dag | Opmerking |
|---|---|---|
| Salaris (per grade) | zie tabel | uitbetaling per 30 min (aanname); ESX bepaalt het interval |
| Bezorging: Bezorger | €3,000 | server-begrensd (dailyMax in DB) |
| Bezorging: Vrachtwagenchauffeur | €6,000 | server-begrensd (dailyMax in DB) |
| Combat-kills (geld) | €3,000 | + globaal uurbudget 60,000/uur voor de hele server |
| Taxi | ≤ 1500 per rit | overdracht van passagier (geen nieuw geld) |
| Hehler (zwart geld) | €6,000 | alleen na activiteit 'schroot' (item-limiet) |
| Gebiedsinkomsten (gang) | 400/uur/gebied | max 2 gebieden; alleen met ≥2 leden online → gangkas |

## Salarissen

| Job | Grade | Label | Per uitbetaling | Per uur (bij 30 min) |
|---|---|---|---|---|
| ambulance | 0 | Ambulancier | €400 | €800 |
| ambulance | 1 | Verpleger | €550 | €1,100 |
| ambulance | 2 | Arts | €750 | €1,500 |
| ambulance | 3 | Chef | €950 | €1,900 |
| courier | 0 | Bezorger | €100 | €200 |
| mechanic | 0 | Leerling | €250 | €500 |
| mechanic | 1 | Monteur | €400 | €800 |
| mechanic | 2 | Eigenaar | €650 | €1,300 |
| police | 0 | Cadet | €350 | €700 |
| police | 1 | Agent | €500 | €1,000 |
| police | 2 | Brigadier | €650 | €1,300 |
| police | 3 | Inspecteur | €800 | €1,600 |
| police | 4 | Commissaris | €1000 | €2,000 |
| taxi | 0 | Chauffeur | €200 | €400 |
| taxi | 1 | Manager | €400 | €800 |
| trucker | 0 | Chauffeur | €150 | €300 |

## Geldputten (sinks)

| Put | Bedrag |
|---|---|
| Winkels (eten/EHBO/kit) | ShopCfg.Catalogs |
| Voertuigen | vanaf €3,000 |
| Wapenlicentie | €2,500 |
| Wapens (legaal) | WEAPON_PISTOL €4,500, WEAPON_COMBATPISTOL €6,500, WEAPON_BAT €400, WEAPON_KNIFE €350 |
| Zwarte markt | zie config (zwart geld) |
| Depot (wegsleep) | €500 |
| Ziekenhuis | €500 (nooit > bezit) |
| Revive | €150 |
| Combat-entree | haven €0, vliegveld €0, steengroeve €100 |
| Gang oprichten | €50,000 |
| Territorium claimen | €25,000 |
| Ganggevecht | €15,000 |

## Combat-beloningen

* Basis €100 (+ streak max €100) × zonemultiplier (max 1.5); dagcap €3,000 ≈ 30 basiskills.
* Globaal uurbudget €60,000: daarna alleen XP. Paar-cooldown 120 s; slachtoffer moet ≥ 10 s geleefd hebben.
* Beste burgerbaan-daglimiet €6,000 ≥ combat-dagcap €3,000: **PvP verslaat roleplay-banen niet** (beleidsregel, getest).
* Gangoorlogen en tijdelijke zones: **geen** geld/XP/stats.

## Wapens

* Combatwapens (7): alleen client-native, nooit in ESX-loadout/DB; verdwijnen bij verlaten/crash.
* Legaal: licentie €2,500 + wapen. Illegaal: alleen gangleden met recht `blackmarket`, gebied vereist, daglimiet, ≥1.5× legale prijs.

## Beleidsregels die dit script toetst

1. Geen niet-baas-salaris boven €2000/uur; af-dienst-jobs betalen €0.
2. Combat-dagcap ≤ beste burgerbaan-daglimiet.
3. Eén kill (incl. streak/multiplier) ≤ dagcap; entreegeld < dagcap.
4. Zwarte-markt-wapen ≥ 1.5× legale prijs, daglimiet ≤ 3.
5. Gebiedsinkomsten per gang per dag ≤ 5× beste baan-daglimiet; oorlog/claim kosten geld.
