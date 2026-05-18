import uuid
import unittest
from unittest.mock import patch

from yerimebak_ai_v5.api.v1.router import api_router
from yerimebak_ai_v5.services import expertiz_service


class FakeCursor:
    def __init__(self, rows):
        self.rows = list(rows)
        self.executed = []
        self.updated_data = None

    def execute(self, query, params=None):
        self.executed.append((query, params))
        if "UPDATE reports" in query:
            self.updated_data = params[2]
            report_id = params[3]
            status = "published" if "status = 'published'" in query else "rejected"
            durum = "Tamamlandi" if status == "published" else "Iptal"
            self.rows.append(
                {
                    "id": report_id,
                    "status": status,
                    "durum": durum,
                    "data": self.updated_data.adapted,
                    "version_id": 2,
                }
            )

    def fetchone(self):
        if not self.rows:
            return None
        return self.rows.pop(0)

    def fetchall(self):
        rows = self.rows
        self.rows = []
        return rows


class FakeConnection:
    def __init__(self, rows):
        self.cursor_instance = FakeCursor(rows)
        self.committed = False
        self.closed = False

    def cursor(self):
        return self.cursor_instance

    def commit(self):
        self.committed = True

    def close(self):
        self.closed = True




def pending_admin_report(report_id: str, data=None, ai_result=None):
    return {
        "id": report_id,
        "status": "pending_admin",
        "durum": "Raporlandi",
        "data": data or {"existing": True},
        "ai_analiz_detay": ai_result,
        "ai_analysis_result": ai_result,
        "ai_analizi_yapildi_mi": bool(ai_result),
        "version_id": 1,
    }

class ExpertizAdminWorkflowTests(unittest.TestCase):
    def test_admin_expertiz_routes_are_registered(self):
        paths = {route.path for route in api_router.routes}

        self.assertIn("/expertiz/admin/reports", paths)
        self.assertIn("/expertiz/admin/reports/{report_id}", paths)
        self.assertIn("/expertiz/admin/reports/{report_id}/publish", paths)
        self.assertIn("/expertiz/admin/reports/{report_id}/reject", paths)

    def test_publish_admin_report_marks_report_published(self):
        report_id = str(uuid.uuid4())
        conn = FakeConnection(
            [
                pending_admin_report(
                    report_id,
                    data={"ai_meta": {"source": "central_ai", "official": True, "ready": True}},
                    ai_result={"tamamlandiMi": True},
                )
            ]
        )

        with patch.object(expertiz_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(expertiz_service.DatabaseConfig, "return_connection") as mock_return:
            result = expertiz_service.publish_admin_report(report_id, {"email": "admin@yerimebak.ai"})

        self.assertTrue(result["success"])
        self.assertEqual(result["report"]["status"], "published")
        self.assertEqual(result["report"]["durum"], "Tamamlandi")
        self.assertEqual(result["report"]["data"]["published_by"], "admin@yerimebak.ai")
        self.assertTrue(conn.committed)
        self.assertTrue(
            any("CREATE TABLE IF NOT EXISTS audit_logs" in query for query, _ in conn.cursor_instance.executed)
        )
        mock_return.assert_called_once_with(conn)

    def test_publish_admin_report_rejects_already_published_without_mutation(self):
        report_id = str(uuid.uuid4())
        conn = FakeConnection(
            [
                {
                    "id": report_id,
                    "status": "published",
                    "durum": "Tamamlandi",
                    "data": {"published_at": "2026-05-13T10:00:00+00:00"},
                    "version_id": 3,
                }
            ]
        )

        with patch.object(expertiz_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(expertiz_service.DatabaseConfig, "return_connection"):
            result = expertiz_service.publish_admin_report(report_id, {"email": "admin@yerimebak.ai"})

        self.assertTrue(result["success"])
        self.assertTrue(result.get("idempotent"))
        self.assertFalse(conn.committed)
        self.assertIsNone(conn.cursor_instance.updated_data)


    def test_publish_admin_report_requires_official_central_ai(self):
        report_id = str(uuid.uuid4())
        conn = FakeConnection([pending_admin_report(report_id, data={"existing": True}, ai_result=None)])

        with patch.object(expertiz_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(expertiz_service.DatabaseConfig, "return_connection"):
            result = expertiz_service.publish_admin_report(report_id, {"email": "admin@yerimebak.ai"})

        self.assertEqual(result["error"], "Resmi rapor yayinlamak icin merkezi AI analizi gereklidir")
        self.assertEqual(result.get("http_status"), 400)
        self.assertFalse(conn.committed)
        self.assertIsNone(conn.cursor_instance.updated_data)

    def test_reject_admin_report_requires_reason(self):
        result = expertiz_service.reject_admin_report(str(uuid.uuid4()), "  ", {"email": "admin@yerimebak.ai"})

        self.assertEqual(result["error"], "Red nedeni zorunludur")
        self.assertEqual(result.get("http_status"), 400)

    def test_reject_admin_report_stores_reason(self):
        report_id = str(uuid.uuid4())
        conn = FakeConnection(
            [
                pending_admin_report(
                    report_id,
                    data={"ai_meta": {"source": "central_ai", "official": True, "ready": True}},
                    ai_result={"tamamlandiMi": True},
                )
            ]
        )

        with patch.object(expertiz_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(expertiz_service.DatabaseConfig, "return_connection"):
            result = expertiz_service.reject_admin_report(
                report_id,
                "Eksik fotograf var",
                {"email": "admin@yerimebak.ai"},
            )

        self.assertTrue(result["success"])
        self.assertEqual(result["report"]["status"], "rejected")
        self.assertEqual(result["report"]["durum"], "Iptal")
        self.assertEqual(result["report"]["data"]["rejection_reason"], "Eksik fotograf var")
        self.assertEqual(result["report"]["data"]["rejected_by"], "admin@yerimebak.ai")
        self.assertTrue(conn.committed)
        self.assertEqual(result["report"]["version_id"], 2)
        self.assertTrue(
            any("CREATE TABLE IF NOT EXISTS audit_logs" in query for query, _ in conn.cursor_instance.executed)
        )

    def test_reject_admin_report_requires_pending_admin_status(self):
        report_id = str(uuid.uuid4())
        conn = FakeConnection(
            [
                {
                    "id": report_id,
                    "status": "pending_ai",
                    "durum": "AI Bekliyor",
                    "data": {"existing": True},
                    "version_id": 1,
                }
            ]
        )

        with patch.object(expertiz_service.DatabaseConfig, "get_connection", return_value=conn):
            result = expertiz_service.reject_admin_report(
                report_id,
                "Eksik fotograf var",
                {"email": "admin@yerimebak.ai"},
            )

        self.assertEqual(result["error"], "Sadece admin onayi bekleyen rapor reddedilebilir")
        self.assertEqual(result.get("http_status"), 400)
        self.assertFalse(conn.committed)
        self.assertIsNone(conn.cursor_instance.updated_data)


if __name__ == "__main__":
    unittest.main()

