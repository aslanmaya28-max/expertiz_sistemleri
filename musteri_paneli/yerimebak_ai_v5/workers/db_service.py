# -*- coding: utf-8 -*-
"""
YERİMEBAK AI - Database Service
İlanları database'e kaydetme servisi
"""

import logging
from typing import List, Dict, Any, Optional
from datetime import datetime
from pathlib import Path
import sys

# Add project root to path
project_root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(project_root))

from yerimebak_ai_v5.data_lake.database import DatabaseManager
from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = logging.getLogger(__name__)


class ListingDatabaseService:
    """
    İlanları database'e kaydetme servisi
    
    Özellikler:
    - Duplicate kontrolü (URL ile)
    - Enum ve Object → String conversion
    - Batch insert
    - İstatistik takibi
    """
    
    def __init__(self):
        """Database servisini başlat"""
        self.db = DatabaseManager.get_instance()
        self._db_type = DatabaseConfig._get_db_type()
        
        logger.info(f"✅ DatabaseService initialized (DB type: {self._db_type})")
    
    @property
    def _p(self):
        return "%s"
    
    def save_listings(
        self,
        listings: List[Dict[str, Any]],
        source: str,
        force_save: bool = False
    ) -> Dict[str, int]:
        """
        İlanları database'e kaydet
        
        Args:
            listings: İlan listesi
            source: Kaynak (örn: "arabam")
            force_save: Duplicate olsa bile kaydet (overwrite)
        
        Returns:
            {'success': X, 'duplicate': Y, 'failed': Z}
        """
        if not listings:
            logger.warning("⚠️  No listings to save")
            return {'success': 0, 'duplicate': 0, 'failed': 0}
        
        stats = {'success': 0, 'duplicate': 0, 'failed': 0}
        
        logger.info(f"💾 Saving {len(listings)} listings to database (source: {source})...")
        
        for i, listing in enumerate(listings, 1):
            try:
                # URL ile duplicate kontrolü
                url = listing.get('url')
                if not url:
                    logger.warning(f"   [{i}] ⚠️  No URL, skipping")
                    stats['failed'] += 1
                    continue
                
                # Duplicate kontrol
                if not force_save and self._url_exists(url):
                    logger.debug(f"   [{i}] ⏭️  Duplicate: {url}")
                    stats['duplicate'] += 1
                    continue
                
                # İlan kaydı
                self._insert_listing(listing, source, force_save)
                
                if i % 10 == 0:
                    logger.info(f"   Processed {i}/{len(listings)} listings...")
                
                stats['success'] += 1
                
            except Exception as e:
                logger.error(f"   [{i}] ❌ Failed to save listing: {e}")
                stats['failed'] += 1
                continue
        
        logger.info(f"✅ Save complete: {stats['success']} success, {stats['duplicate']} duplicate, {stats['failed']} failed")
        return stats
    
    def _url_exists(self, url: str) -> bool:
        """
        URL'nin DB'de var olup olmadığını kontrol et
        
        Args:
            url: Kontrol edilecek URL
        
        Returns:
            True if URL exists, False otherwise
        """
        # 🔒 DÜZELTİLDİ: conn.close() kaldirildi (connection pool kullaniliyor)
        try:
            conn = DatabaseConfig.get_connection()
            cur = conn.cursor()
            cur.execute(
                f"SELECT id FROM listings WHERE url = {self._p}",
                (url,)
            )
            result = cur.fetchone()
            cur.close()
            return result is not None
        except Exception as e:
            logger.error(f"❌ URL check failed: {e}")
            return False
    
    def _insert_listing(
        self,
        listing: Dict[str, Any],
        source: str,
        force_save: bool = False
    ):
        """
        İlanı database'e insert et
        
        Args:
            listing: İlan verisi
            source: Kaynak
            force_save: Var olanı update et
        """
        # Normalize: Enum ve Object'leri String'e çevir
        listing_copy = self._normalize_for_db(listing)
        listing_copy['source'] = source
        
        # scraped_at ekle
        if 'scraped_at' not in listing_copy:
            listing_copy['scraped_at'] = datetime.now().isoformat()
        
        try:
            conn = DatabaseConfig.get_connection()
            cur = conn.cursor()
            
            # 🔒 DÜZELTİLDİ (B17): Dinamik SQL kolon adları injection riski giderildi.
            # Sadece önceden tanımlanmış kolon adlarına izin verilir.
            # Dict key'leri direkt SQL'e gömülmez — beyaz liste kontrolü yapılır.
            ALLOWED_COLUMNS = {
                'url', 'source', 'brand', 'model', 'year', 'price', 'km',
                'fuel', 'transmission', 'color', 'paint_info', 'accident_record',
                'guarantee', 'package_info', 'description', 'location',
                'listing_date', 'engine_size', 'horsepower', 'series',
                'body_type', 'risk_score', 'opportunity_score',
                'predicted_future_price', 'vision_condition_score',
                'vision_analysis_report', 'action_recommendation',
                'buy_price_min', 'buy_price_max', 'predicted_profit_tl',
                'predicted_profit_pct', 'image_url', 'fuel_type', 'title',
                'market_avg_price', 'price_deviation_pct', 'risk_level',
                'decision', 'exit_price', 'days_to_sell', 'status',
                'last_push_alert', 'analyzed_at', 'scraped_at'
            }
            
            # Filter keys to only allowed columns
            safe_keys = {k: v for k, v in listing_copy.items() if k in ALLOWED_COLUMNS}
            
            if not safe_keys:
                logger.error("❌ No valid columns to insert after whitelist filter")
                raise ValueError("No valid columns for INSERT")
            
            columns = ', '.join(safe_keys.keys())
            placeholders = ', '.join([self._p] * len(safe_keys))
            
            if force_save and self._url_exists(listing['url']):
                query = f"""
                    INSERT INTO listings ({columns})
                    VALUES ({placeholders})
                    ON CONFLICT (url) DO UPDATE SET
                        {', '.join([f"{k} = EXCLUDED.{k}" for k in safe_keys.keys() if k != 'url'])}
                    """
            else:
                # Normal INSERT
                query = f"""
                    INSERT INTO listings ({columns})
                    VALUES ({placeholders})
                """
            
            cur.execute(query, tuple(safe_keys.values()))

            conn.commit()
            cur.close()
            # 🔒 DÜZELTİLDİ: conn.close() kaldirildi (connection pool kullaniliyor)
            
        except Exception as e:
            logger.error(f"❌ Insert failed: {e}")
            raise
    
    def _normalize_for_db(self, listing: Dict[str, Any]) -> Dict[str, Any]:
        """
        Enum ve Object'leri String'e çevir
        
        Args:
            listing: Orijinal ilan verisi
        
        Returns:
            Normalize edilmiş ilan verisi
        """
        result = {}
        
        for k, v in listing.items():
            # None değerleri atla
            if v is None:
                continue
            
            # Enum → String
            if hasattr(v, 'value'):
                result[k] = v.value
            
            # Object → String (PaintInfo, PackageInfo, etc.)
            elif hasattr(v, '__dict__'):
                # Object'ı string'e çevir (repr veya str)
                result[k] = str(v)
            
            # Dict → JSON string
            elif isinstance(v, dict):
                import json
                result[k] = json.dumps(v, ensure_ascii=False)
            
            # List → JSON string
            elif isinstance(v, list):
                import json
                result[k] = json.dumps(v, ensure_ascii=False)
            
            # Diğer tipler
            else:
                result[k] = v
        
        return result
    
    def get_stats(self) -> Dict[str, Any]:
        """
        Database istatistiklerini döndür
        
        Returns:
            {'total_listings': X, 'by_source': {...}, 'by_brand': {...}}
        """
        try:
            conn = DatabaseConfig.get_connection()
            cur = conn.cursor()
            
            # Total listings
            cur.execute("SELECT COUNT(*) FROM listings")
            total = cur.fetchone()[0]
            
            # By source
            cur.execute("""
                SELECT source, COUNT(*) as count
                FROM listings
                GROUP BY source
                ORDER BY count DESC
            """)
            by_source = {row[0]: row[1] for row in cur.fetchall()}
            
            # By brand (top 10)
            cur.execute("""
                SELECT brand, COUNT(*) as count
                FROM listings
                GROUP BY brand
                ORDER BY count DESC
                LIMIT 10
            """)
            by_brand = {row[0]: row[1] for row in cur.fetchall()}
            
            cur.close()
            # 🔒 DÜZELTİLDİ: conn.close() kaldirildi (connection pool kullaniliyor)
            
            return {
                'total_listings': total,
                'by_source': by_source,
                'by_brand': by_brand
            }
            
        except Exception as e:
            logger.error(f"❌ Stats failed: {e}")
            return {
                'total_listings': 0,
                'by_source': {},
                'by_brand': {}
            }
    
    def clear_duplicates(self, source: Optional[str] = None) -> int:
        """
        Duplicate ilanları temizle
        
        Args:
            source: Sadece belirli bir kaynağı temizle (opsiyonel)
        
        Returns:
            Silinen kayıt sayısı
        """
        try:
            conn = DatabaseConfig.get_connection()
            cur = conn.cursor()
            
            if source:
                # URL'ye göre duplicate'leri bul
                cur.execute(f"""
                    DELETE FROM listings
                    WHERE id NOT IN (
                        SELECT MIN(id) FROM listings
                        WHERE source = {self._p}
                        GROUP BY url
                    )
                    AND source = {self._p}
                """, (source, source))
            else:
                # Tüm duplicate'leri sil
                cur.execute("""
                    DELETE FROM listings
                    WHERE id NOT IN (
                        SELECT MIN(id) FROM listings
                        GROUP BY url
                    )
                """)
            
            deleted = cur.rowcount
            conn.commit()
            cur.close()
            # 🔒 DÜZELTİLDİ: conn.close() kaldirildi (connection pool kullaniliyor)
            
            logger.info(f"🗑️  Cleared {deleted} duplicate listings")
            return deleted
            
        except Exception as e:
            logger.error(f"❌ Clear duplicates failed: {e}")
            return 0


# Convenience function
def get_db_service() -> ListingDatabaseService:
    """Get database service instance"""
    return ListingDatabaseService()