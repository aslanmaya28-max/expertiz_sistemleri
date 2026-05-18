import warnings
import asyncio

# DEPRECATION WARNING: IntegrationBridge is legacy. Use MasterForensicPipeline for all new forensic valuations.
warnings.warn("IntegrationBridge is deprecated and will be removed in v9.0. Please use MasterForensicPipeline.", DeprecationWarning, stacklevel=2)
import json
import random
from datetime import datetime
from typing import Optional, List, Dict

try:
    from yerimebak_ai_v5.core.ai.ai_orchestrator import AIOrchestrator
    from yerimebak_ai_v5.core.ai.true_value_engine import TrueValueEngine
    from yerimebak_ai_v5.core.ai.hybrid_engine import HybridValuationEngine
    from yerimebak_ai_v5.core.security.evidence_vault import EvidenceVault
    from yerimebak_ai_v5.core.security.evidence_package import EvidencePackageBuilder
except ImportError:
    from yerimebak_ai_v5.core.ai.ai_orchestrator import AIOrchestrator
    from yerimebak_ai_v5.core.ai.true_value_engine import TrueValueEngine
    from yerimebak_ai_v5.core.ai.hybrid_engine import HybridValuationEngine
    from yerimebak_ai_v5.core.security.evidence_vault import EvidenceVault
    from yerimebak_ai_v5.core.security.evidence_package import EvidencePackageBuilder

# Add scrapers to path for imports
import sys
from pathlib import Path
scrapers_path = Path(__file__).parent.parent / "scrapers"
if str(scrapers_path) not in sys.path:
    sys.path.insert(0, str(scrapers_path))

class IntegrationBridge:
    """
    DEPRECATED: Antigravity v5.5+ Hybrid Autonomous Integration Bridge.
    Legacy component. Please migrate to MasterForensicPipeline.
    """
    
    def __init__(self, customer_data: dict, use_ai: bool = True, ai_engine: str = "gemini", auto_store: bool = True):
        """
        Args:
            customer_data: Customer and vehicle information
            use_ai: Enable AI enhancement (True: hybrid, False: rule-based only)
            ai_engine: AI engine to use ("gemini" or "glm")
            auto_store: Automatically store to vault (True for standalone, False for manual control)
        """
        self.customer_data = customer_data
        self.orchestrator = AIOrchestrator()
        self.use_ai = use_ai
        self.ai_engine = ai_engine
        # Use hybrid engine instead of TrueValueEngine
        self.engine = HybridValuationEngine(ai_engine=ai_engine, verbose=True)
        self.vault = EvidenceVault()
        self.auto_store = auto_store
        
    async def _validate_input_data(self, vehicle_info: dict) -> bool:
        """GÖREV 2: Validation Layer (Zorunlu)"""
        required = ["brand", "model", "km"]
        return all(vehicle_info.get(k) for k in required)

    async def run_forensic_pipeline(self, vision_data: Optional[dict] = None, files: List[dict] = []) -> dict:
        """v5.2+ SaaS: Evidence Package Centric Pipeline"""
        
        print("\n🏛️ YERİMEBAK SaaS CORE – EVIDENCE PACKAGE PIPELINE ACTIVE")
        
        case_id = self.customer_data.get('customer_id', 'UNKNOWN-CASE')
        vehicle_info = self.customer_data.get('vehicle_info', {})
        
        if not await self._validate_input_data(vehicle_info):
            return self._generate_negative_proof("MİM ARİ HATA: Eksik veri (Brand/Model/KM)")

        try:
            # 1. RETRIEVE PREDECESSOR (SaaS Version Linking)
            timeline = self.vault.get_case_timeline(case_id)
            current_version = len(timeline) + 1
            last_hash = timeline[-1]["hash"] if timeline else None

            # 2. EVIDENCE PACKAGE BUILDING
            builder = EvidencePackageBuilder(case_id, version=current_version)
            builder.add_manual_input(vehicle_info)
            
            # Add files to evidence package
            for f in files:
                 builder.add_file(f.get('filename'), f.get('content_type'), f.get('file_hash', 'PENDING_HASH'))

            if vision_data:
                builder.add_image_hash("vision_core_analysis")
            
            # 3. NORMALIZATION & SIGNAL EXTRACTION
            pkg = builder.compile()
            
            # 4. VALUATION (Based on Normalized Data) - v5.5 HYBRID
            search_results = await self._harvest_market_data()
            market_median = sum(r['price'] for r in search_results) / len(search_results) if search_results else 1000000
            
            # Use hybrid engine (rule-based + AI)
            engine_res = self.engine.calculate(
                market_median=market_median,
                vehicle=pkg.normalized_snapshot,
                market_data=search_results,
                use_ai=self.use_ai  # AI enhancement based on user preference
            )
            
            # 5. ORCHESTRATION & SEALING
            # We bundle the Evidence Package into the Forensic Notary Object
            # In a strict SaaS architecture, the Evidence Package IS the primary record.
            
            # We add results to the package for final seal
            pkg.normalized_snapshot["valuation_result"] = engine_res['valuation']
            builder.seal(pkg, prev_hash=last_hash)
            
            # 6. VAULT COMMIT (OPTIONAL - controlled by auto_store)
            final_record = pkg.to_dict()
            # Add metadata for legacy compatibility in dashboard
            final_record["status"] = "VERIFIED_V52"
            final_record["metadata"] = {"timestamp": pkg.created_at, "version": current_version}
            final_record["valuation"] = {"valuation": engine_res['valuation'], "raw_input": vehicle_info}
            final_record["seal"] = pkg.forensic_metadata["package_hash"]

            # Only auto-store if enabled (for backwards compatibility)
            if self.auto_store:
                try:
                    vault_path = self.vault.store_record(final_record, vault_key=case_id)
                    print(f"  ✅ Evidence Package {pkg.package_id} (v{current_version}) Vaulted: {vault_path}")
                except Exception as ve:
                    print(f"  ❌ VAULT_COMMIT_FAILURE: {ve}")
                    return self._generate_negative_proof(f"Vault error: {ve}")
            else:
                print(f"  ℹ️  Skipping auto-store (auto_store=False). Caller must manually vault the record.")
            
            return final_record

        except Exception as e:
            print(f"  ❌ SaaS Pipeline Execution Failure: {e}")
            import traceback
            traceback.print_exc()
            return self._generate_negative_proof(str(e))
    
    async def _harvest_market_data(self) -> list:
        """CANLI VERİ HASADI v5.4 - Arabam ve Sahibinden'dan gerçek scraping + Caching"""
        vehicle = self.customer_data.get('vehicle_info', {})
        brand = vehicle.get('brand', '')
        model = vehicle.get('model', '')
        year = vehicle.get('year', 2020)
        
        print(f"\n🌐 CANLI VERİ HASADI BAŞLATILIYOR: {brand} {model} {year}")
        print("=" * 60)
        
        # CHECK CACHE FIRST
        try:
            from .cache_manager import get_cache_manager
            cache = get_cache_manager()
            cached_data = cache.get(brand, model, year)
            
            if cached_data:
                print(f"🎯 CACHE HIT: {len(cached_data)} listings from cache")
                print("=" * 60)
                return cached_data
        except Exception as e:
            print(f"⚠️  Cache check error: {e}")
        
        # NO CACHE - SCRAPE FRESH DATA
        all_listings = []
        
        # 1. Arabam.com'dan veri çek (DETAYLI)
        try:
            from scrapers.arabam_detailed import ArabamDetailedCollector
            arabam_collector = ArabamDetailedCollector(headless=True)
            arabam_results = await arabam_collector.collect_data(brand, model, year)
            all_listings.extend(arabam_results)
            print(f"✅ Arabam.com (Detailed): {len(arabam_results)} gerçek ilan çekildi")
        except Exception as e:
            print(f"⚠️  Arabam.com hatası: {e}")
        
        # 2. Borusan Next'ten veri çek
        try:
            from scrapers.borusan_smart import get_borusan_scraper
            borusan_scraper = get_borusan_scraper()
            # Fix: .scrape -> .collect_data and params fix
            borusan_results = await borusan_scraper.collect_data(
                brand=brand, 
                year_min=year, 
                year_max=year,
                model=model
            )
            all_listings.extend(borusan_results)
            print(f"✅ Borusan Next: {len(borusan_results)} gerçek ilan çekildi")
        except Exception as e:
            print(f"⚠️  Borusan Next hatası: {e}")
        
        print("=" * 60)
        print(f"🎯 TOPLAM CANLI VERİ: {len(all_listings)} gerçek piyasa ilanı")
        
        # CACHE THE RESULTS
        if all_listings:
            try:
                from .cache_manager import get_cache_manager
                cache = get_cache_manager()
                cache.set(brand, model, year, all_listings)
            except Exception as e:
                print(f"⚠️  Cache write error: {e}")
        
        # Eğer hiç veri çekilemezse, fallback (demo için)
        if not all_listings:
            print("⚠️  UYARI: Canlı veri çekilemedi, demo moduna geçiliyor...")
            await asyncio.sleep(1)
            for i in range(5):
                all_listings.append({
                    "price": random.randint(300000, 600000),
                    "source": "demo_fallback",
                    "url": f"https://demo.fallback/ilan/{i}"
                })
        
        return all_listings

    def _generate_negative_proof(self, reason: str) -> dict:
        """v5.1 Fail-Safe: Negative Proof üret"""
        return {
            "status": "NEGATIVE_PROOF",
            "error_log": reason,
            "timestamp": datetime.now().isoformat(),
            "confidence": 0.0,
            "seal": "FAILED_INTEGRITY"
        }

# Entegrasyon testi
async def test_v51_bridge():
    test_customer = {
        "customer_id": "V51_AUDIT_77",
        "vehicle_info": {
            "brand": "Ford",
            "model": "Focus",
            "year": 2019,
            "km": 92000,
            "color": "gri",
            "changed": ["sol_on_kapi"],
            "painted": ["tavan"] # Roof paint!
        }
    }
    
    bridge = IntegrationBridge(test_customer)
    result = await bridge.run_forensic_pipeline()
    print("\n" + json.dumps(result, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    asyncio.run(test_v51_bridge())