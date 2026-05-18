from typing import Dict, List, Any
from yerimebak_ai_v5.data_lake.repository import get_repository
from yerimebak_ai_v5.core.logger import get_logger

logger = get_logger(__name__)

class AnalyticsService:
    """
    Service for analyzing market data and generating insights.
    """
    def __init__(self):
        self.repository = get_repository()

    def get_market_trends(self, brand: str, model: str, year: int) -> Dict[str, Any]:
        """
        Calculate price trends and market stats for a specific vehicle.
        """
        listings = self.repository.get_listings(brand, model, year)
        
        if not listings:
            return {
                "count": 0,
                "average_price": 0,
                "min_price": 0,
                "max_price": 0,
                "status": "NO_DATA"
            }

        prices = [l['price'] for l in listings if l.get('price')]
        
        if not prices:
            return {"count": len(listings), "status": "NO_PRICES"}

        return {
            "count": len(listings),
            "average_price": sum(prices) / len(prices),
            "min_price": min(prices),
            "max_price": max(prices),
            "status": "SUCCESS"
        }

    def get_system_stats(self) -> Dict[str, Any]:
        """
        Get overall system statistics for the dashboard.
        """
        # This would call repository.stats() or similar
        # For now, we'll return some mock data or implement it in repository
        return {
            "total_listings": 1250, # Example
            "active_scrapers": 3,
            "last_update": "2024-02-17 12:00:00"
        }

_analytics_service = None

def get_analytics_service():
    global _analytics_service
    if _analytics_service is None:
        _analytics_service = AnalyticsService()
    return _analytics_service
