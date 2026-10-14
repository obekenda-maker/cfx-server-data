"""Leest onze Lua-configbestanden in via lupa (met stubs voor vec3/vec4) en geeft de tabellen terug."""
import pathlib
from lupa import lua54

ROOT = pathlib.Path(__file__).resolve().parent.parent

STUBS = """
function vec3(x,y,z) return {x=x+0.0,y=y+0.0,z=z+0.0} end
function vec4(x,y,z,w) return {x=x+0.0,y=y+0.0,z=z+0.0,w=w+0.0} end
function IsDuplicityVersion() return true end
function GetGameTimer() return 0 end
function AddEventHandler() end
exports = setmetatable({}, {__call=function() end})
"""

FILES = {
    "ServerCfg": ["[server]/server_config/config.lua", "[server]/server_config/locale_nl.lua"],
    "CombatCfg": ["[combat]/combat_core/config.lua"],
    "StatsCfg": ["[combat]/combat_stats/config.lua"],
    "JobsCfg": ["[roleplay]/rp_jobs/config.lua"],
    "GarageCfg": ["[roleplay]/rp_garages/config.lua"],
    "ShopCfg": ["[roleplay]/rp_shops/config.lua"],
    "InterCfg": ["[roleplay]/rp_interactions/config.lua"],
    "GangCfg": ["[roleplay]/rp_gangs/config.lua"],
}
OPTIONAL = {"WelcomeCfg": ["[server]/server_welcome/config.lua", "[server]/server_welcome/rules_nl.lua"]}


def load():
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(STUBS)
    for names in (FILES, OPTIONAL):
        for _, files in names.items():
            for f in files:
                p = ROOT / "resources" / f
                if p.exists():
                    lua.execute(p.read_text(encoding="utf-8"))
    return lua


def to_py(v):
    """Lua-tabel → Python (dict/list)"""
    if lua54.lua_type(v) == "table":
        keys = list(v.keys())
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [to_py(v[i]) for i in range(1, len(keys) + 1)]
        return {k: to_py(v[k]) for k in keys}
    return v


def cfg(lua, name):
    return to_py(lua.globals()[name])
