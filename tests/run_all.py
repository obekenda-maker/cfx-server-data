#!/usr/bin/env python3
"""Draait ALLE controles: syntax, manifesten, teksten, SQL en de Lua-tests (echte MariaDB nodig)."""
import pathlib, subprocess, sys

HERE = pathlib.Path(__file__).resolve().parent
steps = [("syntax", "syntax_check.py"), ("lint (luacheck)", "check_lint.py"), ("manifesten", "check_manifests.py"),
         ("kruisverwijzingen (exports/events/callbacks)", "check_crossrefs.py"), ("teksten", "check_locale.py"),
         ("geheimen", "check_secrets.py"), ("configbestanden", "check_config.py"), ("jobcatalogus", "check_jobs.py"), ("zones (RP-bescherming)", "check_zones.py"),
         ("economie-beleid", "check_economy.py"), ("sql", "test_sql.py"), ("sql-statements", "test_sql_statements.py"), ("lua-tests", "run_tests.py"),
         ("herstart-persistentie", "test_restart.py"), ("NUI HUD (Chromium)", "test_nui.py"), ("NUI welkom (Chromium)", "test_nui_welcome.py"),
         ("welkomstdocumenten (drift)", "gen_welcome_check.py")]
failed = []
for name, script in steps:
    print(f"\n=== {name} ===")
    if subprocess.call([sys.executable, str(HERE / script)]) != 0:
        failed.append(name)
print("\nRESULTAAT:", "ALLES GESLAAGD" if not failed else "MISLUKT: " + ", ".join(failed))
sys.exit(1 if failed else 0)
