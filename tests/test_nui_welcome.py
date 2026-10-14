#!/usr/bin/env python3
"""NUI-test voor server_welcome in headless Chromium (wordt overgeslagen zonder Playwright/Chromium)."""
import json, os, pathlib, shutil, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parent.parent
pw = next((p for p in ("/opt/node22/lib/node_modules/playwright", "/usr/lib/node_modules/playwright") if os.path.isdir(p)), None)
chromium = next((str(p) for p in pathlib.Path("/opt/pw-browsers").glob("chromium-*/chrome-linux/chrome")), shutil.which("chromium"))
if not pw or not chromium:
    print("OVERGESLAGEN: Playwright/Chromium niet beschikbaar"); sys.exit(0)
out = subprocess.run(["node", str(ROOT / "tests/nui_welcome_runner.cjs"), str(ROOT / "resources/[server]/server_welcome/web")],
                     capture_output=True, text=True, env=dict(os.environ, PLAYWRIGHT_MODULE=pw, CHROMIUM=chromium), timeout=120)
if out.returncode != 0:
    print("NODE FOUT:", out.stderr[-800:]); sys.exit(1)
r = json.loads(out.stdout.strip().splitlines()[-1])
checks = [
    ("pagina zichtbaar + titel", r["overlayVisible"] and r["title"] == "Serverregels"),
    ("verplicht: geen tabs en geen sluitknop", r["tabsEmpty"] and r["closeHiddenWhenMandatory"]),
    ("Akkoord uitgeschakeld zonder vinkje", r["acceptDisabled"] and r["acceptNoPostWhenDisabled"]),
    ("vinkje activeert Akkoord", r["acceptEnabled"]),
    ("Akkoord stuurt 'accept'", r["acceptPosted"]),
    ("Niet akkoord stuurt 'decline'", r["declinePosted"]),
    ("Escape doet niets bij verplicht akkoord", r["escIgnoredWhenMandatory"]),
    ("regels als tekst (geen HTML-injectie)", r["rulesCount"] == 3 and r["rulesInjected"] == 0),
    ("timeout-melding", "Nog 1:" in r["timeoutNote"] and "Typ /akkoord" in r["timeoutNote"]),
    ("kleur uit config", r["primary"] == "#123456"),
    ("/regels: alleen lezen met Sluiten en tabs", r["readOnlyNoAccept"] and r["tabsShown"]),
    ("Escape sluit als dat mag", r["escClosesWhenAllowed"]),
    ("onboarding stap 1 + teller", r["step1"] == "Stap een" and r["stepCount"] == "Stap 1 van 3" and r["prevDisabledFirst"]),
    ("vet/code gerenderd, scripts niet", r["boldRendered"] == 1 and r["codeRendered"] == 1 and r["stepInjected"] == 0),
    ("waypoint-knop alleen waar nodig + tekst", r["waypointHiddenStep1"] and r["step2"] == "Stap twee" and r["waypointText"] == 'Zet "Jobcentrum" op mijn kaart'),
    ("waypoint stuurt de juiste sleutel", r["waypointPosted"] == "jobcenter"),
    ("laatste stap toont 'Aan de slag', Vorige werkt", r["lastStepShowsFinish"] and r["prevWorks"]),
    ("Aan de slag en Overslaan sturen 'finish'", r["finishPosted"] and r["skipPosted"]),
    ("help toont commando's", r["helpRows"] == 2),
    ("sluiten + onbekende berichten", r["closed"]),
    ("geen script-uitvoering (XSS)", r["xss"] == 0),
    ("geen console-fouten", r["errors"] == []),
]
bad = [n for n, ok in checks if not ok]
for n, ok in checks: print(("  ✓ " if ok else "  ✗ ") + n)
if r["errors"]: print("  fouten:", r["errors"])
print(f"[test_nui_welcome] {len(checks) - len(bad)} geslaagd, {len(bad)} mislukt")
sys.exit(1 if bad else 0)
