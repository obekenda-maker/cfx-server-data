#!/usr/bin/env python3
"""Economie-controle: berekent geldbronnen/-putten uit de configs + salarissen uit sql/02 en toetst beleidsregels.
Schrijft docs/ECONOMIE.md. Faalt als een beleidsregel wordt geschonden."""
import pathlib, re, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lib_config import ROOT, load, cfg

# ---- Aannames (pas aan als jouw ESX anders is ingesteld; zie docs/ECONOMIE.md) ----
PAYCHECK_MINUTES = 30        # ESX Config.PaycheckInterval – AANBEVOLEN waarde; ESX-standaard is korter (zie docs)
MAX_HOURLY_NONBOSS = 2000    # beleid: geen enkel niet-baas-salaris boven dit bedrag per uur
BLACK_PREMIUM = 1.5          # beleid: illegaal wapen ≥ 1,5× legale prijs

L = load()
C, J, G, S = (cfg(L, n) for n in ("CombatCfg", "JobsCfg", "GangCfg", "ShopCfg"))
GR = cfg(L, "GarageCfg"); SV = cfg(L, "ServerCfg")
sql = (ROOT / "sql/02_jobs_items.sql").read_text()
sal = {}
for m in re.finditer(r"\('([a-z]+)',\s*(\d+),\s*'([a-z_]+)',\s*'([^']*)',\s*(\d+),\s*'\{\}'", sql):
    sal.setdefault(m.group(1), []).append((int(m.group(2)), m.group(3), m.group(4), int(m.group(5))))

R = C["Rewards"]
errors, rows = [], []
def err(m): errors.append(m)
hourly = lambda s: s * 60 / PAYCHECK_MINUTES

# ---- Salarissen per uur ----
sal_rows = []
for job, grades in sorted(sal.items()):
    for g, name, label, s in sorted(grades):
        h = hourly(s)
        sal_rows.append((job, g, label, s, h))
        if job.startswith("off") and s != 0: err(f"af-dienst-job {job} grade {g} heeft salaris {s} (moet 0)")
        if name != "boss" and h > MAX_HOURLY_NONBOSS: err(f"{job}/{label}: {h:.0f}/uur > beleidsmaximum {MAX_HOURLY_NONBOSS}")

# ---- Combat ----
daily_deliv = {k: v["dailyMax"] for k, v in J["Delivery"].items()}
best_job_daily = max(daily_deliv.values())
if R["dailyMoneyCap"] > best_job_daily: err(f"combat-dagcap ({R['dailyMoneyCap']}) > beste burgerbaan-daglimiet ({best_job_daily}): PvP zou RP-banen verslaan")
max_kills_cap = R["dailyMoneyCap"] / max(R["killMoney"], 1)
max_zone_mult = max(z["rewardMultiplier"] for z in C["Zones"])
if R["killMoney"] * max_zone_mult + R["streakMoneyMax"] * max_zone_mult > R["dailyMoneyCap"]:
    err("één kill (incl. max. streak/zone-multiplier) is groter dan de dagcap")
for z in C["Zones"]:
    if z["entryFee"] >= R["dailyMoneyCap"]: err(f"zone {z['id']}: entreegeld ≥ dagcap (negatieve verwachting)")

# ---- Wapens ----
legal = {w["weapon"]: w["price"] for w in S["WeaponShop"]["weapons"]}
for w in G["BlackMarket"]["weapons"]:
    if w["weapon"] in legal and w["price"] < legal[w["weapon"]] * BLACK_PREMIUM:
        err(f"zwarte markt: {w['weapon']} ({w['price']}) goedkoper dan {BLACK_PREMIUM}× legale prijs ({legal[w['weapon']]})")
    if w["dailyLimit"] > 3: err(f"zwarte markt: {w['weapon']} dailyLimit {w['dailyLimit']} > 3")
combat_weapons = {w["name"] for lo in C["Loadouts"].values() for w in lo["weapons"]}
shop_weapons = set(legal) | {w["weapon"] for w in G["BlackMarket"]["weapons"]}

# ---- Gangs ----
inc_day_gang = G["Territory"]["incomePerHour"] * G["Territory"]["maxPerGang"] * 24
cheapest_car = min(v["price"] for c in GR["Shop"]["categories"] for v in c["vehicles"])
if inc_day_gang > 5 * best_job_daily: err(f"gebiedsinkomsten per gang per dag ({inc_day_gang}) > 5× beste baan-daglimiet")
if G["War"]["cost"] <= 0 or G["Territory"]["claimCost"] <= 0: err("oorlog/claim moeten geld kosten (geldput)")

# ---- Rapport ----
fa = []  # (bron, max per speler per dag, opmerking)
fa.append(("Salaris (per grade)", "zie tabel", f"uitbetaling per {PAYCHECK_MINUTES} min (aanname); ESX bepaalt het interval"))
for k, v in J["Delivery"].items(): fa.append((f"Bezorging: {v['label']}", v["dailyMax"], "server-begrensd (dailyMax in DB)"))
fa.append(("Combat-kills (geld)", R["dailyMoneyCap"], f"+ globaal uurbudget {R['globalHourlyBudget']:,}/uur voor de hele server"))
fa.append(("Taxi", f"≤ {J['Taxi']['maxFare']} per rit", "overdracht van passagier (geen nieuw geld)"))
fa.append(("Hehler (zwart geld)", G["Fence"]["dailyAmountCap"], "alleen na activiteit 'schroot' (item-limiet)"))
fa.append(("Gebiedsinkomsten (gang)", f"{G['Territory']['incomePerHour']}/uur/gebied", f"max {G['Territory']['maxPerGang']} gebieden; alleen met ≥{G['Territory']['minOnline']} leden online → gangkas"))
sinks = [
    ("Winkels (eten/EHBO/kit)", "ShopCfg.Catalogs"), ("Voertuigen", f"vanaf €{cheapest_car:,}"), ("Wapenlicentie", f"€{S['WeaponShop']['licensePrice']:,}"),
    ("Wapens (legaal)", ", ".join(f"{k} €{v:,}" for k, v in legal.items())), ("Zwarte markt", "zie config (zwart geld)"),
    ("Depot (wegsleep)", f"€{GR['Impound']['fee']}"), ("Ziekenhuis", f"€{J['Death']['hospitalFee']} (nooit > bezit)"), ("Revive", f"€{J['Death']['reviveFee']}"),
    ("Combat-entree", ", ".join(f"{z['id']} €{z['entryFee']}" for z in C["Zones"])), ("Gang oprichten", f"€{G['Creation']['cost']:,}"),
    ("Territorium claimen", f"€{G['Territory']['claimCost']:,}"), ("Ganggevecht", f"€{G['War']['cost']:,}"),
]
md = ["# Economie-overzicht (gegenereerd)", "",
      "*Gegenereerd door `python3 tests/check_economy.py` uit de echte configbestanden en `sql/02_jobs_items.sql`.*", "",
      f"**Aanname:** ESX betaalt salaris elke **{PAYCHECK_MINUTES} minuten**. Zet dat in `es_extended` (`Config.PaycheckInterval = {PAYCHECK_MINUTES} * 60000`);",
      "de ESX-standaard is korter, waardoor salarissen veel te hoog uitvallen. Controleer dit eerst, anders kloppen de bedragen hieronder niet.", "",
      "## Geldbronnen (faucets)", "", "| Bron | Maximaal per speler per dag | Opmerking |", "|---|---|---|"]
md += [f"| {a} | {b if isinstance(b, str) else f'€{b:,}'} | {c} |" for a, b, c in fa]
md += ["", "## Salarissen", "", f"| Job | Grade | Label | Per uitbetaling | Per uur (bij {PAYCHECK_MINUTES} min) |", "|---|---|---|---|---|"]
md += [f"| {j} | {g} | {l} | €{s} | €{h:,.0f} |" for j, g, l, s, h in sal_rows if s > 0]
md += ["", "## Geldputten (sinks)", "", "| Put | Bedrag |", "|---|---|"] + [f"| {a} | {b} |" for a, b in sinks]
md += ["", "## Combat-beloningen", "",
       f"* Basis €{R['killMoney']} (+ streak max €{R['streakMoneyMax']}) × zonemultiplier (max {max_zone_mult}); dagcap €{R['dailyMoneyCap']:,} ≈ {max_kills_cap:.0f} basiskills.",
       f"* Globaal uurbudget €{R['globalHourlyBudget']:,}: daarna alleen XP. Paar-cooldown {R['pairCooldownSeconds']} s; slachtoffer moet ≥ {R['minAliveSeconds']} s geleefd hebben.",
       f"* Beste burgerbaan-daglimiet €{best_job_daily:,} ≥ combat-dagcap €{R['dailyMoneyCap']:,}: **PvP verslaat roleplay-banen niet** (beleidsregel, getest).",
       "* Gangoorlogen en tijdelijke zones: **geen** geld/XP/stats.",
       "", "## Wapens", "",
       f"* Combatwapens ({len(combat_weapons)}): alleen client-native, nooit in ESX-loadout/DB; verdwijnen bij verlaten/crash.",
       f"* Legaal: licentie €{S['WeaponShop']['licensePrice']:,} + wapen. Illegaal: alleen gangleden met recht `blackmarket`, gebied vereist, daglimiet, ≥{BLACK_PREMIUM}× legale prijs.",
       "", "## Beleidsregels die dit script toetst", "",
       f"1. Geen niet-baas-salaris boven €{MAX_HOURLY_NONBOSS}/uur; af-dienst-jobs betalen €0.",
       "2. Combat-dagcap ≤ beste burgerbaan-daglimiet.", "3. Eén kill (incl. streak/multiplier) ≤ dagcap; entreegeld < dagcap.",
       f"4. Zwarte-markt-wapen ≥ {BLACK_PREMIUM}× legale prijs, daglimiet ≤ 3.", "5. Gebiedsinkomsten per gang per dag ≤ 5× beste baan-daglimiet; oorlog/claim kosten geld.", ""]
(ROOT / "docs" / "ECONOMIE.md").write_text("\n".join(md), encoding="utf-8")
for e in errors: print("FOUT:", e)
print(f"economie: {len(errors)} beleidsfout(en); rapport docs/ECONOMIE.md")
sys.exit(1 if errors else 0)
