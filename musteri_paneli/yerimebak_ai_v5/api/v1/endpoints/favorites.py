"""
Favorites API Endpoint v1.0
User favorite vehicle management
"""
import asyncio
from typing import Any, Dict

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from yerimebak_ai_v5.api.v1.endpoints.auth import get_current_user
from yerimebak_ai_v5.api.v1.endpoints.vitrin import _build_vehicle_response, _row_to_dict
from yerimebak_ai_v5.core.database_config import DatabaseConfig

router = APIRouter()


class FavoriteRequest(BaseModel):
    listing_id: int


def _ensure_favorites_schema(cursor: Any) -> None:
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS user_favorites (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL,
            listing_id INTEGER NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(user_id, listing_id)
        )
        """
    )


# ──────────────────────────────────────────────
# 🔒 DÜZELTİLDİ: Sync DB işlemleri run_in_executor için ayrıldı
# ──────────────────────────────────────────────

def _sync_list_favorites(user_id: int) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_favorites_schema(cursor)
        cursor.execute(
            """
            SELECT f.created_at as favorited_at, l.*
            FROM user_favorites f
            JOIN listings l ON l.id = f.listing_id
            WHERE f.user_id = %s
            ORDER BY f.created_at DESC
            LIMIT 100
            """,
            (user_id,),
        )
        rows = [_row_to_dict(row, cursor) for row in cursor.fetchall()]
        favorites = []
        for row in rows:
            item = _build_vehicle_response(row)
            item["favorited_at"] = str(row.get("favorited_at")) if row.get("favorited_at") else None
            favorites.append(item)
        return {"success": True, "favorites": favorites, "total": len(favorites)}
    finally:
        DatabaseConfig.return_connection(conn)


def _sync_add_favorite(user_id: int, listing_id: int) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_favorites_schema(cursor)
        cursor.execute("SELECT id FROM listings WHERE id = %s", (listing_id,))
        if not cursor.fetchone():
            raise HTTPException(status_code=404, detail="Arac bulunamadi")
        cursor.execute(
            """
            INSERT INTO user_favorites (user_id, listing_id)
            VALUES (%s, %s)
            ON CONFLICT (user_id, listing_id) DO NOTHING
            """,
            (user_id, listing_id),
        )
        return {"success": True, "listing_id": listing_id}
    finally:
        DatabaseConfig.return_connection(conn)


def _sync_remove_favorite(user_id: int, listing_id: int) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        _ensure_favorites_schema(cursor)
        cursor.execute(
            "DELETE FROM user_favorites WHERE user_id = %s AND listing_id = %s",
            (user_id, listing_id),
        )
        return {"success": True, "listing_id": listing_id}
    finally:
        DatabaseConfig.return_connection(conn)


# ──────────────────────────────────────────────
# 🔒 DÜZELTİLDİ: Async endpoint'ler run_in_executor kullanır
# ──────────────────────────────────────────────

@router.get("")
async def list_favorites(user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_list_favorites, user["id"])


@router.post("")
async def add_favorite(payload: FavoriteRequest, user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_add_favorite, user["id"], payload.listing_id)


@router.delete("/{listing_id}")
async def remove_favorite(listing_id: int, user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_remove_favorite, user["id"], listing_id)
