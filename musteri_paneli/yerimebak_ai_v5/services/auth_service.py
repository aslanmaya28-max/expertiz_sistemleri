# -*- coding: utf-8 -*-
"""
YERIMEBAK AI v8.2 - Auth Service (Güvenlik Güncellemesi)
Kullanici kimlik dogrulama ve oturum yonetimi
🔒 GÜVENLİK: bcrypt + PyJWT kullanir, SHA-256 el yapimi JWT kaldirildi
"""
import secrets
import logging
import os
import re
from typing import Dict, Any, Optional
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt as pyjwt

from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)

# 🔒 GÜVENLİK: Varsayılan secret key kaldirildi. Ortam degiskeni zorunlu.
SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError(
        "CRITICAL: SECRET_KEY ortam degiskeni tanimlanmadi! "
        "Lutfen .env dosyasina guclu bir SECRET_KEY ekleyin."
    )

JWT_ALGORITHM = "HS256"
# 🔒 GÜVENLİK: JWT expire suresi .env'den alinir, varsayilan 24 saat
JWT_EXPIRE_HOURS = int(os.getenv("JWT_EXPIRE_HOURS", "24"))


def _validate_email(email: str) -> bool:
    """🔒 Email formatini dogrular."""
    pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    return bool(re.match(pattern, email.strip()))


def _validate_password_strength(password: str) -> Optional[str]:
    """🔒 Sifre gucunu kontrol eder. Hata mesaji doner veya None."""
    if len(password) < 8:
        return "Sifre en az 8 karakter olmalidir"
    if not re.search(r'[A-Z]', password):
        return "Sifre en az bir buyuk harf icermelidir"
    if not re.search(r'[a-z]', password):
        return "Sifre en az bir kucuk harf icermelidir"
    if not re.search(r'[0-9]', password):
        return "Sifre en az bir rakam icermelidir"
    return None


def _hash_password(password: str) -> str:
    """🔒 bcrypt ile guvenli sifre hashleme (12 round)."""
    return bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt(rounds=12)).decode('utf-8')


def _verify_password(password: str, stored_hash: str) -> bool:
    """🔒 bcrypt ile sifre dogrulama."""
    try:
        return bcrypt.checkpw(password.encode('utf-8'), stored_hash.encode('utf-8'))
    except Exception:
        return False


def _create_jwt(payload: Dict[str, Any]) -> str:
    """🔒 PyJWT kutuphanesi ile guvenli JWT olusturma."""
    # PyJWT >= 2.10 "sub" alaninin string olmasini zorunlu kilar; users.id SERIAL (int)
    # oldugu icin aksi halde uretilen her token dogrulamada reddedilir.
    if payload.get("sub") is not None:
        payload["sub"] = str(payload["sub"])
    payload["exp"] = datetime.now(timezone.utc) + timedelta(hours=JWT_EXPIRE_HOURS)
    payload["iat"] = datetime.now(timezone.utc)
    return pyjwt.encode(payload, SECRET_KEY, algorithm=JWT_ALGORITHM)


def _verify_jwt(token: str) -> Optional[Dict[str, Any]]:
    """🔒 PyJWT kutuphanesi ile guvenli JWT dogrulama."""
    try:
        payload = pyjwt.decode(token, SECRET_KEY, algorithms=[JWT_ALGORITHM])
        return payload
    except pyjwt.ExpiredSignatureError:
        logger.warning("JWT token suresi dolmus")
        return None
    except pyjwt.InvalidTokenError as e:
        logger.warning(f"Gecersiz JWT token: {e}")
        return None


class AuthService:
    def __init__(self):
        self._db_type = DatabaseConfig._get_db_type()

    @property
    def _p(self):
        return "%s"

    def _is_valid_uuid(self, val: str) -> bool:
        """Check if a string is a valid UUID (for backward compatibility with old API keys)."""
        import re
        uuid_pattern = re.compile(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            re.IGNORECASE
        )
        return bool(uuid_pattern.match(val))

    def register(self, email: str, password: str, full_name: str = None, phone: str = None) -> Dict[str, Any]:
        # 🔒 Email validasyonu
        if not email or not _validate_email(email):
            return {"error": "Gecersiz email formati"}
        
        # 🔒 Sifre gucu validasyonu
        pw_error = _validate_password_strength(password)
        if pw_error:
            return {"error": pw_error}
        
        from yerimebak_ai_v5.services.payment_service import FREE_CREDITS_ON_REGISTER
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT id FROM users WHERE email = {self._p}", (email,))
            if cursor.fetchone():
                return {"error": "Bu email adresi zaten kayitli"}

            import uuid
            api_key = f"yk-{uuid.uuid4().hex[:24]}"
            hashed_pw = _hash_password(password)

            cursor.execute(f"""
                INSERT INTO users (email, password, full_name, phone, api_key, credits, tier, role, is_active)
                VALUES ({self._p}, {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, 'free', 'user', 1)
            """, (email, hashed_pw, full_name, phone, api_key, FREE_CREDITS_ON_REGISTER))
            conn.commit()

            cursor.execute(f"SELECT id, email, full_name, phone, api_key, credits, tier, role FROM users WHERE email = {self._p}", (email,))
            user = dict(cursor.fetchone())

            token = _create_user_jwt(user)

            return {
                "success": True,
                "user": user,
                "token": token,
                "api_key": api_key,
                "message": f"Kayit basarili. {FREE_CREDITS_ON_REGISTER} ucretsiz kredi yuklendi."
            }
        finally:
            DatabaseConfig.return_connection(conn)  # 🔒 DÜZELTİLDİ: conn.close() -> pool'a geri ver

    def register_with_phone(self, phone: str, full_name: str, email: str = None) -> Dict[str, Any]:
        from yerimebak_ai_v5.services.payment_service import FREE_CREDITS_ON_REGISTER
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT id FROM users WHERE phone = {self._p}", (phone,))
            if cursor.fetchone():
                return {"error": "Bu telefon numarasi zaten kayitli"}

            if email:
                cursor.execute(f"SELECT id FROM users WHERE email = {self._p}", (email,))
                if cursor.fetchone():
                    return {"error": "Bu email adresi zaten kayitli"}

            import uuid
            api_key = f"yk-{uuid.uuid4().hex[:24]}"
            temp_pass = secrets.token_hex(16)
            hashed_pw = _hash_password(temp_pass)

            cursor.execute(f"""
                INSERT INTO users (email, password, full_name, phone, api_key, credits, tier, role, is_active)
                VALUES ({self._p}, {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, 'free', 'user', 1)
            """, (email or f"{phone}@yerimebak.ai", hashed_pw, full_name, phone, api_key, FREE_CREDITS_ON_REGISTER))
            conn.commit()

            cursor.execute(f"SELECT id, email, full_name, api_key, credits, tier, role, phone FROM users WHERE phone = {self._p}", (phone,))
            user = dict(cursor.fetchone())

            token = _create_user_jwt(user)

            return {
                "success": True,
                "user": user,
                "token": token,
                "api_key": api_key,
                "message": f"Kayit basarili. {FREE_CREDITS_ON_REGISTER} ucretsiz kredi yuklendi."
            }
        finally:
            DatabaseConfig.return_connection(conn)  # 🔒 DÜZELTİLDİ: conn.close() -> pool'a geri ver

    def login_with_otp(self, phone: str, otp_code: str = None) -> Dict[str, Any]:
        """🔒 DÜZELTİLDİ (Security): OTP kodu zorunlu!
        Önceki implementasyon sadece telefon numarası alıp direkt login yapıyordu.
        """
        conn = DatabaseConfig.get_connection()
        try:
            if not otp_code:
                return {"error": "OTP kodu zorunludur. Telefon numarasi ile dogrulama yapilmali."}

            cursor = conn.cursor()
            cursor.execute(f"SELECT * FROM users WHERE phone = {self._p}", (phone,))
            row = cursor.fetchone()

            if not row:
                return {"error": "Bu telefon numarasi ile kayitli hesap bulunamadi"}

            user = dict(row)

            if not user.get('is_active', 1):
                return {"error": "Hesabiniz devre disi birakilmis"}

            # 🔒 GÜVENLİK: OTP kodu dogrulamasi
            cursor.execute(f"""
                SELECT id FROM otp_codes 
                WHERE phone = {self._p}
                AND code = {self._p}
                AND expires_at > CURRENT_TIMESTAMP 
                AND used = 0
                ORDER BY created_at DESC LIMIT 1
            """, (phone, otp_code))
            
            otp_row = cursor.fetchone()
            if not otp_row:
                # OTP tablosu yoksa veya kod yanlissa -> hata
                return {
                    "error": "Gecersiz veya sureyi dolmus OTP kodu. "
                             "Lutfen yeni bir dogrulama kodu isteyin."
                }
            
            # OTP kodunu kullanildi olarak isaretle (replay attack önleme)
            cursor.execute(f"""
                UPDATE otp_codes SET used = 1 WHERE id = {self._p}
            """, (otp_row['id'],))
            conn.commit()

            cursor.execute(f"""
                UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = {self._p}
            """, (user['id'],))
            conn.commit()

            return {
                "success": True,
                "user": {
                    "id": user['id'],
                    "email": user['email'],
                    "full_name": user.get('full_name'),
                    "phone": user.get('phone'),
                    "api_key": user['api_key'],
                    "credits": user['credits'],
                    "tier": user['tier'],
                    "role": user['role'],
                }
            }
        finally:
            DatabaseConfig.return_connection(conn)

    def verify_token(self, token: str) -> Optional[Dict[str, Any]]:
        payload = _verify_jwt(token)
        if not payload:
            return None

        user_id = payload.get("sub")
        if not user_id:
            return None

        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT * FROM users WHERE id = {self._p}", (user_id,))
            row = cursor.fetchone()
            if not row:
                return None
            user = dict(row)
            if not user.get('is_active', 1):
                return None
            return {
                "id": user['id'],
                "email": user['email'],
                "full_name": user.get('full_name'),
                "phone": user.get('phone'),
                "credits": user['credits'],
                "tier": user['tier'],
                "role": user['role'],
                "api_key": user['api_key'],
            }
        finally:
            DatabaseConfig.return_connection(conn)  # 🔒 DÜZELTİLDİ: conn.close() -> pool'a geri ver

    def refresh_token(self, user_id: int) -> Optional[str]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                f"SELECT id, email, full_name, phone, credits, tier, role FROM users WHERE id = {self._p}",
                (user_id,),
            )
            row = cursor.fetchone()
            if not row:
                return None
            user = dict(row)
            return _create_user_jwt(user)
        finally:
            DatabaseConfig.return_connection(conn)  # 🔒 DÜZELTİLDİ: conn.close() -> pool'a geri ver

    def login(self, email: str, password: str) -> Dict[str, Any]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT * FROM users WHERE email = {self._p}", (email,))
            row = cursor.fetchone()

            if not row:
                return {"error": "Gecersiz email veya sifre"}

            user = dict(row)

            if not user.get('password') or not _verify_password(password, user['password']):
                return {"error": "Gecersiz email veya sifre"}

            if not user.get('is_active', 1):
                return {"error": "Hesabiniz devre disi birakilmis"}

            cursor.execute(f"""
                UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = {self._p}
            """, (user['id'],))
            conn.commit()

            return {
                "success": True,
                "user": {
                    "id": user['id'],
                    "email": user['email'],
                    "full_name": user.get('full_name'),
                    "api_key": user['api_key'],
                    "credits": user['credits'],
                    "tier": user['tier'],
                    "role": user['role'],
                }
            }
        finally:
            DatabaseConfig.return_connection(conn)  # 🔒 DÜZELTİLDİ: conn.close() -> pool'a geri ver

    def change_password(self, user_id: Any, current_password: str, new_password: str) -> Dict[str, Any]:
        """Mevcut sifre dogrulanarak yeni sifre kaydedilir."""
        if not current_password or not new_password:
            return {"error": "Mevcut ve yeni sifre zorunludur"}
        if current_password == new_password:
            return {"error": "Yeni sifre mevcut sifreden farkli olmalidir"}
        strength_error = _validate_password_strength(new_password)
        if strength_error:
            return {"error": strength_error}

        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT id, password FROM users WHERE id = {self._p}", (user_id,))
            row = cursor.fetchone()
            if not row:
                return {"error": "Kullanici bulunamadi", "http_status": 404}
            user = dict(row)
            if not user.get('password') or not _verify_password(current_password, user['password']):
                return {"error": "Mevcut sifre hatali", "http_status": 403}

            cursor.execute(
                f"UPDATE users SET password = {self._p} WHERE id = {self._p}",
                (_hash_password(new_password), user['id']),
            )
            conn.commit()
            return {"success": True}
        finally:
            DatabaseConfig.return_connection(conn)

    def verify_api_key(self, api_key: str) -> Optional[Dict[str, Any]]:
        if not api_key:
            return None

        # Accept both new-style (yk-) and old-style (UUID) API keys
        # Old admin accounts may have UUID-format keys without yk- prefix
        if not (api_key.startswith("yk-") or self._is_valid_uuid(api_key)):
            return None

        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT * FROM users WHERE api_key = {self._p}", (api_key,))
            row = cursor.fetchone()

            if not row:
                return None

            user = dict(row)
            if not user.get('is_active', 1):
                return None

            return {
                "id": user['id'],
                "email": user['email'],
                "credits": user['credits'],
                "tier": user['tier'],
                "role": user['role'],
                "api_key": user['api_key'],
            }
        finally:
            DatabaseConfig.return_connection(conn)  # 🔒 DÜZELTİLDİ: conn.close() -> pool'a geri ver

    def create_admin(self, email: str, password: str, admin_key: str) -> Dict[str, Any]:
        # 🔒 GÜVENLİK: Varsayilan admin key kaldirildi. Ortam degiskeni zorunlu.
        expected_key = os.getenv("ADMIN_SECRET_KEY")
        if not expected_key:
            return {"error": "Sunucu yapilandirma hatasi: ADMIN_SECRET_KEY tanimlanmamis"}
        
        if admin_key != expected_key:
            return {"error": "Gecersiz admin anahtari"}

        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT id FROM users WHERE email = {self._p}", (email,))
            if cursor.fetchone():
                return {"error": "Bu email zaten kayitli"}

            import uuid
            api_key = f"yk-{uuid.uuid4().hex[:24]}"
            hashed_pw = _hash_password(password)

            cursor.execute(f"""
                INSERT INTO users (email, password, api_key, credits, tier, role, is_active)
                VALUES ({self._p}, {self._p}, {self._p}, 1000, 'enterprise', 'admin', 1)
            """, (email, hashed_pw, api_key))
            conn.commit()

            return {"success": True, "api_key": api_key, "message": "Admin hesabi olusturuldu"}
        finally:
            DatabaseConfig.return_connection(conn)  # 🔒 DÜZELTİLDİ: conn.close() -> pool'a geri ver


_auth_service = None

def get_auth_service() -> AuthService:
    global _auth_service
    if _auth_service is None:
        _auth_service = AuthService()
    return _auth_service


def _create_user_jwt(user: Dict[str, Any]) -> str:
    return _create_jwt({
        "sub": user["id"],
        "email": user["email"],
        "full_name": user.get("full_name"),
        "phone": user.get("phone"),
        "credits": user.get("credits", 0),
        "tier": user.get("tier", "free"),
        "role": user.get("role", "user"),
    })
