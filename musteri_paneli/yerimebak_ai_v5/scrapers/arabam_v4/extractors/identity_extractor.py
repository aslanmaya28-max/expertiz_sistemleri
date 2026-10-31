# -*- coding: utf-8 -*-
"""
Ilan kimligi: arabam.com detay sayfasindaki "Marka / Seri / Model / Yil" satirlari.

arabam.com'da "Seri" aracin modelidir (Clio), "Model" ise paket/versiyondur
(1.0 TCe Touch). Degerlemede ayni paketten emsal secmek icin kullanilir.
"""
import re
from typing import Any, Dict, Optional

_LABELS = {
    "brand": r"Marka",
    "series": r"Seri",
    "model": r"Model",
    "year": r"Y[ıi]l",
    "km": r"Kilometre|KM",
}


def _int(value: Any) -> Optional[int]:
    digits = re.sub(r"[^\d]", "", str(value or ""))
    return int(digits) if digits else None


def parse_identity(text: str) -> Dict[str, Any]:
    """Etiketin hemen ardindan (ayni satirda ':' ile ya da alt satirda) gelen degeri okur."""
    out: Dict[str, Any] = {}
    for key, label in _LABELS.items():
        match = re.search(rf"(?:^|\n)[ \t]*(?:{label})[ \t]*(?::[ \t]*|\n[ \t]*)([^\n]+)", text or "")
        if match:
            out[key] = match.group(1).strip()
    for key in ("year", "km"):
        if key in out:
            out[key] = _int(out[key])
    if out.get("year") and not (1950 <= out["year"] <= 2100):
        out.pop("year")
    return out


def package_from_title(title: str, brand: str, series: str) -> Optional[str]:
    """Baslik "Renault Clio 1.0 TCe Touch" ise paket "1.0 TCe Touch" (sayfada Model satiri yoksa)."""
    rest = title or ""
    for word in (brand, series):
        if word:
            rest = re.sub(rf"^\s*{re.escape(word)}\b", "", rest, flags=re.IGNORECASE).strip()
    rest = re.split(r"\s[-|–]\s", rest)[0].strip()
    return rest or None
