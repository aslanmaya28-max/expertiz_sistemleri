import unittest

from yerimebak_ai_v5.workers.scraper_backfill_planner import ScraperBackfillPlanner


class FakeCoverageService:
    def __init__(self, targets=None, raises=False):
        self.targets = targets or []
        self.raises = raises

    def calculate_coverage(self):
        if self.raises:
            raise RuntimeError("coverage unavailable")
        return [{"coverage_status": "underfilled"}]

    def build_backfill_targets(self, coverage):
        return self.targets


def static_targets():
    return [("Renault", "Clio", "B", 1)]


def years_for_segment(segment):
    return [2018, 2019]


class ScraperBackfillPlannerTests(unittest.TestCase):
    def test_builds_midpoint_job_from_backfill_target(self):
        service = FakeCoverageService(targets=[{
            "brand": "Renault",
            "model": "Megane",
            "segment": "C",
            "priority": 1,
            "year_min": 2017,
            "year_max": 2021,
            "year_bucket": "2017-2021",
            "missing_count": 7,
            "preferred_fuel": "petrol",
            "preferred_transmission": "automatic",
            "reason": "underfilled",
        }])
        planner = ScraperBackfillPlanner(
            coverage_service_factory=lambda: service,
            static_targets_loader=static_targets,
            years_loader=years_for_segment,
        )

        jobs = planner.build_jobs()

        self.assertEqual(len(jobs), 1)
        self.assertEqual(jobs[0]["brand"], "Renault")
        self.assertEqual(jobs[0]["model"], "Megane")
        self.assertEqual(jobs[0]["year"], 2019)
        self.assertEqual(jobs[0]["year_min"], 2017)
        self.assertEqual(jobs[0]["year_max"], 2021)
        self.assertEqual(jobs[0]["mode"], "coverage_backfill")
        self.assertEqual(jobs[0]["preferred_fuel"], "petrol")
        self.assertEqual(jobs[0]["preferred_transmission"], "automatic")

    def test_empty_backfill_uses_static_fallback(self):
        service = FakeCoverageService(targets=[])
        planner = ScraperBackfillPlanner(
            coverage_service_factory=lambda: service,
            static_targets_loader=static_targets,
            years_loader=years_for_segment,
        )

        jobs = planner.build_jobs()

        self.assertEqual([job["year"] for job in jobs], [2018, 2019])
        self.assertEqual(jobs[0]["mode"], "static_fallback")

    def test_coverage_error_uses_static_fallback(self):
        service = FakeCoverageService(raises=True)
        planner = ScraperBackfillPlanner(
            coverage_service_factory=lambda: service,
            static_targets_loader=static_targets,
            years_loader=years_for_segment,
        )

        jobs = planner.build_jobs()

        self.assertEqual(len(jobs), 2)
        self.assertEqual(jobs[0]["brand"], "Renault")
        self.assertEqual(jobs[0]["mode"], "static_fallback")

    def test_max_jobs_limits_output(self):
        service = FakeCoverageService(targets=[])
        planner = ScraperBackfillPlanner(
            coverage_service_factory=lambda: service,
            static_targets_loader=static_targets,
            years_loader=years_for_segment,
        )

        jobs = planner.build_jobs(max_jobs=1)

        self.assertEqual(len(jobs), 1)
        self.assertEqual(jobs[0]["year"], 2018)


if __name__ == "__main__":
    unittest.main()
