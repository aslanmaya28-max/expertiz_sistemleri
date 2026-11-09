# -*- coding: utf-8 -*-
"""Açılışta şema kurulumu işlemler arası kilitle sıraya girer (10.11.2026 canlı 'tuple concurrently updated')."""
import pytest

from yerimebak_ai_v5 import main


class _SahteImlec:
    def __init__(self, kayit):
        self.kayit = kayit

    def execute(self, sql, params=None):
        self.kayit.append(sql.split("(")[0].strip())


class _SahteBaglanti:
    def __init__(self, kayit):
        self.kayit = kayit
        self.autocommit = False
        self.kapandi = False

    def cursor(self):
        return _SahteImlec(self.kayit)

    def close(self):
        self.kapandi = True
        self.kayit.append("close")


def test_kurulum_kilit_alindiktan_sonra_calisir_ve_kilit_birakilir():
    kayit = []
    baglanti = _SahteBaglanti(kayit)
    main.sirali_sema_kurulumu(lambda: kayit.append("kur"), lambda: baglanti, bekleme=0)
    assert kayit == ["SET lock_timeout = '60s'", "SELECT pg_advisory_lock", "kur",
                     "SELECT pg_advisory_unlock", "close"]
    assert baglanti.autocommit is True


def test_gecici_hatada_yeniden_dener():
    kayit = []
    denemeler = []

    def kur():
        denemeler.append(1)
        if len(denemeler) == 1:
            raise RuntimeError("tuple concurrently updated")
        kayit.append("kur")

    main.sirali_sema_kurulumu(kur, lambda: _SahteBaglanti(kayit), bekleme=0)
    assert len(denemeler) == 2
    assert kayit[-2:] == ["SELECT pg_advisory_unlock", "close"]


def test_kalici_hatada_son_denemede_hata_firlatir_ve_kilidi_birakir():
    kayit = []

    def kur():
        raise RuntimeError("kalıcı")

    with pytest.raises(RuntimeError):
        main.sirali_sema_kurulumu(kur, lambda: _SahteBaglanti(kayit), deneme=2, bekleme=0)
    assert kayit[-2:] == ["SELECT pg_advisory_unlock", "close"]


def test_kilit_baglantisi_acilamazsa_kilitsiz_kurar():
    kayit = []

    def ac():
        raise OSError("bağlantı yok")

    main.sirali_sema_kurulumu(lambda: kayit.append("kur"), ac, bekleme=0)
    assert kayit == ["kur"]
