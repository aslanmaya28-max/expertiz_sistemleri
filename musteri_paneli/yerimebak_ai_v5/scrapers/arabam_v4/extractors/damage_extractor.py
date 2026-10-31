# -*- coding: utf-8 -*-
"""
Hasar kaydi (tramer) ve agir hasar bilgisi.

arabam.com ilan sayfasinda bu bilgi saticinin doldurdugu "Agir Hasar Kayitli"
alaninda ve/veya aciklamada ("Tramer: 12.500 TL", "tramer kaydi yok") yer alir.
Sayfa metninden okunur; bulunamazsa alanlar None kalir (temiz/hasarsiz kabul edilmez).
"""
import re
from typing import Any, Dict, Optional

from playwright.async_api import Page

_I = "[İIıi]"
_HEAVY = re.compile(
    rf"A[ğg]{_I}r\s*Hasar\s*(?:Kay{_I}tl{_I}|Kayd{_I}|l{_I})?\s*[:\n]\s*(Evet|Hay{_I}r|Var|Yok)", re.IGNORECASE
)
_AMOUNT = re.compile(
    rf"(?:Tramer|Hasar\s*Kayd{_I})(?:\s*\(?Tramer\)?)?(?:\s*(?:Tutar{_I}|Bedeli|Kayd{_I}))?\s*[:\n\-=]?\s*"
    r"(\d{1,3}(?:[.\s]\d{3})+|\d{3,7})(?:[,.]\d{1,2})?\s*(?:TL|₺)",
    re.IGNORECASE,
)
_AMOUNT_AFTER = re.compile(r"(\d{1,3}(?:[.\s]\d{3})+|\d{3,7})\s*(?:TL|₺)\s*(?:tramer|hasar\s*kayd)", re.IGNORECASE)
_NO_HEAVY = re.compile(rf"A[ğg]{_I}r\s*hasar\s*(?:kayd{_I}\s*)?(?:yok|bulunmamaktad{_I}r|yoktur)", re.IGNORECASE)
# "Ağır hasar kaydı yok" tramer kaydının olmadığı anlamına gelmez; bu yüzden "ağır" ile başlayanlar hariç.
_NONE = re.compile(
    rf"tramer\s*(?:kayd{_I}\s*|tutar{_I}\s*)?[:\n\-=]?\s*(?:yok|bulunmamaktad{_I}r|yoktur|0\s*(?:TL|₺))|tramersiz|"
    rf"(?<!A[ğg]{_I}r\s)hasar\s*kayd{_I}\s*[:\n\-=]?\s*(?:yok|bulunmamaktad{_I}r|yoktur)",
    re.IGNORECASE,
)


def _amount(text: str) -> int:
    return int(re.sub(r"[^\d]", "", text))


def parse_damage_record(text: str) -> Dict[str, Any]:
    """Sayfa metninden hasar kaydi: tramer_tl, tramer_yok, agir_hasar, kaynak_metin."""
    text = text or ""
    out: Dict[str, Any] = {"tramer_tl": None, "tramer_yok": None, "agir_hasar": None, "kaynak_metin": None}

    heavy = _HEAVY.search(text)
    if heavy:
        out["agir_hasar"] = heavy.group(1).strip().lower() in ("evet", "var")
        out["kaynak_metin"] = heavy.group(0).strip()
    elif _NO_HEAVY.search(text):
        out["agir_hasar"] = False

    amount = _AMOUNT.search(text) or _AMOUNT_AFTER.search(text)
    if amount:
        value = _amount(amount.group(1))
        if value > 0:
            out["tramer_tl"] = value
            out["tramer_yok"] = False
            out["kaynak_metin"] = amount.group(0).strip()
    if out["tramer_tl"] is None and _NONE.search(text):
        out["tramer_yok"] = True
        out["kaynak_metin"] = out["kaynak_metin"] or _NONE.search(text).group(0).strip()
    return out


class DamageExtractor:
    def __init__(self, page: Page):
        self.page = page

    async def extract(self) -> Dict[str, Any]:
        try:
            text = await self.page.inner_text("body")
        except Exception:
            text = ""
        return parse_damage_record(text)


def damage_summary(record: Optional[Dict[str, Any]]) -> Optional[str]:
    """Emsal siniflandirmasi icin kisa metin ("Tramerli: 12500 TL", "Ağır hasar kayıtlı")."""
    if not record:
        return None
    parts = []
    if record.get("agir_hasar"):
        parts.append("Ağır hasar kayıtlı")
    if record.get("tramer_tl"):
        parts.append(f"Tramerli: {record['tramer_tl']} TL")
    return ", ".join(parts) or None
