# -*- coding: utf-8 -*-
"""
Fiyatlandirma: admin'den yonetilen hizmet bedeli, arac enflasyonu ve
kurumsal ekspertiz firma/paket katalogu.

Degerler veritabaninda tutulur; kod degismeden admin panelinden guncellenir.
"""
import os
import re
import threading
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from psycopg2.extras import Json

from yerimebak_ai_v5.core.database_config import DatabaseConfig

DEFAULT_SERVICE_FEE_TL = float(os.getenv("YERIMEBAK_SERVICE_FEE_TL", "6000.0"))
VAT_RATE = float(os.getenv("VAT_RATE", "0.20"))

SETTING_SERVICE_FEE = "service_fee_tl"
SETTING_INFLATION = "vehicle_inflation"

_schema_lock = threading.Lock()
_schema_ready = False

# Baslangic katalogu: firmalarin kendi fiyat sayfalarindan / basin kaynaklarindan
# (Ekim 2026 aramasi). Fiyatlar degisken oldugu icin "verified=False" ile gelir;
# admin dogrulayip guncellemelidir. Kalan firmalar admin panelinden eklenir.
SEED_FIRMS: List[Dict[str, Any]] = [
    {
        "id": "otorapor", "name": "Otorapor", "source_url": "https://otorapor.com/paketler",
        "packages": [
            ("Kaporta/Boya Paketi", 4900, ["Kaporta", "Boya"]),
            ("Bronz Paket", 5500, ["Kaporta/Boya", "Motor", "Temel Mekanik"]),
            ("Gold Paket", 9000, ["Kaporta/Boya", "Motor", "Mekanik", "Yol Testi"]),
            ("Full Paket", 13000, ["Tam Kapsamli Ekspertiz"]),
            ("Luxury Paket", 22000, ["Luks / Premium Araclar Icin Tam Kapsam"]),
        ],
    },
    {
        "id": "pilot-garage", "name": "Pilot Garage", "source_url": "https://pilotgarage.com/en/packets",
        "packages": [
            ("Eko Class", 7500, ["Kaporta/Boya", "Motor"]),
            ("Bold Class", 9000, ["Kaporta/Boya", "Motor", "Mekanik"]),
            ("Business", 11000, ["Kaporta/Boya", "Motor", "Mekanik", "Dyno"]),
            ("First Class", 12500, ["Genis Kapsamli Ekspertiz"]),
            ("Black Box", 17500, ["En Kapsamli Paket"]),
        ],
    },
    {
        "id": "rs-oto", "name": "RS Oto Ekspertiz", "source_url": "https://rsotoekspertiz.com/oto-ekspertiz-fiyatlari/",
        "packages": [
            ("Kaporta Boya Paketi", 3950, ["Kaporta", "Boya"]),
            ("Temel Paket", 4950, ["Kaporta/Boya", "Motor"]),
            ("Premium Paket", 8900, ["Tam Kapsamli Ekspertiz"]),
        ],
    },
    {
        "id": "garantili-arabam", "name": "Garantili Arabam",
        "source_url": "https://www.bekaroglu.com.tr/blog/2026-turkiye-oto-ekspertiz-firmalari-fiyatlari-guncel-paket-ve-ucret-rehberi",
        "packages": [
            ("Bronz (2WD)", 4100, ["Kaporta/Boya", "Motor"]),
            ("Gold", 5300, ["Kaporta/Boya", "Motor", "Mekanik"]),
            ("Platinum", 8300, ["Tam Kapsamli Ekspertiz"]),
        ],
    },
    {
        "id": "auto-king", "name": "Auto King",
        "source_url": "https://www.bekaroglu.com.tr/blog/2026-turkiye-oto-ekspertiz-firmalari-fiyatlari-guncel-paket-ve-ucret-rehberi",
        "packages": [
            ("Eko Paket", 5200, ["Kaporta/Boya", "Motor"]),
        ],
    },
]


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _slug(text: str) -> str:
    table = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")
    slug = re.sub(r"[^a-z0-9]+", "-", str(text or "").translate(table).lower()).strip("-")
    return slug or uuid.uuid4().hex[:8]


def _error(message: str, status: int = 400) -> Dict[str, Any]:
    return {"error": message, "http_status": status}


def ensure_schema(force: bool = False) -> None:
    global _schema_ready
    if _schema_ready and not force:
        return
    with _schema_lock:
        if _schema_ready and not force:
            return
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS system_settings (
                    key TEXT PRIMARY KEY,
                    value JSONB NOT NULL,
                    updated_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_by TEXT
                )
                """
            )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS expertiz_firms (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    active BOOLEAN NOT NULL DEFAULT TRUE,
                    sort_order INTEGER NOT NULL DEFAULT 0,
                    source_url TEXT,
                    verified BOOLEAN NOT NULL DEFAULT FALSE,
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                )
                """
            )
            cursor.execute(
                """
                CREATE TABLE IF NOT EXISTS expertiz_packages (
                    id TEXT PRIMARY KEY,
                    firm_id TEXT NOT NULL REFERENCES expertiz_firms(id) ON DELETE CASCADE,
                    name TEXT NOT NULL,
                    price_tl NUMERIC(12, 2) NOT NULL CHECK (price_tl >= 0),
                    features JSONB NOT NULL DEFAULT '[]'::jsonb,
                    active BOOLEAN NOT NULL DEFAULT TRUE,
                    sort_order INTEGER NOT NULL DEFAULT 0,
                    created_at TIMESTAMPTZ DEFAULT NOW(),
                    updated_at TIMESTAMPTZ DEFAULT NOW()
                )
                """
            )
            cursor.execute("CREATE INDEX IF NOT EXISTS idx_expertiz_packages_firm ON expertiz_packages(firm_id)")
            cursor.execute(
                "INSERT INTO system_settings (key, value) VALUES (%s, %s) ON CONFLICT (key) DO NOTHING",
                (SETTING_SERVICE_FEE, Json({"amount_tl": DEFAULT_SERVICE_FEE_TL})),
            )
            cursor.execute("SELECT COUNT(*) AS n FROM expertiz_firms")
            if int(dict(cursor.fetchone())["n"]) == 0:
                for f_index, firm in enumerate(SEED_FIRMS):
                    cursor.execute(
                        "INSERT INTO expertiz_firms (id, name, sort_order, source_url, verified) VALUES (%s, %s, %s, %s, FALSE)",
                        (firm["id"], firm["name"], f_index, firm["source_url"]),
                    )
                    for p_index, (name, price, features) in enumerate(firm["packages"]):
                        cursor.execute(
                            "INSERT INTO expertiz_packages (id, firm_id, name, price_tl, features, sort_order) VALUES (%s, %s, %s, %s, %s, %s)",
                            (f"{firm['id']}--{_slug(name)}", firm["id"], name, price, Json(features), p_index),
                        )
            conn.commit()
            _schema_ready = True
        finally:
            DatabaseConfig.return_connection(conn)


# ---------------------------------------------------------------------------
# Ayarlar
# ---------------------------------------------------------------------------

def _get_setting(cursor: Any, key: str) -> Optional[Dict[str, Any]]:
    cursor.execute("SELECT value, updated_at, updated_by FROM system_settings WHERE key = %s", (key,))
    row = cursor.fetchone()
    if not row:
        return None
    row = dict(row)
    value = row["value"] if isinstance(row["value"], dict) else {}
    value["_updated_at"] = row["updated_at"].isoformat() if row.get("updated_at") else None
    value["_updated_by"] = row.get("updated_by")
    return value


def get_pricing_settings() -> Dict[str, Any]:
    ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        fee = _get_setting(cursor, SETTING_SERVICE_FEE) or {}
        inflation = _get_setting(cursor, SETTING_INFLATION)
        return {
            "success": True,
            "service_fee_tl": float(fee.get("amount_tl", DEFAULT_SERVICE_FEE_TL)),
            "vat_rate": VAT_RATE,
            "vehicle_inflation": None if not inflation else {
                "monthly_pct": float(inflation.get("monthly_pct", 0)),
                "note": inflation.get("note") or "",
                "effective_date": inflation.get("effective_date"),
                "updated_at": inflation.get("_updated_at"),
                "updated_by": inflation.get("_updated_by"),
            },
        }
    finally:
        DatabaseConfig.return_connection(conn)


def get_service_fee_tl() -> float:
    return get_pricing_settings()["service_fee_tl"]


def update_pricing_settings(payload: Dict[str, Any], admin: Dict[str, Any]) -> Dict[str, Any]:
    ensure_schema()
    who = str(admin.get("email") or admin.get("id") or "admin")
    fee = payload.get("service_fee_tl")
    inflation = payload.get("vehicle_inflation_monthly_pct")
    if fee is None and inflation is None:
        return _error("Guncellenecek alan yok")
    if fee is not None:
        try:
            fee = float(fee)
        except (TypeError, ValueError):
            return _error("Hizmet bedeli sayi olmali")
        if not 0 <= fee <= 1_000_000:
            return _error("Hizmet bedeli 0 - 1.000.000 TL araliginda olmali")
    if inflation is not None:
        try:
            inflation = float(inflation)
        except (TypeError, ValueError):
            return _error("Enflasyon orani sayi olmali")
        if not -20 <= inflation <= 30:
            return _error("Aylik arac enflasyonu -%20 ile %30 arasinda olmali")

    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        upsert = """
            INSERT INTO system_settings (key, value, updated_at, updated_by) VALUES (%s, %s, NOW(), %s)
            ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW(), updated_by = EXCLUDED.updated_by
        """
        if fee is not None:
            cursor.execute(upsert, (SETTING_SERVICE_FEE, Json({"amount_tl": fee}), who))
        if inflation is not None:
            cursor.execute(upsert, (SETTING_INFLATION, Json({
                "monthly_pct": inflation,
                "note": str(payload.get("inflation_note") or "")[:300],
                "effective_date": str(payload.get("inflation_effective_date") or datetime.now().date().isoformat())[:10],
            }), who))
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    return get_pricing_settings()


# ---------------------------------------------------------------------------
# Firma / paket katalogu
# ---------------------------------------------------------------------------

def _public_package(row: Dict[str, Any]) -> Dict[str, Any]:
    features = row.get("features")
    return {
        "id": row["id"],
        "name": row["name"],
        "price": float(row["price_tl"]),
        "features": features if isinstance(features, list) else [],
        "active": bool(row.get("active", True)),
        "sort_order": int(row.get("sort_order") or 0),
    }


def list_firms(include_inactive: bool = False) -> List[Dict[str, Any]]:
    ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            f"""
            SELECT * FROM expertiz_firms
            {"" if include_inactive else "WHERE active"}
            ORDER BY sort_order, name
            """
        )
        firms = [dict(r) for r in cursor.fetchall()]
        cursor.execute(
            f"""
            SELECT * FROM expertiz_packages
            {"" if include_inactive else "WHERE active"}
            ORDER BY sort_order, price_tl
            """
        )
        packages: Dict[str, List[Dict[str, Any]]] = {}
        for row in cursor.fetchall():
            row = dict(row)
            packages.setdefault(row["firm_id"], []).append(_public_package(row))
        result = []
        for firm in firms:
            firm_packages = packages.get(firm["id"], [])
            if not include_inactive and not firm_packages:
                continue  # paketi olmayan firma musteriye gosterilmez
            result.append({
                "id": firm["id"],
                "name": firm["name"],
                "active": bool(firm["active"]),
                "sort_order": int(firm["sort_order"] or 0),
                "source_url": firm.get("source_url"),
                "verified": bool(firm.get("verified")),
                "updated_at": firm["updated_at"].isoformat() if firm.get("updated_at") else None,
                "packages": firm_packages,
            })
        return result
    finally:
        DatabaseConfig.return_connection(conn)


def find_package(firm_id: str, package_id: str) -> Optional[Dict[str, Any]]:
    """Aktif firma + aktif paket; fiyat o anki katalogdan okunur."""
    ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT f.id AS firm_id, f.name AS firm_name, p.*
            FROM expertiz_packages p JOIN expertiz_firms f ON f.id = p.firm_id
            WHERE f.id = %s AND p.id = %s AND f.active AND p.active
            """,
            (firm_id, package_id),
        )
        row = cursor.fetchone()
        if not row:
            return None
        row = dict(row)
        return {"firm": {"id": row["firm_id"], "name": row["firm_name"]}, "package": _public_package(row)}
    finally:
        DatabaseConfig.return_connection(conn)


def _clean_features(value: Any) -> List[str]:
    if isinstance(value, str):
        value = [v for v in re.split(r"[,\n]", value)]
    if not isinstance(value, list):
        return []
    return [str(v).strip()[:80] for v in value if str(v).strip()][:20]


def save_firm(payload: Dict[str, Any], firm_id: Optional[str] = None) -> Dict[str, Any]:
    ensure_schema()
    name = str(payload.get("name") or "").strip()
    if not firm_id and not name:
        return _error("Firma adi zorunlu")
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        if firm_id:
            cursor.execute("SELECT id FROM expertiz_firms WHERE id = %s", (firm_id,))
            if not cursor.fetchone():
                return _error("Firma bulunamadi", 404)
            fields, values = [], []
            for key in ("name", "active", "sort_order", "source_url", "verified"):
                if key in payload:
                    fields.append(f"{key} = %s")
                    value = payload[key]
                    if key == "name":
                        value = str(value or "").strip()
                        if not value:
                            return _error("Firma adi bos olamaz")
                    values.append(value)
            if fields:
                cursor.execute(
                    f"UPDATE expertiz_firms SET {', '.join(fields)}, updated_at = NOW() WHERE id = %s",
                    (*values, firm_id),
                )
        else:
            firm_id = _slug(name)
            cursor.execute("SELECT 1 FROM expertiz_firms WHERE id = %s", (firm_id,))
            if cursor.fetchone():
                firm_id = f"{firm_id}-{uuid.uuid4().hex[:4]}"
            cursor.execute("SELECT COALESCE(MAX(sort_order), -1) + 1 AS n FROM expertiz_firms")
            sort_order = int(dict(cursor.fetchone())["n"])
            cursor.execute(
                "INSERT INTO expertiz_firms (id, name, sort_order, source_url, verified, active) VALUES (%s, %s, %s, %s, %s, %s)",
                (firm_id, name, payload.get("sort_order", sort_order), payload.get("source_url"),
                 bool(payload.get("verified", False)), bool(payload.get("active", True))),
            )
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    firm = next((f for f in list_firms(include_inactive=True) if f["id"] == firm_id), None)
    return {"success": True, "firm": firm}


def delete_firm(firm_id: str) -> Dict[str, Any]:
    """Gecmis talepler firma adini sakladigi icin firma silinmez, pasife alinir."""
    return save_firm({"active": False}, firm_id)


def save_package(firm_id: str, payload: Dict[str, Any], package_id: Optional[str] = None) -> Dict[str, Any]:
    ensure_schema()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT id FROM expertiz_firms WHERE id = %s", (firm_id,))
        if not cursor.fetchone():
            return _error("Firma bulunamadi", 404)

        price = payload.get("price")
        if price is not None:
            try:
                price = round(float(price), 2)
            except (TypeError, ValueError):
                return _error("Paket fiyati sayi olmali")
            if not 0 < price <= 1_000_000:
                return _error("Paket fiyati 0 - 1.000.000 TL araliginda olmali")

        if package_id:
            cursor.execute("SELECT id FROM expertiz_packages WHERE id = %s AND firm_id = %s", (package_id, firm_id))
            if not cursor.fetchone():
                return _error("Paket bulunamadi", 404)
            fields, values = [], []
            if "name" in payload:
                name = str(payload["name"] or "").strip()
                if not name:
                    return _error("Paket adi bos olamaz")
                fields.append("name = %s"); values.append(name)
            if price is not None:
                fields.append("price_tl = %s"); values.append(price)
            if "features" in payload:
                fields.append("features = %s"); values.append(Json(_clean_features(payload["features"])))
            for key in ("active", "sort_order"):
                if key in payload:
                    fields.append(f"{key} = %s"); values.append(payload[key])
            if fields:
                cursor.execute(
                    f"UPDATE expertiz_packages SET {', '.join(fields)}, updated_at = NOW() WHERE id = %s",
                    (*values, package_id),
                )
        else:
            name = str(payload.get("name") or "").strip()
            if not name or price is None:
                return _error("Paket adi ve fiyati zorunlu")
            package_id = f"{firm_id}--{_slug(name)}"
            cursor.execute("SELECT 1 FROM expertiz_packages WHERE id = %s", (package_id,))
            if cursor.fetchone():
                package_id = f"{package_id}-{uuid.uuid4().hex[:4]}"
            cursor.execute("SELECT COALESCE(MAX(sort_order), -1) + 1 AS n FROM expertiz_packages WHERE firm_id = %s", (firm_id,))
            sort_order = int(dict(cursor.fetchone())["n"])
            cursor.execute(
                "INSERT INTO expertiz_packages (id, firm_id, name, price_tl, features, sort_order, active) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (package_id, firm_id, name, price, Json(_clean_features(payload.get("features"))),
                 payload.get("sort_order", sort_order), bool(payload.get("active", True))),
            )
        # Fiyat degisikligi firmanin "son guncelleme" tarihine yansir
        cursor.execute("UPDATE expertiz_firms SET updated_at = NOW() WHERE id = %s", (firm_id,))
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    firm = next((f for f in list_firms(include_inactive=True) if f["id"] == firm_id), None)
    package = next((p for p in (firm or {}).get("packages", []) if p["id"] == package_id), None)
    return {"success": True, "package": package}


def delete_package(firm_id: str, package_id: str) -> Dict[str, Any]:
    return save_package(firm_id, {"active": False}, package_id)
