"""Ilan toplama mantigi (arabam.com; Apify SDK'dan bagimsiz, testlerde dogrudan kullanilir).

Kaziyici kodu musteri_paneli/yerimebak_ai_v5'ten vendor/ klasorune kopyalanir
(musteri_paneli/scripts/apify_sync.py). Cikti, YerimeBak backend'inin
market_ingest servisinin bekledigi tek bicimdir.
"""
from __future__ import annotations

import math
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional
from urllib.parse import urlparse

VENDOR = Path(__file__).resolve().parent.parent / "vendor"
if str(VENDOR) not in sys.path:
    sys.path.insert(0, str(VENDOR))

UNKNOWN = {"", "bilinmiyor", "bilinmeyen", "unknown", "none"}


def detect_source(url: str) -> Optional[str]:
    host = (urlparse(url or "").hostname or "").lower()
    if host == "arabam.com" or host.endswith(".arabam.com"):
        return "arabam"
    return None


def _enum(value: Any) -> Any:
    value = getattr(value, "value", value)
    if isinstance(value, str) and value.strip().lower() in UNKNOWN:
        return None
    return value


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _int(value: Any) -> Optional[int]:
    if value in (None, ""):
        return None
    if isinstance(value, (int, float)):
        return int(value)
    digits = re.sub(r"[^\d]", "", str(value))
    return int(digits) if digits else None


def parse_identity(text: str) -> Dict[str, Any]:
    """Detay sayfasi metnindeki 'Marka / Seri / Model / Yil' satirlari (kaziyicidaki ortak kod)."""
    from yerimebak_ai_v5.scrapers.arabam_v4.extractors.identity_extractor import parse_identity as _parse

    return _parse(text)


def from_arabam(listing: Any, identity: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    from yerimebak_ai_v5.scrapers.arabam_v4.extractors.damage_extractor import damage_summary

    identity = identity or {}
    paint = listing.paint_info
    damage = {
        "tramer_tl": listing.tramer_amount,
        "tramer_yok": listing.no_damage_record,
        "agir_hasar": listing.heavy_damage,
        "kaynak_metin": listing.damage_text,
    }
    brand = listing.brand if listing.brand not in ("Bilinmeyen", None, "") else identity.get("brand")
    model = listing.model if listing.model not in ("Bilinmeyen", None, "") else (
        listing.series or identity.get("series") or identity.get("model")
    )
    package = listing.trim or (identity.get("model") if identity.get("series") else None)
    year = listing.year or identity.get("year")
    return {
        "source": "arabam",
        "url": listing.url,
        "listing_id": listing.listing_id,
        "title": listing.title,
        "brand": brand,
        "model": model,
        "package": package,
        "year": year or None,
        "km": listing.km,
        "price": listing.price,
        "fuel": _enum(listing.fuel_type),
        "transmission": _enum(listing.gear_type),
        "color": _enum(listing.color),
        "location": listing.location,
        "listing_date": listing.listing_date,
        "image_url": listing.image_url,
        # Satici beyani: tramer tutari / tramer yok / agir hasar kayitli
        "damage_record": damage,
        "accident_record": damage_summary(damage),
        "paint_info": {
            "has_paint": bool(paint.has_paint),
            "has_changed": bool(paint.has_changed),
            "is_original": bool(paint.is_original),
            "status": _enum(paint.status),
            "painted_parts": list(paint.painted_parts or []),
            "local_painted_parts": list(paint.local_paint_parts or []),
            "changed_parts": list(paint.changed_parts or []),
            "paint_count": int(paint.paint_count or 0),
            "changed_count": int(paint.changed_count or 0),
        },
        "observed_at": _now(),
    }


async def fetch_arabam_listing(url: str) -> List[Dict[str, Any]]:
    from yerimebak_ai_v5.scrapers.arabam_v4.core.browser_manager import BrowserManager
    from yerimebak_ai_v5.scrapers.arabam_v4.scrapers.arabam_scraper import ArabamScraper

    scraper = ArabamScraper(headless=True, max_listings=1, enable_pagination=False)
    manager = BrowserManager(headless=True)
    await manager.initialize()
    try:
        page = await manager.create_page()
        await page.goto(url, wait_until="domcontentloaded", timeout=60000)
        await scraper._handle_popups(page)
        text = await page.inner_text("body")
        identity = parse_identity(text)
        title = (await page.title() or "").split("|")[0].strip()
        link_info = {
            "url": url,
            "title": title or url,
            "brand": identity.get("brand") or "Bilinmeyen",
            "model": identity.get("series") or identity.get("model") or "Bilinmeyen",
            "year": identity.get("year") or 0,
        }
        listing = await scraper._extract_listing_detail(page, link_info)
        return [from_arabam(listing, identity)] if listing else []
    finally:
        await manager.close()


async def search_comparables(inp: Dict[str, Any]) -> List[Dict[str, Any]]:
    brand = str(inp.get("brand") or "").strip()
    model = str(inp.get("model") or "").strip()
    year = _int(inp.get("year"))
    if not brand or not model or not year:
        raise ValueError("Emsal aramasi icin marka, model ve yil zorunludur")
    window = max(0, min(3, _int(inp.get("yearWindow")) if inp.get("yearWindow") is not None else 1))
    max_items = max(1, min(120, _int(inp.get("maxItems")) or 36))
    years = list(range(year - window, year + window + 1))

    from yerimebak_ai_v5.scrapers.arabam_v4.scrapers.arabam_scraper import ArabamScraper

    per_year = max(1, math.ceil(max_items / len(years)))
    items: List[Dict[str, Any]] = []
    seen = set()
    for y in years:
        result = await ArabamScraper(headless=True, max_listings=per_year, max_pages=2).search(brand, model, y)
        for listing in result.listings:
            if listing.url in seen:
                continue
            seen.add(listing.url)
            items.append(from_arabam(listing))
    return items[:max_items]


async def collect(inp: Dict[str, Any]) -> List[Dict[str, Any]]:
    mode = inp.get("mode") or "emsal"
    if mode == "ilan":
        url = str(inp.get("url") or "").strip()
        source = detect_source(url)
        if source == "arabam":
            return await fetch_arabam_listing(url)
        raise ValueError("Yalnizca arabam.com ilan linkleri desteklenir")
    if mode == "emsal":
        return await search_comparables(inp)
    raise ValueError(f"Bilinmeyen mod: {mode}")
