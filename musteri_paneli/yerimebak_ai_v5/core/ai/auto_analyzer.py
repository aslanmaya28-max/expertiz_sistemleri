import json
import logging
import ast
import re
from typing import Dict, Any, Optional, List
from datetime import datetime

from yerimebak_ai_v5.core.database_config import DatabaseConfig
from yerimebak_ai_v5.core.engine_v8 import YerimebakEngineV8, VehicleData, DamageLevel
from yerimebak_ai_v5.core.market_reference_service import get_market_reference_service
from yerimebak_ai_v5.core.risk_engine_v8 import RiskEngineV8

_CURRENT_YEAR = datetime.now().year

logger = logging.getLogger(__name__)

_engine_v8 = YerimebakEngineV8(verbose=False)
_risk_engine_v8 = RiskEngineV8()


def _parse_paint_info(raw) -> Dict[str, Any]:
    paint_info = raw
    if isinstance(paint_info, str):
        try:
            parsed = json.loads(paint_info)
            if isinstance(parsed, str):
                parsed = json.loads(parsed)
            paint_info = parsed
        except Exception:
            try:
                paint_info = ast.literal_eval(paint_info)
            except Exception:
                paint_info = {}
    if not isinstance(paint_info, dict):
        paint_info = {}
    return paint_info


def _extract_paint_data(paint_info: Dict) -> tuple:
    paint_data_list = []
    local_paint_parts_list = []
    changed_parts_list = []

    if not paint_info:
        return paint_data_list, local_paint_parts_list, changed_parts_list

    local_parts = paint_info.get('local_paint_parts', [])
    painted_parts = paint_info.get('painted_parts', [])

    if not local_parts and not painted_parts and paint_info.get('details'):
        all_painted_parts = []
        details = paint_info.get('details', [])
        for detail in details:
            if 'Lokal boyalı' in detail:
                lines = detail.split('\n')
                for i, line in enumerate(lines):
                    if i > 0 and line.strip():
                        part = line.strip()
                        if part and part != '-' and part not in all_painted_parts:
                            all_painted_parts.append(part)
                            local_paint_parts_list.append(part)
            elif 'Boyalı' in detail:
                lines = detail.split('\n')
                for i, line in enumerate(lines):
                    if i > 0 and line.strip():
                        part = line.strip()
                        if part and part != '-' and part not in all_painted_parts:
                            all_painted_parts.append(part)

        for part in all_painted_parts:
            if part in local_paint_parts_list:
                paint_data_list.append({"location": part, "condition": "LOCAL"})
            else:
                paint_data_list.append({"location": part, "condition": "PAINTED"})
    else:
        for part in local_parts:
            paint_data_list.append({"location": part, "condition": "LOCAL"})
            local_paint_parts_list.append(part)
        for part in painted_parts:
            if part not in local_parts:
                paint_data_list.append({"location": part, "condition": "PAINTED"})

    changed_parts_list = paint_info.get('changed_parts', [])
    if not changed_parts_list and paint_info.get('details'):
        details = paint_info.get('details', [])
        for detail in details:
            if 'Değişmiş' in detail and 'Değişen parça' not in detail:
                lines = detail.split('\n')
                for i, line in enumerate(lines):
                    if i > 0 and line.strip():
                        part = line.strip()
                        invalid_entries = ['Boyalı', 'Lokal Boyalı', 'Değişmiş', 'Belirtilmemiş', '-', '']
                        if part and part not in invalid_entries:
                            changed_parts_list.append(part)

    if not isinstance(changed_parts_list, list):
        changed_parts_list = []
    changed_parts_list = list(set([str(p) for p in changed_parts_list if p]))

    return paint_data_list, local_paint_parts_list, changed_parts_list


def _extract_damage_amount(description: str) -> float:
    damage_amount = 0.0
    if description and isinstance(description, str):
        match = re.search(
            r'(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?)\s*(?:tl|₺|kayıt)',
            description,
            re.IGNORECASE,
        )
        if match:
            try:
                amount_str = match.group(1).replace('.', '').replace(',', '')
                damage_amount = float(amount_str)
            except Exception:
                pass
    return damage_amount


def _determine_damage_level(listing: Dict[str, Any], damage_amount: float) -> str:
    title_lower = str(listing.get('title', '')).lower()
    accident = str(listing.get('accident_record', '') or '').lower()
    description = str(listing.get('description', '') or '').lower()

    if 'ağır' in title_lower or 'ağır' in accident or 'heavy' in title_lower:
        return "HEAVY"

    if damage_amount > 0:
        price = float(listing.get('price') or 1)
        if price > 0:
            ratio = damage_amount / price
            if ratio > 0.15:
                return "HEAVY"
            elif ratio > 0.05:
                return "MEDIUM"
            elif ratio > 0.01:
                return "LIGHT"

    if any(kw in title_lower or kw in accident or kw in description
           for kw in ['orta hasar', 'medium', 'tramer', 'hasar kaydı']):
        if 'ağır' not in title_lower:
            return "MEDIUM"

    if any(kw in title_lower or kw in accident for kw in ['hafif hasar', 'light', 'boyalı']):
        return "LIGHT"

    if 'değişen' in accident or 'boyalı' in accident:
        return "LIGHT"

    return "NONE"


def _determine_risk_level(total_risk: float) -> str:
    if total_risk <= 25:
        return "DÜŞÜK"
    elif total_risk <= 50:
        return "ORTA"
    elif total_risk <= 75:
        return "YÜKSEK"
    return "ÇOK YÜKSEK"


def analyze_listing(listing_id: int) -> Optional[Dict[str, Any]]:
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM listings WHERE id = %s", (listing_id,))
        row = cursor.fetchone()
        if not row:
            logger.warning(f"[AUTO_ANALYZE] Listing {listing_id} not found")
            return None

        listing = dict(row)
    finally:
        conn.close()

    price = listing.get('price') or 0
    if price is None or price == 0:
        price = 1
    if isinstance(price, (int, float)):
        try:
            price = float(price)
        except (TypeError, ValueError):
            price = 1.0
    else:
        try:
            price_str = str(price)
            if '.' in price_str and ',' in price_str:
                price = float(price_str.replace('.', '').replace(',', '.'))
            elif ',' in price_str:
                price = float(price_str.replace(',', '.'))
            else:
                price = float(price_str.replace('.', '', price_str.count('.') - 1))
            price = float(price)
        except Exception:
            price = 1.0
    if price <= 0:
        price = 1.0

    km = listing.get('km') or 0
    try:
        km = int(km)
    except (TypeError, ValueError):
        km = 0

    year = listing.get('year') or 2020
    try:
        year = int(year)
    except (TypeError, ValueError):
        year = 2020

    market_reference = get_market_reference_service().get_reference(
        brand=str(listing.get('brand', '') or ''),
        model=str(listing.get('model', '') or ''),
        year=year,
        km=km,
        fuel=listing.get('fuel') or listing.get('fuel_type'),
        transmission=listing.get('transmission'),
        exclude_id=listing_id,
        listed_price=price,
    )
    market_avg = market_reference.get('market_avg_price') or listing.get('market_avg_price') or price

    paint_info = _parse_paint_info(listing.get('paint_info'))
    paint_data_list, local_paint_parts_list, changed_parts_list = _extract_paint_data(paint_info)

    description = listing.get('description', '') or listing.get('accident_record', '') or ''
    damage_amount = _extract_damage_amount(description)
    damage_level = _determine_damage_level(listing, damage_amount)

    painted_locations = [str(p.get('location', '')) for p in paint_data_list if p and p.get('location')]

    vehicle = VehicleData(
        make_model=f"{listing.get('brand', '')} {listing.get('model', '')}",
        year=year,
        mileage_km=km,
        fuel_type=listing.get('fuel', 'Bilinmiyor') or 'Bilinmiyor',
        gear_type=listing.get('transmission', 'Bilinmiyor') or 'Bilinmiyor',
        listed_price=price,
        market_price_avg=float(market_avg),
        damage_level=damage_level,
        bodywork_status=changed_parts_list + painted_locations,
        demand_level='MEDIUM',
        seasonality='NORMAL',
        package_level=listing.get('package_info', 'BASE') or 'BASE',
    )

    try:
        valuation = _engine_v8.analyze(vehicle)
    except Exception as e:
        logger.error(f"[AUTO_ANALYZE] Engine v8 failed for listing {listing_id}: {e}")
        return None

    painted_count = len([p for p in paint_data_list if p.get('condition') in ['PAINTED', 'PLATED']])
    local_paint_count = len([p for p in paint_data_list if p.get('condition') == 'LOCAL'])

    try:
        risk_result = _risk_engine_v8.calculate({
            "price": price,
            "vehicle_km": km,
            "market_average_km": max((_CURRENT_YEAR - year) * 15000, 10000),
            "painted_parts": painted_count,
            "local_paint_parts": local_paint_count,
            "changed_parts": changed_parts_list,
            "damage_amount": damage_amount,
            "package_level": listing.get('package_info', 'BASE') or 'BASE',
            "has_paint_flag": paint_info.get('has_paint', False) if paint_info else False,
            "has_changed_flag": paint_info.get('has_changed', False) if paint_info else False,
            "market_price": float(market_avg),
            "gear_type": listing.get('transmission', '') or '',
        })
    except Exception as e:
        logger.error(f"[AUTO_ANALYZE] Risk engine failed for listing {listing_id}: {e}")
        risk_result = {"total_risk": 50, "opportunity_score": 50, "decision": "HOLD"}

    opportunity_score = valuation.technical_scoring.opportunity_score
    risk_pct = valuation.technical_scoring.risk_percentage
    decision = valuation.dealer_verdict.decision
    net_profit = valuation.commercial_analysis.net_profit_tl
    net_margin = valuation.commercial_analysis.net_margin_percent
    exit_price = valuation.exit_strategy.estimated_exit_price
    days_to_sell = valuation.liquidity_metrics.estimated_days_to_sell
    buy_price_min = int(valuation.commercial_analysis.optimal_purchase_price)
    buy_price_max = int(valuation.commercial_analysis.maximum_purchase_price)
    risk_level = _determine_risk_level(risk_pct)
    price_deviation = ((market_avg - price) / market_avg * 100) if market_avg > 0 else 0.0

    paint_summary = {
        "painted": painted_count,
        "local": local_paint_count,
        "changed": len(changed_parts_list),
    }

    now = datetime.now()
    conn = DatabaseConfig.get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE listings SET
                opportunity_score = %s,
                risk_score = %s,
                predicted_future_price = %s,
                buy_price_min = %s,
                buy_price_max = %s,
                predicted_profit_tl = %s,
                predicted_profit_pct = %s,
                action_recommendation = %s,
                analyzed_at = %s,
                market_avg_price = %s,
                price_deviation_pct = %s,
                risk_level = %s,
                decision = %s,
                exit_price = %s,
                days_to_sell = %s,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
        """, (
            opportunity_score,
            risk_pct,
            int(exit_price),
            buy_price_min,
            buy_price_max,
            int(net_profit),
            round(net_margin, 2),
            valuation.dealer_verdict.action_note,
            now,
            int(market_avg),
            round(price_deviation, 2),
            risk_level,
            decision,
            int(exit_price),
            days_to_sell,
            listing_id,
        ))
    finally:
        conn.close()

    result = {
        "id": listing_id,
        "ai_score": opportunity_score,
        "risk_pct": risk_pct,
        "risk_level": risk_level,
        "decision": decision,
        "net_profit_tl": int(net_profit),
        "net_margin_pct": round(net_margin, 2),
        "exit_price": int(exit_price),
        "days_to_sell": days_to_sell,
        "market_avg_price": int(market_avg),
        "market_reference": market_reference,
        "price_deviation_pct": round(price_deviation, 2),
        "paint_summary": paint_summary,
        "analyzed_at": now.isoformat(),
        "dealer_verdict": {
            "decision": decision,
            "action_note": valuation.dealer_verdict.action_note,
        },
        "technical_scoring": {
            "opportunity_score": opportunity_score,
            "risk_percentage": risk_pct,
        },
        "commercial_analysis": {
            "optimal_purchase_price": buy_price_min,
            "maximum_purchase_price": buy_price_max,
            "net_profit_tl": int(net_profit),
            "net_margin_percent": round(net_margin, 2),
            "estimated_total_cost": int(valuation.commercial_analysis.estimated_total_cost),
        },
        "liquidity_metrics": {
            "estimated_days_to_sell": days_to_sell,
            "liquidity_score": valuation.liquidity_metrics.liquidity_score,
        },
        "risk_v8": risk_result,
        "technical_summary": valuation.technical_summary,
    }

    logger.info(
        f"[AUTO_ANALYZE] Listing {listing_id}: score={opportunity_score}, "
        f"decision={decision}, risk={risk_level}, profit={int(net_profit)} TL"
    )
    return result
