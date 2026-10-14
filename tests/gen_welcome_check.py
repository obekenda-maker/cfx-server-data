#!/usr/bin/env python3
"""Controleert dat docs/SERVERREGELS.md, WELKOM.md en welkom.html overeenkomen met de bron (rules_nl.lua + locale)."""
import pathlib, subprocess, sys
r = subprocess.run([sys.executable, str(pathlib.Path(__file__).resolve().parent.parent / "scripts/gen_welcome_docs.py"), "--check"], capture_output=True, text=True)
print((r.stdout + r.stderr).strip()); sys.exit(r.returncode)
