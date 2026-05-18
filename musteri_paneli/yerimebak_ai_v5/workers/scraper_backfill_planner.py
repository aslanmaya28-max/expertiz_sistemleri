# -*- coding: utf-8 -*-
from __future__ import annotations

import logging
from typing import Callable, Dict, Iterable, List, Optional

from yerimebak_ai_v5.core.market.market_coverage_service import MarketCoverageService
from yerimebak_ai_v5.workers.turkey_targets import get_priority_queue, get_years_for_segment


logger = logging.getLogger(__name__)


class ScraperBackfillPlanner:
    def __init__(
        self,
        coverage_service_factory: Callable[[], MarketCoverageService] = MarketCoverageService,
        static_targets_loader: Callable[[], Iterable] = get_priority_queue,
        years_loader: Callable[[str], Iterable[int]] = get_years_for_segment,
    ):
        self.coverage_service_factory = coverage_service_factory
        self.static_targets_loader = static_targets_loader
        self.years_loader = years_loader

    def build_jobs(self, max_jobs: Optional[int] = None) -> List[Dict]:
        jobs = self._coverage_jobs()
        if not jobs:
            jobs = self._static_jobs()
        if max_jobs is not None:
            return jobs[:max_jobs]
        return jobs

    def _coverage_jobs(self) -> List[Dict]:
        try:
            service = self.coverage_service_factory()
            coverage = service.calculate_coverage()
            targets = service.build_backfill_targets(coverage)
        except Exception as exc:
            logger.warning("[SCRAPER BACKFILL] coverage unavailable, static fallback will be used: %s", exc)
            return []

        jobs = []
        for target in targets:
            year_min = int(target["year_min"])
            year_max = int(target["year_max"])
            jobs.append({
                "brand": target["brand"],
                "model": target["model"],
                "segment": target["segment"],
                "priority": target.get("priority", 3),
                "year": self._midpoint_year(year_min, year_max),
                "year_min": year_min,
                "year_max": year_max,
                "year_bucket": target.get("year_bucket"),
                "missing_count": target.get("missing_count", 0),
                "preferred_fuel": target.get("preferred_fuel"),
                "preferred_transmission": target.get("preferred_transmission"),
                "reason": target.get("reason"),
                "mode": "coverage_backfill",
            })

        return sorted(jobs, key=lambda job: (job["priority"], job["missing_count"], job["brand"], job["model"], job["year"]))

    def _static_jobs(self) -> List[Dict]:
        jobs = []
        for brand, model, segment, priority in self.static_targets_loader():
            for year in self.years_loader(segment):
                jobs.append({
                    "brand": brand,
                    "model": model,
                    "segment": segment,
                    "priority": priority,
                    "year": int(year),
                    "year_min": int(year),
                    "year_max": int(year),
                    "year_bucket": str(year),
                    "missing_count": 0,
                    "preferred_fuel": None,
                    "preferred_transmission": None,
                    "reason": "static_fallback",
                    "mode": "static_fallback",
                })
        return jobs

    def _midpoint_year(self, year_min: int, year_max: int) -> int:
        return int((year_min + year_max) // 2)
