# -*- coding: utf-8 -*-
"""
YERIMEBAK AI v8.1 - Payment Service
Kredi yukleme, odeme takibi ve hesap yonetimi
"""
import os
import uuid
import logging
import json
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from typing import Dict, Any, Optional, List

from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)

# 🔒 GÜVENLİK: Sabit değerler .env'den alinir
# Arac degerleme kredi paketleri (fiyatlar KDV dahil). CREDIT_PACKAGES ortam
# degiskeniyle (ayni JSON yapisi) kod degismeden ezilebilir.
CREDIT_PACKAGES = json.loads(os.getenv("CREDIT_PACKAGES", json.dumps({
    "paket3": {"credits": 3, "price": 100, "name": "3 Analiz", "popular": False},
    "paket5": {"credits": 5, "price": 250, "name": "5 Analiz", "popular": False},
    "paket10": {"credits": 10, "price": 400, "name": "10 Analiz", "popular": True},
    "paket11": {"credits": 11, "price": 750, "name": "11 Analiz", "popular": False},
})))

FREE_CREDITS_ON_REGISTER = int(os.getenv("FREE_CREDITS_ON_REGISTER", "3"))

TIER_LIMITS = json.loads(os.getenv("TIER_LIMITS", json.dumps({
    "free": {"monthly_credits": 0, "max_analyses_per_day": 5},
    "starter": {"monthly_credits": 25, "max_analyses_per_day": 20},
    "basic": {"monthly_credits": 50, "max_analyses_per_day": 50},
    "pro": {"monthly_credits": 150, "max_analyses_per_day": 200},
    "enterprise": {"monthly_credits": 500, "max_analyses_per_day": -1},
})))

ANALYSIS_CREDIT_COST = int(os.getenv("ANALYSIS_CREDIT_COST", "1"))


def credit_refusal(reason, credits=None):
    """Kredi / gunluk sinir reddi -> (http_status, code, mesaj). Iki degerleme akisi da kullanir."""
    if reason == "daily_limit":
        return 429, "daily_limit", "Günlük analiz sınırınıza ulaştınız. Yarın tekrar deneyebilir veya paketinizi yükseltebilirsiniz."
    mevcut = f" Mevcut krediniz: {credits}." if credits is not None else ""
    return 402, "insufficient_credits", "Yetersiz kredi. Analiz için kredi paketi satın alın." + mevcut


class PaymentService:
    def __init__(self):
        self._db_type = DatabaseConfig._get_db_type()

    @property
    def _p(self):
        return "%s"

    @staticmethod
    def _day_bounds(now=None):
        local = (now or datetime.now(timezone.utc)).astimezone(ZoneInfo("Europe/Istanbul"))
        start = local.replace(hour=0, minute=0, second=0, microsecond=0)
        # analysis_history.created_at: UTC, TIMESTAMP WITHOUT TIME ZONE.
        return tuple(d.astimezone(timezone.utc).replace(tzinfo=None)
                     for d in (start, start + timedelta(days=1)))

    @staticmethod
    def _limits(user):
        return TIER_LIMITS.get(user.get("tier"), TIER_LIMITS["free"])

    def _grant_monthly(self, cursor, user):
        """Çağıran users satırını FOR UPDATE ile kilitlemiş olmalı.

        Kullanıcı/ay anahtarı seviye değişimlerinde de ikinci yüklemeyi engeller.
        Bakiye ve hareket aynı transaction içinde kalır.
        """
        amount = int(self._limits(user)["monthly_credits"])
        if amount <= 0:
            return
        month = datetime.now(ZoneInfo("Europe/Istanbul")).strftime("%Y-%m")
        action = f"monthly_credit:{month}"
        cursor.execute("SELECT 1 FROM credit_usage_logs WHERE user_id=%s AND action=%s LIMIT 1",
                       (user['id'], action))
        if cursor.fetchone():
            return
        cursor.execute("UPDATE users SET credits=credits+%s WHERE id=%s", (amount, user['id']))
        cursor.execute("""INSERT INTO credit_usage_logs (user_id, action, credits_used, description)
                          VALUES (%s, %s, %s, %s)""",
                       (user['id'], action, -amount, f"Aylık seviye kredisi ({user['tier']}, {month})"))
        user['credits'] += amount

    def _locked_user(self, cursor, user_id):
        cursor.execute("SELECT * FROM users WHERE id=%s FOR UPDATE", (user_id,))
        row = cursor.fetchone()
        user = dict(row) if row else None
        if user:
            self._grant_monthly(cursor, user)
        return user

    def _analysis_policy(self, user, daily_count, amount):
        limit = int(self._limits(user)['max_analyses_per_day'])
        if limit != -1 and daily_count >= limit:
            return {'ok': False, 'reason': 'daily_limit', 'message': 'Günlük analiz sınırına ulaşıldı'}
        if user['credits'] < amount:
            return {'ok': False, 'reason': 'insufficient_credits', 'message': 'Yetersiz kredi'}
        return {'ok': True, 'reason': None, 'message': 'Analiz yapılabilir'}

    def _allowed(self, cursor, user, amount, now=None):
        if not user:
            return {'ok': False, 'reason': 'user_not_found', 'message': 'Kullanıcı bulunamadı'}
        cursor.execute("""SELECT COUNT(*) AS count FROM analysis_history
                          WHERE user_id=%s AND created_at >= %s AND created_at < %s""",
                       (user['id'], *self._day_bounds(now)))
        return self._analysis_policy(user, cursor.fetchone()['count'], amount)

    def analysis_allowed(self, user_id: int) -> Dict[str, Any]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            user = self._locked_user(cursor, user_id)
            result = self._allowed(cursor, user, ANALYSIS_CREDIT_COST)
            conn.commit()
            return result
        finally:
            DatabaseConfig.return_connection(conn)

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
        conn = DatabaseConfig.get_connection()
        try:
            user = self._locked_user(conn.cursor(), user_id)
            conn.commit()
        finally:
            DatabaseConfig.return_connection(conn)
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
        if type(amount) is not int or amount <= 0:
            return {"success": False, "error": "Kredi miktarı pozitif tam sayı olmalıdır"}
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            user = self._locked_user(cursor, user_id)
            # Kilit bekleyişi gece yarısını geçebilir; sayım ve kayıt aynı anı kullanır.
            now = datetime.now(timezone.utc)
            allowed = self._allowed(cursor, user, amount, now)
            if not allowed['ok']:
                conn.commit()  # Aylık hak analiz reddedilse de kalıcıdır.
                return {"success": False, "error": allowed['message'], "code": allowed['reason'],
                        "credits": user['credits'] if user else 0, "required": amount}
            new_credits = user['credits'] - amount
            cursor.execute("UPDATE users SET credits=%s WHERE id=%s", (new_credits, user_id))

            history_id = str(uuid.uuid4())
            vehicle_json = vehicle_data or {"description": description}
            valuation_json = valuation_data or {"credits_deducted": amount}

            cursor.execute(f"""
                INSERT INTO analysis_history (id, user_id, vehicle_json, valuation_json, created_at)
                VALUES ({self._p}, {self._p}, {self._p}, {self._p}, {self._p})
            """, (
                history_id,
                user_id,
                json.dumps(vehicle_json, ensure_ascii=False, default=str),
                json.dumps(valuation_json, ensure_ascii=False, default=str),
                now.replace(tzinfo=None),
            ))

            cursor.execute(f"""
                    INSERT INTO credit_usage_logs (user_id, action, credits_used, description)
                    VALUES ({self._p}, {self._p}, {self._p}, {self._p})
                """, (user_id, "analysis", amount, description))

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
        return self.analysis_allowed(user_id)['ok']

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
