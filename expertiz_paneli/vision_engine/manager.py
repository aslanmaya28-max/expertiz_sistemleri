"""
Vision Engine - Main Manager
Orchestrates all layers: Collector → Core Engine → AI Commentary → Image Analysis
"""

import time
import asyncio
import logging
from typing import Optional
from datetime import datetime

from .collectors import MultiSourceCollector
from .core_engine import CoreEngine, AdjustmentsCalculator
from .ai_commentary import ExpertizAIService
from .image_analysis import ImageAnalysisService, FactorMatching
from .consistency_engine import ConsistencyEngine
from .market_consistency_engine import MarketConsistencyEngine
from .explainability_ledger import ExplainabilityLedgerService
from .models import (
    AnalysisRequest,
    AnalysisResponse,
    MarketData,
    ErrorResponse,
    RiskReport,
    MarketRiskReport
)

logger = logging.getLogger(__name__)


class VisionEngineManager:
    """
    Main orchestrator for Vision Engine
    Coordinates all layers to produce complete analysis
    """
    
    def __init__(self):
        self.collector = MultiSourceCollector()
        self.core_engine = CoreEngine()
        self.ai_commentary = ExpertizAIService()
        self.image_analysis = ImageAnalysisService()
        self.consistency_engine = ConsistencyEngine()
        self.market_consistency_engine = MarketConsistencyEngine()
        self.ledger_service = ExplainabilityLedgerService()
        self.adjustments = AdjustmentsCalculator()
        self.factor_matching = FactorMatching()
    
    async def analyze(self, request: AnalysisRequest) -> AnalysisResponse:
        """
        Complete vehicle analysis workflow
        Returns comprehensive AnalysisResponse
        """
        
        start_time = time.time()
        logger.info(f"🚀 Starting Vision Engine analysis: {request.brand} {request.model} {request.year}")
        
        # Initialize ledger service
        self.ledger_service = ExplainabilityLedgerService()
        
        try:
            # Step 1: Multi-Source Data Collection
            logger.info("📡 Step 1/8: Collecting market data...")
            listings = await self.collector.collect_all(
                brand=request.brand,
                model=request.model,
                year=request.year,
                location=request.location
            )
            
            if not listings:
                logger.error("❌ No listings found - cannot proceed with analysis")
                return self._create_error_response(request, "NoDataError", "No listings found")
            
            # Create market data
            sources = list(set(l.source.value for l in listings))
            price_range = (min(l.price for l in listings), max(l.price for l in listings))
            
            market_data = MarketData(
                listings=listings,
                total_sources=len(set(l.source for l in listings)),
                scrape_timestamp=datetime.now()
            )
            
            # Ledger: Step 1
            self.ledger_service.add_market_data_collection(
                total_listings=len(listings),
                sources=sources,
                price_range=price_range
            )
            
            # Step 2: Market Consistency Guard (Faz-1.3)
            logger.info("🔒 Step 2/8: Running Market Consistency Guard (Faz-1.3)...")
            market_risk_report, valid_listings = self.market_consistency_engine.analyze_market(market_data)
            logger.info(f"🔒 Market: Score={market_risk_report.market_consistency_score:.2f}, "
                      f"Status={market_risk_report.market_status.value}, "
                      f"Outliers={market_risk_report.outlier_count}")
            
            # Ledger: Step 2
            self.ledger_service.add_market_consistency_check(
                market_risk_report=market_risk_report,
                excluded_count=len(listings) - len(valid_listings)
            )
            
            # Update market data with filtered listings
            filtered_market_data = MarketData(
                listings=valid_listings,
                total_sources=len(set(l.source for l in valid_listings)),
                scrape_timestamp=datetime.now()
            )
            
            # Step 3: Core Engine Analysis (with filtered data)
            logger.info("🧮 Step 3/8: Running Core Engine analysis...")
            metrics = self.core_engine.analyze(filtered_market_data)
            
            # Ledger: Step 3
            self.ledger_service.add_core_metrics_analysis(
                metrics={
                    "avg_price": metrics.avg_price,
                    "median_price": metrics.median_price,
                    "std_deviation": metrics.std_deviation,
                    "confidence_score": metrics.confidence_score,
                    "sample_size": metrics.sample_size
                }
            )
            
            # Step 4: Image Analysis (Faz-1: Stateless Vision)
            image_analysis = None
            if request.images:
                logger.info("📸 Step 4/8: Analyzing images (Faz-1)...")
                image_analysis = await self.image_analysis.analyze_images(request.images)
                
                # Ledger: Step 4
                if image_analysis:
                    high_conf_count = sum(
                        1 for f in image_analysis.visual_findings 
                        if f.guven_skoru >= 0.6
                    )
                    self.ledger_service.add_image_analysis(
                        total_images=len(request.images),
                        total_findings=len(image_analysis.visual_findings),
                        high_confidence_count=high_conf_count
                    )
            
            # Step 5: Consistency & Fraud Guard (Faz-1.2)
            risk_report = RiskReport(
                consistency_score=1.0,
                fraud_risk_level="low",
                anomaly_detected=False,
                analysis_status="normal",
                blocked_parts=[],
                system_notes=["Risk analizi yapılmadı"]
            )
            blocked_parts = set()
            
            if image_analysis and image_analysis.visual_findings:
                logger.info("🔒 Step 5/8: Running Consistency & Fraud Guard (Faz-1.2)...")
                risk_report, blocked_parts = self.consistency_engine.analyze_findings(
                    image_analysis.visual_findings
                )
                logger.info(f"🔒 Risk: Score={risk_report.consistency_score:.2f}, "
                          f"Fraud={risk_report.fraud_risk_level.value}, "
                          f"Blocked={len(blocked_parts)}")
                
                # Ledger: Step 5
                self.ledger_service.add_consistency_check(
                    risk_report=risk_report,
                    blocked_parts=list(blocked_parts)
                )
            
            # Step 6: AI Commentary with Market & Risk Awareness
            logger.info("🤖 Step 6/8: Generating AI commentary (Market + Risk aware)...")
            
            # Prepare adjustments with market and risk reports
            adjustments = {
                "market_risk_report": market_risk_report,
                "risk_report": risk_report,
                "blocked_parts": list(blocked_parts),
                "market_status": market_risk_report.market_status.value
            }
            
            commentary, ai_engine_used = await self.ai_commentary.generate_commentary(
                request=request,
                metrics=metrics,
                adjustments=adjustments
            )
            logger.info(f"✅ AI Commentary generated using engine: {ai_engine_used}")
            
            # Step 7: Calculate Final Value
            logger.info("💰 Step 7/8: Calculating final fair value...")
            
            # Calculate fair value with visual impact breakdown
            fair_value, visual_multiplier, visual_price_effects = self.core_engine.estimate_fair_value(
                metrics=metrics,
                image_analysis=image_analysis,
                km=request.km
            )
            logger.info(f"💰 Fair value: {fair_value:,.0f} TL, Visual: {visual_multiplier:.2f}")
            
            # Ledger: Step 7 - Pricing Calculation
            # Calculate KM adjustment for ledger
            base_price = metrics.median_price
            km_adjustment = fair_value - base_price - sum(e.price_delta for e in visual_price_effects)
            
            visual_effects_dict = [
                {
                    "parca_adi": e.parca_adi,
                    "bulgu_tipi": e.bulgu_tipi.value,
                    "price_delta": e.price_delta,
                    "applied": e.applied
                }
                for e in visual_price_effects
            ]
            
            self.ledger_service.add_pricing_calculation(
                base_price=base_price,
                visual_effects=visual_effects_dict,
                km_adjustment=km_adjustment,
                final_price=fair_value,
                market_status=market_risk_report.market_status.value
            )
            
            # Get value range
            value_range = self.core_engine.get_value_range(metrics)
            
            # Generate final recommendation with market awareness
            recommendation = self.ai_commentary.generate_final_recommendation(
                metrics=metrics,
                commentary=commentary,
                market_status=market_risk_report.market_status
            )
            
            # Calculate processing time
            processing_time = (time.time() - start_time) * 1000  # Convert to ms
            
            # Step 8: Finalize Ledger
            logger.info("📝 Step 8/8: Finalizing Explainability Ledger...")
            explainability_ledger = self.ledger_service.finalize_ledger(
                final_price=fair_value,
                consistency_score=risk_report.consistency_score,
                fraud_risk_level=risk_report.fraud_risk_level.value,
                market_status=market_risk_report.market_status.value
            )
            logger.info(f"🔐 Ledger hash: {explainability_ledger.ledger_hash[:16]}...")
            
            # Build response with Faz-1.4 Explainability Ledger
            response = AnalysisResponse(
                success=True,
                request=request,
                market_data=market_data,
                core_metrics=metrics,
                image_analysis=image_analysis,
                ai_commentary=commentary,
                final_recommendation=recommendation,
                estimated_value=fair_value,
                value_range=value_range,
                visual_price_effects=visual_price_effects,
                risk_report=risk_report,
                market_risk_report=market_risk_report,
                explainability_ledger=explainability_ledger,
                audit_ready=explainability_ledger.audit_ready,
                ai_engine_used=ai_engine_used,
                analysis_timestamp=datetime.now(),
                processing_time_ms=processing_time
            )
            
            logger.info(f"✅ Analysis complete in {processing_time:.0f}ms")
            return response
            
        except Exception as e:
            logger.error(f"❌ Analysis failed: {e}", exc_info=True)
            return self._create_error_response(request, "AnalysisError", str(e))
    
    def _create_error_response(
        self,
        request: AnalysisRequest,
        error_type: str,
        error_message: str
    ) -> AnalysisResponse:
        """Create error response for failed analysis"""
        
        return AnalysisResponse(
            success=False,
            request=request,
            market_data=MarketData(listings=[]),
            core_metrics=self.core_engine._create_default_metrics(),
            ai_commentary=self.ai_commentary._static_fallback_commentary(
                request,
                self.core_engine._create_default_metrics(),
                self.ai_commentary._prepare_analysis_context(
                    request,
                    self.core_engine._create_default_metrics(),
                    {}
                )
            ),
            final_recommendation=f"Analiz başarısız: {error_message}",
            estimated_value=0.0,
            value_range=(0.0, 0.0),
            ai_engine_used="static_fallback",
            processing_time_ms=0.0
        )
    
    async def close(self):
        """Clean up resources"""
        await self.collector.close_all()


# Singleton instance
_manager_instance: Optional[VisionEngineManager] = None


def get_manager() -> VisionEngineManager:
    """Get or create singleton manager instance"""
    global _manager_instance
    if _manager_instance is None:
        _manager_instance = VisionEngineManager()
    return _manager_instance


async def analyze_vehicle(request: AnalysisRequest) -> AnalysisResponse:
    """
    Convenience function for quick analysis
    Usage: result = await analyze_vehicle(request)
    """
    manager = get_manager()
    return await manager.analyze(request)