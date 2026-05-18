import pandas as pd
import logging
from typing import Dict, Any
from abc import ABC, abstractmethod
from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)


class DatabaseProvider(ABC):
    @abstractmethod
    def get_all_listings(self) -> pd.DataFrame:
        pass

    @abstractmethod
    def search_listings(self, brand: str, model: str, year: int) -> pd.DataFrame:
        pass

    @abstractmethod
    def get_price_history(self, listing_id: int) -> pd.DataFrame:
        pass

    @abstractmethod
    def get_market_stats(self) -> Dict[str, Any]:
        pass

    @abstractmethod
    def get_db_health(self) -> Dict[str, Any]:
        pass


class PostgreSQLProvider(DatabaseProvider):
    """Single source of truth — PostgreSQL only."""

    def get_all_listings(self) -> pd.DataFrame:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM listings ORDER BY updated_at DESC")
            rows = [dict(row) for row in cursor.fetchall()]
            return pd.DataFrame(rows) if rows else pd.DataFrame()
        finally:
            conn.close()

    def search_listings(self, brand: str, model: str, year: int) -> pd.DataFrame:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT * FROM listings 
                WHERE brand = %s AND model = %s AND year = %s
                ORDER BY updated_at DESC
            """, (brand.lower(), model.lower(), year))
            rows = [dict(row) for row in cursor.fetchall()]
            return pd.DataFrame(rows) if rows else pd.DataFrame()
        finally:
            conn.close()

    def get_price_history(self, listing_id: int) -> pd.DataFrame:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT price, recorded_at FROM price_history 
                WHERE listing_id = %s ORDER BY recorded_at ASC
            """, (listing_id,))
            rows = [dict(row) for row in cursor.fetchall()]
            return pd.DataFrame(rows) if rows else pd.DataFrame()
        finally:
            conn.close()

    def get_market_stats(self) -> Dict[str, Any]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) as total FROM listings")
            total_listings = cursor.fetchone()['total']

            cursor.execute("SELECT COUNT(*) as total FROM listings WHERE created_at > NOW() - INTERVAL '24 hours'")
            listings_24h = cursor.fetchone()['total']

            cursor.execute("SELECT AVG(price) as avg_price, AVG(km) as avg_km FROM listings")
            avg_row = cursor.fetchone()
            avg_price = avg_row['avg_price'] or 0
            avg_km = avg_row['avg_km'] or 0

            return {
                "total_listings": total_listings,
                "listings_24h": listings_24h,
                "avg_price": int(avg_price),
                "avg_km": int(avg_km)
            }
        finally:
            conn.close()

    def get_db_health(self) -> Dict[str, Any]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) as total FROM listings")
            count = cursor.fetchone()['total']

            cursor.execute("SELECT pg_database_size(current_database()) as db_size")
            db_size = cursor.fetchone()['db_size']

            return {
                "size_bytes": db_size,
                "size_mb": round(db_size / (1024 * 1024), 2),
                "total_records": count,
                "provider": "PostgreSQL"
            }
        finally:
            conn.close()


def get_db_service() -> DatabaseProvider:
    return PostgreSQLProvider()