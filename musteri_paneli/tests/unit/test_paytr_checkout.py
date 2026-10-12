import base64
import hashlib
import hmac
import json
import os
import unittest
from unittest.mock import MagicMock, patch

from yerimebak_ai_v5.services import checkout_service, paytr_service, valuation_service

PAYTR_ENV = {
    "PAYTR_MERCHANT_ID": "123456",
    "PAYTR_MERCHANT_KEY": "anahtar",
    "PAYTR_MERCHANT_SALT": "tuz",
    "PAYTR_TEST_MODE": "1",
}


def _expected_sign(message: str, key: str = "anahtar") -> str:
    return base64.b64encode(hmac.new(key.encode(), message.encode(), hashlib.sha256).digest()).decode()


class PaytrSigningTests(unittest.TestCase):
    def test_get_token_request_signature(self):
        with patch.dict(os.environ, PAYTR_ENV, clear=False):
            body = paytr_service.build_token_request(
                "CRABC123", "a@b.com", 400, [("10 Analiz", 400.0, 1)], "1.2.3.4", "Ali", "05551112233"
            )
        self.assertEqual(body["payment_amount"], "40000")  # kurus
        self.assertEqual(json.loads(base64.b64decode(body["user_basket"])), [["10 Analiz", "400.00", 1]])
        hash_str = (
            f"123456" f"1.2.3.4" f"CRABC123" f"a@b.com" f"40000" f"{body['user_basket']}" f"1" f"0" f"TL" f"1"
        )
        self.assertEqual(body["paytr_token"], _expected_sign(hash_str + "tuz"))

    def test_merchant_oid_must_be_alphanumeric(self):
        with patch.dict(os.environ, PAYTR_ENV, clear=False):
            with self.assertRaises(paytr_service.PaytrError):
                paytr_service.build_token_request("CR-1", "a@b.com", 1, [], "1.1.1.1", "", "")

    def test_callback_signature_verification(self):
        with patch.dict(os.environ, PAYTR_ENV, clear=False):
            good = {"merchant_oid": "EX1", "status": "success", "total_amount": "1000",
                    "hash": _expected_sign("EX1" + "tuz" + "success" + "1000")}
            self.assertTrue(paytr_service.verify_callback(good))
            self.assertFalse(paytr_service.verify_callback({**good, "total_amount": "999999"}))
            self.assertFalse(paytr_service.verify_callback({**good, "hash": "sahte"}))

    def test_callback_rejected_when_not_configured(self):
        with patch.dict(os.environ, {k: "" for k in PAYTR_ENV}, clear=False):
            self.assertFalse(paytr_service.verify_callback({"merchant_oid": "EX1", "status": "success", "total_amount": "1", "hash": "x"}))

    def test_client_ip_prefers_real_ip_header(self):
        self.assertEqual(paytr_service.client_ip({"x-real-ip": "5.6.7.8", "x-forwarded-for": "9.9.9.9"}, "127.0.0.1"), "5.6.7.8")
        self.assertEqual(paytr_service.client_ip({"x-forwarded-for": "9.9.9.9, 10.0.0.1"}, None), "9.9.9.9")


class ProductionSafetyTests(unittest.TestCase):
    def test_no_payment_without_paytr_credentials(self):
        env = {**{k: "" for k in PAYTR_ENV}, "PAYMENT_SIMULATION": ""}
        with patch.dict(os.environ, env, clear=False):
            with self.assertRaises(paytr_service.PaytrError):
                paytr_service.create_payment("CRX", "a@b.com", 100, [], "1.1.1.1")

    def test_simulation_disabled_by_default(self):
        with patch.dict(os.environ, {"PAYMENT_SIMULATION": ""}, clear=False):
            result = checkout_service.simulate_payment("CRX", {"id": 1})
        self.assertEqual(result["http_status"], 403)

    def test_credit_packages_match_business_rules(self):
        from yerimebak_ai_v5.services.payment_service import CREDIT_PACKAGES

        self.assertEqual(
            {(v["price"], v["credits"]) for v in CREDIT_PACKAGES.values()},
            {(100, 3), (250, 5), (400, 10), (750, 11)},
        )


class InflationProjectionTests(unittest.TestCase):
    def test_six_and_twelve_month_projection(self):
        settings = {"vehicle_inflation": {"monthly_pct": 2.0, "note": "test", "effective_date": "2026-10-01"}}
        with patch.object(valuation_service.pricing_service, "get_pricing_settings", return_value=settings):
            p = valuation_service.inflation_projection(1_000_000, 970_000)
        self.assertEqual(p["altiAy"]["tahminiDeger"], round(1_000_000 * 1.02 ** 6, -3))
        self.assertEqual(p["birYil"]["tahminiDeger"], round(1_000_000 * 1.02 ** 12, -3))
        self.assertEqual(p["yillikEnflasyonYuzde"], round((1.02 ** 12 - 1) * 100, 1))
        self.assertGreater(p["birYil"]["getiriTl"], p["altiAy"]["getiriTl"])

    def test_no_projection_until_admin_sets_rate(self):
        with patch.object(valuation_service.pricing_service, "get_pricing_settings", return_value={"vehicle_inflation": None}):
            self.assertIsNone(valuation_service.inflation_projection(1_000_000, 970_000))


class ValuationInputTests(unittest.TestCase):
    def test_only_known_parts_and_statuses_are_used(self):
        parts = valuation_service._clean_parts(
            {"kaput": "degisen", "solOnKapi": "orijinal", "uzay": "boyali", "tavan": "yanlis"}
        )
        self.assertEqual(parts, {"kaput": "degisen"})

    def test_url_normalization_ignores_query_and_case(self):
        self.assertEqual(
            valuation_service.normalize_url("WWW.Arabam.com/ilan/x/123/?utm=1#foto"),
            "https://www.arabam.com/ilan/x/123",
        )

    def test_missing_fields_rejected_before_credit_check(self):
        payment = MagicMock()
        with patch("yerimebak_ai_v5.services.payment_service.get_payment_service", return_value=payment):
            result = valuation_service.analyze({"id": 1}, {"brand": "Fiat"})
        self.assertIn("Eksik bilgi", result["error"])
        payment.check_credits_before_analysis.assert_not_called()


if __name__ == "__main__":
    unittest.main()
