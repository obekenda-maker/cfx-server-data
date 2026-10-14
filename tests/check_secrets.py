#!/usr/bin/env python3
"""Controleert dat er geen geheimen in de repo staan en dat ze alleen via server-convars worden gelezen."""
import pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
files = subprocess.check_output(["git", "ls-files", "-co", "--exclude-standard"], cwd=ROOT, text=True).splitlines()
PATTERNS = {
    "Discord-webhook-URL": r"discord(?:app)?\.com/api/webhooks/\d+/[\w-]+",
    "Database-URI met wachtwoord": r"mysql://[^:\s'\"/]+:(?!WACHTWOORD|PASSWORD|wachtwoord)[^@\s'\"]{3,}@",
    "Cfx licentiesleutel": r"cfxk_[A-Za-z0-9]{12,}",
    "sv_licenseKey met waarde": r"sv_licenseKey\s+\"(?!cfxk_VERVANG_DIT)[^\"]{8,}\"",
}
errors = []
for f in files:
    if f.endswith((".png", ".woff2", ".woff", ".lock", ".proto")) or "/vendor/" in f or f.startswith("docs/CFX_"):
        continue
    try:
        text = (ROOT / f).read_text(encoding="utf-8")
    except Exception:
        continue
    for name, pat in PATTERNS.items():
        if re.search(pat, text):
            errors.append(f"{f}: {name}")

if any(f in ("secrets.cfg", "server.cfg", ".env") for f in files):
    errors.append("secrets.cfg/server.cfg/.env zit in git")
gi = (ROOT / ".gitignore").read_text()
for need in ("*.cfg", "secrets.cfg", ".env"):
    if need not in gi:
        errors.append(f".gitignore mist {need}")

# Convars met geheimen mogen alleen op de SERVER gelezen worden (niet in client/shared scripts)
for f in files:
    if not f.endswith(".lua") or not any(f.startswith(f"resources/{g}/") for g in ("[admin]", "[combat]", "[roleplay]", "[server]", "[ui]")):
        continue
    text = (ROOT / f).read_text(encoding="utf-8")
    if "GetConvar" in text and not f.endswith("server_logs/server.lua") and "/server/" not in f and not f.endswith("server.lua"):
        errors.append(f"{f}: GetConvar buiten servercode")
    if "setr " in text:
        errors.append(f"{f}: 'setr' (repliceert naar clients)")
for f in ("server.cfg.example", "secrets.cfg.example"):
    for line in (ROOT / f).read_text().splitlines():
        if line.strip().startswith("setr") and re.search(r"(?i)mysql|webhook|licen", line):
            errors.append(f"{f}: geheim via setr: {line.strip()}")

for e in errors: print("FOUT:", e)
print(f"{len(files)} bestanden gecontroleerd op geheimen, {len(errors)} fout(en)")
sys.exit(1 if errors else 0)
