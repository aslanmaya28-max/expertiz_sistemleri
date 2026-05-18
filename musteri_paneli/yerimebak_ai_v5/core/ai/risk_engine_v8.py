# -*- coding: utf-8 -*-
"""
YERİMEBAK AI v8.0 - Risk Engine V8
Deterministic Mathematical Valuation Engine
ZERO GUESS - ZERO HALLUCINATION - STRICT MATHEMATICAL
"""

from typing import Dict, Any, List
from dataclasses import dataclass


@dataclass
class RiskCalculation:
    """Risk hesaplama sonucu"""
    km_risk: float
    paint_risk: float
    change_risk: float
    damage_risk: float
    package_bonus: float
    total_risk: float
    exit_price: float
    estimated_days_to_sell: int
    opportunity_score: int
    decision: str


class RiskEngineV8:
    """
    YERİMEBAK AI v8.0 - Risk Engine V8
    
    Deterministic mathematical valuation engine.
    NO AI estimation. NO guessing. NO hallucination.
    ONLY mathematical formulas.
    
    Same input → SAME output (100% reproducible)
    """
    
    # ENGINE 2: Paint Risk Table
    PART_PAINT = 6  # 4'ten 6'ya çıkarıldı (Galerici standardı)
    LOCAL_PAINT = 3 # 2'den 3'e çıkarıldı
    FULL_BODY = 35  # 25'ten 35'e çıkarıldı
    
    # ENGINE 3: Change Risk Map (İngilizce + Türkçe Destek)
    CHANGE_RISK_MAP = {
        # İngilizce Kayıtlar
        "fender": 8,
        "door": 10,
        "hood": 18,
        "trunk": 15,
        "roof": 45,
        "pillar": 45,
        "chassis": 60,
        "front_panel": 25,
        "rear_panel": 20,
        
        # Türkçe Kayıtlar (Arabam.com Crawler verisi için)
        "çamurluk": 8,
        "kapi": 10,
        "kapı": 10,
        "kaput": 18,
        "bagaj": 15,
        "tavan": 45,
        "direk": 45,
        "şase": 60,
        "sase": 60,
        "panel": 25,
        "podye": 60,
        "marşpiyel": 5,
        "tampon": 2
    }
    
    # ENGINE 5: Package Bonus Map
    PACKAGE_MAP = {
        "BASE": 0,
        "MID": -3,
        "HIGH": -5,
        "FULL": -8
    }
    
    # ENGINE 9: Base days
    BASE_DAYS = 15
    
    def calculate(self, vehicle_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Main calculation method
        
        Args:
            vehicle_data: {
                "price": float,
                "vehicle_km": int,
                "market_average_km": int,
                "painted_parts": int,
                "local_paint_parts": int,
                "changed_parts": List[str],
                "damage_amount": float,
                "package_level": str
            }
        
        Returns:
            Strict JSON output
        """
        # Extract input data
        price = vehicle_data.get("price", 0)
        vehicle_km = vehicle_data.get("vehicle_km", 0)
        market_average_km = vehicle_data.get("market_average_km", 150000)
        painted_parts = vehicle_data.get("painted_parts", 0)
        local_paint_parts = vehicle_data.get("local_paint_parts", 0)
        changed_parts = vehicle_data.get("changed_parts", [])
        damage_amount = vehicle_data.get("damage_amount", 0)
        package_level = vehicle_data.get("package_level", "BASE")
        
        market_price = vehicle_data.get("market_price", 0)
        price_deviation = 0.0
        if market_price > 0 and price > 0:
            price_deviation = ((market_price - price) / market_price) * 100

        # ENGINE 1: KM Risk Engine
        km_risk = self._calculate_km_risk(vehicle_km, market_average_km)

        # ENGINE 2: Paint Risk Engine
        paint_risk = self._calculate_paint_risk(painted_parts, local_paint_parts)

        # ENGINE 3: Part Change Risk Engine
        change_risk = self._calculate_change_risk(changed_parts)

        has_paint_flag = vehicle_data.get("has_paint_flag", False)
        has_changed_flag = vehicle_data.get("has_changed_flag", False)

        if has_changed_flag and change_risk == 0:
            change_risk = 25.0
        if has_paint_flag and paint_risk == 0:
            paint_risk = 12.0

        # ENGINE 4: Damage Record Risk Engine
        damage_risk = self._calculate_damage_risk(damage_amount, price)

        # ENGINE 5: Package Bonus Engine
        package_bonus = self._calculate_package_bonus(package_level)

        # ENGINE 6: Total Risk Engine Final
        total_risk = self._calculate_total_risk(km_risk, paint_risk, change_risk, damage_risk, package_bonus)

        # ENGINE 7: Exit Price Impact Engine
        exit_price = self._calculate_exit_price(price, total_risk)

        # ENGINE 8: Liquidity Impact Engine
        gear_type = vehicle_data.get("gear_type", "")
        estimated_days_to_sell = self._calculate_days_to_sell(total_risk, gear_type)

        # ENGINE 9: Opportunity Score Engine
        opportunity_score = self._calculate_opportunity_score(total_risk, vehicle_km, price_deviation)
        
        # ENGINE 10: Decision Engine
        decision = self._calculate_decision(opportunity_score, change_risk)
        
        # Return strict JSON
        return {
            "km_risk": round(km_risk, 1),
            "paint_risk": round(paint_risk, 1),
            "change_risk": round(change_risk, 1),
            "damage_risk": round(damage_risk, 1),
            "package_bonus": round(package_bonus, 1),
            "total_risk": round(total_risk, 1),
            "exit_price": round(exit_price),
            "estimated_days_to_sell": estimated_days_to_sell,
            "opportunity_score": opportunity_score,
            "decision": decision
        }
    
    def _calculate_km_risk(self, vehicle_km: int, market_average_km: int) -> float:
        """
        ENGINE 1 – KM RISK ENGINE
        
        Formula: km_risk = (km_ratio - 1) * 40
        Constraints: 0 <= km_risk <= 40
        """
        if market_average_km == 0:
            return 0.0
        
        km_ratio = vehicle_km / market_average_km
        km_risk = (km_ratio - 1) * 40
        
        # Apply constraints
        if km_risk < 0:
            km_risk = 0.0
        elif km_risk > 40:
            km_risk = 40.0
        
        return km_risk
    
    def _calculate_paint_risk(self, painted_parts: int, local_paint_parts: int) -> float:
        """
        ENGINE 2 – PAINT RISK ENGINE
        
        Formula: paint_risk = (painted_parts * 4) + (local_paint_parts * 2)
        Constraints: paint_risk <= 30
        """
        paint_risk = (painted_parts * self.PART_PAINT) + (local_paint_parts * self.LOCAL_PAINT)
        
        # Apply constraint
        if paint_risk > 45: # 30'dan 45'e çıkarıldı (Daha hassas derin analiz)
            paint_risk = 45.0
        
        return float(paint_risk)
    
    def _calculate_change_risk(self, changed_parts: List[str]) -> float:
        """
        ENGINE 3 – PART CHANGE RISK ENGINE
        
        Formula: change_risk = sum(CHANGE_RISK_MAP[part] for part in changed_parts)
        Constraints: change_risk <= 60
        """
        change_risk = 0.0
        
        for part in changed_parts:
            part_lower = part.lower().strip()
            found = False
            for key, val in self.CHANGE_RISK_MAP.items():
                if key in part_lower:
                    change_risk += val
                    found = True
                    break
        
        # Apply constraint (Ciddi değişen riski %80'e kadar çıkabilir)
        if change_risk > 80:
            change_risk = 80.0
        
        return change_risk
    
    def _calculate_damage_risk(self, damage_amount: float, price: float) -> float:
        """
        ENGINE 4 – DAMAGE RECORD RISK ENGINE
        
        Formula: damage_risk = (damage_amount / price) * 100
        Constraints: damage_risk <= 30
        """
        if price == 0:
            return 0.0
        
        damage_ratio = damage_amount / price
        damage_risk = damage_ratio * 100
        
        # Apply constraint
        if damage_risk > 30:
            damage_risk = 30.0
        
        return damage_risk
    
    def _calculate_package_bonus(self, package_level: str) -> float:
        """
        ENGINE 5 – PACKAGE BONUS ENGINE
        
        Formula: package_bonus = PACKAGE_MAP[package_level]
        """
        return float(self.PACKAGE_MAP.get(package_level.upper(), 0))
    
    def _calculate_total_risk(self, km_risk: float, paint_risk: float, 
                             change_risk: float, damage_risk: float, 
                             package_bonus: float) -> float:
        """
        ENGINE 6 – TOTAL RISK ENGINE
        
        Formula: total_risk = km_risk + paint_risk + change_risk + damage_risk + package_bonus
        Constraints: 0 <= total_risk <= 100
        """
        total_risk = km_risk + paint_risk + change_risk + damage_risk + package_bonus
        
        # Apply constraints
        if total_risk < 0:
            total_risk = 0.0
        elif total_risk > 100:
            total_risk = 100.0
        
        return total_risk
    
    def _calculate_exit_price(self, price: float, total_risk: float) -> float:
        """
        ENGINE 7 – EXIT PRICE IMPACT ENGINE
        
        Formula: exit_price = price - (price * (total_risk * 0.003))
        Constraints: exit_price >= price * 0.7
        """
        price_reduction_ratio = total_risk * 0.003
        exit_price = price - (price * price_reduction_ratio)
        
        # Apply constraint
        min_exit_price = price * 0.7
        if exit_price < min_exit_price:
            exit_price = min_exit_price
        
        return exit_price
    
    def _calculate_days_to_sell(self, total_risk: float, gear_type: str = "") -> int:
        extra_days = total_risk * 0.7
        estimated_days = self.BASE_DAYS + extra_days
        gear = (gear_type or "").lower()
        if gear in ("manuel", "manual"):
            estimated_days += 5
        return int(estimated_days)

    def _calculate_opportunity_score(self, total_risk: float, vehicle_km: int,
                                     price_deviation: float = 0.0) -> int:
        opportunity_score = 100 - total_risk

        if price_deviation > 10:
            opportunity_score += 15
        elif price_deviation > 5:
            opportunity_score += 8
        elif price_deviation > 0:
            opportunity_score += 3
        elif price_deviation < -10:
            opportunity_score -= 15
        elif price_deviation < -5:
            opportunity_score -= 8

        if vehicle_km > 200000:
            opportunity_score = min(opportunity_score, 65)

        return int(max(0, min(100, opportunity_score)))
    
    def _calculate_decision(self, opportunity_score: int, change_risk: float) -> str:
        """
        ENGINE 10 – DECISION ENGINE
        
        Decision Map:
        - opportunity_score < 30 → AVOID
        - opportunity_score < 50 → HOLD
        - opportunity_score < 70 → BUY
        - opportunity_score >= 70 → STRONG_BUY
        
        Constraint: if change_risk >= 40 → AVOID
        """
        # Apply constraint first
        if change_risk >= 40:
            return "AVOID"
        
        # Decision map
        if opportunity_score < 30:
            return "AVOID"
        elif opportunity_score < 50:
            return "HOLD"
        elif opportunity_score < 70:
            return "BUY"
        else:
            return "STRONG_BUY"


# Singleton instance
_risk_engine_v8 = None

def get_risk_engine_v8() -> RiskEngineV8:
    """Get singleton instance"""
    global _risk_engine_v8
    if _risk_engine_v8 is None:
        _risk_engine_v8 = RiskEngineV8()
    return _risk_engine_v8
