# -*- coding: utf-8 -*-
"""Kredili degerleme: guven seviyesi, dusuk guvende kesin karar yok, 5 soruluk ozet, bilgi kaynaklari."""
from yerimebak_ai_v5.services.valuation_service import (
    LOW_CONFIDENCE_VERDICT, confidence_level, decision_summary,
)

DEGERLEME = {
    "adilFiyatAraligi": {"min": 900_000, "max": 980_000},
    "fiyatYorumu": {"farkYuzde": 8.4},
    "kalemler": [
        {"baslik": "Kaput", "durum": "Boyalı", "tutar": 21_000},
        {"baslik": "Sol ön kapı", "durum": "Değişen", "tutar": 38_000},
        {"baslik": "Tavan", "durum": "Lokal boyalı", "tutar": 4_000},
    ],
    "agirHasar": False,
}
REF = {"source": "web_listings", "count": 7, "market_median_price": 960_000}


def _ozet(**kw):
    args: dict = dict(price=1_020_000, degerleme=DEGERLEME, recommended=930_000, verdict_key="PAZARLIK",
                karar="PAZARLIK YAP", karar_aciklama="Fiyat biraz yüksek.", confidence=78, flags=[],
                reference=REF, from_saved_listing=False)
    args.update(kw)
    return decision_summary(**args)


def test_guven_seviyesi():
    assert confidence_level(80, []) == "yuksek"
    assert confidence_level(60, []) == "orta"
    assert confidence_level(45, []) == "dusuk"
    assert confidence_level(90, [{"kod": "az_emsal"}]) == "dusuk"
    assert confidence_level(90, [{"kod": "paket_eslesmedi"}]) == "yuksek"


def test_yeterli_veride_karar_ve_bes_cevap():
    s = _ozet()
    assert s["karar"]["sonuc"] == "PAZARLIK YAP" and s["karar"]["guvenSeviyesi"] == "yuksek"
    assert s["karar"]["hesaplananEgilim"] is None
    o = s["ozet"]
    assert o["piyasaKonumu"]["durum"] == "ustunde" and "%8.4 üstünde" in o["piyasaKonumu"]["metin"]
    assert o["adilFiyat"] == {"min": 900_000, "max": 980_000}
    # En buyuk iki kayip once, beyan uyarisi her zaman sonda
    assert o["riskler"][0].startswith("Sol ön kapı") and "38.000 TL" in o["riskler"][0]
    assert "uzman tarafından doğrulanmadı" in o["riskler"][-1]
    assert o["pazarlikGerekceleri"][0] == "İlan fiyatı adil aralığın üst sınırından 40.000 TL yüksek."
    assert "Benzer 7 ilanın orta fiyatı 960.000 TL." in o["pazarlikGerekceleri"]
    assert "930.000 TL" in o["simdiNeYapmali"]


def test_dusuk_guvende_kesin_karar_verilmez():
    s = _ozet(confidence=40, flags=[{"kod": "az_emsal", "mesaj": "Yalnızca 3 doğrulanmış emsal ilan bulundu"}])
    assert s["karar"]["sonuc"] == LOW_CONFIDENCE_VERDICT
    assert s["karar"]["hesaplananEgilim"] == "PAZARLIK YAP"
    assert s["karar"]["guvenSeviyesi"] == "dusuk"
    assert "uzman incelemesiyle" in s["ozet"]["simdiNeYapmali"]
    assert any("3 doğrulanmış emsal" in r for r in s["ozet"]["riskler"])


def test_bilgi_kaynaklari_beyan_ve_tahmini_ayirir():
    kaynaklar = {k["alan"]: k["kaynak"] for k in _ozet()["bilgiKaynaklari"]}
    assert kaynaklar["Boya, değişen ve tramer"] == "musteri_beyani"
    assert kaynaklar["Piyasa değeri"] == "internet_ilanlari"
    assert kaynaklar["Gelecek değer"] == "tahmin"
    assert kaynaklar["Araç bilgileri (marka, model, yıl, km, fiyat)"] == "musteri_beyani"
    assert {k["alan"]: k["kaynak"] for k in _ozet(from_saved_listing=True)["bilgiKaynaklari"]}[
        "Araç bilgileri (marka, model, yıl, km, fiyat)"] == "kayitli_ilan"


def test_alma_ve_al_adimlari():
    assert "almayın" in _ozet(verdict_key="YUKSEK", karar="ALMA")["ozet"]["simdiNeYapmali"]
    al = _ozet(verdict_key="MAKUL", karar="AL", price=950_000)
    assert al["ozet"]["piyasaKonumu"]["durum"] == "uyumlu"
    assert "yerinde inceletin" in al["ozet"]["simdiNeYapmali"]
    assert not any("adil aralığın" in g for g in al["ozet"]["pazarlikGerekceleri"])
