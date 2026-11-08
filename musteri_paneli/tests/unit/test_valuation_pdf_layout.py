"""PDF görsel yerleşimi: kapak kartları, bütün içerik ve sayfa sınırları."""
from copy import deepcopy
import io

import pdfplumber
import pytest

from yerimebak_ai_v5.services.valuation_report_pdf import build_pdf


def tucson_report(risk_count=0):
    url = 'https://teknik.example.test/arac/' + 'uzun-adres-'*110
    return {
        'arac': {'marka': 'Hyundai', 'model': 'Tucson', 'paket': '1.6 CRDI Elite Plus', 'yil': 2021,
                 'km': 66000, 'yakit': 'Dizel', 'vites': 'Otomatik', 'ilanFiyati': 2200000},
        'karar': {'sonuc': 'EK DOĞRULAMA GEREKLİ', 'aciklama': 'İlan bilgilerini ve aracı uzman incelemesiyle doğrulayın.',
                  'guvenSeviyesi': 'dusuk', 'hesaplananEgilim': 'ALMA'},
        'degerleme': {'temizPiyasaDegeri': 2035190, 'tavsiyeFiyat': 1935000,
                      'adilFiyatAraligi': {'min': 1815000, 'max': 2175000},
                      'kalemler': [{'baslik': 'Sol Arka Çamurluk', 'durum': 'Lokal Boyalı', 'yuzde': .6, 'tutar': 12181}]},
        'piyasa': {'guvenSkoru': 35, 'emsalSayisi': 3, 'ortalama': 2150000, 'medyan': 2150000,
                   'kaynaklar': [{'site': 'Örnek otomotiv', 'yil': 2022, 'km': 83000, 'fiyat': 2119500, 'url': url}]},
        'ozet': {'adilFiyat': {'min': 1815000, 'max': 2175000}, 'piyasaKonumu': {'metin': 'Piyasanın üstünde'},
                 'riskler': ['Boya bilgisi müşteri beyanıdır.'], 'pazarlikGerekceleri': ['Benzer üç ilanın fiyatları.'],
                 'simdiNeYapmali': 'Uzman incelemesi isteyin.'},
        'pazarlikPlani': {'acilisTeklifi': 1875000, 'hedefFiyat': 1935000, 'ustSinir': 2175000,
                          'potansiyelKazanc': 265000, 'adimlar': ['Teklifinizi gerekçeleriyle iletin.'],
                          'gerekceler': ['Sağ ön çamurluk boyalı.'], 'kanitIlanlar': [],
                          'saticiMesaji': 'Merhaba, aracınız için 1.875.000 TL teklif etmek istiyorum. Şasi ve bakım belgelerini paylaşır mısınız?'},
        'modelRiskleri': {'riskler': [{'baslik': f'Şanzıman kontrolü {n}', 'guven': 'orta',
                                      'aciklama': 'Şüpheli belirtileri servis kayıtları ve yol testiyle doğrulayın. '*3,
                                      'etkiledigi': 'Araç sürümünü şasi numarasıyla doğrulayın.',
                                      'belirtiler': ['Kalkışta sarsıntı'], 'kontrol': 'Uzmanla yol testi yapın.',
                                      'kaynaklar': [url]} for n in range(risk_count)]},
        'bakim': [{'baslik': 'Periyodik bakım kayıtları', 'kontrol': 'Servis faturalarını karşılaştırın.'}],
        'saticiSorulari': ['Ekspertize izin veriyor musunuz?', 'Bakım geçmişini paylaşır mısınız?'],
        'rapor': {'report_no': 'YD 2026-000011', 'created_at': '2026-11-02T10:00:00+00:00',
                  'verification_code': 'YD-ABCD-2345'},
    }


def test_cover_has_logo_and_three_large_price_cards_without_decision():
    report = tucson_report()
    unchanged = deepcopy(report)
    with pdfplumber.open(io.BytesIO(build_pdf(report))) as document:
        first = document.pages[0]
        assert first.images, 'Marka logosu ilk sayfada olmalı'
        assert len(first.rects) >= 3, 'Üç fiyat kartı olmalı'
        text = first.extract_text()
        for value in ('Araç değerleme raporu', 'Hyundai Tucson 2021', '1.6 CRDI Elite Plus',
                      'Adil fiyat aralığı', 'Tavsiye alım fiyatı', 'İlan fiyatı'):
            assert value in text
        words = first.extract_words(extra_attrs=['size'])
        prices = [next(word for word in words if word['text'] == price and word['size'] >= 12)
                  for price in ('1.815.000', '1.935.000', '2.200.000')]
        assert max(word['top'] for word in prices)-min(word['top'] for word in prices) < 18
    assert report == unchanged


def pdf_text(report):
    with pdfplumber.open(io.BytesIO(build_pdf(report))) as document:
        return '\n'.join(page.extract_text() for page in document.pages)


def test_decision_data_is_preserved_but_never_exposed():
    report = tucson_report()
    report['karar']['aciklama'] = 'YALNIZ ADMIN KARAR AÇIKLAMASI'
    text = pdf_text(report)
    for hidden in ('Karar ve veri güveni', 'Veri güveni', 'Skor', 'Hesaplanan eğilim', 'EK DOĞRULAMA', 'YALNIZ ADMIN'):
        assert hidden not in text
    assert 'Şimdi ne yapmalı?' in text


@pytest.mark.parametrize('count', [2, 3, 4, 5, 8])
def test_small_comparable_count_note_only_for_three_or_four(count):
    report = tucson_report()
    report['piyasa']['emsalSayisi'] = count
    legacy_warning = f'Yalnızca {count} doğrulanmış emsal ilan bulundu (hedef 5)'
    report['piyasa']['uyarilar'] = [legacy_warning, 'Fiyat aralığı geniş; ilanları karşılaştırın.']
    report['ozet']['riskler'].append(legacy_warning+'.')
    unchanged = deepcopy(report)
    text = pdf_text(report)
    note = f"{count} benzer ilan bulundu; 5'ten az olduğu için fiyatlar yön göstericidir."
    assert (note in text) == (count in (3, 4))
    assert (legacy_warning in text) == (count not in (3, 4))
    assert 'Fiyat aralığı geniş; ilanları karşılaştırın.' in text
    assert report == unchanged


@pytest.mark.parametrize('complaints', [None, [], [{'baslik': 'Vites geçişi', 'aciklama': 'Kullanıcılar sarsıntı bildiriyor.', 'kaynakSayisi': 2, 'kaynaklar': ['https://forum-a.example/tucson', 'https://forum-b.example/tucson']}]])
def test_complaints_optional_empty_and_populated(complaints):
    report = tucson_report()
    if complaints is not None:
        report['kullaniciSikayetleri'] = complaints
    text = pdf_text(report)
    title = 'Kullanıcıların en sık şikâyet ettiği konular'
    assert (title in text) == (complaints is not None)
    if complaints is not None:
        assert 'Forum ve kullanıcı yorumlarından derlenmiştir; kullanıcı beyanıdır, arıza teşhisi değildir.' in text
        if complaints:
            assert 'Vites geçişi' in text and 'Kullanıcılar sarsıntı bildiriyor.' in text
            assert '2 farklı kaynakta geçiyor' in text
            assert 'https://forum-a.example/tucson' in text
        else:
            assert 'Birden fazla kaynakta tekrarlanan kullanıcı şikâyeti bulunamadı.' in text


@pytest.mark.parametrize('risk_count', [0, 25])
def test_normal_and_long_report_keep_all_text_inside_page_and_footer(risk_count):
    content = build_pdf(tucson_report(risk_count))
    assert content.startswith(b'%PDF')
    with pdfplumber.open(io.BytesIO(content)) as document:
        combined = '\n'.join(page.extract_text() or '' for page in document.pages)
        assert 'Satıcıya gönderilecek mesaj' in combined and 'Pazarlık planı' in combined  # ayrı bölüm (09.11.2026)
        assert 'Şasi ve bakım belgelerini paylaşır mısınız?' in combined
        assert 'Açılış teklifi:' in combined and '1.875.000 TL' in combined
        if risk_count:
            assert 'Şanzıman kontrolü 24' in combined
        for page in document.pages:
            text = page.extract_text()
            assert 'YerimeBak araç değerleme raporu' in text and 'sayfa' in text and 'YD-ABCD-2345' in text
            assert all(0 <= char['x0'] < char['x1'] <= page.width+1 for char in page.chars)
            assert all(0 <= char['top'] < char['bottom'] <= page.height for char in page.chars)


def test_two_digit_question_number_stays_with_its_text():
    report = tucson_report()
    report['saticiSorulari'] = [f'Soru {n}: Servis kayıtlarını paylaşır mısınız?' for n in range(1, 12)]
    with pdfplumber.open(io.BytesIO(build_pdf(report))) as document:
        text = '\n'.join(page.extract_text() for page in document.pages)
        assert '10. Soru 10:' in text
        assert '11. Soru 11:' in text


def test_no_empty_information_sources_heading():
    with pdfplumber.open(io.BytesIO(build_pdf(tucson_report()))) as document:
        assert 'Bilgi kaynakları' not in '\n'.join(page.extract_text() for page in document.pages)


GROUPS = ('Mekanik ve motor', 'Elektronik ve sensör', 'Trim, şasi ve kasa')
CTA = 'YerimeBak uzmanı bunu yerinde kontrol eder.'
CRITICAL = 'Bu araçta en çok dikkat etmeniz gerekenler'


def issue(title, category='mekanik_motor', importance='yuksek', **extra):
    return {'baslik': title, 'aciklama': 'Kontrol açıklaması.', 'kategori': category,
            'onem': importance, 'guven': 'orta', 'kaynaklar': [], **extra}


def test_issue_groups_order_severity_and_immutable_input():
    report = tucson_report()
    items = [issue('Trim düşük', 'trim_kasa', 'dusuk'),
             issue('Motor düşük', importance='dusuk'), issue('Motor yüksek'),
             issue('Sensör orta', 'elektronik', 'orta')]
    report['modelRiskleri']['riskler'] = items
    report['kullaniciSikayetleri'] = deepcopy(items)
    unchanged = deepcopy(report)
    text = pdf_text(report)
    for section in (text.split('Modelin bilinen sorunları')[1].split('Kullanıcıların en sık')[0],
                    text.split('Kullanıcıların en sık şikâyet ettiği konular')[1].split('Bu kilometrede')[0]):
        assert section.index(GROUPS[0]) < section.index(GROUPS[1]) < section.index(GROUPS[2])
        assert section.index('Motor yüksek') < section.index('Motor düşük')
        assert all(label in section for label in ('Yüksek masraf', 'Orta', 'Küçük / konfor'))
    assert report == unchanged


def test_critical_box_prefers_verified_risk_then_most_sourced_complaint_and_caps_cta():
    report = tucson_report()
    report['modelRiskleri']['riskler'] = [issue('Düşük güven gizli', guven='dusuk'), issue('Doğrulanmış motor')]
    report['kullaniciSikayetleri'] = [issue('Az kaynak', kaynakSayisi=2),
                                     issue('En çok kaynak', kaynakSayisi=7), issue('İkinci kaynak', kaynakSayisi=5)]
    text = pdf_text(report)
    critical = text.split(CRITICAL)[1].split('Mekanik ve motor')[0]
    assert critical.index('Doğrulanmış motor') < critical.index('En çok kaynak')
    assert 'Az kaynak' not in critical and 'İkinci kaynak' not in critical
    assert 'Düşük güven gizli' not in text
    assert CTA not in critical
    assert text.count(CTA) == 3


@pytest.mark.parametrize('importance', [None, 'orta', 'dusuk'])
def test_no_high_issue_means_no_critical_box_or_expert_line(importance):
    report = tucson_report()
    item = issue('Motor kontrolü', importance=importance)
    report['modelRiskleri']['riskler'] = [item]
    report['kullaniciSikayetleri'] = [deepcopy(item)]
    text = pdf_text(report)
    assert CRITICAL not in text and CTA not in text
    assert GROUPS[0] in text and GROUPS[1] not in text and GROUPS[2] not in text
    if importance is None:
        assert 'Yüksek masraf' not in text and 'Küçük / konfor' not in text


@pytest.mark.parametrize('partial', [False, True])
def test_legacy_or_partial_category_list_stays_flat_without_losing_items(partial):
    report = tucson_report()
    items = [issue('Birinci'), issue('İkinci', 'elektronik')]
    items[0].pop('kategori')
    if not partial:
        items[1].pop('kategori')
    for item in items:
        item.pop('onem')
    report['modelRiskleri']['riskler'] = deepcopy(items)
    report['kullaniciSikayetleri'] = deepcopy(items)
    text = pdf_text(report)
    assert all(group not in text for group in GROUPS)
    assert text.count('Birinci') == 2 and text.count('İkinci') == 2
    assert CRITICAL not in text and CTA not in text


@pytest.mark.parametrize('model_count', [0, 1, 3])
def test_critical_box_has_at_most_two_items_with_model_priority(model_count):
    report = tucson_report()
    report['modelRiskleri']['riskler'] = [issue(f'Model öncelik {n}') for n in range(model_count)]
    report['kullaniciSikayetleri'] = [issue('Şikâyet az', kaynakSayisi=2),
                                     issue('Şikâyet çok', kaynakSayisi=9)]
    with pdfplumber.open(io.BytesIO(build_pdf(report))) as document:
        text = '\n'.join(page.extract_text() for page in document.pages)
        critical = text.split(CRITICAL)[1].split('Modelin bilinen sorunları')[0]
        assert critical.count('1. ') == 1 and critical.count('2. ') == 1
        assert '3. ' not in critical and CTA not in critical
        if model_count:
            assert 'Model öncelik 0' in critical
        if model_count >= 2:
            assert 'Şikâyet çok' not in critical and 'Model öncelik 1' in critical
        else:
            assert 'Şikâyet çok' in critical
        # Uzman çağrısı kaynak URL'sinden bağımsız düz metindir.
        for page in document.pages:
            for link in page.hyperlinks:
                assert CTA not in (link.get('uri') or '')
