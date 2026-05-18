from fastapi import APIRouter
from yerimebak_ai_v5.dashboard.services.query_cache import get_cached_all_listings

router = APIRouter(prefix="/listings", tags=["listings"])

@router.get("/")
async def list_market_data():
    df = get_cached_all_listings()
    return df.to_dict(orient="records")
