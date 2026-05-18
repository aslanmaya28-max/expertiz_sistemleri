import threading
import logging
from contextlib import contextmanager
from typing import Generator

logger = logging.getLogger(__name__)

try:
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
except ImportError:
    from core.database_config import DatabaseConfig


class DatabaseManager:
    """PostgreSQL-only Database Manager. Single source of truth."""
    _instance = None
    _lock = threading.Lock()

    def __init__(self):
        self.local_storage = threading.local()
        self._initialize_db()

    @classmethod
    def get_instance(cls):
        with cls._lock:
            if cls._instance is None:
                cls._instance = cls()
            return cls._instance

    def _get_connection(self):
        if not hasattr(self.local_storage, "connection"):
            self.local_storage.connection = DatabaseConfig.get_connection()
        return self.local_storage.connection

    @contextmanager
    def get_connection(self):
        """Context manager that yields a PostgreSQL connection."""
        conn = DatabaseConfig.get_connection()
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    @contextmanager
    def get_cursor(self):
        conn = self._get_connection()
        cursor = conn.cursor()
        try:
            yield cursor
            conn.commit()
        except Exception as e:
            conn.rollback()
            logger.error(f"Database error: {e}")
            raise
        finally:
            cursor.close()

    def get_db_size(self) -> int:
        """PostgreSQL database size in bytes."""
        try:
            with self.get_cursor() as cursor:
                cursor.execute("SELECT pg_database_size(current_database())")
                return cursor.fetchone()[0]
        except Exception:
            return 0

    def get_table_count(self, table_name: str) -> int:
        _ALLOWED_TABLES = {
            "listings", "price_history", "valuation_history", "users",
            "payment_orders", "analysis_history", "credit_usage_logs",
            "reports", "profiles", "expertiz_requests", "user_requests",
        }
        if table_name not in _ALLOWED_TABLES:
            logger.warning(f"Blocked table count for disallowed table: {table_name}")
            return 0
        try:
            with self.get_cursor() as cursor:
                cursor.execute(f"SELECT COUNT(*) FROM {table_name}")
                return cursor.fetchone()[0]
        except Exception:
            return 0

    def get_table_list(self) -> int:
        """PostgreSQL public schema table count."""
        try:
            with self.get_cursor() as cursor:
                cursor.execute("SELECT COUNT(*) FROM pg_tables WHERE schemaname='public'")
                return cursor.fetchone()[0]
        except Exception:
            return 0

    def execute_query(self, query: str, params: tuple = None) -> list:
        with self.get_cursor() as cursor:
            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)
            return [dict(row) for row in cursor.fetchall()]

    def _initialize_db(self):
        """Delegate to DatabaseConfig — single source of truth."""
        logger.info("Delegating database init to DatabaseConfig.bootstrap()...")
        DatabaseConfig.bootstrap()
        DatabaseConfig.alignment()


# Keep backward-compatible aliases
get_db = DatabaseManager.get_instance
db_manager = DatabaseManager.get_instance()