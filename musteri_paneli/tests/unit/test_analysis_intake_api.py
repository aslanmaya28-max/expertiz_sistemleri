import asyncio
import os
import sys
import types
import unittest
from unittest.mock import patch

os.environ.setdefault("SECRET_KEY", "test-secret-key")
sys.modules.setdefault("bcrypt", types.ModuleType("bcrypt"))
sys.modules.setdefault("jwt", types.ModuleType("jwt"))

from yerimebak_ai_v5.api.v1.router import api_router
from yerimebak_ai_v5.api.v1.endpoints.analysis_intake import (
    UrlAnalysisRequest,
    create_url_analysis_intake,
)
from yerimebak_ai_v5.services.payment_service import PaymentService
from yerimebak_ai_v5.services import payment_service


class FakeIntakeService:
    def __init__(self):
        self.calls = []

    def build_url_intake(self, url: str, source: str) -> dict:
        self.calls.append((url, source))
        return {"url": url.strip(), "source": source, "status": "queued"}


class FakePaymentService:
    def __init__(self):
        self.calls = []

    def record_queued_analysis(self, user_id: int, intake_payload: dict) -> dict:
        self.calls.append((user_id, intake_payload))
        return {"success": True, "history_id": "history-123"}


class FakeCursor:
    def __init__(self):
        self.executed = []

    def execute(self, query, params=None):
        self.executed.append((query, params))


class FakeConnection:
    def __init__(self):
        self.cursor_instance = FakeCursor()
        self.committed = False

    def cursor(self):
        return self.cursor_instance

    def commit(self):
        self.committed = True


class AnalysisIntakeApiTests(unittest.TestCase):
    def test_analysis_intake_url_route_is_registered(self):
        paths = {route.path for route in api_router.routes}

        self.assertIn("/analysis-intake/url", paths)

    def test_url_intake_queues_history_without_charging(self):
        intake_service = FakeIntakeService()
        payment = FakePaymentService()

        result = asyncio.run(
            create_url_analysis_intake(
                UrlAnalysisRequest(url="  https://example.com/car  "),
                user={"id": 42},
                intake_service=intake_service,
                payment_service=payment,
            )
        )

        self.assertEqual(
            intake_service.calls,
            [("  https://example.com/car  ", "manual_paste")],
        )
        self.assertEqual(
            payment.calls,
            [
                (
                    42,
                    {
                        "url": "https://example.com/car",
                        "source": "manual_paste",
                        "status": "queued",
                    },
                )
            ],
        )
        self.assertEqual(
            result,
            {"success": True, "status": "queued", "history_id": "history-123"},
        )

    def test_record_queued_analysis_only_writes_history(self):
        conn = FakeConnection()

        with patch.object(payment_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(payment_service.DatabaseConfig, "return_connection"):
            result = PaymentService().record_queued_analysis(
                42,
                {
                    "url": "https://example.com/car",
                    "source": "manual_paste",
                    "status": "queued",
                },
            )

        executed_sql = [" ".join(query.split()).lower() for query, _ in conn.cursor_instance.executed]
        self.assertTrue(conn.committed)
        self.assertEqual(len(executed_sql), 1)
        self.assertIn("insert into analysis_history", executed_sql[0])
        self.assertNotIn("update users", executed_sql[0])
        self.assertEqual(result["success"], True)
        self.assertIn("history_id", result)


if __name__ == "__main__":
    unittest.main()
