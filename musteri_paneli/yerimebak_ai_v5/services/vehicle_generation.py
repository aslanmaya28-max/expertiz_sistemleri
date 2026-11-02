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
from concurrent.futures import ThreadPoolExecutor
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


def _models() -> List[str]:
    """Kasa listesi iki kaynaktan sorulur; tek modelin cevabı ölçümde tutarsızdı."""
    raw = os.getenv("WEB_GENERATION_MODELS") or "perplexity/sonar,perplexity/sonar-pro"
    return [m.strip() for m in raw.split(",") if m.strip()][:2]


def _cache_key(vehicle: Dict[str, Any]) -> str:
    values = [wmr.fold(vehicle.get(k)).strip() for k in ("brand", "model")]
    return "vehicle-generations:v6:" + hashlib.sha256(json.dumps(values).encode()).hexdigest()


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
    """Aracın yılını kapsayan kasa. Geçiş yılında (iki kasa) yeni kasa seçilir ve önceki kasa
    da döndürülür: müşteriye iki kasanın ortalaması gösterilir (kullanıcı kararı, 02.11.2026)."""
    matches = sorted((g for g in generations if g["baslangic"] <= year <= g["bitis"]), key=lambda g: g["baslangic"])
    if not matches:
        return {"bulundu": False}
    result = {"bulundu": True, **matches[-1], "gecis_yili": len(matches) > 1}
    if len(matches) > 1:
        result["onceki"] = {"bulundu": True, **matches[-2]}
    return result


def _newest(generations: List[Dict[str, Any]], year: int):
    matches = sorted((g for g in generations if g["baslangic"] <= year <= g["bitis"]), key=lambda g: g["baslangic"])
    return matches[-1] if matches else None


def _previous(generations: List[Dict[str, Any]], newest: Dict[str, Any], year: int):
    """Geçiş yılı: yeni kasa bu yıl (±1) başlamış ve önceki kasa bu yıla (±1) kadar sürmüş."""
    older = [g for g in generations if g["baslangic"] < newest["baslangic"]]
    if not older or newest["baslangic"] < year - 1:
        return None
    prev = max(older, key=lambda g: g["baslangic"])
    return prev if prev["bitis"] >= year - 1 else None


def _has_code(name: str) -> bool:
    """Kasa kodu içeriyor mu: "NX4", "TL", "KF", "X98" (Roma rakamı "IV" kod sayılmaz)."""
    for token in re.findall(r"[A-Za-z0-9]+", name):
        if re.fullmatch(r"[A-Z]+\d+[A-Z0-9]*|[A-Z]{2,4}", token) and not re.fullmatch(r"[IVX]+", token):
            return True
    return False


def _name(first: Dict[str, Any], second: Dict[str, Any]):
    """Kodlu ad ("NX4 (4. nesil)") numaralı ya da Roma rakamlı addan ("Tucson IV") önce gelir."""
    names = [n for n in (first.get("kasa"), second.get("kasa")) if n]
    coded = [n for n in names if _has_code(n)] or [n for n in names if "nesil" not in n.lower()]
    name = (coded or names or [None])[0]
    if name and "(" in name:  # müşteriye kısa ad: "NX4 (4. nesil Tucson)" → "NX4"
        name = name.split("(")[0].strip(" /-,") or name
    return name


def _align(first: List[Dict[str, Any]], second: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """İki listedeki kasaları başlangıç yılına göre (±1) eşleştirir; eşleşmeyen kasa atlanır.
    Her kasa için gevşek (birleşik) ve sıkı (kesişim) yıl aralığı tutulur."""
    pairs, used = [], set()
    for a in first:
        match = next((i for i, b in enumerate(second) if i not in used and abs(a["baslangic"] - b["baslangic"]) <= 1), None)
        if match is None:
            continue
        used.add(match)
        b = second[match]
        faces = sorted(f for f in (a.get("makyaj"), b.get("makyaj")) if f)
        pairs.append({"kasa": _name(a, b), "baslangic": min(a["baslangic"], b["baslangic"]),
                      "bitis": max(a["bitis"], b["bitis"]), "sik_baslangic": max(a["baslangic"], b["baslangic"]),
                      "sik_bitis": min(a["bitis"], b["bitis"]),
                      "makyaj": faces[0] if faces else None, "makyaj_son": faces[-1] if faces else None})
    return sorted(pairs, key=lambda g: g["baslangic"])


def combine(first: List[Dict[str, Any]], second: List[Dict[str, Any]], year: int) -> Dict[str, Any]:
    """İki kaynağın ortak sonucu. Kasalar başlangıç yılına göre eşleştirilir; araç yılı iki kasanın
    birleşik aralığına düşüyorsa geçiş yılıdır (ölçüm: kaynaklar yeni kasanın başlangıcını ±1 yıl
    farklı veriyor; bu tam da geçiş yılının işaretidir)."""
    aligned = _align(first, second)
    matches = [g for g in aligned if g["baslangic"] <= year <= g["bitis"]]
    if not matches or len(matches) > 2:
        return {"bulundu": False, "uyusmazlik": True}
    newest = matches[-1]
    previous = matches[0] if len(matches) == 2 else None
    if previous is None:
        # Yeni kasa tam bu yıl başladıysa ve önceki kasa bir önceki yıla kadar sürdüyse de geçiş
        # yılıdır: kasa değişiminde eski stok bir sonraki model yılı olarak da satılır
        # (kullanıcının listesi: TL 2015–2021, NX4 2021–).
        older = [g for g in aligned if g["baslangic"] < newest["baslangic"]]
        if older and newest["baslangic"] >= year and older[-1]["bitis"] >= year - 1:
            previous = older[-1]
    result = {"bulundu": True, **newest, "gecis_yili": previous is not None}
    if previous is not None:
        result["onceki"] = {"bulundu": True, **previous, "bitis": max(previous["bitis"], year)}
        result["baslangic"] = year  # yeni kasa havuzu geçiş yılından önceye inmez
    return result


def year_range(generation: Dict[str, Any], year: int, limit: int = 3) -> tuple | None:
    """Emsal yıl aralığı: aynı kasa, makyaj sınırının aynı tarafı, aracın yılından en fazla ±limit."""
    if not generation.get("bulundu") or not year:
        return None
    lo, hi = max(generation["baslangic"], year - limit), min(generation["bitis"], year + limit)
    first_face = generation.get("makyaj")
    last_face = generation.get("makyaj_son") or first_face
    if first_face:
        if year < first_face:
            hi = min(hi, first_face - 1)
        elif year >= last_face:
            lo = max(lo, last_face)
        else:  # kaynaklar makyaj yılında ayrışıyor ve araç arada: yalnız kendi yılı
            lo = hi = year
    return (lo, hi) if lo <= year <= hi else None


def _search(vehicle: Dict[str, Any], client: httpx.Client, model: str = "perplexity/sonar") -> Dict[str, Any]:
    body = {"model": model, "temperature": 0, "max_tokens": 800, "usage": {"include": True},
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
    if not (cached and cached.get("listeler")):
        lists = []
        with httpx.Client(timeout=timeout) as client, ThreadPoolExecutor(2) as pool:
            futures = [pool.submit(_search, vehicle, client, model) for model in _models()]
            for future in futures:
                try:
                    found = future.result()
                except (httpx.HTTPError, ValueError, TypeError, KeyError) as exc:
                    logger.warning("[KASA] Liste alınamadı: %s", str(exc)[:200])
                    continue
                cost += float(found.get("cost") or 0)
                lists.append(parse_list(found["data"], found["cited"]))
        if len(lists) < 2 or not lists[0] or not lists[1]:
            return {"bulundu": False, "uyusmazlik": True, "cost_usd": cost}
        result = combine(lists[0], lists[1], year)
        if result.get("bulundu"):  # yalnız uyuşan liste saklanır; uyuşmazsa sonraki raporda yeniden sorulur
            wmr._cache_write(key, {"listeler": lists})
    else:
        lists = cached["listeler"]
        result = combine(lists[0], lists[1], year)
    if not result.get("bulundu"):
        # Kaynaklar uyuşmazsa kasa bilinmez: çağıran yalnız aracın kendi yılını kullanır.
        logger.info("[KASA] %s %s %s: kaynaklar uyuşmadı", vehicle.get("brand"), vehicle.get("model"), year)
    result["cost_usd"] = cost
    return result
