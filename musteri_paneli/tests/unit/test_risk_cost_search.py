import pytest
from yerimebak_ai_v5.services import risk_cost_search as cs


def risk(title='Triger seti', **extra):
    return {'baslik': title, 'guven': 'orta', 'tahminiMaliyet': None, **extra}


def test_single_search_three_items_and_cost(monkeypatch):
    calls = []
    monkeypatch.setenv('RISK_COST_SEARCH_LIMIT', '20')
    monkeypatch.setenv('OPENROUTER_API_KEY', 'test-only')
    monkeypatch.setattr(cs, 'consume_daily', lambda: True)
    def request(vehicle, selected, timeout):
        calls.append(selected)
        return {'data': {'onarimlar': [{'baslik': item['baslik']} for item in selected]},
                'sources': {}, 'cost': .004}
    monkeypatch.setattr(cs, '_request', request)
    out = cs.search({'brand': 'Seat', 'model': 'Arona'}, [risk(str(i)) for i in range(7)])
    assert len(calls) == 1 and len(calls[0]) == 3
    assert out['searches'] == 1 and out['cost_usd'] == .004
    assert len(out['items']) == 3


def test_only_missing_medium_high_risks_and_quota(monkeypatch):
    monkeypatch.setenv('RISK_COST_SEARCH_LIMIT', '20')
    monkeypatch.setenv('OPENROUTER_API_KEY', 'test-only')
    monkeypatch.setattr(cs, 'consume_daily', lambda: False)
    monkeypatch.setattr(cs, '_request', lambda *a: pytest.fail('arama olmamalı'))
    assert cs.search({}, [risk()])['searches'] == 0
    assert cs.search({}, [risk(guven='dusuk'), risk(tahminiMaliyet={'min': 1, 'max': 2})])['searches'] == 0


@pytest.mark.parametrize('raw,want', [('0', 0), ('-1', 0), ('yanlis', 20), ('99999', 1000)])
def test_config_bounds(monkeypatch, raw, want):
    monkeypatch.setenv('RISK_COST_SEARCH_LIMIT', raw)
    assert cs.daily_limit() == want
