# -*- coding: utf-8 -*-
from __future__ import annotations

import re
import unicodedata
from typing import Any, Dict, Iterable, Tuple

from yerimebak_ai_v5.workers.turkey_targets import TURKEY_2EL_TARGETS


BRAND_ALIASES = {
    "vw": "Volkswagen",
    "volkswagen": "Volkswagen",
    "mercedes-benz": "Mercedes",
    "mercedes benz": "Mercedes",
    "mercedes": "Mercedes",
    "renault": "Renault",
}

FUEL_ALIASES = {
    "benzin": "petrol",
    "benzinli": "petrol",
    "petrol": "petrol",
    "dizel": "diesel",
    "diesel": "diesel",
    "elektrik": "electric",
    "elektrikli": "electric",
    "electric": "electric",
    "hibrit": "hybrid",
    "hybrid": "hybrid",
    "lpg": "lpg",
}

TRANSMISSION_ALIASES = {
    "manuel": "manual",
    "manual": "manual",
    "duz": "manual",
    "otomatik": "automatic",
    "automatic": "automatic",
    "edc": "automatic",
    "dsg": "automatic",
    "cvt": "automatic",
}

ENGINE_VARIANT_RE = re.compile(r"^\s*\d(?:[.,]\d)?\s*(?:dci|tdi|hdi|tsi|tce|cdti|crdi|multijet|bluehdi)?\s*$", re.I)


def normalize_listing_vehicle(listing: Dict[str, Any]) -> Dict[str, Any]:
    raw_brand = str(listing.get("brand") or "").strip()
    raw_model = str(listing.get("model") or "").strip()
    raw_title = str(listing.get("title") or listing.get("description") or "").strip()

    brand = normalize_brand(raw_brand)
    model, confidence = normalize_model(brand, raw_model, raw_title)

    return {
        "normalized_brand": brand,
        "normalized_model": model,
        "normalized_fuel": normalize_fuel(listing.get("fuel") or listing.get("fuel_type")),
        "normalized_transmission": normalize_transmission(listing.get("transmission")),
        "normalized_segment": find_segment(brand, model),
        "model_confidence": confidence,
    }


def normalize_brand(value: str) -> str:
    cleaned = _clean_text(value)
    if cleaned in BRAND_ALIASES:
        return BRAND_ALIASES[cleaned]

    for target_brand, _, _, _ in _iter_targets():
        if _clean_text(target_brand) == cleaned:
            return target_brand

    return value.strip().title() if value else "unknown_brand"


def normalize_model(brand: str, model: str, title: str = "") -> Tuple[str, int]:
    candidates = [m for b, m, _, _ in _iter_targets() if b == brand]
    model_clean = _clean_text(model)
    title_clean = _clean_text(title)

    if not model_clean:
        return _find_model_in_text(candidates, title_clean, 70)

    for candidate in _sorted_models(candidates):
        candidate_clean = _clean_text(candidate)
        if model_clean == candidate_clean or model_clean.startswith(candidate_clean + " "):
            return candidate, 95

    if ENGINE_VARIANT_RE.match(model):
        return _find_model_in_text(candidates, title_clean, 75)

    recovered, confidence = _find_model_in_text(candidates, f"{model_clean} {title_clean}", 80)
    if recovered != "unknown_model":
        return recovered, confidence

    return model.strip().title(), 55


def normalize_fuel(value: Any) -> str:
    cleaned = _clean_text(str(value or ""))
    for key, normalized in FUEL_ALIASES.items():
        if key in cleaned:
            return normalized
    return "unknown"


def normalize_transmission(value: Any) -> str:
    cleaned = _clean_text(str(value or ""))
    for key, normalized in TRANSMISSION_ALIASES.items():
        if key in cleaned:
            return normalized
    return "unknown"


def find_segment(brand: str, model: str) -> str:
    for target_brand, target_model, segment, _ in _iter_targets():
        if target_brand == brand and target_model == model:
            return segment
    return "unknown"


def _find_model_in_text(candidates: Iterable[str], text: str, confidence: int) -> Tuple[str, int]:
    if not text:
        return "unknown_model", 20

    for candidate in _sorted_models(candidates):
        if _clean_text(candidate) in text:
            return candidate, confidence

    return "unknown_model", 20


def _sorted_models(models: Iterable[str]) -> list[str]:
    return sorted(set(models), key=len, reverse=True)


def _iter_targets():
    for target in TURKEY_2EL_TARGETS:
        if isinstance(target, dict):
            yield target.get("brand"), target.get("model"), target.get("segment"), target.get("priority", 3)
        else:
            yield target


def _clean_text(value: str) -> str:
    normalized = unicodedata.normalize("NFKD", value or "")
    ascii_value = normalized.encode("ascii", "ignore").decode("ascii")
    return re.sub(r"\s+", " ", ascii_value.lower()).strip()
