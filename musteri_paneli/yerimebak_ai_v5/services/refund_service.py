# -*- coding: utf-8 -*-
"""
Iptal ve iade (admin).

- Ekspertiz talebi iptali: talep 'cancelled' olur, personel atamasi kalkar,
  odeme PayTR'den (tam tutar) iade edilir. Yayinlanmis (tamamlanmis) rapor
  iptal edilemez.
- Kredi paketi iadesi: yalnizca kullanilmamis krediler iade edilebilir; krediler
  bakiyeden dusulur, odeme PayTR'den iade edilir.
- PayTR iadeyi reddederse hicbir kayit degismez (once iade, sonra kayit).
- Musteriye uygulama ici + e-posta bildirimi gider.
"""
import json
import logging
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from psycopg2.extras import Json

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.services import notification_service, paytr_service

logger = logging.getLogger(__name__)

PAID_EXPERTIZ = ("paid", "paid_simulation")


def _error(message: str, status: int = 400) -> Dict[str, Any]:
    return {"error": message, "http_status": status}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load(value: Any) -> Dict[str, Any]:
    if isinstance(value, dict):
        return dict(value)
    try:
        loaded = json.loads(value or "{}")
        return loaded if isinstance(loaded, dict) else {}
    except Exception:
        return {}


def _actor(admin: Dict[str, Any]) -> str:
    return str(admin.get("email") or admin.get("id") or "admin")


def _audit(cursor: Any, action: str, entity_type: str, entity_id: str, admin: Dict[str, Any], meta: Dict[str, Any]) -> None:
    cursor.execute(
        """
        INSERT INTO audit_logs (user_email, user_name, action, entity_type, entity_id, metadata)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (_actor(admin), admin.get("full_name") or _actor(admin), action, entity_type, entity_id, Json(meta)),
    )


def _tl(value: float) -> str:
    return f"{value:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")


def _do_refund(oid: Optional[str], amount: float, payment_status: str) -> Dict[str, Any]:
    """Odemeyi iade eder. Simulasyonla odenmis kayitlarda ag cagrisi yapilmaz."""
    if amount <= 0:
        return {"status": "success", "skipped": True}
    if payment_status == "paid_simulation" or not oid:
        return {"status": "success", "simulated": True}
    try:
        return paytr_service.refund(oid, amount)
    except paytr_service.PaytrError as exc:
        return {"error": str(exc)}


# ---------------------------------------------------------------------------
# Ekspertiz talebi iptali
# ---------------------------------------------------------------------------

def cancel_expertiz_request(report_id: str, admin: Dict[str, Any], reason: str, refund: bool = True) -> Dict[str, Any]:
    reason = (reason or "").strip()
    if not reason:
        return _error("Iptal nedeni zorunludur")
    from yerimebak_ai_v5.services import dispatch_service

    dispatch_service.ensure_workflow_schema_once()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM reports WHERE id::text = %s FOR UPDATE", (str(report_id),))
        row = cursor.fetchone()
        if not row:
            return _error("Talep bulunamadi", 404)
        row = dict(row)
        status = row.get("status") or "draft"
        if status == "cancelled":
            return _error("Talep zaten iptal edilmis", 409)
        if status == "published":
            return _error("Musteriye gonderilmis rapor iptal edilemez", 409)
        data = _load(row.get("data"))
        request_id = str(data.get("expertiz_request_id") or row["id"])
        cursor.execute("SELECT * FROM expertiz_requests WHERE id = %s FOR UPDATE", (request_id,))
        req = cursor.fetchone()
        req = dict(req) if req else {}
        payment_status = str(req.get("payment_status") or row.get("payment_status") or "")
        amount = float(req.get("total_tl") or row.get("toplam_tutar") or 0)

        refunded = 0.0
        if refund and payment_status in PAID_EXPERTIZ:
            result = _do_refund(req.get("paytr_oid"), amount, payment_status)
            if "error" in result:
                conn.rollback()
                return _error(result["error"], 502)
            refunded = amount

        now = _now()
        personnel_id = data.get("assigned_personel_id") or (data.get("assignment") or {}).get("personnel_id")
        if personnel_id:
            data = dispatch_service._clear_assignment(data, admin, reason, "cancelled")
        data["cancellation"] = {"reason": reason, "by": _actor(admin), "at": now, "refunded_tl": refunded}
        cursor.execute(
            """
            UPDATE reports
            SET status = 'cancelled', durum = 'İptal Edildi', data = %s,
                payment_status = CASE WHEN %s > 0 THEN 'refunded' ELSE payment_status END,
                status_updated_at = NOW(), updated_at = NOW(), version_id = COALESCE(version_id, 0) + 1
            WHERE id = %s
            """,
            (Json(data), refunded, row["id"]),
        )
        if req:
            cursor.execute(
                """
                UPDATE expertiz_requests
                SET status = 'Iptal', updated_at = %s,
                    payment_status = CASE WHEN %s > 0 THEN 'refunded' ELSE payment_status END
                WHERE id = %s
                """,
                (now, refunded, request_id),
            )
        _audit(cursor, "REQUEST_CANCELLED", "expertiz_request", str(row["id"]), admin,
               {"reason": reason, "refunded_tl": refunded, "paytr_oid": req.get("paytr_oid")})

        body = f"İptal nedeni: {reason}."
        if refunded:
            body += f" {_tl(refunded)} TL ödemeniz kartınıza iade edildi; bankanıza göre hesabınıza yansıması birkaç iş günü sürebilir."
        notification_service.notify_user(
            cursor, req.get("user_id") or notification_service.customer_user_id(cursor, data),
            "request_cancelled", "Ekspertiz talebiniz iptal edildi", body, str(row["id"]),
        )
        if personnel_id:
            notification_service.notify_user(
                cursor, personnel_id, "task_unassigned", "Görev iptal edildi", f"Talep iptal edildi: {reason}", str(row["id"]),
            )
        conn.commit()
        return {"success": True, "report_id": str(row["id"]), "refunded_tl": refunded}
    except Exception:
        conn.rollback()
        raise
    finally:
        DatabaseConfig.return_connection(conn)


# ---------------------------------------------------------------------------
# Kredi paketi iadesi
# ---------------------------------------------------------------------------

def refund_credit_order(order_id: str, admin: Dict[str, Any], reason: str) -> Dict[str, Any]:
    reason = (reason or "").strip()
    if not reason:
        return _error("Iade nedeni zorunludur")
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM payment_orders WHERE id = %s OR paytr_oid = %s FOR UPDATE",
            (str(order_id), str(order_id)),
        )
        order = cursor.fetchone()
        if not order:
            return _error("Siparis bulunamadi", 404)
        order = dict(order)
        if order.get("status") == "refunded":
            return _error("Siparis zaten iade edilmis", 409)
        if order.get("status") != "approved":
            return _error("Sadece odemesi tamamlanmis siparis iade edilebilir", 409)
        credits = int(order.get("credits") or 0)
        cursor.execute("SELECT id, credits FROM users WHERE id = %s FOR UPDATE", (order["user_id"],))
        user = cursor.fetchone()
        balance = int(dict(user)["credits"] or 0) if user else 0
        if balance < credits:
            return _error(
                f"Paketteki kredilerin bir kismi kullanilmis (bakiye {balance}, paket {credits}); iade yapilamaz", 409
            )
        amount = float(order.get("amount_tl") or 0)
        result = _do_refund(order.get("paytr_oid"), amount, "paid" if order.get("paytr_oid") else "paid_simulation")
        if "error" in result:
            conn.rollback()
            return _error(result["error"], 502)

        cursor.execute("UPDATE users SET credits = credits - %s WHERE id = %s", (credits, order["user_id"]))
        cursor.execute(
            "UPDATE payment_orders SET status = 'refunded', admin_note = %s, updated_at = CURRENT_TIMESTAMP WHERE id = %s",
            (f"Iade: {reason}"[:500], order["id"]),
        )
        cursor.execute(
            "INSERT INTO credit_usage_logs (user_id, action, credits_used, description) VALUES (%s, %s, %s, %s)",
            (order["user_id"], "credit_refund", -credits, f"Iade {order.get('paytr_oid') or order['id']}: {reason}"[:500]),
        )
        _audit(cursor, "CREDIT_ORDER_REFUNDED", "payment_order", str(order["id"]), admin,
               {"reason": reason, "amount_tl": amount, "credits": credits})
        notification_service.notify_user(
            cursor, order["user_id"], "request_cancelled", "Kredi paketi iadesi",
            f"{credits} kredilik paketiniz iade edildi; {_tl(amount)} TL kartınıza iade edildi. Neden: {reason}",
        )
        conn.commit()
        return {"success": True, "order_id": str(order["id"]), "refunded_tl": amount, "credits_removed": credits}
    except Exception:
        conn.rollback()
        raise
    finally:
        DatabaseConfig.return_connection(conn)
