# -*- coding: utf-8 -*-
"""Ekspertiz bazlı değerleme motoru: piyasa değerinden bulgu bazlı değer kaybı."""
from datetime import datetime

import pytest

from yerimebak_ai_v5.core.ai.ai_result_adapter import inspection_to_ai_analiz
from yerimebak_ai_v5.core.ai.inspection_valuation import (
    classify_listing_condition,
    evaluate,
    tramer_loss_pct,
)

NOW = datetime(2026, 10, 11)
MARKET = {
    "found": True,
    "source": "listings",
    "count": 20,
    "market_median_price": 1_000_000,
    "clean_median_price": 1_000_000,
    "clean_count": 8,
    "confidence": 90,
}


def _tam(parts=None, structural=None, year=2024, km=30_000, **extra):
    tam = {
        "adim1": {"yil": year, "guncelKm": km},
        "adim4": {"parcaDurumlari": parts or {}, "yapisalDurumlar": structural or {}},
    }
    for key, value in extra.items():
        tam[key] = value
    return tam


def test_clean_car_keeps_market_value():
    r = evaluate(_tam(), MARKET, listed_price=1_000_000, now=NOW)
    assert r["toplamDegerKaybiYuzde"] == 0
    assert r["aiDegeri"] == 1_000_000
    assert r["hasarSeviyesi"] == "NONE"
    assert r["fiyatYorumu"]["karar"] == "MAKUL"


def test_two_replaced_doors_and_painted_fender_are_deducted_per_part():
    # Kullanıcının örneği: iki kapı değişen, arka çamurluk boyalı
    r = evaluate(_tam({"solOnKapi": "degisen", "sagOnKapi": "degisen", "solArkaCamurluk": "boyali"}),
                 MARKET, listed_price=1_000_000, now=NOW)
    kalemler = {k["anahtar"]: k for k in r["kalemler"]}
    assert set(kalemler) == {"solOnKapi", "sagOnKapi", "solArkaCamurluk"}
    # ikinci değişen azalan etkiyle (%5 → %4,25)
    assert sorted(round(kalemler[k]["yuzde"], 2) for k in ("solOnKapi", "sagOnKapi")) == [4.25, 5.0]
    assert kalemler["solArkaCamurluk"]["yuzde"] == pytest.approx(1.8)
    # Araç Endeks: değişenli araçlarda medyan ≈ -%9,4 → makul bant
    assert 8 <= r["toplamDegerKaybiYuzde"] <= 13
    assert r["aiDegeri"] == pytest.approx(1_000_000 * (1 - r["toplamDegerKaybiYuzde"] / 100), abs=1_000)
    assert sum(k["tutar"] for k in r["kalemler"]) == pytest.approx(r["toplamDegerKaybiTutar"], abs=2)
    assert r["fiyatYorumu"]["karar"] == "YUKSEK"
    assert r["onerilenAlimFiyati"] < r["aiDegeri"]


def test_paint_count_calibration_matches_market_data():
    two = evaluate(_tam({"solOnKapi": "boyali", "sagOnKapi": "boyali"}), MARKET, now=NOW)
    four = evaluate(_tam({k: "boyali" for k in ("solOnKapi", "sagOnKapi", "solArkaKapi", "sagArkaKapi")}), MARKET, now=NOW)
    assert two["toplamDegerKaybiYuzde"] == pytest.approx(3.0)       # 1-2 boyalı ≈ -%3
    assert 4.5 <= four["toplamDegerKaybiYuzde"] <= 6.0              # 3-5 boyalı ≈ -%5,2


def test_structural_damage_is_heavy_and_not_attenuated_by_age():
    young = evaluate(_tam(structural={"onSasi": "islemli"}), MARKET, now=NOW)
    old = evaluate(_tam(structural={"onSasi": "islemli"}, year=2012, km=250_000), MARKET, now=NOW)
    assert young["agirHasar"] and young["hasarSeviyesi"] == "HEAVY"
    assert young["toplamDegerKaybiYuzde"] == old["toplamDegerKaybiYuzde"] == 15.0
    assert young["skorlar"]["genelPuan"] <= 55


def test_cosmetic_loss_is_attenuated_for_old_high_km_cars():
    young = evaluate(_tam({"kaput": "boyali"}), MARKET, now=NOW)
    old = evaluate(_tam({"kaput": "boyali"}, year=2012, km=250_000), MARKET, now=NOW)
    assert old["toplamDegerKaybiYuzde"] < young["toplamDegerKaybiYuzde"]


def test_roof_replacement_and_bumper_paint():
    roof = evaluate(_tam({"tavan": "degisen"}), MARKET, now=NOW)
    bumper = evaluate(_tam({"onTampon": "boyali"}), MARKET, now=NOW)
    assert roof["toplamDegerKaybiYuzde"] >= 15 and roof["agirHasar"]
    assert bumper["toplamDegerKaybiYuzde"] < 1  # tampon boyası ihmal edilebilir


def test_mechanical_flood_and_tramer_findings():
    tam = _tam(
        adim3={"maddeDurumlari": {"kokuNem": "kotu", "klima": "sorunlu"}},
        adim5={"motorDurumu": "sorunlu", "sanzimanDurumu": "iyi"},
    )
    tam["adim1"]["hasarKayitToplamTutar"] = 60_000
    r = evaluate(tam, MARKET, now=NOW)
    cats = {k["kategori"] for k in r["kalemler"]}
    assert {"ic", "mekanik", "tramer"} <= cats
    assert r["agirHasar"]  # su baskını şüphesi
    assert r["skorlar"]["motorMekanikPuan"] < 75


def test_tramer_overlap_with_bodywork_is_not_double_counted():
    only_tramer = _tam()
    only_tramer["adim1"]["hasarKayitToplamTutar"] = 80_000
    with_parts = _tam({"solOnKapi": "degisen"})
    with_parts["adim1"]["hasarKayitToplamTutar"] = 80_000
    t1 = next(k for k in evaluate(only_tramer, MARKET, now=NOW)["kalemler"] if k["kategori"] == "tramer")
    t2 = next(k for k in evaluate(with_parts, MARKET, now=NOW)["kalemler"] if k["kategori"] == "tramer")
    assert t2["yuzde"] < t1["yuzde"]


def test_tramer_tiers():
    assert tramer_loss_pct(0, 1_000_000) == 0
    assert tramer_loss_pct(50_000, 1_000_000) == pytest.approx(5.0)
    assert tramer_loss_pct(150_000, 1_000_000) == pytest.approx(12.0)
    assert tramer_loss_pct(900_000, 1_000_000) == 30.0


def test_outer_checklist_does_not_double_count_bodywork_part():
    tam = _tam({"solOnKapi": "degisen"}, adim2={"maddeDurumlari": {"solOnKapi": "kotu", "onCam": "sorunlu"}})
    keys = [k["anahtar"] for k in evaluate(tam, MARKET, now=NOW)["kalemler"]]
    assert keys.count("solOnKapi") == 1 and "onCam" in keys


def test_total_loss_is_capped():
    parts = {k: "degisen" for k in ("kaput", "tavan", "solOnKapi", "sagOnKapi", "solArkaCamurluk", "sagArkaCamurluk")}
    structural = {k: "hasarli" for k in ("onSasi", "arkaSasi", "onDirekler", "podye")}
    r = evaluate(_tam(parts, structural), MARKET, now=NOW)
    assert r["toplamDegerKaybiYuzde"] == 50.0 and r["kayipTavaniUygulandi"]


def test_no_market_data_gives_percentages_but_no_price():
    r = evaluate(_tam({"solOnKapi": "degisen"}), {"found": False}, listed_price=None, now=NOW)
    assert r["degerlemeYapildi"] is False
    assert r["aiDegeri"] is None
    assert r["toplamDegerKaybiYuzde"] > 0
    ai = inspection_to_ai_analiz(r, report_id="r1")
    assert ai["raporOzeti"]["tahminiDeger"] == 0.0
    assert any("Piyasa" in s for s in ai["kritikSorunlar"])
    # admin talimatı müşteri raporuna sızmaz
    assert any(o["hedef"] == "admin" for o in ai["oneriler"])
    from yerimebak_ai_v5.services.expertiz_service import _customer_ai
    assert all(o["hedef"] != "admin" for o in _customer_ai(ai)["oneriler"])


def test_outer_checklist_labels_without_kontrol_listesi():
    tam = _tam(adim2={"maddeDurumlari": {"onTampon": "sorunlu"}})
    assert evaluate(tam, MARKET, now=NOW)["kalemler"][0]["baslik"] == "Ön Tampon"


def test_last_resort_listed_price_has_low_confidence():
    ref = {"found": True, "source": "last_resort_listed_price", "market_median_price": 970_000,
           "confidence": 20, "scope": {"listed_price": 1_000_000}}
    r = evaluate(_tam(), ref, listed_price=1_000_000, now=NOW)
    assert r["guvenSkoru"] <= 25 and r["temizPiyasaDegeri"] == 1_000_000


def test_km_and_year_adjustment_against_comparables():
    market = dict(MARKET, reference_median_km=80_000, reference_median_year=2024)
    r = evaluate(_tam(km=40_000), market, now=NOW)
    assert r["temizPiyasaDegeri"] > r["piyasaDegeri"]
    assert r["piyasaDuzeltmeleri"][0]["baslik"] == "Kilometre farkı"


def test_legacy_label_lists_are_supported():
    tam = {"adim1": {"yil": 2024}, "adim4": {"boyaliParcalar": ["Motor Kaputu"], "degisenParcalar": ["Sol Ön Kapı", "Bilinmeyen Parça"]}}
    r = evaluate(tam, MARKET, now=NOW)
    assert r["degisenParcaSayisi"] == 2 and r["boyaliParcaSayisi"] == 1


def test_adapter_schema_is_flutter_compatible():
    r = evaluate(_tam({"solOnKapi": "degisen"}), MARKET, listed_price=1_100_000, now=NOW)
    ai = inspection_to_ai_analiz(r, report_id="r1", liquidity={"liquidity_score": 60, "estimated_days_to_sell": 40})
    for key in ("aracDurumuPuan", "motorMekanikPuan", "hasarPuan", "genelPuan"):
        assert isinstance(ai["skorlar"][key], float)
    assert all(isinstance(v, float) for v in ai["skorlar"]["detayliPuanlar"].values())
    assert all(isinstance(o["oncelik"], int) for o in ai["oneriler"])
    assert ai["raporOzeti"]["tahminiDeger"] == r["aiDegeri"]
    assert ai["raporOzeti"]["degerProjeksiyonu1Yil"] == 0.0  # kâr projeksiyonu artık yazılmıyor
    assert ai["ekspertizDegerleme"]["kalemler"][0]["anahtar"] == "solOnKapi"


@pytest.mark.parametrize("text,expected", [
    ("Boyasız/Değişensiz", "clean"),
    ("{'has_paint': True, 'has_changed': False}", "damaged"),
    ("sol kapı değişen", "damaged"),
    ("ağır hasar kayıtlı", "heavy"),
    ("", "unknown"),
])
def test_listing_condition_classifier(text, expected):
    assert classify_listing_condition(text) == expected
