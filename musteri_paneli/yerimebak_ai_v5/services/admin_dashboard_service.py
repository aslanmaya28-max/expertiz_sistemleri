# -*- coding: utf-8 -*-
"""
Admin ana ekrani (Flutter Dashboard sekmesi) icin tek seferde ozet.

Onceden Flutter bu verileri dogrudan Supabase'den cekiyordu; artik merkezi
veritabanindan hesaplanir: sayaclar, rapor durum dagilimi, son islemler,
onay bekleyen raporlar (AI guven skoru ile), son 7 gunun yayin trendi,
AI guven trendi ve personel teslim sureleri.
"""
import json
from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from yerimebak_ai_v5.core.database_config import DatabaseConfig

STATUSES = ("draft", "pending_ai", "pending_admin", "published", "rejected", "cancelled")

ACTION_TITLES = {
    "REQUEST_ASSIGNED": ("statusChanged", "Personel atandı"),
    "REQUEST_REASSIGNED": ("statusChanged", "Personel değiştirildi"),
    "REQUEST_UNASSIGNED": ("statusChanged", "Atama kaldırıldı"),
    "REQUEST_CANCELLED": ("reportRejected", "Talep iptal edildi"),
    "REPORT_SUBMITTED": ("reportCreated", "Rapor onaya gönderildi"),
    "REPORT_PUBLISHED": ("reportPublished", "Rapor yayınlandı"),
    "REPORT_REJECTED": ("reportRejected", "Rapor reddedildi"),
    "ai_analysis_completed": ("aiAnalysisComplete", "AI analizi tamamlandı"),
    "TASK_ACCEPT": ("statusChanged", "Görev kabul edildi"),
    "TASK_DEPART": ("statusChanged", "Personel yola çıktı"),
    "TASK_ARRIVE": ("statusChanged", "Personel araç başında"),
    "TASK_CORPORATE": ("statusChanged", "Kurumsal ekspertizde"),
    "TASK_START": ("statusChanged", "Rapor hazırlanıyor"),
    "PERSONNEL_CREATED": ("userCreated", "Personel eklendi"),
    "PERSONNEL_DUTY_CHANGED": ("statusChanged", "Personel görev durumu"),
    "CREDIT_ORDER_REFUNDED": ("reportRejected", "Kredi iadesi"),
}


def _load(value: Any) -> Dict[str, Any]:
    if isinstance(value, dict):
        return value
    try:
        loaded = json.loads(value or "{}")
        return loaded if isinstance(loaded, dict) else {}
    except Exception:
        return {}


def _iso(value: Any) -> Optional[str]:
    if value is None:
        return None
    if hasattr(value, "isoformat"):
        return value.isoformat()
    return str(value)


def _as_dt(value: Any) -> Optional[datetime]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=timezone.utc)
    try:
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def ai_confidence(ai: Any) -> Optional[float]:
    """AI degerlemesinin veri guven skoru (0-100)."""
    ai = _load(ai)
    for path in (("ekspertizDegerleme", "guvenSkoru"), ("skorlar", "detayliPuanlar", "guvenSkoru")):
        node: Any = ai
        for key in path:
            node = node.get(key) if isinstance(node, dict) else None
        if isinstance(node, (int, float)):
            return float(node)
    return None


def _table_exists(cursor: Any, name: str) -> bool:
    cursor.execute("SELECT to_regclass(%s) IS NOT NULL AS found", (f"public.{name}",))
    return bool(dict(cursor.fetchone()).get("found"))


def get_dashboard() -> Dict[str, Any]:
    from yerimebak_ai_v5.services import dispatch_service

    dispatch_service.ensure_workflow_schema_once()
    today = date.today()
    week_start = today - timedelta(days=6)
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT id, plaka, status, created_at, status_updated_at, data, ai_analiz_detay FROM reports "
            "ORDER BY created_at DESC NULLS LAST LIMIT 5000"
        )
        reports = [dict(r) for r in cursor.fetchall()]

        cursor.execute(
            """
            SELECT
              COUNT(*) FILTER (WHERE role IN ('personel', 'field_staff', 'staff', 'personnel') AND COALESCE(is_active, 1) = 1) AS personnel,
              COUNT(*) FILTER (WHERE role IN ('user', 'customer', 'musteri')) AS customers
            FROM users
            """
        )
        counts = dict(cursor.fetchone())

        total_vehicles = 0
        if _table_exists(cursor, "listings"):
            cursor.execute("SELECT COUNT(*) AS n FROM listings WHERE COALESCE(status, 'active') IN ('active', 'featured')")
            total_vehicles = int(dict(cursor.fetchone())["n"])

        cursor.execute(
            "SELECT id, user_email, user_name, action, entity_id, metadata, created_at FROM audit_logs "
            "ORDER BY created_at DESC LIMIT 8"
        )
        audits = [dict(r) for r in cursor.fetchall()]
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)

    distribution = {s: 0 for s in STATUSES}
    weekly = {(week_start + timedelta(days=i)).isoformat(): 0 for i in range(7)}
    confidence_by_day: Dict[str, List[float]] = {k: [] for k in weekly}
    today_published = today_submitted = active = 0
    pending: List[Dict[str, Any]] = []
    sla: Dict[str, Dict[str, Any]] = {}

    for r in reports:
        status = r.get("status") or "draft"
        if status in distribution:
            distribution[status] += 1
        if status not in ("published", "cancelled"):
            active += 1
        created = _as_dt(r.get("created_at"))
        updated = _as_dt(r.get("status_updated_at"))
        if created and created.date() == today:
            today_submitted += 1
        if status == "published" and updated:
            day = updated.date().isoformat()
            if day in weekly:
                weekly[day] += 1
            if updated.date() == today:
                today_published += 1
        conf = ai_confidence(r.get("ai_analiz_detay"))
        if conf is not None and updated and updated.date().isoformat() in confidence_by_day:
            confidence_by_day[updated.date().isoformat()].append(conf)

        data = _load(r.get("data"))
        if status == "pending_admin":
            pending.append({
                "id": str(r["id"]),
                "plaka": r.get("plaka") or (data.get("vehicle_snapshot") or {}).get("plaka") or "",
                "status": status,
                "status_updated_at": _iso(r.get("status_updated_at")),
                "ai_analysis_result": {"reliability_score": conf if conf is not None else 0.0},
            })
        if status == "published":
            assignment = data.get("assignment") or {}
            name = assignment.get("personnel_name") or data.get("assigned_personel_name")
            start = _as_dt(assignment.get("assigned_at")) or created
            end = _as_dt(data.get("published_at")) or updated
            if name and start and end and end >= start:
                entry = sla.setdefault(name, {"hours": [], "id": assignment.get("personnel_id")})
                entry["hours"].append((end - start).total_seconds() / 3600)

    # Onay bekleyenler: dusuk guven skoru once (daha dikkatli inceleme), sonra en eski
    pending.sort(key=lambda p: (p["ai_analysis_result"]["reliability_score"], p["status_updated_at"] or ""))

    activities = []
    for a in audits:
        kind, title = ACTION_TITLES.get(str(a.get("action")), ("other", str(a.get("action") or "Sistem işlemi")))
        meta = _load(a.get("metadata"))
        description = meta.get("reason") or meta.get("note") or f"Kayıt: {a.get('entity_id') or '-'}"
        activities.append({
            "id": str(a["id"]),
            "type": kind,
            "title": title,
            "description": str(description)[:200],
            "user_id": None,
            "user_name": a.get("user_name") or a.get("user_email"),
            "report_id": str(a.get("entity_id") or ""),
            "timestamp": _iso(a.get("created_at")),
        })

    return {
        "success": True,
        "stats": {
            "total_vehicles": total_vehicles,
            "active_reports": active,
            "personnel_count": int(counts.get("personnel") or 0),
            "customer_count": int(counts.get("customers") or 0),
            "total_reports": len(reports),
            "today_published": today_published,
            "today_submitted": today_submitted,
        },
        "status_distribution": distribution,
        "recent_activities": activities,
        "pending_admin": pending[:10],
        "weekly_published": [{"date": d, "count": c} for d, c in weekly.items()],
        "ai_confidence_trend": [
            {"date": d, "avg": round(sum(v) / len(v), 1) if v else 0.0, "count": len(v)} for d, v in confidence_by_day.items()
        ],
        "personnel_sla": sorted(
            (
                {"personnel_name": n, "personnel_id": e["id"], "avg_hours": round(sum(e["hours"]) / len(e["hours"]), 1),
                 "report_count": len(e["hours"])}
                for n, e in sla.items()
            ),
            key=lambda p: p["avg_hours"],
        ),
    }
