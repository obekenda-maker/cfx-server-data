#!/usr/bin/env python3
"""Draait alle Lua-tests (tests/test_*.lua) onder Lua 5.4 met het mock-harnas."""
import pathlib, sys
from lupa import lua54

ROOT = pathlib.Path(__file__).resolve().parent.parent
TESTS = sorted((ROOT / "tests").glob("test_*.lua"))
only = sys.argv[1:]
total_fail = 0
for t in TESTS:
    if only and t.stem not in only:
        continue
    lua = lua54.LuaRuntime(unpack_returned_tuples=True)
    lua.globals().ROOT = str(ROOT)
    lua.execute((ROOT / "tests" / "harness.lua").read_text(encoding="utf-8"))
    try:
        lua.execute((ROOT / "tests" / t.name).read_text(encoding="utf-8"))
    except Exception as e:  # noqa
        print(f"[{t.stem}] LAADFOUT: {e}")
        total_fail += 1
        continue
    passed = lua.eval("Test.passed")
    failed = lua.eval("Test.failed")
    print(f"[{t.stem}] {passed} geslaagd, {failed} mislukt")
    if failed:
        total_fail += failed
        for i in range(1, int(lua.eval("#Test.failures")) + 1):
            print("   ✗", lua.eval(f"Test.failures[{i}]"))
sys.exit(1 if total_fail else 0)
