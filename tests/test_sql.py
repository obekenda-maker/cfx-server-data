#!/usr/bin/env python3
"""Importeert sql/01..03 in een echte MariaDB (test-database) – tweemaal, om idempotentie te bewijzen."""
import pathlib, sys, pymysql

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOCK = "/run/mysqld/mysqld.sock"

def split(sql):
    out, cur = [], []
    for line in sql.splitlines():
        if line.strip().startswith("--") or not line.strip():
            continue
        cur.append(line)
        if line.rstrip().endswith(";"):
            out.append("\n".join(cur)); cur = []
    return out

def connect(db=None):
    return pymysql.connect(unix_socket=SOCK, user="root", database=db, autocommit=True)

def fresh():
    c = connect(); cur = c.cursor()
    cur.execute("DROP DATABASE IF EXISTS cfx_test"); cur.execute("CREATE DATABASE cfx_test CHARACTER SET utf8mb4")
    c.close()
    c = connect("cfx_test"); cur = c.cursor()
    for st in split((ROOT / "tests/esx_stub.sql").read_text()): cur.execute(st)
    return c

if __name__ == "__main__":
    c = fresh(); cur = c.cursor(); bad = 0
    for run in (1, 2):
        for f in ("01_core.sql", "02_jobs_items.sql", "03_societies.sql"):
            for st in split((ROOT / "sql" / f).read_text()):
                try: cur.execute(st)
                except Exception as e:
                    bad += 1; print(f"FOUT run{run} {f}: {e}\n  {st[:90]}")
    cur.execute("SELECT COUNT(*) FROM job_grades WHERE job_name='police'"); n = cur.fetchone()[0]
    cur.execute("SELECT COUNT(*) FROM jobs"); jobs = cur.fetchone()[0]
    cur.execute("SHOW TABLES"); tables = sorted(r[0] for r in cur.fetchall())
    print("tabellen:", ", ".join(tables))
    print(f"police grades na 2 imports: {n} (verwacht 5), jobs: {jobs}, fouten: {bad}")
    sys.exit(1 if bad or n != 5 else 0)
