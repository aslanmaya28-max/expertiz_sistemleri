"""Rapor kimliği, çevrimdışı ZIP, doğrulama ve onaylı medya arşivi."""
import base64
import hashlib
import html
import json
import math
import os
import re
import secrets
import tempfile
import zipfile
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

from psycopg2.extras import Json

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.services import expertiz_service as reports, media_service as media, stamp_service


def ensure_schema(cursor):
    cursor.execute('CREATE SEQUENCE IF NOT EXISTS report_public_number_seq')
    cursor.execute("""CREATE UNIQUE INDEX IF NOT EXISTS idx_report_verification_code
                      ON reports ((data->>'verification_code')) WHERE data->>'verification_code' IS NOT NULL""")
    cursor.execute('''CREATE TABLE IF NOT EXISTS report_media_requests (
        report_id TEXT NOT NULL, user_id TEXT NOT NULL, requested_day DATE NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), PRIMARY KEY (report_id,user_id,requested_day))''')
    cursor.execute('''CREATE TABLE IF NOT EXISTS report_verify_limits (
        ip_hash TEXT PRIMARY KEY, window_at TIMESTAMPTZ NOT NULL, hits INTEGER NOT NULL)''')
    cursor.execute('CREATE INDEX IF NOT EXISTS idx_report_verify_window ON report_verify_limits(window_at)')


def ensure_identity(cursor, row, data):
    if not data.get('verification_code'):
        alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
        while True:
            code = 'YB-'+''.join(secrets.choice(alphabet) for _ in range(4))+'-'+''.join(secrets.choice(alphabet) for _ in range(4))
            cursor.execute("SELECT 1 FROM reports WHERE data->>'verification_code'=%s", (code,))
            if not cursor.fetchone():
                data['verification_code'] = code
                break
    if not data.get('report_no'):
        cursor.execute("SELECT nextval('report_public_number_seq') AS n")
        number = int(cursor.fetchone()['n'])
        data['report_no'] = f'RAPOR {datetime.now(ZoneInfo("Europe/Istanbul")).year}-{number:06d}'


def _date(value):
    if isinstance(value, str):
        value = datetime.fromisoformat(value.replace('Z', '+00:00'))
    return value.replace(tzinfo=timezone.utc) if value and value.tzinfo is None else value


def retention(row):
    days = max(0, int(os.getenv('ARCHIVE_AFTER_DAYS', '7')))
    data = reports._json_loads(row.get('data'), {}) or {}
    published = _date(data.get('published_at') or row.get('status_updated_at'))
    remaining = max(0, math.ceil(((published+timedelta(days=days))-datetime.now(timezone.utc)).total_seconds()/86400)) if published else days
    return {'days': days, 'remaining_days': remaining,
            'archive_eligible': bool(row.get('status') == 'published' and published and remaining == 0 and not data.get('archive'))}


def seal_fields(row):
    data = reports._json_loads(row.get('data'), {}) or {}
    published = _date(data.get('published_at') or row.get('status_updated_at'))
    return (data.get('verification_code') or 'YAYINLANMADI', data.get('report_no') or 'ÖN İNCELEME',
            published.astimezone(ZoneInfo('Europe/Istanbul')).strftime('%d.%m.%Y') if published else '')


def _safe_name(value):
    return re.sub(r'[^\w-]+', '-', str(value or 'genel'), flags=re.UNICODE).strip('-')[:70] or 'genel'


def _safe_tree(value):
    """HTML metni daima escape edilir; bağlantılar yalnız HTTP(S)."""
    if isinstance(value, dict):
        parts = []
        for key, item in value.items():
            if key in ('url', 'link') and isinstance(item, str) and item.startswith(('https://', 'http://')):
                content = f'<a href="{html.escape(item, quote=True)}" rel="noopener noreferrer nofollow">{html.escape(item)}</a>'
            else:
                content = _safe_tree(item)
            parts.append(f'<dt>{html.escape(str(key))}</dt><dd>{content}</dd>')
        return '<dl>'+''.join(parts)+'</dl>'
    if isinstance(value, list):
        return '<ul>'+''.join('<li>'+_safe_tree(item)+'</li>' for item in value)+'</ul>'
    return html.escape(str(value if value is not None else '—'))


def build_package(row, media_rows, admin=False):
    data = reports._json_loads(row.get('data'), {}) or {}
    code, number, date = seal_fields(row)
    seal = base64.b64encode(stamp_service.seal_png(code, number, date)).decode('ascii')
    public = reports._public_report(row)
    from yerimebak_ai_v5.services.email_service import site_url
    verify_url = site_url('/dogrula/'+code)
    seal_html = f'<img alt="YerimeBak mührü" width="220" src="data:image/png;base64,{seal}">'
    sections = [('Araç bilgileri', data.get('vehicle_snapshot', {})), ('Personel ekspertizi', data.get('tam_rapor') or data.get('inspection') or {}),
                ('Yapay zekâ değerlemesi', public.get('ai') or {}), ('Admin notu', data.get('admin_note') or '')]
    page = ('<!doctype html><html lang="tr"><meta charset="utf-8"><title>'+html.escape(number)+'</title>'
            '<style>body{font:16px sans-serif;color:#182c40;max-width:1000px;margin:32px auto;padding:16px}'
            'dl{display:grid;grid-template-columns:minmax(110px,1fr) 3fr;gap:8px}dd{margin:0;overflow-wrap:anywhere}'
            'section{border-top:1px solid #ccd;padding:16px 0}img{display:block}a{color:#0E4A78}</style>'
            +seal_html+f'<h1>{html.escape(number)}</h1><p>{html.escape(date)} · {html.escape(code)}</p>'
            +f'<p>Rapor doğrula: <a href="{html.escape(verify_url, quote=True)}">{html.escape(verify_url)}</a></p>'
            +''.join(f'<section><h2>{title}</h2>{_safe_tree(value)}</section>' for title, value in sections))
    file = tempfile.SpooledTemporaryFile(max_size=8*1024*1024, mode='w+b')
    sums = []
    try:
        with zipfile.ZipFile(file, 'w', compression=zipfile.ZIP_DEFLATED) as package:
            def add(name, content):
                package.writestr(name, content)
                sums.append((name, hashlib.sha256(content).hexdigest()))
            links, photos = [], []
            for index, item in enumerate(media_rows, 1):
                content = media.read_stored_media(item)
                base = f'{index:02d}-{_safe_name(item.get("section"))}-{_safe_name(item.get("item_key"))}'
                if item.get('category') == 'inspection_photo':
                    stamped, _ = stamp_service.stamp_photo(content, item['content_type'], code, number, date)
                    add('fotograflar/'+base+'.jpg', stamped)
                    photo_path = html.escape('fotograflar/'+base+'.jpg', quote=True)
                    photos.append(f'<figure><a href="{photo_path}"><img width="440" src="{photo_path}" alt="Ekspertiz fotoğrafı"></a>'
                                  f'<figcaption>{html.escape(str(item.get("item_label") or item.get("section") or "Fotoğraf"))}</figcaption></figure>')
                    if admin:
                        add('orijinal/'+base+os.path.splitext(item['file_name'])[1], content)
                else:
                    name = 'kurumsal/'+base+os.path.splitext(item['file_name'])[1]
                    add(name, content)
                    links.append(f'<li><a href="{html.escape(name, quote=True)}">{html.escape(item.get("original_name") or name)}</a></li>')
            page += '<section><h2>Fotoğraflar</h2>'+''.join(photos)+'</section>'
            page += '<section><h2>Kurumsal raporlar</h2><ul>'+''.join(links)+'</ul></section>'+seal_html+'</html>'
            add('rapor.html', page.encode('utf-8'))
            add('veri.json', json.dumps(row if admin else public, default=str, ensure_ascii=False, indent=2).encode('utf-8'))
            package.writestr('ozet.sha256', ''.join(digest+'  '+name+'\n' for name, digest in sums).encode())
        file.seek(0)
        digest = hashlib.file_digest(file, 'sha256').hexdigest()
        size = file.seek(0, 2)
        file.seek(0)
        return file, {'sha256': digest, 'file_count': len(sums)+1, 'bytes': size}
    except Exception:
        file.close()
        raise


@contextmanager
def _transaction():
    conn = DatabaseConfig.get_connection()
    try:
        yield conn, conn.cursor()
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        DatabaseConfig.return_connection(conn)


def _report(cursor, report_id, user, admin=False):
    cursor.execute("SELECT * FROM reports WHERE id::text=%s AND status='published' FOR UPDATE", (str(report_id),))
    raw = cursor.fetchone()
    if not raw:
        return None
    row = dict(raw)
    if not admin:
        profile_id = reports._expertiz_profile_id(user)
        if profile_id not in (str(row.get('user_id')), str(row.get('customer_id'))):
            return None
    return row


def _save(cursor, row, data):
    cursor.execute('UPDATE reports SET data=%s WHERE id::text=%s', (Json(data), str(row['id'])))
    row['data'] = data


def _media(cursor, report_id, include_deleted=True):
    deleted = '' if include_deleted else ' AND deleted_at IS NULL'
    cursor.execute('SELECT * FROM report_media WHERE report_id=%s AND archived_at IS NULL'+deleted+' ORDER BY id', (str(report_id),))
    return [dict(item) for item in cursor.fetchall()]


def package_for(report_id, user, admin=False):
    with _transaction() as (_, cursor):
        row = _report(cursor, report_id, user, admin)
        if not row:
            return {'error': 'Rapor bulunamadı', 'http_status': 404}
        data = reports._json_loads(row.get('data'), {}) or {}
        if data.get('archive'):
            return {'error': 'Fotoğraflar arşivlendi; admin üzerinden talep edebilirsiniz', 'http_status': 410}
        if (data.get('archive_pending') or {}).get('confirmed'):
            return {'error': 'Arşiv silme onayı alınmış; indirdiğiniz kopyayla arşivlemeyi tamamlayın', 'http_status': 409}
        policy = retention(row)
        if admin and not policy['archive_eligible']:
            return {'error': f'Arşivleme için {policy["remaining_days"]} gün daha bekleyin', 'http_status': 400}
        ensure_identity(cursor, row, data)
        _save(cursor, row, data)
        items = _media(cursor, report_id, include_deleted=admin)
        try:
            file, info = build_package(row, items, admin)
        except (media._MediaStorageError, OSError, ValueError):
            return {'error': 'Rapor paketi hazırlanamadı; hiçbir dosya silinmedi', 'http_status': 502}
        if admin:
            data['archive_pending'] = {**info, 'media': {str(item['id']): item['sha256'] for item in items}}
            _save(cursor, row, data)
        return {'file': file, **info}


def confirm_archive(report_id, admin, sha256):
    with _transaction() as (conn, cursor):
        row = _report(cursor, report_id, admin, True)
        if not row:
            return {'error': 'Rapor bulunamadı', 'http_status': 404}
        data = reports._json_loads(row.get('data'), {}) or {}
        if data.get('archive'):
            if not secrets.compare_digest(data['archive']['sha256'], sha256):
                return {'error': 'Arşiv özeti eşleşmiyor', 'http_status': 409}
            return {'success': True, 'archive': data['archive'], 'idempotent': True}
        pending = data.get('archive_pending') or {}
        if not pending.get('sha256') or not secrets.compare_digest(pending['sha256'], sha256):
            return {'error': 'Arşiv özeti eşleşmiyor; paketi yeniden indirin', 'http_status': 409}
        if not retention(row)['archive_eligible']:
            return {'error': 'Rapor henüz arşivlenemez', 'http_status': 400}
        items = _media(cursor, report_id)
        if {str(item['id']): item['sha256'] for item in items} != pending['media']:
            return {'error': 'Rapor dosyaları değişti; paketi yeniden indirin', 'http_status': 409}
        # Onay, dış depoda ilk dosyayı silmeden önce kalıcı olmalı. Süreç
        # kesilirse admin aynı özetle (yeni ZIP üretmeden) devam edebilir.
        pending['confirmed'] = True
        _save(cursor, row, data)
        conn.commit()
        row = _report(cursor, report_id, admin, True)
        data = reports._json_loads(row.get('data'), {}) or {}
        if data.get('archive'):
            return {'success': True, 'archive': data['archive'], 'idempotent': True}
        pending = data.get('archive_pending') or {}
        if not secrets.compare_digest(pending.get('sha256', ''), sha256):
            return {'error': 'Arşiv özeti değişti; admin kaydını kontrol edin', 'http_status': 409}
        items = _media(cursor, report_id)
        if {str(item['id']): item['sha256'] for item in items} != pending['media']:
            return {'error': 'Rapor dosyaları değişti; arşiv silinmedi', 'http_status': 409}
        try:
            for item in items:
                media.delete_stored_media(item)
        except (media._MediaStorageError, OSError):
            return {'error': 'Arşiv silme işlemi tamamlanamadı; aynı onayı tekrar deneyin', 'http_status': 502}
        now = datetime.now(timezone.utc).isoformat()
        data['archive'] = {key: pending[key] for key in ('sha256', 'file_count', 'bytes')}
        data['archive'].update(at=now, by=str(admin.get('id') or admin.get('email')))
        data.pop('archive_pending', None)
        cursor.execute('UPDATE report_media SET archived_at=%s WHERE report_id=%s', (now, str(report_id)))
        _save(cursor, row, data)
        reports._write_audit(cursor, 'REPORT_ARCHIVED', 'report', str(report_id), admin, data['archive'])
        return {'success': True, 'archive': data['archive']}


def request_media(report_id, user):
    with _transaction() as (_, cursor):
        row = _report(cursor, report_id, user)
        if not row:
            return {'error': 'Rapor bulunamadı', 'http_status': 404}
        data = reports._json_loads(row.get('data'), {}) or {}
        if not data.get('archive'):
            return {'error': 'Rapor henüz arşivlenmedi', 'http_status': 400}
        day = datetime.now(ZoneInfo('Europe/Istanbul')).date()
        cursor.execute('''INSERT INTO report_media_requests(report_id,user_id,requested_day) VALUES (%s,%s,%s)
                          ON CONFLICT DO NOTHING RETURNING report_id''', (str(report_id), str(user['id']), day))
        if not cursor.fetchone():
            return {'error': 'Bu rapor için bugün zaten talep oluşturdunuz', 'http_status': 429}
        from yerimebak_ai_v5.services import notification_service
        notification_service.notify_admins(cursor, 'archived_media_request', 'Arşivlenmiş fotoğraf talebi',
                                          f'{data.get("report_no", report_id)} için müşteri arşiv kopyasını talep ediyor.', str(report_id))
        return {'success': True}


def verify(code, ip):
    with _transaction() as (_, cursor):
        ip_hash = hashlib.sha256(str(ip).encode()).hexdigest()
        cursor.execute('''INSERT INTO report_verify_limits(ip_hash,window_at,hits) VALUES (%s,NOW(),1)
            ON CONFLICT(ip_hash) DO UPDATE SET
            hits=CASE WHEN report_verify_limits.window_at < NOW()-INTERVAL '1 minute' THEN 1 ELSE report_verify_limits.hits+1 END,
            window_at=CASE WHEN report_verify_limits.window_at < NOW()-INTERVAL '1 minute' THEN NOW() ELSE report_verify_limits.window_at END
            RETURNING hits''', (ip_hash,))
        if int(cursor.fetchone()['hits']) > 30:
            return {'error': 'Çok fazla doğrulama isteği; bir dakika sonra deneyin', 'http_status': 429}
        cursor.execute("DELETE FROM report_verify_limits WHERE window_at < NOW()-INTERVAL '1 day'")
        cursor.execute("SELECT * FROM reports WHERE status='published' AND data->>'verification_code'=%s", (code.upper().strip(),))
        raw = cursor.fetchone()
        if not raw:
            return {'gecerli': False}
        row = dict(raw)
        data = reports._json_loads(row.get('data'), {}) or {}
        vehicle = data.get('vehicle_snapshot') or {}
        plate = str(row.get('plaka') or vehicle.get('plaka') or '')
        plate = re.sub(r'([A-Za-zÇĞİÖŞÜçğıöşü])([A-Za-zÇĞİÖŞÜçğıöşü]+)', lambda match: match[1]+'*'*len(match[2]), plate)
        code, number, date = seal_fields(row)
        return {'gecerli': True, 'rapor_no': number, 'tarih': date, 'marka': vehicle.get('marka') or vehicle.get('brand'),
                'model': vehicle.get('model'), 'yil': vehicle.get('yil') or vehicle.get('year'), 'plaka_maskeli': plate,
                'durum': 'arsivlendi' if data.get('archive') else 'yayinlandi',
                'seal_url': f'/api/v1/expertiz/verify/{code}/seal.png'}


def report_for_media(report_id):
    with _transaction() as (_, cursor):
        cursor.execute('SELECT * FROM reports WHERE id::text=%s', (str(report_id),))
        raw = cursor.fetchone()
        return dict(raw) if raw else {}
