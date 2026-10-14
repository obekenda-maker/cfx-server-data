# Installatie

Je hebt nodig: een Linux-VPS **of** een Pterodactyl-paneel met FiveM-egg, een MariaDB/MySQL-database, en een
Cfx.re-licentiesleutel (<https://portal.cfx.re/servers/registration-keys>).

---------------------------------------------------------------------------

## A. VPS (Ubuntu 22.04/24.04)

### 1. Pakketten en database
```bash
sudo apt update && sudo apt install -y git curl unzip xz-utils mariadb-server screen
sudo mysql_secure_installation
sudo mariadb <<'SQL'
CREATE DATABASE esx_nl CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'esx_nl'@'127.0.0.1' IDENTIFIED BY 'KIES_EEN_STERK_WACHTWOORD';
GRANT ALL PRIVILEGES ON esx_nl.* TO 'esx_nl'@'127.0.0.1';
FLUSH PRIVILEGES;
SQL
```

### 2. FXServer
Download de *recommended* (of nieuwere) Linux-build van <https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/>:
```bash
mkdir -p ~/fxserver && cd ~/fxserver
curl -fsSLO "<URL-van-fx.tar.xz>"          # kopieer de link van de pagina hierboven
tar xf fx.tar.xz
```

### 3. Server-data (deze repo) en afhankelijkheden
```bash
cd ~ && git clone <deze-repo-url> server-data && cd server-data
./scripts/install-deps.sh                  # oxmysql, ox_lib, ESX
# Productie: pin ESX op een geteste tag:  ESX_REF=<tag> ./scripts/install-deps.sh
```
Het script meldt welke ESX-resources het niet kon vinden. Installeer die dan handmatig in `resources/[esx]/`
(of verwijder de `ensure`-regel uit `server.cfg` als je ze bewust niet gebruikt).

### 4. Configuratie en geheimen
```bash
cp server.cfg.example server.cfg
cp secrets.cfg.example secrets.cfg && chmod 600 secrets.cfg
nano secrets.cfg       # sv_licenseKey, mysql_connection_string, webhooks
```
Open poort **30120 TCP+UDP** in je firewall (`sudo ufw allow 30120`).

### 5. Database vullen
```bash
DB_USER=esx_nl DB_PASS='JOUW_WACHTWOORD' DB_NAME=esx_nl ./scripts/import-sql.sh
```
Volgorde: ESX-tabellen (uit `es_extended` en de `esx_*` resources) → `sql/01_core.sql` (eigen tabellen) →
`sql/02_jobs_items.sql` (jobs, **salarissen**, items) → `sql/03_societies.sql` (bedrijfsrekeningen).
Alles is opnieuw uit te voeren zonder dubbele data.
> `01_core.sql` eindigt met `ALTER TABLE owned_vehicles ADD COLUMN IF NOT EXISTS stored …` (MariaDB). Op MySQL geeft dit
> een melding als de kolom al bestaat – negeer die.

### 6. Starten
```bash
cd ~/server-data
screen -S fivem
bash ~/fxserver/run.sh +exec server.cfg
```
Als service (aanbevolen): `/etc/systemd/system/fivem.service`
```ini
[Unit]
Description=FiveM server
After=network.target mariadb.service

[Service]
User=fivem
WorkingDirectory=/home/fivem/server-data
ExecStart=/bin/bash /home/fivem/fxserver/run.sh +exec server.cfg
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

### 7. Eerste beheerder en ESX-instellingen
* Verbind met de server, noteer je speler-id (`F8` → `status` of het scoreboard) en typ in de **serverconsole**:
  `setgroup <id> superadmin`.
* In `resources/[core]/es_extended` (config): zet de taal op Nederlands (`Config.Locale = 'nl'`, als jouw ESX-versie die heeft),
  controleer startgeld en `PaycheckInterval`.
* In `esx_society` (config): `Config.EnableSocietyPayouts = true` laat salarissen uit de bedrijfskas komen (realistischer
  economie; vul de kas dan via boetes/behandelingen/taxi). Staat het uit, dan komen salarissen "uit het niets".
* Controleer `docs/TESTEN.md` (API-verificatielijst voor jouw ESX-versie).

---------------------------------------------------------------------------

## B. Pterodactyl

1. **Server aanmaken** met de *FiveM*-egg (parkervcp). Wijs een allocation toe (poort 30120, TCP+UDP).
   Zet in de egg-variabelen je **licentiesleutel**; kies een recente *artifact*.
2. **Bestanden uploaden**: de scripts in `scripts/` hebben een shell nodig. Draai `./scripts/install-deps.sh` daarom
   op je eigen PC (Linux, WSL of Git Bash) en upload de volledige map (incl. `resources/[core]` en `resources/[esx]`)
   via SFTP naar `/home/container`. Alternatief: laat de egg deze repo via `GIT`-variabele clonen en upload `[core]`/`[esx]` erbij.
3. **Database**: paneel → *Databases* → nieuwe database. Noteer **host, poort, gebruiker, wachtwoord, naam**
   (de host is *niet* `127.0.0.1`!). Importeer in phpMyAdmin/HeidiSQL, in deze volgorde: de `.sql`-bestanden van
   `es_extended` en de `esx_*`-resources, daarna `sql/01_core.sql`, `02_jobs_items.sql`, `03_societies.sql`.
4. **Geheimen**: maak `secrets.cfg` aan in de bestandsbeheerder (inhoud uit `secrets.cfg.example`).
   `set mysql_connection_string "mysql://GEBRUIKER:WACHTWOORD@HOST:POORT/NAAM?charset=utf8mb4"`.
   Wil je het bestand niet gebruiken, zet dan in het startup-commando `+set mysql_connection_string "…"`.
5. **server.cfg**: kopieer `server.cfg.example` naar `server.cfg`. De licentiesleutel staat in `secrets.cfg`
   (of via egg-variabele) – niet dubbel opgeven.
6. **Startup-commando**: moet eindigen op `+exec server.cfg`. Start de server en controleer de console op rode regels.
7. Eerste beheerder: typ in de paneel-console `setgroup <id> superadmin`.

Updaten: upload gewijzigde bestanden en herstart; of `restart <resource>` in de console (SQL-wijzigingen eerst importeren).

---------------------------------------------------------------------------

## Problemen oplossen

| Melding | Oorzaak/oplossing |
|---|---|
| `Tabel … ontbreekt. Importeer sql/01_core.sql` | SQL niet geïmporteerd of verkeerde database in connection string |
| `Failed to load script @ox_lib/init.lua` / `@es_extended/imports.lua` | `ox_lib`/`es_extended` staan niet in `resources/` of starten te laat (zie startvolgorde in `server.cfg.example`) |
| `jobs.duty_missing` (job ontbreekt) | `sql/02_jobs_items.sql` niet geïmporteerd, of de ESX-server is niet herstart na import (ESX leest jobs bij start) |
| Webhook-berichten komen niet aan | convar leeg/typfout; `set` (niet `setr`) en de URL in aanhalingstekens; controleer console op `HTTP 4xx` |
| Niemand kan kills scoren | OneSync niet aan (`set onesync on`) |
