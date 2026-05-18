import logging
import time
from datetime import datetime, timedelta

from yerimebak_ai_v5.core.database_config import DatabaseConfig


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - [MAINTENANCE] - %(levelname)s - %(message)s",
)
logger = logging.getLogger(__name__)


class DataCleanupWorker:
    """
    Veritabani bakim isçisi.
    - 27 gunden eski ilanlari otomatik temizler.
    - Gunluk periyotta calisir.
    """

    def __init__(self, retention_days=27):
        self.retention_days = retention_days
        self.running = True

    def cleanup_old_data(self):
        """Retention penceresinden eski verileri siler ve istatistik dondurur."""
        logger.info("Veri temizligi baslatiliyor (Kriter: %s gun)...", self.retention_days)

        conn = DatabaseConfig.get_connection()
        deleted_listings = 0
        try:
            cursor = conn.cursor()
            cutoff_date = (datetime.now() - timedelta(days=self.retention_days)).strftime("%Y-%m-%d %H:%M:%S")

            cursor.execute("SELECT COUNT(*) FROM listings WHERE updated_at < %s", (cutoff_date,))
            count = cursor.fetchone()[0]

            if count > 0:
                cursor.execute("DELETE FROM listings WHERE updated_at < %s", (cutoff_date,))
                deleted_listings = cursor.rowcount
                cursor.execute("DELETE FROM price_history WHERE recorded_at < %s", (cutoff_date,))
                logger.info("Temizlik tamamlandi: %s adet eski ilan veritabanindan silindi.", deleted_listings)
            else:
                logger.info("Silinecek eski veri bulunamadi.")

            conn.commit()
            return {"deleted_listings": deleted_listings, "retention_days": self.retention_days}
        except Exception as exc:
            logger.error("Temizlik hatasi: %s", exc)
            try:
                conn.rollback()
            except Exception:
                pass
            return {"deleted_listings": 0, "retention_days": self.retention_days, "error": str(exc)}
        finally:
            conn.close()

    def run_periodically(self):
        """Gunde bir kez temizlik yapar."""
        logger.info("Data Cleanup Worker aktif.")
        while self.running:
            self.cleanup_old_data()
            logger.info("Sonraki temizlige kadar 24 saat bekleniyor...")
            time.sleep(86400)


if __name__ == "__main__":
    worker = DataCleanupWorker(retention_days=27)
    worker.run_periodically()
