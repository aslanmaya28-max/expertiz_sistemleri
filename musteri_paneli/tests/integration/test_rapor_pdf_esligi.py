"""Sentetik tam API raporunun web alanlarıyla PDF çıktısının eşliği."""
import io
import re
from copy import deepcopy

import pdfplumber
import pytest

from .test_dispatch_flow import TEST_DB
from .test_rapor_degismezleri import (  # noqa: F401 -- pytest ortak fixture kaydı
    SENARYOLAR, client, customer_token, rapor_uret,
)
from yerimebak_ai_v5.services.valuation_report_pdf import build_pdf

pytestmark = pytest.mark.skipif(not TEST_DB, reason="TEST_DATABASE_URL tanımlı değil")


def _normal(value):
    return " ".join(value.split())


def _tl(value):
    # Üretim biçimleyicisini çağırmayarak PDF'nin yanlış tutarını paylaşmayız.
    assert isinstance(value, (int, float)), f"API tutarı eksik: {value!r}"
    return format(value, ",.0f").replace(",", ".") + " TL"


def _kart_tutarlari(document, etiket):
    """Belgenin başka yerindeki aynı tutar yanlış olumlu sonuç vermesin."""
    bulunan = []
    for page in document.pages:
        for match in page.search(re.escape(etiket)):
            kutular = [rect for rect in page.rects
                       if rect["x0"] <= match["x0"]
                       and rect["x1"] >= match["x1"]
                       and rect["top"] <= match["top"]
                       and rect["bottom"] >= match["bottom"]
                       and rect["height"] > 30
                       # Tam genişlikteki satıcı mesajı da aynı sözü içerebilir.
                       and rect["width"] < page.width / 2]
            if not kutular:
                continue
            kutu = min(kutular, key=lambda r: r["width"] * r["height"])
            metin = page.crop((kutu["x0"], kutu["top"], kutu["x1"], kutu["bottom"])).extract_text() or ""
            bulunan.append(re.findall(r"\d[\d.]*\s+TL", _normal(metin)))
    assert len(bulunan) == 1, f"{etiket}: tek fiyat kartı bekleniyordu, bulunan={bulunan}"
    return bulunan[0]


@pytest.fixture
def pdf_raporu(rapor_uret, request):
    rapor = rapor_uret(request.param)
    once = deepcopy(rapor)
    cikti = build_pdf(rapor)
    assert rapor == once, "PDF üretimi kaynak API raporunu değiştirdi"
    assert cikti.startswith(b"%PDF")
    with pdfplumber.open(io.BytesIO(cikti)) as document:
        yield rapor, document, _normal(" ".join(page.extract_text() or "" for page in document.pages))


@pytest.mark.parametrize("pdf_raporu", SENARYOLAR, indirect=True)
def test_pdf_ana_tutarlar_ilgili_kart_ve_etikette_api_ile_ayni(pdf_raporu):
    rapor, document, metin = pdf_raporu
    degerleme = rapor["degerleme"]
    adil = degerleme["adilFiyatAraligi"]
    plan = rapor["pazarlikPlani"]
    kartlar = {
        "İlan fiyatı": [rapor["arac"]["ilanFiyati"]],
        "Tavsiye alım fiyatı": [degerleme["tavsiyeFiyat"]],
        "Adil fiyat aralığı": [adil["min"], adil["max"]],
        "Açılış teklifi:": [plan["acilisTeklifi"]],
        "Hedef fiyat:": [plan["hedefFiyat"]],
        "Üst sınır:": [plan["ustSinir"]],
    }
    for etiket, tutarlar in kartlar.items():
        assert _kart_tutarlari(document, etiket) == [_tl(tutar) for tutar in tutarlar], etiket
    assert re.search(r"Ortalama(?: \(bu araca göre\))?: "
                     + re.escape(_tl(rapor["piyasa"]["ortalama"])) + r"\b", metin), metin
    assert "Hasarsız piyasa değeri: " + _tl(degerleme["temizPiyasaDegeri"]) in metin
    ozet_adil = rapor["ozet"]["adilFiyat"]
    assert ("Adil fiyat " + _tl(ozet_adil["min"]) + " – " + _tl(ozet_adil["max"])) in metin


@pytest.mark.parametrize("pdf_raporu", SENARYOLAR, indirect=True)
def test_pdf_uyari_ve_getiri_bolumleri_web_raporuyla_eslesir(pdf_raporu):
    rapor, _, metin = pdf_raporu
    if rapor.get('ekspertizRaporu'):
        assert _normal(rapor['ekspertizRaporu']['aciklama']) in metin
        assert _normal(rapor['ozet']['riskler'][0]) in metin
        assert _normal(rapor['ozet']['simdiNeYapmali']) in metin
    uyari = rapor["pazarlikPlani"].get("uyari")
    if uyari:
        assert _normal(uyari) in metin
    # Planın uyarısı az veri vb. uyarılar da içerebilir; düşük fiyatı ayrıca ayır.
    for imza in ("Bu bir fırsat olabilir", "Bu kadar düşük fiyat;"):
        assert (imza in metin) == (imza in (uyari or ""))
    assert "güven skoru" not in metin.casefold()
    if not rapor.get("getiri"):
        # Başlık ve bilgi kaynaklarındaki alan aynı koşulla kaybolmalıdır.
        assert "gelecek değer" not in metin.casefold()
        assert "Enflasyona göre kazanç tahmini" not in metin
        assert "sağladığı kazanç" not in metin
        assert "Aylık araç enflasyonu:" not in metin
    else:
        # Bölüm sitedeki kartla aynı adı ve 6 aylık/yıllık oranları taşır (09.11.2026).
        assert "Enflasyona göre kazanç tahmini" in metin
        assert "6 aylık araç enflasyonu:" in metin and "Yıllık araç enflasyonu:" in metin
        assert "1 yıl sonra sağladığı kazanç:" in metin
