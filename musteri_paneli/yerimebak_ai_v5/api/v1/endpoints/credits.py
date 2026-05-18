# -*- coding: utf-8 -*-
"""
Credits API Endpoint - Bakiye sorgulama, kredi gecmisi
"""
from fastapi import APIRouter, HTTPException, Depends
from typing import Dict, Any

from yerimebak_ai_v5.services.payment_service import get_payment_service
from yerimebak_ai_v5.api.v1.endpoints.auth import get_current_user

router = APIRouter()


@router.get("/balance")
async def get_balance(
    user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    payment = get_payment_service()
    return payment.get_credit_balance(user['id'])


@router.get("/history")
async def get_analysis_history(
    user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    payment = get_payment_service()
    history = payment.get_analysis_history(user['id'])
    return {"history": history, "total": len(history)}
