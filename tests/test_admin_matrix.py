#!/usr/bin/env python3
"""Rechtenmatrix: elke beheeractie × rol (echt uitgevoerd in de Lua-servercode). Vergelijkt met ServerCfg.Admin en
schrijft docs/ADMIN_RECHTEN.md."""
import json, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lib_runtime import ROOT, build_db, make_runtime
from lib_config import load, cfg

lua = make_runtime(build_db())
lua.execute((ROOT / "tests" / "admin_matrix.lua").read_text(encoding="utf-8"))
M = json.loads(lua.globals().MATRIX_JSON)
A = cfg(load(), "ServerCfg")["Admin"]
level = {"user": 0, "console": 99, **A["groups"]}
errors = []
for row in M["rows"]:
    need = row["need"]
    if need == "super": min_level, label = A["groups"]["superadmin"], "alleen superadmin/console"
    elif need == "permban": min_level, label = A["permBanLevel"], f"niveau ≥ {A['permBanLevel']}"
    else: min_level, label = A["levels"][need], f"niveau ≥ {A['levels'][need]}"
    row["label"] = label
    for role, res in row["results"].items():
        if res == "n.v.t.": continue
        expected = "ja" if level[role] >= min_level else "nee"
        if res != expected:
            errors.append(f"'{row['id']}' als {role}: uitgevoerd={res}, verwacht={expected} ({label})")
    if not row["results"]["user"] == "nee": errors.append(f"'{row['id']}': gewone speler kan dit uitvoeren!")
    if row["logged"] is None or row["logged"] is False:
        if row["id"] not in ("menu: spelerslijst", "/coords (rechtencheck)", "warnings", "checkplayer"):
            if row["id"] not in ("warnings",): errors.append(f"'{row['id']}': uitgevoerde actie is niet gelogd in kanaal 'admin'")

icon = {"ja": "✅", "nee": "⛔", "n.v.t.": "–"}
roles = M["roles"]
md = ["# Adminrechten – matrix (gegenereerd en getest)", "",
      "*Gegenereerd door `python3 tests/test_admin_matrix.py`: elke actie is **echt uitgevoerd** in de serverlogica als elke rol en de uitkomst is vergeleken met `ServerCfg.Admin`.*", "",
      "✅ = actie uitgevoerd • ⛔ = geweigerd (geen effect) • – = niet van toepassing", "",
      "| Actie | Vereist | " + " | ".join(roles) + " |", "|---|---|" + "---|" * len(roles)]
for row in M["rows"]:
    md.append(f"| `{row['id']}` | {row['label']} | " + " | ".join(icon.get(row['results'][r], row['results'][r]) for r in roles) + " |")
md += ["", "## Hoe rechten worden bepaald", "",
       f"* Rechten volgen de **ESX-groep** van de speler (`users.group`): `user`=0, " + ", ".join(f"`{g}`={v}" for g, v in sorted(A['groups'].items(), key=lambda x: x[1])) + ", serverconsole=99.",
       "* Eerste beheerder maak je in de **serverconsole**: `setgroup <id> superadmin`. Rechten per actie staan in `ServerCfg.Admin.levels`.",
       f"* Permanente bans: niveau ≥ {A['permBanLevel']} (`permBanLevel`). Tijdelijke bans maximaal {A['maxBanHours']} uur. Automatische ban na {A['warnBanThreshold']} waarschuwingen ({A['warnBanHours']} uur).",
       "* **Elke** actie controleert de rechten opnieuw op de server; het adminmenu in het spel is alleen een scherm. Menu-callbacks (`admin_tools:*`) controleren per actie het vereiste niveau.",
       "* Elke uitgevoerde beheeractie wordt gelogd in het Discord-kanaal `admin` en in de tabel `server_log_entries`.", "",
       "## Let op: ESX-eigen commando's", "",
       "Naast deze tools heeft ESX zelf commando's (`/setjob`, `/setgroup`, `/giveaccountmoney`, `/car`, `/giveweapon`, …). Die zijn **niet** door onze code beperkt:",
       "ze volgen de ESX-instellingen van jouw versie (meestal groep `admin` en `superadmin`). Geef de groep `admin` dus alleen aan vertrouwde beheerders; `mod` krijgt via deze server alleen kick/warn/check/revive/teleport-naar.",
       "Controleer in jouw ESX-versie welke groepen toegang hebben tot geld- en item-commando's (zoek in `es_extended` naar `ESX.RegisterCommand`).", ""]
(ROOT / "docs" / "ADMIN_RECHTEN.md").write_text("\n".join(md), encoding="utf-8")
for e in errors: print("FOUT:", e)
print(f"rechtenmatrix: {len(M['rows'])} acties × {len(roles)} rollen, {len(errors)} fout(en); docs/ADMIN_RECHTEN.md geschreven")
sys.exit(1 if errors else 0)
