"""Uzun URL, Türkçe metin, tahmin ve çok sayfalı kayıp tablosu."""
import io

import pdfplumber

from yerimebak_ai_v5.services.valuation_report_pdf import build_pdf, DISCLAIMER


def test_turkish_pdf_long_content_and_complete_sections():
    report = {
        'arac': {'marka': 'Örnek', 'model': 'Çığ Şişli', 'yil': 2024, 'km': 30000,
                 'ilanFiyati': 1000000},
        'karar': {'sonuc': 'PAZARLIK YAP', 'aciklama': 'İlan/müşteri beyanı', 'guvenSeviyesi': 'orta'},
        'degerleme': {'temizPiyasaDegeri': 1000000, 'tavsiyeFiyat': 950000,
                      'adilFiyatAraligi': {'min': 900000, 'max': 1000000},
                      'kalemler': [{'baslik': f'Türkçe kalem {n}', 'durum': 'Değişen', 'yuzde': 1.2, 'tutar': 12000} for n in range(55)]},
        'piyasa': {'guvenSkoru': 60, 'kaynaklar': [{'site': 'Örnek', 'url': 'https://example.test/'+'a'*1200,
                                                 'yil': 2024, 'km': 30000, 'fiyat': 950000}]},
        'ozet': {'piyasaKonumu': {'metin': 'Piyasa üstü'}, 'adilFiyat': {'min': 900000, 'max': 1000000},
                 'riskler': ['Şüpheli beyan'], 'pazarlikGerekceleri': ['Sağ ön çamurluk'],
                 'simdiNeYapmali': 'Uzman incelemesi isteyin.'},
        'bilgiKaynaklari': [{'alan': 'Boya', 'kaynak': 'musteri_beyani', 'aciklama': 'Müşteri beyanı'}],
        'getiri': {'aylikEnflasyonYuzde': 2, 'kaynak': 'Varsayım',
                   'altiAy': {'ay': 6, 'tahminiDeger': 1100000, 'getiriTl': 150000, 'getiriYuzde': 15},
                   'birYil': {'ay': 12, 'tahminiDeger': 1200000, 'getiriTl': 250000, 'getiriYuzde': 25},
                   'aciklama': 'Tahmindir, kesin değildir.'},
        'rapor': {'id': 'test', 'report_no': 'YD 2026-000001', 'created_at': '2026-11-01T21:30:00+00:00',
                  'verification_code': 'YD-ABCD-2345'},
    }
    content = build_pdf(report)
    assert content.startswith(b'%PDF')
    with pdfplumber.open(io.BytesIO(content)) as document:
        assert len(document.pages) >= 3
        text = '\n'.join(page.extract_text() for page in document.pages)
        assert 'Örnek Çığ Şişli 2024' in text
        assert '02.11.2026' in text  # İstanbul tarihi
        assert 'Türkçe kalem 54' in text
        assert '12 ay: 1.200.000 TL' in text
        assert 'https://www.yerimebak.com.tr/dogrula/YD-ABCD-2345' in text
        assert DISCLAIMER in text
        for page in document.pages:
            assert all(0 <= ch['x0'] < ch['x1'] <= page.width+1 for ch in page.chars)
