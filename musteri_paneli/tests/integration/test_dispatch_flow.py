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

    import psycopg2

    conn = psycopg2.connect(TEST_DB)
    conn.autocommit = True
    with conn.cursor() as cur:
        cur.execute("DROP SCHEMA public CASCADE; CREATE SCHEMA public;")
    conn.close()

    from fastapi.testclient import TestClient
    from yerimebak_ai_v5.main import app
    from yerimebak_ai_v5.services import dispatch_service, expertiz_service

    # Sema bu surecte daha once hazirlandiysa sifirlanan veritabani icin tekrar kur
    dispatch_service._schema_ready = False
    expertiz_service._reports_schema_ensured = False

    with TestClient(app, base_url="http://localhost") as test_client:
        yield test_client


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


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
        json={"email": "musteri@yerimebak.test", "password": "Musteri123!", "full_name": "Ayse Musteri", "phone": "05551112233"},
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
    created = client.post(
        "/api/v1/expertiz/requests",
        headers=_auth(customer_token),
        json={"firm_id": "FIRM_001", "package_id": "PG_STD", "plate": "34 TST 34", "city": "istanbul kadikoy", "note": "Hafta ici"},
    )
    assert created.status_code == 200, created.text
    report_id = created.json()["report_id"]

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

