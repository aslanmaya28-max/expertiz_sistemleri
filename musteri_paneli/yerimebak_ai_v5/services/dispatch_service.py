# -*- coding: utf-8 -*-
"""
Talep dagitim (dispatch) servisi.

Akis:
  1. Musteri talebi  -> reports (status='draft', atanmamis)   [expertiz_service]
  2. Admin kuyrugu   -> list_admin_requests(bucket='waiting_assignment')
  3. Admin atamasi   -> assign_request(report_id, personnel_id)
  4. Personel paneli -> list_personnel_tasks(user) / update_task_progress(accept|start)
  5. Personel raporu tamamlayinca status pending_ai/pending_admin olur (mevcut akis).

Atama bilgisi reports.data icinde tutulur:
  data.assigned_personel_id / data.assigned_personel_name  (eski Flutter kodu ile uyumlu)
  data.assignment = {status, personnel_id, personnel_name, assigned_at, ..., history[]}
"""
import json
import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from psycopg2.extras import Json

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.core import turkey_regions
from yerimebak_ai_v5.services import personnel_service
from yerimebak_ai_v5.services import expertiz_service
from yerimebak_ai_v5.services import media_service

logger = logging.getLogger(__name__)

PERSONNEL_ROLES = personnel_service.PERSONNEL_ROLES
ASSIGNABLE_STATUSES = ("draft", "rejected")
APPROVAL_STATUSES = ("pending_ai", "pending_admin")
BUCKETS = ("waiting_assignment", "in_progress", "pending_approval", "completed")

DURUM_BY_ASSIGNMENT = {
    "unassigned": "Beklemede",
    "assigned": "Personele Atandı",
    "accepted": "Personel Kabul Etti",
    "in_progress": "İncelemede",
    "submitted": "Rapor Gönderildi",
}

_schema_ready = False


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _error(message: str, status: int) -> Dict[str, Any]:
    return {"error": message, "http_status": status}


# ---------------------------------------------------------------------------
# Sema
# ---------------------------------------------------------------------------

def ensure_reports_table(cursor: Any) -> None:
    """reports / expertiz_requests tablolarinin var oldugunu garanti eder."""
    expertiz_service._create_reports_schema(cursor)
    expertiz_service._ensure_expertiz_requests_schema(cursor)


def ensure_workflow_schema(cursor: Any) -> None:
    personnel_service._ensure_personnel_schema(cursor)
    ensure_reports_table(cursor)
    media_service.ensure_media_schema(cursor)


def ensure_workflow_schema_once() -> bool:
    """Uygulama acilisinda bir kez calisir ve DDL'i commit eder."""
    global _schema_ready
    if _schema_ready:
        return True
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        ensure_workflow_schema(cursor)
        conn.commit()
        _schema_ready = True
        return True
    except Exception as exc:  # pragma: no cover - acilista loglanir
        conn.rollback()
        logger.error("Workflow sema hazirlama hatasi: %s", exc)
        return False
    finally:
        DatabaseConfig.return_connection(conn)


# ---------------------------------------------------------------------------
# Yardimcilar
# ---------------------------------------------------------------------------

def _load_data(value: Any) -> Dict[str, Any]:
    if isinstance(value, dict):
        return dict(value)
    if isinstance(value, str) and value:
        try:
            loaded = json.loads(value)
            return loaded if isinstance(loaded, dict) else {}
        except Exception:
            return {}
    return {}


def _iso(value: Any) -> Any:
    return value.isoformat() if hasattr(value, "isoformat") else value


def _assigned_id(data: Dict[str, Any]) -> str:
    assignment = data.get("assignment") if isinstance(data.get("assignment"), dict) else {}
    return str(data.get("assigned_personel_id") or assignment.get("personnel_id") or "").strip()


def _assignment_status(data: Dict[str, Any]) -> str:
    assignment = data.get("assignment") if isinstance(data.get("assignment"), dict) else {}
    if not _assigned_id(data):
        return "unassigned"
    return assignment.get("status") or "assigned"


def _bucket(status: Optional[str], data: Dict[str, Any]) -> str:
    status = (status or "draft").lower()
    if status == "published":
        return "completed"
    if status in APPROVAL_STATUSES:
        return "pending_approval"
    if _assigned_id(data):
        return "in_progress"
    return "waiting_assignment"


def _request_location(row: Dict[str, Any], data: Dict[str, Any]) -> Dict[str, Any]:
    talep = data.get("talep") if isinstance(data.get("talep"), dict) else {}
    vehicle = data.get("vehicle_snapshot") if isinstance(data.get("vehicle_snapshot"), dict) else {}
    raw_city = row.get("sehir") or talep.get("sehir") or vehicle.get("location") or ""
    location = turkey_regions.describe_city(raw_city)
    if not location["il_id"]:
        location["city"] = str(raw_city).strip()
    return location


def _admin_request(row: Dict[str, Any]) -> Dict[str, Any]:
    data = _load_data(row.get("data"))
    talep = data.get("talep") if isinstance(data.get("talep"), dict) else {}
    vehicle = data.get("vehicle_snapshot") if isinstance(data.get("vehicle_snapshot"), dict) else {}
    assignment = data.get("assignment") if isinstance(data.get("assignment"), dict) else {}
    location = _request_location(row, data)
    assigned_id = _assigned_id(data)
    status = row.get("status") or "draft"

    brand = vehicle.get("marka") or talep.get("aracMarka") or ""
    model = vehicle.get("model") or talep.get("aracModel") or ""
    title = vehicle.get("title") or " ".join(part for part in [brand, model] if part and part != "Belirtilmedi")

    return {
        "id": str(row.get("id")),
        "request_id": data.get("expertiz_request_id") or str(row.get("id")),
        "status": status,
        "durum": row.get("durum"),
        "bucket": _bucket(status, data),
        "needs_revision": status == "rejected",
        "rejection_reason": data.get("rejection_reason"),
        "created_at": _iso(row.get("created_at")),
        "updated_at": _iso(row.get("updated_at") or row.get("status_updated_at")),
        "customer": {
            "id": str(row.get("user_id") or row.get("customer_id") or ""),
            "name": data.get("customer_name") or talep.get("musteriAdi") or "Musteri",
            "phone": data.get("customer_phone") or talep.get("telefon") or "",
            "email": data.get("customer_email") or "",
        },
        "vehicle": {
            "plate": row.get("plaka") or vehicle.get("plaka") or talep.get("aracPlaka") or "",
            "brand": brand,
            "model": model,
            "year": vehicle.get("yil"),
            "km": vehicle.get("km"),
            "title": title or "Arac bilgisi yok",
            "listing_url": row.get("ilan_linki") or vehicle.get("listing_url") or "",
            "image_url": vehicle.get("image_url") or "",
        },
        "city": location["city"],
        "district": row.get("ilce") or "",
        "il_id": location["il_id"],
        "region_id": location["region_id"],
        "region": location["region"],
        "firm_name": row.get("ekspertiz_firmasi") or row.get("firma") or talep.get("expertizFirmasi") or "",
        "package_name": data.get("expertiz_paketi") or talep.get("expertizPaketi") or "",
        "total_tl": float(row.get("toplam_tutar") or talep.get("toplamTutar") or 0),
        "is_paid": bool(row.get("odendi_mi")),
        "payment_status": row.get("payment_status") or data.get("payment_status"),
        "note": data.get("note") or "",
        "assignment": {
            "status": _assignment_status(data),
            "personnel_id": assigned_id,
            "personnel_name": data.get("assigned_personel_name") or assignment.get("personnel_name") or "",
            "personnel_phone": assignment.get("personnel_phone") or "",
            "assigned_at": assignment.get("assigned_at"),
            "assigned_by": assignment.get("assigned_by"),
            "accepted_at": assignment.get("accepted_at"),
            "started_at": assignment.get("started_at"),
            "note": assignment.get("note") or "",
            "history": assignment.get("history") or [],
        }
        if assigned_id
        else {"status": "unassigned", "history": assignment.get("history") or []},
    }


def _write_audit(cursor: Any, action: str, report_id: str, actor: Dict[str, Any], metadata: Dict[str, Any]) -> None:
    cursor.execute(
        """
        INSERT INTO audit_logs (user_email, user_name, action, entity_type, entity_id, metadata)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (
            actor.get("email") or str(actor.get("id", "")),
            actor.get("full_name") or actor.get("email") or "system",
            action,
            "expertiz_request",
            report_id,
            Json(metadata),
        ),
    )


def _save_report_data(cursor: Any, row: Dict[str, Any], data: Dict[str, Any], durum: str) -> None:
    cursor.execute(
        """
        UPDATE reports
        SET data = %s,
            durum = %s,
            updated_at = NOW(),
            version_id = COALESCE(version_id, 0) + 1
        WHERE id = %s
        """,
        (Json(data), durum, row["id"]),
    )
    request_id = data.get("expertiz_request_id") or str(row["id"])
    cursor.execute(
        "UPDATE expertiz_requests SET status = %s, updated_at = %s WHERE id = %s",
        (durum, _now(), str(request_id)),
    )


def _lock_report(cursor: Any, report_id: str) -> Optional[Dict[str, Any]]:
    cursor.execute("SELECT * FROM reports WHERE id::text = %s FOR UPDATE", (str(report_id),))
    row = cursor.fetchone()
    return dict(row) if row else None


def _fetch_report(cursor: Any, report_id: str) -> Dict[str, Any]:
    cursor.execute("SELECT * FROM reports WHERE id::text = %s", (str(report_id),))
    return dict(cursor.fetchone())


def _actor_label(actor: Dict[str, Any]) -> str:
    return str(actor.get("email") or actor.get("full_name") or actor.get("id") or "system")


def _clear_assignment(data: Dict[str, Any], actor: Dict[str, Any], reason: str, action: str) -> Dict[str, Any]:
    assignment = data.get("assignment") if isinstance(data.get("assignment"), dict) else {}
    history = list(assignment.get("history") or [])
    history.append(
        {
            "action": action,
            "personnel_id": _assigned_id(data),
            "personnel_name": data.get("assigned_personel_name") or assignment.get("personnel_name") or "",
            "by": _actor_label(actor),
            "at": _now(),
            "note": reason,
        }
    )
    data["assignment"] = {"status": "unassigned", "history": history}
    data["assigned_personel_id"] = None
    data["assigned_personel_name"] = None
    if isinstance(data.get("talep"), dict):
        data["talep"]["atananPersonel"] = None
        data["talep"]["durum"] = DURUM_BY_ASSIGNMENT["unassigned"]
    return data


# ---------------------------------------------------------------------------
# Admin: talep kuyrugu
# ---------------------------------------------------------------------------

def list_admin_requests(
    bucket: Optional[str] = None,
    region_id: Optional[int] = None,
    il_id: Optional[int] = None,
    limit: int = 300,
) -> Dict[str, Any]:
    if bucket and bucket not in BUCKETS:
        return _error(f"Gecersiz bucket. Secenekler: {', '.join(BUCKETS)}", 400)
    ensure_workflow_schema_once()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM reports ORDER BY created_at DESC NULLS LAST LIMIT %s",
            (max(1, min(int(limit or 300), 1000)),),
        )
        requests = [_admin_request(dict(row)) for row in cursor.fetchall()]
    finally:
        DatabaseConfig.return_connection(conn)

    if region_id:
        requests = [r for r in requests if r["region_id"] == region_id]
    if il_id:
        requests = [r for r in requests if r["il_id"] == il_id]
    counts = {name: 0 for name in BUCKETS}
    for item in requests:
        counts[item["bucket"]] = counts.get(item["bucket"], 0) + 1
    if bucket:
        requests = [r for r in requests if r["bucket"] == bucket]
    return {"success": True, "counts": counts, "requests": requests}


def get_admin_request(report_id: str) -> Dict[str, Any]:
    ensure_workflow_schema_once()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM reports WHERE id::text = %s", (str(report_id),))
        row = cursor.fetchone()
        if not row:
            return _error("Talep bulunamadi", 404)
        return {"success": True, "request": _admin_request(dict(row))}
    finally:
        DatabaseConfig.return_connection(conn)


def _match_level(person: Dict[str, Any], request: Dict[str, Any]) -> str:
    if request["il_id"] and person["il_id"] == request["il_id"]:
        return "same_city"
    if request["region_id"] and person["region_id"] == request["region_id"]:
        return "same_region"
    return "other_region"


_MATCH_ORDER = {"same_city": 0, "same_region": 1, "other_region": 2}


def list_candidates(report_id: str) -> Dict[str, Any]:
    """Bir talep icin atanabilecek aktif personeller (once ayni il, sonra ayni bolge)."""
    detail = get_admin_request(report_id)
    if "error" in detail:
        return detail
    request = detail["request"]
    personnel = personnel_service.list_personnel(active=True)["personnel"]
    candidates = []
    for person in personnel:
        level = _match_level(person, request)
        candidates.append({**person, "match": level, "is_current": person["id"] == request["assignment"].get("personnel_id")})
    candidates.sort(key=lambda p: (_MATCH_ORDER[p["match"]], p["open_task_count"], p["full_name"]))
    return {
        "success": True,
        "request": request,
        "candidates": candidates,
        "recommended_id": candidates[0]["id"] if candidates else None,
    }


def assign_request(report_id: str, personnel_id: str, admin: Dict[str, Any], note: Optional[str] = None) -> Dict[str, Any]:
    personnel_id = str(personnel_id or "").strip()
    if not personnel_id:
        return _error("Personel secimi zorunludur", 400)
    ensure_workflow_schema_once()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        row = _lock_report(cursor, report_id)
        if not row:
            return _error("Talep bulunamadi", 404)
        status = row.get("status") or "draft"
        if status not in ASSIGNABLE_STATUSES:
            return _error(f"Bu talep su an atanamaz (durum: {status})", 409)

        personnel = personnel_service._get_personnel(cursor, personnel_id)
        if not personnel:
            return _error("Personel bulunamadi", 404)
        if not personnel_service._is_active_value(personnel.get("is_active")):
            return _error("Pasif personele gorev atanamaz", 409)

        data = _load_data(row.get("data"))
        previous_id = _assigned_id(data)
        new_id = str(personnel["id"])
        if previous_id == new_id:
            return _error("Talep zaten bu personele atanmis", 409)

        public_person = personnel_service._public_personnel(personnel)
        request_location = _request_location(row, data)
        now = _now()
        assignment = data.get("assignment") if isinstance(data.get("assignment"), dict) else {}
        history = list(assignment.get("history") or [])
        history.append(
            {
                "action": "reassigned" if previous_id else "assigned",
                "from_personnel_id": previous_id or None,
                "personnel_id": new_id,
                "personnel_name": public_person["full_name"],
                "by": _actor_label(admin),
                "at": now,
                "note": (note or "").strip(),
            }
        )
        data["assignment"] = {
            "status": "assigned",
            "personnel_id": new_id,
            "personnel_name": public_person["full_name"],
            "personnel_phone": public_person["phone"] or "",
            "personnel_city": public_person["city"],
            "match": _match_level(public_person, {**request_location}),
            "assigned_at": now,
            "assigned_by": _actor_label(admin),
            "accepted_at": None,
            "started_at": None,
            "note": (note or "").strip(),
            "history": history,
        }
        data["assigned_personel_id"] = new_id
        data["assigned_personel_name"] = public_person["full_name"]
        if isinstance(data.get("talep"), dict):
            data["talep"]["atananPersonel"] = new_id
            data["talep"]["durum"] = DURUM_BY_ASSIGNMENT["assigned"]

        _save_report_data(cursor, row, data, DURUM_BY_ASSIGNMENT["assigned"])
        _write_audit(
            cursor,
            "REQUEST_REASSIGNED" if previous_id else "REQUEST_ASSIGNED",
            str(row["id"]),
            admin,
            {"personnel_id": new_id, "previous_personnel_id": previous_id or None, "note": (note or "").strip()},
        )
        conn.commit()
        return {"success": True, "request": _admin_request(_fetch_report(cursor, report_id))}
    finally:
        DatabaseConfig.return_connection(conn)


def unassign_request(report_id: str, admin: Dict[str, Any], reason: Optional[str] = None) -> Dict[str, Any]:
    ensure_workflow_schema_once()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        row = _lock_report(cursor, report_id)
        if not row:
            return _error("Talep bulunamadi", 404)
        if (row.get("status") or "draft") not in ASSIGNABLE_STATUSES:
            return _error("Rapor onay surecindeki talebin atamasi kaldirilamaz", 409)
        data = _load_data(row.get("data"))
        previous_id = _assigned_id(data)
        if not previous_id:
            return _error("Talep zaten atanmamis", 409)
        note = (reason or "").strip() or "Admin atamayi kaldirdi"
        data = _clear_assignment(data, admin, note, "unassigned")
        _save_report_data(cursor, row, data, DURUM_BY_ASSIGNMENT["unassigned"])
        _write_audit(cursor, "REQUEST_UNASSIGNED", str(row["id"]), admin, {"personnel_id": previous_id, "reason": note})
        conn.commit()
        return {"success": True, "request": _admin_request(_fetch_report(cursor, report_id))}
    finally:
        DatabaseConfig.return_connection(conn)


def release_personnel_tasks(cursor: Any, personnel_id: str, actor: Dict[str, Any], reason: str) -> List[str]:
    """Personelin acik (draft/rejected) gorevlerini admin kuyruguna geri dusurur.

    Cagiran fonksiyonun transaction'i icinde calisir; commit cagirana aittir.
    """
    cursor.execute(
        """
        SELECT * FROM reports
        WHERE data->>'assigned_personel_id' = %s
          AND COALESCE(status, 'draft') IN %s
        FOR UPDATE
        """,
        (str(personnel_id), ASSIGNABLE_STATUSES),
    )
    released = []
    for raw in cursor.fetchall():
        row = dict(raw)
        data = _clear_assignment(_load_data(row.get("data")), actor, reason, "released")
        _save_report_data(cursor, row, data, DURUM_BY_ASSIGNMENT["unassigned"])
        _write_audit(cursor, "REQUEST_RELEASED", str(row["id"]), actor, {"personnel_id": str(personnel_id), "reason": reason})
        released.append(str(row["id"]))
    return released


def open_request_locations(cursor: Any) -> List[Dict[str, Any]]:
    """Kapsama raporu icin acik taleplerin il bilgisi."""
    cursor.execute(
        "SELECT id, sehir, status, data FROM reports WHERE COALESCE(status, 'draft') IN %s",
        (ASSIGNABLE_STATUSES,),
    )
    items = []
    for raw in cursor.fetchall():
        row = dict(raw)
        data = _load_data(row.get("data"))
        location = _request_location(row, data)
        items.append({"id": str(row["id"]), "il_id": location["il_id"], "assigned": bool(_assigned_id(data))})
    return items


# ---------------------------------------------------------------------------
# Personel: gorevlerim
# ---------------------------------------------------------------------------

def is_personnel(user: Dict[str, Any]) -> bool:
    return str(user.get("role") or "").lower().strip() in PERSONNEL_ROLES


def list_personnel_tasks(user: Dict[str, Any]) -> Dict[str, Any]:
    ensure_workflow_schema_once()
    personnel_id = str(user.get("id") or "")
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT * FROM reports
            WHERE data->>'assigned_personel_id' = %s
            ORDER BY created_at DESC NULLS LAST
            LIMIT 300
            """,
            (personnel_id,),
        )
        tasks = [_admin_request(dict(row)) for row in cursor.fetchall()]
    finally:
        DatabaseConfig.return_connection(conn)

    for task in tasks:
        task["is_active"] = task["status"] in ASSIGNABLE_STATUSES
    active = [t for t in tasks if t["is_active"]]
    return {
        "success": True,
        "summary": {
            "active": len(active),
            "waiting_acceptance": sum(1 for t in active if t["assignment"]["status"] == "assigned"),
            "in_progress": sum(1 for t in active if t["assignment"]["status"] in ("accepted", "in_progress")),
            "needs_revision": sum(1 for t in active if t["needs_revision"]),
            "completed": len(tasks) - len(active),
        },
        "tasks": tasks,
    }


_TASK_TRANSITIONS = {
    "accept": {"from": ("assigned",), "to": "accepted", "stamp": "accepted_at"},
    # "submitted": admin raporu reddettiyse personel duzeltmeye yeniden baslar
    "start": {"from": ("assigned", "accepted", "submitted"), "to": "in_progress", "stamp": "started_at"},
}


def update_task_progress(report_id: str, user: Dict[str, Any], action: str) -> Dict[str, Any]:
    transition = _TASK_TRANSITIONS.get(action)
    if not transition:
        return _error("Gecersiz islem", 400)
    ensure_workflow_schema_once()
    personnel_id = str(user.get("id") or "")
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        row = _lock_report(cursor, report_id)
        if not row:
            return _error("Gorev bulunamadi", 404)
        data = _load_data(row.get("data"))
        if _assigned_id(data) != personnel_id:
            return _error("Bu gorev size atanmamis", 403)
        if (row.get("status") or "draft") not in ASSIGNABLE_STATUSES:
            return _error("Bu gorev artik guncellenemez", 409)

        current = _assignment_status(data)
        if current == transition["to"]:
            return {"success": True, "task": _admin_request(row), "unchanged": True}
        if current not in transition["from"]:
            return _error(f"Gorev bu adima gecemez (mevcut: {current})", 409)

        now = _now()
        assignment = data.get("assignment") if isinstance(data.get("assignment"), dict) else {
            "personnel_id": personnel_id,
            "personnel_name": data.get("assigned_personel_name") or user.get("full_name") or "",
            "history": [],
        }
        assignment["status"] = transition["to"]
        assignment[transition["stamp"]] = now
        if transition["to"] == "in_progress" and not assignment.get("accepted_at"):
            assignment["accepted_at"] = now
        history = list(assignment.get("history") or [])
        history.append({"action": action, "personnel_id": personnel_id, "by": _actor_label(user), "at": now})
        assignment["history"] = history
        data["assignment"] = assignment
        durum = DURUM_BY_ASSIGNMENT[transition["to"]]
        if isinstance(data.get("talep"), dict):
            data["talep"]["durum"] = durum

        _save_report_data(cursor, row, data, durum)
        _write_audit(cursor, f"TASK_{action.upper()}", str(row["id"]), user, {"personnel_id": personnel_id})
        conn.commit()
        return {"success": True, "task": _admin_request(_fetch_report(cursor, report_id))}
    finally:
        DatabaseConfig.return_connection(conn)


# ---------------------------------------------------------------------------
# Personel: saha raporu (dis / ic / boya-kaporta / kurumsal) ve fotograflar
# ---------------------------------------------------------------------------

REPORT_SECTIONS = ("adim1", "adim2", "adim3", "adim4", "adim5")
MAX_REPORT_JSON_BYTES = 2 * 1024 * 1024


def corporate_info(row: Dict[str, Any], data: Dict[str, Any]) -> Dict[str, Any]:
    """Musterinin kurumsal ekspertiz (anlasmali firma) talep edip etmedigi."""
    talep = data.get("talep") if isinstance(data.get("talep"), dict) else {}
    firm_name = row.get("ekspertiz_firmasi") or row.get("firma") or talep.get("expertizFirmasi") or ""
    package_name = data.get("expertiz_paketi") or talep.get("expertizPaketi") or ""
    required = bool(data.get("firm_id") or data.get("expertiz_package_id"))
    if "corporate_required" in data:
        required = bool(data.get("corporate_required"))
    return {"required": required, "firm_name": firm_name, "package_name": package_name}


def _load_owned_task(cursor: Any, report_id: str, user: Dict[str, Any], lock: bool = False) -> Dict[str, Any]:
    cursor.execute(
        f"SELECT * FROM reports WHERE id::text = %s{' FOR UPDATE' if lock else ''}",
        (str(report_id),),
    )
    row = cursor.fetchone()
    if not row:
        return _error("Gorev bulunamadi", 404)
    row = dict(row)
    data = _load_data(row.get("data"))
    if _assigned_id(data) != str(user.get("id") or ""):
        return _error("Bu gorev size atanmamis", 403)
    return {"row": row, "data": data}


def _task_is_open(row: Dict[str, Any]) -> bool:
    return (row.get("status") or "draft") in ASSIGNABLE_STATUSES


def get_task_report(report_id: str, user: Dict[str, Any]) -> Dict[str, Any]:
    """Personelin rapor ekrani icin: gorev, taslak rapor, fotograflar, kurumsal bilgi."""
    ensure_workflow_schema_once()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        loaded = _load_owned_task(cursor, report_id, user)
        if "error" in loaded:
            return loaded
        row, data = loaded["row"], loaded["data"]
        media = media_service.list_media(cursor, [str(row["id"])])[str(row["id"])]
    finally:
        DatabaseConfig.return_connection(conn)
    return {
        "success": True,
        "task": _admin_request(row),
        "editable": _task_is_open(row),
        "tam_rapor": data.get("tam_rapor_draft") or data.get("tam_rapor"),
        "draft_saved_at": data.get("tam_rapor_draft_at"),
        "corporate": corporate_info(row, data),
        "rejection_reason": data.get("rejection_reason") if row.get("status") == "rejected" else None,
        "media": media,
    }


def _validate_report_payload(tam_rapor: Any) -> Optional[Dict[str, Any]]:
    if not isinstance(tam_rapor, dict):
        return _error("Rapor verisi gecersiz", 400)
    if len(json.dumps(tam_rapor, ensure_ascii=False, default=str).encode("utf-8")) > MAX_REPORT_JSON_BYTES:
        return _error("Rapor verisi cok buyuk", 413)
    return None


def save_task_draft(report_id: str, user: Dict[str, Any], tam_rapor: Any) -> Dict[str, Any]:
    invalid = _validate_report_payload(tam_rapor)
    if invalid:
        return invalid
    ensure_workflow_schema_once()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        loaded = _load_owned_task(cursor, report_id, user, lock=True)
        if "error" in loaded:
            return loaded
        row, data = loaded["row"], loaded["data"]
        if not _task_is_open(row):
            return _error("Gonderilmis rapor degistirilemez", 409)
        data["tam_rapor_draft"] = tam_rapor
        data["tam_rapor_draft_at"] = _now()
        cursor.execute(
            "UPDATE reports SET data = %s, updated_at = NOW() WHERE id = %s",
            (Json(data), row["id"]),
        )
        conn.commit()
        return {"success": True, "draft_saved_at": data["tam_rapor_draft_at"]}
    finally:
        DatabaseConfig.return_connection(conn)


def upload_task_media(
    report_id: str,
    user: Dict[str, Any],
    content: bytes,
    original_name: Optional[str],
    category: str,
    section: Optional[str] = None,
    item_key: Optional[str] = None,
    item_label: Optional[str] = None,
    note: Optional[str] = None,
) -> Dict[str, Any]:
    ensure_workflow_schema_once()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        loaded = _load_owned_task(cursor, report_id, user)
        if "error" in loaded:
            return loaded
        row = loaded["row"]
        if not _task_is_open(row):
            return _error("Gonderilmis rapora dosya eklenemez", 409)
        result = media_service.store_media(
            cursor, str(row["id"]), user, content, original_name, category, section, item_key, item_label, note
        )
        if "error" in result:
            conn.rollback()
            return result
        _write_audit(
            cursor,
            "MEDIA_UPLOADED",
            str(row["id"]),
            user,
            {"media_id": result["media"]["id"], "category": category, "item_key": item_key},
        )
        conn.commit()
        return result
    finally:
        DatabaseConfig.return_connection(conn)


def delete_task_media(report_id: str, media_id: str, user: Dict[str, Any]) -> Dict[str, Any]:
    ensure_workflow_schema_once()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        loaded = _load_owned_task(cursor, report_id, user)
        if "error" in loaded:
            return loaded
        row = loaded["row"]
        if not _task_is_open(row):
            return _error("Gonderilmis rapordan dosya silinemez", 409)
        if not media_service.soft_delete_media(cursor, str(row["id"]), media_id):
            return _error("Dosya bulunamadi", 404)
        _write_audit(cursor, "MEDIA_DELETED", str(row["id"]), user, {"media_id": str(media_id)})
        conn.commit()
        return {"success": True}
    finally:
        DatabaseConfig.return_connection(conn)


def submit_task_report(report_id: str, user: Dict[str, Any], tam_rapor: Any) -> Dict[str, Any]:
    """Personel raporu 'Kaydet ve Gonder' ile admin onayina gonderir.

    Kurallar:
    - Gorev bu personele atanmis ve acik (draft / rejected) olmali.
    - Rapor 5 bolumu icermeli (arac, dis, ic, boya-kaporta, kurumsal).
    - Musteri kurumsal ekspertiz talep ettiyse kurumsal rapor dosyasi eklenmis olmali.
    Sonuc: status='pending_ai' (merkezi AI analizi) -> admin 'Onay Bekleyen' sekmesi.
    """
    invalid = _validate_report_payload(tam_rapor)
    if invalid:
        return invalid
    missing = [key for key in REPORT_SECTIONS if not isinstance(tam_rapor.get(key), dict)]
    if missing:
        return _error(f"Rapor eksik bolum iceriyor: {', '.join(missing)}", 400)

    ensure_workflow_schema_once()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        loaded = _load_owned_task(cursor, report_id, user, lock=True)
        if "error" in loaded:
            return loaded
        row, data = loaded["row"], loaded["data"]
        if not _task_is_open(row):
            return _error("Bu rapor zaten gonderilmis", 409)

        counts = media_service.count_media(cursor, str(row["id"]))
        corporate = corporate_info(row, data)
        if corporate["required"] and counts.get("corporate_report", 0) == 0:
            return _error(
                f"Musteri kurumsal ekspertiz talep etti ({corporate['firm_name'] or 'anlasmali firma'}). "
                "Firmanin raporunu dosyaya ekleyin.",
                409,
            )

        now = _now()
        was_rejected = row.get("status") == "rejected"
        assignment = data.get("assignment") if isinstance(data.get("assignment"), dict) else {}
        history = list(assignment.get("history") or [])
        history.append({"action": "submitted", "personnel_id": str(user.get("id")), "by": _actor_label(user), "at": now})
        assignment.update({"status": "submitted", "submitted_at": now, "history": history})
        data["assignment"] = assignment
        data["tam_rapor"] = tam_rapor
        data["tam_rapor_draft"] = tam_rapor
        data["tam_rapor_draft_at"] = now
        data["inspection"] = {
            "submitted_at": now,
            "submitted_by": str(user.get("id")),
            "submitted_by_name": user.get("full_name") or user.get("email"),
            "photo_count": counts.get("inspection_photo", 0),
            "corporate_report_count": counts.get("corporate_report", 0),
            "corporate_required": corporate["required"],
            "revision": int((data.get("inspection") or {}).get("revision", 0)) + (1 if was_rejected else 0),
        }
        if was_rejected:
            data["previous_rejection_reason"] = data.get("rejection_reason")
        if isinstance(data.get("talep"), dict):
            data["talep"]["durum"] = DURUM_BY_ASSIGNMENT["submitted"]

        adim1 = tam_rapor.get("adim1") or {}
        snapshot = data.get("vehicle_snapshot") if isinstance(data.get("vehicle_snapshot"), dict) else {}
        for target, source in (("marka", "marka"), ("model", "model"), ("yil", "yil"), ("km", "guncelKm")):
            if adim1.get(source) not in (None, ""):
                snapshot[target] = adim1.get(source)
        data["vehicle_snapshot"] = snapshot

        cursor.execute(
            """
            UPDATE reports
            SET data = %s,
                status = 'pending_ai',
                durum = %s,
                plaka = COALESCE(NULLIF(%s, ''), plaka),
                status_updated_at = NOW(),
                updated_at = NOW(),
                version_id = COALESCE(version_id, 0) + 1
            WHERE id = %s
            """,
            (Json(data), DURUM_BY_ASSIGNMENT["submitted"], str(adim1.get("plaka") or ""), row["id"]),
        )
        request_id = data.get("expertiz_request_id") or str(row["id"])
        cursor.execute(
            "UPDATE expertiz_requests SET status = %s, updated_at = %s WHERE id = %s",
            (DURUM_BY_ASSIGNMENT["submitted"], now, str(request_id)),
        )
        _write_audit(
            cursor,
            "REPORT_SUBMITTED",
            str(row["id"]),
            user,
            {"revision": data["inspection"]["revision"], "photos": counts.get("inspection_photo", 0)},
        )
        conn.commit()
        return {"success": True, "task": _admin_request(_fetch_report(cursor, report_id))}
    finally:
        DatabaseConfig.return_connection(conn)


async def run_central_ai(report_id: str) -> bool:
    """Gonderilen rapor icin merkezi AI analizini calistirir (arka planda).

    Basarili olursa rapor 'pending_admin' durumuna gecer. Basarisiz olursa
    'pending_ai' olarak admin 'Onay Bekleyen' listesinde kalir ve admin
    analizi panelden tekrar tetikleyebilir.
    """
    try:
        from yerimebak_ai_v5.workers.ai_analysis_worker import get_ai_analysis_worker

        return bool(await get_ai_analysis_worker().process_single_report(str(report_id)))
    except Exception as exc:  # pragma: no cover - loglanir
        logger.error("Merkezi AI analizi baslatilamadi (%s): %s", report_id, exc)
        return False
