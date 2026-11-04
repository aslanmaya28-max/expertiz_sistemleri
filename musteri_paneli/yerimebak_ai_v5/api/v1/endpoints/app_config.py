"""Mobil uygulamanın herkese açık özellik ve sürüm ayarları."""
import os
from fastapi import APIRouter
from yerimebak_ai_v5.services.payment_service import ANALYSIS_CREDIT_COST

router = APIRouter()


@router.get('/config')
def app_config():
    return {
        'expertiz_enabled': os.getenv('APP_EXPERTIZ_ENABLED', 'false').lower() in ('true', '1', 'yes'),
        'min_supported_version': os.getenv('APP_MIN_VERSION') or '1.0.0',
        'latest_version': os.getenv('APP_LATEST_VERSION') or '1.0.0',
        'store_url': os.getenv('APP_STORE_URL') or 'https://play.google.com/store/apps/details?id=com.yerimebak.app',
        'support_email': os.getenv('SUPPORT_EMAIL') or 'destek@yerimebak.com.tr',
        'analysis_cost': ANALYSIS_CREDIT_COST,
    }
