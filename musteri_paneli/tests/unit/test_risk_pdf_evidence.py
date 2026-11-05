import io
import pdfplumber
from .test_valuation_pdf_layout import tucson_report
from yerimebak_ai_v5.services.valuation_report_pdf import build_pdf


def test_pdf_new_categories_evidence_cost_km_and_complaints_no_price():
    report = tucson_report()
    report['modelRiskleri'] = {'gorunumSurumu': 2, 'riskler': [
        {'baslik': 'Mekatronik', 'kategori': 'sanziman', 'guven': 'orta',
         'kanitSeviyesi': 'Çok kaynaklı', 'onem': 'yuksek', 'kaynaklar': [],
         'tahminiMaliyet': {'min': 25000, 'max': 30000},
         'tipikKm': {'min': 80000, 'max': 100000}, 'kilometreUyarisi': 'Bu kilometrede dikkat',
         'maliyetKaynagi': {'url': 'https://servis.test/fiyat', 'tarih': '2026-11-05', 'onarim': 'Mekatronik onarımı'}},
        {'baslik': 'Boya soyulması', 'kategori': 'kaporta', 'guven': 'orta', 'kaynaklar': [], 'onem': 'dusuk'},
    ]}
    report['kullaniciSikayetleri'] = [{'baslik': 'Müşteri bildirimi', 'kategori': 'elektronik',
        'kaynakSayisi': 2, 'tahminiMaliyet': {'min': 9999, 'max': 9999}}]
    with pdfplumber.open(io.BytesIO(build_pdf(report))) as document:
        text = '\n'.join(page.extract_text() or '' for page in document.pages)
    for expected in ('Bu araçta dikkat edilecekler', 'Şanzıman', 'Kaporta', 'Elektronik',
                     'Çok kaynaklı', 'Kullanıcı deneyimi', '25.000–30.000 TL', 'Genelde 80.000–100.000 km',
                     'Bu kilometrede dikkat', 'https://servis.test/fiyat', 'Erişim: 2026-11-05',
                     'kaynakta belirtilmemiş'):
        assert expected in text
    assert '9.999' not in text
