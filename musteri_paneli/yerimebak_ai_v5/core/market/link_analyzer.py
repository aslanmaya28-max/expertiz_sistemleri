# -*- coding: utf-8 -*-
"""
Universal Link Analyzer - Crawls and analyzes individual URLs on-demand.
Supports: Arabam.com, Sahibinden.
"""
import asyncio
import re
import logging
import json
from pathlib import Path
from typing import Dict, Any, Optional
from playwright.async_api import async_playwright
import sys
import os

# Windows Subprocess Fix
if sys.platform == 'win32':
    try:
        from asyncio import WindowsProactorEventLoopPolicy
        asyncio.set_event_loop_policy(WindowsProactorEventLoopPolicy())
    except ImportError:
        pass

from yerimebak_ai_v5.core.ai_orchestrator import ai_orchestrator
from yerimebak_ai_v5.core.repository import get_repository

logger = logging.getLogger(__name__)

class UniversalLinkAnalyzer:
    def __init__(self, headless: bool = True):
        self.headless = headless

    async def analyze_url(self, url: str, save_to_db: bool = True) -> Dict[str, Any]:
        """
        Analyze a single URL from Arabam, Sahibinden, or a local MHTML/HTML file.
        """
        import os
        
        # Clean up quotes if user pasted a path with quotes
        url = url.strip('"\'')
        logger.info(f"🔍 Analyzing URL/Path: {url} (Save to DB: {save_to_db})")
        
        is_local = os.path.exists(url) or url.startswith("file://") or url.endswith(".mhtml") or url.endswith(".html")
        
        data = None
        if is_local:
            data = await self._analyze_local_file(url)
        elif "arabam.com" in url:
            data = await self._analyze_arabam(url)
        elif "sahibinden.com" in url:
            data = await self._analyze_sahibinden(url)
        else:
            return {"error": "Desteklenmeyen platform URL'i veya geçerli bir yerel dosya değil."}

        if not data or "error" in data:
            return data or {"error": "Veri çekilemedi."}

        # Run AI Orchestration
        analysis = await ai_orchestrator.process_listing_async(data)
        
        # Save to database only if requested
        if save_to_db:
            repo = get_repository()
            await repo.save_listing(analysis)
        
        return analysis

    async def _analyze_arabam(self, url: str) -> Optional[Dict[str, Any]]:
        """Scrape Arabam.com listing"""
        from yerimebak_ai_v5.scrapers.arabam_detailed import ArabamDetailedCollector
        collector = ArabamDetailedCollector(headless=self.headless)
        
        async with async_playwright() as p:
            # We need a browser instance to pass to the collector's detail scraper
            browser = await p.chromium.launch(
                headless=self.headless,
                args=['--disable-blink-features=AutomationControlled', '--no-sandbox']
            )
            
            try:
                # Reusing the tested detail scraper from ArabamDetailedCollector
                # Changed from non-existent _extract_single_listing_details to _scrape_listing_detail
                details = await collector._scrape_listing_detail(browser, url)
                await browser.close()
                return details
            except Exception as e:
                logger.error(f"Arabam link analysis failed: {e}")
                await browser.close()
                return None

    async def _analyze_sahibinden(self, url: str) -> Optional[Dict[str, Any]]:
        """Sahibinden scraper using undetected-chromedriver (Highest Stealth)"""
        # Run synchronous UC code in an async thread to not block the main event loop
        return await asyncio.to_thread(self._analyze_sahibinden_sync, url)

    def _analyze_sahibinden_sync(self, url: str) -> Optional[Dict[str, Any]]:
        import sys
        if 'distutils' not in sys.modules:
            try:
                import setuptools._distutils
                import setuptools._distutils.version
                sys.modules['distutils'] = setuptools._distutils
                sys.modules['distutils.version'] = setuptools._distutils.version
            except ImportError:
                pass
                
        import undetected_chromedriver as uc
        from bs4 import BeautifulSoup
        import random
        import time
        import os
        import json

        logger.info("Initializing Undetected-Chromedriver for Sahibinden...")
        
        project_root = Path(__file__).resolve().parent.parent.parent
        auth_path = project_root / "auth.json"

        options = uc.ChromeOptions()
        if self.headless:
            # UC headless mode is tricky but supported by passing headless=True to Chrome()
            pass
        
        # Let undetected_chromedriver handle stealth internally
        # options.add_argument("--disable-popup-blocking")
        # options.add_argument("--no-sandbox")

        # BREAK PATTERN: Mandatory random wait before even starting browser
        pre_wait = random.uniform(2.0, 5.0)
        logger.info(f"Stealth delay: waiting {pre_wait:.1f}s before launch...")
        time.sleep(pre_wait)

        try:
            driver = uc.Chrome(options=options, headless=False)
            
            # Use randomized but realistic desktop window size
            w = random.randint(1280, 1920)
            h = random.randint(800, 1080)
            driver.set_window_size(w, h)

            logger.info(f"Navigating to {url}")
            driver.get(url)
            
            # Initial human-like pause (simulating reading above the fold)
            time.sleep(random.uniform(4.0, 7.5))
            
            # Gradual scrolling
            for _ in range(random.randint(2, 4)):
                scroll_amount = random.randint(200, 500)
                driver.execute_script(f"window.scrollBy(0, {scroll_amount})")
                time.sleep(random.uniform(0.8, 2.0))
            
            # Brief scroll up (mimicking looking back at a photo)
            driver.execute_script(f"window.scrollBy(0, -{random.randint(150, 400)})")
            time.sleep(random.uniform(1.0, 2.5))
            
            # Final reading pause
            time.sleep(random.uniform(2.0, 4.0))
            
            # Extract content
            html = driver.page_source
            title = driver.title
            
            # Check for block and allow manual override since headless=False
            def is_blocked(t, h):
                return any(x in t.lower() for x in ["olağan dışı", "robot", "doğrula", "log in", "giriş"]) or \
                       any(x in h for x in ["Bir dakika lütfen", "giriş yapmanız gerekebilir", "bireysel giriş"])

            if is_blocked(title, html):
                logger.warning("⚠️ Sahibinden güvenlik doğrulaması (veya Giriş) tespit edildi! Lütfen açılan tarayıcı penceresinde doğrulamayı manuel olarak geçin. 90 saniye bekleniyor...")
                wait_time = 90
                for _ in range(wait_time):
                    time.sleep(1)
                    title = driver.title
                    html = driver.page_source
                    if not is_blocked(title, html):
                        logger.info("✅ Doğrulama başarıyla geçildi!")
                        break
                else:
                    logger.error("🛑 Doğrulama süresi doldu. Sahibinden BLOCKED in UC.")
                    os.makedirs("screenshots", exist_ok=True)
                    try:
                        driver.save_screenshot("screenshots/sahibinden_blocked_uc.png")
                    except:
                        pass
                    driver.quit()
                    return {"error": "Sahibinden bot engelini aşamadı (Güvenlik Duvarı veya Giriş Ekranı). Lütfen açılan tarayıcıda manuel olarak doğrulamayı geçmeyi deneyin."}

            data = {
                "source": "sahibinden",
                "url": url,
                "title": title.strip(),
            }
            
            soup = BeautifulSoup(html, 'html.parser')
            
            # Title
            h1 = soup.find('h1')
            if h1:
                data["title"] = h1.text.strip()
                
            # Description
            desc_div = soup.find('div', id='classifiedDescription')
            if desc_div:
                data["description"] = desc_div.text.strip()
                
            # Price
            data["price"] = 0
            price_div = soup.select_one('.classifiedInfo [data-price]')
            if price_div:
                raw_price = price_div.get('data-price', '0')
                data["price"] = int(re.sub(r'[^\d]', '', raw_price))
            else:
                price_h3 = soup.select_one('.classifiedInfo h3')
                if price_h3:
                    data["price"] = int(re.sub(r'[^\d]', '', price_h3.text))
                    
            # Features - core fields
            info_list = soup.select('.classifiedInfoList li')
            for li in info_list:
                # Sahibinden usually uses <strong> for key and <span> for value, without colons.
                strong_tag = li.find('strong')
                span_tag = li.find('span')
                
                if strong_tag and span_tag:
                    key = strong_tag.text.strip().lower()
                    val = span_tag.text.strip()
                    # Handle valid encoding issues without breaking the string
                    key = key.replace('ý', 'i').replace('ý', 'i').replace('i̇', 'i').replace('ı', 'i')

                    if "marka" in key: data["brand"] = val
                    elif "seri" in key: data["series"] = val
                    elif "model" in key: data["model"] = val
                    elif "yıl" in key or "yil" in key: data["year"] = int(val) if val.isdigit() else 0
                    elif "km" in key or "kilometre" in key: data["km"] = int(re.sub(r'[^\d]', '', val)) if re.sub(r'[^\d]', '', val) else 0
                    elif "yakıt" in key or "yakit" in key: data["fuel"] = val
                    elif "vites" in key: data["transmission"] = val
                    elif "renk" in key: data["color"] = val
                    elif "motor hacmi" in key: data["engine_size"] = val
                    elif "motor gücü" in key or "gucu" in key: data["horsepower"] = val
                    # Extended fields
                    elif "kasa tipi" in key: data["body_type"] = val
                    elif "çekiş" in key or "cekis" in key: data["drive_type"] = val
                    elif "durumu" in key: data["condition"] = val

            # Extract ilan no and ilan tarihi from separate section
            for li in soup.select('.classifiedInfoList li'): # Note: usually all in the same list
                strong_tag = li.find('strong')
                span_tag = li.find('span')
                if strong_tag and span_tag:
                    key = strong_tag.text.strip().lower()
                    val = span_tag.text.strip()
                    key = key.replace('ý', 'i').replace('ý', 'i').replace('i̇', 'i').replace('ı', 'i')
                    
                    if "ilan no" in key or ("tarihi" not in key and "no" in key):
                        data["listing_no"] = val
                    elif "ilan tarihi" in key or "tarihi" in key:
                        data["listing_date"] = val

            # Store original URL for clickable links on dashboard
            data["url"] = url

            # Fallbacks: Structured Data (JSON-LD) and Breadcrumbs
            if not data.get("brand") or not data.get("model"):
                # 1. Try to find the Breadcrumbs
                breadcrumb_nav = soup.select('.navigataion .navigataion-item span')
                if breadcrumb_nav and len(breadcrumb_nav) >= 4:
                    # Usually: Vasıta > Otomobil > Renault > Clio > 1.0 TCe > Techno Esprit Alpine
                    brand_idx = 2  # 0: Vasıta, 1: Otomobil, 2: Brand
                    if "Vasıta" in breadcrumb_nav[0].text:
                        if not data.get("brand") and len(breadcrumb_nav) > brand_idx:
                            data["brand"] = breadcrumb_nav[brand_idx].text.strip()
                        if not data.get("series") and len(breadcrumb_nav) > brand_idx + 1:
                            data["series"] = breadcrumb_nav[brand_idx + 1].text.strip()
                        if not data.get("model") and len(breadcrumb_nav) > brand_idx + 2:
                            data["model"] = breadcrumb_nav[brand_idx + 2].text.strip()

                # 2. Try JSON-LD script (Often robust)
                scripts = soup.find_all('script', type='application/ld+json')
                for script in scripts:
                    try:
                        content = script.string
                        if content and 'Product' in content:
                            json_data = json.loads(content)
                            if 'brand' in json_data and isinstance(json_data['brand'], dict):
                                data["brand"] = json_data['brand'].get('name', data.get("brand", ""))
                            # Model might be buried in the description or name
                            break
                    except Exception:
                        pass
                
                # 3. String Fallback (Desperation fix)
                if not data.get("brand"):
                    title = data.get("title", "").upper()
                    # Basic brand list for quick fallback
                    for b in ["FIAT", "RENAULT", "VOLKSWAGEN", "BMW", "MERCEDES", "AUDI", "FORD", "TOYOTA", "HYUNDAI", "HONDA", "KIA", "OPEL", "PEUGEOT", "CITROEN", "SKODA", "DACIA"]:
                        if f"{b}" in title or f" {b} " in title:
                            data["brand"] = b.capitalize()
                            model_part = title.split(b)[-1].strip()
                            if model_part and not data.get("model"):
                                data["model"] = model_part.split()[0].capitalize()
                            break

            # Condition (Paint/Damage)
            paint_info = {'has_paint': False, 'has_changed': False, 'details': []}
            accident_record = "Bilinmiyor"
            
            desc_lower = data.get("description", "").lower()
            if "boya" in desc_lower and "yok" not in desc_lower:
                paint_info['has_paint'] = True
                paint_info['details'].append("Açıklamada boya belirtilmiş")
            if "değişen" in desc_lower and "yok" not in desc_lower:
                paint_info['has_changed'] = True
                paint_info['details'].append("Açıklamada değişen belirtilmiş")
            if "hasar kaydı" in desc_lower:
                accident_record = "Açıklamada hasar kaydı belirtilmiş"

            data["paint_info"] = paint_info
            data["accident_record"] = accident_record

            # Location and Image
            loc_h2 = soup.select_one('.classifiedInfo h2')
            if loc_h2:
                data["location"] = loc_h2.text.strip()
            else:
                data["location"] = ""
                
            img_el = soup.select_one('img.classifiedDetailMainPhoto')
            if img_el:
                data["image_url"] = img_el.get('src', '')
            else:
                data["image_url"] = ""

            # Try graceful quit
            try:
                driver.close()
                time.sleep(0.5)
                driver.quit()
            except OSError:
                pass # Ignore WinError 6
            except Exception as e:
                logger.debug(f"UC Quit Error: {e}")
            
            # Prevent __del__ error
            try:
                driver.__del__ = lambda: None
                del driver
            except:
                pass
                
            return data
            
        except Exception as e:
            logger.error(f"Sahibinden link analysis via UC failed: {e}")
            try:
                driver.close()
                driver.quit()
            except OSError:
                pass
            except Exception:
                pass
            
            try:
                driver.__del__ = lambda: None
                del driver
            except:
                pass

            return {"error": f"Analiz hatası: {str(e)}"}

    async def _analyze_local_file(self, file_path: str) -> Optional[Dict[str, Any]]:
        """Scrape offline MHTML/HTML files using Playwright"""
        import os
        from pathlib import Path

        logger.info(f"Processing local file: {file_path}")
        
        if not file_path.startswith("file://") and not file_path.startswith("http"):
            abs_path = os.path.abspath(file_path)
            file_url = Path(abs_path).as_uri()
        else:
            file_url = file_path

        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=True)
            context = await browser.new_context(viewport={'width': 1920, 'height': 1080})
            page = await context.new_page()
            
            try:
                await page.goto(file_url, wait_until="networkidle", timeout=30000)
                await asyncio.sleep(2) # Give JS time to render MHTML
                
                title = await page.title()
                
                data = {
                    "source": "sahibinden", # Processed as Sahibinden offline
                    "url": file_path,
                    "title": title.strip(),
                }
                
                title_locator = page.locator("h1")
                if await title_locator.count() > 0:
                    data["title"] = (await title_locator.first.inner_text(timeout=5000)).strip()

                desc_el = await page.query_selector("#classifiedDescription")
                if desc_el:
                    data["description"] = await desc_el.inner_text()

                price = 0
                try:
                    price_locator = page.locator(".classifiedInfo [data-price]")
                    if await price_locator.count() > 0:
                        raw_price = await price_locator.first.get_attribute("data-price", timeout=5000) or "0"
                        price = int(re.sub(r'[^\d]', '', raw_price))
                    else:
                        price_h3 = page.locator(".classifiedInfo h3")
                        if await price_h3.count() > 0:
                            price_txt = await price_h3.first.inner_text(timeout=5000)
                            price = int(re.sub(r'[^\d]', '', price_txt))
                except Exception as pe:
                    logger.warning(f"Price extraction failed: {pe}")
                
                data["price"] = price

                info_items = await page.locator(".classifiedInfoList li").all()
                for item in info_items:
                    text = await item.inner_text()
                    if ":" in text:
                        parts = text.split(":", 1)
                        key = parts[0].strip().lower()
                        val = parts[1].strip()
                        
                        if "marka" in key: data["brand"] = val
                        elif "seri" in key: data["series"] = val
                        elif "model" in key: data["model"] = val
                        elif "yıl" in key: data["year"] = int(val) if val.isdigit() else 0
                        elif "km" in key: data["km"] = int(re.sub(r'[^\d]', '', val)) if re.sub(r'[^\d]', '', val) else 0
                        elif "yakıt" in key: data["fuel_type"] = val
                        elif "vites" in key: data["gear_type"] = val
                        elif "renk" in key: data["color"] = val
                        elif "motor hacmi" in key: data["engine_size"] = val
                        elif "motor gücü" in key: data["horsepower"] = val

                paint_info = {'has_paint': False, 'has_changed': False, 'details': []}
                accident_record = "Bilinmiyor"
                
                desc_lower = data.get("description", "").lower()
                if "boya" in desc_lower and "yok" not in desc_lower:
                    paint_info['has_paint'] = True
                    paint_info['details'].append("Açıklamada boya belirtilmiş")
                if "değişen" in desc_lower and "yok" not in desc_lower:
                    paint_info['has_changed'] = True
                    paint_info['details'].append("Açıklamada değişen belirtilmiş")
                if "hasar kaydı" in desc_lower:
                    accident_record = "Açıklamada hasar kaydı belirtilmiş"

                data["paint_info"] = paint_info
                data["accident_record"] = accident_record

                loc_h2 = page.locator(".classifiedInfo h2")
                data["location"] = await loc_h2.inner_text() if await loc_h2.count() > 0 else ""
                
                img_el = await page.query_selector("img.classifiedDetailMainPhoto")
                data["image_url"] = await img_el.get_attribute("src") if img_el else ""

                await browser.close()
                return data
            except Exception as e:
                logger.error(f"Local file analysis failed: {e}")
                await browser.close()
                return {"error": f"Yerel dosya analiz hatası: {str(e)}"}

# Singleton
link_analyzer = UniversalLinkAnalyzer()
