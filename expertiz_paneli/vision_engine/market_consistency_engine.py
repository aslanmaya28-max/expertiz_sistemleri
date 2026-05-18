"""
Vision Engine - Market Consistency Engine (Faz-1.3)
Market Consistency Guard & Outlier Defense

Detects anomalous market data, source dominance, and logical inconsistencies
"""

import logging
from typing import List, Tuple
from collections import Counter
import statistics

from .models import (
    CarListing,
    MarketData,
    MarketRiskReport,
    MarketStatus,
    SourceType
)

logger = logging.getLogger(__name__)


class MarketConsistencyEngine:
    """
    Faz-1.3: Market Consistency Guard & Outlier Defense
    
    Analyzes market data for:
    1. Outlier listings (extreme prices)
    2. Source dominance (single platform bias)
    3. Logical inconsistencies (KM vs price)
    
    Filters unreliable data from price calculations
    """
    
    # Thresholds
    OUTLIER_STD_DEV_THRESHOLD = 1.5  # |price - median| > 1.5 × std_dev
    SOURCE_DOMINANCE_THRESHOLD = 0.6  # >60% from single source
    MIN_SAMPLE_SIZE = 5  # Minimum listings for reliable analysis
    
    def analyze_market(self, market_data: MarketData) -> Tuple[MarketRiskReport, List[CarListing]]:
        """
        Analyze market data for consistency and outliers
        
        Returns:
            Tuple of (market_risk_report, valid_listings)
        """
        
        if not market_data.listings:
            logger.warning("⚠️ No market data to analyze")
            return self._create_clean_report(), []
        
        logger.info(f"📊 Analyzing {len(market_data.listings)} market listings for consistency...")
        
        # Step 1: Calculate statistics
        prices = [listing.price for listing in market_data.listings]
        median_price = statistics.median(prices)
        
        # Calculate std deviation
        if len(prices) > 1:
            std_dev = statistics.stdev(prices)
        else:
            std_dev = 0
        
        logger.info(f"  📈 Median: {median_price:,.0f} TL, Std Dev: {std_dev:,.0f} TL")
        
        # Step 2: Detect outliers (Rule A)
        outlier_indices = set()
        for i, listing in enumerate(market_data.listings):
            deviation = abs(listing.price - median_price)
            threshold = self.OUTLIER_STD_DEV_THRESHOLD * std_dev
            
            if deviation > threshold:
                outlier_indices.add(i)
                logger.warning(f"  🔴 OUTLIER: {listing.source.value} - {listing.price:,.0f} TL "
                             f"(deviation: {deviation:,.0f} TL > threshold: {threshold:,.0f} TL)")
        
        outlier_count = len(outlier_indices)
        
        # Step 3: Check source dominance (Rule B)
        sources = [listing.source for listing in market_data.listings]
        source_counts = Counter(sources)
        total_listings = len(market_data.listings)
        
        dominant_source = None
        source_dominance = False
        
        for source, count in source_counts.items():
            ratio = count / total_listings
            if ratio > self.SOURCE_DOMINANCE_THRESHOLD:
                source_dominance = True
                dominant_source = source
                logger.warning(f"  ⚠️ SOURCE DOMINANCE: {source.value} = {ratio:.1%} (>60%)")
        
        # Step 4: Check logical inconsistencies (Rule C)
        # Group by year and check KM vs price correlation
        logical_inconsistencies = self._check_logical_consistency(market_data.listings)
        
        # Step 5: Filter out outliers
        valid_listings = [
            listing for i, listing in enumerate(market_data.listings)
            if i not in outlier_indices
        ]
        excluded_count = outlier_count
        
        # Step 6: Calculate consistency score
        outlier_ratio = outlier_count / total_listings if total_listings > 0 else 0
        consistency_score = self._calculate_consistency_score(
            outlier_ratio=outlier_ratio,
            source_dominance=source_dominance,
            logical_inconsistencies=len(logical_inconsistencies)
        )
        
        # Step 7: Determine market status
        market_status = self._determine_market_status(consistency_score)
        
        # Step 8: Generate system notes
        system_notes = self._generate_system_notes(
            outlier_count=outlier_count,
            excluded_count=excluded_count,
            source_dominance=source_dominance,
            dominant_source=dominant_source,
            market_status=market_status,
            total_listings=total_listings,
            valid_listings=len(valid_listings)
        )
        
        # Create market risk report
        market_risk_report = MarketRiskReport(
            market_consistency_score=consistency_score,
            outlier_count=outlier_count,
            excluded_listings=excluded_count,
            source_dominance=source_dominance,
            market_status=market_status,
            system_notes=system_notes
        )
        
        logger.info(
            f"✅ Market analysis complete: "
            f"Score={consistency_score:.2f}, "
            f"Status={market_status.value}, "
            f"Outliers={outlier_count}, "
            f"Valid={len(valid_listings)}"
        )
        
        return market_risk_report, valid_listings
    
    def _check_logical_consistency(self, listings: List[CarListing]) -> List[str]:
        """
        Rule C: Check KM/Price logical consistency
        
        For same year vehicles:
        - Higher KM should generally mean lower price
        - Significant violations indicate data issues
        """
        inconsistencies = []
        
        # Group by year
        by_year = {}
        for listing in listings:
            year = listing.year
            if year not in by_year:
                by_year[year] = []
            by_year[year].append(listing)
        
        # Check each year group
        for year, year_listings in by_year.items():
            if len(year_listings) < 3:
                continue  # Need at least 3 listings for meaningful comparison
            
            # Sort by KM
            sorted_by_km = sorted(year_listings, key=lambda x: x.km)
            
            # Check for price inversions (higher KM but higher price)
            for i in range(len(sorted_by_km) - 1):
                current = sorted_by_km[i]
                next_listing = sorted_by_km[i + 1]
                
                # If next has higher KM but significantly higher price (>10%)
                if next_listing.km > current.km:
                    if next_listing.price > current.price * 1.1:
                        inconsistencies.append(
                            f"Year {year}: KM inconsistency detected "
                            f"({current.km}km @ {current.price:,.0f} TL vs "
                            f"{next_listing.km}km @ {next_listing.price:,.0f} TL)"
                        )
                        logger.warning(f"  ⚠️ LOGICAL INCONSISTENCY: {inconsistencies[-1]}")
                        break  # Only report first inconsistency per year
        
        return inconsistencies
    
    def _calculate_consistency_score(
        self,
        outlier_ratio: float,
        source_dominance: bool,
        logical_inconsistencies: int
    ) -> float:
        """
        Calculate market consistency score (0.0 - 1.0)
        
        Formula:
        score = 1.0
               - (outlier_ratio × 0.4)
               - (source_dominance ? 0.3 : 0.0)
               - (logical_inconsistencies × 0.1)
        """
        score = 1.0
        
        # Penalty for outliers
        score -= min(outlier_ratio * 0.4, 0.4)
        
        # Penalty for source dominance
        if source_dominance:
            score -= 0.3
        
        # Penalty for logical inconsistencies
        score -= min(logical_inconsistencies * 0.1, 0.3)
        
        # Ensure score is in valid range
        return max(0.0, min(score, 1.0))
    
    def _determine_market_status(self, consistency_score: float) -> MarketStatus:
        """Determine market status based on consistency score"""
        
        if consistency_score >= 0.8:
            return MarketStatus.NORMAL
        elif consistency_score >= 0.5:
            return MarketStatus.GUARDED
        else:
            return MarketStatus.UNSTABLE
    
    def _generate_system_notes(
        self,
        outlier_count: int,
        excluded_count: int,
        source_dominance: bool,
        dominant_source: SourceType,
        market_status: MarketStatus,
        total_listings: int,
        valid_listings: int
    ) -> List[str]:
        """Generate system notes based on analysis results"""
        
        notes = []
        
        if market_status == MarketStatus.NORMAL:
            notes.append(f"✅ Piyasa verisi tutarlı ({valid_listings}/{total_listings} ilan geçerli)")
            if outlier_count > 0:
                notes.append(f"ℹ️ {outlier_count} anomali ilan dışlandı")
        elif market_status == MarketStatus.GUARDED:
            notes.append(f"⚠️ Piyasa verisi kısmen güvenilmez ({valid_listings}/{total_listings} ilan geçerli)")
            notes.append(f"⚠️ {excluded_count} ilan fiyat hesaplamasına dahil edilmedi")
            if source_dominance:
                notes.append(f"⚠️ Tek kaynak baskın: {dominant_source.value if dominant_source else 'Bilinmiyor'}")
        else:  # UNSTABLE
            notes.append(f"🚨 Piyasa verisi anormal dalgalanıyor ({valid_listings}/{total_listings} ilan geçerli)")
            notes.append(f"🚨 {excluded_count} ilan dışlandı - fiyat stabilizasyonu uygulandı")
            if source_dominance:
                notes.append(f"🚨 Kritik: Piyasa tek kaynağa bağımlı ({dominant_source.value if dominant_source else 'Bilinmiyor'})")
        
        return notes
    
    def _create_clean_report(self) -> MarketRiskReport:
        """Create default clean market risk report when no data"""
        return MarketRiskReport(
            market_consistency_score=1.0,
            outlier_count=0,
            excluded_listings=0,
            source_dominance=False,
            market_status=MarketStatus.NORMAL,
            system_notes=["Piyasa verisi yok - analiz gerekli değil"]
        )