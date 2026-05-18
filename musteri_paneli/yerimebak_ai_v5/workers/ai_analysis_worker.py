# -*- coding: utf-8 -*-
"""
AI Analysis Worker
Polls for pending_ai reports and runs the AI analysis pipeline.
Can be run as a standalone process or integrated into the worker_manager.
"""
import asyncio
import logging
import traceback
from datetime import datetime
from typing import Dict, Any, Optional

from yerimebak_ai_v5.core.supabase_bridge import get_supabase_bridge
from yerimebak_ai_v5.core.ai_result_adapter import engine_v8_to_ai_analiz
from yerimebak_ai_v5.core.market_reference_service import get_market_reference_service

logger = logging.getLogger(__name__)

POLL_INTERVAL_SECONDS = 10


class AIAnalysisWorker:
    """
    Worker that polls for pending_ai reports and processes them through
    the AI analysis pipeline.
    """

    def __init__(self):
        self.bridge = get_supabase_bridge()
        self._running = False

    async def process_single_report(self, report_id: str) -> bool:
        """
        Process a single report through the AI analysis pipeline.

        Steps:
        1. Read report data from Supabase
        2. Extract vehicle info from data JSONB
        3. Run Engine V8 analysis
        4. Convert result to AIAnalizSonucu format
        5. Write results back to Supabase
        6. Write audit log
        """
        logger.info(f"[AI WORKER] Processing report: {report_id}")

        try:
            vehicle_info = self.bridge.extract_vehicle_info(report_id)
            if not vehicle_info:
                logger.error(f"[AI WORKER] Could not extract vehicle info for {report_id}")
                return False

            brand = vehicle_info.get("brand", "")
            model = vehicle_info.get("model", "")
            year = int(vehicle_info.get("yil") or vehicle_info.get("year") or 2020)
            km = int(vehicle_info.get("km") or 0)
            price = float(vehicle_info.get("price") or 0)

            if not brand or not model:
                logger.error(f"[AI WORKER] Missing brand/model for {report_id}")
                return False

            from yerimebak_ai_v5.core.engine_v8 import (
                YerimebakEngineV8, VehicleData,
            )

            damage_level = "NONE"
            boyali = vehicle_info.get("boyali_parcalar", [])
            degisen = vehicle_info.get("degisen_parcalar", [])
            hasar_kayitlari = vehicle_info.get("hasar_kayitlari", [])

            if hasar_kayitlari and len(hasar_kayitlari) > 0:
                damage_level = "MEDIUM"
            elif degisen and len(degisen) > 3:
                damage_level = "MEDIUM"
            elif boyali and len(boyali) > 3:
                damage_level = "LIGHT"
            elif boyali or degisen:
                damage_level = "LIGHT"

            bodywork_status = []
            if isinstance(boyali, list):
                bodywork_status.extend([f"boyali_{p}" for p in boyali])
            if isinstance(degisen, list):
                bodywork_status.extend([f"degisen_{p}" for p in degisen])

            market_reference = get_market_reference_service().get_reference(
                brand=brand,
                model=model,
                year=year,
                km=km,
                fuel=vehicle_info.get("yakit"),
                transmission=vehicle_info.get("sanziman"),
                listed_price=price,
            )
            market_avg = market_reference.get("market_avg_price") or price or 1.0

            vehicle = VehicleData(
                make_model=f"{brand} {model}",
                year=year,
                mileage_km=km,
                fuel_type=vehicle_info.get("yakit", "Bilinmiyor") or "Bilinmiyor",
                gear_type=vehicle_info.get("sanziman", "Bilinmiyor") or "Bilinmiyor",
                listed_price=price if price > 0 else 1.0,
                market_price_avg=float(market_avg),
                damage_level=damage_level,
                bodywork_status=bodywork_status,
                demand_level="MEDIUM",
                seasonality="NORMAL",
                package_level=vehicle_info.get("paket", "BASE") or "BASE",
            )

            engine = YerimebakEngineV8(verbose=False)
            valuation = engine.analyze(vehicle)

            ai_analiz_sonucu = engine_v8_to_ai_analiz(
                valuation=valuation,
                vehicle_data={
                    "listed_price": price,
                    "brand": brand,
                    "model": model,
                    "year": year,
                    "km": km,
                },
                report_id=report_id,
            )

            success = self.bridge.write_ai_results(
                report_id,
                ai_analiz_sonucu,
                market_reference=market_reference,
                source="central_ai",
            )
            if not success:
                logger.error(f"[AI WORKER] Failed to write results for {report_id}")
                return False

            self.bridge.write_audit_log(
                action="ai_analysis_completed",
                entity_type="report",
                entity_id=report_id,
                metadata={
                    "decision": valuation.dealer_verdict.decision,
                    "opportunity_score": valuation.technical_scoring.opportunity_score,
                    "risk_pct": valuation.technical_scoring.risk_percentage,
                    "net_profit_tl": valuation.commercial_analysis.net_profit_tl,
                    "market_reference_found": market_reference.get("found", False),
                    "market_reference_count": market_reference.get("count", 0),
                    "market_reference_avg": market_reference.get("market_avg_price", 0),
                },
                user_id=vehicle_info.get("user_id"),
            )

            logger.info(
                f"[AI WORKER] Completed report {report_id}: "
                f"decision={valuation.dealer_verdict.decision}, "
                f"score={valuation.technical_scoring.opportunity_score}"
            )
            return True

        except Exception as e:
            logger.error(f"[AI WORKER] Failed processing {report_id}: {e}")
            traceback.print_exc()

            try:
                self.bridge.write_audit_log(
                    action="ai_analysis_failed",
                    entity_type="report",
                    entity_id=report_id,
                    metadata={"error": str(e)},
                )
            except Exception:
                pass

            return False

    async def run_once(self) -> int:
        """Process all pending_ai reports. Returns count of processed reports."""
        pending = self.bridge.get_pending_ai_reports()
        if not pending:
            return 0

        logger.info(f"[AI WORKER] Found {len(pending)} pending reports")
        processed = 0

        for report in pending:
            report_id = str(report.get("id", ""))
            if not report_id:
                continue

            success = await self.process_single_report(report_id)
            if success:
                processed += 1

        return processed

    async def run_loop(self, interval: int = POLL_INTERVAL_SECONDS):
        """Run the worker in a continuous polling loop."""
        self._running = True
        logger.info(f"[AI WORKER] Starting polling loop (interval={interval}s)")

        while self._running:
            try:
                count = await self.run_once()
                if count > 0:
                    logger.info(f"[AI WORKER] Processed {count} reports")
            except Exception as e:
                logger.error(f"[AI WORKER] Loop error: {e}")

            await asyncio.sleep(interval)

    def stop(self):
        self._running = False
        logger.info("[AI WORKER] Stopping...")


_worker = None


def get_ai_analysis_worker() -> AIAnalysisWorker:
    global _worker
    if _worker is None:
        _worker = AIAnalysisWorker()
    return _worker

