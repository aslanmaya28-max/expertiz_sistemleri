"""YerimeBak piyasa takibi: admin'in yapıştırdığı arama listesi (verisi az olan modeller)."""
import pytest

from .test_dispatch_flow import client, customer_token, admin_token, _auth, TEST_DB  # noqa: F401

pytestmark = pytest.mark.skipif(not TEST_DB, reason='TEST_DATABASE_URL tanımlı değil')

# Gerçek ilan metni yerine aynı biçimde uydurma satırlar (depo herkese açık)
SAYFA = (
    '"Arazi, SUV & Pickup MG Fiyatları & Modelleri"\naramanızda\n3 ilan\nbulundu.\n'
    'ORNEK GALERI 2024 MG HS LUXURY #1000000001\tHS\t1.5 T-GDI\t\nORNEK GALERI 2024 MG HS LUXURY\n'
    '2024\t40.000\tSiyah\t\n1.670.000 TL\n02 Kasım\n2026\tİstanbul\nBahçelievler\n'
    'ORNEK 2024 YENI HS 170 HP #1000000002\tHS\t1.5 T-GDI\t\nORNEK 2024 YENI HS 170 HP\n'
    '2024\t30.000\tGri\t\n1.900.000 TL\n01 Kasım\n2026\tAnkara\nÇankaya\n'
    'ORNEK 2023 HS 162HP #1000000003\tHS\t1.5 T-GDI\t\nORNEK 2023 HS 162HP\n'
    '2023\t60.000\tBeyaz\t\n1.600.000 TL\n31 Ekim\n2026\tİzmir\nKarşıyaka\n'
)


def test_yalniz_admin_erisir(client, customer_token):
    h = _auth(customer_token)
    assert client.post('/api/v1/admin/market/manual/preview', headers=h, json={'text': SAYFA}).status_code == 403
    assert client.get('/api/v1/admin/market/gaps', headers=h).status_code == 403


def test_onizleme_kayit_ve_tekrar(client, admin_token):
    h = _auth(admin_token)
    r = client.post('/api/v1/admin/market/manual/preview', headers=h, json={'text': SAYFA})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body['marka'] == 'MG' and len(body['satirlar']) == 3
    satir = body['satirlar'][1]
    assert (satir['seri'], satir['yil'], satir['km'], satir['fiyat'], satir['beygir']) == ('HS', 2024, 30000, 1_900_000, 170)
    assert satir['ilan_tarihi'] == '2026-11-01' and satir['il'] == 'Ankara'
    assert 'ORNEK' not in str(body['satirlar']) and '1000000002' not in str(body['satirlar'])  # başlık / ilan no saklanmaz
    saved = client.post('/api/v1/admin/market/manual/save', headers=h, json={'brand': 'MG', 'satirlar': body['satirlar']})
    assert saved.json() == {'eklenen': 3, 'tekrar': 0}
    again = client.post('/api/v1/admin/market/manual/save', headers=h, json={'brand': 'MG', 'satirlar': body['satirlar']})
    assert again.json() == {'eklenen': 0, 'tekrar': 3}
    from yerimebak_ai_v5.services import manual_market
    found = manual_market.find({'brand': 'mg', 'model': 'HS'})
    assert sorted(i['fiyat_tl'] for i in found) == [1_600_000, 1_670_000, 1_900_000]
    assert all(i['url'].startswith('manuel://') and i['_manual'] for i in found)


def test_bos_liste_422(client, admin_token):
    r = client.post('/api/v1/admin/market/manual/preview', headers=_auth(admin_token), json={'text': 'bu bir ilan listesi değil'})
    assert r.status_code == 422
