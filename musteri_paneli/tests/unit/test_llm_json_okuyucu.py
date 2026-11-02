"""Ortak JSON okuyucusunun veri uydurmadan kurtarma sınırları."""
import json
import logging

import pytest
import httpx

from yerimebak_ai_v5.services.llm_json import oku


@pytest.mark.parametrize('content', [
    '{"ilanlar":[{"fiyat":1200000}]}',
    '```json\n{"ilanlar":[{"fiyat":1200000}]}\n```',
    'Yanıt: {"ilanlar":[{"fiyat":1200000}]} Açıklama.',
])
def test_complete_json_and_code_fences(content, caplog):
    assert oku(content, listeler=('ilanlar',)) == {'ilanlar':[{'fiyat':1200000}]}
    assert not caplog.records


def test_partial_lists_only_keep_completed_items_and_log_counts(caplog):
    content = '{"riskler":[{"baslik":"Bir"},{"baslik":"İk'
    with caplog.at_level(logging.WARNING):
        assert oku(content, listeler=('riskler',)) == {'riskler':[{'baslik':'Bir'}]}
    assert caplog.records and 'Bir' not in caplog.text and 'İk' not in caplog.text


def test_missing_comma_and_later_list_keep_legacy_risk_behavior():
    content = '{"riskler":[{"a":1},{"b":2} "c":3}],"kullaniciSikayetleri":[{"d":4}]}'
    assert oku(content, listeler=('riskler','kullaniciSikayetleri')) == {
        'riskler':[{'a':1},{'b':2}], 'kullaniciSikayetleri':[{'d':4}]}


def test_completed_prefix_and_source_urls_survive_truncated_generation():
    content = '{"kaynaklar":["https://source.example/kasa"],"nesiller":[{"ad":"Bir"},{"ad":"Yar'
    assert oku(content, listeler=('nesiller',)) == {
        'kaynaklar':['https://source.example/kasa'], 'nesiller':[{'ad':'Bir'}]}


def test_flat_price_and_listing_fields_survive_missing_comma_or_cut_note():
    assert oku('{"medyan":1200000 "min":1100000,"max":1300000,"not":"Yar') == {
        'medyan':1200000,'min':1100000,'max':1300000}


@pytest.mark.parametrize('content', [
    'JSON bulunamadı.', None, '', 'null', '[]', '{bozuk}',
    '[{"x":1}]', '```json\n[{"x":1}]\n```',
    '{"medyan":NaN}', '{"medyan":Infinity}', '{"medyan":-Infinity}',
    '{"medyan":1e999}', 'Sonuç: [{"medyan":1000000}]',
    'Sonuç:\n```json\n[{"medyan":1000000}]\n```',
    '{"medyan":12000',  # Sayının kalan basamakları kesilmiş olabilir.
])
def test_no_supported_complete_fields_raises(content):
    with pytest.raises(ValueError):
        oku(content)


def test_fields_embedded_in_strings_and_nested_objects_are_not_rescued_as_root_lists():
    note = 'Örnek "riskler":[{"fake":1}]'
    text = '{"note":' + json.dumps(note) + ', "yar'
    assert oku(text, listeler=('riskler',)) == {'note':note}
    assert oku('{"nested":{"riskler":[{"fake":1}]},"riskler":[{"real":2},{"x":',
               listeler=('riskler',))['riskler'] == [{'real':2}]


def test_unknown_truncated_lists_are_not_implicitly_rescued():
    with pytest.raises(ValueError):
        oku('{"other":[{"x":1},{"y":')


def test_missing_comma_between_complete_items():
    assert oku('{"ilanlar":[{"x":1} {"x":2}]}', listeler=('ilanlar',)) == {
        'ilanlar':[{'x':1},{'x':2}]}


def test_recovery_logs_do_not_include_untrusted_keys_or_values(caplog):
    secret = 'SENTETIK_OZEL_BILGI'
    with caplog.at_level(logging.WARNING):
        assert oku('{"' + secret + '":"gizli değer","yar') == {secret:'gizli değer'}
    assert caplog.records
    assert secret not in caplog.text and 'gizli değer' not in caplog.text


def test_price_fallback_log_does_not_dump_invalid_response(monkeypatch, caplog):
    from yerimebak_ai_v5.services import ai_price_estimate
    secret = 'SENTETIK_OZEL_BILGI'
    monkeypatch.setenv('OPENROUTER_API_KEY', 'test-fake')
    monkeypatch.setenv('AI_PRICE_ESTIMATE', 'on')
    transport = httpx.MockTransport(lambda request: httpx.Response(200, json={
        'choices':[{'message':{'content':secret}}]}))
    with caplog.at_level(logging.WARNING):
        assert ai_price_estimate.estimate({'brand':'Sentetik','model':'Deneme','year':2023},
                                         transport=transport) is None
    assert caplog.records and secret not in caplog.text


def test_string_value_is_not_promoted_to_root_list():
    assert oku('{"note":"riskler": [{"baslik":"sahte"}],"yarim":',
               listeler=('riskler',)) == {'note':'riskler'}


def test_overflow_in_list_item_drops_only_unfinished_or_invalid_item():
    assert oku('{"ilanlar":[{"fiyat_tl":1000000},{"fiyat_tl":1e999}]}',
               listeler=('ilanlar',)) == {'ilanlar':[{'fiyat_tl':1000000}]}


def test_price_overflow_preserves_safe_prefix_without_crashing():
    from yerimebak_ai_v5.services.ai_price_estimate import parse_answer
    assert parse_answer('{"medyan":1e999}') is None
    result = parse_answer('{"medyan":1000000,"max":1e999,"note":"kes')
    assert result['median'] == result['max'] == 1000000


def test_nested_truncated_value_never_becomes_a_complete_item():
    deep = '[' * 100 + '0'
    with pytest.raises(ValueError):
        oku('{"note":' + deep)
    assert oku('{"ilanlar":[{"x":1},{"x":' + deep,
               listeler=('ilanlar',)) == {'ilanlar':[{'x':1}]}
