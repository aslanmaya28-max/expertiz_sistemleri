from copy import deepcopy
from yerimebak_ai_v5.services.inspection_findings import enrich_report


def test_serious_first_cosmetic_only_for_negotiation_no_price_change():
    report = {'degerleme': {'aiDegeri': 900000}, 'ozet': {
        'riskler': ['Eski risk'], 'pazarlikGerekceleri': ['Eski gerekçe'],
        'simdiNeYapmali': 'Pazarlık edin.'},
        'pazarlikPlani': {'gerekceler': ['Eski gerekçe'], 'hedefFiyat': 850000},
        'bilgiKaynaklari': [{'alan': 'Boya, değişen ve tramer', 'kaynak': 'musteri_beyani'}]}
    prices = deepcopy(report['degerleme'])
    enrich_report(report, {'kaynak_turu': 'ekspertiz_raporu', 'ekspertiz_firma_adi': 'Örnek',
        'ekspertiz_rapor_tarihi': '2026-11-05', 'bulgular': [
            {'kategori': 'motor', 'metin': 'Motorda yağ kaçağı', 'ciddiyet': 'pazarlik'},
            {'kategori': 'kaporta', 'metin': 'Tamponda çizik', 'ciddiyet': 'pazarlik'}]})
    assert 'Motorda yağ kaçağı' in report['ozet']['riskler'][0]
    assert report['ozet']['simdiNeYapmali'].startswith('Önce')
    assert 'yerinde doğrulatın' in report['ozet']['simdiNeYapmali']
    assert 'Motorda' not in str(report['ozet']['pazarlikGerekceleri'])
    assert 'Tamponda çizik' in str(report['ozet']['pazarlikGerekceleri'])
    assert report['ozet']['pazarlikGerekceleri'] == report['pazarlikPlani']['gerekceler'][:3]
    assert report['degerleme'] == prices
    assert report['pazarlikPlani']['hedefFiyat'] == 850000
    assert report['bilgiKaynaklari'][0]['aciklama'] == 'Ekspertiz raporu (Örnek, 2026-11-05) — YerimeBak uzmanı tarafından doğrulanmadı'


def test_legacy_report_unchanged():
    report = {'ozet': {'riskler': ['Aynı']}}
    before = deepcopy(report)
    enrich_report(report, {})
    assert before == report
