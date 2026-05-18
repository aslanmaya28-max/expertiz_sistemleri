# -*- coding: utf-8 -*-
"""
YERİMEBAK AI v8.0 - Hallucination Guard
Critical enforcement layer to prevent unrealistic valuations
"""

from typing import Dict, List, Any, Optional
from datetime import datetime
from dataclasses import dataclass, field

try:
    from yerimebak_ai_v5.core.engine_v8 import DealerValuation, VehicleData
except ImportError:
    from engine_v8 import DealerValuation, VehicleData


@dataclass
class GuardViolation:
    """Record of a guard rule violation"""
    timestamp: str
    rule_name: str
    original_value: Any
    corrected_value: Any
    severity: str  # INFO, WARNING, CRITICAL
    description: str


@dataclass
class GuardReport:
    """Complete guard validation report"""
    passed: bool
    violations: List[GuardViolation]
    corrected_valuation: Optional[DealerValuation]
    validation_timestamp: str


class HallucinationGuard:
    """
    Hallucination Guard v8.0
    
    Enforces 7 critical reality rules to prevent unrealistic valuations.
    
    Rules:
    1. Exit price ≤ market_price_max
    2. Margin ≤ 25%
    3. Negative profit → decision = AVOID
    4. KM > 200k → opportunity_score ≤ 65
    5. HEAVY damage → decision ≠ STRONG_BUY
    6. Risk > 50 → decision ≠ STRONG_BUY
    7. Listed > market_avg → Risk increases
    """
    
    def __init__(self, verbose: bool = True):
        self.version = "8.0-guard"
        self.verbose = verbose
        self.violations_log: List[GuardViolation] = []
        
        if self.verbose:
            print(f"\n{'='*80}")
            print(f"🛡️ HALLUCINATION GUARD v8.0 INITIALIZED")
            print(f"{'='*80}\n")
    
    def validate_valuation(self, valuation: DealerValuation, 
                          vehicle: VehicleData) -> GuardReport:
        """
        Validate valuation against all 7 reality rules
        
        Args:
            valuation: Dealer valuation to validate
            vehicle: Original vehicle data
        
        Returns:
            Guard report with violations and corrections
        """
        if self.verbose:
            print(f"\n{'='*80}")
            print(f"🛡️ HALLUCINATION GUARD - VALIDATION STARTED")
            print(f"{'='*80}\n")
        
        self.violations_log = []
        corrected_valuation = valuation
        
        # Apply all 7 rules
        corrected_valuation = self._rule_market_cap(corrected_valuation)
        corrected_valuation = self._rule_margin_cap(corrected_valuation)
        corrected_valuation = self._rule_negative_profit(corrected_valuation)
        corrected_valuation = self._rule_high_km(corrected_valuation, vehicle)
        corrected_valuation = self._rule_heavy_damage(corrected_valuation, vehicle)
        corrected_valuation = self._rule_high_risk(corrected_valuation)
        corrected_valuation = self._rule_price_position_risk(corrected_valuation, vehicle)
        
        # Build report
        report = GuardReport(
            passed=len(self.violations_log) == 0,
            violations=self.violations_log.copy(),
            corrected_valuation=corrected_valuation,
            validation_timestamp=datetime.now().isoformat()
        )
        
        if self.verbose:
            self._print_validation_report(report)
        
        return report
    
    def _rule_market_cap(self, valuation: DealerValuation) -> DealerValuation:
        """
        Rule 1: Exit price ≤ market_price_max
        
        CRITICAL: Exit price can NEVER exceed market maximum
        """
        market_max = valuation.market_valuation.market_price_max
        exit_price = valuation.exit_strategy.estimated_exit_price
        
        if exit_price > market_max:
            # Violation detected
            violation = GuardViolation(
                timestamp=datetime.now().isoformat(),
                rule_name="rule_market_cap",
                original_value=exit_price,
                corrected_value=market_max,
                severity="CRITICAL",
                description=f"Exit price ({exit_price:,.0f} TL) exceeds market max ({market_max:,.0f} TL)"
            )
            self.violations_log.append(violation)
            
            # Correct
            valuation.exit_strategy.estimated_exit_price = market_max
            
            # Recalculate profit and margin
            total_cost = valuation.commercial_analysis.estimated_total_cost
            new_profit = market_max - total_cost
            new_margin = (new_profit / total_cost) * 100
            
            valuation.commercial_analysis.net_profit_tl = new_profit
            valuation.commercial_analysis.net_margin_percent = min(25.0, new_margin)
            
            if self.verbose:
                print(f"❌ RULE 1 VIOLATION: Exit price capped at market max")
        
        return valuation
    
    def _rule_margin_cap(self, valuation: DealerValuation) -> DealerValuation:
        """
        Rule 2: Margin ≤ 25%
        
        CRITICAL: Profit margin can NEVER exceed 25%
        """
        margin = valuation.commercial_analysis.net_margin_percent
        
        if margin > 25.0:
            # Violation detected
            violation = GuardViolation(
                timestamp=datetime.now().isoformat(),
                rule_name="rule_margin_cap",
                original_value=margin,
                corrected_value=25.0,
                severity="CRITICAL",
                description=f"Margin ({margin:.1f}%) exceeds 25% limit"
            )
            self.violations_log.append(violation)
            
            # Correct
            valuation.commercial_analysis.net_margin_percent = 25.0
            
            # Recalculate profit with capped margin
            total_cost = valuation.commercial_analysis.estimated_total_cost
            new_profit = total_cost * 0.25
            valuation.commercial_analysis.net_profit_tl = new_profit
            
            if self.verbose:
                print(f"❌ RULE 2 VIOLATION: Margin capped at 25%")
        
        return valuation
    
    def _rule_negative_profit(self, valuation: DealerValuation) -> DealerValuation:
        """
        Rule 3: Negative profit → decision = AVOID
        
        CRITICAL: If profit is negative, decision must be AVOID
        """
        profit = valuation.commercial_analysis.net_profit_tl
        decision = valuation.dealer_verdict.decision
        
        if profit < 0 and decision != "AVOID":
            # Violation detected
            violation = GuardViolation(
                timestamp=datetime.now().isoformat(),
                rule_name="rule_negative_profit",
                original_value=decision,
                corrected_value="AVOID",
                severity="CRITICAL",
                description=f"Profit is negative ({profit:,.0f} TL) but decision is {decision}"
            )
            self.violations_log.append(violation)
            
            # Correct
            valuation.dealer_verdict.decision = "AVOID"
            valuation.dealer_verdict.action_note = f"Negatif kar ({profit:,.0f} TL). Bu araçtan kaçının."
            
            if self.verbose:
                print(f"❌ RULE 3 VIOLATION: Decision forced to AVOID (negative profit)")
        
        return valuation
    
    def _rule_high_km(self, valuation: DealerValuation, vehicle: VehicleData) -> DealerValuation:
        """
        Rule 4: KM > 200k → opportunity_score ≤ 65
        
        CRITICAL: High KM vehicles have limited opportunity
        """
        if vehicle.mileage_km > 200000:
            opportunity = valuation.technical_scoring.opportunity_score
            
            if opportunity > 65:
                # Violation detected
                violation = GuardViolation(
                    timestamp=datetime.now().isoformat(),
                    rule_name="rule_high_km",
                    original_value=opportunity,
                    corrected_value=65,
                    severity="WARNING",
                    description=f"KM > 200k ({vehicle.mileage_km:,}) but opportunity score ({opportunity}) exceeds 65"
                )
                self.violations_log.append(violation)
                
                # Correct
                valuation.technical_scoring.opportunity_score = 65
                
                if self.verbose:
                    print(f"❌ RULE 4 VIOLATION: Opportunity score capped at 65 (high KM)")
        
        return valuation
    
    def _rule_heavy_damage(self, valuation: DealerValuation, vehicle: VehicleData) -> DealerValuation:
        """
        Rule 5: HEAVY damage → decision ≠ STRONG_BUY
        
        CRITICAL: Heavy damage vehicles cannot be STRONG_BUY
        """
        if vehicle.damage_level.upper() == "HEAVY":
            decision = valuation.dealer_verdict.decision
            
            if decision == "STRONG_BUY":
                # Violation detected
                violation = GuardViolation(
                    timestamp=datetime.now().isoformat(),
                    rule_name="rule_heavy_damage",
                    original_value=decision,
                    corrected_value="BUY",
                    severity="WARNING",
                    description=f"Heavy damage but decision is STRONG_BUY"
                )
                self.violations_log.append(violation)
                
                # Correct
                valuation.dealer_verdict.decision = "BUY"
                valuation.dealer_verdict.action_note += " Ağır hasar nedeniyle 'STRONG_BUY' değil 'BUY'."
                
                if self.verbose:
                    print(f"❌ RULE 5 VIOLATION: Decision downgraded to BUY (heavy damage)")
        
        return valuation
    
    def _rule_high_risk(self, valuation: DealerValuation) -> DealerValuation:
        """
        Rule 6: Risk > 50 → decision ≠ STRONG_BUY
        
        CRITICAL: High risk vehicles cannot be STRONG_BUY
        """
        risk = valuation.technical_scoring.risk_percentage
        decision = valuation.dealer_verdict.decision
        
        if risk > 50 and decision == "STRONG_BUY":
            # Violation detected
            violation = GuardViolation(
                timestamp=datetime.now().isoformat(),
                rule_name="rule_high_risk",
                original_value=decision,
                corrected_value="BUY",
                severity="WARNING",
                description=f"Risk > 50% ({risk:.1f}%) but decision is STRONG_BUY"
            )
            self.violations_log.append(violation)
            
            # Correct
            valuation.dealer_verdict.decision = "BUY"
            valuation.dealer_verdict.action_note += f" Risk > 50%% ({risk:.1f}%%) nedeniyle 'STRONG_BUY' değil 'BUY'."
            
            if self.verbose:
                print(f"❌ RULE 6 VIOLATION: Decision downgraded to BUY (high risk)")
        
        return valuation
    
    def _rule_price_position_risk(self, valuation: DealerValuation, vehicle: VehicleData) -> DealerValuation:
        """
        Rule 7: Listed > market_avg → Risk increases
        
        WARNING: If listed price is above market average, risk must be increased
        """
        listed_price = vehicle.listed_price
        market_avg = vehicle.market_price_avg
        
        if listed_price > market_avg:
            # Calculate how much over
            over_percentage = ((listed_price - market_avg) / market_avg) * 100
            
            # Current risk
            current_risk = valuation.technical_scoring.risk_percentage
            
            # Required risk increase
            if over_percentage > 10:
                risk_increase = 15
            elif over_percentage > 5:
                risk_increase = 10
            else:
                risk_increase = 5
            
            new_risk = min(100, current_risk + risk_increase)
            
            if new_risk > current_risk:
                # Violation detected
                violation = GuardViolation(
                    timestamp=datetime.now().isoformat(),
                    rule_name="rule_price_position_risk",
                    original_value=current_risk,
                    corrected_value=new_risk,
                    severity="WARNING",
                    description=f"Listed price ({listed_price:,.0f} TL) above market avg ({market_avg:,.0f} TL) by {over_percentage:.1f}%"
                )
                self.violations_log.append(violation)
                
                # Correct
                valuation.technical_scoring.risk_percentage = new_risk
                
                # Recalculate opportunity score with increased risk
                profit_score = min(100, valuation.commercial_analysis.net_margin_percent * 4)
                liquidity_score = valuation.liquidity_metrics.liquidity_score
                new_opportunity = max(0, min(100, profit_score + liquidity_score - new_risk))
                valuation.technical_scoring.opportunity_score = int(new_opportunity)
                
                if self.verbose:
                    print(f"❌ RULE 7 VIOLATION: Risk increased by {risk_increase}% (overpriced)")
        
        return valuation
    
    def _print_validation_report(self, report: GuardReport):
        """Print validation report"""
        print(f"\n{'='*80}")
        print(f"🛡️ HALLUCINATION GUARD - VALIDATION REPORT")
        print(f"{'='*80}\n")
        
        if report.passed:
            print(f"✅ VALIDATION PASSED")
            print(f"   No violations detected\n")
        else:
            print(f"❌ VALIDATION FAILED")
            print(f"   {len(report.violations)} violation(s) detected\n")
            
            print(f"📋 VIOLATIONS:")
            for i, violation in enumerate(report.violations, 1):
                print(f"\n   {i}. {violation.rule_name.upper()} [{violation.severity}]")
                print(f"      Description: {violation.description}")
                print(f"      Original: {violation.original_value}")
                print(f"      Corrected: {violation.corrected_value}")
            
            print(f"\n{'='*80}\n")


# Singleton instance
_guard = None


def get_hallucination_guard(verbose: bool = True) -> HallucinationGuard:
    """Get or create Hallucination Guard instance"""
    global _guard
    if _guard is None:
        _guard = HallucinationGuard(verbose=verbose)
    return _guard


if __name__ == "__main__":
    # Test guard with sample valuations
    try:
        from yerimebak_ai_v5.core.engine_v8 import YerimebakEngineV8, VehicleData
    except ImportError:
        from engine_v8 import YerimebakEngineV8, VehicleData
    
    print("\n" + "="*80)
    print("HALLUCINATION GUARD v8.0 - TEST RUN")
    print("="*80)
    
    engine = YerimebakEngineV8(verbose=False)
    guard = HallucinationGuard(verbose=True)
    
    # Test 1: Normal valuation (should pass)
    print("\n" + "="*80)
    print("TEST 1: Normal Valuation (Should Pass)")
    print("="*80)
    
    vehicle1 = VehicleData(
        make_model="Volkswagen Passat",
        year=2020,
        mileage_km=95000,
        fuel_type="dizel",
        gear_type="otomatik",
        listed_price=420000,
        market_price_avg=470000,
        damage_level="LIGHT",
        bodywork_status=["sol_on_kapi"],
        demand_level="MEDIUM",
        seasonality="NORMAL"
    )
    
    valuation1 = engine.analyze(vehicle1)
    report1 = guard.validate_valuation(valuation1, vehicle1)
    
    # Test 2: Overpriced vehicle (should trigger Rule 7)
    print("\n" + "="*80)
    print("TEST 2: Overpriced Vehicle (Should Trigger Rule 7)")
    print("="*80)
    
    vehicle2 = VehicleData(
        make_model="BMW 3 Series",
        year=2020,
        mileage_km=80000,
        fuel_type="benzin",
        gear_type="otomatik",
        listed_price=850000,
        market_price_avg=750000,
        damage_level="NONE",
        bodywork_status=[],
        demand_level="HIGH",
        seasonality="NORMAL"
    )
    
    valuation2 = engine.analyze(vehicle2)
    report2 = guard.validate_valuation(valuation2, vehicle2)
    
    # Test 3: High KM (should trigger Rule 4)
    print("\n" + "="*80)
    print("TEST 3: High KM Vehicle (Should Trigger Rule 4)")
    print("="*80)
    
    vehicle3 = VehicleData(
        make_model="Renault Clio",
        year=2017,
        mileage_km=250000,
        fuel_type="dizel",
        gear_type="manuel",
        listed_price=280000,
        market_price_avg=320000,
        damage_level="NONE",
        bodywork_status=[],
        demand_level="LOW",
        seasonality="NORMAL"
    )
    
    valuation3 = engine.analyze(vehicle3)
    report3 = guard.validate_valuation(valuation3, vehicle3)
    
    print("\n" + "="*80)
    print("✅ ALL GUARD TESTS COMPLETED")
    print("="*80)
