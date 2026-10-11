import os
import logging
import psycopg2
from psycopg2.extras import DictCursor
from psycopg2.pool import ThreadedConnectionPool
import threading

from dotenv import load_dotenv
load_dotenv(override=False)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - [FORENSIC DB] - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def _get_database_url():
    """Get DATABASE_URL, raise if not configured."""
    url = os.getenv("DATABASE_URL", "")
    if not url.startswith("postgresql://"):
        raise RuntimeError(
            "DATABASE_URL must be a PostgreSQL connection string. "
            "Set DATABASE_URL=postgresql://user:pass@host:port/dbname in .env"
        )
    return url


_pool = None
_pool_lock = threading.Lock()


class _PooledConnection(psycopg2.extensions.connection):
    """Havuzdan gelen baglanti.

    psycopg2'nin C seviyesindeki connection nesnesinde `close` salt-okunurdur;
    eski kod `conn.close = ...` ile monkey-patch yapmaya calistigi icin HER
    baglanti isteginde AttributeError aliniyordu. Bu alt sinif `close()`
    cagrisini havuza geri iade olarak yorumlar (eski conn.close() cagrilari
    calismaya devam eder).
    """

    _return_to_pool = None

    def close(self):
        release = self._return_to_pool
        if release is not None:
            self._return_to_pool = None
            try:
                release(self)
                return
            except Exception:
                pass
        super().close()


def _get_pool() -> ThreadedConnectionPool:
    global _pool
    if _pool is None:
        with _pool_lock:
            if _pool is None:
                url = _get_database_url()
                _pool = ThreadedConnectionPool(
                    minconn=2,
                    maxconn=20,
                    dsn=url,
                    cursor_factory=DictCursor,
                    connection_factory=_PooledConnection,
                )
                logger.info("[FORENSIC DB POOL] ThreadedConnectionPool created (2-20)")
    return _pool


class DatabaseConfig:
    """
    SINGLE SOURCE OF TRUTH — PostgreSQL Only.
    Thread-safe connection pooling via ThreadedConnectionPool.
    """

    @staticmethod
    def _get_db_type():
        """Always returns 'postgresql'. SQLite is no longer supported."""
        return "postgresql"

    @staticmethod
    def get_connection():
        """PostgreSQL connection from pool with DictCursor.
        
        🔒 DÜZELTİLDİ: conn.close() otomatik olarak pool'a geri döner.
        Eski kodlardaki conn.close() çağrıları hala çalışır.
        """
        try:
            pool = _get_pool()
            conn = pool.getconn()
            conn.autocommit = False

            def _release(connection):
                # 🔒 DÜZELTİLDİ (Bug #9): Pool'a dönmeden önce connection state'i resetle
                connection.rollback()
                connection.autocommit = False
                pool.putconn(connection)

            if isinstance(conn, _PooledConnection):
                conn._return_to_pool = _release
            return conn
        except Exception as e:
            logger.error(f"[FORENSIC DB CONNECTION FAILURE] {e}")
            raise

    @staticmethod
    def return_connection(conn):
        """Return a connection to the pool."""
        global _pool
        if _pool is not None and conn is not None:
            try:
                if isinstance(conn, _PooledConnection):
                    conn._return_to_pool = None
                _pool.putconn(conn)
            except Exception:
                pass

    @staticmethod
    def bootstrap():
        """Initialize PostgreSQL schema. Called once during deployment."""
        logger.info("[FORENSIC DB BOOTSTRAP] Initializing PostgreSQL schema...")
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS listings (
                    id SERIAL PRIMARY KEY,
                    brand TEXT NOT NULL,
                    model TEXT NOT NULL,
                    year INTEGER,
                    price INTEGER,
                    km INTEGER,
                    fuel TEXT,
                    transmission TEXT,
                    source TEXT,
                    url TEXT UNIQUE,
                    color TEXT,
                    paint_info TEXT,
                    accident_record TEXT,
                    guarantee TEXT,
                    package_info TEXT,
                    description TEXT,
                    location TEXT,
                    listing_date TEXT,
                    engine_size TEXT,
                    horsepower TEXT,
                    series TEXT,
                    body_type TEXT,
                    risk_score FLOAT,
                    opportunity_score FLOAT,
                    predicted_future_price INTEGER,
                    vision_condition_score FLOAT,
                    vision_analysis_report TEXT,
                    action_recommendation TEXT,
                    buy_price_min INTEGER,
                    buy_price_max INTEGER,
                    predicted_profit_tl INTEGER,
                    predicted_profit_pct FLOAT,
                    image_url TEXT,
                    scraped_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS price_history (
                    id SERIAL PRIMARY KEY,
                    listing_id INTEGER,
                    price INTEGER,
                    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    FOREIGN KEY(listing_id) REFERENCES listings(id)
                )
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS valuation_history (
                    id SERIAL PRIMARY KEY,
                    vehicle_brand TEXT,
                    vehicle_model TEXT,
                    vehicle_year INTEGER,
                    actual_price INTEGER,
                    ai_price INTEGER,
                    confidence FLOAT,
                    recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            try:
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_v_lookup ON listings(brand, model, year)")
            except Exception:
                pass

            # 🔒 DÜZELTİLDİ (Bug #16): idx_listings_status ve idx_listings_analyzed_at
            # status ve analyzed_at kolonları bootstrap CREATE TABLE'da yok,
            # alignment() tarafından ekleniyor. Index'ler de alignment sonrası oluşturulur.
            # Aşağıdaki index'ler kaldırıldı — güvenli index oluşturma alignment içine taşındı.

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id SERIAL PRIMARY KEY,
                    email TEXT UNIQUE NOT NULL,
                    password TEXT,
                    full_name TEXT,
                    phone TEXT UNIQUE,
                    api_key TEXT UNIQUE,
                    credits INTEGER DEFAULT 3,
                    tier TEXT DEFAULT 'free',
                    role TEXT DEFAULT 'user',
                    is_active INTEGER DEFAULT 1,
                    last_login TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS payment_orders (
                    id TEXT PRIMARY KEY,
                    user_id INTEGER,
                    user_email TEXT,
                    user_phone TEXT,
                    package_key TEXT,
                    package_name TEXT,
                    credits INTEGER,
                    amount_tl INTEGER,
                    status TEXT DEFAULT 'pending',
                    payment_method TEXT DEFAULT 'havale',
                    payment_ref TEXT,
                    approved_by TEXT,
                    approved_at TIMESTAMP,
                    admin_note TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS analysis_history (
                    id TEXT PRIMARY KEY,
                    user_id INTEGER,
                    vehicle_json TEXT,
                    valuation_json TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS credit_usage_logs (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER,
                    action TEXT,
                    credits_used INTEGER,
                    description TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """)

            try:
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)")
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone)")
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_users_api_key ON users(api_key)")
                cursor.execute("CREATE INDEX IF NOT EXISTS idx_listings_opp ON listings(opportunity_score)")
                # 🔒 DÜZELTİLDİ (Bug #16): status ve analyzed_at kolonları alignment'da ekleniyor
                # Index'leri orada oluşturmak daha güvenli, bu yüzden kaldırıldı
            except Exception:
                pass

            # DDL kalici olsun diye commit edilir (pool'a donuste rollback yapilir).
            conn.commit()
            logger.info("[FORENSIC DB BOOTSTRAP] Schema initialized successfully.")
        finally:
            DatabaseConfig.return_connection(conn)  # 🔒 DÜZELTİLDİ: conn.close() -> pool'a geri ver

    @staticmethod
    def alignment():
        """Self-healing schema alignment — adds missing columns automatically."""
        required_columns = {
            'guarantee': 'TEXT',
            'description': 'TEXT',
            'location': 'TEXT',
            'listing_date': 'TEXT',
            'engine_size': 'TEXT',
            'horsepower': 'TEXT',
            'series': 'TEXT',
            'body_type': 'TEXT',
            'risk_score': 'FLOAT',
            'opportunity_score': 'FLOAT',
            'predicted_future_price': 'INTEGER',
            'image_url': 'TEXT',
            # 🔒 DÜZELTİLDİ (Bug #15): Hardcoded tarih yerine CURRENT_TIMESTAMP
            'scraped_at': "TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
            'fuel_type': 'TEXT',
            'title': 'TEXT',
            'paint_info': 'TEXT',
            'accident_record': 'TEXT',
            'package_info': 'TEXT',
            'vision_condition_score': 'FLOAT',
            'vision_analysis_report': 'TEXT',
            'action_recommendation': 'TEXT',
            'buy_price_min': 'INTEGER',
            'buy_price_max': 'INTEGER',
            'predicted_profit_tl': 'INTEGER',
            'predicted_profit_pct': 'FLOAT',
            'last_push_alert': 'TIMESTAMP',
            'analyzed_at': 'TIMESTAMP',
            'market_avg_price': 'INTEGER',
            'price_deviation_pct': 'FLOAT',
            'risk_level': 'TEXT',
            'decision': 'TEXT',
            'exit_price': 'INTEGER',
            'days_to_sell': 'INTEGER',
            'status': "TEXT DEFAULT 'active'",
        }

        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT column_name FROM information_schema.columns
                WHERE table_name = 'listings'
            """)
            existing_columns = [row['column_name'] for row in cursor.fetchall()]

            for col, col_type in required_columns.items():
                if col not in existing_columns:
                    logger.info(f"[FORENSIC DB ALIGNMENT] Adding missing column: {col}")
                    try:
                        cursor.execute(f"ALTER TABLE listings ADD COLUMN IF NOT EXISTS {col} {col_type}")
                    except Exception as e:
                        logger.error(f"[FORENSIC DB ALIGNMENT] Failed to add {col}: {e}")

            conn.commit()
            logger.info("[FORENSIC DB ALIGNMENT] Database schema is now aligned.")
        finally:
            DatabaseConfig.return_connection(conn)  # 🔒 DÜZELTİLDİ: conn.close() -> pool'a geri ver
