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
    assert collect.detect_source("https://borusannext.com/araba/bmw-320i") == "borusan"
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
                            brand="Bilinmeyen", model="Bilinmeyen", year=2019, km=72000, paint_info=paint)
    item = collect.from_arabam(listing, {"brand": "Renault", "series": "Clio", "model": "1.0 TCe Touch"})
    assert item["brand"] == "Renault" and item["model"] == "Clio" and item["package"] == "1.0 TCe Touch"
    assert item["price"] == 650000 and item["paint_info"]["changed_parts"] == ["Sol Ön Kapı"]
    assert item["paint_info"]["paint_count"] == 1 and item["source"] == "arabam"


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
    assert row["fuel"] is None and row["source"] == "borusan"
    assert json.loads(row["paint_info"]) == {"has_paint": True}
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
    unknown = compare_declaration(None, {"boyaliParcaSayisi": 2})
    assert unknown["uyumlu"] is None and unknown["ilanBeyaniVar"] is False
