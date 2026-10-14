# Ontbrekende assets, externe scripts en handmatige instellingen

Alles wat **niet** in deze repo zit maar je wél nodig hebt (of kunt willen) voor een besloten test of release.
Legenda: 🔴 verplicht • 🟡 sterk aanbevolen • ⚪ optioneel.

## 1. Externe scripts (niet meegeleverd)

| Prio | Wat | Waarom / opmerking | Hoe |
|---|---|---|---|
| 🔴 | **oxmysql** | database-laag | `scripts/install-deps.sh` |
| 🔴 | **ox_lib** | menu's, callbacks, zones, meldingen | `scripts/install-deps.sh` |
| 🔴 | **es_extended** (ESX Legacy) + `esx_menu_*`, `skinchanger`, `esx_skin`, `esx_identity`, `esx_addonaccount`, `esx_addoninventory`, `esx_datastore`, `esx_society`, `esx_status`, `esx_basicneeds`, `esx_license` | framework en basisfuncties | `scripts/install-deps.sh` (meldt wat ontbreekt) |
| 🔴 | **FXServer-artifact** | gameserver | zie `docs/INSTALLATIE.md` |
| 🟡 | **Anticheat** | **Er is geen anticheat meegeleverd.** De server valideert geld/kills/wapens/afstanden, maar dat vervangt geen anticheat (geen detectie van aimbots/mod menus/injectie). Kies er één en test het samen met deze server. | extern |
| 🟡 | **Voicechat** (bijv. `pma-voice`) | proximity-voice voor roleplay; FiveM's standaardvoice is beperkt | extern, ontbreekt in de resourcelijst |
| 🟡 | **Brandstofsysteem** | HUD leest `GetVehicleFuelLevel`; zonder script blijft brandstof vol | extern |
| ⚪ | Voertuigsleutels/-sloten | er is geen slotsysteem; iedereen kan elk voertuig besturen | extern |
| ⚪ | Telefoon, huizen/woningen, kleding-/kapperszaak (utility), boodschappen-/crafting-systemen | niet gebouwd | extern |
| ⚪ | Eigen inventaris (`ox_inventory`) | **niet ondersteund** door deze server (default ESX-inventaris) | – |

## 2. Maps en voertuigen

| Prio | Wat | Opmerking |
|---|---|---|
| ⚪ | **MLO's/interieurs** (politiebureau, ziekenhuis, monteursgarage, Jobcentrum) | Er zijn **geen** custom maps; alle locaties zijn vanilla GTA-coördinaten (buiten/ingang). Gebruik je MLO's, **verplaats dan de coördinaten** (`rp_jobs`, `rp_garages`, `combat_core` SafeZones) en draai `python3 tests/check_zones.py`. |
| ⚪ | **Addon-voertuigen/Nederlandse politie-/ambulancevoertuigen** | Alleen standaard GTA-modellen in `GarageCfg.Shop`. Politie/ambulance-voertuigen en -garage (uitgifte) zijn **niet** gebouwd: spelers gebruiken eigen of bedrijfsvoertuigen. |
| 🟡 | **Coördinaten verifiëren** | Alle plaatsen zijn best-effort. Loop ze na met `/coords` (zie `docs/RESTERENDE_PUNTEN.md` §B1). |

## 3. Visuele en branding-assets

| Prio | Wat | Waar | Status |
|---|---|---|---|
| 🟡 | Server-icoon (96×96 PNG) | `load_server_icon` in `server.cfg` (staat uitgecommentarieerd) | ontbreekt |
| 🟡 | Logo + achtergrondbeeld/-muziek voor de loadscreen | `resources/[server]/server_welcome/web/loading.html` is **CSS-only** (geen afbeeldingen) | optioneel te verrijken |
| 🔴 | Servernaam, kleuren, Discord-link | `server_config/config.lua` + `loading.html` | placeholders (`jouw-invite`) invullen |
| 🟡 | Publieke welkomstpagina | `docs/welkom.html` (gegenereerd) | hosten op jouw website/Discord; regels bijwerken met `scripts/gen_welcome_docs.py` |

## 4. Accounts, sleutels en diensten (handmatig)

| Prio | Wat | Opmerking |
|---|---|---|
| 🔴 | **Cfx.re-licentiesleutel** | `secrets.cfg` (`sv_licenseKey`) |
| 🔴 | **Databasegebruiker + wachtwoord** | sterk, alleen lokaal/privé-netwerk bereikbaar; `mysql_connection_string` in `secrets.cfg` |
| 🟡 | **Discord-server** met kanalen en **6 webhooks** | `general`, `admin`, `money`, `combat`, `gang`, `suspicious` → `dc_webhook_*` in `secrets.cfg`. Beperk wie `admin`/`money`/`suspicious` mag lezen (bevat licenses). |
| 🟡 | Discord: ticket-/supportkanaal, regels-kanaal, rollen (beheerders, testers) | niet meegeleverd |
| 🟡 | Beheerders aanwijzen | `setgroup <id> superadmin|admin|mod` in de serverconsole; stel een beleid op wie welke rol krijgt |
| ⚪ | txAdmin | optioneel voor monitoring/herstarten; werkt naast de scripts (niet getest) |
| ⚪ | Monitoring/alerting (uptime, schijfruimte, back-up-log) | niet meegeleverd |

## 5. Handmatige instellingen (checklist)

- [ ] ESX: `PaycheckInterval` = 30 min, taal, startgeld; `esx_society`: `EnableSocietyPayouts` (zie `docs/INSTALLATIE.md` §D).
- [ ] `server.cfg`: `sv_hostname`, tags, `sv_maxclients`; `set onesync on` blijft staan.
- [ ] `secrets.cfg` ingevuld, rechten 600, **niet** in git.
- [ ] Jobs/salarissen/prijzen gebalanceerd (`docs/ECONOMIE.md`, `JobsCfg.Catalog`, `CombatCfg.Rewards`).
- [ ] Beleid illegale activiteiten: `GangCfg.Activities[…].minPolice` (nu 0 zodat het met weinig spelers werkt; zet ≥ 1 zodra er politie speelt).
- [ ] Serverregels gelezen en goedgekeurd door jou (`rules_nl.lua`); regelversie genoteerd.
- [ ] Back-ups + off-site kopie (`docs/BACKUP_HERSTEL.md`).
- [ ] Privacy: de server logt licenses/Discord-id's (bans, logs). Vermeld dat in je regels/privacyverklaring en beperk de toegang tot de logs.
- [ ] Cfx.re-beleid gelezen (o.a. monetisatie/"pay-to-win" regels) als je ooit donaties of een shop wilt.

## 6. Bekende gaten in de inhoud (niet gebouwd)

Politie-/ambulance-voertuiguitgifte en -armory, jailsysteem, boetes-historie/dossiers, voertuigsloten, telefoon, huizen, bedrijven kopen, uitgebreide crafting,
meerdere personages per speler (`esx_multicharacter` niet getest), brandstof, anticheat. Zie `docs/RESTERENDE_PUNTEN.md` §C.
