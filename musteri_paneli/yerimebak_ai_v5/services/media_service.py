# -*- coding: utf-8 -*-
"""
Ekspertiz medya servisi (hasar fotograflari ve kurumsal ekspertiz raporlari).

- Dosyalar varsayılan olarak MEDIA_ROOT altında, MEDIA_STORAGE=supabase ise
  gizli Supabase Storage bucket'ında saklanır.
- Kayitlar `report_media` tablosunda tutulur.
- Dosyalara imzali (HMAC) ve sureli URL ile erisilir; boylece hem Flutter
  (Image.network) hem web (<img src>) ek baslik gondermeden goruntuleyebilir.
  URL sadece yetkili kullaniciya (admin / atanan personel / yayinlanmis
  raporun sahibi musteri) API yanitinda verilir.
"""
import hashlib
import hmac
import logging
import os
import time
import uuid
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Tuple
from urllib.parse import quote

import httpx

from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)

CATEGORIES = {"inspection_photo", "corporate_report", "document"}
SECTIONS = {"arac", "dis", "ic", "boya_kaporta", "kurumsal", "genel"}
MAX_UPLOAD_BYTES = int(float(os.getenv("MEDIA_MAX_MB", "15")) * 1024 * 1024)
URL_TTL_SECONDS = int(os.getenv("MEDIA_URL_TTL_SECONDS", str(24 * 3600)))

_EXTENSIONS = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/heic": ".heic",
    "application/pdf": ".pdf",
}


def media_root() -> Path:
    configured = os.getenv("MEDIA_ROOT")
    if configured:
        return Path(configured)
    # .../musteri_paneli/yerimebak_ai_v5/services -> .../musteri_paneli/data/media
    return Path(__file__).resolve().parents[2] / "data" / "media"


class _MediaStorageError(Exception):
    """Depolama hataları API'ye anahtar veya sağlayıcı yanıtı taşımamalı."""


def _storage_mode() -> str:
    mode = (os.getenv("MEDIA_STORAGE") or "local").strip().lower()
    if mode not in {"local", "supabase"}:
        logger.error("Geçersiz medya depolama modu")
        raise _MediaStorageError
    return mode


def _supabase_object(
    method: str, report_id: str, file_name: str,
    content: Optional[bytes] = None, content_type: Optional[str] = None,
) -> bytes:
    base_url = (os.getenv("SUPABASE_URL") or "").strip().rstrip("/")
    key = (os.getenv("SUPABASE_SERVICE_ROLE_KEY") or "").strip()
    bucket = (os.getenv("SUPABASE_MEDIA_BUCKET") or "report-media").strip()
    if not base_url or not key or not bucket:
        logger.error("Supabase medya depolama ayarları eksik")
        raise _MediaStorageError
    object_path = "/".join(quote(str(part), safe="") for part in (bucket, report_id, file_name))
    headers = {"Authorization": f"Bearer {key}", "apikey": key}
    if method == "POST":
        headers.update({"Content-Type": content_type, "x-upsert": "false"})
    try:
        with httpx.Client(timeout=30.0) as client:
            response = client.request(
                method, f"{base_url}/storage/v1/object/{object_path}",
                headers=headers, content=content,
            )
            response.raise_for_status()
            return response.content
    except httpx.HTTPStatusError as exc:
        logger.warning("Supabase medya isteği başarısız: işlem=%s durum=%s", method, exc.response.status_code)
        raise _MediaStorageError from None
    except (httpx.RequestError, httpx.InvalidURL):
        logger.warning("Supabase medya bağlantı hatası: işlem=%s", method)
        raise _MediaStorageError from None


def _secret() -> bytes:
    secret = os.getenv("MEDIA_SIGNING_KEY") or os.getenv("SECRET_KEY") or ""
    if not secret:
        raise RuntimeError("SECRET_KEY tanimli degil; medya URL'leri imzalanamaz")
    return secret.encode("utf-8")


def ensure_media_schema(cursor: Any) -> None:
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS report_media (
            id UUID PRIMARY KEY,
            report_id TEXT NOT NULL,
            category TEXT NOT NULL,
            section TEXT,
            item_key TEXT,
            item_label TEXT,
            note TEXT,
            file_name TEXT NOT NULL,
            original_name TEXT,
            content_type TEXT NOT NULL,
            size_bytes INTEGER NOT NULL,
            sha256 TEXT NOT NULL,
            uploaded_by TEXT,
            uploaded_by_name TEXT,
            created_at TIMESTAMPTZ DEFAULT NOW(),
            deleted_at TIMESTAMPTZ
        )
        """
    )
    cursor.execute("CREATE INDEX IF NOT EXISTS idx_report_media_report ON report_media(report_id)")


def detect_content_type(head: bytes) -> Optional[str]:
    """Dosya turunu istemcinin bildirdigi tipe degil, icerige gore belirler."""
    if head.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if head.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
        return "image/webp"
    if head.startswith(b"%PDF-"):
        return "application/pdf"
    if head[4:8] == b"ftyp" and head[8:12] in (b"heic", b"heix", b"heif", b"mif1", b"msf1", b"hevc"):
        return "image/heic"
    return None


def sign(media_id: str, expires_at: int) -> str:
    message = f"{media_id}:{expires_at}".encode("utf-8")
    return hmac.new(_secret(), message, hashlib.sha256).hexdigest()[:40]


def verify_signature(media_id: str, expires_at: int, signature: str) -> bool:
    if not signature or expires_at < int(time.time()):
        return False
    return hmac.compare_digest(sign(media_id, expires_at), signature)


def signed_url(media_id: str, ttl: int = URL_TTL_SECONDS) -> str:
    expires_at = int(time.time()) + ttl
    return f"/api/v1/expertiz/media/{media_id}?exp={expires_at}&sig={sign(media_id, expires_at)}"


def public_media(row: Dict[str, Any], ttl: int = URL_TTL_SECONDS) -> Dict[str, Any]:
    media_id = str(row["id"])
    created = row.get("created_at")
    return {
        "id": media_id,
        "category": row.get("category"),
        "section": row.get("section"),
        "item_key": row.get("item_key"),
        "item_label": row.get("item_label"),
        "note": row.get("note") or "",
        "content_type": row.get("content_type"),
        "is_image": str(row.get("content_type") or "").startswith("image/"),
        "original_name": row.get("original_name"),
        "size_bytes": row.get("size_bytes"),
        "uploaded_by_name": row.get("uploaded_by_name"),
        "created_at": created.isoformat() if hasattr(created, "isoformat") else created,
        "url": signed_url(media_id, ttl),
    }


def list_media(
    cursor: Any,
    report_ids: Iterable[str],
    categories: Optional[Iterable[str]] = None,
) -> Dict[str, List[Dict[str, Any]]]:
    ids = [str(r) for r in report_ids if r]
    result: Dict[str, List[Dict[str, Any]]] = {rid: [] for rid in ids}
    if not ids:
        return result
    params: Tuple[Any, ...] = (tuple(ids),)
    category_sql = ""
    if categories:
        category_sql = " AND category IN %s"
        params += (tuple(categories),)
    cursor.execute(
        f"""
        SELECT * FROM report_media
        WHERE report_id IN %s AND deleted_at IS NULL{category_sql}
        ORDER BY created_at ASC
        """,
        params,
    )
    for raw in cursor.fetchall():
        row = dict(raw)
        result.setdefault(str(row["report_id"]), []).append(public_media(row))
    return result


def count_media(cursor: Any, report_id: str) -> Dict[str, int]:
    cursor.execute(
        """
        SELECT category, COUNT(*) AS n FROM report_media
        WHERE report_id = %s AND deleted_at IS NULL
        GROUP BY category
        """,
        (str(report_id),),
    )
    return {str(row["category"]): int(row["n"]) for row in cursor.fetchall()}


def store_media(
    cursor: Any,
    report_id: str,
    uploader: Dict[str, Any],
    content: bytes,
    original_name: Optional[str],
    category: str,
    section: Optional[str] = None,
    item_key: Optional[str] = None,
    item_label: Optional[str] = None,
    note: Optional[str] = None,
) -> Dict[str, Any]:
    """Dosyayı seçili depoya yazar ve kaydını oluşturur. Commit çağırana aittir."""
    if category not in CATEGORIES:
        return {"error": "Gecersiz dosya kategorisi", "http_status": 400}
    if section and section not in SECTIONS:
        return {"error": "Gecersiz bolum", "http_status": 400}
    if not content:
        return {"error": "Dosya bos", "http_status": 400}
    if len(content) > MAX_UPLOAD_BYTES:
        return {"error": f"Dosya en fazla {MAX_UPLOAD_BYTES // (1024 * 1024)} MB olabilir", "http_status": 413}
    content_type = detect_content_type(content[:16])
    if not content_type:
        return {"error": "Sadece JPG, PNG, WEBP, HEIC fotograf veya PDF yuklenebilir", "http_status": 415}
    if category == "inspection_photo" and not content_type.startswith("image/"):
        return {"error": "Hasar kaydi icin fotograf yukleyin", "http_status": 415}

    media_id = str(uuid.uuid4())
    file_name = f"{media_id}{_EXTENSIONS[content_type]}"
    try:
        if _storage_mode() == "supabase":
            _supabase_object("POST", str(report_id), file_name, content, content_type)
        else:
            folder = media_root() / str(report_id)
            folder.mkdir(parents=True, exist_ok=True)
            target = folder / file_name
            temp = folder / f".{file_name}.tmp"
            temp.write_bytes(content)
            os.replace(temp, target)
    except _MediaStorageError:
        return {"error": "Dosya depolama hizmetine yüklenemedi. Lütfen tekrar deneyin.", "http_status": 502}

    safe_name = Path(original_name or file_name).name[:200]
    cursor.execute(
        """
        INSERT INTO report_media (
            id, report_id, category, section, item_key, item_label, note,
            file_name, original_name, content_type, size_bytes, sha256,
            uploaded_by, uploaded_by_name
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING *
        """,
        (
            media_id,
            str(report_id),
            category,
            section,
            (item_key or "")[:120] or None,
            (item_label or "")[:200] or None,
            (note or "")[:1000] or None,
            file_name,
            safe_name,
            content_type,
            len(content),
            hashlib.sha256(content).hexdigest(),
            str(uploader.get("id") or ""),
            uploader.get("full_name") or uploader.get("email") or "",
        ),
    )
    return {"success": True, "media": public_media(dict(cursor.fetchone()))}


def soft_delete_media(cursor: Any, report_id: str, media_id: str) -> bool:
    cursor.execute(
        """
        UPDATE report_media SET deleted_at = NOW()
        WHERE id::text = %s AND report_id = %s AND deleted_at IS NULL
        """,
        (str(media_id), str(report_id)),
    )
    return cursor.rowcount > 0


def open_media(media_id: str, expires_at: int, signature: str) -> Dict[str, Any]:
    """İmza doğrulandıktan sonra yerel yolu veya depodaki dosya baytlarını döndürür."""
    try:
        uuid.UUID(str(media_id))
    except ValueError:
        return {"error": "Dosya bulunamadi", "http_status": 404}
    if not verify_signature(str(media_id), int(expires_at or 0), signature or ""):
        return {"error": "Baglantinin suresi dolmus veya gecersiz", "http_status": 403}
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM report_media WHERE id::text = %s AND deleted_at IS NULL",
            (str(media_id),),
        )
        row = cursor.fetchone()
    finally:
        DatabaseConfig.return_connection(conn)
    if not row:
        return {"error": "Dosya bulunamadi", "http_status": 404}
    row = dict(row)
    try:
        if _storage_mode() == "supabase":
            stored_file = {"content": _supabase_object("GET", str(row["report_id"]), str(row["file_name"]))}
        else:
            path = media_root() / str(row["report_id"]) / str(row["file_name"])
            if not path.is_file():
                return {"error": "Dosya bulunamadi", "http_status": 404}
            stored_file = {"path": str(path)}
    except _MediaStorageError:
        return {"error": "Dosya depolama hizmetinden okunamadı. Lütfen tekrar deneyin.", "http_status": 502}
    return {
        **stored_file,
        "content_type": row["content_type"],
        "original_name": row.get("original_name") or row["file_name"],
    }
