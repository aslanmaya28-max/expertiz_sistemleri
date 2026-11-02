"""Ekspertiz talebi tutarı: KDV yalnız hizmet bedeline eklenir, firma paketi KDV dahil aktarılır."""
from yerimebak_ai_v5.services import pricing_service


def test_kdv_yalniz_hizmet_bedeline():
    t = pricing_service.expertiz_totals(5000, 4900)
    assert t["vat_tl"] == round(5000 * pricing_service.VAT_RATE, 2)
    assert t["total_tl"] == 5000 + t["vat_tl"] + 4900
    assert t["service_fee_tl"] == 5000 and t["package_price_tl"] == 4900


def test_odeme_satirlari_toplamla_uyumlu():
    t = pricing_service.expertiz_totals(5000.0, 13000.0)
    assert round(t["service_fee_tl"] + t["package_price_tl"] + t["vat_tl"], 2) == t["total_tl"]
