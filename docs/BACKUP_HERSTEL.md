# Back-up- en herstelprocedure

**Alles wat spelers kwijt kunnen raken staat in de database** (ESX-spelers, geld, jobs, voertuigen, combat-statistieken, gangs, bans,
regels-akkoord). De code staat in git. Een goede back-up is dus: **database + serverconfiguratie** (+ je eigen aanpassingen).

> De scripts `scripts/backup.sh` en `scripts/restore.sh` zijn **echt getest** tegen MariaDB 10.11 (zie `docs/TESTRESULTATEN.md`:
> dump, checksum, versleuteld config-archief, retentie, lock, herstel tot byte-gelijke tabellen, weigeren van beschadigde back-ups).
> **Niet getest:** hosting-specifieke omgevingen (je panel, cron op jouw VPS) en herstel op een andere MariaDB/MySQL-versie.

## 1. Wat wordt waar bewaard

| Onderdeel | Hoe | Waar |
|---|---|---|
| Database (`esx_nl`) | `scripts/backup.sh` → `db-<naam>-<tijd>.sql.gz` + `.sha256` | `backups/` (rechten 700/600) |
| `server.cfg` | `INCLUDE_CONFIG=1` | `backups/config-<tijd>.tar.gz` |
| `secrets.cfg` (licentie, DB-wachtwoord, webhooks) | `INCLUDE_CONFIG=1 INCLUDE_SECRETS=1 BACKUP_PASSPHRASE_FILE=…` | alleen **versleuteld** (`.tar.gz.gpg`); zonder wachtwoordbestand weigert het script |
| Code, eigen resources, SQL, docs | git (deze repo) | je git-remote |
| Externe resources (`[core]`, `[esx]`) | opnieuw te installeren met `scripts/install-deps.sh` — **noteer de versies** (`scripts/print-versions.sh`) | in je beheerdocument |
| Eigen wijzigingen buiten git (`resources/[local]`, afbeeldingen, txAdmin-`txData`) | handmatig mee-archiveren | jouw keuze |

## 2. Dagelijkse back-up instellen (VPS)

```bash
# eenmalig: wachtwoordbestand voor het versleutelen van secrets (bewaar het ELDERS ook – anders is het archief onleesbaar)
install -m 600 /dev/null ~/.backup-passphrase && echo 'kies-een-lange-passphrase' > ~/.backup-passphrase

# crontab -e   (elke nacht 04:10; bewaar 14 dagen)
10 4 * * * cd /home/fivem/server-data && DB_USER=esx_nl DB_PASS='…' DB_NAME=esx_nl KEEP_DAYS=14 INCLUDE_CONFIG=1 INCLUDE_SECRETS=1 BACKUP_PASSPHRASE_FILE=$HOME/.backup-passphrase ./scripts/backup.sh >> backups/backup.log 2>&1
```
Zet het databasewachtwoord liever in een omgevingsbestand met rechten 600 (`set -a; . ~/.fivem-env; set +a`) dan in de crontab.
Het script gebruikt `MYSQL_PWD`, dus het wachtwoord staat niet in de procestabel.

* **Off-site kopie (verplicht voor een echte release):** kopieer `backups/` dagelijks naar een andere machine of opslag
  (`rclone`, `rsync` of de back-up-functie van je hoster). Een back-up op dezelfde schijf beschermt niet tegen schijf- of VPS-verlies.
* **Controle:** `backups/backup.log` moet elke dag een regel `Klaar.` hebben. Het script stopt met een foutcode (2–5) bij een mislukte of
  onvolledige dump; laat je monitoring of cron-mail daarop letten.
* **Voor elke update** (artifact, ESX, deze repo): maak handmatig een back-up en `git tag voor-update-<datum>`.

## 3. Herstellen (VPS)

1. **Stop de gameserver** (anders schrijft hij tijdens het herstel naar de database).
2. Kies de back-up: `ls -lh backups/db-esx_nl-*.sql.gz`.
3. Herstel:
   ```bash
   DB_USER=esx_nl DB_PASS='…' DB_NAME=esx_nl ./scripts/restore.sh backups/db-esx_nl-20261014-041000.sql.gz
   ```
   Het script controleert checksum en gzip, **maakt eerst een veiligheidskopie van de huidige staat** (`backups/pre-restore-…`),
   vraagt om `JA`, herstelt en toont aantallen rijen van de belangrijkste tabellen.
   * Staan er tabellen in de database die **niet** in de back-up zitten en wil je die weg (volledige terugzet)? Voeg `--clean` toe.
   * Een beschadigde of onvolledige back-up wordt geweigerd **zonder** de database aan te raken.
4. Start de server en controleer: log in, geld/voertuigen/gang kloppen, `/top` toont het leaderboard.
5. Ging het herstel fout? Herstel de `pre-restore-…`-kopie op dezelfde manier.

**Alleen een configbestand terug:** `gpg -d backups/config-….tar.gz.gpg | tar -xz -C /pad/naar/server-data` (vraagt om de passphrase).

## 4. Pterodactyl / beheerde hosting

* **Bestanden:** gebruik de back-upfunctie van het paneel (Backups-tab) voor de serverbestanden, vóór elke update.
* **Database:** Databases-tab → exporteer met phpMyAdmin (formaat SQL, "Add DROP TABLE") of draai `scripts/backup.sh` vanaf een machine
  die de database mag bereiken (host/poort uit het paneel; `DB_HOST` en `DB_PORT` instellen). Herstel kan met `scripts/restore.sh` op dezelfde manier.
* **Plan het zelf:** het paneel maakt de database niet automatisch veilig. Stel in het paneel een geplande back-uptaak in en bewaar een kopie buiten het paneel.

## 5. Oefen het herstel (maandelijks, vóór de release één keer)

Een back-up die je nooit hebt teruggezet is een gok. Oefening op een **testdatabase** (niet op productie):
```bash
DB_USER=… DB_PASS=… DB_NAME=esx_nl_test ./scripts/restore.sh backups/db-esx_nl-<recent>.sql.gz --yes --clean
```
Start een testserver tegen die database en loop de herstel-controlelijst (§3 stap 4) door. Noteer hoe lang het duurde (je hersteltijd).

## 6. Doelen en grenzen

* **Maximaal gegevensverlies (RPO)** = tijd sinds de laatste back-up (met de cron hierboven: ≤ 24 uur). Wil je minder? Draai het script vaker of schakel binary logging in op MariaDB.
* **Combat-statistieken** worden elke 30 s naar de database geschreven; bij een harde crash gaan ≤ 30 s verloren (zie `docs/RESTERENDE_PUNTEN.md`).
* Een back-up herstelt **niet** wat in het spel via ESX op de server in geheugen staat maar nog niet is opgeslagen; stop de server netjes (`quit`) vóór een geplande herstart.
* Herstel op een **andere MariaDB/MySQL-hoofdversie** is niet getest; controleer dat eerst op een testdatabase.
