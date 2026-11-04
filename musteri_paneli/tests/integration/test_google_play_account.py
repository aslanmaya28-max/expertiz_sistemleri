"""019: gerçek HTTP/PostgreSQL, yalnız Google taşıması sahte."""
import threading
import uuid
import json
from concurrent.futures import ThreadPoolExecutor

import pytest

from .test_dispatch_flow import client, TEST_DB, _auth, admin_token
from .test_credit_admin_flow import sql

pytestmark = pytest.mark.skipif(not TEST_DB, reason="TEST_DATABASE_URL tanımlı değil")


@pytest.fixture
def customer(client):
    from yerimebak_ai_v5.services import email_service
    email_service.capture_for_tests()
    try:
        email = f"gp-{uuid.uuid4().hex}@example.test"
        response = client.post('/api/v1/auth/register', json={
            'email': email, 'password': 'Musteri123!', 'full_name': 'Örnek Müşteri',
            'terms_accepted': True})
        assert response.status_code == 200, response.text
        body = response.json()
        return body['user']['id'], _auth(body['token']), email
    finally:
        email_service.stop_capture()


@pytest.fixture
def google(monkeypatch):
    from yerimebak_ai_v5.services import google_play_service as gp

    class Google:
        state = 0
        account = None
        consume_fails = False
        consumption_state = 0
        consumed = []
        voided = []
        barrier = None

        def get_purchase(self, product, token):
            if self.barrier:
                self.barrier.wait(timeout=15)
            return {'purchaseState': self.state, 'consumptionState': self.consumption_state,
                    'orderId': 'GPA.' + token, 'productId': product,
                    'obfuscatedExternalAccountId': self.account}

        def consume(self, product, token):
            if self.consume_fails:
                raise gp.GooglePlayError('Google geçici hata', 502)
            self.consumed.append((product, token))

        def list_voided(self):
            return iter(self.voided)

    fake = Google()
    monkeypatch.setattr(gp, 'get_client', lambda: fake)
    return fake


def verify(client, headers, token, product='paket5'):
    return client.post('/api/v1/payments/google-play/verify', headers=headers,
                       json={'product_id': product, 'purchase_token': token})


def test_products_and_defaults(client, customer, monkeypatch):
    for key in ('APP_EXPERTIZ_ENABLED', 'APP_MIN_VERSION', 'APP_LATEST_VERSION'):
        monkeypatch.delenv(key, raising=False)
    config = client.get('/api/v1/app/config')
    assert config.status_code == 200
    assert config.json()['expertiz_enabled'] is False
    assert config.json()['min_supported_version'] == '1.0.0'
    assert config.json()['analysis_cost'] == 1
    monkeypatch.setenv('APP_EXPERTIZ_ENABLED', 'true')
    assert client.get('/api/v1/app/config').json()['expertiz_enabled'] is True
    assert client.get('/api/v1/payments/google-play/products').status_code == 401
    products = client.get('/api/v1/payments/google-play/products', headers=customer[1]).json()
    assert [(p['product_id'], p['credits']) for p in products['products']] == [
        ('paket1', 1), ('paket5', 5), ('paket10', 10)]
    assert len(products['obfuscated_account_id']) == 64


@pytest.mark.parametrize('concurrent', [False, True])
def test_credit_exactly_once(client, customer, google, concurrent):
    from yerimebak_ai_v5.services import google_play_service as gp
    uid, headers, _ = customer
    google.account = gp.obfuscated_account_id(uid)
    token = uuid.uuid4().hex
    if concurrent:
        google.barrier = threading.Barrier(2)
        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(verify, client, headers, token) for _ in range(2)]
            responses = [f.result(timeout=30) for f in futures]
    else:
        responses = [verify(client, headers, token), verify(client, headers, token)]
    assert [r.status_code for r in responses] == [200, 200], [r.text for r in responses]
    assert sorted(r.json()['status'] for r in responses) == ['already_granted', 'granted']
    assert sql('SELECT credits FROM users WHERE id=%s', (uid,), True)[0]['credits'] == 5
    orders = sql("SELECT * FROM payment_orders WHERE user_id=%s", (uid,), True)
    assert len(orders) == 1 and orders[0]['payment_method'] == 'google_play'
    assert orders[0]['payment_ref'] == 'GPA.' + token and orders[0]['status'] == 'approved'
    logs = sql("SELECT * FROM credit_usage_logs WHERE user_id=%s AND action='credit_purchase'", (uid,), True)
    assert len(logs) == 1 and logs[0]['credits_used'] == 5
    assert google.consumed
    assert sql('SELECT status FROM google_play_purchases WHERE purchase_token=%s', (token,), True)[0]['status'] == 'consumed'


@pytest.mark.parametrize('state,expected', [(2, 200), (1, 400), (9, 400)])
def test_pending_cancelled_unknown_state(client, customer, google, state, expected):
    from yerimebak_ai_v5.services import google_play_service as gp
    google.account = gp.obfuscated_account_id(customer[0])
    google.state = state
    res = verify(client, customer[1], uuid.uuid4().hex)
    assert res.status_code == expected, res.text
    if state == 2:
        assert res.json() == {'status': 'pending'}
    assert sql('SELECT credits FROM users WHERE id=%s', (customer[0],), True)[0]['credits'] == 0
    assert not google.consumed


def test_ownership_unknown_product_and_token_rebinding(client, customer, google):
    from yerimebak_ai_v5.services import google_play_service as gp
    token = uuid.uuid4().hex
    google.account = 'someone-else'
    assert verify(client, customer[1], token).status_code == 403
    assert verify(client, customer[1], token, 'unknown').status_code == 400
    google.account = gp.obfuscated_account_id(customer[0])
    assert verify(client, customer[1], token).status_code == 200
    assert verify(client, customer[1], token, 'paket10').status_code == 400
    other = client.post('/api/v1/auth/register', json={
        'email': uuid.uuid4().hex + '@example.test', 'password': 'Musteri123!', 'terms_accepted': True}).json()
    google.account = gp.obfuscated_account_id(other['user']['id'])
    assert verify(client, _auth(other['token']), token).status_code == 403


def test_consume_failure_retry_and_voided_once(client, customer, google, admin_token, monkeypatch):
    from yerimebak_ai_v5.services import google_play_service as gp, refund_service
    uid, headers, _ = customer
    google.account = gp.obfuscated_account_id(uid)
    google.consume_fails = True
    token = uuid.uuid4().hex
    assert verify(client, headers, token).json()['status'] == 'granted'
    assert sql('SELECT status FROM google_play_purchases WHERE purchase_token=%s', (token,), True)[0]['status'] == 'granted_not_consumed'
    google.consume_fails = False
    assert verify(client, headers, token).json()['status'] == 'already_granted'
    oid = sql('SELECT id FROM payment_orders WHERE user_id=%s', (uid,), True)[0]['id']
    monkeypatch.setattr(refund_service, '_do_refund', lambda *a: pytest.fail('Google siparişi PayTR’ye gönderildi'))
    response = client.post(f'/api/v1/payments/admin/orders/{oid}/refund', headers=_auth(admin_token), json={'reason': 'Test'})
    assert response.status_code == 400 and 'Play Console' in response.json()['detail']
    sql('UPDATE users SET credits=2 WHERE id=%s', (uid,))
    google.voided = [{'purchaseToken': token, 'orderId': 'GPA.' + token}]
    url = '/api/v1/payments/admin/google-play/sync-voided'
    assert client.post(url, headers=headers).status_code == 403
    assert client.post(url, headers=_auth(admin_token)).json()['voided_count'] == 1
    assert client.post(url, headers=_auth(admin_token)).json()['voided_count'] == 0
    assert sql('SELECT credits FROM users WHERE id=%s', (uid,), True)[0]['credits'] == 0
    assert verify(client, headers, token).status_code == 400
    logs = sql("SELECT * FROM credit_usage_logs WHERE user_id=%s AND action='google_play_voided'", (uid,), True)
    assert len(logs) == 1 and logs[0]['credits_used'] == -2


def test_delete_account_anonymizes_and_invalidates_sessions(client, customer, google):
    from yerimebak_ai_v5.services import google_play_service as gp
    uid, headers, email = customer
    google.account = gp.obfuscated_account_id(uid)
    assert verify(client, headers, uuid.uuid4().hex).status_code == 200
    assert client.put('/api/v1/auth/profile', headers=headers, json={
        'phone': '05550001919', 'company_name': 'Kişisel şirket', 'invoice_address': 'Özel adres'}).status_code == 200
    assert client.post('/api/v1/auth/delete-account', headers=headers, json={'password': 'wrong'}).status_code == 403
    response = client.post('/api/v1/auth/delete-account', headers=headers, json={'password': 'Musteri123!'})
    assert response.status_code == 200, response.text
    user = sql('SELECT * FROM users WHERE id=%s', (uid,), True)[0]
    assert user['email'] == f'silindi-{uid}@silindi.invalid'
    assert not user['full_name'] and not user['phone'] and not user['invoice_address'] and not user['company_name']
    assert user['is_active'] == 0 and user['deleted_at'] and user['credits'] == 0
    assert client.get('/api/v1/auth/me', headers=headers).status_code == 401
    assert client.post('/api/v1/auth/refresh-token', headers=headers).status_code == 401
    assert client.post('/api/v1/auth/login', json={'email': email, 'password': 'Musteri123!'}).status_code == 401
    order = sql('SELECT * FROM payment_orders WHERE user_id=%s', (uid,), True)[0]
    assert order['user_email'] == user['email'] and not order['user_phone']
    assert sql('SELECT * FROM account_tokens WHERE user_id=%s AND used_at IS NULL', (uid,), True) == []
    registered = client.post('/api/v1/auth/register', json={
        'email': email, 'phone': '05550001919', 'password': 'YeniMusteri123!', 'terms_accepted': True})
    assert registered.status_code == 200, registered.text


def test_admin_cannot_delete(client, admin_token):
    assert client.post('/api/v1/auth/delete-account', headers=_auth(admin_token), json={'password': 'any'}).status_code == 403


def test_staff_cannot_delete(client, customer):
    sql("UPDATE users SET role='personel' WHERE id=%s", (customer[0],))
    assert client.post('/api/v1/auth/delete-account', headers=customer[1], json={'password': 'Musteri123!'}).status_code == 403


def test_delete_cleans_report_and_profile_copies(client, customer):
    from yerimebak_ai_v5.services.expertiz_service import _expertiz_profile_id
    uid, headers, email = customer
    profile = _expertiz_profile_id({'id': uid})
    rid = str(uuid.uuid4())
    data = json.dumps({'customer_email': email, 'customer_name': 'Örnek Müşteri',
                       'telefon': '05551230000', 'invoice_address': 'Adres',
                       'vehicle': {'brand': 'Seat', 'model': 'Ibiza'}, 'notes': email})
    sql("INSERT INTO profiles(id,email,ad_soyad,telefon) VALUES (%s,%s,'Örnek Müşteri','05551230000')", (profile, email))
    sql('INSERT INTO reports(id,user_id,customer_id,data) VALUES (%s,%s,%s,%s::jsonb)', (rid, profile, profile, data))
    sql('INSERT INTO analysis_history(id,user_id,vehicle_json,valuation_json,report_json) VALUES (%s,%s,%s,%s,%s::jsonb)',
        (rid, uid, data, data, data))
    sql('INSERT INTO expertiz_requests(id,user_id,user_email,data) VALUES (%s,%s,%s,%s)', (rid, str(uid), email, data))
    assert client.post('/api/v1/auth/delete-account', headers=headers, json={'password': 'Musteri123!'}).status_code == 200
    profile_row = sql('SELECT * FROM profiles WHERE id=%s', (profile,), True)[0]
    assert profile_row['email'] == f'silindi-{uid}@silindi.invalid' and not profile_row['aktif_mi']
    for table, field in [('reports', 'data'), ('analysis_history', 'report_json'), ('expertiz_requests', 'data')]:
        value = sql(f'SELECT {field} FROM {table} WHERE id=%s', (rid,), True)[0][field]
        if isinstance(value, str):
            value = json.loads(value)
        assert value['customer_email'] is None and value['telefon'] is None and value['invoice_address'] is None
        assert value['vehicle'] == {'brand': 'Seat', 'model': 'Ibiza'}
        assert email not in json.dumps(value)
    import psycopg2
    with pytest.raises(psycopg2.errors.RaiseException, match='değiştirilemez'):
        sql("UPDATE analysis_history SET report_json='{}'::jsonb WHERE id=%s", (rid,))


def test_delete_during_google_verification_cannot_receive_credit(client, customer, google, monkeypatch):
    from yerimebak_ai_v5.services import google_play_service as gp
    uid, headers, _ = customer
    google.account = gp.obfuscated_account_id(uid)
    entered, release = threading.Event(), threading.Event()
    original = google.get_purchase
    def delayed(*args):
        entered.set()
        assert release.wait(15)
        return original(*args)
    monkeypatch.setattr(google, 'get_purchase', delayed)
    with ThreadPoolExecutor(max_workers=1) as pool:
        future = pool.submit(verify, client, headers, uuid.uuid4().hex)
        try:
            assert entered.wait(15)
            assert client.post('/api/v1/auth/delete-account', headers=headers, json={'password': 'Musteri123!'}).status_code == 200
        finally:
            release.set()
        assert future.result(20).status_code == 401
    assert sql('SELECT credits FROM users WHERE id=%s', (uid,), True)[0]['credits'] == 0
    assert sql('SELECT * FROM google_play_purchases WHERE user_id=%s', (uid,), True) == []


@pytest.mark.parametrize('token,status', [('test-ok', 'granted'), ('test-pending-ok', 'pending'), ('test-cancel-ok', None)])
def test_simulation_http(client, customer, monkeypatch, token, status):
    monkeypatch.setenv('GOOGLE_PLAY_SIMULATION', 'true')
    monkeypatch.delenv('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON', raising=False)
    result = verify(client, customer[1], token)
    assert result.status_code == (200 if status else 400)
    if status:
        assert result.json()['status'] == status


def test_deleted_account_stays_deleted_after_admin_reactivation(client, customer, admin_token):
    from yerimebak_ai_v5.services import customer_service
    uid, headers, _ = customer
    assert client.post('/api/v1/auth/delete-account', headers=headers, json={'password': 'Musteri123!'}).status_code == 200
    assert customer_service.set_customer_active(uid, True, 'Test', {'id': 999, 'role': 'admin'})['http_status'] == 409
    # Eski/veritabanı dışı yönetim işlemi is_active alanını yanlışlıkla açsa bile eski JWT canlanmaz.
    sql('UPDATE users SET is_active=1 WHERE id=%s', (uid,))
    assert client.get('/api/v1/auth/me', headers=headers).status_code == 401


def test_reserved_email_and_existing_collision(client, customer):
    uid, headers, _ = customer
    address = f'silindi-{uid}@silindi.invalid'
    assert client.post('/api/v1/auth/register', json={
        'email': address, 'password': 'Musteri123!', 'terms_accepted': True}).status_code == 400
    # Eski kurulumda daha önce açılmış çakışan bir kayıt silmeyi engellememeli.
    sql("INSERT INTO users(email,is_active) VALUES (%s,1)", (address,))
    assert client.post('/api/v1/auth/delete-account', headers=headers, json={'password': 'Musteri123!'}).status_code == 200
    anonymized = sql('SELECT email FROM users WHERE id=%s', (uid,), True)[0]['email']
    assert anonymized.startswith(f'silindi-{uid}-') and anonymized.endswith('@silindi.invalid')


def test_late_paid_order_keeps_deleted_balance_zero(client, customer):
    from yerimebak_ai_v5.services import checkout_service
    uid, headers, _ = customer
    checkout = client.post('/api/v1/payments/checkout/credits', headers=headers,
                           json={'package_key': 'paket5', 'contract_accepted': True})
    assert checkout.status_code == 200, checkout.text
    oid = checkout.json()['order_id']
    assert client.post('/api/v1/auth/delete-account', headers=headers, json={'password': 'Musteri123!'}).status_code == 200
    assert checkout_service.complete_payment(oid, True)['fulfilled']
    assert sql('SELECT credits FROM users WHERE id=%s', (uid,), True)[0]['credits'] == 0
    assert sql('SELECT status FROM payment_orders WHERE id=%s', (oid,), True)[0]['status'] == 'approved'
    assert sum(row['credits_used'] for row in sql('SELECT credits_used FROM credit_usage_logs WHERE user_id=%s', (uid,), True)) == 0


def test_consume_response_lost_but_google_already_consumed(client, customer, google):
    from yerimebak_ai_v5.services import google_play_service as gp
    google.account = gp.obfuscated_account_id(customer[0])
    token = uuid.uuid4().hex
    google.consume_fails = True
    assert verify(client, customer[1], token).json()['status'] == 'granted'
    google.consumption_state = 1
    assert verify(client, customer[1], token).json()['status'] == 'already_granted'
    assert sql('SELECT status FROM google_play_purchases WHERE purchase_token=%s', (token,), True)[0]['status'] == 'consumed'


def test_consumed_unknown_token_is_not_granted(client, customer, google):
    from yerimebak_ai_v5.services import google_play_service as gp
    google.account = gp.obfuscated_account_id(customer[0])
    google.consumption_state = 1
    assert verify(client, customer[1], uuid.uuid4().hex).status_code == 400
    assert sql('SELECT credits FROM users WHERE id=%s', (customer[0],), True)[0]['credits'] == 0


def test_checkout_authenticated_before_deletion_cannot_restore_pii(client, customer, monkeypatch):
    from yerimebak_ai_v5.services import checkout_service
    uid, headers, email = customer
    stale = {'id': uid, 'email': email, 'full_name': 'Örnek Müşteri', 'phone': '05551230000'}
    assert client.post('/api/v1/auth/delete-account', headers=headers, json={'password': 'Musteri123!'}).status_code == 200
    before = len(sql('SELECT * FROM legal_consents WHERE user_id=%s', (uid,), True))
    monkeypatch.setattr(checkout_service, '_start_payment', lambda *a: pytest.fail('Silinen hesap sağlayıcıya aktarıldı'))
    assert checkout_service.start_credit_purchase(stale, 'paket5', '192.0.2.19', True)['http_status'] == 401
    assert checkout_service.start_expertiz_checkout({}, stale, '192.0.2.19')['http_status'] == 401
    assert sql('SELECT * FROM payment_orders WHERE user_id=%s', (uid,), True) == []
    assert len(sql('SELECT * FROM legal_consents WHERE user_id=%s', (uid,), True)) == before


def test_anonymization_flag_cannot_edit_old_snapshot_in_later_transaction(client, customer):
    import psycopg2
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    uid, headers, _ = customer
    rid = uuid.uuid4().hex
    sql('INSERT INTO analysis_history(id,user_id,vehicle_json,valuation_json,report_json) VALUES (%s,%s,%s,%s,%s::jsonb)',
        (rid, uid, '{}', '{}', '{"price":1000000}'))
    assert client.post('/api/v1/auth/delete-account', headers=headers, json={'password': 'Musteri123!'}).status_code == 200
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT set_config('yerimebak.anonymizing_user',%s,true)", (str(uid),))
        with pytest.raises(psycopg2.errors.RaiseException, match='değiştirilemez'):
            cursor.execute("UPDATE analysis_history SET report_json='{}'::jsonb WHERE id=%s", (rid,))
        conn.rollback()
        with pytest.raises(psycopg2.errors.RaiseException, match='değiştirilemez'):
            cursor.execute('DELETE FROM analysis_history WHERE id=%s', (rid,))
    finally:
        conn.rollback()
        DatabaseConfig.return_connection(conn)
    assert sql('SELECT report_json FROM analysis_history WHERE id=%s', (rid,), True)[0]['report_json']['price'] == 1000000
