#!/usr/bin/env bash
# Haalt de externe afhankelijkheden op: oxmysql, ox_lib en ESX Legacy (+ benodigde esx_*-resources).
# Gebruik:  ./scripts/install-deps.sh            (laatste releases)
#           ESX_REF=<tag> ./scripts/install-deps.sh   (ESX vastzetten op een tag/branch – aanbevolen voor productie)
# Vereist: bash, curl, unzip, git.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RES="$ROOT/resources"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ESX_REF="${ESX_REF:-main}"

mkdir -p "$RES/[core]" "$RES/[esx]"

fetch_zip() { # naam url doelmap
  local name="$1" url="$2" dest="$3"
  echo ">> $name downloaden"
  curl -fsSL "$url" -o "$TMP/$name.zip"
  rm -rf "${dest:?}/${name:?}"
  unzip -q "$TMP/$name.zip" -d "$TMP/$name-x"
  # releases bevatten meestal één map met de resourcenaam
  if [ -d "$TMP/$name-x/$name" ]; then mv "$TMP/$name-x/$name" "$dest/$name"; else mkdir -p "$dest/$name" && mv "$TMP/$name-x"/* "$dest/$name/"; fi
}

fetch_zip oxmysql "https://github.com/overextended/oxmysql/releases/latest/download/oxmysql.zip" "$RES/[core]"
fetch_zip ox_lib  "https://github.com/overextended/ox_lib/releases/latest/download/ox_lib.zip"   "$RES/[core]"

echo ">> ESX Legacy (esx_core @ $ESX_REF) ophalen"
git clone --quiet --depth 1 --branch "$ESX_REF" https://github.com/esx-framework/esx_core.git "$TMP/esx_core" \
  || git clone --quiet --depth 1 https://github.com/esx-framework/esx_core.git "$TMP/esx_core"

CORE_DIR="$TMP/esx_core/[core]"
[ -d "$CORE_DIR" ] || CORE_DIR="$TMP/esx_core"

rm -rf "$RES/[core]/es_extended"
if [ -d "$CORE_DIR/es_extended" ]; then cp -r "$CORE_DIR/es_extended" "$RES/[core]/es_extended"; else echo "!! es_extended niet gevonden in esx_core"; exit 1; fi

# Resources die onze server nodig heeft (zie server.cfg.example). Eerst in esx_core, anders los repo.
NEEDED=(esx_menu_default esx_menu_dialog esx_menu_list skinchanger esx_skin esx_identity esx_addonaccount \
        esx_addoninventory esx_datastore esx_society esx_status esx_basicneeds esx_license)
MISSING=()
for r in "${NEEDED[@]}"; do
  rm -rf "$RES/[esx]/$r"
  found="$(find "$TMP/esx_core" -maxdepth 3 -type d -name "$r" -print -quit || true)"
  if [ -n "$found" ]; then
    cp -r "$found" "$RES/[esx]/$r"
  elif git clone --quiet --depth 1 "https://github.com/esx-framework/$r.git" "$RES/[esx]/$r" 2>/dev/null; then
    rm -rf "$RES/[esx]/$r/.git"
  else
    MISSING+=("$r")
  fi
done

echo
echo "Klaar. Geïnstalleerd in resources/[core] en resources/[esx]."
if [ ${#MISSING[@]} -gt 0 ]; then
  echo "!! Niet automatisch gevonden (installeer handmatig of pas server.cfg aan): ${MISSING[*]}"
fi
echo "Volgende stap: database aanmaken en ./scripts/import-sql.sh draaien."
