"""Model riskleri: dış ağa çıkmadan kaynak, kapsam ve önbellek denetimi."""
from copy import deepcopy
from datetime import datetime, timedelta, timezone

import pytest

from yerimebak_ai_v5.services import vehicle_risk as vr


VEHICLE = dict(brand="Seat", model="Arona", year=2020, package="1.0 TSI DSG",
               fuel="Benzin", transmission="Otomatik", km=120000)
URL = "https://www.seat.com/owners/recall"
TEXT = "Seat Arona 1.0 TSI DSG triger servis bülteni. Triger seti 10.000–15.000 TL."


def item(**updates):
    return dict(dict(baslik="Triger seti", aciklama="Triger geçmişini doğrulayın.",
                     etkiledigi="2020 1.0 TSI DSG", belirtiler=["Ses"],
                     kontrol="Servis faturası", tahminiMaliyet={"min": 10000, "max": 15000},
                     kaynaklar=[URL], guven="yuksek"), **updates)


@pytest.fixture(autouse=True)
def isolated(monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-key")
    monkeypatch.setenv("WEB_RISK_CACHE_DAYS", "0")


def search(monkeypatch, items, sources=None):
    calls = []
    def fake(query, client):
        calls.append(query)
        return {"risks": items, "sources": {URL: TEXT} if sources is None else sources, "cost": .009}
    monkeypatch.setattr(vr, "_search", fake)
    return calls


@pytest.mark.parametrize("updates,sources", [
    ({"kaynaklar": ["https://invented.test/no"]}, None),
    ({}, {URL: "Seat Arona 1.0 TSI DSG turbo"}),
    ({}, {URL: "Seat Arona 1.4 TSI DSG triger"}),
    ({"etkiledigi": "1.4 TSI DSG"}, None),
    ({}, {URL: "Seat Arona 1.0 TSI manuel triger"}),
    ({"etkiledigi": "2010-2014 1.0 TSI DSG"}, None),
    ({}, {URL: "Seat Arona 1.0 TSI DSG tanıtım. 1.4 TSI triger sorunu."}),
    ({}, {URL: "Seat Arona 1.0 TDI DSG triger sorunu."}),
    ({"baslik": "Triger geri çağırma"}, {URL: "Seat Arona 1.0 TSI DSG fren geri çağırma."}),
])
def test_unsupported_claims_dropped(monkeypatch, updates, sources):
    search(monkeypatch, [item(**updates)], sources)
    assert vr.get_model_risks(VEHICLE)["riskler"] == []


def test_verified_and_turkish(monkeypatch):
    calls = search(monkeypatch, [item()])
    result = vr.get_model_risks(VEHICLE)
    assert len(calls) == 1
    assert result["riskler"][0] == item()
    assert not result["bulunamadi"]
    assert result["scope"]["cost_usd"] == .009


@pytest.mark.parametrize("url,text,confidence", [
    ("https://forum.seatclub.test/topic", TEXT, "dusuk"),
    ("https://unknown.test/topic", TEXT, "dusuk"),
    ("https://www.whatcar.com/seat/arona/review", TEXT, "orta"),
    (URL, "Seat Arona 1.0 TSI DSG triger incelemesi", "dusuk"),
])
def test_confidence_is_source_based(monkeypatch, url, text, confidence):
    search(monkeypatch, [item(kaynaklar=[url])], {url: text})
    assert vr.get_model_risks(VEHICLE)["riskler"][0]["guven"] == confidence


@pytest.mark.parametrize("text", [
    "Seat Arona 1.0 TSI DSG triger 10000 km, 15000 km.",
    "Seat Arona 1.0 TSI DSG triger 10000–15000 EUR.",
    "Seat Arona 1.0 TSI DSG triger. Turbo 10.000–15.000 TL.",
])
def test_no_invented_cost(monkeypatch, text):
    search(monkeypatch, [item()], {URL: text})
    assert vr.get_model_risks(VEHICLE)["riskler"][0]["tahminiMaliyet"] is None


def test_only_verified_sources_survive(monkeypatch):
    search(monkeypatch, [item(kaynaklar=[URL, "https://fake.test"] )])
    assert vr.get_model_risks(VEHICLE)["riskler"][0]["kaynaklar"] == [URL]


def test_missing_key_rules_still_work(monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", "")
    monkeypatch.setattr(vr, "_search", lambda *args: pytest.fail("Arama yapılmamalı"))
    result = vr.get_model_risks(VEHICLE)
    assert result["riskler"] == [] and result["bulunamadi"]
    maintenance = vr.upcoming_maintenance(VEHICLE, result)
    assert any("Triger" in x["baslik"] for x in maintenance)
    assert all("doğrulayın" in x["aciklama"] for x in maintenance)
    questions = vr.seller_questions(VEHICLE, result, [])
    assert 6 <= len(questions) <= 10
    assert any("Ekspertize" in q for q in questions)


def test_rules_merge_dedupe_and_damage():
    risks = {"riskler": [item(), item(), item(baslik="Mekatronik", aciklama="Kontrol edin")]}
    maintenance = vr.upcoming_maintenance(VEHICLE, risks)
    assert sum("triger" in vr.fold(x["baslik"]) for x in maintenance) == 1
    questions = vr.seller_questions(VEHICLE, risks, [{"baslik": "Sol kapı boyalı", "durum": "Hasarlı"}])
    assert 6 <= len(questions) <= 10 and len(questions) == len(set(questions))
    assert any("Mekatronik" in q for q in questions)
    assert any("Tramer" in q for q in questions)
    assert any("Sol kapı" in q for q in questions)


def test_electric_and_young_vehicle():
    electric = {**VEHICLE, "year": datetime.now().year, "km": 1000, "fuel": "Elektrik"}
    text = str(vr.upcoming_maintenance(electric, []))
    assert "Triger" not in text and "DPF" not in text and "Debriyaj" not in text
    assert "Fren" in text


def test_cache_key_scope():
    assert vr._cache_key(VEHICLE) == vr._cache_key({**VEHICLE, "km": 200000, "year": 2021})
    for field, value in [("package", "1.4 TSI"), ("fuel", "Dizel"), ("transmission", "Manuel"),
                         ("model", "Ibiza"), ("brand", "VW"), ("year", 2025)]:
        assert vr._cache_key(VEHICLE) != vr._cache_key({**VEHICLE, field: value})


@pytest.mark.parametrize("items", [[item(etkiledigi="2020-2021 1.0 TSI DSG")], []])
def test_cache_hit_and_expiry(monkeypatch, items):
    # Gerçek ortak önbellek okuma/yazma kodu; yalnız DB bağlantısı taklit edilir.
    monkeypatch.setenv("WEB_RISK_CACHE_DAYS", "30")
    rows = {}
    class Connection:
        def cursor(self): return self
        def __enter__(self): return self
        def __exit__(self, *args): pass
        def execute(self, sql, params):
            self.key = params[0]
            if sql.startswith("INSERT"):
                rows[self.key] = {"reference": deepcopy(params[1].adapted), "created_at": datetime.now(timezone.utc)}
        def fetchone(self): return deepcopy(rows.get(self.key))
        def commit(self): pass
    monkeypatch.setattr(vr.wmr, "_ensure_cache_schema", lambda: None)
    monkeypatch.setattr(vr.wmr.DatabaseConfig, "get_connection", lambda: Connection())
    monkeypatch.setattr(vr.wmr.DatabaseConfig, "return_connection", lambda conn: None)
    calls = search(monkeypatch, items)
    assert not vr.get_model_risks(VEHICLE)["scope"]["cached"]
    cached = vr.get_model_risks({**VEHICLE, "km": 200000})
    assert cached["scope"]["cached"] and cached["scope"]["cost_usd"] == 0
    assert len(calls) == 1
    newer = vr.get_model_risks({**VEHICLE, "year": 2024})
    assert newer["riskler"] == [] and newer["bulunamadi"]
    assert newer["scope"]["cached"] and len(calls) == 1
    rows[vr._cache_key(VEHICLE)]["created_at"] -= timedelta(days=31)
    assert not vr.get_model_risks(VEHICLE)["scope"]["cached"]
    assert len(calls) == 2


def test_db_and_search_failure_are_optional(monkeypatch):
    monkeypatch.setenv("WEB_RISK_CACHE_DAYS", "30")
    def fail(*args): raise RuntimeError("Kesinti")
    monkeypatch.setattr(vr.wmr, "_ensure_cache_schema", fail)
    search(monkeypatch, [item()])
    assert vr.get_model_risks(VEHICLE)["riskler"]
    monkeypatch.setattr(vr, "_search", fail)
    assert vr.get_model_risks(VEHICLE)["bulunamadi"]


def test_search_protocol_without_network(monkeypatch):
    monkeypatch.setenv("WEB_PRICE_MODEL", "test-model")
    monkeypatch.setenv("WEB_PRICE_PROVIDER", "test-provider")
    class Response:
        def raise_for_status(self): pass
        def json(self):
            return {"choices": [{"message": {"content": '{"riskler": []}',
                    "annotations": [{"url_citation": {"url": URL + "/", "content": TEXT}}]}}],
                    "usage": {"cost": .009}}
    class Client:
        def post(self, url, headers, json):
            assert json["model"] == "test-model"
            assert json["provider"] == {"only": ["test-provider"], "allow_fallbacks": False}
            assert json["plugins"][0]["id"] == "web"
            assert "Triger" in json["messages"][0]["content"]
            return Response()
    assert vr._search("Seat Arona", Client()) == {"risks": [], "sources": {URL: TEXT}, "cost": .009}
