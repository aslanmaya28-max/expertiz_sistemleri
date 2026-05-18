# -*- coding: utf-8 -*-
"""
Url Analysis Job Service - Kuyruktaki URL analizlerini tamamlar.
link_analyzer kullanarak URL'yi analiz eder, basarili olursa kredi duser,
basarisiz olursa hata kaydi olusturur.
"""
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)


class UrlAnalysisJobService:
    """URL analiz islerini yurutur: analiz + kredi dusumu."""

    async def process(self, history_id: str, user_id: int, url: str) -> Dict[str, Any]:
        """Bir URL'yi analiz eder, sonucu kaydeder.

        1. link_analyzer ile URL'yi analiz et
        2. Basarili ise PaymentService.complete_queued_analysis cagir
        3. Basarisiz ise PaymentService.mark_queued_analysis_failed cagir

        Args:
            history_id: analysis_history ID.
            user_id: Kullanici ID.
            url: Analiz edilecek URL.

        Returns:
            Dict: Islem sonucu.
        """
        from yerimebak_ai_v5.core.market.link_analyzer import link_analyzer
        from yerimebak_ai_v5.services.payment_service import get_payment_service

        try:
            logger.info(f"URL analysis job basladi: history_id={history_id}, url={url}")
            analysis_result = await link_analyzer.analyze_url(url, save_to_db=False)

            if not analysis_result or "error" in analysis_result:
                error_msg = analysis_result.get("error", "Bilinmeyen hata") if analysis_result else "Analiz sonucu alinamadi"
                raise Exception(error_msg)

            payment = get_payment_service()
            result = payment.complete_queued_analysis(
                user_id=user_id,
                history_id=history_id,
                analysis_result=analysis_result,
            )

            if not result.get("success"):
                logger.error(f"complete_queued_analysis basarisiz: {result.get('error')}")
                return {"success": False, "error": result.get("error", "Kredi islemi basarisiz")}

            logger.info(f"URL analysis job tamamlandi: history_id={history_id}")
            return {"success": True, "history_id": history_id, **result}

        except Exception as e:
            logger.error(f"URL analysis job hatasi: history_id={history_id}, error={e}")
            try:
                payment = get_payment_service()
                payment.mark_queued_analysis_failed(user_id, history_id, str(e))
            except Exception as mark_error:
                logger.error(f"mark_queued_analysis_failed hatasi: {mark_error}")

            return {"success": False, "error": str(e), "history_id": history_id}


_url_analysis_job_service = None


def get_url_analysis_job_service() -> UrlAnalysisJobService:
    """Singleton UrlAnalysisJobService doner."""
    global _url_analysis_job_service
    if _url_analysis_job_service is None:
        _url_analysis_job_service = UrlAnalysisJobService()
    return _url_analysis_job_service
