"""
Analysis API Endpoint v1.0
Vehicle analysis and valuation with credit deduction
"""
import logging
from fastapi import APIRouter, HTTPException, Header, Depends
from typing import Dict, Any, Optional
from pydantic import BaseModel

from yerimebak_ai_v5.core.engine_v8 import YerimebakEngineV8, VehicleData, DemandLevel, Seasonality, DamageLevel
from yerimebak_ai_v5.core.market_reference_service import get_market_reference_service
from yerimebak_ai_v5.services.payment_service import get_payment_service
from yerimebak_ai_v5.services.auth_service import get_auth_service
from yerimebak_ai_v5.api.v1.endpoints.auth import get_authenticated_user, get_admin_user

router = APIRouter()

v8_engine = YerimebakEngineV8(verbose=False)


class VehicleAnalysisRequest(BaseModel):
    brand: str
    model: str
    year: int
    mileage_km: int
    fuel_type: str
    gear_type: str
    listed_price: float
    damage_level: str = "NONE"
    demand_level: str = "MEDIUM"
    seasonality: str = "NORMAL"
    api_key: Optional[str] = None


def _authenticate(api_key_header: Optional[str], authorization_header: Optional[str], body_api_key: Optional[str]) -> Dict[str, Any]:
    auth = get_auth_service()

    if authorization_header and authorization_header.startswith("Bearer "):
        token = authorization_header[7:]
        user = auth.verify_token(token)
        if user:
            return user

    key = api_key_header or body_api_key
    if key:
        user = auth.verify_api_key(key)
        if user:
            return user

    raise HTTPException(status_code=401, detail="API Key veya Bearer token gerekli.")


@router.post("/analyze")
async def analyze_vehicle(
    request: VehicleAnalysisRequest,
    api_key_header: Optional[str] = Header(None, alias="X-API-Key"),
    authorization_header: Optional[str] = Header(None, alias="Authorization"),
) -> Dict[str, Any]:
    user = _authenticate(api_key_header, authorization_header, request.api_key)
    
    payment = get_payment_service()
    if not payment.check_credits_before_analysis(user['id']):
        raise HTTPException(
            status_code=402,
            detail=f"Yetersiz kredi. Mevcut: {user['credits']}, Gerekli: 1. Kredi satin almak icin /api/v1/payments/packages"
        )
    
    try:
        market_reference = get_market_reference_service().get_reference(
            brand=request.brand,
            model=request.model,
            year=request.year,
            km=request.mileage_km,
            fuel=request.fuel_type,
            transmission=request.gear_type,
            listed_price=request.listed_price,
        )
        market_avg = market_reference.get("market_avg_price") or request.listed_price

        vehicle = VehicleData(
            make_model=f"{request.brand} {request.model}",
            year=request.year,
            mileage_km=request.mileage_km,
            fuel_type=request.fuel_type,
            gear_type=request.gear_type,
            listed_price=request.listed_price,
            market_price_avg=float(market_avg),
            damage_level=request.damage_level,
            demand_level=request.demand_level,
            seasonality=request.seasonality
        )
        
        valuation = v8_engine.analyze(vehicle)
        
        vehicle_history = {
            "brand": request.brand,
            "model": request.model,
            "year": request.year,
            "mileage_km": request.mileage_km,
            "fuel_type": request.fuel_type,
            "gear_type": request.gear_type,
            "listed_price": request.listed_price,
            "market_price_avg": float(market_avg),
            "market_reference": market_reference,
            "source": "manual_analysis",
        }
        valuation_history = {
            "credits_deducted": 1,
            "opportunity_score": valuation.technical_scoring.opportunity_score,
            "risk_percentage": valuation.technical_scoring.risk_percentage,
            "decision": valuation.dealer_verdict.decision,
            "action_note": valuation.dealer_verdict.action_note,
            "optimal_purchase_price": valuation.commercial_analysis.optimal_purchase_price,
            "estimated_exit_price": valuation.exit_strategy.estimated_exit_price,
            "net_profit_tl": valuation.commercial_analysis.net_profit_tl,
            "net_margin_percent": valuation.commercial_analysis.net_margin_percent,
            "estimated_days_to_sell": valuation.liquidity_metrics.estimated_days_to_sell,
        }

        deduction = payment.deduct_credits(
            user['id'],
            amount=1,
            description=f"Arac analizi: {request.brand} {request.model} {request.year}",
            vehicle_data=vehicle_history,
            valuation_data=valuation_history,
        )
        
        return {
            "vehicle": {
                "brand": request.brand,
                "model": request.model,
                "year": request.year,
                "mileage_km": request.mileage_km,
                "listed_price": request.listed_price
            },
            "market_reference": market_reference,
            "technical_scoring": {
                "opportunity_score": valuation.technical_scoring.opportunity_score,
                "risk_percentage": valuation.technical_scoring.risk_percentage,
            },
            "dealer_verdict": {
                "decision": valuation.dealer_verdict.decision,
                "action_note": valuation.dealer_verdict.action_note,
            },
            "commercial_analysis": {
                "optimal_purchase_price": valuation.commercial_analysis.optimal_purchase_price,
                "estimated_exit_price": valuation.exit_strategy.estimated_exit_price,
                "net_profit_tl": valuation.commercial_analysis.net_profit_tl,
                "net_margin_percent": valuation.commercial_analysis.net_margin_percent,
                "estimated_total_cost": valuation.commercial_analysis.estimated_total_cost
            },
            "liquidity_metrics": {
                "estimated_days_to_sell": valuation.liquidity_metrics.estimated_days_to_sell,
                "liquidity_score": valuation.liquidity_metrics.liquidity_score
            },
            "technical_summary": valuation.technical_summary,
            "billing": {
                "credits_deducted": deduction.get("deducted", 1) if deduction.get("success") else 0,
                "credits_remaining": deduction.get("credits_after", user['credits']) if deduction.get("success") else user['credits']
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        # 🔒 GÜVENLİK: Ic hata mesajlari log'a yazilir, API'ye generic mesaj doner
        logger = logging.getLogger(__name__)
        logger.error(f"Arac analiz hatasi (internal): {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="Arac analizi sirasinda bir hata olustu. Lutfen daha sonra tekrar deneyin."
        )


@router.get("/health")
async def get_analysis_health() -> Dict[str, Any]:
    return {
        "status": "healthy",
        "engine_version": "v8.0",
        "services": {
            "engine_v8": "operational",
            "risk_engine": "operational",
            "condition_analyzer": "operational",
            "ai_valuation": "operational",
            "payment_service": "operational",
            "auth_service": "operational"
        }
    }


class TriggerAnalysisRequest(BaseModel):
    report_id: str


@router.post("/trigger")
async def trigger_ai_analysis(
    request: TriggerAnalysisRequest,
    user: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    """
    Trigger (or re-run) the central AI analysis for a submitted report. Admin only.

    Yalnizca personelin gonderdigi raporlar (pending_ai / pending_admin) analiz
    edilir; taslak rapor AI'ya gonderilemez (personel gonderimini atlamamak icin).
    """
    from yerimebak_ai_v5.core.supabase_bridge import get_supabase_bridge
    from yerimebak_ai_v5.workers.ai_analysis_worker import get_ai_analysis_worker

    bridge = get_supabase_bridge()

    report = bridge.read_report_data(request.report_id)
    if not report:
        raise HTTPException(status_code=404, detail="Rapor bulunamadi")

    if report.get("status") not in ("pending_ai", "pending_admin"):
        raise HTTPException(
            status_code=400,
            detail=f"Rapor durumu uygun degil: {report.get('status')}. Gerekli: pending_ai veya pending_admin"
        )

    worker = get_ai_analysis_worker()
    success = await worker.process_single_report(request.report_id)

    if not success:
        raise HTTPException(status_code=500, detail="AI analiz basarisiz")

    updated = bridge.read_report_data(request.report_id)
    return {
        "success": True,
        "report_id": request.report_id,
        "status": updated.get("status") if updated else "pending_admin",
        "ai_analizi_yapildi_mi": updated.get("ai_analizi_yapildi_mi") if updated else True,
    }


@router.get("/status/{report_id}")
async def get_analysis_status(
    report_id: str,
    user: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    """Get the AI analysis status for a specific report."""
    from yerimebak_ai_v5.core.supabase_bridge import get_supabase_bridge

    bridge = get_supabase_bridge()
    report = bridge.read_report_data(report_id)

    if not report:
        raise HTTPException(status_code=404, detail="Rapor bulunamadi")

    return {
        "success": True,
        "report_id": report_id,
        "status": report.get("status"),
        "ai_analizi_yapildi_mi": report.get("ai_analizi_yapildi_mi", False),
        "ai_analiz_detay": report.get("ai_analiz_detay"),
    }
