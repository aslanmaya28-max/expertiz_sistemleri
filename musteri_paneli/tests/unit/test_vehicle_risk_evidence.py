from copy import deepcopy
import pytest
from yerimebak_ai_v5.services import vehicle_risk as vr, risk_cost_search as cs

VEHICLE = {'brand': 'Seat', 'model': 'Arona', 'package': '1.0 TSI DSG', 'fuel': 'Benzin', 'year': 2020, 'km': 95000}
URL = 'https://www.seat.com/owners/recall'
PRICE = 'https://servis.test/onarim'
CANDIDATE = {'baslik': 'Mekatronik', 'etkiledigi': '1.0 TSI DSG', 'onem': 'dusuk',
             'kaynaklar': [URL], 'tahminiMaliyet': None}
SOURCE = 'Seat Arona 1.0 TSI DSG mekatronik servis bülteni. Mekatronik sorunu 80.000–100.000 km aralığında görülebilir.'


def setup_search(monkeypatch):
    monkeypatch.setenv('OPENROUTER_API_KEY', 'fake')
    monkeypatch.setenv('WEB_RISK_CACHE_DAYS', '0')
    monkeypatch.setattr(vr, '_search', lambda *a: {'risks': [deepcopy(CANDIDATE)], 'sources': {URL: SOURCE}, 'cost': .01})
    monkeypatch.setattr(cs, 'search', lambda *a, **k: {'items': [{'baslik': 'Mekatronik', 'onarim': 'Mekatronik onarımı',
        'tahminiMaliyet': {'min': 25000, 'max': 30000}, 'kaynaklar': [PRICE]}],
        'sources': {PRICE: 'Türkiye oto servis: Mekatronik onarımı 25.000–30.000 TL.'}, 'cost_usd': .004, 'searches': 1})


def test_extra_cost_km_scope_and_cache_recheck(monkeypatch):
    setup_search(monkeypatch)
    monkeypatch.setenv('WEB_RISK_CACHE_DAYS', '30')
    rows = {}
    monkeypatch.setattr(vr.wmr, '_cache_read', lambda key, hours: deepcopy(rows.get(key)))
    monkeypatch.setattr(vr.wmr, '_cache_write', lambda key, data: rows.update({key: deepcopy(data)}))
    result = vr.get_model_risks(VEHICLE)
    risk = result['riskler'][0]
    assert risk['tahminiMaliyet'] == {'min': 25000, 'max': 30000}
    assert risk['maliyetKaynagi']['url'] == PRICE and risk['maliyetKaynagi']['tarih']
    assert risk['tipikKm'] == {'min': 80000, 'max': 100000}
    assert risk['onem'] == 'orta' and risk['kilometreUyarisi'] == 'Bu kilometrede dikkat'
    assert result['scope']['cost_usd'] == pytest.approx(.014)
    assert result['scope']['cost_searches'] == 1
    monkeypatch.setattr(cs, 'search', lambda *a, **k: pytest.fail('önbellekte tekrar arama yok'))
    cached = vr.get_model_risks({**VEHICLE, 'km': 150000})
    assert cached['riskler'][0]['onem'] == 'dusuk'
    assert 'kilometreUyarisi' not in cached['riskler'][0]
    assert cached['riskler'][0]['tahminiMaliyet'] == risk['tahminiMaliyet']
    assert cached['scope']['cost_usd'] == 0


def test_unrelated_repair_and_model_cost_not_accepted(monkeypatch):
    setup_search(monkeypatch)
    monkeypatch.setattr(cs, 'search', lambda *a, **k: {'items': [{'baslik': 'Mekatronik', 'onarim': 'Şanzıman yağ değişimi',
        'tahminiMaliyet': {'min': 25000, 'max': 30000}, 'kaynaklar': [PRICE]}],
        'sources': {PRICE: 'Şanzıman yağ değişimi 25.000–30.000 TL.'}, 'cost_usd': .004, 'searches': 1})
    assert vr.get_model_risks(VEHICLE)['riskler'][0]['tahminiMaliyet'] is None


def test_legacy_cache_without_new_fields_survives(monkeypatch):
    monkeypatch.setenv('OPENROUTER_API_KEY', 'fake')
    monkeypatch.setenv('WEB_RISK_CACHE_DAYS', '30')
    legacy = {'riskler': [{'baslik': 'Triger', 'guven': 'orta', 'onem': 'yuksek', 'kaynaklar': [URL]},
                         {'baslik': 'DSG turbo arızası', 'guven': 'orta', 'kaynaklar': [URL]}],
              'kullaniciSikayetleri': [], 'scope': {'cached': True}}
    monkeypatch.setattr(vr.wmr, '_cache_read', lambda *a: deepcopy(legacy))
    result = vr.get_model_risks(VEHICLE)
    assert result['riskler'][0]['kategori'] == 'motor'
    assert result['riskler'][1]['kategori'] == 'motor'
    assert 'tipikKm' not in result['riskler'][0]


def test_cost_search_does_not_erase_cited_complaints_in_cache(monkeypatch):
    setup_search(monkeypatch)
    monkeypatch.setenv('WEB_RISK_CACHE_DAYS', '30')
    urls = ['https://sikayetvar.com/seat/arona', 'https://forum.donanimhaber.com/arona']
    monkeypatch.setattr(vr, '_search_complaints', lambda *a: {
        'complaints': [{'baslik': 'DSG titremesi', 'aciklama': 'Kullanıcı bildirimi', 'kaynaklar': urls}],
        'cited': {url: 'Seat Arona DSG titremesi kullanıcı şikayeti' for url in urls}, 'cost': .003})
    rows = {}
    monkeypatch.setattr(vr.wmr, '_cache_read', lambda key, hours: deepcopy(rows.get(key)))
    monkeypatch.setattr(vr.wmr, '_cache_write', lambda key, data: rows.update({key: deepcopy(data)}))
    cold = vr.get_model_risks(VEHICLE)
    assert cold['kullaniciSikayetleri']
    cached = vr.get_model_risks(VEHICLE)
    assert cached['kullaniciSikayetleri'] == cold['kullaniciSikayetleri']


def test_price_for_other_engine_cannot_borrow_vehicle_intro(monkeypatch):
    setup_search(monkeypatch)
    source = 'Seat Arona 1.0 TSI DSG. Seat Arona 1.4 TSI DSG mekatronik onarımı 25.000–30.000 TL.'
    monkeypatch.setattr(cs, 'search', lambda *a, **k: {'items': [{'baslik': 'Mekatronik',
        'onarim': 'Mekatronik onarımı', 'tahminiMaliyet': {'min': 25000, 'max': 30000}, 'kaynaklar': [PRICE]}],
        'sources': {PRICE: source}, 'cost_usd': .004, 'searches': 1})
    assert vr.get_model_risks(VEHICLE)['riskler'][0]['tahminiMaliyet'] is None
    risks = [{'baslik': 'Mekatronik', 'guven': 'orta', 'tahminiMaliyet': None}]
    vr._apply_extra(risks, [{'baslik': 'Mekatronik', 'onarim': 'Mekatronik onarımı', 'text': source,
                           'cost': {'min': 25000, 'max': 30000}, 'url': PRICE, 'tarih': '2026-11-05'}], VEHICLE)
    assert risks[0]['tahminiMaliyet'] is None


def test_generic_dsg_context_does_not_reject_specific_valid_fault():
    source = ('Seat Arona 1.0 TSI DSG servis bülteni. Arona 1.0 TSI mekatronik sorunu. '
              'Golf 1.4 TSI DSG yağ bakımı 80.000–100.000 km aralığında.')
    result = vr._verify({**CANDIDATE, 'baslik': 'DSG mekatronik'}, {URL: source}, VEHICLE)
    assert result is not None
    assert result['kategori'] == 'sanziman'
    assert 'tipikKm' not in result


def test_generic_dsg_price_is_not_price_of_specific_mechatronic_repair():
    source = ('Seat Arona 1.0 TSI DSG servis bülteni. Mekatronik sorunu kontrol edilir. '
              'DSG yağ değişimi 25.000–30.000 TL.')
    result = vr._verify({**CANDIDATE, 'baslik': 'DSG mekatronik',
                        'tahminiMaliyet': {'min': 25000, 'max': 30000}}, {URL: source}, VEHICLE)
    assert result is not None
    assert result['tahminiMaliyet'] is None


def test_specific_fault_in_wrong_engine_is_still_rejected():
    source = ('Seat Arona 1.0 TSI DSG servis bülteni. '
              'Golf 1.4 TSI DSG mekatronik sorunu 80.000–100.000 km aralığında.')
    assert vr._verify({**CANDIDATE, 'baslik': 'DSG mekatronik'}, {URL: source}, VEHICLE) is None


def test_gearbox_context_does_not_change_motor_fault_category():
    assert vr._classification({'baslik': 'DSG turbo arızası'}, vr._topics('DSG turbo arızası'), None)[0] == 'motor'
    title = 'Şanzıman yağ kaçağı'
    assert vr._classification({'baslik': title}, vr._topics(title), None)[0] == 'sanziman'


def test_gearbox_context_does_not_hide_specific_fault_km():
    source = ('Seat Arona 1.0 TSI DSG servis bülteni. '
              'Mekatronik sorunu DSG araçlarda 80.000–100.000 km aralığında görülebilir.')
    result = vr._verify({**CANDIDATE, 'baslik': 'DSG mekatronik'}, {URL: source}, VEHICLE)
    assert result['tipikKm'] == {'min': 80000, 'max': 100000}
    assert result['kilometreUyarisi'] == 'Bu kilometrede dikkat'


def test_existing_nhtsa_authority_recognizes_archived_ssm_record():
    vehicle = {'brand': 'Ford', 'model': 'Focus', 'package': '1.0 EcoBoost', 'year': 2017, 'fuel': 'Benzin'}
    url = 'https://static.nhtsa.gov/odi/tsbs/2018/MC-10148728-9999.pdf'
    text = 'SSM 47587. 2015-2018 Focus 1.0L EcoBoost. Coolant consumption, integrated exhaust manifold cracks.'
    assert vr._confidence(url, text, vehicle) == 'yuksek'
    assert vr._verify({'baslik': 'Soğutma sıvısı tüketimi', 'kaynaklar': [url]}, {url: text}, vehicle)['guven'] == 'yuksek'
    assert vr._confidence(url.replace('nhtsa.gov', 'nhtsa.gov.evil.test'), text, vehicle) == 'dusuk'
    assert vr._confidence('https://static.nhtsa.gov/general.pdf', text, vehicle) == 'dusuk'
    assert vr._confidence(url, text.replace('1.0L', '1.5L'), vehicle) == 'dusuk'
