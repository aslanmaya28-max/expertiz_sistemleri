# -*- coding: utf-8 -*-
"""
Arabam v4.0 - URL Builder
4 alternatif URL formatı
Letgo v4.0 pattern implementation
"""

from typing import List, Dict, Any, Optional
from .turkish_chars import TurkishCharacterHandler


class ArabamURLBuilder:
    """
    URL Builder - 4 alternatif URL formatı
    
    Arabam.com için farklı URL formatları oluşturur.
    Her format bir öncekinin başarısız olması durumunda fallback olarak kullanılır.
    """
    
    BASE_URL = "https://www.arabam.com"
    SECOND_HAND_PATH = "/ikinci-el/otomobil"
    
    def __init__(self):
        """Initialize URL builder"""
        self.char_handler = TurkishCharacterHandler()
    
    def build_search_urls(
        self,
        brand: str,
        model: str,
        year: Optional[int] = None,
        min_price: Optional[int] = None,
        max_price: Optional[int] = None
    ) -> List[Dict[str, Any]]:
        """
        4 alternatif URL oluştur
        
        Args:
            brand: Marka adı
            model: Model adı
            year: Model yılı (optional)
            min_price: Minimum fiyat (optional)
            max_price: Maksimum fiyat (optional)
            
        Returns:
            List[Dict[str, Any]]: URL listesi (priority order)
        """
        # Türkçe karakterleri normalize et
        brand_slug = self.char_handler.to_url_slug(brand)
        model_slug = self.char_handler.to_url_slug(model)
        
        urls = []
        
        # URL 1: Standard (highest priority)
        url1 = f"{self.BASE_URL}{self.SECOND_HAND_PATH}/{brand_slug}-{model_slug}"
        if year:
            url1 += f"?minYear={year}&maxYear={year}"
        urls.append({
            "url": url1,
            "pattern": "standard",
            "priority": 1,
            "description": "Standard URL with year filter"
        })
        
        # URL 2: With year filter (if year provided)
        if year:
            url2 = f"{self.BASE_URL}{self.SECOND_HAND_PATH}/{brand_slug}-{model_slug}"
            url2 += f"?minYear={year}&maxYear={year}"
            urls.append({
                "url": url2,
                "pattern": "with_year",
                "priority": 2,
                "description": "URL with explicit year filter"
            })
        
        # URL 3: Full search with price
        url3 = f"{self.BASE_URL}{self.SECOND_HAND_PATH}/{brand_slug}-{model_slug}"
        params = []
        if year:
            params.append(f"minYear={year}&maxYear={year}")
        if min_price:
            params.append(f"minPrice={min_price}")
        if max_price:
            params.append(f"maxPrice={max_price}")
        if params:
            url3 += "?" + "&".join(params)
        urls.append({
            "url": url3,
            "pattern": "full_search",
            "priority": 3,
            "description": "Full search with all filters"
        })
        
        # URL 4: Category-based fallback
        url4 = f"{self.BASE_URL}{self.SECOND_HAND_PATH}"
        url4_params = []
        url4_params.append(f"search={brand_slug}+{model_slug}")
        if year:
            url4_params.append(f"year={year}")
        url4 += "?" + "&".join(url4_params)
        urls.append({
            "url": url4,
            "pattern": "category",
            "priority": 4,
            "description": "Category-based search"
        })
        
        return urls
    
    def build_detail_url(self, listing_id: str) -> str:
        """
        Detay sayfası URL'i oluştur
        
        Args:
            listing_id: İlan ID
            
        Returns:
            str: Detay sayfası URL'i
        """
        return f"{self.BASE_URL}/ilan/{listing_id}"
    
    def is_valid_url(self, url: str) -> bool:
        """
        URL geçerli mi?
        
        Args:
            url: URL string
            
        Returns:
            bool: True if valid
        """
        return url.startswith(self.BASE_URL)
    
    def extract_listing_id(self, url: str) -> Optional[str]:
        """
        URL'den ilan ID'sini çıkar
        
        Args:
            url: İlan URL'i
            
        Returns:
            Optional[str]: İlan ID veya None
        """
        if "/ilan/" in url:
            parts = url.split("/ilan/")
            if len(parts) > 1:
                return parts[1].split("-")[0]
        return None
    
    def normalize_url(self, url: str) -> str:
        """
        URL'i normalize et
        
        Args:
            url: Input URL
            
        Returns:
            str: Normalized URL
        """
        # Remove trailing slash
        url = url.rstrip("/")
        
        # Ensure https
        if url.startswith("http://"):
            url = url.replace("http://", "https://", 1)
        
        return url
    
    @classmethod
    def get_url_pattern(cls, url: str) -> Optional[str]:
        """
        URL pattern'ini tespit et
        
        Args:
            url: URL string
            
        Returns:
            Optional[str]: Pattern adı veya None
        """
        if "/ikinci-el/otomobil/" in url and "?" not in url:
            return "standard"
        elif "/ikinci-el/otomobil/" in url and "minYear" in url:
            return "with_year"
        elif "/ikinci-el/otomobil/" in url and "minPrice" in url:
            return "full_search"
        elif "/ikinci-el/otomobil" in url and "search=" in url:
            return "category"
        return None
