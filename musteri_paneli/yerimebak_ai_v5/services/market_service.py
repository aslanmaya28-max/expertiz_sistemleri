import asyncio
from typing import Dict, List, Any
from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.dashboard.services.analiz_service import get_analiz_servisi

class MarketIntelligenceService:
    """
    Market Intelligence Engine (Market Engine).
    Veritabanındaki gerçek ilanları analiz ederek 'Adil Piyasa Değeri' (FMV) üretir.
    """

    def __init__(self):
        self.valuation_engine = get_analiz_servisi()

    async def analyze_market(self, vehicle_info: Dict[str, Any]) -> Dict[str, Any]:
        """
        Gerçek veritabanı üzerinden çok kaynaklı pazar analizi yapar.
        """
        brand = vehicle_info.get("brand", "")
        model = vehicle_info.get("model", "")
        year = int(vehicle_info.get("year", 2020))
        km = int(vehicle_info.get("km", 80000))
        
        # 1. Gerçek Pazar Verilerini Çek (AnalizServisi üzerinden)
        market_res = self.valuation_engine.search_market(brand, model, year, km)
        stats = market_res.get("stats", {})
        listings = market_res.get("listings", [])
        
        # 2. Değerleme Algoritmasını Çalıştır (DKK - Değer Kaybı Katsayısı)
        valuation = self.valuation_engine.hesapla_deger_kaybi(
            brand=brand,
            model=model,
            year=year,
            km=km,
            degisen_parcalar=vehicle_info.get("degisen", []),
            boyali_parcalar=vehicle_info.get("boyali", []),
            tramer_bedeli=vehicle_info.get("tramer", 0),
            piyasa_ortalamasi=stats.get("avg", 0)
        )
        
        # 3. Sonuçları Paketle
        avg_price = stats.get("avg", valuation["hesaplanan_fiyat"])
        
        return {
            "market_summary": {
                "average_price": avg_price,
                "min_price": stats.get("min", avg_price * 0.9),
                "max_price": stats.get("max", avg_price * 1.1),
                "total_listings_analyzed": stats.get("total", 0),
                "source_type": market_res.get("source", "inference"),
                "confidence_score": 90 if stats.get("total", 0) > 5 else 65
            },
            "valuation": {
                "fair_market_value": valuation["hesaplanan_fiyat"],
                "depreciation_rate": valuation["dkk"],
                "base_market_ref": valuation["baz_fiyat"]
            },
            "listings": listings[:10],
            "ai_verdict": self._generate_verdict(valuation["hesaplanan_fiyat"], avg_price)
        }

    def _generate_verdict(self, my_value: float, avg_market: float) -> str:
        if avg_market == 0: return "Veri yetersiz."
        
        ratio = my_value / avg_market
        if ratio < 0.9:
            return "Bu araç piyasa ortalamasının çok altında bir kondisyona sahip veya çok hesaplı."
        elif ratio > 1.1:
            return "Bu araç piyasasına göre oldukça kıymetli/temiz bir konumda."
        else:
            return "Araç tam olarak adil piyasa değerinde."

# Singleton
_market_service = MarketIntelligenceService()

def get_market_intelligence_service():
    return _market_service
