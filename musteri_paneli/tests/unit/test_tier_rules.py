from datetime import datetime, timezone
from unittest.mock import MagicMock

import pytest

from yerimebak_ai_v5.services.payment_service import PaymentService


@pytest.mark.parametrize('tier,credits,count,reason', [
    ('free', 3, 5, 'daily_limit'),
    ('free', 0, 0, 'insufficient_credits'),
    ('free', 3, 4, None),
    ('enterprise', 3, 10000, None),
])
def test_analysis_policy(tier, credits, count, reason):
    result = PaymentService()._analysis_policy({'tier': tier, 'credits': credits}, count, 1)
    assert result['ok'] is (reason is None)
    assert result['reason'] == reason


def test_istanbul_day_crosses_utc_date():
    start, end = PaymentService()._day_bounds(datetime(2026, 11, 1, 21, 30, tzinfo=timezone.utc))
    assert start == datetime(2026, 11, 1, 21)
    assert end == datetime(2026, 11, 2, 21)


def test_seviyelerde_aylik_kredi_yok():
    from yerimebak_ai_v5.services.payment_service import TIER_LIMITS
    assert all(set(v) == {"max_analyses_per_day"} for v in TIER_LIMITS.values())
    assert not hasattr(PaymentService, "_grant_monthly")
