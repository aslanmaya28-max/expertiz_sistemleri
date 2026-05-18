"""
Scrapers API Endpoint v2.0
Scraper management via ScraperManager — real start/stop/status
"""
from fastapi import APIRouter, HTTPException, Depends
from typing import Dict, Any

from yerimebak_ai_v5.workers.scraper_manager import get_scraper_manager
from yerimebak_ai_v5.api.v1.endpoints.auth import get_authenticated_user

router = APIRouter()


def _format_status(source: str, status: Dict) -> Dict[str, Any]:
    """ScraperManager status response -> API format"""
    running = status.get("running", False)
    return {
        "status": "running" if running else "idle",
        "pid": status.get("pid"),
        "last_activity": status.get("last_activity", "-"),
        "source": source,
    }


@router.get("/status")
async def get_scraper_status(
    user: Dict[str, Any] = Depends(get_authenticated_user),
) -> Dict[str, Any]:
    """Get real status of all scrapers from ScraperManager"""
    manager = get_scraper_manager()
    all_status = manager.get_all_status()

    return {
        "arabam": _format_status("arabam", all_status.get("arabam", {})),
        "borusan": _format_status("borusan", all_status.get("borusan", {})),
        "active_workers": sum(
            1 for s in all_status.values() if s.get("running")
        ),
        "total_workers": len(manager.sources),
    }


@router.post("/start/{source}")
async def start_scraper(
    source: str,
    user: Dict[str, Any] = Depends(get_authenticated_user),
):
    """
    Start scraper for specific source (arabam, borusan, all)
    """
    valid_sources = ["arabam", "borusan", "all"]

    if source not in valid_sources:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid source. Must be one of: {', '.join(valid_sources)}",
        )

    manager = get_scraper_manager()

    try:
        if source == "all":
            results = {}
            for s in manager.sources:
                ok, msg = manager.start(s)
                results[s] = {"success": ok, "message": msg}

            started = [s for s, r in results.items() if r["success"]]
            failed = [s for s, r in results.items() if not r["success"]]

            return {
                "status": "started",
                "message": f"Started: {started}. Already running: {failed}",
                "sources": started,
            }
        else:
            ok, msg = manager.start(source)
            if ok:
                return {"status": "started", "message": msg, "source": source}
            else:
                raise HTTPException(status_code=409, detail=msg)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to start scraper: {str(e)}"
        )


@router.post("/stop/{source}")
async def stop_scraper(
    source: str,
    user: Dict[str, Any] = Depends(get_authenticated_user),
):
    """
    Stop scraper for specific source
    """
    valid_sources = ["arabam", "borusan", "all"]

    if source not in valid_sources:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid source. Must be one of: {', '.join(valid_sources)}",
        )

    manager = get_scraper_manager()

    try:
        if source == "all":
            results = {}
            for s in manager.sources:
                ok, msg = manager.stop(s)
                results[s] = {"success": ok, "message": msg}

            stopped = [s for s, r in results.items() if r["success"]]
            already = [s for s, r in results.items() if not r["success"]]

            return {
                "status": "stopped",
                "message": f"Stopped: {stopped}. Already idle: {already}",
                "sources": stopped,
            }
        else:
            ok, msg = manager.stop(source)
            if ok:
                return {"status": "stopped", "message": msg, "source": source}
            else:
                raise HTTPException(status_code=404, detail=msg)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to stop scraper: {str(e)}"
        )


@router.get("/config")
async def get_scraper_config(
    user: Dict[str, Any] = Depends(get_authenticated_user),
) -> Dict[str, Any]:
    """Get scraper configuration"""
    return {
        "arabam": {
            "enabled": True,
            "headless": True,
            "max_listings": 50,
            "timeout": 30,
        },
        "borusan": {
            "enabled": True,
            "headless": True,
            "max_listings": 30,
            "timeout": 20,
        },
    }