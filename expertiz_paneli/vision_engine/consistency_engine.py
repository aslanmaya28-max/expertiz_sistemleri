"""
Vision Engine - Consistency Engine (Faz-1.2)
Confidence Consistency & Fraud Guard

Detects conflicting findings, variance issues, and fraud risks
"""

import logging
from typing import List, Dict, Set, Tuple
from collections import defaultdict

from .models import (
    VisualFinding,
    FindingType,
    RiskReport,
    FraudRiskLevel,
    AnalysisStatus
)

logger = logging.getLogger(__name__)


class ConsistencyEngine:
    """
    Faz-1.2: Confidence Consistency & Fraud Guard
    
    Cross-checks visual findings for:
    1. Conflicting findings on same part
    2. High variance in confidence scores
    3. Low confidence saturation
    4. High-confidence fraud detection
    
    BLOCKS inconsistent findings from pricing
    """
    
    # Thresholds
    CONFIDENCE_VARIANCE_THRESHOLD = 0.35  # Max variance allowed
    LOW_CONFIDENCE_THRESHOLD = 0.6  # Below this = low confidence
    HIGH_CONFIDENCE_THRESHOLD = 0.75  # Above this = high confidence
    LOW_CONFIDENCE_SATURATION_LIMIT = 0.5  # Max 50% can be low confidence
    
    def analyze_findings(self, findings: List[VisualFinding]) -> Tuple[RiskReport, Set[str]]:
        """
        Analyze visual findings for consistency and fraud risks
        
        Returns:
            Tuple of (risk_report, blocked_part_names)
        """
        
        if not findings:
            logger.info("✅ No findings to analyze")
            return self._create_clean_report(), set()
        
        logger.info(f"🔍 Analyzing {len(findings)} findings for consistency...")
        
        # Initialize tracking
        blocked_parts: Set[str] = set()
        conflict_count = 0
        variance_flags = 0
        high_conf_conflicts = 0
        
        system_notes = []
        
        # Step 1: Group findings by part
        findings_by_part: Dict[str, List[VisualFinding]] = defaultdict(list)
        for finding in findings:
            findings_by_part[finding.parca_adi].append(finding)
        
        # Step 2: Check each part for conflicts
        for part_name, part_findings in findings_by_part.items():
            logger.info(f"  📋 Checking part: {part_name} ({len(part_findings)} findings)")
            
            # Rule A: Consistency Check (conflicting types)
            if self._has_conflicting_findings(part_findings):
                conflict_count += 1
                blocked_parts.add(part_name)
                system_notes.append(
                    f"⚠️ {part_name}: Çelişkili bulgular tespit edildi. Fiyat hesaplamasına dahil edilmedi."
                )
                logger.warning(f"  ❌ CONFLICT: {part_name} has conflicting findings - BLOCKED")
            
            # Rule B: Confidence Variance Check
            elif self._has_high_confidence_variance(part_findings):
                variance_flags += 1
                blocked_parts.add(part_name)
                system_notes.append(
                    f"⚠️ {part_name}: Güven skorları arasında büyük fark var. Fiyat hesaplamasına dahil edilmedi."
                )
                logger.warning(f"  ❌ VARIANCE: {part_name} has high variance - BLOCKED")
            
            # Rule C: High-Confidence Fraud Check
            elif self._has_high_confidence_conflict(part_findings):
                high_conf_conflicts += 1
                blocked_parts.add(part_name)
                system_notes.append(
                    f"🚨 {part_name}: Yüksek güvenli çelişkili bulgular! Dolandırıcılık riski yüksek."
                )
                logger.error(f"  🚨 FRAUD RISK: {part_name} has high-confidence conflicts - BLOCKED")
        
        # Step 3: Calculate low confidence ratio
        low_conf_count = sum(1 for f in findings if f.guven_skoru < self.LOW_CONFIDENCE_THRESHOLD)
        low_conf_ratio = low_conf_count / len(findings) if findings else 0
        
        # Step 4: Determine analysis status
        analysis_status = AnalysisStatus.NORMAL
        if low_conf_ratio > self.LOW_CONFIDENCE_SATURATION_LIMIT:
            analysis_status = AnalysisStatus.LIMITED
            system_notes.append(
                f"⚠️ Analiz Kısıtlı Modu: %{(low_conf_ratio * 100):.0f} bulgunun güven skoru düşük. "
                f"Fotoğraf kalitesi yetersiz olabilir."
            )
            logger.warning(f"  ⚠️ LIMITED MODE: {low_conf_ratio:.2%} low confidence findings")
        
        # Step 5: Calculate fraud risk level
        fraud_risk_level = self._calculate_fraud_risk_level(
            conflict_count, high_conf_conflicts, blocked_parts
        )
        
        # Step 6: Calculate consistency score
        consistency_score = self._calculate_consistency_score(
            conflict_count=conflict_count,
            variance_flags=variance_flags,
            low_conf_ratio=low_conf_ratio,
            total_parts=len(findings_by_part)
        )
        
        # Step 7: Determine if anomaly detected
        anomaly_detected = high_conf_conflicts > 0 or fraud_risk_level == FraudRiskLevel.HIGH
        
        # Add success note if no issues
        if not system_notes:
            system_notes.append("✅ Tüm bulgular tutarlı ve güvenilir")
        
        # Create risk report
        risk_report = RiskReport(
            consistency_score=consistency_score,
            fraud_risk_level=fraud_risk_level,
            anomaly_detected=anomaly_detected,
            analysis_status=analysis_status,
            blocked_parts=list(blocked_parts),
            system_notes=system_notes
        )
        
        logger.info(
            f"✅ Consistency analysis complete: "
            f"Score={consistency_score:.2f}, "
            f"Fraud Risk={fraud_risk_level.value}, "
            f"Blocked={len(blocked_parts)}, "
            f"Status={analysis_status.value}"
        )
        
        return risk_report, blocked_parts
    
    def _has_conflicting_findings(self, findings: List[VisualFinding]) -> bool:
        """
        Rule A: Check for conflicting finding types on same part
        
        Example: Same part marked as both "boya" and "degisen"
        """
        if len(findings) < 2:
            return False
        
        # Get all finding types
        finding_types = {f.bulgu_tipi for f in findings}
        
        # If more than 1 type for same part → conflict
        return len(finding_types) > 1
    
    def _has_high_confidence_variance(self, findings: List[VisualFinding]) -> bool:
        """
        Rule B: Check if confidence scores vary too much
        
        If max(conf) - min(conf) > 0.35 → unreliable
        """
        if len(findings) < 2:
            return False
        
        confidences = [f.guven_skoru for f in findings]
        variance = max(confidences) - min(confidences)
        
        return variance > self.CONFIDENCE_VARIANCE_THRESHOLD
    
    def _has_high_confidence_conflict(self, findings: List[VisualFinding]) -> bool:
        """
        Rule C: Check for high-confidence conflicting findings
        
        Example: Same part has "boya" (conf: 0.85) and "degisen" (conf: 0.90)
        This indicates potential fraud or manipulation
        """
        if len(findings) < 2:
            return False
        
        # Filter high-confidence findings
        high_conf_findings = [f for f in findings if f.guven_skoru >= self.HIGH_CONFIDENCE_THRESHOLD]
        
        if len(high_conf_findings) < 2:
            return False
        
        # Check if types differ
        finding_types = {f.bulgu_tipi for f in high_conf_findings}
        
        return len(finding_types) > 1
    
    def _calculate_fraud_risk_level(
        self,
        conflict_count: int,
        high_conf_conflicts: int,
        blocked_parts: Set[str]
    ) -> FraudRiskLevel:
        """Calculate overall fraud risk level"""
        
        # High confidence conflicts → HIGH risk
        if high_conf_conflicts > 0:
            return FraudRiskLevel.HIGH
        
        # Multiple blocked parts → MEDIUM risk
        if len(blocked_parts) >= 3:
            return FraudRiskLevel.MEDIUM
        
        # Some conflicts → LOW-MEDIUM risk
        if conflict_count > 0:
            return FraudRiskLevel.MEDIUM
        
        # No issues → LOW risk
        return FraudRiskLevel.LOW
    
    def _calculate_consistency_score(
        self,
        conflict_count: int,
        variance_flags: int,
        low_conf_ratio: float,
        total_parts: int
    ) -> float:
        """
        Calculate overall consistency score (0.0 - 1.0)
        
        Formula:
        score = 1.0
               - (conflict_count × 0.2)
               - (variance_flags × 0.15)
               - (low_conf_ratio × 0.3)
        """
        score = 1.0
        
        # Penalty for conflicts
        score -= min(conflict_count * 0.2, 0.4)
        
        # Penalty for variance issues
        score -= min(variance_flags * 0.15, 0.3)
        
        # Penalty for low confidence saturation
        score -= min(low_conf_ratio * 0.3, 0.3)
        
        # Ensure score is in valid range
        return max(0.0, min(score, 1.0))
    
    def _create_clean_report(self) -> RiskReport:
        """Create default clean risk report when no findings"""
        return RiskReport(
            consistency_score=1.0,
            fraud_risk_level=FraudRiskLevel.LOW,
            anomaly_detected=False,
            analysis_status=AnalysisStatus.NORMAL,
            blocked_parts=[],
            system_notes=["Görsel bulgu yok - risk analizi gerekli değil"]
        )