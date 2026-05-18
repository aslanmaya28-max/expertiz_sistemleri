# -*- coding: utf-8 -*-
"""Syntax check all Python files in yerimebak_ai_v5"""
import py_compile
import os
import sys

ok = 0
fail = 0
fail_list = []

for root, dirs, files in os.walk("yerimebak_ai_v5"):
    if "__pycache__" in root:
        continue
    for f in files:
        if not f.endswith(".py"):
            continue
        path = os.path.join(root, f)
        try:
            py_compile.compile(path, doraise=True)
            ok += 1
        except py_compile.PyCompileError as e:
            fail += 1
            fail_list.append((path, str(e)))
            print(f"FAIL: {path}")

print(f"\nChecked {ok + fail} files: {ok} OK, {fail} FAILED")
if fail_list:
    print("\n--- FAILED FILES ---")
    for p, e in fail_list:
        print(f"  {p}")
        print(f"    {e}")
    sys.exit(1)
else:
    print("All files passed syntax check!")