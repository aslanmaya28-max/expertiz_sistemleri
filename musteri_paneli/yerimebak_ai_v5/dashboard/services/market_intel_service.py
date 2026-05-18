# -*- coding: utf-8 -*-
"""
YERİMEBAK AI — Piyasa Zekası Servisi
Edermi.com'dan ilham alınarak araç sektörüne uyarlanmış:
- Arz/Talep Analizi (Supply/Demand)
- Fiyat Trendi (Price Trend)
- Likidite Skoru (Market Speed)
- Emsal İlanlar (Comparable Listings)
- Gelecek Beklentisi (3-6 ay projeksiyon)
"""
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
import math

from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)


class MarketIntelService:
    """
    Edermi.com tarzı piyasa zekası.
    Mevcut listings DB'sinden marka/model bazlı istatistik üretir.
    """

    def __init__(self):
        self._p = "%s"

    def _conn(self):
        return DatabaseConfig.get_connection()

    # ─── Core Query ───────────────────────────────────────────────────────────

    def get_comparables(self, brand: str, model: str, year: int, km: int,
                         price: float, limit: int = 6) -> List[Dict]:
        """Emsal ilanları getirir (marka+model bazlı, fiyat yakın)."""
        try:
            conn = self._conn()
            cursor = conn.cursor()

            # ±3 yıl, ±%30 fiyat aralığı
            min_price = price * 0.70
            max_price = price * 1.30
            year_min = year - 3
            year_max = year + 3

            cursor.execute(f"""
                SELECT brand, model, year, price, km, fuel, transmission,
                       color, paint_info, location, url, image_url,
                       opportunity_score, risk_score, scraped_at
                FROM listings
                WHERE LOWER(brand) = LOWER({self._p})
                  AND LOWER(model) LIKE LOWER({self._p})
                  AND year BETWEEN {self._p} AND {self._p}
                  AND price BETWEEN {self._p} AND {self._p}
                  AND price > 0
                ORDER BY ABS(price - {self._p}), scraped_at DESC
                LIMIT {self._p}
            """, (brand, f"%{model}%", year_min, year_max,
                  min_price, max_price, price, limit))

            rows = cursor.fetchall()
            conn.close()

            result = []
            for row in rows:
                if hasattr(row, 'keys'):
                    r = dict(row)
                else:
                    cols = [d[0] for d in cursor.description]
                    r = dict(zip(cols, row))
                result.append(r)
            return result

        except Exception as e:
            logger.error(f"Comparables error: {e}")
            return []

    def get_market_intel(self, brand: str, model: str, year: int,
                          km: int, price: float) -> Dict[str, Any]:
        """
        Ana piyasa zekası raporu.
        Edermi.com'un Yatırım Skoru + Arz/Talep + Likidite göstergelerini üretir.
        """
        try:
            conn = self._conn()
            cursor = conn.cursor()

            # ─── Toplam arz (son 30 gün) ───
            cursor.execute(f"""
                SELECT COUNT(*) as cnt, AVG(price) as avg_p,
                       MIN(price) as min_p, MAX(price) as max_p,
                       AVG(km) as avg_km
                FROM listings
                WHERE LOWER(brand) = LOWER({self._p})
                  AND LOWER(model) LIKE LOWER({self._p})
                  AND price > 0
            """, (brand, f"%{model}%"))

            row = cursor.fetchone()
            if hasattr(row, 'keys'):
                stats = dict(row)
            else:
                cols = [d[0] for d in cursor.description]
                stats = dict(zip(cols, row))

            total_listings = int(stats.get('cnt') or 0)
            avg_price = float(stats.get('avg_p') or price)
            min_price_db = float(stats.get('min_p') or price)
            max_price_db = float(stats.get('max_p') or price)
            avg_km = float(stats.get('avg_km') or km)

            # ─── Haftalık yeni ilan sayısı (Arz artışı?) ───
            cursor.execute(f"""
                SELECT COUNT(*) as cnt
                FROM listings
                WHERE LOWER(brand) = LOWER({self._p})
                  AND LOWER(model) LIKE LOWER({self._p})
                  AND scraped_at >= NOW() - INTERVAL '7 days'
            """, (brand, f"%{model}%"))
            row7 = cursor.fetchone()
            if row7:
                row7 = dict(row7)
                weekly_new = int(row7.get('cnt') or 0)
            else:
                weekly_new = 0

            # ─── Opportunity skoru ortalaması ───
            cursor.execute(f"""
                SELECT AVG(opportunity_score) as avg_opp,
                       COUNT(CASE WHEN opportunity_score > 70 THEN 1 END) as hot_cnt
                FROM listings
                WHERE LOWER(brand) = LOWER({self._p})
                  AND LOWER(model) LIKE LOWER({self._p})
                  AND opportunity_score IS NOT NULL
            """, (brand, f"%{model}%"))
            row_opp = cursor.fetchone()
            if hasattr(row_opp, 'keys'):
                opp_data = dict(row_opp)
            else:
                cols = [d[0] for d in cursor.description]
                opp_data = dict(zip(cols, row_opp))
            avg_opp_score = float(opp_data.get('avg_opp') or 50)
            hot_count = int(opp_data.get('hot_cnt') or 0)

            conn.close()

            # ─── Hesaplamalar ─────────────────────────────────────────────

            # 1. Fiyat Pozisyonu (İlan fiyatı piyasaya göre nerede?)
            if avg_price > 0:
                price_vs_avg = ((price - avg_price) / avg_price) * 100  # + pahalı, - ucuz
            else:
                price_vs_avg = 0

            # 2. Arz Durumu (Kaç ilan var? Az = Kıt mal = talep yüksek)
            if total_listings == 0:
                arz_durum = "BİLİNMİYOR"
                arz_score = 50
                arz_icon = "⚪"
            elif total_listings < 10:
                arz_durum = "KITI MAL"
                arz_score = 85
                arz_icon = "🟢"
            elif total_listings < 30:
                arz_durum = "NORMAL ARZ"
                arz_score = 60
                arz_icon = "🟡"
            elif total_listings < 80:
                arz_durum = "YÜKSEK ARZ"
                arz_score = 40
                arz_icon = "🟠"
            else:
                arz_durum = "AŞIRI ARZ"
                arz_score = 20
                arz_icon = "🔴"

            # 3. Likidite / Piyasa Hızı (avg_opp_score ve hot_count üzerinden proxy)
            if avg_opp_score > 70:
                likidite = "YÜKSEK TALEP"
                lik_score = 85
                lik_icon = "🔥"
                lik_days = "15-25 gün"
            elif avg_opp_score > 50:
                likidite = "ORTA TALEP"
                lik_score = 60
                lik_icon = "⚡"
                lik_days = "30-45 gün"
            else:
                likidite = "DÜŞÜK TALEP"
                lik_score = 35
                lik_icon = "🐢"
                lik_days = "60-90 gün"

            # 4. Fiyat Trendi (weekly_new: çok yeni ilan geliyorsa = arzda artış = düşüş baskısı)
            if weekly_new > 10:
                trend = "DÜŞÜŞ BASKISI"
                trend_icon = "📉"
                trend_pct = -8
                trend_color = "#f87171"
            elif weekly_new > 5:
                trend = "YATAY"
                trend_icon = "➡️"
                trend_pct = 3
                trend_color = "#fbbf24"
            else:
                trend = "YÜKSELİŞ BEKLENTİSİ"
                trend_icon = "📈"
                trend_pct = 12
                trend_color = "#4ade80"

            # 5. Yatırım Skoru (Edermi tarzı 1-100)
            # Arz skoru + likidite skoru + fiyat pozisyonu
            fp_bonus = max(0, min(20, -price_vs_avg))  # Ucuz = bonus puan
            inv_score = int((arz_score * 0.35) + (lik_score * 0.40) + fp_bonus + 5)
            inv_score = max(5, min(100, inv_score))

            # Yatırım Skoru rengi
            if inv_score >= 70:
                inv_color = "#4ade80"
                inv_label = "GÜÇLÜ YATIRIM"
            elif inv_score >= 45:
                inv_color = "#fbbf24"
                inv_label = "ORTA POTANSİYEL"
            else:
                inv_color = "#f87171"
                inv_label = "RİSKLİ YATIRIM"

            # 6. 3 ve 6 ay fiyat projeksiyonu (Türkiye araç enflasyonu gerçekçi tahmin)
            # Arz azsa + likidite yüksekse = daha fazla artış
            base_monthly_rate = 0.028  # %2.8 aylık (yıllık ~%34 araç enflasyonu)
            adj_monthly = base_monthly_rate * (arz_score / 60) * (lik_score / 60)
            price_3m = int(price * (1 + adj_monthly * 3))
            price_6m = int(price * (1 + adj_monthly * 6))
            gain_3m_pct = round((price_3m - price) / price * 100, 1)
            gain_6m_pct = round((price_6m - price) / price * 100, 1)

            # 7. KM Değerlendirmesi
            beklenen_km = (2026 - year) * 15000
            km_fark = km - beklenen_km
            if km_fark > 30000:
                km_durum = "YÜKSEK KM"
                km_icon = "🔴"
            elif km_fark > 10000:
                km_durum = "ORTANIN ÜZERİ"
                km_icon = "🟡"
            elif km_fark > -10000:
                km_durum = "NORMAL KM"
                km_icon = "🟢"
            else:
                km_durum = "DÜŞÜK KM — AVANTAJ"
                km_icon = "⭐"

            return {
                "success": True,
                "brand": brand,
                "model": model,
                "year": year,
                "km": km,
                "price": price,

                # Piyasa Verileri
                "total_listings": total_listings,
                "avg_price": avg_price,
                "min_price_db": min_price_db,
                "max_price_db": max_price_db,
                "avg_km": avg_km,
                "price_vs_avg": price_vs_avg,
                "weekly_new": weekly_new,

                # Skorlar
                "investment_score": inv_score,
                "investment_color": inv_color,
                "investment_label": inv_label,
                "arz_score": arz_score,

                # Göstergeler
                "arz_durum": arz_durum,
                "arz_icon": arz_icon,
                "likidite": likidite,
                "lik_score": lik_score,
                "lik_icon": lik_icon,
                "lik_days": lik_days,
                "trend": trend,
                "trend_icon": trend_icon,
                "trend_pct": trend_pct,
                "trend_color": trend_color,

                # Projeksiyon
                "price_3m": price_3m,
                "price_6m": price_6m,
                "gain_3m_pct": gain_3m_pct,
                "gain_6m_pct": gain_6m_pct,

                # KM
                "km_durum": km_durum,
                "km_icon": km_icon,
                "km_fark": km_fark,
                "beklenen_km": beklenen_km,

                # Hot vehicles
                "hot_count": hot_count,
            }

        except Exception as e:
            logger.error(f"Market intel error: {e}")
            return {"success": False, "error": str(e)}


# Singleton
_intel_instance: Optional[MarketIntelService] = None

def get_market_intel_service() -> MarketIntelService:
    global _intel_instance
    if _intel_instance is None:
        _intel_instance = MarketIntelService()
    return _intel_instance
