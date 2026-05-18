# -*- coding: utf-8 -*-
"""
Analysis Intake Service - URL tabanli analiz girislerini dogrular,
kuyruk kaydi hazirlar ve kaynak bilgisini standartlastirir.
"""
from urllib.parse import urlparse
from typing import Dict, Any


class AnalysisIntakeService:
    """URL tabanli analiz girislerini dogrulama ve kuyruk kaydi hazirlama servisi."""

    allowed_sources = {"mobile_share", "manual_paste", "chrome_extension"}

    def build_url_intake(self, url: str, source: str) -> Dict[str, Any]:
        """Bir URL'yi dogrular ve kuyruk kaydi payload'i olusturur.

        Args:
            url: Analiz edilecek ilan URL'si.
            source: Kaynak bilgisi (mobile_share, manual_paste, chrome_extension).

        Returns:
            Dict: {'url': ..., 'source': ..., 'status': 'queued'}

        Raises:
            ValueError: URL gecersiz veya kaynak desteklenmiyorsa.
        """
        normalized = url.strip()
        parsed = urlparse(normalized)
        if not parsed.scheme or not parsed.netloc:
            raise ValueError("Gecersiz URL")
        if source not in self.allowed_sources:
            raise ValueError("Gecersiz kaynak")
        return {"url": normalized, "source": source, "status": "queued"}


_analysis_intake_service = None


def get_analysis_intake_service() -> AnalysisIntakeService:
    """Singleton AnalysisIntakeService doner."""
    global _analysis_intake_service
    if _analysis_intake_service is None:
        _analysis_intake_service = AnalysisIntakeService()
    return _analysis_intake_service
