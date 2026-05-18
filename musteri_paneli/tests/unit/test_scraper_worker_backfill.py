import asyncio
import unittest
from unittest.mock import patch

from yerimebak_ai_v5.workers.scraper_worker import ScraperWorker


class FakePlanner:
    def build_jobs(self, max_jobs=None):
        return [{
            "brand": "Renault",
            "model": "Megane",
            "segment": "C",
            "priority": 1,
            "year": 2019,
            "mode": "coverage_backfill",
            "reason": "underfilled",
        }]


class ScraperWorkerBackfillTests(unittest.TestCase):
    def test_worker_processes_planner_jobs(self):
        processed = []

        async def fake_process_vehicle(self, brand, model, year):
            processed.append((brand, model, year))

        with patch("yerimebak_ai_v5.workers.scraper_worker.get_repository", return_value=object()):
            worker = ScraperWorker(planner=FakePlanner())

        with patch.object(ScraperWorker, "process_vehicle", fake_process_vehicle):
            asyncio.run(worker.process_scrape_jobs())

        self.assertEqual(processed, [("Renault", "Megane", 2019)])


if __name__ == "__main__":
    unittest.main()
