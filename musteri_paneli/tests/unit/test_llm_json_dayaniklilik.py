"""Gerçek okuma yolları: bozuk model yanıtları ve doğrulama sınırları (ağ yok)."""
import json

import httpx
import pytest

from yerimebak_ai_v5.services import ai_price_estimate, listing_extract, vehicle_generation, vehicle_risk
from yerimebak_ai_v5.services import web_market_reference as wmr


ARAC = {"brand": "Sentetik", "model": "Deneme", "year": 2023, "km": 30000}
DURUMLAR = ("kesik", "virgul_eksik", "kod_blok", "json_yok")


@pytest.fixture(autouse=True)
def yalniz_sahte_ag(monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-fake")
    monkeypatch.setenv("WEB_PRICE_CACHE_HOURS", "0")
    monkeypatch.setenv("PYTHON_DOTENV_DISABLED", "1")
    monkeypatch.setenv("SECRET_KEY", "test")
    monkeypatch.setenv("AI_PRICE_ESTIMATE", "on")


def yanit(durum, data, liste=None):
    tam = json.dumps(data, ensure_ascii=False)
    if durum == "json_yok":
        return "Bu sentetik araç hakkında veri bulunamadı."
    if durum == "kod_blok":
        return "Sonuç:\n```json\n" + tam + "\n```"
    if liste:
        onceki = {k: v for k, v in data.items() if k != liste}
        bas = json.dumps(onceki, ensure_ascii=False)[:-1]
        bas += (", " if onceki else "") + json.dumps(liste) + ": ["
        maddeler = [json.dumps(x, ensure_ascii=False) for x in data[liste]]
        if durum == "kesik":
            return bas + ", ".join(maddeler) + ', {"yarim": "kes'
        return bas + " ".join(maddeler) + "]}"
    if durum == "kesik":
        return tam[:-1] + ', "yarim": "kes'
    return tam.replace(",", "", 1)


def transport(content, sources=None):
    def handle(request):
        assert request.url.host == "openrouter.ai"
        assert request.headers["Authorization"] == "Bearer test-fake"
        return httpx.Response(200, json={"choices": [{"message": {
            "content": content,
            "annotations": [{"url_citation": {"url": u, "content": t}} for u, t in (sources or {}).items()],
        }}], "usage": {"cost": 0.012}})
    return httpx.MockTransport(handle)


@pytest.mark.parametrize("durum", DURUMLAR)
def test_risk_search_bozuk_yanit(durum):
    riskler = [{"baslik": "Sentetik turbo", "kaynaklar": ["https://example.org/risk"]},
               {"baslik": "Sentetik fren", "kaynaklar": ["https://example.org/fren"]}]
    text = yanit(durum, {"riskler": riskler}, "riskler")
    with httpx.Client(transport=transport(text)) as client:
        if durum == "json_yok":
            # Alt okuyucunun hatası üst risk toplama katmanında veri yoka çevrilir.
            with pytest.raises(ValueError):
                vehicle_risk._search("sentetik araç", client)
        else:
            result = vehicle_risk._search("sentetik araç", client)
            assert result["risks"] == riskler
            assert result["cost"] == 0.012


def ilanlar():
    return [{"url": f"https://www.arabam.com/ilan/sentetik/{i}", "fiyat_tl": fiyat,
             "km": km, "yil": 2023, "kondisyon": "temiz"}
            for i, (fiyat, km) in enumerate(((1000000, 30000), (1020000, 30000), (1040000, 30000),
                                            (1060000, 30000), (1080000, 30000),
                                            (1500000, 30000), (1010000, 300000), (1030000, 30000)))]


@pytest.mark.parametrize("durum", DURUMLAR)
def test_web_search_kurtarma_dogrulamayi_atlamaz(durum):
    items = ilanlar()
    sources = {i["url"]: f"Sentetik Deneme {i['fiyat_tl']} TL" for i in items}
    sources[items[-1]["url"]] = "Sentetik Deneme fiyat belirtilmemiş"
    text = yanit(durum, {"ilanlar": items}, "ilanlar")
    with httpx.Client(transport=transport(text, sources)) as client:
        result = wmr._search("sentetik araç", client)
    assert result["cost"] == 0.012
    if durum == "json_yok":
        assert result["listings"] == [] and result["data"] == {}
        return
    assert result["listings"] == items
    reference = wmr.build_reference([result], ARAC)
    assert reference["found"] is True
    assert reference["count"] == 5
    assert {s["url"] for s in reference["samples"]} == {i["url"] for i in items[:5]}
    assert reference["scope"]["rejected"]["km uzak"] == 1
    assert reference["scope"]["rejected"]["fiyat sayfada yok"] == 1
    # Kurtarma az emsalle fiyat üretme eşiğini de gevşetmez.
    az_emsal = wmr.build_reference([{**result, "listings": result["listings"][:2]}], ARAC)
    assert az_emsal["found"] is False
    assert az_emsal["reason"] == "not_enough_web_listings"


@pytest.mark.parametrize("durum", DURUMLAR)
def test_generation_search_bozuk_yanit(durum):
    source = "https://example.org/nesiller"
    nesiller = [{"kasa": "TEST1", "baslangic": 2020, "bitis": 2026, "makyaj": None},
                {"kasa": "GECERSIZ", "baslangic": 2026, "bitis": 2020, "makyaj": None}]
    text = yanit(durum, {"kaynaklar": [source], "nesiller": nesiller}, "nesiller")
    with httpx.Client(transport=transport(text, {source: "Sentetik kasa kaynağı"})) as client:
        result = vehicle_generation._search(ARAC, client)
    assert result["cost"] == 0.012
    if durum == "json_yok":
        assert result["data"] == {}
        assert vehicle_generation.parse_list(result["data"], result["cited"]) == []
    else:
        assert result["data"]["nesiller"] == nesiller
        assert vehicle_generation.parse_list(result["data"], result["cited"]) == nesiller[:1]
        assert vehicle_generation.parse_list(result["data"], {}) == []


@pytest.mark.parametrize("durum", DURUMLAR)
def test_ai_fiyat_estimate_bozuk_yanit(durum):
    text = yanit(durum, {"medyan": 1000000, "min": 900000, "max": 1100000, "veri_tarihi": "2026-11"})
    result = ai_price_estimate.estimate(ARAC, transport=transport(text))
    if durum == "json_yok":
        assert result is None
    else:
        assert result["median"] == 1000000
        assert result["min"] == 900000
        assert result["max"] == 1100000


@pytest.mark.parametrize("durum", DURUMLAR)
def test_listing_extract_prefill_bozuk_yanit(durum, monkeypatch):
    text = yanit(durum, {"brand": "Sentetik", "model": "Deneme", "year": 2023,
                        "price": 1000000, "km": 999999})
    original_client = httpx.Client
    monkeypatch.setattr(wmr.httpx, "Client", lambda **kw: original_client(transport=transport(text), **kw))
    # Etiket okuyucu devreye girmez; modelin doğrulanmayan km iddiası reddedilir.
    result = listing_extract.from_text("Sentetik Deneme 2023 yılı araç, fiyat 1.000.000 TL.")
    if durum == "json_yok":
        assert result["found"] is False and result["vehicle"] == {}
    else:
        assert result["found"] is True
        assert result["vehicle"] == {"brand": "Sentetik", "model": "Deneme", "year": 2023, "price": 1000000}
        assert result["fields"]["price"]["dogrulandi"] is True
