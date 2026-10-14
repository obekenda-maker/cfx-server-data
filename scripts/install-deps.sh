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
ESX_REF="${ESX_REF:-1.13.5}"
ADDONS_REF="${ADDONS_REF:-v1.14.0}"
OXLIB_VER="${OXLIB_VER:-v3.39.0}"
OXMYSQL_VER="${OXMYSQL_VER:-v2.14.1}"

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

fetch_zip oxmysql "https://github.com/overextended/oxmysql/releases/download/$OXMYSQL_VER/oxmysql.zip" "$RES/[core]"
fetch_zip ox_lib  "https://github.com/overextended/ox_lib/releases/download/$OXLIB_VER/ox_lib.zip"   "$RES/[core]"

echo ">> ESX Legacy (esx_core @ $ESX_REF) ophalen"
git clone --quiet --depth 1 --branch "$ESX_REF" https://github.com/esx-framework/esx_core.git "$TMP/esx_core" \
  || git clone --quiet --depth 1 https://github.com/esx-framework/esx_core.git "$TMP/esx_core"

CORE_DIR="$TMP/esx_core/[core]"
[ -d "$CORE_DIR" ] || CORE_DIR="$TMP/esx_core"

rm -rf "$RES/[core]/es_extended"
if [ -d "$CORE_DIR/es_extended" ]; then cp -r "$CORE_DIR/es_extended" "$RES/[core]/es_extended"; else echo "!! es_extended niet gevonden in esx_core"; exit 1; fi

# Resources die onze server nodig heeft (zie server.cfg.example): menu/skin/identity/cron komen uit esx_core,
# de esx_*-addons uit het losse repo esx_addons (tag moet bij ESX_REF passen).
echo ">> esx_addons @ $ADDONS_REF ophalen"
git clone --quiet --depth 1 --branch "$ADDONS_REF" https://github.com/esx-framework/esx_addons.git "$TMP/esx_addons"
CORE_NEEDED=(cron esx_menu_default esx_menu_dialog esx_menu_list skinchanger esx_skin esx_identity)
ADDON_NEEDED=(esx_addonaccount esx_addoninventory esx_datastore esx_society esx_status esx_basicneeds esx_license)
MISSING=()
for r in "${CORE_NEEDED[@]}"; do
  rm -rf "$RES/[esx]/$r"
  if [ -d "$CORE_DIR/$r" ]; then cp -r "$CORE_DIR/$r" "$RES/[esx]/$r"; else MISSING+=("$r"); fi
done
for r in "${ADDON_NEEDED[@]}"; do
  rm -rf "$RES/[esx]/$r"
  found="$(find "$TMP/esx_addons" -maxdepth 3 -type d -name "$r" -print -quit || true)"
  if [ -n "$found" ]; then cp -r "$found" "$RES/[esx]/$r"; else MISSING+=("$r"); fi
done
for d in "$RES"/[[]core[]]/* "$RES"/[[]esx[]]/*; do
  [ -d "$d" ] && [ ! -f "$d/fxmanifest.lua" ] && MISSING+=("$(basename "$d") (zonder fxmanifest.lua)")
done


# ---- ESX-economie-instellingen (bewust aangepast; staan zo in de ESX-config) -----------------
# Startgeld: 500 contant + 2500 bank (ESX-standaard is 50.000 bank). Salaris elke 30 min (ESX-standaard 7 min).
# Past alleen aan als de standaardregel nog onaangeroerd is. Pas gerust zelf aan in resources/[core]/es_extended/shared/config/main.lua.
ESXCFG="$RES/[core]/es_extended/shared/config/main.lua"
if [ -f "$ESXCFG" ]; then
  sed -i 's/^Config.StartingAccountMoney = { bank = 50000 }/Config.StartingAccountMoney = { money = 500, bank = 2500 }/' "$ESXCFG"
  sed -i 's/^Config.PaycheckInterval = 7 \* 60000/Config.PaycheckInterval = 30 * 60000/' "$ESXCFG"
  grep -E '^Config\.(StartingAccountMoney|PaycheckInterval)' "$ESXCFG" | sed 's/^/   ESX-config: /'
fi

echo
echo "Klaar. Geïnstalleerd in resources/[core] en resources/[esx]."
if [ ${#MISSING[@]} -gt 0 ]; then
  echo "!! Niet automatisch gevonden (installeer handmatig of pas server.cfg aan): ${MISSING[*]}"
fi
echo "Volgende stap: database aanmaken en ./scripts/import-sql.sh draaien."
