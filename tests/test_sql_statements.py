#!/usr/bin/env python3
"""Haalt ALLE SQL-statements uit onze Lua-code en laat MariaDB ze valideren met PREPARE
(tabel-/kolomnamen en syntaxis), tegen het schema uit sql/01–03 + ESX-stub. Dynamische statements (%s) worden apart gemeld."""
import pathlib, re, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from lib_runtime import ROOT, build_db

conn = build_db()
cur = conn.cursor()
stmts, dynamic = {}, []
for g in ("[admin]", "[combat]", "[roleplay]", "[server]", "[ui]"):
    for f in (ROOT / "resources" / g).rglob("*.lua"):
        text = f.read_text(encoding="utf-8")
        text = re.sub(r"'\s*\.\.\s*\n?\s*'", "", text)          # 'a' .. 'b'  → 'ab'
        for m in re.finditer(r"'((?:SELECT|INSERT|UPDATE|DELETE|REPLACE)\b[^'\n]*)'(?!\s*\.\.)", text):
            sql = m.group(1)
            (dynamic if "%s" in sql else stmts.setdefault(sql, f)) if "%s" not in sql else dynamic.append((sql, f))
# Dynamisch opgebouwde queries: valideer de vormen die de code echt kan genereren
extra = {
    "leaderboard kills": "SELECT name, kills, deaths, best_streak, xp FROM combat_stats  ORDER BY kills DESC, deaths ASC LIMIT ?",
    "leaderboard xp": "SELECT name, kills, deaths, best_streak, xp FROM combat_stats  ORDER BY xp DESC LIMIT ?",
    "leaderboard kd": "SELECT name, kills, deaths, best_streak, xp FROM combat_stats WHERE kills >= ? ORDER BY (kills / GREATEST(deaths, 1)) DESC, kills DESC LIMIT ?",
}
for n in range(1, 5):
    cols = " OR ".join(["license = ?", "discord = ?", "fivem = ?", "steam = ?"][:n])
    extra[f"ban-check met {n} identifier(s)"] = ("SELECT id, reason, UNIX_TIMESTAMP(expires_at) AS expires FROM admin_bans WHERE active = 1 "
        "AND (expires_at IS NULL OR expires_at > NOW()) AND (" + cols + ") ORDER BY id DESC LIMIT 1")
for name, sql in extra.items():
    stmts.setdefault(sql, pathlib.Path(name))
bad = 0
for sql, f in stmts.items():
    try:
        cur.execute("PREPARE s FROM %s", (sql,))
        cur.execute("DEALLOCATE PREPARE s")
    except Exception as e:  # noqa
        bad += 1
        print(f"FOUT in {f}: {e}\n   {sql[:140]}")
print(f"{len(stmts)} SQL-statements gevalideerd tegen MariaDB, {bad} fout(en); {len(dynamic)} dynamische (format) overgeslagen")
for sql, f in dynamic:
    print("   dynamisch:", f.name, sql[:90])
sys.exit(1 if bad or len(stmts) < 40 else 0)
