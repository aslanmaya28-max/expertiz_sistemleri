# -*- coding: utf-8 -*-
"""Telefondaki müşteri: ilan ekran görüntüsünden araç bilgisi (kullanıcı denemesi, 08.11.2026).

Sahibinden sayfası sunucudan okunamıyor, telefonda ilan metni kopyalanamıyor. Ekran görüntüsü metne çevrilir
ve yapıştırılan metinle aynı doğrulamadan geçer. Ağ çağrısı yok: görüntü okuyucu sahte."""
import io

import pytest
from PIL import Image

from yerimebak_ai_v5.services import listing_screenshot as ls
from yerimebak_ai_v5.services.inspection_photo import PhotoError

# Sahibinden mobil ilan ekranından okunmuş (sentetik) metin.
OKUNAN = """Fiyat: 1.890.000 TL
İlan No: 1234567890
Marka: MG
Seri: HS
Model: 1.5 T-GDI Luxury
Yıl: 2023
Yakıt Tipi: Benzin
Vites: Otomatik
KM: 33.100
Motor Gücü: 162 hp
Boya-değişen: Sol ön çamurluk boyalı, diğer parçalar orijinal.
Tramer: 12.500 TL"""


def _png():
    out = io.BytesIO()
    Image.new("RGB", (40, 80), "white").save(out, "PNG")
    return out.getvalue()


def test_ekran_goruntusu_metinle_ayni_dogrulamadan_gecer(monkeypatch):
    monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)  # metin çıkarımı yalnız kesin etiket satırlarıyla
    monkeypatch.setattr(ls, "_ocr", lambda images: (OKUNAN, {"model": "sahte", "cost_usd": 0.001}))
    out = ls.read([_png()])
    v = out["vehicle"]
    assert (v["brand"], v["model"], v["package"], v["year"], v["km"]) == ("MG", "HS", "1.5 T-GDI Luxury", 2023, 33_100)
    assert v["price"] == 1_890_000  # fiyat satırı kesin kuralla okunur
    assert out["verified_count"] >= 5 and "Ekran görüntüsünden" in out["message"]
    assert out["metin"] == OKUNAN  # müşteri okunan metni görür ve düzeltebilir
    assert all(f["kaynak"] == "ilan_metni" for f in out["fields"].values())


def test_bos_okuma_ve_sinirlar(monkeypatch):
    monkeypatch.setattr(ls, "_ocr", lambda images: ("", {"model": "sahte", "cost_usd": 0}))
    out = ls.read([_png()])
    assert not out["found"] and out["verified_count"] == 0 and "bulunamadı" in out["message"]
    with pytest.raises(PhotoError):
        ls.read([])
    with pytest.raises(PhotoError):
        ls.read([_png()] * 5)
    with pytest.raises(PhotoError):
        ls.read([b"resim degil"])


def test_saglayici_hatasi_icerik_sizdirmaz(monkeypatch):
    def patla(images):
        raise RuntimeError("sağlayıcı iç hata metni")
    monkeypatch.setattr(ls, "_ocr", patla)
    with pytest.raises(PhotoError) as exc:
        ls.read([_png()])
    assert exc.value.status == 502 and "iç hata" not in str(exc.value)


def test_anahtar_yoksa_anlasilir_hata(monkeypatch):
    monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)
    with pytest.raises(PhotoError) as exc:
        ls.read([_png()])
    assert exc.value.status == 503 and "elle" in str(exc.value)
