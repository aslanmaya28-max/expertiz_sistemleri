from fastapi import APIRouter
from yerimebak_ai_v5.dashboard.services.query_cache import get_cached_market_stats

router = APIRouter(prefix="/analytics", tags=["analytics"])

@router.get("/stats")
async def get_stats():
    return get_cached_market_stats()
