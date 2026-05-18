# -*- coding: utf-8 -*-
"""
Market Coverage API Endpoint v1.0
"""
import asyncio
from typing import Any, Dict

from fastapi import APIRouter, Depends

from yerimebak_ai_v5.api.v1.endpoints.auth import get_admin_user
from yerimebak_ai_v5.core.market.market_coverage_service import MarketCoverageService


router = APIRouter()


# ──────────────────────────────────────────────
# 🔒 DÜZELTİLDİ: Sync DB işlemleri run_in_executor için ayrıldı
# ──────────────────────────────────────────────

def _sync_coverage_summary() -> Dict[str, Any]:
    service = MarketCoverageService()
    coverage = service.calculate_coverage()
    return {
        "success": True,
        "total_rows": len(coverage),
        "healthy": sum(1 for row in coverage if row["coverage_status"] == "healthy"),
        "underfilled": sum(1 for row in coverage if row["coverage_status"] == "underfilled"),
        "filled_imbalanced": sum(1 for row in coverage if row["coverage_status"] == "filled_imbalanced"),
        "stale": sum(1 for row in coverage if row["coverage_status"] == "stale"),
        "coverage": coverage,
    }


def _sync_backfill_targets() -> Dict[str, Any]:
    service = MarketCoverageService()
    coverage = service.calculate_coverage()
    targets = service.build_backfill_targets(coverage)
    return {"success": True, "total": len(targets), "targets": targets[:200]}


# ──────────────────────────────────────────────
# 🔒 DÜZELTİLDİ: Async endpoint'ler run_in_executor kullanır
# ──────────────────────────────────────────────

@router.get("/summary")
async def market_coverage_summary(admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_coverage_summary)


@router.get("/backfill-targets")
async def market_coverage_backfill_targets(admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_backfill_targets)
