#!/usr/bin/env python3
"""Statische analyse met luacheck (typfouten, niet-gedefinieerde variabelen, ongebruikte waarden)."""
import shutil, subprocess, sys, pathlib
ROOT = pathlib.Path(__file__).resolve().parent.parent
if not shutil.which("luacheck"):
    print("OVERGESLAGEN: luacheck niet geïnstalleerd (apt install lua-check)"); sys.exit(0)
r = subprocess.run(["luacheck", "--no-color", "--codes", "--formatter", "plain",
                    *[f"resources/{g}" for g in ("[admin]", "[combat]", "[roleplay]", "[server]", "[ui]")]],
                   cwd=ROOT, capture_output=True, text=True)
print("luacheck: " + (f"{len(r.stdout.strip().splitlines())} waarschuwing(en)" if r.stdout.strip() else "0 waarschuwingen") + (" " + r.stderr.strip() if r.stderr.strip() else ""))
if r.returncode != 0:
    print(r.stdout)
sys.exit(1 if r.returncode else 0)
