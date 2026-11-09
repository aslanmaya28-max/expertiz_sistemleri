import base64
import json
import uuid

import pytest
from starlette.websockets import WebSocketDisconnect

from .test_dispatch_flow import client, admin_token, customer_token, _auth, TEST_DB
from .test_credit_admin_flow import sql
from yerimebak_ai_v5.services.payment_service import PaymentService

pytestmark = pytest.mark.skipif(not TEST_DB, reason="TEST_DATABASE_URL tanımlı değil")


def assert_public(value):
    if isinstance(value, dict):
        assert not {"tier", "tier_limits", "api_key"}.intersection(value)
        for child in value.values():
            assert_public(child)
    elif isinstance(value, list):
        for child in value:
            assert_public(child)


def assert_public_token(token):
    segment = token.split(".")[1]
    assert_public(json.loads(base64.urlsafe_b64decode(segment + "=" * (-len(segment) % 4))))


def test_packages_and_removed_purchase_keys(client, customer_token):
    response = client.get("/api/v1/payments/packages")
    assert response.status_code == 200
    assert response.json()["packages"] == {
        "paket1": {"credits": 1, "price": 100, "name": "1 Kredi", "popular": False},
        "paket5": {"credits": 5, "price": 400, "name": "5 Kredi", "popular": True},
        "paket10": {"credits": 10, "price": 750, "name": "10 Kredi", "popular": False},
    }
    for key in ("paket3", "paket11"):
        result = client.post("/api/v1/payments/checkout/credits", headers=_auth(customer_token),
                             json={"package_key": key, "contract_accepted": True})
        assert result.status_code == 400, result.text


def test_legacy_api_key_cannot_authenticate(client, customer_token):
    uid = client.get("/api/v1/auth/me", headers=_auth(customer_token)).json()["user"]["id"]
    key = "yk-" + uuid.uuid4().hex
    sql("UPDATE users SET api_key=%s WHERE id=%s", (key, uid))
    for path in ("/api/v1/auth/me", "/api/v1/auth/profile", "/api/v1/credits/balance"):
        assert client.get(path, headers={"X-API-Key": key}).status_code == 401
    assert client.post("/api/v1/valuation/analyze", headers={"X-API-Key": key},
                       json={"brand": "Seat", "model": "Ibiza", "year": 2024, "km": 30000,
                             "listed_price": 960000}).status_code == 401
    for query in (f"api_key={key}", f"token={key}"):
        with pytest.raises(WebSocketDisconnect) as exc:
            with client.websocket_connect(f"ws://localhost/ws?{query}"):
                pass
        assert exc.value.code == 4001
    assert client.post("/api/v1/analyze", headers=_auth(customer_token), json={}).status_code in (404, 405)


def test_auth_and_customer_responses_do_not_expose_legacy_fields(client, admin_token, customer_token):
    for token in (admin_token, customer_token):
        assert_public_token(token)
        for path in ("/api/v1/auth/me", "/api/v1/auth/profile", "/api/v1/credits/balance"):
            response = client.get(path, headers=_auth(token))
            assert response.status_code == 200, response.text
            assert_public(response.json())
        refreshed = client.post("/api/v1/auth/refresh-token", headers=_auth(token))
        assert refreshed.status_code == 200, refreshed.text
        assert_public(refreshed.json())
        assert_public_token(refreshed.json()["token"])
    customers = client.get("/api/v1/expertiz/admin/customers", headers=_auth(admin_token))
    assert customers.status_code == 200
    assert_public(customers.json())


def test_registration_login_and_verification_without_credit_gift(client):
    from yerimebak_ai_v5.services import email_service
    from .test_dispatch_flow import _link_token

    email = "public-contract@test.com"
    outbox = email_service.capture_for_tests()
    try:
        response = client.post("/api/v1/auth/register", json={
            "email": email, "password": "Musteri123!", "terms_accepted": True})
        assert response.status_code == 200, response.text
        assert response.json()["user"]["credits"] == 0
        assert "ucretsiz" not in response.json()["message"].lower()
        for part in outbox[-1].walk():
            if part.get_content_type() in ("text/plain", "text/html"):
                assert "ücretsiz" not in part.get_content().lower()
        assert_public(response.json())
        assert_public_token(response.json()["token"])
        verification = client.post("/api/v1/auth/verify-email", json={
            "token": _link_token(outbox[-1], "/eposta-dogrula")})
        assert verification.status_code == 200, verification.text
        assert verification.json()["credits_granted"] == 0
        assert_public(verification.json())
        login = client.post("/api/v1/auth/login", json={"email": email, "password": "Musteri123!"})
        assert login.status_code == 200, login.text
        assert_public(login.json())
        assert_public_token(login.json()["token"])
        balance = client.get("/api/v1/credits/balance", headers=_auth(login.json()["token"]))
        assert balance.json()["credits"] == 0
        refused = client.post("/api/v1/valuation/analyze", headers=_auth(login.json()["token"]),
                              json={"brand": "Seat", "model": "Ibiza", "year": 2024,
                                    "km": 30000, "listed_price": 960000})
        assert refused.status_code == 402, refused.text
        assert refused.json()["detail"]["code"] == "insufficient_credits"
    finally:
        email_service.stop_capture()


def test_legacy_package_refund_uses_recorded_credit_amount(client, admin_token):
    service = PaymentService()
    uid = service.get_or_create_user("legacy-refund@test.com")["id"]
    sql("UPDATE users SET credits=7 WHERE id=%s", (uid,))
    oid = "LEGACY-" + uuid.uuid4().hex
    sql("""INSERT INTO payment_orders
           (id, user_id, user_email, package_key, package_name, credits, amount_tl, status, payment_method)
           VALUES (%s, %s, %s, 'paket3', '3 Analiz', 3, 100, 'approved', 'simulation')""",
        (oid, uid, "legacy-refund@test.com"))
    response = client.post(f"/api/v1/payments/admin/orders/{oid}/refund", headers=_auth(admin_token),
                           json={"reason": "Eski paket iadesi"})
    assert response.status_code == 200, response.text
    assert response.json()["credits_removed"] == 3
    assert response.json()["refunded_tl"] == 100
    assert service.get_credit_balance(uid)["credits"] == 4
    assert sql("SELECT status FROM payment_orders WHERE id=%s", (oid,), True)[0]["status"] == "refunded"


@pytest.mark.parametrize("campaign, balance, already_granted, expected_grant", [
    (0, 0, False, 0), (0, 7, False, 0), (0, 7, True, 0),
    (1, 0, False, 1), (1, 7, False, 1), (1, 7, True, 0),
])
def test_verification_preserves_existing_balance_and_campaign_is_once(
        client, monkeypatch, campaign, balance, already_granted, expected_grant):
    from yerimebak_ai_v5.services import account_service, email_service, payment_service
    from .test_dispatch_flow import _link_token

    monkeypatch.setattr(payment_service, "FREE_CREDITS_ON_REGISTER", campaign)
    email = f"campaign-{uuid.uuid4().hex}@test.com"
    outbox = email_service.capture_for_tests()
    try:
        registration = client.post("/api/v1/auth/register", json={
            "email": email, "password": "Musteri123!", "terms_accepted": True})
        assert registration.status_code == 200, registration.text
        user = registration.json()["user"]
        assert user["credits"] == 0
        content = " ".join(part.get_content() for part in outbox[-1].walk()
                           if part.get_content_type() in ("text/plain", "text/html"))
        assert ("ücretsiz" in content.lower()) is bool(campaign)
        assert ("ücretsiz" in registration.json()["message"].lower()) is bool(campaign)
        sql("UPDATE users SET credits=%s, welcome_credits_granted=%s WHERE id=%s",
            (balance, already_granted, user["id"]))
        vtoken = _link_token(outbox[-1], "/eposta-dogrula")
        verified = client.post("/api/v1/auth/verify-email", json={"token": vtoken})
        assert verified.status_code == 200, verified.text
        assert verified.json()["credits_granted"] == expected_grant
        expected_balance = balance + expected_grant
        service = PaymentService()
        assert service.get_credit_balance(user["id"])["credits"] == expected_balance
        assert client.post("/api/v1/auth/verify-email", json={"token": vtoken}).status_code == 400
        # Yeni token da tamamlanan doğrulama için tekrar kredi vermez.
        account_service.send_verification(user["id"], email)
        repeated = client.post("/api/v1/auth/verify-email", json={
            "token": _link_token(outbox[-1], "/eposta-dogrula")})
        assert repeated.json()["credits_granted"] == 0
        assert service.get_or_create_user(email)["credits"] == expected_balance
        logs = sql("SELECT credits_used FROM credit_usage_logs WHERE user_id=%s AND action='welcome_bonus'",
                   (user["id"],), True)
        assert [row["credits_used"] for row in logs] == ([1] if expected_grant else [])
    finally:
        email_service.stop_capture()


def test_direct_user_creation_without_campaign_preserves_existing_balance(client):
    service = PaymentService()
    email = f"existing-{uuid.uuid4().hex}@test.com"
    user = service.get_or_create_user(email)
    assert user["credits"] == 0
    sql("UPDATE users SET credits=7 WHERE id=%s", (user["id"],))
    assert service.get_or_create_user(email)["credits"] == 7
