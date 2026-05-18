import asyncio
import json
import os
import sys
import types
import unittest
from unittest.mock import AsyncMock, Mock, patch

os.environ.setdefault("SECRET_KEY", "test-secret-key")
sys.modules.setdefault("bcrypt", types.ModuleType("bcrypt"))
sys.modules.setdefault("jwt", types.ModuleType("jwt"))

from yerimebak_ai_v5.api.v1.endpoints.analysis_intake import (
    UrlAnalysisRequest,
    create_url_analysis_intake,
)
from yerimebak_ai_v5.services import payment_service
from yerimebak_ai_v5.services.payment_service import PaymentService
from yerimebak_ai_v5.services.url_analysis_job_service import UrlAnalysisJobService


class FakeIntakeService:
    def build_url_intake(self, url: str, source: str) -> dict:
        return {"url": url.strip(), "source": source, "status": "queued"}


class FakePaymentForEndpoint:
    def record_queued_analysis(self, user_id: int, intake_payload: dict) -> dict:
        return {"success": True, "history_id": "hist-1"}


class FakeBackgroundTasks:
    def __init__(self):
        self.calls = []

    def add_task(self, func, *args):
        self.calls.append((func, args))


class FakeCursor:
    def __init__(self, rows=None):
        self.rows = list(rows or [])
        self.executed = []

    def execute(self, query, params=None):
        self.executed.append((query, params))

    def fetchone(self):
        return self.rows.pop(0) if self.rows else None


class FakeConnection:
    def __init__(self, rows=None):
        self.cursor_instance = FakeCursor(rows)
        self.committed = False

    def cursor(self):
        return self.cursor_instance

    def commit(self):
        self.committed = True


class UrlAnalysisJobServiceTests(unittest.TestCase):
    def test_endpoint_schedules_background_processing_for_new_history_row(self):
        background_tasks = FakeBackgroundTasks()
        job_service = Mock()

        result = asyncio.run(
            create_url_analysis_intake(
                UrlAnalysisRequest(url=" https://example.com/car "),
                background_tasks=background_tasks,
                user={"id": 7},
                intake_service=FakeIntakeService(),
                payment_service=FakePaymentForEndpoint(),
                job_service=job_service,
            )
        )

        self.assertEqual(result["history_id"], "hist-1")
        self.assertEqual(
            background_tasks.calls,
            [(job_service.process, ("hist-1", 7, "https://example.com/car"))],
        )

    def test_successful_job_completes_existing_history_and_charges_credit(self):
        payment = Mock()
        analyzer = Mock()
        analyzer.analyze_url = AsyncMock(return_value={"brand": "Toyota", "model": "Corolla"})

        asyncio.run(
            UrlAnalysisJobService(analyzer=analyzer, payment_service=payment).process(
                "hist-1",
                7,
                "https://example.com/car",
            )
        )

        analyzer.analyze_url.assert_awaited_once_with("https://example.com/car", save_to_db=False)
        payment.complete_queued_analysis.assert_called_once_with(
            "hist-1",
            7,
            {"brand": "Toyota", "model": "Corolla"},
        )
        payment.mark_queued_analysis_failed.assert_not_called()

    def test_analyzer_error_marks_history_failed_without_charging(self):
        payment = Mock()
        analyzer = Mock()
        analyzer.analyze_url = AsyncMock(return_value={"error": "unsupported"})

        asyncio.run(
            UrlAnalysisJobService(analyzer=analyzer, payment_service=payment).process(
                "hist-1",
                7,
                "https://example.com/car",
            )
        )

        payment.mark_queued_analysis_failed.assert_called_once_with("hist-1", 7, "unsupported")
        payment.complete_queued_analysis.assert_not_called()

    def test_complete_queued_analysis_updates_same_row_and_deducts_credit(self):
        conn = FakeConnection(rows=[{"credits": 2}])

        with patch.object(payment_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(payment_service.DatabaseConfig, "return_connection"):
            result = PaymentService().complete_queued_analysis(
                "hist-1",
                7,
                {"brand": "Toyota", "model": "Corolla"},
            )

        executed_sql = [" ".join(query.split()).lower() for query, _ in conn.cursor_instance.executed]
        self.assertTrue(conn.committed)
        self.assertIn("update users", executed_sql[0])
        self.assertIn("update analysis_history", executed_sql[1])
        self.assertNotIn("insert into analysis_history", " ".join(executed_sql))
        self.assertEqual(
            json.loads(conn.cursor_instance.executed[1][1][0]),
            {"brand": "Toyota", "model": "Corolla", "status": "completed"},
        )
        self.assertEqual(result["credits_after"], 2)

    def test_mark_queued_analysis_failed_updates_same_row_without_charging(self):
        conn = FakeConnection()

        with patch.object(payment_service.DatabaseConfig, "get_connection", return_value=conn), \
             patch.object(payment_service.DatabaseConfig, "return_connection"):
            result = PaymentService().mark_queued_analysis_failed("hist-1", 7, "unsupported")

        executed_sql = [" ".join(query.split()).lower() for query, _ in conn.cursor_instance.executed]
        self.assertTrue(conn.committed)
        self.assertEqual(len(executed_sql), 1)
        self.assertIn("update analysis_history", executed_sql[0])
        self.assertNotIn("update users", executed_sql[0])
        self.assertEqual(
            json.loads(conn.cursor_instance.executed[0][1][0]),
            {"status": "failed", "error": "unsupported"},
        )
        self.assertEqual(result, {"success": True, "history_id": "hist-1"})


if __name__ == "__main__":
    unittest.main()
