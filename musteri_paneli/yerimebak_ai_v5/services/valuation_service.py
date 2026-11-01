# -*- coding: utf-8 -*-
"""
Musteri arac degerlemesi (kredi ile).

Musteri ilan linkini paylasir veya bilgileri elle girer; boyali / degisen parcalar
ve tramer (hasar kaydi) bildirilir. Sistem:
  1. Kazinan guncel ilanlardan piyasa ortalamasini (emsal) bulur,
  2. Her bulgunun deger kaybini dusup tavsiye (alim) fiyatini cikarir,
  3. Ilan fiyatina gore AL / PAZARLIK / ALMA karari verir,
  4. Admin'in girdigi aylik arac enflasyonuyla 6 ay / 1 yil sonraki degeri ve getiriyi hesaplar.

Yeterli emsal yoksa analiz yapilmaz ve kredi dusulmez.
"""
import logging
import re
from datetime import datetime
from typing import Any, Dict, List, Optional
from urllib.parse import urlsplit, urlunsplit

from yerimebak_ai_v5.core.ai.inspection_valuation import PART_LABELS, evaluate
from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.core.market_reference_service import get_market_reference_service
from yerimebak_ai_v5.services import pricing_service, web_market_reference

logger = logging.getLogger(__name__)

ANALYSIS_COST = 1
PART_STATUSES = ("orijinal", "lokal_boyali", "boyali", "degisen")
VERDICTS = {
    "AVANTAJLI": ("AL", "Fiyat, aracın bulgulara göre değerinin altında; alım için avantajlı."),
    "MAKUL": ("AL", "Fiyat, aracın bulgulara göre değeriyle uyumlu; tavsiye fiyata yakın alınabilir."),
    "PAZARLIK": ("PAZARLIK YAP", "Fiyat biraz yüksek; tavsiye fiyata inmek için pazarlık önerilir."),
    "YUKSEK": ("ALMA", "Fiyat, aracın bulgulara göre değerinin belirgin üzerinde; bu fiyattan alınması önerilmez."),
}


def _error(message: str, status: int = 400, code: Optional[str] = None) -> Dict[str, Any]:
    out = {"error": message, "http_status": status}
    if code:
        out["code"] = code
    return out


def _int(value: Any) -> Optional[int]:
    if value in (None, ""):
        return None
    try:
        return int(float(str(value).replace(".", "").replace(",", ".")) if isinstance(value, str) else float(value))
    except (TypeError, ValueError):
        return None


def normalize_url(url: str) -> str:
    """Sorgu/parca kisimlari atilir; ayni ilanin farkli linkleri eslesir."""
    url = (url or "").strip()
    if not url:
        return ""
    if not re.match(r"^https?://", url, re.I):
        url = "https://" + url
    parts = urlsplit(url)
    return urlunsplit((parts.scheme.lower(), parts.netloc.lower(), parts.path.rstrip("/"), "", ""))


LOW_CONFIDENCE_VERDICT = "EK DOĞRULAMA GEREKLİ"
LOW_CONFIDENCE_FLAGS = ("az_emsal", "genis_aralik")


def _tl(value: Any) -> str:
    try:
        return f"{int(round(float(value))):,} TL".replace(",", ".")
    except (TypeError, ValueError):
        return "-"


def confidence_level(score: int, flags: List[Dict[str, Any]]) -> str:
    """Raporun piyasa verisine guveni: yuksek | orta | dusuk (dusukte kesin karar verilmez)."""
    if score < 50 or any(f.get("kod") in LOW_CONFIDENCE_FLAGS for f in flags):
        return "dusuk"
    return "yuksek" if score >= 70 else "orta"


def decision_summary(
    *, price: float, degerleme: Dict[str, Any], recommended: float, verdict_key: str,
    karar: str, karar_aciklama: str, confidence: int, flags: List[Dict[str, Any]],
    reference: Dict[str, Any], from_saved_listing: bool,
) -> Dict[str, Any]:
    """Musterinin ilk ekranda gordugu karar, 5 sorunun cevabi ve bilgi kaynaklari.

    Dusuk guvende AL/ALMA verilmez; hesaplanan egilim yalnizca bilgi olarak kalir.
    Hasar bilgileri musteri/ilan beyanidir, uzman tarafindan dogrulanmamistir.
    """
    level = confidence_level(confidence, flags)
    aralik = degerleme.get("adilFiyatAraligi") or {}
    fark = (degerleme.get("fiyatYorumu") or {}).get("farkYuzde")
    if level == "dusuk":
        sonuc, aciklama = LOW_CONFIDENCE_VERDICT, (
            "Bu araç için bulunan piyasa verisi kesin karar vermeye yetmiyor. Aşağıdaki fiyatları "
            "yön gösterici kabul edin; satın almadan önce ilanı ve aracı uzman incelemesiyle doğrulayın.")
    else:
        sonuc, aciklama = karar, karar_aciklama

    if verdict_key == "AVANTAJLI":
        konum = "altinda"
    elif verdict_key == "MAKUL":
        konum = "uyumlu"
    else:
        konum = "ustunde"
    konum_metni = {"altinda": "Piyasanın altında", "uyumlu": "Piyasayla uyumlu", "ustunde": "Piyasanın üstünde"}[konum]
    if fark is not None:
        konum_metni += f" (ilan fiyatı hesaplanan değerin %{abs(fark):.1f} {'altında' if fark < 0 else 'üstünde'})"

    kalemler = sorted(degerleme.get("kalemler") or [], key=lambda k: k.get("tutar") or 0, reverse=True)
    riskler: List[str] = []
    if degerleme.get("agirHasar"):
        riskler.append("Ağır hasar sınıfında bulgu bildirildi; aracın yapısal durumu mutlaka uzmanca incelenmeli.")
    for k in kalemler[:2]:
        if (k.get("tutar") or 0) > 0:
            riskler.append(f"{k.get('baslik')} ({str(k.get('durum') or '').lower()}): değeri yaklaşık {_tl(k.get('tutar'))} düşürüyor.")
    for f in flags:
        if f.get("kod") in LOW_CONFIDENCE_FLAGS and f.get("mesaj"):
            riskler.append(f["mesaj"] + ".")
    riskler.append("Boya, değişen ve tramer bilgileri ilan/müşteri beyanına dayanıyor; uzman tarafından doğrulanmadı.")

    gerekceler: List[str] = []
    if aralik.get("max") and price > aralik["max"]:
        gerekceler.append(f"İlan fiyatı adil aralığın üst sınırından {_tl(price - aralik['max'])} yüksek.")
    if reference.get("count") and reference.get("market_median_price"):
        gerekceler.append(f"Benzer {reference['count']} ilanın orta fiyatı {_tl(reference['market_median_price'])}.")
    for k in kalemler[:2]:
        if (k.get("tutar") or 0) > 0:
            gerekceler.append(f"{k.get('baslik')} {str(k.get('durum') or '').lower()}: yaklaşık {_tl(k.get('tutar'))} değer kaybı.")

    if sonuc == LOW_CONFIDENCE_VERDICT:
        adim = "Veri sınırlı: kararınızı ilan bilgileri ve uzman incelemesiyle netleştirin."
    elif karar == "AL":
        adim = "Fiyat uygun görünüyor. Ödeme yapmadan önce aracı yerinde inceletin."
    elif karar == "PAZARLIK YAP":
        adim = f"{_tl(recommended)} civarına inmek için pazarlık edin, ardından aracı yerinde inceletin."
    else:
        adim = f"Bu fiyattan almayın; fiyat {_tl(recommended)} civarına inmezse başka ilanlara bakın."

    piyasa_kaynagi = reference.get("source")
    return {
        "karar": {"sonuc": sonuc, "aciklama": aciklama, "guvenSeviyesi": level,
                  "hesaplananEgilim": karar if level == "dusuk" else None},
        "ozet": {
            "piyasaKonumu": {"durum": konum, "metin": konum_metni},
            "adilFiyat": {"min": aralik.get("min"), "max": aralik.get("max")},
            "riskler": riskler[:4],
            "pazarlikGerekceleri": gerekceler[:3],
            "simdiNeYapmali": adim,
        },
        "bilgiKaynaklari": [
            {"alan": "Araç bilgileri (marka, model, yıl, km, fiyat)",
             "kaynak": "kayitli_ilan" if from_saved_listing else "musteri_beyani",
             "aciklama": "Kayıtlı ilandan" if from_saved_listing else "Sizin girdiğiniz bilgiler"},
            {"alan": "Boya, değişen ve tramer", "kaynak": "musteri_beyani",
             "aciklama": "İlan/müşteri beyanı; uzman tarafından doğrulanmadı"},
            {"alan": "Piyasa değeri",
             "kaynak": "internet_ilanlari" if piyasa_kaynagi == "web_listings" else "kayitli_ilanlar",
             "aciklama": "Fiyatı kaynak sayfada doğrulanan benzer ilanlar" if piyasa_kaynagi == "web_listings"
             else "Sistemde kayıtlı benzer ilanlar"},
            {"alan": "Değer kaybı, adil fiyat ve tavsiye fiyat", "kaynak": "hesaplama",
             "aciklama": "Bulguların piyasa değerine etkisiyle hesaplandı"},
            {"alan": "Gelecek değer", "kaynak": "tahmin",
             "aciklama": "Araç enflasyonu varsayımına dayanan tahmin; kesin değildir"},
        ],
    }


def _listing_by_url(url: str) -> Optional[Dict[str, Any]]:
    norm = normalize_url(url)
    if not norm:
        return None
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT id, brand, model, year, km, price, fuel, transmission, title, url, image_url,
                   location, paint_info, accident_record
            FROM listings
            WHERE regexp_replace(rtrim(split_part(split_part(lower(url), '?', 1), '#', 1), '/'), '^https?://', '') = %s
            LIMIT 1
            """,
            (re.sub(r"^https?://", "", norm.lower()),),
        )
        row = cursor.fetchone()
        return dict(row) if row else None
    finally:
        DatabaseConfig.return_connection(conn)


def _known_brands() -> List[str]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT DISTINCT brand FROM listings WHERE brand IS NOT NULL AND brand <> ''")
        return [str(dict(r)["brand"]) for r in cursor.fetchall()]
    finally:
        DatabaseConfig.return_connection(conn)


def _known_models(brand: str) -> List[str]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT DISTINCT model FROM listings WHERE lower(brand) = lower(%s) AND model IS NOT NULL AND model <> ''",
            (brand,),
        )
        return [str(dict(r)["model"]) for r in cursor.fetchall()]
    finally:
        DatabaseConfig.return_connection(conn)


def _slug(text: str) -> List[str]:
    text = (text or "").lower()
    for src, dst in (("ç", "c"), ("ğ", "g"), ("ı", "i"), ("i̇", "i"), ("ö", "o"), ("ş", "s"), ("ü", "u")):
        text = text.replace(src, dst)
    return [t for t in re.split(r"[^a-z0-9]+", text) if t]


def _find(tokens: List[str], words: List[str], start: int = 0) -> Optional[int]:
    for i in range(start, len(tokens) - len(words) + 1):
        if words and tokens[i:i + len(words)] == words:
            return i
    return None


def _guess_from_slug(url: str) -> Dict[str, Any]:
    """Ilan veritabaninda yoksa linkteki metinden marka/model/yil tahmini (musteri dogrular).

    arabam.com ve sahibinden.com ilan adresleri basliktan uretilir, ör.
    sahibinden.com/ilan/vasita-otomobil-renault-clio-1.0-tce-touch-2019-1234567890/detay
    """
    tokens = _slug(urlsplit(normalize_url(url)).path)
    guess: Dict[str, Any] = {}
    used: set = set()
    for brand in sorted(_known_brands(), key=len, reverse=True):
        words = _slug(brand)
        i = _find(tokens, words)
        if i is None:
            continue
        guess["brand"] = brand
        used.update(range(i, i + len(words)))
        after = i + len(words)
        # Bilinen modellerden en uzun eslesen (ör. "3 Serisi", "C-Elysee"), yoksa markadan sonraki kelime
        for model in sorted(_known_models(brand), key=lambda m: len(_slug(m)), reverse=True):
            m_words = _slug(model)
            j = _find(tokens, m_words, after)
            if j is not None:
                guess["model"] = model
                used.update(range(j, j + len(m_words)))
                break
        else:
            if after < len(tokens):
                guess["model"] = tokens[after].capitalize()
                used.add(after)
        break
    # Model adindaki sayilar (Peugeot 2008) ve ilan numarasi yil sayilmaz
    year = next((int(t) for k, t in enumerate(tokens)
                 if k not in used and len(t) == 4 and t.isdigit() and 1990 <= int(t) <= datetime.now().year + 1), None)
    if year:
        guess["year"] = year
    return guess


def _paint_to_parts(paint_info: Any) -> Dict[str, str]:
    """Kazinan ilandaki boya/degisen bilgisini parca anahtarlarina cevirir."""
    import json as _json

    if isinstance(paint_info, str):
        try:
            paint_info = _json.loads(paint_info)
        except ValueError:
            return {}
    if not isinstance(paint_info, dict):
        return {}
    labels = {v.lower(): k for k, v in PART_LABELS.items()}
    parts: Dict[str, str] = {}
    # painted_parts lokal boyalilari da icerir; lokal bilgisi ezilmesin diye boyali once islenir
    for status, key in (("boyali", "painted_parts"), ("lokal_boyali", "local_painted_parts"), ("degisen", "changed_parts")):
        for label in paint_info.get(key) or []:
            part = labels.get(str(label).strip().lower())
            if part:
                parts[part] = status
    return parts


def prefill_from_link(url: str) -> Dict[str, Any]:
    from yerimebak_ai_v5.services import listing_links

    if not normalize_url(url):
        return _error("Geçerli bir ilan linki girin")
    # shbd.io gibi kisa linkler once asil ilan adresine cevrilir
    if listing_links.is_short_link(url):
        url = listing_links.resolve_short_link(url)
    listing = _listing_by_url(url)
    if listing:
        return {
            "success": True,
            "found": True,
            "listing_id": listing["id"],
            "url": normalize_url(url),
            "vehicle": {
                "brand": listing.get("brand"), "model": listing.get("model"), "year": listing.get("year"),
                "km": listing.get("km"), "price": listing.get("price"), "fuel": listing.get("fuel"),
                "transmission": listing.get("transmission"), "title": listing.get("title"),
                "image_url": listing.get("image_url"), "location": listing.get("location"),
            },
            "parts": _paint_to_parts(listing.get("paint_info")),
            "message": "İlan sistemimizde bulundu; bilgileri kontrol edip eksikleri tamamlayın.",
        }
    source = listing_links.link_source(url)
    if listing_links.is_short_link(url):
        message = "Kısa link açılamadı; araç bilgilerini elle girin."
    elif listing_links.is_site_short_link(url):
        message = ("Sahibinden kısa linkinden araç bilgisi okunamıyor. İlanın tam adresini "
                   "(sahibinden.com/ilan/...) yapıştırın ya da bilgileri elle girin.")
    elif source == "sahibinden":
        message = ("Sahibinden ilanının bilgilerini linkten tahmin ettik; kontrol edin. "
                   "Yıl, km, fiyat, boya-değişen ve tramer bilgisini ilandan bakarak girin.")
    else:
        message = "İlan sistemimizde yok; linkten tahmin edilen bilgileri kontrol edip eksikleri elle girin."
    return {
        "success": True,
        "found": False,
        "source": source,
        "url": normalize_url(url),
        "vehicle": _guess_from_slug(url),
        "parts": {},
        "message": message,
    }


def inflation_projection(ai_value: float, purchase_price: float) -> Optional[Dict[str, Any]]:
    settings = pricing_service.get_pricing_settings().get("vehicle_inflation")
    if not settings:
        return None
    monthly = float(settings["monthly_pct"]) / 100.0

    def horizon(months: int) -> Dict[str, Any]:
        future = ai_value * (1 + monthly) ** months
        gain = future - purchase_price
        return {
            "ay": months,
            "tahminiDeger": int(round(future, -3)),
            "getiriTl": int(round(gain, -3)),
            "getiriYuzde": round(gain / purchase_price * 100, 1) if purchase_price else None,
        }

    return {
        "aylikEnflasyonYuzde": float(settings["monthly_pct"]),
        "yillikEnflasyonYuzde": round(((1 + monthly) ** 12 - 1) * 100, 1),
        "kaynak": settings.get("note") or "",
        "gecerlilikTarihi": settings.get("effective_date"),
        "alisFiyati": int(purchase_price),
        "altiAy": horizon(6),
        "birYil": horizon(12),
        "aciklama": (
            "Tahmini değer, aracın bugünkü bulgu düzeltmeli değerinin aylık araç enflasyonu ile "
            "büyütülmesiyle hesaplanır; getiri, tavsiye alım fiyatına göre beklenen değer artışıdır. "
            "Piyasa koşullarına göre değişebilir, yatırım tavsiyesi değildir."
        ),
    }


def _clean_parts(raw: Any) -> Dict[str, str]:
    parts: Dict[str, str] = {}
    if not isinstance(raw, dict):
        return parts
    for key, status in raw.items():
        status = str(status or "").strip().lower()
        if key in PART_LABELS and status in PART_STATUSES and status != "orijinal":
            parts[key] = status
    return parts


def analyze(user: Dict[str, Any], payload: Dict[str, Any]) -> Dict[str, Any]:
    from yerimebak_ai_v5.services.valuation_reports import request_guard

    with request_guard(user['id'], payload.get('request_id')) as previous:
        if previous is not None:
            return previous
        return _analyze_once(user, payload)


def _analyze_once(user: Dict[str, Any], payload: Dict[str, Any]) -> Dict[str, Any]:
    from yerimebak_ai_v5.services.payment_service import get_payment_service
    from yerimebak_ai_v5.services.valuation_reports import ENGINE_VERSION

    listing = None
    if payload.get("listing_url"):
        listing = _listing_by_url(payload["listing_url"])

    def pick(key: str, listing_key: Optional[str] = None):
        value = payload.get(key)
        if value in (None, "") and listing:
            value = listing.get(listing_key or key)
        return value

    brand = str(pick("brand") or "").strip()
    model = str(pick("model") or "").strip()
    year = _int(pick("year"))
    km = _int(pick("km"))
    price = _int(pick("listed_price", "price"))
    fuel = str(pick("fuel") or "").strip() or None
    transmission = str(pick("transmission") or "").strip() or None

    missing = [name for name, value in (("marka", brand), ("model", model), ("yıl", year), ("km", km), ("ilan fiyatı", price)) if not value]
    if missing:
        return _error(f"Eksik bilgi: {', '.join(missing)}")
    if not 1980 <= year <= datetime.now().year + 1:
        return _error("Model yılı geçersiz")
    if not 0 <= km <= 2_000_000 or not 10_000 <= price <= 200_000_000:
        return _error("Km veya ilan fiyatı geçersiz")

    parts = _clean_parts(payload.get("parts"))
    if not parts and listing and payload.get("parts") is None:
        parts = _paint_to_parts(listing.get("paint_info"))
    tramer_amount = max(0, _int(payload.get("tramer_amount")) or 0)
    tramer_count = max(0, _int(payload.get("tramer_count")) or (1 if tramer_amount else 0))

    payment = get_payment_service()
    from yerimebak_ai_v5.services.payment_service import credit_refusal

    allowed = payment.analysis_allowed(user["id"])
    if not allowed.get("ok"):
        status, code, message = credit_refusal(allowed.get("reason"))
        return _error(message, status, code)

    reference = web_market_reference.get_reference({
        "brand": brand, "model": model, "year": year, "km": km, "fuel": fuel,
        "transmission": transmission, "package": payload.get("package"), "listed_price": price,
    })
    if not reference or not reference.get("found"):
        reference = get_market_reference_service().get_reference(
            brand=brand, model=model, year=year, km=km, fuel=fuel, transmission=transmission,
            exclude_id=listing.get("id") if listing else None, listed_price=price,
        )
    if not reference.get("count") or str(reference.get("source", "")).startswith("last_resort"):
        return _error(
            f"{brand} {model} {year} için yeterli güncel piyasa verisi yok. Kredi düşülmedi; "
            "veri toplandıkça tekrar deneyebilirsiniz.",
            422, "insufficient_market_data",
        )

    tam_rapor = {
        "adim1": {
            "marka": brand, "model": model, "yil": year, "guncelKm": km,
            "hasarKayitToplamTutar": tramer_amount, "hasarKayitAdet": tramer_count,
            "yakitTuru": fuel, "vites": transmission,
        },
        "adim4": {"parcaDurumlari": parts},
    }
    degerleme = evaluate(tam_rapor, reference, listed_price=price, vehicle={"km": km, "yil": year})
    if not degerleme.get("degerlemeYapildi") or not degerleme.get("aiDegeri"):
        return _error("Bu araç için değerleme yapılamadı. Kredi düşülmedi.", 422, "valuation_failed")

    ai_value = float(degerleme["aiDegeri"])
    recommended = float(degerleme.get("onerilenAlimFiyati") or ai_value)
    verdict_key = (degerleme.get("fiyatYorumu") or {}).get("karar", "MAKUL")
    karar, karar_aciklama = VERDICTS.get(verdict_key, VERDICTS["MAKUL"])
    flags = reference.get("kontrol") or []
    confidence = degerleme.get("guvenSkoru") or 0
    if any(f.get("kod") in LOW_CONFIDENCE_FLAGS for f in flags):
        confidence = min(confidence, 49)
    purchase_price = min(float(price), recommended)
    projection = inflation_projection(ai_value, purchase_price)

    result = {
        "arac": {"marka": brand, "model": model, "yil": year, "km": km, "yakit": fuel, "vites": transmission,
                 "ilanFiyati": price, "ilanLinki": payload.get("listing_url") or None},
        "piyasa": {
            "ortalama": reference.get("market_avg_price"),
            "medyan": reference.get("market_median_price"),
            "min": reference.get("market_min_price"),
            "max": reference.get("market_max_price"),
            "emsalSayisi": reference.get("count"),
            "hasarsizEmsalSayisi": reference.get("clean_count"),
            "guvenSkoru": confidence,
            "kaynak": reference.get("source"),
            "kaynaklar": [{"site": s.get("site"), "url": s.get("url"), "fiyat": s.get("price"),
                           "km": s.get("km"), "yil": s.get("year")} for s in (reference.get("samples") or [])[:10]],
            "uyarilar": [f["mesaj"] for f in flags if f.get("mesaj")],
            "guncelGun": reference.get("recent_days"),
        },
        "degerleme": {
            "temizPiyasaDegeri": degerleme.get("temizPiyasaDegeri"),
            "toplamDegerKaybiYuzde": degerleme.get("toplamDegerKaybiYuzde"),
            "toplamDegerKaybiTutar": degerleme.get("toplamDegerKaybiTutar"),
            "kalemler": degerleme.get("kalemler") or [],
            "aiDegeri": degerleme.get("aiDegeri"),
            "adilFiyatAraligi": degerleme.get("adilFiyatAraligi"),
            "tavsiyeFiyat": int(recommended),
            "hasarSeviyesi": degerleme.get("hasarSeviyesi"),
            "agirHasar": degerleme.get("agirHasar"),
            "ozet": degerleme.get("ozet"),
        },
        "karar": {
            "ilanFarkiYuzde": (degerleme.get("fiyatYorumu") or {}).get("farkYuzde"),
            "ilanFarkiTutar": (degerleme.get("fiyatYorumu") or {}).get("farkTutar"),
        },
        "getiri": projection,
    }
    summary = decision_summary(
        price=float(price), degerleme=degerleme, recommended=recommended, verdict_key=verdict_key,
        karar=karar, karar_aciklama=karar_aciklama, confidence=int(confidence), flags=flags,
        reference=reference, from_saved_listing=bool(listing),
    )
    result["karar"].update(summary["karar"])
    result["ozet"] = summary["ozet"]
    result["bilgiKaynaklari"] = summary["bilgiKaynaklari"]

    deduction = payment.deduct_credits(
        user["id"],
        amount=ANALYSIS_COST,
        report_data=result,
        request_id=str(payload['request_id']) if payload.get('request_id') else None,
        engine_version=ENGINE_VERSION,
        description=f"Arac degerleme: {brand} {model} {year}",
        vehicle_data={**result["arac"], "source": "panel_valuation", "parts": parts,
                      "tramer_amount": tramer_amount},
        valuation_data={"credits_deducted": ANALYSIS_COST, "karar": result["karar"]["sonuc"], "tavsiye_fiyat": int(recommended),
                        "ai_degeri": degerleme.get("aiDegeri"), "piyasa_ortalama": reference.get("market_avg_price"),
                        "getiri": projection, "piyasa_kaynagi": reference.get("source"),
                        "web_maliyet_usd": (reference.get("scope") or {}).get("cost_usd", 0)},
    )
    if not deduction.get("success"):
        # Kilitli d???m son karard?r; e? zamanl? istekte kredi kalmad?ysa sonu? verilmez
        status, code, message = credit_refusal(deduction.get("code"), deduction.get("credits"))
        return _error(message, status, code)
    if deduction.get('report'):
        return deduction['report']
    result["kredi"] = {"dusulen": ANALYSIS_COST, "kalan": deduction.get("credits_after")}
    result["success"] = True
    return result
