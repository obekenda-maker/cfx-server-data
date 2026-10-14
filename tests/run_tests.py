#!/usr/bin/env python3
"""Draait alle Lua-tests (tests/test_*.lua) onder Lua 5.4 met het mock-harnas en een ECHTE MariaDB.
Vereist: draaiende MariaDB/MySQL (unix-socket /run/mysqld/mysqld.sock, user root) en `pip install lupa pymysql`."""
import datetime, decimal, pathlib, sys
from lupa import lua54
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from test_sql import fresh, split, ROOT  # noqa

only = [a for a in sys.argv[1:] if not a.startswith("-")]
total_fail = 0

def build_db():
    conn = fresh()
    cur = conn.cursor()
    for f in ("01_core.sql", "02_jobs_items.sql", "03_societies.sql"):
        for st in split((ROOT / "sql" / f).read_text()):
            cur.execute(st)
    return conn

for t in sorted((ROOT / "tests").glob("test_*.lua")):
    if only and t.stem not in only:
        continue
    conn = build_db()
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)

    def conv(v):
        if isinstance(v, decimal.Decimal):
            return int(v) if v == v.to_integral_value() else float(v)
        if isinstance(v, (datetime.datetime, datetime.date)):
            return int(datetime.datetime.combine(v, datetime.time()).timestamp() * 1000) if not isinstance(v, datetime.datetime) else int(v.timestamp() * 1000)
        if isinstance(v, bytes):
            return v.decode()
        return v

    def db(mode, query, params, n):
        args = [params[i] for i in range(1, int(n) + 1)]
        cur = conn.cursor(__import__("pymysql").cursors.DictCursor)
        cur.execute(query.replace("?", "%s"), args)
        if mode == "insert":
            return cur.lastrowid
        if mode == "update":
            return cur.rowcount
        rows = [{k: conv(v) for k, v in r.items()} for r in cur.fetchall()]
        if mode == "scalar":
            return next(iter(rows[0].values())) if rows else None
        if mode == "single":
            return lua.table_from(rows[0]) if rows else None
        return lua.table_from([lua.table_from(r) for r in rows])

    lua.globals().ROOT = str(ROOT)
    lua.globals().__db = db
    lua.execute((ROOT / "tests" / "harness.lua").read_text(encoding="utf-8"))
    try:
        lua.execute((ROOT / "tests" / t.name).read_text(encoding="utf-8"))
    except Exception as e:  # noqa
        print(f"[{t.stem}] LAADFOUT: {e}")
        total_fail += 1
        continue
    passed, failed = lua.eval("Test.passed"), lua.eval("Test.failed")
    print(f"[{t.stem}] {passed} geslaagd, {failed} mislukt")
    if failed:
        total_fail += failed
        for i in range(1, int(lua.eval("#Test.failures")) + 1):
            print("   ✗", lua.eval(f"Test.failures[{i}]"))
sys.exit(1 if total_fail else 0)
