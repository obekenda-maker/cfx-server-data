#!/usr/bin/env python3
"""Controleert server.cfg.example, secrets.cfg.example en de betekenis van de configwaarden."""
import pathlib, re, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lib_config import ROOT, load, cfg

errors = []
def err(m): errors.append(m)

# ---------- server.cfg.example ----------
text = (ROOT / "server.cfg.example").read_text()
lines = [l.strip() for l in text.splitlines()]
active = [l for l in lines if l and not l.startswith("#")]
for needle, why in [("set onesync on", "OneSync is verplicht"), ("exec secrets.cfg", "geheimen via secrets.cfg"),
                    ("sv_scriptHookAllowed 0", "geen ScriptHook"), ('endpoint_add_tcp', "tcp-endpoint"), ('endpoint_add_udp', "udp-endpoint")]:
    if not any(l.startswith(needle) for l in active): err(f"server.cfg.example mist '{needle}' ({why})")
if any(re.match(r"sv_licenseKey", l) for l in active): err("sv_licenseKey hoort in secrets.cfg, niet in server.cfg.example")
if any(l.startswith("setr") and re.search(r"(?i)mysql|webhook|key|pass", l) for l in active): err("geheim via setr")

ensures = [l.split()[1] for l in active if l.startswith("ensure ")]
FORBIDDEN = {"runcode", "esx_ambulancejob", "esx_policejob", "esx_mechanicjob", "esx_vehicleshop", "esx_shops", "esx_weaponshop",
             "esx_advancedgarage", "ox_inventory", "hardcap", "money-fountain", "money", "ped-money-drops", "basic-gamemode"}
for f in FORBIDDEN & set(ensures): err(f"'{f}' mag niet in server.cfg.example (conflict/onveilig)")
EXTERNAL = {"oxmysql", "ox_lib", "es_extended", "esx_menu_default", "esx_menu_dialog", "esx_menu_list", "skinchanger", "esx_skin",
            "esx_identity", "esx_addonaccount", "esx_addoninventory", "esx_datastore", "esx_society", "esx_status", "esx_basicneeds", "esx_license"}
present = {p.parent.name for p in (ROOT / "resources").rglob("fxmanifest.lua")}
for e in ensures:
    if e not in present and e not in EXTERNAL: err(f"ensure {e}: resource bestaat niet in repo en is geen bekende externe")
if len(ensures) != len(set(ensures)): err("dubbele ensure-regels")
idx = lambda n: next((i for i, l in enumerate(active) if l == f"ensure {n}"), None)
exec_i = next(i for i, l in enumerate(active) if l.startswith("exec secrets.cfg"))
for n in ("oxmysql", "ox_lib", "es_extended"):
    if idx(n) is None or idx(n) < exec_i: err(f"ensure {n} moet NA 'exec secrets.cfg' staan (connection string)")

# ---------- secrets.cfg.example ----------
sec = (ROOT / "secrets.cfg.example").read_text()
L = load(); S = cfg(L, "ServerCfg")
needed = {"sv_licenseKey", "mysql_connection_string"} | set(S["Webhooks"].values())
for n in needed:
    if not re.search(rf"^\s*(set\s+)?{n}\b", sec, re.M): err(f"secrets.cfg.example mist {n}")
used = set()
for f in (ROOT / "resources").rglob("*.lua"):
    if any(g in str(f) for g in ("[system]", "[gameplay]", "[managers]", "[gamemodes]", "[test]")): continue
    used |= set(re.findall(r"GetConvar(?:Int)?\(\s*'([^']+)'", f.read_text(encoding="utf-8")))
for u in used:
    if u not in needed and u not in S["Webhooks"].values(): err(f"code leest convar '{u}' die niet in secrets.cfg.example staat")

# ---------- configwaarden ----------
C, J, G, SH, GC, ST = (cfg(L, n) for n in ("CombatCfg", "JobsCfg", "GarageCfg", "ShopCfg", "GangCfg", "StatsCfg"))
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
for k in ("primary", "secondary", "success", "danger", "warning", "info"):
    if not HEX.match(S["Colors"][k]): err(f"ServerCfg.Colors.{k} is geen hex-kleur")
if S["Hud"]["position"] not in ("bottom-left", "bottom-right", "top-left", "top-right"): err("ServerCfg.Hud.position ongeldig")
if not (0.5 <= S["Hud"]["scale"] <= 1.5): err("ServerCfg.Hud.scale buiten 0.5–1.5")
groups = S["Admin"]["groups"]
if "admin" not in groups or "superadmin" not in groups: err("ServerCfg.Admin.groups mist admin/superadmin")
top = max(groups.values())
for a, lv in S["Admin"]["levels"].items():
    if lv > top: err(f"admin-actie {a} vereist niveau {lv} > hoogste groep ({top}): niemand kan het")
if S["Admin"]["permBanLevel"] > top: err("permBanLevel > hoogste groepsniveau")

seen = set()
for z in C["Zones"]:
    if z["id"] in seen: err(f"dubbele zone-id {z['id']}")
    seen.add(z["id"])
    if z["mode"] not in ("ffa", "team"): err(f"zone {z['id']}: ongeldige mode")
    if not (20 <= z["radius"] <= 400): err(f"zone {z['id']}: radius {z['radius']} onwaarschijnlijk")
    if not z["loadouts"]: err(f"zone {z['id']}: geen loadouts")
    for lo in z["loadouts"]:
        if lo not in C["Loadouts"]: err(f"zone {z['id']}: onbekende loadout {lo}")
    if z.get("entryFee", 0) < 0: err(f"zone {z['id']}: negatieve entreeprijs")
    if z["mode"] == "team" and not (z.get("teams") or C["DefaultTeams"]): err(f"zone {z['id']}: team-modus zonder teams")
for k, lo in C["Loadouts"].items():
    if not (1 <= lo["health"] <= 200): err(f"loadout {k}: health buiten 1–200")
    if not (0 <= lo["armor"] <= 100): err(f"loadout {k}: armor buiten 0–100")
    for w in lo["weapons"]:
        if not re.match(r"^WEAPON_[A-Z0-9_]+$", w["name"]): err(f"loadout {k}: ongeldige wapennaam {w['name']}")
        if w["name"] not in C["WeaponLabels"]: err(f"loadout {k}: {w['name']} mist een Nederlands label in WeaponLabels (killfeed)")
        if not (0 < w["ammo"] <= 1000): err(f"loadout {k}: {w['name']} ammo {w['ammo']} onwaarschijnlijk")
R = C["Rewards"]
for k in ("killMoney", "dailyMoneyCap", "globalHourlyBudget", "pairCooldownSeconds", "minAliveSeconds", "streakMoneyMax"):
    if R[k] < 0: err(f"Rewards.{k} negatief")
if R["dailyMoneyCap"] < R["killMoney"]: err("dailyMoneyCap < killMoney: er kan nooit een volle kill worden uitbetaald")
if R["killMoneyAccount"] not in ("money", "bank", "black_money"): err("Rewards.killMoneyAccount ongeldig")
if C["Rules"]["respawnSeconds"] < 1: err("respawnSeconds < 1")
if C["Outside"]["mode"] not in ("rp", "disabled"): err("Outside.mode ongeldig")

# jobs / winkels / bezorging
sql02 = (ROOT / "sql/02_jobs_items.sql").read_text()
items_sql = set(re.findall(r"^\s*\('([a-z_]+)',\s*'[^']*',\s*\d+,\s*\d+,\s*\d+\)", sql02, re.M)) | {"bread", "water"}
for cat, entries in SH["Catalogs"].items():
    for e in entries:
        if e["item"] not in items_sql: err(f"winkel-item '{e['item']}' ({cat}) staat niet in sql/02_jobs_items.sql (items)")
        if e["price"] <= 0: err(f"winkel-item {e['item']}: prijs <= 0")
for item in SH["Consumables"]:
    if item not in items_sql: err(f"consumable '{item}' mist in items-SQL")
for a in GC["Activities"]:
    if a["item"] not in items_sql: err(f"activiteit-item {a['item']} mist in items-SQL")
for item in GC["Fence"]["prices"]:
    if item not in items_sql: err(f"hehler-item {item} mist in items-SQL")
for b in GC["BlackMarket"]["items"]:
    if b["item"] not in items_sql: err(f"zwarte-markt-item {b['item']} mist in items-SQL")
if J["Mechanic"]["repairItem"] and J["Mechanic"]["repairItem"] not in items_sql: err("repairItem mist in items-SQL")
for k, d in J["Delivery"].items():
    for r in d["routes"]:
        if not (0 < r["pay"] <= d["dailyMax"]): err(f"delivery {k}/{r['label']}: pay buiten 1–dailyMax")
for g in G["Shop"]["categories"]:
    for v in g["vehicles"]:
        if v["price"] <= 0: err(f"voertuig {v['model']}: prijs <= 0")
if G["Shop"]["deliverTo"] not in {x["id"] for x in G["Garages"]}: err("GarageCfg.Shop.deliverTo verwijst naar onbekende garage")
for jr in C["JobRules"]:
    pass  # jobnamen worden in check_jobs gecontroleerd tegen de catalogus
gr = GC["Grades"]
if max(gr) != GC["LeaderGrade"]: err("GangCfg.LeaderGrade is niet de hoogste grade")
for g, v in gr.items():
    for p in v["perms"]:
        if p not in {"invite", "kick", "promote", "bank_deposit", "bank_withdraw", "war", "blackmarket", "disband"}: err(f"gang-grade {g}: onbekend recht {p}")

# ---------- server_welcome ----------
W = cfg(L, "WelcomeCfg"); rules = cfg(L, "WelcomeRules")
loc = SV = S["Locale"]
for st in W["Steps"]:
    for suffix in ("_title", "_text"):
        if f"welcome.step_{st['key']}{suffix}" not in loc: err(f"onboarding-stap '{st['key']}': tekst welcome.step_{st['key']}{suffix} ontbreekt")
    if st.get("waypoint") and st["waypoint"] not in W["Waypoints"]: err(f"onboarding-stap {st['key']}: onbekende waypoint {st['waypoint']}")
for g in W["Help"]:
    if g["group"] not in loc: err(f"help-groep {g['group']} mist tekst")
    for _, k in g["items"]:
        if k not in loc: err(f"help-tekst {k} ontbreekt")
for k in ("rules_title", "onboarding_title", "helppage_title", "accept_check", "accept_btn", "decline_btn", "close", "prev", "next", "finish", "skip", "step_of", "waypoint_btn", "timeout_note", "chat_fallback", "tab_welcome", "tab_rules", "tab_help"):
    if f"welcome.{k}" not in loc: err(f"NUI-tekst welcome.{k} ontbreekt")
near = lambda a, b: all(abs(a[c] - b[c]) < 1.0 for c in "xyz")
if not near(W["Waypoints"]["jobcenter"]["coords"], J["JobCenter"]["coords"]): err("welcome-waypoint 'jobcenter' ≠ JobsCfg.JobCenter.coords")
if not near(W["Waypoints"]["dealer"]["coords"], G["Shop"]["coords"]): err("welcome-waypoint 'dealer' ≠ GarageCfg.Shop.coords")
if not near(W["Waypoints"]["garage"]["coords"], G["Garages"][0]["coords"]): err("welcome-waypoint 'garage' ≠ eerste garage")
if not rules or any(not s["items"] for s in rules): err("WelcomeRules: lege sectie of geen regels")
if W["Rules"]["acceptTimeoutSeconds"] < 120: err("acceptTimeoutSeconds < 120: te kort voor personage aanmaken")
loading = re.sub(r"<[^>]+>", "", (ROOT / "resources/[server]/server_welcome/web/loading.html").read_text(encoding="utf-8"))
if re.sub(r"\s+", " ", S["Server"]["name"]).lower() not in re.sub(r"\s+", " ", loading).lower():
    err(f"loadscreen (server_welcome/web/loading.html) bevat de servernaam '{S['Server']['name']}' niet: pas de tekst aan (statische HTML)")
if W["Rules"]["version"] < 1: err("WelcomeCfg.Rules.version moet ≥ 1 zijn")

for e in errors: print("FOUT:", e)
print(f"config-lint: {len(ensures)} ensure-regels, {len(errors)} fout(en)")
sys.exit(1 if errors else 0)
