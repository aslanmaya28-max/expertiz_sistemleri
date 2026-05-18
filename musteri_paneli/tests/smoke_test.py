import asyncio
import sys
import os
from pathlib import Path

# Fix Path - Add the parent directory so 'yerimebak_ai_v5' is a package
current_dir = Path(__file__).resolve().parent
sys.path.append(str(current_dir.parent))

async def smoke_test():
    print("🚀 Yerimebak AI Unified OS - Smoke Test Başlatılıyor...")
    
    from yerimebak_ai_v5.services import get_analysis_service, get_market_intelligence_service
    
    analysis = get_analysis_service()
    market = get_market_intelligence_service()
    
    test_car = {
        "brand": "Volkswagen",
        "model": "Golf",
        "year": 2020,
        "km": 45000,
        "paket": "Highline",
        "tramer": 5000,
        "degisen": ["Ön Tampon"],
        "boyali": ["Sağ Ön Çamurluk"]
    }
    
    print("\n1. 📊 Market Analysis Testi...")
    try:
        m_res = await market.analyze_market(test_car)
        print(f"✅ Market Summary: Avg Price {m_res['market_summary']['average_price']:,} TL")
        print(f"✅ FMV: {m_res['valuation']['fair_market_value']:,} TL")
    except Exception as e:
        print(f"❌ Market Analysis Hatası: {e}")

    print("\n2. 🔬 Full Forensic Analysis Testi (AI + Seal)...")
    try:
        # Note: This will call Gemini/Groq if keys are valid
        a_res = await analysis.run_full_analysis(test_car)
        print(f"✅ Forensic Seal: {a_res['forensic']['seal']}")
        print(f"✅ AI Verdict Length: {len(a_res['ai_rapor']['gemini'] or '')} characters")
        print(f"✅ Case ID Created: {a_res.get('case_id')}")
    except Exception as e:
        print(f"❌ Full Analysis Hatası: {e}")

    print("\n🚀 Smoke Test Tamamlandı.")

if __name__ == "__main__":
    asyncio.run(smoke_test())
