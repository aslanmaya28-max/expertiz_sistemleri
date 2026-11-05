import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from yerimebak_ai_v5.api.v1.endpoints import valuation
from yerimebak_ai_v5.services import inspection_photo


@pytest.fixture
def client(monkeypatch):
    app = FastAPI()
    app.include_router(valuation.router, prefix='/valuation')
    app.dependency_overrides[valuation.get_current_user] = lambda: {'id': 'photo-user'}
    monkeypatch.setattr(valuation.listing_extract, 'consume_daily', lambda user: True)
    return TestClient(app)


def test_multipart_reads_in_memory_and_uses_shared_quota(client, monkeypatch):
    seen = []
    monkeypatch.setattr(valuation.listing_extract, 'consume_daily', lambda user: seen.append(user) or True)
    monkeypatch.setattr(inspection_photo, 'read', lambda files: {'success': True, 'size': len(files[0])})
    # Büyük veri: Starlette UploadFile bu boyutta diske taşardı.
    monkeypatch.setattr('tempfile.SpooledTemporaryFile', lambda *a, **k: pytest.fail('spool yok'))
    result = client.post('/valuation/inspection-photo', files={'files': ('rapor.jpg', b'x' * 1_100_000, 'image/jpeg')})
    assert result.status_code == 200 and result.json()['size'] == 1_100_000
    assert seen == ['photo-user']


def test_quota_rejects_before_model(client, monkeypatch):
    monkeypatch.setattr(valuation.listing_extract, 'consume_daily', lambda user: False)
    monkeypatch.setattr(inspection_photo, 'read', lambda _: pytest.fail('model çağrılmamalı'))
    assert client.post('/valuation/inspection-photo', files={'files': ('a.png', b'a')}).status_code == 429


@pytest.mark.parametrize('count', [0, 5])
def test_file_count(client, count):
    files = [('files', ('a.png', b'a', 'image/png'))] * count
    response = client.post('/valuation/inspection-photo', files=files or None)
    assert response.status_code in (415, 422)


def test_file_limit_and_wrong_format(client):
    assert client.post('/valuation/inspection-photo', files={'files': ('a.jpg', b'x' * (8 * 1024 * 1024 + 1))}).status_code == 413
    assert client.post('/valuation/inspection-photo', files={'files': ('a.jpg', b'not an image')}).status_code == 422


def test_truncated_upload(client):
    response = client.post('/valuation/inspection-photo', content=b'--yb\r\nContent-Disposition: form-data; name="files"; filename="a.jpg"\r\n\r\nx',
                           headers={'Content-Type': 'multipart/form-data; boundary=yb'})
    assert response.status_code == 422


def test_auth_required():
    app = FastAPI()
    app.include_router(valuation.router, prefix='/valuation')
    assert TestClient(app).post('/valuation/inspection-photo').status_code == 401
