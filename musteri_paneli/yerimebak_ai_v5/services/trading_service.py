import logging
from typing import List, Dict, Any
from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)

class TradingService:
    """
    Arbitraj ve Ticari Analiz Servisi (Wealth Engine).
    Pazar değeri ile ilan fiyatı arasındaki farkı (Kâr Marjı) analiz eder.
    """

    def get_arbitrage_opportunities(self, limit: int = 20) -> List[Dict[str, Any]]:
        """
        En yüksek kâr potansiyeli olan araçları (Arbitraj Fırsatları) getirir.
        Kriter: (Pazar Ortalaması - İlan Fiyatı)
        """
        # 🔒 DÜZELTİLDİ: SQLite json_extract() -> PostgreSQL JSON operatörleri
        # 🔒 DÜZELTİLDİ: SQLite ? placeholder -> PostgreSQL %s
        # 🔒 DÜZELTİLDİ: conn.close() kaldirildi (connection pool kullaniliyor)
        try:
            conn = DatabaseConfig.get_connection()
            cursor = conn.cursor()
            
            query = """
                SELECT brand, model, year, price, km, source, url, 
                       paint_info, accident_record, color,
                       (price * 1.0) as listing_price,
                       COALESCE(
                           CAST(paint_info::json->>'market_avg' AS NUMERIC),
                           price * 1.1
                       ) as fmv
                FROM listings
                WHERE price > 50000
                ORDER BY (fmv - price) DESC
                LIMIT %s
            """
            
            cursor.execute(query, (limit,))
            rows = cursor.fetchall()
            cols = ["brand", "model", "year", "price", "km", "source", "url", 
                    "paint_info", "accident_record", "color", "listing_price", "fmv"]
            
            opportunities = []
            for r in rows:
                item = dict(zip(cols, r))
                item["profit"] = item["fmv"] - item["listing_price"]
                item["profit_pct"] = round((item["profit"] / item["listing_price"]) * 100, 1) if item["listing_price"] > 0 else 0
                opportunities.append(item)
                
            return opportunities
        except Exception as e:
            logger.error(f"Arbitraj sorgusu hatasi: {e}")
            return []

    def calculate_trade_score(self, vehicle_data: Dict[str, Any], market_avg: float) -> Dict[str, Any]:
        """
        Bir araç için ticari 'Al-Sat' skoru üretir.
        """
        price = vehicle_data.get("price", 0)
        if price == 0 or market_avg == 0:
            return {"score": 0, "verdict": "Veri Yetersiz"}
            
        profit = market_avg - price
        profit_pct = (profit / price) * 100
        
        if profit_pct > 15:
            score = 95
            verdict = "KAÇIRILMAZ FIRSAT (Arbitraj)"
        elif profit_pct > 8:
            score = 80
            verdict = "MAKUL YATIRIM"
        elif profit_pct > 0:
            score = 60
            verdict = "PİYASASINDA"
        else:
            score = 30
            verdict = "PAHALI / RİSKLİ"
            
        return {
            "score": score,
            "potential_profit": profit,
            "profit_pct": round(profit_pct, 1),
            "verdict": verdict
        }

# Singleton
_trading_service = TradingService()

def get_trading_service():
    return _trading_service
