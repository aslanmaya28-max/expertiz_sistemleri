# -*- coding: utf-8 -*-
"""
Arabam v4.0 - Main Scraper
Ana scraper sınıfı - tüm bileşenleri orkestrasyon eder
"""

import asyncio
import random
from typing import Optional, List, Dict, Any
from datetime import datetime
from playwright.async_api import Page

from ..models.listing import ArabamListing
from ..models.search_result import ArabamSearchResult
from ..models.enums import FuelType, GearType, Color
from ..core.browser_manager import BrowserManager
from ..core.config.settings import (
    DEFAULT_MAX_LISTINGS,
    MIN_WAIT_BETWEEN_REQUESTS,
    MAX_WAIT_BETWEEN_REQUESTS,
    DEFAULT_WAIT_AFTER_LOAD,
    SCROLL_STEPS,
    MIN_SCROLL_AMOUNT,
    MAX_SCROLL_AMOUNT,
)
from ..utils.url_builder import ArabamURLBuilder
from ..utils.pagination_handler import PaginationHandler
from ..extractors.paint_extractor import PaintExtractor
from ..extractors.package_extractor import PackageExtractor
from ..extractors.damage_extractor import DamageExtractor
from ..extractors.selectors import ArabamSelectors

import logging
from yerimebak_ai_v5.core.security.rate_limiter import get_rate_limiter

logger = logging.getLogger(__name__)


class ArabamScraper:
    """
    Arabam V4.0 - Main Scraper
    
    Letgo v4.0 pattern implementation:
    - 5-layer clean architecture
    - 6 browser args + 5 JS stealth scripts
    - 6+ fallback selectors per field
    - 4 URL fallback formats
    - Paint/changed part extraction (CRITICAL)
    """
    
    def __init__(
        self,
        headless: bool = True,
        max_listings: int = DEFAULT_MAX_LISTINGS,
        skip_detail_scroll: bool = True,
        max_pages: int = 3,
        enable_pagination: bool = True
    ):
        """
        Initialize scraper
        
        Args:
            headless: Headless mode
            max_listings: Maximum listings to scrape
            skip_detail_scroll: Skip scrolling on detail pages (performance optimization)
            max_pages: Maximum pages to scrape (pagination)
            enable_pagination: Enable multi-page extraction
        """
        self.headless = headless
        self.max_listings = max_listings
        self.skip_detail_scroll = skip_detail_scroll
        self.max_pages = max_pages
        self.enable_pagination = enable_pagination
        self.browser_manager: Optional[BrowserManager] = None
        self.url_builder = ArabamURLBuilder()
        self.rate_limiter = get_rate_limiter()
        self.selectors = ArabamSelectors()
        self.pagination_handler = PaginationHandler(
            max_pages=max_pages,
            max_listings=max_listings
        )
    
    async def search(
        self,
        brand: str,
        model: str,
        year: int,
        min_price: Optional[int] = None,
        max_price: Optional[int] = None
    ) -> ArabamSearchResult:
        """
        Araç ara ve sonuçları döndür
        
        Args:
            brand: Marka
            model: Model
            year: Yıl
            min_price: Min fiyat (optional)
            max_price: Max fiyat (optional)
            
        Returns:
            ArabamSearchResult: Arama sonuçları
        """
        start_time = datetime.now()
        
        logger.info(f"\n{'='*80}")
        logger.info(f"🚗 ARABAM V4.0 SCRAPER: {brand} {model} {year}")
        logger.info(f"{'='*80}")
        
        result = ArabamSearchResult(
            query={
                "brand": brand,
                "model": model,
                "year": year,
                "min_price": min_price,
                "max_price": max_price,
            }
        )
        
        try:
            # Rate limit kontrolü
            await self.rate_limiter.wait_for_slot("arabam.com")
            
            # Browser başlat
            self.browser_manager = BrowserManager(headless=self.headless)
            await self.browser_manager.initialize()
            
            # URL'leri oluştur (4 fallback)
            urls = self.url_builder.build_search_urls(brand, model, year, min_price, max_price)
            result.urls_tried = [url_info["url"] for url_info in urls]
            
            logger.info(f"📋 {len(urls)} URL formati oluşturuldu")
            
            # URL fallback ile dene
            for url_info in urls:
                try:
                    logger.info(f"\n🔗 Deneme: {url_info['description']}")
                    logger.info(f"   URL: {url_info['url']}")
                    
                    page = await self.browser_manager.create_page()

                    # Sayfaya git
                    await page.goto(url_info["url"], wait_until="domcontentloaded", timeout=60000)

                    # KRİTİK: JavaScript rendering için bekle
                    await asyncio.sleep(5)

                    # Cookie/popup handle
                    await self._handle_popups(page)

                    # V5.0: Multi-page extraction with pagination
                    if self.enable_pagination:
                        logger.info(f"🔄 Multi-page extraction enabled (max {self.max_pages} pages)")
                        listing_links = await self.pagination_handler.extract_multi_page(
                            page,
                            url_info["url"],
                            brand,
                            model,
                            year
                        )
                    else:
                        # Fallback to single-page extraction
                        await self._human_like_scroll(page)
                        listing_links = await self._extract_listing_links(page, brand, model, year)

                    if listing_links:
                        logger.info(f"✅ {len(listing_links)} ilan bulundu")
                        result.successful_url = url_info["url"]

                        # Detayları çek
                        listings = await self._scrape_listing_details(page, listing_links)
                        result.listings = listings
                        result.successful_count = len(listings)

                        # KRİTİK: Failed count = toplam deneme - başarılı
                        result.failed_count = len(listing_links) - len(listings)
                        break
                    else:
                        logger.warning(f"⚠️ İlan bulunamadı")
                        await page.close()
                        
                except Exception as e:
                    logger.error(f"❌ Hata: {str(e)[:100]}")
                    result.failed_count += 1
                    continue
            
            # İstatistikleri hesapla
            result.calculate_statistics()
            
            # Çalışma süresi
            result.execution_time = (datetime.now() - start_time).total_seconds()
            
        except Exception as e:
            logger.error(f"❌ Critical error: {str(e)}")
            result.errors.append(str(e))
        
        finally:
            # Browser kapat
            if self.browser_manager:
                try:
                    await self.browser_manager.close()
                except Exception as e:
                    logger.warning(f"⚠️ Browser kapatma hatası (İzole edildi): {str(e)[:50]}")
        
        # Sonuç log
        logger.info(f"\n{'='*80}")
        logger.info(f"📊 SONUÇLAR:")
        logger.info(f"   Başarı: %{result.success_rate * 100:.1f}")
        logger.info(f"   İlan: {len(result.listings)} adet")
        logger.info(f"   Süre: {result.execution_time:.1f}s")
        logger.info(f"{'='*80}\n")
        
        return result
    
    async def _handle_popups(self, page: Page) -> None:
        """
        Cookie/popup handle et
        
        Args:
            page: Playwright page
        """
        try:
            for selector_def in self.selectors.COOKIE_SELECTORS:
                try:
                    element = await page.query_selector(selector_def.selector)
                    if element:
                        await element.click()
                        logger.info(f"✅ Popup kapatıldı: {selector_def.description}")
                        await asyncio.sleep(0.5)
                        break
                except:
                    continue
        except Exception as e:
            logger.warning(f"⚠️ Popup handle hatası: {str(e)[:50]}")
    
    async def _human_like_scroll(self, page: Page) -> None:
        """
        İnsan gibi scroll yap
        
        Args:
            page: Playwright page
        """
        try:
            for i in range(SCROLL_STEPS):
                scroll_amount = random.randint(MIN_SCROLL_AMOUNT, MAX_SCROLL_AMOUNT)
                await page.mouse.wheel(0, scroll_amount)
                await asyncio.sleep(random.uniform(0.3, 0.8))
            
            await asyncio.sleep(DEFAULT_WAIT_AFTER_LOAD)
        except Exception as e:
            logger.warning(f"⚠️ Scroll hatası: {str(e)[:50]}")
    
    async def _extract_listing_links(
        self,
        page: Page,
        brand: str,
        model: str,
        year: int
    ) -> List[Dict[str, Any]]:
        """
        İlan linklerini çıkar
        
        Args:
            page: Playwright page
            brand: Marka
            model: Model
            year: Yıl
        Returns:
            List[Dict[str, Any]]: İlan linkleri
        """
        links = []
        seen_urls = set()  # Duplicate kontrolü için

        try:
            # Listing link selector'larını dene
            for selector_def in self.selectors.LISTING_LINK_SELECTORS:
                try:
                    elements = await page.query_selector_all(selector_def.selector)

                    logger.info(f"🔍 [{selector_def.description}] {len(elements)} element bulundu")

                    if elements and len(elements) >= 3:
                        valid_count = 0
                        duplicate_count = 0
                        invalid_count = 0

                        for element in elements[:self.max_listings * 3]:  # Daha fazla element dene (duplicate'ler için)
                            try:
                                href = await element.get_attribute('href')

                                if not href:
                                    invalid_count += 1
                                    continue

                                # Validation kontrolü
                                if not self._is_valid_listing_link(href):
                                    invalid_count += 1
                                    continue

                                valid_count += 1

                                # Full URL
                                if href.startswith('/'):
                                    full_url = f"https://www.arabam.com{href}"
                                else:
                                    full_url = href

                                # KRİTİK: Duplicate kontrolü
                                if full_url in seen_urls:
                                    duplicate_count += 1
                                    continue

                                seen_urls.add(full_url)

                                # Title - link metni yerine boş bırak (detay sayfasında doldurulacak)
                                title = f"{brand} {model} {year}"

                                links.append({
                                    'url': full_url,
                                    'title': title,
                                    'brand': brand,
                                    'model': model,
                                    'year': year
                                })

                                if len(links) >= self.max_listings:
                                    break

                            except Exception:
                                continue

                        # Debug bilgisi
                        logger.info(f"   Valid: {valid_count}, Duplicate: {duplicate_count}, Invalid: {invalid_count}")
                        logger.info(f"   Unique links: {len(links)}")

                        if links:
                            logger.info(f"✅ {len(links)} unique link bulundu ({selector_def.description})")
                            break

                except Exception as e:
                    logger.warning(f"⚠️ Selector hatası: {str(e)[:50]}")
                    continue

        except Exception as e:
            logger.error(f"❌ Link extraction error: {str(e)[:100]}")
        
        return links
    
    def _is_valid_listing_link(self, href: str) -> bool:
        """
        Geçerli ilan linki mi?

        Args:
            href: URL

        Returns:
            bool: True if valid
        """
        # KRİTİK: Sadece /ilan/ içeren linkleri kabul et
        # Validation'ı gevşet - daha fazla listing bulmak için
        if '/ilan/' not in href:
            return False

        # Sayısal ID kontrolü (listing linklerinde ID vardır)
        # Bu kategori linklerini filtreler
        url_parts = href.split('/')
        last_part = url_parts[-1] if url_parts else ""

        # Son segment tamamen sayı ise veya sayı içeriyorsa geçerli
        if not any(c.isdigit() for c in last_part):
            return False

        return True
    
    async def _scrape_listing_details(
        self,
        page: Page,
        listing_links: List[Dict[str, Any]]
    ) -> List[ArabamListing]:
        """
        İlan detaylarını çek - OPTIMIZED VERSION
        
        Args:
            page: Playwright page
            listing_links: İlan linkleri
            
        Returns:
            List[ArabamListing]: İlan detayları
        """
        listings = []
        
        for i, link_info in enumerate(listing_links[:self.max_listings], 1):
            try:
                logger.info(f"\n  [{i}/{len(listing_links)}] {link_info['title'][:50]}...")
                
                # İnsan gibi bekle
                await asyncio.sleep(random.uniform(MIN_WAIT_BETWEEN_REQUESTS, MAX_WAIT_BETWEEN_REQUESTS))
                
                # Detay sayfasına git
                await page.goto(link_info['url'], wait_until="domcontentloaded", timeout=60000)
                
                # Popup handle
                await self._handle_popups(page)
                
                # Scroll - ONLY if not skipping (performance optimization)
                if not self.skip_detail_scroll:
                    await self._human_like_scroll(page)

                # İlan detayını çıkar
                listing = await self._extract_listing_detail(page, link_info)

                if listing:
                    listings.append(listing)
                    logger.info(f"    ✅ {listing.price:,} TL | Boya: {listing.paint_info.status.value}")
                else:
                    logger.warning(f"    ⚠️ Detay çıkarılamadı")
                
            except Exception as e:
                logger.error(f"    ❌ Hata: {str(e)[:100]}")
                continue
        
        return listings
    
    async def _extract_listing_detail(
        self,
        page: Page,
        link_info: Dict[str, Any]
    ) -> Optional[ArabamListing]:
        """
        İlan detayını çıkar - ROBUST VERSION
        
        Args:
            page: Playwright page
            link_info: Link bilgisi
            
        Returns:
            Optional[ArabamListing]: İlan detayı veya None
        """
        try:
            # URL
            url = link_info['url']
            logger.info(f"    🔗 URL: {url}")
            
            # Title
            title = link_info['title']
            
            # Price - KRİTİK
            price = None
            try:
                price = await self._extract_price(page)
            except Exception as e:
                logger.warning(f"    ⚠️ Fiyat çıkarım hatası: {str(e)[:50]}")
                
            if not price:
                logger.warning(f"    ❌ Fiyat bulunamadı, ilan atlanıyor")
                return None
            
            logger.info(f"    💰 Fiyat: {price:,} TL")
            
            # Brand, Model, Year
            brand = link_info.get('brand', 'Bilinmeyen')
            model = link_info.get('model', 'Bilinmeyen')
            year = link_info.get('year', 0)
            
            # KRİTİK: Unified Info Panel Extraction
            # Sağ taraftaki panelden TÜM bilgileri çek
            info_panel_data = {}
            try:
                info_panel_data = await self._extract_from_info_panel(page)
            except Exception as e:
                logger.warning(f"    ⚠️ Info panel extraction hatası: {str(e)[:50]}")
            
            # KM
            km = info_panel_data.get('km')
            if not km:
                try:
                    km = await self._extract_km(page)
                except: pass
            logger.info(f"    📏 KM: {km:,}" if km else "    📏 KM: Bulunamadı")
            
            # Fuel type
            fuel_type = info_panel_data.get('fuel_type', FuelType.UNKNOWN)
            if not fuel_type or fuel_type == FuelType.UNKNOWN:
                try:
                    fuel_type = await self._extract_fuel_type(page)
                except: fuel_type = FuelType.UNKNOWN
            logger.info(f"    ⛽ Yakıt: {fuel_type.value if hasattr(fuel_type, 'value') else fuel_type}")
            
            # Gear type
            gear_type = info_panel_data.get('gear_type', GearType.UNKNOWN)
            if not gear_type or gear_type == GearType.UNKNOWN:
                try:
                    gear_type = await self._extract_gear_type(page)
                except: gear_type = GearType.UNKNOWN
            logger.info(f"    ⚙️ Vites: {gear_type.value if hasattr(gear_type, 'value') else gear_type}")
            
            # Color
            color = info_panel_data.get('color', Color.UNKNOWN)
            if not color or color == Color.UNKNOWN:
                try:
                    color = await self._extract_color(page)
                except: color = Color.UNKNOWN
            logger.info(f"    🎨 Renk: {color.value if hasattr(color, 'value') else color}")
            
            # Paint info (CRITICAL)
            paint_info = None
            try:
                paint_extractor = PaintExtractor(page)
                paint_info = await paint_extractor.extract()
                logger.info(f"    🎨 Boya: {paint_info.status.value}")
            except Exception as e:
                logger.warning(f"    ⚠️ Boya bilgisi çıkarılamadı: {str(e)[:50]}")
                # Fallback dummy paint info
                from ..models.paint_info import PaintInfo
                from ..models.enums import PaintStatus
                paint_info = PaintInfo(status=PaintStatus.UNKNOWN)
            
            # Hasar kaydi (tramer) / agir hasar - satici beyani
            damage = {}
            try:
                damage = await DamageExtractor(page).extract()
                logger.info(f"    🧾 Hasar kaydı: tramer={damage.get('tramer_tl')} yok={damage.get('tramer_yok')} "
                            f"ağır={damage.get('agir_hasar')}")
            except Exception as e:
                logger.warning(f"    ⚠️ Hasar kaydı çıkarılamadı: {str(e)[:50]}")

            # Package info
            package_info = None
            try:
                package_extractor = PackageExtractor(page)
                package_info = await package_extractor.extract()
                logger.info(f"    📦 Paket: {package_info.total_features} özellik")
            except Exception as e:
                logger.warning(f"    ⚠️ Paket bilgisi çıkarılamadı: {str(e)[:50]}")
                from ..models.package_info import PackageInfo
                package_info = PackageInfo(packages=["Bilinmiyor"], features=[], total_features=0)
            
            # Image URL (KRİTİK - Dashboard için)
            image_url = None
            try:
                image_url = await self._extract_image_url(page)
            except Exception as e:
                logger.warning(f"    ⚠️ Görsel çıkarım hatası: {str(e)[:50]}")
            
            # Location (İl/İlçe)
            location = None
            try:
                location = await self._extract_location(page)
            except: pass
            logger.info(f"    📍 Konum: {location}" if location else "    📍 Konum: Bulunamadı")
            
            # Listing Date (İlan Tarihi)
            listing_date = info_panel_data.get('listing_date')
            if not listing_date:
                try:
                    listing_date = await self._extract_listing_date(page)
                except: pass
            logger.info(f"    📆 İlan Tarihi: {listing_date}" if listing_date else "    📆 İlan Tarihi: Bulunamadı")
            
            # Calculate data quality score
            quality_score = 0.5  # Base score
            if km: quality_score += 0.1
            if fuel_type != FuelType.UNKNOWN: quality_score += 0.15
            if gear_type != GearType.UNKNOWN: quality_score += 0.15
            if color != Color.UNKNOWN: quality_score += 0.1
            
            # Create listing
            listing = ArabamListing(
                url=url,
                price=price,
                title=title,
                brand=brand,
                model=model,
                year=year,
                km=km,
                fuel_type=fuel_type,
                gear_type=gear_type,
                color=color,
                paint_info=paint_info,
                package_info=package_info,
                image_url=image_url,  # KRİTİK - Dashboard için
                location=location,  # İl/İlçe bilgisi
                listing_date=listing_date,  # İlan tarihi
                tramer_amount=damage.get('tramer_tl'),
                no_damage_record=damage.get('tramer_yok'),
                heavy_damage=damage.get('agir_hasar'),
                damage_text=damage.get('kaynak_metin'),
                data_quality_score=min(quality_score, 1.0),
            )
            
            logger.info(f"    ✅ Kalite: %{quality_score * 100:.1f}")
            return listing
            
        except Exception as e:
            logger.error(f"    ❌ Listing detail fatal error: {str(e)[:200]}")
            return None
    
    async def _extract_image_url(self, page: Page) -> Optional[str]:
        """
        İlanın ana görsel URL'sini çıkar - ROBUST
        
        Args:
            page: Playwright page
            
        Returns:
            Optional[str]: Görsel URL'si veya None
        """
        try:
            # Denenecek selector'lar
            selectors = [
                "img.v-p-img",
                ".product-details-viewer-container img",
                ".gallery-container img",
                ".image-gallery img",
                "[class*='gallery'] img",
                "img[class*='listing']",
                ".product-image img",
                "img.v-p-img"
            ]
            
            for selector in selectors:
                try:
                    # Max 3 saniye bekle
                    element = page.locator(selector).first
                    # Attached olmasını bekle
                    await element.wait_for(state="attached", timeout=3000)
                    
                    # src veya data-src dene
                    src = await element.get_attribute("src")
                    if not src or "base64" in src or src.startswith("data:"):
                        src = await element.get_attribute("data-src")
                        
                    if src:
                        # URL normalizasyonu
                        if src.startswith("//"):
                            src = "https:" + src
                        elif src.startswith("/"):
                            src = "https://www.arabam.com" + src
                        
                        logger.info(f"    🖼️ Görsel bulundu: {src[:50]}...")
                        return src
                except:
                    continue
            
            # Fallback to selectors from ArabamSelectors
            for selector_def in self.selectors.IMAGE_URL_SELECTORS:
                try:
                    element = await page.query_selector(selector_def.selector)
                    if element:
                        attribute = selector_def.attribute or "src"
                        src = await element.get_attribute(attribute)
                        if src:
                            if src.startswith("//"): src = "https:" + src
                            elif src.startswith("/"): src = "https://www.arabam.com" + src
                            return src
                except:
                    continue
                    
        except Exception as e:
            logger.warning(f"    ⚠️ Görsel çıkarım hatası: {str(e)[:50]}")
            
        return None

    async def _extract_location(self, page: Page) -> Optional[str]:
        """
        Konum (İl/İlçe) çıkar
        
        Args:
            page: Playwright page
            
        Returns:
            Optional[str]: Konum veya None
        """
        try:
            # Farklı selector'ları dene
            location_selectors = [
                # Arabam.com selectors
                "div.classified-info > div > p",
                "div.info-box > p",
                "div.location-info",
                "span.location",
                "div.city-name",
                # Generic selectors
                "[class*='location']",
                "[class*='city']",
                "[class*='il']",
            ]
            
            for selector in location_selectors:
                try:
                    elements = await page.query_selector_all(selector)
                    
                    for element in elements:
                        try:
                            text = await element.inner_text()
                            text = text.strip()
                            
                            # İl/İlçe formatı kontrolü
                            # Örnek: "İzmir / Bornova", "İstanbul Kadıköy"
                            if len(text) > 3 and len(text) < 50:
                                # Gereksiz whitespace'leri temizle
                                text = ' '.join(text.split())
                                
                                # Şehir ismi içeriyor mu kontrol et
                                common_cities = ['istanbul', 'ankara', 'izmir', 'bursa', 'antalya', 
                                                'konya', 'adana', 'gaziantep', 'şanlıurfa', 'kocaeli']
                                text_lower = text.lower()
                                
                                if any(city in text_lower for city in common_cities):
                                    logger.info(f"    ✅ Konum bulundu: {text}")
                                    return text
                                
                                # / işareti içeriyor mu (İl/İlçe formatı)
                                if '/' in text or len(text.split()) >= 2:
                                    logger.info(f"    ✅ Konum bulundu: {text}")
                                    return text
                        except:
                            continue
                except:
                    continue
        except Exception as e:
            logger.warning(f"    ⚠️ Konum çıkarım hatası: {str(e)[:50]}")
        
        return None
    
    async def _extract_listing_date(self, page: Page) -> Optional[str]:
        """
        İlan tarihi çıkar - GÜÇLENDİRİLMİŞ VERSİYON
        
        Args:
            page: Playwright page
            
        Returns:
            Optional[str]: İlan tarihi (ISO format: 2026-02-25) veya None
        """
        try:
            # Türkçe ay isimleri mapping
            month_map = {
                'ocak': '01', 'şubat': '02', 'mart': '03', 'nisan': '04',
                'mayıs': '05', 'haziran': '06', 'temmuz': '07', 'ağustos': '08',
                'eylül': '09', 'ekim': '10', 'kasım': '11', 'aralık': '12'
            }
            
            # Selector'ları ArabamSelectors'dan al veya fallback kullan
            date_selectors = []
            if hasattr(self.selectors, 'DATE_SELECTORS'):
                date_selectors = [s.selector for s in self.selectors.DATE_SELECTORS]
            
            if not date_selectors:
                date_selectors = [
                    "span.date",
                    "span.publishing-date",
                    "div.listing-date",
                    "time",
                    "div.classified-info > div > p",
                    "div.info-box > p",
                ]
            
            for selector in date_selectors:
                try:
                    elements = await page.query_selector_all(selector)
                    
                    for element in elements:
                        try:
                            text = await element.inner_text()
                            text = text.strip()
                            
                            if not text or len(text) > 100:
                                continue
                            
                            text_lower = text.lower()
                            
                            # Format 1: "25 Şubat 2026" - Türkçe tarih
                            months_tr = list(month_map.keys())
                            for month in months_tr:
                                if month in text_lower:
                                    # Parse and convert to ISO
                                    try:
                                        # Extract day, month, year
                                        parts = text.split()
                                        day = None
                                        year = None
                                        
                                        for part in parts:
                                            if part.isdigit() and len(part) <= 2:
                                                day = part
                                            elif part.isdigit() and len(part) == 4:
                                                year = part
                                        
                                        if day and year:
                                            iso_date = f"{year}-{month_map[month]}-{day.zfill(2)}"
                                            logger.info(f"    ✅ İlan tarihi (Türkçe): {text} → {iso_date}")
                                            return iso_date
                                    except:
                                        pass
                            
                            # Format 2: "25.02.2026" or "25/02/2026" - Sayısal tarih
                            import re
                            numeric_date_pattern = r'(\d{2})[\./](\d{2})[\./](\d{4})'
                            match = re.search(numeric_date_pattern, text)
                            if match:
                                day, month, year = match.groups()
                                # Basic validation
                                if 1 <= int(month) <= 12 and 1 <= int(day) <= 31:
                                    iso_date = f"{year}-{month}-{day}"
                                    logger.info(f"    ✅ İlan tarihi (Sayısal): {text} → {iso_date}")
                                    return iso_date
                            
                            # Format 3: "X gün önce", "X saat önce" - Relative time
                            if 'gün önce' in text_lower or 'saat önce' in text_lower:
                                # Convert relative time to actual date
                                try:
                                    from datetime import datetime, timedelta
                                    
                                    # Extract number
                                    num_match = re.search(r'(\d+)', text)
                                    if num_match:
                                        num = int(num_match.group(1))
                                        
                                        if 'gün önce' in text_lower:
                                            calc_date = datetime.now() - timedelta(days=num)
                                        elif 'saat önce' in text_lower:
                                            calc_date = datetime.now() - timedelta(hours=num)
                                        else:
                                            continue
                                        
                                        iso_date = calc_date.strftime('%Y-%m-%d')
                                        logger.info(f"    ✅ İlan tarihi (Relative): {text} → {iso_date}")
                                        return iso_date
                                except:
                                    # If parsing fails, return raw text
                                    logger.info(f"    ✅ İlan tarihi (Relative-raw): {text}")
                                    return text
                            
                            # Format 4: ISO format already (2026-02-25)
                            iso_pattern = r'\d{4}-\d{2}-\d{2}'
                            if re.search(iso_pattern, text):
                                match = re.search(iso_pattern, text)
                                if match:
                                    logger.info(f"    ✅ İlan tarihi (ISO): {text}")
                                    return match.group(0)
                            
                        except Exception as e:
                            logger.debug(f"    Date parsing error: {str(e)[:50]}")
                            continue
                except Exception as e:
                    logger.debug(f"    Selector error: {str(e)[:50]}")
                    continue
                    
            # Last resort: Try to find date in page source or body text
            try:
                # 1. Search in body text for "İlan Tarihi: ..."
                body_text = await page.inner_text("body")
                date_match = re.search(r'İlan Tarihi[:\s]+(\d{1,2}\s+[a-zA-ZşŞıİğĞüÜöÖçÇ]+\s+\d{4})', body_text, re.IGNORECASE)
                if date_match:
                    date_text = date_match.group(1)
                    # Parse this found text
                    for month_tr, month_num in month_map.items():
                        if month_tr in date_text.lower():
                            parts = date_text.split()
                            d = next((p for p in parts if p.isdigit() and len(p) <= 2), None)
                            y = next((p for p in parts if p.isdigit() and len(p) == 4), None)
                            if d and y:
                                iso_date = f"{y}-{month_num}-{d.zfill(2)}"
                                logger.info(f"    ✅ İlan tarihi (Body-Text): {date_text} → {iso_date}")
                                return iso_date

                # 2. Look for numeric patterns in body
                numeric_match = re.search(r'İlan Tarihi[:\s]+(\d{2})[\./](\d{2})[\./](\d{4})', body_text, re.IGNORECASE)
                if numeric_match:
                    d, m, y = numeric_match.groups()
                    iso_date = f"{y}-{m}-{d}"
                    logger.info(f"    ✅ İlan tarihi (Body-Num): {iso_date}")
                    return iso_date

                # 3. Look for common date patterns in HTML source
                page_content = await page.content()
                patterns = [
                    r'"publishDate":"(\d{4}-\d{2}-\d{2})"',
                    r'"datePublished":"(\d{4}-\d{2}-\d{2})"',
                    r'data-date="(\d{4}-\d{2}-\d{2})"',
                ]
                
                for pattern in patterns:
                    match = re.search(pattern, page_content)
                    if match:
                        logger.info(f"    ✅ İlan tarihi (Source): {match.group(1)}")
                        return match.group(1)
            except:
                pass
                
        except Exception as e:
            logger.warning(f"    ⚠️ İlan tarihi çıkarım hatası: {str(e)[:50]}")
        
        return None
    
    async def _extract_price(self, page: Page) -> Optional[int]:
        """
        Fiyat çıkar - İYİLEŞTİRİLMİŞ VERSİYON
        
        Args:
            page: Playwright page
            
        Returns:
            Optional[int]: Fiyat veya None
        """
        try:
            for selector_def in self.selectors.PRICE_SELECTORS:
                try:
                    element = await page.query_selector(selector_def.selector)
                    if element:
                        text = await element.inner_text()
                        
                        # Clean price text - more aggressive cleaning
                        text = text.strip()
                        
                        # Remove currency symbols and separators
                        text = text.replace('TL', '').replace('₺', '').replace('₺', '')
                        text = text.replace('.', '').replace(',', '').strip()
                        
                        # Extract numbers from text
                        import re
                        numbers = re.findall(r'\d+', text)
                        
                        if numbers:
                            # Take the largest number (likely the price)
                            price = max(int(num) for num in numbers)
                            
                            # Validate price range
                            if 10000 <= price <= 100000000:
                                logger.info(f"    💰 Fiyat bulundu ({selector_def.description}): {price:,} TL")
                                return price
                except Exception as e:
                    logger.debug(f"    Price selector {selector_def.description} failed: {str(e)[:50]}")
                    continue
        except Exception as e:
            logger.warning(f"    Price extraction error: {str(e)[:100]}")
        
        return None
    
    async def _extract_km(self, page: Page) -> Optional[int]:
        """
        KM çıkar
        
        Args:
            page: Playwright page
            
        Returns:
            Optional[int]: KM veya None
        """
        try:
            for selector_def in self.selectors.KM_SELECTORS:
                try:
                    element = await page.query_selector(selector_def.selector)
                    if element:
                        text = await element.inner_text()
                        
                        # Clean KM text
                        text = text.strip()
                        text = text.replace('km', '').replace('KM', '').replace('.', '').replace(',', '').strip()
                        
                        if text.isdigit():
                            km = int(text)
                            if 0 <= km <= 500000:
                                return km
                except:
                    continue
        except:
            pass
        
        return None
    
    async def _extract_fuel_type(self, page: Page) -> FuelType:
        """
        Yakıt tipi çıkar
        
        Args:
            page: Playwright page
            
        Returns:
            FuelType: Yakıt tipi
        """
        try:
            # Get page text for keyword matching
            body_text = await page.inner_text("body")
            body_lower = body_text.lower()
            
            # Keyword matching
            if 'dizel' in body_lower or 'diesel' in body_lower:
                return FuelType.DIZEL
            elif 'benzin' in body_lower:
                return FuelType.BENZIN
            elif 'hibrit' in body_lower or 'hybrid' in body_lower:
                return FuelType.HIBRIT
            elif 'elektrik' in body_lower or 'electric' in body_lower:
                return FuelType.ELEKTRIK
            
            # Try selectors
            for selector_def in self.selectors.FUEL_SELECTORS:
                try:
                    element = await page.query_selector(selector_def.selector)
                    if element:
                        text = await element.inner_text()
                        text_lower = text.lower()
                        
                        if 'dizel' in text_lower or 'diesel' in text_lower:
                            return FuelType.DIZEL
                        elif 'benzin' in text_lower:
                            return FuelType.BENZIN
                        elif 'hibrit' in text_lower or 'hybrid' in text_lower:
                            return FuelType.HIBRIT
                        elif 'elektrik' in text_lower or 'electric' in text_lower:
                            return FuelType.ELEKTRIK
                except:
                    continue
        except:
            pass
        
        return FuelType.UNKNOWN
    
    async def _extract_gear_type(self, page: Page) -> GearType:
        """
        Vites tipi çıkar - İYİLEŞTİRİLMİŞ VERSİYON
        
        Args:
            page: Playwright page
            
        Returns:
            GearType: Vites tipi
        """
        try:
            # Try selectors first (more reliable)
            for selector_def in self.selectors.GEAR_SELECTORS:
                try:
                    element = await page.query_selector(selector_def.selector)
                    if element:
                        text = await element.inner_text()
                        text_lower = text.lower()
                        
                        # Daha geniş pattern matching
                        if 'otomatik' in text_lower and 'manuel' not in text_lower:
                            logger.info(f"   ✅ Vites: Otomatik (selector)")
                            return GearType.OTOMATIK
                        elif 'manuel' in text_lower or 'düzen' in text_lower:
                            logger.info(f"   ✅ Vites: Manuel (selector)")
                            return GearType.MANUEL
                        elif 'yarı otomatik' in text_lower or 'semi-automatic' in text_lower or 'yarı otomatik' in text_lower:
                            logger.info(f"   ✅ Vites: Yarı Otomatik (selector)")
                            return GearType.SEMI_AUTOMATIC
                except:
                    continue
            
            # Fallback 1: Get page text for keyword matching
            body_text = await page.inner_text("body")
            body_lower = body_text.lower()
            
            # Keyword matching (broader patterns)
            if 'otomatik vites' in body_lower or 'otomatik şanzıman' in body_lower:
                logger.info(f"   ✅ Vites: Otomatik (keyword)")
                return GearType.OTOMATIK
            elif 'manuel vites' in body_lower or 'manuel şanzıman' in body_lower:
                logger.info(f"   ✅ Vites: Manuel (keyword)")
                return GearType.MANUEL
            elif 'yarı otomatik' in body_lower:
                logger.info(f"   ✅ Vites: Yarı Otomatik (keyword)")
                return GearType.SEMI_AUTOMATIC
            
            # Fallback 2: Check for common gear type abbreviations
            if 'auto' in body_lower and 'man' not in body_lower:
                logger.info(f"   ✅ Vites: Otomatik (abbreviation)")
                return GearType.OTOMATIK
            elif 'man' in body_lower and 'auto' not in body_lower:
                logger.info(f"   ✅ Vites: Manuel (abbreviation)")
                return GearType.MANUEL
                
        except Exception as e:
            logger.warning(f"   ⚠️ Vites çıkarım hatası: {str(e)[:50]}")
        
        logger.info(f"   ⚠️ Vites: Bilinmiyor")
        return GearType.UNKNOWN
    
    async def _extract_color(self, page: Page) -> Color:
        """
        Renk çıkar
        
        Args:
            page: Playwright page
            
        Returns:
            Color: Renk
        """
        try:
            # Get page text for keyword matching
            body_text = await page.inner_text("body")
            body_lower = body_text.lower()
            
            # Keyword matching
            color_map = {
                'beyaz': Color.WHITE,
                'white': Color.WHITE,
                'siyah': Color.BLACK,
                'black': Color.BLACK,
                'gri': Color.GREY,
                'grey': Color.GREY,
                'gümüş': Color.SILVER,
                'silver': Color.SILVER,
                'mavi': Color.BLUE,
                'blue': Color.BLUE,
                'kırmızı': Color.RED,
                'red': Color.RED,
                'kahverengi': Color.BROWN,
                'brown': Color.BROWN,
                'bej': Color.BEIGE,
                'yeşil': Color.GREEN,
                'green': Color.GREEN,
            }
            
            for color_tr, color_enum in color_map.items():
                if color_tr in body_lower:
                    return color_enum
            
            # Try selectors
            for selector_def in self.selectors.COLOR_SELECTORS:
                try:
                    element = await page.query_selector(selector_def.selector)
                    if element:
                        text = await element.inner_text()
                        text_lower = text.lower()
                        
                        for color_tr, color_enum in color_map.items():
                            if color_tr in text_lower:
                                return color_enum
                except:
                    continue
        except:
            pass
        
        return Color.UNKNOWN
    
    async def _extract_from_info_panel(self, page: Page) -> Dict[str, Any]:
        """
        Sağ taraftaki bilgi panelinden TÜM verileri çıkar - UNIFIED EXTRACTION
        """
        import re
        
        result = {
            'km': None,
            'fuel_type': FuelType.UNKNOWN,
            'gear_type': GearType.UNKNOWN,
            'color': None,
            'listing_date': None,
        }
        
        try:
            # Türkçe ay isimleri mapping
            month_map = {
                'ocak': '01', 'şubat': '02', 'mart': '03', 'nisan': '04',
                'mayıs': '05', 'haziran': '06', 'temmuz': '07', 'ağustos': '08',
                'eylül': '09', 'ekim': '10', 'kasım': '11', 'aralık': '12'
            }
            
            # Info panel selector'ları
            info_panel_selectors = [
                "div.classified-info", "div.detail-info", "div.info-box", 
                "div.info-panel", "div[class*='info']", "div[class*='detail']", 
                "aside[class*='info']", "div.property-list"
            ]
            
            for panel_selector in info_panel_selectors:
                panel_element = await page.query_selector(panel_selector)
                if not panel_element: continue
                
                # Panel içindeki tüm metni al
                panel_text = await panel_element.inner_text()
                if not panel_text or len(panel_text) < 20: continue
                
                logger.info(f"    📋 Info panel text length: {len(panel_text)}")

                # 1. İLAN TARİHİ (Regex on full text)
                if not result['listing_date']:
                    # "İlan Tarihi" kelimesinden sonra gelen tarihi bul (whitespace/newline dahil)
                    date_re = re.search(r'İlan Tarihi\s+(\d{1,2})\s+([a-zA-ZşŞıİğĞüÜöÖçÇ]+)\s+(\d{4})', panel_text, re.IGNORECASE)
                    if date_re:
                        d, m_name, y = date_re.groups()
                        m_num = month_map.get(m_name.lower())
                        if m_num:
                            result['listing_date'] = f"{y}-{m_num}-{d.zfill(2)}"
                            logger.info(f"    📆 İlan Tarihi (FullText): {result['listing_date']}")
                    
                    # Sayısal format (25.02.2026)
                    if not result['listing_date']:
                        num_re = re.search(r'İlan Tarihi\s+(\d{2})[\./](\d{2})[\./](\d{4})', panel_text, re.IGNORECASE)
                        if num_re:
                            d, m, y = num_re.groups()
                            result['listing_date'] = f"{y}-{m}-{d}"
                            logger.info(f"    📆 İlan Tarihi (FullText-Num): {result['listing_date']}")

                # 2. KİLOMETRE - KRİTİK: Yıl değil mi kontrol et
                if not result['km']:
                    km_re = re.search(r'Kilometre\s+([\d.,]+)\s*km', panel_text, re.IGNORECASE)
                    if km_re:
                        km_str = km_re.group(1).replace('.', '').replace(',', '')
                        if km_str.isdigit():
                            km_value = int(km_str)
                            # KRİTİK VALIDATION: Yıl değil mi?
                            # 4 haneli ve 1900-2100 arası ise YIL'dir (2017, 2018, vb.)
                            if 1900 <= km_value <= 2100:
                                logger.debug(f"    ⏭️ Yıl değeri atlandı: {km_value}")
                            # KM validation: Minimum 1.000 km, maksimum 500.000 km
                            elif 1000 <= km_value <= 500000:
                                result['km'] = km_value
                                logger.info(f"    📏 KM (FullText): {result['km']:,}")

                # 3. YAKIT & VİTES & RENK (Element bazlı daha güvenli)
                all_elems = await panel_element.query_selector_all("li, p, .property, .info-row")
                texts = []
                for elem in all_elems:
                    t = (await elem.inner_text()).strip()
                    if t and t not in texts: texts.append(t)
                
                for i, text in enumerate(texts):
                    t_low = text.lower()
                    val_cand = texts[i+1] if i+1 < len(texts) else ""
                    
                    if 'yakıt' in t_low and result['fuel_type'] == FuelType.UNKNOWN:
                        for f in FuelType:
                            if f.value.lower() in (t_low + " " + val_cand.lower()):
                                result['fuel_type'] = f
                                logger.info(f"    ⛽ Yakıt: {f.value}")
                                break
                    elif 'vites' in t_low and result['gear_type'] == GearType.UNKNOWN:
                        for g in GearType:
                            if g.value.lower() in (t_low + " " + val_cand.lower()):
                                result['gear_type'] = g
                                logger.info(f"    ⚙️ Vites: {g.value}")
                                break
                    elif 'renk' in t_low and not result['color']:
                        # Eğer element içinde "Renk: Beyaz" gibi bir yapı varsa al, yoksa bir sonrakine bak
                        color_val = text.split(':')[-1].strip() if ':' in text else val_cand
                        if color_val and len(color_val) < 20: # Uzun metinleri ele (yanlış eşleşme)
                            result['color'] = color_val
                            logger.info(f"    🎨 Renk: {color_val}")

                # Eğer herhangi bir kritik veri bulunduysa panel döngüsünden çık
                if any([result['km'], result['listing_date'], result['fuel_type'] != FuelType.UNKNOWN]):
                    break
                    
        except Exception as e:
            logger.debug(f"    Info panel extraction error: {str(e)}")
            
        return result
