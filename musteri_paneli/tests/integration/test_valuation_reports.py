"""Kayıtlı değerleme: gerçek PostgreSQL, dış servissiz emsal ve HTTP akışı."""
import json
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import Mock

import pytest
import psycopg2

from .test_dispatch_flow import client, customer_token, admin_token, _auth, TEST_DB
from .test_credit_admin_flow import sql
from yerimebak_ai_v5.services import valuation_service

pytestmark = pytest.mark.skipif(not TEST_DB, reason='TEST_DATABASE_URL tanımlı değil')


@pytest.fixture
def scenario(client, customer_token, monkeypatch):
    uid = client.get('/api/v1/auth/me', headers=_auth(customer_token)).json()['user']['id']
    sql('UPDATE users SET credits=3 WHERE id=%s', (uid,))
    reference = Mock(return_value={
        'found': True, 'count': 8, 'clean_count': 8, 'source': 'web_listings',
        'market_avg_price': 950000, 'market_median_price': 950000,
        'market_min_price': 900000, 'market_max_price': 1000000,
        'samples': [{'site': 'Örnek ilan', 'url': 'https://example.test/ilan/şişli',
                     'price': 950000, 'year': 2024, 'km': 30000}],
    })
    monkeypatch.setattr(valuation_service.web_market_reference, 'get_reference', reference)
    payload = {'brand': 'Seat', 'model': 'Ibiza', 'year': 2024, 'km': 30000,
               'listed_price': 960000, 'request_id': str(uuid.uuid4())}
    return uid, _auth(customer_token), payload, reference


def test_saved_snapshot_retry_ownership_pdf_and_verification(client, admin_token, scenario):
    uid, headers, payload, search = scenario
    first = client.post('/api/v1/valuation/analyze', headers=headers, json=payload)
    assert first.status_code == 200, first.text
    report = first.json()
    identity = report['rapor']
    path = '/api/v1/valuation/reports/' + identity['id']
    stored = sql('SELECT * FROM analysis_history WHERE id=%s', (identity['id'],), True)[0]
    assert stored['report_json'] == report
    assert stored['request_id'] == payload['request_id']
    assert stored['engine_version']
    assert client.get(path, headers=headers).json() == report
    assert client.get(path, headers=_auth(admin_token)).status_code == 404
    assert client.get(path+'/pdf', headers=_auth(admin_token)).status_code == 404
    assert client.get(path).status_code == 401
    sql('UPDATE users SET credits=0 WHERE id=%s', (uid,))
    retry = client.post('/api/v1/valuation/analyze', headers=headers, json=payload)
    assert retry.status_code == 200, retry.text
    assert retry.json() == {**report, 'tekrar': True}
    assert search.call_count == 1
    assert client.get(path, headers=headers).json() == report
    assert sql('SELECT credits FROM users WHERE id=%s', (uid,), True)[0]['credits'] == 0
    pdf = client.get(path+'/pdf', headers=headers)
    assert pdf.status_code == 200, pdf.text
    assert pdf.content.startswith(b'%PDF')
    assert pdf.headers['content-type'] == 'application/pdf'
    import io
    import pdfplumber
    with pdfplumber.open(io.BytesIO(pdf.content)) as document:
        pdf_text = '\n'.join(page.extract_text() for page in document.pages)
    for required in ('Kredili değerleme raporu', 'Özet', 'Değer kaybı tablosu',
                     'Bilgi kaynakları', 'Gelecek değer', identity['verification_code'],
                     'uzman incelemesi değildir.'):
        assert required in pdf_text
    public = client.get('/api/v1/expertiz/verify/'+identity['verification_code']).json()
    assert public['gecerli'] and public['tur'] == 'degerleme'
    assert set(public) == {'gecerli', 'tur', 'marka', 'model', 'yil', 'rapor_no', 'tarih', 'seal_url'}
    assert public['marka'] == 'Seat'
    assert client.get(public['seal_url']).content.startswith(b'\x89PNG')
    assert client.get('/api/v1/expertiz/verify/YD-XXXX-XXXX').json() == {'gecerli': False}
    # Rapor, daha sonra motor/emsal çıktısı değişse de yeniden hesaplanmaz.
    search.side_effect = AssertionError('Arşiv tekrar hesaplanmamalı')
    assert client.get(path, headers=headers).json() == report
    with pytest.raises(psycopg2.Error):
        sql("UPDATE analysis_history SET report_json='{}' WHERE id=%s", (identity['id'],))


def test_concurrent_same_uuid_searches_and_charges_once(client, scenario):
    uid, headers, payload, search = scenario
    gate = threading.Barrier(2)

    def submit():
        gate.wait(timeout=10)
        return client.post('/api/v1/valuation/analyze', headers=headers, json=payload)

    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda _: submit(), range(2)))
    assert [r.status_code for r in responses] == [200, 200], [r.text for r in responses]
    bodies = [r.json() for r in responses]
    assert bodies[0]['rapor'] == bodies[1]['rapor']
    assert sum(bool(b.get('tekrar')) for b in bodies) == 1
    assert search.call_count == 1
    assert sql('SELECT credits FROM users WHERE id=%s', (uid,), True)[0]['credits'] == 2
    assert len(sql('SELECT id FROM analysis_history WHERE user_id=%s AND request_id=%s',
                   (uid, payload['request_id']), True)) == 1


def test_legacy_pagination_and_uuid_validation(client, scenario):
    uid, headers, payload, search = scenario
    legacy_id = str(uuid.uuid4())
    sql('INSERT INTO analysis_history(id,user_id,vehicle_json,valuation_json) VALUES (%s,%s,%s,%s)',
        (legacy_id, uid, json.dumps({'marka': 'Ford', 'model': 'Focus', 'yil': 2020}), '{}'))
    listing = client.get('/api/v1/valuation/reports?limit=1&offset=0', headers=headers)
    assert listing.status_code == 200, listing.text
    assert listing.json()['total'] >= 1 and len(listing.json()['reports']) == 1
    row = next(r for r in client.get('/api/v1/valuation/reports', headers=headers).json()['reports'] if r['id'] == legacy_id)
    assert row['ozet_kayit'] is True
    detail = client.get('/api/v1/valuation/reports/'+legacy_id, headers=headers)
    assert detail.status_code == 200 and detail.json()['ozet_kayit']
    assert client.get('/api/v1/valuation/reports/'+legacy_id+'/pdf', headers=headers).status_code == 409
    assert client.post('/api/v1/valuation/analyze', headers=headers,
                       json={**payload, 'request_id': 'yanlış'}).status_code == 422
    search.assert_not_called()


def test_insufficient_data_or_credits_leave_no_report_and_retry_can_succeed(client, scenario):
    uid, headers, payload, search = scenario
    reference = search.return_value
    search.return_value = {'found': True, 'count': 0}
    response = client.post('/api/v1/valuation/analyze', headers=headers, json=payload)
    assert response.status_code == 422, response.text
    assert sql('SELECT credits FROM users WHERE id=%s', (uid,), True)[0]['credits'] == 3
    assert not sql('SELECT id FROM analysis_history WHERE request_id=%s', (payload['request_id'],), True)
    search.return_value = reference
    sql('UPDATE users SET credits=0 WHERE id=%s', (uid,))
    search.reset_mock()
    assert client.post('/api/v1/valuation/analyze', headers=headers, json=payload).status_code == 402
    search.assert_not_called()
    sql('UPDATE users SET credits=1 WHERE id=%s', (uid,))
    assert client.post('/api/v1/valuation/analyze', headers=headers, json=payload).status_code == 200


def test_database_failure_rolls_back_report_credit_and_usage(client, scenario, monkeypatch):
    uid, headers, payload, search = scenario
    from yerimebak_ai_v5.services import payment_service
    original = payment_service.uuid.uuid4
    report = client.post('/api/v1/valuation/analyze', headers=headers, json=payload).json()
    report_id = report['rapor']['id']
    usages = sql('SELECT COUNT(*) AS n FROM credit_usage_logs WHERE user_id=%s', (uid,), True)[0]['n']
    # Aynı birincil anahtar kaydı başarısız kılar; önceki UPDATE users de geri alınmalı.
    monkeypatch.setattr(payment_service.uuid, 'uuid4', lambda: uuid.UUID(report_id))
    with pytest.raises(psycopg2.IntegrityError):
        valuation_service.analyze({'id': uid}, {**payload, 'request_id': str(original())})
    assert sql('SELECT credits FROM users WHERE id=%s', (uid,), True)[0]['credits'] == 2
    assert len(sql('SELECT id FROM analysis_history WHERE id=%s', (report_id,), True)) == 1
    assert sql('SELECT report_json FROM analysis_history WHERE id=%s', (report_id,), True)[0]['report_json'] == report
    assert sql('SELECT COUNT(*) AS n FROM credit_usage_logs WHERE user_id=%s', (uid,), True)[0]['n'] == usages


def test_same_uuid_is_scoped_to_user_and_new_analyses_are_new_rows(client, admin_token, scenario):
    uid, headers, payload, search = scenario
    one = client.post('/api/v1/valuation/analyze', headers=headers, json=payload)
    other = client.post('/api/v1/valuation/analyze', headers=_auth(admin_token), json=payload)
    assert one.status_code == other.status_code == 200
    assert one.json()['rapor']['id'] != other.json()['rapor']['id']
    assert not other.json().get('tekrar')
    without_uuid = {k: v for k, v in payload.items() if k != 'request_id'}
    new = client.post('/api/v1/valuation/analyze', headers=headers, json=without_uuid)
    assert new.status_code == 200 and new.json()['rapor']['id'] != one.json()['rapor']['id']
    assert search.call_count == 3


def test_waiting_request_locks_do_not_exhaust_business_pool(client, scenario, monkeypatch):
    from psycopg2.extras import DictCursor
    from psycopg2.pool import ThreadedConnectionPool
    from yerimebak_ai_v5.core.infrastructure import database_config as db
    uid, headers, payload, search = scenario
    small_pool = ThreadedConnectionPool(1, 2, dsn=TEST_DB, cursor_factory=DictCursor,
                                       connection_factory=db._PooledConnection)
    monkeypatch.setattr(db, '_pool', small_pool)
    # İlgisiz bir sorgu bir slotu kullanırken iki aynı UUID isteği tek iş
    # bağlantısıyla ilerleyebilmeli; kilitte bekleyenler iş havuzunu tutmamalı.
    occupied = db.DatabaseConfig.get_connection()
    barrier = threading.Barrier(2)

    def run():
        barrier.wait(timeout=10)
        return valuation_service.analyze({'id': uid}, payload)

    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: run(), range(2)))
        assert all(r.get('success') for r in results)
        assert results[0]['rapor'] == results[1]['rapor']
        assert search.call_count == 1
    finally:
        db.DatabaseConfig.return_connection(occupied)
        small_pool.closeall()
