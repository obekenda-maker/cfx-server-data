#!/usr/bin/env python3
"""Shell-scripts: shellcheck + echte tests van backup/restore en import-sql tegen de lokale MariaDB."""
import pathlib, shutil, subprocess, sys
ROOT = pathlib.Path(__file__).resolve().parent.parent
fail = 0
files = sorted(str(p) for p in list((ROOT / "scripts").glob("*.sh")) + list((ROOT / "tests").glob("*.sh")))
if shutil.which("shellcheck"):
    r = subprocess.run(["shellcheck", "-x", *files], capture_output=True, text=True)
    print(f"shellcheck: {len(files)} scripts, {'0 meldingen' if r.returncode == 0 else 'MELDINGEN'}")
    if r.returncode: print(r.stdout); fail += 1
else:
    print("shellcheck OVERGESLAGEN (niet geïnstalleerd)")
for t in ("test_backup.sh", "test_import_script.sh"):
    r = subprocess.run(["bash", str(ROOT / "tests" / t)], capture_output=True, text=True)
    last = [l for l in r.stdout.strip().splitlines() if l.strip()][-1] if r.stdout.strip() else r.stderr.strip()
    print(last)
    if r.returncode: print(r.stdout[-1500:], r.stderr[-500:]); fail += 1
sys.exit(1 if fail else 0)
