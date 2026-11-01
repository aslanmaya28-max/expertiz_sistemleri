# -*- coding: utf-8 -*-
"""Web aramasiyla kaynakli emsal: dogrulama, paket eslesmesi, kontrol isaretleri (ag kullanilmaz)."""
from yerimebak_ai_v5.core.ai.inspection_valuation import evaluate
from yerimebak_ai_v5.services import web_market_reference as wmr

ARONA = {"brand": "Seat", "model": "Arona", "year": 2024, "km": 22000,
         "package": "1.0 EcoTSI Style DSG 115 hb", "fuel": "Benzin", "transmission": "Otomatik"}


def _ilan(url, fiyat, km, paket, yil=2024, durum="hatasız", kondisyon="temiz"):
    return {"url": url, "fiyat_tl": fiyat, "km": km, "yil": yil, "paket": paket, "durum": durum, "kondisyon": kondisyon}


def _arama(ilanlar, sayfalar=None, maliyet=0.009):
    """Sahte arama sonucu: her ilanin sayfa metninde fiyati gecer (sayfalar ile ezilebilir)."""
    kaynaklar = {i["url"]: f"Seat Arona {i['paket']} {i['fiyat_tl']:,} TL".replace(",", ".") for i in ilanlar}
    kaynaklar.update(sayfalar or {})
    return {"listings": ilanlar, "sources": kaynaklar, "cost": maliyet}


STYLE = [
    _ilan("https://www.batidan2.com/arona-style/884", 1_474_900, 43_745, "1.0 EcoTSI Style DSG"),
    _ilan("https://www.otoshops.com/seat-arona-10_ecotsi_style_dsg_115hp-2024-30167", 1_550_000, 32_500, "1.0 EcoTSI Style DSG 115HP"),
    _ilan("https://www.arabam.com/ilan/sahibinden-satilik-seat-arona-1-0-ecotsi-style/1", 1_565_000, 30_000, "1.0 EcoTSI Style"),
]
FR = [
    _ilan(f"https://www.arabam.com/ilan/seat-arona-1-0-ecotsi-fr/{n}", fiyat, 20_000, "1.0 EcoTSI FR")
    for n, fiyat in enumerate((1_635_000, 1_645_000, 1_679_000, 1_699_900, 1_720_000))
]


def test_fiyat_sayfada_yoksa_ve_kaynak_degilse_reddedilir():
    uydurma = _ilan("https://www.arabam.com/ilan/uydurma/9", 1_400_000, 25_000, "1.0 EcoTSI Style")
    kaynak_disi = _ilan("https://www.sahibinden.com/ilan/kaynakta-yok", 1_500_000, 25_000, "1.0 EcoTSI Style")
    sonuc = _arama([uydurma], sayfalar={uydurma["url"]: "Seat Arona 1.390.000 TL"})
    sonuc["listings"].append(kaynak_disi)
    assert wmr.verify(uydurma, sonuc["sources"], ARONA) == "fiyat sayfada yok"
    assert wmr.verify(kaynak_disi, sonuc["sources"], ARONA) == "kaynaklarda yok"


def test_tahmin_sitesi_yil_km_motor_filtreleri():
    tahmin = _ilan("https://kacasatar.com/arac/seat/arona/2024", 1_500_000, 22_000, "Style")
    eski = _ilan("https://x.com/a", 1_200_000, 22_000, "1.0 EcoTSI Style", yil=2021)
    cok_km = _ilan("https://x.com/b", 1_300_000, 140_000, "1.0 EcoTSI Style")
    baska_motor = _ilan("https://x.com/c", 1_700_000, 25_000, "1.5 EcoTSI FR")
    kaynaklar = _arama([tahmin, eski, cok_km, baska_motor])["sources"]
    assert wmr.verify(tahmin, kaynaklar, ARONA) == "tahmin sitesi"
    assert wmr.verify(eski, kaynaklar, ARONA) == "yıl uyumsuz"
    assert wmr.verify(cok_km, kaynaklar, ARONA) == "km uzak"
    assert wmr.verify(baska_motor, kaynaklar, ARONA) == "motor uyumsuz"
    # url'deki "1-0" motor hacmi olarak okunur
    assert wmr.verify(STYLE[2], _arama(STYLE)["sources"], ARONA) is None


def test_paket_ayiklama():
    assert wmr.trim_tokens("1.0 EcoTSI Style DSG 115 hb") == ["style"]
    assert wmr.trim_tokens("1.5 TSI FR DSG") == ["fr"]
    assert wmr.trim_tokens("") == []


def test_ayni_paket_yeterliyse_yalnizca_o_paket_kullanilir():
    ref = wmr.build_reference([_arama(STYLE + FR[:2]), _arama(FR[2:])], ARONA)
    assert ref["found"] and ref["source"] == "web_listings"
    assert ref["package_match"] is True
    assert ref["count"] == 3
    assert ref["market_median_price"] == 1_550_000
    assert {s["site"] for s in ref["samples"]} == {"batidan2.com", "otoshops.com", "arabam.com"}
    assert ref["clean_count"] == 3  # "hatasız" beyanı
    kodlar = {f["kod"] for f in ref["kontrol"]}
    assert "az_emsal" in kodlar          # 3 < 5
    assert "paket_eslesmedi" not in kodlar
    assert ref["scope"]["searches"] == 2 and ref["scope"]["cost_usd"] == 0.018


def test_ayni_paket_azsa_tum_paketler_ve_isaret():
    ref = wmr.build_reference([_arama(STYLE[:1] + FR)], ARONA)
    assert ref["found"] and ref["package_match"] is False
    assert "paket_eslesmedi" in {f["kod"] for f in ref["kontrol"]}


def test_ayni_ilan_tekrar_sayilmaz_ve_aykiri_atilir():
    aykiri = _ilan("https://www.neziroglu.com.tr/arona/1", 950_000, 20_000, "1.0 EcoTSI Style")
    ref = wmr.build_reference([_arama(STYLE + [aykiri]), _arama(STYLE)], ARONA)
    assert ref["raw_count"] == 4
    assert ref["count"] == 3
    assert 950_000 not in [s["price"] for s in ref["samples"]]


def test_uc_ilandan_az_ise_referans_yok():
    ref = wmr.build_reference([_arama(STYLE[:2])], ARONA)
    assert ref["found"] is False and ref["count"] == 2


def test_anahtar_yoksa_kapali(monkeypatch):
    monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)
    assert wmr.enabled() is False
    assert wmr.get_reference(ARONA) is None


def test_get_reference_uc_sorgu_birlestirir(monkeypatch):
    monkeypatch.delenv("WEB_PRICE_SEARCHES", raising=False)
    sorgular = []

    def sahte(q):
        sorgular.append(q)
        return _arama(STYLE + FR)

    ref = wmr.get_reference(ARONA, search=sahte)
    assert len(sorgular) == 3 and "Style" in sorgular[0]
    assert ref["count"] == 3 and ref["package_match"]


def test_degerleme_motoru_web_emsalini_gercek_emsal_sayar():
    ref = wmr.build_reference([_arama(STYLE + [
        _ilan(f"https://www.arabam.com/ilan/arona-style/{n}", f, 28_000, "1.0 EcoTSI Style")
        for n, f in enumerate((1_520_000, 1_580_000))
    ])], ARONA)
    assert ref["count"] == 5 and not any(f["kod"] == "az_emsal" for f in ref["kontrol"])
    sonuc = evaluate({"adim1": {"guncelKm": 22000, "yil": 2024}, "adim4": {"parcaDurumlari": {}}},
                     ref, listed_price=1_590_000, vehicle={"km": 22000, "yil": 2024})
    assert sonuc["degerlemeYapildi"] is True
    assert sonuc["piyasaKaynagi"] == "web_listings"
    assert "web aramasıyla" in sonuc["piyasaYontemi"]
    # Emsallerden daha az km: yukari duzeltme
    assert any(a["baslik"] == "Kilometre farkı" and a["yuzde"] > 0 for a in sonuc["piyasaDuzeltmeleri"])
    # Veritabani emsalleri gibi guven tavanina (25) takilmaz
    assert sonuc["guvenSkoru"] > 25


def test_kondisyon_model_secimi_olumsuz_cumleleri_hasar_saymaz():
    assert wmr._condition({"kondisyon": "temiz", "durum": "değişen yok, ağır hasar kayıtlı değil"}) == "clean"
    assert wmr._condition({"kondisyon": "Ağır hasarlı"}) == "heavy"
    assert wmr._condition({"durum": "değişen yok", "url": "https://x.com/arona-hatasiz-boyasiz"}) == "clean"
    assert wmr._condition({"durum": "değişen yok"}) == "unknown"


def test_agir_hasarli_ilan_emsal_olmaz():
    pert = _ilan("https://www.arabam.com/ilan/arona-pert/7", 1_000_000, 25_000, "1.0 EcoTSI Style", kondisyon="agir_hasarli")
    ref = wmr.build_reference([_arama(STYLE + [pert])], ARONA)
    assert ref["count"] == 3 and ref["scope"]["rejected"] == {"ağır hasarlı": 1}
