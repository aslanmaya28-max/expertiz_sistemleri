"""
Vision Engine - Explainability Ledger (Faz-1.4)
Decision Traceability & Legal Defense Layer

Records every decision made during analysis with full audit trail.
Provides legal defense and makes AI arbitrariness technically impossible.
"""

import logging
from typing import List, Dict, Any, Optional
from datetime import datetime

from .models import (
    ExplainabilityLedger,
    ExplainabilityLedgerEntry,
    MarketRiskReport,
    RiskReport,
    MarketStatus
)

logger = logging.getLogger(__name__)


class RuleTemplates:
    """
    Rule templates and explanations
    Fixed templates (not AI-generated) for consistent audit trails
    """
    
    # Market Rules (Faz-1.3)
    RULE_MKT_001 = "Outlier detection: Price deviation exceeds 1.5σ from median"
    RULE_MKT_002 = "Source dominance: Single source provides >60% of data"
    RULE_MKT_003 = "Logical inconsistency: KM/Price correlation violation detected"
    
    # Consistency Rules (Faz-1.2)
    RULE_CON_001 = "Cross-consistency: Same part has conflicting finding types"
    RULE_CON_002 = "Variance guard: Confidence variance exceeds threshold (0.35)"
    RULE_CON_003 = "Low confidence: Finding confidence below threshold (0.6)"
    RULE_CON_004 = "Fraud detection: High-confidence conflicting findings detected"
    RULE_CON_005 = "Saturation guard: >50% findings have low confidence"
    
    # Pricing Rules
    RULE_PRI_001 = "Base penalty: Visual finding type applied"
    RULE_PRI_002 = "Confidence scaling: Penalty adjusted by confidence score"
    RULE_PRI_003 = "KM adjustment: Mileage penalty applied"
    RULE_PRI_004 = "Market adjustment: Price adjusted based on market data"
    
    @classmethod
    def get_rule_description(cls, rule_id: str) -> str:
        """Get human-readable rule description"""
        return getattr(cls, rule_id, rule_id)


class ExplainabilityLedgerService:
    """
    Faz-1.4: Explainability Ledger Service
    
    Automatically records every decision during analysis.
    No manual recording required - workflow integration is automatic.
    """
    
    def __init__(self):
        self.entries: List[ExplainabilityLedgerEntry] = []
        self.step_counter = 0
    
    def add_market_data_collection(
        self,
        total_listings: int,
        sources: List[str],
        price_range: tuple[float, float]
    ) -> None:
        """Record Step 1: Market Data Collection"""
        self.step_counter += 1
        
        decisions = [
            f"{total_listings} ilan toplandı",
            f"Fiyat aralığı: {price_range[0]:,.0f} - {price_range[1]:,.0f} TL",
            f"Kaynaklar: {', '.join(sources)}"
        ]
        
        entry = ExplainabilityLedgerEntry(
            step_id=self.step_counter,
            step_name="Market Data Collection",
            input_snapshot={
                "total_listings": total_listings,
                "sources": sources,
                "price_range": price_range
            },
            applied_rules=[],
            decisions=decisions,
            blocked_entities=[],
            confidence_impact=None,
            price_impact=None,
            timestamp=datetime.now()
        )
        
        self.entries.append(entry)
        logger.info(f"📝 Ledger entry added: Step {self.step_counter} - Market Data Collection")
    
    def add_market_consistency_check(
        self,
        market_risk_report: MarketRiskReport,
        excluded_count: int
    ) -> None:
        """Record Step 2: Market Consistency Check (Faz-1.3)"""
        self.step_counter += 1
        
        applied_rules = []
        decisions = []
        blocked_entities = []
        
        # Record outliers
        if market_risk_report.outlier_count > 0:
            applied_rules.append(RuleTemplates.RULE_MKT_001)
            decisions.append(
                f"{market_risk_report.outlier_count} anomali ilan dışlandı "
                f"(fiyattan {excluded_count} ilan hariç)"
            )
            blocked_entities.extend([f"Listing-{i}" for i in range(excluded_count)])
        
        # Record source dominance
        if market_risk_report.source_dominance:
            applied_rules.append(RuleTemplates.RULE_MKT_002)
            decisions.append(
                "Tek kaynak baskınlığı tespit edildi - piyasa verisi güvenilir değil"
            )
        
        # Record market status
        if market_risk_report.market_status == MarketStatus.GUARDED:
            decisions.append("Piyasa durumu: KORUMALI - Görsel etkiler %50 uygulanacak")
        elif market_risk_report.market_status == MarketStatus.UNSTABLE:
            decisions.append("Piyasa durumu: STABİL DEĞİL - Görsel etkiler uygulanmayacak")
        else:
            decisions.append("Piyasa durumu: NORMAL - Standart fiyatlandırma")
        
        entry = ExplainabilityLedgerEntry(
            step_id=self.step_counter,
            step_name="Market Consistency Guard (Faz-1.3)",
            input_snapshot={
                "consistency_score": market_risk_report.market_consistency_score,
                "market_status": market_risk_report.market_status.value,
                "outlier_count": market_risk_report.outlier_count,
                "excluded_listings": excluded_count
            },
            applied_rules=applied_rules,
            decisions=decisions,
            blocked_entities=blocked_entities,
            confidence_impact=None,
            price_impact=None,
            timestamp=datetime.now()
        )
        
        self.entries.append(entry)
        logger.info(f"📝 Ledger entry added: Step {self.step_counter} - Market Consistency Check")
    
    def add_core_metrics_analysis(
        self,
        metrics: Dict[str, Any]
    ) -> None:
        """Record Step 3: Core Engine Analysis"""
        self.step_counter += 1
        
        decisions = [
            f"Piyasa ortalaması: {metrics['avg_price']:,.0f} TL",
            f"Medyan fiyat: {metrics['median_price']:,.0f} TL",
            f"Standart sapma: {metrics['std_deviation']:,.0f} TL",
            f"Güven skoru: %{metrics['confidence_score']:.1f}"
        ]
        
        entry = ExplainabilityLedgerEntry(
            step_id=self.step_counter,
            step_name="Core Engine Analysis",
            input_snapshot={
                "sample_size": metrics['sample_size'],
                "median_price": metrics['median_price'],
                "confidence_score": metrics['confidence_score']
            },
            applied_rules=[],
            decisions=decisions,
            blocked_entities=[],
            confidence_impact=metrics['confidence_score'] / 100.0,
            price_impact=metrics['median_price'],
            timestamp=datetime.now()
        )
        
        self.entries.append(entry)
        logger.info(f"📝 Ledger entry added: Step {self.step_counter} - Core Engine Analysis")
    
    def add_image_analysis(
        self,
        total_images: int,
        total_findings: int,
        high_confidence_count: int
    ) -> None:
        """Record Step 4: Image Analysis (Faz-1)"""
        self.step_counter += 1
        
        decisions = [
            f"{total_images} görsel analiz edildi",
            f"{total_findings} bulgu tespit edildi",
            f"{high_confidence_count} yüksek güvenli bulgu (confidence ≥ 0.6)"
        ]
        
        entry = ExplainabilityLedgerEntry(
            step_id=self.step_counter,
            step_name="Image Analysis (Faz-1)",
            input_snapshot={
                "total_images": total_images,
                "total_findings": total_findings,
                "high_confidence_count": high_confidence_count
            },
            applied_rules=[],
            decisions=decisions,
            blocked_entities=[],
            confidence_impact=None,
            price_impact=None,
            timestamp=datetime.now()
        )
        
        self.entries.append(entry)
        logger.info(f"📝 Ledger entry added: Step {self.step_counter} - Image Analysis")
    
    def add_consistency_check(
        self,
        risk_report: RiskReport,
        blocked_parts: List[str]
    ) -> None:
        """Record Step 5: Consistency & Fraud Guard (Faz-1.2)"""
        self.step_counter += 1
        
        applied_rules = []
        decisions = []
        
        # Record blocked parts with reasons
        for part in blocked_parts:
            applied_rules.append(RuleTemplates.RULE_CON_001)
            decisions.append(
                f"{part}, yüksek güvenli çelişkili bulgular nedeniyle fiyat hesabından çıkarıldı"
            )
        
        # Record fraud risk
        if risk_report.anomaly_detected:
            applied_rules.append(RuleTemplates.RULE_CON_004)
            decisions.append(
                f"Yüksek güvenli dolandırıcılık riski tespit edildi "
                f"({risk_report.fraud_risk_level.value})"
            )
        
        # Record analysis status
        if risk_report.analysis_status.value == "limited":
            applied_rules.append(RuleTemplates.RULE_CON_005)
            decisions.append(
                "Analiz Kısıtlı Modu: %50'den fazla bulgunun güven skoru düşük"
            )
        
        decisions.append(f"Tutarlılık skoru: %{risk_report.consistency_score * 100:.0f}")
        
        entry = ExplainabilityLedgerEntry(
            step_id=self.step_counter,
            step_name="Consistency & Fraud Guard (Faz-1.2)",
            input_snapshot={
                "total_findings": len(blocked_parts) + len(risk_report.system_notes),
                "consistency_score": risk_report.consistency_score,
                "fraud_risk_level": risk_report.fraud_risk_level.value,
                "analysis_status": risk_report.analysis_status.value
            },
            applied_rules=applied_rules,
            decisions=decisions,
            blocked_entities=blocked_parts,
            confidence_impact=risk_report.consistency_score,
            price_impact=0.0,  # Blocked parts have no price impact
            timestamp=datetime.now()
        )
        
        self.entries.append(entry)
        logger.info(f"📝 Ledger entry added: Step {self.step_counter} - Consistency Check")
    
    def add_pricing_calculation(
        self,
        base_price: float,
        visual_effects: List[Dict[str, Any]],
        km_adjustment: float,
        final_price: float,
        market_status: str
    ) -> None:
        """Record Step 6: Final Pricing Calculation"""
        self.step_counter += 1
        
        applied_rules = [RuleTemplates.RULE_PRI_001, RuleTemplates.RULE_PRI_002]
        decisions = []
        blocked_entities = []
        
        # Base price
        decisions.append(f"Taban fiyat: {base_price:,.0f} TL (piyasa medyanı)")
        
        # Visual effects
        if market_status == "unstable":
            decisions.append(
                "Görsel etkiler UYGULANMADI (Piyasa stabil değil - Faz-1.3)"
            )
        elif market_status == "guarded":
            decisions.append(
                "Görsel etkiler %50 UYGULANDI (Piyasa korumalı - Faz-1.3)"
            )
            # Apply at 50%
            total_visual_effect = sum(e.get('price_delta', 0) for e in visual_effects) * 0.5
            decisions.append(
                f"Görsel ayarlar (50%): {total_visual_effect:,.0f} TL"
            )
        else:
            # Full effect
            total_visual_effect = sum(e.get('price_delta', 0) for e in visual_effects)
            decisions.append(
                f"Görsel ayarlar (100%): {total_visual_effect:,.0f} TL"
            )
        
        # KM adjustment
        if km_adjustment != 0:
            applied_rules.append(RuleTemplates.RULE_PRI_003)
            decisions.append(f"KM ayarı: {km_adjustment:,.0f} TL")
        
        # Final price
        decisions.append(f"FİNAL FİYAT: {final_price:,.0f} TL")
        
        entry = ExplainabilityLedgerEntry(
            step_id=self.step_counter,
            step_name="Final Pricing Calculation",
            input_snapshot={
                "base_price": base_price,
                "market_status": market_status,
                "visual_effects_count": len(visual_effects)
            },
            applied_rules=applied_rules,
            decisions=decisions,
            blocked_entities=blocked_entities,
            confidence_impact=None,
            price_impact=final_price - base_price,
            timestamp=datetime.now()
        )
        
        self.entries.append(entry)
        logger.info(f"📝 Ledger entry added: Step {self.step_counter} - Pricing Calculation")
    
    def finalize_ledger(
        self,
        final_price: float,
        consistency_score: float,
        fraud_risk_level: str,
        market_status: str
    ) -> ExplainabilityLedger:
        """
        Finalize ledger and compute hash
        Returns complete ExplainabilityLedger
        """
        ledger = ExplainabilityLedger(
            entries=self.entries,
            final_price=final_price,
            final_consistency_score=consistency_score,
            final_fraud_risk_level=fraud_risk_level,
            final_market_status=market_status,
            ledger_hash="",  # Will be computed
            audit_ready=True
        )
        
        # Compute hash
        ledger.ledger_hash = ledger.compute_hash()
        
        logger.info(f"✅ Ledger finalized with {len(self.entries)} entries")
        logger.info(f"🔐 Ledger hash: {ledger.ledger_hash[:16]}...")
        
        return ledger
    
    def create_error_entry(
        self,
        step_name: str,
        error_message: str
    ) -> None:
        """Create ledger entry for error/incomplete step"""
        self.step_counter += 1
        
        entry = ExplainabilityLedgerEntry(
            step_id=self.step_counter,
            step_name=step_name,
            input_snapshot={},
            applied_rules=[],
            decisions=[f"INCOMPLETE_STEP: {error_message}"],
            blocked_entities=[],
            confidence_impact=None,
            price_impact=None,
            timestamp=datetime.now()
        )
        
        self.entries.append(entry)
        logger.warning(f"⚠️ Ledger error entry added: {step_name}")