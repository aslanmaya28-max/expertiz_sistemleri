"""Gerçek PostgreSQL ve yerel dosyalarla raporun yayın → ZIP → onay akışı."""
import hashlib
import io
import json
import os
import zipfile

import pytest
from psycopg2.extras import Json

from tests.integration import test_dispatch_flow as flow

pytestmark = pytest.mark.skipif(not os.getenv('TEST_DATABASE_URL'), reason='TEST_DATABASE_URL tanımlı değil')
client = flow.client
admin_token = flow.admin_token
customer_token = flow.customer_token


def _published(client, admin_token, customer_token, monkeypatch, tmp_path):
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    from yerimebak_ai_v5.services import media_service
    monkeypatch.setenv('MEDIA_ROOT', str(tmp_path))
    monkeypatch.setenv('MEDIA_STORAGE', 'local')
    report_id = flow._create_paid_request(client, customer_token, '34 ABC 123', 'İstanbul')
    conn = DatabaseConfig.get_connection()
    try:
        cur = conn.cursor()
        cur.execute('SELECT data FROM reports WHERE id::text=%s', (report_id,))
        data = dict(cur.fetchone())['data']
        if isinstance(data, str):
            data = json.loads(data)
        data.update(ai_meta={'source': 'central_ai', 'official': True, 'ready': True},
                    tam_rapor={'ic': {'koltuk': 'Sağlam'}, 'dis': {'tampon': 'Çizik'}})
        cur.execute("UPDATE reports SET status='pending_admin', data=%s, ai_analizi_yapildi_mi=TRUE, ai_analysis_result=%s WHERE id::text=%s",
                    (Json(data), Json({'tamamlandiMi': True, 'ekspertizDegerleme': {'aiDegeri': 850000}}), report_id))
        photo = media_service.store_media(cur, report_id, {'id': 'staff'}, flow.JPEG_BYTES, 'foto.jpg', 'inspection_photo')['media']
        media_service.store_media(cur, report_id, {'id': 'staff'}, flow.PDF_BYTES, 'rapor.pdf', 'corporate_report')
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    response = client.post(f'/api/v1/expertiz/admin/reports/{report_id}/publish', headers=flow._auth(admin_token))
    assert response.status_code == 200, response.text
    return report_id, response.json()['report'], photo


def _age(report_id):
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    conn = DatabaseConfig.get_connection()
    try:
        cur = conn.cursor()
        cur.execute("UPDATE reports SET data=jsonb_set(data,'{published_at}',to_jsonb((NOW()-INTERVAL '8 days')::text)) WHERE id::text=%s", (report_id,))
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)


def test_package_archive_confirmation_and_customer_request(client, admin_token, customer_token, monkeypatch, tmp_path):
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    from yerimebak_ai_v5.services import email_service
    emails = email_service.capture_for_tests()
    try:
        report_id, report, photo = _published(client, admin_token, customer_token, monkeypatch, tmp_path)
    finally:
        email_service.stop_capture()
    assert emails and any(report['verification_code'] in message.get_body(preferencelist=('plain',)).get_content() for message in emails)
    assert report['verification_code'].startswith('YB-') and report['report_no'].startswith('RAPOR ')
    root = f'/api/v1/expertiz/admin/reports/{report_id}/archive'
    customer = f'/api/v1/expertiz/reports/{report_id}'
    assert client.get(root, headers=flow._auth(admin_token)).status_code == 400
    assert client.get(root, headers=flow._auth(customer_token)).status_code == 403
    assert client.post(customer+'/media-request', headers=flow._auth(customer_token)).status_code == 400
    assert client.get(customer+'/package', headers=flow._auth(admin_token)).status_code == 404
    package = client.get(customer+'/package', headers=flow._auth(customer_token))
    assert package.status_code == 200, package.text
    with zipfile.ZipFile(io.BytesIO(package.content)) as archive:
        assert 'rapor.html' in archive.namelist()
        assert not any(name.startswith('orijinal/') for name in archive.namelist())
    verify = '/api/v1/expertiz/verify/'+report['verification_code']
    public = client.get(verify)
    assert public.status_code == 200 and public.json()['gecerli'] is True
    assert public.json()['plaka_maskeli'] == '34 A** 123'
    assert set(public.json()) == {'gecerli', 'tur', 'rapor_no', 'tarih', 'marka', 'model', 'yil', 'plaka_maskeli', 'durum', 'seal_url'}
    assert public.json()['tur'] == 'ekspertiz'
    assert client.get(public.json()['seal_url']).headers['content-type'] == 'image/png'
    assert client.get('/api/v1/expertiz/verify/YB-XXXX-XXXX').json() == {'gecerli': False}
    _age(report_id)
    download = client.get(root, headers=flow._auth(admin_token))
    assert download.status_code == 200, download.text
    digest = hashlib.sha256(download.content).hexdigest()
    assert download.headers['x-archive-sha256'] == digest
    with zipfile.ZipFile(io.BytesIO(download.content)) as archive:
        original = next(name for name in archive.namelist() if name.startswith('orijinal/'))
        assert archive.read(original) == flow.JPEG_BYTES
    assert client.post(root+'/confirm', json={'sha256': '0'*64}, headers=flow._auth(admin_token)).status_code == 409
    assert client.get(photo['url']).status_code == 200
    assert client.post(root+'/confirm', json={'sha256': digest}, headers=flow._auth(customer_token)).status_code == 403
    confirmed = client.post(root+'/confirm', json={'sha256': digest}, headers=flow._auth(admin_token))
    assert confirmed.status_code == 200, confirmed.text
    again = client.post(root+'/confirm', json={'sha256': digest}, headers=flow._auth(admin_token))
    assert again.status_code == 200 and again.json()['idempotent'] is True
    assert client.post(root+'/confirm', json={'sha256': '1'*64}, headers=flow._auth(admin_token)).status_code == 409
    detail = client.get(customer, headers=flow._auth(customer_token)).json()['report']
    assert detail['archive']['sha256'] == digest and detail['report']['ic']['koltuk'] == 'Sağlam'
    assert all(item['url'] is None for item in detail['media'])
    assert client.get(photo['url']).status_code == 410
    assert not list((tmp_path/report_id).glob('*'))
    assert client.get(customer+'/package', headers=flow._auth(customer_token)).status_code == 410
    assert client.get(verify).json()['durum'] == 'arsivlendi'
    requested = client.post(customer+'/media-request', headers=flow._auth(customer_token))
    assert requested.status_code == 200, requested.text
    assert client.post(customer+'/media-request', headers=flow._auth(customer_token)).status_code == 429
    conn = DatabaseConfig.get_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) AS n FROM notifications WHERE kind='archived_media_request' AND report_id=%s", (report_id,))
        assert cur.fetchone()['n'] == 1
        cur.execute('SELECT COUNT(*) AS n FROM report_media WHERE report_id=%s AND archived_at IS NOT NULL', (report_id,))
        assert cur.fetchone()['n'] == 2
        cur.execute("SELECT COUNT(*) AS n FROM audit_logs WHERE action='REPORT_ARCHIVED' AND entity_id=%s", (report_id,))
        assert cur.fetchone()['n'] == 1
    finally:
        DatabaseConfig.return_connection(conn)


def test_changed_manifest_blocks_deletion_and_verify_rate_limit(client, admin_token, customer_token, monkeypatch, tmp_path):
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    report_id, report, photo = _published(client, admin_token, customer_token, monkeypatch, tmp_path)
    _age(report_id)
    root = f'/api/v1/expertiz/admin/reports/{report_id}/archive'
    package = client.get(root, headers=flow._auth(admin_token))
    assert package.status_code == 200
    conn = DatabaseConfig.get_connection()
    try:
        cur = conn.cursor()
        cur.execute("UPDATE report_media SET sha256='changed' WHERE id=%s", (photo['id'],))
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    confirm = client.post(root+'/confirm', json={'sha256': package.headers['x-archive-sha256']}, headers=flow._auth(admin_token))
    assert confirm.status_code == 409
    assert list((tmp_path/report_id).glob('*'))
    for _ in range(30):
        assert client.get('/api/v1/expertiz/verify/YB-XXXX-XXXX', headers={'X-Real-IP': '192.0.2.9'}).status_code == 200
    assert client.get('/api/v1/expertiz/verify/'+report['verification_code'], headers={'X-Real-IP': '192.0.2.9'}).status_code == 429


def test_archive_can_resume_after_partial_storage_failure(client, admin_token, customer_token, monkeypatch, tmp_path):
    from yerimebak_ai_v5.services import media_service
    report_id, _, _ = _published(client, admin_token, customer_token, monkeypatch, tmp_path)
    _age(report_id)
    root = f'/api/v1/expertiz/admin/reports/{report_id}'
    package = client.get(root+'/archive', headers=flow._auth(admin_token))
    assert package.status_code == 200
    digest = package.headers['x-archive-sha256']
    original_delete = media_service.delete_stored_media
    deleted = []
    def fail_second(item):
        if deleted:
            raise media_service._MediaStorageError
        original_delete(item)
        deleted.append(item['id'])
    monkeypatch.setattr(media_service, 'delete_stored_media', fail_second)
    failed = client.post(root+'/archive/confirm', headers=flow._auth(admin_token), json={'sha256': digest})
    assert failed.status_code == 502
    assert len(list((tmp_path/report_id).glob('*'))) == 1
    detail = client.get(root, headers=flow._auth(admin_token)).json()['report']
    assert detail['archive_retry_sha256'] == digest
    assert client.get(root+'/archive', headers=flow._auth(admin_token)).status_code == 409
    customer = client.get(f'/api/v1/expertiz/reports/{report_id}', headers=flow._auth(customer_token)).json()['report']
    assert 'archive_retry_sha256' not in customer
    monkeypatch.setattr(media_service, 'delete_stored_media', original_delete)
    retry = client.post(root+'/archive/confirm', headers=flow._auth(admin_token), json={'sha256': digest})
    assert retry.status_code == 200, retry.text
    assert not list((tmp_path/report_id).glob('*'))
