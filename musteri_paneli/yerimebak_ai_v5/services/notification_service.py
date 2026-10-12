# -*- coding: utf-8 -*-
"""
Uygulama ici bildirimler (musteri, personel, admin).

- audience='user'  : tek bir kullaniciya (users.id) gider.
- audience='admin' : tum adminlerin ortak bildirim kutusu.
Bildirimler cagiran fonksiyonun transaction'i icinde yazilir; is adimi commit
edilmezse bildirim de olusmaz. Paneller listeyi periyodik olarak ceker.
"""
import logging
import os
from typing import Any, Dict, Iterable, List, Optional

from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)

MAX_LIST = 100


def ensure_schema(cursor: Any) -> None:
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS notifications (
            id BIGSERIAL PRIMARY KEY,
            audience TEXT NOT NULL DEFAULT 'user',
            user_id TEXT,
            kind TEXT NOT NULL,
            title TEXT NOT NULL,
            body TEXT NOT NULL DEFAULT '',
            report_id TEXT,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            read_at TIMESTAMPTZ
        )
        """
    )
    cursor.execute(
        "CREATE INDEX IF NOT EXISTS idx_notifications_target ON notifications(audience, user_id, created_at DESC)"
    )


# Uygulama ici bildirime ek olarak e-posta da gonderilen turler
EMAIL_KINDS = {
    # musteri
    "expert_assigned", "task_depart", "task_arrive", "task_corporate", "report_ready",
    "request_cancelled",
    # personel
    "task_assigned", "task_unassigned", "report_rejected", "report_approved",
}
PERSONNEL_ROLES = ("personel", "field_staff", "staff", "personnel")


def _admin_site_url() -> str:
    return os.getenv("ADMIN_SITE_URL", "https://admin.yerimebak.com.tr")


def _email_copy(cursor: Any, user_id: Any, kind: str, title: str, body: str) -> None:
    from yerimebak_ai_v5.services import email_service

    if not email_service.is_configured():
        return
    try:
        cursor.execute("SELECT email, role FROM users WHERE id::text = %s", (str(user_id),))
        row = cursor.fetchone()
    except Exception as exc:  # pragma: no cover - bildirim islemi bozulmasin
        logger.warning("Bildirim e-postasi icin kullanici okunamadi: %s", exc)
        return
    if not row:
        return
    row = dict(row)
    if str(row.get("role") or "").lower() in PERSONNEL_ROLES:
        button = ("Personel paneline git", _admin_site_url())
    else:
        button = ("Panelimi aç", email_service.site_url("/panel"))
    email_service.send(row.get("email"), f"YerimeBak - {title}", title, [body] if body else [], button)


def notify_user(cursor: Any, user_id: Any, kind: str, title: str, body: str = "", report_id: Optional[str] = None) -> None:
    if user_id in (None, ""):
        return
    cursor.execute(
        "INSERT INTO notifications (audience, user_id, kind, title, body, report_id) VALUES ('user', %s, %s, %s, %s, %s)",
        (str(user_id), kind, title[:200], (body or "")[:1000], report_id),
    )
    if kind in EMAIL_KINDS:
        _email_copy(cursor, user_id, kind, title, body)


# Admine e-posta ile de bildirilen turler (ADMIN_NOTIFY_EMAIL tanimliysa)
ADMIN_EMAIL_KINDS = {"request_paid", "report_submitted"}


def notify_admins(cursor: Any, kind: str, title: str, body: str = "", report_id: Optional[str] = None) -> None:
    cursor.execute(
        "INSERT INTO notifications (audience, user_id, kind, title, body, report_id) VALUES ('admin', NULL, %s, %s, %s, %s)",
        (kind, title[:200], (body or "")[:1000], report_id),
    )
    admin_email = os.getenv("ADMIN_NOTIFY_EMAIL")
    if admin_email and kind in ADMIN_EMAIL_KINDS:
        from yerimebak_ai_v5.services import email_service

        for address in [a.strip() for a in admin_email.split(",") if a.strip()]:
            email_service.send(address, f"YerimeBak Admin - {title}", title, [body] if body else [],
                               ("Admin paneline git", _admin_site_url()))


def customer_user_id(cursor: Any, data: Dict[str, Any]) -> Optional[str]:
    """Rapor verisinden musterinin users.id degeri (talep kaydindan)."""
    request_id = data.get("expertiz_request_id")
    if not request_id:
        return None
    cursor.execute("SELECT user_id FROM expertiz_requests WHERE id = %s", (str(request_id),))
    row = cursor.fetchone()
    value = dict(row).get("user_id") if row else None
    return str(value) if value not in (None, "") else None


def _target_clause(user: Dict[str, Any], admin: bool) -> tuple:
    # admin=True yalnizca get_admin_user ile dogrulanmis endpoint'lerden gelir
    if admin:
        return "(audience = 'admin' OR (audience = 'user' AND user_id = %s))", (str(user.get("id") or ""),)
    return "(audience = 'user' AND user_id = %s)", (str(user.get("id") or ""),)


def _public(row: Dict[str, Any]) -> Dict[str, Any]:
    out = dict(row)
    for key in ("created_at", "read_at"):
        if hasattr(out.get(key), "isoformat"):
            out[key] = out[key].isoformat()
    out["read"] = out.get("read_at") is not None
    out.pop("user_id", None)
    return out


def list_notifications(user: Dict[str, Any], limit: int = 30, unread_only: bool = False, admin: bool = False) -> Dict[str, Any]:
    from yerimebak_ai_v5.services import dispatch_service

    dispatch_service.ensure_workflow_schema_once()
    clause, params = _target_clause(user, admin)
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            f"""
            SELECT id, audience, user_id, kind, title, body, report_id, created_at, read_at
            FROM notifications
            WHERE {clause} {"AND read_at IS NULL" if unread_only else ""}
            ORDER BY created_at DESC, id DESC
            LIMIT %s
            """,
            params + (max(1, min(int(limit or 30), MAX_LIST)),),
        )
        items = [_public(dict(row)) for row in cursor.fetchall()]
        cursor.execute(f"SELECT COUNT(*) AS n FROM notifications WHERE {clause} AND read_at IS NULL", params)
        unread = int(dict(cursor.fetchone())["n"])
        return {"success": True, "unread": unread, "notifications": items}
    finally:
        DatabaseConfig.return_connection(conn)


def mark_read(user: Dict[str, Any], ids: Optional[Iterable[Any]] = None, admin: bool = False) -> Dict[str, Any]:
    """ids verilmezse kullanicinin tum okunmamis bildirimleri okundu olur."""
    from yerimebak_ai_v5.services import dispatch_service

    dispatch_service.ensure_workflow_schema_once()
    clause, params = _target_clause(user, admin)
    id_list: List[int] = []
    for value in ids or []:
        try:
            id_list.append(int(value))
        except (TypeError, ValueError):
            continue
    if ids is not None and not id_list:
        return {"success": True, "updated": 0}
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        extra = " AND id = ANY(%s)" if id_list else ""
        cursor.execute(
            f"UPDATE notifications SET read_at = NOW() WHERE {clause} AND read_at IS NULL{extra}",
            params + ((id_list,) if id_list else ()),
        )
        updated = cursor.rowcount
        conn.commit()
        return {"success": True, "updated": updated}
    finally:
        DatabaseConfig.return_connection(conn)
