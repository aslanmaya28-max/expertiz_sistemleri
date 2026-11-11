"""Yerel JWT sürümü, geçiş uyumu ve yenileme yarışı."""
import pytest
from yerimebak_ai_v5.services import auth_service as auth

class Cursor:
    def __init__(self, user): self.user = user
    def execute(self, query, params=None): pass
    def fetchone(self): return self.user

@pytest.fixture
def service(monkeypatch):
    user = dict(id=1, email='oturum@example.test', credits=0, role='user', is_active=1, token_version=2)
    cursor = Cursor(user)
    class Connection:
        def cursor(self): return cursor
    monkeypatch.setattr(auth.DatabaseConfig, 'get_connection', lambda: Connection())
    monkeypatch.setattr(auth.DatabaseConfig, 'return_connection', lambda conn: None)
    return auth.AuthService(), user

def test_yeni_jwt_db_surumu_tasir(service):
    _, user = service
    assert auth._verify_jwt(auth._create_user_jwt(user))['tv'] == 2

@pytest.mark.parametrize('version', [0, 1, None, '2', True, 2.0, -1])
def test_eski_ve_bozuk_surum_reddedilir(service, version):
    svc, _ = service
    assert svc.verify_token(auth._create_jwt(dict(sub=1, tv=version))) is None

def test_eski_tvsiz_token_yalniz_db_sifirken_gecerli(service):
    svc, user = service
    token = auth._create_jwt(dict(sub=1))
    assert svc.verify_token(token) is None
    user['token_version'] = 0
    assert svc.verify_token(token)['token_version'] == 0

def test_eslesen_surumu_kimlik_sonucunda_tasir(service):
    svc, user = service
    assert svc.verify_token(auth._create_user_jwt(user))['token_version'] == 2

def test_refresh_dogrulama_sonrasi_sifre_degismisse_token_uretmez(service):
    svc, user = service
    assert svc.refresh_token(1, expected_token_version=1) is None
    assert auth._verify_jwt(svc.refresh_token(1, expected_token_version=2))['tv'] == 2


def test_sifre_degistirme_yeni_token_verir_ve_surumu_artirir(service, monkeypatch):
    svc, user = service
    user['password'] = 'eski-hash'
    class ChangeCursor(Cursor):
        def execute(self, query, params=None):
            if query.lstrip().startswith('UPDATE users'):
                if 'token_version = token_version + 1' in query:
                    user['token_version'] += 1
    class Connection:
        def cursor(self): return ChangeCursor(user)
        def commit(self): pass
    monkeypatch.setattr(auth.DatabaseConfig, 'get_connection', lambda: Connection())
    monkeypatch.setattr(auth, '_verify_password', lambda *args: True)
    monkeypatch.setattr(auth, '_hash_password', lambda value: 'yeni-hash')
    result = svc.change_password(1, 'EskiSifre123!', 'YeniSifre456!')
    assert user['token_version'] == 3
    assert auth._verify_jwt(result['token'])['tv'] == 3


def test_hesap_sifirlama_surumu_artirir(monkeypatch):
    from yerimebak_ai_v5.services import account_service as account
    state = {'token_version': 2}
    class ResetCursor:
        def execute(self, query, params=None):
            if 'UPDATE users SET password' in query and 'token_version = token_version + 1' in query:
                state['token_version'] += 1
    class Connection:
        def cursor(self): return ResetCursor()
        def commit(self): pass
    monkeypatch.setattr(account, 'ensure_schema', lambda: None)
    monkeypatch.setattr(account, '_consume_token', lambda *args: 1)
    monkeypatch.setattr(auth, '_hash_password', lambda value: 'hash')
    monkeypatch.setattr(auth.DatabaseConfig, 'get_connection', lambda: Connection())
    monkeypatch.setattr(auth.DatabaseConfig, 'return_connection', lambda conn: None)
    assert account.reset_password('reset', 'YeniSifre456!')['success']
    assert state['token_version'] == 3


def test_personel_sifirlama_surumu_artirir(monkeypatch):
    from yerimebak_ai_v5.services import personnel_service as personnel
    state = {'token_version': 2}
    class ResetCursor:
        def execute(self, query, params=None):
            if 'UPDATE users SET password' in query and 'token_version = token_version + 1' in query:
                state['token_version'] += 1
    class Connection:
        def cursor(self): return ResetCursor()
        def commit(self): pass
    monkeypatch.setattr(personnel, '_ensure_schema', lambda: None)
    monkeypatch.setattr(personnel, '_get_personnel', lambda *args: dict(id=1, email='p@test.test'))
    monkeypatch.setattr(personnel, '_write_audit', lambda *args: None)
    monkeypatch.setattr(personnel, '_hash_password', lambda value: 'hash')
    monkeypatch.setattr(auth.DatabaseConfig, 'get_connection', lambda: Connection())
    monkeypatch.setattr(auth.DatabaseConfig, 'return_connection', lambda conn: None)
    assert personnel.reset_personnel_password('1', 'YeniSifre456!', {})['success']
    assert state['token_version'] == 3
