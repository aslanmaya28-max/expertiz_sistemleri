# -*- coding: utf-8 -*-
"""
Emsal ilan yetersizken yapay zekadan (OpenRouter uzerinden DeepSeek) temiz arac piyasa fiyati tahmini.

Bu deger PIYASA VERISI DEGILDIR: model egitildigi tarihteki genel bilgiden tahmin eder,
internette arama yapmaz, eski ya da hatali olabilir. Bu yuzden:
- yalnizca 5'ten az emsal varken kullanilir,
- raporda "yapay zeka tahmini" olarak etiketlenir ve guven skoru dusuk tutulur,
- ekspertiz raporu zaten admin onayi olmadan musteriye gitmez.

Ayarlar (.env):
  OPENROUTER_API_KEY   zorunlu (yoksa tahmin yapilmaz)
  AI_PRICE_ESTIMATE    off -> kapali (varsayilan: acik)
  AI_PRICE_MODEL       varsayilan deepseek/deepseek-chat
"""
from __future__ import annotations

import json
import logging
import os
import re
from datetime import datetime
from typing import Any, Dict, Optional

import httpx

logger = logging.getLogger(__name__)

SOURCE = "ai_estimate"
WARNING = "Yapay zekâ tahmini — gerçek emsal ilan verisi değil; admin kontrol etmeli."
_URL = "https://openrouter.ai/api/v1/chat/completions"
_MIN_PRICE, _MAX_PRICE = 50_000, 100_000_000

_SYSTEM = (
    "Türkiye ikinci el otomobil piyasası için fiyat tahmini yapıyorsun. "
    "Hasarsız, boyasız, değişensiz, tramer kaydı olmayan bir aracın Türkiye'deki güncel ikinci el "
    "ilan fiyatını Türk lirası olarak tahmin et. Yalnızca JSON döndür, başka metin yazma: "
    '{"medyan": sayı, "min": sayı, "max": sayı, "veri_tarihi": "YYYY-AA", "not": "kısa açıklama"}. '
    "Bilmiyorsan uydurma, medyan için null döndür."
)


def enabled() -> bool:
    return bool(os.getenv("OPENROUTER_API_KEY")) and (os.getenv("AI_PRICE_ESTIMATE") or "on").strip().lower() != "off"


def _model() -> str:
    return (os.getenv("AI_PRICE_MODEL") or "deepseek/deepseek-chat").strip()


def _prompt(vehicle: Dict[str, Any]) -> str:
    rows = [
        ("Marka", vehicle.get("brand")), ("Model", vehicle.get("model")), ("Paket", vehicle.get("package")),
        ("Model yılı", vehicle.get("year")), ("Kilometre", vehicle.get("km")),
        ("Yakıt", vehicle.get("fuel")), ("Vites", vehicle.get("transmission")),
    ]
    lines = [f"{k}: {v}" for k, v in rows if v not in (None, "", 0)]
    return f"Bugünün tarihi: {datetime.now():%Y-%m-%d}\n" + "\n".join(lines)


def _int(value: Any) -> Optional[int]:
    if isinstance(value, bool) or value is None:
        return None
    if isinstance(value, (int, float)):
        return int(value)
    digits = re.sub(r"[^\d]", "", str(value))
    return int(digits) if digits else None


def parse_answer(text: str) -> Optional[Dict[str, Any]]:
    """Model cevabindaki JSON'u okur ve dogrular; gecersizse None."""
    match = re.search(r"\{.*\}", text or "", re.DOTALL)
    if not match:
        return None
    try:
        data = json.loads(match.group(0))
    except ValueError:
        return None
    median = _int(data.get("medyan"))
    low = _int(data.get("min")) or median
    high = _int(data.get("max")) or median
    if not median or not (_MIN_PRICE <= median <= _MAX_PRICE):
        return None
    low, high = min(low, median), max(high, median)
    # Cok genis aralik: model emin degil demektir
    if high > median * 2 or low < median / 2:
        return None
    return {
        "median": median,
        "min": low,
        "max": high,
        "data_date": str(data.get("veri_tarihi") or "")[:7] or None,
        "note": str(data.get("not") or "")[:300] or None,
    }


def estimate(vehicle: Dict[str, Any], timeout_s: float = 40.0,
             transport: Optional[httpx.BaseTransport] = None) -> Optional[Dict[str, Any]]:
    """Temiz arac icin fiyat tahmini; kapaliysa, marka/model/yil yoksa ya da hata olursa None."""
    if not enabled() or not vehicle.get("brand") or not vehicle.get("model") or not vehicle.get("year"):
        return None
    try:
        with httpx.Client(timeout=timeout_s, transport=transport) as client:
            resp = client.post(
                _URL,
                headers={"Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}"},
                json={
                    "model": _model(),
                    "temperature": 0,
                    "messages": [{"role": "system", "content": _SYSTEM}, {"role": "user", "content": _prompt(vehicle)}],
                },
            )
            resp.raise_for_status()
            text = resp.json()["choices"][0]["message"]["content"]
    except Exception as exc:
        logger.warning("[AI FIYAT] Tahmin alinamadi: %s", str(exc)[:200])
        return None
    result = parse_answer(text)
    if result:
        result["model"] = _model()
    else:
        logger.warning("[AI FIYAT] Gecersiz cevap: %s", (text or "")[:200])
    return result


def to_reference(est: Dict[str, Any], previous: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Tahmini, degerleme motorunun okudugu piyasa referansi bicimine cevirir."""
    previous = previous or {}
    return {
        "found": True,
        "source": SOURCE,
        "reason": previous.get("reason") or "not_enough_reference",
        "count": 0,
        "raw_count": 0,
        "market_avg_price": est["median"],
        "market_median_price": est["median"],
        "market_min_price": est["min"],
        "market_max_price": est["max"],
        "confidence": 20,
        "uyari": WARNING,
        "ai_estimate": est,
        "scope": {"fallback": "ai_estimate", "model": est.get("model"),
                  "listed_price": (previous.get("scope") or {}).get("listed_price")},
        "package": previous.get("package"),
        "package_match": False,
        "samples": [],
    }
