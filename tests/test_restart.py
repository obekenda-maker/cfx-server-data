#!/usr/bin/env python3
"""Simuleert een serverrestart: fase A (data aanmaken) en fase B (nieuwe Lua-runtime, zelfde database)."""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lib_runtime import ROOT, build_db, make_runtime, report  # noqa

conn = build_db()
fail = 0
for phase in ("phase_a", "phase_b"):
    lua = make_runtime(conn)           # nieuwe runtime = alle Lua-geheugen weg, database blijft
    try:
        lua.execute((ROOT / "tests" / "restart" / f"{phase}.lua").read_text(encoding="utf-8"))
    except Exception as e:  # noqa
        print(f"[restart {phase}] LAADFOUT: {e}"); fail += 1; continue
    fail += report(f"restart {phase}", lua)
sys.exit(1 if fail else 0)
