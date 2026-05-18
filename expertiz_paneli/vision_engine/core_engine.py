"""
Vision Engine - Core Statistical Engine
IQR Outlier Removal, Volatility Index, Confidence Score Calculation
"""

import statistics
import logging
from typing import List, Tuple, Optional
import numpy as np
from .models import CarListing, CoreMetrics, MarketData, ImageAnalysis, FindingType, VisualFinding, VisualPriceEffect

logger = logging.getLogger(__name__)


class CoreEngine:
    """
    Statistical brain of the Vision Engine
    Performs robust statistical analysis with outlier removal
    """
    
    def __init__(self):
        self.minimum_sample_size = 3  # Minimum data points for analysis
        self.iqr_multiplier = 1.5     # IQR outlier detection multiplier
    
    def analyze(self, market_data: MarketData) -> CoreMetrics:
        """
        Perform complete statistical analysis on market data
        Returns CoreMetrics with outlier-removed statistics
        """
        logger.info("🧮 Starting Core Engine analysis")
        
        # Extract prices
        prices = [listing.price for listing in market_data.listings]
        sample_size = len(prices)
        
        if sample_size < self.minimum_sample_size:
            logger.warning(f"⚠️ Insufficient data: {sample_size} listings")
            return self._create_default_metrics()
        
        # Remove outliers using IQR method
        cleaned_prices, iqr_bounds = self._remove_outliers_iqr(prices)
        logger.info(f"📊 Outlier removal: {len(prices)} -> {len(cleaned_prices)} listings")
        
        # Calculate statistics on cleaned data
        avg_price = statistics.mean(cleaned_prices)
        median_price = statistics.median(cleaned_prices)
        std_deviation = statistics.stdev(cleaned_prices) if len(cleaned_prices) > 1 else 0.0
        min_price = min(cleaned_prices)
        max_price = max(cleaned_prices)
        
        # Calculate confidence score
        confidence_score = self._calculate_confidence_score(sample_size, std_deviation, avg_price)
        
        # Calculate volatility index
        volatility_index = self._calculate_volatility_index(std_deviation, avg_price)
        
        metrics = CoreMetrics(
            avg_price=avg_price,
            median_price=median_price,
            std_deviation=std_deviation,
            min_price=min_price,
            max_price=max_price,
            confidence_score=confidence_score,
            volatility_index=volatility_index,
            iqr_lower_bound=iqr_bounds[0],
            iqr_upper_bound=iqr_bounds[1],
            sample_size=sample_size
        )
        
        logger.info(f"✅ Analysis complete: Avg={avg_price:.0f} TL, Confidence={confidence_score:.1f}%")
        return metrics
    
    def _remove_outliers_iqr(self, prices: List[float]) -> Tuple[List[float], Tuple[float, float]]:
        """
        Remove outliers using Interquartile Range (IQR) method
        More robust than z-score for skewed distributions
        """
        # Calculate quartiles
        q1 = np.percentile(prices, 25)
        q3 = np.percentile(prices, 75)
        iqr = q3 - q1
        
        # Calculate bounds
        lower_bound = q1 - (self.iqr_multiplier * iqr)
        upper_bound = q3 + (self.iqr_multiplier * iqr)
        
        # Filter outliers
        cleaned_prices = [p for p in prices if lower_bound <= p <= upper_bound]
        
        return cleaned_prices, (lower_bound, upper_bound)
    
    def _calculate_confidence_score(self, sample_size: int, std_deviation: float, mean: float) -> float:
        """
        Calculate confidence score (0-100)
        Based on sample size and coefficient of variation
        """
        if mean == 0:
            return 0.0
        
        # Coefficient of variation (CV)
        cv = (std_deviation / mean) * 100
        
        # Sample size score (0-50 points)
        # More data = higher confidence
        sample_score = min(50, (sample_size / 50) * 50)
        
        # CV score (0-50 points)
        # Lower CV = higher confidence
        cv_score = max(0, min(50, 50 - cv))
        
        # Total confidence score
        confidence = sample_score + cv_score
        
        return round(confidence, 1)
    
    def _calculate_volatility_index(self, std_deviation: float, mean: float) -> float:
        """
        Calculate market volatility index
        Higher values indicate more price variation
        """
        if mean == 0:
            return 0.0
        
        # Coefficient of variation as volatility index
        volatility = (std_deviation / mean)
        
        return round(volatility, 4)
    
    def _create_default_metrics(self) -> CoreMetrics:
        """Create default metrics when insufficient data"""
        return CoreMetrics(
            avg_price=0.0,
            median_price=0.0,
            std_deviation=0.0,
            min_price=0.0,
            max_price=0.0,
            confidence_score=0.0,
            volatility_index=0.0,
            iqr_lower_bound=0.0,
            iqr_upper_bound=0.0,
            sample_size=0
        )
    
    def estimate_fair_value(
        self, 
        metrics: CoreMetrics, 
        image_analysis: Optional[ImageAnalysis] = None,
        km: int = 0
    ) -> Tuple[float, float, List[VisualPriceEffect]]:
        """
        Estimate fair market value with adjustments
        
        Faz-1.1: Returns visual price effects for explainability
        
        Adjustment factors (only if guven_skoru >= 0.6):
        - Boya: -3%
        - Değişen: -7%
        - Hizasızlık: -4%
        - Hasar: -6%
        - KM: -2% per 10,000 excess km
        
        Args:
            metrics: Core market metrics
            image_analysis: Visual findings from AI (optional)
            km: Vehicle kilometer (optional)
        
        Returns:
            Tuple of (final_price, visual_multiplier, visual_price_effects)
        """
        base_value = metrics.avg_price
        
        # 1. Visual findings adjustment (Faz-1.1: Explainable)
        visual_price_effects, visual_multiplier = self.calculate_visual_price_effects(
            base_price=base_value,
            visual_findings=image_analysis.visual_findings if image_analysis else []
        )
        
        # 2. KM adjustment
        km_factor = 1.0
        if km > 0:
            km_factor = self._calculate_km_adjustment(km)
            logger.info(f"📏 KM adjustment factor: {km_factor:.2f}")
        
        total_factor = visual_multiplier * km_factor
        fair_value = base_value * total_factor
        
        logger.info(f"💰 Fair value: {fair_value:.0f} TL (base: {base_value:.0f}, visual: {visual_multiplier:.2f}, km: {km_factor:.2f})")
        
        return fair_value, visual_multiplier, visual_price_effects
    
    def calculate_visual_price_effects(
        self,
        base_price: float,
        visual_findings: List[VisualFinding]
    ) -> Tuple[List[VisualPriceEffect], float]:
        """
        Faz-1.1: Calculate explainable visual price effects
        
        Shows line-by-line impact of each visual finding on the final price.
        
        RULES:
        - Only apply effects where confidence >= 0.6
        - applied_penalty_percent = base_penalty_percent × confidence
        - price_delta = base_price × (applied_penalty_percent / 100)
        - Cap total visual penalty at -30%
        
        Args:
            base_price: Base price before visual adjustments
            visual_findings: List of visual findings from AI
        
        Returns:
            Tuple of (visual_price_effects_list, final_visual_multiplier)
        """
        if not visual_findings:
            return [], 1.0
        
        # Base penalty percentages
        base_penalties = {
            FindingType.BOYA: 3.0,       # 3%
            FindingType.DEGISEN: 7.0,    # 7%
            FindingType.HIZALIKLIK: 4.0, # 4%
            FindingType.HASAR: 6.0       # 6%
        }
        
        visual_price_effects = []
        total_adjustment = 0.0
        
        for finding in visual_findings:
            # Get base penalty
            base_penalty = base_penalties.get(finding.bulgu_tipi, 0.0)
            
            # Confidence threshold
            applied = finding.guven_skoru >= 0.6
            
            # Calculate applied penalty
            if applied:
                applied_penalty = base_penalty * finding.guven_skoru
                price_delta = base_price * (applied_penalty / 100)
                total_adjustment += applied_penalty
            else:
                applied_penalty = 0.0
                price_delta = 0.0
            
            # Create visual price effect
            effect = VisualPriceEffect(
                parca_adi=finding.parca_adi,
                bulgu_tipi=finding.bulgu_tipi,
                base_penalty_percent=base_penalty,
                confidence=finding.guven_skoru,
                applied_penalty_percent=applied_penalty,
                price_delta=-price_delta if applied else 0.0,
                applied=applied
            )
            
            visual_price_effects.append(effect)
            
            if applied:
                logger.info(f"  ✓ {finding.parca_adi}: {finding.bulgu_tipi.value} - Base: %{base_penalty:.1f}, Applied: %{applied_penalty:.2f}, Delta: {-price_delta:,.0f} TL")
            else:
                logger.info(f"  ✗ {finding.parca_adi}: {finding.bulgu_tipi.value} - SKIPPED (confidence: {finding.guven_skoru:.2f} < 0.6)")
        
        # Cap total visual penalty at -30%
        total_adjustment = max(total_adjustment, -30.0)
        visual_multiplier = 1.0 + (total_adjustment / 100.0)
        
        logger.info(f"📸 Visual effects: {len(visual_price_effects)} findings, total adjustment: %{total_adjustment:.2f}, multiplier: {visual_multiplier:.2f}")
        
        return visual_price_effects, visual_multiplier
    
    def _calculate_visual_adjustment(self, image_analysis: ImageAnalysis) -> float:
        """
        Calculate adjustment factor from visual findings
        
        CONFIDENCE RULE: Only apply adjustments for findings with guven_skoru >= 0.6
        """
        if not image_analysis.visual_findings:
            return 1.0
        
        # Adjustment factors per finding type
        factors = {
            FindingType.BOYA: -0.03,      # -3% per painted part
            FindingType.DEGISEN: -0.07,   # -7% per replaced part
            FindingType.HIZALIKLIK: -0.04, # -4% per alignment issue
            FindingType.HASAR: -0.06      # -6% per damaged part
        }
        
        total_adjustment = 0.0
        findings_applied = 0
        
        for finding in image_analysis.visual_findings:
            # Confidence threshold: 0.6
            if finding.guven_skoru < 0.6:
                # Skip low confidence findings
                continue
            
            # Get adjustment factor
            factor = factors.get(finding.bulgu_tipi, 0.0)
            
            # Weight by confidence score
            weighted_factor = factor * finding.guven_skoru
            
            total_adjustment += weighted_factor
            findings_applied += 1
            
            logger.info(f"  ✓ {finding.parca_adi}: {finding.bulgu_tipi.value} (guven: {finding.guven_skoru:.2f}, ayar: {weighted_factor:.2%})")
        
        # Apply bounds: Max penalty -30%, max bonus 0%
        total_adjustment = max(total_adjustment, -0.30)
        
        final_factor = 1.0 + total_adjustment
        
        logger.info(f"📸 Visual findings applied: {findings_applied}, total adjustment: {total_adjustment:.2%}, factor: {final_factor:.2f}")
        
        return final_factor
    
    def _calculate_km_adjustment(self, km: int, expected_km_per_year: int = 15000) -> float:
        """
        Calculate adjustment factor based on kilometer
        
        Expected: 15,000 km per year
        Penalty: -2% per 10,000 excess km
        Max penalty: -15%
        """
        # Calculate expected km based on vehicle age
        # Assuming current year 2026, average vehicle age 5 years
        expected_total_km = 5 * expected_km_per_year  # 75,000 km
        
        excess_km = max(0, km - expected_total_km)
        
        if excess_km == 0:
            return 1.0
        
        # Calculate penalty: -2% per 10,000 excess km
        penalty = (excess_km / 10000) * 0.02
        
        # Max penalty: 15%
        penalty = min(penalty, 0.15)
        
        factor = 1.0 - penalty
        
        logger.info(f"📏 KM adjustment: {km:,} km (excess: {excess_km:,}), penalty: {penalty:.2%}, factor: {factor:.2f}")
        
        return factor
    
    def get_value_range(self, metrics: CoreMetrics, confidence_interval: float = 0.9) -> Tuple[float, float]:
        """
        Calculate value range based on confidence interval
        """
        # Use standard deviation for range calculation
        margin = metrics.std_deviation * confidence_interval
        
        min_value = metrics.avg_price - margin
        max_value = metrics.avg_price + margin
        
        # Ensure bounds are within IQR
        min_value = max(min_value, metrics.iqr_lower_bound)
        max_value = min(max_value, metrics.iqr_upper_bound)
        
        return (round(min_value, 2), round(max_value, 2))
    
    def calculate_depreciation(self, base_value: float, year: int, current_year: int = 2026) -> dict:
        """
        Calculate annual depreciation and future projections
        """
        age = current_year - year
        
        # Typical annual depreciation rate (varies by brand/segment)
        annual_rate = 0.12  # 12% per year
        
        # Calculate depreciation
        depreciation = base_value * (annual_rate * age)
        
        # Future projections
        projection_6months = base_value * (1 - (annual_rate / 2))
        projection_1year = base_value * (1 - annual_rate)
        
        return {
            "current_depreciation": depreciation,
            "depreciation_rate": annual_rate,
            "value_6_months": projection_6months,
            "value_1_year": projection_1year
        }


class AdjustmentsCalculator:
    """Calculate adjustment factors based on vehicle condition"""
    
    @staticmethod
    def paint_adjustment(painted_parts: List[str]) -> float:
        """
        Calculate price adjustment for painted parts
        Each painted part reduces value by 2-5%
        """
        if not painted_parts:
            return 1.0
        
        # Calculate adjustment
        total_reduction = len(painted_parts) * 0.03  # 3% per painted part
        factor = 1.0 - min(total_reduction, 0.20)  # Max 20% reduction
        
        logger.info(f"🎨 Paint adjustment: {len(painted_parts)} parts, factor={factor:.2f}")
        return factor
    
    @staticmethod
    def damage_adjustment(damaged_parts: List[str]) -> float:
        """
        Calculate price adjustment for damaged parts
        Each damaged part reduces value by 5-15%
        """
        if not damaged_parts:
            return 1.0
        
        # Calculate adjustment
        total_reduction = len(damaged_parts) * 0.10  # 10% per damaged part
        factor = 1.0 - min(total_reduction, 0.40)  # Max 40% reduction
        
        logger.info(f"⚠️ Damage adjustment: {len(damaged_parts)} parts, factor={factor:.2f}")
        return factor
    
    @staticmethod
    def km_adjustment(km: int, expected_km: int = 15000) -> float:
        """
        Calculate adjustment based on kilometer
        Expected average: 15,000 km per year
        """
        excess_km = max(0, km - expected_km)
        
        # Each 10,000 excess km reduces value by 2%
        reduction = (excess_km / 10000) * 0.02
        factor = 1.0 - min(reduction, 0.15)  # Max 15% reduction
        
        logger.info(f"📏 KM adjustment: {km} km (excess: {excess_km}), factor={factor:.2f}")
        return factor