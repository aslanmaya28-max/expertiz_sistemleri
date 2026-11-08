import io
import json
import httpx
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


def test_unread_display_label_maps_to_key_and_missing_parts_stay_visible():
    out = photo.normalize({'parts': {'kaput': 'boyali', 'sagOnKapi': 'orijinal'},
                           'okunamayan_alanlar': ['Sağ Ön Kapı']})
    assert 'sagOnKapi' not in out['parts']
    assert 'sagOnKapi' in out['okunamayan_alanlar']
    out = photo.normalize({'parts': {'kaput': 'boyali'}, 'okunamayan_alanlar': []})
    assert 'sagOnKapi' in out['okunamayan_alanlar']
    assert 'kaput' not in out['okunamayan_alanlar']


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


@pytest.mark.parametrize('fmt', ['JPEG', 'PNG', 'HEIF'])
def test_all_supported_formats(fmt):
    raw = image_bytes((64, 64), fmt)
    with Image.open(io.BytesIO(photo.prepare(raw))) as image:
        assert image.format == 'JPEG'


def test_pixel_limit_before_decode():
    # PNG sıkıştırması küçük olsa da decoded piksel sınırını aşar.
    with pytest.raises(photo.PhotoError, match='megapiksel'):
        photo.prepare(image_bytes((8000, 5100)))


@pytest.mark.parametrize('text', ['Motor normal çalışmıyor', 'Şasi sağlam değil',
                                  'Motor normal, şaside hasar var'])
def test_negative_or_mixed_statement_preserves_serious_finding(text):
    result = photo.normalize({'bulgular': [{'metin': text, 'kategori': 'motor', 'ciddiyet': 'ciddi'}]})
    assert len(result['bulgular']) == 1
    assert result['bulgular'][0]['ciddiyet'] == 'ciddi'


@pytest.mark.parametrize('text', ['Motor normal çalışıyor', 'Şasi sağlam', 'Motor: sorun yok'])
def test_explicit_positive_statement_is_not_a_risk(text):
    assert photo.normalize({'bulgular': [{'metin': text, 'kategori': 'motor', 'ciddiyet': 'ciddi'}]})['bulgular'] == []


@pytest.mark.parametrize('field,text', [('metin', 'Şasi numarası VF1ABCDEF12345678'),
                                      ('metin', 'Şaside VF1ABCDEF12345678 hasar var'),
                                      ('firma_adi', 'VIN VF1ABCDEF12345678'),
                                      ('firma_adi', 'Yetkili VF1ABCDEF12345678 Ekspertiz')])
def test_vin_removed_from_every_text_output(field, text):
    data = {'bulgular': [{'metin': text, 'kategori': 'kaporta', 'ciddiyet': 'ciddi'}]} if field == 'metin' else {field: text}
    assert 'VF1ABCDEF12345678' not in str(photo.normalize(data))


def test_responses_model_request_and_usage_cost(monkeypatch):
    monkeypatch.setenv('OPENROUTER_API_KEY', 'test-only')
    monkeypatch.setenv('EKSPERTIZ_OKUMA_MODEL', 'fake/vision')
    original = httpx.Client
    def handle(request):
        assert str(request.url) == 'https://openrouter.ai/api/v1/responses'
        body = json.loads(request.content)
        assert body['model'] == 'fake/vision'
        assert body['input'][0]['content'][0]['type'] == 'input_text'
        assert body['input'][0]['content'][1]['image_url'].startswith('data:image/jpeg;base64,')
        assert body.get('store', False) is False
        return httpx.Response(200, json={'output': [{'type': 'message', 'content': [
            {'type': 'output_text', 'text': '{"parts":{"kaput":"boyali"}}'}]}],
            'usage': {'cost': 0.0017}})
    monkeypatch.setattr(photo.httpx, 'Client', lambda **kw: original(transport=httpx.MockTransport(handle), **kw))
    result = photo.read([image_bytes((50, 50))])
    assert result['parts'] == {'kaput': 'boyali'}
    assert result['scope'] == {'model': 'fake/vision', 'cost_usd': 0.0017}


@pytest.mark.parametrize('belge,mesaj', [('ilan', 'Ekran görüntüsü yükle'), ('diger', 'ekspertiz raporu bulunamadı')])
def test_ekspertiz_alanina_ilan_ya_da_baska_gorsel_yuklenirse_reddedilir(monkeypatch, belge, mesaj):
    # Kullanıcı denemesi (08.11.2026): ilan görüntüsü bu alana yüklenince satıcı beyanı uzman bulgusu gibi görünmesin.
    monkeypatch.setattr(photo, '_model', lambda images: ({'belge_turu': belge, 'parts': {'kaput': 'boyali'}},
                                                         {'model': 'sahte', 'cost_usd': 0}))
    with pytest.raises(photo.PhotoError, match=mesaj):
        photo.read([image_bytes()])


def test_ekspertiz_raporu_ve_turu_bilinmeyen_yanit_kabul_edilir(monkeypatch):
    for veri in ({'belge_turu': 'ekspertiz_raporu', 'parts': {'kaput': 'boyali'}}, {'parts': {'kaput': 'boyali'}}):
        monkeypatch.setattr(photo, '_model', lambda images, v=veri: (v, {'model': 'sahte', 'cost_usd': 0}))
        assert photo.read([image_bytes()])['parts'] == {'kaput': 'boyali'}


def test_webp_ekran_goruntusu_kabul_edilir():
    with Image.open(io.BytesIO(photo.prepare(image_bytes(fmt='WEBP')))) as image:
        assert image.format == 'JPEG'
