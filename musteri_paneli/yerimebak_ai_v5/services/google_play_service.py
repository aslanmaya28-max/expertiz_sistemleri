"""Google Play tüketilebilir krediler: doğrulama, tek yükleme ve iade uzlaştırması."""
import hashlib
import hmac
import json
import logging
import os
import threading
import uuid
from urllib.parse import quote

import requests
from psycopg2.extras import Json

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.services.auth_service import SECRET_KEY
from yerimebak_ai_v5.services.payment_service import CREDIT_PACKAGES

logger = logging.getLogger(__name__)
_BASE = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'


class GooglePlayError(Exception):
    def __init__(self, message, status=502):
        super().__init__(message)
        self.status = status


def simulation_enabled():
    return (os.getenv('GOOGLE_PLAY_SIMULATION', '').lower() in ('true', '1', 'yes')
            and not os.getenv('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON', '').strip())


def warn_simulation_config():
    if os.getenv('GOOGLE_PLAY_SIMULATION', '').lower() in ('true', '1', 'yes'):
        if not simulation_enabled():
            logger.warning('Google Play hizmet hesabı tanımlı; simülasyon devre dışı.')
        else:
            logger.warning('Google Play simülasyon etkin; yalnız geliştirme/test ortamında kullanılmalıdır.')


def obfuscated_account_id(user_id):
    return hmac.new(SECRET_KEY.encode(), f'gp:{user_id}'.encode(), hashlib.sha256).hexdigest()


def get_products(user):
    return {'products': [{'product_id': key, 'credits': int(pkg['credits']),
                          'name': pkg['name'], 'popular': bool(pkg.get('popular'))}
                         for key, pkg in CREDIT_PACKAGES.items()],
            'obfuscated_account_id': obfuscated_account_id(user['id'])}


class GooglePlayClient:
    def __init__(self):
        self._credentials = None
        self._credentials_json = None
        self._lock = threading.Lock()

    def _access_token(self):
        # google-auth JWT imzalar, OAuth belirtecini son kullanma tarihine kadar saklar.
        from google.oauth2 import service_account
        from google.auth.transport.requests import Request
        config = os.getenv('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON', '').strip()
        if not config:
            raise GooglePlayError('Google Play hizmet hesabı yapılandırılmamış.', 503)
        with self._lock:
            try:
                if self._credentials is None or self._credentials_json != config:
                    info = json.loads(config)
                    # Hizmet hesabı ayarı başka bir adrese anahtar/belirteç göndermesin.
                    info['token_uri'] = 'https://oauth2.googleapis.com/token'
                    self._credentials = service_account.Credentials.from_service_account_info(
                        info, scopes=['https://www.googleapis.com/auth/androidpublisher'])
                    self._credentials_json = config
                if not self._credentials.valid:
                    transport = Request()
                    self._credentials.refresh(lambda *a, **kw: transport(*a, **{**kw, 'timeout': 20}))
                return self._credentials.token
            except GooglePlayError:
                raise
            except Exception:
                raise GooglePlayError('Google Play yetkilendirmesi başarısız.', 503) from None

    def _request(self, method, path, **kwargs):
        package = quote(os.getenv('GOOGLE_PLAY_PACKAGE_NAME') or 'com.yerimebak.app', safe='')
        try:
            response = requests.request(method, _BASE + package + path,
                                        headers={'Authorization': 'Bearer ' + self._access_token()},
                                        timeout=25, **kwargs)
        except requests.RequestException:
            raise GooglePlayError('Google Play bağlantısı kurulamadı; tekrar deneyin.') from None
        if response.status_code >= 400:
            status = 400 if response.status_code in (400, 404, 410) else 502
            # Google hata gövdesi/URL satın alma token'ı içerebilir; döndürülmez/loglanmaz.
            raise GooglePlayError('Google Play satın almayı doğrulayamadı.', status)
        if method == 'POST':
            return {}
        try:
            data = response.json()
            if not isinstance(data, dict):
                raise ValueError()
            return data
        except (ValueError, TypeError):
            raise GooglePlayError('Google Play yanıtı okunamadı.') from None

    def get_purchase(self, product, token):
        return self._request('GET', f'/purchases/products/{quote(product, safe="")}/tokens/{quote(token, safe="")}')

    def consume(self, product, token):
        self._request('POST', f'/purchases/products/{quote(product, safe="")}/tokens/{quote(token, safe="")}:consume')

    def list_voided(self):
        page = None
        while True:
            data = self._request('GET', '/purchases/voidedpurchases', params={**({'token': page} if page else {}), 'type': 0})
            yield from data.get('voidedPurchases', [])
            page = data.get('tokenPagination', {}).get('nextPageToken')
            if not page:
                break


_client = GooglePlayClient()


def get_client():
    return _client


def ensure_schema():
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute('''CREATE TABLE IF NOT EXISTS google_play_purchases (
            id BIGSERIAL PRIMARY KEY,
            purchase_token TEXT UNIQUE NOT NULL,
            order_id TEXT UNIQUE NOT NULL,
            product_id TEXT NOT NULL,
            user_id INTEGER NOT NULL REFERENCES users(id),
            credits INTEGER NOT NULL CHECK (credits > 0),
            status TEXT NOT NULL,
            raw_json JSONB NOT NULL DEFAULT '{}'::jsonb,
            created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )''')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_google_play_user ON google_play_purchases(user_id)')
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)


def _existing(cursor, token, user_id, product):
    cursor.execute('SELECT * FROM google_play_purchases WHERE purchase_token=%s', (token,))
    row = cursor.fetchone()
    if row:
        if row['user_id'] != user_id:
            raise GooglePlayError('Bu satın alma başka bir hesaba aittir.', 403)
        if row['product_id'] != product:
            raise GooglePlayError('Satın alma ürünü eşleşmiyor.', 400)
        if row['status'] == 'voided':
            raise GooglePlayError('Bu satın alma iade veya iptal edilmiş.', 400)
    return row


def _consume(client, product, token):
    try:
        client.consume(product, token)
    except GooglePlayError:
        # Google tüketmiş fakat HTTP yanıtı kaybolmuş olabilir. Yeni kredi verilmez.
        try:
            completed = client.get_purchase(product, token).get('consumptionState') == 1
        except GooglePlayError:
            completed = False
        if not completed:
            logger.warning('Google Play tüketimi tamamlanamadı; sonraki doğrulamada tekrar denenecek.')
            return
    conn = DatabaseConfig.get_connection()
    try:
        conn.cursor().execute("""UPDATE google_play_purchases SET status='consumed', updated_at=NOW()
                                 WHERE purchase_token=%s AND status='granted_not_consumed'""", (token,))
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)


class _SimulationClient:
    def __init__(self, user_id):
        self.user_id = user_id

    def get_purchase(self, product, token):
        if not token.startswith('test-'):
            raise GooglePlayError('Simülasyonda test- ile başlayan token gerekir.', 400)
        return {'orderId': 'TEST.' + hashlib.sha256(token.encode()).hexdigest(),
                'purchaseState': 2 if token.startswith('test-pending-') else 1 if token.startswith('test-cancel-') else 0,
                'obfuscatedExternalAccountId': obfuscated_account_id(self.user_id), 'consumptionState': 0}

    def consume(self, product, token):
        pass


def verify_purchase(user, product_id, purchase_token):
    pkg = CREDIT_PACKAGES.get(product_id)
    if not pkg:
        raise GooglePlayError('Bilinmeyen Google Play ürünü.', 400)
    uid = int(user['id'])
    client = _SimulationClient(uid) if simulation_enabled() else get_client()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        known = _existing(cursor, purchase_token, uid, product_id)
        conn.rollback()
        purchase = None
        if not known:
            purchase = client.get_purchase(product_id, purchase_token)
            if not hmac.compare_digest(str(purchase.get('obfuscatedExternalAccountId') or '').encode(), obfuscated_account_id(uid).encode()):
                raise GooglePlayError('Bu satın alma başka bir hesaba aittir.', 403)
            if purchase.get('productId') not in (None, product_id):
                raise GooglePlayError('Satın alma ürünü eşleşmiyor.', 400)
            if purchase.get('purchaseState') == 2:
                return {'status': 'pending'}
            if purchase.get('purchaseState') != 0 or not purchase.get('orderId'):
                raise GooglePlayError('Satın alma tamamlanmamış veya iptal edilmiş.', 400)
            if purchase.get('consumptionState', 0) != 0:
                raise GooglePlayError('Satın alma daha önce tüketilmiş.', 400)

        # Tüm bakiye işlemleriyle ve hesap silmeyle aynı kullanıcı kilidi.
        cursor.execute('SELECT * FROM users WHERE id=%s FOR UPDATE', (uid,))
        current = cursor.fetchone()
        if not current or not current['is_active'] or current.get('deleted_at'):
            raise GooglePlayError('Hesap etkin değil.', 401)
        known = _existing(cursor, purchase_token, uid, product_id)
        granted = False
        if not known:
            # Başka kullanıcının eşzamanlı talebinde de token ve orderId benzersizdir.
            raw = {k: purchase[k] for k in ('orderId', 'purchaseState', 'consumptionState',
                    'purchaseTimeMillis', 'obfuscatedExternalAccountId', 'productId') if k in purchase}
            cursor.execute('''INSERT INTO google_play_purchases
                (purchase_token,order_id,product_id,user_id,credits,status,raw_json)
                VALUES (%s,%s,%s,%s,%s,'granted_not_consumed',%s)
                ON CONFLICT DO NOTHING RETURNING id''',
                (purchase_token, purchase['orderId'], product_id, uid, pkg['credits'], Json(raw)))
            if not cursor.fetchone():
                known = _existing(cursor, purchase_token, uid, product_id)
                if not known:
                    raise GooglePlayError('Google siparişi daha önce kullanılmış.', 400)
            else:
                oid = 'GP' + uuid.uuid4().hex.upper()
                cursor.execute('''INSERT INTO payment_orders
                    (id,user_id,user_email,user_phone,package_key,package_name,credits,amount_tl,
                     status,payment_method,payment_ref,approved_by,approved_at,admin_note)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'approved','google_play',%s,'google_play',NOW(),%s)''',
                    (oid, uid, current['email'], current.get('phone'), product_id, pkg['name'],
                     pkg['credits'], pkg['price'], purchase['orderId'],
                     'Paketin sunucu TL fiyatıdır; Play gerçek fiyatı ve komisyonu farklı olabilir.'))
                cursor.execute('UPDATE users SET credits=credits+%s WHERE id=%s RETURNING credits', (pkg['credits'], uid))
                balance = cursor.fetchone()['credits']
                cursor.execute('''INSERT INTO credit_usage_logs (user_id,action,credits_used,description)
                    VALUES (%s,'credit_purchase',%s,%s)''',
                    (uid, pkg['credits'], f"Google Play {purchase['orderId']}: {pkg['credits']} kredi yüklendi"))
                granted = True
        if not granted:
            balance = current['credits']
        needs_consume = granted or known['status'] == 'granted_not_consumed'
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        DatabaseConfig.return_connection(conn)
    if needs_consume:
        _consume(client, product_id, purchase_token)
    if granted:
        return {'status': 'granted', 'credits_added': int(pkg['credits']), 'new_balance': int(balance)}
    return {'status': 'already_granted', 'new_balance': int(balance)}


def sync_voided_purchases():
    count, removed = 0, 0
    if simulation_enabled():
        return {'voided_count': 0, 'credits_removed': 0}
    for purchase in get_client().list_voided():
        token = purchase.get('purchaseToken')
        if not token:
            continue
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute('SELECT user_id FROM google_play_purchases WHERE purchase_token=%s', (token,))
            row = cursor.fetchone()
            if not row:
                continue
            uid = row['user_id']
            cursor.execute('SELECT credits FROM users WHERE id=%s FOR UPDATE', (uid,))
            balance = cursor.fetchone()['credits']
            cursor.execute("""UPDATE google_play_purchases SET status='voided',updated_at=NOW()
                WHERE purchase_token=%s AND status<>'voided' RETURNING credits,order_id""", (token,))
            row = cursor.fetchone()
            if row:
                deduction = min(max(0, balance), row['credits'])
                cursor.execute('UPDATE users SET credits=credits-%s WHERE id=%s', (deduction, uid))
                cursor.execute("""UPDATE payment_orders SET status='refunded',updated_at=NOW()
                    WHERE payment_method='google_play' AND payment_ref=%s""", (row['order_id'],))
                cursor.execute('''INSERT INTO credit_usage_logs (user_id,action,credits_used,description)
                    VALUES (%s,'google_play_voided',%s,%s)''',
                    (uid, -deduction, f"Google Play {row['order_id']}: iade/iptal; {deduction}/{row['credits']} kredi geri alındı"))
                count += 1
                removed += deduction
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            DatabaseConfig.return_connection(conn)
    return {'voided_count': count, 'credits_removed': removed}
