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
    assert p["hedefFiyat"] == 915_000 and p["ustSinir"] == 960_000
    # Acilis adil araligin %95'inin altina inmez
    assert p["acilisTeklifi"] >= 900_000 * 0.95
    assert p["potansiyelKazanc"] == 135_000
    assert any(g.startswith("İlan fiyatı (1.050.000 TL) adil aralığın üst sınırından (980.000 TL) 70.000 TL yüksek.") for g in p["gerekceler"])
    assert any("Sol ön kapı" in g and "38.000 TL" in g for g in p["gerekceler"])
    assert p["uyari"] is None


def test_kanitlar_en_ucuz_ve_linkli_ilanlar():
    kanit = _plan()["kanitIlanlar"]
    assert [k["fiyat"] for k in kanit] == [940_000, 955_000, 980_000]
    assert all(k["url"].startswith("https://") for k in kanit)


def test_satici_mesaji_rakam_ve_ekspertiz_icerir():
    p = _plan()
    m = p["saticiMesaji"]
    assert "Renault Clio ilanınızı gördüm" in m and f"{p['acilisTeklifi']:,}".replace(",", ".") in m
    assert "ekspertiz" in m


def test_fiyat_zaten_uygunsa_kucuk_pay():
    p = _plan(price=880_000)
    assert p["durum"] == "fiyat_uygun"
    # Kullanıcı kararı (07.11.2026): son fiyat (üst sınır) ilan fiyatının en az 10.000 TL altında.
    assert p["ustSinir"] == 870_000 and p["hedefFiyat"] < 870_000 and p["acilisTeklifi"] < p["hedefFiyat"]
    assert "sınırlı" in p["adimlar"][0]


def test_dusuk_guvende_uyari_var():
    assert "yön gösterici" in _plan(confidence_level="dusuk")["uyari"]


def test_kaynak_yoksa_bile_calisir():
    p = _plan(reference={}, kalemler=[])
    assert p["kanitIlanlar"] == [] and p["saticiMesaji"]
    assert p["acilisTeklifi"] <= p["hedefFiyat"] <= p["ustSinir"]


def test_ilan_ortanin_cok_ustundeyse_plan_uyarir():
    from yerimebak_ai_v5.services.negotiation import build_plan
    plan = build_plan(price=1_895_000, fair_min=1_540_000, fair_max=1_740_000, recommended=1_590_000,
                      reference={"count": 9, "market_median_price": 1_640_000, "samples": []}, kalemler=[],
                      confidence_level="orta", vehicle_title="2024 MG HS")
    assert "satıcıdan nedenini isteyin" in (plan["uyari"] or "")
    normal = build_plan(price=1_700_000, fair_min=1_540_000, fair_max=1_740_000, recommended=1_590_000,
                        reference={"count": 9, "market_median_price": 1_640_000, "samples": []}, kalemler=[],
                        confidence_level="orta", vehicle_title="2024 MG HS")
    assert normal["uyari"] is None


def test_ilan_piyasanin_altindaysa_hedef_ilan_fiyatina_esit_olmaz_ve_satici_lehine_gerekce_yok():
    # Cupra Formentor denemesi (02.11.2026): ilan 2.265.000, düzeltilmiş orta fiyat 2.338.115.
    # Eski plan hedef = üst sınır = ilan fiyatı veriyor, satıcıya "orta fiyat daha yüksek" diyordu.
    ref = {"count": 4, "market_median_price": 2_338_115, "reference_median_year": 2023, "reference_median_km": 87_000,
           "samples": [
               {"site": "a.com", "url": "https://a.com/1", "price": 2_229_500, "km": 76_735, "year": 2023},
               {"site": "b.com", "url": "https://b.com/2", "price": 2_175_000, "km": 72_000, "year": 2021},
               {"site": "c.com", "url": "https://c.com/3", "price": 2_495_000, "km": 33_000, "year": 2023},
               {"site": "d.com", "url": "https://d.com/4", "price": 2_378_500, "km": 68_695, "year": 2023}]}
    p = build_plan(price=2_265_000, fair_min=2_205_000, fair_max=2_485_000, recommended=2_275_000,
                   reference=ref, kalemler=[], confidence_level="yuksek", vehicle_title="2023 Cupra Formentor")
    assert p["durum"] == "kucuk_pay"
    assert p["acilisTeklifi"] < p["hedefFiyat"] < p["ustSinir"] == 2_255_000
    assert not any("orta fiyat" in g for g in p["gerekceler"])
    assert "orta fiyat" not in p["saticiMesaji"]
    # Satıcıya yalnız ilandan ucuz ve en az aynı yıldaki ilan gösterilir (2021 ilanı kanıt olmaz).
    assert [k["fiyat"] for k in p["kanitIlanlar"]] == [2_229_500]
    assert any("kilometresi" in g for g in p["gerekceler"])
    assert "sınırlı" in p["adimlar"][0]


def test_gerekce_yoksa_mesaj_uydurma_gerekce_yazmaz():
    p = build_plan(price=1_000_000, fair_min=950_000, fair_max=1_100_000, recommended=1_020_000,
                   reference={"count": 5, "market_median_price": 1_050_000, "samples": []}, kalemler=[],
                   confidence_level="yuksek", vehicle_title="2022 Fiat Egea")
    assert p["gerekceler"] == []
    assert "ekspertizini yaptırırım" in p["saticiMesaji"] and "1.050.000" not in p["saticiMesaji"]
    assert p["hedefFiyat"] < 1_000_000



def test_son_fiyat_her_durumda_ilanin_en_az_10_bin_tl_altinda():
    # Kullanıcı kararı (07.11.2026): "amaç müşterimize kâr ettirmek; son fiyat en az 10 bin TL eksik".
    for price, lo, hi, rec in [(880_000, 900_000, 1_000_000, 950_000), (2_095_000, 1_950_000, 2_200_000, 2_015_000),
                               (1_730_000, 1_360_000, 1_530_000, 1_400_000), (452_500, 430_000, 470_000, 445_000),
                               (95_000, 90_000, 110_000, 98_000)]:
        p = build_plan(price=price, fair_min=lo, fair_max=hi, recommended=rec, reference={}, kalemler=[],
                       confidence_level="yuksek", vehicle_title="Deneme")
        assert p["acilisTeklifi"] < p["hedefFiyat"] <= p["ustSinir"] <= price - 10_000, (price, p)
        assert p["potansiyelKazanc"] >= 10_000
        assert any(f"Üst sınırınız" in a for a in p["adimlar"])


def test_satici_mesaji_kullanici_metni_kalibinda():
    # Kullanıcı metni (09.11.2026): samimi, ciddi alıcı; aracın kendi yılı/km'si, tek net rakam, gerekçe listesi yok.
    from yerimebak_ai_v5.services.negotiation import _satici_mesaji
    m = _satici_mesaji("2025 Skoda Kamiq", 2025, 18_000, 1_705_000)
    assert m.split("\n\n") == [
        "Merhaba, Skoda Kamiq ilanınızı gördüm. Araç hoşuma gitti, açıkçası ciddi olarak düşünüyorum. "
        "Özellikle 2025 model ve 18.000 km olması benim aradığım özellikler.",
        "Piyasaya da biraz baktım, o yüzden size direkt net bir rakam söylemek istedim. 1.705.000 TL civarında "
        "anlaşabilirsek gelip aracı görürüm, ekspertizini yaptırırım. Her şey söylendiği gibiyse de uzatmadan "
        "alım tarafında ilerlemek isterim.",
        "Sizin açınızdan da uygunsa konuşalım, belki ortak bir noktada buluşuruz.",
    ]
    tek = _satici_mesaji("2019 Fiat Egea", 2019, None, 627_000, hasarli=True)
    assert "2019 model olması benim için önemli." in tek and "boya/değişen bilgisine" in tek
    # Planın mesajı emsal ortalama km'sini aracın km'si gibi yazmaz.
    p = _plan(vehicle_km=None)
    assert " km olması" not in p["saticiMesaji"]
