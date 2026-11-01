"""
Analysis API Endpoint v1.0
Admin report AI trigger, status and health
"""
from fastapi import APIRouter, HTTPException, Depends
from typing import Dict, Any
from pydantic import BaseModel

from yerimebak_ai_v5.api.v1.endpoints.auth import get_admin_user

router = APIRouter()

@router.get("/health")
async def get_analysis_health() -> Dict[str, Any]:
    return {
        "status": "healthy",
        "engine_version": "v8.0",
        "services": {
            "engine_v8": "operational",
            "risk_engine": "operational",
            "condition_analyzer": "operational",
            "ai_valuation": "operational",
            "payment_service": "operational",
            "auth_service": "operational"
        }
    }


class TriggerAnalysisRequest(BaseModel):
    report_id: str


@router.post("/trigger")
async def trigger_ai_analysis(
    request: TriggerAnalysisRequest,
    user: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    """
    Trigger (or re-run) the central AI analysis for a submitted report. Admin only.

    Yalnizca personelin gonderdigi raporlar (pending_ai / pending_admin) analiz
    edilir; taslak rapor AI'ya gonderilemez (personel gonderimini atlamamak icin).
    """
    from yerimebak_ai_v5.core.supabase_bridge import get_supabase_bridge
    from yerimebak_ai_v5.workers.ai_analysis_worker import get_ai_analysis_worker

    bridge = get_supabase_bridge()

    report = bridge.read_report_data(request.report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Rapor bulunamadi")

    if report.get("status") not in ("pending_ai", "pending_admin"):
        raise HTTPException(
            status_code=400,
            detail=f"Rapor durumu uygun degil: {report.get('status')}. Gerekli: pending_ai veya pending_admin"
        )

    worker = get_ai_analysis_worker()
    success = await worker.process_single_report(request.report_id)

    if not success:
        raise HTTPException(status_code=500, detail="AI analiz basarisiz")

    updated = bridge.read_report_data(request.report_id)
    return {
        "success": True,
        "report_id": request.report_id,
        "status": updated.get("status") if updated else "pending_admin",
        "ai_analizi_yapildi_mi": updated.get("ai_analizi_yapildi_mi") if updated else True,
    }


@router.get("/status/{report_id}")
async def get_analysis_status(
    report_id: str,
    user: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    """Get the AI analysis status for a specific report."""
    from yerimebak_ai_v5.core.supabase_bridge import get_supabase_bridge

    bridge = get_supabase_bridge()
    report = bridge.read_report_data(report_id)

    if not report:
        raise HTTPException(status_code=404, detail="Rapor bulunamadi")

    return {
        "success": True,
        "report_id": report_id,
        "status": report.get("status"),
        "ai_analizi_yapildi_mi": report.get("ai_analizi_yapildi_mi", False),
        "ai_analiz_detay": report.get("ai_analiz_detay"),
    }
