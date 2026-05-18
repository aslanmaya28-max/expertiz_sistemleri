# -*- coding: utf-8 -*-
"""
YERİMEBAK AI - Data Refresher Tool
Re-calculates AI metrics for all legacy records in the database.
"""
import sys
import os
import json
from datetime import datetime

# Path setup
_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
if _root not in sys.path:
    sys.path.insert(0, _root)

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.core.ai_orchestrator import ai_orchestrator
from yerimebak_ai_v5.core.market_reference_service import get_market_reference_service

def refresh_all_listings():
    print("🔄 [DataRefresher] Eski veriler AI motorlarından geçiriliyor...")
    
    conn = DatabaseConfig.get_connection()
    cursor = conn.cursor()
    
    # 1. Tüm araçları çek
    cursor.execute("SELECT * FROM listings")
    cols = [column[0] for column in cursor.description]
    rows = cursor.fetchall()
    
    total = len(rows)
    updated = 0
    
    # 2. Piyasa ortalaması için basit bir harita oluştur (Grup bazlı)
    # Bu adımı basitleştirmek için marka/model/yıl bazlı ortalama hesaplayalım
    market_reference_service = get_market_reference_service()
    
    # 3. Her birini işle ve güncelle
    for row in rows:
        item = dict(zip(cols, row))
        market_reference = market_reference_service.get_reference(
            brand=str(item.get('brand') or ''),
            model=str(item.get('model') or ''),
            year=item.get('year'),
            km=item.get('km'),
            fuel=item.get('fuel_type') or item.get('fuel'),
            transmission=item.get('gear_type') or item.get('transmission'),
            exclude_id=item.get('id'),
            listed_price=item.get('price'),
        )
        market_avg = market_reference.get('market_avg_price') or item.get('market_avg_price') or item.get('price') or 0
        item['market_reference'] = market_reference
        
        # AI Orkestrasyonu
        processed = ai_orchestrator.process_listing(item, market_avg)
        
        # DB Güncelle
        cursor.execute("""
            UPDATE listings SET
                risk_score = %s,
                opportunity_score = %s,
                predicted_future_price = %s,
                vision_condition_score = %s,
                vision_analysis_report = %s,
                action_recommendation = %s,
                buy_price_min = %s,
                buy_price_max = %s,
                predicted_profit_tl = %s,
                predicted_profit_pct = %s,
                scraped_at = CURRENT_TIMESTAMP,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
        """, (
            processed.get('risk_score'),
            processed.get('opportunity_score'),
            processed.get('predicted_future_price'),
            processed.get('vision_condition_score'),
            processed.get('vision_analysis_report'),
            processed.get('action_recommendation'),
            processed.get('buy_price_min'),
            processed.get('buy_price_max'),
            processed.get('predicted_profit_tl'),
            processed.get('predicted_profit_pct'),
            item['id']
        ))
        updated += 1
        if updated % 50 == 0:
            print(f"   ✅ {updated}/{total} araç güncellendi...")
    
    conn.commit()
    conn.close()
    print(f"✨ [DataRefresher] TAMAMLANDI: {updated} araç AI v6.1 standartlarına yükseltildi.")

if __name__ == "__main__":
    refresh_all_listings()
