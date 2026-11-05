import pytest
from yerimebak_ai_v5.services import risk_evidence as evidence, vehicle_risk as vr


@pytest.mark.parametrize('title,category', [
    ('Triger seti', 'motor'), ('DSG mekatronik', 'sanziman'),
    ('Kaput boya soyulması', 'kaporta'), ('Rot başı', 'alt_takim'),
    ('Multimedya donması', 'elektronik'), ('Elektronik aksam', 'elektronik'),
    ('Aksiyon', 'diger'), ('Genel titreme', 'diger')])
def test_six_categories_ignore_model_label(title, category):
    assert vr._classification({'kategori': 'trim_kasa'}, vr._topics(title), None)[0] == category


@pytest.mark.parametrize('text,want', [
    ('Triger arızası 80.000–120.000 km aralığında görülebilir.', {'min': 80000, 'max': 120000}),
    ('Triger sorunu 100.000 km civarı görülür.', {'min': 100000, 'max': 100000}),
    ('Triger 100 bin km civarı', None), ('Triger genellikle yüksek kilometrede sorun çıkarır.', None),
    ('Triger kontrolü. Lastik arızası 80.000–120.000 km aralığında.', None),
    ('Triger kontrol edilir, lastikler 80.000–120.000 km aralığında aşınabilir.', None),
    ('Triger kontrol edilir ve lastikler 80.000–120.000 km aralığında aşınabilir.', None),
    ('Triger kontrolünde lastikler 80.000–120.000 km aralığında aşınabilir.', None),
    ('80.000–120.000 km aralığında triger sorunu görülebilir.', {'min': 80000, 'max': 120000}),
    ('Triger fiyatı 8.000–12.000 TL.', None)])
def test_km_only_explicit_same_topic_source(text, want):
    actual = evidence.km_range({'https://servis.test': text}, ['triger'], vr._TOPICS)
    assert (actual[0] if actual else None) == want


def test_importance_only_one_step_near_range():
    item = {'onem': 'dusuk', 'tipikKm': {'min': 80000, 'max': 100000}}
    assert evidence.at_km(item, 105000)['onem'] == 'orta'
    assert evidence.at_km(item, 105000)['kilometreUyarisi'] == 'Bu kilometrede dikkat'
    assert evidence.at_km(item, 150000)['onem'] == 'dusuk'
    assert 'kilometreUyarisi' not in evidence.at_km(item, 150000)
    assert item['onem'] == 'dusuk'


@pytest.mark.parametrize('text,repair,ok', [
    ('Mekatronik onarımı 25.000–30.000 TL.', 'Mekatronik onarımı', True),
    ('Şanzıman yağ değişimi 25.000–30.000 TL.', 'Mekatronik onarımı', False),
    ('Mekatronik kontrolü ve şanzıman yağ değişimi 25.000–30.000 TL.', 'Mekatronik kontrolü', False),
    ('Mekatronik onarımı fiyatı için arayın.', 'Mekatronik onarımı', False),
    ('Mekatronik onarımı 25.000–30.000 EUR.', 'Mekatronik onarımı', False)])
def test_only_exact_repair_explicit_tl(text, repair, ok):
    actual = evidence.cost_proof({'min': 25000, 'max': 30000}, text, repair,
                                 ['mekatronik'], vr._topics, vr._cost)
    assert bool(actual) is ok


def test_combined_repair_cannot_hide_other_job_in_label():
    for repair in ('Mekatronik kontrolü ve şanzıman yağ değişimi',
                   'Mekatronik onarımı ve yağ değişimi'):
        assert evidence.cost_proof({'min': 25000, 'max': 30000}, repair + ' 25.000–30.000 TL.',
                                   repair, ['mekatronik'], vr._topics, vr._cost) is None
