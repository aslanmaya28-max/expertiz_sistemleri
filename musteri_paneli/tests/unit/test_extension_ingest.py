# -*- coding: utf-8 -*-
"""Chrome eklentisinin gonderdigi arabam.com sayfalarinin ayristirilmasi ve kaydi (veritabanisiz)."""
import asyncio

import pytest
from fastapi import HTTPException

from yerimebak_ai_v5.services import extension_ingest

LISTING_URL = "https://www.arabam.com/ilan/galeriden-satilik-renault-clio-1-0-tce-touch/temiz-arac/28123456"

# arabam.com ilan sayfasinin tarayicidaki metni (document.body.innerText), kisaltilmis
LISTING_TEXT = """arabam.com
Renault Clio 1.0 TCe Touch
985.000 TL
İlan No
28123456
İlan Tarihi
12 Ekim 2026
Marka
Renault
Seri
Clio
Model
1.0 TCe Touch
Yıl
2021
Kilometre
48.500 km
Vites Tipi
Manuel
Yakıt Tipi
Benzin
Renk
Beyaz
Boya, Değişen ve Tramer
Orijinal
Boyalı
Lokal boyalı
Değişmiş
Belirtilmemiş
Boyalı
Motor Kaputu
Değişmiş
Ön Tampon
Tramer tutarı
12.500 TL
Ağır Hasar Kayıtlı
Hayır
"""


def test_parse_listing_page_reads_identity_paint_and_damage():
    item = extension_ingest.parse_listing_page(
        LISTING_URL, LISTING_TEXT, title="Renault Clio 1.0 TCe Touch | arabam.com",
        image_url="https://arbstorage.mncdn.com/x.jpg", location="İstanbul, Kadıköy",
    )
    assert (item["brand"], item["model"], item["package"], item["year"]) == ("Renault", "Clio", "1.0 TCe Touch", 2021)
    assert item["km"] == 48500 and item["price"] == 985000  # tramer tutari fiyat sanilmaz
    assert (item["fuel"], item["transmission"], item["color"]) == ("Benzin", "Manuel", "Beyaz")
    assert item["listing_date"] == "2026-10-12"
    assert item["paint_info"]["painted_parts"] == ["Motor Kaputu"]
    assert item["paint_info"]["changed_parts"] == ["Ön Tampon"]
    assert item["damage_record"]["tramer_tl"] == 12500 and item["damage_record"]["agir_hasar"] is False
    assert item["accident_record"] == "Tramerli: 12500 TL"
    assert item["location"] == "İstanbul, Kadıköy" and item["title"] == "Renault Clio 1.0 TCe Touch"


def test_parse_listing_page_without_paint_section_is_unknown():
    text = "Marka\nFiat\nSeri\nEgea\nYıl\n2020\n650.000 TL"
    item = extension_ingest.parse_listing_page(LISTING_URL, text)
    assert item["paint_info"] is None  # beyan yoksa orijinal sayilmaz
    assert item["price"] == 650000 and item["model"] == "Egea"


def test_parse_listing_page_prefers_structured_data():
    ld = [{"@type": "Car", "brand": {"name": "Fiat"}, "model": "Egea", "mileageFromOdometer": {"value": "75000"},
           "offers": {"price": "720000"}, "image": ["https://img/1.jpg"]}]
    item = extension_ingest.parse_listing_page(LISTING_URL, "Yıl\n2019", structured=ld)
    assert (item["brand"], item["model"], item["km"], item["price"]) == ("Fiat", "Egea", 75000, 720000)
    assert item["image_url"] == "https://img/1.jpg"


def test_parse_search_page_cards():
    page = "https://www.arabam.com/ikinci-el/otomobil/renault-clio"
    cards = [
        {"url": "/ilan/sahibinden-satilik-renault-clio-1-5-dci-joy/aciklama/28000001",
         "text": "Clio 1.5 dCi Joy\nSahibinden temiz Clio\n2019\n85.000\nBeyaz\n815.000 TL\n10 Ekim 2026\nAnkara"},
        {"url": "/ilan/galeriden-satilik-renault-clio-1-0-tce-touch/x/28000002",
         "text": "Clio 1.0 TCe Touch\n2021\n32.000 km\n1.050.000 TL"},
        {"url": "/ilan/galeriden-satilik-renault-clio-1-0-tce-touch/x/28000002", "text": "tekrar 1.050.000 TL"},
        {"url": "https://www.sahibinden.com/ilan/x", "text": "500.000 TL"},
        {"url": "/ilan/fiyatsiz/28000003", "text": "Fiyat sorunuz"},
    ]
    items = extension_ingest.parse_search_page(page, cards, "Renault", "Clio")
    assert [i["url"][-8:] for i in items] == ["28000001", "28000002"]
    assert (items[0]["year"], items[0]["km"], items[0]["price"]) == (2019, 85000, 815000)
    assert (items[1]["year"], items[1]["km"], items[1]["price"]) == (2021, 32000, 1050000)
    assert items[0]["brand"] == "Renault" and items[0]["paint_info"] is None


def test_parse_search_table_row_with_tabs():
    # Tarayicida tablo satirinin innerText'i hucreleri sekmeyle ayirir
    item = extension_ingest.parse_search_card(
        "https://www.arabam.com/ilan/a/b/1", "Clio\t1.5 dCi Joy Sahibinden\t2019\t85.000\tBeyaz\t815.000 TL\tAnkara",
        "Renault", "Clio")
    assert (item["year"], item["km"], item["price"]) == (2019, 85000, 815000)
    assert item["title"] == "1.5 dCi Joy Sahibinden"


def test_url_checks():
    assert extension_ingest.is_listing_url(LISTING_URL)
    assert not extension_ingest.is_listing_url("https://www.arabam.com/ikinci-el/otomobil")
    assert not extension_ingest.is_arabam_url("https://arabam.com.evil.example/ilan/1")
    assert not extension_ingest.is_arabam_url("javascript:alert(1)")


# ---------------------------------------------------------------------------
# Uc noktalar
# ---------------------------------------------------------------------------

@pytest.fixture()
def endpoints(monkeypatch):
    from yerimebak_ai_v5.api.v1.endpoints import extension
    from yerimebak_ai_v5.services import market_ingest

    users = {"yk-admin": {"id": 1, "role": "admin", "credits": 0},
             "yk-staff": {"id": 2, "role": "personel", "credits": 0},
             "yk-customer": {"id": 3, "role": "user", "credits": 5}}

    class Auth:
        def verify_api_key(self, key):
            return users.get(key)

    saved = []

    def upsert(items, status):
        rows = [{**it, "id": 100 + len(saved) + i, "status": status} for i, it in enumerate(items)]
        saved.extend(rows)
        return rows

    monkeypatch.setattr(extension, "get_auth_service", lambda: Auth())
    monkeypatch.setattr(market_ingest, "upsert_listings", upsert)
    return extension, saved


def test_listing_endpoint_saves_for_staff(endpoints):
    extension, saved = endpoints
    req = extension.ExtensionListingPage(url=LISTING_URL, text=LISTING_TEXT)
    out = asyncio.run(extension.extension_save_listing(req, api_key="yk-staff"))
    assert out["success"] and saved[0]["status"] == "talep"
    assert out["beyan"]["degisen"] == ["Ön Tampon"] and out["beyan"]["tramerTl"] == 12500


def test_listing_endpoint_rejects_customers_and_other_sites(endpoints):
    extension, saved = endpoints
    req = extension.ExtensionListingPage(url=LISTING_URL, text=LISTING_TEXT)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(extension.extension_save_listing(req, api_key="yk-customer"))
    assert exc.value.status_code == 403
    bad = extension.ExtensionListingPage(url="https://www.sahibinden.com/ilan/1", text=LISTING_TEXT)
    with pytest.raises(HTTPException) as exc:
        asyncio.run(extension.extension_save_listing(bad, api_key="yk-admin"))
    assert exc.value.status_code == 400
    empty = extension.ExtensionListingPage(url=LISTING_URL, text="yükleniyor")
    with pytest.raises(HTTPException) as exc:
        asyncio.run(extension.extension_save_listing(empty, api_key="yk-admin"))
    assert exc.value.status_code == 422 and not saved


def test_search_endpoint_saves_comparables(endpoints):
    extension, saved = endpoints
    req = extension.ExtensionSearchPage(
        url="https://www.arabam.com/ikinci-el/otomobil/renault-clio", brand="Renault", model="Clio",
        cards=[{"url": "/ilan/a/b/28000001", "text": "Clio Joy\n2019\n85.000 km\n815.000 TL"}],
    )
    out = asyncio.run(extension.extension_save_search(req, api_key="yk-admin"))
    assert (out["found"], out["saved"]) == (1, 1) and saved[0]["status"] == "emsal"
