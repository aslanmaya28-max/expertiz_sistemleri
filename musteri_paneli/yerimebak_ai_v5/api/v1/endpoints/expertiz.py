# -*- coding: utf-8 -*-
"""
Kurumsal ekspertiz talep API'si.
"""
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from yerimebak_ai_v5.api.v1.endpoints.auth import get_admin_user, get_authenticated_user
from yerimebak_ai_v5.services.expertiz_service import (
    create_expertiz_request,
    get_admin_report,
    get_customer_report,
    get_expertiz_packages,
    list_admin_reports,
    list_customer_reports,
    list_customer_requests,
    publish_admin_report,
    reject_admin_report,
)

router = APIRouter()


class CreateExpertizRequest(BaseModel):
    firm_id: str
    package_id: str
    listing_id: Optional[int] = None
    listing_url: Optional[str] = None
    plate: Optional[str] = None
    city: Optional[str] = None
    note: Optional[str] = None


class RejectReportRequest(BaseModel):
    reason: str


@router.get("/packages")
async def packages() -> Dict[str, Any]:
    return get_expertiz_packages()


@router.post("/requests")
async def request_expertiz(
    request: CreateExpertizRequest,
    user: Dict[str, Any] = Depends(get_authenticated_user),
) -> Dict[str, Any]:
    result = create_expertiz_request(request.model_dump(), user)
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.get("/requests")
async def my_expertiz_requests(
    user: Dict[str, Any] = Depends(get_authenticated_user),
) -> Dict[str, Any]:
    return list_customer_requests(user)


@router.get("/reports")
async def my_published_reports(
    user: Dict[str, Any] = Depends(get_authenticated_user),
) -> Dict[str, Any]:
    return list_customer_reports(user)


@router.get("/admin/reports")
async def admin_reports(
    status: Optional[str] = None,
    limit: int = 100,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return list_admin_reports(status=status, limit=limit)


@router.get("/admin/reports/{report_id}")
async def admin_report_detail(
    report_id: str,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    result = get_admin_report(report_id)
    if "error" in result:
        raise HTTPException(status_code=404, detail=result["error"])
    return result


@router.post("/admin/reports/{report_id}/publish")
async def admin_publish_report(
    report_id: str,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    result = publish_admin_report(report_id, admin)
    if "error" in result:
        raise HTTPException(status_code=result.get("http_status", 400), detail=result["error"])
    return result


@router.post("/admin/reports/{report_id}/reject")
async def admin_reject_report(
    report_id: str,
    request: RejectReportRequest,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    result = reject_admin_report(report_id, request.reason, admin)
    if "error" in result:
        raise HTTPException(status_code=result.get("http_status", 400), detail=result["error"])
    return result


@router.get("/reports/{report_id}")
async def my_published_report_detail(
    report_id: str,
    user: Dict[str, Any] = Depends(get_authenticated_user),
) -> Dict[str, Any]:
    result = get_customer_report(report_id, user)
    if "error" in result:
        raise HTTPException(status_code=404, detail=result["error"])
    return result
