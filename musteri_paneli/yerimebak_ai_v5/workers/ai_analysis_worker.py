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
from yerimebak_ai_v5.core.market_reference_service import get_market_reference_service

logger = logging.getLogger(__name__)

POLL_INTERVAL_SECONDS = 30
# Gonderim aninda arka plan gorevi raporu zaten isler; polling dongusu yalnizca
# bu sureden uzun suredir pending_ai'da bekleyen (takilmis) raporlari toplar.
STUCK_REPORT_AGE_SECONDS = 60

# Birden fazla calisan islem (uvicorn --workers) varken kurtarma taramasini
# ayni anda yalnizca biri yapsin: PostgreSQL danisma kilidi.
SWEEP_LOCK_KEY = 72_410_051


def _try_sweep_lock():
    """Kilidi alirsa baglantiyi dondurur (birakmak icin), alamazsa None."""
    from yerimebak_ai_v5.core.database_config import DatabaseConfig

    conn = DatabaseConfig.get_connection()
    try:
        conn.autocommit = True
        cur = conn.cursor()
        cur.execute("SELECT pg_try_advisory_lock(%s)", (SWEEP_LOCK_KEY,))
        if cur.fetchone()[0]:
            return conn
    except Exception as e:
        logger.warning(f"[AI WORKER] Sweep lock check failed: {e}")
    DatabaseConfig.return_connection(conn)
    return None


def _release_sweep_lock(conn) -> None:
    from yerimebak_ai_v5.core.database_config import DatabaseConfig

    try:
        conn.cursor().execute("SELECT pg_advisory_unlock(%s)", (SWEEP_LOCK_KEY,))
    except Exception:
        pass
    DatabaseConfig.return_connection(conn)


def _to_int(value: Any) -> int:
    try:
        if value in (None, ""):
            return 0
        if isinstance(value, (int, float)):
            return int(value)
        return int(float(str(value).replace(".", "").replace(",", ".")))
    except (TypeError, ValueError):
        return 0


def _to_float(value: Any) -> float:
    try:
        if value in (None, ""):
            return 0.0
        if isinstance(value, (int, float)):
            return float(value)
        return float(str(value).replace(".", "").replace(",", "."))
    except (TypeError, ValueError):
        return 0.0


def _compact_reference(ref: Dict[str, Any]) -> Dict[str, Any]:
    """Rapor icinde saklanan piyasa referansi (emsal ornekleri en fazla 10)."""
    ref = dict(ref or {})
    ref["samples"] = list(ref.get("samples") or [])[:10]
    return ref


def _liquidity(vehicle_info: Dict[str, Any], degerleme: Dict[str, Any], km: int) -> Dict[str, Any]:
    """Satilabilirlik (likidite) skoru — Engine V8 likidite modeli, gercek hasar seviyesiyle."""
    try:
        from types import SimpleNamespace
        from yerimebak_ai_v5.core.engine_v8 import YerimebakEngineV8, VehicleData

        value = float(degerleme.get("aiDegeri") or 0) or 1.0
        vehicle = VehicleData(
            make_model=f"{vehicle_info.get('brand', '')} {vehicle_info.get('model', '')}",
            year=_to_int(vehicle_info.get("yil") or vehicle_info.get("year")) or 2020,
            mileage_km=km,
            fuel_type=vehicle_info.get("yakit") or "Bilinmiyor",
            gear_type=vehicle_info.get("sanziman") or "Bilinmiyor",
            listed_price=value,
            market_price_avg=value,
            damage_level=degerleme.get("hasarSeviyesi") or "NONE",
            bodywork_status=[],
            demand_level="MEDIUM",
            seasonality="NORMAL",
            package_level=vehicle_info.get("paket") or "BASE",
        )
        metrics = YerimebakEngineV8(verbose=False)._calculate_liquidity(
            vehicle, SimpleNamespace(price_position_index=0.0)
        )
        return {
            "liquidity_score": int(metrics.liquidity_score),
            "estimated_days_to_sell": int(metrics.estimated_days_to_sell),
        }
    except Exception as exc:  # pragma: no cover - likidite opsiyoneldir
        logger.warning("[AI WORKER] liquidity calc failed: %s", exc)
        return {}


class AIAnalysisWorker:
    """
    Worker that polls for pending_ai reports and processes them through
    the AI analysis pipeline.
    """

    def __init__(self):
        self.bridge = get_supabase_bridge()
        self._running = False

    async def process_single_report(self, report_id: str) -> bool:
        """Async giris: veritabani/hesaplama isi event loop'u bloklamamak icin thread'de calisir."""
        return await asyncio.to_thread(self.process_single_report_sync, report_id)

    def process_single_report_sync(self, report_id: str) -> bool:
        """
        Process a single report through the AI analysis pipeline.

        Steps:
        1. Read report data (vehicle snapshot + personnel's tam_rapor)
        2. Market reference from real listings (recent, clean comparables)
        3. Inspection-based valuation: market value minus per-finding value loss
        4. Convert to AIAnalizSonucu (+ ekspertizDegerleme breakdown)
        5. Write results back (status -> pending_admin) and audit log
        """
        logger.info(f"[AI WORKER] Processing report: {report_id}")

        try:
            vehicle_info = self.bridge.extract_vehicle_info(report_id)
            if not vehicle_info:
                logger.error(f"[AI WORKER] Could not extract vehicle info for {report_id}")
                return False
            if vehicle_info.get("status") not in (None, "pending_ai", "pending_admin"):
                logger.info(f"[AI WORKER] Skip {report_id}: status={vehicle_info.get('status')}")
                return False

            brand = (vehicle_info.get("brand") or "").strip()
            model = (vehicle_info.get("model") or "").strip()
            year = _to_int(vehicle_info.get("yil") or vehicle_info.get("year"))
            km = _to_int(vehicle_info.get("km"))
            price = _to_float(vehicle_info.get("price"))

            from yerimebak_ai_v5.core.ai.inspection_valuation import evaluate
            from yerimebak_ai_v5.core.ai.ai_result_adapter import inspection_to_ai_analiz

            # Guncel emsaller: Apify acikken bu arac icin arabam.com / Borusan Next'ten
            # o anki ilanlar cekilir (APIFY_REFRESH_HOURS icinde tekrar cekilmez).
            from yerimebak_ai_v5.services import market_ingest

            # Musterinin paylastigi ilan sistemde yoksa once o ilan cekilir:
            # satici beyani (boya/degisen/hasar) ve ilan fiyati karsilastirma icin gerekir.
            listing_id = _to_int(vehicle_info.get("listing_id")) or None
            ilan_cekimi: Dict[str, Any] = {}
            if not listing_id and vehicle_info.get("listing_url"):
                existing = market_ingest.declared_condition(None, vehicle_info.get("listing_url"))
                if existing:
                    listing_id = existing["listing_id"]
                else:
                    try:
                        fetched = market_ingest.fetch_listing(vehicle_info["listing_url"])
                        if fetched:
                            listing_id = fetched["id"]
                            price = price or float(fetched.get("price") or 0)
                            km = km or _to_int(fetched.get("km"))
                            year = year or _to_int(fetched.get("year"))
                            brand = brand or (fetched.get("brand") or "")
                            model = model or (fetched.get("model") or "")
                            ilan_cekimi = {"durum": "cekildi", "listing_id": listing_id}
                        else:
                            ilan_cekimi = {"durum": "bulunamadi" if market_ingest.apify_service.enabled() else "kapali"}
                    except Exception as exc:
                        logger.warning(f"[AI WORKER] Ilan cekilemedi ({report_id}): {exc}")
                        ilan_cekimi = {"durum": "hata", "hata": str(exc)[:300]}

            if not brand or not model:
                logger.error(f"[AI WORKER] Missing brand/model for {report_id}")
                return False

            emsal_cekimi = market_ingest.refresh_comparables(brand, model, year or None)
            if ilan_cekimi:
                emsal_cekimi["ilan"] = ilan_cekimi

            market_reference = get_market_reference_service().get_reference(
                brand=brand,
                model=model,
                year=year or None,
                km=km or None,
                fuel=vehicle_info.get("yakit"),
                transmission=vehicle_info.get("sanziman"),
                exclude_id=listing_id,
                listed_price=price,
            )

            degerleme = evaluate(
                vehicle_info.get("tam_rapor") or {},
                market_reference,
                listed_price=price,
                vehicle={"km": km, "yil": year},
            )
            liquidity = _liquidity(vehicle_info, degerleme, km)
            # Ilanda satıcının beyan ettiği durum ↔ personel ekspertiz bulguları
            adim1 = (vehicle_info.get("tam_rapor") or {}).get("adim1") or {}
            degerleme["ilanBeyaniKarsilastirma"] = market_ingest.compare_declaration(
                market_ingest.declared_condition(listing_id, vehicle_info.get("listing_url")),
                degerleme,
                ekspertiz_tramer_tl=_to_float(adim1.get("hasarKayitToplamTutar")) if isinstance(adim1, dict) else None,
            )
            market_reference["emsalCekimi"] = emsal_cekimi

            ai_analiz_sonucu = inspection_to_ai_analiz(
                degerleme,
                report_id=report_id,
                liquidity=liquidity,
                vehicle={"brand": brand, "model": model, "year": year, "km": km},
            )

            success = self.bridge.write_ai_results(
                report_id,
                ai_analiz_sonucu,
                market_reference=_compact_reference(market_reference),
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
                    "model_version": degerleme.get("modelVersiyonu"),
                    "ai_value": degerleme.get("aiDegeri"),
                    "clean_market_value": degerleme.get("temizPiyasaDegeri"),
                    "total_loss_pct": degerleme.get("toplamDegerKaybiYuzde"),
                    "damage_level": degerleme.get("hasarSeviyesi"),
                    "genel_puan": (degerleme.get("skorlar") or {}).get("genelPuan"),
                    "market_reference_found": market_reference.get("found", False),
                    "market_reference_source": market_reference.get("source"),
                    "market_reference_count": market_reference.get("count", 0),
                },
                user_id=vehicle_info.get("user_id"),
            )

            logger.info(
                f"[AI WORKER] Completed report {report_id}: value={degerleme.get('aiDegeri')} "
                f"loss=%{degerleme.get('toplamDegerKaybiYuzde')} level={degerleme.get('hasarSeviyesi')}"
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

    async def run_once(self, min_age_seconds: int = 0) -> int:
        """Process all pending_ai reports. Returns count of processed reports."""
        pending = await asyncio.to_thread(self.bridge.get_pending_ai_reports, 50, min_age_seconds)
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
            lock_conn = None
            try:
                lock_conn = await asyncio.to_thread(_try_sweep_lock)
                if lock_conn is not None:
                    count = await self.run_once(min_age_seconds=STUCK_REPORT_AGE_SECONDS)
                    if count > 0:
                        logger.info(f"[AI WORKER] Processed {count} reports")
            except Exception as e:
                logger.error(f"[AI WORKER] Loop error: {e}")
            finally:
                if lock_conn is not None:
                    await asyncio.to_thread(_release_sweep_lock, lock_conn)

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

