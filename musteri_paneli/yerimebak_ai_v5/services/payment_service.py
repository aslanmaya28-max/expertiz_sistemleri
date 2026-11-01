# -*- coding: utf-8 -*-
"""
YERIMEBAK AI v8.1 - Payment Service
Kredi yukleme, odeme takibi ve hesap yonetimi
"""
import os
import uuid
import logging
import json
from datetime import datetime, timezone
from typing import Dict, Any, Optional, List

from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)

# 🔒 GÜVENLİK: Sabit değerler .env'den alinir
# Arac degerleme kredi paketleri (fiyatlar KDV dahil). CREDIT_PACKAGES ortam
# degiskeniyle (ayni JSON yapisi) kod degismeden ezilebilir.
CREDIT_PACKAGES = json.loads(os.getenv("CREDIT_PACKAGES", json.dumps({
    "paket1": {"credits": 1, "price": 100, "name": "1 Kredi", "popular": False},
    "paket5": {"credits": 5, "price": 400, "name": "5 Kredi", "popular": True},
    "paket10": {"credits": 10, "price": 750, "name": "10 Kredi", "popular": False},
})))

FREE_CREDITS_ON_REGISTER = int(os.getenv("FREE_CREDITS_ON_REGISTER", "1"))

ANALYSIS_CREDIT_COST = int(os.getenv("ANALYSIS_CREDIT_COST", "1"))


def credit_refusal(reason, credits=None):
    """Kredi reddi -> (http_status, code, mesaj)."""
    mevcut = f" Mevcut krediniz: {credits}." if credits is not None else ""
    return 402, "insufficient_credits", "Yetersiz kredi. Analiz için kredi paketi satın alın." + mevcut


class PaymentService:
    def __init__(self):
        self._db_type = DatabaseConfig._get_db_type()

    @property
    def _p(self):
        return "%s"

    def _locked_user(self, cursor, user_id):
        cursor.execute("SELECT * FROM users WHERE id=%s FOR UPDATE", (user_id,))
        row = cursor.fetchone()
        return dict(row) if row else None

    @staticmethod
    def _allowed(user, amount):
        if not user:
            return {'ok': False, 'reason': 'insufficient_credits', 'message': 'Kullanıcı bulunamadı'}
        if user['credits'] < amount:
            return {'ok': False, 'reason': 'insufficient_credits', 'message': 'Yetersiz kredi'}
        return {'ok': True, 'reason': None, 'message': 'Analiz yapılabilir'}

    def analysis_allowed(self, user_id: int) -> Dict[str, Any]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            user = self._locked_user(cursor, user_id)
            result = self._allowed(user, ANALYSIS_CREDIT_COST)
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

            cursor.execute(f"""
                INSERT INTO users (email, phone, full_name, credits, role, is_active)
                VALUES ({self._p}, {self._p}, {self._p}, {self._p}, 'user', 1)
            """, (email, phone, full_name, FREE_CREDITS_ON_REGISTER))
            conn.commit()

            cursor.execute(f"SELECT * FROM users WHERE email = {self._p}", (email,))
            row = cursor.fetchone()
            return dict(row)
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
            "role": user['role'],
        }

    def deduct_credits(
        self,
        user_id: int,
        amount: int = ANALYSIS_CREDIT_COST,
        description: str = "Arac analizi",
        vehicle_data: Optional[Dict[str, Any]] = None,
        valuation_data: Optional[Dict[str, Any]] = None,
        report_data: Optional[Dict[str, Any]] = None,
        request_id: Optional[str] = None,
        engine_version: Optional[str] = None,
    ) -> Dict[str, Any]:
        if type(amount) is not int or amount <= 0:
            return {"success": False, "error": "Kredi miktarı pozitif tam sayı olmalıdır"}
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            user = self._locked_user(cursor, user_id)
            now = datetime.now(timezone.utc)
            allowed = self._allowed(user, amount)
            if not allowed['ok']:
                conn.commit()  # Satir kilidi birakilir; degisiklik yok.
                return {"success": False, "error": allowed['message'], "code": allowed['reason'],
                        "credits": user['credits'] if user else 0, "required": amount}
            new_credits = user['credits'] - amount
            cursor.execute("UPDATE users SET credits=%s WHERE id=%s", (new_credits, user_id))

            history_id = str(uuid.uuid4())
            vehicle_json = vehicle_data or {"description": description}
            valuation_json = valuation_data or {"credits_deducted": amount}

            report = None
            if report_data is not None:
                import secrets
                from copy import deepcopy
                report = deepcopy(report_data)
                alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
                while True:
                    code = 'YD-'+''.join(secrets.choice(alphabet) for _ in range(4))+'-'+''.join(secrets.choice(alphabet) for _ in range(4))
                    cursor.execute('SELECT 1 FROM analysis_history WHERE verification_code=%s', (code,))
                    if not cursor.fetchone():
                        break
                cursor.execute("SELECT nextval('valuation_report_number_seq') AS n")
                number = f'YD {now.year}-{int(cursor.fetchone()["n"]):06d}'
                report['rapor'] = {'id': history_id, 'report_no': number, 'verification_code': code,
                                   'created_at': now.isoformat(), 'engine_version': engine_version,
                                   'verification_url': 'https://www.yerimebak.com.tr/dogrula/'+code}
                report['kredi'] = {'dusulen': amount, 'kalan': new_credits}
                report['success'] = True

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

            if report is not None:
                from psycopg2.extras import Json
                cursor.execute('''UPDATE analysis_history SET report_json=%s,report_no=%s,
                                  verification_code=%s,request_id=%s,engine_version=%s WHERE id=%s''',
                               (Json(report), number, code, request_id, engine_version, history_id))

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
                "description": description,
                "report": report,
            }
        except Exception:
            conn.rollback()
            raise
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
            "analysis_cost": ANALYSIS_CREDIT_COST
        }


_payment_service = None

def get_payment_service() -> PaymentService:
    global _payment_service
    if _payment_service is None:
        _payment_service = PaymentService()
    return _payment_service
