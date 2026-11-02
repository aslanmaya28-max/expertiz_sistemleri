"""Ortak test ayarı: testler gerçek şikâyet aramasına (ağ) çıkmaz."""
import pytest


@pytest.fixture(autouse=True)
def _sikayet_aramasi_kapali(monkeypatch):
    # Risk aramasını taklit eden testler yalnız `_search`'ü değiştirir; ikinci (Türkçe şikâyet)
    # araması varsayılan olarak boş döner. Bu davranışı sınayan testler kendi sahtesini kurar.
    from yerimebak_ai_v5.services import vehicle_risk
    monkeypatch.setattr(vehicle_risk, "_search_complaints",
                        lambda query, client: {"complaints": [], "cited": {}, "cost": 0})
