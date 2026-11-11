"""E-posta kotaları: gerçek PostgreSQL, sahte e-posta teslimi."""
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier

import pytest
from .test_dispatch_flow import client, TEST_DB  # noqa: F401
from .test_credit_admin_flow import sql

pytestmark = pytest.mark.skipif(not TEST_DB, reason='TEST_DATABASE_URL tanımlı değil')


def _clear():
    sql('DELETE FROM auth_mail_limits')


def test_kayit_ip_siniri_eposta_gondermeden_429_doner(client, monkeypatch):
    from yerimebak_ai_v5.services import email_service
    monkeypatch.setenv('KAYIT_IP_SINIRI', '2')
    _clear()
    outbox = email_service.capture_for_tests()
    try:
        for i in range(2):
            result = client.post('/api/v1/auth/register', json={
                'email': f'kota{i}@yerimebak.test', 'password': 'Deneme123!', 'terms_accepted': True},
                headers={'CF-Connecting-IP': '198.51.100.42'})
            assert result.status_code == 200, result.text
        denied = client.post('/api/v1/auth/register', json={
            'email': 'kota-fazla@yerimebak.test', 'password': 'Deneme123!', 'terms_accepted': True},
            headers={'CF-Connecting-IP': '198.51.100.42'})
        assert denied.status_code == 429
        assert 0 < int(denied.headers['retry-after']) <= 3600
        assert len(outbox) == 2
        rows = sql('SELECT anahtar FROM auth_mail_limits', fetch=True)
        assert rows and all('198.51.100.42' not in r['anahtar'] and '@' not in r['anahtar'] for r in rows)
    finally:
        email_service.stop_capture()


def test_forgot_ip_ve_hesap_sinirini_ayri_uygular(client, monkeypatch):
    from yerimebak_ai_v5.services import account_service
    monkeypatch.setenv('EPOSTA_IP_SINIRI', '3')
    monkeypatch.setenv('EPOSTA_HESAP_SINIRI', '2')
    monkeypatch.setattr(account_service, 'request_password_reset', lambda email: {'success': True})
    _clear()
    def call(email, ip):
        return client.post('/api/v1/auth/forgot-password', json={'email': email}, headers={'CF-Connecting-IP': ip})
    assert call('kota-hesap@yerimebak.test', '203.0.113.42').status_code == 200
    assert call('KOTA-HESAP@yerimebak.test', '203.0.113.43').status_code == 200
    assert call('kota-hesap@yerimebak.test', '203.0.113.44').status_code == 429
    assert call('baska@yerimebak.test', '203.0.113.42').status_code == 200
    assert call('ucuncu@yerimebak.test', '203.0.113.42').status_code == 200
    assert call('dorduncu@yerimebak.test', '203.0.113.42').status_code == 429
    sql("UPDATE auth_mail_limits SET pencere_basi = NOW() - INTERVAL '61 minutes'")
    assert call('kota-hesap@yerimebak.test', '203.0.113.42').status_code == 200


def test_resend_dogrulama_kotasini_eposta_gondermeden_uygular(client, monkeypatch):
    from yerimebak_ai_v5.services import account_service
    monkeypatch.setenv('EPOSTA_HESAP_SINIRI', '1')
    monkeypatch.setenv('EPOSTA_IP_SINIRI', '5')
    registered = client.post('/api/v1/auth/register', json={
        'email': 'kota-resend@yerimebak.test', 'password': 'Deneme123!', 'terms_accepted': True})
    assert registered.status_code == 200, registered.text
    _clear()
    called = []
    monkeypatch.setattr(account_service, 'resend_verification', lambda user: called.append(user['id']) or {'success': True})
    headers = {'Authorization': f"Bearer {registered.json()['token']}"}
    assert client.post('/api/v1/auth/resend-verification', headers=headers).status_code == 200
    assert client.post('/api/v1/auth/resend-verification', headers=headers).status_code == 429
    assert len(called) == 1


def test_es_zamanli_kota_asimi_yok(client, monkeypatch):
    from yerimebak_ai_v5.services.eposta_korumasi import tuket
    monkeypatch.setenv('KAYIT_IP_SINIRI', '3')
    _clear()
    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(lambda _: tuket('register', 'ayni@yerimebak.test', '198.51.100.99'), range(8)))
    assert results.count(0) == 3
    assert all(0 <= result <= 3600 for result in results)


def test_eski_farkli_ip_kotalari_es_zamanli_temizlenirken_kilitlenmez(client, monkeypatch):
    from yerimebak_ai_v5.services.eposta_korumasi import tuket
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    _clear()
    for ip in ['198.51.100.80', '198.51.100.81']:
        assert tuket('register', '', ip) == 0
    sql("UPDATE auth_mail_limits SET pencere_basi = NOW() - INTERVAL '3 days'")
    barrier = Barrier(2)
    real_get = DatabaseConfig.get_connection
    real_return = DatabaseConfig.return_connection
    class CursorProxy:
        def __init__(self, cursor): self.cursor = cursor
        def __getattr__(self, name): return getattr(self.cursor, name)
        def execute(self, query, params=None):
            if 'DELETE FROM auth_mail_limits' in query:
                barrier.wait(timeout=10)
            return self.cursor.execute(query, params)
    class ConnectionProxy:
        def __init__(self, connection): self.connection = connection
        def cursor(self): return CursorProxy(self.connection.cursor())
        def __getattr__(self, name): return getattr(self.connection, name)
    monkeypatch.setattr(DatabaseConfig, 'get_connection', lambda: ConnectionProxy(real_get()))
    monkeypatch.setattr(DatabaseConfig, 'return_connection', lambda conn: real_return(conn.connection))
    with ThreadPoolExecutor(max_workers=2) as pool:
        assert list(pool.map(lambda ip: tuket('register', '', ip), ['198.51.100.80', '198.51.100.81'])) == [0, 0]
