import unittest
from unittest.mock import patch

from yerimebak_ai_v5.core.market.market_reference_service import MarketReferenceService


def row(price, year=2019):
    return {
        "id": price,
        "brand": "Renault",
        "model": "Megane",
        "year": year,
        "km": 100000,
        "price": price,
        "fuel": "Dizel",
        "fuel_type": "Dizel",
        "transmission": "Manuel",
        "source": "arabam",
        "title": "Renault Megane",
        "url": f"https://example.com/{price}",
    }


class MarketReferenceQualityTests(unittest.TestCase):
    def test_reference_with_ten_bucket_samples_is_healthy(self):
        service = MarketReferenceService()
        with patch.object(service, "_query_listings", return_value=[row(700000 + i * 10000) for i in range(10)]):
            ref = service.get_reference("Renault", "Megane", year=2019, km=100000, fuel="Dizel", transmission="Manuel", listed_price=750000)
        self.assertTrue(ref["found"])
        self.assertEqual(ref["quality"]["sample_size_status"], "healthy")
        self.assertEqual(ref["quality"]["year_bucket"], "2017-2021")
        self.assertGreaterEqual(ref["confidence"], 90)

    def test_reference_with_five_samples_is_acceptable_not_healthy(self):
        service = MarketReferenceService()
        with patch.object(service, "_query_listings", return_value=[row(700000 + i * 10000) for i in range(5)]):
            ref = service.get_reference("Renault", "Megane", year=2019, km=100000, fuel="Dizel", transmission="Manuel", listed_price=750000)
        self.assertTrue(ref["found"])
        self.assertEqual(ref["quality"]["sample_size_status"], "acceptable")
        self.assertLess(ref["confidence"], 90)

    def test_reference_below_five_uses_last_resort(self):
        service = MarketReferenceService()
        with patch.object(service, "_query_listings", return_value=[row(700000), row(710000), row(720000), row(730000)]):
            ref = service.get_reference("Renault", "Megane", year=2019, km=100000, fuel="Dizel", transmission="Manuel", listed_price=750000)
        self.assertEqual(ref["source"], "last_resort_listed_price")
        self.assertEqual(ref["market_avg_price"], 727500)
        self.assertEqual(ref["confidence"], 20)


if __name__ == "__main__":
    unittest.main()
