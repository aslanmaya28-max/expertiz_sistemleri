import unittest

from yerimebak_ai_v5.core.market.vehicle_normalizer import normalize_listing_vehicle


class VehicleNormalizerTests(unittest.TestCase):
    def test_normalizes_known_brand_aliases_and_model_variants(self):
        result = normalize_listing_vehicle({
            "brand": "VW",
            "model": "Golf 1.6 TDI Comfortline",
            "title": "2018 Volkswagen Golf 1.6 TDI Comfortline",
            "fuel": "Dizel",
            "transmission": "Manuel",
        })

        self.assertEqual(result["normalized_brand"], "Volkswagen")
        self.assertEqual(result["normalized_model"], "Golf")
        self.assertEqual(result["normalized_fuel"], "diesel")
        self.assertEqual(result["normalized_transmission"], "manual")
        self.assertGreaterEqual(result["model_confidence"], 80)

    def test_recovers_model_from_title_when_model_is_engine_variant(self):
        result = normalize_listing_vehicle({
            "brand": "RENAULT",
            "model": "1.5 dCi",
            "title": "2020 Renault Megane 1.5 dCi Icon EDC",
            "fuel": "Dizel",
            "transmission": "Otomatik",
        })

        self.assertEqual(result["normalized_brand"], "Renault")
        self.assertEqual(result["normalized_model"], "Megane")
        self.assertEqual(result["normalized_fuel"], "diesel")
        self.assertEqual(result["normalized_transmission"], "automatic")
        self.assertGreaterEqual(result["model_confidence"], 70)

    def test_marks_unrecoverable_engine_variant_as_unknown_model(self):
        result = normalize_listing_vehicle({
            "brand": "RENAULT",
            "model": "1.5 dCi",
            "title": "Temiz aile araci dizel",
        })

        self.assertEqual(result["normalized_brand"], "Renault")
        self.assertEqual(result["normalized_model"], "unknown_model")
        self.assertLess(result["model_confidence"], 50)


if __name__ == "__main__":
    unittest.main()
