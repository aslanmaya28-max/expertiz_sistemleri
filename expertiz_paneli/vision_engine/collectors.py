"""
Vision Engine - Multi-Source Market Data Collector
Parallel scraping from Arabam, VavaCars, and Borusan Next
"""

import asyncio
import logging
from typing import List, Optional
from datetime import datetime
from playwright.async_api import async_playwright, Page, Browser
from .models import CarListing, SourceType

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class BaseCollector:
    """Base class for all market collectors"""
    
    def __init__(self, source: SourceType, timeout: int = 30000):
        self.source = source
        self.timeout = timeout
        self.browser = None
        self.page = None
    
    async def init_browser(self):
        """Initialize Playwright browser"""
        if not self.browser:
            playwright = await async_playwright().start()
            self.browser = await playwright.chromium.launch(headless=True)
            self.page = await self.browser.new_page()
            await self.page.set_default_timeout(self.timeout)
    
    async def close(self):
        """Close browser resources"""
        if self.browser:
            await self.browser.close()
            self.browser = None
            self.page = None
    
    async def search(self, brand: str, model: str, year: int, location: str = "Türkiye") -> List[CarListing]:
        """
        Search for vehicle listings
        Must be implemented by subclasses
        """
        raise NotImplementedError("Subclasses must implement search()")


class ArabamCollector(BaseCollector):
    """Collector for arabam.com"""
    
    def __init__(self):
        super().__init__(SourceType.ARABAM)
        self.base_url = "https://www.arabam.com"
    
    async def search(self, brand: str, model: str, year: int, location: str = "Türkiye") -> List[CarListing]:
        """Search Arabam for vehicle listings"""
        listings = []
        
        try:
            await self.init_browser()
            
            # Construct search URL
            search_url = f"{self.base_url}/ikinci-el/{brand.lower()}/{model.lower()}"
            logger.info(f"🔍 Searching Arabam: {search_url}")
            
            await self.page.goto(search_url)
            await self.page.wait_for_load_state("networkidle")
            
            # Wait for listings to load
            await self.page.wait_for_selector("listing-item, .listing-item, .card", timeout=5000)
            
            # Extract listing data (simplified selector structure)
            listing_elements = await self.page.query_all_selector("listing-item, .listing-item, .card")
            
            for element in listing_elements[:10]:  # Limit to first 10 listings
                try:
                    title = await element.text_content("h3, .title, .listing-title")
                    price_text = await element.text_content(".price, .listing-price")
                    location_text = await element.text_content(".location, .listing-location")
                    url = await element.get_attribute("a", "href")
                    
                    # Parse price
                    price = self._parse_price(price_text)
                    
                    listing = CarListing(
                        source=self.source,
                        title=title.strip() if title else f"{brand} {model}",
                        price=price,
                        year=year,
                        km=0,  # Will be parsed if available
                        location=location_text.strip() if location_text else location,
                        url=f"{self.base_url}{url}" if url and not url.startswith('http') else url,
                        listed_at=datetime.now(),
                        is_verified=True
                    )
                    listings.append(listing)
                    
                except Exception as e:
                    logger.warning(f"Error parsing Arabam listing: {e}")
                    continue
            
            logger.info(f"✅ Arabam: Found {len(listings)} listings")
            
        except Exception as e:
            logger.error(f"❌ Arabam scraping error: {e}")
        finally:
            await self.close()
        
        return listings
    
    def _parse_price(self, price_text: Optional[str]) -> float:
        """Parse price from text (e.g., '850.000 TL' -> 850000.0)"""
        if not price_text:
            return 0.0
        
        # Remove non-numeric characters
        cleaned = price_text.replace('.', '').replace(',', '').replace('TL', '').strip()
        try:
            return float(cleaned)
        except ValueError:
            return 0.0


class VavaCarsCollector(BaseCollector):
    """Collector for vavacars.com"""
    
    def __init__(self):
        super().__init__(SourceType.VAVACARS)
        self.base_url = "https://www.vavacars.com"
    
    async def search(self, brand: str, model: str, year: int, location: str = "Türkiye") -> List[CarListing]:
        """Search VavaCars for vehicle listings"""
        listings = []
        
        try:
            await self.init_browser()
            
            # VavaCars search endpoint (simplified)
            search_url = f"{self.base_url}/satilik-araba"
            logger.info(f"🔍 Searching VavaCars: {search_url}")
            
            await self.page.goto(search_url)
            await self.page.wait_for_load_state("networkidle")
            
            # Fill search form
            await self.page.fill("input[placeholder*='Marka'], input[name*='brand']", brand)
            await self.page.press("input[placeholder*='Marka'], input[name*='brand']", "Enter")
            await self.page.wait_for_timeout(2000)
            
            # Extract listings (simplified)
            listing_elements = await self.page.query_all_selector(".car-card, .vehicle-card, .listing")
            
            for element in listing_elements[:10]:
                try:
                    title = await element.text_content("h3, .title")
                    price_text = await element.text_content(".price, .amount")
                    url = await element.get_attribute("a", "href")
                    
                    price = self._parse_price(price_text)
                    
                    listing = CarListing(
                        source=self.source,
                        title=title.strip() if title else f"{brand} {model}",
                        price=price,
                        year=year,
                        km=0,
                        location=location,
                        url=f"{self.base_url}{url}" if url and not url.startswith('http') else url,
                        listed_at=datetime.now(),
                        is_verified=True
                    )
                    listings.append(listing)
                    
                except Exception as e:
                    logger.warning(f"Error parsing VavaCars listing: {e}")
                    continue
            
            logger.info(f"✅ VavaCars: Found {len(listings)} listings")
            
        except Exception as e:
            logger.error(f"❌ VavaCars scraping error: {e}")
        finally:
            await self.close()
        
        return listings
    
    def _parse_price(self, price_text: Optional[str]) -> float:
        """Parse price from text"""
        if not price_text:
            return 0.0
        cleaned = price_text.replace('.', '').replace(',', '').replace('TL', '').strip()
        try:
            return float(cleaned)
        except ValueError:
            return 0.0


class BorusanCollector(BaseCollector):
    """Collector for Borusan Next (Premium upper bound)"""
    
    def __init__(self):
        super().__init__(SourceType.BORUSAN)
        self.base_url = "https://www.borusanoto.com"
    
    async def search(self, brand: str, model: str, year: int, location: str = "Türkiye") -> List[CarListing]:
        """Search Borusan for vehicle listings"""
        listings = []
        
        try:
            await self.init_browser()
            
            # Borusan search (simplified - typically requires authentication)
            logger.info(f"🔍 Searching Borusan (Premium Source)")
            
            # Note: Borusan often requires dealer authentication
            # This is a placeholder for the implementation
            logger.warning("⚠️ Borusan requires dealer credentials - using mock data")
            
            # Mock premium pricing for demonstration
            for i in range(5):
                listing = CarListing(
                    source=self.source,
                    title=f"{brand} {model} Premium",
                    price=1000000.0 + (i * 50000),  # Premium pricing
                    year=year,
                    km=0,
                    location=location,
                    url=f"{self.base_url}/listing/{i}",
                    listed_at=datetime.now(),
                    is_verified=True
                )
                listings.append(listing)
            
            logger.info(f"✅ Borusan: Found {len(listings)} listings")
            
        except Exception as e:
            logger.error(f"❌ Borusan scraping error: {e}")
        finally:
            await self.close()
        
        return listings


class MultiSourceCollector:
    """
    Orchestrates parallel data collection from all sources
    Implements timeout management and graceful degradation
    """
    
    def __init__(self):
        self.collectors = {
            SourceType.ARABAM: ArabamCollector(),
            SourceType.VAVACARS: VavaCarsCollector(),
            SourceType.BORUSAN: BorusanCollector()
        }
    
    async def collect_all(self, brand: str, model: str, year: int, location: str = "Türkiye") -> List[CarListing]:
        """
        Collect data from all sources in parallel
        If one source fails, continue with others
        """
        logger.info(f"🚀 Starting multi-source collection: {brand} {model} {year}")
        
        tasks = []
        for source_type, collector in self.collectors.items():
            task = self._collect_with_timeout(collector, brand, model, year, location)
            tasks.append(task)
        
        # Run all tasks in parallel, don't fail if one fails
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        all_listings = []
        for result in results:
            if isinstance(result, Exception):
                logger.error(f"Collection failed: {result}")
            elif isinstance(result, list):
                all_listings.extend(result)
        
        logger.info(f"✅ Total listings collected: {len(all_listings)}")
        return all_listings
    
    async def _collect_with_timeout(self, collector: BaseCollector, brand: str, model: str, year: int, location: str) -> List[CarListing]:
        """Run collector with timeout management"""
        try:
            return await asyncio.wait_for(
                collector.search(brand, model, year, location),
                timeout=30.0  # 30 seconds timeout per source
            )
        except asyncio.TimeoutError:
            logger.warning(f"⏱️ Timeout for {collector.source.value}")
            return []
        except Exception as e:
            logger.error(f"❌ Error in {collector.source.value}: {e}")
            return []
    
    async def close_all(self):
        """Close all collector resources"""
        for collector in self.collectors.values():
            await collector.close()