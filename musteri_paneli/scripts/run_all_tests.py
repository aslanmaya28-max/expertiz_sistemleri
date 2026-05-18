# -*- coding: utf-8 -*-
"""
YerimeBak AI — Test Runner Wrapper
Windows uyumlu, pytest tabanlı test keşfi ve çalıştırma.

Kullanım:
  python scripts/run_all_tests.py
  python scripts/run_all_tests.py --unit
  python scripts/run_all_tests.py --verbose
"""

import sys
import os
import subprocess

# Proje kökünü path'e ekle
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, PROJECT_ROOT)


def run_tests(scope: str = "all", verbose: bool = False, quiet: bool = False):
    """Pytest'i belirtilen kapsamda çalıştır."""
    cmd = [sys.executable, "-m", "pytest"]

    # Kapsam
    if scope == "unit":
        test_path = os.path.join(PROJECT_ROOT, "tests", "unit")
    elif scope == "smoke":
        test_path = os.path.join(PROJECT_ROOT, "tests", "smoke_test.py")
    else:
        test_path = os.path.join(PROJECT_ROOT, "tests")

    cmd.append(test_path)

    # Seviye
    if verbose:
        cmd.append("-v")
    elif quiet:
        cmd.append("-q")
    else:
        cmd.append("-v")

    # Ortak flags
    cmd.extend([
        "--tb=short",
        "--no-header",
        f"--rootdir={PROJECT_ROOT}",
    ])

    print(f"🧪 Running tests: {scope}")
    print(f"   Path: {test_path}")
    print(f"   Command: {' '.join(cmd)}")
    print()

    result = subprocess.run(cmd, cwd=PROJECT_ROOT)
    return result.returncode


def main():
    import argparse
    parser = argparse.ArgumentParser(description="YerimeBak AI Test Runner")
    parser.add_argument("--unit", action="store_true", help="Sadece unit testler")
    parser.add_argument("--smoke", action="store_true", help="Sadece smoke test")
    parser.add_argument("--all", action="store_true", help="Tüm testler (default)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Detaylı çıktı")
    parser.add_argument("-q", "--quiet", action="store_true", help="Sessiz mod")

    args = parser.parse_args()

    if args.smoke:
        scope = "smoke"
    elif args.unit:
        scope = "unit"
    else:
        scope = "all"

    exit_code = run_tests(scope=scope, verbose=args.verbose, quiet=args.quiet)
    sys.exit(exit_code)


if __name__ == "__main__":
    main()