import unittest
from datetime import datetime, timedelta

from yerimebak_ai_v5.core.market.market_coverage_service import MarketCoverageService


def listing(brand="Renault", model="Megane", year=2019, fuel="Dizel", transmission="Manuel", days_old=1):
    return {
        "id": 1,
        "brand": brand,
        "model": model,
        "title": f"{year} {brand} {model} {fuel} {transmission}",
        "year": year,
        "fuel": fuel,
        "transmission": transmission,
        "price": 750000,
        "updated_at": datetime.now() - timedelta(days=days_old),
    }


class MarketCoverageServiceTests(unittest.TestCase):
    def test_underfilled_bucket_produces_backfill_target(self):
        service = MarketCoverageService(listings_loader=lambda: [listing(year=2018) for _ in range(3)])
        coverage = service.calculate_coverage(targets=[("Renault", "Megane", "C", 1)])
        bucket = next(row for row in coverage if row["year_bucket"] == "2017-2021")
        self.assertEqual(bucket["active_count"], 3)
        self.assertEqual(bucket["missing_count"], 7)
        self.assertEqual(bucket["coverage_status"], "underfilled")
        backfill = service.build_backfill_targets(coverage)
        self.assertEqual(backfill[0]["year_min"], 2017)
        self.assertEqual(backfill[0]["year_max"], 2021)
        self.assertEqual(backfill[0]["missing_count"], 7)

    def test_filled_but_imbalanced_bucket_is_reported(self):
        service = MarketCoverageService(listings_loader=lambda: [listing(year=2019, fuel="Dizel", transmission="Otomatik") for _ in range(10)])
        coverage = service.calculate_coverage(targets=[("Renault", "Megane", "C", 1)])
        bucket = next(row for row in coverage if row["year_bucket"] == "2017-2021")
        self.assertEqual(bucket["active_count"], 10)
        self.assertEqual(bucket["coverage_status"], "filled_imbalanced")
        self.assertEqual(bucket["fuel_balance"]["diesel"], 10)
        self.assertEqual(bucket["transmission_balance"]["automatic"], 10)

    def test_old_rows_are_marked_stale(self):
        service = MarketCoverageService(listings_loader=lambda: [listing(year=2019, days_old=28) for _ in range(10)])
        coverage = service.calculate_coverage(targets=[("Renault", "Megane", "C", 1)])
        bucket = next(row for row in coverage if row["year_bucket"] == "2017-2021")
        self.assertEqual(bucket["coverage_status"], "stale")


if __name__ == "__main__":
    unittest.main()
