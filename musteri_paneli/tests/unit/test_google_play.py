import hashlib
import hmac

import pytest


def test_account_binding_and_simulation_guard(monkeypatch, caplog):
    from yerimebak_ai_v5.services import google_play_service as gp
    from yerimebak_ai_v5.services.auth_service import SECRET_KEY
    assert gp.obfuscated_account_id(42) == hmac.new(SECRET_KEY.encode(), b'gp:42', hashlib.sha256).hexdigest()
    monkeypatch.setenv('GOOGLE_PLAY_SIMULATION', 'true')
    monkeypatch.delenv('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON', raising=False)
    assert gp.simulation_enabled()
    monkeypatch.setenv('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON', '{"configured":true}')
    assert not gp.simulation_enabled()
    gp.warn_simulation_config()
    assert 'simülasyon' in caplog.text


def test_google_http_paths_and_voided_pagination(monkeypatch):
    from yerimebak_ai_v5.services import google_play_service as gp
    monkeypatch.setenv('GOOGLE_PLAY_PACKAGE_NAME', 'com.yerimebak.app')
    client = gp.GooglePlayClient()
    monkeypatch.setattr(client, '_access_token', lambda: 'fake-access')
    calls = []

    def request(method, url, **kwargs):
        calls.append((method, url, kwargs))
        class Response:
            status_code = 200
            def json(self):
                if 'voidedpurchases' in url:
                    if kwargs.get('params', {}).get('token'):
                        return {'voidedPurchases': [{'purchaseToken': 'second'}]}
                    return {'voidedPurchases': [{'purchaseToken': 'first'}],
                            'tokenPagination': {'nextPageToken': 'page2'}}
                return {'purchaseState': 0}
        return Response()

    monkeypatch.setattr(gp.requests, 'request', request)
    assert client.get_purchase('paket1', 'token/with slash')['purchaseState'] == 0
    client.consume('paket1', 'token/with slash')
    assert list(client.list_voided()) == [{'purchaseToken': 'first'}, {'purchaseToken': 'second'}]
    assert calls[0][1].endswith('/purchases/products/paket1/tokens/token%2Fwith%20slash')
    assert calls[1][0] == 'POST' and calls[1][1].endswith(':consume')
    assert all(c[2]['headers']['Authorization'] == 'Bearer fake-access' for c in calls)


def test_google_errors_are_sanitized(monkeypatch):
    from yerimebak_ai_v5.services import google_play_service as gp
    client = gp.GooglePlayClient()
    monkeypatch.setattr(client, '_access_token', lambda: 'secret-access')
    class Response:
        status_code = 404
        text = 'purchase-token-secret'
    monkeypatch.setattr(gp.requests, 'request', lambda *a, **kw: Response())
    with pytest.raises(gp.GooglePlayError) as exc:
        client.get_purchase('paket1', 'purchase-token-secret')
    assert exc.value.status == 400 and 'secret' not in str(exc.value)


def test_oauth_credentials_are_cached_until_expiry(monkeypatch):
    from yerimebak_ai_v5.services import google_play_service as gp
    from google.oauth2 import service_account
    monkeypatch.setenv('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON', '{"client_email":"test@example.test"}')
    class Credentials:
        valid = False
        token = None
        refresh_count = 0
        def refresh(self, transport):
            self.refresh_count += 1
            self.valid = True
            self.token = 'access-' + str(self.refresh_count)
    credentials = Credentials()
    def create(info, scopes):
        assert info['token_uri'] == 'https://oauth2.googleapis.com/token'
        assert scopes == ['https://www.googleapis.com/auth/androidpublisher']
        return credentials
    monkeypatch.setattr(service_account.Credentials, 'from_service_account_info', create)
    client = gp.GooglePlayClient()
    assert client._access_token() == 'access-1'
    assert client._access_token() == 'access-1'
    credentials.valid = False
    assert client._access_token() == 'access-2'
