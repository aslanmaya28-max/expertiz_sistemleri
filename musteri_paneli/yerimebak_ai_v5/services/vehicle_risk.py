"""Akıllı Alıcı için kaynaklı model riskleri ve kurallı alıcı kontrol listeleri.

get_model_risks -> {riskler, bulunamadi, scope}. Araç alanları mevcut servislerle
aynıdır: brand, model, year, package, fuel, transmission, km (engine isteğe bağlı).
Önbellek yalnız model bilgisini tutar; bakım/sorular güncel araçla ayrıca üretilir.
Anahtar terim denetimi bir iddianın doğruluk garantisi değildir; sonuçlar servis
kaydı ve şasi numarasıyla doğrulanması gereken kontrol başlıklarıdır.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import re
from datetime import datetime
from urllib.parse import urlsplit

import httpx

from yerimebak_ai_v5.services import web_market_reference as wmr
from yerimebak_ai_v5.services.web_market_reference import fold, _displacements


# İlk değer, çıktı ve tekilleştirme anahtarıdır. Eş anlamlılar kaynakta aranır.
_TOPICS = {
    "triger": ("triger", "timing belt"),
    "zincir": ("zincir", "timing chain"),
    "mekatronik": ("mekatronik", "mechatronic"),
    "sanziman": ("şanzıman", "transmission", "gearbox"),
    "debriyaj": ("debriyaj", "clutch"),
    "volan": ("volan", "çift kütle", "dual mass"),
    "dpf": ("dpf", "partikül"),
    "egr": ("egr",),
    "enjektor": ("enjektör", "injector"),
    "turbo": ("turbo",),
    "fren": ("fren", "brake"),
    "aku": ("akü", "battery", "batarya"),
    "lastik": ("lastik", "tyre", "tire"),
    "yag": ("yağ tüketimi", "oil consumption", "yağ kaçağı", "oil leak"),
    "sogutma": ("soğutma", "devirdaim", "coolant", "water pump"),
    "geri_cagirma": ("geri çağırma", "recall", "servis bülteni", "service bulletin"),
}
_OFFICIAL = {
    "seat": ("seat.com", "seat.com.tr"), "volkswagen": ("volkswagen.com", "volkswagen.com.tr"),
    "vw": ("volkswagen.com", "volkswagen.com.tr"), "skoda": ("skoda-auto.com", "skoda.com.tr"),
    "audi": ("audi.com", "audi.com.tr"), "ford": ("ford.com", "ford.com.tr"),
    "toyota": ("toyota.com", "toyota.com.tr", "toyota-europe.com"),
    "renault": ("renault.com", "renault.com.tr"), "bmw": ("bmw.com", "bmw.com.tr"),
    "mercedes-benz": ("mercedes-benz.com", "mercedes-benz.com.tr"),
    "peugeot": ("peugeot.com", "peugeot.com.tr"), "citroen": ("citroen.com", "citroen.com.tr"),
    "fiat": ("fiat.com", "fiat.com.tr"), "honda": ("honda.com", "honda.com.tr"),
    "hyundai": ("hyundai.com",), "kia": ("kia.com",), "opel": ("opel.com", "opel.com.tr"),
}
_AUTHORITIES = ("nhtsa.gov", "gov.uk", "ec.europa.eu")
_TECHNICAL = ("whatcar.com", "adac.de", "rac.co.uk", "theaa.com", "autocar.co.uk")
_PROMPT = """Şu araç için motor/şanzıman sürümüne özgü bilinen sorunları,
geri çağırmaları/servis bültenlerini ve doğrulanacak büyük bakım kalemlerini bul: {vehicle}.
Üretici, resmi geri çağırma ve güvenilir teknik incelemeleri öncele. Forum iddiasını
kesin bilgi sayma. Aracın arızalı olduğunu veya bakımının yapılmadığını varsayma.
Yalnız kaynakta açıkça yazan motor, şanzıman, model yılı kapsamını ve TL maliyeti ver.
Belirli km/yaş için kesin değişim aralığı uydurma. Şasi numarasıyla kontrolü öner.
Sadece JSON: {{"riskler":[{{"baslik":"Triger seti", "aciklama":"",
"etkiledigi":"motor/şanzıman/yıl aralığı", "belirtiler":[], "kontrol":"",
"tahminiMaliyet":null, "kaynaklar":["https://..."], "guven":"dusuk"}}]}}.
tahminiMaliyet yalnız aynı bakım için açıkça TL verilmişse {{"min":0,"max":0}} olabilir.
"""


def _cache_days():
    try:
        days = float(os.getenv("WEB_RISK_CACHE_DAYS", "30"))
        return days if math.isfinite(days) and days >= 0 else 30
    except ValueError:
        return 30


def _cache_key(vehicle):
    # Beş yıllık kovalar (merkez yıl ±2); kilometre/gerçek yaş modele ait değildir.
    values = [fold(vehicle.get(k)).strip() for k in
              ("brand", "model", "engine", "package", "fuel", "transmission")]
    values.append((wmr._int(vehicle.get("year")) or 0) // 5)
    return "vehicle-risk:v1:" + hashlib.sha256(json.dumps(values).encode()).hexdigest()


def _search(query, client):
    """Emsal aramasıyla aynı OpenRouter web eklentisi ve sağlayıcı ayarları."""
    body = {"model": wmr.model_name(), "temperature": 0,
            "plugins": [{"id": "web", "max_results": 10}],
            "messages": [{"role": "user", "content": _PROMPT.format(vehicle=query)}],
            "usage": {"include": True}}
    provider = (os.getenv("WEB_PRICE_PROVIDER") or "").strip()
    if provider:
        body["provider"] = {"only": [provider], "allow_fallbacks": False}
    response = client.post(wmr._URL, headers={"Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}"}, json=body)
    response.raise_for_status()
    data = response.json()
    message = (data.get("choices") or [{}])[0].get("message") or {}
    sources = {}
    for annotation in message.get("annotations") or []:
        citation = annotation.get("url_citation") or {}
        if citation.get("url"):
            sources[citation["url"].rstrip("/")] = citation.get("content") or ""
    match = re.search(r"\{.*\}", message.get("content") or "", re.DOTALL)
    if not match:
        raise ValueError("Arama yanıtında JSON yok")
    parsed = json.loads(match.group())
    if not isinstance(parsed, dict) or not isinstance(parsed.get("riskler"), list):
        raise ValueError("Arama yanıtında risk listesi yok")
    return {"risks": parsed.get("riskler") or [], "sources": sources,
            "cost": (data.get("usage") or {}).get("cost") or 0}


def _topics(text):
    text = fold(text)
    return [key for key, terms in _TOPICS.items() if any(
        re.search(r"\b" + re.escape(fold(term)), text) for term in terms)]


def _gear(text):
    text = fold(text)
    return {label for label, pattern in {
        "manual": r"\b(manuel|manual)\b", "dsg": r"\b(dsg|s.tronic)\b",
        "cvt": r"\bcvt\b", "edc": r"\bedc\b", "dct": r"\bdct\b",
        "eat": r"\beat[68]\b"}.items() if re.search(pattern, text)}


def _incompatible(text, vehicle):
    target = " ".join(str(vehicle.get(k) or "") for k in ("engine", "package", "transmission"))
    a, b = _displacements(target), _displacements(text)
    if a and b and not a & b:
        return True
    families = {"tsi", "tdi", "tfsi", "dci", "tce", "hdi", "puretech", "ecoboost", "tdci"}
    target_families = set(re.findall(r"\b[a-z]+\b", fold(target))) & families
    found_families = set(re.findall(r"\b[a-z]+\b", fold(text))) & families
    if target_families and found_families and not target_families & found_families:
        return True
    gears, found = _gear(target), _gear(text)
    if gears and found and not gears & found:
        return True
    if "manual" in found and "otomatik" in fold(target):
        return True
    if "manual" in gears and re.search(r"\b(otomatik|automatic)\b", fold(text)):
        return True
    year = wmr._int(vehicle.get("year"))
    ranges = re.findall(r"\b((?:19|20)\d{2})\s*[-–/]\s*((?:19|20)\d{2})\b", text)
    if year and ranges and not any(int(lo) <= year <= int(hi) for lo, hi in ranges):
        return True
    return False


def _domain(host, domains):
    return any(host == d or host.endswith("." + d) for d in domains)


def _confidence(url, text, vehicle):
    host = (urlsplit(url).hostname or "").lower()
    if any(word in host + urlsplit(url).path.lower() for word in ("forum", "club", "reddit", "community")):
        return "dusuk"
    # Sürüm/model kapsamı belirsiz bir metin yüksek/orta güven kazanamaz.
    target = _displacements(str(vehicle.get("engine") or "") + " " + str(vehicle.get("package") or ""))
    if fold(vehicle.get("model")) not in fold(text) or (target and not target & _displacements(text)):
        return "dusuk"
    official = _OFFICIAL.get(fold(vehicle.get("brand")), ()) + _AUTHORITIES
    if _domain(host, official) and re.search(r"geri cagirma|recall|servis bulteni|service bulletin", fold(text)):
        return "yuksek"
    return "orta" if _domain(host, _TECHNICAL) else "dusuk"


def _cost(value, texts, topics):
    if not isinstance(value, dict):
        return None
    low, high = value.get("min"), value.get("max")
    if any(isinstance(n, bool) or not isinstance(n, (int, float)) or not math.isfinite(n) for n in (low, high)):
        return None
    if not 0 < low <= high or int(low) != low or int(high) != high:
        return None
    # Yalnız anahtar terimle aynı cümlede açık TL aralığı; km/EUR veya başka
    # kalemin maliyetini kabul etmez. Binlik noktaları cümle ayırıcı sayılmaz.
    for text in texts:
        for sentence in re.split(r"[.!?](?!\d)|[\n;]", text):
            if not set(_topics(sentence)) & set(topics):
                continue
            for a, b in re.findall(r"(?<![\d.,])([\d.]+)\s*[-–]\s*([\d.]+)\s*(?:TL\b|₺)", sentence, re.I):
                if a.replace(".", "").isdigit() and b.replace(".", "").isdigit():
                    if (int(a.replace(".", "")), int(b.replace(".", ""))) == (low, high):
                        return {"min": int(low), "max": int(high)}
            if low == high and re.search(rf"(?<![\d.,])(?:{int(low)}|{int(low):,})\s*(?:TL\b|₺)".replace(",", r"\."), sentence, re.I):
                return {"min": int(low), "max": int(high)}
    return None


def _verify(item, sources, vehicle):
    if not isinstance(item, dict) or not isinstance(item.get("baslik"), str):
        return None
    topics = _topics(item["baslik"])
    if not topics or _incompatible(str(item.get("etkiledigi") or ""), vehicle):
        return None
    valid = {}
    for url in item.get("kaynaklar") or []:
        if not isinstance(url, str) or urlsplit(url).scheme not in ("https", "http"):
            continue
        url = url.rstrip("/")
        text = sources.get(url)
        required = set(topics) - {"geri_cagirma"} or set(topics)
        if not isinstance(text, str) or not required & set(_topics(text)) or _incompatible(text, vehicle):
            continue
        # Bir sayfa birden çok motoru anlatabilir. İddiayı taşıyan cümlenin
        # yalnız başka motoru kapsaması, genel sayfadaki hedef motorla gizlenemez.
        relevant = [s for s in re.split(r"(?<!\d)[.!?](?!\d)|[\n;]", text)
                    if required & set(_topics(s))]
        if any(_incompatible(sentence, vehicle) for sentence in relevant):
            continue
        valid[url] = text
    if not valid:
        return None
    confidence = max((_confidence(url, text, vehicle) for url, text in valid.items()),
                     key=lambda c: {"dusuk": 0, "orta": 1, "yuksek": 2}[c])
    return {"baslik": item["baslik"], "aciklama": str(item.get("aciklama") or ""),
            "etkiledigi": str(item.get("etkiledigi") or "Kapsamı servisle doğrulayın"),
            "belirtiler": [s for s in item.get("belirtiler", []) if isinstance(s, str)]
            if isinstance(item.get("belirtiler"), list) else [],
            "kontrol": str(item.get("kontrol") or "Şasi numarası ve servis kaydıyla doğrulayın."),
            "tahminiMaliyet": _cost(item.get("tahminiMaliyet"), valid.values(), topics),
            "kaynaklar": list(valid), "guven": confidence}


def _verified_items(items, sources, vehicle):
    output, seen = [], set()
    for item in items:
        verified = _verify(item, sources, vehicle)
        if verified and fold(verified["baslik"]) not in seen:
            output.append(verified)
            seen.add(fold(verified["baslik"]))
    return output


def get_model_risks(vehicle) -> dict:
    """Tek arama; opsiyonel 30 günlük DB önbelleği, arıza teşhisi değildir."""
    result = {"riskler": [], "bulunamadi": True,
              "scope": {"cached": False, "searches": 0, "cost_usd": 0, "model": wmr.model_name()}}
    if not os.getenv("OPENROUTER_API_KEY") or not vehicle.get("brand") or not vehicle.get("model"):
        return result
    days, key = _cache_days(), _cache_key(vehicle)
    if days:
        cached = wmr._cache_read(key, days * 24)
        if cached:
            # Aynı kovadaki başka yıl, daha dar kapsamlı bir riski devralamaz.
            # Ham adayları tutmak, ilk araçta elenen bir adayın uygun yılda
            # yeniden değerlendirilmesini de sağlar; yeniden arama yapılmaz.
            candidates = cached.pop("_candidates", [])
            sources = cached.pop("_sources", {})
            cached["riskler"] = _verified_items(candidates, sources, vehicle)
            cached["bulunamadi"] = not bool(cached["riskler"])
            return cached
    try:
        query = wmr._vehicle_text({**vehicle, "km": None}) + " " + str(vehicle.get("engine") or "")
        with httpx.Client(timeout=90.0) as client:
            found = _search(query, client)
        result["scope"].update(searches=1, cost_usd=float(found.get("cost") or 0))
        result["riskler"] = _verified_items(found.get("risks") or [], found.get("sources") or {}, vehicle)
        result["bulunamadi"] = not bool(result["riskler"])
    except (httpx.HTTPError, ValueError, TypeError, KeyError, RuntimeError):
        return result
    # Başarıyla tamamlanan boş sonuç da aynı modelde yeniden arama maliyetini önler.
    # İstemci/ayrıştırma hataları yukarıda döner ve önbelleğe girmez.
    if days:
        wmr._cache_write(key, {**result, "_candidates": found.get("risks") or [],
                               "_sources": found.get("sources") or {}})
    return result


def _risk_items(risks):
    items = risks.get("riskler", []) if isinstance(risks, dict) else risks
    return [r for r in (items or []) if isinstance(r, dict)]


def upcoming_maintenance(vehicle, risks) -> list:
    """Genel kontrol eşikleri üretici değişim periyodu değildir; geçmişi sorgular."""
    km = wmr._int(vehicle.get("km")) or 0
    year = wmr._int(vehicle.get("year")) or datetime.now().year
    age = max(0, datetime.now().year - year)
    fuel = fold(vehicle.get("fuel"))
    electric = fuel in ("elektrik", "elektrikli", "electric", "ev")
    automatic = "otomatik" in fold(vehicle.get("transmission")) or bool(_gear(str(vehicle.get("package"))) - {"manual"})
    labels = ["Fren ve lastik kontrolü", "Periyodik bakım kayıtları"]
    if age >= 4:
        labels += ["Akü kontrolü"]
    if not electric:
        if km >= 60000 or age >= 5:
            labels += ["Triger / zincir bakım geçmişi"]
        if km >= 60000:
            labels += ["Şanzıman yağı ve filtre geçmişi"]
        if km >= 100000:
            labels += ["Turbo ve enjektör kontrolü"]
            if not automatic:
                labels += ["Debriyaj / çift kütleli volan kontrolü"]
        if ("dizel" in fuel or "diesel" in fuel) and (km >= 80000 or age >= 5):
            labels += ["DPF / EGR kontrolü"]
    output, seen = [], set()
    # Model bakım/risk başlıkları önce gelir; genel öneriler aynı parçayı tekrarlamaz.
    candidates = [r for r in _risk_items(risks) if set(_topics(r.get("baslik"))) - {"geri_cagirma"}]
    candidates += [{"baslik": label} for label in labels]
    for entry in candidates:
        title = str(entry.get("baslik") or "")
        keys = set(_topics(title)) or {fold(title)}
        if keys & seen:
            continue
        seen.update(keys)
        output.append({**entry, "baslik": title,
                       "aciklama": f"Bu kilometrede ({km:,} km) ve yaşta ({age} yıl) {title.lower()} geçmişini doğrulayın; üreticinin araç sürümüne özel bakım planını esas alın.",
                       "kontrol": entry.get("kontrol") or "Tarih, kilometre ve servis faturalarını karşılaştırın."})
    return output


def seller_questions(vehicle, risks, findings) -> list:
    """Risk, bakım ve beyanlardan tekrarsız 6–10 satıcı sorusu."""
    questions = ["Ekspertize izin veriyor musunuz?", "Servis ve bakım faturalarını tarih ve kilometreleriyle paylaşır mısınız?",
                 "Şasi numarasıyla açık geri çağırma ve servis kampanyası kontrolü yapabilir miyiz?"]
    if findings:
        questions.append("Tramer kaydının detay dökümünü ve onarım faturalarını paylaşır mısınız?")
        values = findings if isinstance(findings, list) else [findings]
        for finding in values[:1]:
            title = finding.get("baslik") or finding.get("parca") if isinstance(finding, dict) else str(finding)
            if title:
                questions.append(f"Beyan edilen {title} için hasarın nedeni ve onarım belgeleri var mı?")
    seen = set()
    for entry in upcoming_maintenance(vehicle, risks):
        title = entry["baslik"]
        topics = set(_topics(title)) or {fold(title)}
        if topics <= seen:
            continue
        seen.update(topics)
        if "triger" in topics or "zincir" in topics:
            question = "Triger seti veya zincir en son kaç km'de kontrol edildi/değişti? Faturası var mı?"
        else:
            question = f"{title} için son kontrol/bakım hangi tarih ve kilometrede yapıldı? Faturası var mı?"
        questions.append(question)
        if len(questions) >= 9:
            break
    for question in ["Aracı soğuk motorla çalıştırıp test sürüşü yapabilir miyiz?",
                     "Kilometreyi TÜVTÜRK ve servis kayıtlarıyla doğrulayabilir miyiz?",
                     "Bilinen arızalar, uyarı lambaları veya bekleyen onarımlar var mı?"]:
        if len(questions) >= 10:
            break
        questions.append(question)
    return list(dict.fromkeys(questions))[:10]
