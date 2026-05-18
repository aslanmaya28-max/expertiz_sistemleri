from fastapi import APIRouter, HTTPException, Depends
from typing import List, Optional, Dict, Any
import json

from yerimebak_ai_v5.services.case_service import CaseService
from yerimebak_ai_v5.schemas.case import CaseCreateRequest, CaseResponse, CaseDetailResponse
from yerimebak_ai_v5.api.v1.endpoints.auth import get_authenticated_user

router = APIRouter()

def get_case_service():
    return CaseService(vault_path="yerimebak_ai_v5/data/vault")

@router.get("/", response_model=List[CaseResponse])
async def list_cases(
    service: CaseService = Depends(get_case_service),
    user: Dict[str, Any] = Depends(get_authenticated_user),
):
    return await service.list_cases()

@router.post("/", response_model=CaseResponse)
async def create_case(
    payload: CaseCreateRequest,
    service: CaseService = Depends(get_case_service),
    user: Dict[str, Any] = Depends(get_authenticated_user),
):
    """
    Create a new Evidence Chain/Case.
    """
    try:
        result = await service.create_case(
            vehicle_info=payload.vehicle_info,
            case_id=payload.case_id,
            files=[]
        )

        return {
            "case_id": result["case_id"],
            "status": result["status"],
            "updated_at": result["metadata"].get("timestamp"),
            "vehicle": payload.vehicle_info.brand,
            "last_version": f"v{result['metadata'].get('version')}"
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Internal Server Error: {str(e)}")

@router.get("/{case_id}", response_model=CaseDetailResponse)
async def get_case(
    case_id: str,
    service: CaseService = Depends(get_case_service),
    user: Dict[str, Any] = Depends(get_authenticated_user),
):
    """
    Get full case detail.
    """
    case_data = await service.get_case_detail(case_id)
    
    if not case_data:
        raise HTTPException(status_code=404, detail="Case not found")
        
    return {
        "case_id": case_id,
        "history": case_data["history"],
        "latest": case_data["latest"],
        "latest_json": json.dumps(case_data["latest"].get("normalized_snapshot", {}), indent=2, ensure_ascii=False),
        "integrity_verified": case_data["integrity_verified"]
    }
