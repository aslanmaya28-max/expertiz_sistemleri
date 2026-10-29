from unittest.mock import MagicMock

from yerimebak_ai_v5.services import expertiz_service


def test_unpaid_request_enters_queue_without_payment(monkeypatch):
    conn = MagicMock()
    cursor = conn.cursor.return_value
    monkeypatch.setattr(expertiz_service.DatabaseConfig, 'get_connection', lambda: conn)
    monkeypatch.setattr(expertiz_service.DatabaseConfig, 'return_connection', lambda _: None)
    monkeypatch.setattr(expertiz_service, '_ensure_expertiz_requests_schema', lambda _: None)
    report = MagicMock()
    monkeypatch.setattr(expertiz_service, '_upsert_report_from_request', report)
    from yerimebak_ai_v5.services import checkout_service, notification_service
    monkeypatch.setattr(checkout_service, 'quote_expertiz', lambda *_: {
        'selected': {'firm': {'id': 'f', 'name': 'Firma'}, 'package': {'id': 'p', 'name': 'Paket'}},
        'totals': {'service_fee_tl': 100, 'package_price_tl': 200, 'vat_tl': 60, 'total_tl': 360},
    })
    notify = MagicMock()
    monkeypatch.setattr(notification_service, 'notify_admins', notify)
    result = expertiz_service.create_unpaid_request(
        {'firm_id': 'f', 'package_id': 'p', 'city': 'İstanbul', 'district': 'Kadıköy',
         'vehicle': {'brand': 'Ford', 'model': 'Focus'}},
        {'id': 'user-1', 'email': 'test@example.test'},
    )
    assert result['success'] is True
    assert result['payment_status'] == 'not_collected'
    assert report.call_args.kwargs['payment_status'] == 'not_collected'
    assert report.call_args.kwargs['request_id'] == result['request_id']
    notify.assert_called_once()
    conn.commit.assert_called_once()
    assert cursor.execute.called


def test_unpaid_request_requires_location_and_vehicle(monkeypatch):
    monkeypatch.setattr(expertiz_service.DatabaseConfig, 'get_connection', lambda: (_ for _ in ()).throw(AssertionError('DB should not be accessed')))
    result = expertiz_service.create_unpaid_request({'firm_id': 'f', 'package_id': 'p'}, {'id': 'user-1'})
    assert 'error' in result


def test_unpaid_report_is_not_marked_paid(monkeypatch):
    cursor = MagicMock()
    monkeypatch.setattr(expertiz_service, '_ensure_reports_schema', lambda _: None)
    monkeypatch.setattr(expertiz_service, '_upsert_profile', lambda *_: None)
    monkeypatch.setattr(expertiz_service, '_expertiz_profile_id', lambda _: 'user-1')
    monkeypatch.setattr(expertiz_service, '_get_listing_snapshot', lambda *_: None)
    monkeypatch.setattr(expertiz_service, '_get_table_columns', lambda *_: {'id', 'odendi_mi', 'payment_status', 'data'})
    expertiz_service._upsert_report_from_request(
        cursor, 'request-1', {'city': 'İstanbul', 'district': 'Kadıköy'}, {'id': 'user-1'},
        {'firm': {'id': 'f', 'name': 'Firma'}, 'package': {'id': 'p', 'name': 'Paket'}},
        {'service_fee_tl': 100, 'package_price_tl': 200, 'total_tl': 360}, '2026-01-01',
        payment_status='not_collected',
    )
    args = cursor.execute.call_args.args
    columns = args[0].split('INSERT INTO reports (', 1)[1].split(')', 1)[0].split(', ')
    row = dict(zip(columns, args[1]))
    assert row['odendi_mi'] is False
    assert row['data'].adapted['talep']['isPaid'] is False


def test_unpaid_request_rolls_back_when_report_creation_fails(monkeypatch):
    conn = MagicMock()
    monkeypatch.setattr(expertiz_service.DatabaseConfig, 'get_connection', lambda: conn)
    monkeypatch.setattr(expertiz_service.DatabaseConfig, 'return_connection', lambda _: None)
    monkeypatch.setattr(expertiz_service, '_ensure_expertiz_requests_schema', lambda _: None)
    from yerimebak_ai_v5.services import checkout_service
    monkeypatch.setattr(checkout_service, 'quote_expertiz', lambda *_: {
        'selected': {'firm': {'id': 'f', 'name': 'F'}, 'package': {'id': 'p', 'name': 'P'}},
        'totals': {'service_fee_tl': 1, 'package_price_tl': 2, 'vat_tl': 0, 'total_tl': 3},
    })
    def fail(**_):
        raise RuntimeError('report failed')
    monkeypatch.setattr(expertiz_service, '_upsert_report_from_request', fail)
    import pytest
    with pytest.raises(RuntimeError):
        expertiz_service.create_unpaid_request(
            {'firm_id': 'f', 'package_id': 'p', 'city': 'İstanbul', 'district': 'Kadıköy', 'listing_url': 'https://example.test'},
            {'id': 'user-1'},
        )
    conn.rollback.assert_called_once()
    conn.commit.assert_not_called()


def test_unpaid_http_endpoint_forwards_authenticated_customer(monkeypatch):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from yerimebak_ai_v5.api.v1.endpoints import expertiz
    app = FastAPI()
    app.include_router(expertiz.router, prefix='/expertiz')
    customer = {'id': 'user-1', 'role': 'customer'}
    app.dependency_overrides[expertiz.get_authenticated_user] = lambda: customer
    service = MagicMock(return_value={'success': True, 'request_id': 'request-1', 'payment_status': 'not_collected'})
    monkeypatch.setattr(expertiz, 'create_unpaid_request', service)
    response = TestClient(app).post('/expertiz/requests/unpaid', json={
        'firm_id': 'f', 'package_id': 'p', 'city': 'İstanbul', 'district': 'Kadıköy', 'listing_url': 'https://example.test',
    })
    assert response.status_code == 200
    assert response.json()['request_id'] == 'request-1'
    assert service.call_args.args[1] == customer


def test_unpaid_http_endpoint_rejects_unauthenticated_caller(monkeypatch):
    from fastapi import FastAPI
    from fastapi.testclient import TestClient
    from yerimebak_ai_v5.api.v1.endpoints import expertiz
    app = FastAPI()
    app.include_router(expertiz.router, prefix='/expertiz')
    service = MagicMock()
    monkeypatch.setattr(expertiz, 'create_unpaid_request', service)
    response = TestClient(app).post('/expertiz/requests/unpaid', json={'firm_id': 'f', 'package_id': 'p'})
    assert response.status_code in (401, 403)
    service.assert_not_called()


def test_admin_candidates_prioritize_on_duty_personnel_in_same_district(monkeypatch):
    from yerimebak_ai_v5.services import dispatch_service, personnel_service
    request = {'il_id': 34, 'region_id': 1, 'district': 'Kadıköy', 'assignment': {}}
    monkeypatch.setattr(dispatch_service, 'get_admin_request', lambda _: {'request': request})
    def person(id, district, duty):
        return {'id': id, 'il_id': 34, 'region_id': 1, 'district': district,
                'on_duty': duty, 'open_task_count': 0, 'full_name': id}
    monkeypatch.setattr(personnel_service, 'list_personnel', lambda **_: {
        'personnel': [person('baska-ilce', 'Beşiktaş', True), person('ayni-ilce', 'Kadıköy', True),
                      person('pasif', 'Kadıköy', False)]})
    result = dispatch_service.list_candidates('request-1')
    assert result['recommended_id'] == 'ayni-ilce'
    assert [p['id'] for p in result['candidates']] == ['ayni-ilce', 'baska-ilce', 'pasif']
    assert result['candidates'][-1]['assignable'] is False
