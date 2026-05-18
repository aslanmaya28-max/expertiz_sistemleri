"""
YERİMEBAK AI - Borusan Detailed Scraper v3.0
Boya, Değişen, Hasar, Paket bilgileri ile
ANTİ-BOT SİSTEMİ v3.0 - Arabam v4 pattern
"""
import asyncio
import json
import re
import random
from playwright.async_api import async_playwright
from typing import List, Dict, Any
from datetime import datetime

from yerimebak_ai_v5.core.rate_limiter import get_rate_limiter
from yerimebak_ai_v5.core.logger import get_logger

logger = get_logger(__name__)

# ==================== ANTI-BOT CONSTANTS ====================
USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"

BROWSER_ARGS = [
    '--disable-blink-features=AutomationControlled',  # KRİTİK
    '--disable-dev-shm-usage',
    '--no-sandbox',
    '--disable-setuid-sandbox',
    '--disable-infobars',
    '--disable-extensions',
]

JS_STEALTH_SCRIPTS = """
// Script 1: Hide WebDriver
Object.defineProperty(navigator, 'webdriver', {
    get: () => undefined
});

// Script 2: Fake Plugins
Object.defineProperty(navigator, 'plugins', {
    get: () => [
        { name: 'Chrome PDF Plugin' },
        { name: 'Chrome PDF Viewer' },
        { name: 'Native Client' }
    ]
});

// Script 3: Fake Languages
Object.defineProperty(navigator, 'languages', {
    get: () => ['tr-TR', 'tr', 'en-US', 'en']
});

// Script 4: Fake Hardware
Object.defineProperty(navigator, 'hardwareConcurrency', { get: () => 8 });
Object.defineProperty(navigator, 'deviceMemory', { get: () => 8 });

// Script 5: Clean Automation Traces
delete window.__playwright;
delete window.__pw_manual;
delete window.chrome.runtime;
"""

class BorusanDetailedCollector:
    def __init__(self, headless=True):
        self.headless = headless
        self.rate_limiter = get_rate_limiter()
    
    async def collect_data(self, brand, year_min, year_max):
        """
        Borusan Next'ten detaylı araç bilgileri çeker
        Boya, Değişen, Hasar, Paket bilgileri ile
        """
        logger.info(f"\n{'='*80}")
        logger.info(f"🚀 BORUSAN DETAILED SCRAPER v2.0: {brand} {year_min}-{year_max}")
        logger.info(f"{'='*80}")
        
        results = []
        
        try:
            async with async_playwright() as p:
                await self.rate_limiter.wait_for_slot("borusan.com.tr")
                
                # 🚀 Anti-bot browser launch - 6 browser args
                browser = await p.chromium.launch(
                    headless=self.headless,
                    args=BROWSER_ARGS
                )
                
                # 🛡️ Anti-bot context - Full stealth setup
                context = await browser.new_context(
                    user_agent=USER_AGENT,
                    viewport={"width": 1920, "height": 1080},
                    locale="tr-TR",
                    timezone_id="Europe/Istanbul",
                    geolocation={"latitude": 41.0082, "longitude": 28.9784},
                    permissions=["geolocation"],
                    extra_http_headers={
                        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
                        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                        'Accept-Encoding': 'gzip, deflate, br',
                        'Connection': 'keep-alive',
                        'Upgrade-Insecure-Requests': '1',
                        'Sec-Fetch-Dest': 'document',
                        'Sec-Fetch-Mode': 'navigate',
                        'Sec-Fetch-Site': 'none',
                        'Cache-Control': 'max-age=0'
                    }
                )
                
                # 🔒 JS stealth scripts ekle - 5 script
                await context.add_init_script(JS_STEALTH_SCRIPTS)
                
                page = await context.new_page()
                
                # Borusan Next URL (yeni domain)
                url = f"https://borusannext.com/araba-al?marka={brand.lower()}&yilMin={year_min}&yilMax={year_max}"
                
                logger.info(f"🔗 Borusan Next URL: {url}")
                
                # 🤖 Human-like navigation - random bekleme
                await asyncio.sleep(random.uniform(1.5, 3.0))
                
                # Sayfaya git
                await page.goto(url, wait_until="domcontentloaded", timeout=30000)
                
                # 🕐 Bot detection kontrolü için ek bekleme
                await asyncio.sleep(random.uniform(2.0, 4.0))
                
                # 🚨 Bot tespit kontrolü
                try:
                    page_text = await page.inner_text("body")
                    page_lower = page_text.lower()
                    
                    # Bot tespit keyword'leri
                    bot_keywords = ['robot', 'bot detected', 'captcha', 'access denied', 'blocked', 'yasak', 'engellendi']
                    
                    if any(keyword in page_lower for keyword in bot_keywords):
                        logger.error("🚨 BOT TESPİT EDİLDİ! Screenshot alınıyor...")
                        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                        await page.screenshot(path=f"bot_detected_{timestamp}.png", full_page=True)
                        await browser.close()
                        return results
                        
                except Exception as e:
                    logger.warning(f"Bot detection kontrol hatası: {e}")
                
                logger.info("✅ Bot tespiti yok, devam ediliyor...")
                
                # 📸 Debug screenshot
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                await page.screenshot(path=f"borusan_page_{timestamp}.png", full_page=True)
                logger.info(f"📸 Screenshot kaydedildi: borusan_page_{timestamp}.png")
                
                # 📄 HTML içeriğini kaydet
                page_html = await page.content()
                html_filename = f"borusan_html_{timestamp}.html"
                with open(html_filename, 'w', encoding='utf-8') as f:
                    f.write(page_html)
                logger.info(f"📄 HTML kaydedildi: {html_filename} ({len(page_html)} karakter)")
                
                # 🔍 Araç linklerini ara
                try:
                    # Tüm araç linklerini bul
                    car_links = await page.query_selector_all("a[href*='/ikinci-el/otomobil']")
                    logger.info(f"🔗 Bulunan araç linki sayısı: {len(car_links)}")
                    
                    if car_links:
                        # İlk 3 linki logla
                        for i, link in enumerate(car_links[:3], 1):
                            href = await link.get_attribute('href')
                            text = await link.inner_text()
                            logger.info(f"  [{i}] {text[:50]}... -> {href}")
                except Exception as e:
                    logger.warning(f"Link arama hatası: {e}")
                
                # Next.js data'dan araçları al
                try:
                    next_data = await page.evaluate("""
                        () => {
                            if (window.__NEXT_DATA__ && window.__NEXT_DATA__.props) {
                                return window.__NEXT_DATA__.props.pageProps;
                            }
                            return {};
                        }
                    """)
                    
                    # 🐛 Debug: Next.js data'yı logla
                    logger.info(f"🔍 Next.js data keys: {list(next_data.keys()) if next_data else 'None'}")
                    
                    # Borusan Next kullanıyor - 'datas' key'ini kullan
                    vehicles = []
                    
                    # Önce 'datas' key'ini dene
                    if 'datas' in next_data:
                        vehicles = next_data['datas']
                        logger.info(f"✅ 'datas' key'inden {len(vehicles)} araç alındı")
                    
                    # Fallback: Sayfa içinden selector ile bul
                    if not vehicles:
                        try:
                            links = await page.query_selector_all("a[href*='/araba-al/']")
                            vehicles = []
                            for link in links[:10]:
                                href = await link.get_attribute('href')
                                if href and '/araba-al/' in href:
                                    vehicle_id = href.split('/')[-1]
                                    vehicles.append({'id': vehicle_id, 'url': f"https://borusannext.com{href}"})
                        except:
                            vehicles = []
                    
                except Exception as e:
                    logger.warning(f"Next.js data extraction hatası: {e}")
                    vehicles = []
                
                logger.info(f"✅ {len(vehicles)} araç bulundu")
                
                if not vehicles:
                    logger.warning("⚠️ Araç bulunamadı")
                    await browser.close()
                    return results
                
                # Her araç için detayları çıkar (detail sayfasına GEREK YOK!)
                max_vehicles = min(len(vehicles), 5)
                print(f"\n🔍 Araç Detayları Çıkartılıyor: {max_vehicles}/{len(vehicles)}")
                
                for i, vehicle in enumerate(vehicles[:max_vehicles], 1):
                    try:
                        # 🔥 Tüm veri zaten 'datas' içinde var!
                        vehicle_id = vehicle.get('id')
                        brand_name = vehicle.get('brand', brand)
                        model = vehicle.get('model', '')
                        model_extension = vehicle.get('modelExtension', '')
                        title = f"{brand_name} {model}"
                        
                        print(f"\n  [{i}/{max_vehicles}] Araç işleniyor: {title[:50]}...")
                        
                        # ✅ Doğrudan veriden çıkar
                        listing_detail = await self._extract_from_data(vehicle, brand_name)
                        
                        if listing_detail:
                            results.append(listing_detail)
                            print(f"    ✅ Başarılı: {listing_detail['price']:,} TL | "
                                  f"Boya: {'Var' if vehicle.get('painted', False) else 'Yok'} | "
                                  f"Tramer: {'Var' if vehicle.get('hasTramerRecord', False) else 'Yok'}")
                        
                    except Exception as e:
                        print(f"    ❌ Hata: {e}")
                        import traceback
                        traceback.print_exc()
                        continue
                
                await browser.close()
                
                print(f"\n{'='*80}")
                print(f"✅ TAMAMLANDI: {len(results)} araç başarıyla çekildi")
                print(f"{'='*80}\n")
                
                return results
                
        except Exception as e:
            logger.error(f"❌ Borusan detailed scraper hatası: {e}")
            import traceback
            traceback.print_exc()
            return results
    
    async def _scrape_vehicle_detail(self, browser, vehicle_id: str, basic_data: Dict, brand: str) -> Dict[str, Any]:
        """Araç detay sayfasından TÜM bilgileri çeker"""
        try:
            page = await browser.new_page()
            
            detail_url = f"https://www.borusanoto.com/tr/ikinci-el/otomobil/{vehicle_id}"
            await page.goto(detail_url, wait_until="domcontentloaded", timeout=30000)
            await asyncio.sleep(2)
            
            # Temel bilgiler (JSON'dan)
            title = basic_data.get('title', f"{brand} {basic_data.get('model', '')}")
            price = int(basic_data.get('price', {}).get('amount', 0))
            km = int(basic_data.get('mileage', 0))
            year = int(basic_data.get('year', 0))
            
            # KRİTİK: Boya bilgisi
            paint_info = await self._extract_paint_info(page, basic_data)
            
            # KRİTİK: Hasar bilgisi
            accident_record = await self._extract_accident_info(page, basic_data)
            
            # KRİTİK: Paket bilgileri
            package_info = await self._extract_package_info(page, basic_data)
            
            # Diğer bilgiler
            fuel = basic_data.get('fuelType', '')
            gear = basic_data.get('gearboxType', '')
            color = basic_data.get('color', '')
            
            # Görsel URL
            image_url = await self._extract_image_url(page, basic_data)
            
            await page.close()
            
            if not price:
                return None
            
            return {
                'source': 'borusan',
                'url': detail_url,
                'title': title,
                'price': price,
                'km': km,
                'year': year,
                'fuel_type': fuel,
                'gear_type': gear,
                'color': color,
                'paint_info': paint_info,  # KRİTİK
                'accident_record': accident_record,  # KRİTİK
                'package_info': package_info,  # KRİTİK
                'image_url': image_url,
                'scraped_at': datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"❌ Detay çekme hatası: {e}")
            return None
    
    async def _extract_paint_info(self, page, basic_data: Dict) -> Dict[str, Any]:
        """Boya/değişen bilgisi çıkar"""
        paint_info = {
            'has_paint': False,
            'has_changed': False,
            'is_original': False,
            'details': []
        }
        
        try:
            # Body text'ten kontrol et
            body_text = await page.inner_text("body")
            body_lower = body_text.lower()
            
            # Boya/değişen keyword'leri
            paint_keywords = {
                'boyalı': ['boyalı', 'boyası var', 'boyası mevcut'],
                'değişen': ['değişen', 'parça değişen', 'tramer', 'değişen parça'],
                'orjinal': ['orjinal', 'boyasız', 'değişensiz', 'orijinal', 'perte']
            }
            
            for status, keywords in paint_keywords.items():
                for keyword in keywords:
                    if keyword in body_lower:
                        if status == 'boyalı':
                            paint_info['has_paint'] = True
                            paint_info['details'].append("Boyalı parça")
                        elif status == 'değişen':
                            paint_info['has_changed'] = True
                            paint_info['details'].append("Değişen parça")
                        elif status == 'orjinal':
                            paint_info['is_original'] = True
                            paint_info['details'].append("Boyasız/Değişensiz")
                        break
            
            # Borusan Next API'den kontrol et
            try:
                # Page'deki Next.js data'yı çek
                next_data = await page.evaluate("""
                    () => {
                        return window.__NEXT_DATA__ || {};
                    }
                """)
                
                if next_data:
                    vehicle_data = next_data.get('props', {}).get('pageProps', {}).get('vehicle', {})
                    
                    if vehicle_data:
                        # Borusan "Durum" alanı
                        condition = vehicle_data.get('condition', {})
                        if condition.get('isPerte', False):
                            paint_info['is_original'] = True
                            paint_info['details'].append("Perte (Boyasız)")
                        
                        if condition.get('hasPaint', False):
                            paint_info['has_paint'] = True
                            paint_info['details'].append("Boyalı")
                        
                        if condition.get('hasChanged', False):
                            paint_info['has_changed'] = True
                            paint_info['details'].append("Değişen parça")
                        
            except Exception as e:
                print(f"Next.js data hatası: {e}")
            
        except Exception as e:
            print(f"Boya bilgisi hatası: {e}")
        
        return paint_info
    
    async def _extract_accident_info(self, page, basic_data: Dict) -> str:
        """Hasar/tramer bilgisi çıkar"""
        try:
            # Body text kontrolü
            body_text = await page.inner_text("body")
            body_lower = body_text.lower()
            
            if any(phrase in body_lower for phrase in ['hasarsız', 'hasar kaydı yok', 'tramer yok']):
                return 'Yok'
            
            if any(phrase in body_lower for phrase in ['hasar kaydı var', 'hasarlı', 'tramer var']):
                return 'Var'
            
            # Borusan API'den kontrol et
            try:
                next_data = await page.evaluate("""
                    () => {
                        return window.__NEXT_DATA__ || {};
                    }
                """)
                
                if next_data:
                    vehicle_data = next_data.get('props', {}).get('pageProps', {}).get('vehicle', {})
                    condition = vehicle_data.get('condition', {})
                    
                    if not condition.get('hasAccident', True):
                        return 'Yok'
                    elif condition.get('hasAccident', False):
                        return 'Var'
                        
            except:
                pass
            
            return 'Bilinmiyor'
            
        except:
            return 'Bilinmiyor'
    
    async def _extract_package_info(self, page, basic_data: Dict) -> List[str]:
        """Paket/ekipman bilgisi çıkar"""
        packages = []
        
        try:
            # Body text'ten ekipmanları çıkar
            body_text = await page.inner_text("body").lower()
            
            package_keywords = [
                'navigation', 'navigasyon',
                'sunroof', 'cam tavan',
                'deri koltuk', 'deri döşeme',
                'ısıtmalı koltuk', 'heated seat',
                'ventilated', 'havalı koltuk',
                'park sensor', 'park sensörü',
                'kamera', 'geri görüş',
                'bluetooth',
                'cruise control', 'hız sabitleyici',
                'adaptive cruise', 'akıllı cruise',
                'led far', 'led headlight',
                'xenon',
                'alüminyum jant', 'alloy wheel',
                'iklim kontrolü', 'climate control',
                'otomatik klima',
                'panoramik cam tavan',
                'head up display', 'hud',
                'koltuk belleği', 'memory seat',
                'elektrikli koltuk'
            ]
            
            for package in package_keywords:
                if package in body_text:
                    package_display = package.capitalize()
                    if package_display not in str(packages).lower():
                        packages.append(package_display)
            
            # Borusan Next API'den özellikleri al
            try:
                next_data = await page.evaluate("""
                    () => {
                        return window.__NEXT_DATA__ || {};
                    }
                """)
                
                if next_data:
                    vehicle_data = next_data.get('props', {}).get('pageProps', {}).get('vehicle', {})
                    features = vehicle_data.get('features', [])
                    
                    if features:
                        for feature in features[:20]:
                            feature_name = feature.get('name', feature.get('title', ''))
                            if feature_name and len(feature_name) < 50:
                                if feature_name not in packages:
                                    packages.append(feature_name)
                                    
            except Exception as e:
                print(f"Next.js features hatası: {e}")
                        
        except Exception as e:
                        print(f"Paket bilgisi hatası: {e}")
        
        return packages[:15]  # En fazla 15 paket
    
    async def _extract_from_data(self, vehicle: Dict, brand_name: str) -> Dict[str, Any]:
        """
        Doğrudan 'datas' objesinden araç bilgilerini çıkarır
        DETAY SAYFASINA GEREK YOK!
        
        Args:
            vehicle: Next.js 'datas' objesi
            brand_name: Marka adı
            
        Returns:
            Araç detayları dict
        """
        try:
            # Temel bilgiler
            vehicle_id = vehicle.get('id')
            model = vehicle.get('model', '')
            model_extension = vehicle.get('modelExtension', '')
            year = vehicle.get('year', 0)
            km = vehicle.get('km', 0)
            
            # Fiyat bilgisi
            price = vehicle.get('salePrice') or vehicle.get('currentListingPrice', 0)
            
            # Teknik bilgiler
            fuel_type = vehicle.get('fuelType', '')
            gear_type = vehicle.get('gearType', '')
            paint_color = vehicle.get('paint', '')
            case_type = vehicle.get('caseType', '')
            
            # KRİTİK: Boya/değişen/hasar bilgileri
            painted = vehicle.get('painted', False)
            part_changed = vehicle.get('partChanged', False)
            has_tramer = vehicle.get('hasTramerRecord', False)
            
            paint_info = {
                'has_paint': painted,
                'has_changed': part_changed,
                'is_original': not painted and not part_changed,
                'details': []
            }
            
            if painted:
                paint_info['details'].append("Boyalı")
            if part_changed:
                paint_info['details'].append("Değişen parça")
            if not painted and not part_changed:
                paint_info['details'].append("Boyasız/Değişensiz")
            
            # Hasar/tramer bilgisi
            accident_record = 'Var' if has_tramer else 'Yok'
            
            # Görseller
            listing_photos = vehicle.get('listingPhotos', [])
            all_photos = vehicle.get('allPhotos', [])
            image_url = listing_photos[0] if listing_photos else (all_photos[0] if all_photos else '')
            
            # URL
            announcement_no = vehicle.get('announcementNo', '')
            detail_url = f"https://borusannext.com{vehicle.get('detailUrl', '')}/{announcement_no}" if announcement_no else ''
            
            # Başlık
            title = f"{brand_name} {model} {model_extension}".strip()
            
            if not price:
                return None
            
            return {
                'source': 'borusan',
                'url': detail_url,
                'title': title,
                'price': int(price),
                'km': int(km),
                'year': int(year),
                'fuel_type': fuel_type,
                'gear_type': gear_type,
                'color': paint_color,
                'paint_info': paint_info,
                'accident_record': accident_record,
                'package_info': [],  # Borusan API'de paket bilgisi yok
                'image_url': image_url,
                'scraped_at': datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"❌ _extract_from_data hatası: {e}")
            import traceback
            traceback.print_exc()
            return None
    
    async def _extract_image_url(self, page, basic_data: Dict) -> str:
        """
        Araç görsel URL'sini çeker
        
        Args:
            page: Playwright page object
            basic_data: Temel araç verileri
            
        Returns:
            Görsel URL string veya boş string
        """
        # Önce basic_data'dan görsel URL'sini dene
        if basic_data:
            # Borusan API'den gelen görsel URL'si
            images = basic_data.get('images', [])
            if images and len(images) > 0:
                first_image = images[0]
                if isinstance(first_image, dict):
                    img_url = first_image.get('url', first_image.get('src', ''))
                    if img_url:
                        return img_url
                elif isinstance(first_image, str):
                    return first_image
        
        # Sayfadan selector ile çek
        selectors = [
            # Borusan görsel selector'ları
            "img[class*='vehicle']",
            "img[class*='car']",
            "img[class*='gallery']",
            "img[class*='detail']",
            # Next.js image component
            "img[src*='borusanoto']",
            # Generic selectors
            ".image img",
            ".photo img",
            "figure img",
            # Fallback
            "img[src]",
        ]
        
        for selector in selectors:
            try:
                element = await page.query_selector(selector)
                if element:
                    src = await element.get_attribute('src')
                    if src and self._is_valid_image_url(src):
                        return src
            except Exception:
                continue
        
        return ''
    
    def _is_valid_image_url(self, url: str) -> bool:
        """
        URL'nin geçerli bir görsel URL'si olup olmadığını kontrol eder
        
        Args:
            url: Kontrol edilecek URL
            
        Returns:
            True ise geçerli görsel URL
        """
        if not url:
            return False
        
        # Görsel uzantıları veya yaygın görsel pattern'ları
        valid_patterns = [
            '.jpg', '.jpeg', '.png', '.webp', '.gif',
            '/images/', '/img/', '/photo/', '/picture/',
            'borusanoto', 'cdn'
        ]
        
        url_lower = url.lower()
        return any(pattern in url_lower for pattern in valid_patterns)


# ─────────────────────────────────────────────────────────────
# TEST KODU
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    import asyncio
    
    async def test():
        collector = BorusanDetailedCollector(headless=False)
        
        # Test: Volkswagen, 2020-2023
        results = await collector.collect_data(
            brand="Volkswagen",
            year_min=2020,
            year_max=2023
        )
        
        print(f"\n✅ Toplam {len(results)} araç çekildi")
        
        if results:
            # İlk aracın detaylarını göster
            first = results[0]
            print(f"\n🔍 Örnek Araç:")
            print(f"  Başlık: {first['title']}")
            print(f"  Fiyat: {first['price']:,} TL")
            print(f"  KM: {first['km']:,}")
            print(f"  Yıl: {first['year']}")
            print(f"  Görsel URL: {first.get('image_url', 'YOK')}")
            print(f"  Boya Bilgisi: {first['paint_info']}")
            print(f"  Paket Sayısı: {len(first.get('package_info', []))}")
            
            # Görsel URL'si var mı kontrol et
            if first.get('image_url'):
                print(f"\n✅ GÖRSEL BAŞARILI: {first['image_url'][:80]}...")
            else:
                print(f"\n⚠️ Görsel bulunamadı")
    
    asyncio.run(test())
