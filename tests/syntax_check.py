#!/usr/bin/env python3
"""Syntaxcontrole van alle eigen Lua- en JavaScript-bestanden (Lua 5.4 via lupa, JS via node --check)."""
import pathlib, subprocess, sys
from lupa import lua54

ROOT = pathlib.Path(__file__).resolve().parent.parent
OWN = ["[admin]", "[combat]", "[roleplay]", "[server]", "[ui]"]
lua = lua54.LuaRuntime()
check = lua.eval("function(src, name) local f, err = load(src, name, 't') if f then return nil end return err end")

failed = 0
count = 0
for group in OWN:
    base = ROOT / "resources" / group
    for path in sorted(base.rglob("*.lua")):
        count += 1
        err = check(path.read_text(encoding="utf-8"), "@" + str(path.relative_to(ROOT)))
        if err:
            failed += 1
            print("LUA FOUT:", err)
    for path in sorted(base.rglob("*.js")):
        count += 1
        r = subprocess.run(["node", "--check", str(path)], capture_output=True, text=True)
        if r.returncode != 0:
            failed += 1
            print("JS FOUT:", path, r.stderr)
print(f"{count} bestanden gecontroleerd, {failed} fout(en)")
sys.exit(1 if failed else 0)
