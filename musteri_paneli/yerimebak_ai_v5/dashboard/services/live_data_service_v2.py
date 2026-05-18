"""
Canlı Veri Akış Servisi v2.0 — PostgreSQL Only
Detaylı araç bilgileri ile (boya, hasar, paket, durum)
Single source of truth: PostgreSQL
"""
import json
import logging
from typing import List, Dict, Any

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.core.broadcaster import broadcaster

logger = logging.getLogger(__name__)


class LiveDataServiceV2:
    """Canlı veri akış servisi — PostgreSQL only."""

    def __init__(self, db_path: str = None):
        self._init_database()

    @property
    def _p(self):
        return "%s"

    def _row_to_dict(self, row, cursor):
        if isinstance(row, dict):
            return row
        try:
            return dict(row)
        except (TypeError, ValueError):
            return {desc[0]: row[i] for i, desc in enumerate(cursor.description)}

    def _init_database(self):
        """Delegate schema init to DatabaseConfig.bootstrap() — single source of truth."""
        from yerimebak_ai_v5.core.database_config import DatabaseConfig
        DatabaseConfig.bootstrap()
        DatabaseConfig.alignment()

    def get_market_stats(self) -> Dict[str, Any]:
        """Tüm kaynaklar için market istatistiklerini getirir."""
        stats = {}
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            date_filter = "NOW() - INTERVAL '24 hours'"

            cursor.execute(f"""
                SELECT 
                    source, 
                    COUNT(*) as total,
                    AVG(price) as avg_price,
                    COUNT(CASE WHEN updated_at > {date_filter} THEN 1 END) as daily_total,
                    COUNT(CASE WHEN opportunity_score > 70 AND updated_at > {date_filter} THEN 1 END) as daily_opportunities
                FROM listings
                GROUP BY source
            """)
            rows = cursor.fetchall()
            for row in rows:
                row_dict = self._row_to_dict(row, cursor)
                source = row_dict.get('source') or 'unknown'
                stats[source.lower()] = {
                    "total": row_dict.get('total', 0),
                    "avg_price": row_dict.get('avg_price', 0),
                    "daily_total": row_dict.get('daily_total', 0),
                    "daily_opportunities": row_dict.get('daily_opportunities', 0)
                }
            return stats
        except Exception as e:
            logger.error(f"Error getting market stats: {e}")
            return {}
        finally:
            conn.close()

    def get_active_brands(self) -> List[str]:
        """Veritabanında bulunan aktif markaların listesini getirir."""
        valid_brands = {
            "Renault", "Fiat", "Volkswagen", "Hyundai", "Ford", "Opel", "Dacia", "Peugeot",
            "Citroen", "Seat", "Suzuki", "Nissan", "Toyota", "Honda", "BMW", "Mercedes",
            "Skoda", "Audi", "Mazda", "Subaru", "Volvo", "Lexus", "Cupra", "MG", "Chery", "Togg", "Tesla", "BYD"
        }

        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT brand FROM listings GROUP BY brand")
            rows = cursor.fetchall()
            brands = []
            for row in rows:
                row_dict = self._row_to_dict(row, cursor)
                brand_raw = row_dict.get('brand', '').strip()
                for valid in valid_brands:
                    if brand_raw.lower() == valid.lower():
                        brands.append(valid)
                        break
            return sorted(list(set(brands)))
        except Exception as e:
            logger.error(f"Error getting active brands: {e}")
            return []
        finally:
            conn.close()

    def get_filtered_listings(self, brand: str = None, model: str = None,
                             min_price: int = None, max_price: int = None,
                             limit: int = 100, offset: int = 0) -> List[Dict[str, Any]]:
        """Marka/model/fiyat filtreli sorgu — SQL seviyesinde filtreleme."""
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            conditions = []
            params = []

            if brand and brand != "Tüm Markalar":
                conditions.append(f"LOWER(TRIM(brand)) = LOWER(TRIM({self._p}))")
                params.append(brand.strip())
            if model and model != "Tüm Modeller":
                conditions.append(f"LOWER(TRIM(model)) = LOWER(TRIM({self._p}))")
                params.append(model.strip())
            if min_price is not None:
                conditions.append(f"price >= {self._p}")
                params.append(min_price)
            if max_price is not None:
                conditions.append(f"price <= {self._p}")
                params.append(max_price)

            where_clause = (" WHERE " + " AND ".join(conditions)) if conditions else ""
            params.append(limit)
            params.append(offset)

            cursor.execute(
                f"SELECT * FROM listings{where_clause} ORDER BY updated_at DESC LIMIT {self._p} OFFSET {self._p}",
                tuple(params)
            )
            return [self._row_to_dict(row, cursor) for row in cursor.fetchall()]
        except Exception as e:
            logger.error(f"Error getting filtered listings: {e}")
            return []
        finally:
            conn.close()

    def get_detailed_listings(self, limit: int = 100) -> List[Dict[str, Any]]:
        """Detaylı araç listesini getirir."""
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"SELECT * FROM listings ORDER BY updated_at DESC LIMIT {self._p}", (limit,))
            return [self._row_to_dict(row, cursor) for row in cursor.fetchall()]
        except Exception as e:
            logger.error(f"Error getting detailed listings: {e}")
            return []
        finally:
            conn.close()

    def get_opportunity_vehicles(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Fırsat araçlarını (yüksek skorlu) getirir."""
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                SELECT * FROM listings 
                WHERE opportunity_score > 70 
                ORDER BY opportunity_score DESC, updated_at DESC 
                LIMIT {self._p}
            """, (limit,))
            return [self._row_to_dict(row, cursor) for row in cursor.fetchall()]
        except Exception as e:
            logger.error(f"Error getting opportunity vehicles: {e}")
            return []
        finally:
            conn.close()

    def get_no_accident_vehicles(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Hatasız/Boyasız araçları getirir."""
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                SELECT * FROM listings 
                WHERE (accident_record IS NULL OR accident_record = '' OR accident_record LIKE '%yok%')
                ORDER BY updated_at DESC 
                LIMIT {self._p}
            """, (limit,))
            return [self._row_to_dict(row, cursor) for row in cursor.fetchall()]
        except Exception as e:
            logger.error(f"Error getting no accident vehicles: {e}")
            return []
        finally:
            conn.close()

    def get_no_paint_vehicles(self, limit: int = 50) -> List[Dict[str, Any]]:
        """Boyasız araçları getirir."""
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                SELECT * FROM listings 
                WHERE (paint_info IS NULL OR paint_info = '' OR (paint_info NOT LIKE '%Boyalı%' AND paint_info NOT LIKE '%Lokal%'))
                ORDER BY updated_at DESC 
                LIMIT {self._p}
            """, (limit,))
            return [self._row_to_dict(row, cursor) for row in cursor.fetchall()]
        except Exception as e:
            logger.error(f"Error getting no paint vehicles: {e}")
            return []
        finally:
            conn.close()

    def get_full_package_vehicles(self, limit: int = 50) -> List[Dict[str, Any]]:
        """En dolu paket araçları getirir."""
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(f"""
                SELECT * FROM listings 
                WHERE (package_info LIKE '%Full%' OR package_info LIKE '%Dolu%' OR package_info LIKE '%Premium%')
                ORDER BY updated_at DESC 
                LIMIT {self._p}
            """, (limit,))
            return [self._row_to_dict(row, cursor) for row in cursor.fetchall()]
        except Exception as e:
            logger.error(f"Error getting full package vehicles: {e}")
            return []
        finally:
            conn.close()


# Singleton instance
_instance = None

def get_live_service_v2():
    """LiveDataServiceV2 singleton factory"""
    global _instance
    if _instance is None:
        _instance = LiveDataServiceV2()
    return _instance