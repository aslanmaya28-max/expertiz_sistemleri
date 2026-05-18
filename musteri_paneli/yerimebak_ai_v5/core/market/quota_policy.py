# -*- coding: utf-8 -*-
from __future__ import annotations

from typing import Dict, List, Tuple

from yerimebak_ai_v5.workers.turkey_targets import TURKEY_2EL_TARGETS


MODEL_TARGET_TOTAL = 30
BUCKET_TARGET_COUNT = 10
RETENTION_DAYS = 27

STANDARD_YEAR_BUCKETS = [(2012, 2016), (2017, 2021), (2022, 2026)]
EV_YEAR_BUCKETS = [(2020, 2022), (2023, 2026)]


def get_year_buckets_for_segment(segment: str) -> List[Tuple[int, int]]:
    return EV_YEAR_BUCKETS if segment == "EV" else STANDARD_YEAR_BUCKETS


def get_year_bucket(year: int, segment: str) -> str:
    for start, end in get_year_buckets_for_segment(segment):
        if start <= int(year) <= end:
            return f"{start}-{end}"
    return "out_of_scope"


def get_balance_targets(segment: str) -> Dict[str, Dict[str, int]]:
    if segment == "EV":
        return {"fuel": {}, "transmission": {}}
    if segment == "Ticari":
        return {"fuel": {"diesel": 7, "other": 3}, "transmission": {"manual": 6, "automatic": 4}}
    return {"fuel": {"petrol": 5, "diesel": 5}, "transmission": {"automatic": 5, "manual": 5}}


def find_segment_for_vehicle(brand: str, model: str) -> str:
    normalized_brand = (brand or "").strip().lower()
    normalized_model = (model or "").strip().lower()

    for target_brand, target_model, segment, _ in _iter_targets():
        if (target_brand or "").strip().lower() == normalized_brand and (target_model or "").strip().lower() == normalized_model:
            return segment or "C"

    return "C"


def _iter_targets():
    for target in TURKEY_2EL_TARGETS:
        if isinstance(target, dict):
            yield target.get("brand"), target.get("model"), target.get("segment"), target.get("priority", 3)
        else:
            yield target
