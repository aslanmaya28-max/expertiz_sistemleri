# -*- coding: utf-8 -*-
"""Ilan sayfasi ayristiricilari, ilan kaydi ve satici beyani karsilastirmasi (veritabanisiz)."""
import json

import pytest


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


def test_listing_paint_maps_to_valuation_parts():
    from yerimebak_ai_v5.services.valuation_service import _paint_to_parts

    parts = _paint_to_parts({"painted_parts": ["Motor Kaputu", "Sağ Ön Kapı"], "local_painted_parts": ["Sağ Ön Kapı"],
                             "changed_parts": ["Ön Tampon"]})
    assert parts == {"kaput": "boyali", "sagOnKapi": "lokal_boyali", "onTampon": "degisen"}


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
    assert tramer["farklar"][0] == "İlanda tramer kaydı yok beyan edilmiş, ekspertizde 18.000 TL hasar kaydı bulundu."
    same = compare_declaration({**declared, "tramerTl": 18000}, {"boyaliParcaSayisi": 1}, ekspertiz_tramer_tl=18500)
    assert same["uyumlu"] is True
    unknown_tramer = compare_declaration({**declared, "tramerTl": None}, {"boyaliParcaSayisi": 1}, ekspertiz_tramer_tl=18000)
    assert unknown_tramer["uyumlu"] is True
    unknown = compare_declaration(None, {"boyaliParcaSayisi": 2})
    assert unknown["uyumlu"] is None and unknown["ilanBeyaniVar"] is False


def test_normalize_item_drops_absurd_values():
    from yerimebak_ai_v5.services.market_ingest import normalize_item

    base = {"url": "https://a/1", "brand": "Renault", "model": "Clio"}
    assert normalize_item({**base, "price": 62_000_985_000}) is None   # ayristirma hatasi: fiyat reddedilir
    row = normalize_item({**base, "price": 900_000, "km": 62_000_985})  # anlamsiz km yok sayilir, ilan kalir
    assert row["price"] == 900000 and row["km"] is None
