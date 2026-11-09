"""Yerinde ekspertiz hizmet bölgesi, test kullanıcısı ve randevu alanları uçtan uca (sözleşme 2026-11-09)."""
import pytest

from .test_dispatch_flow import client, admin_token, customer_token, _auth, _login, _randevu, TEST_DB  # noqa: F401

pytestmark = pytest.mark.skipif(not TEST_DB, reason='TEST_DATABASE_URL tanımlı değil')


def _musteri(client, email):
    import zlib
    telefon = '0555' + str(zlib.crc32(email.encode()) % 10_000_000).zfill(7)
    r = client.post('/api/v1/auth/register', json={'email': email, 'password': 'Musteri123!', 'full_name': 'Test Kişi',
                                                    'phone': telefon, 'terms_accepted': True})
    assert r.status_code == 200, r.text
    return _login(client, email, 'Musteri123!')


def _govde(client, city, **ek):
    firm = client.get('/api/v1/expertiz/packages').json()['firms'][0]
    return {'firm_id': firm['id'], 'package_id': firm['packages'][0]['id'], 'city': city, 'district': 'Merkez',
            'contract_accepted': True, 'vehicle': {'brand': 'Fiat', 'model': 'Egea'}, **_randevu(), **ek}


def test_il_durumu_test_kullanicisi_ve_odemesiz_talep(client, admin_token, monkeypatch):
    monkeypatch.setenv('APP_EXPERTIZ_ENABLED', 'true')
    musteri = _musteri(client, 'bolge-musteri@yerimebak.test')
    testci = _musteri(client, 'bolge-test@yerimebak.test')

    # Yönetici: İstanbul açık, Ankara test, Adana kapalı
    r = client.put('/api/v1/expertiz/admin/service-area', headers=_auth(admin_token), json={'cities': [
        {'il': 'İstanbul', 'durum': 'acik'}, {'il': 'Ankara', 'durum': 'test'}, {'il': 'Adana', 'durum': 'kapali'}]})
    assert r.status_code == 200, r.text
    assert client.put('/api/v1/expertiz/admin/service-area', headers=_auth(admin_token),
                      json={'cities': [{'il': 'Atlantis', 'durum': 'acik'}]}).status_code == 422
    assert client.put('/api/v1/expertiz/admin/service-area', headers=_auth(musteri),
                      json={'cities': [{'il': 'Adana', 'durum': 'acik'}]}).status_code == 403

    herkese = client.get('/api/v1/expertiz/service-area').json()
    iller = {c['il']: c for c in herkese['cities']}
    assert len(iller) == 81 and herkese['pilot'] == 'İstanbul' and herkese['tester'] is False
    assert iller['İstanbul'] == {'il': 'İstanbul', 'durum': 'acik', 'talep_acabilir': True}
    assert iller['Ankara']['talep_acabilir'] is False and iller['Adana']['talep_acabilir'] is False

    # Kapalı ve test ilinde müşteri talep açamaz; açık ilde ödeme adımına geçer
    kapali = client.post('/api/v1/expertiz/requests', headers=_auth(musteri), json=_govde(client, 'Adana'))
    assert kapali.status_code == 422 and kapali.json()['detail']['code'] == 'il_kapali'
    test_ili = client.post('/api/v1/expertiz/requests', headers=_auth(musteri), json=_govde(client, 'Ankara'))
    assert test_ili.status_code == 422 and test_ili.json()['detail']['code'] == 'il_kapali'
    acik = client.post('/api/v1/expertiz/requests', headers=_auth(musteri), json=_govde(client, 'istanbul'))
    assert acik.status_code == 200, acik.text

    # Müşteri ödemesiz talep açamaz
    odemesiz = client.post('/api/v1/expertiz/requests/unpaid', headers=_auth(musteri), json=_govde(client, 'İstanbul'))
    assert odemesiz.status_code == 403 and odemesiz.json()['detail']['code'] == 'odemesiz_talep_yetkisi_yok'

    # Test kullanıcısı: test ilinde ödemesiz talep açabilir; randevu iş kaydına ve yönetici görünümüne gider
    uid = client.get('/api/v1/auth/me', headers=_auth(testci)).json()['user']['id']
    assert client.post(f'/api/v1/expertiz/admin/customers/{uid}/tester', headers=_auth(admin_token),
                       json={'tester': True}).json() == {'success': True, 'tester': True}
    gorunum = client.get('/api/v1/expertiz/service-area', headers=_auth(testci)).json()
    assert gorunum['tester'] is True
    assert {c['il']: c['talep_acabilir'] for c in gorunum['cities']}['Ankara'] is True
    yeni = client.post('/api/v1/expertiz/requests/unpaid', headers=_auth(testci), json=_govde(client, 'Ankara'))
    assert yeni.status_code == 200, yeni.text
    detay = client.get(f"/api/v1/expertiz/admin/requests/{yeni.json()['request_id']}", headers=_auth(admin_token)).json()
    talep = detay.get('request') or detay
    assert talep['randevu']['satici_telefon'] == '05321112233' and talep['city'] == 'Ankara'
    benim = client.get('/api/v1/expertiz/requests', headers=_auth(testci)).json()['requests']
    assert benim[0]['randevu']['adres'].startswith('Caferağa')
    musteriler = client.get('/api/v1/expertiz/admin/customers', headers=_auth(admin_token)).json()
    satirlar = musteriler.get('customers') or musteriler
    assert any(c['email'] == 'bolge-test@yerimebak.test' and c['tester'] for c in satirlar)

    # Genel anahtar kapalıyken açık ilde de yalnız test kullanıcısı
    monkeypatch.setenv('APP_EXPERTIZ_ENABLED', 'false')
    kapali_genel = client.post('/api/v1/expertiz/requests', headers=_auth(musteri), json=_govde(client, 'İstanbul'))
    assert kapali_genel.status_code == 422 and kapali_genel.json()['detail']['code'] == 'il_kapali'


@pytest.mark.parametrize('ek,kod', [
    ({'appointment_at': '2020-01-01T10:00'}, 'randevu_gecersiz'),
    ({'address': 'kısa'}, 'adres_eksik'),
    ({'seller_phone': '12'}, 'satici_telefon_gecersiz'),
    ({'not_found_accepted': False}, 'bulunamama_onayi_gerekli'),
])
def test_randevu_alanlari_zorunlu(client, customer_token, monkeypatch, ek, kod):
    monkeypatch.setenv('APP_EXPERTIZ_ENABLED', 'true')
    r = client.post('/api/v1/expertiz/requests', headers=_auth(customer_token), json=_govde(client, 'İstanbul', **ek))
    assert r.status_code == 422 and r.json()['detail']['code'] == kod, r.text
