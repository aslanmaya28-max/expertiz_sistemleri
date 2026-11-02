"""Kasa geçiş yılı (kullanıcı kararı, 02.11.2026): iki kaynaklı kasa listesi, iki havuz, müşteriye iki kasa."""
import io

import pdfplumber
import pytest

from yerimebak_ai_v5.services import vehicle_generation as g
from yerimebak_ai_v5.services import web_market_reference as wmr

G = lambda k, a, b, f=None: {"kasa": k, "baslangic": a, "bitis": b, "makyaj": f}
# Gerçek denemede iki kaynağın verdiği listeler (aynı soru, farklı cevap)
SONAR = [G("JM", 2004, 2009, 2006), G("LM", 2010, 2015, 2013), G("TL", 2016, 2021, 2018), G("NX4", 2021, 2026, 2024)]
SONAR_PRO = [G("JM", 2005, 2009), G("LM", 2009, 2015, 2013), G("TL", 2015, 2020, 2018), G("NX4", 2020, 2026, 2024)]


def test_iki_kaynak_ayni_yeni_kasada_uyusur_ve_gecis_yili_bulunur():
    r = g.combine(SONAR, SONAR_PRO, 2021)
    assert r["bulundu"] and r["kasa"] == "NX4" and r["gecis_yili"]
    assert g.year_range(r, 2021) == (2021, 2023)
    assert r["onceki"]["kasa"] == "TL" and g.year_range(r["onceki"], 2021) == (2018, 2021)


def test_gecis_yili_olmayan_ve_uyusmayan_kaynaklar():
    egea = g.combine([G("356", 2015, 2026, 2021)], [G("356", 2015, 2026, 2020)], 2019)
    assert egea["bulundu"] and not egea["gecis_yili"] and g.year_range(egea, 2019) == (2016, 2019)
    # Makyaj yılında ayrışıyorlar ve araç arada: yalnız kendi yılı
    assert g.year_range(egea, 2020) == (2020, 2020)
    bozuk = g.combine([G("A", 2015, 2026)], [G("B", 2018, 2026)], 2019)
    assert not bozuk["bulundu"] and bozuk["uyusmazlik"]


def _ref(median, count=6):
    return {"found": True, "market_median_price": median, "count": count, "scope": {"cost_usd": 0.03}}


@pytest.mark.parametrize("kasa,listed,secilen,neden", [
    ("eski", 2_200_000, "eski", "musteri"),
    (None, 2_080_000, "yeni", "ilan_fiyati"),
    (None, 1_880_000, "eski", "ilan_fiyati"),
])
def test_degerleme_kasasi_secimi(kasa, listed, secilen, neden):
    ref = wmr._transition({"year": 2021, "kasa": kasa, "listed_price": listed}, _ref(2_050_000), _ref(1_900_000),
                          G("NX4", 2021, 2026), G("TL", 2015, 2021))
    assert ref["gecis"]["secilen"] == secilen and ref["gecis"]["neden"] == neden
    assert ref["scope"]["cost_usd"] == 0.06
    assert ref["gecis"]["yeni"]["orta_fiyat"] == 2_050_000 and ref["gecis"]["eski"]["orta_fiyat"] == 1_900_000


def test_tek_havuz_bulunursa_o_kullanilir():
    ref = wmr._transition({"year": 2021, "listed_price": 2_000_000}, _ref(2_050_000), {"found": False, "scope": {}},
                          G("NX4", 2021, 2026), G("TL", 2015, 2021))
    assert ref["gecis"]["secilen"] == "yeni" and ref["gecis"]["neden"] == "tek_havuz"
    assert ref["gecis"]["eski"]["bulundu"] is False


def test_get_reference_gecis_yilinda_iki_havuz_arar(monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-fake")
    monkeypatch.setenv("WEB_PRICE_CACHE_HOURS", "0")
    monkeypatch.setattr(g, "get_generation", lambda v, timeout=25.0: {**g.combine(SONAR, SONAR_PRO, 2021), "cost_usd": 0.015})
    asked = []

    def ilan(n, fiyat, yil, paket="1.6 CRDI Elite Plus"):
        return {"url": f"https://galeri{n}.com/tucson/{n}", "fiyat_tl": fiyat, "km": 66000, "yil": yil,
                "paket": paket, "kondisyon": "temiz"}

    belirsiz = ilan(99, 1_990_000, 2021)                  # kasası yazmıyor: iki havuza da girmez
    nx4_2021 = ilan(98, 2_060_000, 2021, "NX4 1.6 CRDI Elite Plus")

    def fake(query, client, **kw):
        asked.append(query)
        if "2021-2023" in query:   # NX4 havuzu: sonraki yıllar + kasası yazan 2021
            items = [ilan(n, 2_150_000 + n * 5_000, 2022) for n in range(1, 4)] +                     [ilan(n, 2_250_000 + n * 5_000, 2023) for n in range(4, 7)] + [nx4_2021, belirsiz]
        else:                      # TL havuzu (2018-2021): önceki yıllar
            items = [ilan(n + 50, 1_700_000 + n * 5_000, 2019) for n in range(1, 4)] +                     [ilan(n + 50, 1_800_000 + n * 5_000, 2020) for n in range(4, 7)] + [belirsiz]
        return {"listings": items, "sources": {i["url"]: f"{i['fiyat_tl']:,} TL".replace(",", ".") for i in items}, "cost": 0.01}

    monkeypatch.setattr(wmr, "_search", fake)
    ref = wmr.get_reference({"brand": "Hyundai", "model": "Tucson", "year": 2021, "km": 66000,
                             "package": "1.6 CRDI Elite Plus", "listed_price": 2_200_000})
    assert any("2021-2023" in q for q in asked) and any("2018-2021" in q for q in asked)
    gecis = ref["gecis"]
    assert gecis["yeni"]["kasa"] == "NX4" and gecis["eski"]["kasa"] == "TL"
    assert gecis["yeni"]["orta_fiyat"] > gecis["eski"]["orta_fiyat"]
    assert gecis["secilen"] == "yeni" and gecis["neden"] == "ilan_fiyati"   # 2,2 milyon NX4'e daha yakın
    assert belirsiz["url"] not in {x["url"] for x in ref["samples"]}
    assert nx4_2021["url"] in {x["url"] for x in ref["samples"]}
    assert ref["scope"]["rejected"]["geçiş yılı belirsiz"] >= 1
    assert ref["scope"]["cost_usd"] == pytest.approx(0.075)                 # 6 arama + kasa listesi


def test_pdf_gecis_yili_bolumu():
    from yerimebak_ai_v5.services.valuation_report_pdf import build_pdf
    report = {
        "arac": {"marka": "Hyundai", "model": "Tucson", "yil": 2021, "km": 66000, "ilanFiyati": 2_200_000},
        "karar": {"sonuc": "PAZARLIK YAP", "aciklama": "-"},
        "degerleme": {"temizPiyasaDegeri": 2_000_000, "tavsiyeFiyat": 1_950_000,
                      "adilFiyatAraligi": {"min": 1_900_000, "max": 2_100_000}, "kalemler": []},
        "piyasa": {"guvenSkoru": 70, "kaynaklar": [], "emsalSayisi": 6, "gecisYili": {
            "yil": 2021, "secilen": "yeni", "neden": "ilan_fiyati",
            "yeni": {"kasa": "NX4", "baslangic": 2021, "bitis": 2026, "ortaFiyat": 2_050_000, "emsal": 6},
            "eski": {"kasa": "TL", "baslangic": 2015, "bitis": 2021, "ortaFiyat": 1_900_000, "emsal": 5}}},
        "rapor": {"id": "t", "report_no": "YD 2026-000009", "created_at": "2026-11-02T10:00:00+00:00",
                  "verification_code": "YD-TEST-2345"},
    }
    with pdfplumber.open(io.BytesIO(build_pdf(report))) as doc:
        text = "\n".join(p.extract_text() for p in doc.pages)
    assert "2021 bu model için kasa geçiş yılı" in text
    assert "TL (2015–2021): 1.900.000 TL" in text and "NX4 (2021–): 2.050.000 TL" in text
    assert "fark yaklaşık 150.000 TL" in text and "NX4 kasasına göre yapıldı" in text



def test_sikayet_bos_kalirsa_bir_kez_daha_aranir(monkeypatch):
    from yerimebak_ai_v5.services import vehicle_risk as vr
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-key")
    monkeypatch.setenv("WEB_RISK_CACHE_DAYS", "0")
    monkeypatch.setattr(vr, "_search", lambda q, c: {"risks": [], "complaints": [], "sources": {}, "cost": .01})
    sv, dh = "https://www.sikayetvar.com/hyundai/tucson/titreme", "https://forum.donanimhaber.com/tucson-dct-titreme"
    asked = []

    def complaints(query, client):
        asked.append(query)
        if len(asked) == 1:
            return {"complaints": [], "cited": {}, "cost": .006}
        return {"complaints": [{"baslik": "DCT şanzıman titremesi", "kaynaklar": [sv, dh]}],
                "cited": {sv: "Tucson", dh: "Tucson"}, "cost": .006}

    monkeypatch.setattr(vr, "_search_complaints", complaints)
    result = vr.get_model_risks({"brand": "Hyundai", "model": "Tucson", "year": 2021, "fuel": "Dizel",
                                 "engine": "1.6 CRDI", "transmission": "Otomatik"})
    assert len(asked) == 2 and "kullanıcı yorumları" in asked[1]
    assert [c["baslik"] for c in result["kullaniciSikayetleri"]] == ["DCT şanzıman titremesi"]
    assert result["scope"]["searches"] == 3 and result["scope"]["cost_usd"] == pytest.approx(.022)


@pytest.mark.parametrize("first,second", [
    # Gerçek denemelerde aynı soruya gelen farklı cevaplar: hepsinde 2021 geçiş yılı, kasa NX4
    ([G("TL", 2016, 2021, 2019), G("NX4", 2022, 2026, 2024)], [G("TL (3. nesil)", 2015, 2021, 2018), G("NX4 (4. nesil)", 2021, 2026, 2024)]),
    ([G("Tucson III", 2016, 2020, 2019), G("Tucson IV", 2021, 2026, 2024)], [G("TL (3. nesil)", 2015, 2020, 2018), G("NX4 (4. nesil)", 2021, 2026, 2024)]),
    ([G("JM", 2004, 2009), G("LM", 2009, 2015), G("TL", 2015, 2020, 2018), G("NX4", 2021, 2026, 2024)],
     [G("1. nesil", 2004, 2010), G("2. nesil", 2015, 2020, 2018), G("3. nesil", 2021, 2026, 2024)]),
])
def test_kaynak_varyantlarinda_ayni_sonuc(first, second):
    r = g.combine(first, second, 2021)
    assert r["bulundu"] and "NX4" in r["kasa"] and r["gecis_yili"]
    assert g.year_range(r, 2021) == (2021, 2023)
    assert "TL" in r["onceki"]["kasa"] or "III" in r["onceki"]["kasa"]
    for year in (2022, 2023):
        assert not g.combine(first, second, year)["gecis_yili"]


def test_musteri_secimi_bulunamazsa_diger_kasaya_gecilmez():
    ref = wmr._transition({"year": 2024, "kasa": "yeni", "listed_price": 1_895_000}, {"found": False, "scope": {}},
                          _ref(1_740_000), G("AS33", 2024, 2026), G("AS23", 2022, 2024))
    assert ref["gecis"]["secilen"] == "yeni" and ref["gecis"]["neden"] == "secilen_bulunamadi"
    assert not ref.get("found")


@pytest.mark.parametrize("ilan,beklenen", [
    ({"paket": "Yeni Luxury", "url": "https://x.test/mg-hs/1"}, None),
    ({"paket": "1.5 T-GDI Luxury", "url": "https://x.test/mg-hs-yeni-luxury-2024/2"}, None),
    ({"paket": "1.5 T-GDI Luxury", "url": "https://x.test/mg-hs-luxury/3", "durum": "yeni lastik takıldı"}, "geçiş yılı belirsiz"),
    ({"paket": "1.5 T-GDI Luxury", "url": "https://x.test/mg-hs-yenilenmis/4"}, "geçiş yılı belirsiz"),
])
def test_yeni_kelimesi_yalniz_baslik_ve_adreste_sayilir(ilan, beklenen):
    full = {"fiyat_tl": 1_900_000, "km": 30000, "yil": 2024, **ilan}
    sources = {ilan["url"]: "1.900.000 TL"}
    v = {"brand": "MG", "model": "HS", "year": 2024, "km": 33100}
    terms = wmr.kasa_terms({"kasa": "AS33"}, True, v)
    assert wmr.verify(full, sources, v, year_range=(2024, 2026), ambiguous_year=2024, terms=terms) == beklenen
