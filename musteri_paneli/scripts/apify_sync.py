"""Apify actor'une kaziyici kodunu kopyalar (tek kaynak: musteri_paneli/yerimebak_ai_v5).

Apify, actor klasorunu tek basina derler; bu yuzden kaziyici dosyalari actor'un
vendor/ klasorune kopyalanir. Kaziyiciyi degistirdikten sonra calistirin:

    python musteri_paneli/scripts/apify_sync.py

tests/unit/test_apify_actor.py kopyalarin guncel oldugunu denetler.
"""
from __future__ import annotations

import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "musteri_paneli"
TARGET = ROOT / "apify" / "yerimebak-arac-verisi" / "vendor"

# Actor'un ihtiyac duydugu dosyalar (paket ici importlarla birlikte)
FILES = [
    "yerimebak_ai_v5/__init__.py",
    "yerimebak_ai_v5/scrapers/__init__.py",
    "yerimebak_ai_v5/scrapers/borusan_smart.py",
    "yerimebak_ai_v5/core/__init__.py",
    "yerimebak_ai_v5/core/logger.py",
    "yerimebak_ai_v5/core/rate_limiter.py",
    "yerimebak_ai_v5/core/security/__init__.py",
    "yerimebak_ai_v5/core/security/rate_limiter.py",
    "yerimebak_ai_v5/core/utils/__init__.py",
    "yerimebak_ai_v5/core/utils/logger.py",
]
TREES = ["yerimebak_ai_v5/scrapers/arabam_v4"]


def source_files() -> list[str]:
    files = list(FILES)
    for tree in TREES:
        for path in sorted((SOURCE / tree).rglob("*.py")):
            files.append(path.relative_to(SOURCE).as_posix())
    return files


def sync() -> list[str]:
    if TARGET.exists():
        shutil.rmtree(TARGET)
    copied = []
    for rel in source_files():
        dest = TARGET / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(SOURCE / rel, dest)
        copied.append(rel)
    return copied


if __name__ == "__main__":
    names = sync()
    print(f"{len(names)} dosya kopyalandi -> {TARGET.relative_to(ROOT)}")
    sys.exit(0)
