import pytest
from .test_dispatch_flow import client, admin_token, customer_token, _auth, TEST_DB
from .test_credit_admin_flow import sql
from yerimebak_ai_v5.services.payment_service import PaymentService

pytestmark = pytest.mark.skipif(not TEST_DB, reason='TEST_DATABASE_URL tanımlı değil')


def test_movements_authenticated_private_paginated_and_balanced(client, customer_token, admin_token):
    url = '/api/v1/credits/movements'
    headers = _auth(customer_token)
    uid = client.get('/api/v1/auth/me', headers=headers).json()['user']['id']
    other = client.get('/api/v1/auth/me', headers=_auth(admin_token)).json()['user']['id']
    assert client.get(url).status_code == 401
    sql('DELETE FROM credit_usage_logs WHERE user_id=%s', (uid,))
    # Eski hesapta kayıtsız başlangıç bakiyesi olabilir; bu örnekte 3 kredi.
    initial = 3
    sql('UPDATE users SET credits=%s WHERE id=%s', (initial, uid))
    rows = [('credit_purchase', 5, 'PayTR INTERNAL-ORDER: 5 kredi'),
            ('credit_purchase', 10, 'Google Play GPA.secret: token-secret'),
            ('google_play_voided', -2, 'Google Play GPA.secret: token-secret'),
            ('credit_refund', -1, 'Iade INTERNAL-ORDER: token-secret'),
            ('future_action', 1, 'token-secret')]
    for action, amount, description in rows:
        sql('INSERT INTO credit_usage_logs(user_id,action,credits_used,description) VALUES (%s,%s,%s,%s)',
            (uid, action, amount, description))
    sql('UPDATE users SET credits=credits+13 WHERE id=%s', (uid,))
    assert PaymentService().deduct_credits(uid, description='token-secret')['success']
    added = client.post(f'/api/v1/expertiz/admin/customers/{uid}/credits', headers=_auth(admin_token),
                        json={'amount': 4, 'reason': 'token-secret'})
    assert added.status_code == 200, added.text
    sql("INSERT INTO credit_usage_logs(user_id,action,credits_used,description) VALUES (%s,'analysis',99,'OTHER-USER')", (other,))
    result = client.get(url, headers=headers).json()
    movements = result['movements']
    assert result['total'] == 7
    assert [m['id'] for m in movements] == sorted([m['id'] for m in movements], reverse=True)
    assert [(m['tur'], m['miktar'], m['kaynak']) for m in movements] == [
        ('yukleme', 4, 'admin'), ('kullanim', -1, 'analiz'), ('duzeltme', 1, 'admin'),
        ('iade', -1, 'paytr'), ('iade', -2, 'google_play'),
        ('yukleme', 10, 'google_play'), ('yukleme', 5, 'paytr')]
    assert result['balance'] == initial + sum(m['miktar'] for m in movements) == 19
    assert not any(secret in str(result) for secret in ['token-secret', 'INTERNAL-ORDER', 'GPA.secret', 'OTHER-USER'])
    assert all(m['tarih'].endswith('+00:00') for m in movements)
    page = client.get(url+'?limit=2&offset=2', headers=headers).json()
    assert page == {**result, 'movements': movements[2:4]}
    assert client.get(url+'?offset=999', headers=headers).json() == {**result, 'movements': []}
    for query in ('limit=0', 'limit=101', 'offset=-1', 'limit=x'):
        assert client.get(url+'?'+query, headers=headers).status_code == 422
    # Aynı zaman damgasında id azalan sırası kararlı sayfalama sağlar.
    sql("UPDATE credit_usage_logs SET created_at='2026-01-01' WHERE user_id=%s", (uid,))
    assert client.get(url, headers=headers).json()['movements'] == [
        {**m, 'tarih': '2026-01-01T00:00:00+00:00'} for m in movements]
    # Hesap silme günlüğünün negatif bakiye farkı olarak yazıldığını sınar.
    sql("INSERT INTO credit_usage_logs(user_id,action,credits_used,description) VALUES (%s,'account_deleted',-19,'INTERNAL-ORDER')", (uid,))
    sql('UPDATE users SET credits=0 WHERE id=%s', (uid,))
    final = client.get(url, headers=headers).json()
    assert (final['movements'][0]['tur'], final['movements'][0]['miktar'], final['movements'][0]['kaynak']) == ('sifirlama', -19, 'hesap_silme')
    assert final['balance'] == initial + sum(m['miktar'] for m in final['movements']) == 0
    # Analiz geçmişi eski sözleşmesini korur.
    history = client.get('/api/v1/credits/history', headers=headers).json()
    assert set(history) == {'history', 'total'} and history['total'] == 1


def test_empty_movement_history_keeps_opening_balance(client):
    user = PaymentService().get_or_create_user('empty-movements@test.com')
    sql('UPDATE users SET credits=3 WHERE id=%s', (user['id'],))
    assert PaymentService().get_credit_movements(user['id']) == {'movements': [], 'total': 0, 'balance': 3}


def test_legacy_missing_values_still_appear_after_dated_movements(client):
    uid = PaymentService().get_or_create_user('legacy-movements@test.com')['id']
    sql("INSERT INTO credit_usage_logs(user_id,action,credits_used,created_at) VALUES (%s,'unknown',NULL,NULL)", (uid,))
    sql("INSERT INTO credit_usage_logs(user_id,action,credits_used) VALUES (%s,'welcome_bonus',1)", (uid,))
    result = PaymentService().get_credit_movements(uid)
    assert result['total'] == 2
    assert result['movements'][0]['tur'] == 'yukleme'
    assert result['movements'][1]['tarih'] is None
    assert result['movements'][1]['miktar'] == 0
    assert result['movements'][1]['tur'] == 'duzeltme'
