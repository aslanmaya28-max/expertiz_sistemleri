# -*- coding: utf-8 -*-
"""
Arabam v4.0 - PackageInfo Model
Donanım/Ekipman bilgisi
"""

from pydantic import BaseModel, Field
from typing import List, Dict, Optional


class PackageInfo(BaseModel):
    """
    Donanım/Ekipman bilgisi modeli
    
    Arabam.com'da araçların donanım paketleri ve
    ekipman bilgilerini tutar.
    
    Turkish Market Importance:
    - Yüksek donanım %5-10 fiyat artışı sağlar
    - Güvenlik ekipmanları öncelikli
    - Teknoloji paketleri popüler
    """
    
    # Toplam bilgiler
    total_features: int = Field(
        default=0,
        description="Toplam ekipman sayısı"
    )
    
    # Tüm özellikler
    features: List[str] = Field(
        default_factory=list,
        description="Tüm ekipman listesi"
    )
    
    # Paket bilgileri
    packages: List[str] = Field(
        default_factory=list,
        description="Paket adları (örn: 'Comfort', 'Sport')"
    )
    
    # Kategorilere ayrılmış özellikler
    safety_features: List[str] = Field(
        default_factory=list,
        description="Güvenlik ekipmanları (ABS, ESP, Airbag)"
    )
    comfort_features: List[str] = Field(
        default_factory=list,
        description="Konfor ekipmanları (Klima, Deri koltuk)"
    )
    technology_features: List[str] = Field(
        default_factory=list,
        description="Teknoloji ekipmanları (Navi, Kamera, Sensör)"
    )
    performance_features: List[str] = Field(
        default_factory=list,
        description="Performans ekipmanları (Spor koltuk, Direksiyon)"
    )
    
    # Meta veriler
    has_park_assist: bool = Field(
        default=False,
        description="Park assist var mı"
    )
    has_camera: bool = Field(
        default=False,
        description="Geri görüş kamerası var mı"
    )
    has_navigation: bool = Field(
        default=False,
        description="Navigasyon var mı"
    )
    has_leather: bool = Field(
        default=False,
        description="Deri döşeme var mı"
    )
    has_sunroof: bool = Field(
        default=False,
        description="Sunroof var mı"
    )
    has_heated_seats: bool = Field(
        default=False,
        description="Isıtmalı koltuk var mı"
    )
    # YENİ EKLENEN ÖZELLİKLER (v4.0)
    has_cooled_seats: bool = Field(
        default=False,
        description="Soğutmalı koltuk var mı"
    )
    has_memory_seats: bool = Field(
        default=False,
        description="Hafızalı koltuk var mı"
    )
    has_massage_seats: bool = Field(
        default=False,
        description="Masajlı koltuk var mı"
    )
    has_head_up_display: bool = Field(
        default=False,
        description="Head-up display var mı"
    )
    has_digital_cluster: bool = Field(
        default=False,
        description="Dijital gösterge paneli var mı"
    )
    has_adaptive_cruise: bool = Field(
        default=False,
        description="Adaptive cruise control var mı"
    )
    has_lane_assist: bool = Field(
        default=False,
        description="Şerit takip asistanı var mı"
    )
    has_blind_spot: bool = Field(
        default=False,
        description="Kör nokta uyarısı var mı"
    )
    has_keyless: bool = Field(
        default=False,
        description="Anahtarsız giriş/var mı"
    )
    has_wireless_charging: bool = Field(
        default=False,
        description="Kablosuz şarj var mı"
    )
    
    # Kalite skoru
    confidence_score: float = Field(
        default=0.5,
        ge=0.0,
        le=1.0,
        description="Veri kalite skoru (0-1)"
    )
    
    class Config:
        json_encoders = {
            list: lambda v: str(v)
        }
    
    def get_price_impact(self) -> float:
        """
        Donanım bilgisinin fiyat etkisini hesapla
        
        Returns:
            float: Fiyat etkisi oranı (pozitif = fiyat artışı)
        """
        impact = 0.0
        
        # Temel ekipmanlar
        if self.has_navigation:
            impact += 0.03
        if self.has_leather:
            impact += 0.02
        if self.has_sunroof:
            impact += 0.02
        if self.has_heated_seats:
            impact += 0.01
        if self.has_camera:
            impact += 0.01
        if self.has_park_assist:
            impact += 0.01
        
        # Toplam ekipman sayısına göre bonus
        if self.total_features >= 15:
            impact += 0.03
        elif self.total_features >= 10:
            impact += 0.02
        elif self.total_features >= 5:
            impact += 0.01
        
        # Paket sayısına göre bonus
        impact += len(self.packages) * 0.01
        
        return min(impact, 0.10)  # Max %10
    
    def get_summary(self) -> str:
        """
        Donanım özetini döndür
        
        Returns:
            str: Özet metin
        """
        if self.total_features == 0:
            return "Donanım bilgisi yok"
        
        highlights = []
        if self.has_navigation:
            highlights.append("Navigasyon")
        if self.has_leather:
            highlights.append("Deri")
        if self.has_sunroof:
            highlights.append("Sunroof")
        if self.has_camera:
            highlights.append("Kamera")
        
        if highlights:
            return f"{self.total_features} ekipman ({', '.join(highlights[:3])})"
        else:
            return f"{self.total_features} ekipman"
    
    def get_feature_categories(self) -> Dict[str, int]:
        """
        Kategori başına özellik sayısını döndür
        
        Returns:
            Dict[str, int]: Kategori sayıları
        """
        return {
            "Güvenlik": len(self.safety_features),
            "Konfor": len(self.comfort_features),
            "Teknoloji": len(self.technology_features),
            "Performans": len(self.performance_features),
        }
    
    def is_high_spec(self) -> bool:
        """
        Yüksek donanımlı mı?
        
        Returns:
            bool: True if 15+ features or 3+ packages
        """
        return self.total_features >= 15 or len(self.packages) >= 3
    
    def is_basic_spec(self) -> bool:
        """
        Temel donanım mı?
        
        Returns:
            bool: True if 0-5 features and no packages
        """
        return self.total_features <= 5 and len(self.packages) == 0
