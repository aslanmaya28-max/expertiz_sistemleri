# -*- coding: utf-8 -*-
"""
YERIMEBAK AI v8.1 - Payment Service
Kredi yukleme, odeme takibi ve hesap yonetimi
"""
import os
import uuid
import logging
import json
from datetime import datetime
from typing import Dict, Any, Optional, List

from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)

# 🔒 GÜVENLİK: Sabit değerler .env'den alinir
CREDIT_PACKAGES = json.loads(os.getenv("CREDIT_PACKAGES", json.dumps({
    "tek": {"credits": 1, "price": 100, "name": "Tek Analiz", "popular": False},
    "besli": {"credits": 5, "price": 400, "name": "5 Analiz", "popular": False},
    "onlu": {"credits": 10, "price": 750, "name": "10 Analiz", "popular": True},
    "kurumsal": {"credits": 50, "price": 3000, "name": "Kurumsal 50 Analiz", "popular": False},
})))

FREE_CREDITS_ON_REGISTER = int(os.getenv("FREE_CREDITS_ON_REGISTER", "3"))

TIER_LIMITS = json.loads(os.getenv("TIER_LIMITS", json.dumps({
    "free": {"monthly_credits": 10, "max_analyses_per_day": 5},
    "starter": {"monthly_credits": 25, "max_analyses_per_day": 20},
    "basic": {"monthly_credits": 50, "max_analyses_per_day": 50},
    "pro": {"monthly_credits": 150, "max_analyses_per_day": 200},
    "enterprise": {"monthly_credits": 500, "max_analyses_per_day": -1},
})))

ANALYSIS_CREDIT_COST = int(os.getenv("ANALYSIS_CREDIT_COST", "1"))


class PaymentService:
    def __init__(self):
        self._db_type = DatabaseConfig._get_db_type()

    @property
    def _p(self):
        return "%s"

    def get_or_create_user(self, email: str, phone: str = None, full_name: str = None) -> Dict[str, Any]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT * FROM users WHERE email = {self._p}", (email,))
            row = cursor.fetchone()

            if row:
                user = dict(row)
                return user

            api_key = f"yk-{uuid.uuid4().hex[:24]}"
            cursor.execute(f"""
                INSERT INTO users (email, phone, full_name, api_key, credits, tier, role, is_active)
                VALUES ({self._p}, {self._p}, {self._p}, {self._p}, 3, 'free', 'user', 1)
            """, (email, phone, full_name, api_key))
            conn.commit()

            cursor.execute(f"SELECT * FROM users WHERE email = {self._p}", (email,))
            row = cursor.fetchone()
            return dict(row)
        finally:
            DatabaseConfig.return_connection(conn)

    def get_user_by_api_key(self, api_key: str) -> Optional[Dict[str, Any]]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT * FROM users WHERE api_key = {self._p}", (api_key,))
            row = cursor.fetchone()
            return dict(row) if row else None
        finally:
            DatabaseConfig.return_connection(conn)

    def get_user_by_id(self, user_id: int) -> Optional[Dict[str, Any]]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT * FROM users WHERE id = {self._p}", (user_id,))
            row = cursor.fetchone()
            return dict(row) if row else None
        finally:
            DatabaseConfig.return_connection(conn)

    def get_credit_balance(self, user_id: int) -> Dict[str, Any]:
        user = self.get_user_by_id(user_id)
        if not user:
            return {"error": "Kullanici bulunamadi"}

        return {
            "user_id": user['id'],
            "email": user['email'],
            "credits": user['credits'],
            "tier": user['tier'],
            "role": user['role'],
        }

    def deduct_credits(
        self,
        user_id: int,
        amount: int = ANALYSIS_CREDIT_COST,
        description: str = "Arac analizi",
        vehicle_data: Optional[Dict[str, Any]] = None,
        valuation_data: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            # 🔒 DÜZELTİLDİ (B3): FOR UPDATE ile satır kilidi — TOCTOU race condition önlendi
            # Kredi düşümü atomik hale getirildi: tek bir UPDATE ile kontrol + düşüm
            cursor.execute(f"""
                UPDATE users 
                SET credits = credits - {self._p} 
                WHERE id = {self._p} AND credits >= {self._p}
                RETURNING credits, tier
            """, (amount, user_id, amount))
            row = cursor.fetchone()

            if not row:
                # Yetersiz kredi veya kullanıcı yok
                cursor.execute(f"SELECT credits FROM users WHERE id = {self._p}", (user_id,))
                check = cursor.fetchone()
                if not check:
                    return {"success": False, "error": "Kullanici bulunamadi"}
                return {"success": False, "error": "Yetersiz kredi", "credits": check['credits'], "required": amount}

            new_credits = row['credits']

            history_id = str(uuid.uuid4())
            vehicle_json = vehicle_data or {"description": description}
            valuation_json = valuation_data or {"credits_deducted": amount}

            cursor.execute(f"""
                INSERT INTO analysis_history (id, user_id, vehicle_json, valuation_json)
                VALUES ({self._p}, {self._p}, {self._p}, {self._p})
            """, (
                history_id,
                user_id,
                json.dumps(vehicle_json, ensure_ascii=False, default=str),
                json.dumps(valuation_json, ensure_ascii=False, default=str),
            ))

            # Log to credit_usage_logs for audit trail
            try:
                cursor.execute(f"""
                    INSERT INTO credit_usage_logs (user_id, action, credits_used, description)
                    VALUES ({self._p}, {self._p}, {self._p}, {self._p})
                """, (user_id, "analysis", amount, description))
            except Exception:
                logger.warning("credit_usage_logs insert skipped (table may not exist yet)")

            conn.commit()

            return {
                "success": True,
                "credits_before": new_credits + amount,
                "credits_after": new_credits,
                "deducted": amount,
                "history_id": history_id,
                "description": description
            }
        finally:
            DatabaseConfig.return_connection(conn)

    def check_credits_before_analysis(self, user_id: int) -> bool:
        user = self.get_user_by_id(user_id)
        if not user:
            return False
        return user['credits'] >= ANALYSIS_CREDIT_COST

    def create_payment_order(self, user_id: int, package_key: str, payment_method: str = "havale", payment_ref: str = None) -> Dict[str, Any]:
        if package_key not in CREDIT_PACKAGES:
            return {"error": f"Gecersiz paket: {package_key}. Gecerli paketler: {list(CREDIT_PACKAGES.keys())}"}

        pkg = CREDIT_PACKAGES[package_key]
        user = self.get_user_by_id(user_id)
        if not user:
            return {"error": "Kullanici bulunamadi"}

        order_id = f"ORD-{uuid.uuid4().hex[:12].upper()}"

        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                INSERT INTO payment_orders (id, user_id, user_email, user_phone, package_key, package_name, credits, amount_tl, status, payment_method, payment_ref)
                VALUES ({self._p}, {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, {self._p})
            """, (
                order_id, user_id, user['email'], user.get('phone'),
                package_key, pkg['name'], pkg['credits'], pkg['price'],
                'pending', payment_method, payment_ref
            ))
            conn.commit()

            return {
                "order_id": order_id,
                "package": pkg,
                "payment_method": payment_method,
                "status": "pending",
                "message": "Siparis olusturuldu. Odeme bekleniyor."
            }
        finally:
            DatabaseConfig.return_connection(conn)

    def approve_payment_order(self, order_id: str, approved_by: str = "admin", admin_note: str = None) -> Dict[str, Any]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT * FROM payment_orders WHERE id = {self._p}", (order_id,))
            order = cursor.fetchone()

            if not order:
                return {"error": "Siparis bulunamadi"}

            order = dict(order)

            if order['status'] != 'pending':
                return {"error": f"Siparis zaten '{order['status']}' durumunda"}

            cursor.execute(f"""
                UPDATE payment_orders
                SET status = 'approved', approved_by = {self._p}, approved_at = CURRENT_TIMESTAMP,
                    admin_note = {self._p}, updated_at = CURRENT_TIMESTAMP
                WHERE id = {self._p}
            """, (approved_by, admin_note, order_id))

            cursor.execute(f"""
                UPDATE users SET credits = credits + {self._p} WHERE id = {self._p}
            """, (order['credits'], order['user_id']))

            conn.commit()

            updated_user = self.get_user_by_id(order['user_id'])

            return {
                "success": True,
                "order_id": order_id,
                "credits_added": order['credits'],
                "new_balance": updated_user['credits'] if updated_user else None,
                "approved_by": approved_by,
                "message": f"{order['credits']} kredi yuklendi."
            }
        finally:
            DatabaseConfig.return_connection(conn)

    def reject_payment_order(self, order_id: str, rejected_by: str = "admin", admin_note: str = None) -> Dict[str, Any]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT * FROM payment_orders WHERE id = {self._p}", (order_id,))
            order = cursor.fetchone()

            if not order:
                return {"error": "Siparis bulunamadi"}

            order = dict(order)

            if order['status'] != 'pending':
                return {"error": f"Siparis zaten '{order['status']}' durumunda"}

            cursor.execute(f"""
                UPDATE payment_orders
                SET status = 'rejected', approved_by = {self._p}, admin_note = {self._p}, updated_at = CURRENT_TIMESTAMP
                WHERE id = {self._p}
            """, (rejected_by, admin_note, order_id))

            conn.commit()

            return {"success": True, "order_id": order_id, "message": "Siparis reddedildi."}
        finally:
            DatabaseConfig.return_connection(conn)

    def get_payment_orders(self, user_id: int = None, status: str = None, limit: int = 50) -> List[Dict[str, Any]]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            query = "SELECT * FROM payment_orders WHERE 1=1"
            params = []

            if user_id:
                query += f" AND user_id = {self._p}"
                params.append(user_id)
            if status:
                query += f" AND status = {self._p}"
                params.append(status)

            query += f" ORDER BY created_at DESC LIMIT {self._p}"
            params.append(limit)

            cursor.execute(query, tuple(params))
            return [dict(row) for row in cursor.fetchall()]
        finally:
            DatabaseConfig.return_connection(conn)

    def get_analysis_history(self, user_id: int, limit: int = 50) -> List[Dict[str, Any]]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                SELECT * FROM analysis_history
                WHERE user_id = {self._p}
                ORDER BY created_at DESC
                LIMIT {self._p}
            """, (user_id, limit))
            return [dict(row) for row in cursor.fetchall()]
        finally:
            DatabaseConfig.return_connection(conn)

    def get_packages(self) -> Dict[str, Any]:
        return {
            "packages": CREDIT_PACKAGES,
            "tier_limits": TIER_LIMITS,
            "analysis_cost": ANALYSIS_CREDIT_COST
        }


_payment_service = None

def get_payment_service() -> PaymentService:
    global _payment_service
    if _payment_service is None:
        _payment_service = PaymentService()
    return _payment_service
