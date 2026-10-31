# -*- coding: utf-8 -*-
"""
Arabam v4.0 - PaintInfo Model
KRİTİK: Boya/değişen bilgisi - Fiyat belirleme için hayati önem taşıyor
"""

from pydantic import BaseModel, Field
from typing import List, Optional
from .enums import PaintStatus


class PaintInfo(BaseModel):
    """
    Boya/değişen bilgisi modeli
    
    Bu model Arabam.com için en kritik modeldir.
    Boya ve değişen parça bilgisi, araç fiyatını belirlemede
    en önemli faktörlerden biridir.
    
    Turkish Market Importance:
    - Orijinal/Boyasız araçlar %15-25 daha değerli
    - Değişen parça fiyatı %10-20 düşürebilir
    - Lokal boyalar daha az etkiler (%3-5)
    """
    
    # Ana durum baytları
    has_paint: bool = Field(
        default=False,
        description="Araçta boya var mı"
    )
    has_changed: bool = Field(
        default=False,
        description="Değişen parça var mı"
    )
    is_original: bool = Field(
        default=False,
        description="Tamamen orijinal/boyasız mı"
    )
    
    # Genel durum
    status: PaintStatus = Field(
        default=PaintStatus.UNKNOWN,
        description="Genel boya durumu"
    )
    
    # Detaylı bilgi
    painted_parts: List[str] = Field(
        default_factory=list,
        description="Boyalı parçalar (örn: 'ön tampon', 'sağ ön kapı')"
    )
    local_paint_parts: List[str] = Field(
        default_factory=list,
        description="Lokal boyalı parçalar (örn: 'sağ ön kapı lokal')"
    )
    changed_parts: List[str] = Field(
        default_factory=list,
        description="Değişen parçalar (örn: 'sol arka çamurluk', 'amortisör')"
    )
    details: List[str] = Field(
        default_factory=list,
        description="Detaylı notlar"
    )
    
    # Meta veriler
    paint_count: int = Field(
        default=0,
        description="Boyalı parça sayısı"
    )
    local_paint_count: int = Field(
        default=0,
        description="Lokal boyalı parça sayısı"
    )
    changed_count: int = Field(
        default=0,
        description="Değişen parça sayısı"
    )
    confidence_score: float = Field(
        default=0.5,
        ge=0.0,
        le=1.0,
        description="Veri kalite skoru (0-1)"
    )
    
    class Config:
        use_enum_values = True
        json_encoders = {
            list: lambda v: str(v)
        }
    
    def get_price_impact(self) -> float:
        """
        Boya/değişen bilgisinin fiyat etkisini hesapla
        
        Returns:
            float: Fiyat etkisi oranı (negatif = fiyat düşürücü)
            
        Examples:
            - Orijinal: +0.15 (fiyat artışı)
            - Lokal boya: -0.03 (hafif düşüş)
            - Değişen parça: -0.15 (ciddi düşüş)
            - Karma: -0.10 (orta düşüş)
        """
        if self.is_original:
            return 0.15  # Orijinal araç daha değerli
        elif self.has_changed and self.has_paint:
            return -0.15  # Hem boya hem değişen = ciddi düşüş
        elif self.has_changed:
            return -0.12  # Sadece değişen = ciddi düşüş
        elif self.has_paint:
            # Boya sayısına göre
            if self.paint_count <= 1:
                return -0.03  # Tek lokal boya = hafif düşüş
            elif self.paint_count <= 3:
                return -0.08  # 2-3 boya = orta düşüş
            else:
                return -0.12  # 4+ boya = ciddi düşüş
        else:
            return 0.0  # Bilinmiyor
    
    def get_summary(self) -> str:
        """
        Boya bilgisi özetini döndür
        
        Returns:
            str: Özet metin
        """
        if self.is_original:
            return "Orijinal/Boyasız"
        elif self.has_changed and self.has_paint:
            return f"{self.changed_count} değişen, {self.paint_count} boyalı"
        elif self.has_changed:
            return f"{self.changed_count} değişen parça"
        elif self.has_paint:
            return f"{self.paint_count} boyalı parça"
        else:
            return "Bilinmiyor"
    
    def is_ideal_condition(self) -> bool:
        """
        İdeal durumda mı (orijinal/boyasız)?
        
        Returns:
            bool: True if original
        """
        return self.is_original and not self.has_paint and not self.has_changed
    
    def has_major_issues(self) -> bool:
        """
        Ciddi sorun var mı?
        
        Returns:
            bool: True if has changed parts or 4+ paint
        """
        return self.has_changed or self.paint_count >= 4
