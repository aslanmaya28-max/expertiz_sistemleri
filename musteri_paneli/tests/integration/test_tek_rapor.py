"""Tek rapor (1 kredi): pazarlik plani, model riskleri, bakim, satici sorulari, paralel arama, PDF."""
import time
import uuid

import pytest

from .test_dispatch_flow import client, customer_token, admin_token, _auth, TEST_DB  # noqa: F401
from .test_credit_admin_flow import sql
from yerimebak_ai_v5.services import valuation_service, vehicle_risk

pytestmark = pytest.mark.skipif(not TEST_DB, reason='TEST_DATABASE_URL tanımlı değil')

REFERENCE = {
    'found': True, 'count': 6, 'clean_count': 6, 'source': 'web_listings',
    'market_avg_price': 950000, 'market_median_price': 950000,
    'market_min_price': 900000, 'market_max_price': 1000000,
    'reference_median_km': 60000, 'reference_median_year': 2020, 'confidence': 80,
    'scope': {'cost_usd': 0.03},
    'samples': [{'site': 'arabam.com', 'url': 'https://www.arabam.com/ilan/clio/1', 'price': 930000,
                 'year': 2020, 'km': 58000},
                {'site': 'otoshops.com', 'url': 'https://www.otoshops.com/clio/2', 'price': 960000,
                 'year': 2020, 'km': 61000}],
}
RISKS = {
    'riskler': [{'baslik': 'Triger kayışı değişim periyodu', 'aciklama': '1.0 TCe motorda periyodik değişim.',
                 'etkiledigi': '1.0 TCe', 'belirtiler': ['Ses'], 'kontrol': 'Servis kaydı',
                 'tahminiMaliyet': {'min': 8000, 'max': 12000},
                 'kaynaklar': ['https://teknik.example/clio-triger'], 'guven': 'orta'}],
    'bulunamadi': False, 'scope': {'cached': False, 'searches': 1, 'cost_usd': 0.012},
}


@pytest.fixture
def musteri(client, customer_token):
    uid = client.get('/api/v1/auth/me', headers=_auth(customer_token)).json()['user']['id']
    sql('UPDATE users SET credits=3 WHERE id=%s', (uid,))
    return uid, _auth(customer_token)


def _payload(**kw):
    p = {'brand': 'Renault', 'model': 'Clio', 'package': '1.0 TCe Touch', 'year': 2020, 'km': 60000,
         'fuel': 'Benzin', 'transmission': 'Manuel', 'listed_price': 1050000,
         'parts': {'kaput': 'boyali'}, 'tramer_amount': 15000, 'request_id': str(uuid.uuid4())}
    p.update(kw)
    return p


def _krediler(uid):
    return sql('SELECT credits FROM users WHERE id=%s', (uid,), True)[0]['credits']


def test_tek_rapor_tum_bolumler_kayitta_ve_kredi_bir(client, musteri, monkeypatch):
    uid, headers = musteri
    asked = []
    monkeypatch.setattr(valuation_service.web_market_reference, 'get_reference', lambda v: dict(REFERENCE))
    monkeypatch.setattr(vehicle_risk, 'get_model_risks', lambda v: asked.append(v) or dict(RISKS))
    r = client.post('/api/v1/valuation/analyze', headers=headers, json=_payload())
    assert r.status_code == 200, r.text
    body = r.json()
    plan = body['pazarlikPlani']
    assert plan['acilisTeklifi'] <= plan['hedefFiyat'] <= plan['ustSinir'] <= 1050000
    assert '2020 Renault Clio' in plan['saticiMesaji']
    assert body['modelRiskleri']['riskler'][0]['baslik'].startswith('Triger')
    assert body['modelRiskleri']['bulunamadi'] is False and body['modelRiskleri']['mesaj'] is None
    assert any('Triger' in b['baslik'] for b in body['bakim'])
    assert any('Ekspertize izin' in q for q in body['saticiSorulari'])
    assert any('Motor Kaputu' in q for q in body['saticiSorulari'])
    # Ekspertiz on doldurmasi icin beyan
    assert body['arac']['paket'] == '1.0 TCe Touch'
    assert body['arac']['beyanEdilenParcalar'] == {'kaput': 'boyali'} and body['arac']['tramerTutari'] == 15000
    # Model riski aramasi arac surumuyle yapildi
    assert asked[0]['engine'] == '1.0 TCe Touch' and asked[0]['km'] == 60000
    assert body['kredi']['dusulen'] == 1 and _krediler(uid) == 2
    stored = sql('SELECT report_json, valuation_json FROM analysis_history WHERE id=%s', (body['rapor']['id'],), True)[0]
    for key in ('pazarlikPlani', 'modelRiskleri', 'bakim', 'saticiSorulari'):
        assert stored['report_json'][key] == body[key]
    import json
    maliyet = json.loads(stored['valuation_json'])
    assert maliyet['web_maliyet_usd'] == 0.03 and maliyet['risk_maliyet_usd'] == 0.012
    assert maliyet['toplam_maliyet_usd'] == 0.042
    pdf = client.get(f"/api/v1/valuation/reports/{body['rapor']['id']}/pdf", headers=headers)
    assert pdf.status_code == 200 and pdf.content.startswith(b'%PDF')


def test_risk_servisi_coksede_rapor_ve_kredi_dogru(client, musteri, monkeypatch):
    uid, headers = musteri

    def patladi(_v):
        raise RuntimeError('ağ hatası')

    monkeypatch.setattr(valuation_service.web_market_reference, 'get_reference', lambda v: dict(REFERENCE))
    monkeypatch.setattr(vehicle_risk, 'get_model_risks', patladi)
    r = client.post('/api/v1/valuation/analyze', headers=headers, json=_payload())
    assert r.status_code == 200, r.text
    body = r.json()
    assert body['modelRiskleri']['riskler'] == [] and 'tamamlanamadı' in body['modelRiskleri']['mesaj']
    assert body['bakim'] and body['saticiSorulari'] and body['pazarlikPlani']
    assert _krediler(uid) == 2


def test_emsal_yoksa_422_ve_kredi_dusmez(client, musteri, monkeypatch):
    uid, headers = musteri
    monkeypatch.setattr(valuation_service.web_market_reference, 'get_reference', lambda v: {'found': False})
    monkeypatch.setattr(valuation_service, 'get_market_reference_service',
                        lambda: type('S', (), {'get_reference': lambda self, **kw: {'count': 0, 'source': 'last_resort'}})())
    monkeypatch.setattr(vehicle_risk, 'get_model_risks', lambda v: dict(RISKS))
    r = client.post('/api/v1/valuation/analyze', headers=headers, json=_payload())
    assert r.status_code == 422, r.text
    assert _krediler(uid) == 3


def test_piyasa_ve_model_aramasi_paralel(client, musteri, monkeypatch):
    _, headers = musteri

    def yavas_piyasa(_v):
        time.sleep(1.0)
        return dict(REFERENCE)

    def yavas_risk(_v):
        time.sleep(1.0)
        return dict(RISKS)

    monkeypatch.setattr(valuation_service.web_market_reference, 'get_reference', yavas_piyasa)
    monkeypatch.setattr(vehicle_risk, 'get_model_risks', yavas_risk)
    start = time.monotonic()
    r = client.post('/api/v1/valuation/analyze', headers=headers, json=_payload())
    sure = time.monotonic() - start
    assert r.status_code == 200, r.text
    assert sure < 1.8, f'aramalar sirali calisti ({sure:.2f} sn)'
