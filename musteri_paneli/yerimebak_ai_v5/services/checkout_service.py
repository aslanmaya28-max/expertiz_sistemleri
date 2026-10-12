# -*- coding: utf-8 -*-
"""
Odeme akislari (PayTR):
  * Kredi paketi satin alma  -> odeme onaylaninca krediler aninda hesaba yuklenir.
  * Ekspertiz talebi         -> hizmet bedeli + kurumsal paket (+ KDV) odenince talep
                                olusur ve admin/personel kuyruguna duser.

PayTR ayni bildirimi birden fazla gonderebilir; tamamlama islemleri
"WHERE ... status = 'pending'" kosuluyla atomiktir, kredi iki kez yuklenmez.
"""
import json
import logging
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.services import paytr_service, pricing_service

logger = logging.getLogger(__name__)

CREDIT_PREFIX = "CR"
EXPERTIZ_PREFIX = "EX"

_schema_ready = False


def _error(message: str, status: int = 400) -> Dict[str, Any]:
    return {"error": message, "http_status": status}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _new_oid(prefix: str) -> str:
    # PayTR merchant_oid: sadece harf/rakam, benzersiz
    return f"{prefix}{uuid.uuid4().hex.upper()}"


def ensure_schema() -> None:
    global _schema_ready
    if _schema_ready:
        return
    from yerimebak_ai_v5.services.expertiz_service import _ensure_expertiz_requests_schema

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_expertiz_requests_schema(cursor)
        cursor.execute("ALTER TABLE payment_orders ADD COLUMN IF NOT EXISTS paytr_oid TEXT")
        cursor.execute("ALTER TABLE payment_orders ADD COLUMN IF NOT EXISTS failed_reason TEXT")
        cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_orders_paytr_oid ON payment_orders(paytr_oid)")
        cursor.execute("ALTER TABLE expertiz_requests ADD COLUMN IF NOT EXISTS paytr_oid TEXT")
        cursor.execute("ALTER TABLE expertiz_requests ADD COLUMN IF NOT EXISTS paid_at TEXT")
        cursor.execute("ALTER TABLE expertiz_requests ADD COLUMN IF NOT EXISTS failed_reason TEXT")
        cursor.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_expertiz_requests_paytr_oid ON expertiz_requests(paytr_oid)")
        conn.commit()
        _schema_ready = True
    finally:
        DatabaseConfig.return_connection(conn)


def _start_payment(oid: str, user: Dict[str, Any], amount_tl: float, basket, user_ip: str) -> Dict[str, Any]:
    try:
        return paytr_service.create_payment(
            merchant_oid=oid,
            email=str(user.get("email") or ""),
            amount_tl=amount_tl,
            basket=basket,
            user_ip=user_ip,
            user_name=str(user.get("full_name") or user.get("email") or ""),
            user_phone=str(user.get("phone") or ""),
        )
    except paytr_service.PaytrError as exc:
        return _error(str(exc), 503)


# ---------------------------------------------------------------------------
# Kredi paketi
# ---------------------------------------------------------------------------

def start_credit_purchase(user: Dict[str, Any], package_key: str, user_ip: str) -> Dict[str, Any]:
    from yerimebak_ai_v5.services.payment_service import CREDIT_PACKAGES

    ensure_schema()
    pkg = CREDIT_PACKAGES.get(package_key)
    if not pkg:
        return _error(f"Gecersiz paket. Gecerli paketler: {', '.join(CREDIT_PACKAGES)}")
    if not user.get("email"):
        return _error("Odeme icin hesabinizda e-posta adresi olmali")

    oid = _new_oid(CREDIT_PREFIX)
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            INSERT INTO payment_orders (id, user_id, user_email, user_phone, package_key, package_name,
                                        credits, amount_tl, status, payment_method, paytr_oid)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'pending', %s, %s)
            """,
            (oid, user["id"], user.get("email"), user.get("phone"), package_key, pkg["name"],
             pkg["credits"], pkg["price"], paytr_service.provider_status()["provider"], oid),
        )
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)

    payment = _start_payment(
        oid, user, float(pkg["price"]),
        [paytr_service.basket_line(f"YerimeBak {pkg['name']} ({pkg['credits']} analiz)", float(pkg["price"]))],
        user_ip,
    )
    if "error" in payment:
        _mark_failed(oid, payment["error"])
        return payment
    return {"success": True, "order_id": oid, "kind": "credits", "amount_tl": float(pkg["price"]),
            "credits": pkg["credits"], **payment}


def _fulfill_credit(cursor: Any, oid: str, total_kurus: Optional[int]) -> Dict[str, Any]:
    cursor.execute(
        """
        UPDATE payment_orders
        SET status = 'approved', approved_by = 'paytr', approved_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
        WHERE paytr_oid = %s AND status = 'pending'
          AND (%s IS NULL OR %s >= ROUND(amount_tl * 100))
        RETURNING user_id, credits, amount_tl
        """,
        (oid, total_kurus, total_kurus),
    )
    row = cursor.fetchone()
    if not row:
        return {"fulfilled": False}
    row = dict(row)
    cursor.execute("UPDATE users SET credits = credits + %s WHERE id = %s RETURNING credits", (row["credits"], row["user_id"]))
    balance = dict(cursor.fetchone())["credits"]
    cursor.execute(
        "INSERT INTO credit_usage_logs (user_id, action, credits_used, description) VALUES (%s, %s, %s, %s)",
        (row["user_id"], "credit_purchase", int(row["credits"]), f"PayTR {oid}: {row['credits']} kredi yuklendi"),
    )
    return {"fulfilled": True, "credits_added": int(row["credits"]), "new_balance": int(balance)}


# ---------------------------------------------------------------------------
# Ekspertiz talebi
# ---------------------------------------------------------------------------

VEHICLE_FIELDS = ("brand", "model", "year", "km", "price", "fuel", "transmission")


def _clean_vehicle(raw: Any) -> Dict[str, Any]:
    raw = raw if isinstance(raw, dict) else {}
    vehicle: Dict[str, Any] = {}
    for key in VEHICLE_FIELDS:
        value = raw.get(key)
        if value in (None, ""):
            continue
        if key in ("year", "km", "price"):
            try:
                value = int(float(value))
            except (TypeError, ValueError):
                continue
        else:
            value = str(value).strip()[:60]
        vehicle[key] = value
    return vehicle


def quote_expertiz(firm_id: str, package_id: str) -> Dict[str, Any]:
    selected = pricing_service.find_package(firm_id, package_id)
    if not selected:
        return _error("Gecersiz veya artik sunulmayan ekspertiz firma/paket secimi")
    fee = pricing_service.get_service_fee_tl()
    package_price = float(selected["package"]["price"])
    subtotal = fee + package_price
    vat = round(subtotal * pricing_service.VAT_RATE, 2)
    totals = {
        "service_fee_tl": fee,
        "package_price_tl": package_price,
        "vat_tl": vat,
        "total_tl": round(subtotal + vat, 2),
    }
    return {"success": True, "selected": selected, "totals": totals}


def start_expertiz_checkout(payload: Dict[str, Any], user: Dict[str, Any], user_ip: str) -> Dict[str, Any]:
    from yerimebak_ai_v5.services.expertiz_service import _ensure_expertiz_requests_schema

    ensure_schema()
    vehicle = _clean_vehicle(payload.get("vehicle"))
    if not payload.get("listing_id") and not payload.get("listing_url") and not (vehicle.get("brand") and vehicle.get("model")):
        return _error("Arac icin ilan linki paylasin veya marka/model bilgilerini girin")
    if not user.get("email"):
        return _error("Odeme icin hesabinizda e-posta adresi olmali")

    quote = quote_expertiz(str(payload.get("firm_id") or ""), str(payload.get("package_id") or ""))
    if "error" in quote:
        return quote
    selected, totals = quote["selected"], quote["totals"]

    request_id = str(uuid.uuid4())
    oid = _new_oid(EXPERTIZ_PREFIX)
    now = _now()
    clean_payload = {
        "firm_id": selected["firm"]["id"],
        "package_id": selected["package"]["id"],
        "listing_id": payload.get("listing_id"),
        "listing_url": (payload.get("listing_url") or "").strip()[:500],
        "plate": (payload.get("plate") or "").strip()[:20],
        "city": (payload.get("city") or "").strip()[:80],
        "note": (payload.get("note") or "").strip()[:1000],
        "vehicle": vehicle,
    }
    snapshot = {
        "payload": clean_payload,
        "selected": selected,
        "totals": totals,
        "user": {k: user.get(k) for k in ("id", "email", "full_name", "phone")},
    }

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_expertiz_requests_schema(cursor)
        cursor.execute(
            """
            INSERT INTO expertiz_requests (
                id, user_id, user_email, listing_id, listing_url, plate, city,
                firm_id, firm_name, package_id, package_name, service_fee_tl,
                package_price_tl, vat_tl, total_tl, status, payment_status,
                data, created_at, updated_at, paytr_oid
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'OdemeBekliyor', 'pending', %s, %s, %s, %s)
            """,
            (
                request_id, str(user.get("id", "")), user.get("email", ""),
                str(clean_payload["listing_id"] or ""), clean_payload["listing_url"], clean_payload["plate"],
                clean_payload["city"], selected["firm"]["id"], selected["firm"]["name"],
                selected["package"]["id"], selected["package"]["name"], totals["service_fee_tl"],
                totals["package_price_tl"], totals["vat_tl"], totals["total_tl"],
                json.dumps(snapshot, ensure_ascii=False, default=str), now, now, oid,
            ),
        )
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)

    payment = _start_payment(
        oid, user, totals["total_tl"],
        [
            paytr_service.basket_line("YerimeBak Hizmet Bedeli", totals["service_fee_tl"]),
            paytr_service.basket_line(f"{selected['firm']['name']} - {selected['package']['name']}", totals["package_price_tl"]),
            paytr_service.basket_line("KDV", totals["vat_tl"]),
        ],
        user_ip,
    )
    if "error" in payment:
        _mark_failed(oid, payment["error"])
        return payment
    return {"success": True, "order_id": oid, "request_id": request_id, "kind": "expertiz",
            "amount_tl": totals["total_tl"], "totals": totals,
            "firm": selected["firm"], "package": selected["package"], **payment}


def _fulfill_expertiz(cursor: Any, oid: str, total_kurus: Optional[int]) -> Dict[str, Any]:
    from yerimebak_ai_v5.services.expertiz_service import _upsert_report_from_request

    now = _now()
    cursor.execute(
        """
        UPDATE expertiz_requests
        SET payment_status = 'paid', status = 'Islemde', paid_at = %s, updated_at = %s
        WHERE paytr_oid = %s AND payment_status = 'pending'
          AND (%s IS NULL OR %s >= ROUND(total_tl * 100))
        RETURNING id, data
        """,
        (now, now, oid, total_kurus, total_kurus),
    )
    row = cursor.fetchone()
    if not row:
        return {"fulfilled": False}
    row = dict(row)
    snapshot = json.loads(row["data"]) if isinstance(row["data"], str) else (row["data"] or {})
    _upsert_report_from_request(
        cursor=cursor,
        request_id=row["id"],
        payload=snapshot["payload"],
        user=snapshot["user"],
        selected=snapshot["selected"],
        totals=snapshot["totals"],
        now=now,
        payment_status="paid",
    )
    return {"fulfilled": True, "request_id": row["id"]}


# ---------------------------------------------------------------------------
# Tamamlama / bildirim
# ---------------------------------------------------------------------------

def _mark_failed(oid: str, reason: str) -> None:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        if oid.startswith(CREDIT_PREFIX):
            cursor.execute(
                "UPDATE payment_orders SET status = 'failed', failed_reason = %s, updated_at = CURRENT_TIMESTAMP WHERE paytr_oid = %s AND status = 'pending'",
                (reason[:300], oid),
            )
        elif oid.startswith(EXPERTIZ_PREFIX):
            cursor.execute(
                "UPDATE expertiz_requests SET payment_status = 'failed', failed_reason = %s, updated_at = %s WHERE paytr_oid = %s AND payment_status = 'pending'",
                (reason[:300], _now(), oid),
            )
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)


def complete_payment(oid: str, success: bool, total_kurus: Optional[int] = None, reason: str = "") -> Dict[str, Any]:
    """Odeme sonucunu isler; ayni bildirim tekrar gelirse etkisizdir."""
    ensure_schema()
    if not success:
        _mark_failed(oid, reason or "Odeme basarisiz")
        return {"fulfilled": False, "failed": True}
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        if oid.startswith(CREDIT_PREFIX):
            result = _fulfill_credit(cursor, oid, total_kurus)
        elif oid.startswith(EXPERTIZ_PREFIX):
            result = _fulfill_expertiz(cursor, oid, total_kurus)
        else:
            return {"fulfilled": False, "unknown": True}
        conn.commit()
        if result.get("fulfilled"):
            logger.info("[CHECKOUT] Odeme tamamlandi: %s %s", oid, result)
        return result
    except Exception:
        conn.rollback()
        raise
    finally:
        DatabaseConfig.return_connection(conn)


def handle_paytr_callback(form: Dict[str, Any]) -> bool:
    """PayTR bildirimi. Imza gecersizse False (istek reddedilir)."""
    if not paytr_service.verify_callback(form):
        logger.warning("[PAYTR] Gecersiz imzali bildirim: oid=%s", form.get("merchant_oid"))
        return False
    oid = str(form.get("merchant_oid") or "")
    status = str(form.get("status") or "")
    try:
        total_kurus = int(str(form.get("total_amount") or "0"))
    except ValueError:
        total_kurus = 0
    complete_payment(
        oid,
        success=status == "success",
        total_kurus=total_kurus,
        reason=f"{form.get('failed_reason_code') or ''} {form.get('failed_reason_msg') or ''}".strip(),
    )
    return True


def simulate_payment(oid: str, user: Dict[str, Any], success: bool = True) -> Dict[str, Any]:
    """Sadece PAYMENT_SIMULATION=true iken: musteri kendi siparisini 'oder'."""
    if not paytr_service.simulation_enabled():
        return _error("Odeme simulasyonu kapali", 403)
    status = get_order_status(oid, user)
    if "error" in status:
        return status
    complete_payment(oid, success=success, total_kurus=None, reason="Simulasyon")
    return get_order_status(oid, user)


def get_order_status(oid: str, user: Dict[str, Any]) -> Dict[str, Any]:
    ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        if oid.startswith(CREDIT_PREFIX):
            cursor.execute("SELECT * FROM payment_orders WHERE paytr_oid = %s AND user_id = %s", (oid, user.get("id")))
            row = cursor.fetchone()
            if not row:
                return _error("Siparis bulunamadi", 404)
            row = dict(row)
            cursor.execute("SELECT credits FROM users WHERE id = %s", (user.get("id"),))
            balance = cursor.fetchone()
            state = {"approved": "paid", "pending": "pending"}.get(row["status"], "failed")
            return {"success": True, "order_id": oid, "kind": "credits", "status": state,
                    "credits": row["credits"], "amount_tl": float(row["amount_tl"]),
                    "credit_balance": dict(balance)["credits"] if balance else None,
                    "failed_reason": row.get("failed_reason")}
        if oid.startswith(EXPERTIZ_PREFIX):
            cursor.execute("SELECT * FROM expertiz_requests WHERE paytr_oid = %s AND user_id = %s", (oid, str(user.get("id"))))
            row = cursor.fetchone()
            if not row:
                return _error("Siparis bulunamadi", 404)
            row = dict(row)
            state = {"paid": "paid", "pending": "pending"}.get(row["payment_status"], "failed")
            return {"success": True, "order_id": oid, "kind": "expertiz", "status": state,
                    "request_id": row["id"], "amount_tl": float(row["total_tl"] or 0),
                    "firm_name": row.get("firm_name"), "package_name": row.get("package_name"),
                    "failed_reason": row.get("failed_reason")}
        return _error("Siparis bulunamadi", 404)
    finally:
        DatabaseConfig.return_connection(conn)
