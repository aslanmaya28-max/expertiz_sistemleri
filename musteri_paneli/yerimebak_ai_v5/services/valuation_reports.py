"""Kredili raporların değişmez anlık görüntüleri ve istek kilidi."""
import json
import time
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
    # Müşterinin sildiği raporlar (09.11.2026). Rapor satırı değişmez (tetikleyici korur); silme, raporu
    # müşterinin listesinden/detayından/PDF'inden kaldıran ayrı bir işarettir. Kredi kaydı ve doğrulama korunur.
    tables = _names(cursor, "SELECT table_name FROM information_schema.tables WHERE table_schema = current_schema()")
    if 'valuation_report_hidden' not in tables:
        cursor.execute('''CREATE TABLE IF NOT EXISTS valuation_report_hidden (
            report_id TEXT PRIMARY KEY, user_id INTEGER NOT NULL, hidden_at TIMESTAMPTZ NOT NULL DEFAULT NOW())''')
        # Supabase: tablo dışarıya (anon/authenticated) kapalı kalsın; sunucu sahibi rolle erişir.
        cursor.execute('ALTER TABLE valuation_report_hidden ENABLE ROW LEVEL SECURITY')
    # Aynı isteğin iki kez işlenmesini önleyen kısa ömürlü "işleniyor" kayıtları (request_guard, 09.11.2026).
    if 'valuation_request_claims' not in tables:
        cursor.execute('''CREATE TABLE IF NOT EXISTS valuation_request_claims (
            user_id INTEGER NOT NULL, request_id TEXT NOT NULL,
            claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(), PRIMARY KEY (user_id, request_id))''')
        cursor.execute('ALTER TABLE valuation_request_claims ENABLE ROW LEVEL SECURITY')
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


# Aynı istek (UUID) ikinci kez gelirse ilkinin bitmesini bekleme süresi ve sahipsiz kalan "işleniyor" kaydının
# bayatlama süresi. Değerleme en fazla ~3 dk sürer (arama sınırları 85–90 sn, sıra 60 sn).
GUARD_WAIT_SECONDS = 300
GUARD_STALE_SECONDS = 600
GUARD_POLL_SECONDS = 1.0


def _claim(user_id, request_id):
    """Kısa işlem: rapor hazırsa onu, değilse "işleniyor" kaydını almayı dener. Bağlantı hemen havuza döner."""
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT report_json FROM analysis_history WHERE user_id=%s AND request_id=%s',
                       (user_id, request_id))
        row = cursor.fetchone()
        if row and row['report_json']:
            return 'hazir', dict(row['report_json'], tekrar=True)
        # Çöken işlemden kalan kayıt sonsuza dek beklettirmesin.
        cursor.execute('DELETE FROM valuation_request_claims WHERE user_id=%s AND request_id=%s '
                       'AND claimed_at < NOW() - make_interval(secs => %s)',
                       (user_id, request_id, GUARD_STALE_SECONDS))
        cursor.execute('''INSERT INTO valuation_request_claims (user_id, request_id) VALUES (%s, %s)
                          ON CONFLICT DO NOTHING RETURNING 1''', (user_id, request_id))
        got = cursor.fetchone() is not None
        conn.commit()
        return ('alindi' if got else 'bekle'), None
    finally:
        DatabaseConfig.return_connection(conn)


def _release(user_id, request_id):
    conn = DatabaseConfig.get_connection()
    try:
        conn.cursor().execute('DELETE FROM valuation_request_claims WHERE user_id=%s AND request_id=%s',
                              (user_id, request_id))
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)


@contextmanager
def request_guard(user_id, request_id):
    """Süreçler arasında da aynı UUID'nin aramaya iki kere girmesini önler.

    09.11.2026: Eskiden analiz boyunca (1–3 dk) havuz dışı bir bağlantı açık kalıyordu; Supabase bağlantı
    sınırında eşzamanlı değerleme sayısını ~5'e düşürüyordu. Şimdi kısa işlemlerle "işleniyor" kaydı
    (valuation_request_claims) alınır; ikinci istek bağlantı tutmadan bekler ve ilk raporu döner.
    İlk istek başarısız olursa kayıt silinir, bekleyen istek kendisi dener. Son güvence: (user_id, request_id)
    benzersiz indeksi aynı isteğin iki rapor yazmasını engeller.
    """
    if not request_id:
        yield None
        return
    request_id = str(UUID(str(request_id)))
    deadline = time.monotonic() + GUARD_WAIT_SECONDS
    while True:
        state, report = _claim(user_id, request_id)
        if state == 'hazir':
            yield report
            return
        if state == 'alindi':
            break
        if time.monotonic() >= deadline:
            yield {'error': 'Bu değerleme isteği hâlâ işleniyor; birkaç dakika sonra raporlarınızda görünecek.',
                   'http_status': 409, 'code': 'istek_isleniyor'}
            return
        time.sleep(GUARD_POLL_SECONDS)
    try:
        yield None
    finally:
        _release(user_id, request_id)


def _json(value):
    return json.loads(value) if isinstance(value, str) else value or {}


def summary(row):
    vehicle, valuation = _json(row['vehicle_json']), _json(row['valuation_json'])
    return {'id': row['id'], 'created_at': row['created_at'].isoformat()+'Z',
            'arac': {'marka': vehicle.get('marka') or vehicle.get('brand'), 'model': vehicle.get('model'),
                     'yil': vehicle.get('yil') or vehicle.get('year')},
            # Müşteriye karar verisi (AL/ALMA/EK DOĞRULAMA…) gösterilmez; liste özetinde de gönderilmez (09.11.2026).
            'karar': None,
            'kredi': valuation.get('credits_deducted', 1), 'report_no': row['report_no'],
            'verification_code': row['verification_code'], 'ozet_kayit': not row['has_report']}


HIDDEN_FILTER = 'id::text NOT IN (SELECT report_id FROM valuation_report_hidden WHERE user_id=%s)'


def list_reports(user_id, limit=20, offset=0):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(f'SELECT COUNT(*) AS total FROM analysis_history WHERE user_id=%s AND {HIDDEN_FILTER}',
                       (user_id, user_id))
        total = cursor.fetchone()['total']
        cursor.execute(f'''SELECT id,created_at,vehicle_json,valuation_json,report_no,verification_code,
                          report_json IS NOT NULL AS has_report FROM analysis_history
                          WHERE user_id=%s AND {HIDDEN_FILTER} ORDER BY created_at DESC,id DESC LIMIT %s OFFSET %s''',
                       (user_id, user_id, limit, offset))
        return {'reports': [summary(dict(row)) for row in cursor.fetchall()], 'total': total,
                'limit': limit, 'offset': offset}
    finally:
        DatabaseConfig.return_connection(conn)


def hide_report(user_id, report_id):
    """Müşteri raporunu siler: yalnız kendi raporu; tekrar çağrı zararsızdır."""
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute('SELECT 1 FROM analysis_history WHERE user_id=%s AND id::text=%s', (user_id, str(report_id)))
        if not cursor.fetchone():
            return {'error': 'Rapor bulunamadı', 'http_status': 404}
        cursor.execute('''INSERT INTO valuation_report_hidden (report_id, user_id) VALUES (%s, %s)
                          ON CONFLICT (report_id) DO NOTHING''', (str(report_id), user_id))
        conn.commit()
        return {'success': True}
    finally:
        DatabaseConfig.return_connection(conn)


def get_report(user_id, report_id):
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(f'SELECT *, report_json IS NOT NULL AS has_report FROM analysis_history '
                       f'WHERE user_id=%s AND id=%s AND {HIDDEN_FILTER}',
                       (user_id, report_id, user_id))
        row = cursor.fetchone()
        if not row:
            return {'error': 'Rapor bulunamadı', 'http_status': 404}
        return row['report_json'] if row['has_report'] else summary(dict(row))
    finally:
        DatabaseConfig.return_connection(conn)
