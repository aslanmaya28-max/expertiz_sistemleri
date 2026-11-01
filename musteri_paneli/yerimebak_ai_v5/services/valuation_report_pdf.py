"""Arşivdeki anlık görüntüden Türkçe kredili değerleme PDF'i."""
import io
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo

from fpdf import FPDF

from yerimebak_ai_v5.services.stamp_service import font_paths, seal_png

DISCLAIMER = 'Bu rapor ilan/müşteri beyanına ve internetteki ilanlara dayanır; uzman incelemesi değildir.'


def _money(value):
    return f'{value:,.0f} TL'.replace(',', '.') if isinstance(value, (float, int)) else '—'


class ValuationPDF(FPDF):
    def footer(self):
        self.set_y(-14)
        self.set_font('Report', size=8)
        self.set_text_color(85, 95, 105)
        self.cell(0, 6, f'Kredili değerleme • {self.page_no()}/{{nb}}', align='C')


def build_pdf(report):
    pdf = ValuationPDF()
    for style, bold in (('', False), ('B', True)):
        path = next((p for p in font_paths(bold) if Path(p).is_file()), None)
        if not path:
            raise RuntimeError('Türkçe PDF için DejaVuSans veya Arial yazı tipi gerekli')
        pdf.add_font('Report', style=style, fname=path)
    pdf.set_margins(18, 18, 18)
    pdf.set_auto_page_break(True, margin=22)
    pdf.alias_nb_pages()
    pdf.set_title('Kredili değerleme raporu')
    pdf.add_page()

    def text(value, bold=False, size=10):
        pdf.set_font('Report', 'B' if bold else '', size=size)
        pdf.set_text_color(22, 45, 62)
        # Müşteri/ilan metnindeki denetim karakterlerini PDF komutu olarak yorumlama.
        value = ''.join(c for c in str(value if value is not None else '—') if c in '\n\t' or ord(c) >= 32)
        pdf.multi_cell(0, 6, value, new_x='LMARGIN', new_y='NEXT')

    def heading(label):
        pdf.ln(4)
        if pdf.get_y() > pdf.h-44:
            pdf.add_page()
        text(label, True, 13)

    vehicle, decision = report['arac'], report['karar']
    valuation, market = report['degerleme'], report['piyasa']
    identity = report['rapor']
    date = datetime.fromisoformat(identity['created_at'].replace('Z', '+00:00')).astimezone(ZoneInfo('Europe/Istanbul')).strftime('%d.%m.%Y')
    text('YERİMEBAK', True, 20)
    text('Kredili değerleme raporu', True, 17)
    text(f'{vehicle["marka"]} {vehicle["model"]} {vehicle["yil"]}', True, 14)
    text(f'{date} • {vehicle.get("km")} km • {vehicle.get("yakit") or "—"} • {vehicle.get("vites") or "—"}')
    text('Uzman incelemesi içermez. İlan/müşteri beyanına dayalı hesaplama.')
    heading('Karar ve veri güveni')
    text(decision.get('sonuc'), True)
    text(decision.get('aciklama'))
    text(f'Güven seviyesi: {decision.get("guvenSeviyesi", "—")} • Skor: %{market.get("guvenSkoru", 0)}')
    if decision.get('hesaplananEgilim'):
        text('Hesaplanan eğilim (kesin karar değildir): '+decision['hesaplananEgilim'])
    heading('Özet — beş cevap')
    summary = report.get('ozet') or {}
    fair = summary.get('adilFiyat') or {}
    for label, value in (
        ('Piyasaya göre fiyatı', (summary.get('piyasaKonumu') or {}).get('metin')),
        ('Adil fiyat', f'{_money(fair.get("min"))} – {_money(fair.get("max"))}'),
        ('En önemli riskler', '; '.join(summary.get('riskler') or []) or 'Belirtilmedi'),
        ('Pazarlık gerekçeleri', '; '.join(summary.get('pazarlikGerekceleri') or []) or 'Belirtilmedi'),
        ('Şimdi ne yapmalı?', summary.get('simdiNeYapmali')),
    ):
        text(label, True)
        text(value)
    heading('Fiyatlar')
    fair = valuation.get('adilFiyatAraligi') or {}
    text('İlan fiyatı: '+_money(vehicle.get('ilanFiyati')))
    text(f'Adil fiyat aralığı: {_money(fair.get("min"))} – {_money(fair.get("max"))}')
    text('Tavsiye alım fiyatı: '+_money(valuation.get('tavsiyeFiyat')))
    text('Hasarsız piyasa değeri: '+_money(valuation.get('temizPiyasaDegeri')))
    heading('Değer kaybı tablosu')
    pdf.set_font('Report', size=9)
    with pdf.table(col_widths=(3, 2, 1, 2), line_height=6, text_align=('LEFT', 'LEFT', 'RIGHT', 'RIGHT')) as table:
        for values in [('Kalem', 'Durum', 'Yüzde', 'Tutar')] + [
            (str(k.get('baslik') or '—'), str(k.get('durum') or '—'), str(k.get('yuzde', 0)), _money(k.get('tutar')))
            for k in valuation.get('kalemler') or []]:
            row = table.row()
            for value in values:
                row.cell(value)
    text(f'Toplam kayıp: %{valuation.get("toplamDegerKaybiYuzde", 0)} • {_money(valuation.get("toplamDegerKaybiTutar"))}')
    if valuation.get('ozet'):
        text(valuation['ozet'])
    heading('Benzer ilanlar')
    text(f'{market.get("emsalSayisi", 0)} emsal • Ortalama: {_money(market.get("ortalama"))} • Medyan: {_money(market.get("medyan"))}')
    for sample in market.get('kaynaklar') or []:
        text(f'{sample.get("site") or "Kaynak"} • {sample.get("yil") or "—"} • {sample.get("km") or "—"} km • {_money(sample.get("fiyat"))}', True)
        text(sample.get('url'))
    for warning in market.get('uyarilar') or []:
        text(warning)
    heading('Bilgi kaynakları')
    for source in report.get('bilgiKaynaklari') or []:
        text(f'{source.get("alan")}: {source.get("aciklama")} ({source.get("kaynak")})')
    heading('Gelecek değer — tahmin')
    projection = report.get('getiri')
    if projection:
        text(f'Aylık araç enflasyonu: %{projection.get("aylikEnflasyonYuzde")} • {projection.get("kaynak") or ""}')
        for key in ('altiAy', 'birYil'):
            horizon = projection.get(key) or {}
            text(f'{horizon.get("ay")} ay: {_money(horizon.get("tahminiDeger"))} • Tahmini getiri: {_money(horizon.get("getiriTl"))} (%{horizon.get("getiriYuzde")})')
        text(projection.get('aciklama'))
    else:
        text('Güncel araç enflasyonu oranı henüz girilmedi.')
    if pdf.get_y() > pdf.h-132:
        pdf.add_page()
    heading('Dijital doğrulama')
    text(identity['report_no'], True)
    text(identity['verification_code'])
    text('https://www.yerimebak.com.tr/dogrula/'+identity['verification_code'])
    if pdf.get_y() > pdf.h-98:
        pdf.add_page()
    pdf.image(io.BytesIO(seal_png(identity['verification_code'], identity['report_no'], date)), x=18, y=pdf.get_y(), w=48)
    pdf.ln(52)
    text(DISCLAIMER, size=9)
    return bytes(pdf.output())
