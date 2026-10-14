#!/usr/bin/env bash
# Herstelt de database uit een back-up van scripts/backup.sh.
#
#   DB_USER=esx_nl DB_PASS=... DB_NAME=esx_nl ./scripts/restore.sh backups/db-esx_nl-20260101-030000.sql.gz [--yes] [--clean]
#
# Veiligheid:
#   * controleert eerst checksum (.sha256) en gzip-integriteit; bij een fout wordt NIETS aangeraakt
#   * maakt eerst een veiligheidskopie van de HUIDIGE database (backups/pre-restore-*.sql.gz)
#   * vraagt bevestiging (typ JA), tenzij --yes
#   * --clean verwijdert eerst ALLE tabellen in de database (anders blijven tabellen die niet in de back-up staan bestaan)
# STOP DE GAMESERVER vóór een herstel (anders schrijft hij tegelijk naar de database).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILE="${1:-}"; shift || true
YES=0; CLEAN=0
for a in "$@"; do case "$a" in --yes) YES=1;; --clean) CLEAN=1;; *) echo "Onbekende optie: $a" >&2; exit 2;; esac; done
[ -f "$FILE" ] || { echo "Gebruik: $0 <back-upbestand.sql.gz> [--yes] [--clean]" >&2; exit 2; }
: "${DB_USER:?DB_USER ontbreekt}" "${DB_PASS:?DB_PASS ontbreekt}" "${DB_NAME:?DB_NAME ontbreekt}"
DB_HOST="${DB_HOST:-127.0.0.1}"; DB_PORT="${DB_PORT:-3306}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT/backups}"
CLIENT="$(command -v mariadb || command -v mysql || true)"
DUMP="$(command -v mariadb-dump || command -v mysqldump || true)"
if [ -z "$CLIENT" ] || [ -z "$DUMP" ]; then echo "FOUT: mariadb/mysql-client niet gevonden" >&2; exit 2; fi
export MYSQL_PWD="$DB_PASS"
sql() { "$CLIENT" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" "$@"; }

echo ">> Back-up controleren: $FILE"
if [ -f "$FILE.sha256" ]; then
  ( cd "$(dirname "$FILE")" && sha256sum -c "$(basename "$FILE").sha256" >/dev/null ) || { echo "FOUT: checksum klopt niet – back-up is beschadigd. Niets aangeraakt." >&2; exit 4; }
  echo "   checksum OK"
else
  echo "   (geen .sha256-bestand; alleen gzip-controle)"
fi
gzip -t "$FILE" || { echo "FOUT: gzip-bestand beschadigd. Niets aangeraakt." >&2; exit 4; }
zcat "$FILE" | tail -n 3 | grep -q "Dump completed" || { echo "FOUT: back-up is onvolledig. Niets aangeraakt." >&2; exit 4; }
sql -e "SELECT 1" >/dev/null || { echo "FOUT: geen verbinding met de database. Niets aangeraakt." >&2; exit 5; }

echo
echo "LET OP: dit overschrijft de gegevens in database '$DB_NAME' op $DB_HOST met de inhoud van de back-up."
echo "        Is de gameserver GESTOPT? (Nu doorgaan terwijl hij draait geeft inconsistente data.)"
[ "$CLEAN" = "1" ] && echo "        --clean: ALLE bestaande tabellen worden eerst verwijderd."
if [ "$YES" != "1" ]; then
  read -r -p "Typ JA om door te gaan: " ANSWER
  [ "$ANSWER" = "JA" ] || { echo "Afgebroken."; exit 1; }
fi

umask 077; mkdir -p "$BACKUP_DIR"
SAFE="$BACKUP_DIR/pre-restore-$DB_NAME-$(date +%Y%m%d-%H%M%S).sql.gz"
echo ">> Veiligheidskopie van de huidige database: $SAFE"
"$DUMP" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" --single-transaction --quick --routines --triggers --events --no-tablespaces --default-character-set=utf8mb4 "$DB_NAME" | gzip -9 > "$SAFE"
gzip -t "$SAFE"

if [ "$CLEAN" = "1" ]; then
  echo ">> Bestaande tabellen verwijderen (--clean)..."
  { echo "SET FOREIGN_KEY_CHECKS=0;"; sql -N -e "SELECT CONCAT('DROP TABLE IF EXISTS \`', table_name, '\`;') FROM information_schema.tables WHERE table_schema = '$DB_NAME'"; echo "SET FOREIGN_KEY_CHECKS=1;"; } | sql "$DB_NAME"
fi

echo ">> Herstellen..."
zcat "$FILE" | sql "$DB_NAME"

echo ">> Controle na herstel:"
TABLES="$(sql -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_NAME'")"
echo "   $TABLES tabellen in '$DB_NAME'"
for t in users owned_vehicles combat_stats rp_gangs rp_gang_members rp_gang_territories admin_bans admin_warnings server_rules_accepted; do
  n="$(sql -N -e "SELECT COUNT(*) FROM \`$t\`" "$DB_NAME" 2>/dev/null || echo '-')"
  printf "   %-24s %s rijen\n" "$t" "$n"
done
echo "Klaar. Start de gameserver weer. Bij problemen: herstel de veiligheidskopie $SAFE"
