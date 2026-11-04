"""Kredili raporların değişmez anlık görüntüleri ve istek kilidi."""
import json
from contextlib import contextmanager
from uuid import UUID

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.core.ai.inspection_valuation import MODEL_VERSION

ENGINE_VERSION = MODEL_VERSION


def _names(cursor, sql):
    cursor.execute(sql)
    return {(row[0] if not isinstance(row, dict) else next(iter(row.values()))) for row in cursor.fetchall()}


def ensure_schema(cursor):
    """Rapor kolonları ve indeksleri.

    Zaten varsa ALTER/CREATE INDEX çalıştırılmaz: "IF NOT EXISTS" olsa bile PostgreSQL tabloyu önce kilitler.
    Sunucu açılırken (Render yeni sürümü yayınlarken eski sunucu rapor hazırlıyorsa) bu kilit, request_guard'ın
    açık işlemini bekliyor, arkasındaki rapor sorguları da kilidi bekliyordu: değerleme sonsuza dek takılıyordu
    (02.11.2026 yerel denemede ölçüldü). Kilit beklemesi ayrıca 10 sn ile sınırlıdır.
    """
    cursor.execute("SET LOCAL lock_timeout = '10s'")
    cursor.execute('CREATE SEQUENCE IF NOT EXISTS valuation_report_number_seq')
    columns = _names(cursor, "SELECT column_name FROM information_schema.columns "
                             "WHERE table_schema = current_schema() AND table_name = 'analysis_history'")
    for name, kind in (('report_json', 'JSONB'), ('report_no', 'TEXT'),
                       ('verification_code', 'TEXT'), ('request_id', 'TEXT'), ('engine_version', 'TEXT')):
        if name not in columns:
            cursor.execute(f'ALTER TABLE analysis_history ADD COLUMN IF NOT EXISTS {name} {kind}')
    indexes = _names(cursor, "SELECT indexname FROM pg_indexes "
                             "WHERE schemaname = current_schema() AND tablename = 'analysis_history'")
    for name, sql in (
            ('idx_valuation_request', 'CREATE UNIQUE INDEX IF NOT EXISTS idx_valuation_request ON analysis_history(user_id,request_id)'),
            ('idx_valuation_code', 'CREATE UNIQUE INDEX IF NOT EXISTS idx_valuation_code ON analysis_history(verification_code)'),
            ('idx_valuation_number', 'CREATE UNIQUE INDEX IF NOT EXISTS idx_valuation_number ON analysis_history(report_no)'),
            ('idx_valuation_owner_date', 'CREATE INDEX IF NOT EXISTS idx_valuation_owner_date ON analysis_history(user_id,created_at DESC,id DESC)')):
        if name not in indexes:
            cursor.execute(sql)
    cursor.execute('''CREATE OR REPLACE FUNCTION protect_valuation_snapshot() RETURNS trigger AS $$
        BEGIN
            IF OLD.report_json IS NOT NULL THEN
                -- Yalnız hesap silme işleminin aynı transaction içindeki anonimleştirmesi.
                -- Kimlik, rapor numarası, zaman ve diğer arşiv metaverileri korunur.
                IF TG_OP = 'UPDATE'
                   AND current_setting('yerimebak.anonymizing_user', true) = OLD.user_id::text
                   AND EXISTS (SELECT 1 FROM users WHERE id=OLD.user_id AND is_active=0
                               AND deleted_at=transaction_timestamp()
                               AND xmin::text=(txid_current() % 4294967296)::text)
                   AND (to_jsonb(NEW) - ARRAY['vehicle_json','valuation_json','report_json'])
                       = (to_jsonb(OLD) - ARRAY['vehicle_json','valuation_json','report_json']) THEN
                    RETURN NEW;
                END IF;
                RAISE EXCEPTION 'Kayıtlı değerleme raporu değiştirilemez';
            END IF;
            IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
            RETURN NEW;
        END; $$ LANGUAGE plpgsql''')
    cursor.execute('''DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname='valuation_snapshot_immutable'
                       AND tgrelid='analysis_history'::regclass) THEN
            CREATE TRIGGER valuation_snapshot_immutable BEFORE UPDATE OR DELETE ON analysis_history
                FOR EACH ROW EXECUTE FUNCTION protect_valuation_snapshot();
        END IF;
    END $$''')


@contextmanager
def request_guard(user_id, request_id):
    """Süreçler arasında da aynı UUID'nin aramaya iki kere girmesini önler.

    Kilit bağlantısı kredi işlemi bitene kadar açık kalır. Ayrı kredi işlemi
    commit olduktan sonra bekleyen istek READ COMMITTED ile raporu görür.
    Hata halinde rollback kilidi de serbest bırakır.
    """
    if not request_id:
        yield None
        return
    request_id = str(UUID(str(request_id)))
    conn = DatabaseConfig.get_lock_connection()
    try:
        conn.set_session(isolation_level='READ COMMITTED')
        cursor = conn.cursor()
        cursor.execute('SELECT pg_advisory_xact_lock(hashtextextended(%s,0))',
                       (f'valuation:{user_id}:{request_id}',))
        cursor.execute('SELECT report_json FROM analysis_history WHERE user_id=%s AND request_id=%s',
                       (user_id, request_id))
        row = cursor.fetchone()
        yield dict(row['report_json'], tekrar=True) if row and row['report_json'] else None
    finally:
        try:
            conn.rollback()
        finally:
            conn.close()


def _json(value):
    return json.loads(value) if isinstance(value, str) else value or {}


def summary(row):
    vehicle, valuation = _json(row['vehicle_json']), _json(row['valuation_json'])
    return {'id': row['id'], 'created_at': row['created_at'].isoformat()+'Z',
            'arac': {'marka': vehicle.get('marka') or vehicle.get('brand'), 'model': vehicle.get('model'),
                     'yil': vehicle.get('yil') or vehicle.get('year')},
            'karar': valuation.get('karar') or valuation.get('decision'),
            'kredi': valuation.get('credits_deducted', 1), 'report_no': row['report_no'],
            'verification_code': row['verification_code'], 'ozet_kayit': not row['has_report']}


def list_reports(user_id, limit=20, offset=0):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT COUNT(*) AS total FROM analysis_history WHERE user_id=%s', (user_id,))
        total = cursor.fetchone()['total']
        cursor.execute('''SELECT id,created_at,vehicle_json,valuation_json,report_no,verification_code,
                          report_json IS NOT NULL AS has_report FROM analysis_history
                          WHERE user_id=%s ORDER BY created_at DESC,id DESC LIMIT %s OFFSET %s''',
                       (user_id, limit, offset))
        return {'reports': [summary(dict(row)) for row in cursor.fetchall()], 'total': total,
                'limit': limit, 'offset': offset}
    finally:
        DatabaseConfig.return_connection(conn)


def get_report(user_id, report_id):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT *, report_json IS NOT NULL AS has_report FROM analysis_history WHERE user_id=%s AND id=%s',
                       (user_id, report_id))
        row = cursor.fetchone()
        if not row:
            return {'error': 'Rapor bulunamadı', 'http_status': 404}
        return row['report_json'] if row['has_report'] else summary(dict(row))
    finally:
        DatabaseConfig.return_connection(conn)
