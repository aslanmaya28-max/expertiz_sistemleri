"""Gerçek model denemesi: kişisel verisiz sentetik rapor, yalnız bellekte görüntü.

PYTHON_DOTENV_DISABLED=1 ve yetkili sürece verilmiş OPENROUTER_API_KEY ile:
python -m tools.inspection_photo_smoke
Anahtar veya görüntü dosyası okunmaz/yazılmaz; sonuç ve usage.cost yazdırılır.
"""
import io
import json
from PIL import Image, ImageDraw, ImageFont
from yerimebak_ai_v5.services.inspection_photo import read, PhotoError
from yerimebak_ai_v5.services.stamp_service import font_paths


def synthetic():
    font = None
    for path in font_paths():
        try:
            font = ImageFont.truetype(path, 32)
            break
        except OSError:
            pass
    if font is None:
        raise RuntimeError('Sentetik Türkçe rapor için yazı tipi bulunamadı.')
    image = Image.new('RGB', (1400, 1800), 'white')
    draw = ImageDraw.Draw(image)
    lines = ['SENTETİK EKSPERTİZ RAPORU — GERÇEK ARAÇ DEĞİLDİR',
             'Firma: Sentetik Örnek Oto Ekspertiz', 'Rapor tarihi: 05.11.2026',
             'Motor Kaputu: Boyalı', 'Tavan: Orijinal', 'Sol Ön Kapı: Değişen',
             'Sağ Ön Kapı: Okunamıyor', 'Tramer toplam tutarı: 125.000 TL',
             'Hasar kayıt adedi: 2', 'Teknik bulgu: Motorda yağ kaçağı görüldü.',
             'Teknik bulgu: Ön tamponda yüzeysel çizik görüldü.',
             'Diğer parçalar bu sayfada belirtilmemiştir.',
             'Bu görsel kişisel veri içermez.']
    for i, line in enumerate(lines):
        draw.text((60, 60 + i * 100), line, fill='black', font=font)
    result = io.BytesIO()
    image.save(result, 'PNG')
    return result.getvalue()


if __name__ == '__main__':
    try:
        result = read([synthetic()])
        print(json.dumps(result, ensure_ascii=False, indent=2))
        assert result['parts'].get('kaput') == 'boyali'
        assert result['parts'].get('solOnKapi') == 'degisen'
        assert 'sagOnKapi' not in result['parts']
        assert 'sagOnKapi' in result['okunamayan_alanlar']
        assert result['tramer_amount'] == 125000
        assert result['tramer_count'] == 2
        assert any(x['ciddiyet'] == 'ciddi' for x in result['bulgular'])
    except PhotoError as error:
        print(str(error))
        raise SystemExit(1) from None
