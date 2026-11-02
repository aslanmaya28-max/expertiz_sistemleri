# -*- coding: utf-8 -*-
"""
Kanita dayali pazarlik plani (Akilli Alici Raporu).

Rakamlar yapay zekadan degil, degerleme motorunun sonucundan kurallarla hesaplanir; satici
mesaji kalip metindir. Boylece her rapor tutarli, tekrar uretilebilir ve ek maliyetsizdir.

Girdi: ilan fiyati, adil fiyat araligi, tavsiye alim fiyati, piyasa referansi, bulgu kalemleri,
guven seviyesi. Cikti: acilis teklifi, hedef, ust sinir, adimlar, gerekceler, satici mesaji.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from yerimebak_ai_v5.core.ai.inspection_valuation import _round_price

# Acilis teklifi adil araligin altina en fazla bu oranda iner (saticiyi kirmamak icin)
OPENING_FLOOR_RATIO = 0.95
# Ilan fiyatina gore acilis indirimi ust siniri
OPENING_MAX_DISCOUNT = 0.10


def _tl(value: Optional[float]) -> str:
    if value is None:
        return "-"
    return f"{int(round(value)):,} TL".replace(",", ".")


def _evidence(reference: Dict[str, Any], price: float, year: Optional[int], limit: int = 3) -> List[Dict[str, Any]]:
    """Pazarlikta saticiya gosterilecek en ucuz benzer ilanlar (yalnizca kaynak linki olanlar).

    Saticiya ancak ilanindan ucuz ve en az ayni model yilindaki ilan gosterilir: daha eski yilin
    dogal olarak dusuk fiyati 'bakin daha ucuzu var' kaniti olmaz, alicinin elini zayiflatir."""
    samples = [s for s in reference.get("samples") or []
               if s.get("price") and str(s.get("url") or "").startswith(("http://", "https://"))
               and s["price"] < price and not (year and s.get("year") and s["year"] < year)]
    samples.sort(key=lambda s: s["price"])
    return [{"site": s.get("site"), "url": s.get("url"), "fiyat": s.get("price"),
             "km": s.get("km"), "yil": s.get("year")} for s in samples[:limit]]


def build_plan(
    *, price: float, fair_min: Optional[float], fair_max: Optional[float], recommended: float,
    reference: Dict[str, Any], kalemler: List[Dict[str, Any]], confidence_level: str,
    vehicle_title: str,
) -> Dict[str, Any]:
    """Pazarlik plani. Fiyat zaten adil araligin altindaysa pazarlik payi kucuk tutulur."""
    price = float(price)
    lo = float(fair_min or recommended)
    hi = float(fair_max or recommended)
    median = reference.get("market_median_price")
    median = float(median) if median and float(median) > 0 else None
    year = reference.get("reference_median_year") or None
    car_km = reference.get("reference_median_km") or None
    # Ilan, hesaplanan degerin ya da benzer ilanlarin ortasinin altindaysa pazarlik payi kucuktur:
    # hedef yine de ilan fiyatinin altinda kalir (hedef = ilan fiyati, pazarlik degildir).
    piyasa_alti = price <= recommended or (median is not None and price <= median)

    if price <= lo:
        durum = "fiyat_uygun"
        hedef = _round_price(price * 0.985)
        acilis = _round_price(price * 0.97)
    elif piyasa_alti:
        durum = "kucuk_pay"
        hedef = _round_price(price * 0.975)
        acilis = _round_price(price * 0.95)
    else:
        durum = "pazarlik_payi_var" if price > hi else "kucuk_pay"
        hedef = _round_price(min(recommended, price))
        acilis = _round_price(max(lo * OPENING_FLOOR_RATIO,
                                  min(recommended * 0.97, price * (1 - OPENING_MAX_DISCOUNT))))
    ust = min(price, hi, median if median is not None else float("inf"))
    hedef = min(hedef, ust)
    if hedef >= price:
        hedef = min(ust, _round_price(price * 0.975))
    acilis = min(acilis, hedef)
    if acilis >= hedef and hedef > 0:
        acilis = min(acilis, _round_price(hedef * 0.975))
    potansiyel = max(0, int(round(price - hedef)))

    gerekceler: List[str] = []
    # Benzer ilanlarin ortasi ilandan yuksekse bu bilgi saticinin isine yarar; saticiya gerekce yapilmaz.
    median_limited = median is not None and median == ust and median < price
    if median_limited:
        gerekceler.append(f"Üst sınır {_tl(ust)}: benzer ilanların orta fiyatı (bu araca göre düzeltilmiş) bu tutardır.")
    if price > hi:
        gerekceler.append(f"İlan fiyatı ({_tl(price)}) adil aralığın üst sınırından ({_tl(hi)}) {_tl(price - hi)} yüksek.")
    if reference.get("count") and median is not None and median < price:
        gerekceler.append(f"Benzer {reference['count']} ilanın orta fiyatı (bu araca göre düzeltilmiş) "
                          f"{_tl(median)}.")
    ayni_yil = [s for s in reference.get("samples") or []
                if s.get("price") and (not year or not s.get("year") or s["year"] >= year)]
    ucuzlar = sorted(s["price"] for s in ayni_yil if s["price"] < price)
    if ucuzlar and year:
        gerekceler.append(f"Aynı yıl ya da daha yeni {len(ucuzlar)} benzer ilan {_tl(ucuzlar[0])}'den başlıyor.")
    km_list = [s["km"] for s in ayni_yil if s.get("km")]
    if car_km and len(km_list) >= 2:
        ort_km = sum(km_list) / len(km_list)
        if car_km > ort_km * 1.15:
            gerekceler.append(f"Aracın kilometresi ({int(car_km):,} km) benzer ilanların ortalamasının "
                              f"({int(round(ort_km, -3)):,} km) üzerinde.".replace(",", "."))
    for k in sorted(kalemler, key=lambda k: k.get("tutar") or 0, reverse=True)[:3]:
        if (k.get("tutar") or 0) > 0:
            kalem_durumu = str(k.get('durum') or '')
            kalem = (f"{k.get('baslik')} {kalem_durumu}" if any(c.isdigit() for c in kalem_durumu)
                     else f"{k.get('baslik')} ({kalem_durumu.replace('I', 'ı').replace('İ', 'i').lower()})")
            gerekceler.append(f"{kalem} değeri yaklaşık {_tl(k.get('tutar'))} düşürüyor.")

    kanitlar = _evidence(reference, price, year)

    if durum == "fiyat_uygun":
        adimlar = [
            "Fiyat zaten adil aralığın altında; pazarlık payı sınırlı.",
            f"Küçük bir indirim isteyin: {_tl(acilis)} ile açın, {_tl(hedef)} civarında anlaşın.",
            "Hızlı davranın ama ödeme yapmadan önce aracı yerinde inceletin.",
        ]
    elif piyasa_alti:
        adimlar = [
            "İlan fiyatı benzer ilanların ortasının altında; pazarlık payı sınırlı. Fazla zorlamak aracı kaçırmanıza neden olabilir.",
            f"{_tl(acilis)} ile açın, {_tl(hedef)} civarında anlaşmayı hedefleyin.",
            f"İlan fiyatı olan {_tl(ust)} üst sınırınız; bunun üstüne çıkmayın.",
            "Son fiyatı ekspertiz sonucuna bağlayın: incelemede beyan dışı hasar çıkarsa fiyat yeniden konuşulur.",
        ]
    else:
        adimlar = [
            f"{_tl(acilis)} teklifiyle açın ve gerekçeleri gösterin.",
            f"Karşı teklif gelirse {_tl(hedef)} hedefine doğru ilerleyin.",
            f"{_tl(ust)} üst sınırınız; bunun üstüne çıkmayın.",
            "Son fiyatı ekspertiz sonucuna bağlayın: incelemede beyan dışı hasar çıkarsa fiyat yeniden konuşulur.",
        ]

    if median_limited:
        adimlar.append(f"Üst sınırı benzer ilanların orta fiyatı olan {_tl(ust)} belirliyor.")
    if gerekceler:
        mesaj = (
            f"Merhaba, {vehicle_title} ilanınızla ilgileniyorum. {' '.join(gerekceler[:2])} "
            f"Bu nedenle {_tl(acilis)} teklif etmek istiyorum. Aracı satın almadan önce bağımsız bir "
            f"ekspertizde inceletmek istiyorum; uygun olursa randevu ayarlayabiliriz. Teşekkürler."
        )
    else:
        # Saticiya gosterilecek gerekce yoksa uydurma gerekce yazilmaz; kibar bir teklif yeterli.
        mesaj = (
            f"Merhaba, {vehicle_title} ilanınızla ciddi olarak ilgileniyorum. Aracı satın almadan önce bağımsız bir "
            f"ekspertizde inceletmek istiyorum. Ekspertiz sonucu beyanla uyumlu çıkarsa {_tl(acilis)} teklif "
            f"etmek istiyorum; uygun olursa randevu ayarlayabiliriz. Teşekkürler."
        )

    uyari = None
    if confidence_level == "dusuk":
        uyari = "Piyasa verisi sınırlı: rakamları yön gösterici kullanın, kesin fiyat olarak sunmayın."
    ref_median = reference.get("market_median_price")
    if ref_median and price > ref_median * 1.12:
        not_ = ("İlan fiyatı benzer ilanların belirgin şekilde üstünde. Fark yeni kasa, motor gücü, donanım veya "
                "garantiden kaynaklanıyor olabilir; teklif vermeden önce satıcıdan nedenini isteyin.")
        uyari = f"{uyari} {not_}" if uyari else not_

    return {
        "durum": durum,
        "acilisTeklifi": acilis,
        "hedefFiyat": hedef,
        "ustSinir": ust,
        "potansiyelKazanc": potansiyel,
        "adimlar": adimlar,
        "gerekceler": gerekceler[:4],
        "kanitIlanlar": kanitlar,
        "saticiMesaji": mesaj,
        "uyari": uyari,
    }
