# -*- coding: utf-8 -*-
"""
YERIMEBAK AI - Alert Worker
Monitors Opportunity Scores and Prices to trigger Push Alerts
PostgreSQL Only
"""
import time
from datetime import datetime, timedelta
from yerimebak_ai_v5.core.database_config import DatabaseConfig

class AlertWorker:
    def __init__(self, rate_limit_minutes: int = 15):
        self.rate_limit_minutes = rate_limit_minutes

    def run(self):
        print(f"Alert Worker baslatildi (Rate Limit: {self.rate_limit_minutes} dk)")
        while True:
            try:
                self.check_for_alerts()
            except Exception as e:
                print(f"Alert Worker hatasi: {e}")
            time.sleep(60)

    def check_for_alerts(self):
        conn = None
        try:
            conn = DatabaseConfig.get_connection()
            cursor = conn.cursor()

            time_filter = f"last_push_alert IS NULL OR last_push_alert < NOW() - INTERVAL '{self.rate_limit_minutes} minutes'"

            cursor.execute(f"""
                SELECT id, brand, model, opportunity_score, price, last_push_alert
                FROM listings
                WHERE opportunity_score >= 80
                AND ({time_filter})
                LIMIT 5
            """)

            alerts = cursor.fetchall()
            for alert in alerts:
                row = dict(alert)
                listing_id = row['id']
                brand = row['brand']
                model = row['model']
                score = row['opportunity_score']
                price = row['price']

                self.trigger_push_alert(listing_id, brand, model, score, price)
                cursor.execute("UPDATE listings SET last_push_alert = CURRENT_TIMESTAMP WHERE id = %s", (listing_id,))

            conn.commit()
        except Exception as e:
            print(f"Alert Worker check error: {e}")
            if conn:
                conn.rollback()
            raise
        finally:
            if conn:
                # 🔒 DÜZELTİLDİ (B1): Connection pool'a geri dön — exception durumunda bile
                DatabaseConfig.return_connection(conn)


    def trigger_push_alert(self, listing_id, brand, model, score, price):
        print(f"PUSH ALERT: {brand} {model} | Skor: {score} | Fiyat: {price:,.0f} TL")

if __name__ == "__main__":
    worker = AlertWorker()
    worker.run()