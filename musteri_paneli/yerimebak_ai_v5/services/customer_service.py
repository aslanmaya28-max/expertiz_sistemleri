# -*- coding: utf-8 -*-
"""
Admin musteri yonetimi.

Musteri: users tablosunda admin veya saha personeli olmayan hesap. Ekspertiz
talepleri expertiz_requests.user_id (users.id metin hali) ile eslesir.
"""
from typing import Any, Dict, Optional

from yerimebak_ai_v5.core.infrastructure.database_config import DatabaseConfig
from yerimebak_ai_v5.services.expertiz_service import _ensure_expertiz_requests_schema, _write_audit
from yerimebak_ai_v5.services.personnel_service import PERSONNEL_ROLES

NON_CUSTOMER_ROLES = ("admin",) + tuple(PERSONNEL_ROLES)
MAX_LIMIT = 500

_CUSTOMER_FILTER = "lower(coalesce(u.role, 'user')) NOT IN %s"


def _error(message: str, status: int) -> Dict[str, Any]:
    return {"error": message, "http_status": status}


def _public_customer(row: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "id": row.get("id"),
        "email": row.get("email"),
        "full_name": row.get("full_name") or "",
        "phone": row.get("phone") or "",
        "credits": int(row.get("credits") or 0),
        "tier": row.get("tier") or "free",
        "is_active": bool(row.get("is_active", 1)),
        "created_at": str(row["created_at"]) if row.get("created_at") else None,
        "last_login": str(row["last_login"]) if row.get("last_login") else None,
        "request_count": int(row.get("request_count") or 0),
        "total_spent_tl": round(float(row.get("total_spent_tl") or 0), 2),
        "last_request_at": row.get("last_request_at"),
    }


def list_customers(search: Optional[str] = None, limit: int = 200) -> Dict[str, Any]:
    limit = max(1, min(int(limit or 200), MAX_LIMIT))
    params: list = [NON_CUSTOMER_ROLES]
    where = _CUSTOMER_FILTER
    term = (search or "").strip()
    if term:
        where += " AND (u.email ILIKE %s OR u.full_name ILIKE %s OR u.phone ILIKE %s)"
        like = f"%{term}%"
        params += [like, like, like]

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_expertiz_requests_schema(cursor)
        cursor.execute(
            f"""
            SELECT u.id, u.email, u.full_name, u.phone, u.credits, u.tier, u.is_active,
                   u.created_at, u.last_login,
                   COUNT(q.id) FILTER (WHERE coalesce(q.status, '') <> 'Iptal') AS request_count,
                   COALESCE(SUM(q.total_tl) FILTER (WHERE coalesce(q.status, '') <> 'Iptal'), 0) AS total_spent_tl,
                   MAX(q.created_at) AS last_request_at
            FROM users u
            LEFT JOIN expertiz_requests q ON q.user_id = u.id::text
            WHERE {where}
            GROUP BY u.id
            ORDER BY u.created_at DESC NULLS LAST, u.id DESC
            LIMIT %s
            """,
            tuple(params + [limit]),
        )
        customers = [_public_customer(dict(row)) for row in cursor.fetchall()]
        conn.commit()
        return {
            "success": True,
            "customers": customers,
            "total": len(customers),
            "active": sum(1 for c in customers if c["is_active"]),
        }
    finally:
        DatabaseConfig.return_connection(conn)


def _get_customer(cursor: Any, customer_id: int) -> Optional[Dict[str, Any]]:
    cursor.execute(
        f"SELECT u.* FROM users u WHERE u.id = %s AND {_CUSTOMER_FILTER}",
        (customer_id, NON_CUSTOMER_ROLES),
    )
    row = cursor.fetchone()
    return dict(row) if row else None


def get_customer(customer_id: int) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        customer = _get_customer(cursor, customer_id)
        if not customer:
            return _error("Musteri bulunamadi", 404)
        _ensure_expertiz_requests_schema(cursor)
        cursor.execute(
            """
            SELECT q.id, q.plate, q.city, q.firm_name, q.package_name, q.total_tl,
                   q.status, q.payment_status, q.created_at, r.status AS report_status
            FROM expertiz_requests q
            LEFT JOIN reports r ON r.id::text = q.id
            WHERE q.user_id = %s
            ORDER BY q.created_at DESC
            """,
            (str(customer_id),),
        )
        requests = [dict(row) for row in cursor.fetchall()]
        conn.commit()
        active_requests = [r for r in requests if r.get("status") != "Iptal"]
        customer["request_count"] = len(active_requests)
        customer["total_spent_tl"] = sum(float(r.get("total_tl") or 0) for r in active_requests)
        customer["last_request_at"] = requests[0]["created_at"] if requests else None
        return {"success": True, "customer": _public_customer(customer), "requests": requests}
    finally:
        DatabaseConfig.return_connection(conn)


def set_customer_active(customer_id: int, active: bool, reason: str, admin: Dict[str, Any]) -> Dict[str, Any]:
    clean_reason = (reason or "").strip()
    if not active and not clean_reason:
        return _error("Pasife alma nedeni zorunludur", 400)

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        customer = _get_customer(cursor, customer_id)
        if not customer:
            return _error("Musteri bulunamadi", 404)
        cursor.execute("UPDATE users SET is_active = %s WHERE id = %s", (1 if active else 0, customer_id))
        _write_audit(
            cursor,
            "CUSTOMER_ACTIVATED" if active else "CUSTOMER_DEACTIVATED",
            "user",
            str(customer_id),
            admin,
            {"reason": clean_reason, "email": customer.get("email")},
        )
        conn.commit()
        customer["is_active"] = 1 if active else 0
        return {"success": True, "customer": _public_customer(customer)}
    finally:
        DatabaseConfig.return_connection(conn)
