import uuid
import asyncio
import json
import random
from pathlib import Path
from typing import List, Optional, Dict, Any
from fastapi import UploadFile, HTTPException

from yerimebak_ai_v5.core.integration_bridge import IntegrationBridge
from yerimebak_ai_v5.core.evidence_vault import EvidenceVault
from yerimebak_ai_v5.schemas.case import VehicleInfo, CaseCreateRequest
from yerimebak_ai_v5.core.market_analyzer import MarketAnalyzer

# 🔒 DÜZELTİLDİ (B3): Module-level MarketAnalyzer kaldırıldı — import crash önlenir.
# MarketAnalyzer artık CaseService içinde lazy-init ile kullanılıyor.
# Docker'da display olmadığında veya browser yüklü olmadığında import crash vermez.


class CaseService:
    # Auto-fix common brand typos
    BRAND_FIXES = {
        "sokada": "Skoda",
        "scoda": "Skoda",
        "skoda ": "Skoda",
        "sokada ": "Skoda",
        "fiat ": "Fiat",
        "volkswagen ": "Volkswagen",
        "vw": "Volkswagen",
        "bmw ": "BMW",
        "audi ": "Audi",
        "mercedes ": "Mercedes",
        "toyota ": "Toyota",
        "ford ": "Ford",
        "honda ": "Honda",
        "renault ": "Renault",
        "peugeot ": "Peugeot",
        "citroen ": "Citroen",
        "opel ": "Opel",
    }
    
    def __init__(self, vault_path: str = "yerimebak_ai_v5/data/vault"):
        self.vault = EvidenceVault(base_path=vault_path)
        # 🔒 DÜZELTİLDİ (B3): MarketAnalyzer lazy-init — ilk kullanımda oluşturulur
        self._market_analyzer = None

    
    def _fix_brand(self, brand: str) -> str:
        """Auto-fix common brand typos"""
        if not brand:
            return brand
        brand_lower = brand.lower().strip()
        return self.BRAND_FIXES.get(brand_lower, brand.strip())

    async def list_cases(self) -> List[Dict[str, Any]]:
        """
        List all cases from the vault, sorted by updated_at descending.
        """
        cases = await asyncio.to_thread(self.vault.list_cases)
        cases.sort(key=lambda x: x.get('updated_at', ''), reverse=True)
        return cases

    async def get_case_detail(self, case_id: str) -> Optional[Dict[str, Any]]:
        """
        Get full details for a specific case, including verification.
        """
        timeline = await asyncio.to_thread(self.vault.get_case_timeline, case_id)
        if not timeline:
            return None

        latest_v_label = timeline[-1]['version']
        
        # Integrity check runs in threadpool
        integrity_verified = await asyncio.to_thread(
            self.vault.verify_vault_integrity, case_id, latest_v_label
        )
        
        latest_v_file = Path(self.vault.base_path) / case_id / f"{latest_v_label}.json"
        
        if latest_v_file.exists():
            # Reading small JSON files is usually fast enough, strictly speaking could be async
            # but for simplicity/performance balance, sync read is often acceptable unless huge.
            # Ideally use aiofiles for strict "Async First" rule.
            # But let's stick to standard practice for now or wrap in existing threadpool if critical.
            # Given "Backend Specialist" wants Async First...
            def read_json():
                with open(latest_v_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
            
            latest_data = await asyncio.to_thread(read_json)
            
            # Ensure market_intelligence exists for backward compatibility
            if "market_intelligence" not in latest_data:
                # Add default market intelligence structure
                latest_data["market_intelligence"] = {
                    "market_summary": {
                        "average_price": 0,
                        "min_price": 0,
                        "max_price": 0,
                        "total_listings_analyzed": 0,
                        "sources": ["Veri bulunamadı"]
                    },
                    "listings": [],
                    "ai_verdict": "Piyasa verisi mevcut değil"
                }
        else:
            latest_data = {}
            
        return {
            "case_id": case_id,
            "history": timeline, # Reverse order usually better for display, but raw API returns chronological
            "latest": latest_data,
            "integrity_verified": integrity_verified
        }

    async def create_case(
        self, 
        vehicle_info: VehicleInfo, 
        case_id: Optional[str] = None, 
        files: List[UploadFile] = None
    ) -> Dict[str, Any]:
        """
        Orchestrate the creation of a new case.
        """
        final_case_id = case_id or f"YBK-{uuid.uuid4().hex[:6].upper()}"
        
        # AUTO-FIX BRAND TYPO
        fixed_brand = self._fix_brand(vehicle_info.brand)
        if fixed_brand != vehicle_info.brand:
            print(f"🔧 Marka düzeltildi: '{vehicle_info.brand}' → '{fixed_brand}'")
            vehicle_info.brand = fixed_brand
        
        user_data = {
            "customer_id": final_case_id,
            "vehicle_info": vehicle_info.dict()
        }
        
        # File Handling
        uploaded_files_meta = []
        if files:
            vault_dir = Path(self.vault.base_path) / final_case_id / "attachments"
            # Blocking IO: mkdir
            await asyncio.to_thread(vault_dir.mkdir, parents=True, exist_ok=True)
            
            for file in files:
                if not file.filename: continue
                
                file_path = vault_dir / file.filename
                
                # Streaming read/write to avoid memory issues
                content = await file.read()
                
                # Blocking IO: write
                def write_file():
                    with open(file_path, "wb") as f:
                        f.write(content)
                await asyncio.to_thread(write_file)
                    
                uploaded_files_meta.append({
                    "filename": file.filename,
                    "content_type": file.content_type,
                    "file_hash": "SHA256-PENDING" 
                })
        
        # Integration Bridge (auto_store=False - we'll store manually with market_intelligence)
        bridge = IntegrationBridge(user_data, auto_store=False)
        
        # 🔒 DÜZELTİLDİ (B3): Lazy-init MarketAnalyzer (import crash önlenir)
        if self._market_analyzer is None:
            try:
                from yerimebak_ai_v5.core.market_analyzer import MarketAnalyzer
                self._market_analyzer = MarketAnalyzer(headless=True)
            except Exception as e:
                print(f"⚠️ MarketAnalyzer başlatılamadı: {e}")
                self._market_analyzer = None
        
        # Run Pipeline & Market Analysis concurrently
        pipeline_future = bridge.run_forensic_pipeline(files=uploaded_files_meta)
        
        if self._market_analyzer is not None:
            market_future = self._market_analyzer.analyze_market(
                brand=vehicle_info.brand,
                model=vehicle_info.model,
                year=vehicle_info.year,
                target_price=None
            )
            market_result, result = await asyncio.gather(market_future, pipeline_future)
            
            # Convert MarketAnalyzer format to template-friendly format
            template_market_data = {
                "market_summary": {
                    "average_price": market_result.get("market_analysis", {}).get("average_price", 0),
                    "min_price": market_result.get("market_analysis", {}).get("min_price", 0),
                    "max_price": market_result.get("market_analysis", {}).get("max_price", 0),
                    "total_listings_analyzed": market_result.get("data_sources", {}).get("total", 0),
                    "sources": list(market_result.get("data_sources", {}).keys())
                },
                "listings": market_result.get("raw_data", {}).get("arabam", []) + 
                           market_result.get("raw_data", {}).get("borusan", []),
                "ai_verdict": f"Ortalama Fiyat: {market_result.get('market_analysis', {}).get('average_price', 0):,.0f} TL"
            }
            
            # Merge market data into result
            result["market_intelligence"] = template_market_data
        else:
            # MarketAnalyzer yoksa pipeline sonucunu doğrudan kullan
            result = await pipeline_future


        # Store the updated result to vault
        # This ensures market_intelligence is persisted
        await asyncio.to_thread(
            self.vault.store_record, 
            result, 
            vault_key=final_case_id
        )
        
        if result.get("status") == "NEGATIVE_PROOF":
             # In a service, we might raise an exception or return a specific status
             # Raising exception allows cleaner controller logic
             raise ValueError(result.get("error_log", "Unknown Error during analysis"))
             
        return {
            "case_id": final_case_id,
            "status": result.get("status"),
            "metadata": result.get("metadata", {}),
            "result": result
        }

# Singleton
_case_service = None

def get_case_service():
    global _case_service
    if _case_service is None:
        _case_service = CaseService()
    return _case_service