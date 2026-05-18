# -*- coding: utf-8 -*-
from __future__ import annotations

from collections import Counter, defaultdict
from datetime import datetime, timedelta
from typing import Any, Callable, Dict, Iterable, List

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.core.market.quota_policy import (
    BUCKET_TARGET_COUNT,
    find_segment_for_vehicle,
    get_balance_targets,
    get_year_bucket,
    get_year_buckets_for_segment,
)
from yerimebak_ai_v5.core.market.vehicle_normalizer import normalize_listing_vehicle
from yerimebak_ai_v5.workers.turkey_targets import TURKEY_2EL_TARGETS


class MarketCoverageService:
    def __init__(self, listings_loader: Callable[[], Iterable[Dict[str, Any]]] | None = None, retention_days: int = 27):
        self.listings_loader = listings_loader or self._load_listings
        self.retention_days = retention_days

    def calculate_coverage(self, targets=None) -> List[Dict[str, Any]]:
        targets = targets or TURKEY_2EL_TARGETS
        grouped = self._group_listings(self.listings_loader())
        rows: List[Dict[str, Any]] = []

        for brand, model, segment, priority in self._iter_targets(targets):
            segment = segment or find_segment_for_vehicle(brand, model)
            for start, end in get_year_buckets_for_segment(segment):
                bucket_name = f"{start}-{end}"
                listings = grouped.get((brand, model, bucket_name), [])
                active_count = len(listings)
                stale_count = sum(1 for item in listings if self._is_stale(item.get("updated_at")))
                fuel_balance = self._balance_counts(listings, "normalized_fuel", get_balance_targets(segment)["fuel"])
                transmission_balance = self._balance_counts(
                    listings,
                    "normalized_transmission",
                    get_balance_targets(segment)["transmission"],
                )

                rows.append({
                    "brand": brand,
                    "model": model,
                    "segment": segment,
                    "priority": priority,
                    "year_bucket": bucket_name,
                    "year_min": start,
                    "year_max": end,
                    "active_count": active_count,
                    "target_count": BUCKET_TARGET_COUNT,
                    "missing_count": max(0, BUCKET_TARGET_COUNT - active_count),
                    "stale_count": stale_count,
                    "fuel_balance": fuel_balance,
                    "transmission_balance": transmission_balance,
                    "coverage_status": self._status(active_count, stale_count, fuel_balance, transmission_balance),
                })

        return rows

    def build_backfill_targets(self, coverage: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        targets = []
        for row in coverage:
            if row["coverage_status"] == "healthy":
                continue

            targets.append({
                "brand": row["brand"],
                "model": row["model"],
                "segment": row["segment"],
                "year_min": row["year_min"],
                "year_max": row["year_max"],
                "year_bucket": row["year_bucket"],
                "missing_count": row["missing_count"],
                "preferred_fuel": self._preferred(row["fuel_balance"]),
                "preferred_transmission": self._preferred(row["transmission_balance"]),
                "priority": row["priority"],
                "reason": row["coverage_status"],
            })

        return sorted(targets, key=lambda item: (item["priority"], item["missing_count"], item["brand"], item["model"]))

    def _group_listings(self, listings: Iterable[Dict[str, Any]]):
        grouped = defaultdict(list)
        for listing in listings:
            normalized = normalize_listing_vehicle(listing)
            brand = normalized["normalized_brand"]
            model = normalized["normalized_model"]
            if model == "unknown_model":
                continue

            year = listing.get("year")
            if not year:
                continue

            segment = find_segment_for_vehicle(brand, model)
            year_bucket = get_year_bucket(int(year), segment)
            if year_bucket == "out_of_scope":
                continue

            item = dict(listing)
            item.update(normalized)
            grouped[(brand, model, year_bucket)].append(item)

        return grouped

    def _balance_counts(self, listings: List[Dict[str, Any]], key: str, targets: Dict[str, int]) -> Dict[str, Any]:
        counts = Counter()
        for item in listings:
            value = item.get(key) or "unknown"
            if "other" in targets and value not in targets:
                value = "other"
            counts[value] += 1

        result: Dict[str, Any] = dict(counts)
        if not targets:
            result["status"] = "not_applicable"
            return result

        missing = {name: max(0, target - counts.get(name, 0)) for name, target in targets.items()}
        result["missing"] = missing
        result["status"] = "imbalanced" if any(value > 0 for value in missing.values()) else "healthy"
        return result

    def _status(self, active_count: int, stale_count: int, fuel_balance: Dict[str, Any], transmission_balance: Dict[str, Any]) -> str:
        if active_count < BUCKET_TARGET_COUNT:
            return "underfilled"
        if stale_count > 0:
            return "stale"
        if fuel_balance.get("status") == "imbalanced" or transmission_balance.get("status") == "imbalanced":
            return "filled_imbalanced"
        return "healthy"

    def _preferred(self, balance: Dict[str, Any]) -> str | None:
        missing = balance.get("missing") or {}
        if not missing:
            return None
        return max(missing.items(), key=lambda item: item[1])[0]

    def _is_stale(self, updated_at: Any) -> bool:
        parsed = self._parse_datetime(updated_at)
        if not parsed:
            return False
        return parsed < datetime.now() - timedelta(days=self.retention_days)

    def _parse_datetime(self, value: Any) -> datetime | None:
        if isinstance(value, datetime):
            return value
        if isinstance(value, str):
            try:
                return datetime.fromisoformat(value.replace("Z", "+00:00")).replace(tzinfo=None)
            except ValueError:
                return None
        return None

    def _load_listings(self) -> List[Dict[str, Any]]:
        conn = DatabaseConfig.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                """
                SELECT id, brand, model, year, fuel, fuel_type, transmission, title,
                       description, price, updated_at
                FROM listings
                WHERE price IS NOT NULL AND year IS NOT NULL
                """
            )
            return [dict(row) for row in cursor.fetchall()]
        finally:
            DatabaseConfig.return_connection(conn)

    def _iter_targets(self, targets):
        for target in targets:
            if isinstance(target, dict):
                yield target.get("brand"), target.get("model"), target.get("segment"), target.get("priority", 3)
            else:
                yield target
