# -*- coding: utf-8 -*-
"""
Chrome eklentisinden gelen arabam.com sayfalarini ilan kaydina cevirir.

arabam.com sunucudan gelen otomatik istekleri Cloudflare ile durdurur.
Bu yuzden ilan verisi, personelin kendi tarayicisinda actigi sayfadan alinir:
eklenti sayfanin metnini gonderir, burada kaziyicinin ayristiricilariyla
(boya/degisen, tramer, Marka/Seri/Model satirlari) okunur ve market_ingest ile kaydedilir.

- Ilan sayfasi  -> tek ilan, tam veri (boya/degisen ve tramer dahil).
- Arama sayfasi -> sayfada gorunen ilanlar emsal olarak (yalnizca fiyat/km/yil; boya bilgisi yok).
Eklenti sayfa gezmez; yalnizca kullanicinin actigi sayfayi okur.
"""
from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
from urllib.parse import urljoin, urlparse

from yerimebak_ai_v5.scrapers.arabam_v4.extractors.damage_extractor import damage_summary, parse_damage_record
from yerimebak_ai_v5.scrapers.arabam_v4.extractors.identity_extractor import package_from_title, parse_identity

MAX_TEXT = 200_000
MAX_CARDS = 120
MAX_PRICE = 500_000_000

_MONTHS = {
    "ocak": 1, "şubat": 2, "mart": 3, "nisan": 4, "mayıs": 5, "haziran": 6,
    "temmuz": 7, "ağustos": 8, "eylül": 9, "ekim": 10, "kasım": 11, "aralık": 12,
}
# Binlik ayirac yalnizca nokta: "62.000 985.000 TL" km ve fiyat olarak ayri okunur
_MONEY = re.compile(r"(?<![\d.])(\d{1,3}(?:\.\d{3})+|\d{4,9})\s*(?:TL|₺)", re.IGNORECASE)
_DAMAGE_WORDS = ("tramer", "hasar")


def is_arabam_url(url: str) -> bool:
    parsed = urlparse(url or "")
    host = (parsed.hostname or "").lower()
    return parsed.scheme in ("http", "https") and (host == "arabam.com" or host.endswith(".arabam.com"))


def is_listing_url(url: str) -> bool:
    return is_arabam_url(url) and "/ilan/" in urlparse(url).path


def _int(value: Any) -> Optional[int]:
    digits = re.sub(r"[^\d]", "", str(value if value is not None else ""))
    return int(digits) if digits else None


def _label(text: str, *labels: str) -> Optional[str]:
    """'Etiket: deger' ya da etiketin alt satirindaki deger (identity_extractor ile ayni bicim)."""
    pattern = "|".join(labels)
    match = re.search(rf"(?:^|\n)[ \t]*(?:{pattern})[ \t]*(?::[ \t]*|\n[ \t]*)([^\n]+)", text or "", re.IGNORECASE)
    value = match.group(1).strip() if match else None
    return value if value and value not in ("-", "Belirtilmemiş") else None


def _listing_date(text: str) -> Optional[str]:
    value = _label(text, r"İlan Tarihi", r"Ilan Tarihi")
    if not value:
        return None
    m = re.match(r"(\d{1,2})\s+([^\s\d]+)\s+(\d{4})", value)
    if m and m.group(2).replace("İ", "i").lower() in _MONTHS:
        return f"{m.group(3)}-{_MONTHS[m.group(2).replace('İ', 'i').lower()]:02d}-{int(m.group(1)):02d}"
    m = re.match(r"(\d{1,2})[./](\d{1,2})[./](\d{4})", value)
    if m:
        return f"{m.group(3)}-{int(m.group(2)):02d}-{int(m.group(1)):02d}"
    return None


def _price_from_text(text: str) -> Optional[int]:
    """Sayfadaki ilk TL tutari; tramer/hasar satirlarindaki tutarlar atlanir."""
    lines = (text or "").split("\n")
    for i, line in enumerate(lines):
        for match in _MONEY.finditer(line):
            context = " ".join(lines[max(0, i - 2):i + 1]).lower()
            if any(word in context for word in _DAMAGE_WORDS):
                continue
            value = _int(match.group(1))
            if value and 10_000 <= value <= MAX_PRICE:
                return value
    return None


def _structured(blocks: Optional[List[Any]]) -> Dict[str, Any]:
    """Sayfadaki JSON-LD (schema.org Car/Product) icinden fiyat, marka, model, km, gorsel."""
    out: Dict[str, Any] = {}
    stack = list(blocks or [])
    while stack:
        node = stack.pop(0)
        if isinstance(node, list):
            stack.extend(node)
            continue
        if not isinstance(node, dict):
            continue
        stack.extend(v for k, v in node.items() if k == "@graph")
        offers = node.get("offers")
        if isinstance(offers, list):
            offers = offers[0] if offers else None
        if isinstance(offers, dict) and not out.get("price"):
            out["price"] = _int(offers.get("price"))
        brand = node.get("brand")
        if isinstance(brand, dict):
            brand = brand.get("name")
        if isinstance(brand, str) and brand.strip() and not out.get("brand"):
            out["brand"] = brand.strip()
        if isinstance(node.get("model"), str) and not out.get("model"):
            out["model"] = node["model"].strip()
        mileage = node.get("mileageFromOdometer")
        if isinstance(mileage, dict):
            mileage = mileage.get("value")
        if mileage is not None and not out.get("km"):
            out["km"] = _int(mileage)
        image = node.get("image")
        if isinstance(image, list):
            image = image[0] if image else None
        if isinstance(image, dict):
            image = image.get("url")
        if isinstance(image, str) and image.startswith("http") and not out.get("image_url"):
            out["image_url"] = image
    return out


def parse_listing_page(
    url: str,
    text: str,
    title: str = "",
    image_url: Optional[str] = None,
    location: Optional[str] = None,
    structured: Optional[List[Any]] = None,
) -> Dict[str, Any]:
    """arabam.com ilan sayfasi metni -> market_ingest.upsert_listings'in bekledigi ilan bicimi."""
    from yerimebak_ai_v5.scrapers.arabam_v4.extractors.paint_extractor import parse_paint_section

    text = (text or "")[:MAX_TEXT]
    ld = _structured(structured)
    identity = parse_identity(text)
    title = (title or "").split("|")[0].strip()
    brand = identity.get("brand") or ld.get("brand")
    model = identity.get("series") or ld.get("model") or (identity.get("model") if not identity.get("series") else None)
    package = identity.get("model") if identity.get("series") else None
    if not package and title and brand and model:
        package = package_from_title(title, brand, model)

    parsed = parse_paint_section(text)
    if parsed["section_found"]:
        painted, changed = parsed["painted_parts"], parsed["changed_parts"]
        if parsed["is_original"]:
            status = "Orijinal"
        elif painted and changed:
            status = "Boyalı ve değişenli"
        elif changed:
            status = "Değişenli"
        elif painted:
            status = "Boyalı"
        else:
            status = None
        paint_info: Optional[Dict[str, Any]] = {
            "has_paint": bool(painted),
            "has_changed": bool(changed),
            "is_original": parsed["is_original"],
            "status": status,
            "painted_parts": painted,
            "local_painted_parts": parsed["local_paint_parts"],
            "changed_parts": changed,
            "paint_count": len(painted),
            "changed_count": len(changed),
        }
    else:
        # Bolum yoksa beyan bilinmiyor: arac orijinal kabul edilmez
        paint_info = None

    damage = parse_damage_record(text)
    km = identity.get("km") or ld.get("km")
    return {
        "source": "arabam",
        "url": url,
        "title": title or None,
        "brand": brand,
        "model": model,
        "package": package,
        "year": identity.get("year"),
        "km": km if km and not (1900 <= km <= 2100) else None,
        "price": ld.get("price") or _price_from_text(text),
        "fuel": _label(text, r"Yakıt Tipi", r"Yakıt"),
        "transmission": _label(text, r"Vites Tipi", r"Vites"),
        "color": _label(text, r"Renk"),
        "location": (location or "").strip() or None,
        "listing_date": _listing_date(text),
        "image_url": image_url if image_url and image_url.startswith("http") else ld.get("image_url"),
        "damage_record": damage,
        "accident_record": damage_summary(damage),
        "paint_info": paint_info,
        "observed_at": datetime.now(timezone.utc).isoformat(),
    }


def parse_search_card(card_url: str, card_text: str, brand: str, model: str) -> Optional[Dict[str, Any]]:
    """Arama sonucundaki tek ilan satiri -> emsal kaydi (boya/tramer bilgisi aramada yoktur)."""
    text = (card_text or "")[:5000]
    price = _price_from_text(text)
    if not price:
        return None
    rest = _MONEY.sub(" ", text)
    max_year = datetime.now().year + 1
    numbers = [n for n in re.findall(r"(?<![\d.,])(\d{1,3}(?:\.\d{3})+|\d+)(?![\d.,])", rest)]
    year = next((int(n) for n in numbers if n.isdigit() and len(n) == 4 and 1990 <= int(n) <= max_year), None)
    km_match = re.search(r"(\d{1,3}(?:\.\d{3})+|\d+)\s*km\b", rest, re.IGNORECASE)
    km = _int(km_match.group(1)) if km_match else next(
        (_int(n) for n in numbers if "." in n and (_int(n) or 0) >= 1000 and not (1900 <= (_int(n) or 0) <= 2100)),
        None,
    )
    # Tablo satirlari sekmeyle, kartlar satir sonuyla ayrilir; baslik ilk uzun metin hucresidir
    cells = [c.strip() for c in re.split(r"[\n\t]+", text) if c.strip()]
    title = next((c for c in cells if len(c) > 8 and not _MONEY.search(c) and re.search(r"[A-Za-zÇĞİÖŞÜçğıöşü]", c)), None)
    return {
        "source": "arabam",
        "url": card_url,
        "title": title,
        "brand": brand,
        "model": model,
        "package": package_from_title(title, brand, model) if title else None,
        "year": year,
        "km": km,
        "price": price,
        "damage_record": None,
        "paint_info": None,
        "observed_at": datetime.now(timezone.utc).isoformat(),
    }


def parse_search_page(page_url: str, cards: List[Dict[str, Any]], brand: str, model: str) -> List[Dict[str, Any]]:
    items: List[Dict[str, Any]] = []
    seen = set()
    for card in (cards or [])[:MAX_CARDS]:
        href = urljoin(page_url, str(card.get("url") or ""))
        if not is_listing_url(href) or href in seen:
            continue
        seen.add(href)
        item = parse_search_card(href, str(card.get("text") or ""), brand, model)
        if item:
            items.append(item)
    return items
