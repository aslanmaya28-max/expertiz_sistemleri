# -*- coding: utf-8 -*-
"""Değerlemeyi etkileyen özellikler ilandan okunur (11.11.2026): telefonun ilan sayfası metninde etiket ve
değer alt alta gelir; motor gücü ve tam paket adı da okunur."""
from yerimebak_ai_v5.services import listing_extract as l

TELEFON_METNI = "\n".join([
    "Seat Ibiza 1.0 EcoTSI Style", "939.000 TL", "İzmir / Karşıyaka / Bostanlı Mh.",
    "Marka", "Seat", "Seri", "Ibiza", "Model", "1.0 EcoTSI Style", "Yıl", "2021",
    "Yakıt", "Benzin", "Vites", "Manuel", "KM", "54.274", "Motor Gücü", "95 hp", "Motor Hacmi", "999 cc",
])


def test_alt_alta_etiketler_okunur():
    alanlar = {k: v["deger"] for k, v in l.labeled_fields(TELEFON_METNI).items()}
    assert alanlar == {"brand": "Seat", "model": "Ibiza", "package": "1.0 EcoTSI Style", "year": 2021,
                       "km": 54274, "fuel": "Benzin", "transmission": "Manuel", "hp": 95}


def test_ayni_satir_bicimi_bozulmadi():
    alanlar = l.labeled_fields("MarkaSeat\nSeriIbiza\nModel1.0 EcoTSI Style\nYıl2021\nMotor Gücü95 hp")
    assert alanlar["package"]["deger"] == "1.0 EcoTSI Style"
    assert alanlar["hp"]["deger"] == 95


def test_motor_gucu_araligi_kesin_deger_sayilmaz():
    assert "hp" not in l.labeled_fields("Marka\nSeat\nSeri\nIbiza\nMotor Gücü\n76 - 100 hp")


def test_yapay_zekanin_motor_gucu_ilanda_geciyorsa_kabul_edilir():
    alanlar = l.verify({"hp": 95}, TELEFON_METNI, "ilan_metni")
    assert alanlar["hp"]["deger"] == 95
    assert "hp" not in l.verify({"hp": 110}, TELEFON_METNI, "ilan_metni")
    assert "hp" not in l.verify({"hp": 20}, "20 hp", "ilan_metni")


def test_anahtarsiz_yolda_tum_ozellikler_ve_sehir():
    import os
    eski = os.environ.pop("OPENROUTER_API_KEY", None)
    try:
        arac = l.from_text(TELEFON_METNI)["vehicle"]
    finally:
        if eski is not None:
            os.environ["OPENROUTER_API_KEY"] = eski
    assert arac["hp"] == 95 and arac["package"] == "1.0 EcoTSI Style" and arac["location"] == "İzmir"


def test_yakit_motor_tipi_etiketi_deger_sanilmaz():
    for metin in ("Marka\nSeat\nSeri\nIbiza\nYakıt / Motor Tipi\nBenzin",
                  "MarkaSeat\nSeriIbiza\nYakıt / Motor TipiBenzin"):
        assert l.labeled_fields(metin)["fuel"]["deger"] == "Benzin"


def test_gercek_sahibinden_telefon_metni():
    """Uygulamanın WebView'ından alınan gerçek ilan bilgileri bölümü (11.11.2026, Seat Ibiza).
    Sahibinden motoru seriye yazar ("Ibiza 1.0" / "Style"); sayfa başında "4. YIL" rozeti vardır."""
    from pathlib import Path
    metin = (Path(__file__).parents[1] / "fixtures" / "sahibinden_telefon_metni.txt").read_text(encoding="utf-8")
    alanlar = {k: v["deger"] for k, v in l.labeled_fields(metin).items()}
    assert alanlar == {"brand": "Seat", "model": "Ibiza", "package": "1.0 Style", "year": 2021, "km": 54274,
                       "fuel": "Benzin", "transmission": "Manuel", "hp": 80, "price": 939000}
    assert l.konum_satirindan_il(metin) == "İzmir"
