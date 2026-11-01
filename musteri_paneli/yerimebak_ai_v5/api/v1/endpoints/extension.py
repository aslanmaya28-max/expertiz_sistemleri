# -*- coding: utf-8 -*-
"""
Extension API Endpoint - Chrome Extension vehicle analysis
Reuses core v8 engine with credit deduction, returns enriched results.
"""
from fastapi import APIRouter, HTTPException, Header
from typing import Dict, Any, Optional
from pydantic import BaseModel, Field

from yerimebak_ai_v5.core.engine_v8 import YerimebakEngineV8, VehicleData
from yerimebak_ai_v5.core.market_reference_service import get_market_reference_service
from yerimebak_ai_v5.services.payment_service import get_payment_service
from yerimebak_ai_v5.services.auth_service import get_auth_service

router = APIRouter()

v8_engine = YerimebakEngineV8(verbose=False)


class ExtensionVehicleRequest(BaseModel):
    """Rich vehicle data from Chrome extension content scripts."""
    brand: str
    model: str
    year: int
    mileage_km: int
    fuel_type: str = "Bilinmiyor"
    gear_type: str = "Bilinmiyor"
    listed_price: float
    damage_level: str = "NONE"
    source: str = "extension"
    url: str = ""
    title: str = ""
    color: str = ""
    engine_size: str = ""
    horsepower: str = ""
    body_type: str = ""
    drive_type: str = ""
    location: str = ""
    image_url: str = ""
    listing_no: str = ""
    listing_date: str = ""
    paint_info: Optional[Dict[str, Any]] = None
    description: str = ""


def _authenticate(api_key: str) -> Dict[str, Any]:
    if not api_key:
        raise HTTPException(status_code=401, detail="API Key gerekli. Header: X-API-Key")
    auth = get_auth_service()
    user = auth.verify_api_key(api_key)
    if not user:
        raise HTTPException(status_code=401, detail="Gecersiz API Key")
    return user


@router.post("/analyze")
async def extension_analyze(
    request: ExtensionVehicleRequest,
    api_key: Optional[str] = Header(None, alias="X-API-Key"),
) -> Dict[str, Any]:
    """
    Chrome Extension analysis endpoint.
    Accepts rich vehicle data from content scripts, runs v8 engine, returns full results.
    """
    user = _authenticate(api_key)

    payment = get_payment_service()
    if not payment.check_credits_before_analysis(user["id"]):
        raise HTTPException(
            status_code=402,
            detail=f"Yetersiz kredi. Mevcut: {user['credits']}, Gerekli: 1",
        )

    try:
        # Derive demand level from market heuristics
        demand_level = "MEDIUM"
        if request.mileage_km < 50000 and request.year >= 2020:
            demand_level = "HIGH"
        elif request.mileage_km > 200000 or request.year < 2012:
            demand_level = "LOW"

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
            demand_level=demand_level,
            seasonality="NORMAL",
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
            "source": "chrome_extension",
            "url": request.url,
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

        # Deduct credit after successful analysis
        deduction = payment.deduct_credits(
            user["id"],
            amount=1,
            description=f"Extension: {request.brand} {request.model} {request.year}",
            vehicle_data=vehicle_history,
            valuation_data=valuation_history,
        )

        # Build risk_v8 from technical scoring
        risk_v8 = {
            "km_risk": min(100, max(0, valuation.technical_scoring.risk_percentage * 0.4)),
            "paint_risk": 15.0 if request.paint_info and request.paint_info.get("has_paint") else 5.0,
            "change_risk": 20.0 if request.paint_info and request.paint_info.get("has_changed") else 5.0,
            "exit_price": valuation.exit_strategy.estimated_exit_price,
            "estimated_days_to_sell": valuation.liquidity_metrics.estimated_days_to_sell,
        }

        return {
            "dealer_verdict": {
                "decision": valuation.dealer_verdict.decision,
                "action_note": valuation.dealer_verdict.action_note,
            },
            "technical_scoring": {
                "opportunity_score": valuation.technical_scoring.opportunity_score,
                "risk_percentage": valuation.technical_scoring.risk_percentage,
            },
            "commercial_analysis": {
                "optimal_purchase_price": valuation.commercial_analysis.optimal_purchase_price,
                "max_offer_price": valuation.commercial_analysis.optimal_purchase_price * 0.95,
                "estimated_exit_price": valuation.exit_strategy.estimated_exit_price,
                "net_profit_tl": valuation.commercial_analysis.net_profit_tl,
                "net_margin_percent": valuation.commercial_analysis.net_margin_percent,
                "estimated_total_cost": valuation.commercial_analysis.estimated_total_cost,
            },
            "liquidity_metrics": {
                "estimated_days_to_sell": valuation.liquidity_metrics.estimated_days_to_sell,
                "liquidity_score": valuation.liquidity_metrics.liquidity_score,
            },
            "risk_v8": risk_v8,
            "vehicle": {
                "brand": request.brand,
                "model": request.model,
                "year": request.year,
                "mileage_km": request.mileage_km,
                "fuel_type": request.fuel_type,
                "gear_type": request.gear_type,
                "listed_price": request.listed_price,
            },
            "market_reference": market_reference,
            "technical_summary": valuation.technical_summary,
            "billing": {
                "credits_deducted": deduction.get("deducted", 1) if deduction.get("success") else 0,
                "credits_remaining": deduction.get("credits_after", user["credits"]),
            },
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analiz hatasi: {str(e)}")


# ---------------------------------------------------------------------------
# arabam.com sayfasini sisteme kaydetme (personelin kendi tarayicisindan)
# ---------------------------------------------------------------------------

_INGEST_ROLES = {"admin", "field_staff", "personel", "personnel", "staff"}


class ExtensionListingPage(BaseModel):
    """Eklentinin okudugu arabam.com ilan sayfasi (sayfa metni sunucuda ayristirilir)."""
    url: str = Field(max_length=2000)
    text: str = Field(max_length=300_000)
    title: str = Field("", max_length=500)
    image_url: str = Field("", max_length=2000)
    location: str = Field("", max_length=200)
    structured: Optional[list] = Field(None, max_length=20)


class ExtensionSearchCard(BaseModel):
    url: str = Field(max_length=2000)
    text: str = Field(max_length=5000)


class ExtensionSearchPage(BaseModel):
    """Arama sonuc sayfasinda gorunen ilanlar (emsal olarak kaydedilir)."""
    url: str = Field(max_length=2000)
    cards: list[ExtensionSearchCard] = Field(max_length=200)
    brand: str = Field("", max_length=60)
    model: str = Field("", max_length=60)


def _authenticate_staff(api_key: Optional[str]) -> Dict[str, Any]:
    user = _authenticate(api_key)
    if str(user.get("role") or "").lower().strip() not in _INGEST_ROLES:
        raise HTTPException(status_code=403, detail="İlan kaydı yalnızca admin ve personel hesaplarıyla yapılabilir.")
    return user


@router.post("/listing")
async def extension_save_listing(
    request: ExtensionListingPage,
    api_key: Optional[str] = Header(None, alias="X-API-Key"),
) -> Dict[str, Any]:
    """Acik arabam.com ilanini (boya/degisen ve tramer beyaniyla) kaydeder; ucretsizdir."""
    from yerimebak_ai_v5.services import extension_ingest, market_ingest

    _authenticate_staff(api_key)
    if not extension_ingest.is_listing_url(request.url):
        raise HTTPException(status_code=400, detail="Bir arabam.com ilan sayfası açın.")
    item = extension_ingest.parse_listing_page(
        request.url, request.text, request.title, request.image_url, request.location, request.structured
    )
    missing = [label for key, label in (("brand", "marka"), ("model", "model"), ("price", "fiyat")) if not item.get(key)]
    if missing:
        raise HTTPException(status_code=422, detail=f"Sayfadan okunamadı: {', '.join(missing)}. Sayfa tam yüklendi mi?")
    saved = market_ingest.upsert_listings([item], status="talep")
    if not saved:
        raise HTTPException(status_code=422, detail="İlan kaydedilemedi.")
    row = saved[0]
    paint = item.get("paint_info") or {}
    damage = item.get("damage_record") or {}
    return {
        "success": True,
        "listing_id": row["id"],
        "vehicle": {k: item.get(k) for k in ("brand", "model", "package", "year", "km", "price", "fuel", "transmission")},
        "beyan": {
            "boyaBolumuVar": item.get("paint_info") is not None,
            "boyali": paint.get("painted_parts", []),
            "degisen": paint.get("changed_parts", []),
            "tramerTl": damage.get("tramer_tl"),
            "tramerYok": damage.get("tramer_yok"),
            "agirHasar": damage.get("agir_hasar"),
        },
    }


@router.post("/search")
async def extension_save_search(
    request: ExtensionSearchPage,
    api_key: Optional[str] = Header(None, alias="X-API-Key"),
) -> Dict[str, Any]:
    """Acik arama sayfasindaki ilanlari emsal olarak kaydeder (sayfa gezilmez)."""
    from yerimebak_ai_v5.services import extension_ingest, market_ingest

    _authenticate_staff(api_key)
    if not extension_ingest.is_arabam_url(request.url):
        raise HTTPException(status_code=400, detail="Bir arabam.com arama sayfası açın.")
    brand, model = request.brand.strip(), request.model.strip()
    if not brand or not model:
        try:
            from yerimebak_ai_v5.services.valuation_service import _guess_from_slug

            guess = _guess_from_slug(request.url)
            brand, model = brand or guess.get("brand", ""), model or guess.get("model", "")
        except Exception:
            pass
    if not brand or not model:
        raise HTTPException(status_code=422, detail="Marka ve model belirlenemedi; eklentide elle girin.")
    items = extension_ingest.parse_search_page(request.url, [c.model_dump() for c in request.cards], brand, model)
    saved = market_ingest.upsert_listings(items, status="emsal") if items else []
    return {"success": True, "brand": brand, "model": model, "found": len(request.cards), "saved": len(saved)}
