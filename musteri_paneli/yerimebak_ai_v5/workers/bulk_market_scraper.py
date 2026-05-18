# -*- coding: utf-8 -*-
"""
YERİMEBAK AI - Bulk Market Scraper
Toplu piyasa verisi çekimi için esnek scraper
"""

import asyncio
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta

from yerimebak_ai_v5.workers.turkey_targets import TURKEY_2EL_TARGETS
from yerimebak_ai_v5.workers.db_service import ListingDatabaseService
from yerimebak_ai_v5.scrapers.arabam_v4.facade import ArabamScraperFacade

import logging
logger = logging.getLogger(__name__)


class BulkMarketScraper:
    """
    Esnek toplu market scraper
    
    İki mod destekler:
    1. List modu: turkey_targets.py'den çeker
    2. Custom modu: İstisnai marka/modeller için
    
    Filtreler:
    - 24 saat içindeki ilanlar
    - Yıl aralığı (min_year, max_year)
    """
    
    def __init__(
        self,
        sources: List[str] = ["arabam"],
        min_year: int = 2012,
        max_year: int = 2026,
        max_listings: int = 50,
        headless: bool = True,
        enable_24h_filter: bool = True,
        enable_db_save: bool = True,
        force_save: bool = False
    ):
        """
        Args:
            sources: ['arabam'] veya sadece biri
            min_year: Minimum kabul edilen yıl
            max_year: Maksimum kabul edilen yıl
            max_listings: Her araç için max ilan
            headless: Browser modu
            enable_24h_filter: Sadece 24 saat içindeki ilanları çek
            enable_db_save: Database'e kaydet (varsayılan: True)
            force_save: Duplicate olsa bile kaydet (varsayılan: False)
        """
        self.sources = sources
        self.min_year = min_year
        self.max_year = max_year
        self.max_listings = max_listings
        self.headless = headless
        self.enable_24h_filter = enable_24h_filter
        self.enable_db_save = enable_db_save
        self.force_save = force_save
        
        # Database servisi
        self.db_service = ListingDatabaseService() if enable_db_save else None
        
        # İstatistikler
        self.stats = {
            'total_models': 0,
            'total_listings_found': 0,
            'total_listings_filtered': 0,
            'total_listings_saved': 0,
            'db_saved': 0,
            'db_duplicate': 0,
            'db_failed': 0,
            'models_scraped': 0,
            'errors': []
        }
    
    async def scrape_from_list(
        self,
        priority_filter: int = 1,
        segment_filter: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        turkey_targets.py listesinden çeker
        
        Args:
            priority_filter: 1=sadece yüksek hacim, 2=+orta, 3=tümü
            segment_filter: None=tümü veya 'SUV', 'C', etc.
        
        Returns:
            List[Dict[str, Any]]: Filtrelenmiş ilanlar
        """
        results = []
        
        # Listeyi filtrele
        targets = TURKEY_2EL_TARGETS
        
        if priority_filter:
            targets = [t for t in targets if t[3] <= priority_filter]
        
        if segment_filter:
            targets = [t for t in targets if t[2] == segment_filter]
        
        self.stats['total_models'] = len(targets)
        
        print(f"\n{'='*80}")
        print(f"🎯 LİSTEDEN ÇEKİME BAŞLANIYOR")
        print(f"{'='*80}")
        print(f"Toplam hedef: {len(targets)} model")
        print(f"Kaynaklar: {', '.join(self.sources)}")
        print(f"Yıl aralığı: {self.min_year}-{self.max_year}")
        print(f"24 saat filtresi: {'Aktif' if self.enable_24h_filter else 'Pasif'}")
        print(f"{'='*80}\n")
        
        for brand, model, segment, priority in targets:
            model_results = await self._scrape_single_model(brand, model, segment, priority)
            results.extend(model_results)
        
        # ── DATABASE KAYDI ─────────────────────────────────────────────────────
        if self.enable_db_save and results:
            print(f"\n💾 Database'e kaydediliyor...")
            db_stats = self.db_service.save_listings(
                results,
                source=', '.join(self.sources),
                force_save=self.force_save
            )
            self.stats['db_saved'] = db_stats['success']
            self.stats['db_duplicate'] = db_stats['duplicate']
            self.stats['db_failed'] = db_stats['failed']
            
            print(f"   ✅ Başarılı: {db_stats['success']}")
            print(f"   ⏭️  Duplicate: {db_stats['duplicate']}")
            print(f"   ❌ Başarısız: {db_stats['failed']}")
        
        self._print_summary()
        return results
    
    async def scrape_custom(
        self,
        brand: str,
        model: str,
        segment: str = "Custom"
    ) -> List[Dict[str, Any]]:
        """
        İstisnai marka/model için çeker
        
        Args:
            brand: Marka (örn: "Volvo")
            model: Model (örn: "S60")
            segment: Segment (opsiyonel, varsayılan "Custom")
        
        Returns:
            List[Dict[str, Any]]: Filtrelenmiş ilanlar
        """
        print(f"\n{'='*80}")
        print(f"🎯 İSTİSNİ MARKA ÇEKİME BAŞLANIYOR")
        print(f"{'='*80}")
        print(f"Hedef: {brand} {model}")
        print(f"Segment: {segment}")
        print(f"Kaynaklar: {', '.join(self.sources)}")
        print(f"Yıl aralığı: {self.min_year}-{self.max_year}")
        print(f"24 saat filtresi: {'Aktif' if self.enable_24h_filter else 'Pasif'}")
        print(f"{'='*80}\n")
        
        self.stats['total_models'] = 1
        results = await self._scrape_single_model(brand, model, segment, priority=1)
        
        # ── DATABASE KAYDI ─────────────────────────────────────────────────────
        if self.enable_db_save and results:
            print(f"\n💾 Database'e kaydediliyor...")
            db_stats = self.db_service.save_listings(
                results,
                source=', '.join(self.sources),
                force_save=self.force_save
            )
            self.stats['db_saved'] = db_stats['success']
            self.stats['db_duplicate'] = db_stats['duplicate']
            self.stats['db_failed'] = db_stats['failed']
            
            print(f"   ✅ Başarılı: {db_stats['success']}")
            print(f"   ⏭️  Duplicate: {db_stats['duplicate']}")
            print(f"   ❌ Başarısız: {db_stats['failed']}")
        
        self._print_summary()
        return results
    
    async def scrape_multiple_custom(
        self,
        custom_targets: List[tuple]
    ) -> List[Dict[str, Any]]:
        """
        Çoklu istisnai marka/model için çeker
        
        Args:
            custom_targets: [(brand, model, segment), ...]
                           Örn: [("Volvo", "S60", "D"), ("Lexus", "IS", "D")]
        
        Returns:
            List[Dict[str, Any]]: Filtrelenmiş ilanlar
        """
        results = []
        
        print(f"\n{'='*80}")
        print(f"🎯 ÇOKLU İSTİSNİ MARKA ÇEKİME BAŞLANIYOR")
        print(f"{'='*80}")
        print(f"Toplam hedef: {len(custom_targets)} model")
        print(f"Kaynaklar: {', '.join(self.sources)}")
        print(f"Yıl aralığı: {self.min_year}-{self.max_year}")
        print(f"24 saat filtresi: {'Aktif' if self.enable_24h_filter else 'Pasif'}")
        print(f"{'='*80}\n")
        
        self.stats['total_models'] = len(custom_targets)
        
        for brand, model, segment in custom_targets:
            model_results = await self._scrape_single_model(brand, model, segment, priority=1)
            results.extend(model_results)
        
        # ── DATABASE KAYDI ─────────────────────────────────────────────────────
        if self.enable_db_save and results:
            print(f"\n💾 Database'e kaydediliyor...")
            db_stats = self.db_service.save_listings(
                results,
                source=', '.join(self.sources),
                force_save=self.force_save
            )
            self.stats['db_saved'] = db_stats['success']
            self.stats['db_duplicate'] = db_stats['duplicate']
            self.stats['db_failed'] = db_stats['failed']
            
            print(f"   ✅ Başarılı: {db_stats['success']}")
            print(f"   ⏭️  Duplicate: {db_stats['duplicate']}")
            print(f"   ❌ Başarısız: {db_stats['failed']}")
        
        self._print_summary()
        return results
    
    async def _scrape_single_model(
        self,
        brand: str,
        model: str,
        segment: str,
        priority: int
    ) -> List[Dict[str, Any]]:
        """
        Tek bir marka/model için tüm kaynaklardan çeker ve filtreler
        
        Args:
            brand: Marka
            model: Model
            segment: Segment
            priority: Öncelik (1-3)
        
        Returns:
            List[Dict[str, Any]]: Filtrelenmiş ilanlar
        """
        results = []
        
        print(f"\n{'─'*80}")
        print(f"🚗 {brand} {model}")
        print(f"   Segment: {segment} | Öncelik: {priority}")
        print(f"{'─'*80}")
        
        for source in self.sources:
            try:
                if source == "arabam":
                    scraper = ArabamScraperFacade(headless=self.headless)
                    # Year belirtmeksizin çağır
                    search_result = await scraper.search(
                        brand=brand,
                        model=model,
                        year=None,  # YIL YOK
                        min_price=None,
                        max_price=None
                    )
                    
                    # Listing'leri filtrele
                    for listing in search_result.listings:
                        filtered_listing = self._filter_listing(
                            listing.__dict__,
                            source,
                            brand,
                            model
                        )
                        if filtered_listing:
                            results.append(filtered_listing)
                
                # İstatistik güncelle
                self.stats['models_scraped'] += 1
                
            except Exception as e:
                error_msg = f"{source} - {brand} {model}: {str(e)[:100]}"
                logger.error(f"   ❌ {error_msg}")
                self.stats['errors'].append(error_msg)
                continue
        
        print(f"   ✅ Toplam: {len(results)} ilan (filtreleme sonrası)")
        return results
    
    def _filter_listing(
        self,
        listing: Dict[str, Any],
        source: str,
        brand: str,
        model: str
    ) -> Optional[Dict[str, Any]]:
        """
        İlanı filtreler:
        1. Yıl aralığı (2012-2026)
        2. 24 saat içinde mi
        
        Args:
            listing: İlan verisi
            source: Kaynak (arabam)
            brand: Marka
            model: Model
        
        Returns:
            Optional[Dict[str, Any]]: Filtrelenmiş ilan veya None
        """
        self.stats['total_listings_found'] += 1
        
        # 1. YIL FİLTRESİ
        year = listing.get('year')
        if year:
            if not (self.min_year <= year <= self.max_year):
                logger.debug(f"      ⏭️ Atlandı: Yıl {year} dışında aralıkta")
                self.stats['total_listings_filtered'] += 1
                return None
        
        # 2. 24 SAAT FİLTRESİ
        if self.enable_24h_filter:
            listing_date = listing.get('listing_date')
            
            if listing_date:
                try:
                    # ISO format: 2026-02-25
                    if isinstance(listing_date, str) and len(listing_date) == 10:
                        listing_datetime = datetime.strptime(listing_date, '%Y-%m-%d')
                        age = datetime.now() - listing_datetime
                        
                        if age.days > 1:
                            logger.debug(f"      ⏭️ Atlandı: {age.days} gün önce ({listing_date})")
                            self.stats['total_listings_filtered'] += 1
                            return None
                except Exception as e:
                    logger.debug(f"      ⚠️ Tarih parse hatası: {listing_date} - {e}")
        
        # Filtrelerden geçti
        self.stats['total_listings_saved'] += 1
        
        # Metadata ekle
        filtered = listing.copy()
        filtered['source'] = source
        filtered['scraped_at'] = datetime.now().isoformat()
        
        return filtered
    
    def _print_summary(self):
        """Çalışma özeti yazdır"""
        print(f"\n{'='*80}")
        print(f"📊 TOPLAM SONUÇ")
        print(f"{'='*80}")
        print(f"Toplam model denendi: {self.stats['total_models']}")
        print(f"Başarıyla çekilen: {self.stats['models_scraped']}")
        print(f"Toplam ilan bulundu: {self.stats['total_listings_found']}")
        print(f"Filtrelenen: {self.stats['total_listings_filtered']}")
        print(f"Kaydedilen: {self.stats['total_listings_saved']}")
        
        # Database istatistikleri
        if self.enable_db_save:
            print(f"\n💾 DATABASE İSTATİSTİKLERİ:")
            print(f"   ✅ Başarılı: {self.stats['db_saved']}")
            print(f"   ⏭️  Duplicate: {self.stats['db_duplicate']}")
            print(f"   ❌ Başarısız: {self.stats['db_failed']}")
        
        if self.stats['errors']:
            print(f"\n❌ Hatalar: {len(self.stats['errors'])}")
            for error in self.stats['errors'][:5]:  # İlk 5 hata
                print(f"   - {error}")
        
        print(f"{'='*80}\n")


# ─── CLI ARAYÜZ ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Yerimebak AI - Toplu Market Scraper")
    
    # Mod seçimi
    parser.add_argument("--mode", choices=["list", "custom"], required=True,
                       help="Mod: list=listedeki araçlar, custom=istisnai marka")
    
    # Kaynaklar
    parser.add_argument("--sources", nargs="+", default=["arabam"],
                       choices=["arabam"],
                       help="Hangi sitelerden çekilecek (varsayılan: arabam)")
    
    # List modu parametreleri
    parser.add_argument("--priority", type=int, choices=[1, 2, 3], default=1,
                       help="List modu: Öncelik filtresi (1=en yüksek, 3=tümü)")
    parser.add_argument("--segment", type=str,
                       choices=["B", "C", "D", "SUV", "Ticari", "EV"],
                       help="List modu: Segment filtresi")
    
    # Custom modu parametreleri
    parser.add_argument("--brand", type=str,
                       help="Custom modu: Marka (örn: Volvo)")
    parser.add_argument("--model", type=str,
                       help="Custom modu: Model (örn: S60)")
    parser.add_argument("--brands", type=str,
                       help="Custom modu: Çoklu marka (virgülle ayrılmış)")
    
    # Ortak parametreler
    parser.add_argument("--min-year", type=int, default=2012,
                       help="Minimum yıl (varsayılan: 2012)")
    parser.add_argument("--max-year", type=int, default=2026,
                       help="Maksimum yıl (varsayılan: 2026)")
    parser.add_argument("--max-listings", type=int, default=50,
                       help="Her araç için max ilan sayısı (varsayılan: 50)")
    parser.add_argument("--headless", action="store_true", default=True,
                       help="Browser'ı headless modda çalıştır")
    parser.add_argument("--no-24h-filter", action="store_true",
                       help="24 saat filtresini devre dışı bırak")
    
    # Database parametreleri
    parser.add_argument("--no-db-save", action="store_true",
                       help="Database kaydını devre dışı bırak")
    parser.add_argument("--force-save", action="store_true",
                       help="Duplicate olsa bile kaydet (overwrite)")
    
    args = parser.parse_args()
    
    # Scraper'ı başlat
    scraper = BulkMarketScraper(
        sources=args.sources,
        min_year=args.min_year,
        max_year=args.max_year,
        max_listings=args.max_listings,
        headless=args.headless,
        enable_24h_filter=not args.no_24h_filter,
        enable_db_save=not args.no_db_save,
        force_save=args.force_save
    )
    
    # Mod'a göre çalıştır
    async def main():
        if args.mode == "list":
            results = await scraper.scrape_from_list(
                priority_filter=args.priority,
                segment_filter=args.segment
            )
        
        elif args.mode == "custom":
            if args.brands:
                # Çoklu marka: "Volvo S60, Lexus IS" → [("Volvo", "S60"), ("Lexus", "IS")]
                targets = []
                for item in args.brands.split(","):
                    parts = item.strip().split()
                    if len(parts) >= 2:
                        brand = parts[0]
                        model = " ".join(parts[1:])
                        targets.append((brand, model, "Custom"))
                
                results = await scraper.scrape_multiple_custom(targets)
            
            elif args.brand and args.model:
                # Tekil marka
                results = await scraper.scrape_custom(args.brand, args.model)
            
            else:
                print("❌ Hata: Custom modu için --brand/--model veya --brands gerekli")
                return
        
        # Sonuçları kaydet (opsiyonel)
        if results:
            print(f"\n💾 {len(results)} ilan başarıyla çekildi!")
            
            # JSON olarak kaydet
            import json
            filename = f"market_data_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            filepath = Path(__file__).parents[1] / "data" / "raw" / filename
            
            # Dict'leri JSON serializable hale getir
            json_results = []
            for r in results:
                # Enum'ları string'e çevir
                r_copy = {}
                for k, v in r.items():
                    if hasattr(v, 'value'):  # Enum
                        r_copy[k] = v.value
                    elif hasattr(v, '__dict__'):  # Object (PaintInfo, etc.)
                        r_copy[k] = str(v)
                    else:
                        r_copy[k] = v
                json_results.append(r_copy)
            
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(json_results, f, ensure_ascii=False, indent=2)
            
            print(f"💾 Dosya kaydedildi: {filepath}")
    
    asyncio.run(main())