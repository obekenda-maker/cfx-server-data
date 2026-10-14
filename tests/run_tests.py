#!/usr/bin/env python3
"""Draait alle Lua-tests (tests/test_*.lua) onder Lua 5.4 met het mock-harnas en een ECHTE MariaDB.
Vereist: draaiende MariaDB/MySQL (unix-socket /run/mysqld/mysqld.sock, user root) en `pip install lupa pymysql`."""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lib_runtime import ROOT, build_db, make_runtime, report  # noqa

only = [a for a in sys.argv[1:] if not a.startswith("-")]
total_fail = 0
for t in sorted((ROOT / "tests").glob("test_*.lua")):
    if only and t.stem not in only:
        continue
    lua = make_runtime(build_db())
    try:
        lua.execute((ROOT / "tests" / t.name).read_text(encoding="utf-8"))
    except Exception as e:  # noqa
        print(f"[{t.stem}] LAADFOUT: {e}")
        total_fail += 1
        continue
    total_fail += report(t.stem, lua)
sys.exit(1 if total_fail else 0)
