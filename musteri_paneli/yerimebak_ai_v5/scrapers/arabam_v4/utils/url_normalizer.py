# -*- coding: utf-8 -*-
"""
Arabam v5.0 - URL Normalizer
URL normalization ve duplicate prevention
"""

from urllib.parse import urlparse, urlunparse
from typing import Optional
import re


class URLNormalizer:
    """
    URL normalization ve duplicate prevention
    
    Arabam.com'da aynı ilan farklı query parametreleri ile 
    birden fazla kez görünebilir. Bu sınıf bu duplicate'leri 
    temizlemek için kullanılır.
    """
    
    @staticmethod
    def normalize(url: str) -> str:
        """
        URL'den query parametrelerini temizle
        
        Args:
            url: Normalizasyon yapılacak URL
            
        Returns:
            str: Temizlenmiş URL
            
        Examples:
            >>> URLNormalizer.normalize("/ilan/abc/123?source=listing&utm=xxx")
            "/ilan/abc/123"
            >>> URLNormalizer.normalize("https://www.arabam.com/ilan/abc/123?ref=google")
            "https://www.arabam.com/ilan/abc/123"
        """
        if not url:
            return ""
        
        # Parse URL
        try:
            parsed = urlparse(url)
            
            # Remove query parameters and fragment
            clean_url = urlunparse((
                parsed.scheme,
                parsed.netloc,
                parsed.path,  # Keep only path
                '',          # Remove params
                '',          # Remove query
                ''           # Remove fragment
            ))
            
            return clean_url
        except Exception:
            # Fallback: manual cleaning
            if '?' in url:
                url = url.split('?')[0]
            if '#' in url:
                url = url.split('#')[0]
            return url
    
    @staticmethod
    def extract_listing_id(url: str) -> Optional[str]:
        """
        URL'den ilan ID'sini çıkar
        
        Args:
            url: İlan URL'si
            
        Returns:
            Optional[str]: İlan ID veya None
            
        Examples:
            >>> URLNormalizer.extract_listing_id("/ilan/abc/12345")
            "12345"
            >>> URLNormalizer.extract_listing_id("https://www.arabam.com/ilan/.../37982515")
            "37982515"
        """
        if not url:
            return None
        
        try:
            # Normalize first
            normalized = URLNormalizer.normalize(url)
            
            # Extract ID from URL path
            # Pattern: /ilan/.../listing_id or /listing_id
            parts = normalized.rstrip('/').split('/')
            
            # Last part should be the ID
            if parts:
                last_part = parts[-1]
                
                # Check if it's numeric (listing ID)
                if last_part.isdigit():
                    return last_part
                
                # Try to find numeric ID in last part
                # Pattern: abc-12345 or abc12345
                numbers = re.findall(r'\d+', last_part)
                if numbers:
                    return numbers[-1]  # Last number is likely the ID
            
            return None
        except Exception:
            return None
    
    @staticmethod
    def is_duplicate(url1: str, url2: str) -> bool:
        """
        İki URL'nin aynı ilana ait olup olmadığını kontrol et
        
        Args:
            url1: İlk URL
            url2: İkinci URL
            
        Returns:
            bool: True if same listing (duplicate)
            
        Examples:
            >>> URLNormalizer.is_duplicate(
            ...     "/ilan/abc/123",
            ...     "/ilan/abc/123?source=listing"
            ... )
            True
            >>> URLNormalizer.is_duplicate(
            ...     "/ilan/abc/123",
            ...     "/ilan/xyz/456"
            ... )
            False
        """
        # Normalize both URLs
        norm1 = URLNormalizer.normalize(url1)
        norm2 = URLNormalizer.normalize(url2)
        
        # Compare
        return norm1 == norm2
    
    @staticmethod
    def build_page_url(base_url: str, page_num: int) -> str:
        """
        Sayfa numarası ile URL oluştur
        
        Args:
            base_url: Base URL
            page_num: Sayfa numarası
            
        Returns:
            str: Sayfa URL'si
            
        Examples:
            >>> URLNormalizer.build_page_url(
            ...     "https://www.arabam.com/ikinci-el/otomobil/volkswagen-golf",
            ...     2
            ... )
            "https://www.arabam.com/ikinci-el/otomobil/volkswagen-golf?sayfa=2"
        """
        separator = '&' if '?' in base_url else '?'
        return f"{base_url}{separator}sayfa={page_num}"
    
    @staticmethod
    def get_domain(url: str) -> str:
        """
        URL'den domain'i çıkar
        
        Args:
            url: URL
            
        Returns:
            str: Domain
            
        Examples:
            >>> URLNormalizer.get_domain("https://www.arabam.com/ilan/abc")
            "www.arabam.com"
        """
        try:
            parsed = urlparse(url)
            return parsed.netloc
        except Exception:
            return ""
