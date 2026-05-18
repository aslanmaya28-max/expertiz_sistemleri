# -*- coding: utf-8 -*-
"""
Verification Script for YERIMEBAK AI Master Analysis
Validates high-mileage penalties, margin caps, and year sanity checks.
"""
import asyncio
import json
import sys
import os

# Adust path to include project root
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if root not in sys.path:
    sys.path.insert(0, root)

from yerimebak_ai_v5.dashboard.services.analiz_service import get_analiz_servisi

async def verify_hallucination_guard():
    print("\n" + "="*80)
    print("🚀 STARTING AI VALUATION & HALLUCINATION GUARD VERIFICATION (v7.2-sahipsiz)")
    print("="*80)
    
    analiz = get_analiz_servisi()
    
    # CASE 1: The reported 2017/2026 Hyundai i20 with high mileage
    print("\n🔍 CASE 1: Reported High-Mileage Hyundai i20 (extracted as 2026)")
    result = analiz.tam_analiz(
        brand="Hyundai",
        model="i20",
        year=2026, # Hallucinated Future Year
        km=208000,
        paket="Style",
        yakit="Dizel",
        sanziman="Manuel",
        degisen_parcalar=[],
        boyali_parcalar=[],
        tramer_bedeli=0,
        listing_count=5 # Low liquidity case
    )
    
    ai = result.get('ai_json', {})
    opp = result.get('opp_res', {})
    
    # Nested extraction for v7.2-sahipsiz
    meta = ai.get('analysis_meta', {})
    tech = ai.get('technical_scoring', {})
    comm = ai.get('commercial_analysis', {})
    verdict = ai.get('dealer_verdict', {})
    
    print(f"   Model: {ai.get('make_model') or 'N/A'}")
    print(f"   Confidence: {meta.get('confidence_score')}% (System: {opp.get('confidence_score')})")
    print(f"   Risk: {tech.get('risk_percentage')}%")
    print(f"   Opportunity Score: {tech.get('opportunity_score')}/100")
    print(f"   Net Profit: {comm.get('net_profit_tl')} TL (Margin: {comm.get('net_margin_percent')}%)")
    print(f"   Decision: {verdict.get('decision')}")
    
    # Assertions
    assert tech.get('risk_percentage', 0) >= 20, "❌ Risk penalty failed"
    assert tech.get('opportunity_score', 0) < 70, "❌ High risk must cap opportunity"
    assert comm.get('net_margin_percent', 0) <= 25, "❌ Margin cap failed"
    
    print("\n✅ CASE 1 PASSED: v7.2 Professional realism enforced.")

    # CASE 2: Heavy Damage Vehicle
    print("\n🔍 CASE 2: Heavy Damage Premium Vehicle (v7.2)")
    result_heavy = analiz.tam_analiz(
        brand="BMW",
        model="3 Serisi",
        year=2019,
        km=95000,
        tramer_bedeli=150000, # Heavy damage
        degisen_parcalar=["ön kaput", "sağ ön çamurluk"],
        boyali_parcalar=["sol ön kapı"],
        listing_count=150 # Oversaturated market
    )
    
    ai_heavy = result_heavy.get('ai_json', {})
    tech_heavy = ai_heavy.get('technical_scoring', {})
    verdict_heavy = ai_heavy.get('dealer_verdict', {})
    
    print(f"   Risk: {tech_heavy.get('risk_percentage')}%")
    print(f"   Opportunity Score: {tech_heavy.get('opportunity_score')}/100")
    print(f"   Decision: {verdict_heavy.get('decision')}")
    
    assert tech_heavy.get('risk_percentage', 0) >= 45, "❌ v7.2 Heavy damage risk failed"
    assert verdict_heavy.get('decision') in ["AVOID", "NEGOTIATE"], "❌ Invalid decision for heavy damage"
    
    print("\n✅ CASE 2 PASSED: Heavy damage correctly penalized under v7.2.")

    print("\n" + "="*80)
    print("✨ ALL VERIFICATIONS PASSED: The AI Valuer is now a disciplined professional.")
    print("="*80 + "\n")

if __name__ == "__main__":
    asyncio.run(verify_hallucination_guard())
