# -*- coding: utf-8 -*-
"""
AI Result Adapter
Converts Python AI pipeline outputs to Flutter's AIAnalizSonucu JSON schema.
Supports: Engine V8 (DealerValuation), AI Valuation (Gemini), Unified AI (OpenRouter)
"""
import uuid
import logging
from datetime import datetime
from typing import Dict, Any, List, Optional

logger = logging.getLogger(__name__)


def _genel_sonuc_from_score(genel_puan: float) -> str:
    if genel_puan >= 90:
        return "Mükemmel"
    elif genel_puan >= 80:
        return "Çok İyi"
    elif genel_puan >= 70:
        return "İyi"
    elif genel_puan >= 60:
        return "Orta"
    elif genel_puan >= 50:
        return "Yeterli"
    return "Yetersiz"


def _puan_rengi(genel_puan: float) -> str:
    if genel_puan >= 80:
        return "Green"
    elif genel_puan >= 60:
        return "Orange"
    return "Red"


def _puan_degerlendirmesi(genel_puan: float) -> str:
    if genel_puan >= 90:
        return "Mükemmel Durum"
    elif genel_puan >= 80:
        return "Çok İyi Durum"
    elif genel_puan >= 70:
        return "İyi Durum"
    elif genel_puan >= 60:
        return "Orta Durum"
    elif genel_puan >= 50:
        return "Yetersiz Durum"
    return "Kötü Durum"


def _decision_to_onay_red(decision: str) -> str:
    mapping = {
        "STRONG_BUY": "Alınması kesinlikle önerilir",
        "BUY": "Alınması önerilir",
        "NEGOTIATE": "Müzakere sonrası alınabilir",
        "HOLD": "Beklenmesi önerilir",
        "AVOID": "Alınması önerilmez",
    }
    return mapping.get(decision, "Değerlendirme yapılamadı")


def _decision_to_oneriler(decision: str, action_note: str) -> List[Dict[str, Any]]:
    oneriler = []
    if decision in ("AVOID", "HOLD"):
        oneriler.append({
            "kategori": "Kritik",
            "baslik": "Riskli Araç",
            "aciklama": action_note,
            "onerilenEylem": "Bu araçtan uzak durun veya fiyatı ciddi şekilde müzakere edin",
            "oncelik": 1,
            "onemDerecesi": "Yüksek",
        })
    elif decision == "NEGOTIATE":
        oneriler.append({
            "kategori": "Önemli",
            "baslik": "Müzakere Gerekli",
            "aciklama": action_note,
            "onerilenEylem": "Fiyat müzakeresi yaparak uygun fiyata alabilirsiniz",
            "oncelik": 3,
            "onemDerecesi": "Orta",
        })
    elif decision in ("BUY", "STRONG_BUY"):
        oneriler.append({
            "kategori": "Öneri",
            "baslik": "İyi Fırsat",
            "aciklama": action_note,
            "onerilenEylem": "Araç değerinde, alım değerlendirilebilir",
            "oncelik": 7,
            "onemDerecesi": "Düşük",
        })
    return oneriler


def engine_v8_to_ai_analiz(
    valuation,
    vehicle_data: Optional[Dict[str, Any]] = None,
    report_id: Optional[str] = None,
) -> Dict[str, Any]:
    """
    Convert Engine V8 DealerValuation to AIAnalizSonucu JSON schema.

    Args:
        valuation: DealerValuation dataclass from engine_v8.py
        vehicle_data: Original vehicle input data
        report_id: UUID of the report

    Returns:
        dict matching Flutter's AIAnalizSonucu.toJson() schema
    """
    vehicle_data = vehicle_data or {}

    risk_pct = valuation.technical_scoring.risk_percentage
    opportunity = valuation.technical_scoring.opportunity_score

    arac_durumu = max(0, min(100, 100 - risk_pct * 0.8))
    motor_mekanik = max(0, min(100, 85 - risk_pct * 0.4))
    hasar_puan = max(0, min(100, 100 - risk_pct * 1.0))
    genel_puan = (arac_durumu * 0.3 + motor_mekanik * 0.3 + hasar_puan * 0.2 + opportunity * 0.2)
    genel_puan = max(0, min(100, genel_puan))

    decision = valuation.dealer_verdict.decision
    oneriler = _decision_to_oneriler(decision, valuation.dealer_verdict.action_note)

    market_valuation = valuation.market_valuation
    commercial = valuation.commercial_analysis
    exit_price = valuation.exit_strategy.estimated_exit_price
    net_profit = commercial.net_profit_tl
    listed_price = vehicle_data.get("listed_price", vehicle_data.get("price", 0))

    deger_kaybi = abs((listed_price - exit_price) / listed_price * 100) if listed_price > 0 else 0

    alti_aylik_getiri = net_profit / 2 if net_profit > 0 else 0
    bir_yillik_getiri = net_profit if net_profit > 0 else 0

    tahmini_deger = market_valuation.market_price_avg

    rapor_ozeti = {
        "genelSonuc": _genel_sonuc_from_score(genel_puan),
        "anahtarBulgular": valuation.technical_summary.split(". ")[:8] if valuation.technical_summary else [],
        "ozetAciklama": valuation.technical_summary or "",
        "onayRedOnerisi": _decision_to_onay_red(decision),
        "tahminiDeger": float(tahmini_deger),
        "degerKaybiYuzde": round(deger_kaybi, 2),
        "degerProjeksiyonu1Yil": float(bir_yillik_getiri),
        "altiAylikGetiri": float(alti_aylik_getiri),
    }

    skorlar = {
        "aracDurumuPuan": round(arac_durumu, 1),
        "motorMekanikPuan": round(motor_mekanik, 1),
        "hasarPuan": round(hasar_puan, 1),
        "genelPuan": round(genel_puan, 1),
        "detayliPuanlar": {
            "riskPercentage": round(risk_pct, 1),
            "opportunityScore": opportunity,
            "liquidityScore": valuation.liquidity_metrics.liquidity_score,
        },
        "puanDegerlendirmesi": _puan_degerlendirmesi(genel_puan),
        "puanRengi": _puan_rengi(genel_puan),
    }

    finansal = {
        "ai_piyasa_degeri": float(tahmini_deger),
        "ai_onerilen_alim_fiyati": float(commercial.optimal_purchase_price),
        "ai_alti_aylik_getiri": float(alti_aylik_getiri),
        "ai_bir_yillik_getiri": float(bir_yillik_getiri),
        "ai_deger_kaybi": round(deger_kaybi, 2),
    }

    kritik_sorunlar = []
    if risk_pct > 50:
        kritik_sorunlar.append(f"Yüksek risk oranı: %{risk_pct:.1f}")
    if decision == "AVOID":
        kritik_sorunlar.append("Araç alınması önerilmez")
    if net_profit < 0:
        kritik_sorunlar.append(f"Negatif kâr: {net_profit:,.0f} TL")

    return build_ai_analiz_sonucu(
        skorlar=skorlar,
        oneriler=oneriler,
        rapor_ozeti=rapor_ozeti,
        finansal=finansal,
        kritik_sorunlar=kritik_sorunlar,
        report_id=report_id,
    )


def build_ai_analiz_sonucu(
    skorlar: Dict[str, Any],
    oneriler: List[Dict[str, Any]],
    rapor_ozeti: Dict[str, Any],
    finansal: Dict[str, Any],
    kritik_sorunlar: Optional[List[str]] = None,
    report_id: Optional[str] = None,
) -> Dict[str, Any]:
    """Build the final AIAnalizSonucu JSON matching Flutter schema."""
    return {
        "gorevId": report_id or str(uuid.uuid4()),
        "analizZamani": datetime.now().isoformat(),
        "skorlar": skorlar,
        "oneriler": oneriler,
        "raporOzeti": rapor_ozeti,
        "kritikSorunlar": kritik_sorunlar or [],
        "fotografAnalizi": {},
        "finansalProjeksiyonlar": finansal,
        "tamamlandiMi": True,
        "hataMesaji": None,
    }
