from typing import Any, Dict

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from pydantic import BaseModel

from yerimebak_ai_v5.api.v1.endpoints.auth import get_current_user
from yerimebak_ai_v5.services.analysis_intake_service import AnalysisIntakeService
from yerimebak_ai_v5.services.payment_service import PaymentService, get_payment_service
from yerimebak_ai_v5.services.url_analysis_job_service import UrlAnalysisJobService

router = APIRouter()


class UrlAnalysisRequest(BaseModel):
    url: str
    source: str = "manual_paste"


def get_analysis_intake_service() -> AnalysisIntakeService:
    return AnalysisIntakeService()


def get_url_analysis_job_service() -> UrlAnalysisJobService:
    return UrlAnalysisJobService()


@router.post("/url")
async def create_url_analysis_intake(
    request: UrlAnalysisRequest,
    background_tasks: BackgroundTasks = None,
    user: Dict[str, Any] = Depends(get_current_user),
    intake_service: AnalysisIntakeService = Depends(get_analysis_intake_service),
    payment_service: PaymentService = Depends(get_payment_service),
    job_service: UrlAnalysisJobService = Depends(get_url_analysis_job_service),
) -> Dict[str, Any]:
    try:
        intake_payload = intake_service.build_url_intake(request.url, request.source)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc

    history_result = payment_service.record_queued_analysis(user["id"], intake_payload)
    if background_tasks is not None:
        background_tasks.add_task(
            job_service.process,
            history_result["history_id"],
            user["id"],
            intake_payload["url"],
        )
    return {
        "success": history_result["success"],
        "status": intake_payload["status"],
        "history_id": history_result["history_id"],
    }
