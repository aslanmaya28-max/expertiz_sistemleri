# -*- coding: utf-8 -*-
"""
Apify'dan gelen ilanlari veritabanina yazar (tek ilan + guncel emsaller).

- Emsal ilanlar listings tablosuna status='emsal' ile yazilir: vitrinde gorunmez,
  degerleme motoru (MarketReferenceService) bunlari dogrudan kullanir.
- Musterinin paylastigi ilan status='talep' ile yazilir.
- Vitrin icin daha once cekilmis bir ilanin durumu degistirilmez.
- Fiyat degisince eski fiyat price_history'ye yazilir (6/12 aylik seri icin).
- Ayni arac icin emsaller APIFY_REFRESH_HOURS (varsayilan 24) icinde tekrar cekilmez.
"""
from __future__ import annotations

import json
import logging
import os
import re
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Iterable, List, Optional
from urllib.parse import urlparse, urlunparse

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.services import apify_service

logger = logging.getLogger(__name__)

PROTECTED_STATUSES = ("active", "featured", "hidden", "sold")
_UNKNOWN = {"", "bilinmiyor", "bilinmeyen", "unknown", "none", "null"}
_schema_ready = False


def _ensure_schema(cursor: Any) -> None:
    global _schema_ready
    if _schema_ready:
        return
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS market_refresh (
            key TEXT PRIMARY KEY,
            refreshed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            item_count INTEGER NOT NULL DEFAULT 0,
            run_id TEXT,
            usage_usd DOUBLE PRECISION,
            error TEXT
        )
        """
    )
    # Eski kurulumlarda bulunmayabilecek ilan sutunlari (init.sql disinda kurulan tablolar)
    for column, col_type in (
        ("series", "TEXT"), ("title", "TEXT"), ("image_url", "TEXT"), ("location", "TEXT"),
        ("listing_date", "TEXT"), ("accident_record", "TEXT"), ("heavy_damage", "TEXT"),
        ("damage_info", "TEXT"), ("paint_info", "TEXT"), ("status", "TEXT DEFAULT 'active'"),
        ("scraped_at", "TIMESTAMP"), ("fuel_type", "TEXT"),
    ):
        cursor.execute(f"ALTER TABLE listings ADD COLUMN IF NOT EXISTS {column} {col_type}")
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS price_history (
            id SERIAL PRIMARY KEY,
            listing_id INTEGER REFERENCES listings(id) ON DELETE CASCADE,
            price INTEGER,
            recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """
    )
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_price_history_listing ON price_history(listing_id, recorded_at)")
    _schema_ready = True


def normalize_url(url: str) -> str:
    """https + kucuk harf, sorgu/parca yok: ayni ilanin farkli linkleri tek kayda duser."""
    url = (url or "").strip()
    if url and not re.match(r"^https?://", url, re.I):
        url = "https://" + url
    parsed = urlparse(url)
    if not parsed.netloc:
        return ""
    return urlunparse(("https", parsed.netloc.lower(), parsed.path.rstrip("/").lower(), "", "", ""))


def _clean_text(value: Any) -> Optional[str]:
    if value is None:
        return None
    text = str(value).strip()
    return None if text.lower() in _UNKNOWN else text


def _int(value: Any) -> Optional[int]:
    if value in (None, ""):
        return None
    if isinstance(value, (int, float)):
        return int(value)
    digits = re.sub(r"[^\d]", "", str(value))
    return int(digits) if digits else None


def normalize_item(item: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Actor ciktisini listings satirina cevirir; fiyat, marka veya model yoksa None."""
    url = normalize_url(str(item.get("url") or ""))
    brand = _clean_text(item.get("brand"))
    model = _clean_text(item.get("model"))
    price = _int(item.get("price"))
    if not url or not brand or not model or not price or price <= 0:
        return None
    year = _int(item.get("year"))
    if year and not (1950 <= year <= 2100):
        year = None
    paint = item.get("paint_info") if isinstance(item.get("paint_info"), dict) else None
    damage = item.get("damage_record") if isinstance(item.get("damage_record"), dict) else None
    source = (item.get("source") or "").lower()
    return {
        "url": url,
        "source": source or "arabam",
        "brand": brand,
        "model": model,
        "series": _clean_text(item.get("package")),
        "year": year,
        "km": _int(item.get("km")),
        "price": price,
        "fuel": _clean_text(item.get("fuel")),
        "transmission": _clean_text(item.get("transmission")),
        "color": _clean_text(item.get("color")),
        "title": _clean_text(item.get("title")) or f"{brand} {model}",
        "location": _clean_text(item.get("location")),
        "listing_date": _clean_text(item.get("listing_date")),
        "image_url": _clean_text(item.get("image_url")),
        # "Tramerli: 12500 TL" / "Ağır hasar kayıtlı": emsal sınıflandırması bu metni okur
        "accident_record": _clean_text(item.get("accident_record")),
        "heavy_damage": "Ağır hasar kayıtlı" if (damage or {}).get("agir_hasar") else None,
        "damage_info": json.dumps(damage, ensure_ascii=False) if damage and any(v is not None for v in damage.values()) else None,
        "paint_info": json.dumps(paint, ensure_ascii=False) if paint else None,
    }


_COLUMNS = (
    "url", "source", "brand", "model", "series", "year", "km", "price", "fuel", "transmission",
    "color", "title", "location", "listing_date", "image_url", "accident_record", "heavy_damage",
    "damage_info", "paint_info",
)


def upsert_listings(items: Iterable[Dict[str, Any]], status: str) -> List[Dict[str, Any]]:
    """Ilanlari yazar/gunceller; yazilan satirlari (id dahil) dondurur."""
    rows = [row for row in (normalize_item(it) for it in items) if row]
    if not rows:
        return []
    saved: List[Dict[str, Any]] = []
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_schema(cursor)
        for row in rows:
            cursor.execute("SELECT id, price, status FROM listings WHERE url = %s FOR UPDATE", (row["url"],))
            existing = cursor.fetchone()
            values = [row[c] for c in _COLUMNS]
            if existing:
                existing = dict(existing)
                new_status = existing["status"] if existing.get("status") in PROTECTED_STATUSES else status
                assignments = ", ".join(f"{c} = COALESCE(%s, {c})" for c in _COLUMNS[1:])
                cursor.execute(
                    f"UPDATE listings SET {assignments}, status = %s, fuel_type = COALESCE(%s, fuel_type), "
                    "scraped_at = NOW(), updated_at = NOW() WHERE id = %s",
                    values[1:] + [new_status, row["fuel"], existing["id"]],
                )
                if existing.get("price") and int(existing["price"]) != row["price"]:
                    cursor.execute(
                        "INSERT INTO price_history (listing_id, price) VALUES (%s, %s)", (existing["id"], row["price"])
                    )
                listing_id = existing["id"]
            else:
                placeholders = ", ".join(["%s"] * len(_COLUMNS))
                cursor.execute(
                    f"INSERT INTO listings ({', '.join(_COLUMNS)}, fuel_type, status, scraped_at, created_at, updated_at) "
                    f"VALUES ({placeholders}, %s, %s, NOW(), NOW(), NOW()) RETURNING id",
                    values + [row["fuel"], status],
                )
                listing_id = dict(cursor.fetchone())["id"]
                cursor.execute("INSERT INTO price_history (listing_id, price) VALUES (%s, %s)", (listing_id, row["price"]))
            saved.append({**row, "id": listing_id})
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        DatabaseConfig.return_connection(conn)
    return saved


def _refresh_key(source: str, brand: str, model: str, year: Optional[int]) -> str:
    return "|".join([source, brand.strip().lower(), model.strip().lower(), str(year or "")])


def _recently_refreshed(key: str, hours: float) -> Optional[Dict[str, Any]]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_schema(cursor)
        cursor.execute("SELECT * FROM market_refresh WHERE key = %s", (key,))
        row = cursor.fetchone()
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    if not row:
        return None
    row = dict(row)
    refreshed = row["refreshed_at"]
    if refreshed.tzinfo is None:
        refreshed = refreshed.replace(tzinfo=timezone.utc)
    if row.get("error") or datetime.now(timezone.utc) - refreshed > timedelta(hours=hours):
        return None
    return row


def _record_refresh(key: str, count: int, run: Dict[str, Any], error: Optional[str]) -> None:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_schema(cursor)
        cursor.execute(
            """
            INSERT INTO market_refresh (key, refreshed_at, item_count, run_id, usage_usd, error)
            VALUES (%s, NOW(), %s, %s, %s, %s)
            ON CONFLICT (key) DO UPDATE SET refreshed_at = NOW(), item_count = EXCLUDED.item_count,
                run_id = EXCLUDED.run_id, usage_usd = EXCLUDED.usage_usd, error = EXCLUDED.error
            """,
            (key, count, run.get("id"), run.get("usage_usd"), error),
        )
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)


def refresh_comparables(brand: str, model: str, year: Optional[int]) -> Dict[str, Any]:
    """Degerlemeden once guncel emsalleri Apify ile arabam.com'dan ceker.

    Hata durumunda degerleme durmaz: mevcut veritabani verisiyle devam edilir ve
    sebep sonuc ozetinde doner (admin ekraninda gosterilir).
    """
    summary: Dict[str, Any] = {"enabled": apify_service.enabled(), "mode": apify_service.mode(), "sources": []}
    if not summary["enabled"] or not brand or not model or not year:
        return summary
    hours = float(os.getenv("APIFY_REFRESH_HOURS") or 24)
    window = int(os.getenv("APIFY_YEAR_WINDOW") or 1)
    max_items = int(os.getenv("APIFY_MAX_ITEMS") or 36)
    for source in ("arabam",):
        key = _refresh_key(source, brand, model, year)
        cached = _recently_refreshed(key, hours)
        if cached:
            summary["sources"].append({"source": source, "cached": True, "count": cached["item_count"],
                                       "refreshed_at": cached["refreshed_at"].isoformat()})
            continue
        run_input = {"mode": "emsal", "source": source, "brand": brand, "model": model, "year": int(year),
                     "yearWindow": window, "maxItems": max_items}
        try:
            result = apify_service.run_actor(run_input)
            saved = upsert_listings(result["items"], status="emsal")
            _record_refresh(key, len(saved), result["run"], None)
            summary["sources"].append({"source": source, "cached": False, "count": len(saved),
                                       "run_id": result["run"].get("id"), "usage_usd": result["run"].get("usage_usd")})
        except Exception as exc:
            logger.warning("[MARKET INGEST] %s emsal cekilemedi: %s", source, exc)
            _record_refresh(key, 0, {}, str(exc)[:500])
            summary["sources"].append({"source": source, "error": str(exc)[:300]})
    return summary


def fetch_listing(url: str) -> Optional[Dict[str, Any]]:
    """Musterinin paylastigi ilani Apify ile ceker ve kaydeder (status='talep')."""
    from yerimebak_ai_v5.services import listing_links

    # Actor yalnizca arabam.com okur; sahibinden vb. icin bosuna (ucretli) calistirilmaz
    if not apify_service.enabled() or not listing_links.can_fetch(url):
        return None
    result = apify_service.run_actor({"mode": "ilan", "url": url}, timeout_s=int(os.getenv("APIFY_LISTING_TIMEOUT_S") or 180))
    saved = upsert_listings(result["items"], status="talep")
    return saved[0] if saved else None


def declared_condition(listing_id: Optional[int], url: Optional[str]) -> Optional[Dict[str, Any]]:
    """Ilanda saticinin beyan ettigi boya/degisen/hasar bilgisi (ilan kayitli degilse None)."""
    norm = normalize_url(url or "")
    if not listing_id and not norm:
        return None
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_schema(cursor)
        if listing_id:
            cursor.execute("SELECT id, url, source, price, series, paint_info, accident_record, damage_info FROM listings WHERE id = %s", (listing_id,))
        else:
            cursor.execute("SELECT id, url, source, price, series, paint_info, accident_record, damage_info FROM listings WHERE url = %s", (norm,))
        row = cursor.fetchone()
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    if not row:
        return None
    row = dict(row)
    try:
        paint = json.loads(row.get("paint_info") or "null")
    except (TypeError, ValueError):
        paint = None
    if not isinstance(paint, dict):
        return {"listing_id": row["id"], "url": row["url"], "known": False, "paket": _clean_text(row.get("series"))}
    painted = list(paint.get("painted_parts") or [])
    changed = list(paint.get("changed_parts") or [])
    try:
        damage = json.loads(row.get("damage_info") or "null")
    except (TypeError, ValueError):
        damage = None
    damage = damage if isinstance(damage, dict) else {}
    return {
        "listing_id": row["id"],
        "url": row["url"],
        "source": row.get("source"),
        "known": True,
        "paket": _clean_text(row.get("series")),
        "boyali": max(len(painted), int(paint.get("paint_count") or 0)),
        "degisen": max(len(changed), int(paint.get("changed_count") or 0)),
        "boyaliParcalar": painted,
        "degisenParcalar": changed,
        "hasarKaydi": _clean_text(row.get("accident_record")),
        # Tramer: tutar biliniyorsa sayi, "yok" beyan edildiyse 0, bilinmiyorsa None
        "tramerTl": damage.get("tramer_tl") if damage.get("tramer_tl") else (0 if damage.get("tramer_yok") else None),
        "agirHasar": damage.get("agir_hasar"),
    }


def compare_declaration(
    declared: Optional[Dict[str, Any]], degerleme: Dict[str, Any], ekspertiz_tramer_tl: Optional[float] = None
) -> Dict[str, Any]:
    """Satici beyani (boya / degisen / tramer) ile ekspertiz bulgularini karsilastirir."""
    found_paint = int(degerleme.get("boyaliParcaSayisi") or 0)
    found_changed = int(degerleme.get("degisenParcaSayisi") or 0)
    found_tramer = int(ekspertiz_tramer_tl or 0)
    out: Dict[str, Any] = {
        "ilanBeyaniVar": bool(declared and declared.get("known")),
        "ekspertiz": {"boyali": found_paint, "degisen": found_changed, "tramerTl": found_tramer},
        "farklar": [],
    }
    if not out["ilanBeyaniVar"]:
        out["uyumlu"] = None
        out["ozet"] = "İlanda boya/değişen beyanı bulunamadı; karşılaştırma yapılamadı."
        return out
    out["ilanBeyani"] = {
        "boyali": declared["boyali"],
        "degisen": declared["degisen"],
        "hasarKaydi": declared.get("hasarKaydi"),
        "tramerTl": declared.get("tramerTl"),
        "agirHasar": declared.get("agirHasar"),
        "kaynak": declared.get("source"),
        "url": declared.get("url"),
    }
    if found_paint > declared["boyali"]:
        out["farklar"].append(
            f"İlanda {declared['boyali']} boyalı parça beyan edilmiş, ekspertizde {found_paint} boyalı parça bulundu."
        )
    if found_changed > declared["degisen"]:
        out["farklar"].append(
            f"İlanda {declared['degisen']} değişen parça beyan edilmiş, ekspertizde {found_changed} değişen parça bulundu."
        )
    declared_tramer = declared.get("tramerTl")
    if found_tramer > 0 and declared_tramer is not None and found_tramer > int(declared_tramer) * 1.1:
        beyan = "tramer kaydı yok" if not declared_tramer else f"{int(declared_tramer):,} TL tramer".replace(",", ".")
        out["farklar"].append(
            f"İlanda {beyan} beyan edilmiş, ekspertizde {found_tramer:,} TL hasar kaydı bulundu.".replace(",", ".")
        )
    out["uyumlu"] = not out["farklar"]
    out["ozet"] = (
        "İlan beyanı ekspertiz bulgularıyla uyumlu."
        if out["uyumlu"]
        else "İlan beyanı ile ekspertiz bulguları uyuşmuyor; değer gerçek bulgulara göre hesaplandı."
    )
    return out
