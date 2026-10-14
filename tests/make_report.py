#!/usr/bin/env python3
"""Draait alle controles en schrijft de ECHTE uitvoer samengevat naar docs/TESTRESULTATEN.md."""
import datetime, pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
T = ROOT / "tests"
steps = [
    ("Lua/JS-syntaxis", "syntax_check.py"), ("Statische analyse (luacheck)", "check_lint.py"),
    ("Manifesten + startvolgorde", "check_manifests.py"), ("Kruisverwijzingen (exports/events/callbacks)", "check_crossrefs.py"),
    ("Tekstsleutels (NL)", "check_locale.py"), ("Geheimen-scan", "check_secrets.py"), ("SQL-import (2×, MariaDB)", "test_sql.py"),
    ("Lua-servertests", "run_tests.py"), ("Herstart-persistentie", "test_restart.py"), ("NUI in Chromium", "test_nui.py"),
]
rows, detail, ok_all = [], [], True
for name, script in steps:
    r = subprocess.run([sys.executable, str(T / script)], capture_output=True, text=True)
    out = (r.stdout + r.stderr)
    ok = r.returncode == 0
    ok_all &= ok
    summary = ""
    if script == "run_tests.py" or script == "test_restart.py":
        parts = re.findall(r"\[([^\]]+)\] (\d+) geslaagd, (\d+) mislukt", out)
        summary = ", ".join(f"{n}: {p}/{int(p)+int(f)}" for n, p, f in parts)
        total = sum(int(p) for _, p, _ in parts); summary = f"{total} checks ({summary})"
    elif script == "test_nui.py":
        m = re.search(r"(\d+) geslaagd, (\d+) mislukt", out); summary = f"{m.group(1)} checks" if m else out.strip()[:80]
    else:
        summary = [l for l in out.strip().splitlines() if l.strip()][-1] if out.strip() else ""
        if script == "check_crossrefs.py":
            summary = re.search(r"\d+ bestanden, \d+ fout\(en\)", out).group(0)
    rows.append((name, "✅ geslaagd" if ok else "❌ MISLUKT", summary))
    if not ok: detail.append(f"### {name}\n```\n{out[-1500:]}\n```")

md = f"""# Testresultaten

*Gegenereerd door `python3 tests/make_report.py` op {datetime.datetime.now().strftime('%d-%m-%Y %H:%M')} – dit zijn de werkelijke uitkomsten van die run.*

Omgeving: Lua 5.4 (lupa), luacheck 1.1.2, MariaDB 10.11.14, Chromium (Playwright), Node 22. **Geen FXServer/GTA.**

## Uitgevoerde controles

| Controle | Resultaat | Details |
|---|---|---|
""" + "\n".join(f"| {a} | {b} | {c} |" for a, b, c in rows) + f"""

**Eindoordeel van deze run: {'ALLES GESLAAGD' if ok_all else 'MISLUKT – zie onder'}**
""" + ("\n" + "\n".join(detail) if detail else "") + """

## Wat is echt UITGEVOERD (getest)

| Onderdeel | Hoe getest |
|---|---|
| **Serverlogica combat** (join-regels, zones, kills, beloningen/caps, anti-farm, respawn-limiet, beschermtijd, loadout-validatie, killfeed-dubbelingen, streaks, tijdelijke zones, schaderegels) | Echte serverbestanden in Lua 5.4 + mock van FiveM/ESX/ox_lib; queries tegen **echte MariaDB** |
| **Economie-grens** | 12 spelers die elkaar herhaald doden: totale uitkering ≤ uurbudget en dagcap |
| **Stats, K/D, XP, leaderboard** | Opslag in MariaDB, flush bij disconnect/stop, sortering (kills/kd/xp), SQL-injectie op sortering |
| **Dood/disconnect/jobwissel** | Inventaris, geld, bank, RP-loadout identiek vóór/na PvP-cyclus; geen verweesde toestand |
| **Roleplay-servers** | Dienst, politie, dood/revive/ziekenhuis, bezorging (anti-teleport/dagmax), taxi (alleen overdracht), monteur, garages (atomisch uitparkeren, geen model-swap), depot, winkels, wapenlicentie, geld/items geven, /me |
| **Gangs** | Aanmaken, rechten/grades, kas, territoria, **volledig ganggevecht** via combat_core, zwarte markt, activiteiten, hehler |
| **Admin** | Rechtenniveaus (ook voor menu-callbacks), bans in DB + login-controle (ook via ander identifier), verlopen/unban, warnings + auto-ban, console |
| **Persistentie na restart** | Twee opeenvolgende Lua-runtimes op dezelfde database: stats, dagcap, gang/kas/grades/territorium, voertuigen (garage + depot), bans, warnings, dagelijkse limieten |
| **SQL** | `sql/01–03` 2× achter elkaar in MariaDB (idempotent); alle queries via parameter-binding |
| **NUI** | Echte `index.html/style.css/app.js` in Chromium: berichten met ontbrekende/extreme waarden, killfeed-limiet, XSS via spelersnamen, geen console-fouten |
| **Kwaliteit** | luacheck (geen waarschuwingen), manifesten, kruisverwijzingen, tekstsleutels, geheimen-scan |

## Alleen via CODE gecontroleerd (NIET uitgevoerd)

| Onderdeel | Waarom niet getest |
|---|---|
| Alle **clientcode** (zones/blips/markers, bystander-gedrag, death-camera, respawn, spawn-teleport, loadouts geven, menu's, progressbars, taxi-meter, politie-animaties) | vereist een draaiende GTA-client |
| **Echte ESX/ox_lib/oxmysql-versies** (API-vormen) | bronnen niet op te halen; zie API-lijst in `docs/TESTEN.md` |
| **`weaponDamageEvent`** in een echte server | server-side schadebescherming; gedrag in-game te bevestigen |
| **ESX-eigen persistentie** (users: geld, job, positie, inventaris, loadout; personages/esx_identity) | beheerd door ESX, niet door onze code |
| Prestaties onder belasting (`resmon`) | geen echte server; alleen codeanalyse (lussen, queries, diff-updates) |
| Netwerkgedrag, latency, meerdere gelijktijdige clients | niet te simuleren |
"""
(ROOT / "docs" / "TESTRESULTATEN.md").write_text(md, encoding="utf-8")
print("docs/TESTRESULTATEN.md geschreven;", "ALLES GESLAAGD" if ok_all else "MISLUKT")
sys.exit(0 if ok_all else 1)
