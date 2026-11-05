"""Eksik risk masrafları için en fazla tek, günlük kotası atomik ek arama."""
import json
import logging
import math
import os
import httpx
from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.services import web_market_reference as wmr

logger = logging.getLogger(__name__)


def daily_limit():
    try:
        return max(0, min(1000, int(os.getenv('RISK_COST_SEARCH_LIMIT', '20'))))
    except ValueError:
        return 20


def consume_daily():
    limit = daily_limit()
    if not limit:
        return False
    conn = None
    try:
        conn = DatabaseConfig.get_connection()
        with conn.cursor() as cur:
            cur.execute('SET LOCAL statement_timeout = 5000')
            cur.execute('SELECT pg_advisory_xact_lock(800826)')
            cur.execute('''CREATE TABLE IF NOT EXISTS risk_cost_search_usage (
                day DATE PRIMARY KEY, requests INTEGER NOT NULL CHECK(requests >= 0))''')
            cur.execute('''INSERT INTO risk_cost_search_usage(day,requests)
                VALUES ((NOW() AT TIME ZONE 'Europe/Istanbul')::date,1)
                ON CONFLICT(day) DO UPDATE SET requests=risk_cost_search_usage.requests+1
                WHERE risk_cost_search_usage.requests < %s RETURNING requests''', (limit,))
            allowed = cur.fetchone() is not None
        conn.commit()
        return allowed
    except Exception as exc:
        if conn:
            conn.rollback()
        logger.warning('[RISK MASRAF] Günlük kota alınamadı: %s', type(exc).__name__)
        return False
    finally:
        if conn:
            DatabaseConfig.return_connection(conn)


def _request(vehicle, selected, timeout):
    query = wmr._vehicle_text({**vehicle, 'km': None})
    titles = [item['baslik'] for item in selected]
    prompt = '''Yalnız Türkiye servis/usta sayfalarında şu araç ve aynı onarım için açık TL fiyatı ara.
Başka bakımın fiyatını kullanma; fiyat yoksa kalemi boş bırak. Forum/şikâyet fiyatı kullanma.
Kaynak sayfada aynı onarım adı ve TL tutarı açıkça geçmeli; tahmin, döviz çevirisi, toplama yapma.
Araç: %s. Kalemler: %s.
Yalnız JSON: {"onarimlar":[{"baslik":"verilen başlığın aynısı","onarim":"kaynakta yazan tam onarım/işlem adı",
"tahminiMaliyet":{"min":0,"max":0},"kaynaklar":["https://..."]}]}.
En fazla3kalem, yalnız bu başlıklar; başlıkla ilgisiz motor/şanzıman sürümü kullanma.''' % (query, json.dumps(titles, ensure_ascii=False))
    with httpx.Client(timeout=timeout) as client:
        return wmr._search(query, client, prompt=prompt, web=True)


def search(vehicle, risks, timeout=20):
    empty = {'items': [], 'sources': {}, 'cost_usd': 0, 'searches': 0}
    selected = [r for r in risks if r.get('guven') in ('orta', 'yuksek') and not r.get('tahminiMaliyet')][:3]
    if not selected or timeout < 2 or not daily_limit() or not os.getenv('OPENROUTER_API_KEY') or not consume_daily():
        return empty
    try:
        result = _request(vehicle, selected, min(20, timeout))
        cost = result.get('cost')
        cost = float(cost) if isinstance(cost, (int, float)) and math.isfinite(cost) and cost >= 0 else 0
        titles = {r['baslik'] for r in selected}
        data = result.get('data')
        items = data.get('onarimlar') if isinstance(data, dict) else []
        return {'items': [i for i in (items if isinstance(items, list) else [])
                          if isinstance(i, dict) and isinstance(i.get('baslik'), str) and i['baslik'] in titles][:3],
                'sources': result.get('sources') or {}, 'cost_usd': cost, 'searches': 1}
    except Exception as exc:
        logger.warning('[RISK MASRAF] Ek arama tamamlanamadı: %s', type(exc).__name__)
        return {**empty, 'searches': 1}
