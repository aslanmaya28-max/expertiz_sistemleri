"""
YERİMEBAK AI - Arabam Detailed Scraper v2.1
Boya, Değişen, Hasar, Paket bilgileri ile. Merkezi Repository kullanır.
"""
import asyncio
import re
import random
import json
from playwright.async_api import async_playwright
from typing import List, Dict, Any
from datetime import datetime

from yerimebak_ai_v5.core.rate_limiter import get_rate_limiter
from yerimebak_ai_v5.core.logger import get_logger
from yerimebak_ai_v5.core.repository import get_repository
from yerimebak_ai_v5.core.database_config import DatabaseConfig

logger = get_logger(__name__)

class ArabamDetailedCollector:
    def __init__(self, headless=True):
        self.headless = headless
        self.rate_limiter = get_rate_limiter()
        self.repository = get_repository()
        self._db_type = DatabaseConfig._get_db_type()
    
    @property
    def _p(self):
        return "%s"
    
    async def collect_data(self, brand, model, year, only_new: bool = False):
        """
        Arabam.com'dan detaylı araç bilgileri çeker
        Boya, Değişen, Hasar, Paket bilgileri ile
        """
        logger.info(f"\n{'='*80}")
        logger.info(f"🚀 ARABAM DETAILED SCRAPER v2.0: {brand} {model} {year}")
        logger.info(f"{'='*80}")
        
        results = []
        
        try:
            async with async_playwright() as p:
                await self.rate_limiter.wait_for_slot("arabam.com")
                
                browser = await p.chromium.launch(
                    headless=self.headless,
                    args=[
                        '--disable-blink-features=AutomationControlled',
                        '--disable-dev-shm-usage',
                        '--no-sandbox',
                        '--disable-web-security'
                    ]
                )
                
                context = await browser.new_context(
                    user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36",
                    viewport={'width': 1920, 'height': 1080},
                    locale='tr-TR',
                    extra_http_headers={
                        'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
                        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
                        'Connection': 'keep-alive',
                        'Upgrade-Insecure-Requests': '1'
                    }
                )
                
                # Gelişmiş Anti-Bot Stealth
                await context.add_init_script("""
Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
Object.defineProperty(navigator, 'languages', { get: () => ['tr-TR', 'tr', 'en-US', 'en'] });
window.chrome = { runtime: {} };
""")
                
                page = await context.new_page()
                
                # Arama URL'i (Slug Mapping)
                model_slug = model.lower().strip()
                # Özel eşleşmeler (Slug Mapping)
                slug_map = {
                    "3 serisi": "3-serisi", "5 serisi": "5-serisi", "1 serisi": "1-serisi",
                    "t-roc": "t-roc", "t-cross": "t-cross", "c-elysee": "c-elysee",
                    "c-hr": "c-hr", "model y": "model-y", "t10x": "t10x"
                }
                model_path = slug_map.get(model_slug, model_slug.replace(" ", "-"))
                
                # SADECE SON 24 SAAT: &date=1
                url = f"https://www.arabam.com/ikinci-el/otomobil/{brand.lower()}-{model_path}?minYear={year}&maxYear={year}"
                if only_new:
                    url += "&date=1"
                
                logger.info(f"🔗 URL: {url}")
                await page.goto(url, wait_until="domcontentloaded", timeout=60000)
                await asyncio.sleep(random.uniform(2, 4))
                
                # Human-like scroll
                for i in range(5):
                    await page.mouse.wheel(0, random.randint(300, 600))
                    await asyncio.sleep(random.uniform(0.5, 1.0))
                
                # İlan linklerini bul
                listing_links = await self._extract_listing_links(page, brand, model, year)
                logger.info(f"\n📊 Bulunan İlan Linkleri: {len(listing_links)}")
                
                if not listing_links:
                    logger.warning(f"⚠️ İlan bulunamadı: {brand} {model} {year}")
                    # Screenshot al (Neden bulunamadı? Blok?)
                    try:
                        ts = datetime.now().strftime("%H%M%S")
                        filename = f"arabam_diag_{brand}_{model}_{ts}.png"
                        await page.screenshot(path=filename)
                        logger.info(f"📸 Teşhis ekran görüntüsü alındı: {filename}")
                    except: pass
                    
                    await browser.close()
                    return results
                
                # Detayları çek (max 15 ilan - tam performans)
                max_listings = min(len(listing_links), 15)
                print(f"\n🔍 İlan Detayları Çekiliyor: {max_listings}/{len(listing_links)}")
                
                for i, link_info in enumerate(listing_links[:max_listings], 1):
                    try:
                        print(f"\n  [{i}/{max_listings}] İlan çekiliyor: {link_info['title'][:50]}...")
                        
                        # İnsan gibi bekle
                        await asyncio.sleep(random.uniform(2, 3))
                        
                        # ── DB kontrolü (zaten var mı?) ────────────────────────────
                        if self._url_exists_in_db(link_info['url']):
                            print(f"    ⏭️  Atlandı: Zaten DB'de mevcut.")
                            continue

                        # ── STRICT RELEVANCY FILTER ──────────────────────────
                        if not self._is_relevant(link_info['title'], brand, model):
                            print(f"    ⏭️  Atlandı: İlgisiz İlan (Relevancy Failure)")
                            continue

                        # Detay sayfasına git
                        listing_detail = await self._scrape_listing_detail(browser, link_info['url'])
                        
                        if listing_detail:
                            results.append(listing_detail)
                            print(f"    ✅ Başarılı: {listing_detail['price']:,} TL | "
                                  f"Boya: {'Var' if listing_detail['paint_info'].get('has_paint') else 'Yok'} | "
                                  f"Paket: {len(listing_detail.get('package_info', []))} ekipman")
                        
                    except Exception as e:
                        print(f"    ❌ Hata: {e}")
                        continue
                
                await browser.close()
                
                print(f"\n{'='*80}")
                print(f"✅ TAMAMLANDI: {len(results)} ilan başarıyla çekildi")
                print(f"{'='*80}\n")
                
                return results
                
        except Exception as e:
            logger.error(f"❌ Arabam detailed scraper hatası: {e}")
            import traceback
            traceback.print_exc()
            return results
    
    def _url_exists_in_db(self, url: str) -> bool:
        """URL'nin DB'de zaten var olup olmadığını kontrol eder."""
        try:
            conn = DatabaseConfig.get_connection()
            cur = conn.cursor()
            cur.execute(f"SELECT id FROM listings WHERE url = {self._p}", (url,))
            result = cur.fetchone()
            conn.close()
            return result is not None
        except Exception:
            return False

    async def _extract_listing_links(self, page, brand, model, year) -> List[Dict[str, Any]]:
        """İlan linklerini çıkar"""
        links = []
        
        selectors = [
            ("a[href*='/ilan/']", "İlan link"),
        ]
        
        for selector, desc in selectors:
            try:
                print(f"🔍 Selector deneniyor: {desc}")
                elements = await page.query_selector_all(selector)
                
                print(f"   Bulunan: {len(elements)} element")
                
                if elements and len(elements) >= 3:
                    logger.info(f"✅ Selector çalıştı: {selector}")
                    
                    for el in elements:
                        try:
                            href = await el.get_attribute('href')
                            if href and ('/ilan/' in href or '/detay/' in href):
                                full_url = href if href.startswith('http') else f"https://www.arabam.com{href}"
                                
                                # Sponsorlu linkleri ve duplicate'leri ele
                                if "featuredad" in full_url.lower(): continue
                                
                                if not any(l['url'] == full_url for l in links):
                                    try:
                                        title = await el.inner_text()
                                        title = title.strip()[:100]
                                    except:
                                        title = f"{brand} {model}"
                                    
                                    # Relevancy check disabled for link extraction
                                    # if not self._is_relevant(title, brand, model):
                                    #     print(f"   ⏭️  İlgisiz ilan atlandı: {title[:30]}")
                                    #     continue

                                    links.append({
                                        'url': full_url,
                                        'title': title,
                                        'brand': brand,
                                        'model': model,
                                        'year': year
                                    })
                                    
                                    print(f"   ✅ Link eklendi: {title[:50]}...")
                                
                                if len(links) >= 10:
                                    break
                        except Exception as e:
                            print(f"   ⚠️ Link işleme hatası: {e}")
                            continue
                    
                    if len(links) >= 5:
                        print(f"✅ {len(links)} link bulundu, devam ediliyor")
                        break
                        
            except Exception as e:
                print(f"⚠️ Selector başarısız: {selector} - {e}")
                continue
        
        print(f"\n📊 TOPLAM: {len(links)} ilan linki bulundu")
        return links

    def _is_relevant(self, text: str, brand: str, model: str) -> bool:
        """
        Check if the text (title/description) is relevant to brand and model.
        Forced True in v6.1 to ensure maximum data flow.
        """
        return True
    
    async def _scrape_listing_detail(self, browser, listing_url: str) -> Dict[str, Any]:
        """İlan detay sayfasından TÜM bilgileri çeker"""
        try:
            page = await browser.new_page()
            await page.goto(listing_url, wait_until="domcontentloaded", timeout=30000)
            await asyncio.sleep(random.uniform(2, 3))
            
            # Temel bilgiler (Eski metodlar korunarak, Specs Tablosu ile zenginleştiriliyor)
            title = await self._extract_text(page, "h1", "")
            price = await self._extract_price(page)
            km = await self._extract_km(page)
            year = await self._extract_year(page)
            fuel = await self._extract_fuel_type(page)
            gear = await self._extract_gear_type(page)
            color = await self._extract_color(page)
            image_url = await self._extract_image_url(page)
            description = await self._extract_text(page, ".classified-description", "")
            if not description:
                # Fallback for alternative description containers
                description = await self._extract_text(page, "#classifiedDescription", "")
            
            # KRİTİK: Boya, Hasar ve Paket
            paint_info = await self._extract_paint_info(page)
            accident_record = await self._extract_accident_info(page)
            package_info = await self._extract_package_info(page)

            # Teknik Bilgiler (Tablo) - Arabam.com teknik tablo
            # Birden fazla DOM yapsını dene (Arabam zaman zaman değiştiriyor)
            specs = {}
            try:
                SPEC_SELECTORS = [
                    ".list-detail li, .property-view li",
                    "[class*='specification'] li",
                    "[class*='detail-property'] li",
                    "[data-testid='technical-details'] li",
                    "[class*='tech-specs'] li",
                    "[class*='techSpecs'] li",
                    ".classified-properties li",
                ]
                for sel in SPEC_SELECTORS:
                    rows_sel = await page.query_selector_all(sel)
                    if rows_sel:
                        for row in rows_sel:
                            key_el = await row.query_selector(".property-key, [class*='key'], [class*='label'], dt")
                            val_el = await row.query_selector(".property-value, [class*='value'], [class*='val'], dd")
                            if key_el and val_el:
                                key = (await key_el.inner_text()).strip().replace(":", "")
                                val = (await val_el.inner_text()).strip()
                                specs[key] = val
                        if specs:
                            break
                # Fallback: DL/DT/DD yapısı
                if not specs:
                    dts = await page.query_selector_all("dl dt")
                    for dt in dts:
                        dd = await dt.evaluate_handle("el => el.nextElementSibling")
                        try:
                            key = (await dt.inner_text()).strip().replace(":", "")
                            val = (await dd.inner_text()).strip()
                            if key and val:
                                specs[key] = val
                        except:
                            pass
            except:
                pass

            # Garanti bilgisi
            guarantee = specs.get("Garanti", specs.get("garanti", ""))
            if not guarantee:
                try:
                    body_txt = (await page.inner_text("body")).lower()
                    if "garantili" in body_txt or "fabrika garantisi" in body_txt:
                        guarantee = "Evet"
                except:
                    pass

            # 🛠️ New Engine Specs Extraction Logic
            engine_size = specs.get("Motor Hacmi", "")
            horsepower = specs.get("Motor Gücü", "")

            # If technical labels are empty or "Belirtilmemiş", parse from title or specs context
            if not engine_size or "belirtil" in engine_size.lower():
                # Try to parse from title or other specs (like Model/Seri)
                search_txt = f"{title} {specs.get('Model', '')} {specs.get('Seri', '')}"
                m_sz = re.search(r'\b([0-2]\.[0-9])\b', search_txt)
                if m_sz:
                    engine_size = f"{m_sz.group(1)}L"
                else:
                    m_cc = re.search(r'\b(1[1-9]00|2[0-9]00)\b', search_txt)
                    if m_cc:
                        engine_size = f"{float(m_cc.group(1))/1000:.1f}L"

            if not horsepower or "belirtil" in horsepower.lower():
                search_txt = f"{title} {specs.get('Model', '')} {specs.get('Seri', '')}"
                m_hp = re.search(r'(\d{2,3})\s*(?:hp|bg|ps|beygir)', search_txt, re.I)
                if m_hp:
                    horsepower = f"{m_hp.group(1)} HP"
                else:
                    # Contextual pattern (num after displacement)
                    m_ctx = re.search(r'(?:1\.[3-6]|2\.0)\s+(?:\w+\s+)?(\d{2,3})\b', search_txt)
                    if m_ctx:
                        val = int(m_ctx.group(1))
                        if 60 <= val <= 400:
                            horsepower = f"{val} HP"

            # Verileri tabloya göre eşle (Tablo varsa ezsin)
            final_brand = specs.get("Marka", "")
            
            # Eğer tablo boşsa veya geçersizse (örn: 'Galeriden') başlıktan akıllı ayrıştırma
            if not final_brand or final_brand.lower() in ['galeriden', 'sahibinden', 'belirtilmemiş']:
                # Başlıktan marka bul (Daha geniş liste)
                KNOWN_BRANDS = [
                    "Renault", "Fiat", "Volkswagen", "Hyundai", "Ford", "Opel", "Dacia", "Peugeot", 
                    "Citroen", "Seat", "Suzuki", "Nissan", "Toyota", "Honda", "BMW", "Mercedes", 
                    "Skoda", "Audi", "Mazda", "Subaru", "Volvo", "Lexus", "Cupra", "MG", "Chery", "Togg", "Tesla"
                ]
                title_search = title.lower()
                for b in KNOWN_BRANDS:
                    if b.lower() in title_search:
                        final_brand = b
                        break
                if not final_brand and title:
                    # Hala yoksa ilk kelimeye bak ama 'Galeriden', 'Satılık' gibi kelimeleri temizleyerek
                    clean_title = re.sub(r'^(Galeriden|Sahibinden|Satılık|İkinci El|Acil)\s+', '', title, flags=re.I)
                    final_brand = clean_title.split()[0] if clean_title else "Belirtilmemiş"

            final_series = specs.get("Seri", "")
            final_model = specs.get("Model", "")
            
            # Eğer seri/model eksikse başlıktan akıllı ayrıştırma (Fallback)
            if not final_series or not final_model:
                # Başlığı temizle
                noise = r'^(Galeriden|Sahibinden|Satılık|İkinci El|Acil|Hatasız|Boyasız|Düşük KM)\s+'
                title_clean = re.sub(noise, '', title, flags=re.I)
                title_clean = title_clean.replace(final_brand, "").strip()
                parts = title_clean.split()
                if not final_series and len(parts) > 0: final_series = parts[0]
                if not final_model and len(parts) > 1: final_model = " ".join(parts[1:3]) # Daha kompakt al
                elif not final_model: final_model = final_series

            await page.close()

            if not price:
                return None

            # fuel_type / gear_type (specs'ten al önce)
            final_fuel = specs.get("Yakıt Tipi", fuel)
            final_gear = specs.get("Vites Tipi", gear)

            # Seri: specs tablosundan, yoksa başlıktan akllı ayrıştırma
            final_series = specs.get("Seri", "")
            if not final_series and final_model:
                final_series = final_model.split()[0] if " " in final_model else final_model

            return {
                'source': 'arabam',
                'url': listing_url,
                'title': title,
                'brand': final_brand,
                'series': final_series,
                'model': final_model,
                'year': int(str(specs.get("Model Yılı", year)).replace(".", "")) if specs.get("Model Yılı") else year,
                'price': price,
                'km': int(str(specs.get("Kilometre", km)).replace(".", "").replace(" km", "").strip()) if specs.get("Kilometre") else km,
                # DB alan bireşitirme: fuel_type VE fuel, gear_type VE transmission
                'fuel_type': final_fuel,
                'fuel':      final_fuel,
                'gear_type': final_gear,
                'transmission': final_gear,
                'color': specs.get("Renk", color),
                'engine_size': engine_size or specs.get("Motor Hacmi", ""),
                'horsepower': horsepower or specs.get("Motor Gücu", ""),
                'body_type': specs.get("Kasa Tipi", "Sedan"),
                'guarantee': guarantee,
                'paint_info': paint_info,
                'accident_record': accident_record,
                'package_info': package_info,
                'image_url': image_url,
                'description': description,
                'location': specs.get("İl / İlçe", ""),
                'listing_date': specs.get("İlan Tarihi", datetime.now().strftime("%Y-%m-%d")),
                'scraped_at': datetime.now().isoformat()
            }
            
        except Exception as e:
            print(f"❌ Detay çekme hatası: {e}")
            return None
    
    async def _extract_paint_info(self, page) -> Dict[str, Any]:
        """Boya/değişen bilgisi — Arabam 'Boya, Değişen ve Tramer' bölümünden panel bazlı parse"""
        paint_info = {
            'has_paint': False,
            'has_changed': False,
            'is_original': False,
            'painted_parts': [],
            'changed_parts': [],
            'original_parts': [],
            'local_painted_parts': [],
            'details': []
        }
        
        # Bilinen panel adları
        KNOWN_PANELS = {
            'motor kaputu', 'arka kaput', 'tavan', 'ön tampon', 'arka tampon',
            'sol ön çamurluk', 'sağ ön çamurluk', 'sol arka çamurluk', 'sağ arka çamurluk',
            'sol ön kapı', 'sağ ön kapı', 'sol arka kapı', 'sağ arka kapı',
        }
        
        try:
            body_text = await page.inner_text("body")
            lines = body_text.split('\n')
            
            # "Boya, Değişen ve Tramer" bölümünü bul
            boya_section_start = -1
            for i, line in enumerate(lines):
                if 'Boya, Değişen ve Tramer' in line.strip():
                    boya_section_start = i
                    break
            
            if boya_section_start >= 0:
                # Bu bölümdeki satırları parse et
                # Yapı: [Durum Başlığı] → [Panel1] → [Panel2] → ... → [Yeni Durum] → ...
                current_status = None
                for line in lines[boya_section_start + 1:]:
                    txt = line.strip()
                    if not txt or txt == '-':
                        continue
                    txt_lower = txt.lower()
                    
                    # Bölüm sonu kontrolü
                    if 'Tramer tutarı' in txt or 'arabam.com' in txt_lower:
                        break
                    
                    # Durum başlığı mı?
                    if txt_lower in ['orijinal', 'orjinal']:
                        current_status = 'original'
                        continue
                    elif txt_lower in ['boyalı', 'boyali']:
                        current_status = 'painted'
                        continue
                    elif txt_lower in ['lokal boyalı', 'lokal boyali']:
                        current_status = 'local_painted'
                        continue
                    elif txt_lower in ['değişmiş', 'degismis', 'değişen']:
                        current_status = 'changed'
                        continue
                    elif txt_lower in ['belirtilmemiş', 'belirtilmemis']:
                        current_status = 'unknown'
                        continue
                    
                    # Legend metinleri (SVG legend) — atla
                    if txt_lower in ['orijinal', 'boyalı', 'lokal boyalı', 'değişmiş', 'belirtilmemiş',
                                     'açıklama', 'boya, değişen ve tramer']:
                        continue
                    
                    # Panel adı mı kontrol et
                    if current_status and txt_lower in KNOWN_PANELS:
                        if current_status == 'original':
                            paint_info['original_parts'].append(txt)
                            paint_info['is_original'] = True
                        elif current_status == 'painted':
                            paint_info['painted_parts'].append(txt)
                            paint_info['has_paint'] = True
                        elif current_status == 'local_painted':
                            paint_info['painted_parts'].append(f"{txt} (Lokal)")
                            paint_info['has_paint'] = True
                            paint_info['local_painted_parts'].append(txt)
                        elif current_status == 'changed':
                            paint_info['changed_parts'].append(txt)
                            paint_info['has_changed'] = True
            
            # Detay özeti oluştur
            if paint_info['painted_parts']:
                paint_info['details'].append(f"Boyalı: {', '.join(paint_info['painted_parts'])}")
            if paint_info['changed_parts']:
                paint_info['details'].append(f"Değişen: {', '.join(paint_info['changed_parts'])}")
            if paint_info['original_parts']:
                paint_info['details'].append(f"Orijinal: {', '.join(paint_info['original_parts'])}")
            
            # Fallback — eski keyword tabanlı yöntem
            if not paint_info['painted_parts'] and not paint_info['changed_parts'] and not paint_info['original_parts']:
                body_lower = body_text.lower()
                if any(k in body_lower for k in ['boyalı', 'boyası var', 'lokal boya']):
                    paint_info['has_paint'] = True
                    paint_info['painted_parts'].append("Belirtilmemiş Parça (Boya)")
                if any(k in body_lower for k in ['değişen', 'değişmiş']):
                    paint_info['has_changed'] = True
                    paint_info['changed_parts'].append("Belirtilmemiş Parça (Değişen)")
                if any(k in body_lower for k in ['hatasız', 'boyasız', 'orijinal', 'orjinal']):
                    paint_info['is_original'] = True
            
        except Exception as e:
            print(f"Boya bilgisi hatası: {e}")
        
        return paint_info
    
    async def _extract_accident_info(self, page) -> str:
        """Hasar/tramer bilgisi çıkar"""
        try:
            body_text = await page.inner_text("body")
            body_lower = body_text.lower()
            
            # Tramer rakamı ara
            tramer_match = re.search(r'(?:hasar kaydı|tramer)[:\s]*([\d\.]+)\s*(?:tl|₺)', body_lower)
            if tramer_match:
                return f"{tramer_match.group(1)} TL"

            if any(phrase in body_lower for phrase in ['hasarsız', 'hasar kaydı yok', 'tramer yok']):
                return 'Yok'
            
            if any(phrase in body_lower for phrase in ['hasar kaydı var', 'hasarlı', 'tramer var']):
                return 'Var'
            
            return 'Bilinmiyor'
            
        except:
            return 'Bilinmiyor'
    
    async def _extract_package_info(self, page) -> List[str]:
        """Paket/ekipman bilgisi çıkar"""
        packages = []
        
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
        
        try:
            body_text = (await page.inner_text("body")).lower()
            
            for package in package_keywords:
                if package in body_text:
                    # Duplicate kontrolü
                    package_display = package.capitalize()
                    if package_display not in str(packages).lower():
                        packages.append(package_display)
                        
        except Exception as e:
            print(f"Paket bilgisi hatası: {e}")
        
        return packages[:15]  # En fazla 15 paket
    
    async def _extract_text(self, page, selector: str, default: str = "") -> str:
        """Selector'dan metin çıkar"""
        try:
            el = await page.query_selector(selector)
            if el:
                text = await el.inner_text()
                return text.strip()
        except:
            pass
        return default
    
    async def _extract_price(self, page) -> int:
        """Fiyat bilgisi çıkar"""
        selectors = [
            "[class*='price']",
            "[class*='fiyat']"
        ]
        
        for selector in selectors:
            try:
                el = await page.query_selector(selector)
                if el:
                    text = await el.inner_text()
                    match = re.search(r'(\d{1,3}(?:\.\d{3})*)', text)
                    if match:
                        return int(match.group(1).replace('.', ''))
            except:
                continue
        
        return 0
    
    async def _extract_km(self, page) -> int:
        """KM bilgisi çıkar"""
        try:
            body_text = await page.inner_text("body")
            match = re.search(r'(\d{1,3}(?:\.\d{3})+)\s*(?:km|KM)', body_text)
            if match:
                return int(match.group(1).replace('.', ''))
        except:
            pass
        return 0
    
    async def _extract_year(self, page) -> int:
        """Yıl bilgisi çıkar — footer/copyright yılını (2026) hariç tut"""
        try:
            body_text = await page.inner_text("body")
            current_year = datetime.now().year
            # Tüm 4-haneli yılları bul, mevcut yıl ve ilerisini hariç tut
            matches = re.findall(r'\b(20[1-2][0-9])\b', body_text)
            for m in matches:
                yr = int(m)
                if yr <= current_year and yr >= 2010:
                    return yr
        except:
            pass
        return 0
    
    async def _extract_fuel_type(self, page) -> str:
        """Yakıt tipi çıkar"""
        try:
            body_text = (await page.inner_text("body")).lower()
            if 'dizel' in body_text:
                return 'Dizel'
            elif 'benzin' in body_text:
                return 'Benzin'
            elif 'hibrit' in body_text:
                return 'Hibrit'
            elif 'elektrik' in body_text:
                return 'Elektrik'
        except:
            pass
        return ''
    
    async def _extract_gear_type(self, page) -> str:
        """Vites tipi çıkar"""
        try:
            body_text = (await page.inner_text("body")).lower()
            if 'otomatik' in body_text:
                return 'Otomatik'
            elif 'manuel' in body_text or 'düzen' in body_text:
                return 'Manuel'
        except:
            pass
        return ''
    
    async def _extract_color(self, page) -> str:
        """Renk bilgisi çıkar"""
        try:
            body_text = (await page.inner_text("body")).lower()
            colors = {
                'beyaz': 'beyaz',
                'siyah': 'siyah',
                'gri': 'gri',
                'gümüş': 'gümüş',
                'mavi': 'mavi',
                'kırmızı': 'kırmızı',
                'kahve': 'kahverengi',
                'bej': 'bej'
            }
            for color_tr, key in colors.items():
                if color_tr in body_text:
                    return color_tr.capitalize()
        except:
            pass
        return ''
    
    async def _extract_image_url(self, page) -> str:
        """
        İLK FOTOĞRAF KURALI: İlan sayfasındaki yana yana fotoğraflardan İLK FOTOĞRAFI (index 0) al.
        Karmaşık stratejiler yok - sadece ilk fotoğraf.
        """
        
        # İLK FOTOĞRAF: JSON-LD'den ilk image
        try:
            scripts = await page.query_selector_all('script[type="application/ld+json"]')
            for script in scripts:
                content = await script.inner_text()
                data = json.loads(content)
                if isinstance(data, dict):
                    if data.get("@type") in ["Product", "Vehicle", "Car"]:
                        image = data.get("image")
                        # İLK FOTOĞRAF: String'de ilk, list'de index 0
                        if isinstance(image, str) and '/ilanfotograflari/' in image:
                            return image
                        elif isinstance(image, list) and image and '/ilanfotograflari/' in image[0]:
                            return image[0]
        except: pass

        # İLK FOTOĞRAF: __NEXT_DATA__'dan ilk image
        try:
            next_data_script = await page.query_selector('script#__NEXT_DATA__')
            if next_data_script:
                content = await next_data_script.inner_text()
                data = json.loads(content)
                props = data.get('props', {}).get('pageProps', {})
                images = props.get('images', []) or props.get('listing', {}).get('images', [])
                # İLK FOTOĞRAF: Index 0
                if images and isinstance(images, list):
                    img_url = images[0]
                    if isinstance(img_url, str) and '/ilanfotograflari/' in img_url:
                        return img_url
        except: pass

        # İLK FOTOĞRAF: CSS selector - ilk gallery image
        try:
            elements = await page.query_selector_all("img[src*='ilanfotograflari']")
            # İLK FOTOĞRAF: Index 0
            if elements:
                src = await elements[0].get_attribute('src')
                if src:
                    return src
        except: pass
        
        return ''
    
    def _is_valid_image_url(self, url: str) -> bool:
        """
        URL'nin geçerli bir ARAÇ GÖRSELİ URL'si olup olmadığını kontrol eder
        
        Strict validation - Only accept actual vehicle photos
        
        Args:
            url: Kontrol edilecek URL
            
        Returns:
            True ise geçerli araç görseli URL
        """
        if not url:
            return False
        
        # Minimum URL uzunluğu (favicon gibi küçük dosyaları engelle)
        if len(url) < 50:
            return False
        
        url_lower = url.lower()
        
        # BLOCKLIST - Bu kelimeleri içeren URL'leri tamamen engelle
        blocked_keywords = [
            'favicon', 'logo', 'icon', 'avatar', 'badge', 'banner',
            'mini', 'small', 'tiny',
            'assets', 'static', 'dist', 'common'
        ]
        
        for keyword in blocked_keywords:
            if keyword in url_lower:
                return False
        
        # REQUIRED - Araç fotoğrafı pattern'leri (en az biri zorunlu)
        required_patterns = [
            '/ilanfotograflari/',  # Arabam.com resim yolu (EN GEÇERLİ)
            '/images/', '/img/', '/photo/', '/picture/',
            'arabam', 'cdn'
        ]
        
        has_required = any(pattern in url_lower for pattern in required_patterns)
        if not has_required:
            return False
        
        # ALLOWLIST - Sadece gerçek görsel uzantıları
        valid_extensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif']
        has_valid_ext = any(ext in url_lower for ext in valid_extensions)
        
        return has_valid_ext
