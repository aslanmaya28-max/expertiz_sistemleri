# -*- coding: utf-8 -*-
"""
YERİMEBAK AI — Authentication & User Management Service
PostgreSQL Only — Single Source of Truth
"""

import hashlib
import uuid
import random
import string
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

from yerimebak_ai_v5.core.database_config import DatabaseConfig


class AuthService:
    def __init__(self, db_path=None):
        # db_path ignored — PostgreSQL only
        self._ensure_tables()

    def _get_conn(self):
        return DatabaseConfig.get_connection()

    def _ensure_tables(self):
        try:
            conn = self._get_conn()
            cursor = conn.cursor()
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    email TEXT UNIQUE NOT NULL,
                    password TEXT NOT NULL,
                    username TEXT,
                    full_name TEXT,
                    phone TEXT,
                    phone_verified INTEGER DEFAULT 0,
                    profile_image TEXT,
                    credits INTEGER DEFAULT 0,
                    api_key TEXT,
                    tier TEXT DEFAULT 'free',
                    role TEXT DEFAULT 'user',
                    last_login TIMESTAMP,
                    is_active INTEGER DEFAULT 1,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS otp_codes (
                    id SERIAL PRIMARY KEY,
                    phone TEXT NOT NULL,
                    code TEXT NOT NULL,
                    expires_at TIMESTAMP NOT NULL,
                    used INTEGER DEFAULT 0,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS sessions (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    session_token TEXT UNIQUE NOT NULL,
                    expires_at TIMESTAMP NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY (user_id) REFERENCES users(id)
                )
            """)

            try:
                cursor.execute("SELECT role FROM users LIMIT 1")
            except Exception:
                cursor.execute("ALTER TABLE users ADD COLUMN role TEXT DEFAULT 'user'")
                conn.commit()

            conn.commit()
        except Exception as e:
            logger.error(f"[AUTH] Table creation error: {e}")
        finally:
            conn.close()

    def _normalize_phone(self, phone: str) -> str:
        phone = phone.strip().replace(" ", "").replace("-", "").replace("(", "").replace(")", "")
        if phone.startswith("0"):
            phone = "+90" + phone[1:]
        elif phone.startswith("90") and not phone.startswith("+90"):
            phone = "+" + phone
        elif not phone.startswith("+"):
            phone = "+90" + phone
        return phone

    def generate_otp(self, phone: str) -> str:
        phone = self._normalize_phone(phone)
        code = ''.join(random.choices(string.digits, k=6))
        expires_at = datetime.now() + timedelta(minutes=5)

        conn = self._get_conn()
        try:
            cursor = conn.cursor()
            cursor.execute("UPDATE otp_codes SET used = 1 WHERE phone = %s AND used = 0", (phone,))
            cursor.execute(
                "INSERT INTO otp_codes (phone, code, expires_at) VALUES (%s, %s, %s)",
                (phone, code, expires_at.isoformat())
            )
            conn.commit()
        finally:
            conn.close()
        return code

    def verify_otp(self, phone: str, code: str) -> bool:
        phone = self._normalize_phone(phone)
        conn = self._get_conn()
        try:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT id, expires_at FROM otp_codes 
                WHERE phone = %s AND code = %s AND used = 0
                ORDER BY created_at DESC LIMIT 1
            """, (phone, code))
            row = cursor.fetchone()

            if not row:
                return False

            row = dict(row)
            expires = datetime.fromisoformat(str(row['expires_at']))
            if datetime.now() > expires:
                return False

            cursor.execute("UPDATE otp_codes SET used = 1 WHERE id = %s", (row['id'],))
            conn.commit()
        finally:
            conn.close()
        return True

    def register_user(self, full_name: str, phone: str, password: str = None) -> dict:
        phone = self._normalize_phone(phone)
        email = f"{phone.replace('+', '')}@yerimebak.com"
        api_key = str(uuid.uuid4())
        hashed_pw = hashlib.sha256((password or phone).encode()).hexdigest()

        conn = self._get_conn()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM users WHERE phone = %s", (phone,))
            existing = cursor.fetchone()
            if existing:
                return {"success": False, "error": "Bu telefon numarası zaten kayıtlı.", "user_id": dict(existing)['id']}

            try:
                cursor.execute("""
                    INSERT INTO users (username, email, password, full_name, phone, phone_verified, credits, api_key, tier, role, is_active)
                    VALUES (%s, %s, %s, %s, %s, 1, 3, %s, 'free', 'user', 1)
                    RETURNING id
                """, (email.split('@')[0], email, hashed_pw, full_name, phone, api_key))
                user_id = cursor.fetchone()['id']
                conn.commit()

                return {
                    "success": True,
                    "user_id": user_id,
                    "email": email,
                    "api_key": api_key,
                    "credits": 3,
                    "full_name": full_name,
                    "phone": phone
                }
            except Exception as e:
                logger.error(f"[AUTH] Register error: {e}")
                return {"success": False, "error": f"Kayıt hatası: {e}"}
        finally:
            conn.close()

    def login_with_phone(self, phone: str) -> dict:
        phone = self._normalize_phone(phone)
        conn = self._get_conn()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users WHERE phone = %s", (phone,))
            user = cursor.fetchone()

            if not user:
                return {"success": False, "error": "Kayıt bulunamadı."}

            user = dict(user)
            session_token = str(uuid.uuid4())
            expires_at = datetime.now() + timedelta(days=30)

            cursor.execute("""
                INSERT INTO sessions (user_id, session_token, expires_at)
                VALUES (%s, %s, %s)
            """, (user['id'], session_token, expires_at.isoformat()))

            cursor.execute("UPDATE users SET last_login = %s WHERE id = %s", (datetime.now().isoformat(), user['id']))
            conn.commit()

            return {
                "success": True,
                "user_id": user['id'],
                "full_name": user['full_name'] or "",
                "phone": phone,
                "email": user['email'],
                "credits": user['credits'],
                "tier": user['tier'],
                "role": user.get('role', 'user'),
                "api_key": user['api_key'],
                "session_token": session_token
            }
        finally:
            conn.close()

    def register_with_google(self, email: str, full_name: str) -> dict:
        api_key = str(uuid.uuid4())
        hashed_pw = hashlib.sha256(email.encode()).hexdigest()

        conn = self._get_conn()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
            existing = cursor.fetchone()
            if existing:
                return {"success": False, "error": "Bu Google hesabı zaten kayıtlı.", "user_id": dict(existing)['id']}

            try:
                cursor.execute("""
                    INSERT INTO users (username, email, password, full_name, phone, phone_verified, credits, api_key, tier, role, is_active)
                    VALUES (%s, %s, %s, %s, %s, 1, 3, %s, 'free', 'user', 1)
                    RETURNING id
                """, (email.split('@')[0], email, hashed_pw, full_name, "Google", api_key))
                conn.commit()
                return {"success": True, "email": email, "api_key": api_key, "credits": 3, "full_name": full_name}
            except Exception as e:
                logger.error(f"[AUTH] Google register error: {e}")
                return {"success": False, "error": f"Google Kayıt hatası: {e}"}
        finally:
            conn.close()

    def login_with_google(self, email: str) -> dict:
        conn = self._get_conn()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM users WHERE email = %s", (email,))
            user = cursor.fetchone()

            if not user:
                return {"success": False, "error": "Kayıt bulunamadı."}

            user = dict(user)
            session_token = str(uuid.uuid4())
            expires_at = datetime.now() + timedelta(days=30)

            cursor.execute("""
                INSERT INTO sessions (user_id, session_token, expires_at)
                VALUES (%s, %s, %s)
            """, (user['id'], session_token, expires_at.isoformat()))

            cursor.execute("UPDATE users SET last_login = %s WHERE id = %s", (datetime.now().isoformat(), user['id']))
            conn.commit()

            return {
                "success": True,
                "user_id": user['id'],
                "full_name": user['full_name'] or "",
                "phone": user['phone'],
                "email": user['email'],
                "credits": user['credits'],
                "tier": user['tier'],
                "role": user.get('role', 'user'),
                "api_key": user['api_key'],
                "session_token": session_token
            }
        finally:
            conn.close()

    def get_user_by_session(self, session_token: str) -> dict:
        if not session_token:
            return None
        conn = self._get_conn()
        try:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT u.*, s.session_token FROM sessions s
                JOIN users u ON s.user_id = u.id
                WHERE s.session_token = %s AND s.expires_at > %s
            """, (session_token, datetime.now().isoformat()))
            row = cursor.fetchone()
            if row:
                return dict(row)
        finally:
            conn.close()
        return None


def get_auth_service():
    return AuthService()