# -*- coding: utf-8 -*-
"""Apify actor'u, Apify baglanti servisi ve ilan donusturucu (veritabanisiz)."""
import importlib
import json
import sys
from pathlib import Path

import httpx
import pytest

ROOT = Path(__file__).resolve().parents[3]
ACTOR = ROOT / "apify" / "yerimebak-arac-verisi"


# ---------------------------------------------------------------------------
# Actor
# ---------------------------------------------------------------------------

def test_actor_vendor_copy_is_up_to_date():
    """Kaziyici degistiyse actor kopyasi da guncellenmeli: python musteri_paneli/scripts/apify_sync.py"""
    sys.path.insert(0, str(ROOT / "musteri_paneli" / "scripts"))
    try:
        sync = importlib.import_module("apify_sync")
    finally:
        sys.path.pop(0)
    stale = [
        rel for rel in sync.source_files()
        if not (sync.TARGET / rel).exists()
        or (sync.TARGET / rel).read_bytes() != (sync.SOURCE / rel).read_bytes()
    ]
    assert stale == [], f"Actor vendor kopyasi eski: {stale[:5]} -> apify_sync.py calistirin"


def test_actor_files_and_input_schema():
    actor = json.loads((ACTOR / ".actor" / "actor.json").read_text(encoding="utf-8"))
    schema = json.loads((ACTOR / ".actor" / "input_schema.json").read_text(encoding="utf-8"))
    assert actor["name"] == "yerimebak-arac-verisi" and actor["dockerfile"] == "../Dockerfile"
    assert set(schema["properties"]["mode"]["enum"]) == {"ilan", "emsal"}
    assert (ACTOR / "Dockerfile").exists() and (ACTOR / "src" / "__main__.py").exists()


@pytest.fixture()
def collect():
    """Actor modulu; vendor kopyasi testten sonra asil paketi golgelemesin."""
    import yerimebak_ai_v5  # noqa: F401  (asil paket once yuklenir)

    saved_path = list(sys.path)
    saved_modules = set(sys.modules)
    sys.path.insert(0, str(ACTOR))
    try:
        yield importlib.import_module("src.collect")
    finally:
        sys.path[:] = saved_path
        for name in set(sys.modules) - saved_modules:
            module = sys.modules.get(name)
            if name == "src" or name.startswith("src.") or str(getattr(module, "__file__", "") or "").startswith(str(ACTOR)):
                sys.modules.pop(name, None)


def test_actor_detects_source_and_parses_identity(collect):
    assert collect.detect_source("https://www.arabam.com/ilan/x/123") == "arabam"
    assert collect.detect_source("https://borusannext.com/araba/bmw-320i") is None
    assert collect.detect_source("https://www.sahibinden.com/ilan/1") is None
    text = "İlan Bilgileri\nMarka\nRenault\nSeri\nClio\nModel\n1.0 TCe Touch\nYıl\n2019\nKilometre\n72.000 km\n"
    ident = collect.parse_identity(text)
    assert ident["brand"] == "Renault" and ident["series"] == "Clio" and ident["model"] == "1.0 TCe Touch"
    assert ident["year"] == 2019 and ident["km"] == 72000


def test_actor_maps_arabam_listing(collect):
    from yerimebak_ai_v5.scrapers.arabam_v4.models.listing import ArabamListing
    from yerimebak_ai_v5.scrapers.arabam_v4.models.paint_info import PaintInfo

    paint = PaintInfo(has_paint=True, has_changed=True, is_original=False,
                      painted_parts=["Kaput"], changed_parts=["Sol Ön Kapı"], paint_count=1, changed_count=1)
    listing = ArabamListing(url="https://www.arabam.com/ilan/test/1", price=650000, title="Renault Clio",
                            brand="Bilinmeyen", model="Bilinmeyen", year=2019, km=72000, paint_info=paint,
                            tramer_amount=12500, no_damage_record=False, heavy_damage=False,
                            damage_text="Tramer: 12.500 TL")
    item = collect.from_arabam(listing, {"brand": "Renault", "series": "Clio", "model": "1.0 TCe Touch"})
    assert item["brand"] == "Renault" and item["model"] == "Clio" and item["package"] == "1.0 TCe Touch"
    assert item["price"] == 650000 and item["paint_info"]["changed_parts"] == ["Sol Ön Kapı"]
    assert item["paint_info"]["paint_count"] == 1 and item["source"] == "arabam"
    assert item["damage_record"]["tramer_tl"] == 12500 and item["accident_record"] == "Tramerli: 12500 TL"


def test_identity_and_package_parsing():
    from yerimebak_ai_v5.scrapers.arabam_v4.extractors.identity_extractor import package_from_title, parse_identity

    text = "İlan No\n123\nMarka\nRenault\nSeri\nClio\nModel\n1.0 TCe Touch\nModel Yılı\n2019\nYıl: 2019\n"
    ident = parse_identity(text)
    assert ident["brand"] == "Renault" and ident["series"] == "Clio" and ident["model"] == "1.0 TCe Touch"
    assert ident["year"] == 2019
    assert package_from_title("Renault Clio 1.0 TCe Touch - Galeriden", "Renault", "Clio") == "1.0 TCe Touch"
    assert package_from_title("Renault Clio", "Renault", "Clio") is None


def test_valuation_criteria_table():
    from yerimebak_ai_v5.services.valuation_criteria import build_criteria

    degerleme = {
        "kalemler": [
            {"kategori": "kaporta", "baslik": "Kaput", "durum": "Boyalı", "yuzde": 2.5, "tutar": 16000},
            {"kategori": "kaporta", "baslik": "Sol Ön Kapı", "durum": "Değişen", "yuzde": 5.0, "tutar": 32000},
            {"kategori": "kaporta", "baslik": "Sağ Ön Kapı", "durum": "Lokal Boyalı", "yuzde": 0.6, "tutar": 4000},
            {"kategori": "yapisal", "baslik": "Ön Şasi", "durum": "İşlemli", "yuzde": 6.0, "tutar": 38000},
            {"kategori": "tramer", "baslik": "Tramer (hasar kaydı)", "durum": "18.000 TL", "yuzde": 1.5, "tutar": 9000},
        ],
        "piyasaDuzeltmeleri": [{"baslik": "Kilometre farkı", "yuzde": -1.2, "tutar": -8000, "aciklama": "Emsal medyan 57.000 km"}],
    }
    ref = {"found": True, "source": "listings", "count": 12, "clean_count": 8, "reference_median_km": 57000,
           "scope": {"year_window": 1}, "package": "1.0 TCe Touch", "package_match": True}
    rows = {r["kriter"]: r for r in build_criteria(
        degerleme, ref, {"brand": "Renault", "model": "Clio", "year": 2019, "km": 72000, "paket": "1.0 TCe Touch"},
        tramer_tl=18000)}
    assert list(rows) == ["Model", "Paket", "Kilometre", "Hasar kaydı (tramer)", "Değişen", "Boya", "Hasar"]
    assert rows["Paket"]["eslesti"] is True and "aynı paketten" in rows["Paket"]["aciklama"]
    assert rows["Kilometre"]["etki"]["yuzde"] == -1.2 and "72.000 km" in rows["Kilometre"]["deger"]
    assert rows["Hasar kaydı (tramer)"]["deger"] == "18.000 TL" and rows["Hasar kaydı (tramer)"]["etki"]["yuzde"] == 1.5
    assert rows["Değişen"]["deger"] == "1 parça" and rows["Değişen"]["etki"]["tutar"] == 32000
    assert rows["Boya"]["deger"] == "2 parça" and rows["Boya"]["etki"]["yuzde"] == 3.1
    assert rows["Hasar"]["deger"] == "1 bulgu" and "Ön Şasi" in rows["Hasar"]["aciklama"]
    unknown = {r["kriter"]: r for r in build_criteria({}, {}, {"brand": "Renault", "model": "Clio"})}
    assert unknown["Paket"]["deger"] == "Bilinmiyor" and unknown["Model"]["aciklama"] == "Yeterli emsal bulunamadı"


@pytest.mark.parametrize("text,tramer,yok,agir", [
    ("Açıklama\nTramer: 12.500 TL\nAğır Hasar Kayıtlı\nHayır", 12500, False, False),
    ("Hasar Kaydı (Tramer) 8.750,50 TL", 8750, False, None),
    ("aracin 4.200 TL tramer kaydi var", 4200, False, None),
    ("Boyasız değişensiz, tramer kaydı yoktur.", None, True, None),
    ("TRAMERSİZ", None, True, None),
    ("Ağır Hasar Kayıtlı: Evet", None, None, True),
    ("Model yılı 2019, 72.000 km", None, None, None),
    # "Ağır hasar kaydı yok" tramer kaydı yok demek değildir
    ("Ağır hasar kaydı yoktur.", None, None, False),
    ("Tramer tutarı\n0 TL", None, True, None),
    ("Tramer tutarı\n23.400 TL", 23400, False, None),
    ("Tramer tutarı\nBelirtilmemiş", None, None, None),
])
def test_damage_record_parsing(text, tramer, yok, agir):
    from yerimebak_ai_v5.scrapers.arabam_v4.extractors.damage_extractor import damage_summary, parse_damage_record

    rec = parse_damage_record(text)
    assert (rec["tramer_tl"], rec["tramer_yok"], rec["agir_hasar"]) == (tramer, yok, agir)
    summary = damage_summary(rec)
    assert (summary is None) == (not tramer and not agir)


# arabam.com "Boya, Değişen ve Tramer" bölümünün sayfa metni (önce parçasız şema lejantı gelir)
_PAINT_SECTION = """Araç Bilgileri
Boyalı ve değişen parçaları görmek için şemaya bakın
Boya, Değişen ve Tramer
Orijinal
Boyalı
Lokal boyalı
Değişmiş
Belirtilmemiş
Orijinal
Tavan
Sol Ön Kapı
Lokal boyalı
Sağ Ön Kapı
Boyalı
Motor Kaputu
Arka Kaput
Değişmiş
Ön Tampon
Belirtilmemiş
Sol Arka Çamurluk
Tramer tutarı
12.500 TL
Açıklama
Değişen yok demiştim, boyalı parça var."""


def test_paint_section_parsing():
    from yerimebak_ai_v5.scrapers.arabam_v4.extractors.paint_extractor import parse_paint_section

    p = parse_paint_section(_PAINT_SECTION)
    assert p["section_found"]
    assert p["painted_parts"] == ["Motor Kaputu", "Bagaj Kapağı", "Sağ Ön Kapı"]
    assert p["local_paint_parts"] == ["Sağ Ön Kapı"]
    assert p["changed_parts"] == ["Ön Tampon"]
    assert p["original_parts"] == ["Tavan", "Sol Ön Kapı"]
    assert p["unknown_parts"] == ["Sol Arka Çamurluk"] and p["is_original"] is False


@pytest.mark.parametrize("text,painted,changed,original", [
    # Tamamı orijinal
    ("Boya, Değişen ve Tramer\nOrijinal\nMotor Kaputu\nTavan\nÖn Tampon", [], [], True),
    # Tablo satırı ve "Durum: parça, parça" biçimleri, büyük harf
    ("BOYA, DEĞİŞEN VE TRAMER\nSOL ÖN ÇAMURLUK\tBOYALI\nDEĞİŞMİŞ: Bagaj Kapağı, Sağ Arka Kapı", ["Sol Ön Çamurluk"],
     ["Bagaj Kapağı", "Sağ Arka Kapı"], False),
    # Bölüm yoksa (veya yalnız lejant varsa) hiçbir şey uydurulmaz, orijinal de sayılmaz
    ("İlan açıklaması: boyalı değişen yok, tramer yok", [], [], False),
    ("Boya, Değişen ve Tramer\nOrijinal\nBoyalı\nDeğişmiş\nTramer tutarı\nBelirtilmemiş", [], [], False),
])
def test_paint_section_variants(text, painted, changed, original):
    from yerimebak_ai_v5.scrapers.arabam_v4.extractors.paint_extractor import parse_paint_section

    p = parse_paint_section(text)
    assert (p["painted_parts"], p["changed_parts"], p["is_original"]) == (painted, changed, original)


def test_listing_paint_maps_to_valuation_parts():
    from yerimebak_ai_v5.services.valuation_service import _paint_to_parts

    parts = _paint_to_parts({"painted_parts": ["Motor Kaputu", "Sağ Ön Kapı"], "local_painted_parts": ["Sağ Ön Kapı"],
                             "changed_parts": ["Ön Tampon"]})
    assert parts == {"kaput": "boyali", "sagOnKapi": "lokal_boyali", "onTampon": "degisen"}


def test_actor_rejects_unsupported_link(collect):
    import asyncio

    with pytest.raises(ValueError):
        asyncio.run(collect.collect({"mode": "ilan", "url": "https://www.sahibinden.com/ilan/1"}))
    with pytest.raises(ValueError):
        asyncio.run(collect.collect({"mode": "emsal", "brand": "Renault"}))


# ---------------------------------------------------------------------------
# Apify baglanti servisi
# ---------------------------------------------------------------------------

def _transport(states, items, calls):
    def handler(request: httpx.Request) -> httpx.Response:
        calls.append((request.method, request.url.path, request.headers.get("authorization")))
        if request.method == "POST" and request.url.path == "/v2/acts/kullanici~yerimebak-arac-verisi/runs":
            assert json.loads(request.content)["mode"] == "emsal"
            return httpx.Response(201, json={"data": {"id": "run1", "status": states.pop(0), "defaultDatasetId": "ds1"}})
        if request.url.path == "/v2/actor-runs/run1":
            return httpx.Response(200, json={"data": {"id": "run1", "status": states.pop(0), "defaultDatasetId": "ds1",
                                                      "usageTotalUsd": 0.012}})
        if request.url.path == "/v2/datasets/ds1/items":
            return httpx.Response(200, json=items)
        return httpx.Response(404, json={"error": {"message": "yok"}})
    return httpx.MockTransport(handler)


def test_live_client_runs_waits_and_returns_items():
    from yerimebak_ai_v5.services.apify_service import ApifyClient

    calls = []
    client = ApifyClient(token="tok", actor_id="kullanici/yerimebak-arac-verisi",
                         transport=_transport(["RUNNING", "RUNNING", "SUCCEEDED"], [{"price": 1}], calls),
                         sleep=lambda _s: None)
    result = client.run({"mode": "emsal", "brand": "Renault", "model": "Clio", "year": 2019})
    assert result["items"] == [{"price": 1}]
    assert result["run"]["status"] == "SUCCEEDED" and result["run"]["usage_usd"] == 0.012
    assert all(auth == "Bearer tok" for _, _, auth in calls)
    assert [c[1] for c in calls].count("/v2/actor-runs/run1") == 2


def test_live_client_reports_failed_run_and_http_errors():
    from yerimebak_ai_v5.services.apify_service import ApifyClient, ApifyError

    client = ApifyClient(token="tok", actor_id="kullanici~yerimebak-arac-verisi",
                         transport=_transport(["RUNNING", "FAILED"], [], []), sleep=lambda _s: None)
    with pytest.raises(ApifyError, match="FAILED"):
        client.run({"mode": "emsal"})
    bad = ApifyClient(token="tok", actor_id="yanlis~actor", transport=_transport([], [], []), sleep=lambda _s: None)
    with pytest.raises(ApifyError, match="HTTP 404"):
        bad.run({"mode": "emsal"})
    with pytest.raises(ApifyError, match="yapilandirilmamis"):
        ApifyClient(token="", actor_id="").run({"mode": "emsal"})


def test_modes_off_and_mock(monkeypatch, tmp_path):
    from yerimebak_ai_v5.services import apify_service

    monkeypatch.delenv("APIFY_MODE", raising=False)
    assert apify_service.mode() == "off" and not apify_service.enabled()
    with pytest.raises(apify_service.ApifyError):
        apify_service.run_actor({"mode": "emsal"})

    monkeypatch.setenv("APIFY_MODE", "mock")
    emsal = apify_service.run_actor({"mode": "emsal", "brand": "Renault", "model": "Clio"})
    assert emsal["run"]["mock"] is True and len(emsal["items"]) >= 10
    ilan = apify_service.run_actor({"mode": "ilan", "url": "https://www.arabam.com/ilan/x/555"})
    assert ilan["items"][0]["url"] == "https://www.arabam.com/ilan/x/555"

    (tmp_path / "emsal_bmw_320i.json").write_text(json.dumps([{"brand": "BMW"}]), encoding="utf-8")
    monkeypatch.setenv("APIFY_MOCK_DIR", str(tmp_path))
    assert apify_service.run_actor({"mode": "emsal", "brand": "BMW", "model": "320i"})["items"] == [{"brand": "BMW"}]
    assert apify_service.run_actor({"mode": "ilan", "url": "https://x/1"})["items"] == []


# ---------------------------------------------------------------------------
# Donusturucu ve beyan karsilastirmasi
# ---------------------------------------------------------------------------

def test_normalize_item():
    from yerimebak_ai_v5.services.market_ingest import normalize_item, normalize_url

    assert normalize_url("http://WWW.Arabam.com/ilan/X/1/?utm=a#f") == "https://www.arabam.com/ilan/x/1"
    row = normalize_item({"url": "www.arabam.com/ilan/a/1", "brand": "Renault", "model": "Clio", "price": "650.000 TL",
                          "year": 2019, "km": "72.000", "fuel": "Bilinmiyor", "source": "borusan_next",
                          "paint_info": {"has_paint": True}})
    assert row["url"] == "https://www.arabam.com/ilan/a/1" and row["price"] == 650000 and row["km"] == 72000
    assert row["fuel"] is None and row["source"] == "borusan_next"
    assert json.loads(row["paint_info"]) == {"has_paint": True}
    damaged = normalize_item({"url": "https://a/2", "brand": "Renault", "model": "Clio", "price": 5,
                              "accident_record": "Ağır hasar kayıtlı, Tramerli: 180000 TL",
                              "damage_record": {"tramer_tl": 180000, "tramer_yok": False, "agir_hasar": True}})
    assert damaged["heavy_damage"] == "Ağır hasar kayıtlı" and json.loads(damaged["damage_info"])["tramer_tl"] == 180000
    unknown = normalize_item({"url": "https://a/3", "brand": "Renault", "model": "Clio", "price": 5,
                              "damage_record": {"tramer_tl": None, "tramer_yok": None, "agir_hasar": None}})
    assert unknown["damage_info"] is None and unknown["heavy_damage"] is None
    assert normalize_item({"url": "https://a/1", "brand": "Renault", "model": "Clio", "price": 0}) is None
    assert normalize_item({"url": "", "brand": "Renault", "model": "Clio", "price": 5}) is None


def test_compare_declaration():
    from yerimebak_ai_v5.services.market_ingest import compare_declaration

    declared = {"known": True, "boyali": 1, "degisen": 0, "source": "arabam", "url": "u"}
    mismatch = compare_declaration(declared, {"boyaliParcaSayisi": 3, "degisenParcaSayisi": 1})
    assert mismatch["uyumlu"] is False and len(mismatch["farklar"]) == 2
    assert "1 boyalı" in mismatch["farklar"][0] and "3 boyalı" in mismatch["farklar"][0]
    ok = compare_declaration(declared, {"boyaliParcaSayisi": 1, "degisenParcaSayisi": 0})
    assert ok["uyumlu"] is True and ok["farklar"] == []
    tramer = compare_declaration({**declared, "tramerTl": 0}, {"boyaliParcaSayisi": 1}, ekspertiz_tramer_tl=18000)
    assert tramer["uyumlu"] is False and "tramer kaydı yok" in tramer["farklar"][0] and "18.000 TL" in tramer["farklar"][0]
    same = compare_declaration({**declared, "tramerTl": 18000}, {"boyaliParcaSayisi": 1}, ekspertiz_tramer_tl=18500)
    assert same["uyumlu"] is True
    unknown_tramer = compare_declaration({**declared, "tramerTl": None}, {"boyaliParcaSayisi": 1}, ekspertiz_tramer_tl=18000)
    assert unknown_tramer["uyumlu"] is True
    unknown = compare_declaration(None, {"boyaliParcaSayisi": 2})
    assert unknown["uyumlu"] is None and unknown["ilanBeyaniVar"] is False
