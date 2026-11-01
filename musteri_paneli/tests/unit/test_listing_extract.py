"""Ağsız ilan çıkarımı: model beyanı kaynak değildir."""
import json
from copy import deepcopy

import httpx
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from yerimebak_ai_v5.services import listing_extract as extract, valuation_service as valuation
from yerimebak_ai_v5.services import web_market_reference as web
from yerimebak_ai_v5.api.v1.endpoints import valuation as endpoint

URL = "https://www.arabam.com/ilan/renault-clio-2019/123"
TEXT = "Renault Clio Touch 2019 model, 85.000 km, 950.000 TL, Benzin, Otomatik, Ankara."
DATA = dict(brand="Renault", model="Clio", package="Touch", year=2019, km=85000,
            price=950000, fuel="Benzin", transmission="Otomatik", location="Ankara")


@pytest.fixture(autouse=True)
def offline(monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-fake")
    monkeypatch.setattr(web, "_cache_read", lambda *a: None)
    monkeypatch.setattr(web, "_cache_write", lambda *a: None)
    monkeypatch.setattr(valuation, "_listing_by_url", lambda url: None)
    monkeypatch.setattr(valuation, "_known_brands", lambda: ["Renault"])
    monkeypatch.setattr(valuation, "_known_models", lambda brand: ["Clio"])
    def no_network(*a, **kw):
        raise AssertionError("Testte gerçek ağ çağrısı yasak")
    monkeypatch.setattr(httpx.HTTPTransport, "handle_request", no_network)


def test_verified_fields_and_legacy_shape(monkeypatch):
    calls = []
    def search(query, client, **kw):
        calls.append((query, kw))
        return {"data": DATA, "sources": {URL + "?utm=a": TEXT}, "cost": .009}
    monkeypatch.setattr(web, "_search", search)
    result = valuation.prefill_from_link(URL)
    assert len(calls) == 1 and calls[0][1]["web"] is True
    assert result["vehicle"] == DATA
    assert result["parts"] == {}
    assert result["verified_count"] == len(DATA)
    assert all(f["dogrulandi"] and f["kaynak"] == "ilan_sayfasi" for f in result["fields"].values())


def test_hallucinated_fields_rejected(monkeypatch):
    monkeypatch.setattr(web, "_search", lambda *a, **k: {
        "data": {**DATA, "price": 1500000, "km": 8500, "location": "İzmir"}, "sources": {URL: TEXT}})
    result = valuation.prefill_from_link(URL)
    assert "price" not in result["vehicle"]
    assert "km" not in result["vehicle"]
    assert "location" not in result["fields"]
    assert result["fields"]["year"]["dogrulandi"]


@pytest.mark.parametrize("sources", [{}, {URL + "4": TEXT}, {"https://evil.test/ilan/123": TEXT}])
def test_other_url_not_evidence(monkeypatch, sources):
    monkeypatch.setattr(web, "_search", lambda *a, **k: {"data": DATA, "sources": sources})
    result = valuation.prefill_from_link(URL)
    assert result["vehicle"] == {"brand": "Renault", "model": "Clio"}
    assert not any(f["dogrulandi"] for f in result["fields"].values())


def test_text_numbers_and_parts_need_evidence(monkeypatch):
    text = TEXT + " Sol Ön Kapı boyalı. Tavan değişen yok. Tramer 12.000 TL. 2 parça boyalı."
    data = {**DATA, "price": 1234567, "tramer_amount": 12000, "painted_count": 2,
            "parts": {"solOnKapi": "boyali", "tavan": "degisen", "kaput": "boyali"},
            "evidence": {"parts.solOnKapi": "Sol Ön Kapı boyalı", "parts.tavan": "Tavan değişen yok",
                         "parts.kaput": "Motor Kaputu boyalı", "tramer_amount": "Tramer 12.000 TL",
                         "painted_count": "2 parça boyalı"}}
    def search(query, client, **kw):
        assert kw["web"] is False and query == text
        return {"data": data, "cost": .001}
    monkeypatch.setattr(web, "_search", search)
    result = extract.from_text(text)
    assert "price" not in result["vehicle"]
    assert result["vehicle"]["tramer_amount"] == 12000
    assert result["vehicle"]["painted_count"] == 2
    assert result["parts"] == {"solOnKapi": "boyali"}
    assert all(v["kaynak"] == "ilan_metni" for v in result["fields"].values())


@pytest.mark.parametrize("text,value,expected", [("1.950.000 TL", 950000, False), ("1950000", 950000, False),
    ("950.000 TL", 950000, True), ("950,000 TL", 950000, True), ("950 000 TL", 950000, True),
    ("2019 model", 2019, True), ("12019 km", 2019, False), ("85000.50", 85000, False),
    # sahibinden kopyasında etiket ve değer bitişik gelir
    ("Yıl2024", 2024, True), ("KM24.000", 24000, True), ("Yıl2024", 24, False), ("Model1.5 PHEV", 1, False),
    ("KM 24.000.", 24000, True)])
def test_numeric_boundaries(text, value, expected):
    assert extract.numeric_in_text(value, text) is expected


def test_cache_skips_second_search(monkeypatch):
    cache, calls = {}, []
    monkeypatch.setattr(web, "_cache_read", lambda key, hours: deepcopy(cache.get(key)))
    monkeypatch.setattr(web, "_cache_write", lambda key, value: cache.update({key: deepcopy(value)}))
    def search(*a, **kw):
        calls.append(1)
        return {"data": DATA, "sources": {URL: TEXT}}
    monkeypatch.setattr(web, "_search", search)
    assert extract.from_link(URL)["vehicle"] == DATA
    assert extract.from_link(URL.replace("www.", "") + "?utm=1")["vehicle"] == DATA
    assert calls == [1]


def test_part_cannot_borrow_another_part_status():
    text = "Sol Ön Kapı boyalı, Tavan değişen."
    data = {"parts": {"solOnKapi": "degisen", "tavan": "boyali"},
            "evidence": {"parts.solOnKapi": text, "parts.tavan": text}}
    assert extract.verify(data, text, "ilan_metni") == {}


@pytest.mark.parametrize("text", ["Tavan değişmedi", "Tavan değişmeyen", "Tavan değişensiz", "Tavan değişmiş değildir"])
def test_negative_damage_not_verified(text):
    data = {"parts": {"tavan": "degisen"}, "evidence": {"parts.tavan": text}}
    assert extract.verify(data, text, "ilan_metni") == {}


def test_common_part_name_alias():
    text = "Kaput boyalı"
    data = {"parts": {"kaput": "boyali"}, "evidence": {"parts.kaput": text}}
    assert extract.verify(data, text, "ilan_metni")["parts.kaput"]["deger"] == "boyali"


def test_failed_search_keeps_only_brand_model_guess(monkeypatch):
    def failed(*args, **kwargs):
        raise httpx.TimeoutException("offline")
    monkeypatch.setattr(web, "_search", failed)
    result = valuation.prefill_from_link(URL)
    assert result["vehicle"] == {"brand": "Renault", "model": "Clio"}
    assert result["verified_count"] == 0


def test_url_numbers_are_not_page_evidence():
    assert extract.verify({"year": 2019}, URL, "ilan_sayfasi") == {}


def test_no_key_preserves_old_slug(monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", "")
    result = valuation.prefill_from_link(URL)
    assert result["vehicle"] == {"brand": "Renault", "model": "Clio", "year": 2019}
    assert result["verified_count"] == 0
    assert all(not f["dogrulandi"] for f in result["fields"].values())
    assert extract.from_text(TEXT)["vehicle"] == {}


def test_shared_openrouter_transport_has_no_plugin_for_text(monkeypatch):
    real_client = httpx.Client
    bodies = []
    def handle(req):
        assert str(req.url) == web._URL
        body = json.loads(req.content)
        bodies.append(body)
        return httpx.Response(200, json={"choices": [{"message": {"content": json.dumps(DATA)}}], "usage": {"cost": .001}})
    monkeypatch.setattr(httpx, "Client", lambda **kw: real_client(transport=httpx.MockTransport(handle), **kw))
    result = extract.from_text(TEXT)
    assert result["vehicle"] == DATA
    assert "plugins" not in bodies[0]
    assert bodies[0]["model"] == web.model_name()


@pytest.fixture
def api(monkeypatch):
    app = FastAPI()
    app.include_router(endpoint.router, prefix="/valuation")
    app.dependency_overrides[endpoint.get_current_user] = lambda: {"id": "customer"}
    return TestClient(app)


def test_endpoints_daily_limit_and_payload(api, monkeypatch):
    consumed = []
    def consume(uid):
        consumed.append(uid)
        return len(consumed) <= 20
    monkeypatch.setattr(extract, "consume_daily", consume)
    monkeypatch.setattr(extract, "from_text", lambda t: extract.response({}))
    monkeypatch.setattr(valuation, "prefill_from_link", lambda u: extract.response({}, u))
    for i in range(20):
        r = api.post('/valuation/prefill-text', json={"text": TEXT}) if i % 2 else api.get('/valuation/prefill', params={"url": URL})
        assert r.status_code == 200
    assert api.get('/valuation/prefill', params={"url": URL}).status_code == 429
    assert api.post('/valuation/prefill-text', json={"text": TEXT}).status_code == 429
    assert api.post('/valuation/prefill-text', json={"text": "a" * 8001}).status_code == 422
    assert api.post('/valuation/prefill-text', json={"text": "  "}).status_code == 422
    assert len(consumed) == 22


def test_both_endpoints_require_login():
    app = FastAPI()
    app.include_router(endpoint.router, prefix="/valuation")
    with TestClient(app) as client:
        assert client.get('/valuation/prefill', params={"url": URL}).status_code == 401
        assert client.post('/valuation/prefill-text', json={"text": TEXT}).status_code == 401
