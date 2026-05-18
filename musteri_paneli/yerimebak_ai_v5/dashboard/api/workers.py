from fastapi import APIRouter
from yerimebak_ai_v5.dashboard.services.worker_service import WorkerService

router = APIRouter(prefix="/workers", tags=["workers"])

@router.get("/status")
async def get_worker_status():
    return WorkerService.get_worker_status()
