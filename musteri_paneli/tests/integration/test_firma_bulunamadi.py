"""Kurumsal firma modeli ve 'araç adreste bulunamadı' akışı uçtan uca (sözleşme 2026-11-09 bölüm 3-4)."""
import pytest

from .test_dispatch_flow import (client, admin_token, customer_token, _auth, _login, _create_paid_request,  # noqa: F401
                                 TEST_DB)

pytestmark = pytest.mark.skipif(not TEST_DB, reason='TEST_DATABASE_URL tanımlı değil')


def _personel(client, admin_token, email, firm_id):
    r = client.post('/api/v1/personnel/admin/personnel', headers=_auth(admin_token), json={
        'full_name': f'Saha {email[:6]}', 'email': email, 'temporary_password': 'Personel123', 'phone': '',
        'city': 'İstanbul', 'district': 'Kadıköy', 'expertise': 'Kaporta', 'firm_id': firm_id})
    assert r.status_code == 200, r.text
    return r.json()['personnel']


def test_firma_personeli_ve_arac_bulunamadi_kismi_iade(client, admin_token, customer_token, monkeypatch):
    monkeypatch.setenv('APP_EXPERTIZ_ENABLED', 'true')
    firmalar = client.get('/api/v1/expertiz/packages').json()['firms']
    a, b = firmalar[0], firmalar[1]
    pa = _personel(client, admin_token, 'firma-a@yerimebak.test', a['id'])
    pb = _personel(client, admin_token, 'firma-b@yerimebak.test', b['id'])
    assert pa['firm_id'] == a['id'] and pa['firm_name'] == a['name']
    assert client.post('/api/v1/personnel/admin/personnel', headers=_auth(admin_token), json={
        'full_name': 'X', 'email': 'yok@yerimebak.test', 'temporary_password': 'Personel123', 'city': 'İstanbul',
        'district': 'Kadıköy', 'firm_id': 'boyle-firma-yok'}).status_code == 400

    report_id = _create_paid_request(client, customer_token, '34 BUL 01', 'İstanbul', district='Kadıköy')

    adaylar = client.get(f'/api/v1/expertiz/admin/requests/{report_id}/candidates', headers=_auth(admin_token)).json()
    assert adaylar['firm_id'] == a['id']
    assert [c['id'] for c in adaylar['candidates']] == [pa['id']]
    yanlis = client.post(f'/api/v1/expertiz/admin/requests/{report_id}/assign', headers=_auth(admin_token),
                         json={'personnel_id': pb['id']})
    assert yanlis.status_code == 409 and yanlis.json()['detail']['code'] == 'firma_uyusmuyor'
    assert client.post(f'/api/v1/expertiz/admin/requests/{report_id}/assign', headers=_auth(admin_token),
                       json={'personnel_id': pa['id']}).status_code == 200

    saha = _login(client, 'firma-a@yerimebak.test', 'Personel123')
    # Kontrol merkezi (kullanıcı kararı 9 Kasım 2026): personel müşteriye/satıcıya doğrudan bağlanmaz;
    # görevde numara yok, yalnız kontrol merkezinin numarası. Numaraları yönetici (kontrol merkezi) görür.
    assert client.put('/api/v1/expertiz/admin/control-center', headers=_auth(admin_token),
                      json={'telefon': '123'}).status_code == 422
    assert client.put('/api/v1/expertiz/admin/control-center', headers=_auth(saha),
                      json={'telefon': '0850 111 22 33'}).status_code == 403
    ayar = client.put('/api/v1/expertiz/admin/control-center', headers=_auth(admin_token),
                      json={'telefon': '0850 111 22 33', 'calisma_saatleri': 'Her gün 08.00–20.00'}).json()
    assert ayar['telefon'] == '08501112233' and ayar['tanimli'] is True
    liste = client.get('/api/v1/expertiz/personnel/tasks', headers=_auth(saha)).json()
    assert liste['kontrol_merkezi']['telefon'] == '08501112233'
    gorev = next(t for t in liste['tasks'] if t['id'] == report_id)
    assert gorev['customer'] == {'name': 'Ayse M.'}
    assert 'satici_telefon' not in gorev['randevu'] and gorev['randevu']['adres']
    import json as _json
    assert '05551112233' not in _json.dumps(liste) and '05321112233' not in _json.dumps(liste)
    rapor = client.get(f'/api/v1/expertiz/personnel/tasks/{report_id}/report', headers=_auth(saha)).json()
    assert '05551112233' not in _json.dumps(rapor) and 'musteri@yerimebak.test' not in _json.dumps(rapor)
    # Personel kontrol merkezine not bırakır; kontrol merkezi müşteriyi arar ve kaydeder
    assert client.post(f'/api/v1/expertiz/personnel/tasks/{report_id}/control-note', headers=_auth(saha),
                       json={'note': 'Satıcı telefonu açmıyor, 10 dk sonra adresteyim'}).status_code == 200
    merkez = client.get('/api/v1/expertiz/admin/control-center/tasks', headers=_auth(admin_token)).json()
    satir = next(g for g in merkez['gorevler'] if g['id'] == report_id)
    assert satir['customer']['phone'] == '05551112233' and satir['randevu']['satici_telefon'] == '05321112233'
    assert satir['son_iletisim']['note'].startswith('Satıcı telefonu açmıyor')
    assert client.post(f'/api/v1/expertiz/admin/requests/{report_id}/contact-log', headers=_auth(admin_token),
                       json={'hedef': 'satici', 'sonuc': 'mesaj_birakildi', 'note': 'SMS atıldı'}).status_code == 200
    assert client.post(f'/api/v1/expertiz/admin/requests/{report_id}/contact-log', headers=_auth(admin_token),
                       json={'hedef': 'kimse', 'sonuc': 'ulasildi'}).status_code == 422
    kayitlar = client.get(f'/api/v1/expertiz/admin/requests/{report_id}/contact-log', headers=_auth(admin_token)).json()
    assert [k['hedef'] for k in kayitlar['kayitlar']] == ['satici', 'kontrol_merkezi']
    assert client.get(f'/api/v1/expertiz/admin/requests/{report_id}/contact-log', headers=_auth(saha)).status_code == 403
    # Kabul aşamasında 'araç yok' bildirilemez; yoldayken bildirilebilir
    assert client.post(f'/api/v1/expertiz/personnel/tasks/{report_id}/accept', headers=_auth(saha)).status_code == 200
    erken = client.post(f'/api/v1/expertiz/personnel/tasks/{report_id}/not-found', headers=_auth(saha),
                        json={'note': 'Satıcı açmadı, adreste yok'})
    assert erken.status_code == 409 and erken.json()['detail']['code'] == 'asama_uygun_degil'
    assert client.post(f'/api/v1/expertiz/personnel/tasks/{report_id}/depart', headers=_auth(saha)).status_code == 200
    kisa = client.post(f'/api/v1/expertiz/personnel/tasks/{report_id}/not-found', headers=_auth(saha), json={'note': 'yok'})
    assert kisa.status_code == 422 and kisa.json()['detail']['code'] == 'not_gerekli'
    # Personel iade yapamaz; iade bildirimden önce yapılamaz
    assert client.post(f'/api/v1/expertiz/admin/requests/{report_id}/not-found-refund', headers=_auth(saha),
                       json={'reason': 'x'}).status_code == 403
    once = client.post(f'/api/v1/expertiz/admin/requests/{report_id}/not-found-refund', headers=_auth(admin_token),
                       json={'reason': 'Araç yok'})
    assert once.status_code == 409 and once.json()['detail']['code'] == 'arac_bulunamadi_bildirimi_yok'

    ok = client.post(f'/api/v1/expertiz/personnel/tasks/{report_id}/not-found', headers=_auth(saha),
                     json={'note': 'Adrese gidildi, satıcı iki kez arandı, araç yerinde yok'})
    assert ok.status_code == 200, ok.text
    # Bildirimden sonra görev ilerletilemez
    assert client.post(f'/api/v1/expertiz/personnel/tasks/{report_id}/arrive', headers=_auth(saha)).status_code == 409
    detay = client.get(f'/api/v1/expertiz/admin/requests/{report_id}', headers=_auth(admin_token)).json()
    assert (detay.get('request') or detay)['durum_kodu'] == 'vehicle_not_found'

    iade = client.post(f'/api/v1/expertiz/admin/requests/{report_id}/not-found-refund', headers=_auth(admin_token),
                       json={'reason': 'Saha bildirimi doğrulandı'})
    assert iade.status_code == 200, iade.text
    sonuc = iade.json()
    paket = float(a['packages'][0]['price'])
    assert sonuc['refund_tl'] == paket and sonuc['status'] == 'cancelled'
    talep = next(r for r in client.get('/api/v1/expertiz/requests', headers=_auth(customer_token)).json()['requests']
                 if r['report_id'] == report_id)
    assert talep['durum_kodu'] == 'vehicle_not_found'
    assert sonuc['kept_tl'] == round(talep['total_tl'] - paket, 2)
    # İkinci kez iade edilmez
    assert client.post(f'/api/v1/expertiz/admin/requests/{report_id}/not-found-refund', headers=_auth(admin_token),
                       json={'reason': 'tekrar'}).status_code == 409

    finans = client.get('/api/v1/expertiz/admin/finance/summary', headers=_auth(admin_token)).json()
    firma = next(f for f in finans['firmalar'] if f['firm_id'] == a['id'])
    assert firma['bulunamadi_sayisi'] == 1 and firma['hakedis_tl'] > 0
    assert finans['iadeler']['expertiz_tl'] >= paket
