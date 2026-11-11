"""Kayıt ve e-posta uçları için işçiler arasında paylaşılan saatlik kota.

Anahtarlar HMAC ile özetlenir. Çok anahtarlı tüketim tek transaction'dır;
PostgreSQL advisory lock yarışan isteklerin kotayı aşmasını engeller.
Şema yalnız startup'ta kurulur. DB hatası çağırana iletilir (e-posta gönderilmez).
"""
import hashlib
import hmac
import os
from typing import Any

from yerimebak_ai_v5.core.database_config import DatabaseConfig

PENCERE_SANIYE = 3600


def _sinir(name: str, default: int) -> int:
    try:
        return max(1, int(os.getenv(name, str(default))))
    except ValueError:
        return default


def ensure_schema(cursor: Any) -> None:
    cursor.execute("""CREATE TABLE IF NOT EXISTS auth_mail_limits (
        anahtar TEXT PRIMARY KEY,
        pencere_basi TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        sayi INTEGER NOT NULL DEFAULT 0)""")
    cursor.execute("ALTER TABLE auth_mail_limits ENABLE ROW LEVEL SECURITY")


def _anahtar(action: str, kind: str, value: str) -> str:
    secret = (os.getenv('SECRET_KEY') or '').encode('utf-8')
    digest = hmac.new(secret, f'{action}:{kind}:{value.strip().lower()}'.encode('utf-8'), hashlib.sha256).hexdigest()
    return f'{action}:{kind}:{digest}'


def tuket(action: str, email: str, ip: str) -> int:
    """İzin varsa 0; kota doluysa tekrar denenebilecek saniye sayısı."""
    if action not in ('register', 'forgot', 'resend'):
        raise ValueError('Bilinmeyen e-posta işlemi')
    keys = [(_anahtar(action, 'ip', ip), _sinir('KAYIT_IP_SINIRI', 5) if action == 'register' else _sinir('EPOSTA_IP_SINIRI', 10))]
    if action != 'register':
        keys.append((_anahtar(action, 'hesap', email), _sinir('EPOSTA_HESAP_SINIRI', 3)))
    keys.sort()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        # Bütün anahtarlar aynı sırada kilitlenir; farklı işçiler de aynı kilidi görür.
        for key, _ in keys:
            lock_id = int.from_bytes(hashlib.sha256(key.encode()).digest()[:8], 'big', signed=True)
            cursor.execute('SELECT pg_advisory_xact_lock(%s)', (lock_id,))
        retry = 0
        for key, limit in keys:
            cursor.execute("""SELECT sayi, GREATEST(1, CEIL(EXTRACT(EPOCH FROM
                pencere_basi + make_interval(secs => %s) - NOW())))::int AS bekle
                FROM auth_mail_limits WHERE anahtar = %s
                AND pencere_basi > NOW() - make_interval(secs => %s)""",
                (PENCERE_SANIYE, key, PENCERE_SANIYE))
            row = cursor.fetchone()
            if row and row['sayi'] >= limit:
                retry = max(retry, row['bekle'])
        if retry:
            conn.rollback()
            return retry
        for key, _ in keys:
            cursor.execute("""INSERT INTO auth_mail_limits (anahtar, pencere_basi, sayi)
                VALUES (%s, NOW(), 1) ON CONFLICT (anahtar) DO UPDATE SET
                sayi = CASE WHEN auth_mail_limits.pencere_basi <= NOW() - make_interval(secs => %s)
                    THEN 1 ELSE auth_mail_limits.sayi + 1 END,
                pencere_basi = CASE WHEN auth_mail_limits.pencere_basi <= NOW() - make_interval(secs => %s)
                    THEN NOW() ELSE auth_mail_limits.pencere_basi END""",
                (key, PENCERE_SANIYE, PENCERE_SANIYE))
        # Başka isteğin yenilediği eski satırda bekleme: çapraz UPSERT/DELETE
        # kilit döngüsü kurmamak için kilitli satırları atla ve işi sınırlı tut.
        cursor.execute("""WITH eski AS (
            SELECT anahtar FROM auth_mail_limits
            WHERE pencere_basi < NOW() - INTERVAL '2 days'
            LIMIT 100 FOR UPDATE SKIP LOCKED)
            DELETE FROM auth_mail_limits WHERE anahtar IN (SELECT anahtar FROM eski)""")
        conn.commit()
        return 0
    except Exception:
        conn.rollback()
        raise
    finally:
        DatabaseConfig.return_connection(conn)
