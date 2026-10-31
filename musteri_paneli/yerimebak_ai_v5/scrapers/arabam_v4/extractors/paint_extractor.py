# -*- coding: utf-8 -*-
"""
Arabam v4.0 - Paint Extractor
Boya/değişen bilgisi çıkarıcı - EN KRİTİK EXTRACTOR

Arabam'da fiyat belirleme için hayati önem taşıyor.
"""

import re
from typing import Any, Dict, Optional

from playwright.async_api import Page
from ..models.paint_info import PaintInfo
from ..models.enums import PaintStatus
from .base_extractor import BaseExtractor

# arabam.com ilan sayfasindaki "Boya, Değişen ve Tramer" bolumu, metin olarak:
#   Boya, Değişen ve Tramer
#   Orijinal / Boyalı / Lokal boyalı / Değişmiş / Belirtilmemiş   <- sema lejanti (parcasiz)
#   Lokal boyalı
#   Sol Ön Kapı
#   Değişmiş
#   Ön Tampon
#   Tramer tutarı ...                                             <- bolum sonu
# Durum basligi, altindaki parcalarin durumudur. Ayni satirda "Parça<TAB>Durum"
# ya da "Durum: Parça, Parça" bicimi de okunur.

# Cikti parca adlari degerleme motorundaki adlarla (inspection_valuation.PART_LABELS) aynidir.
_PART_ALIASES = {
    "Ön Tampon": ["ön tampon"],
    "Arka Tampon": ["arka tampon"],
    "Motor Kaputu": ["motor kaputu", "motor kaput", "ön kaput", "kaput"],
    "Bagaj Kapağı": ["bagaj kapağı", "bagaj kapagi", "arka kaput", "bagaj"],
    "Tavan": ["tavan"],
    "Sol Ön Çamurluk": ["sol ön çamurluk"],
    "Sağ Ön Çamurluk": ["sağ ön çamurluk"],
    "Sol Arka Çamurluk": ["sol arka çamurluk"],
    "Sağ Arka Çamurluk": ["sağ arka çamurluk"],
    "Sol Ön Kapı": ["sol ön kapı"],
    "Sağ Ön Kapı": ["sağ ön kapı"],
    "Sol Arka Kapı": ["sol arka kapı"],
    "Sağ Arka Kapı": ["sağ arka kapı"],
}
_PART_BY_ALIAS = {alias: name for name, aliases in _PART_ALIASES.items() for alias in aliases}

_STATUSES = {
    "orijinal": "original", "orjinal": "original", "boyasız": "original",
    "boyalı": "painted",
    "lokal boyalı": "local", "lokal boya": "local",
    "değişmiş": "changed", "değişen": "changed",
    "belirtilmemiş": "unknown",
}
_SECTION_START = re.compile(r"^boya\s*[,/-]?\s*değişen(?:\s+ve\s+(?:tramer|ekspertiz)(?:\s+bilgisi)?)?$")
_SECTION_END = ("tramer tutarı", "tramer kaydı", "ağır hasar")


def tr_lower(text: str) -> str:
    """Turkce kucuk harf (İ->i, I->ı)."""
    return (text or "").replace("İ", "i").replace("I", "ı").lower()


def _clean(line: str) -> str:
    line = tr_lower(line).strip().strip(":-•*").strip()
    line = re.sub(r"\s*\(\d+\)$", "", line)  # "Boyalı (2)"
    line = re.sub(r"\s+parça(?:lar)?$", "", line)  # "Boyalı parçalar"
    return re.sub(r"\s+", " ", line)


def _part(text: str) -> Optional[str]:
    text = _clean(text)
    return _PART_BY_ALIAS.get(text)


def _status(text: str) -> Optional[str]:
    return _STATUSES.get(_clean(text))


def parse_paint_section(text: str) -> Dict[str, Any]:
    """Sayfa metninden parca parca boya/degisen beyanini okur."""
    out: Dict[str, Any] = {
        "painted_parts": [], "local_paint_parts": [], "changed_parts": [],
        "original_parts": [], "unknown_parts": [], "is_original": False,
        "section_found": False, "details": [],
    }
    lines = [ln.strip() for ln in (text or "").split("\n")]
    start = next((i for i, ln in enumerate(lines) if _SECTION_START.match(_clean(ln))), None)
    if start is None:
        return out
    out["section_found"] = True

    found: Dict[str, str] = {}

    def put(part: Optional[str], status: Optional[str]) -> None:
        if part and status:
            found[part] = status

    current = None
    for raw in lines[start + 1:start + 120]:
        if not raw or raw == "-":
            continue
        low = _clean(raw)
        if low.startswith(_SECTION_END) or "arabam.com" in low:
            break
        # "Sol Ön Kapı<TAB>Boyalı" (tablo satiri)
        cells = [c for c in re.split(r"\t+|\s{2,}", raw) if c.strip()]
        if len(cells) == 2 and _part(cells[0]) and _status(cells[1]):
            put(_part(cells[0]), _status(cells[1]))
            continue
        # "Boyalı: Motor Kaputu, Tavan"
        if ":" in raw:
            head, _, rest = raw.partition(":")
            if _status(head) and rest.strip():
                for item in re.split(r"[,;/]", rest):
                    put(_part(item), _status(head))
                current = _status(head)
                continue
        status = _status(raw)
        if status:
            current = status
            continue
        put(_part(raw), current)

    order = list(_PART_ALIASES)
    groups = {"painted": [], "local": [], "changed": [], "original": [], "unknown": []}
    for part in sorted(found, key=order.index):
        groups[found[part]].append(part)
    # Lokal boyali parca boyali sayisina da girer (eski bicimle uyumlu)
    out["local_paint_parts"] = groups["local"]
    out["painted_parts"] = groups["painted"] + groups["local"]
    out["changed_parts"] = groups["changed"]
    out["original_parts"] = groups["original"]
    out["unknown_parts"] = groups["unknown"]
    # Orijinal: yalnizca satici parcalari orijinal isaretlediyse ve hicbiri boyali/degisen/belirtilmemis degilse
    out["is_original"] = bool(groups["original"]) and not (
        groups["painted"] or groups["local"] or groups["changed"] or groups["unknown"]
    )
    for label, key in (("Boyalı", "painted"), ("Lokal boyalı", "local"), ("Değişen", "changed"),
                       ("Orijinal", "original"), ("Belirtilmemiş", "unknown")):
        if groups[key]:
            out["details"].append(f"{label}: {', '.join(groups[key])}")
    return out


class PaintExtractor(BaseExtractor[PaintInfo]):
    """
    Boya/değişen bilgisi çıkarıcı
    
    Bu extractor Arabam.com için en kritik component'tir.
    Boya ve değişen parça bilgisi, araç fiyatını belirlemede
    en önemli faktörlerden biridir.
    
    Turkish Market Importance:
    - Orijinal/Boyasız araçlar %15-25 daha değerli
    - Değişen parça fiyatı %10-20 düşürebilir
    - Lokal boyalar daha az etkiler (%3-5)
    """
    
    def __init__(self, page: Page):
        """
        Initialize paint extractor
        
        Args:
            page: Playwright page instance
        """
        super().__init__(page)
    
    async def extract(self) -> PaintInfo:
        """
        Boya/değişen bilgisini sayfa metnindeki "Boya, Değişen ve Tramer"
        bölümünden okur (bkz. parse_paint_section). Bölüm yoksa durum
        "Bilinmiyor" kalır; araç orijinal kabul edilmez.
        """
        try:
            text = await self.page.inner_text("body")
        except Exception as e:
            self._extraction_log.append({'method': 'paint_section', 'success': False, 'error': str(e)[:100]})
            text = ""
        parsed = parse_paint_section(text)

        paint_info = PaintInfo()
        paint_info.painted_parts = parsed['painted_parts']
        paint_info.local_paint_parts = parsed['local_paint_parts']
        paint_info.changed_parts = parsed['changed_parts']
        paint_info.has_paint = bool(parsed['painted_parts'])
        paint_info.has_changed = bool(parsed['changed_parts'])
        paint_info.is_original = parsed['is_original']
        paint_info.details = parsed['details']
        paint_info.paint_count = len(paint_info.painted_parts)
        paint_info.local_paint_count = len(paint_info.local_paint_parts)
        paint_info.changed_count = len(paint_info.changed_parts)
        paint_info.status = self._determine_status(paint_info)
        paint_info.confidence_score = self._calculate_confidence(paint_info)
        return paint_info

    def _determine_status(self, paint_info: PaintInfo) -> PaintStatus:
        """
        Durum belirle
        
        Args:
            paint_info: PaintInfo modeli
            
        Returns:
            PaintStatus: Boya durumu
        """
        if paint_info.is_original:
            return PaintStatus.ORIGINAL
        elif paint_info.has_changed and paint_info.has_paint:
            return PaintStatus.MIXED
        elif paint_info.has_changed:
            return PaintStatus.CHANGED
        elif paint_info.has_paint:
            return PaintStatus.PAINTED
        else:
            return PaintStatus.UNKNOWN
    
    def _calculate_confidence(self, paint_info: PaintInfo) -> float:
        """
        Kalite skoru hesapla (0-1)
        
        Args:
            paint_info: PaintInfo modeli
            
        Returns:
            float: Kalite skoru
        """
        score = 0.5  # Başlangıç
        
        # Bilgi varsa artır
        if paint_info.status != PaintStatus.UNKNOWN:
            score += 0.2
        
        # Parça detayları varsa artır
        if paint_info.painted_parts or paint_info.changed_parts:
            score += 0.2
        
        # Detaylı notlar varsa artır
        if paint_info.details:
            score += 0.1
        
        return min(score, 1.0)
