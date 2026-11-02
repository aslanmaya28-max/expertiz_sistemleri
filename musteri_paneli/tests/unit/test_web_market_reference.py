# -*- coding: utf-8 -*-
"""Web aramasiyla kaynakli emsal: dogrulama, paket eslesmesi, kontrol isaretleri (ag kullanilmaz)."""
from yerimebak_ai_v5.core.ai.inspection_valuation import evaluate
from yerimebak_ai_v5.services import web_market_reference as wmr
import pytest


@pytest.fixture(autouse=True)
def no_database_cache(monkeypatch):
    monkeypatch.setenv("WEB_PRICE_CACHE_HOURS", "0")

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
    assert len(sorgular) == 6 and "Style" in sorgular[0]
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


def test_onbellek_anahtari_sadelestirme_ve_km_kovasi():
    base = {**ARONA, "brand": "  ŞEAT  ", "km": 20000}
    assert wmr._cache_key(base) == wmr._cache_key({**base, "brand": "seat", "km": 39999})
    for field, value in (("brand", "Fiat"), ("model", "Ibiza"), ("year", 2023),
                         ("package", "FR"), ("fuel", "Dizel"), ("transmission", "Manuel"), ("km", 40000)):
        assert wmr._cache_key(base) != wmr._cache_key({**base, field: value})


def test_onbellek_suresi(monkeypatch):
    monkeypatch.delenv("WEB_PRICE_CACHE_HOURS")
    assert wmr._cache_hours() == 24
    monkeypatch.setenv("WEB_PRICE_CACHE_HOURS", "0")
    assert wmr._cache_hours() == 0
    monkeypatch.setenv("WEB_PRICE_CACHE_HOURS", "2")
    assert wmr._cache_hours() == 2


def test_onbellek_db_hatasinda_arama_surer(monkeypatch):
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    monkeypatch.setenv("WEB_PRICE_CACHE_HOURS", "24")

    def broken():
        raise RuntimeError("DB kapalı")

    monkeypatch.setattr(DatabaseConfig, "get_connection", broken)
    ref = wmr.get_reference(ARONA, search=lambda q: _arama(STYLE))
    assert ref["found"] and ref["market_median_price"] == 1_550_000


@pytest.mark.parametrize("age_hours, expected_searches", [(1, 0), (25, 6)])
def test_onbellekten_donus_ve_sure_dolunca_yeniden_arama(monkeypatch, age_hours, expected_searches):
    from datetime import datetime, timedelta, timezone
    from unittest.mock import MagicMock
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    cached = wmr.build_reference([_arama(STYLE)], ARONA)
    conn = MagicMock()
    conn.cursor.return_value.__enter__.return_value.fetchone.return_value = {
        "reference": cached, "created_at": datetime.now(timezone.utc) - timedelta(hours=age_hours),
    }
    monkeypatch.setenv("WEB_PRICE_CACHE_HOURS", "24")
    monkeypatch.setattr(wmr, "_schema_ready", True)
    monkeypatch.setattr(DatabaseConfig, "get_connection", lambda: conn)
    monkeypatch.setattr(DatabaseConfig, "return_connection", lambda c: None)
    calls = []

    def search(q):
        calls.append(q)
        return _arama(STYLE)

    ref = wmr.get_reference({**ARONA, "listed_price": 1600000}, search=search)
    assert ref["market_median_price"] == 1550000
    assert len(calls) == expected_searches
    if expected_searches == 0:
        assert ref["scope"]["cached"] and ref["scope"]["cost_usd"] == 0
    else:
        assert ref["scope"]["cost_usd"] == 0.054
    assert ref["scope"]["listed_price"] == 1600000


def test_onbellek_kapaliyken_okuma_yazma_yapilmaz(monkeypatch):
    def forbidden(*args):
        pytest.fail("Önbellek kapalıyken veritabanına gidilmemeli")

    monkeypatch.setattr(wmr, "_cache_read", forbidden)
    monkeypatch.setattr(wmr, "_cache_write", forbidden)
    assert wmr.get_reference(ARONA, search=lambda q: _arama(STYLE))["found"]


def test_ikinci_tur_yil_km_bandi_birlesim_maliyet_ve_url_tekillestirme():
    calls = []
    expanded = [
        _ilan("https://galerim.com/arona/4", 1_540_000, 60_000, "1.0 Style", yil=2022),
        _ilan("https://galerim.com/arona/5", 1_560_000, 70_000, "1.0 Style", yil=2026),
    ]
    duplicate = {**STYLE[0], "fiyat_tl": 1_475_000}

    def search(query):
        calls.append(query)
        return _arama(STYLE if len(calls) <= 3 else expanded + [duplicate])

    ref = wmr.get_reference(ARONA, search=search)
    assert len(calls) == 6
    assert ref["found"] and ref["count"] == 5
    assert len({s["url"] for s in ref["samples"]}) == 5
    assert ref["scope"]["widened"] and ref["scope"]["year_window"] == 2
    assert ref["scope"]["cost_usd"] == 0.054
    assert any("2022-2026" in q for q in calls[3:])
    assert all("±2" in q for q in calls[3:])


def test_hedef_bes_ise_ikinci_tur_yok():
    calls = []
    listings = STYLE + [_ilan(f"https://galerim.com/{n}", 1_550_000, 25_000, "1.0 Style") for n in (4, 5)]
    ref = wmr.get_reference(ARONA, search=lambda q: calls.append(q) or _arama(listings))
    assert len(calls) == 3 and ref["count"] == 5
    assert ref["scope"]["widened"] is False and ref["scope"]["year_window"] == 1


@pytest.mark.parametrize("count, found", [(2, False), (3, True), (4, True)])
def test_iki_tur_sonunda_alt_sinir_ve_hedef_farki(count, found):
    calls = []
    listings = STYLE + [_ilan("https://galerim.com/4", 1_550_000, 25_000, "1.0 Style")]
    ref = wmr.get_reference(ARONA, search=lambda q: calls.append(q) or _arama(listings[:count]))
    assert len(calls) == 6 and ref["count"] == count
    assert ref["found"] is found


def test_aykiri_atilinca_uc_altina_duserse_referans_yok():
    listings = [*STYLE[:2], _ilan("https://galerim.com/cheap", 100_000, 25_000, "1.0 Style")]
    ref = wmr.build_reference([_arama(listings)], ARONA)
    assert ref["found"] is False and ref["count"] == 2


def test_site_yonlendirmesi_ihale_reddi_ve_site_olcumleri():
    qs = wmr.queries(ARONA)
    assert len(qs) == 3 and all("sahibinden" not in q for q in qs)
    assert "otosahibi" in qs[1] and "borusannext" in qs[2]
    assert set(wmr.LISTING_SITES) == {"arabam.com", "otosahibi.com", "otonomi.com", "tr.vava.cars", "otokocikinciel.com", "dogusoto.com.tr", "borusannext.com", "otoplus.com", "letgo.com", "carvak.com", "satariz.com", "otoshops.com"}
    auctions = [_ilan(f"https://{domain}/arona", 1_500_000, 25_000, "1.0 Style") for domain in ("ikinciyeni.com", "galerim.com/acik-artirma", "galerim.com/ihale")]
    result = _arama(STYLE + auctions)
    for listing in auctions:
        assert wmr.verify(listing, result["sources"], ARONA) == "açık artırma"
    ref = wmr.build_reference([result], ARONA)
    assert ref["scope"]["site_stats"] == {"batidan2.com": {"kabul": 1, "red": 0}, "otoshops.com": {"kabul": 1, "red": 0}, "arabam.com": {"kabul": 1, "red": 0}, "ikinciyeni.com": {"kabul": 0, "red": 1}, "galerim.com": {"kabul": 0, "red": 2}}


def test_ikinci_tur_sonucu_onbellekte_tutulur(monkeypatch):
    cached = {}
    monkeypatch.setenv("WEB_PRICE_CACHE_HOURS", "24")
    monkeypatch.setattr(wmr, "_cache_read", lambda key, hours: cached.get(key))
    monkeypatch.setattr(wmr, "_cache_write", lambda key, ref: cached.update({key: ref}))
    calls = []
    search = lambda q: calls.append(q) or _arama(STYLE)
    first = wmr.get_reference(ARONA, search=search)
    second = wmr.get_reference(ARONA, search=search)
    assert len(calls) == 6
    assert first["scope"]["widened"] and second["count"] == 3


def test_ikinci_tur_da_motor_fiyat_yil_ve_km_kurallarini_korur():
    distant_year = _ilan("https://galerim.com/year", 1_500_000, 25_000, "1.0 Style", yil=2021)
    distant_km = _ilan("https://galerim.com/km", 1_500_000, 85_000, "1.0 Style")
    wrong_engine = _ilan("https://galerim.com/engine", 1_500_000, 25_000, "1.5 Style")
    fake_price = _ilan("https://galerim.com/price", 1_500_000, 25_000, "1.0 Style")
    result = _arama(STYLE + [distant_year, distant_km, wrong_engine, fake_price],
                    sayfalar={fake_price["url"]: "Fiyat belirtilmedi"})
    ref = wmr.build_reference([result], ARONA, widened=True)
    assert ref["count"] == 3
    assert ref["scope"]["rejected"] == {"yıl uyumsuz": 1, "km uzak": 1, "motor uyumsuz": 1, "fiyat sayfada yok": 1}


def test_aykiri_fiyat_atildiktan_sonra_bes_hedefi_kontrol_edilir():
    calls = []
    outliers = [_ilan(f"https://galerim.com/{n}", price, 25_000, "1.0 Style")
                for n, price in enumerate((100_000, 4_000_000))]
    ref = wmr.get_reference(ARONA, search=lambda q: calls.append(q) or _arama(STYLE + outliers))
    assert len(calls) == 6 and ref["count"] == 3


def test_onbellek_anahtari_arama_politikasi_surumu_icerir(monkeypatch):
    previous = wmr._cache_key(ARONA)
    monkeypatch.setattr(wmr, "CACHE_VERSION", "different-policy")
    assert wmr._cache_key(ARONA) != previous


@pytest.mark.parametrize("searches", [1, 2, 3])
def test_her_tur_yapilandirilmis_sorgu_sayisini_korur(monkeypatch, searches):
    monkeypatch.setenv("WEB_PRICE_SEARCHES", str(searches))
    calls = []
    ref = wmr.get_reference(ARONA, search=lambda q: calls.append(q) or _arama(STYLE))
    assert len(calls) == searches * 2 and ref["count"] == 3
    assert "sahibinden.com ilanlarını verme" in wmr._PROMPT
