# -*- coding: utf-8 -*-
"""
Arabam v4.0 - Package Extractor
Donanım/Ekipman bilgisi çıkarıcı
"""

from typing import List, Dict, Optional
from playwright.async_api import Page
from ..models.package_info import PackageInfo
from .base_extractor import BaseExtractor
from .selectors import ArabamSelectors


class PackageExtractor(BaseExtractor[PackageInfo]):
    """
    Donanım/Ekipman bilgisi çıkarıcı
    
    Arabam.com'da araçların donanım paketlerini ve
    ekipman bilgilerini çıkarır.
    """
    
    # Feature keyword'leri - GENİŞLETİLMİŞ VERSİYON
    FEATURE_KEYWORDS = {
        'safety': [
            'abs', 'esp', 'airbag', 'hava yastığı', 'yokuş kalkış',
            'dergili', 'basınç dağıtıcı', 'lastik takip', 'şerit takip',
            'adaptif far', 'far sensörü', 'sürüş kontrolü',
            # Turkish safety features
            'hava yastığı', 'sürücü airbag', 'yolcu airbag', 'yan airbag',
            'perde airbag', 'diz airbag', 'hba', 'hill holder', 'hill start',
            'asr', 'eds', 'xds', 'tpms', 'lastik basınç', 'şerit yardımcı',
            'adaptif cruise', 'acc', 'sürüş asistanı', 'bağılantılı asistan',
            'çarpışma önleyici', 'otomatik fren', 'emergency brake',
            'trafik işareti', 'speed limit', 'hız sınırlayıcı',
        ],
        'comfort': [
            'klima', 'klimalı', 'otomatik klima', 'çift bölgeli klima',
            'deri', 'deri koltuk', 'isıtmalı', 'soğutmalı',
            'elektrikli', 'ayarlanabilir', 'koltuk',
            'sunroof', 'açılır tavan', 'panoramik',
            # Turkish comfort features
            'manuel klima', 'dijital klima', '4 bölgeli klima',
            'elektrikli cam', 'elektrikli ayna', 'katlanır ayna',
            'ısıtmalı ön koltuk', 'ısıtmalı arka koltuk', 'soğutmalı koltuk',
            'hafızalı koltuk', 'masajlı koltuk', 'elektrikli bel desteği',
            'deri direksiyon', 'ısıtmalı direksiyon', 'multifonksiyonlu direksiyon',
            'cruise control', 'hız sabitleyici', 'tempomat',
            'otomatik kararan dikiz', 'electrochromic', 'auto dimming',
        ],
        'technology': [
            'navigasyon', 'gps', 'harita',
            'kamera', 'geri görüş', 'park sensörü', 'park assist',
            'bluetooth', 'usb', 'android', 'apple carplay',
            'ekran', 'touch', 'dokunmatik',
            # Turkish technology features
            'multimedya ekranı', 'infotainment', 'entertainment',
            'geri görüş kamerası', '360 kamera', 'etraf kamera',
            'ön park sensörü', 'arka park sensörü', 'yan park sensörü',
            'otomatik park', 'park asistanı', 'park pilot',
            'android auto', 'carplay', 'mirrorlink', 'wireless',
            'head up display', 'hud', 'ön gösterge', 'headup',
            'dijital gösterge', 'digital cockpit', 'virtual cockpit',
            'harita güncelleme', 'online servis', 'connected',
            'wifi hotspot', '4g', 'lte', 'internet',
        ],
        'performance': [
            'spor', 'sport', 'r', 'gti', 'gt',
            'spor koltuk', 'spor direksiyon', 'paddle shift',
            'sport modu', 'sürüş modu',
            # Turkish performance features
            'dsg', 'tiptronic', 's-tronic', 'pdk',
            'launch control', 'başlangıç kontrolü',
            'sport chrono', 'sport plus', 'race',
            'adaptif süspansiyon', 'havalı süspansiyon', 'air suspension',
            'mühendislik modu', 'individual', 'eco', 'comfort', 'sport',
            'diferansiyel kilit', 'lsd', 'xds', 'quattro', '4motion', 'awd',
        ],
    }
    
    # Special features - GENİŞLETİLMİŞ VERSİYON
    SPECIAL_FEATURES = {
        'has_park_assist': ['park assist', 'otomatik park', 'park asistanı', 'park pilot', 'park asistan'],
        'has_camera': ['kamera', 'geri görüş', 'arka kamera', '360 kamera', 'etraf kamera', 'geri dönüş kamerası'],
        'has_navigation': ['navigasyon', 'gps', 'harita', 'navigation', 'navi'],
        'has_leather': ['deri', 'deri koltuk', 'leather', 'leather seat', 'deri döşeme'],
        'has_sunroof': ['sunroof', 'açılır tavan', 'panoramik tavan', 'panoramik cam', 'moonroof'],
        'has_heated_seats': ['ısıtmalı koltuk', 'heated seat', 'seat heater', 'koltuk ısıtma'],
        'has_cooled_seats': ['soğutmalı koltuk', 'cooled seat', 'ventilated seat', 'koltuk soğutma'],
        'has_memory_seats': ['hafızalı koltuk', 'memory seat', 'koltuk hafıza'],
        'has_massage_seats': ['masajlı koltuk', 'massage seat', 'koltuk masaj'],
        'has_head_up_display': ['head up display', 'hud', 'headup', 'ön gösterge'],
        'has_digital_cluster': ['dijital gösterge', 'digital cockpit', 'virtual cockpit', 'active info'],
        'has_adaptive_cruise': ['adaptive cruise', 'acc', 'adaptif cruise', 'hız sabitleyici'],
        'has_lane_assist': ['şerit takip', 'lane assist', 'lane keep', 'şerit yardımcı'],
        'has_blind_spot': ['kör nokta', 'blind spot', 'kör nokta uyarısı'],
        'has_keyless': ['keyless', 'keyless go', 'anahtarsız', 'start stop'],
        'has_wireless_charging': ['kablosuz şarj', 'wireless charging', 'induction charging'],
    }
    
    # Common package names for Turkish market
    PACKAGE_NAMES = [
        'comfortline', 'trendline', 'highline', 'elegance', 'avantgarde',
        'ambition', 'sportline', 'style', 'business', 'executive',
        'premium', 'premium plus', 'luxury', 'ultimate', 'sport',
        'base', 'concept', 'life', 'active', 'advance',
        # Turkish package names
        'konfor', 'spor', 'lux', 'premium', 'elite',
        'business', 'executive', 'ultimate', 'sport plus',
    ]
    
    def __init__(self, page: Page):
        """
        Initialize package extractor
        
        Args:
            page: Playwright page instance
        """
        super().__init__(page)
        self.selectors = ArabamSelectors()
    
    async def extract(self) -> PackageInfo:
        """
        Donanım bilgisi çıkar - İYİLEŞTİRİLMİŞ VERSİYON
        
        Returns:
            PackageInfo: Donanım bilgisi modeli
        """
        package_info = PackageInfo()
        
        # Yöntem 1: Tablo/listeden çıkar
        list_result = await self._extract_from_list()
        
        # Yöntem 2: Sayfa metninden çıkar
        text_result = await self._extract_from_page_text()
        
        # Yöntem 3: Paket adı tespiti (YENİ)
        package_name = await self._extract_package_name()
        if package_name:
            package_info.packages.append(package_name)
        
        # Merge sonuçları
        package_info = self._merge_results(package_info, list_result, text_result)
        
        # Özellikleri kategorize et
        package_info = self._categorize_features(package_info)
        
        # Sayıları güncelle
        package_info.total_features = len(package_info.features)
        
        # Kalite skoru hesapla
        package_info.confidence_score = self._calculate_confidence(package_info)
        
        # Logging
        if package_info.total_features > 0:
            print(f"   📦 Paket: {package_info.total_features} özellik bulundu")
            if package_info.packages:
                print(f"      Paket adı: {', '.join(package_info.packages)}")
        
        return package_info
    
    async def _extract_from_list(self) -> dict:
        """
        Liste yapısından donanım bilgisi çıkar
        
        Returns:
            dict: Donanım bilgisi
        """
        result = {
            'features': [],
            'packages': [],
        }
        
        try:
            # List items
            items = await self.page.query_selector_all("li")
            for item in items:
                text = await item.inner_text()
                text = text.strip().lower()
                
                if len(text) > 2 and len(text) < 100:
                    # Feature olarak ekle
                    if text not in result['features']:
                        result['features'].append(text)
        except Exception as e:
            self._extraction_log.append({
                'method': 'list_extraction',
                'success': False,
                'error': str(e)[:100]
            })
        
        return result
    
    async def _extract_from_page_text(self) -> dict:
        """
        Sayfa metninden donanım bilgisi çıkar
        
        Returns:
            dict: Donanım bilgisi
        """
        result = {
            'features': [],
            'special_features': {},
        }
        
        try:
            page_text = await self.page.inner_text("body")
            page_text_lower = page_text.lower()
            
            # Special features kontrolü
            for feature, keywords in self.SPECIAL_FEATURES.items():
                for keyword in keywords:
                    if keyword in page_text_lower:
                        result['special_features'][feature] = True
                        break
        except Exception as e:
            self._extraction_log.append({
                'method': 'text_extraction',
                'success': False,
                'error': str(e)[:100]
            })
        
        return result
    
    async def _extract_package_name(self) -> Optional[str]:
        """
        Paket adını çıkar (Comfortline, Highline, vb.)
        
        Returns:
            Optional[str]: Paket adı veya None
        """
        try:
            page_text = await self.page.inner_text("body")
            page_text_lower = page_text.lower()
            
            # Check for package names
            for package_name in self.PACKAGE_NAMES:
                if package_name.lower() in page_text_lower:
                    return package_name.capitalize()
            
            # Also check in title and headings
            title_elements = await self.page.query_selector_all("h1, h2, h3, .title, .package-name")
            for element in title_elements:
                try:
                    text = await element.inner_text()
                    text_lower = text.lower()
                    for package_name in self.PACKAGE_NAMES:
                        if package_name.lower() in text_lower:
                            return package_name.capitalize()
                except:
                    continue
                    
        except Exception as e:
            self._extraction_log.append({
                'method': 'package_name_extraction',
                'success': False,
                'error': str(e)[:100]
            })
        
        return None
    
    def _merge_results(self, package_info: PackageInfo, *results) -> PackageInfo:
        """
        Tüm sonuçları birleştir
        
        Args:
            package_info: Ana PackageInfo modeli
            *results: Extraction sonuçları
            
        Returns:
            PackageInfo: Birleştirilmiş model
        """
        for result in results:
            if 'features' in result:
                package_info.features.extend(result['features'])
            if 'packages' in result:
                package_info.packages.extend(result['packages'])
            if 'special_features' in result:
                for feature, value in result['special_features'].items():
                    setattr(package_info, feature, value)
        
        # Remove duplicates
        package_info.features = list(set(package_info.features))
        package_info.packages = list(set(package_info.packages))
        
        return package_info
    
    def _categorize_features(self, package_info: PackageInfo) -> PackageInfo:
        """
        Özellikleri kategorize et
        
        Args:
            package_info: PackageInfo modeli
            
        Returns:
            PackageInfo: Kategorize edilmiş model
        """
        for feature in package_info.features:
            feature_lower = feature.lower()
            
            # Kategorilere ayır
            for category, keywords in self.FEATURE_KEYWORDS.items():
                for keyword in keywords:
                    if keyword in feature_lower:
                        if category == 'safety' and feature not in package_info.safety_features:
                            package_info.safety_features.append(feature)
                        elif category == 'comfort' and feature not in package_info.comfort_features:
                            package_info.comfort_features.append(feature)
                        elif category == 'technology' and feature not in package_info.technology_features:
                            package_info.technology_features.append(feature)
                        elif category == 'performance' and feature not in package_info.performance_features:
                            package_info.performance_features.append(feature)
                        break
        
        return package_info
    
    def _calculate_confidence(self, package_info: PackageInfo) -> float:
        """
        Kalite skoru hesapla (0-1)
        
        Args:
            package_info: PackageInfo modeli
            
        Returns:
            float: Kalite skoru
        """
        score = 0.5  # Başlangıç
        
        # Feature sayısına göre
        if package_info.total_features > 0:
            score += 0.2
        
        # Kategorilere ayrılmışsa
        if (package_info.safety_features or 
            package_info.comfort_features or 
            package_info.technology_features):
            score += 0.2
        
        # Special features varsa
        special_count = sum([
            package_info.has_park_assist,
            package_info.has_camera,
            package_info.has_navigation,
            package_info.has_leather,
            package_info.has_sunroof,
            package_info.has_heated_seats,
        ])
        if special_count > 0:
            score += min(special_count * 0.05, 0.1)
        
        return min(score, 1.0)
