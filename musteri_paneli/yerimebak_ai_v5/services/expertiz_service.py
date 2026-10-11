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


# 🔒 GÜVENLİK: Sabit değerler .env'den alinir
YERIMEBAK_SERVICE_FEE_TL = float(os.getenv("YERIMEBAK_SERVICE_FEE_TL", "6500.0"))
VAT_RATE = float(os.getenv("VAT_RATE", "0.20"))

EXPERTIZ_FIRMS: List[Dict[str, Any]] = [
    {
        "id": "FIRM_001",
        "name": "Pilot Garage",
        "packages": [
            {"id": "PG_ECO", "name": "Ekonomik Paket", "price": 3500.0, "features": ["Kaporta/Boya", "Motor Mekanik", "Dyno Test"]},
            {"id": "PG_STD", "name": "Standart Paket", "price": 4500.0, "features": ["Kaporta/Boya", "Motor Mekanik", "Dyno Test", "Fren Testi", "Suspansiyon Testi"]},
            {"id": "PG_FULL", "name": "Full Paket", "price": 6000.0, "features": ["Kaporta/Boya", "Motor Mekanik", "Dyno Test", "Fren Testi", "Suspansiyon Testi", "OBD Beyin Kontrol", "Airbag Kontrol"]},
        ],
    },
    {
        "id": "FIRM_002",
        "name": "Otorapor",
        "packages": [
            {"id": "OR_BRONZE", "name": "Bronz Paket", "price": 3250.0, "features": ["Kaporta", "Motor", "Sanziman"]},
            {"id": "OR_SILVER", "name": "Gumus Paket", "price": 4250.0, "features": ["Kaporta", "Motor", "Sanziman", "Alt Kontrol", "Yanal Kayma"]},
            {"id": "OR_GOLD", "name": "Altin Paket", "price": 5750.0, "features": ["Full Mekanik", "Kaporta Boya", "OBD", "Airbag", "Conta Kacak Testi"]},
        ],
    },
    {
        "id": "FIRM_003",
        "name": "Tarcanlar Ekspertiz",
        "packages": [
            {"id": "TR_STD", "name": "Standart Kontrol", "price": 4000.0, "features": ["Motor", "Kaporta", "Sase Kontrol"]},
            {"id": "TR_PRO", "name": "Profesyonel Kontrol", "price": 5500.0, "features": ["Motor", "Kaporta", "Sase", "Airbag", "Kilometre Teyit"]},
            {"id": "TR_ELITE", "name": "Elit Kontrol", "price": 7000.0, "features": ["Full Detayli Ekspertiz + Yol Testi"]},
        ],
    },
    {
        "id": "FIRM_004",
        "name": "Dynomoss",
        "packages": [
            {"id": "DM_1", "name": "Eko", "price": 3000.0, "features": ["Dyno", "Boya"]},
            {"id": "DM_2", "name": "Orta", "price": 4000.0, "features": ["Dyno", "Boya", "Mekanik"]},
            {"id": "DM_3", "name": "Full", "price": 5000.0, "features": ["Full Paket"]},
        ],
    },
    {
        "id": "FIRM_005",
        "name": "Umran Oto Ekspertiz",
        "packages": [
            {"id": "UM_1", "name": "Baz Paket", "price": 3200.0, "features": ["Kaporta", "Motor"]},
            {"id": "UM_2", "name": "Klasik Paket", "price": 4200.0, "features": ["Kaporta", "Motor", "Alt Takim"]},
            {"id": "UM_3", "name": "Premium Paket", "price": 5500.0, "features": ["Full + Conta Testi"]},
        ],
    },
    {
        "id": "FIRM_006",
        "name": "Eksperix",
        "packages": [
            {"id": "EX_1", "name": "Eko", "price": 2900.0, "features": ["Boya", "Motor"]},
            {"id": "EX_2", "name": "Full", "price": 4500.0, "features": ["Boya", "Motor", "Mekanik"]},
            {"id": "EX_3", "name": "VIP", "price": 5900.0, "features": ["Full + Airbag"]},
        ],
    },
    {
        "id": "FIRM_007",
        "name": "Computest",
        "packages": [
            {"id": "CT_1", "name": "Mobil", "price": 3100.0, "features": ["Temel Kontrol"]},
            {"id": "CT_2", "name": "Gold", "price": 4100.0, "features": ["Standart Kontrol"]},
            {"id": "CT_3", "name": "Platinum", "price": 5200.0, "features": ["Gelismis Kontrol"]},
        ],
    },
    {
        "id": "FIRM_008",
        "name": "Garantili Arabam",
        "packages": [
            {"id": "GA_1", "name": "Paket 1", "price": 3300.0, "features": ["Kaporta"]},
            {"id": "GA_2", "name": "Paket 2", "price": 4400.0, "features": ["Kaporta + Motor"]},
            {"id": "GA_3", "name": "Paket 3", "price": 5600.0, "features": ["Full"]},
        ],
    },
    {
        "id": "FIRM_009",
        "name": "Dynobil",
        "packages": [
            {"id": "DB_1", "name": "BASIC", "price": 3000.0, "features": ["Motor %"]},
            {"id": "DB_2", "name": "PLUS", "price": 4000.0, "features": ["Motor % + Kaporta"]},
            {"id": "DB_3", "name": "PREMIUM", "price": 5300.0, "features": ["Full Check-up"]},
        ],
    },
    {
        "id": "FIRM_010",
        "name": "Auto King Ekspertiz",
        "packages": [
            {"id": "AK_1", "name": "King Eko", "price": 3750.0, "features": ["Temel"]},
            {"id": "AK_2", "name": "King Star", "price": 4950.0, "features": ["Orta"]},
            {"id": "AK_3", "name": "King Gold", "price": 6500.0, "features": ["Gelismis"]},
        ],
    },
]


def get_expertiz_packages() -> Dict[str, Any]:
    return {
        "service_fee_tl": YERIMEBAK_SERVICE_FEE_TL,
        "vat_rate": VAT_RATE,
        "firms": EXPERTIZ_FIRMS,
    }


def find_package(firm_id: str, package_id: str) -> Optional[Dict[str, Any]]:
    for firm in EXPERTIZ_FIRMS:
        if firm["id"] != firm_id:
            continue
        for package in firm["packages"]:
            if package["id"] == package_id:
                return {"firm": firm, "package": package}
    return None


def calculate_total(package_price: float) -> Dict[str, float]:
    subtotal = YERIMEBAK_SERVICE_FEE_TL + package_price
    vat = subtotal * VAT_RATE
    return {
        "service_fee_tl": YERIMEBAK_SERVICE_FEE_TL,
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
) -> str:
    _ensure_reports_schema(cursor)

    profile_id = _expertiz_profile_id(user)
    _upsert_profile(cursor, profile_id, user)

    listing = _get_listing_snapshot(cursor, payload.get("listing_id"))
    data = {
        "source": "yerimebak_sistemleri",
        "expertiz_request_id": request_id,
        "payment_status": "paid_simulation",
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
        "ekspertiz_firmasi": selected["firm"]["name"],
        "secilen_paket": selected["package"]["id"],
        "hizmet_bedeli": totals["service_fee_tl"],
        "paket_fiyati": totals["package_price_tl"],
        "toplam_tutar": totals["total_tl"],
        "hasar_tutar": 0.0,
        "odendi_mi": True,
        "durum": "Islemde",
        "status": "draft",
        "payment_status": "paid_simulation",
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
        "firm_name": row.get("ekspertiz_firmasi") or row.get("firma") or (talep or {}).get("expertizFirmasi"),
        "package_name": data.get("expertiz_paketi") or (talep or {}).get("expertizPaketi"),
        "total_tl": float(row.get("toplam_tutar") or (talep or {}).get("toplamTutar") or 0),
        "created_at": row.get("created_at"),
        "updated_at": row.get("updated_at") or row.get("status_updated_at"),
        "vehicle": vehicle,
    }


def _public_report(row: Dict[str, Any]) -> Dict[str, Any]:
    data = _json_loads(row.get("data"), {}) or {}
    vehicle = data.get("vehicle_snapshot", {}) if isinstance(data, dict) else {}
    tam_rapor = data.get("tam_rapor") if isinstance(data, dict) else None
    ai_summary = row.get("ai_analiz_detay") or row.get("ai_analysis_result")
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
            "market_value": row.get("ai_piyasa_degeri"),
            "ai_comment": row.get("ai_yorumu"),
            "damage_amount": row.get("hasar_tutar"),
            "total_tl": row.get("toplam_tutar"),
        },
        "ai": ai_summary,
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
        }
    )
    return public


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
        return {"success": True, "requests": [_public_request(row) for row in rows]}
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
        return {"success": True, "reports": [_public_report(row) for row in rows]}
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
            WHERE id = %s
              AND status = 'published'
              AND (user_id = %s OR customer_id = %s)
            LIMIT 1
            """,
            (report_id, profile_id, profile_id),
        )
        row = _row_to_dict(cursor.fetchone())
        if not row:
            return {"error": "Rapor bulunamadi veya henuz yayinlanmadi"}
        return {"success": True, "report": _public_report(row)}
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
        return {"success": True, "reports": [_admin_report(row) for row in rows], "total": len(rows)}
    finally:
        DatabaseConfig.return_connection(conn)


def get_admin_report(report_id: str) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_reports_schema(cursor)
        cursor.execute("SELECT * FROM reports WHERE id = %s LIMIT 1", (report_id,))
        row = _row_to_dict(cursor.fetchone())
        if not row:
            return {"error": "Rapor bulunamadi"}
        return {"success": True, "report": _admin_report(row)}
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


def publish_admin_report(report_id: str, admin: Dict[str, Any]) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_reports_schema(cursor)
        cursor.execute("SELECT * FROM reports WHERE id = %s LIMIT 1", (report_id,))
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

        cursor.execute(
            """
            UPDATE reports
            SET status = 'published',
                durum = 'Tamamlandi',
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
        cursor.execute("SELECT * FROM reports WHERE id = %s LIMIT 1", (report_id,))
        row = _row_to_dict(cursor.fetchone())
        if not row:
            return {"error": "Rapor bulunamadi", "http_status": 404}
        if row.get("status") != "pending_admin":
            return {"error": "Sadece admin onayi bekleyen rapor reddedilebilir", "http_status": 400}

        now = datetime.now(timezone.utc).isoformat()
        data = _json_loads(row.get("data"), {}) or {}
        data["rejection_reason"] = clean_reason
        data["rejected_at"] = now
        data["rejected_by"] = admin.get("email") or admin.get("id")

        cursor.execute(
            """
            UPDATE reports
            SET status = 'rejected',
                durum = 'Iptal',
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
        _write_audit(cursor, "REPORT_REJECTED", "report", report_id, admin, {
            "old_status": row.get("status"), "rejection_reason": clean_reason,
        })
        conn.commit()
        return {"success": True, "report": _admin_report(updated)}
    finally:
        DatabaseConfig.return_connection(conn)


def create_expertiz_request(payload: Dict[str, Any], user: Dict[str, Any]) -> Dict[str, Any]:
    selected = find_package(payload["firm_id"], payload["package_id"])
    if not selected:
        return {"error": "Gecersiz ekspertiz firma/paket secimi"}

    request_id = str(uuid.uuid4())
    totals = calculate_total(float(selected["package"]["price"]))
    now = datetime.now(timezone.utc).isoformat()

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        p = "%s"
        _ensure_expertiz_requests_schema(cursor)
        cursor.execute(
            f"""
            INSERT INTO expertiz_requests (
                id, user_id, user_email, listing_id, listing_url, plate, city,
                firm_id, firm_name, package_id, package_name, service_fee_tl,
                package_price_tl, vat_tl, total_tl, status, payment_status,
                data, created_at, updated_at
            ) VALUES ({p}, {p}, {p}, {p}, {p}, {p}, {p}, {p}, {p}, {p}, {p}, {p}, {p}, {p}, {p}, {p}, {p}, {p}, {p}, {p})
            """,
            (
                request_id,
                str(user.get("id", "")),
                user.get("email", ""),
                str(payload.get("listing_id") or ""),
                payload.get("listing_url") or "",
                payload.get("plate") or "",
                payload.get("city") or "",
                payload["firm_id"],
                selected["firm"]["name"],
                payload["package_id"],
                selected["package"]["name"],
                totals["service_fee_tl"],
                totals["package_price_tl"],
                totals["vat_tl"],
                totals["total_tl"],
                "Islemde",
                "paid_simulation",
                json.dumps(payload, ensure_ascii=False),
                now,
                now,
            ),
        )
        profile_id = _upsert_report_from_request(
            cursor=cursor,
            request_id=request_id,
            payload=payload,
            user=user,
            selected=selected,
            totals=totals,
            now=now,
        )
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)

    return {
        "success": True,
        "request_id": request_id,
        "report_id": request_id,
        "customer_profile_id": profile_id,
        "status": "Islemde",
        "payment_status": "paid_simulation",
        "firm": {"id": selected["firm"]["id"], "name": selected["firm"]["name"]},
        "package": selected["package"],
        **totals,
    }

