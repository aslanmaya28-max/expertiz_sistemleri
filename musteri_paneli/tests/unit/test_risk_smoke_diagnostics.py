from types import SimpleNamespace
from tools.risk_smoke_diagnostics import compare_candidates


def test_zero_visible_does_not_mean_verified_candidates_regressed():
    url = 'https://forum.test/egea'
    items = [{'baslik': 'Triger'}, {'baslik': 'Bilinmeyen başlık'}]
    verified = [{'baslik': 'Triger', 'guven': 'dusuk', 'kaynaklar': [url]}]
    old = SimpleNamespace(_verified_items=lambda *a: verified)
    out = compare_candidates(items, {url: 'Egea 1.3 Multijet triger'},
                             {'model': 'Egea', 'engine': '1.3 Multijet'}, verified, old)
    assert out['raw_risk_count'] == 2
    assert out['current_verified_count'] == out['legacy_verified_count'] == 1
    assert out['current_visible_count'] == out['legacy_visible_count'] == 0
    assert out['confidence_counts'] == {'dusuk': 1}
    assert out['dropped'][0]['neden'] == 'Başlıkta tanınan teknik konu yok'
    assert out['low_confidence'][0]['kaynaklar'][0]['neden'] == 'Kullanıcı/derleme kaynağı'


def test_known_official_domain_is_not_reported_as_missing_from_list():
    url = 'https://static.nhtsa.gov/general.pdf'
    item = {'baslik': 'Soğutma', 'guven': 'dusuk', 'kaynaklar': [url]}
    old = SimpleNamespace(_verified_items=lambda *a: [item])
    out = compare_candidates([item], {url: 'Focus 1.0L EcoBoost coolant consumption'},
                             {'model': 'Focus', 'engine': '1.0 EcoBoost'}, [item], old)
    assert out['low_confidence'][0]['kaynaklar'][0]['neden'] == 'Resmî alan adı tanınıyor; kayıt türü doğrulanamadı'
