# -*- coding: utf-8 -*-
"""
Borusan Next Scraper v3.1 - Full Detail Extraction
Çift strateji: JSON-LD (birincil) + __NEXT_DATA__ (yedek)
Detay sayfası: KM, Boya, Değişen, Hasar Kaydı, Ekipman
Platform: https://www.borusannext.com
"""

import asyncio
import json
import re
import random
from playwright.async_api import async_playwright, BrowserContext
from typing import List, Dict, Any, Optional
from datetime import datetime

# ABSOLUTE IMPORTS
from yerimebak_ai_v5.core.rate_limiter import get_rate_limiter
from yerimebak_ai_v5.core.logger import get_logger

logger = get_logger(__name__)


# ──────────────────────────────────────────────
# Stealth launch argümanları (Letgo v4.1'den alındı)
# ──────────────────────────────────────────────
STEALTH_ARGS = [
    "--disable-blink-features=AutomationControlled",
    "--no-sandbox",
    "--disable-dev-shm-usage",
    "--disable-infobars",
    "--disable-setuid-sandbox",
    "--lang=tr-TR,tr",
    "--start-maximized",
]

STEALTH_SCRIPT = """
Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
window.chrome = { runtime: {} };
Object.defineProperty(navigator, 'languages', { get: () => ['tr-TR', 'tr', 'en-US'] });
Object.defineProperty(navigator, 'plugins', { get: () => [1, 2, 3] });
"""


class BorusanNextScraper:
    """
    Borusan Next scraper v3.0
    Çift çekme stratejisi:
      1. JSON-LD (application/ld+json) — en güvenilir, sayfa render sonrası anında mevcut
      2. __NEXT_DATA__ (window.__NEXT_DATA__) — yedek, derin veri için ideal

    URL formatları (öncelik sırasıyla):
      1. /araba-al/{marka}          → BMW: /araba-al/bmw
      2. /araba-al/{marka}/{model}  → BMW 3 Serisi: /araba-al/bmw/3-serisi
      3. /araba-al                  → Tüm araçlar (filtresiz)
    """

    BASE_URL = "https://www.borusannext.com"
    LISTING_BASE = f"{BASE_URL}/araba-al"

    # URL slug eşleştirme tablosu
    BRAND_SLUG_MAP = {
        "bmw": "bmw",
        "mini": "mini",
        "land rover": "land-rover",
        "landrover": "land-rover",
        "range rover": "land-rover",
    }

    def __init__(self, headless: bool = True):
        self.headless = headless
        self.rate_limiter = get_rate_limiter()
        self.name = "Borusan Next"

    async def collect_data(
        self,
        brand: str,
        year_min: int,
        year_max: Optional[int] = None,
        model: Optional[str] = None,
        only_new: bool = False
    ) -> List[Dict[str, Any]]:
        """
        Borusan Next'ten araç verisi çek.

        Args:
            brand:    Marka (ör: "BMW", "Mini", "Land Rover")
            year_min: Minimum yıl (dahil)
            year_max: Maksimum yıl (dahil, belirtilmezse year_min kullanılır)
            model:    Model adı (opsiyonel, ör: "3 Serisi")

        Returns:
            Araç bilgileri listesi (price, km, year, url, ...)
        """
        await self.rate_limiter.wait_for_slot("borusannext.com")
        year_max = year_max or year_min

        url = self._build_url(brand, model)
        logger.info(f"\n{'='*70}")
        logger.info(f"🚀 BORUSAN NEXT SCRAPER v3.1 — Full Detail Edition")
        logger.info(f"🔗 URL: {url}")
        logger.info(f"🎯 Hedef: {brand} {model or ''} | Yıl: {year_min}-{year_max}")
        logger.info(f"{'='*70}")

        results = []

        try:
            async with async_playwright() as p:
                browser = await p.chromium.launch(
                    headless=self.headless,
                    args=STEALTH_ARGS
                )

                context = await browser.new_context(
                    user_agent=(
                        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                        "AppleWebKit/537.36 (KHTML, like Gecko) "
                        "Chrome/131.0.0.0 Safari/537.36"
                    ),
                    viewport={"width": 1920, "height": 1080},
                    locale="tr-TR",
                    timezone_id="Europe/Istanbul",
                )

                # Stealth JS enjeksiyonu
                await context.add_init_script(STEALTH_SCRIPT)

                page = await context.new_page()

                # Sayfaya git
                logger.info(f"🌐 Sayfaya gidiliyor: {url}")
                try:
                    await page.goto(url, wait_until="networkidle", timeout=45000)
                except Exception as e:
                    logger.warning(f"⚠️ networkidle timeout, domcontentloaded deneniyor: {e}")
                    await page.goto(url, wait_until="domcontentloaded", timeout=45000)

                await asyncio.sleep(random.uniform(2.5, 4.0))

                # ── Strateji 1: JSON-LD ──────────────────────────────────────────
                logger.info("🔍 Strateji 1: JSON-LD çekiliyor...")
                raw_vehicles = await self._extract_jsonld(page)

                if not raw_vehicles:
                    # ── Strateji 2: __NEXT_DATA__ ─────────────────────────────────
                    logger.info("🔍 Strateji 2: __NEXT_DATA__ çekiliyor...")
                    raw_vehicles = await self._extract_next_data(page)

                if not raw_vehicles:
                    # ── Strateji 3: CSS Selector fallback ────────────────────────
                    logger.info("🔍 Strateji 3: CSS Selector çekiliyor...")
                    raw_vehicles = await self._extract_css_fallback(page, brand)

                logger.info(f"📦 Ham veri: {len(raw_vehicles)} araç")

                # Yıl filtresi uygula ve maksimum 5 araç ile sınırlandır
                max_listings = 5 if not only_new else 2  # 24h mode: restrict further if needed
                for v in raw_vehicles:
                    if len(results) >= max_listings:
                        break
                    
                    vy = v.get("year", 0)
                    if vy and year_min <= vy <= year_max:
                        results.append(v)
                    elif not vy:
                        # Yılı bilinmiyorsa dahil et (daha sonra filtrelensin)
                        results.append(v)

                logger.info(f"✅ Filtrelenmiş: {len(results)} araç ({year_min}-{year_max})")

                # ── DETAY SAYFASI: KM + Boya/Değişen/Hasar/Ekipman ────────────
                if results:
                    logger.info(f"\n🔬 Detay sayfaları taranıyor: {len(results)} araç...")
                    enriched = []
                    for i, v in enumerate(results, 1):
                        detail_url = v.get("url", "")
                        if not detail_url:
                            enriched.append(v)
                            continue
                        logger.info(f"  [{i}/{len(results)}] {v.get('title', '')[:50]}")
                        try:
                            detail = await self._fetch_vehicle_details(context, detail_url)
                            v.update(detail)  # KM, boya, hasar, ekipman merge
                        except Exception as de:
                            logger.warning(f"  ⚠️ Detay hatası: {de}")
                        enriched.append(v)
                        await asyncio.sleep(random.uniform(1.2, 2.5))  # rate limit
                    results = enriched

                await browser.close()

        except Exception as e:
            logger.error(f"❌ Borusan scraper kritik hata: {e}")
            import traceback
            traceback.print_exc()

        logger.info(f"\n{'='*70}")
        logger.info(f"✅ TAMAMLANDI: {len(results)} araç (detaylı)")
        logger.info(f"{'='*70}\n")
        return results

    # ──────────────────────────────────────────────────────────────────────────
    # DETAY SAYFASI ÇEKME
    # ──────────────────────────────────────────────────────────────────────────
    async def _fetch_vehicle_details(self, context, detail_url: str) -> Dict[str, Any]:
        """
        İlan detay sayfasından ayrıntılı bilgileri çeker:
        - KM (kilometre)
        - Boya durumu (boyasız / boyalı)
        - Değişen parça bilgisi
        - Hasar/tramer kaydı
        - Donanım/ekipman listesi
        - Yakıt ve vites tipi (zenginleştirme)
        """
        details: Dict[str, Any] = {}
        page = None
        try:
            page = await context.new_page()
            await page.goto(detail_url, wait_until="networkidle", timeout=35000)
            await asyncio.sleep(random.uniform(2.0, 3.5))

            # ── 1. __NEXT_DATA__ (en zengin kaynak) ─────────────────────────
            raw = await page.evaluate("""
                () => {
                    const nd = window.__NEXT_DATA__;
                    if (!nd) return null;
                    const pp = nd?.props?.pageProps || {};
                    // Detay sayfasında genellikle 'vehicle' veya 'car' anahtarı
                    return pp.vehicle || pp.car || pp.data || pp.listing || null;
                }
            """)

            if raw and isinstance(raw, dict):
                details = self._parse_detail_next_data(raw)
                logger.info(f"    ✅ __NEXT_DATA__ detay: KM={details.get('km')}, "
                            f"Hasar={details.get('accident_record')}, "
                            f"Boya={details.get('paint_info', {}).get('status')}")
            else:
                # ── 2. Sayfa metni fallback ────────────────────────────────
                body_text = await page.inner_text("body")
                details = self._parse_detail_body_text(body_text)
                logger.info(f"    ✅ Body-text detay: KM={details.get('km')}, "
                            f"Hasar={details.get('accident_record')}")

        except Exception as e:
            logger.warning(f"    ⚠️ Detail fetch hatası ({detail_url[:60]}): {e}")
        finally:
            if page:
                try:
                    await page.close()
                except Exception:
                    pass
        return details

    def _parse_detail_next_data(self, v: Dict) -> Dict[str, Any]:
        """
        __NEXT_DATA__ araç detay nesnesini çözümler.
        Gerçek yapı: vehicleExpertiseAppraisalSketches > her parça için appraisalSketchValue.name
        Değerler: 'Orjinal' | 'Boyalı' | 'Değişen' | 'Hasar'
        """
        # ── KM ─────────────────────────────────────────────────────────────────────
        km_raw = (
            v.get("km") or v.get("mileage") or v.get("kilometre")
            or v.get("odometer") or v.get("kilometerCount") or 0
        )
        try:
            km = int(str(km_raw).replace(".", "").replace(",", ""))
        except (ValueError, AttributeError):
            km = 0

        # ── Renk ───────────────────────────────────────────────────────────────────
        color_raw = v.get("color") or v.get("paint") or v.get("renk") or ""
        if isinstance(color_raw, dict):
            color = color_raw.get("text") or color_raw.get("name") or ""
        else:
            color = str(color_raw)

        # ── Yakıt / Vites ───────────────────────────────────────────────────────────
        fuel = (
            v.get("fuelType") or v.get("fuel") or v.get("yakitTipi")
            or v.get("engineType") or ""
        )
        gear = (
            v.get("gearType") or v.get("gearboxType") or v.get("transmissionType")
            or v.get("transmission") or ""
        )

        # ── vehicleExpertiseAppraisalSketches (gerçek boya/hasar yapısı) ──────
        # Her satır: {appraisalSketchValue: {name: 'Orjinal'|'Boyalı'|'Değişen'|'Hasar'},
        #              appraisalSketch: {name: 'Sol Ön Kapuı', ...}}
        sketches = v.get("vehicleExpertiseAppraisalSketches") or []

        # Parça düzeyinde durum
        has_paint   = False
        has_changed = False
        has_damage  = False
        damaged_parts   = []
        painted_parts   = []
        changed_parts   = []
        original_parts  = []

        for sk in sketches:
            if not isinstance(sk, dict):
                continue
            val_obj    = sk.get("appraisalSketchValue") or {}
            sketch_obj = sk.get("appraisalSketch")      or {}
            val_name   = str(val_obj.get("name") or "").strip()
            part_name  = str(sketch_obj.get("name") or "").strip()

            val_low = val_name.lower()
            if val_low in ("boyalı", "boyali"):
                has_paint = True
                painted_parts.append(part_name)
            elif val_low in ("değişen", "degisen", "değişti", "changed"):
                has_changed = True
                changed_parts.append(part_name)
            elif val_low in ("hasar", "hasarlı", "hasarli", "damaged"):
                has_damage = True
                damaged_parts.append(part_name)
            elif val_low in ("orjinal", "orijinal", "original"):
                original_parts.append(part_name)

        # ── paint_info objesi ──────────────────────────────────────────────
        parts_total = len(sketches)
        if parts_total > 0:
            if not has_paint and not has_changed and not has_damage:
                status = "Boyasız/Değişensiz"
            else:
                flags = []
                if has_paint:   flags.append("Boyalı")
                if has_changed: flags.append("Değişen")
                if has_damage:  flags.append("Hasarlı")
                status = " | ".join(flags)
        else:
            # Sketch verisi yok — fallback
            status = "Bilinmiyor"

        details_list = []
        for p in painted_parts: details_list.append(f"Boyalı: {p}")
        for p in changed_parts: details_list.append(f"Değişen: {p}")
        for p in damaged_parts: details_list.append(f"Hasar: {p}")

        paint_info = {
            "status": status,
            "has_paint": has_paint,
            "has_changed": has_changed,
            "has_damage": has_damage,
            "is_original": (not has_paint and not has_changed and not has_damage and parts_total > 0),
            "painted_parts": painted_parts[:10],
            "changed_parts": changed_parts[:10],
            "damaged_parts": damaged_parts[:10],
            "details": details_list[:15],
        }

        # ── Hasar kaydı (tramer) ────────────────────────────────────────────
        # isTramInquiry: True ise tramer sorgusu yapılmış
        is_tram = v.get("isTramInquiry", False)
        if has_damage:
            accident_record = "Var"
        elif is_tram is True:
            accident_record = "Yok"  # Tramer sorgulandı ve temiz
        elif parts_total > 0 and not has_damage:
            accident_record = "Yok"  # Expertise yapıldı ve hasar yok
        else:
            accident_record = "Bilinmiyor"

        # ── Ekipman / Donanım ──────────────────────────────────────────────
        features_raw = (
            v.get("vehicleHardwareFeatures") or v.get("vehiclePackageOptions")
            or v.get("vehicleHardwares") or v.get("features")
            or v.get("equipments") or v.get("extras") or []
        )
        package_info = []
        if isinstance(features_raw, list):
            for f in features_raw[:25]:
                if isinstance(f, dict):
                    name = (
                        f.get("name") or f.get("title") or f.get("featureName")
                        or f.get("label") or f.get("hardwareName") or ""
                    )
                else:
                    name = str(f)
                if name and len(name) < 70 and name not in package_info:
                    package_info.append(name)

        # ── Kasa Tipi (Body Type) ──────────────────────────────────────────
        body_type_raw = v.get("bodyType") or v.get("kasaTipi") or ""
        if isinstance(body_type_raw, dict):
            body_type = body_type_raw.get("text") or body_type_raw.get("name") or "Belirtilmemiş"
        else:
            body_type = str(body_type_raw) or "Belirtilmemiş"

        return {
            "km": km or None,
            "fuel_type": fuel,
            "gear_type": gear,
            "color": color,
            "body_type": body_type,
            "engine_size": v.get("engineSize") or v.get("motorHacmi"),
            "horsepower": v.get("hp") or v.get("motorGucu"),
            "paint_info": paint_info,
            "accident_record": accident_record,
            "package_info": package_info[:15],
            "expertise_parts": len(sketches),  # Toplam ekspertiz parçası
        }


    def _parse_detail_body_text(self, body: str) -> Dict[str, Any]:
        """
        Sayfa body metni üzerinden temel bilgileri çıkarır (fallback).
        """
        body_low = body.lower()

        # KM
        km = self._parse_km(body)

        # Hasar kaydı
        if any(x in body_low for x in ["hasarsız", "hasar kaydı yok", "tramer yok", "hasar yok"]):
            accident_record = "Yok"
        elif any(x in body_low for x in ["hasar kaydı var", "hasarlı", "tramer var", "hasar mevcut"]):
            accident_record = "Var"
        else:
            accident_record = "Bilinmiyor"

        # Boya
        paint_info = {
            "status": "Bilinmiyor",
            "has_paint": False,
            "has_changed": False,
            "is_original": False,
            "details": []
        }
        if any(x in body_low for x in ["boyasız", "değişensiz", "orijinal", "orjinal"]):
            paint_info["status"] = "Boyasız/Değişensiz"
            paint_info["is_original"] = True
        if any(x in body_low for x in ["boyalı", "boyası var"]):
            paint_info["status"] = "Boyalı"
            paint_info["has_paint"] = True
        if any(x in body_low for x in ["değişen", "parça değişen", "tramer"]):
            paint_info["status"] = "Değişen var"
            paint_info["has_changed"] = True

        # Ekipman
        equipment_keywords = [
            "navigasyon", "sunroof", "cam tavan", "deri koltuk", "ısıtmalı koltuk",
            "park sensörü", "geri görüş kamerası", "bluetooth", "cruise control",
            "led far", "xenon", "klima", "head up display", "elektrikli koltuk",
            "panoramik", "lane assist", "çarpışma önleme", "adaptive",
        ]
        package_info = [kw.capitalize() for kw in equipment_keywords if kw in body_low]

        return {
            "km": km or None,
            "paint_info": paint_info,
            "accident_record": accident_record,
            "package_info": package_info[:15],
            "body_type": "Belirtilmemiş",
            "engine_size": "Belirtilmemiş",
            "horsepower": "Belirtilmemiş"
        }

    # ──────────────────────────────────────────────────────────────────────────
    # Strateji 1: JSON-LD  (application/ld+json > ItemList > Product)
    # ──────────────────────────────────────────────────────────────────────────
    async def _extract_jsonld(self, page) -> List[Dict[str, Any]]:
        """
        JSON-LD veri setini çeker.
        Borusan Next'te sayfa <script type="application/ld+json"> ile
        ItemList/Product şemasını yayınlar.
        """
        try:
            scripts = await page.query_selector_all('script[type="application/ld+json"]')
            logger.info(f"  📄 JSON-LD script sayısı: {len(scripts)}")

            for script in scripts:
                content = await script.text_content()
                if not content:
                    continue

                try:
                    data = json.loads(content)

                    # ItemList → Product listesi
                    if data.get("@type") == "ItemList":
                        items = data.get("itemListElement", [])
                        results = []
                        for entry in items:
                            item = entry.get("item", entry)  # hem item içinde hem direkt olabilir
                            parsed = self._parse_jsonld_product(item)
                            if parsed:
                                results.append(parsed)
                        if results:
                            logger.info(f"  ✅ JSON-LD ItemList: {len(results)} ürün")
                            return results

                    # Tek bir Product
                    elif data.get("@type") == "Product":
                        parsed = self._parse_jsonld_product(data)
                        if parsed:
                            return [parsed]

                    # Liste içinde Product listesi (farklı yapı)
                    elif isinstance(data, list):
                        results = []
                        for item in data:
                            if item.get("@type") in ("Product", "Car", "Vehicle"):
                                parsed = self._parse_jsonld_product(item)
                                if parsed:
                                    results.append(parsed)
                        if results:
                            logger.info(f"  ✅ JSON-LD List: {len(results)} ürün")
                            return results

                except json.JSONDecodeError:
                    continue

        except Exception as e:
            logger.warning(f"  ⚠️ JSON-LD hata: {e}")

        return []

    def _parse_jsonld_product(self, item: Dict) -> Optional[Dict[str, Any]]:
        """JSON-LD Product nesnesini standart formata dönüştür"""
        try:
            name = item.get("name", "")
            url = item.get("url", "")
            description = item.get("description", "")
            offers = item.get("offers", {})

            # Fiyat
            price_raw = offers.get("price", 0)
            try:
                price = int(str(price_raw).replace(".", "").replace(",", "").split(".")[0])
            except (ValueError, AttributeError):
                price = 0

            # Yıl — isimden çek (ör: "2024 BMW 320i")
            year = self._parse_year(name) or self._parse_year(description)

            # KM — açıklamadan çek
            km = self._parse_km(description) or self._parse_km(name)

            # URL normaliza
            if url and not url.startswith("http"):
                url = f"{self.BASE_URL}{url}"

            brand_data = item.get("brand", {})
            brand_name = (
                brand_data.get("name", "") if isinstance(brand_data, dict)
                else str(brand_data)
            )

            return {
                "source": "borusan_next",
                "url": url,
                "title": name,
                "description": description,
                "price": price,
                "km": km,
                "year": year,
                "brand": brand_name or self._infer_brand(name),
                "model": self._infer_model(name),
                "fuel_type": None,
                "gear_type": self._infer_gear(description),
                "color": None,
                "image_url": item.get("image"),
                "scraped_at": datetime.now().isoformat(),
            }
        except Exception:
            return None

    # ──────────────────────────────────────────────────────────────────────────
    # Strateji 2: __NEXT_DATA__ (window level)
    # ──────────────────────────────────────────────────────────────────────────
    async def _extract_next_data(self, page) -> List[Dict[str, Any]]:
        """
        window.__NEXT_DATA__ üzerinden araç listesini çeker.
        pageProps altındaki olası anahtarları dene: vehicles, datas, items, cars, listings
        """
        try:
            raw = await page.evaluate("""
                () => {
                    const nd = window.__NEXT_DATA__;
                    if (!nd) return null;
                    const pp = nd?.props?.pageProps || {};
                    // Olası anahtar isimleri
                    const keys = ['vehicles', 'datas', 'items', 'cars', 'listings', 'data'];
                    for (const k of keys) {
                        if (pp[k] && Array.isArray(pp[k]) && pp[k].length > 0) {
                            return { key: k, data: pp[k] };
                        }
                    }
                    // Tüm anahtar isimlerini döndür (debug için)
                    return { key: 'ALL_KEYS', data: Object.keys(pp) };
                }
            """)

            if not raw:
                logger.warning("  ⚠️ __NEXT_DATA__ bulunamadı")
                return []

            if raw.get("key") == "ALL_KEYS":
                logger.warning(f"  ⚠️ pageProps anahtarları: {raw['data']}")
                return []

            logger.info(f"  ✅ __NEXT_DATA__ [{raw['key']}]: {len(raw['data'])} öğe")

            results = []
            for v in raw["data"]:
                parsed = self._parse_next_data_vehicle(v)
                if parsed:
                    results.append(parsed)

            return results

        except Exception as e:
            logger.warning(f"  ⚠️ __NEXT_DATA__ hata: {e}")
            return []

    def _parse_next_data_vehicle(self, v: Dict) -> Optional[Dict[str, Any]]:
        """__NEXT_DATA__ araç nesnesini standart formata dönüştür"""
        try:
            # Fiyat — farklı anahtar isimleri deneniyor
            price_raw = (
                v.get("salePrice")
                or v.get("currentListingPrice")
                or v.get("price", {}).get("amount", 0) if isinstance(v.get("price"), dict) else v.get("price", 0)
                or 0
            )
            try:
                price = int(str(price_raw).replace(".", "").replace(",", "").split(".")[0])
            except (ValueError, AttributeError):
                price = 0

            # KM
            km_raw = v.get("km") or v.get("mileage") or v.get("kilometre") or 0
            try:
                km = int(str(km_raw).replace(".", "").replace(",", ""))
            except (ValueError, AttributeError):
                km = 0

            # Yıl
            year_raw = v.get("year") or v.get("modelYear") or 0
            try:
                year = int(year_raw)
            except (ValueError, TypeError):
                year = 0

            # URL
            detail_url = v.get("detailUrl") or v.get("url") or ""
            if detail_url and not detail_url.startswith("http"):
                detail_url = f"{self.BASE_URL}{detail_url}"

            # Şube/Şehir
            branch = v.get("branchInfo", {})
            city = branch.get("cityName", "") if isinstance(branch, dict) else ""

            return {
                "source": "borusan_next",
                "url": detail_url,
                "title": f"{v.get('brand', '')} {v.get('model', '')}",
                "price": price,
                "km": km,
                "year": year,
                "brand": v.get("brand", ""),
                "model": v.get("model", ""),
                "fuel_type": v.get("fuelType") or v.get("fuel"),
                "gear_type": v.get("gearType") or v.get("gearboxType"),
                "color": v.get("paint") or v.get("color"),
                "city": city,
                "is_sold": v.get("isSold", False),
                "is_certified": v.get("isCertified", False),
                "announcement_no": v.get("announcementNo"),
                "image_url": v.get("imageUrl") or (v.get("images", [{}])[0].get("url") if v.get("images") else None),
                "scraped_at": datetime.now().isoformat(),
            }
        except Exception:
            return None

    # ──────────────────────────────────────────────────────────────────────────
    # Strateji 3: CSS Selector Fallback
    # ──────────────────────────────────────────────────────────────────────────
    async def _extract_css_fallback(self, page, brand: str) -> List[Dict[str, Any]]:
        """
        CSS selector ile ilan linklerini çek.
        Sayfa kaynağından fiyat/başlık bilgisini sınırlı olarak alır.
        """
        results = []
        selectors = [
            "a[href*='/araba-al/']",
            "a[href*='/arac-detay/']",
            "[class*='vehicle'] a",
            "[class*='car'] a",
            "[class*='listing'] a",
            "article a",
        ]

        for selector in selectors:
            try:
                elements = await page.query_selector_all(selector)
                if len(elements) >= 2:
                    logger.info(f"  ✅ CSS ({selector}): {len(elements)} element")
                    for el in elements[:30]:
                        href = await el.get_attribute("href")
                        text = ""
                        try:
                            text = (await el.inner_text()).strip()[:200]
                        except Exception:
                            pass

                        if not href or len(href) < 10:
                            continue

                        full_url = href if href.startswith("http") else f"{self.BASE_URL}{href}"
                        price = self._parse_price(text)
                        year = self._parse_year(text)

                        results.append({
                            "source": "borusan_next",
                            "url": full_url,
                            "title": text[:100],
                            "price": price,
                            "km": self._parse_km(text),
                            "year": year,
                            "brand": brand,
                            "image_url": await self._find_associated_image(el),
                            "scraped_at": datetime.now().isoformat(),
                        })
                    if results:
                        break
            except Exception:
                continue

        return results

    # ──────────────────────────────────────────────────────────────────────────
    # URL Builder
    # ──────────────────────────────────────────────────────────────────────────
    def _build_url(self, brand: str, model: Optional[str]) -> str:
        slug = self.BRAND_SLUG_MAP.get(brand.lower(), brand.lower().replace(" ", "-"))
        if model:
            model_slug = model.lower().replace(" ", "-")
            return f"{self.LISTING_BASE}/{slug}/{model_slug}"
        return f"{self.LISTING_BASE}/{slug}"

    # ──────────────────────────────────────────────────────────────────────────
    # Yardımcı parser'lar
    # ──────────────────────────────────────────────────────────────────────────
    @staticmethod
    def _parse_year(text: str) -> int:
        if not text:
            return 0
        m = re.search(r'\b(19[89]\d|20[012]\d)\b', str(text))
        return int(m.group(1)) if m else 0

    @staticmethod
    def _parse_km(text: str) -> int:
        if not text:
            return 0
        m = re.search(r'([\d\.]+)\s*(?:KM|km|Km)', str(text))
        if m:
            try:
                return int(m.group(1).replace(".", "").replace(",", ""))
            except ValueError:
                pass
        return 0

    async def _find_associated_image(self, element) -> Optional[str]:
        """CSS elementin içindeki veya yanındaki görseli bulur"""
        try:
            # Önce element içindeki img tagına bak
            img = await element.query_selector("img")
            if img:
                src = await img.get_attribute("src")
                if src: return src
            
            # Elementin bir üst seviyesine çıkıp oradaki img tagına bak
            # (Genelde ilan kartı yapısında link ve görsel kardeştir)
            parent = await element.query_selector("xpath=..")
            if parent:
                img = await parent.query_selector("img")
                if img:
                    src = await img.get_attribute("src")
                    if src: return src
        except Exception:
            pass
        return None

    @staticmethod
    def _parse_price(text: str) -> int:
        if not text:
            return 0
        m = re.search(r'([\d\.]+)\s*(?:TL|₺)', str(text))
        if m:
            try:
                return int(m.group(1).replace(".", "").replace(",", ""))
            except ValueError:
                pass
        return 0

    @staticmethod
    def _infer_brand(name: str) -> str:
        brands = ["BMW", "MINI", "Land Rover", "Range Rover"]
        for b in brands:
            if b.lower() in name.lower():
                return b
        return ""

    @staticmethod
    def _infer_model(name: str) -> str:
        # "2024 BMW 320i M Sport" → "320i M Sport"
        m = re.sub(r'^\d{4}\s+', "", name)  # yılı kaldır
        m = re.sub(r'^(BMW|MINI|Land Rover|Range Rover)\s+', "", m, flags=re.IGNORECASE)
        return m.strip()

    @staticmethod
    def _infer_gear(text: str) -> str:
        if not text:
            return ""
        t = text.lower()
        if "otomatik" in t or "automatic" in t:
            return "Otomatik"
        if "manuel" in t or "manual" in t:
            return "Manuel"
        return ""


# ──────────────────────────────────────────────────────────────────────────────
# Singleton & Wrapper
# ──────────────────────────────────────────────────────────────────────────────
_instance: Optional[BorusanNextScraper] = None


def get_borusan_scraper() -> BorusanNextScraper:
    """Singleton instance döndür"""
    global _instance
    if _instance is None:
        _instance = BorusanNextScraper()
    return _instance


# ── Geriye dönük uyumluluk alias ─────────────────────────────────────────────
# Eski kodlar BorusanSmartScraper adını kullanıyordu.
BorusanSmartScraper = BorusanNextScraper
