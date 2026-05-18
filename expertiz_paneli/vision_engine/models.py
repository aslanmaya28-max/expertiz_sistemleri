"""
Vision Engine - Pydantic V2 Models
Data validation and serialization for robust architecture
"""

from pydantic import BaseModel, Field, field_validator
from typing import List, Optional, Dict, Any, Literal
from datetime import datetime
from enum import Enum
import hashlib
import json


class SourceType(str, Enum):
    """Market data sources"""
    ARABAM = "arabam"
    VAVACARS = "vavacars"
    BORUSAN = "borusan"


class ListingQuality(str, Enum):
    """Listing quality assessment"""
    PREMIUM = "premium"
    STANDARD = "standard"
    POOR = "poor"


class FindingType(str, Enum):
    """Visual finding types for expert inspection"""
    BOYA = "boya"  # Paint color difference
    DEGISEN = "degisen"  # Part replacement suspicion
    HIZALIKLIK = "hizaliklik"  # Panel alignment issue
    HASAR = "hasar"  # Surface damage / scratch
    MANUEL_KONTROL = "manuel_kontrol"  # Low confidence, requires manual inspection


class CarListing(BaseModel):
    """Individual car listing from any source"""
    source: SourceType
    title: str
    price: float = Field(gt=0, description="Price in Turkish Lira")
    year: int = Field(ge=2000, le=2026, description="Model year")
    km: int = Field(ge=0, le=500000, description="Kilometer")
    location: str
    url: str
    listed_at: datetime = Field(default_factory=datetime.now)
    is_verified: bool = False
    image_count: int = Field(ge=0, default=0)
    
    @field_validator('price')
    @classmethod
    def price_must_be_reasonable(cls, v: float) -> float:
        """Filter out unrealistic prices"""
        if v < 10000:  # Minimum 10.000 TL
            raise ValueError('Price too low')
        if v > 50000000:  # Maximum 50M TL
            raise ValueError('Price too high')
        return v


class MarketData(BaseModel):
    """Aggregated market data from multiple sources"""
    listings: List[CarListing] = Field(min_length=1)
    total_sources: int = Field(ge=1, le=3)
    scrape_timestamp: datetime = Field(default_factory=datetime.now)
    
    @property
    def average_price(self) -> float:
        """Calculate average price across all listings"""
        if not self.listings:
            return 0.0
        return sum(l.price for l in self.listings) / len(self.listings)
    
    @property
    def price_range(self) -> tuple[float, float]:
        """Get min and max prices"""
        if not self.listings:
            return (0.0, 0.0)
        prices = [l.price for l in self.listings]
        return (min(prices), max(prices))


class CoreMetrics(BaseModel):
    """Statistical metrics from Core Engine"""
    avg_price: float = Field(ge=0, description="Average market price")
    median_price: float = Field(ge=0, description="Median market price")
    std_deviation: float = Field(ge=0, description="Standard deviation")
    min_price: float = Field(ge=0, description="Minimum price (outliers removed)")
    max_price: float = Field(ge=0, description="Maximum price (outliers removed)")
    confidence_score: float = Field(ge=0, le=100, description="Confidence in data (0-100)")
    volatility_index: float = Field(ge=0, description="Market volatility index")
    iqr_lower_bound: float = Field(ge=0, description="IQR lower bound (outlier removal)")
    iqr_upper_bound: float = Field(ge=0, description="IQR upper bound (outlier removal)")
    sample_size: int = Field(ge=0, description="Number of valid data points")
    
    class Config:
        json_schema_extra = {
            "example": {
                "avg_price": 850000.0,
                "median_price": 830000.0,
                "std_deviation": 95000.0,
                "min_price": 750000.0,
                "max_price": 950000.0,
                "confidence_score": 85.5,
                "volatility_index": 0.12,
                "iqr_lower_bound": 720000.0,
                "iqr_upper_bound": 980000.0,
                "sample_size": 42
            }
        }


class VisualFinding(BaseModel):
    """Individual visual finding from image analysis"""
    parca_adi: str = Field(description="Name of the car part (e.g., 'Sol ön çamurluk', 'Kaput')")
    bulgu_tipi: FindingType = Field(description="Type of finding: boya, degisen, hizaliklik, hasar, manuel_kontrol")
    guven_skoru: float = Field(ge=0, le=1, description="Confidence score (0-1). < 0.6 triggers manual inspection note")
    
    @field_validator('guven_skoru')
    @classmethod
    def validate_confidence(cls, v: float, info) -> float:
        """Convert low confidence findings to manual inspection"""
        if v < 0.6:
            # Auto-convert to manual inspection type
            finding_type = info.data.get('bulgu_tipi')
            if finding_type and finding_type != FindingType.MANUEL_KONTROL:
                # Note: This is handled in image_analysis.py, not here
                # This validator just validates the value
                pass
        return v
    
    class Config:
        json_schema_extra = {
            "example": {
                "parca_adi": "Sol ön çamurluk",
                "bulgu_tipi": "boya",
                "guven_skoru": 0.85
            }
        }


class VisualPriceEffect(BaseModel):
    """
    Explainable pricing: How each visual finding affects the final price
    
    Faz-1.1: Visual Impact Breakdown
    Shows line-by-line impact on vehicle valuation
    """
    parca_adi: str = Field(description="Name of the car part")
    bulgu_tipi: FindingType = Field(description="Type of finding")
    base_penalty_percent: float = Field(description="Base penalty percentage (e.g., 3.0 for boya)")
    confidence: float = Field(ge=0, le=1, description="Confidence score (0.0-1.0)")
    applied_penalty_percent: float = Field(description="Applied penalty = base × confidence")
    price_delta: float = Field(description="Price impact in TL (negative value)")
    applied: bool = Field(description="Whether this penalty was applied (confidence >= 0.6)")
    
    class Config:
        json_schema_extra = {
            "example": {
                "parca_adi": "Sol ön çamurluk",
                "bulgu_tipi": "boya",
                "base_penalty_percent": 3.0,
                "confidence": 0.85,
                "applied_penalty_percent": 2.55,
                "price_delta": -21675.0,
                "applied": True
            }
        }


class ImageAnalysis(BaseModel):
    """Image analysis result from Vision Engine (Faz-1 Stateless)"""
    visual_findings: List[VisualFinding] = Field(default_factory=list, description="Detailed visual findings with confidence scores")
    quality_score: float = Field(ge=0, le=100, description="Overall image quality score")
    overall_confidence: float = Field(ge=0, le=1, description="Overall detection confidence across all findings")
    total_images_analyzed: int = Field(ge=0, default=0, description="Number of images analyzed")
    notes: List[str] = Field(default_factory=list, description="Additional notes (e.g., low confidence warnings)")
    
    # Legacy fields for backward compatibility
    @property
    def detected_issues(self) -> List[str]:
        """Legacy compatibility: Generate issues list from findings"""
        issues = []
        for finding in self.visual_findings:
            if finding.guven_skoru >= 0.6:
                issues.append(f"{finding.parca_adi}: {finding.bulgu_tipi.value}")
        return issues
    
    @property
    def painted_parts(self) -> List[str]:
        """Legacy compatibility: Get painted parts"""
        return [f.parca_adi for f in self.visual_findings 
                if f.bulgu_tipi == FindingType.BOYA and f.guven_skoru >= 0.6]
    
    @property
    def confidence(self) -> float:
        """Legacy compatibility: Overall confidence"""
        return self.overall_confidence
    
    class Config:
        json_schema_extra = {
            "example": {
                "visual_findings": [
                    {
                        "parca_adi": "Sol ön çamurluk",
                        "bulgu_tipi": "boya",
                        "guven_skoru": 0.85
                    },
                    {
                        "parca_adi": "Kapı",
                        "bulgu_tipi": "hizaliklik",
                        "guven_skoru": 0.92
                    },
                    {
                        "parca_adi": "Tavan",
                        "bulgu_tipi": "manuel_kontrol",
                        "guven_skoru": 0.45
                    }
                ],
                "quality_score": 78.5,
                "overall_confidence": 0.74,
                "total_images_analyzed": 3,
                "notes": ["Tavan: Şüpheli alan, manuel kontrol önerilir"]
            }
        }


class AICommentary(BaseModel):
    """AI-generated expert commentary (Gemini 1.5 Flash)"""
    overall_assessment: str = Field(description="General condition assessment")
    key_findings: List[str] = Field(default_factory=list, description="Key technical findings")
    market_position: str = Field(description="Market position analysis")
    recommendations: List[str] = Field(default_factory=list, description="Actionable recommendations")
    confidence_level: str = Field(description="AI confidence in analysis")
    
    class Config:
        json_schema_extra = {
            "example": {
                "overall_assessment": "Araç genel olarak iyi bakımlı, ancak sol çamurlukta boyama tespit edildi.",
                "key_findings": [
                    "Sol ön çamurluk boyalı (%5 değer kaybı)",
                    "Kaporta hizaları normal aralıkta",
                    "Motor performans testi bekleniyor"
                ],
                "market_position": "Piyasa ortalamasında, ancak boyalı parça nedeniyle hafif aşağıda.",
                "recommendations": [
                    "Motor performans testi önerilir",
                    "Sol ön çamurluk orijinal parça değişimi kontrolü gerekli"
                ],
                "confidence_level": "Yüksek"
            }
        }


class FraudRiskLevel(str, Enum):
    """Fraud risk level assessment"""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class AnalysisStatus(str, Enum):
    """Analysis execution status"""
    NORMAL = "normal"
    LIMITED = "limited"


class MarketStatus(str, Enum):
    """Market data stability status"""
    NORMAL = "normal"
    GUARDED = "guarded"
    UNSTABLE = "unstable"


class MarketRiskReport(BaseModel):
    """
    Faz-1.3: Market Consistency Guard & Outlier Defense
    
    Detects anomalous market data, source dominance, and logical inconsistencies
    """
    market_consistency_score: float = Field(ge=0, le=1, description="Market data consistency score (0.0-1.0)")
    outlier_count: int = Field(ge=0, description="Number of outlier listings detected")
    excluded_listings: int = Field(ge=0, description="Number of listings excluded from pricing")
    source_dominance: bool = Field(default=False, description="Single source dominates >60% of data")
    market_status: MarketStatus = Field(description="Market stability status")
    system_notes: List[str] = Field(default_factory=list, description="System-generated market warnings")
    
    class Config:
        json_schema_extra = {
            "example": {
                "market_consistency_score": 0.85,
                "outlier_count": 2,
                "excluded_listings": 2,
                "source_dominance": False,
                "market_status": "normal",
                "system_notes": [
                    "Piyasa verisi tutarlı",
                    "2 anomali ilan dışlandı"
                ]
            }
        }


class RiskReport(BaseModel):
    """
    Faz-1.2: Confidence Consistency & Fraud Guard
    
    Detects conflicting findings, variance issues, and fraud risks
    """
    consistency_score: float = Field(ge=0, le=1, description="Overall consistency score (0.0-1.0)")
    fraud_risk_level: FraudRiskLevel = Field(description="Fraud risk assessment")
    anomaly_detected: bool = Field(default=False, description="High-confidence conflict detected")
    analysis_status: AnalysisStatus = Field(description="Analysis execution status")
    blocked_parts: List[str] = Field(default_factory=list, description="Parts excluded from pricing due to conflicts")
    system_notes: List[str] = Field(default_factory=list, description="System-generated warnings and notes")
    
    class Config:
        json_schema_extra = {
            "example": {
                "consistency_score": 0.85,
                "fraud_risk_level": "low",
                "anomaly_detected": False,
                "analysis_status": "normal",
                "blocked_parts": [],
                "system_notes": [
                    "Tüm bulgular tutarlı",
                    "Güven skorları normal aralıkta"
                ]
            }
        }


class AnalysisRequest(BaseModel):
    """Request model for /analyze endpoint"""
    brand: str = Field(min_length=2, description="Vehicle brand")
    model: str = Field(min_length=2, description="Vehicle model")
    year: int = Field(ge=2000, le=2026, description="Model year")
    km: int = Field(ge=0, le=500000, description="Kilometer")
    fuel_type: Optional[str] = Field(default="Benzin", description="Fuel type")
    transmission: Optional[str] = Field(default="Otomatik", description="Transmission type")
    location: Optional[str] = Field(default="Türkiye", description="Search location")
    images: Optional[List[str]] = Field(default=None, description="Image URLs for analysis")
    
    class Config:
        json_schema_extra = {
            "example": {
                "brand": "Volkswagen",
                "model": "Passat",
                "year": 2022,
                "km": 45000,
                "fuel_type": "Benzin",
                "transmission": "Otomatik",
                "location": "İstanbul",
                "images": []
            }
        }


class ExplainabilityLedgerEntry(BaseModel):
    """
    Faz-1.4: Explainability Ledger Entry
    
    Records every decision made during analysis with full traceability
    """
    step_id: int = Field(ge=0, description="Sequential step number")
    step_name: str = Field(description="Name of the analysis step")
    input_snapshot: Dict[str, Any] = Field(default_factory=dict, description="Summary of input data for this step")
    applied_rules: List[str] = Field(default_factory=list, description="Rule IDs that were triggered")
    decisions: List[str] = Field(default_factory=list, description="Human-readable decisions made")
    blocked_entities: List[str] = Field(default_factory=list, description="Entities blocked from pricing (parts, listings, etc.)")
    confidence_impact: Optional[float] = Field(default=None, ge=-1.0, le=1.0, description="Impact on overall confidence score")
    price_impact: Optional[float] = Field(default=None, description="Impact on final price in TL")
    timestamp: datetime = Field(default_factory=datetime.now, description="When this step completed")
    
    class Config:
        json_schema_extra = {
            "example": {
                "step_id": 4,
                "step_name": "Consistency & Fraud Guard",
                "input_snapshot": {
                    "total_findings": 4,
                    "low_confidence_count": 2
                },
                "applied_rules": [
                    "RULE-CON-001",
                    "RULE-CON-003"
                ],
                "decisions": [
                    "Sol ön çamurluk, yüksek güvenli çelişkili bulgular nedeniyle fiyat hesabından çıkarıldı",
                    "Tavan, düşük güven skoru nedeniyle manuel kontrol gerektiriyor"
                ],
                "blocked_entities": [
                    "Sol ön çamurluk"
                ],
                "confidence_impact": -0.25,
                "price_impact": 0.0,
                "timestamp": "2026-01-30T22:50:05"
            }
        }


class ExplainabilityLedger(BaseModel):
    """
    Faz-1.4: Complete Explainability Ledger
    
    Immutable record of all decisions made during analysis.
    Provides legal defense and full audit trail.
    """
    entries: List[ExplainabilityLedgerEntry] = Field(default_factory=list, description="All ledger entries in chronological order")
    final_price: float = Field(ge=0, description="Final estimated price")
    final_consistency_score: float = Field(ge=0, le=1, description="Final consistency score from Faz-1.2")
    final_fraud_risk_level: str = Field(description="Final fraud risk level")
    final_market_status: str = Field(description="Final market status from Faz-1.3")
    ledger_hash: str = Field(description="SHA256 hash for immutability verification")
    audit_ready: bool = Field(default=True, description="Whether ledger is complete and ready for audit")
    
    def compute_hash(self) -> str:
        """
        Compute SHA256 hash of ledger for immutability
        Hash depends on entry order and content
        """
        # Create deterministic string representation
        ledger_dict = {
            "final_price": self.final_price,
            "final_consistency_score": self.final_consistency_score,
            "final_fraud_risk_level": self.final_fraud_risk_level,
            "final_market_status": self.final_market_status,
            "entries": [
                {
                    "step_id": e.step_id,
                    "step_name": e.step_name,
                    "decisions": e.decisions,
                    "blocked_entities": e.blocked_entities,
                    "timestamp": e.timestamp.isoformat()
                }
                for e in self.entries
            ]
        }
        
        # Sort keys for deterministic output
        ledger_str = json.dumps(ledger_dict, sort_keys=True)
        return hashlib.sha256(ledger_str.encode()).hexdigest()
    
    class Config:
        json_schema_extra = {
            "example": {
                "entries": [],
                "final_price": 750064.0,
                "final_consistency_score": 0.85,
                "final_fraud_risk_level": "low",
                "final_market_status": "normal",
                "ledger_hash": "a3f5e8c2...",
                "audit_ready": True
            }
        }


def _default_risk_report() -> RiskReport:
    """Default factory for RiskReport"""
    return RiskReport(
        consistency_score=1.0,
        fraud_risk_level=FraudRiskLevel.LOW,
        anomaly_detected=False,
        analysis_status=AnalysisStatus.NORMAL,
        blocked_parts=[],
        system_notes=["Risk analizi yapılmadı"]
    )


def _default_market_risk_report() -> MarketRiskReport:
    """Default factory for MarketRiskReport"""
    return MarketRiskReport(
        market_consistency_score=1.0,
        outlier_count=0,
        excluded_listings=0,
        source_dominance=False,
        market_status=MarketStatus.NORMAL,
        system_notes=["Piyasa analizi yapılmadı"]
    )


class AnalysisResponse(BaseModel):
    """Complete analysis response for Flutter"""
    success: bool = Field(default=True)
    request: AnalysisRequest
    market_data: MarketData
    core_metrics: CoreMetrics
    image_analysis: Optional[ImageAnalysis] = Field(default=None)
    ai_commentary: AICommentary
    final_recommendation: str = Field(description="Final buy/sell recommendation")
    estimated_value: float = Field(ge=0, description="Estimated fair market value")
    value_range: tuple[float, float] = Field(description="Price range (min, max)")
    visual_price_effects: List[VisualPriceEffect] = Field(default_factory=list, description="Faz-1.1: Visual impact breakdown")
    risk_report: RiskReport = Field(default_factory=_default_risk_report, description="Faz-1.2: Confidence consistency & fraud guard")
    market_risk_report: MarketRiskReport = Field(default_factory=_default_market_risk_report, description="Faz-1.3: Market consistency guard & outlier defense")
    explainability_ledger: Optional[ExplainabilityLedger] = Field(default=None, description="Faz-1.4: Complete decision ledger for audit")
    audit_ready: bool = Field(default=True, description="Whether the analysis is audit-ready")
    ai_engine_used: str = Field(description="AI engine used: 'gemini' | 'glm' | 'static_fallback'")
    analysis_timestamp: datetime = Field(default_factory=datetime.now)
    processing_time_ms: float = Field(ge=0, description="Processing time in milliseconds")
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "market_data": {},
                "core_metrics": {},
                "image_analysis": {},
                "ai_commentary": {},
                "final_recommendation": "ALINABİLİR - Fiyat uygun, kontroller yapılabilir.",
                "estimated_value": 835000.0,
                "value_range": (780000.0, 890000.0),
                "processing_time_ms": 2450.5
            }
        }


class ErrorResponse(BaseModel):
    """Error response model"""
    success: bool = Field(default=False)
    error_type: str = Field(description="Error type")
    error_message: str = Field(description="Detailed error message")
    timestamp: datetime = Field(default_factory=datetime.now)
    
    class Config:
        json_schema_extra = {
            "example": {
                "success": False,
                "error_type": "ScrapingError",
                "error_message": "Unable to fetch data from VavaCars: timeout",
                "timestamp": "2026-01-30T22:50:00"
            }
        }
