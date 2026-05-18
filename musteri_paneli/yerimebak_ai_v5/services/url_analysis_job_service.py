from typing import Any, Optional

from yerimebak_ai_v5.core.link_analyzer import link_analyzer
from yerimebak_ai_v5.services.payment_service import PaymentService, get_payment_service


class UrlAnalysisJobService:
    def __init__(self, analyzer: Optional[Any] = None, payment_service: Optional[PaymentService] = None):
        self._analyzer = analyzer or link_analyzer
        self._payment_service = payment_service or get_payment_service()

    async def process(self, history_id: str, user_id: int, url: str) -> None:
        try:
            analysis = await self._analyzer.analyze_url(url, save_to_db=False)
        except Exception as exc:
            self._payment_service.mark_queued_analysis_failed(history_id, user_id, str(exc))
            return

        if not analysis or analysis.get("error"):
            error = analysis.get("error") if isinstance(analysis, dict) else "Analiz sonucu alinamadi"
            self._payment_service.mark_queued_analysis_failed(history_id, user_id, error)
            return

        self._payment_service.complete_queued_analysis(history_id, user_id, analysis)
