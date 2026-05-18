import unittest
from unittest.mock import AsyncMock, MagicMock, patch

from yerimebak_ai_v5.services.url_analysis_job_service import UrlAnalysisJobService


class UrlAnalysisJobServiceTests(unittest.IsolatedAsyncioTestCase):
    async def test_successful_job_completes_history_and_charges_credit(self):
        service = UrlAnalysisJobService()
        with patch("yerimebak_ai_v5.core.market.link_analyzer.link_analyzer") as mock_analyzer, \
             patch("yerimebak_ai_v5.services.payment_service.get_payment_service") as payment_factory:
            mock_analyzer.analyze_url = AsyncMock(return_value={"brand": "Toyota", "model": "Corolla"})
            payment_factory.return_value.complete_queued_analysis.return_value = {"success": True}

            result = await service.process("hist-1", 7, "https://www.sahibinden.com/ilan/1")

        self.assertTrue(result["success"])
        payment_factory.return_value.complete_queued_analysis.assert_called_once()

    async def test_failed_job_calls_mark_failed(self):
        service = UrlAnalysisJobService()
        with patch("yerimebak_ai_v5.core.market.link_analyzer.link_analyzer") as mock_analyzer, \
             patch("yerimebak_ai_v5.services.payment_service.get_payment_service") as payment_factory:
            mock_analyzer.analyze_url = AsyncMock(side_effect=Exception("Scraping failed"))
            payment_factory.return_value.mark_queued_analysis_failed.return_value = {"success": True}

            result = await service.process("hist-1", 7, "https://www.sahibinden.com/ilan/1")

        self.assertFalse(result["success"])
        self.assertIn("Scraping failed", result["error"])
        payment_factory.return_value.mark_queued_analysis_failed.assert_called_once()



