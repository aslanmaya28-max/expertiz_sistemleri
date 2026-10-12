"""
Vitrin API Endpoint v1.0
Vehicle showcase with filtering, search, and analysis
"""
import asyncio
import json
import ast
import logging
from typing import Dict, Any, Optional, List
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.core.auto_analyzer import analyze_listing
from yerimebak_ai_v5.core.redis_cache import cache_get, cache_set, cache_invalidate_vitrin
from yerimebak_ai_v5.api.v1.endpoints.auth import get_admin_user, get_current_user_optional

logger = logging.getLogger(__name__)
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


def _parse_paint_info_safe(raw):
    if raw is None:
        return {}
    paint_info = raw
    if isinstance(paint_info, str):
        try:
            parsed = json.loads(paint_info)
            if isinstance(parsed, str):
                parsed = json.loads(parsed)
            paint_info = parsed
        except Exception:
            try:
                paint_info = ast.literal_eval(paint_info)
            except Exception:
                paint_info = {}
    if not isinstance(paint_info, dict):
        paint_info = {}
    return paint_info


def _build_vehicle_response(listing: Dict[str, Any], favorite_ids: Optional[set[int]] = None) -> Dict[str, Any]:
    paint_info = _parse_paint_info_safe(listing.get('paint_info'))

    painted_count = 0
    local_count = 0
    changed_count = 0
    if paint_info:
        painted_count = len(paint_info.get('painted_parts', []))
        local_count = len(paint_info.get('local_paint_parts', []))
        changed_parts = paint_info.get('changed_parts', [])
        changed_count = len(changed_parts) if isinstance(changed_parts, list) else 0

    price = listing.get('price') or 0
    market_avg = listing.get('market_avg_price') or 0
    if market_avg and market_avg > 0 and price > 0:
        price_deviation = round(((market_avg - price) / market_avg) * 100, 2)
    else:
        price_deviation = listing.get('price_deviation_pct') or 0.0

    return {
        "id": listing.get('id'),
        "brand": listing.get('brand', ''),
        "model": listing.get('model', ''),
        "year": listing.get('year'),
        "price": price,
        "km": listing.get('km'),
        "fuel": listing.get('fuel') or listing.get('fuel_type', ''),
        "transmission": listing.get('transmission', ''),
        "source": listing.get('source', ''),
        "url": listing.get('url', ''),
        "image_url": listing.get('image_url', ''),
        "location": listing.get('location', ''),
        "title": listing.get('title', ''),
        "color": listing.get('color', ''),
        "engine_size": listing.get('engine_size', ''),
        "horsepower": listing.get('horsepower', ''),
        "body_type": listing.get('body_type', ''),
        "guarantee": listing.get('guarantee', ''),
        "description": listing.get('description', ''),
        "paint_summary": {
            "painted": painted_count,
            "local": local_count,
            "changed": changed_count,
        },
        "ai_score": listing.get('opportunity_score'),
        "market_avg_price": market_avg or None,
        "price_deviation_pct": price_deviation,
        "risk_score": listing.get('risk_score'),
        "risk_level": listing.get('risk_level'),
        "decision": listing.get('decision'),
        "net_profit_tl": listing.get('predicted_profit_tl') or listing.get('net_profit_tl'),
        "net_margin_pct": listing.get('predicted_profit_pct') or listing.get('net_margin_pct'),
        "exit_price": listing.get('exit_price'),
        "days_to_sell": listing.get('days_to_sell'),
        "buy_price_min": listing.get('buy_price_min'),
        "buy_price_max": listing.get('buy_price_max'),
        "analyzed_at": str(listing.get('analyzed_at')) if listing.get('analyzed_at') else None,
        "status": listing.get('status', 'active'),
        "is_favorite": bool(favorite_ids and listing.get('id') in favorite_ids),
        "scraped_at": str(listing.get('scraped_at')) if listing.get('scraped_at') else None,
        "updated_at": str(listing.get('updated_at')) if listing.get('updated_at') else None,
    }


def _favorite_ids_for_user(cursor: Any, user_id: Optional[int], listing_ids: List[int]) -> set[int]:
    if not user_id or not listing_ids:
        return set()
    try:
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
        placeholders = ", ".join(["%s"] * len(listing_ids))
        cursor.execute(
            f"SELECT listing_id FROM user_favorites WHERE user_id = %s AND listing_id IN ({placeholders})",
            tuple([user_id] + listing_ids),
        )
        return {int(_row_to_dict(row, cursor).get("listing_id")) for row in cursor.fetchall()}
    except Exception as exc:
        logger.warning("[VITRIN] favorite lookup skipped: %s", exc)
        return set()


# ──────────────────────────────────────────────
# 🔒 DÜZELTİLDİ: Sync DB işlemleri run_in_executor için ayrıldı
# ──────────────────────────────────────────────

def _sync_get_vehicles(
    brand: Optional[str], model: Optional[str],
    min_price: Optional[int], max_price: Optional[int],
    min_year: Optional[int], max_year: Optional[int],
    min_score: Optional[int], max_score: Optional[int],
    source: Optional[str], risk_level: Optional[str],
    decision: Optional[str], status: str,
    sort_by: str, sort_order: str,
    limit: int, offset: int,
    user_id: Optional[int],
    cache_key: str,
) -> Dict[str, Any]:
    cached = None if user_id else cache_get(cache_key)
    if cached:
        return cached

    p = _p()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        conditions = []
        params = []

        if brand:
            conditions.append(f"LOWER(TRIM(brand)) = LOWER(TRIM({p}))")
            params.append(brand.strip())
        if model:
            conditions.append(f"LOWER(TRIM(model)) = LOWER(TRIM({p}))")
            params.append(model.strip())
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
        if min_score is not None:
            conditions.append(f"opportunity_score >= {p}")
            params.append(min_score)
        if max_score is not None:
            conditions.append(f"opportunity_score <= {p}")
            params.append(max_score)
        if source:
            conditions.append(f"LOWER(source) = LOWER({p})")
            params.append(source.strip())
        if risk_level:
            conditions.append(f"risk_level = {p}")
            params.append(risk_level)
        if decision:
            conditions.append(f"decision = {p}")
            params.append(decision.upper())
        if status:
            conditions.append(f"(status = {p} OR status IS NULL)")
            params.append(status)

        where_clause = (" WHERE " + " AND ".join(conditions)) if conditions else ""

        allowed_sort = {
            "updated_at", "price", "opportunity_score", "risk_score",
            "year", "km", "predicted_profit_tl", "analyzed_at",
        }
        if sort_by not in allowed_sort:
            sort_by = "updated_at"
        sort_dir = "DESC" if sort_order.lower() == "desc" else "ASC"

        count_params = list(params)
        cursor.execute(f"SELECT COUNT(*) as total FROM listings{where_clause}", tuple(count_params))
        total = _row_to_dict(cursor.fetchone(), cursor).get('total', 0)

        params.append(limit)
        params.append(offset)
        cursor.execute(
            f"SELECT * FROM listings{where_clause} ORDER BY {sort_by} {sort_dir} LIMIT {p} OFFSET {p}",
            tuple(params),
        )
        rows = [_row_to_dict(row, cursor) for row in cursor.fetchall()]
        favorite_ids = _favorite_ids_for_user(cursor, user_id, [int(r["id"]) for r in rows if r.get("id")])
        vehicles = [_build_vehicle_response(r, favorite_ids) for r in rows]

        result = {"total": total, "limit": limit, "offset": offset, "vehicles": vehicles}
        if not user_id:
            cache_set(cache_key, result, ttl=120)
        return result
    except Exception as e:
        logger.error(f"[VITRIN] get_vehicles error: {e}")
        raise HTTPException(status_code=500, detail=f"Araç listesi alınamadı: {str(e)}")
    finally:
        conn.close()


def _sync_get_vehicle_detail(vehicle_id: int, user_id: Optional[int]) -> Dict[str, Any]:
    p = _p()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(f"SELECT * FROM listings WHERE id = {p}", (vehicle_id,))
        row = cursor.fetchone()
        if not row:
            raise HTTPException(status_code=404, detail="Araç bulunamadı")
        listing = _row_to_dict(row, cursor)
        favorite_ids = _favorite_ids_for_user(cursor, user_id, [vehicle_id])
        response = _build_vehicle_response(listing, favorite_ids)

        paint_info = _parse_paint_info_safe(listing.get('paint_info'))
        if paint_info:
            response["paint_details"] = paint_info

        if listing.get('action_recommendation'):
            response["action_recommendation"] = listing.get('action_recommendation')

        return response
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[VITRIN] get_vehicle_detail error: {e}")
        raise HTTPException(status_code=500, detail=f"Araç detayı alınamadı: {str(e)}")
    finally:
        conn.close()


def _sync_get_brands() -> List[Dict[str, Any]]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT brand, COUNT(*) as count
            FROM listings
            WHERE brand IS NOT NULL
            GROUP BY brand
            ORDER BY count DESC
        """)
        rows = [_row_to_dict(row, cursor) for row in cursor.fetchall()]
        return [{"brand": r['brand'], "count": r['count']} for r in rows]
    except Exception as e:
        logger.error(f"[VITRIN] get_brands error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


def _sync_get_models(brand: str) -> List[Dict[str, Any]]:
    p = _p()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(f"""
            SELECT model, COUNT(*) as count
            FROM listings
            WHERE LOWER(TRIM(brand)) = LOWER(TRIM({p}))
            GROUP BY model
            ORDER BY count DESC
        """, (brand.strip(),))
        rows = [_row_to_dict(row, cursor) for row in cursor.fetchall()]
        return [{"model": r['model'], "count": r['count']} for r in rows]
    except Exception as e:
        logger.error(f"[VITRIN] get_models error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


def _sync_get_stats() -> Dict[str, Any]:
    cached = cache_get("vitrin:stats")
    if cached:
        return cached
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()

        cursor.execute("SELECT COUNT(*) as total FROM listings")
        total_listings = _row_to_dict(cursor.fetchone(), cursor).get('total', 0)

        cursor.execute("SELECT COUNT(*) as total FROM listings WHERE analyzed_at IS NOT NULL")
        analyzed_count = _row_to_dict(cursor.fetchone(), cursor).get('total', 0)

        cursor.execute("""
            SELECT AVG(opportunity_score) as avg_score
            FROM listings WHERE opportunity_score IS NOT NULL
        """)
        row = _row_to_dict(cursor.fetchone(), cursor)
        avg_score = round(float(row.get('avg_score') or 0), 1)

        cursor.execute("""
            SELECT COUNT(*) as total
            FROM listings WHERE decision IN ('BUY', 'STRONG_BUY')
        """)
        buy_count = _row_to_dict(cursor.fetchone(), cursor).get('total', 0)

        cursor.execute("""
            SELECT AVG(price) as avg_price
            FROM listings WHERE price IS NOT NULL AND price > 0
        """)
        row = _row_to_dict(cursor.fetchone(), cursor)
        avg_price = round(float(row.get('avg_price') or 0))

        cursor.execute("""
            SELECT source, COUNT(*) as count FROM listings GROUP BY source
        """)
        rows = [_row_to_dict(row, cursor) for row in cursor.fetchall()]
        by_source = {r.get('source', 'unknown'): r['count'] for r in rows}

        cursor.execute("""
            SELECT COUNT(*) as total
            FROM listings WHERE updated_at > NOW() - INTERVAL '24 hours'
        """)
        daily_new = _row_to_dict(cursor.fetchone(), cursor).get('total', 0)

        result = {
            "total_listings": total_listings,
            "analyzed_listings": analyzed_count,
            "avg_ai_score": avg_score,
            "buy_opportunities": buy_count,
            "avg_price": avg_price,
            "by_source": by_source,
            "daily_new_listings": daily_new,
        }
        cache_set("vitrin:stats", result, ttl=300)
        return result
    except Exception as e:
        logger.error(f"[VITRIN] get_stats error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


def _sync_search_vehicles(q: str, limit: int, user_id: Optional[int]) -> Dict[str, Any]:
    p = _p()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        search_term = f"%{q.strip()}%"
        cursor.execute(f"""
            SELECT * FROM listings
            WHERE (brand ILIKE {p} OR model ILIKE {p} OR title ILIKE {p} OR series ILIKE {p})
            ORDER BY updated_at DESC LIMIT {p}
        """, (search_term, search_term, search_term, search_term, limit))
        rows = [_row_to_dict(row, cursor) for row in cursor.fetchall()]
        favorite_ids = _favorite_ids_for_user(cursor, user_id, [int(r["id"]) for r in rows if r.get("id")])
        vehicles = [_build_vehicle_response(r, favorite_ids) for r in rows]
        return {"query": q, "total": len(vehicles), "vehicles": vehicles}
    except Exception as e:
        logger.error(f"[VITRIN] search error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        conn.close()


def _sync_update_vehicle_status(vehicle_id: int, new_status: str) -> Dict[str, Any]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("UPDATE listings SET status = %s WHERE id = %s", (new_status, vehicle_id))
        if cursor.rowcount == 0:
            raise HTTPException(status_code=404, detail="Araç bulunamadı")
        conn.commit()
        return {"id": vehicle_id, "status": new_status}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        DatabaseConfig.return_connection(conn)


# ──────────────────────────────────────────────
# 🔒 DÜZELTİLDİ: Async endpoint'ler run_in_executor kullanır
# ──────────────────────────────────────────────

@router.get("/vehicles")
async def get_vehicles(
    brand: Optional[str] = Query(None, description="Marka filtresi"),
    model: Optional[str] = Query(None, description="Model filtresi"),
    min_price: Optional[int] = Query(None, description="Minimum fiyat"),
    max_price: Optional[int] = Query(None, description="Maksimum fiyat"),
    min_year: Optional[int] = Query(None, description="Minimum yıl"),
    max_year: Optional[int] = Query(None, description="Maksimum yıl"),
    min_score: Optional[int] = Query(None, description="Minimum AI puanı"),
    max_score: Optional[int] = Query(None, description="Maksimum AI puanı"),
    source: Optional[str] = Query(None, description="Kaynak filtresi (arabam/borusan)"),
    risk_level: Optional[str] = Query(None, description="Risk seviyesi (DÜŞÜK/ORTA/YÜKSEK)"),
    decision: Optional[str] = Query(None, description="Karar filtresi (BUY/STRONG_BUY/HOLD/AVOID)"),
    status: Optional[str] = Query("active", description="Durum filtresi (active/hidden/featured/sold)"),
    sort_by: Optional[str] = Query("updated_at", description="Sıralama alanı"),
    sort_order: Optional[str] = Query("desc", description="Sıralama yönü (asc/desc)"),
    limit: int = Query(24, ge=1, le=200, description="Sayfa boyutu"),
    user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
    offset: int = Query(0, ge=0, description="Sayfa başlangıcı"),
) -> Dict[str, Any]:
    cache_key = f"vitrin:vehicles:{brand}:{model}:{min_price}:{max_price}:{min_year}:{max_year}:{min_score}:{max_score}:{source}:{risk_level}:{decision}:{status}:{sort_by}:{sort_order}:{limit}:{offset}"
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(
        None, _sync_get_vehicles,
        brand, model, min_price, max_price, min_year, max_year,
        min_score, max_score, source, risk_level, decision, status or "active",
        sort_by or "updated_at", sort_order or "desc",
        limit, offset, user.get("id") if user else None, cache_key,
    )


@router.get("/vehicles/{vehicle_id}")
async def get_vehicle_detail(
    vehicle_id: int,
    user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_vehicle_detail, vehicle_id, user.get("id") if user else None)


@router.get("/brands")
async def get_brands() -> List[Dict[str, Any]]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_brands)


@router.get("/models")
async def get_models(brand: str = Query(..., description="Marka adı")) -> List[Dict[str, Any]]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_models, brand)


@router.get("/stats")
async def get_stats() -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_stats)


@router.post("/{vehicle_id}/analyze")
async def analyze_vehicle(vehicle_id: int, admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    cache_invalidate_vitrin()
    result = analyze_listing(vehicle_id)
    if not result:
        raise HTTPException(status_code=404, detail="Araç bulunamadı veya analiz başarısız")
    return result


@router.get("/search")
async def search_vehicles(
    q: str = Query(..., min_length=2, description="Arama sorgusu"),
    limit: int = Query(20, ge=1, le=100),
    user: Optional[Dict[str, Any]] = Depends(get_current_user_optional),
) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_search_vehicles, q, limit, user.get("id") if user else None)


@router.patch("/{vehicle_id}/status")
async def update_vehicle_status(vehicle_id: int, payload: Dict[str, str] = None, admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    if not payload or 'status' not in payload:
        raise HTTPException(status_code=400, detail="status alanı gerekli")
    new_status = payload['status']
    if new_status not in ('active', 'hidden', 'featured', 'sold'):
        raise HTTPException(status_code=400, detail="Geçersiz durum. Aktif/gizli/öne çıkarılmış/satıldı olmalı")
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, _sync_update_vehicle_status, vehicle_id, new_status)
    cache_invalidate_vitrin()
    return result
