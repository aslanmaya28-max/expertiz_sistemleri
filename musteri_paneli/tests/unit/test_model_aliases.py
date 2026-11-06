"""030: takma ad yanlış kuşak veya motor kanıtını geçerli kılamaz."""
from types import SimpleNamespace

import pytest

from yerimebak_ai_v5.services import vehicle_risk as vr
from tools.risk_smoke_diagnostics import compare_candidates

VEHICLE = dict(brand='Fiat', model='Egea', year=2019, engine='1.3 Multijet',
               package='1.3 Multijet', fuel='Dizel', transmission='Manuel')
A = 'https://engineering.example.com/tipo'
B = 'https://workshop.example.org/tipo'
TEXT = 'Fiat Tipo 1.3 Multijet triger zinciri sesi servis kontrolü gerektirir.'
OTHER = 'Tipo 1.3 Multijet zincir uzaması soğuk çalıştırmada incelenir ve bakım kayıtları karşılaştırılır.'


def verify(sources, vehicle=VEHICLE):
    return vr._verify(dict(baslik='Zincir sesi', kaynaklar=list(sources)), sources, vehicle)


def test_two_independent_alias_sources_gain_medium_confidence():
    out = verify({A: TEXT, B: OTHER})
    assert out['guven'] == 'orta'
    assert out['kanitSeviyesi'] == 'İki bağımsız teknik kaynak'
    assert out['tahminiMaliyet'] is None
    assert 'tipikKm' not in out
    assert vr._scoped(TEXT, VEHICLE, ['zincir'])


def test_reverse_alias_and_cross_are_scoped():
    assert vr._scoped(TEXT.replace('Tipo', 'Egea'), {**VEHICLE, 'model': 'Tipo'}, ['zincir'])
    cross = {**VEHICLE, 'model': 'Egea Cross', 'year': 2022, 'engine': '1.6 Multijet', 'package': ''}
    assert vr._scoped('Tipo Cross 1.6 Multijet zincir kontrolü.', cross, ['zincir'])
    assert not vr._scoped('Tipo 1.6 Multijet zincir kontrolü.', cross, ['zincir'])


@pytest.mark.parametrize('text,changes', [
    (TEXT, {'year': 2014}), (TEXT, {'year': None}), (TEXT, {'brand': 'Toyota'}),
    (TEXT, {'engine': '', 'package': ''}),
    (TEXT.replace('Tipo', 'Linea'), {}),
    ('Tipo 1988–1995 1.3 Multijet zincir kontrolü.', {}),
    ('Tipo 1992 1.3 Multijet zincir kontrolü.', {}),
    ('1992 Tipo 1.3 Multijet zincir kontrolü, güncelleme 2026.', {}),
    (TEXT.replace('1.3', '1.6'), {}),
    (TEXT.replace('Multijet', 'Fire'), {}),
    ('Tipo 1.3 Multijet otomatik şanzıman zincir kontrolü.', {}),
    ('Tipo tanıtımı. 1.3 Multijet zincir kontrolü.', {}),
    ('Tipoloji 1.3 Multijet zincir kontrolü.', {}),
    ('Tipo Cross 1.3 Multijet zincir kontrolü.', {}),
    ('Tipo Cross Wagon 1.3 Multijet zincir kontrolü.', {}),
    ('Tipo 1.3 Multijet hatchback zincir kontrolü.', {}),
    ('Tipo 1.3 Multijet Station Wagon zincir kontrolü.', {}),
    ('Tipo 1.3 Multijet Cross zincir kontrolü.', {}),
    ('Tipo 1.3 Multijet SW zincir kontrolü.', {}),
], ids=['old-target', 'missing-year', 'brand', 'missing-engine', 'unknown', 'old-range',
        'old-single-year', 'old-year-with-update', 'wrong-displacement', 'wrong-family', 'wrong-gear', 'split',
        'substring', 'cross-is-not-sedan', 'wagon-is-not-sedan', 'late-hatchback',
        'late-station-wagon', 'late-cross', 'late-sw'])
def test_invalid_alias_is_never_scoped(text, changes):
    assert not vr._scoped(text, {**VEHICLE, **changes}, ['zincir'])


def test_alias_wrong_engine_is_incompatible_even_when_displacement_matches():
    assert vr._incompatible('Tipo 1.3 Fire zincir kontrolü.', VEHICLE)
    assert vr._incompatible('Tipo 1992 1.3 Multijet zincir kontrolü.', VEHICLE)
    assert not vr._incompatible(TEXT, VEHICLE)


@pytest.mark.parametrize('sources', [{A: TEXT}, {A: TEXT, B: TEXT},
    {A: TEXT, A + '/2': OTHER}, {'https://adac.de/tipo': TEXT}])
def test_alias_alone_or_copied_does_not_upgrade(sources):
    assert verify(sources)['guven'] == 'dusuk'


def test_official_alias_record_preserves_029_rule():
    out = verify({'https://fiat.com/recall': TEXT + ' Servis bülteni recall.'})
    assert out['guven'] == 'yuksek'


def test_official_alias_cannot_borrow_model_scope_from_another_risk():
    text = 'Tipo 1.3 Multijet DPF recall kaydı. Zincir sesi servis kontrolü gerektirir.'
    out = verify({'https://fiat.com/recall': text})
    assert out['guven'] == 'dusuk'


@pytest.mark.parametrize('text', [
    'Tipo 1.3 Multijet ve 1.6 Multijet zincir sesi kontrol edilir.',
    'Tipo 1.3 Multijet ve 1.3 TDI zincir sesi kontrol edilir.',
])
def test_alias_cannot_hide_different_engine_in_same_sentence(text):
    assert not vr._scoped(text, VEHICLE, ['zincir'])
    assert vr._incompatible(text, VEHICLE)


def test_alias_diagnostic_counts_unique_scoped_urls_only():
    sources = {A: TEXT, B: OTHER, 'https://other.example.net/a': 'Tipo 1.6 Multijet zincir.'}
    result = verify(sources)
    old = SimpleNamespace(_verified_items=lambda *a: [])
    out = compare_candidates([], sources, VEHICLE, [result, result], old)
    assert out['alias_accepted_source_count'] == 2


def test_alias_registry_entries_have_primary_evidence_and_boundaries():
    from yerimebak_ai_v5.services import model_aliases
    assert model_aliases.aliases(VEHICLE) == ('Tipo',)
    assert model_aliases.aliases({**VEHICLE, 'model': 'Taliant', 'brand': 'Renault'}) == ()
    assert model_aliases.aliases({**VEHICLE, 'model': 'Tiggo 7 Pro Max', 'brand': 'Chery'}) == ()
    assert model_aliases.aliases({**VEHICLE, 'model': 'Accent Blue', 'brand': 'Hyundai'}) == ()
    for rule in model_aliases.MODEL_ALIASES:
        assert rule.reason and rule.sources and rule.generation and rule.engines
        assert all(url.startswith('https://') for url in rule.sources)


def test_search_payload_uses_alias_and_independent_evidence_without_extra_calls(monkeypatch):
    import httpx
    import json

    monkeypatch.setenv('OPENROUTER_API_KEY', 'test-fake')
    monkeypatch.setenv('WEB_RISK_CACHE_DAYS', '0')
    payloads = []

    def respond(request):
        body = json.loads(request.content)
        payloads.append(body)
        return httpx.Response(200, json={'choices': [{'message': {
            'content': '{"riskler": [], "kullaniciSikayetleri": []}'}}], 'usage': {'cost': .013}})

    client_type = httpx.Client
    monkeypatch.setattr(vr.httpx, 'Client', lambda **kw: client_type(transport=httpx.MockTransport(respond), **kw))
    result = vr.get_model_risks(VEHICLE)
    assert len(payloads) == 1
    prompt = payloads[0]['messages'][0]['content']
    assert 'Egea' in prompt and '(yurt dışında: Tipo)' in prompt
    assert 'Her risk için en az iki bağımsız kaynak' in prompt and 'farklı yayıncı' in prompt
    assert result['scope']['cost_usd'] == pytest.approx(.013)


def test_v7_cache_does_not_share_alias_eligibility_at_cross_year_boundary():
    cross = {**VEHICLE, 'model': 'Egea Cross', 'engine': '1.6 Multijet', 'package': ''}
    assert vr._cache_key(cross).startswith('vehicle-risk:v7:')
    assert vr._cache_key({**cross, 'year': 2020}) != vr._cache_key({**cross, 'year': 2021})


def test_default_smoke_selects_all_five_vehicles():
    from tools.risk_evidence_smoke import selected_vehicles
    assert [v['model'] for v in selected_vehicles()] == ['Formentor', 'Egea', 'Focus', 'Golf', 'Egea Cross']
    assert [v['model'] for v in selected_vehicles(technical_pair=True)] == ['Focus', 'Golf']
