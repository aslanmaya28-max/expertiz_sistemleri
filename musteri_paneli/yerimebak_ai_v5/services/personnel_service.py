# -*- coding: utf-8 -*-
"""
Admin personel yonetimi servisi.

Tek kaynak: merkezi PostgreSQL `users` tablosu (personel buradan giris yapar).
`profiles` tablosu raporlarla uyumluluk icin senkron tutulur.

Islevler:
- Personel ekleme / guncelleme / pasife alma / aktif etme / sistemden cikarma
- Il + cografi bolge (7 bolge, 81 il) bazli kapsama raporu
- Pasife alinan ya da cikarilan personelin acik gorevleri otomatik olarak
  admin kuyruguna geri dusurulur.
"""
import uuid
from typing import Any, Dict, List, Optional

import psycopg2
from psycopg2.extras import Json

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.core import turkey_regions
from yerimebak_ai_v5.services.auth_service import _hash_password


PERSONNEL_ROLES = ("personel", "field_staff", "staff", "personnel")
OPEN_TASK_STATUSES = ("draft", "rejected")
DONE_TASK_STATUSES = ("pending_ai", "pending_admin", "published")
MIN_PASSWORD_LENGTH = 8

# Geriye donuk uyumluluk (eski testler / importlar)
BIG_CITY_MIN_PERSONNEL = 3
DEFAULT_MIN_PERSONNEL = 1


def _normalize_city(city: Optional[str]) -> str:
    return (city or "").split("/")[0].strip()


def _minimum_target(city: str) -> int:
    return turkey_regions.minimum_target(turkey_regions.province_plate(city))


def _error(message: str, status: int) -> Dict[str, Any]:
    return {"error": message, "http_status": status}


def _ensure_schema() -> None:
    """Semayi surec basina bir kez, ayri bir baglantida commit ederek hazirlar.

    Her istekte ALTER TABLE calistirmak tablo kilitleri aldigi icin (ve okuma
    yollarinda commit edilmedigi icin) kaldirildi.
    """
    from yerimebak_ai_v5.services import account_service, dispatch_service

    dispatch_service.ensure_workflow_schema_once()
    account_service.ensure_schema()


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
        "bolge": "TEXT",
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
        "il_id": "INTEGER",
        "region_id": "INTEGER",
        "created_at": "TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
        # Gorev icin aktif/pasif (hesap aktifliginden ayri): pasif personele gorev atanmaz
        "on_duty": "BOOLEAN DEFAULT TRUE",
        "on_duty_changed_at": "TIMESTAMPTZ",
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


def _is_active_value(value: Any) -> bool:
    if value is None:
        return True
    if isinstance(value, bool):
        return value
    try:
        return int(value) == 1
    except (TypeError, ValueError):
        return str(value).lower() in {"true", "t", "yes", "aktif"}


def _iso_value(value: Any) -> Any:
    return value.isoformat() if hasattr(value, "isoformat") else value


def _public_personnel(row: Dict[str, Any]) -> Dict[str, Any]:
    city_raw = row.get("city") or row.get("il") or ""
    location = turkey_regions.describe_city(city_raw)
    il_id = row.get("il_id") or location["il_id"]
    region_id = row.get("region_id") or location["region_id"] or turkey_regions.region_id_of(il_id)
    active_raw = row.get("active", row.get("is_active", row.get("aktif_mi", True)))
    created_at = row.get("created_at")
    return {
        "id": str(row.get("id") or ""),
        "full_name": row.get("full_name") or row.get("ad_soyad") or "",
        "email": row.get("email") or "",
        "phone": row.get("phone") or row.get("telefon"),
        "role": "field_staff",
        "active": _is_active_value(active_raw),
        "on_duty": row.get("on_duty") is not False,
        "on_duty_changed_at": _iso_value(row.get("on_duty_changed_at")),
        "city": turkey_regions.province_name(il_id) or location["city"] or "",
        "district": row.get("district") or row.get("ilce") or "",
        "il_id": il_id,
        "region_id": region_id,
        "region": turkey_regions.region_name(region_id),
        "expertise": row.get("expertise") or row.get("uzmanlik_alani") or "",
        "must_change_password": bool(row.get("must_change_password", False)),
        "open_task_count": int(row.get("open_task_count") or 0),
        "completed_task_count": int(row.get("completed_task_count") or 0),
        "created_at": created_at.isoformat() if hasattr(created_at, "isoformat") else created_at,
    }


def _resolve_location(city: Any) -> Optional[Dict[str, Any]]:
    plate = turkey_regions.province_plate(city)
    if not plate:
        return None
    region_id = turkey_regions.region_id_of(plate)
    return {
        "il_id": plate,
        "city": turkey_regions.province_name(plate),
        "region_id": region_id,
        "region": turkey_regions.region_name(region_id),
    }


def _profile_id_for_user(user_id: Any) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, f"yerimebak-personnel:{user_id}"))


def _upsert_personnel_profile(cursor: Any, user_id: Any, values: Dict[str, Any]) -> None:
    """profiles tablosunu users ile senkron tutar (e-posta uzerinden eslesir)."""
    cursor.execute("SELECT id FROM profiles WHERE lower(email) = lower(%s) LIMIT 1", (values["email"],))
    existing = cursor.fetchone()
    params = (
        values["full_name"],
        values["email"],
        values.get("phone"),
        values.get("city"),
        values.get("district"),
        values.get("region"),
        values.get("expertise"),
    )
    if existing:
        cursor.execute(
            """
            UPDATE profiles SET
                ad_soyad = %s, email = %s, telefon = %s, rol = 'personel',
                il = %s, ilce = %s, bolge = %s, uzmanlik_alani = %s,
                aktif_mi = TRUE, is_active = TRUE, aktif = TRUE,
                must_change_password = TRUE, updated_at = NOW()
            WHERE id = %s
            """,
            params + (existing["id"],),
        )
    else:
        cursor.execute(
            """
            INSERT INTO profiles (
                ad_soyad, email, telefon, rol, il, ilce, bolge, uzmanlik_alani,
                aktif_mi, is_active, aktif, must_change_password, updated_at, id
            )
            VALUES (%s, %s, %s, 'personel', %s, %s, %s, %s, TRUE, TRUE, TRUE, TRUE, NOW(), %s)
            """,
            params + (_profile_id_for_user(user_id),),
        )


def create_personnel(payload: Dict[str, Any], admin: Dict[str, Any]) -> Dict[str, Any]:
    full_name = str(payload.get("full_name") or "").strip()
    email = str(payload.get("email") or "").strip().lower()
    temporary_password = str(payload.get("temporary_password") or "")
    district = str(payload.get("district") or "").strip()
    phone = str(payload.get("phone") or "").strip() or None
    expertise = str(payload.get("expertise") or "").strip() or None

    if not full_name or not email or not temporary_password or not payload.get("city") or not district:
        return _error("Ad soyad, e-posta, gecici sifre, il ve ilce zorunludur", 400)
    if "@" not in email or "." not in email.split("@")[-1]:
        return _error("Gecerli bir e-posta adresi girin", 400)
    if len(temporary_password) < MIN_PASSWORD_LENGTH:
        return _error(f"Gecici sifre en az {MIN_PASSWORD_LENGTH} karakter olmali", 400)

    location = _resolve_location(payload.get("city"))
    if not location:
        return _error("Gecersiz il. Lutfen listeden bir il secin", 400)

    _ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM users WHERE lower(email) = lower(%s) LIMIT 1", (email,))
        if cursor.fetchone():
            return _error("Bu e-posta ile kayitli bir kullanici zaten var", 409)
        if phone:
            cursor.execute("SELECT id FROM users WHERE phone = %s LIMIT 1", (phone,))
            if cursor.fetchone():
                return _error("Bu telefon numarasi baska bir kullanicida kayitli", 409)

        cursor.execute(
            """
            INSERT INTO users (
                email, password, full_name, phone, credits, role,
                is_active, must_change_password, city, district, expertise, il_id, region_id,
                email_verified, welcome_credits_granted
            )
            VALUES (%s, %s, %s, %s, 0, 'personel', 1, TRUE, %s, %s, %s, %s, %s, TRUE, TRUE)
            RETURNING id, created_at
            """,
            (
                email,
                _hash_password(temporary_password),
                full_name,
                phone,
                location["city"],
                district,
                expertise,
                location["il_id"],
                location["region_id"],
            ),
        )
        user_row = cursor.fetchone()
        personnel_id = str(user_row["id"])
        _upsert_personnel_profile(
            cursor,
            personnel_id,
            {
                "full_name": full_name,
                "email": email,
                "phone": phone,
                "city": location["city"],
                "district": district,
                "region": location["region"],
                "expertise": expertise,
            },
        )
        _write_audit(
            cursor,
            "PERSONNEL_CREATED",
            personnel_id,
            admin,
            {"email": email, "city": location["city"], "district": district, "region": location["region"]},
        )
        conn.commit()
        return {
            "success": True,
            "personnel": _public_personnel(
                {
                    "id": personnel_id,
                    "full_name": full_name,
                    "email": email,
                    "phone": phone,
                    "is_active": 1,
                    "city": location["city"],
                    "district": district,
                    "il_id": location["il_id"],
                    "region_id": location["region_id"],
                    "expertise": expertise,
                    "must_change_password": True,
                    "created_at": user_row["created_at"],
                }
            ),
        }
    except psycopg2.IntegrityError:
        conn.rollback()
        return _error("E-posta veya telefon baska bir kullanicida kayitli", 409)
    finally:
        DatabaseConfig.return_connection(conn)


def _personnel_rows(cursor: Any, where_extra: str = "", params: tuple = ()) -> List[Dict[str, Any]]:
    cursor.execute(
        f"""
        SELECT
            u.id, u.full_name, u.email, u.phone, u.role, u.is_active, u.city, u.district,
            u.expertise, u.il_id, u.region_id, u.must_change_password, u.created_at,
            u.on_duty, u.on_duty_changed_at,
            COALESCE(t.open_count, 0) AS open_task_count,
            COALESCE(t.done_count, 0) AS completed_task_count
        FROM users u
        LEFT JOIN (
            SELECT
                data->>'assigned_personel_id' AS personnel_id,
                COUNT(*) FILTER (WHERE status IN ('draft', 'rejected')) AS open_count,
                COUNT(*) FILTER (WHERE status IN ('pending_ai', 'pending_admin', 'published')) AS done_count
            FROM reports
            WHERE COALESCE(data->>'assigned_personel_id', '') <> ''
            GROUP BY data->>'assigned_personel_id'
        ) t ON t.personnel_id = u.id::text
        WHERE u.role IN %s {where_extra}
        ORDER BY u.full_name ASC NULLS LAST, u.id ASC
        """,
        (PERSONNEL_ROLES,) + params,
    )
    return [dict(row) for row in cursor.fetchall()]


def list_personnel(
    active: Optional[bool] = None,
    region_id: Optional[int] = None,
    il_id: Optional[int] = None,
) -> Dict[str, Any]:
    _ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        personnel = [_public_personnel(row) for row in _personnel_rows(cursor)]
        if active is not None:
            personnel = [p for p in personnel if p["active"] == active]
        if region_id:
            personnel = [p for p in personnel if p["region_id"] == region_id]
        if il_id:
            personnel = [p for p in personnel if p["il_id"] == il_id]
        return {"success": True, "personnel": personnel}
    finally:
        DatabaseConfig.return_connection(conn)


def _get_personnel(cursor: Any, personnel_id: str) -> Optional[Dict[str, Any]]:
    cursor.execute(
        """
        SELECT id, email, full_name, phone, role, is_active, city, district, expertise, il_id, region_id,
               on_duty, on_duty_changed_at
        FROM users
        WHERE (id::text = %s OR lower(email) = lower(%s))
          AND role IN %s
        LIMIT 1
        """,
        (str(personnel_id), str(personnel_id), PERSONNEL_ROLES),
    )
    row = cursor.fetchone()
    return dict(row) if row else None


def update_personnel(personnel_id: str, payload: Dict[str, Any], admin: Dict[str, Any]) -> Dict[str, Any]:
    allowed = {"full_name", "phone", "city", "district", "expertise"}
    updates = {
        key: value.strip() if isinstance(value, str) else value
        for key, value in payload.items()
        if key in allowed and value is not None
    }
    if not updates:
        return _error("Guncellenecek alan bulunamadi", 400)
    if updates.get("full_name") == "":
        return _error("Ad soyad bos olamaz", 400)
    if updates.get("city") == "" or updates.get("district") == "":
        return _error("Il ve ilce bos olamaz", 400)
    if "phone" in updates and updates["phone"] == "":
        updates["phone"] = None

    location = None
    if "city" in updates:
        location = _resolve_location(updates["city"])
        if not location:
            return _error("Gecersiz il. Lutfen listeden bir il secin", 400)
        updates["city"] = location["city"]
        updates["il_id"] = location["il_id"]
        updates["region_id"] = location["region_id"]

    _ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        personnel = _get_personnel(cursor, personnel_id)
        if not personnel:
            return _error("Personel bulunamadi", 404)
        user_id = personnel["id"]
        email = personnel.get("email")

        if updates.get("phone"):
            cursor.execute("SELECT id FROM users WHERE phone = %s AND id <> %s LIMIT 1", (updates["phone"], user_id))
            if cursor.fetchone():
                return _error("Bu telefon numarasi baska bir kullanicida kayitli", 409)

        assignments = ", ".join(f"{key} = %s" for key in updates)
        cursor.execute(
            f"UPDATE users SET {assignments} WHERE id = %s",
            tuple(updates.values()) + (user_id,),
        )

        profile_map = {
            "full_name": "ad_soyad",
            "phone": "telefon",
            "city": "il",
            "district": "ilce",
            "expertise": "uzmanlik_alani",
        }
        profile_updates = {profile_map[k]: v for k, v in updates.items() if k in profile_map}
        if location:
            profile_updates["bolge"] = location["region"]
        if profile_updates:
            profile_assignments = ", ".join(f"{column} = %s" for column in profile_updates)
            cursor.execute(
                f"UPDATE profiles SET {profile_assignments}, updated_at = NOW() WHERE lower(email) = lower(%s)",
                tuple(profile_updates.values()) + (email,),
            )
        _write_audit(cursor, "PERSONNEL_UPDATED", str(user_id), admin, {"email": email, "updates": updates})
        conn.commit()
        return {"success": True, "personnel": _public_personnel({**personnel, **updates})}
    except psycopg2.IntegrityError:
        conn.rollback()
        return _error("Telefon numarasi baska bir kullanicida kayitli", 409)
    finally:
        DatabaseConfig.return_connection(conn)


def deactivate_personnel(personnel_id: str, reason: str, admin: Dict[str, Any]) -> Dict[str, Any]:
    from yerimebak_ai_v5.services import dispatch_service

    clean_reason = (reason or "").strip()
    if not clean_reason:
        return _error("Pasife alma nedeni zorunludur", 400)

    _ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        personnel = _get_personnel(cursor, personnel_id)
        if not personnel:
            return _error("Personel bulunamadi", 404)
        user_id = personnel["id"]
        email = personnel.get("email")
        cursor.execute("UPDATE users SET is_active = 0 WHERE id = %s", (user_id,))
        cursor.execute(
            "UPDATE profiles SET aktif_mi = FALSE, is_active = FALSE, aktif = FALSE, updated_at = NOW() WHERE lower(email) = lower(%s)",
            (email,),
        )
        released = dispatch_service.release_personnel_tasks(
            cursor, str(user_id), admin, f"Personel pasife alindi: {clean_reason}"
        )
        _write_audit(
            cursor,
            "PERSONNEL_DEACTIVATED",
            str(user_id),
            admin,
            {"reason": clean_reason, "email": email, "released_tasks": released},
        )
        conn.commit()
        personnel["is_active"] = 0
        return {
            "success": True,
            "personnel": _public_personnel(personnel),
            "released_task_ids": released,
            "released_task_count": len(released),
        }
    finally:
        DatabaseConfig.return_connection(conn)


def activate_personnel(personnel_id: str, admin: Dict[str, Any]) -> Dict[str, Any]:
    _ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        personnel = _get_personnel(cursor, personnel_id)
        if not personnel:
            return _error("Personel bulunamadi", 404)
        user_id = personnel["id"]
        email = personnel.get("email")
        cursor.execute("UPDATE users SET is_active = 1 WHERE id = %s", (user_id,))
        cursor.execute(
            "UPDATE profiles SET aktif_mi = TRUE, is_active = TRUE, aktif = TRUE, updated_at = NOW() WHERE lower(email) = lower(%s)",
            (email,),
        )
        _write_audit(cursor, "PERSONNEL_ACTIVATED", str(user_id), admin, {"email": email})
        conn.commit()
        personnel["is_active"] = 1
        return {"success": True, "personnel": _public_personnel(personnel)}
    finally:
        DatabaseConfig.return_connection(conn)


def delete_personnel(personnel_id: str, admin: Dict[str, Any], reason: Optional[str] = None) -> Dict[str, Any]:
    """Personeli sistemden cikarir. Acik gorevleri admin kuyruguna geri doner.

    Tamamlanmis raporlar silinmez; raporlarda personelin adi saklandigi icin
    gecmis kayitlar okunabilir kalir.
    """
    from yerimebak_ai_v5.services import dispatch_service

    _ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        personnel = _get_personnel(cursor, personnel_id)
        if not personnel:
            return _error("Personel bulunamadi", 404)
        user_id = personnel["id"]
        email = personnel.get("email")
        note = (reason or "").strip() or "Personel sistemden cikarildi"
        released = dispatch_service.release_personnel_tasks(cursor, str(user_id), admin, note)
        cursor.execute("DELETE FROM profiles WHERE lower(email) = lower(%s) AND rol IN %s", (email, PERSONNEL_ROLES))
        cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
        _write_audit(
            cursor,
            "PERSONNEL_REMOVED",
            str(user_id),
            admin,
            {
                "email": email,
                "full_name": personnel.get("full_name"),
                "reason": note,
                "released_tasks": released,
            },
        )
        conn.commit()
        return {
            "success": True,
            "personnel_id": str(user_id),
            "released_task_ids": released,
            "released_task_count": len(released),
        }
    finally:
        DatabaseConfig.return_connection(conn)


def reset_personnel_password(personnel_id: str, new_password: str, admin: Dict[str, Any]) -> Dict[str, Any]:
    if len(new_password or "") < MIN_PASSWORD_LENGTH:
        return _error(f"Yeni sifre en az {MIN_PASSWORD_LENGTH} karakter olmali", 400)
    _ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        personnel = _get_personnel(cursor, personnel_id)
        if not personnel:
            return _error("Personel bulunamadi", 404)
        user_id = personnel["id"]
        email = personnel.get("email")
        cursor.execute(
            "UPDATE users SET password = %s, must_change_password = TRUE WHERE id = %s",
            (_hash_password(new_password), user_id),
        )
        cursor.execute(
            "UPDATE profiles SET must_change_password = TRUE, updated_at = NOW() WHERE lower(email) = lower(%s)",
            (email,),
        )
        _write_audit(cursor, "PERSONNEL_PASSWORD_RESET", str(user_id), admin, {"email": email})
        conn.commit()
        return {"success": True, "personnel_id": str(user_id), "must_change_password": True}
    finally:
        DatabaseConfig.return_connection(conn)


def set_duty(personnel_id: str, on_duty: bool, actor: Dict[str, Any], by_admin: bool = False) -> Dict[str, Any]:
    """Personel gorev durumunu (aktif/pasif) degistirir; admin bildirimi olusur.

    Acik gorevler pasife geciste personelde kalir: personel onlari bitirebilir,
    yeni gorev atanmaz.
    """
    from yerimebak_ai_v5.services import notification_service

    _ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        personnel = _get_personnel(cursor, personnel_id)
        if not personnel:
            return _error("Personel bulunamadi", 404)
        if not _is_active_value(personnel.get("is_active")):
            return _error("Hesabi pasif personelin gorev durumu degistirilemez", 409)
        on_duty = bool(on_duty)
        if (personnel.get("on_duty") is not False) != on_duty:
            cursor.execute(
                "UPDATE users SET on_duty = %s, on_duty_changed_at = NOW() WHERE id = %s",
                (on_duty, personnel["id"]),
            )
            name = personnel.get("full_name") or personnel.get("email")
            state = "aktif" if on_duty else "pasif"
            _write_audit(cursor, "PERSONNEL_DUTY_CHANGED", str(personnel["id"]), actor,
                         {"on_duty": on_duty, "by_admin": by_admin})
            if by_admin:
                notification_service.notify_user(
                    cursor, personnel["id"], "duty_changed",
                    f"Görev durumunuz {state} yapıldı", "Değişikliği admin yaptı.",
                )
            else:
                notification_service.notify_admins(
                    cursor, "duty_changed", f"{name} görev için {state}",
                    f"{personnel.get('city') or ''} / {personnel.get('district') or ''}".strip(" /"),
                )
            conn.commit()
        return {"success": True, "personnel": _public_personnel(_get_personnel(cursor, personnel_id))}
    finally:
        DatabaseConfig.return_connection(conn)


def get_me(user: Dict[str, Any]) -> Dict[str, Any]:
    _ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        rows = _personnel_rows(cursor, "AND u.id::text = %s", (str(user.get("id") or ""),))
        if not rows:
            return _error("Personel kaydi bulunamadi", 404)
        return {"success": True, "personnel": _public_personnel(rows[0])}
    finally:
        DatabaseConfig.return_connection(conn)


def get_personnel_coverage() -> Dict[str, Any]:
    """Il ve 7 cografi bolge bazli personel kapsama raporu."""
    from yerimebak_ai_v5.services import dispatch_service

    _ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        personnel = [_public_personnel(row) for row in _personnel_rows(cursor)]
        open_requests = dispatch_service.open_request_locations(cursor)
    finally:
        DatabaseConfig.return_connection(conn)

    provinces: Dict[int, Dict[str, Any]] = {}
    for plate, (name, region_id) in turkey_regions.PROVINCES.items():
        provinces[plate] = {
            "il_id": plate,
            "city": name,
            "region_id": region_id,
            "region": turkey_regions.region_name(region_id),
            "active_count": 0,
            "passive_count": 0,
            "open_request_count": 0,
            "unassigned_request_count": 0,
            "minimum_target": turkey_regions.minimum_target(plate),
        }
    unknown = {"active_count": 0, "passive_count": 0, "open_request_count": 0, "unassigned_request_count": 0}

    for person in personnel:
        bucket = provinces.get(person["il_id"]) if person["il_id"] else None
        target = bucket if bucket is not None else unknown
        target["active_count" if person["active"] else "passive_count"] += 1

    for request in open_requests:
        bucket = provinces.get(request["il_id"]) if request["il_id"] else None
        target = bucket if bucket is not None else unknown
        target["open_request_count"] += 1
        if not request["assigned"]:
            target["unassigned_request_count"] += 1

    def _status(item: Dict[str, Any]) -> str:
        if item["active_count"] == 0:
            return "critical" if item["open_request_count"] else "missing"
        if item["active_count"] < item["minimum_target"]:
            return "understaffed"
        return "ok"

    for item in provinces.values():
        item["status"] = _status(item)

    missing = sorted(
        (p for p in provinces.values() if p["active_count"] == 0),
        key=lambda p: (-p["open_request_count"], p["city"]),
    )
    understaffed = sorted(
        (p for p in provinces.values() if 0 < p["active_count"] < p["minimum_target"]),
        key=lambda p: p["city"],
    )

    regions = []
    for region_id, region_name in turkey_regions.REGIONS.items():
        items = [p for p in provinces.values() if p["region_id"] == region_id]
        covered = [p for p in items if p["active_count"] > 0]
        regions.append(
            {
                "region_id": region_id,
                "region": region_name,
                "province_count": len(items),
                "covered_province_count": len(covered),
                "coverage_pct": round(100 * len(covered) / len(items)) if items else 0,
                "active_personnel": sum(p["active_count"] for p in items),
                "passive_personnel": sum(p["passive_count"] for p in items),
                "open_request_count": sum(p["open_request_count"] for p in items),
                "unassigned_request_count": sum(p["unassigned_request_count"] for p in items),
                "critical_cities": [p["city"] for p in items if p["status"] == "critical"],
                "provinces": sorted(items, key=lambda p: p["city"]),
            }
        )

    # Tablo icin sadece hareketli illeri dondur (personeli veya talebi olanlar)
    cities = {
        p["city"]: p
        for p in sorted(provinces.values(), key=lambda p: p["city"])
        if p["active_count"] or p["passive_count"] or p["open_request_count"]
    }
    if any(unknown.values()):
        cities["Belirtilmedi"] = {**unknown, "minimum_target": 0, "status": "unknown", "region": ""}

    return {
        "success": True,
        "summary": {
            "total_personnel": len(personnel),
            "active_personnel": sum(1 for p in personnel if p["active"]),
            "passive_personnel": sum(1 for p in personnel if not p["active"]),
            "covered_city_count": sum(1 for p in provinces.values() if p["active_count"] > 0),
            "missing_city_count": len(missing),
            "understaffed_city_count": len(understaffed),
            "critical_city_count": sum(1 for p in provinces.values() if p["status"] == "critical"),
            "open_request_count": len(open_requests),
            "unassigned_request_count": sum(1 for r in open_requests if not r["assigned"]),
        },
        "cities": cities,
        "regions": regions,
        "missing_cities": [p["city"] for p in missing],
        "critical_cities": [p["city"] for p in missing if p["open_request_count"]],
        "understaffed_cities": [p["city"] for p in understaffed],
    }
