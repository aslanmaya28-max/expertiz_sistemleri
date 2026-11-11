"""Şifre yenileme tüm eski JWT'leri iptal eder; mevcut cihaz yeni JWT alır."""
import pytest
from .test_dispatch_flow import client, TEST_DB, _auth
from .test_google_play_account import customer
from .test_credit_admin_flow import sql

pytestmark = pytest.mark.skipif(not TEST_DB, reason='TEST_DATABASE_URL tanımlı değil')

def test_sifre_degisince_eski_oturum_ve_refresh_reddedilir(client, customer):
    uid, old_headers, _ = customer
    response = client.post('/api/v1/auth/change-password', headers=old_headers,
                           json={'current_password': 'Musteri123!', 'new_password': 'YeniSifre456!'})
    assert response.status_code == 200, response.text
    new_headers = _auth(response.json()['token'])
    assert client.get('/api/v1/auth/me', headers=old_headers).status_code == 401
    assert client.post('/api/v1/auth/refresh-token', headers=old_headers).status_code == 401
    assert client.get('/api/v1/auth/me', headers=new_headers).status_code == 200
    assert client.post('/api/v1/auth/refresh-token', headers=new_headers).status_code == 200
    assert sql('SELECT token_version FROM users WHERE id=%s', (uid,), True)[0]['token_version'] == 1


def test_reset_ve_silme_oturum_surumu_artirir(client, customer):
    from yerimebak_ai_v5.services import account_service as account
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    uid, headers, _ = customer
    conn = DatabaseConfig.get_connection()
    try:
        token = account._issue_token(conn.cursor(), uid, 'reset_password', account.RESET_TTL)
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    response = client.post('/api/v1/auth/reset-password', json={'token': token, 'new_password': 'YeniSifre456!'})
    assert response.status_code == 200, response.text
    assert client.get('/api/v1/auth/me', headers=headers).status_code == 401
    assert sql('SELECT token_version FROM users WHERE id=%s', (uid,), True)[0]['token_version'] == 1
    result = account.delete_account(uid, 'YeniSifre456!')
    assert result.get('success'), result
    assert sql('SELECT token_version FROM users WHERE id=%s', (uid,), True)[0]['token_version'] == 2


def test_tvsiz_gecis_ve_personel_sifirlama(client, customer):
    from yerimebak_ai_v5.services.auth_service import _create_jwt
    from yerimebak_ai_v5.services import personnel_service
    uid, headers, email = customer
    legacy = _auth(_create_jwt({'sub': uid, 'email': email}))
    assert client.get('/api/v1/auth/me', headers=legacy).status_code == 200
    sql("UPDATE users SET role='personel' WHERE id=%s", (uid,))
    result = personnel_service.reset_personnel_password(str(uid), 'Personel456!', {'id': 'test-admin'})
    assert result.get('success'), result
    assert client.get('/api/v1/auth/me', headers=legacy).status_code == 401
    assert client.get('/api/v1/auth/me', headers=headers).status_code == 401
    assert client.post('/api/v1/auth/refresh-token', headers=legacy).status_code == 401
    response = client.post('/api/v1/auth/login', json={'email': email, 'password': 'Personel456!'})
    assert response.status_code == 200, response.text
    assert client.get('/api/v1/auth/me', headers=_auth(response.json()['token'])).status_code == 200
