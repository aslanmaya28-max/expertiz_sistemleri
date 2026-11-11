# -*- coding: utf-8 -*-
"""Girişte kaba kuvvet koruması (11.11.2026 güvenlik denetimi).

Yanlış şifre sayaçları veritabanında tutulur; birden çok sunucu işlemi (WEB_CONCURRENCY) aynı sayacı görür.
- Aynı e-posta: GIRIS_EPOSTA_SINIRI yanlış denemede (varsayılan 5) o hesaba giriş GIRIS_PENCERE_DK dakika durur.
- Aynı IP: GIRIS_IP_SINIRI yanlış denemede (varsayılan 30) o IP'den giriş durur (çok hesabı tek tek deneme).
Kilitliyken doğru şifre de kabul edilmez; aksi halde kilit şifre denemeyi durdurmaz.
E-posta ve IP düz yazılmaz; SECRET_KEY ile özetlenir (kişisel veri tutulmaz).
"""
import hashlib
import hmac
import logging
import os
import random
from typing import Any, Optional

from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)


def _sayi(ad: str, varsayilan: int) -> int:
    try:
        return max(1, int(os.getenv(ad, str(varsayilan))))
    except ValueError:
        return varsayilan


def pencere_dk() -> int:
    return _sayi("GIRIS_PENCERE_DK", 15)


def eposta_siniri() -> int:
    return _sayi("GIRIS_EPOSTA_SINIRI", 5)


def ip_siniri() -> int:
    return _sayi("GIRIS_IP_SINIRI", 30)


def ensure_schema(cursor: Any) -> None:
    """Yalnız sunucu açılışında (istek yolunda DDL yok)."""
    cursor.execute("SELECT to_regclass('public.login_attempts') IS NOT NULL AS var")
    row = cursor.fetchone()
    if not (row["var"] if isinstance(row, dict) else row[0]):
        cursor.execute("""CREATE TABLE IF NOT EXISTS login_attempts (
            anahtar TEXT PRIMARY KEY, pencere_basi TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            hatali INTEGER NOT NULL DEFAULT 0)""")
        # Supabase: tablo dışarıya kapalı kalsın; sunucu sahibi rolle erişir.
        cursor.execute("ALTER TABLE login_attempts ENABLE ROW LEVEL SECURITY")


def _anahtar(tur: str, deger: str) -> str:
    gizli = (os.getenv("SECRET_KEY") or "").encode("utf-8")
    ozet = hmac.new(gizli, f"{tur}:{(deger or '').strip().lower()}".encode("utf-8"), hashlib.sha256).hexdigest()
    return f"{tur}:{ozet}"


def _anahtarlar(email: str, ip: Optional[str]):
    out = [(_anahtar("eposta", email), eposta_siniri())]
    if ip:
        out.append((_anahtar("ip", ip), ip_siniri()))
    return out


def kilitli_mi(email: str, ip: Optional[str]) -> bool:
    """Bu e-posta ya da IP için yanlış deneme sınırı aşıldıysa True (veritabanı hatasında girişi engellemez)."""
    anahtarlar = _anahtarlar(email, ip)
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT anahtar, hatali FROM login_attempts WHERE anahtar = ANY(%s) "
            "AND pencere_basi > NOW() - make_interval(mins => %s)",
            ([a for a, _ in anahtarlar], pencere_dk()))
        sayilar = {r["anahtar"]: r["hatali"] for r in cursor.fetchall()}
        conn.commit()
    except Exception as exc:  # pragma: no cover - koruma, girişi tamamen kilitlememeli
        conn.rollback()
        logger.warning("[GİRİŞ KORUMASI] okunamadı: %s", type(exc).__name__)
        return False
    finally:
        DatabaseConfig.return_connection(conn)
    return any(sayilar.get(a, 0) >= sinir for a, sinir in anahtarlar)


def basarisiz(email: str, ip: Optional[str]) -> None:
    """Yanlış şifre: e-posta ve IP sayaçları artar; süresi dolan pencere sıfırdan başlar."""
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        for anahtar, _ in _anahtarlar(email, ip):
            cursor.execute(
                """INSERT INTO login_attempts (anahtar, pencere_basi, hatali) VALUES (%s, NOW(), 1)
                   ON CONFLICT (anahtar) DO UPDATE SET
                     hatali = CASE WHEN login_attempts.pencere_basi <= NOW() - make_interval(mins => %s)
                                   THEN 1 ELSE login_attempts.hatali + 1 END,
                     pencere_basi = CASE WHEN login_attempts.pencere_basi <= NOW() - make_interval(mins => %s)
                                         THEN NOW() ELSE login_attempts.pencere_basi END""",
                (anahtar, pencere_dk(), pencere_dk()))
        if random.random() < 0.02:  # eski kayıtlar ara sıra temizlenir
            cursor.execute("DELETE FROM login_attempts WHERE pencere_basi < NOW() - INTERVAL '1 day'")
        conn.commit()
    except Exception as exc:  # pragma: no cover
        conn.rollback()
        logger.warning("[GİRİŞ KORUMASI] yazılamadı: %s", type(exc).__name__)
    finally:
        DatabaseConfig.return_connection(conn)


def basarili(email: str) -> None:
    """Doğru şifre: o hesabın sayacı sıfırlanır (IP sayacı kalır; tek IP'den çok hesap denemesini sayar)."""
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("DELETE FROM login_attempts WHERE anahtar = %s", (_anahtar("eposta", email),))
        conn.commit()
    except Exception:  # pragma: no cover
        conn.rollback()
    finally:
        DatabaseConfig.return_connection(conn)
