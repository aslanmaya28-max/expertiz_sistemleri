# -*- coding: utf-8 -*-
"""
Analysis Intake API Endpoint - URL tabanli analiz girislerini kuyruga alir.
Kaynak: manual_paste (web), mobile_share (Flutter), chrome_extension.
"""
import asyncio
from fastapi import APIRouter, HTTPException, Depends

from typing import Dict, Any
from pydantic import BaseModel, field_validator

from yerimebak_ai_v5.services.analysis_intake_service import get_analysis_intake_service
from yerimebak_ai_v5.services.payment_service import get_payment_service
from yerimebak_ai_v5.api.v1.endpoints.auth import get_current_user

router = APIRouter()


class UrlAnalysisRequest(BaseModel):
    url: str
    source: str = "manual_paste"

    @field_validator("url")
    @classmethod
    def validate_url(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("URL bos olamaz")
        return v

    @field_validator("source")
    @classmethod
    def validate_source(cls, v: str) -> str:
        allowed = {"mobile_share", "manual_paste", "chrome_extension"}
        if v not in allowed:
            raise ValueError(f"Gecersiz kaynak. Izin verilenler: {', '.join(sorted(allowed))}")
        return v


# ──────────────────────────────────────────────
# Sync helpers for run_in_executor
# ──────────────────────────────────────────────

def _sync_create_url_analysis(user_id: int, url: str, source: str) -> Dict[str, Any]:
    intake = get_analysis_intake_service().build_url_intake(url, source)
    payment = get_payment_service()
    queued = payment.record_queued_analysis(user_id, intake)
    return {
        "success": True,
        "status": intake["status"],
        "history_id": queued["history_id"],
    }


# ──────────────────────────────────────────────
# Endpoints
# ──────────────────────────────────────────────

@router.post("/url")
async def create_url_analysis(
    request: UrlAnalysisRequest,
    user: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    """Bir URL'yi analiz kuyruguna alir. Kredi dusmez, sadece kuyruk kaydi olusturur."""
    loop = asyncio.get_event_loop()
    try:
        result = await loop.run_in_executor(
            None, _sync_create_url_analysis, user["id"], request.url, request.source
        )
        return result
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
