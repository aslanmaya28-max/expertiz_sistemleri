"""Belgeler ve host güven sınırı: DB/worker çalıştırmadan ASGI doğrulaması."""
import importlib

import pytest
from fastapi.testclient import TestClient


@pytest.mark.parametrize('flag, expected', [(None, 404), ('false', 404), ('true', 200)])
def test_api_belgeleri_yalniz_acikca_acilinca_gorunur(monkeypatch, flag, expected):
    from yerimebak_ai_v5 import main
    if flag is None:
        monkeypatch.delenv('ENABLE_API_DOCS', raising=False)
    else:
        monkeypatch.setenv('ENABLE_API_DOCS', flag)
    try:
        app = importlib.reload(main).app
        client = TestClient(app, base_url='http://localhost')
        for path in ['/docs', '/redoc', '/openapi.json']:
            assert client.get(path).status_code == expected
    finally:
        monkeypatch.delenv('ENABLE_API_DOCS', raising=False)
        importlib.reload(main)


def test_render_dogrudan_hostu_sahte_cf_basligiyla_da_reddedilir():
    from yerimebak_ai_v5.main import app
    response = TestClient(app, base_url='http://yerimebak-api.onrender.com').get(
        '/api/v1/auth/me', headers={'CF-Connecting-IP': '198.51.100.9'})
    assert response.status_code == 400


def test_render_ozel_domain_saglik_hostu_izinlidir():
    from yerimebak_ai_v5.main import app
    response = TestClient(app, base_url='https://api.yerimebak.com.tr').get('/health')
    assert response.status_code == 200
    assert response.json()['status'] == 'ok'


def test_kullanilmayan_ws_kanali_yayinlanmaz():
    from yerimebak_ai_v5.main import app
    assert not any(getattr(route, 'path', '') == '/ws' for route in app.routes)
