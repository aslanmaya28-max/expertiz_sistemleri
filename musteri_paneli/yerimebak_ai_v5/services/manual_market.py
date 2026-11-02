"""YerimeBak piyasa takibi: verisi az olan marka/modeller için admin'in elle girdiği ilan verisi.

Kullanıcı kararı (02.11.2026): internet aramasının yeterli ilan bulamadığı modellerde admin,
ilan sitesindeki arama sonuç listesini yapıştırır. Risk azaltma kuralları:
- Yalnız rakamlar saklanır (seri, model/paket, yıl, km, fiyat, beygir, ilan tarihi, il).
  Başlık, açıklama, fotoğraf, satıcı adı ve link saklanmaz; ilan numarası yalnız tekrarı
  önlemek için geri çözülemez bir iz (SHA-256) olarak tutulur.
- Müşteriye tek tek ilan gösterilmez; raporda yalnız toplam ("YerimeBak piyasa takibi: N ilan").
- Veri yalnız internet aramasıyla 5 ilan bulunamadığında kullanılır; 90 günden eskisi kullanılmaz,
  daha yenileri araç enflasyonu ayarıyla bugüne taşınır.
"""
from __future__ import annotations

import hashlib
import logging
import re
import threading
from datetime import date, datetime, timezone
from typing import Any, Dict, List, Optional

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.services.web_market_reference import fold, horsepower, _int

logger = logging.getLogger(__name__)

MAX_AGE_DAYS = 90
_schema_ready = False
_schema_lock = threading.Lock()

_MONTHS = {"ocak": 1, "subat": 2, "mart": 3, "nisan": 4, "mayis": 5, "haziran": 6, "temmuz": 7,
           "agustos": 8, "eylul": 9, "ekim": 10, "kasim": 11, "aralik": 12}

# Sahibinden arama sonuç listesinin kopyası: her ilan "... #<ilanNo>\t<Seri>\t<Model>\t" satırıyla
# başlar; ardından başlık satırları, "<Yıl>\t<KM>\t<Renk>", "<Fiyat> TL", "<gün> <ay>", "<yıl>\t<İl>".
_ROW = re.compile(
    r"^(?P<title>[^\n]*?)#(?P<no>\d{6,12})\t(?P<seri>[^\t\n]+)\t(?P<model>[^\t\n]*)\t?[^\n]*\n"
    r"(?P<body>.*?)"
    r"^\s*(?P<yil>(?:19|20)\d{2})\t(?P<km>[\d.]+)\t[^\n]*\n"
    r"\s*(?P<fiyat>[\d.]+)\s*TL\s*\n"
    r"\s*(?P<gun>\d{1,2})\s+(?P<ay>[^\s\d]+)\s*\n"
    r"\s*(?P<ilan_yili>(?:19|20)\d{2})\t(?P<il>[^\t\n]*)",
    re.MULTILINE | re.DOTALL,
)
def _fingerprint(listing_no: str) -> str:
    return hashlib.sha256(f"yerimebak-piyasa-takibi:{listing_no}".encode()).hexdigest()


def parse_search_page(text: str) -> Dict[str, Any]:
    """Yapıştırılan arama listesini satırlara ayırır (yalnız rakamlar ve model bilgisi)."""
    rows, skipped = [], 0
    for match in _ROW.finditer(text or ""):
        year, km, price = _int(match["yil"]), _int(match["km"]), _int(match["fiyat"])
        month = _MONTHS.get(fold(match["ay"]).strip())
        try:
            listed = date(int(match["ilan_yili"]), month, int(match["gun"])) if month else None
        except ValueError:
            listed = None
        if not (year and km is not None and price and 50_000 <= price <= 100_000_000):
            skipped += 1
            continue
        rows.append({
            "iz": _fingerprint(match["no"]),
            "seri": match["seri"].strip()[:60], "model": match["model"].strip()[:80],
            "yil": year, "km": km, "fiyat": price,
            "beygir": horsepower(match["title"] + " " + match["body"]),
            "ilan_tarihi": listed.isoformat() if listed else None,
            "il": match["il"].strip()[:40] or None,
        })
    return {"satirlar": rows, "atlanan": skipped}


def _ensure_schema(cur) -> None:
    global _schema_ready
    if _schema_ready:
        return
    with _schema_lock:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS manual_listings (
                id BIGSERIAL PRIMARY KEY,
                fingerprint TEXT UNIQUE NOT NULL,
                brand TEXT NOT NULL, model TEXT NOT NULL, package TEXT,
                year INTEGER NOT NULL, km INTEGER NOT NULL, price INTEGER NOT NULL,
                horsepower INTEGER, listing_date DATE, city TEXT,
                added_by TEXT, added_at TIMESTAMPTZ NOT NULL DEFAULT now())
        """)
        cur.execute("CREATE INDEX IF NOT EXISTS manual_listings_model ON manual_listings (lower(brand), lower(model))")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS market_gaps (
                brand TEXT NOT NULL, model TEXT NOT NULL, year INTEGER NOT NULL,
                requests INTEGER NOT NULL DEFAULT 0, last_count INTEGER NOT NULL DEFAULT 0,
                last_at TIMESTAMPTZ NOT NULL DEFAULT now(),
                PRIMARY KEY (brand, model, year))
        """)
        _schema_ready = True


def save(brand: str, rows: List[Dict[str, Any]], user_id: Optional[str]) -> Dict[str, int]:
    """Satırları kaydeder; aynı ilan (iz) ikinci kez kaydedilmez."""
    brand = (brand or "").strip()[:40]
    if not brand:
        raise ValueError("Marka gerekli")
    added = duplicate = 0
    conn = DatabaseConfig.get_connection()
    try:
        with conn.cursor() as cur:
            _ensure_schema(cur)
            for row in rows:
                if not re.fullmatch(r"[0-9a-f]{64}", str(row.get("iz") or "")):
                    continue
                cur.execute("""
                    INSERT INTO manual_listings (fingerprint, brand, model, package, year, km, price,
                                                 horsepower, listing_date, city, added_by)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) ON CONFLICT (fingerprint) DO NOTHING
                """, (row["iz"], brand, str(row["seri"])[:60], (row.get("model") or None),
                      int(row["yil"]), int(row["km"]), int(row["fiyat"]), row.get("beygir"),
                      row.get("ilan_tarihi"), row.get("il"), user_id))
                if cur.rowcount:
                    added += 1
                else:
                    duplicate += 1
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    return {"eklenen": added, "tekrar": duplicate}


def _monthly_inflation_pct() -> float:
    try:
        from yerimebak_ai_v5.services import pricing_service
        setting = pricing_service.get_pricing_settings().get("vehicle_inflation") or {}
        return float(setting.get("monthly_pct") or 0)
    except Exception:  # ayar yoksa fiyat bugüne taşınmaz
        return 0.0


def find(vehicle: Dict[str, Any], *, max_age_days: int = MAX_AGE_DAYS) -> List[Dict[str, Any]]:
    """Aracın marka/modeli için son kayıtlar, emsal ilan biçiminde (fiyat bugüne taşınmış).
    Yıl/km/beygir/kasa süzmesi emsal doğrulamasında yapılır."""
    brand, model = fold(vehicle.get("brand")).strip(), fold(vehicle.get("model")).strip()
    if not brand or not model:
        return []
    try:
        conn = DatabaseConfig.get_connection()
    except Exception:
        return []
    try:
        with conn.cursor() as cur:
            _ensure_schema(cur)
            cur.execute("""
                SELECT fingerprint, brand, model, package, year, km, price, horsepower, listing_date, added_at
                FROM manual_listings WHERE added_at >= now() - make_interval(days => %s)
            """, (int(max_age_days),))
            rows = [dict(r) for r in cur.fetchall()]
    except Exception as exc:
        logger.warning("[PIYASA TAKIBI] okunamadı: %s", str(exc)[:200])
        return []
    finally:
        DatabaseConfig.return_connection(conn)
    monthly = _monthly_inflation_pct()
    now = datetime.now(timezone.utc)
    out = []
    for r in rows:
        if fold(r["brand"]).strip() != brand:
            continue
        seri = fold(r["model"]).strip()
        if not (model == seri or model.startswith(seri + " ") or seri.startswith(model + " ")):
            continue
        added = r["added_at"] if r["added_at"].tzinfo else r["added_at"].replace(tzinfo=timezone.utc)
        months = max(0.0, (now - added).days / 30.0)
        price = int(round(r["price"] * (1 + monthly / 100.0) ** months))
        out.append({"url": f"manuel://{r['fingerprint'][:16]}", "fiyat_tl": price, "km": r["km"], "yil": r["year"],
                    "paket": r.get("package") or "", "beygir": r.get("horsepower"), "kondisyon": "bilinmiyor",
                    "_manual": True})
    return out


def log_gap(brand: str, model: str, year: Optional[int], count: int) -> None:
    """İnternet aramasında yetersiz ilan: admin'in veri toplaması gereken modeller listesi."""
    if not brand or not model or not year:
        return
    try:
        conn = DatabaseConfig.get_connection()
    except Exception:
        return
    try:
        with conn.cursor() as cur:
            _ensure_schema(cur)
            cur.execute("""
                INSERT INTO market_gaps (brand, model, year, requests, last_count, last_at)
                VALUES (%s,%s,%s,1,%s,now())
                ON CONFLICT (brand, model, year) DO UPDATE
                SET requests = market_gaps.requests + 1, last_count = EXCLUDED.last_count, last_at = now()
            """, (brand.strip()[:40], model.strip()[:60], int(year), int(count)))
        conn.commit()
    except Exception as exc:
        logger.warning("[PIYASA TAKIBI] eksik kaydı yazılamadı: %s", str(exc)[:200])
    finally:
        DatabaseConfig.return_connection(conn)


def gaps(limit: int = 50) -> List[Dict[str, Any]]:
    conn = DatabaseConfig.get_connection()
    try:
        with conn.cursor() as cur:
            _ensure_schema(cur)
            cur.execute("""
                SELECT g.brand, g.model, g.year, g.requests, g.last_count, g.last_at,
                       (SELECT count(*) FROM manual_listings m
                         WHERE lower(m.brand) = lower(g.brand) AND lower(m.model) = lower(g.model)
                           AND m.added_at >= now() - interval '90 days') AS takip_ilan
                FROM market_gaps g ORDER BY g.requests DESC, g.last_at DESC LIMIT %s
            """, (limit,))
            return [{**dict(r), "last_at": dict(r)["last_at"].isoformat()} for r in cur.fetchall()]
    finally:
        DatabaseConfig.return_connection(conn)
