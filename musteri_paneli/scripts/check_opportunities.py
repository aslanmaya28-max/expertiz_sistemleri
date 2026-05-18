# -*- coding: utf-8 -*-
"""
Günlük Fırsat Sayısı Kontrol Scripti
Veritabanındaki fırsat ilanlarını market-relative yöntemle sayar (PostgreSQL)
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from yerimebak_ai_v5.core.database_config import DatabaseConfig

def main():
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()

        cursor.execute("SELECT COUNT(*) as total FROM listings")
        total = cursor.fetchone()['total']
        print(f"Toplam İlan: {total}")

        cursor.execute("SELECT MAX(updated_at) as last_batch FROM listings")
        last_batch = cursor.fetchone()['last_batch']
        print(f"Son Batch: {last_batch}")

        cursor.execute("SELECT COUNT(*) as cnt FROM listings WHERE opportunity_score > 70")
        old_count = cursor.fetchone()['cnt']
        print(f"\nAI Score > 70: {old_count}")

        cursor.execute("""
            SELECT COUNT(*) as cnt FROM listings l
            JOIN (
                SELECT brand, model, AVG(price) as med_price
                FROM listings WHERE price > 0
                GROUP BY brand, model
            ) grp ON l.brand = grp.brand AND l.model = grp.model
            WHERE l.price < grp.med_price * 0.85 AND l.price > 0
        """)
        new_count = cursor.fetchone()['cnt']
        print(f"Market-relative %15 altinda: {new_count}")

        cursor.execute("""
            SELECT l.brand, l.model, COUNT(*) as cnt,
                   ROUND(AVG(grp.med_price)) as avg_market,
                   ROUND(AVG(l.price)) as avg_deal
            FROM listings l
            JOIN (
                SELECT brand, model, AVG(price) as med_price
                FROM listings WHERE price > 0
                GROUP BY brand, model
            ) grp ON l.brand = grp.brand AND l.model = grp.model
            WHERE l.price < grp.med_price * 0.85 AND l.price > 0
            GROUP BY l.brand, l.model
            ORDER BY cnt DESC
            LIMIT 10
        """)
        rows = cursor.fetchall()
        print(f"\nEn Cok Firsat Olan Marka/Modeller:")
        for r in rows:
            print(f"  {r['brand']} {r['model']}: {r['cnt']} adet, pazar ort: {r['avg_market']}, firsat ort: {r['avg_deal']}")

        print(f"\nSonuc: {new_count} firsat ilan bulundu (AI score > 70: {old_count})")
    finally:
        conn.close()

if __name__ == "__main__":
    main()