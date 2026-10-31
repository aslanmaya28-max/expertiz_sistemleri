# -*- coding: utf-8 -*-
"""
Arabam v4.0 - Turkish Character Handler
Türkçe karakter normalizasyonu - Arabam.com URL'leri için gerekli
"""

import re
from typing import Optional


class TurkishCharacterHandler:
    """
    Türkçe karakter normalizasyonu
    
    Arabam.com URL'leri Türkçe karakterleri kabul etmez.
    Bu sınıf Türkçe karakterleri İngilizce karşılıklarına çevirir.
    """
    
    CHAR_MAP = {
        "ç": "c", "Ç": "C",
        "ğ": "g", "Ğ": "G",
        "ı": "i", "İ": "I",
        "ö": "o", "Ö": "O",
        "ş": "s", "Ş": "S",
        "ü": "u", "Ü": "U",
    }
    
    @classmethod
    def normalize(cls, text: str) -> str:
        """
        Türkçe karakterleri İngilizce karşılıklarına çevir
        
        Args:
            text: Input text
            
        Returns:
            str: Normalized text
            
        Examples:
            >>> TurkishCharacterHandler.normalize("Çorum")
            'Corum'
            >>> TurkishCharacterHandler.normalize("Şanlıurfa")
            'Sanliurfa'
        """
        for tr, en in cls.CHAR_MAP.items():
            text = text.replace(tr, en)
        return text
    
    @classmethod
    def to_url_slug(cls, text: str) -> str:
        """
        URL slug oluştur
        
        Türkçe karakterleri normalize eder, küçük harfe çevirir,
        non-alphanumeric karakterleri tire ile değiştirir.
        
        Args:
            text: Input text
            
        Returns:
            str: URL-safe slug
            
        Examples:
            >>> TurkishCharacterHandler.to_url_slug("Volkswagen Golf")
            'volkswagen-golf'
            >>> TurkishCharacterHandler.to_url_slug("Şahin")
            'sahin'
        """
        # Normalize Turkish characters
        slug = cls.normalize(text)
        
        # Convert to lowercase
        slug = slug.lower()
        
        # Replace non-alphanumeric with hyphens
        slug = re.sub(r"[^a-z0-9]+", "-", slug)
        
        # Remove leading/trailing hyphens
        slug = slug.strip("-")
        
        # Remove multiple consecutive hyphens
        slug = re.sub(r"-+", "-", slug)
        
        return slug
    
    @classmethod
    def normalize_brand(cls, brand: str) -> str:
        """
        Marka adını normalize et
        
        Args:
            brand: Marka adı
            
        Returns:
            str: Normalized marka adı
        """
        return cls.to_url_slug(brand)
    
    @classmethod
    def normalize_model(cls, model: str) -> str:
        """
        Model adını normalize et
        
        Args:
            model: Model adı
            
        Returns:
            str: Normalized model adı
        """
        return cls.to_url_slug(model)
    
    @classmethod
    def build_url_slug(cls, brand: str, model: Optional[str] = None) -> str:
        """
        URL slug oluştur (marka-model)
        
        Args:
            brand: Marka adı
            model: Model adı (optional)
            
        Returns:
            str: URL slug
            
        Examples:
            >>> TurkishCharacterHandler.build_url_slug("Volkswagen", "Golf")
            'volkswagen-golf'
            >>> TurkishCharacterHandler.build_url_slug("Renault")
            'renault'
        """
        brand_slug = cls.normalize_brand(brand)
        
        if model:
            model_slug = cls.normalize_model(model)
            return f"{brand_slug}-{model_slug}"
        
        return brand_slug
    
    @classmethod
    def is_turkish(cls, text: str) -> bool:
        """
        Metin Türkçe karakter içeriyor mu?
        
        Args:
            text: Input text
            
        Returns:
            bool: True if contains Turkish characters
        """
        return any(char in cls.CHAR_MAP for char in text)
    
    @classmethod
    def get_turkish_chars(cls, text: str) -> list:
        """
        Metindeki Türkçe karakterleri döndür
        
        Args:
            text: Input text
            
        Returns:
            list: Türkçe karakter listesi
        """
        return [char for char in text if char in cls.CHAR_MAP]
