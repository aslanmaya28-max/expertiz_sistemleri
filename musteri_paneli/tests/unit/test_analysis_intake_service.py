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
        self.assertEqual(
            payload["url"],
            "https://www.sahibinden.com/ilan/vasita-otomobil-test-123",
        )

    def test_rejects_unsupported_source(self):
        with self.assertRaises(ValueError):
            AnalysisIntakeService().build_url_intake(
                url="https://example.com/car",
                source="unknown",
            )

    def test_trims_url_before_building_payload(self):
        payload = AnalysisIntakeService().build_url_intake(
            url="  https://example.com/car  ",
            source="manual_paste",
        )

        self.assertEqual(payload["url"], "https://example.com/car")

    def test_accepts_each_supported_source(self):
        for source in ("mobile_share", "manual_paste", "chrome_extension"):
            with self.subTest(source=source):
                payload = AnalysisIntakeService().build_url_intake(
                    url="https://example.com/car",
                    source=source,
                )

                self.assertEqual(payload["source"], source)

    def test_rejects_invalid_url(self):
        with self.assertRaises(ValueError):
            AnalysisIntakeService().build_url_intake(
                url="not-a-url",
                source="manual_paste",
            )

    def test_rejects_non_web_scheme(self):
        with self.assertRaises(ValueError):
            AnalysisIntakeService().build_url_intake(
                url="ftp://example.com/car",
                source="manual_paste",
            )


if __name__ == "__main__":
    unittest.main()
