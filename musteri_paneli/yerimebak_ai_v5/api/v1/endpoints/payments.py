# -*- coding: utf-8 -*-
"""
Payment API Endpoint - kredi paketleri, PayTR odeme, admin siparis listesi ve iade
"""
import asyncio
from fastapi import APIRouter, HTTPException, Depends, Request
from fastapi.responses import PlainTextResponse
from typing import Dict, Any, Optional
from pydantic import BaseModel

from yerimebak_ai_v5.services.payment_service import get_payment_service
from yerimebak_ai_v5.services import checkout_service, paytr_service
from yerimebak_ai_v5.api.v1.endpoints.auth import get_current_user, get_admin_user

router = APIRouter()


# ──────────────────────────────────────────────
# 🔒 DÜZELTİLDİ: Sync DB işlemleri run_in_executor için ayrıldı
# ──────────────────────────────────────────────

def _sync_get_packages() -> Dict[str, Any]:
    payment = get_payment_service()
    return payment.get_packages()


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


# Havale + elle admin onayi akisi kaldirildi: odemeler PayTR ile alinir ve
# krediler odeme onayinda otomatik yuklenir (/checkout/credits).


@router.get("/admin/orders")
async def get_all_orders(
    status: Optional[str] = None,
    admin: Dict[str, Any] = Depends(get_admin_user)
) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return await loop.run_in_executor(None, _sync_get_all_orders, status)


class RefundOrderRequest(BaseModel):
    reason: str


@router.post("/admin/orders/{order_id}/refund")
async def refund_order(
    order_id: str,
    request: RefundOrderRequest,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    """Kullanilmamis kredi paketini iade eder (PayTR iadesi + kredi dusumu)."""
    from yerimebak_ai_v5.services import refund_service

    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(None, refund_service.refund_credit_order, order_id, admin, request.reason)
    if "error" in result:
        raise HTTPException(status_code=int(result.get("http_status") or 400), detail=result["error"])
    return result


# ──────────────────────────────────────────────
# PayTR: kredi paketi satin alma (krediler odeme onayinda aninda yuklenir)
# ──────────────────────────────────────────────

class CreditCheckoutRequest(BaseModel):
    package_key: str
    # On Bilgilendirme Formu + Mesafeli Satis Sozlesmesi onayi (zorunlu)
    contract_accepted: bool = False


class SimulateRequest(BaseModel):
    success: bool = True


def _raise_checkout(result: Dict[str, Any]) -> Dict[str, Any]:
    if "error" in result:
        raise HTTPException(status_code=int(result.get("http_status") or 400), detail=result["error"])
    return result


@router.get("/provider")
async def payment_provider() -> Dict[str, Any]:
    return paytr_service.provider_status()


@router.post("/checkout/credits")
async def checkout_credits(
    payload: CreditCheckoutRequest,
    request: Request,
    user: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    ip = paytr_service.client_ip({k.lower(): v for k, v in request.headers.items()}, request.client.host if request.client else None)
    loop = asyncio.get_event_loop()
    return _raise_checkout(await loop.run_in_executor(None, checkout_service.start_credit_purchase, user, payload.package_key, ip, payload.contract_accepted))


@router.get("/checkout/{order_id}")
async def checkout_status(order_id: str, user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    loop = asyncio.get_event_loop()
    return _raise_checkout(await loop.run_in_executor(None, checkout_service.get_order_status, order_id, user))


@router.post("/checkout/{order_id}/simulate")
async def checkout_simulate(
    order_id: str,
    payload: SimulateRequest,
    user: Dict[str, Any] = Depends(get_current_user),
) -> Dict[str, Any]:
    """Sadece PAYMENT_SIMULATION=true iken calisir (gelistirme / test)."""
    loop = asyncio.get_event_loop()
    return _raise_checkout(await loop.run_in_executor(None, checkout_service.simulate_payment, order_id, user, payload.success))


@router.post("/paytr/callback", response_class=PlainTextResponse)
async def paytr_callback(request: Request) -> PlainTextResponse:
    """PayTR 'Bildirim URL'. Imza dogrulanir; PayTR duz 'OK' cevabi bekler."""
    form = dict(await request.form())
    loop = asyncio.get_event_loop()
    ok = await loop.run_in_executor(None, checkout_service.handle_paytr_callback, form)
    if not ok:
        raise HTTPException(status_code=400, detail="PAYTR notification failed: bad hash")
    return PlainTextResponse("OK")
