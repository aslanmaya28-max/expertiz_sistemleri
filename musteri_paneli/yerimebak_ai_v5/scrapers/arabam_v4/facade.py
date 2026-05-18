# -*- coding: utf-8 -*-
"""
Arabam v4.0 - Facade
Basit API için Facade pattern
"""

from typing import Optional

from yerimebak_ai_v5.scrapers.arabam_v4.scrapers.arabam_scraper import ArabamScraper
from yerimebak_ai_v5.scrapers.arabam_v4.models.search_result import ArabamSearchResult

import logging
logger = logging.getLogger(__name__)


class ArabamScraperFacade:
    """
    Arabam Scraper Facade
    
    Basit API sağlar. Tüm karmaşıklığı gizler.
    """
    
    def __init__(
        self,
        headless: bool = True,
        max_listings: int = 15,
        skip_detail_scroll: bool = True,
        max_pages: int = 3,
        enable_pagination: bool = True
    ):
        """
        Initialize facade
        
        Args:
            headless: Headless mode (default: True)
            max_listings: Maximum listings (default: 15)
            skip_detail_scroll: Skip scrolling on detail pages for performance (default: True)
            max_pages: Maximum pages to scrape for pagination (default: 3)
            enable_pagination: Enable multi-page extraction (default: True)
        """
        self.scraper = ArabamScraper(
            headless=headless,
            max_listings=max_listings,
            skip_detail_scroll=skip_detail_scroll,
            max_pages=max_pages,
            enable_pagination=enable_pagination
        )
    
    async def search(
        self,
        brand: str,
        model: str,
        year: int,
        min_price: Optional[int] = None,
        max_price: Optional[int] = None
    ) -> ArabamSearchResult:
        """
        Araç ara
        
        Args:
            brand: Marka (örn: "Volkswagen")
            model: Model (örn: "Golf")
            year: Yıl (örn: 2020)
            min_price: Min fiyat (optional)
            max_price: Max fiyat (optional)
            
        Returns:
            ArabamSearchResult: Arama sonuçları
            
        Example:
            >>> facade = ArabamScraperFacade()
            >>> result = await facade.search("Volkswagen", "Golf", 2020)
            >>> print(f"Found: {len(result.listings)} listings")
        """
        logger.info(f"🔍 Arama başlatıldı: {brand} {model} {year}")
        
        result = await self.scraper.search(
            brand=brand,
            model=model,
            year=year,
            min_price=min_price,
            max_price=max_price
        )
        
        logger.info(f"✅ Arama tamamlandı: {len(result.listings)} ilan")
        
        return result
    
    async def close(self) -> None:
        """Scraper'ı kapat"""
        if self.scraper and self.scraper.browser_manager:
            await self.scraper.browser_manager.close()
    
    async def __aenter__(self):
        """Async context manager entry"""
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit"""
        await self.close()
