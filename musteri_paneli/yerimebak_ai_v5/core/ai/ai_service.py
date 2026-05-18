# -*- coding: utf-8 -*-
"""
YERİMEBAK AI v5.5 - AI Service Module
Gemini and GLM-4 integration for narrative generation
"""

import os
import json
from typing import Dict, Optional, Literal
from datetime import datetime

class AIService:
    """
    AI Service for narrative generation
    Supports: Gemini (Google) and GLM-4 (Zhipu AI)
    """
    
    def __init__(self, engine: Literal["gemini", "glm"] = "gemini"):
        self.engine = engine
        self.enabled = False
        self.client = None
        self.model_name = None
        
        # Try to initialize
        self._initialize_engine()
    
    def _initialize_engine(self):
        """Initialize AI engine based on configuration"""
        if self.engine == "gemini":
            self._init_gemini()
        elif self.engine == "glm":
            self._init_glm()
    
    def _init_gemini(self):
        """Initialize Gemini AI using new SDK"""
        try:
            from google import genai
            
            api_key = os.getenv("GOOGLE_API_KEY") or os.getenv("GEMINI_API_KEY")
            if not api_key:
                print("⚠️  GEMINI_API_KEY not found in environment")
                return
            
            self.client = genai.Client(api_key=api_key)
            self.model_name = "gemini-2.0-flash"
            self.enabled = True
            print(f"✅ Gemini AI initialized: {self.model_name} (NEW SDK)")
            
        except ImportError:
            print("⚠️  google-genai not installed")
        except Exception as e:
            print(f"⚠️  Gemini initialization failed: {e}")
    
    def _init_glm(self):
        """Initialize GLM-4 AI"""
        try:
            from zhipuai import ZhipuAI
            
            api_key = os.getenv("ZHIPU_API_KEY")
            if not api_key:
                print("⚠️  ZHIPU_API_KEY not found in environment")
                return
            
            self.client = ZhipuAI(api_key=api_key)
            self.model_name = "glm-4-plus"
            self.enabled = True
            print(f"✅ GLM-4 AI initialized: {self.model_name}")
            
        except ImportError:
            print("⚠️  zhipuai not installed")
            print("   Install: pip install zhipuai")
        except Exception as e:
            print(f"⚠️  GLM initialization failed: {e}")
    
    def generate_narrative(self, vehicle_data: Dict, valuation_result: Dict, market_data: list = None) -> str:
        """
        Generate detailed valuation narrative using AI
        
        Args:
            vehicle_data: Vehicle information (brand, model, year, km, etc.)
            valuation_result: Valuation calculation results
            market_data: List of market listings (optional)
        
        Returns:
            AI-generated narrative text
        """
        if not self.enabled:
            return None
        
        try:
            # Build prompt
            prompt = self._build_prompt(vehicle_data, valuation_result, market_data)
            
            # Generate based on engine
            if self.engine == "gemini":
                return self._generate_gemini(prompt)
            elif self.engine == "glm":
                return self._generate_glm(prompt)
            
        except Exception as e:
            print(f"⚠️  AI generation failed: {e}")
            return None
    
    def _build_prompt(self, vehicle_data: Dict, valuation_result: Dict, market_data: list = None) -> str:
        """Build detailed prompt for AI"""
        
        # Extract vehicle info
        brand = vehicle_data.get('brand', 'Bilinmiyor')
        model = vehicle_data.get('model', 'Bilinmiyor')
        year = vehicle_data.get('year', 2020)
        km = vehicle_data.get('km', 0)
        color = vehicle_data.get('color', 'Bilinmiyor')
        changed = vehicle_data.get('changed', [])
        painted = vehicle_data.get('painted', [])
        
        # Extract valuation info
        base_price = valuation_result.get('base_price', 0)
        ai_adjustment = valuation_result.get('ai_adjustment', 0)
        final_estimate = valuation_result.get('final_estimate', 0)
        dkk = valuation_result.get('deger_kaybi_katsayisi', 0)
        confidence = valuation_result.get('confidence_score', 0.95)
        
        # Build market analysis
        market_stats = ""
        if market_data:
            sources = {}
            for listing in market_data:
                source = listing.get('source', 'unknown')
                sources[source] = sources.get(source, 0) + 1
                
            # Market Condition Summary
            condition_stats = {
                'original': 0, 'painted': 0, 'changed': 0, 'unknown': 0
            }
            package_counts = {}
            
            for listing in market_data:
                # Condition stats
                p_info = listing.get('paint_info', {}) or {}
                if isinstance(p_info, str):
                    try: p_info = json.loads(p_info)
                    except: p_info = {}
                
                if p_info.get('is_original'): condition_stats['original'] += 1
                elif p_info.get('has_changed'): condition_stats['changed'] += 1
                elif p_info.get('has_paint'): condition_stats['painted'] += 1
                else: condition_stats['unknown'] += 1
                
                # Package stats
                pkgs = listing.get('package_info', []) or []
                if isinstance(pkgs, str):
                    try: pkgs = json.loads(pkgs)
                    except: pkgs = []
                for pkg in pkgs[:3]: # Top 3 per listing
                    package_counts[pkg] = package_counts.get(pkg, 0) + 1

            top_packages = sorted(package_counts.items(), key=lambda x: x[1], reverse=True)[:5]
            
            market_stats = f"""
Piyasa Analizi:
- Toplam İlan Sayısı: {len(market_data)} adet
- Kaynaklar: {', '.join([f'{s} ({v} ilan)' for s, v in sources.items()])}
- Ortalama Piyasa Fiyatı: {base_price:,.0f} TL
- Piyasadaki Araç Durumları: {condition_stats['original']} Orjinal, {condition_stats['painted']} Boyalı, {condition_stats['changed']} Değişenli
- En Yaygın Donanımlar: {', '.join([f'{p[0]}' for p in top_packages])}
            """
        
        # Build damage analysis
        damage_analysis = ""
        if changed or painted:
            damage_analysis = "\nHasar Analizi:\n"
            if changed:
                for part in changed:
                    damage_analysis += f"- Değişen: {part}\n"
            if painted:
                for part in painted:
                    damage_analysis += f"- Boyalı: {part}\n"
        else:
            damage_analysis = "\nHasar Durumu: Temiz (değişen/boyalı parça yok)\n"
        
        diff_pct = (ai_adjustment / base_price * 100) if base_price > 0 else 0.0

        prompt = f"""
Sen profesyonel bir araç değerleme uzmanısın. Aşağıdaki araç için detaylı bir değerleme raporu hazırla.

ARAÇ BİLGİLERİ:
Marka: {brand}
Model: {model}
Yıl: {year}
Kilometre: {km:,} km
Renk: {color}

{damage_analysis}

DEĞERLEME SONUÇLARI:
Piyasa Ortalaması: {base_price:,.0f} TL
AI Tahmini: {final_estimate:,.0f} TL
Fark: {ai_adjustment:,.0f} TL ({diff_pct:+.1f}%)
Değer Kaybı Katsayısı (DKK): {dkk:.4f}
Güven Skoru: %{confidence*100:.1f}

{market_stats}

TALEP:
1. Profesyonel, tarafsız ve objektif dil kullan
2. Türkçe, resmi dilde yaz
3. Araç durumunu detaylı analiz et
4. Piyasa konumunu değerlendir (ucuz/normal/pahalı)
5. Hasarların fiyata etkisini açıkla
6. Alıcı için tavsiyeler sun
7. Yatırım potansiyelini değerlendir

Raporu şu başlıklar altında düzenle:
- GENEL DEĞERLEME
- HASAR ANALİZİ
- PİYASA KONUMU
- ALICI TAVSİYELERİ
- YATIRIM DEĞERLENDIRMESİ
        """
        
        return prompt.strip()
    
    def _generate_gemini(self, prompt: str) -> str:
        """Generate using Gemini (NEW SDK)"""
        if not self.client:
            return "AI Client not initialized"
        response = self.client.models.generate_content(
            model=self.model_name,
            contents=prompt
        )
        return response.text
    
    def _generate_glm(self, prompt: str) -> str:
        """Generate using GLM-4"""
        response = self.client.chat.completions.create(
            model=self.model_name,
            messages=[
                {
                    "role": "system",
                    "content": "Sen profesyonel bir araç değerleme uzmanısın. Tarafsız, detaylı ve objektif raporlar hazırlarsın."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            temperature=0.7,
            max_tokens=2000
        )
        return response.choices[0].message.content
    
    def is_enabled(self) -> bool:
        """Check if AI service is enabled"""
        return self.enabled
    
    def get_info(self) -> Dict:
        """Get AI service information"""
        return {
            "engine": self.engine,
            "model": self.model_name,
            "enabled": self.enabled,
            "available_models": {
                "gemini": "gemini-2.0-flash-exp",
                "glm": "glm-4-plus"
            }
        }

# Singleton instances
_gemini_service = None
_glm_service = None

def get_ai_service(engine: str = "gemini") -> AIService:
    """Get or create AI service singleton"""
    global _gemini_service, _glm_service
    
    if engine == "gemini":
        if _gemini_service is None:
            _gemini_service = AIService(engine="gemini")
        return _gemini_service
    elif engine == "glm":
        if _glm_service is None:
            _glm_service = AIService(engine="glm")
        return _glm_service
    else:
        raise ValueError(f"Unknown AI engine: {engine}")

if __name__ == "__main__":
    # Test AI service
    print("Testing AI Service...")
    
    # Test Gemini
    print("\n=== Testing Gemini ===")
    gemini = get_ai_service("gemini")
    print(f"Gemini enabled: {gemini.is_enabled()}")
    print(f"Gemini info: {json.dumps(gemini.get_info(), indent=2)}")
    
    # Test GLM
    print("\n=== Testing GLM ===")
    glm = get_ai_service("glm")
    print(f"GLM enabled: {glm.is_enabled()}")
    print(f"GLM info: {json.dumps(glm.get_info(), indent=2)}")