# -*- coding: utf-8 -*-
"""
Web aramasiyla kaynakli emsal fiyat (kaziyici gerektirmez).

Akis:
1. Yapay zeka (OpenRouter, varsayilan DeepSeek) web aramasiyla 3 farkli sorguda benzer ilanlari bulur.
2. Kod her ilani dogrular; dogrulanamayan ilan kullanilmaz:
   - url arama servisinin dondurdugu kaynaklardan biri olmali,
   - fiyat o kaynagin sayfa metninde gecmeli (model uyduramaz),
   - fiyat tahmin / kasko siteleri dislanir,
   - model yili +-1, km yakin, motor hacmi ayni olmali.
3. Ayni paketten (or. Style) en az 3 ilan varsa yalnizca onlar kullanilir.
4. Aykiri fiyatlar atilir; medyan, km/yil ve hasarsiz emsal medyani hesaplanir.
5. Az emsal, genis fiyat araligi, paket eslesmemesi "kontrol gerekli" olarak isaretlenir;
   kredili değerlemede bu uyarılar müşteriye de gösterilir.

Ayarlar (.env):
  OPENROUTER_API_KEY     zorunlu (yoksa bu kaynak kapali)
  WEB_PRICE_ENABLED      off -> kapali (varsayilan acik)
  WEB_PRICE_MODEL        varsayilan deepseek/deepseek-v4.1-flash-1017
  WEB_PRICE_SEARCHES     sorgu sayisi, varsayilan 3 (1-3)
  WEB_PRICE_PROVIDER     istege bagli, or. "deepseek": yalnizca bu saglayicinin sunucusu kullanilir
  WEB_PRICE_CACHE_HOURS  başarılı emsalin önbellek süresi (varsayılan 24 saat, 0 kapalı)
"""
from __future__ import annotations

import json
import hashlib
import logging
import os
import re
import statistics
import threading
import unicodedata
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Dict, List, Optional
from urllib.parse import urlsplit

import httpx
from psycopg2.extras import Json
from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)

SOURCE = "web_listings"
_URL = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL = "deepseek/deepseek-v4.1-flash-1017"
MIN_PRICE, MAX_PRICE = 50_000, 100_000_000
MIN_SAMPLES = 3          # bunun altinda referans uretilmez
TARGET_SAMPLES = 5       # bunun altinda "kontrol gerekli"
OUTLIER_BAND = 0.25      # medyan +-%25 disi atilir
WIDE_SPREAD_RATIO = 1.35 # max/min bundan buyukse "kontrol gerekli"
_schema_ready = False
_schema_lock = threading.Lock()

# Ilan degil, fiyat tahmini / kasko / liste fiyati veren siteler
ESTIMATE_SITES = ("kacasatar", "arabamkacpara", "kasko", "sbm.org", "fiyatlari", "fiyat-listesi", "fiyatlistesi")

# Paket adinda motor/sanziman/yakit bilgisi; paket eslesmesinde dikkate alinmaz
_NON_TRIM = {
    "tsi", "ecotsi", "tfsi", "tdi", "tce", "dci", "crdi", "mpi", "gdi", "tgdi", "tgi", "multijet", "mjet",
    "bluehdi", "hdi", "puretech", "ecoboost", "tdci", "vct", "ti", "vti", "ivtec", "vtec", "skyactiv",
    "dsg", "edc", "cvt", "eat6", "eat8", "at", "mt", "amt", "dct", "otomatik", "manuel", "steptronic",
    "hp", "ps", "bg", "hb", "beygir", "kw", "benzin", "benzinli", "dizel", "hybrid", "hibrit", "elektrik",
    "lpg", "turbo", "sedan", "hatchback", "hb5", "cross", "4x4", "4matic", "xdrive", "quattro",
}

_PROMPT = (
    "Türkiye'de şu anda satılık ikinci el ilanlar arasında şu araca en çok benzeyenleri bul: {arac}. "
    "Aynı model ve mümkünse aynı paket, model yılı ±1, kilometresi yakın olsun. "
    "Yalnızca tek tek araç ilanlarını ver; fiyat listesi, kasko değeri, tahmin sitesi verme. "
    "Her ilan için sadece sayfada gerçekten yazan bilgileri yaz, bilmediğini boş bırak, uydurma. "
    "durum alanına ilanda boya/değişen/hasar/tramer hakkında yazanı kısaca yaz (ör. 'hatasız', '2 parça boyalı'). "
    "kondisyon alanı şunlardan biri olsun: 'temiz' (ilanda hatasız ya da boyasız, değişensiz ve hasar kaydı yok "
    "yazıyorsa), 'hasarli' (boya, değişen veya tramer/hasar kaydı varsa), 'agir_hasarli' (ağır hasar kayıtlı, pert, "
    "sel/yangın), 'bilinmiyor' (ilanda bilgi yoksa). "
    'Sadece JSON döndür: {{"ilanlar":[{{"url":"","yil":0,"km":0,"fiyat_tl":0,"paket":"","durum":"","kondisyon":"",'
    '"ilan_tarihi":""}}]}}'
)

_CONDITIONS = {"temiz": "clean", "hasarli": "damaged", "agir_hasarli": "heavy", "bilinmiyor": "unknown"}


# ---------------------------------------------------------------------------
# Ayarlar
# ---------------------------------------------------------------------------
def enabled() -> bool:
    return bool(os.getenv("OPENROUTER_API_KEY")) and (os.getenv("WEB_PRICE_ENABLED") or "on").strip().lower() != "off"


def model_name() -> str:
    return (os.getenv("WEB_PRICE_MODEL") or DEFAULT_MODEL).strip()


def _search_count() -> int:
    try:
        return max(1, min(3, int(os.getenv("WEB_PRICE_SEARCHES") or 3)))
    except ValueError:
        return 3


# ---------------------------------------------------------------------------
# Metin yardimcilari
# ---------------------------------------------------------------------------
def fold(text: Any) -> str:
    """Kucuk harf, Turkce karakterleri sadelestirir (İ->i, ş->s ...)."""
    text = str(text or "").replace("İ", "i").replace("I", "ı").lower().replace("ı", "i")
    text = unicodedata.normalize("NFKD", text)
    return "".join(c for c in text if not unicodedata.combining(c))


def _cache_hours() -> float:
    try:
        hours = float(os.getenv("WEB_PRICE_CACHE_HOURS", "24"))
        return hours if 0 <= hours < float("inf") else 24
    except ValueError:
        return 24


def _cache_key(vehicle: Dict[str, Any]) -> str:
    values = [" ".join(fold(vehicle.get(k)).split())
              for k in ("brand", "model", "year", "package", "fuel", "transmission")]
    values.append((_int(vehicle.get("km")) or 0) // 20_000)
    return hashlib.sha256(json.dumps(values, ensure_ascii=False).encode("utf-8")).hexdigest()


def _ensure_cache_schema() -> None:
    global _schema_ready
    with _schema_lock:
        if _schema_ready:
            return
        conn = DatabaseConfig.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""CREATE TABLE IF NOT EXISTS web_reference_cache (
                    cache_key TEXT PRIMARY KEY,
                    reference JSONB NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )""")
            conn.commit()
            _schema_ready = True
        finally:
            DatabaseConfig.return_connection(conn)


def _cache_read(key: str, hours: float) -> Optional[Dict[str, Any]]:
    try:
        _ensure_cache_schema()
        conn = DatabaseConfig.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT reference, created_at FROM web_reference_cache WHERE cache_key = %s", (key,))
                row = cur.fetchone()
            if row and dict(row)["created_at"] > datetime.now(timezone.utc) - timedelta(hours=hours):
                ref = dict(row)["reference"]
                ref["scope"] = {**ref.get("scope", {}), "cached": True, "cost_usd": 0}
                return ref
        finally:
            DatabaseConfig.return_connection(conn)
    except Exception:
        # Önbellek isteğe bağlıdır; veritabanı kesintisi web değerlemesini durdurmaz.
        pass
    return None


def _cache_write(key: str, reference: Dict[str, Any]) -> None:
    try:
        _ensure_cache_schema()
        conn = DatabaseConfig.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""INSERT INTO web_reference_cache (cache_key, reference) VALUES (%s, %s)
                    ON CONFLICT (cache_key) DO UPDATE SET reference = EXCLUDED.reference, created_at = NOW()""",
                            (key, Json(reference)))
            conn.commit()
        finally:
            DatabaseConfig.return_connection(conn)
    except Exception:
        pass


def _int(value: Any) -> Optional[int]:
    if isinstance(value, bool) or value in (None, ""):
        return None
    if isinstance(value, (int, float)):
        return int(value)
    digits = re.sub(r"[^\d]", "", str(value))
    return int(digits) if digits else None


def _displacements(text: str) -> set:
    """'1.0', '1-0', '1,0' -> {'1.0'}"""
    return {f"{a}.{b}" for a, b in re.findall(r"(?<![\d.])(\d)[.,\-](\d)(?![\d])", text)}


def trim_tokens(package: Optional[str]) -> List[str]:
    """'1.0 EcoTSI Style DSG 115 hp' -> ['style']"""
    tokens = re.split(r"[^a-z0-9]+", fold(package))
    return [t for t in tokens if len(t) >= 2 and not t.isdigit() and t not in _NON_TRIM]


def price_in_text(price: int, text: str) -> bool:
    dotted = f"{price:,}".replace(",", ".")
    return dotted in text or re.search(rf"(?<!\d){price}(?!\d)", text) is not None


def is_estimate_site(url: str) -> bool:
    parts = urlsplit(url)
    blob = (parts.netloc + parts.path).lower()
    return any(s in blob for s in ESTIMATE_SITES)


# ---------------------------------------------------------------------------
# Arama
# ---------------------------------------------------------------------------
def _vehicle_text(v: Dict[str, Any]) -> str:
    parts = [str(v.get("year") or ""), v.get("brand"), v.get("model"), v.get("package")]
    text = " ".join(str(p) for p in parts if p)
    extra = [x for x in (v.get("fuel"), v.get("transmission")) if x]
    if extra:
        text += ", " + ", ".join(str(x) for x in extra)
    if v.get("km"):
        text += f", {int(v['km']):,} km".replace(",", ".")
    return text


def queries(v: Dict[str, Any]) -> List[str]:
    base = _vehicle_text(v)
    year = _int(v.get("year"))
    years = f"{year - 1}-{year + 1} model " if year else ""
    no_year = " ".join(str(p) for p in (v.get("brand"), v.get("model"), v.get("package")) if p)
    return [
        base,
        f"{base}, arabam.com ve sahibinden ilanları",
        f"satılık ikinci el {no_year} {years}".strip(),
    ][: _search_count()]


def _search(query: str, client: httpx.Client, *, prompt: Optional[str] = None, web: bool = True) -> Dict[str, Any]:
    """Tek web aramasi: modelin ilan listesi + arama servisinin kaynak metinleri."""
    body: Dict[str, Any] = {
        "model": model_name(),
        "temperature": 0,
        "messages": [{"role": "user", "content": prompt if prompt is not None else _PROMPT.format(arac=query)}],
        "usage": {"include": True},
    }
    if web:
        body["plugins"] = [{"id": "web", "max_results": 10}]
    provider = (os.getenv("WEB_PRICE_PROVIDER") or "").strip()
    if provider:
        body["provider"] = {"only": [provider], "allow_fallbacks": False}
    resp = client.post(_URL, headers={"Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}"}, json=body)
    resp.raise_for_status()
    data = resp.json()
    message = (data.get("choices") or [{}])[0].get("message") or {}
    sources: Dict[str, str] = {}
    for ann in message.get("annotations") or []:
        cit = ann.get("url_citation") or {}
        if cit.get("url"):
            sources[cit["url"].rstrip("/")] = cit.get("content") or ""
    listings: List[Dict[str, Any]] = []
    match = re.search(r"\{.*\}", message.get("content") or "", re.DOTALL)
    parsed = {}
    if match:
        try:
            parsed = json.loads(match.group(0))
            listings = [x for x in parsed.get("ilanlar") or [] if isinstance(x, dict)]
        except ValueError:
            pass
    return {"listings": listings, "sources": sources, "data": parsed,
            "cost": (data.get("usage") or {}).get("cost") or 0}


# ---------------------------------------------------------------------------
# Dogrulama ve hesap (ag olmadan test edilebilir)
# ---------------------------------------------------------------------------
def verify(listing: Dict[str, Any], sources: Dict[str, str], v: Dict[str, Any]) -> Optional[str]:
    """Ilan kullanilabilirse None, degilse red nedeni."""
    url = str(listing.get("url") or "").rstrip("/")
    price = _int(listing.get("fiyat_tl")) or 0
    if url not in sources:
        return "kaynaklarda yok"
    if is_estimate_site(url):
        return "tahmin sitesi"
    if not MIN_PRICE <= price <= MAX_PRICE:
        return "fiyat geçersiz"
    if not price_in_text(price, sources[url]):
        return "fiyat sayfada yok"
    year, l_year = _int(v.get("year")), _int(listing.get("yil"))
    if year and l_year and abs(l_year - year) > 1:
        return "yıl uyumsuz"
    km, l_km = _int(v.get("km")), _int(listing.get("km"))
    if km is not None and l_km is not None and not (km * 0.5 - 20_000 <= l_km <= km * 1.5 + 20_000):
        return "km uzak"
    target = _displacements(f"{v.get('package') or ''} {v.get('model') or ''}")
    found = _displacements(f"{listing.get('paket') or ''} {url}")
    if target and found and not (target & found):
        return "motor uyumsuz"
    return None


def _condition(listing: Dict[str, Any]) -> str:
    """Modelin sectigi kondisyon; yoksa yalnizca url/paket metninden (ör. '...-hatasiz-boyasiz-...').

    Serbest 'durum' metni siniflandiriciya verilmez: 'degisen yok' gibi olumsuz cumleleri hasar sanar.
    """
    value = fold(listing.get("kondisyon")).replace(" ", "_").replace("-", "_")
    if value in _CONDITIONS:
        return _CONDITIONS[value]
    from yerimebak_ai_v5.core.ai.inspection_valuation import classify_listing_condition

    return classify_listing_condition(*(str(listing.get(k) or "") for k in ("paket", "url")))


def _package_match(listing: Dict[str, Any], tokens: List[str]) -> bool:
    blob = fold(f"{listing.get('paket') or ''} {listing.get('url') or ''}")
    return all(t in blob for t in tokens)


def build_reference(results: List[Dict[str, Any]], v: Dict[str, Any]) -> Dict[str, Any]:
    """Arama sonuclarini dogrular, birlestirir ve degerleme motorunun okudugu bicime cevirir."""
    accepted: Dict[tuple, Dict[str, Any]] = {}
    rejected: Dict[str, int] = {}
    cost = 0.0
    for res in results:
        cost += float(res.get("cost") or 0)
        for item in res.get("listings") or []:
            reason = verify(item, res.get("sources") or {}, v)
            if reason:
                rejected[reason] = rejected.get(reason, 0) + 1
                continue
            if _condition(item) == "heavy":
                rejected["ağır hasarlı"] = rejected.get("ağır hasarlı", 0) + 1
                continue
            url = str(item["url"]).rstrip("/")
            key = (url, _int(item.get("fiyat_tl")), _int(item.get("km")))
            accepted[key] = {**item, "url": url, "fiyat_tl": _int(item.get("fiyat_tl"))}

    items = list(accepted.values())
    tokens = trim_tokens(v.get("package"))
    package_match = False
    if tokens:
        same = [i for i in items if _package_match(i, tokens)]
        if len(same) >= MIN_SAMPLES:
            items, package_match = same, True

    flags: List[Dict[str, str]] = []
    scope = {
        "method": "web_search", "model": model_name(), "searches": len(results),
        "year_window": 1, "cost_usd": round(cost, 4), "rejected": rejected,
        "listed_price": _int(v.get("listed_price")),
    }
    if len(items) < MIN_SAMPLES:
        return {
            "found": False, "source": SOURCE, "reason": "not_enough_web_listings",
            "count": len(items), "scope": scope, "package": v.get("package"), "samples": [],
        }

    prices = sorted(i["fiyat_tl"] for i in items)
    med = statistics.median(prices)
    kept = [i for i in items if (1 - OUTLIER_BAND) * med <= i["fiyat_tl"] <= (1 + OUTLIER_BAND) * med]
    if len(kept) < MIN_SAMPLES:
        kept = items
    kept.sort(key=lambda i: i["fiyat_tl"])
    prices = [i["fiyat_tl"] for i in kept]
    median_price = int(statistics.median(prices))
    for i in kept:
        i["_condition"] = _condition(i)
    clean = [i["fiyat_tl"] for i in kept if i["_condition"] == "clean"]
    kms = [k for k in (_int(i.get("km")) for i in kept) if k]
    years = [y for y in (_int(i.get("yil")) for i in kept) if y]

    if len(kept) < TARGET_SAMPLES:
        flags.append({"kod": "az_emsal", "mesaj": f"Yalnızca {len(kept)} doğrulanmış emsal ilan bulundu (hedef {TARGET_SAMPLES})"})
    if max(prices) / min(prices) > WIDE_SPREAD_RATIO:
        flags.append({"kod": "genis_aralik", "mesaj": "Emsal fiyatları birbirinden çok farklı; piyasa değerini kontrol edin"})
    if tokens and not package_match:
        flags.append({"kod": "paket_eslesmedi", "mesaj": f"Aynı paketten ({v.get('package')}) yeterli ilan yok; diğer paketler de kullanıldı"})
    if not tokens:
        flags.append({"kod": "paket_bilinmiyor", "mesaj": "Araç paketi girilmemiş; emsaller modelin tüm paketlerinden"})

    confidence = min(85, 40 + 6 * len(kept)) + (5 if package_match else 0)
    if any(f["kod"] in ("az_emsal", "genis_aralik") for f in flags):
        confidence = min(confidence, 50)

    return {
        "found": True,
        "source": SOURCE,
        "count": len(kept),
        "raw_count": len(accepted),
        "market_avg_price": int(sum(prices) / len(prices)),
        "market_median_price": median_price,
        "market_min_price": prices[0],
        "market_max_price": prices[-1],
        "clean_median_price": int(statistics.median(clean)) if clean else None,
        "clean_count": len(clean),
        "reference_median_km": int(statistics.median(kms)) if kms else 0,
        "reference_median_year": int(statistics.median(years)) if years else 0,
        "stale": False,
        "confidence": int(confidence),
        "package": v.get("package"),
        "package_match": package_match,
        "kontrol": flags,
        "uyari": "; ".join(f["mesaj"] for f in flags) or None,
        "scope": scope,
        "samples": [
            {
                "price": i["fiyat_tl"], "km": _int(i.get("km")), "year": _int(i.get("yil")),
                "title": " ".join(str(x) for x in (v.get("brand"), v.get("model"), i.get("paket")) if x),
                "url": i["url"], "site": urlsplit(i["url"]).netloc.replace("www.", ""),
                "condition": i["_condition"], "declared": (str(i.get("durum") or "")[:80] or None),
                "listing_date": (str(i.get("ilan_tarihi") or "")[:20] or None),
            }
            for i in kept
        ],
        "searched_at": datetime.now().isoformat(timespec="seconds"),
    }


def get_reference(vehicle: Dict[str, Any], search: Optional[Callable[[str], Dict[str, Any]]] = None) -> Optional[Dict[str, Any]]:
    """Web aramasiyla emsal referansi; kapaliysa veya marka/model/yil yoksa None.

    vehicle: brand, model, year, km, package, fuel, transmission, listed_price
    search: testlerde ag yerine kullanilir (sorgu -> {listings, sources, cost}).
    """
    if not vehicle.get("brand") or not vehicle.get("model") or not vehicle.get("year"):
        return None
    if search is None and not enabled():
        return None
    hours = _cache_hours()
    key = _cache_key(vehicle)
    if hours:
        cached = _cache_read(key, hours)
        if cached:
            # İlan fiyatı önbellek anahtarına dahil değildir; güncel isteğe aittir.
            cached["scope"]["listed_price"] = _int(vehicle.get("listed_price"))
            return cached
    qs = queries(vehicle)
    results: List[Dict[str, Any]] = []
    if search is None:
        with httpx.Client(timeout=90.0) as client:
            with ThreadPoolExecutor(len(qs)) as pool:
                futures = [pool.submit(_search, q, client) for q in qs]
                for fut in futures:
                    try:
                        results.append(fut.result())
                    except Exception as exc:
                        logger.warning("[WEB FIYAT] Arama basarisiz: %s", str(exc)[:200])
    else:
        results = [search(q) for q in qs]
    if not results:
        return None
    ref = build_reference(results, vehicle)
    if hours and ref.get("found"):
        _cache_write(key, ref)
    logger.info("[WEB FIYAT] %s %s %s: %s emsal, medyan %s, maliyet $%s, red %s",
                vehicle.get("brand"), vehicle.get("model"), vehicle.get("year"), ref.get("count"),
                ref.get("market_median_price"), ref["scope"]["cost_usd"], ref["scope"]["rejected"])
    return ref
