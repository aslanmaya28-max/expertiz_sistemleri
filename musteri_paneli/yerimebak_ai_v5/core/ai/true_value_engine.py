# -*- coding: utf-8 -*-
"""
True Value Engine 5.1 - Autonomous Forensic Valuation Core
YerimeBak AI – Quantum Decision Engine
"""

import json
from datetime import datetime
from typing import Dict, List, Union, Tuple

class TrueValueEngine:
    """
    Antigravity v5.1 Forensic Engine.
    Implements DEGER_KAYBI_KATSAYISI and Structural Severity Protocol.
    """
    
    def __init__(self, verbose: bool = True):
        self.verbose = verbose
        self.version = "5.1-autonomous"
        
        # === STRUCTURAL SEVERITY HIERARCHY ===
        # roof > chassis/pillars > panel
        self.SEVERITY_LEVELS = {
            "roof": 0.15,      # Tavan: En kritik, takla veya ağır hasar göstergesi
            "chassis": 0.12,   # Şase, Direk, Podye: Yapısal bütünlük
            "engine": 0.10,    # Motor, Mekanik
            "panel": 0.04      # Kapı, Çamurluk, Tampon: Kozmetik
        }
        
        # === KM ADJUSTMENT (Autonomous Calibration) ===
        self.KM_BANDS = [
            (0, 25000, 0.15, "Pristine"),
            (25001, 60000, 0.08, "Optimized"),
            (60001, 120000, 0.00, "Standard"),
            (120001, 180000, -0.10, "High Wear"),
            (180001, float('inf'), -0.18, "End of Life Proxy")
        ]
        
        # === LIQUIDITY ADJUSTMENTS (Color Impact) ===
        self.COLOR_LIQUIDITY = {
            "beyaz": 0.02,
            "gri": 0.01,
            "siyah": 0.01,
            "kirmizi": -0.02,
            "mavi": -0.01,
            "ozel": 0.03 # Lansman rengi vb.
        }

        # === COMPONENT MAPPING ===
        self.STRUCTURAL_MAP = {
            "tavan": "roof",
            "şase": "chassis", "direk": "chassis", "podye": "chassis", "havuz": "chassis",
            "motor": "engine", "traves": "engine",
            "kaput": "panel", "bagaj": "panel", "kapı": "panel", "çamurluk": "panel"
        }

    def _get_severity(self, part_name: str) -> str:
        """Determines the severity class of a part"""
        part_lower = part_name.lower()
        for key, severity in self.STRUCTURAL_MAP.items():
            if key in part_lower:
                return severity
        return "panel"

    def calculate_v51(self, market_median: float, vehicle: Dict) -> Dict:
        """
        Antigravity v5.1 Autonomous Valuation Logic.
        Focuses on DEGER_KAYBI_KATSAYISI (DKK).
        """
        if self.verbose:
            print(f"\n🏛️ ANTIGRAVITY v5.1 FORENSIC CORE")
            print(f"   Analyzing: {vehicle.get('brand', 'Unknown')} {vehicle.get('model', '')}")

        base_price = float(market_median)
        dkk = 0.0 # DEGER_KAYBI_KATSAYISI (Value Loss Coefficient)
        evidence_log = []

        # 1. STRUCTURAL DAMAGE ANALYSIS (Forensic Priority)
        changed = vehicle.get("changed", [])
        painted = vehicle.get("painted", [])
        
        # Severity hierarchy processing
        for part in changed:
            severity = self._get_severity(part)
            penalty = self.SEVERITY_LEVELS[severity]
            dkk += penalty
            evidence_log.append(f"CRITICAL: Changed {part} [Sev: {severity.upper()}] - Penalty: {penalty:.2f}")

        for part in painted:
            severity = self._get_severity(part)
            penalty = self.SEVERITY_LEVELS[severity] * 0.4 # Paint is ~40% of replacement impact
            dkk += penalty
            evidence_log.append(f"FORENSIC: Painted {part} [Sev: {severity.upper()}] - Penalty: {penalty:.2f}")

        # 2. KM & LIQUIDITY ADJUSTMENTS
        km = vehicle.get("km", 100000)
        km_adj, km_label = 0.0, "Standard"
        for low, high, adj, label in self.KM_BANDS:
            if low <= km <= high:
                km_adj, km_label = adj, label
                break
        
        color = vehicle.get("color", "beyaz").lower()
        color_adj = self.COLOR_LIQUIDITY.get(color, 0.0)

        # 3. QUANTUM DECISION (Final Consolidation)
        # Final Formula: base * (1 + km_bonus + color_bonus - dkk)
        ai_adjustment_factor = km_adj + color_adj - dkk
        final_estimate = base_price * (1 + ai_adjustment_factor)

        # 4. CONFIDENCE ENGINEERING
        # Reduces confidence based on damage complexity and missing data
        confidence = 0.95
        if dkk > 0.30: confidence -= 0.15 # Heavy damage reduces certainty
        if not vehicle.get("inspection_report", True): confidence -= 0.10
        
        # 5. VERDICT GENERATION
        verdict = "ADLI_ONAYLI"
        if ai_adjustment_factor > 0.10: forensic_status = "PREMIUM_ASSET"
        elif dkk > 0.40: forensic_status = "HEAVY_RESTORATION_REQUIRED"
        else: forensic_status = "STANDART_VALUATION"
        
        return {
            "status": verdict,
            "forensic_status": forensic_status,
            "valuation": {
                "base_price": base_price,
                "ai_adjustment": base_price * ai_adjustment_factor,
                "final_estimate": int(final_estimate),
                "deger_kaybi_katsayisi": round(dkk, 4)
            },
            "confidence_score": round(confidence, 2),
            "evidence_log": evidence_log,
            "metadata": {
                "engine": self.version,
                "timestamp": datetime.now().isoformat(),
                "km_label": km_label
            }
        }

if __name__ == "__main__":
    # Quick Test
    engine = TrueValueEngine()
    test_car = {
        "brand": "Toyota", "model": "Corolla",
        "km": 45000, "color": "ozel",
        "changed": ["kaput", "sol_on_kapi"],
        "painted": ["tavan"], # Roof paint is very suspicious
        "inspection_report": True
    }
    res = engine.calculate_v51(1000000, test_car)
    print(json.dumps(res, indent=2, ensure_ascii=False))
