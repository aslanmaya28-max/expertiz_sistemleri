# -*- coding: utf-8 -*-
"""
Payment API Endpoint - Odeme siparisleri, onay, red
"""
import asyncio
from fastapi import APIRouter, HTTPException, Depends, Header
from typing import Dict, Any, Optional
from pydantic import BaseModel

from yerimebak_ai_v5.services.payment_service import get_payment_service, CREDIT_PACKAGES
from yerimebak_ai_v5.api.v1.endpoints.auth import get_current_user, get_admin_user

router = APIRouter()


class CreateOrderRequest(BaseModel):
    package_key: str
    payment_method: str = "havale"
    payment_ref: Optional[str] = None


class ApproveOrderRequest(BaseModel):
    order_id: str
    admin_note: Optional[str] = None


class RejectOrderRequest(BaseModel):
    order_id: str
    admin_note: Optional[str] = None


# ──────────────────────────────────────────────
# 🔒 DÜZELTİLDİ: Sync DB işlemleri run_in_executor için ayrıldı
# ──────────────────────────────────────────────

def _sync_get_packages() -> Dict[str, Any]:
    payment = get_payment_service()
    return payment.get_packages()


def _sync_create_order(user_id: int, package_key: str, payment_method: str, payment_ref: Optional[str]) -> Dict[str, Any]:
    payment = get_payment_service()
    return payment.create_payment_order(
        user_id=user_id,
        package_key=package_key,
        payment_method=payment_method,
        payment_ref=payment_ref,
    )


def _sync_get_my_orders(user_id: int) -> Dict[str, Any]:
    payment = get_payment_service()
    orders = payment.get_payment_orders(user_id=user_id)
    return {"orders": orders}


def _sync_approve_order(order_id: str, approved_by: str, admin_note: Optional[str]) -> Dict[str, Any]:
    payment = get_payment_service()
    return payment.approve_payment_order(
        order_id=order_id,
        approved_by=approved_by,
        admin_note=admin_note,
    )


def _sync_reject_order(order_id: str, rejected_by: str, admin_note: Optional[str]) -> Dict[str, Any]:
    payment = get_payment_service()
    return payment.reject_payment_order(
        order_id=order_id,
        rejected_by=rejected_by,
        admin_note=admin_note,
    )


def _sync_get_all_orders(status: Optional[str]) -> Dict[str, Any]:
    payment = get_payment_service()
    orders = payment.get_payment_orders(status=status)
    return {"orders": orders}


# ──────────────────────────────────────────────
# 🔒 DÜZELTİLDİ: Async endpoint'ler run_in_executor kullanır
# ──────────────────────────────────────────────

@router.get("/packages")
async def get_packages() -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_packages)


@router.post("/order")
async def create_order(
    request: CreateOrderRequest,
    user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, _sync_create_order, user['id'], request.package_key, request.payment_method, request.payment_ref)
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.get("/orders")
async def get_my_orders(
    user: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_my_orders, user['id'])


@router.post("/approve")
async def approve_order(
    request: ApproveOrderRequest,
    admin: Dict[str, Any] = Depends(get_admin_user)
) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, _sync_approve_order, request.order_id, admin.get('email', 'admin'), request.admin_note)
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.post("/reject")
async def reject_order(
    request: RejectOrderRequest,
    admin: Dict[str, Any] = Depends(get_admin_user)
) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, _sync_reject_order, request.order_id, admin.get('email', 'admin'), request.admin_note)
    if "error" in result:
        raise HTTPException(status_code=400, detail=result["error"])
    return result


@router.get("/admin/orders")
async def get_all_orders(
    status: Optional[str] = None,
    admin: Dict[str, Any] = Depends(get_admin_user)
) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_all_orders, status)
