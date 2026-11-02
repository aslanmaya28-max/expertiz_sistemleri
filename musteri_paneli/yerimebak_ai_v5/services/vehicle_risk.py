"""Akıllı Alıcı için kaynaklı model riskleri ve kurallı alıcı kontrol listeleri.

get_model_risks -> {riskler, kullaniciSikayetleri, bulunamadi, scope}. Araç alanları mevcut servislerle
aynıdır: brand, model, year, package, fuel, transmission, km (engine isteğe bağlı).
Önbellek yalnız model bilgisini tutar; bakım/sorular güncel araçla ayrıca üretilir.
Anahtar terim denetimi bir iddianın doğruluk garantisi değildir; sonuçlar servis
kaydı ve şasi numarasıyla doğrulanması gereken kontrol başlıklarıdır.
"""
from __future__ import annotations

import hashlib
import json
import logging
import math
import os
import re
from concurrent.futures import ThreadPoolExecutor, wait
from datetime import datetime
from urllib.parse import unquote, urlsplit

import httpx

from yerimebak_ai_v5.services import web_market_reference as wmr
from yerimebak_ai_v5.services.web_market_reference import fold, _displacements


# İlk değer, çıktı ve tekilleştirme anahtarıdır. Eş anlamlılar kaynakta aranır.
logger = logging.getLogger(__name__)

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
    "adblue": ("adblue",),
    "yakit_pompasi": ("yakıt pompası", "enjektör pompası", "fuel pump"),
    "yag_pompasi": ("yağ pompası", "oil pump"),
    "motor": ("motor arızası", "motor yağı", "engine failure", "engine oil"),
    "egzoz": ("egzoz", "exhaust"),
    "buji": ("buji", "kızdırma bujisi", "spark plug", "glow plug"),
    "atesleme": ("ateşleme bobini", "ignition coil"),
    "suspansiyon": ("süspansiyon", "amortisör", "suspension"),
    "sensor": ("sensör", "sensor"),
    "adas": ("adas", "şerit takip", "adaptif hız", "lane assist"),
    "elektronik_unite": ("elektronik ünite", "ecu", "kontrol ünitesi"),
    "multimedya": ("multimedya", "infotainment"),
    "anahtarsiz": ("anahtarsız", "keyless"),
    "gosterge": ("gösterge", "instrument cluster"),
    "trim": ("trim", "iç trim sesi", "tıkırtı"),
    "far_bugusu": ("far buğusu", "far buğu", "headlight condensation"),
    "kaplama": ("kaplama", "döşeme", "boya soyulması"),
    "kasa": ("kapı hizası", "bagaj hizası", "kapı/bagaj hizası", "şasi", "paslan", "paslı", "pas"),
    "geri_cagirma": ("geri çağırma", "recall", "servis bülteni", "service bulletin"),
    # Kullanıcı şikâyetlerinde sık geçen belirtiler (Sonar araması, 02.11.2026)
    "ariza_lambasi": ("arıza lambası", "arıza ışığı", "check engine"),
    "guc_kaybi": ("güç düşmesi", "güç kaybı", "çekiş kaybı", "nefes kesilmesi", "limp mode"),
    "titreme": ("titreme", "sarsıntı", "vibration"),
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
_USER_SOURCES = ("sikayetvar.com", "donanimhaber.com", "technopat.net")
_COMPILATIONS = ("araclo.com",)
_BLOCKED = ("kronikmotor.com",)
_PROMPT = """Şu araç için motor/şanzıman sürümüne özgü bilinen sorunları,
geri çağırmaları/servis bültenlerini ve doğrulanacak büyük bakım kalemlerini bul: {vehicle}.
Üretici, resmi geri çağırma ve güvenilir teknik incelemeleri öncele. Forum iddiasını
kesin bilgi sayma. Aracın arızalı olduğunu veya bakımının yapılmadığını varsayma.
Yalnız kaynakta açıkça yazan motor, şanzıman, model yılı kapsamını ve TL maliyeti ver.
Belirli km/yaş için kesin değişim aralığı uydurma. Şasi numarasıyla kontrolü öner.
Sadece JSON: {{"riskler":[{{"baslik":"Triger seti", "aciklama":"",
"etkiledigi":"motor/şanzıman/yıl aralığı", "belirtiler":[], "kontrol":"",
"tahminiMaliyet":null, "kaynaklar":["https://..."], "guven":"dusuk"}}],
"kullaniciSikayetleri":[{{"baslik":"Triger sesi", "aciklama":"Kullanıcı beyanlarının kısa özeti",
"kaynaklar":["https://..."]}}]}}.
tahminiMaliyet yalnız aynı bakım için açıkça TL verilmişse {{"min":0,"max":0}} olabilir.
Aynı aramada forum ve kullanıcı yorumlarında tekrarlanan şikâyetleri ayrıca
kullaniciSikayetleri listesine ekle. Her başlık tek konu olsun; en az iki farklı
alan adındaki kaynakta hem model adı hem konu açıkça geçsin. Kullanıcı beyanını
arıza teşhisi veya doğrulanmış sorun gibi sunma; şikâyetlere maliyet yazma.
Kullanıcı şikâyetlerinde herkese açık, dizine eklenen model sayfalarını tercih et:
araclo.com kronik sorun derlemeleri, sikayetvar.com, forum.donanimhaber.com,
technopat.net/sosyal ve arabalar.com.tr/blog. Yalnız kısa özet ve kaynak linki ver.
Her risk ve kullanıcı şikâyetine kategori ve onem ekle. kategori yalnız
mekanik_motor (motor, şanzıman, yakıt, soğutma, fren, süspansiyon), elektronik
(sensör, ADAS, multimedya, gösterge, anahtarsız giriş) veya trim_kasa
(trim sesi, far buğusu, kaplama, kapı/bagaj hizası, pas) olabilir.
onem yalnız yuksek, orta veya dusuk olabilir; büyük motor/şanzıman/triger,
turbo/pompa/soğutma masrafları yüksek; sensör/ADAS/süspansiyon orta;
trim, far buğusu ve multimedya donması düşük önemlidir. Yakıt türüne aykırı
parça veya sorun ekleme.
"""


# Kullanıcı şikâyetleri için ayrı Türkçe arama: tek aramanın 10 sonucu çoğunlukla
# İngilizce teknik sayfalardan geliyor, Türkçe forumlar hiç gelmiyordu (Tucson, 02.11.2026).
_COMPLAINT_PROMPT = """Türkiye'deki kullanıcıların şu araç için forumlarda ve şikâyet sitelerinde
en sık dile getirdiği kronik sorunları bul: {vehicle}.
Herkese açık sayfaları kullan: sikayetvar.com, forum.donanimhaber.com, technopat.net/sosyal,
araclo.com kronik sorun sayfaları, arabalar.com.tr ve otomobil kulübü forumları.
kronikmotor.com kullanma. Aynı konu en az iki farklı sitede geçsin; her konuda bu
sitelerin linklerini ver. Yalnız bu model ve motor/yakıt türüyle ilgili şikâyetleri yaz;
yakıt türüne aykırı parça yazma. Kullanıcı beyanını arıza teşhisi gibi sunma, maliyet yazma.
En fazla 6 konu, her başlık tek konu olsun.
Sadece JSON: {{"kullaniciSikayetleri":[{{"baslik":"", "aciklama":"Kullanıcı beyanlarının kısa özeti",
"kategori":"mekanik_motor", "onem":"orta", "kaynaklar":["https://..."]}}]}}.
kategori yalnız mekanik_motor, elektronik veya trim_kasa; onem yalnız yuksek, orta
veya dusuk (büyük motor/şanzıman/triger/turbo masrafı yüksek; sensör/ADAS/süspansiyon
orta; trim, far buğusu, multimedya düşük).
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
    # v4: ayrı Türkçe şikâyet araması eklendi; v3 kayıtlarında şikâyet adayı yok
    return "vehicle-risk:v5:" + hashlib.sha256(json.dumps(values).encode()).hexdigest()


def _search(query, client):
    """Emsal aramasıyla aynı OpenRouter web eklentisi ve sağlayıcı ayarları."""
    body = {"model": wmr.model_name(), "temperature": 0,
            "plugins": [{"id": "web", "max_results": 10}],
            "messages": [{"role": "user", "content": _PROMPT.format(vehicle=query)}],
            "usage": {"include": True}, **wmr._llm_limits()}
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
    complaints = parsed.get("kullaniciSikayetleri")
    return {"risks": parsed.get("riskler") or [],
            "complaints": complaints if isinstance(complaints, list) else [], "sources": sources,
            "cost": (data.get("usage") or {}).get("cost") or 0}


def _topics(text):
    text = fold(text)
    # Kısa "pas" sözcüğü Passat/paspas gibi adları kanıt saymamalı;
    # paslanma ve paslı çekimleri kendi açık kökleriyle eşleşir.
    return [key for key, terms in _TOPICS.items() if any(
        re.search(r"\b" + re.escape(fold(term)) + (r"\b" if term == "pas" else ""), text)
        for term in terms)]


def _gear(text):
    text = fold(text)
    return {label for label, pattern in {
        "manual": r"\b(manuel|manual)\b", "dsg": r"\b(dsg|s.tronic)\b",
        "cvt": r"\bcvt\b", "edc": r"\bedc\b", "dct": r"\bdct\b",
        "eat": r"\beat[68]\b"}.items() if re.search(pattern, text)}


def _incompatible(text, vehicle):
    if _fuel_incompatible(text, vehicle):
        return True
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


def _fuel_incompatible(text, vehicle):
    fuel, text = fold(vehicle.get("fuel")), fold(text)
    if fuel in ("elektrik", "elektrikli", "electric", "ev"):
        return bool(re.search(r"\b(motor yagi|engine oil|triger|timing belt|zincir|timing chain|sanziman yagi|transmission oil|egzoz|exhaust)\w*\b", text))
    diesel = "dizel" in fuel or "diesel" in fuel
    if diesel:
        # Kızdırma bujisi dizelde mevcuttur; ateşleme bujisiyle karıştırma.
        without_glow = re.sub(r"\b(kizdirma buj\w*|glow plugs?)\b", "", text)
        return bool(re.search(r"\b(buji\w*|spark plugs?|atesleme bobin\w*|ignition coils?)\b", without_glow))
    if any(term in fuel for term in ("benzin", "petrol", "gasoline", "hibrit", "hybrid", "lpg")):
        return bool(re.search(r"\b(adblue|dpf|dizel partikul)\b", text)
                    or ("dizel" in text and re.search(r"\b(enjektor|yakit) pompa\w*", text)))
    return False


def _domain(host, domains):
    host = host.lower().rstrip(".")
    return any(host == d or host.endswith("." + d) for d in domains)


def _confidence(url, text, vehicle):
    host = (urlsplit(url).hostname or "").lower()
    if (_domain(host, _USER_SOURCES + _COMPILATIONS)
            or any(word in host + urlsplit(url).path.lower() for word in ("forum", "club", "reddit", "community"))):
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
    details = " ".join(str(item.get(k) or "") for k in
                       ("baslik", "aciklama", "etkiledigi", "belirtiler", "kontrol"))
    if not topics or _fuel_incompatible(details, vehicle) or _incompatible(str(item.get("etkiledigi") or ""), vehicle):
        return None
    valid = {}
    for url in item.get("kaynaklar") or []:
        if not isinstance(url, str) or urlsplit(url).scheme not in ("https", "http"):
            continue
        if _domain(urlsplit(url).hostname or "", _BLOCKED):
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
    cost = _cost(item.get("tahminiMaliyet"), valid.values(), topics)
    category, severity = _classification(item, topics, cost)
    return {"baslik": item["baslik"], "aciklama": str(item.get("aciklama") or ""),
            "etkiledigi": str(item.get("etkiledigi") or "Kapsamı servisle doğrulayın"),
            "belirtiler": [s for s in item.get("belirtiler", []) if isinstance(s, str)]
            if isinstance(item.get("belirtiler"), list) else [],
            "kontrol": str(item.get("kontrol") or "Şasi numarası ve servis kaydıyla doğrulayın."),
            "tahminiMaliyet": cost, "kategori": category, "onem": severity,
            "kaynaklar": list(valid), "guven": confidence}


def _classification(item, topics, cost):
    keys = set(topics)
    category = item.get("kategori")
    if category not in ("mekanik_motor", "elektronik", "trim_kasa"):
        if keys & {"trim", "far_bugusu", "kaplama", "kasa"}:
            category = "trim_kasa"
        elif keys & {"sensor", "adas", "elektronik_unite", "multimedya", "anahtarsiz", "gosterge", "aku"}:
            category = "elektronik"
        else:
            category = "mekanik_motor"
    severity = item.get("onem")
    if severity not in ("yuksek", "orta", "dusuk"):
        if ((cost and cost["max"] >= 25000) or keys & {
                "motor", "sanziman", "mekatronik", "triger", "zincir", "yakit_pompasi",
                "yag_pompasi", "turbo", "sogutma"}):
            severity = "yuksek"
        elif keys & {"sensor", "adas", "elektronik_unite", "suspansiyon", "anahtarsiz", "gosterge"}:
            severity = "orta"
        else:
            severity = "dusuk"
    return category, severity


def _verified_items(items, sources, vehicle):
    output, seen = [], set()
    for item in items:
        verified = _verify(item, sources, vehicle)
        if verified and fold(verified["baslik"]) not in seen:
            output.append(verified)
            seen.add(fold(verified["baslik"]))
    return output


def _search_complaints(query, client):
    """Türkçe forum/şikâyet sitelerini hedefleyen ikinci arama (risk aramasıyla aynı anda)."""
    # Ölçüm (Tucson): DeepSeek+web eklentisi Türkçe forum getirmedi; Perplexity Sonar
    # şikayetvar, donanimhaber, araclo, forumarac sayfalarını 6 sn'de, 0,006 $'a buldu.
    body = {"model": _complaint_model(), "temperature": 0, "max_tokens": 2500,
            "messages": [{"role": "user", "content": _COMPLAINT_PROMPT.format(vehicle=query)}],
            "usage": {"include": True}}
    response = client.post(wmr._URL, headers={"Authorization": f"Bearer {os.getenv('OPENROUTER_API_KEY')}"}, json=body)
    response.raise_for_status()
    data = response.json()
    message = (data.get("choices") or [{}])[0].get("message") or {}
    # Sonar sayfa metni döndürmez; yalnız gerçekten dönen linkler ve başlıkları tutulur.
    cited = {}
    for annotation in message.get("annotations") or []:
        citation = annotation.get("url_citation") or {}
        if citation.get("url"):
            cited[citation["url"].rstrip("/")] = str(citation.get("title") or "")
    match = re.search(r"\{.*\}", message.get("content") or "", re.DOTALL)
    if not match:
        raise ValueError("Şikâyet aramasında JSON yok")
    parsed = json.loads(match.group())
    complaints = parsed.get("kullaniciSikayetleri") if isinstance(parsed, dict) else None
    return {"complaints": complaints if isinstance(complaints, list) else [], "cited": cited,
            "cost": (data.get("usage") or {}).get("cost") or 0}


def _search_seconds():
    """Model ve şikâyet aramalarının birlikte kesin üst sınırı (saniye)."""
    try:
        return max(1.0, float(os.getenv("WEB_RISK_SECONDS") or 60))
    except ValueError:
        return 60.0


def _complaint_model():
    return (os.getenv("WEB_COMPLAINT_MODEL") or "perplexity/sonar").strip()


def _tokens(text):
    return re.findall(r"[a-z0-9]+", fold(text))


def _verified_cited_complaints(items, cited, vehicle):
    """Sonar şikâyetleri: link aramada gerçekten dönmüş olmalı, linkte/başlıkta model adı
    geçmeli, en az 2 farklı kök alan adı. Sayfa metni olmadığından kullanıcı beyanıdır."""
    model_tokens = _tokens(vehicle.get("model"))
    if not model_tokens:
        return []
    output = []
    for item in items or []:
        if not isinstance(item, dict) or not isinstance(item.get("baslik"), str) or not item["baslik"].strip():
            continue
        details = " ".join(str(item.get(k) or "") for k in ("baslik", "aciklama"))
        if _fuel_incompatible(details, vehicle):
            continue
        urls = []
        for url in item.get("kaynaklar") or []:
            if not isinstance(url, str) or urlsplit(url).scheme not in ("https", "http"):
                continue
            url = url.rstrip("/")
            if url not in cited or _domain(urlsplit(url).hostname or "", _BLOCKED):
                continue
            hay = set(_tokens(unquote(urlsplit(url).path) + " " + cited[url]))
            if all(token in hay for token in model_tokens) and url not in urls:
                urls.append(url)
        count = len({_root_domain(url) for url in urls})
        if count < 2:
            continue
        topics = _topics(item["baslik"])
        category, severity = _classification(item, topics, None)
        output.append({"baslik": item["baslik"].strip(), "aciklama": str(item.get("aciklama") or ""),
                       "kaynaklar": urls, "kategori": category, "onem": severity, "kaynakSayisi": count})
    return output


def _merge_complaints(*lists):
    """Aynı konu tek madde; kaynaklar birleşir, kaynak sayısı yeniden hesaplanır; en fazla 5."""
    merged = {}
    for entry in (e for group in lists for e in group):
        topics = _topics(entry["baslik"])
        key = topics[0] if topics else fold(entry["baslik"])
        if key in merged:
            target = merged[key]
            target["kaynaklar"] += [u for u in entry["kaynaklar"] if u not in target["kaynaklar"]]
            target["kaynakSayisi"] = len({_root_domain(u) for u in target["kaynaklar"]})
        else:
            merged[key] = dict(entry, kaynaklar=list(entry["kaynaklar"]))
    return sorted(merged.values(), key=lambda e: e["kaynakSayisi"], reverse=True)[:5]


def _root_domain(url):
    """Alt alan adları bağımsız kaynak sayılmaz; com.tr/co.uk de birlikte kalır."""
    host = (urlsplit(url).hostname or "").lower().rstrip(".")
    labels = host.split(".")
    country_suffix = (len(labels) >= 3 and len(labels[-1]) == 2
                      and labels[-2] in {"com", "co", "org", "net", "gov", "ac", "edu"})
    return ".".join(labels[-3:] if country_suffix else labels[-2:])


def _verified_complaints(items, sources, vehicle):
    """Yalnız kaynak metniyle desteklenen, bağımsız alanlarda tekrarlanan konular."""
    model = fold(vehicle.get("model")).strip()
    model_pattern = r"(?<!\w)" + re.escape(model) + r"(?!\w)"
    groups = {}
    for item in items:
        verified = _verify(item, sources, vehicle)
        if not verified:
            continue
        topic = _topics(verified["baslik"])[0]
        group = groups.setdefault(topic, {"baslik": verified["baslik"],
                                          "aciklama": verified["aciklama"], "kaynaklar": [],
                                          "kategori": verified["kategori"], "onem": verified["onem"]})
        for url in verified["kaynaklar"]:
            text = sources[url]
            if (model and re.search(model_pattern, fold(text)) and topic in _topics(text)
                    and _root_domain(url) and url not in group["kaynaklar"]):
                group["kaynaklar"].append(url)
    output = []
    for group in groups.values():
        count = len({_root_domain(url) for url in group["kaynaklar"]})
        if count >= 2:
            output.append({**group, "kaynakSayisi": count})
    return sorted(output, key=lambda entry: entry["kaynakSayisi"], reverse=True)[:5]


def get_model_risks(vehicle) -> dict:
    """Tek arama; opsiyonel 30 günlük DB önbelleği, arıza teşhisi değildir."""
    result = {"riskler": [], "kullaniciSikayetleri": [], "bulunamadi": True,
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
            complaints = cached.pop("_complaint_candidates", [])
            cited_complaints = cached.pop("_cited_complaints", [])
            cited = cached.pop("_cited", {})
            sources = cached.pop("_sources", {})
            cached["riskler"] = _verified_items(candidates, sources, vehicle)
            cached["kullaniciSikayetleri"] = _merge_complaints(
                _verified_complaints(complaints, sources, vehicle),
                _verified_cited_complaints(cited_complaints, cited, vehicle))
            cached["bulunamadi"] = not bool(cached["riskler"])
            return cached
    errors = (httpx.HTTPError, ValueError, TypeError, KeyError, RuntimeError)
    query = wmr._vehicle_text({**vehicle, "km": None}) + " " + str(vehicle.get("engine") or "")
    complaint_query = " ".join(str(p) for p in (vehicle.get("brand"), vehicle.get("model"),
                                                vehicle.get("engine") or vehicle.get("package")) if p)
    complaint_query += " kronik sorun şikayet"
    # İki arama bağımsızdır: biri düşer ya da süreyi aşarsa diğerinin sonucu kullanılır.
    # (Ölçüm: geçici bir risk araması hatası, başarılı şikâyetleri de siliyordu.)
    client = httpx.Client(timeout=90.0)
    pool = ThreadPoolExecutor(2)
    try:
        risk_future = pool.submit(_search, query, client)
        complaint_future = pool.submit(_search_complaints, complaint_query, client)
        done, _pending = wait([risk_future, complaint_future], timeout=_search_seconds())

        def take(future, label, empty):
            if future not in done:
                logger.warning("[MODEL RISK] %s araması %.0f sn içinde bitmedi", label, _search_seconds())
                return empty, False
            try:
                return future.result(), True
            except errors as exc:
                logger.warning("[MODEL RISK] %s araması başarısız: %s", label, str(exc)[:200])
                return empty, False

        found, risks_ok = take(risk_future, "Risk", {"risks": [], "complaints": [], "sources": {}, "cost": 0})
        extra, complaints_ok = take(complaint_future, "Şikâyet", {"complaints": [], "cited": {}, "cost": 0})
    finally:
        client.close()  # süren istekleri keser
        pool.shutdown(wait=False, cancel_futures=True)
    if not risks_ok and not complaints_ok:
        return result
    try:
        cost = float(found.get("cost") or 0) + float(extra.get("cost") or 0)
        result["scope"].update(searches=2, cost_usd=cost, complaint_model=_complaint_model())
        result["riskler"] = _verified_items(found.get("risks") or [], found.get("sources") or {}, vehicle)
        result["kullaniciSikayetleri"] = _merge_complaints(
            _verified_complaints(found.get("complaints") or [], found.get("sources") or {}, vehicle),
            _verified_cited_complaints(extra.get("complaints") or [], extra.get("cited") or {}, vehicle))
        result["bulunamadi"] = not bool(result["riskler"])
    except errors as exc:
        logger.warning("[MODEL RISK] Sonuç işlenemedi: %s", str(exc)[:200])
        return result
    # Başarıyla tamamlanan boş sonuç da aynı modelde yeniden arama maliyetini önler.
    # Aramalardan biri düştüyse önbelleğe yazılmaz (30 gün eksik sonuçla kalınmasın).
    if days and risks_ok and complaints_ok:
        wmr._cache_write(key, {**result, "_candidates": found.get("risks") or [],
                               "_complaint_candidates": found.get("complaints") or [],
                               "_cited_complaints": extra.get("complaints") or [],
                               "_cited": extra.get("cited") or {},
                               "_sources": found.get("sources") or {}})
    return result


def _risk_items(risks):
    items = risks.get("riskler", []) if isinstance(risks, dict) else risks
    return [r for r in (items or []) if isinstance(r, dict)]


GENEL_BAKIM_KONTROLU = "Tarih, kilometre ve servis faturalarını karşılaştırın."


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
                       "aciklama": f"{title}: {km:,} km ve {age} yaşındaki araçta son yapıldığı tarih ve kilometreyi doğrulayın; üreticinin araç sürümüne özel bakım planını esas alın.".replace(",", "."),
                       "kontrol": entry.get("kontrol") or GENEL_BAKIM_KONTROLU})
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
