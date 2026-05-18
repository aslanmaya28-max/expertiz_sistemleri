import unittest

from yerimebak_ai_v5.core.market.quota_policy import (
    find_segment_for_vehicle,
    get_balance_targets,
    get_year_bucket,
    get_year_buckets_for_segment,
)


class QuotaPolicyTests(unittest.TestCase):
    def test_standard_year_buckets(self):
        self.assertEqual(get_year_bucket(2014, "C"), "2012-2016")
        self.assertEqual(get_year_bucket(2019, "SUV"), "2017-2021")
        self.assertEqual(get_year_bucket(2025, "B"), "2022-2026")

    def test_ev_year_buckets(self):
        self.assertEqual(get_year_buckets_for_segment("EV"), [(2020, 2022), (2023, 2026)])
        self.assertEqual(get_year_bucket(2024, "EV"), "2023-2026")

    def test_balance_targets_for_segments(self):
        self.assertEqual(get_balance_targets("C"), {"fuel": {"petrol": 5, "diesel": 5}, "transmission": {"automatic": 5, "manual": 5}})
        self.assertEqual(get_balance_targets("SUV"), {"fuel": {"petrol": 5, "diesel": 5}, "transmission": {"automatic": 5, "manual": 5}})
        self.assertEqual(get_balance_targets("Ticari"), {"fuel": {"diesel": 7, "other": 3}, "transmission": {"manual": 6, "automatic": 4}})
        self.assertEqual(get_balance_targets("EV"), {"fuel": {}, "transmission": {}})

    def test_finds_segment_from_existing_turkey_targets(self):
        self.assertEqual(find_segment_for_vehicle("Renault", "Megane"), "C")
        self.assertEqual(find_segment_for_vehicle("Fiat", "Doblo"), "Ticari")


if __name__ == "__main__":
    unittest.main()
