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
    created = client.post(
        "/api/v1/expertiz/requests",
        headers=_auth(customer_token),
        json={"firm_id": "FIRM_001", "package_id": "PG_FULL", "plate": "34 TST 35", "city": "İstanbul"},
    )
    report_id = created.json()["report_id"]
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


def test_ai_valuation_admin_approval_and_customer_view(client, admin_token, customer_token):
    """Personel raporu -> merkezi AI (piyasa - ekspertiz değer kaybı) -> admin onayı -> müşteri."""
    _seed_listings()
    person = _create_personnel(client, admin_token, "ai@yerimebak.test", "İstanbul", "Şişli", "AI Personel")
    token = _login(client, "ai@yerimebak.test", "Personel123")
    report_id = client.post(
        "/api/v1/expertiz/requests",
        headers=_auth(customer_token),
        json={"firm_id": "FIRM_001", "package_id": "PG_FULL", "plate": "34 AI 01", "city": "İstanbul"},
    ).json()["report_id"]
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
