import unittest
from unittest.mock import patch

from yerimebak_ai_v5.api.v1.router import api_router
from tests.unit.route_paths import api_paths
from yerimebak_ai_v5.services import personnel_service


class FakeCursor:
    def __init__(self, rows=None):
        self.rows = list(rows or [])
        self.executed = []
        self.inserted_user = None
        self.inserted_profile = None
        self.updated_user = None
        self.updated_profile = None

    def execute(self, query, params=None):
        self.executed.append((query, params))
        normalized = " ".join(query.split()).lower()
        if "insert into users" in normalized:
            self.inserted_user = params
        if "insert into profiles" in normalized:
            self.inserted_profile = params
        if "update users" in normalized:
            self.updated_user = params
        if "update profiles" in normalized:
            self.updated_profile = params

    def fetchone(self):
        if not self.rows:
            return None
        return self.rows.pop(0)

    def fetchall(self):
        rows = self.rows
        self.rows = []
        return rows


class FakeConnection:
    def __init__(self, rows=None):
        self.cursor_instance = FakeCursor(rows)
        self.committed = False

    def cursor(self):
        return self.cursor_instance

    def commit(self):
        self.committed = True


class PersonnelAdminWorkflowTests(unittest.TestCase):
    def setUp(self):
        # Sema hazirlama gercek veritabani ister; birim testlerde atlanir.
        from yerimebak_ai_v5.services import dispatch_service

        patcher = patch.object(dispatch_service, "ensure_workflow_schema_once", return_value=True)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_personnel_admin_routes_are_registered(self):
        paths = api_paths(api_router)

        self.assertIn("/personnel/admin/personnel", paths)
        self.assertIn("/personnel/admin/personnel/{personnel_id}/deactivate", paths)
        self.assertIn("/personnel/admin/personnel/{personnel_id}/activate", paths)
        self.assertIn("/personnel/admin/personnel/{personnel_id}/reset-password", paths)
        self.assertIn("/personnel/admin/coverage", paths)

    def test_create_personnel_writes_user_and_profile(self):
        # sirasiyla: e-posta kontrolu, telefon kontrolu, INSERT ... RETURNING, profil arama
        conn = FakeConnection(rows=[None, None, {"id": 7, "created_at": None}, None])
        payload = {
            "full_name": "Ayse Yilmaz",
            "email": "ayse@yerimebak.ai",
            "phone": "+905551112233",
            "city": "Istanbul",
            "district": "Kadikoy",
            "expertise": "Kaporta",
            "temporary_password": "Gecici-12345",
        }

        with patch.object(personnel_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(personnel_service.DatabaseConfig, "return_connection") as mock_return:
            result = personnel_service.create_personnel(payload, {"email": "admin@yerimebak.ai"})

        self.assertTrue(result["success"])
        self.assertEqual(result["personnel"]["email"], "ayse@yerimebak.ai")
        self.assertEqual(result["personnel"]["id"], "7")
        self.assertEqual(result["personnel"]["role"], "field_staff")
        self.assertEqual(result["personnel"]["city"], "İstanbul")
        self.assertEqual(result["personnel"]["il_id"], 34)
        self.assertEqual(result["personnel"]["region"], "Marmara")
        self.assertTrue(result["personnel"]["active"])
        self.assertIsNotNone(conn.cursor_instance.inserted_user)
        self.assertIsNotNone(conn.cursor_instance.inserted_profile)
        self.assertNotIn("Gecici-12345", str(conn.cursor_instance.inserted_user))
        self.assertTrue(conn.committed)
        mock_return.assert_called_once_with(conn)

    def test_create_personnel_rejects_duplicate_email(self):
        conn = FakeConnection(rows=[{"id": "existing-id"}])

        with patch.object(personnel_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(personnel_service.DatabaseConfig, "return_connection"):
            result = personnel_service.create_personnel(
                {
                    "full_name": "Ayse Yilmaz",
                    "email": "ayse@yerimebak.ai",
                    "temporary_password": "Gecici-12345",
                    "city": "Istanbul",
                    "district": "Kadikoy",
                },
                {"email": "admin@yerimebak.ai"},
            )

        self.assertEqual(result["error"], "Bu e-posta ile kayitli bir kullanici zaten var")
        self.assertEqual(result["http_status"], 409)
        self.assertFalse(conn.committed)

    def test_deactivate_personnel_requires_reason_and_blocks_login(self):
        result = personnel_service.deactivate_personnel(
            "staff-id",
            " ",
            {"email": "admin@yerimebak.ai"},
        )

        self.assertEqual(result["error"], "Pasife alma nedeni zorunludur")
        self.assertEqual(result["http_status"], 400)

        conn = FakeConnection(rows=[{"id": "staff-id", "email": "staff@yerimebak.ai"}])
        with patch.object(personnel_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(personnel_service.DatabaseConfig, "return_connection"):
            result = personnel_service.deactivate_personnel(
                "staff-id",
                "Disiplin incelemesi",
                {"email": "admin@yerimebak.ai"},
            )

        self.assertTrue(result["success"])
        self.assertFalse(result["personnel"]["active"])
        self.assertTrue(any("is_active = 0" in query for query, _ in conn.cursor_instance.executed))
        self.assertTrue(any("aktif_mi = FALSE" in query for query, _ in conn.cursor_instance.executed))
        self.assertTrue(any("PERSONNEL_DEACTIVATED" in str(params) for _, params in conn.cursor_instance.executed))

    def test_update_personnel_changes_city_district_and_expertise(self):
        conn = FakeConnection(rows=[{"id": "staff-id", "email": "staff@yerimebak.ai"}])

        with patch.object(personnel_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(personnel_service.DatabaseConfig, "return_connection"):
            result = personnel_service.update_personnel(
                "staff-id",
                {
                    "full_name": "Ayse Kaya",
                    "phone": "+905550000000",
                    "city": "Ankara",
                    "district": "Cankaya",
                    "expertise": "Mekanik",
                },
                {"email": "admin@yerimebak.ai"},
            )

        self.assertTrue(result["success"])
        self.assertEqual(result["personnel"]["city"], "Ankara")
        self.assertEqual(result["personnel"]["district"], "Cankaya")
        self.assertTrue(any("city = %s" in query for query, _ in conn.cursor_instance.executed))
        self.assertTrue(any("il = %s" in query for query, _ in conn.cursor_instance.executed))
        self.assertTrue(any("PERSONNEL_UPDATED" in str(params) for _, params in conn.cursor_instance.executed))

    def test_reset_personnel_password_hashes_new_password(self):
        conn = FakeConnection(rows=[{"id": "staff-id", "email": "staff@yerimebak.ai"}])

        with patch.object(personnel_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(personnel_service.DatabaseConfig, "return_connection"):
            result = personnel_service.reset_personnel_password(
                "staff-id",
                "Yeni-12345",
                {"email": "admin@yerimebak.ai"},
            )

        self.assertTrue(result["success"])
        self.assertTrue(result["must_change_password"])
        self.assertIsNotNone(conn.cursor_instance.updated_user)
        self.assertNotIn("Yeni-12345", str(conn.cursor_instance.updated_user))
        self.assertTrue(conn.committed)

    def test_coverage_marks_missing_and_understaffed_cities(self):
        from yerimebak_ai_v5.services import dispatch_service

        personnel_rows = [
            {"id": 1, "city": "Istanbul", "is_active": 1},
            {"id": 2, "city": "Istanbul", "is_active": 1},
            {"id": 3, "city": "Istanbul", "is_active": 0},
            {"id": 4, "city": "Ankara", "is_active": 0},
            {"id": 5, "city": "Izmir", "is_active": 1},
        ]
        open_requests = [
            {"id": "a", "il_id": 6, "assigned": False},
            {"id": "b", "il_id": 6, "assigned": False},
            {"id": "c", "il_id": 6, "assigned": True},
            {"id": "d", "il_id": 16, "assigned": False},
        ]
        conn = FakeConnection()

        with patch.object(personnel_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(personnel_service.DatabaseConfig, "return_connection"), \
             patch.object(personnel_service, "_personnel_rows", return_value=personnel_rows), \
             patch.object(dispatch_service, "open_request_locations", return_value=open_requests):
            result = personnel_service.get_personnel_coverage()

        self.assertTrue(result["success"])
        self.assertEqual(result["summary"]["active_personnel"], 3)
        self.assertEqual(result["summary"]["unassigned_request_count"], 3)
        self.assertIn("Ankara", result["missing_cities"])
        self.assertIn("Bursa", result["missing_cities"])
        self.assertEqual(result["critical_cities"][:2], ["Ankara", "Bursa"])
        self.assertIn("İstanbul", result["understaffed_cities"])
        self.assertEqual(result["cities"]["Ankara"]["open_request_count"], 3)
        self.assertEqual(result["cities"]["Ankara"]["status"], "critical")
        marmara = next(r for r in result["regions"] if r["region"] == "Marmara")
        self.assertEqual(marmara["active_personnel"], 2)
        self.assertEqual(marmara["unassigned_request_count"], 1)
        self.assertEqual(sum(r["province_count"] for r in result["regions"]), 81)

if __name__ == "__main__":
    unittest.main()
