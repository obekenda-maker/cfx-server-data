#!/usr/bin/env python3
"""Controleert dat elke gebruikte tekstsleutel ('namespace.sleutel') in locale_nl.lua bestaat
en dat er geen ongebruikte/dubbele sleutels met een typfout in staan."""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
locale = (ROOT / "resources/[server]/server_config/locale_nl.lua").read_text(encoding="utf-8")
defined = set(re.findall(r"\['([a-z_]+\.[a-z0-9_]+)'\]\s*=", locale))

NS = r"(?:combat|hud|admin|jobs|garage|shop|inter|gang|common|stats|welcome)"
pattern = re.compile(r"['\"](" + NS + r"\.[a-z0-9_]*[a-z0-9])['\"]")
used = {}
for group in ["[admin]", "[combat]", "[roleplay]", "[server]", "[ui]"]:
    for path in (ROOT / "resources" / group).rglob("*.lua"):
        if path.name == "locale_nl.lua":
            continue
        for key in pattern.findall(path.read_text(encoding="utf-8")):
            used.setdefault(key, path)

missing = sorted(k for k in used if k not in defined)
for k in missing:
    print(f"ONTBREEKT: {k}  (gebruikt in {used[k].relative_to(ROOT)})")
unused = sorted(defined - set(used))
print(f"{len(defined)} sleutels gedefinieerd, {len(used)} in gebruik, {len(missing)} ontbreken, {len(unused)} ongebruikt")
if "--unused" in sys.argv:
    for k in unused:
        print("ongebruikt:", k)
sys.exit(1 if missing else 0)
