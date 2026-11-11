# -*- coding: utf-8 -*-
"""Girişte kaba kuvvet koruması (11.11.2026 güvenlik denetimi)."""
import pytest

from .test_dispatch_flow import client, TEST_DB  # noqa: F401
from .test_credit_admin_flow import sql

pytestmark = pytest.mark.skipif(not TEST_DB, reason='TEST_DATABASE_URL tanımlı değil')

SIFRE = "Koruma123!"


def _kayit(client, email):
    telefon = "0555" + str(abs(hash(email)) % 10_000_000).zfill(7)
    r = client.post("/api/v1/auth/register", json={"email": email, "password": SIFRE, "full_name": "Koruma Deneme",
                                                   "phone": telefon, "terms_accepted": True})
    assert r.status_code == 200, r.text


def _giris(client, email, sifre, ip="198.51.100.7"):
    return client.post("/api/v1/auth/login", json={"email": email, "password": sifre},
                       headers={"CF-Connecting-IP": ip})


def test_bes_yanlis_denemeden_sonra_dogru_sifre_de_beklemek_zorunda(client):
    sql("DELETE FROM login_attempts")
    _kayit(client, "koruma1@yerimebak.test")
    _kayit(client, "koruma2@yerimebak.test")
    for _ in range(5):
        assert _giris(client, "koruma1@yerimebak.test", "Yanlis123!").status_code == 401
    kilitli = _giris(client, "koruma1@yerimebak.test", SIFRE)
    assert kilitli.status_code == 429
    assert "Çok fazla hatalı giriş" in kilitli.json()["detail"]
    assert kilitli.headers.get("retry-after") == "900"
    # Aynı IP'den başka hesap etkilenmez (IP sınırı 30).
    assert _giris(client, "koruma2@yerimebak.test", SIFRE).status_code == 200
    # Süre dolunca (pencere geçmişte) giriş açılır ve sayaç sıfırlanır.
    sql("UPDATE login_attempts SET pencere_basi = NOW() - INTERVAL '16 minutes'")
    assert _giris(client, "koruma1@yerimebak.test", SIFRE).status_code == 200
    assert _giris(client, "koruma1@yerimebak.test", "Yanlis123!").status_code == 401
    assert _giris(client, "koruma1@yerimebak.test", SIFRE).status_code == 200


def test_basarili_giris_hesap_sayacini_sifirlar(client):
    sql("DELETE FROM login_attempts")
    _kayit(client, "koruma3@yerimebak.test")
    for _ in range(4):
        _giris(client, "koruma3@yerimebak.test", "Yanlis123!", ip="198.51.100.8")
    assert _giris(client, "koruma3@yerimebak.test", SIFRE, ip="198.51.100.8").status_code == 200
    for _ in range(4):
        _giris(client, "koruma3@yerimebak.test", "Yanlis123!", ip="198.51.100.8")
    assert _giris(client, "koruma3@yerimebak.test", SIFRE, ip="198.51.100.8").status_code == 200


def test_tek_ipden_cok_hesap_denemesi_durur(client):
    sql("DELETE FROM login_attempts")
    for i in range(30):
        assert _giris(client, f"yok{i}@yerimebak.test", "Yanlis123!", ip="198.51.100.9").status_code == 401
    assert _giris(client, "baska@yerimebak.test", "Yanlis123!", ip="198.51.100.9").status_code == 429
    assert _giris(client, "baska@yerimebak.test", "Yanlis123!", ip="198.51.100.10").status_code == 401


def test_kayitta_e_posta_ve_ip_duz_yazilmaz(client):
    sql("DELETE FROM login_attempts")
    _giris(client, "gizli@yerimebak.test", "Yanlis123!", ip="203.0.113.5")
    satirlar = sql("SELECT anahtar FROM login_attempts", fetch=True)
    assert satirlar and all("gizli" not in r["anahtar"] and "203.0.113" not in r["anahtar"] for r in satirlar)
