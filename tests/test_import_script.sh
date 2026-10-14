#!/usr/bin/env bash
# Test scripts/import-sql.sh met een nagebootste ESX-installatie (tests/esx_stub.sql) tegen de lokale MariaDB.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MS="mariadb --default-character-set=utf8mb4 -uroot"; command -v mariadb >/dev/null || MS="mysql --default-character-set=utf8mb4 -uroot"
DB=cfx_imp; PASS='Imp0rt-Test!'; U=imp_user
TMP="$(mktemp -d)"; PASSED=0; FAILED=0
ok() { PASSED=$((PASSED+1)); echo "  ✓ $1"; }; fail() { FAILED=$((FAILED+1)); echo "  ✗ $1"; }
check() { local n="$1"; shift; if "$@"; then ok "$n"; else fail "$n"; fi; }
trap '$MS -e "DROP DATABASE IF EXISTS $DB; DROP USER IF EXISTS \"$U\"@\"127.0.0.1\"" 2>/dev/null; rm -rf "$TMP"' EXIT

# nagebootste installatie: scripts + sql + "ESX" met de stub-SQL
mkdir -p "$TMP/scripts" "$TMP/sql" "$TMP/resources/[core]/es_extended" "$TMP/resources/[esx]/esx_society/sql"
cp "$ROOT"/scripts/import-sql.sh "$TMP/scripts/"; cp "$ROOT"/sql/*.sql "$TMP/sql/"
cp "$ROOT/tests/esx_stub.sql" "$TMP/resources/[core]/es_extended/legacy.sql"
echo "CREATE TABLE IF NOT EXISTS esx_extra (id INT PRIMARY KEY);" > "$TMP/resources/[esx]/esx_society/sql/extra.sql"

$MS -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB CHARACTER SET utf8mb4; CREATE USER '$U'@'127.0.0.1' IDENTIFIED BY '$PASS'; GRANT ALL ON $DB.* TO '$U'@'127.0.0.1'; FLUSH PRIVILEGES;" || { echo "geen MariaDB"; exit 1; }
export DB_HOST=127.0.0.1 DB_USER=$U DB_PASS=$PASS DB_NAME=$DB

OUT="$(bash "$TMP/scripts/import-sql.sh" 2>&1)"; RC=$?
tables() { $MS -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB'"; }
has() { [ "$($MS -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$DB' AND table_name='$1'")" = 1 ]; }
check "import-script eindigt met exit 0" [ "$RC" -eq 0 ]
for t in owned_vehicles jobs job_grades items esx_extra combat_stats combat_kill_log rp_gangs rp_gang_members rp_gang_territories rp_cooldowns admin_bans admin_warnings server_log_entries server_rules_accepted addon_account; do
  check "tabel $t aanwezig" has "$t"
done
check "jobs uit de catalogus geïmporteerd" [ "$($MS -N -e "SELECT COUNT(*) FROM $DB.jobs")" = 9 ]
check "items geïmporteerd" [ "$($MS -N -e "SELECT COUNT(*) FROM $DB.items WHERE name IN ('medkit','repairkit','lockpick','schroot')")" = 4 ]
T1="$(tables)"; G1="$($MS -N -e "SELECT COUNT(*) FROM $DB.job_grades")"
bash "$TMP/scripts/import-sql.sh" >/dev/null 2>&1; RC=$?
check "tweede import (idempotent): exit 0" [ "$RC" -eq 0 ]
check "tweede import: zelfde aantal tabellen en grades (geen dubbele data)" [ "$(tables)" = "$T1" ] && [ "$($MS -N -e "SELECT COUNT(*) FROM $DB.job_grades")" = "$G1" ]
check "wachtwoord niet in de uitvoer" bash -c "! printf '%s' \"\$1\" | grep -qF \"\$2\"" _ "$OUT" "$PASS"
DB_PASS=fout bash "$TMP/scripts/import-sql.sh" >/dev/null 2>&1; RC=$?
check "verkeerd wachtwoord: exit 5 (geen schijn-succes)" [ "$RC" -eq 5 ]
DB_NAME=bestaat_niet bash "$TMP/scripts/import-sql.sh" >/dev/null 2>&1; RC=$?
check "onbekende database: exit 5" [ "$RC" -eq 5 ]
check "zonder DB_NAME stopt het script direct" bash -c "! env -u DB_NAME DB_USER=x DB_PASS=y bash '$TMP/scripts/import-sql.sh' >/dev/null 2>&1"
echo "SELECT kapotte syntax FROM;" > "$TMP/sql/04_kapot.sql"
cp "$TMP/sql/04_kapot.sql" "$TMP/sql/03_societies.sql"
bash "$TMP/scripts/import-sql.sh" >/dev/null 2>&1; RC=$?
check "een echt kapot SQL-bestand geeft exit 1" [ "$RC" -eq 1 ]
echo "[test_import_script] $PASSED geslaagd, $FAILED mislukt"
[ "$FAILED" -eq 0 ]
