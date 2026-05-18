import unittest
from unittest.mock import patch

from yerimebak_ai_v5.core.infrastructure.supabase_bridge import SupabaseBridge


class FakeCursor:
    def __init__(self):
        self.executed = []
        self.updated_data = None

    def execute(self, query, params=None):
        self.executed.append((query, params))
        if query.strip().startswith("SELECT data FROM reports"):
            return
        if "UPDATE reports SET" in query:
            self.updated_data = params[2].adapted

    def fetchone(self):
        return {"data": {"tam_rapor": {"id": "r1"}}}


class FakeConnection:
    def __init__(self):
        self.cursor_instance = FakeCursor()
        self.committed = False

    def cursor(self):
        return self.cursor_instance

    def commit(self):
        self.committed = True

    def rollback(self):
        pass


class CentralAiMetadataTests(unittest.TestCase):
    def test_write_ai_results_marks_result_as_official_central_ai(self):
        conn = FakeConnection()
        bridge = SupabaseBridge()
        market_reference = {
            "found": True,
            "source": "listings",
            "count": 7,
            "market_avg_price": 1200000,
            "confidence": 85,
        }

        with patch("yerimebak_ai_v5.core.infrastructure.supabase_bridge.DatabaseConfig.get_connection", return_value=conn), \
             patch("yerimebak_ai_v5.core.infrastructure.supabase_bridge.DatabaseConfig.return_connection"):
            success = bridge.write_ai_results(
                "report-1",
                {"tamamlandiMi": True, "raporOzeti": {}},
                market_reference=market_reference,
                source="central_ai",
            )

        self.assertTrue(success)
        data = conn.cursor_instance.updated_data
        self.assertEqual(data["ai_meta"]["source"], "central_ai")
        self.assertTrue(data["ai_meta"]["official"])
        self.assertTrue(data["ai_meta"]["ready"])
        self.assertEqual(data["ai_meta"]["reference_count"], 7)
        self.assertEqual(data["ai_analiz_sonucu"]["source"], "central_ai")
        self.assertTrue(conn.committed)


if __name__ == "__main__":
    unittest.main()
