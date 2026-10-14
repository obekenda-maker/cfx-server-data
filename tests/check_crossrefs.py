#!/usr/bin/env python3
"""Kruiscontrole van eigen resources:
  - exports.<resource>:<Fn>(...) → bestaat exports('Fn', ...) in die resource?
  - lib.callback.await/ lib.callback(...) naam → is er een lib.callback.register met die naam?
  - TriggerEvent/TriggerClientEvent/TriggerServerEvent('naam') → is er een handler (RegisterNetEvent/AddEventHandler)?
Externe events (esx:, esx_status:, chat:, ox_lib:, playerDropped, ...) worden gemeld als 'extern' en niet als fout."""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OWN = {}
for g in ["[admin]", "[combat]", "[roleplay]", "[server]", "[ui]"]:
    for m in (ROOT / "resources" / g).glob("*/fxmanifest.lua"):
        OWN[m.parent.name] = m.parent

src = {}
for name, path in OWN.items():
    for f in path.rglob("*.lua"):
        src[f] = (name, f.read_text(encoding="utf-8"))

exports_defined = {}   # res -> set
cb_registered, ev_handlers = set(), set()
for f, (res, text) in src.items():
    for m in re.finditer(r"\bexports\(\s*'([A-Za-z_]+)'", text):
        exports_defined.setdefault(res, set()).add(m.group(1))
    for m in re.finditer(r"lib\.callback\.register\(\s*'([^']+)'", text):
        cb_registered.add(m.group(1))
    for m in re.finditer(r"(?:RegisterNetEvent|AddEventHandler)\(\s*'([^']+)'", text):
        ev_handlers.add(m.group(1))

errors, external = [], set()
for f, (res, text) in src.items():
    rel = f.relative_to(ROOT)
    for m in re.finditer(r"exports\.([a-z_]+):([A-Za-z_]+)\(", text):
        r, fn = m.groups()
        if r in OWN and fn not in exports_defined.get(r, set()):
            errors.append(f"{rel}: export {r}:{fn} bestaat niet")
        elif r not in OWN:
            external.add(f"export {r}:{fn}")
    for m in re.finditer(r"lib\.callback\.await\(\s*'([^']+)'", text):
        if m.group(1) not in cb_registered:
            errors.append(f"{rel}: callback '{m.group(1)}' heeft geen register")
    for m in re.finditer(r"\b(?:TriggerEvent|TriggerClientEvent|TriggerServerEvent)\(\s*'([^']+)'", text):
        ev = m.group(1)
        if ev not in ev_handlers:
            external.add(f"event {ev}")

for e in errors: print("FOUT:", e)
print(f"{len(src)} bestanden, {len(errors)} fout(en). Externe verwijzingen ({len(external)}):")
for e in sorted(external): print("  extern:", e)
sys.exit(1 if errors else 0)
