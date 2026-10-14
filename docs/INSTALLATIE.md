# Installatiehandleiding

> **Welke hosting heb je?** Dat is niet bekend gemaakt, dus deze handleiding dekt de drie gangbare omgevingen:
> **A. Linux-VPS** • **B. Pterodactyl** (FiveM-egg) • **C. Windows-server**. Kies er één; §D t/m §G gelden voor allemaal.
> Status per omgeving: de **scripts en SQL zijn getest** (zie `docs/TESTRESULTATEN.md`); de **hostingstappen zelf zijn niet** op een
> echte VPS/paneel uitgevoerd. Volg de stappen en meld afwijkingen.

## 0. Wat heb je nodig

| Item | Opmerking |
|---|---|
| Cfx.re-licentiesleutel | <https://portal.cfx.re/servers/registration-keys> (gratis, gekoppeld aan jouw account en server-IP) |
| Server | min. 4 vCPU / 8 GB RAM / 40 GB SSD voor ~32–48 spelers (richtwaarde, niet getest) |
| Database | MariaDB ≥ 10.3 (getest: 10.11) of MySQL 8 |
| Discord-server | + webhooks voor logkanalen (zie `docs/ONTBREKENDE_ASSETS.md`) |
| Domeinnaam | optioneel (voor een website/`welkom.html`) |
| Git, curl, unzip | alleen voor het installeren van afhankelijkheden |

**Poorten:** 30120 **TCP + UDP** open. De database (3306) mag **niet** van buiten bereikbaar zijn.

---

## A. Linux-VPS (Ubuntu 22.04/24.04)

### A1. Server voorbereiden en beveiligen
```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y git curl unzip xz-utils mariadb-server screen ufw fail2ban
sudo adduser --disabled-password --gecos "" fivem          # draai de gameserver NOOIT als root
sudo ufw default deny incoming && sudo ufw allow OpenSSH && sudo ufw allow 30120/tcp && sudo ufw allow 30120/udp && sudo ufw enable
# SSH: alleen sleutels (PasswordAuthentication no in /etc/ssh/sshd_config), root-login uit
sudo mysql_secure_installation
```
MariaDB luistert standaard op `127.0.0.1` (`bind-address`) – laat dat zo.

### A2. Database aanmaken
```bash
sudo mariadb <<'SQL'
CREATE DATABASE esx_nl CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'esx_nl'@'127.0.0.1' IDENTIFIED BY 'KIES_EEN_STERK_WACHTWOORD';
GRANT ALL PRIVILEGES ON esx_nl.* TO 'esx_nl'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
```

### A3. FXServer en server-data
```bash
sudo -iu fivem
mkdir -p ~/fxserver && cd ~/fxserver
# Recommended Linux-build van https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/ (kopieer de fx.tar.xz-link)
curl -fsSLO "<URL-van-fx.tar.xz>" && tar xf fx.tar.xz
cd ~ && git clone <deze-repo-url> server-data && cd server-data
git checkout claude/custom-fivem-esx-server-omyxob         # of jouw releasebranch
```

### A4. Afhankelijkheden (oxmysql, ox_lib, ESX)
```bash
ESX_REF=<geteste-tag> ./scripts/install-deps.sh            # pin ESX! zonder ESX_REF wordt 'main' gebruikt
./scripts/print-versions.sh | tee ~/versies-$(date +%F).txt # leg vast waartegen je draait
```
Het script meldt welke ESX-resources het niet kon vinden. Installeer die handmatig in `resources/[esx]/` of pas `server.cfg` aan.
**Installeer nooit** `esx_ambulancejob`, `esx_policejob`, `esx_mechanicjob`, `esx_vehicleshop`, `esx_shops`, `esx_weaponshop`, `ox_inventory` (zie `docs/DEPENDENCIES.md`).

### A5. Configuratie en geheimen
```bash
cp server.cfg.example server.cfg
cp secrets.cfg.example secrets.cfg && chmod 600 secrets.cfg
nano secrets.cfg      # sv_licenseKey, mysql_connection_string, dc_webhook_*
```
### A6. Database vullen
```bash
DB_USER=esx_nl DB_PASS='JOUW_WACHTWOORD' DB_NAME=esx_nl ./scripts/import-sql.sh
```
Het script stopt met een foutmelding (exit 5) bij verkeerde gegevens, en met exit 1 bij een echt SQL-probleem (getest). Opnieuw uitvoeren is veilig.
> Op MySQL (niet MariaDB) geeft `sql/01_core.sql` aan het eind meldingen voor `IF NOT EXISTS` bij `ALTER TABLE`; die zijn onschuldig.

### A7. Starten (service)
`/etc/systemd/system/fivem.service`:
```ini
[Unit]
Description=FiveM server
After=network.target mariadb.service

[Service]
User=fivem
WorkingDirectory=/home/fivem/server-data
ExecStart=/bin/bash /home/fivem/fxserver/run.sh +exec server.cfg
Restart=on-failure
RestartSec=10
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=read-only
ReadWritePaths=/home/fivem

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl daemon-reload && sudo systemctl enable --now fivem && journalctl -u fivem -f
```
(`ProtectHome=read-only` + `ReadWritePaths` laat alleen jouw map beschrijfbaar; krijg je rechtenfouten, haal die regels dan weg.)

---

## B. Pterodactyl (FiveM-egg)

1. **Server aanmaken** met de FiveM-egg (parkervcp). Allocation 30120 (TCP+UDP). Zet je **licentiesleutel** in de egg-variabelen; kies een recente *artifact*.
2. **Scripts draaien kan niet in de container.** Draai `./scripts/install-deps.sh` op je eigen computer (Linux/WSL/Git Bash) en upload de **hele** projectmap via SFTP naar `/home/container` (inclusief `resources/[core]` en `resources/[esx]`).
3. **Database:** paneel → *Databases* → nieuwe database. Noteer host, poort, gebruiker, wachtwoord, naam (de host is **niet** `127.0.0.1`).
   Importeer in phpMyAdmin/HeidiSQL, **in deze volgorde**: `.sql`-bestanden van `es_extended` en de `esx_*`-resources → `sql/01_core.sql` → `sql/02_jobs_items.sql` → `sql/03_societies.sql`.
   (Of draai `scripts/import-sql.sh` vanaf je computer met `DB_HOST`/`DB_PORT` van het paneel, als de database extern bereikbaar is.)
4. **Geheimen:** maak `secrets.cfg` in de bestandsbeheerder (inhoud van `secrets.cfg.example`). Connection string: `mysql://GEBRUIKER:WACHTWOORD@HOST:POORT/NAAM?charset=utf8mb4`.
5. **server.cfg:** kopieer `server.cfg.example`. Licentiesleutel staat in `secrets.cfg` **of** in de egg-variabele – niet dubbel.
6. **Startup-commando** eindigt op `+exec server.cfg`. Start en controleer de console (§F).
7. **Back-ups:** zie `docs/BACKUP_HERSTEL.md` §4 – het paneel maakt de database niet vanzelf veilig.

---

## C. Windows-server (niet getest)

1. Download de Windows-artifact (<https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/>) en pak uit naar `C:\fxserver`.
2. Installeer MariaDB (of gebruik een externe database) en maak database + gebruiker zoals in A2 (met `mysql.exe`).
3. Clone deze repo naar `C:\server-data`; voer `scripts/install-deps.sh` uit in **Git Bash** of **WSL**; kopieer resultaat naar `C:\server-data\resources`.
4. `server.cfg` en `secrets.cfg` zoals in A5. SQL importeren met `scripts/import-sql.sh` (Git Bash) of HeidiSQL (zelfde volgorde als B3).
5. Start: `C:\fxserver\FXServer.exe +exec server.cfg` (vanuit `C:\server-data`). Open poort 30120 in de Windows-firewall.
6. Back-ups: `scripts/backup.sh` werkt in Git Bash/WSL; plan met Taakplanner.

---

## D. Instellingen na de installatie (verplicht, voor alle omgevingen)

1. **Eerste beheerder:** log in, zoek je speler-id, typ in de **serverconsole** `setgroup <id> superadmin`.
2. **ESX-config** (`resources/[core]/es_extended`, bestandsnamen verschillen per versie):
   * `Config.PaycheckInterval = 30 * 60000` (de salarissen en het economierapport `docs/ECONOMIE.md` gaan hiervan uit).
   * Taal op Nederlands als jouw versie dat heeft; startgeld/-bank bepalen.
   * In `esx_society`: `Config.EnableSocietyPayouts = true` voor salarissen uit de bedrijfskas (aanbevolen).
3. **Branding:** `resources/[server]/server_config/config.lua` (naam, kleuren, HUD) en `resources/[server]/server_welcome/web/loading.html`
   (de loadscreen is statische HTML; `python3 tests/check_config.py` waarschuwt als de servernaam niet overeenkomt).
4. **Regels:** `resources/[server]/server_welcome/rules_nl.lua`. Na een wijziging: `WelcomeCfg.Rules.version` ophogen en
   `python3 scripts/gen_welcome_docs.py` (werkt `docs/SERVERREGELS.md`, `WELKOM.md` en `welkom.html` bij; publiceer die op Discord/website).
5. **Jobs/salarissen:** `JobsCfg.Catalog` (zie `docs/JOBS.md`); controleer in de console bij start dat er **geen** melding "jobs wijken af" staat.
6. **Coördinaten controleren** met `/coords` (zones, garages, winkels, depots, territoria) – zie `docs/RESTERENDE_PUNTEN.md` §B.
7. **Back-ups instellen** (`docs/BACKUP_HERSTEL.md`) **vóór** je spelers uitnodigt.

## E. Configuratie controleren (kan op je eigen computer)

```bash
pip install lupa pymysql && apt install lua-check          # eenmalig
python3 tests/check_config.py      # server.cfg, secrets-voorbeeld, alle configwaarden
python3 tests/check_zones.py       # RP-gebieden niet overlappend met PvP/gangoorlog
python3 tests/check_economy.py     # economie-beleid (schrijft docs/ECONOMIE.md)
python3 tests/check_jobs.py        # jobcatalogus ↔ SQL ↔ teksten
```

## F. Eerste start – wat je in de console hoort te zien

* `[combat_core] 3 zone(s) geladen.` en `[rp_gangs] 0 gang(s) geladen.`
* **Geen** rode regels met `Tabel … ontbreekt` (dan is de SQL niet geïmporteerd) en geen `Failed to load script`.
* **Geen** `[rp_jobs] … wijken af van JobsCfg.Catalog` (anders: `sql/02_jobs_items.sql` importeren of `jobsync`, daarna herstarten).
* Een waarschuwing over een ontbrekende ESX-resource of `esx_society` betekent dat `install-deps.sh` die niet vond.

## G. Problemen oplossen

| Melding | Oorzaak/oplossing |
|---|---|
| `Tabel … ontbreekt. Importeer sql/01_core.sql` | SQL niet geïmporteerd of verkeerde database in de connection string |
| `server_welcome`: spelers worden gekickt "regels" | tabel `server_rules_accepted` ontbreekt of timeout te kort; tijdelijk `WelcomeCfg.Rules.requireAcceptance = false` |
| `Failed to load script @ox_lib/init.lua` / `@es_extended/imports.lua` | resource ontbreekt in `resources/` of staat te laat in `server.cfg` |
| `jobs.duty_missing` | `sql/02_jobs_items.sql` niet geïmporteerd of server niet herstart na import |
| Webhooks komen niet aan | convar leeg/typfout; `set` (niet `setr`); console toont `HTTP 4xx` |
| Niemand kan kills scoren / zones doen niets | OneSync niet aan (`set onesync on`) |
| Spelers hangen op het akkoordscherm | `/akkoord` in de chat (noodoplossing), controleer F8-console op NUI-fouten |

---
**Gehost paneel zonder shell (Pelican/Pterodactyl)?** Volg `docs/START_HIER_PELICAN.md`; maak het samengevoegde SQL-bestand met `scripts/build-all-sql.sh`.
