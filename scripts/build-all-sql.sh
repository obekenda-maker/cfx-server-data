#!/usr/bin/env bash
# Voegt alle SQL (ESX-basis, esx_*-addons en onze sql/01..03) samen in ÉÉN bestand voor hosts zonder shell
# (phpMyAdmin / paneel-import). Gebruik:  ./scripts/build-all-sql.sh [uitvoerbestand]   (standaard: sql/ALL_IN_ONE.sql)
# Importeer het in een LEGE database (de gebruikers-database van je host). Het bestand maakt geen database aan.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/sql/ALL_IN_ONE.sql}"
{
  echo "-- ALL_IN_ONE.sql – gegenereerd door scripts/build-all-sql.sh. Importeer in een LEGE database."
  echo "SET NAMES utf8mb4;"
  f="$ROOT/resources/[core]/es_extended/es_extended.sql"
  if [ -f "$f" ]; then
    echo "-- == es_extended =="
    if grep -q '^USE ' "$f"; then sed '1,/^USE /d' "$f"; else cat "$f"; fi
  else
    echo "-- LET OP: es_extended.sql ontbrak tijdens het samenstellen" >&2
  fi
  for f in "$ROOT"/resources/\[esx\]/*/*.sql "$ROOT"/resources/\[esx\]/*/sql/*.sql; do
    [ -f "$f" ] || continue
    echo; echo "-- == $(basename "$(dirname "$f")")/$(basename "$f") =="
    cat "$f"
  done
  for n in 01_core 02_jobs_items 03_societies; do
    echo; echo "-- == sql/$n.sql =="
    cat "$ROOT/sql/$n.sql"
  done
} > "$OUT"
echo "Geschreven: $OUT ($(wc -l < "$OUT") regels)"
