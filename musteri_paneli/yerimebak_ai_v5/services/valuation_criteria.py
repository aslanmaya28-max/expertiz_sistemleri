# -*- coding: utf-8 -*-
"""
Degerleme kriterleri tablosu: model, paket, km, hasar kaydi, degisen, boya, hasar.

Her kriter icin aracin degeri ve degere etkisi (yuzde / TL) tek yerde gosterilir;
admin onay ekrani ve musteri raporu bu tabloyu okur. Hesap yapmaz, degerleme
motorunun ciktisini (ekspertizDegerleme) ve emsal referansini ozetler.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

_BOYA = {"Boyalı", "Lokal Boyalı"}
_DEGISEN = {"Değişen"}
_HASAR_KATEGORI = {"yapisal", "hasar_kaydi", "dis", "ic", "mekanik"}


def _fmt_int(value: Any) -> str:
    try:
        return f"{int(round(float(value))):,}".replace(",", ".")
    except (TypeError, ValueError):
        return "-"


def _sum(items: List[Dict[str, Any]]) -> Dict[str, float]:
    return {
        "yuzde": round(sum(float(i.get("yuzde") or 0) for i in items), 2),
        "tutar": round(sum(float(i.get("tutar") or 0) for i in items)),
    }


def build_criteria(
    degerleme: Dict[str, Any],
    market_reference: Dict[str, Any],
    vehicle: Dict[str, Any],
    tramer_tl: Optional[float] = None,
) -> List[Dict[str, Any]]:
    kalemler = list(degerleme.get("kalemler") or [])
    kaporta = [k for k in kalemler if k.get("kategori") == "kaporta"]
    boya = [k for k in kaporta if k.get("durum") in _BOYA]
    degisen = [k for k in kaporta if k.get("durum") in _DEGISEN]
    hasar = [k for k in kaporta if k.get("durum") not in _BOYA | _DEGISEN] + [
        k for k in kalemler if k.get("kategori") in _HASAR_KATEGORI
    ]
    tramer = [k for k in kalemler if k.get("kategori") == "tramer"]
    km_adj = [a for a in degerleme.get("piyasaDuzeltmeleri") or [] if a.get("baslik") == "Kilometre farkı"]
    yil_adj = [a for a in degerleme.get("piyasaDuzeltmeleri") or [] if a.get("baslik") == "Model yılı farkı"]
    ref = market_reference or {}
    found = bool(ref.get("found")) and ref.get("source") == "listings"

    model_text = " ".join(str(v) for v in (vehicle.get("brand"), vehicle.get("model"), vehicle.get("year")) if v)
    paket = vehicle.get("paket") or ref.get("package")
    if not paket:
        paket_durum = "Paket bilinmiyor; emsaller modelin tüm paketlerinden seçildi"
    elif ref.get("package_match"):
        paket_durum = f"Emsaller aynı paketten seçildi ({paket})"
    else:
        paket_durum = f"Aynı paketten yeterli emsal yok; modelin diğer paketleri de kullanıldı ({paket})"

    km = vehicle.get("km")
    km_ref = ref.get("reference_median_km")
    km_text = f"{_fmt_int(km)} km" if km else "Bilinmiyor"
    if km and km_ref:
        km_text += f" (emsal medyanı {_fmt_int(km_ref)} km)"

    tramer_value = float(tramer_tl or 0)
    criteria = [
        {
            "kriter": "Model",
            "deger": model_text or "Bilinmiyor",
            "etki": _sum(yil_adj),
            "aciklama": (
                f"{int(ref.get('count') or 0)} emsal ilan (yıl ±{(ref.get('scope') or {}).get('year_window') or '-'}); "
                f"{int(ref.get('clean_count') or 0)} tanesi hasarsız"
                if found else (
                    "Yeterli emsal bulunamadı; piyasa değeri yapay zekâ tahmini"
                    if ref.get("source") == "ai_estimate" else "Yeterli emsal bulunamadı"
                )
            ),
        },
        {
            "kriter": "Paket",
            "deger": paket or "Bilinmiyor",
            "etki": None,
            "eslesti": bool(ref.get("package_match")),
            "aciklama": paket_durum,
        },
        {
            "kriter": "Kilometre",
            "deger": km_text,
            "etki": _sum(km_adj),
            "aciklama": km_adj[0]["aciklama"] if km_adj else "Emsallerle km farkı önemsiz",
        },
        {
            "kriter": "Hasar kaydı (tramer)",
            "deger": f"{_fmt_int(tramer_value)} TL" if tramer_value > 0 else "Yok",
            "etki": _sum(tramer),
            "aciklama": "Tramerli emsaller temiz emsal sayılmaz",
        },
        {
            "kriter": "Değişen",
            "deger": f"{len(degisen)} parça" if degisen else "Yok",
            "etki": _sum(degisen),
            "aciklama": ", ".join(k.get("baslik") or "" for k in degisen) or "Değişen parça yok",
        },
        {
            "kriter": "Boya",
            "deger": f"{len(boya)} parça" if boya else "Yok",
            "etki": _sum(boya),
            "aciklama": ", ".join(f"{k.get('baslik')} ({k.get('durum')})" for k in boya) or "Boyalı parça yok",
        },
        {
            "kriter": "Hasar",
            "deger": f"{len(hasar)} bulgu" if hasar else "Yok",
            "etki": _sum(hasar),
            "aciklama": ", ".join(k.get("baslik") or "" for k in hasar[:6]) or "Hasar bulgusu yok",
        },
    ]
    return criteria
