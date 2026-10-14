#!/usr/bin/env python3
"""Zone-lint: beschermt roleplaygebieden tegen overlap met PvP-zones en gangoorlogsgebieden.
 1. elk RP-punt ligt in een CombatCfg.SafeZone
 2. geen PvP-zone overlapt een SafeZone of RP-punt
 3. geen territorium (= toekomstige oorlogszone) overlapt een SafeZone, RP-punt of PvP-zone
 4. coördinaten zijn plausibel (binnen de GTA-kaart)"""
import math, pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lib_config import load, cfg

L = load()
C, J, G, S, GC = (cfg(L, n) for n in ("CombatCfg", "JobsCfg", "GarageCfg", "ShopCfg", "GangCfg"))
d = lambda a, b: math.dist((a["x"], a["y"], a["z"]), (b["x"], b["y"], b["z"]))

rp = []  # (label, coords)
for x in J["Duty"]: rp.append((f"dienstpunt {x['label']}", x["coords"]))
for x in J["Boss"]: rp.append((f"bossmenu {x['job']}", x["coords"]))
for k, x in J["Delivery"].items(): rp.append((f"depot {k}", x["depot"]["coords"]))
for x in J["Death"]["hospitals"]: rp.append((f"ziekenhuis {x['label']}", x["coords"]))
if "JobCenter" in J: rp.append(("jobcentrum", J["JobCenter"]["coords"]))
for x in G["Garages"]: rp.append((f"garage {x['label']}", x["coords"]))
rp.append(("depot wegsleep", G["Impound"]["coords"])); rp.append(("autodealer", G["Shop"]["coords"]))
for x in S["Shops"]: rp.append((f"winkel {x['label']}", x["coords"]))

errors = []
safe = C["SafeZones"]
for label, p in rp:
    if not any(d(p, s["coords"]) <= s["radius"] for s in safe):
        errors.append(f"RP-punt '{label}' ligt in GEEN SafeZone")
MARGIN = 25.0
for z in C["Zones"]:
    for s in safe:
        if d(z["coords"], s["coords"]) < z["radius"] + s["radius"]:
            errors.append(f"PvP-zone '{z['id']}' overlapt SafeZone '{s['label']}'")
    for label, p in rp:
        if d(z["coords"], p) < z["radius"] + MARGIN:
            errors.append(f"PvP-zone '{z['id']}' ligt op/bij RP-punt '{label}'")
for t in GC["Territories"]:
    for s in safe:
        if d(t["coords"], s["coords"]) < t["radius"] + s["radius"]:
            errors.append(f"territorium '{t['id']}' overlapt SafeZone '{s['label']}' (oorlogszone zou RP-gebied raken)")
    for label, p in rp:
        if d(t["coords"], p) < t["radius"] + MARGIN:
            errors.append(f"territorium '{t['id']}' ligt op/bij RP-punt '{label}'")
    for z in C["Zones"]:
        if d(t["coords"], z["coords"]) < t["radius"] + z["radius"]:
            errors.append(f"territorium '{t['id']}' overlapt PvP-zone '{z['id']}'")
everything = [(z["id"], z["coords"]) for z in C["Zones"]] + [(t["id"], t["coords"]) for t in GC["Territories"]] + rp + [(s["label"], s["coords"]) for s in safe]
for label, p in everything:
    if not (-4200 <= p["x"] <= 4500 and -4500 <= p["y"] <= 8200):
        errors.append(f"'{label}' ligt buiten de GTA-kaart: {p}")

for e in errors: print("FOUT:", e)
print(f"{len(rp)} RP-punten, {len(safe)} SafeZones, {len(C['Zones'])} PvP-zones, {len(GC['Territories'])} territoria: {len(errors)} fout(en)")
sys.exit(1 if errors else 0)
