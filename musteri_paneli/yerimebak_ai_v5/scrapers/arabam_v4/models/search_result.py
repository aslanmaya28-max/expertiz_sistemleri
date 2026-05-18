# -*- coding: utf-8 -*-
"""
Arabam v4.0 - ArabamSearchResult Model
Arama sonuçları modeli
"""

from pydantic import BaseModel, Field
from typing import List, Dict, Any, Optional
from datetime import datetime
from .listing import ArabamListing


class ArabamSearchResult(BaseModel):
    """
    Arama sonuçları modeli
    
    Bir arama sorgusunun sonuçlarını tutar.
    Başarı oranı, performans metrikleri ve istatistikler içerir.
    """
    
    # ==================== SORGU BİLGİLERİ ====================
    query: Dict[str, Any] = Field(
        ...,
        description="Arama sorgusu (brand, model, year)"
    )
    
    # ==================== SONUÇLAR ====================
    listings: List[ArabamListing] = Field(
        default_factory=list,
        description="Bulunan ilanlar"
    )
    
    # ==================== İSTATİSTİKLER ====================
    total_count: int = Field(
        default=0,
        description="Toplam ilan sayısı"
    )
    successful_count: int = Field(
        default=0,
        description="Başarılı çekilen sayısı"
    )
    failed_count: int = Field(
        default=0,
        description="Başarısız sayısı"
    )
    
    # ==================== METRİKLER ====================
    success_rate: float = Field(
        default=0.0,
        ge=0.0,
        le=1.0,
        description="Başarı oranı (0-1)"
    )
    data_quality_score: float = Field(
        default=0.0,
        ge=0.0,
        le=1.0,
        description="Ortalama veri kalite skoru"
    )
    
    # ==================== PERFORMANS ====================
    execution_time: float = Field(
        default=0.0,
        description="Toplam çalışma süresi (saniye)"
    )
    avg_extraction_time: float = Field(
        default=0.0,
        description="Ortalama çıkarma süresi (saniye)"
    )
    
    # ==================== URL BİLGİLERİ ====================
    urls_tried: List[str] = Field(
        default_factory=list,
        description="Denenen URL'ler"
    )
    successful_url: Optional[str] = Field(
        None,
        description="Başarılı URL"
    )
    
    # ==================== FİYAT ANALİZİ ====================
    min_price: Optional[int] = Field(
        None,
        description="En düşük fiyat"
    )
    max_price: Optional[int] = Field(
        None,
        description="En yüksek fiyat"
    )
    avg_price: Optional[float] = Field(
        None,
        description="Ortalama fiyat"
    )
    median_price: Optional[float] = Field(
        None,
        description="Medyan fiyat"
    )
    
    # ==================== BOYA ANALİZİ ====================
    original_count: int = Field(
        default=0,
        description="Orijinal/Boyasız sayısı"
    )
    painted_count: int = Field(
        default=0,
        description="Boyalı sayısı"
    )
    changed_count: int = Field(
        default=0,
        description="Değişen parça sayısı"
    )
    
    # ==================== META VERİLER ====================
    scraped_at: datetime = Field(
        default_factory=datetime.now,
        description="Çekim tarihi"
    )
    errors: List[str] = Field(
        default_factory=list,
        description="Hata mesajları"
    )
    warnings: List[str] = Field(
        default_factory=list,
        description="Uyarı mesajları"
    )
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            list: lambda v: str(v)
        }
    
    # ==================== METODLAR ====================
    
    def calculate_statistics(self) -> None:
        """
        İstatistikleri hesapla ve güncelle
        """
        if not self.listings:
            return
        
        # Fiyat istatistikleri
        prices = [l.price for l in self.listings if l.price]
        if prices:
            self.min_price = min(prices)
            self.max_price = max(prices)
            self.avg_price = sum(prices) / len(prices)
            
            # Medyan
            sorted_prices = sorted(prices)
            n = len(sorted_prices)
            if n % 2 == 0:
                self.median_price = (sorted_prices[n//2 - 1] + sorted_prices[n//2]) / 2
            else:
                self.median_price = sorted_prices[n//2]
        
        # Boya istatistikleri
        self.original_count = sum(1 for l in self.listings if l.paint_info.is_original)
        self.painted_count = sum(1 for l in self.listings if l.paint_info.has_paint and not l.paint_info.has_changed)
        self.changed_count = sum(1 for l in self.listings if l.paint_info.has_changed)
        
        # Veri kalitesi
        if self.listings:
            self.data_quality_score = sum(l.data_quality_score for l in self.listings) / len(self.listings)
        
        # Başarı oranı
        total = self.successful_count + self.failed_count
        if total > 0:
            self.success_rate = self.successful_count / total
    
    def get_price_range(self) -> str:
        """
        Fiyat aralığını döndür
        
        Returns:
            str: Fiyat aralığı metni
        """
        if self.min_price and self.max_price:
            return f"{self.min_price:,} - {self.max_price:,} TL"
        return "Fiyat bilgisi yok"
    
    def get_paint_summary(self) -> str:
        """
        Boya özetini döndür
        
        Returns:
            str: Boya özeti metni
        """
        parts = []
        if self.original_count > 0:
            parts.append(f"{self.original_count} Orijinal")
        if self.painted_count > 0:
            parts.append(f"{self.painted_count} Boyalı")
        if self.changed_count > 0:
            parts.append(f"{self.changed_count} Değişen")
        
        if parts:
            return " | ".join(parts)
        return "Boya bilgisi yok"
    
    def get_best_deal(self) -> Optional[ArabamListing]:
        """
        En iyi fırsatı döndür
        
        Returns:
            Optional[ArabamListing]: En iyi fırsat veya None
        """
        good_deals = [l for l in self.listings if l.is_good_deal()]
        if good_deals:
            # En düşük fiyatlı iyi fırsat
            return min(good_deals, key=lambda x: x.price)
        return None
    
    def get_worst_deal(self) -> Optional[ArabamListing]:
        """
        En kötü fırsatı döndür
        
        Returns:
            Optional[ArabamListing]: En kötü fırsat veya None
        """
        if not self.listings:
            return None
        
        # En yüksek pazar skorlu = en kötü fırsat
        return max(self.listings, key=lambda x: x.calculate_market_score())
    
    def is_successful(self) -> bool:
        """
        Arama başarılı mı?
        
        Returns:
            bool: True if success rate >= 0.95 and listings >= 15
        """
        return self.success_rate >= 0.95 and len(self.listings) >= 15
    
    def get_summary(self) -> str:
        """
        Sonuç özeti oluştur
        
        Returns:
            str: Özet metin
        """
        parts = [
            f"✅ Başarı: %{self.success_rate:.1f}",
            f"📊 İlan: {len(self.listings)} adet",
            f"⏱️ Süre: {self.execution_time:.1f}s",
        ]
        
        if self.min_price and self.max_price:
            parts.append(f"💰 Fiyat: {self.get_price_range()}")
        
        if self.original_count > 0 or self.painted_count > 0 or self.changed_count > 0:
            parts.append(f"🎨 {self.get_paint_summary()}")
        
        return " | ".join(parts)
    
    def get_top_listings(self, n: int = 5) -> List[ArabamListing]:
        """
        En iyi n ilanı döndür (fiyata göre)
        
        Args:
            n: İlan sayısı
            
        Returns:
            List[ArabamListing]: En iyi n ilan
        """
        return sorted(self.listings, key=lambda x: x.price)[:n]
    
    def get_market_insights(self) -> Dict[str, Any]:
        """
        Pazar içgörülerini döndür
        
        Returns:
            Dict[str, Any]: Pazar analizi
        """
        insights = {
            "total_listings": len(self.listings),
            "price_range": self.get_price_range(),
            "avg_price": f"{int(self.avg_price):,} TL" if self.avg_price else None,
            "paint_distribution": {
                "original": self.original_count,
                "painted": self.painted_count,
                "changed": self.changed_count,
            },
            "quality_score": f"%{self.data_quality_score * 100:.1f}" if self.data_quality_score > 0 else None,
        }
        
        # Yakıt tipi dağılımı
        fuel_dist = {}
        for listing in self.listings:
            # Handle both enum and string types
            fuel = listing.fuel_type.value if hasattr(listing.fuel_type, 'value') else str(listing.fuel_type)
            fuel_dist[fuel] = fuel_dist.get(fuel, 0) + 1
        insights["fuel_distribution"] = fuel_dist
        
        # Vites tipi dağılımı
        gear_dist = {}
        for listing in self.listings:
            # Handle both enum and string types
            gear = listing.gear_type.value if hasattr(listing.gear_type, 'value') else str(listing.gear_type)
            gear_dist[gear] = gear_dist.get(gear, 0) + 1
        insights["gear_distribution"] = gear_dist
        
        return insights
