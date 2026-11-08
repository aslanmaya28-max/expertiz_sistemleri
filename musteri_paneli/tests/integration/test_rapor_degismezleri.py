"""Sentetik emsal/risk verisiyle gerçek analyze ve kalıcı raporun değişmezleri.

Piyasa doğrulama ve kayıp oranları bu testlerin konusu değildir. Yalnız dış arama
sınırları sahtedir; API, değerleme, pazarlık, kredi düşümü ve arşiv gerçektir.
``SENARYOLAR`` ve ``rapor_uret`` PDF eşliği testlerinin de ortak arayüzüdür.
"""
from copy import deepcopy
from datetime import date
import json
import re
from statistics import mean, median
import unicodedata
import uuid

import pytest

from .test_dispatch_flow import client, customer_token, _auth, TEST_DB  # noqa: F401
from .test_credit_admin_flow import sql
from yerimebak_ai_v5.services import pricing_service, valuation_service, vehicle_risk

pytestmark = pytest.mark.skipif(not TEST_DB, reason="TEST_DATABASE_URL tanımlı değil")

SENARYOLAR = [
    "hasarsiz_biraz_ucuz", "hasarsiz_yuzde15_ucuz", "hasarsiz_pahali",
    "hasar_sonrasi_pahali_chery", "yalniz_tramer", "boyali_parca",
    "az_emsal_3", "az_emsal_4", "kasa_gecis_yili",
    "risk_hatasi_sikayet_var", "risk_ve_sikayet_yok", "enflasyon_yok",
    "ortalama_medyan_farkli", "ekspertiz_raporlu",
]


def _metinler(value):
    """Raporun iç içe tüm müşteri metinlerini dolaş; yalnız seçilmiş alanlara bakma."""
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from _metinler(item)
    elif isinstance(value, list):
        for item in value:
            yield from _metinler(item)


def _normal(text):
    text = unicodedata.normalize("NFKD", text.casefold().replace("ı", "i"))
    return " ".join("".join(c for c in text if not unicodedata.combining(c)).split())


def _ters_piyasa_iddiasi(text, direction):
    yon = "(?:ustunde|uzerinde)" if direction == "ustunde" else "altinda"
    return re.search(
        rf"(?:piyasanin|(?:piyasa |benzer ilanlarin )?ortalama(?:si)?nin|benzer ilanlarin ortasinin)"
        rf"[^.\n]{{0,90}}\b{yon}\b", _normal(text))


@pytest.mark.parametrize("text,direction", [
    ("Piyasanın altında", "altinda"), ("Piyasanın %5 altında", "altinda"),
    ("Benzer ilanların ortalamasının %25,1 altında.", "altinda"),
    ("Ortalamanın biraz altında", "altinda"), ("Benzer ilanların ortasının altında", "altinda"),
    ("Piyasanın üstünde", "ustunde"), ("Piyasanın %15 üzerinde", "ustunde"),
    ("Piyasa ortalamasının üzerinde", "ustunde"),
])
def test_piyasa_iddiasi_kontrolu_tam_ve_varyant_ifadeleri_yakalar(text, direction):
    assert _ters_piyasa_iddiasi(text, direction)


def _referans(senaryo):
    count = 3 if senaryo == "az_emsal_3" else 4 if senaryo == "az_emsal_4" else 6
    # Hedef araç 2023: eski ucuz 2022 ilanı kanıt olamaz. Medyan yılın 2022
    # olması, hedef yıl yerine yanlışlıkla medyan yıl kullanılması hatasını yakalar.
    samples = [
        {"site": "arabam.com", "url": f"https://www.arabam.com/ilan/sentetik-degismez/{i}",
         "price": price, "year": year, "km": 60000, "condition": "clean"}
        for i, (price, year) in enumerate([
            (800000, 2022), (820000, 2023), (830000, 2024),
            (1170000, 2022), (1180000, 2022), (1200000, 2022),
        ][:count])
    ]
    if senaryo == "ortalama_medyan_farkli":
        # Altı fiyatın medyanı 1 milyon, ortalaması 1,2 milyon. Özetin
        # medyanla, düşük fiyat uyarısının ortalamayla ters karar vermesini yakala.
        samples[-1]["price"] = 2400000
    ref = {
        "found": True, "count": count, "clean_count": count, "source": "web_listings",
        "market_avg_price": round(mean(s["price"] for s in samples)),
        "market_median_price": round(median(s["price"] for s in samples)),
        "market_min_price": min(s["price"] for s in samples),
        "market_max_price": max(s["price"] for s in samples),
        "reference_median_km": 60000, "reference_median_year": int(median(s["year"] for s in samples)),
        "same_year_count": sum(s["year"] == 2023 for s in samples), "confidence": 80,
        "samples": samples, "scope": {"cost_usd": 0, "cached": False}, "kontrol": [],
    }
    if count < 5:
        ref["kontrol"] = [{"kod": "az_emsal", "mesaj": "Az sayıda emsal bulundu"}]
    if senaryo == "kasa_gecis_yili":
        ref["scope"].update(normalized=True, yearly_rate=0.03, year_range=[2023, 2024],
                            generation={"kasa": "Sentetik yeni kasa"})
        ref["gecis"] = {
            "yil": 2023, "secilen": "yeni", "neden": "musteri",
            "yeni": {"bulundu": True, "kasa": "Sentetik yeni kasa", "baslangic": 2023,
                     "bitis": None, "orta_fiyat": 1000000, "emsal": count},
            "eski": {"bulundu": True, "kasa": "Sentetik eski kasa", "baslangic": 2018,
                     "bitis": 2023, "orta_fiyat": 900000, "emsal": 5},
        }
    return ref


def _riskler(senaryo):
    complaints = [] if senaryo == "risk_ve_sikayet_yok" else [{
        "baslik": "Düşük hızda titreşim bildirimi", "aciklama": "Sentetik kullanıcı bildirimi.",
        "kaynakSayisi": 2, "kaynaklar": ["https://yorum.example/sentetik/1", "https://forum.example/sentetik/2"],
    }]
    risks = [] if senaryo in ("risk_hatasi_sikayet_var", "risk_ve_sikayet_yok") else [{
        "baslik": "Periyodik kayış kontrolü", "aciklama": "Servis periyodunda kayış kontrolü önerilir.",
        "etkiledigi": "Sentetik motor", "belirtiler": ["Ses"], "kontrol": "Servis kaydını doğrulatın.",
        "tahminiMaliyet": {"min": 8000, "max": 12000},
        "kaynaklar": ["https://servis.example/sentetik/bakim"], "guven": "orta",
    }]
    return {"riskler": risks, "kullaniciSikayetleri": complaints, "bulunamadi": not risks,
            "hata": senaryo == "risk_hatasi_sikayet_var",
            "scope": {"cost_usd": 0, "searches": 1}}


@pytest.fixture
def rapor_uret(client, customer_token, monkeypatch):
    """Senaryo adı -> tam API raporu; her çağrı benzersiz istek ve gerçek arşiv kaydıdır."""
    headers = _auth(customer_token)
    uid = client.get("/api/v1/auth/me", headers=headers).json()["user"]["id"]
    sql("UPDATE users SET credits=1000 WHERE id=%s", (uid,))
    pricing_service.ensure_schema()

    def uret(senaryo):
        assert senaryo in SENARYOLAR
        # Gerçek getiri hesabını da çalıştır; yalnız oransız senaryoda ayarı kaldır.
        if senaryo == "enflasyon_yok":
            sql("DELETE FROM system_settings WHERE key='vehicle_inflation'")
        else:
            sql("""INSERT INTO system_settings (key,value) VALUES ('vehicle_inflation', %s::jsonb)
                   ON CONFLICT (key) DO UPDATE SET value=EXCLUDED.value""",
                (json.dumps({"monthly_pct": 1.1, "note": "Sentetik test varsayımı", "effective_date": date.today().isoformat()}),))
        price = {"hasarsiz_biraz_ucuz": 970000, "hasarsiz_yuzde15_ucuz": 850000,
                 "hasar_sonrasi_pahali_chery": 900000}.get(senaryo, 1100000)
        payload = {"brand": "Sentetik", "model": "Senaryo", "package": "1.0 Test",
                   "year": 2023, "km": 60000, "fuel": "Benzin", "transmission": "Otomatik",
                   "listed_price": price, "parts": {}, "tramer_amount": 0,
                   "request_id": str(uuid.uuid4())}
        if senaryo == "hasar_sonrasi_pahali_chery":
            payload.update(brand="Chery", model="Tiggo 7 Pro Max", tramer_amount=180000,
                           parts={"solOnKapi": "degisen", "sagOnKapi": "degisen"})
        elif senaryo == "yalniz_tramer":
            payload["tramer_amount"] = 120000
        elif senaryo == "boyali_parca":
            payload["parts"] = {"kaput": "boyali"}
        elif senaryo == "ekspertiz_raporlu":
            payload.update(kaynak_turu='ekspertiz_raporu', ekspertiz_firma_adi='Sentetik Ekspertiz',
                           ekspertiz_rapor_tarihi='2026-11-05', parts={'kaput': 'boyali'},
                           bulgular=[{'kategori': 'motor', 'metin': 'Motorda yağ kaçağı görüldü', 'ciddiyet': 'ciddi'},
                                     {'kategori': 'kaporta', 'metin': 'Tamponda çizik görüldü', 'ciddiyet': 'pazarlik'}])
        elif senaryo == "kasa_gecis_yili":
            payload["kasa"] = "yeni"
        reference, risks = _referans(senaryo), _riskler(senaryo)
        monkeypatch.setattr(valuation_service.web_market_reference, "get_reference", lambda _v: deepcopy(reference))
        monkeypatch.setattr(vehicle_risk, "get_model_risks", lambda _v: deepcopy(risks))
        response = client.post("/api/v1/valuation/analyze", headers=headers, json=payload)
        assert response.status_code == 200, response.text
        body = response.json()
        if senaryo == 'ekspertiz_raporlu':
            assert 'Motorda yağ kaçağı' in body['ozet']['riskler'][0]
            assert body['ozet']['simdiNeYapmali'].startswith('Önce')
            assert 'Motorda yağ' not in str(body['pazarlikPlani']['gerekceler'])
            assert 'Tamponda çizik' in str(body['pazarlikPlani']['gerekceler'])
            assert any(x['kaynak'] == 'ekspertiz_raporu' for x in body['bilgiKaynaklari'])
        assert body["kredi"]["dusulen"] == 1
        stored = sql("SELECT report_json FROM analysis_history WHERE id=%s AND user_id=%s",
                     (body["rapor"]["id"], uid), True)
        assert len(stored) == 1
        for key in ("arac", "piyasa", "degerleme", "pazarlikPlani", "ozet", "modelRiskleri", "getiri"):
            assert stored[0]["report_json"][key] == body[key], f"Arşiv/API farkı: {key}"
        if senaryo == "hasar_sonrasi_pahali_chery":
            assert body["arac"]["beyanEdilenParcalar"] == payload["parts"]
            assert body["degerleme"]["toplamDegerKaybiTutar"] > 0
            assert body["degerleme"]["aiDegeri"] < price < body["piyasa"]["ortalama"]
            assert body["ozet"]["piyasaKonumu"]["durum"] == "ustunde"
        if senaryo.startswith("az_emsal_"):
            assert body["piyasa"]["emsalSayisi"] == int(senaryo.rsplit("_", 1)[1])
            assert body["karar"]["guvenSeviyesi"] == "dusuk"
        if senaryo == "ortalama_medyan_farkli":
            assert body["piyasa"]["medyan"] < price < body["piyasa"]["ortalama"]
            assert body["ozet"]["piyasaKonumu"]["durum"] == "ustunde"
        if senaryo == "kasa_gecis_yili":
            assert body["piyasa"]["gecisYili"]["secilen"] == "yeni"
            assert body["piyasa"]["gecisYili"]["yil"] == body["arac"]["yil"]
            assert body["piyasa"]["duzeltme"]["kasa"] == "Sentetik yeni kasa"
        return body

    return uret


@pytest.mark.parametrize("senaryo", SENARYOLAR)
def test_fiyat_sirasi_ve_pazarlik_payi(rapor_uret, senaryo):
    body = rapor_uret(senaryo)
    plan = body["pazarlikPlani"]
    assert plan["acilisTeklifi"] < plan["hedefFiyat"] <= plan["ustSinir"] <= body["arac"]["ilanFiyati"]
    if plan["durum"] == "pazarlik_payi_var":
        assert plan["hedefFiyat"] < plan["ustSinir"]


@pytest.mark.parametrize("senaryo", SENARYOLAR)
def test_tavsiye_hedefle_ayni_ve_ilani_asmiyor(rapor_uret, senaryo):
    body = rapor_uret(senaryo)
    assert body["degerleme"]["tavsiyeFiyat"] == body["pazarlikPlani"]["hedefFiyat"]
    assert body["degerleme"]["tavsiyeFiyat"] <= body["arac"]["ilanFiyati"]


@pytest.mark.parametrize("senaryo", SENARYOLAR)
def test_piyasa_konumu_tum_metinlerde_tutarli(rapor_uret, senaryo):
    body = rapor_uret(senaryo)
    durum = body["ozet"]["piyasaKonumu"]["durum"]
    ters = "altinda" if durum == "ustunde" else "ustunde" if durum == "altinda" else None
    if ters:
        for text in _metinler(body):
            assert not _ters_piyasa_iddiasi(text, ters), text


@pytest.mark.parametrize("senaryo", SENARYOLAR)
def test_saticiya_ilani_asan_piyasa_rakami_gerekce_yapilmaz(rapor_uret, senaryo):
    body = rapor_uret(senaryo)
    plan, price = body["pazarlikPlani"], body["arac"]["ilanFiyati"]
    for text in [plan["saticiMesaji"], *plan["gerekceler"], *body["ozet"]["pazarlikGerekceleri"]]:
        # Piyasa/emsal gerekçesi içindeki TL tutarları alıcının aleyhine olamaz.
        if re.search(r"benzer|emsal|piyasa|adil aralik", _normal(text)):
            for amount in re.findall(r"\b(\d{1,3}(?:\.\d{3})+|\d+)\s*TL", text):
                assert int(amount.replace(".", "")) <= price, text


@pytest.mark.parametrize("senaryo", SENARYOLAR)
def test_kanit_ilanlari_daha_ucuz_ve_en_az_hedef_yilinda(rapor_uret, senaryo):
    body = rapor_uret(senaryo)
    evidence = body["pazarlikPlani"]["kanitIlanlar"]
    assert evidence, "Sentetik veride hedef yıl ve daha yeni ucuz ilanlar var"
    assert any(e["yil"] == body["arac"]["yil"] for e in evidence)
    assert any(e["yil"] > body["arac"]["yil"] for e in evidence)
    for item in evidence:
        assert item["fiyat"] < body["arac"]["ilanFiyati"]
        assert item["yil"] >= body["arac"]["yil"]


@pytest.mark.parametrize("senaryo", SENARYOLAR)
def test_ozet_ve_planin_ilk_gerekceleri_ayni(rapor_uret, senaryo):
    body = rapor_uret(senaryo)
    assert body["ozet"]["pazarlikGerekceleri"] == body["pazarlikPlani"]["gerekceler"][:3]


def test_risk_aramasi_hatasi_bulunamadi_diye_sunulmaz(rapor_uret):
    body = rapor_uret("risk_hatasi_sikayet_var")
    assert body["kullaniciSikayetleri"]
    text = _normal(body["modelRiskleri"]["mesaj"])
    assert "tamamlanamadi" in text
    assert "bulunamadi" not in text


@pytest.mark.parametrize("senaryo", SENARYOLAR)
def test_sikayet_varken_kosulsuz_bilinen_sorun_yok_denmez(rapor_uret, senaryo):
    body = rapor_uret(senaryo)
    if body["kullaniciSikayetleri"]:
        for text in _metinler(body):
            normal = _normal(text)
            assert not re.search(r"bilinen (?:teknik )?sorun(?:lar)? bulunamadi", normal), text
        if not body["modelRiskleri"]["riskler"]:
            assert "sikayet" in _normal(body["modelRiskleri"]["mesaj"])
    else:
        assert senaryo == "risk_ve_sikayet_yok"
        assert body["modelRiskleri"]["riskler"] == []
        assert "bulunamadi" in _normal(body["modelRiskleri"]["mesaj"])


@pytest.mark.parametrize("senaryo", SENARYOLAR)
def test_getiri_yoksa_gelecek_deger_kaynagi_yok(rapor_uret, senaryo):
    body = rapor_uret(senaryo)
    gelecek = [s for s in body["bilgiKaynaklari"] if "gelecek deger" in _normal(s["alan"])]
    if senaryo == "enflasyon_yok":
        assert body["getiri"] is None
        assert not gelecek
    else:
        assert body["getiri"] is not None
        assert gelecek


# Yapılmış bir ekspertize dayanıyormuş gibi konuşan ifadeler. "Son fiyatı ekspertiz sonucuna bağlayın" ve
# "ekspertiz sonucu beyanla uyumlu çıkarsa" gibi gelecekteki incelemeye yönlendiren öneriler serbesttir.
_YAPILMIS_EKSPERTIZ = re.compile(
    r"ekspertiz sonucu(?:yla| ile)|ekspertiz sonucuna gore|ekspertizde (?:.{0,40})tespit edil|ekspertiz bulgu")


@pytest.mark.parametrize("text,yasak", [
    ("İlan fiyatı ekspertiz sonucuyla uyumlu", True),
    ("İlan fiyatı ekspertiz sonucuna göre piyasanın altında", True),
    ("Ekspertizde kaporta işlemi tespit edilmedi", True),
    ("Son fiyatı ekspertiz sonucuna bağlayın: incelemede beyan dışı hasar çıkarsa fiyat yeniden konuşulur.", False),
    ("Ekspertiz sonucu beyanla uyumlu çıkarsa 950.000 TL teklif etmek istiyorum", False),
])
def test_yapilmis_ekspertiz_ifadesi_kontrolu(text, yasak):
    assert bool(_YAPILMIS_EKSPERTIZ.search(_normal(text))) is yasak


@pytest.mark.parametrize("senaryo", SENARYOLAR)
def test_ekspertiz_yapilmadan_ekspertiz_sonucu_denmez(rapor_uret, senaryo):
    for text in _metinler(rapor_uret(senaryo)):
        assert not _YAPILMIS_EKSPERTIZ.search(_normal(text)), text


@pytest.mark.parametrize("senaryo", SENARYOLAR)
def test_bakim_aciklamalari_ve_satici_sorulari_tekrarsiz(rapor_uret, senaryo):
    body = rapor_uret(senaryo)
    for values in ([b["aciklama"] for b in body["bakim"] if b.get("aciklama")], body["saticiSorulari"]):
        normalized = [_normal(v).rstrip(".?!") for v in values]
        assert len(normalized) == len(set(normalized)), values


@pytest.mark.parametrize("senaryo", SENARYOLAR)
def test_yuzdeler_turkce_isaret_ve_ondalik_biciminde(rapor_uret, senaryo):
    texts = list(_metinler(rapor_uret(senaryo)))
    assert any(re.search(r"%\d+,\d", text) for text in texts), "Ondalık yüzdeyi sınayan metin üretilmeli"
    for text in texts:
        assert not re.search(r"%-|\d+(?:[.,]\d+)?\s*%|%\d+\.\d+", text), text
