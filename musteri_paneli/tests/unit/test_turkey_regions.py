# -*- coding: utf-8 -*-
def test_turkey_regions_reference_is_complete():
    from yerimebak_ai_v5.core import turkey_regions as tr

    assert len(tr.PROVINCES) == 81
    expected = {1: 11, 2: 13, 3: 8, 4: 8, 5: 18, 6: 14, 7: 9}
    for region_id, count in expected.items():
        assert len(tr.provinces_in_region(region_id)) == count, region_id
    assert tr.province_plate("İSTANBUL") == 34
    assert tr.province_plate("Istanbul / Kadıköy") == 34
    assert tr.province_plate("sanliurfa") == 63
    assert tr.province_plate("Iğdır") == 76
    assert tr.province_plate("ığdır") == 76
    assert tr.province_plate("Kadıköy, İstanbul") == 34
    assert tr.province_plate("Atlantis") is None
    assert tr.region_name(tr.region_id_of(36)) == "Doğu Anadolu"  # Kars
    assert tr.region_name(tr.region_id_of(19)) == "Karadeniz"  # Çorum
