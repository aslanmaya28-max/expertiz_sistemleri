# -*- coding: utf-8 -*-
"""
Admin personnel management service.
"""
import uuid
from typing import Any, Dict, Optional

from psycopg2.extras import Json

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.services.auth_service import _hash_password


BIG_CITY_MIN_PERSONNEL = 3
DEFAULT_MIN_PERSONNEL = 1
BIG_CITIES = {
    "istanbul",
    "ankara",
    "izmir",
    "bursa",
    "antalya",
    "konya",
    "adana",
    "gaziantep",
    "kocaeli",
}


def _normalize_city(city: Optional[str]) -> str:
    return (city or "").split("/")[0].strip()


def _city_key(city: str) -> str:
    return _normalize_city(city).lower()


def _minimum_target(city: str) -> int:
    return BIG_CITY_MIN_PERSONNEL if _city_key(city) in BIG_CITIES else DEFAULT_MIN_PERSONNEL


def _ensure_personnel_schema(cursor: Any) -> None:
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS profiles (
            id UUID PRIMARY KEY,
            ad_soyad TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            telefon TEXT,
            rol TEXT DEFAULT 'musteri',
            bolge TEXT,
            il TEXT,
            ilce TEXT,
            uzmanlik_alani TEXT,
            aktif_mi BOOLEAN DEFAULT TRUE,
            must_change_password BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            updated_at TIMESTAMPTZ DEFAULT NOW()
        )
        """
    )
    profile_columns = {
        "is_active": "BOOLEAN DEFAULT TRUE",
        "aktif": "BOOLEAN DEFAULT TRUE",
        "il": "TEXT",
        "ilce": "TEXT",
        "uzmanlik_alani": "TEXT",
        "must_change_password": "BOOLEAN DEFAULT FALSE",
    }
    for column, column_type in profile_columns.items():
        cursor.execute(f"ALTER TABLE profiles ADD COLUMN IF NOT EXISTS {column} {column_type}")

    user_columns = {
        "must_change_password": "BOOLEAN DEFAULT FALSE",
        "city": "TEXT",
        "district": "TEXT",
        "expertise": "TEXT",
    }
    for column, column_type in user_columns.items():
        cursor.execute(f"ALTER TABLE users ADD COLUMN IF NOT EXISTS {column} {column_type}")

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


def _write_audit(cursor: Any, action: str, personnel_id: str, admin: Dict[str, Any], metadata: Dict[str, Any]) -> None:
    cursor.execute(
        """
        INSERT INTO audit_logs (user_email, user_name, action, entity_type, entity_id, metadata)
        VALUES (%s, %s, %s, %s, %s, %s)
        """,
        (
            admin.get("email") or str(admin.get("id", "")),
            admin.get("full_name") or admin.get("email") or "admin",
            action,
            "personnel",
            personnel_id,
            Json(metadata),
        ),
    )


def _public_personnel(row: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "id": str(row.get("id") or ""),
        "full_name": row.get("full_name") or row.get("ad_soyad") or "",
        "email": row.get("email") or "",
        "phone": row.get("phone") or row.get("telefon"),
        "role": row.get("role") or row.get("rol") or "personel",
        "active": bool(row.get("active", row.get("is_active", row.get("aktif_mi", True)))),
        "city": row.get("city") or row.get("il") or "",
        "district": row.get("district") or row.get("ilce") or "",
        "expertise": row.get("expertise") or row.get("uzmanlik_alani") or "",
        "must_change_password": bool(row.get("must_change_password", False)),
    }


def create_personnel(payload: Dict[str, Any], admin: Dict[str, Any]) -> Dict[str, Any]:
    full_name = str(payload.get("full_name") or "").strip()
    email = str(payload.get("email") or "").strip().lower()
    temporary_password = str(payload.get("temporary_password") or "")
    city = _normalize_city(payload.get("city"))
    district = str(payload.get("district") or "").strip()
    if not full_name or not email or not temporary_password or not city or not district:
        return {"error": "Ad soyad, e-posta, gecici sifre, il ve ilce zorunludur", "http_status": 400}

    personnel_id = str(uuid.uuid4())
    hashed_password = _hash_password(temporary_password)
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_personnel_schema(cursor)
        cursor.execute("SELECT id FROM users WHERE lower(email) = lower(%s) LIMIT 1", (email,))
        if cursor.fetchone():
            return {"error": "Bu e-posta ile personel zaten var", "http_status": 409}

        # 🔒 DÜZELTİLDİ: users.id SERIAL olduğu için UUID eklenemez.
        # users tablosu SERIAL kullanıyor, UUID yerine NULL gönderip otomatik atanmasını sağlıyoruz.
        cursor.execute(
            """
            INSERT INTO users (
                email, password, full_name, phone, api_key, credits, tier, role,
                is_active, must_change_password, city, district, expertise
            )
            VALUES (%s, %s, %s, %s, %s, 0, 'staff', 'personel', 1, TRUE, %s, %s, %s)
            RETURNING id
            """,
            (
                email,
                hashed_password,
                full_name,
                payload.get("phone"),
                f"yk-{uuid.uuid4().hex[:24]}",
                city,
                district,
                payload.get("expertise"),
            ),
        )
        # 🔒 DÜZELTİLDİ: Otomatik atanan SERIAL id'yi al
        user_row = cursor.fetchone()
        if user_row:
            personnel_id = str(user_row['id'])
        cursor.execute(
            """
            INSERT INTO profiles (
                id, ad_soyad, email, telefon, rol, il, ilce, uzmanlik_alani,
                aktif_mi, is_active, aktif, must_change_password, updated_at
            )
            VALUES (%s, %s, %s, %s, 'personel', %s, %s, %s, TRUE, TRUE, TRUE, TRUE, NOW())
            ON CONFLICT (id) DO UPDATE SET
                ad_soyad = EXCLUDED.ad_soyad,
                email = EXCLUDED.email,
                telefon = EXCLUDED.telefon,
                rol = 'personel',
                il = EXCLUDED.il,
                ilce = EXCLUDED.ilce,
                uzmanlik_alani = EXCLUDED.uzmanlik_alani,
                aktif_mi = TRUE,
                is_active = TRUE,
                aktif = TRUE,
                must_change_password = TRUE,
                updated_at = NOW()
            """,
            (
                personnel_id,
                full_name,
                email,
                payload.get("phone"),
                city,
                district,
                payload.get("expertise"),
            ),
        )
        _write_audit(cursor, "PERSONNEL_CREATED", personnel_id, admin, {"email": email, "city": city, "district": district})
        conn.commit()
        return {
            "success": True,
            "personnel": _public_personnel(
                {
                    "id": personnel_id,
                    "full_name": full_name,
                    "email": email,
                    "phone": payload.get("phone"),
                    "role": "personel",
                    "active": True,
                    "city": city,
                    "district": district,
                    "expertise": payload.get("expertise"),
                    "must_change_password": True,
                }
            ),
        }
    finally:
        DatabaseConfig.return_connection(conn)


def list_personnel(active: Optional[bool] = None) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_personnel_schema(cursor)
        params = []
        where = "WHERE COALESCE(u.role, p.rol) IN ('personel', 'field_staff', 'staff')"
        if active is not None:
            where += " AND COALESCE(u.is_active = 1, p.aktif_mi, TRUE) = %s"
            params.append(active)
        cursor.execute(
            f"""
            SELECT
                COALESCE(u.id::text, p.id::text) AS id,
                COALESCE(u.full_name, p.ad_soyad) AS full_name,
                COALESCE(u.email, p.email) AS email,
                COALESCE(u.phone, p.telefon) AS phone,
                COALESCE(u.role, p.rol) AS role,
                COALESCE(u.is_active = 1, p.aktif_mi, TRUE) AS active,
                COALESCE(u.city, p.il) AS city,
                COALESCE(u.district, p.ilce) AS district,
                COALESCE(u.expertise, p.uzmanlik_alani) AS expertise,
                COALESCE(u.must_change_password, p.must_change_password, FALSE) AS must_change_password
            FROM profiles p
            FULL OUTER JOIN users u ON lower(u.email) = lower(p.email)
            {where}
            ORDER BY full_name ASC
            """,
            tuple(params),
        )
        return {"success": True, "personnel": [_public_personnel(dict(row)) for row in cursor.fetchall()]}
    finally:
        DatabaseConfig.return_connection(conn)


def _get_personnel(cursor: Any, personnel_id: str) -> Optional[Dict[str, Any]]:
    cursor.execute(
        """
        SELECT id, email, full_name, role, is_active
        FROM users
        WHERE id::text = %s OR lower(email) = lower(%s)
        LIMIT 1
        """,
        (personnel_id, personnel_id),
    )
    row = cursor.fetchone()
    return dict(row) if row else None


def deactivate_personnel(personnel_id: str, reason: str, admin: Dict[str, Any]) -> Dict[str, Any]:
    clean_reason = (reason or "").strip()
    if not clean_reason:
        return {"error": "Pasife alma nedeni zorunludur", "http_status": 400}

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_personnel_schema(cursor)
        personnel = _get_personnel(cursor, personnel_id)
        if not personnel:
            return {"error": "Personel bulunamadi", "http_status": 404}
        email = personnel.get("email")
        cursor.execute("UPDATE users SET is_active = 0 WHERE id::text = %s OR lower(email) = lower(%s)", (personnel_id, email))
        cursor.execute("UPDATE profiles SET aktif_mi = FALSE, is_active = FALSE, aktif = FALSE, updated_at = NOW() WHERE id::text = %s OR lower(email) = lower(%s)", (personnel_id, email))
        _write_audit(cursor, "PERSONNEL_DEACTIVATED", personnel_id, admin, {"reason": clean_reason, "email": email})
        conn.commit()
        personnel["active"] = False
        return {"success": True, "personnel": _public_personnel(personnel)}
    finally:
        DatabaseConfig.return_connection(conn)


def update_personnel(personnel_id: str, payload: Dict[str, Any], admin: Dict[str, Any]) -> Dict[str, Any]:
    allowed = {
        "full_name": ("full_name", "ad_soyad"),
        "phone": ("phone", "telefon"),
        "city": ("city", "il"),
        "district": ("district", "ilce"),
        "expertise": ("expertise", "uzmanlik_alani"),
    }
    updates = {
        key: value.strip() if isinstance(value, str) else value
        for key, value in payload.items()
        if key in allowed and value is not None
    }
    if "city" in updates:
        updates["city"] = _normalize_city(updates["city"])
    if not updates:
        return {"error": "Guncellenecek alan bulunamadi", "http_status": 400}
    if updates.get("city") == "" or updates.get("district") == "":
        return {"error": "Il ve ilce bos olamaz", "http_status": 400}

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_personnel_schema(cursor)
        personnel = _get_personnel(cursor, personnel_id)
        if not personnel:
            return {"error": "Personel bulunamadi", "http_status": 404}
        email = personnel.get("email")

        user_assignments = ", ".join(f"{allowed[key][0]} = %s" for key in updates)
        profile_assignments = ", ".join(f"{allowed[key][1]} = %s" for key in updates)
        values = tuple(updates[key] for key in updates)
        cursor.execute(
            f"UPDATE users SET {user_assignments} WHERE id::text = %s OR lower(email) = lower(%s)",
            values + (personnel_id, email),
        )
        cursor.execute(
            f"UPDATE profiles SET {profile_assignments}, updated_at = NOW() WHERE id::text = %s OR lower(email) = lower(%s)",
            values + (personnel_id, email),
        )
        _write_audit(cursor, "PERSONNEL_UPDATED", personnel_id, admin, {"email": email, "updates": updates})
        conn.commit()
        public = _public_personnel({**personnel, **updates})
        return {"success": True, "personnel": public}
    finally:
        DatabaseConfig.return_connection(conn)


def activate_personnel(personnel_id: str, admin: Dict[str, Any]) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_personnel_schema(cursor)
        personnel = _get_personnel(cursor, personnel_id)
        if not personnel:
            return {"error": "Personel bulunamadi", "http_status": 404}
        email = personnel.get("email")
        cursor.execute("UPDATE users SET is_active = 1 WHERE id::text = %s OR lower(email) = lower(%s)", (personnel_id, email))
        cursor.execute("UPDATE profiles SET aktif_mi = TRUE, is_active = TRUE, aktif = TRUE, updated_at = NOW() WHERE id::text = %s OR lower(email) = lower(%s)", (personnel_id, email))
        _write_audit(cursor, "PERSONNEL_ACTIVATED", personnel_id, admin, {"email": email})
        conn.commit()
        personnel["active"] = True
        return {"success": True, "personnel": _public_personnel(personnel)}
    finally:
        DatabaseConfig.return_connection(conn)


def reset_personnel_password(personnel_id: str, new_password: str, admin: Dict[str, Any]) -> Dict[str, Any]:
    if len(new_password or "") < 8:
        return {"error": "Yeni sifre en az 8 karakter olmali", "http_status": 400}
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_personnel_schema(cursor)
        personnel = _get_personnel(cursor, personnel_id)
        if not personnel:
            return {"error": "Personel bulunamadi", "http_status": 404}
        hashed_password = _hash_password(new_password)
        email = personnel.get("email")
        cursor.execute(
            "UPDATE users SET password = %s, must_change_password = TRUE WHERE id::text = %s OR lower(email) = lower(%s)",
            (hashed_password, personnel_id, email),
        )
        cursor.execute(
            "UPDATE profiles SET must_change_password = TRUE, updated_at = NOW() WHERE id::text = %s OR lower(email) = lower(%s)",
            (personnel_id, email),
        )
        _write_audit(cursor, "PERSONNEL_PASSWORD_RESET", personnel_id, admin, {"email": email})
        conn.commit()
        return {"success": True, "personnel_id": personnel_id, "must_change_password": True}
    finally:
        DatabaseConfig.return_connection(conn)


def get_personnel_coverage() -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_personnel_schema(cursor)
        cursor.execute(
            """
            SELECT city, active_count, passive_count, open_request_count
            FROM (
                SELECT
                    COALESCE(NULLIF(city, ''), 'Belirtilmedi') AS city,
                    SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) AS active_count,
                    SUM(CASE WHEN is_active = 1 THEN 0 ELSE 1 END) AS passive_count,
                    0 AS open_request_count
                FROM users
                WHERE role IN ('personel', 'field_staff', 'staff')
                GROUP BY COALESCE(NULLIF(city, ''), 'Belirtilmedi')
                UNION ALL
                SELECT
                    COALESCE(NULLIF(sehir, ''), 'Belirtilmedi') AS city,
                    0 AS active_count,
                    0 AS passive_count,
                    COUNT(*) AS open_request_count
                FROM reports
                WHERE status IN ('draft', 'pending_ai', 'pending_admin')
                GROUP BY COALESCE(NULLIF(sehir, ''), 'Belirtilmedi')
            ) coverage
            ORDER BY city
            """
        )
        cities: Dict[str, Dict[str, int]] = {}
        for raw in cursor.fetchall():
            row = dict(raw)
            city = _normalize_city(row.get("city")) or "Belirtilmedi"
            bucket = cities.setdefault(
                city,
                {
                    "active_count": 0,
                    "passive_count": 0,
                    "open_request_count": 0,
                    "minimum_target": _minimum_target(city),
                },
            )
            bucket["active_count"] += int(row.get("active_count") or 0)
            bucket["passive_count"] += int(row.get("passive_count") or 0)
            bucket["open_request_count"] += int(row.get("open_request_count") or 0)

        missing = sorted([city for city, item in cities.items() if item["active_count"] == 0])
        understaffed = sorted(
            [city for city, item in cities.items() if 0 < item["active_count"] < item["minimum_target"]]
        )
        return {
            "success": True,
            "summary": {
                "total_personnel": sum(item["active_count"] + item["passive_count"] for item in cities.values()),
                "active_personnel": sum(item["active_count"] for item in cities.values()),
                "passive_personnel": sum(item["passive_count"] for item in cities.values()),
                "covered_city_count": len([item for item in cities.values() if item["active_count"] > 0]),
                "missing_city_count": len(missing),
                "understaffed_city_count": len(understaffed),
            },
            "cities": cities,
            "missing_cities": missing,
            "understaffed_cities": understaffed,
        }
    finally:
        DatabaseConfig.return_connection(conn)
