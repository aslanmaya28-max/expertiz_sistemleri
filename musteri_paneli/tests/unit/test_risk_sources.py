"""Kaynak sınıflaması ve bağımsızlık denetimi ağ bağlantısı gerektirmez."""
import importlib.util

import pytest


def test_source_module_exists():
    assert importlib.util.find_spec('yerimebak_ai_v5.services.risk_sources') is not None


def sources_module():
    from yerimebak_ai_v5.services import risk_sources
    return risk_sources


@pytest.mark.parametrize('url,expected', [
    ('https://news.service.co.uk/a', 'service.co.uk'),
    ('https://a.example.com.tr/path', 'example.com.tr'),
    ('https://a.example.com.au/', 'example.com.au'),
    ('https://a.example.co.jp/', 'example.co.jp'),
    ('https://WWW.ADac.de./a', 'adac.de'),
    ('https://127.0.0.1/a', ''), ('https://[::1]/', ''),
    ('http://localhost/a', ''), ('not a url', ''), ('', ''),
    ('https://a..com/', ''), ('https://adac.de:bad/a', ''),
    ('ftp://adac.de/a', ''), ('https://co.uk/', ''),
])
def test_root_domain_uses_psl_and_rejects_bad_urls(url, expected):
    assert sources_module().root_domain(url) == expected


@pytest.mark.parametrize('url,brand,kind', [
    ('https://www.ford.com/recall', 'Ford', 'official'),
    ('https://ford.com.tr/recall', 'Toyota', 'unknown'),
    ('https://nhtsa.gov/recalls', '', 'official'),
    ('https://www.kba.de/recalls', '', 'official'),
    ('https://ec.europa.eu/safety-gate-alerts/a', '', 'official'),
    ('https://adac.de/test', '', 'technical'),
    ('https://adac.de.evil.com/test', '', 'unknown'),
    ('https://forum.adac.de/test', '', 'user'),
    ('https://adac.de/%66orum/test', '', 'user'),
    ('https://carforum.org/post', '', 'user'),
    ('https://reddit.com/r/cars', '', 'user'),
    ('https://araclo.com/model', '', 'user'),
    ('https://kronikmotor.com/forum', '', 'blocked'),
    ('https://independent.example.com/article', '', 'unknown'),
])
def test_source_classification(url, brand, kind):
    assert sources_module().source_kind(url, brand) == kind


@pytest.mark.parametrize('left,right,expected', [
    ('https://a.adac.de/1', 'https://adac.de/2', True),
    ('https://ford.com/1', 'https://ford.com.tr/2', True),
    ('https://seat.com/1', 'https://volkswagen.com/2', True),
    ('https://whatcar.com/1', 'https://autocar.co.uk/2', True),
    ('https://adac.de/1', 'https://rac.co.uk/2', False),
    ('bad', 'bad', False),
])
def test_same_publisher(left, right, expected):
    assert sources_module().is_same_publisher(left, right) is expected


def test_registry_has_auditable_reasons_and_publishers():
    assert all(rule.reason and rule.publisher for rule in sources_module().SOURCE_REGISTRY)


def test_independent_count_excludes_user_blocked_invalid_and_empty():
    assert sources_module().independent_count({
        'https://adac.de/a': 'Bir teknik inceleme.',
        'https://forum.rac.co.uk/a': 'Başka inceleme.',
        'https://reddit.com/r/cars': 'İddia.',
        'https://kronikmotor.com/a': 'İddia.',
        'bad': 'İddia.', 'https://rac.co.uk/a': ' ',
    }) == 1


@pytest.mark.parametrize('citation', ['https://adac.de/article', 'adac.de', 'www.adac.de'])
def test_citations_join_even_without_clickable_url(citation):
    assert sources_module().independent_count({
        'https://adac.de/article': 'Özgün teknik değerlendirme.',
        'https://rac.co.uk/report': f'Bulguların kaynağı {citation} olarak belirtilmiştir.',
    }) == 1


def test_host_substrings_are_not_citations():
    assert sources_module().independent_count({
        'https://adac.de/article': 'Özgün teknik değerlendirme.',
        'https://rac.co.uk/report': 'Kaynak notadac.de veya adac.de.evil.com değildir.',
    }) == 2


def test_copied_long_sentence_joins_sources():
    sentence = ('Araçların şanzıman kontrol ünitesinde meydana gelen elektriksel kesintiler '
                'sürüş sırasında beklenmedik güç kaybına ve güvenlik sorunlarına yol açabilir.')
    assert sources_module().independent_count({
        'https://adac.de/a': sentence + ' İlk rapor.',
        'https://rac.co.uk/b': 'İkinci rapor. ' + sentence,
    }) == 1


def test_high_similarity_joins_sources_with_minor_rewriting():
    first = ('The transmission control module can develop an electrical fault during '
             'extended motorway driving and unexpectedly interrupt delivery of engine power '
             'to the wheels requiring immediate workshop inspection and replacement.')
    second = first.replace('extended', 'prolonged').replace('immediate', 'urgent')
    assert sources_module().independent_count({
        'https://adac.de/a': first, 'https://rac.co.uk/b': second,
    }) == 1


def test_independence_uses_transitive_components_and_unknown_domains():
    assert sources_module().independent_count({
        'https://adac.de/a': 'Kaynak rac.co.uk raporudur.',
        'https://rac.co.uk/b': 'Özgün ikinci değerlendirme.',
        'https://aa.example.com/c': 'Kaynak rac.co.uk raporunun devamı.',
        'https://bb.example.net/d': 'Ayrı bir ölçüm sonucu.',
    }) == 2
