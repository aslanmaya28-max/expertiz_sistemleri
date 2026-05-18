# -*- coding: utf-8 -*-
"""
YERİMEBAK AI - Regional Engine
Aggregation for Market Heatmap
"""
from typing import List, Dict, Any

class RegionalEngine:
    def __init__(self):
        pass

    def aggregate_regional_data(self, listings: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Şehir/İlçe bazlı verileri grupla ve ısı haritası için skor üret
        """
        regions = {}
        
        # Popüler şehirler için satış hızı çarpanları
        speed_multipliers = {
            "İstanbul": 1.4, "Ankara": 1.2, "İzmir": 1.1, "Bursa": 1.05
        }
        
        for item in listings:
            loc = item.get('location', 'Bilinmiyor')
            city = loc.split('/')[0].strip() if '/' in loc else loc
            
            if city not in regions:
                regions[city] = {
                    "count": 0,
                    "avg_price_sum": 0,
                    "sales_speed_score": speed_multipliers.get(city, 1.0) * 60,
                    "demand_score": 50
                }
            
            regions[city]["count"] += 1
            regions[city]["avg_price_sum"] += item.get('price', 0)
            
        # Skorları normalize et
        for city, data in regions.items():
            # count ne kadar fazlaysa talep o kadar yüksektir (0-100 ölçeğinde)
            data["demand_score"] = min(100, data["count"] * 5 + 40)
            data["avg_price"] = data["avg_price_sum"] / data["count"] if data["count"] > 0 else 0
            # Gereksiz alanı sil
            del data["avg_price_sum"]
            
        return regions
