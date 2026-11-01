import hashlib
import io
import json
import zipfile
from datetime import datetime, timedelta, timezone

from PIL import Image
from yerimebak_ai_v5.services import report_archive as archive, media_service


def test_retention_uses_first_publication_and_requires_seven_days():
    now = datetime.now(timezone.utc)
    row = {'status': 'published', 'data': {'published_at': (now-timedelta(days=6, hours=23)).isoformat()}}
    assert archive.retention(row)['remaining_days'] == 1
    assert archive.retention(row)['archive_eligible'] is False
    row['data']['published_at'] = (now-timedelta(days=7, seconds=1)).isoformat()
    assert archive.retention(row)['archive_eligible'] is True
    row['status'] = 'draft'
    assert archive.retention(row)['archive_eligible'] is False


def test_zip_contains_stamped_photos_raw_originals_and_valid_manifest(tmp_path, monkeypatch):
    monkeypatch.setenv('MEDIA_STORAGE', 'local')
    monkeypatch.setenv('MEDIA_ROOT', str(tmp_path))
    photo = io.BytesIO()
    Image.new('RGB', (640, 480), 'gray').save(photo, 'JPEG')
    folder = tmp_path/'report-1'
    folder.mkdir()
    (folder/'photo.jpg').write_bytes(photo.getvalue())
    (folder/'report.pdf').write_bytes(b'%PDF-1.7\nkurumsal')
    row = {'id': 'report-1', 'status': 'published', 'plaka': '34 ABC 123', 'data': {
        'verification_code': 'YB-ABCD-2345', 'report_no': 'RAPOR 2026-000001',
        'published_at': datetime.now(timezone.utc).isoformat(),
        'vehicle_snapshot': {'marka': 'Fiat', 'model': '<script>bad()</script>'},
        'tam_rapor': {'ic': {'koltuk': 'Sağlam'}}, 'admin_note': '<b>not</b>'}}
    media = [{'id': '1', 'report_id': 'report-1', 'file_name': 'photo.jpg', 'category': 'inspection_photo',
              'section': '../ic', 'item_key': '../koltuk', 'content_type': 'image/jpeg', 'sha256': 'a'},
             {'id': '2', 'report_id': 'report-1', 'file_name': 'report.pdf', 'category': 'corporate_report',
              'content_type': 'application/pdf', 'sha256': 'b'}]
    file, meta = archive.build_package(row, media, admin=True)
    with file, zipfile.ZipFile(file) as package:
        names = package.namelist()
        assert {'rapor.html', 'veri.json', 'ozet.sha256'} <= set(names)
        assert all('..' not in name for name in names)
        original = next(n for n in names if n.startswith('orijinal/'))
        stamped = next(n for n in names if n.startswith('fotograflar/'))
        assert package.read(original) == photo.getvalue()
        assert package.read(stamped) != photo.getvalue()
        assert Image.open(io.BytesIO(package.read(stamped))).size == (640, 480)
        html = package.read('rapor.html').decode()
        assert '<script>bad()</script>' not in html and '&lt;script&gt;' in html
        assert 'data:image/png;base64,' in html and 'Sağlam' in html
        for line in package.read('ozet.sha256').decode().splitlines():
            digest, name = line.split('  ', 1)
            assert hashlib.sha256(package.read(name)).hexdigest() == digest
        assert meta['file_count'] == len(names)
    assert (folder/'photo.jpg').read_bytes() == photo.getvalue()
    file, _ = archive.build_package(row, media, admin=False)
    with file, zipfile.ZipFile(file) as package:
        assert not any(n.startswith('orijinal/') for n in package.namelist())
        data = json.loads(package.read('veri.json'))
        assert 'data' not in data


def test_supabase_delete_uses_authenticated_api(monkeypatch):
    import httpx
    requests = []
    monkeypatch.setenv('SUPABASE_URL', 'https://storage.example.test')
    monkeypatch.setenv('SUPABASE_SERVICE_ROLE_KEY', 'secret-test')
    monkeypatch.setenv('SUPABASE_MEDIA_BUCKET', 'report-media')
    monkeypatch.setenv('MEDIA_STORAGE', 'supabase')
    client = httpx.Client
    def handler(request):
        requests.append(request)
        return httpx.Response(200)
    monkeypatch.setattr(media_service.httpx, 'Client', lambda **kwargs: client(transport=httpx.MockTransport(handler), **kwargs))
    media_service.delete_stored_media({'report_id': 'r-1', 'file_name': 'p.jpg'})
    request, = requests
    assert request.method == 'DELETE'
    assert request.url.path == '/storage/v1/object/report-media/r-1/p.jpg'
    assert request.headers['apikey'] == 'secret-test'
