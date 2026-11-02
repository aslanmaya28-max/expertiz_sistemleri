"""Aracın kasa (nesil) bilgisi: aynı kasa + motor + şanzımanın Türkiye'de sunulduğu yıllar.

Emsal havuzunu doğru genişletmek için kullanılır: aynı kasa/motor/şanzımanlı ilanlar yalnız
yaş ve km farkıyla düzeltilerek karşılaştırılabilir (kullanıcı önerisi, 02.11.2026). Farklı
kasa (ör. 2015-2020 Tucson) havuza girmez. Bilgi Perplexity Sonar ile kaynaklı bulunur ve
6 ay saklanır; bulunamazsa çağıran mevcut ±1/±2 yıl kuralına döner.
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
import re
from datetime import datetime
from typing import Any, Dict

import httpx

from yerimebak_ai_v5.services import web_market_reference as wmr

logger = logging.getLogger(__name__)

MAX_SPAN_YEARS = 12

_PROMPT = """Türkiye pazarındaki şu araç için kasa (nesil) bilgisini bul: {arac}.
İstenen: bu aracın ait olduğu kasa/nesil kodu, bu kasanın Türkiye'de satıldığı yıllar ve
özellikle BU MOTOR ve BU ŞANZIMAN kombinasyonunun bu kasada sunulduğu ilk ve son model yılı,
varsa makyaj (facelift) model yılı. Üretici, distribütör veya güvenilir otomotiv kaynaklarını kullan.
Bilmediğini null bırak, tahmin etme. Sadece JSON:
{{"kasa":"", "kasa_baslangic":0, "kasa_bitis":0, "motor_sanziman_baslangic":0,
"motor_sanziman_bitis":0, "makyaj_yili":null, "kaynaklar":["https://..."]}}
Kasa hâlâ satılıyorsa bitiş yılı olarak {yil_simdi} yaz.
"""


def _model() -> str:
    return (os.getenv("WEB_GENERATION_MODEL") or "perplexity/sonar").strip()


def _cache_key(vehicle: Dict[str, Any]) -> str:
    values: list = [wmr.fold(vehicle.get(k)).strip() for k in ("brand", "model", "package", "fuel", "transmission")]
    values.append(wmr._int(vehicle.get("year")) or 0)
    return "vehicle-generation:v2:" + hashlib.sha256(json.dumps(values).encode()).hexdigest()


def _year(value: Any) -> int | None:
    year = wmr._int(value)
    return year if year and 1980 <= year <= datetime.now().year + 1 else None


def parse(data: Dict[str, Any], cited: Dict[str, str], vehicle: Dict[str, Any]) -> Dict[str, Any]:
    """Yanıtı doğrular: yıllar mantıklı olmalı, aracın yılını kapsamalı, en az bir kaynak dönmüş olmalı."""
    empty = {"bulundu": False}
    if not isinstance(data, dict):
        return empty
    year = wmr._int(vehicle.get("year"))
    # Motor+şanzıman yılları ölçümde güvenilmez çıktı (Tucson 1.6 CRDi için yalnız "2021" dedi);
    # kasa yılları ve makyaj sınırı kullanılır, motor/şanzıman uyumu ilan bazında denetlenir.
    start = _year(data.get("kasa_baslangic"))
    end = _year(data.get("kasa_bitis"))
    if not (year and start and end and start <= year <= end and end - start <= MAX_SPAN_YEARS):
        return empty
    sources = [u.rstrip("/") for u in data.get("kaynaklar") or [] if isinstance(u, str)]
    sources = [u for u in sources if u in cited]
    if not sources:
        return empty
    facelift = _year(data.get("makyaj_yili"))
    return {"bulundu": True, "kasa": str(data.get("kasa") or "").strip()[:40] or None,
            "baslangic": start, "bitis": end,
            "makyaj": facelift if facelift and start < facelift <= end else None,
            "kaynaklar": sources[:3]}


def _search(vehicle: Dict[str, Any], client: httpx.Client) -> Dict[str, Any]:
    arac = " ".join(str(vehicle.get(k)) for k in ("brand", "model", "year", "package", "fuel", "transmission")
                    if vehicle.get(k))
    body = {"model": _model(), "temperature": 0, "max_tokens": 800, "usage": {"include": True},
            "messages": [{"role": "user", "content": _PROMPT.format(arac=arac, yil_simdi=datetime.now().year)}]}
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


def get_generation(vehicle: Dict[str, Any], timeout: float = 25.0) -> Dict[str, Any]:
    """Kasa bilgisi; bulunamazsa {"bulundu": False}. Hata/zaman aşımı raporu engellemez."""
    if not os.getenv("OPENROUTER_API_KEY") or not vehicle.get("brand") or not vehicle.get("model") \
            or not vehicle.get("year"):
        return {"bulundu": False}
    key = _cache_key(vehicle)
    cached = wmr._cache_read(key, 24 * 180)
    if cached:
        return {**cached, "cost_usd": 0, "cached": True}
    try:
        with httpx.Client(timeout=timeout) as client:
            found = _search(vehicle, client)
        result = parse(found["data"], found["cited"], vehicle)
        result["cost_usd"] = float(found.get("cost") or 0)
    except (httpx.HTTPError, ValueError, TypeError, KeyError) as exc:
        logger.warning("[KASA] Bilgi bulunamadı: %s", str(exc)[:200])
        return {"bulundu": False}
    # Yalnız bulunan bilgi saklanır; bulunamazsa sonraki raporda yeniden denenir (~0,006 $).
    if result.get("bulundu"):
        wmr._cache_write(key, {k: v for k, v in result.items() if k != "cost_usd"})
    result["cached"] = False
    return result
