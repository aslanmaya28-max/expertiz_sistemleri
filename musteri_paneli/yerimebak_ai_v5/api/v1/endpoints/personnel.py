from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from yerimebak_ai_v5.api.v1.endpoints.auth import get_admin_user
from yerimebak_ai_v5.services import personnel_service


router = APIRouter()


class PersonnelCreateRequest(BaseModel):
    full_name: str
    email: str
    temporary_password: str
    phone: Optional[str] = None
    city: str
    district: str
    expertise: Optional[str] = None


class PersonnelUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    city: Optional[str] = None
    district: Optional[str] = None
    expertise: Optional[str] = None


class DeactivateRequest(BaseModel):
    reason: str


class ResetPasswordRequest(BaseModel):
    temporary_password: str


class RemovePersonnelRequest(BaseModel):
    reason: Optional[str] = None


def _raise_if_error(result: Dict[str, Any]) -> Dict[str, Any]:
    if "error" in result:
        raise HTTPException(status_code=int(result.get("http_status") or 400), detail=result["error"])
    return result


@router.get("/admin/personnel")
async def admin_list_personnel(
    active: Optional[bool] = None,
    region_id: Optional[int] = None,
    il_id: Optional[int] = None,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return personnel_service.list_personnel(active=active, region_id=region_id, il_id=il_id)


@router.post("/admin/personnel")
async def admin_create_personnel(
    request: PersonnelCreateRequest,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    result = personnel_service.create_personnel(request.model_dump(), admin)
    return _raise_if_error(result)


@router.put("/admin/personnel/{personnel_id}")
async def admin_update_personnel(
    personnel_id: str,
    request: PersonnelUpdateRequest,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    result = personnel_service.update_personnel(personnel_id, request.model_dump(exclude_unset=True), admin)
    return _raise_if_error(result)


@router.post("/admin/personnel/{personnel_id}/deactivate")
async def admin_deactivate_personnel(
    personnel_id: str,
    request: DeactivateRequest,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    result = personnel_service.deactivate_personnel(personnel_id, request.reason, admin)
    return _raise_if_error(result)


@router.delete("/admin/personnel/{personnel_id}")
async def admin_remove_personnel(
    personnel_id: str,
    request: Optional[RemovePersonnelRequest] = None,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    """Personeli sistemden cikarir; acik gorevleri admin kuyruguna geri doner."""
    result = personnel_service.delete_personnel(personnel_id, admin, request.reason if request else None)
    return _raise_if_error(result)


@router.post("/admin/personnel/{personnel_id}/activate")
async def admin_activate_personnel(
    personnel_id: str,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    result = personnel_service.activate_personnel(personnel_id, admin)
    return _raise_if_error(result)


@router.post("/admin/personnel/{personnel_id}/reset-password")
async def admin_reset_personnel_password(
    personnel_id: str,
    request: ResetPasswordRequest,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    result = personnel_service.reset_personnel_password(personnel_id, request.temporary_password, admin)
    return _raise_if_error(result)


@router.get("/admin/coverage")
async def admin_personnel_coverage(
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return personnel_service.get_personnel_coverage()
