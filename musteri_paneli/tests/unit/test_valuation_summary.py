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
    assert o["piyasaKonumu"]["durum"] == "ustunde" and "%8,4 üstünde" in o["piyasaKonumu"]["metin"]
    assert o["adilFiyat"] == {"min": 900_000, "max": 980_000}
    # En buyuk iki kayip once, beyan uyarisi her zaman sonda
    assert o["riskler"][0].startswith("Sol ön kapı") and "38.000 TL" in o["riskler"][0]
    assert "uzman tarafından doğrulanmadı" in o["riskler"][-1]
    assert o["pazarlikGerekceleri"][0] == "İlan fiyatı adil aralığın üst sınırından 40.000 TL yüksek."
    assert "Benzer 7 ilanın orta fiyatı (bu araca göre düzeltilmiş) 960.000 TL." in o["pazarlikGerekceleri"]
    assert "930.000 TL" in o["simdiNeYapmali"]


def test_dusuk_guvende_kesin_karar_verilmez():
    s = _ozet(confidence=40, flags=[{"kod": "az_emsal", "mesaj": "Yalnızca 3 doğrulanmış emsal ilan bulundu"}])
    assert s["karar"]["sonuc"] == LOW_CONFIDENCE_VERDICT
    assert s["karar"]["hesaplananEgilim"] == "PAZARLIK YAP"
    assert s["karar"]["guvenSeviyesi"] == "dusuk"
    assert "7 ilan" in s["ozet"]["simdiNeYapmali"] and "yerinde ekspertiz" in s["ozet"]["simdiNeYapmali"]
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



def test_kalem_metni_ve_beyan_ozeti():
    from yerimebak_ai_v5.services.valuation_service import _beyan_ozeti, _kalem_metni
    assert _kalem_metni({"baslik": "Tramer (hasar kaydı)", "durum": "20.000 TL"}) == "Tramer (hasar kaydı) 20.000 TL"
    assert _kalem_metni({"baslik": "Sol Arka Çamurluk", "durum": "Lokal Boyalı"}) == "Sol Arka Çamurluk (lokal boyalı)"
    assert _kalem_metni({"baslik": "Kaput", "durum": "DEĞİŞEN"}) == "Kaput (değişen)"
    assert _beyan_ozeti("Ekspertizde 1 boyalı parça tespit edildi; bulguların toplam değer kaybı %1,8.") ==         "Beyana göre araçta 1 boyalı parça var; bulguların toplam değer kaybı %1,8."
    assert _beyan_ozeti("Ekspertizde kaporta işlemi tespit edilmedi; x").startswith("Beyana göre araçta kaporta işlemi yok")
    assert _beyan_ozeti(None) is None


def test_buyuk_fiyat_farkinda_once_neden_sorulur():
    """MG HS 2024 örneği: yeni kasa ilanı eski kasa emsallerle %15 pahalı görünüyordu."""
    s = _ozet(price=1_895_000, reference={**REF, "market_median_price": 1_640_000})
    assert any("%16 yüksek" in r and "yeni kasa" in r for r in s["ozet"]["riskler"])
    assert s["ozet"]["simdiNeYapmali"].startswith("Önce satıcıya farkın nedenini sorun")
    normal = _ozet()   # %8,4: eski davranış
    assert "farkın nedenini" not in normal["ozet"]["simdiNeYapmali"]
    assert not any("yeni kasa" in r for r in normal["ozet"]["riskler"])



def test_hasardan_gelen_farkta_neden_sorusu_cikmaz():
    """Egea örneği: hasar düşülünce değer düşük; ilan emsallerin hasarsız ortasına yakınsa kasa sorusu yok."""
    s = _ozet(price=800_000, degerleme={**DEGERLEME, "fiyatYorumu": {"farkYuzde": 23.0}},
              reference={**REF, "market_median_price": 756_000})
    assert "farkın nedenini" not in s["ozet"]["simdiNeYapmali"]
    assert not any("yeni kasa" in r for r in s["ozet"]["riskler"])


def test_cok_ucuz_ilanda_karar_alinabilir_yerine_ek_dogrulama():
    """Kullanıcı kararı (6 Kasım 2026, Seat Ibiza): ilan piyasanın %10+ altındayken üstte 'Alınabilir' yazıp
    altta dolandırıcılık uyarısı vermek çelişkili; karar temkinli olur, eğilim bilgi olarak kalır."""
    temiz = {**DEGERLEME, "kalemler": [], "fiyatYorumu": {"farkYuzde": -29.4}, "aiDegeri": 1_360_000,
             "adilFiyatAraligi": {"min": 1_275_000, "max": 1_440_000}}
    ref = {**REF, "market_avg_price": 1_340_000, "market_median_price": 1_358_000}
    s = _ozet(price=960_000, degerleme=temiz, recommended=946_000, verdict_key="AVANTAJLI",
              karar="AL", karar_aciklama="Avantajlı.", reference=ref)
    assert s["karar"]["sonuc"] == LOW_CONFIDENCE_VERDICT and s["karar"]["hesaplananEgilim"] == "AL"
    assert s["karar"]["guvenSeviyesi"] == "yuksek" and "%29 altında" in s["karar"]["aciklama"]
    # Adım, az veri metni değil düşük fiyat yönlendirmesidir.
    assert "kapora" in s["ozet"]["simdiNeYapmali"] and "az sayıda" not in s["ozet"]["simdiNeYapmali"]
    # %10'un altındaki ucuzlukta karar değişmez (yalnız yumuşak uyarı).
    s = _ozet(price=1_280_000, degerleme=temiz, recommended=1_250_000, verdict_key="AVANTAJLI",
              karar="AL", karar_aciklama="Avantajlı.", reference=ref)
    assert s["karar"]["sonuc"] == "AL" and s["karar"]["hesaplananEgilim"] is None
