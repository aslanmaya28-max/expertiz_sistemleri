from fastapi import APIRouter
from yerimebak_ai_v5.api.v1.endpoints import cases, scrapers, listings, analysis, auth, payments, credits, extension, vitrin, expertiz, favorites, personnel, market_coverage

api_router = APIRouter()
api_router.include_router(cases.router, prefix="/cases", tags=["cases"])
api_router.include_router(listings.router, prefix="/listings", tags=["listings"])
api_router.include_router(scrapers.router, prefix="/scrapers", tags=["scrapers"])
api_router.include_router(analysis.router, tags=["analysis"])
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(payments.router, prefix="/payments", tags=["payments"])
api_router.include_router(credits.router, prefix="/credits", tags=["credits"])
api_router.include_router(extension.router, prefix="/extension", tags=["extension"])
api_router.include_router(vitrin.router, prefix="/vitrin", tags=["vitrin"])
api_router.include_router(expertiz.router, prefix="/expertiz", tags=["expertiz"])
api_router.include_router(favorites.router, prefix="/favorites", tags=["favorites"])
api_router.include_router(personnel.router, prefix="/personnel", tags=["personnel"])
api_router.include_router(market_coverage.router, prefix="/market-coverage", tags=["market-coverage"])
