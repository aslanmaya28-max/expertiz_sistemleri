# -*- coding: utf-8 -*-
"""
Admin finans ozeti.

Kaynaklar:
  - expertiz_requests: musterinin odedigi ekspertiz tutari (hizmet + paket + KDV)
  - reports:           raporun durumu ve atanan personel (data.assigned_personel_id)
  - payment_orders:    musteri panelindeki kredi paketi satislari

Personel odeme (hakedis) takibi henuz yok; hakedis, yayinlanan raporlarin hizmet
bedeli uzerinden PERSONNEL_SHARE_RATE ile hesaplanan tahakkuktur.
"""
import json
import os
from typing import Any, Dict, List

from yerimebak_ai_v5.core.infrastructure.database_config import DatabaseConfig
from yerimebak_ai_v5.services.expertiz_service import _ensure_expertiz_requests_schema

# Personel payi sadece YerimeBak hizmet bedeli uzerinden hesaplanir; kurumsal
# ekspertiz paket ucreti firmaya aktarilan maliyettir, personelle paylasilmaz.
PERSONNEL_SHARE_RATE = float(os.getenv("PERSONNEL_SHARE_RATE", "0.25"))

CANCELLED_REQUEST_STATUSES = {"Iptal", "cancelled"}


def _num(value: Any) -> float:
    try:
        return float(value or 0)
    except (TypeError, ValueError):
        return 0.0


def _as_dict(value: Any) -> Dict[str, Any]:
    if isinstance(value, dict):
        return value
    if isinstance(value, str) and value:
        try:
            parsed = json.loads(value)
            return parsed if isinstance(parsed, dict) else {}
        except ValueError:
            return {}
    return {}


def summarize(requests: List[Dict[str, Any]], payment_orders: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Ham satirlardan finans ozetini hesaplar (veritabanindan bagimsiz)."""
    ciro = kdv = net = 0.0
    adet = simulasyon_adet = 0
    durumlar: Dict[str, int] = {}
    personel: Dict[str, Dict[str, Any]] = {}

    for row in requests:
        if row.get("status") in CANCELLED_REQUEST_STATUSES:
            continue
        toplam = _num(row.get("total_tl"))
        vergi = _num(row.get("vat_tl"))
        kdv_haric = toplam - vergi

        adet += 1
        ciro += toplam
        kdv += vergi
        net += kdv_haric
        if row.get("payment_status") == "paid_simulation":
            simulasyon_adet += 1

        rapor_durumu = row.get("report_status") or "bilinmiyor"
        durumlar[rapor_durumu] = durumlar.get(rapor_durumu, 0) + 1

        if rapor_durumu != "published":
            continue
        data = _as_dict(row.get("report_data"))
        assignment = _as_dict(data.get("assignment"))
        personel_id = str(data.get("assigned_personel_id") or assignment.get("personnel_id") or "").strip()
        if not personel_id:
            continue
        kayit = personel.setdefault(personel_id, {
            "personnel_id": personel_id,
            "personnel_name": data.get("assigned_personel_name") or assignment.get("personnel_name") or "",
            "report_count": 0,
            "hakedis_tl": 0.0,
        })
        kayit["report_count"] += 1
        kayit["hakedis_tl"] += _num(row.get("service_fee_tl")) * PERSONNEL_SHARE_RATE

    kredi = {"approved_tl": 0.0, "approved_count": 0, "pending_tl": 0.0, "pending_count": 0}
    for row in payment_orders:
        status = row.get("status")
        if status in ("approved", "pending"):
            kredi[f"{status}_tl"] += _num(row.get("toplam"))
            kredi[f"{status}_count"] += int(row.get("adet") or 0)

    personel_listesi = sorted(personel.values(), key=lambda p: p["hakedis_tl"], reverse=True)
    for p in personel_listesi:
        p["hakedis_tl"] = round(p["hakedis_tl"], 2)

    return {
        "success": True,
        "ekspertiz": {
            "request_count": adet,
            "ciro_tl": round(ciro, 2),
            "kdv_tl": round(kdv, 2),
            "net_tl": round(net, 2),
            "simulated_payment_count": simulasyon_adet,
            "report_status_counts": durumlar,
        },
        "kredi_satislari": {k: round(v, 2) if isinstance(v, float) else v for k, v in kredi.items()},
        "personel": {
            "share_rate": PERSONNEL_SHARE_RATE,
            "hakedis_tl": round(sum(p["hakedis_tl"] for p in personel_listesi), 2),
            "by_personnel": personel_listesi,
            "payout_tracking": False,
        },
    }


def get_admin_finance_summary() -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_expertiz_requests_schema(cursor)
        cursor.execute(
            """
            SELECT q.id, q.status, q.payment_status, q.total_tl, q.vat_tl, q.service_fee_tl,
                   r.status AS report_status, r.data AS report_data
            FROM expertiz_requests q
            LEFT JOIN reports r ON r.id::text = q.id
            """
        )
        requests = [dict(row) for row in cursor.fetchall()]

        payment_orders: List[Dict[str, Any]] = []
        cursor.execute("SELECT to_regclass('public.payment_orders') IS NOT NULL AS found")
        exists = cursor.fetchone()
        if exists and dict(exists).get("found"):
            cursor.execute(
                """
                SELECT status, COUNT(*) AS adet, COALESCE(SUM(amount_tl), 0) AS toplam
                FROM payment_orders
                GROUP BY status
                """
            )
            payment_orders = [dict(row) for row in cursor.fetchall()]
        conn.commit()
        return summarize(requests, payment_orders)
    finally:
        DatabaseConfig.return_connection(conn)
