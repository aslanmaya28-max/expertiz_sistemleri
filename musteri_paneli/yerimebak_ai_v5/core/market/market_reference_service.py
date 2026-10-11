import logging
import statistics
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.core.market.quota_policy import BUCKET_TARGET_COUNT, find_segment_for_vehicle, get_year_bucket

logger = logging.getLogger(__name__)

# Bu süreden eski ilanlar "eski piyasa verisi" sayılır; yeterli güncel ilan varsa kullanılmaz.
RECENT_DAYS = 90


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        if value is None:
            return default
        if isinstance(value, (int, float)):
            return int(value)
        return int(float(str(value).replace(".", "").replace(",", ".")))
    except Exception:
        return default


def _row_to_dict(row: Any) -> Dict[str, Any]:
    if row is None:
        return {}
    if isinstance(row, dict):
        return row
    try:
        return dict(row)
    except Exception:
        return {}


class MarketReferenceService:
    """Calculates market reference values from the real listings table."""

    def get_reference(
        self,
        brand: str,
        model: str,
        year: Optional[int] = None,
        km: Optional[int] = None,
        fuel: Optional[str] = None,
        transmission: Optional[str] = None,
        exclude_id: Optional[int] = None,
        listed_price: Optional[float] = None,
        limit: int = 80,
    ) -> Dict[str, Any]:
        brand = (brand or "").strip()
        model = (model or "").strip()
        year_val = _safe_int(year)
        km_val = _safe_int(km)

        fallback_price = _safe_int(listed_price)

        if not brand or not model:
            return self._last_resort("missing_brand_model", fallback_price)

        attempts = [
            {"year_window": 1, "km_pct": 0.35, "with_fuel": True, "with_transmission": True},
            {"year_window": 2, "km_pct": 0.50, "with_fuel": True, "with_transmission": False},
            {"year_window": 3, "km_pct": 0.70, "with_fuel": False, "with_transmission": False},
            {"year_window": None, "km_pct": None, "with_fuel": False, "with_transmission": False},
        ]

        for attempt in attempts:
            listings = self._query_listings(
                brand=brand,
                model=model,
                year=year_val,
                km=km_val,
                fuel=fuel,
                transmission=transmission,
                exclude_id=exclude_id,
                limit=limit,
                **attempt,
            )
            if len(listings) >= 5:
                return self._build_reference(listings, attempt, brand=brand, model=model, year=year_val)

        return self._last_resort("not_enough_reference", fallback_price)

    def _query_listings(
        self,
        brand: str,
        model: str,
        year: int,
        km: int,
        fuel: Optional[str],
        transmission: Optional[str],
        exclude_id: Optional[int],
        limit: int,
        year_window: Optional[int],
        km_pct: Optional[float],
        with_fuel: bool,
        with_transmission: bool,
    ) -> List[Dict[str, Any]]:
        conditions = [
            "LOWER(TRIM(brand)) = LOWER(TRIM(%s))",
            "LOWER(TRIM(model)) = LOWER(TRIM(%s))",
            "price IS NOT NULL",
            "price > 0",
        ]
        params: List[Any] = [brand, model]

        if year and year_window is not None:
            conditions.append("year BETWEEN %s AND %s")
            params.extend([year - year_window, year + year_window])

        if km and km_pct is not None:
            lower_km = max(0, int(km * (1 - km_pct)))
            upper_km = int(km * (1 + km_pct))
            conditions.append("(km IS NULL OR km = 0 OR km BETWEEN %s AND %s)")
            params.extend([lower_km, upper_km])

        if with_fuel and fuel:
            conditions.append("LOWER(COALESCE(fuel, fuel_type, '')) = LOWER(%s)")
            params.append(fuel.strip())

        if with_transmission and transmission:
            conditions.append("LOWER(COALESCE(transmission, '')) = LOWER(%s)")
            params.append(transmission.strip())

        if exclude_id:
            conditions.append("id <> %s")
            params.append(exclude_id)

        params.append(limit)
        # to_jsonb: opsiyonel kolonlar (paint_info, damage_info, heavy_damage ...) yoksa sorgu bozulmaz
        sql = f"""
            SELECT to_jsonb(listings) AS row
            FROM listings
            WHERE {' AND '.join(conditions)}
            ORDER BY updated_at DESC NULLS LAST
            LIMIT %s
        """

        conn = None
        try:
            conn = DatabaseConfig.get_connection()
            cursor = conn.cursor()
            cursor.execute(sql, tuple(params))
            rows = []
            for row in cursor.fetchall():
                data = _row_to_dict(row)
                rows.append(data.get("row") if isinstance(data.get("row"), dict) else data)
            return rows
        except Exception as exc:
            logger.warning("[MARKET REF] lookup failed: %s", exc)
            return []
        finally:
            if conn is not None:
                DatabaseConfig.return_connection(conn)

    def _build_reference(self, listings: List[Dict[str, Any]], scope: Dict[str, Any], brand: str, model: str, year: int) -> Dict[str, Any]:
        from yerimebak_ai_v5.core.ai.inspection_valuation import classify_listing_condition

        # Güncellik: yeterli sayıda son 90 günlük ilan varsa yalnızca onlar kullanılır.
        recent = [item for item in listings if _is_recent(item.get("updated_at"))]
        stale = False
        if len(recent) >= 5:
            listings = recent
        else:
            dated = [item for item in listings if item.get("updated_at")]
            stale = bool(dated) and len(recent) < len(dated) / 2
        # Ağır hasarlı / pert ilanlar emsal değildir.
        for item in listings:
            item["_condition"] = classify_listing_condition(
                item.get("paint_info"), item.get("damage_info"), item.get("heavy_damage"),
                item.get("accident_record") if str(item.get("accident_record") or "").lower() not in ("yok", "none", "") else "",
                item.get("title"),
            )
        usable = [item for item in listings if item["_condition"] != "heavy"]
        if len(usable) >= 5:
            listings = usable
        prices = sorted(_safe_int(item.get("price")) for item in listings if _safe_int(item.get("price")) > 0)
        if not prices:
            return self._empty("no_prices")

        median_price = int(statistics.median(prices))
        q1, q3 = self._quartiles(prices)
        iqr = q3 - q1
        if iqr > 0:
            low = q1 - (1.5 * iqr)
            high = q3 + (1.5 * iqr)
            filtered = [price for price in prices if low <= price <= high]
        else:
            filtered = prices

        if len(filtered) < 3:
            filtered = prices

        avg_price = int(sum(filtered) / len(filtered))
        low_ok, high_ok = min(filtered), max(filtered)
        in_band = [item for item in listings if low_ok <= _safe_int(item.get("price")) <= high_ok]

        # Hasarsız (boyasız / değişensiz) emsallerin medyanı — ekspertiz değerlemesinin baz fiyatı
        clean_prices = sorted(_safe_int(i.get("price")) for i in in_band if i.get("_condition") == "clean")
        not_damaged = sorted(_safe_int(i.get("price")) for i in in_band if i.get("_condition") != "damaged")
        clean_median = int(statistics.median(clean_prices)) if clean_prices else 0
        median_price = int(statistics.median(not_damaged)) if len(not_damaged) >= 3 else int(statistics.median(filtered))
        kms = [_safe_int(i.get("km")) for i in in_band if _safe_int(i.get("km")) > 0]
        years = [_safe_int(i.get("year")) for i in in_band if _safe_int(i.get("year")) > 0]

        confidence = min(95, 45 + len(filtered) * 5)
        if scope.get("year_window") is not None:
            confidence += max(0, 10 - int(scope["year_window"]) * 2)
        if scope.get("km_pct") is not None:
            confidence += 5
        confidence = max(40, min(98, confidence))

        sample_status = "healthy" if len(filtered) >= BUCKET_TARGET_COUNT else "acceptable"
        segment = find_segment_for_vehicle(brand, model)
        year_bucket = get_year_bucket(year, segment) if year else "unknown"
        if sample_status == "acceptable":
            confidence = min(confidence, 85)
        if stale:
            confidence = min(confidence, 60)

        samples = [
            {
                "id": item.get("id"),
                "price": _safe_int(item.get("price")),
                "km": item.get("km"),
                "year": item.get("year"),
                "source": item.get("source"),
                "title": item.get("title"),
                "url": item.get("url"),
                "condition": item.get("_condition"),
                "updated_at": str(item.get("updated_at") or "") or None,
            }
            for item in listings[:10]
        ]

        return {
            "found": True,
            "source": "listings",
            "count": len(filtered),
            "raw_count": len(prices),
            "market_avg_price": avg_price,
            "market_median_price": median_price,
            "market_min_price": int(min(filtered)),
            "market_max_price": int(max(filtered)),
            "clean_median_price": clean_median,
            "clean_count": len(clean_prices),
            "reference_median_km": int(statistics.median(kms)) if kms else 0,
            "reference_median_year": int(statistics.median(years)) if years else 0,
            "recent_count": len(recent),
            "stale": stale,
            "recent_days": RECENT_DAYS,
            "confidence": confidence,
            "quality": {
                "normalized_brand": brand,
                "normalized_model": model,
                "year_bucket": year_bucket,
                "sample_size_status": sample_status,
                "target_count": BUCKET_TARGET_COUNT,
                "sample_count": len(filtered),
            },
            "scope": scope,
            "samples": samples,
        }

    def _quartiles(self, prices: List[int]) -> tuple[float, float]:
        if len(prices) < 4:
            return float(min(prices)), float(max(prices))
        midpoint = len(prices) // 2
        lower = prices[:midpoint]
        upper = prices[-midpoint:]
        return float(statistics.median(lower)), float(statistics.median(upper))

    def _empty(self, reason: str) -> Dict[str, Any]:
        return {
            "found": False,
            "source": "listings",
            "reason": reason,
            "count": 0,
            "raw_count": 0,
            "market_avg_price": 0,
            "market_median_price": 0,
            "market_min_price": 0,
            "market_max_price": 0,
            "confidence": 0,
            "scope": {},
            "samples": [],
        }

    def _last_resort(self, reason: str, listed_price: int) -> Dict[str, Any]:
        if listed_price <= 0:
            return self._empty(reason)

        estimated_price = int(listed_price * 0.97)
        return {
            "found": True,
            "source": "last_resort_listed_price",
            "reason": reason,
            "count": 0,
            "raw_count": 0,
            "market_avg_price": estimated_price,
            "market_median_price": estimated_price,
            "market_min_price": estimated_price,
            "market_max_price": estimated_price,
            "confidence": 20,
            "scope": {
                "fallback": "listed_price_minus_3_percent",
                "listed_price": listed_price,
            },
            "samples": [],
        }


def _is_recent(value: Any, days: int = RECENT_DAYS) -> bool:
    if not value:
        return False
    try:
        if isinstance(value, datetime):
            ts = value
        else:
            ts = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if ts.tzinfo is None:
            ts = ts.replace(tzinfo=timezone.utc)
        return ts >= datetime.now(timezone.utc) - timedelta(days=days)
    except Exception:
        return False


_market_reference_service = None


def get_market_reference_service() -> MarketReferenceService:
    global _market_reference_service
    if _market_reference_service is None:
        _market_reference_service = MarketReferenceService()
    return _market_reference_service
