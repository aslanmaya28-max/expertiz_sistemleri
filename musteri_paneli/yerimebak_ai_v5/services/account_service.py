# -*- coding: utf-8 -*-
"""
Hesap islemleri: e-posta dogrulama ve sifre sifirlama.

- Yeni musteri kaydinda hos geldin kredisi hemen verilmez; e-posta adresi
  dogrulaninca BIR KEZ yuklenir (sahte hesaplarla bedava kredi toplanmasin).
- Sifremi unuttum: e-postaya tek kullanimlik, 1 saat gecerli baglanti gider.
  Kayitli olmayan e-posta icin de ayni yanit doner (hesap varligi sizdirilmaz).
- Tokenlar veritabaninda SHA-256 ozeti olarak tutulur.
"""
import hashlib
import logging
import secrets
import threading
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Optional

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.services import email_service

logger = logging.getLogger(__name__)

RESET_TTL = timedelta(hours=1)
VERIFY_TTL = timedelta(days=3)
RESEND_COOLDOWN = timedelta(minutes=2)
# Yasal metinlerin surumu; metinler degisince artirilir (onay kaydinda saklanir)
LEGAL_VERSION = "2026-10"

_schema_lock = threading.Lock()
_schema_ready = False


def _error(message: str, status: int = 400) -> Dict[str, Any]:
    return {"error": message, "http_status": status}


def _hash(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def welcome_credits() -> int:
    from yerimebak_ai_v5.services.payment_service import FREE_CREDITS_ON_REGISTER

    return int(FREE_CREDITS_ON_REGISTER)


def ensure_schema(force: bool = False) -> None:
    global _schema_ready
    if _schema_ready and not force:
        return
    with _schema_lock:
        if _schema_ready and not force:
            return
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute('ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ')
            # Mevcut kullanicilar dogrulanmis sayilir (DEFAULT TRUE ile eklenir),
            # bundan sonraki kayitlar FALSE baslar.
            cursor.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS email_verified BOOLEAN DEFAULT TRUE")
            cursor.execute("ALTER TABLE users ALTER COLUMN email_verified SET DEFAULT FALSE")
            cursor.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS welcome_credits_granted BOOLEAN DEFAULT TRUE")
            cursor.execute("ALTER TABLE users ALTER COLUMN welcome_credits_granted SET DEFAULT FALSE")
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS account_tokens (
                    token_hash TEXT PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    purpose TEXT NOT NULL,
                    expires_at TIMESTAMPTZ NOT NULL,
                    used_at TIMESTAMPTZ,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
            cursor.execute(
                "CREATE INDEX IF NOT EXISTS idx_account_tokens_user ON account_tokens(user_id, purpose, created_at DESC)"
            )
            # Kullanim kosullari / KVKK / mesafeli satis onaylarinin kaniti
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS legal_consents (
                    id BIGSERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    kind TEXT NOT NULL,
                    document_version TEXT NOT NULL,
                    reference TEXT,
                    ip TEXT,
                    accepted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_legal_consents_user ON legal_consents(user_id, kind)")
            conn.commit()
            _schema_ready = True
        finally:
            DatabaseConfig.return_connection(conn)


def _issue_token(cursor: Any, user_id: Any, purpose: str, ttl: timedelta) -> str:
    token = secrets.token_urlsafe(32)
    # Ayni amacli eski (kullanilmamis) tokenlar gecersiz olur
    cursor.execute(
        "UPDATE account_tokens SET used_at = NOW() WHERE user_id = %s AND purpose = %s AND used_at IS NULL",
        (int(user_id), purpose),
    )
    cursor.execute(
        "INSERT INTO account_tokens (token_hash, user_id, purpose, expires_at) VALUES (%s, %s, %s, %s)",
        (_hash(token), int(user_id), purpose, datetime.now(timezone.utc) + ttl),
    )
    return token


def _consume_token(cursor: Any, token: str, purpose: str) -> Optional[int]:
    cursor.execute(
        """
        UPDATE account_tokens SET used_at = NOW()
        WHERE token_hash = %s AND purpose = %s AND used_at IS NULL AND expires_at > NOW()
        RETURNING user_id
        """,
        (_hash(token or ""), purpose),
    )
    row = cursor.fetchone()
    return int(dict(row)["user_id"]) if row else None


def record_consents(user_id: Any, kinds: list, reference: Optional[str] = None, ip: Optional[str] = None) -> None:
    """Onaylari kaydeder (ayri baglanti, hemen commit)."""
    ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        for kind in kinds:
            cursor.execute(
                "INSERT INTO legal_consents (user_id, kind, document_version, reference, ip) VALUES (%s, %s, %s, %s, %s)",
                (int(user_id), kind, LEGAL_VERSION, reference, (ip or "")[:64] or None),
            )
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)


# ---------------------------------------------------------------------------
# E-posta dogrulama
# ---------------------------------------------------------------------------

def send_verification(user_id: Any, email: str, full_name: str = "") -> bool:
    """Yeni kayit sonrasi dogrulama e-postasi."""
    ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        token = _issue_token(cursor, user_id, "verify_email", VERIFY_TTL)
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    credits = welcome_credits()
    return email_service.send(
        email,
        "YerimeBak - E-posta adresinizi doğrulayın",
        "E-posta adresinizi doğrulayın",
        [
            f"Merhaba {full_name or ''}".strip() + ",",
            "YerimeBak hesabınızı etkinleştirmek için aşağıdaki bağlantıya tıklayın.",
            *( [f"Doğrulamadan sonra {credits} ücretsiz araç analizi kredisi hesabınıza yüklenir."] if credits else [] ),
            "Bu kaydı siz yapmadıysanız bu e-postayı dikkate almayın.",
        ],
        ("E-postamı doğrula", email_service.site_url(f"/eposta-dogrula?token={token}")),
    )


def resend_verification(user: Dict[str, Any]) -> Dict[str, Any]:
    ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT id, email, full_name, email_verified FROM users WHERE id::text = %s", (str(user.get("id")),))
        row = cursor.fetchone()
        if not row:
            return _error("Kullanıcı bulunamadı", 404)
        row = dict(row)
        if row.get("email_verified"):
            return {"success": True, "already_verified": True}
        cursor.execute(
            "SELECT created_at FROM account_tokens WHERE user_id = %s AND purpose = 'verify_email' ORDER BY created_at DESC LIMIT 1",
            (int(row["id"]),),
        )
        last = cursor.fetchone()
        if last and dict(last)["created_at"] > datetime.now(timezone.utc) - RESEND_COOLDOWN:
            return _error("Doğrulama e-postası az önce gönderildi; birkaç dakika sonra tekrar deneyin", 429)
    finally:
        DatabaseConfig.return_connection(conn)
    send_verification(row["id"], row["email"], row.get("full_name") or "")
    return {"success": True}


def verify_email(token: str) -> Dict[str, Any]:
    """Tokeni dogrular; hos geldin kredisi bir kez yuklenir."""
    ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        user_id = _consume_token(cursor, token, "verify_email")
        if user_id is None:
            conn.rollback()
            return _error("Doğrulama bağlantısı geçersiz veya süresi dolmuş", 400)
        cursor.execute(
            """
            UPDATE users SET email_verified = TRUE
            WHERE id = %s
            RETURNING id, email, welcome_credits_granted
            """,
            (user_id,),
        )
        row = dict(cursor.fetchone())
        granted = 0
        if not row.get("welcome_credits_granted"):
            granted = welcome_credits()
            cursor.execute(
                "UPDATE users SET credits = COALESCE(credits, 0) + %s, welcome_credits_granted = TRUE WHERE id = %s",
                (granted, user_id),
            )
            if granted:
                try:
                    cursor.execute("SAVEPOINT welcome_log")
                    cursor.execute(
                        "INSERT INTO credit_usage_logs (user_id, action, credits_used, description) VALUES (%s, %s, %s, %s)",
                        (user_id, "welcome_bonus", granted, "E-posta dogrulama hos geldin kredisi"),
                    )
                    cursor.execute("RELEASE SAVEPOINT welcome_log")
                except Exception:
                    cursor.execute("ROLLBACK TO SAVEPOINT welcome_log")
        conn.commit()
        return {"success": True, "credits_granted": granted}
    finally:
        DatabaseConfig.return_connection(conn)


# ---------------------------------------------------------------------------
# Sifre sifirlama
# ---------------------------------------------------------------------------

def request_password_reset(email: str) -> Dict[str, Any]:
    """Her durumda ayni yaniti verir (kayitli e-posta tahmin edilemesin)."""
    ensure_schema()
    response = {
        "success": True,
        "message": "Bu e-posta adresi kayıtlıysa şifre sıfırlama bağlantısı gönderildi.",
    }
    email = (email or "").strip()
    if not email:
        return response
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT id, email, full_name, is_active FROM users WHERE lower(email) = lower(%s) LIMIT 1",
            (email,),
        )
        row = cursor.fetchone()
        if not row:
            return response
        row = dict(row)
        if str(row.get("is_active", 1)) in ("0", "False", "false"):
            return response
        cursor.execute(
            "SELECT created_at FROM account_tokens WHERE user_id = %s AND purpose = 'reset_password' ORDER BY created_at DESC LIMIT 1",
            (int(row["id"]),),
        )
        last = cursor.fetchone()
        if last and dict(last)["created_at"] > datetime.now(timezone.utc) - RESEND_COOLDOWN:
            return response
        token = _issue_token(cursor, row["id"], "reset_password", RESET_TTL)
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)

    email_service.send(
        row["email"],
        "YerimeBak - Şifre sıfırlama",
        "Şifrenizi sıfırlayın",
        [
            "Hesabınız için şifre sıfırlama talebi aldık.",
            "Yeni şifre belirlemek için aşağıdaki bağlantıya tıklayın. Bağlantı 1 saat geçerlidir ve bir kez kullanılabilir.",
            "Bu talebi siz yapmadıysanız bu e-postayı dikkate almayın; şifreniz değişmez.",
        ],
        ("Yeni şifre belirle", email_service.site_url(f"/sifre-sifirla?token={token}")),
    )
    return response


def reset_password(token: str, new_password: str) -> Dict[str, Any]:
    from yerimebak_ai_v5.services.auth_service import _hash_password, _validate_password_strength

    error = _validate_password_strength(new_password or "")
    if error:
        return _error(error, 400)
    ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        user_id = _consume_token(cursor, token, "reset_password")
        if user_id is None:
            conn.rollback()
            return _error("Şifre sıfırlama bağlantısı geçersiz veya süresi dolmuş", 400)
        cursor.execute(
            "UPDATE users SET password = %s, must_change_password = FALSE WHERE id = %s",
            (_hash_password(new_password), user_id),
        )
        conn.commit()
        return {"success": True}
    finally:
        DatabaseConfig.return_connection(conn)


def delete_account(user_id: Any, password: str) -> Dict[str, Any]:
    """Müşteri kişisel alanlarını ve kurtarma bağlantılarını tek işlemde temizler."""
    import json
    from psycopg2.extras import Json
    from yerimebak_ai_v5.services.auth_service import _hash_password, _verify_password
    from yerimebak_ai_v5.services.expertiz_service import _expertiz_profile_id

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM users WHERE id=%s FOR UPDATE', (user_id,))
        row = cursor.fetchone()
        if not row or not row['is_active']:
            return _error('Hesap etkin değil.', 401)
        user = dict(row)
        if str(user.get('role') or '').lower() not in ('user', 'musteri', 'customer'):
            return _error('Admin ve personel hesapları bu yolla silinemez.', 403)
        if not _verify_password(password or '', user.get('password') or ''):
            return _error('Şifreniz yanlış.', 403)
        uid = user['id']
        email = f'silindi-{uid}@silindi.invalid'
        cursor.execute('''SELECT 1 FROM users WHERE lower(email)=lower(%s) AND id<>%s
                          UNION ALL SELECT 1 FROM profiles WHERE lower(email)=lower(%s) AND id<>%s LIMIT 1''',
                       (email, uid, email, _expertiz_profile_id(user)))
        if cursor.fetchone():
            # Eski kurulumda rezerve alan adıyla açılmış hesaplar silmeyi engellemez.
            email = f'silindi-{uid}-{secrets.token_hex(12)}@silindi.invalid'
        # Bazı profil kolonları eski kurulumlarda yalnız /auth/profile açıldığında eklenir.
        personal_fields = ('full_name', 'phone', 'api_key', 'company_name', 'city',
                           'tax_number', 'tax_office', 'invoice_address')
        assignments = ','.join(f'{field}=NULL' for field in personal_fields if field in user)
        cursor.execute(f'''UPDATE users SET email=%s,password=%s,is_active=0,credits=0,
                            deleted_at=NOW(),{assignments} WHERE id=%s''',
                       (email, _hash_password(secrets.token_urlsafe(48)), uid))
        cursor.execute('UPDATE account_tokens SET used_at=NOW() WHERE user_id=%s AND used_at IS NULL', (uid,))
        cursor.execute('UPDATE legal_consents SET ip=NULL WHERE user_id=%s', (uid,))
        cursor.execute('UPDATE payment_orders SET user_email=%s,user_phone=NULL WHERE user_id=%s', (email, uid))
        cursor.execute('''INSERT INTO credit_usage_logs (user_id,action,credits_used,description)
                          VALUES (%s,'account_deleted',%s,'Hesap silindi; kalan kredi sıfırlandı')''',
                       (uid, -int(user.get('credits') or 0)))

        # Raporlar tutulur; müşteri kopyaları ad/e-posta/telefon/adres taşımaz.
        sensitive_keys = {'email', 'e_posta', 'phone', 'telefon', 'full_name', 'customer_name',
                          'customer_email', 'customer_phone', 'musteriAdi', 'ad_soyad',
                          'invoice_address', 'tax_number', 'tax_office', 'company_name',
                          'address', 'adres', 'obfuscatedExternalAccountId', 'user_email', 'user_phone'}
        originals = sorted({str(user[k]) for k in ('email', 'phone')
                            if user.get(k) and len(str(user[k])) >= 3}, key=len, reverse=True)

        def scrub(value):
            if isinstance(value, dict):
                return {k: (None if k in sensitive_keys else scrub(v)) for k, v in value.items()}
            if isinstance(value, list):
                return [scrub(v) for v in value]
            if isinstance(value, str):
                for original in originals:
                    value = value.replace(original, '[silindi]')
            return value

        def scrub_rows(table, fields, where, params, json_fields=()):
            cursor.execute(f'SELECT id,{",".join(fields)} FROM {table} WHERE {where}', params)
            for record in cursor.fetchall():
                values = []
                for field in fields:
                    value = record[field]
                    if field in json_fields and isinstance(value, str):
                        try:
                            value = json.loads(value)
                        except ValueError:
                            value = {}
                    cleaned = scrub(value)
                    if field in json_fields:
                        values.append(Json(cleaned) if field == 'report_json' or table in ('reports', 'google_play_purchases') else json.dumps(cleaned, ensure_ascii=False))
                    else:
                        values.append(cleaned)
                cursor.execute(f'UPDATE {table} SET {",".join(f"{f}=%s" for f in fields)} WHERE id=%s',
                               (*values, record['id']))

        cursor.execute("SELECT set_config('yerimebak.anonymizing_user',%s,true)", (str(uid),))
        scrub_rows('analysis_history', ('vehicle_json', 'valuation_json', 'report_json'), 'user_id=%s', (uid,),
                   ('vehicle_json', 'valuation_json', 'report_json'))
        cursor.execute("SELECT set_config('yerimebak.anonymizing_user','',true)")
        scrub_rows('payment_orders', ('admin_note',), 'user_id=%s', (uid,))
        scrub_rows('credit_usage_logs', ('description',), 'user_id=%s', (uid,))
        scrub_rows('google_play_purchases', ('raw_json',), 'user_id=%s', (uid,), ('raw_json',))
        scrub_rows('expertiz_requests', ('data',), 'user_id=%s', (str(uid),), ('data',))
        cursor.execute('UPDATE expertiz_requests SET user_email=%s WHERE user_id=%s', (email, str(uid)))
        profile_id = _expertiz_profile_id(user)
        scrub_rows('reports', ('data', 'ai_analiz_detay', 'ai_analysis_result'),
                   'user_id=%s OR customer_id=%s', (profile_id, profile_id),
                   ('data', 'ai_analiz_detay', 'ai_analysis_result'))
        cursor.execute('''UPDATE profiles SET email=%s,ad_soyad='',telefon=NULL,bolge=NULL,
                          aktif_mi=FALSE,updated_at=NOW() WHERE id=%s''', (email, profile_id))
        cursor.execute("DELETE FROM notifications WHERE audience='user' AND user_id=%s", (str(uid),))
        conn.commit()
        return {'success': True, 'message': 'Hesabınız silindi ve kişisel bilgileriniz anonimleştirildi.'}
    except Exception:
        conn.rollback()
        raise
    finally:
        DatabaseConfig.return_connection(conn)
