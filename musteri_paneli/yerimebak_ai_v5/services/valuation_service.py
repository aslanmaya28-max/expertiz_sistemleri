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
from concurrent.futures import ThreadPoolExecutor
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


def _kalem_metni(k: Dict[str, Any]) -> str:
    """'Sol Arka Çamurluk (lokal boyalı)' / 'Tramer (hasar kaydı) 20.000 TL' (tutar küçük harfe çevrilmez)."""
    baslik, durum = str(k.get("baslik") or ""), str(k.get("durum") or "")
    if not durum:
        return baslik
    if any(ch.isdigit() for ch in durum):
        return f"{baslik} {durum}"
    return f"{baslik} ({durum.replace('I', 'ı').replace('İ', 'i').lower()})"


def _uyari_metni(flag: Dict[str, Any], package: Optional[str]) -> str:
    """Önbellekteki eski emsal aramalarında "paket girilmemiş" metni, yalnız motor yazılmış araçta da kalmıştı."""
    if flag.get("kod") == "paket_bilinmiyor" and package:
        return "Donanım paketi belirtilmediği için emsaller bu motorun tüm donanım paketlerinden alındı"
    return flag["mesaj"]

def _beyan_ozeti(text: Optional[str]) -> Optional[str]:
    """Motorun ekspertiz cümlesi kredili değerlemede beyana göre yazılır (ortada ekspertiz yok)."""
    if not text:
        return text
    text = text.replace("Ekspertizde kaporta işlemi tespit edilmedi", "Beyana göre araçta kaporta işlemi yok", 1)
    # Fiyat yorumu da ekspertize değil hesaplanan değere göredir (araç görülmedi).
    for eski, yeni in (("ekspertiz sonucuyla uyumlu", "hesaplanan değerle uyumlu"),
                       ("ekspertiz sonucuna göre piyasanın altında", "hesaplanan değere göre piyasanın altında")):
        text = text.replace(eski, yeni)
    return re.sub(r"^Ekspertizde (.+?) tespit edildi", r"Beyana göre araçta \1 var", text)


def _transition_view(gecis: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    if not gecis:
        return None

    def pool(entry: Dict[str, Any]) -> Dict[str, Any]:
        return {"kasa": entry.get("kasa"), "baslangic": entry.get("baslangic"), "bitis": entry.get("bitis"),
                "ortaFiyat": entry.get("orta_fiyat") if entry.get("bulundu") else None, "emsal": entry.get("emsal")}

    return {"yil": gecis.get("yil"), "secilen": gecis.get("secilen"), "neden": gecis.get("neden"),
            "yeni": pool(gecis.get("yeni") or {}), "eski": pool(gecis.get("eski") or {})}


def generation_choices(brand: str, model: str, year: int) -> Dict[str, Any]:
    """Form için: yıl kasa geçiş yılıysa seçenekler (yeni/eski), değilse tek kasa bilgisi."""
    from yerimebak_ai_v5.services import vehicle_generation

    gen = vehicle_generation.get_generation({"brand": brand.strip()[:60], "model": model.strip()[:60], "year": year})
    if not gen.get("bulundu"):
        return {"gecisYili": False, "kasa": None, "secenekler": []}

    def option(code: str, g: Dict[str, Any]) -> Dict[str, Any]:
        return {"kod": code, "kasa": g.get("kasa"), "baslangic": g.get("baslangic"), "bitis": g.get("bitis")}

    options = [option("yeni", gen)] + ([option("eski", gen["onceki"])] if gen.get("gecis_yili") and gen.get("onceki") else [])
    return {"gecisYili": len(options) > 1, "kasa": gen.get("kasa"), "secenekler": options}


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


# İlan fiyatı benzer ilanlardan bu kadar yüksekse "pahalı" demeden önce farkın nedeni sorulur:
# fark yeni kasa, motor gücü, donanım ya da garantiden gelebilir (MG HS 2024 örneği: yeni kasa
# 170 hp ilan, eski kasa 162 hp emsallerle "%15 pahalı" görünmüştü).
EXPLAIN_GAP_PCT = 12.0


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
        yuzde = f"{abs(fark):.1f}".replace(".", ",")
        konum_metni += f" (ilan fiyatı hesaplanan değerin %{yuzde} {'altında' if fark < 0 else 'üstünde'})"

    kalemler = sorted(degerleme.get("kalemler") or [], key=lambda k: k.get("tutar") or 0, reverse=True)
    riskler: List[str] = []
    if degerleme.get("agirHasar"):
        riskler.append("Ağır hasar sınıfında bulgu bildirildi; aracın yapısal durumu mutlaka uzmanca incelenmeli.")
    for k in kalemler[:2]:
        if (k.get("tutar") or 0) > 0:
            riskler.append(f"{_kalem_metni(k)}: değeri yaklaşık {_tl(round(float(k.get('tutar')), -3))} düşürüyor.")
    for f in flags:
        if f.get("kod") in LOW_CONFIDENCE_FLAGS and f.get("mesaj"):
            riskler.append(f["mesaj"] + ".")
    # Karşılaştırma hasarsız emsal orta fiyatıyla yapılır: hasar düşülmüş değere göre fark zaten
    # hasardan gelir (Egea örneği: değişen kapı + tramer, ilan %23 "üstünde" görünmüştü).
    median = reference.get("market_median_price")
    emsal_farki = (price / median - 1) * 100 if median else None
    buyuk_fark = emsal_farki is not None and emsal_farki > EXPLAIN_GAP_PCT
    if buyuk_fark:
        riskler.append(f"İlan fiyatı benzer ilanlardan %{emsal_farki:.0f} yüksek. Fark yeni kasa, motor gücü, donanım "
                       "veya garantiden kaynaklanıyor olabilir; benzer ilanlarla aynı araç olduğu doğrulanmalı."
                       )
    # İlan benzer ilan ortalamasının altındaysa satıcı bir kusuru belirtmemiş olabilir (kullanıcı kararı):
    # ağır hasardan sonra en üste yazılır ki 4 maddelik özet kesilince kaybolmasın.
    from yerimebak_ai_v5.services.negotiation import (
        DUSUK_FIYAT_SERT_YUZDE, _yaklasik, dusuk_fiyat_uyarisi, dusuk_fiyat_yuzdesi)
    # Tek ölçü: hesaplanan değer ve adil aralık (BYD, 07.11.2026).
    deger, alt_sinir = degerleme.get("aiDegeri"), aralik.get("min")
    dusuk_fiyat = dusuk_fiyat_uyarisi(price, deger, alt_sinir)
    if dusuk_fiyat:
        riskler.insert(1 if degerleme.get("agirHasar") else 0, dusuk_fiyat)
    # Kullanıcı kararı (6 Kasım 2026, Seat Ibiza denemesi): ilan piyasanın %10 ve daha fazla altındayken
    # üstte "Alınabilir, avantajlı" yazıp altta dolandırıcılık uyarısı vermek çelişkili. Karar temkinli olur;
    # hesaplanan eğilim ("AL") bilgi olarak kalır.
    yuzde = dusuk_fiyat_yuzdesi(price, deger, alt_sinir)
    if sonuc == "AL" and yuzde is not None and yuzde >= DUSUK_FIYAT_SERT_YUZDE:
        oran = f"%{yuzde:.0f}"
        sonuc, aciklama = LOW_CONFIDENCE_VERDICT, (
            f"İlan fiyatı aracın hesaplanan değerinin {oran} altında. Bu bir fırsat olabilir, ama fiyatın neden bu kadar "
            "düşük olduğu öğrenilmeden ve araç yerinde incelenmeden alım kararı verilmemeli.")
    riskler.append("Boya, değişen ve tramer bilgileri ilan/müşteri beyanına dayanıyor; uzman tarafından doğrulanmadı.")

    gerekceler: List[str] = []
    if aralik.get("max") and price > aralik["max"]:
        gerekceler.append(f"İlan fiyatı adil aralığın üst sınırından {_tl(price - aralik['max'])} yüksek.")
    if reference.get("count") and reference.get("market_median_price"):
        gerekceler.append(f"Benzer {reference['count']} ilanın orta fiyatı (bu araca göre düzeltilmiş) "
                          f"{_tl(reference['market_median_price'])}.")
    for k in kalemler[:2]:
        if (k.get("tutar") or 0) > 0:
            gerekceler.append(f"{_kalem_metni(k)}: yaklaşık {_yaklasik(k.get('tutar'))} değer kaybı.")

    if level == "dusuk":
        # Az/dağınık veride müşteriye somut bilgi: kaç ilan, kaçı aynı yıl, ne kadar belirsizlik.
        count, same = reference.get("count") or 0, reference.get("same_year_count")
        low, high = aralik.get("min"), aralik.get("max")
        belirsizlik = round((high - low) / (high + low) * 100) if low and high else None
        adim = (f"Bu araç için piyasada az sayıda ve birbirinden farklı ilan var ({count} ilan"
                + (f", {same} tanesi aynı model yılı" if same is not None else "") + "). "
                + (f"Fiyatlar bu yüzden yaklaşık ±%{belirsizlik} belirsizlik taşır; " if belirsizlik else "")
                + "satın almadan önce yerinde ekspertiz özellikle önemlidir.")
    elif buyuk_fark:
        adim = (f"Önce satıcıya farkın nedenini sorun (kasa/model yılı, motor gücü, donanım, garanti). "
                f"Açıklanamıyorsa {_tl(recommended)} civarına pazarlık edin; her durumda aracı yerinde inceletin.")
    elif dusuk_fiyat:
        adim = ("Fiyat piyasanın altında. Önce satıcıya fiyatın neden düşük olduğunu sorun; ödeme ya da kapora "
                "göndermeden önce aracı yerinde inceletin.")
    elif karar == "AL":
        adim = "Fiyat uygun görünüyor. Ödeme yapmadan önce aracı yerinde inceletin."
    elif karar == "PAZARLIK YAP":
        adim = f"{_tl(recommended)} civarına inmek için pazarlık edin, ardından aracı yerinde inceletin."
    else:
        adim = f"Bu fiyattan almayın; fiyat {_tl(recommended)} civarına inmezse başka ilanlara bakın."

    if any((k.get("tutar") or 0) > 0 for k in kalemler) and "yerinde inceletin" not in adim:
        adim += " Bildirilen hasarı ve onarım kalitesini aracı yerinde inceleterek doğrulatın."
    piyasa_kaynagi = reference.get("source")
    return {
        "karar": {"sonuc": sonuc, "aciklama": aciklama, "guvenSeviyesi": level,
                  "hesaplananEgilim": karar if sonuc == LOW_CONFIDENCE_VERDICT else None},
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


RISK_TIMEOUT_SECONDS = 90
DISPLAYED_RISK_CONFIDENCE = ("yuksek", "orta")
_RISK_POOL = ThreadPoolExecutor(max_workers=4, thread_name_prefix="model-risk")


def _risk_vehicle(brand, model, year, km, package, fuel, transmission) -> Dict[str, Any]:
    return {"brand": brand, "model": model, "year": year, "km": km, "package": package,
            "engine": package, "fuel": fuel, "transmission": transmission}


def _model_risks_safe(future) -> Dict[str, Any]:
    """Model riski aramasinin sonucu; hata/zaman asiminda rapor yine verilir."""
    try:
        risks = future.result(timeout=RISK_TIMEOUT_SECONDS)
        if isinstance(risks, dict):
            return risks
    except Exception as exc:  # ag, zaman asimi, beklenmeyen hata: rapor engellenmez
        logger.warning("[MODEL RISK] Arastirma tamamlanamadi: %s", str(exc)[:200])
    return {"riskler": [], "bulunamadi": True, "hata": True,
            "scope": {"cached": False, "searches": 0, "cost_usd": 0}}


def _findings(parts: Dict[str, str], tramer_amount: int) -> List[Dict[str, Any]]:
    durum = {"lokal_boyali": "lokal boyalı", "boyali": "boyalı", "degisen": "değişen"}
    out = [{"baslik": f"{PART_LABELS.get(k, k)} ({durum.get(v, v)})"} for k, v in parts.items()]
    if tramer_amount:
        out.append({"baslik": f"{tramer_amount:,} TL tramer kaydı".replace(",", ".")})
    return out


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


def _legacy_prefill_from_link(url: str) -> Dict[str, Any]:
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


SAHIBINDEN_PASTE_MESSAGE = (
    "Sahibinden ilanını linkten okuyamıyoruz. Telefondaysanız ilanın fiyat ve özellikler kısmının ekran "
    "görüntüsünü yükleyin; bilgisayardaysanız ilan metnini kopyalayıp aşağıdaki kutuya yapıştırın."
)


def prefill_from_link(url: str) -> Dict[str, Any]:
    from yerimebak_ai_v5.services import listing_extract

    legacy = _legacy_prefill_from_link(url)
    if "error" in legacy:
        return legacy
    if not legacy.get("listing_id") and legacy.get("source") == "sahibinden":
        # Sahibinden sayfası erişimi engelliyor ve aramada görünmüyor: ücretli arama yapılmaz.
        # Link başlığı da güvenilir değil (satıcı başlığı eski yıl/km/fiyat içerebilir); tahmin yok.
        # Müşteri ilan metnini yapıştırır; link rapora ilan linki olarak girer.
        return {**legacy, "vehicle": {}, "parts": {}, "fields": {}, "verified_count": 0,
                "paste_text": True, "message": SAHIBINDEN_PASTE_MESSAGE}
    extracted = listing_extract.from_link(legacy["url"])
    if extracted is None:
        # Anahtar yokken eski yanıt ve URL kelimesi tahmini korunur; yeşil rozet verilmez.
        legacy["fields"] = {k: listing_extract.field(v, "ilan_sayfasi" if legacy.get("listing_id") else "link_kelimeleri", False)
                            for k, v in legacy["vehicle"].items() if v is not None}
        legacy["fields"].update({"parts." + k: listing_extract.field(v, "ilan_sayfasi", False)
                                 for k, v in legacy["parts"].items()})
        legacy["verified_count"] = 0
        return legacy
    fields = extracted["fields"].copy()
    guesses = _guess_from_slug(legacy["url"]) if legacy.get("listing_id") else legacy["vehicle"]
    for key in ("brand", "model"):
        value = guesses.get(key)
        if key not in fields and value:
            fields[key] = listing_extract.field(value, "link_kelimeleri", False)
    out = listing_extract.response(fields, legacy["url"])
    out["source"] = legacy.get("source")
    return out


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
            # Kazancın iki kaynağı (09.11.2026): araç enflasyonuyla değer artışı + değerinin altında alım.
            "enflasyonKazanciTl": int(round(future - ai_value, -3)),
            "alimKazanciTl": int(round(ai_value - purchase_price, -3)),
            "enflasyonYuzde": round(((1 + monthly) ** months - 1) * 100, 1),
        }

    return {
        "aylikEnflasyonYuzde": float(settings["monthly_pct"]),
        "altiAylikEnflasyonYuzde": round(((1 + monthly) ** 6 - 1) * 100, 1),
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

    package = str(payload.get("package") or "").strip()[:80] or None
    # Model riski aramasi piyasa aramasiyla ayni anda baslar (toplam sure en uzun arama kadar)
    from yerimebak_ai_v5.services import vehicle_risk
    risk_vehicle = _risk_vehicle(brand, model, year, km, package, fuel, transmission)
    risk_future = _RISK_POOL.submit(vehicle_risk.get_model_risks, risk_vehicle)
    kasa = payload.get("kasa") if payload.get("kasa") in ("yeni", "eski") else None
    hp = payload.get("hp") if isinstance(payload.get("hp"), int) and 40 <= payload["hp"] <= 800 else None
    reference = web_market_reference.get_reference({
        "brand": brand, "model": model, "year": year, "km": km, "fuel": fuel,
        "transmission": transmission, "package": package, "listed_price": price, "kasa": kasa, "hp": hp,
    })
    if int((reference or {}).get("count") or 0) < web_market_reference.TARGET_SAMPLES:
        # Admin'in "verisi az olan modeller" listesi (piyasa takibi için)
        from yerimebak_ai_v5.services import manual_market
        manual_market.log_gap(brand, model, year, int((reference or {}).get("count") or 0))
    gecis = (reference or {}).get("gecis") or {}
    if gecis.get("neden") == "secilen_bulunamadi":
        secilen = (gecis.get(gecis.get("secilen")) or {}).get("kasa") or "seçtiğiniz kasa"
        return _error(
            f"Seçtiğiniz kasa ({secilen}) için yeterli benzer ilan bulunamadı; diğer kasanın fiyatıyla "
            "değerlendirme yapmıyoruz çünkü yanıltıcı olur. Kredi düşülmedi.",
            422, "insufficient_market_data",
        )
    if not reference or not reference.get("found"):
        reference = get_market_reference_service().get_reference(
            brand=brand, model=model, year=year, km=km, fuel=fuel, transmission=transmission,
            exclude_id=listing.get("id") if listing else None, listed_price=price,
        )
    if int(reference.get("count") or 0) < 3 or str(reference.get("source", "")).startswith("last_resort"):
        return _error(
            "Bu araç için yeterli benzer ilan bulunamadı. Kredi düşülmedi.",
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
        "arac": {"marka": brand, "model": model, "paket": package, "yil": year, "km": km, "yakit": fuel,
                 "vites": transmission, "ilanFiyati": price, "ilanLinki": payload.get("listing_url") or None,
                 # Ekspertiz talebine on doldurma icin musterinin beyani
                 "beyanEdilenParcalar": parts, "tramerTutari": tramer_amount},
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
                           "duzeltilmisFiyat": s.get("adjusted_price"),
                           "km": s.get("km"), "yil": s.get("year")} for s in (reference.get("samples") or [])[:10]],
            # İlan fiyatları bu aracın yılına/km'sine çevrildi; müşteriye nasıl yapıldığı gösterilir.
            # Admin'in piyasa takibinden kullanılan ilan sayısı (tek tek gösterilmez)
            "takipIlanSayisi": int(reference.get("manual_count") or 0),
            # Kasa geçiş yılı: iki kasanın bu araca göre orta fiyatı ve hangisine göre değerlendiği
            "gecisYili": _transition_view(reference.get("gecis")),
            "duzeltme": ({
                "aracYili": year, "aracKm": km,
                "yillikOran": (reference.get("scope") or {}).get("yearly_rate"),
                "yilAraligi": (reference.get("scope") or {}).get("year_range"),
                "kasa": ((reference.get("scope") or {}).get("generation") or {}).get("kasa"),
                "ayniYilSayisi": reference.get("same_year_count"),
            } if (reference.get("scope") or {}).get("normalized") else None),
            "uyarilar": [_uyari_metni(f, package) for f in flags if f.get("mesaj") and f.get("kod") != "az_emsal"],
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
            "ozet": _beyan_ozeti(degerleme.get("ozet")),
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
    result["bilgiKaynaklari"] = [b for b in summary["bilgiKaynaklari"]
                                 if projection or b.get("alan") != "Gelecek değer"]

    # Akilli alici bolumleri (tek rapor, 1 kredi): pazarlik plani, model riskleri, bakim, sorular
    from yerimebak_ai_v5.services.negotiation import build_plan

    result["pazarlikPlani"] = build_plan(
        price=float(price), fair_min=(degerleme.get("adilFiyatAraligi") or {}).get("min"),
        fair_max=(degerleme.get("adilFiyatAraligi") or {}).get("max"), recommended=recommended,
        reference=reference, kalemler=degerleme.get("kalemler") or [],
        confidence_level=summary["karar"]["guvenSeviyesi"], vehicle_title=f"{year} {brand} {model}",
        vehicle_year=year, vehicle_km=km, value=ai_value,
    )
    # Tavsiye alım fiyatı = pazarlık hedefi. Eskiden ilan piyasanın altındayken tavsiye ilan fiyatının
    # üstünde kalıyordu (Cupra: ilan 2.265.000, tavsiye 2.275.000); özet metinleri de aynı rakamla yeniden yazılır.
    hedef = result["pazarlikPlani"].get("hedefFiyat")
    if hedef and float(hedef) < recommended:
        recommended = float(hedef)
        result["degerleme"]["tavsiyeFiyat"] = int(hedef)
        summary = decision_summary(
            price=float(price), degerleme=degerleme, recommended=recommended, verdict_key=verdict_key,
            karar=karar, karar_aciklama=karar_aciklama, confidence=int(confidence), flags=flags,
            reference=reference, from_saved_listing=bool(listing),
        )
        result["karar"].update(summary["karar"])
        result["ozet"] = summary["ozet"]
    # Özet ile pazarlık planı aynı gerekçeleri gösterir. İlan piyasanın altındayken "benzer ilanların
    # ortası daha yüksek" bilgisi satıcının işine yarar; plan bunu gerekçe saymaz (Cupra Formentor denemesi).
    result["ozet"]["pazarlikGerekceleri"] = result["pazarlikPlani"]["gerekceler"][:3]
    risks = _model_risks_safe(risk_future)
    result["kullaniciSikayetleri"] = risks.get("kullaniciSikayetleri") or []
    risk_cost = float((risks.get("scope") or {}).get("cost_usd") or 0)
    # Musteriye yalniz kaynagi dogrulanmis (yuksek/orta) maddeler gider; forum vb. dusuk guven atilir
    risks = {**risks, "riskler": [r for r in (risks.get("riskler") or []) if r.get("guven") in DISPLAYED_RISK_CONFIDENCE]}
    result["modelRiskleri"] = {
        "gorunumSurumu": 2,
        "riskler": risks.get("riskler") or [],
        "bulunamadi": not risks["riskler"],
        "mesaj": ("Bu raporda bilinen teknik sorun araştırması tamamlanamadı; aşağıdaki kullanıcı şikâyetlerine "
                  "ve bakım kontrollerine bakın. Bakım ve sorular genel kurallarla hazırlandı."
                  if risks.get("hata") else
                  # Şikâyet varken "bilinen sorun bulunamadı" demek çelişkili görünüyordu (Cupra: DSG şikâyeti yüksek).
                  "Üretici veya servis kaynağıyla doğrulanmış teknik sorun bulunamadı; kullanıcıların bildirdiği "
                  "şikâyetler aşağıda ayrıca listelendi."
                  if not risks.get("riskler") and result["kullaniciSikayetleri"] else
                  "Bu model/motor için kaynağı doğrulanmış bilinen sorun bulunamadı."
                  if not risks.get("riskler") else None),
    }
    result["bakim"] = vehicle_risk.upcoming_maintenance(risk_vehicle, risks)
    if parts:
        result["bakim"].insert(0, {
            "baslik": "Değişen / boyalı parçaların kontrolü",
            "aciklama": "Beyan edilen parçalarda onarımın kalitesini ve parçanın orijinal mi muadil mi olduğunu öğrenin.",
            "kontrol": "Kapı ve kaput aralıklarının eşit olduğuna, fitillerin oturduğuna, renk tonu farkına; değişen kapılarda "
                       "cam, kilit ve ayna elektriklerinin çalıştığına bakın.",
        })
    result["saticiSorulari"] = vehicle_risk.seller_questions(risk_vehicle, risks, _findings(parts, tramer_amount))
    web_cost = float((reference.get("scope") or {}).get("cost_usd") or 0)

    from yerimebak_ai_v5.services.inspection_findings import enrich_report
    enrich_report(result, payload)

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
                        "web_maliyet_usd": web_cost, "risk_maliyet_usd": risk_cost,
                        "web_site_stats": (reference.get("scope") or {}).get("site_stats") or {},
                        "toplam_maliyet_usd": round(web_cost + risk_cost, 6)},
    )
    if not deduction.get("success"):
        # Kilitli düşüm son karardır; eş zamanlı istekte kredi kalmadıysa sonuç verilmez
        status, code, message = credit_refusal(deduction.get("code"), deduction.get("credits"))
        return _error(message, status, code)
    if deduction.get('report'):
        return deduction['report']
    result["kredi"] = {"dusulen": ANALYSIS_COST, "kalan": deduction.get("credits_after")}
    result["success"] = True
    return result
