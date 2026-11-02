# -*- coding: utf-8 -*-
"""Admin: YerimeBak piyasa takibi (verisi az olan marka/modeller için elle girilen ilan verisi).

Yalnız admin erişir (kullanıcı kararı: personel yok). Yalnız rakamlar saklanır; ayrıntı
services/manual_market.py başındaki açıklamada.
"""
import asyncio
import json
from pathlib import Path
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from yerimebak_ai_v5.api.v1.endpoints.auth import get_admin_user
from yerimebak_ai_v5.services import manual_market
from yerimebak_ai_v5.services.web_market_reference import fold

router = APIRouter()

_EXTRA_BRANDS = ("Alfa Romeo", "Chevrolet", "Cupra", "DS", "Isuzu", "Jaguar", "Jeep", "Land Rover", "Lexus",
                 "Mazda", "MINI", "Mitsubishi", "Omoda", "Porsche", "Smart", "Subaru", "Suzuki", "Tesla", "Volvo",
                 "Jaecoo", "Leapmotor", "SsangYong", "KGM", "Cadillac", "Infiniti", "Lancia", "Dodge", "Chrysler")


def _known_brands() -> List[str]:
    path = Path(__file__).resolve().parents[3] / "data" / "kasa_listesi.json"
    try:
        brands = {m["marka"] for m in json.loads(path.read_text(encoding="utf-8")).get("modeller") or []}
    except (OSError, ValueError, KeyError):
        brands = set()
    return sorted(brands | set(_EXTRA_BRANDS), key=len, reverse=True)


def guess_brand(text: str) -> Optional[str]:
    """Liste başlığından marka ("Arazi, SUV & Pickup MG Fiyatları" → MG); bulunamazsa None."""
    head = fold((text or "")[:400]).replace("-", " ")
    words = f" {' '.join(head.split())} "
    for brand in _known_brands():
        if f" {' '.join(fold(brand).replace('-', ' ').split())} " in words:
            return brand
    return None


class PreviewRequest(BaseModel):
    text: str = Field(..., min_length=10, max_length=300_000)


class SaveRequest(BaseModel):
    brand: str = Field(..., min_length=1, max_length=40)
    satirlar: List[Dict[str, Any]] = Field(..., max_length=500)


@router.post("/manual/preview")
async def preview(payload: PreviewRequest, admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    """Yapıştırılan arama listesini ayrıştırır; kaydetmez (admin önizlemede satır çıkarabilir)."""
    parsed = manual_market.parse_search_page(payload.text)
    if not parsed["satirlar"]:
        raise HTTPException(status_code=422, detail="Listede ilan satırı bulunamadı. Arama sonuç sayfasını olduğu gibi kopyalayın.")
    return {**parsed, "marka": guess_brand(payload.text)}


@router.post("/manual/save")
async def save(payload: SaveRequest, admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    try:
        return await loop.run_in_executor(None, manual_market.save, payload.brand, payload.satirlar, str(admin.get("id")))
    except (ValueError, KeyError, TypeError) as exc:
        raise HTTPException(status_code=422, detail=f"Kayıt yapılamadı: {exc}") from exc


@router.get("/gaps")
async def gaps(limit: int = Query(50, ge=1, le=200), admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    """Verisi az olan modeller: internet aramasında 5 ilan bulunamayan istekler, en çok istenen önce."""
    loop = asyncio.get_event_loop()
    return {"modeller": await loop.run_in_executor(None, manual_market.gaps, limit)}
