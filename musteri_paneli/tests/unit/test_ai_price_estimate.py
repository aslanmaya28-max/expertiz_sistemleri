# -*- coding: utf-8 -*-
"""Emsal yetersizken yapay zeka (DeepSeek) fiyat tahmini: dogrulama, baglanti, degerlemeye etkisi (agsiz)."""
import json

import httpx
import pytest

from yerimebak_ai_v5.services import ai_price_estimate as ape

ARONA = {"brand": "Seat", "model": "Arona", "year": 2024, "package": "1.0 EcoTSI FR", "km": 20000}


@pytest.mark.parametrize("text,median", [
    ('{"medyan": 1550000, "min": 1420000, "max": 1755000, "veri_tarihi": "2026-09", "not": "x"}', 1550000),
    ('Tahmin:\n```json\n{"medyan": "1.550.000 TL", "min": "1.420.000", "max": "1.755.000"}\n```', 1550000),
    ('{"medyan": 1550000}', 1550000),
    ('{"medyan": null, "not": "bilmiyorum"}', None),
    ('{"medyan": 900, "min": 800, "max": 1000}', None),          # anlamsiz kucuk fiyat
    ('{"medyan": 1000000, "min": 200000, "max": 5000000}', None),  # cok genis aralik: emin degil
    ("bu aracin fiyati yaklasik 1,5 milyon", None),
    ('{"medyan": tr', None),
])
def test_parse_answer(text, median):
    out = ape.parse_answer(text)
    assert (out or {}).get("median") == median
    if out:
        assert out["min"] <= out["median"] <= out["max"]


def _transport(content, calls, status=200):
    def handler(request):
        calls.append(json.loads(request.content))
        if status != 200:
            return httpx.Response(status, json={"error": "x"})
        return httpx.Response(200, json={"choices": [{"message": {"content": content}}]})
    return httpx.MockTransport(handler)


def test_estimate_calls_openrouter_with_deepseek(monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", "test")
    monkeypatch.delenv("AI_PRICE_MODEL", raising=False)
    monkeypatch.delenv("AI_PRICE_ESTIMATE", raising=False)
    calls = []
    out = ape.estimate(ARONA, transport=_transport('{"medyan": 1550000, "min": 1420000, "max": 1755000}', calls))
    assert out["median"] == 1550000 and out["model"] == "deepseek/deepseek-chat"
    assert calls[0]["model"] == "deepseek/deepseek-chat" and calls[0]["temperature"] == 0
    assert "Arona" in calls[0]["messages"][1]["content"] and "2024" in calls[0]["messages"][1]["content"]


def test_estimate_returns_none_when_off_or_failing(monkeypatch):
    calls = []
    monkeypatch.delenv("OPENROUTER_API_KEY", raising=False)
    assert ape.estimate(ARONA, transport=_transport("{}", calls)) is None and not calls
    monkeypatch.setenv("OPENROUTER_API_KEY", "test")
    monkeypatch.setenv("AI_PRICE_ESTIMATE", "off")
    assert ape.estimate(ARONA, transport=_transport("{}", calls)) is None and not calls
    monkeypatch.delenv("AI_PRICE_ESTIMATE")
    assert ape.estimate({"brand": "Seat"}, transport=_transport("{}", calls)) is None and not calls
    assert ape.estimate(ARONA, transport=_transport("", calls, status=500)) is None
    assert ape.estimate(ARONA, transport=_transport("bilmiyorum", calls)) is None


def test_ai_reference_is_labelled_and_low_confidence():
    from yerimebak_ai_v5.core.ai.inspection_valuation import evaluate
    from yerimebak_ai_v5.services.valuation_criteria import build_criteria

    ref = ape.to_reference({"median": 1_550_000, "min": 1_420_000, "max": 1_755_000, "model": "deepseek/deepseek-chat"},
                           {"reason": "not_enough_reference", "scope": {"listed_price": 1_600_000}})
    d = evaluate({}, ref, listed_price=1_600_000, vehicle={"km": 20000, "yil": 2024})
    assert d["degerlemeYapildi"] is True and d["piyasaKaynagi"] == "ai_estimate"
    assert d["piyasaDegeri"] == 1_550_000 and d["guvenSkoru"] <= 25
    assert d["piyasaUyarisi"] == ape.WARNING and "yapay zekâ tahmini" in d["piyasaYontemi"]
    assert "yapay zekâ tahmini" in d["ozet"]
    model_row = build_criteria(d, ref, {"brand": "Seat", "model": "Arona", "year": 2024})[0]
    assert "yapay zekâ tahmini" in model_row["aciklama"]
    # Gercek emsallerle yapilan degerlemede uyari yok
    listings = {"found": True, "source": "listings", "market_median_price": 1_500_000, "confidence": 80, "count": 12}
    assert "piyasaUyarisi" not in evaluate({}, listings, vehicle={"km": 20000, "yil": 2024})
