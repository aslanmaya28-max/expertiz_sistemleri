from datetime import datetime
import json
import logging
from typing import List, Dict, Any, Optional
from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.core.broadcaster import broadcaster

# Configure Forensic Logging
logger = logging.getLogger(__name__)

class ListingRepository:
    """
    Forensic Repository Layer.
    Enforcing absolute data consistency and persistence.
    """

    _user_requests_ensured = False

    @property
    def _p(self):
        """PostgreSQL parameter placeholder"""
        return "%s"

    def _ensure_user_requests_table(self):
        if ListingRepository._user_requests_ensured:
            return
        ListingRepository._user_requests_ensured = True
        try:
            conn = DatabaseConfig.get_connection()
            try:
                cursor = conn.cursor()
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS user_requests (
                        id SERIAL PRIMARY KEY,
                        brand TEXT,
                        model TEXT,
                        year INTEGER,
                        requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """)
                conn.commit()
            finally:
                # 🔒 DÜZELTİLDİ (Bug #21): conn.close() -> DatabaseConfig.return_connection()
                DatabaseConfig.return_connection(conn)
        except Exception as e:
            logger.warning(f"Could not ensure user_requests table: {e}")

    def _should_cleanup(self) -> bool:
        """Randomized trigger for cleanup to avoid performance hit on every save"""
        import random
        return random.random() < 0.02  # 2% chance per save (approx every 50 saves)

    def save_listing_sync(self, data: Dict[str, Any]) -> int:
        """Synchronous wrapper for save_listing, safe for worker threads."""
        import asyncio
        import sys
        
        # Windows loop policy
        if sys.platform == 'win32':
            try:
                asyncio.get_event_loop()
            except RuntimeError:
                asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())
                
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                return loop.run_until_complete(self.save_listing(data))
            finally:
                loop.close()
        except Exception as e:
            logger.error(f"Error in save_listing_sync: {e}")
            return -1

    async def save_listing(self, data: Dict[str, Any]) -> int:
        """
        Forensic Insert/Update with AI Orchestration.
        """
        url = data.get('url')
        if not url:
            return -1

        # ── NORMALIZATION LAYER INTEGRATION (v5.3) ──────────────────────
        try:
            from yerimebak_ai_v5.core.normalization import NormalizationLayer
            data = NormalizationLayer.normalize_vehicle(data)
        except Exception as e:
            logger.warning(f"Normalization failed: {e}")

        # ── AI ORCHESTRATION INTEGRATION (v6.1) ──────────────────────
        # Eğer veri içinde AI skorları yoksa ve market_avg varsa orkestratörü çalıştır
        if 'opportunity_score' not in data or data.get('opportunity_score') is None:
            try:
                from yerimebak_ai_v5.core.ai_orchestrator import ai_orchestrator
                from yerimebak_ai_v5.core.market_reference_service import get_market_reference_service
                # Market ortalamasını basitçe hesapla veya varsayılan al
                market_reference = get_market_reference_service().get_reference(
                    brand=str(data.get('brand') or ''),
                    model=str(data.get('model') or ''),
                    year=data.get('year'),
                    km=data.get('km'),
                    fuel=data.get('fuel_type') or data.get('fuel'),
                    transmission=data.get('gear_type') or data.get('transmission'),
                    listed_price=data.get('price'),
                )
                market_avg = data.get('market_avg') or market_reference.get('market_avg_price') or data.get('price', 0)
                data['market_reference'] = market_reference
                data = await ai_orchestrator.process_listing_async(data, market_avg)
            except Exception as e:
                import traceback
                logger.warning(f"AI Orchestration failed during save: {e}\n{traceback.format_exc()}")

        # Extract normalized fields
        brand = data.get('brand')
        series = data.get('series')
        model = data.get('model')
        year = data.get('year')
        price = data.get('price')
        km = data.get('km')
        fuel_type = data.get('fuel_type') or data.get('fuel') or ''
        gear_type = data.get('gear_type') or data.get('transmission') or ''
        body_type = data.get('body_type')
        source = data.get('source')
        guarantee = data.get('guarantee')

        # KRİTİK: PaintInfo ve PackageInfo Pydantic modellerini düzgün serialize et
        paint_info_raw = data.get('paint_info')
        if paint_info_raw:
            if hasattr(paint_info_raw, 'dict'):
                paint_info_json = json.dumps(paint_info_raw.dict(), ensure_ascii=False)
            elif hasattr(paint_info_raw, 'model_dump'):
                paint_info_json = json.dumps(paint_info_raw.model_dump(), ensure_ascii=False)
            else:
                paint_info_json = json.dumps(paint_info_raw, ensure_ascii=False)
        else:
            paint_info_json = None

        package_info_raw = data.get('package_info')
        if package_info_raw:
            if hasattr(package_info_raw, 'dict'):
                package_info_json = json.dumps(package_info_raw.dict(), ensure_ascii=False)
            elif hasattr(package_info_raw, 'model_dump'):
                package_info_json = json.dumps(package_info_raw.model_dump(), ensure_ascii=False)
            else:
                package_info_json = json.dumps(package_info_raw, ensure_ascii=False)
        else:
            package_info_json = None

        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT id FROM listings WHERE url = {self._p}", (url,))
            existing = cursor.fetchone()

            if existing:
                listing_id = existing['id']
                cursor.execute(f"""
                    UPDATE listings
                    SET price = {self._p}, km = {self._p}, fuel = {self._p}, transmission = {self._p},
                        fuel_type = {self._p},
                        body_type = {self._p}, color = {self._p}, paint_info = {self._p}, 
                        accident_record = {self._p}, package_info = {self._p}, title = {self._p}, 
                        image_url = {self._p}, location = {self._p}, listing_date = {self._p},
                        risk_score = {self._p}, opportunity_score = {self._p}, 
                        predicted_future_price = {self._p}, vision_condition_score = {self._p},
                        vision_analysis_report = {self._p}, action_recommendation = {self._p},
                        buy_price_min = {self._p}, buy_price_max = {self._p},
                        predicted_profit_tl = {self._p}, predicted_profit_pct = {self._p},
                        engine_size = {self._p}, horsepower = {self._p}, series = {self._p},
                        description = {self._p}, guarantee = {self._p},
                        updated_at = CURRENT_TIMESTAMP
                    WHERE id = {self._p}
                """, (
                    price, km, fuel_type, gear_type,
                    fuel_type, body_type,
                    data.get('color'), paint_info_json, data.get('accident_record'),
                    package_info_json, data.get('title'), data.get('image_url'),
                    data.get('location'), data.get('listing_date'),
                    data.get('risk_score'), data.get('opportunity_score'),
                    data.get('predicted_future_price'), data.get('vision_condition_score'),
                    data.get('vision_analysis_report'), data.get('action_recommendation'),
                    data.get('buy_price_min'), data.get('buy_price_max'),
                    data.get('predicted_profit_tl'), data.get('predicted_profit_pct'),
                    data.get('engine_size'), data.get('horsepower'), series,
                    data.get('description'), guarantee,
                    listing_id
                ))
            else:
                cursor.execute(f"""
                    INSERT INTO listings (
                        brand, series, model, year, price, km, fuel, transmission,
                        fuel_type,
                        body_type, source, url, color, paint_info, accident_record,
                        package_info, title, image_url, location, listing_date,
                        risk_score, opportunity_score, predicted_future_price,
                        vision_condition_score, vision_analysis_report,
                        action_recommendation, buy_price_min, buy_price_max,
                        predicted_profit_tl, predicted_profit_pct,
                        engine_size, horsepower, description, guarantee
                    ) VALUES (
                        {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, 
                        {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, 
                        {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, 
                        {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, 
                        {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, 
                        {self._p}, {self._p}, {self._p}, {self._p}, {self._p}, 
                        {self._p}, {self._p}, {self._p}, {self._p}
                    ) RETURNING id
                """, (
                    brand, series, model, year, price, km, fuel_type, gear_type,
                    fuel_type,
                    body_type, source, url, data.get('color'), paint_info_json, 
                    data.get('accident_record'), package_info_json, data.get('title'), 
                    data.get('image_url'), data.get('location'), data.get('listing_date'),
                    data.get('risk_score'), data.get('opportunity_score'),
                    data.get('predicted_future_price'), data.get('vision_condition_score'),
                    data.get('vision_analysis_report'), data.get('action_recommendation'),
                    data.get('buy_price_min'), data.get('buy_price_max'),
                    data.get('predicted_profit_tl'), data.get('predicted_profit_pct'),
                    data.get('engine_size'), data.get('horsepower'), data.get('description'), guarantee
                ))
                listing_id = cursor.fetchone()['id']

            conn.commit()
            
            # Broadcast new/update listing
            try:
                if not hasattr(self, '_live_service'):
                    try:
                        from yerimebak_ai_v5.dashboard.services.live_data_service_v2 import LiveDataServiceV2
                        self._live_service = LiveDataServiceV2()
                    except ImportError:
                        self._live_service = None
                
                broadcast_data = {
                    "type": "new_listing" if not existing else "update_listing",
                    "data": {
                        "id": listing_id,
                        "brand": brand,
                        "model": model,
                        "price": price,
                        "source": data.get('source'),
                        "opportunity_score": data.get('opportunity_score')
                    }
                }
                # Firestore/WebSocket broadcast
                import asyncio
                asyncio.create_task(broadcaster.broadcast(broadcast_data))
            except Exception as be:
                logger.warning(f"Broadcast failed: {be}")

            # ── DATA RETENTION POLICY (v5.5) ───────────────────────────
            if self._should_cleanup():
                try:
                    import asyncio
                    asyncio.create_task(self.cleanup_old_listings(days=24))
                except Exception as ce:
                    logger.warning(f"Cleanup trigger failed: {ce}")

            return listing_id
        finally:
            DatabaseConfig.return_connection(conn)

    async def get_listings(self, brand: Optional[str] = None, model: Optional[str] = None, year: Optional[int] = None, source: Optional[str] = None, limit: int = 100) -> List[Dict[str, Any]]:
        """
        Forensic Read with filters and limit.
        """
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            
            query = "SELECT * FROM listings WHERE 1=1"
            params = []
            
            if brand:
                query += f" AND brand = {self._p}"
                params.append(brand.lower().strip())
            
            if model:
                query += f" AND model = {self._p}"
                params.append(model.lower().strip())
                
            if year:
                query += f" AND year = {self._p}"
                params.append(year)
                
            if source:
                query += f" AND source = {self._p}"
                params.append(source.lower().strip())
                
            query += f" ORDER BY updated_at DESC LIMIT {self._p}"
            params.append(limit)
            
            cursor.execute(query, tuple(params))
            
            rows = [dict(row) for row in cursor.fetchall()]
            
            # Forensic Read Log
            logger.info(f"[FORENSIC READ CONFIRMED] COUNT: {len(rows)}")
            
            return rows
        finally:
            DatabaseConfig.return_connection(conn)

    async def get_market_data(self, brand: str, model: str, year: int) -> List[Dict[str, Any]]:
        """Alias for get_listings"""
        return await self.get_listings(brand, model, year)

    async def log_valuation(self, data: Dict[str, Any]):
        """Log an AI valuation"""
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                INSERT INTO valuation_history (
                    vehicle_brand, vehicle_model, vehicle_year, actual_price, ai_price, confidence
                ) VALUES ({self._p}, {self._p}, {self._p}, {self._p}, {self._p}, {self._p})
            """, (
                data.get('brand'), data.get('model'), data.get('year'),
                data.get('actual_price'), data.get('ai_price'), data.get('confidence')
            ))
            conn.commit()
            logger.info("[FORENSIC VALUATION LOGGED]")
        finally:
            DatabaseConfig.return_connection(conn)

    def log_user_request(self, brand: str, model: str, year: int):
        """Log a user search request for later analysis"""
        self._ensure_user_requests_table()
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                INSERT INTO user_requests (brand, model, year, requested_at)
                VALUES ({self._p}, {self._p}, {self._p}, CURRENT_TIMESTAMP)
            """, (brand.lower(), model.lower(), year))
            conn.commit()
        except Exception as e:
            logger.warning(f"Could not log user request: {e}")
        finally:
            DatabaseConfig.return_connection(conn)

    async def cleanup_old_listings(self, days: int = 24):
        """
        PERMANENT CLEANUP: Delete listings and price history older than 'days'.
        Keeps the database fresh and fast.
        """
        logger.info(f"[FORENSIC CLEANUP] Starting TTL cleanup (Threshold: {days} days)")
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            p = self._p
            
            date_filter = f"updated_at < NOW() - INTERVAL '{days} days'"
            
            cursor.execute(f"""
                DELETE FROM price_history 
                WHERE listing_id IN (
                    SELECT id FROM listings 
                    WHERE {date_filter}
                )
            """)
            
            cursor.execute(f"DELETE FROM listings WHERE {date_filter}")
            
            conn.commit()
            logger.info("[FORENSIC CLEANUP] Finished. 24-day retention policy applied.")
        except Exception as e:
            logger.error(f"[FORENSIC CLEANUP FAILURE] {e}")
        finally:
            DatabaseConfig.return_connection(conn)

    async def get_market_statistics(self, brand: str, model: str, year: int) -> Dict[str, Any]:
        """
        Market Awareness: Get min/max/avg prices from the existing database.
        """
        conn = None
        stats = {
            'min_price': 0,
            'max_price': 0,
            'avg_price': 0,
            'count': 0
        }
        try:
            conn = DatabaseConfig.get_connection()
            cursor = conn.cursor()
            query = f"""
                SELECT MIN(price) as min_p, MAX(price) as max_p, AVG(price) as avg_p, COUNT(*) as cnt
                FROM listings
                WHERE brand = {self._p} AND model = {self._p} AND year = {self._p}
            """
            # 🔒 DÜZELTİLDİ: get_listings() ile tutarlılık için lowercase kullan
            cursor.execute(query, ((brand or '').lower().strip(), (model or '').lower().strip(), year))
            row = cursor.fetchone()
            if row and row['cnt'] > 0:
                stats = {
                    'min_price': int(row['min_p'] or 0),
                    'max_price': int(row['max_p'] or 0),
                    'avg_price': int(row['avg_p'] or 0),
                    'count': row['cnt']
                }
            return stats
        except Exception as e:
            logger.warning(f"Market stats lookup failed: {e}")
            return stats
        finally:
            if conn is not None:
                DatabaseConfig.return_connection(conn)

# Singleton instance for high-efficiency forensic access
_repository = None

def get_repository():
    global _repository
    if _repository is None:
        _repository = ListingRepository()
    return _repository
