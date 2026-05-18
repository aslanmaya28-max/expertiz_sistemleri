# -*- coding: utf-8 -*-
"""
YERİMEBAK AI - Bulk Scraper Worker v2
Türkiye 2. el piyasası hedef listesinden otomatik veri çeker.
"""
import asyncio
import json
import time
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Any
import sys

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent))
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from yerimebak_ai_v5.scrapers.arabam_detailed import ArabamDetailedCollector
from yerimebak_ai_v5.scrapers.borusan_smart import BorusanSmartScraper
from yerimebak_ai_v5.workers.db_service import get_db_service
from yerimebak_ai_v5.workers.turkey_targets import get_priority_queue, get_years_for_segment, SEGMENT_LABELS

_db_service = get_db_service()

class BulkScraperWorker:
    """
    Türkiye 2. el piyasası hedef listesinden otomatik veri çeken worker.
    Kapsam: 45 model | B/C/D/SUV/Ticari/EV | 2015–2024 | Arabam+Borusan
    """

    def __init__(self, headless: bool = False):
        self.headless = headless
        self.collected_data = {
            'total_listings': 0,
            'by_source': {},
            'by_segment': {},
            'failures': [],
            'scraped_at': datetime.now().isoformat()
        }

        self.scrapers = {
            'arabam':  ArabamDetailedCollector(headless=True),
            'borusan': BorusanSmartScraper()
        }

    async def run_bulk_scraping(self, max_vehicles: int = None):
        """
        Bulk scraping işlemini öncelik sırasıyla başlat.
        Args:
            max_vehicles: Kaç marka/model işlenecek (None = hepsi)
        """
        targets = get_priority_queue(max_vehicles)

        print("\n" + "="*100)
        print("  YERİMEBAK AI - BULK SCRAPER WORKER v2")
        print("="*100)
        print(f"\n📅 Başlangıç : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"🎯 Hedef     : {len(targets)} model (Türkiye 2. el top-sellers)")
        
        for seg, label in SEGMENT_LABELS.items():
            seg_models = [t for t in targets if t[2] == seg]
            if seg_models:
                print(f"   {label}: {len(seg_models)} model")
        
        tahmini_kombo = sum(len(get_years_for_segment(t[2])) for t in targets)
        print(f"🔗 Tahmini kombinasyon : {tahmini_kombo} | İlan tahmini: ~{tahmini_kombo*10:,}–{tahmini_kombo*15:,}")
        print("\n" + "="*100 + "\n")

        start_time = time.time()
        processed_count = 0

        for brand, model, segment, priority in targets:
            years = get_years_for_segment(segment)
            seg_label = SEGMENT_LABELS.get(segment, segment)
            print(f"\n{'='*80}")
            print(f"  {seg_label} | {brand} {model} | Öncelik: {priority}")
            print(f"{'='*80}")

            for year in years:
                try:
                    processed_count += 1
                    print(f"\n  [{processed_count}] {brand} {model} {year}")

                    all_listings = await self._scrape_all_sources(brand, model, year)

                    # DB'ye kalıcı kaydet (duplikat korumalı)
                    for src_key in ['arabam', 'borusan']:
                        src_listings = [
                            l for l in all_listings
                            if l.get('source', '').lower().startswith(src_key)
                        ]
                        if src_listings:
                            try:
                                _db_service.save_listings(src_listings, src_key)
                            except Exception as db_err:
                                print(f"     ⚠️  DB kayit hatasi ({src_key}): {db_err}")

                    # İstatistikler
                    for listing in all_listings:
                        ls = listing.get('source', 'unknown')
                        self.collected_data['by_source'][ls] = self.collected_data['by_source'].get(ls, 0) + 1
                        self.collected_data['by_segment'][segment] = self.collected_data['by_segment'].get(segment, 0) + 1
                        self.collected_data['total_listings'] += 1

                    db_total = self.collected_data['total_listings']
                    print(f"     ✅ {len(all_listings)} ilan | DB toplam: {db_total}")
                    await asyncio.sleep(3)

                except Exception as e:
                    print(f"     ❌ Hata: {e}")
                    continue

            await asyncio.sleep(5)

        elapsed = time.time() - start_time
        print(f"\n{'='*100}")
        print(f"  TAMAMLANDI | Toplam: {self.collected_data['total_listings']} ilan | Süre: {elapsed/60:.1f} dk")
        
        if self.collected_data['failures']:
            print(f"  ⚠️  Başarısızlıklar ({len(self.collected_data['failures'])}):")
            for fail in self.collected_data['failures'][:10]:
                print(f"    - {fail['source']}: {fail['brand']} {fail['model']} {fail['year']}")
            if len(self.collected_data['failures']) > 10:
                print(f"    ... ve {len(self.collected_data['failures'])-10} tane daha.")
        
        print(f"{'='*100}\n")

        self._save_results()

    async def _scrape_all_sources(self, brand: str, model: str, year: int) -> List[Dict[str, Any]]:
        """Tüm kaynaklardan veri çek (paralel)"""
        tasks = [
            self._scrape_source('arabam', brand, model, year),
            self._scrape_source('borusan', brand, year, year)
        ]
        
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        all_listings = []
        for result in results:
            if isinstance(result, list):
                all_listings.extend(result)
        
        return all_listings
    
    async def _scrape_source(self, source: str, brand: str, model: str, year: int) -> List[Dict[str, Any]]:
        """Tek bir kaynaktan veri çek"""
        try:
            print(f"     → {source.capitalize()}...", end=" ", flush=True)
            
            scraper = self.scrapers.get(source)
            if not scraper:
                print("❌ Scraper bulunamadı")
                return []
            
            # Borusan için farklı signature
            if source == 'borusan':
                listings = await scraper.collect_data(brand, year, year)
            else:
                listings = await scraper.collect_data(brand, model, year)
            
            if not listings or len(listings) == 0:
                # Başarısızlığı kaydet
                self.collected_data['failures'].append({
                    'source': source, 'brand': brand, 'model': model, 'year': year
                })
                print("⚠️ 0 ilan")
            else:
                print(f"✅ {len(listings)} ilan")
                
            return listings
            
        except Exception as e:
            print(f"❌ {e}")
            return []
    
    def _save_results(self):
        """Sonuçları JSON dosyasına kaydet"""
        output_file = Path("bulk_scraping_results.json")
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(self.collected_data, f, indent=2, ensure_ascii=False)

async def main():
    """Ana worker fonksiyonu"""
    worker = BulkScraperWorker(headless=False)
    # Test için: İlk 5 araç
    await worker.run_bulk_scraping(max_vehicles=5)

if __name__ == "__main__":
    asyncio.run(main())