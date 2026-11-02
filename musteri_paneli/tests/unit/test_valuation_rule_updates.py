"""02.11.2026 değerleme kuralları: oranlar, tramer tabanı ve pazarlık sınırı."""
from datetime import datetime

import pytest

from yerimebak_ai_v5.core.ai.inspection_valuation import age_factor, km_factor, evaluate
from yerimebak_ai_v5.services.negotiation import build_plan


@pytest.mark.parametrize('age,expected', [(3,1), (4,.95), (6,.95), (7,.85), (10,.85), (11,.75)])
def test_age_contract(age, expected):
    assert age_factor(age) == expected


@pytest.mark.parametrize('km,expected', [(60000,1), (60001,.97), (120000,.97), (120001,.9), (200000,.9), (200001,.8)])
def test_km_contract(km, expected):
    assert km_factor(km) == expected


@pytest.mark.parametrize('part,rates', [
    ('onTampon', [.25,.6,1,.15,1.2]),
    ('solOnKapi', [1,2.5,6,.6,2.7]),
    ('solOnCamurluk', [1,2.5,5,.6,2.7]),
    ('solArkaCamurluk', [1,2.7,12,.9,3.3]),
    ('kaput', [1.2,3.5,10,.75,3.75]),
    ('bagajKapagi', [1,2.5,6,.6,2.7]),
    ('tavan', [4.5,12,25,3,7.5]),
])
def test_prescribed_part_rates(part, rates):
    for status, expected in zip(('lokal_boyali','boyali','degisen','sokulup_takilmis','hasarli'), rates):
        result = evaluate({'adim1': {'yil':2026, 'guncelKm':1000},
                           'adim4': {'parcaDurumlari': {part:status}}},
                          {'found':True, 'source':'web_listings', 'count':5,
                           'market_median_price':2_000_000}, now=datetime(2026,11,2))
        assert result['kalemler'][0]['yuzde'] == pytest.approx(expected, abs=.01)


@pytest.mark.parametrize('amount,expected', [(20000,2), (100000,7.5), (2_000_000,50)])
def test_tramer_floor_applies_after_age_km_and_respects_total_cap(amount, expected):
    result = evaluate({'adim1': {'yil':2010, 'guncelKm':250000, 'hasarKayitToplamTutar':amount}},
                      {'found':True, 'source':'web_listings', 'count':5,
                       'market_median_price':2_000_000}, now=datetime(2026,11,2))
    tramer = next(k for k in result['kalemler'] if k['kategori']=='tramer')
    assert tramer['yuzde'] == pytest.approx(expected)
    assert 'Tramerli araç algısı: en az %2 / tutarın 1,5 katı' in tramer['aciklama']
    assert result['toplamDegerKaybiYuzde'] <= 50


@pytest.mark.parametrize('amount,floor', [(500_000,37.5), (2_000_000,50)])
def test_total_cap_preserves_tramer_floor_with_bodywork(amount, floor):
    result = evaluate({'adim1': {'yil':2026, 'guncelKm':1000, 'hasarKayitToplamTutar':amount},
                       'adim4': {'parcaDurumlari': {'tavan':'degisen'}}},
                      {'found':True, 'source':'web_listings', 'count':5,
                       'market_median_price':2_000_000}, now=datetime(2026,11,2))
    tramer = next(k for k in result['kalemler'] if k['kategori']=='tramer')
    assert tramer['yuzde'] >= floor
    assert result['toplamDegerKaybiYuzde'] == 50
    assert sum(k['tutar'] for k in result['kalemler']) == result['toplamDegerKaybiTutar']


@pytest.mark.parametrize('median', [2_150_000, 1_931_234, None])
def test_negotiation_clamps_all_prices_to_unrounded_cap(median):
    ref = {'market_median_price':median, 'count':5}
    result = build_plan(price=2_200_000, fair_min=2_050_000, fair_max=2_175_000,
                        recommended=2_180_000, reference=ref, kalemler=[],
                        confidence_level='yuksek', vehicle_title='2021 Hyundai Tucson')
    cap = min(2_200_000, 2_175_000, median or float('inf'))
    assert result['acilisTeklifi'] <= result['hedefFiyat'] <= result['ustSinir'] == cap
    if median:
        assert any('benzer ilanların orta fiyatı' in s for s in result['gerekceler'])
        assert any('benzer ilanların orta fiyatı' in s for s in result['adimlar'])


def test_tucson_exact_table_with_existing_year_and_km_normalization():
    # Kullanıcı 02.11.2026'da yaklaşık %3–3,5 yerine kesin tablonun %2,92 sonucunu onayladı.
    result = evaluate({'adim1': {'yil':2021, 'guncelKm':66000, 'hasarKayitToplamTutar':20000},
                       'adim4': {'parcaDurumlari': {'solArkaCamurluk':'lokal_boyali'}}},
                      {'found':True, 'source':'web_listings', 'count':3, 'confidence':50,
                       'market_median_price':2_150_000,
                       'reference_median_year':2022, 'reference_median_km':49223},
                      now=datetime(2026,11,2))
    assert result['temizPiyasaDegeri'] == 2_035_190
    assert result['yasKmKatsayisi'] == pytest.approx(.95 * .97, abs=.001)
    assert result['toplamDegerKaybiYuzde'] == 2.92
    assert {k['kategori']:k['yuzde'] for k in result['kalemler']} == {'kaporta':.92, 'tramer':2}
    assert {a['baslik'] for a in result['piyasaDuzeltmeleri']} == {'Kilometre farkı','Model yılı farkı'}
