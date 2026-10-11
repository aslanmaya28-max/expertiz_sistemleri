# -*- coding: utf-8 -*-
"""
Kurumsal ekspertiz talep API'si.
"""
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from yerimebak_ai_v5.api.v1.endpoints.auth import get_admin_user, get_authenticated_user
from yerimebak_ai_v5.services import dispatch_service
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


class AssignRequest(BaseModel):
    personnel_id: str
    note: Optional[str] = None


class UnassignRequest(BaseModel):
    reason: Optional[str] = None


def _raise_if_error(result: Dict[str, Any]) -> Dict[str, Any]:
    if "error" in result:
        raise HTTPException(status_code=int(result.get("http_status") or 400), detail=result["error"])
    return result


def get_personnel_user(user: Dict[str, Any] = Depends(get_authenticated_user)) -> Dict[str, Any]:
    if not dispatch_service.is_personnel(user):
        raise HTTPException(status_code=403, detail="Bu islem sadece saha personeli icindir")
    return user


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


# ---------------------------------------------------------------------------
# Admin: talep kuyrugu ve personel atama
# ---------------------------------------------------------------------------

@router.get("/admin/requests")
async def admin_list_requests(
    bucket: Optional[str] = None,
    region_id: Optional[int] = None,
    il_id: Optional[int] = None,
    limit: int = 300,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.list_admin_requests(bucket=bucket, region_id=region_id, il_id=il_id, limit=limit))


@router.get("/admin/requests/{report_id}")
async def admin_request_detail(
    report_id: str,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.get_admin_request(report_id))


@router.get("/admin/requests/{report_id}/candidates")
async def admin_request_candidates(
    report_id: str,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.list_candidates(report_id))


@router.post("/admin/requests/{report_id}/assign")
async def admin_assign_request(
    report_id: str,
    request: AssignRequest,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.assign_request(report_id, request.personnel_id, admin, request.note))


@router.post("/admin/requests/{report_id}/unassign")
async def admin_unassign_request(
    report_id: str,
    request: Optional[UnassignRequest] = None,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.unassign_request(report_id, admin, request.reason if request else None))


# ---------------------------------------------------------------------------
# Personel: bana atanan gorevler
# ---------------------------------------------------------------------------

@router.get("/personnel/tasks")
async def personnel_tasks(user: Dict[str, Any] = Depends(get_personnel_user)) -> Dict[str, Any]:
    return dispatch_service.list_personnel_tasks(user)


@router.post("/personnel/tasks/{report_id}/accept")
async def personnel_accept_task(report_id: str, user: Dict[str, Any] = Depends(get_personnel_user)) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.update_task_progress(report_id, user, "accept"))


@router.post("/personnel/tasks/{report_id}/start")
async def personnel_start_task(report_id: str, user: Dict[str, Any] = Depends(get_personnel_user)) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.update_task_progress(report_id, user, "start"))
