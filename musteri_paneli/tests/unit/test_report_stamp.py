import io
from PIL import Image
import pillow_heif
import pytest

from yerimebak_ai_v5.services import stamp_service as stamp


def test_seal_is_navy_png_with_transparency():
    image = Image.open(io.BytesIO(stamp.seal_png('YB-ABCD-2345', 'RAPOR 2026-000001', '01.11.2026')))
    assert image.format == 'PNG' and image.mode == 'RGBA'
    assert image.size == (520, 520)
    assert image.getextrema()[3][0] == 0
    assert image.getextrema()[3][1] == 255


@pytest.mark.parametrize('kind', ['JPEG', 'PNG', 'WEBP', 'HEIF'])
def test_photo_stamp_preserves_original_and_dimensions(kind):
    pillow_heif.register_heif_opener()
    photo = Image.new('RGB', (960, 720), '#8899aa')
    buffer = io.BytesIO()
    photo.save(buffer, format=kind)
    original = buffer.getvalue()
    source = bytes(original)
    result, content_type = stamp.stamp_photo(original, 'image/heic' if kind == 'HEIF' else 'image/'+kind.lower(),
                                            'YB-ABCD-2345', 'RAPOR 2026-000001', '01.11.2026')
    output = Image.open(io.BytesIO(result))
    assert original == source
    assert output.size == photo.size
    assert content_type == 'image/jpeg' and output.format == 'JPEG'
    assert output.convert('RGB').crop((650, 410, 950, 710)).getextrema() != ((136, 136), (153, 153), (170, 170))


def test_transparent_photo_has_white_background():
    buffer = io.BytesIO()
    Image.new('RGBA', (600, 600), (0, 0, 0, 0)).save(buffer, 'PNG')
    content, _ = stamp.stamp_photo(buffer.getvalue(), 'image/png', 'YB-ABCD-2345', 'RAPOR 1', '01.11.2026')
    assert Image.open(io.BytesIO(content)).getpixel((0, 0)) == (255, 255, 255)
