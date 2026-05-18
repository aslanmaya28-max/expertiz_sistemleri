"""
API v1 Router - YERİMEBAK AI
Main router configuration for all v1 endpoints
"""
from fastapi import APIRouter
from yerimebak_ai_v5.api.v1.endpoints import cases, scrapers, listings, analysis

# Create main API v1 router
api_router = APIRouter()

# Include all endpoint routers
api_router.include_router(
    cases.router,
    prefix="/cases",
    tags=["cases"]
)

api_router.include_router(
    scrapers.router,
    prefix="/scrapers",
    tags=["scrapers"]
)

api_router.include_router(
    listings.router,
    prefix="/listings",
    tags=["listings"]
)

api_router.include_router(
    analysis.router,
    prefix="/analysis",
    tags=["analysis"]
)

# Health check endpoint
@api_router.get("/health")
async def health_check():
    """
    Overall API health check
    """
    return {
        "status": "healthy",
        "version": "v1.0",
        "service": "yerimebak_ai",
        "endpoints": {
            "cases": "/api/v1/cases",
            "scrapers": "/api/v1/scrapers",
            "listings": "/api/v1/listings",
            "analysis": "/api/v1/analysis"
        }
    }