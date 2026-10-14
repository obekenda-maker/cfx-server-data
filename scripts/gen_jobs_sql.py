#!/usr/bin/env python3
"""Genereert het jobs-deel van sql/02_jobs_items.sql uit JobsCfg.Catalog (resources/[roleplay]/rp_jobs/config.lua).
Gebruik:  python3 scripts/gen_jobs_sql.py          (schrijft het bestand)
          python3 scripts/gen_jobs_sql.py --check  (exit 1 als het bestand afwijkt van de catalogus)
Vereist: pip install lupa"""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "tests"))
from lib_config import ROOT, load, cfg

BEGIN, END = "-- >>> GENERATED JOBS (scripts/gen_jobs_sql.py) – NIET HANDMATIG WIJZIGEN <<<", "-- <<< END GENERATED JOBS >>>"


def rows(catalog, prefix="off"):
    jobs, grades = [], []
    for j in catalog:
        jobs.append((j["name"], j["label"], 1 if j.get("whitelisted") else 0))
        for i, g in enumerate(j["grades"]):
            grades.append((j["name"], i, g["name"], g["label"], g["salary"]))
        if j.get("offDuty"):
            jobs.append((prefix + j["name"], j["label"] + " (af dienst)", 1 if j.get("whitelisted") else 0))
            for i, g in enumerate(j["grades"]):
                grades.append((prefix + j["name"], i, g["name"], g["label"], 0))
    return jobs, grades


def render():
    C = cfg(load(), "JobsCfg")
    jobs, grades = rows(C["Catalog"], C["OffDutyPrefix"])
    q = lambda s: "'" + str(s).replace("'", "''") + "'"
    out = [BEGIN, "INSERT INTO `jobs` (`name`, `label`, `whitelisted`) VALUES"]
    out.append(",\n".join(f"  ({q(n)}, {q(l)}, {w})" for n, l, w in jobs))
    out.append("ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `whitelisted` = VALUES(`whitelisted`);\n")
    names = ",".join(q(n) for n, _, _ in jobs)
    out.append(f"DELETE FROM `job_grades` WHERE `job_name` IN\n  ({names});\n")
    out.append("INSERT INTO `job_grades` (`job_name`, `grade`, `name`, `label`, `salary`, `skin_male`, `skin_female`) VALUES")
    out.append(",\n".join(f"  ({q(j)}, {g}, {q(n)}, {q(l)}, {s}, '{{}}', '{{}}')" for j, g, n, l, s in grades) + ";")
    out.append(END)
    return "\n".join(out)


def main():
    path = ROOT / "sql" / "02_jobs_items.sql"
    text = path.read_text(encoding="utf-8")
    block = render()
    if BEGIN in text:
        a, b = text.index(BEGIN), text.index(END) + len(END)
        new = text[:a] + block + text[b:]
    else:  # eerste keer: vervang het handgeschreven jobs-deel
        a = text.index("INSERT INTO `jobs`")
        b = text.index("-- ---- Items")
        new = text[:a] + block + "\n\n" + text[b:]
    if "--check" in sys.argv:
        if new != text:
            print("sql/02_jobs_items.sql wijkt af van JobsCfg.Catalog – draai scripts/gen_jobs_sql.py"); sys.exit(1)
        print("sql/02_jobs_items.sql komt overeen met JobsCfg.Catalog"); return
    path.write_text(new, encoding="utf-8")
    print("sql/02_jobs_items.sql bijgewerkt:", len(grades_ := rows(cfg(load(), 'JobsCfg')['Catalog'])[1]), "grade-regels")


main()
