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
   Hedef 5 emsal bulunmazsa yıl ±2 ve iki kat km bandıyla ikinci tur yapılır.
5. Az emsal, genis fiyat araligi, paket eslesmemesi kontrol bayraklarında korunur;
   müşteri raporunda az emsal için yalnız kısa yön gösterici fiyat notu gösterilir.

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
import math
import statistics
import threading
import unicodedata
from concurrent.futures import ThreadPoolExecutor, wait
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Dict, List, Optional
from urllib.parse import urlsplit

import httpx
from psycopg2.extras import Json
from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.services.llm_json import oku

logger = logging.getLogger(__name__)

SOURCE = "web_listings"
_URL = "https://openrouter.ai/api/v1/chat/completions"
DEFAULT_MODEL = "deepseek/deepseek-v4.1-flash-1017"
MIN_PRICE, MAX_PRICE = 50_000, 100_000_000
MIN_SAMPLES = 3          # bunun altinda referans uretilmez
TARGET_SAMPLES = 5       # bunun altında ikinci tur arama yapılır
# v5: emsalde yakıt/vites ailesi uyumu (08.11.2026); dizel emsalli eski benzinli sonuçlar kullanılmaz.
CACHE_VERSION = "yakit-vites-v5"
OUTLIER_BAND = 0.25      # medyan +-%25 disi atilir
DEFAULT_YEARLY_RATE = 0.04   # ilanlardan hesaplanamazsa yıllık değer kaybı
YEARLY_RATE_LIMITS = (0.02, 0.12)
KM_RATE_PER_10K = 0.008      # 10.000 km farkı başına (en fazla ±%10)
SUSPICIOUS_CHEAP = 0.85      # düzeltilmiş ortanın %15'ten fazla altındaki hasarsız görünen ilan
WIDE_SPREAD_RATIO = 1.35 # max/min bundan buyukse "kontrol gerekli"
_schema_ready = False
_schema_lock = threading.Lock()

# Ilan degil, fiyat tahmini / kasko / liste fiyati veren siteler
ESTIMATE_SITES = ("kacasatar", "arabamkacpara", "kasko", "sbm.org", "fiyatlari", "fiyat-listesi", "fiyatlistesi")

AUCTION_SITES = ("ikinciyeni", "acik-artirma", "ihale")
LISTING_SITES = {
    "arabam.com": "Arabam", "otosahibi.com": "Otosahibi", "otonomi.com": "Otonomi",
    "tr.vava.cars": "VavaCars", "otokocikinciel.com": "Otokoç 2. El",
    "dogusoto.com.tr": "Doğuş Oto / DOD", "borusannext.com": "Borusan Next",
    "otoplus.com": "Otoplus", "letgo.com": "Otoplus/letgo", "carvak.com": "Carvak",
    "satariz.com": "Satarız", "otoshops.com": "Otoshops",
}

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
    "Aynı model ve mümkünse aynı paket, sorgudaki yıl/km aralığında olsun (belirtilmediyse model yılı ±1). "
    "sahibinden.com ilanlarını verme (sayfası okunamıyor); arabam.com, otosahibi, otonomi, VavaCars, "
    "Otokoç 2. El, Doğuş Oto, Borusan Next, Otoplus, Carvak, Satarız ve galeri sitelerindeki ilanları tercih et. "
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


def _llm_limits() -> Dict[str, Any]:
    """DeepSeek düşünen modeldir; bazı sorgularda düşünmekten çıkamayıp dakikalarca
    (ölçüm: 590 sn, 0,073 $, 0 ilan) çalışıyordu. Doğruluk kodda denetlendiği için düşünme
    kapalı; çıktı sınırlı (düşünme kapalıyken aynı sorgu 9,8 sn, 0,008 $, 9 ilan)."""
    limits: Dict[str, Any] = {"max_tokens": int(os.getenv("WEB_MAX_TOKENS") or 4000)}
    if (os.getenv("WEB_REASONING") or "off").lower() != "on":
        limits["reasoning"] = {"enabled": False}
    return limits


def _round_seconds() -> float:
    """Bir arama turunun kesin üst sınırı; aşan arama kesilir, bitenlerle devam edilir."""
    try:
        return max(1.0, float(os.getenv("WEB_ROUND_SECONDS") or 75))
    except ValueError:
        return 75.0


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
              for k in ("brand", "model", "year", "package", "fuel", "transmission", "kasa", "hp")]
    values.extend([(_int(vehicle.get("km")) or 0) // 20_000, CACHE_VERSION, _search_count()])
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
    return any(s in blob for s in ESTIMATE_SITES + AUCTION_SITES)


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


def queries(v: Dict[str, Any], *, widened: bool = False, year_range: Optional[tuple] = None) -> List[str]:
    base = _vehicle_text(v)
    year = _int(v.get("year"))
    window = 2 if widened else 1
    lo, hi = year_range or ((year - window, year + window) if year else (None, None))
    years = f"{lo}-{hi} model " if year else ""
    km = _int(v.get("km")) or 0
    band = (km * 0.5 + 20_000) * (2 if widened else 1)
    expansion = (f", {'aynı kasa' if year_range else 'yıl ±2'}, {years}{max(0, int(km - band))}-{int(km + band)} km"
                 if widened else "")
    if year_range and not widened:
        expansion = f", {years}aynı kasa"
    no_year = " ".join(str(p) for p in (v.get("brand"), v.get("model"), v.get("package")) if p)
    return [
        base + expansion,
        f"{base} satılık ilan arabam.com otosahibi otonomi vavacars satariz" + expansion,
        f"satılık ikinci el {no_year} {years}galeri ilanı borusannext otokoç doğuş oto otoplus carvak" + expansion,
    ][: _search_count()]


def _search(query: str, client: httpx.Client, *, prompt: Optional[str] = None, web: bool = True) -> Dict[str, Any]:
    """Tek web aramasi: modelin ilan listesi + arama servisinin kaynak metinleri."""
    body: Dict[str, Any] = {
        "model": model_name(),
        "temperature": 0,
        "messages": [{"role": "user", "content": prompt if prompt is not None else _PROMPT.format(arac=query)}],
        "usage": {"include": True},
        **_llm_limits(),
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
    try:
        parsed = oku(message.get("content"), listeler=("ilanlar",))
    except ValueError:
        parsed = {}
    listings = [x for x in parsed.get("ilanlar") or [] if isinstance(x, dict)]
    return {"listings": listings, "sources": sources, "data": parsed,
            "cost": (data.get("usage") or {}).get("cost") or 0}


# ---------------------------------------------------------------------------
# Dogrulama ve hesap (ag olmadan test edilebilir)
# ---------------------------------------------------------------------------
_HP = re.compile(r"(?<!\d)(\d{2,3})\s*(?:hp|ps|bg|beygir)\b")
HP_TOLERANCE = 5   # aynı motorun yazım farkları (ör. 130/131 bg)
MANUAL_URL = "manuel://"
MANUAL_LABEL = "YerimeBak piyasa takibi"


def horsepower(text: Any) -> Optional[int]:
    """Başlık/paket metnindeki beygir ("170 HP", "162HP", "130 bg"). Kasa değişiminde güç de
    çoğu zaman değişir (MG HS: eski 162 hp, yeni 170 hp); ayırt etmek için kullanılır."""
    match = _HP.search(fold(text))
    if not match:
        return None
    value = int(match.group(1))
    return value if 40 <= value <= 800 else None


def kasa_terms(generation: Optional[Dict[str, Any]], newer: bool, vehicle: Optional[Dict[str, Any]] = None) -> tuple:
    """Geçiş yılındaki ilanın kasasını ilan metninden tanımak için terimler (ör. "nx4", "yeni kasa").
    Kısa kodlar (ör. "TL") fiyat yazısıyla karışacağı için kullanılmaz."""
    terms = [t for t in re.findall(r"[a-z0-9]+", fold((generation or {}).get("kasa"))) if len(t) >= 3 and not t.isdigit()]
    names = set(re.findall(r"[a-z0-9]+", fold(f"{(vehicle or {}).get('brand') or ''} {(vehicle or {}).get('model') or ''}")))
    terms = [t for t in terms if t not in names and t not in ("nesil", "kasa", "facelift", "makyaj")][:2]
    # Türkiye ilanlarında yeni kasa çoğunlukla "Yeni <model>" diye yazılır (ör. "mg-hs-yeni-luxury").
    # "yeni" tek kelime olarak yalnız paket adında/adreste aranır (açıklamadaki "yeni lastik" sayılmaz).
    return tuple(terms) + (("yeni kasa", "yeni nesil", "kelime:yeni") if newer else ("eski kasa", "onceki kasa"))


# Motor ailesi ve vites adları (ilan paketinde/adresinde). Fiat Egea 1.4 Fire benzinli raporunda emsallere
# "1-3-multijet" dizel ve "1.6 e-torq otomatik" ilanları girmişti (08.11.2026).
DIZEL_ADLARI = (r"\b(dizel|diesel|multijet|mjet|crdi|tdi|dci|hdi|bluehdi|cdti|tdci|cdi|ddis|jtd|d[- ]?4d|"
                r"i[- ]?dtec|ecoblue|skyactiv[- ]?d)\b")
BENZIN_ADLARI = (r"\b(benzin|benzinli|fire|t[- ]?jet|e[- ]?torq|tsi|tfsi|tce|ecoboost|puretech|vtec|mpi|"
                 r"t?[- ]?gdi|vvt[- ]?i|skyactiv[- ]?g)\b")
OTOMATIK_ADLARI = r"\b(otomatik|automatic|dsg|dct|cvt|edc|eat[- ]?[68]|steptronic|tiptronic|s[- ]?tronic|dualogic|amt)\b"
MANUEL_ADLARI = r"\b(manuel|manual|duz vites)\b"


def aile_uyumsuz(arac: Dict[str, Any], metin: str) -> Optional[str]:
    """Metin (ilan paketi/adresi) aracın yakıtına ya da vitesine açıkça uymuyorsa red nedeni."""
    blob, fuel, gear = fold(metin), fold(arac.get("fuel")), fold(arac.get("transmission"))
    dizel, benzin = re.search(DIZEL_ADLARI, blob), re.search(BENZIN_ADLARI, blob)
    if ("benzin" in fuel or "lpg" in fuel) and dizel and not benzin:
        return "yakıt uyumsuz"
    if ("dizel" in fuel or "diesel" in fuel) and benzin and not dizel:
        return "yakıt uyumsuz"
    otomatik, manuel = re.search(OTOMATIK_ADLARI, blob), re.search(MANUEL_ADLARI, blob)
    if ("manuel" in gear or "manual" in gear) and otomatik and not manuel:
        return "vites uyumsuz"
    if ("otomatik" in gear or "automatic" in gear) and manuel and not otomatik:
        return "vites uyumsuz"
    return None


def verify(listing: Dict[str, Any], sources: Dict[str, str], v: Dict[str, Any], *, year_window: int = 1,
           km_band_scale: int = 1, year_range: Optional[tuple] = None, ambiguous_year: Optional[int] = None,
           terms: tuple = ()) -> Optional[str]:
    """Ilan kullanilabilirse None, degilse red nedeni."""
    url = str(listing.get("url") or "").rstrip("/")
    price = _int(listing.get("fiyat_tl")) or 0
    manual = url.startswith(MANUAL_URL) and listing.get("_manual")
    if url not in sources and not manual:
        return "kaynaklarda yok"
    parts = urlsplit(url)
    if any(site in (parts.netloc + parts.path).lower() for site in AUCTION_SITES):
        return "açık artırma"
    if is_estimate_site(url):
        return "tahmin sitesi"
    if not MIN_PRICE <= price <= MAX_PRICE:
        return "fiyat geçersiz"
    if not manual and not price_in_text(price, sources[url]):
        return "fiyat sayfada yok"
    year, l_year = _int(v.get("year")), _int(listing.get("yil"))
    if year and not l_year:
        return "yıl bilinmiyor"  # yıl olmadan bu araca göre düzeltilemez
    if ambiguous_year and l_year == ambiguous_year:
        # Geçiş yılı ilanı iki kasadan biri olabilir: yalnız kasası metinde açıkça yazıyorsa alınır.
        blob = fold(f"{listing.get('paket') or ''} {listing.get('durum') or ''} {url}")
        title_words = set(re.findall(r"[a-z0-9]+", fold(f"{listing.get('paket') or ''} {url}")))
        if not any((t[len("kelime:"):] in title_words) if t.startswith("kelime:") else (t in blob) for t in terms):
            return "geçiş yılı belirsiz"
    if year and l_year and year_range and not year_range[0] <= l_year <= year_range[1]:
        return "yıl uyumsuz"
    if year and l_year and not year_range and abs(l_year - year) > year_window:
        return "yıl uyumsuz"
    km, l_km = _int(v.get("km")), _int(listing.get("km"))
    band = (km * 0.5 + 20_000) * km_band_scale if km is not None else 0
    if km is not None and l_km is not None and not (km - band <= l_km <= km + band):
        return "km uzak"
    target = _displacements(f"{v.get('package') or ''} {v.get('model') or ''}")
    found = _displacements(f"{listing.get('paket') or ''} {url}")
    if target and found and not (target & found):
        return "motor uyumsuz"
    aile = aile_uyumsuz(v, f"{listing.get('paket') or ''} {url}")
    if aile:
        return aile
    target_hp = _int(v.get("hp"))
    listing_hp = _int(listing.get("beygir")) or horsepower(f"{listing.get('paket') or ''} {url}")
    if target_hp and listing_hp and abs(target_hp - listing_hp) > HP_TOLERANCE:
        return "beygir farklı"
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


def _yearly_rate(items: List[Dict[str, Any]], target_km: Optional[int]) -> tuple:
    """İlanlardan yıllık değer kaybı: km düzeltilmiş log(fiyat) ~ yıl eğimi. En az 5 ilan ve
    2 farklı yıl gerekir; aksi halde varsayılan. Sonuç %2-12 ile sınırlanır."""
    points = []
    for i in items:
        year, price = _int(i.get("yil")), _int(i.get("fiyat_tl"))
        if year and price:
            points.append((year, math.log(price * _km_factor(_int(i.get("km")), target_km))))
    if len(points) < 5 or len({y for y, _ in points}) < 2:
        return DEFAULT_YEARLY_RATE, False
    mean_y = sum(y for y, _ in points) / len(points)
    mean_p = sum(p for _, p in points) / len(points)
    var = sum((y - mean_y) ** 2 for y, _ in points)
    slope = sum((y - mean_y) * (p - mean_p) for y, p in points) / var
    if slope <= 0:
        return DEFAULT_YEARLY_RATE, False
    rate = 1 - math.exp(-slope)
    return min(max(rate, YEARLY_RATE_LIMITS[0]), YEARLY_RATE_LIMITS[1]), True


def _km_factor(listing_km: Optional[int], target_km: Optional[int]) -> float:
    """Fazla km'li ilanın fiyatı bu araca göre yukarı, az km'li ilanınki aşağı düzeltilir."""
    if listing_km is None or target_km is None:
        return 1.0
    return 1 + max(-0.10, min(0.10, (listing_km - target_km) / 10_000 * KM_RATE_PER_10K))


def _adjusted(i: Dict[str, Any], v: Dict[str, Any], rate: float) -> int:
    """İlan fiyatını bu aracın yılına ve km'sine çevirir (aynı kasa/motor varsayımıyla)."""
    price = float(i["fiyat_tl"])
    year, l_year = _int(v.get("year")), _int(i.get("yil"))
    if year and l_year:
        price *= (1 - rate) ** (l_year - year)
    return int(round(price * _km_factor(_int(i.get("km")), _int(v.get("km")))))


def build_reference(results: List[Dict[str, Any]], v: Dict[str, Any], *, widened: bool = False,
                    year_range: Optional[tuple] = None, generation: Optional[Dict[str, Any]] = None,
                    ambiguous_year: Optional[int] = None, terms: tuple = ()) -> Dict[str, Any]:
    """Arama sonuclarini dogrular, birlestirir ve degerleme motorunun okudugu bicime cevirir."""
    accepted: Dict[str, Dict[str, Any]] = {}
    site_stats: Dict[str, Dict[str, int]] = {}
    rejected: Dict[str, int] = {}
    cost = 0.0
    for res in results:
        cost += float(res.get("cost") or 0)
        for item in res.get("listings") or []:
            reason = verify(item, res.get("sources") or {}, v, year_window=2 if widened else 1,
                            km_band_scale=2 if widened else 1, year_range=year_range,
                            ambiguous_year=ambiguous_year, terms=terms)
            if not reason and _condition(item) == "heavy":
                reason = "ağır hasarlı"
            # Ölçüm doğrulama denemelerine aittir; tekrarlanan arama sonuçları da sayılır.
            domain = (MANUAL_LABEL if str(item.get("url") or "").startswith(MANUAL_URL)
                      else (urlsplit(str(item.get("url") or "")).hostname or "bilinmiyor").removeprefix("www."))
            stats = site_stats.setdefault(domain, {"kabul": 0, "red": 0})
            stats["red" if reason else "kabul"] += 1
            if reason:
                rejected[reason] = rejected.get(reason, 0) + 1
                continue
            url = str(item["url"]).rstrip("/")
            accepted[url] = {**item, "url": url, "fiyat_tl": _int(item.get("fiyat_tl"))}

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
        "year_window": 2 if widened else 1, "widened": widened,
        "year_range": list(year_range) if year_range else None,
        "generation": ({k: generation.get(k) for k in ("kasa", "baslangic", "bitis", "makyaj", "kaynaklar")}
                       if generation and generation.get("bulundu") else None),
        "cost_usd": round(cost, 4), "rejected": rejected, "site_stats": site_stats,
        "listed_price": _int(v.get("listed_price")),
    }
    # Her ilan önce bu aracın yılına/km'sine çevrilir; ayıklama ve orta fiyat düzeltilmiş
    # fiyatlarla yapılır (önceden ham fiyatların ortası alınıp sonra tek sayı düzeltiliyordu).
    rate, rate_measured = _yearly_rate(items, _int(v.get("km")))
    for i in items:
        i["_adj"] = _adjusted(i, v, rate)
        i["_condition"] = _condition(i)
    scope.update(yearly_rate=round(rate, 4), yearly_rate_measured=rate_measured, normalized=True)
    med = statistics.median(i["_adj"] for i in items) if items else 0
    suspicious = [i for i in items if i["_adj"] < SUSPICIOUS_CHEAP * med and i["_condition"] != "damaged"]
    for i in suspicious:
        rejected["şüpheli ucuz"] = rejected.get("şüpheli ucuz", 0) + 1
    items = [i for i in items if i not in suspicious]
    med = statistics.median(i["_adj"] for i in items) if items else 0
    kept = [i for i in items if (1 - OUTLIER_BAND) * med <= i["_adj"] <= (1 + OUTLIER_BAND) * med]
    if len(kept) < MIN_SAMPLES:
        return {
            "found": False, "source": SOURCE, "reason": "not_enough_web_listings",
            "count": len(kept), "scope": scope, "package": v.get("package"), "samples": [],
        }
    kept.sort(key=lambda i: i["_adj"])
    prices = [i["_adj"] for i in kept]
    median_price = int(statistics.median(prices))
    clean = [i["_adj"] for i in kept if i["_condition"] == "clean"]
    kms = [k for k in (_int(i.get("km")) for i in kept) if k]
    years = [y for y in (_int(i.get("yil")) for i in kept) if y]

    if len(kept) < TARGET_SAMPLES:
        flags.append({"kod": "az_emsal", "mesaj": f"Yalnızca {len(kept)} doğrulanmış emsal ilan bulundu (hedef {TARGET_SAMPLES})"})
    if max(prices) / min(prices) > WIDE_SPREAD_RATIO:
        flags.append({"kod": "genis_aralik", "mesaj": "Emsal fiyatları birbirinden çok farklı; piyasa değerini kontrol edin"})
    if tokens and not package_match:
        flags.append({"kod": "paket_eslesmedi", "mesaj": f"Aynı paketten ({v.get('package')}) yeterli ilan yok; diğer paketler de kullanıldı"})
    if not tokens:
        # "1.5 TSI" gibi yalnız motor yazıldığında da buraya düşülür; "paket girilmemiş" demek müşteriyle çelişiyordu.
        flags.append({"kod": "paket_bilinmiyor", "mesaj": (
            "Donanım paketi belirtilmediği için emsaller bu motorun tüm donanım paketlerinden alındı"
            if v.get("package") else "Araç paketi girilmemiş; emsaller modelin tüm paketlerinden")})

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
        # Fiyatlar zaten bu araca çevrildi; değerleme motoru ikinci kez yıl/km düzeltmesi yapmasın.
        "reference_median_km": _int(v.get("km")) or (int(statistics.median(kms)) if kms else 0),
        "reference_median_year": _int(v.get("year")) or (int(statistics.median(years)) if years else 0),
        "listing_median_km": int(statistics.median(kms)) if kms else 0,
        "listing_median_year": int(statistics.median(years)) if years else 0,
        "same_year_count": sum(1 for y in years if y == _int(v.get("year"))),
        "stale": False,
        "confidence": int(confidence),
        "package": v.get("package"),
        "package_match": package_match,
        "kontrol": flags,
        "uyari": "; ".join(f["mesaj"] for f in flags) or None,
        "scope": scope,
        "manual_count": sum(1 for i in kept if str(i.get("url") or "").startswith(MANUAL_URL)),
        "samples": [
            {
                "price": i["fiyat_tl"], "adjusted_price": i["_adj"], "km": _int(i.get("km")), "year": _int(i.get("yil")),
                "title": " ".join(str(x) for x in (v.get("brand"), v.get("model"), i.get("paket")) if x),
                "url": i["url"], "site": urlsplit(i["url"]).netloc.replace("www.", ""),
                "condition": i["_condition"], "declared": (str(i.get("durum") or "")[:80] or None),
                "listing_date": (str(i.get("ilan_tarihi") or "")[:20] or None),
            }
            for i in kept if not str(i.get("url") or "").startswith(MANUAL_URL)
        ],
        "searched_at": datetime.now().isoformat(timespec="seconds"),
    }


def _pool_summary(reference: Dict[str, Any], generation: Dict[str, Any]) -> Dict[str, Any]:
    return {"kasa": generation.get("kasa"), "baslangic": generation.get("baslangic"), "bitis": generation.get("bitis"),
            "bulundu": bool(reference.get("found")), "orta_fiyat": reference.get("market_median_price"),
            "emsal": reference.get("count") or 0}


def _transition(vehicle: Dict[str, Any], new_ref: Dict[str, Any], old_ref: Dict[str, Any],
                new_gen: Dict[str, Any], old_gen: Dict[str, Any]) -> Dict[str, Any]:
    """Geçiş yılında değerlemenin hangi kasaya göre yapılacağı ve iki kasanın özeti.
    Müşteri kasayı seçtiyse o; seçmediyse ilan fiyatının daha yakın olduğu kasa (açıkça yazılır)."""
    choice = fold(vehicle.get("kasa")).strip()
    candidates = {"yeni": new_ref, "eski": old_ref}
    found = {k: r for k, r in candidates.items() if r.get("found")}
    if choice in candidates and choice not in found:
        # Müşteri kasayı seçti ama o kasa için yeterli ilan yok: diğer kasaya göre değerlendirilmez
        # (MG HS 2024 örneği: yeni kasa seçildi, eski kasa ilanlarıyla düşük değer çıkmıştı).
        selected, reason = choice, "secilen_bulunamadi"
    elif choice in found:
        selected, reason = choice, "musteri"
    elif len(found) == 2 and _int(vehicle.get("listed_price")):
        price = _int(vehicle.get("listed_price"))
        selected = min(found, key=lambda k: abs(found[k]["market_median_price"] - price))
        reason = "ilan_fiyati"
    elif found:
        selected, reason = next(iter(found)), "tek_havuz"
    else:
        selected, reason = "yeni", "bulunamadi"
    ref = candidates[selected]
    cost = sum(float((r.get("scope") or {}).get("cost_usd") or 0) for r in candidates.values())
    ref.setdefault("scope", {})["cost_usd"] = round(cost, 4)
    ref["gecis"] = {"yil": _int(vehicle.get("year")), "secilen": selected, "neden": reason,
                    "yeni": _pool_summary(new_ref, new_gen), "eski": _pool_summary(old_ref, old_gen)}
    return ref


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
    generation: Dict[str, Any] = {"bulundu": False}
    year = _int(vehicle.get("year")) or 0
    year_range = None
    previous, previous_range = None, None
    if search is None:
        from yerimebak_ai_v5.services import vehicle_generation
        generation = vehicle_generation.get_generation(vehicle)
        if generation.get("uyusmazlik"):
            year_range = (year, year)  # kaynaklar uyuşmadı: kasa bilinmez, yalnız aracın kendi yılı
        else:
            year_range = vehicle_generation.year_range(generation, year)
        if generation.get("gecis_yili") and generation.get("onceki"):
            previous = generation["onceki"]
            previous_range = vehicle_generation.year_range(previous, year)

    def run_round(rng, widened: bool = False) -> List[Dict[str, Any]]:
        qs = queries(vehicle, widened=widened, year_range=rng)
        if search is not None:
            return [search(q) for q in qs]
        results = []
        # httpx zaman aşımı "veri gelmezse" sınırıdır; OpenRouter bekleme boşlukları
        # gönderdiği için toplam süreyi sınırlamaz. Tur için kesin süre burada uygulanır.
        client = httpx.Client(timeout=90.0)
        pool = ThreadPoolExecutor(len(qs))
        try:
            futures = [pool.submit(_search, q, client) for q in qs]
            done, _pending = wait(futures, timeout=_round_seconds())
            for fut in futures:
                if fut not in done:
                    logger.warning("[WEB FIYAT] Arama %.0f sn icinde bitmedi, atlandi", _round_seconds())
                    continue
                try:
                    results.append(fut.result())
                except Exception as exc:
                    logger.warning("[WEB FIYAT] Arama basarisiz: %s", str(exc)[:200])
        finally:
            client.close()  # süren istekleri keser
            pool.shutdown(wait=False, cancel_futures=True)
        return results

    def pool_reference(rng, gen, ambiguous=None, terms=()):
        found = run_round(rng)
        reference = build_reference(found, vehicle, year_range=rng, generation=gen, ambiguous_year=ambiguous, terms=terms)
        if reference.get("count", 0) < TARGET_SAMPLES:
            found.extend(run_round(rng, widened=True))
            reference = build_reference(found, vehicle, widened=True, year_range=rng, generation=gen,
                                        ambiguous_year=ambiguous, terms=terms)
        if reference.get("count", 0) < TARGET_SAMPLES and search is None:
            # Verisi az olan modeller: admin'in girdiği piyasa takibi kayıtları (kullanıcı kararı)
            from yerimebak_ai_v5.services import manual_market
            manual = manual_market.find(vehicle)
            if manual:
                found = found + [{"listings": manual, "sources": {}, "cost": 0}]
                reference = build_reference(found, vehicle, widened=True, year_range=rng, generation=gen,
                                            ambiguous_year=ambiguous, terms=terms)
        return found, reference

    if previous_range:
        # Geçiş yılı: iki kasa ayrı havuzlarda, aynı anda (kullanıcı kararı, 02.11.2026)
        with ThreadPoolExecutor(2) as pools:
            # Aynı yılın ilanları iki kasadan biri olabilir: kasası metinde yazmıyorsa iki havuza da
            # girmez (ölçüm: TL havuzuna 2021 NX4 ilanları karışıp eski kasayı pahalı gösterdi).
            new_future = pools.submit(pool_reference, year_range, generation, year, kasa_terms(generation, True, vehicle))
            old_future = pools.submit(pool_reference, previous_range, previous, year, kasa_terms(previous, False, vehicle))
            results, ref = new_future.result()
            old_results, old_ref = old_future.result()
        ref, results = _transition(vehicle, ref, old_ref, generation, previous), results + old_results
    else:
        results, ref = pool_reference(year_range, generation)
    ref["scope"]["cost_usd"] = round(ref["scope"]["cost_usd"] + float(generation.get("cost_usd") or 0), 4)
    if not results:
        return None
    if hours and ref.get("found"):
        _cache_write(key, ref)
    logger.info("[WEB FIYAT] %s %s %s: %s emsal, medyan %s, maliyet $%s, red %s",
                vehicle.get("brand"), vehicle.get("model"), vehicle.get("year"), ref.get("count"),
                ref.get("market_median_price"), ref["scope"]["cost_usd"], ref["scope"]["rejected"])
    return ref
