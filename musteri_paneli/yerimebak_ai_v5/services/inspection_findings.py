"""Müşterinin onayladığı rapor bulguları; fiyat/kayıp hesabına müdahale etmez."""
from yerimebak_ai_v5.services.inspection_photo import normalize


def enrich_report(report, payload):
    if payload.get('kaynak_turu') != 'ekspertiz_raporu':
        return
    data = normalize({'bulgular': payload.get('bulgular'),
                      'firma_adi': payload.get('ekspertiz_firma_adi'),
                      'rapor_tarihi': payload.get('ekspertiz_rapor_tarihi')})
    metadata = ', '.join(x for x in (data['firma_adi'], data['rapor_tarihi']) if x)
    description = 'Ekspertiz raporu' + (f' ({metadata})' if metadata else '') + ' — YerimeBak uzmanı tarafından doğrulanmadı'
    source = {'alan': 'Boya, değişen ve tramer', 'kaynak': 'ekspertiz_raporu', 'aciklama': description}
    sources = report.setdefault('bilgiKaynaklari', [])
    sources[:] = [source if x.get('alan') == source['alan'] else x for x in sources]
    if not any(x.get('kaynak') == 'ekspertiz_raporu' for x in sources):
        sources.append(source)
    report['ekspertizRaporu'] = {'firmaAdi': data['firma_adi'], 'raporTarihi': data['rapor_tarihi'],
                                'bulgular': data['bulgular'], 'aciklama': description}
    summary = report.setdefault('ozet', {})
    serious = [x['metin'] for x in data['bulgular'] if x['ciddiyet'] == 'ciddi']
    cosmetic = ['Ekspertiz raporunda: ' + x['metin'] for x in data['bulgular'] if x['ciddiyet'] == 'pazarlik']
    if serious:
        summary['riskler'] = (['Ekspertiz raporunda ciddi bulgu: ' + x for x in serious]
                              + list(summary.get('riskler') or []))[:4]
        summary['simdiNeYapmali'] = ('Önce ekspertiz raporundaki ciddi bulguyu yerinde doğrulatın: '
                                     + '; '.join(serious) + '. Ödeme veya kapora göndermeden önce uzman görüşü alın.')
    plan = report.get('pazarlikPlani')
    if plan is not None:
        plan['gerekceler'] = cosmetic + list(plan.get('gerekceler') or [])
        summary['pazarlikGerekceleri'] = plan['gerekceler'][:3]
    else:
        summary['pazarlikGerekceleri'] = (cosmetic + list(summary.get('pazarlikGerekceleri') or []))[:3]
