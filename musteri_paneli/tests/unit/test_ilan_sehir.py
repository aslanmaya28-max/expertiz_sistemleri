# -*- coding: utf-8 -*-
"""İlandan şehir okunur (11.11.2026: birebir eşleşme yüzünden şehir hep boş kalıyordu)."""
from yerimebak_ai_v5.services import listing_extract as l

METIN = "Seat Ibiza 1.0 TSI Style\nİstanbul / Kadıköy / Caferağa Mh.\nFiyat 960.000 TL\nYıl 2024\nKM 30.000"


def test_yapay_zekanin_birlesik_konumundan_il_adi_alinir():
    for deger in ("İstanbul / Kadıköy", "Kadıköy, İstanbul", "istanbul", "Kadıköy İstanbul"):
        alanlar = l.verify({"location": deger}, METIN, "ilan_metni")
        assert alanlar["location"]["deger"] == "İstanbul", deger


def test_metinde_gecmeyen_il_kabul_edilmez_ve_konum_satirina_dusulur():
    alanlar = l.verify({"location": "Ankara"}, METIN, "ilan_metni")
    assert alanlar["location"]["deger"] == "İstanbul"  # konum satırından
    assert "location" not in l.verify({"location": "Ankara"}, "Fiyat 960.000 TL", "ilan_metni")


def test_yapay_zeka_bos_dondururse_konum_satirindan_okunur():
    assert l.verify({}, METIN, "ilan_metni")["location"]["deger"] == "İstanbul"
    assert l.konum_satirindan_il("Satıcı İzmirli, takas yok") is None
    assert l.konum_satirindan_il("Konum: Afyonkarahisar / Merkez") == "Afyonkarahisar"


def test_anahtarsiz_metin_yolunda_da_sehir_gelir(monkeypatch):
    monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)
    out = l.from_text("Marka Seat\nSeri Ibiza\n" + METIN)
    assert out["vehicle"].get("location") == "İstanbul"
