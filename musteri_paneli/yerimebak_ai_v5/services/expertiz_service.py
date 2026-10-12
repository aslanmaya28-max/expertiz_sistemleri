# -*- coding: utf-8 -*-
"""
Kurumsal ekspertiz paketleri ve musteri ekspertiz talep akisi.
"""
import json
import os
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from psycopg2.extras import Json

from yerimebak_ai_v5.core.database_config import DatabaseConfig


from yerimebak_ai_v5.services import pricing_service

VAT_RATE = pricing_service.VAT_RATE


def get_expertiz_packages() -> Dict[str, Any]:
    """Musteriye gosterilen guncel katalog (admin panelinden yonetilir)."""
    settings = pricing_service.get_pricing_settings()
    return {
        "service_fee_tl": settings["service_fee_tl"],
        "vat_rate": settings["vat_rate"],
        "firms": pricing_service.list_firms(),
    }


def find_package(firm_id: str, package_id: str) -> Optional[Dict[str, Any]]:
    return pricing_service.find_package(firm_id, package_id)


def calculate_total(package_price: float) -> Dict[str, float]:
    fee = pricing_service.get_service_fee_tl()
    subtotal = fee + package_price
    vat = subtotal * VAT_RATE
    return {
        "service_fee_tl": fee,
        "package_price_tl": package_price,
        "vat_tl": vat,
        "total_tl": subtotal + vat,
    }


def _expertiz_profile_id(user: Dict[str, Any]) -> str:
    """Return a stable UUID profile id for the Flutter/Supabase reports flow."""
    raw_id = str(user.get("id") or user.get("email") or uuid.uuid4())
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"yerimebak-ai-user:{raw_id}"))


def _normalize_city(city: Optional[str]) -> str:
    return (city or "").split("/")[0].strip()


def _canonical_city(city: Optional[str]) -> str:
    """Taniyabildigi il adini resmi yazimina cevirir (ör. 'istanbul kadikoy' -> 'İstanbul')."""
    from yerimebak_ai_v5.core import turkey_regions

    plate = turkey_regions.province_plate(city)
    return turkey_regions.province_name(plate) if plate else _normalize_city(city)


def _get_listing_snapshot(cursor: Any, listing_id: Any) -> Dict[str, Any]:
    if not listing_id:
        return {}

    try:
        cursor.execute(
            """
            SELECT id, brand, model, year, price, km, fuel, transmission, url,
                   location, title, color, image_url, risk_score, opportunity_score,
                   market_avg_price, price_deviation_pct
            FROM listings
            WHERE id = %s
            LIMIT 1
            """,
            (listing_id,),
        )
        row = cursor.fetchone()
        return dict(row) if row else {}
    except Exception:
        return {}


_reports_schema_ensured = False


def _ensure_reports_schema(cursor: Any) -> None:
    global _reports_schema_ensured
    if _reports_schema_ensured:
        return
    # Not: Kalici sema kurulumu uygulama acilisinda
    # dispatch_service.ensure_workflow_schema_once() ile commit edilerek yapilir.
    _reports_schema_ensured = True
    _create_reports_schema(cursor)


def _create_reports_schema(cursor: Any) -> None:
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS profiles (
            id UUID PRIMARY KEY,
            ad_soyad TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            telefon TEXT,
            rol TEXT DEFAULT 'musteri',
            bolge TEXT,
            aktif_mi BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        )
        """
    )
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS reports (
            id UUID PRIMARY KEY,
            user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
            ilan_linki TEXT,
            plaka TEXT,
            firma TEXT,
            sehir TEXT,
            ilce TEXT,
            ekspertiz_firmasi TEXT,
            secilen_paket TEXT,
            hizmet_bedeli NUMERIC(10,2) DEFAULT 6500.0,
            paket_fiyati NUMERIC(10,2) DEFAULT 0.0,
            toplam_tutar NUMERIC(10,2) DEFAULT 0.0,
            hasar_tutar NUMERIC(10,2) DEFAULT 0.0,
            odendi_mi BOOLEAN DEFAULT FALSE,
            durum TEXT DEFAULT 'Islemde',
            status TEXT DEFAULT 'draft',
            payment_status TEXT,
            ai_analizi_yapildi_mi BOOLEAN DEFAULT FALSE,
            data JSONB DEFAULT '{}'::jsonb,
            ai_analiz_detay JSONB,
            ai_analysis_result JSONB,
            status_updated_at TIMESTAMPTZ DEFAULT NOW(),
            version_id INTEGER DEFAULT 0,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        )
        """
    )

    columns = {
        "plaka": "TEXT",
        "firma": "TEXT",
        "customer_id": "UUID",
        "status": "TEXT DEFAULT 'draft'",
        "payment_status": "TEXT",
        "status_updated_at": "TIMESTAMPTZ DEFAULT NOW()",
        "version_id": "INTEGER DEFAULT 0",
        "ai_analysis_result": "JSONB",
    }
    for column, column_type in columns.items():
        cursor.execute(f"ALTER TABLE reports ADD COLUMN IF NOT EXISTS {column} {column_type}")


def _ensure_expertiz_requests_schema(cursor: Any) -> None:
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS expertiz_requests (
            id TEXT PRIMARY KEY,
            user_id TEXT,
            user_email TEXT,
            listing_id TEXT,
            listing_url TEXT,
            plate TEXT,
            city TEXT,
            firm_id TEXT,
            firm_name TEXT,
            package_id TEXT,
            package_name TEXT,
            service_fee_tl REAL,
            package_price_tl REAL,
            vat_tl REAL,
            total_tl REAL,
            status TEXT,
            payment_status TEXT,
            data TEXT,
            created_at TEXT,
            updated_at TEXT
        )
        """
    )


def _get_table_columns(cursor: Any, table_name: str) -> set[str]:
    cursor.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_name = %s
        """,
        (table_name,),
    )
    return {row["column_name"] for row in cursor.fetchall()}


def _row_to_dict(row: Any) -> Dict[str, Any]:
    return dict(row) if row else {}


def _json_loads(value: Any, fallback: Any = None) -> Any:
    if value is None:
        return fallback
    if isinstance(value, (dict, list)):
        return value
    if isinstance(value, str):
        try:
            return json.loads(value)
        except Exception:
            return fallback
    return fallback




def _ai_meta_from_row(row: Dict[str, Any]) -> Dict[str, Any]:
    data = _json_loads(row.get("data"), {}) or {}
    meta = data.get("ai_meta") if isinstance(data, dict) else None
    ai_result = row.get("ai_analysis_result") or row.get("ai_analiz_detay") or {}
    if isinstance(ai_result, str):
        ai_result = _json_loads(ai_result, {}) or {}
    if not isinstance(meta, dict):
        meta = {}
    if not isinstance(ai_result, dict):
        ai_result = {}
    return {
        "source": meta.get("source") or ai_result.get("source") or "none",
        "official": bool(meta.get("official") or ai_result.get("official")),
        "ready": bool(meta.get("ready") or row.get("ai_analizi_yapildi_mi")),
        "reference_found": bool(meta.get("reference_found")),
        "reference_count": int(meta.get("reference_count") or 0),
        "confidence": int(meta.get("confidence") or 0),
    }


def _has_official_central_ai(row: Dict[str, Any]) -> bool:
    meta = _ai_meta_from_row(row)
    return meta["source"] == "central_ai" and meta["official"] and meta["ready"]

def _upsert_profile(cursor: Any, profile_id: str, user: Dict[str, Any]) -> None:
    email = str(user.get("email") or f"user-{profile_id[:8]}@yerimebak.local")
    full_name = str(user.get("full_name") or user.get("name") or email.split("@")[0])
    phone = user.get("phone")
    cursor.execute(
        """
        INSERT INTO profiles (id, ad_soyad, email, telefon, rol, updated_at)
        VALUES (%s, %s, %s, %s, %s, NOW())
        ON CONFLICT (id) DO UPDATE SET
            ad_soyad = EXCLUDED.ad_soyad,
            email = EXCLUDED.email,
            telefon = EXCLUDED.telefon,
            updated_at = NOW()
        """,
        (profile_id, full_name, email, phone, "musteri"),
    )


def _upsert_report_from_request(
    cursor: Any,
    request_id: str,
    payload: Dict[str, Any],
    user: Dict[str, Any],
    selected: Dict[str, Any],
    totals: Dict[str, float],
    now: str,
    payment_status: str = "paid_simulation",
) -> str:
    _ensure_reports_schema(cursor)

    profile_id = _expertiz_profile_id(user)
    _upsert_profile(cursor, profile_id, user)

    # Vitrin ilani varsa onun bilgisi, yoksa musterinin linkle/elle girdigi arac
    listing = dict(_get_listing_snapshot(cursor, payload.get("listing_id")) or {})
    for key, value in (payload.get("vehicle") or {}).items():
        if value not in (None, "") and not listing.get(key):
            listing[key] = value
    data = {
        "source": "yerimebak_sistemleri",
        "expertiz_request_id": request_id,
        "payment_status": payment_status,
        "customer_name": user.get("full_name") or user.get("email") or "YerimeBak Musteri",
        "customer_email": user.get("email") or "",
        "customer_phone": user.get("phone") or "",
        "expertiz_paketi": selected["package"]["name"],
        "expertiz_package_id": selected["package"]["id"],
        "firm_id": selected["firm"]["id"],
        "note": payload.get("note") or "",
        "talep": {
            "id": request_id,
            "musteriAdi": user.get("full_name") or user.get("email") or "YerimeBak Musteri",
            "musteriId": profile_id,
            "telefon": user.get("phone") or "",
            "aracPlaka": payload.get("plate") or "",
            "aracMarka": listing.get("brand") or "Belirtilmedi",
            "aracModel": listing.get("model") or "Belirtilmedi",
            "durum": "Beklemede",
            "olusturulma": now,
            "aciklama": payload.get("listing_url") or listing.get("url") or payload.get("note") or "",
            "sehir": payload.get("city") or listing.get("location") or "",
            "ilce": payload.get("district") or "",
            "expertizFirmasi": selected["firm"]["name"],
            "expertizPaketi": selected["package"]["name"],
            "paketFiyati": totals["package_price_tl"],
            "hizmetBedeli": totals["service_fee_tl"],
            "toplamTutar": totals["total_tl"],
            "hasarTutar": 0.0,
            "isPaid": True,
        },
        "vehicle_snapshot": {
            "listing_id": payload.get("listing_id"),
            "listing_url": payload.get("listing_url") or listing.get("url") or "",
            "plaka": payload.get("plate") or "",
            "marka": listing.get("brand") or "",
            "model": listing.get("model") or "",
            "yil": listing.get("year"),
            "km": listing.get("km"),
            "price": listing.get("price"),
            "yakit": listing.get("fuel"),
            "sanziman": listing.get("transmission"),
            "title": listing.get("title"),
            "image_url": listing.get("image_url"),
            "location": listing.get("location"),
        },
    }

    desired = {
        "id": request_id,
        "user_id": profile_id,
        "customer_id": profile_id,
        "ilan_linki": payload.get("listing_url") or listing.get("url") or "",
        "plaka": payload.get("plate") or "",
        "firma": selected["firm"]["name"],
        "sehir": _canonical_city(payload.get("city") or listing.get("location")),
        "ilce": payload.get("district") or "",
        "ekspertiz_firmasi": selected["firm"]["name"],
        "secilen_paket": selected["package"]["id"],
        "hizmet_bedeli": totals["service_fee_tl"],
        "paket_fiyati": totals["package_price_tl"],
        "toplam_tutar": totals["total_tl"],
        "hasar_tutar": 0.0,
        "odendi_mi": True,
        "durum": "Islemde",
        "status": "draft",
        "payment_status": payment_status,
        "ai_analizi_yapildi_mi": False,
        "data": Json(data),
        "status_updated_at": now,
        "version_id": 0,
        "created_at": now,
        "updated_at": now,
    }

    columns = _get_table_columns(cursor, "reports")
    insert_data = {key: value for key, value in desired.items() if key in columns}
    column_names = list(insert_data.keys())
    placeholders = ", ".join(["%s"] * len(column_names))
    assignments = ", ".join(
        f"{column}=EXCLUDED.{column}"
        for column in column_names
        if column not in {"id", "created_at"}
    )

    cursor.execute(
        f"""
        INSERT INTO reports ({", ".join(column_names)})
        VALUES ({placeholders})
        ON CONFLICT (id) DO UPDATE SET {assignments}
        """,
        tuple(insert_data[column] for column in column_names),
    )
    return profile_id


def _public_request(row: Dict[str, Any]) -> Dict[str, Any]:
    data = _json_loads(row.get("data"), {}) or {}
    talep = data.get("talep") if isinstance(data, dict) else None
    vehicle = data.get("vehicle_snapshot", {}) if isinstance(data, dict) else {}
    return {
        "id": row.get("id"),
        "report_id": row.get("id"),
        "status": row.get("status") or row.get("durum"),
        "payment_status": row.get("payment_status") or data.get("payment_status"),
        "plate": row.get("plaka") or vehicle.get("plaka") or (talep or {}).get("aracPlaka"),
        "city": row.get("sehir") or (talep or {}).get("sehir"),
        "district": row.get("ilce") or (talep or {}).get("ilce") or "",
        "firm_name": row.get("ekspertiz_firmasi") or row.get("firma") or (talep or {}).get("expertizFirmasi"),
        "package_name": data.get("expertiz_paketi") or (talep or {}).get("expertizPaketi"),
        "total_tl": float(row.get("toplam_tutar") or (talep or {}).get("toplamTutar") or 0),
        "created_at": row.get("created_at"),
        "updated_at": row.get("updated_at") or row.get("status_updated_at"),
        "vehicle": vehicle,
        "progress": _customer_progress(row, data),
    }


def _customer_progress(row: Dict[str, Any], data: Dict[str, Any]) -> Dict[str, Any]:
    from yerimebak_ai_v5.services import task_progress

    assignment = data.get("assignment") if isinstance(data.get("assignment"), dict) else {}
    if not assignment.get("personnel_id") and data.get("assigned_personel_id"):
        assignment = {**assignment, "personnel_id": data.get("assigned_personel_id"), "status": "assigned"}
    corporate = bool(data.get("firm_id") or data.get("expertiz_package_id"))
    if "corporate_required" in data:
        corporate = bool(data.get("corporate_required"))
    created = row.get("created_at")
    return task_progress.customer_timeline(
        row.get("status") or "draft",
        created.isoformat() if hasattr(created, "isoformat") else created,
        assignment,
        corporate,
        published_at=data.get("published_at"),
        person_name=assignment.get("personnel_name") or data.get("assigned_personel_name") or "",
    )


def _customer_ai(ai: Any) -> Optional[Dict[str, Any]]:
    """Musteriye gosterilen AI analizi: ic metadata ayiklanir, emsal ilanlar sadelesir."""
    ai = _json_loads(ai, None)
    if not isinstance(ai, dict):
        return None
    out = {k: v for k, v in ai.items() if k not in ("source", "official", "temporary", "marketReference")}
    if isinstance(out.get("oneriler"), list):
        out["oneriler"] = [o for o in out["oneriler"] if not (isinstance(o, dict) and o.get("hedef") == "admin")]
    ref = ai.get("marketReference")
    if isinstance(ref, dict):
        out["piyasaReferansi"] = {
            "bulundu": bool(ref.get("found")),
            "emsalSayisi": ref.get("count") or 0,
            "hasarsizEmsalSayisi": ref.get("clean_count") or 0,
            "ortalama": ref.get("market_avg_price") or 0,
            "medyan": ref.get("market_median_price") or 0,
            "min": ref.get("market_min_price") or 0,
            "max": ref.get("market_max_price") or 0,
            "guncelGun": ref.get("recent_days"),
            "emsaller": [
                {k: sample.get(k) for k in ("price", "km", "year", "title", "condition")}
                for sample in (ref.get("samples") or [])[:8]
                if isinstance(sample, dict)
            ],
        }
    return out


def _ai_summary_fields(ai: Any) -> Dict[str, Any]:
    ai = _json_loads(ai, None)
    if not isinstance(ai, dict):
        return {}
    ozet = ai.get("raporOzeti") if isinstance(ai.get("raporOzeti"), dict) else {}
    degerleme = ai.get("ekspertizDegerleme") if isinstance(ai.get("ekspertizDegerleme"), dict) else {}
    skorlar = ai.get("skorlar") if isinstance(ai.get("skorlar"), dict) else {}
    return {
        "market_value": degerleme.get("aiDegeri") or ozet.get("tahminiDeger") or None,
        "clean_market_value": degerleme.get("temizPiyasaDegeri"),
        "value_loss_pct": degerleme.get("toplamDegerKaybiYuzde", ozet.get("degerKaybiYuzde")),
        "fair_price_min": (degerleme.get("adilFiyatAraligi") or {}).get("min"),
        "fair_price_max": (degerleme.get("adilFiyatAraligi") or {}).get("max"),
        "overall_score": skorlar.get("genelPuan"),
        "recommendation": ozet.get("onayRedOnerisi"),
        "ai_comment": ozet.get("ozetAciklama"),
    }


def _public_report(row: Dict[str, Any]) -> Dict[str, Any]:
    data = _json_loads(row.get("data"), {}) or {}
    vehicle = data.get("vehicle_snapshot", {}) if isinstance(data, dict) else {}
    tam_rapor = data.get("tam_rapor") if isinstance(data, dict) else None
    ai_raw = row.get("ai_analiz_detay") or row.get("ai_analysis_result")
    ai_fields = _ai_summary_fields(ai_raw)
    return {
        "id": row.get("id"),
        "status": row.get("status"),
        "plate": row.get("plaka") or vehicle.get("plaka"),
        "firm_name": row.get("ekspertiz_firmasi") or row.get("firma"),
        "published_at": row.get("status_updated_at"),
        "created_at": row.get("created_at"),
        "vehicle": vehicle,
        "summary": {
            "ai_analysis_ready": bool(row.get("ai_analizi_yapildi_mi")),
            "ai_source": _ai_meta_from_row(row)["source"],
            "ai_official": _ai_meta_from_row(row)["official"],
            "market_value": ai_fields.get("market_value"),
            "clean_market_value": ai_fields.get("clean_market_value"),
            "value_loss_pct": ai_fields.get("value_loss_pct"),
            "fair_price_min": ai_fields.get("fair_price_min"),
            "fair_price_max": ai_fields.get("fair_price_max"),
            "overall_score": ai_fields.get("overall_score"),
            "recommendation": ai_fields.get("recommendation"),
            "ai_comment": ai_fields.get("ai_comment"),
            "damage_amount": row.get("hasar_tutar"),
            "total_tl": row.get("toplam_tutar"),
        },
        "ai": _customer_ai(ai_raw),
        "admin_note": data.get("admin_note") if isinstance(data, dict) else None,
        "report": tam_rapor,
    }


def _admin_report(row: Dict[str, Any]) -> Dict[str, Any]:
    public = _public_report(row)
    data = _json_loads(row.get("data"), {}) or {}
    public.update(
        {
            "customer_id": row.get("customer_id") or row.get("user_id"),
            "payment_status": row.get("payment_status"),
            "durum": row.get("durum"),
            "status": row.get("status"),
            "status_updated_at": row.get("status_updated_at"),
            "updated_at": row.get("updated_at"),
            "version_id": row.get("version_id") or 0,
            "data": data,
            "ai_analiz_detay": row.get("ai_analiz_detay"),
            "ai_analysis_result": row.get("ai_analysis_result"),
            "ai_meta": _ai_meta_from_row(row),
            "can_publish": row.get("status") == "pending_admin" and _has_official_central_ai(row),
            # Admin rapor inceleme ekraninin kullandigi ham alanlar
            "user_id": row.get("user_id"),
            "plaka": row.get("plaka"),
            "sehir": row.get("sehir"),
            "ekspertiz_firmasi": row.get("ekspertiz_firmasi") or row.get("firma"),
            "hizmet_bedeli": row.get("hizmet_bedeli"),
            "paket_fiyati": row.get("paket_fiyati"),
            "toplam_tutar": row.get("toplam_tutar"),
            "odendi_mi": row.get("odendi_mi"),
            "ai_analizi_yapildi_mi": bool(row.get("ai_analizi_yapildi_mi")),
            "inspection": data.get("inspection") if isinstance(data, dict) else None,
        }
    )
    return public


def _attach_media(cursor: Any, reports: List[Dict[str, Any]], categories: Optional[List[str]] = None) -> None:
    """Rapor(lar)a imzali URL'li fotograf / kurumsal rapor listesini ekler."""
    from yerimebak_ai_v5.services import media_service

    try:
        media = media_service.list_media(cursor, [str(r.get("id")) for r in reports], categories)
    except Exception:
        # report_media tablosu henuz yoksa (sema acilista kurulur) rapor yine doner
        media = {}
    for report in reports:
        items = media.get(str(report.get("id")), [])
        report["media"] = items
        report["photos"] = [m for m in items if m["category"] == "inspection_photo"]
        report["corporate_reports"] = [m for m in items if m["category"] == "corporate_report"]


def list_customer_requests(user: Dict[str, Any]) -> Dict[str, Any]:
    profile_id = _expertiz_profile_id(user)
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_reports_schema(cursor)
        _ensure_expertiz_requests_schema(cursor)
        cursor.execute(
            """
            SELECT *
            FROM reports
            WHERE user_id = %s
               OR customer_id = %s
               OR data->>'expertiz_request_id' IN (
                    SELECT id FROM expertiz_requests WHERE user_id = %s
               )
            ORDER BY created_at DESC
            LIMIT 100
            """,
            (profile_id, profile_id, str(user.get("id", ""))),
        )
        rows = [_row_to_dict(row) for row in cursor.fetchall()]
        requests = [_public_request(row) for row in rows]

        # Odemesi tamamlanmamis talepler (rapor henuz olusmadi): musteri gorup tekrar odeyebilsin
        cursor.execute(
            """
            SELECT * FROM expertiz_requests
            WHERE user_id = %s AND payment_status IN ('pending', 'failed')
            ORDER BY created_at DESC
            LIMIT 20
            """,
            (str(user.get("id", "")),),
        )
        for row in cursor.fetchall():
            row = _row_to_dict(row)
            snapshot = _json_loads(row.get("data"), {}) or {}
            requests.insert(0, {
                "id": row["id"],
                "report_id": None,
                "order_id": row.get("paytr_oid"),
                "status": "payment_pending" if row.get("payment_status") == "pending" else "payment_failed",
                "payment_status": row.get("payment_status"),
                "plate": row.get("plate"),
                "city": row.get("city"),
                "firm_name": row.get("firm_name"),
                "package_name": row.get("package_name"),
                "total_tl": float(row.get("total_tl") or 0),
                "created_at": row.get("created_at"),
                "updated_at": row.get("updated_at"),
                "vehicle": (snapshot.get("payload") or {}).get("vehicle") or {},
            })
        return {"success": True, "requests": requests}
    finally:
        DatabaseConfig.return_connection(conn)


def list_customer_reports(user: Dict[str, Any]) -> Dict[str, Any]:
    profile_id = _expertiz_profile_id(user)
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_reports_schema(cursor)
        cursor.execute(
            """
            SELECT *
            FROM reports
            WHERE status = 'published'
              AND (user_id = %s OR customer_id = %s)
            ORDER BY status_updated_at DESC, created_at DESC
            LIMIT 100
            """,
            (profile_id, profile_id),
        )
        rows = [_row_to_dict(row) for row in cursor.fetchall()]
        reports = [_public_report(row) for row in rows]
        _attach_media(cursor, reports, ["inspection_photo", "corporate_report"])
        return {"success": True, "reports": reports}
    finally:
        DatabaseConfig.return_connection(conn)


def get_customer_report(report_id: str, user: Dict[str, Any]) -> Dict[str, Any]:
    profile_id = _expertiz_profile_id(user)
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_reports_schema(cursor)
        cursor.execute(
            """
            SELECT *
            FROM reports
            WHERE id::text = %s
              AND status = 'published'
              AND (user_id = %s OR customer_id = %s)
            LIMIT 1
            """,
            (report_id, profile_id, profile_id),
        )
        row = _row_to_dict(cursor.fetchone())
        if not row:
            return {"error": "Rapor bulunamadi veya henuz yayinlanmadi"}
        report = _public_report(row)
        # Musteri sadece yayinlanmis raporun fotograflarini ve kurumsal raporunu gorur
        _attach_media(cursor, [report], ["inspection_photo", "corporate_report"])
        return {"success": True, "report": report}
    finally:
        DatabaseConfig.return_connection(conn)


def list_admin_reports(status: Optional[str] = None, limit: int = 100) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_reports_schema(cursor)
        safe_limit = max(1, min(int(limit or 100), 250))
        if status:
            cursor.execute(
                """
                SELECT *
                FROM reports
                WHERE status = %s
                ORDER BY status_updated_at DESC, created_at DESC
                LIMIT %s
                """,
                (status, safe_limit),
            )
        else:
            cursor.execute(
                """
                SELECT *
                FROM reports
                WHERE status IN ('pending_admin', 'pending_ai', 'published', 'rejected', 'draft')
                ORDER BY status_updated_at DESC, created_at DESC
                LIMIT %s
                """,
                (safe_limit,),
            )
        rows = [_row_to_dict(row) for row in cursor.fetchall()]
        reports = [_admin_report(row) for row in rows]
        _attach_media(cursor, reports)
        return {"success": True, "reports": reports, "total": len(rows)}
    finally:
        DatabaseConfig.return_connection(conn)


def get_admin_report(report_id: str) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_reports_schema(cursor)
        cursor.execute("SELECT * FROM reports WHERE id::text = %s LIMIT 1", (str(report_id),))
        row = _row_to_dict(cursor.fetchone())
        if not row:
            return {"error": "Rapor bulunamadi"}
        report = _admin_report(row)
        _attach_media(cursor, [report])
        return {"success": True, "report": report}
    finally:
        DatabaseConfig.return_connection(conn)


def _write_audit(cursor: Any, action: str, entity_type: str, entity_id: str,
                  admin: Dict[str, Any], metadata: Optional[Dict[str, Any]] = None) -> None:
    # Bos bir veritabaninda da yayinlama/ret calissin diye tablo garanti edilir.
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS audit_logs (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            user_id UUID,
            user_email TEXT,
            user_name TEXT,
            action TEXT NOT NULL,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            metadata JSONB DEFAULT '{}'::jsonb,
            created_at TIMESTAMPTZ DEFAULT NOW()
        )
        """
    )
    cursor.execute(
        """
        INSERT INTO audit_logs (user_email, user_name, action, entity_type, entity_id, metadata)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (
            admin.get("email") or str(admin.get("id", "")),
            admin.get("full_name") or admin.get("email") or "admin",
            action,
            entity_type,
            entity_id,
            Json(metadata or {}),
        ),
    )


def _notify_report_decision(
    cursor: Any, row: Dict[str, Any], data: Dict[str, Any], approved: bool, reason: str = ""
) -> None:
    """Onay: personel + musteri bildirimi. Red: yalnizca personel (musteri gormez)."""
    from yerimebak_ai_v5.services import notification_service

    vehicle = data.get("vehicle_snapshot") if isinstance(data.get("vehicle_snapshot"), dict) else {}
    label = " - ".join(
        p for p in (row.get("plaka") or vehicle.get("plaka") or "",
                    vehicle.get("title") or " ".join(x for x in (vehicle.get("marka"), vehicle.get("model")) if x))
        if p
    ) or "Araç"
    personnel_id = data.get("assigned_personel_id") or (data.get("assignment") or {}).get("personnel_id")
    report_id = str(row.get("id"))
    if approved:
        notification_service.notify_user(
            cursor, personnel_id, "report_approved", "Raporunuz onaylandı",
            f"{label} raporu onaylandı ve müşteriye gönderildi.", report_id,
        )
        notification_service.notify_user(
            cursor, notification_service.customer_user_id(cursor, data), "report_ready",
            "Ekspertiz raporunuz hazır", f"{label} raporunu görüntüleyebilirsiniz.", report_id,
        )
    else:
        notification_service.notify_user(
            cursor, personnel_id, "report_rejected", "Raporunuz düzeltme için geri gönderildi",
            f"{label}: {reason}", report_id,
        )


def publish_admin_report(report_id: str, admin: Dict[str, Any], admin_note: Optional[str] = None) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_reports_schema(cursor)
        cursor.execute("SELECT * FROM reports WHERE id::text = %s LIMIT 1", (str(report_id),))
        row = _row_to_dict(cursor.fetchone())
        if not row:
            return {"error": "Rapor bulunamadi", "http_status": 404}

        if row.get("status") == "published":
            return {"success": True, "report": _admin_report(row), "idempotent": True}

        if row.get("status") != "pending_admin":
            return {"error": "Sadece admin onayi bekleyen rapor yayinlanabilir", "http_status": 400}

        if not _has_official_central_ai(row):
            return {
                "error": "Resmi rapor yayinlamak icin merkezi AI analizi gereklidir",
                "http_status": 400,
            }

        now = datetime.now(timezone.utc).isoformat()
        data = _json_loads(row.get("data"), {}) or {}
        data["published_at"] = now
        data["published_by"] = admin.get("email") or admin.get("id")
        if admin_note and admin_note.strip():
            data["admin_note"] = admin_note.strip()[:2000]

        cursor.execute(
            """
            UPDATE reports
            SET status = 'published',
                durum = 'Tamamlandı',
                status_updated_at = %s,
                updated_at = %s,
                version_id = COALESCE(version_id, 0) + 1,
                data = %s
            WHERE id = %s AND status = 'pending_admin'
            RETURNING *
            """,
            (now, now, Json(data), report_id),
        )
        updated = _row_to_dict(cursor.fetchone())
        if not updated:
            return {"error": "Rapor durumu degisti, islem tekrar denenmeli", "http_status": 409}
        _write_audit(cursor, "REPORT_PUBLISHED", "report", report_id, admin, {
            "old_status": row.get("status"), "new_status": "published",
        })
        _notify_report_decision(cursor, updated, data, approved=True)
        conn.commit()
        return {"success": True, "report": _admin_report(updated)}
    finally:
        DatabaseConfig.return_connection(conn)


def reject_admin_report(report_id: str, reason: str, admin: Dict[str, Any]) -> Dict[str, Any]:
    clean_reason = (reason or "").strip()
    if not clean_reason:
        return {"error": "Red nedeni zorunludur", "http_status": 400}

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_reports_schema(cursor)
        cursor.execute("SELECT * FROM reports WHERE id::text = %s LIMIT 1", (str(report_id),))
        row = _row_to_dict(cursor.fetchone())
        if not row:
            return {"error": "Rapor bulunamadi", "http_status": 404}
        # pending_ai: AI analizi bitmeden de admin hatayi gorup personele geri gonderebilir
        if row.get("status") not in ("pending_ai", "pending_admin"):
            return {"error": "Sadece onay bekleyen rapor reddedilebilir", "http_status": 400}

        now = datetime.now(timezone.utc).isoformat()
        data = _json_loads(row.get("data"), {}) or {}
        data["rejection_reason"] = clean_reason
        data["rejected_at"] = now
        data["rejected_by"] = admin.get("email") or admin.get("id")

        cursor.execute(
            """
            UPDATE reports
            SET status = 'rejected',
                durum = 'Düzeltme Gerekli',
                status_updated_at = %s,
                updated_at = %s,
                version_id = COALESCE(version_id, 0) + 1,
                data = %s
            WHERE id = %s AND status = %s
            RETURNING *
            """,
            (now, now, Json(data), report_id, row.get("status")),
        )
        updated = _row_to_dict(cursor.fetchone())
        if not updated:
            return {"error": "Rapor durumu degisti, islem tekrar denenmeli", "http_status": 409}
        _write_audit(cursor, "REPORT_REJECTED", "report", report_id, admin, {
            "old_status": row.get("status"), "rejection_reason": clean_reason,
        })
        _notify_report_decision(cursor, updated, data, approved=False, reason=clean_reason)
        conn.commit()
        return {"success": True, "report": _admin_report(updated)}
    finally:
        DatabaseConfig.return_connection(conn)


