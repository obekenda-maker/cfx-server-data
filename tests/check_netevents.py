#!/usr/bin/env python3
"""Audit van de serverkant-ingangen die een client kan aanroepen:
  1. net events (RegisterNetEvent in servercode): alleen een vaste, gedocumenteerde lijst, elk met spam-bescherming
  2. lib.callback.register in servercode: elk met spam-bescherming, tenzij op de lijst 'bewust zonder' met reden"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
NETEVENTS = {  # naam → reden
    "combat:died": "claim van slachtoffer; server valideert killer/zone/afstand/beveiliging; throttle",
    "combat:protectionBroken": "verwijdert alleen eigen bescherming; throttle",
    "rp_jobs:died": "alleen logging/timer; server controleert health; throttle",
    "welcome:decline": "alleen kick van jezelf bij niet-akkoord; throttle",
}
NO_THROTTLE_OK = {  # callbacks zonder throttle: alleen-lezen/goedkoop of server-bepaald
    "admin_tools:can": "alleen-lezen rechtencheck (in-memory)",
    "rp_jobs:delivery:cancel": "wist alleen eigen missie",
    "rp_garages:restore": "alleen eigen voertuig, server controleert wereld + eigenaar",
    "combat_stats:getMine": "alleen-lezen, in-memory eigen stats",
    "admin_tools:action": "throttle zit in de handler (lokale functie); rechten per actie",
}
errors, seen_ev, seen_cb = [], set(), []

def server_files():
    for g in ("[admin]", "[combat]", "[roleplay]", "[server]", "[ui]"):
        for f in (ROOT / "resources" / g).rglob("*.lua"):
            rel = f.relative_to(ROOT).as_posix()
            if "/client/" in rel or rel.endswith(("config.lua", "locale_nl.lua", "interact.lua", "rules_nl.lua", "util.lua")): continue
            yield f

def body(text, start, n=1800):
    return text[start:start + n]

for f in server_files():
    text = f.read_text(encoding="utf-8")
    rel = f.relative_to(ROOT)
    for m in re.finditer(r"RegisterNetEvent\(\s*'([^']+)'\s*,\s*function", text):
        ev = m.group(1); seen_ev.add(ev)
        if ev not in NETEVENTS: errors.append(f"{rel}: NIEUW net event '{ev}' – voeg toe aan de lijst met reden of verwijder")
        elif not re.search(r"[Tt]hrottle\(", body(text, m.end(), 700)): errors.append(f"{rel}: net event '{ev}' mist throttle")
    for m in re.finditer(r"RegisterNetEvent\(\s*'([^']+)'\s*\)", text):   # zonder handler = registratie voor ander gebruik
        if m.group(1) not in NETEVENTS: errors.append(f"{rel}: RegisterNetEvent('{m.group(1)}') zonder handler")
    for m in re.finditer(r"lib\.callback\.register\(\s*'([^']+)'\s*,\s*function\(([^)]*)\)", text):
        name = m.group(1); seen_cb.append(name)
        b = body(text, m.end(), 900)
        if not re.search(r"[Tt]hrottle\(", b) and name not in NO_THROTTLE_OK:
            errors.append(f"{rel}: callback '{name}' heeft geen throttle en staat niet op de 'bewust zonder'-lijst")

for ev in NETEVENTS:
    if ev not in seen_ev: errors.append(f"net event {ev} staat op de lijst maar bestaat niet meer (lijst bijwerken)")
for n in NO_THROTTLE_OK:
    if n not in seen_cb: errors.append(f"callback {n} staat op de uitzonderingenlijst maar bestaat niet")

for e in errors: print("FOUT:", e)
print(f"{len(seen_ev)} net events en {len(seen_cb)} server-callbacks geaudit, {len(errors)} fout(en)")
sys.exit(1 if errors else 0)
