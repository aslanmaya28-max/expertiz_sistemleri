# -*- coding: utf-8 -*-
"""
Arabam v4.0 - ArabamListing Model
Ana ilan modeli - Tüm alanlar ve validatörler
"""

from pydantic import BaseModel, Field, validator
from typing import Optional, List
from datetime import datetime
from .enums import FuelType, GearType, BodyType, SellerType, WarrantyStatus
from .paint_info import PaintInfo
from .package_info import PackageInfo


class ArabamListing(BaseModel):
    """
    Ana ilan modeli
    
    Arabam.com'dan çekilen tüm araç ilanı bilgilerini tutar.
    Pydantic ile validasyon yapılır.
    """
    
    # ==================== ZORUNLU ALANLAR ====================
    url: str = Field(
        ...,
        description="İlan URL'i"
    )
    price: int = Field(
        ...,
        gt=10000,
        description="Fiyat (TL)"
    )
    title: str = Field(
        ...,
        min_length=5,
        description="İlan başlığı"
    )
    brand: str = Field(
        ...,
        min_length=2,
        description="Marka"
    )
    model: str = Field(
        ...,
        min_length=2,
        description="Model"
    )
    year: int = Field(
        ...,
        ge=1990,
        le=datetime.now().year + 1,
        description="Model yılı"
    )
    
    # ==================== KRİTİK ALANLAR ====================
    paint_info: PaintInfo = Field(
        default_factory=PaintInfo,
        description="Boya/değişen bilgisi - KRİTİK"
    )
    package_info: PackageInfo = Field(
        default_factory=PackageInfo,
        description="Donanım bilgisi"
    )
    
    # ==================== ARAÇ ÖZELLİKLERİ ====================
    km: Optional[int] = Field(
        None,
        ge=0,
        description="Kilometre"
    )
    fuel_type: FuelType = Field(
        default=FuelType.UNKNOWN,
        description="Yakıt tipi"
    )
    gear_type: GearType = Field(
        default=GearType.UNKNOWN,
        description="Vites tipi"
    )
    body_type: BodyType = Field(
        default=BodyType.UNKNOWN,
        description="Kasa tipi"
    )
    color: Optional[str] = Field(
        None,
        description="Renk"
    )
    engine_size: Optional[float] = Field(
        None,
        gt=0.0,
        description="Motor hacmi (litre)"
    )
    horsepower: Optional[int] = Field(
        None,
        gt=0,
        description="Beygir gücü"
    )
    
    # ==================== İLAN BİLGİLERİ ====================
    image_url: Optional[str] = Field(
        None,
        description="Araç görseli URL (1. görsel - dış görünüş)"
    )
    seller_type: SellerType = Field(
        default=SellerType.UNKNOWN,
        description="Satıcı tipi"
    )
    location: Optional[str] = Field(
        None,
        description="Konum (Şehir/İlçe)"
    )
    listing_date: Optional[str] = Field(
        None,
        description="İlan tarihi"
    )
    listing_id: Optional[str] = Field(
        None,
        description="İlan ID"
    )
    
    # ==================== TRAMER & SİGORTA ====================
    has_insurance: Optional[bool] = Field(
        None,
        description="Sigortası var mı"
    )
    insurance_expiry: Optional[str] = Field(
        None,
        description="Sigorta bitiş tarihi"
    )
    inspection_expiry: Optional[str] = Field(
        None,
        description="Muayene bitiş tarihi"
    )
    warranty_status: WarrantyStatus = Field(
        default=WarrantyStatus.UNKNOWN,
        description="Garanti durumu"
    )
    
    # ==================== AÇIKLAMA ====================
    description: Optional[str] = Field(
        None,
        description="İlan açıklaması"
    )
    
    # ==================== META VERİLER ====================
    scraped_at: datetime = Field(
        default_factory=datetime.now,
        description="Çekim tarihi"
    )
    data_quality_score: float = Field(
        default=0.5,
        ge=0.0,
        le=1.0,
        description="Veri kalite skoru (0-1)"
    )
    extraction_log: List[str] = Field(
        default_factory=list,
        description="Veri çıkarma logları"
    )
    
    # ==================== VALIDATÖRLER ====================
    
    @validator('price')
    def validate_price(cls, v):
        """Fiyat validasyonu"""
        if v < 10000:
            raise ValueError(f"Fiyat çok düşük: {v:,} TL")
        if v > 100_000_000:
            raise ValueError(f"Fiyat çok yüksek: {v:,} TL")
        return v
    
    @validator('km')
    def validate_km(cls, v, values):
        """KM validasyonu - yıla göre kontrol"""
        if v is not None:
            year = values.get('year', datetime.now().year)
            age = datetime.now().year - year + 1
            max_km = age * 30000  # Yılda ortalama 30k KM
            
            # Çok yüksek km uyarısı (ama hata değil)
            if v > max_km * 2:
                # Uyarı ama engelleme
                pass
        return v
    
    @validator('engine_size')
    def validate_engine_size(cls, v):
        """Motor hacmi validasyonu"""
        if v is not None:
            if v < 0.8 or v > 8.0:
                # Uyarı ama engelleme
                pass
        return v
    
    @validator('horsepower')
    def validate_horsepower(cls, v):
        """Beygir gücü validasyonu"""
        if v is not None:
            if v < 40 or v > 1000:
                # Uyarı ama engelleme
                pass
        return v
    
    class Config:
        use_enum_values = True
        json_encoders = {
            datetime: lambda v: v.isoformat(),
            list: lambda v: str(v)
        }
    
    # ==================== METODLAR ====================
    
    def get_adjusted_price(self) -> int:
        """
        Boya ve donanım bilgisine göre düzeltilmiş fiyat hesapla
        
        Returns:
            int: Düzeltilmiş fiyat (TL)
        """
        adjusted = self.price
        
        # Boya/değişen etkisi
        paint_impact = self.paint_info.get_price_impact()
        adjusted = int(adjusted * (1 + paint_impact))
        
        # Donanım etkisi
        package_impact = self.package_info.get_price_impact()
        adjusted = int(adjusted * (1 + package_impact))
        
        return adjusted
    
    def get_price_per_km(self) -> Optional[float]:
        """
        Kilometre başına fiyat hesapla
        
        Returns:
            Optional[float]: KM başına fiyat veya None
        """
        if self.km and self.km > 0:
            return self.price / self.km
        return None
    
    def get_age(self) -> int:
        """
        Araç yaşını hesapla
        
        Returns:
            int: Yaş (yıl)
        """
        return datetime.now().year - self.year
    
    def is_good_deal(self) -> bool:
        """
        İyi fırsat mı?
        
        Returns:
            bool: True if good deal criteria met
        """
        # Kriterler:
        # 1. Orijinal/boyasız veya hafif boya
        # 2. Düşük KM (yılda 15k'den az)
        # 3. İyi donanım
        
        age = self.get_age()
        if self.km and age > 0:
            km_per_year = self.km / age
            if km_per_year > 15000:
                return False
        
        if self.paint_info.has_major_issues():
            return False
        
        if self.data_quality_score < 0.7:
            return False
        
        return True
    
    def get_summary(self) -> str:
        """
        İlan özeti oluştur
        
        Returns:
            str: Özet metin
        """
        parts = [
            f"{self.brand} {self.model}",
            f"{self.year}",
            f"{self.km:,} KM" if self.km else "KM Yok",
            f"{self.fuel_type.value}",
            f"{self.gear_type.value}",
        ]
        
        if self.paint_info.status.value != "Bilinmiyor":
            parts.append(f"Boya: {self.paint_info.status.value}")
        
        if self.package_info.total_features > 0:
            parts.append(f"{self.package_info.total_features} Ekipman")
        
        return " | ".join(parts)
    
    def calculate_market_score(self) -> float:
        """
        Pazar skorunu hesapla (0-100)
        
        Returns:
            float: Pazar skoru
        """
        score = 50.0  # Başlangıç
        
        # Boya durumu (+/- 20)
        if self.paint_info.is_original:
            score += 20
        elif self.paint_info.has_changed:
            score -= 20
        elif self.paint_info.has_paint:
            if self.paint_info.paint_count <= 1:
                score -= 5
            elif self.paint_info.paint_count <= 3:
                score -= 10
            else:
                score -= 15
        
        # Donanım (+15)
        if self.package_info.is_high_spec():
            score += 15
        elif self.package_info.is_basic_spec():
            score -= 5
        
        # KM (+/- 10)
        age = self.get_age()
        if self.km and age > 0:
            km_per_year = self.km / age
            if km_per_year < 10000:
                score += 10
            elif km_per_year > 25000:
                score -= 10
        
        # Veri kalitesi (+/- 5)
        score += (self.data_quality_score - 0.5) * 10
        
        return max(0, min(100, score))
