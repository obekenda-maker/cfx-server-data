#!/usr/bin/env python3
"""NUI-test: laadt de echte server_hud in headless Chromium (Playwright) en controleert gedrag/XSS/fouten.
Wordt overgeslagen (exit 0, melding) als Playwright of Chromium ontbreekt."""
import json, os, pathlib, shutil, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
pw = next((p for p in ("/opt/node22/lib/node_modules/playwright", "/usr/lib/node_modules/playwright") if os.path.isdir(p)), None)
chromium = next((str(p) for p in pathlib.Path("/opt/pw-browsers").glob("chromium-*/chrome-linux/chrome")), shutil.which("chromium"))
if not pw or not chromium:
    print("OVERGESLAGEN: Playwright/Chromium niet beschikbaar")
    sys.exit(0)

env = dict(os.environ, PLAYWRIGHT_MODULE=pw, CHROMIUM=chromium)
out = subprocess.run(["node", str(ROOT / "tests/nui_runner.cjs"), str(ROOT / "resources/[ui]/server_hud/web")],
                     capture_output=True, text=True, env=env, timeout=120)
if out.returncode != 0:
    print("NODE FOUT:", out.stderr[-800:]); sys.exit(1)
r = json.loads(out.stdout.strip().splitlines()[-1])

checks = [
    ("ready-bericht naar Lua gestuurd", r["readyPosted"]),
    ("positie-klasse uit config", "pos-top-left" in r["positionClass"]),
    ("kleur uit config", r["primaryVar"] == "#123456"),
    ("geld geformatteerd/afgerond", r["cash"].startswith("€1.250")),
    ("ontbrekende bank → €0", r["bank"] == "€0"),
    ("ontbrekende job → fallback", r["job"] == "Werkloos"),
    ("health >100 begrensd op 100", r["healthClamped"] == "100"),
    ("honger zonder waarde verborgen", r["hungerHidden"]),
    ("achteruit = R", r["gearReverse"] == "R"),
    ("brandstof met %", r["fuelText"] == "50%"),
    ("munitie", r["ammo"] == "7/30"),
    ("lage dorst pulseert", r["thirstLow"]),
    ("HUD verborgen bij pauzemenu", r["dimmed"]),
    ("killfeed begrensd op killfeedMax=3", r["killfeedCount"] == 3),
    ("geen HTML-injectie via namen (XSS)", r["injectedElements"] == 0 and r["xss"] == 0),
    ("suicide-tekst", "Mo is uitgeschakeld (Val)" in r["lastFeed"]),
    ("combat-paneel zichtbaar + K/D", r["combatVisible"] and r["kd"] == "4.00"),
    ("zonenaam als tekst (geen HTML)", r["zoneEscaped"] == 0),
    ("teamstanden", "Rood 3" in r["scoresText"] and "Blauw 0" in r["scoresText"]),
    ("combat-paneel verdwijnt", r["combatHidden"]),
    ("beschermingsbalk", r["protectShown"]),
    ("doodsoverlay", r["deathShown"]),
    ("leaderboard-rij + naam als tekst", r["boardRows"] == 1 and r["boardEscaped"] == 0),
    ("leeg leaderboard toont melding", r["boardEmptyShown"]),
    ("geen JS-fouten in de console", r["errors"] == []),
]
bad = [n for n, ok in checks if not ok]
for n, ok in checks: print(("  ✓ " if ok else "  ✗ ") + n)
if r["errors"]: print("  fouten:", r["errors"])
print(f"[test_nui] {len(checks) - len(bad)} geslaagd, {len(bad)} mislukt")
sys.exit(1 if bad else 0)
