import hashlib
import json
from datetime import datetime
from typing import Any, Dict, Optional

class ForensicService:
    """
    Adli Bütünlük Servisi (Forensic Integrity Service)
    Verilerin kriptografik olarak mühürlenmesini ve doğrulanmasını sağlar.
    """

    @staticmethod
    def generate_seal(data: Any) -> str:
        """
        Veri için SHA3-512 kriptografik mühür üretir.
        """
        if isinstance(data, (dict, list)):
            data_sent = json.dumps(data, sort_keys=True, ensure_ascii=False).encode('utf-8')
        elif isinstance(data, str):
            data_sent = data.encode('utf-8')
        else:
            data_sent = str(data).encode('utf-8')
            
        return hashlib.sha3_512(data_sent).hexdigest()

    @staticmethod
    def verify_seal(data: Any, seal: str) -> bool:
        """
        Verinin mühürle eşleşip eşleşmediğini doğrular.
        """
        return ForensicService.generate_seal(data) == seal

    def create_evidence_package(self, data: Dict[str, Any], source: str) -> Dict[str, Any]:
        """
        Adli kanıt paketi oluşturur.
        """
        timestamp = datetime.now().isoformat()
        seal = self.generate_seal(data)
        
        return {
            "evidence_id": f"EV-{int(datetime.now().timestamp())}",
            "timestamp": timestamp,
            "source": source,
            "original_data": data,
            "seal": seal,
            "algorithm": "SHA3-512",
            "integrity_verified": True
        }

# Singleton
_forensic_service = ForensicService()

def get_forensic_service():
    return _forensic_service
