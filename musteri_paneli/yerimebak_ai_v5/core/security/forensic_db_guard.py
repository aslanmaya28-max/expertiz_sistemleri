import logging
from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)


class ForensicDBGuard:
    """
    Forensic Database Guard Layer.
    Verifies data integrity and single source of truth connectivity.
    PostgreSQL only — SQLite support removed.
    """

    @staticmethod
    def verify_database_integrity():
        """
        Verify database existence, schema, and functional R/W.
        Aborts system execution if integrity is compromised.
        """
        logger.info("[FORENSIC DB GUARD] Starting verification for PostgreSQL...")
        DatabaseConfig.bootstrap()
        DatabaseConfig.alignment()

        try:
            conn = DatabaseConfig.get_connection()
            cursor = conn.cursor()

            cursor.execute("""
                SELECT table_name FROM information_schema.tables
                WHERE table_schema = 'public'
            """)
            tables = [row[0] for row in cursor.fetchall()]

            required_tables = ['listings', 'price_history', 'valuation_history']
            for table in required_tables:
                if table not in tables:
                    logger.error(f"[FORENSIC DB GUARD FAILURE] Table MISSING: {table}")
                    raise Exception(f"FORENSIC INTEGRITY FAILURE: Table {table} missing.")

            cursor.execute("BEGIN TRANSACTION;")
            try:
                cursor.execute("""
                    INSERT INTO listings (brand, model, year, price, url, source)
                    VALUES ('FORENSIC_GUARD', 'INTEGRITY_TEST', 2024, 0, 'forensic://test', 'guard')
                    RETURNING id
                """)
                test_id = cursor.fetchone()[0]

                cursor.execute("SELECT id FROM listings WHERE id = %s", (test_id,))
                if not cursor.fetchone():
                    raise Exception("Read-back failed during integrity test.")

                conn.rollback()
                logger.info("[FORENSIC DB GUARD] R/W Integrity Verified.")
            except Exception as e:
                conn.rollback()
                logger.error(f"[FORENSIC DB GUARD FAILURE] R/W Test Failed: {e}")
                raise
            finally:
                conn.close()

            logger.info("FORENSIC DB VERIFIED")
            return True

        except Exception as e:
            logger.error(f"[FORENSIC DB GUARD CRITICAL FAILURE] {e}")
            raise


if __name__ == "__main__":
    try:
        ForensicDBGuard.verify_database_integrity()
        print("FORENSIC DB VERIFIED")
    except Exception as e:
        print(f"FORENSIC DB FAILURE: {e}")