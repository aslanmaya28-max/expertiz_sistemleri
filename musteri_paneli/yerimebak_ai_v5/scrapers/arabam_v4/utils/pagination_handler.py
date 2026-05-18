# -*- coding: utf-8 -*-
"""
Arabam v5.0 - Pagination Handler
Multi-page listing extraction
"""

import asyncio
from typing import List, Dict, Any, Optional
from playwright.async_api import Page

from .url_normalizer import URLNormalizer
from .scroll_manager import ScrollManager

import logging
logger = logging.getLogger(__name__)


class PaginationHandler:
    """
    Pagination handler
    
    Arabam.com'da çok sayfalı ilan listelemek için
    URL-based pagination stratejisi uygular.
    """
    
    def __init__(
        self,
        max_pages: int = 3,
        max_listings: int = 15,
        scroll_cycles: int = 5
    ):
        """
        Initialize pagination handler
        
        Args:
            max_pages: Maximum sayfa sayısı
            max_listings: Maximum ilan sayısı
            scroll_cycles: Scroll döngü sayısı
        """
        self.max_pages = max_pages
        self.max_listings = max_listings
        self.url_normalizer = URLNormalizer()
        self.scroll_manager = ScrollManager(scroll_cycles=scroll_cycles)
    
    async def extract_multi_page(
        self,
        page: Page,
        base_url: str,
        brand: str,
        model: str,
        year: int
    ) -> List[Dict[str, Any]]:
        """
        Multi-page listing extraction
        
        Args:
            page: Playwright page
            base_url: Base URL
            brand: Marka
            model: Model
            year: Yıl
            
        Returns:
            List[Dict[str, Any]]: Tüm ilanlar
        """
        all_listings = []
        seen_urls = set()
        
        logger.info(f"🔄 Starting multi-page extraction (max {self.max_pages} pages)")
        
        for page_num in range(1, self.max_pages + 1):
            logger.info(f"\n📄 Sayfa {page_num}/{self.max_pages}")
            
            # Build page URL
            page_url = self.url_normalizer.build_page_url(base_url, page_num)
            logger.info(f"   URL: {page_url}")
            
            try:
                # Navigate to page
                await page.goto(page_url, wait_until="domcontentloaded", timeout=60000)
                
                # Wait for page load
                await asyncio.sleep(3)
                
                # Aggressive scroll to trigger lazy loading
                listing_count = await self.scroll_manager.aggressive_scroll(
                    page,
                    target_count=self.max_listings
                )
                logger.info(f"   📊 {listing_count} listing element found")
                
                # Extract listings from this page
                page_listings = await self._extract_page_listings(
                    page,
                    brand,
                    model,
                    year,
                    seen_urls
                )
                
                if not page_listings:
                    logger.info(f"   ⚠️ No listings found on page {page_num}")
                    # If no listings on first page, stop
                    if page_num == 1:
                        break
                    # If no listings on subsequent page, might be end
                    continue
                
                logger.info(f"   ✅ {len(page_listings)} unique listings extracted")
                
                all_listings.extend(page_listings)
                
                # Stop if we have enough listings
                if len(all_listings) >= self.max_listings:
                    logger.info(f"   🎯 Target reached: {len(all_listings)} listings")
                    break
                
                # If we got fewer listings than expected, might be last page
                if len(page_listings) < 5:
                    logger.info(f"   ⚠️ Few listings than expected, might be last page")
                    break
                
            except Exception as e:
                logger.error(f"   ❌ Error on page {page_num}: {str(e)[:100]}")
                # Continue to next page
                continue
        
        logger.info(f"\n✅ Multi-page extraction complete: {len(all_listings)} total listings")
        
        return all_listings[:self.max_listings]
    
    async def _extract_page_listings(
        self,
        page: Page,
        brand: str,
        model: str,
        year: int,
        seen_urls: set
    ) -> List[Dict[str, Any]]:
        """
        Sayfadaki ilanları çıkar
        
        Args:
            page: Playwright page
            brand: Marka
            model: Model
            year: Yıl
            seen_urls: Görülen URL'ler set
            
        Returns:
            List[Dict[str, Any]]: İlan listesi
        """
        listings = []
        
        try:
            # Get all listing link elements
            elements = await page.query_selector_all("a[href*='/ilan/']")
            
            valid_count = 0
            duplicate_count = 0
            invalid_count = 0
            
            for element in elements:
                try:
                    href = await element.get_attribute('href')
                    
                    if not href:
                        invalid_count += 1
                        continue
                    
                    # Normalize URL to remove query parameters
                    normalized = self.url_normalizer.normalize(href)
                    
                    # Validation check
                    if not self._is_valid_listing_link(normalized):
                        invalid_count += 1
                        continue
                    
                    valid_count += 1
                    
                    # Duplicate check
                    if normalized in seen_urls:
                        duplicate_count += 1
                        continue
                    
                    seen_urls.add(normalized)
                    
                    # Build full URL
                    if href.startswith('/'):
                        full_url = f"https://www.arabam.com{href}"
                    else:
                        full_url = href
                    
                    # Create listing info
                    title = f"{brand} {model} {year}"
                    
                    listings.append({
                        'url': full_url,
                        'title': title,
                        'brand': brand,
                        'model': model,
                        'year': year
                    })
                    
                    # Stop if we have enough
                    if len(listings) >= self.max_listings:
                        break
                
                except Exception:
                    continue
            
            logger.info(f"   Valid: {valid_count}, Duplicate: {duplicate_count}, Invalid: {invalid_count}")
            
        except Exception as e:
            logger.error(f"   ❌ Page extraction error: {str(e)[:100]}")
        
        return listings
    
    def _is_valid_listing_link(self, href: str) -> bool:
        """
        Geçerli ilan linki mi?
        
        Args:
            href: URL
            
        Returns:
            bool: True if valid
        """
        # Must contain /ilan/
        if '/ilan/' not in href:
            return False
        
        # Must have numeric ID
        url_parts = href.split('/')
        last_part = url_parts[-1] if url_parts else ""
        
        if not any(c.isdigit() for c in last_part):
            return False
        
        return True
