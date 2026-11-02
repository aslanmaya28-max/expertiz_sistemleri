"""Cupra Formentor müşteri denemesinde (02.11.2026) bulunan rapor mantık hataları geri gelmesin."""
from yerimebak_ai_v5.core.ai.inspection_valuation import _summary
from yerimebak_ai_v5.services import vehicle_risk as vr
from yerimebak_ai_v5.services.valuation_service import _beyan_ozeti


def _r(**kw):
    r = {"degisenParcaSayisi": 0, "boyaliParcaSayisi": 0, "yapisalIslemSayisi": 0, "toplamDegerKaybiYuzde": 0,
         "toplamDegerKaybiTutar": 0, "aiDegeri": 2_345_000, "temizPiyasaDegeri": 2_343_669,
         "adilFiyatAraligi": {"min": 2_205_000, "max": 2_485_000}, "ilanFiyati": 2_265_000, "agirHasar": False,
         "fiyatYorumu": {"farkYuzde": -3.4, "aciklama": "İlan fiyatı ekspertiz sonucuyla uyumlu"}}
    r.update(kw)
    return r


def test_deger_kaybi_yokken_dusulerek_yazilmaz_ve_fark_okunur_yazilir():
    text = _summary(_r(), None)
    # Yuvarlanmış değer (2.345.000) temiz değerden (2.343.669) büyük: "düşülerek" çelişkili görünüyordu.
    assert "düşülerek" not in text
    assert "%-3,4" not in text and "hesaplanan değerin %3,4 altında" in text


def test_deger_kaybi_varsa_dusulerek_yazilir():
    assert "düşülerek" in _summary(_r(toplamDegerKaybiTutar=40_000, toplamDegerKaybiYuzde=1.7), None)


def test_kredili_degerlemede_ekspertiz_sonucu_denmez():
    text = _beyan_ozeti(_summary(_r(), None))
    assert text.startswith("Beyana göre araçta kaporta işlemi yok")
    assert "ekspertiz sonucu" not in text and "hesaplanan değerle uyumlu" in text


def test_risk_aramasi_cokerse_hata_isareti_verilir(monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", "test")
    monkeypatch.setenv("WEB_RISK_CACHE_DAYS", "0")

    def bozuk(query, client):
        raise ValueError("Expecting ',' delimiter")

    monkeypatch.setattr(vr, "_search", bozuk)
    monkeypatch.setattr(vr, "_search_complaints", lambda q, c: {"complaints": [], "cited": {}, "cost": 0})
    result = vr.get_model_risks({"brand": "Cupra", "model": "Formentor", "year": 2023, "package": "1.5 TSI"})
    # "Bilinen sorun bulunamadı" denmemeli: bulunamamak ile aranamamak farklıdır.
    assert result["hata"] is True


def test_bakim_maddeleri_ve_sorular_tekrarsiz():
    vehicle = {"brand": "Cupra", "model": "Formentor", "year": 2023, "km": 87_000, "fuel": "Benzin",
               "transmission": "Otomatik", "package": "1.5 TSI"}
    bakim = vr.upcoming_maintenance(vehicle, {"riskler": []})
    assert len({b["aciklama"] for b in bakim}) == len(bakim)
    sorular = vr.seller_questions(vehicle, {"riskler": []}, [])
    assert not any("için son kontrol/bakım" in q for q in sorular)
    assert len(sorular) == len(set(sorular))


def test_ortalamanin_altindaki_ilanda_gizli_kusur_uyarisi():
    from yerimebak_ai_v5.services.negotiation import build_plan, dusuk_fiyat_uyarisi
    ref = {"count": 8, "market_avg_price": 2_331_752, "market_median_price": 2_338_115, "samples": []}
    uyari = dusuk_fiyat_uyarisi(2_265_000, ref)
    assert "%2,9 altında" in uyari and "kusuru" in uyari and "yerinde inceletin" in uyari
    plan = build_plan(price=2_265_000, fair_min=2_205_000, fair_max=2_485_000, recommended=2_275_000,
                      reference=ref, kalemler=[], confidence_level="yuksek", vehicle_title="2023 Cupra Formentor")
    assert plan["uyari"].startswith("İlan fiyatı benzer ilanların ortalamasının")
    # Çok düşük fiyatta uyarı sertleşir: kapora uyarısı.
    assert "kapora" in dusuk_fiyat_uyarisi(2_000_000, ref)
    # Ortalamanın üstündeki ilanda bu uyarı yok.
    assert dusuk_fiyat_uyarisi(2_400_000, ref) is None


def test_motor_yazilmis_aracta_paket_girilmemis_denmez():
    from yerimebak_ai_v5.services.valuation_service import _uyari_metni
    eski = {"kod": "paket_bilinmiyor", "mesaj": "Araç paketi girilmemiş; emsaller modelin tüm paketlerinden"}
    assert "girilmemiş" not in _uyari_metni(eski, "1.5 TSI")
    assert _uyari_metni(eski, None) == eski["mesaj"]


def test_hasari_beyan_edilmis_ucuz_ilanda_gizli_kusur_uyarisi_yok_ve_plan_tutarli():
    # Chery Tiggo 7 Pro Max denemesi (03.11.2026): 180.000 TL tramer + 2 değişen kapı. İlan hasarsız ortalamanın
    # %10,9 altında ama hasar düşülünce hesaplanan değerin %19,7 üstünde. Eski rapor "gizli kusur" uyarısı veriyor,
    # hedef = üst sınır = 1.530.000 çıkıyor ve tavsiye fiyatıyla (1.400.000) çelişiyordu.
    from yerimebak_ai_v5.services.negotiation import build_plan, dusuk_fiyat_uyarisi
    ref = {"count": 6, "market_avg_price": 1_941_952, "market_median_price": 1_928_809, "samples": []}
    kalemler = [{"baslik": "Tramer (hasar kaydı)", "durum": "180.000 TL", "tutar": 270_000},
                {"baslik": "Sol Ön Kapı", "durum": "Değişen", "tutar": 115_729},
                {"baslik": "Sol Arka Kapı", "durum": "Değişen", "tutar": 98_402}]
    assert dusuk_fiyat_uyarisi(1_730_000, ref, 484_131) is None
    plan = build_plan(price=1_730_000, fair_min=1_360_000, fair_max=1_530_000, recommended=1_400_000,
                      reference=ref, kalemler=kalemler, confidence_level="orta", vehicle_title="2025 Chery Tiggo 7 Pro Max")
    assert plan["durum"] == "pazarlik_payi_var"
    assert plan["hedefFiyat"] == 1_400_000 < plan["ustSinir"] == 1_530_000
    assert plan["uyari"] is None
    # Hasar düşüldükten sonra da ucuzsa uyarı verilir ve bunu açıkça söyler.
    assert "bildirilen hasarın etkisi düşüldükten sonra" in dusuk_fiyat_uyarisi(1_300_000, ref, 484_131)


def test_birden_cok_degisen_parca_tek_soruda_hepsi_sorulur():
    vehicle = {"brand": "Chery", "model": "Tiggo 7 Pro Max", "year": 2025, "km": 44_000, "fuel": "Benzin",
               "transmission": "Otomatik", "package": "1.6 T-GDI"}
    findings = [{"baslik": "Sol Ön Kapı (değişen)"}, {"baslik": "Sol Arka Kapı (değişen)"},
                {"baslik": "180.000 TL tramer kaydı"}]
    sorular = vr.seller_questions(vehicle, {"riskler": []}, findings)
    parca_sorusu = [q for q in sorular if q.startswith("Beyan edilen")]
    assert parca_sorusu == ["Beyan edilen Sol Ön Kapı (değişen), Sol Arka Kapı (değişen) için hasarın nedeni ve onarım belgeleri var mı?"]
