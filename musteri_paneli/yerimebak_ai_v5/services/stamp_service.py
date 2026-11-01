"""Onaylı soğuk mühür taslağı; kaynak fotoğraflara dokunmadan çıktı üretir."""
import io
import math
from functools import lru_cache
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps
import pillow_heif

pillow_heif.register_heif_opener()


def font_paths(bold=False):
    """Mühür ve PDF için ortak Türkçe yazı tipi adayları."""
    name = 'DejaVuSans-Bold' if bold else 'DejaVuSans'
    windows = 'arialbd' if bold else 'arial'
    return (f'/usr/share/fonts/truetype/dejavu/{name}.ttf',
            f'/usr/share/fonts/dejavu/{name}.ttf', f'C:/Windows/Fonts/{windows}.ttf')


def _font(size):
    for path in font_paths(bold=True):
        try:
            return ImageFont.truetype(path, size)
        except OSError:
            pass
    return ImageFont.load_default(size=size)


def _arc(mask, text, center, radius, font, upper=True, spacing=1.12):
    draw = ImageDraw.Draw(mask)
    widths = [draw.textlength(ch, font=font)*spacing for ch in text]
    angle = -math.pi/2-sum(widths)/radius/2 if upper else math.pi/2+sum(widths)/radius/2
    for ch, width in zip(text, widths):
        delta = width/radius
        middle = angle+(delta/2 if upper else -delta/2)
        glyph = Image.new('L', (120, 120))
        ImageDraw.Draw(glyph).text((60, 60), ch, font=font, fill=255, anchor='mm')
        glyph = glyph.rotate(-math.degrees(middle)+(-90 if upper else 90), resample=Image.Resampling.BICUBIC)
        mask.paste(255, (int(center+radius*math.cos(middle)-60), int(center+radius*math.sin(middle)-60)), glyph)
        angle += delta if upper else -delta


def _seal(size, code, number, date):
    width, center = 1040, 520
    mask = Image.new('L', (width, width))
    draw = ImageDraw.Draw(mask)
    draw.ellipse((12, 12, width-12, width-12), outline=255, width=16)
    draw.ellipse((150, 150, width-150, width-150), outline=255, width=6)
    _arc(mask, 'YERİMEBAK EKSPERTİZ', center, center-100, _font(66))
    _arc(mask, 'DİJİTAL DOĞRULAMA', center, center-80, _font(66), False)
    for x in (92, width-92):
        points = [(x+48*(1 if n % 2 == 0 else .42)*math.cos(-math.pi/2+n*math.pi/5),
                   center+48*(1 if n % 2 == 0 else .42)*math.sin(-math.pi/2+n*math.pi/5)) for n in range(10)]
        draw.polygon(points, fill=255)
    with Image.open(Path(__file__).resolve().parents[1]/'assets'/'yerimebak_mark.png') as logo:
        alpha = logo.convert('RGBA').getchannel('A').resize((330, 330), Image.Resampling.LANCZOS)
    mask.paste(255, (center-165, center-245), alpha)
    draw.text((center, center+130), number, font=_font(42), fill=255, anchor='mm')
    draw.text((center, center+185), f'{date} • {code}', font=_font(42), fill=255, anchor='mm')
    return mask.resize((size, size), Image.Resampling.LANCZOS)


@lru_cache(maxsize=128)
def seal_png(kod, no, tarih):
    mask = _seal(520, kod, no, tarih)
    image = Image.new('RGBA', mask.size, '#0E4A78')
    image.putalpha(mask)
    output = io.BytesIO()
    image.save(output, 'PNG')
    return output.getvalue()


def stamp_photo(content, content_type, kod, no, tarih):
    with Image.open(io.BytesIO(content)) as source:
        oriented = ImageOps.exif_transpose(source).convert('RGBA')
        image = Image.new('RGBA', oriented.size, 'white')
        image.alpha_composite(oriented)
    size = max(1, int(min(image.size)*.30))
    mask = _seal(size, kod, no, tarih)
    x, y = int(image.width-size-size*.08), int(image.height-size-size*.08)
    offset = max(2, size//170)
    for color, dx, dy, opacity in [('black', offset, offset, .85*.45),
                                    ('white', -offset, -offset, .85*.45), ('white', 0, 0, .5*.45)]:
        layer = Image.new('RGBA', mask.size, color)
        layer.putalpha(mask.point(lambda value: round(value*opacity)))
        image.alpha_composite(layer, (x+dx, y+dy))
    output = io.BytesIO()
    image.convert('RGB').save(output, 'JPEG', quality=92)
    return output.getvalue(), 'image/jpeg'
