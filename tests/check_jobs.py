#!/usr/bin/env python3
"""Controleert de jobcatalogus: consistentie met dienstpunten, bossmenu's, bedrijfskassen, bezorgbanen, PvP-regels,
uitlegteksten (/baan) en dat sql/02_jobs_items.sql gelijk is aan de catalogus."""
import pathlib, re, subprocess, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lib_config import ROOT, load, cfg

L = load()
J, C, SV = cfg(L, "JobsCfg"), cfg(L, "CombatCfg"), cfg(L, "ServerCfg")
loc = SV["Locale"]
errors = []
err = errors.append
cat = {j["name"]: j for j in J["Catalog"]}
off = J["OffDutyPrefix"]

for n, j in cat.items():
    if not re.match(r"^[a-z]+$", n): err(f"jobnaam '{n}' moet kleine letters zijn")
    if n == "unemployed": err("'unemployed' hoort niet in de catalogus (ESX levert die)")
    if j.get("public") and j.get("whitelisted"): err(f"{n}: public én whitelisted is tegenstrijdig")
    names = [g["name"] for g in j["grades"]]
    if len(names) != len(set(names)): err(f"{n}: dubbele gradenamen")
    for g in j["grades"]:
        if not isinstance(g["salary"], int) or g["salary"] < 0: err(f"{n}/{g['name']}: salaris moet een geheel getal ≥ 0 zijn")
    sal = [g["salary"] for g in j["grades"]]
    if sal != sorted(sal): err(f"{n}: salarissen niet oplopend per grade")
    for k in (j["info"], j["info"] + "_short"):
        if k not in loc: err(f"{n}: tekstsleutel {k} ontbreekt in locale_nl.lua")

for d in J["Duty"]:
    if d["job"] not in cat: err(f"dienstpunt voor onbekende job {d['job']}")
    elif not cat[d["job"]].get("offDuty"): err(f"dienstpunt voor {d['job']} maar offDuty = false (geen {off}-variant)")
for b in J["Boss"]:
    if b["job"] not in cat: err(f"bossmenu voor onbekende job {b['job']}")
    elif cat[b["job"]]["grades"][-1]["name"] != "boss": err(f"bossmenu {b['job']}: hoogste grade heet niet 'boss'")
for s in J["Societies"]:
    if s["job"] not in cat: err(f"society voor onbekende job {s['job']}")
    elif cat[s["job"]]["grades"][-1]["name"] != "boss": err(f"society {s['job']}: hoogste grade heet niet 'boss'")
for k, d in J["Delivery"].items():
    if d["job"] not in cat: err(f"bezorgbaan {k}: job {d['job']} niet in catalogus")
    elif not cat[d["job"]].get("public"): err(f"bezorgbaan {k}: job {d['job']} is niet public (niemand kan zich aanmelden)")
for key in ("Police", "Mechanic", "Taxi"):
    if J[key]["job"] not in cat: err(f"{key}.job {J[key]['job']} niet in catalogus")
if J["Death"]["medicJob"] not in cat: err("Death.medicJob niet in catalogus")
for jr in C["JobRules"]:
    if jr != "default" and jr not in cat and jr != "unemployed": err(f"CombatCfg.JobRules.{jr} verwijst naar onbekende job")
for must in ("police", "ambulance"):
    if C["JobRules"].get(must, {}).get("canJoin") is not False: err(f"beleid: {must} (op dienst) mag niet aan PvP deelnemen")
    if not cat[must].get("whitelisted") or cat[must].get("public"): err(f"beleid: {must} moet whitelisted en niet public zijn")
if not any(j.get("public") for j in cat.values()): err("geen enkele public job: burgers kunnen nergens werken")
if J["JobCenter"]["minSecondsBetween"] < 60: err("JobCenter.minSecondsBetween < 60 (job-hoppen)")

# SQL gelijk aan catalogus?
r = subprocess.run([sys.executable, str(ROOT / "scripts/gen_jobs_sql.py"), "--check"], capture_output=True, text=True)
if r.returncode != 0: err(r.stdout.strip() or r.stderr.strip())

for e in errors: print("FOUT:", e)
print(f"jobcatalogus: {len(cat)} jobs, {sum(len(j['grades']) for j in cat.values())} grades, {len(errors)} fout(en)")
sys.exit(1 if errors else 0)
