from concurrent.futures import ThreadPoolExecutor
import pytest
from .test_dispatch_flow import client, TEST_DB
from .test_credit_admin_flow import sql
from yerimebak_ai_v5.services import risk_cost_search

pytestmark = pytest.mark.skipif(not TEST_DB, reason='TEST_DATABASE_URL tanımlı değil')


def test_daily_cost_budget_is_atomic(client, monkeypatch):
    monkeypatch.setenv('RISK_COST_SEARCH_LIMIT', '3')
    # Teste özel ybtest_026 şeması dışında çalıştırılmaz.
    assert TEST_DB.rsplit('/', 1)[-1].startswith('ybtest_')
    with ThreadPoolExecutor(8) as pool:
        results = list(pool.map(lambda _: risk_cost_search.consume_daily(), range(12)))
    assert sum(results) == 3
    rows = sql('SELECT requests FROM risk_cost_search_usage', fetch=True)
    assert rows[0]['requests'] == 3
