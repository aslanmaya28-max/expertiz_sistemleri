# -*- coding: utf-8 -*-
"""
Arabam v4.0 - Base Extractor
Template method pattern ile selector fallback
Letgo v4.0 pattern implementation
"""

from abc import ABC, abstractmethod
from typing import Generic, TypeVar, Optional, List, Any
from playwright.async_api import Page
from .selectors import SelectorDefinition

T = TypeVar('T')


class BaseExtractor(ABC, Generic[T]):
    """
    Base extractor class
    
    Template method pattern ile selector fallback mekanizması.
    Letgo v4.0 pattern implementation.
    
    Tüm extractor'lar bu sınıftan türetilir.
    """
    
    def __init__(self, page: Page):
        """
        Initialize base extractor
        
        Args:
            page: Playwright page instance
        """
        self.page = page
        self._extraction_log = []
    
    @abstractmethod
    async def extract(self) -> T:
        """
        Veri çıkar - Alt sınıflar implement etmeli
        
        Returns:
            T: Çıkarılan veri tipi
        """
        pass
    
    async def try_selectors(
        self,
        selectors: List[SelectorDefinition],
        transform_func: Optional[callable] = None,
    ) -> Optional[Any]:
        """
        Sequential selector attempts with fallback
        
        Her selector'ı sırayla dener, başarılı olanı döndürür.
        
        Args:
            selectors: Selector listesi (priority order)
            transform_func: Optional transform function
            
        Returns:
            Optional[Any]: Çıkarılan değer veya None
        """
        for selector_def in selectors:
            try:
                element = await self.page.query_selector(selector_def.selector)
                if element:
                    # Get text or attribute
                    if selector_def.attribute:
                        value = await element.get_attribute(selector_def.attribute)
                    else:
                        value = await element.inner_text()
                    
                    # Transform if needed
                    if transform_func and value:
                        value = transform_func(value)
                    
                    if value is not None:
                        self._extraction_log.append({
                            'selector': selector_def.selector,
                            'priority': selector_def.priority,
                            'success': True,
                            'value': str(value)[:100],  # Log first 100 chars
                        })
                        return value
                        
            except Exception as e:
                self._extraction_log.append({
                    'selector': selector_def.selector,
                    'priority': selector_def.priority,
                    'success': False,
                    'error': str(e)[:100],  # Log first 100 chars
                })
                continue
        
        return None
    
    async def try_multiple_selectors(
        self,
        selector_groups: List[List[SelectorDefinition]],
        transform_func: Optional[callable] = None,
    ) -> List[Any]:
        """
        Multiple selector groups attempt
        
        Farklı selector gruplarını dener ve tüm sonuçları döndürür.
        
        Args:
            selector_groups: Selector grupları
            transform_func: Optional transform function
            
        Returns:
            List[Any]: Başarılı sonuçlar listesi
        """
        results = []
        
        for selectors in selector_groups:
            result = await self.try_selectors(selectors, transform_func)
            if result is not None:
                results.append(result)
        
        return results
    
    def get_extraction_log(self) -> List[dict]:
        """
        Extraction loglarını döndür
        
        Returns:
            List[dict]: Log kayıtları
        """
        return self._extraction_log
    
    def get_success_count(self) -> int:
        """
        Başarılı extraction sayısını döndür
        
        Returns:
            int: Başarılı sayı
        """
        return sum(1 for log in self._extraction_log if log.get('success', False))
    
    def get_failure_count(self) -> int:
        """
        Başarısız extraction sayısını döndür
        
        Returns:
            int: Başarısız sayı
        """
        return sum(1 for log in self._extraction_log if not log.get('success', True))
    
    def clear_log(self) -> None:
        """Extraction logunu temizle"""
        self._extraction_log.clear()
    
    def get_success_rate(self) -> float:
        """
        Başarı oranını hesapla
        
        Returns:
            float: Başarı oranı (0-1)
        """
        total = len(self._extraction_log)
        if total == 0:
            return 0.0
        return self.get_success_count() / total
