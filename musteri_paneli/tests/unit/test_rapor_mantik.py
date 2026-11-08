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
    # Kullanıcı kararı (07.11.2026, BYD Seal U): uyarı tek ölçüyle, hesaplanan değer ve adil aralıkla verilir.
    # Cupra Formentor: ilan 2.265.000, adil aralık 2.205.000–2.485.000 içinde, uyarı yok.
    from yerimebak_ai_v5.services.negotiation import build_plan, dusuk_fiyat_uyarisi
    ref = {"count": 8, "market_avg_price": 2_331_752, "market_median_price": 2_338_115, "samples": []}
    assert dusuk_fiyat_uyarisi(2_265_000, 2_345_000, 2_205_000) is None
    plan = build_plan(price=2_265_000, fair_min=2_205_000, fair_max=2_485_000, recommended=2_275_000,
                      reference=ref, kalemler=[], confidence_level="yuksek", vehicle_title="2023 Cupra Formentor",
                      value=2_345_000)
    assert plan["uyari"] is None and "hesaplanan değerinin altında" in plan["adimlar"][0]
    # Aralığın altında: yumuşak uyarı; %10 ve üstü: kapora uyarısı.
    uyari = dusuk_fiyat_uyarisi(2_180_000, 2_345_000, 2_205_000)
    assert "%7,0 altında" in uyari and "kusuru" in uyari and "yerinde inceletin" in uyari
    assert "kapora" in dusuk_fiyat_uyarisi(2_000_000, 2_345_000, 2_205_000)
    plan = build_plan(price=2_000_000, fair_min=2_205_000, fair_max=2_485_000, recommended=2_275_000,
                      reference=ref, kalemler=[], confidence_level="yuksek", vehicle_title="2023 Cupra Formentor",
                      value=2_345_000)
    assert plan["uyari"].startswith("İlan fiyatı, bildirilen hasar hesaba katıldıktan sonra bile")
    # Hesaplanan değerin üstündeki ilanda bu uyarı yok.
    assert dusuk_fiyat_uyarisi(2_400_000, 2_345_000, 2_205_000) is None


def test_hesaplanan_degere_uyumlu_ilanda_piyasa_alti_denmez_ve_tavsiye_hedefe_esit():
    # BYD Seal U DM-i 2024 (canlı ilk rapor, 07.11.2026): ilan 2.095.000, hesaplanan değer 2.075.000 (%0,9 üstü),
    # benzer ilanların ortası 2.193.260. Eski plan "ortanın altında" deyip hedefi 2.045.000 koyuyor, tavsiye
    # 2.015.000 kalıyor; özet hem "piyasayla uyumlu" hem "piyasanın altında" diyordu.
    from yerimebak_ai_v5.services.negotiation import build_plan, dusuk_fiyat_uyarisi
    ref = {"count": 7, "market_avg_price": 2_198_957, "market_median_price": 2_193_260, "samples": []}
    kalemler = [{"baslik": "Sol Arka Çamurluk", "durum": "Boyalı", "tutar": 57_618}]
    assert dusuk_fiyat_uyarisi(2_095_000, 2_075_000, 1_950_000) is None
    plan = build_plan(price=2_095_000, fair_min=1_950_000, fair_max=2_200_000, recommended=2_015_000,
                      reference=ref, kalemler=kalemler, confidence_level="yuksek",
                      vehicle_title="2024 BYD Seal U DM-i", value=2_075_000)
    assert plan["uyari"] is None
    assert plan["hedefFiyat"] == 2_015_000 and plan["acilisTeklifi"] < plan["hedefFiyat"] <= plan["ustSinir"] <= 2_095_000
    assert plan["acilisTeklifi"] >= 2_095_000 * 0.93 - 5_000
    assert not any("ortasının altında" in a or "hesaplanan değerinin altında" in a for a in plan["adimlar"])
    # Satıcı mesajı (09.11.2026) gerekçe/tutar listelemez; hasar yalnız "boya/değişen bilgisine baktım" diye anılır.
    assert "boya/değişen" in plan["saticiMesaji"] and "57.618" not in plan["saticiMesaji"]


def test_motor_yazilmis_aracta_paket_girilmemis_denmez():
    from yerimebak_ai_v5.services.valuation_service import _uyari_metni
    eski = {"kod": "paket_bilinmiyor", "mesaj": "Araç paketi girilmemiş; emsaller modelin tüm paketlerinden"}
    assert "girilmemiş" not in _uyari_metni(eski, "1.5 TSI")
    assert _uyari_metni(eski, None) == eski["mesaj"]


def test_hasari_beyan_edilmis_ucuz_ilanda_gizli_kusur_uyarisi_yok_ve_plan_tutarli():
    # Chery Tiggo 7 Pro Max denemesi (03.11.2026): 180.000 TL tramer + 2 değişen kapı. İlan hasarsız ortalamanın
    # %10,9 altında ama hasar düşülünce hesaplanan değerin (≈1.445.000) %19,7 üstünde. Eski rapor "gizli kusur"
    # uyarısı veriyor, hedef = üst sınır = 1.530.000 çıkıyor ve tavsiye fiyatıyla (1.400.000) çelişiyordu.
    from yerimebak_ai_v5.services.negotiation import build_plan, dusuk_fiyat_uyarisi
    ref = {"count": 6, "market_avg_price": 1_941_952, "market_median_price": 1_928_809, "samples": []}
    kalemler = [{"baslik": "Tramer (hasar kaydı)", "durum": "180.000 TL", "tutar": 270_000},
                {"baslik": "Sol Ön Kapı", "durum": "Değişen", "tutar": 115_729},
                {"baslik": "Sol Arka Kapı", "durum": "Değişen", "tutar": 98_402}]
    assert dusuk_fiyat_uyarisi(1_730_000, 1_445_000, 1_360_000) is None
    plan = build_plan(price=1_730_000, fair_min=1_360_000, fair_max=1_530_000, recommended=1_400_000,
                      reference=ref, kalemler=kalemler, confidence_level="orta",
                      vehicle_title="2025 Chery Tiggo 7 Pro Max", value=1_445_000)
    assert plan["durum"] == "pazarlik_payi_var"
    assert plan["hedefFiyat"] == 1_400_000 < plan["ustSinir"] == 1_530_000
    assert plan["uyari"] is None
    # Hasar hesaba katıldıktan sonra da aralığın altındaysa uyarı verilir ve bunu açıkça söyler.
    assert "bildirilen hasar hesaba katıldıktan sonra bile" in dusuk_fiyat_uyarisi(1_300_000, 1_445_000, 1_360_000)


def test_birden_cok_degisen_parca_tek_soruda_hepsi_sorulur():
    vehicle = {"brand": "Chery", "model": "Tiggo 7 Pro Max", "year": 2025, "km": 44_000, "fuel": "Benzin",
               "transmission": "Otomatik", "package": "1.6 T-GDI"}
    findings = [{"baslik": "Sol Ön Kapı (değişen)"}, {"baslik": "Sol Arka Kapı (değişen)"},
                {"baslik": "180.000 TL tramer kaydı"}]
    sorular = vr.seller_questions(vehicle, {"riskler": []}, findings)
    parca_sorusu = [q for q in sorular if q.startswith("Beyan edilen")]
    assert parca_sorusu == ["Beyan edilen Sol Ön Kapı (değişen), Sol Arka Kapı (değişen) için hasarın nedeni ve onarım belgeleri var mı?"]


def test_tramer_ile_ayni_hasarin_degisen_parcalari_iki_kez_dusulmez():
    # Chery Tiggo 7 Pro Max (03.11.2026, kullanıcı kararı): 180.000 TL tramer + iki değişen kapı.
    # Eskiden tramer tek başına tutarın 1,5 katı (270.000 TL) düşülüyor, kapılar ayrıca 214.000 TL: toplam %25,1.
    # Şimdi 1,5 kat tabanı kaporta + tramer toplamına uygulanır: toplam %14, karar PAZARLIK.
    from datetime import datetime
    from yerimebak_ai_v5.core.ai.inspection_valuation import evaluate
    market = {"found": True, "source": "web_listings", "count": 6, "market_median_price": 1_928_809,
              "clean_median_price": 1_928_809, "clean_count": 4, "reference_median_year": 2025, "reference_median_km": 44_000}
    r = evaluate({"adim1": {"yil": 2025, "guncelKm": 44_000, "hasarKayitToplamTutar": 180_000},
                  "adim4": {"parcaDurumlari": {"solOnKapi": "degisen", "solArkaKapi": "degisen"}}},
                 market, listed_price=1_730_000, now=datetime(2026, 11, 3))
    assert r["toplamDegerKaybiYuzde"] == 14.0
    assert r["toplamDegerKaybiTutar"] >= 270_000  # en az tramerin 1,5 katı
    assert r["fiyatYorumu"]["karar"] == "PAZARLIK"
    tramer = next(k for k in r["kalemler"] if k["kategori"] == "tramer")
    assert tramer["yuzde"] >= 2.0


def test_elektrikli_ve_hibrit_aracta_batarya_kontrolu_basta():
    # BYD Seal U DM-i (07.11.2026): şarj edilebilir hibritte rapor batarya sağlığını ve garantisini hiç sormuyordu.
    phev = {"fuel": "Benzin (Plug-in Hibrit)", "package": "1.5 PHEV Design", "km": 47_000, "year": 2024,
            "transmission": "Otomatik"}
    basliklar = [m["baslik"] for m in vr.upcoming_maintenance(phev, {"riskler": []})]
    assert basliklar[:2] == ["Yüksek voltaj batarya sağlığı ve garantisi", "Şarj sistemi kontrolü"]
    sorular = vr.seller_questions(phev, {"riskler": []}, [])
    assert any("SoH" in q and "garanti" in q for q in sorular)
    # Kendi kendine şarj olan hibritte şarj sistemi sorulmaz; benzinli araçta (Chevrolet dahil) batarya yok.
    hev = [m["baslik"] for m in vr.upcoming_maintenance({"fuel": "Hibrit", "package": "1.8 HEV", "km": 30_000,
                                                         "year": 2022}, {"riskler": []})]
    assert hev[0] == "Yüksek voltaj batarya sağlığı ve garantisi" and "Şarj sistemi kontrolü" not in hev
    for arac in [{"fuel": "Benzin", "package": "1.5 TSI"}, {"fuel": "Benzin", "package": "Chevrolet Cruze 1.6"}]:
        assert not any("batarya" in m["baslik"] for m in vr.upcoming_maintenance({**arac, "km": 10_000, "year": 2024},
                                                                                  {"riskler": []}))
