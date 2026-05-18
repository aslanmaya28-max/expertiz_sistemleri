# -*- coding: utf-8 -*-
"""
YERİMEBAK AI v6 - Master Forensic Pipeline
Orchestrates the complete forensic valuation process
"""

import logging
from typing import Dict, Any, List
from datetime import datetime
from pathlib import Path

# ABSOLUTE IMPORTS - Production architecture
from yerimebak_ai_v5.core.data_cleaner import get_data_cleaner
from yerimebak_ai_v5.core.ai_valuation import get_ai_valuation_engine
from yerimebak_ai_v5.core.opportunity_detector import get_opportunity_detector
from yerimebak_ai_v5.core.report_generator import get_report_generator

# Scraper imports removed from top-level to prevent circular dependencies
# Scrapers managed via data_lake/cache.py (Arabam + Borusan)

from yerimebak_ai_v5.core.utils.logger import get_logger
logger = get_logger(__name__)


class MasterForensicPipeline:
    """Master forensic valuation pipeline"""
    
    def __init__(self, debug_mode: bool = False):
        """Initialize master pipeline"""
        self.debug_mode = debug_mode
        
        # Initialize components
        self.data_cleaner = get_data_cleaner(debug_mode=debug_mode)
        self.ai_engine = get_ai_valuation_engine()
        self.opportunity_detector = get_opportunity_detector()
        self.report_generator = get_report_generator()
        
        # Forensic Repository (Single Source of Truth)
        from yerimebak_ai_v5.core.repository import get_repository
        self.repository = get_repository()
        
        # Unified AI Service (v8.1)
        from yerimebak_ai_v5.core.unified_ai_service import get_unified_ai_service
        self.ai_service = get_unified_ai_service()
        
        # Forensic Trust Components
        from yerimebak_ai_v5.core.evidence_vault import EvidenceVault
        from yerimebak_ai_v5.core.evidence_package import EvidencePackageBuilder
        self.vault = EvidenceVault()
        
        # MARKET DATA LAKE CACHE
        from yerimebak_ai_v5.data_lake.cache import get_market_cache
        self.cache = get_market_cache()
        
        logger.info("Master Forensic Pipeline v8.1 (FORENSIC TRUST) initialized")
    
    async def run_forensic_pipeline(self, vehicle_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Run complete forensic valuation pipeline
        
        Args:
            vehicle_data: Raw vehicle input
        
        Returns:
            Complete forensic report
        """
        try:
            logger.info("="*80)
            logger.info("🏛️ YERİMEBAK AI v7.0 - MARKET DATA LAKE MASTER")
            logger.info("="*80)
            
            # STEP 1: Normalize & Validate
            logger.info("\n📋 STEP 1: Normalizing vehicle data...")
            vehicle = self._normalize_vehicle(vehicle_data)
            logger.info(f"✅ Vehicle: {vehicle['brand']} {vehicle['model']} {vehicle['year']}")
            
            # STEP 2: Use Data Lake (Single Source of Truth)
            logger.info("\n🌐 STEP 2: Retrieving data from Market Data Lake...")
            
            # The cache internally triggers scrapers if needed
            # We enforce that all data ends up in the repository
            listings, scraped_count = await self.cache.get_market_data_cached(vehicle)
            
            # ── FORENSIC FAILURE GUARD ──────────────────────────
            db_count = len(listings)
            
            # Risk 3: Explicit Scraper vs DB Assertion
            if scraped_count > 0 and db_count == 0:
                logger.error(f"FORENSIC FAILURE: SCRAPED {scraped_count} BUT DB IS EMPTY")
                raise Exception("FORENSIC FAILURE: Data lost between scraper and SOT repository.")
            
            # Check if cache miss triggered scraping but DB is still empty
            if db_count == 0:
                # If we were in debug mode or had a high expectation, we abort
                # In production forensic architecture, we NEVER proceed with 0 results
                logger.error("FORENSIC FAILURE: DATA LAKE EMPTY")
                raise Exception("FORENSIC DATA FAILURE: No market data found in SOT repository.")
            
            logger.info(f"[FORENSIC READ CONFIRMED] COUNT: {db_count}")
            
            # STEP 3: Clean Data
            logger.info("\n🧹 STEP 3: Cleaning market data...")
            clean_listings = self.data_cleaner.clean_listing_data(listings)
            cleaning_report = self.data_cleaner.get_cleaning_report(
                listings, clean_listings
            )
            logger.info(f"✅ Cleaned: {cleaning_report['cleaned_count']} listings")
            
            if not clean_listings:
                logger.error("FORENSIC FAILURE: No valid listings after cleaning")
                raise ValueError("FORENSIC FAILURE: DATA LAKE records are invalid or empty after cleaning")
            
            # STEP 4: AI Valuation
            logger.info("\n🤖 STEP 4: Running AI valuation...")
            valuation = self.ai_engine.evaluate_vehicle(vehicle, clean_listings)
            logger.info(f"✅ Forensic Price: {valuation['forensic_price']:,} TL")
            
            # STEP 4.1: Deep AI Forensic Narrative (v8.1)
            logger.info("\n🧠 STEP 4.1: Generating Deep AI Forensic Audit...")
            market_stats = {
                "avg": valuation.get('forensic_price', 0),
                "min": min(l['price'] for l in clean_listings),
                "max": max(l['price'] for l in clean_listings),
                "total": len(clean_listings)
            }
            ai_report = await self.ai_service.generate_valuation_report(vehicle, market_stats, clean_listings)
            valuation['ai_audit'] = ai_report
            logger.info("✅ Deep AI Audit completed")
            
            # STEP 5: Opportunity Detection
            logger.info("\n🎯 STEP 5: Detecting opportunities...")
            opportunities = self.opportunity_detector.detect_opportunities(
                clean_listings, valuation['forensic_price']
            )
            logger.info(f"✅ Found {len(opportunities)} opportunities")
            
            # STEP 6: Generate Report
            logger.info("\n📊 STEP 6: Generating reports...")
            report_info = self.report_generator.generate_forensic_report(
                vehicle, clean_listings, valuation, opportunities, cleaning_report
            )
            logger.info(f"✅ Report generated: {report_info['html_path']}")
            
            # STEP 7: Forensic Sealing (Evidence Package)
            logger.info("\n📜 STEP 7: Generating Forensic Evidence Package...")
            case_id = f"CASE-{report_info['report_id'][-8:]}"
            builder = EvidencePackageBuilder(case_id)
            builder.add_manual_input(vehicle)
            # Add valuation and analysis signals
            pkg = builder.compile()
            pkg.normalized_snapshot["forensic_valuation"] = valuation
            
            # Seal the package (Immutable Chain start)
            builder.seal(pkg)
            
            # Vault the package
            vault_path = self.vault.store_record(pkg.to_dict(), vault_key=case_id)
            logger.info(f"✅ Evidence Package sealed and vaulted: {vault_path}")
            
            # STEP 8: Build final result
            result = {
                'status': 'SUCCESS',
                'pipeline_version': 'v7.0',
                'timestamp': datetime.now().isoformat(),
                
                'vehicle': vehicle,
                'valuation': valuation,
                'market_data': {
                    'total_listings': len(clean_listings),
                    'cleaning_report': cleaning_report
                },
                'opportunities': {
                    'count': len(opportunities),
                    'total_profit': sum(o['potential_profit'] for o in opportunities),
                    'top_opportunities': opportunities[:5]
                },
                'reports': report_info
            }
            
            logger.info("\n" + "="*80)
            logger.info("✅ FORENSIC PIPELINE COMPLETED")
            logger.info("="*80)
            
            return result
            
        except Exception as e:
            logger.error(f"Pipeline failed: {e}")
            import traceback
            traceback.print_exc()
            
            return {
                'status': 'FAILED',
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            }

    def _normalize_vehicle(self, vehicle_data: Dict[str, Any]) -> Dict[str, Any]:
        """Normalize and validate vehicle data"""
        
        # Extract and normalize fields
        brand = str(vehicle_data.get('brand', '')).strip().title()
        model = str(vehicle_data.get('model', '')).strip().title()
        year = int(vehicle_data.get('year', 2020))
        km = int(vehicle_data.get('km', 0))
        fuel = str(vehicle_data.get('fuel', 'benzin')).strip().lower()
        transmission = str(vehicle_data.get('transmission', 'otomatik')).strip().lower()
        
        # Validation
        if not brand or not model:
            raise ValueError("Brand and model are required")
        
        _current_year = datetime.now().year
        if not (2010 <= year <= _current_year + 1):
            raise ValueError(f"Invalid year: {year} (must be 2010-{_current_year + 1})")
        
        if km < 0 or km > 500000:
            raise ValueError(f"Invalid KM: {km} (must be 0-500000)")
        
        # Valid fuels
        valid_fuels = ['benzin', 'dizel', 'hibrit', 'elektrik', 'lpg']
        if fuel not in valid_fuels:
            fuel = 'benzin'  # Default
        
        # Valid transmissions
        valid_transmissions = ['otomatik', 'manuel', 'yarı otomatik']
        if transmission not in valid_transmissions:
            transmission = 'otomatik'  # Default
        
        return {
            'brand': brand,
            'model': model,
            'year': year,
            'km': km,
            'fuel': fuel,
            'transmission': transmission
        }


# Singleton instance
_pipeline = None


def get_master_pipeline(debug_mode: bool = False) -> MasterForensicPipeline:
    """Get or create master pipeline instance"""
    global _pipeline
    if _pipeline is None:
        _pipeline = MasterForensicPipeline(debug_mode=debug_mode)
    return _pipeline


# Convenience function for quick usage
async def analyze_vehicle(vehicle_data: Dict[str, Any], 
                         debug_mode: bool = False) -> Dict[str, Any]:
    """
    Quick convenience function to analyze a vehicle
    
    Args:
        vehicle_data: Vehicle information
        debug_mode: Enable debug logging
    
    Returns:
        Complete forensic analysis result
    """
    pipeline = get_master_pipeline(debug_mode=debug_mode)
    return await pipeline.run_forensic_pipeline(vehicle_data)

if __name__ == "__main__":
    import asyncio
    
    test_vehicle = {
        "brand": "Renault",
        "model": "Clio",
        "year": 2017,
        "km": 90000,
        "fuel": "dizel",
        "transmission": "manuel"
    }
    
    print("\n🏛️ [YERIMEBAK AI] PIPELINE TEST RUNNER")
    print("="*60)
    
    async def run_test():
        result = await analyze_vehicle(test_vehicle, debug_mode=True)
        if result['status'] == 'SUCCESS':
            print("\n✅ PIPELINE TEST PASSED")
            print(f"📊 Forensic Price: {result['valuation']['forensic_price']:,} TL")
            print(f"📈 Total Listings: {result['market_data']['total_listings']}")
        else:
            print("\n❌ PIPELINE TEST FAILED")
            print(f"⚠️ Error: {result.get('error')}")
            
    asyncio.run(run_test())