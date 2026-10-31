# -*- coding: utf-8 -*-
"""
Arabam v4.0 - Selector Definitions
Her alan için 6+ fallback selector
Letgo v4.0 pattern implementation
"""

from dataclasses import dataclass
from enum import Enum
from typing import List, Optional, Dict


class SelectorType(str, Enum):
    """Selector tipi enum"""
    CSS = "css"
    XPATH = "xpath"
    TEXT = "text"
    REGEX = "regex"
    JS = "javascript"


@dataclass
class SelectorDefinition:
    """
    Selector tanımı
    
    Attributes:
        selector: CSS/XPath selector string
        selector_type: Selector tipi
        attribute: Get attribute name (optional)
        priority: Öncelik (1 = en yüksek)
        description: Açıklama
    """
    selector: str
    selector_type: SelectorType = SelectorType.CSS
    attribute: Optional[str] = None
    priority: int = 1
    description: str = ""


class ArabamSelectors:
    """
    Arabam.com selector tanımları
    
    Her alan için 6+ fallback selector.
    Letgo v4.0 pattern implementation.
    """
    
    # ==================== PRICE SELECTORS (10+) ====================
    PRICE_SELECTORS: List[SelectorDefinition] = [
        # Detail page selectors (öncelikli)
        SelectorDefinition(
            selector="h1, h2, h3",
            priority=1,
            description="Detail page heading (contains price)"
        ),
        SelectorDefinition(
            selector=".price-tag, .price-tag-container",
            priority=2,
            description="Detail page price tag"
        ),
        SelectorDefinition(
            selector=".gc-price, .price-value",
            priority=3,
            description="Detail page price value"
        ),
        SelectorDefinition(
            selector="[class*='Price'], [class*='price']",
            priority=4,
            description="Generic price class (detail page)"
        ),
        SelectorDefinition(
            selector="[id*='Price'], [id*='price']",
            priority=5,
            description="Generic price ID (detail page)"
        ),
        # Search page selectors
        SelectorDefinition(
            selector="[class*='fiyat']",
            priority=6,
            description="Turkish price class"
        ),
        SelectorDefinition(
            selector=".listing-price",
            priority=7,
            description="Listing price container"
        ),
        SelectorDefinition(
            selector="[data-price]",
            priority=8,
            description="Data attribute price"
        ),
        SelectorDefinition(
            selector=".price-container span",
            priority=9,
            description="Price container span"
        ),
        SelectorDefinition(
            selector="span:has-text('TL')",
            priority=10,
            description="TL text marker"
        ),
    ]
    
    # ==================== TITLE SELECTORS (6) ====================
    TITLE_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="h1[class*='title']",
            priority=1,
            description="Primary title"
        ),
        SelectorDefinition(
            selector="[class*='listing-title']",
            priority=2,
            description="Listing title class"
        ),
        SelectorDefinition(
            selector=".product-title",
            priority=3,
            description="Product title"
        ),
        SelectorDefinition(
            selector="[data-title]",
            priority=4,
            description="Data attribute title"
        ),
        SelectorDefinition(
            selector="h1",
            priority=5,
            description="Generic H1"
        ),
        SelectorDefinition(
            selector="[class*='baslik']",
            priority=6,
            description="Turkish title class"
        ),
    ]
    
    # ==================== KM SELECTORS (6) ====================
    KM_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="[class*='km']",
            priority=1,
            description="KM class"
        ),
        SelectorDefinition(
            selector="[data-km]",
            priority=2,
            description="Data attribute KM"
        ),
        SelectorDefinition(
            selector=".mileage",
            priority=3,
            description="Mileage class"
        ),
        SelectorDefinition(
            selector="span:has-text('km')",
            priority=4,
            description="KM text marker"
        ),
        SelectorDefinition(
            selector="[class*='kilometre']",
            priority=5,
            description="Turkish KM class"
        ),
        SelectorDefinition(
            selector="td:has-text('km') + td",
            priority=6,
            description="Table cell with KM"
        ),
    ]
    
    # ==================== YEAR SELECTORS (6) ====================
    YEAR_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="[class*='year']",
            priority=1,
            description="Year class"
        ),
        SelectorDefinition(
            selector="[data-year]",
            priority=2,
            description="Data attribute year"
        ),
        SelectorDefinition(
            selector=".model-year",
            priority=3,
            description="Model year class"
        ),
        SelectorDefinition(
            selector="span:has-text('Yıl')",
            priority=4,
            description="Year text marker"
        ),
        SelectorDefinition(
            selector="[class*='yil']",
            priority=5,
            description="Turkish year class"
        ),
        SelectorDefinition(
            selector="td:has-text('Yıl') + td",
            priority=6,
            description="Table cell with year"
        ),
    ]
    
    # ==================== FUEL SELECTORS (6) ====================
    FUEL_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="[class*='fuel']",
            priority=1,
            description="Fuel class"
        ),
        SelectorDefinition(
            selector="[data-fuel]",
            priority=2,
            description="Data attribute fuel"
        ),
        SelectorDefinition(
            selector=".fuel-type",
            priority=3,
            description="Fuel type class"
        ),
        SelectorDefinition(
            selector="span:has-text('Yakıt')",
            priority=4,
            description="Fuel text marker"
        ),
        SelectorDefinition(
            selector="[class*='yakit']",
            priority=5,
            description="Turkish fuel class"
        ),
        SelectorDefinition(
            selector="td:has-text('Yakıt') + td",
            priority=6,
            description="Table cell with fuel"
        ),
    ]
    
    # ==================== GEAR SELECTORS (6) ====================
    GEAR_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="[class*='gear']",
            priority=1,
            description="Gear class"
        ),
        SelectorDefinition(
            selector="[data-gear]",
            priority=2,
            description="Data attribute gear"
        ),
        SelectorDefinition(
            selector=".gear-type",
            priority=3,
            description="Gear type class"
        ),
        SelectorDefinition(
            selector="span:has-text('Vites')",
            priority=4,
            description="Gear text marker"
        ),
        SelectorDefinition(
            selector="[class*='vites']",
            priority=5,
            description="Turkish gear class"
        ),
        SelectorDefinition(
            selector="td:has-text('Vites') + td",
            priority=6,
            description="Table cell with gear"
        ),
    ]
    
    # ==================== COLOR SELECTORS (6) ====================
    COLOR_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="[class*='color']",
            priority=1,
            description="Color class"
        ),
        SelectorDefinition(
            selector="[data-color]",
            priority=2,
            description="Data attribute color"
        ),
        SelectorDefinition(
            selector=".exterior-color",
            priority=3,
            description="Exterior color class"
        ),
        SelectorDefinition(
            selector="span:has-text('Renk')",
            priority=4,
            description="Color text marker"
        ),
        SelectorDefinition(
            selector="[class*='renk']",
            priority=5,
            description="Turkish color class"
        ),
        SelectorDefinition(
            selector="td:has-text('Renk') + td",
            priority=6,
            description="Table cell with color"
        ),
    ]
    
    # ==================== PAINT SELECTORS (8 - KRİTİK) ====================
    PAINT_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="[class*='boya']",
            priority=1,
            description="Paint class"
        ),
        SelectorDefinition(
            selector="[class*='paint']",
            priority=2,
            description="English paint class"
        ),
        SelectorDefinition(
            selector="[data-paint]",
            priority=3,
            description="Data attribute paint"
        ),
        SelectorDefinition(
            selector=".paint-info",
            priority=4,
            description="Paint info container"
        ),
        SelectorDefinition(
            selector="td:has-text('boya') + td",
            priority=5,
            description="Table cell with paint"
        ),
        SelectorDefinition(
            selector="li:has-text('boyalı')",
            priority=6,
            description="List item with paint"
        ),
        SelectorDefinition(
            selector="span:has-text('değişen')",
            priority=7,
            description="Changed part marker"
        ),
        SelectorDefinition(
            selector=".damage-info",
            priority=8,
            description="Damage info container"
        ),
    ]
    
    # ==================== PACKAGE SELECTORS (6) ====================
    PACKAGE_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="[class*='package']",
            priority=1,
            description="Package class"
        ),
        SelectorDefinition(
            selector="[class*='equipment']",
            priority=2,
            description="Equipment class"
        ),
        SelectorDefinition(
            selector=".features-list",
            priority=3,
            description="Features list"
        ),
        SelectorDefinition(
            selector="span:has-text('Donanım')",
            priority=4,
            description="Equipment text marker"
        ),
        SelectorDefinition(
            selector="[class*='ekipman']",
            priority=5,
            description="Turkish equipment class"
        ),
        SelectorDefinition(
            selector="td:has-text('Donanım') + td",
            priority=6,
            description="Table cell with equipment"
        ),
    ]
    
    # ==================== IMAGE URL SELECTORS (8 - KRİTİK) ====================
    # 1. görsel (dış görünüş) için selector'ler
    IMAGE_URL_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector=".gallery-container img",
            priority=1,
            description="Gallery container first image",
            attribute="src"
        ),
        SelectorDefinition(
            selector=".image-gallery img:first-of-type",
            priority=2,
            description="Image gallery first image",
            attribute="src"
        ),
        SelectorDefinition(
            selector="[class*='gallery'] img",
            priority=3,
            description="Generic gallery image",
            attribute="src"
        ),
        SelectorDefinition(
            selector="img[class*='listing']",
            priority=4,
            description="Listing image class",
            attribute="src"
        ),
        SelectorDefinition(
            selector="img[data-src]",
            priority=5,
            description="Lazy loaded image (data-src)",
            attribute="data-src"
        ),
        SelectorDefinition(
            selector=".product-image img",
            priority=6,
            description="Product image container",
            attribute="src"
        ),
        SelectorDefinition(
            selector="[class*='car-image'] img",
            priority=7,
            description="Car image container",
            attribute="src"
        ),
        SelectorDefinition(
            selector="img[src*='arabam']",
            priority=8,
            description="Any arabam.com image",
            attribute="src"
        ),
    ]
    
    # ==================== LISTING LINK SELECTORS (6) ====================
    # KRİTİK: /ilan/ selector'ü en başta - kategori linklerini engellemek için
    LISTING_LINK_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="a[href*='/ilan/']",
            priority=1,
            description="Ilan link (KRITIK - en specific)",
            attribute="href"
        ),
        SelectorDefinition(
            selector="[class*='listing'] a[href]",
            priority=2,
            description="Listing card link",
            attribute="href"
        ),
        SelectorDefinition(
            selector="[class*='item'] a[href]",
            priority=3,
            description="Item card link",
            attribute="href"
        ),
        SelectorDefinition(
            selector="[data-listing-id] a",
            priority=4,
            description="Data attribute link",
            attribute="href"
        ),
        SelectorDefinition(
            selector="a[href*='-detay']",
            priority=5,
            description="Detail page link",
            attribute="href"
        ),
        SelectorDefinition(
            selector="a[href*='/ikinci-el/']",
            priority=6,
            description="Second hand link (geniş - son çare)",
            attribute="href"
        ),
    ]
    
    # ==================== SELLER TYPE SELECTORS (6) ====================
    SELLER_TYPE_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="[class*='seller']",
            priority=1,
            description="Seller class"
        ),
        SelectorDefinition(
            selector="[data-seller]",
            priority=2,
            description="Data attribute seller"
        ),
        SelectorDefinition(
            selector=".seller-type",
            priority=3,
            description="Seller type class"
        ),
        SelectorDefinition(
            selector="span:has-text('Satıcı')",
            priority=4,
            description="Seller text marker"
        ),
        SelectorDefinition(
            selector="[class*='satici']",
            priority=5,
            description="Turkish seller class"
        ),
        SelectorDefinition(
            selector="td:has-text('Satıcı') + td",
            priority=6,
            description="Table cell with seller"
        ),
    ]
    
    # ==================== LOCATION SELECTORS (6) ====================
    LOCATION_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="[class*='location']",
            priority=1,
            description="Location class"
        ),
        SelectorDefinition(
            selector="[data-location]",
            priority=2,
            description="Data attribute location"
        ),
        SelectorDefinition(
            selector=".city-name",
            priority=3,
            description="City name class"
        ),
        SelectorDefinition(
            selector="span:has-text('İl')",
            priority=4,
            description="Location text marker"
        ),
        SelectorDefinition(
            selector="[class*='il']",
            priority=5,
            description="Turkish location class"
        ),
        SelectorDefinition(
            selector="td:has-text('İl') + td",
            priority=6,
            description="Table cell with location"
        ),
    ]
    
    # ==================== ENGINE SIZE SELECTORS (6) ====================
    ENGINE_SIZE_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="[class*='engine']",
            priority=1,
            description="Engine class"
        ),
        SelectorDefinition(
            selector="[data-engine]",
            priority=2,
            description="Data attribute engine"
        ),
        SelectorDefinition(
            selector=".engine-size",
            priority=3,
            description="Engine size class"
        ),
        SelectorDefinition(
            selector="span:has-text('Motor')",
            priority=4,
            description="Engine text marker"
        ),
        SelectorDefinition(
            selector="[class*='motor']",
            priority=5,
            description="Turkish engine class"
        ),
        SelectorDefinition(
            selector="td:has-text('Motor') + td",
            priority=6,
            description="Table cell with engine"
        ),
    ]
    
    # ==================== HORSEPOWER SELECTORS (6) ====================
    HORSEPOWER_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="[class*='hp']",
            priority=1,
            description="HP class"
        ),
        SelectorDefinition(
            selector="[data-hp]",
            priority=2,
            description="Data attribute HP"
        ),
        SelectorDefinition(
            selector=".horsepower",
            priority=3,
            description="Horsepower class"
        ),
        SelectorDefinition(
            selector="span:has-text('Beygir')",
            priority=4,
            description="HP text marker"
        ),
        SelectorDefinition(
            selector="[class*='beygir']",
            priority=5,
            description="Turkish HP class"
        ),
        SelectorDefinition(
            selector="td:has-text('Beygir') + td",
            priority=6,
            description="Table cell with HP"
        ),
    ]
    
    # ==================== DATE SELECTORS (10) ====================
    DATE_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="span.date",
            priority=1,
            description="Primary date span"
        ),
        SelectorDefinition(
            selector="span.publishing-date",
            priority=2,
            description="Publishing date class"
        ),
        SelectorDefinition(
            selector="div.listing-date",
            priority=3,
            description="Listing date div"
        ),
        SelectorDefinition(
            selector="time",
            priority=4,
            description="HTML5 time element"
        ),
        SelectorDefinition(
            selector="[data-date]",
            priority=5,
            description="Data attribute date"
        ),
        SelectorDefinition(
            selector="[class*='tarih']",
            priority=6,
            description="Turkish date class"
        ),
        SelectorDefinition(
            selector="td:has-text('tarih') + td",
            priority=7,
            description="Table cell with date"
        ),
        SelectorDefinition(
            selector="p:has-text('İlan Tarihi')",
            priority=8,
            description="Text based date lookup"
        ),
        SelectorDefinition(
            selector="li:has-text('İlan Tarihi')",
            priority=9,
            description="List based date lookup"
        ),
        SelectorDefinition(
            selector="[class*='publish']",
            priority=10,
            description="Generic publish marker"
        ),
    ]
    
    # ==================== COOKIE SELECTORS (8) ====================
    COOKIE_SELECTORS: List[SelectorDefinition] = [
        SelectorDefinition(
            selector="button[id*='accept']",
            priority=1,
            description="Accept button with ID"
        ),
        SelectorDefinition(
            selector="button[class*='accept']",
            priority=2,
            description="Accept button with class"
        ),
        SelectorDefinition(
            selector=".cookie-accept",
            priority=3,
            description="Cookie accept class"
        ),
        SelectorDefinition(
            selector="button:has-text('Kabul')",
            priority=4,
            description="Kabul text button"
        ),
        SelectorDefinition(
            selector="button:has-text('Tamam')",
            priority=5,
            description="Tamam text button"
        ),
        SelectorDefinition(
            selector=".kvkk-accept",
            priority=6,
            description="KVKK accept class"
        ),
        SelectorDefinition(
            selector=".cookie-policy-accept",
            priority=7,
            description="Cookie policy accept"
        ),
        SelectorDefinition(
            selector="div.cookie-consent button",
            priority=8,
            description="Cookie consent button"
        ),
    ]
    
    @classmethod
    def get_all_selectors(cls) -> Dict[str, List[SelectorDefinition]]:
        """
        Tüm selector gruplarını döndür
        
        Returns:
            Dict[str, List[SelectorDefinition]]: Selector grupları
        """
        return {
            "price": cls.PRICE_SELECTORS,
            "title": cls.TITLE_SELECTORS,
            "km": cls.KM_SELECTORS,
            "year": cls.YEAR_SELECTORS,
            "fuel": cls.FUEL_SELECTORS,
            "gear": cls.GEAR_SELECTORS,
            "color": cls.COLOR_SELECTORS,
            "paint": cls.PAINT_SELECTORS,
            "package": cls.PACKAGE_SELECTORS,
            "image_url": cls.IMAGE_URL_SELECTORS,
            "listing_link": cls.LISTING_LINK_SELECTORS,
            "seller_type": cls.SELLER_TYPE_SELECTORS,
            "location": cls.LOCATION_SELECTORS,
            "engine_size": cls.ENGINE_SIZE_SELECTORS,
            "horsepower": cls.HORSEPOWER_SELECTORS,
            "cookie": cls.COOKIE_SELECTORS,
        }
    
    @classmethod
    def get_selector_count(cls) -> Dict[str, int]:
        """
        Her gruptaki selector sayısını döndür
        
        Returns:
            Dict[str, int]: Selector sayıları
        """
        return {
            name: len(selectors)
            for name, selectors in cls.get_all_selectors().items()
        }
