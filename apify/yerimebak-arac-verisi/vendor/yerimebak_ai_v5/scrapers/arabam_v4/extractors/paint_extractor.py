# -*- coding: utf-8 -*-
"""
Arabam v4.0 - Paint Extractor
Boya/değişen bilgisi çıkarıcı - EN KRİTİK EXTRACTOR

Arabam'da fiyat belirleme için hayati önem taşıyor.
"""

from typing import List, Dict, Optional
from playwright.async_api import Page
from ..models.paint_info import PaintInfo
from ..models.enums import PaintStatus
from .base_extractor import BaseExtractor
from .selectors import ArabamSelectors


class PaintExtractor(BaseExtractor[PaintInfo]):
    """
    Boya/değişen bilgisi çıkarıcı
    
    Bu extractor Arabam.com için en kritik component'tir.
    Boya ve değişen parça bilgisi, araç fiyatını belirlemede
    en önemli faktörlerden biridir.
    
    Turkish Market Importance:
    - Orijinal/Boyasız araçlar %15-25 daha değerli
    - Değişen parça fiyatı %10-20 düşürebilir
    - Lokal boyalar daha az etkiler (%3-5)
    """
    
    # Boya keyword'leri
    PAINT_KEYWORDS = {
        'boyalı': ['boyalı', 'boya var', 'lokal boya', 'boyalı'],
        'değişen': ['değişen', 'parça değişen', 'değişmiş', 'tramer'],
        'orijinal': ['orijinal', 'boyasız', 'değişensiz', 'orjinal'],
    }
    
    # Gövde parçaları (17+ parça)
    BODY_PARTS = [
        'ön tampon', 'arka tampon', 'ön kaput', 'bagaj kapağı',
        'sağ ön çamurluk', 'sol ön çamurluk', 'sağ arka çamurluk', 'sol arka çamurluk',
        'sağ ön kapı', 'sol ön kapı', 'sağ arka kapı', 'sol arka kapı',
        'tavan', 'sağ ön panel', 'sol ön panel', 'sağ arka panel', 'sol arka panel',
        'amortisör', 'far', 'stop lambası', 'tampon',
    ]
    
    def __init__(self, page: Page):
        """
        Initialize paint extractor
        
        Args:
            page: Playwright page instance
        """
        super().__init__(page)
        self.selectors = ArabamSelectors()
    
    async def extract(self) -> PaintInfo:
        """
        Boya/değişen bilgisi çıkar
        
        3 farklı yöntem kullanır:
        1. Tablo/bölümden çıkar
        2. Sayfa metninden çıkar
        3. Structured data'dan çıkar
        
        Returns:
            PaintInfo: Boya bilgisi modeli
        """
        paint_info = PaintInfo()
        
        # Yöntem 1: Tablo/bölümden çıkar
        table_result = await self._extract_from_paint_table()
        
        # Yöntem 2: Sayfa metninden çıkar
        text_result = await self._extract_from_page_text()
        
        # Yöntem 3: Structured data'dan çıkar
        structured_result = await self._extract_from_structured_data()
        
        # Merge sonuçları
        paint_info = self._merge_results(paint_info, table_result, text_result, structured_result)
        
        # Sayıları güncelle
        paint_info.paint_count = len(paint_info.painted_parts)
        paint_info.changed_count = len(paint_info.changed_parts)
        
        # Status belirle
        paint_info.status = self._determine_status(paint_info)
        
        # Kalite skoru hesapla
        paint_info.confidence_score = self._calculate_confidence(paint_info)
        
        return paint_info
    
    async def _extract_from_paint_table(self) -> dict:
        """
        Tablo yapısından boya bilgisi çıkar.
        Arabam.com'da boya tablosu genellikle dinamik seçimlerden oluşur.
        KRİTİK: Önce negatif ifadeleri kontrol et!
        """
        result = {
            'has_paint': False,
            'has_changed': False,
            'is_original': False,
            'painted_parts': [],
            'local_paint_parts': [],  # Lokal boyalı parçalar
            'changed_parts': [],
            'details': []
        }
        
        try:
            # Sadece boya/hasar tablosunun içindeki satırları hedefle
            # Genellikle .boyabebil-wrapper veya benzeri bir container içindedir
            container = await self.page.query_selector(".boyadegisen-wrapper, .damage-info")
            rows = await (container or self.page).query_selector_all("tr")
            
            # ÖNCELİK: Tüm tabloya bakarak negatif ifade var mı kontrol et
            full_table_text = ""
            for row in rows:
                full_table_text += await row.inner_text() + " "
            full_table_text_lower = full_table_text.lower()
            
            # Negatif ifadeleri kontrol et
            negation_patterns = [
                'boya yok', 'boya değişen yok', 'boyasız', 'değişensiz',
                'orijinal boyası', 'orijinal parça', 'tramer yok',
                'kazası yok', 'hasar yok', 'değişen yoktur'
            ]
            
            has_negation = False
            for pattern in negation_patterns:
                if pattern in full_table_text_lower:
                    result['is_original'] = True
                    result['details'].append(f"✅ Tablo negatif tespit: '{pattern}'")
                    has_negation = True
                    break
            
            # Eğer negatif ifade bulduysa, tablo detayına girme
            if has_negation:
                return result
            
            # Detaylı satır analizi (sadece negatif yoksa)
            for row in rows:
                text = await row.inner_text()
                text_lower = text.lower().strip()
                
                # Başlıkları veya statik opsiyon listesini atla
                if "belirtilmemiş" in text_lower and "\n" in text:
                    # Bu büyük ihtimalle tablonun lejantı veya başlığıdır
                    continue

                # Arabam.com'da seçili olan opsiyon genellikle bir renkle veya 'selected' classı ile işaretlenir
                # Playwright ile seçili olanı bulmaya çalışalım
                selected_cell = await row.query_selector(".selected, .active, [class*='active'], [class*='selected']")
                if not selected_cell:
                    # Alternatif: Satırda 'boyalı' veya 'değişen' kelimesi geçiyor mu? 
                    # Ama sadece o hücrede mi geçiyor kontrol etmeliyiz.
                    # Eğer seçili hücre yoksa manuel check:
                    parts_of_text = text_lower.split('\n')
                    if len(parts_of_text) > 1:
                        # İlk kısım parça adı, ikinci kısım durum olabilir
                        part_name = parts_of_text[0].strip()
                        status = parts_of_text[1].strip()
                        
                        found_part = None
                        for p in self.BODY_PARTS:
                            if p in part_name:
                                found_part = p
                                break
                        
                        if found_part:
                            if 'boyalı' in status or 'local' in status:
                                result['has_paint'] = True
                                if found_part not in result['painted_parts']:
                                    result['painted_parts'].append(found_part)
                            elif 'değiş' in status:
                                result['has_changed'] = True
                                if found_part not in result['changed_parts']:
                                    result['changed_parts'].append(found_part)
                else:
                    # Seçili hücre varsa onun metnine bak
                    status_text = (await selected_cell.inner_text()).lower()
                    found_part = None
                    for p in self.BODY_PARTS:
                        if p in text_lower:
                            found_part = p
                            break
                    
                    if found_part:
                        if 'lokal' in status_text:
                            # Lokal boya - hem painted hem local_paint listesine ekle
                            result['has_paint'] = True
                            if found_part not in result['painted_parts']:
                                result['painted_parts'].append(found_part)
                            if found_part not in result['local_paint_parts']:
                                result['local_paint_parts'].append(found_part)
                        elif 'boyalı' in status_text:
                            # Normal boya
                            result['has_paint'] = True
                            if found_part not in result['painted_parts']:
                                result['painted_parts'].append(found_part)
                        elif 'değiş' in status_text:
                            result['has_changed'] = True
                            if found_part not in result['changed_parts']:
                                result['changed_parts'].append(found_part)
                                
        except Exception as e:
            self._extraction_log.append({
                'method': 'table_extraction',
                'success': False,
                'error': str(e)[:100]
            })
        
        return result

    async def _extract_from_page_text(self) -> dict:
        """
        Sayfa metninden boya bilgisi çıkar.
        KRİTİK: Negatif ifadeleri (yok, değil, yoktur) öncelikli kontrol et!
        """
        result = {'has_paint': False, 'has_changed': False, 'is_original': False, 'details': []}
        try:
            page_text = (await self.page.inner_text("body")).lower()
            
            # NEGATİF İFADELERİ ÖNCELİKLE KONTROL ET (KRİTİK!)
            # "boya yok", "değişen yok", "boyasız", "değişensiz" gibi ifadeler
            negation_patterns = [
                'boya yok', 'boya değişen yok', 'boyasız', 'değişensiz',
                'orijinal boyası', 'orijinal parça', 'tramer yok', 
                'kazası yok', 'hasar yok', 'değişen yoktur'
            ]
            
            has_negation = False
            for pattern in negation_patterns:
                if pattern in page_text:
                    result['is_original'] = True
                    result['details'].append(f"✅ Negatif tespit: '{pattern}' bulundu → Orijinal araç")
                    has_negation = True
                    break
            
            # Eğer negatif ifade bulduysa, pozitif arama yapma
            if has_negation:
                return result
            
            # Boya kontrolü (sadece negatif yoksa)
            for keyword in self.PAINT_KEYWORDS['boyalı']:
                # "yok" kelimesi ile birlikte kullanılıyorsa atla
                if f"{keyword} yok" in page_text:
                    continue
                if keyword in page_text:
                    result['has_paint'] = True
                    result['details'].append(f"Metin tespiti: {keyword}")
                    break
            
            # Değişen kontrolü (sadece negatif yoksa)
            for keyword in self.PAINT_KEYWORDS['değişen']:
                # "yok" kelimesi ile birlikte kullanılıyorsa atla
                if f"{keyword} yok" in page_text:
                    continue
                if keyword in page_text:
                    result['has_changed'] = True
                    result['details'].append(f"Metin tespiti: {keyword}")
                    break
            
            # Orijinal kontrolü (negatif yoksa)
            for keyword in self.PAINT_KEYWORDS['orijinal']:
                if keyword in page_text and not result['has_paint'] and not result['has_changed']:
                    result['is_original'] = True
                    break
        except:
            pass
        return result

    async def _extract_from_structured_data(self) -> dict:
        """
        Structured data (JSON-LD) extraction fallback.
        """
        return {'painted_parts': [], 'changed_parts': []}

    def _merge_results(self, paint_info: PaintInfo, *results) -> PaintInfo:
        """
        Tüm sonuçları birleştir.
        is_original mantığı düzeltildi: Boya/Değişen varsa Orijinal OLAMAZ.
        """
        any_paint = False
        any_changed = False
        consensus_original = False
        
        for result in results:
            if result.get('has_paint'): any_paint = True
            if result.get('has_changed'): any_changed = True
            if result.get('is_original'): consensus_original = True
            
            if 'painted_parts' in result:
                paint_info.painted_parts.extend(result['painted_parts'])
            if 'local_paint_parts' in result:
                paint_info.local_paint_parts.extend(result['local_paint_parts'])
            if 'changed_parts' in result:
                paint_info.changed_parts.extend(result['changed_parts'])
            if 'details' in result:
                paint_info.details.extend(result['details'])
        
        # Kesin bayrakları set et
        paint_info.has_paint = any_paint
        paint_info.has_changed = any_changed
        
        # KRİTİK DÜZELTME: Boya veya Değişen varsa Orijinal false olmalı
        if any_paint or any_changed:
            paint_info.is_original = False
        else:
            paint_info.is_original = consensus_original
        
        # Duplikeleri temizle
        paint_info.painted_parts = list(set(paint_info.painted_parts))
        paint_info.local_paint_parts = list(set(paint_info.local_paint_parts))
        paint_info.changed_parts = list(set(paint_info.changed_parts))
        paint_info.details = [d for d in list(set(paint_info.details)) if len(d) > 2] # çöpleri temizle
        
        # Sayıları güncelle
        paint_info.paint_count = len(paint_info.painted_parts)
        paint_info.local_paint_count = len(paint_info.local_paint_parts)
        paint_info.changed_count = len(paint_info.changed_parts)
        
        return paint_info
    
    def _determine_status(self, paint_info: PaintInfo) -> PaintStatus:
        """
        Durum belirle
        
        Args:
            paint_info: PaintInfo modeli
            
        Returns:
            PaintStatus: Boya durumu
        """
        if paint_info.is_original:
            return PaintStatus.ORIGINAL
        elif paint_info.has_changed and paint_info.has_paint:
            return PaintStatus.MIXED
        elif paint_info.has_changed:
            return PaintStatus.CHANGED
        elif paint_info.has_paint:
            return PaintStatus.PAINTED
        else:
            return PaintStatus.UNKNOWN
    
    def _calculate_confidence(self, paint_info: PaintInfo) -> float:
        """
        Kalite skoru hesapla (0-1)
        
        Args:
            paint_info: PaintInfo modeli
            
        Returns:
            float: Kalite skoru
        """
        score = 0.5  # Başlangıç
        
        # Bilgi varsa artır
        if paint_info.status != PaintStatus.UNKNOWN:
            score += 0.2
        
        # Parça detayları varsa artır
        if paint_info.painted_parts or paint_info.changed_parts:
            score += 0.2
        
        # Detaylı notlar varsa artır
        if paint_info.details:
            score += 0.1
        
        return min(score, 1.0)
