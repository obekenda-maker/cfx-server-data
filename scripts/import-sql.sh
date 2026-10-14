#!/usr/bin/env bash
# Importeert ESX-SQL (es_extended/esx_*) en onze eigen SQL (sql/01..03) in de database.
# Gebruik:  DB_HOST=127.0.0.1 DB_USER=esx_nl DB_PASS=... DB_NAME=esx_nl ./scripts/import-sql.sh
# Het wachtwoord gaat via MYSQL_PWD (niet in de procestabel als argument).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${DB_USER:?DB_USER ontbreekt}" "${DB_PASS:?DB_PASS ontbreekt}" "${DB_NAME:?DB_NAME ontbreekt}"
DB_HOST="${DB_HOST:-127.0.0.1}"
export MYSQL_PWD="$DB_PASS"
CLIENT="$(command -v mariadb || command -v mysql)"
run() { # bestand
  echo ">> $1"
  "$CLIENT" -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" < "$1" || echo "   (waarschuwing: fouten in $1 – meestal 'bestaat al')"
}
# 1) ESX-tabellen (volgorde: es_extended eerst)
for f in "$ROOT"/resources/\[core\]/es_extended/*.sql; do [ -f "$f" ] && run "$f"; done
for f in "$ROOT"/resources/\[esx\]/*/*.sql "$ROOT"/resources/\[esx\]/*/sql/*.sql; do [ -f "$f" ] && run "$f"; done
# 2) Onze tabellen, jobs/salarissen/items en societies
for f in 01_core 02_jobs_items 03_societies; do run "$ROOT/sql/$f.sql"; done
echo "Klaar."
