# -*- coding: utf-8 -*-
"""
Musteri arac degerlemesi: ilan linki veya elle giris + boya/degisen/tramer.
Her analiz 1 kredi; yeterli piyasa verisi yoksa kredi dusulmez.
"""
import asyncio
from typing import Any, Dict, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from yerimebak_ai_v5.api.v1.endpoints.auth import get_current_user
from yerimebak_ai_v5.services import valuation_service, listing_extract

router = APIRouter()


class ValuationRequest(BaseModel):
    listing_url: Optional[str] = None
    brand: Optional[str] = None
    model: Optional[str] = None
    package: Optional[str] = None
    year: Optional[int] = None
    km: Optional[int] = None
    listed_price: Optional[int] = None
    fuel: Optional[str] = None
    transmission: Optional[str] = None
    # parca anahtari -> orijinal | lokal_boyali | boyali | degisen
    parts: Optional[Dict[str, str]] = None
    tramer_amount: Optional[int] = None
    tramer_count: Optional[int] = None


def _raise_if_error(result: Dict[str, Any]) -> Dict[str, Any]:
    if "error" in result:
        detail: Any = result["error"]
        if result.get("code"):
            detail = {"message": result["error"], "code": result["code"]}
        raise HTTPException(status_code=int(result.get("http_status") or 400), detail=detail)
    return result


@router.get("/prefill")
async def prefill(url: str = Query(..., min_length=8), user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    await _consume_daily(user)
    return _raise_if_error(await loop.run_in_executor(None, valuation_service.prefill_from_link, url))


class PrefillTextRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=8000)


async def _consume_daily(user):
    allowed = await asyncio.get_event_loop().run_in_executor(None, listing_extract.consume_daily, user["id"])
    if not allowed:
        raise HTTPException(status_code=429, detail="Günlük 20 ilan çıkarımı sınırına ulaştınız.")


@router.post("/prefill-text")
async def prefill_text(payload: PrefillTextRequest, user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    if not payload.text.strip():
        raise HTTPException(status_code=422, detail="İlan metni boş olamaz.")
    await _consume_daily(user)
    return await asyncio.get_event_loop().run_in_executor(None, listing_extract.from_text, payload.text)


@router.get("/parts")
async def parts() -> Dict[str, Any]:
    """Formda gosterilen kaporta parcalari ve durum secenekleri."""
    from yerimebak_ai_v5.core.ai.inspection_valuation import PART_LABELS

    return {
        "parts": [{"key": k, "label": v} for k, v in PART_LABELS.items()],
        "statuses": [
            {"key": "orijinal", "label": "Orijinal"},
            {"key": "lokal_boyali", "label": "Lokal Boyalı"},
            {"key": "boyali", "label": "Boyalı"},
            {"key": "degisen", "label": "Değişen"},
        ],
        "cost_credits": valuation_service.ANALYSIS_COST,
    }


@router.post("/analyze")
async def analyze(payload: ValuationRequest, user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return _raise_if_error(await loop.run_in_executor(None, valuation_service.analyze, user, payload.model_dump()))
