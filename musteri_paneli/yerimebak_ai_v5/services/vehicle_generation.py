"""Aracın kasa (nesil) bilgisi: emsal havuzunu aynı kasaya sınırlamak için.

Aynı kasa + motor + şanzımanlı ilanlar yalnız yaş ve km farkıyla düzeltilerek karşılaştırılabilir
(kullanıcı önerisi, 02.11.2026). Farklı kasa (ör. 2015-2021 TL Tucson) havuza girmez.

Modelin **bütün kasa listesi** sorulur (kullanıcının örneği: "4. Nesil (NX4): 2021 – günümüz,
2024 makyaj") ve kasa aracın yılına göre burada seçilir. "Bu araç hangi kasa" sorusu ölçümde
tutarsızdı: geçiş yılı (Tucson 2021) bir denemede NX4, diğerinde TL çıktı. Geçiş yılında yeni
kasa seçilir. Liste Perplexity Sonar ile kaynaklı bulunur, model başına 1 yıl saklanır;
bulunamazsa çağıran mevcut ±1/±2 yıl kuralına döner.
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
import re
from datetime import datetime
from typing import Any, Dict, List

import httpx

from yerimebak_ai_v5.services import web_market_reference as wmr

logger = logging.getLogger(__name__)

MAX_SPAN_YEARS = 15
CACHE_HOURS = 24 * 365

_PROMPT = """{marka} {model} modelinin Türkiye'de satılmış bütün kasa (nesil) listesini ver.
Her kasa için: kasa kodu veya adı, Türkiye'deki ilk ve son model yılı, varsa makyaj (facelift) model yılı.
Üretici, distribütör veya güvenilir otomotiv kaynaklarını kullan; bilmediğini null bırak, tahmin etme.
Hâlâ satılan kasanın bitiş yılı {yil_simdi} olsun. Sadece JSON:
{{"nesiller":[{{"kasa":"", "baslangic":0, "bitis":0, "makyaj":null}}], "kaynaklar":["https://..."]}}
"""


def _model() -> str:
    return (os.getenv("WEB_GENERATION_MODEL") or "perplexity/sonar").strip()


def _cache_key(vehicle: Dict[str, Any]) -> str:
    values = [wmr.fold(vehicle.get(k)).strip() for k in ("brand", "model")]
    return "vehicle-generations:v3:" + hashlib.sha256(json.dumps(values).encode()).hexdigest()


def _year(value: Any) -> int | None:
    year = wmr._int(value)
    return year if year and 1980 <= year <= datetime.now().year + 1 else None


def parse_list(data: Dict[str, Any], cited: Dict[str, str]) -> List[Dict[str, Any]]:
    """Kasa listesini doğrular: yıllar mantıklı, en az bir kaynak aramada gerçekten dönmüş olmalı."""
    if not isinstance(data, dict):
        return []
    sources = [u.rstrip("/") for u in data.get("kaynaklar") or [] if isinstance(u, str)]
    if not any(u in cited for u in sources):
        return []
    output = []
    for entry in data.get("nesiller") or []:
        if not isinstance(entry, dict):
            continue
        start, end = _year(entry.get("baslangic")), _year(entry.get("bitis"))
        if not (start and end and start <= end and end - start <= MAX_SPAN_YEARS):
            continue
        facelift = _year(entry.get("makyaj"))
        output.append({"kasa": str(entry.get("kasa") or "").strip()[:40] or None, "baslangic": start,
                       "bitis": end, "makyaj": facelift if facelift and start < facelift <= end else None})
    output.sort(key=lambda g: g["baslangic"])
    return output


def select(generations: List[Dict[str, Any]], year: int) -> Dict[str, Any]:
    """Aracın yılını kapsayan kasa; geçiş yılında (iki kasa) yeni kasa seçilir."""
    matches = [g for g in generations if g["baslangic"] <= year <= g["bitis"]]
    if not matches:
        return {"bulundu": False}
    chosen = max(matches, key=lambda g: g["baslangic"])
    return {"bulundu": True, **chosen, "gecis_yili": len(matches) > 1}


def year_range(generation: Dict[str, Any], year: int, limit: int = 3) -> tuple | None:
    """Emsal yıl aralığı: aynı kasa, makyaj sınırının aynı tarafı, aracın yılından en fazla ±limit."""
    if not generation.get("bulundu") or not year:
        return None
    lo, hi = max(generation["baslangic"], year - limit), min(generation["bitis"], year + limit)
    facelift = generation.get("makyaj")
    if facelift:
        if year < facelift:
            hi = min(hi, facelift - 1)
        else:
            lo = max(lo, facelift)
    return (lo, hi) if lo <= year <= hi else None


def _search(vehicle: Dict[str, Any], client: httpx.Client) -> Dict[str, Any]:
    body = {"model": _model(), "temperature": 0, "max_tokens": 800, "usage": {"include": True},
            "messages": [{"role": "user", "content": _PROMPT.format(
                marka=vehicle.get("brand"), model=vehicle.get("model"), yil_simdi=datetime.now().year)}]}
    response = client.post(wmr._URL, headers={"Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}"}, json=body)
    response.raise_for_status()
    payload = response.json()
    message = (payload.get("choices") or [{}])[0].get("message") or {}
    cited = {}
    for annotation in message.get("annotations") or []:
        citation = annotation.get("url_citation") or {}
        if citation.get("url"):
            cited[citation["url"].rstrip("/")] = str(citation.get("title") or "")
    match = re.search(r"\{.*\}", message.get("content") or "", re.DOTALL)
    data = json.loads(match.group()) if match else {}
    return {"data": data, "cited": cited, "cost": (payload.get("usage") or {}).get("cost") or 0}


def get_generation(vehicle: Dict[str, Any], timeout: float = 25.0) -> Dict[str, Any]:
    """Aracın kasası; bulunamazsa {"bulundu": False}. Hata/zaman aşımı raporu engellemez."""
    year = wmr._int(vehicle.get("year"))
    if not os.getenv("OPENROUTER_API_KEY") or not vehicle.get("brand") or not vehicle.get("model") or not year:
        return {"bulundu": False}
    key = _cache_key(vehicle)
    cached = wmr._cache_read(key, CACHE_HOURS)
    cost = 0.0
    if cached and cached.get("nesiller"):
        generations = cached["nesiller"]
    else:
        try:
            with httpx.Client(timeout=timeout) as client:
                found = _search(vehicle, client)
        except (httpx.HTTPError, ValueError, TypeError, KeyError) as exc:
            logger.warning("[KASA] Liste alınamadı: %s", str(exc)[:200])
            return {"bulundu": False}
        cost = float(found.get("cost") or 0)
        generations = parse_list(found["data"], found["cited"])
        if generations:  # yalnız bulunan liste saklanır; bulunamazsa sonraki raporda yeniden denenir
            wmr._cache_write(key, {"nesiller": generations})
    result = select(generations, year)
    result["cost_usd"] = cost
    return result
