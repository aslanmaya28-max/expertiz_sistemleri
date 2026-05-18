import logging
import asyncio
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from yerimebak_ai_v5.core.repository import get_repository
from yerimebak_ai_v5.scrapers.arabam_detailed import ArabamDetailedCollector
from yerimebak_ai_v5.scrapers.borusan_smart import BorusanSmartScraper

logger = logging.getLogger(__name__)

class MarketCache:
    def __init__(self):
        self.repository = get_repository()
        # Initialize collectors for fallback/triggering
        self.collectors = {
            'arabam': ArabamDetailedCollector(headless=True),
            'borusan': BorusanSmartScraper()
        }

    async def get_market_data_cached(self, vehicle: Dict[str, Any]) -> List[Dict[str, Any]]:
        """
        Get market data from cache if recent, otherwise trigger scrapers.
        """
        brand = vehicle.get('brand', '').lower()
        model = vehicle.get('model', '').lower()
        year = int(vehicle.get('year', 0))

        # 1. Check database
        # 🔒 DÜZELTİLDİ (B2): get_listings() async — await ile çağrılıyor
        listings = await self.repository.get_listings(brand, model, year)

        
        # 2. Check freshness (at least one listing updated in last 24h)
        is_fresh = False
        if listings:
            latest_update = max(datetime.fromisoformat(l['updated_at'].replace(' ', 'T')) for l in listings)
            if datetime.now() - latest_update < timedelta(hours=24):
                is_fresh = True

        if is_fresh and len(listings) >= 5:
            logger.info(f"🚀 CACHE HIT: Found {len(listings)} fresh listings for {brand} {model} {year}")
            return listings, 0
        
        logger.info(f"🔍 CACHE MISS: Triggering scrapers for {brand} {model} {year}")

        # 3. Trigger scrapers if not fresh or not enough data
        scraped_data = await self._trigger_scrapers(vehicle)
        
        # 4. Save to repository
        scraped_count = len(scraped_data)
        for data in scraped_data:
            await self.repository.save_listing(data)
            
        # 5. Return updated listings from database
        # 🔒 DÜZELTİLDİ (B2): get_listings() async — await ile çağrılıyor
        updated_listings = await self.repository.get_listings(brand, model, year)
        return updated_listings, scraped_count


    async def _trigger_scrapers(self, vehicle: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Run all scrapers for the vehicle"""
        all_new_listings = []
        
        # We run these concurrently for better performance
        tasks = [
            self._scrape_arabam(vehicle),
            self._scrape_borusan(vehicle)
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        for res in results:
            if isinstance(res, list):
                all_new_listings.extend(res)
            elif isinstance(res, Exception):
                logger.error(f"Scraper task failed: {res}")
                
        return all_new_listings

    async def _scrape_arabam(self, vehicle: Dict[str, Any]) -> List[Dict[str, Any]]:
        try:
            # Re-scraped listings should have consistent casing
            raw = await self.collectors['arabam'].collect_data(
                vehicle.get('brand'), vehicle.get('model'), vehicle.get('year')
            )
            for item in raw:
                item['source'] = 'arabam'
            return raw
        except Exception as e:
            logger.warning(f"Arabam scrape failed: {e}")
            return []

    async def _scrape_borusan(self, vehicle: Dict[str, Any]) -> List[Dict[str, Any]]:
        try:
            raw = await self.collectors['borusan'].collect_data(
                vehicle.get('brand'), vehicle.get('year'), vehicle.get('year'),
                model=vehicle.get('model')
            )
            for item in raw:
                item['source'] = 'borusan'
            return raw
        except Exception as e:
            logger.warning(f"Borusan scrape failed: {e}")
            return []

_cache = None

def get_market_cache():
    global _cache
    if _cache is None:
        _cache = MarketCache()
    return _cache
