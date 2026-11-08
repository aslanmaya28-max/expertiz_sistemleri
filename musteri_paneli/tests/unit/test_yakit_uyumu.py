# -*- coding: utf-8 -*-
"""Benzinli araca dizel bilgisi girmesin (canlı rapor YD 2026-000002, Fiat Egea 2020 Urban Plus, 1.4 benzinli
manuel, 08.11.2026): şikâyetlerde "Dizel 1.3 Multijet" maddeleri, emsallerde 1.3 Multijet ve 1.6 E-Torq otomatik
ilanları, bakımda turbo ve çift kütleli volan çıkıyordu."""
from yerimebak_ai_v5.services import vehicle_risk as vr
from yerimebak_ai_v5.services import web_market_reference as wmr

EGEA = {"brand": "Fiat", "model": "Egea", "year": 2020, "km": 155_000, "package": "Urban plus",
        "fuel": "Benzin", "transmission": "Manuel"}


def test_benzinli_araca_dizel_sikayeti_girmez():
    dizel = ["Dizel 1.3 Multijet'te EGR kurumlanması ve motor arıza lambası Kullanıcı beyanlarında EGR valfinde kurum",
             "Dizel 1.3 Multijet'te partikül filtresi tıkanması Kısa mesafede kullanım sonrası filtre dolması"]
    assert all(vr._fuel_incompatible(t, EGEA) for t in dizel)
    # Benzinli motoru anlatan ya da iki yakıtı birlikte anan metin elenmez.
    assert not vr._fuel_incompatible("1.4 Fire motorda rölanti dalgalanması ve bobin arızası", EGEA)
    assert not vr._fuel_incompatible("Egea'nın hem benzinli hem dizel versiyonlarında ön takım sesi", EGEA)
    # Tersi: dizel araca yalnız benzinli motoru anlatan madde girmez.
    dizel_arac = {**EGEA, "fuel": "Dizel", "package": "1.3 Multijet Urban"}
    assert vr._fuel_incompatible("1.4 Fire motorda yağ yakma şikâyeti", dizel_arac)
    assert not vr._fuel_incompatible("1.3 Multijet'te EGR kurumlanması", dizel_arac)


def test_emsalde_yakit_ve_vites_uyumsuz_ilan_elenir():
    yanlis = {
        "https://www.arabam.com/ikinci-el/otomobil/fiat-egea-1-3-multijet-urban-plus-galeriden": "yakıt uyumsuz",
        "https://www.renewturkiye.com/otomobil/fiat/egea/hatchback-1.6-e-torq-urban-plus-otomatik": "vites uyumsuz",
    }
    for url, neden in yanlis.items():
        assert wmr.aile_uyumsuz(EGEA, url) == neden
    dogru = ["https://www.adwhit.com/map/satilik-arabalar-fiat-egea-1-4-fire-urban-plus-hatchback-5-egea-1-4-16v-fire-urban-plus-manuel",
             "https://www.turkiyepazari.com/manisa-salihli-2020-hatasiz-boyasiz-70-binde-urban-plus-egea-12778"]
    assert all(wmr.aile_uyumsuz(EGEA, url) is None for url in dogru)
    # Otomatik araç manuel ilanla karşılaştırılmaz; bilgisi olmayan ilan elenmez.
    assert wmr.aile_uyumsuz({**EGEA, "transmission": "Otomatik"}, "egea-1-4-fire-manuel") == "vites uyumsuz"
    assert wmr.aile_uyumsuz({**EGEA, "transmission": "Otomatik"}, "egea-urban-plus") is None


def test_turbosuz_benzinlide_turbo_ve_cift_kutleli_volan_sorulmaz():
    basliklar = [m["baslik"] for m in vr.upcoming_maintenance(EGEA, {"riskler": []})]
    assert "Turbo ve enjektör kontrolü" not in basliklar and "Debriyaj / çift kütleli volan kontrolü" not in basliklar
    assert "Enjektör ve ateşleme kontrolü" in basliklar and "Debriyaj kontrolü" in basliklar
    sorular = vr.seller_questions(EGEA, {"riskler": []}, [])
    assert not any("turbo" in q.lower() for q in sorular)
    # Dizelde ve turbolu benzinlide sorulur.
    for arac in [{**EGEA, "fuel": "Dizel", "package": "1.3 Multijet Urban"},
                 {**EGEA, "brand": "Volkswagen", "model": "Golf", "package": "1.0 TSI Comfortline"}]:
        b = [m["baslik"] for m in vr.upcoming_maintenance(arac, {"riskler": []})]
        assert "Turbo ve enjektör kontrolü" in b and "Debriyaj / çift kütleli volan kontrolü" in b
