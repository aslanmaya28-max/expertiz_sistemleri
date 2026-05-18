import unittest

from yerimebak_ai_v5.api.v1.router import api_router


class MarketCoverageApiTests(unittest.TestCase):
    def test_market_coverage_routes_are_registered(self):
        paths = {route.path for route in api_router.routes}
        self.assertIn("/market-coverage/summary", paths)
        self.assertIn("/market-coverage/backfill-targets", paths)


if __name__ == "__main__":
    unittest.main()
