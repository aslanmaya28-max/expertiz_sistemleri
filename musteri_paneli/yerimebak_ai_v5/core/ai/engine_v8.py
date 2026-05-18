# -*- coding: utf-8 -*-
"""
YERİMEBAK AI v8.0 - Final Dealer Master Engine
Professional car dealer intelligence system with 20 years of experience encoded
"""

from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any
from datetime import datetime
from enum import Enum


class DamageLevel(Enum):
    """Damage severity levels"""
    NONE = "NONE"
    LIGHT = "LIGHT"
    MEDIUM = "MEDIUM"
    HEAVY = "HEAVY"


class DemandLevel(Enum):
    """Market demand levels"""
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


class Seasonality(Enum):
    """Seasonality levels"""
    HIGH = "HIGH"
    NORMAL = "NORMAL"
    LOW = "LOW"


class Decision(Enum):
    """Final dealer decision"""
    AVOID = "AVOID"
    HOLD = "HOLD"
    NEGOTIATE = "NEGOTIATE"
    BUY = "BUY"
    STRONG_BUY = "STRONG_BUY"


@dataclass
class VehicleData:
    """Vehicle input data model"""
    make_model: str
    year: int
    mileage_km: int
    fuel_type: str
    gear_type: str
    listed_price: float
    market_price_avg: float
    damage_level: str
    bodywork_status: List[str] = field(default_factory=list)
    demand_level: str = "MEDIUM"
    seasonality: str = "NORMAL"
    package_level: str = "BASE"


@dataclass
class MarketValuation:
    """Market analysis results"""
    market_price_min: float
    market_price_avg: float
    market_price_max: float
    price_position_index: float


@dataclass
class ExitStrategy:
    """Exit price strategy"""
    estimated_exit_price: float


@dataclass
class CommercialAnalysis:
    """Commercial analysis results"""
    estimated_total_cost: float
    net_profit_tl: float
    net_margin_percent: float
    optimal_purchase_price: float
    maximum_purchase_price: float


@dataclass
class LiquidityMetrics:
    """Liquidity analysis"""
    liquidity_score: int
    estimated_days_to_sell: int


@dataclass
class TechnicalScoring:
    """Technical scoring"""
    opportunity_score: int
    risk_percentage: float


@dataclass
class DealerVerdict:
    """Final dealer verdict"""
    decision: str
    action_note: str


@dataclass
class DealerValuation:
    """Complete dealer valuation output"""
    analysis_meta: Dict[str, Any]
    market_valuation: MarketValuation
    exit_strategy: ExitStrategy
    commercial_analysis: CommercialAnalysis
    liquidity_metrics: LiquidityMetrics
    technical_scoring: TechnicalScoring
    dealer_verdict: DealerVerdict
    technical_summary: str


class YerimebakEngineV8:
    """
    YERİMEBAK AI v8.0 - Final Dealer Master Engine
    
    Role: 20 years experienced professional car dealer
    Principle: NEVER guess, ONLY realistic risk-adjusted commercial analysis
    Priority: Protect capital, avoid risk, calculate realistic profit
    Behavior: NEVER optimistic, ALWAYS conservative
    """
    
    def __init__(self, verbose: bool = True):
        self.version = "8.0-final"
        self.verbose = verbose
        
        if self.verbose:
            print(f"\n{'='*80}")
            print(f"🏛️ YERİMEBAK AI v8.0 - FINAL DEALER MASTER ENGINE")
            print(f"{'='*80}\n")
    
    def analyze(self, vehicle: VehicleData) -> DealerValuation:
        """
        Run complete dealer analysis
        
        Args:
            vehicle: Vehicle input data
        
        Returns:
            Complete dealer valuation
        """
        # Fallback to listed price if market data is completely missing
        # to avoid severe negative profit calculations due to zero-exit-price.
        if vehicle.market_price_avg <= 0:
            vehicle.market_price_avg = vehicle.listed_price

        if self.verbose:
            print(f"📊 Analyzing: {vehicle.make_model} {vehicle.year}")
            print(f"   KM: {vehicle.mileage_km:,}")
            print(f"   Listed Price: {vehicle.listed_price:,.0f} TL")
            print(f"   Market Avg: {vehicle.market_price_avg:,.0f} TL")
            print(f"   Damage: {vehicle.damage_level}")
        
        # Step 1: Market Analysis
        market = self._analyze_market(vehicle)
        
        # Step 2: Exit Price
        exit_strategy = self._calculate_exit_price(vehicle, market)
        
        # Step 3: Liquidity
        liquidity = self._calculate_liquidity(vehicle, market)
        
        # Step 4: Expense
        expense = self._calculate_expense(vehicle, liquidity)
        
        # Step 5: Total Cost
        total_cost = self._calculate_total_cost(vehicle, expense)
        
        # Step 6: Profit
        profit = self._calculate_profit(exit_strategy.estimated_exit_price, total_cost)
        
        # Step 7: Negotiation
        negotiation = self._calculate_negotiation(
            exit_strategy.estimated_exit_price,
            profit,
            expense,
            vehicle.listed_price
        )
        
        # Step 8: Risk
        risk = self._calculate_risk(vehicle, liquidity, market)
        
        # Step 9: Opportunity
        opportunity = self._calculate_opportunity(profit, liquidity, risk)
        
        # Step 10: Decision
        decision = self._make_decision(profit, risk, opportunity, vehicle)
        
        fixed_expenses = expense['expertise'] + expense['prep'] + expense['listing'] + expense['finance']
        max_purchase_price = exit_strategy.estimated_exit_price - fixed_expenses

        commercial = CommercialAnalysis(
            estimated_total_cost=total_cost,
            net_profit_tl=profit['net'],
            net_margin_percent=profit['margin'],
            optimal_purchase_price=negotiation['optimal'],
            maximum_purchase_price=max(0, max_purchase_price)
        )
        
        # Build technical scoring
        technical = TechnicalScoring(
            opportunity_score=opportunity,
            risk_percentage=risk
        )
        
        # Build dealer verdict
        verdict = DealerVerdict(
            decision=decision['action'],
            action_note=decision['note']
        )
        
        # Generate summary
        summary = self._generate_summary(
            vehicle, market, exit_strategy, commercial, liquidity, technical, verdict
        )
        
        # Build complete valuation
        valuation = DealerValuation(
            analysis_meta={
                "version": self.version,
                "confidence_score": self._calculate_confidence(vehicle, risk),
                "timestamp": datetime.now().isoformat()
            },
            market_valuation=market,
            exit_strategy=exit_strategy,
            commercial_analysis=commercial,
            liquidity_metrics=liquidity,
            technical_scoring=technical,
            dealer_verdict=verdict,
            technical_summary=summary
        )
        
        if self.verbose:
            self._print_results(valuation)
        
        return valuation
    
    def _analyze_market(self, vehicle: VehicleData) -> MarketValuation:
        """
        Step 1: Market Analysis
        
        Calculate market positioning
        """
        market_price_min = vehicle.market_price_avg * 0.92
        market_price_max = vehicle.market_price_avg * 1.08
        
        # Prevent ZeroDivisionError
        m_avg = vehicle.market_price_avg if vehicle.market_price_avg > 0 else vehicle.listed_price
        if m_avg <= 0: m_avg = 1.0 # Absolute fallback
        
        price_position_index = ((m_avg - vehicle.listed_price) / m_avg) * 100
        
        return MarketValuation(
            market_price_min=market_price_min,
            market_price_avg=vehicle.market_price_avg,
            market_price_max=market_price_max,
            price_position_index=price_position_index
        )
    
    def _calculate_exit_price(self, vehicle: VehicleData, market: MarketValuation) -> ExitStrategy:
        base_multiplier = 1.0

        if market.price_position_index > 5:
            base_multiplier = 1.02
        elif market.price_position_index < -5:
            base_multiplier = 0.95
        else:
            base_multiplier = 0.98

        package_bonus = {"FULL": 0.03, "HIGH": 0.02, "MID": 0.01}.get(
            (vehicle.package_level or "BASE").upper(), 0.0
        )
        base_multiplier += package_bonus

        fuel_bonus = {"hibrit": 0.02, "benzin+lpg": 0.01, "lpg": 0.01}.get(
            (vehicle.fuel_type or "").lower().replace(" ", ""), 0.0
        )
        base_multiplier += fuel_bonus

        gear_penalty = -0.02 if (vehicle.gear_type or "").lower() in ("manuel", "manual") else 0.0
        base_multiplier += gear_penalty

        estimated_exit_price = vehicle.market_price_avg * base_multiplier

        if estimated_exit_price > market.market_price_max:
            estimated_exit_price = market.market_price_max

        return ExitStrategy(estimated_exit_price=estimated_exit_price)
    
    def _calculate_liquidity(self, vehicle: VehicleData, market: MarketValuation) -> LiquidityMetrics:
        demand = (vehicle.demand_level or "MEDIUM").upper()
        if demand == "HIGH":
            base_score = 80
        elif demand == "MEDIUM":
            base_score = 60
        else:
            base_score = 40

        penalties = 0

        if vehicle.mileage_km > 200000:
            penalties += 20
        elif vehicle.mileage_km > 150000:
            penalties += 10
        elif vehicle.mileage_km > 100000:
            penalties += 5

        damage = (vehicle.damage_level or "NONE").upper()
        if damage == "HEAVY":
            penalties += 25
        elif damage == "MEDIUM":
            penalties += 15
        elif damage == "LIGHT":
            penalties += 5

        if vehicle.listed_price > vehicle.market_price_avg:
            price_diff = abs(market.price_position_index)
            if price_diff > 10:
                penalties += 25
            elif price_diff > 5:
                penalties += 15
            else:
                penalties += 5

        bonuses = 0
        pkg = (vehicle.package_level or "BASE").upper()
        if pkg == "FULL":
            bonuses += 10
        elif pkg == "HIGH":
            bonuses += 7
        elif pkg == "MID":
            bonuses += 4

        gear = (vehicle.gear_type or "").lower()
        if gear in ("otomatik", "automatic"):
            bonuses += 5
        elif gear in ("manuel", "manual"):
            penalties += 5

        fuel = (vehicle.fuel_type or "").lower()
        if fuel in ("dizel", "diesel"):
            bonuses += 3
        elif fuel in ("hibrit", "hybrid"):
            bonuses += 5

        liquidity_score = base_score - penalties + bonuses
        liquidity_score = max(0, min(100, liquidity_score))

        estimated_days_to_sell = max(5, 100 - liquidity_score)

        return LiquidityMetrics(
            liquidity_score=int(liquidity_score),
            estimated_days_to_sell=int(estimated_days_to_sell)
        )
    
    def _calculate_expense(self, vehicle: VehicleData, liquidity: LiquidityMetrics) -> Dict[str, float]:
        """
        Step 4: Expense
        
        Calculate all ownership costs
        """
        expertise_cost = 2000.0
        prep_cost = vehicle.listed_price * 0.01
        listing_cost = 2000.0
        
        # Finance cost (daily rate × days)
        daily_finance_rate = 0.0015
        finance_cost = vehicle.listed_price * daily_finance_rate * liquidity.estimated_days_to_sell
        
        return {
            'expertise': expertise_cost,
            'prep': prep_cost,
            'listing': listing_cost,
            'finance': finance_cost
        }
    
    def _calculate_total_cost(self, vehicle: VehicleData, expense: Dict[str, float]) -> float:
        """
        Step 5: Total Cost
        
        Calculate total ownership cost
        """
        return (
            vehicle.listed_price +
            expense['expertise'] +
            expense['prep'] +
            expense['listing'] +
            expense['finance']
        )
    
    def _calculate_profit(self, exit_price: float, total_cost: float) -> Dict[str, float]:
        """
        Step 6: Profit
        
        Calculate net profit and margin
        
        LIMIT: Max 25%
        """
        net_profit_tl = exit_price - total_cost
        net_margin_percent = (net_profit_tl / total_cost) * 100
        
        # CRITICAL RULE: Margin never exceeds 25%
        if net_margin_percent > 25:
            net_margin_percent = 25.0
            # Recalculate profit with capped margin
            net_profit_tl = total_cost * 0.25
        
        return {
            'net': net_profit_tl,
            'margin': net_margin_percent
        }
    
    def _calculate_negotiation(self, exit_price: float, profit: Dict[str, float],
                               expense: Dict[str, float], listed_price: float) -> Dict[str, float]:
        """
        Step 7: Negotiation
        
        Calculate optimal and maximum purchase prices
        """
        # Target profit: 12% of exit price
        target_profit = exit_price * 0.12
        
        # Optimal purchase price (ideal)
        fixed_costs = expense['expertise'] + expense['prep'] + expense['listing']
        calculated_optimal = exit_price - target_profit - fixed_costs
        
        # KRİTİK DÜZELTME: Optimum fiyat, listed fiyatının %95'ini geçemez
        # Eğer hesaplanan optimum, listed fiyatından yüksekse, listed fiyatının %95'ini kullan
        max_optimal_from_listed = listed_price * 0.95
        optimal_purchase_price = min(calculated_optimal, max_optimal_from_listed)
        
        # Maximum purchase price (breakeven)
        # This is calculated when we create the complete valuation
        # For now, return optimal
        return {
            'optimal': max(0, optimal_purchase_price),
            'maximum': 0  # Will be set in analyze()
        }
    
    def _calculate_risk(self, vehicle: VehicleData, liquidity: LiquidityMetrics, 
                        market: MarketValuation) -> float:
        """
        Step 8: Risk
        
        Calculate investment risk percentage
        
        Component weights:
        - KM: 35%
        - Damage: 30%
        - Liquidity: 20%
        - Price Position: 15%
        """
        # KM score (0-100, higher = worse)
        if vehicle.mileage_km < 50000:
            km_score = 5
        elif vehicle.mileage_km < 100000:
            km_score = 20
        elif vehicle.mileage_km < 150000:
            km_score = 40
        elif vehicle.mileage_km < 200000:
            km_score = 70
        else:
            km_score = 95
        
        # Damage score
        damage = vehicle.damage_level.upper()
        if damage == "NONE":
            damage_score = 0
        elif damage == "LIGHT":
            damage_score = 20
        elif damage == "MEDIUM":
            damage_score = 50
        else:  # HEAVY
            damage_score = 90
        
        # Liquidity risk (invert: higher liquidity = lower risk)
        liquidity_risk = 100 - liquidity.liquidity_score
        
        # Price score (higher price = higher risk)
        if market.price_position_index > 10:
            price_score = 10  # Good price
        elif market.price_position_index > 0:
            price_score = 30
        elif market.price_position_index > -10:
            price_score = 50
        else:
            price_score = 80  # Overpriced
        
        # Technical risk components
        body_risk = 0
        if vehicle.bodywork_status:
            for part in vehicle.bodywork_status:
                part_l = part.lower()
                if any(x in part_l for x in ['tavan', 'direk', 'şase', 'sase', 'podye', 'roof', 'pillar', 'chassis']):
                    body_risk += 30 # Major
                elif any(x in part_l for x in ['kaput', 'bagaj', 'hood', 'trunk']):
                    body_risk += 15 # Medium
                else:
                    body_risk += 5  # Minor (kapı, çamurluk vb.)
        
        risk_bonus = 0.0
        pkg = (vehicle.package_level or "BASE").upper()
        if pkg == "FULL":
            risk_bonus -= 5.0
        elif pkg == "HIGH":
            risk_bonus -= 3.0
        elif pkg == "MID":
            risk_bonus -= 1.5

        gear = (vehicle.gear_type or "").lower()
        if gear in ("manuel", "manual"):
            risk_bonus += 3.0

        weighted_risk = (
            km_score * 0.35 +
            damage_score * 0.25 +
            liquidity_risk * 0.15 +
            price_score * 0.10 +
            min(40, body_risk) * 0.15
        )

        risk_percentage = max(0, weighted_risk + risk_bonus)

        return risk_percentage
    
    def _calculate_opportunity(self, profit: Dict[str, float], 
                               liquidity: LiquidityMetrics, risk: float) -> int:
        """
        Step 9: Opportunity
        
        Calculate opportunity score (0-100)
        
        Increases with: profit, liquidity
        Decreases with: risk
        """
        # Normalize profit to 0-100
        profit_score = min(100, max(0, profit['margin'] * 4))
        
        # Opportunity score
        opportunity_score = profit_score + liquidity.liquidity_score - risk
        
        # KRİTİK KURAL (v8.0): Negatif kâr varsa fırsat skoru 0'dır!
        if profit['net'] < 0:
            opportunity_score = 0
            
        opportunity_score = max(0, min(100, opportunity_score))
        
        return int(opportunity_score)
    
    def _make_decision(self, profit: Dict[str, float], risk: float,
                       opportunity: int, vehicle: VehicleData) -> Dict[str, str]:
        margin = profit['margin']
        net_profit = profit['net']
        risk_pct = risk

        decision = "HOLD"
        note = ""

        if net_profit < 0:
            decision = "AVOID"
            note = "Negatif kar. Bu araçtan kaçının."
        elif risk_pct > 70:
            decision = "AVOID"
            note = "Risk çok yüksek (%.1f%%). Bu araçtan kaçın." % risk_pct
        elif margin < 3:
            if risk_pct >= 50:
                decision = "AVOID"
                note = "Kar marjı çok düşük (%%%1.f) ve risk yüksek. Kaçının." % margin
            else:
                decision = "HOLD"
                note = "Kar marjı çok düşük (%%%.1f). Dikkatli olun." % margin
        elif margin < 6:
            if risk_pct < 40:
                decision = "NEGOTIATE"
                note = "Kar marjı düşük (%%%.1f) ama risk uygun. Müzakere ile alınabilir." % margin
            else:
                decision = "HOLD"
                note = "Kar marjı düşük ve risk orta/yüksek. Bekleyin."
        elif margin < 10:
            if risk_pct < 45:
                decision = "NEGOTIATE"
                note = "İyi fırsat (%%%.1f marj). Müzakere ile alınabilir." % margin
            else:
                decision = "HOLD"
                note = "Kar potansiyeli var ama risk yüksek. Bekleyin."
        elif margin < 16:
            if risk_pct < 50:
                decision = "BUY"
                note = "İyi fırsat (%%%.1f marj). Alın." % margin
            else:
                decision = "NEGOTIATE"
                note = "Kar potansiyeli iyi (%%%.1f) ama risk orta. Müzakere edin." % margin
        else:
            if risk_pct < 35:
                decision = "STRONG_BUY"
                note = "Mükemmel fırsat (%%%.1f marj). Şimdi alın." % margin
            elif risk_pct < 50:
                decision = "BUY"
                note = "Çok iyi fırsat (%%%.1f marj). Alın." % margin
            else:
                decision = "NEGOTIATE"
                note = "Yüksek kar potansiyeli (%%%.1f) ama risk yüksek. Müzakere edin." % margin

        if vehicle.mileage_km > 200000:
            if decision == "STRONG_BUY":
                decision = "BUY"
                note += " Yüksek KM nedeniyle 'STRONG_BUY' değil 'BUY'."

        if vehicle.damage_level.upper() == "HEAVY":
            if decision == "STRONG_BUY":
                decision = "BUY"
                note += " Ağır hasar nedeniyle 'STRONG_BUY' değil 'BUY'."

        if risk_pct > 50:
            if decision == "STRONG_BUY":
                decision = "BUY"
                note += " Risk > 50%% nedeniyle 'STRONG_BUY' değil 'BUY'."

        return {
            'action': decision,
            'note': note.strip()
        }
    
    def _calculate_confidence(self, vehicle: VehicleData, risk: float) -> int:
        """
        Calculate confidence score (0-100)
        """
        base_confidence = 75
        
        # Reduce confidence based on risk
        if risk > 70:
            base_confidence -= 25
        elif risk > 50:
            base_confidence -= 15
        elif risk > 30:
            base_confidence -= 5
        
        # Reduce confidence for high KM
        if vehicle.mileage_km > 200000:
            base_confidence -= 10
        elif vehicle.mileage_km > 150000:
            base_confidence -= 5
        
        return max(0, min(100, base_confidence))
    
    def _generate_summary(self, vehicle: VehicleData, market: MarketValuation,
                         exit_strategy: ExitStrategy, commercial: CommercialAnalysis,
                         liquidity: LiquidityMetrics, technical: TechnicalScoring,
                         verdict: DealerVerdict) -> str:
        """
        Generate technical summary
        """
        parts = []
        
        # Price positioning
        if market.price_position_index > 5:
            parts.append(f"Araç piyasa ortalamasının %{market.price_position_index:.1f} altında fiyatlanmış (iyi fırsat).")
        elif market.price_position_index < -5:
            parts.append(f"Araç piyasa ortalamasının %{abs(market.price_position_index):.1f} üzerinde fiyatlanmış (pahalı).")
        else:
            parts.append("Araç piyasa ortalamasında fiyatlanmış.")
        
        # KM assessment
        if vehicle.mileage_km < 50000:
            parts.append("KM çok düşük.")
        elif vehicle.mileage_km < 100000:
            parts.append("KM normal.")
        elif vehicle.mileage_km < 150000:
            parts.append("KM yüksek.")
        elif vehicle.mileage_km < 200000:
            parts.append("KM çok yüksek.")
        else:
            parts.append("KM aşırı yüksek (riskli).")
        
        # Damage assessment
        damage = vehicle.damage_level.upper()
        if damage == "NONE":
            parts.append("Hasar yok.")
        elif damage == "LIGHT":
            parts.append("Hafif hasar var.")
        elif damage == "MEDIUM":
            parts.append("Orta hasar var.")
        else:
            parts.append("Ağır hasar var (ciddi risk).")
        
        # Liquidity
        if liquidity.liquidity_score >= 70:
            parts.append("Likidite yüksek.")
        elif liquidity.liquidity_score >= 50:
            parts.append("Likidite orta seviyede.")
        else:
            parts.append("Likidite düşük (uzun satış süresi).")
        
        # Profit
        if commercial.net_margin_percent < 5:
            parts.append(f"Kar marjı çok düşük (%{commercial.net_margin_percent:.1f}).")
        elif commercial.net_margin_percent < 10:
            parts.append(f"Kar marjı düşük (%{commercial.net_margin_percent:.1f}).")
        elif commercial.net_margin_percent < 15:
            parts.append(f"Kar marjı orta (%{commercial.net_margin_percent:.1f}).")
        else:
            parts.append(f"Kar marjı iyi (%{commercial.net_margin_percent:.1f}).")
        
        # Risk
        if technical.risk_percentage < 30:
            parts.append("Risk düşük.")
        elif technical.risk_percentage < 50:
            parts.append("Risk orta seviyede.")
        elif technical.risk_percentage < 70:
            parts.append("Risk yüksek.")
        else:
            parts.append("Risk çok yüksek.")
        
        # Decision
        parts.append(f"Galericinin kararı: {verdict.decision}")
        
        return " ".join(parts)
    
    def _print_results(self, valuation: DealerValuation):
        """Print valuation results"""
        print(f"\n{'='*80}")
        print(f"📊 DEALER VALUATION RESULTS")
        print(f"{'='*80}\n")
        
        print(f"🏷️  MARKET VALUATION:")
        print(f"   Min: {valuation.market_valuation.market_price_min:,.0f} TL")
        print(f"   Avg: {valuation.market_valuation.market_price_avg:,.0f} TL")
        print(f"   Max: {valuation.market_valuation.market_price_max:,.0f} TL")
        print(f"   Position: %{valuation.market_valuation.price_position_index:.1f}\n")
        
        print(f"💰 EXIT STRATEGY:")
        print(f"   Estimated Exit Price: {valuation.exit_strategy.estimated_exit_price:,.0f} TL\n")
        
        print(f"💵 COMMERCIAL ANALYSIS:")
        print(f"   Total Cost: {valuation.commercial_analysis.estimated_total_cost:,.0f} TL")
        print(f"   Net Profit: {valuation.commercial_analysis.net_profit_tl:,.0f} TL")
        print(f"   Net Margin: %{valuation.commercial_analysis.net_margin_percent:.1f}")
        print(f"   Optimal Purchase: {valuation.commercial_analysis.optimal_purchase_price:,.0f} TL")
        print(f"   Maximum Purchase: {valuation.commercial_analysis.maximum_purchase_price:,.0f} TL\n")
        
        print(f"⏱️  LIQUIDITY:")
        print(f"   Score: {valuation.liquidity_metrics.liquidity_score}/100")
        print(f"   Days to Sell: {valuation.liquidity_metrics.estimated_days_to_sell} days\n")
        
        print(f"📈 TECHNICAL SCORING:")
        print(f"   Opportunity: {valuation.technical_scoring.opportunity_score}/100")
        print(f"   Risk: %{valuation.technical_scoring.risk_percentage:.1f}\n")
        
        print(f"🎯 DEALER VERDICT:")
        print(f"   Decision: {valuation.dealer_verdict.decision}")
        print(f"   Note: {valuation.dealer_verdict.action_note}\n")
        
        print(f"📝 SUMMARY:")
        print(f"   {valuation.technical_summary}\n")
        
        print(f"{'='*80}\n")


# Singleton instance
_engine_v8 = None


def get_engine_v8(verbose: bool = True) -> YerimebakEngineV8:
    """Get or create Engine v8 instance"""
    global _engine_v8
    if _engine_v8 is None:
        _engine_v8 = YerimebakEngineV8(verbose=verbose)
    return _engine_v8


if __name__ == "__main__":
    # Test engine with sample vehicle
    print("\n" + "="*80)
    print("YERİMEBAK AI v8.0 - TEST RUN")
    print("="*80)
    
    engine = YerimebakEngineV8(verbose=True)
    
    # Test vehicle 1: Good opportunity
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
    
    print("\n" + "="*80)
    print("TEST 1: Good Opportunity")
    print("="*80)
    result1 = engine.analyze(vehicle1)
    
    # Test vehicle 2: High KM
    vehicle2 = VehicleData(
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
    
    print("\n" + "="*80)
    print("TEST 2: High KM Vehicle")
    print("="*80)
    result2 = engine.analyze(vehicle2)
    
    # Test vehicle 3: Heavy damage
    vehicle3 = VehicleData(
        make_model="Ford Focus",
        year=2019,
        mileage_km=120000,
        fuel_type="benzin",
        gear_type="otomatik",
        listed_price=380000,
        market_price_avg=450000,
        damage_level="HEAVY",
        bodywork_status=["tavan", "motor_havuzu"],
        demand_level="MEDIUM",
        seasonality="NORMAL"
    )
    
    print("\n" + "="*80)
    print("TEST 3: Heavy Damage Vehicle")
    print("="*80)
    result3 = engine.analyze(vehicle3)
    
    print("\n" + "="*80)
    print("✅ ALL TESTS COMPLETED")
    print("="*80)
