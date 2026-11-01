import time
import uuid
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import MagicMock

import httpx
import pytest

from yerimebak_ai_v5.services import media_service as media


MEDIA_ID = "11111111-1111-1111-1111-111111111111"
CONTENT = b"%PDF-1.7\nrapor"


@pytest.fixture(autouse=True)
def settings(monkeypatch, tmp_path):
    monkeypatch.setenv("MEDIA_ROOT", str(tmp_path / "media"))
    monkeypatch.setenv("MEDIA_SIGNING_KEY", "test-signing-key")
    monkeypatch.delenv("MEDIA_STORAGE", raising=False)
    monkeypatch.setenv("SUPABASE_URL", "https://storage.example.test/")
    monkeypatch.setenv("SUPABASE_SERVICE_ROLE_KEY", "test-service-key")
    monkeypatch.setenv("SUPABASE_MEDIA_BUCKET", "report-media")
    monkeypatch.setattr(media, "uuid", SimpleNamespace(UUID=uuid.UUID, uuid4=lambda: MEDIA_ID))


def cursor_for_row():
    cursor = MagicMock()
    cursor.fetchone.return_value = {
        "id": MEDIA_ID, "report_id": "report-1", "file_name": f"{MEDIA_ID}.pdf",
        "content_type": "application/pdf", "original_name": "rapor.pdf",
    }
    return cursor


def upload(cursor):
    return media.store_media(cursor, "report-1", {"id": "personel"}, CONTENT,
                             "rapor.pdf", "corporate_report")


def open_file(monkeypatch, cursor, signature=None):
    conn = MagicMock()
    conn.cursor.return_value = cursor
    monkeypatch.setattr(media.DatabaseConfig, "get_connection", lambda: conn)
    monkeypatch.setattr(media.DatabaseConfig, "return_connection", MagicMock())
    expiry = int(time.time()) + 3600
    return media.open_media(MEDIA_ID, expiry, signature or media.sign(MEDIA_ID, expiry))


def mock_storage(monkeypatch, handler):
    client_class = httpx.Client
    monkeypatch.setattr(media.httpx, "Client", lambda **kwargs: client_class(
        transport=httpx.MockTransport(handler), **kwargs))
    monkeypatch.setenv("MEDIA_STORAGE", "supabase")


def test_supabase_upload_request(monkeypatch):
    requests = []

    def handler(request):
        requests.append(request)
        return httpx.Response(200, json={"Key": "ok"})

    mock_storage(monkeypatch, handler)
    cursor = cursor_for_row()
    result = upload(cursor)
    assert result["success"]
    assert result["media"]["url"].startswith(f"/api/v1/expertiz/media/{MEDIA_ID}?exp=")
    request, = requests
    assert request.method == "POST"
    assert str(request.url) == f"https://storage.example.test/storage/v1/object/report-media/report-1/{MEDIA_ID}.pdf"
    assert request.headers["Authorization"] == "Bearer test-service-key"
    assert request.headers["apikey"] == "test-service-key"
    assert request.headers["Content-Type"] == "application/pdf"
    assert request.headers["x-upsert"] == "false"
    assert request.content == CONTENT
    assert request.extensions["timeout"]["read"] == 30
    cursor.execute.assert_called_once()
    assert not media.media_root().exists()


def test_supabase_read_and_signature(monkeypatch):
    requests = []

    def handler(request):
        requests.append(request)
        return httpx.Response(200, content=CONTENT)

    mock_storage(monkeypatch, handler)
    cursor = cursor_for_row()
    assert open_file(monkeypatch, cursor, "invalid")["http_status"] == 403
    assert not requests
    result = open_file(monkeypatch, cursor)
    assert result == {"content": CONTENT, "content_type": "application/pdf", "original_name": "rapor.pdf"}
    request, = requests
    assert request.method == "GET"
    assert request.url.path == f"/storage/v1/object/report-media/report-1/{MEDIA_ID}.pdf"
    assert request.headers["Authorization"] == "Bearer test-service-key"
    assert request.headers["apikey"] == "test-service-key"


@pytest.mark.parametrize("failure", ["status", "timeout"])
def test_supabase_error_does_not_insert(monkeypatch, caplog, failure):
    def handler(request):
        if failure == "timeout":
            raise httpx.ReadTimeout("test-service-key", request=request)
        return httpx.Response(403, text="test-service-key")

    mock_storage(monkeypatch, handler)
    cursor = cursor_for_row()
    result = upload(cursor)
    assert result["http_status"] == 502
    assert "yüklenemedi" in result["error"]
    cursor.execute.assert_not_called()
    assert open_file(monkeypatch, cursor)["http_status"] == 502
    assert caplog.records
    assert "test-service-key" not in caplog.text


def test_supabase_missing_configuration(monkeypatch):
    monkeypatch.setenv("MEDIA_STORAGE", "supabase")
    monkeypatch.delenv("SUPABASE_SERVICE_ROLE_KEY")
    cursor = cursor_for_row()
    assert upload(cursor)["http_status"] == 502
    cursor.execute.assert_not_called()


def test_unknown_mode_does_not_write_locally(monkeypatch):
    monkeypatch.setenv("MEDIA_STORAGE", "supabsae")
    cursor = cursor_for_row()
    assert upload(cursor)["http_status"] == 502
    cursor.execute.assert_not_called()
    assert not media.media_root().exists()


@pytest.mark.parametrize("mode", [None, "local"])
def test_local_atomic_write_and_read(monkeypatch, mode):
    if mode:
        monkeypatch.setenv("MEDIA_STORAGE", mode)
    cursor = cursor_for_row()
    assert upload(cursor)["success"]
    path = media.media_root() / "report-1" / f"{MEDIA_ID}.pdf"
    assert path.read_bytes() == CONTENT
    assert list(path.parent.iterdir()) == [path]
    result = open_file(monkeypatch, cursor)
    assert Path(result["path"]) == path
    assert "content" not in result
    path.unlink()
    assert open_file(monkeypatch, cursor)["http_status"] == 404


@pytest.mark.parametrize("backend", ["local", "supabase"])
@pytest.mark.parametrize("filename", ["rapor.pdf", "kurumsal rapor–İstanbul.pdf"])
def test_endpoint_returns_file_and_private_inline_headers(monkeypatch, tmp_path, backend, filename):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from urllib.parse import quote
    from yerimebak_ai_v5.api.v1.endpoints import expertiz

    result = {"content_type": "application/pdf", "original_name": filename}
    if backend == "local":
        path = tmp_path / "rapor.pdf"
        path.write_bytes(CONTENT)
        result["path"] = str(path)
    else:
        result["content"] = CONTENT
    opener = MagicMock(return_value=result)
    monkeypatch.setattr(media, "open_media", opener)
    app = FastAPI()
    app.include_router(expertiz.router, prefix="/api/v1/expertiz")
    with TestClient(app) as client:
        response = client.get(f"/api/v1/expertiz/media/{MEDIA_ID}?exp=123&sig=test")
    assert response.status_code == 200
    assert response.content == CONTENT
    assert response.headers["content-type"] == "application/pdf"
    assert response.headers["cache-control"] == "private, max-age=3600"
    disposition = (f"inline; filename*=utf-8''{quote(filename)}" if quote(filename) != filename
                   else f'inline; filename="{filename}"')
    assert response.headers["content-disposition"] == disposition
    opener.assert_called_once_with(MEDIA_ID, 123, "test")


def test_endpoint_propagates_storage_failure(monkeypatch):
    import asyncio
    from fastapi import HTTPException
    from yerimebak_ai_v5.api.v1.endpoints import expertiz

    monkeypatch.setattr(media, "open_media", lambda *_: {"error": "Dosya okunamadı", "http_status": 502})
    with pytest.raises(HTTPException) as exc:
        asyncio.run(expertiz.get_media_file(MEDIA_ID, 123, "test"))
    assert exc.value.status_code == 502
