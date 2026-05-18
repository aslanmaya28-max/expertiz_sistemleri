# -*- coding: utf-8 -*-
"""
YERİMEBAK AI - Market Analyzer v1.0
Arabam + Borusan'dan eşzamanlı veri çeken ve müşteri raporu üreten sistem
"""
import asyncio
from typing import List, Dict, Any, Optional
from datetime import datetime
import statistics

# Scrapers
from yerimebak_ai_v5.scrapers.arabam_smart import ArabamSmartCollector
from yerimebak_ai_v5.scrapers.borusan_smart import BorusanSmartScraper


class BorusanSmartCollector:
    """Borusan SmartScraper için wrapper - diğer collectorlarla uyumlu arayüz"""
    
    def __init__(self, headless: bool = True):
        self.scraper = BorusanSmartScraper()
        self.headless = headless
    
    async def collect_data(self, brand: str, model: str, year: int) -> List[Dict[str, Any]]:
        """
        Arabam ile uyumlu arayüz
        
        Args:
            brand: Marka (örn: "Volkswagen")
            model: Model (örn: "Passat")
            year: Yıl (örn: 2020)
        
        Returns:
            Araç listesi
        """
        try:
            # Borusan scraper'ı çalıştır
            vehicles = await self.scraper.scrape(
                make=brand,
                year_min=year,
                year_max=year
            )
            
            # Veriyi normalize et (arabam formatına)
            normalized = []
            for vehicle in vehicles:
                normalized_vehicle = {
                    'source': 'borusan',
                    'price': vehicle.get('price'),
                    'km': vehicle.get('km'),
                    'year': vehicle.get('year'),
                    'fuel_type': vehicle.get('fuel_type'),
                    'gear_type': vehicle.get('gear_type'),
                    'color': vehicle.get('color'),
                    'url': vehicle.get('detail_url'),
                    'title': f"{vehicle.get('make', '')} {vehicle.get('model', '')}",
                }
                normalized.append(normalized_vehicle)
            
            return normalized
        except Exception as e:
            # Borusan'da marka yoksa veya hata olursa sessizce boş liste döndür
            # Böylece diğer platformların çalışması etkilenmez
            return []


class MarketAnalyzer:
    """
    Arabam ve Borusan'dan eşzamanlı veri çeker ve piyasa analizi üretir
    """
    
    def __init__(self, headless: bool = True):
        self.headless = headless
        self.collectors = {
            'arabam': ArabamSmartCollector(headless=headless),
            'borusan': BorusanSmartCollector(headless=headless)
        }
    
    async def analyze_market(
        self, 
        brand: str, 
        model: str, 
        year: int, 
        target_price: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Arabam + Borusan'dan eşzamanlı veri çeker ve piyasa analizi üretir
        
        Args:
            brand: Marka (örn: "Volkswagen")
            model: Model (örn: "Passat")
            year: Yıl (örn: 2020)
            target_price: Hedef fiyat (opsiyonel)
        
        Returns:
            Piyasa analizi raporu
        """
        print(f"\n{'='*80}")
        print(f"🚀 PİYASA ANALİZİ BAŞLATILIYOR: {brand} {model} {year}")
        print(f"   Kaynaklar: Arabam + Borusan")
        print(f"{'='*80}\n")
        
        # 1. Eşzamanlı veri çekme
        raw_data = await self._collect_parallel(brand, model, year)
        
        # 2. Veri birleştirme ve normalize etme
        normalized_data = self._normalize_data(raw_data)
        
        # 3. Piyasa analizi
        market_analysis = self._analyze_market(normalized_data, year, target_price)
        
        # 4. Değer kaybı hesaplama
        depreciation_analysis = self._calculate_depreciation(normalized_data, year)
        
        # 5. Müşteri önerileri
        recommendations = self._generate_recommendations(market_analysis, depreciation_analysis, target_price)
        
        # Rapor oluştur
        report = {
            'vehicle_info': {
                'brand': brand,
                'model': model,
                'year': year
            },
            'data_sources': {
                'arabam': len(raw_data.get('arabam', [])),
                'borusan': len(raw_data.get('borusan', [])),
                'total': sum(len(v) for v in raw_data.values())
            },
            'market_analysis': market_analysis,
            'depreciation_analysis': depreciation_analysis,
            'recommendations': recommendations,
            'raw_data': raw_data,
            'generated_at': datetime.now().isoformat()
        }
        
        print(f"\n{'='*80}")
        print(f"✅ ANALİZ TAMAMLANDI")
        print(f"{'='*80}\n")
        
        return report
    
    async def _collect_parallel(
        self, 
        brand: str, 
        model: str, 
        year: int
    ) -> Dict[str, List[Dict[str, Any]]]:
        """
        Arabam + Borusan'dan eşzamanlı veri çeker
        
        Returns:
            Platform'a göre ayrılmış ham veriler
        """
        print("🔄 Arabam + Borusan'dan Eşzamanlı Veri Çekiliyor...\n")
        
        tasks = []
        platform_names = []
        
        # Her platform için task oluştur
        for platform_name, collector in self.collectors.items():
            tasks.append(collector.collect_data(brand, model, year))
            platform_names.append(platform_name)
        
        # Eşzamanlı çalıştır
        results = await asyncio.gather(*tasks, return_exceptions=True)
        
        # Sonuçları birleştir
        raw_data = {}
        for platform_name, result in zip(platform_names, results):
            if isinstance(result, Exception):
                print(f"❌ {platform_name.upper()}: Hata - {result}")
                raw_data[platform_name] = []
            else:
                print(f"✅ {platform_name.upper()}: {len(result)} ilan bulundu")
                raw_data[platform_name] = result
        
        total = sum(len(v) for v in raw_data.values())
        print(f"\n📊 TOPLAM: {total} ilan başarıyla çekildi\n")
        
        return raw_data
    
    def _normalize_data(
        self, 
        raw_data: Dict[str, List[Dict[str, Any]]]
    ) -> List[Dict[str, Any]]:
        """
        Farklı platformlardan gelen verileri normalize eder
        
        Args:
            raw_data: Platform'a göre ayrılmış veriler
        
        Returns:
            Normalize edilmiş tek liste
        """
        normalized = []
        
        for platform, listings in raw_data.items():
            for listing in listings:
                # Her listing'i normalize et
                normalized_listing = {
                    'source': platform,
                    'price': listing.get('price') or listing.get('price'),
                    'km': listing.get('km') or listing.get('km'),
                    'year': listing.get('year') or listing.get('year'),
                    'fuel_type': listing.get('fuel_type'),
                    'gear_type': listing.get('gear_type'),
                    'color': listing.get('color'),
                    'url': listing.get('url') or listing.get('link')
                }
                
                # Sadece fiyatı olan verileri ekle (KM opsiyonel)
                if normalized_listing['price']:
                    normalized.append(normalized_listing)
        
        print(f"🔧 {len(normalized)} ilan normalize edildi")
        return normalized
    
    def _analyze_market(
        self, 
        normalized_data: List[Dict[str, Any]], 
        vehicle_year: int,
        target_price: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Piyasa analizi yapar
        
        Args:
            normalized_data: Normalize edilmiş veriler
            vehicle_year: Araç yılı
            target_price: Hedef fiyat (opsiyonel)
        
        Returns:
            Piyasa analizi sonuçları
        """
        if not normalized_data:
            return {
                'average_price': 0,
                'min_price': 0,
                'max_price': 0,
                'median_price': 0,
                'price_range': 0,
                'sample_size': 0,
                'std_deviation': 0
            }
        
        # Fiyatları çıkar
        prices = [item['price'] for item in normalized_data if item['price']]
        
        if not prices:
            return {
                'average_price': 0,
                'min_price': 0,
                'max_price': 0,
                'median_price': 0,
                'price_range': 0,
                'sample_size': 0,
                'std_deviation': 0
            }
        
        # İstatistikler
        avg_price = statistics.mean(prices)
        min_price = min(prices)
        max_price = max(prices)
        median_price = statistics.median(prices)
        
        # Standart sapma (eğer yeterli veri varsa)
        std_dev = 0
        if len(prices) > 1:
            std_dev = statistics.stdev(prices)
        
        # KM ortalaması
        kms = [item['km'] for item in normalized_data if item['km']]
        avg_km = statistics.mean(kms) if kms else 0
        
        analysis = {
            'average_price': int(avg_price),
            'min_price': int(min_price),
            'max_price': int(max_price),
            'median_price': int(median_price),
            'price_range': int(max_price - min_price),
            'sample_size': len(prices),
            'std_deviation': int(std_dev),
            'average_km': int(avg_km),
            'price_per_km': int(avg_price / avg_km) if avg_km > 0 else 0
        }
        
        print(f"📈 Piyasa Analizi:")
        print(f"   Ortalama Fiyat: {avg_price:,.0f} TL")
        print(f"   Min Fiyat: {min_price:,.0f} TL")
        print(f"   Max Fiyat: {max_price:,.0f} TL")
        print(f"   Medyan: {median_price:,.0f} TL")
        print(f"   Ortalama KM: {avg_km:,.0f}")
        
        return analysis
    
    def _calculate_depreciation(
        self, 
        normalized_data: List[Dict[str, Any]], 
        vehicle_year: int
    ) -> Dict[str, Any]:
        """
        Değer kaybı hesaplar
        
        Args:
            normalized_data: Normalize edilmiş veriler
            vehicle_year: Araç yılı
        
        Returns:
            Değer kaybı analizi
        """
        current_year = datetime.now().year
        car_age = current_year - vehicle_year
        
        if not normalized_data or car_age <= 0:
            return {
                'car_age_years': car_age,
                'annual_depreciation_rate': 0,
                'total_depreciation': 0,
                'current_value_ratio': 0
            }
        
        # Ortalama fiyat
        prices = [item['price'] for item in normalized_data if item['price']]
        if not prices:
            return {
                'car_age_years': car_age,
                'annual_depreciation_rate': 0,
                'total_depreciation': 0,
                'current_value_ratio': 0
            }
        
        current_avg_price = statistics.mean(prices)
        
        # Yeni araç fiyatı (tahmini - ortalama 350,000 TL)
        original_price_estimate = current_avg_price / ((1 - 0.13) ** car_age)
        
        # Yıllık değer kaybı oranı (ortalama %12-15)
        annual_rate = 0.13
        
        # Toplam değer kaybı
        total_depreciation = (original_price_estimate - current_avg_price) / original_price_estimate * 100
        
        depreciation_analysis = {
            'car_age_years': car_age,
            'annual_depreciation_rate': f"%{int(annual_rate * 100)}",
            'total_depreciation': f"%{int(total_depreciation)}",
            'current_value_ratio': f"%{int((1 - annual_rate) ** car_age * 100)}",
            'original_price_estimate': int(original_price_estimate),
            'current_value': int(current_avg_price)
        }
        
        print(f"📉 Değer Kaybı Analizi:")
        print(f"   Araç Yaşı: {car_age} yıl")
        print(f"   Yıllık Değer Kaybı: %{int(annual_rate * 100)}")
        print(f"   Toplam Değer Kaybı: %{int(total_depreciation)}")
        
        return depreciation_analysis
    
    def _generate_recommendations(
        self, 
        market_analysis: Dict[str, Any],
        depreciation_analysis: Dict[str, Any],
        target_price: Optional[int] = None
    ) -> Dict[str, Any]:
        """
        Müşteri önerileri üretir
        
        Args:
            market_analysis: Piyasa analizi
            depreciation_analysis: Değer kaybı analizi
            target_price: Hedef fiyat (opsiyonel)
        
        Returns:
            Müşteri önerileri
        """
        avg_price = market_analysis['average_price']
        min_price = market_analysis['min_price']
        max_price = market_analysis['max_price']
        
        # Alış fiyatı önerileri
        recommended_buy_max = int(avg_price * 0.94)  # %6 altı
        recommended_buy_target = int(avg_price * 0.88)  # %12 altı
        recommended_buy_ideal = int(avg_price * 0.82)  # %18 altı
        
        # Satış fiyatı önerisi
        recommended_sell_price = int(avg_price * 1.05)  # %5 üstü
        
        # Risk seviyesi
        price_range = market_analysis['price_range']
        std_dev = market_analysis['std_deviation']
        sample_size = market_analysis['sample_size']
        
        if sample_size < 5:
            risk_level = "YÜKSEK (Az veri)"
            risk_emoji = "🔴"
        elif std_dev / avg_price > 0.15:
            risk_level = "ORTA (Fiyat dalgalanması)"
            risk_emoji = "🟡"
        else:
            risk_level = "DÜŞÜK (İstikrarlı piyasa)"
            risk_emoji = "🟢"
        
        # Kar hesaplama
        profit_analysis = {}
        if target_price:
            potential_profit = recommended_sell_price - target_price
            profit_margin = (potential_profit / target_price) * 100
            
            profit_analysis = {
                'buy_price': target_price,
                'recommended_sell_price': recommended_sell_price,
                'potential_profit': potential_profit,
                'profit_margin': f"%{int(profit_margin)}"
            }
        
        recommendations = {
            'buy_prices': {
                'max': recommended_buy_max,
                'target': recommended_buy_target,
                'ideal': recommended_buy_ideal
            },
            'sell_price': recommended_sell_price,
            'risk_level': risk_level,
            'risk_emoji': risk_emoji,
            'profit_analysis': profit_analysis,
            'opportunity_score': self._calculate_opportunity_score(min_price, avg_price, target_price)
        }
        
        print(f"🎯 Alış Fiyatı Önerileri:")
        print(f"   Maximum: {recommended_buy_max:,} TL")
        print(f"   Hedef: {recommended_buy_target:,} TL")
        print(f"   İdeal: {recommended_buy_ideal:,} TL")
        print(f"📈 Satış Fiyatı: {recommended_sell_price:,} TL")
        print(f"⚠️  Risk Seviyesi: {risk_emoji} {risk_level}")
        
        return recommendations
    
    def _calculate_opportunity_score(
        self, 
        min_price: int, 
        avg_price: int,
        target_price: Optional[int]
    ) -> str:
        """
        Fırsat skoru hesaplar
        
        Args:
            min_price: Minimum fiyat
            avg_price: Ortalama fiyat
            target_price: Hedef fiyat
        
        Returns:
            Fırsat skoru (0-100)
        """
        if target_price and avg_price > 0:
            discount_ratio = (avg_price - target_price) / avg_price
            score = int(discount_ratio * 100)
            
            if score >= 20:
                return f"{score}/100 ⭐⭐⭐ (Mükemmel Fırsat)"
            elif score >= 15:
                return f"{score}/100 ⭐⭐ (İyi Fırsat)"
            elif score >= 10:
                return f"{score}/100 ⭐ (Fırsat)"
            else:
                return f"{score}/100 (Normal)"
        else:
            return "N/A"
    
    def generate_customer_report(self, report: Dict[str, Any]) -> str:
        """
        Müşteri için okunabilir rapor üretir
        
        Args:
            report: Analiz raporu
        
        Returns:
            Formatlanmış metin raporu
        """
        vehicle = report['vehicle_info']
        market = report['market_analysis']
        depreciation = report['depreciation_analysis']
        recommendations = report['recommendations']
        
        lines = []
        lines.append("╔" + "═" * 78 + "╗")
        lines.append("║" + " " * 15 + "📊 ARACINIZ İÇİN PİYASA ANALİZİ" + " " * 33 + "║")
        lines.append("╠" + "═" * 78 + "╣")
        
        # Araç bilgisi
        lines.append(f"║  Model: {vehicle['brand']} {vehicle['model']} {vehicle['year']}" + " " * (78 - len(f"  Model: {vehicle['brand']} {vehicle['model']} {vehicle['year']}")) + "║")
        lines.append("║  ─────────────────────────────────────────────────────────────────────  ║")
        
        # Veri kaynakları
        sources = report['data_sources']
        lines.append(f"║  📊 Veri Kaynakları:" + " " * (78 - len(f"  📊 Veri Kaynakları:")) + "║")
        lines.append(f"║  ├─ Arabam.com: {sources['arabam']} ilan" + " " * (78 - len(f"  ├─ Arabam.com: {sources['arabam']} ilan")) + "║")
        lines.append(f"║  └─ Borusan: {sources['borusan']} ilan" + " " * (78 - len(f"  └─ Borusan: {sources['borusan']} ilan")) + "║")
        lines.append(f"║  Toplam: {sources['total']} ilan analiz edildi" + " " * (78 - len(f"  Toplam: {sources['total']} ilan analiz edildi")) + "║")
        lines.append("║  ─────────────────────────────────────────────────────────────────────  ║")
        
        # Fiyat analizi
        lines.append(f"║  💰 FİYAT ANALİZİ:" + " " * (78 - len(f"  💰 FİYAT ANALİZİ:")) + "║")
        lines.append(f"║  ├─ En Düşük (Fırsat):    {market['min_price']:,} TL ⭐" + " " * (78 - len(f"  ├─ En Düşük (Fırsat):    {market['min_price']:,} TL ⭐")) + "║")
        lines.append(f"║  ├─ Ortalama Piyasa:       {market['average_price']:,} TL" + " " * (78 - len(f"  ├─ Ortalama Piyasa:       {market['average_price']:,} TL")) + "║")
        lines.append(f"║  └─ En Yüksek:            {market['max_price']:,} TL" + " " * (78 - len(f"  └─ En Yüksek:            {market['max_price']:,} TL")) + "║")
        lines.append("║  ─────────────────────────────────────────────────────────────────────  ║")
        
        # Değer kaybı
        lines.append(f"║  📉 DEĞER KAYBI:" + " " * (78 - len(f"║  📉 DEĞER KAYBI:")) + "║")
        lines.append(f"║  ├─ Araç Yaşı:              {depreciation['car_age_years']} yıl" + " " * (78 - len(f"  ├─ Araç Yaşı:              {depreciation['car_age_years']} yıl")) + "║")
        lines.append(f"║  ├─ Yıllık Değer Kaybı:     {depreciation['annual_depreciation_rate']}" + " " * (78 - len(f"  ├─ Yıllık Değer Kaybı:     {depreciation['annual_depreciation_rate']}")) + "║")
        lines.append(f"║  └─ Toplam Değer Kaybı:     {depreciation['total_depreciation']}" + " " * (78 - len(f"  └─ Toplam Değer Kaybı:     {depreciation['total_depreciation']}")) + "║")
        lines.append("║  ─────────────────────────────────────────────────────────────────────  ║")
        
        # Önerilen alış fiyatları
        buy = recommendations['buy_prices']
        lines.append(f"║  🎯 ÖNERİLEN ALIŞ FİYATI:" + " " * (78 - len(f"  🎯 ÖNERİLEN ALIŞ FİYATI:")) + "║")
        lines.append(f"║  ├─ Maximum:               {buy['max']:,} TL" + " " * (78 - len(f"  ├─ Maximum:               {buy['max']:,} TL")) + "║")
        lines.append(f"║  ├─ Hedef:                 {buy['target']:,} TL" + " " * (78 - len(f"  ├─ Hedef:                 {buy['target']:,} TL")) + "║")
        lines.append(f"║  └─ İdeal:                 {buy['ideal']:,} TL ⭐" + " " * (78 - len(f"  └─ İdeal:                 {buy['ideal']:,} TL ⭐")) + "║")
        lines.append("║  ─────────────────────────────────────────────────────────────────────  ║")
        
        # Kar analizi
        profit = recommendations.get('profit_analysis', {})
        if profit:
            lines.append(f"║  💡 NE KADAR KAR?" + " " * (78 - len(f"  💡 NE KADAR KAR?")) + "║")
            profit_margin = profit['profit_margin']
            potential_profit = profit['potential_profit']
            
            if potential_profit > 0:
                profit_emoji = "⭐" if int(profit_margin.replace('%','')) > 15 else ""
                lines.append(f"║  └─ {profit['buy_price']:,} TL'ya alıp {recommendations['sell_price']:,} TL'ya satarsan: +{potential_profit:,} TL ({profit_margin}) {profit_emoji}" + " " * (78 - len(f"  └─ {profit['buy_price']:,} TL'ya alıp {recommendations['sell_price']:,} TL'ya satarsan: +{potential_profit:,} TL ({profit_margin}) {profit_emoji}")) + "║")
            else:
                lines.append(f"║  └─ Bu fiyatla almak karlı değil!" + " " * (78 - len(f"  └─ Bu fiyatla almak karlı değil!")) + "║")
            
            lines.append("║  ─────────────────────────────────────────────────────────────────────  ║")
        
        # Risk seviyesi
        lines.append(f"║  ⚠️  Risk Seviyesi: {recommendations['risk_emoji']} {recommendations['risk_level']}" + " " * (78 - len(f"║  ⚠️  Risk Seviyesi: {recommendations['risk_emoji']} {recommendations['risk_level']}")) + "║")
        lines.append("╚" + "═" * 78 + "╝")
        
        return "\n".join(lines)