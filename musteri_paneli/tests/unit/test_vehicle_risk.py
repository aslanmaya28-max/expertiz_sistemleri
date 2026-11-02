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
    assert result["riskler"][0] == item(kategori="mekanik_motor", onem="yuksek")
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
            return {"choices": [{"message": {"content": '{"riskler": [], "kullaniciSikayetleri": []}',
                    "annotations": [{"url_citation": {"url": URL + "/", "content": TEXT}}]}}],
                    "usage": {"cost": .009}}
    class Client:
        def post(self, url, headers, json):
            assert json["model"] == "test-model"
            assert json["provider"] == {"only": ["test-provider"], "allow_fallbacks": False}
            assert json["plugins"][0]["id"] == "web"
            assert "Triger" in json["messages"][0]["content"]
            assert "kullaniciSikayetleri" in json["messages"][0]["content"]
            prompt = json["messages"][0]["content"]
            for preferred in ("araclo.com", "sikayetvar.com", "forum.donanimhaber.com", "technopat.net/sosyal", "arabalar.com.tr/blog"):
                assert preferred in prompt
            assert "kronikmotor" not in prompt.lower()
            assert "kategori" in prompt and "onem" in prompt
            return Response()
    assert vr._search("Seat Arona", Client()) == {"risks": [], "complaints": [], "sources": {URL: TEXT}, "cost": .009}


def complaint_search(monkeypatch, complaints, sources):
    calls = []
    def fake(query, client):
        calls.append(query)
        return {"risks": [], "complaints": complaints, "sources": sources, "cost": .009}
    monkeypatch.setattr(vr, "_search", fake)
    return calls


def test_complaints_merge_topics_count_root_domains_and_omit_cost(monkeypatch):
    urls = ["https://forum.first.com/topic", "https://first.com/other", "https://second.com/triger"]
    calls = complaint_search(monkeypatch, [
        {"baslik": "Triger sesi", "aciklama": "Kullanıcılar triger sesinden söz ediyor.",
         "kaynaklar": urls[:2], "tahminiMaliyet": {"min": 10, "max": 20}},
        {"baslik": "Timing belt sesi", "kaynaklar": urls[2:]},
        {"baslik": "Turbo", "kaynaklar": [urls[0]]},
    ], {url: "Seat Arona 1.0 TSI DSG triger sesi ve turbo yorumu." for url in urls})
    result = vr.get_model_risks(VEHICLE)
    assert len(calls) == 1 and result["scope"]["searches"] == 1
    assert result["kullaniciSikayetleri"] == [{
        "baslik": "Triger sesi", "aciklama": "Kullanıcılar triger sesinden söz ediyor.",
        "kaynakSayisi": 2, "kaynaklar": urls, "kategori": "mekanik_motor", "onem": "yuksek"}]


@pytest.mark.parametrize("urls,text,vehicle", [
    (["https://forum.first.com/topic", "https://first.com/topic"], TEXT, VEHICLE),
    (["https://forum.first.com.tr/topic", "https://first.com.tr/topic"], TEXT, VEHICLE),
    (["https://first.com/topic", "https://second.com/topic"], "Seat Ibiza triger sesi", VEHICLE),
    (["https://first.com/topic", "https://second.com/topic"], "Citroen C30 triger sesi", {**VEHICLE, "model": "C3"}),
    (["https://first.com/topic", "https://second.com/topic"], "Seat Arona turbo yorumu", VEHICLE),
    (["https://first.com/topic", "https://second.com/topic"], "Seat Arona 1.4 TSI triger sorunu", VEHICLE),
])
def test_complaints_require_two_independent_model_and_topic_sources(monkeypatch, urls, text, vehicle):
    complaint_search(monkeypatch, [{"baslik": "Triger sesi", "kaynaklar": urls}], {url: text for url in urls})
    assert vr.get_model_risks(vehicle)["kullaniciSikayetleri"] == []


def test_complaints_rank_source_counts_and_limit_five(monkeypatch):
    complaints, sources = [], {}
    for i, title in enumerate(["Triger", "Zincir", "Mekatronik", "Debriyaj", "Volan", "DPF", "EGR"]):
        urls = [f"https://source{j}.com/{i}" for j in range(i + 2)]
        complaints.append({"baslik": title, "kaynaklar": urls})
        sources.update({url: f"Seat Arona 1.0 TSI DSG {title} şikâyeti" for url in urls})
    complaint_search(monkeypatch, complaints, sources)
    result = vr.get_model_risks(VEHICLE)["kullaniciSikayetleri"]
    assert [c["baslik"] for c in result] == ["EGR", "Volan", "Debriyaj", "Mekatronik", "Zincir"]
    assert [c["kaynakSayisi"] for c in result] == [8, 6, 5, 4, 3]


def test_complaints_cached_candidates_reverified_for_current_vehicle(monkeypatch):
    monkeypatch.setenv("WEB_RISK_CACHE_DAYS", "30")
    rows = {}
    monkeypatch.setattr(vr.wmr, "_cache_read", lambda key, hours: deepcopy(rows.get(key)))
    monkeypatch.setattr(vr.wmr, "_cache_write", lambda key, value: rows.update({key: deepcopy(value)}))
    urls = ["https://first.com/topic", "https://second.com/topic"]
    calls = complaint_search(monkeypatch, [{"baslik": "Triger", "kaynaklar": urls}],
                            {url: "Seat Arona 2020-2021 1.0 TSI DSG triger sesi" for url in urls})
    assert vr.get_model_risks(VEHICLE)["kullaniciSikayetleri"][0]["kaynakSayisi"] == 2
    assert vr.get_model_risks(VEHICLE)["kullaniciSikayetleri"][0]["kaynakSayisi"] == 2
    assert vr.get_model_risks({**VEHICLE, "year": 2024})["kullaniciSikayetleri"] == []
    assert len(calls) == 1


def test_complaints_empty_without_api_key(monkeypatch):
    monkeypatch.setenv("OPENROUTER_API_KEY", "")
    assert vr.get_model_risks(VEHICLE)["kullaniciSikayetleri"] == []


@pytest.mark.parametrize("host,blocked", [
    ("kronikmotor.com", True), ("www.kronikmotor.com", True),
    ("sub.kronikmotor.com.", True), ("kronikmotor.com.example.org", False),
])
def test_prohibited_source_domain_boundary(monkeypatch, host, blocked):
    url = f"https://{host}/arona"
    search(monkeypatch, [item(kaynaklar=[url])], {url: TEXT})
    assert bool(vr.get_model_risks(VEHICLE)["riskler"]) is not blocked


@pytest.mark.parametrize("host", ["sikayetvar.com", "forum.donanimhaber.com", "technopat.net", "araclo.com"])
def test_preferred_user_sources_do_not_establish_verified_confidence(monkeypatch, host):
    url = f"https://{host}/arona"
    search(monkeypatch, [item(kaynaklar=[url])], {url: TEXT})
    assert vr.get_model_risks(VEHICLE)["riskler"][0]["guven"] == "dusuk"


@pytest.mark.parametrize("title,category,severity", [
    ("Triger", "mekanik_motor", "yuksek"), ("Sensör arızası", "elektronik", "orta"),
    ("Far buğusu", "trim_kasa", "dusuk"), ("Multimedya donması", "elektronik", "dusuk"),
    ("Trim sesi", "trim_kasa", "dusuk"), ("Süspansiyon", "mekanik_motor", "orta"),
    ("Yakıt pompası", "mekanik_motor", "yuksek"), ("Motor arızası", "mekanik_motor", "yuksek"),
])
def test_category_and_severity_fallback_in_both_lists(monkeypatch, title, category, severity):
    urls = ["https://sikayetvar.com/arona", "https://forum.donanimhaber.com/arona"]
    candidate = item(baslik=title, kaynaklar=urls)
    monkeypatch.setattr(vr, "_search", lambda *args: {
        "risks": [candidate], "complaints": [candidate], "cost": .009,
        "sources": {url: f"Seat Arona 1.0 TSI DSG {title} şikâyeti" for url in urls}})
    result = vr.get_model_risks(VEHICLE)
    for key in ("riskler", "kullaniciSikayetleri"):
        assert len(result[key]) == 1
        assert result[key][0]["kategori"] == category
        assert result[key][0]["onem"] == severity
    assert "tahminiMaliyet" not in result["kullaniciSikayetleri"][0]


def test_explicit_valid_category_and_severity_preserved(monkeypatch):
    search(monkeypatch, [item(kategori="trim_kasa", onem="dusuk")])
    result = vr.get_model_risks(VEHICLE)["riskler"][0]
    assert (result["kategori"], result["onem"]) == ("trim_kasa", "dusuk")


@pytest.mark.parametrize("verified,want", [(False, "dusuk"), (True, "yuksek")])
def test_only_source_verified_cost_escalates_severity(monkeypatch, verified, want):
    text = "Seat Arona 1.0 TSI DSG far buğusu."
    if verified:
        text += " Far buğusu onarımı 25.000–30.000 TL."
    search(monkeypatch, [item(baslik="Far buğusu", tahminiMaliyet={"min": 25000, "max": 30000})], {URL: text})
    assert vr.get_model_risks(VEHICLE)["riskler"][0]["onem"] == want


@pytest.mark.parametrize("fuel,title,keep", [
    ("Benzin", "AdBlue arızası", False), ("Hibrit", "DPF arızası", False),
    ("Benzin", "Enjektör pompası (dizel)", False), ("Dizel", "AdBlue arızası", True),
    ("Elektrik", "Triger", False), ("Elektrik", "Motor yağı", False),
    ("Elektrik", "Trigerin kopması", False), ("Elektrik", "Motor yağının sızması", False),
    ("Elektrik", "Şanzıman yağı", False), ("Elektrik", "Egzoz", False),
    ("Dizel", "Buji", False), ("Dizel", "Ateşleme bobini", False),
    ("Dizel", "Kızdırma bujisi", True),
])
def test_fuel_consistency_applies_to_risks_and_complaints(monkeypatch, fuel, title, keep):
    urls = ["https://first.com/arona", "https://second.com/arona"]
    candidate = item(baslik=title, aciklama="Kaynaklı şikâyet", kaynaklar=urls)
    monkeypatch.setattr(vr, "_search", lambda *args: {
        "risks": [candidate], "complaints": [candidate], "cost": 0,
        "sources": {url: f"Seat Arona 1.0 TSI DSG {title}" for url in urls}})
    result = vr.get_model_risks({**VEHICLE, "fuel": fuel})
    for key in ("riskler", "kullaniciSikayetleri"):
        assert bool(result[key]) is keep


@pytest.mark.parametrize("field", ["aciklama", "belirtiler", "kontrol"])
def test_fuel_conflicts_in_claim_details_are_dropped(monkeypatch, field):
    search(monkeypatch, [item(**{field: ["AdBlue uyarısı"] if field == "belirtiler" else "AdBlue uyarısı"})])
    assert vr.get_model_risks(VEHICLE)["riskler"] == []


def test_fuel_conflicts_in_source_are_dropped(monkeypatch):
    search(monkeypatch, [item()], {URL: TEXT + " AdBlue arızası."})
    assert vr.get_model_risks(VEHICLE)["riskler"] == []


def test_cached_candidate_is_rechecked_for_fuel(monkeypatch):
    monkeypatch.setenv("WEB_RISK_CACHE_DAYS", "30")
    monkeypatch.setattr(vr.wmr, "_cache_read", lambda *args: {
        "scope": {"cached": True}, "_candidates": [item(aciklama="AdBlue")],
        "_complaint_candidates": [], "_sources": {URL: TEXT}})
    monkeypatch.setattr(vr, "_search", lambda *args: pytest.fail("Önbellek yeniden aramamalı"))
    assert vr.get_model_risks(VEHICLE)["riskler"] == []


@pytest.mark.parametrize('evidence,keep', [('konforlu bir otomobildir', False),
                                         ('kapıda pas oluşumu var', True),
                                         ('kapı paslı', True), ('kapı paslanması', True)])
def test_passat_model_name_is_not_rust_evidence(monkeypatch, evidence, keep):
    vehicle = {**VEHICLE, 'brand':'Volkswagen', 'model':'Passat', 'package':'1.4 TSI DSG'}
    urls = ['https://whatcar.com/passat', 'https://forum.donanimhaber.com/passat']
    candidate = item(baslik='Paslanma', aciklama='Kaporta kontrolü', etkiledigi='1.4 TSI DSG',
                     kaynaklar=urls, tahminiMaliyet=None)
    monkeypatch.setattr(vr, '_search', lambda *args: {
        'risks':[candidate], 'complaints':[candidate], 'cost':0,
        'sources':{url:f'Volkswagen Passat 1.4 TSI DSG {evidence}.' for url in urls}})
    result = vr.get_model_risks(vehicle)
    assert bool(result['riskler']) is keep
    assert bool(result['kullaniciSikayetleri']) is keep


@pytest.mark.parametrize('title,keep', [('GPF partikül filtresi arızası',True),
                                     ('OPF benzin partikül filtresi arızası',True),
                                     ('Dizel partikül filtresi arızası',False),
                                     ('DPF arızası',False)])
def test_gasoline_filter_is_not_confused_with_diesel_filter(monkeypatch, title, keep):
    urls = ['https://whatcar.com/arona', 'https://forum.donanimhaber.com/arona']
    candidate = item(baslik=title, aciklama='Filtreyi kontrol edin', kaynaklar=urls, tahminiMaliyet=None)
    monkeypatch.setattr(vr, '_search', lambda *args: {
        'risks':[candidate], 'complaints':[candidate], 'cost':0,
        'sources':{url:f'Seat Arona 1.0 TSI DSG {title}.' for url in urls}})
    result = vr.get_model_risks(VEHICLE)
    assert bool(result['riskler']) is keep
    assert bool(result['kullaniciSikayetleri']) is keep
