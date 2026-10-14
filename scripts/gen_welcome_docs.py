#!/usr/bin/env python3
"""Genereert docs/SERVERREGELS.md, docs/WELKOM.md en docs/welkom.html uit WelcomeRules + de onboarding-teksten.
Gebruik:  python3 scripts/gen_welcome_docs.py          (schrijven)
          python3 scripts/gen_welcome_docs.py --check  (exit 1 bij afwijking)"""
import html, pathlib, re, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "tests"))
from lib_config import ROOT, load, cfg

L = load()
W, rules, S = cfg(L, "WelcomeCfg"), cfg(L, "WelcomeRules"), cfg(L, "ServerCfg")
loc, name, version = S["Locale"], S["Server"]["name"], W["Rules"]["version"]
discord = S["Server"]["discord"]

def step_text(key):  # %s → servernaam
    return loc[f"welcome.step_{key}_text"].replace("%s", name)

# ---------------- SERVERREGELS.md ----------------
md = [f"# Serverregels – {name}", "", f"*Regelversie {version}. Wie de server betreedt gaat hiermee akkoord (in het spel via de akkoord-pagina).*", ""]
for i, sec in enumerate(rules, 1):
    md.append(f"## {i}. {sec['title']}")
    md += [f"{j}. {it}" for j, it in enumerate(sec["items"], 1)]
    md.append("")
md += ["---", f"Vragen, klachten of een bug gevonden? Open een ticket op Discord: {discord}", ""]
rules_md = "\n".join(md)

# ---------------- WELKOM.md ----------------
w = [f"# Welkom bij {name}", "", "Nederlandse ESX-server die **roleplay** combineert met **vrijwillige PvP**.", "",
     f"* Discord: {discord}", "* Regels: zie `SERVERREGELS.md` (in het spel: `/regels`)", "* Hulp: `/help`, uitleg bij je baan: `/baan`, uitleg voor nieuwe spelers: `/welkom`", "",
     "## Zo begin je", ""]
for i, st in enumerate(W["Steps"], 1):
    w.append(f"### {i}. {loc[f'welcome.step_{st['key']}_title']}")
    w.append(re.sub(r"`([^`]+)`", r"`\1`", step_text(st["key"]).replace("\n", "\n\n")))
    w.append("")
w += ["## Commando's", ""]
for g in W["Help"]:
    w += [f"**{loc[g['group']]}**", ""] + [f"* `{c}` – {loc[k]}" for c, k in g["items"]] + [""]
welkom_md = "\n".join(w)

# ---------------- welkom.html ----------------
def inline(text):
    t = html.escape(text)
    t = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", t)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", t)
h = [f"<!doctype html><html lang=\"nl\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Welkom bij {html.escape(name)}</title>",
     "<style>body{margin:0;background:#0b0e14;color:#f4f6fa;font:16px/1.6 'Segoe UI',Roboto,Arial,sans-serif}main{max-width:860px;margin:0 auto;padding:32px 20px 64px}",
     "h1{color:#ff6a00;letter-spacing:.04em}h2{color:#2d9cff;margin-top:34px}h3{margin-top:22px}code{background:#1b2230;padding:1px 6px;border-radius:5px;color:#ff9a4d}",
     ".card{background:#121823;border:1px solid #232c3d;border-left:3px solid #ff6a00;border-radius:10px;padding:14px 18px;margin:12px 0}a{color:#2d9cff}li{margin:4px 0}small{color:#9aa4b2}</style></head><body><main>",
     f"<h1>Welkom bij {html.escape(name)}</h1><p>Nederlandse ESX-server die <b>roleplay</b> combineert met <b>vrijwillige PvP</b>. Discord: <a href=\"{html.escape(discord)}\">{html.escape(discord)}</a></p>",
     "<h2>Zo begin je</h2>"]
for i, st in enumerate(W["Steps"], 1):
    paras = "".join(f"<p>{inline(p)}</p>" for p in step_text(st["key"]).split("\n") if p.strip())
    h.append(f"<div class=\"card\"><h3>{i}. {html.escape(loc[f'welcome.step_{st['key']}_title'])}</h3>{paras}</div>")
h.append("<h2>Serverregels</h2>")
for i, sec in enumerate(rules, 1):
    items = "".join(f"<li>{html.escape(it)}</li>" for it in sec["items"])
    h.append(f"<h3>{i}. {html.escape(sec['title'])}</h3><ol>{items}</ol>")
h.append("<h2>Commando's</h2>")
for g in W["Help"]:
    rows = "".join(f"<li><code>{html.escape(c)}</code> – {html.escape(loc[k])}</li>" for c, k in g["items"])
    h.append(f"<h3>{html.escape(loc[g['group']])}</h3><ul>{rows}</ul>")
h.append(f"<p><small>Regelversie {version}. Vragen of een bug gevonden? Open een ticket op Discord.</small></p></main></body></html>")
welkom_html = "\n".join(h)

targets = {"SERVERREGELS.md": rules_md, "WELKOM.md": welkom_md, "welkom.html": welkom_html}
bad = False
for fn, content in targets.items():
    p = ROOT / "docs" / fn
    cur = p.read_text(encoding="utf-8") if p.exists() else None
    if "--check" in sys.argv:
        if cur != content + "\n" if not content.endswith("\n") else cur != content:
            print(f"docs/{fn} wijkt af van de bron – draai scripts/gen_welcome_docs.py"); bad = True
    else:
        p.write_text(content if content.endswith("\n") else content + "\n", encoding="utf-8")
if "--check" in sys.argv:
    print("welkomstdocumenten komen overeen met de bron" if not bad else "")
    sys.exit(1 if bad else 0)
print("docs/SERVERREGELS.md, docs/WELKOM.md en docs/welkom.html geschreven")
