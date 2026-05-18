# -*- coding: utf-8 -*-
"""
YERİMEBAK AI v8.0 - Condition Analyzer
Değişen KM ve Boyalı Parça Analiz Motoru
"""

from typing import Dict, Any, List
from dataclasses import dataclass
from enum import Enum
from datetime import datetime


class PaintCondition(Enum):
    """Boya durumu seviyeleri"""
    ORIGINAL = "ORIGINAL"  # Orijinal boyasız
    PAINTED = "PAINTED"    # Boyalı
    PLATED = "PLATED"      # Kaplama (değişen parça)


class PartLocation(Enum):
    """Parça konumları"""
    FRONT_BUMPER = "Ön Tampon"
    REAR_BUMPER = "Arka Tampon"
    HOOD = "Kaput"
    TRUNK = "Bagaj Kapağı"
    FRONT_LEFT_DOOR = "Ön Sol Kapı"
    FRONT_RIGHT_DOOR = "Ön Sağ Kapı"
    REAR_LEFT_DOOR = "Arka Sol Kapı"
    REAR_RIGHT_DOOR = "Arka Sağ Kapı"
    FRONT_LEFT_FENDER = "Ön Sol Çamurluk"
    FRONT_RIGHT_FENDER = "Ön Sağ Çamurluk"
    REAR_LEFT_FENDER = "Arka Sol Çamurluk"
    REAR_RIGHT_FENDER = "Arka Sağ Çamurluk"
    ROOF = "Tavan"


@dataclass
class PaintedPart:
    """Boyalı parça bilgisi"""
    location: str
    condition: str  # ORIGINAL, PAINTED, PLATED
    description: str = ""


@dataclass
class KMAnalysis:
    """KM analizi sonucu"""
    current_km: int
    expected_km: int
    km_difference: int
    km_penalty_score: float  # 0-100, yüksek = kötü
    is_km_suspicious: bool
    analysis_note: str


@dataclass
class PaintAnalysis:
    """Boya analizi sonucu"""
    painted_parts: List[PaintedPart]
    paint_penalty_score: float  # 0-100
    paint_impact_on_value: float  # % değer kaybı
    is_paint_acceptable: bool
    analysis_note: str


@dataclass
class ConditionReport:
    """Komple durum raporu"""
    km_analysis: KMAnalysis
    paint_analysis: PaintAnalysis
    overall_condition_score: float  # 0-100
    price_adjustment_percent: float  # Fiyat ayarı (%)
    recommendation: str


class ConditionAnalyzer:
    """
    Değişen KM ve Boyalı Parça Analiz Motoru
    
    20 yıllık galerici deneyimi ile:
    - KM tutarsızlıklarını tespit eder
    - Boyalı parçaları analiz eder
    - Fiyat ayarı önerir
    """
    
    def __init__(self):
        self.year = datetime.now().year
        
        # Yıllık ortalama KM (Türkiye standartları)
        self.annual_km_avg = {
            "economy": 15000,    # Ekonomik segment
            "medium": 20000,     # Orta segment
            "premium": 18000,    # Premium segment
            "sport": 12000,      # Spor araçlar
        }
    
    def analyze_km(self, 
                   current_km: int, 
                   vehicle_year: int,
                   segment: str = "medium") -> KMAnalysis:
        """
        KM analizi
        
        Args:
            current_km: Mevcut KM
            vehicle_year: Araç yılı
            segment: Araç segmenti
        
        Returns:
            KMAnalysis objesi
        """
        # Araç yaşı
        vehicle_age = self.year - vehicle_year
        if vehicle_age < 0:
            vehicle_age = 0
        
        # Beklenen KM hesapla
        annual_km = self.annual_km_avg.get(segment, 20000)
        expected_km = vehicle_age * annual_km
        
        # KM farkı
        km_difference = current_km - expected_km
        
        # KM ceza skoru (0-100)
        if km_difference <= 0:
            # KM beklenenin altında veya eşit
            km_penalty_score = 0
        elif km_difference <= 20000:
            # %20'ye kadar fark
            km_penalty_score = (km_difference / 20000) * 10
        elif km_difference <= 50000:
            # %20-50 arası fark
            km_penalty_score = 10 + ((km_difference - 20000) / 30000) * 20
        elif km_difference <= 100000:
            # %50-100 arası fark
            km_penalty_score = 30 + ((km_difference - 50000) / 50000) * 30
        else:
            # %100'den fazla fark
            km_penalty_score = 60 + min(40, (km_difference - 100000) / 50000 * 10)
        
        # Şüpheli KM kontrolü
        is_km_suspicious = km_difference > 50000
        
        # Analiz notu
        if km_difference <= 0:
            analysis_note = f"✅ KM normal. Araç {vehicle_age} yaşında ve {current_km:,} KM."
        elif km_difference <= 20000:
            analysis_note = f"⚠️ KM biraz yüksek. Beklenen: {expected_km:,} KM, Mevcut: {current_km:,} KM (+{km_difference:,} KM)"
        elif km_difference <= 50000:
            analysis_note = f"⚠️ KM yüksek. Beklenen: {expected_km:,} KM, Mevcut: {current_km:,} KM (+{km_difference:,} KM)"
        else:
            analysis_note = f"🚨 KM çok yüksek! Beklenen: {expected_km:,} KM, Mevcut: {current_km:,} KM (+{km_difference:,} KM). Şüpheli!"
        
        return KMAnalysis(
            current_km=current_km,
            expected_km=int(expected_km),
            km_difference=km_difference,
            km_penalty_score=round(km_penalty_score, 1),
            is_km_suspicious=is_km_suspicious,
            analysis_note=analysis_note
        )
    
    def analyze_paint(self, 
                     paint_data: List[Dict[str, str]],
                     vehicle_year: int) -> PaintAnalysis:
        """
        Boya analizi
        
        Args:
            paint_data: Boya bilgisi listesi
                Örnek: [{"location": "Ön Tampon", "condition": "PAINTED"}]
            vehicle_year: Araç yılı
        
        Returns:
            PaintAnalysis objesi
        """
        painted_parts = []
        
        for part in paint_data:
            location = part.get("location", "")
            condition = part.get("condition", "ORIGINAL").upper()
            
            painted_parts.append(PaintedPart(
                location=location,
                condition=condition,
                description=part.get("description", "")
            ))
        
        # Boyalı parça sayısı (LOCAL dahil)
        painted_count = sum(1 for p in painted_parts if p.condition in ["PAINTED", "PLATED", "LOCAL"])
        plated_count = sum(1 for p in painted_parts if p.condition == "PLATED")
        local_count = sum(1 for p in painted_parts if p.condition == "LOCAL")
        
        # Araç yaşı
        vehicle_age = self.year - vehicle_year
        if vehicle_age < 0:
            vehicle_age = 0
        
        # Boya ceza skoru hesapla (Lokal boyalar daha az ceza)
        # Lokal boya = 2 puan, Normal boya = 4 puan
        paint_penalty_score = local_count * 2 + (painted_count - local_count) * 4
        
        # Değişen parça (plated) ek ceza
        if plated_count > 0:
            paint_penalty_score += plated_count * 15
        
        # Değer kaybı hesapla
        paint_impact_on_value = paint_penalty_score * 0.3  # Her ceza puanı %0.3 değer kaybı
        
        # Boya kabul edilebilir mi?
        # 3 yaşından küçük araçlarda boya kabul edilebilir
        # 5 yaşından büyük araçlarda boya normal
        # Lokal boyalar daha toleranslı
        effective_painted = painted_count - local_count  # Sadece normal boyalılar
        if vehicle_age <= 3:
            is_paint_acceptable = effective_painted == 0 and local_count <= 1
        elif vehicle_age <= 5:
            is_paint_acceptable = plated_count == 0 and effective_painted <= 2 and local_count <= 2
        else:
            is_paint_acceptable = plated_count == 0 and effective_painted <= 4 and local_count <= 3
        
        # Analiz notu
        if painted_count == 0:
            analysis_note = "✅ Orijinal boyasız araç. Mükemmel durum!"
        elif plated_count > 0:
            analysis_note = f"🚨 {plated_count} değişen parça var! Dikkatli olun. Toplam: {painted_count} boyalı parça."
        elif local_count > 0 and effective_painted == 0:
            analysis_note = f"✅ {local_count} lokal boyalı parça var. İyi durum, hafif pazarlık alanı."
        elif local_count > 0:
            analysis_note = f"⚠️ {local_count} lokal + {effective_painted} boyalı = Toplam {painted_count} parça. Fiyat pazarlık alanı."
        elif painted_count <= 2:
            analysis_note = f"✅ {painted_count} boyalı parça var. Normal kabul edilebilir."
        elif painted_count <= 4:
            analysis_note = f"⚠️ {painted_count} boyalı parça var. Fiyat pazarlık alanı."
        else:
            analysis_note = f"🚨 {painted_count} boyalı parça var! Çok fazla boya, dikkat!"
        
        return PaintAnalysis(
            painted_parts=painted_parts,
            paint_penalty_score=round(paint_penalty_score, 1),
            paint_impact_on_value=round(paint_impact_on_value, 1),
            is_paint_acceptable=is_paint_acceptable,
            analysis_note=analysis_note
        )
    
    def analyze_condition(self,
                         current_km: int,
                         vehicle_year: int,
                         paint_data: List[Dict[str, str]],
                         segment: str = "medium") -> ConditionReport:
        """
        Komple durum analizi
        
        Args:
            current_km: Mevcut KM
            vehicle_year: Araç yılı
            paint_data: Boya bilgisi
            segment: Araç segmenti
        
        Returns:
            ConditionReport objesi
        """
        # KM analizi
        km_analysis = self.analyze_km(current_km, vehicle_year, segment)
        
        # Boya analizi
        paint_analysis = self.analyze_paint(paint_data, vehicle_year)
        
        # Genel durum skoru (0-100)
        # 100 - (KM cezası + Boya cezası)
        overall_condition_score = 100 - (km_analysis.km_penalty_score + paint_analysis.paint_penalty_score)
        overall_condition_score = max(0, min(100, overall_condition_score))
        
        # Fiyat ayarı
        # KM farkı ve boya durumuna göre
        km_impact = km_analysis.km_penalty_score * 0.5  # KM cezasının %50'si fiyat etkisi
        paint_impact = paint_analysis.paint_impact_on_value
        price_adjustment_percent = -(km_impact + paint_impact)
        
        # Öneri
        if overall_condition_score >= 85:
            recommendation = "🌟 Mükemmel durum. İyi fiyatlandırılmış."
        elif overall_condition_score >= 70:
            recommendation = "✅ İyi durum. Normal fiyatlandırılmış."
        elif overall_condition_score >= 50:
            recommendation = "⚠️ Orta durum. Fiyat pazarlık alanı var."
        else:
            recommendation = "🚨 Kötü durum. Dikkatli olun veya fiyatı düşürün."
        
        return ConditionReport(
            km_analysis=km_analysis,
            paint_analysis=paint_analysis,
            overall_condition_score=round(overall_condition_score, 1),
            price_adjustment_percent=round(price_adjustment_percent, 1),
            recommendation=recommendation
        )


# Singleton instance
_condition_analyzer = None

def get_condition_analyzer() -> ConditionAnalyzer:
    """Get singleton instance"""
    global _condition_analyzer
    if _condition_analyzer is None:
        _condition_analyzer = ConditionAnalyzer()
    return _condition_analyzer
