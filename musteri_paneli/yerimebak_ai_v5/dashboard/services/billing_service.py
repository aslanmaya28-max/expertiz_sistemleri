# -*- coding: utf-8 -*-
"""
YERİMEBAK AI — Billing & Credits Service
PostgreSQL Only — Single Source of Truth
"""

import logging
import uuid
from typing import Optional
from datetime import datetime

logger = logging.getLogger(__name__)

from yerimebak_ai_v5.core.database_config import DatabaseConfig


class BillingService:
    def __init__(self, db_path=None):
        # db_path ignored — PostgreSQL only
        self._ensure_tables()

    def _get_conn(self):
        return DatabaseConfig.get_connection()

    def _ensure_tables(self):
        try:
            from yerimebak_ai_v5.core.database_config import DatabaseConfig
            DatabaseConfig.bootstrap()
            DatabaseConfig.alignment()
        except Exception as e:
            logger.error(f"[BILLING] Table init error: {e}")

    def get_user_credits(self, email: str) -> int:
        try:
            conn = self._get_conn()
            cursor = conn.cursor()
            cursor.execute("SELECT credits FROM users WHERE email = %s", (email,))
            row = cursor.fetchone()
            conn.close()
            if row:
                return int(dict(row)['credits'])
            return 0
        except Exception as e:
            logger.error(f"[BILLING] Kredi okuma hatası: {e}")
            return 0

    def deduct_credit(self, email: str, amount: int = 1) -> bool:
        try:
            conn = self._get_conn()
            cursor = conn.cursor()
            cursor.execute("SELECT credits FROM users WHERE email = %s", (email,))
            row = cursor.fetchone()
            if row and int(dict(row)['credits']) >= amount:
                cursor.execute("UPDATE users SET credits = credits - %s WHERE email = %s", (amount, email))
                conn.commit()
                conn.close()
                return True
            conn.close()
            return False
        except Exception as e:
            logger.error(f"[BILLING] Kredi düşme hatası: {e}")
            return False

    def add_credits(self, email: str, amount: int) -> bool:
        try:
            conn = self._get_conn()
            cursor = conn.cursor()
            cursor.execute("UPDATE users SET credits = credits + %s WHERE email = %s", (amount, email))
            conn.commit()
            conn.close()
            return True
        except Exception as e:
            logger.error(f"[BILLING] Kredi ekleme hatası: {e}")
            return False

    def get_analysis_history(self, limit: int = 50) -> list:
        try:
            conn = self._get_conn()
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM analysis_history ORDER BY created_at DESC LIMIT %s", (limit,))
            rows = [dict(r) for r in cursor.fetchall()]
            conn.close()
            return rows
        except Exception:
            return []

    def save_analysis(self, email: str, vehicle_json: str, valuation_json: str) -> bool:
        try:
            user_id = self._get_user_id(email)
            conn = self._get_conn()
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO analysis_history (id, user_id, vehicle_json, valuation_json)
                VALUES (%s, %s, %s, %s)
            """, (str(uuid.uuid4()), user_id, vehicle_json, valuation_json))
            conn.commit()
            conn.close()
            return True
        except Exception as e:
            logger.error(f"[BILLING] History save error: {e}")
            return False

    def _get_user_id(self, email: str) -> Optional[int]:
        try:
            conn = self._get_conn()
            cursor = conn.cursor()
            cursor.execute("SELECT id FROM users WHERE email = %s", (email,))
            row = cursor.fetchone()
            conn.close()
            if row:
                return int(dict(row)['id'])
            return None
        except Exception:
            return None


def get_billing_service():
    return BillingService()