# -*- coding: utf-8 -*-
"""
YERİMEBAK AI - AI Orchestrator
Coordinates all specialized AI engines
"""
from typing import Dict, Any, List, Optional
from yerimebak_ai_v5.core.opportunity_engine import OpportunityEngine
from yerimebak_ai_v5.core.prediction_engine import PredictionEngine
from yerimebak_ai_v5.core.vision_engine import VisionEngine
from yerimebak_ai_v5.core.regional_engine import RegionalEngine
from yerimebak_ai_v5.core.engine_v8 import YerimebakEngineV8, VehicleData
from yerimebak_ai_v5.core.repository import get_repository
from yerimebak_ai_v5.core.market_reference_service import get_market_reference_service

class AIOrchestrator:
    def __init__(self):
        self.opportunity_engine = OpportunityEngine()
        self.prediction_engine = PredictionEngine()
        self.vision_engine = VisionEngine()
        self.regional_engine = RegionalEngine()
        self.engine_v8 = YerimebakEngineV8(verbose=False)

    async def process_listing_async(self, item: Dict[str, Any], market_avg: float = 0) -> Dict[str, Any]:
        """
        Bir ilanı tüm AI motorlarından geçir ve sonuçları birleştir.
        Piyasa bağlamını (Market Context) depodan çekerek analizi güçlendirir.
        """
        repo = get_repository()
        
        # 0. Market Context Lookup (NEW v5.6)
        brand = item.get('brand', '')
        model = item.get('model', '')
        year = item.get('year', 0)
        km = item.get('km', 0)

        market_reference = get_market_reference_service().get_reference(
            brand=brand,
            model=model,
            year=year,
            km=km,
            fuel=item.get('fuel_type') or item.get('fuel'),
            transmission=item.get('gear_type') or item.get('transmission'),
            exclude_id=item.get('id'),
            listed_price=item.get('price'),
        )

        if market_reference.get('found'):
            market_avg = market_reference['market_avg_price']
            item['market_reference'] = market_reference
        
        market_stats = await repo.get_market_statistics(brand, model, year)
        
        # Eğer depoda veri varsa ve dışarıdan gelen market_avg 0 ise depodakini kullan
        if market_stats['count'] > 0:
            if market_avg <= 0:
                market_avg = market_stats['avg_price']
            
            # AI Analizine bağlam ekle
            item['market_context'] = market_stats
        
        # 1. Vision Analizi
        vision_result = self.vision_engine.analyze_photos(
            item.get('photo_urls', []), 
            item.get('description', '')
        )
        item.update(vision_result)

        # 2. Gelecek Fiyat Tahmini
        future_price = self.prediction_engine.predict_future_price(item['price'])
        item['predicted_future_price'] = future_price

        # 3. v8.0 Derin Analiz (KRİTİK GÜNCELLEME)
        # Boya ve değişen verilerini hazırla
        paint_info = item.get('paint_info', {})
        if hasattr(paint_info, 'dict'): paint_info = paint_info.dict()
        
        changed_parts = paint_info.get('changed_parts', []) if isinstance(paint_info, dict) else []
        painted_parts = paint_info.get('painted_parts', []) if isinstance(paint_info, dict) else []
        
        vehicle = VehicleData(
            make_model=f"{item.get('brand', '')} {item.get('model', '')}",
            year=item.get('year', 2020),
            mileage_km=item.get('km', 0),
            fuel_type=item.get('fuel', 'Bilinmiyor'),
            gear_type=item.get('transmission', 'Bilinmiyor'),
            listed_price=float(item.get('price', 0)),
            market_price_avg=float(market_avg),
            damage_level=item.get('accident_record') or 'NONE',
            bodywork_status=changed_parts + painted_parts
        )
        
        from dataclasses import asdict
        v8_valuation = self.engine_v8.analyze(vehicle)
        
        # Sonuçları item'a map et
        item['opportunity_score'] = v8_valuation.technical_scoring.opportunity_score
        item['risk_score'] = v8_valuation.technical_scoring.risk_percentage
        item['action_recommendation'] = v8_valuation.dealer_verdict.decision
        item['buy_price_min'] = v8_valuation.commercial_analysis.optimal_purchase_price
        item['buy_price_max'] = v8_valuation.commercial_analysis.optimal_purchase_price
        item['predicted_profit_tl'] = v8_valuation.commercial_analysis.net_profit_tl
        item['predicted_profit_pct'] = v8_valuation.commercial_analysis.net_margin_percent

        # v8.0 Tam veri paketini de ekle (Dashboard detaylı gösterim için)
        item['valuation_v8'] = asdict(v8_valuation)

        return item

    def process_listing(self, item: Dict[str, Any], market_avg: float) -> Dict[str, Any]:
        """Synchronous version (deprecated, uses event loop)"""
        import asyncio
        import sys
        
        if sys.platform == 'win32':
            asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
            
        loop = asyncio.get_event_loop()
        return loop.run_until_complete(self.process_listing_async(item, market_avg))

    def get_regional_heatmap(self, listings: List[Dict[str, Any]]) -> Dict[str, Any]:
        return self.regional_engine.aggregate_regional_data(listings)

    async def process_listing_async_wrapper(self, item: Dict[str, Any], market_avg: float) -> Dict[str, Any]:
        """Helper for background tasks"""
        return await self.process_listing_async(item, market_avg)

# Singleton
ai_orchestrator = AIOrchestrator()
