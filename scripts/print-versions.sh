#!/usr/bin/env bash
# Toont de versie van elke geïnstalleerde resource (uit fxmanifest.lua) + databaseversie.
# Handig om na installatie vast te leggen waartegen jouw server draait (en om te pinnen).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
printf "%-22s %-12s %s\n" RESOURCE VERSIE MAP
find "$ROOT/resources" -name fxmanifest.lua -o -name __resource.lua 2>/dev/null | sort | while read -r m; do
  d="$(dirname "$m")"; n="$(basename "$d")"
  v="$(grep -oiE "^\s*version\s+['\"][^'\"]+['\"]" "$m" | head -1 | sed -E "s/.*['\"]([^'\"]+)['\"].*/\1/")"
  printf "%-22s %-12s %s\n" "$n" "${v:--}" "${d#$ROOT/}"
done
echo
CLIENT="$(command -v mariadb || command -v mysql || true)"
[ -n "$CLIENT" ] && "$CLIENT" --version || echo "(geen mysql/mariadb-client gevonden)"
