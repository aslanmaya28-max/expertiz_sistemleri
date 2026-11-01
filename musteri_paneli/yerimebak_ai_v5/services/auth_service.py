# -*- coding: utf-8 -*-
"""
YERIMEBAK AI v8.2 - Auth Service (Güvenlik Güncellemesi)
Kullanici kimlik dogrulama ve oturum yonetimi
🔒 GÜVENLİK: bcrypt + PyJWT kullanir, SHA-256 el yapimi JWT kaldirildi
"""
import logging
import os
import hmac
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

            hashed_pw = _hash_password(password)

            # Hos geldin kredisi e-posta dogrulaninca yuklenir (account_service.verify_email)
            from yerimebak_ai_v5.services import account_service
            account_service.ensure_schema()
            cursor.execute(f"""
                INSERT INTO users (email, password, full_name, phone, credits, role, is_active,
                                   email_verified, welcome_credits_granted)
                VALUES ({self._p}, {self._p}, {self._p}, {self._p}, 0, 'user', 1, FALSE, FALSE)
            """, (email, hashed_pw, full_name, phone))
            conn.commit()

            cursor.execute(f"SELECT id, email, full_name, phone, credits, role FROM users WHERE email = {self._p}", (email,))
            user = dict(cursor.fetchone())
            user["email_verified"] = False

            token = _create_user_jwt(user)
            account_service.send_verification(user["id"], email, full_name or "")

            bonus = f" Dogrulamadan sonra {FREE_CREDITS_ON_REGISTER} ucretsiz kredi yuklenir." if FREE_CREDITS_ON_REGISTER else ""
            return {
                "success": True,
                "user": user,
                "token": token,
                "email_verification_required": True,
                "message": f"Kayit basarili. E-posta adresinize dogrulama baglantisi gonderdik.{bonus}"
            }
        finally:
            DatabaseConfig.return_connection(conn)  # 🔒 DÜZELTİLDİ: conn.close() -> pool'a geri ver

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
                "role": user['role'],
            }
        finally:
            DatabaseConfig.return_connection(conn)  # 🔒 DÜZELTİLDİ: conn.close() -> pool'a geri ver

    def refresh_token(self, user_id: int) -> Optional[str]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                f"SELECT id, email, full_name, phone, credits, role FROM users WHERE id = {self._p}",
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
                    "credits": user['credits'],
                    "role": user['role'],
                    "email_verified": user.get('email_verified') is not False,
                    "must_change_password": bool(user.get('must_change_password')),
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

            # Gecici sifre ile giren personel sifresini degistirince zorunluluk kalkar
            cursor.execute(
                f"UPDATE users SET password = {self._p}, must_change_password = FALSE WHERE id = {self._p}",
                (_hash_password(new_password), user['id']),
            )
            conn.commit()
            return {"success": True}
        finally:
            DatabaseConfig.return_connection(conn)


    def create_admin(self, email: str, password: str, admin_key: str) -> Dict[str, Any]:
        # 🔒 GÜVENLİK: Varsayilan admin key kaldirildi. Ortam degiskeni zorunlu.
        expected_key = os.getenv("ADMIN_SECRET_KEY")
        if not expected_key:
            return {"error": "Sunucu yapilandirma hatasi: ADMIN_SECRET_KEY tanimlanmamis"}
        
        if not hmac.compare_digest(str(admin_key or ""), expected_key):
            return {"error": "Gecersiz admin anahtari"}

        return self._insert_admin(email, password)

    def ensure_initial_admin(self) -> Optional[str]:
        """Sunucu ilk acilista INITIAL_ADMIN_EMAIL / INITIAL_ADMIN_PASSWORD (.env)
        tanimliysa ve bu e-postada hesap yoksa admin hesabini olusturur.
        Sifre kod deposuna yazilmaz; yalnizca sunucudaki .env dosyasinda durur."""
        email = (os.getenv("INITIAL_ADMIN_EMAIL") or "").strip().lower()
        password = os.getenv("INITIAL_ADMIN_PASSWORD") or ""
        if not email or not password:
            return None
        if not _validate_email(email):
            logger.error("INITIAL_ADMIN_EMAIL gecersiz: %s", email)
            return None
        weak = _validate_password_strength(password)
        if weak:
            logger.error("INITIAL_ADMIN_PASSWORD yeterince guclu degil: %s", weak)
            return None
        result = self._insert_admin(email, password)
        if result.get("success"):
            logger.info("Ilk admin hesabi olusturuldu: %s", email)
            return email
        return None

    def _insert_admin(self, email: str, password: str) -> Dict[str, Any]:
        from yerimebak_ai_v5.services import account_service
        account_service.ensure_schema()

        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT id FROM users WHERE lower(email) = lower({self._p})", (email,))
            if cursor.fetchone():
                conn.commit()
                return {"error": "Bu email zaten kayitli"}

            hashed_pw = _hash_password(password)

            cursor.execute(f"""
                INSERT INTO users (email, password, credits, role, is_active,
                                   email_verified, welcome_credits_granted)
                VALUES ({self._p}, {self._p}, 1000, 'admin', 1, TRUE, TRUE)
            """, (email, hashed_pw))
            conn.commit()

            return {"success": True, "message": "Admin hesabi olusturuldu"}
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
        "role": user.get("role", "user"),
    })
