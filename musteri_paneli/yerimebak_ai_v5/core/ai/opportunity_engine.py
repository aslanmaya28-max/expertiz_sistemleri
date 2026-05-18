# -*- coding: utf-8 -*-
"""
YERİMEBAK AI - Opportunity Engine
Dynamic Opportunity Scoring and Action Recommendations
"""
from typing import Dict, Any, Optional

class OpportunityEngine:
    def __init__(self):
        pass

    def calculate_opportunity(self, 
                             price: float, 
                             market_avg: float, 
                             condition_score: float, 
                             vision_score: Optional[float] = None,
                             risk_score: float = 0.0,
                             km: int = 0,
                             year: int = 2020,
                             damage_level: str = "none",
                             listing_count: int = 0) -> Dict[str, Any]:
        """
        v7.2 — SAHİPSİZ ULTRA: Dinamik Fırsat Skoru ve Karar Mekanizması
        """
        risk_score = risk_score or 0.0
        condition_score = condition_score or 100.0
        vision_score = vision_score or 100.0
        km = km or 0
        year = year or 2020
        damage_level = (damage_level or "none").lower()

        if market_avg <= 0:
            return {
                "opportunity_score": 0,
                "action_recommendation": "Beklet",
                "risk_score": 50,
                "confidence_score": 30
            }

        # 1. v7.2 Baz Risk Artışları
        base_risk = risk_score
        
        # v7.2 Damage Penalties (NONE:0, LIGHT:2, MEDIUM:5, HEAVY:10+)
        damage_impact = 0
        if "heavy" in damage_level or "ağır" in damage_level:
            base_risk += 45
            damage_impact = 15
        elif "medium" in damage_level or "orta" in damage_level:
            base_risk += 20
            damage_impact = 5
        elif "light" in damage_level or "hafif" in damage_level:
            base_risk += 10
            damage_impact = 2
            
        # KM Risk v7.2
        if km > 300000: base_risk += 35
        elif km > 200000: base_risk += 25
        elif km > 150000: base_risk += 15
        
        # 1.1 Market Saturation & Liquidity (SAHİPSİZ Engine)
        if listing_count > 100: base_risk += 10 # Oversaturated
        elif listing_count < 10: base_risk += 5 # Low liquidity/data
        
        # 2. Baz indirim oranı
        discount_ratio = (market_avg - price) / market_avg
        
        # 3. Kondisyon & Vision
        final_condition = (condition_score * 0.4) + (vision_score * 0.6)
            
        # 4. Fırsat Skoru (0-100) — SAHİPSİZ Weighted Logic
        opp_score = (discount_ratio * 320) + (final_condition * 0.35) - (base_risk * 0.55)
        
        # v7.2 Hard Penalties
        if km > 250000: opp_score -= 30
        if "heavy" in damage_level or "ağır" in damage_level: opp_score -= 40
        
        # v7.2 Hallucination Guard (Strict)
        if base_risk > 35: opp_score = min(opp_score, 70)
        if base_risk > 55: opp_score = min(opp_score, 45)
        if base_risk > 75: opp_score = min(opp_score, 15)

        opp_score = max(0, min(100, opp_score))
        
        # 5. v7.2 Confidence Score (SAHİPSİZ Engine)
        confidence = 100 - (base_risk * 0.2)
        if listing_count < 5: confidence -= 20
        confidence = max(10, min(95, confidence))
        
        # 6. Dealer Decision Engine (v7.2)
        if opp_score >= 85: rec = "STRONG_BUY 🔥"
        elif opp_score >= 70: rec = "BUY ✅"
        elif opp_score >= 50: rec = "NEGOTIATE ⏳"
        elif opp_score >= 30: rec = "HOLD ⏸️"
        else: rec = "AVOID ⚠️"
            
        return {
            "opportunity_score": round(opp_score, 1),
            "action_recommendation": rec,
            "risk_score": round(min(100, base_risk), 1),
            "confidence_score": round(confidence, 1),
            "damage_impact_pct": damage_impact
        }
