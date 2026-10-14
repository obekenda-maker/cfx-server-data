#!/usr/bin/env bash
# Maakt een back-up van de database (en optioneel de serverconfiguratie).
#
#   DB_USER=esx_nl DB_PASS=... DB_NAME=esx_nl ./scripts/backup.sh
#
# Omgevingsvariabelen:
#   DB_HOST (127.0.0.1)  DB_PORT (3306)  DB_USER*  DB_PASS*  DB_NAME*
#   BACKUP_DIR   (./backups)        map voor de back-ups (wordt aangemaakt, rechten 700)
#   KEEP_DAYS    (14)               back-ups van dit script ouder dan zoveel dagen worden verwijderd (0 = nooit)
#   INCLUDE_CONFIG=1                server.cfg (+ secrets.cfg als INCLUDE_SECRETS=1) meenemen in een apart archief
#   INCLUDE_SECRETS=1               secrets.cfg meenemen – ALLEEN samen met BACKUP_PASSPHRASE_FILE (versleuteld)
#   BACKUP_PASSPHRASE_FILE=<pad>    bestand met wachtwoord; archief wordt dan met gpg (AES256) versleuteld
# Het wachtwoord gaat via MYSQL_PWD (niet via een argument, dus niet zichtbaar in `ps`).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${DB_USER:?DB_USER ontbreekt}" "${DB_PASS:?DB_PASS ontbreekt}" "${DB_NAME:?DB_NAME ontbreekt}"
DB_HOST="${DB_HOST:-127.0.0.1}"; DB_PORT="${DB_PORT:-3306}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT/backups}"; KEEP_DAYS="${KEEP_DAYS:-14}"
DUMP="$(command -v mariadb-dump || command -v mysqldump || true)"
[ -n "$DUMP" ] || { echo "FOUT: mariadb-dump/mysqldump niet gevonden" >&2; exit 2; }
export MYSQL_PWD="$DB_PASS"

umask 077
mkdir -p "$BACKUP_DIR"; chmod 700 "$BACKUP_DIR"
exec 9>"$BACKUP_DIR/.backup.lock"
flock -n 9 || { echo "FOUT: er draait al een back-up" >&2; exit 3; }

TS="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/db-$DB_NAME-$TS.sql.gz"
TMP="$OUT.partial"
trap 'rm -f "$TMP"' EXIT

echo ">> Database '$DB_NAME' dumpen..."
"$DUMP" -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" \
  --single-transaction --quick --routines --triggers --events --no-tablespaces \
  --default-character-set=utf8mb4 --add-drop-table "$DB_NAME" | gzip -9 > "$TMP"

# Controle: heel gzip-bestand leesbaar en dump is volledig afgerond
gzip -t "$TMP" || { echo "FOUT: gzip-controle mislukt" >&2; exit 4; }
zcat "$TMP" | tail -n 3 | grep -q "Dump completed" || { echo "FOUT: dump lijkt onvolledig (geen 'Dump completed')" >&2; exit 4; }
TABLES="$(zcat "$TMP" | grep -c '^CREATE TABLE')"
[ "$TABLES" -gt 0 ] || { echo "FOUT: dump bevat geen tabellen" >&2; exit 4; }

mv "$TMP" "$OUT"
( cd "$BACKUP_DIR" && sha256sum "$(basename "$OUT")" > "$(basename "$OUT").sha256" )
echo "   OK: $OUT ($(du -h "$OUT" | cut -f1), $TABLES tabellen)"

if [ "${INCLUDE_CONFIG:-0}" = "1" ]; then
  FILES=()
  [ -f "$ROOT/server.cfg" ] && FILES+=("server.cfg")
  if [ "${INCLUDE_SECRETS:-0}" = "1" ]; then
    [ -n "${BACKUP_PASSPHRASE_FILE:-}" ] || { echo "FOUT: INCLUDE_SECRETS=1 vereist BACKUP_PASSPHRASE_FILE (secrets nooit onversleuteld bewaren)" >&2; exit 5; }
    [ -f "$ROOT/secrets.cfg" ] && FILES+=("secrets.cfg")
  fi
  if [ ${#FILES[@]} -gt 0 ]; then
    CFG="$BACKUP_DIR/config-$TS.tar.gz"
    tar -C "$ROOT" -czf "$CFG" "${FILES[@]}"
    if [ -n "${BACKUP_PASSPHRASE_FILE:-}" ]; then
      gpg --batch --yes --pinentry-mode loopback --passphrase-file "$BACKUP_PASSPHRASE_FILE" --symmetric --cipher-algo AES256 -o "$CFG.gpg" "$CFG"
      shred -u "$CFG" 2>/dev/null || rm -f "$CFG"
      echo "   OK (versleuteld): $CFG.gpg"
    else
      echo "   OK: $CFG  (bevat GEEN secrets.cfg)"
    fi
  fi
fi

if [ "$KEEP_DAYS" -gt 0 ]; then
  find "$BACKUP_DIR" -maxdepth 1 -type f \( -name "db-$DB_NAME-*.sql.gz" -o -name "db-$DB_NAME-*.sql.gz.sha256" -o -name "config-*.tar.gz*" \) -mtime +"$KEEP_DAYS" -print -delete | sed 's/^/   verwijderd (ouder dan '"$KEEP_DAYS"' dagen): /'
fi
echo "Klaar."
