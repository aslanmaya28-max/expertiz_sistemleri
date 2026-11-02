"""Model risk/şikâyet aramasının JSON yanıtı yarıda kesilse ya da virgül eksik olsa da sağlam maddeler kurtarılır."""
import pytest

from yerimebak_ai_v5.services.vehicle_risk import _lenient_json


def test_saglam_json_aynen_okunur():
    assert _lenient_json('metin ```json\n{"riskler": [], "kullaniciSikayetleri": [{"x": 1}]}\n```') == {
        "riskler": [], "kullaniciSikayetleri": [{"x": 1}]}


def test_yarida_kesilen_yanittan_tam_maddeler_kurtarilir():
    kesik = '{"riskler": [{"baslik": "DSG", "onem": "yuksek"},\n {"baslik": "Turbo", "onem": "orta"},\n {"baslik": "Yar'
    assert _lenient_json(kesik) == {"riskler": [{"baslik": "DSG", "onem": "yuksek"}, {"baslik": "Turbo", "onem": "orta"}]}


def test_eksik_virgulde_onceki_maddeler_ve_diger_liste_kurtarilir():
    bozuk = '{"riskler": [{"a": 1}, {"b": 2} "c": 3}], "kullaniciSikayetleri": [{"d": 4}]}'
    assert _lenient_json(bozuk) == {"riskler": [{"a": 1}, {"b": 2}], "kullaniciSikayetleri": [{"d": 4}]}


def test_hic_json_yoksa_hata():
    with pytest.raises(ValueError):
        _lenient_json("Bu araç için bilgi bulunamadı.")
