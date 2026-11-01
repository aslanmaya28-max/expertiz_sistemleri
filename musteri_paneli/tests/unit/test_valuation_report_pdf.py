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


def test_pdf_akilli_alici_bolumleri_turkce_ve_uzun_url():
    long_url = 'https://forum.example.test/'+'ç'*10+'b'*900
    report = {
        'arac': {'marka': 'Renault', 'model': 'Clio', 'yil': 2020, 'km': 60000, 'ilanFiyati': 1050000},
        'karar': {'sonuc': 'PAZARLIK YAP', 'aciklama': 'Fiyat yüksek', 'guvenSeviyesi': 'orta'},
        'degerleme': {'temizPiyasaDegeri': 950000, 'tavsiyeFiyat': 920000,
                      'adilFiyatAraligi': {'min': 900000, 'max': 960000}, 'kalemler': []},
        'piyasa': {'guvenSkoru': 80, 'kaynaklar': []},
        'pazarlikPlani': {'acilisTeklifi': 900000, 'hedefFiyat': 930000, 'ustSinir': 960000,
                          'potansiyelKazanc': 120000, 'adimlar': ['Açılış teklifini verin.'],
                          'gerekceler': ['Sağ ön çamurluk boyalı'], 'saticiMesaji': 'Merhaba, 2020 Renault Clio için 900.000 TL öneriyorum.',
                          'kanitIlanlar': [{'site': 'arabam.com', 'url': long_url, 'fiyat': 930000, 'yil': 2020, 'km': 58000},
                                           {'site': 'otoshops', 'url': None, 'fiyat': 940000, 'yil': 2020, 'km': 61000}]},
        'modelRiskleri': {'riskler': [{'baslik': f'Şanzıman titreşimi {n}', 'aciklama': 'Düşük devirde sarsıntı.',
                                       'belirtiler': ['Kalkışta titreme'], 'kontrol': 'Yol testi', 'guven': 'orta',
                                       'kaynaklar': [long_url]} for n in range(25)]
                          + [{'baslik': 'Forum söylentisi', 'kontrol': '-', 'guven': 'dusuk', 'kaynaklar': []},
                             {'baslik': 'Resmi geri çağırma', 'kontrol': 'Şasi sorgusu', 'guven': 'yuksek', 'kaynaklar': []}],
                          'bulunamadi': False},
        'bakim': [{'baslik': 'Fren ve lastik kontrolü', 'aciklama': 'Geçmişi doğrulayın.', 'kontrol': 'Faturalar'}],
        'saticiSorulari': ['Ekspertize izin veriyor musunuz?', 'Motor kaputu neden boyandı?'],
        'rapor': {'id': 't', 'report_no': 'YD 2026-000002', 'created_at': '2026-11-02T10:00:00+00:00',
                  'verification_code': 'YD-WXYZ-2345'},
    }
    content = build_pdf(report)
    with pdfplumber.open(io.BytesIO(content)) as document:
        assert len(document.pages) >= 3  # 25 risk sayfa taşırır
        text = '\n'.join(page.extract_text() for page in document.pages)
        for part in ('Pazarlık planı', 'Açılış teklifi: 900.000 TL', 'Modelin bilinen sorunları', 'Şanzıman titreşimi 24',
                     'Resmi kaynak', 'kaynakta belirtilmemiş', 'Bu kilometrede doğrulanacak bakımlar',
                     'Satıcıya sorulacak sorular', '2. Motor kaputu neden boyandı?',
                     'Bu aracı YerimeBak ile yerinde inceletin', 'https://www.yerimebak.com.tr/ekspertiz-talebi'):
            assert part in text, part
        assert 'Forum söylentisi' not in text and 'doğrulanmamış' not in text and 'Güven:' not in text
        assert 'Maliyet' not in text.split('Bu kilometrede doğrulanacak bakımlar')[1].split('Satıcıya sorulacak')[0]
        for page in document.pages:
            assert all(0 <= ch['x0'] < ch['x1'] <= page.width+1 for ch in page.chars)
