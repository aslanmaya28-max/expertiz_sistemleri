# -*- coding: utf-8 -*-
"""
Muhasebe / e-Arsiv fatura icin odeme dokumu (CSV).

Sistem e-Arsiv faturayi kendisi kesmez (bunun icin GIB onayli bir entegrator
hesabi gerekir). Bu dokum, tarih araligindaki tum tahsilatlari musteri fatura
bilgileriyle birlikte verir; entegrator paneline toplu yuklenebilir ya da
muhasebeciye iletilir. Iadeler ayri satir olarak (eksi tutarla) listelenir.
"""
import csv
import io
from datetime import date, datetime, timedelta
from typing import Any, Dict, List, Optional

from yerimebak_ai_v5.core.database_config import DatabaseConfig

COLUMNS = [
    "tarih", "islem", "siparis_no", "aciklama", "musteri_adi", "e_posta", "telefon",
    "firma_unvani", "vergi_tckn_no", "vergi_dairesi", "fatura_adresi", "il",
    "kdv_haric_tl", "kdv_tl", "toplam_tl",
]


def _parse_day(value: Optional[str], default: date) -> date:
    if not value:
        return default
    return datetime.strptime(value[:10], "%Y-%m-%d").date()


def _money(value: Any) -> str:
    return f"{float(value or 0):.2f}"


def _billing(u: Dict[str, Any]) -> Dict[str, str]:
    return {
        "musteri_adi": u.get("full_name") or "",
        "e_posta": u.get("email") or "",
        "telefon": u.get("phone") or "",
        "firma_unvani": u.get("company_name") or "",
        "vergi_tckn_no": u.get("tax_number") or "",
        "vergi_dairesi": u.get("tax_office") or "",
        "fatura_adresi": u.get("invoice_address") or "",
        "il": u.get("city") or "",
    }


def collect_rows(start: Optional[str] = None, end: Optional[str] = None) -> List[Dict[str, str]]:
    today = date.today()
    start_day = _parse_day(start, today.replace(day=1))
    end_day = _parse_day(end, today)
    end_exclusive = end_day + timedelta(days=1)
    vat_rate = None
    rows: List[Dict[str, str]] = []
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        # to_jsonb(u): profil kolonlari (tax_number vb.) henuz olusmamissa da sorgu calisir
        cursor.execute(
            """
            SELECT q.*, to_jsonb(u) AS u
            FROM expertiz_requests q
            LEFT JOIN users u ON u.id::text = q.user_id
            WHERE q.payment_status IN ('paid', 'paid_simulation', 'refunded')
              AND COALESCE(q.paid_at::timestamptz, q.created_at::timestamptz) >= %s
              AND COALESCE(q.paid_at::timestamptz, q.created_at::timestamptz) < %s
            ORDER BY COALESCE(q.paid_at::timestamptz, q.created_at::timestamptz)
            """,
            (start_day, end_exclusive),
        )
        for raw in cursor.fetchall():
            q = dict(raw)
            u = q.get("u") or {}
            total = float(q.get("total_tl") or 0)
            vat = float(q.get("vat_tl") or 0)
            base = {
                "tarih": str(q.get("paid_at") or q.get("created_at") or "")[:19],
                "siparis_no": q.get("paytr_oid") or q.get("id"),
                "aciklama": f"Ekspertiz hizmeti: {q.get('firm_name') or ''} - {q.get('package_name') or ''} ({q.get('plate') or ''})",
                **_billing(u),
            }
            rows.append({**base, "islem": "satis", "kdv_haric_tl": _money(total - vat), "kdv_tl": _money(vat), "toplam_tl": _money(total)})
            if q.get("payment_status") == "refunded":
                rows.append({**base, "islem": "iade", "kdv_haric_tl": _money(-(total - vat)), "kdv_tl": _money(-vat), "toplam_tl": _money(-total)})

        cursor.execute("SELECT to_regclass('public.payment_orders') IS NOT NULL AS found")
        if dict(cursor.fetchone()).get("found"):
            from yerimebak_ai_v5.services.expertiz_service import VAT_RATE

            vat_rate = float(VAT_RATE)
            cursor.execute(
                """
                SELECT o.*, to_jsonb(u) AS u
                FROM payment_orders o
                LEFT JOIN users u ON u.id = o.user_id
                WHERE o.status IN ('approved', 'refunded')
                  AND COALESCE(o.approved_at, o.created_at) >= %s
                  AND COALESCE(o.approved_at, o.created_at) < %s
                ORDER BY COALESCE(o.approved_at, o.created_at)
                """,
                (start_day, end_exclusive),
            )
            for raw in cursor.fetchall():
                o = dict(raw)
                u = o.get("u") or {}
                total = float(o.get("amount_tl") or 0)
                # Kredi paketi fiyatlari KDV dahildir
                net = total / (1 + vat_rate)
                base = {
                    "tarih": str(o.get("approved_at") or o.get("created_at") or "")[:19],
                    "siparis_no": o.get("paytr_oid") or o.get("id"),
                    "aciklama": f"Arac analizi kredi paketi: {o.get('package_name') or ''} ({o.get('credits')} kredi)",
                    **_billing(u),
                }
                rows.append({**base, "islem": "satis", "kdv_haric_tl": _money(net), "kdv_tl": _money(total - net), "toplam_tl": _money(total)})
                if o.get("status") == "refunded":
                    rows.append({**base, "islem": "iade", "kdv_haric_tl": _money(-net), "kdv_tl": _money(-(total - net)), "toplam_tl": _money(-total)})
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    rows.sort(key=lambda r: r["tarih"])
    return rows


def to_csv(rows: List[Dict[str, str]]) -> str:
    buffer = io.StringIO()
    # Excel'in Turkce karakterleri dogru acmasi icin BOM + noktali virgul
    buffer.write("﻿")
    writer = csv.DictWriter(buffer, fieldnames=COLUMNS, delimiter=";", extrasaction="ignore")
    writer.writeheader()
    writer.writerows(rows)
    return buffer.getvalue()
