from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

import pytest

from .test_dispatch_flow import (client, admin_token, customer_token, _auth, _login, _create_personnel, TEST_DB)
from yerimebak_ai_v5.services.payment_service import PaymentService
from yerimebak_ai_v5.core.database_config import DatabaseConfig

pytestmark = pytest.mark.skipif(not TEST_DB, reason='TEST_DATABASE_URL tanımlı değil')


def sql(query, params=(), fetch=False):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(query, params)
        rows = cursor.fetchall() if fetch else None
        conn.commit()
        return rows
    finally:
        DatabaseConfig.return_connection(conn)


def test_admin_credit_and_tier_flow(client, admin_token, customer_token):
    headers = _auth(admin_token)
    customers = client.get('/api/v1/expertiz/admin/customers', headers=headers).json()['customers']
    uid = next(c['id'] for c in customers if c['email'] == 'musteri@yerimebak.test')
    # Kayıt fixture'ı e-postayı doğrulamaz (hediye henüz verilmez).
    # Bu senaryo başlangıç bakiyesi 3 olan mevcut bir müşteriyle çalışır.
    sql('UPDATE users SET credits=3 WHERE id=%s', (uid,))
    url = f'/api/v1/expertiz/admin/customers/{uid}'
    def post(path, body, auth=headers):
        return client.post(url + path, json=body, headers=auth)

    assert post('/credits', {'amount': 10, 'reason': 'Telafi'}).json()['customer']['credits'] == 13
    assert post('/credits', {'amount': -4, 'reason': 'Düzeltme'}).json()['customer']['credits'] == 9
    assert post('/credits', {'amount': -10, 'reason': 'Hata'}).status_code == 400
    for body in ({'amount': 0, 'reason': 'x'}, {'amount': 10001, 'reason': 'x'},
                 {'amount': 1, 'reason': ' '}, {'amount': 1.5, 'reason': 'x'}, {'amount': True, 'reason': 'x'}):
        assert post('/credits', body).status_code in (400, 422)
    assert post('/tier', {'tier': 'unknown'}).status_code == 400
    _create_personnel(client, admin_token, 'credit-staff@test.com', 'İstanbul', 'Kadıköy', 'Kredi Personeli')
    staff = _login(client, 'credit-staff@test.com', 'Personel123')
    for token in (customer_token, staff):
        assert post('/credits', {'amount': 1, 'reason': 'x'}, _auth(token)).status_code == 403
        assert post('/tier', {'tier': 'pro'}, _auth(token)).status_code == 403
    # Seviye degisimi kredi eklemez (aylik kredi yok)
    assert post('/tier', {'tier': 'pro', 'note': 'Galeri'}).json()['customer']['credits'] == 9
    assert post('/tier', {'tier': 'pro'}).json()['customer']['credits'] == 9
    service = PaymentService()
    with ThreadPoolExecutor(max_workers=4) as pool:
        assert list(pool.map(lambda _: service.get_credit_balance(uid)['credits'], range(4))) == [9] * 4
    detail = client.get(url, headers=headers).json()
    assert detail['tier_limits']['free'] == {'max_analyses_per_day': 5}
    assert len(detail['credit_movements']) == 2
    audits = sql("SELECT action, metadata FROM audit_logs WHERE entity_id=%s AND action IN ('CUSTOMER_CREDITS_ADJUSTED', 'CUSTOMER_TIER_CHANGED')", (str(uid),), True)
    assert len(audits) == 4
    adjustment = next(r['metadata'] for r in audits if r['action'] == 'CUSTOMER_CREDITS_ADJUSTED')
    assert adjustment['credits_before'] == 3 and adjustment['credits_after'] == 13
    assert adjustment['reason'] == 'Telafi'

    assert post('/tier', {'tier': 'free'}).status_code == 200
    sql('UPDATE users SET credits=20 WHERE id=%s', (uid,))
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda _: service.deduct_credits(uid), range(8)))
    assert sum(r['success'] for r in results) == 5
    assert all(r.get('code') == 'daily_limit' for r in results if not r['success'])
    assert service.get_credit_balance(uid)['credits'] == 15
    assert service.check_credits_before_analysis(uid) is False
    assert service.analysis_allowed(uid)['reason'] == 'daily_limit'


def test_analysis_timestamp_is_utc_even_with_local_database_timezone(client, monkeypatch):
    service = PaymentService()
    uid = service.get_or_create_user('timezone@test.com')['id']
    get_connection = DatabaseConfig.get_connection

    def local_connection():
        conn = get_connection()
        conn.cursor().execute("SET LOCAL TIME ZONE 'Europe/Istanbul'")
        return conn

    monkeypatch.setattr(DatabaseConfig, 'get_connection', local_connection)
    result = service.deduct_credits(uid)
    assert result['success']
    row = sql('SELECT created_at FROM analysis_history WHERE id=%s', (result['history_id'],), True)[0]
    assert abs((row['created_at'] - datetime.now(timezone.utc).replace(tzinfo=None)).total_seconds()) < 10
