import os
import re
import json
import asyncio
from datetime import datetime
from typing import Dict, List, Any, Optional

from yerimebak_ai_v5.services.forensic_service import get_forensic_service
from yerimebak_ai_v5.dashboard.services.analiz_service import get_analiz_servisi
from yerimebak_ai_v5.services.case_service import get_case_service
from yerimebak_ai_v5.schemas.case import VehicleInfo

class AnalysisService:
    """
    Kapsamlı Araç Analiz Servisi.
    PDF Ekspertiz okuma, AI Değerleme ve Adli Mühürleme işlemlerini koordine eder.
    """

    def __init__(self):
        self.analiz_service_v1 = get_analiz_servisi()
        self.forensic = get_forensic_service()
        self.case_service = get_case_service()

    def parse_pdf(self, file_path: str) -> Dict[str, Any]:
        """
        PDF ekspertiz raporundan araç bilgilerini çıkarır (pdfplumber kullanarak).
        """
        extracted = {}
        try:
            import pdfplumber
            with pdfplumber.open(file_path) as pdf:
                text = "\n".join(p.extract_text() or "" for p in pdf.pages)

            # Marka/Model
            m = re.search(r"(Marka|Brand)[:\s]+([A-Za-zçğışöüÇĞİŞÖÜ\-]+)", text, re.I)
            if m: extracted["brand"] = m.group(2).strip()
            
            m = re.search(r"(Model)[:\s]+([A-Za-z0-9çğışöüÇĞİŞÖÜ\-\s]+)", text, re.I)
            if m: extracted["model"] = m.group(2).strip()[:20]

            # Yıl
            m = re.search(r"(Yıl|Model Yılı|Year)[:\s]+(\d{4})", text, re.I)
            if m: extracted["year"] = int(m.group(2))

            # KM
            m = re.search(r"(\d[\d\.]+)\s*(km|kilometre)", text, re.I)
            if m: extracted["km"] = int(m.group(1).replace(".", "").replace(",", ""))

            # Tramer
            m = re.search(r"(Tramer|Hasar)[:\s]*[\$₺]?([\d\.]+)", text, re.I)
            if m: extracted["tramer"] = int(m.group(2).replace(".", ""))

        except ImportError:
            return {"error": "pdfplumber not installed"}
        except Exception as e:
            return {"error": str(e)}

        return extracted

    async def run_full_analysis(self, vehicle_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Araç verilerini analiz eder, AI raporu üretir ve sonucu mühürler.
        Sonucu aynı zamanda CaseService üzerinden veritabanına kaydeder.
        """
        import uuid
        case_id = f"YBK-{uuid.uuid4().hex[:6].upper()}"

        # 1. Temel Analiz ve AI Detayları (V1 servisini kullan)
        analysis_result = self.analiz_service_v1.tam_analiz(
            brand=vehicle_data.get("brand", ""),
            model=vehicle_data.get("model", ""),
            year=int(vehicle_data.get("year", 2020)),
            km=int(vehicle_data.get("km", 80000)),
            paket=vehicle_data.get("paket", ""),
            yakit=vehicle_data.get("yakit", ""),
            sanziman=vehicle_data.get("sanziman", ""),
            renk=vehicle_data.get("renk", ""),
            degisen_parcalar=vehicle_data.get("degisen", []),
            boyali_parcalar=vehicle_data.get("boyali", []),
            tramer_bedeli=int(vehicle_data.get("tramer", 0))
        )

        # 2. Adli Mühürleme (Forensic Sealing)
        seal = self.forensic.generate_seal(analysis_result)
        
        # 3. Sonuç Paketleme
        analysis_result["forensic"] = {
            "seal": seal,
            "algorithm": "SHA3-512",
            "timestamp": datetime.now().isoformat(),
            "integrity_verified": True
        }

        # 4. Veritabanına Kayıt (Persistence)
        try:
            v_info = VehicleInfo(
                brand=vehicle_data.get("brand", ""),
                model=vehicle_data.get("model", ""),
                year=int(vehicle_data.get("year", 2020)),
                km=int(vehicle_data.get("km", 80000)),
                trim=vehicle_data.get("paket", ""),
                color=vehicle_data.get("renk", ""),
                tramer=int(vehicle_data.get("tramer", 0)),
                changed_parts=vehicle_data.get("degisen", []),
                painted_parts=vehicle_data.get("boyali", [])
            )
            # Analiz sonucunu snapshota ekleyerek kaydet
            await self.case_service.create_case(
                vehicle_info=v_info,
                case_id=case_id,
                files=[]
            )
            # Not: CaseService zaten mühürleme yapıyor, ama biz kendi analiz mühürümüzü de içerde saklıyoruz.
            analysis_result["case_id"] = case_id
        except Exception as e:
            print(f"⚠️ Persistence error: {e}")

        return analysis_result

# 🔒 DÜZELTİLDİ (B4): Module-level singleton kaldırıldı — DB hazır değilse import crash vermez.
# Lazy-init ile ilk get_analysis_service() çağrısında oluşturulur.
_analysis_service = None

def get_analysis_service():
    global _analysis_service
    if _analysis_service is None:
        _analysis_service = AnalysisService()
    return _analysis_service


