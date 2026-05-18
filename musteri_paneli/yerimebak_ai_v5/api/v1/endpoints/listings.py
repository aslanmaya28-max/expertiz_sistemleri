"""
Listings API Endpoint v1.0
Vehicle listing CRUD operations
"""
import asyncio
from fastapi import APIRouter, HTTPException, Query, Depends
from typing import List, Dict, Any, Optional
from datetime import datetime

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.api.v1.endpoints.auth import get_authenticated_user

router = APIRouter()


def _p():
    return "%s"


def _row_to_dict(row, cursor):
    if isinstance(row, dict):
        return row
    try:
        return dict(row)
    except (TypeError, ValueError):
        return {desc[0]: row[i] for i, desc in enumerate(cursor.description)}


# ──────────────────────────────────────────────
# 🔒 DÜZELTİLDİ: Sync DB işlemleri run_in_executor için ayrıldı
# ──────────────────────────────────────────────

def _sync_get_listings(
    limit: int,
    source: Optional[str],
    brand: Optional[str],
    min_price: Optional[float],
    max_price: Optional[float],
    min_year: Optional[int],
    max_year: Optional[int],
    opportunity_only: bool,
) -> List[Dict[str, Any]]:
    p = _p()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        conditions = []
        params = []

        if source:
            conditions.append(f"LOWER(source) = LOWER({p})")
            params.append(source)
        if brand:
            conditions.append(f"LOWER(brand) = LOWER({p})")
            params.append(brand)
        if min_price is not None:
            conditions.append(f"price >= {p}")
            params.append(min_price)
        if max_price is not None:
            conditions.append(f"price <= {p}")
            params.append(max_price)
        if min_year is not None:
            conditions.append(f"year >= {p}")
            params.append(min_year)
        if max_year is not None:
            conditions.append(f"year <= {p}")
            params.append(max_year)
        if opportunity_only:
            conditions.append("opportunity_score >= 70")

        where_clause = (" WHERE " + " AND ".join(conditions)) if conditions else ""
        params.append(limit)
        cursor.execute(f"SELECT * FROM listings{where_clause} ORDER BY updated_at DESC LIMIT {p}", tuple(params))
        return [_row_to_dict(row, cursor) for row in cursor.fetchall()]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch listings: {str(e)}")
    finally:
        conn.close()


def _sync_get_pristine_vehicles(limit: int) -> List[Dict[str, Any]]:
    p = _p()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(f"""
            SELECT * FROM listings
            WHERE (paint_info IS NULL OR paint_info = '' OR paint_info = '{{}}')
              AND (accident_record IS NULL OR accident_record = '')
            ORDER BY updated_at DESC LIMIT {p}
        """, (limit,))
        return [_row_to_dict(row, cursor) for row in cursor.fetchall()]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch pristine vehicles: {str(e)}")
    finally:
        conn.close()


def _sync_get_full_package_vehicles(limit: int) -> List[Dict[str, Any]]:
    p = _p()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(f"""
            SELECT * FROM listings
            WHERE package_info ILIKE '%%full%%' OR package_info ILIKE '%%tam%%'
            ORDER BY updated_at DESC LIMIT {p}
        """, (limit,))
        return [_row_to_dict(row, cursor) for row in cursor.fetchall()]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch full package vehicles: {str(e)}")
    finally:
        conn.close()


def _sync_get_market_stats() -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) as total FROM listings")
        total = _row_to_dict(cursor.fetchone(), cursor).get('total', 0)
        cursor.execute("SELECT AVG(price) as avg_price FROM listings WHERE price IS NOT NULL AND price > 0")
        avg_price = round(float(_row_to_dict(cursor.fetchone(), cursor).get('avg_price') or 0))
        cursor.execute("SELECT source, COUNT(*) as count FROM listings GROUP BY source")
        rows = [_row_to_dict(row, cursor) for row in cursor.fetchall()]
        by_source = {r.get('source', 'unknown'): r['count'] for r in rows}
        return {"total_listings": total, "avg_price": avg_price, "by_source": by_source}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch market stats: {str(e)}")
    finally:
        conn.close()


def _sync_get_available_brands() -> List[str]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT DISTINCT brand FROM listings WHERE brand IS NOT NULL ORDER BY brand")
        return [row[0] for row in cursor.fetchall()]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch brands: {str(e)}")
    finally:
        conn.close()


def _sync_get_models_by_brand(brand: str) -> List[str]:
    p = _p()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(f"""
            SELECT DISTINCT model FROM listings
            WHERE brand = {p} AND model IS NOT NULL ORDER BY model
        """, (brand,))
        return [row[0] for row in cursor.fetchall()]
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch models: {str(e)}")
    finally:
        conn.close()


# ──────────────────────────────────────────────
# 🔒 DÜZELTİLDİ: Async endpoint'ler run_in_executor kullanır
# ──────────────────────────────────────────────

@router.get("/")
async def get_listings(
    limit: int = Query(50, ge=1, le=200, description="Maximum number of listings to return"),
    user: Dict[str, Any] = Depends(get_authenticated_user),
    source: Optional[str] = Query(None, description="Filter by source (arabam, borusan)"),
    brand: Optional[str] = Query(None, description="Filter by brand"),
    min_price: Optional[float] = Query(None, description="Minimum price"),
    max_price: Optional[float] = Query(None, description="Maximum price"),
    min_year: Optional[int] = Query(None, description="Minimum year"),
    max_year: Optional[int] = Query(None, description="Maximum year"),
    opportunity_only: bool = Query(False, description="Only return opportunities (score >= 70)")
) -> List[Dict[str, Any]]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_listings, limit, source, brand, min_price, max_price, min_year, max_year, opportunity_only)


@router.get("/pristine")
async def get_pristine_vehicles(
    limit: int = Query(20, ge=1, le=100)
) -> List[Dict[str, Any]]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_pristine_vehicles, limit)


@router.get("/full-package")
async def get_full_package_vehicles(
    limit: int = Query(20, ge=1, le=100)
) -> List[Dict[str, Any]]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_full_package_vehicles, limit)


@router.get("/stats")
async def get_market_stats() -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_market_stats)


@router.get("/brands")
async def get_available_brands() -> List[str]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_available_brands)


@router.get("/models/{brand}")
async def get_models_by_brand(brand: str) -> List[str]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_models_by_brand, brand)
