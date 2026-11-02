"""Sentetik müşteri yolculuğu: gerçek HTTP/DB, taklit model taşıması.

Emsal yokken 422/kredi koruması mevcut
test_valuation_reports.test_insufficient_data_or_credits_leave_no_report_and_retry_can_succeed
ile sınanır; burada aynı senaryo tekrarlanmaz.
"""
import json
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from unittest.mock import Mock

import pytest

from .test_dispatch_flow import client, TEST_DB, _auth, _link_token
from .test_credit_admin_flow import sql
from yerimebak_ai_v5.services import email_service, payment_service
from yerimebak_ai_v5.services import vehicle_risk, valuation_reports, web_market_reference

pytestmark = pytest.mark.skipif(not TEST_DB, reason="TEST_DATABASE_URL tanımlı değil")


@pytest.fixture
def paid_customer(client, monkeypatch):
    monkeypatch.setattr(payment_service, "FREE_CREDITS_ON_REGISTER", 0)
    email = f"sentetik-yolculuk-{uuid.uuid4().hex}@example.test"
    outbox = email_service.capture_for_tests()
    try:
        registered = client.post("/api/v1/auth/register", json={
            "email": email, "password": "Sentetik123!", "terms_accepted": True})
        assert registered.status_code == 200, registered.text
        assert registered.json()["user"]["credits"] == 0
        verified = client.post("/api/v1/auth/verify-email", json={
            "token": _link_token(outbox[-1], "/eposta-dogrula")})
        assert verified.status_code == 200, verified.text
        assert verified.json()["credits_granted"] == 0
    finally:
        email_service.stop_capture()
    headers = _auth(registered.json()["token"])
    checkout = client.post("/api/v1/payments/checkout/credits", headers=headers,
                           json={"package_key": "paket1", "contract_accepted": True})
    assert checkout.status_code == 200, checkout.text
    order_id = checkout.json()["order_id"]
    paid = client.post(f"/api/v1/payments/checkout/{order_id}/simulate",
                       headers=headers, json={"success": True})
    assert paid.status_code == 200, paid.text
    assert client.get("/api/v1/credits/balance", headers=headers).json()["credits"] == 1
    return registered.json()["user"]["id"], headers


@pytest.mark.parametrize("concurrent", [False, True], ids=["sonradan-tekrar", "ilk-istek-surerken-tekrar"])
def test_kayittan_pdfye_kesik_risk_yaniti_ve_tek_kredi(
        client, paid_customer, monkeypatch, concurrent, caplog):
    uid, headers = paid_customer
    monkeypatch.setenv("OPENROUTER_API_KEY", "sentetik-test-anahtari")
    monkeypatch.setenv("WEB_RISK_CACHE_DAYS", "0")
    model_calls = []
    overlap = threading.Barrier(2)
    guard_calls = 0
    guard_lock = threading.Lock()
    original_guard = valuation_reports.request_guard

    @contextmanager
    def observed_guard(user_id, request_id):
        nonlocal guard_calls
        with guard_lock:
            guard_calls += 1
            number = guard_calls
        # İkinci istek gerçek kilide girmek üzereyken ilk model yanıtı bekler.
        if concurrent and number == 2:
            overlap.wait(timeout=15)
        with original_guard(user_id, request_id) as cached:
            yield cached

    monkeypatch.setattr(valuation_reports, "request_guard", observed_guard)
    risk_url = "https://www.whatcar.com/sentetik-seat-ibiza-triger"
    risk = {"baslik": "Triger seti", "aciklama": "Sentetik bakım kontrolü",
            "etkiledigi": "Seat Ibiza 1.0 TSI", "kaynaklar": [risk_url]}
    # Son madde çıktı sınırında kesilir; tamamlanan ilk madde korunmalıdır.
    truncated = '{"riskler":[' + json.dumps(risk, ensure_ascii=False) + ', {"baslik":"yarım'

    class FakeModelClient:
        def __init__(self, *args, **kwargs):
            pass

        def __enter__(self):
            return self

        def __exit__(self, *args):
            self.close()

        def close(self):
            pass

        def post(self, url, **kwargs):
            assert url == web_market_reference._URL
            model_calls.append(kwargs["json"])
            if concurrent:
                overlap.wait(timeout=15)
            return Mock(raise_for_status=Mock(), json=Mock(return_value={
                "choices": [{"message": {"content": truncated, "annotations": [{
                    "url_citation": {"url": risk_url,
                        "content": "Seat Ibiza 1.0 TSI triger seti bakım kontrolü."}}]}}],
                "usage": {"cost": 0.001}}))

    # _search ve get_model_risks gerçektir; yalnız HTTP taşıması taklit edilir.
    monkeypatch.setattr(vehicle_risk.httpx, "Client", FakeModelClient)
    prefill_search = Mock(return_value={"data": {
        "brand": "Seat", "model": "Ibiza", "package": "1.0 TSI", "year": 2024,
        "km": 30000, "price": 960000, "fuel": "Benzin", "transmission": "Manuel"}, "cost": 0})
    monkeypatch.setattr(web_market_reference, "_search", prefill_search)
    prefill = client.post("/api/v1/valuation/prefill-text", headers=headers, json={"text":
        "Sentetik test ilanı: Seat Ibiza 1.0 TSI 2024, 30.000 km, 960.000 TL, Benzin, Manuel."})
    assert prefill.status_code == 200, prefill.text
    vehicle = prefill.json()["vehicle"]
    assert vehicle["brand"] == "Seat" and vehicle["price"] == 960000
    prefill_search.assert_called_once()
    assert prefill_search.call_args.kwargs["web"] is False
    assert client.get("/api/v1/credits/balance", headers=headers).json()["credits"] == 1
    reference = Mock(return_value={"found": True, "count": 8, "clean_count": 8,
        "source": "web_listings", "market_avg_price": 950000, "market_median_price": 950000,
        "market_min_price": 900000, "market_max_price": 1000000, "samples": []})
    monkeypatch.setattr(web_market_reference, "get_reference", reference)
    payload = {**{k: v for k, v in vehicle.items() if k != "price"},
               "listed_price": vehicle["price"], "request_id": str(uuid.uuid4())}

    def submit():
        return client.post("/api/v1/valuation/analyze", headers=headers, json=payload)

    if concurrent:
        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(submit)
            second = pool.submit(submit)
            responses = [first.result(timeout=30), second.result(timeout=30)]
    else:
        responses = [submit(), submit()]
    assert [r.status_code for r in responses] == [200, 200], [r.text for r in responses]
    bodies = [r.json() for r in responses]
    report = next(body for body in bodies if not body.get("tekrar"))
    replay = next(body for body in bodies if body.get("tekrar"))
    assert replay == {**report, "tekrar": True}
    assert report["kredi"] == {"dusulen": 1, "kalan": 0}
    assert report["modelRiskleri"]["riskler"][0]["baslik"] == "Triger seti"
    assert report["modelRiskleri"]["riskler"][0]["kaynaklar"] == [risk_url]
    assert len(report["modelRiskleri"]["riskler"]) == 1
    assert any("kurtar" in rec.message.lower() for rec in caplog.records)
    assert len(model_calls) == 1 and reference.call_count == 1
    report_id = report["rapor"]["id"]
    listing = client.get("/api/v1/valuation/reports", headers=headers)
    assert listing.status_code == 200, listing.text
    assert listing.json()["total"] == 1
    assert listing.json()["reports"][0]["id"] == report_id
    pdf = client.get(f"/api/v1/valuation/reports/{report_id}/pdf", headers=headers)
    assert pdf.status_code == 200, pdf.text
    assert pdf.headers["content-type"] == "application/pdf" and pdf.content.startswith(b"%PDF")
    assert client.get("/api/v1/credits/balance", headers=headers).json()["credits"] == 0
    histories = sql("SELECT id, request_id FROM analysis_history WHERE user_id=%s", (uid,), True)
    assert [(row["id"], row["request_id"]) for row in histories] == [(report_id, payload["request_id"])]
    movements = sql("SELECT credits_used FROM credit_usage_logs WHERE user_id=%s AND action='analysis'",
                    (uid,), True)
    assert [row["credits_used"] for row in movements] == [1]
