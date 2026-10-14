#!/usr/bin/env python3
"""Controleert alle fxmanifest.lua van onze eigen resources:
 - verwezen bestanden bestaan (ook '@resource/pad' naar onze eigen resources, en dat die in `files` staan)
 - dependencies zijn eigen resources of bekende externe resources
 - elke eigen resource staat in server.cfg.example, en NA zijn dependencies"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GROUPS = ["[admin]", "[combat]", "[roleplay]", "[server]", "[ui]"]
EXTERNAL = {"oxmysql", "ox_lib", "es_extended", "esx_society", "esx_status", "esx_basicneeds", "esx_license",
            "esx_addonaccount", "esx_addoninventory", "esx_datastore", "esx_identity", "esx_skin", "skinchanger"}

res = {}
for g in GROUPS:
    for m in (ROOT / "resources" / g).glob("*/fxmanifest.lua"):
        res[m.parent.name] = m.parent

def strings_in_block(text, key):
    out = []
    for m in re.finditer(r"\b" + key + r"\s*(?:\{(.*?)\}|'([^']*)')", text, re.S):
        block = m.group(1) if m.group(1) is not None else "'" + m.group(2) + "'"
        out += re.findall(r"'([^']+)'", block)
    return out

errors = []
manifests = {}
for name, path in res.items():
    text = (path / "fxmanifest.lua").read_text(encoding="utf-8")
    manifests[name] = text
    refs = []
    for key in ("client_scripts", "server_scripts", "shared_scripts", "client_script", "server_script", "shared_script", "files", "ui_page"):
        refs += [(key, r) for r in strings_in_block(text, key)]
    for key, ref in refs:
        if ref.startswith("@"):
            target, _, rel = ref[1:].partition("/")
            if target in res:
                if not (res[target] / rel).exists():
                    errors.append(f"{name}: {ref} bestaat niet")
                elif key != "ui_page" and rel not in strings_in_block(manifests.get(target, (res[target] / 'fxmanifest.lua').read_text()), "files"):
                    errors.append(f"{name}: {ref} staat niet in `files` van {target}")
            elif target not in EXTERNAL:
                errors.append(f"{name}: onbekende externe verwijzing {ref}")
            continue
        if "*" in ref:
            if not list(path.glob(ref)): errors.append(f"{name}: glob {ref} vindt niets")
        elif not (path / ref).exists():
            errors.append(f"{name}: {key} verwijst naar ontbrekend bestand {ref}")
    for dep in strings_in_block(text, "dependencies"):
        if dep not in res and dep not in EXTERNAL:
            errors.append(f"{name}: onbekende dependency {dep}")
    for need in ("fx_version", "game", "lua54"):
        if need not in text:
            errors.append(f"{name}: mist {need}")

cfg = ROOT / "server.cfg.example"
if cfg.exists():
    order = [m.group(1) for m in re.finditer(r"^\s*ensure\s+(\S+)", cfg.read_text(), re.M)]
    for name in res:
        if name not in order:
            errors.append(f"{name}: staat niet in server.cfg.example")
            continue
        idx = order.index(name)
        for dep in strings_in_block(manifests[name], "dependencies"):
            if dep not in order:
                errors.append(f"{name}: dependency {dep} niet in server.cfg.example")
            elif order.index(dep) > idx:
                errors.append(f"{name}: dependency {dep} start NA {name} in server.cfg.example")
else:
    errors.append("server.cfg.example ontbreekt")

for e in errors: print("FOUT:", e)
print(f"{len(res)} resources gecontroleerd, {len(errors)} fout(en)")
sys.exit(1 if errors else 0)
