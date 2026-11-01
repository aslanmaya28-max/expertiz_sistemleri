"""Gerçek PostgreSQL ile kalıcı önbellek ve kullanıcı kotası; dış ağ yok."""
import uuid
from concurrent.futures import ThreadPoolExecutor

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from .test_dispatch_flow import client, TEST_DB
from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.services import listing_extract as extract, web_market_reference as web
from yerimebak_ai_v5.services import valuation_service as valuation
from yerimebak_ai_v5.api.v1.endpoints import valuation as endpoint

pytestmark = pytest.mark.skipif(not TEST_DB, reason="TEST_DATABASE_URL tanımlı değil")


def test_persistent_cache_and_shared_endpoint_quota(client, monkeypatch):
    uid = str(uuid.uuid4())
    url = "https://www.arabam.com/ilan/renault-clio/" + uid
    calls = []
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-fake")
    monkeypatch.setattr(valuation, "_listing_by_url", lambda u: None)
    monkeypatch.setattr(valuation, "_known_brands", lambda: [])
    def search(query, http_client, **kwargs):
        calls.append(kwargs["web"])
        return {"data": {"brand": "Renault", "price": 950000},
                "sources": {url: "Renault 950.000 TL"}, "cost": .009}
    monkeypatch.setattr(web, "_search", search)
    app = FastAPI()
    app.include_router(endpoint.router, prefix="/valuation")
    app.dependency_overrides[endpoint.get_current_user] = lambda: {"id": uid}
    with TestClient(app) as api:
        for i in range(20):
            result = api.get("/valuation/prefill", params={"url": url + "?utm=" + str(i)})
            assert result.status_code == 200
            assert result.json()["vehicle"]["price"] == 950000
        assert calls == [True]
        assert api.post("/valuation/prefill-text", json={"text": "Renault 950.000 TL"}).status_code == 429
        assert api.get("/valuation/prefill", params={"url": url}).status_code == 429
        assert calls == [True]
    key = "listing_extract:v1:" + extract.hashlib.sha256(extract.canonical_url(url).encode()).hexdigest()
    assert web._cache_read(key, 24)["scope"]["cached"] is True
    conn = DatabaseConfig.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("UPDATE web_reference_cache SET created_at=NOW()-INTERVAL '25 hours' WHERE cache_key=%s", (key,))
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    assert web._cache_read(key, 24) is None


def test_daily_quota_atomic_and_next_day(client):
    uid = str(uuid.uuid4())
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda _: extract.consume_daily(uid), range(25)))
    assert sum(results) == 20
    assert extract.consume_daily(uid + "-another")
    conn = DatabaseConfig.get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("UPDATE listing_extract_usage SET day=day-1 WHERE user_id=%s", (uid,))
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    assert extract.consume_daily(uid)
