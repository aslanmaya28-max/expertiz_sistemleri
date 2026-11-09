"""Yerinde ekspertiz hizmet bölgesi ve randevu alanları (sözleşme 2026-11-09)."""
from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from yerimebak_ai_v5.services import service_area as sa

SIMDI = datetime(2026, 11, 9, 12, 0, tzinfo=ZoneInfo("Europe/Istanbul"))


def _form(**ek):
    return {"appointment_at": "2026-11-10T10:30", "address": "Moda Cad. No: 10, Kadıköy",
            "seller_phone": "+90 532 111 22 33", "not_found_accepted": True, **ek}


def test_81_il_turkce_sirada_ve_pilot_istanbul():
    assert len(sa.ILLER) == 81 and sa.PILOT == "İstanbul"
    assert sa.ILLER[:3] == ["Adana", "Adıyaman", "Afyonkarahisar"]
    # Türkçe sıra: Iğdır (ı) İstanbul'dan (i) önce; Çanakkale C'den sonra
    assert sa.ILLER.index("Iğdır") < sa.ILLER.index("Isparta") < sa.ILLER.index("İstanbul")
    assert sa.ILLER.index("Çanakkale") > sa.ILLER.index("Bursa")
    assert sa.il_adi("istanbul kadıköy") == "İstanbul" and sa.il_adi("Atlantis") is None


@pytest.mark.parametrize("durum,tester,genel,beklenen", [
    ("acik", False, True, True), ("acik", False, False, False), ("test", False, True, False),
    ("test", True, False, True), ("acik", True, False, True), ("kapali", True, True, False),
])
def test_talep_acabilir(monkeypatch, durum, tester, genel, beklenen):
    monkeypatch.setenv("APP_EXPERTIZ_ENABLED", "true" if genel else "false")
    assert sa._talep_acabilir(durum, tester) is beklenen


def test_randevu_gecerli_ve_telefon_bicimi():
    randevu, hata = sa.randevu_ayrintilari(_form(seller_name="  Ali   Veli "), SIMDI)
    assert hata is None
    assert randevu == {"tarih_saat": "2026-11-10T10:30", "adres": "Moda Cad. No: 10, Kadıköy",
                       "satici_adi": "Ali Veli", "satici_telefon": "05321112233"}
    for tel, beklenen in (("05321112233", "05321112233"), ("532 111 22 33", "05321112233"),
                          ("0216 333 44 55", "02163334455")):
        assert sa._telefon(tel) == beklenen
    assert sa._telefon("12345") is None


@pytest.mark.parametrize("ek,kod", [
    ({"appointment_at": "2026-11-09T13:00"}, "randevu_gecersiz"),      # 2 saatten erken
    ({"appointment_at": "2026-12-20T10:00"}, "randevu_gecersiz"),      # 30 günden geç
    ({"appointment_at": "yarın"}, "randevu_gecersiz"),
    ({"address": "Kadıköy"}, "adres_eksik"),
    ({"seller_phone": "123"}, "satici_telefon_gecersiz"),
    ({"not_found_accepted": False}, "bulunamama_onayi_gerekli"),
    ({"not_found_accepted": "true"}, "bulunamama_onayi_gerekli"),   # yalnız gerçek true
])
def test_randevu_hatalari_kodlu(ek, kod):
    randevu, hata = sa.randevu_ayrintilari(_form(**ek), SIMDI)
    assert randevu is None and hata["code"] == kod and hata["http_status"] == 422
