"""Arşivdeki anlık görüntüden Türkçe araç değerleme PDF'i (ilan/beyan + internet ilanları)."""
import io
from pathlib import Path
from datetime import datetime
from zoneinfo import ZoneInfo

from fpdf import FPDF
from fpdf.fonts import FontFace

from yerimebak_ai_v5.services.stamp_service import font_paths, seal_png
from yerimebak_ai_v5.services.vehicle_risk import GENEL_BAKIM_KONTROLU

DISCLAIMER = 'Bu rapor ilan/müşteri beyanına ve internetteki ilanlara dayanır; uzman incelemesi değildir.'


TITLE = 'Araç değerleme raporu'
GUVEN = {'yuksek': 'Yüksek', 'orta': 'Orta', 'dusuk': 'Düşük'}
SEAL_TITLE = 'YERİMEBAK DEĞERLEME'
BRAND = (14, 74, 120)
INK = (27, 45, 61)
MUTED = (88, 105, 121)
LIGHT = (245, 248, 251)
RULE = (217, 227, 235)


def _money(value):
    return f'{value:,.0f} TL'.replace(',', '.') if isinstance(value, (float, int)) else '—'


def _num(value):
    """24000 -> '24.000' (Türkçe binlik)."""
    return f'{value:,.0f}'.replace(',', '.') if isinstance(value, (float, int)) else '—'


def _pct(value, digits=1):
    """1.84 -> '%1,8' (Türkçe ondalık virgül)."""
    return ('%' + f'{value:.{digits}f}'.replace('.', ',')) if isinstance(value, (float, int)) else '—'


class ValuationPDF(FPDF):
    verification_code = ''

    def header(self):
        if self.page_no() > 1:
            self.set_font('Report', size=8)
            self.set_text_color(*MUTED)
            self.set_xy(self.l_margin, 9)
            self.cell(0, 4, 'YERİMEBAK  /  '+TITLE)
            self.set_draw_color(*RULE)
            self.line(self.l_margin, 15, self.w-self.r_margin, 15)
            self.set_y(21)

    def footer(self):
        self.set_draw_color(*RULE)
        self.line(self.l_margin, self.h-17, self.w-self.r_margin, self.h-17)
        self.set_y(-14)
        self.set_font('Report', size=7.5)
        self.set_text_color(*MUTED)
        self.cell(0, 6, f'YerimeBak araç değerleme raporu • sayfa {self.page_no()}/{{nb}} • {self.verification_code}', align='C')


def build_pdf(report):
    pdf = ValuationPDF()
    pdf.verification_code = report['rapor']['verification_code']
    for style, bold in (('', False), ('B', True)):
        path = next((p for p in font_paths(bold) if Path(p).is_file()), None)
        if not path:
            raise RuntimeError('Türkçe PDF için DejaVuSans veya Arial yazı tipi gerekli')
        pdf.add_font('Report', style=style, fname=path)
    pdf.set_margins(18, 18, 18)
    pdf.set_auto_page_break(True, margin=22)
    pdf.alias_nb_pages()
    pdf.set_title(TITLE)
    pdf.add_page()

    def clean(value):
        return ''.join(c for c in str(value if value is not None else '—') if c in '\n\t' or ord(c) >= 32)

    def measure(value, bold=False, size=9.5, width=None, line_height=5):
        pdf.set_font('Report', 'B' if bold else '', size=size)
        return pdf.multi_cell(width or pdf.epw, line_height, clean(value), dry_run=True, output='HEIGHT')

    def ensure(height):
        if pdf.get_y()+height > pdf.h-pdf.b_margin and height <= pdf.h-pdf.t_margin-pdf.b_margin:
            pdf.add_page()

    def text(value, bold=False, size=9.5, color=INK, width=None, x=None, line_height=5, link=None):
        pdf.set_font('Report', 'B' if bold else '', size=size)
        pdf.set_text_color(*color)
        pdf.set_x(pdf.l_margin if x is None else x)
        # Müşteri/ilan metnindeki denetim karakterlerini PDF komutu olarak yorumlama.
        pdf.multi_cell(width or pdf.epw, line_height, clean(value), new_x='LMARGIN', new_y='NEXT',
                       align='L', wrapmode='CHAR' if link else 'WORD', link=link or '')

    def heading(label):
        ensure(48)
        pdf.ln(5)
        text(label, True, 12, BRAND, line_height=6)
        pdf.set_draw_color(*RULE)
        pdf.line(pdf.l_margin, pdf.get_y()+1, pdf.w-pdf.r_margin, pdf.get_y()+1)
        pdf.ln(3)

    def bullet(value, index=None):
        indent = 8 if index is not None else 6
        ensure(measure(value, width=pdf.epw-indent)+1)
        top = pdf.get_y()
        text(f'{index}.' if index is not None else '•', size=9, color=BRAND, width=indent)
        pdf.set_y(top)
        text(value, width=pdf.epw-indent, x=pdf.l_margin+indent)
        pdf.ln(1)

    def panel(label, body, fill=LIGHT, accent=BRAND, badge=False):
        # Gerçekten uzun metinlerde her sayfaya sığan ayrı bir kutu çizilir.
        pdf.set_font('Report', size=9.5)
        lines = pdf.multi_cell(pdf.epw-10, 5, clean(body), dry_run=True, output='LINES')
        first = True
        while lines:
            ensure(32)
            available = int((pdf.h-pdf.b_margin-pdf.get_y()-20)//5)
            count = max(1, min(len(lines), available))
            chunk, lines = lines[:count], lines[count:]
            height = 18+5*len(chunk)
            top = pdf.get_y()
            pdf.set_fill_color(*fill)
            pdf.rect(pdf.l_margin, top, pdf.epw, height, style='F')
            pdf.set_fill_color(*accent)
            pdf.rect(pdf.l_margin, top, 1, height, style='F')
            pdf.set_y(top+4)
            if badge and first:
                pdf.set_font('Report', 'B', size=9)
                badge_width = min(pdf.epw-10, pdf.get_string_width(clean(label))+8)
                pdf.rect(pdf.l_margin+4, top+3, badge_width, 7, style='F')
                text(label, True, 9, (255, 255, 255), width=badge_width-4, x=pdf.l_margin+6, line_height=5)
            else:
                text(label if first else label+' (devam)', True, 10, accent, width=pdf.epw-10, x=pdf.l_margin+5)
            pdf.set_y(top+11)
            text('\n'.join(chunk), width=pdf.epw-10, x=pdf.l_margin+5)
            pdf.set_y(top+height+4)
            first = False
            if lines:
                pdf.add_page()

    def cards(items, note=None, sizes=None):
        gap, height = 4, 34 if note else 27
        width = (pdf.epw-gap*(len(items)-1))/len(items)
        ensure(height+6)
        top, left = pdf.get_y(), pdf.l_margin
        for index, (label, value) in enumerate(items):
            x = left+index*(width+gap)
            pdf.set_fill_color(*LIGHT)
            pdf.set_draw_color(*RULE)
            pdf.rect(x, top, width, height, style='DF')
            pdf.set_fill_color(*BRAND)
            pdf.rect(x, top, width, .8, style='F')
            pdf.set_y(top+4)
            text(label, True, 8, MUTED, width=width-8, x=x+4, line_height=4)
            pdf.set_y(top+13)
            size = sizes[index] if sizes else 15
            text(value, True, size, BRAND, width=width-8, x=x+4, line_height=6)
            if note and index == len(items)-1:
                pdf.set_y(top+24)
                text(note, size=7.5, color=MUTED, width=width-8, x=x+4, line_height=3.5)
        pdf.set_y(top+height+4)

    def table(headers, rows, widths, align):
        ensure(26)
        pdf.set_x(pdf.l_margin)
        pdf.set_font('Report', size=9)
        pdf.set_text_color(*INK)
        pdf.set_draw_color(*RULE)
        pdf.set_fill_color(255, 255, 255)
        with pdf.table(col_widths=widths, line_height=5, padding=2,
                       text_align=align, align='LEFT', borders_layout='HORIZONTAL_LINES',
                       headings_style=FontFace(emphasis='BOLD', color=(255, 255, 255), fill_color=BRAND),
                       cell_fill_color=LIGHT, cell_fill_mode='ROWS') as grid:
            for values in [headers]+rows:
                row = grid.row()
                for value in values:
                    row.cell(clean(value))
        pdf.ln(3)

    def source_links(sources):
        for source in sources or []:
            source = str(source)
            text(source, size=8, color=MUTED, line_height=4,
                 link=source if source.startswith(('https://', 'http://')) else None)

    def risk_details(item):
        ensure(36)
        text(item.get('baslik'), True)
        text(item.get('aciklama'))
        if item.get('etkiledigi'):
            text('Etkilediği sürümler: '+item['etkiledigi'])
        if item.get('belirtiler'):
            text('Belirtiler: '+'; '.join(item['belirtiler']))
        text('Nasıl kontrol edilir: '+str(item.get('kontrol') or 'Servis kayıtlarıyla doğrulayın.'))
        if item.get('guven') == 'yuksek':
            text('Resmi kaynak (geri çağırma / servis bülteni)')
        cost = item.get('tahminiMaliyet')
        text('Maliyet: '+(f'{_money(cost.get("min"))} - {_money(cost.get("max"))}'
                          if isinstance(cost, dict) else 'kaynakta belirtilmemiş'))
        source_links(item.get('kaynaklar'))
        pdf.ln(4)

    vehicle, decision = report['arac'], report['karar']
    valuation, market = report['degerleme'], report['piyasa']
    identity = report['rapor']
    date = datetime.fromisoformat(identity['created_at'].replace('Z', '+00:00')).astimezone(ZoneInfo('Europe/Istanbul')).strftime('%d.%m.%Y')
    top = pdf.get_y()
    logo = Path(__file__).resolve().parents[1]/'assets'/'yerimebak_mark.png'
    pdf.image(str(logo), x=pdf.l_margin, y=top, w=12, h=12)
    text('YERİMEBAK', True, 9, BRAND, width=pdf.epw-18, x=pdf.l_margin+18, line_height=4)
    text(TITLE, True, 19, width=pdf.epw-18, x=pdf.l_margin+18, line_height=8)
    pdf.set_y(max(pdf.get_y(), top+14)+5)
    text(f'{vehicle["marka"]} {vehicle["model"]} {vehicle["yil"]}' + (f' • {vehicle["paket"]}' if vehicle.get('paket') else ''), True, 15, line_height=7)
    text(f'{date} • {_num(vehicle.get("km"))} km • {vehicle.get("yakit") or "—"} • {vehicle.get("vites") or "—"}'
         + (f' • İlan fiyatı {_money(vehicle.get("ilanFiyati"))}' if vehicle.get('ilanFiyati') else ''))
    text('Uzman incelemesi içermez. İlan/müşteri beyanına dayalı hesaplama.', size=8.5, color=MUTED)
    heading('Karar ve veri güveni')
    verdict = decision.get('sonuc') or '—'
    verdict_colors = {'AL': ((237, 248, 240), (25, 111, 69)),
                      'PAZARLIK YAP': ((255, 246, 231), (170, 94, 13)),
                      'ALMA': ((255, 239, 239), (168, 38, 43))}
    fill, accent = verdict_colors.get(verdict, ((241, 246, 250), BRAND))
    decision_text = f'Veri güveni: {GUVEN.get(decision.get("guvenSeviyesi"), "—")} • Skor: %{market.get("guvenSkoru", 0)}\n'+str(decision.get('aciklama') or '—')
    if decision.get('hesaplananEgilim'):
        decision_text += '\nHesaplanan eğilim (kesin karar değildir): '+decision['hesaplananEgilim']
    panel(verdict, decision_text, fill, accent, badge=True)
    summary = report.get('ozet') or {}
    heading('Fiyatlar')
    fair = valuation.get('adilFiyatAraligi') or {}
    cards([('Adil fiyat aralığı', _money(fair.get('min'))+' -\n'+_money(fair.get('max'))),
           ('Tavsiye alım fiyatı', _money(valuation.get('tavsiyeFiyat'))),
           ('İlan fiyatı', _money(vehicle.get('ilanFiyati')))],
          note=(summary.get('piyasaKonumu') or {}).get('metin'), sizes=[12, 16, 16])
    text('Hasarsız piyasa değeri: '+_money(valuation.get('temizPiyasaDegeri')), size=9, color=MUTED)
    heading('Özet — beş cevap')
    fair = summary.get('adilFiyat') or {}
    for label, value in (
        ('Piyasaya göre fiyatı', (summary.get('piyasaKonumu') or {}).get('metin')),
        ('Adil fiyat', f'{_money(fair.get("min"))} – {_money(fair.get("max"))}'),
        ('En önemli riskler', summary.get('riskler') or []),
        ('Pazarlık gerekçeleri', summary.get('pazarlikGerekceleri') or []),
        ('Şimdi ne yapmalı?', summary.get('simdiNeYapmali')),
    ):
        body_height = sum(measure(item, width=pdf.epw-6)+1 for item in value) if isinstance(value, list) else measure(value)
        ensure(measure(label, True)+body_height+2)
        text(label, True)
        if isinstance(value, list):
            for item in value:
                bullet(item)
            if not value:
                text('Belirtilmedi')
        else:
            text(value)
        pdf.ln(1)
    plan = report.get('pazarlikPlani')
    if plan:
        ensure(65)
        heading('Pazarlık planı')
        cards([('Açılış teklifi:', _money(plan.get('acilisTeklifi'))),
               ('Hedef fiyat:', _money(plan.get('hedefFiyat'))),
               ('Üst sınır:', _money(plan.get('ustSinir')))])
        text('Potansiyel kazanç: '+_money(plan.get('potansiyelKazanc')), True)
        if plan.get('uyari'):
            text(plan['uyari'])
        text('Adımlar', True)
        for index, step in enumerate(plan.get('adimlar') or [], 1):
            bullet(step, index)
        text('Gerekçeler', True)
        for reason in plan.get('gerekceler') or []:
            bullet(reason)
        text('Benzer ilanlar tablosuna bakın.', size=8.5, color=MUTED)
        if plan.get('saticiMesaji'):
            panel('Satıcıya mesaj', plan['saticiMesaji'])
    if 'modelRiskleri' in report:
        heading('Modelin bilinen sorunları')
        risks = report.get('modelRiskleri') or {}
        text('Bu başlıklar arıza teşhisi değildir; araç sürümü, şasi numarası ve servis kayıtlarıyla doğrulayın.')
        # Eski kayıtlarda düşük güvenli maddeler olabilir; müşteriye gösterilmez.
        shown = [r for r in risks.get('riskler') or [] if r.get('guven') in ('yuksek', 'orta')]
        for item in shown:
            risk_details(item)
        if not shown:
            text(risks.get('mesaj') or 'Bu model/motor için kaynağı doğrulanmış bilinen sorun bulunamadı.')
    if 'bakim' in report:
        heading('Bu kilometrede doğrulanacak bakımlar')
        # Açıklama her maddede aynı: bir kez yazılır, maddeler kısa liste olur.
        text(f'{_num(vehicle.get("km"))} km ve {vehicle.get("yil")} model araç için aşağıdaki işlemlerin son yapıldığı '
             'tarih ve kilometreyi servis faturalarından kontrol edin; üreticinin araç sürümüne özel bakım planını esas alın.')
        for item in report.get('bakim') or []:
            specific = item.get('kontrol') and item['kontrol'] != GENEL_BAKIM_KONTROLU
            bullet(str(item.get('baslik'))+(f' (kontrol: {item["kontrol"]})' if specific else ''))
    if 'saticiSorulari' in report:
        heading('Satıcıya sorulacak sorular')
        for index, question in enumerate(report.get('saticiSorulari') or [], 1):
            bullet(question, index)
    heading('Bu aracı YerimeBak ile yerinde inceletin')
    text('Satın almadan önce ilan beyanlarını ve bakım geçmişini yerinde uzman incelemesiyle doğrulatın. Ekspertiz talebi oluşturun:')
    text('https://www.yerimebak.com.tr/ekspertiz-talebi')
    heading('Değer kaybı tablosu')
    table(('Kalem', 'Durum', 'Yüzde', 'Tutar'), [
            (str(k.get('baslik') or '—'), str(k.get('durum') or '—'), _pct(k.get('yuzde', 0), 2), _money(k.get('tutar')))
            for k in valuation.get('kalemler') or []], (3, 2, 1, 2), ('LEFT', 'LEFT', 'RIGHT', 'RIGHT'))
    text(f'Toplam kayıp: {_pct(valuation.get("toplamDegerKaybiYuzde", 0), 2)} • {_money(valuation.get("toplamDegerKaybiTutar"))}')
    if valuation.get('ozet'):
        text(valuation['ozet'])
    heading('Benzer ilanlar')
    text(f'{market.get("emsalSayisi", 0)} emsal • Ortalama: {_money(market.get("ortalama"))} • Medyan: {_money(market.get("medyan"))}')
    samples = list(market.get('kaynaklar') or [])
    for sample in (plan or {}).get('kanitIlanlar') or []:
        if sample not in samples and not (sample.get('url') and any(s.get('url') == sample['url'] for s in samples)):
            samples.append(sample)
    table(('Site', 'Yıl', 'Km', 'Fiyat'), [(sample.get('site') or 'Kaynak', str(sample.get('yil') or '—'),
          _num(sample.get('km')), _money(sample.get('fiyat'))) for sample in samples],
          (4, 1.4, 1.8, 2.8), ('LEFT', 'CENTER', 'RIGHT', 'RIGHT'))
    for sample in samples:
        if sample.get('url'):
            text(sample.get('site') or 'Kaynak', True, 8, MUTED, line_height=4)
            source_links([sample['url']])
    for warning in market.get('uyarilar') or []:
        text(warning)
    sources = [source for source in report.get('bilgiKaynaklari') or []
               if source.get('kaynak') != 'tahmin' or report.get('getiri')]
    if sources:
        heading('Bilgi kaynakları')
        for source in sources:
            text(f'{source.get("alan")}: {source.get("aciklama")}')
    projection = report.get('getiri')
    if projection:  # oran girilmemişse bölüm hiç gösterilmez
        heading('Gelecek değer — tahmin')
        text(f'Aylık araç enflasyonu: {_pct(projection.get("aylikEnflasyonYuzde"))} • {projection.get("kaynak") or ""}')
        for key in ('altiAy', 'birYil'):
            horizon = projection.get(key) or {}
            text(f'{horizon.get("ay")} ay: {_money(horizon.get("tahminiDeger"))} • Tahmini getiri: {_money(horizon.get("getiriTl"))} ({_pct(horizon.get("getiriYuzde"))})')
        text(projection.get('aciklama'))
    if pdf.get_y() > pdf.h-132:
        pdf.add_page()
    heading('Dijital doğrulama')
    text(identity['report_no'], True)
    text(identity['verification_code'])
    text('https://www.yerimebak.com.tr/dogrula/'+identity['verification_code'])
    if pdf.get_y() > pdf.h-98:
        pdf.add_page()
    pdf.image(io.BytesIO(seal_png(identity['verification_code'], identity['report_no'], date, SEAL_TITLE)), x=18, y=pdf.get_y(), w=48)
    pdf.ln(52)
    text(DISCLAIMER, size=9)
    return bytes(pdf.output())
