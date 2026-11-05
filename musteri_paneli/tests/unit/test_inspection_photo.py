import io
import pytest
from PIL import Image
from yerimebak_ai_v5.services import inspection_photo as photo


def image_bytes(size=(2400, 800), fmt='PNG'):
    out = io.BytesIO()
    Image.new('RGB', size, 'white').save(out, fmt)
    return out.getvalue()


def test_prepare_only_memory_resizes_and_removes_metadata(monkeypatch):
    monkeypatch.setattr('builtins.open', lambda *a, **k: pytest.fail('disk erişimi'))
    data = photo.prepare(image_bytes())
    with Image.open(io.BytesIO(data)) as image:
        assert image.format == 'JPEG'
        assert image.size == (2000, 667)
        assert not image.getexif()


@pytest.mark.parametrize('value', [b'<html>pdf</html>', b'', b'x' * (8 * 1024 * 1024 + 1)],
                         ids=['yanlis-bicim', 'bos', 'buyuk'])
def test_bad_or_large_image_rejected(value):
    with pytest.raises(photo.PhotoError):
        photo.prepare(value)


def test_parts_and_findings_are_whitelisted_and_serious_is_not_negotiation():
    out = photo.normalize({
        'parts': {'kaput': 'boyali', 'tavan': None, 'bilinmeyen': 'degisen',
                  'sagOnKapi': 'emin_degil'},
        'tramer_amount': -3, 'tramer_count': True,
        'bulgular': [{'kategori': 'motor', 'metin': 'Motorda yağ kaçağı var', 'ciddiyet': 'pazarlik'},
                     {'kategori': 'kaporta', 'metin': 'Tamponda çizik var', 'ciddiyet': 'pazarlik'},
                     {'kategori': 'diger', 'metin': 'Müşteri: Ali Örnek 05321234567', 'ciddiyet': 'bilgi'}],
        'plaka': '34 ABC 123', 'firma_adi': 'Örnek Ekspertiz', 'rapor_tarihi': '2026-11-06',
        'okunamayan_alanlar': ['tavan'],
    })
    assert out['parts'] == {'kaput': 'boyali'}
    assert out['tramer_amount'] is None and out['tramer_count'] is None
    assert [x['ciddiyet'] for x in out['bulgular']] == ['ciddi', 'pazarlik']
    assert 'plaka' not in out and '0532' not in str(out)


def test_uncertain_part_is_not_assumed_original():
    out = photo.normalize({'parts': {'tavan': 'orijinal'}, 'okunamayan_alanlar': ['tavan']})
    assert out['parts'] == {}


def test_fake_model_read_reports_cost_without_persisting(monkeypatch):
    monkeypatch.setattr(photo, '_model', lambda images: (
        {'parts': {'kaput': 'boyali'}, 'firma_adi': 'Örnek'},
        {'model': 'fake', 'cost_usd': 0.002}))
    result = photo.read([image_bytes()])
    assert result['found'] and result['parts'] == {'kaput': 'boyali'}
    assert result['scope']['cost_usd'] == 0.002


@pytest.mark.parametrize('files', [[], [b''] * 5])
def test_count_limit(files):
    with pytest.raises(photo.PhotoError):
        photo.read(files)
