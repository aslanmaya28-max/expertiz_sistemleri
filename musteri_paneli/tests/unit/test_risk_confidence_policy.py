"""029: iki bağımsız, aynı araç ve konu kapsamındaki teknik kanıt."""
import pytest
from yerimebak_ai_v5.services import vehicle_risk as vr

VEHICLE = dict(brand='Seat', model='Arona', engine='1.0 TSI', package='1.0 TSI DSG',
               fuel='Benzin', transmission='Otomatik', year=2020, km=90000)
A = 'https://engineering.example.com/arona'
B = 'https://technical.example.org/arona'
TEXT_A = 'Seat Arona 1.0 TSI DSG triger kayışında erken aşınma kontrol edilmelidir; servis geçmişi incelenir.'
TEXT_B = 'Arona 1.0 TSI modelinde triger incelemesi yapılırken dişlerde çatlak aranır ve bakım faturaları karşılaştırılır.'

def verify(sources):
    return vr._verify(dict(baslik='Triger aşınması', etkiledigi='1.0 TSI DSG',
                           kaynaklar=list(sources)), sources, VEHICLE)

def test_two_independent_scoped_technical_sources():
    out = verify({A: TEXT_A, B: TEXT_B})
    assert out['guven'] == 'orta'
    assert out['kanitSeviyesi'] == 'İki bağımsız teknik kaynak'
    assert out['tahminiMaliyet'] is None
    assert 'tipikKm' not in out

@pytest.mark.parametrize('sources', [
    {A: TEXT_A},
    {A: TEXT_A, A + '/other': TEXT_B},
    {A: TEXT_A, B: TEXT_A},
    {A: TEXT_A, B: 'Arona tanıtımı. 1.0 TSI triger incelenir.'},
    {A: TEXT_A, B: 'Arona triger incelemesi.'},
    {A: TEXT_A, B: 'Ibiza 1.0 TSI triger kontrolü.'},
    {'https://forum.example.com/arona': TEXT_A, 'https://reddit.com/r/arona': TEXT_B},
    {A: TEXT_A, B: TEXT_B + ' Kaynak: https://engineering.example.com/arona'},
], ids=['single', 'same-root', 'copy', 'split-scope', 'no-engine', 'wrong-model', 'forums', 'citation'])
def test_no_unearned_upgrade(sources):
    assert verify(sources)['guven'] == 'dusuk'
    assert verify(sources)['kanitSeviyesi'] == 'Kullanıcı deneyimi'

@pytest.mark.parametrize('url', ['https://static.nhtsa.gov/odi/tsbs/2020/MC-10123456-0001.pdf',
                               'https://www.kba.de/recall/123',
                               'https://ec.europa.eu/safety-gate/123'])
def test_official_record(url):
    out = verify({url: 'Seat Arona 1.0 TSI DSG triger servis bülteni recall.'})
    assert out['guven'] == 'yuksek'
    assert out['kanitSeviyesi'] == 'Resmî kayıt'

def test_unscoped_price_and_km_not_borrowed_from_third_source():
    sources = {A: TEXT_A, B: TEXT_B,
               'https://forum.example.net/post': 'Arona 1.0 TSI triger 80.000–100.000 km. Triger 10.000–15.000 TL.'}
    out = vr._verify(dict(baslik='Triger aşınması', etkiledigi='1.0 TSI', kaynaklar=list(sources),
                          tahminiMaliyet={'min':10000, 'max':15000}), sources, VEHICLE)
    assert out['guven'] == 'orta'
    assert out['tahminiMaliyet'] is None
    assert 'tipikKm' not in out
