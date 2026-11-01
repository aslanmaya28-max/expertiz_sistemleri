# -*- coding: utf-8 -*-
"""Pazarlik plani: kurallar, siniri asmayan rakamlar, kanitlar ve satici mesaji."""
from yerimebak_ai_v5.services.negotiation import build_plan

REF = {
    "count": 6, "market_median_price": 960_000,
    "samples": [
        {"site": "arabam.com", "url": "https://www.arabam.com/ilan/1", "price": 980_000, "km": 60_000, "year": 2020},
        {"site": "otoshops.com", "url": "https://www.otoshops.com/2", "price": 940_000, "km": 70_000, "year": 2020},
        {"site": "batidan2.com", "url": "https://www.batidan2.com/3", "price": 955_000, "km": 65_000, "year": 2021},
        {"site": "kopya", "url": "ftp://x", "price": 900_000},
        {"site": "arabam.com", "url": "https://www.arabam.com/ilan/5", "price": 1_010_000, "km": 50_000, "year": 2021},
    ],
}
KALEMLER = [{"baslik": "Kaput", "durum": "Boyalı", "tutar": 21_000},
            {"baslik": "Sol ön kapı", "durum": "Değişen", "tutar": 38_000}]


def _plan(**kw):
    args: dict = dict(price=1_050_000, fair_min=900_000, fair_max=980_000, recommended=915_000,
                      reference=REF, kalemler=KALEMLER, confidence_level="yuksek",
                      vehicle_title="2020 Renault Clio")
    args.update(kw)
    return build_plan(**args)


def test_pahali_ilanda_sira_ve_sinirlar():
    p = _plan()
    assert p["durum"] == "pazarlik_payi_var"
    assert p["acilisTeklifi"] <= p["hedefFiyat"] <= p["ustSinir"] <= 1_050_000
    assert p["hedefFiyat"] == 915_000 and p["ustSinir"] == 980_000
    # Acilis adil araligin %95'inin altina inmez
    assert p["acilisTeklifi"] >= 900_000 * 0.95
    assert p["potansiyelKazanc"] == 135_000
    assert p["gerekceler"][0].startswith("İlan fiyatı (1.050.000 TL) adil aralığın üst sınırından (980.000 TL) 70.000 TL yüksek.")
    assert any("Sol ön kapı" in g and "38.000 TL" in g for g in p["gerekceler"])
    assert p["uyari"] is None


def test_kanitlar_en_ucuz_ve_linkli_ilanlar():
    kanit = _plan()["kanitIlanlar"]
    assert [k["fiyat"] for k in kanit] == [940_000, 955_000, 980_000]
    assert all(k["url"].startswith("https://") for k in kanit)


def test_satici_mesaji_rakam_ve_ekspertiz_icerir():
    p = _plan()
    m = p["saticiMesaji"]
    assert "2020 Renault Clio" in m and f"{p['acilisTeklifi']:,}".replace(",", ".") in m
    assert "ekspertiz" in m


def test_fiyat_zaten_uygunsa_kucuk_pay():
    p = _plan(price=880_000)
    assert p["durum"] == "fiyat_uygun"
    assert p["ustSinir"] == 880_000 and p["hedefFiyat"] < 880_000 and p["acilisTeklifi"] < p["hedefFiyat"]
    assert "sınırlı" in p["adimlar"][0]


def test_dusuk_guvende_uyari_var():
    assert "yön gösterici" in _plan(confidence_level="dusuk")["uyari"]


def test_kaynak_yoksa_bile_calisir():
    p = _plan(reference={}, kalemler=[])
    assert p["kanitIlanlar"] == [] and p["saticiMesaji"]
    assert p["acilisTeklifi"] <= p["hedefFiyat"] <= p["ustSinir"]
