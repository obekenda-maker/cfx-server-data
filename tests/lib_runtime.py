"""Gedeelde helper: bouwt een Lua 5.4-runtime met het mock-harnas en een databasebrug naar MariaDB."""
import datetime, decimal, pathlib, sys
import pymysql
from lupa import lua54

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tests"))
from test_sql import fresh, split  # noqa


def build_db():
    conn = fresh()
    cur = conn.cursor()
    for f in ("01_core.sql", "02_jobs_items.sql", "03_societies.sql"):
        for st in split((ROOT / "sql" / f).read_text()):
            cur.execute(st)
    return conn


def make_runtime(conn):
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)

    def conv(v):
        if isinstance(v, decimal.Decimal):
            return int(v) if v == v.to_integral_value() else float(v)
        if isinstance(v, datetime.datetime):
            return int(v.timestamp() * 1000)
        if isinstance(v, datetime.date):
            return int(datetime.datetime.combine(v, datetime.time()).timestamp() * 1000)
        if isinstance(v, bytes):
            return v.decode()
        return v

    def db(mode, query, params, n):
        args = [params[i] for i in range(1, int(n) + 1)]
        cur = conn.cursor(pymysql.cursors.DictCursor)
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
    return lua


def report(name, lua):
    passed, failed = lua.eval("Test.passed"), lua.eval("Test.failed")
    print(f"[{name}] {passed} geslaagd, {failed} mislukt")
    for i in range(1, int(lua.eval("#Test.failures")) + 1):
        print("   ✗", lua.eval(f"Test.failures[{i}]"))
    return int(failed)
