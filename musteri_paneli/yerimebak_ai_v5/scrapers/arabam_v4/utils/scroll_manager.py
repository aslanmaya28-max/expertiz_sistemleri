# -*- coding: utf-8 -*-
"""
Arabam v5.0 - Scroll Manager
Aggressive scroll mekanizması için lazy loading tetikleme
"""

import asyncio
from typing import Optional
from playwright.async_api import Page


class ScrollManager:
    """
    Aggressive scroll mekanizması
    
    Lazy loading ile yüklenen içerikleri tetiklemek için
    agresif scroll stratejisi uygular.
    """
    
    def __init__(self, scroll_cycles: int = 5, scroll_delay: int = 1500):
        """
        Initialize scroll manager
        
        Args:
            scroll_cycles: Scroll döngü sayısı (default: 5)
            scroll_delay: Scroll sonrası bekleme süresi ms (default: 1500)
        """
        self.scroll_cycles = scroll_cycles
        self.scroll_delay = scroll_delay
        
        # Scroll pattern: (direction, wait_time_ms)
        self.scroll_pattern = [
            ('bottom', 2000),   # Scroll to bottom, wait 2s
            ('middle', 1500),   # Scroll to middle, wait 1.5s
            ('top', 1000),      # Scroll to top, wait 1s
            ('bottom', 2000),   # Scroll to bottom again
        ]
    
    async def aggressive_scroll(
        self,
        page: Page,
        target_count: int = 15,
        listing_selector: str = "a[href*='/ilan/']"
    ) -> int:
        """
        Aggressive scroll stratejisi uygula
        
        Args:
            page: Playwright page
            target_count: Hedef ilan sayısı
            listing_selector: İlan link selector'ı
            
        Returns:
            int: Bulunan toplam ilan sayısı
        """
        total_cycles = 0
        
        for cycle in range(self.scroll_cycles):
            total_cycles += 1
            
            for direction, wait_time in self.scroll_pattern:
                # Scroll işlemi
                await self._scroll_to(page, direction)
                
                # Lazy loading için bekle
                await asyncio.sleep(wait_time / 1000)
                
                # Mevcut ilan sayısını kontrol et
                current_count = await self._count_listings(page, listing_selector)
                
                # Hedefe ulaşıldı mı?
                if current_count >= target_count:
                    return current_count
            
            # Son döngüdeyse dur
            if cycle == self.scroll_cycles - 1:
                break
        
        # Final count
        final_count = await self._count_listings(page, listing_selector)
        return final_count
    
    async def _scroll_to(self, page: Page, direction: str) -> None:
        """
        Sayfada belirli bir yöne scroll yap
        
        Args:
            page: Playwright page
            direction: Scroll yönü (top, middle, bottom)
        """
        try:
            if direction == 'bottom':
                await page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
            elif direction == 'top':
                await page.evaluate("window.scrollTo(0, 0)")
            elif direction == 'middle':
                await page.evaluate("window.scrollTo(0, document.body.scrollHeight / 2)")
        except Exception as e:
            # Scroll başarısız olursa sessizce geç
            pass
    
    async def _count_listings(self, page: Page, selector: str) -> int:
        """
        Mevcut ilan sayısını say
        
        Args:
            page: Playwright page
            selector: İlan link selector'ı
            
        Returns:
            int: İlan sayısı
        """
        try:
            elements = await page.query_selector_all(selector)
            return len(elements)
        except Exception:
            return 0
    
    async def scroll_to_bottom(self, page: Page, wait_time: int = 2000) -> None:
        """
        Sayfanın en altına scroll yap
        
        Args:
            page: Playwright page
            wait_time: Bekleme süresi (ms)
        """
        await self._scroll_to(page, 'bottom')
        await asyncio.sleep(wait_time / 1000)
    
    async def scroll_and_wait(
        self,
        page: Page,
        direction: str = 'bottom',
        wait_time: int = 1500
    ) -> None:
        """
        Scroll yap ve bekle
        
        Args:
            page: Playwright page
            direction: Scroll yönü
            wait_time: Bekleme süresi (ms)
        """
        await self._scroll_to(page, direction)
        await asyncio.sleep(wait_time / 1000)
    
    async def incremental_scroll(
        self,
        page: Page,
        steps: int = 10,
        step_delay: int = 500
    ) -> None:
        """
        Artımlı scroll (yavaş yavaş aşağı in)
        
        Args:
            page: Playwright page
            steps: Adım sayısı
            step_delay: Her adımda bekleme süresi (ms)
        """
        try:
            # Get page height
            page_height = await page.evaluate("document.body.scrollHeight")
            
            # Calculate step size
            step_size = page_height / steps
            
            for i in range(steps):
                scroll_position = int(i * step_size)
                await page.evaluate(f"window.scrollTo(0, {scroll_position})")
                await asyncio.sleep(step_delay / 1000)
        except Exception:
            # Fallback to simple scroll
            await self.scroll_to_bottom(page, 1000)
