#!/usr/bin/env bash
# Echte test van scripts/backup.sh en scripts/restore.sh tegen de lokale MariaDB.
# shellcheck disable=SC2012,SC2016  # ls/tellen in een testscript is hier prima
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MS="mariadb -uroot --default-character-set=utf8mb4"; command -v mariadb >/dev/null || MS="mysql -uroot --default-character-set=utf8mb4"
PASS="T3st-W8woord!"; DB=cfx_bk; USERN=bk_user
TMP="$(mktemp -d)"; BK="$TMP/backups"
PASSED=0; FAILED=0
ok()   { PASSED=$((PASSED+1)); echo "  ✓ $1"; }
fail() { FAILED=$((FAILED+1)); echo "  ✗ $1"; }
check() { local n="$1"; shift; if "$@"; then ok "$n"; else fail "$n"; fi; }
cleanup() { $MS -e "DROP DATABASE IF EXISTS $DB; DROP USER IF EXISTS '$USERN'@'127.0.0.1'; DROP USER IF EXISTS '$USERN'@'localhost';" 2>/dev/null; rm -rf "$TMP"; rm -f "$ROOT/server.cfg" "$ROOT/secrets.cfg"; }
trap cleanup EXIT
[ -e "$ROOT/server.cfg" ] && { echo "OVERGESLAGEN: server.cfg bestaat al in $ROOT (test zou het overschrijven)"; exit 0; }

$MS -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB CHARACTER SET utf8mb4; CREATE USER '$USERN'@'127.0.0.1' IDENTIFIED BY '$PASS'; GRANT ALL ON $DB.* TO '$USERN'@'127.0.0.1'; FLUSH PRIVILEGES;" || { echo "geen MariaDB beschikbaar"; exit 1; }
for f in tests/esx_stub.sql sql/01_core.sql sql/02_jobs_items.sql sql/03_societies.sql; do $MS $DB < "$ROOT/$f" || echo "(waarschuwing import $f)"; done
$MS $DB -e "INSERT INTO owned_vehicles (owner, plate, vehicle, type, \`stored\`) VALUES ('license:a','AB 123 C','{\"model\":1}','car',1),('license:b','CD 456 E','{\"model\":2}','car',0);
 INSERT INTO rp_gangs (name,label,color,bank,created_by) VALUES ('rood','Rood','#ff0000',12345,'license:a');
 INSERT INTO rp_gang_members (identifier,gang_id,grade,name) VALUES ('license:a',1,4,'Ä Ü ß – emoji ✓');
 INSERT INTO combat_stats (identifier,name,kills,deaths,xp) VALUES ('license:a','Een',10,2,500),('license:b','Twee',3,9,40);
 INSERT INTO admin_bans (license,name,reason,banned_by) VALUES ('license:z','Boef','Cheaten','Admin');
 INSERT INTO server_rules_accepted (license,version,name) VALUES ('license:a',1,'Een');"
TABLES="$($MS -N -e "SELECT table_name FROM information_schema.tables WHERE table_schema='$DB'")"
sums() { for t in $TABLES; do $MS -N -e "CHECKSUM TABLE $DB.\`$t\`"; done | sort; }
BEFORE="$(sums)"
export DB_HOST=127.0.0.1 DB_USER=$USERN DB_PASS=$PASS DB_NAME=$DB BACKUP_DIR="$BK"

echo "== backup =="
OUT="$(bash "$ROOT/scripts/backup.sh" 2>&1)"; RC=$?
rc_is() { [ "$RC" -eq "$1" ]; }
rc_not() { [ "$RC" -ne "$1" ]; }
check "backup slaagt (exit 0)" rc_is 0
FILE="$(ls "$BK"/db-$DB-*.sql.gz 2>/dev/null | head -1)"
files_exist() { [ -f "$FILE" ] && [ -f "$FILE.sha256" ]; }
perms_ok() { [ "$(stat -c %a "$BK")" = 700 ] && [ "$(stat -c %a "$FILE")" = 600 ]; }
sha_ok() { ( cd "$BK" && sha256sum -c "$(basename "$FILE").sha256" >/dev/null ); }
utf8_ok() { zcat "$FILE" | grep -q 'Ä Ü ß – emoji ✓'; }
nopw() { ! grep -qE -- '--password|-p"\$DB_PASS' "$ROOT/scripts/backup.sh" "$ROOT/scripts/restore.sh" && ! printf '%s' "$OUT" | grep -qF "$PASS"; }
check "dumpbestand + checksumbestand aangemaakt" files_exist
check "back-upmap heeft rechten 700, bestand 600" perms_ok
check "sha256 klopt" sha_ok
check "dump bevat gegevens (UTF-8 intact)" utf8_ok
check "wachtwoord staat niet in de scripts/uitvoer" nopw

echo "== config-archief =="
echo 'sv_hostname "test"' > "$ROOT/server.cfg"; echo 'set mysql_connection_string "mysql://u:GEHEIMWACHTWOORD@h/db"' > "$ROOT/secrets.cfg"
INCLUDE_CONFIG=1 INCLUDE_SECRETS=1 bash "$ROOT/scripts/backup.sh" >/dev/null 2>&1; RC=$?
check "INCLUDE_SECRETS zonder wachtwoordbestand wordt geweigerd" rc_is 5
echo 'een-sterk-passphrase' > "$TMP/pp"; chmod 600 "$TMP/pp"; sleep 1
INCLUDE_CONFIG=1 INCLUDE_SECRETS=1 BACKUP_PASSPHRASE_FILE="$TMP/pp" bash "$ROOT/scripts/backup.sh" >/dev/null 2>&1; RC=$?
CFG="$(ls "$BK"/config-*.tar.gz.gpg 2>/dev/null | head -1)"
enc_ok() { [ "$RC" -eq 0 ] && [ -f "$CFG" ] && [ -z "$(ls "$BK"/config-*.tar.gz 2>/dev/null)" ]; }
no_plain() { ! grep -q GEHEIMWACHTWOORD "$CFG"; }
readable() { gpg --batch --pinentry-mode loopback --passphrase-file "$TMP/pp" -d "$CFG" 2>/dev/null | tar -xzO secrets.cfg | grep -q GEHEIMWACHTWOORD; }
check "versleuteld config-archief aangemaakt, geen onversleuteld archief over" enc_ok
check "secrets staan niet leesbaar in het archief" no_plain
check "archief terug te lezen met de passphrase" readable
rm -f "$ROOT/server.cfg" "$ROOT/secrets.cfg"

echo "== retentie en lock =="
touch -d '40 days ago' "$BK/db-$DB-20200101-000000.sql.gz" "$BK/db-$DB-20200101-000000.sql.gz.sha256" "$BK/notities.txt"
touch -d '40 days ago' "$BK/db-andere-20200101-000000.sql.gz"
KEEP_DAYS=14 bash "$ROOT/scripts/backup.sh" >/dev/null 2>&1; sleep 1
old_gone() { [ ! -e "$BK/db-$DB-20200101-000000.sql.gz" ]; }
others_kept() { [ -e "$BK/notities.txt" ] && [ -e "$BK/db-andere-20200101-000000.sql.gz" ]; }
check "oude back-up van deze database verwijderd" old_gone
check "vreemde/andere bestanden blijven staan" others_kept
( flock 9; sleep 4 ) 9>"$BK/.backup.lock" & sleep 1
bash "$ROOT/scripts/backup.sh" >/dev/null 2>&1; RC=$?
check "tweede gelijktijdige back-up wordt geweigerd (lock, exit 3)" rc_is 3
wait

echo "== restore =="
$MS $DB -e "DELETE FROM combat_stats; UPDATE rp_gangs SET bank = 0; DROP TABLE admin_bans; CREATE TABLE extra_junk (id INT); INSERT INTO extra_junk VALUES (1);"
SAFE_BEFORE="$(ls "$BK"/pre-restore-* 2>/dev/null | wc -l)"
OUT="$(bash "$ROOT/scripts/restore.sh" "$FILE" --yes 2>&1)"; RC=$?
safe_made() { [ "$(ls "$BK"/pre-restore-* | wc -l)" -gt "$SAFE_BEFORE" ]; }
sums_equal() { [ "$BEFORE" = "$(sums)" ]; }
junk_stays() { [ "$($MS -N -e "SELECT COUNT(*) FROM $DB.extra_junk")" = 1 ]; }
junk_gone() { [ "$($MS -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB' AND table_name='extra_junk'")" = 0 ]; }
wrong_answer() { echo nee | bash "$ROOT/scripts/restore.sh" "$FILE" >/dev/null 2>&1; [ $? -eq 1 ]; }
check "restore slaagt" rc_is 0
check "veiligheidskopie van de huidige staat gemaakt" safe_made
check "alle oorspronkelijke tabellen zijn byte-voor-byte hersteld (CHECKSUM TABLE)" sums_equal
check "tabel die niet in de back-up zat blijft staan zonder --clean" junk_stays
bash "$ROOT/scripts/restore.sh" "$FILE" --yes --clean >/dev/null 2>&1; RC=$?
check "met --clean: restore slaagt" rc_is 0
check "met --clean: extra tabel verdwenen" junk_gone
check "met --clean: data klopt weer (CHECKSUM TABLE)" sums_equal
check "zonder --yes en met verkeerd antwoord wordt niets gedaan" wrong_answer

echo "== beschadigde back-ups raken de database niet aan =="
$MS $DB -e "UPDATE combat_stats SET kills = 999 WHERE identifier = 'license:a'"
KEEP="$($MS -N -e "CHECKSUM TABLE $DB.combat_stats")"
head -c 2000 "$FILE" > "$TMP/afgekapt.sql.gz"
bash "$ROOT/scripts/restore.sh" "$TMP/afgekapt.sql.gz" --yes >/dev/null 2>&1; RC=$?
check "afgekapte back-up geweigerd (exit ≠ 0)" rc_not 0
cp "$FILE" "$TMP/gewijzigd.sql.gz"; cp "$FILE.sha256" "$TMP/gewijzigd.sql.gz.sha256"; sed -i 's/gewijzigd/gewijzigd/' "$TMP/gewijzigd.sql.gz.sha256"
printf 'x' >> "$TMP/gewijzigd.sql.gz"
( cd "$TMP" && sed -i "s#$(basename "$FILE")#gewijzigd.sql.gz#" gewijzigd.sql.gz.sha256 )
bash "$ROOT/scripts/restore.sh" "$TMP/gewijzigd.sql.gz" --yes >/dev/null 2>&1; RC=$?
unchanged() { [ "$($MS -N -e "CHECKSUM TABLE $DB.combat_stats")" = "$KEEP" ]; }
check "back-up met afwijkende checksum geweigerd" rc_is 4
check "database ongewijzigd na mislukte herstelpogingen" unchanged
DB_PASS=fout bash "$ROOT/scripts/restore.sh" "$FILE" --yes >/dev/null 2>&1; RC=$?
check "verkeerd databasewachtwoord: foutmelding" rc_not 0
check "verkeerd databasewachtwoord: niets aangeraakt" unchanged

echo "[test_backup] $PASSED geslaagd, $FAILED mislukt"
[ "$FAILED" -eq 0 ]
