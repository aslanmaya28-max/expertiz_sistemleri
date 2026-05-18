import unittest
from unittest.mock import patch, AsyncMock

from yerimebak_ai_v5.api.v1.endpoints.analysis_intake import create_url_analysis, UrlAnalysisRequest


class AnalysisIntakeApiTests(unittest.IsolatedAsyncioTestCase):
    async def test_manual_paste_creates_queued_history_entry(self):
        fake_user = {"id": 7}
        with patch("yerimebak_ai_v5.api.v1.endpoints.analysis_intake.get_analysis_intake_service") as intake_factory, \
             patch("yerimebak_ai_v5.api.v1.endpoints.analysis_intake.get_payment_service") as payment_factory:
            intake_factory.return_value.build_url_intake.return_value = {
                "url": "https://www.sahibinden.com/ilan/1",
                "source": "manual_paste",
                "status": "queued",
            }
            payment_factory.return_value.record_queued_analysis.return_value = {
                "success": True,
                "history_id": "hist-1",
            }

            result = await create_url_analysis(
                UrlAnalysisRequest(url="https://www.sahibinden.com/ilan/1", source="manual_paste"),
                user=fake_user,
            )

        self.assertEqual(result["status"], "queued")
        self.assertEqual(result["history_id"], "hist-1")
        self.assertTrue(result["success"])

    async def test_mobile_share_creates_queued_history_entry(self):
        fake_user = {"id": 10}
        with patch("yerimebak_ai_v5.api.v1.endpoints.analysis_intake.get_analysis_intake_service") as intake_factory, \
             patch("yerimebak_ai_v5.api.v1.endpoints.analysis_intake.get_payment_service") as payment_factory:
            intake_factory.return_value.build_url_intake.return_value = {
                "url": "https://www.arabam.com/ilan/2",
                "source": "mobile_share",
                "status": "queued",
            }
            payment_factory.return_value.record_queued_analysis.return_value = {
                "success": True,
                "history_id": "hist-2",
            }

            result = await create_url_analysis(
                UrlAnalysisRequest(url="https://www.arabam.com/ilan/2", source="mobile_share"),
                user=fake_user,
            )

        self.assertEqual(result["status"], "queued")
        self.assertEqual(result["history_id"], "hist-2")

    async def test_rejects_invalid_url(self):
        fake_user = {"id": 7}
        with patch("yerimebak_ai_v5.api.v1.endpoints.analysis_intake.get_analysis_intake_service") as intake_factory, \
             patch("yerimebak_ai_v5.api.v1.endpoints.analysis_intake.get_payment_service"):
            intake_factory.return_value.build_url_intake.side_effect = ValueError("Gecersiz URL")

            from fastapi import HTTPException
            with self.assertRaises(HTTPException):
                await create_url_analysis(
                    UrlAnalysisRequest(url="invalid", source="manual_paste"),
                    user=fake_user,
                )
