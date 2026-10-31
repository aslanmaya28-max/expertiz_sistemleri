# -*- coding: utf-8 -*-
"""Musteri ilan linki: kaynak tespiti, kisa link cozumu, linkten arac tahmini (agsiz, veritabanisiz)."""
import httpx
import pytest

from yerimebak_ai_v5.services import listing_links, valuation_service

SAHIBINDEN = "https://www.sahibinden.com/ilan/vasita-otomobil-renault-clio-1.0-tce-touch-2019-1234567890/detay"


@pytest.mark.parametrize("url,source,fetch", [
    ("https://www.arabam.com/ilan/galeriden-satilik-renault-clio/x/123", "arabam", True),
    ("arabam.com/ilan/x/1", "arabam", True),
    (SAHIBINDEN, "sahibinden", False),
    ("https://shbd.io/s/JxlAmKg0", "sahibinden", False),
    ("https://example.com/ilan/1", None, False),
    ("https://arabam.com.evil.example/ilan/1", None, False),
])
def test_link_source(url, source, fetch):
    assert listing_links.link_source(url) == source
    assert listing_links.can_fetch(url) is fetch


@pytest.fixture
def fake_http(monkeypatch):
    calls = []
    real = httpx.Client

    def install(handler):
        def handle(request):
            calls.append(str(request.url))
            return handler(request)
        monkeypatch.setattr(listing_links.httpx, "Client", lambda **kw: real(transport=httpx.MockTransport(handle), **kw))
        return calls
    return install


def test_short_link_resolves_without_visiting_target(fake_http):
    calls = fake_http(lambda req: httpx.Response(301, headers={"location": SAHIBINDEN}))
    assert listing_links.resolve_short_link("https://shbd.io/s/JxlAmKg0") == SAHIBINDEN
    assert calls == ["https://shbd.io/s/JxlAmKg0"]  # sahibinden.com'a istek atilmadi


def test_short_link_failure_keeps_original(fake_http):
    fake_http(lambda req: httpx.Response(200, text="<html>yonlendirme yok</html>"))
    assert listing_links.resolve_short_link("https://shbd.io/s/abc") == "https://shbd.io/s/abc"

    def boom(req):
        raise httpx.ConnectError("ag yok")
    fake_http(boom)
    assert listing_links.resolve_short_link("https://shbd.io/s/abc") == "https://shbd.io/s/abc"


@pytest.fixture
def catalog(monkeypatch):
    models = {"Renault": ["Clio", "Megane"], "Peugeot": ["2008", "308"], "BMW": ["3 Serisi", "5 Serisi"]}
    monkeypatch.setattr(valuation_service, "_known_brands", lambda: list(models))
    monkeypatch.setattr(valuation_service, "_known_models", lambda brand: models.get(brand, []))


@pytest.mark.parametrize("url,expected", [
    (SAHIBINDEN, {"brand": "Renault", "model": "Clio", "year": 2019}),
    # Model adindaki sayi yil sanilmaz
    ("https://www.sahibinden.com/ilan/vasita-otomobil-peugeot-2008-1.2-puretech-allure-2021-1122334455/detay",
     {"brand": "Peugeot", "model": "2008", "year": 2021}),
    ("https://www.sahibinden.com/ilan/vasita-otomobil-bmw-3-serisi-320i-1099887766/detay",
     {"brand": "BMW", "model": "3 Serisi"}),
    ("https://shbd.io/s/JxlAmKg0", {}),
])
def test_guess_from_slug(catalog, url, expected):
    assert valuation_service._guess_from_slug(url) == expected


def test_prefill_sahibinden_short_link_skips_apify(catalog, monkeypatch):
    monkeypatch.setattr(listing_links, "resolve_short_link", lambda url, **kw: SAHIBINDEN)
    monkeypatch.setattr(valuation_service, "_listing_by_url", lambda url: None)

    from yerimebak_ai_v5.services import apify_service, market_ingest

    def no_apify(*a, **kw):
        raise AssertionError("sahibinden linki icin Apify calistirilmamali")
    monkeypatch.setattr(apify_service, "run_actor", no_apify)
    monkeypatch.setattr(market_ingest, "fetch_listing", no_apify)

    res = valuation_service.prefill_from_link("https://shbd.io/s/JxlAmKg0")
    assert res["found"] is False and res["source"] == "sahibinden"
    assert res["url"] == valuation_service.normalize_url(SAHIBINDEN)
    assert res["vehicle"] == {"brand": "Renault", "model": "Clio", "year": 2019}
    assert "Sahibinden" in res["message"]


def test_fetch_listing_skips_non_arabam(monkeypatch):
    from yerimebak_ai_v5.services import apify_service, market_ingest

    monkeypatch.setattr(apify_service, "enabled", lambda: True)
    monkeypatch.setattr(apify_service, "run_actor", lambda *a, **kw: (_ for _ in ()).throw(AssertionError("calismamali")))
    assert market_ingest.fetch_listing(SAHIBINDEN) is None


# shbd.io canli denemede (2026-10) sahibinden'in kendi kisa adresine 301 ile yonlendirdi
SITE_SHORT = "https://www.sahibinden.com/s/JxlAmKg0"


def test_shbd_redirects_to_site_short_link(fake_http):
    calls = fake_http(lambda req: httpx.Response(301, headers={"location": SITE_SHORT}))
    assert listing_links.resolve_short_link("https://shbd.io/s/JxlAmKg0") == SITE_SHORT
    assert calls == ["https://shbd.io/s/JxlAmKg0"]  # sahibinden.com'a gidilmedi
    assert listing_links.is_site_short_link(SITE_SHORT)
    assert not listing_links.is_site_short_link(SAHIBINDEN)
    assert not listing_links.is_site_short_link("https://shbd.io/s/JxlAmKg0")


def test_prefill_site_short_link_asks_full_link(catalog, monkeypatch):
    monkeypatch.setattr(listing_links, "resolve_short_link", lambda url, **kw: SITE_SHORT)
    monkeypatch.setattr(valuation_service, "_listing_by_url", lambda url: None)
    res = valuation_service.prefill_from_link("https://shbd.io/s/JxlAmKg0")
    assert res["found"] is False and res["source"] == "sahibinden"
    assert res["vehicle"] == {}
    assert "tam adresini" in res["message"]
