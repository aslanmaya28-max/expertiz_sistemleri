import unittest

from yerimebak_ai_v5.services.analysis_intake_service import AnalysisIntakeService


class AnalysisIntakeServiceTests(unittest.TestCase):
    def test_builds_queue_payload_for_mobile_share_url(self):
        payload = AnalysisIntakeService().build_url_intake(
            url="https://www.sahibinden.com/ilan/vasita-otomobil-test-123",
            source="mobile_share",
        )

        self.assertEqual(payload["source"], "mobile_share")
        self.assertEqual(payload["status"], "queued")
        self.assertEqual(payload["url"], "https://www.sahibinden.com/ilan/vasita-otomobil-test-123")

    def test_rejects_unsupported_source(self):
        with self.assertRaises(ValueError):
            AnalysisIntakeService().build_url_intake(
                url="https://example.com/car",
                source="unknown",
            )

    def test_rejects_invalid_url(self):
        with self.assertRaises(ValueError):
            AnalysisIntakeService().build_url_intake(
                url="",
                source="manual_paste",
            )

    def test_accepts_manual_paste_source(self):
        payload = AnalysisIntakeService().build_url_intake(
            url="https://www.arabam.com/ilan/123",
            source="manual_paste",
        )
        self.assertEqual(payload["source"], "manual_paste")
        self.assertEqual(payload["status"], "queued")

    def test_accepts_chrome_extension_source(self):
        payload = AnalysisIntakeService().build_url_intake(
            url="https://www.sahibinden.com/ilan/test-456",
            source="chrome_extension",
        )
        self.assertEqual(payload["source"], "chrome_extension")
        self.assertEqual(payload["status"], "queued")

    def test_trims_url_whitespace(self):
        payload = AnalysisIntakeService().build_url_intake(
            url="  https://www.arabam.com/ilan/789  ",
            source="manual_paste",
        )
        self.assertEqual(payload["url"], "https://www.arabam.com/ilan/789")

    def test_rejects_url_without_scheme(self):
        with self.assertRaises(ValueError):
            AnalysisIntakeService().build_url_intake(
                url="not-a-url",
                source="manual_paste",
            )
