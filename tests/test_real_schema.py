#!/usr/bin/env python3
"""Echte-schema-test: importeert de ECHTE ESX-SQL (resources/[core]/es_extended + resources/[esx]/*) via scripts/import-sql.sh
in een lege MariaDB-database, twee keer (idempotent), en valideert daarna al onze Lua-SQL-statements met PREPARE.
Slaat over (exit 0, duidelijke melding) als de ESX-resources niet geïnstalleerd zijn (scripts/install-deps.sh)."""
import os, pathlib, re, subprocess, sys
import pymysql
ROOT = pathlib.Path(__file__).resolve().parent.parent
if not (ROOT / "resources/[core]/es_extended/es_extended.sql").exists():
    print("OVERGESLAGEN: ESX-resources niet geïnstalleerd (draai scripts/install-deps.sh)"); sys.exit(0)
DB, USER, PW = "real_schema_test", "rst", "rst-test-pw"
adm = pymysql.connect(unix_socket="/run/mysqld/mysqld.sock", user="root", autocommit=True)
c = adm.cursor()
c.execute(f"DROP DATABASE IF EXISTS {DB}")
c.execute(f"CREATE DATABASE {DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci")
for h in ("127.0.0.1", "localhost"):
    c.execute(f"CREATE USER IF NOT EXISTS '{USER}'@'{h}' IDENTIFIED BY '{PW}'")
    c.execute(f"GRANT ALL ON {DB}.* TO '{USER}'@'{h}'")
env = dict(os.environ, DB_USER=USER, DB_PASS=PW, DB_NAME=DB, DB_HOST="127.0.0.1")
bad = 0
for rnd in (1, 2):
    r = subprocess.run(["bash", str(ROOT / "scripts/import-sql.sh")], env=env, capture_output=True, text=True)
    errs = [l for l in (r.stdout + r.stderr).splitlines() if "FOUT" in l]
    print(f"import ronde {rnd}: exit={r.returncode}, {len(errs)} fout(en)")
    if r.returncode != 0 or errs: bad += 1; print(r.stdout[-1500:], r.stderr[-1500:])
conn = pymysql.connect(unix_socket="/run/mysqld/mysqld.sock", user="root", database=DB, autocommit=True)
cur = conn.cursor()
cur.execute("SELECT COUNT(*) FROM jobs WHERE name IN ('police','ambulance','mechanic','taxi','trucker','courier')")
n = cur.fetchone()[0]; print(f"onze jobs in echte jobs-tabel: {n}/6")
if n != 6: bad += 1
cur.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=%s AND table_name='es_extended'", (DB,))
cur.execute("SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='es_extended'")
if cur.fetchone()[0]: bad += 1; print("FOUT: database 'es_extended' is aangemaakt (USE-regel niet gestript)")
stmts = {}
for g in ("[admin]", "[combat]", "[roleplay]", "[server]", "[ui]"):
    for f in (ROOT / "resources" / g).rglob("*.lua"):
        t = re.sub(r"'\s*\.\.\s*\n?\s*'", "", f.read_text(encoding="utf-8"))
        for m in re.finditer(r"'((?:SELECT|INSERT|UPDATE|DELETE|REPLACE)\b[^'\n]*)'(?!\s*\.\.)", t):
            if "%s" not in m.group(1): stmts.setdefault(m.group(1), f)
for sql, f in stmts.items():
    try:
        cur.execute("PREPARE s FROM %s", (sql,)); cur.execute("DEALLOCATE PREPARE s")
    except Exception as e:
        bad += 1; print(f"FOUT in {f.name}: {e}\n   {sql[:140]}")
print(f"{len(stmts)} statements gevalideerd tegen het ECHTE ESX-schema, {bad} fout(en) in totaal")
c.execute(f"DROP DATABASE {DB}")
sys.exit(1 if bad else 0)
