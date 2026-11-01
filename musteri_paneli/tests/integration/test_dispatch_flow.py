# -*- coding: utf-8 -*-
"""
Uctan uca: musteri talebi -> admin kuyrugu -> personel atama -> personel paneli.

Gercek bir PostgreSQL ister. Calistirmak icin:
    TEST_DATABASE_URL=postgresql://user@host:port/db SECRET_KEY=test pytest tests/integration -q
Veritabani her calistirmada sifirlanir (public sema), uretim veritabani KULLANMAYIN.
"""
import os
import uuid

import pytest

TEST_DB = os.getenv("TEST_DATABASE_URL", "")
pytestmark = pytest.mark.skipif(not TEST_DB, reason="TEST_DATABASE_URL tanimli degil")

ADMIN_KEY = "test-admin-key"


@pytest.fixture(scope="module")
def client():
    os.environ["DATABASE_URL"] = TEST_DB
    os.environ.setdefault("SECRET_KEY", "test-secret")
    os.environ["ADMIN_SECRET_KEY"] = ADMIN_KEY
    # Polling dongusu testte kapali: AI, gonderimdeki arka plan gorevi ile deterministik calisir
    os.environ["AI_WORKER_ENABLED"] = "false"
    # Odeme, PayTR yerine test simulasyonuyla tamamlanir
    os.environ["PAYMENT_SIMULATION"] = "true"

    import psycopg2

    conn = psycopg2.connect(TEST_DB)
    conn.autocommit = True
    with conn.cursor() as cur:
        cur.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
    conn.close()

    from fastapi.testclient import TestClient
    from yerimebak_ai_v5.main import app
    from yerimebak_ai_v5.services import (
        account_service, checkout_service, dispatch_service, expertiz_service, market_ingest, pricing_service, web_market_reference,
    )

    # Sema bu surecte daha once hazirlandiysa sifirlanan veritabani icin tekrar kur
    dispatch_service._schema_ready = False
    expertiz_service._reports_schema_ensured = False
    pricing_service._schema_ready = False
    checkout_service._schema_ready = False
    account_service._schema_ready = False
    market_ingest._schema_ready = False
    web_market_reference._schema_ready = False

    with TestClient(app, base_url="http://localhost") as test_client:
        yield test_client


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def test_kredili_web_degerleme_onbellek_ve_api_anahtari(client, monkeypatch):
    from yerimebak_ai_v5.services import email_service, web_market_reference as wmr
    from yerimebak_ai_v5.core.database_config import DatabaseConfig

    outbox = email_service.capture_for_tests()
    try:
        reg = client.post("/api/v1/auth/register", json={"email": "webkredi@yerimebak.test",
                          "password": "Musteri123!", "terms_accepted": True})
        assert reg.status_code == 200, reg.text
        token = reg.json()["token"]
        verified = client.post("/api/v1/auth/verify-email",
                               json={"token": _link_token(outbox[-1], "/eposta-dogrula")})
        assert verified.json()["credits_granted"] == 3
    finally:
        email_service.stop_capture()

    calls = []
    listings = [{"url": f"https://www.arabam.com/ilan/seat-ibiza/{i}", "fiyat_tl": p,
                 "km": 30000, "yil": 2024, "paket": "Style", "kondisyon": "temiz"}
                for i, p in enumerate((900000, 925000, 950000))]

    def search(query, _client):
        calls.append(query)
        return {"listings": listings, "sources": {i["url"]: str(i["fiyat_tl"]) for i in listings}, "cost": 0.01}

    monkeypatch.setenv("OPENROUTER_API_KEY", "test-key")
    monkeypatch.setenv("WEB_PRICE_CACHE_HOURS", "24")
    monkeypatch.setattr(wmr, "_search", search)
    payload = {"brand": "Seat", "model": "Ibiza", "year": 2024, "km": 30000,
               "fuel": "Benzin", "transmission": "Otomatik", "listed_price": 960000}
    first = client.post("/api/v1/valuation/analyze", headers=_auth(token), json=payload)
    assert first.status_code == 200, first.text
    body = first.json()
    assert body["piyasa"]["kaynak"] == "web_listings"
    assert len(body["piyasa"]["kaynaklar"]) == 3
    assert body["piyasa"]["kaynaklar"][0]["fiyat"] == 900000
    assert body["piyasa"]["guvenSkoru"] <= 50 and body["piyasa"]["uyarilar"]
    assert "Emsal" in body["karar"]["aciklama"]
    assert body["kredi"] == {"dusulen": 1, "kalan": 2}
    assert len(calls) == 3
    second = client.post("/api/v1/valuation/analyze", headers=_auth(token), json=payload)
    assert second.status_code == 200, second.text
    assert second.json()["kredi"] == {"dusulen": 1, "kalan": 1}
    assert len(calls) == 3

    conn = DatabaseConfig.get_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT api_key FROM users WHERE email = 'webkredi@yerimebak.test'")
        key = dict(cur.fetchone())["api_key"]
        cur.execute("""SELECT valuation_json FROM analysis_history
                       WHERE user_id = (SELECT id FROM users WHERE email = 'webkredi@yerimebak.test')""")
        import json
        histories = [json.loads(r["valuation_json"]) if isinstance(r["valuation_json"], str)
                     else r["valuation_json"] for r in cur.fetchall()]
        assert len(histories) == 2
        assert {h["piyasa_kaynagi"] for h in histories} == {"web_listings"}
        assert sorted(h["web_maliyet_usd"] for h in histories) == [0, 0.03]
    finally:
        DatabaseConfig.return_connection(conn)
    api_payload = {"brand": "Seat", "model": "Ibiza", "year": 2024, "mileage_km": 30000,
                   "fuel_type": "Benzin", "gear_type": "Otomatik", "listed_price": 960000}
    api = client.post("/api/v1/analyze", headers={"X-API-Key": key}, json=api_payload)
    assert api.status_code == 200, api.text
    assert api.json()["market_reference"]["source"] == "web_listings"
    assert api.json()["market_reference"]["scope"]["cached"] is True
    assert api.json()["market_reference"]["scope"]["cost_usd"] == 0
    assert api.json()["billing"]["credits_remaining"] == 0
    assert len(calls) == 3
    conn = DatabaseConfig.get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""SELECT valuation_json FROM analysis_history
                       WHERE user_id = (SELECT id FROM users WHERE email = 'webkredi@yerimebak.test')
                       AND vehicle_json::jsonb->>'source' = 'manual_analysis'""")
        history = dict(cur.fetchone())["valuation_json"]
        if isinstance(history, str):
            history = json.loads(history)
        assert history["piyasa_kaynagi"] == "web_listings"
        assert history["web_maliyet_usd"] == 0
    finally:
        DatabaseConfig.return_connection(conn)


def test_web_onbellek_suresi_dolunca_yeniden_arama(client, monkeypatch):
    from yerimebak_ai_v5.services import web_market_reference as wmr
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    vehicle = {"brand": "Test", "model": "Cache", "year": 2024, "km": 10000}
    calls = []

    def search(query):
        calls.append(query)
        listings = [{"url": f"https://www.arabam.com/ilan/cache/{i}", "fiyat_tl": p, "yil": 2024, "km": 10000}
                    for i, p in enumerate((800000, 810000, 820000))]
        return {"listings": listings, "sources": {i["url"]: str(i["fiyat_tl"]) for i in listings}, "cost": 0.01}

    monkeypatch.setenv("WEB_PRICE_CACHE_HOURS", "24")
    assert wmr.get_reference(vehicle, search=search)["found"]
    assert wmr.get_reference(vehicle, search=search)["scope"]["cached"]
    assert len(calls) == 3
    conn = DatabaseConfig.get_connection()
    try:
        cur = conn.cursor()
        cur.execute("UPDATE web_reference_cache SET created_at = NOW() - INTERVAL '25 hours' WHERE cache_key = %s",
                    (wmr._cache_key(vehicle),))
        conn.commit()
    finally:
        DatabaseConfig.return_connection(conn)
    assert wmr.get_reference(vehicle, search=search)["scope"]["cost_usd"] == 0.03
    assert len(calls) == 6


def test_kredili_emsal_yoksa_kredi_dusmez(client, admin_token, monkeypatch):
    from yerimebak_ai_v5.services import web_market_reference as wmr
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-key")
    monkeypatch.setattr(wmr, "_search", lambda q, c: {"listings": [], "sources": {}})
    before = client.get("/api/v1/credits/balance", headers=_auth(admin_token)).json()["credits"]
    payload = {"brand": "Bulunmayan", "model": "Arac", "year": 2024, "km": 30000, "listed_price": 960000}
    response = client.post("/api/v1/valuation/analyze", headers=_auth(admin_token), json=payload)
    assert response.status_code == 422, response.text
    assert response.json()["detail"]["code"] == "insufficient_market_data"
    api = client.post("/api/v1/analyze", headers=_auth(admin_token), json={
        "brand": "Bulunmayan", "model": "Arac", "year": 2024, "mileage_km": 30000,
        "fuel_type": "Benzin", "gear_type": "Otomatik", "listed_price": 960000})
    assert api.status_code == 422, api.text
    assert client.get("/api/v1/credits/balance", headers=_auth(admin_token)).json()["credits"] == before


def _create_paid_request(client, token, plate, city, note=None, package_index=0, district="Merkez", vehicle=None):
    """Katalogdan paket secer, talep acar ve odemeyi (simulasyon) tamamlar; rapor id doner."""
    firm = client.get("/api/v1/expertiz/packages").json()["firms"][0]
    package = firm["packages"][min(package_index, len(firm["packages"]) - 1)]
    body = {
        "firm_id": firm["id"], "package_id": package["id"], "plate": plate, "city": city, "district": district,
        "contract_accepted": True,
        "vehicle": vehicle or {"brand": "Fiat", "model": "Egea", "year": 2020, "km": 60000, "price": 850000},
    }
    if note:
        body["note"] = note
    created = client.post("/api/v1/expertiz/requests", headers=_auth(token), json=body)
    assert created.status_code == 200, created.text
    paid = client.post(f"/api/v1/payments/checkout/{created.json()['order_id']}/simulate", headers=_auth(token), json={"success": True})
    assert paid.status_code == 200 and paid.json()["status"] == "paid", paid.text
    return created.json()["request_id"]


def _login(client, email, password):
    response = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert response.status_code == 200, response.text
    return response.json()["token"]


@pytest.fixture(scope="module")
def admin_token(client):
    response = client.post(
        "/api/v1/auth/admin/create",
        json={"email": "admin@yerimebak.test", "password": "AdminPass123", "admin_key": ADMIN_KEY},
    )
    assert response.status_code == 200, response.text
    return _login(client, "admin@yerimebak.test", "AdminPass123")


@pytest.fixture(scope="module")
def customer_token(client):
    response = client.post(
        "/api/v1/auth/register",
        json={"email": "musteri@yerimebak.test", "password": "Musteri123!", "full_name": "Ayse Musteri", "phone": "05551112233",
              "terms_accepted": True},
    )
    assert response.status_code == 200, response.text
    return _login(client, "musteri@yerimebak.test", "Musteri123!")


def _create_personnel(client, admin_token, email, city, district, name):
    response = client.post(
        "/api/v1/personnel/admin/personnel",
        headers=_auth(admin_token),
        json={
            "full_name": name,
            "email": email,
            "temporary_password": "Personel123",
            "phone": "",
            "city": city,
            "district": district,
            "expertise": "Kaporta",
        },
    )
    assert response.status_code == 200, response.text
    return response.json()["personnel"]


def test_full_dispatch_flow(client, admin_token, customer_token):
    # --- Personel ekleme + bolge sistemi -------------------------------------
    ist = _create_personnel(client, admin_token, "ist@yerimebak.test", "istanbul", "Kadıköy", "Ali Istanbul")
    ank = _create_personnel(client, admin_token, "ank@yerimebak.test", "ANKARA", "Çankaya", "Veli Ankara")
    assert ist["city"] == "İstanbul" and ist["il_id"] == 34 and ist["region"] == "Marmara"
    assert ank["city"] == "Ankara" and ank["region_id"] == 2

    # Ayni e-posta ve gecersiz il reddedilir
    dup = client.post(
        "/api/v1/personnel/admin/personnel",
        headers=_auth(admin_token),
        json={"full_name": "X", "email": "ist@yerimebak.test", "temporary_password": "Personel123", "city": "İzmir", "district": "Konak"},
    )
    assert dup.status_code == 409
    bad_city = client.post(
        "/api/v1/personnel/admin/personnel",
        headers=_auth(admin_token),
        json={"full_name": "X", "email": "x@yerimebak.test", "temporary_password": "Personel123", "city": "Atlantis", "district": "Merkez"},
    )
    assert bad_city.status_code == 400

    listing = client.get("/api/v1/personnel/admin/personnel", headers=_auth(admin_token)).json()["personnel"]
    assert {p["email"] for p in listing} == {"ist@yerimebak.test", "ank@yerimebak.test"}
    marmara_only = client.get("/api/v1/personnel/admin/personnel?region_id=1", headers=_auth(admin_token)).json()["personnel"]
    assert [p["email"] for p in marmara_only] == ["ist@yerimebak.test"]

    # Personel giris yapabilir ve rolu field_staff olarak doner
    ist_token = _login(client, "ist@yerimebak.test", "Personel123")
    ank_token = _login(client, "ank@yerimebak.test", "Personel123")

    # --- Musteri talebi -------------------------------------------------------
    report_id = _create_paid_request(client, customer_token, "34 TST 34", "istanbul kadikoy", note="Hafta ici", package_index=1)

    # Musteri ve personel admin kuyruguna erisemez
    assert client.get("/api/v1/expertiz/admin/requests", headers=_auth(customer_token)).status_code == 403
    assert client.get("/api/v1/expertiz/admin/requests", headers=_auth(ist_token)).status_code == 403

    queue = client.get("/api/v1/expertiz/admin/requests?bucket=waiting_assignment", headers=_auth(admin_token)).json()
    assert queue["counts"]["waiting_assignment"] == 1
    request = queue["requests"][0]
    assert request["id"] == report_id
    assert request["city"] == "İstanbul" and request["region"] == "Marmara"
    assert request["customer"]["name"] == "Ayse Musteri"

    # Kapsama: Istanbul'da 1 acik atanmamis talep
    coverage = client.get("/api/v1/personnel/admin/coverage", headers=_auth(admin_token)).json()
    assert coverage["summary"]["active_personnel"] == 2
    assert coverage["summary"]["unassigned_request_count"] == 1
    assert coverage["cities"]["İstanbul"]["open_request_count"] == 1
    marmara = next(r for r in coverage["regions"] if r["region_id"] == 1)
    assert marmara["active_personnel"] == 1 and marmara["unassigned_request_count"] == 1
    assert len(coverage["regions"]) == 7
    assert sum(r["province_count"] for r in coverage["regions"]) == 81

    # --- Aday onerisi: ayni il once ------------------------------------------
    candidates = client.get(f"/api/v1/expertiz/admin/requests/{report_id}/candidates", headers=_auth(admin_token)).json()
    assert candidates["recommended_id"] == ist["id"]
    assert candidates["candidates"][0]["match"] == "same_city"
    assert candidates["candidates"][1]["match"] == "other_region"

    # --- Atama ----------------------------------------------------------------
    assigned = client.post(
        f"/api/v1/expertiz/admin/requests/{report_id}/assign",
        headers=_auth(admin_token),
        json={"personnel_id": ist["id"], "note": "Oncelikli"},
    )
    assert assigned.status_code == 200, assigned.text
    body = assigned.json()["request"]
    assert body["bucket"] == "in_progress"
    assert body["assignment"]["personnel_name"] == "Ali Istanbul"
    assert body["durum"] == "Personele Atandı"

    again = client.post(f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token), json={"personnel_id": ist["id"]})
    assert again.status_code == 409

    # --- Personel paneli ------------------------------------------------------
    tasks = client.get("/api/v1/expertiz/personnel/tasks", headers=_auth(ist_token)).json()
    assert tasks["summary"]["active"] == 1 and tasks["summary"]["waiting_acceptance"] == 1
    assert tasks["tasks"][0]["vehicle"]["plate"] == "34 TST 34"
    assert client.get("/api/v1/expertiz/personnel/tasks", headers=_auth(ank_token)).json()["tasks"] == []
    # Baskasinin gorevine dokunamaz; admin personel endpointini kullanamaz
    assert client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/accept", headers=_auth(ank_token)).status_code == 403
    assert client.get("/api/v1/expertiz/personnel/tasks", headers=_auth(admin_token)).status_code == 403

    accepted = client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/accept", headers=_auth(ist_token))
    assert accepted.status_code == 200 and accepted.json()["task"]["assignment"]["status"] == "accepted"
    started = client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/start", headers=_auth(ist_token))
    assert started.status_code == 200 and started.json()["task"]["assignment"]["status"] == "in_progress"
    assert started.json()["task"]["durum"] == "İncelemede"

    # Personel listesinde acik gorev sayisi
    listing = {p["email"]: p for p in client.get("/api/v1/personnel/admin/personnel", headers=_auth(admin_token)).json()["personnel"]}
    assert listing["ist@yerimebak.test"]["open_task_count"] == 1

    # --- Yeniden atama ve pasife alma ile otomatik serbest birakma -----------
    re = client.post(f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token), json={"personnel_id": ank["id"]})
    assert re.status_code == 200
    assert [h["action"] for h in re.json()["request"]["assignment"]["history"]][-1] == "reassigned"
    assert client.get("/api/v1/expertiz/personnel/tasks", headers=_auth(ist_token)).json()["tasks"] == []

    deactivated = client.post(
        f"/api/v1/personnel/admin/personnel/{ank['id']}/deactivate",
        headers=_auth(admin_token),
        json={"reason": "Izinli"},
    )
    assert deactivated.status_code == 200
    assert deactivated.json()["released_task_ids"] == [report_id]
    queue = client.get("/api/v1/expertiz/admin/requests?bucket=waiting_assignment", headers=_auth(admin_token)).json()
    assert [r["id"] for r in queue["requests"]] == [report_id]

    # Pasif personele atama yapilamaz, pasif personel giris yapamaz
    blocked = client.post(f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token), json={"personnel_id": ank["id"]})
    assert blocked.status_code == 409
    assert client.post("/api/v1/auth/login", json={"email": "ank@yerimebak.test", "password": "Personel123"}).status_code == 401

    # --- Atama kaldirma + sistemden cikarma -----------------------------------
    client.post(f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token), json={"personnel_id": ist["id"]})
    removed = client.request("DELETE", f"/api/v1/personnel/admin/personnel/{ist['id']}", headers=_auth(admin_token), json={"reason": "Isten ayrildi"})
    assert removed.status_code == 200, removed.text
    assert removed.json()["released_task_count"] == 1
    remaining = client.get("/api/v1/personnel/admin/personnel", headers=_auth(admin_token)).json()["personnel"]
    assert [p["email"] for p in remaining] == ["ank@yerimebak.test"]
    assert client.post("/api/v1/auth/login", json={"email": "ist@yerimebak.test", "password": "Personel123"}).status_code == 401

    # Sadece personel silinebilir (admin/musteri bu endpointten silinemez)
    admin_me = client.get("/api/v1/auth/me", headers=_auth(admin_token)).json()["user"]
    assert client.request("DELETE", f"/api/v1/personnel/admin/personnel/{admin_me['id']}", headers=_auth(admin_token)).status_code == 404

    final = client.get(f"/api/v1/expertiz/admin/requests/{report_id}", headers=_auth(admin_token)).json()["request"]
    assert final["bucket"] == "waiting_assignment"
    actions = [h["action"] for h in final["assignment"]["history"]]
    assert actions == ["assigned", "accept", "start", "reassigned", "released", "assigned", "released"]



JPEG_BYTES = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00" + b"\x00" * 200 + b"\xff\xd9"
PDF_BYTES = b"%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n"


def _tam_rapor(report_id, personnel_id):
    base = {"gorevId": report_id, "personelId": personnel_id}
    return {
        **base,
        "adim1": {**base, "marka": "Fiat", "model": "Egea", "yil": "2021", "plaka": "34 TST 35", "guncelKm": 45000},
        "adim2": {**base, "maddeDurumlari": {"onTampon": "Sorunlu"}},
        "adim3": {**base, "maddeDurumlari": {"direksiyon": "İyi"}},
        "adim4": {**base, "parcalar": {"kaput": {"durum": "boyali"}}},
        "adim5": {**base, "kurumsalRaporNo": "PG-123"},
        "durum": "Onay Bekliyor",
    }


def test_inspection_report_photos_and_submit(client, admin_token, customer_token):
    person = _create_personnel(client, admin_token, "rapor@yerimebak.test", "İstanbul", "Beşiktaş", "Rapor Personel")
    token = _login(client, "rapor@yerimebak.test", "Personel123")
    report_id = _create_paid_request(client, customer_token, "34 TST 35", "İstanbul", package_index=3)
    assert client.post(
        f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token), json={"personnel_id": person["id"]}
    ).status_code == 200
    assert client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/start", headers=_auth(token)).status_code == 200

    detail = client.get(f"/api/v1/expertiz/personnel/tasks/{report_id}/report", headers=_auth(token)).json()
    assert detail["editable"] is True
    assert detail["corporate"]["required"] is True
    assert detail["tam_rapor"] is None

    # Hasar fotografi yukle (dosya turu icerikten belirlenir)
    photo = client.post(
        f"/api/v1/expertiz/personnel/tasks/{report_id}/media",
        headers=_auth(token),
        files={"file": ("tampon.jpg", JPEG_BYTES, "image/jpeg")},
        data={"category": "inspection_photo", "section": "dis", "item_key": "onTampon", "item_label": "Ön Tampon", "note": "Çizik"},
    )
    assert photo.status_code == 200, photo.text
    photo_media = photo.json()["media"]
    assert photo_media["is_image"] and photo_media["item_key"] == "onTampon"

    fake = client.post(
        f"/api/v1/expertiz/personnel/tasks/{report_id}/media",
        headers=_auth(token),
        files={"file": ("virus.jpg", b"MZ\x90\x00not-an-image", "image/jpeg")},
        data={"category": "inspection_photo"},
    )
    assert fake.status_code == 415
    pdf_as_photo = client.post(
        f"/api/v1/expertiz/personnel/tasks/{report_id}/media",
        headers=_auth(token),
        files={"file": ("x.pdf", PDF_BYTES, "application/pdf")},
        data={"category": "inspection_photo"},
    )
    assert pdf_as_photo.status_code == 415

    # Imzali URL ile dosya okunur, imzasiz/bozuk imza reddedilir
    got = client.get(photo_media["url"])
    assert got.status_code == 200 and got.content == JPEG_BYTES
    assert client.get(photo_media["url"].replace("sig=", "sig=0")).status_code == 403

    # Taslak kaydet
    rapor = _tam_rapor(report_id, person["id"])
    assert client.put(f"/api/v1/expertiz/personnel/tasks/{report_id}/draft", headers=_auth(token), json={"tam_rapor": rapor}).status_code == 200
    assert client.get(f"/api/v1/expertiz/personnel/tasks/{report_id}/report", headers=_auth(token)).json()["tam_rapor"]["adim5"]["kurumsalRaporNo"] == "PG-123"

    # Kurumsal rapor eklenmeden gonderilemez
    blocked = client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/submit", headers=_auth(token), json={"tam_rapor": rapor})
    assert blocked.status_code == 409 and "kurumsal" in blocked.json()["detail"].lower()

    corp = client.post(
        f"/api/v1/expertiz/personnel/tasks/{report_id}/media",
        headers=_auth(token),
        files={"file": ("pilot_garage_rapor.pdf", PDF_BYTES, "application/pdf")},
        data={"category": "corporate_report", "section": "kurumsal"},
    )
    assert corp.status_code == 200, corp.text

    # Eksik bolumlu rapor reddedilir
    bad = client.post(
        f"/api/v1/expertiz/personnel/tasks/{report_id}/submit",
        headers=_auth(token),
        json={"tam_rapor": {"adim1": {}}},
    )
    assert bad.status_code == 400

    # Musteri yayinlanmadan raporu goremez
    assert client.get(f"/api/v1/expertiz/reports/{report_id}", headers=_auth(customer_token)).status_code == 404

    submitted = client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/submit", headers=_auth(token), json={"tam_rapor": rapor})
    assert submitted.status_code == 200, submitted.text
    assert submitted.json()["task"]["bucket"] == "pending_approval"

    # Gonderildikten sonra degistirilemez
    assert client.put(f"/api/v1/expertiz/personnel/tasks/{report_id}/draft", headers=_auth(token), json={"tam_rapor": rapor}).status_code == 409
    tasks = client.get("/api/v1/expertiz/personnel/tasks", headers=_auth(token)).json()
    assert tasks["summary"]["active"] == 0 and tasks["summary"]["completed"] == 1

    # Admin: rapor, fotograflar ve kurumsal rapor gorunur
    queue = client.get("/api/v1/expertiz/admin/requests?bucket=pending_approval", headers=_auth(admin_token)).json()
    assert report_id in [r["id"] for r in queue["requests"]]
    admin_report = client.get(f"/api/v1/expertiz/admin/reports/{report_id}", headers=_auth(admin_token)).json()["report"]
    assert admin_report["status"] in ("pending_ai", "pending_admin")
    assert admin_report["data"]["tam_rapor"]["adim1"]["marka"] == "Fiat"
    assert len(admin_report["photos"]) == 1 and len(admin_report["corporate_reports"]) == 1
    assert admin_report["photos"][0]["note"] == "Çizik"
    assert client.get(admin_report["corporate_reports"][0]["url"]).content == PDF_BYTES

    # Admin reddederse personel duzeltip tekrar gonderir
    if admin_report["status"] == "pending_admin":
        rejected = client.post(
            f"/api/v1/expertiz/admin/reports/{report_id}/reject", headers=_auth(admin_token), json={"reason": "Arka tampon fotografi eksik"}
        )
        assert rejected.status_code == 200, rejected.text
        again = client.get(f"/api/v1/expertiz/personnel/tasks/{report_id}/report", headers=_auth(token)).json()
        assert again["editable"] and again["rejection_reason"] == "Arka tampon fotografi eksik"
        assert client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/start", headers=_auth(token)).status_code == 200
        client.post(
            f"/api/v1/expertiz/personnel/tasks/{report_id}/media",
            headers=_auth(token),
            files={"file": ("arka.jpg", JPEG_BYTES, "image/jpeg")},
            data={"category": "inspection_photo", "section": "dis", "item_key": "arkaTampon"},
        )
        resubmitted = client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/submit", headers=_auth(token), json={"tam_rapor": rapor})
        assert resubmitted.status_code == 200

        admin_report = client.get(f"/api/v1/expertiz/admin/reports/{report_id}", headers=_auth(admin_token)).json()["report"]
        assert admin_report["inspection"]["revision"] == 1
        assert len(admin_report["photos"]) == 2

    # Admin yayinlarsa musteri raporu, fotograflari ve kurumsal raporu gorur
    if admin_report["status"] == "pending_admin" and admin_report["can_publish"]:
        published = client.post(f"/api/v1/expertiz/admin/reports/{report_id}/publish", headers=_auth(admin_token))
        assert published.status_code == 200, published.text
        customer_view = client.get(f"/api/v1/expertiz/reports/{report_id}", headers=_auth(customer_token)).json()["report"]
        assert len(customer_view["photos"]) >= 1 and len(customer_view["corporate_reports"]) == 1
        assert client.get(customer_view["photos"][0]["url"]).status_code == 200
    else:
        pytest.fail(f"AI analizi raporu admin onayina tasimadi: {admin_report['status']} / {admin_report.get('ai_meta')}")


def _seed_listings(count=12, base_price=900_000):
    import psycopg2

    conn = psycopg2.connect(TEST_DB)
    with conn, conn.cursor() as cur:
        for i in range(count):
            cur.execute(
                """
                INSERT INTO listings (brand, model, year, km, price, fuel, transmission, source, url, paint_info, updated_at)
                VALUES ('Fiat', 'Egea', 2021, %s, %s, 'Benzin', 'Manuel', 'test', %s, %s, NOW())
                """,
                (40_000 + i * 2_000, base_price + (i - count // 2) * 5_000, f"https://test/egea/{uuid.uuid4()}",
                 "Boyasız/Değişensiz" if i % 2 == 0 else ""),
            )
    conn.close()


def test_unpaid_customer_to_staff_to_approved_customer_report(client, admin_token, customer_token):
    """Izole DB: odemesiz talep, ilce atamasi, AI ve admin onayi."""
    _seed_listings()
    person = _create_personnel(client, admin_token, 'e2e-unpaid@yerimebak.test', 'İstanbul', 'Kadıköy', 'Test Personel')
    staff_token = _login(client, 'e2e-unpaid@yerimebak.test', 'Personel123')
    catalog = client.get('/api/v1/expertiz/packages').json()
    firm = catalog['firms'][0]
    package = firm['packages'][0]
    created = client.post('/api/v1/expertiz/requests/unpaid', headers=_auth(customer_token), json={
        'firm_id': firm['id'], 'package_id': package['id'], 'city': 'İstanbul', 'district': 'Kadıköy',
        'plate': '34 TEST 01', 'vehicle': {'brand': 'Fiat', 'model': 'Egea', 'year': 2021, 'km': 45000},
    })
    assert created.status_code == 200, created.text
    assert created.json()['payment_status'] == 'not_collected'
    report_id = created.json()['request_id']
    assert client.get('/api/v1/expertiz/admin/requests', headers=_auth(customer_token)).status_code == 403
    assert client.get('/api/v1/expertiz/admin/requests', headers=_auth(staff_token)).status_code == 403
    queue = client.get('/api/v1/expertiz/admin/requests?bucket=waiting_assignment', headers=_auth(admin_token)).json()
    entry = next(r for r in queue['requests'] if r['id'] == report_id)
    assert entry['is_paid'] is False and entry['district'] == 'Kadıköy'
    candidates = client.get(f'/api/v1/expertiz/admin/requests/{report_id}/candidates', headers=_auth(admin_token)).json()
    assert candidates['recommended_id'] == person['id']
    assert candidates['candidates'][0]['match'] == 'same_district'
    assigned = client.post(f'/api/v1/expertiz/admin/requests/{report_id}/assign', headers=_auth(admin_token), json={'personnel_id': person['id']})
    assert assigned.status_code == 200, assigned.text
    tasks = client.get('/api/v1/expertiz/personnel/tasks', headers=_auth(staff_token)).json()['tasks']
    assert any(task['id'] == report_id for task in tasks)
    assert client.post(f'/api/v1/expertiz/personnel/tasks/{report_id}/start', headers=_auth(staff_token)).status_code == 200
    assert client.get(f'/api/v1/expertiz/reports/{report_id}', headers=_auth(customer_token)).status_code == 404
    media = client.post(f'/api/v1/expertiz/personnel/tasks/{report_id}/media', headers=_auth(staff_token),
                        files={'file': ('test.pdf', PDF_BYTES, 'application/pdf')}, data={'category': 'corporate_report'})
    assert media.status_code == 200, media.text
    submitted = client.post(f'/api/v1/expertiz/personnel/tasks/{report_id}/submit', headers=_auth(staff_token),
                            json={'tam_rapor': _tam_rapor(report_id, person['id'])})
    assert submitted.status_code == 200, submitted.text
    admin_report = client.get(f'/api/v1/expertiz/admin/reports/{report_id}', headers=_auth(admin_token)).json()['report']
    assert admin_report['status'] == 'pending_admin', admin_report.get('ai_meta')
    assert admin_report['can_publish'] is True
    assert admin_report['ai_analiz_detay']['marketReference']['source'] == 'listings'
    assert client.get(f'/api/v1/expertiz/reports/{report_id}', headers=_auth(customer_token)).status_code == 404
    rejected = client.post(f'/api/v1/expertiz/admin/reports/{report_id}/reject', headers=_auth(admin_token),
                           json={'reason': 'Kontrol fotoğrafı eksik'})
    assert rejected.status_code == 200, rejected.text
    draft = client.get(f'/api/v1/expertiz/personnel/tasks/{report_id}/report', headers=_auth(staff_token)).json()
    assert draft['editable'] and draft['rejection_reason'] == 'Kontrol fotoğrafı eksik'
    assert client.get(f'/api/v1/expertiz/reports/{report_id}', headers=_auth(customer_token)).status_code == 404
    assert client.post(f'/api/v1/expertiz/personnel/tasks/{report_id}/start', headers=_auth(staff_token)).status_code == 200
    resubmitted = client.post(f'/api/v1/expertiz/personnel/tasks/{report_id}/submit', headers=_auth(staff_token),
                              json={'tam_rapor': _tam_rapor(report_id, person['id'])})
    assert resubmitted.status_code == 200, resubmitted.text
    admin_report = client.get(f'/api/v1/expertiz/admin/reports/{report_id}', headers=_auth(admin_token)).json()['report']
    assert admin_report['status'] == 'pending_admin' and admin_report['can_publish'] is True
    published = client.post(f'/api/v1/expertiz/admin/reports/{report_id}/publish', headers=_auth(admin_token))
    assert published.status_code == 200, published.text
    customer = client.get(f'/api/v1/expertiz/reports/{report_id}', headers=_auth(customer_token))
    assert customer.status_code == 200, customer.text
    assert customer.json()['report']['status'] == 'published'


def test_ai_valuation_admin_approval_and_customer_view(client, admin_token, customer_token):
    """Personel raporu -> merkezi AI (piyasa - ekspertiz değer kaybı) -> admin onayı -> müşteri."""
    _seed_listings()
    person = _create_personnel(client, admin_token, "ai@yerimebak.test", "İstanbul", "Şişli", "AI Personel")
    token = _login(client, "ai@yerimebak.test", "Personel123")
    report_id = _create_paid_request(client, customer_token, "34 AI 01", "İstanbul", package_index=3)
    client.post(f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token), json={"personnel_id": person["id"]})
    client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/start", headers=_auth(token))
    client.post(
        f"/api/v1/expertiz/personnel/tasks/{report_id}/media",
        headers=_auth(token),
        files={"file": ("kurumsal.pdf", PDF_BYTES, "application/pdf")},
        data={"category": "corporate_report", "section": "kurumsal"},
    )

    rapor = _tam_rapor(report_id, person["id"])
    # Kullanıcı örneği: iki kapı değişen, arka çamurluk boyalı
    rapor["adim4"] = {"gorevId": report_id, "personelId": person["id"],
                      "parcaDurumlari": {"solOnKapi": "degisen", "sagOnKapi": "degisen", "solArkaCamurluk": "boyali"},
                      "yapisalDurumlar": {"onSasi": "orijinal"}}
    submitted = client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/submit", headers=_auth(token), json={"tam_rapor": rapor})
    assert submitted.status_code == 200, submitted.text

    admin_report = client.get(f"/api/v1/expertiz/admin/reports/{report_id}", headers=_auth(admin_token)).json()["report"]
    assert admin_report["status"] == "pending_admin", admin_report.get("ai_meta")
    assert admin_report["can_publish"] is True
    ai = admin_report["ai_analiz_detay"]
    degerleme = ai["ekspertizDegerleme"]
    assert degerleme["degerlemeYapildi"] is True
    assert degerleme["degisenParcaSayisi"] == 2 and degerleme["boyaliParcaSayisi"] == 1
    assert {k["anahtar"] for k in degerleme["kalemler"]} >= {"solOnKapi", "sagOnKapi", "solArkaCamurluk"}
    assert degerleme["aiDegeri"] < degerleme["temizPiyasaDegeri"]
    assert 7 <= degerleme["toplamDegerKaybiYuzde"] <= 14
    assert ai["raporOzeti"]["tahminiDeger"] == degerleme["aiDegeri"]
    assert ai["marketReference"]["source"] == "listings" and ai["marketReference"]["clean_count"] >= 3

    # Müşteri / personel AI'yı tetikleyemez veya yeniden çalıştıramaz
    assert client.post("/api/v1/trigger", headers=_auth(customer_token), json={"report_id": report_id}).status_code == 403
    assert client.get(f"/api/v1/status/{report_id}", headers=_auth(customer_token)).status_code == 403
    assert client.post(f"/api/v1/expertiz/admin/reports/{report_id}/reanalyze", headers=_auth(token)).status_code == 403

    # Admin yeniden analiz edebilir (sonuç aynı bulgulardan deterministik)
    re_run = client.post(f"/api/v1/expertiz/admin/reports/{report_id}/reanalyze", headers=_auth(admin_token))
    assert re_run.status_code == 200, re_run.text
    assert re_run.json()["report"]["status"] == "pending_admin"
    assert re_run.json()["report"]["ai_analiz_detay"]["ekspertizDegerleme"]["aiDegeri"] == degerleme["aiDegeri"]

    # Admin onayı ile yayın (müşteriye not)
    published = client.post(
        f"/api/v1/expertiz/admin/reports/{report_id}/publish",
        headers=_auth(admin_token),
        json={"admin_note": "Değişen kapılar pazarlıkta dikkate alınmalı."},
    )
    assert published.status_code == 200, published.text

    # Yayınlanan rapor AI tarafından artık değiştirilemez
    assert client.post(f"/api/v1/expertiz/admin/reports/{report_id}/reanalyze", headers=_auth(admin_token)).status_code == 400
    from yerimebak_ai_v5.core.supabase_bridge import get_supabase_bridge
    assert get_supabase_bridge().write_ai_results(report_id, {"tamamlandiMi": True}) is False

    # Müşteri: personel raporu + kurumsal rapor + AI değerlemesi birlikte
    customer = client.get(f"/api/v1/expertiz/reports/{report_id}", headers=_auth(customer_token)).json()["report"]
    assert customer["status"] == "published"
    assert customer["report"]["adim4"]["parcaDurumlari"]["solOnKapi"] == "degisen"
    assert len(customer["corporate_reports"]) == 1
    assert customer["summary"]["market_value"] == degerleme["aiDegeri"]
    assert customer["summary"]["value_loss_pct"] == degerleme["toplamDegerKaybiYuzde"]
    assert customer["summary"]["ai_comment"]
    assert customer["ai"]["ekspertizDegerleme"]["kalemler"]
    assert "marketReference" not in customer["ai"] and customer["ai"]["piyasaReferansi"]["bulundu"] is True
    assert "url" not in customer["ai"]["piyasaReferansi"]["emsaller"][0]
    assert customer["admin_note"] == "Değişen kapılar pazarlıkta dikkate alınmalı."
    listed = client.get("/api/v1/expertiz/reports", headers=_auth(customer_token)).json()["reports"]
    assert report_id in [r["id"] for r in listed]


def test_ai_worker_loop_recovers_stuck_reports(client):
    """Arka plan görevi düşerse polling döngüsü bekleyen pending_ai raporlarını tamamlar."""
    import asyncio
    import json as _json

    import psycopg2

    from yerimebak_ai_v5.workers.ai_analysis_worker import get_ai_analysis_worker

    tam = {"adim1": {"marka": "Fiat", "model": "Egea", "yil": 2021, "guncelKm": 50_000},
           "adim4": {"parcaDurumlari": {"kaput": "boyali"}}}
    stuck_id, fresh_id = str(uuid.uuid4()), str(uuid.uuid4())
    conn = psycopg2.connect(TEST_DB)
    with conn, conn.cursor() as cur:
        for rid, age in ((stuck_id, "10 minutes"), (fresh_id, "0 seconds")):
            cur.execute(
                "INSERT INTO reports (id, status, data, ai_analizi_yapildi_mi, status_updated_at) "
                "VALUES (%s, 'pending_ai', %s::jsonb, FALSE, NOW() - %s::interval)",
                (rid, _json.dumps({"vehicle_snapshot": {"price": 880_000}, "tam_rapor": tam}), age),
            )
    processed = asyncio.run(get_ai_analysis_worker().run_once(min_age_seconds=60))
    assert processed >= 1
    with conn, conn.cursor() as cur:
        cur.execute("SELECT id::text, status FROM reports WHERE id::text IN (%s, %s)", (stuck_id, fresh_id))
        statuses = dict(cur.fetchall())
    conn.close()
    assert statuses[stuck_id] == "pending_admin"
    assert statuses[fresh_id] == "pending_ai"  # yeni gönderilen, arka plan görevine bırakılır


def _notes(client, token, admin=False):
    path = "/api/v1/expertiz/admin/notifications" if admin else "/api/v1/expertiz/notifications"
    response = client.get(f"{path}?limit=100", headers=_auth(token))
    assert response.status_code == 200, response.text
    return response.json()


def _customer_request(client, token, report_id):
    rows = client.get("/api/v1/expertiz/requests", headers=_auth(token)).json()["requests"]
    return next(r for r in rows if r["report_id"] == report_id)


def test_field_flow_duty_district_live_status_and_notifications(client, admin_token, customer_token):
    """Gorev icin aktif/pasif + ilce onceligi + saha adimlari + red/duzeltme + onay bildirimleri."""
    a = _create_personnel(client, admin_token, "ksk1@yerimebak.test", "İzmir", "Karşıyaka", "Kemal Saha")
    b = _create_personnel(client, admin_token, "brn@yerimebak.test", "İzmir", "Bornova", "Burak Bornova")
    c = _create_personnel(client, admin_token, "ksk2@yerimebak.test", "İzmir", "Karşıyaka", "Cem Pasif")
    a_token = _login(client, "ksk1@yerimebak.test", "Personel123")
    c_token = _login(client, "ksk2@yerimebak.test", "Personel123")

    # Il/ilce olmadan talep acilamaz
    firm = client.get("/api/v1/expertiz/packages").json()["firms"][0]
    no_district = client.post(
        "/api/v1/expertiz/requests", headers=_auth(customer_token),
        json={"firm_id": firm["id"], "package_id": firm["packages"][0]["id"], "city": "İzmir",
              "vehicle": {"brand": "Fiat", "model": "Egea"}, "contract_accepted": True},
    )
    assert no_district.status_code == 400 and "ilce" in no_district.json()["detail"]

    # Personel kendini gorev icin pasif yapar -> admin bildirimi
    me = client.get("/api/v1/expertiz/personnel/me", headers=_auth(c_token)).json()["personnel"]
    assert me["on_duty"] is True
    off = client.put("/api/v1/expertiz/personnel/me/duty", headers=_auth(c_token), json={"on_duty": False})
    assert off.status_code == 200 and off.json()["personnel"]["on_duty"] is False
    assert any(n["kind"] == "duty_changed" and "Cem Pasif" in n["title"] for n in _notes(client, admin_token, admin=True)["notifications"])
    # Musteri/admin personel endpointini kullanamaz
    assert client.put("/api/v1/expertiz/personnel/me/duty", headers=_auth(customer_token), json={"on_duty": True}).status_code == 403

    report_id = _create_paid_request(client, customer_token, "35 KSK 35", "İzmir", package_index=3, district="karsiyaka")

    # Aday sirasi: ayni ilce -> ayni il -> diger; pasif personel en sonda ve atanamaz
    cand = client.get(f"/api/v1/expertiz/admin/requests/{report_id}/candidates", headers=_auth(admin_token)).json()
    ids = [p["id"] for p in cand["candidates"]]
    assert cand["request"]["district"] == "karsiyaka"
    assert ids[0] == a["id"] and cand["candidates"][0]["match"] == "same_district"
    assert ids[1] == b["id"] and cand["candidates"][1]["match"] == "same_city"
    assert ids[-1] == c["id"] and cand["candidates"][-1]["assignable"] is False
    assert cand["recommended_id"] == a["id"]
    blocked = client.post(f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token), json={"personnel_id": c["id"]})
    assert blocked.status_code == 409 and "pasif" in blocked.json()["detail"]

    assert client.post(f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token), json={"personnel_id": a["id"]}).status_code == 200
    assert any(n["kind"] == "task_assigned" and n["report_id"] == report_id for n in _notes(client, a_token)["notifications"])
    progress = _customer_request(client, customer_token, report_id)["progress"]
    assert progress["label"] == "Ekspertiz uzmanı atandı" and progress["person_name"] == "Kemal S."

    # Saha adimlari: her biri musteri + admin bildirimi uretir
    task = client.get("/api/v1/expertiz/personnel/tasks", headers=_auth(a_token)).json()["tasks"][0]
    assert task["next_actions"] == ["accept", "depart", "arrive", "corporate", "start"]
    expected = [
        ("accept", "accepted", "Ekspertiz uzmanı atandı"),
        ("depart", "on_the_way", "Uzman harekete geçti"),
        ("arrive", "at_vehicle", "Uzman araç başında"),
        ("corporate", "at_corporate", "Kurumsal ekspertizde"),
        ("start", "in_progress", "Rapor hazırlanıyor"),
    ]
    for action, stage, label in expected:
        r = client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/{action}", headers=_auth(a_token))
        assert r.status_code == 200, (action, r.text)
        assert r.json()["task"]["assignment"]["status"] == stage
        assert _customer_request(client, customer_token, report_id)["progress"]["label"] == label
    # Geri adim yapilamaz
    assert client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/depart", headers=_auth(a_token)).status_code == 409

    customer_titles = [n["title"] for n in _notes(client, customer_token)["notifications"] if n["report_id"] == report_id]
    for title in ("Ekspertiz uzmanınız atandı", "Uzmanınız yola çıktı", "Uzmanınız araç başında",
                  "Aracınız kurumsal ekspertizde", "Raporunuz hazırlanıyor"):
        assert title in customer_titles, (title, customer_titles)
    admin_titles = [n["title"] for n in _notes(client, admin_token, admin=True)["notifications"] if n["report_id"] == report_id]
    for title in ("Görev kabul edildi", "Personel harekete geçti", "Personel araç başında", "Kurumsal ekspertizde"):
        assert title in admin_titles, (title, admin_titles)

    # Rapor gonder -> personel "beklemede"
    client.post(
        f"/api/v1/expertiz/personnel/tasks/{report_id}/media", headers=_auth(a_token),
        files={"file": ("kurumsal.pdf", PDF_BYTES, "application/pdf")}, data={"category": "corporate_report"},
    )
    rapor = _tam_rapor(report_id, a["id"])
    assert client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/submit", headers=_auth(a_token), json={"tam_rapor": rapor}).status_code == 200
    mine = client.get("/api/v1/expertiz/personnel/tasks", headers=_auth(a_token)).json()
    assert mine["summary"]["buckets"]["pending"] == 1
    assert "Rapor onaya geldi" in [n["title"] for n in _notes(client, admin_token, admin=True)["notifications"]]

    # Admin reddeder -> personel "reddedildi" + bildirim; musteri reddi gormez
    rejected = client.post(f"/api/v1/expertiz/admin/reports/{report_id}/reject", headers=_auth(admin_token), json={"reason": "Motor fotografi eksik"})
    assert rejected.status_code == 200, rejected.text
    assert rejected.json()["report"]["durum"] == "Düzeltme Gerekli"
    mine = client.get("/api/v1/expertiz/personnel/tasks", headers=_auth(a_token)).json()
    t = next(x for x in mine["tasks"] if x["id"] == report_id)
    assert t["personnel_bucket"] == "rejected" and t["rejection_reason"] == "Motor fotografi eksik"
    assert t["next_actions"] == ["start"]
    rej = next(n for n in _notes(client, a_token)["notifications"] if n["kind"] == "report_rejected")
    assert "Motor fotografi eksik" in rej["body"]
    cust = _customer_request(client, customer_token, report_id)
    assert cust["progress"]["stage"] == "review" and cust["progress"]["label"] == "Rapor kontrol ediliyor"
    assert not any(n["kind"] == "report_rejected" for n in _notes(client, customer_token)["notifications"])

    # Duzeltip tekrar gonderir
    assert client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/start", headers=_auth(a_token)).status_code == 200
    assert client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/submit", headers=_auth(a_token), json={"tam_rapor": rapor}).status_code == 200
    assert "Düzeltilmiş rapor onaya geldi" in [n["title"] for n in _notes(client, admin_token, admin=True)["notifications"]]

    admin_report = client.get(f"/api/v1/expertiz/admin/reports/{report_id}", headers=_auth(admin_token)).json()["report"]
    assert admin_report["status"] == "pending_admin", admin_report.get("ai_meta")
    assert client.post(f"/api/v1/expertiz/admin/reports/{report_id}/publish", headers=_auth(admin_token)).status_code == 200

    # Onay -> personel "onaylandi" + bildirim, musteriye "raporunuz hazir"
    mine = client.get("/api/v1/expertiz/personnel/tasks", headers=_auth(a_token)).json()
    assert next(x for x in mine["tasks"] if x["id"] == report_id)["personnel_bucket"] == "approved"
    assert mine["summary"]["approved"] == 1
    assert any(n["kind"] == "report_approved" for n in _notes(client, a_token)["notifications"])
    assert any(n["kind"] == "report_ready" for n in _notes(client, customer_token)["notifications"])
    cust = _customer_request(client, customer_token, report_id)
    assert cust["progress"]["stage"] == "published" and all(s["done"] for s in cust["progress"]["steps"])

    # Okundu isaretleme
    unread = _notes(client, a_token)["unread"]
    assert unread >= 3
    assert client.post("/api/v1/expertiz/notifications/read", headers=_auth(a_token), json={}).json()["updated"] == unread
    assert _notes(client, a_token)["unread"] == 0
    # Baskasinin bildirimini okuyamaz / gormez
    assert not any(n["kind"] == "task_assigned" for n in _notes(client, c_token)["notifications"])

    # Admin personeli tekrar aktif yapabilir; personel bildirim alir
    on = client.put(f"/api/v1/expertiz/admin/personnel/{c['id']}/duty", headers=_auth(admin_token), json={"on_duty": True})
    assert on.status_code == 200 and on.json()["personnel"]["on_duty"] is True
    assert any(n["kind"] == "duty_changed" for n in _notes(client, c_token)["notifications"])
    assert client.put(f"/api/v1/expertiz/admin/personnel/{c['id']}/duty", headers=_auth(c_token), json={"on_duty": True}).status_code == 403


def _link_token(message, path):
    import re as _re

    body = message.get_body(preferencelist=("plain",)).get_content()
    match = _re.search(rf"{path}\?token=([A-Za-z0-9_\-]+)", body)
    assert match, body
    return match.group(1)


def test_accounts_refunds_invoices_and_emails(client, admin_token):
    """E-posta dogrulama + hos geldin kredisi, sifre sifirlama, iptal/iade, fatura dokumu, e-posta bildirimleri."""
    from yerimebak_ai_v5.services import email_service

    outbox = email_service.capture_for_tests()
    try:
        # --- Kayit: kredi hemen verilmez, dogrulama e-postasi gider
        # Kullanim kosullari / KVKK onayi olmadan kayit olunamaz
        no_terms = client.post("/api/v1/auth/register", json={"email": "onaysiz@yerimebak.test", "password": "Musteri123!"})
        assert no_terms.status_code == 400
        reg = client.post("/api/v1/auth/register", json={"email": "Yeni@Yerimebak.test", "password": "Musteri123!",
                                                           "full_name": "Yeni Musteri", "terms_accepted": True})
        assert reg.status_code == 200, reg.text
        assert reg.json()["user"]["credits"] == 0 and reg.json()["email_verification_required"] is True
        token = reg.json()["token"]
        verify_mail = next(m for m in outbox if m["To"] == "yeni@yerimebak.test")
        vtoken = _link_token(verify_mail, "/eposta-dogrula")
        assert client.get("/api/v1/auth/profile", headers=_auth(token)).json()["profile"]["email_verified"] is False

        ok = client.post("/api/v1/auth/verify-email", json={"token": vtoken})
        assert ok.status_code == 200 and ok.json()["credits_granted"] == 3
        # Ayni baglanti ikinci kez kullanilamaz, kredi iki kez verilmez
        assert client.post("/api/v1/auth/verify-email", json={"token": vtoken}).status_code == 400
        profile = client.get("/api/v1/auth/profile", headers=_auth(token)).json()["profile"]
        assert profile["email_verified"] is True and profile["credits"] == 3
        assert client.post("/api/v1/auth/resend-verification", headers=_auth(token)).json()["already_verified"] is True

        # --- Sifremi unuttum: kayitli olmayan e-postada da ayni yanit
        unknown = client.post("/api/v1/auth/forgot-password", json={"email": "yok@yerimebak.test"})
        known = client.post("/api/v1/auth/forgot-password", json={"email": "yeni@yerimebak.test"})
        assert unknown.status_code == known.status_code == 200 and unknown.json() == known.json()
        reset_mail = [m for m in outbox if "Sifre sifirlama" in m["Subject"]]
        assert len(reset_mail) == 1
        rtoken = _link_token(reset_mail[0], "/sifre-sifirla")
        assert client.post("/api/v1/auth/reset-password", json={"token": rtoken, "new_password": "zayif"}).status_code == 400
        assert client.post("/api/v1/auth/reset-password", json={"token": rtoken, "new_password": "YeniSifre123"}).status_code == 200
        assert client.post("/api/v1/auth/reset-password", json={"token": rtoken, "new_password": "BaskaSifre123"}).status_code == 400
        assert client.post("/api/v1/auth/login", json={"email": "yeni@yerimebak.test", "password": "Musteri123!"}).status_code == 401
        token = _login(client, "yeni@yerimebak.test", "YeniSifre123")

        # --- SMS / telefonla kayit uclari kaldirildi
        for path in ("/api/v1/auth/send-otp", "/api/v1/auth/verify-otp", "/api/v1/auth/register-phone"):
            assert client.post(path, json={"phone": "05551112233", "code": "123456", "full_name": "X"}).status_code in (404, 405)

        # Ekspertiz odemesi de sozlesme onayi olmadan baslamaz
        firm = client.get("/api/v1/expertiz/packages").json()["firms"][0]
        no_contract = client.post("/api/v1/expertiz/requests", headers=_auth(token), json={
            "firm_id": firm["id"], "package_id": firm["packages"][0]["id"], "city": "Ankara", "district": "Çankaya",
            "vehicle": {"brand": "Fiat", "model": "Egea"}})
        assert no_contract.status_code == 400 and "Sözleşmesi" in no_contract.json()["detail"]

        # --- Odeme: makbuz e-postasi + admine yeni talep bildirimi
        report_id = _create_paid_request(client, token, "06 IPT 06", "Ankara", district="Çankaya")
        assert any("Odemeniz alindi" in m["Subject"] and m["To"] == "yeni@yerimebak.test" for m in outbox)
        admin_notes = client.get("/api/v1/expertiz/admin/notifications", headers=_auth(admin_token)).json()["notifications"]
        assert any(n["kind"] == "request_paid" and n["report_id"] == report_id for n in admin_notes)

        # --- Iptal + iade
        assert client.post(f"/api/v1/expertiz/admin/requests/{report_id}/cancel", headers=_auth(admin_token), json={"reason": ""}).status_code == 400
        cancelled = client.post(f"/api/v1/expertiz/admin/requests/{report_id}/cancel", headers=_auth(admin_token),
                                json={"reason": "Musteri talebi", "refund": True})
        assert cancelled.status_code == 200, cancelled.text
        assert cancelled.json()["refunded_tl"] > 0
        assert client.post(f"/api/v1/expertiz/admin/requests/{report_id}/cancel", headers=_auth(admin_token),
                           json={"reason": "tekrar"}).status_code == 409
        detail = client.get(f"/api/v1/expertiz/admin/requests/{report_id}", headers=_auth(admin_token)).json()["request"]
        assert detail["bucket"] == "cancelled" and detail["cancellation"]["reason"] == "Musteri talebi"
        mine = next(r for r in client.get("/api/v1/expertiz/requests", headers=_auth(token)).json()["requests"] if r["report_id"] == report_id)
        assert mine["status"] == "cancelled" and mine["progress"]["stage"] == "cancelled"
        assert any("iptal" in m["Subject"].lower() for m in outbox if m["To"] == "yeni@yerimebak.test")
        # Iptal edilen talebe personel atanamaz
        person = _create_personnel(client, admin_token, "iptal@yerimebak.test", "Ankara", "Çankaya", "Iptal Personel")
        assert client.post(f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token),
                           json={"personnel_id": person["id"]}).status_code == 409
        finance = client.get("/api/v1/expertiz/admin/finance/summary", headers=_auth(admin_token)).json()
        assert finance["iadeler"]["expertiz_count"] >= 1

        # --- Kredi paketi: kullanilmissa iade yok, kullanilmamissa iade + kredi dusumu
        # Mesafeli satis sozlesmesi onayi olmadan odeme baslamaz
        assert client.post("/api/v1/payments/checkout/credits", headers=_auth(token), json={"package_key": "paket3"}).status_code == 400
        start = client.post("/api/v1/payments/checkout/credits", headers=_auth(token),
                            json={"package_key": "paket3", "contract_accepted": True})
        assert start.status_code == 200, start.text
        oid = start.json()["order_id"]
        client.post(f"/api/v1/payments/checkout/{oid}/simulate", headers=_auth(token), json={"success": True})
        before = client.get("/api/v1/auth/profile", headers=_auth(token)).json()["profile"]["credits"]
        assert client.post(f"/api/v1/payments/admin/orders/{oid}/refund", headers=_auth(token), json={"reason": "x"}).status_code == 403
        refunded = client.post(f"/api/v1/payments/admin/orders/{oid}/refund", headers=_auth(admin_token), json={"reason": "Yanlis paket"})
        assert refunded.status_code == 200, refunded.text
        after = client.get("/api/v1/auth/profile", headers=_auth(token)).json()["profile"]["credits"]
        assert after == before - 3
        assert client.post(f"/api/v1/payments/admin/orders/{oid}/refund", headers=_auth(admin_token), json={"reason": "x"}).status_code == 409

        # --- Fatura dokumu (CSV): satis + iade satirlari, fatura bilgileri
        client.put("/api/v1/auth/profile", headers=_auth(token), json={"company_name": "Yeni Ltd", "tax_number": "1234567890", "tax_office": "Kavaklidere"})
        csv_resp = client.get("/api/v1/expertiz/admin/finance/invoices.csv", headers=_auth(admin_token))
        assert csv_resp.status_code == 200 and csv_resp.headers["content-type"].startswith("text/csv")
        text = csv_resp.content.decode("utf-8-sig")
        lines = [l for l in text.splitlines() if "yeni@yerimebak.test" in l]
        assert any(";satis;" in l and "Yeni Ltd" in l and "1234567890" in l for l in lines)
        assert sum(";iade;" in l for l in lines) == 2
        assert client.get("/api/v1/expertiz/admin/finance/invoices.csv", headers=_auth(token)).status_code == 403
        assert client.get("/api/v1/expertiz/admin/finance/invoices.csv?start=bozuk", headers=_auth(admin_token)).status_code == 400

        # --- Eski havale/elle onay uclari kaldirildi
        assert client.post("/api/v1/payments/order", headers=_auth(token), json={"package_key": "paket3"}).status_code in (404, 405)
        assert client.post("/api/v1/payments/approve", headers=_auth(admin_token), json={"order_id": "x"}).status_code in (404, 405)

        # Onaylar kanit olarak saklanir
        import psycopg2
        db = psycopg2.connect(TEST_DB)
        with db.cursor() as cur:
            cur.execute("SELECT kind, reference FROM legal_consents WHERE user_id = (SELECT id FROM users WHERE email = 'yeni@yerimebak.test')")
            kinds = {k for k, _ in cur.fetchall()}
        db.close()
        assert {"terms_of_use", "kvkk_notice", "distance_sales", "preliminary_info"} <= kinds

        # --- Admin ana ekran ozeti (Supabase yerine merkezi API)
        dash = client.get("/api/v1/expertiz/admin/dashboard", headers=_auth(admin_token))
        assert dash.status_code == 200, dash.text
        dash = dash.json()
        assert dash["stats"]["total_reports"] >= 1 and dash["status_distribution"]["cancelled"] >= 1
        assert len(dash["weekly_published"]) == 7 and len(dash["ai_confidence_trend"]) == 7
        assert any(a["title"] == "Talep iptal edildi" for a in dash["recent_activities"]) or dash["recent_activities"]
        assert client.get("/api/v1/expertiz/admin/dashboard", headers=_auth(token)).status_code == 403

    finally:
        email_service.stop_capture()


def test_initial_admin_bootstrap_from_env(client, monkeypatch):
    from yerimebak_ai_v5.services.auth_service import get_auth_service

    email = f"ilk-admin-{uuid.uuid4().hex[:8]}@example.com"
    monkeypatch.setenv("INITIAL_ADMIN_EMAIL", email)
    monkeypatch.setenv("INITIAL_ADMIN_PASSWORD", "Baslangic123.")
    auth = get_auth_service()
    assert auth.ensure_initial_admin() == email
    # Ikinci acilista dokunulmaz (sifre degismez, hata yok)
    monkeypatch.setenv("INITIAL_ADMIN_PASSWORD", "BaskaSifre456")
    assert auth.ensure_initial_admin() is None

    login = client.post("/api/v1/auth/login", json={"email": email, "password": "Baslangic123."})
    assert login.status_code == 200, login.text
    body = login.json()
    assert body["user"]["role"] == "admin"
    assert client.post("/api/v1/auth/login", json={"email": email, "password": "BaskaSifre456"}).status_code != 200

    # Zayif sifre ile olusturulmaz
    monkeypatch.setenv("INITIAL_ADMIN_EMAIL", f"zayif-{uuid.uuid4().hex[:6]}@example.com")
    monkeypatch.setenv("INITIAL_ADMIN_PASSWORD", "kisa")
    assert auth.ensure_initial_admin() is None


def test_link_request_saved_listing_and_comparables_valuation(client, admin_token, customer_token, monkeypatch):
    """Musteri link + marka/model paylasir -> ilan ve emsaller eklentiyle kaydedilmis -> personel raporu
    -> ekspertiz degerlemesi + ilan beyani karsilastirmasi -> admin onayi -> musteri."""
    import json as _json
    from pathlib import Path

    import psycopg2
    from yerimebak_ai_v5.services import market_ingest

    market_ingest._schema_ready = False
    link = "https://www.arabam.com/ilan/galeriden-satilik-renault-clio-1-0-tce-touch/test/9001?utm_source=paylas"
    # Personel ilani ve arama sayfasini Chrome eklentisiyle kaydetti (ornek veri)
    fixtures = Path(__file__).resolve().parents[1] / "fixtures" / "listings"
    ilan = [dict(it, url=link) for it in _json.loads((fixtures / "ilan.json").read_text(encoding="utf-8"))]
    assert market_ingest.upsert_listings(ilan, status="talep")
    assert len(market_ingest.upsert_listings(_json.loads((fixtures / "emsal.json").read_text(encoding="utf-8")),
                                             status="emsal")) >= 10

    person = _create_personnel(client, admin_token, "emsal@yerimebak.test", "İstanbul", "Üsküdar", "Emsal Personel")
    staff = _login(client, "emsal@yerimebak.test", "Personel123")
    firm = client.get("/api/v1/expertiz/packages").json()["firms"][0]
    created = client.post("/api/v1/expertiz/requests/unpaid", headers=_auth(customer_token), json={
        "firm_id": firm["id"], "package_id": firm["packages"][0]["id"],
        "city": "İstanbul", "district": "Üsküdar", "listing_url": link,
        # Musteri formu marka/modeli ister; fiyat, km ve satici beyani kaydedilmis ilandan gelir
        "vehicle": {"brand": "Renault", "model": "Clio"},
    })
    assert created.status_code == 200, created.text
    report_id = created.json()["request_id"]
    assert client.post(f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token),
                       json={"personnel_id": person["id"]}).status_code == 200
    assert client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/start", headers=_auth(staff)).status_code == 200
    client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/media", headers=_auth(staff),
                files={"file": ("kurumsal.pdf", PDF_BYTES, "application/pdf")}, data={"category": "corporate_report"})

    rapor = _tam_rapor(report_id, person["id"])
    rapor["adim1"].update({"marka": "Renault", "model": "Clio", "yil": "2019", "guncelKm": 72000,
                           "hasarKayitToplamTutar": 18000, "hasarKayitAdet": 1})
    # Ilanda 1 boyali / 0 degisen / "tramer yok" beyan edildi; ekspertiz 3 boyali + 1 degisen + 18.000 TL tramer buldu
    rapor["adim4"] = {"gorevId": report_id, "personelId": person["id"],
                      "parcaDurumlari": {"kaput": "boyali", "solOnCamurluk": "boyali", "sagOnKapi": "boyali",
                                         "solOnKapi": "degisen"},
                      "yapisalDurumlar": {"onSasi": "orijinal"}}
    submitted = client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/submit", headers=_auth(staff),
                            json={"tam_rapor": rapor})
    assert submitted.status_code == 200, submitted.text

    admin_report = client.get(f"/api/v1/expertiz/admin/reports/{report_id}", headers=_auth(admin_token)).json()["report"]
    assert admin_report["status"] == "pending_admin", admin_report.get("ai_meta")
    ai = admin_report["ai_analiz_detay"]
    ref = ai["marketReference"]
    assert "emsalCekimi" not in ref
    assert ref["found"] is True and ref["clean_count"] >= 3
    assert all("/ilan/test/9001" not in (s.get("url") or "") for s in ref["samples"])  # kendi ilani emsal degil
    degerleme = ai["ekspertizDegerleme"]
    assert degerleme["degerlemeYapildi"] is True
    assert degerleme["boyaliParcaSayisi"] == 3 and degerleme["degisenParcaSayisi"] == 1
    assert degerleme["aiDegeri"] < degerleme["temizPiyasaDegeri"]
    assert degerleme["ilanFiyati"] == 650000  # musteri fiyat girmedi: kayitli ilandan geldi
    karsilastirma = degerleme["ilanBeyaniKarsilastirma"]
    assert karsilastirma["ilanBeyaniVar"] is True and karsilastirma["uyumlu"] is False
    assert karsilastirma["ilanBeyani"] == {"boyali": 1, "degisen": 0, "hasarKaydi": None, "tramerTl": 0, "agirHasar": False,
                                           "kaynak": "test",
                                           "url": "https://www.arabam.com/ilan/galeriden-satilik-renault-clio-1-0-tce-touch/test/9001"}
    assert len(karsilastirma["farklar"]) == 3 and "18.000 TL" in karsilastirma["farklar"][2]
    assert karsilastirma["ekspertiz"]["tramerTl"] == 18000
    # Paket: musterinin ilani "1.0 TCe Touch"; daha pahali "1.3 TCe Icon" emsalleri kullanilmaz
    assert ref["package"] == "1.0 TCe Touch" and ref["package_match"] is True
    assert all("test-emsal-icon" not in (s.get("url") or "") for s in ref["samples"])
    kriterler = {k["kriter"]: k for k in degerleme["degerlemeKriterleri"]}
    assert list(kriterler) == ["Model", "Paket", "Kilometre", "Hasar kaydı (tramer)", "Değişen", "Boya", "Hasar"]
    assert kriterler["Model"]["deger"] == "Renault Clio 2019"
    assert kriterler["Paket"]["deger"] == "1.0 TCe Touch" and kriterler["Paket"]["eslesti"] is True
    assert kriterler["Kilometre"]["deger"].startswith("72.000 km")
    assert kriterler["Hasar kaydı (tramer)"]["deger"] == "18.000 TL" and kriterler["Hasar kaydı (tramer)"]["etki"]["yuzde"] > 0
    assert kriterler["Değişen"]["deger"] == "1 parça" and kriterler["Boya"]["deger"] == "3 parça"
    # Tramerli emsaller temiz sayilmaz, agir hasarli emsal kullanilmaz
    conditions = {s["url"].rsplit("/", 1)[-1]: s["condition"] for s in ref["samples"]}
    assert conditions.get("9100") in (None, "damaged") and "9113" not in conditions

    # Veritabani: musteri ilani 'talep', emsaller 'emsal' (vitrinde yok), fiyat gecmisi tutuldu
    conn = psycopg2.connect(TEST_DB)
    with conn, conn.cursor() as cur:
        cur.execute("SELECT status FROM listings WHERE url LIKE %s", ("%/ilan/galeriden-satilik-renault-clio-1-0-tce-touch/test/9001",))
        assert cur.fetchone()[0] == "talep"
        cur.execute("SELECT count(*) FROM listings WHERE status = 'emsal' AND brand = 'Renault'")
        assert cur.fetchone()[0] >= 10
        cur.execute("SELECT count(*) FROM price_history ph JOIN listings l ON l.id = ph.listing_id WHERE l.brand = 'Renault'")
        assert cur.fetchone()[0] >= 11
    conn.close()

    # Ayni arac icin tekrar analiz ayni sonucu verir
    re_run = client.post(f"/api/v1/expertiz/admin/reports/{report_id}/reanalyze", headers=_auth(admin_token))
    assert re_run.status_code == 200, re_run.text
    again = re_run.json()["report"]["ai_analiz_detay"]
    assert again["ekspertizDegerleme"]["aiDegeri"] == degerleme["aiDegeri"]

    # Admin onayi -> musteri degerlemeyi ve beyan karsilastirmasini gorur
    assert client.post(f"/api/v1/expertiz/admin/reports/{report_id}/publish", headers=_auth(admin_token)).status_code == 200
    customer = client.get(f"/api/v1/expertiz/reports/{report_id}", headers=_auth(customer_token)).json()["report"]
    assert customer["status"] == "published"
    assert customer["summary"]["market_value"] == degerleme["aiDegeri"]
    assert customer["ai"]["ekspertizDegerleme"]["ilanBeyaniKarsilastirma"]["uyumlu"] is False
    assert len(customer["ai"]["ekspertizDegerleme"]["degerlemeKriterleri"]) == 7
    assert len(customer["corporate_reports"]) == 1


def test_valuation_without_saved_listing(client, admin_token, customer_token, monkeypatch):
    """Musterinin ilani sisteme kaydedilmemisse degerleme mevcut emsallerle surer; beyan karsilastirmasi yapilmaz."""
    _seed_listings()
    person = _create_personnel(client, admin_token, "kayitsiz@yerimebak.test", "İstanbul", "Maltepe", "Kayitsiz Personel")
    staff = _login(client, "kayitsiz@yerimebak.test", "Personel123")
    report_id = _create_paid_request(client, customer_token, "34 APF 02", "İstanbul", package_index=3, district="Maltepe")
    client.post(f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token), json={"personnel_id": person["id"]})
    client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/start", headers=_auth(staff))
    client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/media", headers=_auth(staff),
                files={"file": ("kurumsal.pdf", PDF_BYTES, "application/pdf")}, data={"category": "corporate_report"})
    submitted = client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/submit", headers=_auth(staff),
                            json={"tam_rapor": _tam_rapor(report_id, person["id"])})
    assert submitted.status_code == 200, submitted.text
    report = client.get(f"/api/v1/expertiz/admin/reports/{report_id}", headers=_auth(admin_token)).json()["report"]
    assert report["status"] == "pending_admin"
    assert report["ai_analiz_detay"]["ekspertizDegerleme"]["degerlemeYapildi"] is True
    assert report["ai_analiz_detay"]["ekspertizDegerleme"]["ilanBeyaniKarsilastirma"]["uyumlu"] is None


def test_ai_price_estimate_when_no_comparables(client, admin_token, customer_token, monkeypatch):
    """Emsal yoksa DeepSeek tahmini etiketli kullanilir; rapor admin onayina duser, musteriye gitmez."""
    from yerimebak_ai_v5.core.market.market_reference_service import MarketReferenceService
    from yerimebak_ai_v5.services import ai_price_estimate

    monkeypatch.setattr(MarketReferenceService, "get_reference",
                        lambda self, **kw: self._last_resort("not_enough_reference", int(kw.get("listed_price") or 0)))
    asked = []

    def fake_estimate(vehicle, **_kw):
        asked.append(vehicle)
        return {"median": 1_550_000, "min": 1_420_000, "max": 1_755_000, "data_date": "2026-09",
                "note": "test", "model": "deepseek/deepseek-chat"}
    monkeypatch.setattr(ai_price_estimate, "estimate", fake_estimate)

    person = _create_personnel(client, admin_token, "aitahmin@yerimebak.test", "İstanbul", "Kartal", "Tahmin Personel")
    staff = _login(client, "aitahmin@yerimebak.test", "Personel123")
    report_id = _create_paid_request(client, customer_token, "34 AIT 01", "İstanbul", package_index=3, district="Kartal")
    client.post(f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token), json={"personnel_id": person["id"]})
    client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/start", headers=_auth(staff))
    client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/media", headers=_auth(staff),
                files={"file": ("kurumsal.pdf", PDF_BYTES, "application/pdf")}, data={"category": "corporate_report"})
    submitted = client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/submit", headers=_auth(staff),
                            json={"tam_rapor": _tam_rapor(report_id, person["id"])})
    assert submitted.status_code == 200, submitted.text

    report = client.get(f"/api/v1/expertiz/admin/reports/{report_id}", headers=_auth(admin_token)).json()["report"]
    assert report["status"] == "pending_admin"
    d = report["ai_analiz_detay"]["ekspertizDegerleme"]
    assert asked and asked[0]["brand"] and asked[0]["model"]
    assert d["degerlemeYapildi"] is True and d["piyasaKaynagi"] == "ai_estimate"
    assert d["piyasaDegeri"] == 1_550_000 and d["guvenSkoru"] <= 25
    assert "yapay zekâ" in d["piyasaUyarisi"].lower() and "yapay zekâ tahmini" in d["ozet"]
    assert report["ai_analiz_detay"]["marketReference"]["source"] == "ai_estimate"
    customer = client.get(f"/api/v1/expertiz/reports/{report_id}", headers=_auth(customer_token))
    assert customer.status_code != 200 or customer.json()["report"].get("status") != "published"


def test_web_emsal_kaynakli_degerleme_kontrol_isareti_ve_musteri_kaynaklari(client, admin_token, customer_token, monkeypatch):
    """Kaziyicisiz: web aramasiyla dogrulanan emsaller -> personel raporu -> admin kontrol isareti -> onay -> musteri kaynaklari."""
    from yerimebak_ai_v5.services import web_market_reference as wmr

    def sayfa(url, fiyat, km, paket):
        return {"url": url, "fiyat_tl": fiyat, "km": km, "yil": 2021, "paket": paket, "durum": "hatasız"}

    ilanlar = [
        sayfa("https://www.arabam.com/ilan/fiat-egea-1-3-multijet-urban/1", 905_000, 52_000, "1.3 Multijet Urban"),
        sayfa("https://www.otosor.com.tr/egea-urban/2", 925_000, 40_000, "1.3 Multijet Urban"),
        sayfa("https://www.arabam.com/ilan/fiat-egea-1-3-multijet-urban/3", 940_000, 61_000, "1.3 Multijet Urban"),
        # Uydurma fiyat: sayfa metninde yok, kullanilmamali
        sayfa("https://www.arabam.com/ilan/fiat-egea-1-3-multijet-urban/4", 610_000, 45_000, "1.3 Multijet Urban"),
    ]
    sorgular = []

    def sahte_arama(query, _client):
        sorgular.append(query)
        kaynaklar = {i["url"]: f"Fiat Egea {i['paket']} {i['fiyat_tl']:,} TL".replace(",", ".") for i in ilanlar[:3]}
        kaynaklar[ilanlar[3]["url"]] = "Fiat Egea 1.3 Multijet Urban 915.000 TL"
        return {"listings": ilanlar, "sources": kaynaklar, "cost": 0.009}

    monkeypatch.setenv("OPENROUTER_API_KEY", "test-key")
    monkeypatch.setattr(wmr, "_search", sahte_arama)

    person = _create_personnel(client, admin_token, "webemsal@yerimebak.test", "İstanbul", "Pendik", "Web Personel")
    staff = _login(client, "webemsal@yerimebak.test", "Personel123")
    report_id = _create_paid_request(
        client, customer_token, "34 WEB 01", "İstanbul", package_index=3, district="Pendik",
        vehicle={"brand": "Fiat", "model": "Egea", "package": "1.3 Multijet Urban", "year": 2021, "km": 45000,
                 "price": 960000, "fuel": "Dizel", "transmission": "Manuel",
                 # Musteri ilandan aktardi: "boyasiz, tramersiz"; degisen alani bos (ilanda yazmiyor)
                 "declared_painted": 0, "declared_tramer": 0},
    )
    client.post(f"/api/v1/expertiz/admin/requests/{report_id}/assign", headers=_auth(admin_token), json={"personnel_id": person["id"]})
    client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/start", headers=_auth(staff))
    client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/media", headers=_auth(staff),
                files={"file": ("kurumsal.pdf", PDF_BYTES, "application/pdf")}, data={"category": "corporate_report"})
    rapor = _tam_rapor(report_id, person["id"])
    rapor["adim4"]["parcaDurumlari"] = {"kaput": "boyali"}
    submitted = client.post(f"/api/v1/expertiz/personnel/tasks/{report_id}/submit", headers=_auth(staff),
                            json={"tam_rapor": rapor})
    assert submitted.status_code == 200, submitted.text

    report = client.get(f"/api/v1/expertiz/admin/reports/{report_id}", headers=_auth(admin_token)).json()["report"]
    assert report["status"] == "pending_admin"
    ai = report["ai_analiz_detay"]
    d = ai["ekspertizDegerleme"]
    # Paket musterinin talep formundan geldi, 3 sorgu yapildi
    assert len(sorgular) == 3 and all("1.3 Multijet Urban" in q for q in sorgular[:2])
    assert d["piyasaKaynagi"] == "web_listings"
    assert d["piyasaDegeri"] == 925_000
    assert [k["price"] for k in d["piyasaKaynaklari"]] == [905_000, 925_000, 940_000]
    assert {k["kod"] for k in d["kontrolGerekli"]} == {"az_emsal"}
    # Satici beyani talep formundan: personel boyali parca buldu, degisen beyan edilmedigi icin karsilastirilmadi
    beyan = d["ilanBeyaniKarsilastirma"]
    assert d["boyaliParcaSayisi"] >= 1
    assert beyan["ilanBeyaniVar"] is True and beyan["ilanBeyani"]["kaynak"] == "musteri_formu"
    assert beyan["ilanBeyani"]["degisen"] is None and beyan["uyumlu"] is False
    assert len(beyan["farklar"]) == 1 and "boyalı" in beyan["farklar"][0]
    assert any(o.get("baslik") == "Kontrol gerekli" for o in ai["oneriler"])
    assert ai["marketReference"]["scope"]["rejected"] == {"fiyat sayfada yok": 3}

    # Admin kaynaklara bakip piyasa degerini duzeltir: yeni arama yapilmaz, iki deger de kaydedilir
    bad = client.post(f"/api/v1/expertiz/admin/reports/{report_id}/market-value", headers=_auth(admin_token), json={"value": 10})
    assert bad.status_code == 400
    fixed = client.post(f"/api/v1/expertiz/admin/reports/{report_id}/market-value", headers=_auth(admin_token),
                        json={"value": 950_000, "note": "Urban paketinde 950 bin bandı daha gerçekçi"})
    assert fixed.status_code == 200, fixed.text
    assert len(sorgular) == 3
    d2 = fixed.json()["report"]["ai_analiz_detay"]["ekspertizDegerleme"]
    assert d2["piyasaKaynagi"] == "admin_manual" and d2["piyasaDegeri"] == 950_000
    assert d2["adminDuzeltmesi"]["ai_value"] == 925_000 and d2["adminDuzeltmesi"]["diff_pct"] == 2.7
    assert len(d2["piyasaKaynaklari"]) == 3 and not d2.get("kontrolGerekli")
    assert "yapay zekânın bulduğu" in d2["piyasaYontemi"]
    # Ikinci duzeltmede yapay zekanin ilk degeri korunur
    again = client.post(f"/api/v1/expertiz/admin/reports/{report_id}/market-value", headers=_auth(admin_token),
                        json={"value": 940_000})
    assert again.json()["report"]["ai_analiz_detay"]["ekspertizDegerleme"]["adminDuzeltmesi"]["ai_value"] == 925_000
    from yerimebak_ai_v5.core.database_config import DatabaseConfig
    conn = DatabaseConfig.get_connection()
    try:
        cur = conn.cursor()
        cur.execute("SELECT metadata FROM audit_logs WHERE action = 'market_value_override' AND entity_id = %s",
                    (report_id,))
        logs = [dict(r)["metadata"] for r in cur.fetchall()]
    finally:
        DatabaseConfig.return_connection(conn)
    assert sorted((m["ai_value"], m["admin_value"]) for m in logs) == [(925_000, 940_000), (925_000, 950_000)]

    published = client.post(f"/api/v1/expertiz/admin/reports/{report_id}/publish", headers=_auth(admin_token))
    assert published.status_code == 200, published.text
    # Yayindan sonra duzeltme yapilamaz
    assert client.post(f"/api/v1/expertiz/admin/reports/{report_id}/market-value", headers=_auth(admin_token),
                       json={"value": 900_000}).status_code == 400
    customer = client.get(f"/api/v1/expertiz/reports/{report_id}", headers=_auth(customer_token)).json()["report"]
    ref = customer["ai"]["piyasaReferansi"]
    assert ref["kaynak"] == "admin_manual" and ref["emsalSayisi"] == 3
    assert {e["site"] for e in ref["emsaller"]} == {"arabam.com", "otosor.com.tr"}
    assert all(e["url"].startswith("https://") for e in ref["emsaller"])
    # Admin'e ozel kontrol onerileri musteriye gitmez
    assert not any(o.get("baslik") == "Kontrol gerekli" for o in customer["ai"].get("oneriler") or [])


def test_kredi_reddi_gunluk_sinir_ve_basarisiz_dusumde_sonuc_verilmez(client, monkeypatch):
    """Gunluk sinir doluysa 429; kilitli kredi dusumu basarisizsa (es zamanli istek) analiz sonucu verilmez."""
    from yerimebak_ai_v5.services import email_service, payment_service, web_market_reference as wmr
    from yerimebak_ai_v5.core.database_config import DatabaseConfig

    outbox = email_service.capture_for_tests()
    try:
        reg = client.post("/api/v1/auth/register", json={"email": "kredired@yerimebak.test",
                          "password": "Musteri123!", "terms_accepted": True})
        assert reg.status_code == 200, reg.text
        token = reg.json()["token"]
        client.post("/api/v1/auth/verify-email", json={"token": _link_token(outbox[-1], "/eposta-dogrula")})
    finally:
        email_service.stop_capture()

    listings = [{"url": f"https://www.arabam.com/ilan/renault-clio-red/{i}", "fiyat_tl": p,
                 "km": 40000, "yil": 2022, "paket": "Touch", "kondisyon": "temiz"}
                for i, p in enumerate((800000, 820000, 840000))]
    monkeypatch.setenv("OPENROUTER_API_KEY", "test-key")
    monkeypatch.setattr(wmr, "_search", lambda q, _c: {
        "listings": listings, "sources": {i["url"]: str(i["fiyat_tl"]) for i in listings}, "cost": 0.01})
    payload = {"brand": "Renault", "model": "Clio", "year": 2022, "km": 40000,
               "fuel": "Benzin", "transmission": "Manuel", "listed_price": 830000}
    api_payload = {"brand": "Renault", "model": "Clio", "year": 2022, "mileage_km": 40000,
                   "fuel_type": "Benzin", "gear_type": "Manuel", "listed_price": 830000}

    def kredi_ve_gecmis():
        conn = DatabaseConfig.get_connection()
        try:
            cur = conn.cursor()
            cur.execute("SELECT credits FROM users WHERE email = 'kredired@yerimebak.test'")
            credits = dict(cur.fetchone())["credits"]
            cur.execute("""SELECT count(*) AS n FROM analysis_history
                           WHERE user_id = (SELECT id FROM users WHERE email = 'kredired@yerimebak.test')""")
            return credits, dict(cur.fetchone())["n"]
        finally:
            DatabaseConfig.return_connection(conn)

    baslangic = kredi_ve_gecmis()
    assert baslangic == (3, 0)

    # 1) Gunluk sinir dolu (free: gunluk 0 analiz hakki) -> 429, kredi ve gecmis degismez
    monkeypatch.setitem(payment_service.TIER_LIMITS, "free", {"max_analyses_per_day": 0})
    r = client.post("/api/v1/valuation/analyze", headers=_auth(token), json=payload)
    assert r.status_code == 429, r.text
    assert r.json()["detail"]["code"] == "daily_limit"
    a = client.post("/api/v1/analyze", headers=_auth(token), json=api_payload)
    assert a.status_code == 429, a.text
    assert kredi_ve_gecmis() == baslangic

    # 2) On kontrol gecer ama kilitli dusum reddeder (es zamanli ikinci istek) -> sonuc verilmez
    monkeypatch.setitem(payment_service.TIER_LIMITS, "free", {"max_analyses_per_day": 5})
    monkeypatch.setattr(payment_service.PaymentService, "deduct_credits",
                        lambda self, *args, **kw: {"success": False, "error": "Yetersiz kredi",
                                                   "code": "insufficient_credits", "credits": 0})
    r = client.post("/api/v1/valuation/analyze", headers=_auth(token), json=payload)
    assert r.status_code == 402, r.text
    assert "piyasa" not in r.text and r.json()["detail"]["code"] == "insufficient_credits"
    a = client.post("/api/v1/analyze", headers=_auth(token), json=api_payload)
    assert a.status_code == 402, a.text
    assert "technical_scoring" not in a.text
    assert kredi_ve_gecmis() == baslangic
