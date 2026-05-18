# -*- coding: utf-8 -*-
"""
YERİMEBAK AI v5.5 - Hybrid Valuation Engine
Kural tabanlı hızlı sistem + AI detaylı raporlama
"""

import json
from typing import Dict, List, Optional
from datetime import datetime

try:
    from .true_value_engine import TrueValueEngine
    from .ai_service import get_ai_service
except ImportError:
    from true_value_engine import TrueValueEngine
    from ai_service import get_ai_service

class HybridValuationEngine:
    """
    Hibrit Değerleme Motoru v5.5
    
    Strateji:
    1. Kural tabanlı hızlı hesaplama (TrueValueEngine)
    2. AI ile detaylı raporlama (AIService)
    3. Kullanıcı tercihine göre çalışma
    """
    
    def __init__(self, ai_engine: str = "gemini", verbose: bool = True):
        """
        Args:
            ai_engine: "gemini" veya "glm"
            verbose: Konsol çıktısı göster
        """
        self.verbose = verbose
        self.version = "5.5-hybrid"
        
        # Kural tabanlı motor (her zaman aktif)
        self.rule_engine = TrueValueEngine(verbose=False)
        
        # AI servis (opsiyonel)
        self.ai_engine_name = ai_engine
        self.ai_service = None
        
        # İlk başta lazy load
        self._ai_initialized = False
    
    def _ensure_ai_initialized(self):
        """Lazy initialization of AI service"""
        if not self._ai_initialized:
            self.ai_service = get_ai_service(engine=self.ai_engine_name)
            self._ai_initialized = True
            
            if self.verbose and self.ai_service.is_enabled():
                print(f"✅ Hybrid Engine: AI service initialized ({self.ai_engine_name})")
            elif self.verbose and not self.ai_service.is_enabled():
                print(f"⚠️  Hybrid Engine: AI service not available, rule-based mode only")
    
    def calculate(
        self,
        market_median: float,
        vehicle: Dict,
        market_data: List[Dict] = None,
        use_ai: bool = True,
        force_ai: bool = False
    ) -> Dict:
        """
        Hibrit değerleme hesaplama
        
        Args:
            market_median: Piyasa medyan fiyatı
            vehicle: Araç bilgileri
            market_data: Piyasa ilanları (opsiyonel, AI için)
            use_ai: AI kullan (True: opsiyonel, False: sadece kural)
            force_ai: AI zorla (True: hata vermezse çalıştır)
        
        Returns:
            Değerleme sonucu
        """
        
        if self.verbose:
            print(f"\n🏛️  HIBRIT DEĞERLEME MOTORU v{self.version}")
            print(f"   Araç: {vehicle.get('brand')} {vehicle.get('model')} {vehicle.get('year')}")
            print(f"   KM: {vehicle.get('km', 0):,}")
        
        # 1. KURAL TABANLI HIZLI HESAPLAMA (Her zaman yap)
        rule_result = self.rule_engine.calculate_v51(market_median, vehicle)
        
        if self.verbose:
            print(f"\n📊 KURAL TABANLI HESAPLAMA:")
            print(f"   Piyasa Ortalaması: {rule_result['valuation']['base_price']:,.0f} TL")
            print(f"   AI Tahmini: {rule_result['valuation']['final_estimate']:,.0f} TL")
            print(f"   Değer Kaybı (DKK): {rule_result['valuation']['deger_kaybi_katsayisi']:.4f}")
            print(f"   Güven Skoru: %{rule_result['confidence_score']*100:.1f}")
        
        # 2. AI RAPORLAMA (Opsiyonel)
        ai_narrative = None
        ai_used = False
        ai_info = None
        
        if use_ai or force_ai:
            self._ensure_ai_initialized()
            
            if self.ai_service and self.ai_service.is_enabled():
                if self.verbose:
                    print(f"\n🤖 AI RAPORLAMA BAŞLATILIYOR ({self.ai_engine_name})...")
                    print(f"   Bu işlem 2-10 saniye sürebilir...")
                
                try:
                    # AI ile detaylı rapor üret
                    ai_narrative = self.ai_service.generate_narrative(
                        vehicle_data=vehicle,
                        valuation_result=rule_result['valuation'],
                        market_data=market_data
                    )
                    
                    if ai_narrative:
                        ai_used = True
                        ai_info = self.ai_service.get_info()
                        
                        if self.verbose:
                            print(f"   ✅ AI raporu başarıyla üretildi ({len(ai_narrative)} karakter)")
                    else:
                        if self.verbose:
                            print(f"   ⚠️  AI raporu üretilemedi")
                
                except Exception as e:
                    if self.verbose:
                        print(f"   ❌ AI raporlama hatası: {e}")
            else:
                if self.verbose:
                    print(f"\n⚠️  AI servisi kullanılamıyor")
                    print(f"   Kural tabanlı sonuç kullanılıyor")
        
        # 3. HİBRİT SONUÇ
        result = {
            "engine": self.version,
            "calculation_mode": "hybrid" if ai_used else "rule_based",
            "valuation": rule_result['valuation'],
            "forensic_status": rule_result.get('forensic_status', 'UNKNOWN'),
            "confidence_score": rule_result['confidence_score'],
            "evidence_log": rule_result.get('evidence_log', []),
            "ai_enhancement": {
                "enabled": ai_used,
                "engine": ai_info['model'] if ai_info else None,
                "narrative": ai_narrative
            },
            "metadata": {
                "timestamp": datetime.now().isoformat(),
                "rule_engine_version": self.rule_engine.version,
                "ai_available": self.ai_service.is_enabled() if self.ai_service else False,
                "ai_engine": self.ai_engine_name
            }
        }
        
        if self.verbose:
            print(f"\n✅ HİBRİT DEĞERLEME TAMAMLANDI")
            print(f"   Mod: {result['calculation_mode'].upper()}")
            if ai_used:
                print(f"   AI Engine: {ai_info['model']}")
                print(f"   Rapor: Detaylı ({len(ai_narrative)} karakter)")
            else:
                print(f"   Rapor: Kural tabanlı")
        
        return result
    
    def get_ai_status(self) -> Dict:
        """AI servis durumunu kontrol et"""
        self._ensure_ai_initialized()
        
        if not self.ai_service:
            return {
                "available": False,
                "engine": None,
                "reason": "AI service not initialized"
            }
        
        info = self.ai_service.get_info()
        return {
            "available": info['enabled'],
            "engine": info['engine'],
            "model": info['model'],
            "reason": "Ready" if info['enabled'] else "API key not configured"
        }
    
    def is_ai_available(self) -> bool:
        """AI servis kullanılabilir mi?"""
        self._ensure_ai_initialized()
        return self.ai_service and self.ai_service.is_enabled()

if __name__ == "__main__":
    # Test hybrid engine
    print("=" * 70)
    print("HIBRIT MOTOR TEST")
    print("=" * 70)
    
    engine = HybridValuationEngine(ai_engine="gemini", verbose=True)
    
    # Test vehicle
    test_vehicle = {
        "brand": "Ford",
        "model": "Focus",
        "year": 2019,
        "km": 95000,
        "color": "gri",
        "changed": ["sol_on_kapi"],
        "painted": ["tavan"]
    }
    
    # Test market data
    test_market = [
        {"price": 450000, "source": "arabam.com"},
        {"price": 475000, "source": "arabam.com"},
        {"price": 460000, "source": "sahibinden"},
        {"price": 485000, "source": "arabam.com"},
        {"price": 470000, "source": "arabam.com"}
    ]
    
    market_median = sum(m['price'] for m in test_market) / len(test_market)
    
    # Test with AI
    print("\n\n### TEST 1: WITH AI (if available) ###")
    result1 = engine.calculate(
        market_median=market_median,
        vehicle=test_vehicle,
        market_data=test_market,
        use_ai=True
    )
    
    # Test without AI
    print("\n\n### TEST 2: WITHOUT AI (rule-based only) ###")
    result2 = engine.calculate(
        market_median=market_median,
        vehicle=test_vehicle,
        market_data=test_market,
        use_ai=False
    )
    
    # Print AI status
    print("\n\n### AI STATUS ###")
    print(json.dumps(engine.get_ai_status(), indent=2))