#!/usr/bin/env python3
"""Vergelijkt onze ESX-aanroepen met de ECHTE geïnstalleerde es_extended-broncode:
xPlayer-methoden (server/classes/player.lua), ESX.*-serverfuncties, esx:*-events. Overgeslagen als niet geïnstalleerd."""
import pathlib, re, sys
ROOT = pathlib.Path(__file__).resolve().parent.parent
ES = ROOT / "resources/[core]/es_extended"
if not ES.exists():
    print("OVERGESLAGEN: es_extended niet geïnstalleerd"); sys.exit(0)
src = "\n".join(p.read_text(encoding="utf-8", errors="ignore") for p in ES.rglob("*.lua"))
methods = set(re.findall(r"function self\.(\w+)\(", src)) | set(re.findall(r"self\.(\w+)\s*=\s*function", src))
used, funcs, events = {}, {}, {}
for g in ("[admin]", "[combat]", "[roleplay]", "[server]", "[ui]"):
    for f in (ROOT / "resources" / g).rglob("*.lua"):
        t = f.read_text(encoding="utf-8")
        for m in re.finditer(r"\b(?:xPlayer|xTarget|xTo|xFrom|xSource|xDriver|xp|x)\.(\w+)\(", t):
            used.setdefault(m.group(1), f.name)
        for m in re.finditer(r"\bESX\.(\w+)\(", t): funcs.setdefault(m.group(1), f.name)
        for m in re.finditer(r"['\"](esx:\w+)['\"]", t): events.setdefault(m.group(1), f.name)
bad = 0
ignore = {"job", "source", "identifier"}
for m, f in sorted(used.items()):
    if m not in methods and m not in ignore:
        bad += 1; print(f"FOUT: xPlayer.{m}() ({f}) bestaat niet in es_extended")
esx_funcs = set(re.findall(r"function ESX\.(\w+)\(", src)) | set(re.findall(r"^ESX\.(\w+)\s*=", src, re.M))
for m, f in sorted(funcs.items()):
    if m not in esx_funcs:
        bad += 1; print(f"FOUT: ESX.{m}() ({f}) niet gevonden in es_extended")
for e, f in sorted(events.items()):
    if e not in src:
        print(f"LET OP: event {e} ({f}) komt niet voor in es_extended (alleen een probleem als wij erop wachten)")
print(f"{len(used)} xPlayer-methoden, {len(funcs)} ESX-functies, {len(events)} esx-events vergeleken met es_extended; {bad} fout(en)")
sys.exit(1 if bad else 0)
