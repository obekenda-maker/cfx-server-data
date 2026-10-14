#!/usr/bin/env bash
# Importeert ESX-SQL (es_extended/esx_*) en onze eigen SQL (sql/01..03) in de database.
# Gebruik:  DB_HOST=127.0.0.1 DB_USER=esx_nl DB_PASS=... DB_NAME=esx_nl ./scripts/import-sql.sh
# Het wachtwoord gaat via MYSQL_PWD (niet in de procestabel als argument).
#
# Exitcode: 0 = alles gelukt (meldingen "bestaat al" bij een herhaalde import zijn normaal),
#           1 = één of meer bestanden gaven een echte fout, 5 = geen databaseverbinding.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${DB_USER:?DB_USER ontbreekt}" "${DB_PASS:?DB_PASS ontbreekt}" "${DB_NAME:?DB_NAME ontbreekt}"
DB_HOST="${DB_HOST:-127.0.0.1}"; DB_PORT="${DB_PORT:-3306}"
export MYSQL_PWD="$DB_PASS"
CLIENT="$(command -v mariadb || command -v mysql || true)"
[ -n "$CLIENT" ] || { echo "FOUT: mariadb/mysql-client niet gevonden" >&2; exit 2; }
sql() { "$CLIENT" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" --default-character-set=utf8mb4 "$@"; }

sql -e "SELECT 1" "$DB_NAME" >/dev/null 2>&1 || { echo "FOUT: geen verbinding met database '$DB_NAME' op $DB_HOST:$DB_PORT (gebruiker/wachtwoord/naam controleren). Niets geïmporteerd." >&2; exit 5; }

ERRORS=0; FILES=0
run() { # bestand
  echo ">> $1"
  FILES=$((FILES+1))
  local out rc errs
  # es_extended.sql begint met CREATE DATABASE `es_extended` + USE: dat zou de tabellen in een andere database zetten.
  # Alles tot en met de USE-regel wordt weggelaten, zodat ze in DB_NAME terechtkomen.
  if [ "$(basename "$1")" = "es_extended.sql" ] && grep -q '^USE ' "$1"; then
    out="$(sed '1,/^USE /d' "$1" | sql "$DB_NAME" 2>&1)"; rc=$?
  else
    out="$(sql "$DB_NAME" < "$1" 2>&1)"; rc=$?
  fi
  if [ "$rc" -ne 0 ]; then
    # Alleen de ERROR-regels beoordelen: de echo van de SQL zelf (bv. "ON DUPLICATE KEY UPDATE") telt niet mee.
    errs="$(printf '%s\n' "$out" | grep -E '^ERROR')"
    if [ -n "$errs" ] && ! printf '%s\n' "$errs" | grep -qvE "already exists|Duplicate (column name|key name|entry)|Multiple primary key"; then
      echo "   (melding 'bestaat al' – normaal bij een herhaalde import)"
    else
      echo "   FOUT: $out" >&2
      ERRORS=$((ERRORS+1))
    fi
  fi
}
# 1) ESX-tabellen (volgorde: es_extended eerst)
for f in "$ROOT"/resources/\[core\]/es_extended/*.sql; do [ -f "$f" ] && run "$f"; done
for f in "$ROOT"/resources/\[esx\]/*/*.sql "$ROOT"/resources/\[esx\]/*/sql/*.sql; do [ -f "$f" ] && run "$f"; done
# 2) Onze tabellen, jobs/salarissen/items en societies
for f in 01_core 02_jobs_items 03_societies; do run "$ROOT/sql/$f.sql"; done

if [ "$ERRORS" -gt 0 ]; then
  echo "KLAAR MET $ERRORS FOUT(EN) in $FILES bestand(en). Los die op en importeer opnieuw (veilig om te herhalen)." >&2
  exit 1
fi
echo "Klaar: $FILES bestand(en) geïmporteerd zonder fouten."
